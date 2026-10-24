"""Klubbhuvudets bana mellan ankarna (PLAN S7b, METOD M61, BESLUT B71): facit för
SwingLabKit (`KlubbSpar`, samma tal inom 1e-6, BESLUT B12).

Johannes tryck vid P1–P10 (S7a, `KlubbMarkering`) är ankare. Bara mellan två ankare som är
grannar i svingens ordning (P1→P2→…→P10) spåras klubbhuvudet; saknas en position mellan två
ankare ritas inget där. Spårningen, ruta för ruta i tidsordning (så att appen kan strömma
rutorna):

1. Rörelsen i ruta k är min(|I_k − I_före|, |I_k − I_efter|), rutorna 2/240 s före och
   efter: pixlar som skiljer sig från båda, alltså det som är där just i ruta k. Tröskeln
   är brusanpassad per ruta: 3,5 · σ ur differensens MAD i sökrutan, minst 8 gråtoner.
2. Kroppen maskeras ut ur Visions leder i rutan (streck kring lederna, bålen och huvudet).
3. Sökningen begränsas till en korridor kring greppet: radien 0,5–1,35 skaft och vinkeln
   kring skaftets riktning, linjärt i tiden mellan ankarnas riktningar. Greppet är
   handledernas mitt (utjämnad, M3) plus ankarnas förskjutning mellan handlederna och det
   tryckta greppet; skaftets längd är ankarnas, linjärt i tiden.
4. Rör sig mer än 1 % av sökrutan utanför kroppen och korridoren (kameran skakar, en
   textur rör sig) är rutan tappad.
5. Klubbhuvudet är mitten av de rörliga pixlarna ytterst i korridoren (bandet som är ett
   klubbhuvud brett, räknat från den tredje yttersta pixeln). Är bandet smalare tvärs
   riktningen än ett klubbhuvud syns bara skaftet, och rutan är tappad.

Sedan, utan bilderna: förskjutningen mellan huvudets rörliga mitt och hoseln mäts vid ankarna
(i skaftets koordinater) och dras av, interpolerad mellan ankarna. En punkt vars avstånd till
greppet skiljer mer än 0,25 skaft från det väntade, som hoppar för långt från den förra, eller
som ligger mer än 0,10 skaft från interpolationen mellan sina säkra grannar är tappad. Tappade
rutor interpoleras mellan de säkra grannarna (spårade eller ankare) i polära koordinater kring
greppet och märks interpolerade. En punkt utanför bilden skrivs inte.

Indata i hela bildens pixlar (som lederna och trycken), rutorna i sin egen upplösning
(`skala` = rutans px per bildens px). Ut: en punkt per ruta, eller None där ingen bana räknas,
med källan `klick` (ankaret), `spar` eller `interpolerad`.
"""
from __future__ import annotations

import math

import numpy as np

from . import faser
from . import klubba as K

STEG_S = 2.0 / 240     # METOD M61: rutorna så långt före och efter, s
TROSKEL_K = 3.5          # METOD M61: tröskeln i σ av differensen (σ ur MAD) …
TROSKEL_MIN = 8.0        # … men minst så många gråtoner
R_MIN, R_MAX = 0.5, 1.35     # METOD M61: korridorens radie i skaft
VINKEL_MIN = math.radians(30.0)   # METOD M61: korridorens halva vinkel, minst …
VINKEL_ANDEL = 0.5       # … och annars halva vridningen mellan ankarna
MIN_PIX = 5              # METOD M61: färre rörliga pixlar = tappad
HUVUD = 0.12             # METOD M61: klubbhuvudets bredd i skaft (bandet ytterst)
BRED = 0.05              # METOD M61: bandet minst så brett tvärs riktningen, i skaft (inte bara skaftet)
SKAK = 0.01              # METOD M61: rörliga pixlar utanför kroppen och korridoren, andel av sökrutan
RADIE_TOL = 0.25         # METOD M61: |avståndet till greppet − skaftet| högst så mycket, i skaft
SPRANG_S = 120.0         # METOD M61: längsta förflyttning, skaft per sekund
MITT_MIN = 0.03          # METOD M61: förskjutningen mitt → hosel räknas från så mycket, i skaft …
MITT_MAX = 0.12          # … och högst så mycket (mer är något annat än klubbhuvudet)
GRANNE = 0.10            # METOD M61: högst så långt från grannarnas interpolation, i skaft
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


