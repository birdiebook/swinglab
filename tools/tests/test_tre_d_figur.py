"""S6d: figuren på telefonen (BESLUT B12, B72, METOD MK10).

`tools/pc/tre_d_figur.py` skriver kedjans triangulerade leder och kamerorna för tre påhittade
pass till tools/tests/fixturer/tre_d/figur.json, som SwingLabKit:s TreDFigurTests jämför med.
Här räknas de om ur fixturens egna indata, och figuren prövas mot uppställningen den filmades
i (generera_paket.tva_paket, METOD MK8). Inga riktiga leder (CLAUDE.md, Dataregeln).
"""
from __future__ import annotations

import json
import math
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from pc import generera_tre_d as GT  # noqa: E402
from pc import tre_d_figur as TF  # noqa: E402
from pc import visa as V  # noqa: E402

TMP = tempfile.TemporaryDirectory()
FIXTUR = json.loads((GT.MAPP / "figur.json").read_text(encoding="utf-8"))


class Figuren(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.nu = {namn: TF.fixtur(namn, Path(TMP.name)) for namn in TF.FIXTUR_PASS}

    def test_fixturen_ar_pythons_tal(self) -> None:
        self.assertEqual(set(FIXTUR["pass"]), set(TF.FIXTUR_PASS))
        for namn, f in self.nu.items():
            self.assertEqual(GT.lika(f, FIXTUR["pass"][namn], namn), [], "kör python3 tools/pc/tre_d_figur.py")

    def test_figuren_star_dar_den_filmades(self) -> None:
        """Utan brus: FO-kameran i origo, DTL-kameran cirka 3 m från spelaren och 90° (±5°) runt
        honom (MK8), kameran 1,0 m över marken, marken under fötterna, och träffen (P7) på
        figurens tid 0. Skalan ur benen (MK10) ger avstånden inom några cm; näsan över fotlederna
        (MK9) gav 4,0 m och 1,16 m."""
        f = self.nu["utan_brus"]
        u = f["uppstallningar"][0]
        self.assertIsNone(u["hoppat"])
        self.assertEqual(u["skala"], "langd")
        self.assertEqual(u["kameror"]["fo"]["C"], [0.0, 0.0, 0.0])
        self.assertEqual(len(f["slag"]), 10)
        for s in f["slag"]:
            P = np.array([[np.nan if v is None else v for v in rad] for rad in s["P"]]).reshape(-1, 13, 3)
            hoft = np.nanmean(P[:, [7, 8], :], axis=(0, 1))
            for vy in ("fo", "dtl"):
                avst = float(np.linalg.norm(np.array(u["kameror"][vy]["C"])[:2] - hoft[:2]))
                self.assertAlmostEqual(avst, 3.0, delta=0.2, msg=vy)
                self.assertAlmostEqual(u["kameror"][vy]["C"][2] - u["golv"], 1.0, delta=0.05, msg=vy)
            fot = float(np.nanmedian(P[:, V.FOTLEDER, 2]))
            self.assertAlmostEqual(fot - u["golv"], 0.039 * 1.80, delta=0.03)
            self.assertEqual(s["positioner"]["P7"], 0.0)
            self.assertLess(s["positioner"]["P1"], s["positioner"]["P4"])
            self.assertLess(s["positioner"]["P4"], 0.0)
            self.assertTrue(s["t0"] <= s["positioner"]["P1"] and s["t_sista"] >= s["positioner"]["P10"])
        self.assertTrue(60 <= u["vinkel"] <= 120)

    def test_over_sparren_kamerorna_men_ingen_figur(self) -> None:
        """BESLUT B72: en uppställning över spärren får kamerorna (så att uppställningen syns),
        men ingen figur, och passet bär kedjans skäl."""
        f = self.nu["sparren"]
        self.assertEqual(f["hoppat"], "kalibreringen: Sampson-felet är över spärren")
        self.assertEqual(f["slag"], [])
        u = f["uppstallningar"][0]
        self.assertEqual(u["hoppat"], f["hoppat"])
        self.assertGreater(u["sampson_px"], 8)
        self.assertIsNotNone(u["kameror"])
        self.assertTrue(all(math.isfinite(x) for x in u["kameror"]["dtl"]["C"]))

    def test_andra_ben_ger_det_vantade_felet(self) -> None:
        """Skalan antar benen 0,491 × längden (MK10). En påhittad spelare med benen 0,47 × längden
        filmad med samma slumptal ger en värld som är 0,491 / 0,47 = 4,5 % för stor: avståndet
        mellan kamerorna och kamerornas höjd över marken växer med just det, och inget annat."""
        from pc import analys as A
        from pc import generera_paket as GP
        from pc import paket as P
        ut = {}
        for ben in (None, 0.47):
            d, f, _ = GP.tva_paket(Path(TMP.name) / f"ben-{ben}", "20261103-180000", n=4, seed=5, brus="inget",
                                   ben_andel=ben)
            pd, pf = P.las(d), P.las(f)
            u = TF.figurer(pd, pf, A.mat_paket(pd, 1.80) + A.mat_paket(pf, 1.80), 1.80)["uppstallningar"][0]
            self.assertEqual(u["skala"], "langd")
            C = [np.array(u["kameror"][v]["C"]) for v in ("fo", "dtl")]
            ut[ben] = (float(np.linalg.norm(C[0] - C[1])), C[0][2] - u["golv"])
        self.assertAlmostEqual(ut[None][1], 1.0, delta=0.01)          # kamerans sanna höjd (MK8)
        for a, b in zip(ut[0.47], ut[None]):
            self.assertAlmostEqual(a / b, TF.BENETS_ANDEL / 0.47, delta=0.005)

    def test_reserven_nar_benen_saknas_eller_ar_fel(self) -> None:
        """Skyddet (MK10): utan ben, med sidor som skiljer mer än 10 %, eller med kameror som då
        hamnar orimligt, blir skalan 1 och marken okänd, med skälet."""
        def figur(v: float, h: float) -> np.ndarray:
            X = np.full((5, 13, 3), np.nan)
            for (hi, ki, fi), langd in zip(TF.BEN, (v, h)):
                X[:, hi] = [0.0, 0.0, langd]
                X[:, ki] = [0.0, 0.0, langd / 2]
                X[:, fi] = [0.0, 0.0, 0.0]
            X[:, TF.BEN[1], 1] = 0.3
            return X
        rutor = np.arange(5)
        kam = [np.array([0.0, -1.8, 0.58])]                   # 3,4 m bort och 1,1 m upp med benen 0,5
        ok = TF.skala([(figur(0.5, 0.5), rutor)], 1.80, kam)
        self.assertEqual(ok["skala"], "langd")
        self.assertIsNone(ok["skala_fel"])
        self.assertAlmostEqual(ok["golv"], -0.039 * 1.80)
        for X, kameror, skal in ((figur(0.5, 0.6), kam, "benen skiljer mer än 10 % mellan sidorna"),
                                 (np.full((5, 13, 3), np.nan), kam, "benen syns inte i adressen"),
                                 (figur(0.5, 0.5), [np.array([0.0, -30.0, 0.58])],
                                  "kamerorna hamnar orimligt med benens skala"),
                                 (figur(0.5, 0.5), [np.array([0.0, -1.8, 20.0])],
                                  "kamerorna hamnar orimligt med benens skala")):
            r = TF.skala([(X, rutor)], 1.80, kameror)
            self.assertEqual(r, {"skala": "kamerorna", "skala_m": 1.0, "golv": None, "skala_fel": skal})
        # Adressens rutor: fram till P1 + 0,15 s, annars de första 0,3 s.
        t = np.arange(-1.5, 1.0, 1 / 240)
        self.assertAlmostEqual(t[TF.adressens_rutor(t, {"P1": -1.2})[-1]], -1.05, delta=1 / 240)
        self.assertAlmostEqual(t[TF.adressens_rutor(t, {})[-1]], -1.2, delta=1 / 240)

    def test_vanster_och_positionerna_pa_dtl_utan_fo(self) -> None:
        """En vänsterspelare speglas inte i figuren (bara i måtten, MK6), och en position som FO
        saknar tas ur DTL flyttad med synken."""
        self.assertEqual(self.nu["bra_brus_vanster"]["hand"], "vanster")
        d = {"traffA": 0.1, "traffB": 0.2}
        p = TF.positioner({"positioner": {"P1": -1.0, "P3": None}}, {"positioner": {"P3": -0.5, "P1": -2.0}}, d, 0.004)
        self.assertAlmostEqual(p["P1"], -1.1)
        self.assertAlmostEqual(p["P3"], -0.5 - 0.204)
        self.assertNotIn("P4", p)


if __name__ == "__main__":
    unittest.main()
