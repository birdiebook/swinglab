"""Klubbens bana i 3D ur två telefoner (PLAN S7e, METOD MK12, BESLUT B96).

Förmärkarens klubbhuvud (`swinglab-klubba-forslag/1`, MF7) i båda vyerna trianguleras med
S6:s kameror. Där huvudet bara syns i en vy ligger det på en sfär med skaftets längd kring
greppet i 3D (väg b i S7e), och utan huvud i någon vy blir det en lucka: en gissning ska
aldrig se ut som en bana (M61).

1. **Kalibreringen med uppställningen** när lederna ensamma inte räcker (provpasset: ett
   slag, Sampson över spärren och vinkeln mellan 24° och 155° beroende på synken): båda
   kamerorna står i våg och siktar ungefär på spelaren, och huvudets punktpar är med. Flera
   starter i vinkeln mellan kamerorna, den med minst robust Sampson-kostnad vinner.
2. **Synken på huvudet:** huvudet rör sig upp till 40 m/s, så 2 ms synkfel (MK4) är 8 cm av
   banan. Synken finjusteras per slag på huvudets återprojektion kring ledernas synk.
3. **Trianguleringen:** DLT med två vyer där båda har huvudet inom en och en halv ruta,
   annars sfären kring greppet (handledernas mitt i 3D) med slagets skaftlängd.
4. **Skalan** är figurens (benen i adressen, MK10), så att banan står i meter.

Felen nämner slaget och steget, aldrig ett värde (CLAUDE.md, Dataregeln).
"""
from __future__ import annotations

import math

import numpy as np

from . import paket as P
from . import tva_kameror as TK
from .tre_d import kalibrering as kal
from .tre_d import triangulering as tri
from .tre_d.sving import I

MIN_KONF = 0.3                 # BESLUT B95: förslagen från 0,3
MAX_LUCKA_S = 1.5 / 240        # METOD MK12: interpolation mellan två rutor högst så långt isär
SIKTE_MAX = math.radians(15)   # METOD MK12: kameran siktar högst så långt bredvid spelaren
LUTNING_MAX = math.radians(20)  # METOD MK12: kamerans lutning upp eller ner
AVSTAND_A = 3.0                # METOD MK12: FO-kamerans avstånd sätter skalan i passningen (sedan benen)
AVSTAND_B = (1.5, 6.0)         # METOD MK12: DTL-kamerans avstånd, m i samma skala
HOJD_SKILLNAD_MAX = 1.0        # METOD MK12: höjdskillnaden mellan kamerorna, m
STARTER_DEG = tuple(range(-165, 180, 30))   # METOD MK12: vinkelns starter
STRAFF = 200.0                 # METOD MK12: villkorens vikt i px per radian (eller meter)
HUVUD_VIKT = 3.0               # METOD MK12: ett huvudpar väger som tre ledpar (färre, mer utspridda)
SYNK_HUVUD_SOK_S = 0.005       # METOD MK12: huvudets synk söks så nära ledernas
SYNK_HUVUD_STEG_S = 0.00025
SFAR_TOL = 0.25                # METOD MK12: skaftlängden får skilja så mycket (andel) innan sfären tappar
ATERPROJ_MAX_PX = 15.0         # METOD MK12: huvudets återprojektion över det = vyerna ser inte samma sving


# --- huvudet ur förslagsfilen ------------------------------------------------------------

def huvud_spar(forslag: dict, p: P.Paket, s: P.Slag) -> np.ndarray:
    """Slagets klubbhuvud på träffens tid: (N, 4) med t, x, y och konfidens, i tidsordning.
    Tom när filen saknar slaget. METOD MK12"""
    rad = next((x for x in forslag.get("slag", []) if x.get("id") == s.id), None)
    if rad is None:
        return np.zeros((0, 4))
    tr = P.traff_i_serien(p, s)
    r = sorted((q["t"] - tr, h["x"], h["y"], h["konfidens"]) for q in rad["rutor"]
               if (h := q.get("punkter", {}).get("huvud")) and h.get("konfidens", 0) >= MIN_KONF)
    return np.array(r, float).reshape(-1, 4)


