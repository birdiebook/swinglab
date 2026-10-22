"""Den påhittade svingen: kroppen håller ihop och storlekarna är rimliga."""
import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "pc"))

from tre_d import matt  # noqa: E402
from tre_d.sving import I, LEDER, Sving, pchip, segment_rotation, slumpa_sving  # noqa: E402


class TestKurvor(unittest.TestCase):
    def test_pchip_gar_genom_nyckelbilderna_och_haller_toppen(self):
        x = np.array([0.0, 1.0, 2.0, 3.0])
        y = np.array([0.0, 5.0, 4.0, -2.0])
        self.assertTrue(np.allclose(pchip(x, y, x), y))
        t = np.linspace(0, 3, 3001)
        f = pchip(x, y, t)
        self.assertAlmostEqual(t[np.argmax(f)], 1.0, places=2)  # ingen översväng
        self.assertLessEqual(f.max(), 5.0 + 1e-9)

    def test_rotationen_ar_ortonormal(self):
        R = segment_rotation(np.array([30.0, -80.0]), np.array([35.0, 10.0]), np.array([-10.0, 25.0]))
        for r in R:
            self.assertTrue(np.allclose(r @ r.T, np.eye(3)))
            self.assertAlmostEqual(np.linalg.det(r), 1.0)


class TestSvingen(unittest.TestCase):
    def setUp(self):
        self.s = Sving()
        self.t = np.arange(0.05, self.s.t_slut - 0.05, 0.001)
        self.P = self.s.leder(self.t)

    def test_tretton_leder_utan_nan(self):
        self.assertEqual(self.P.shape[1:], (13, 3))
        self.assertEqual(len(LEDER), 13)
        self.assertFalse(np.isnan(self.P).any())

    def test_lankarna_har_fast_langd(self):
        for a, b in (("v_axel", "v_armbage"), ("v_armbage", "v_handled"), ("h_axel", "h_armbage"),
                     ("h_armbage", "h_handled"), ("v_hoft", "v_kna"), ("v_kna", "v_fotled"),
                     ("h_hoft", "h_kna"), ("h_kna", "h_fotled"), ("v_hoft", "h_hoft")):
            d = np.linalg.norm(self.P[:, I[a]] - self.P[:, I[b]], axis=1)
            self.assertLess(d.max() - d.min(), 1e-6, f"{a}–{b}")

    def test_fotterna_star_still_och_ingen_led_under_marken(self):
        self.assertLess(np.ptp(self.P[:, I["v_fotled"]], axis=0).max(), 1e-9)
        self.assertGreater(self.P[..., 2].min(), 0.0)

    def test_storlekarna_ur_research_1(self):
        adress = (0.05, self.s.t_start - 0.05)
        m = matt.svingmatt(self.P, self.t, self.s.t_start, self.s.t_traff, adress)
        self.assertTrue(38 <= m["backen_topp"] <= 47, m["backen_topp"])
        self.assertTrue(82 <= m["brost_topp"] <= 96, m["brost_topp"])
        self.assertTrue(35 <= m["xfaktor_topp"] <= 55, m["xfaktor_topp"])
        self.assertTrue(3 <= m["stretch"] <= 12, m["stretch"])
        self.assertTrue(33 <= m["hofter_oppna_traff"] <= 45, m["hofter_oppna_traff"])
        self.assertLess(abs(m["t_topp"] - self.s.t_topp), 0.03)

    def test_slumpade_svingar_haller_sig_i_spannet(self):
        rng = np.random.default_rng(0)
        for _ in range(5):
            s = slumpa_sving(rng)
            t = np.arange(0.05, s.t_slut - 0.05, 0.002)
            m = matt.svingmatt(s.leder(t), t, s.t_start, s.t_traff, (0.05, s.t_start - 0.05))
            self.assertTrue(30 <= m["backen_topp"] <= 55)
            self.assertTrue(70 <= m["brost_topp"] <= 105)
            self.assertTrue(25 <= m["hofter_oppna_traff"] <= 50)


if __name__ == "__main__":
    unittest.main()
