"""Rensningen av lederna före mätningen: byten mellan vänster och höger, och spikar.
PLAN S3b lager 1, METOD M53.

Posemodellen kan byta plats på en leds vänstra och högra punkt i några rutor, eller
kasta en punkt långt bort i en eller ett par rutor. Utan facit syns båda i tidsserien:

- **Bytet:** i en grupp (armbågarna och handlederna, knäna och fotlederna, höfterna,
  axlarna) ligger rutans främre punkter närmare förra rutans bakre än sina egna, och
  korsat är billigare än halva det raka. En verklig rörelse korsar aldrig så fort: med
  sidorna minst 0,2 bål isär skulle det kräva en fart på tiotals m/s. Ett kort byte (ut
  och tillbaka inom 0,25 s) byts tillbaka; en ensam växling räknas men rättas inte.
- **Spiken:** en punkt hoppar ut fortare än leden kan röra sig och kommer tillbaka lika
  fort inom tre rutor, åt motsatt håll. En verklig snabb rörelse (händerna i nedsvingen)
  håller riktningen från ruta till ruta. Rutorna i spiken räknas som saknade.

Allt räknas på tiderna (rutorna kommer med ojämna steg) och i bålens längd i bild, så
att gränserna i m/s gäller oavsett kamerans avstånd (METOD M2:s kvoter).
"""
from __future__ import annotations

import math

import numpy as np

from .format import (ARMBAGE_B, ARMBAGE_F, AXEL_B, AXEL_F, FOTLED_B, FOTLED_F, HANDLED_B, HANDLED_F,
                     HOFT_B, HOFT_F, KNA_B, KNA_F, LEDER, NASA)

AXELHOJD, HOFTHOJD = 0.818, 0.530     # METOD M2 (samma som matt.py)
BAL = AXELHOJD - HOFTHOJD

# METOD M53: högsta rimliga fart per led i bildens plan, m/s. **antagande**
FART_MAX = {NASA: 6.0, AXEL_F: 6.0, AXEL_B: 6.0, ARMBAGE_F: 12.0, ARMBAGE_B: 12.0,
            HANDLED_F: 15.0, HANDLED_B: 15.0, HOFT_F: 4.0, HOFT_B: 4.0, KNA_F: 5.0, KNA_B: 5.0,
            FOTLED_F: 5.0, FOTLED_B: 5.0}
SPIK_MAX_RUTOR = 3       # METOD M53: en spik är högst så många rutor lång
VANDNING_COS = -0.5      # METOD M53: ut och tillbaka = stegen mer än 120° isär
TILLBAKA_ANDEL = 0.5     # METOD M53: steget tillbaka är minst halva steget ut
SPIK_MIN_BAL = 0.25      # METOD M53: steget ut är minst så många bål (skakningen är inte en spik)
MAX_STEG_S = 0.05        # METOD M53: längre mellan två rutor är en lucka, inget steg
BYTE_ANDEL = 0.5         # METOD M53: korsat under halva det raka = bytt
BYTE_SEP_MIN = 0.2       # METOD M53: sidorna minst så många bål isär, annars prövas inget byte
BYTE_MAX_S = 0.25        # METOD M53: ett byte är högst så långt; längre rättas inte

GRUPPER = {              # METOD M53: punkterna som byter sida tillsammans
    "armar": ((ARMBAGE_F, ARMBAGE_B), (HANDLED_F, HANDLED_B)),
    "ben": ((KNA_F, KNA_B), (FOTLED_F, FOTLED_B)),
    "hofter": ((HOFT_F, HOFT_B),),
    "axlar": ((AXEL_F, AXEL_B),),
}


def bal_px(xy: np.ndarray) -> float:
    """Bålen i bild: medianen av avståndet axelmitt–höftmitt över rutorna där alla fyra
    syns, px. NaN när ingen ruta har dem. METOD M53"""
    C = (xy[:, AXEL_F] + xy[:, AXEL_B]) / 2
    P = (xy[:, HOFT_F] + xy[:, HOFT_B]) / 2
    d = np.hypot(C[:, 0] - P[:, 0], C[:, 1] - P[:, 1])
    d = d[np.isfinite(d)]
    return float(np.median(d)) if len(d) else math.nan


def _avst(a, b) -> float:
    return math.hypot(float(a[0]) - float(b[0]), float(a[1]) - float(b[1]))