def huvud_pa(h: np.ndarray, t: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Huvudet på tiderna t: linjärt mellan två rutor högst MAX_LUCKA_S isär, annars NaN.
    Svarar uv (M, 2) och konfidensen (den svagare rutans, 0 där huvudet saknas)."""
    uv = np.full((len(t), 2), np.nan)
    k = np.zeros(len(t))
    if len(h) < 2:
        return uv, k
    ti = h[:, 0]
    j = np.clip(np.searchsorted(ti, t), 1, len(ti) - 1)
    a, b = ti[j - 1], ti[j]
    ok = (t >= ti[0]) & (t <= ti[-1]) & ((b - a) <= MAX_LUCKA_S)
    w = np.clip((t - a) / np.maximum(b - a, 1e-9), 0, 1)[:, None]
    uv[ok] = (h[j - 1, 1:3] * (1 - w) + h[j, 1:3] * w)[ok]
    k[ok] = np.minimum(h[j - 1, 3], h[j, 3])[ok]
    return uv, k


def _huvudpar(d: dict, forsk: float):
    """Huvudets punktpar på FO:s tider, DTL flyttad med synken: (x1, x2, w) normerade."""
    hA, hB = d["huvudA"], d["huvudB"]
    if not len(hA) or not len(hB):
        return np.zeros((0, 3)), np.zeros((0, 3)), np.zeros(0)
    uvB, kB = huvud_pa(hB, hA[:, 0] + forsk)
    ok = kB > 0
    return TK._normera(hA[ok, 1:3], d["KA"]), TK._normera(uvB[ok], d["KB"]), np.sqrt(hA[ok, 3] * kB[ok])


def _ledpar(d: dict, forsk: float):
    _, a, ka, b, kb = TK._jamnade(d, forsk, TK.KALIB_STEG_S)
    ok = np.isfinite(a).all(-1) & np.isfinite(b).all(-1) & (ka > TK.KALIB_KONF) & (kb > TK.KALIB_KONF)
    return TK._normera(a[ok], d["KA"]), TK._normera(b[ok], d["KB"]), np.sqrt(ka[ok] * kb[ok])


# --- 1. kalibreringen med uppställningen --------------------------------------------------

def _vag_kamera(yaw: float, pitch: float) -> np.ndarray:
    """R (värld → kamera) för en kamera i våg som blickar åt (yaw, pitch); världens z uppåt."""
    cy, sy, cp, sp = math.cos(yaw), math.sin(yaw), math.cos(pitch), math.sin(pitch)
    fram = np.array([cy * cp, sy * cp, sp])
    hoger = np.array([sy, -cy, 0.0])
    return np.stack([hoger, np.cross(fram, hoger), fram])


def uppstallningen(p: np.ndarray):
    """Kamerorna ur uppställningens tal p = (vinkel, lutning A, lutning B, sikte A, sikte B,
    höjdskillnad, avstånd B), spelaren i origo och FO-kameran (A) AVSTAND_A framför. Svarar
    B:s läge mot A (R, t med |t| = 1) och världens uppåt i A:s ram. METOD MK12"""
    theta, lutA, lutB, sikteA, sikteB, dh, dB = p
    CA = np.array([0.0, -AVSTAND_A, 0.0])
    CB = np.array([dB * math.sin(theta), -dB * math.cos(theta), dh])
    RA = _vag_kamera(math.atan2(-CA[1], -CA[0]) + sikteA, lutA)
    RB = _vag_kamera(math.atan2(-CB[1], -CB[0]) + sikteB, lutB)
    R = RB @ RA.T
    t = RB @ (CA - CB)
    return R, t / np.linalg.norm(t), RA @ np.array([0.0, 0.0, 1.0])


def _kostnad(p, par, f_px):
    R, t, _ = uppstallningen(p)
    E = kal._skev(t) @ R
    r = np.concatenate([kal._sampson(E, x1, x2) * f_px * np.sqrt(w) for x1, x2, w in par])
    s = 1.4826 * np.median(np.abs(r)) + 1e-9
    r = r / np.sqrt(1 + (r / (3 * s)) ** 2)          # robust: ett fel större än 3 s väger mindre
    straff = [abs(p[1]) - LUTNING_MAX, abs(p[2]) - LUTNING_MAX, abs(p[3]) - SIKTE_MAX, abs(p[4]) - SIKTE_MAX,
              abs(p[5]) - HOJD_SKILLNAD_MAX, AVSTAND_B[0] - p[6], p[6] - AVSTAND_B[1]]
    return np.concatenate([r, STRAFF * np.maximum(0.0, straff)])


def kalibrera(grupp: list[dict], forsk: list[float]):
    """Kamerorna för en uppställning ur lederna och huvudet, med uppställningen som villkor.
    Svarar (R, t, upp, info) som TK.kalibrera, med Sampson-felet för lederna och huvudet var
    för sig. METOD MK12"""
    led = [_ledpar(d, f) for d, f in zip(grupp, forsk)]
    huv = [_huvudpar(d, f) for d, f in zip(grupp, forsk)]
    huv = [(a, b, w * HUVUD_VIKT) for a, b, w in huv if len(a)]
    par = [x for x in led if len(x[0])] + huv
    if sum(len(x[0]) for x in par) < kal.MIN_PUNKTPAR:
        raise TK.TreDFel("kalibreringen: för få punkter syns i båda vyerna")
    f_px = float(np.median([d["KA"][0, 0] for d in grupp]))
    bast = None
    for deg in STARTER_DEG:
        p0 = np.array([math.radians(deg), 0, 0, 0, 0, 0, AVSTAND_A])
        p = kal.lm(lambda q: _kostnad(q, par, f_px), p0, iter=40)
        k = float(np.sum(_kostnad(p, par, f_px) ** 2))
        if bast is None or k < bast[0]:
            bast = (k, p)
    p = bast[1]
    R, t, upp = uppstallningen(p)
    E = kal._skev(t) @ R

    def samp(xs):
        x1 = np.concatenate([x[0] for x in xs]) if xs else np.zeros((0, 3))
        x2 = np.concatenate([x[1] for x in xs]) if xs else np.zeros((0, 3))
        return round(float(np.median(np.abs(kal._sampson(E, x1, x2)))) * f_px, 2) if len(x1) else None
    kamA, kamB = kal.varld(np.eye(3), np.eye(3), R, t, upp)
    fa, fb = kamA.R[2].copy(), kamB.R[2].copy()
    fa[2] = fb[2] = 0.0
    vinkel = math.degrees(math.acos(float(np.clip(fa @ fb / (np.linalg.norm(fa) * np.linalg.norm(fb)), -1, 1))))
    info = {"kalibrering": "uppstallningen", "lodlinje": "uppstallningen",
            "sampson_px": samp([x for x in led if len(x[0])]), "sampson_huvud_px": samp(huv),
            "vinkel_mellan_kamerorna": round(vinkel, 1), "vinkel_ok": TK.VINKEL_OK[0] <= vinkel <= TK.VINKEL_OK[1],
            "huvudpar": int(sum(len(x[0]) for x in huv))}
    return R, t, upp, info


# --- 2. synken på huvudet -------------------------------------------------------------------

def synka_huvud(kamA, kamB, d: dict, mitt: float) -> float:
    """Synken (s, som TK.synka) vald på minsta återprojektionsfel för huvudet, sökt
    ±SYNK_HUVUD_SOK_S kring `mitt`. Utan huvudpar står `mitt`. METOD MK12"""
    hA, hB = d["huvudA"], d["huvudB"]
    if not len(hA) or not len(hB):
        return mitt
    steg = np.arange(-SYNK_HUVUD_SOK_S, SYNK_HUVUD_SOK_S + 1e-9, SYNK_HUVUD_STEG_S)
    kost = []
    for s in steg:
        uvB, kB = huvud_pa(hB, hA[:, 0] + mitt + s)
        ok = kB > 0
        if ok.sum() < 20:
            kost.append(np.nan)
            continue
        uv = np.stack([hA[ok, None, 1:3], uvB[ok, None]])
        P3 = tri.triangulera([kamA, kamB], uv, np.ones(uv.shape[:3]))
        kost.append(float(np.nanmedian(tri.aterprojektionsfel([kamA, kamB], P3, uv))))
    kost = np.array(kost)
    if not np.isfinite(kost).any():
        return mitt
    i = int(np.nanargmin(kost))
    return mitt + tri._parabel_topp(steg, -kost, i)


def huvudets_aterprojektion(kamA, kamB, d: dict, forsk: float) -> float | None:
    """Medianen av huvudets återprojektion (px) i rutorna där båda vyerna har det."""
    hA, hB = d["huvudA"], d["huvudB"]
    if not len(hA) or not len(hB):
        return None
    uvB, kB = huvud_pa(hB, hA[:, 0] + forsk)
    ok = kB > 0
    if ok.sum() < 5:
        return None
    uv = np.stack([hA[ok, None, 1:3], uvB[ok, None]])
    e = tri.aterprojektionsfel([kamA, kamB], tri.triangulera([kamA, kamB], uv, np.ones(uv.shape[:3])), uv)
    return float(np.nanmedian(e)) if np.isfinite(e).any() else None


def kalibrera_uppstallning(grupp: list[dict], forsk: list[float]):
    """Hela vägen för en uppställning när lederna inte räcker: kalibreringen med villkoren,
    synken på lederna och sedan på huvudet, och en kalibrering till på de slag där vyerna
    ser samma sving (huvudets återprojektion under ATERPROJ_MAX_PX). Svarar (R, t, upp,
    info, forsk). METOD MK12"""
    R, t, upp, info = kalibrera(grupp, forsk)
    for _ in range(2):
        forsk = [TK.synka(*TK.kameror(d, R, t, upp), d, f) for d, f in zip(grupp, forsk)]
        forsk = [synka_huvud(*TK.kameror(d, R, t, upp), d, f) for d, f in zip(grupp, forsk)]
        rep = [huvudets_aterprojektion(*TK.kameror(d, R, t, upp), d, f) for d, f in zip(grupp, forsk)]
        bra = [i for i, e in enumerate(rep) if e is not None and e <= ATERPROJ_MAX_PX]
        urval = bra or list(range(len(grupp)))
        R, t, upp, info = kalibrera([grupp[i] for i in urval], [forsk[i] for i in urval])
    info["slag_i_kalibreringen"] = [grupp[i]["dtl"].id + "·" + grupp[i]["fo"].id for i in urval]
    return R, t, upp, info, forsk


# --- 3. trianguleringen och sfären ----------------------------------------------------------

def _stralen(kam, uv: np.ndarray) -> np.ndarray:
    """Strålarnas riktning i världen (enhetsvektorer) genom pixlarna uv (M, 2)."""
    d = np.column_stack([uv, np.ones(len(uv))]) @ np.linalg.inv(kam.K).T @ kam.R
    return d / np.linalg.norm(d, axis=1, keepdims=True)


def sfar(C: np.ndarray, d: np.ndarray, G: np.ndarray, L: float) -> tuple[np.ndarray, np.ndarray]:
    """Strålen C + λ·d mot sfären |X − G| = L: de två skärningarna (M, 2, 3), NaN där strålen
    missar sfären. METOD MK12"""
    m = C[None, :] - G
    b = np.sum(d * m, axis=1)
    c = np.sum(m * m, axis=1) - L * L
    disk = b * b - c
    rot = np.sqrt(np.where(disk >= 0, disk, np.nan))
    lam = np.stack([-b - rot, -b + rot], 1)
    X = C[None, None, :] + lam[..., None] * d[:, None, :]
    return X, disk >= 0


def _narmast(X2: np.ndarray, ref: np.ndarray) -> np.ndarray:
    """Den av de två skärningarna (M, 2, 3) som ligger närmast ref (M, 3)."""
    avst = np.linalg.norm(X2 - ref[:, None, :], axis=-1)
    i = np.where(np.isnan(avst[:, 0]), 1, np.where(np.isnan(avst[:, 1]), 0, np.argmin(np.nan_to_num(avst, nan=1e9), 1)))
    return X2[np.arange(len(X2)), i]


def bana(kamA, kamB, d: dict, forsk: float, tg: np.ndarray, X: np.ndarray) -> dict | None:
    """Huvudets och greppets bana för ett slag på FO:s klocka (träffen = 0), i kedjans
    enheter: tiderna där någon vy har huvudet, huvudet (M, 3), greppet (M, 3), källan per
    punkt (2 = båda vyerna, 1 = bara FO, −1 = bara DTL), skaftets längd och huvudets
    återprojektion. `tg`, `X` är slagets triangulerade leder. METOD MK12"""
    hA, hB = d["huvudA"], d["huvudB"]
    tider = np.unique(np.concatenate([hA[:, 0] if len(hA) else [], hB[:, 0] - forsk if len(hB) else []]))
    tider = tider[(tider >= tg[0]) & (tider <= tg[-1])] if len(tg) else tider[:0]
    if not len(tider):
        return None
    uvA, kA = huvud_pa(hA, tider)
    # en FO-ruta som finns räknas som sig själv, inte som interpolationen mellan grannarna
    uvB, kB = huvud_pa(hB, tider + forsk)
    grepp_led = (X[:, I["v_handled"]] + X[:, I["h_handled"]]) / 2
    G = np.column_stack([np.interp(tider, tg, grepp_led[:, a], left=np.nan, right=np.nan) for a in range(3)])
    H = np.full((len(tider), 3), np.nan)
    kalla = np.zeros(len(tider), int)
    tva = (kA > 0) & (kB > 0)
    if tva.any():
        uv = np.stack([uvA[tva, None], uvB[tva, None]])
        H[tva] = tri.triangulera([kamA, kamB], uv, np.ones(uv.shape[:3]))[:, 0]
        kalla[tva] = 2
    rep = None
    if tva.any():
        e = tri.aterprojektionsfel([kamA, kamB], H[tva, None], np.stack([uvA[tva, None], uvB[tva, None]]))
        rep = float(np.nanmedian(e)) if np.isfinite(e).any() else None
    if rep is None or rep > ATERPROJ_MAX_PX:
        return {"fel": "vyerna ser inte samma sving (huvudets återprojektion)" if rep is not None
                else "huvudet syns inte i båda vyerna samtidigt"}
    langd = np.linalg.norm(H - G, axis=1)
    fin = np.isfinite(langd) & (kalla == 2)
    L = float(np.median(langd[fin])) if fin.sum() >= 5 else None
    # En vy: sfären kring greppet, den skärning som ligger närmast de två vyernas bana
    if L is not None:
        tv = np.where(kalla == 2)[0]
        for kam, uv, k, kod in ((kamA, uvA, kA, 1), (kamB, uvB, kB, -1)):
            en = (k > 0) & (kalla == 0) & np.isfinite(G).all(1)
            if not en.any():
                continue
            X2, traff = sfar(kam.centrum, _stralen(kam, uv[en]), G[en], L)
            ref = np.column_stack([np.interp(tider[en], tider[tv], H[tv, a]) for a in range(3)])
            Xv = _narmast(X2, ref)
            ok = traff & (np.linalg.norm(Xv - ref, axis=1) < SFAR_TOL * 4 * L)
            idx = np.where(en)[0][ok]
            H[idx], kalla[idx] = Xv[ok], kod
    ok = np.isfinite(H).all(1)
    return {"t": tider[ok], "huvud": H[ok], "grepp": G[ok], "kalla": kalla[ok], "skaft": L,
            "aterprojektion_px": rep, "langd": langd[ok]}


# --- 4. en vy: sfären kring greppet med greppets djup ur en mall (väg b i S7e) -----------------

def fas(t: np.ndarray, pos: dict) -> np.ndarray:
    """Svingens fas: 0 vid P1, 1 vid toppen (P4), 2 vid träffen (t = 0), linjärt mellan och
    förlängt med närmaste stycke utanför. Utan P1 och P4: t självt. METOD MK12"""
    p1, p4 = pos.get("P1"), pos.get("P4")
    if p1 is None or p4 is None or not p1 < p4 < 0:
        return np.asarray(t, float)
    t = np.asarray(t, float)
    return np.where(t < p4, (t - p1) / (p4 - p1), 1 + (t - p4) / (0 - p4))


def djupmall(b: dict, pos: dict, kamA) -> dict:
    """Greppets och huvudets djup i FO-kameran (längs blicken, kedjans enheter) mot fasen, ur
    en bana med båda vyerna: mallen som väg b lägger greppet i. METOD MK12"""
    m = b["kalla"] == 2
    dg = kamA.djup(b["grepp"][m])
    dh = kamA.djup(b["huvud"][m])
    ok = np.isfinite(dg) & np.isfinite(dh)
    f = fas(b["t"][m][ok], pos)
    i = np.argsort(f)
    L = b["langd"][m][ok]
    return {"fas": f[i], "grepp": dg[ok][i], "huvud": dh[ok][i], "langd": L[i], "skaft": b["skaft"]}


def _punkt_pa_djup(kam, uv: np.ndarray, z: np.ndarray) -> np.ndarray:
    """Världspunkten på strålen genom pixlarna uv där djupet längs blicken är z."""
    x = np.column_stack([uv, np.ones(len(uv))]) @ np.linalg.inv(kam.K).T * z[:, None]
    return x @ kam.R + kam.centrum


def bana_en_vy(kam, t_led: np.ndarray, uv_led: np.ndarray, k_led: np.ndarray, h: np.ndarray, pos: dict,
               mall: dict, konstant: bool = False) -> dict | None:
    """Huvudets bana ur en vy: greppet på strålen genom handledernas mitt på mallens djup för
    fasen (eller, med `konstant`, mallens djup i adressen hela svingen), och huvudet på
    sfären med mallens skaftlängd kring det. Av sfärens två skärningar tas den som ligger
    närmast mallens huvuddjup för fasen. Missar strålen sfären tas punkten där den
    kommer närmast, märkt. Kedjans enheter. METOD MK12"""
    if not len(h) or mall is None or not len(mall["fas"]) or not mall["skaft"]:
        return None
    v, hh = I["v_handled"], I["h_handled"]
    if ((k_led[:, v] > 0) & (k_led[:, hh] > 0)).sum() < 10:
        return None
    inne = (h[:, 0] >= t_led[0]) & (h[:, 0] <= t_led[-1])
    h = h[inne]
    t = h[:, 0]
    # handlederna utjämnade som i trianguleringen (MK5), så att greppet är samma som väg a:s
    uvj, kj = tri.jamna(t_led, uv_led[:, [v, hh]], k_led[:, [v, hh]], t, TK.HALVBREDD_2D)
    ok = np.isfinite(uvj).all((1, 2))
    t, h, uvj = t[ok], h[ok], uvj[ok]
    g2 = uvj.mean(1)
    f = fas(t, pos)
    if konstant:
        z0 = float(np.interp(0.0, mall["fas"], mall["grepp"]))
        zg = np.full(len(t), z0)
    else:
        zg = np.interp(f, mall["fas"], mall["grepp"])
    zh = np.interp(f, mall["fas"], mall["huvud"])
    G = _punkt_pa_djup(kam, g2, zg)
    d = _stralen(kam, h[:, 1:3])
    L = np.interp(f, mall["fas"], mall["langd"]) if "langd" in mall else np.full(len(t), mall["skaft"])
    X2, traff = sfar(kam.centrum, d, G, L)
    djup2 = np.stack([kam.djup(X2[:, 0]), kam.djup(X2[:, 1])], 1)
    i = np.argmin(np.abs(np.nan_to_num(djup2, nan=1e9) - zh[:, None]), 1)
    H = X2[np.arange(len(t)), i]
    # strålen missar sfären: närmaste punkten på strålen
    m = ~traff
    if m.any():
        lam = np.sum(d[m] * (G[m] - kam.centrum), axis=1)
        H[m] = kam.centrum + lam[:, None] * d[m]
    return {"t": t, "huvud": H, "grepp": G, "kalla": np.where(traff, 1, 0), "skaft": mall["skaft"],
            "aterprojektion_px": None, "langd": np.linalg.norm(H - G, axis=1)}


def jamfor_banor(a: dict, b: dict) -> dict | None:
    """Väg b mot väg a på de tider där a har båda vyerna: huvudets avstånd i 3D (enheter),
    median och p95, och per fas (baksvingen, nedsvingen, efter träffen) med a:s tider."""
    m = a["kalla"] == 2
    if not m.any() or b is None or not len(b["t"]):
        return None
    Hb = np.column_stack([np.interp(a["t"][m], b["t"], b["huvud"][:, k], left=np.nan, right=np.nan) for k in range(3)])
    e = np.linalg.norm(Hb - a["huvud"][m], axis=1)
    ok = np.isfinite(e)
    if not ok.any():
        return None
    return {"median": float(np.median(e[ok])), "p95": float(np.percentile(e[ok], 95)), "n": int(ok.sum())}


FORE_P1_S = 0.05              # METOD MK12: banan börjar så långt före P1
EFTER_FINISH_S = 0.10          # METOD MK12: och slutar så långt efter huvudets högsta punkt efter träffen
FINISH_SOK_S = 0.8             # METOD MK12: den högsta punkten söks inom så lång tid efter träffen


def svingen(b: dict, p1: float | None) -> dict:
    """Banan från strax före P1 till strax efter finishen (huvudets högsta punkt efter träffen,
    världens z uppåt): före och efter står klubban still eller sänks, och det ser ut som
    klotter. METOD MK12"""
    t, z = b["t"], b["huvud"][:, 2]
    fran = (p1 - FORE_P1_S) if p1 is not None else t[0]
    efter = (t > 0) & (t <= FINISH_SOK_S)
    till = float(t[efter][np.argmax(z[efter])]) + EFTER_FINISH_S if efter.any() else t[-1]
    m = (t >= fran) & (t <= till)
    return {k: (v[m] if isinstance(v, np.ndarray) and len(v) == len(t) else v) for k, v in b.items()}


def fart(t: np.ndarray, H: np.ndarray) -> np.ndarray:
    """Huvudets fart (enheter per s) ur grannpunkterna; NaN vid en lucka över tre rutor."""
    v = np.full(len(t), np.nan)
    if len(t) < 3:
        return v
    dt = t[2:] - t[:-2]
    ok = dt <= 4 / 240
    v[1:-1][ok] = np.linalg.norm(H[2:] - H[:-2], axis=1)[ok] / dt[ok]
    return v


def langdens_spridning(b: dict, fran: float, till: float) -> dict | None:
    """Skaftets längd grepp → huvud över [fran, till] i de två vyernas punkter: medianen och
    p5–p95 (enheter). Ska vara konstant, så spridningen är ett fel utan facit. METOD MK12"""
    m = (b["kalla"] == 2) & (b["t"] >= fran) & (b["t"] <= till) & np.isfinite(b["langd"])
    if m.sum() < 5:
        return None
    x = b["langd"][m]
    return {"median": float(np.median(x)), "p5": float(np.percentile(x, 5)), "p95": float(np.percentile(x, 95)),
            "n": int(m.sum())}
