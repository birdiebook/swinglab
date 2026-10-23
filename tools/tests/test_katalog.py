"""Katalogen (katalog.json, BESLUT B6) och bedömningen (METOD M27)."""
from __future__ import annotations

import json
import unittest

from _hjalp import gen
from pc import att_jobba_pa as AJ
from pc import katalog as K
from pc import klubba as KL
from pc import session as S


def _fel(id_: str) -> dict:
    return next(f for f in K.las()["fel"] if f["id"] == id_)


class Formen(unittest.TestCase):
    def test_katalogen_ar_hel(self) -> None:
        k = K.las()
        self.assertEqual(K.kontrollera(k), [])
        ids = {f["id"] for f in k["fel"]}
        for id_ in ("sway_topp", "tempo", "early_extension", "tappad_hallning", "backens_resa_framat", "sway_gap",
                    "axellutning", "reverse_spine", "chicken_wing", "flying_elbow", "over_the_top",
                    "bojd_framre_arm"):
            self.assertIn(id_, ids)

    def test_positionerna_enligt_skissen(self) -> None:
        """BESLUT B32: kopplingen mått → position (design/skiss.html, PM)."""
        k = K.las()
        pos = {f["id"]: f["positioner"] for f in k["fel"]}
        self.assertEqual(pos["sway_topp"], ["P4"])
        self.assertEqual(pos["over_the_top"], ["P5"])
        self.assertEqual(pos["early_extension"], ["P7"])
        self.assertEqual(pos["chicken_wing"], ["P9"])
        self.assertEqual(pos["tempo"], [])                    # hela svingen
        self.assertEqual(pos["backens_resa_framat"], [])      # resan visas vid P5, som måttet hittills
        self.assertEqual(pos["tappad_hallning"], ["P7"])      # avvikelse mot skissen (METOD M29)
        matt = {(m["vy"], m["matt"]): m["positioner"] for m in k["matt"]}
        self.assertEqual(matt[("fo", "backen_sway_p3")], ["P3"])
        self.assertEqual(matt[("fo", "framre_armbage_p3")], ["P3"])
        self.assertEqual(matt[("fo", "backen_resa_p5")], ["P5"])
        self.assertEqual(matt[("fo", "huvud_backen_finish")], ["P10"])
        self.assertEqual(matt[("dtl", "brost_bojning_adress")], ["P1"])
        # Accenten (B31) följer felet: sway hittills hör till sway-felet, resan till resans.
        kopplat = {m["matt"]: m.get("fel") for m in k["matt"]}
        self.assertEqual(kopplat["backen_sway_p3"], "sway_topp")
        self.assertEqual(kopplat["backen_resa_p5"], "backens_resa_framat")
        self.assertIsNone(kopplat["stans_bredd"])
        # Tilläggen mot Sportsbox (PLAN S1b, METOD M30–M37) och ur research 5 (PLAN S1e).
        self.assertEqual(len(k["matt"]), 62)
        self.assertEqual(kopplat["bakre_kna_sway_topp"], "sway_topp")
        self.assertIsNone(kopplat["backen_bojning_traff"])       # visar inte early extension (METOD M30)
        self.assertEqual(matt[("dtl", "brost_lyft_traff")], ["P7"])
        self.assertEqual(matt[("fo", "genomsving_s")], ["P10"])
        self.assertEqual(matt[("fo", "handfart_max_fore_traff_ms")], ["P7"])
        # Tilläggen bakifrån (PLAN S1c, METOD M38–M39): vid toppen, utan fel.
        self.assertEqual(matt[("dtl", "hand_djup_topp")], ["P4"])
        self.assertEqual(matt[("dtl", "framre_arm_plan_topp")], ["P4"])
        self.assertIsNone(kopplat["hand_djup_topp"])
        self.assertIsNone(kopplat["framre_arm_plan_topp"])
        # Tilläggen ur research 5 (PLAN S1e, METOD M41–M43, M5, M14, M18): utan fel.
        self.assertEqual(matt[("fo", "backen_recentrering")], ["P4"])
        self.assertEqual(matt[("fo", "backen_skifte_ms")], ["P5"])
        for vy in ("dtl", "fo"):
            self.assertEqual(matt[(vy, "backen_lyft_min")], ["P5"])
            self.assertEqual(matt[(vy, "backen_lyft_in_traff")], ["P7"])
            self.assertEqual(matt[(vy, "nedsving_s")], ["P7"])
        self.assertEqual(matt[("fo", "sidbojning_finish")], ["P10"])
        self.assertEqual(matt[("fo", "hoftlinje_lutning_topp")], ["P4"])
        self.assertEqual(matt[("fo", "hoftlinje_lutning_traff")], ["P7"])
        for m in ("backen_recentrering", "backen_skifte_ms", "backen_lyft_min", "backen_lyft_in_traff",
                  "sidbojning_finish", "nedsving_s", "hoftlinje_lutning_topp", "hoftlinje_lutning_traff"):
            self.assertIsNone(kopplat[m], m)
        # Farterna är oprövade på telefonen (METOD M35–M37, BESLUT B11), inget annat.
        oprovade = {m["matt"] for m in k["matt"] if m.get("status") == "oprovad"}
        self.assertEqual(oprovade, {"handfart_max", "handfart_max_fore_traff_ms", "framre_arm_vinkelfart_max",
                                    "genomsving_s"})                                   # också finishens fart (M36)
        # Huvudet (METOD M8, M9) vid toppen och träffen, utan fel (Johannes 2026-10-23).
        self.assertEqual(matt[("dtl", "huvud_mot_bollen_topp")], ["P4"])
        self.assertEqual(matt[("dtl", "huvud_lyft_traff")], ["P7"])
        self.assertEqual(matt[("fo", "huvud_lyft_topp")], ["P4"])
        self.assertIsNone(kopplat["huvud_mot_bollen_traff"])
        # Varje position utom P2, P6 och P8 visar något ur kroppen; de tre bara klubbans mått (S7a).
        kroppen = {p for v in pos.values() for p in v} | {p for (vy, m), v in matt.items() for p in v
                                                          if m not in KL.katalognamn(vy)}
        self.assertEqual(kroppen, {"P1", "P3", "P4", "P5", "P7", "P9", "P10"})
        self.assertEqual(matt[("dtl", "skaft_vinkel")], list(KL.POSITIONER))
        self.assertEqual(matt[("dtl", "skaft_mot_plan_p2")], ["P2"])
        self.assertEqual(matt[("fo", "skaft_arm_p6")], ["P6"])
        self.assertTrue(all("fel" not in m for m in k["matt"] if m["matt"] in KL.katalognamn(m["vy"])))

    def test_kallorna_efter_research_5(self) -> None:
        """BESLUT B10, B45: research 5 läste källorna i original 2026-10-23. Bara flying elbow
        har kvar en källa som inte är läst; gränserna med källa är härledda ur Sportsbox."""
        k = K.las()
        for f in k["fel"]:
            self.assertEqual(f["kontrollerad"], f["id"] != "flying_elbow", f["id"])
            self.assertTrue(all(u.startswith("https://") for u in f["kalla"].split(" · ")), f["id"])
        med_grans = {f["id"] for f in k["fel"] if f["gront"] is not None}
        self.assertEqual(med_grans, {"sway_topp", "tempo", "early_extension"})
        self.assertEqual({f["id"] for f in k["fel"] if f.get("grans_harledd")}, {"sway_topp", "early_extension"})
        self.assertEqual(_fel("sway_gap")["samre"], "-")                     # + = bröstet bakom (M19)
        self.assertIsNone(_fel("sway_gap")["gront"])                         # gränsen beror på klubban
        self.assertIsNone(_fel("tappad_hallning")["gront"])

    def test_spridningen(self) -> None:
        """METOD M44, BESLUT B46: bröstets böjning i adressen och vid träffen, bakifrån."""
        k = K.las()
        self.assertEqual([(e["vy"], e["matt"]) for e in k["spridning"]],
                         [("dtl", "brost_bojning_adress"), ("dtl", "brost_bojning_traff")])
        nu = gen.session(21, 10, 9, utslag=True)
        s = K.spridning(k, nu)
        dtl = S.sammanfatta([x["matt"] for x in nu if x["vy"] == "dtl"])
        for e in s:
            self.assertAlmostEqual(e["varde"], S.robust_sd(dtl[e["matt"]]), delta=1e-12)
            self.assertEqual(e["n"], 9)
        sju = [x for x in nu if x["vy"] == "dtl"][:7]
        self.assertEqual([(e["n"], e["varde"]) for e in K.spridning(k, sju)], [(7, None), (7, None)])   # under 8
        ett = [x for x in nu if x["vy"] == "dtl"][:1]
        self.assertEqual([e["n"] for e in K.spridning(k, ett)], [1, 1])               # det verkliga antalet
        hand = [{"vy": "dtl", "matt": {"brost_bojning_traff": v}} for v in (30.0, 31.0, 32.0, 33.0, 34.0, 35.0, 36.0, 50.0)]
        # q1 = 31,75, q3 = 35,25 (linjärt, M25): IQR 3,5.
        self.assertAlmostEqual(K.spridning(k, hand)[1]["varde"], 3.5 / 1.349, delta=1e-12)

    def test_infobladet_finns_overallt(self) -> None:
        """BESLUT B41: varje fel och varje mått har vad, varfor och tecken, korta och
        på engelska (test_engelska fäller svenska tecken), vad och varfor som en mening."""
        k = K.las()
        for e in k["fel"] + k["matt"]:
            namn = e.get("id", e["matt"])
            for f in K.INFO:
                with self.subTest(post=namn, falt=f):
                    self.assertIsInstance(e[f], str)
                    self.assertTrue(e[f].strip())
                    self.assertLessEqual(len(e[f]), 120)
            self.assertTrue(e["vad"].endswith(".") and e["varfor"].endswith("."), namn)
            for f in K.INFO:                                     # inga värdeord (BESLUT B13)
                self.assertIsNone(AJ.vardeord(e[f]), f"{namn}.{f}")
        self.assertEqual(len(k["fel"]) + len(k["matt"]), 74)
        for e in k["spridning"]:
            for f in K.INFO:
                self.assertTrue(e[f].strip() and len(e[f]) <= 120, e["matt"])
                self.assertIsNone(AJ.vardeord(e[f]), e["matt"])

    def test_axellutningen_ar_avstangd_utan_grans(self) -> None:
        f = _fel("axellutning")
        self.assertFalse(f["aktiv"])
        self.assertIsNone(f["gront"])

    # Samma fall som KatalogTests.swift (formfel): (från, till, väntat fel).
    FORMFEL = [
        ('"matt": "backen_sway_topp"', '"matt": "finns_inte"', "sway_topp: måttet finns inte i vyn"),
        ('"vy": "bada"', '"vy": "sida"', "tempo: vy ska vara"),
        ('"status": "tillverkare"', '"status": "rykte"', "sway_topp: status ska vara"),
        ('"samre": "-"', '"samre": "x"', "sway_topp: samre ska vara"),
        ('"gront": [-2.5, null]', '"gront": null', "sway_topp: gult utan gront"),
        ('"id": "tempo"', '"id": "sway_topp"', "sway_topp: id finns två gånger"),
        ('"gront": [2.5, 3.1]', '"gront": [2.5]', "tempo: gront ska vara"),
        ('"positioner": ["P4"]', '"positioner": ["P2"]', "sway_topp: positioner ska vara"),
        ('"positioner": ["P4"]', '"positioner": ["P4", "P1"]', "sway_topp: positioner ska vara"),
        ('"positioner": ["P4"]', '"positioner": ["P4", "P4"]', "sway_topp: positioner ska vara"),
        ('{"matt": "backen_sway_p3", "vy": "fo"', '{"matt": "backen_sway_p3", "vy": "dtl"',
         "matt backen_sway_p3: måttet finns inte i vyn"),
        ('{"matt": "stans_bredd"', '{"matt": "backen_sway_topp"', "matt backen_sway_topp: står redan i katalogen"),
        ('"positioner": ["P10"]', '"positioner": []', "matt huvud_backen_finish: positioner ska vara"),
        ('{"matt": "stans_bredd", "vy": "fo"', '{"matt": "stans_bredd", "vy": "bada"', "matt stans_bredd: vy ska vara"),
        ('"fel": "sway_topp"}', '"fel": "finns_inte"}', "matt backen_sway_p3: fel ska vara ett fel i katalogen"),
        ('{"matt": "stans_bredd", "vy": "fo",', '{"matt": "stans_bredd", "x": 1, "vy": "fo",',
         "matt stans_bredd: ska ha matt, vy, positioner, vad, varfor och tecken, och får ha fel"),
        # Infobladet (BESLUT B41).
        ('"vad": "Ankle width', '"vadd": "Ankle width',
         "matt stans_bredd: ska ha matt, vy, positioner, vad, varfor och tecken, och får ha fel"),
        ('"tecken": "1.0 = as wide as the shoulders"', '"tecken": " "', "matt stans_bredd: tecken ska vara en text"),
        ('"varfor": "Shows a slide away', '"varfor": "", "x": "Sliding away', "sway_topp: varfor ska vara en text"),
        ('"status": "oprovad"}', '"status": "provad"}', "matt genomsving_s: status ska vara oprovad"),
        ('"grans_harledd": true', '"grans_harledd": 1', "sway_topp: grans_harledd ska vara"),
        ('"samre": "-",', "", "sway_topp: samre saknas"),
        ('"ovning":', '"ovn":', "sway_topp: ovning saknas"),
        ('"positioner": ["P4"],', "", "sway_topp: positioner saknas"),
        ('"vad": "Backswing time', '"vadd": "Backswing time', "tempo: vad saknas"),
        ('"matt": [\n', '"mått": [\n', "katalogen: listan matt saknas"),
        # Spridningen (METOD M44).
        ('"spridning": [\n', '"spridningen": [\n', "katalogen: listan spridning saknas"),
        ('{"matt": "brost_bojning_adress", "vy": "dtl", "vad": "The spread', '{"matt": "brost_bojning_adress", "vy": "fo", "vad": "The spread',
         "spridning brost_bojning_adress: måttet finns inte i vyn"),
        ('{"matt": "brost_bojning_traff", "vy": "dtl", "vad": "The spread', '{"matt": "brost_bojning_adress", "vy": "dtl", "vad": "The spread',
         "spridning brost_bojning_adress: står två gånger"),
        ('"tecken": "Degrees, robust', '"x": 1, "tecken": "Degrees, robust', "spridning brost_bojning_adress: ska ha matt"),
    ]

    def test_formfelen_hittas(self) -> None:
        text = K.KATALOG.read_text(encoding="utf-8")
        for fran, till, vantat in self.FORMFEL:
            with self.subTest(vantat=vantat):
                self.assertIn(fran, text)
                fel = K.kontrollera(json.loads(text.replace(fran, till, 1)))
                self.assertTrue(any(f.startswith(vantat) for f in fel), fel)


