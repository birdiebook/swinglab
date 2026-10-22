"""Historiken: passen, baslinjen och övningarnas läge genom vintern
(METOD MT4, MT5). Påhittade analyser med bara de fält historiken läser."""
from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path

import _hjalp  # noqa: F401
from pc import historik as H

FIXTUR = Path(__file__).resolve().parent / "fixturer" / "att_jobba_pa_exempel.json"
MATT = "backen_sway_topp"


def _sammanf(v: float) -> dict:
    return {"n": 8, "median": v, "q1": v - 0.6745, "q3": v + 0.6745}     # robust sd 1,0


def _analys(pass_id: str, forsta: float, hela: float | None = None) -> dict:
    hela = forsta if hela is None else hela
    return {"pass": pass_id, "klubbor": ["j7"],
            "slag": [{"vy": "fo", "matt": {MATT: hela}} for _ in range(8)],
            "session": {"fo": {MATT: _sammanf(hela)}, "dtl": {}, "alla": {}},
            "forsta_serien": {"fo": {MATT: _sammanf(forsta)}, "dtl": {}, "alla": {}},
            "bedomning": [{"id": "sway_topp", "visat": hela, "forsta_serien": forsta, "status": "rod"}]}


def _doc(pass_id: str, text: str = "Käpp vid höften.", pass_i_rad: int = 2) -> dict:
    d = json.loads(FIXTUR.read_text(encoding="utf-8"))
    d["pass"] = pass_id
    d["saker"][0]["ovning"]["text"] = text
    d["saker"][0]["klart_nar"]["pass_i_rad"] = pass_i_rad
    return d


class Historiken(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.rot = Path(self.tmp.name)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def pass_(self, pass_id: str, forsta: float, hela: float | None = None) -> None:
        H.spara_analys(self.rot, _analys(pass_id, forsta, hela))

    def ajp(self, pass_id: str, **kw) -> None:
        H._skriv(self.rot / "att_jobba_pa" / f"{pass_id}.json", _doc(pass_id, **kw))

    def lage(self, till=None) -> dict:
        return {o["fel"]: o for o in H.ovningar(self.rot, till)}["sway_topp"]

    def test_tom_historik(self) -> None:
        self.assertEqual(H.lista(self.rot), [])
        self.assertEqual(H.baslinje(self.rot, "20261103-180000"), ([], []))
        self.assertIsNone(H.forra(self.rot, "20261103-180000"))
        self.assertEqual(H.minne(self.rot)["ovningar"], [])

    def test_lista_forra_och_baslinje(self) -> None:
        for p in ("20261110-180000", "20261103-180000", "20261106-180000"):
            self.pass_(p, -5.0)
        self.assertEqual(H.lista(self.rot), ["20261103-180000", "20261106-180000", "20261110-180000"])
        self.assertEqual(H.forra(self.rot, "20261110-180000")["pass"], "20261106-180000")
        svingar, pass_ids = H.baslinje(self.rot, "20261110-180000")
        self.assertEqual((len(svingar), pass_ids), (16, ["20261103-180000", "20261106-180000"]))

    def test_spelaren_minns(self) -> None:
        self.assertEqual(H.spelare(self.rot), {})
        H.spara_spelare(self.rot, 1.82)
        self.assertEqual(H.spelare(self.rot)["spelarens_langd_m"], 1.82)

    def test_ny_ovning(self) -> None:
        self.pass_("20261103-180000", -6.0)
        self.ajp("20261103-180000")
        o = self.lage()
        self.assertEqual((o["lage"], o["pass_sedan"], o["start_forsta_serien"], o["spridning"]), ("ny", 0, -6.0, 1.0))

    def test_klart_efter_tva_pass_i_rad_pa_forsta_serien(self) -> None:
        self.pass_("20261103-180000", -6.0)
        self.ajp("20261103-180000")
        self.pass_("20261106-180000", 0.5, hela=-2.0)       # första serien klarar, passet inte: retentionen räknas
        self.assertEqual(self.lage()["lage"], "fortsatt")
        self.pass_("20261110-180000", 0.0)
        o = self.lage()
        self.assertEqual((o["lage"], o["uppfyllt_i_rad"]), ("klart", 2))
        self.assertTrue(all(u["tydlig"] for u in o["uppfoljning"]))

    def test_byt_ovning_efter_n_pass_utan_rorelse(self) -> None:
        self.pass_("20261101-180000", -6.0)
        self.ajp("20261101-180000")
        dagar = ["20261103", "20261105", "20261107", "20261109"]
        for i, d in enumerate(dagar):
            self.pass_(f"{d}-180000", -6.0 + 0.3 * (i % 2))     # inom spridningen
            o = self.lage()
            self.assertEqual(o["lage"], "byt_ovning" if i + 1 >= H.BYT_OVNING_PASS else "fortsatt")
        self.assertEqual(o["pass_utan_rorelse"], H.BYT_OVNING_PASS)

    def test_en_tydlig_rorelse_nollstaller_rakningen(self) -> None:
        self.pass_("20261101-180000", -6.0)
        self.ajp("20261101-180000")
        for d, v in (("20261103", -6.0), ("20261105", -6.0), ("20261107", -4.5), ("20261109", -4.6)):
            self.pass_(f"{d}-180000", v)
        o = self.lage()
        self.assertEqual((o["pass_utan_rorelse"], o["lage"]), (0, "fortsatt"))

    def test_sex_veckor_utan_rorelse_ger_fysiken(self) -> None:
        self.pass_("20261101-180000", -6.0)
        self.ajp("20261101-180000")
        self.pass_("20261201-180000", -6.0)
        self.pass_("20261215-180000", -5.9)
        o = self.lage()
        self.assertGreaterEqual(o["dagar_sedan"], H.FYSIK_DAGAR)
        self.assertEqual(o["lage"], "fysik")

    def test_bytt_ovning_borjar_om_och_minns_den_forra(self) -> None:
        self.pass_("20261101-180000", -6.0)
        self.ajp("20261101-180000", text="Käpp vid höften.")
        self.pass_("20261103-180000", -6.0)
        self.ajp("20261103-180000", text="Fötterna ihop, 3/4-svingar.")
        self.pass_("20261105-180000", -6.0)
        o = self.lage()
        self.assertEqual((o["valt_i_pass"], o["forra_ovningar"], o["pass_sedan"]),
                         ("20261103-180000", ["Käpp vid höften."], 1))
        o = self.lage(till="20261101-180000")
        self.assertEqual((o["ovning"], o["lage"]), ("Käpp vid höften.", "ny"))

    def test_minnet_har_felens_vag(self) -> None:
        self.pass_("20261103-180000", -6.0)
        self.pass_("20261106-180000", -4.0)
        m = H.minne(self.rot)
        self.assertEqual([x["varde"] for x in m["fel"]["sway_topp"]], [-6.0, -4.0])
        self.assertEqual(m["pass"][1]["datum"], "2026-11-06")

    def test_spara_kontrollerar_mot_analysen(self) -> None:
        self.pass_("20261103-180000", -6.0)
        d = copy.deepcopy(_doc("20261103-180000"))
        with self.assertRaises(ValueError):
            H.spara_att_jobba_pa(self.rot, d)        # den påhittade analysen saknar förslagen
        self.assertFalse((self.rot / "att_jobba_pa").exists())


if __name__ == "__main__":
    unittest.main()
