"""Måtten (METOD M6–M24, M30–M39, M41–M43): påhittade svingar med kända förflyttningar ger kända tal."""
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
# Axlarna vridna i bildens plan vid toppen (METOD M39): utan det skymmer de varandra
# bakifrån, och främre armen mot axellinjen saknas. Armens vinkel vid toppen: utjämningen
# sänker handleden i toppen (som handens lyft), uppmätt −0,03° i snitt, största 0,10°.
AXLAR = {"axel_dx": (1.5, 16, 1.5, 1.5), "axel_dz": (0, -11, 0, 0)}
ARM_PLAN = {"framre_arm_plan_topp": 0.15}
# Tilläggen ur research 5 (METOD M41–M43, uppmätt på frön 0–19 utan brus): skiftets tid räknas
# från den uppmätta toppen, som ligger ≈ 9 ms tidigt (M4), så talet blir ≈ 9 ms för långt
# (största 13 ms); själva passagen ligger inom 4 ms. Bäckenets lägsta punkt: utjämningen
# höjer en dal (största 0,09 cm).
S1E = {"backen_skifte_ms": 15.0, "backen_lyft_min": 0.1, "backen_lyft_in_traff": 0.1}
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
        self.kolla("fo", {"tempo": TEMPO_BIAS, **FARTER, **S1E}, seed=3)

    def test_dtl(self) -> None:
        self.kolla("dtl", {"tempo": TEMPO_BIAS, "handbana": HANDBANA, **FARTER, **ARM_PLAN, **S1E}, **AXLAR)

    def test_backen_sex_cm_bakat_vid_toppen(self) -> None:
        r = mat(vy="fo", sway=(0, -6, 8, 14))
        self.assertAlmostEqual(r["matt"]["backen_sway_topp"], -6.0, delta=FACIT)
        self.assertAlmostEqual(r["matt"]["backen_resa_framat"], 14.0, delta=FACIT)

    def test_andra_parametrar_och_annan_langd(self) -> None:
        andra = {"sway": (0, 3, 12, 15), "sidbojning": (10, -4, 30, 5), "armbage": (0, 40, 55, 80),
                 "stans": 36.0, "langd_m": 1.62, "seed": 7}
        self.kolla("fo", {"tempo": TEMPO_BIAS, **FARTER, **S1E}, **andra)
        r = mat(vy="fo", **andra)
        self.assertLess(r["matt"]["sidbojning_topp"], 0)        # reverse spine
        self.assertAlmostEqual(r["cm_per_px"], 1 / 4.0, delta=1e-4)
        andra = {"thrust": (0, 1, -2, 5), "bojning": (35, 36, 37, 0), "over": -3.0, "kna_bak": (15, 18, 40, 5),
                 "armbage_bak": (0, 95, 10, 30), "seed": 8, "axel_dx": (1.5, 14, 1.5, 1.5), "axel_dz": (0, -14, 0, 0)}
        self.kolla("dtl", {"tempo": TEMPO_BIAS, "handbana": HANDBANA, **FARTER, **ARM_PLAN, **S1E}, **andra)
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
        for k in ("tempo", "baksving_s"):
            self.assertNotIn(k, r["matt"])
        # Nedsvingens tid kräver ingen start: toppen till klicket (METOD M5).
        self.assertAlmostEqual(r["matt"]["nedsving_s"], r["faser"]["traff"] - r["faser"]["topp"], delta=1e-12)
        self.assertAlmostEqual(r["matt"]["backen_thrust_topp"], -2.0, delta=FACIT)  # adressen från toppen − 1,2 s

    def test_armbagen_mats_mot_den_egna_handleden(self) -> None:
        """Greppregeln ger händerna, inte armbågen (METOD M22, M23)."""
        r = mat(vy="fo", dolj=[["handled_v", 0.0, 9.9]])
        self.assertNotIn("framre_armbage_topp", r["matt"])
        self.assertNotIn("framre_armbage_efter_traff", r["matt"])
        self.assertIn("hander_fore_adress_traff", r["matt"])
        self.assertIn("tempo", r["matt"])



