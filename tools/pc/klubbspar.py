"""Klubbhuvudets bana mellan ankarna (PLAN S7b, METOD M61, BESLUT B71): facit för
SwingLabKit (`KlubbSpar`, samma tal inom 1e-6, BESLUT B12).

Johannes tryck vid P1–P10 (S7a, `KlubbMarkering`) är ankare. Mellan två ankare spåras
klubbhuvudet med rörelsedifferens i gråskalerutor:

1. Rörelsen i ruta k är min(|I_k − I_(k−2)|, |I_k − I_(k+2)|): pixlar som skiljer sig både
   från rutan två före och två efter, alltså det som är där just i ruta k.
2. Kroppen maskeras ut ur Visions leder i rutan (streck kring lederna, bålen och huvudet).
3. Sökningen begränsas till en korridor kring greppet: radien 0,5–1,35 skaft och vinkeln
   kring skaftets riktning, linjärt i tiden mellan ankarnas riktningar. Greppet är
   handledernas mitt (utjämnad, M3) plus ankarnas förskjutning mellan handlederna och det
   tryckta greppet; skaftets längd är ankarnas, linjärt i tiden.
4. Klubbhuvudet är mitten av de rörliga pixlarna ytterst i korridoren (det bandet som är
   ett klubbhuvud brett, räknat från den tredje yttersta pixeln). Är bandet smalare tvärs
   skaftet än ett klubbhuvud syns bara skaftet (huvudet mot en mörk bakgrund eller nästan
   stilla), och rutan är tappad.
5. Hittas för lite, eller hoppar punkten för långt från den förra, är rutan tappad; tappade
   rutor interpoleras mellan de säkra grannarna (spårade eller ankare) i polära koordinater
   kring greppet, och märks interpolerade.

Indata i hela bildens pixlar (som lederna och trycken), rutorna i sin egen upplösning
(`skala` = rutans px per bildens px). Ut: en punkt per ruta från första till sista ankaret,
med källan `klick` (ankaret), `spar` eller `interpolerad`.
"""
from __future__ import annotations

import math

import numpy as np

from . import faser
from . import klubba as K

STEG = 2                 # METOD M61: rutorna t−2 och t+2
TROSKEL = 40             # METOD M61: gråtoner i båda differenserna
R_MIN, R_MAX = 0.5, 1.35     # METOD M61: korridorens radie i skaft
VINKEL_MIN = math.radians(30.0)   # METOD M61: korridorens halva vinkel, minst …
VINKEL_ANDEL = 0.5       # … och annars halva vridningen mellan ankarna
MIN_PIX = 5              # METOD M61: färre rörliga pixlar = tappad
HUVUD = 0.12             # METOD M61: klubbhuvudets bredd i skaft (bandet ytterst)
BRED = 0.05              # METOD M61: bandet minst så brett tvärs skaftet, i skaft (inte bara skaftet)
SPRANG = 0.5             # METOD M61: längsta steg per ruta, i skaft
KROPP = 0.18             # METOD M61: lemmarnas radie i bålens längd
BAL = 0.35               # METOD M61: bålens radie
HUVUDET = 0.40           # METOD M61: huvudets radie kring näsan
HANDERNA = 0.20          # METOD M61: händernas radie kring handledernas mitt
PLAN_MIN = 0.25          # METOD M61: närmare P1:s hosel än så (i P1-skaft) mäts inte planet
BEN = [(1, 2), (7, 8), (1, 3), (3, 5), (2, 4), (4, 6), (7, 9), (9, 11), (8, 10), (10, 12)]

KALLA_SPAR, KALLA_INTERPOLERAD = "spar", "interpolerad"


def _wrap(a: float) -> float:
    """Vinkeln i (−π, π]."""
    r = math.fmod(a + math.pi, 2.0 * math.pi)
    if r < 0.0:
        r += 2.0 * math.pi
    r -= math.pi
    return math.pi if r == -math.pi else r


def _langd(dx: float, dy: float) -> float:
    """√(dx² + dy²) som Swift räknar den (inte math.hypot, som avrundar annorlunda)."""
    return math.sqrt(dx * dx + dy * dy)


