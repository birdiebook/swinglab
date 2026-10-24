"""Figuren på telefonen (PLAN S6d): kedjans triangulerade leder per slag och kamerorna per
uppställning, som telefonen sparar i passets mapp (docs/FORMAT.md "Figuren i 3D").

    python3 tools/pc/tre_d_figur.py   # skriver tools/tests/fixturer/tre_d/figur.json (facit för Swift)

Det här är facit för SwingLabKit:s `TreDFigurer` (BESLUT B12, B72): samma kedja
(`tva_kameror.analysera`), samma kameror (kalibreringens sista anrop, METOD MK3, MK4), samma
triangulering (MK5). Skalan är benens längd i adressen (höft–knä–fotled = 0,491 × längden,
METOD MK10), samma i PC:ns visare (MK9). Telefonen räknar själv; PC:n läser inte telefonens
figur.

- En uppställning som kalibrerades (även en över spärren) får kamerorna, skalan och markens
  höjd (fotledernas median i adressen minus fotledens höjd), eller reserven med skälet; bara en som inte hoppades över får figurerna (BESLUT B72: ingen figur där skälet
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
# Kedjans version för figuren: höjs när MK10 ändras, så att telefonen räknar om (BESLUT B72).
KEDJA = 2
POSITIONER = ("P1", "P3", "P4", "P5", "P7", "P9", "P10")      # kroppens, METOD M28
FOTLEDER = (LEDER_FIL.index("fotled_v"), LEDER_FIL.index("fotled_h"))
# Benen per sida: höft, knä, fotled (index i lederna).
BEN = ((LEDER_FIL.index("hoft_v"), LEDER_FIL.index("kna_v"), LEDER_FIL.index("fotled_v")),
       (LEDER_FIL.index("hoft_h"), LEDER_FIL.index("kna_h"), LEDER_FIL.index("fotled_h")))
BENETS_ANDEL = 0.245 + 0.246      # lår + smalben av längden, Drillis och Contini 1966. METOD MK10
FOTLED_ANDEL = 0.039              # fotledens höjd över marken av längden (samma källa). METOD MK10


# Skyddet runt skalan (METOD MK10): sidornas ben får skilja så mycket, och kamerorna ska hamna
# så långt från stansen och så högt över marken med skalan, annars används reserven.
BEN_SKILLNAD = 0.10
KAMERA_AVSTAND_M = (1.5, 8.0)
KAMERA_HOJD_M = (0.5, 1.8)
ADRESS_EFTER_P1_S = 0.15          # adressens rutor: fram till P1 + 0,15 s (utan P1 de första 0,3 s)
ADRESS_RESERV_RUTOR = 72          # utan rutor före gränsen: de första så många


def adressens_rutor(t: np.ndarray, positioner: dict) -> np.ndarray:
    """Rutorna i adressen: fram till P1 + 0,15 s, utan P1 slagets första 0,3 s; finns ingen,
    de första 72. METOD MK10, MK11"""
    t = np.asarray(t)
    if not len(t):
        return np.array([], dtype=int)
    p1 = positioner.get("P1")
    slut = (p1 if p1 is not None else float(t[0]) + ADRESS_EFTER_P1_S) + ADRESS_EFTER_P1_S
    r = np.where(t <= slut)[0]
    return r if len(r) else np.arange(min(len(t), ADRESS_RESERV_RUTOR))


def _reserv(fel: str) -> dict:
    return {"skala": "kamerorna", "skala_m": 1.0, "golv": None, "skala_fel": fel}


def skala(figurer: list[tuple[np.ndarray, np.ndarray]], langd: float, kameror: list[np.ndarray]) -> dict:
    """Meter per enhet i kalibreringens värld, och markens höjd (METOD MK10), ur uppställningens
    figurer i adressen (`figurer`: lederna och adressens rutor per slag): benets längd (lår +
    smalben, medianen över båda sidor och alla rutor) = 0,491 × längden, och marken =
    fotledernas median − 0,039 × längden. Reserven (avståndet mellan kamerorna = 1, ingen mark)
    med skälet när benen saknas, när sidorna skiljer mer än 10 %, eller när en kamera (`kameror`,
    centrum i kalibreringens enheter) då hamnar närmare än 1,5 m eller längre än 8 m från
    stansen, eller lägre än 0,5 m eller högre än 1,8 m över marken. Bara för bilden: inget mått
    beror på den."""
    sidor: tuple[list, list] = ([], [])
    fot: list[float] = []
    stans: dict = {j: ([], []) for j in FOTLEDER}
    for X, rutor in figurer:
        A = X[rutor]
        for (h, k, f), lista in zip(BEN, sidor):
            b = np.linalg.norm(A[:, h] - A[:, k], axis=1) + np.linalg.norm(A[:, k] - A[:, f], axis=1)
            lista += [float(v) for v in b[np.isfinite(b)]]
        for j in FOTLEDER:
            z = A[:, j, 2]
            fot += [float(v) for v in z[np.isfinite(z)]]
            ok = np.isfinite(A[:, j]).all(axis=1)
            stans[j][0].extend(float(v) for v in A[ok, j, 0])
            stans[j][1].extend(float(v) for v in A[ok, j, 1])
    v, h = sidor
    if not v or not h:
        return _reserv("benen syns inte i adressen")
    mv, mh = float(np.median(v)), float(np.median(h))
    if not abs(mv - mh) <= BEN_SKILLNAD * max(mv, mh):
        return _reserv("benen skiljer mer än 10 % mellan sidorna")
    m = float(np.median(v + h))
    if not (m > 0 and fot):
        return _reserv("benen syns inte i adressen")
    s = BENETS_ANDEL * langd / m
    golv = float(np.median(fot)) * s - FOTLED_ANDEL * langd
    mitt = [(float(np.median(stans[j][0])), float(np.median(stans[j][1]))) for j in FOTLEDER if stans[j][0]]
    sx, sy = sum(p[0] for p in mitt) / len(mitt) * s, sum(p[1] for p in mitt) / len(mitt) * s
    for C in kameror:
        avst = math.hypot(float(C[0]) * s - sx, float(C[1]) * s - sy)
        hojd = float(C[2]) * s - golv
        if not (KAMERA_AVSTAND_M[0] <= avst <= KAMERA_AVSTAND_M[1] and KAMERA_HOJD_M[0] <= hojd <= KAMERA_HOJD_M[1]):
            return _reserv("kamerorna hamnar orimligt med benens skala")
    return {"skala": "langd", "skala_m": s, "golv": golv, "skala_fel": None}


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
    ut = {"format": FORMAT, "kedja": KEDJA, "hand": dtl.spelhand, "hoppat": hoppat, "uppstallningar": [], "slag": []}
    for i, (_, grupp) in enumerate(sorted(grupper.items())):
        info = kalib[i] if i < len(kalib) else {}
        u = {"serie": {"dtl": grupp[0]["dtl"].serie, "fo": grupp[0]["fo"].serie}, "slag": len(grupp),
             "hoppat": info.get("hoppat"), "sampson_px": info.get("sampson_px"),
             "vinkel": info.get("vinkel_mellan_kamerorna"), "vinkel_ok": info.get("vinkel_ok"),
             "skala": None, "skala_m": None, "golv": None, "skala_fel": None, "kameror": None}
        ut["uppstallningar"].append(u)
        if i >= len(inre) or inre[i] is None:
            continue
        R, t, upp = np.array(inre[i]["R"]), np.array(inre[i]["t"]), np.array(inre[i]["upp"])
        forsk = inre[i]["forsk"]
        tri = [TK.triangulera(*TK.kameror(d, R, t, upp), d, f) for d, f in zip(grupp, forsk)]
        pos = [positioner(rad.get(("fo", d["fo"].id)), rad.get(("dtl", d["dtl"].id)), d, f) for d, f in zip(grupp, forsk)]
        kamA, kamB = TK.kameror(grupp[0], R, t, upp)
        sk = skala([(x[1], adressens_rutor(x[0], p)) for x, p in zip(tri, pos)], langd, [kamA.centrum, kamB.centrum])
        s = sk["skala_m"]
        d0 = grupp[0]
        u.update(sk, kameror={"fo": _kamera(kamA, d0["fo"].lederna["width"], d0["fo"].lederna["height"], s),
                              "dtl": _kamera(kamB, d0["dtl"].lederna["width"], d0["dtl"].lederna["height"], s)})
        if u["hoppat"] is not None:
            continue                              # BESLUT B72: ingen figur där skälet säger nej
        for d, f, (tg, X, _), p in zip(grupp, forsk, tri, pos):
            ut["slag"].append({"dtl": d["dtl"].id, "fo": d["fo"].id, "uppstallning": i, "synk_s": float(f),
                               "t": tg, "P": X * s, "positioner": p})
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
