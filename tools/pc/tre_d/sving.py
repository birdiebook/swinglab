"""En påhittad 3D-sving för en högerspelare: 13 leder över tiden.

Kroppen är en kedja: bäckenet (läge + vridning, framåtböjning, sidböjning),
bålen ovanpå (egen vridning, böjning, sidböjning), axlarna med skulderbladens
glidning, huvudet, armarna (händerna på en bana i ett lutande plan, armbågarna
ur tvålänkad invers kinematik) och benen (fötterna står still, knäna ur
invers kinematik).

Vinklarna är rörelsekurvor genom nyckelbilder (monoton kubisk interpolation,
PCHIP), så att topp och vändning hamnar där nyckelbilderna säger. Storlekarna
är valda efter docs/research/1_matt_och_granser.md (§1.7, §1.8): bäckenet
40–45° vid toppen, axellinjen 85–95°, X-factor-stretch några grader i tidig
nedsving, höfterna 35–45° öppna vid träff. Det är en rimlig sving, inte en
uppmätt (antagande, S6_FELBUDGET.md §2).

Kroppsmåtten följer Drillis & Continis andelar av längden H (via Winter,
Biomechanics and Motor Control of Human Movement, fig. 4.1; standard, ej läst
i original i detta pass). Avståndet mellan höftpunkterna och mellan
axelpunkterna är antaganden: Vision och MediaPipe sätter punkterna nära
ledcentrum, inte på kroppens ytterkant.

Vridningen räknas positiv bort från målet (bakåt i baksvingen); Rz(-θ) är
medurs sett ovanifrån.
"""
from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

LEDER = (
    "nasa",
    "v_axel", "h_axel",
    "v_armbage", "h_armbage",
    "v_handled", "h_handled",
    "v_hoft", "h_hoft",
    "v_kna", "h_kna",
    "v_fotled", "h_fotled",
)
I = {namn: i for i, namn in enumerate(LEDER)}

# Segment för skymningen: (led a, led b, radie i m). Bålen läggs till separat
# (bäckenets mitt till axlarnas mitt).
SEGMENT = (
    ("v_axel", "v_armbage", 0.05), ("h_axel", "h_armbage", 0.05),
    ("v_armbage", "v_handled", 0.04), ("h_armbage", "h_handled", 0.04),
    ("v_hoft", "v_kna", 0.07), ("h_hoft", "h_kna", 0.07),
    ("v_kna", "v_fotled", 0.05), ("h_kna", "h_fotled", 0.05),
)
# Bålens kärna, inte ytan: höft- och axelpunkterna ligger inne i kroppen och
# räknas skymda först när strålen går genom kärnan (antagande).
BAL_RADIE = 0.09


# --------------------------------------------------------------------------
# Kurvor


def pchip(x: np.ndarray, y: np.ndarray, t: np.ndarray) -> np.ndarray:
    """Monoton kubisk Hermite-interpolation (Fritsch–Carlson).

    Lutningen är noll i ändarna och i varje lokalt extremvärde, så en topp i
    nyckelbilderna blir en topp i kurvan, på samma tid.
    """
    x = np.asarray(x, float)
    y = np.asarray(y, float)
    t = np.clip(np.asarray(t, float), x[0], x[-1])
    h = np.diff(x)
    d = np.diff(y) / h
    m = np.zeros_like(y)
    for k in range(1, len(x) - 1):
        if d[k - 1] * d[k] > 0:
            w1 = 2 * h[k] + h[k - 1]
            w2 = h[k] + 2 * h[k - 1]
            m[k] = (w1 + w2) / (w1 / d[k - 1] + w2 / d[k])
    k = np.clip(np.searchsorted(x, t, side="right") - 1, 0, len(x) - 2)
    s = (t - x[k]) / h[k]
    h00 = (1 + 2 * s) * (1 - s) ** 2
    h10 = s * (1 - s) ** 2
    h01 = s * s * (3 - 2 * s)
    h11 = s * s * (s - 1)
    return h00 * y[k] + h10 * h[k] * m[k] + h01 * y[k + 1] + h11 * h[k] * m[k + 1]


def rot_x(a: np.ndarray) -> np.ndarray:
    c, s = np.cos(a), np.sin(a)
    o, z = np.ones_like(a), np.zeros_like(a)
    return np.stack([np.stack([o, z, z], -1), np.stack([z, c, -s], -1), np.stack([z, s, c], -1)], -2)


def rot_y(a: np.ndarray) -> np.ndarray:
    c, s = np.cos(a), np.sin(a)
    o, z = np.ones_like(a), np.zeros_like(a)
    return np.stack([np.stack([c, z, s], -1), np.stack([z, o, z], -1), np.stack([-s, z, c], -1)], -2)


