"""S7d: modellens förslag i klubbmarkeringen (BESLUT B93, METOD MF8). Formatet
swinglab-klubba-forslag/1 och dess kontroll, matchningen ruta → position, kontrollen mot ett
paket, källan godkand_forslag i swinglab-klubba och samlingen med källorna. Allt är påhittat
(CLAUDE.md, Dataregeln)."""
from __future__ import annotations

import contextlib
import copy
import io
import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

import _hjalp  # noqa: F401
from pc import generera_paket as GP
from pc import klubba as KL
from pc import klubba_forslag as KF
from pc import paket as P
from pc import samla_klubba as SK


class Formen(unittest.TestCase):
    def test_den_pahittade_filen_ar_giltig_och_incheckad(self) -> None:
        d = KF.pahittad()
        self.assertEqual(KF.kontrollera(d), [])
        self.assertEqual(KF.okanda(d), [])
        self.assertEqual(KF.FIXTURFIL.read_text(encoding="utf-8"), KF.fixtur_text(), "kör klubba_forslag.py --swift")
        self.assertEqual(KF.SWIFTFIL.read_text(encoding="utf-8"), KF.swift_kalla(), "kör klubba_forslag.py --swift")
        # Exemplet i FORMAT.md är en giltig fil.
        text = (KF.REPO / "docs" / "FORMAT.md").read_text(encoding="utf-8")
        start = text.index("## Klubbans förslag")
        block = text[text.index("```json", start) + 7:text.index("```", text.index("```json", start) + 7)]
        self.assertEqual(KF.kontrollera(json.loads(block)), [])

    def test_felen_namner_faltet_aldrig_vardet(self) -> None:
        fel = {n: KF.kontrollera(v) for n, v in KF._fel_varianter()}
        self.assertEqual(fel["format"], ["format: must be swinglab-klubba-forslag/1"])
        self.assertEqual(fel["pass"], ["pass: invalid"])
        self.assertEqual(fel["licens"], ["modell.data[0].licens is missing"])
        self.assertEqual(fel["t_dubbel"], ["slag[0].rutor[2].t: duplicate"])
        self.assertEqual(fel["utanfor"], ["slag[1].rutor[0].punkter.hosel: outside the image"])
        self.assertEqual(fel["konfidens"], ["slag[1].rutor[0].punkter.grepp.konfidens: invalid"])
        self.assertEqual(fel["ingen_punkt"], ["slag[1].rutor[0].punkter: no point"])
        self.assertEqual(len(fel["manga"]), KF.MAX_FEL + 1)
        self.assertEqual(fel["manga"][-1], "more errors skipped")
        for n, f in fel.items():
            self.assertTrue(f, n)
            for rad in f:
                for varde in ("../x", "sidan", "1081", "1.5", "1080.5", "swinglab-klubba-forslag/2:"):
                    self.assertNotIn(varde, rad.replace("swinglab-klubba-forslag/1", ""), n)

    def test_okanda_falt_tillats_men_raknas_upp(self) -> None:
        d = KF.pahittad()
        d["nytt"] = 1
        d["slag"][0]["rutor"][0]["punkter"]["hosle"] = {"x": 1, "y": 1, "konfidens": 0.9}
        self.assertEqual(KF.kontrollera(d), [])
        self.assertEqual(KF.okanda(d), ["nytt", "slag[0].rutor[0].punkter.hosle"])

    def test_heltal_som_telefonen(self) -> None:
        """1080.0 är ett heltal som i telefonens JSON-läsare; 1080.5 och true är det inte."""
        d = KF.pahittad()
        d["bredd"] = 1080.0
        self.assertEqual(KF.kontrollera(d), [])


class Matchningen(unittest.TestCase):
    def test_ruta_for_position(self) -> None:
        d = KF.pahittad()
        r = KF.rutor(d, "s01", 1080, 1920)
        self.assertEqual(len(r), 6)
        self.assertEqual(KF.ruta_for(r, -0.3125), 0)
        self.assertEqual(KF.ruta_for(r, -0.3125 + 0.0019), 0)
        self.assertIsNone(KF.ruta_for(r, -0.3125 - 0.0021))
        # Mellan två rutor: den närmaste.
        self.assertEqual(KF.ruta_for(r, -0.3125 + 2 / 240 + 0.0025), 3)
        self.assertEqual(KF.matcha(r, {"P4": -0.3125, "P1": None}), {"P4": 0, "P1": None})
        self.assertEqual(KF.rutor(d, "s01", 1920, 1080), [], "en annan bild: inga förslag")
        self.assertEqual(KF.rutor(d, "s99"), [])

    def test_visade(self) -> None:
        r = KF.rutor(KF.pahittad(), "s01")
        self.assertEqual(set(KF.visade(r[0])), {"grepp", "hosel", "huvud"})
        self.assertNotIn("skaft_mitt", KF.visade(r[2]), "skaftets mitt visas inte")
        self.assertNotIn("hosel", KF.visade(r[3]), "konfidensen 0,42 visas inte (MF8)")
        self.assertEqual(set(KF.visade(r[5])), {"huvud"})
        self.assertEqual(KF.visade(r[0])["hosel"]["box"], [580.0, 960.0, 60.0, 40.0])


