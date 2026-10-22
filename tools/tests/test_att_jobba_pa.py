"""Kontrollen av att_jobba_pa.json (METOD MT5, MT6, MT8): skillens regler i kod.
Fixturen tools/tests/fixturer/att_jobba_pa_exempel.json är påhittad."""
from __future__ import annotations

import copy
import json
import unittest
from pathlib import Path

import _hjalp  # noqa: F401
from pc import analys as A
from pc import att_jobba_pa as AJP

FIXTUR = Path(__file__).resolve().parent / "fixturer" / "att_jobba_pa_exempel.json"


def _sak(**kw) -> dict:
    s = {"ordning": 1, "fel": "early_extension", "namn": "Early extension: bäckenet mot bollen", "vy": "dtl",
         "matt": "backen_thrust_traff", "enhet": "cm", "nu": 3.3, "spann": None, "markning": "egen",
         "ovning": {"text": "Stjärten mot en stol bakom dig, långsamma svingar.", "tanke": "Stolen ska känna stjärten.",
                    "kalla": "research3"},
         "klart_nar": {"villkor": "<=", "grans": 3.1, "pa": "forsta_serien", "pass_i_rad": 2},
         "foljdfel": ["tappad_hallning"], "typ": "teknik", "fysik": None}
    s.update(kw)
    return s


def _doc(*saker) -> dict:
    return {"format": AJP.FORMAT, "pass": "20261103-180000", "skapad": "2026-11-03T21:15:00+01:00",
            "saker": list(saker)}


class Fixturen(unittest.TestCase):
    def test_fixturen_ar_giltig(self) -> None:
        self.assertEqual(AJP.kontrollera(json.loads(FIXTUR.read_text(encoding="utf-8"))), [])

    def test_katalogens_ovningar_och_tankar_har_inga_vardeord(self) -> None:
        from pc import katalog as KAT
        for f in KAT.las()["fel"]:
            fel: list[str] = []
            AJP._text(f["ovning"], f["id"], AJP.MAX_OVNING, fel)
            AJP._text(f["tanke"], f["id"], AJP.MAX_TANKE, fel)
            self.assertEqual(fel, [], f["id"])


