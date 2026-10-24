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
        """De påhittade skaften ger sina satta vinklar, också för en vänsterspelare (M1, M46),
        och ett kort skaft bakifrån saknas på sin osäkerhet (M46)."""
        for namn in ("dtl", "dtl_vanster", "fo"):
            marks, sv = KL.fixtur_markeringar(namn)
            m, sd = KL.mat(marks, sv.vy, sv.x_tecken, KL.FIXTUR_BREDD, KL.FIXTUR_HOJD, sv, med_sd=True)
            for p, (vinkel, langd) in KL.SATTA[sv.vy].items():
                k = KL.nyckel("skaft_vinkel", p)
                vantad_sd = math.degrees(math.sqrt(2) * KL.TRYCK_PX / langd)
                if vantad_sd > KL.MAX_SD + 0.1:
                    self.assertNotIn(k, m, f"{namn} {p}: för osäkert")
                    continue
                if vantad_sd < KL.MAX_SD - 0.1:
                    self.assertAlmostEqual(m[k], vinkel, delta=0.15, msg=f"{namn} {p}")
                    self.assertAlmostEqual(sd[k], vantad_sd, delta=0.02, msg=f"{namn} {p}: √2·σ/L")
            if sv.vy == "dtl":
                self.assertAlmostEqual(m["skaftplan_p1"], 60.0, delta=0.1)          # −60° grepp → hosel
                self.assertNotIn("skaft_vinkel_p2", m)                              # 40 px: för osäkert
                self.assertIn("skaft_plan_p6", m, "bara hoslarnas avstånd spärrar (M47)")
            else:
                self.assertAlmostEqual(m["skaft_topp"], 10.0, delta=0.1)            # huvudet över: kort av parallellt
                self.assertAlmostEqual(m["skaft_lutning_traff"], 14.0, delta=0.1)   # greppet mot målet

    def test_tecknen(self) -> None:
        g1 = (500.0, 1000.0)
        h1 = _vid(g1, -60, 400)                                  # adressen: hoseln nere mot bollen
        dtl = lambda *x: KL.mat([_m("P1", g1, h1)] + list(x), "dtl", 1, 1080, 1920)  # noqa: E731
        # P6: hoseln rakt ovanför bollen ligger över (utanför) planlinjen, bakom den under; ett
        # kort skaft vid P6 spelar ingen roll.
        over = dtl(_m("P6", (h1[0] - 20, h1[1] - 290), (h1[0], h1[1] - 300)))["skaft_plan_p6"]
        under = dtl(_m("P6", (300.0, 900.0), (h1[0] - 300, h1[1])))["skaft_plan_p6"]
        self.assertAlmostEqual(over, 30.0, delta=1e-9)
        self.assertLess(under, 0)
        self.assertNotIn("skaft_plan_p6", dtl(_m("P6", (h1[0] + 5, h1[1] - 25), (h1[0], h1[1] - 30))),
                         "hoslarna för nära varandra")
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

    def test_flyktpunkten_ur_riktpinnen(self) -> None:
        """Riktpinnens linje skär bildens vågräta mittlinje där flyktpunkten är (M48); utan
        pinne eller med en nästan vågrät pinne är den bildens mitt, antagen."""
        self.assertEqual(KL.flyktpunkt(None, 1080, 1920), ((540.0, 960.0), True))
        c, antagen = KL.flyktpunkt([(600.0, 1800.0), (580.0, 1400.0)], 1080, 1920)
        self.assertFalse(antagen)
        self.assertAlmostEqual(c[0], 600.0 - 20.0 * 840.0 / 400.0)
        self.assertTrue(KL.flyktpunkt([(100.0, 1000.0), (900.0, 1010.0)], 1080, 1920)[1])
        # Kameran vriden: med pinnen pekar ett parallellt skaft mot flyktpunkten och ger 0.
        g4 = (540.0, 500.0)
        vp = (700.0, 960.0)
        h = (g4[0] + 0.3 * (vp[0] - g4[0]), g4[1] + 0.3 * (vp[1] - g4[1]))
        pinne = [(760.0, 1800.0), (730.0, 1380.0)]                   # genom vp
        m = KL.mat([_m("P4", g4, h)], "dtl", 1, 1080, 1920, pinne=pinne)
        self.assertAlmostEqual(m["skaft_riktning_topp"], 0.0, delta=1e-9)
        self.assertNotAlmostEqual(KL.mat([_m("P4", g4, h)], "dtl", 1, 1080, 1920)["skaft_riktning_topp"], 0.0,
                                  delta=5.0)

    def test_sparren_ar_osakerheten(self) -> None:
        g = (500.0, 900.0)
        m, sd = KL.mat([_m("P7", g, _vid(g, -60, 59)), _m("P1", None, None), _m("P4", g, _vid(g, -60, 62))],
                       "dtl", 1, 1080, 1920, med_sd=True)
        self.assertEqual(set(m), {"skaft_vinkel_p4"})
        self.assertLessEqual(sd["skaft_vinkel_p4"], KL.MAX_SD)
        self.assertAlmostEqual(sd["skaft_vinkel_p4"], math.degrees(math.sqrt(2) * 3 / 62), delta=0.01)

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
        self.assertAlmostEqual(KL.mat([{**p5, "grepp": g, "hosel": vinkel}], "fo", 1, 1080, 1920, sv)["skaft_arm_p5"],
                               90.0, delta=1e-6)
        # I linje: derivatan av acos är oändlig där, så osäkerheten spärrar ett rakt skaft.
        nastan = (g[0] + 300 * ut[0] / n - 60 * ut[1] / n, g[1] + 300 * ut[1] / n + 60 * ut[0] / n)
        self.assertGreater(KL.mat([{**p5, "grepp": g, "hosel": nastan}], "fo", 1, 1080, 1920, sv)["skaft_arm_p5"], 160)
        self.assertNotIn("skaft_arm_p5", KL.mat([{**p5, "grepp": g, "hosel": rak}], "fo", 1, 1080, 1920))

    def test_forslaget_for_p2_p6_p8(self) -> None:
        pos = {"P1": -1.4, "P3": -0.5, "P4": -0.3, "P5": -0.1, "P7": 0.0, "P9": 0.2, "P10": 1.1}
        self.assertAlmostEqual(KL.forslag_tid("P2", pos), -0.95)
        self.assertAlmostEqual(KL.forslag_tid("P2", {**pos, "P3": None}), -0.85)
        self.assertAlmostEqual(KL.forslag_tid("P6", pos), -0.05)
        self.assertAlmostEqual(KL.forslag_tid("P8", {**pos, "P9": None}), 0.55)
        self.assertEqual(KL.forslag_tid("P4", pos), -0.3)
        self.assertIsNone(KL.forslag_tid("P3", {**pos, "P3": None}))

    def test_forslaget_ur_skaftet_framifran(self) -> None:
        """FO: rutan där skaftets vinkel, linjärt i tiden mellan positionerna före och efter, går
        genom vågrätt (M45), åt svingens håll och över ±180°."""
        g = (500.0, 1300.0)
        p1 = _m("P1", g, _vid(g, -95, 285), -1.2)
        p3 = _m("P3", g, _vid(g, 130, 220), -0.5)
        # Baksvingen medurs: −95° → −180° → 130° är 135°, vågrätt bort från målet efter 85°.
        self.assertAlmostEqual(KL.forslag_tid_skaft("P2", [p1, p3], 1.0), -1.2 + 0.7 * 85 / 135, delta=1e-9)
        # Nedsvingen moturs: P5 100° → 180° → P7 −104° (256°), och P7 → 0° → P9 80°.
        p5, p7, p9 = (_m("P5", g, _vid(g, 100, 240), -0.1), _m("P7", g, _vid(g, -104, 290), 0.0),
                      _m("P9", g, _vid(g, 80, 220), 0.3))
        self.assertAlmostEqual(KL.forslag_tid_skaft("P6", [p5, p7], 1.0), -0.1 + 0.1 * 80 / 156, delta=1e-9)
        self.assertAlmostEqual(KL.forslag_tid_skaft("P8", [p7, p9], 1.0), 0.3 * 104 / 184, delta=1e-9)
        # Från baksvingens start när den ligger efter P1 (skaftet står still i adressen), bara för P2.
        self.assertAlmostEqual(KL.forslag_tid_skaft("P2", [p1, p3], 1.0, start=-1.0), -1.0 + 0.5 * 85 / 135,
                               delta=1e-9)
        self.assertAlmostEqual(KL.forslag_tid_skaft("P2", [p1, p3], 1.0, start=-1.5), -1.2 + 0.7 * 85 / 135,
                               delta=1e-9)
        self.assertAlmostEqual(KL.forslag_tid_skaft("P6", [p5, p7], 1.0, start=-1.0), -0.1 + 0.1 * 80 / 156,
                               delta=1e-9)
        self.assertIsNone(KL.forslag_tid_skaft("P2", [p1, p3], 1.0, start=-0.4), "starten efter P3")
        # Fel håll: −95° → −85° i baksvingen och −104° → −110° efter träffen är mer än 270° åt
        # svingens håll, och inget förslag.
        self.assertIsNone(KL.forslag_tid_skaft("P2", [p1, _m("P3", g, _vid(g, -85, 220), -0.5)], 1.0))
        self.assertIsNone(KL.forslag_tid_skaft("P8", [p7, _m("P9", g, _vid(g, -110, 220), 0.3)], 1.0))
        # Speglat (vänsterspelare): samma tid.
        spegel = [{**m, "grepp": (1080 - m["grepp"][0], m["grepp"][1]), "hosel": (1080 - m["hosel"][0], m["hosel"][1])}
                  for m in (p1, p3)]
        self.assertAlmostEqual(KL.forslag_tid_skaft("P2", spegel, -1.0), -1.2 + 0.7 * 85 / 135, delta=1e-9)
        # Inget förslag: en ände saknas eller är hoppad, skaftet når inte vågrätt, tiderna i fel
        # ordning, eller en position som inte är skaftets.
        self.assertIsNone(KL.forslag_tid_skaft("P2", [p1], 1.0))
        self.assertIsNone(KL.forslag_tid_skaft("P2", [p1, {**p3, "grepp": None, "hosel": None}], 1.0))
        self.assertIsNone(KL.forslag_tid_skaft("P2", [p1, _m("P3", g, _vid(g, -150, 220), -0.5)], 1.0))
        self.assertIsNone(KL.forslag_tid_skaft("P2", [p1, {**p3, "t": -1.3}], 1.0))
        self.assertIsNone(KL.forslag_tid_skaft("P4", [p1, p3], 1.0))
        # De påhittade svingarna, också vänsterspelaren: förslaget ligger mellan ändarna (P2 efter
        # baksvingens start).
        for namn in ("fo", "fo_vanster"):
            marks, sv = KL.fixtur_markeringar(namn)
            t = {m["position"]: m["t"] for m in marks}
            start = KL.fixtur_start(namn)
            self.assertTrue(t["P1"] < start < t["P3"], namn)
            for p, (a, b) in (("P2", ("P1", "P3")), ("P6", ("P5", "P7")), ("P8", ("P7", "P9"))):
                f = KL.forslag_tid_skaft(p, marks, sv.x_tecken, start)
                self.assertTrue((start if p == "P2" else t[a]) < f < t[b], f"{namn} {p}")

    def test_telefonens_tryck_ar_samma_pixel(self) -> None:
        """Ett tryck på telefonens yta blir samma pixel som PC:n räknar ur `visad` (M45); vyn
        ingår inte, och fixturerna har också utsnitt som framifrån som SwingLabKit prövar."""
        self.assertEqual(KL.visad_telefonen(None, 1080, 1920), [0, 0, 1080, 1920])
        v = KL.visad_telefonen((0.2, 0.1, 0.5, 0.6), 1080, 1920)
        self.assertEqual(v, [135, 19, 702, 1498])
        self.assertEqual(KL.yta_till_bild(0.0, 1.0, v), (135.0, 19.0 + 1498.0))
        fo = KL.fixturer()["yta"][3]
        self.assertEqual(fo["visad"], [48, 168, 984, 1752])
        self.assertEqual(fo["punkt"], [48 + 0.62 * 984, 168 + 0.18 * 1752])


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
                # Flyktpunkten bara bakifrån (METOD M48); framifrån finns ingen.
                if vy == "dtl":
                    self.assertEqual(rad["klubba_flyktpunkt"], "bildens_mitt")
                else:
                    self.assertNotIn("klubba_flyktpunkt", rad)
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

    def test_ommarkning_ersatter_och_tiden_sorteras_som_tid(self) -> None:
        """Telefonens ommärkning av en position på en annan ruta ersätter den gamla raden, och
        den senast ändrade vinner även när zonerna skiljer (text hade gett fel ordning)."""
        marks, _ = KL.fixtur_markeringar("dtl")
        a = KL.fil_ur(marks[:1], "dtl", PASS, "p.zip", "s01")
        b = KL.fil_ur([{**marks[0], "t": marks[0]["t"] + 0.05}], "dtl", PASS, "p.zip", "s01")
        a["andrad"] = "2026-11-03T21:00:00+01:00"       # 20:00 UTC
        b["andrad"] = "2026-11-03T20:30:00+00:00"       # 20:30 UTC: senare, fast mindre som text
        m = SK.sla_ihop([b, a])[PASS]
        self.assertEqual(len(m["rutor"]), 1)
        self.assertAlmostEqual(m["rutor"][0]["t"], marks[0]["t"] + 0.05)
        self.assertEqual(m["andrad"], b["andrad"])

    def test_markera_klubba_tal_null_forskjutning(self) -> None:
        r = {"id": "a", "fil": "f", "t": 0.1, "t_klipp": None, "forskjutning_ms": None}
        self.assertTrue(MK._samma(r, dict(r)))
        self.assertFalse(MK._samma(r, {**r, "forskjutning_ms": 0.0}), "null är inte 0")

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
        self.assertEqual(data["yta"], ny["yta"])
        self.assertEqual(data["forslag_skaft"], ny["forslag_skaft"])
        self.assertEqual(KL.YTAFIL.read_text(encoding="utf-8"), KL.swift_yta())
        for a, b in zip(data["fall"], ny["fall"], strict=True):
            self.assertEqual(a["markeringar"], b["markeringar"])
            self.assertEqual(set(a["matt"]), set(b["matt"]))
            for k in a["matt"]:
                self.assertAlmostEqual(a["matt"][k], b["matt"][k], delta=1e-9)
                self.assertAlmostEqual(a["sd"][k], b["sd"][k], delta=1e-9)
        self.assertIn("fo_vanster", gen.FIXTURSVINGAR)


if __name__ == "__main__":
    unittest.main()
