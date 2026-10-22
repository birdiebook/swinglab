"""Sessionen: varje mått sammanfattat över passets svingar, och jämförelsen mot
förra passet. METOD M25, METOD M26

Percentilen, medianen och rangerna räknas här för hand (inte med np.percentile),
så att Swift kan göra exakt samma sak.
"""
from __future__ import annotations

import math

MIN_N = 3                # METOD M25: färre svingar ger ingen sammanfattning
MAD_GRANS = 3.0          # METOD M25: avvikare = mer än 3 robusta sd från medianen
MAD_SKALA = 1.4826       # METOD M25: MAD → sd för normalfördelning (standard)
IQR_SKALA = 1.349        # METOD M26: IQR → sd för normalfördelning (standard)


def percentil(sorterad: list[float], p: float) -> float:
    """Linjär interpolation mellan de närmaste (som numpy 'linear'), p i 0…1."""
    n = len(sorterad)
    pos = p * (n - 1)
    lo = int(math.floor(pos))
    hi = min(lo + 1, n - 1)
    return sorterad[lo] + (pos - lo) * (sorterad[hi] - sorterad[lo])


def rang(x: list[float]) -> list[float]:
    """Rangerna 1…n, med medelrangen för lika värden."""
    ordning = sorted(range(len(x)), key=lambda i: x[i])
    r = [0.0] * len(x)
    i = 0
    while i < len(ordning):
        j = i
        while j + 1 < len(ordning) and x[ordning[j + 1]] == x[ordning[i]]:
            j += 1
        medel = (i + j) / 2 + 1
        for k in range(i, j + 1):
            r[ordning[k]] = medel
        i = j + 1
    return r


def pearson(a: list[float], b: list[float]) -> float:
    n = len(a)
    ma, mb = sum(a) / n, sum(b) / n
    sab = sum((a[i] - ma) * (b[i] - mb) for i in range(n))
    saa = sum((v - ma) ** 2 for v in a)
    sbb = sum((v - mb) ** 2 for v in b)
    if saa == 0 or sbb == 0:
        return 0.0
    return sab / math.sqrt(saa * sbb)


def spearman(a: list[float], b: list[float]) -> float:
    return pearson(rang(a), rang(b))


def sammanfatta(rader: list[dict[str, float]]) -> dict[str, dict]:
    """Rader = måtten per sving i passets ordning. Per mått: n, median, q1, q3,
    sd, min, max, trend (Spearman mot ordningen) och avvikare (svingens plats i
    passet, 0 först). METOD M25"""
    ut: dict[str, dict] = {}
    for k in sorted({k for r in rader for k in r}):
        plats = [i for i, r in enumerate(rader) if k in r and math.isfinite(r[k])]
        x = [rader[i][k] for i in plats]
        n = len(x)
        if n < MIN_N:
            continue
        s = sorted(x)
        med = percentil(s, 0.5)
        medel = sum(x) / n
        sd = math.sqrt(sum((v - medel) ** 2 for v in x) / (n - 1))
        mad = percentil(sorted(abs(v - med) for v in x), 0.5)
        grans = MAD_GRANS * MAD_SKALA * mad
        ut[k] = {"n": n, "median": med, "q1": percentil(s, 0.25), "q3": percentil(s, 0.75),
                 "sd": sd, "min": s[0], "max": s[-1],
                 "trend": spearman([float(i) for i in plats], x),
                 "avvikare": [plats[i] for i in range(n) if mad > 0 and abs(x[i] - med) > grans]}
    return ut


def robust_sd(sammanf: dict) -> float:
    """Spridningen ur kvartilerna: (q3 − q1)/1,349. METOD M26"""
    return (sammanf["q3"] - sammanf["q1"]) / IQR_SKALA


def jamfor(nu: dict[str, dict], forra: dict[str, dict]) -> dict[str, dict]:
    """Skillnaden i median mot förra passet, och om den är större än förra
    passets spridning (robust sd). METOD M26"""
    ut = {}
    for k in sorted(set(nu) & set(forra)):
        skillnad = nu[k]["median"] - forra[k]["median"]
        spridning = robust_sd(forra[k])
        ut[k] = {"skillnad": skillnad, "spridning": spridning, "tydlig": abs(skillnad) > spridning}
    return ut


def sammanfatta_session(svingar: list[dict]) -> dict[str, dict]:
    """Svingar = resultaten ur matt.mat (med "vy" och "matt"), i passets ordning.
    Måtten sammanfattas per vy, och för alla svingar ihop (tempot)."""
    return {"dtl": sammanfatta([s["matt"] for s in svingar if s["vy"] == "dtl"]),
            "fo": sammanfatta([s["matt"] for s in svingar if s["vy"] == "fo"]),
            "alla": sammanfatta([s["matt"] for s in svingar])}
