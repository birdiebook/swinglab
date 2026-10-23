"""Påhittade svingar med kända tal (CLAUDE.md, Dataregeln: inga riktiga leder).

    python3 tools/pc/generera.py --swift     # skriver SwingLabKit/Tests/SwingTests/Fixturer.swift
    python3 tools/pc/generera.py fo > x.json # en påhittad FO-sving som JSON

En sving byggs som en ledfigur i bildens plan, i cm (X mot målet eller bollen,
Z uppåt), och ritas till pixlar med 4 px/cm. Varje mått som testerna känner
står som en parameter: `sway=(0, -6, 8, 14)` betyder att bäckenet ligger
6 cm bakom adressen vid toppen, 8 cm framför vid träffen och 14 cm i finishen.
Kroppen står still på platar kring toppen och träffen, så att utjämningen och
toppens tid inte rör talen. Händerna har ingen platå: deras högsta punkt är
toppen. Vid träffen står även händerna still (±0,04 s), så att deras läge i
klicket inte beror på utjämningen.

Figuren är skalad med samma kvoter som skalan (METOD M2), så centimetrarna
stämmer exakt: bålen bakifrån och benen framifrån har kvoternas längd i adressen.

`--swift` skriver indata och Pythons resultat som JSON-strängar i en
Swift-källfil (BESLUT B12), så att Swift-testerna jämför sina tal med Pythons.
"""
from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

import numpy as np

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "pc"

from . import katalog as KAT  # noqa: E402
from . import matt as M  # noqa: E402
from . import session as S  # noqa: E402
from .format import FRAN_FIL, LEDER_FIL, las  # noqa: E402

ROT = Path(__file__).resolve().parents[2]
FIXTURFIL = ROT / "SwingLabKit" / "Tests" / "SwingTests" / "Fixturer.swift"

K_PX = 4.0                   # px per cm
X0, Y0 = 540.0, 1750.0       # bildens origo för figurens fötter
FREKVENS = 240.0
SAKNAS = 0.36                # andel av 240-rutnätet som saknas (som i oktober)
KROPP_SEN = 0.10             # kroppen börjar röra sig 0,1 s efter händerna
INF = math.inf

# Tiderna (s): start, topp, klick, klippets slut. Baksving 0,95 s, nedsving 0,30 s.
TIDER = {"start": 1.25, "topp": 2.20, "klick": 2.50, "slut": 3.80}

FO = {
    "sway": (0, -6, 8, 14),            # bäckenets sway, cm: adress, topp, träff, finish
    "lyft": (0, 1, 2, 5),              # bäckenets lyft, cm
    "sidbojning": (6, 4, 25, 10),      # grader, + bort från målet
    "hoftlutning": (2, 6, 8, 0),       # grader, + bakre sidan lägre
    "axellutning": (8, 20, 30, 0),
    "huvud_sway": (0, -3, -2, 10),
    "huvud_lyft": (0, -1, -1, 2),
    "armbage": (5, 15, 20, 90),        # främre armbågens böjning: adress, topp, efter träff, finish
    "arm": (-14, -130, -6, 140),       # främre överarmen från lodlinjen nedåt, + mot målet
    "stans": 48.0,                     # fotlederna isär, cm
    "kna_sway_f": (0, 3, 9, 12),       # främre knäets sway, cm (METOD M34)
    "kna_sway_b": (0, -4, 7, 28),      # bakre knäets sway, cm
    "axelbredd": 40.0,
    "hoftbredd": 32.0,
}
DTL = {
    "bojning": (40, 38, 34, 10),       # bröstets böjning, grader, + mot bollen
    "thrust": (0, -2, 3, 8),           # bäckenets thrust, cm, + mot bollen
    "lyft": (0, 0.5, 3, 6),
    "huvud_x": (0, -1, 2, 8),
    "huvud_lyft": (0, -0.5, 1, 12),
    "kna_bak": (22, 30, 25, 10),       # bakre knäets böjning, grader
    "kna_fram": (20, 24, 12, 8),       # främre knäets böjning, grader (METOD M33)
    "armbage_bak": (10, 60, 5, 40),    # bakre överarmen från lodlinjen nedåt, + bort från bollen
    "over": 4.0,                       # handens bana: nedsvingen så här mycket utanför, cm
    "hander_upp": 70.0,                # händerna så här mycket högre vid toppen än i adressen, cm
    "hander_finish": 80.0,             # … och i finishen (bakre armen vågrät på vägen dit, P9)
    # Främre axeln från axelmitten i bild, cm: X mot bollen och Z uppåt; den bakre är
    # spegelbilden. Standarden står still (axlarna skymmer varandra bakifrån); med
    # vridningen vid toppen hamnar axellinjen i bildens plan (METOD M39).
    "axel_dx": (1.5, 1.5, 1.5, 1.5),
    "axel_dz": (0, 0, 0, 0),
}


