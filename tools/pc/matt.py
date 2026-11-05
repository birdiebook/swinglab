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
METOD M38–M39. Tilläggen ur research 5 (PLAN S1e): bäckenets recentrering och
skiftets tidpunkt (FO), och bäckenets lägsta punkt i nedsvingen och lyftet därifrån
in i träffen (båda vyerna), METOD M41–M43.

Positionerna P1–P10 (BESLUT B32, METOD M28) och måtten vid P3, P5 och P10 som
inte är en fas (METOD M29): sway och främre armbågen vid P3, bäckenets resa
från toppen vid P5, huvudet mot bäckenet i finishen.

Vridningen och X-factor ingår inte: de kräver två kameror (PLAN S6) och räknas i
`tva_kameror.py` (S6a).
"""
from __future__ import annotations

import dataclasses
import math

import numpy as np

from . import faser as F
from . import farter as FA
from . import positioner as PO
from . import rensa as RE
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
SEGMENT_MIN = 0.70               # METOD M52: kortare segment i bild än så mot adressen = vinkeln i leden mäts inte
SEGMENT_MAX = 1.15               # METOD M52: längre än så mot adressen = en punkt är fel (ett stelt segment kan inte växa)
PLATA_ANDEL = 0.02               # METOD M4: toppens platå = händerna inom 2 % av vägen adress → topp från toppen
PLATA_SOK_S = 0.30               # METOD M4: platån söks högst så långt från toppen åt vardera hållet
AXLAR_MIN_CM = 15.0              # METOD M39: kortare axellinje i bild vid toppen = axlarna skymmer varandra
MATVERSION = 7                   # METOD M40, MS14: mätningens version; 2 = starten bakifrån ur posen, 3 = M41–M43 och spridningen, 4 = synliga segment (M52), 5 = stilla adress (M4), 6 = rensningen (M53) och för långa segment (M52), 7 = varningarna (M54)

# Varningarna: mått som visas men är osäkra (METOD M54). Gränserna är antaganden.
PLATA_BRED_S = 0.08              # METOD M55: bredare platå än så = toppen prövas mot en andra signal
TOPP_OENIG_S = 0.05              # METOD M55: signalerna mer än så isär = toppen osäker
LUCKA_FONSTER_S = 0.05           # METOD M56: rutorna så nära måttets ögonblick räknas
LUCKA_ANDEL = 0.20               # METOD M56: större andel saknade av måttets egna leder där = varning
SYNK_ANDEL = 0.10                # METOD M57: händerna i klicket högre än så över sin lägsta punkt = träffen osäker
NEDSVING_RIMLIG = (0.20, 0.45)   # METOD M59: en nedsving utanför (s) = toppen eller träffen fel
TEMPO_RIMLIGT = (2.0, 4.5)       # METOD M59: ett tempo utanför = toppen, starten eller träffen fel

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
    + ["genomsving_s", "hand_djup_topp", "framre_arm_plan_topp"]
    + ["backen_lyft_min", "backen_lyft_in_traff"])
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
    + ["genomsving_s", "handfart_max", "handfart_max_fore_traff_ms", "framre_arm_vinkelfart_max"]
    + ["backen_recentrering", "backen_skifte_ms", "backen_lyft_min", "backen_lyft_in_traff"])
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


def segment_orsak(a: np.ndarray, mitt: np.ndarray, c: np.ndarray,
                  a0: np.ndarray, mitt0: np.ndarray, c0: np.ndarray) -> str | None:
    """Varför ledens vinkel inte kan mätas, eller None: "led_saknas" (en punkt saknas i
    fasen eller i adressen), "segment_kort" (ett segment syns kortare i bild än
    SEGMENT_MIN av sin längd i adressen: det pekar mot eller från kameran och felet i en
    punkt förstärks) eller "segment_langt" (längre än SEGMENT_MAX: ett stelt segment kan
    inte växa i bild, så en punkt är fel). Det korta före det långa. METOD M52"""
    kvoter = []
    for p, q, p0, q0 in ((a, mitt, a0, mitt0), (c, mitt, c0, mitt0)):
        l0 = math.hypot(p0[0] - q0[0], p0[1] - q0[1])
        l1 = math.hypot(p[0] - q[0], p[1] - q[1])
        if not (math.isfinite(l0) and math.isfinite(l1) and l0 > 0):
            return "led_saknas"
        kvoter.append(l1 / l0)
    if any(not (k >= SEGMENT_MIN) for k in kvoter):
        return "segment_kort"
    if any(k > SEGMENT_MAX for k in kvoter):
        return "segment_langt"
    return None


def bojning_synlig(a: np.ndarray, mitt: np.ndarray, c: np.ndarray,
                   a0: np.ndarray, mitt0: np.ndarray, c0: np.ndarray) -> float:
    """Ledens böjning (som `bojning`), men NaN när segment_orsak ger en orsak: ett
    segment syns för kort (pekar mot eller från kameran) eller för långt (en punkt är fel)
    mot adressen. En rak led syns rak i bild hur den än är vriden, men felet i punkterna
    förstärks. METOD M52"""
    if segment_orsak(a, mitt, c, a0, mitt0, c0) is not None:
        return math.nan
    return bojning(a, mitt, c)


def topp_plata(t: np.ndarray, G: np.ndarray, f: F.Faser) -> float | None:
    """Toppens platå i s: hur länge händerna står inom PLATA_ANDEL av vägen adress → topp
    från sin högsta punkt, räknat från rutan närmast toppen och utåt åt båda hållen (högst
    PLATA_SOK_S, och inte över en lucka längre än MAX_LUCKA_S). Med driver kan händerna stå
    nästan still medan klubban fortsätter, och toppen hamna tidigt på platån. Mäts och
    visas; ingen spärr än (METOD M4, öppen fråga). None när vägen inte går att räkna."""
    y_topp = F.vid(t, G, f.topp)[1]
    y_adr = F.lage(t, G, f, "adress")[1]
    vag = y_adr - y_topp
    if not (math.isfinite(vag) and vag > 0):
        return None
    ok = np.where(np.isfinite(G).all(axis=1) & (np.abs(t - f.topp) <= PLATA_SOK_S))[0]
    if len(ok) == 0:
        return None
    k0 = int(np.argmin(np.abs(t[ok] - f.topp)))
    grans = PLATA_ANDEL * vag
    if not (G[ok[k0], 1] - y_topp <= grans):
        return 0.0
    lo = hi = k0
    while lo > 0 and t[ok[lo]] - t[ok[lo - 1]] <= F.MAX_LUCKA_S and G[ok[lo - 1], 1] - y_topp <= grans:
        lo -= 1
    while hi < len(ok) - 1 and t[ok[hi + 1]] - t[ok[hi]] <= F.MAX_LUCKA_S and G[ok[hi + 1], 1] - y_topp <= grans:
        hi += 1
    return float(t[ok[hi]] - t[ok[lo]])


# Måtten som beror på toppens tid (METOD M55, M59) och på träffens (METOD M57), utöver de som
# slutar på _traff (lägen i klicket) och fönster från toppen till klicket.
TOPPENS = ("tempo", "baksving_s", "nedsving_s")
TRAFFENS = ("brost_bojning_tapp", "backen_resa_framat", "tempo", "nedsving_s", "genomsving_s", "handfart_max",
            "handfart_max_fore_traff_ms", "framre_arm_vinkelfart_max", "backen_lyft_min", "backen_skifte_ms")
FARTERNAS = ("handfart_max", "handfart_max_fore_traff_ms")                           # METOD M58
GREPP = -1   # METOD M56: händerna efter greppregeln (M1), saknade bara när båda handlederna saknas
# Kontrollernas tal i `kvalitet`, när de går att räkna (METOD M54): följer med i analysen för kalibreringen.
KONTROLLER = ("topp_plata_s", "topp_andra_s", "traff_hojd", "handfart_kvot")
AXLAR, HOFTER = (AXEL_F, AXEL_B), (HOFT_F, HOFT_B)


def traffens_matt(namn: str) -> bool:
    """Måttet beror på träffens tid: ett läge i klicket, eller en tid, fart eller ett fönster
    som slutar där. METOD M57"""
    return namn.endswith("_traff") or namn in TRAFFENS


def luckornas_leder(namn: str) -> tuple[tuple[int, ...], tuple[str, ...]]:
    """Måttets egna leder och ögonblicken det läses i, för luckorna kring fasen: ("start",
    "topp", "traff", "P3", "P5", "handfart", "vinkelfart"). Mått som är medel över ett fönster
    (adressen, finishen, efter träffen) eller sökningar över svingen (handens bana, skiftet,
    genomsvingen) har inga ögonblick. GREPP = händerna efter greppregeln. METOD M56"""
    if namn in ("tempo", "baksving_s"):
        tider: tuple[str, ...] = ("start", "topp")
    elif namn == "nedsving_s" or namn == "backen_recentrering":
        tider = ("topp",)
    elif namn.startswith("handfart_max"):
        tider = ("handfart",)
    elif namn == "framre_arm_vinkelfart_max":
        tider = ("vinkelfart",)
    elif namn == "backen_resa_framat":
        tider = ("topp", "traff")
    elif namn == "backen_resa_p5":
        tider = ("topp", "P5")
    elif namn == "brost_bojning_tapp":
        tider = ("traff",)
    elif namn == "framre_armbage_efter_traff":
        tider = ()
    elif namn.endswith("_topp"):
        tider = ("topp",)
    elif namn.endswith("_traff"):
        tider = ("traff",)
    elif namn.endswith("_p3"):
        tider = ("P3",)
    else:
        tider = ()
    if namn in TOPPENS:
        leder: tuple[int, ...] = (GREPP,)
    elif namn.startswith("handfart"):
        leder = (HANDLED_F, HANDLED_B)
    elif namn.startswith("framre_arm_vinkelfart"):
        leder = (AXEL_F, HANDLED_F)
    elif namn.startswith("framre_arm_plan"):
        leder = (AXEL_F, AXEL_B, HANDLED_F)
    elif namn.startswith("framre_armbage"):
        leder = (AXEL_F, ARMBAGE_F, HANDLED_F)
    elif namn.startswith("bakre_armbage"):
        leder = (AXEL_B, ARMBAGE_B)
    elif namn.startswith("framre_kna_sway"):
        leder = (KNA_F,)
    elif namn.startswith("bakre_kna_sway"):
        leder = (KNA_B,)
    elif namn.startswith("framre_kna"):
        leder = (HOFT_F, KNA_F, FOTLED_F)
    elif namn.startswith("bakre_kna"):
        leder = (HOFT_B, KNA_B, FOTLED_B)
    elif namn.startswith("backen_bojning"):
        leder = AXLAR + HOFTER + (KNA_B,)
    elif namn.startswith(("brost_bojning", "sidbojning", "sway_gap")):
        leder = AXLAR + HOFTER
    elif namn.startswith(("brost", "axellinje")):
        leder = AXLAR
    elif namn.startswith(("backen", "hoftlinje")):
        leder = HOFTER
    elif namn.startswith("huvud"):
        leder = (NASA,)
    elif namn.startswith("hander_fore_backen"):
        leder = (GREPP,) + HOFTER
    elif namn.startswith(("hand_", "hander_")):
        leder = (GREPP,)
    else:
        leder = ()
    return (leder, tider) if leder and tider else ((), ())


def saknad_andel(t: np.ndarray, xy: np.ndarray, led: int, tc: float) -> float:
    """Andelen av rutorna inom LUCKA_FONSTER_S från tc där leden saknas (låg konfidens eller
    borttagen av rensningen, M1, M53); GREPP saknas bara där båda handlederna saknas (M1). Rutor
    som telefonen inte gav alls räknas inte: där gäller M3:s lucka. 1 utan rutor. METOD M56"""
    sel = np.abs(t - tc) <= LUCKA_FONSTER_S
    n = int(sel.sum())
    if n == 0:
        return 1.0
    if led == GREPP:
        ute = ~np.isfinite(xy[sel, HANDLED_F]).all(axis=1) & ~np.isfinite(xy[sel, HANDLED_B]).all(axis=1)
    else:
        ute = ~np.isfinite(xy[sel, led]).all(axis=1)
    return int(ute.sum()) / n


def varningar(matt: dict[str, float], kontroller: dict, plata: float | None, t: np.ndarray, xy: np.ndarray,
              f: F.Faser, pos: dict, tider: dict[str, float]) -> dict[str, list[str]]:
    """Mått som visas men är osäkra → orsakerna, sorterade (METOD M54). Bara mått som finns:
    ett mått som saknas har sin orsak i `saknas`.

    - "topp_osaker": platån bredare än PLATA_BRED_S och den andra signalen mer än TOPP_OENIG_S
      från toppen (M55), på tempot, baksvingen och nedsvingen;
    - "luckor_kring_fasen": mer än LUCKA_ANDEL saknade av måttets egna leder kring dess
      ögonblick (M56);
    - "traff_osaker": händerna i klicket mer än SYNK_ANDEL av vägen över sin lägsta punkt
      (M57), på måtten som beror på träffen;
    - "filterkanslig": handens toppfart under FILTER_KVOT av den smalare utjämningens (M58);
    - "fas_orimlig": nedsvingen eller tempot utanför det rimliga (M59)."""
    ut: dict[str, set[str]] = {}

    def varna(namn: str, orsak: str) -> None:
        if namn in matt:
            ut.setdefault(namn, set()).add(orsak)

    d2 = kontroller.get("topp_andra_s")
    if plata is not None and plata > PLATA_BRED_S and d2 is not None and abs(d2) > TOPP_OENIG_S:   # METOD M55
        for namn in TOPPENS:
            varna(namn, "topp_osaker")
    ogonblick = {"start": f.start, "topp": f.topp, "traff": f.traff, "P3": pos.get("P3"), "P5": pos.get("P5"),
                 **tider}
    for namn in matt:                                                                              # METOD M56
        leder, nar = luckornas_leder(namn)
        if any(ogonblick.get(x) is not None and saknad_andel(t, xy, j, ogonblick[x]) > LUCKA_ANDEL
               for x in nar for j in leder):
            varna(namn, "luckor_kring_fasen")
    h = kontroller.get("traff_hojd")
    if h is not None and h > SYNK_ANDEL:                                                           # METOD M57
        for namn in matt:
            if traffens_matt(namn):
                varna(namn, "traff_osaker")
    k = kontroller.get("handfart_kvot")
    if k is not None and k < FA.FILTER_KVOT:                                                       # METOD M58
        for namn in FARTERNAS:
            varna(namn, "filterkanslig")
    ned, tempo = matt.get("nedsving_s"), matt.get("tempo")                                         # METOD M59
    if ((ned is not None and not NEDSVING_RIMLIG[0] <= ned <= NEDSVING_RIMLIG[1])
            or (tempo is not None and not TEMPO_RIMLIGT[0] <= tempo <= TEMPO_RIMLIGT[1])):
        for namn in TOPPENS:
            varna(namn, "fas_orimlig")
    return {k: sorted(v) for k, v in sorted(ut.items())}


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


def fonster(t: np.ndarray, p: np.ndarray, axel: int, noll: float, skala: float, a: float,
            b: float) -> tuple[np.ndarray, np.ndarray] | None:
    """Punktens koordinat längs `axel` minus `noll`, gånger `skala`, i fönstret a…b:
    värdet i ögonblicket vid a och vid b (M3) och rutorna strikt mellan dem som har
    värde, i tidsordning, som (tider, värden). None när en ände saknas eller när två
    tider i följd ligger mer än MAX_LUCKA_S isär: då kan ytterläget ligga i luckan.
    METOD M41, METOD M42, METOD M43"""
    pa, pb = F.vid(t, p, a), F.vid(t, p, b)
    if not (np.isfinite(pa).all() and np.isfinite(pb).all()):
        return None
    sel = np.isfinite(p).all(axis=1) & (t > a) & (t < b)
    tt = np.concatenate([[a], t[sel], [b]])
    if np.any(np.diff(tt) > F.MAX_LUCKA_S):
        return None
    v = np.concatenate([[pa[axel]], p[sel, axel], [pb[axel]]])
    return tt, (v - noll) * skala


def forsta_framat(tt: np.ndarray, v: np.ndarray) -> float | None:
    """Första tiden då v når 0 underifrån, linjärt mellan två värden i följd; tt[0] när
    v redan är ≥ 0 där, None när v aldrig når 0. METOD M42"""
    if v[0] >= 0:
        return float(tt[0])
    for i in range(1, len(v)):
        if v[i] >= 0:
            return float(tt[i - 1] + (0.0 - v[i - 1]) / (v[i] - v[i - 1]) * (tt[i] - tt[i - 1]))
    return None


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
    står inte med. "kvalitet" säger vad rensningen gjorde (METOD M53), toppens platå
    (METOD M4) och varför vissa mått saknas (METOD M52, M5)."""
    t = s.t
    # Byten och spikar bort först, sedan räknas allt på de rensade lederna. METOD M53
    xy, rensning = RE.rensa(t, s.xy)
    s = dataclasses.replace(s, xy=xy)
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
    saknas: dict[str, str] = {}
    tider: dict[str, float] = {}                 # farternas toppar, för luckorna kring dem (METOD M56)
    kontroller: dict[str, float | None] = {}     # kontrollernas tal, för kalibreringen (METOD M54)

    def synlig(namn: str, a, mitt, c, a0, mitt0, c0) -> None:
        """Vinkeln i leden som måttet `namn`, eller orsaken till att den saknas. METOD M52"""
        orsak = segment_orsak(a, mitt, c, a0, mitt0, c0)
        if orsak is None:
            m[namn] = bojning(a, mitt, c)
        else:
            saknas[namn] = orsak

    def led(namn: str, a: np.ndarray, mitt: np.ndarray, c: np.ndarray, fas: str) -> None:
        """Böjningen i fasen, bara när båda segmenten syns rimligt i bild. METOD M52"""
        synlig(namn, L(a, fas), L(mitt, fas), L(c, fas), L(a, "adress"), L(mitt, "adress"), L(c, "adress"))

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
            led(f"bakre_kna_{fz}", b[:, HOFT_B], b[:, KNA_B], b[:, FOTLED_B], fz)      # METOD M52
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
            led(f"framre_kna_{fz}", b[:, HOFT_F], b[:, KNA_F], b[:, FOTLED_F], fz)     # METOD M52
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
        led("framre_armbage_topp", b[:, AXEL_F], b[:, ARMBAGE_F], hand_f, "topp")          # METOD M22, METOD M52
        a0, a1 = s.t_klick + CHICKEN[0], s.t_klick + CHICKEN[1]                          # METOD M23
        synlig("framre_armbage_efter_traff", F.medel(t, b[:, AXEL_F], a0, a1), F.medel(t, b[:, ARMBAGE_F], a0, a1),
               F.medel(t, hand_f, a0, a1), L(b[:, AXEL_F], "adress"), L(b[:, ARMBAGE_F], "adress"),
               L(hand_f, "adress"))
        fot = L(b[:, FOTLED_F], "adress") - L(b[:, FOTLED_B], "adress")                  # METOD M24
        axl = L(b[:, AXEL_F], "adress") - L(b[:, AXEL_B], "adress")
        axelbredd = math.hypot(axl[0], axl[1])
        m["stans_bredd"] = math.hypot(fot[0], fot[1]) / axelbredd if axelbredd > 0 else math.nan
        # Måtten vid positionerna som inte är en fas. METOD M29
        if pos["P3"] is not None:
            p3 = pos["P3"]
            m["backen_sway_p3"] = (F.vid(t, P, p3)[0] - L(P, "adress")[0]) * cm
            synlig("framre_armbage_p3", F.vid(t, b[:, AXEL_F], p3), F.vid(t, b[:, ARMBAGE_F], p3),
                   F.vid(t, hand_f, p3), L(b[:, AXEL_F], "adress"), L(b[:, ARMBAGE_F], "adress"),
                   L(hand_f, "adress"))
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
            tider["handfart"] = hf[1]
            # Samma topp med en smalare utjämning: känslig för utjämningen? METOD M58
            kontroller["handfart_kvot"] = FA.kvot_mot_smal(nedsving, hf, lambda tau: FA.handens_fart(
                t, s.xy[:, HANDLED_F], s.xy[:, HANDLED_B], tau, True, FA.SMAL_SIGMA_S) * cm)
        af = FA.maxpunkt(nedsving, FA.vinkelfart(t, s.xy[:, AXEL_F], s.xy[:, HANDLED_F], nedsving))
        if af is not None:
            m["framre_arm_vinkelfart_max"] = af[0]
            tider["vinkelfart"] = af[1]

    for fz in EFTER:                                                 # METOD M31, METOD M32
        m[f"brost_lyft_{fz}"] = flytt(C, 1, fz, -1.0)
        m[f"hand_lyft_{fz}"] = flytt(G, 1, fz, -1.0)
    # Bäckenets lägsta punkt mellan toppen och träffen, från adressen, och lyftet därifrån
    # in i träffen. METOD M43
    ned = fonster(t, P, 1, L(P, "adress")[1], -cm, f.topp, f.traff)
    if ned is not None:
        m["backen_lyft_min"] = float(ned[1].min())
        m["backen_lyft_in_traff"] = float(ned[1][-1] - ned[1].min())
    if s.vy == "fo":
        x0 = L(P, "adress")[0]
        # Recentreringen: bäckenets sway vid toppen minus dess minsta i baksvingen. METOD M41
        bak = fonster(t, P, 0, x0, cm, f.adress[1], f.topp)
        if bak is not None:
            m["backen_recentrering"] = float(bak[1][-1] - bak[1].min())
        # Skiftet: tiden från toppen tills höftmitten är tillbaka i adressläget. METOD M42
        fram = fonster(t, P, 0, x0, cm, f.topp, f.traff)
        if fram is not None:
            tc = forsta_framat(*fram)
            if tc is not None:
                m["backen_skifte_ms"] = (tc - f.topp) * 1000.0

    efter = FA.rutnat(f.traff + FA.STEG_S, f.traff + F.FINISH[0])  # METOD M36
    tf = FA.finish_tid(efter, FA.handens_fart(t, s.xy[:, HANDLED_F], s.xy[:, HANDLED_B], efter, False))
    if tf is not None:
        m["genomsving_s"] = tf - f.traff

    m["nedsving_s"] = f.traff - f.topp                               # METOD M5: utan starten
    if f.start is not None and not f.start_osaker:                   # METOD M5, METOD M40
        bak, ned = f.topp - f.start, f.traff - f.topp
        m["baksving_s"] = bak
        if ned > 0:
            m["tempo"] = bak / ned
    else:                                                            # METOD M5: varför tempot saknas
        orsak = "start_saknas" if f.start is None else "start_osaker"
        saknas["tempo"] = saknas["baksving_s"] = orsak

    matt = {k: float(v) for k, v in m.items() if v is not None and math.isfinite(v)}
    plata = topp_plata(t, G, f)
    t2 = F.andra_toppen(t, G, b[:, AXEL_F], hand_f, f, s.vy)                      # METOD M55
    kontroller["topp_andra_s"] = None if t2 is None else t2 - f.topp
    kontroller["traff_hojd"] = F.traffens_hojd(t, G, f)                          # METOD M57
    kvalitet = {"rensning": rensning, "topp_plata_s": plata,
                "saknas": {k: v for k, v in sorted(saknas.items()) if k not in matt},
                "varningar": varningar(matt, kontroller, plata, t, s.xy, f, pos, tider),
                **{k: v for k, v in kontroller.items() if v is not None}}
    return {"vy": s.vy, "hand": s.hand, "cm_per_px": cm,
            "faser": {"start": f.start, "topp": f.topp, "traff": f.traff, "start_osaker": f.start_osaker},
            "positioner": pos, "matt": matt, "kvalitet": kvalitet}
