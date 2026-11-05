"""S6e steg 0: bäckenets och axlarnas vridning och X-factor ur EN telefon, mätt mot 3D-sanningen.

Frågan (PLAN S6e): räcker en telefon, framifrån (FO) eller bakifrån (DTL), för att visa
vridningen? Svaret kommer ur en simulering på påhittade svingar, som felbudgeten för två
telefoner (docs/S6_FELBUDGET.md), och står i docs/S6E_EN_TELEFON.md, METOD M70–M74 och
BESLUT B103–B104.

    python3 tools/pc/vridning_2d.py                     # alla tabeller (cirka 15 min)
    python3 tools/pc/vridning_2d.py --n 40 --bara bas   # en tabell, färre försök

Försöket (METOD M70):

1. En påhittad 3D-sving (`tre_d/sving.py`) med slumpad längd, tempo och vinklar, och med
   höft- och axelpunkternas avstånd slumpade kring felbudgetens andelar (antagande).
2. En FO- och en DTL-kamera ur felbudgetens modell (`tre_d/kamera.py`): placeringen ±5°,
   bildtider med 36 % tappade rutor, 2D-brus med fast avvikelse, skymning, och klickets fel.
3. 2D-kedjan som den är: `matt.mat` (rensningen M53, utjämningen M3, faserna M4 och M40)
   ger toppen och baksvingens start, alltså adressens fönster. Spåren rättas mot lodlinjen
   och jämnas som i 3D-kedjan (MK5, LOESS ±40 ms).
4. Skattarna (M71–M73) ger vinkelkurvorna, som jämnas ±30 ms (MK6), och måtten tas med
   `tre_d/matt.py` vid 2D-toppen och klicket.
5. Sanningen är samma mått på de sanna 3D-lederna (MK6): toppen där händerna står högst i
   3D, träffen på svingens träff och adressen ur den sanna starten.

Bara numpy och påhittade svingar (CLAUDE.md, Dataregeln). Bara geometri: ingen tränad
modell (B92, research 2026-11-05 `3d_en_kamera.md`).
"""
from __future__ import annotations

import argparse
import math
import sys
import time
import warnings
from dataclasses import dataclass, fields, replace
from pathlib import Path

import numpy as np

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "pc"

from . import faser as F  # noqa: E402
from . import format as FM  # noqa: E402
from . import matt as M  # noqa: E402
from .generera_paket import EFTER_3D, T_START_3D  # noqa: E402
from .tre_d import felbudget as FB  # noqa: E402
from .tre_d import kalibrering as KAL  # noqa: E402
from .tre_d import kamera as KM  # noqa: E402
from .tre_d import matt as M3  # noqa: E402
from .tre_d import triangulering as TRI  # noqa: E402
from .tre_d.sving import I, Sving, rot_x, rot_y, rot_z, slumpa_sving  # noqa: E402
from .tva_kameror import HALVBREDD_2D, HALVBREDD_VINKEL, KANT_S, MIN_KONF, RUTNAT_S  # noqa: E402

warnings.filterwarnings("ignore", category=RuntimeWarning)  # tomma medel blir NaN och räknas som bortfall

# Linjerna: främre led minus bakre (för en högerspelare vänster minus höger, format.py M1).
HOFTER = (I["v_hoft"], I["h_hoft"])
AXLAR = (I["v_axel"], I["h_axel"])

HOFT_ANDEL = 0.11       # METOD M73: höftpunkterna isär, andel av längden (S6_FELBUDGET §2, antagande)
AXEL_ANDEL = 0.20       # METOD M73: axelpunkterna isär, andel av längden (S6_FELBUDGET §2, antagande)
BREDD_CV = 0.08         # METOD M70: spelarens avstånd mellan punkterna varierar så mycket (1σ, relativt; antagande)
KLICK_MS = 7.0          # METOD M70: klickets fel, likformigt ± (MS4)
KORS_EFTER_S = 0.10     # METOD M71: linjens passage genom adressens läge i nedsvingen söks till träffen + 0,10 s
FINISH_S = F.FINISH[1]  # METOD M73: bredden ur linjen söks från toppen till träffen + 1,2 s (M4:s finish)
BREDD_JAMNING_S = 0.10  # METOD M73: linjens längd jämnas ±0,10 s innan den största tas (brusets max drar uppåt)
BACKEN_AV_BAL = 22.0 / 38.0  # METOD M72: bäckenets framåtböjning som andel av bålens (felbudgetens sving §2, antagande)
VINKEL_BINS = (0.0, 15.0, 30.0, 60.0, 80.0, 100.0, 180.0)  # METOD M70: kurvans fel efter den sanna vinkeln
VARIANTER = ("lodrat", "lutande")  # METOD M70: vridningen kring lodlinjen (sving.py) eller kring den böjda axeln

SKATTARE = ("fo_a", "fo_stel", "fo_b", "fo_b_dtl", "fo_stel_b", "dtl_c", "dtl_c_fo", "dtl_c_max")
VY = {k: k.split("_")[0] for k in SKATTARE}
MATT = ("backen_topp", "brost_topp", "xfaktor_topp", "hofter_oppna_traff", "brost_traff", "stretch")
KURVOR = ("backen", "brost", "xfaktor")