# --- profilerna -----------------------------------------------------------------

def smoothstep(u: np.ndarray) -> np.ndarray:
    u = np.clip(u, 0.0, 1.0)
    return u * u * (3 - 2 * u)


def profil(t: np.ndarray, platar: list[tuple[float, float, float]]) -> np.ndarray:
    """Värdet står still på varje platå (ta, tb, v) och glider mjukt mellan dem."""
    v = np.full_like(t, platar[0][2], dtype=float)
    for (_, b0, v0), (a1, _, v1) in zip(platar, platar[1:]):
        v = np.where(t > b0, v0 + (v1 - v0) * smoothstep((t - b0) / (a1 - b0)), v)
    return v


def kropp(t: np.ndarray, varden) -> np.ndarray:
    """Kroppens fyra lägen: adress, topp (±0,06 s), träff (±0,04 s), finish."""
    ts, tt, tk = TIDER["start"] + KROPP_SEN, TIDER["topp"], TIDER["klick"]
    a, b, c, d = varden
    return profil(t, [(-INF, ts, a), (tt - 0.06, tt + 0.06, b), (tk - 0.04, tk + 0.04, c), (tk + 0.8, INF, d)])


def _rad(v):
    return np.radians(v)


def _p(x, z) -> np.ndarray:
    """Punkter (…, 2) ur X och Z (tal eller serier)."""
    return np.stack(np.broadcast_arrays(np.asarray(x, float), np.asarray(z, float)), axis=-1)


def _kna(hoft: np.ndarray, fot: np.ndarray, bojning_grader) -> np.ndarray:
    """Knäet mellan höften och fotleden så att benet böjs exakt `bojning` grader,
    framåt (+X). Vinkeln vid knäet är 180 − böjningen."""
    m = (hoft + fot) / 2
    d = fot - hoft
    langd = np.hypot(d[..., 0], d[..., 1])
    n = np.stack([-d[..., 1], d[..., 0]], axis=-1) / langd[..., None]
    n = np.where(n[..., :1] < 0, -n, n)
    return m + n * (langd / 2 * np.tan(_rad(np.asarray(bojning_grader)) / 2))[..., None]


# --- figurerna (cm, X mot målet/bollen, Z uppåt, interna leder f/b) -------------

def figur_fo(t: np.ndarray, p: dict, langd_cm: float) -> np.ndarray:
    n = len(t)
    za = M.FOTLEDSHOJD * langd_cm
    ben, bal = M.BEN * langd_cm, M.BAL * langd_cm
    hals = 0.12 * langd_cm
    ua, fa = 0.186 * langd_cm, 0.146 * langd_cm
    ts, tt, tk = TIDER["start"], TIDER["topp"], TIDER["klick"]

    sway, lyft = kropp(t, p["sway"]), kropp(t, p["lyft"])
    beta, alfa, gamma = _rad(kropp(t, p["sidbojning"])), _rad(kropp(t, p["hoftlutning"])), _rad(kropp(t, p["axellutning"]))
    a, b, c, d = p["armbage"]
    phi = _rad(profil(t, [(-INF, ts + KROPP_SEN, a), (tt - 0.06, tt + 0.06, b), (tk - 0.04, tk + 0.20, c),
                          (tk + 0.8, INF, d)]))
    a, b, c, d = p["arm"]
    psi = _rad(profil(t, [(-INF, ts, a), (tt, tt, b), (tk - 0.04, tk + 0.04, c), (tk + 0.8, INF, d)]))

    L = np.zeros((n, 13, 2))
    P = _p(sway, za + ben + lyft)
    hw, sw = p["hoftbredd"] / 2, p["axelbredd"] / 2
    L[:, 7] = P + hw * np.stack([np.cos(alfa), np.sin(alfa)], -1)
    L[:, 8] = P - hw * np.stack([np.cos(alfa), np.sin(alfa)], -1)
    C = P + bal * np.stack([-np.sin(beta), np.cos(beta)], -1)
    L[:, 1] = C + sw * np.stack([np.cos(gamma), np.sin(gamma)], -1)
    L[:, 2] = C - sw * np.stack([np.cos(gamma), np.sin(gamma)], -1)
    b0 = _rad(p["sidbojning"][0])
    nasa0 = np.array([-(bal + hals) * math.sin(b0), za + ben + (bal + hals) * math.cos(b0)])
    L[:, 0] = nasa0 + _p(kropp(t, p["huvud_sway"]), kropp(t, p["huvud_lyft"]))
    L[:, 11] = [p["stans"] / 2, za]
    L[:, 12] = [-p["stans"] / 2, za]
    # Knäna: mitt mellan höften och fotleden i adressen, i sidled flyttade med sin egen sway.
    a0 = _rad(p["hoftlutning"][0])
    xf = (p["sway"][0] + hw * math.cos(a0) + p["stans"] / 2) / 2 + 2.0
    xb = (p["sway"][0] - hw * math.cos(a0) - p["stans"] / 2) / 2 - 2.0
    L[:, 9] = _p(xf + kropp(t, p["kna_sway_f"]), (L[:, 7, 1] + L[:, 11, 1]) / 2)
    L[:, 10] = _p(xb + kropp(t, p["kna_sway_b"]), (L[:, 8, 1] + L[:, 12, 1]) / 2)
    # Främre armen från axeln: överarmen med vinkeln psi, underarmen böjd phi.
    L[:, 3] = L[:, 1] + ua * np.stack([np.sin(psi), -np.cos(psi)], -1)
    under = np.stack([np.sin(psi - phi), -np.cos(psi - phi)], -1)
    L[:, 5] = L[:, 3] + fa * under
    L[:, 6] = L[:, 5] + 2.0 * under                   # bakre handen under den främre på greppet
    L[:, 4] = (L[:, 2] + L[:, 6]) / 2 - [0.0, 3.0]
    return L


