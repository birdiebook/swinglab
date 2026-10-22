"""Vridningen, X-factor, stretch och öppna höfter ur 3D-leder.

Definitionerna (S6_FELBUDGET.md §5):

- **Bäckenets vridning** θp(t): linjen höger höft → vänster höft projicerad på
  markplanet (mattans plan), vinkeln mot samma linje i adressen. Positiv bort
  från målet (medurs ovanifrån för en högerspelare). Sportsbox skriver samma
  sak med motsatt tecken (tour ≈ −40° vid toppen, +40° öppen vid träff).
- **Bröstets vridning** θs(t): samma för linjen höger axel → vänster axel.
  Axelpunkterna ur Vision/MediaPipe ligger nära axellederna, så linjen är en
  **akromionlinje**, inte bröstkorgens (thorax) sidoaxel: den följer
  skulderbladen och armarna och ger några grader mer vid toppen.
- **X-factor** X(t) = θs(t) − θp(t); X vid toppen = X(t_topp).
- **Toppen** t_topp: där händernas mitt står högst mellan svingens start och
  träffen (S1:s definition). Forskningen använder ibland bäckenets vändning
  i stället (research 1 §1.8); den finns som `topp="backen"`.
- **Stretch** = max X i tidig nedsving − X vid toppen. Tidig nedsving =
  t_topp … t_topp + halva tiden till träffen. I grader, inte procent.
- **Öppna höfter vid träff** = −θp(t_träff). Träffen ges av klicket.
- **Adressen** = medel över `adress` (s), före svingens start.
"""
from __future__ import annotations

import numpy as np

from .sving import I


def linjevinkel(L: np.ndarray, R: np.ndarray, t: np.ndarray, adress: tuple, upp=(0, 0, 1)) -> np.ndarray:
    """Vridningen (grader) av linjen R → L i markplanet, mot adressen."""
    v = L - R
    upp = np.asarray(upp, float)
    if not np.allclose(upp, (0, 0, 1)):
        raise ValueError("bara markplanet z = 0 stöds")
    vin = np.arctan2(v[:, 1], v[:, 0])
    ok = np.isfinite(vin)
    a = (t >= adress[0]) & (t <= adress[1]) & ok
    if not a.any():
        return np.full(len(t), np.nan)
    ref = np.arctan2(np.mean(np.sin(vin[a])), np.mean(np.cos(vin[a])))
    # inom ±180° från adressen: ingen unwrap, så att en brusig ruta inte kan
    # lägga till ett helt varv (svingens vinklar ligger inom ±130°)
    return -np.degrees(np.angle(np.exp(1j * (vin - ref))))


def fyll_luckor(t: np.ndarray, y: np.ndarray) -> np.ndarray:
    """Linjär interpolation över NaN (en led som saknas i en vy ger ingen 3D-punkt)."""
    ok = np.isfinite(y)
    if ok.sum() < 2 or ok.all():
        return y
    return np.interp(t, t[ok], y[ok])


def vridningar(P: np.ndarray, t: np.ndarray, adress: tuple):
    p = linjevinkel(P[:, I["v_hoft"]], P[:, I["h_hoft"]], t, adress)
    s = linjevinkel(P[:, I["v_axel"]], P[:, I["h_axel"]], t, adress)
    return fyll_luckor(t, p), fyll_luckor(t, s)


def _vid(t, y, tid):
    ok = np.isfinite(y)
    if ok.sum() < 2 or not np.isfinite(tid):
        return float("nan")
    return float(np.interp(tid, t[ok], y[ok]))


def topptid(P: np.ndarray, t: np.ndarray, t_start: float, t_traff: float) -> float:
    z = 0.5 * (P[:, I["v_handled"], 2] + P[:, I["h_handled"], 2])
    f = (t >= t_start) & (t < t_traff) & np.isfinite(z)
    if not f.any():
        return float("nan")
    i = np.argmax(z[f])
    tt = t[f]
    zz = z[f]
    if 0 < i < len(zz) - 1:  # parabel genom toppen
        den = zz[i - 1] - 2 * zz[i] + zz[i + 1]
        if den < 0:
            return float(tt[i] + 0.5 * (zz[i - 1] - zz[i + 1]) / den * (tt[1] - tt[0]))
    return float(tt[i])


def jamna_kurva(t: np.ndarray, y: np.ndarray, halvbredd: float) -> np.ndarray:
    """Lokal andragradsregression (trikubisk kärna) av en vinkelkurva."""
    from .triangulering import jamna
    ut, _ = jamna(t, np.stack([y, np.zeros_like(y)], -1)[:, None, :], np.ones((len(t), 1)), t,
                  halvbredd, robust=False)
    return ut[:, 0, 0]