class Granserna(unittest.TestCase):
    def test_sway_vid_toppen(self) -> None:
        """BESLUT B45: grönt från −2,5 cm (tour −1,5 med driver, 0,0 med järn)."""
        f = _fel("sway_topp")
        for v, status in ((3.0, "gron"), (0.0, "gron"), (-1.5, "gron"), (-2.5, "gron"), (-2.6, "gul"), (-5.0, "gul"),
                          (-5.01, "rod"), (-12.0, "rod")):
            self.assertEqual(K.bedom_varde(f, v, [])["status"], status, v)

    def test_early_extension(self) -> None:
        """BESLUT B45: grönt till Sportsbox ideal (+4,3 cm), rött över tour + 2 SD (8,4 cm)."""
        f = _fel("early_extension")
        for v, status in ((-6.0, "gron"), (1.3, "gron"), (4.3, "gron"), (4.4, "gul"), (8.4, "gul"), (8.5, "rod")):
            self.assertEqual(K.bedom_varde(f, v, [])["status"], status, v)

    def test_tempot_blir_aldrig_rott(self) -> None:
        f = _fel("tempo")
        self.assertEqual(K.bedom_varde(f, 2.8, [])["status"], "gron")
        self.assertEqual(K.bedom_varde(f, 3.4, [])["status"], "gul")
        self.assertEqual(K.bedom_varde(f, 1.2, [])["status"], "gul")

    def test_avstangt_och_okant(self) -> None:
        self.assertEqual(K.bedom_varde(_fel("axellutning"), 10.0, [])["status"], "av")
        self.assertEqual(K.bedom_varde(_fel("sway_topp"), None, [])["status"], "okand")


