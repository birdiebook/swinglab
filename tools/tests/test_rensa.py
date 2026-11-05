"""Rensningen före mätningen: byten och spikar (METOD M53), för långa segment (METOD M52),
orsakerna till att ett mått saknas och toppens platå (METOD M4). Påhittade svingar med
inlagda fel; inga riktiga leder (CLAUDE.md, Dataregeln)."""
from __future__ import annotations

import json
import unittest

import numpy as np

from _hjalp import M, fm, sving
from pc import rensa as RE
from pc.format import AXEL_F, ARMBAGE_F, HANDLED_F, HOFT_B, HOFT_F, LEDER

# Felen som läggs in: (led, t, rutor, dx cm, dy cm), och (grupp, ta, tb).
SPIKAR = [["handled_f", 2.20, 2, 30, 0], ["hoft_f", 2.50, 1, 0, -20], ["armbage_f", 2.35, 3, -25, 10],
          ["nasa", 1.00, 1, 15, 0]]
BYTEN = [["armar", 1.40, 1.45], ["ben", 2.60, 2.62], ["hofter", 3.00, 3.10]]


def _las(d: dict):
    return fm.las(json.dumps(d))


class IngaFalskaLarm(unittest.TestCase):
    """Rena påhittade svingar, med upp till 6 px brus: rensningen rör ingenting."""

    def test_rena_svingar(self) -> None:
        for vy in ("fo", "dtl"):
            for seed in range(8):
                for brus in (0.8, 6.0):
                    s = _las(sving(vy=vy, seed=seed, brus_px=brus)[0])
                    xy, r = RE.rensa(s.t, s.xy)
                    self.assertEqual(r, {"byten": {}, "byten_oklara": {}, "spikar": {}}, f"{vy} {seed} {brus}")
                    np.testing.assert_array_equal(xy, s.xy)

    def test_kraftigt_brus(self) -> None:
        # 10 px brus (≈ 2,5 cm): en enstaka ruta långt ut kan tas för en spik, men högst 1 %
        # av rutorna, och måtten rör sig mindre än bruset själv.
        s = _las(sving(vy="dtl", seed=23, brus_px=10.0)[0])
        xy, r = RE.rensa(s.t, s.xy)
        self.assertLess(sum(r["spikar"].values()), 0.01 * len(s.t) * 13)
        self.assertEqual(r["byten"], {})


class Spikar(unittest.TestCase):
    def test_spikarna_tas_bort(self) -> None:
        d, _ = sving(vy="fo", seed=5, brus_px=0.8, spikar=SPIKAR)
        s = _las(d)
        xy, r = RE.rensa(s.t, s.xy)
        self.assertEqual(r["spikar"], {"nasa": 1, "armbage_f": 3, "handled_f": 2, "hoft_f": 1})
        for namn, t0, rutor, _, _ in SPIKAR:
            j = LEDER.index(namn)
            k = int(np.searchsorted(s.t, t0))
            self.assertTrue(np.isnan(xy[k:k + rutor, j]).all(), namn)
            self.assertTrue(np.isfinite(xy[k - 1, j]).all() and np.isfinite(xy[k + rutor, j]).all(), namn)

    def test_matten_som_utan_spikarna(self) -> None:
        # Höften kastad 20 cm i träffens ruta flyttar sway och lutning; efter rensningen
        # ligger måtten inom 0,3 cm och 0,5° från svingen utan spikar.
        ren = M.mat(_las(sving(vy="fo", seed=5, brus_px=0.8)[0]))["matt"]
        med = M.mat(_las(sving(vy="fo", seed=5, brus_px=0.8, spikar=SPIKAR)[0]))["matt"]
        for k in ("backen_sway_traff", "hoftlinje_lutning_traff", "sidbojning_traff", "handfart_max"):
            self.assertAlmostEqual(med[k], ren[k], delta=0.5, msg=k)

    def test_snabb_rorelse_ar_ingen_spik(self) -> None:
        # Händerna i nedsvingen håller riktningen: ett långt steg utan steg tillbaka.
        u, t = 100.0, np.arange(6) / 240.0
        xy = np.full((6, 13, 2), np.nan)
        xy[:, HANDLED_F] = np.stack([np.arange(6) * 30.0, np.zeros(6)], axis=1)   # 30 px per ruta
        self.assertEqual(RE.spikar(t, xy, px_per_m=100.0, u=u), {})


