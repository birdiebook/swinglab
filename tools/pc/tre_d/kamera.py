"""Två iPhones som filmar svingen: pinhole, bildtider, tappade rutor, brus och skymning.

**Kameran (antagande, S6_FELBUDGET.md §3).** iPhones huvudkamera har 26 mm
ekvivalent brännvidd (Apples tekniska data för iPhone 12–15, ej läst i original
i detta pass; 15 Pro har 24 mm). 35 mm-ekvivalenten avser 4:3-bildens diagonal
(43,3 mm), så 16:9-videons långsida motsvarar 34,6 mm och kortsidan 19,5 mm.
Det ger 67° × 41° synfält och f ≈ 1444 px i 1080 × 1920. Stabilisering och
slowmotion-läget kan beskära mer (f upp mot ~1700 px). Brännvidden mäts med
ChArUco i S6; här är den en parameter.

**Bildtiderna.** 240 bilder/s nominellt. Varje kamera tappar 36 % av rutorna
(Golf SG: oktobers klipp gav cirka 154 bilder/s ur 240), ojämnt: en
Markovkedja med i snitt 1,5 tappade rutor i rad. Kamerornas rutnät ligger
förskjutna mot varandra, och klockorna skiljer sig med synkfelet.

**Bruset i 2D (antagande).** Fyra delar per kamera och led: en fast avvikelse
(modellen sätter punkten på fel ställe på kroppen), ett långsamt fel (AR(1),
τ = 0,15 s: modellen "vandrar" mellan rutor), vitt brus och enstaka
utliggare. Rörelseoskärpan (fart × exponeringstid) lägger till brus på snabba
leder. Skymda leder får 2,5 gånger bruset och låg konfidens, som Vision och
MediaPipe ger dem. Nivåerna är satta efter PCK@0,2 i MediaPipes egen mätning
(docs/research/2_teknik.md §1): 96–97 % inom 0,2 × bålens diameter för
BlazePose Heavy motsvarar högst cirka 18 px i 1σ vid 3 m om felet vore
normalfördelat, och Apple Visions 83–91 % cirka 25 px. Verkliga fel är en
smalare kärna plus utliggare.
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from .sving import I, LEDER, SEGMENT, BAL_RADIE

BREDD, HOJD = 1080, 1920  # stående 1080p
F_PX = 1444.0  # antagande: 26 mm ekvivalent, se modulens text
FPS = 240.0
TAPP = 0.36
REF_AVSTAND = 3.0


@dataclass
class Kamera:
    K: np.ndarray  # (3, 3)
    R: np.ndarray  # (3, 3) värld → kamera
    t: np.ndarray  # (3,)
    namn: str = ""

    @property
    def centrum(self) -> np.ndarray:
        return -self.R.T @ self.t

    @property
    def P(self) -> np.ndarray:
        return self.K @ np.hstack([self.R, self.t[:, None]])

    def till_kamera(self, X: np.ndarray) -> np.ndarray:
        return X @ self.R.T + self.t

    def projicera(self, X: np.ndarray) -> np.ndarray:
        """(..., 3) världspunkter → (..., 2) pixlar."""
        Xc = self.till_kamera(X)
        x = Xc @ self.K.T
        return x[..., :2] / x[..., 2:3]

    def djup(self, X: np.ndarray) -> np.ndarray:
        return self.till_kamera(X)[..., 2]


def K_matris(f: float = F_PX, cx: float = BREDD / 2, cy: float = HOJD / 2) -> np.ndarray:
    return np.array([[f, 0.0, cx], [0.0, f, cy], [0.0, 0.0, 1.0]])


def titta_mot(position, mal, K=None, namn="") -> Kamera:
    """Kamera i `position` som tittar mot `mal`, utan lutning åt sidan.

    Kamerans axlar: x åt höger i bilden, y nedåt, z framåt.
    """
    position = np.asarray(position, float)
    fram = np.asarray(mal, float) - position
    fram /= np.linalg.norm(fram)
    hoger = np.cross(fram, [0.0, 0.0, 1.0])
    hoger /= np.linalg.norm(hoger)
    ned = np.cross(fram, hoger)
    R = np.stack([hoger, ned, fram])
    return Kamera(K=K_matris() if K is None else K, R=R, t=-R @ position, namn=namn)


SIKTE = np.array([0.0, -0.15, 1.0])  # mitt på kroppen i adress


def placera(azimut_deg: float, avstand: float, hojd: float, namn: str = "", f: float = F_PX,
            sikte=SIKTE) -> Kamera:
    """Kamera på en cirkel kring spelaren, siktad mot kroppens mitt. Azimut
    180° = DTL (bakom, längs mållinjen), 270° = FO (framför, på bollens sida)."""
    a = np.radians(azimut_deg)
    pos = np.array([sikte[0] + avstand * np.cos(a), sikte[1] + avstand * np.sin(a), hojd])
    return titta_mot(pos, np.asarray(sikte, float), K_matris(f), namn)


# --------------------------------------------------------------------------
# Bildtider


def bildtider(t_slut: float, rng: np.random.Generator, fps: float = FPS, tapp: float = TAPP,
              skur: float = 1.5) -> np.ndarray:
    """Rutornas sanna tider: rutnät med slumpad fas, tappade rutor i skurar."""
    n = int(t_slut * fps)
    t = (np.arange(n) + rng.uniform(0, 1)) / fps
    if tapp <= 0:
        return t[t < t_slut]
    b = 1.0 / skur  # tappad → kvar
    a = tapp * b / (1 - tapp)  # kvar → tappad
    kvar = np.empty(n, bool)
    tillstand = rng.uniform() > tapp
    for k in range(n):
        kvar[k] = tillstand
        tillstand = (rng.uniform() > a) if tillstand else (rng.uniform() < b)
    t = t[kvar]
    return t[t < t_slut]


# --------------------------------------------------------------------------
# Brus


@dataclass(frozen=True)
class Brus:
    """2D-brus i pixlar vid referensavståndet 3 m och f = 1444 px."""

    vitt: float = 5.0
    vandring: float = 5.0
    fast: float = 5.0
    utliggare: float = 0.03
    utliggare_px: float = 50.0
    skymd_faktor: float = 2.5
    oskarpa_andel: float = 0.3  # del av oskärpans längd som blir fel (1σ)


BRUS = {
    "inget": Brus(0, 0, 0, 0),
    "bra": Brus(3, 3, 3, 0.01),
    "typiskt": Brus(5, 5, 5, 0.03),
    "daligt": Brus(10, 10, 8, 0.05),
    "mycket_daligt": Brus(20, 15, 12, 0.08),
}


def skymda(kam: Kamera, P: np.ndarray) -> np.ndarray:
    """(T, J) sant där leden skyms av ett kroppssegment närmare kameran.

    Segmenten är kapslar (SEGMENT och bålen). En led skyms inte av ett segment
    den själv sitter på.
    """
    C = kam.centrum
    T, J, _ = P.shape
    kapslar = [(I[a], I[b], r) for a, b, r in SEGMENT]
    # bålen från en fjärdedel upp (magen), så att höfterna sitter på dess yta
    bm = 0.5 * (P[:, I["v_hoft"]] + P[:, I["h_hoft"]])
    bal_b = 0.5 * (P[:, I["v_axel"]] + P[:, I["h_axel"]])
    bal_a = bm + 0.25 * (bal_b - bm)
    res = np.zeros((T, J), bool)
    seg = [(P[:, a], P[:, b], r, {a, b}) for a, b, r in kapslar]
    seg.append((bal_a, bal_b, BAL_RADIE, set()))
    for j in range(J):
        Q = P[:, j]
        d = Q - C  # stråle från kameran
        L = np.linalg.norm(d, axis=1)
        u = d / L[:, None]
        for A, B, r, egna in seg:
            if j in egna:
                continue
            # närmaste avstånd mellan strålen (0..L-ε) och segmentet A..B
            s_p, s_q, dist = _linje_avstand(C, u, L - 0.05, A, B)
            res[:, j] |= (dist < r) & (s_p < L - 0.05)
    return res


def _linje_avstand(C, u, Lmax, A, B):
    """Närmaste avstånd mellan strålsegmentet C + s·u (0 ≤ s ≤ Lmax) och A..B."""
    v = B - A
    w0 = C - A
    a = 1.0
    b = np.sum(u * v, axis=1)
    c = np.sum(v * v, axis=1)
    d = np.sum(u * w0, axis=1)
    e = np.sum(v * w0, axis=1)
    den = a * c - b * b
    s = np.where(den > 1e-12, (b * e - c * d) / np.maximum(den, 1e-12), 0.0)
    s = np.clip(s, 0, Lmax)
    q = np.clip((e + b * s) / np.maximum(c, 1e-12), 0, 1)
    s = np.clip((b * q - d) / a, 0, Lmax)
    p1 = C + s[:, None] * u
    p2 = A + q[:, None] * v
    return s, q, np.linalg.norm(p1 - p2, axis=1)


def observera(kam: Kamera, sving, t_sann: np.ndarray, brus: Brus, rng: np.random.Generator,
              exponering: float = 1 / 1000, skala: str = "kropp", fast: np.ndarray | None = None):
    """Vad posemodellen ger i en kamera: (uv (T,J,2), konfidens (T,J), skymd (T,J)).

    `skala`: "kropp" = felet följer personens storlek i bilden (posemodellen
    beskär personen och kör med fast upplösning), "px" = fast i pixlar.
    Leder utanför bilden får NaN och konfidens 0. `fast` (J, 2), standardiserad,
    är den fasta avvikelsen om den ska delas mellan svingar i samma pass.
    """
    P = sving.leder(t_sann)
    T, J, _ = P.shape
    uv = kam.projicera(P)
    sky = skymda(kam, P)
    mitt = 0.5 * (P[0, I["v_hoft"]] + P[0, I["h_hoft"]])
    if skala == "kropp":
        s = (kam.K[0, 0] / kam.djup(mitt)) / (F_PX / REF_AVSTAND)
    else:
        s = 1.0
    fak = np.where(sky, brus.skymd_faktor, 1.0)[..., None]

    fel = np.zeros((T, J, 2))
    fast = rng.standard_normal((J, 2)) if fast is None else fast
    fel += s * brus.fast * fast[None]
    if brus.vandring > 0:
        tau = 0.15
        dt = np.diff(t_sann, prepend=t_sann[0] - 1 / FPS)
        rho = np.exp(-dt / tau)
        e = np.zeros((T, J, 2))
        x = rng.standard_normal((J, 2))
        for k in range(T):
            x = rho[k] * x + np.sqrt(1 - rho[k] ** 2) * rng.standard_normal((J, 2))
            e[k] = x
        fel += s * brus.vandring * e
    fel += s * brus.vitt * rng.standard_normal((T, J, 2))
    # rörelseoskärpa: bildens fart × exponeringstid
    if exponering > 0 and brus.oskarpa_andel > 0 and brus.vitt > 0:
        fart = np.linalg.norm(np.gradient(uv, t_sann, axis=0), axis=-1)  # px/s
        fel += (brus.oskarpa_andel * fart * exponering)[..., None] * rng.standard_normal((T, J, 2))
    fel *= fak
    utl = rng.uniform(size=(T, J)) < brus.utliggare
    if utl.any():
        vinkel = rng.uniform(0, 2 * np.pi, utl.sum())
        storlek = s * brus.utliggare_px * rng.uniform(0.5, 1.5, utl.sum())
        fel[utl] += np.stack([np.cos(vinkel), np.sin(vinkel)], -1) * storlek[:, None]
    obs = uv + fel

    konf = np.where(sky, rng.normal(0.35, 0.12, (T, J)), rng.normal(0.85, 0.08, (T, J)))
    konf = np.where(utl, rng.normal(0.5, 0.2, (T, J)), konf)
    konf = np.clip(konf, 0.02, 1.0)
    utanfor = (obs[..., 0] < 0) | (obs[..., 0] > BREDD) | (obs[..., 1] < 0) | (obs[..., 1] > HOJD)
    obs[utanfor] = np.nan
    konf[utanfor] = 0.0
    return obs, konf, sky


__all__ = ["Kamera", "K_matris", "titta_mot", "placera", "bildtider", "Brus", "BRUS", "observera",
           "skymda", "BREDD", "HOJD", "F_PX", "FPS", "LEDER"]
