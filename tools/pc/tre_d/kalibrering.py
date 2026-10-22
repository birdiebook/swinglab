"""Kalibreringen: yttre parametrar ur mattans punkter, eller ur lederna själva.

**Mot mattan (Pose2Sims väg, docs/research/2_teknik.md §2).** Inre parametrar
(K) kända från en ChArUco-kalibrering, med fel. Varje pass klickas (eller hittas
automatiskt) N kända punkter på mattan i båda vyerna. Ligger alla i marken
(z = 0) skattas läget ur en homografi (Zhang 2000; standard), annars med DLT
(Hartley & Zisserman kap. 7; standard). Båda förfinas med Levenberg–Marquardt
på återprojektionsfelet med K fast.

**Självkalibrering ur lederna (antagande, byggt på arXiv 2604.17567 och Lee
m.fl. 2022, ej lästa i original).** Samma leder i båda vyerna över hela
svingen ger tusentals par. Den relativa orienteringen skattas med
åttapunktsmetoden (normaliserad, viktad, Hartley 1997; standard) och förfinas
på Sampson-felet. Skalan blir okänd, men vinklar behöver ingen skala. Lodlinjen
kommer från telefonens accelerometer (gravitationen i kamerans ram) och
mållinjen behövs inte, eftersom vridningen mäts mot adressen.
"""
from __future__ import annotations

import numpy as np

from .kamera import Kamera, K_matris


# --------------------------------------------------------------------------
# Rotationer och optimering


def rodrigues(r: np.ndarray) -> np.ndarray:
    th = np.linalg.norm(r)
    if th < 1e-12:
        return np.eye(3)
    k = r / th
    Kx = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    return np.eye(3) + np.sin(th) * Kx + (1 - np.cos(th)) * Kx @ Kx


def slumprotation(sigma_deg: float, rng: np.random.Generator) -> np.ndarray:
    return rodrigues(np.radians(sigma_deg) * rng.standard_normal(3))


def lm(fun, p0: np.ndarray, iter: int = 40, eps: float = 1e-6) -> np.ndarray:
    """Levenberg–Marquardt med numerisk Jacobian. fun(p) → residualvektor."""
    p = np.asarray(p0, float).copy()
    r = fun(p)
    c = r @ r
    lam = 1e-3
    for _ in range(iter):
        J = np.empty((len(r), len(p)))
        for k in range(len(p)):
            dp = np.zeros_like(p)
            dp[k] = eps
            J[:, k] = (fun(p + dp) - r) / eps
        A = J.T @ J
        g = J.T @ r
        while True:
            steg = -np.linalg.solve(A + lam * np.diag(np.diag(A) + 1e-12), g)
            r2 = fun(p + steg)
            c2 = r2 @ r2
            if c2 < c:
                p += steg
                klart = (c - c2) < 1e-10 * max(c, 1e-30)
                r, c = r2, c2
                lam = max(lam * 0.3, 1e-12)
                break
            lam *= 10
            if lam > 1e10:
                return p
        if klart:
            break
    return p


# --------------------------------------------------------------------------
# Mot mattan


def mattpunkter(n: int, sida: float, hojd: bool = False, mitt=(0.0, -0.35)) -> np.ndarray:
    """N punkter på mattan i ett jämnt rutnät (sida × sida m) kring stansen.

    `hojd`: dessutom två lodräta pinnar i mattans bakre hörn med märken på
    0,5 och 1,0 m (fyra punkter ovan marken).
    """
    k = int(np.ceil(np.sqrt(n)))
    g = np.linspace(-sida / 2, sida / 2, k)
    xx, yy = np.meshgrid(g, g)
    pts = np.stack([xx.ravel(), yy.ravel()], -1)
    # ta hörnen först, sedan resten i spridd ordning
    ordning = np.argsort(-np.abs(pts).sum(1), kind="stable")
    pts = pts[ordning][:n]
    X = np.column_stack([pts[:, 0] + mitt[0], pts[:, 1] + mitt[1], np.zeros(len(pts))])
    if hojd:
        h = []
        for x in (-sida / 2, sida / 2):
            for z in (0.5, 1.0):
                h.append([x + mitt[0], sida / 2 + mitt[1], z])
        X = np.vstack([X, np.array(h)])
    return X