class MotPaketet(unittest.TestCase):
    def test_passet_vyn_slagen_och_rutorna(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            pk = P.las(GP.paket(Path(tmp), "20261024-171500", "dtl", n=2, inte_sving=0))
            s = pk.slag[0]
            d = KF.ny(pk.pass_id, "dtl", "m", "1", [{"namn": "golf-49wbh", "licens": "CC BY 4.0"}],
                      s.lederna["width"], s.lederna["height"])
            for f in s.lederna["frames"][10:13]:
                KF.lagg_till(d, s.id, f["t"], {"grepp": {"x": 10.0, "y": 10.0, "konfidens": 0.9}})
            self.assertEqual(KF.kontrollera(d), [])
            self.assertEqual(KF.mot_paket(d, pk), [])
            fel = copy.deepcopy(d)
            fel["vy"] = "fo"
            fel["slag"][0]["rutor"][1]["t"] = 100.0
            KF.lagg_till(fel, "s99", 0.0, {"grepp": {"x": 10.0, "y": 10.0, "konfidens": 0.9}})
            self.assertEqual(KF.mot_paket(fel, pk), ["vy: does not match the session",
                                                     "slag[0].rutor[1].t: no such frame", "slag[1].id: no such shot"])
            # CLI: OK på filen, fel med fälten.
            ok, trasig = Path(tmp) / "ok.json", Path(tmp) / "fel.json"
            KF.skriv(ok, d)
            trasig.write_text(json.dumps(fel), encoding="utf-8")
            ut = io.StringIO()
            with contextlib.redirect_stdout(ut):
                self.assertEqual(KF.main([str(ok), "--paket", str(GP.paket(Path(tmp), "20261024-171500", "dtl",
                                                                            n=2, inte_sving=0))]), 0)
                self.assertEqual(KF.main([str(trasig), "--paket", str(Path(tmp) / pk.fil)]), 1)
            self.assertIn("OK: 1 slag, 3 rutor", ut.getvalue())
            self.assertIn("slag[1].id: no such shot", ut.getvalue())

    def test_vision_t_ur_opencv(self) -> None:
        frames = [{"t": round(-0.5 + k / 240, 4)} for k in range(100)]
        s = SimpleNamespace(klick_i_klipp_s=2.0, lederna={"frames": frames})
        self.assertEqual(KF.vision_t(s, 2.0 - 0.5 + 10 / 240), frames[10]["t"])
        self.assertEqual(KF.vision_t(s, 2.0 - 0.5 + 10 / 240 + 0.003, forskjutning_ms=3.0), frames[10]["t"])
        self.assertIsNone(KF.vision_t(s, 10.0))
        self.assertIsNone(KF.vision_t(SimpleNamespace(klick_i_klipp_s=None, lederna=None), 1.0))


class KallanIMarkeringen(unittest.TestCase):
    def test_godkand_kraver_forslaget(self) -> None:
        f = KL.fixturer()["fil"]
        self.assertEqual(KL.kontrollera(f), [])
        r = f["rutor"]
        self.assertEqual([(KL.ursprung(x, "grepp"), KL.ursprung(x, "klubbhuvud")) for x in r[:4]],
                         [("handlederna_bekraftad", "klick"), ("godkand_forslag", "godkand_forslag"),
                          ("godkand_forslag", "rattat_forslag"), ("klick", "klick")])
        trasig = copy.deepcopy(f)
        trasig["rutor"][1]["forslag"] = {}
        self.assertEqual(KL.kontrollera(trasig), [
            "rutor[1].punkter.grepp.kalla godkand_forslag kräver forslag.grepp med kalla modell",
            "rutor[1].punkter.klubbhuvud.kalla godkand_forslag kräver forslag.klubbhuvud med kalla modell"])
        v1 = copy.deepcopy(f)
        v1["format"] = KL.FORMAT_1
        for x in v1["rutor"]:
            x["val"], x["t_klipp"], x["forskjutning_ms"] = "jamn", 1.0, 0.0
            x["punkter"]["skaft_mitt"] = x["punkter"]["grepp"]
        self.assertTrue(any("punkter.grepp ska vara" in e for e in KL.kontrollera(v1)), "version 1 har bara klick")

    def test_samla_raknar_kallorna_och_kan_lamna_forslagen(self) -> None:
        f = KL.fixturer()["fil"]
        with tempfile.TemporaryDirectory() as tmp:
            fil = Path(tmp) / f"swinglab-{f['pass']}-klubba.json"
            fil.write_text(json.dumps(f), encoding="utf-8")
            for flagga, rutor in (([], 10), (["--utan-forslag"], 8)):
                ut = Path(tmp) / ("ut" + "".join(flagga))
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(SK.main([str(fil), "--ut", str(ut)] + flagga), 0)
                index = json.loads((ut / "index.json").read_text(encoding="utf-8"))
                self.assertEqual(index["pass"][0]["rutor"], rutor)
                u = index["pass"][0]["ursprung"]
                if not flagga:
                    self.assertEqual(u["grepp"], {"klick": 7, "handlederna_bekraftad": 1, "godkand_forslag": 2,
                                                  "rattat_forslag": 0})
                    self.assertEqual(u["klubbhuvud"], {"klick": 8, "handlederna_bekraftad": 0, "godkand_forslag": 1,
                                                       "rattat_forslag": 1})
                else:
                    self.assertEqual(u["grepp"]["godkand_forslag"] + u["klubbhuvud"]["rattat_forslag"], 0)


if __name__ == "__main__":
    unittest.main()
