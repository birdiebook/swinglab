"""Farterna ur ledernas tidsserie: handens fart, främre armens vinkelfart och
finishens tid (METOD M35–M37). Samma i Swift (`Farter.swift`, BESLUT B12).

Farten räknas på ett rutnät i tiden (1 ms), inte i rutorna: i varje punkt τ är
hastigheten lutningen i en viktad linjär anpassning över tiden till de råa
lederna inom 3σ från τ, med samma gaussvikt som utjämningen (σ = 7,5 ms, METOD
M3). Inte en differens av de utjämnade lägena: luckorna gör utjämningens vikter
osymmetriska, så läget flyttas olika mycket i varje ruta (upp till 4 ms gånger
farten), vilket en differens förstorar. Anpassningen är väntevärdesriktig för en
jämn rörelse hur luckorna än ligger, och rutnätet gör att en lucka vid toppfarten
inte tar bort toppen. Farterna kräver skarp bild (BESLUT B11) och är oprovade på
telefonen. METOD M35
"""
from __future__ import annotations

import math

import numpy as np

from . import faser as F

STEG_S = 0.001              # METOD M35: rutnätet i tiden som farten räknas på
MIN_PER_SIDA = 2            # METOD M35: rutor med värde som krävs före och efter τ i fönstret
NARA_S = 0.020              # METOD M35: så nära toppen får rutnätet inte ha en lucka …
LUCKA_S = 0.020             # METOD M35: … längre än så, annars saknas toppen
GENOMSVING_ANDEL = 0.10     # METOD M36: finishen = handens fart under 10 % av genomsvingens toppfart


def rutnat(a: float, b: float) -> np.ndarray:
    """Tiderna a, a + 1 ms, … till och med b. METOD M35"""
    n = int(math.floor((b - a) / STEG_S + 1e-9))
    return a + np.arange(n + 1) * STEG_S


def _fonster(t: np.ndarray, ok: np.ndarray, tau: float) -> tuple[list[int], list[float]] | None:
    """Rutorna med värde inom 3σ från τ och deras gaussvikter, i tidsordning, eller
    None utan minst MIN_PER_SIDA rutor med värde före τ och lika många efter: en
    ensam ruta på ena sidan styr annars lutningen med hela sitt brus. METOD M35"""
    grans = F.TRUNKERA * F.SIGMA_S
    js = [int(j) for j in np.where(ok & (np.abs(t - tau) <= grans))[0]]
    fore = sum(1 for j in js if t[j] < tau)
    efter = sum(1 for j in js if t[j] > tau)
    if fore < MIN_PER_SIDA or efter < MIN_PER_SIDA:
        return None
    return js, [math.exp(-0.5 * ((float(t[j]) - tau) / F.SIGMA_S) ** 2) for j in js]


def _lutning(dt: list[float], y: list[float], w: list[float]) -> float:
    """Lutningen i den viktade linjära anpassningen y ≈ a + b·dt."""
    sw = 0.0
    st = 0.0
    sy = 0.0
    for wi, x, v in zip(w, dt, y):
        sw += wi
        st += wi * x
        sy += wi * v
    mt, my = st / sw, sy / sw
    num = 0.0
    den = 0.0
    for wi, x, v in zip(w, dt, y):
        num += wi * (x - mt) * (v - my)
        den += wi * (x - mt) * (x - mt)
    return num / den


def hastighet(t: np.ndarray, p: np.ndarray, tau: np.ndarray) -> np.ndarray:
    """Punktens hastighet (len(tau), 2) i px/s ur de råa lägena p (n, 2), NaN där
    den inte går att räkna. METOD M35"""
    ok = np.isfinite(p).all(axis=1)
    v = np.full((len(tau), 2), np.nan)
    for i, tc in enumerate(tau):
        r = _fonster(t, ok, float(tc))
        if r is None:
            continue
        js, w = r
        dt = [float(t[j]) - float(tc) for j in js]
        v[i, 0] = _lutning(dt, [float(p[j, 0]) for j in js], w)
        v[i, 1] = _lutning(dt, [float(p[j, 1]) for j in js], w)
    return v


def fart(t: np.ndarray, p: np.ndarray, tau: np.ndarray) -> np.ndarray:
    """Farten i px/s på rutnätet tau (NaN där hastigheten saknas). METOD M35"""
    v = hastighet(t, p, tau)
    return np.array([math.hypot(a, b) for a, b in v]) if len(v) else np.array([])


def handens_fart(t: np.ndarray, fram: np.ndarray, bak: np.ndarray, tau: np.ndarray, bada: bool) -> np.ndarray:
    """Greppets fart i px/s: medlet av handledernas hastigheter, var och en anpassad
    på sin egen råa serie. Inte greppregelns punkt (M1): den hoppar 1–2 cm när en
    handled försvinner, och hoppet blir en falsk fart. Med `bada` krävs båda
    handlederna (toppfarten, M35); annars gäller den ena där bara den går att räkna
    (finishens tid, M36, som bara jämför farten med sin egen topp: den yttre
    handleden går ≈ 3 % fortare). METOD M35, METOD M36"""
    vf, vb = hastighet(t, fram, tau), hastighet(t, bak, tau)
    ut = np.full(len(tau), np.nan)
    for i in range(len(tau)):
        f, b = bool(np.isfinite(vf[i]).all()), bool(np.isfinite(vb[i]).all())
        if f and b:
            ut[i] = math.hypot((vf[i, 0] + vb[i, 0]) / 2, (vf[i, 1] + vb[i, 1]) / 2)
        elif f and not bada:
            ut[i] = math.hypot(vf[i, 0], vf[i, 1])
        elif b and not bada:
            ut[i] = math.hypot(vb[i, 0], vb[i, 1])
    return ut