def figur_dtl(t: np.ndarray, p: dict, langd_cm: float) -> np.ndarray:
    n = len(t)
    za = M.FOTLEDSHOJD * langd_cm
    bal = M.BAL * langd_cm
    hals = 0.12 * langd_cm
    ua = 0.186 * langd_cm
    tt, tk = TIDER["topp"], TIDER["klick"]
    px0, pz0 = -14.0, za + 0.47 * langd_cm

    theta = _rad(kropp(t, p["bojning"]))
    eta = _rad(kropp(t, p["armbage_bak"]))
    L = np.zeros((n, 13, 2))
    P = _p(px0 + kropp(t, p["thrust"]), pz0 + kropp(t, p["lyft"]))
    L[:, 7], L[:, 8] = P + [1.5, 0.0], P - [1.5, 0.0]
    C = P + bal * np.stack([np.sin(theta), np.cos(theta)], -1)
    axel = _p(kropp(t, p["axel_dx"]), kropp(t, p["axel_dz"]))
    L[:, 1], L[:, 2] = C + axel, C - axel
    t0 = _rad(p["bojning"][0])
    nasa0 = np.array([px0 + (bal + hals) * math.sin(t0), pz0 + (bal + hals) * math.cos(t0)])
    L[:, 0] = nasa0 + _p(kropp(t, p["huvud_x"]), kropp(t, p["huvud_lyft"]))
    L[:, 11] = [2.0, za]
    L[:, 12] = [-2.0, za]
    L[:, 9] = _kna(L[:, 7], L[:, 11], kropp(t, p["kna_fram"]))
    L[:, 10] = _kna(L[:, 8], L[:, 12], kropp(t, p["kna_bak"]))
    L[:, 4] = L[:, 2] + ua * np.stack([-np.sin(eta), -np.cos(eta)], -1)
    # Händerna: upp och bakåt till toppen, ner `over` cm utanför på samma höjd, upp i finishen.
    u = profil(t, [(-INF, TIDER["start"], 0.0), (tt, tt, 1.0), (tk - 0.04, INF, 0.0)])
    v = profil(t, [(-INF, tk + 0.04, 0.0), (tk + 0.8, INF, 1.0)])
    utanfor = np.where((t > tt) & (t < tk), p["over"] * np.sin(np.pi * u), 0.0)
    G = _p(px0 + 32.0 - 20.0 * u + utanfor + 15.0 * v, pz0 - 12.0 + p["hander_upp"] * u + p["hander_finish"] * v)
    L[:, 5], L[:, 6] = G + [0.5, 1.0], G - [0.5, 1.0]
    L[:, 3] = (L[:, 1] + L[:, 5]) / 2
    return L


def _hander(L: np.ndarray) -> np.ndarray:
    return (L[..., 5, :] + L[..., 6, :]) / 2


def facit_start(figur, p: dict, langd_cm: float) -> float:
    """Starten enligt METOD M4 på den exakta figuren: händerna har rört sig
    5 % av vägen till toppen."""
    g0 = _hander(figur(np.array([0.0]), p, langd_cm))[0]
    gt = _hander(figur(np.array([TIDER["topp"]]), p, langd_cm))[0]
    troskel = 0.05 * float(np.hypot(*(gt - g0)))
    tt = np.arange(TIDER["start"], TIDER["topp"], 1e-5)
    d = np.hypot(*(_hander(figur(tt, p, langd_cm)) - g0).T)
    k = int(np.argmax(d > troskel))
    return float(tt[k - 1] + (troskel - d[k - 1]) / (d[k] - d[k - 1]) * (tt[k] - tt[k - 1]))


def _armens_hojd(L: np.ndarray, axel: int, handled: int) -> np.ndarray:
    """Handledens höjd över axeln på den exakta figuren (Z uppåt), cm. METOD M28"""
    return L[:, handled, 1] - L[:, axel, 1]


