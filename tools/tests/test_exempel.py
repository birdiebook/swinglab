"""Exemplet från början till slut, med skillens kommandon (svinganalys/SKILL.md
§Exemplet) på påhittade paket: paket → analys → att_jobba_pa → historik →
nästa pass → minnet. Fixturen är påhittad."""
from __future__ import annotations

import contextlib
import copy
import io
import json
import tempfile
import unittest
from pathlib import Path

import _hjalp  # noqa: F401
from pc import att_jobba_pa as AJP
from pc import generera_paket as GP
from pc import historik as H
from pc import session as S

FIXTUR = Path(__file__).resolve().parent / "fixturer" / "att_jobba_pa_exempel.json"
P1, P2 = "20261103-180000", "20261106-180000"


def _kor(main, argv) -> tuple[int, str]:
    ut = io.StringIO()
    with contextlib.redirect_stdout(ut):
        kod = main(argv)
    return kod, ut.getvalue()


class Exemplet(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tmp = tempfile.TemporaryDirectory()
        t = Path(cls.tmp.name)
        cls.hist = t / "historik"
        # Steg 0: Johannes paket (här påhittade, som i skillens exempel).
        cls.p1 = [GP.paket(t / "in", P1, vy, serier=2, langd_m=None) for vy in ("fo", "dtl")]
        cls.p2 = [GP.paket(t / "in", P2, vy, serier=2, seed=2, sway_topp=-3.5, forsta_serien_flytt=-0.5,
                           langd_m=None) for vy in ("fo", "dtl")]

    @classmethod
    def tearDownClass(cls) -> None:
        cls.tmp.cleanup()

    def test_hela_vagen(self) -> None:
        hist = ["--historik", str(self.hist)]
        # Utan längd stoppar analysen med en rad.
        kod, ut = _kor(S.main, [*map(str, self.p1), *hist, "--utan-kontaktark"])
        self.assertEqual(kod, 1)
        self.assertIn("--langd", ut)
        # Steg 1: paket → analys (längden sparas till nästa gång).
        kod, ut = _kor(S.main, [*map(str, self.p1), *hist, "--langd", "1.80", "--utan-kontaktark"])
        self.assertEqual(kod, 0, ut)
        self.assertIn("kandidater: sway_topp (rod)", ut)
        analys = self.hist / "pass" / P1 / "analys.json"
        a = json.loads(analys.read_text(encoding="utf-8"))
        self.assertEqual(a["format"], "swinglab-analys/1")
        self.assertEqual(a["matversion"], 2)                      # METOD M40
        self.assertEqual((a["forra"], a["baslinje"]["pass"]), (None, []))
        self.assertEqual(sum(1 for r in a["slag"] if "matt" in r), 16)
        self.assertEqual((a["tempo_vy"], a["session"]["alla"]["tempo"]["n"]), ("fo", 8))   # aldrig 16
        # Steg 2: minnet före tolkningen (tomt första gången).
        kod, ut = _kor(H.main, ["--rot", str(self.hist), "minne"])
        self.assertEqual(json.loads(ut)["ovningar"], [])
        # Steg 3–4: Claudes val (fixturen) kontrolleras mot analysen och sparas.
        kod, ut = _kor(AJP.main, [str(FIXTUR), "--analys", str(analys), "--historik", str(self.hist)])
        self.assertEqual(kod, 0, ut)
        kod, ut = _kor(H.main, ["--rot", str(self.hist), "spara-att-jobba-pa", str(FIXTUR)])
        self.assertEqual(kod, 0, ut)
        # Nästa pass: längden ur historiken, förra passet och baslinjen ur historiken.
        kod, ut = _kor(S.main, [*map(str, self.p2), *hist, "--utan-kontaktark"])
        self.assertEqual(kod, 0, ut)
        self.assertIn(f"förra passet {P1}, baslinje ur 1 pass", ut)
        b = json.loads((self.hist / "pass" / P2 / "analys.json").read_text(encoding="utf-8"))
        self.assertEqual(b["forra"]["pass"], P1)
        sway = {x["id"]: x for x in b["bedomning"]}["sway_topp"]
        self.assertTrue(sway["mot_forra"]["tydlig"])
        self.assertGreater(sway["mot_forra"]["skillnad"], 0)
        # Minnet: övningen bet (tydlig rörelse på första serien), men är inte klar.
        m = json.loads(_kor(H.main, ["--rot", str(self.hist), "minne"])[1])
        o = m["ovningar"][0]
        self.assertEqual((o["fel"], o["valt_i_pass"], o["lage"]), ("sway_topp", P1, "fortsatt"))
        self.assertTrue(o["uppfoljning"][0]["tydlig"])
        self.assertFalse(o["uppfoljning"][0]["uppfyllt"])
        # Nästa val: samma övning fortsätter, ett steg upp, samma "klart när".
        d = self.fortsatt(json.loads(FIXTUR.read_text(encoding="utf-8")), b)
        self.assertEqual(H.kontrollera_att_jobba_pa(self.hist, d), [])
        d2 = copy.deepcopy(d)
        d2["saker"][0]["klart_nar"]["grans"] = -2
        self.assertIn("saker[0].klart_nar: ska vara samma som när övningen valdes",
                      H.kontrollera_att_jobba_pa(self.hist, d2))
        d2 = copy.deepcopy(d)
        d2["saker"][0]["ovning"]["steg"] = "full_fart"
        self.assertIn("inget hopp", "; ".join(H.kontrollera_att_jobba_pa(self.hist, d2)))

    @staticmethod
    def fortsatt(d: dict, analys: dict) -> dict:
        """Förra valet skrivet om för nästa pass med analysens tal, som skillen gör."""
        bed = {x["id"]: x for x in analys["bedomning"]}
        d["pass"], d["skapad"] = P2, "2026-11-06T21:00:00+01:00"
        s = d["saker"][0]
        s["nu"] = bed[s["fel"]]["visat"]
        s["ovning"]["steg"] = "halv_fart"
        for f in s["foljdfel"]:
            f["nu"] = bed[f["fel"]]["visat"]
        return d

    def test_ut_far_inte_ligga_i_repot_utom_data(self) -> None:
        kod, ut = _kor(S.main, [*map(str, self.p1), "--ut", str(S.REPO / "tools" / "analys"), "--langd", "1.8"])
        self.assertEqual(kod, 1)
        self.assertIn("--ut: mappen ligger i repot men inte i data/", ut)
        self.assertFalse((S.REPO / "tools" / "analys").exists())
        self.assertTrue(S.utanfor_repot(S.REPO / "data" / "historik"))
        self.assertTrue(S.utanfor_repot(Path(self.tmp.name)))
        self.assertFalse(S.utanfor_repot(S.REPO / "docs" / ".." / "tools"))

    def test_forra_passet_ur_paket_utan_historik(self) -> None:
        with tempfile.TemporaryDirectory() as ut:
            kod, text = _kor(S.main, [*map(str, self.p2), "--forra", *map(str, self.p1), "--ut", ut,
                                      "--langd", "1.80", "--utan-kontaktark"])
            self.assertEqual(kod, 0, text)
            a = json.loads((Path(ut) / "analys.json").read_text(encoding="utf-8"))
        self.assertEqual((a["forra"]["pass"], a["baslinje"]["pass"]), (P1, [P1]))
        self.assertEqual(a["baslinje"]["svingar"], {"dtl": 8, "fo": 8})


if __name__ == "__main__":
    unittest.main()
