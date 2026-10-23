"""Svingens mått per vy, i Sportsbox-form, portade från Golf SG
(`tools/handled_svingmatt.py`, HANDLED_PLAN HL6).

En kamera ser två av tre axlar, så varje mått tas i den vy där det ligger i
bildens plan. X pekar mot målet (FO) eller mot bollen (DTL), Y nedåt (format.py).

  DTL  bröstets och bäckenets böjning, bäckenets och bröstets thrust (+ mot
       bollen), lyft, huvudet mot bollen, båda knäna, bakre armbågen vid toppen,
       handens bana.
  FO   sidböjningen (+ bort från målet), sway (+ mot målet) för bäckenet, bröstet,
       huvudet och knäna, lyft, axel- och höftlinjens lutning, sway gap, händerna
       vid träffen, bäckenets resa framåt, främre armbågen vid toppen och efter
       träffen, stansen, handens fart och främre armens vinkelfart.
  Båda tempot, bröstets och handens lyft och genomsvingens tid.

Tilläggen mot Sportsbox i 2D (PLAN S1b, research 4): METOD M30–M37. Tilläggen
bakifrån (PLAN S1c): händernas djup och främre armen mot axellinjen vid toppen,
METOD M38–M39.

Positionerna P1–P10 (BESLUT B32, METOD M28) och måtten vid P3, P5 och P10 som
inte är en fas (METOD M29): sway och främre armbågen vid P3, bäckenets resa
från toppen vid P5, huvudet mot bäckenet i finishen.

Vridningen och X-factor ingår inte: de kräver två kameror (PLAN S6) och räknas i
`tva_kameror.py` (S6a).
"""
from __future__ import annotations

import math

import numpy as np

from . import faser as F
from . import farter as FA
from . import positioner as PO
from .format import (ARMBAGE_B, ARMBAGE_F, AXEL_B, AXEL_F, FOTLED_B, FOTLED_F, HANDLED_B, HANDLED_F,
                     HOFT_B, HOFT_F, KNA_B, KNA_F, NASA, Sving)

# METOD M2: Drillis & Contini via Winter, andel av kroppslängden H.
AXELHOJD = 0.818
HOFTHOJD = 0.530
FOTLEDSHOJD = 0.039
BAL = AXELHOJD - HOFTHOJD        # axelmitt–höftmitt, DTL
BEN = HOFTHOJD - FOTLEDSHOJD     # höftmitt–fotledsmitt, FO

CHICKEN = (0.05, 0.15)           # METOD M23: s efter träffen
HANDBANA_NIVAER = (0.25, 0.50, 0.75)   # METOD M13: andel av höjden från adress till topp
AXLAR_MIN_CM = 15.0              # METOD M39: kortare axellinje i bild vid toppen = axlarna skymmer varandra
MATVERSION = 2                   # METOD M40: mätningens version; 2 = starten bakifrån ur posen

FASER = ("adress", "topp", "traff", "finish")
EFTER = ("topp", "traff", "finish")

# Måtten som varje vy kan ge (katalogen pekar bara på dessa).
MATT_DTL = (
    [f"brost_bojning_{f}" for f in FASER] + ["brost_bojning_tapp"]
    + [f"{m}_{f}" for m in ("backen_thrust", "backen_lyft", "huvud_mot_bollen", "huvud_lyft", "brost_thrust")
       for f in EFTER]
    + [f"bakre_kna_{f}" for f in ("adress", "topp", "traff")]
    + ["bakre_armbage_topp", "handbana", "tempo", "baksving_s", "nedsving_s"]
    + [f"{m}_{f}" for m in ("backen_bojning", "framre_kna") for f in ("adress", "topp", "traff")]
    + [f"{m}_{f}" for m in ("brost_lyft", "hand_lyft") for f in EFTER]
    + ["genomsving_s", "hand_djup_topp", "framre_arm_plan_topp"])
MATT_FO = (
    [f"sidbojning_{f}" for f in FASER]
    + [f"{m}_{f}" for m in ("backen_sway", "brost_sway", "backen_lyft", "huvud_sway", "huvud_lyft")
       for f in EFTER]
    + [f"axellinje_lutning_{f}" for f in ("adress", "traff")]
    + [f"hoftlinje_lutning_{f}" for f in ("adress", "topp", "traff")]
    + ["sway_gap_traff", "hander_fore_adress_traff", "hander_fore_backen_traff", "backen_resa_framat",
       "framre_armbage_topp", "framre_armbage_efter_traff", "stans_bredd", "tempo", "baksving_s", "nedsving_s",
       "backen_sway_p3", "framre_armbage_p3", "backen_resa_p5", "huvud_backen_finish"]
    + [f"{m}_{f}" for m in ("brost_lyft", "hand_lyft", "framre_kna_sway", "bakre_kna_sway") for f in EFTER]
    + ["genomsving_s", "handfart_max", "handfart_max_fore_traff_ms", "framre_arm_vinkelfart_max"])