def facit_positioner(figur, p: dict, langd_cm: float, t_start: float) -> dict:
    """P3, P5 och P9 på den exakta figuren (METOD M28), på ett rutnät om 10 µs och
    linjärt mellan: sista passagen uppåt före toppen, första nedåt efter, och
    första uppåt för bakre armen efter träffen. None när armen aldrig blir vågrät."""
    tt, tk = TIDER["topp"], TIDER["klick"]

    def passage(a: float, b: float, axel: int, handled: int, uppat: bool, sista: bool):
        t = np.arange(a, b, 1e-5)
        v = _armens_hojd(figur(t, p, langd_cm), axel, handled)
        k = np.where((v[:-1] < 0) & (v[1:] >= 0) if uppat else (v[:-1] >= 0) & (v[1:] < 0))[0]
        if len(k) == 0:
            return None
        i = int(k[-1] if sista else k[0])
        return float(t[i] + (0 - v[i]) / (v[i + 1] - v[i]) * (t[i + 1] - t[i]))

    return {"P3": passage(t_start, tt, 1, 5, True, True),
            "P5": passage(tt, tk, 1, 5, False, False),
            "P9": passage(tk, tk + 1.0, 2, 6, True, False)}


def facit_vid_positioner(p: dict, langd_cm: float, pos: dict) -> dict:
    """Måtten vid P3 och P5 på den exakta figuren (METOD M29), FO."""
    f = {}
    if pos["P3"] is not None:
        L = figur_fo(np.array([0.0, pos["P3"]]), p, langd_cm)
        hx = (L[:, 7, 0] + L[:, 8, 0]) / 2
        f["backen_sway_p3"] = float(hx[1] - hx[0])
        u, v = L[1, 1] - L[1, 3], L[1, 5] - L[1, 3]
        f["framre_armbage_p3"] = 180.0 - math.degrees(math.acos(float(u @ v) / math.hypot(*u) / math.hypot(*v)))
    if pos["P5"] is not None:
        L = figur_fo(np.array([TIDER["topp"], pos["P5"]]), p, langd_cm)
        hx = (L[:, 7, 0] + L[:, 8, 0]) / 2
        f["backen_resa_p5"] = float(hx[1] - hx[0])
    return f


def facit_fo(p: dict, langd_cm: float) -> dict:
    s, ly, sb = p["sway"], p["lyft"], p["sidbojning"]
    bal = M.BAL * langd_cm
    f = {}
    for i, fz in enumerate(("adress", "topp", "traff", "finish")):
        f[f"sidbojning_{fz}"] = float(sb[i])
        if i:
            f[f"backen_sway_{fz}"] = float(s[i])
            f[f"backen_lyft_{fz}"] = float(ly[i])
            f[f"brost_sway_{fz}"] = s[i] - bal * (math.sin(math.radians(sb[i])) - math.sin(math.radians(sb[0])))
            f[f"huvud_sway_{fz}"] = float(p["huvud_sway"][i])
            f[f"huvud_lyft_{fz}"] = float(p["huvud_lyft"][i])
    for i, fz in ((0, "adress"), (2, "traff")):
        f[f"axellinje_lutning_{fz}"] = float(p["axellutning"][i])
    for i, fz in ((0, "adress"), (1, "topp"), (2, "traff")):
        f[f"hoftlinje_lutning_{fz}"] = float(p["hoftlutning"][i])
    f["sway_gap_traff"] = f["backen_sway_traff"] - f["brost_sway_traff"]
    f["backen_resa_framat"] = float(s[2] - s[1])
    f["framre_armbage_topp"] = float(p["armbage"][1])
    f["framre_armbage_efter_traff"] = float(p["armbage"][2])
    f["stans_bredd"] = p["stans"] / p["axelbredd"]
    L0 = figur_fo(np.array([0.0, TIDER["klick"]]), p, langd_cm)
    g = _hander(L0)
    f["hander_fore_adress_traff"] = float(g[1, 0] - g[0, 0])
    f["hander_fore_backen_traff"] = float(g[1, 0] - (L0[1, 7, 0] + L0[1, 8, 0]) / 2)
    L1 = figur_fo(np.array([TIDER["klick"] + 1.1]), p, langd_cm)[0]
    f["huvud_backen_finish"] = float(L1[0, 0] - (L1[7, 0] + L1[8, 0]) / 2)
    return f