# --------------------------------------------------------------------------------------------
# Uppställningen och försöket (METOD M70)


@dataclass(frozen=True)
class EnKamera:
    """Ett pass med en telefon i varje vy (varje vy skattas för sig)."""

    avstand: float = 3.0
    hojd: float = 1.0
    azimut_fel_deg: float = 5.0   # stativets läge runt spelaren (1σ), som felbudgeten
    f_px: float = KM.F_PX
    brus: str = "typiskt"
    skymning: bool = True
    tapp: float = KM.TAPP
    exponering: float = 1 / 1000
    klick_ms: float = KLICK_MS
    grav_deg: float = 1.0         # lodlinjens fel (1σ per axel), MK3
    lodlinje: bool = True         # spåren rättas mot lodlinjen (telefonens gravity, MS17)
    bredd_cv: float = BREDD_CV
    variant: str = "lodrat"       # svingens modell, VARIANTER

    def fb(self) -> FB.Uppstallning:
        """Felbudgetens uppställning med samma kameror och brus."""
        return replace(FB.Uppstallning(), avstand=self.avstand, hojd=self.hojd, azimut_fel_deg=self.azimut_fel_deg,
                       f_px=self.f_px, brus=self.brus, skymning=self.skymning, tapp=self.tapp,
                       exponering=self.exponering, kalib="perfekt")


REN = EnKamera(brus="inget", azimut_fel_deg=0.0, tapp=0.0, skymning=False, exponering=0.0, klick_ms=0.0,
               grav_deg=0.0, bredd_cv=0.0)


def _xzy(vrid_deg, bojning_deg, sidbojning_deg) -> np.ndarray:
    """R = Rx(framåtböjning) · Rz(−vridning) · Ry(sidböjning): vridningen sker kring segmentets
    egen framåtböjda axel, inte kring lodlinjen som i sving.segment_rotation (ZXY)."""
    v = np.radians(np.asarray(vrid_deg, float))
    b = np.radians(np.asarray(bojning_deg, float))
    s = np.radians(np.asarray(sidbojning_deg, float))
    return rot_x(b) @ rot_z(-v) @ rot_y(s)


@dataclass
class LutandeSving(Sving):
    """Svingvarianten "lutande": bäckenet och bålen vrids kring sin framåtböjda axel, och
    adressens sidböjning står kvar hela svingen. Linjerna sänker då den främre sidan i
    baksvingen av vridningen själv, inte av en sidböjning (som i grundsvingen). METOD M70"""

    def segment(self, t):
        k = self.kurvor(t)
        return (_xzy(k["backen_vrid"], k["backen_boj"], k["backen_sid"]),
                _xzy(k["bal_vrid"], k["bal_boj"], k["bal_sid"]), k)


def ny_sving(u: EnKamera, rng: np.random.Generator) -> Sving:
    """En slumpad sving (slumpa_sving) i uppställningens variant, med adress och finish som
    rymmer M4:s fönster (MK8) och slumpade avstånd mellan höft- och axelpunkterna. Samma frö
    ger samma sving i båda varianterna. METOD M70"""
    s = slumpa_sving(rng)
    if u.variant == "lutande":
        s = LutandeSving(**{f.name: getattr(s, f.name) for f in fields(Sving)})
        for nyckel in ("backen_sid", "bal_sid"):
            s.nyckel[nyckel] = [s.nyckel[nyckel][0]] * len(s.nyckel[nyckel])
    elif u.variant != "lodrat":
        raise ValueError(u.variant)
    s.t_start, s.efter = T_START_3D, EFTER_3D
    s.__post_init__()
    s.hoft_bredd = HOFT_ANDEL * s.langd * (1 + u.bredd_cv * float(rng.standard_normal()))
    s.axel_bredd = AXEL_ANDEL * s.langd * (1 + u.bredd_cv * float(rng.standard_normal()))
    return s


def nytt_pass(u: EnKamera, rng: np.random.Generator) -> dict:
    """Kamerorna (FO = A, DTL = B, 90° isär med placeringsfelet) och posemodellens fasta
    avvikelse per led och vy, gemensamma för passets slag (felbudgetens nytt_pass)."""
    return FB.nytt_pass(u.fb(), rng)


def sanning(s: Sving) -> dict:
    """De sanna måtten och kurvorna, med MK6:s definitioner på de sanna lederna."""
    t = np.arange(0.05, s.t_slut - 0.05, 0.001)
    P = s.leder(t)
    adress = (s.t_start + F.ADRESS[0], s.t_start + F.ADRESS[1])
    m = M3.svingmatt(P, t, s.t_start, s.t_traff, adress)
    p, sh = M3.vridningar(P, t, adress)
    return {"matt": {k: m[k] for k in ("t_topp", "backen_topp", "brost_topp", "xfaktor_topp", "stretch",
                                        "hofter_oppna_traff", "brost_traff")},
            "t": t, "backen": p, "brost": sh, "start": s.t_start, "traff": s.t_traff}