class Byten(unittest.TestCase):
    def test_korta_byten_ratta(self) -> None:
        ren = _las(sving(vy="fo", seed=5, brus_px=0.8)[0])
        s = _las(sving(vy="fo", seed=5, brus_px=0.8, byten=BYTEN)[0])
        xy, r = RE.rensa(s.t, s.xy)
        self.assertEqual(set(r["byten"]), {"armar", "ben", "hofter"})
        self.assertEqual(r["byten_oklara"], {})
        np.testing.assert_allclose(xy, ren.xy, atol=1e-9)

    def test_bytet_i_matten(self) -> None:
        ren = M.mat(_las(sving(vy="fo", seed=5, brus_px=0.8)[0]))
        med = M.mat(_las(sving(vy="fo", seed=5, brus_px=0.8, byten=[["hofter", 2.45, 2.55]])[0]))
        self.assertEqual(set(med["kvalitet"]["rensning"]["byten"]), {"hofter"})
        self.assertAlmostEqual(med["matt"]["hoftlinje_lutning_traff"], ren["matt"]["hoftlinje_lutning_traff"],
                               places=9)

    def test_ensam_vaxling_rattas_inte(self) -> None:
        # Klippet börjar bytt och byter tillbaka efter 0,5 s: vilken sida som är rätt går
        # inte att veta ur bytet, så inget rättas, men växlingen räknas.
        s = _las(sving(vy="fo", seed=5, brus_px=0.8, fran=0.0, byten=[["armar", 0.0, 0.5]])[0])
        xy, r = RE.rensa(s.t, s.xy)
        self.assertEqual(r["byten"], {})
        self.assertEqual(r["byten_oklara"], {"armar": 1})
        np.testing.assert_array_equal(xy, s.xy)

    def test_sidor_nara_varandra_provas_inte(self) -> None:
        # Höfterna 5 px isär (bakifrån skymmer de varandra): inget byte prövas.
        t = np.arange(4) / 240.0
        xy = np.full((4, 13, 2), np.nan)
        xy[:, HOFT_F] = [[0, 0], [0, 0], [5, 0], [0, 0]]
        xy[:, HOFT_B] = [[5, 0], [5, 0], [0, 0], [5, 0]]
        self.assertEqual(RE.byten(t, xy, u=100.0), ({}, {}))


class OberoendeAvLangden(unittest.TestCase):
    def test_samma_rensning_med_annan_langd(self) -> None:
        # Farterna räknas om med en standardbål, så att faserna inte beror på längden. METOD M53
        d, _ = sving(vy="fo", seed=5, brus_px=0.8, spikar=SPIKAR, byten=BYTEN)
        a, b = M.mat(_las(d)), M.mat(_las(dict(d, spelarens_langd_m=1.60)))
        self.assertEqual(a["kvalitet"]["rensning"], b["kvalitet"]["rensning"])
        self.assertEqual(a["faser"], b["faser"])