def byten(t: np.ndarray, xy: np.ndarray, u: float) -> tuple[dict[str, int], dict[str, int]]:
    """Byter tillbaka korta byten (xy ändras på plats). Varje ruta jämförs med förra rutan
    där gruppen syns, högst MAX_STEG_S bort: korsat under BYTE_ANDEL av det raka, med
    sidorna isär (BYTE_SEP_MIN bål för minst ett av gruppens par), är en växling. Två
    växlingar i följd inom BYTE_MAX_S är ett byte, och rutorna mellan dem byts tillbaka. En
    växling utan en partner inom tiden rättas inte (vilken sida som är rätt går inte att
    veta) men räknas. Ger ({grupp: bytta rutor}, {grupp: växlingar utan partner}). METOD M53"""
    rattade: dict[str, int] = {}
    oklara: dict[str, int] = {}
    for namn, par in GRUPPER.items():
        hel = np.ones(len(t), bool)
        for f, b in par:
            hel &= np.isfinite(xy[:, f]).all(axis=1) & np.isfinite(xy[:, b]).all(axis=1)
        idx = [int(k) for k in np.where(hel)[0]]
        vaxlingar = []                                # positioner i idx där rutan växlat
        for i in range(1, len(idx)):
            k, q = idx[i], idx[i - 1]
            if t[k] - t[q] > MAX_STEG_S:
                continue
            sep = max(_avst(xy[q, f], xy[q, b]) for f, b in par)
            rakt = sum(_avst(xy[k, f], xy[q, f]) + _avst(xy[k, b], xy[q, b]) for f, b in par)
            kors = sum(_avst(xy[k, f], xy[q, b]) + _avst(xy[k, b], xy[q, f]) for f, b in par)
            if sep >= BYTE_SEP_MIN * u and kors < BYTE_ANDEL * rakt:
                vaxlingar.append(i)
        bytta, utan = [], 0
        v = 0
        while v < len(vaxlingar):
            i0 = vaxlingar[v]
            if v + 1 < len(vaxlingar) and t[idx[vaxlingar[v + 1]]] - t[idx[i0]] <= BYTE_MAX_S:
                bytta.extend(idx[i0:vaxlingar[v + 1]])
                v += 2
            else:
                utan += 1
                v += 1
        for k in bytta:
            for f, b in par:
                xy[k, f], xy[k, b] = xy[k, b].copy(), xy[k, f].copy()
        if bytta:
            rattade[namn] = len(bytta)
        if utan:
            oklara[namn] = utan
    return rattade, oklara


def spikar(t: np.ndarray, xy: np.ndarray, px_per_m: float, u: float) -> dict[str, int]:
    """Tar bort spikar (rutorna sätts till NaN, xy ändras på plats): ett steg ut fortare än
    ledens FART_MAX och minst SPIK_MIN_BAL bål (u px) långt, och inom SPIK_MAX_RUTOR rutor ett steg tillbaka, också över gränsen,
    mer än 120° från steget ut och minst halva dess längd. Stegen räknas mellan rutor där
    leden syns, högst MAX_STEG_S isär. Ger {led: antal borttagna rutor}. METOD M53"""
    ut: dict[str, int] = {}
    for j in range(xy.shape[1]):
        grans = FART_MAX[j] * px_per_m
        idx = [int(k) for k in np.where(np.isfinite(xy[:, j]).all(axis=1))[0]]
        p = [xy[k, j].copy() for k in idx]
        bort: list[int] = []
        i = 1
        while i < len(idx):
            dt = t[idx[i]] - t[idx[i - 1]]
            ut_steg = p[i] - p[i - 1]
            lu = math.hypot(*ut_steg)
            if dt > MAX_STEG_S or not (lu > grans * dt and lu >= SPIK_MIN_BAL * u):
                i += 1
                continue
            hittad = None
            for m in range(i + 1, min(i + SPIK_MAX_RUTOR, len(idx) - 1) + 1):
                dm = t[idx[m]] - t[idx[m - 1]]
                if dm > MAX_STEG_S:
                    break
                tillbaka = p[m] - p[m - 1]
                lt = math.hypot(*tillbaka)
                cos = float(ut_steg[0] * tillbaka[0] + ut_steg[1] * tillbaka[1]) / (lu * lt) if lt > 0 else 1.0
                if lt > grans * dm and cos < VANDNING_COS and lt >= TILLBAKA_ANDEL * lu:
                    hittad = m
                    break
            if hittad is None:
                i += 1
                continue
            bort.extend(idx[i:hittad])
            i = hittad + 1
        for k in bort:
            xy[k, j] = np.nan
        if bort:
            ut[LEDER[j]] = len(bort)
    return ut


def rensa(t: np.ndarray, xy: np.ndarray, langd_m: float) -> tuple[np.ndarray, dict]:
    """Lederna rensade (en kopia), och vad som gjordes: {"byten": {grupp: rutor},
    "byten_oklara": {grupp: växlingar}, "spikar": {led: rutor}}. Bytena först, så att ett
    kort byte inte ser ut som två spikar. Utan bålen i bild görs ingenting. METOD M53"""
    ut = xy.copy()
    u = bal_px(ut)
    if not (u > 0):
        return ut, {"byten": {}, "byten_oklara": {}, "spikar": {}}
    b, o = byten(t, ut, u)
    s = spikar(t, ut, u / (BAL * langd_m), u)
    return ut, {"byten": b, "byten_oklara": o, "spikar": s}
