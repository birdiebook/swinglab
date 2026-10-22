"""Klicket och parningen (METOD MS4, MS10) och fixturen för Swift (BESLUT B12).

Golf SG:s `klick()` och `para()` är facit. De provas mot porten här när Golf SG
finns på datorn (`GOLF_SG` i miljön, annars de vanliga mapparna); annars hoppas
de testerna över. CI har inte Golf SG, så paritetsprovet görs lokalt.
"""
from __future__ import annotations

import importlib
import math
import os
import sys
import unittest
from pathlib import Path

import numpy as np

import _hjalp  # noqa: F401  (sökvägen till tools/)
from pc import klick as KL
from pc import klickljud as G

TOL = 1e-9


def _golf_sg():
    for kand in [os.environ.get("GOLF_SG"), "/home/user/Golf-sg", r"C:\dev\golf-sg"]:
        if kand and (Path(kand) / "tools" / "handled_video.py").exists():
            sys.path.insert(0, str(Path(kand) / "tools"))
            try:
                return importlib.import_module("handled_video")
            except Exception:       # saknade beroenden: hoppa över
                return None
    return None


HV = _golf_sg()


def _brus(n: int, fro: int = 1, brus: float = 0.001) -> np.ndarray:
    return G.signal({"sr": 48000, "langd_s": n / 48000, "fro": fro, "brus": brus, "klick": []})


class Klicket(unittest.TestCase):
    def test_en_impuls_ger_ansatsen_47_prov_fore(self) -> None:
        """Fönstret är n − 48 … n + 47, så energin syns först i k − 47 (specens k − 48 är ett prov fel)."""
        x = np.zeros(48000, np.float32)
        x[20000] = 0.5
        kl = KL.klick(x)
        self.assertEqual(len(kl), 1)
        self.assertEqual(round(kl[0][0] * 48000), 20000 - 47)

    def test_tva_klick_04_s_isar_blir_det_starkaste(self) -> None:
        r = next(r for r in G.RECEPT if r["namn"] == "nara")
        kl = KL.klick(G.signal(r))
        self.assertEqual(len(kl), 1)
        self.assertAlmostEqual(kl[0][0], 1.4, delta=0.002)

    def test_bara_brus_ger_inget(self) -> None:
        self.assertEqual(KL.klick(_brus(5 * 48000)), [])
        self.assertEqual(KL.klick(np.zeros(5, np.float32)), [])
        self.assertEqual(KL.klick(np.zeros(50, np.float32)), [])      # kortare än fönstret

    def test_recepten_hittar_det_de_ska(self) -> None:
        for r in G.RECEPT:
            with self.subTest(r["namn"]):
                f = G.facit_klick(r)
                vantade = [k["prov"] for k in r["klick"] if k["amp"] >= 0.04]
                if r["namn"] == "nara":
                    vantade = vantade[1:]
                self.assertEqual(len(f["hela"]), len(vantade))
                for (prov, _), k in zip(f["hela"], vantade):
                    self.assertTrue(0 < k - prov <= 48, (prov, k))

    def test_bitarna(self) -> None:
        self.assertEqual(KL.bitar(10 * 48000), [(0, 480000)])
        self.assertEqual(KL.bitar(61 * 48000), [(0, 1440000), (1392000, 2832000), (2784000, 2928000)])
        self.assertEqual(KL.bitar(30 * 48000), [(0, 1440000)])

    def test_bitar_ger_samma_ansats_som_hela_signalen(self) -> None:
        """Klicken i överlappen (29,5 s och 58,6 s) och vid bitgränserna (13 prov in,
        bitens sista prov) hittas en gång, på samma prov. Styrkan skiljer: medianen är
        bitens (S2_SPEC §4.2)."""
        for namn in ("lang", "bitgrans"):
            r = next(r for r in G.RECEPT if r["namn"] == namn)
            f = G.facit_klick(r)
            self.assertEqual(len(f["hela"]), len(r["klick"]), namn)
            self.assertEqual([p for p, _ in f["bitar"]], [p for p, _ in f["hela"]], namn)
            for (_, a), (_, b) in zip(f["bitar"], f["hela"]):
                self.assertLess(abs(a / b - 1), 0.01, namn)

    def test_utan_kantregeln_blir_det_fel(self) -> None:
        """Kvittot på att receptet prövar regeln: utan den kapas klicket 13 prov in."""
        r = next(r for r in G.RECEPT if r["namn"] == "bitgrans")
        x = G.signal(r)
        a = 29 * 48000
        kapat = KL._klick_prov(x[a:a + 30 * 48000], 48000)[0]
        hel = KL._klick_prov(x[:30 * 48000], 48000)[0]
        self.assertLess(kapat[1], KL.kant())
        self.assertNotEqual(a + kapat[0], hel[0])

    def test_sla_ihop_tar_det_starkaste(self) -> None:
        kl = KL.sla_ihop([(0.0, [(1.0, 50.0), (29.5, 40.0)]), (29.0, [(0.5001, 45.0), (5.0, 30.0)])])
        self.assertEqual(kl, [(1.0, 50.0), (29.5001, 45.0), (34.0, 30.0)])


