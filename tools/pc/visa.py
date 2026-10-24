"""Visaren: ett pass på PC:n som en fristående sida (PLAN S6f).

    python tools/pc/visa.py <dtl.zip> <fo.zip> [--ut <mapp>] [--langd 1.80] [--s3 <mapp>]

Sidan visar det kedjan redan räknar, så att ett trasigt pass syns direkt och ett bra
pass går att granska (VISION: PC:n är facit och verkstad):

- båda vyernas klipp sida vid sida med Visions leder ovanpå, och MediaPipes när S3
  sparat dem (`~/swinglab-s3/<pass>/mediapipe/`, flyttade med S3:s förskjutning,
  METOD MF1), med stegning P1–P10 ur 2D-faserna (METOD M28);
- 3D-figuren ur `tva_kameror.py`:s triangulerade leder (METOD MK5), i takt med klippen,
  och samma leder projicerade tillbaka i båda klippen;
- kamerorna där kalibreringen placerade dem, per uppställning, med Sampson-felet mot
  spärren, vinkeln mellan kamerorna och varje pakets vy-etikett (METOD MK3). En
  uppställning över spärren ritas ändå, märkt: det är den som ska synas;
- måtten per sving (2D per vy, 3D per par) och skälen när 3D hoppades över.

Formspråket är B13: ett mätinstrument, ingen modellerad kropp. Sidan och klippen skrivs
till `~/swinglab-analys/<pass>/` (Johannes data, CLAUDE.md Dataregeln); en utmapp i
repot utanför `data/` vägras. three.js hämtas från cdnjs; utan nät ritas inte 3D, men
klippen och måtten visas.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import sys
import zipfile
from pathlib import Path

import numpy as np

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "pc"

from . import analys as A  # noqa: E402
from . import katalog as KAT  # noqa: E402
from . import paket as P  # noqa: E402
from . import s3_facit as S3F  # noqa: E402
from . import session as S  # noqa: E402
from . import tva_kameror as TK  # noqa: E402
from .format import LEDER_FIL  # noqa: E402
from .kontaktark import BEN  # noqa: E402

FORMAT = "swinglab-visa/1"
UT_ROT = Path.home() / "swinglab-analys"
THREE_JS = "https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"
NASA_OVER_FOTLED = 0.89        # METOD MK9: figurens skala, bara för bilden (kalibreringen saknar skala)
NASA, FOTLEDER = LEDER_FIL.index("nasa"), (LEDER_FIL.index("fotled_v"), LEDER_FIL.index("fotled_h"))


class VisaFel(ValueError):
    """Sidan går inte att bygga. Meddelandet nämner filen, aldrig ett värde."""


# --- 2D: lederna, klippen och MediaPipe ------------------------------------------------

def _tal(v, d: int):
    return round(float(v), d) if v is not None and math.isfinite(v) else None


def _leder_2d(lederna: dict) -> dict:
    """Visions leder som tider och platta [x, y] × 13 i hela bildens pixlar; en led under
    konfidensen 0,3 (METOD M1) är null, som i kedjan."""
    rutor = sorted(lederna["frames"], key=lambda r: r["t"])
    t, xy = [], []
    for r in rutor:
        rad = []
        for j in r["joints"]:
            v, _ = P._led(j, "")
            ok = v is not None and v[2] >= TK.MIN_KONF
            rad += [round(v[0]), round(v[1])] if ok else [None, None]
        t.append(round(float(r["t"]), 4))
        xy.append(rad)
    return {"t": t, "xy": xy}


def _mediapipe(mapp: Path | None, p: P.Paket, s: P.Slag, forskjutning: dict) -> dict | None:
    """S3:s sparade MediaPipe-leder för slaget, på Visions tid: klippets tid tk minus S3:s
    förskjutning och klicket i klippet (METOD MF1). None när de saknas eller inte går att
    läsa. `kand` säger om förskjutningen var känd (annars 0)."""
    if mapp is None or s.klick_i_klipp_s is None:
        return None
    fil = mapp / f"{Path(p.fil).stem}-{s.id}.json"
    try:
        d = json.loads(fil.read_text(encoding="utf-8"))
        rutor = d["frames"]
    except (OSError, json.JSONDecodeError, KeyError, TypeError):
        return None
    d_s = forskjutning.get((p.fil, s.id))
    skift = float(s.klick_i_klipp_s) + (d_s or 0.0) / 1000.0
    t, xy = [], []
    for r in rutor:
        rad = []
        for j in (r.get("joints") or [None] * len(LEDER_FIL)):
            v, _ = P._led(j, "")
            ok = v is not None and v[2] >= TK.MIN_KONF
            rad += [round(v[0]), round(v[1])] if ok else [None, None]
        t.append(round(float(r["tk"]) - skift, 4))
        xy.append(rad)
    return {"t": t, "xy": xy, "kand": d_s is not None}


def _kopiera_klipp(fil: Path, p: P.Paket, ut: Path) -> dict[str, str]:
    """Paketets klipp kopierade till `ut/klipp/`: slagets id → sökvägen från sidan."""
    vag = {}
    mapp = ut / "klipp"
    with zipfile.ZipFile(fil) as z:
        for s in p.slag:
            if not s.klipp:
                continue
            namn = f"{Path(p.fil).stem}-{s.id}{Path(s.klipp).suffix.lower()}"
            mapp.mkdir(parents=True, exist_ok=True)
            (mapp / namn).write_bytes(P.las_ur_zip(z, p.fil, s.klipp))
            vag[s.id] = f"klipp/{namn}"
    return vag


def _matt_2d(rad: dict) -> dict:
    return {k: A.avrunda(k, v) for k, v in sorted(rad.get("matt", {}).items()) if v is not None and math.isfinite(v)}


def _vy_2d(p: P.Paket, s: P.Slag, rad: dict | None, t0: float, klipp: dict, mp_mapp: Path | None,
           forskjutning: dict) -> dict:
    """En vy av ett slag på sidan. Vyns tid är τ + t0, där τ är passets tid för raden
    (träffen = 0, FO:s klocka när slaget är parat)."""
    d_s = forskjutning.get((p.fil, s.id))
    rad = rad or {}
    flytta = lambda d: {k: _tal(v - t0, 4) for k, v in (d or {}).items() if v is not None}  # noqa: E731
    v = {"id": s.id, "serie": s.serie, "dom": s.dom, "t0": round(t0, 5),
         "klipp": klipp.get(s.id), "w": s.lederna["width"], "h": s.lederna["height"],
         "klipp_t": None if s.klick_i_klipp_s is None else round(float(s.klick_i_klipp_s) + (d_s or 0.0) / 1000, 5),
         "klipp_langd": s.klipp_langd_s, "s3_forskjutning": d_s is not None,
         **_leder_2d(s.lederna),
         "mp": _mediapipe(mp_mapp, p, s, forskjutning),
         "positioner": flytta(rad.get("positioner")),
         "faser": flytta({k: rad["faser"][k] for k in ("start", "topp", "traff")} if rad.get("faser") else None),
         "matt": _matt_2d(rad), "fel": rad.get("fel") or rad.get("utelamnat")}
    return v


# --- 3D: kedjan, kamerorna och figuren ----------------------------------------------------

def _kamera_ut(kam, w: int, h: int, s: float) -> dict:
    return {"C": [round(float(x) * s, 4) for x in kam.centrum], "R": np.round(kam.R, 6).tolist(),
            "K": np.round(kam.K, 3).tolist(), "w": w, "h": h}


def _skala(P_alla: list[np.ndarray], langd: float) -> tuple[float, str]:
    """Skalan för visningen: figurens näsa över fotlederna = 0,89 × längden (median över
    rutorna). Utan figur (eller en orimlig) får avståndet mellan kamerorna vara 1."""
    hojd = []
    for X in P_alla:
        z = X[:, NASA, 2] - np.nanmean(X[:, FOTLEDER, 2], axis=1)
        hojd += [float(v) for v in z[np.isfinite(z)]]
    if hojd:
        m = float(np.median(hojd))
        if m > 0:
            return NASA_OVER_FOTLED * langd / m, "langd"
    return 1.0, "kamerorna"


def _P_ut(X: np.ndarray, s: float) -> list:
    return [[None if not math.isfinite(v) else round(float(v) * s, 3) for v in rad.ravel()] for rad in X]


def tre_d(dtl: P.Paket, fo: P.Paket, rader: list[dict], langd: float) -> dict:
    """Kedjan (TK.analysera) en gång, och för varje uppställning kamerorna och de
    triangulerade lederna: kalibreringen räknas om med kedjans synk, som i dess sista
    steg, så att även en uppställning över spärren kan ritas. METOD MK9"""
    grupper: dict = {}
    inre: list = []
    ut = {"hoppat": None, "uppstallningar": [], "par": [], "osaker": [], "utelamnade": [], "session": {},
          "parning": None, "sparr_px": TK.SAMPSON_MAX_PX, "vinkel_ok": list(TK.VINKEL_OK), "min_slag": TK.MIN_SLAG}
    try:
        r = TK.analysera(dtl, fo, rader, inre, grupper=grupper)
    except TK.TreDFel as e:
        r, ut["hoppat"] = None, str(e)
    except Exception as e:  # noqa: BLE001 — som analysen (BESLUT B37): typen, aldrig ett värde
        r, ut["hoppat"] = None, f"3D gick inte ({type(e).__name__})"
    if r is not None:
        ut.update(parning=r["parning"], osaker=r["osaker"], utelamnade=r["utelamnade"],
                  session={m: round(v["median"], 1) for m, v in r["session"].items()})
    else:
        try:
            ut["parning"] = TK.para_slag(dtl, fo)[1]
        except TK.TreDFel:
            pass
    per_slag = {(x["dtl"], x["fo"]): x for x in (r or {}).get("slag", [])}
    kalib = (r or {}).get("kalibrering", [])
    for i, (nyckel, grupp) in enumerate(sorted(grupper.items())):
        sd, sf = nyckel
        u = {"serie": {"dtl": sd, "fo": sf}, "slag": len(grupp), "hoppat": None, "kameror": None}
        if i < len(kalib) and kalib[i].get("hoppat"):
            u["hoppat"] = kalib[i]["hoppat"]
        forsk = (inre[i] or {}).get("forsk") if i < len(inre) else None
        uppA, uppB = TK._upp_i_kamera(fo.serier[sf].lodlinje), TK._upp_i_kamera(dtl.serier[sd].lodlinje)
        try:
            R, t, upp, info = TK.kalibrera(grupp, forsk or [0.0] * len(grupp), uppA, uppB)
        except TK.TreDFel as e:
            u["hoppat"] = u["hoppat"] or str(e)
            ut["uppstallningar"].append(u)
            continue
        info.pop("lodlinje_fel", None)
        u.update(info)
        if u["hoppat"] is None and not info["sampson_px"] <= TK.SAMPSON_MAX_PX:
            u["hoppat"] = "kalibreringen: Sampson-felet är över spärren"
        if forsk is None:
            u["synk"] = "klicket"          # kedjan kom inte till synken: figuren på klicket
        figurer = []
        for d, f in zip(grupp, forsk or [0.0] * len(grupp)):
            kamA, kamB = TK.kameror(d, R, t, upp)
            tg, X, rep = TK.triangulera(kamA, kamB, d, f)
            figurer.append((d, f, kamA, kamB, tg, X, rep))
        s, kalla = _skala([x[5] for x in figurer], langd)
        u["skala"] = kalla
        d0 = figurer[0] if figurer else None
        if d0:
            u["kameror"] = {"fo": _kamera_ut(d0[2], d0[0]["fo"].lederna["width"], d0[0]["fo"].lederna["height"], s),
                            "dtl": _kamera_ut(d0[3], d0[0]["dtl"].lederna["width"], d0[0]["dtl"].lederna["height"], s)}
        for d, f, kamA, kamB, tg, X, rep in figurer:
            x = per_slag.get((d["dtl"].id, d["fo"].id), {})
            ut["par"].append({"dtl": d["dtl"].id, "fo": d["fo"].id, "uppstallning": i, "synk_s": round(f, 5),
                              "KA": np.round(kamA.K, 3).tolist(), "KB": np.round(kamB.K, 3).tolist(),
                              "t": [round(float(v), 5) for v in tg], "P": _P_ut(X, s),
                              "aterprojektion_px": _tal(rep, 1),
                              "matt": {m: round(v, 1) for m, v in x.get("matt", {}).items()},
                              "fel": x.get("fel")})
        ut["uppstallningar"].append(u)
    return ut


# --- sidan ---------------------------------------------------------------------------------

def _paket_ut(p: P.Paket) -> dict:
    tel = p.manifest.get("telefon") or {}
    return {"fil": p.fil, "vy": p.vy, "spelhand": p.spelhand, "slag": len(p.slag),
            "klipp": sum(1 for s in p.slag if s.klipp), "telefon": {k: tel.get(k) for k in ("modell", "roll")},
            "avstand_m": p.avstand_m}


def _matt_info() -> dict:
    """Måttens enhet och beskrivning ur katalogen (för sidans tabell)."""
    info = {}
    try:
        k = json.loads(KAT.KATALOG.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return info
    for e in k.get("matt", []):
        info.setdefault(e["matt"], {"vad": e.get("vad")})
    for e in k.get("tre_d", []):
        info[e["matt"]] = {"vad": e.get("vad"), "namn": e.get("namn")}
    return info


def data(filer: list[Path], paket: list[P.Paket], langd: float, mp_mapp: Path | None, ut: Path,
         s3_fil: Path | None = None, kopiera: bool = True) -> dict:
    """Allt sidan visar. Panelerna: DTL till vänster och FO till höger när paketen är
    märkta så; annars i den ordning de gavs, och 3D hoppas över."""
    vyer = [p.vy for p in paket]
    ordning = sorted(range(len(paket)), key=lambda i: paket[i].vy) if sorted(vyer) == ["dtl", "fo"] \
        else list(range(len(paket)))
    paket = [paket[i] for i in ordning]
    filer = [filer[i] for i in ordning]
    pass_id = paket[0].pass_id
    forskjutning = S3F.las_forskjutningar(pass_id, s3_fil) if s3_fil or mp_mapp else {}
    rader_2d = [r for p in paket for r in A.mat_paket(p, langd)]
    rad = {(r["vy"], r["id"]): r for r in rader_2d}
    klipp = [_kopiera_klipp(f, p, ut) if kopiera else {} for f, p in zip(filer, paket)]

    if sorted(vyer) == ["dtl", "fo"]:
        dtl, fo = paket
        t3 = tre_d(dtl, fo, rader_2d, langd)
    else:
        t3 = {"hoppat": f"båda paketen är märkta {'/'.join(v.upper() for v in vyer)}: 3D kräver ett DTL- och "
                        "ett FO-paket", "uppstallningar": [], "par": [], "osaker": [], "utelamnade": [],
              "session": {}, "parning": None, "sparr_px": TK.SAMPSON_MAX_PX, "vinkel_ok": list(TK.VINKEL_OK),
              "min_slag": TK.MIN_SLAG}
        dtl = fo = None

    # Raderna: de parade slagen (på FO:s klocka, DTL flyttad med synken), sedan de oparade.
    synk = {(x["dtl"], x["fo"]): (i, x["synk_s"]) for i, x in enumerate(t3["par"])}
    sidrader, sedda = [], set()
    if dtl is not None:
        try:
            par, _ = TK.para_slag(dtl, fo)
        except TK.TreDFel:
            par = []
        for sd, sf in par:
            i, f = synk.get((sd.id, sf.id), (None, 0.0))
            sidrader.append({"namn": f"{sd.id} · {sf.id}", "serie": sf.serie, "par": i, "vyer": [
                _vy_2d(dtl, sd, rad.get(("dtl", sd.id)), P.traff_i_serien(dtl, sd) + f, klipp[0], mp_mapp, forskjutning),
                _vy_2d(fo, sf, rad.get(("fo", sf.id)), P.traff_i_serien(fo, sf), klipp[1], mp_mapp, forskjutning)]})
            sedda |= {(0, sd.id), (1, sf.id)}
    for k, p in enumerate(paket):
        for s in p.slag:
            if (k, s.id) in sedda or s.lederna is None:
                continue
            v = [None] * len(paket)
            v[k] = _vy_2d(p, s, rad.get((p.vy, s.id)), P.traff_i_serien(p, s), klipp[k], mp_mapp, forskjutning)
            sidrader.append({"namn": f"{s.id} ({p.vy.upper()})", "serie": s.serie, "par": None, "vyer": v})
    info = _matt_info()
    for k in {k for r in sidrader for v in r["vyer"] if v for k in v["matt"]} | set(TK.MATT):
        info.setdefault(k, {})["enhet"] = A.enhet(k)
    return {"format": FORMAT, "pass": pass_id, "skapad": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
            "langd_m": langd, "paket": [_paket_ut(p) for p in paket], "leder": list(LEDER_FIL),
            "ben": [list(b) for b in BEN], "rader": sidrader, "tre_d": t3, "matt_info": info,
            "mediapipe": mp_mapp is not None and any(v and v["mp"] for r in sidrader for v in r["vyer"])}


def html(d: dict) -> str:
    """Sidan: mallen med datan inbäddad som JSON (ingen server behövs)."""
    blob = json.dumps(d, ensure_ascii=False, separators=(",", ":"), allow_nan=False).replace("</", "<\\/")
    return (MALL.read_text(encoding="utf-8").replace("{{PASS}}", d["pass"]).replace("{{THREE_JS}}", THREE_JS)
            .replace("{{DATA}}", blob))


MALL = Path(__file__).resolve().parent / "visa.html"


def standard_ut(pass_id: str) -> Path:
    return UT_ROT / pass_id


def main(argv=None) -> int:
    from . import historik as H

    ap = argparse.ArgumentParser(description="Ett pass (DTL- och FO-paketet) → en sida att öppna i webbläsaren.")
    ap.add_argument("paket", nargs="+", help="swinglab-<pass>-<vy>.zip, ett per vy (två för 3D)")
    ap.add_argument("--ut", help="mappen (standard ~/swinglab-analys/<pass>/), aldrig i repot utanför data/")
    ap.add_argument("--langd", type=float, help="spelarens längd i m (annars paketet eller historiken)")
    ap.add_argument("--s3", help="S3:s mapp för passet (standard ~/swinglab-s3/<pass>/), för MediaPipes leder")
    ap.add_argument("--utan-klipp", action="store_true", help="kopiera inte klippen (bara lederna)")
    a = ap.parse_args(argv)
    if len(a.paket) > 2:
        print("Högst två paket: ett DTL- och ett FO-paket från samma pass.")
        return 1
    try:
        paket = [P.las(f) for f in a.paket]
    except P.PaketFel as e:
        print("Paketet går inte att läsa:\n  " + "\n  ".join(e.fel))
        return 1
    pass_id = paket[0].pass_id
    if any(p.pass_id != pass_id for p in paket):
        print("Paketen är från olika pass.")
        return 1
    ut = Path(a.ut).expanduser() if a.ut else standard_ut(pass_id)
    if not S.utanfor_repot(ut):
        print("--ut: mappen ligger i repot men inte i data/; passets data får inte hamna i git.")
        return 1
    langd = a.langd or next((p.langd_m for p in paket if p.langd_m), None) or H.spelare(H.ROT).get("spelarens_langd_m")
    if langd is None:
        print("Spelarens längd saknas: ange --langd.")
        return 1
    s3 = Path(a.s3).expanduser() if a.s3 else S3F.UT_ROT / pass_id
    mp = s3 / "mediapipe" if (s3 / "mediapipe").is_dir() else None
    ut.mkdir(parents=True, exist_ok=True)
    try:
        d = data([Path(f) for f in a.paket], paket, langd, mp, ut, s3_fil=s3 / "s3.json", kopiera=not a.utan_klipp)
    except P.PaketFel as e:
        print("Paketet går inte att läsa:\n  " + "\n  ".join(e.fel))
        return 1
    fil = ut / "visa.html"
    fil.write_text(html(d), encoding="utf-8")
    t = d["tre_d"]
    print(f"Pass {pass_id}: {len(d['rader'])} rader, "
          + ", ".join(f"{p['fil']} märkt {p['vy'].upper()}" for p in d["paket"]))
    for u in t["uppstallningar"]:
        namn = f"serie {u['serie']['dtl']} (DTL) mot {u['serie']['fo']} (FO)"
        if "sampson_px" in u:
            print(f"  {namn}: Sampson {u['sampson_px']} px (spärren {t['sparr_px']:g}), "
                  f"{u['vinkel_mellan_kamerorna']}° mellan kamerorna" + (f", hoppad ({u['hoppat']})" if u["hoppat"]
                                                                        else ""))
        else:
            print(f"  {namn}: hoppad ({u['hoppat']})")
    if t["hoppat"]:
        print(f"  3D: hoppat ({t['hoppat']})")
    print(f"  MediaPipe: {'med' if d['mediapipe'] else 'saknas (kör s3_facit.py för att få dem)'}")
    print(f"Skrev {fil}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
