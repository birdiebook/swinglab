"""Utjämningen på ojämna tider, trianguleringen och synkens finjustering."""
import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "pc"))

from tre_d import kamera as km  # noqa: E402
from tre_d import triangulering as tri  # noqa: E402
from tre_d.sving import I, Sving  # noqa: E402


class TestJamna(unittest.TestCase):
    def test_andragradskurva_aterges_exakt_pa_ojamna_tider(self):
        rng = np.random.default_rng(0)
        t_in = np.sort(rng.uniform(0, 1, 150))
        y = np.stack([3 * t_in ** 2 - t_in + 2, -t_in], -1)[:, None, :]
        t_ut = np.linspace(0.1, 0.9, 50)
        ut, k = tri.jamna(t_in, y, np.ones((150, 1)), t_ut, 0.05)
        sann = np.stack([3 * t_ut ** 2 - t_ut + 2, -t_ut], -1)
        self.assertTrue(np.allclose(ut[:, 0], sann, atol=1e-8))
        self.assertTrue(np.allclose(k, 1))

    def test_robust_tar_bort_utliggare(self):
        t_in = np.arange(0, 1, 1 / 240)
        y = np.zeros((len(t_in), 1, 2))
        y[100, 0] = [80.0, -60.0]
        ut, _ = tri.jamna(t_in, y, np.ones((len(t_in), 1)), t_in, 0.02)
        self.assertLess(np.abs(ut).max(), 1.0)

    def test_for_glest_ger_nan(self):
        t_in = np.array([0.0, 0.5, 1.0])
        ut, k = tri.jamna(t_in, np.zeros((3, 1, 2)), np.ones((3, 1)), np.array([0.25]), 0.02)
        self.assertTrue(np.isnan(ut).all())
        self.assertEqual(k[0, 0], 0.0)


class TestTriangulera(unittest.TestCase):
    def test_exakt_utan_brus(self):
        s = Sving()
        t = np.linspace(0.1, 2.0, 40)
        P = s.leder(t)
        kam = [km.placera(270, 3.0, 1.0), km.placera(180, 3.0, 1.0)]
        uv = np.stack([k.projicera(P) for k in kam])
        X = tri.triangulera(kam, uv, np.ones(uv.shape[:3]))
        self.assertLess(np.abs(X - P).max(), 1e-8)

    def test_en_vy_ger_nan(self):
        kam = [km.placera(270, 3.0, 1.0), km.placera(180, 3.0, 1.0)]
        uv = np.stack([k.projicera(np.zeros((1, 1, 3)) + [0, 0, 1.0]) for k in kam])
        w = np.ones(uv.shape[:3])
        w[1] = 0
        self.assertTrue(np.isnan(tri.triangulera(kam, uv, w)).all())


class TestSynk(unittest.TestCase):
    def test_reprojektionen_hittar_forskjutningen(self):
        s = Sving()
        rng = np.random.default_rng(4)
        kam = [km.placera(270, 3.0, 1.0), km.placera(180, 3.0, 1.0)]
        tA = km.bildtider(s.t_slut, rng)
        tB = km.bildtider(s.t_slut, rng)
        oA = kam[0].projicera(s.leder(tA))
        oB = kam[1].projicera(s.leder(tB))
        kA, kB = np.ones(oA.shape[:2]), np.ones(oB.shape[:2])
        delta = 0.0052
        leder = [I["v_handled"], I["h_handled"], I["v_armbage"], I["h_armbage"]]
        f = (s.t_traff - 0.35, s.t_traff + 0.1)
        d = tri.synk_reprojektion(kam, tA, oA, kA, tB + delta, oB, kB, leder, f, sok=0.012, halvbredd=0.02)
        self.assertLess(abs(d - delta), 0.0007)
        d2 = tri.synk_fart(tA, oA, kA, tB + delta, oB, kB, leder, f, sok=0.012, halvbredd=0.02)
        self.assertLess(abs(d2 - delta), 0.008)  # farten ser olika ut i vyerna: några ms fel
        self.assertLess(abs(d - delta), abs(d2 - delta))


if __name__ == "__main__":
    unittest.main()
