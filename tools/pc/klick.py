"""Klicket i ljudet och parningen mellan två telefoner (METOD MS4, MS10).

Facit för SwingLabKit `Capture` (`ClickDetector`, `ClickPairing`), BESLUT B12.
`klick()` är Golf SG:s `tools/handled_video.py` `klick()` rad för rad, med en
enda vakt till (en signal kortare än fönstret ger inga klick). `para()` är
Golf SG:s `para()` med den sökta förskjutningen som ett eget fönster (kring en
prior från pingen, eller ± `sok` utan) och med stegen räknade som `lo + i·steg`,
så att Swift kan räkna samma steg (numpys `arange` gör inte riktigt det).

    from pc import klick as KL
    KL.klick(x, 48000)            # [(tid s, styrka), ...] för en bit
    KL.klick_i_bitar(x, 48000)    # samma i bitar om 30 s med 1 s överlapp (S2_SPEC §4.2)
    KL.para(a, b, prior=None)     # b ≈ a + förskjutning (S2_SPEC §7.3)
"""
from __future__ import annotations

import math

import numpy as np

SR = 48000
# METOD MS4: Golf SG:s konstanter (handled_video.py), mätta på oktobers 41 klick.
FONSTER_S = 0.002         # energins fönster
FAKTOR = 25.0             # klickets energi mot bitens median
AVSTAND_S = 0.5           # två toppar närmare än så är samma klick
ANSATS_S = 0.02           # ansatsen söks så långt före toppen
ANSATS_ANDEL = 0.5        # ansatsen: första provet över halva toppen
# METOD MS4: bitarna (antagande, minnet på telefonen).
BIT_S = 30.0
OVERLAPP_S = 1.0
# METOD MS10: parningen. Steg och tolerans ur Golf SG para(); fönstren antagande.
STEG_S = 0.005
TOL_S = 0.03
PRIOR_FONSTER_S = 0.25
SOK_S = 10.0


def klick(x: np.ndarray, sr: int = SR) -> list[tuple[float, float]]:
    """Korta, kraftiga ansatser i ljudet: (tid s, styrka mot medianen). Tiden
    är ansatsen, första provet över halva toppen inom 20 ms före den."""
    w = max(1, int(sr * FONSTER_S))
    if len(x) < 10 or len(x) < w:    # vakten: np.convolve byter annars plats på fönstret och signalen
        return []
    hp = np.diff(x, prepend=x[0])
    e = np.sqrt(np.convolve(hp ** 2, np.ones(w) / w, mode="same"))
    bas = float(np.median(e)) + 1e-9
    toppar: list[int] = []
    for i in np.flatnonzero(e > FAKTOR * bas):
        if toppar and i - toppar[-1] < sr * AVSTAND_S:
            if e[i] > e[toppar[-1]]:
                toppar[-1] = int(i)
            continue
        toppar.append(int(i))
    ut = []
    for p in toppar:
        a = max(0, p - int(sr * ANSATS_S))
        o = a + int(np.argmax(e[a:p + 1] > ANSATS_ANDEL * e[p]))
        ut.append((o / sr, float(e[p] / bas)))
    return ut


def bitar(n: int, sr: int = SR, bit_s: float = BIT_S, overlapp_s: float = OVERLAPP_S) -> list[tuple[int, int]]:
    """Bitarnas prov [början, slut): bit_s långa, överlappande med overlapp_s.
    Den sista slutar vid signalens slut. Samma i Swift (ClickDetector.segments)."""
    langd = int(bit_s * sr)
    steg = int((bit_s - overlapp_s) * sr)
    ut, a = [], 0
    while True:
        b = min(a + langd, n)
        ut.append((a, b))
        if b >= n:
            return ut
        a += steg


def sla_ihop(delar: list[tuple[float, list[tuple[float, float]]]], avstand: float = AVSTAND_S) -> list[tuple[float, float]]:
    """Bitarnas klick på signalens tid: (bitens start s, bitens klick). Två klick
    närmare än avstand blir det starkaste (jämfört mot det senast behållna, som
    toppjakten i klick())."""
    alla = sorted(((start + t, s) for start, kl in delar for t, s in kl), key=lambda k: k[0])
    ut: list[tuple[float, float]] = []
    for t, s in alla:
        if ut and t - ut[-1][0] < avstand:
            if s > ut[-1][1]:
                ut[-1] = (t, s)
            continue
        ut.append((t, s))
    return ut


def klick_i_bitar(x: np.ndarray, sr: int = SR, bit_s: float = BIT_S, overlapp_s: float = OVERLAPP_S) -> list[tuple[float, float]]:
    """klick() per bit, ihopslaget. Så räknar telefonen (S2_SPEC §4.2)."""
    return sla_ihop([(a / sr, klick(x[a:b], sr)) for a, b in bitar(len(x), sr, bit_s, overlapp_s)])


def ljudets_vag(avstand_m: float, fart: float = 343.0) -> float:
    """Tiden ljudet tar från bollen till telefonen, s (METOD MS6)."""
    return avstand_m / fart


def _steg(lo: float, hi: float, steg: float) -> list[float]:
    n = max(0, math.ceil((hi - lo) / steg))
    return [lo + i * steg for i in range(n)]


def para(a, b, prior: float | None = None, prior_fonster: float = PRIOR_FONSTER_S, sok: float = SOK_S,
         steg: float = STEG_S, tol: float = TOL_S) -> dict:
    """Förskjutningen d där b ≈ a + d parar flest klick inom tol, förfinad med
    medianen av de parade resterna (Golf SG para(), med a = klicken och b = bandet).
    Svarar {"forskjutning": d, "par": [[i_a, i_b, rest], ...]} där rest = a[i] + d − b[j]
    för det a som ligger närmast varje b. Parar inget svaras prior (eller 0) och inga par."""
    a = np.asarray(a, dtype=float)
    b = np.asarray(b, dtype=float)
    if not len(a) or not len(b):
        return {"forskjutning": float(prior or 0.0), "par": []}

    def rest(d):
        k = a + d
        idx = [int(np.argmin(np.abs(k - x))) for x in b]
        return idx, np.array([k[i] - x for i, x in zip(idx, b)])

    lo, hi = (prior - prior_fonster, prior + prior_fonster) if prior is not None else (-sok, sok)
    bast, flest = lo, -1
    for d in _steg(lo, hi, steg):
        n = int((np.abs(rest(d)[1]) < tol).sum())
        if n > flest:
            bast, flest = d, n
    if flest == 0:                     # inget parar: ingen förskjutning att lita på (Golf SG svarade sökningens början)
        return {"forskjutning": float(prior or 0.0), "par": []}
    _, r = rest(bast)
    ok = np.abs(r) < tol
    d = bast - float(np.median(r[ok])) if ok.any() else bast
    idx, r = rest(d)
    par = [[int(idx[j]), j, float(r[j])] for j in range(len(b)) if abs(r[j]) < tol]
    return {"forskjutning": float(d), "par": par}
