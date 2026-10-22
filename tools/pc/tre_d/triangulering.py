"""Utjämning på ojämna tider, viktad DLT-triangulering och synkens finjustering.

Ordningen (S6_FELBUDGET.md §4):

1. Varje kameras 2D-spår jämnas ut och samplas om till en gemensam tidsaxel,
   på rutornas egna tider (36 % saknas, ojämnt). Lokal andragradsregression
   med trikubisk kärna, viktad med konfidensen, och ett robust varv
   (bisquare) som tar bort utliggarna. Det är LOESS (Cleveland 1979;
   standard).
2. Synkfelet efter klicket (±7 ms) finjusteras: antingen korskorrelation av
   handledernas fart i 2D (som OpenCap och Pose2Sim, docs/research/2_teknik.md
   §2) eller genom att välja den förskjutning som ger minst
   återprojektionsfel för de snabba lederna (egen metod, antagande).
3. Lederna trianguleras per tidpunkt med DLT i normaliserade koordinater
   (Hartley & Zisserman kap. 12; standard), där varje kameras rader vägs med
   konfidensen.
"""
from __future__ import annotations

import warnings

import numpy as np


def _trikub(d: np.ndarray) -> np.ndarray:
    a = np.clip(1 - np.abs(d) ** 3, 0, None)
    return a ** 3


class _Band:
    """Kärnans vikter från t_in till t_ut, bara inom ±h (bandmatris)."""

    def __init__(self, t_in: np.ndarray, t_ut: np.ndarray, h: float):
        lo = np.searchsorted(t_in, t_ut - h, side="left")
        hi = np.searchsorted(t_in, t_ut + h, side="right")
        bredd = max(int((hi - lo).max()), 1)
        idx = lo[:, None] + np.arange(bredd)[None, :]
        inne = idx < hi[:, None]
        self.idx = np.minimum(idx, len(t_in) - 1)
        self.d = np.where(inne, (t_in[self.idx] - t_ut[:, None]) / h, 0.0)
        self.K = np.where(inne, _trikub(self.d), 0.0)


def _lokal_kvadrat(band: _Band, y: np.ndarray, w: np.ndarray) -> np.ndarray:
    """Kärnviktad lokal andragradsregression för alla leder på en gång.

    y (N, J, D), w (N, J) → (M, J, D); NaN där färre än tre punkter bär.
    """
    yg = y[band.idx]  # (M, B, J, D)
    ok = np.isfinite(yg).all(-1)
    W = band.K[:, :, None] * w[band.idx] * ok  # (M, B, J)
    yg = np.where(ok[..., None], yg, 0.0)
    d = band.d[:, :, None]
    S = [np.sum(W * d ** k, axis=1) for k in range(5)]  # (M, J)
    A = np.stack([np.stack([S[0], S[1], S[2]], -1), np.stack([S[1], S[2], S[3]], -1),
                  np.stack([S[2], S[3], S[4]], -1)], -2)  # (M, J, 3, 3)
    B = np.stack([np.sum((W * d ** k)[..., None] * yg, axis=1) for k in range(3)], -2)  # (M, J, 3, D)
    A = A + np.eye(3) * (1e-9 * np.maximum(S[0], 1e-12))[..., None, None]
    bar = (W > 0).sum(axis=1) >= 3
    ut = np.full(bar.shape + (y.shape[-1],), np.nan)
    if bar.any():
        ut[bar] = np.linalg.solve(A[bar], B[bar])[:, 0, :]
    return ut


def jamna(t_in: np.ndarray, uv: np.ndarray, konf: np.ndarray, t_ut: np.ndarray,
          halvbredd: float = 0.02, robust: bool = True):
    """Jämna ut och sampla om 2D-spår. uv (N, J, 2), konf (N, J).

    Returnerar uv (M, J, 2) och konfidens (M, J) på `t_ut`. Konfidensen på
    utdata är kärnviktat medel av indata; NaN där underlaget är för tunt.
    """
    w = np.where(np.isfinite(uv).all(-1), konf, 0.0)
    w0 = w
    if robust:
        # LOESS med robusta varv (Cleveland 1979): bisquare på residualerna,
        # skala = MAD med golv 2 px (utan brus är MAD noll)
        b_in = _Band(t_in, t_in, halvbredd)
        for _ in range(2):
            f_in = _lokal_kvadrat(b_in, uv, w)
            r = np.linalg.norm(uv - f_in, axis=-1)
            with warnings.catch_warnings():
                warnings.simplefilter("ignore", RuntimeWarning)
                mad = np.nanmedian(np.where(w0 > 0, r, np.nan), axis=0)
            mad = np.where(np.isfinite(mad), mad, 2.0)
            u = r / (6 * np.maximum(mad, 2.0))
            w = w0 * np.where(np.isfinite(u), np.clip(1 - u ** 2, 0, None) ** 2, 1.0)
    band = _Band(t_in, t_ut, halvbredd)
    ut = _lokal_kvadrat(band, uv, w)
    if robust:  # där de robusta vikterna lämnat för lite: den vanliga skattningen
        lucka = ~np.isfinite(ut).all(-1)
        if lucka.any():
            ut[lucka] = _lokal_kvadrat(band, uv, w0)[lucka]
    Ksum = band.K.sum(1)[:, None]
    kut = np.where(Ksum > 0, np.sum(band.K[:, :, None] * w[band.idx], axis=1) / np.maximum(Ksum, 1e-12), 0.0)
    kut[~np.isfinite(ut).all(axis=-1)] = 0.0
    return ut, kut


