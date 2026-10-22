"""Utjämningen och svingens faser ur ledernas tidsserie.

Rutorna kommer med ojämna steg (en del av 240-rutnätet saknas), så allt räknas
på tiderna, aldrig på rutnumret. METOD M3 (utjämningen), METOD M4 (faserna).
"""
from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np

from .format import HANDLED_B, HANDLED_F

SIGMA_S = 0.0075         # METOD M3: gaussvikt över tiden (samma varians som Golf SG:s 25 ms)
TRUNKERA = 3.0           # METOD M3: rutor längre bort än 3σ räknas inte
MAX_LUCKA_S = 0.10       # METOD M3: längre lucka mellan två rutor interpoleras inte över

SOK_FORE_S = 2.0         # METOD M4: toppen söks högst så långt före klicket
SOK_SLUT_S = 0.05        # METOD M4: … och minst så långt före
MAX_BAKSVING_S = 1.5     # METOD M4: adressläget söks högst så långt före toppen
TROSKEL_ANDEL = 0.05     # METOD M4: starten = händerna har rört sig 5 % av vägen till toppen
MIN_BAKSVING_S = 0.4     # METOD M4: kortare baksving = starten är fel och saknas
TOPP_ADRESS_S = 1.2      # METOD M4: adressen räknas från toppen − 1,2 s när starten saknas
ADRESS = (-0.40, -0.10)  # METOD M4: s kring baksvingens start
FINISH = (1.0, 1.2)      # METOD M4: s efter träffen


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
    3σ, med vikten exp(−½(Δt/σ)²). Saknade värden räknas inte; en ruta utan
    någon granne med värde blir NaN. METOD M3"""
    y2 = y.reshape(len(t), -1)
    dt = t[:, None] - t[None, :]
    w = np.exp(-0.5 * (dt / sigma) ** 2)
    w[np.abs(dt) > TRUNKERA * sigma] = 0.0
    ok = np.isfinite(y2)
    num = w @ np.where(ok, y2, 0.0)
    den = w @ ok.astype(float)
    with np.errstate(invalid="ignore", divide="ignore"):
        ut = np.where(den > 0, num / den, np.nan)
    return ut.reshape(y.shape)


def _hela(p: np.ndarray) -> np.ndarray:
    return np.isfinite(p).all(axis=1)


def vid(t: np.ndarray, p: np.ndarray, tc: float) -> np.ndarray:
    """Punkten p (n, 2) i ögonblicket tc, linjärt mellan de två närmaste rutorna
    med värde. NaN utanför serien och över en lucka längre än MAX_LUCKA_S. METOD M3"""
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


def hitta_faser(t: np.ndarray, G: np.ndarray, t_klick: float) -> Faser:
    """Toppen, starten, adressen och finishen ur händernas bana G (n, 2),
    redan utjämnad. METOD M4"""
    ok = _hela(G)
    idx = np.where(ok & (t >= t_klick - SOK_FORE_S) & (t <= t_klick - SOK_SLUT_S))[0]
    if len(idx) == 0:
        raise SvingFel("händerna syns inte före träffen")
    j = int(np.argmin(G[idx, 1]))                      # minst y = högst i bilden
    topp = float(t[idx[j]])
    if 0 < j < len(idx) - 1:
        a, b, c = idx[j - 1], idx[j], idx[j + 1]
        topp = float(toppunkt(t[a], G[a, 1], t[b], G[b, 1], t[c], G[c, 1]))

    start = None
    fore = np.where(ok & (t >= topp - MAX_BAKSVING_S) & (t <= topp))[0]
    gt = vid(t, G, topp)
    if len(fore) > 0 and np.isfinite(gt).all():
        k_lag = fore[int(np.argmax(G[fore, 1]))]       # händerna lägst = adressläget
        r = G[k_lag]
        troskel = TROSKEL_ANDEL * float(np.hypot(*(gt - r)))
        seq = fore[t[fore] >= t[k_lag]]
        d = np.hypot(G[seq, 0] - r[0], G[seq, 1] - r[1])
        inom = np.where(d <= troskel)[0]               # finns alltid: d = 0 i adressläget
        m = int(inom[-1])
        if m < len(seq) - 1:
            k0, k1 = seq[m], seq[m + 1]
            s = float(t[k0] + (troskel - d[m]) / (d[m + 1] - d[m]) * (t[k1] - t[k0]))
            if topp - s >= MIN_BAKSVING_S:
                start = s

    s0 = start if start is not None else topp - TOPP_ADRESS_S
    return Faser(start=start, topp=topp, traff=float(t_klick),
                 adress=(s0 + ADRESS[0], s0 + ADRESS[1]),
                 finish=(t_klick + FINISH[0], t_klick + FINISH[1]))


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
