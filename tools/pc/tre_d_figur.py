"""Figuren på telefonen (PLAN S6d): kedjans triangulerade leder per slag och kamerorna per
uppställning, som telefonen sparar i passets mapp (docs/FORMAT.md "Figuren i 3D").

    python3 tools/pc/tre_d_figur.py   # skriver tools/tests/fixturer/tre_d/figur.json (facit för Swift)

Det här är facit för SwingLabKit:s `TreDFigurer` (BESLUT B12, B72): samma kedja
(`tva_kameror.analysera`), samma kameror (kalibreringens sista anrop, METOD MK3, MK4), samma
triangulering (MK5). Skalan är benens längd (höft–knä–fotled = 0,491 × längden), inte
visarens näsa över fotlederna (MK9), som gör figuren 15–30 % för stor i en böjd hållning
(METOD MK10). Telefonen räknar själv; PC:n läser inte telefonens figur.

- En uppställning som kalibrerades (även en över spärren) får kamerorna, skalan och markens
  höjd (fotledernas median minus fotledens höjd); bara en som inte hoppades över får figurerna (BESLUT B72: ingen figur där skälet
  säger nej).
- Positionerna P1–P10 (kroppens, METOD M28) per slag på figurens tid: FO:s, annars DTL:s
  flyttad med synken, som baksvingens start i MK6.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "pc"

from . import tva_kameror as TK  # noqa: E402
from .format import LEDER_FIL  # noqa: E402

FORMAT = "swinglab-tre-d-figur/1"
POSITIONER = ("P1", "P3", "P4", "P5", "P7", "P9", "P10")      # kroppens, METOD M28
FOTLEDER = (LEDER_FIL.index("fotled_v"), LEDER_FIL.index("fotled_h"))
# Benen per sida: höft, knä, fotled (index i lederna).
BEN = ((LEDER_FIL.index("hoft_v"), LEDER_FIL.index("kna_v"), LEDER_FIL.index("fotled_v")),
       (LEDER_FIL.index("hoft_h"), LEDER_FIL.index("kna_h"), LEDER_FIL.index("fotled_h")))
BENETS_ANDEL = 0.245 + 0.246      # lår + smalben av längden, Drillis och Contini 1966. METOD MK10
FOTLED_ANDEL = 0.039              # fotledens höjd över marken av längden (samma källa). METOD MK10


def skala(figurer: list[np.ndarray], langd: float) -> tuple[float, str]:
    """Meter per enhet i kalibreringens värld: benets längd (lår + smalben, båda sidor, alla
    rutor i uppställningens slag, medianen) = 0,491 × längden. Utan ben (eller ett orimligt)
    får avståndet mellan kamerorna vara 1. Bara för bilden: inget mått beror på den. METOD MK10"""
    ben = []
    for X in figurer:
        for h, k, f in BEN:
            b = np.linalg.norm(X[:, h] - X[:, k], axis=1) + np.linalg.norm(X[:, k] - X[:, f], axis=1)
            ben += [float(v) for v in b[np.isfinite(b)]]
    if ben:
        m = float(np.median(ben))
        if m > 0:
            return BENETS_ANDEL * langd / m, "langd"
    return 1.0, "kamerorna"


def positioner(rad_fo: dict | None, rad_dtl: dict | None, d: dict, forsk: float) -> dict:
    """Slagets positioner på figurens tid (träffen = 0 på FO:s klocka): FO:s, annars DTL:s
    flyttad med synken, position för position. METOD MK10"""
    ut = {}
    for p in POSITIONER:
        for rad, skift in ((rad_fo, d["traffA"]), (rad_dtl, d["traffB"] + forsk)):
            v = ((rad or {}).get("positioner") or {}).get(p)
            if v is not None and math.isfinite(v):
                ut[p] = float(v) - skift
                break
    return ut


def _kamera(kam, w: int, h: int, s: float) -> dict:
    return {"C": [float(x) * s for x in kam.centrum], "R": [float(x) for x in kam.R.ravel()],
            "K": [float(x) for x in kam.K.ravel()], "w": int(w), "h": int(h)}


def figurer(dtl, fo, rader: list[dict], langd: float) -> dict:
    """Passets figur: uppställningarna med kamerorna och slagen med lederna (m, världens ram
    med z uppåt, FO-kameran i origo) eller skälet. `rader` är 2D-analysens slag
    (analys.mat_paket) för båda paketen. METOD MK10"""
    grupper: dict = {}
    inre: list = []
    hoppat, kalib = None, []
    try:
        r = TK.analysera(dtl, fo, rader, inre, grupper=grupper)
        kalib = r["kalibrering"]
    except TK.TreDFel as e:
        hoppat, kalib = str(e), e.delvis.get("kalibrering", [])
    rad = {(x["vy"], x["id"]): x for x in rader}
    ut = {"format": FORMAT, "hand": dtl.spelhand, "hoppat": hoppat, "uppstallningar": [], "slag": []}
    for i, (_, grupp) in enumerate(sorted(grupper.items())):
        info = kalib[i] if i < len(kalib) else {}
        u = {"serie": {"dtl": grupp[0]["dtl"].serie, "fo": grupp[0]["fo"].serie}, "slag": len(grupp),
             "hoppat": info.get("hoppat"), "sampson_px": info.get("sampson_px"),
             "vinkel": info.get("vinkel_mellan_kamerorna"), "vinkel_ok": info.get("vinkel_ok"),
             "skala": None, "skala_m": None, "golv": None, "kameror": None}
        ut["uppstallningar"].append(u)
        if i >= len(inre) or inre[i] is None:
            continue
        R, t, upp = np.array(inre[i]["R"]), np.array(inre[i]["t"]), np.array(inre[i]["upp"])
        forsk = inre[i]["forsk"]
        tri = [TK.triangulera(*TK.kameror(d, R, t, upp), d, f) for d, f in zip(grupp, forsk)]
        s, kalla = skala([x[1] for x in tri], langd)
        fot = np.concatenate([x[1][:, FOTLEDER, 2].ravel() for x in tri]) if tri else np.array([])
        fot = fot[np.isfinite(fot)]
        kamA, kamB = TK.kameror(grupp[0], R, t, upp)
        d0 = grupp[0]
        u.update(skala=kalla, skala_m=s, golv=float(np.median(fot)) * s - FOTLED_ANDEL * langd if len(fot) else None,
                 kameror={"fo": _kamera(kamA, d0["fo"].lederna["width"], d0["fo"].lederna["height"], s),
                          "dtl": _kamera(kamB, d0["dtl"].lederna["width"], d0["dtl"].lederna["height"], s)})
        if u["hoppat"] is not None:
            continue                              # BESLUT B72: ingen figur där skälet säger nej
        for d, f, (tg, X, _) in zip(grupp, forsk, tri):
            ut["slag"].append({"dtl": d["dtl"].id, "fo": d["fo"].id, "uppstallning": i, "synk_s": float(f),
                               "t": tg, "P": X * s,
                               "positioner": positioner(rad.get(("fo", d["fo"].id)), rad.get(("dtl", d["dtl"].id)),
                                                        d, f)})
    return ut


# --- facit för Swift (tools/tests/fixturer/tre_d/figur.json) ----------------------------

FIXTUR_PASS = ("utan_brus", "bra_brus_vanster", "sparren")


def _rena(x):
    if isinstance(x, dict):
        return {k: _rena(v) for k, v in x.items()}
    if isinstance(x, (list, tuple)):
        return [_rena(v) for v in x]
    if isinstance(x, (float, np.floating)):
        return float(x) if math.isfinite(x) else None
    if isinstance(x, np.integer):
        return int(x)
    if isinstance(x, np.bool_):
        return bool(x)
    return x


def sammandrag(f: dict) -> dict:
    """Figuren i fixturens form: allt utom lederna, och per slag tidsaxeln, fyra rutor hela
    och summan och antalet av de leder som finns (så att filen förblir liten)."""
    ut = {k: v for k, v in f.items() if k != "slag"}
    ut["slag"] = []
    for s in f["slag"]:
        t, P = np.asarray(s["t"]), np.asarray(s["P"])
        n = len(t)
        index = sorted({0, n // 3, 2 * n // 3, n - 1})
        fin = P[np.isfinite(P)]
        ut["slag"].append({k: s[k] for k in ("dtl", "fo", "uppstallning", "synk_s", "positioner")} | {
            "n": n, "t0": float(t[0]), "t_sista": float(t[-1]), "index": index,
            "P": [P[i].ravel().tolist() for i in index], "summa": float(fin.sum()), "antal": int(fin.size)})
    return _rena(ut)


def fixtur(namn: str, mapp) -> dict:
    """Ett fixturpass figur (tools/pc/generera_tre_d.py:s indata), med 2D-analysen ur paketen."""
    from . import analys as A
    from . import generera_tre_d as G
    indata = G.las_indata(namn)
    dtl, fo = G.paketen(indata, {}, mapp)
    langd = indata["langd_m"]
    rader = A.mat_paket(dtl, langd) + A.mat_paket(fo, langd)
    return sammandrag(figurer(dtl, fo, rader, langd))


def main() -> int:
    import json
    import shutil
    import tempfile

    from . import generera_tre_d as G
    tmp = Path(tempfile.mkdtemp())
    try:
        d = {"om": G.OM.replace("generera_tre_d.py", "tre_d_figur.py"), "langd_m": G.LANGD_M,
             "pass": {namn: fixtur(namn, tmp) for namn in FIXTUR_PASS}}
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    fil = G.MAPP / "figur.json"
    fil.write_text(json.dumps(d, ensure_ascii=False, allow_nan=False, indent=1) + "\n", encoding="utf-8")
    print(fil)
    return 0


if __name__ == "__main__":
    sys.exit(main())
