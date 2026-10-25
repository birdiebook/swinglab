"""S7-1: förmärkarens delning per scen, klasserna och kontaktarkets tider (METOD MF7)."""
from __future__ import annotations

import json
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
        self.assertEqual(FM.kroppen(rutor), (1000.0, 510.0, 900.0))
        self.assertIsNone(FM.kroppen([[None, [1, 1, 0.1]]]))

    def test_utsnittet_kring_handerna_annars_kroppen(self) -> None:
        leder = [None] * 13
        leder[5], leder[6] = [400, 1000, 0.9], {"x": 440, "y": 1020, "c": 0.8}
        kropp = (1000.0, 510.0, 900.0)
        self.assertEqual(FM.utsnitt(leder, kropp, 1080, 1920), (-330, 260, 1500))   # 1,5 × 1000 kring händerna
        leder[6] = [440, 1020, 0.1]                                                  # greppregeln: den som syns
        self.assertEqual(FM.utsnitt(leder, kropp, 1080, 1920)[:2], (-350, 250))
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
        ut, n = FM.over_tiden(p, 100.0)
        self.assertEqual([None if q is None else q["konfidens"] for q in ut], [0.8, 0.6, None, 0.6])
        self.assertEqual(n, {"lyfta": 1, "strukna": 0})        # 0,1 är under GRANNAR_MIN

    def test_en_som_hoppar_stryks_aven_om_den_ar_saker(self) -> None:
        p = [self._p(0, 0, 0.8), self._p(10, 40, 0.9), self._p(20, 0, 0.7)]
        ut, n = FM.over_tiden(p, 100.0)
        self.assertIsNone(ut[1])
        self.assertEqual(n["strukna"], 1)

    def test_utan_granne_at_bada_hall_galler_modellens_egen(self) -> None:
        p = [self._p(0, 0, 0.4), self._p(10, 0, 0.7), None, None, None, None, self._p(60, 0, 0.45)]
        ut, n = FM.over_tiden(p, 100.0)
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
        self.assertIsNone(FM.bedom(huvud, {"grepp": pk["grepp"], "klubbhuvud": None}))

    def test_klasserna_och_avstandet_bland_traffarna(self) -> None:
        rader = [{"konfidens": 0.6, "traff": True, "avstand": 0.02}, {"konfidens": 0.35, "traff": True, "avstand": 0.04},
                 {"konfidens": 0.35, "traff": False, "avstand": 0.5}, {"konfidens": 0.0, "traff": False, "avstand": None}]
        s = FM.sammanfatta(rader)
        self.assertEqual(s["klasser"], {"≥0.5": {"rutor": 1, "traff": 1}, "0.3–0.5": {"rutor": 2, "traff": 1},
                                        "<0.1": {"rutor": 1, "traff": 0}})
        self.assertEqual(s["avstand_median"], 0.03)


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
        self.assertIsNone(FM.huvud_punkt([{"klass": "klubbhuvud", "konfidens": 0.49, "bbox": [0, 0, 5, 5]}],
                                         0, 0, 1, 1, 100, 100))
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
        d = KF.ny("20261024-142435", "fo", FM.MODELL_NAMN, "alla-2026-10-25",
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