def lodratt(K: np.ndarray, upp: np.ndarray) -> np.ndarray:
    """Homografin som vrider bilden till en kamera utan lutning: bildens y lodrätt nedåt,
    blicken vågrät, samma K. `upp` är uppåt i kamerans ram (telefonens gravity). METOD M70"""
    ned = -upp / np.linalg.norm(upp)
    fram = np.array([0.0, 0.0, 1.0]) - ned * ned[2]
    fram /= np.linalg.norm(fram)
    hoger = np.cross(ned, fram)
    R = np.stack([hoger, ned, fram])
    return K @ R @ np.linalg.inv(K)


def tillampa(H: np.ndarray, uv: np.ndarray) -> np.ndarray:
    x = np.concatenate([uv, np.ones(uv.shape[:-1] + (1,))], -1) @ H.T
    return x[..., :2] / x[..., 2:3]


def filma(u: EnKamera, s: Sving, kam, fast, t_klick: float, vy: str, rng: np.random.Generator) -> dict:
    """En vy som telefonen ser den: 2D-kedjans faser och mått (matt.mat), och spåren rättade
    mot lodlinjen och jämnade på 1/240 s (MK5). METOD M70"""
    t = KM.bildtider(s.t_slut, rng, tapp=u.tapp)
    obs, konf = FB._observera(kam, s, t, u.fb(), rng, fast)
    xy = np.where((konf >= MIN_KONF)[..., None], obs, np.nan)          # METOD M1
    ut = {"vy": vy, "fel": None}
    try:
        m2 = M.mat(FM.Sving(vy=vy, hand="hoger", x_tecken=1.0, langd_m=s.langd, t_klick=t_klick, t=t, xy=xy))
    except F.SvingFel as e:
        ut["fel"] = str(e)
        return ut
    f = m2["faser"]
    s0 = f["start"] if f["start"] is not None else f["topp"] - F.TOPP_ADRESS_S
    ut.update(topp=f["topp"], traff=t_klick, start=s0, adress=(s0 + F.ADRESS[0], s0 + F.ADRESS[1]),
              matt2d=m2["matt"])
    if u.lodlinje:
        upp = KAL.slumprotation(u.grav_deg, rng) @ (kam.R @ np.array([0.0, 0.0, 1.0]))
        xy = tillampa(lodratt(kam.K, upp), xy)
    k = np.where(np.isfinite(xy).all(-1), konf, 0.0)
    tg = np.arange(t[0] + KANT_S, t[-1] - KANT_S, RUTNAT_S)
    uv, _ = TRI.jamna(t, xy, k, tg, HALVBREDD_2D)
    # normerade bildkoordinater (tangenten av vinkeln från blicken), så att perspektivet går att räkna
    ut.update(t=tg, uv=uv, n=(uv - kam.K[:2, 2]) / kam.K[0, 0])
    return ut


# --------------------------------------------------------------------------------------------
# Hjälp: linjen, adressen och vinkelkurvorna


def linje(uv: np.ndarray, leder: tuple) -> np.ndarray:
    """Linjen främre → bakre led i bild, (T, 2): X (mot målet i FO, mot bollen i DTL), Y nedåt."""
    return uv[:, leder[0]] - uv[:, leder[1]]


def i_adressen(t: np.ndarray, y: np.ndarray, adress: tuple) -> np.ndarray:
    """Medlet över adressens fönster (M4), av rutorna där värdet finns."""
    ok = np.isfinite(y).reshape(len(t), -1).all(axis=1)
    a = (t >= adress[0]) & (t <= adress[1]) & ok
    return y[a].mean(axis=0) if a.any() else np.full(y.shape[1:], np.nan)


def tecken_ur_fasen(t: np.ndarray, mag: np.ndarray, topp: float, traff: float) -> np.ndarray:
    """Tecknet när bara storleken syns: stängd (+) fram till linjens vändning i nedsvingen,
    öppen (−) efter. Vändningen är där den jämnade storleken är minst mellan toppen och
    träffen + 0,10 s. METOD M71"""
    jamn = M3.jamna_kurva(t, mag, HALVBREDD_VINKEL)
    f = (t >= topp) & (t <= traff + KORS_EFTER_S) & np.isfinite(jamn)
    if not f.any():
        return np.ones_like(mag)
    tx = t[f][int(np.argmin(jamn[f]))]
    return np.where(t > tx, -1.0, 1.0)


# --------------------------------------------------------------------------------------------
# Skattarna framifrån (FO): förkortningen, den stela linjen och den lutande axeln


def fo_a(d: np.ndarray, d0: np.ndarray) -> np.ndarray:
    """Förkortningen: |θ| = arccos(Δx / Δx_adress), med Δx med tecken (så att linjen kan
    passera 90°). Bara den vågräta komponenten. METOD M71"""
    return np.degrees(np.arccos(np.clip(d[:, 0] / d0[0], -1.0, 1.0)))


