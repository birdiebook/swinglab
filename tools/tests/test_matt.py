"""Måtten (METOD M6–M24): påhittade svingar med kända förflyttningar ger kända tal."""
from __future__ import annotations

import unittest

from _hjalp import M, mat, sving

AVRUNDNING = 0.05      # samma som Swift mot Python
TEMPO_BIAS = 0.15      # toppen 7–10 ms tidigt av utjämningen (METOD M4)
HANDBANA = 0.15        # rutnätet och utjämningen när händerna rör sig 4–6 m/s (METOD M13)


class KandaTal(unittest.TestCase):
    def kolla(self, vy: str, undantag: dict[str, float] = {}, **args) -> None:  # noqa: B006
        r = mat(vy=vy, **args)
        _, facit = sving(vy=vy, **args)
        for k, v in facit.items():
            if k.startswith("_"):
                continue
            with self.subTest(matt=k):
                self.assertIn(k, r["matt"])
                self.assertAlmostEqual(r["matt"][k], v, delta=undantag.get(k, AVRUNDNING))
        self.assertAlmostEqual(r["cm_per_px"], 1 / 4.0, delta=1e-4)
        self.assertEqual(set(r["matt"]), set(M.MATT[vy]))

    def test_fo(self) -> None:
        self.kolla("fo", {"tempo": TEMPO_BIAS})

    def test_dtl(self) -> None:
        self.kolla("dtl", {"tempo": TEMPO_BIAS, "handbana": HANDBANA})

    def test_backen_sex_cm_bakat_vid_toppen(self) -> None:
        r = mat(vy="fo", sway=(0, -6, 8, 14))
        self.assertAlmostEqual(r["matt"]["backen_sway_topp"], -6.0, delta=AVRUNDNING)
        self.assertAlmostEqual(r["matt"]["backen_resa_framat"], 14.0, delta=AVRUNDNING)

    def test_andra_parametrar_och_annan_langd(self) -> None:
        andra = {"sway": (0, 3, 12, 15), "sidbojning": (10, -4, 30, 5), "armbage": (0, 40, 55, 80),
                 "stans": 36.0, "langd_m": 1.62, "seed": 7}
        self.kolla("fo", {"tempo": TEMPO_BIAS}, **andra)
        r = mat(vy="fo", **andra)
        self.assertLess(r["matt"]["sidbojning_topp"], 0)        # reverse spine
        self.assertAlmostEqual(r["cm_per_px"], 1 / 4.0, delta=1e-4)
        andra = {"thrust": (0, 1, -2, 5), "bojning": (35, 36, 37, 0), "over": -3.0, "kna_bak": (15, 18, 40, 5),
                 "armbage_bak": (0, 95, 10, 30), "seed": 8}
        self.kolla("dtl", {"tempo": TEMPO_BIAS, "handbana": HANDBANA}, **andra)
        self.assertLess(mat(vy="dtl", **andra)["matt"]["handbana"], 0)       # innanför

    def test_tecknen(self) -> None:
        fo, dtl = mat(vy="fo"), mat(vy="dtl")
        self.assertGreater(fo["matt"]["backen_sway_traff"], 0)              # + mot målet
        self.assertGreater(fo["matt"]["sidbojning_traff"], 0)               # + bort från målet
        self.assertGreater(fo["matt"]["axellinje_lutning_traff"], 0)        # + bakre axeln lägre
        self.assertGreater(dtl["matt"]["backen_thrust_traff"], 0)           # + mot bollen
        self.assertGreater(dtl["matt"]["brost_bojning_adress"], 0)          # + framåtböjd
        self.assertGreater(dtl["matt"]["handbana"], 0)                      # + utanför = over the top
        self.assertGreater(dtl["matt"]["backen_lyft_traff"], 0)             # + uppåt


class Speglat(unittest.TestCase):
    def test_vansterspelaren_ger_samma_tal(self) -> None:
        for vy in ("fo", "dtl"):
            h, v = mat(vy=vy, seed=5), mat(vy=vy, seed=5, hand="vanster")
            self.assertEqual(set(h["matt"]), set(v["matt"]))
            for k in h["matt"]:
                with self.subTest(vy=vy, matt=k):
                    self.assertAlmostEqual(h["matt"][k], v["matt"][k], delta=1e-6)


class SaknadeLeder(unittest.TestCase):
    def test_kort_lucka_fylls(self) -> None:
        r = mat(vy="fo", dolj=[["hoft_v", 2.18, 2.205]])
        self.assertAlmostEqual(r["matt"]["backen_sway_topp"], -6.0, delta=AVRUNDNING)

    def test_lang_lucka_tar_bort_matten_i_fasen_men_inget_annat(self) -> None:
        r = mat(vy="dtl", dolj=[["hoft_v", 2.0, 2.4]])
        for k in ("backen_thrust_topp", "backen_lyft_topp", "brost_bojning_topp"):
            self.assertNotIn(k, r["matt"])
        self.assertAlmostEqual(r["matt"]["backen_thrust_traff"], 3.0, delta=AVRUNDNING)
        self.assertAlmostEqual(r["matt"]["bakre_kna_topp"], 30.0, delta=AVRUNDNING)  # bakre höften syns

    def test_en_dold_handled_ersatts_av_den_andra(self) -> None:
        r = mat(vy="dtl", dolj=[["handled_v", 0.0, 9.9]])
        self.assertAlmostEqual(r["faser"]["topp"], mat(vy="dtl")["faser"]["topp"], delta=0.002)
        self.assertAlmostEqual(r["matt"]["handbana"], mat(vy="dtl")["matt"]["handbana"], delta=0.05)

    def test_ingen_skala_utan_benen_i_adressen(self) -> None:
        from pc import faser as F
        from pc import format as fm
        d, _ = sving(vy="fo", dolj=[["fotled_v", 0.0, 1.5]])
        with self.assertRaises(F.SvingFel):
            M.mat(fm.fran_dict(d))


class Brus(unittest.TestCase):
    def test_brus_flyttar_talen_lite(self) -> None:
        """0,8 px brus (≈ 2 mm): lägena håller sig inom 0,5 cm och 1,5°."""
        r = mat(vy="fo", seed=9, brus_px=0.8)
        _, facit = sving(vy="fo", seed=9, brus_px=0.8)
        for k in ("backen_sway_topp", "backen_sway_traff", "huvud_sway_topp", "brost_sway_traff"):
            self.assertAlmostEqual(r["matt"][k], facit[k], delta=0.5)
        for k in ("sidbojning_topp", "framre_armbage_topp", "hoftlinje_lutning_traff"):
            self.assertAlmostEqual(r["matt"][k], facit[k], delta=1.5)


if __name__ == "__main__":
    unittest.main()
