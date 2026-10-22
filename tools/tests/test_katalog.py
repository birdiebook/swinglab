"""Katalogen (katalog.json, BESLUT B6) och bedömningen (METOD M27)."""
from __future__ import annotations

import json
import unittest

from _hjalp import gen
from pc import katalog as K


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

    def test_ingen_grans_ar_kontrollerad_an(self) -> None:
        """BESLUT B10: inget är läst i original ännu (2026-10-22)."""
        for f in K.las()["fel"]:
            self.assertFalse(f["kontrollerad"], f["id"])
            self.assertTrue(f["kalla"].startswith("https://"), f["id"])

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
        ('"gront": [0, null]', '"gront": null', "sway_topp: gult utan gront"),
        ('"id": "tempo"', '"id": "sway_topp"', "sway_topp: id finns två gånger"),
        ('"gront": [2.5, 3.1]', '"gront": [2.5]', "tempo: gront ska vara"),
        ('"samre": "-",', "", "sway_topp: samre saknas"),
        ('"ovning":', '"ovn":', "sway_topp: ovning saknas"),
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
        f = _fel("sway_topp")
        for v, status in ((3.0, "gron"), (0.0, "gron"), (-0.1, "gul"), (-5.0, "gul"), (-5.01, "rod"), (-12.0, "rod")):
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
        f = _fel("early_extension")                          # samre "+": mot bollen
        spr = 4.0 / 1.349
        self.assertEqual(K.bedom_varde(f, 4.0 + 0.5 * spr, self.BAS)["status"], "gron")
        self.assertEqual(K.bedom_varde(f, 4.0 + 1.5 * spr, self.BAS)["status"], "gul")
        self.assertEqual(K.bedom_varde(f, 4.0 + 2.5 * spr, self.BAS)["status"], "rod")
        b = K.bedom_varde(f, 4.0 - 2.5 * spr, self.BAS)        # bättre än vanligt
        self.assertEqual((b["status"], b["grund"]), ("gron", "baslinje"))
        self.assertAlmostEqual(b["z"], -2.5)

    def test_utan_riktning_raknas_bada_hallen(self) -> None:
        f = _fel("sway_gap")
        self.assertEqual(K.bedom_varde(f, 4.0 - 2.5 * 4.0 / 1.349, self.BAS)["status"], "rod")

    def test_for_kort_baslinje_ar_okand(self) -> None:
        self.assertEqual(K.bedom_varde(_fel("early_extension"), 9.0, self.BAS[:7])["status"], "okand")
        self.assertEqual(K.bedom_varde(_fel("early_extension"), 9.0, [1.0] * 9)["status"], "okand")

    def test_ett_pass_mot_tva_tidigare(self) -> None:
        nu = gen.session(21, 10, 9, utslag=True)
        tidigare = gen.session(22, 12, 10)
        b = {x["id"]: x for x in K.bedom(K.las(), nu, tidigare)}
        self.assertEqual(len(b), len(K.las()["fel"]))
        self.assertEqual(b["sway_topp"]["grund"], "grans")
        self.assertEqual(b["early_extension"]["grund"], "baslinje")
        self.assertEqual(b["axellutning"]["status"], "av")
        self.assertIn(b["tempo"]["status"], ("gron", "gul"))


if __name__ == "__main__":
    unittest.main()