def djupet(A: np.ndarray, B: np.ndarray, L2, nara: bool) -> np.ndarray:
    """Djupskillnaden δ mellan linjens ändar (främre − bakre, i enheter av avståndet till
    linjens mitt) för en stel linje sedd genom en hålkamera: |A + B·δ|² + δ² = L².
    A (T, 2) = ändarnas skillnad i normerade bildkoordinater, B (T, 2) = deras medel (linjens
    mitt sett från blicken), L = linjens längd i samma enhet. `nara`: den främre änden närmast
    kameran (den mindre roten), annars den större. Utan reell rot (linjen ser längre ut än L):
    toppen av parabeln. METOD M71"""
    a = 1.0 + np.sum(B * B, axis=-1)
    b = np.sum(A * B, axis=-1)
    c = np.sum(A * A, axis=-1) - L2
    rot = np.sqrt(np.clip(b * b - a * c, 0.0, None))
    return (-b - rot) / a if nara else (-b + rot) / a


def fo_stel(nf: np.ndarray, nb: np.ndarray, t: np.ndarray, adress: tuple, topp: float, traff: float,
            beta_deg: float | None = None) -> np.ndarray:
    """Den stela linjen framifrån: linjen är lika lång som i adressen och djupet är det som
    saknas (`djupet`, med perspektivet). Den lodräta komponenten räknas inte som djup. Två
    rötter, speglade kring linjen vinkelrät mot synlinjen: den stängda (den mindre) mellan
    passagerna där linjen syns längst i baksvingen och i nedsvingen, annars den öppna (fasen,
    `langsta`). Vinkeln i markplanet är atan2(−δ, ΔX), mot adressens.

    Utan `beta_deg` ligger linjen i bildens plan i adressen. Med `beta_deg` (bålens
    framåtböjning) kommer adressens lutning i bild av en sidböjning av den böjda bålen, som
    också för den högre änden mot bollen: djupet i adressen δ₀ = tan β · ΔY₀ (främre änden
    högre, ΔY₀ < 0, = närmare kameran). METOD M71, METOD M72"""
    A, B = nf - nb, (nf + nb) / 2
    A0, B0 = i_adressen(t, A, adress), i_adressen(t, B, adress)
    d0 = 0.0 if beta_deg is None else math.tan(math.radians(beta_deg)) * float(A0[1])
    L2 = float(np.sum((A0 + B0 * d0) ** 2) + d0 ** 2)
    psi0 = math.degrees(math.atan2(-d0, A0[0] + B0[0] * d0))
    ut = []
    for nara in (True, False):          # vinkeln mot bildens plan, + = främre änden närmare kameran
        d = djupet(A, B, L2, nara)
        ut.append(np.degrees(np.arctan2(-d, A[:, 0] + B[:, 0] * d)))
    stangd, oppen = ut
    # Rötterna speglas kring linjen vinkelrät mot synlinjen, där den syns längst. Den stängda
    # roten gäller mellan baksvingens och nedsvingens passage där; adressen ligger redan på den
    # stängda sidan när adressens djup är närmare kameran än den vinkelräta linjens.
    langd = M3.jamna_kurva(t, np.linalg.norm(A, axis=1), HALVBREDD_VINKEL)
    vinkelrat = -float(A0 @ B0) / (1.0 + float(B0 @ B0))
    t1 = t[0] - 1.0 if d0 < vinkelrat else langsta(t, langd, adress[1], topp)
    t2 = langsta(t, langd, topp, traff + KORS_EFTER_S)
    return np.where((t > t1) & (t <= t2), stangd, oppen) - psi0


def langsta(t: np.ndarray, langd: np.ndarray, fran: float, till: float) -> float:
    """Tiden då linjen syns längst mellan `fran` och `till` (där den står vinkelrät mot
    synlinjen); `till` när inget värde finns. METOD M71"""
    f = (t >= fran) & (t <= till) & np.isfinite(langd)
    return float(t[f][int(np.argmax(langd[f]))]) if f.any() else till


PHI = np.radians(np.arange(-180.0, 180.0, 1.0))  # METOD M72: vridningarna som prövas, steg 1° (sedan en parabel)


def fo_b(nf: np.ndarray, nb: np.ndarray, A0: np.ndarray, beta_deg: float) -> np.ndarray:
    """Den lutande axeln framifrån: linjen vrids φ kring en axel som lutar `beta_deg` mot
    bollen (mot kameran), vinkelrät mot linjen i adressen (där den antas ligga i bildens plan).
    Varje φ ger en linje i rummet och, genom hålkameran, en linje i bild; φ väljs där den ligger
    närmast den som syns (steg 1°, sedan en parabel). Tecknet kommer ur den lodräta
    komponenten: den främre änden nedåt = stängd. Vinkeln i markplanet tas ur den vridna
    linjen. METOD M72"""
    b = math.radians(beta_deg)
    l0 = np.array([A0[0], 0.0, -A0[1]])                     # x mot målet, y bort från kameran, z upp
    a = np.array([0.0, -math.sin(b), math.cos(b)])
    a = a - (a @ l0) / (l0 @ l0) * l0
    a /= np.linalg.norm(a)
    c = np.cross(a, l0)                                     # φ > 0: främre änden bort från bollen (öppnar)
    l = np.outer(np.cos(PHI), l0) + np.outer(np.sin(PHI), c)  # (P, 3)
    A, B = nf - nb, (nf + nb) / 2                           # (T, 2)
    # i bild: ΔX/d = A + B·δ med δ = l_y, alltså A = (l_x, −l_z) − B·l_y
    px = l[None, :, 0] - B[:, None, 0] * l[None, :, 1]
    py = -l[None, :, 2] - B[:, None, 1] * l[None, :, 1]
    kost = (A[:, None, 0] - px) ** 2 + (A[:, None, 1] - py) ** 2   # (T, P)
    ok = np.isfinite(kost).all(axis=1)
    i = np.argmin(np.where(np.isfinite(kost), kost, np.inf), axis=1)
    P = len(PHI)
    y0, y1, y2 = (kost[np.arange(len(i)), (i + k) % P] for k in (-1, 0, 1))
    den = y0 - 2 * y1 + y2
    steg = np.where(den > 0, 0.5 * (y0 - y2) / np.where(den > 0, den, 1.0), 0.0)
    phi = PHI[i] + steg * (PHI[1] - PHI[0])
    lin = np.outer(np.cos(phi), l0) + np.outer(np.sin(phi), c)
    return np.where(ok, np.degrees(np.arctan2(-lin[:, 1], lin[:, 0])), np.nan)   # + = stängd