class LangaSegment(unittest.TestCase):
    """Ett stelt segment kan inte bli längre i bild än i adressen. METOD M52"""

    def test_orsakerna(self) -> None:
        a0, m0, c0 = np.array([0.0, -1.0]), np.array([0.0, 0.0]), np.array([0.0, 1.0])
        self.assertIsNone(M.segment_orsak(a0, m0, c0, a0, m0, c0))
        self.assertEqual(M.segment_orsak(np.array([0.0, -0.69]), m0, c0, a0, m0, c0), "segment_kort")
        self.assertEqual(M.segment_orsak(np.array([0.0, -1.16]), m0, c0, a0, m0, c0), "segment_langt")
        self.assertIsNone(M.segment_orsak(np.array([0.0, -1.14]), m0, c0, a0, m0, c0))
        self.assertEqual(M.segment_orsak(np.array([np.nan, 0.0]), m0, c0, a0, m0, c0), "led_saknas")
        self.assertTrue(np.isnan(M.bojning_synlig(np.array([0.0, -1.16]), m0, c0, a0, m0, c0)))

    def test_armbagen_fel_vid_toppen(self) -> None:
        # Armbågspunkten 20 cm ut från armen i 0,2 s kring toppen (för länge för en spik):
        # överarmen syns längre än i adressen, och vinkeln saknas med orsaken.
        d, _ = sving(vy="fo")
        s = fm.fran_dict(d)
        topp = M.mat(s)["faser"]["topp"]
        xy = s.xy.copy()
        for k in np.flatnonzero(np.abs(s.t - topp) <= 0.10):
            arm = xy[k, HANDLED_F] - xy[k, AXEL_F]
            xy[k, ARMBAGE_F] += np.array([-arm[1], arm[0]]) / np.hypot(*arm) * 80.0
        s.xy = xy
        r = M.mat(s)
        self.assertNotIn("framre_armbage_topp", r["matt"])
        self.assertEqual(r["kvalitet"]["saknas"]["framre_armbage_topp"], "segment_langt")


class Orsaker(unittest.TestCase):
    def test_tempot_utan_start(self) -> None:
        r = M.mat(_las(sving(vy="dtl", seed=16, start=1.95)[0]))
        self.assertEqual(r["kvalitet"]["saknas"]["tempo"], "start_saknas")

    def test_tempot_med_osaker_start(self) -> None:
        # Bakifrån med 10 px brus: posen skakar i adressen och starten är osäker (METOD M40).
        from pc import generera as gen
        r = M.mat(fm.las(gen.fixtursving("dtl_osaker")))
        self.assertNotIn("tempo", r["matt"])
        self.assertEqual(r["kvalitet"]["saknas"]["tempo"], "start_osaker")

    def test_bara_saknade_mått(self) -> None:
        r = M.mat(_las(sving(vy="fo", seed=5, brus_px=0.8)[0]))
        self.assertEqual(r["kvalitet"]["saknas"], {})
        self.assertFalse(set(r["kvalitet"]["saknas"]) & set(r["matt"]))


class ToppensPlata(unittest.TestCase):
    """Platån mäts och visas, ingen spärr än (METOD M4, öppen fråga)."""

    def test_plata_finns(self) -> None:
        r = M.mat(_las(sving(vy="fo", seed=5)[0]))
        self.assertGreater(r["kvalitet"]["topp_plata_s"], 0.0)
        self.assertLess(r["kvalitet"]["topp_plata_s"], M.PLATA_SOK_S * 2)

    def test_handerna_still_langre_ger_bredare_plata(self) -> None:
        # Händerna hålls på toppens höjd 0,15 s efter toppen (som med driver): platån växer.
        d, _ = sving(vy="fo", seed=5)
        s = fm.fran_dict(d)
        f = M.mat(s)
        topp, bred0 = f["faser"]["topp"], f["kvalitet"]["topp_plata_s"]
        xy = s.xy.copy()
        y_topp = np.nanmin(xy[np.abs(s.t - topp) < 0.01][:, [HANDLED_F]][..., 1])
        fonst = (s.t > topp) & (s.t <= topp + 0.15)
        for j in (HANDLED_F, LEDER.index("handled_b")):
            xy[fonst, j, 1] = np.minimum(xy[fonst, j, 1], y_topp + 1.0)
        s.xy = xy
        self.assertGreater(M.mat(s)["kvalitet"]["topp_plata_s"], bred0 + 0.08)


if __name__ == "__main__":
    unittest.main()