def _vinkel(d: float) -> float:
    """Vinkelskillnaden i grader, lagd i (−180, 180]."""
    return d - 360.0 * math.ceil((d - 180.0) / 360.0)


def vinkelfart(t: np.ndarray, fran: np.ndarray, till: np.ndarray, tau: np.ndarray) -> np.ndarray:
    """Linjen fran → till (råa lägen): vinkelns fart i grader/s i bildens plan,
    som belopp, på rutnätet tau. Vinkeln är atan2(dy, dx), och varje rutas vinkel
    räknas mot den första rutan i fönstret, lagd i (−180, 180], så att ett varv
    runt ±180° inte blir ett hopp. Anpassningen som i hastighet(). METOD M37"""
    d = till - fran
    ok = np.isfinite(d).all(axis=1)
    w = np.full(len(tau), np.nan)
    for i, tc in enumerate(tau):
        r = _fonster(t, ok, float(tc))
        if r is None:
            continue
        js, vikt = r
        ref = math.degrees(math.atan2(d[js[0], 1], d[js[0], 0]))
        dt = [float(t[j]) - float(tc) for j in js]
        y = [_vinkel(math.degrees(math.atan2(d[j, 1], d[j, 0])) - ref) for j in js]
        w[i] = abs(_lutning(dt, y, vikt))
    return w


def _parabel(t0: float, y0: float, t1: float, y1: float, t2: float, y2: float, tc: float) -> float:
    """Parabeln genom tre punkter, i tc (Lagrange)."""
    return (y0 * (tc - t1) * (tc - t2) / ((t0 - t1) * (t0 - t2))
            + y1 * (tc - t0) * (tc - t2) / ((t1 - t0) * (t1 - t2))
            + y2 * (tc - t0) * (tc - t1) / ((t2 - t0) * (t2 - t1)))


def maxpunkt(tau: np.ndarray, s: np.ndarray) -> tuple[float, float] | None:
    """(största värdet, dess tid) på rutnätet. Tiden och värdet förfinas med
    parabeln genom punkten och dess två grannar med värde (som toppen, METOD M4).
    None utan värden, när toppen ligger i rutnätets ände (farten steg ännu eller
    sjönk redan: toppen ligger utanför) eller saknar granne med värde på ena
    sidan, och när en lucka i rutnätet längre än LUCKA_S når in inom NARA_S från
    toppen (toppen kan ligga i luckan). METOD M35"""
    idx = np.where(np.isfinite(s))[0]
    if len(idx) == 0:
        return None
    j = int(np.argmax(s[idx]))
    k1 = int(idx[j])
    if k1 == 0 or k1 == len(tau) - 1 or not (0 < j < len(idx) - 1):
        return None
    # Varje lucka (punkter i följd utan värde) som når in inom NARA_S från toppen
    # räknas med hela sin längd.
    k = 0
    while k < len(tau):
        if math.isfinite(s[k]):
            k += 1
            continue
        b = k
        while b + 1 < len(tau) and not math.isfinite(s[b + 1]):
            b += 1
        nar = tau[k] - tau[k1] <= NARA_S and tau[k1] - tau[b] <= NARA_S
        if nar and (b - k + 1) * STEG_S > LUCKA_S:
            return None
        k = b + 1
    k0, k2 = int(idx[j - 1]), int(idx[j + 1])
    tc = float(F.toppunkt(tau[k0], -s[k0], tau[k1], -s[k1], tau[k2], -s[k2]))
    return _parabel(tau[k0], s[k0], tau[k1], s[k1], tau[k2], s[k2], tc), tc


def finish_tid(tau: np.ndarray, s: np.ndarray) -> float | None:
    """Finishen i tid: första gången efter toppfarten på rutnätet som handens fart
    faller under GENOMSVING_ANDEL av den, linjärt mellan två punkter i följd med
    värde. None om farten aldrig faller under, eller om de två punkterna ligger mer
    än MAX_LUCKA_S isär. METOD M36"""
    idx = np.where(np.isfinite(s))[0]
    if len(idx) == 0:
        return None
    j = int(np.argmax(s[idx]))
    troskel = GENOMSVING_ANDEL * float(s[idx[j]])
    for i in range(j + 1, len(idx)):
        k0, k1 = idx[i - 1], idx[i]
        if s[k1] < troskel:
            if tau[k1] - tau[k0] > F.MAX_LUCKA_S:
                return None
            return float(tau[k0] + (troskel - s[k0]) / (s[k1] - s[k0]) * (tau[k1] - tau[k0]))
    return None