def bojning_fo(uv: np.ndarray, t: np.ndarray, adress: tuple) -> float:
    """Bålens framåtböjning ur FO-figuren i adressen: bålen (höftmitt → axelmitt) syns
    förkortad mot sin längd ur benens skala (M2: bål 0,288 och ben 0,491 av längden), så
    cos β = bålen i bild / bålen ur benen. METOD M72"""
    P = (uv[:, I["v_hoft"]] + uv[:, I["h_hoft"]]) / 2
    C = (uv[:, I["v_axel"]] + uv[:, I["h_axel"]]) / 2
    A = (uv[:, I["v_fotled"]] + uv[:, I["h_fotled"]]) / 2
    ben = np.linalg.norm(i_adressen(t, A - P, adress))
    bal = np.linalg.norm(i_adressen(t, C - P, adress))
    if not (ben > 0 and np.isfinite(bal)):
        return float("nan")
    return math.degrees(math.acos(min(1.0, bal / (ben * M.BAL / M.BEN))))


# --------------------------------------------------------------------------------------------
# Skattaren bakifrån (DTL): bredden


def dtl_c(nf: np.ndarray, nb: np.ndarray, w: float, t: np.ndarray, adress: tuple) -> np.ndarray:
    """Bredden bakifrån: linjen pekar längs blicken i adressen och breddas med vridningen.
    Med linjens sanna längd w (normerad, som `djupet`) är den främre änden längre bort än
    den bakre (den större roten) så länge vinkeln är under 90°, och vinkeln i markplanet är
    atan2(ΔX, δ), med tecken: den främre änden mot bollen (+X) = stängd. Adressens vinkel
    dras av. Över 90° viks vinkeln tillbaka (felet mäts). METOD M73"""
    A, B = nf - nb, (nf + nb) / 2
    d = djupet(A, B, w * w, nara=False)
    psi = np.degrees(np.arctan2(A[:, 0] + B[:, 0] * d, d))
    return psi - i_adressen(t, psi, adress)


def bal_n(n: np.ndarray, t: np.ndarray, adress: tuple) -> float:
    P = (n[:, I["v_hoft"]] + n[:, I["h_hoft"]]) / 2
    C = (n[:, I["v_axel"]] + n[:, I["h_axel"]]) / 2
    return float(np.linalg.norm(i_adressen(t, C - P, adress)))


def bredder(vy_dtl: dict, vy_fo: dict | None) -> dict:
    """Linjernas sanna längd i DTL:s normerade bild ur tre källor. METOD M73
    - "m2": bålen i adressen är 0,288 av längden (M2), höfterna 0,11 och axlarna 0,20;
    - "fo": linjens längd i FO:s adress mot benen där (M2:s skala), i DTL:s skala;
    - "max": linjens största längd i bild från toppen till finishen, där linjen står tvärs."""
    t, n, adr = vy_dtl["t"], vy_dtl["n"], vy_dtl["adress"]
    bal = bal_n(n, t, adr)
    ut = {"m2": {"hofter": bal * HOFT_ANDEL / M.BAL, "axlar": bal * AXEL_ANDEL / M.BAL}}
    if vy_fo is not None and vy_fo.get("fel") is None:
        tf, nf, af = vy_fo["t"], vy_fo["n"], vy_fo["adress"]
        P = (nf[:, I["v_hoft"]] + nf[:, I["h_hoft"]]) / 2
        A = (nf[:, I["v_fotled"]] + nf[:, I["h_fotled"]]) / 2
        ben = np.linalg.norm(i_adressen(tf, A - P, af))
        ut["fo"] = {namn: np.linalg.norm(i_adressen(tf, linje(nf, led), af)) / ben * M.BEN / M.BAL * bal
                    for namn, led in (("hofter", HOFTER), ("axlar", AXLAR))}
    f = (t >= vy_dtl["topp"]) & (t <= vy_dtl["traff"] + FINISH_S)
    ut["max"] = {}
    for namn, led in (("hofter", HOFTER), ("axlar", AXLAR)):
        L = M3.jamna_kurva(t, np.linalg.norm(linje(n, led), axis=1), BREDD_JAMNING_S)[f]
        ut["max"][namn] = float(np.nanmax(L)) if np.isfinite(L).any() else float("nan")
    return ut


