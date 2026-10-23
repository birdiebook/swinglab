"""S7a: klubbans mått ur markeringarna (METOD M45–M49), formatet swinglab-klubba/2
(BESLUT B47) läst av markera_klubba.py och paket.py, analysen och historiken med
klubbmåtten, samlingen till en träningsmapp och Swift-fixturerna (BESLUT B12).
Alla markeringar är påhittade (CLAUDE.md, Dataregeln)."""
from __future__ import annotations

import contextlib
import io
import json
import math
import tempfile
import unittest
import zipfile
from pathlib import Path

import _hjalp  # noqa: F401
from pc import analys as A
from pc import generera as gen
from pc import generera_paket as GP
from pc import historik as H
from pc import klubba as KL
from pc import markera_klubba as MK
from pc import paket as P
from pc import samla_klubba as SK

PASS = "20261103-180000"


def _m(p, g, h, t=0.0):
    return {"position": p, "t": t, "grepp": g, "hosel": h}


def _vid(g, vinkel, langd):
    """Hoseln längs vinkeln (grader, y uppåt) från greppet, i bildens pixlar (y nedåt)."""
    return (g[0] + langd * math.cos(math.radians(vinkel)), g[1] - langd * math.sin(math.radians(vinkel)))


class Mattet(unittest.TestCase):
    def test_satta_vinklar_och_spegling(self) -> None:
        """De påhittade skaften ger sina satta vinklar, också för en vänsterspelare (M1, M46)."""
        for namn in ("dtl", "dtl_vanster", "fo"):
            marks, sv = KL.fixtur_markeringar(namn)
            m = KL.mat(marks, sv.vy, sv.x_tecken, KL.FIXTUR_BREDD, KL.FIXTUR_HOJD, sv)
            for p, (vinkel, langd) in KL.SATTA[sv.vy].items():
                if langd < KL.MIN_SKAFT_PX:
                    self.assertNotIn(KL.nyckel("skaft_vinkel", p), m, f"{namn} {p}: för kort skaft")
                    continue
                self.assertAlmostEqual(m[KL.nyckel("skaft_vinkel", p)], vinkel, delta=0.1, msg=f"{namn} {p}")
            if sv.vy == "dtl":
                self.assertAlmostEqual(m["skaftplan_p1"], 60.0, delta=0.1)          # −60° grepp → hosel
                self.assertAlmostEqual(m["skaft_mot_plan_p2"], -25.0, delta=0.15)   # 35° mot 60°: flatare
            else:
                self.assertAlmostEqual(m["skaft_topp"], 10.0, delta=0.1)            # huvudet över: kort av parallellt
                self.assertAlmostEqual(m["skaft_lutning_traff"], 14.0, delta=0.1)   # greppet mot målet

    def test_tecknen(self) -> None:
        g1 = (500.0, 1000.0)
        h1 = _vid(g1, -60, 400)                                  # adressen: hoseln nere mot bollen
        dtl = lambda *x: KL.mat([_m("P1", g1, h1)] + list(x), "dtl", 1, 1080, 1920)  # noqa: E731
        # P2 brantare än planet: +
        self.assertGreater(dtl(_m("P2", g1, _vid(g1, -70, 300)))["skaft_mot_plan_p2"], 0)
        self.assertLess(dtl(_m("P2", g1, _vid(g1, -40, 300)))["skaft_mot_plan_p2"], 0)
        # P6: hoseln rakt ovanför bollen ligger över (utanför) planlinjen, bakom den under.
        over = dtl(_m("P6", (300.0, 900.0), (h1[0], h1[1] - 300)))["skaft_plan_p6"]
        under = dtl(_m("P6", (300.0, 900.0), (h1[0] - 300, h1[1])))["skaft_plan_p6"]
        self.assertAlmostEqual(over, 30.0, delta=1e-9)
        self.assertLess(under, 0)
        # Toppen bakifrån: mitten rakt under greppet; huvudet åt bollen = across (+).
        g4 = (540.0, 500.0)
        self.assertAlmostEqual(dtl(_m("P4", g4, _vid(g4, -60, 200)))["skaft_riktning_topp"], 30.0, delta=1e-9)
        self.assertAlmostEqual(dtl(_m("P4", g4, _vid(g4, -120, 200)))["skaft_riktning_topp"], -30.0, delta=1e-9)
        # Speglat (vänsterspelare, x_tecken −1): bilden spegelvänd ger samma tal.
        spegel = KL.mat([_m("P4", (1080 - g4[0], g4[1]), (1080 - _vid(g4, -60, 200)[0], _vid(g4, -60, 200)[1]))],
                        "dtl", -1, 1080, 1920)
        self.assertAlmostEqual(spegel["skaft_riktning_topp"], 30.0, delta=1e-9)
        # FO: framåtlutning vid träffen = greppet mot målet (+X).
        fo = KL.mat([_m("P7", (500.0, 900.0), _vid((500.0, 900.0), -100, 400))], "fo", 1, 1080, 1920)
        self.assertAlmostEqual(fo["skaft_lutning_traff"], 10.0, delta=1e-9)

    def test_toppen_bakifran_kraver_greppet_over_mitten(self) -> None:
        g = (540.0, 960.0 - 0.04 * 1920)                          # under marginalen (5 %)
        self.assertNotIn("skaft_riktning_topp", KL.mat([_m("P4", g, _vid(g, -60, 200))], "dtl", 1, 1080, 1920))

    def test_sparren_och_hoppade_positioner(self) -> None:
        g = (500.0, 900.0)
        m = KL.mat([_m("P7", g, _vid(g, -60, KL.MIN_SKAFT_PX - 1)), _m("P1", None, None),
                    _m("P4", g, _vid(g, -60, KL.MIN_SKAFT_PX))], "dtl", 1, 1080, 1920)
        self.assertEqual(set(m), {"skaft_vinkel_p4"})
        self.assertAlmostEqual(KL.osakerhet(KL.MIN_SKAFT_PX), 4.05, delta=0.01)   # M46: √2·3/60 rad
        self.assertAlmostEqual(KL.osakerhet(300.0), 0.81, delta=0.01)

    def test_casting_ur_armen(self) -> None:
        """Armen ur svingens utjämnade leder vid markeringens tid (M49): ett skaft i armens
        förlängning ger 180°, ett vinkelrätt 90°."""
        marks, sv = KL.fixtur_markeringar("fo")
        from pc import faser as F
        from pc.format import AXEL_F, HANDLED_F
        p5 = next(m for m in marks if m["position"] == "P5")
        a = F.vid(sv.t, F.jamna(sv.t, sv.xy[:, AXEL_F]), p5["t"])
        w = F.vid(sv.t, F.jamna(sv.t, sv.xy[:, HANDLED_F]), p5["t"])
        ut = ((w[0] - a[0]), (w[1] - a[1]))                     # skuldra → handled, speglat
        n = math.hypot(*ut)
        g = (w[0], w[1])
        rak = (g[0] + 300 * ut[0] / n, g[1] + 300 * ut[1] / n)
        vinkel = (g[0] - 300 * ut[1] / n, g[1] + 300 * ut[0] / n)
        for hosel, vantat in ((rak, 180.0), (vinkel, 90.0)):
            m = KL.mat([{**p5, "grepp": g, "hosel": hosel}], "fo", 1, 1080, 1920, sv)
            self.assertAlmostEqual(m["skaft_arm_p5"], vantat, delta=1e-6)
        self.assertNotIn("skaft_arm_p5", KL.mat([{**p5, "grepp": g, "hosel": rak}], "fo", 1, 1080, 1920))

    def test_forslaget_for_p2_p6_p8(self) -> None:
        pos = {"P1": -1.4, "P3": -0.5, "P4": -0.3, "P5": -0.1, "P7": 0.0, "P9": 0.2, "P10": 1.1}
        self.assertAlmostEqual(KL.forslag_tid("P2", pos, -0.9), -0.7)
        self.assertAlmostEqual(KL.forslag_tid("P2", {**pos, "P3": None}, None), -0.85)
        self.assertAlmostEqual(KL.forslag_tid("P6", pos, None), -0.05)
        self.assertAlmostEqual(KL.forslag_tid("P8", {**pos, "P9": None}, None), 0.55)
        self.assertEqual(KL.forslag_tid("P4", pos, None), -0.3)
        self.assertIsNone(KL.forslag_tid("P3", {**pos, "P3": None}, None))