def facit_dtl(p: dict, langd_cm: float) -> dict:
    bal = M.BAL * langd_cm
    th = p["bojning"]
    f = {}
    for i, fz in enumerate(("adress", "topp", "traff", "finish")):
        f[f"brost_bojning_{fz}"] = float(th[i])
        if i:
            f[f"backen_thrust_{fz}"] = float(p["thrust"][i])
            f[f"backen_lyft_{fz}"] = float(p["lyft"][i])
            f[f"huvud_mot_bollen_{fz}"] = float(p["huvud_x"][i])
            f[f"huvud_lyft_{fz}"] = float(p["huvud_lyft"][i])
            f[f"brost_thrust_{fz}"] = p["thrust"][i] + bal * (math.sin(math.radians(th[i])) - math.sin(math.radians(th[0])))
    f["brost_bojning_tapp"] = float(th[0] - th[2])
    for i, fz in ((0, "adress"), (1, "topp"), (2, "traff")):
        f[f"bakre_kna_{fz}"] = float(p["kna_bak"][i])
    f["bakre_armbage_topp"] = float(p["armbage_bak"][1])
    f["handbana"] = p["over"] * sum(math.sin(math.pi * a) for a in M.HANDBANA_NIVAER) / len(M.HANDBANA_NIVAER)
    return f


def _lod(nedre: np.ndarray, ovre: np.ndarray) -> float:
    """Linjen nedre → övre mot lodlinjen, + åt +X (Z uppåt). METOD M6"""
    d = ovre - nedre
    return math.degrees(math.atan2(d[0], d[1]))


def _fart(figur, p: dict, langd_cm: float, a: float, b: float, led=None) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """(t, handens fart i cm/s, figuren) på ett rutnät om 10 µs mellan a och b."""
    t = np.arange(a, b, 1e-5)
    L = figur(t, p, langd_cm)
    g = _hander(L)
    v = np.gradient(g, t, axis=0)
    return t, np.hypot(v[:, 0], v[:, 1]), L


def facit_s1b(figur, p: dict, langd_cm: float, vy: str, klick: float | None = None) -> dict:
    """Tilläggen mot Sportsbox (METOD M30–M37) på den exakta figuren: lägena på
    platåerna, farterna på ett rutnät om 10 µs. `klick` = mätningens träff när den
    inte är figurens (handens toppfart nära träffen): bara farterna i nedsvingen
    räknas då mot den."""
    tt, tk = TIDER["topp"], TIDER["klick"]
    tider = {"adress": 0.0, "topp": tt, "traff": tk, "finish": tk + 1.1}
    L = {fz: figur(np.array([tc]), p, langd_cm)[0] for fz, tc in tider.items()}
    f = {}
    for fz in ("topp", "traff", "finish"):
        c, c0 = (L[fz][1] + L[fz][2]) / 2, (L["adress"][1] + L["adress"][2]) / 2
        f[f"brost_lyft_{fz}"] = float(c[1] - c0[1])                                   # METOD M31
        f[f"hand_lyft_{fz}"] = float(_hander(L[fz])[1] - _hander(L["adress"])[1])     # METOD M32
    # Genomsvingen: toppfarten efter träffen och första gången under 10 % av den. METOD M36
    t, s, _ = _fart(figur, p, langd_cm, tk + 1e-5, tk + 1.0)
    j = int(np.argmax(s))
    k = j + int(np.argmax(s[j:] < 0.10 * s[j]))
    f["genomsving_s"] = float(t[k - 1] + (0.10 * s[j] - s[k - 1]) / (s[k] - s[k - 1]) * (t[k] - t[k - 1])) - tk
    if vy == "dtl":
        for fz in ("adress", "topp", "traff"):
            P, C = (L[fz][7] + L[fz][8]) / 2, (L[fz][1] + L[fz][2]) / 2
            f[f"backen_bojning_{fz}"] = (_lod(P, C) + _lod(L[fz][10], L[fz][8])) / 2       # METOD M30
        for i, fz in enumerate(("adress", "topp", "traff")):
            f[f"framre_kna_{fz}"] = float(p["kna_fram"][i])                              # METOD M33
        f.update(facit_s1c(L["adress"], L["topp"]))
    else:
        for i, fz in ((1, "topp"), (2, "traff"), (3, "finish")):                         # METOD M34
            f[f"framre_kna_sway_{fz}"] = float(p["kna_sway_f"][i])
            f[f"bakre_kna_sway_{fz}"] = float(p["kna_sway_b"][i])
        kl = tk if klick is None else klick
        t, s, F = _fart(figur, p, langd_cm, tt, kl)                                       # METOD M35
        j = int(np.argmax(s))
        f["handfart_max"] = float(s[j]) / 100.0                                           # m/s
        f["handfart_max_fore_traff_ms"] = (kl - float(t[j])) * 1000.0
        d = F[:, 5] - F[:, 1]                                                             # METOD M37
        w = np.gradient(np.unwrap(np.arctan2(d[:, 1], d[:, 0])), t)
        f["framre_arm_vinkelfart_max"] = float(np.degrees(np.abs(w).max()))
    return f