def rot_z(a: np.ndarray) -> np.ndarray:
    c, s = np.cos(a), np.sin(a)
    o, z = np.ones_like(a), np.zeros_like(a)
    return np.stack([np.stack([c, -s, z], -1), np.stack([s, c, z], -1), np.stack([z, z, o], -1)], -2)


def segment_rotation(vrid_deg, bojning_deg, sidbojning_deg) -> np.ndarray:
    """R = Rz(−vridning) · Rx(framåtböjning) · Ry(sidböjning), batchad.

    Inre ordning ZXY: först vridningen kring lodlinjen, sedan böjningen mot
    bollen kring segmentets sidoaxel, sist sidböjningen kring segmentets
    bakåtaxel. Sidböjning > 0 sänker vänster sida (mot målet).
    """
    v = np.radians(np.asarray(vrid_deg, float))
    b = np.radians(np.asarray(bojning_deg, float))
    s = np.radians(np.asarray(sidbojning_deg, float))
    return rot_z(-v) @ rot_x(b) @ rot_y(s)


def tvalank(start: np.ndarray, mal: np.ndarray, l1: float, l2: float, pol: np.ndarray):
    """Tvålänkad invers kinematik. Returnerar (mellanled, mål som nåtts).

    Om målet ligger utom räckhåll flyttas det in längs linjen (99,9 % av
    räckvidden), så att länkarnas längd alltid stämmer.
    """
    v = mal - start
    d = np.linalg.norm(v, axis=-1, keepdims=True)
    e = v / np.maximum(d, 1e-9)
    dmax = 0.999 * (l1 + l2)
    dmin = abs(l1 - l2) * 1.001 + 1e-6
    d = np.clip(d, dmin, dmax)
    mal = start + e * d
    a = (l1 ** 2 - l2 ** 2 + d ** 2) / (2 * d)
    h = np.sqrt(np.maximum(l1 ** 2 - a ** 2, 0.0))
    p = pol - np.sum(pol * e, axis=-1, keepdims=True) * e
    p = p / np.maximum(np.linalg.norm(p, axis=-1, keepdims=True), 1e-9)
    return start + a * e + h * p, mal


# --------------------------------------------------------------------------
# Svingen

# Nyckelbildernas tider relativt fasernas tider; värden i grader eller meter.
# Kolumnerna: 0, start, start+0.25, start+0.5, topp−0.04, topp, topp+0.05,
# topp+0.13, träff, träff+0.15, finish, slut.
_NYCKEL = {
    # vridning, positiv bort från målet
    "backen_vrid": [0, 0, 12, 30, 45, 44.5, 38, 14, -40, -70, -90, -90],
    "bal_vrid":    [0, 0, 28, 66, 97, 99, 99.5, 62, -32, -80, -115, -115],
    # framåtböjning mot bollen
    "backen_boj":  [22, 22, 21, 20, 20, 20, 19, 18, 15, 10, 5, 5],
    "bal_boj":     [38, 38, 37, 35, 33, 33, 33, 32, 30, 20, 10, 10],
    # sidböjning, > 0 sänker vänster sida
    "backen_sid":  [0, 0, 2, 4, 5, 5, 4, 0, -10, -10, -10, -10],
    "bal_sid":     [-10, -10, 5, 18, 25, 25, 24, 5, -30, -30, -25, -25],
    # bäckenets mitt, m: sway (x, mot målet), thrust (−y = mot bollen), lyft (z)
    "sway":        [0, 0, -0.01, -0.02, -0.02, -0.02, 0.0, 0.04, 0.10, 0.11, 0.12, 0.12],
    "thrust":      [0, 0, 0, 0, 0, 0, 0, -0.005, -0.02, -0.03, -0.03, -0.03],
    "lyft":        [0, 0, 0, 0.005, 0.005, 0.005, 0, -0.01, 0.01, 0.0, -0.01, -0.01],
    # händernas vinkel i svingplanet, grader från adressen
    "hand":        [0, 0, 40, 95, 150, 155, 150, 110, -3, -90, -190, -190],
}


