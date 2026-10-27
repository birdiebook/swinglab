"""S7-1: förmärkarens delning per scen, klasserna och kontaktarkets tider (METOD MF7)."""
from __future__ import annotations

import json
import math
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from pc import formarkare as FM  # noqa: E402
from pc.session import REPO  # noqa: E402


def _bild(fro: int, brus: float = 0.0, n: int = 64) -> np.ndarray:
    """En påhittad scen: slumpade block, plus brus som i grannrutor ur samma video."""
    r = np.random.default_rng(fro)
    b = np.kron(r.uniform(0, 255, (8, 8)), np.ones((n // 8, n // 8)))
    return b + np.random.default_rng(fro + 1000).normal(0, brus, b.shape)


class Miniatyr(unittest.TestCase):
    def test_langd_ett_och_medel_noll(self) -> None:
        v = FM.miniatyr(_bild(1))
        self.assertEqual(v.shape, (FM.MINIATYR ** 2,))
        self.assertAlmostEqual(float(np.linalg.norm(v)), 1.0)
        self.assertAlmostEqual(float(v.mean()), 0.0)

    def test_jamn_bild_ger_nollvektorn(self) -> None:
        self.assertEqual(float(np.abs(FM.miniatyr(np.full((32, 32), 7.0))).sum()), 0.0)

    def test_for_liten_bild(self) -> None:
        with self.assertRaises(FM.FormFel):
            FM.miniatyr(np.zeros((8, 8)))


class Scener(unittest.TestCase):
    def test_grannrutor_blir_en_scen_och_andra_scener_skiljs(self) -> None:
        bilder = [_bild(1, 2.0), _bild(2, 2.0), _bild(1, 3.0), _bild(3), _bild(2, 1.0)]
        s = FM.scener(np.stack([FM.miniatyr(b) for b in bilder]))
        self.assertEqual(s.tolist(), [0, 1, 0, 3, 1])

    def test_sambanden_ar_transitiva(self) -> None:
        # a ~ b och b ~ c men inte a ~ c: alla tre i samma scen.
        a = np.zeros(4); a[0] = 1
        c = np.zeros(4); c[1] = 1
        b = (a + c) / np.linalg.norm(a + c)
        s = FM.scener(np.stack([a, b, c]), grans=0.7)
        self.assertEqual(s.tolist(), [0, 0, 0])

    def test_bitarna_ger_samma_svar(self) -> None:
        v = np.stack([FM.miniatyr(_bild(i % 7, 1.0 + i)) for i in range(30)])
        self.assertEqual(FM.scener(v, bit=4).tolist(), FM.scener(v).tolist())


class Dela(unittest.TestCase):
    def test_en_scen_hamnar_i_en_del_och_provet_haller_taket(self) -> None:
        namn = [f"b{i:03d}" for i in range(200)]
        scen = np.array([i // 5 for i in range(200)])        # 40 scener om 5 bilder
        d = FM.dela(namn, scen)
        for s in set(scen.tolist()):
            self.assertEqual(len({d[i] for i in range(200) if scen[i] == s}), 1)
        self.assertEqual(d.count("test"), 20)
        self.assertEqual(d.count("valid"), 20)
        self.assertEqual(d.count("train"), 160)

    def test_samma_kalla_delas_likadant(self) -> None:
        namn = [f"x{i}" for i in range(50)]
        scen = np.array([i // 2 for i in range(50)])
        self.assertEqual(FM.dela(namn, scen), FM.dela(list(namn), scen.copy()))

    def test_for_stor_scen_gar_till_traningen(self) -> None:
        namn = [f"y{i}" for i in range(100)]
        scen = np.zeros(100, int)
        self.assertEqual(set(FM.dela(namn, scen)), {"train"})


class Coco(unittest.TestCase):
    def test_klasserna_och_negativa_bilder(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp) / "train"
            d.mkdir()
            (d / "_annotations.coco.json").write_text(json.dumps({
                "categories": [{"id": 0, "name": "golf"}, {"id": 1, "name": "club"},
                               {"id": 2, "name": "club_head"}, {"id": 3, "name": "golfball"},
                               {"id": 4, "name": "3"}],
                "images": [{"id": 0, "file_name": "a.jpg", "width": 640, "height": 640},
                           {"id": 1, "file_name": "b.jpg", "width": 640, "height": 640}],
                "annotations": [{"image_id": 0, "category_id": 1, "bbox": [1, 2, 3, 4]},
                                {"image_id": 0, "category_id": 2, "bbox": [5, 6, 7, 8]},
                                {"image_id": 1, "category_id": 3, "bbox": [0, 0, 1, 1]},
                                {"image_id": 1, "category_id": 4, "bbox": [0, 0, 1, 1]}]}))
            b = FM.las_coco(Path(tmp))
        self.assertEqual([r["klass"] for r in b[0]["rutor"]], ["klubba", "klubbhuvud"])
        self.assertEqual(b[1]["rutor"], [])           # bollen och händerna tas bort, bilden står kvar
        for x in b:
            x["ut_namn"] = x["namn"]
        c = FM.coco(b)
        self.assertEqual([k["name"] for k in c["categories"]], ["klubba-delar", "klubba", "klubbhuvud"])
        self.assertEqual([a["category_id"] for a in c["annotations"]], [1, 2])

    def test_handerna_bara_nar_de_valjs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp) / "train"
            d.mkdir()
            (d / "_annotations.coco.json").write_text(json.dumps({
                "categories": [{"id": 0, "name": "golf"}, {"id": 1, "name": "0"}, {"id": 2, "name": "3"}],
                "images": [{"id": 0, "file_name": "a.jpg", "width": 640, "height": 640}],
                "annotations": [{"image_id": 0, "category_id": 1, "bbox": [1, 2, 3, 4]},
                                {"image_id": 0, "category_id": 2, "bbox": [5, 6, 7, 8]}]}))
            self.assertEqual([r["klass"] for r in FM.las_coco(Path(tmp))[0]["rutor"]], ["klubba"])
            b = FM.las_coco(Path(tmp), FM.ALLA_KLASSER)
        self.assertEqual([r["klass"] for r in b[0]["rutor"]], ["klubba", "hander"])
        b[0]["ut_namn"] = "a.jpg"
        c = FM.coco(b, FM.ALLA_KLASSER)
        self.assertEqual([k["name"] for k in c["categories"]][1:], ["klubba", "klubbhuvud", "hander"])
        self.assertEqual([a["category_id"] for a in c["annotations"]], [1, 3])

    def test_storleken_ur_viktmappen(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            v = Path(tmp) / "best.pth"
            self.assertEqual(FM.storlek(v), "nano")              # de första vikterna har ingen modell.json
            (Path(tmp) / "modell.json").write_text(json.dumps({"storlek": "small"}))
            self.assertEqual(FM.storlek(v), "small")

    def test_tom_mapp(self) -> None:
        with tempfile.TemporaryDirectory() as tmp, self.assertRaises(FM.FormFel):
            FM.las_coco(Path(tmp))


class Dataregeln(unittest.TestCase):
    def test_repot_och_mnt_nekas(self) -> None:
        for p in (REPO / "tools", REPO / "x" / "vikter", Path("/mnt/c/swinglab")):
            with self.assertRaises(FM.FormFel):
                FM.utanfor_repot(p)

    def test_hemmappen_gar(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(FM.utanfor_repot(Path(tmp)), Path(tmp).resolve())


class Kontaktarket(unittest.TestCase):
    def test_tiderna_i_ordning_fran_adress_till_finish(self) -> None:
        t = FM.tider_ark({"start": -1.0, "topp": -0.25, "traff": 0.0})
        self.assertEqual([n for n, _ in t][0], "adress")
        self.assertEqual([n for n, _ in t][-1], "finish")
        v = [x for _, x in t]
        self.assertEqual(v, sorted(v))
        self.assertAlmostEqual(dict(t)["nedsving 1/2"], -0.125)
        self.assertAlmostEqual(dict(t)["efter"], 0.15)

    def test_kroppen_over_svingens_rutor(self) -> None:
        rutor = [[{"x": 500, "y": 400, "c": 0.9}, None, [0, 0, 0.1]], [[520, 1400, 0.9]]]
        self.assertEqual(FM.kroppen(rutor), (1000.0, 510.0, 900.0))     # för få leder per ruta
        self.assertIsNone(FM.kroppen([[None, [1, 1, 0.1]]]))
        # Rutans egen höjd i median: armarna uppe i en ruta gör inte kroppen större.
        sta = [[x, y, 0.9] for x, y in ((0, 0), (0, 100), (0, 200), (0, 300), (0, 400), (0, 1000))]
        upp = [[x, y, 0.9] for x, y in ((0, -500), (0, 100), (0, 200), (0, 300), (0, 400), (0, 1000))]
        self.assertEqual(FM.kroppen([sta, sta, upp])[0], 1000.0)

    def test_utsnittet_kring_handerna_annars_kroppen(self) -> None:
        leder = [None] * 13
        leder[5], leder[6] = [400, 1000, 0.9], {"x": 440, "y": 1020, "c": 0.8}
        kropp = (1000.0, 510.0, 900.0)
        self.assertEqual(FM.utsnitt(leder, kropp, 1080, 1920), (-480, 110, 1800))   # 1,8 × 1000 kring händerna
        leder[6] = [440, 1020, 0.1]                                                  # greppregeln: den som syns
        self.assertEqual(FM.utsnitt(leder, kropp, 1080, 1920)[:2], (-500, 100))
        self.assertEqual(FM.utsnitt([None] * 13, kropp, 1080, 1920), (-450, -60, 1920))  # kroppen, högst långsidan

    def test_utsnittet_fylls_med_svart_utanfor(self) -> None:
        b = np.full((4, 6, 3), 9, np.uint8)
        u = FM.skar(b, -2, 1, 5)
        self.assertEqual(u.shape, (5, 5, 3))
        self.assertTrue((u[:3, 2:] == 9).all())
        self.assertEqual(int(u[:, :2].sum()) + int(u[3:].sum()), 0)


class OverTiden(unittest.TestCase):
    """Grannarna i tiden lyfter en osäker punkt på linjen och stryker en som hoppar (METOD MF7)."""

    @staticmethod
    def _p(x, y, k):
        return {"x": float(x), "y": float(y), "konfidens": k}

    def test_osaker_pa_linjen_lyfts_till_den_svagare_grannen(self) -> None:
        p = [self._p(0, 0, 0.8), self._p(10, 0, 0.3), self._p(20, 1, 0.1), self._p(30, 0, 0.6)]
        ut, n = FM.over_tiden(p, 100.0, grans=0.5)
        self.assertEqual([None if q is None else q["konfidens"] for q in ut], [0.8, 0.6, None, 0.6])
        self.assertEqual(n, {"lyfta": 1, "strukna": 0})        # 0,1 är under GRANNAR_MIN

    def test_en_som_hoppar_stryks_aven_om_den_ar_saker(self) -> None:
        p = [self._p(0, 0, 0.8), self._p(10, 40, 0.9), self._p(20, 0, 0.7)]
        ut, n = FM.over_tiden(p, 100.0)
        self.assertIsNone(ut[1])
        self.assertEqual(n["strukna"], 1)

    def test_utan_granne_at_bada_hall_galler_modellens_egen(self) -> None:
        p = [self._p(0, 0, 0.4), self._p(10, 0, 0.7), None, None, None, None, self._p(60, 0, 0.45)]
        ut, n = FM.over_tiden(p, 100.0, grans=0.5)
        self.assertEqual([q is not None for q in ut], [False, True, False, False, False, False, False])
        self.assertEqual(n, {"lyfta": 0, "strukna": 0})

    def test_toleransen_vaxer_med_grannarnas_avstand(self) -> None:
        # Grannarna 200 px isär: 0,02 × 100 + 0,25 × 200 = 52 px från linjen godtas.
        p = [self._p(0, 0, 0.9), self._p(100, 50, 0.3), self._p(200, 0, 0.9)]
        self.assertIsNotNone(FM.over_tiden(p, 100.0)[0][1])
        p[1] = self._p(100, 55, 0.3)
        self.assertIsNone(FM.over_tiden(p, 100.0)[0][1])


class MotMarkeringen(unittest.TestCase):
    """Modellens huvud mot Johannes hosel (METOD MF7)."""

    def test_traff_inom_vidgad_ruta_och_avstand_i_skaftets_langd(self) -> None:
        pk = {"grepp": {"x": 100.0, "y": 0.0}, "klubbhuvud": {"x": 100.0, "y": 300.0}}
        huvud = {"x": 110.0, "y": 300.0, "konfidens": 0.4, "box": [104.0, 290.0, 20.0, 20.0]}
        b = FM.bedom(huvud, pk)
        self.assertTrue(b["traff"])                       # 4 px utanför, marginalen är 10
        self.assertAlmostEqual(b["avstand"], 10 / 300)
        huvud["box"] = [115.0, 290.0, 20.0, 20.0]
        self.assertFalse(FM.bedom(huvud, pk)["traff"])   # 15 px utanför
        self.assertEqual(FM.bedom(None, pk), {"konfidens": 0.0, "traff": False, "avstand": None})

    def test_greppet_ur_handerna_och_skaftets_vinkel(self) -> None:
        rad = [{"klass": "hander", "konfidens": 0.3, "bbox": [0, 0, 10, 10]},
               {"klass": "hander", "konfidens": 0.8, "bbox": [90, -10, 20, 20]},
               {"klass": "klubbhuvud", "konfidens": 0.9, "bbox": [0, 0, 5, 5]}]
        g = FM.grepp_punkt(rad, 0, 0, 1, 1)
        self.assertEqual((g["x"], g["y"], g["konfidens"]), (100.0, 0.0, 0.8))
        self.assertIsNone(FM.grepp_punkt([{"klass": "klubba", "konfidens": 0.9, "bbox": [0, 0, 1, 1]}], 0, 0, 1, 1))
        pk = {"grepp": {"x": 100.0, "y": 0.0}, "klubbhuvud": {"x": 100.0, "y": 300.0}}
        huvud = {"x": 100.0 + 300 * math.tan(math.radians(2)), "y": 300.0, "konfidens": 0.6, "box": [95, 295, 20, 10]}
        b = FM.bedom(huvud, pk, {"x": 100.0, "y": 15.0, "konfidens": 0.8})
        self.assertAlmostEqual(b["grepp_fel"], 0.05)
        self.assertAlmostEqual(b["vinkel"], math.degrees(math.atan2(300 * math.tan(math.radians(2)), 285)), places=6)
        self.assertNotIn("vinkel", FM.bedom(None, pk, {"x": 100.0, "y": 15.0, "konfidens": 0.8}))
        self.assertIsNone(FM.bedom(huvud, {"grepp": pk["grepp"], "klubbhuvud": None}))
        self.assertIsNone(FM.bedom(huvud, {"grepp": pk["grepp"], "klubbhuvud": {"syns_inte": True}}))

    def test_klasserna_och_avstandet_bland_traffarna(self) -> None:
        rader = [{"konfidens": 0.6, "traff": True, "avstand": 0.02}, {"konfidens": 0.35, "traff": True, "avstand": 0.04},
                 {"konfidens": 0.35, "traff": False, "avstand": 0.5}, {"konfidens": 0.0, "traff": False, "avstand": None}]
        s = FM.sammanfatta(rader)
        self.assertEqual(s["klasser"], {"≥0.5": {"rutor": 1, "traff": 1}, "0.3–0.5": {"rutor": 2, "traff": 1},
                                        "<0.1": {"rutor": 1, "traff": 0}})
        self.assertEqual(s["avstand_median"], 0.03)


class MattenUtanTryck(unittest.TestCase):
    """Positionerna ur kroppen och skaftet (METOD M45, MF7)."""

    @staticmethod
    def _sving_fo():
        # Framifrån, en högerspelare i speglad bild (x_tecken 1): skaftet vrider sig moturs i
        # nedsvingen från 135° (P5) till 260° (P7) och går genom vågrätt (180°) vid t = 0,036.
        serie = []
        for k in range(10):
            t = round(k / 100, 2)
            v = math.radians(135 + 125 * k / 9)
            g = (500.0, 800.0)
            serie.append({"t": t, "g": g, "h": (g[0] + 300 * math.cos(v), g[1] - 300 * math.sin(v)),
                          "kg": 0.9, "kh": 0.8})
        return serie

    def test_p6_framifran_dar_skaftet_gar_genom_vagratt(self) -> None:
        a = FM.auto_positioner(self._sving_fo(), {"P5": 0.0, "P7": 0.09}, "fo", 1.0)
        self.assertEqual(a["P6"]["t"], 0.03)          # vågrätt vid 0,0324: rutan närmast
        self.assertEqual(a["P6"]["kalla"], "skaftet")
        self.assertEqual((a["P5"]["kalla"], a["P7"]["t"]), ("kroppen", 0.09))

    def test_p6_bakifran_dar_skaftet_ar_kortast(self) -> None:
        langd = [300, 280, 200, 120, 60, 70, 140, 250, 300]
        serie = [{"t": k / 100, "g": (500.0, 800.0), "h": (500.0, 800.0 + L), "kg": 0.9, "kh": 0.9}
                 for k, L in enumerate(langd)]
        serie[6]["h"] = (500.0, 801.0)                 # en ensam för kort ruta jämnas bort
        a = FM.auto_positioner(serie, {"P5": 0.0, "P7": 0.08}, "dtl", 1.0)
        self.assertEqual(a["P6"]["t"], 0.04)

    def test_p1_saknas_nar_skaftet_inte_pekar_nedat(self) -> None:
        serie = [{"t": 0.0, "g": (500.0, 800.0), "h": (520.0, 1200.0), "kg": 0.9, "kh": 0.9},
                 {"t": 0.5, "g": (500.0, 800.0), "h": (900.0, 830.0), "kg": 0.9, "kh": 0.9}]
        self.assertIn("P1", FM.auto_positioner(serie, {"P1": 0.0}, "fo", 1.0))
        self.assertNotIn("P1", FM.auto_positioner(serie, {"P1": 0.5}, "fo", 1.0))   # skaftet åt sidan

    def test_position_utan_ruta_saknas(self) -> None:
        a = FM.auto_positioner(self._sving_fo()[:3], {"P1": 0.5, "P5": 0.0, "P7": 0.09}, "fo", 1.0)
        self.assertNotIn("P1", a)                      # ingen ruta inom 10 ms
        self.assertNotIn("P6", a)                      # skaftet passerar inte vågrätt i de rutor som finns

    def test_serien_bara_med_bade_grepp_och_huvud(self) -> None:
        rutor = [{"t": k / 240, "x0": 0, "y0": 0, "skala": 1.0, "kropp_hojd": 1000.0,
                  "rad": [{"klass": "hander", "konfidens": 0.8, "bbox": [90, 90, 20, 20]}]
                  + ([{"klass": "klubbhuvud", "konfidens": 0.7, "bbox": [95, 395, 10, 10]}] if k != 2 else [])}
                 for k in range(5)]
        s = FM.skaft_serie(rutor, 1080, 1920)
        self.assertEqual([round(q["t"] * 240) for q in s], [0, 1, 3, 4])
        self.assertEqual((s[0]["g"], s[0]["h"]), ((100.0, 100.0), (100.0, 400.0)))


class Forslagsfilen(unittest.TestCase):
    """S7d:s format (METOD MF8, BESLUT B93): huvudets mitt, aldrig hoseln eller greppet."""

    def test_huvudets_mitt_flyttad_och_skalad_till_ledernas_px(self) -> None:
        rad = [{"klass": "klubba", "konfidens": 0.9, "bbox": [0, 0, 50, 200]},
               {"klass": "klubbhuvud", "konfidens": 0.6, "bbox": [10, 20, 10, 10]},
               {"klass": "klubbhuvud", "konfidens": 0.8, "bbox": [40, 60, 20, 10]}]
        q = FM.huvud_punkt(rad, 100, 200, 0.5, 0.5, 1080, 1920)
        # Den säkraste rutan: (140, 260)–(160, 270) i klippet, halverat till ledernas px.
        self.assertEqual(q, {"x": 75.0, "y": 132.5, "konfidens": 0.8, "box": [70.0, 130.0, 10.0, 5.0]})

    def test_under_grans_och_bara_klubba_ger_ingen_punkt(self) -> None:
        from pc.klubba_forslag import VISA_KONFIDENS
        self.assertIsNone(FM.huvud_punkt([{"klass": "klubbhuvud", "konfidens": VISA_KONFIDENS - 0.01,
                                           "bbox": [0, 0, 5, 5]}], 0, 0, 1, 1, 100, 100))
        self.assertIsNone(FM.huvud_punkt([{"klass": "klubba", "konfidens": 0.99, "bbox": [0, 0, 5, 5]}],
                                         0, 0, 1, 1, 100, 100))

    def test_mitten_utanfor_bilden_ger_ingen_punkt_och_boxen_beskars(self) -> None:
        rad = [{"klass": "klubbhuvud", "konfidens": 0.9, "bbox": [0, 0, 10, 10]}]
        self.assertIsNone(FM.huvud_punkt(rad, -20, 0, 1, 1, 100, 100))
        q = FM.huvud_punkt(rad, -4, 95, 1, 1, 100, 100)
        self.assertEqual((q["x"], q["y"]), (1.0, 100.0))
        self.assertEqual(q["box"], [0.0, 95.0, 6.0, 5.0])

    def test_filen_ar_giltig_med_bara_huvud(self) -> None:
        from pc import klubba_forslag as KF
        d = KF.ny("20261024-142435", "fo", "rfdetr-nano-klubba", "alla-2026-10-25",
                  [{"namn": "golf-49wbh", "licens": "CC BY 4.0"}], 1080, 1920)
        q = FM.huvud_punkt([{"klass": "klubbhuvud", "konfidens": 0.7, "bbox": [500, 900, 40, 30]}],
                           0, 0, 1, 1, 1080, 1920)
        KF.lagg_till(d, "s06", -0.25, {"huvud": q}, ruta=400, t_klipp=2.2)
        self.assertEqual(KF.kontrollera(d), [])
        self.assertEqual(set(KF.visade(d["slag"][0]["rutor"][0])), {"huvud"})

    def test_modellens_data_ur_traningsmappen(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            mapp, vikter = Path(tmp) / "trana", Path(tmp) / "vikter-alla"
            mapp.mkdir()
            vikter.mkdir()
            (mapp / "delning.json").write_text(json.dumps({"kallor": {"golf-49wbh": {}, "golf-club-tracking": {}}}))
            (vikter / "training_config.json").write_text(json.dumps({"train_config": {"dataset_dir": str(mapp)}}))
            (vikter / "best.pth").write_bytes(b"x")
            version, data = FM.modell_info(vikter / "best.pth")
            self.assertTrue(version.startswith("alla-"))
            self.assertEqual([(x["namn"], x["licens"]) for x in data],
                             [("golf-49wbh", "CC BY 4.0"), ("golf-club-tracking", "CC BY 4.0")])
            (mapp / "delning.json").write_text(json.dumps({"kallor": {"okant": {}}}))
            with self.assertRaises(FM.FormFel):
                FM.modell_info(vikter / "best.pth")


if __name__ == "__main__":
    unittest.main()
