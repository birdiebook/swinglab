"""Utjämningen och svingens faser ur ledernas tidsserie.

Rutorna kommer med ojämna steg (en del av 240-rutnätet saknas), så allt räknas
på tiderna, aldrig på rutnumret. METOD M3 (utjämningen), METOD M4 (faserna).
"""
from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np

from .format import ARMBAGE_B, ARMBAGE_F, AXEL_B, AXEL_F, HANDLED_B, HANDLED_F

SIGMA_S = 0.0075         # METOD M3: gaussvikt över tiden (samma varians som Golf SG:s 25 ms)
TRUNKERA = 3.0           # METOD M3: rutor längre bort än 3σ räknas inte
MAX_LUCKA_S = 0.10       # METOD M3: längre lucka mellan två rutor interpoleras inte över

SOK_FORE_S = 1.5         # METOD M4: toppen söks högst så långt före klicket (som Golf SG)
SOK_SLUT_S = 0.05        # METOD M4: … och minst så långt före
MAX_BAKSVING_S = 1.5     # METOD M4: adressläget söks högst så långt före toppen
TROSKEL_ANDEL = 0.05     # METOD M4: starten = händerna har rört sig 5 % av vägen till toppen
MIN_BAKSVING_S = 0.5     # METOD M4: kortare baksving = starten är fel och saknas (som Golf SG)
TOPP_ADRESS_S = 1.2      # METOD M4: adressen räknas från toppen − 1,2 s när starten saknas
ADRESS = (-0.40, -0.10)  # METOD M4: s kring baksvingens start
FINISH = (1.0, 1.2)      # METOD M4: s efter träffen

# Starten bakifrån ur posen (METOD M40)
POSE_LEDER = (AXEL_F, AXEL_B, ARMBAGE_F, ARMBAGE_B, HANDLED_F, HANDLED_B)  # METOD M40: posen
STILLA_S = 0.10          # METOD M40: adressens fönster är 0,1 s långt …
STILLA_RUTOR = 3         # METOD M40: … med minst 3 rutor per led
MIN_LEDER = 4            # METOD M40: posen kräver minst fyra av de sex lederna
POSE_ANDEL = 0.03        # METOD M40: starten = posen har rört sig 3 % av vägen till toppen …
BRUS_K = 3.0             # METOD M40: … men minst 3 gånger posens skakning i adressen
OSAKER_ANDEL = 0.015     # METOD M40: skakningen över 1,5 % av vägen = starten osäker


class SvingFel(ValueError):
    """Svingen går inte att mäta (händerna syns inte, skalan saknas)."""


def grepp_regel(xy: np.ndarray) -> np.ndarray:
    """Händerna sitter ihop på greppet: en saknad handled tar den andras plats.
    Saknas båda är händerna borta i rutan. METOD M1"""
    ut = xy.copy()
    f_saknas = np.isnan(xy[:, HANDLED_F]).any(axis=1)
    b_saknas = np.isnan(xy[:, HANDLED_B]).any(axis=1)
    ut[f_saknas & ~b_saknas, HANDLED_F] = xy[f_saknas & ~b_saknas, HANDLED_B]
    ut[b_saknas & ~f_saknas, HANDLED_B] = xy[b_saknas & ~f_saknas, HANDLED_F]
    return ut


def jamna(t: np.ndarray, y: np.ndarray, sigma: float = SIGMA_S) -> np.ndarray:
    """Gaussvikt över tiden: varje ruta blir det viktade medlet av rutorna inom
    3σ, med vikten exp(−½(Δt/σ)²). Saknade värden räknas inte, och en ruta där
    värdet saknas förblir saknad: utjämningen fyller inga luckor, så att
    luckans längd i vid() är den råa. METOD M3"""
    y2 = y.reshape(len(t), -1)
    dt = t[:, None] - t[None, :]
    w = np.exp(-0.5 * (dt / sigma) ** 2)
    w[np.abs(dt) > TRUNKERA * sigma] = 0.0
    ok = np.isfinite(y2)
    num = w @ np.where(ok, y2, 0.0)
    den = w @ ok.astype(float)
    with np.errstate(invalid="ignore", divide="ignore"):
        ut = np.where(ok & (den > 0), num / den, np.nan)
    return ut.reshape(y.shape)


def _hela(p: np.ndarray) -> np.ndarray:
    return np.isfinite(p).all(axis=1)


