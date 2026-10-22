"""Måtten i 3D: vridningen mot adressen, X-factor, stretch, öppna höfter."""
import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "pc"))

from tre_d import matt  # noqa: E402
from tre_d.sving import I  # noqa: E402


def linje(theta_deg, z=0.0, lutning=0.0):
    """En linje (L, R) i markplanet vriden theta medurs ovanifrån (bort från målet)."""
    th = np.radians(theta_deg)
    v = np.stack([np.cos(th), -np.sin(th), np.full_like(th, lutning)], -1) * 0.1
    mitt = np.array([0, 0, z])
    return mitt + v, mitt - v


class TestVinkel(unittest.TestCase):
    def test_vridningen_mot_adressen(self):
        t = np.linspace(0, 1, 101)
        th = np.where(t < 0.2, 5.0, 5.0 + 100 * (t - 0.2))
        L, R = linje(th)
        v = matt.linjevinkel(L, R, t, (0.0, 0.15))
        self.assertTrue(np.allclose(v, th - 5.0, atol=1e-9))

    def test_lutning_i_hojdled_paverkar_inte_projektionen(self):
        t = np.linspace(0, 1, 11)
        th = np.linspace(0, 60, 11)
        L, R = linje(th, lutning=0.7)
        self.assertTrue(np.allclose(matt.linjevinkel(L, R, t, (0, 0.05)), th, atol=1e-9))

    def test_ingen_varvhopp_vid_brusig_ruta(self):
        t = np.linspace(0, 1, 11)
        L, R = linje(np.zeros(11))
        L[5], R[5] = R[5].copy(), L[5].copy()  # en ruta med linjen åt fel håll
        v = matt.linjevinkel(L, R, t, (0, 0.2))
        self.assertLessEqual(np.abs(v).max(), 180.0)

    def test_forkortningen_for_ren_vridning(self):
        t = np.linspace(0, 1, 11)
        th = np.linspace(0, 80, 11)
        uvL = np.stack([100 * np.cos(np.radians(th)), np.zeros(11)], -1)
        uvR = -uvL
        self.assertTrue(np.allclose(matt.forkortning(uvL, uvR, t, (0, 0.05)), th, atol=1e-6))


class TestSvingmatt(unittest.TestCase):
    def test_x_factor_och_stretch_ur_konstruerade_kurvor(self):
        t = np.arange(0, 2, 0.001)
        tt, ti = 1.0, 1.3
        p = np.interp(t, [0, 0.3, tt - 0.03, tt + 0.05, ti, 2], [0, 0, 45, 38, -40, -40])
        s = np.interp(t, [0, 0.3, tt, tt + 0.05, ti, 2], [0, 0, 90, 91, -25, -25])
        P = np.zeros((len(t), 13, 3))
        P[:, I["v_hoft"]], P[:, I["h_hoft"]] = linje(p)
        P[:, I["v_axel"]], P[:, I["h_axel"]] = linje(s)
        hz = np.interp(t, [0, 0.3, tt, ti, 2], [0.8, 0.8, 1.8, 0.8, 1.8])
        P[:, I["v_handled"], 2] = hz
        P[:, I["h_handled"], 2] = hz
        m = matt.svingmatt(P, t, 0.3, ti, (0.0, 0.25))
        self.assertAlmostEqual(m["t_topp"], tt, places=2)
        self.assertAlmostEqual(m["backen_topp"], np.interp(tt, t, p), places=1)
        self.assertAlmostEqual(m["xfaktor_topp"], np.interp(tt, t, s - p), places=1)
        self.assertAlmostEqual(m["stretch"], 91 - 38 - m["xfaktor_topp"], delta=0.2)
        self.assertAlmostEqual(m["hofter_oppna_traff"], 40.0, places=1)


if __name__ == "__main__":
    unittest.main()
