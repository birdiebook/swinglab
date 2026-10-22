"""Måtten (METOD M6–M24, M30–M37): påhittade svingar med kända förflyttningar ger kända tal."""
from __future__ import annotations

import unittest

from _hjalp import M, mat, sving

FACIT = 0.05           # figurens tal mot mätningen: pixlarna avrundas, rutnätet har luckor
TEMPO_BIAS = 0.15      # toppen 7–10 ms tidigt av utjämningen (METOD M4)
HANDBANA = 0.15        # rutnätet och utjämningen när händerna rör sig 4–6 m/s (METOD M13)
# Farterna mot figurens exakta derivata, utan brus (METOD M35–M37, uppmätt på frön 0–19):
# anpassningen över ±3σ rundar av toppen (handen −0,6 %, största felet 9,8 cm/s; armen −0,3 %,
# 4,1 °/s), och toppens tid ligger på en flack kurva (sd 3 ms, största 6,1 ms). Handens lyft vid
# toppen: utjämningen sänker toppen och toppen ligger tidigt (−0,06 cm, största 0,18).
FARTER = {"handfart_max": 0.12, "handfart_max_fore_traff_ms": 8.0, "framre_arm_vinkelfart_max": 6.0,
          "genomsving_s": 0.008, "hand_lyft_topp": 0.2}


class KandaTal(unittest.TestCase):
    def kolla(self, vy: str, undantag: dict[str, float] = {}, **args) -> None:  # noqa: B006
        r = mat(vy=vy, **args)
        _, facit = sving(vy=vy, **args)
        for k, v in facit.items():
            if k.startswith("_"):
                continue
            with self.subTest(matt=k):
                self.assertIn(k, r["matt"])
                self.assertAlmostEqual(r["matt"][k], v, delta=undantag.get(k, FACIT))
        self.assertAlmostEqual(r["cm_per_px"], 1 / 4.0, delta=1e-4)
        self.assertEqual(set(r["matt"]), set(M.MATT[vy]))

    def test_fo(self) -> None:
        # Frö 3: frö 1 har en rå lucka på 33 ms vid handens toppfart, och då saknas toppen
        # (test_farter.Svingen.test_lucka_vid_toppfarten_ger_ingen_topp).
        self.kolla("fo", {"tempo": TEMPO_BIAS, **FARTER}, seed=3)

    def test_dtl(self) -> None:
        self.kolla("dtl", {"tempo": TEMPO_BIAS, "handbana": HANDBANA, **FARTER})

    def test_backen_sex_cm_bakat_vid_toppen(self) -> None:
        r = mat(vy="fo", sway=(0, -6, 8, 14))
        self.assertAlmostEqual(r["matt"]["backen_sway_topp"], -6.0, delta=FACIT)
        self.assertAlmostEqual(r["matt"]["backen_resa_framat"], 14.0, delta=FACIT)

    def test_andra_parametrar_och_annan_langd(self) -> None:
        andra = {"sway": (0, 3, 12, 15), "sidbojning": (10, -4, 30, 5), "armbage": (0, 40, 55, 80),
                 "stans": 36.0, "langd_m": 1.62, "seed": 7}
        self.kolla("fo", {"tempo": TEMPO_BIAS, **FARTER}, **andra)
        r = mat(vy="fo", **andra)
        self.assertLess(r["matt"]["sidbojning_topp"], 0)        # reverse spine
        self.assertAlmostEqual(r["cm_per_px"], 1 / 4.0, delta=1e-4)
        andra = {"thrust": (0, 1, -2, 5), "bojning": (35, 36, 37, 0), "over": -3.0, "kna_bak": (15, 18, 40, 5),
                 "armbage_bak": (0, 95, 10, 30), "seed": 8}
        self.kolla("dtl", {"tempo": TEMPO_BIAS, "handbana": HANDBANA, **FARTER}, **andra)
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
        self.assertAlmostEqual(r["matt"]["backen_sway_topp"], -6.0, delta=FACIT)

    def test_lang_lucka_tar_bort_matten_i_fasen_men_inget_annat(self) -> None:
        r = mat(vy="dtl", dolj=[["hoft_v", 2.0, 2.4]])
        for k in ("backen_thrust_topp", "backen_lyft_topp", "brost_bojning_topp"):
            self.assertNotIn(k, r["matt"])
        self.assertAlmostEqual(r["matt"]["backen_thrust_traff"], 3.0, delta=FACIT)
        self.assertAlmostEqual(r["matt"]["bakre_kna_topp"], 30.0, delta=FACIT)  # bakre höften syns

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


class Granserna(unittest.TestCase):
    def test_lucka_langre_an_max_lucka_saknas_kortare_interpoleras(self) -> None:
        r = mat(vy="fo", dolj=[["hoft_v", 2.135, 2.265], ["nasa", 2.175, 2.225]])
        self.assertNotIn("backen_sway_topp", r["matt"])              # 0,13 s > MAX_LUCKA_S
        self.assertAlmostEqual(r["matt"]["huvud_sway_topp"], -3.0, delta=FACIT)   # 0,05 s
        self.assertAlmostEqual(r["matt"]["backen_sway_traff"], 8.0, delta=FACIT)

    def test_konfidensen_precis_pa_gransen_raknas(self) -> None:
        r = mat(vy="dtl", konf={"hoft_v": 0.3, "kna_h": 0.29})
        self.assertAlmostEqual(r["matt"]["backen_thrust_traff"], 3.0, delta=FACIT)
        for fz in ("adress", "topp", "traff"):
            self.assertNotIn(f"bakre_kna_{fz}", r["matt"])

    def test_kort_baksving_ger_ingen_start_och_inget_tempo(self) -> None:
        r = mat(vy="dtl", start=1.95)
        self.assertIsNone(r["faser"]["start"])
        for k in ("tempo", "baksving_s", "nedsving_s"):
            self.assertNotIn(k, r["matt"])
        self.assertAlmostEqual(r["matt"]["backen_thrust_topp"], -2.0, delta=FACIT)  # adressen från toppen − 1,2 s

    def test_armbagen_mats_mot_den_egna_handleden(self) -> None:
        """Greppregeln ger händerna, inte armbågen (METOD M22, M23)."""
        r = mat(vy="fo", dolj=[["handled_v", 0.0, 9.9]])
        self.assertNotIn("framre_armbage_topp", r["matt"])
        self.assertNotIn("framre_armbage_efter_traff", r["matt"])
        self.assertIn("hander_fore_adress_traff", r["matt"])
        self.assertIn("tempo", r["matt"])


if __name__ == "__main__":
    unittest.main()