def facit_s1c(adress: np.ndarray, topp: np.ndarray) -> dict:
    """Tilläggen bakifrån (METOD M38, M39) på den exakta figuren (X mot bollen, Z uppåt):
    greppets X vid toppen mot adressen, och främre armens höjdvinkel bort från bollen
    minus axellinjens (främre → bakre axel), räknade var för sig mot vågrätt. Den
    vinkeln saknas när axellinjen är kortare än AXLAR_MIN_CM (standardfiguren)."""
    def hojd(v: np.ndarray) -> float:
        return math.degrees(math.atan2(v[1], -v[0]))

    f = {"hand_djup_topp": float(_hander(topp)[0] - _hander(adress)[0])}
    if math.hypot(*(topp[2] - topp[1])) >= M.AXLAR_MIN_CM:          # annars skymmer axlarna varandra
        f["framre_arm_plan_topp"] = hojd(topp[5] - topp[1]) - hojd(topp[2] - topp[1])
    return f


# --- svingen som JSON ------------------------------------------------------------

def sving(vy: str = "fo", hand: str = "hoger", seed: int = 1, brus_px: float = 0.0, langd_m: float = 1.80,
          dolj: tuple = (), saknas: float = SAKNAS, fran: float = 0.0, decimaler: int = 2,
          start: float | None = None, konf: dict | None = None, klick: float | None = None,
          **andra) -> tuple[dict, dict]:
    """(svingen som dict i filformatet, facit). `dolj` = [(led i filen, ta, tb)]
    ger låg konfidens och skräpkoordinater i fönstret. `start` flyttar
    baksvingens start (s), `konf` = {led i filen: konfidens} sätter en leds
    konfidens i alla rutor. `klick` flyttar bara mätningens träff (t_klick), inte
    figurens: handens toppfart hamnar då nära träffen (METOD M35); bara farternas
    facit räknas mot den. `andra` byter parametrar."""
    global TIDER
    if start is not None:
        gamla = TIDER
        TIDER = dict(TIDER, start=start)
        try:
            return sving(vy, hand, seed, brus_px, langd_m, dolj, saknas, fran, decimaler, None, konf, klick, **andra)
        finally:
            TIDER = gamla
    p = dict(FO if vy == "fo" else DTL)
    for k, v in andra.items():
        if k not in p:
            raise KeyError(k)
        p[k] = v
    langd_cm = langd_m * 100
    rng = np.random.default_rng(seed)
    t = np.arange(int(round(fran * FREKVENS)), int(TIDER["slut"] * FREKVENS) + 1) / FREKVENS
    t = t[rng.random(len(t)) >= saknas]
    figur = figur_fo if vy == "fo" else figur_dtl
    L = figur(t, p, langd_cm)
    tecken = 1.0 if hand == "hoger" else -1.0
    x = X0 + tecken * L[..., 0] * K_PX
    y = Y0 - L[..., 1] * K_PX
    if brus_px:
        x = x + rng.normal(0, brus_px, x.shape)
        y = y + rng.normal(0, brus_px, y.shape)
    konfidens = rng.uniform(0.55, 1.0, L.shape[:2])
    karta = FRAN_FIL[hand]
    rutor = []
    for i in range(len(t)):
        leder = []
        for j_fil in range(13):
            j = karta[j_fil]
            led = [round(float(x[i, j]), decimaler), round(float(y[i, j]), decimaler), round(float(konfidens[i, j]), 2)]
            if konf and LEDER_FIL[j_fil] in konf:
                led[2] = konf[LEDER_FIL[j_fil]]
            for namn, ta, tb in dolj:
                if LEDER_FIL[j_fil] == namn and ta <= t[i] <= tb:
                    led = [0.0, 0.0, 0.1]
            leder.append(led)
        rutor.append({"t": round(float(t[i]), 6), "leder": leder})
    d = {"format": 1, "vy": vy, "hand": hand, ("x_mot_malet" if vy == "fo" else "x_mot_bollen"): int(tecken),
         "spelarens_langd_m": langd_m, "t_klick": TIDER["klick"] if klick is None else klick, "rutor": rutor}
    facit = facit_fo(p, langd_cm) if vy == "fo" else facit_dtl(p, langd_cm)
    t_start = facit_start(figur, p, langd_cm)
    facit["tempo"] = (TIDER["topp"] - t_start) / (TIDER["klick"] - TIDER["topp"])
    facit["_start"], facit["_topp"] = t_start, TIDER["topp"]
    pos = facit_positioner(figur, p, langd_cm, t_start)
    facit["_positioner"] = pos
    if vy == "fo":
        facit.update(facit_vid_positioner(p, langd_cm, pos))
    facit.update(facit_s1b(figur, p, langd_cm, vy, klick))
    return d, facit


def till_json(d: dict) -> str:
    """En ruta per rad, så att filen går att läsa och diffa."""
    huvud = {k: v for k, v in d.items() if k != "rutor"}
    rader = [json.dumps(r, separators=(",", ":")) for r in d["rutor"]]
    return json.dumps(huvud, separators=(",", ":"))[:-1] + ',"rutor":[\n' + ",\n".join(rader) + "\n]}"


