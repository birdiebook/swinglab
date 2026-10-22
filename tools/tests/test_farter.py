"""Tilläggen mot Sportsbox i 2D (PLAN S1b, METOD M30–M37): farterna, finishens tid,
knäna och böjningen, med påhittade svingar och konstruerade serier."""
from __future__ import annotations

import math
import unittest

import numpy as np

from _hjalp import mat, sving
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
        """Utan två rutor med värde inom 3σ på var sida saknas farten. METOD M35"""
        t = np.arange(0, 241) / 240
        p = np.stack([t, t], axis=1)
        p[(t > 0.40) & (t < 0.46)] = np.nan
        v = FA.hastighet(t, p, np.array([0.43, 0.30]))
        self.assertTrue(np.isnan(v[0]).all())
        self.assertTrue(np.isfinite(v[1]).all())
        # En enda ruta efter τ räcker inte.
        q = p.copy()
        q[(t > 0.20) & (t < 0.25)] = np.nan
        q[(t > 0.2124) & (t < 0.2126)] = [0.2125, 0.2125]
        v = FA.hastighet(t, q, np.array([0.2005, 0.195]))
        self.assertTrue(np.isnan(v[0]).all())        # en ruta efter inom 22,5 ms
        self.assertTrue(np.isfinite(v[1]).all())     # 0,1958, 0,2 och 0,2125 efter

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

    def test_ingen_topp_i_anden_eller_vid_en_lucka(self) -> None:
        """M35: toppen i rutnätets ände eller intill en lucka över 20 ms saknas; en kort lucka gör inget."""
        tau = FA.rutnat(0.0, 0.1)
        self.assertIsNone(FA.maxpunkt(tau, 500 + 1000 * tau))            # farten steg ännu
        s = 700 - 1e5 * (tau - 0.0423) ** 2
        lucka = s.copy()
        lucka[(tau > 0.045) & (tau < 0.067)] = np.nan                    # 21 ms intill toppen
        self.assertIsNone(FA.maxpunkt(tau, lucka))
        lucka = s.copy()
        lucka[(tau > 0.050) & (tau < 0.062)] = np.nan                    # 11 ms
        self.assertAlmostEqual(FA.maxpunkt(tau, lucka)[1], 0.0423, delta=1e-9)
        lucka = s.copy()
        lucka[(tau > 0.0655) & (tau < 0.095)] = np.nan                   # 29 ms, 23 ms bort
        self.assertAlmostEqual(FA.maxpunkt(tau, lucka)[0], 700.0, delta=1e-6)

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
        self.assertGreater(mat(vy="fo", seed=3)["matt"]["handfart_max_fore_traff_ms"], 0)   # före träffen
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

    def test_farterna_kraver_den_egna_handleden(self) -> None:
        """M35–M37: utan främre handleden ingen toppfart och ingen vinkelfart (greppregeln
        ersätter inte), men finishens tid ur den bakre."""
        r = mat(vy="fo", seed=3, dolj=[["handled_v", 0.0, 9.9]])
        self.assertNotIn("handfart_max", r["matt"])
        self.assertNotIn("framre_arm_vinkelfart_max", r["matt"])
        self.assertIn("genomsving_s", r["matt"])

    def test_lucka_vid_toppfarten_ger_ingen_topp(self) -> None:
        """M35: händerna borta 60–80 ms över toppfarten ger inget tal, inte ett fel tal."""
        for a, b in ((2.30, 2.36), (2.29, 2.37)):
            r = mat(vy="fo", seed=3, brus_px=1.0, dolj=[["handled_v", a, b], ["handled_h", a, b]])
            for k in ("handfart_max", "handfart_max_fore_traff_ms", "framre_arm_vinkelfart_max"):
                self.assertNotIn(k, r["matt"])
            self.assertIn("genomsving_s", r["matt"])
        # Frö 1: rutnätet med 36 % saknade rutor har en rå lucka på 33 ms vid toppfarten.
        self.assertNotIn("handfart_max", mat(vy="fo")["matt"])

    def test_toppfarten_nara_traffen(self) -> None:
        """M35: toppfarten 15 ms före träffen hittas; kommer träffen innan farten vänt saknas den."""
        r = mat(vy="fo", seed=3, klick=2.34)
        _, f = sving(vy="fo", seed=3, klick=2.34)
        self.assertAlmostEqual(r["matt"]["handfart_max_fore_traff_ms"], f["handfart_max_fore_traff_ms"], delta=3.0)
        self.assertGreater(r["matt"]["handfart_max_fore_traff_ms"], 5.0)
        r = mat(vy="fo", seed=3, klick=2.30)
        self.assertNotIn("handfart_max", r["matt"])                      # inte 0 ms
        self.assertNotIn("handfart_max_fore_traff_ms", r["matt"])


if __name__ == "__main__":
    unittest.main()
