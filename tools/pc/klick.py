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
# METOD MS10: så många par krävs för att parningen ska räknas som säker (antagande).
MIN_PAR_UTAN_PRIOR = 3
MIN_PAR_MED_PRIOR = 1


def _klick_prov(x: np.ndarray, sr: int = SR) -> list[tuple[int, int, float]]:
    """klick() i prov: (ansats, topp, styrka). Golf SG:s rader, bara utan tiden."""
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
        ut.append((o, p, float(e[p] / bas)))
    return ut


def klick(x: np.ndarray, sr: int = SR) -> list[tuple[float, float]]:
    """Korta, kraftiga ansatser i ljudet: (tid s, styrka mot medianen). Tiden
    är ansatsen, första provet över halva toppen inom 20 ms före den."""
    return [(o / sr, s) for o, _, s in _klick_prov(x, sr)]


def kant(sr: int = SR) -> int:
    """Prov från en inre bitgräns där bitens energi är kapad: ansatsens sökfönster
    plus energins fönster (METOD MS4). Grannbiten, som överlappar 1 s, ser klicket helt."""
    return int(sr * ANSATS_S) + max(1, int(sr * FONSTER_S))


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


def bitens_klick(x: np.ndarray, a: int, b: int, n: int, sr: int = SR) -> list[tuple[float, float]]:
    """klick() i biten x[a:b] av en signal med n prov, utan klick vars topp ligger
    närmare än kant() från en inre bitgräns (S2_SPEC §4.2, METOD MS4)."""
    k = kant(sr)
    ut = []
    for o, p, s in _klick_prov(x[a:b], sr):
        if (a > 0 and p < k) or (b < n and p > (b - a) - 1 - k):
            continue
        ut.append((o / sr, s))
    return ut


def klick_i_bitar(x: np.ndarray, sr: int = SR, bit_s: float = BIT_S, overlapp_s: float = OVERLAPP_S) -> list[tuple[float, float]]:
    """klick() per bit, ihopslaget. Så räknar telefonen (S2_SPEC §4.2)."""
    return sla_ihop([(a / sr, bitens_klick(x, a, b, len(x), sr)) for a, b in bitar(len(x), sr, bit_s, overlapp_s)])


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

    Svarar {"forskjutning": d, "par": [[i_a, i_b, rest], ...], "antal", "nast_bast",
    "nast_antal", "osaker"}: rest = a[i] + d − b[j] för det a som ligger närmast
    varje b; antal = flest parade i sökningen; nast_bast och nast_antal = det bästa
    d minst 2·tol från det valda (marginalen, None och 0 om inget finns). Osäker när
    antal < MIN_PAR (3 utan prior, 1 med) eller när näst bästa parar lika många.
    Parar inget (eller är fönstret tomt) svaras prior (eller 0), inga par, osäker."""
    a = np.asarray(a, dtype=float)
    b = np.asarray(b, dtype=float)
    tom = {"forskjutning": float(prior or 0.0), "par": [], "antal": 0, "nast_bast": None, "nast_antal": 0,
           "osaker": True}
    if not len(a) or not len(b):
        return tom

    def rest(d):
        k = a + d
        idx = [int(np.argmin(np.abs(k - x))) for x in b]
        return idx, np.array([k[i] - x for i, x in zip(idx, b)])

    lo, hi = (prior - prior_fonster, prior + prior_fonster) if prior is not None else (-sok, sok)
    sokta = [(d, int((np.abs(rest(d)[1]) < tol).sum())) for d in _steg(lo, hi, steg)]
    bast, flest = lo, 0
    for d, n in sokta:
        if n > flest:
            bast, flest = d, n
    if flest == 0:                     # inget parar: ingen förskjutning att lita på (Golf SG svarade sökningens början)
        return tom
    nast, nast_antal = None, 0
    for d, n in sokta:
        if abs(d - bast) >= 2 * tol and n > nast_antal:
            nast, nast_antal = d, n
    _, r = rest(bast)
    ok = np.abs(r) < tol
    d = bast - float(np.median(r[ok]))
    idx, r = rest(d)
    par = [[int(idx[j]), j, float(r[j])] for j in range(len(b)) if abs(r[j]) < tol]
    minst = MIN_PAR_UTAN_PRIOR if prior is None else MIN_PAR_MED_PRIOR
    return {"forskjutning": float(d), "par": par, "antal": flest, "nast_bast": nast, "nast_antal": nast_antal,
            "osaker": flest < minst or nast_antal >= flest}