# --- sessionerna (påhittade mått, utan leder) -------------------------------------

def session(seed: int, n_fo: int, n_dtl: int, utslag: bool = False) -> list[dict]:
    """Ett påhittat pass: måtten per sving direkt, utan leder. Med `utslag` har
    sving 3 (FO) ett avvikande sway-värde, och thrusten stiger genom passet."""
    rng, spelaren = np.random.default_rng(seed), np.random.default_rng(100)   # samma spelare varje pass
    ut = []
    for vy, n in (("fo", n_fo), ("dtl", n_dtl)):
        mu = {k: float(spelaren.uniform(-10, 40)) for k in M.MATT[vy]}
        sd = {k: float(spelaren.uniform(0.5, 3.0)) for k in M.MATT[vy]}
        mu.update(tempo=2.9, backen_sway_topp=-4.0, stans_bredd=1.2)
        sd.update(tempo=0.15, stans_bredd=0.05)
        for i in range(n):
            m = {k: round(float(rng.normal(mu[k], sd[k])), 3) for k in M.MATT[vy]}
            if vy == "dtl" and utslag:
                m["backen_thrust_traff"] = round(0.5 * i + float(rng.normal(0, 0.2)), 3)
            if vy == "fo" and i == 3 and utslag:
                m["backen_sway_topp"] = -25.0
            if i % 2:
                m.pop("handbana", None)          # ett mått som bara finns ibland
            if i > 1:
                m.pop("huvud_lyft_finish", None)  # och ett som för sällan räcker
            ut.append({"vy": vy, "matt": m})
    # Blanda vyerna i passet, som på rangen, men behåll ordningen inom varje vy.
    vyer = [s["vy"] for s in ut]
    rng.shuffle(vyer)
    ko = {vy: [s for s in ut if s["vy"] == vy] for vy in ("fo", "dtl")}
    return [ko[vy].pop(0) for vy in vyer]


# --- Swift-fixturerna ------------------------------------------------------------

FIXTURSVINGAR = {
    # namn: (vy, hand, seed, brus_px, dolj, övrigt till sving())
    "fo": ("fo", "hoger", 11, 0.8, (("hoft_v", 1.60, 1.62),), {}),
    # Vänsterspelaren med den främre handleden dold: greppregeln ger händerna,
    # men armbågsmåtten (M22, M23) saknas.
    "fo_vanster": ("fo", "vanster", 12, 0.8, (("handled_h", 0.0, 9.9),), {}),
    # Axlarna vridna i bildens plan vid toppen (METOD M39); i dtl_kort skymmer de varandra,
    # och främre armen mot axellinjen saknas, och i dtl_lucka ligger axellinjen nära spärren
    # (15,3 cm i figuren), så att Python och Swift prövas vid gränsen.
    "dtl": ("dtl", "hoger", 13, 0.8, (("kna_h", 2.0, 2.02),), {"axel_dx": (1.5, 16, 1.5, 1.5), "axel_dz": (0, -11, 0, 0)}),
    "dtl_lucka": ("dtl", "hoger", 14, 0.8, (("hoft_v", 2.05, 2.35), ("nasa", 3.40, 3.80)),
                  {"axel_dx": (1.5, 6.5, 1.5, 1.5), "axel_dz": (0, -4.0, 0, 0)}),
    # Luckor kring toppen (2,20 s): höften 0,13 s (mer än MAX_LUCKA_S, saknas),
    # näsan 0,05 s (interpoleras). METOD M3
    "fo_luckor": ("fo", "hoger", 15, 0.8, (("hoft_v", 2.135, 2.265), ("nasa", 2.175, 2.225)), {}),
    # Baksvingen 0,25 s: starten och tempot saknas (METOD M4). Konfidensen precis på
    # gränsen 0,3 räknas (främre höften), 0,29 inte (bakre knäet). METOD M1
    "dtl_kort": ("dtl", "hoger", 16, 0.8, (), {"start": 1.95, "konf": {"hoft_v": 0.3, "kna_h": 0.29}}),
    # Främre armen blir aldrig vågrät i baksvingen: P3 och P5 saknas, och måtten
    # vid dem (METOD M28, M29). P9 finns.
    "fo_kort_arm": ("fo", "hoger", 17, 0.8, (), {"arm": (-14, -60, -6, 140)}),
    # Främre handleden borta kring P3 (rå lucka 0,096 s: interpoleras) och kring P5
    # (0,104 s: P5 saknas, och resan vid P5). METOD M3, METOD M28
    "fo_lucka_arm": ("fo", "hoger", 19, 0.8, (("handled_v", 1.7525, 1.8425), ("handled_v", 2.2587, 2.3587)), {}),
    # Vänsterspelaren bakifrån med alla positioner (de speglade armarna), och axlarna
    # vridna i bildens plan vid toppen: främre armen 6° över axellinjen (METOD M39).
    "dtl_vanster": ("dtl", "vanster", 18, 0.8, (), {"axel_dx": (1.5, 16, 1.5, 1.5), "axel_dz": (0, -11, 0, 0)}),
    # Händerna borta 80 ms över toppfarten: ingen toppfart och ingen vinkelfart, men
    # finishens tid (METOD M35–M37).
    "fo_lucka_fart": ("fo", "hoger", 20, 0.8, (("handled_v", 2.29, 2.37), ("handled_h", 2.29, 2.37)), {}),
    # Träffen 15 ms efter handens toppfart (bara mätningens klick flyttas): toppen
    # förfinas nära träffen, inte i rutnätets ände. METOD M35
    "fo_nara_traff": ("fo", "hoger", 21, 0.8, (), {"klick": 2.34}),
}
FRAN_S = 0.50          # fixturerna börjar 0,5 s in i klippet och har en decimal, för att hålla filen liten