def triangulera(kameror, uv: np.ndarray, vikt: np.ndarray) -> np.ndarray:
    """Viktad DLT. uv (C, M, J, 2) pixlar, vikt (C, M, J). → (M, J, 3).

    Varje kameras två rader multipliceras med dess vikt. Punkter med färre än
    två kameror med vikt > 0 blir NaN.
    """
    C, M, J, _ = uv.shape
    rader = []
    giltig = np.zeros((M, J), int)
    for c, kam in enumerate(kameror):
        Kinv = np.linalg.inv(kam.K)
        Pn = np.hstack([kam.R, kam.t[:, None]])
        x = np.concatenate([uv[c], np.ones((M, J, 1))], -1) @ Kinv.T
        ok = np.isfinite(x).all(-1) & (vikt[c] > 0)
        giltig += ok
        w = np.where(ok, vikt[c], 0.0)[..., None]
        x = np.where(ok[..., None], x, 0.0)
        r1 = x[..., 0:1] * Pn[2] - Pn[0]
        r2 = x[..., 1:2] * Pn[2] - Pn[1]
        rader += [w * r1, w * r2]
    A = np.stack(rader, -2)  # (M, J, 2C, 4)
    _, _, Vh = np.linalg.svd(A)
    X = Vh[..., -1, :]
    with np.errstate(divide="ignore", invalid="ignore"):
        P = X[..., :3] / X[..., 3:4]
    P[giltig < 2] = np.nan
    return P


def aterprojektionsfel(kameror, P: np.ndarray, uv: np.ndarray) -> np.ndarray:
    """(C, M, J) pixelfel mellan 3D-punkterna och observationerna."""
    return np.stack([np.linalg.norm(k.projicera(P) - uv[c], axis=-1) for c, k in enumerate(kameror)])


# --------------------------------------------------------------------------
# Synk


def _parabel_topp(x: np.ndarray, y: np.ndarray, i: int) -> float:
    if 0 < i < len(y) - 1:
        y0, y1, y2 = y[i - 1], y[i], y[i + 1]
        den = y0 - 2 * y1 + y2
        if den != 0:
            return float(x[i] + 0.5 * (y0 - y2) / den * (x[1] - x[0]))
    return float(x[i])


def synk_fart(tA, uvA, kA, tB, uvB, kB, leder, fonster, sok=0.03, steg=0.0005, halvbredd=0.02):
    """Hur mycket B:s klocka går före A:s (s; dra av från B:s tider), ur
    korskorrelation av den lodräta farten i bilden för `leder` inom `fonster`
    (t0, t1). Som Pose2Sim (lodrät fart, som syns lika i båda vyerna när
    kamerorna står plant) och OpenCaps utilsSync, men på ojämna tider och med
    delrutor."""
    t_fin = np.arange(fonster[0] - sok - 0.05, fonster[1] + sok + 0.05, steg)
    a, _ = jamna(tA, uvA[:, leder], kA[:, leder], t_fin, halvbredd, robust=True)
    b, _ = jamna(tB, uvB[:, leder], kB[:, leder], t_fin, halvbredd, robust=True)
    fa = np.nansum(np.abs(np.gradient(a[..., 1], steg, axis=0)), axis=1)
    fb = np.nansum(np.abs(np.gradient(b[..., 1], steg, axis=0)), axis=1)
    inne = (t_fin >= fonster[0]) & (t_fin <= fonster[1])
    lags = np.arange(-int(sok / steg), int(sok / steg) + 1)
    idx = np.where(inne)[0]
    x = fa[idx] - fa[idx].mean()
    kor = []
    for L in lags:
        y = fb[idx + L]
        y = y - y.mean()
        kor.append(float(x @ y / (np.linalg.norm(x) * np.linalg.norm(y) + 1e-12)))
    kor = np.array(kor)
    i = int(np.argmax(kor))
    # B:s signal vid B-tiden t + L·steg motsvarar A vid t → B:s klocka går L·steg före
    return _parabel_topp(lags * steg, kor, i)


def synk_reprojektion(kameror, tA, uvA, kA, tB, uvB, kB, leder, fonster, sok=0.03, steg=0.0005,
                      halvbredd=0.02):
    """Hur mycket B:s klocka går före A:s (s), vald som den förskjutning som
    ger minst återprojektionsfel för `leder` (de
    snabba, handlederna och armbågarna) inom `fonster`."""
    t_fin = np.arange(fonster[0] - sok - 0.05, fonster[1] + sok + 0.05, steg)
    a, ka = jamna(tA, uvA[:, leder], kA[:, leder], t_fin, halvbredd)
    b, kb = jamna(tB, uvB[:, leder], kB[:, leder], t_fin, halvbredd)
    inne = np.where((t_fin >= fonster[0]) & (t_fin <= fonster[1]))[0][::4]
    lags = np.arange(-int(sok / steg), int(sok / steg) + 1, 2)
    kost = []
    for L in lags:
        uv = np.stack([a[inne], b[inne + L]])
        w = np.stack([ka[inne], kb[inne + L]])
        P = triangulera(kameror, uv, w)
        e = aterprojektionsfel(kameror, P, uv)
        kost.append(float(np.nanmedian(e)))
    kost = np.array(kost)
    i = int(np.nanargmin(kost))
    return _parabel_topp(lags * steg, -kost, i)
