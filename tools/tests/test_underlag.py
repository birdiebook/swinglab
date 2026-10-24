"""Underlaget till Claude-appen och svaret tillbaka (S5b, BESLUT B52–B54, METOD MT11–MT12):
instruktionen ur skillens markörer, datan ur en påhittad passhistorik, storleken, och
svarstexterna. Facit för Swift (claude_facit.json, ClaudeKallor.swift) ska vara Pythons."""
from __future__ import annotations

import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path

import _hjalp  # noqa: F401
from pc import analys as A
from pc import att_jobba_pa as AJP
from pc import generera_paket as GP
from pc import historik as H
from pc import session as S
from pc import underlag as U

INSTR_MAX = 8 * 1024       # METOD MT11: instruktionen, byte
DATA_TYPISKT = 7680        # METOD MT11: datan för ett typiskt pass, 8 KiB med marginal
TEXT_MAX = 24 * 1024       # METOD MT11: hela texten, även det värsta fallet i facit


def _kor(main, argv) -> tuple[int, str]:
    ut = io.StringIO()
    with contextlib.redirect_stdout(ut):
        kod = main(argv)
    return kod, ut.getvalue()


def _data(text: str) -> dict:
    block = AJP.kodblock(text)
    return json.loads(block[-1])


class Instruktionen(unittest.TestCase):
    def test_avsnitten_ur_skillen(self) -> None:
        i = U.instruktion()
        self.assertTrue(i.startswith("**Claude-appen.**"))
        for del_ in ("**A. Läget för förra valet först.**", "**I. Övningen, stegen och tanken.**",
                     "## Det Claude inte får göra", "- **Säga att något är rörlighet**"):
            self.assertIn(del_, i)
        for ute in ("## Kommandona", "**J. ", "**K. ", "3D-mått", "## Exemplet", "<!--"):
            self.assertNotIn(ute, i)

    def test_markorerna_maste_ga_ihop(self) -> None:
        with self.assertRaises(ValueError):
            U.instruktion("a " + U.START + " b")
        with self.assertRaises(ValueError):
            U.instruktion("a " + U.SLUT)
        with self.assertRaises(ValueError):
            U.instruktion(U.START + U.START + U.SLUT)
        with self.assertRaises(ValueError):
            U.instruktion("inga markörer")
        self.assertEqual(U.instruktion(f"x{U.START}\nett\n{U.SLUT}y{U.START}två{U.SLUT}"), "ett\n\ntvå")

    def test_swift_bar_samma_instruktion_och_kedjor(self) -> None:
        """BESLUT B53: appens källa är skillens och kedjornas text, ordagrant."""
        self.assertEqual(U.KALLOR_SWIFT.read_text(encoding="utf-8"), U.swift_kalla(),
                         "kör python3 tools/pc/underlag.py --swift")