def grannrutor(t: list[float], k: int) -> tuple[int, int] | None:
    """Rutorna närmast STEG_S före och efter ruta k (högst tre rutor bort), eller None när
    ingen ligger inom 0,6 STEG_S från det (en saknad ruta ger 3/240 s)."""
    def bast(js):
        j = min(js, key=lambda j: abs(abs(t[k] - t[j]) - STEG_S), default=None)
        return j if j is not None and abs(abs(t[k] - t[j]) - STEG_S) <= 0.6 * STEG_S else None
    a = bast([j for j in range(k - 3, k) if j >= 0])
    b = bast([j for j in range(k + 1, k + 4) if j < len(t)])
    return None if a is None or b is None else (a, b)


def _median(v: np.ndarray) -> float:
    s = np.sort(v)
    n = s.size
    return float(s[n // 2]) if n % 2 == 1 else (float(s[n // 2 - 1]) + float(s[n // 2])) / 2.0


def hitta(I: np.ndarray, A: np.ndarray, B: np.ndarray, g: tuple, theta: float, lim: float, L: float,
          streck: list) -> tuple[float, float] | None:
    """Klubbhuvudets rörliga mitt i ruta I (rutorna A före och B efter) i rutans pixlar, eller
    None: för lite rörelse, bara skaftet, eller skak."""
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
    korridor = (r >= rmin) & (r <= rmax) & (vx * ux + vy * uy >= r * math.cos(lim))
    a = I[y0:y1 + 1, x0:x1 + 1].astype(np.int32)
    d1 = a - A[y0:y1 + 1, x0:x1 + 1].astype(np.int32)
    d2 = a - B[y0:y1 + 1, x0:x1 + 1].astype(np.int32)
    # Brusets σ ur differensens MAD (1,4826 · MAD) i hela sökrutan. METOD M61
    m = _median(d1.ravel())
    sigma = 1.4826 * _median(np.abs(d1.ravel() - m))
    troskel = max(TROSKEL_MIN, TROSKEL_K * sigma)
    ror = np.minimum(np.abs(d1), np.abs(d2)) >= troskel
    kropp = np.zeros(ror.shape, dtype=bool)
    for p, q, rad in streck:
        kropp |= _nara_streck(cx, cy, p, q, rad)
    if int((ror & ~kropp & ~korridor).sum()) > SKAK * ror.size:
        return None
    ok = ror & korridor & ~kropp
    # Fläckarna (8-grannar) bland de rörliga pixlarna: klubbhuvudet är fläcken vars yttre kant
    # ligger närmast skaftets längd (en skugga eller bollen ligger längre ut, en bit av skaftet
    # längre in), bland dem med minst MIN_PIX pixlar.
    ok = _flacken(ok, r, L)
    if ok is None:
        return None
    n = int(ok.sum())
    rs = np.sort(r[ok])[::-1]
    r_end = float(rs[min(2, n - 1)])
    band = ok & (r >= r_end - HUVUD * L)
    mb = float(band.sum())
    mx, my = float(cx[band].sum()) / mb, float(cy[band].sum()) / mb
    # Bredden tvärs riktningen greppet → bandets mitt.
    ex, ey = mx - g[0], my - g[1]
    en = _langd(ex, ey)
    tvars = (vx[band] * (-ey / en) + vy[band] * (ex / en))
    if float(tvars.max() - tvars.min()) < BRED * L:
        return None
    return (mx, my)


def _flacken(ok: np.ndarray, r: np.ndarray, L: float) -> np.ndarray | None:
    """Fläcken (8-grannar) med minst MIN_PIX pixlar vars yttre kant (den tredje yttersta
    pixeln) ligger närmast L från greppet; lika: den som hittas först rad för rad. None utan
    någon. METOD M61"""
    h, w = ok.shape
    etikett = np.full(ok.shape, -1, dtype=np.int64)
    basta, basta_r, nr = None, math.inf, 0
    ys, xs = np.nonzero(ok)
    for y0, x0 in zip(ys.tolist(), xs.tolist()):
        if etikett[y0, x0] >= 0:
            continue
        stack = [(y0, x0)]
        etikett[y0, x0] = nr
        pix = []
        while stack:
            y, x = stack.pop()
            pix.append((y, x))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < h and 0 <= xx < w and ok[yy, xx] and etikett[yy, xx] < 0:
                        etikett[yy, xx] = nr
                        stack.append((yy, xx))
        if len(pix) >= MIN_PIX:
            rr = sorted((float(r[y, x]) for y, x in pix), reverse=True)
            d = abs(rr[2] - L)
            if d < basta_r:
                basta, basta_r = nr, d
        nr += 1
    return None if basta is None else etikett == basta


def segment(ankare: list[dict]) -> list[tuple[int, int]]:
    """Paren av ankare (index i tidsordningen) som är grannar i svingens ordning."""
    ut = []
    for i in range(len(ankare) - 1):
        a, b = ankare[i]["position"], ankare[i + 1]["position"]
        if a in K.POSITIONER and b in K.POSITIONER and K.POSITIONER.index(b) == K.POSITIONER.index(a) + 1:
            ut.append((i, i + 1))
    return ut


def _polar(g0, p0, g1, p1, g, f):
    """Punkten en andel f mellan p0 (kring g0) och p1 (kring g1), polärt kring g."""
    a0 = math.atan2(p0[1] - g0[1], p0[0] - g0[0])
    a1 = math.atan2(p1[1] - g1[1], p1[0] - g1[0])
    r0 = _langd(p0[0] - g0[0], p0[1] - g0[1])
    r1 = _langd(p1[0] - g1[0], p1[1] - g1[1])
    a = a0 + f * _wrap(a1 - a0)
    r = r0 + f * (r1 - r0)
    return (g[0] + r * math.cos(a), g[1] + r * math.sin(a))


def spara(t: list[float], bilder, leder: list[list], ankare: list[dict], skala: float,
          bredd: int | None = None, hojd: int | None = None) -> list[dict | None]:
    """Banan: en punkt per ruta ({"x", "y", "kalla"} i hela bildens pixlar), None där ingen
    bana räknas. `bilder[k]` ger rutan (läses i tidsordning, högst tre rutor bort från k);
    `leder` per ruta: 13 punkter (x, y) i hela bildens pixlar eller None (konfidens under
    0,3, M1); `ankare`: markerade positioner med `position`, `t`, `grepp` och `hosel`;
    `bredd`, `hojd`: hela bilden (punkter utanför skrivs inte). METOD M61"""
    n = len(t)
    ut: list[dict | None] = [None] * n
    if n == 0 or not ankare:
        return ut
    Ls = [[None if q is None else (q[0] * skala, q[1] * skala) for q in L] for L in leder]
    hm = handernas_mitt(t, Ls)
    bal = balens_langd(Ls) or 0.0
    # Ankarna på sina rutor (närmast tiden), i tidsordning, ett per ruta.
    ank: list[dict] = []
    for a in sorted(ankare, key=lambda a: a["t"]):
        k = min(range(n), key=lambda j: abs(t[j] - a["t"]))
        g = (a["grepp"][0] * skala, a["grepp"][1] * skala)
        hs = (a["hosel"][0] * skala, a["hosel"][1] * skala)
        off = (g[0] - hm[k][0], g[1] - hm[k][1]) if hm[k] is not None else (0.0, 0.0)
        post = {"k": k, "position": a["position"], "g": g, "h": hs, "off": off,
                "L": _langd(hs[0] - g[0], hs[1] - g[1]), "theta": math.atan2(hs[1] - g[1], hs[0] - g[0])}
        if ank and ank[-1]["k"] == k:
            ank[-1] = post
        else:
            ank.append(post)
    seg = segment(ank)
    # Geometrin per ruta: (segmentet, andelen f, greppet, väntad vinkel, korridorens halva vinkel, L).
    geo: dict[int, tuple] = {}
    for i, j in seg:
        A, B = ank[i], ank[j]
        dth = _wrap(B["theta"] - A["theta"])
        lim = max(VINKEL_MIN, VINKEL_ANDEL * abs(dth))
        for k in range(A["k"] + 1, B["k"]):
            f = (t[k] - t[A["k"]]) / (t[B["k"]] - t[A["k"]])
            L = A["L"] + f * (B["L"] - A["L"])
            g = None
            if hm[k] is not None:
                g = (hm[k][0] + A["off"][0] + f * (B["off"][0] - A["off"][0]),
                     hm[k][1] + A["off"][1] + f * (B["off"][1] - A["off"][1]))
            geo[k] = ((i, j), f, g, A["theta"] + f * dth, lim, L)
    for i, A in enumerate(ank):
        geo.setdefault(A["k"], (None, 0.0, A["g"], A["theta"], VINKEL_MIN, A["L"]))
    # 1. Rörelsen, ruta för ruta i tidsordning (rutorna strömmar).
    ra: dict[int, tuple] = {}
    for k in sorted(geo):
        _, _, g, th, lim, L = geo[k]
        gr = grannrutor(t, k)
        if g is None or gr is None or L <= 0:
            continue
        I, A_, B_ = bilder[k], bilder[gr[0]], bilder[gr[1]]
        if I is None or A_ is None or B_ is None or A_.shape != I.shape or B_.shape != I.shape:
            continue
        q = hitta(I, A_, B_, g, th, lim, L, kroppens_streck(Ls[k], bal))
        if q is not None:
            ra[k] = q
    # 2. Förskjutningen mitt → hosel vid ankarna, i skaftets koordinater (längs, tvärs).
    for A in ank:
        q = ra.get(A["k"])
        if q is None:
            A["mitt"] = None
            continue
        ux, uy = math.cos(A["theta"]), math.sin(A["theta"])
        dx, dy = q[0] - A["h"][0], q[1] - A["h"][1]
        # Under MITT_MIN är den tryckens brus och spårningens egen skevhet, inte huvudets form.
        # Över MITT_MAX är det något annat som rör sig vid ankaret (en skugga, bollen).
        d = _langd(dx, dy)
        A["mitt"] = (dx * ux + dy * uy, dx * -uy + dy * ux) if MITT_MIN * A["L"] <= d <= MITT_MAX * A["L"] else None
    punkt: dict[int, tuple] = {A["k"]: A["h"] for A in ank}
    kalla: dict[int, str] = {A["k"]: "klick" for A in ank}
    grepp: dict[int, tuple | None] = {A["k"]: A["g"] for A in ank}
    for i, j in seg:
        A, B = ank[i], ank[j]
        ka, kb = A["k"], B["k"]
        if A["mitt"] is not None and B["mitt"] is not None:
            mitt = lambda f: (A["mitt"][0] + f * (B["mitt"][0] - A["mitt"][0]), A["mitt"][1] + f * (B["mitt"][1] - A["mitt"][1]))
        else:
            fast = A["mitt"] or B["mitt"] or (0.0, 0.0)
            mitt = lambda f, fast=fast: fast
        # 3. Mitten → hoseln, radien och språnget, i tidsordning.
        forra, kforra = A["h"], ka
        sakra: dict[int, tuple] = {}
        for k in range(ka + 1, kb):
            _, f, g, _, _, L = geo[k]
            grepp[k] = g
            q = ra.get(k)
            if q is None or g is None:
                continue
            ex, ey = q[0] - g[0], q[1] - g[1]
            en = _langd(ex, ey)
            if en <= 0:
                continue
            ux, uy = ex / en, ey / en
            m = mitt(f)
            p = (q[0] - (m[0] * ux - m[1] * uy), q[1] - (m[0] * uy + m[1] * ux))
            r = _langd(p[0] - g[0], p[1] - g[1])
            if abs(r - L) > RADIE_TOL * L:
                continue
            if _langd(p[0] - forra[0], p[1] - forra[1]) > SPRANG_S * L * (t[k] - t[kforra]):
                continue
            sakra[k] = p
            forra, kforra = p, k
        # 4. Grannarna: interpolationen mellan förra och nästa säkra punkt (före prövningen).
        alla = {ka: A["h"], kb: B["h"], **sakra}
        nycklar = sorted(alla)
        bort = []
        for idx in range(1, len(nycklar) - 1):
            k = nycklar[idx]
            k0, k1 = nycklar[idx - 1], nycklar[idx + 1]
            f = (t[k] - t[k0]) / (t[k1] - t[k0])
            fo = _polar(grepp[k0], alla[k0], grepp[k1], alla[k1], grepp[k], f)
            if _langd(alla[k][0] - fo[0], alla[k][1] - fo[1]) > GRANNE * geo[k][5]:
                bort.append(k)
        for k in bort:
            del sakra[k]
        for k, p in sakra.items():
            punkt[k], kalla[k] = p, KALLA_SPAR
        # 5. De tappade: polärt kring greppet mellan de säkra grannarna (spårade eller ankare).
        saker = {ka: A["h"], kb: B["h"], **sakra}
        for k in range(ka + 1, kb):
            if k in sakra:
                continue
            k0 = max(j for j in range(ka, k) if j in saker)
            k1 = min(j for j in range(k + 1, kb + 1) if j in saker)
            f = (t[k] - t[k0]) / (t[k1] - t[k0])
            g0, g1 = grepp[k0], grepp[k1]
            g = grepp[k] or (g0[0] + f * (g1[0] - g0[0]), g0[1] + f * (g1[1] - g0[1]))
            punkt[k] = _polar(g0, saker[k0], g1, saker[k1], g, f)
            kalla[k] = KALLA_INTERPOLERAD
    for k, q in punkt.items():
        x, y = q[0] / skala, q[1] / skala
        if bredd is not None and hojd is not None and not (0.0 <= x <= bredd and 0.0 <= y <= hojd):
            continue
        ut[k] = {"x": x, "y": y, "kalla": kalla[k]}
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