def svingmatt(P: np.ndarray, t: np.ndarray, t_start: float, t_traff: float, adress: tuple,
              topp: str = "hander", utjamna: float = 0.0) -> dict:
    """Måtten ur 3D-leder (T, 13, 3) på tidsaxeln t (jämn).

    `utjamna` > 0 jämnar vinkelkurvorna (halvbredd i s) innan måtten tas; det
    tar bort det mesta av brusets uppåtfel i stretchen (max av en brusig kurva).
    """
    p, s = vridningar(P, t, adress)
    if utjamna > 0:
        p, s = jamna_kurva(t, p, utjamna), jamna_kurva(t, s, utjamna)
    X = s - p
    if topp == "hander":
        tt = topptid(P, t, t_start, t_traff)
    else:
        f = (t >= t_start) & (t < t_traff) & np.isfinite(p)
        tt = float(t[f][np.argmax(p[f])])
    tidig = (t >= tt) & (t <= tt + 0.5 * (t_traff - tt)) & np.isfinite(X) if np.isfinite(tt) else np.zeros(len(t), bool)
    x_topp = _vid(t, X, tt)
    return {
        "t_topp": tt,
        "backen_topp": _vid(t, p, tt),
        "brost_topp": _vid(t, s, tt),
        "xfaktor_topp": x_topp,
        "stretch": float(np.max(X[tidig]) - x_topp) if tidig.any() else np.nan,
        "hofter_oppna_traff": -_vid(t, p, t_traff),
        "brost_traff": _vid(t, s, t_traff),
    }


MATT = ("backen_topp", "brost_topp", "xfaktor_topp", "stretch", "hofter_oppna_traff")


# --------------------------------------------------------------------------
# Utan triangulering, för jämförelsen (BESLUT B9)


def forkortning(uvL: np.ndarray, uvR: np.ndarray, t: np.ndarray, adress: tuple) -> np.ndarray:
    """En kamera framifrån (FO): vridningen ur linjens skenbara bredd,
    θ = arccos(|Δu| / |Δu_adress|). Tecknet går inte att se, så värdet är
    alltid ≥ 0 (bort från målet i baksvingen, öppen vid träff)."""
    du = np.abs(uvL[:, 0] - uvR[:, 0])
    a = (t >= adress[0]) & (t <= adress[1]) & np.isfinite(du)
    if not a.any():
        return np.full(len(t), np.nan)
    return np.degrees(np.arccos(np.clip(du / np.mean(du[a]), 0, 1)))


def bildmatt_tva_vyer(uvA_L, uvA_R, uvB_L, uvB_R, hogerA, hogerB, skalaA, skalaB, t, adress):
    """Två vyer utan kalibrering: varje bilds vågräta avstånd mellan punkterna
    (pixlar / skala = meter) är linjens komponent längs kamerans högerriktning
    (antagen, i marken). Två riktningar ger linjen i markplanet."""
    a = (uvA_L[:, 0] - uvA_R[:, 0]) / skalaA
    b = (uvB_L[:, 0] - uvB_R[:, 0]) / skalaB
    M = np.array([hogerA[:2], hogerB[:2]])
    v = np.linalg.solve(M, np.stack([a, b]))  # (2, T)
    vin = np.arctan2(v[1], v[0])
    f = (t >= adress[0]) & (t <= adress[1]) & np.isfinite(vin)
    ref = np.arctan2(np.mean(np.sin(vin[f])), np.mean(np.cos(vin[f])))
    return -np.degrees(np.angle(np.exp(1j * (vin - ref))))


def matt_ur_vinklar(t, p, s, tt, t_traff) -> dict:
    """Samma mått som `svingmatt` ur färdiga vinkelkurvor och given topptid."""
    X = s - p
    tidig = (t >= tt) & (t <= tt + 0.5 * (t_traff - tt)) & np.isfinite(X) if np.isfinite(tt) else np.zeros(len(t), bool)
    x_topp = _vid(t, X, tt)
    return {
        "backen_topp": _vid(t, p, tt),
        "brost_topp": _vid(t, s, tt),
        "xfaktor_topp": x_topp,
        "stretch": float(np.max(X[tidig]) - x_topp) if tidig.any() else np.nan,
        "hofter_oppna_traff": -_vid(t, p, t_traff),
    }