MATT = {"dtl": tuple(MATT_DTL), "fo": tuple(MATT_FO)}


def vinkel_fran_lod(nedre: np.ndarray, ovre: np.ndarray) -> float:
    """Linjen nedre→övre mot lodlinjen i bild, i grader, + när den övre punkten
    ligger åt +X. METOD M6, METOD M14"""
    d = ovre - nedre
    return math.degrees(math.atan2(d[0], -d[1]))


def bojning(a: np.ndarray, mitt: np.ndarray, c: np.ndarray) -> float:
    """Ledens böjning i grader: 0 = rak, 90 = rät vinkel. METOD M11, METOD M22"""
    u, v = a - mitt, c - mitt
    nu, nv = math.hypot(u[0], u[1]), math.hypot(v[0], v[1])
    if not (nu > 0 and nv > 0):
        return math.nan
    cos = (u[0] * v[0] + u[1] * v[1]) / (nu * nv)
    return 180.0 - math.degrees(math.acos(max(-1.0, min(1.0, cos))))


def arm_mot_axlar(axel_f: np.ndarray, axel_b: np.ndarray, hand: np.ndarray) -> float:
    """Vinkeln från axellinjen (främre axel → bakre) till främre armen (främre axel →
    den egna handleden) i bild, grader, + när armen pekar brantare uppåt än axellinjen
    (över axelplanet). Kryss- och skalärprodukten i bildens koordinater (y nedåt).
    METOD M39"""
    s, a = axel_b - axel_f, hand - axel_f
    return math.degrees(math.atan2(s[0] * a[1] - s[1] * a[0], s[0] * a[0] + s[1] * a[1]))


def linjens_lutning(fram: np.ndarray, bak: np.ndarray) -> float:
    """Linjen bakre→främre mot vågrätt, + när den bakre sidan är lägre. METOD M17"""
    d = fram - bak
    return math.degrees(math.atan2(-d[1], d[0]))


def _korsning(t: np.ndarray, G: np.ndarray, a: float, b: float, niva: float, uppat: bool) -> float:
    """Händernas X första gången de passerar höjden `niva` mellan a och b, linjärt
    mellan rutorna. Uppåt i bild = y minskar. METOD M13"""
    ok = np.isfinite(G).all(axis=1) & (t >= a) & (t <= b)
    idx = np.where(ok)[0]
    for i in range(1, len(idx)):
        k0, k1 = idx[i - 1], idx[i]
        y0, y1 = G[k0, 1], G[k1, 1]
        passerar = (y0 > niva >= y1) if uppat else (y0 < niva <= y1)
        if passerar:
            f = (niva - y0) / (y1 - y0)
            return float(G[k0, 0] + f * (G[k1, 0] - G[k0, 0]))
    return math.nan