def _normalisering(p: np.ndarray) -> np.ndarray:
    m = p.mean(0)
    s = np.sqrt(2) / np.mean(np.linalg.norm(p - m, axis=1))
    return np.array([[s, 0, -s * m[0]], [0, s, -s * m[1]], [0, 0, 1]])


def homografi(X2: np.ndarray, uv: np.ndarray) -> np.ndarray:
    """Normaliserad DLT för H: uv ~ H · [X, Y, 1]."""
    T1, T2 = _normalisering(X2), _normalisering(uv)
    a = np.column_stack([X2, np.ones(len(X2))]) @ T1.T
    b = np.column_stack([uv, np.ones(len(uv))]) @ T2.T
    A = []
    for (x, y, w), (u, v, s) in zip(a, b):
        A.append([0, 0, 0, -s * x, -s * y, -s * w, v * x, v * y, v * w])
        A.append([s * x, s * y, s * w, 0, 0, 0, -u * x, -u * y, -u * w])
    _, _, Vh = np.linalg.svd(np.array(A))
    H = Vh[-1].reshape(3, 3)
    return np.linalg.inv(T2) @ H @ T1


def _narmaste_rotation(M: np.ndarray) -> np.ndarray:
    U, _, Vt = np.linalg.svd(M)
    R = U @ Vt
    if np.linalg.det(R) < 0:
        R = U @ np.diag([1, 1, -1]) @ Vt
    return R


def pose_ur_homografi(H: np.ndarray, K: np.ndarray):
    B = np.linalg.inv(K) @ H
    lam = 1.0 / np.linalg.norm(B[:, 0])
    if (lam * B[:, 2])[2] < 0:  # marken framför kameran
        lam = -lam
    r1, r2, t = lam * B[:, 0], lam * B[:, 1], lam * B[:, 2]
    R = _narmaste_rotation(np.column_stack([r1, r2, np.cross(r1, r2)]))
    return R, t


def dlt_pose(X: np.ndarray, uv: np.ndarray, K: np.ndarray):
    """DLT för P (minst 6 punkter, inte alla i ett plan), sedan R, t med K känd."""
    T2 = _normalisering(uv)
    m = X.mean(0)
    s3 = np.sqrt(3) / np.mean(np.linalg.norm(X - m, axis=1))
    T3 = np.diag([s3, s3, s3, 1.0])
    T3[:3, 3] = -s3 * m
    Xh = np.column_stack([X, np.ones(len(X))]) @ T3.T
    xh = np.column_stack([uv, np.ones(len(uv))]) @ T2.T
    A = []
    for Xi, (u, v, w) in zip(Xh, xh):
        A.append(np.concatenate([np.zeros(4), -w * Xi, v * Xi]))
        A.append(np.concatenate([w * Xi, np.zeros(4), -u * Xi]))
    _, _, Vh = np.linalg.svd(np.array(A))
    P = np.linalg.inv(T2) @ Vh[-1].reshape(3, 4) @ T3
    M = np.linalg.inv(K) @ P
    U, S, Vt = np.linalg.svd(M[:, :3])
    skala = S.mean() * np.sign(np.linalg.det(U @ Vt))
    R = _narmaste_rotation(M[:, :3] / skala)
    t = M[:, 3] / skala
    if (X @ R.T + t)[:, 2].mean() < 0:
        R, t = _narmaste_rotation(-M[:, :3] / skala), -t
    return R, t


def forfina_pose(K, R, t, X, uv):
    def res(p):
        Rk = rodrigues(p[:3]) @ R
        x = (X @ Rk.T + p[3:]) @ K.T
        return (x[:, :2] / x[:, 2:3] - uv).ravel()

    p = lm(res, np.concatenate([np.zeros(3), t]))
    return rodrigues(p[:3]) @ R, p[3:]


def kalibrera_mot_matta(K: np.ndarray, X: np.ndarray, uv: np.ndarray, namn: str = "") -> Kamera:
    if np.allclose(X[:, 2], 0) or len(X) < 6:
        plan = np.abs(X[:, 2]) < 1e-9
        R, t = pose_ur_homografi(homografi(X[plan, :2], uv[plan]), K)
    else:
        R, t = dlt_pose(X, uv, K)
    R, t = forfina_pose(K, R, t, X, uv)
    return Kamera(K=K, R=R, t=t, namn=namn)


