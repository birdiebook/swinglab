"""Swift-fixturerna (SwingLabKit/Tests/SwingTests/Fixturer.swift) är Pythons tal
för samma indata (BESLUT B12). Ändras koden i tools/pc utan att fixturerna
skrivs om fäller testet: kör `python3 tools/pc/generera.py --swift`.

Talen jämförs med tolerans, inte som text: numpy och BLAS kan skilja i sista
decimalen mellan datorer.
"""
from __future__ import annotations

import json
import math
import unittest

from _hjalp import fm, gen
from pc import katalog as K
from pc import matt as M
from pc import session as S

TOL = 1e-9


def _lika(test: unittest.TestCase, a, b, vag: str = "") -> None:
    if isinstance(a, dict):
        test.assertEqual(set(a), set(b), vag)
        for k in a:
            _lika(test, a[k], b[k], f"{vag}.{k}")
    elif isinstance(a, list):
        test.assertEqual(len(a), len(b), vag)
        for i, (x, y) in enumerate(zip(a, b)):
            _lika(test, x, y, f"{vag}[{i}]")
    elif isinstance(a, float) or isinstance(b, float):
        test.assertTrue(math.isclose(a, b, rel_tol=TOL, abs_tol=TOL), f"{vag}: {a} != {b}")
    else:
        test.assertEqual(a, b, vag)


class Fixturerna(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.f = gen.las_fixturer(gen.FIXTURFIL.read_text(encoding="utf-8"))

    def test_katalogen_ar_ordagrann(self) -> None:
        self.assertEqual(self.f["katalog"], K.KATALOG.read_text(encoding="utf-8").rstrip("\n"))

    def test_svingarna_finns(self) -> None:
        self.assertEqual(list(self.f["svingar"]), list(gen.FIXTURSVINGAR))

    def test_pythons_tal_stammer_for_varje_sving(self) -> None:
        for namn, (indata, python) in self.f["svingar"].items():
            with self.subTest(sving=namn):
                _lika(self, json.loads(python), gen.resultat_json(indata), namn)

    def test_svingarna_provar_det_de_ska(self) -> None:
        """Kvittot: fixturerna täcker båda vyerna, vänsterhand, ojämna tider och luckor."""
        s = {n: fm.las(i) for n, (i, _) in self.f["svingar"].items()}
        self.assertEqual({x.vy for x in s.values()}, {"fo", "dtl"})
        self.assertEqual(s["fo_vanster"].hand, "vanster")
        steg = s["fo"].t[1:] - s["fo"].t[:-1]
        self.assertGreater(steg.max(), 1.5 / 240)
        lucka = json.loads(self.f["svingar"]["dtl_lucka"][1])["matt"]
        self.assertNotIn("backen_thrust_topp", lucka)
        self.assertNotIn("huvud_lyft_finish", lucka)
        self.assertEqual(len(json.loads(self.f["svingar"]["dtl"][1])["matt"]), len(M.MATT["dtl"]))
        vanster = json.loads(self.f["svingar"]["fo_vanster"][1])["matt"]
        self.assertNotIn("framre_armbage_topp", vanster)          # den egna handleden är dold
        self.assertIn("hander_fore_adress_traff", vanster)         # men greppregeln ger händerna
        luckor = json.loads(self.f["svingar"]["fo_luckor"][1])["matt"]
        self.assertNotIn("backen_sway_topp", luckor)               # rå lucka 0,146 s
        self.assertIn("huvud_sway_topp", luckor)                   # rå lucka 0,067 s
        kort = json.loads(self.f["svingar"]["dtl_kort"][1])
        self.assertIsNone(kort["faser"]["start"])
        self.assertNotIn("tempo", kort["matt"])
        self.assertNotIn("bakre_kna_adress", kort["matt"])        # konfidens 0,29
        self.assertIn("backen_thrust_traff", kort["matt"])         # konfidens 0,3

    def test_sessionen_stammer(self) -> None:
        s = json.loads(self.f["session"])
        sn, sf = S.sammanfatta_session(s["nu"]), S.sammanfatta_session(s["forra"])
        _lika(self, s["sammanfattning"], {"nu": sn, "forra": sf}, "sammanfattning")
        _lika(self, s["jamforelse"], {g: S.jamfor(sn[g], sf[g]) for g in sn}, "jamforelse")
        _lika(self, s["bedomning"], K.bedom(K.las(), s["nu"], s["forra"]), "bedomning")
        self.assertEqual({b["status"] for b in s["bedomning"]} >= {"gul", "gron", "av", "okand"}, True)


if __name__ == "__main__":
    unittest.main()
