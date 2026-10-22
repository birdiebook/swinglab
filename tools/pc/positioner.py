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


def armens_vinkel(axel: np.ndarray, handled: np.ndarray) -> np.ndarray:
    """α per ruta i grader: armen axel → handled mot vågrätt i bild, + när
    handleden står över axeln (y nedåt). NaN där en av punkterna saknas.
    Riktningen i x räknas inte: vågrät åt vilket håll som helst. METOD M28"""
    dx = handled[:, 0] - axel[:, 0]
    dy = axel[:, 1] - handled[:, 1]
    return np.degrees(np.arctan2(dy, np.abs(dx)))


def passager(t: np.ndarray, a: np.ndarray, fran: float, till: float, uppat: bool) -> list[float]:
    """Tiderna då α passerar 0 mellan fran och till, i tidsordning. Uppåt:
    α0 < 0 ≤ α1, nedåt: α0 ≥ 0 > α1, mellan två rutor i följd där armen syns,
    båda inom fönstret och högst MAX_LUCKA_S isär (METOD M3), linjärt mellan
    dem. METOD M28"""
    idx = np.where(np.isfinite(a) & (t >= fran) & (t <= till))[0]
    ut = []
    for i in range(1, len(idx)):
        k0, k1 = idx[i - 1], idx[i]
        if t[k1] - t[k0] > F.MAX_LUCKA_S:
            continue
        a0, a1 = float(a[k0]), float(a[k1])
        if (a0 < 0 <= a1) if uppat else (a0 >= 0 > a1):
            ut.append(float(t[k0] + (0.0 - a0) / (a1 - a0) * (t[k1] - t[k0])))
    return ut


def hitta(t: np.ndarray, f: F.Faser, framre: np.ndarray, bakre: np.ndarray) -> dict[str, float | None]:
    """Positionernas tider (s), None där positionen saknas. `framre` och `bakre`
    är armens vinkel per ruta (armens_vinkel). METOD M28

      P1   adressens fönster, tiden i fönstrets mitt (måtten är fönstrets medel)
      P3   sista gången främre armen går upp till vågrätt, från adressens slut till toppen
      P4   toppen
      P5   första gången främre armen går ner under vågrätt, från toppen till träffen
      P7   träffen (klicket)
      P9   första gången bakre armen går upp till vågrätt, från träffen och 1,0 s fram
      P10  finishens fönster, tiden i fönstrets mitt
    """
    p3 = passager(t, framre, f.adress[1], f.topp, uppat=True)
    p5 = passager(t, framre, f.topp, f.traff, uppat=False)
    p9 = passager(t, bakre, f.traff, f.traff + P9_EFTER_S, uppat=True)
    return {"P1": (f.adress[0] + f.adress[1]) / 2,
            "P3": p3[-1] if p3 else None,
            "P4": f.topp,
            "P5": p5[0] if p5 else None,
            "P7": f.traff,
            "P9": p9[0] if p9 else None,
            "P10": (f.finish[0] + f.finish[1]) / 2}
