"""Hela kedjan: utan fel blir måtten rätt, och felen växer åt rätt håll."""
import sys
import unittest
from dataclasses import replace
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "pc"))

from tre_d import felbudget as fb  # noqa: E402
from tre_d import matt  # noqa: E402

REN = fb.Uppstallning(brus="inget", synkfel_ms=0.0, synk="perfekt", kalib="perfekt", tapp=0.0,
                      skymning=False, exponering=0.0)


class TestKedjan(unittest.TestCase):
    def test_utan_fel_ar_kedjan_exakt(self):
        r = fb.forsok(REN, np.random.default_rng(1))
        for k in matt.MATT:
            self.assertLess(abs(r["3d"][k]), 0.5, k)

    def test_tappade_rutor_skymning_och_synk_utan_brus(self):
        u = replace(REN, tapp=0.36, skymning=True, synkfel_ms=7.0, synk="reprojektion", kalib="matta",
                    matt_klick_px=0.0, matt_varld_m=0.0, f_rel=0.0, c_px=0.0)
        r = fb.forsok(u, np.random.default_rng(2))
        self.assertLess(abs(r["synk_rest_ms"]), 1.0)
        for k in matt.MATT:
            self.assertLess(abs(r["3d"][k]), 1.0, k)

    def test_sjalvkalibreringen_utan_brus(self):
        u = replace(REN, kalib="sjalv", grav_deg=0.0, f_rel=0.0, c_px=0.0)
        r = fb.forsok(u, np.random.default_rng(3))
        for k in matt.MATT:
            self.assertLess(abs(r["3d"][k]), 1.0, k)

    def test_mer_brus_ger_storre_fel(self):
        bra = fb.monte_carlo(replace(REN, brus="bra"), 6, seed=4)["3d"]["brost_topp"]["rmse"]
        daligt = fb.monte_carlo(replace(REN, brus="mycket_daligt"), 6, seed=4)["3d"]["brost_topp"]["rmse"]
        self.assertLess(bra, daligt)

    def test_en_kamera_ar_samre_an_tva_for_brostet(self):
        res = fb.monte_carlo(replace(REN, brus="bra", tapp=0.36), 6, seed=5, metoder=("3d", "fo_en"))
        self.assertLess(res["3d"]["xfaktor_topp"]["rmse"], res["fo_en"]["xfaktor_topp"]["rmse"])


class TestFacit(unittest.TestCase):
    def test_pinnen_mater_brostkorgen(self):
        r = fb.facit_forsok(replace(REN, kalib="matta"), np.random.default_rng(6), vinklar=(90.0,))
        self.assertLess(abs(r[90.0]["pinne_mot_thorax"]), 1.5)
        self.assertLess(abs(r[90.0]["axel_matfel"]), 0.5)

    def test_definitionerna_skiljer(self):
        d = fb.definitioner()["topp"]
        # Euler-vinkeln > akromionlinjen > bröstkorgens sidoaxel i modellen
        self.assertGreater(d["brost_euler"], d["axel_linje"])
        self.assertGreater(d["axel_linje"], d["thorax_linje"])
        self.assertGreater(d["x_euler"] - d["x_thorax"], 10.0)


if __name__ == "__main__":
    unittest.main()