def vid(t: np.ndarray, p: np.ndarray, tc: float) -> np.ndarray:
    """Punkten p (n, 2) i ögonblicket tc, linjärt mellan de två närmaste rutorna
    med värde. NaN utanför serien och över en lucka längre än MAX_LUCKA_S (den
    råa luckan, eftersom jamna inte fyller). METOD M3"""
    ok = _hela(p)
    tt, pp = t[ok], p[ok]
    nan = np.array([np.nan, np.nan])
    if len(tt) == 0 or not math.isfinite(tc) or tc < tt[0] or tc > tt[-1]:
        return nan
    k = int(np.searchsorted(tt, tc, side="left"))      # första rutan med t ≥ tc
    if tt[k] == tc:
        return pp[k].copy()
    lo, hi = k - 1, k
    if tt[hi] - tt[lo] > MAX_LUCKA_S:
        return nan
    f = (tc - tt[lo]) / (tt[hi] - tt[lo])
    return pp[lo] + f * (pp[hi] - pp[lo])


def medel(t: np.ndarray, p: np.ndarray, a: float, b: float) -> np.ndarray:
    """Medlet av punkten p över rutorna a ≤ t ≤ b som har värde."""
    sel = (t >= a) & (t <= b) & _hela(p)
    if not sel.any():
        return np.array([np.nan, np.nan])
    return p[sel].mean(axis=0)


def toppunkt(t0: float, y0: float, t1: float, y1: float, t2: float, y2: float) -> float:
    """Minimum på parabeln genom tre punkter med ojämna steg (tiderna räknas
    från t1 för noggrannhetens skull). Faller tillbaka på t1. METOD M4"""
    u0, u2 = t0 - t1, t2 - t1
    d = u0 * (u0 - u2) * (-u2)
    if d == 0:
        return t1
    a = (u2 * (y1 - y0) + u0 * (y2 - y1)) / d
    b = (u2 * u2 * (y0 - y1) + u0 * u0 * (y1 - y2)) / d
    if a <= 0:
        return t1
    u = -b / (2 * a)
    return t1 + min(max(u, u0), u2)


@dataclass
class Faser:
    start: float | None      # baksvingens start (s), None om den inte gick att hitta
    topp: float              # händerna högst
    traff: float             # klicket
    adress: tuple[float, float]
    finish: tuple[float, float]
    start_osaker: bool = False   # starten finns men bär inte tempot (METOD M40)


def _start_ur_handerna(t: np.ndarray, G: np.ndarray, topp: float, ok: np.ndarray) -> float | None:
    """Sista gången före toppen som händerna var inom 5 % av vägen från adressläget
    (händerna lägst). METOD M4"""
    fore = np.where(ok & (t >= topp - MAX_BAKSVING_S) & (t <= topp))[0]
    gt = vid(t, G, topp)
    if len(fore) == 0 or not np.isfinite(gt).all():
        return None
    k_lag = fore[int(np.argmax(G[fore, 1]))]           # händerna lägst = adressläget
    r = G[k_lag]
    troskel = TROSKEL_ANDEL * float(np.hypot(*(gt - r)))
    seq = fore[t[fore] >= t[k_lag]]
    d = np.hypot(G[seq, 0] - r[0], G[seq, 1] - r[1])
    inom = np.where(d <= troskel)[0]                   # finns alltid: d = 0 i adressläget
    m = int(inom[-1])
    if m < len(seq) - 1:
        k0, k1 = seq[m], seq[m + 1]
        s = float(t[k0] + (troskel - d[m]) / (d[m + 1] - d[m]) * (t[k1] - t[k0]))
        if topp - s >= MIN_BAKSVING_S:
            return s
    return None


def _adressens_fonster(t: np.ndarray, B: np.ndarray, topp: float):
    """Adressen bakifrån: det fönster om STILLA_S, med början mellan toppen −
    MAX_BAKSVING_S och toppen − MIN_BAKSVING_S, där posen skakar minst (det första
    vid lika). Skakningen = medlet över lederna av rutornas kvadrerade avstånd till ledens medel
    i fönstret (px²). Ger (första rutan, {led: medel}, {led: skakning}) eller None.
    METOD M40"""
    hel = np.isfinite(B).all(axis=2)                   # (n, 13)
    bast = None
    for k in np.where((t >= topp - MAX_BAKSVING_S) & (t <= topp - MIN_BAKSVING_S))[0]:
        sel = np.where((t >= t[k]) & (t <= t[k] + STILLA_S))[0]
        medel, skak = {}, {}
        for j in POSE_LEDER:
            r = sel[hel[sel, j]]
            if len(r) < STILLA_RUTOR:
                continue
            m = B[r, j].sum(axis=0) / len(r)
            medel[j] = m
            skak[j] = float(((B[r, j, 0] - m[0]) ** 2 + (B[r, j, 1] - m[1]) ** 2).sum() / len(r))
        if len(medel) >= MIN_LEDER:
            r = sum(skak.values()) / len(skak)
            if bast is None or r < bast[3]:
                bast = (int(k), medel, skak, r)
    return None if bast is None else bast[:3]