# --------------------------------------------------------------------------------------------
# Kurvorna och måtten


def kurvor(namn: str, vyer: dict, br: dict | None) -> tuple[np.ndarray, np.ndarray] | None:
    """Skattarens vinkelkurvor (bäcken, axlar) i grader på vyns tidsaxel, + = stängd."""
    vy = vyer[VY[namn]]
    if vy.get("fel") is not None:
        return None
    t, uv, n, adr = vy["t"], vy["uv"], vy["n"], vy["adress"]
    ut = []
    for linjen, led in (("hofter", HOFTER), ("axlar", AXLAR)):
        d = linje(uv, led)
        d0 = i_adressen(t, d, adr)
        if not np.isfinite(d0).all():
            return None
        if namn == "fo_a":
            mag = fo_a(d, d0)
            y = mag * tecken_ur_fasen(t, mag, vy["topp"], vy["traff"])
        elif namn == "fo_stel":
            y = fo_stel(n[:, led[0]], n[:, led[1]], t, adr, vy["topp"], vy["traff"])
        elif namn in ("fo_b", "fo_b_dtl", "fo_stel_b"):
            if namn in ("fo_b", "fo_stel_b"):      # en telefon: böjningen ur FO-figuren
                beta = bojning_fo(uv, t, adr)
            else:                                  # M6 ur ett parat (eller tidigare) DTL-pass
                beta = (vyer["dtl"].get("matt2d") or {}).get("brost_bojning_adress", np.nan)
            if linjen == "hofter":
                beta = beta * BACKEN_AV_BAL
            if not (np.isfinite(beta) and beta > 1.0):
                return None
            if namn == "fo_stel_b":
                y = fo_stel(n[:, led[0]], n[:, led[1]], t, adr, vy["topp"], vy["traff"], beta)
            else:
                y = fo_b(n[:, led[0]], n[:, led[1]], i_adressen(t, linje(n, led), adr), beta)
        else:
            kalla = {"dtl_c": "m2", "dtl_c_fo": "fo", "dtl_c_max": "max"}[namn]
            w = (br or {}).get(kalla, {}).get(linjen, np.nan)
            if not (np.isfinite(w) and w > 0):
                return None
            y = dtl_c(n[:, led[0]], n[:, led[1]], w, t, adr)
        ut.append(M3.jamna_kurva(t, y, HALVBREDD_VINKEL))      # MK6: ±30 ms före måtten
    return ut[0], ut[1]


def matt_ur_kurvor(t, p, s, topp, traff) -> dict:
    m = M3.matt_ur_vinklar(t, p, s, topp, traff)
    m["brost_traff"] = M3._vid(t, s, traff)
    return m


def jamfor_kurvor(t, p, s, sant: dict) -> dict:
    """Kurvans fel mot sanningen från den sanna starten till träffen: RMS per kurva, och
    felen per bin av den sanna vinkeln (summa av kvadrater och antal). METOD M70"""
    ut = {}
    f = (t >= sant["start"]) & (t <= sant["traff"])
    for namn, est, sann in (("backen", p, sant["backen"]), ("brost", s, sant["brost"]),
                            ("xfaktor", s - p, sant["brost"] - sant["backen"])):
        sv = np.interp(t[f], sant["t"], sann)
        e = est[f] - sv
        ok = np.isfinite(e)
        ut[namn] = float(np.sqrt(np.mean(e[ok] ** 2))) if ok.sum() > 10 else float("nan")
        if namn != "xfaktor":
            b = np.digitize(np.abs(sv[ok]), VINKEL_BINS) - 1
            ut[namn + "_bin"] = [(float(np.sum(e[ok][b == k] ** 2)), int(np.sum(b == k)))
                                 for k in range(len(VINKEL_BINS) - 1)]
    return ut


def forsok(u: EnKamera, rng: np.random.Generator, s: Sving | None = None, pas: dict | None = None,
           skattare=SKATTARE) -> dict:
    """Ett försök: en sving, båda vyerna och alla skattare. {"sant": mått, skattare: {"fel": mått,
    "kurva": ...}}; en skattare som inte gick står med None."""
    s = s or ny_sving(u, rng)
    pas = pas or nytt_pass(u, rng)
    t_klick = s.t_traff + float(rng.uniform(-1, 1)) * u.klick_ms / 1000
    vyer = {"fo": filma(u, s, pas["A"], pas["fastA"], t_klick, "fo", rng),
            "dtl": filma(u, s, pas["B"], pas["fastB"], t_klick, "dtl", rng)}
    sant = sanning(s)
    br = bredder(vyer["dtl"], vyer["fo"]) if vyer["dtl"].get("fel") is None else None
    ut = {"sant": sant["matt"]}
    for namn in skattare:
        k = kurvor(namn, vyer, br)
        if k is None:
            ut[namn] = None
            continue
        vy = vyer[VY[namn]]
        p, sh = k
        m = matt_ur_kurvor(vy["t"], p, sh, vy["topp"], vy["traff"])
        ut[namn] = {"fel": {x: m[x] - sant["matt"][x] for x in MATT},
                    "kurva": jamfor_kurvor(vy["t"], p, sh, sant)}
    return ut


