"""Kamerorna: projektion, placering, bildtider och skymning."""
import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "pc"))

from tre_d import kamera as km  # noqa: E402
from tre_d.sving import I, Sving  # noqa: E402


class TestKamera(unittest.TestCase):
    def test_siktpunkten_hamnar_mitt_i_bilden(self):
        k = km.placera(270, 3.0, 1.0)
        uv = k.projicera(km.SIKTE)
        self.assertTrue(np.allclose(uv, [km.BREDD / 2, km.HOJD / 2]))

    def test_dtl_har_bollen_till_hoger_och_upp_uppat(self):
        k = km.placera(180, 3.0, 1.0)
        self.assertTrue(np.allclose(k.R[0], [0, -1, 0], atol=0.06))  # höger i bilden = mot bollen (−y)
        hog = k.projicera(np.array([0.0, -0.15, 1.5]))
        lag = k.projicera(np.array([0.0, -0.15, 0.5]))
        self.assertLess(hog[1], lag[1])  # högre punkt = mindre v

    def test_synfaltet(self):
        # 1444 px på halva höjden 960 px ger cirka 67° på långsidan
        self.assertAlmostEqual(2 * np.degrees(np.arctan(960 / km.F_PX)), 67.2, delta=0.5)

    def test_tappade_rutor_ungefar_36_procent(self):
        rng = np.random.default_rng(1)
        t = km.bildtider(60.0, rng)
        self.assertAlmostEqual(1 - len(t) / (60 * km.FPS), 0.36, delta=0.03)
        self.assertTrue(np.all(np.diff(t) > 0))

    def test_utan_brus_ar_observationen_projektionen(self):
        s = Sving()
        k = km.placera(270, 3.0, 1.0)
        rng = np.random.default_rng(2)
        t = km.bildtider(s.t_slut, rng)
        obs, konf, _ = km.observera(k, s, t, km.BRUS["inget"], rng, exponering=0.0)
        self.assertTrue(np.allclose(obs, k.projicera(s.leder(t)), equal_nan=True))
        self.assertTrue(np.all((konf > 0) & (konf <= 1)))

    def test_skymningen_ser_den_bortre_hoften_bakom_kroppen_i_dtl(self):
        s = Sving()
        P = s.leder(np.array([0.1]))
        sky = km.skymda(km.placera(180, 3.0, 1.0), P)
        self.assertFalse(sky[0, I["h_hoft"]])  # närmaste höften syns
        self.assertFalse(sky[0, I["nasa"]])


if __name__ == "__main__":
    unittest.main()
