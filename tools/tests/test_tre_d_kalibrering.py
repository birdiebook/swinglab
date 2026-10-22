"""Kalibreringen: mot mattan (homografi, DLT) och ur lederna (åttapunkt)."""
import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "pc"))

from tre_d import kalibrering as kal  # noqa: E402
from tre_d import kamera as km  # noqa: E402
from tre_d.sving import Sving  # noqa: E402


def vinkel_mellan(R1, R2):
    return np.degrees(np.arccos(np.clip((np.trace(R1 @ R2.T) - 1) / 2, -1, 1)))


class TestMattan(unittest.TestCase):
    def test_homografin_ger_kameran_ur_exakta_punkter(self):
        k = km.placera(180, 3.0, 1.0)
        X = kal.mattpunkter(10, 1.5)
        self.assertTrue(np.allclose(X[:, 2], 0))
        e = kal.kalibrera_mot_matta(k.K, X, k.projicera(X))
        self.assertLess(vinkel_mellan(e.R, k.R), 1e-4)
        self.assertLess(np.linalg.norm(e.centrum - k.centrum), 1e-4)

    def test_dlt_med_punkter_ovan_marken(self):
        k = km.placera(270, 3.0, 1.2)
        X = kal.mattpunkter(10, 1.5, hojd=True)
        self.assertGreater(X[:, 2].max(), 0.9)
        e = kal.kalibrera_mot_matta(k.K, X, k.projicera(X))
        self.assertLess(vinkel_mellan(e.R, k.R), 1e-4)

    def test_klickfel_ger_litet_fel(self):
        rng = np.random.default_rng(3)
        k = km.placera(180, 3.0, 1.0)
        X = kal.mattpunkter(10, 1.5)
        e = kal.kalibrera_mot_matta(k.K, X, k.projicera(X) + 1.0 * rng.standard_normal((len(X), 2)))
        self.assertLess(vinkel_mellan(e.R, k.R), 1.0)

    def test_lm_hittar_minimum(self):
        p = kal.lm(lambda p: np.array([p[0] - 1, 10 * (p[1] - p[0] ** 2)]), np.array([-1.0, 1.0]), iter=200)
        self.assertTrue(np.allclose(p, [1, 1], atol=1e-4))


class TestSjalvkalibrering(unittest.TestCase):
    def test_relativ_orientering_ur_lederna_utan_brus(self):
        s = Sving()
        t = np.arange(0.05, s.t_slut - 0.05, 1 / 120)
        P = s.leder(t)
        A, B = km.placera(270, 3.0, 1.0), km.placera(180, 3.0, 1.0)
        uvA, uvB = A.projicera(P), B.projicera(P)
        k = np.ones(uvA.shape[:2])
        upp = A.R @ np.array([0, 0, 1.0])
        eA, eB = kal.sjalvkalibrera(A.K, uvA, k, B.K, uvB, k, upp)
        R_rel_sann = B.R @ A.R.T
        R_rel = eB.R @ eA.R.T
        self.assertLess(vinkel_mellan(R_rel, R_rel_sann), 0.05)
        # världens z är lodrät
        self.assertTrue(np.allclose(eA.R.T @ upp, [0, 0, 1], atol=1e-9))


if __name__ == "__main__":
    unittest.main()
