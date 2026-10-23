"""S7: märk klubban för hand på utvalda rutor (PLAN S7, BESLUT B44, METOD MF5–MF6).

    python tools/pc/markera_klubba.py <paket.zip> [fler paket]     # ett pass, gärna DTL och FO
    python tools/pc/markera_klubba.py <video.mov> [--vy fo]         # ett klipp utan paket

Rutorna väljs själva (MF5): adress, topp och tidig nedsving ur Visions faser och P5, plus
några jämnt spridda, för några slag jämnt spridda över passet, i varje vy. En video utan
paket har inga leder: där sprids rutorna jämnt över klippet.

Sidan öppnas i webbläsaren från en server på den här datorn (127.0.0.1, inget nätverk ut).
Klicka grepp, skaftets mitt och klubbhuvudet (hoseln) i den ordningen:

    klick  sätt punkten          1 2 3  välj punkt          X  punkten syns inte
    Enter  rutan klar            mellanslag  hoppa över     ←  föregående ruta
    Z      zooma kring musen     Backsteg  ta bort punkten

Ett förslag (greppet ur handlederna) visas ihåligt och godtas med Enter. Märkningen
sparas efter varje ruta i `swinglab-<pass>-klubba.json` bredvid paketet (formatet i
docs/FORMAT.md, "Klubbans märkning"), och en körning till fortsätter där den slutade.
Filen ska ligga utanför repot: den är Johannes data.
"""
from __future__ import annotations

import argparse
import base64
import json
import math
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

from . import faser as F  # noqa: E402
from . import format as fm  # noqa: E402
from . import kontaktark as KA  # noqa: E402
from . import matt as M  # noqa: E402
from . import paket as P  # noqa: E402
from . import session as S  # noqa: E402
from .format import LEDER_FIL, MIN_KONFIDENS  # noqa: E402

FORMAT = "swinglab-klubba/1"
# BESLUT B44: tre punkter, GolfPose hosel som klubbhuvudets punkt.
PUNKTER = ("grepp", "skaft_mitt", "klubbhuvud")
VAL = ("adress", "topp", "tidig_nedsving", "jamn")
STATUS = ("omarkerad", "markerad", "hoppad")
KALLOR = ("klick", "forslag")

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
    """Greppets förslag: handledernas mitt, eller den som syns (greppregeln, METOD M1).
    Skaftet och klubbhuvudet har inget förslag förrän en detektor finns (S7). METOD MF5"""
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


def valj_rutor(paket: list[tuple[Path, P.Paket]], slag_per_paket: int = SLAG_PER_PAKET,
               jamna: int = JAMNA_PER_SLAG) -> list[dict]:
    """Rutorna att märka i paketen: för valda slag adressen, toppen och tidig nedsving
    (P5, annars toppen + 1/3 av nedsvingen), och `jamna` rutor jämnt mellan adressen och
    finishen; varje tid flyttad till närmaste Vision-ruta och bara inom klippet. METOD MF5"""
    ut = []
    for fil, p in paket:
        kandidater = []
        for s in p.slag:
            if s.dom not in P.MATS or s.detection_wrong or not s.klipp or not s.lederna:
                continue
            try:
                r = M.mat(fm.fran_dict(P.till_sving(p, s, p.langd_m or LANGD_FASER_M)))
            except (fm.FormatFel, F.SvingFel):
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
                           "val": namn.split("-")[0], "t": round(float(rr["t"]), 4), "t_klipp": round(tk, 4),
                           "bredd": bredd, "hojd": hojd, "visad": visad, "status": "omarkerad",
                           "punkter": {n: None for n in PUNKTER}, "forslag": forslag(rr["joints"])})
    return ut


def valj_video(fil: Path, langd_s: float, bredd: int, hojd: int, vy: str | None, n: int = JAMNA_VIDEO) -> list[dict]:
    """En video utan paket: n rutor jämnt över klippet (inga leder, inga faser). METOD MF5"""
    return [{"id": f"video-{k + 1:02d}", "fil": fil.name, "vy": vy, "slag": None, "val": "jamn", "t": None,
             "t_klipp": round((k + 0.5) / n * langd_s, 4), "bredd": bredd, "hojd": hojd,
             "visad": [0, 0, bredd, hojd], "status": "omarkerad", "punkter": {p: None for p in PUNKTER},
             "forslag": {}} for k in range(n)]


# --- formatet ------------------------------------------------------------------------

def ny(rutor: list[dict], kalla: list[str], pass_id: str | None) -> dict:
    return {"format": FORMAT, "pass": pass_id, "kalla": kalla, "punkter": list(PUNKTER),
            "andrad": datetime.now().astimezone().isoformat(timespec="seconds"), "rutor": rutor}