def start_ur_posen(t: np.ndarray, B: np.ndarray, topp: float) -> tuple[float | None, bool]:
    """Baksvingens start bakifrån ur armarnas och axlarnas pose B (n, 13, 2), redan
    utjämnad: sista gången före toppen som posen var inom POSE_ANDEL av vägen från
    adressen till toppen (men minst BRUS_K gånger skakningen i adressen), som
    medelavstånd över lederna. Ger (starten, osäker) eller (None, False) när posen
    inte räcker. METOD M40"""
    a = _adressens_fonster(t, B, topp)
    if a is None:
        return None, False
    k_ref, medel, skak = a
    toppen = {j: vid(t, B[:, j], topp) for j in medel}
    leder = [j for j in POSE_LEDER if j in medel and np.isfinite(toppen[j]).all()]
    if len(leder) < MIN_LEDER:
        return None, False
    sigma = math.sqrt(sum(skak[j] for j in leder) / len(leder))
    vag = sum(math.hypot(*(toppen[j] - medel[j])) for j in leder) / len(leder)
    troskel = max(POSE_ANDEL * vag, BRUS_K * sigma)
    seq = np.where((t >= t[k_ref]) & (t <= topp) & np.isfinite(B[:, leder]).all(axis=(1, 2)))[0]
    d = sum(np.hypot(B[seq, j, 0] - medel[j][0], B[seq, j, 1] - medel[j][1]) for j in leder) / len(leder)
    inom = np.where(d <= troskel)[0]
    if len(inom) == 0 or inom[-1] == len(seq) - 1:
        return None, False
    m = int(inom[-1])
    k0, k1 = seq[m], seq[m + 1]
    s = float(t[k0] + (troskel - d[m]) / (d[m + 1] - d[m]) * (t[k1] - t[k0]))
    if topp - s < MIN_BAKSVING_S:
        return None, False
    return s, sigma > OSAKER_ANDEL * vag


def hitta_faser(t: np.ndarray, G: np.ndarray, t_klick: float, pose: np.ndarray | None = None) -> Faser:
    """Toppen, starten, adressen och finishen ur händernas bana G (n, 2),
    redan utjämnad. Med `pose` (n, 13, 2, utjämnad; bakifrån) tas starten ur
    armarnas och axlarnas pose i stället (METOD M40), annars ur händerna. METOD M4"""
    ok = _hela(G)
    idx = np.where(ok & (t >= t_klick - SOK_FORE_S) & (t <= t_klick - SOK_SLUT_S))[0]
    if len(idx) == 0:
        raise SvingFel("händerna syns inte före träffen")
    j = int(np.argmin(G[idx, 1]))                      # minst y = högst i bilden
    topp = float(t[idx[j]])
    if 0 < j < len(idx) - 1:
        a, b, c = idx[j - 1], idx[j], idx[j + 1]
        topp = float(toppunkt(t[a], G[a, 1], t[b], G[b, 1], t[c], G[c, 1]))

    start, osaker = None, False
    if pose is not None:
        start, osaker = start_ur_posen(t, pose, topp)
        if start is None:                              # posen räcker inte: händerna, osäkert
            start = _start_ur_handerna(t, G, topp, ok)
            osaker = start is not None
    else:
        start = _start_ur_handerna(t, G, topp, ok)

    s0 = start if start is not None else topp - TOPP_ADRESS_S
    return Faser(start=start, topp=topp, traff=float(t_klick),
                 adress=(s0 + ADRESS[0], s0 + ADRESS[1]),
                 finish=(t_klick + FINISH[0], t_klick + FINISH[1]), start_osaker=osaker)


def lage(t: np.ndarray, p: np.ndarray, f: Faser, fas: str) -> np.ndarray:
    """Punkten i en fas: medel över adressens och finishens fönster, värdet i
    ögonblicket vid toppen och träffen."""
    if fas == "adress":
        return medel(t, p, *f.adress)
    if fas == "finish":
        return medel(t, p, *f.finish)
    if fas == "topp":
        return vid(t, p, f.topp)
    if fas == "traff":
        return vid(t, p, f.traff)
    raise ValueError(f"okänd fas: {fas}")
