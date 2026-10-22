"""Kontrollen av att_jobba_pa.json (METOD MT5, MT6, MT8, MT10): skillens regler i
kod, alltid mot en analys. Analyserna här är påhittade och har bara de fält
kontrollen läser; fixturen prövas mot en riktig körning i test_exempel.py."""
from __future__ import annotations

import unittest

import _hjalp  # noqa: F401
from pc import analys as A
from pc import att_jobba_pa as AJP
from pc import katalog as KAT

PASS = "20261103-180000"
KED = A.las_kedjor()
KATL = KAT.las()
K = {f["id"]: f for f in KATL["fel"]}
KN = {"villkor": "<=", "grans": 0.5, "grund": "nu", "markning": "egen"}


def _analys(status: dict[str, str], visat: dict | None = None, kn: dict | None = None) -> dict:
    """En påhittad analys: varje fel grönt utom de i `status`."""
    bed = []
    for f in KATL["fel"]:
        bed.append({"id": f["id"], "fas": f["fas"], "status": status.get(f["id"], "gron"), "z": None,
                    "visat": (visat or {}).get(f["id"], 1.0), "klart_nar": (kn or {}).get(f["id"], KN)})
    return {"pass": PASS, "bedomning": bed, "kandidater": A.kandidater(bed, KED)}


def _sak(fid: str, ordning: int = 1, **kw) -> dict:
    k = K[fid]
    s = {"ordning": ordning, "fel": fid, "namn": k["namn"], "vy": k["vy"], "matt": k["matt"],
         "enhet": A.enhet(k["matt"]), "nu": 1.0, "spann": k["gront"], "markning": "egen",
         "ovning": {"text": k["ovning"], "tanke": "The chair stays in contact.", "kalla": "katalog",
                    "steg": "langsamt_med_foremal"},
         "klart_nar": {"villkor": "<=", "grans": 0.5, "pa": "forsta_serien", "pass_i_rad": 2},
         "foljdfel": [], "typ": "teknik", "fysik": None, "block": {"start": "2026-11-03", "vecka": 1}}
    s.update(kw)
    return s


def _doc(*saker) -> dict:
    return {"format": AJP.FORMAT, "pass": PASS, "skapad": "2026-11-03T21:15:00+01:00", "saker": list(saker)}


def _ff(fel: str, vag: list[str], nu: float = 1.0) -> dict:
    return {"fel": fel, "namn": K[fel]["namn"], "vag": vag, "nu": nu, "enhet": A.enhet(K[fel]["matt"])}


class Grunden(unittest.TestCase):
    def kolla(self, d, analys=None, ov=None) -> str:
        return "; ".join(AJP.kontrollera(d, analys or _analys({"early_extension": "rod"}), ov))

    def test_en_giltig_sak(self) -> None:
        self.assertEqual(self.kolla(_doc(_sak("early_extension"))), "")

    def test_en_till_tre_saker(self) -> None:
        fel = ["sway_topp", "flying_elbow", "over_the_top", "chicken_wing"]
        a = _analys({f: "rod" for f in fel})
        s = [_sak(f, i + 1, markning="egen") for i, f in enumerate(fel)]
        self.assertIn("1–3", self.kolla(_doc(), a))
        self.assertIn("1–3", self.kolla(_doc(*s), a))
        self.assertEqual(self.kolla(_doc(*s[:3]), a), "")

    def test_formen_ar_stangd(self) -> None:
        d = _doc(_sak("early_extension"))
        d["kommentar"] = "x"
        self.assertIn("filen: okänd nyckel kommentar", self.kolla(d))
        s = _sak("early_extension", extra=1)
        self.assertIn("saker[0]: okänd nyckel extra", self.kolla(_doc(s)))
        s = _sak("early_extension")
        s["ovning"]["bild"] = "x.png"
        self.assertIn("saker[0].ovning: okänd nyckel bild", self.kolla(_doc(s)))
        s = _sak("early_extension")
        del s["block"]
        self.assertIn("saker[0]: block saknas", self.kolla(_doc(s)))
        s = _sak("early_extension")
        s["klart_nar"]["mal"] = 1
        self.assertIn("klart_nar: okänd nyckel mal", self.kolla(_doc(s)))

    def test_bara_katalogens_fel_och_text(self) -> None:
        self.assertIn("finns inte i katalogen", self.kolla(_doc(_sak("early_extension", fel="slice"))))
        self.assertIn("namn: ska vara katalogens", self.kolla(_doc(_sak("early_extension", namn="EE"))))
        self.assertIn("avstängt", self.kolla(_doc(_sak("axellutning")), _analys({"axellutning": "rod"})))

    def test_kommandot_kraver_analysen(self) -> None:
        """Granskningen fynd 5: inget läge utan --analys."""
        import contextlib
        import io
        from pathlib import Path
        fixtur = Path(__file__).resolve().parent / "fixturer" / "att_jobba_pa_exempel.json"
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            AJP.main([str(fixtur)])

    def test_analysens_pass(self) -> None:
        d = _doc(_sak("early_extension"))
        d["pass"] = "20261104-180000"
        self.assertIn("analysens pass", self.kolla(d))


