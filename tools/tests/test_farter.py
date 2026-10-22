"""Tilläggen mot Sportsbox i 2D (PLAN S1b, METOD M30–M37): farterna, finishens tid,
knäna och böjningen, med påhittade svingar och konstruerade serier."""
from __future__ import annotations

import math
import unittest

import numpy as np

from _hjalp import mat
from pc import farter as FA


class Farterna(unittest.TestCase):
    def test_jamn_rorelse_ger_exakt_fart_trots_luckor(self) -> None:
        """Anpassningen är väntevärdesriktig för en jämn rörelse, hur luckorna än ligger. METOD M35"""
        rng = np.random.default_rng(3)
        t = np.arange(0, 241) / 240
        t = t[rng.random(len(t)) >= 0.36]
        p = np.stack([100 + 300 * t, 50 - 400 * t], axis=1)
        tau = FA.rutnat(0.1, 0.9)
        v = FA.hastighet(t, p, tau)
        ok = np.isfinite(v).all(axis=1)
        self.assertGreater(ok.sum(), 700)
        np.testing.assert_allclose(v[ok], np.tile([300.0, -400.0], (ok.sum(), 1)), rtol=1e-9)
        np.testing.assert_allclose(FA.fart(t, p, tau)[ok], 500.0, rtol=1e-9)

    def test_ingen_fart_over_en_lucka(self) -> None:
        """Utan en ruta med värde inom 3σ på båda sidor saknas farten. METOD M35"""
        t = np.arange(0, 241) / 240
        p = np.stack([t, t], axis=1)
        p[(t > 0.40) & (t < 0.46)] = np.nan
        v = FA.hastighet(t, p, np.array([0.43, 0.30]))
        self.assertTrue(np.isnan(v[0]).all())
        self.assertTrue(np.isfinite(v[1]).all())

    def test_rutnatet(self) -> None:
        r = FA.rutnat(2.2, 2.5)
        self.assertEqual(len(r), 301)
        self.assertAlmostEqual(r[-1], 2.5, delta=1e-12)

    def test_vinkelfarten_over_180(self) -> None:
        """En linje som roterar 600 °/s genom ±180° ger 600, inget hopp. METOD M37"""
        t = np.arange(0, 121) / 240
        a = np.radians(170 + 600 * t)
        fran = np.zeros((len(t), 2))
        till = np.stack([np.cos(a), np.sin(a)], axis=1) * 50
        w = FA.vinkelfart(t, fran, till, FA.rutnat(0.05, 0.45))
        np.testing.assert_allclose(w[np.isfinite(w)], 600.0, rtol=1e-9)
        self.assertEqual(FA._vinkel(181.0), -179.0)
        self.assertEqual(FA._vinkel(-180.0), 180.0)

    def test_maxpunkt_pa_parabeln(self) -> None:
        tau = FA.rutnat(0.0, 0.1)
        s = 700 - 1e5 * (tau - 0.0423) ** 2
        v, tid = FA.maxpunkt(tau, s)
        self.assertAlmostEqual(tid, 0.0423, delta=1e-9)
        self.assertAlmostEqual(v, 700.0, delta=1e-6)

    def test_finishen_saknas_nar_farten_inte_faller(self) -> None:
        tau = FA.rutnat(0.0, 1.0)
        self.assertIsNone(FA.finish_tid(tau, np.full(len(tau), 300.0)))
        s = 300 * np.exp(-((tau - 0.3) / 0.1) ** 2)
        tf = FA.finish_tid(tau, s)
        self.assertAlmostEqual(tf, 0.3 + 0.1 * math.sqrt(math.log(10)), delta=1e-5)


class Svingen(unittest.TestCase):
    def test_tecken_och_ordning(self) -> None:
        fo, dtl = mat(vy="fo"), mat(vy="dtl")
        self.assertLess(fo["matt"]["bakre_kna_sway_topp"], 0)                 # bort från målet
        self.assertGreater(fo["matt"]["bakre_kna_sway_finish"], 20)           # bakre knät mot målet
        self.assertGreater(fo["matt"]["handfart_max_fore_traff_ms"], 0)       # toppfarten före träffen
        self.assertGreater(fo["matt"]["hand_lyft_topp"], 50)                  # + uppåt
        self.assertLess(dtl["matt"]["framre_kna_traff"], dtl["matt"]["framre_kna_topp"])   # benet sträcks
        for r in (fo, dtl):
            self.assertGreater(r["matt"]["genomsving_s"], 0.5)
            self.assertLess(r["matt"]["genomsving_s"], 1.0)

    def test_backens_bojning_ar_medlet_av_balen_och_laret(self) -> None:
        """M30: utan låret (bakre knät dolt) saknas måttet, bröstets böjning finns."""
        r = mat(vy="dtl", konf={"kna_h": 0.1})
        for fz in ("adress", "topp", "traff"):
            self.assertNotIn(f"backen_bojning_{fz}", r["matt"])
            self.assertIn(f"brost_bojning_{fz}", r["matt"])
            self.assertIn(f"framre_kna_{fz}", r["matt"])

    def test_framre_knat_skymt_saknas(self) -> None:
        """M33: främre knät bakifrån med låg konfidens räknas inte; resten finns."""
        r = mat(vy="dtl", konf={"kna_v": 0.2})
        for fz in ("adress", "topp", "traff"):
            self.assertNotIn(f"framre_kna_{fz}", r["matt"])
            self.assertIn(f"backen_bojning_{fz}", r["matt"])

    def test_armens_fart_kraver_den_egna_handleden(self) -> None:
        """M37: greppregeln ger handens fart men inte armens vinkelfart."""
        r = mat(vy="fo", dolj=[["handled_v", 0.0, 9.9]])
        self.assertIn("handfart_max", r["matt"])
        self.assertNotIn("framre_arm_vinkelfart_max", r["matt"])


if __name__ == "__main__":
    unittest.main()