def sla_ihop(ny_d: dict, gammal: dict | None) -> dict:
    """En tidigare märkning behålls: samma id får sin status och sina punkter tillbaka,
    och rutor som inte valdes nu ligger kvar sist."""
    if not gammal:
        return ny_d
    forra = {r["id"]: r for r in gammal["rutor"]}
    rutor = []
    for r in ny_d["rutor"]:
        g = forra.pop(r["id"], None)
        if g is not None:
            r = {**r, "status": g["status"], "punkter": g["punkter"]}
        rutor.append(r)
    return {**ny_d, "rutor": rutor + list(forra.values())}


def _tal(v) -> bool:
    return not isinstance(v, bool) and isinstance(v, (int, float)) and math.isfinite(v)


def _heltal(v) -> bool:
    return not isinstance(v, bool) and isinstance(v, int)


def kontrollera(d) -> list[str]:
    """Formen på märkningen (docs/FORMAT.md, "Klubbans märkning"). Felen nämner rutans
    plats och fältet, aldrig värdet."""
    if not isinstance(d, dict):
        return ["märkningen ska vara ett JSON-objekt"]
    fel = []
    if d.get("format") != FORMAT:
        fel.append(f"format ska vara {FORMAT}")
    if d.get("punkter") != list(PUNKTER):
        fel.append(f"punkter ska vara {list(PUNKTER)}")
    if d.get("pass") is not None and not (isinstance(d["pass"], str) and P.PASS_ID.match(d["pass"])):
        fel.append("pass ska vara yyyyMMdd-HHmmss eller null")
    if not isinstance(d.get("kalla"), list) or not all(isinstance(k, str) for k in d["kalla"]):
        fel.append("kalla ska vara en lista med filnamn")
    if not isinstance(d.get("andrad"), str):
        fel.append("andrad ska vara en tid")
    rutor = d.get("rutor")
    if not isinstance(rutor, list):
        return fel + ["rutor ska vara en lista"]
    ids = set()
    for i, r in enumerate(rutor):
        p = f"rutor[{i}]"
        if not isinstance(r, dict):
            fel.append(f"{p} ska vara ett objekt")
            continue
        if not isinstance(r.get("id"), str) or not r["id"]:
            fel.append(f"{p}.id ska vara text")
        elif r["id"] in ids:
            fel.append(f"{p}.id finns två gånger")
        ids.add(r.get("id"))
        if not isinstance(r.get("fil"), str):
            fel.append(f"{p}.fil ska vara text")
        if r.get("vy") not in ("dtl", "fo", None):
            fel.append(f"{p}.vy ska vara dtl, fo eller null")
        if r.get("slag") is not None and not isinstance(r["slag"], str):
            fel.append(f"{p}.slag ska vara text eller null")
        if r.get("val") not in VAL:
            fel.append(f"{p}.val ska vara en av {', '.join(VAL)}")
        if r.get("t") is not None and not _tal(r["t"]):
            fel.append(f"{p}.t ska vara ett tal eller null")
        if not (_tal(r.get("t_klipp")) and r["t_klipp"] >= 0):
            fel.append(f"{p}.t_klipp ska vara ett tal ≥ 0")
        bh = (r.get("bredd"), r.get("hojd"))
        if not all(_heltal(v) and v > 0 for v in bh):
            fel.append(f"{p}.bredd och hojd ska vara positiva heltal")
            bh = None
        v = r.get("visad")
        if not (isinstance(v, list) and len(v) == 4 and all(_heltal(x) for x in v)):
            fel.append(f"{p}.visad ska vara fyra heltal")
        elif bh and not (v[0] >= 0 and v[1] >= 0 and v[2] > 0 and v[3] > 0
                         and v[0] + v[2] <= bh[0] and v[1] + v[3] <= bh[1]):
            fel.append(f"{p}.visad ska ligga inom bilden")
        if r.get("status") not in STATUS:
            fel.append(f"{p}.status ska vara en av {', '.join(STATUS)}")
        pk = r.get("punkter")
        if not isinstance(pk, dict) or set(pk) != set(PUNKTER):
            fel.append(f"{p}.punkter ska ha exakt {', '.join(PUNKTER)}")
        else:
            for n in PUNKTER:
                q = pk[n]
                if q is None:
                    if r.get("status") == "markerad":
                        fel.append(f"{p}.punkter.{n} saknas i en markerad ruta")
                    continue
                if q == {"syns_inte": True}:
                    continue
                if not (isinstance(q, dict) and set(q) == {"x", "y", "kalla"} and _tal(q["x"]) and _tal(q["y"])
                        and q["kalla"] in KALLOR):
                    fel.append(f"{p}.punkter.{n} ska vara null, {{x, y, kalla}} eller {{syns_inte: true}}")
                elif bh and not (0 <= q["x"] <= bh[0] and 0 <= q["y"] <= bh[1]):
                    fel.append(f"{p}.punkter.{n} ligger utanför bilden")
        fs = r.get("forslag")
        if not isinstance(fs, dict) or not set(fs) <= set(PUNKTER) or not all(
                isinstance(q, dict) and _tal(q.get("x")) and _tal(q.get("y")) and isinstance(q.get("kalla"), str)
                for q in fs.values()):
            fel.append(f"{p}.forslag ska vara {{punkt: {{x, y, kalla}}}}")
        if len(fel) > 30:
            return fel + ["fler fel hoppas över"]
    return fel