class Valet(unittest.TestCase):
    def kolla(self, d, analys) -> str:
        return "; ".join(AJP.kontrollera(d, analys))

    def test_tidigt_i_svingen_forst(self) -> None:
        a = _analys({"sway_topp": "rod", "chicken_wing": "rod"})
        d = _doc(_sak("chicken_wing"), _sak("sway_topp", 2))
        self.assertIn("tidigt går först", self.kolla(d, a))

    def test_foljdfel_av_en_vald_sak_ar_ingen_egen_sak(self) -> None:
        a = _analys({"sway_topp": "rod", "early_extension": "rod"})
        fel = self.kolla(_doc(_sak("sway_topp"), _sak("early_extension", 2)), a)
        self.assertIn("följdfel av en annan vald sak", fel)

    def test_foljdfel_ensamt_nar_orsaken_ar_flaggad(self) -> None:
        """Granskningen fynd 1: backens_resa_framat ensam när sway_topp är flaggad."""
        a = _analys({"sway_topp": "gul", "backens_resa_framat": "rod"})
        self.assertIn("följdfel av ett flaggat fel", self.kolla(_doc(_sak("backens_resa_framat")), a))
        self.assertEqual(self.kolla(_doc(_sak("backens_resa_framat")), _analys({"backens_resa_framat": "rod"})), "")

    def test_okant_bara_nar_inget_ar_flaggat(self) -> None:
        a = _analys({"sway_topp": "rod", "flying_elbow": "okand"})
        self.assertIn("okänt fel får väljas bara", self.kolla(_doc(_sak("flying_elbow")), a))
        self.assertEqual(self.kolla(_doc(_sak("flying_elbow")), _analys({"flying_elbow": "okand"})), "")

    def test_ett_gront_matt_ovas_inte(self) -> None:
        self.assertIn("inte flaggat", self.kolla(_doc(_sak("flying_elbow")), _analys({})))


class Talen(unittest.TestCase):
    """Talen är analysens (BESLUT B2)."""

    def setUp(self) -> None:
        self.a = _analys({"sway_topp": "rod"}, visat={"sway_topp": -5.7, "reverse_spine": 4.0, "early_extension": 3.3},
                         kn={"sway_topp": {"villkor": ">=", "grans": 0, "grund": "grans", "markning": "B10"}})

    def sway(self, **kw) -> dict:
        s = _sak("sway_topp", nu=-5.7, markning="B10",
                 klart_nar={"villkor": ">=", "grans": 0, "pa": "forsta_serien", "pass_i_rad": 2})
        s.update(kw)
        return s

    def kolla(self, s) -> str:
        return "; ".join(AJP.kontrollera(_doc(s), self.a))

    def test_samma_tal_gar_igenom(self) -> None:
        self.assertEqual(self.kolla(self.sway()), "")

    def test_eget_tal_egen_grans_egen_markning(self) -> None:
        self.assertIn("nu: ska vara analysens", self.kolla(self.sway(nu=-5.0)))
        kn = {"villkor": ">=", "grans": -2, "pa": "forsta_serien", "pass_i_rad": 2}
        self.assertIn("analysens förslag", self.kolla(self.sway(klart_nar=kn)))
        self.assertIn("markning: ska vara analysens", self.kolla(self.sway(markning=None)))

    def test_klart_nar_ar_ett_villkor_pa_forsta_serien_tva_pass_i_rad(self) -> None:
        def kn(**x):
            return dict({"villkor": ">=", "grans": 0, "pa": "forsta_serien", "pass_i_rad": 2}, **x)
        self.assertIn("klart_nar.pa", self.kolla(self.sway(klart_nar=kn(pa="passet"))))
        self.assertIn("klart_nar.grans", self.kolla(self.sway(klart_nar=kn(grans="lite"))))
        self.assertIn("klart_nar.villkor", self.kolla(self.sway(klart_nar=kn(villkor="nära"))))
        self.assertIn("pass_i_rad: ska vara 2", self.kolla(self.sway(klart_nar=kn(pass_i_rad=3))))
        self.assertIn("pass_i_rad: ska vara 2", self.kolla(self.sway(klart_nar=kn(pass_i_rad=1))))

    def test_foljdfel_genom_kedjan_flera_led(self) -> None:
        ff = [_ff("reverse_spine", ["sway_topp", "reverse_spine"], 4.0),
              _ff("early_extension", ["sway_topp", "reverse_spine", "early_extension"], 3.3)]
        self.assertEqual(self.kolla(self.sway(foljdfel=ff)), "")

    def test_foljdfel_fel_vag_namn_tal_eller_utan_kedja(self) -> None:
        self.assertIn("ingen kedja", self.kolla(self.sway(foljdfel=[_ff("flying_elbow", ["sway_topp", "flying_elbow"])])))
        self.assertIn("vag: ska vara kedjans", self.kolla(self.sway(foljdfel=[_ff("early_extension",
                                                                                   ["sway_topp", "early_extension"], 3.3)])))
        f = _ff("reverse_spine", ["sway_topp", "reverse_spine"], 4.0)
        self.assertIn("nu: ska vara analysens", self.kolla(self.sway(foljdfel=[dict(f, nu=3.0)])))
        self.assertIn("namn: ska vara katalogens", self.kolla(self.sway(foljdfel=[dict(f, namn="RSA")])))


