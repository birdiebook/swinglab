"""P-positionerna (BESLUT B32, METOD M28) och måtten vid dem (METOD M29) på
påhittade svingar, där armens vinkel är styrd och tiderna kända ur figuren."""
from __future__ import annotations

import unittest

import numpy as np

from _hjalp import gen, mat, sving
from pc import faser as F
from pc import positioner as PO

RUTA = 1 / 240         # en ruta i 240-rutnätet
FACIT = 0.05           # måtten vid positionerna, som test_matt


class Tiderna(unittest.TestCase):
    def kolla(self, vy: str, **args) -> dict:
        r = mat(vy=vy, **args)
        _, facit = sving(vy=vy, **args)
        p = r["positioner"]
        self.assertEqual(list(p), list(PO.POSITIONER))
        for k in ("P3", "P5", "P9"):
            with self.subTest(vy=vy, position=k):
                self.assertIsNotNone(facit["_positioner"][k])
                self.assertAlmostEqual(p[k], facit["_positioner"][k], delta=RUTA)
        self.assertEqual(p["P4"], r["faser"]["topp"])
        self.assertEqual(p["P7"], r["faser"]["traff"])
        self.assertAlmostEqual(p["P10"], gen.TIDER["klick"] + sum(F.FINISH) / 2)
        self.assertLess(p["P1"], p["P3"])
        self.assertTrue(p["P3"] < p["P4"] < p["P5"] < p["P7"] < p["P9"] < p["P10"])
        return r

    def test_fo_inom_en_ruta(self) -> None:
        for seed in (1, 2, 3):
            self.kolla("fo", seed=seed)
        self.kolla("fo", seed=9, brus_px=0.8)

    def test_dtl_inom_en_ruta(self) -> None:
        for seed in (1, 2, 3):
            self.kolla("dtl", seed=seed)
        self.kolla("dtl", seed=9, brus_px=0.8)

    def test_andra_armar_flyttar_positionerna(self) -> None:
        """En armbåge som böjer mer och en kortare baksving ger andra tider, som hittas."""
        a = self.kolla("fo", armbage=(0, 40, 55, 80), arm=(-14, -110, -6, 140))
        b = self.kolla("fo")
        self.assertGreater(abs(a["positioner"]["P3"] - b["positioner"]["P3"]), 2 * RUTA)

    def test_utan_bias_over_manga_svingar(self) -> None:
        """Luckorna gör utjämningen osymmetrisk (METOD M3), men i medel ingen bias."""
        fel = []
        for seed in range(20, 32):
            r = mat(vy="fo", seed=seed)
            _, facit = sving(vy="fo", seed=seed)
            fel += [r["positioner"][k] - facit["_positioner"][k] for k in ("P3", "P5", "P9")]
        self.assertLess(abs(float(np.mean(fel))), 0.001)
        self.assertLess(float(np.max(np.abs(fel))), 1.25 * RUTA)


class Saknas(unittest.TestCase):
    def test_armen_aldrig_vagrat_i_baksvingen(self) -> None:
        for vy, args in (("fo", {"arm": (-14, -60, -6, 140)}), ("dtl", {"hander_upp": 40.0})):
            with self.subTest(vy=vy):
                r = mat(vy=vy, **args)
                _, facit = sving(vy=vy, **args)
                self.assertIsNone(facit["_positioner"]["P3"])
                self.assertIsNone(r["positioner"]["P3"])
                self.assertIsNone(r["positioner"]["P5"])
                self.assertIsNotNone(r["positioner"]["P9"])
                self.assertIsNotNone(r["positioner"]["P4"])
        r = mat(vy="fo", arm=(-14, -60, -6, 140))
        for k in ("backen_sway_p3", "framre_armbage_p3", "backen_resa_p5"):
            self.assertNotIn(k, r["matt"])
        self.assertIn("backen_sway_topp", r["matt"])

    def test_bakre_armen_aldrig_vagrat_efter_traffen(self) -> None:
        for vy, args in (("fo", {"arm": (-14, -130, -6, 20)}), ("dtl", {"hander_finish": 50.0})):
            with self.subTest(vy=vy):
                r = mat(vy=vy, **args)
                self.assertIsNone(r["positioner"]["P9"])
                self.assertIsNotNone(r["positioner"]["P3"])
                self.assertIsNotNone(r["positioner"]["P5"])

    def test_dold_framre_handled_ger_inga_p3_och_p5(self) -> None:
        """Armen mäts mot den egna handleden; greppregeln gissar inte positionen."""
        r = mat(vy="fo", dolj=[["handled_v", 0.0, 9.9]])
        self.assertIsNone(r["positioner"]["P3"])
        self.assertIsNone(r["positioner"]["P5"])
        self.assertIsNotNone(r["positioner"]["P9"])

    def test_lang_lucka_vid_passagen(self) -> None:
        """Handleden borta 0,2 s kring P3: ingen interpolation över luckan (METOD M3)."""
        _, facit = sving(vy="fo")
        p3 = facit["_positioner"]["P3"]
        r = mat(vy="fo", dolj=[["handled_v", p3 - 0.1, p3 + 0.1]])
        self.assertIsNone(r["positioner"]["P3"])
        self.assertIsNotNone(r["positioner"]["P5"])


