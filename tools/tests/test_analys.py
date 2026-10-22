"""Analysen: "klart när"-förslaget (METOD MT3), kedjorna och kandidaternas
ordning (METOD MT6). Påhittade bedömningar, inga riktiga tal."""
from __future__ import annotations

import json
import math
import unittest

import _hjalp  # noqa: F401
from pc import analys as A
from pc import katalog as KAT


def _fel(**kw) -> dict:
    f = {"id": "x", "matt": "backen_thrust_traff", "aktiv": True, "gront": None, "gult": None,
         "kontrollerad": False, "samre": "+"}
    f.update(kw)
    return f


class KlartNar(unittest.TestCase):
    def test_ur_katalogens_grans_med_b10(self) -> None:
        k = A.klart_nar(_fel(gront=[0, None]), {"grund": "grans"}, None, [])
        self.assertEqual(k, {"villkor": ">=", "grans": 0, "grund": "grans", "markning": "B10"})
        k = A.klart_nar(_fel(gront=[2.5, 3.1], kontrollerad=True), {"grund": "grans"}, None, [])
        self.assertEqual((k["villkor"], k["grans"], k["markning"]), ("mellan", [2.5, 3.1], None))
        self.assertEqual(A.klart_nar(_fel(gront=[None, 4]), {"grund": "grans"}, None, [])["villkor"], "<=")

    def test_ur_egen_baslinje(self) -> None:
        bas = [float(v) for v in range(9)]                  # median 4, IQR 2…6 → sd 4/1,349
        spr = 4 / 1.349
        k = A.klart_nar(_fel(samre="+"), {"grund": "baslinje"}, None, bas)
        self.assertEqual((k["villkor"], k["grans"], k["markning"]), ("<=", round(4 + KAT.GRON_Z * spr, 1), "egen"))
        k = A.klart_nar(_fel(samre="-"), {"grund": "baslinje"}, None, bas)
        self.assertEqual((k["villkor"], k["grans"]), (">=", round(4 - spr, 1)))
        k = A.klart_nar(_fel(samre=None), {"grund": "baslinje"}, None, bas)
        self.assertEqual(k["grans"], [round(4 - spr, 1), round(4 + spr, 1)])

    def test_utan_baslinje_en_spridning_at_ratt_hall(self) -> None:
        nu = {"median": 3.0, "q1": 2.0, "q3": 4.698}       # robust sd 2,0
        k = A.klart_nar(_fel(samre="+"), {"grund": None}, nu, [])
        self.assertEqual((k["villkor"], k["grans"], k["grund"]), ("<=", 1.0, "nu"))
        self.assertIsNone(A.klart_nar(_fel(samre=None), {"grund": None}, nu, []))
        self.assertIsNone(A.klart_nar(_fel(aktiv=False), {"grund": None}, nu, []))

    def test_uppfyllt_ar_slutet(self) -> None:
        self.assertTrue(A.uppfyllt(">=", 0, 0.0))
        self.assertTrue(A.uppfyllt("mellan", [2.5, 3.1], 3.1))
        self.assertFalse(A.uppfyllt("<=", 1.0, 1.05))

    def test_avrundningen_och_enheten(self) -> None:
        self.assertEqual((A.enhet("backen_sway_topp"), A.enhet("sidbojning_topp"), A.enhet("tempo"),
                          A.enhet("baksving_s"), A.enhet("bakre_kna_adress")), ("cm", "°", "", "s", "°"))
        self.assertEqual(A.avrunda("tempo", 2.6449), 2.64)
        self.assertEqual(A.avrunda("backen_sway_topp", -5.66), -5.7)


class Kedjorna(unittest.TestCase):
    def setUp(self) -> None:
        self.k = A.las_kedjor()

    def test_kedjorna_pekar_pa_katalogens_fel(self) -> None:
        ids = {f["id"] for f in KAT.las()["fel"]}
        for k in self.k["kedjor"]:
            self.assertIn(k["orsak"], ids)
            self.assertIn(k["foljd"], ids)
            self.assertIn(k["status"], KAT.STATUS)
        for x in self.k["fysik"] + self.k["lag_prioritet"]:
            self.assertIn(x["fel"], ids)
        for f in KAT.las()["fel"]:
            self.assertIn(f["fas"], self.k["faser"])

    def test_orsakerna_las_transitivt(self) -> None:
        o = A.orsaker(self.k, "early_extension")
        self.assertEqual(o["reverse_spine"], ["reverse_spine", "early_extension"])
        self.assertEqual(o["sway_topp"], ["sway_topp", "reverse_spine", "early_extension"])
        self.assertEqual(A.orsaker(self.k, "sway_topp"), {})

    def test_kedjorna_har_ingen_cirkel(self) -> None:
        for f in KAT.las()["fel"]:
            self.assertNotIn(f["id"], A.orsaker(self.k, f["id"]))

    def test_kandidaternas_ordning(self) -> None:
        def b(fid, fas, status, z=None):
            return {"id": fid, "fas": fas, "status": status, "z": z}
        bed = [b("tempo", "hela", "gul"), b("early_extension", "traff", "rod", 3.0),
               b("chicken_wing", "efter_traff", "rod", 2.5), b("flying_elbow", "topp", "gul", 1.5),
               b("over_the_top", "nedsving", "rod", 2.1), b("sway_topp", "topp", "rod"),
               b("tappad_hallning", "traff", "gron", 0.2)]
        k = A.kandidater(bed, self.k)
        self.assertEqual([x["fel"] for x in k], ["sway_topp", "flying_elbow", "over_the_top", "chicken_wing",
                                                 "tempo", "early_extension"])
        ee = k[-1]
        self.assertTrue(ee["foljdfel"])
        self.assertEqual(list(ee["orsaker"]), ["sway_topp"])          # via reverse_spine, som inte är flaggat
        self.assertIn("Toe touch", ee["fysik"])


class Renheten(unittest.TestCase):
    def test_nan_blir_null(self) -> None:
        self.assertEqual(json.dumps(A.ren({"a": [math.nan, 1.0], "b": math.inf})), '{"a": [null, 1.0], "b": null}')


if __name__ == "__main__":
    unittest.main()