class Fritexten(unittest.TestCase):
    def kolla(self, tanke: str) -> str:
        s = _sak("early_extension")
        s["ovning"]["tanke"] = tanke
        return "; ".join(AJP.kontrollera(_doc(s), _analys({"early_extension": "rod"})))

    def test_vardeord_pa_ordstam(self) -> None:
        """Den engelska listan (BESLUT B30), på ordstam och oavsett versaler."""
        for t in ("Good rotation.", "Better balance.", "Best swing yet.", "Worse balance.", "Worst of the day.",
                  "Bad shot.", "Poorly timed.", "Great turn.", "Perfect swings.", "Nicely done.", "Excellent.",
                  "Awesome.", "Amazing pivot.", "Fine contact.", "Fantastic.", "Terrible.", "Wrong way."):
            self.assertIn("värdeord", self.kolla(t), t)

    def test_inga_falska_traffar(self) -> None:
        for t in ("Hands at the top.", "The chair stays there to the finish.", "Find the stick behind you.",
                  "The club steep down.", "Fingers light on the grip.", "The ball sees the top of your cap.",
                  "A strong grip on the club.", "Final position held.", "The badge on the cap faces the ball."):
            self.assertEqual(self.kolla(t), "", t)

    def test_fritexten_ar_engelska(self) -> None:
        """Svensk fritext fälls (BESLUT B30): appen visar den som den står."""
        self.assertIn("engelska", self.kolla("Rör inte käppen."))
        self.assertEqual(self.kolla("Don't touch the stick."), "")

    def test_inga_siffror_utropstecken_eller_langd(self) -> None:
        self.assertIn("inga siffror", self.kolla("Three swings, then 5 more."))
        self.assertIn("utropstecken", self.kolla("The chair!"))
        self.assertIn("högst", self.kolla("x" * (AJP.MAX_TANKE + 1)))

    def test_katalogens_och_kedjornas_texter_ar_rena(self) -> None:
        for f in KATL["fel"]:
            self.assertIsNone(AJP.vardeord(f["ovning"]), f["id"])
            fel: list[str] = []
            AJP._fritext(f["tanke"], f["id"], AJP.MAX_TANKE, fel)
            self.assertEqual(fel, [], f["id"])
        for o in KED["ovningar"]:
            self.assertIsNone(AJP.vardeord(o["text"]), o["text"])
            self.assertIsNone(AJP.SVENSKA.search(o["text"]), o["text"])
            self.assertIn(o["fel"], K)
        for f in KATL["fel"]:
            for falt in ("namn", "ovning"):
                self.assertIsNone(AJP.SVENSKA.search(f[falt]), f"{f['id']}.{falt}")
        for x in KED["fysik"]:
            self.assertIsNone(AJP.SVENSKA.search(x["test"]), x["test"])