class Passagerna(unittest.TestCase):
    T = np.array([0.0, 0.01, 0.02, 0.03, 0.04, 0.2, 0.21])

    def test_linjart_mellan_rutorna_och_lika_med_noll(self) -> None:
        a = np.array([-2.0, -1.0, 1.0, 0.0, -1.0, 1.0, 2.0])
        self.assertEqual(PO.passager(self.T, a, 0.0, 0.1, uppat=True), [0.015])
        self.assertEqual(PO.passager(self.T, a, 0.0, 0.1, uppat=False), [0.03])   # 0 räknas som vågrät
        self.assertEqual(PO.passager(self.T, a, 0.0, 0.3, uppat=True), [0.015])   # luckan 0,16 s räknas inte
        a2 = a.copy()
        a2[2] = np.nan
        # Utan rutan 0,02: −1 → 0 är en passage uppåt, och 0 → −1 en nedåt, båda vid 0,03.
        self.assertEqual(PO.passager(self.T, a2, 0.0, 0.1, uppat=True), [0.03])
        self.assertEqual(PO.passager(self.T, a2, 0.0, 0.1, uppat=False), [0.03])

    def test_vinkeln(self) -> None:
        axel = np.array([[0.0, 0.0], [0.0, 0.0], [0.0, 0.0]])
        hand = np.array([[-10.0, -10.0], [10.0, 10.0], [np.nan, 1.0]])            # y nedåt
        a = PO.armens_vinkel(axel, hand)
        self.assertAlmostEqual(a[0], 45.0)
        self.assertAlmostEqual(a[1], -45.0)
        self.assertTrue(np.isnan(a[2]))


class MattenVidPositionerna(unittest.TestCase):
    def test_kanda_tal(self) -> None:
        for args in ({}, {"sway": (0, 3, 12, 15), "armbage": (0, 40, 55, 80), "seed": 7}):
            r = mat(vy="fo", **args)
            _, facit = sving(vy="fo", **args)
            for k in ("backen_sway_p3", "framre_armbage_p3", "backen_resa_p5", "huvud_backen_finish"):
                with self.subTest(args=args, matt=k):
                    self.assertAlmostEqual(r["matt"][k], facit[k], delta=FACIT)

    def test_tecknen(self) -> None:
        r = mat(vy="fo")
        self.assertLess(r["matt"]["backen_sway_p3"], 0)              # på väg bakåt, som toppen (−6)
        self.assertGreater(r["matt"]["backen_sway_p3"], -6.0)
        self.assertGreater(r["matt"]["backen_resa_p5"], 0)           # på väg fram från toppen
        self.assertLess(r["matt"]["backen_resa_p5"], r["matt"]["backen_resa_framat"])


class Speglat(unittest.TestCase):
    def test_vansterspelaren_ger_samma_tider(self) -> None:
        for vy in ("fo", "dtl"):
            h, v = mat(vy=vy, seed=5), mat(vy=vy, seed=5, hand="vanster")
            for k in PO.POSITIONER:
                with self.subTest(vy=vy, position=k):
                    self.assertIsNotNone(h["positioner"][k])
                    self.assertAlmostEqual(h["positioner"][k], v["positioner"][k], delta=1e-9)


if __name__ == "__main__":
    unittest.main()