class Baslinjen(unittest.TestCase):
    BAS = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]      # median 4, q1 2, q3 6 → spridning 4/1,349

    def test_det_samre_hallet_raknas(self) -> None:
        f = _fel("tappad_hallning")                          # samre "+": bröstet reser sig
        spr = 4.0 / 1.349
        self.assertEqual(K.bedom_varde(f, 4.0 + 0.5 * spr, self.BAS)["status"], "gron")
        self.assertEqual(K.bedom_varde(f, 4.0 + 1.5 * spr, self.BAS)["status"], "gul")
        self.assertEqual(K.bedom_varde(f, 4.0 + 2.5 * spr, self.BAS)["status"], "rod")
        b = K.bedom_varde(f, 4.0 - 2.5 * spr, self.BAS)        # bättre än vanligt
        self.assertEqual((b["status"], b["grund"]), ("gron", "baslinje"))
        self.assertAlmostEqual(b["z"], -2.5)

    def test_utan_riktning_raknas_bada_hallen(self) -> None:
        f = dict(_fel("sway_gap"), samre=None)
        self.assertEqual(K.bedom_varde(f, 4.0 - 2.5 * 4.0 / 1.349, self.BAS)["status"], "rod")
        self.assertEqual(K.bedom_varde(f, 4.0 + 2.5 * 4.0 / 1.349, self.BAS)["status"], "rod")
        f = _fel("sway_gap")                                 # samre "-": bröstet mindre bakom är sämre
        self.assertEqual(K.bedom_varde(f, 4.0 + 2.5 * 4.0 / 1.349, self.BAS)["status"], "gron")

    def test_for_kort_baslinje_ar_okand(self) -> None:
        self.assertEqual(K.bedom_varde(_fel("tappad_hallning"), 9.0, self.BAS[:7])["status"], "okand")
        self.assertEqual(K.bedom_varde(_fel("tappad_hallning"), 9.0, [1.0] * 9)["status"], "okand")

    def test_ett_pass_mot_tva_tidigare(self) -> None:
        nu = gen.session(21, 10, 9, utslag=True)
        tidigare = gen.session(22, 12, 10)
        b = {x["id"]: x for x in K.bedom(K.las(), nu, tidigare)}
        self.assertEqual(len(b), len(K.las()["fel"]))
        self.assertEqual(b["sway_topp"]["grund"], "grans")
        self.assertEqual(b["early_extension"]["grund"], "grans")
        self.assertEqual(b["tappad_hallning"]["grund"], "baslinje")
        self.assertEqual(b["axellutning"]["status"], "av")
        self.assertIn(b["tempo"]["status"], ("gron", "gul"))


if __name__ == "__main__":
    unittest.main()