def mat(s: Sving) -> dict:
    """Måtten för en sving: {"vy", "hand", "cm_per_px", "faser", "positioner", "matt"}.
    Ett mått som inte går att räkna (leden saknas i fasen, positionen saknas)
    står inte med."""
    t = s.t
    b = F.jamna(t, F.grepp_regel(s.xy))
    # Armbågarna mäts mot den egna handleden, inte greppregelns ersatta. METOD M22
    hand_f = F.jamna(t, s.xy[:, HANDLED_F])
    hand_b = F.jamna(t, s.xy[:, HANDLED_B])
    P = (b[:, HOFT_F] + b[:, HOFT_B]) / 2
    C = (b[:, AXEL_F] + b[:, AXEL_B]) / 2
    A = (b[:, FOTLED_F] + b[:, FOTLED_B]) / 2
    G = (b[:, HANDLED_F] + b[:, HANDLED_B]) / 2
    N = b[:, NASA]
    # Bakifrån tas starten ur armarnas och axlarnas pose. METOD M40
    f = F.hitta_faser(t, G, s.t_klick, b if s.vy == "dtl" else None)
    # Positionerna: armarna mot de egna handlederna, som armbågarna. METOD M28
    pos = PO.hitta(t, f, PO.armens_hojd(b[:, AXEL_F], hand_f), PO.armens_hojd(b[:, AXEL_B], hand_b))

    def L(p: np.ndarray, fas: str) -> np.ndarray:
        return F.lage(t, p, f, fas)

    # Skalan: segmentet som ligger i bildens plan i adressen. METOD M2
    if s.vy == "dtl":
        seg, kvot = F.medel(t, C - P, *f.adress), BAL
    else:
        seg, kvot = F.medel(t, A - P, *f.adress), BEN
    px = math.hypot(seg[0], seg[1])
    if not (px > 0):
        raise F.SvingFel("skalan saknas: segmentet syns inte i adressen")
    cm = kvot * s.langd_m * 100.0 / px

    def flytt(p: np.ndarray, axel: int, fas: str, tecken: float = 1.0) -> float:
        """Förflyttningen från adressen i cm; axel 1 vänds så att + är uppåt."""
        return tecken * (L(p, fas)[axel] - L(p, "adress")[axel]) * cm

    m: dict[str, float] = {}
    if s.vy == "dtl":
        for fz in FASER:                                             # METOD M6
            m[f"brost_bojning_{fz}"] = vinkel_fran_lod(L(P, fz), L(C, fz))
        m["brost_bojning_tapp"] = m["brost_bojning_adress"] - m["brost_bojning_traff"]
        for fz in EFTER:
            m[f"backen_thrust_{fz}"] = flytt(P, 0, fz)               # METOD M7
            m[f"backen_lyft_{fz}"] = flytt(P, 1, fz, -1.0)           # METOD M8
            m[f"huvud_mot_bollen_{fz}"] = flytt(N, 0, fz)            # METOD M9
            m[f"huvud_lyft_{fz}"] = flytt(N, 1, fz, -1.0)            # METOD M8
            m[f"brost_thrust_{fz}"] = flytt(C, 0, fz)                # METOD M10
        for fz in ("adress", "topp", "traff"):                       # METOD M11
            m[f"bakre_kna_{fz}"] = bojning(L(b[:, HOFT_B], fz), L(b[:, KNA_B], fz), L(b[:, FOTLED_B], fz))
        # Bakre överarmen mot lodlinjen nedåt, + bort från bollen. METOD M12
        d = L(b[:, ARMBAGE_B], "topp") - L(b[:, AXEL_B], "topp")
        m["bakre_armbage_topp"] = math.degrees(math.atan2(-d[0], d[1]))
        # Handens bana: nedsvingen mot baksvingen på samma höjd. METOD M13
        y_adr, y_topp = L(G, "adress")[1], L(G, "topp")[1]
        b0 = f.start if f.start is not None else f.adress[1]
        skillnad = []
        for andel in HANDBANA_NIVAER:
            niva = y_adr + andel * (y_topp - y_adr)
            xb = _korsning(t, G, b0, f.topp, niva, uppat=True)
            xn = _korsning(t, G, f.topp, f.traff, niva, uppat=False)
            skillnad.append(xn - xb)
        m["handbana"] = sum(skillnad) / len(skillnad) * cm
        # Bäckenets böjning: bålens och lårets lutning, medlet. METOD M30
        for fz in ("adress", "topp", "traff"):
            m[f"backen_bojning_{fz}"] = (vinkel_fran_lod(L(P, fz), L(C, fz))
                                         + vinkel_fran_lod(L(b[:, KNA_B], fz), L(b[:, HOFT_B], fz))) / 2
        for fz in ("adress", "topp", "traff"):                       # METOD M33
            m[f"framre_kna_{fz}"] = bojning(L(b[:, HOFT_F], fz), L(b[:, KNA_F], fz), L(b[:, FOTLED_F], fz))
        # Händernas djup vid toppen: greppet längs X från adressen, + mot bollen. METOD M38
        m["hand_djup_topp"] = flytt(G, 0, "topp")
        # Främre armen mot axellinjen vid toppen, + över axelplanet; bara när axellinjen
        # är lång nog i bild (axlarna skymmer inte varandra). METOD M39
        af, ab = L(b[:, AXEL_F], "topp"), L(b[:, AXEL_B], "topp")
        if math.hypot(ab[0] - af[0], ab[1] - af[1]) * cm >= AXLAR_MIN_CM:
            m["framre_arm_plan_topp"] = arm_mot_axlar(af, ab, L(hand_f, "topp"))
    else:
        for fz in FASER:                                             # METOD M14
            m[f"sidbojning_{fz}"] = -vinkel_fran_lod(L(P, fz), L(C, fz))
        for fz in EFTER:
            m[f"backen_sway_{fz}"] = flytt(P, 0, fz)                 # METOD M15
            m[f"brost_sway_{fz}"] = flytt(C, 0, fz)                  # METOD M16
            m[f"backen_lyft_{fz}"] = flytt(P, 1, fz, -1.0)           # METOD M8
            m[f"huvud_sway_{fz}"] = flytt(N, 0, fz)                  # METOD M9
            m[f"huvud_lyft_{fz}"] = flytt(N, 1, fz, -1.0)            # METOD M8
        for fz in ("adress", "traff"):                               # METOD M17
            m[f"axellinje_lutning_{fz}"] = linjens_lutning(L(b[:, AXEL_F], fz), L(b[:, AXEL_B], fz))
        for fz in ("adress", "topp", "traff"):                       # METOD M18
            m[f"hoftlinje_lutning_{fz}"] = linjens_lutning(L(b[:, HOFT_F], fz), L(b[:, HOFT_B], fz))
        m["sway_gap_traff"] = m["backen_sway_traff"] - m["brost_sway_traff"]             # METOD M19
        m["hander_fore_adress_traff"] = flytt(G, 0, "traff")                              # METOD M20
        m["hander_fore_backen_traff"] = (L(G, "traff")[0] - L(P, "traff")[0]) * cm
        m["backen_resa_framat"] = m["backen_sway_traff"] - m["backen_sway_topp"]         # METOD M21
        m["framre_armbage_topp"] = bojning(L(b[:, AXEL_F], "topp"), L(b[:, ARMBAGE_F], "topp"),
                                           L(hand_f, "topp"))                             # METOD M22
        a0, a1 = s.t_klick + CHICKEN[0], s.t_klick + CHICKEN[1]                          # METOD M23
        m["framre_armbage_efter_traff"] = bojning(F.medel(t, b[:, AXEL_F], a0, a1),
                                                  F.medel(t, b[:, ARMBAGE_F], a0, a1),
                                                  F.medel(t, hand_f, a0, a1))
        fot = L(b[:, FOTLED_F], "adress") - L(b[:, FOTLED_B], "adress")                  # METOD M24
        axl = L(b[:, AXEL_F], "adress") - L(b[:, AXEL_B], "adress")
        axelbredd = math.hypot(axl[0], axl[1])
        m["stans_bredd"] = math.hypot(fot[0], fot[1]) / axelbredd if axelbredd > 0 else math.nan
        # Måtten vid positionerna som inte är en fas. METOD M29
        if pos["P3"] is not None:
            p3 = pos["P3"]
            m["backen_sway_p3"] = (F.vid(t, P, p3)[0] - L(P, "adress")[0]) * cm
            m["framre_armbage_p3"] = bojning(F.vid(t, b[:, AXEL_F], p3), F.vid(t, b[:, ARMBAGE_F], p3),
                                             F.vid(t, hand_f, p3))
        if pos["P5"] is not None:
            m["backen_resa_p5"] = (F.vid(t, P, pos["P5"])[0] - L(P, "topp")[0]) * cm
        m["huvud_backen_finish"] = (L(N, "finish")[0] - L(P, "finish")[0]) * cm
        for fz in EFTER:                                             # METOD M34
            m[f"framre_kna_sway_{fz}"] = flytt(b[:, KNA_F], 0, fz)
            m[f"bakre_kna_sway_{fz}"] = flytt(b[:, KNA_B], 0, fz)
        # Farterna i nedsvingen, från toppen till träffen. METOD M35, METOD M37
        nedsving = FA.rutnat(f.topp, f.traff)
        hf = FA.maxpunkt(nedsving, FA.handens_fart(t, s.xy[:, HANDLED_F], s.xy[:, HANDLED_B], nedsving, True) * cm)
        if hf is not None:
            m["handfart_max"] = hf[0] / 100.0                       # m/s
            m["handfart_max_fore_traff_ms"] = (f.traff - hf[1]) * 1000.0
        af = FA.maxpunkt(nedsving, FA.vinkelfart(t, s.xy[:, AXEL_F], s.xy[:, HANDLED_F], nedsving))
        if af is not None:
            m["framre_arm_vinkelfart_max"] = af[0]

    for fz in EFTER:                                                 # METOD M31, METOD M32
        m[f"brost_lyft_{fz}"] = flytt(C, 1, fz, -1.0)
        m[f"hand_lyft_{fz}"] = flytt(G, 1, fz, -1.0)
    efter = FA.rutnat(f.traff + FA.STEG_S, f.traff + F.FINISH[0])  # METOD M36
    tf = FA.finish_tid(efter, FA.handens_fart(t, s.xy[:, HANDLED_F], s.xy[:, HANDLED_B], efter, False))
    if tf is not None:
        m["genomsving_s"] = tf - f.traff

    if f.start is not None and not f.start_osaker:                   # METOD M5, METOD M40
        bak, ned = f.topp - f.start, f.traff - f.topp
        m["baksving_s"], m["nedsving_s"] = bak, ned
        if ned > 0:
            m["tempo"] = bak / ned

    return {"vy": s.vy, "hand": s.hand, "cm_per_px": cm,
            "faser": {"start": f.start, "topp": f.topp, "traff": f.traff, "start_osaker": f.start_osaker},
            "positioner": pos,
            "matt": {k: float(v) for k, v in m.items() if v is not None and math.isfinite(v)}}