class TillaggenBakifran(unittest.TestCase):
    """PLAN S1c: händernas djup och främre armen mot axellinjen vid toppen (METOD M38, M39)."""

    def test_handernas_djup(self) -> None:
        r = mat(vy="dtl", **AXLAR)
        self.assertAlmostEqual(r["matt"]["hand_djup_topp"], -20.0, delta=FACIT)     # 20 cm från bollen
        self.assertIn("hand_djup_topp", mat(vy="dtl")["matt"])                       # kräver inga axlar

    def test_armen_over_och_under_axellinjen(self) -> None:
        over = mat(vy="dtl", **AXLAR)                                                # axellinjen 34,5°
        _, f = sving(vy="dtl", **AXLAR)
        self.assertAlmostEqual(f["framre_arm_plan_topp"], 6.1, delta=0.05)
        self.assertAlmostEqual(over["matt"]["framre_arm_plan_topp"], 6.1, delta=0.15)
        brant = dict(AXLAR, axel_dz=(0, -20, 0, 0))                                  # axellinjen 51°
        under = mat(vy="dtl", **brant)
        self.assertLess(under["matt"]["framre_arm_plan_topp"], -2.5)
        self.assertGreater(under["matt"]["framre_arm_plan_topp"], -3.5)

    def test_saknas_nar_axlarna_skymmer_varandra(self) -> None:
        """Standardfiguren har axlarna 3 cm isär i bild: under AXLAR_MIN_CM saknas vinkeln."""
        self.assertNotIn("framre_arm_plan_topp", mat(vy="dtl")["matt"])
        self.assertNotIn("framre_arm_plan_topp", sving(vy="dtl")[1])
        kort = dict(AXLAR, axel_dx=(1.5, 5.5, 1.5, 1.5), axel_dz=(0, -4.0, 0, 0))   # 13,6 cm
        self.assertNotIn("framre_arm_plan_topp", mat(vy="dtl", **kort)["matt"])
        lang = dict(AXLAR, axel_dx=(1.5, 6.5, 1.5, 1.5), axel_dz=(0, -4.0, 0, 0))   # 15,3 cm
        self.assertIn("framre_arm_plan_topp", mat(vy="dtl", **lang)["matt"])

    def test_saknas_utan_framre_axeln_eller_handleden(self) -> None:
        self.assertNotIn("framre_arm_plan_topp", mat(vy="dtl", dolj=[["axel_v", 2.0, 2.4]], **AXLAR)["matt"])
        r = mat(vy="dtl", dolj=[["handled_v", 2.0, 2.4]], **AXLAR)
        self.assertNotIn("framre_arm_plan_topp", r["matt"])                          # den egna handleden
        self.assertIn("hand_djup_topp", r["matt"])                                   # greppregeln ger greppet

    def test_vansterspelaren_ger_samma_tal(self) -> None:
        h, v = mat(vy="dtl", seed=5, **AXLAR), mat(vy="dtl", seed=5, hand="vanster", **AXLAR)
        for k in ("hand_djup_topp", "framre_arm_plan_topp"):
            self.assertAlmostEqual(h["matt"][k], v["matt"][k], delta=1e-6)


class TillaggenUrResearch5(unittest.TestCase):
    """PLAN S1e: recentreringen och skiftet (FO), bäckenets lägsta punkt och lyftet in i
    träffen (båda vyerna). METOD M41–M43"""

    def test_mot_figuren(self) -> None:
        for vy, andra in (("fo", {"sway_ut": -3.0, "lyft_ned": -4.0, "seed": 3}), ("dtl", {"lyft_ned": -3.0})):
            r = mat(vy=vy, **andra)
            _, f = sving(vy=vy, **andra)
            for k in ("backen_recentrering", "backen_skifte_ms", "backen_lyft_min", "backen_lyft_in_traff"):
                if k in f:
                    with self.subTest(vy=vy, matt=k):
                        self.assertAlmostEqual(r["matt"][k], f[k], delta=S1E.get(k, FACIT))
            self.assertLess(r["matt"]["backen_lyft_min"], 0)                     # under adressen
            # Lyftet in i träffen är träffens lyft minus den lägsta punkten.
            self.assertAlmostEqual(r["matt"]["backen_lyft_in_traff"],
                                   r["matt"]["backen_lyft_traff"] - r["matt"]["backen_lyft_min"], delta=1e-9)
        self.assertNotIn("backen_recentrering", mat(vy="dtl")["matt"])            # bara FO

    def test_recentreringen(self) -> None:
        _, f = sving(vy="fo", sway_ut=-3.0)
        self.assertGreater(f["backen_recentrering"], 1.0)                           # glider bort, sedan tillbaka
        self.assertAlmostEqual(mat(vy="fo")["matt"]["backen_recentrering"], 0.0, delta=FACIT)   # ingen glidning
        self.assertAlmostEqual(mat(vy="fo", sway=(0, 2, 8, 14))["matt"]["backen_recentrering"], 2.0, delta=FACIT)

    def test_skiftet(self) -> None:
        # Redan framför adressläget vid toppen: 0 ms.
        self.assertEqual(mat(vy="fo", sway=(0, 2, 8, 14))["matt"]["backen_skifte_ms"], 0.0)
        # Aldrig tillbaka före träffen: saknas.
        self.assertNotIn("backen_skifte_ms", mat(vy="fo", sway=(0, -6, -1, 14))["matt"])
        tidigt = mat(vy="fo", sway=(0, -2, 8, 14))["matt"]["backen_skifte_ms"]
        sent = mat(vy="fo", sway=(0, -10, 8, 14))["matt"]["backen_skifte_ms"]
        self.assertLess(tidigt, sent)

    def test_lucka_ger_inget_tal(self) -> None:
        """En rå lucka längre än MAX_LUCKA_S i fönstret: ytterläget kan ligga i luckan."""
        r = mat(vy="fo", sway_ut=-3.0, dolj=[["hoft_v", 1.70, 1.85]])
        self.assertNotIn("backen_recentrering", r["matt"])
        self.assertIn("backen_lyft_min", r["matt"])                                 # nedsvingen är hel
        r = mat(vy="dtl", dolj=[["hoft_v", 2.30, 2.45]])
        self.assertNotIn("backen_lyft_min", r["matt"])
        self.assertNotIn("backen_lyft_in_traff", r["matt"])

    def test_vansterspelaren_ger_samma_tal(self) -> None:
        h, v = mat(vy="fo", seed=5, sway_ut=-3.0), mat(vy="fo", seed=5, hand="vanster", sway_ut=-3.0)
        for k in ("backen_recentrering", "backen_skifte_ms", "backen_lyft_min", "backen_lyft_in_traff"):
            self.assertAlmostEqual(h["matt"][k], v["matt"][k], delta=1e-6)


if __name__ == "__main__":
    unittest.main()