def stord_K(K: np.ndarray, f_rel: float, c_px: float, rng: np.random.Generator) -> np.ndarray:
    """K med kalibreringsfel: brännvidd ±f_rel (relativt, 1σ), huvudpunkt ±c_px."""
    f = K[0, 0] * (1 + f_rel * rng.standard_normal())
    c = K[:2, 2] + c_px * rng.standard_normal(2)
    return K_matris(f, c[0], c[1])


# --------------------------------------------------------------------------
# Självkalibrering ur lederna


def _sampson(E, x1, x2):
    Ex1 = x1 @ E.T
    Etx2 = x2 @ E
    num = np.sum(x2 * Ex1, axis=1)
    den = Ex1[:, 0] ** 2 + Ex1[:, 1] ** 2 + Etx2[:, 0] ** 2 + Etx2[:, 1] ** 2
    return num / np.sqrt(np.maximum(den, 1e-18))


def _skev(t):
    return np.array([[0, -t[2], t[1]], [t[2], 0, -t[0]], [-t[1], t[0], 0]])


def atta_punkt(x1, x2, w):
    """Viktad, normaliserad åttapunktsmetod för E (x i normaliserade koordinater)."""
    T1, T2 = _normalisering(x1[:, :2]), _normalisering(x2[:, :2])
    a, b = x1 @ T1.T, x2 @ T2.T
    A = (b[:, :, None] * a[:, None, :]).reshape(len(a), 9) * w[:, None]
    _, _, Vh = np.linalg.svd(A, full_matrices=False)
    F = Vh[-1].reshape(3, 3)
    E = T2.T @ F @ T1
    U, _, Vt = np.linalg.svd(E)
    return U @ np.diag([1, 1, 0]) @ Vt


def _triangulera_par(R, t, x1, x2):
    P1 = np.hstack([np.eye(3), np.zeros((3, 1))])
    P2 = np.hstack([R, t[:, None]])
    A = np.stack([x1[:, 0:1] * P1[2] - P1[0], x1[:, 1:2] * P1[2] - P1[1],
                  x2[:, 0:1] * P2[2] - P2[0], x2[:, 1:2] * P2[2] - P2[1]], 1)
    _, _, Vh = np.linalg.svd(A)
    X = Vh[:, -1]
    return X[:, :3] / X[:, 3:4]


def dela_upp_E(E, x1, x2):
    """De fyra lösningarna; välj den där flest punkter ligger framför båda."""
    U, _, Vt = np.linalg.svd(E)
    if np.linalg.det(U) < 0:
        U = -U
    if np.linalg.det(Vt) < 0:
        Vt = -Vt
    W = np.array([[0, -1, 0], [1, 0, 0], [0, 0, 1]])
    bast, flest = None, -1
    for R in (U @ W @ Vt, U @ W.T @ Vt):
        for t in (U[:, 2], -U[:, 2]):
            X = _triangulera_par(R, t, x1, x2)
            fram = np.sum((X[:, 2] > 0) & ((X @ R.T + t)[:, 2] > 0))
            if fram > flest:
                bast, flest = (R, t), fram
    return bast


def relativ_orientering(x1, x2, w, f_px: float = 1444.0, varv: int = 3):
    """R, t (|t| = 1) från kamera 1 till kamera 2 ur normaliserade punktpar."""
    vikt = w.copy()
    for _ in range(varv):
        E = atta_punkt(x1, x2, vikt)
        r = np.abs(_sampson(E, x1, x2)) * f_px
        s = 1.4826 * np.median(r) + 1e-9
        vikt = w / (1 + (r / (2.5 * s)) ** 2)
    R0, t0 = dela_upp_E(E, x1, x2)

    def param_t(a):
        return np.array([np.sin(a[0]) * np.cos(a[1]), np.sin(a[0]) * np.sin(a[1]), np.cos(a[0])])

    th = np.arccos(np.clip(t0[2], -1, 1))
    ph = np.arctan2(t0[1], t0[0])
    sv = np.sqrt(vikt)

    def res(p):
        R = rodrigues(p[:3]) @ R0
        t = param_t(p[3:])
        return sv * _sampson(_skev(t) @ R, x1, x2) * f_px

    for _ in range(2):
        p = lm(res, np.array([0, 0, 0, th, ph]), iter=30)
        R0 = rodrigues(p[:3]) @ R0
        th, ph = p[3], p[4]
        r = np.abs(_sampson(_skev(param_t(p[3:])) @ R0, x1, x2)) * f_px
        s = 1.4826 * np.median(r) + 1e-9
        vikt = w / (1 + (r / (2.5 * s)) ** 2)
        sv = np.sqrt(vikt)
    return R0, param_t(np.array([th, ph]))