# --------------------------------------------------------------------------------------------
# Monte Carlo och sammanfattningen


def sammanfatta(fel) -> dict:
    fel = np.asarray(fel, float)
    fel = fel[np.isfinite(fel)]
    if len(fel) == 0:
        return dict(bias=np.nan, sd=np.nan, rmse=np.nan, p95=np.nan, n=0)
    return dict(bias=float(fel.mean()), sd=float(fel.std(ddof=1)) if len(fel) > 1 else 0.0,
                rmse=float(np.sqrt(np.mean(fel ** 2))), p95=float(np.percentile(np.abs(fel), 95)), n=len(fel))


def monte_carlo(u: EnKamera, n: int, seed: int = 1, skattare=SKATTARE) -> dict:
    """n försök: per skattare och mått bias, SD, RMSE och P95 av |fel|; kurvornas RMS (median
    och P95 över svingarna) och felet per bin av den sanna vinkeln (RMSE)."""
    rng = np.random.default_rng(seed)
    fel = {k: {m: [] for m in MATT} for k in skattare}
    kurva = {k: {c: [] for c in KURVOR} for k in skattare}
    nb = len(VINKEL_BINS) - 1
    binn = {k: {c: np.zeros((nb, 2)) for c in ("backen", "brost")} for k in skattare}
    bortfall = {k: 0 for k in skattare}
    for _ in range(n):
        r = forsok(u, rng, skattare=skattare)
        for k in skattare:
            if r[k] is None:
                bortfall[k] += 1
                continue
            for m in MATT:
                fel[k][m].append(r[k]["fel"][m])
            for c in KURVOR:
                kurva[k][c].append(r[k]["kurva"][c])
            for c in ("backen", "brost"):
                binn[k][c] += np.array(r[k]["kurva"][c + "_bin"])
    ut = {}
    for k in skattare:
        kv = {}
        for c in KURVOR:
            v = np.array(kurva[k][c], float)
            v = v[np.isfinite(v)]
            kv[c] = {"median": float(np.median(v)) if len(v) else np.nan,
                     "p95": float(np.percentile(v, 95)) if len(v) else np.nan}
        bins = {c: [float(np.sqrt(s / m)) if m > 0 else np.nan for s, m in binn[k][c]] for c in ("backen", "brost")}
        ut[k] = {"matt": {m: sammanfatta(fel[k][m]) for m in MATT}, "kurva": kv, "bin": bins,
                 "bortfall": bortfall[k]}
    return ut


def pass_monte_carlo(u: EnKamera, n_pass: int, n_slag: int = 10, seed: int = 1, skattare=SKATTARE) -> dict:
    """Passets median (B14: trenden): samma kameror, samma fasta avvikelse och samma spelare
    (längd och punkternas avstånd) för passets slag. Felet är medianen av slagens fel."""
    rng = np.random.default_rng(seed)
    samlat = {k: {m: [] for m in MATT} for k in skattare}
    for _ in range(n_pass):
        pas = nytt_pass(u, rng)
        spelare = ny_sving(u, rng)
        fel = {k: {m: [] for m in MATT} for k in skattare}
        for _ in range(n_slag):
            s = ny_sving(u, rng)
            s.langd = spelare.langd
            s.__post_init__()
            s.hoft_bredd, s.axel_bredd = spelare.hoft_bredd, spelare.axel_bredd
            r = forsok(u, rng, s=s, pas=pas, skattare=skattare)
            for k in skattare:
                if r[k] is not None:
                    for m in MATT:
                        fel[k][m].append(r[k]["fel"][m])
        for k in skattare:
            for m in MATT:
                v = np.array(fel[k][m], float)
                samlat[k][m].append(float(np.nanmedian(v)) if np.isfinite(v).any() else np.nan)
    return {k: {m: sammanfatta(samlat[k][m]) for m in MATT} for k in skattare}


# --------------------------------------------------------------------------------------------
# Tabellerna (docs/S6E_EN_TELEFON.md)

NAMN = {"backen_topp": "Bäcken, topp", "brost_topp": "Axlar, topp", "xfaktor_topp": "X-factor, topp",
        "hofter_oppna_traff": "Höfter öppna, träff", "brost_traff": "Axlar, träff", "stretch": "Stretch"}
SKATTARNAS_NAMN = {"fo_a": "FO a, förkortning", "fo_stel": "FO, stel linje", "fo_b": "FO b, lutande axel (β FO)",
                   "fo_b_dtl": "FO b, lutande axel (β DTL)", "fo_stel_b": "FO b2, stel linje + adressens djup (β FO)",
                   "dtl_c": "DTL c, bredd (M2)", "dtl_c_fo": "DTL c, bredd (FO)", "dtl_c_max": "DTL c, bredd (max)"}


def _cell(r: dict, vis: str) -> str:
    if r["n"] == 0:
        return "–"
    if vis == "bias":
        return f"{r['bias']:+.1f} / {r['sd']:.1f} / {r['p95']:.0f}"
    return f"{r['rmse']:.1f}"


