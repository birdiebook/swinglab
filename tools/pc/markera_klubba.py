"""S7: märk klubban för hand på utvalda rutor (PLAN S7, BESLUT B44, METOD MF5–MF6).

    python tools/pc/markera_klubba.py <paket.zip> [fler paket]     # ett pass, gärna DTL och FO
    python tools/pc/markera_klubba.py <video.mov> [--vy fo]         # ett klipp utan paket

Rutorna väljs själva (MF5): adress, topp och tidig nedsving ur Visions faser och P5, plus
några jämnt spridda, för några slag jämnt spridda över passet, i varje vy. Klippets ruta
tas med S3:s förskjutning (`~/swinglab-s3/<pass>/s3.json`, METOD MF1), så att bilden,
tiden och greppets ledtråd hör till samma ruta som Visions leder: kör S3 först. En
video utan paket har inga leder: där sprids rutorna jämnt över klippet.

Sidan öppnas i webbläsaren från en server på den här datorn (127.0.0.1, inget nätverk ut).
Klicka grepp, skaftets mitt och klubbhuvudet (hoseln) i den ordningen:

    klick  sätt punkten          1 2 3  välj punkt          X  punkten syns inte
    Enter  rutan klar            mellanslag  hoppa över     ←  föregående ruta
    Z      zooma kring musen     Backsteg  ta bort punkten

Greppets ledtråd (handledernas mitt) visas ihålig; greppet kräver ändå ett klick. Märkningen
sparas efter varje ruta i `swinglab-<pass>-klubba.json` bredvid paketet (formatet i
docs/FORMAT.md, "Klubbans märkning"), och en körning till fortsätter där den slutade.
Filen ska ligga utanför repot: den är Johannes data.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import secrets
import sys
import tempfile
import threading
import webbrowser
import zipfile
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Callable

import numpy as np

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "pc"

from . import klipp as KL  # noqa: E402
from . import klubba as KLB  # noqa: E402
from . import kontaktark as KA  # noqa: E402
from . import paket as P  # noqa: E402
from . import s3_facit as S3F  # noqa: E402
from . import session as S  # noqa: E402
from .format import LEDER_FIL, MIN_KONFIDENS  # noqa: E402

# Formatet ägs av klubba.py (BESLUT B47): verktyget skriver version 2 och läser 1 och 2.
FORMAT = KLB.FORMAT
PUNKTER = KLB.PUNKTER        # BESLUT B44: tre punkter, GolfPose hosel som klubbhuvudets punkt
VAL = KLB.VAL_1              # rutorna som verktyget väljer (MF5); telefonen väljer P-positioner
STATUS = KLB.STATUS
KALLOR = KLB.KALLOR          # BESLUT B44: varje punkt är ett klick; ledtråden godtas aldrig av sig själv
TID_TOL_S = 0.002            # METOD MF1: samma tolerans som S3 för klippets ruta

SLAG_PER_PAKET = 6           # METOD MF5: slag per paket, jämnt spridda över passet
JAMNA_PER_SLAG = 2           # METOD MF5: jämnt spridda rutor per slag, adress → finish
JAMNA_VIDEO = 24             # METOD MF5: rutor i en video utan paket
NEDSVING_ANDEL = 1 / 3       # METOD MF5: tidig nedsving utan P5 = toppen + 1/3 av nedsvingen
MARGINAL = 0.15              # METOD MF6: sidan visar utsnittet + 15 % per sida (klubban når utanför)
ZOOM = 3.0                   # METOD MF6: Z förstorar så mycket kring musen
JPEG_KVALITET = 88           # METOD MF6
LANGD_FASER_M = 1.80         # faserna beror inte på längden; den behövs bara för att mäta


class MarkFel(RuntimeError):
    pass


# --- rutvalet ------------------------------------------------------------------------

def _visad(utsnitt, bredd: int, hojd: int) -> list[int]:
    """Utsnittet i px, vidgat med MARGINAL per sida och inom bilden. Utan utsnitt hela
    bilden. METOD MF6"""
    x, y, b, h = P.utsnitt_px(utsnitt, bredd, hojd)
    if utsnitt is None:
        return [x, y, b, h]
    mx, my = int(round(b * MARGINAL)), int(round(h * MARGINAL))
    x0, y0 = max(0, x - mx), max(0, y - my)
    x1, y1 = min(bredd, x + b + mx), min(hojd, y + h + my)
    return [x0, y0, x1 - x0, y1 - y0]


def forslag(ruta_leder: list) -> dict:
    """Greppets ledtråd: handledernas mitt, eller den som syns (greppregeln, METOD M1).
    Den ligger 5–8 cm från skaftet, så den visas bara som ledtråd och greppet kräver ett
    klick. Skaftet och klubbhuvudet har ingen förrän en detektor finns (S7). METOD MF5"""
    hander = []
    for j in (LEDER_FIL.index("handled_v"), LEDER_FIL.index("handled_h")):
        led, _ = P._led(ruta_leder[j], "")
        if led is not None and led[2] >= MIN_KONFIDENS:
            hander.append(led)
    if not hander:
        return {}
    return {"grepp": {"x": round(sum(h[0] for h in hander) / len(hander), 1),
                      "y": round(sum(h[1] for h in hander) / len(hander), 1), "kalla": "handlederna"}}


def valj_slag(n_slag: int, n: int) -> list[int]:
    """n slag jämnt spridda över de n_slag (index), första och sista med. METOD MF5"""
    if n_slag <= 0 or n <= 0:
        return []
    return sorted(set(np.round(np.linspace(0, n_slag - 1, min(n, n_slag))).astype(int).tolist()))


forskjutningar = S3F.forskjutningar


def valj_rutor(paket: list[tuple[Path, P.Paket]], forskjutning: dict[tuple[str, str], float],
               slag_per_paket: int = SLAG_PER_PAKET, jamna: int = JAMNA_PER_SLAG) -> list[dict]:
    """Rutorna att märka i paketen: för valda slag adressen, toppen och tidig nedsving
    (P5, annars toppen + 1/3 av nedsvingen), och `jamna` rutor jämnt mellan adressen och
    finishen; varje tid flyttad till närmaste Vision-ruta och bara inom klippet. Bara
    slag med S3:s förskjutning (ms) väljs, så att klippets ruta är Visions. METOD MF5"""
    ut = []
    for fil, p in paket:
        kandidater = []
        for s in p.slag:
            if s.dom not in P.MATS or s.detection_wrong or not s.klipp or not s.lederna:
                continue
            if (p.fil, s.id) not in forskjutning:
                continue
            r, _ = S3F._mat_vision(fil, p, s, p.langd_m or LANGD_FASER_M)
            if r is None:
                continue
            kandidater.append((s, r))
        for k in valj_slag(len(kandidater), slag_per_paket):
            s, r = kandidater[k]
            f = r["faser"]
            kol = KA.tider(f)
            p5 = r["positioner"].get("P5")
            tider = [("adress", kol["adress"]), ("topp", f["topp"]),
                     ("tidig_nedsving", p5 if p5 is not None else f["topp"] + NEDSVING_ANDEL * (f["traff"] - f["topp"]))]
            for j in range(jamna):
                tider.append((f"jamn-{j + 1}", kol["adress"] + (j + 1) / (jamna + 1) * (kol["finish"] - kol["adress"])))
            rutor = s.lederna["frames"]
            bredd, hojd = s.lederna["width"], s.lederna["height"]
            visad = _visad(p.serier[s.serie].utsnitt, bredd, hojd)
            sedda = set()
            for namn, t in tider:
                rr = min(rutor, key=lambda x: abs(x["t"] - t))
                tk = float(rr["t"]) + float(s.klick_i_klipp_s)
                if not P.i_klippet(s, tk) or rr["t"] in sedda:
                    continue
                sedda.add(rr["t"])
                ut.append({"id": f"{p.vy}-{s.id}-{namn}", "fil": p.fil, "vy": p.vy, "slag": s.id,
                           "val": namn.split("-")[0], "t": round(float(rr["t"]), 4), "t_klipp": round(tk, 6),
                           "forskjutning_ms": forskjutning[(p.fil, s.id)], "t_ruta": None,
                           "bredd": bredd, "hojd": hojd, "visad": visad, "status": "omarkerad",
                           "punkter": {n: None for n in PUNKTER}, "forslag": forslag(rr["joints"])})
    return ut


def valj_video(fil: Path, langd_s: float, bredd: int, hojd: int, vy: str | None, n: int = JAMNA_VIDEO) -> list[dict]:
    """En video utan paket: n rutor jämnt över klippet (inga leder, inga faser). METOD MF5"""
    return [{"id": f"video-{k + 1:02d}", "fil": fil.name, "vy": vy, "slag": None, "val": "jamn", "t": None,
             "t_klipp": round((k + 0.5) / n * langd_s, 6), "forskjutning_ms": 0.0, "t_ruta": None,
             "bredd": bredd, "hojd": hojd,
             "visad": [0, 0, bredd, hojd], "status": "omarkerad", "punkter": {p: None for p in PUNKTER},
             "forslag": {}} for k in range(n)]


# --- formatet ------------------------------------------------------------------------

def ny(rutor: list[dict], kalla: list[str], pass_id: str | None) -> dict:
    return {"format": FORMAT, "pass": pass_id, "kalla": kalla, "punkter": list(PUNKTER),
            "andrad": datetime.now().astimezone().isoformat(timespec="seconds"), "rutor": rutor}


SAMMA_T_S = 1e-4             # METOD MF5: samma ruta = samma tid inom 0,1 ms


def _samma(a: dict, b: dict) -> bool:
    """Samma ruta: samma id och fil, samma förskjutning och samma tid inom 0,1 ms
    (Visions tid; för en video den valda tiden i klippet, inte rutans egen). METOD MF5"""
    if a["id"] != b["id"] or a["fil"] != b["fil"]:
        return False
    if abs(a.get("forskjutning_ms", 0.0) - b.get("forskjutning_ms", 0.0)) > SAMMA_T_S * 1000:
        return False
    ta, tb = (a["t"], b["t"]) if a["t"] is not None and b["t"] is not None else (a["t_klipp"], b["t_klipp"])
    return ta is not None and tb is not None and abs(ta - tb) <= SAMMA_T_S


def sla_ihop(ny_d: dict, gammal: dict | None) -> dict:
    """En tidigare märkning behålls: en ny ruta som är samma ruta som en gammal får dess
    status och punkter. En gammal ruta som inte matchar ligger kvar sist, oförändrad; en
    ny ruta med samma id men en annan ruta får ett nytt id."""
    if not gammal:
        return ny_d
    kvar = list(gammal["rutor"])
    rutor = []
    for r in ny_d["rutor"]:
        g = next((x for x in kvar if _samma(r, x)), None)
        if g is not None:
            kvar.remove(g)
            r = {**r, "status": g["status"], "punkter": g["punkter"]}
        rutor.append(r)
    ids = {x["id"] for x in kvar}
    for r in rutor:
        k = 2
        bas = r["id"]
        while r["id"] in ids:
            r["id"] = f"{bas}-{k}"
            k += 1
    return {**ny_d, "rutor": rutor + kvar}


def kontrollera(d) -> list[str]:
    """Formen på märkningen, version 1 och 2 (docs/FORMAT.md, "Klubbans märkning"): ägs av
    klubba.py, så att telefonens markeringar och PC:ns läses som samma data. BESLUT B47"""
    return KLB.kontrollera(d)


def las(fil: Path) -> dict:
    """Märkningen i version 2: en fil i version 1 (före S7a) uppgraderas, och nästa
    sparning skriver version 2. Telefonens `klubba.json` läses likadant. BESLUT B47"""
    try:
        d = json.loads(Path(fil).read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        raise MarkFel(f"{Path(fil).name}: inte giltig JSON (rad {e.lineno})") from None
    f = kontrollera(d)
    if f:
        raise MarkFel(f"{Path(fil).name}: " + "; ".join(f))
    return KLB.uppgradera(d)


def las_paket(fil: Path) -> dict | None:
    """Telefonens markeringar ur ett paket (`klubba.json`, version 2), eller None när
    paketet inte har några. BESLUT B47"""
    with zipfile.ZipFile(fil) as z:
        if KLB.FIL not in z.namelist():
            return None
        try:
            d = json.loads(P.las_ur_zip(z, Path(fil).name, KLB.FIL).decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            raise MarkFel(f"{Path(fil).name}: {KLB.FIL} är inte giltig JSON") from None
    f = kontrollera(d)
    if f:
        raise MarkFel(f"{Path(fil).name}: {KLB.FIL}: " + "; ".join(f))
    return KLB.uppgradera(d)


_LAS = threading.Lock()


def skriv(fil: Path, d: dict) -> None:
    """Kontrollerar och skriver märkningen: ett unikt temporärt namn i samma mapp och
    sedan ett byte, under ett lås så att två sparningar inte blandas."""
    f = kontrollera(d)
    if f:
        raise MarkFel("; ".join(f))
    fil = Path(fil)
    with _LAS:
        fd, tmp = tempfile.mkstemp(prefix=fil.name + ".", suffix=".del", dir=fil.parent)
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as ut:
                ut.write(json.dumps(d, ensure_ascii=False, indent=1) + "\n")
            os.replace(tmp, fil)
        except BaseException:
            Path(tmp).unlink(missing_ok=True)
            raise


# --- bilderna ------------------------------------------------------------------------

def koda(img: np.ndarray) -> str:
    """En RGB-bild som data-URL: JPEG med OpenCV, annars PNG utan beroenden."""
    try:
        import cv2
        ok, b = cv2.imencode(".jpg", cv2.cvtColor(img, cv2.COLOR_RGB2BGR), [cv2.IMWRITE_JPEG_QUALITY, JPEG_KVALITET])
        if ok:
            return "data:image/jpeg;base64," + base64.b64encode(b.tobytes()).decode()
    except ImportError:
        pass
    with tempfile.TemporaryDirectory() as tmp:
        f = Path(tmp) / "r.png"
        KA.skriv_png(f, np.ascontiguousarray(img))
        return "data:image/png;base64," + base64.b64encode(f.read_bytes()).decode()


LasVid = Callable[[Path, list, int, int, float], dict]


def bilder(rutor: list[dict], kallor: dict[str, Path], las_vid: LasVid = KL.ramar_vid,
           rapport=print, tol_video: float = TID_TOL_S) -> dict[str, str]:
    """Varje rutas bild (den visade delen) som data-URL. Rutan läses i läsarens tid
    t_klipp + förskjutningen (S3, METOD MF1) och tas bara om en ruta finns inom
    TID_TOL_S; rutans egen tid (läsarens) sparas i t_ruta, och t_klipp står kvar som
    vald tid, så att en återupptagen märkning hittar rutan. Ett klipp läses en gång. `kallor`: paketets eller videons namn → filen. METOD MF6"""
    ut: dict[str, str] = {}
    grupper: dict[tuple[str, str | None], list[dict]] = {}
    for r in rutor:
        grupper.setdefault((r["fil"], r["slag"]), []).append(r)
    with tempfile.TemporaryDirectory() as tmp:
        for (namn, slag), grupp in grupper.items():
            fil = kallor.get(namn)
            if fil is None:
                continue
            if fil.suffix.lower() == ".zip":
                p = P.las(fil, med_leder=False)
                s = next((x for x in p.slag if x.id == slag), None)
                if s is None or not s.klipp:
                    continue
                klipp = Path(tmp) / f"{len(ut)}-{slag}{Path(s.klipp).suffix}"
                with zipfile.ZipFile(fil) as z:
                    klipp.write_bytes(P.las_ur_zip(z, p.fil, s.klipp))
                tol = TID_TOL_S
            else:
                klipp, tol = fil, tol_video
            onskat = {r["id"]: r["t_klipp"] + r["forskjutning_ms"] / 1000.0 for r in grupp}
            fatt = las_vid(klipp, sorted(set(onskat.values())), grupp[0]["bredd"], grupp[0]["hojd"], tol)
            for r in grupp:
                if onskat[r["id"]] not in fatt:
                    continue
                tid, img = fatt[onskat[r["id"]]]
                r["t_ruta"] = round(float(tid), 6)
                h, w = img.shape[:2]
                x, y, b, hh = KL.skala_ruta(tuple(r["visad"]), w, h, r["bredd"], r["hojd"])
                ut[r["id"]] = koda(img[y:y + hh, x:x + b])
            if rapport:
                rapport(f"  {len(ut)} av {len(rutor)} rutor lästa", flush=True)
    return ut


# --- sidan ---------------------------------------------------------------------------

def _json_i_html(d) -> str:
    return json.dumps(d, ensure_ascii=False).replace("</", "<\\/")


def sida(markering: dict, bilder_: dict[str, str], server: bool, filnamn: str) -> str:
    """Hela sidan som en fil: data, bilder och skript inbäddade, inget hämtas utifrån."""
    lage = {"server": server, "filnamn": filnamn, "zoom": ZOOM}
    return (SIDA.replace("__DATA__", _json_i_html(markering)).replace("__BILDER__", _json_i_html(bilder_))
            .replace("__LAGE__", _json_i_html(lage)).replace("__SKRIPT__", SKRIPT))


SIDA = """<!doctype html>
<html lang="sv"><head><meta charset="utf-8"><title>Märk klubban</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
html,body{margin:0;height:100%;background:#000;color:#eee;font:14px system-ui,sans-serif}
#rad{display:flex;gap:16px;align-items:center;padding:6px 10px;background:#111;flex-wrap:wrap}
#rad b{font-variant-numeric:tabular-nums}
.p{padding:2px 8px;border:1px solid #444;border-radius:4px}
.p.akt{border-color:#fff;background:#333}
#hjalp{color:#999;padding:2px 10px 6px;background:#111}
#sparat{margin-left:auto;color:#999}
button{background:#fff;color:#000;border:0;border-radius:4px;padding:4px 10px;font:inherit;cursor:pointer}
canvas{display:block;cursor:crosshair}
</style></head><body>
<div id="rad"><b id="plats"></b><span id="vad"></span>
<span class="p" id="p0">1 Grepp</span><span class="p" id="p1">2 Skaftets mitt</span><span class="p" id="p2">3 Klubbhuvud (hosel)</span>
<span id="sparat"></span><button id="ladda">Ladda ner</button><button id="klar">Klar</button></div>
<div id="hjalp">Klick sätt punkten · 1–3 välj punkt · X syns inte · Backsteg ta bort · Enter rutan klar · Mellanslag hoppa över · ← föregående · Z zoom.
Grepp = skaftet mitt mellan händerna (ringen är bara en ledtråd ur handlederna) · Skaftets mitt = mitt mellan grepp och hosel · Klubbhuvud = hoseln, där skaftet går in i huvudet.</div>
<canvas id="cv"></canvas>
<script type="application/json" id="data">__DATA__</script>
<script type="application/json" id="bilder">__BILDER__</script>
<script type="application/json" id="lage">__LAGE__</script>
<script>__SKRIPT__</script>
</body></html>
"""

SKRIPT = r"""
"use strict";
const D = JSON.parse(document.getElementById("data").textContent);
const B = JSON.parse(document.getElementById("bilder").textContent);
const L = JSON.parse(document.getElementById("lage").textContent);
const PUNKTER = D.punkter;
const FARG = {grepp: "#4fc3f7", skaft_mitt: "#ffd54f", klubbhuvud: "#ff7043"};
const KORT = {grepp: "G", skaft_mitt: "M", klubbhuvud: "H"};
const NYCKEL = new URLSearchParams(window.location.search).get("k") || "";
const cv = document.getElementById("cv");
const ctx = cv.getContext("2d");
const img = new Image();
let i = Math.max(0, D.rutor.findIndex(r => r.status === "omarkerad"));
let p = 0;
let zoom = false;
let mus = null;
let vy = {s: 1, ox: 0, oy: 0};

function ruta() { return D.rutor[i]; }
function forstaTomma() {
  const k = PUNKTER.findIndex(n => !ruta().punkter[n]);
  return k < 0 ? 0 : k;
}
function ladda() {
  p = forstaTomma();
  img.onload = rita;
  img.src = B[ruta().id] || "";
  rita();
}
function berakna() {
  const iw = img.naturalWidth || ruta().visad[2], ih = img.naturalHeight || ruta().visad[3];
  let s = Math.min(cv.width / iw, cv.height / ih);
  let ox = (cv.width - iw * s) / 2, oy = (cv.height - ih * s) / 2;
  if (zoom && mus) {
    const ix = (mus.x - ox) / s, iy = (mus.y - oy) / s;
    s *= L.zoom;
    ox = mus.x - ix * s;
    oy = mus.y - iy * s;
  }
  vy = {s: s, ox: ox, oy: oy};
}
function skala() {
  const v = ruta().visad;
  return img.naturalWidth ? v[2] / img.naturalWidth : 1;
}
function tillBild(x, y) {
  const v = ruta().visad, k = skala();
  return {x: v[0] + (x - vy.ox) / vy.s * k, y: v[1] + (y - vy.oy) / vy.s * k};
}
function tillSkarm(q) {
  const v = ruta().visad, k = skala();
  return {x: vy.ox + (q.x - v[0]) / k * vy.s, y: vy.oy + (q.y - v[1]) / k * vy.s};
}
function rita() {
  const rad = document.getElementById("rad").offsetHeight + document.getElementById("hjalp").offsetHeight;
  cv.width = window.innerWidth;
  cv.height = Math.max(100, window.innerHeight - rad);
  berakna();
  ctx.fillStyle = "#000";
  ctx.fillRect(0, 0, cv.width, cv.height);
  const r = ruta();
  if (img.complete && img.naturalWidth) {
    ctx.drawImage(img, vy.ox, vy.oy, img.naturalWidth * vy.s, img.naturalHeight * vy.s);
  } else {
    ctx.fillStyle = "#999";
    ctx.fillText("Ingen bild för rutan: hoppa över med mellanslag.", 20, 30);
  }
  const lagen = PUNKTER.map(n => {
    const q = r.punkter[n];
    if (q && !q.syns_inte) return {q: q, fast: true};
    if (!q && r.forslag[n]) return {q: r.forslag[n], fast: false};
    return null;
  });
  ctx.strokeStyle = "rgba(255,255,255,0.6)";
  ctx.lineWidth = 1;
  ctx.beginPath();
  let forsta = true;
  lagen.forEach(l => {
    if (!l) return;
    const s = tillSkarm(l.q);
    if (forsta) ctx.moveTo(s.x, s.y); else ctx.lineTo(s.x, s.y);
    forsta = false;
  });
  ctx.stroke();
  lagen.forEach((l, k) => {
    if (!l) return;
    const n = PUNKTER[k], s = tillSkarm(l.q);
    ctx.strokeStyle = FARG[n];
    ctx.fillStyle = FARG[n];
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(s.x, s.y, 6, 0, 2 * Math.PI);
    if (l.fast) ctx.fill(); else ctx.stroke();
    ctx.fillText(KORT[n], s.x + 9, s.y - 9);
  });
  info();
}
function info() {
  const r = ruta();
  const markerade = D.rutor.filter(x => x.status === "markerad").length;
  const hoppade = D.rutor.filter(x => x.status === "hoppad").length;
  document.getElementById("plats").textContent = (i + 1) + " / " + D.rutor.length;
  document.getElementById("vad").textContent = [r.vy ? r.vy.toUpperCase() : "", r.slag || "", r.val, r.status,
    "märkta " + markerade + ", hoppade " + hoppade].filter(Boolean).join(" · ");
  PUNKTER.forEach((n, k) => {
    const e = document.getElementById("p" + k);
    e.className = "p" + (k === p ? " akt" : "");
    const q = r.punkter[n];
    e.style.color = q ? (q.syns_inte ? "#999" : FARG[n]) : "#eee";
  });
}
let kedja = Promise.resolve();
function spara() {
  D.andrad = new Date().toISOString();
  if (!L.server) { document.getElementById("sparat").textContent = "inte sparad: ladda ner"; return kedja; }
  const kropp = JSON.stringify(D);
  // En sparning i taget, i ordning: den senaste vinner alltid.
  kedja = kedja.then(() => fetch("/spara?k=" + encodeURIComponent(NYCKEL),
      {method: "POST", headers: {"Content-Type": "application/json"}, body: kropp}))
    .then(svar => { document.getElementById("sparat").textContent = svar.ok ? "sparad" : "kunde inte spara"; })
    .catch(() => { document.getElementById("sparat").textContent = "servern svarar inte: ladda ner"; });
  return kedja;
}
function ga(steg) {
  i = Math.min(D.rutor.length - 1, Math.max(0, i + steg));
  zoom = false;
  ladda();
}
function klar() {
  const r = ruta();
  // Ledtråden (greppet ur handlederna) godtas aldrig av sig själv: varje punkt är ett klick.
  const saknas = PUNKTER.filter(n => !r.punkter[n]);
  if (saknas.length) {
    p = PUNKTER.indexOf(saknas[0]);
    document.getElementById("sparat").textContent = "saknas: " + saknas.join(", ");
    rita();
    return;
  }
  r.status = "markerad";
  spara();
  ga(1);
}
cv.addEventListener("mousemove", e => {
  mus = {x: e.offsetX, y: e.offsetY};
  if (zoom) rita();
});
cv.addEventListener("click", e => {
  const r = ruta();
  const q = tillBild(e.offsetX, e.offsetY);
  if (q.x < 0 || q.y < 0 || q.x > r.bredd || q.y > r.hojd) return;
  r.punkter[PUNKTER[p]] = {x: Math.round(q.x * 10) / 10, y: Math.round(q.y * 10) / 10, kalla: "klick"};
  const nasta = PUNKTER.findIndex(n => !r.punkter[n]);
  if (nasta >= 0) p = nasta;
  rita();
});
document.addEventListener("keydown", e => {
  const r = ruta();
  if (e.key === "1" || e.key === "2" || e.key === "3") { p = Number(e.key) - 1; info(); }
  else if (e.key === "x" || e.key === "X") {
    r.punkter[PUNKTER[p]] = {syns_inte: true};
    const nasta = PUNKTER.findIndex(n => !r.punkter[n]);
    if (nasta >= 0) p = nasta;
    rita();
  }
  else if (e.key === "Backspace" || e.key === "Delete") { r.punkter[PUNKTER[p]] = null; r.status = "omarkerad"; rita(); }
  else if (e.key === "Enter" || e.key === "ArrowRight") { klar(); }
  else if (e.key === " ") { r.status = "hoppad"; spara(); ga(1); }
  else if (e.key === "ArrowLeft") { ga(-1); }
  else if (e.key === "z" || e.key === "Z") { zoom = !zoom; rita(); }
  else return;
  e.preventDefault();
});
document.getElementById("ladda").addEventListener("click", () => {
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob([JSON.stringify(D, null, 1)], {type: "application/json"}));
  a.download = L.filnamn;
  a.click();
});
document.getElementById("klar").addEventListener("click", () => {
  spara().then(() => L.server ? fetch("/klar?k=" + encodeURIComponent(NYCKEL),
      {method: "POST", headers: {"Content-Type": "application/json"}, body: "{}"}) : null).then(() => {
    document.body.textContent = "Klart. Märkningen ligger i " + L.filnamn + ". Fönstret kan stängas.";
  });
});
window.addEventListener("resize", rita);
ladda();
"""


# --- servern -------------------------------------------------------------------------

MAX_BYTES = 50 * 1024 * 1024


def server(html: str, fil: Path, port: int = 0) -> ThreadingHTTPServer:
    """En server på 127.0.0.1 som visar sidan och sparar märkningen i `fil`. Varje anrop
    kräver den slumpade nyckeln (`?k=`, `srv.nyckel`) och Host 127.0.0.1:<port>, och en
    sparning JSON med en giltig längd, så att ingen annan sida i webbläsaren kan skriva
    filen. /klar stänger servern. METOD MF6"""
    sidan = html.encode("utf-8")
    nyckel = secrets.token_urlsafe(24)

    class H(BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def _svar(self, kod: int, typ: str, kropp: bytes) -> None:
            self.send_response(kod)
            self.send_header("Content-Type", typ)
            self.send_header("Content-Length", str(len(kropp)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(kropp)

        def _behorig(self) -> str | None:
            """Sökvägen utan frågan, eller None (och svaret skickat) när anropet nekas."""
            from urllib.parse import parse_qs, urlsplit
            u = urlsplit(self.path)
            if self.headers.get("Host") != f"127.0.0.1:{self.server.server_address[1]}":
                self._svar(403, "text/plain", b"fel Host")
                return None
            if not secrets.compare_digest((parse_qs(u.query).get("k") or [""])[0], nyckel):
                self._svar(403, "text/plain", b"nyckeln saknas")
                return None
            return u.path

        def do_GET(self):
            vag = self._behorig()
            if vag is None:
                return
            if vag in ("/", "/index.html"):
                self._svar(200, "text/html; charset=utf-8", sidan)
            else:
                self._svar(404, "text/plain", b"")

        def do_POST(self):
            vag = self._behorig()
            if vag is None:
                return
            if (self.headers.get("Content-Type") or "").split(";")[0].strip() != "application/json":
                self._svar(415, "text/plain", b"application/json required")
                return
            langd = self.headers.get("Content-Length")
            if langd is None:
                self._svar(411, "text/plain", b"")
                return
            try:
                n = int(langd)
            except ValueError:
                n = -1
            if n < 0:
                self._svar(400, "text/plain", b"fel Content-Length")
                return
            if n > MAX_BYTES:
                self._svar(413, "text/plain", b"")
                return
            kropp = self.rfile.read(n)
            if vag == "/spara":
                try:
                    skriv(fil, json.loads(kropp.decode("utf-8")))
                except (MarkFel, json.JSONDecodeError, UnicodeDecodeError) as e:
                    self._svar(400, "text/plain; charset=utf-8", str(e)[:500].encode("utf-8"))
                    return
                except OSError:
                    self._svar(500, "text/plain; charset=utf-8", "filen gick inte att skriva".encode("utf-8"))
                    return
                self._svar(200, "application/json", b'{"ok":true}')
            elif vag == "/klar":
                self._svar(200, "application/json", b'{"ok":true}')
                threading.Thread(target=self.server.shutdown, daemon=True).start()
            else:
                self._svar(404, "text/plain", b"")

    srv = ThreadingHTTPServer(("127.0.0.1", port), H)
    srv.nyckel = nyckel
    return srv


# --- kommandot -----------------------------------------------------------------------

def _video_info(fil: Path) -> tuple[float, int, int, float]:
    """(längd i s, bredd, höjd, bilder per s), upprätt, med OpenCV."""
    try:
        import cv2
    except ImportError:
        raise MarkFel("En video kräver OpenCV: pip install opencv-python") from None
    cap = cv2.VideoCapture(str(fil))
    try:
        n, fps = cap.get(cv2.CAP_PROP_FRAME_COUNT), cap.get(cv2.CAP_PROP_FPS)
        ok, ram = cap.read()
    finally:
        cap.release()
    if not ok or not fps or not n:
        raise MarkFel(f"{fil.name}: videon går inte att läsa")
    return n / fps, ram.shape[1], ram.shape[0], fps


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="S7: märk grepp, skaftets mitt och klubbhuvudet på utvalda rutor.")
    ap.add_argument("in_", nargs="+", metavar="paket.zip|video.mov")
    ap.add_argument("--ut", help="märkningens fil (standard bredvid första filen)")
    ap.add_argument("--slag", type=int, default=SLAG_PER_PAKET, help="slag per paket")
    ap.add_argument("--jamna", type=int, help=f"jämnt spridda rutor per slag ({JAMNA_PER_SLAG}) eller per video "
                                              f"({JAMNA_VIDEO})")
    ap.add_argument("--vy", choices=("dtl", "fo"), help="vyn för en video utan paket")
    ap.add_argument("--s3", help="S3:s s3.json med klippens förskjutning (standard ~/swinglab-s3/<pass>/s3.json)")
    ap.add_argument("--port", type=int, default=0)
    ap.add_argument("--utan-webblasare", action="store_true", help="öppna inte webbläsaren, skriv bara adressen")
    a = ap.parse_args(argv)
    filer = [Path(f).expanduser() for f in a.in_]
    try:
        zippar = [f for f in filer if f.suffix.lower() == ".zip"]
        if zippar and len(zippar) != len(filer):
            raise MarkFel("Ge antingen paket (.zip) eller videor, inte båda.")
        tol_video = TID_TOL_S
        if zippar:
            paket = [(f, P.las(f)) for f in zippar]
            pass_id = paket[0][1].pass_id
            s3 = Path(a.s3).expanduser() if a.s3 else S3F.UT_ROT / pass_id / "s3.json"
            if not s3.is_file():
                raise MarkFel(f"S3:s tabell saknas ({s3}). Kör S3 först: den mäter klippens tidsförskjutning, "
                              "så att bilden blir samma ruta som Visions leder:\n  python tools/pc/s3_facit.py "
                              + " ".join(str(f) for f in zippar))
            fsk = S3F.las_forskjutningar(pass_id, s3)
            rutor = valj_rutor(paket, fsk, a.slag, JAMNA_PER_SLAG if a.jamna is None else a.jamna)
            standard = zippar[0].parent / f"swinglab-{pass_id}-klubba.json"
        else:
            pass_id, rutor = None, []
            for f in filer:
                langd, b, h, fps = _video_info(f)
                tol_video = 0.5 / fps
                rutor += valj_video(f, langd, b, h, a.vy, JAMNA_VIDEO if a.jamna is None else a.jamna)
            standard = filer[0].parent / f"{filer[0].stem}-klubba.json"
        ut = Path(a.ut).expanduser() if a.ut else standard
        if not S.utanfor_repot(ut.parent):
            raise MarkFel("Märkningen får inte ligga i repot: den är Johannes data.")
        if not rutor:
            raise MarkFel("Inga rutor att märka: inga mätta slag med klipp och en säker förskjutning i S3.")
        try:
            import cv2  # noqa: F401
        except ImportError:
            raise MarkFel("Bilderna kräver OpenCV: pip install opencv-python") from None
        gammal = las(ut) if ut.is_file() else None
        d = sla_ihop(ny(rutor, [f.name for f in filer], pass_id), gammal)
        print(f"{len(d['rutor'])} rutor, varav {sum(r['status'] == 'omarkerad' for r in d['rutor'])} omärkta. "
              "Läser bilderna …", flush=True)
        bild = bilder(d["rutor"], {f.name: f for f in filer}, tol_video=tol_video)
        skriv(ut, d)
    except KL.VridenFel as e:
        print(str(e))
        return 1
    except (P.PaketFel, MarkFel) as e:
        print("\n  ".join(e.fel) if isinstance(e, P.PaketFel) else str(e))
        return 1
    srv = server(sida(d, bild, True, ut.name), ut, a.port)
    url = f"http://127.0.0.1:{srv.server_address[1]}/?k={srv.nyckel}"
    print(f"Märkningen sparas i {ut}\nSidan: {url}\nTryck Klar på sidan (eller Ctrl+C här) när du är klar.", flush=True)
    if not a.utan_webblasare:
        webbrowser.open(url)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        srv.server_close()
    d = las(ut)
    print(f"{sum(r['status'] == 'markerad' for r in d['rutor'])} rutor märkta, "
          f"{sum(r['status'] == 'hoppad' for r in d['rutor'])} hoppade, i {ut}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