class Parningen(unittest.TestCase):
    def test_kand_forskjutning(self) -> None:
        for p in G.PARA[:3]:
            with self.subTest(p["namn"]):
                r = G.facit_para(p)
                sann = 2.347 if p["namn"] != "negativ" else -4.512
                self.assertAlmostEqual(r["forskjutning"], sann, delta=0.002)
                self.assertEqual(len(r["par"]), 6)
                self.assertLess(max(abs(x[2]) for x in r["par"]), 0.005)
                self.assertNotIn(4, [x[0] for x in r["par"]])           # det b missade

    def test_utan_traff_svaras_prior(self) -> None:
        tom = {"par": [], "antal": 0, "nast_bast": None, "nast_antal": 0, "osaker": True}
        self.assertEqual(KL.para([1.0], [5.0], prior=1.0), {"forskjutning": 1.0, **tom})
        self.assertEqual(KL.para([], [5.0]), {"forskjutning": 0.0, **tom})
        self.assertEqual(KL.para(G._A, G._A, prior=0.0, prior_fonster=0.0), {"forskjutning": 0.0, **tom})

    def test_saker_och_osaker(self) -> None:
        for p in G.PARA[:3]:
            r = G.facit_para(p)
            self.assertFalse(r["osaker"], p["namn"])
            self.assertEqual(r["antal"], 6)
            self.assertLess(r["nast_antal"], 3)
        # Exemplet ur granskningen: ett par, två lika bra förskjutningar.
        r = KL.para([1.0, 11.53], [3.07])
        self.assertTrue(r["osaker"])
        self.assertEqual(r["antal"], 1)
        self.assertEqual(r["nast_antal"], 1)
        self.assertAlmostEqual(r["forskjutning"], -8.46, places=9)      # lägsta d vid lika
        self.assertAlmostEqual(r["nast_bast"], 2.07, delta=0.035)   # det sanna, i sökningens steg
        # Två par räcker inte utan prior, men med.
        self.assertTrue(KL.para([1.0, 4.0], [3.0, 6.0])["osaker"])
        self.assertFalse(KL.para([1.0, 4.0], [3.0, 6.0], prior=2.0)["osaker"])

    def test_ljudets_vag(self) -> None:
        self.assertAlmostEqual(KL.ljudets_vag(3.0) * 1000, 8.746, places=3)


@unittest.skipIf(HV is None, "Golf SG finns inte här (paritetsprovet görs lokalt)")
class SomGolfSG(unittest.TestCase):
    def test_klick_som_golf_sg(self) -> None:
        for r in G.RECEPT:
            with self.subTest(r["namn"]):
                x = G.signal(r)
                a, b = KL.klick(x, r["sr"]), HV.klick(x, r["sr"])
                self.assertEqual([round(t * r["sr"]) for t, _ in a], [round(t * r["sr"]) for t, _ in b])
                for (_, s1), (_, s2) in zip(a, b):
                    self.assertEqual(s1, s2)

    def test_para_som_golf_sg(self) -> None:
        """Golf SG söker ± 3 s; förskjutningarna här ligger inom det."""
        a = np.array(G._A)
        b = np.array(G._b(2.347, 9.9))
        d_gs, rest_gs = HV.para(a, b)
        r = KL.para(a, b)
        self.assertTrue(math.isclose(r["forskjutning"], d_gs, abs_tol=1e-9))
        ok = np.abs(rest_gs) < HV.KLICK_TOL_S
        self.assertEqual([x[1] for x in r["par"]], list(np.flatnonzero(ok)))
        for x in r["par"]:
            self.assertTrue(math.isclose(x[2], rest_gs[x[1]], abs_tol=1e-9))


class Fixturen(unittest.TestCase):
    """KlickFixturer.swift är Pythons tal för recepten. Annars: kör `python3 tools/pc/klickljud.py --swift`."""

    def test_fixturen_ar_pythons_tal(self) -> None:
        fil = G.las_fixtur(G.FIXTURFIL.read_text(encoding="utf-8"))
        nu = G.fixtur()
        self.assertEqual([r["namn"] for r in fil["klick"]], [r["namn"] for r in nu["klick"]])
        for a, b in zip(fil["klick"], nu["klick"]):
            for k in ("sr", "langd_s", "fro", "brus", "klick"):
                self.assertEqual(a[k], b[k], a["namn"])
            for k in ("hela", "bitar"):
                self.assertEqual([p for p, _ in a[k]], [p for p, _ in b[k]], a["namn"])
                for (_, x), (_, y) in zip(a[k], b[k]):
                    self.assertTrue(math.isclose(x, y, rel_tol=TOL), a["namn"])
        self.assertEqual(len(fil["para"]), len(nu["para"]))
        for a, b in zip(fil["para"], nu["para"]):
            self.assertEqual((a["a"], a["b"], a["prior"]), (b["a"], b["b"], b["prior"]))
            self.assertTrue(math.isclose(a["forskjutning"], b["forskjutning"], abs_tol=TOL))
            self.assertEqual([x[:2] for x in a["par"]], [x[:2] for x in b["par"]])
            self.assertEqual((a["antal"], a["nast_antal"], a["osaker"]), (b["antal"], b["nast_antal"], b["osaker"]))


if __name__ == "__main__":
    unittest.main()
