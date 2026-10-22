"""Sessionens sammanfattning och jämförelsen mot förra passet (METOD M25, M26)."""
from __future__ import annotations

import math
import unittest

import numpy as np

from _hjalp import gen
from pc import session as S


class Statistiken(unittest.TestCase):
    def test_percentilen_som_numpy(self) -> None:
        rng = np.random.default_rng(1)
        for n in (1, 2, 3, 8, 13):
            x = sorted(rng.normal(size=n).tolist())
            for p in (0.0, 0.25, 0.5, 0.75, 1.0):
                self.assertAlmostEqual(S.percentil(x, p), float(np.percentile(x, 100 * p)), places=12)

    def test_rangerna_ger_medelrang_for_lika(self) -> None:
        self.assertEqual(S.rang([10.0, 30.0, 20.0, 20.0]), [1.0, 4.0, 2.5, 2.5])

    def test_spearman(self) -> None:
        self.assertAlmostEqual(S.spearman([0, 1, 2, 3], [1.0, 5.0, 6.0, 90.0]), 1.0)
        self.assertAlmostEqual(S.spearman([0, 1, 2, 3], [9.0, 5.0, 2.0, 1.0]), -1.0)
        self.assertEqual(S.spearman([0, 1, 2], [4.0, 4.0, 4.0]), 0.0)     # ingen spridning, ingen trend


class Sammanfattningen(unittest.TestCase):
    def test_kanda_tal(self) -> None:
        rader = [{"a": v} for v in (1.0, 2.0, 3.0, 4.0, 100.0)]
        s = S.sammanfatta(rader)["a"]
        self.assertEqual((s["n"], s["median"], s["q1"], s["q3"], s["min"], s["max"]), (5, 3.0, 2.0, 4.0, 1.0, 100.0))
        self.assertAlmostEqual(s["sd"], float(np.std([1, 2, 3, 4, 100], ddof=1)))
        self.assertAlmostEqual(s["trend"], 1.0)
        self.assertEqual(s["avvikare"], [4])            # MAD 1 → gränsen 4,45 från medianen

    def test_platsen_i_passet_ar_svingens_aven_nar_matt_saknas(self) -> None:
        rader = [{"a": 1.0}, {}, {"a": 2.0}, {"a": 50.0}, {"a": 3.0}, {"a": 2.5}]
        s = S.sammanfatta(rader)["a"]
        self.assertEqual(s["n"], 5)
        self.assertEqual(s["avvikare"], [3])

    def test_for_fa_svingar_ger_ingen_sammanfattning(self) -> None:
        self.assertEqual(S.sammanfatta([{"a": 1.0}, {"a": 2.0}, {"b": 1.0}]), {})

    def test_lika_varden_ger_inga_avvikare(self) -> None:
        s = S.sammanfatta([{"a": 2.0}] * 4 + [{"a": 9.0}])["a"]
        self.assertEqual(s["avvikare"], [])             # MAD = 0: inget att mäta mot

    def test_det_pahittade_passet(self) -> None:
        nu = gen.session(21, 10, 9, utslag=True)
        s = S.sammanfatta_session(nu)
        self.assertEqual(s["fo"]["backen_sway_topp"]["n"], 10)
        self.assertEqual(s["alla"]["tempo"]["n"], 19)
        self.assertNotIn("huvud_lyft_finish", s["fo"])
        self.assertEqual(len(s["fo"]["backen_sway_topp"]["avvikare"]), 1)
        self.assertGreater(s["dtl"]["backen_thrust_traff"]["trend"], 0.9)


class Jamforelsen(unittest.TestCase):
    def test_skillnaden_mot_forra_passets_spridning(self) -> None:
        forra = S.sammanfatta([{"a": v, "b": v} for v in (0.0, 1.0, 2.0, 3.0, 4.0)])
        nu = S.sammanfatta([{"a": v + 2.0, "b": v + 1.0} for v in (0.0, 1.0, 2.0, 3.0, 4.0)])
        j = S.jamfor(nu, forra)
        self.assertAlmostEqual(j["a"]["spridning"], 2.0 / 1.349)
        self.assertEqual((j["a"]["skillnad"], j["a"]["tydlig"]), (2.0, True))
        self.assertEqual((j["b"]["skillnad"], j["b"]["tydlig"]), (1.0, False))
        self.assertTrue(math.isfinite(j["b"]["spridning"]))


if __name__ == "__main__":
    unittest.main()