@dataclass
class Sving:
    """En påhittad sving. `leder(t)` ger (T, 13, 3) i meter, världens ram."""

    langd: float = 1.80
    t_start: float = 0.30
    baksving: float = 0.80
    nedsving: float = 0.27
    utsving: float = 0.55
    efter: float = 0.25
    nyckel: dict = field(default_factory=lambda: {k: list(v) for k, v in _NYCKEL.items()})
    # > 0: en pinne (m) i bältet ersätter höftpunkterna med sina ändar, 12 cm
    # framför höftlederna och vriden `pinnvinkel` grader mot höftlinjen (vänster
    # ände framåt), så att ändarna inte hamnar i linje med DTL-kameran i adressen.
    # Vridningen mäts mot adressen, så en fast vinkel tar ut sig själv.
    hoftpinne: float = 0.0
    pinnvinkel: float = 0.0
    # > 0: en stav (m) tvärs över övre ryggen (en sele, i höjd med skulderbladen,
    # 10 cm bakom axlarnas mitt) ersätter axelpunkterna med sina ändar. Den följer
    # bröstkorgen (thorax), inte skulderbladen.
    ryggstav: float = 0.0

    def __post_init__(self) -> None:
        H = self.langd
        self.t_topp = self.t_start + self.baksving
        self.t_traff = self.t_topp + self.nedsving
        self.t_finish = self.t_traff + self.utsving
        self.t_slut = self.t_finish + self.efter
        a, tp, ti = self.t_start, self.t_topp, self.t_traff
        bs, ds = self.baksving, self.nedsving
        self._tx = np.array([0.0, a, a + 0.3125 * bs, a + 0.625 * bs, tp - 0.04, tp, tp + 0.05,
                             tp + 0.13 * ds / 0.27, ti, ti + 0.15, self.t_finish, self.t_slut])
        # Drillis & Contini (andelar av H)
        self.lar = 0.245 * H
        self.smalben = 0.246 * H
        self.overarm = 0.186 * H
        self.underarm = 0.146 * H
        self.bal = (0.818 - 0.530) * H
        self.fotled_h = 0.039 * H
        # antaganden (ledcentrum, inte ytterkant)
        self.hoft_bredd = 0.11 * H
        self.axel_bredd = 0.20 * H
        self.stans = 0.22 * H
        self.backen_h = 0.50 * H
        self.backen_y = 0.06
        # skulderbladens glidning (m) vid full vridning: ledande axel fram, bakre bak
        self.skulder_fram = 0.035
        self.skulder_bak = 0.020
        self._hand_plan()

    # ---------------------------------------------------------------- kurvor

    def kurvor(self, t) -> dict:
        t = np.asarray(t, float)
        return {k: pchip(self._tx, np.asarray(v, float), t) for k, v in self.nyckel.items()}

    def _backen_mitt(self, k: dict) -> np.ndarray:
        return np.stack([k["sway"], self.backen_y + k["thrust"], self.backen_h + k["lyft"]], -1)

    def segment(self, t):
        """Bäckenets och bålens rotationsmatriser (T, 3, 3) och kurvorna."""
        k = self.kurvor(t)
        Rp = segment_rotation(k["backen_vrid"], k["backen_boj"], k["backen_sid"])
        Rt = segment_rotation(k["bal_vrid"], k["bal_boj"], k["bal_sid"])
        return Rp, Rt, k

    def _axel_mitt(self, k: dict, Rt: np.ndarray) -> np.ndarray:
        return self._backen_mitt(k) + Rt @ np.array([0.0, 0.0, self.bal])

    def _hand_plan(self) -> None:
        """Svingplanet: händerna i adress, cirkeln kring axlarnas mitt."""
        k = self.kurvor(np.array([0.0]))
        Rt = segment_rotation(k["bal_vrid"], k["bal_boj"], k["bal_sid"])
        c0 = self._axel_mitt(k, Rt)[0]
        hand0 = np.array([0.05, -0.40, 0.43 * self.langd])
        v = hand0 - c0
        self.hand_r = float(np.linalg.norm(v))
        self.plan_a = v / self.hand_r
        b = np.array([-1.0, 0.0, 0.0])
        b = b - (b @ self.plan_a) * self.plan_a
        self.plan_b = b / np.linalg.norm(b)

    # ---------------------------------------------------------------- leder

    def leder(self, t) -> np.ndarray:
        t = np.atleast_1d(np.asarray(t, float))
        Rp, Rt, k = self.segment(t)
        T = len(t)
        P = np.zeros((T, len(LEDER), 3))
        pm = self._backen_mitt(k)
        lat_p = Rp[:, :, 0]
        P[:, I["v_hoft"]] = pm + 0.5 * self.hoft_bredd * lat_p
        P[:, I["h_hoft"]] = pm - 0.5 * self.hoft_bredd * lat_p
        hoft_v, hoft_h = P[:, I["v_hoft"]].copy(), P[:, I["h_hoft"]].copy()

        am = pm + Rt[:, :, 2] * self.bal
        lat_t, bak_t, upp_t = Rt[:, :, 0], Rt[:, :, 1], Rt[:, :, 2]
        # skulderbladen: glider fram (−bak_t) med vridningen, åt var sitt håll
        s = np.clip(k["bal_vrid"] / 90.0, -1.3, 1.3)
        fram_v = 0.01 + np.where(s > 0, self.skulder_fram * s, self.skulder_bak * s)
        fram_h = 0.01 + np.where(s > 0, -self.skulder_bak * s, -self.skulder_fram * s)
        P[:, I["v_axel"]] = am + 0.5 * self.axel_bredd * lat_t - fram_v[:, None] * bak_t
        P[:, I["h_axel"]] = am - 0.5 * self.axel_bredd * lat_t - fram_h[:, None] * bak_t

        # huvudet: följer bålens böjning, vrider bara en fjärdedel (blicken på bollen)
        Rh = segment_rotation(0.25 * k["bal_vrid"], k["bal_boj"] + 15.0, 0.3 * k["bal_sid"])
        P[:, I["nasa"]] = am + Rh @ np.array([0.0, -0.06 * self.langd, 0.095 * self.langd])

        # händerna i svingplanet kring axlarnas mitt
        phi = np.radians(k["hand"])[:, None]
        radial = np.cos(phi) * self.plan_a + np.sin(phi) * self.plan_b
        mitt = am + self.hand_r * radial
        mal_v = mitt - 0.04 * radial
        mal_h = mitt + 0.04 * radial
        pol_arm = np.array([0.0, 0.3, -1.0])
        ab_v, hl_v = tvalank(P[:, I["v_axel"]], mal_v, self.overarm, self.underarm, pol_arm)
        ab_h, hl_h = tvalank(P[:, I["h_axel"]], mal_h, self.overarm, self.underarm, pol_arm)
        P[:, I["v_armbage"]], P[:, I["v_handled"]] = ab_v, hl_v
        P[:, I["h_armbage"]], P[:, I["h_handled"]] = ab_h, hl_h

        # benen: fotlederna står still, knäna ur invers kinematik (pekar mot bollen)
        fv = np.array([0.5 * self.stans, 0.0, self.fotled_h])
        fh = np.array([-0.5 * self.stans, 0.0, self.fotled_h])
        pol_ben = np.array([0.0, -1.0, 0.0])
        kn_v, fv_n = tvalank(hoft_v, np.broadcast_to(fv, (T, 3)), self.lar, self.smalben, pol_ben)
        kn_h, fh_n = tvalank(hoft_h, np.broadcast_to(fh, (T, 3)), self.lar, self.smalben, pol_ben)
        P[:, I["v_kna"]], P[:, I["v_fotled"]] = kn_v, fv_n
        P[:, I["h_kna"]], P[:, I["h_fotled"]] = kn_h, fh_n
        if self.ryggstav > 0:
            rygg = am - 0.05 * self.langd * upp_t + 0.10 * bak_t
            P[:, I["v_axel"]] = rygg + 0.5 * self.ryggstav * lat_t
            P[:, I["h_axel"]] = rygg - 0.5 * self.ryggstav * lat_t
        if self.hoftpinne > 0:
            fram = pm - 0.12 * Rp[:, :, 1]
            a = np.radians(self.pinnvinkel)
            riktning = np.cos(a) * lat_p - np.sin(a) * Rp[:, :, 1]
            P[:, I["v_hoft"]] = fram + 0.5 * self.hoftpinne * riktning
            P[:, I["h_hoft"]] = fram - 0.5 * self.hoftpinne * riktning
        return P


def slumpa_sving(rng: np.random.Generator) -> Sving:
    """En sving med spridning kring grundsvingen: längd, tempo och vinklar."""
    s = Sving(
        langd=float(rng.uniform(1.70, 1.90)),
        baksving=float(rng.uniform(0.74, 0.88)),
        nedsving=float(rng.uniform(0.25, 0.30)),
    )
    n = s.nyckel
    dp = rng.normal(0, 3.0)
    dt = rng.normal(0, 4.0)
    di = rng.normal(0, 3.0)
    for i, f in ((2, 0.3), (3, 0.65), (4, 1.0), (5, 1.0), (6, 1.0), (7, 1.0)):
        n["backen_vrid"][i] += f * dp
        n["bal_vrid"][i] += f * dt
    n["backen_vrid"][8] += di
    for nyckel, sd in (("bal_boj", 3.0), ("bal_sid", 4.0), ("backen_boj", 3.0)):
        d = rng.normal(0, sd)
        n[nyckel] = [v + d for v in n[nyckel]]
    s.__post_init__()
    return s