class Datan(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.hist = U.facit_historiker()
        cls.text = {n: U.facit_text(h) for n, h in cls.hist.items()}

    def test_facit_ar_pythons(self) -> None:
        """Swift prövas mot den här filen (BESLUT B12, B53)."""
        self.assertEqual(U.FACIT.read_text(encoding="utf-8"), U.facit_json(), "kör python3 tools/pc/underlag.py --swift")

    def test_storleken(self) -> None:
        """Instruktionen under 8 KiB, ett typiskt pass (två vyer, sex pass, en övning som
        fortsätter) under 8 KiB data med marginal, och varje historik under 24 KiB."""
        instr = len(U.instruktion().encode())
        self.assertLessEqual(instr, INSTR_MAX)
        self.assertLessEqual(len(self.text["typiskt"].encode()) - instr, DATA_TYPISKT)
        for namn, t in self.text.items():
            self.assertLessEqual(len(t.encode()), TEXT_MAX, namn)

    def test_texten_ar_instruktion_och_data(self) -> None:
        t = self.text["typiskt"]
        self.assertTrue(t.startswith(U.RUBRIK + "20261120-180000\n\n" + U.instruktion() + "\n\n## Datan\n\n```json\n"))
        self.assertTrue(t.endswith("\n```\n"))
        d = _data(t)
        self.assertEqual(list(d), ["pass", "datum", "klubba", "slag", "tempo_vy", "forra", "baslinje", "kandidater",
                                   "bedomning", "spridning", "historik", "ovningar", "pagaende", "fil", "mallar"])
        self.assertEqual(d["fil"], {"format": AJP.FORMAT, "pass": "20261120-180000",
                                    "skapad": "2026-11-20T21:15:00+01:00"})

    def test_mallen_for_en_ovning_som_fortsatter(self) -> None:
        d = _data(self.text["typiskt"])
        o = d["ovningar"][0]
        self.assertEqual((o["fel"], o["lage"], o["steg"]), ("sway_topp", "fortsatt", "halv_fart"))
        m = d["mallar"][0]
        self.assertEqual(m["fel"], "sway_topp")
        self.assertEqual(m["klart_nar"], o["klart_nar"])
        self.assertEqual(m["steg_val"], ["halv_fart", "full_fart"])
        self.assertEqual([x["id"] for x in m["ovning_val"]], ["kapp_och_fotterna_ihop"])
        self.assertEqual(m["block"], {"start": "2026-11-06", "vecka": 3})
        # Följdfelen med kedjans hela väg, även två led bort.
        vag = {f["fel"]: f["vag"] for f in m["foljdfel"]}
        self.assertEqual(vag["early_extension"], ["sway_topp", "reverse_spine", "early_extension"])
        # Ett följdfel får ingen mall (steg D).
        self.assertNotIn("early_extension", [x["fel"] for x in d["mallar"]])

    def test_mallen_nar_minnet_sager_byt_ovning(self) -> None:
        d = _data(self.text["byt"])
        self.assertEqual(d["ovningar"][0]["lage"], "byt_ovning")
        m = d["mallar"][0]
        self.assertEqual([x["kalla"] for x in m["ovning_val"]], ["research3"])
        self.assertNotIn("stol_bakom", [x["id"] for x in m["ovning_val"]])
        self.assertEqual((m["steg_val"], m["block"]["start"]), (["langsamt_med_foremal"], "2026-12-03"))

    def test_forsta_passet(self) -> None:
        d = _data(self.text["forsta"])
        self.assertEqual((d["forra"], d["ovningar"], d["pagaende"], d["slag"]), (None, [], None, {"dtl": 0, "fo": 12}))
        self.assertEqual(d["mallar"][0]["block"], {"start": "2026-12-01", "vecka": 1})
        self.assertIn("okand", {b["status"] for b in d["bedomning"]})

    def test_lagena(self) -> None:
        """Lägena i minnet (METOD MT5, BESLUT B56): klart på båda skälen, fysik, ny och avslutad."""
        lagen = {n: {o["fel"]: (o["lage"], o.get("klart_skal")) for o in _data(t)["ovningar"]}
                 for n, t in self.text.items()}
        self.assertEqual(lagen["klart"], {"sway_topp": ("klart", "klart_nar"),
                                          "bojd_framre_arm": ("klart", "inte_flaggat")})
        self.assertEqual(lagen["fysik"], {"early_extension": ("fysik", None)})
        # Swayen (FO) väntar medan passen är DTL; over the top släpps av ett DTL-val.
        self.assertEqual(lagen["vyer"], {"sway_topp": ("ny", None), "over_the_top": ("avslutad", None),
                                         "early_extension": ("fortsatt", None)})

    def test_gront_och_mallarna(self) -> None:
        for namn, t in self.text.items():
            d = _data(t)
            self.assertNotIn("gron", {b["status"] for b in d["bedomning"]}, namn)
            for rader in d["historik"]["fel"].values():
                self.assertTrue(any(r and r[1] != "gron" for r in rader), namn)
            fortsatter = {o["fel"] for o in d["ovningar"] if o["lage"] in ("ny", "fortsatt", "fysik")}
            self.assertLessEqual(len([m for m in d["mallar"] if m["fel"] not in fortsatter]), U.MAX_NYA_MALLAR)
            for m in d["mallar"]:
                self.assertIn(m["grund"], ("grans", "baslinje", None))
        self.assertEqual(len(_data(self.text["varsta"])["mallar"]), 3)

    def test_spridning_under_atta_slag(self) -> None:
        d = _data(self.text["vyer"])
        self.assertEqual({(s["n"], s["visat"]) for s in d["spridning"]}, {(6, None)})

    def test_klubborna_och_langden(self) -> None:
        """BESLUT B56: varje klubba för sig, baslinjen ur samma klubba och längd, även ur en annan
        klubbas pass (delar), och valet för en annan klubba rör inte saken."""
        h = self.hist["klubbor"]
        enh = U.analysera_historik(h)
        self.assertEqual([(u["pass"][4:8], u["klubba_id"], u["huvud"]) for u in enh],
                         [("0301", "j7", True), ("0301", "dr", False), ("0303", "dr", True), ("0305", None, True),
                          ("0305", "j7", False), ("0307", "j7", True), ("0309", "j7", True)])
        d = _data(self.text["klubbor"])
        self.assertEqual((d["klubba"], d["baslinje"]["pass"], d["forra"]), ("j7", 2, "20260305-150000"))
        self.assertEqual([(o["fel"], o["lage"], o["ovning_id"]) for o in d["ovningar"]],
                         [("sway_topp", "fortsatt", "kapp_och_fotterna_ihop")])

    def test_kompakt_json_som_swift(self) -> None:
        self.assertEqual(U.skriv({"a": [1, 2.5, None, True, "x\"\n"], "b": {"c": {"d": [0.0, -0.0, 1e-05]}}}),
                         '{\n"a":[\n1,\n2.5,\nnull,\ntrue,\n"x\\"\\n"\n],\n"b":{\n"c":{"d":[0,0,1e-05]}\n}\n}')


class Svaret(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.facit = U.facit()
        cls.svar = {s["namn"]: s for s in cls.facit["historiker"][0]["svar"]}

    def test_giltiga_svar(self) -> None:
        for n in ("giltigt", "utan_markning", "bara_json", "typografiska", "flera_block", "annat_block_sist"):
            self.assertTrue(self.svar[n]["godkand"], n)
            self.assertEqual(self.svar[n]["fel"], [], n)
        for h in self.facit["historiker"]:
            if h["namn"] != "klart":
                self.assertTrue(h["svar"][0]["godkand"], h["namn"])

    def test_varje_felkod_har_ett_svar(self) -> None:
        """En ändring per felkod (BESLUT B54). ej_i_analysen går inte att nå: analysen
        bedömer alltid hela katalogen."""
        import re
        kalla = (U.ROT / "tools" / "pc" / "att_jobba_pa.py").read_text(encoding="utf-8")
        alla = set(re.findall(r'_F\([^\n]*?, "(\w+)"(?:, [^\n]*)?\)', kalla))
        alla |= set(re.findall(r'Kontrollfel\("[^"]*", "svaret", "(\w+)"\)', kalla))
        sedda = {k for h in self.facit["historiker"] for s in h["svar"] for _, k in s["fel"]}
        self.assertEqual(alla - sedda, {"ej_i_analysen"})
        for n, s in self.svar.items():
            if not s["godkand"]:
                self.assertTrue(s["fel"], n)

    def test_ogiltiga_svar(self) -> None:
        self.assertEqual(self.svar["inget_block"]["fel"], [["svaret", "inget_block"]])
        self.assertEqual(self.svar["trasig_json"]["fel"], [["svaret", "inte_json"]])
        self.assertEqual(self.svar["djup"]["fel"], [["svaret", "inte_json"]])
        self.assertEqual(self.svar["djup_33"]["fel"], [["svaret", "inte_json"]])
        self.assertEqual(self.svar["djup_32"]["fel"], [["extra", "okand_nyckel"]])
        self.assertEqual(self.svar["for_stort"]["fel"], [["svaret", "for_stort"]])
        self.assertEqual(self.svar["ej_i_katalogen"]["fel"], [["saker[1].fel", "ej_i_katalogen"]])
        self.assertEqual(self.svar["antal"]["fel"], [["saker", "antal"]])
        # true är inte 1 (BESLUT B54).
        self.assertEqual(self.svar["ordning_bool"]["fel"], [["saker[0].ordning", "ordning"]])
        self.assertEqual(self.svar["vecka_bool"]["fel"], [["saker[1].block.vecka", "block_vecka"]])
        self.assertEqual(self.svar["nu_bool"]["fel"], [["saker[1].nu", "analysens_tal"]])
        self.assertEqual(self.svar["pass_form"]["fel"], [["pass", "pass_form"]])

    def test_avrundningen(self) -> None:
        """Pythons round() på det exakta binära talet, som Swift gör efter (METOD MT3)."""
        f = {(m, v): r for m, v, r in self.facit["avrundning"]}
        self.assertEqual(f[("backen_sway_topp", 0.35)], 0.3)
        self.assertEqual(f[("backen_sway_topp", 0.25)], 0.2)
        self.assertEqual(f[("handens_vinkelfart", 2.5)], 2.0)

    def test_kodblocken(self) -> None:
        self.assertEqual(AJP.kodblock("a\n```json\n{1}\n```\nb ```\n2\n``` ```x"), ["{1}\n", "2\n"])
        self.assertEqual(AJP.kodblock("````\nx\n```"), ["x\n"])          # fyra backticks: blocket börjar på den andra
        self.assertEqual(AJP.kodblock("```json {\n```"), [""])
        self.assertEqual(AJP.kodblock("```\nöppet"), [])
        # Samma fall prövas i Swift ur facit.
        for text, block in self.facit["kodblock"]:
            self.assertEqual(AJP.kodblock(text), block)

    def test_felen_namner_falt_aldrig_varden(self) -> None:
        """Dataregeln: felet säger fältet, aldrig det som stod i svaret."""
        for h in self.facit["historiker"]:
            u, ov = U.facit_kontext(h["historik"])
            for s in h["svar"]:
                _, fel = AJP.las_svar(s["text"], u, ov)
                for f in fel:
                    for varde in ("slice", "great", "Great", "Well", "Vänd", "igår", "-1.0", "20261399", "kg"):
                        self.assertNotIn(varde, str(f), s["namn"])


class Koderna(unittest.TestCase):
    def test_varje_kod_har_en_engelsk_text_i_appen(self) -> None:
        """BESLUT B54: telefonen visar koden på engelska; en ny kod i Python behöver sin text."""
        import re
        kalla = (U.ROT / "tools" / "pc" / "att_jobba_pa.py").read_text(encoding="utf-8")
        koder = set(re.findall(r'_F\([^\n]*?, "(\w+)"(?:, [^\n]*)?\)', kalla))
        koder |= set(re.findall(r'Kontrollfel\("[^"]*", "svaret", "(\w+)"\)', kalla))
        texter = (U.ROT / "SwingLabKit" / "Sources" / "Swing" / "Visning" / "Texter.swift").read_text(encoding="utf-8")
        i = texter.index("kontrollfelTexter")
        swift = set(re.findall(r'"(\w+)": "', texter[i:texter.index("]", texter.index("inte_att_jobba_pa"))]))
        self.assertGreater(len(koder), 50)
        self.assertEqual(koder - swift, set())


class PCvagen(unittest.TestCase):
    """session.py --claude-text och att_jobba_pa.py --ur-text på skillens påhittade exempel."""

    def test_hela_vagen(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            t = Path(tmp)
            hist = t / "historik"
            p1, p2 = "20261103-180000", "20261106-180000"
            paket1 = [GP.paket(t / "in", p1, vy, serier=2, langd_m=None) for vy in ("fo", "dtl")]
            paket2 = [GP.paket(t / "in", p2, vy, serier=2, seed=2, sway_topp=-3.5, forsta_serien_flytt=-0.5,
                               langd_m=None) for vy in ("fo", "dtl")]
            kod, ut = _kor(S.main, [*map(str, paket1), "--historik", str(hist), "--langd", "1.80",
                                    "--utan-kontaktark", "--claude-text"])
            self.assertEqual(kod, 0, ut)
            text = (hist / "pass" / p1 / "claude-text.txt").read_text(encoding="utf-8")
            d = _data(text)
            m = d["mallar"][0]
            self.assertEqual(m["fel"], "sway_topp")
            # Svaret som skillen bygger det ur mallen, med text runt om.
            sak = {"ordning": 1, **{k: m[k] for k in ("fel", "namn", "vy", "matt", "enhet", "nu", "spann",
                                                     "markning")},
                   "ovning": {"id": m["ovning_val"][0]["id"], "text": m["ovning_val"][0]["text"],
                              "tanke": "Leave the stick standing.", "kalla": m["ovning_val"][0]["kalla"],
                              "steg": m["steg_val"][0]},
                   "klart_nar": m["klart_nar"], "foljdfel": m["foljdfel"], "typ": "teknik", "fysik": None,
                   "block": m["block"]}
            svar = t / "svar.txt"
            svar.write_text("Rapport.\n\n```json\n" + json.dumps(dict(d["fil"], saker=[sak]), ensure_ascii=False)
                            + "\n```\n", encoding="utf-8")
            analys = hist / "pass" / p1 / "analys.json"
            fil = t / "att_jobba_pa.json"
            kod, ut = _kor(AJP.main, ["--ur-text", str(svar), "--analys", str(analys), "--historik", str(hist),
                                      "--ut", str(fil)])
            self.assertEqual(kod, 0, ut)
            kod, ut = _kor(H.main, ["--rot", str(hist), "spara-att-jobba-pa", str(fil)])
            self.assertEqual(kod, 0, ut)
            # Nästa pass: övningen fortsätter, och mallen bär minnets "klart när" och nästa steg.
            kod, ut = _kor(S.main, [*map(str, paket2), "--historik", str(hist), "--utan-kontaktark", "--claude-text"])
            self.assertEqual(kod, 0, ut)
            d2 = _data((hist / "pass" / p2 / "claude-text.txt").read_text(encoding="utf-8"))
            self.assertEqual(d2["ovningar"][0]["lage"], "fortsatt")
            m2 = next(x for x in d2["mallar"] if x["fel"] == "sway_topp")
            self.assertEqual((m2["klart_nar"], m2["steg_val"]), (m["klart_nar"], ["langsamt_med_foremal", "halv_fart"]))
            # Ett trasigt svar stoppar med fältet.
            svar.write_text("```json\n{\"format\": 1,\n```", encoding="utf-8")
            kod, ut = _kor(AJP.main, ["--ur-text", str(svar), "--analys", str(analys), "--historik", str(hist)])
            self.assertEqual((kod, ut.strip()), (1, f"{svar}: svaret: blocket går inte att läsa som JSON"))

    def test_rader_ger_samma_analys_som_paketen(self) -> None:
        """analysera_rader är analysera utan paketen: samma bedömning och kandidater."""
        with tempfile.TemporaryDirectory() as tmp:
            paket = [GP.paket(Path(tmp), "20261103-180000", vy, serier=2, langd_m=None) for vy in ("fo", "dtl")]
            from pc import paket as P
            pk = [P.las(p) for p in paket]
            a = A.analysera(pk, 1.80, [], skapad="")
            slag = [r for p in sorted(pk, key=lambda p: p.vy) for r in A.mat_paket(p, 1.80)]
            b = A.analysera_rader(a["pass"], slag, 1.80, [], skapad="")
            for k in ("bedomning", "kandidater", "session", "forsta_serien", "spridning", "tempo_vy"):
                self.assertEqual(json.dumps(a[k]), json.dumps(b[k]), k)


if __name__ == "__main__":
    unittest.main()