def tabell(rubrik: str, rader: list[tuple[str, dict]], skattare, vis: str = "bias") -> str:
    """En rad per (uppställning, skattare): bias / SD / P95 per mått, kurvornas median-RMS."""
    ut = [f"\n### {rubrik}\n", "| Uppställning | Skattare | " + " | ".join(NAMN[m] for m in MATT)
          + " | Kurva bäcken / axlar / X (RMS, median) |", "|" + "---|" * (len(MATT) + 3)]
    for namn, res in rader:
        for k in skattare:
            r = res[k]
            kv = r["kurva"]
            ut.append(f"| {namn} | {SKATTARNAS_NAMN[k]} | " + " | ".join(_cell(r["matt"][m], vis) for m in MATT)
                      + f" | {kv['backen']['median']:.1f} / {kv['brost']['median']:.1f} / {kv['xfaktor']['median']:.1f} |")
    return "\n".join(ut)


def tabell_bin(rubrik: str, res: dict, skattare) -> str:
    kol = [f"{VINKEL_BINS[i]:.0f}–{VINKEL_BINS[i + 1]:.0f}°" for i in range(len(VINKEL_BINS) - 1)]
    ut = [f"\n### {rubrik}\n", "| Skattare | Linje | " + " | ".join(kol) + " |", "|" + "---|" * (len(kol) + 2)]
    for k in skattare:
        for c, cn in (("backen", "bäcken"), ("brost", "axlar")):
            ut.append(f"| {SKATTARNAS_NAMN[k]} | {cn} | " + " | ".join(
                "–" if not np.isfinite(v) else f"{v:.1f}" for v in res[k]["bin"][c]) + " |")
    return "\n".join(ut)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--n", type=int, default=120)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--bara", default="", help="ren, bas, bin, placering, pass (kommaseparerat)")
    a = ap.parse_args(argv)
    bara = set(filter(None, a.bara.split(",")))
    vill = lambda x: not bara or x in bara  # noqa: E731
    bas = EnKamera()
    lut = replace(bas, variant="lutande")
    n4 = max(a.n // 4, 8)
    print(f"En telefon: {a.n} försök per rad (utan brus {n4}), frö {a.seed}. Fel = skattat − sant i grader: "
          "bias / SD / P95 av |fel|. Kurvan: RMS från starten till träffen, median över svingarna.")
    t0 = time.time()

    def klar(namn):
        print(f"<!-- {namn}: {time.time() - t0:.0f} s -->", file=sys.stderr, flush=True)

    if vill("ren"):
        rader = [("Inget brus, inget fel", monte_carlo(REN, n4, a.seed)),
                 ("Inget brus, inget fel, lutande", monte_carlo(replace(REN, variant="lutande"), n4, a.seed)),
                 ("Inget brus, placering ±5°, klick ±7 ms, tappade rutor",
                  monte_carlo(replace(REN, azimut_fel_deg=5.0, klick_ms=KLICK_MS, tapp=KM.TAPP), n4, a.seed))]
        print(tabell("Utan brus", rader, SKATTARE), flush=True)
        klar("ren")
    if vill("bas"):
        rader = [(f"Brus {b}", monte_carlo(replace(bas, brus=b), a.n, a.seed)) for b in ("bra", "typiskt", "daligt")]
        rader.append(("Brus typiskt, lutande", monte_carlo(replace(lut, brus="typiskt"), a.n, a.seed)))
        rader.append(("Brus typiskt, punkternas avstånd kända", monte_carlo(replace(bas, bredd_cv=0.0), a.n, a.seed)))
        print(tabell("Brusnivåerna (3 m, höfthöjd, placering ±5°, skymning, klick ±7 ms)", rader, SKATTARE), flush=True)
        klar("bas")
    if vill("bin"):
        print(tabell_bin("Kurvans fel efter den sanna vinkeln, inget brus (RMSE)", monte_carlo(REN, n4, a.seed),
                         SKATTARE))
        print(tabell_bin("Kurvans fel efter den sanna vinkeln, typiskt brus (RMSE)", monte_carlo(bas, a.n, a.seed),
                         SKATTARE), flush=True)
        klar("bin")
    if vill("placering"):
        rader = [(f"{h:.1f} m höjd", monte_carlo(replace(bas, hojd=h), a.n, a.seed)) for h in (0.7, 1.5)]
        rader.append(("1,5 m höjd, utan lodlinjen", monte_carlo(replace(bas, hojd=1.5, lodlinje=False), a.n, a.seed)))
        rader += [(f"{d:.1f} m bort", monte_carlo(replace(bas, avstand=d), a.n, a.seed)) for d in (2.5, 4.0)]
        print(tabell("Placeringen (typiskt brus)", rader, SKATTARE), flush=True)
        klar("placering")
    if vill("pass"):
        rader = []
        for namn, u in (("bra", replace(bas, brus="bra")), ("typiskt", bas), ("typiskt, lutande", lut)):
            r = pass_monte_carlo(u, n4, 10, a.seed)
            rader.append((f"Passets median, brus {namn}",
                          {k: {"matt": r[k], "kurva": {c: {"median": np.nan} for c in KURVOR}} for k in SKATTARE}))
        print(tabell(f"Passets median ({n4} pass om 10 slag; samma kameror, fasta avvikelse och spelare)",
                     rader, SKATTARE), flush=True)
        klar("pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