def fixtursving(namn: str) -> str:
    vy, hand, seed, brus, dolj, ovrigt = FIXTURSVINGAR[namn]
    return till_json(sving(vy, hand, seed=seed, brus_px=brus, dolj=dolj, fran=FRAN_S, decimaler=1, **ovrigt)[0])


def resultat_json(text: str) -> dict:
    r = M.mat(las(text))
    return {"cm_per_px": r["cm_per_px"], "faser": r["faser"], "positioner": r["positioner"], "matt": r["matt"]}


def session_fixtur() -> dict:
    nu, forra = session(21, 10, 9, utslag=True), session(22, 12, 10)
    katalog = KAT.las()
    sn, sf = S.sammanfatta_session(nu), S.sammanfatta_session(forra)
    return {"nu": nu, "forra": forra, "sammanfattning": {"nu": sn, "forra": sf},
            "jamforelse": {g: S.jamfor(sn[g], sf[g]) for g in sn},
            "bedomning": KAT.bedom(katalog, nu, forra)}


def _raa(text: str) -> str:
    if '"""#' in text:
        raise ValueError("texten kan inte stå i en rå Swift-sträng")
    return '#"""\n' + text + '\n"""#'


def swift_kalla() -> str:
    delar = [
        "// GENERERAD av tools/pc/generera.py --swift. Ändra inte för hand: kör skriptet igen.",
        "//",
        "// PÅHITTADE svingar (CLAUDE.md, Dataregeln): figurer med kända förflyttningar,",
        "// inga riktiga leder och inga riktiga mått. Varje sving står som indata (filformatet,",
        "// docs/FORMAT.md) och Pythons resultat (tools/pc/matt.py), båda som JSON.",
        "",
        "enum Fixturer {",
        "    /// katalog.json, ordagrant.",
        "    static let katalog = " + _raa(KAT.KATALOG.read_text(encoding="utf-8").rstrip("\n")),
        "",
        "    /// (namn, indata, Pythons resultat)",
        "    static let svingar: [(namn: String, indata: String, python: String)] = [",
    ]
    for namn in FIXTURSVINGAR:
        indata = fixtursving(namn)
        delar.append(f'        ("{namn}", ' + _raa(indata) + ", " + _raa(json.dumps(resultat_json(indata))) + "),")
    delar += [
        "    ]",
        "",
        "    /// Två påhittade pass (måtten per sving), och Pythons sammanfattning,",
        "    /// jämförelse och bedömning mot katalogen.",
        "    static let session = " + _raa(json.dumps(session_fixtur(), ensure_ascii=False)),
        "}",
        "",
    ]
    return "\n".join(delar)


RAA = re.compile(r'#"""\n(.*?)\n"""#', re.S)
NAMN = re.compile(r'^        \("(\w+)", #"""$', re.M)


def las_fixturer(text: str) -> dict:
    """Fixturfilens delar tillbaka: katalogen, svingarna och sessionen."""
    raa = RAA.findall(text)
    namn = NAMN.findall(text)
    svingar = {n: (raa[1 + 2 * i], raa[2 + 2 * i]) for i, n in enumerate(namn)}
    return {"katalog": raa[0], "svingar": svingar, "session": raa[-1]}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("vy", nargs="?", choices=("fo", "dtl"))
    ap.add_argument("--hand", default="hoger", choices=("hoger", "vanster"))
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--swift", action="store_true", help=f"skriv {FIXTURFIL.relative_to(ROT)}")
    a = ap.parse_args(argv)
    if a.swift:
        FIXTURFIL.write_text(swift_kalla(), encoding="utf-8")
        print(f"{FIXTURFIL.relative_to(ROT)}: {len(FIXTURSVINGAR)} svingar och två pass")
        return 0
    if not a.vy:
        ap.error("ange vy eller --swift")
    print(till_json(sving(a.vy, a.hand, seed=a.seed)[0]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
