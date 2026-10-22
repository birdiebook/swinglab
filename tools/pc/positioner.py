"""P-positionerna ur kroppens leder (BESLUT B32): P1 Adress, P3, P4 Topp, P5,
P7 Träff, P9 och P10 Finish. METOD M28

P1, P4, P7 och P10 är faserna (METOD M4). P3, P5 och P9 är armen vågrät i
bildens plan: vinkeln α mellan armen (axeln → den egna handleden) och vågrätt,
+ när handleden står över axeln. Positionen är tiden då α passerar 0, linjärt
mellan två rutor där armen syns. Blir armen aldrig vågrät saknas positionen:
den gissas aldrig. P2, P6 och P8 kräver klubban (PLAN S7).

Lederna är redan främre och bakre (format.py), så en vänsterspelare speglas:
främre armen är vänsterarmen för en högerspelare och högerarmen för en
vänsterspelare.
"""
from __future__ import annotations

import numpy as np

from . import faser as F

POSITIONER = ("P1", "P3", "P4", "P5", "P7", "P9", "P10")
P9_EFTER_S = F.FINISH[0]     # METOD M28: P9 söks från träffen till finishens fönster (1,0 s)


def armens_hojd(axel: np.ndarray, handled: np.ndarray) -> np.ndarray:
    """Handledens höjd över axeln per ruta, px: axel_y − handled_y (y nedåt), +
    när handleden står över axeln. 0 = armen vågrät (vinkeln α mot vågrätt är 0,
    åt vilket håll armen än pekar). NaN där en av punkterna saknas. Nollstället
    interpoleras på höjden, inte på α: atan böjer kurvan när armen är kort i
    bild (|Δx| litet), och då hamnar nollstället fel. METOD M28"""
    syns = np.isfinite(axel).all(axis=1) & np.isfinite(handled).all(axis=1)
    return np.where(syns, axel[:, 1] - handled[:, 1], np.nan)


def passager(t: np.ndarray, h: np.ndarray, fran: float, till: float) -> list[tuple[float, float, float, bool]]:
    """Armens passager genom vågrätt mellan fran och till, i tidsordning:
    (tid, t0, t1, uppåt). Uppåt: h0 < 0 ≤ h1, nedåt: h0 ≥ 0 > h1, mellan två
    rutor i följd där armen syns, båda inom fönstret och högst MAX_LUCKA_S isär
    (METOD M3), linjärt mellan dem. METOD M28"""
    idx = np.where(np.isfinite(h) & (t >= fran) & (t <= till))[0]
    ut = []
    for i in range(1, len(idx)):
        k0, k1 = idx[i - 1], idx[i]
        t0, t1 = float(t[k0]), float(t[k1])
        if t1 - t0 > F.MAX_LUCKA_S:
            continue
        h0, h1 = float(h[k0]), float(h[k1])
        upp, ned = h0 < 0 <= h1, h0 >= 0 > h1
        if upp or ned:
            ut.append((t0 + (0.0 - h0) / (h1 - h0) * (t1 - t0), t0, t1, upp))
    return ut


def _nagon(h: np.ndarray, sel: np.ndarray, villkor) -> bool:
    """Någon ruta i urvalet där armen syns och villkoret gäller höjden."""
    sel = sel & np.isfinite(h)
    return bool(np.any(villkor(h[sel])))


def hitta(t: np.ndarray, f: F.Faser, framre: np.ndarray, bakre: np.ndarray) -> dict[str, float | None]:
    """Positionernas tider (s), None där positionen saknas. `framre` och `bakre`
    är armens höjd per ruta (armens_hojd). METOD M28

      P1   adressens fönster, tiden i fönstrets mitt (måtten är fönstrets medel)
      P3   sista passagen uppåt för främre armen, från adressens slut, med rutparet
           över toppen (t0 ≤ toppen)
      P4   toppen
      P5   första passagen nedåt för främre armen till träffen, med rutparet över
           toppen (t1 ≥ toppen)
      P7   träffen (klicket)
      P9   första passagen uppåt för bakre armen, från träffen och 1,0 s fram
      P10  finishens fönster, tiden i fönstrets mitt

    Ingen passage gissas över en lucka: P3 saknas om armen syns under vågrätt
    någon gång mellan P3 och toppen, P5 om den syns under vågrätt mellan toppen
    och P5, och P9 om bakre armen syns vid eller över vågrätt mellan träffen och P9.
    """
    fr = passager(t, framre, f.adress[1], f.traff)
    upp = [p[0] for p in fr if p[3] and p[1] <= f.topp]
    ned = [p[0] for p in fr if not p[3] and p[2] >= f.topp]
    p3 = upp[-1] if upp else None
    p5 = ned[0] if ned else None
    if p3 is not None and _nagon(framre, (t > p3) & (t <= f.topp), lambda h: h < 0):
        p3 = None
    if p5 is not None and _nagon(framre, (t >= f.topp) & (t < p5), lambda h: h < 0):
        p5 = None
    bk = [p[0] for p in passager(t, bakre, f.traff, f.traff + P9_EFTER_S) if p[3]]
    p9 = bk[0] if bk else None
    if p9 is not None and _nagon(bakre, (t >= f.traff) & (t < p9), lambda h: h >= 0):
        p9 = None
    return {"P1": (f.adress[0] + f.adress[1]) / 2,
            "P3": p3,
            "P4": f.topp,
            "P5": p5,
            "P7": f.traff,
            "P9": p9,
            "P10": (f.finish[0] + f.finish[1]) / 2}
