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
        """Handleden borta 0,2 s kring P3: ingen interpolation över luckan (METOD M3).
        Fixturen fo_lucka_arm prövar gränsen 0,10 s (test_fixturer)."""
        _, facit = sving(vy="fo")
        p3 = facit["_positioner"]["P3"]
        r = mat(vy="fo", dolj=[["handled_v", p3 - 0.1, p3 + 0.1]])
        self.assertIsNone(r["positioner"]["P3"])
        self.assertIsNotNone(r["positioner"]["P5"])


class Passagerna(unittest.TestCase):
    T = np.array([0.0, 0.01, 0.02, 0.03, 0.04, 0.2, 0.21])

    def test_linjart_mellan_rutorna_och_lika_med_noll(self) -> None:
        h = np.array([-2.0, -1.0, 1.0, 0.0, -1.0, 1.0, 2.0])
        p = PO.passager(self.T, h, 0.0, 0.1)
        self.assertEqual([(x[0], x[3]) for x in p], [(0.015, True), (0.03, False)])   # 0 räknas som vågrät
        self.assertEqual(len(PO.passager(self.T, h, 0.0, 0.3)), 2)                    # luckan 0,16 s räknas inte
        h2 = h.copy()
        h2[2] = np.nan
        # Utan rutan 0,02: −1 → 0 är en passage uppåt, och 0 → −1 en nedåt, båda vid 0,03.
        self.assertEqual([(x[0], x[3]) for x in PO.passager(self.T, h2, 0.0, 0.1)], [(0.03, True), (0.03, False)])

    def test_hojden(self) -> None:
        axel = np.array([[0.0, 0.0], [0.0, 0.0], [0.0, 0.0]])
        hand = np.array([[-10.0, -4.0], [10.0, 10.0], [np.nan, 1.0]])               # y nedåt
        h = PO.armens_hojd(axel, hand)
        self.assertEqual(list(h[:2]), [4.0, -10.0])
        self.assertTrue(np.isnan(h[2]))

    @staticmethod
    def faser(topp: float = 1.0, traff: float = 1.5) -> F.Faser:
        return F.Faser(start=0.3, topp=topp, traff=traff, adress=(-0.1, 0.2), finish=(2.5, 2.7))

    T2 = np.round(np.arange(0.0, 2.6, 0.01), 6)

    def test_ingen_passage_over_en_lucka(self) -> None:
        """Armen syns under vågrätt mellan P3 och toppen (nedgången dold i en lucka
        längre än 0,10 s): P3 saknas hellre än att den första passagen tas. Likadant
        för P5 och P9. METOD M28"""
        t = self.T2
        h = np.where((t > 0.5) & (t < 1.3), 5.0, -5.0)               # ren baksving: över vågrätt 0,5–1,3 s
        p = PO.hitta(t, self.faser(), h, -h)
        self.assertAlmostEqual(p["P3"], 0.505)
        self.assertAlmostEqual(p["P5"], 1.295)
        g = h.copy()
        g[(t > 0.7) & (t < 0.75)] = -5.0                             # ner under vågrätt …
        g[(t >= 0.75) & (t < 0.9)] = np.nan                          # … och upp igen i en lucka på 0,16 s
        self.assertIsNone(PO.hitta(t, self.faser(), g, -h)["P3"])
        g = h.copy()
        g[(t > 1.02) & (t < 1.15)] = np.nan                          # passagen nedåt dold i en lång lucka,
        g[(t >= 1.15) & (t < 1.2)] = -5.0                            # armen syns under vågrätt,
        g[(t >= 1.2) & (t < 1.25)] = np.nan                          # upp igen, och ner vid 1,295 s
        self.assertIsNone(PO.hitta(t, self.faser(), g, -h)["P5"])
        b = np.where(t > 1.8, 5.0, -5.0)
        self.assertAlmostEqual(PO.hitta(t, self.faser(), h, b)["P9"], 1.805)
        b = np.where(t > 1.9, 5.0, -5.0)                             # synlig passage vid 1,895 s, men …
        b[(t > 1.55) & (t < 1.7)] = np.nan                           # … armen gick upp i en lång lucka,
        b[(t >= 1.7) & (t < 1.72)] = 5.0                             # syns över vågrätt,
        b[(t >= 1.72) & (t < 1.85)] = np.nan                         # och ner igen i en lång lucka
        self.assertIsNone(PO.hitta(t, self.faser(), h, b)["P9"])

    def test_rutparet_over_toppen(self) -> None:
        """Passerar armen vågrätt mellan rutorna kring toppen hör paret till P3 (uppåt)
        eller P5 (nedåt), så att ingen av dem tappas. METOD M28"""
        t = self.T2
        h = np.where((t > 1.0) & (t < 1.3), 5.0, -5.0)               # upp mellan 1,00 och 1,01
        p = PO.hitta(t, self.faser(topp=1.004), h, -h)
        self.assertAlmostEqual(p["P3"], 1.005)                        # efter toppen, inom rutan
        self.assertAlmostEqual(p["P5"], 1.295)
        h = np.where((t > 0.5) & (t < 1.0), 5.0, -5.0)               # ner mellan 0,99 och 1,00
        p = PO.hitta(t, self.faser(topp=0.996), h, -h)
        self.assertAlmostEqual(p["P3"], 0.505)
        self.assertAlmostEqual(p["P5"], 0.995)                        # före toppen, inom rutan


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