class Ovningen(unittest.TestCase):
    def kolla(self, s, ov=None) -> str:
        return "; ".join(AJP.kontrollera(_doc(s), _analys({"early_extension": "rod"}), ov))

    def test_ur_katalogen_ordagrant_eller_ur_listan(self) -> None:
        s = _sak("early_extension")
        s["ovning"]["text"] = "Chair behind."
        self.assertIn("katalogens när kalla är katalog", self.kolla(s))
        s["ovning"]["kalla"] = "research3"
        self.assertIn("en av felets övningar i kedjor.json", self.kolla(s))
        s["ovning"]["text"] = [o["text"] for o in KED["ovningar"] if o["fel"] == "early_extension"][0]
        self.assertEqual(self.kolla(s), "")

    def test_en_ny_ovning_borjar_pa_forsta_steget(self) -> None:
        s = _sak("early_extension")
        s["ovning"]["steg"] = "full_fart"
        self.assertIn("börjar på langsamt_med_foremal", self.kolla(s))
        s["ovning"]["steg"] = "sprint"
        self.assertIn("ovning.steg: ska vara ett av", self.kolla(s))

    def test_blocket_for_ett_nytt_fel(self) -> None:
        self.assertIn("block.start", self.kolla(_sak("early_extension", block={"start": "2026-10-01", "vecka": 1})))
        self.assertIn("block.vecka", self.kolla(_sak("early_extension", block={"start": "2026-11-03", "vecka": 2})))

    def test_treregeln(self) -> None:
        fy = {"test": "Toe touch", "treregeln": [True, True, True], "ovning": "Toe touch progression every morning."}
        self.assertEqual(self.kolla(_sak("early_extension", typ="troligen_rorlighet", fysik=fy)), "")
        self.assertIn("treregeln", self.kolla(_sak("early_extension", typ="troligen_rorlighet",
                                                   fysik=dict(fy, treregeln=[True, False, True]))))
        self.assertEqual(self.kolla(_sak("early_extension", typ="teknik_kroppen_gor_det_svart",
                                         fysik=dict(fy, treregeln=[True, True, False]))), "")
        self.assertEqual(self.kolla(_sak("early_extension", typ="teknik",
                                         fysik=dict(fy, treregeln=[True, False, False], ovning=None))), "")
        self.assertIn("ska vara null för teknik", self.kolla(_sak("early_extension", typ="teknik",
                                                                  fysik=dict(fy, treregeln=[True, False, False]))))
        self.assertIn("fysik: krävs", self.kolla(_sak("early_extension", typ="troligen_rorlighet")))
        self.assertIn("inget test", self.kolla(_sak("early_extension", typ="troligen_rorlighet",
                                                     fysik=dict(fy, test="Plank"))))
        self.assertIn("inga siffror", self.kolla(_sak("early_extension", typ="troligen_rorlighet",
                                                      fysik=dict(fy, ovning="Toe touch, 3 × 10."))))


class Minnet(unittest.TestCase):
    """Fortsätter samma övning flyttar sig inte "klart när" (granskningen fynd 3)."""

    def setUp(self) -> None:
        self.text = K["early_extension"]["ovning"]
        self.o = {"fel": "early_extension", "ovning": self.text, "lage": "fortsatt", "fel_start": "20261020-180000",
                  "klart_nar": {"villkor": "<=", "grans": 2.0, "pa": "forsta_serien", "pass_i_rad": 2},
                  "markning": "egen", "steg": "langsamt_med_foremal", "forra_ovningar": ["Old drill."]}

    def sak(self, **kw) -> dict:
        s = _sak("early_extension", klart_nar={"villkor": "<=", "grans": 2.0, "pa": "forsta_serien", "pass_i_rad": 2},
                 block={"start": "2026-10-20", "vecka": 3})
        s.update(kw)
        return s

    def kolla(self, s, o=None) -> str:
        return "; ".join(AJP.kontrollera(_doc(s), _analys({"early_extension": "rod"}), [o or self.o]))

    def test_fortsatter_med_minnets_klart_nar_och_block(self) -> None:
        self.assertEqual(self.kolla(self.sak()), "")
        self.assertIn("samma som när övningen valdes", self.kolla(self.sak(klart_nar={
            "villkor": "<=", "grans": 0.5, "pa": "forsta_serien", "pass_i_rad": 2})))
        self.assertIn("block.vecka", self.kolla(self.sak(block={"start": "2026-10-20", "vecka": 1})))

    def test_stegen_ett_i_taget(self) -> None:
        s = self.sak()
        s["ovning"]["steg"] = "halv_fart"
        self.assertEqual(self.kolla(s), "")
        s["ovning"]["steg"] = "full_fart"
        self.assertIn("inget hopp", self.kolla(s))

    def test_ny_ovning_for_samma_fel_far_analysens_klart_nar_men_samma_block(self) -> None:
        text = [o["text"] for o in KED["ovningar"] if o["fel"] == "early_extension"][0]
        s = _sak("early_extension", block={"start": "2026-10-20", "vecka": 3})
        s["ovning"].update(text=text, kalla="research3")
        self.assertEqual(self.kolla(s, dict(self.o, lage="byt_ovning")), "")

    def test_klar_byt_provad_och_fysik(self) -> None:
        self.assertIn("släpp saken", self.kolla(self.sak(), dict(self.o, lage="klart")))
        self.assertIn("minnet säger byt övning", self.kolla(self.sak(), dict(self.o, lage="byt_ovning")))
        s = self.sak()
        s["ovning"].update(text="Old drill.", kalla="research3")
        self.assertIn("redan provad", self.kolla(s))
        self.assertIn("minnet säger fysik", self.kolla(self.sak(), dict(self.o, lage="fysik")))

    def test_en_avslutad_ovning_ar_inget_minne(self) -> None:
        self.assertEqual(self.kolla(_sak("early_extension"), dict(self.o, lage="avslutad")), "")


if __name__ == "__main__":
    unittest.main()