class Formatet(unittest.TestCase):
    def _fil(self) -> dict:
        marks, _ = KL.fixtur_markeringar("dtl", hoppa=("P8",))
        return KL.fil_ur(marks, "dtl", PASS, f"swinglab-{PASS}-dtl.zip", "s03")

    def test_version_2_las_av_markera_klubba(self) -> None:
        d = self._fil()
        self.assertEqual(KL.kontrollera(d), [])
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp) / "klubba.json"
            f.write_text(json.dumps(d), encoding="utf-8")
            self.assertEqual(MK.las(f), d)
            MK.skriv(f, d)                                         # PC:ns skrivning tar den
        m = KL.markeringar(d)["s03"]
        self.assertEqual([x["position"] for x in m], list(KL.POSITIONER))
        self.assertIsNone(next(x for x in m if x["position"] == "P8")["grepp"])

    def test_version_1_uppgraderas_och_skrivs_som_2(self) -> None:
        rutor = MK.valj_video(Path("x.mov"), 4.0, 1080, 1920, "fo", 2)
        d = {**MK.ny(rutor, ["x.mov"], None), "format": KL.FORMAT_1}
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp) / "m.json"
            f.write_text(json.dumps(d), encoding="utf-8")
            self.assertEqual(MK.las(f)["format"], KL.FORMAT)
        self.assertEqual(MK.ny(rutor, ["x.mov"], None)["format"], KL.FORMAT)

    def test_skillnaderna_mellan_versionerna(self) -> None:
        d = self._fil()
        v1 = {**d, "format": KL.FORMAT_1}
        fel = "; ".join(KL.kontrollera(v1))
        self.assertIn("rutor[0].val ska vara en av", fel)                 # P1 finns inte i v1
        self.assertIn("rutor[0].t_klipp ska vara ett tal ≥ 0", fel)
        self.assertIn("rutor[0].punkter.skaft_mitt saknas i en markerad ruta", fel)
        d["rutor"][0]["punkter"]["klubbhuvud"] = None
        d["rutor"][1]["punkter"]["grepp"] = {"x": 123456.7, "y": 1.0, "kalla": "klick"}
        fel = "; ".join(KL.kontrollera(d))
        self.assertIn("rutor[0].punkter.klubbhuvud saknas i en markerad ruta", fel)
        self.assertIn("rutor[1].punkter.grepp ligger utanför bilden", fel)
        self.assertNotIn("123456", fel)


