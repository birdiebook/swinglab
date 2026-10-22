"""Utjämningen och faserna (METOD M3, M4) på ojämna tider."""
from __future__ import annotations

import math
import unittest

import numpy as np

from _hjalp import gen
from pc import faser as F


def _ojamna(n: int = 600, seed: int = 0) -> np.ndarray:
    rng = np.random.default_rng(seed)
    t = np.arange(n) / 240.0
    return t[rng.random(n) >= 0.36]


class Utjamning(unittest.TestCase):
    def test_konstant_och_linjar_bevaras_pa_ojamna_tider(self) -> None:
        t = _ojamna()
        y = np.stack([np.full_like(t, 7.0), 3.0 * t + 1.0], -1)
        j = F.jamna(t, y)
        np.testing.assert_allclose(j[:, 0], 7.0)
        mitt = (t > 0.1) & (t < t[-1] - 0.1)                   # kanterna är ensidiga
        # Luckorna gör vikterna osymmetriska: en linje förskjuts högst ~5 ms (uppmätt 4 ms).
        np.testing.assert_allclose(j[mitt, 1], 3.0 * t[mitt] + 1.0, atol=3.0 * 0.005)

    def test_saknade_varden_fylls_av_grannarna_men_inte_over_langre_luckor(self) -> None:
        t = np.arange(200) / 240.0
        y = np.ones((200, 1))
        y[50:52] = np.nan                                       # 8 ms: fylls
        y[100:140] = np.nan                                     # 167 ms: mitten förblir tom
        j = F.jamna(t, y)
        self.assertTrue(np.isfinite(j[50:52]).all())
        self.assertTrue(np.isnan(j[115:125]).all())

    def test_vid_interpolerar_och_vagrar_over_lucka(self) -> None:
        t = np.array([0.0, 0.1, 0.2, 0.5])
        p = np.array([[0.0, 0.0], [1.0, 2.0], [np.nan, np.nan], [4.0, 8.0]])
        np.testing.assert_allclose(F.vid(t, p, 0.05), [0.5, 1.0])
        np.testing.assert_allclose(F.vid(t, p, 0.1), [1.0, 2.0])
        self.assertTrue(np.isnan(F.vid(t, p, 0.3)).all())        # 0,1 → 0,5 är längre än MAX_LUCKA_S
        self.assertTrue(np.isnan(F.vid(t, p, 0.6)).all())        # utanför serien

    def test_toppunkten_pa_ojamna_steg(self) -> None:
        f = lambda x: (x - 0.123) ** 2  # noqa: E731
        self.assertAlmostEqual(F.toppunkt(0.10, f(0.10), 0.12, f(0.12), 0.17, f(0.17)), 0.123, places=12)
        self.assertEqual(F.toppunkt(0.0, 1.0, 1.0, 0.0, 2.0, -1.0), 1.0)   # rak linje: ingen topp


class Faserna(unittest.TestCase):
    def _hander(self, t: np.ndarray, vy: str = "fo") -> np.ndarray:
        figur = gen.figur_fo if vy == "fo" else gen.figur_dtl
        L = figur(t, dict(gen.FO if vy == "fo" else gen.DTL), 180.0)
        g = gen._hander(L)
        return np.stack([g[:, 0] * gen.K_PX, -g[:, 1] * gen.K_PX], -1)   # px, y nedåt

    def test_definitionen_pa_tata_exakta_rutor(self) -> None:
        """Utan utjämning och med täta rutor ger definitionen figurens tider."""
        t = np.arange(0, 3.8, 0.0005)
        for vy, figur, p in (("fo", gen.figur_fo, gen.FO), ("dtl", gen.figur_dtl, gen.DTL)):
            f = F.hitta_faser(t, self._hander(t, vy), gen.TIDER["klick"])
            self.assertAlmostEqual(f.topp, gen.TIDER["topp"], delta=0.001)
            self.assertAlmostEqual(f.start, gen.facit_start(figur, dict(p), 180.0), delta=0.0005)
            self.assertEqual(f.traff, gen.TIDER["klick"])
            self.assertAlmostEqual(f.adress[1], f.start - 0.10)
            self.assertEqual(f.finish, (gen.TIDER["klick"] + 1.0, gen.TIDER["klick"] + 1.2))

    def test_utjamningen_flyttar_toppen_tidigare(self) -> None:
        """Nedsvingen är snabbare än baksvingen, så utjämningen drar toppen mot
        baksvingen: uppmätt 7–10 ms (METOD M4). Testet håller måttet på biasen."""
        t = _ojamna(912, seed=4)
        f = F.hitta_faser(t, F.jamna(t, self._hander(t)), gen.TIDER["klick"])
        self.assertLess(f.topp, gen.TIDER["topp"])
        self.assertGreater(f.topp, gen.TIDER["topp"] - 0.012)

    def test_starten_saknas_nar_handerna_inte_ror_sig_forst(self) -> None:
        t = np.arange(0, 3.0, 1 / 240)
        G = np.stack([np.zeros_like(t), 100 - 120 * np.clip(t - 2.0, 0, None)], -1)  # upp på 0,25 s
        G[t > 2.25, 1] = 100.0
        f = F.hitta_faser(t, G, 2.5)
        self.assertIsNone(f.start)                              # baksvingen 0,25 s < MIN_BAKSVING_S
        self.assertAlmostEqual(f.adress[1], f.topp - F.TOPP_ADRESS_S - 0.10)

    def test_utan_hander_gar_svingen_inte_att_mata(self) -> None:
        t = np.arange(0, 3.0, 1 / 240)
        with self.assertRaises(F.SvingFel):
            F.hitta_faser(t, np.full((len(t), 2), np.nan), 2.5)

    def test_greppregeln(self) -> None:
        xy = np.zeros((3, 13, 2))
        xy[:, 5] = [[1, 1], [np.nan, np.nan], [np.nan, np.nan]]
        xy[:, 6] = [[2, 2], [3, 3], [np.nan, np.nan]]
        g = F.grepp_regel(xy)
        np.testing.assert_array_equal(g[1, 5], [3, 3])
        self.assertTrue(np.isnan(g[2, 5:7]).all())
        np.testing.assert_array_equal(g[0, 5:7], [[1, 1], [2, 2]])
        self.assertTrue(math.isnan(xy[1, 5, 0]))                # indata rörs inte


if __name__ == "__main__":
    unittest.main()
