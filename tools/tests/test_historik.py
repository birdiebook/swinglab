"""Historiken: passen, baslinjen och övningarnas läge genom vintern
(METOD MT4, MT5). Påhittade analyser med bara de fält historiken läser."""
from __future__ import annotations

import datetime as dt
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


def _analys(pass_id: str, forsta: float, hela: float | None = None, status: str = "rod") -> dict:
    hela = forsta if hela is None else hela
    return {"pass": pass_id, "klubbor": ["j7"],
            "slag": [{"vy": "fo", "matt": {MATT: hela}} for _ in range(8)],
            "session": {"fo": {MATT: _sammanf(hela)}, "dtl": {}, "alla": {}},
            "forsta_serien": {"fo": {MATT: _sammanf(forsta)}, "dtl": {}, "alla": {}},
            "bedomning": [{"id": "sway_topp", "visat": hela, "forsta_serien": forsta, "status": status}]}


def _doc(pass_id: str, text: str = "Stick at the hip.", grans: float = 0, fysik=None, ovid: str | None = None) -> dict:
    """Ett påhittat val. Övningen känns igen på `ovid` (standard: texten gjord till id)."""
    d = json.loads(FIXTUR.read_text(encoding="utf-8"))
    d["pass"] = pass_id
    d["saker"][0]["ovning"]["text"] = text
    d["saker"][0]["ovning"]["id"] = ovid or text.lower().rstrip(".").replace(" ", "_")
    d["saker"][0]["klart_nar"]["grans"] = grans
    d["saker"][0]["fysik"] = fysik
    return d


def _pass(start: str, steg_dagar: int, n: int) -> list[str]:
    d0 = dt.date(int(start[:4]), int(start[4:6]), int(start[6:8]))
    return [(d0 + dt.timedelta(days=steg_dagar * i)).strftime("%Y%m%d") + "-180000" for i in range(n)]