class Reglerna(unittest.TestCase):
    def kolla(self, d) -> str:
        return "; ".join(AJP.kontrollera(d))

    def test_en_giltig_sak(self) -> None:
        self.assertEqual(self.kolla(_doc(_sak())), "")

    def test_en_till_tre_saker(self) -> None:
        self.assertIn("1–3", self.kolla(_doc()))
        s = [_sak(ordning=i + 1, fel=f, namn=n, vy=v, matt=m, foljdfel=[]) for i, (f, n, v, m) in enumerate([
            ("sway_topp", "Bäckenet glider bakåt i baksvingen", "fo", "backen_sway_topp"),
            ("flying_elbow", "Flying elbow: bakre armbågen pekar ut i toppen", "dtl", "bakre_armbage_topp"),
            ("over_the_top", "Over the top: händerna utanför i nedsvingen", "dtl", "handbana"),
            ("chicken_wing", "Chicken wing: främre armbågen viker efter träffen", "fo", "framre_armbage_efter_traff")])]
        for x in s:
            x["spann"] = [0, None] if x["fel"] == "sway_topp" else None
            x["enhet"] = A.enhet(x["matt"])
        self.assertIn("1–3", self.kolla(_doc(*s)))
        self.assertEqual(self.kolla(_doc(*s[:3])), "")

    def test_bara_katalogens_fel_och_text(self) -> None:
        self.assertIn("finns inte i katalogen", self.kolla(_doc(_sak(fel="slice"))))
        self.assertIn("namn: ska vara katalogens", self.kolla(_doc(_sak(namn="EE"))))
        self.assertIn("avstängt", self.kolla(_doc(_sak(fel="axellutning", namn="Axellinjens lutning vid träffen",
                                                       vy="fo", matt="axellinje_lutning_traff", enhet="°",
                                                       foljdfel=[]))))

    def test_tidigt_i_svingen_forst(self) -> None:
        sway = _sak(ordning=2, fel="sway_topp", namn="Bäckenet glider bakåt i baksvingen", vy="fo",
                    matt="backen_sway_topp", spann=[0, None], foljdfel=[])
        chicken = _sak(fel="chicken_wing", namn="Chicken wing: främre armbågen viker efter träffen", vy="fo",
                       matt="framre_armbage_efter_traff", enhet="°", foljdfel=[])
        self.assertIn("tidigt går först", self.kolla(_doc(chicken, sway)))

    def test_foljdfel_far_ingen_egen_ovning(self) -> None:
        sway = _sak(fel="sway_topp", namn="Bäckenet glider bakåt i baksvingen", vy="fo",
                    matt="backen_sway_topp", spann=[0, None], foljdfel=[])
        ee = _sak(ordning=2, foljdfel=[])
        self.assertIn("följdfel av en annan vald sak", self.kolla(_doc(sway, ee)))

    def test_foljdfel_bara_enligt_kedjorna(self) -> None:
        self.assertIn("ingen kedja", self.kolla(_doc(_sak(foljdfel=["flying_elbow"]))))

    def test_klart_nar_ar_ett_villkor_i_tal_pa_forsta_serien(self) -> None:
        self.assertIn("klart_nar.pa", self.kolla(_doc(_sak(klart_nar={"villkor": "<=", "grans": 3.1, "pa": "passet",
                                                                     "pass_i_rad": 2}))))
        self.assertIn("klart_nar.grans", self.kolla(_doc(_sak(klart_nar={"villkor": "<=", "grans": "lite",
                                                                        "pa": "forsta_serien", "pass_i_rad": 2}))))
        self.assertIn("klart_nar.villkor", self.kolla(_doc(_sak(klart_nar={"villkor": "nära", "grans": 1,
                                                                          "pa": "forsta_serien", "pass_i_rad": 2}))))

    def test_inga_vardeord_och_kort_tanke(self) -> None:
        o = {"text": "Stolen bakom dig.", "tanke": "Bättre rotation nu", "kalla": "research3"}
        self.assertIn("värdeord (bättre)", self.kolla(_doc(_sak(ovning=o))))
        o = {"text": "Stolen bakom dig.", "tanke": "x" * (AJP.MAX_TANKE + 1), "kalla": "research3"}
        self.assertIn("högst", self.kolla(_doc(_sak(ovning=o))))
        o = {"text": "Bra jobbat!", "tanke": "Stolen.", "kalla": "research3"}
        self.assertIn("utropstecken", self.kolla(_doc(_sak(ovning=o))))

    def test_katalogens_ovning_skrivs_av_ordagrant(self) -> None:
        o = {"text": "Stol bakom.", "tanke": "Stolen.", "kalla": "katalog"}
        self.assertIn("ska vara katalogens när kalla är katalog", self.kolla(_doc(_sak(ovning=o))))

    def test_treregeln(self) -> None:
        fy = {"test": "Toe touch", "treregeln": [True, True, True], "ovning": "Toe touch-progressionen, 3 × 10."}
        self.assertEqual(self.kolla(_doc(_sak(typ="troligen_rorlighet", fysik=fy))), "")
        self.assertIn("treregeln", self.kolla(_doc(_sak(typ="troligen_rorlighet", fysik=dict(fy, treregeln=[True, False, True])))))
        self.assertEqual(self.kolla(_doc(_sak(typ="teknik_kroppen_gor_det_svart",
                                              fysik=dict(fy, treregeln=[True, True, False])))), "")
        self.assertIn("fysik: krävs", self.kolla(_doc(_sak(typ="troligen_rorlighet"))))
        self.assertIn("inget test", self.kolla(_doc(_sak(typ="troligen_rorlighet", fysik=dict(fy, test="Planka")))))


class MotAnalysen(unittest.TestCase):
    """Talen ska vara analysens (BESLUT B2)."""

    def setUp(self) -> None:
        self.analys = {"pass": "20261103-180000", "kandidater": [], "bedomning": [
            {"id": "early_extension", "status": "okand", "visat": 3.3,
             "klart_nar": {"villkor": "<=", "grans": 3.1, "grund": "nu", "markning": "egen"}},
            {"id": "sway_topp", "status": "gron", "visat": 1.2, "klart_nar": None}]}

    def test_samma_tal_gar_igenom(self) -> None:
        self.assertEqual(AJP.kontrollera(_doc(_sak()), analys=self.analys), [])

    def test_eget_tal_eller_egen_grans_fangas(self) -> None:
        fel = "; ".join(AJP.kontrollera(_doc(_sak(nu=3.0)), analys=self.analys))
        self.assertIn("nu: ska vara analysens", fel)
        kn = {"villkor": "<=", "grans": 2.0, "pa": "forsta_serien", "pass_i_rad": 2}
        self.assertIn("analysens förslag", "; ".join(AJP.kontrollera(_doc(_sak(klart_nar=kn)), analys=self.analys)))

    def test_ett_gront_matt_ovas_inte(self) -> None:
        d = _doc(_sak(fel="sway_topp", namn="Bäckenet glider bakåt i baksvingen", vy="fo", matt="backen_sway_topp",
                      spann=[0, None], nu=1.2, foljdfel=[]))
        self.assertIn("inte flaggat", "; ".join(AJP.kontrollera(d, analys=self.analys)))

    def test_fel_pass(self) -> None:
        d = copy.deepcopy(_doc(_sak()))
        d["pass"] = "20261104-180000"
        self.assertIn("analysens pass", "; ".join(AJP.kontrollera(d, analys=self.analys)))


if __name__ == "__main__":
    unittest.main()