def sjalvkalibrera(KA, uvA, kA, KB, uvB, kB, upp_A: np.ndarray, min_konf: float = 0.5,
                   max_par: int = 3000, rng=None):
    """Två kameror i en värld där z är lodrät (ur `upp_A`, lodlinjen i kamera
    A:s ram) och origo ligger i kamera A. Skalan är godtycklig (|baslinje| = 1).

    uvA, uvB (M, J, 2) på samma tidsaxel; kA, kB konfidenser.
    """
    R, t, _ = relativ_ur_leder(KA, uvA, kA, KB, uvB, kB, min_konf, max_par, rng)
    return varld(KA, KB, R, t, upp_A)


def relativ_ur_leder(KA, uvA, kA, KB, uvB, kB, min_konf: float = 0.5, max_par: int = 3000, rng=None):
    """Kamera B:s läge mot A (x_B = R x_A + t, |t| = 1) ur ledernas punktpar, och
    Sampson-felets median i pixlar (kalibreringens kvalitet)."""
    ok = np.isfinite(uvA).all(-1) & np.isfinite(uvB).all(-1) & (kA > min_konf) & (kB > min_konf)
    a, b = uvA[ok], uvB[ok]
    w = np.sqrt(kA[ok] * kB[ok])
    if len(a) < 8:
        raise ValueError("för få punktpar för självkalibreringen")
    if len(a) > max_par:
        rng = rng or np.random.default_rng(0)
        val = rng.choice(len(a), max_par, replace=False)
        a, b, w = a[val], b[val], w[val]
    x1 = np.column_stack([a, np.ones(len(a))]) @ np.linalg.inv(KA).T
    x2 = np.column_stack([b, np.ones(len(b))]) @ np.linalg.inv(KB).T
    R, t = relativ_orientering(x1, x2, w, f_px=KA[0, 0])
    sampson = float(np.median(np.abs(_sampson(_skev(t) @ R, x1, x2)))) * KA[0, 0]
    return R, t, sampson


def upp_ur_vagrata(R: np.ndarray) -> np.ndarray:
    """Lodlinjen i A:s ram när båda kamerorna står utan lutning åt sidan: bildernas
    x-axlar ligger då båda i markplanet, och uppåt är vinkelrät mot dem. Tecknet
    väljs så att uppåt pekar mot bildens överkant (−y). METOD MK3"""
    xA = np.array([1.0, 0.0, 0.0])
    xB = R.T @ np.array([1.0, 0.0, 0.0])
    u = np.cross(xA, xB)
    n = np.linalg.norm(u)
    if n < 0.2:                        # kamerorna nästan parallella: riktningen är obestämd
        raise ValueError("kamerorna står för nära samma riktning för lodlinjen ur bilderna")
    u = u / n
    return u if u[1] < 0 else -u


def varld(KA, KB, R: np.ndarray, t: np.ndarray, upp_A: np.ndarray):
    """Kamerorna i en värld där z är `upp_A` (A:s ram) och x är A:s blickriktning i
    markplanet; origo i kamera A."""
    z = upp_A / np.linalg.norm(upp_A)
    f = np.array([0.0, 0.0, 1.0]) - z[2] * z
    x = f / np.linalg.norm(f)
    y = np.cross(z, x)
    B = np.column_stack([x, y, z])  # världens axlar i A:s ram → R_A = B
    kamA = Kamera(K=KA, R=B, t=np.zeros(3), namn="A")
    kamB = Kamera(K=KB, R=R @ B, t=t, namn="B")
    return kamA, kamB