def las(fil: Path) -> dict:
    try:
        d = json.loads(Path(fil).read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        raise MarkFel(f"{Path(fil).name}: inte giltig JSON (rad {e.lineno})") from None
    f = kontrollera(d)
    if f:
        raise MarkFel(f"{Path(fil).name}: " + "; ".join(f))
    return d


def skriv(fil: Path, d: dict) -> None:
    f = kontrollera(d)
    if f:
        raise MarkFel("; ".join(f))
    tmp = Path(fil).with_suffix(".del")
    tmp.write_text(json.dumps(d, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    tmp.replace(fil)


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


LasBild = Callable[[Path, float, int, int], "np.ndarray | None"]


def bilder(rutor: list[dict], kallor: dict[str, Path], las_bild: LasBild, rapport=print) -> dict[str, str]:
    """Varje rutas bild (den visade delen) som data-URL. `kallor`: paketets eller
    videons namn → filen. Ett klipp ur ett paket packas upp en gång. METOD MF6"""
    ut = {}
    with tempfile.TemporaryDirectory() as tmp:
        uppackade: dict[tuple[str, str], Path] = {}
        for k, r in enumerate(rutor):
            fil = kallor.get(r["fil"])
            if fil is None:
                continue
            if fil.suffix.lower() == ".zip":
                p = P.las(fil, med_leder=False)
                s = next((x for x in p.slag if x.id == r["slag"]), None)
                if s is None or not s.klipp:
                    continue
                nyckel = (r["fil"], s.klipp)
                if nyckel not in uppackade:
                    dst = Path(tmp) / f"{len(uppackade)}{Path(s.klipp).suffix}"
                    with zipfile.ZipFile(fil) as z:
                        dst.write_bytes(P.las_ur_zip(z, p.fil, s.klipp))
                    uppackade[nyckel] = dst
                klipp = uppackade[nyckel]
            else:
                klipp = fil
            img = las_bild(klipp, r["t_klipp"], r["bredd"], r["hojd"])
            if img is None:
                continue
            x, y, b, h = r["visad"]
            ut[r["id"]] = koda(img[y:y + h, x:x + b])
            if rapport and (k + 1) % 10 == 0:
                rapport(f"  {k + 1} av {len(rutor)} rutor lästa", flush=True)
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
<div id="hjalp">Klick sätt punkten · 1–3 välj punkt · X syns inte · Backsteg ta bort · Enter rutan klar (godtar förslag) · Mellanslag hoppa över · ← föregående · Z zoom.
Grepp = skaftet mitt mellan händerna · Skaftets mitt = mitt mellan grepp och hosel · Klubbhuvud = hoseln, där skaftet går in i huvudet.</div>
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
function tillBild(x, y) {
  const v = ruta().visad;
  return {x: v[0] + (x - vy.ox) / vy.s, y: v[1] + (y - vy.oy) / vy.s};
}
function tillSkarm(q) {
  const v = ruta().visad;
  return {x: vy.ox + (q.x - v[0]) * vy.s, y: vy.oy + (q.y - v[1]) * vy.s};
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
let sparar = null;
function spara() {
  D.andrad = new Date().toISOString();
  if (!L.server) { document.getElementById("sparat").textContent = "inte sparad: ladda ner"; return Promise.resolve(); }
  sparar = fetch("/spara", {method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify(D)})
    .then(svar => { document.getElementById("sparat").textContent = svar.ok ? "sparad" : "kunde inte spara"; })
    .catch(() => { document.getElementById("sparat").textContent = "servern svarar inte: ladda ner"; });
  return sparar;
}
function ga(steg) {
  i = Math.min(D.rutor.length - 1, Math.max(0, i + steg));
  zoom = false;
  ladda();
}
function klar() {
  const r = ruta();
  PUNKTER.forEach(n => {
    if (!r.punkter[n] && r.forslag[n]) r.punkter[n] = {x: r.forslag[n].x, y: r.forslag[n].y, kalla: "forslag"};
  });
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
  spara().then(() => L.server ? fetch("/klar", {method: "POST"}) : null).then(() => {
    document.body.textContent = "Klart. Märkningen ligger i " + L.filnamn + ". Fönstret kan stängas.";
  });
});
window.addEventListener("resize", rita);
ladda();
"""


# --- servern -------------------------------------------------------------------------

MAX_BYTES = 50 * 1024 * 1024


def server(html: str, fil: Path, port: int = 0) -> ThreadingHTTPServer:
    """En server på 127.0.0.1 som visar sidan och sparar märkningen i `fil`. /klar
    stänger den."""
    sidan = html.encode("utf-8")

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

        def do_GET(self):
            if self.path in ("/", "/index.html"):
                self._svar(200, "text/html; charset=utf-8", sidan)
            else:
                self._svar(404, "text/plain", b"")

        def do_POST(self):
            n = int(self.headers.get("Content-Length") or 0)
            if n > MAX_BYTES:
                self._svar(413, "text/plain", b"")
                return
            kropp = self.rfile.read(n)
            if self.path == "/spara":
                try:
                    skriv(fil, json.loads(kropp.decode("utf-8")))
                except (MarkFel, json.JSONDecodeError, UnicodeDecodeError) as e:
                    self._svar(400, "text/plain; charset=utf-8", str(e)[:500].encode("utf-8"))
                    return
                self._svar(200, "application/json", b'{"ok":true}')
            elif self.path == "/klar":
                self._svar(200, "application/json", b'{"ok":true}')
                threading.Thread(target=self.server.shutdown, daemon=True).start()
            else:
                self._svar(404, "text/plain", b"")

    return ThreadingHTTPServer(("127.0.0.1", port), H)


# --- kommandot -----------------------------------------------------------------------

def _video_info(fil: Path) -> tuple[float, int, int]:
    """(längd i s, bredd, höjd) upprätt, med OpenCV."""
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
    return n / fps, ram.shape[1], ram.shape[0]


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="S7: märk grepp, skaftets mitt och klubbhuvudet på utvalda rutor.")
    ap.add_argument("in_", nargs="+", metavar="paket.zip|video.mov")
    ap.add_argument("--ut", help="märkningens fil (standard bredvid första filen)")
    ap.add_argument("--slag", type=int, default=SLAG_PER_PAKET, help="slag per paket")
    ap.add_argument("--jamna", type=int, help=f"jämnt spridda rutor per slag ({JAMNA_PER_SLAG}) eller per video "
                                              f"({JAMNA_VIDEO})")
    ap.add_argument("--vy", choices=("dtl", "fo"), help="vyn för en video utan paket")
    ap.add_argument("--port", type=int, default=0)
    ap.add_argument("--utan-webblasare", action="store_true", help="öppna inte webbläsaren, skriv bara adressen")
    a = ap.parse_args(argv)
    filer = [Path(f).expanduser() for f in a.in_]
    try:
        zippar = [f for f in filer if f.suffix.lower() == ".zip"]
        if zippar and len(zippar) != len(filer):
            raise MarkFel("Ge antingen paket (.zip) eller videor, inte båda.")
        if zippar:
            paket = [(f, P.las(f)) for f in zippar]
            pass_id = paket[0][1].pass_id
            rutor = valj_rutor(paket, a.slag, JAMNA_PER_SLAG if a.jamna is None else a.jamna)
            standard = zippar[0].parent / f"swinglab-{pass_id}-klubba.json"
        else:
            pass_id, rutor = None, []
            for f in filer:
                langd, b, h = _video_info(f)
                rutor += valj_video(f, langd, b, h, a.vy, JAMNA_VIDEO if a.jamna is None else a.jamna)
            standard = filer[0].parent / f"{filer[0].stem}-klubba.json"
        ut = Path(a.ut).expanduser() if a.ut else standard
        if not S.utanfor_repot(ut.parent):
            raise MarkFel("Märkningen får inte ligga i repot: den är Johannes data.")
        if not rutor:
            raise MarkFel("Inga rutor att märka: paketen saknar klipp till mätta slag.")
        satt = KA.verktyg()
        if satt is None:
            raise MarkFel("Bilderna kräver OpenCV eller ffmpeg: pip install opencv-python")
        gammal = las(ut) if ut.is_file() else None
        d = sla_ihop(ny(rutor, [f.name for f in filer], pass_id), gammal)
        print(f"{len(d['rutor'])} rutor, varav {sum(r['status'] == 'omarkerad' for r in d['rutor'])} omärkta. "
              "Läser bilderna …", flush=True)
        bild = bilder(d["rutor"], {f.name: f for f in filer},
                      lambda k, t, b, h: KA.las_ruta(k, t, b, h, satt))
        skriv(ut, d)
    except (P.PaketFel, MarkFel) as e:
        print("\n  ".join(e.fel) if isinstance(e, P.PaketFel) else str(e))
        return 1
    srv = server(sida(d, bild, True, ut.name), ut, a.port)
    url = f"http://127.0.0.1:{srv.server_address[1]}/"
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
