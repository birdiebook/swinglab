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

    def test_utsnittet_kring_kroppen(self) -> None:
        leder = [[{"x": 500, "y": 400, "c": 0.9}, [520, 1400, 0.9], None, [0, 0, 0.1]]]
        x0, y0, sida = FM.utsnitt(leder, 1080, 1920)
        self.assertEqual(sida, 1920)                  # 2,0 × 1000 px, högst långsidan
        self.assertEqual((x0, y0), (-450, 0))         # utanför i sidled, inom bilden på höjden
        x0, y0, sida = FM.utsnitt(leder, 1080, 1920, skala=0.5)
        self.assertEqual((x0, y0, sida), (260, 650, 500))
        self.assertEqual(FM.utsnitt([[[50, 5, 0.9], [50, 15, 0.9]]], 100, 100, skala=5)[1], 0)
        self.assertEqual(FM.utsnitt(leder, 1080, 1920, skala=1.8)[:2], (-390, 0))

    def test_utsnittet_fylls_med_svart_utanfor(self) -> None:
        b = np.full((4, 6, 3), 9, np.uint8)
        u = FM.skar(b, -2, 1, 5)
        self.assertEqual(u.shape, (5, 5, 3))
        self.assertTrue((u[:3, 2:] == 9).all())
        self.assertEqual(int(u[:, :2].sum()) + int(u[3:].sum()), 0)
        self.assertIsNone(FM.utsnitt([[None, [1, 1, 0.1]]], 100, 100))


if __name__ == "__main__":
    unittest.main()