def _paket_med_klubba(tmp: Path, vy: str = "dtl", trasig: bool = False) -> tuple[Path, list[dict]]:
    """Ett påhittat paket (generera_paket) med telefonens klubba.json för slag s02."""
    fil = GP.paket(tmp, PASS, vy, n=4, seed=3)
    p = P.las(fil)
    s = next(x for x in p.slag if x.id == "s02")
    marks, _ = KL.pahittade_markeringar(json.dumps(P.till_sving(p, s, 1.80)), hoppa=("P8",))
    d = KL.fil_ur(marks, vy, PASS, fil.name, "s02", 1080, 1920)
    with zipfile.ZipFile(fil, "a") as z:
        z.writestr(KL.FIL, "{" if trasig else json.dumps(d))
    return fil, marks


class PaketetOchAnalysen(unittest.TestCase):
    def test_paket_py_laser_markeringarna(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            fil, marks = _paket_med_klubba(Path(tmp))
            p = P.las(fil)
            self.assertIsNone(p.klubba_fel)
            s2 = next(x for x in p.slag if x.id == "s02")
            self.assertEqual([m["position"] for m in s2.klubba_markeringar], [m["position"] for m in marks])
            self.assertTrue(all(not x.klubba_markeringar for x in p.slag if x.id != "s02"))
            self.assertEqual(MK.las_paket(fil)["format"], KL.FORMAT)

    def test_en_trasig_klubba_json_stoppar_inte_paketet(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            fil, _ = _paket_med_klubba(Path(tmp), trasig=True)
            p = P.las(fil)
            self.assertIn("klubba.json", p.klubba_fel)
            a = A.analysera([p], 1.80, [])
            self.assertEqual(a["klubba"]["markerade"], {"dtl": 0, "fo": 0})
            self.assertEqual(list(a["klubba"]["fel"]), ["dtl"])

    def test_analysen_och_historiken_tar_med_klubbmatten(self) -> None:
        for vy in ("dtl", "fo"):
            with tempfile.TemporaryDirectory() as tmp:
                fil, marks = _paket_med_klubba(Path(tmp), vy)
                p = P.las(fil)
                a = A.analysera([p], 1.80, [])
                rad = next(r for r in a["slag"] if r["id"] == "s02")
                self.assertTrue(rad["klubba_markerad"])
                self.assertIn("skaft_vinkel_p1", rad["matt"])
                self.assertIn("skaftplan_p1" if vy == "dtl" else "skaft_lutning_traff", rad["matt"])
                # P2 och P6 är rutorna han valde; P8 hoppades över.
                self.assertEqual(rad["positioner"]["P2"], next(m["t"] for m in marks if m["position"] == "P2"))
                self.assertIn("P6", rad["positioner"])
                self.assertNotIn("P8", rad["positioner"])
                self.assertTrue(all("skaft_vinkel_p1" not in r.get("matt", {}) for r in a["slag"] if r["id"] != "s02"))
                k = a["klubba"]
                self.assertEqual(k["markerade"][vy], 1)
                v1 = next(x for x in k["matt"] if x["matt"] == "skaft_vinkel_p1")
                self.assertEqual((v1["vy"], v1["n"]), (vy, 1))
                self.assertEqual(v1["visat"], round(rad["matt"]["skaft_vinkel_p1"], 1))
                self.assertEqual(A.enhet("skaft_arm_p5"), "°")
                rot = Path(tmp) / "historik"
                H.spara_analys(rot, json.loads(json.dumps(A.ren(a))))
                minne = H.minne(rot)
                self.assertEqual(minne["klubba"]["skaft_vinkel_p1"][0]["n"], 1)


class Samlingen(unittest.TestCase):
    def test_paket_och_pc_markering_till_en_mapp(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            fil, _ = _paket_med_klubba(tmp)
            pc = KL.fil_ur(KL.fixtur_markeringar("dtl")[0], "dtl", PASS, fil.name, "s05", 1080, 2880)
            pc["andrad"] = "2026-11-04T10:00:00+01:00"
            (tmp / f"swinglab-{PASS}-klubba.json").write_text(json.dumps(pc), encoding="utf-8")
            utan = GP.paket(tmp / "utan", "20261104-180000", "fo", n=2)
            ut = tmp / "traning"
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                kod = SK.main([str(fil), str(tmp / f"swinglab-{PASS}-klubba.json"), str(utan), "--ut", str(ut)])
            self.assertEqual(kod, 0, buf.getvalue())
            self.assertIn("utan markeringar", buf.getvalue())
            d = json.loads((ut / f"{PASS}.json").read_text(encoding="utf-8"))
            self.assertEqual(KL.kontrollera(d), [])
            self.assertEqual({r["slag"] for r in d["rutor"]}, {"s02", "s05"})
            index = json.loads((ut / "index.json").read_text(encoding="utf-8"))
            self.assertEqual(index["pass"][0]["markerade"], 9 + 10)
            # Samma källa två gånger ger samma rutor, inte dubbletter.
            with contextlib.redirect_stdout(io.StringIO()):
                SK.main([str(fil), str(fil), "--ut", str(ut)])
            self.assertEqual(len(json.loads((ut / f"{PASS}.json").read_text())["rutor"]), 10)

    def test_vagrar_en_mapp_i_repot(self) -> None:
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            self.assertEqual(SK.main(["x.zip", "--ut", str(Path(KL.__file__).parent / "ut")]), 1)
        self.assertIn("ligger i repot", buf.getvalue())


class SwiftFixturerna(unittest.TestCase):
    def test_fixturerna_ar_pythons(self) -> None:
        """KlubbFixturer.swift är vad klubba.py skriver nu: kör `python3 tools/pc/klubba.py
        --swift` när koden ändras (BESLUT B12)."""
        text = KL.FIXTURFIL.read_text(encoding="utf-8")
        data = json.loads(text.split('#"""\n', 1)[1].rsplit('\n"""#', 1)[0])
        ny = KL.fixturer()
        self.assertEqual(data["fil"], ny["fil"])
        self.assertEqual(data["forslag"], ny["forslag"])
        for a, b in zip(data["fall"], ny["fall"], strict=True):
            self.assertEqual(a["markeringar"], b["markeringar"])
            self.assertEqual(set(a["matt"]), set(b["matt"]))
            for k in a["matt"]:
                self.assertAlmostEqual(a["matt"][k], b["matt"][k], delta=1e-9)
        self.assertIn("fo_vanster", gen.FIXTURSVINGAR)


if __name__ == "__main__":
    unittest.main()