def _mitt(a, b):
    if a is None or b is None:
        return None
    return ((a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0)


def handernas_mitt(t: list[float], leder: list[list]) -> list:
    """Handledernas mitt per ruta med greppregeln (M1), utjämnad (M3); None = saknas."""
    p = np.full((len(t), 2), np.nan)
    for k, L in enumerate(leder):
        a, b = L[5], L[6]
        q = _mitt(a, b) or a or b
        if q is not None:
            p[k] = q
    j = faser.jamna(np.asarray(t, dtype=float), p)
    return [None if not np.isfinite(j[k]).all() else (float(j[k, 0]), float(j[k, 1])) for k in range(len(t))]


def balens_langd(leder: list[list]) -> float | None:
    """Medianen av axlarnas mitt → höfternas mitt över rutorna där alla fyra finns."""
    v = []
    for L in leder:
        a, h = _mitt(L[1], L[2]), _mitt(L[7], L[8])
        if a is not None and h is not None:
            v.append(_langd(a[0] - h[0], a[1] - h[1]))
    return float(np.median(v)) if v else None


def _nara_streck(px, py, a, b, r):
    dx, dy = b[0] - a[0], b[1] - a[1]
    n2 = dx * dx + dy * dy
    if n2 > 0.0:
        u = ((px - a[0]) * dx + (py - a[1]) * dy) / n2
        u = np.minimum(np.maximum(u, 0.0), 1.0)
    else:
        u = np.zeros_like(px)
    ex = px - (a[0] + u * dx)
    ey = py - (a[1] + u * dy)
    return ex * ex + ey * ey <= r * r


def kroppens_streck(L: list, bal: float) -> list:
    """Maskens streck (a, b, radie) i rutans pixlar ur lederna i rutan; en saknad led tar
    bort sina streck."""
    ut = []
    for i, j in BEN:
        if L[i] is not None and L[j] is not None:
            ut.append((L[i], L[j], KROPP * bal))
    a, h = _mitt(L[1], L[2]), _mitt(L[7], L[8])
    if a is not None and h is not None:
        ut.append((a, h, BAL * bal))
    if L[0] is not None:
        ut.append((L[0], L[0], HUVUDET * bal))
    g = _mitt(L[5], L[6]) or L[5] or L[6]
    if g is not None:
        ut.append((g, g, HANDERNA * bal))
    return ut


def hitta(bilder: list[np.ndarray], k: int, g: tuple, theta: float, lim: float, L: float,
          streck: list) -> tuple[float, float] | None:
    """Klubbhuvudet i ruta k i rutans pixlar, eller None (för lite rörelse)."""
    if k - STEG < 0 or k + STEG >= len(bilder):
        return None
    I = bilder[k]
    h, w = I.shape
    rmin, rmax = R_MIN * L, R_MAX * L
    x0, x1 = max(0, int(math.floor(g[0] - rmax))), min(w - 1, int(math.ceil(g[0] + rmax)))
    y0, y1 = max(0, int(math.floor(g[1] - rmax))), min(h - 1, int(math.ceil(g[1] + rmax)))
    if x1 < x0 or y1 < y0:
        return None
    jj, ii = np.mgrid[y0:y1 + 1, x0:x1 + 1]
    cx = ii.astype(float) + 0.5
    cy = jj.astype(float) + 0.5
    vx, vy = cx - g[0], cy - g[1]
    r = np.sqrt(vx * vx + vy * vy)
    ux, uy = math.cos(theta), math.sin(theta)
    ok = (r >= rmin) & (r <= rmax) & (vx * ux + vy * uy >= r * math.cos(lim))
    a = I[y0:y1 + 1, x0:x1 + 1].astype(np.int32)
    d1 = np.abs(a - bilder[k - STEG][y0:y1 + 1, x0:x1 + 1].astype(np.int32))
    d2 = np.abs(a - bilder[k + STEG][y0:y1 + 1, x0:x1 + 1].astype(np.int32))
    ok &= np.minimum(d1, d2) >= TROSKEL
    for p, q, rad in streck:
        ok &= ~_nara_streck(cx, cy, p, q, rad)
    n = int(ok.sum())
    if n < MIN_PIX:
        return None
    rr = r[ok]
    rs = np.sort(rr)[::-1]
    r_end = float(rs[min(2, n - 1)])
    band = ok & (r >= r_end - HUVUD * L)
    m = float(band.sum())
    mx, my = float(cx[band].sum()) / m, float(cy[band].sum()) / m
    # Bredden tvärs riktningen greppet → bandets mitt.
    ex, ey = mx - g[0], my - g[1]
    en = _langd(ex, ey)
    tvars = (vx[band] * (-ey / en) + vy[band] * (ex / en))
    if float(tvars.max() - tvars.min()) < BRED * L:
        return None
    return (mx, my)


def spara(t: list[float], bilder: list[np.ndarray], leder: list[list], ankare: list[dict],
          skala: float) -> list[dict | None]:
    """Banan: en punkt per ruta ({"x", "y", "kalla"} i hela bildens pixlar) från första
    till sista ankaret, None utanför. `leder` per ruta: 13 punkter (x, y) i hela bildens
    pixlar eller None (konfidens under 0,3, M1). `ankare`: markerade positioner med `t`,
    `grepp` och `hosel`. METOD M61"""
    n = len(t)
    ut: list[dict | None] = [None] * n
    if n == 0 or not ankare:
        return ut
    Ls = [[None if q is None else (q[0] * skala, q[1] * skala) for q in L] for L in leder]
    hm = handernas_mitt(t, Ls)
    bal = balens_langd(Ls) or 0.0
    # Ankarna på sina rutor (närmast tiden), i tidsordning, ett per ruta.
    ank: dict[int, dict] = {}
    for a in sorted(ankare, key=lambda a: a["t"]):
        k = min(range(n), key=lambda j: abs(t[j] - a["t"]))
        g = (a["grepp"][0] * skala, a["grepp"][1] * skala)
        hs = (a["hosel"][0] * skala, a["hosel"][1] * skala)
        off = (g[0] - hm[k][0], g[1] - hm[k][1]) if hm[k] is not None else (0.0, 0.0)
        ank[k] = {"g": g, "h": hs, "off": off, "L": _langd(hs[0] - g[0], hs[1] - g[1]),
                  "theta": math.atan2(hs[1] - g[1], hs[0] - g[0])}
    ks = sorted(ank)
    punkt: dict[int, tuple] = {k: ank[k]["h"] for k in ks}
    kalla: dict[int, str] = {k: "klick" for k in ks}
    grepp: dict[int, tuple | None] = {k: ank[k]["g"] for k in ks}
    for ka, kb in zip(ks, ks[1:]):
        A, B = ank[ka], ank[kb]
        dth = _wrap(B["theta"] - A["theta"])
        lim = max(VINKEL_MIN, VINKEL_ANDEL * abs(dth))
        forra, kforra = A["h"], ka
        tappade = []
        for k in range(ka + 1, kb):
            f = (t[k] - t[ka]) / (t[kb] - t[ka])
            L = A["L"] + f * (B["L"] - A["L"])
            if hm[k] is None:
                grepp[k] = None
                tappade.append(k)
                continue
            g = (hm[k][0] + A["off"][0] + f * (B["off"][0] - A["off"][0]),
                 hm[k][1] + A["off"][1] + f * (B["off"][1] - A["off"][1]))
            grepp[k] = g
            q = hitta(bilder, k, g, A["theta"] + f * dth, lim, L, kroppens_streck(Ls[k], bal))
            if q is not None and _langd(q[0] - forra[0], q[1] - forra[1]) > SPRANG * L * (k - kforra):
                q = None
            if q is None:
                tappade.append(k)
                continue
            punkt[k], kalla[k] = q, KALLA_SPAR
            forra, kforra = q, k
        # De tappade: polärt kring greppet mellan de säkra grannarna (spårade eller ankare).
        saker = set(punkt)
        nya = {}
        for k in tappade:
            k0 = max(j for j in range(ka, k) if j in saker)
            k1 = min(j for j in range(k + 1, kb + 1) if j in saker)
            f = (t[k] - t[k0]) / (t[k1] - t[k0])
            g0, g1 = grepp[k0], grepp[k1]
            g = grepp[k] or (g0[0] + f * (g1[0] - g0[0]), g0[1] + f * (g1[1] - g0[1]))
            p0, p1 = punkt[k0], punkt[k1]
            a0 = math.atan2(p0[1] - g0[1], p0[0] - g0[0])
            a1 = math.atan2(p1[1] - g1[1], p1[0] - g1[0])
            r0 = _langd(p0[0] - g0[0], p0[1] - g0[1])
            r1 = _langd(p1[0] - g1[0], p1[1] - g1[1])
            a = a0 + f * _wrap(a1 - a0)
            r = r0 + f * (r1 - r0)
            kalla[k] = KALLA_INTERPOLERAD
            nya[k] = (g[0] + r * math.cos(a), g[1] + r * math.sin(a))
        punkt.update(nya)
    for k, q in punkt.items():
        ut[k] = {"x": q[0] / skala, "y": q[1] / skala, "kalla": kalla[k]}
    return ut


def planet(bana: list, t: list[float], ankare: list[dict], x_tecken: float) -> list[dict]:
    """Klubbhuvudet mot P1-planet bakifrån i varje ruta från P5 till P7: samma vinkel som
    `skaft_plan_p6` (M47) men med banans punkt, grader, + = över planet. Kräver P1, P5 och
    P7 bland ankarna; [] annars. En punkt närmare P1:s hosel än `PLAN_MIN` skaft mäts inte
    (vinkeln vid hoseln är obestämd där, kring träffen). Visas inte i appen än (BESLUT B71).
    METOD M61"""
    pos = {a["position"]: a for a in ankare}
    if not all(p in pos for p in ("P1", "P5", "P7")):
        return []
    s = x_tecken
    g1 = (s * pos["P1"]["grepp"][0], pos["P1"]["grepp"][1])
    h1 = (s * pos["P1"]["hosel"][0], pos["P1"]["hosel"][1])
    L1 = _langd(h1[0] - g1[0], h1[1] - g1[1])
    ut = []
    for k, b in enumerate(bana):
        if b is None or not (pos["P5"]["t"] - 1e-9 <= t[k] <= pos["P7"]["t"] + 1e-9):
            continue
        q = (s * b["x"], b["y"])
        if _langd(q[0] - h1[0], q[1] - h1[1]) < PLAN_MIN * L1:
            continue
        ut.append({"t": t[k], "grader": -K.vinkel_mellan(K._upp(h1, g1), K._upp(h1, q)), "kalla": b["kalla"]})
    return ut