class Historiken(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.rot = Path(self.tmp.name)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def pass_(self, pass_id: str, forsta: float, hela: float | None = None, status: str = "rod") -> None:
        H.spara_analys(self.rot, _analys(pass_id, forsta, hela, status))

    def ajp(self, pass_id: str, **kw) -> None:
        H._skriv(self.rot / "att_jobba_pa" / f"{pass_id}.json", _doc(pass_id, **kw))

    def tomt_val(self, pass_id: str) -> None:
        d = _doc(pass_id)
        d["saker"][0]["fel"] = "flying_elbow"
        H._skriv(self.rot / "att_jobba_pa" / f"{pass_id}.json", d)

    def lage(self, till=None) -> dict:
        return {o["fel"]: o for o in H.ovningar(self.rot, till)}["sway_topp"]

    def test_aldre_matning_kors_om(self) -> None:
        """Ett pass utan `matversion` (= 1, före S1d) eller med en äldre ska köras om med
        session.py; ett med dagens inte. METOD M40"""
        self.pass_("20261103-180000", -5.0)                          # utan matversion
        a = _analys("20261106-180000", -5.0)
        a["matversion"] = H.M.MATVERSION
        H.spara_analys(self.rot, a)
        a = _analys("20261110-180000", -5.0)
        a["matversion"] = H.M.MATVERSION - 1
        H.spara_analys(self.rot, a)
        self.assertEqual(H.kor_om(self.rot), ["20261103-180000", "20261110-180000"])
        self.assertEqual(H.minne(self.rot, till="20261106-180000")["kor_om"], ["20261103-180000"])

    def test_tom_historik(self) -> None:
        self.assertEqual(H.lista(self.rot), [])
        self.assertEqual(H.enheter(self.rot, fore="20261103-180000"), [])
        self.assertEqual(H.minne(self.rot)["ovningar"], [])

    def test_lista_och_enheterna(self) -> None:
        for p in ("20261110-180000", "20261103-180000", "20261106-180000"):
            self.pass_(p, -5.0)
        self.assertEqual(H.lista(self.rot), ["20261103-180000", "20261106-180000", "20261110-180000"])
        enh = H.enheter(self.rot, fore="20261110-180000")
        self.assertEqual([(u["pass"], u["klubba_id"], u["huvud"]) for u in enh],
                         [("20261103-180000", "j7", True), ("20261106-180000", "j7", True)])
        self.assertEqual(sum(len(u["svingar"]) for u in enh), 16)

    def test_andra_klubbor_och_vyer_ror_inte_saken(self) -> None:
        """BESLUT B56: en sak följs upp och avslutas bara av pass med samma klubba och vy."""
        self.pass_("20261103-180000", -6.0)
        self.ajp("20261103-180000")
        dr = _analys("20261106-180000", 0.5)
        dr["klubbor"] = ["dr"]
        H.spara_analys(self.rot, dr)
        d = _doc("20261106-180000")
        d["saker"][0]["fel"] = "flying_elbow"
        H._skriv(self.rot / "att_jobba_pa" / "20261106-180000.json", d)
        dtl = _analys("20261108-180000", 0.5)
        for r in dtl["slag"]:
            r["vy"] = "dtl"
        H.spara_analys(self.rot, dtl)
        self.pass_("20261110-180000", -6.0)
        o = self.lage()
        self.assertEqual((o["lage"], o["pass_sedan"], o["aktuell"]), ("fortsatt", 1, True))
        self.assertEqual([u["pass"] for u in o["uppfoljning"]], ["20261110-180000"])

    def test_spelaren_minns(self) -> None:
        self.assertEqual(H.spelare(self.rot), {})
        H.spara_spelare(self.rot, 1.5)
        self.assertEqual(H.spelare(self.rot)["spelarens_langd_m"], 1.5)

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
        self.assertEqual((o["lage"], o["uppfyllt_i_rad"], o["klart_skal"]), ("klart", 2, "klart_nar"))
        self.assertTrue(all(u["tydlig"] for u in o["uppfoljning"]))

    def test_ett_fel_som_inte_langre_flaggas_ar_klart(self) -> None:
        """BESLUT B45: gränsen flyttades medan övningen pågick (≥ 0 → ≥ −2,5). "Klart när"
        står kvar från valet, men felet är grönt: övningen är klar, inte tyst borttagen."""
        self.pass_("20261103-180000", -6.0)
        self.ajp("20261103-180000", grans=0)
        self.pass_("20261106-180000", -2.0, status="gron")
        o = self.lage()
        self.assertEqual((o["lage"], o["klart_skal"], o["klart_nar"]["grans"]), ("klart", "inte_flaggat", 0))
        self.assertEqual(o["uppfyllt_i_rad"], 0)
        # Flaggat igen i ett senare pass: övningen fortsätter.
        self.pass_("20261110-180000", -4.0, status="gul")
        self.assertEqual((self.lage()["lage"], self.lage()["klart_skal"]), ("fortsatt", None))
        # Grönt i samma pass som valet räknas inte: inget pass har kommit efter valet.
        self.ajp("20261110-180000", grans=0)
        self.assertEqual(self.lage()["lage"], "fortsatt")

    def test_klart_nar_flyttar_sig_inte_nar_ovningen_fortsatter(self) -> None:
        """Granskningen fynd 3: äldre pass bedöms mot gränsen från valet."""
        self.pass_("20261103-180000", -6.0)
        self.ajp("20261103-180000", grans=0)
        self.pass_("20261106-180000", -1.0)
        self.ajp("20261106-180000", grans=-2)               # samma övning, flyttad gräns: läses inte
        self.pass_("20261110-180000", -1.0)
        o = self.lage()
        self.assertEqual(o["klart_nar"]["grans"], 0)
        self.assertEqual([u["uppfyllt"] for u in o["uppfoljning"]], [False, False])
        self.assertEqual(o["lage"], "fortsatt")

    def test_byt_ovning_efter_n_pass_utan_rorelse(self) -> None:
        pass_ids = _pass("20261101", 2, 5)
        self.pass_(pass_ids[0], -6.0)
        self.ajp(pass_ids[0])
        for i, p in enumerate(pass_ids[1:]):
            self.pass_(p, -6.0 + 0.3 * (i % 2))                # inom spridningen
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

    def test_fysiken_nas_aven_nar_ovningen_byts_var_fjarde_pass(self) -> None:
        """Granskningen fynd 2: dagarna och rörelsen räknas från första gången
        felet valdes, över alla övningar för det."""
        pass_ids = _pass("20261101", 3, 16)                    # dag 0, 3, …, 45
        for i, p in enumerate(pass_ids):
            self.pass_(p, -6.0)
            if i % 5 == 0:                                     # ny övning var femte pass
                self.ajp(p, text=f"Drill {'ABCD'[i // 5]}.")
        o = self.lage(till=pass_ids[13])                       # dag 39
        self.assertNotEqual(o["lage"], "fysik")
        o = self.lage(till=pass_ids[14])                       # dag 42
        self.assertEqual((o["lage"], o["fel_start"], o["dagar_sedan_felet_valdes"]), ("fysik", pass_ids[0], 42))
        self.assertEqual(o["forra_ovningar"], ["drill_c", "drill_b", "drill_a"][1:])

    def test_fysiken_fragas_bara_en_gang(self) -> None:
        pass_ids = _pass("20261101", 7, 8)
        for i, p in enumerate(pass_ids):
            self.pass_(p, -6.0)
        self.ajp(pass_ids[0])
        self.ajp(pass_ids[6], fysik={"test": "Bakre höftens inåtrotation", "treregeln": [True, False, False],
                                     "ovning": None})
        self.assertEqual(self.lage()["lage"], "byt_ovning")

    def test_en_slappt_ovning_ar_avslutad(self) -> None:
        """Granskningen fynd 6: en släppt övning väcks inte som byt_ovning eller fysik."""
        pass_ids = _pass("20261101", 7, 8)
        for p in pass_ids:
            self.pass_(p, -6.0)
        self.ajp(pass_ids[0])
        self.tomt_val(pass_ids[1])
        o = self.lage()
        self.assertEqual((o["lage"], o["aktuell"]), ("avslutad", False))

    def test_ett_fel_som_valjs_igen_borjar_ett_nytt_block(self) -> None:
        pass_ids = _pass("20261101", 7, 4)
        for p in pass_ids:
            self.pass_(p, -6.0)
        self.ajp(pass_ids[0], text="Drill A.")
        self.tomt_val(pass_ids[1])
        self.ajp(pass_ids[2], text="Drill B.")
        o = self.lage()
        self.assertEqual((o["fel_start"], o["forra_ovningar"], o["lage"]), (pass_ids[2], ["drill_a"], "fortsatt"))

    def test_fore_tar_bara_valen_fore_passet(self) -> None:
        self.pass_("20261101-180000", -6.0)
        self.ajp("20261101-180000", text="Drill A.")
        self.pass_("20261103-180000", -6.0)
        self.ajp("20261103-180000", text="Drill B.")
        o = {x["fel"]: x for x in H.ovningar(self.rot, till="20261103-180000", fore="20261103-180000")}["sway_topp"]
        self.assertEqual((o["ovning"], o["ovning_id"], o["pass_sedan"]), ("Drill A.", "drill_a", 1))

    def test_omskriven_text_ar_samma_ovning(self) -> None:
        """Övningen jämförs på sitt id: en ny formulering (som B30:s översättning)
        nollställer inte steget, "klart när" eller blocket."""
        self.pass_("20261103-180000", -6.0)
        self.ajp("20261103-180000", text="Käpp vid höften.", ovid="kapp", grans=0)
        self.pass_("20261106-180000", -4.0)
        self.ajp("20261106-180000", text="Stick at the hip.", ovid="kapp", grans=-2)
        self.pass_("20261110-180000", -3.0)
        o = self.lage()
        self.assertEqual((o["valt_i_pass"], o["fel_start"], o["forra_ovningar"]), ("20261103-180000", "20261103-180000", []))
        self.assertEqual((o["ovning"], o["ovning_id"], o["klart_nar"]["grans"]), ("Stick at the hip.", "kapp", 0))
        self.assertEqual(o["pass_sedan"], 2)
        # Ett nytt id är en ny övning, även med samma text.
        self.ajp("20261110-180000", text="Stick at the hip.", ovid="annan")
        o = self.lage()
        self.assertEqual((o["valt_i_pass"], o["forra_ovningar"]), ("20261110-180000", ["kapp"]))

    def test_aldre_fil_utan_id_kanns_igen_pa_texten(self) -> None:
        self.assertEqual(H.ovning_id({"text": "Drill A."}), "Drill A.")
        self.assertEqual(H.ovning_id({"id": "a", "text": "Drill A."}), "a")

    def test_minnet_har_felens_vag(self) -> None:
        self.pass_("20261103-180000", -6.0)
        self.pass_("20261106-180000", -4.0)
        m = H.minne(self.rot)
        self.assertEqual([x["varde"] for x in m["fel"]["sway_topp"]], [-6.0, -4.0])
        self.assertEqual(m["pass"][1]["datum"], "2026-11-06")

    def test_spara_kraver_analysen(self) -> None:
        """Granskningen fynd 5: kontrollen mot analysen hoppas aldrig över."""
        with self.assertRaises(ValueError) as e:
            H.spara_att_jobba_pa(self.rot, _doc("20261103-180000"))
        self.assertIn("analys.json saknas", str(e.exception))
        self.pass_("20261103-180000", -6.0)
        with self.assertRaises(ValueError):
            H.spara_att_jobba_pa(self.rot, _doc("20261103-180000"))    # den påhittade analysen saknar förslagen
        self.assertFalse((self.rot / "att_jobba_pa").exists())


if __name__ == "__main__":
    unittest.main()
