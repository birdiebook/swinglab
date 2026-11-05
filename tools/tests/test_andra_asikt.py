"""Andra åsikten (METOD MF9) utan PyTorch: en påhittad modell läser rutans nummer ur bilden
och ger Visions leder för just den rutan (sanningen ur de påhittade paketen) med en känd
förskjutning och känt brus. Klippets tider är förskjutna mot Visions som i S3."""
from __future__ import annotations

import io
import contextlib
import json
import tempfile
import unittest
from pathlib import Path

import numpy as np

import _hjalp  # noqa: F401
from pc import andra_asikt as AA
from pc import rensa as RE
from pc.format import (ANTAL_LEDER, ARMBAGE_B, AXEL_B, AXEL_F, HANDLED_B, HANDLED_F, HOFT_B, HOFT_F, KNA_F,
                       LEDER, LEDER_FIL, NASA)
from test_s3_facit import FPS, OFF, Rutor, las_kod, paketen

HANDLED_V = LEDER_FIL.index("handled_v")


class PahittadVitPose:
    """Läser rutans nummer ur hela bilden, tar Visions leder för rutan (filens ordning), lägger
    på `fast` (filens led → (dx, dy) i ledernas px) och vitt brus `sd`, och svarar COCO:s 17
    punkter i klippets px. Sparar personrutorna den fick."""

    namn = "pahittad"

    def __init__(self, sanning: dict, fast: dict | None = None, sd: float = 0.0, seed: int = 1):
        self.sanning, self.fast, self.sd = sanning, fast or {}, sd
        self.rng = np.random.default_rng(seed)
        self.rutor: list[tuple] = []
        self.slag = None

    def kor(self, bilder, rutor):
        ut = []
        for bild, ruta in zip(bilder, rutor):
            self.rutor.append(ruta)
            facit, klick = self.sanning[self.slag]
            sk = bild.shape[1] / 1080.0
            n = las_kod(bild, 0.0, 0.0, sk)
            nycklar = np.array(sorted(facit))
            t_v = n / FPS + OFF - klick
            k = int(np.argmin(np.abs(nycklar - t_v)))
            L = facit[float(nycklar[k])].copy() if abs(nycklar[k] - t_v) < 2e-4 else np.full((13, 3), np.nan)
            for j, (dx, dy) in self.fast.items():
                L[j, :2] += (dx, dy)
            if self.sd:
                L[:, :2] += self.rng.normal(0.0, self.sd, (13, 2))
            P17 = np.zeros((17, 3))
            for j, c in enumerate(AA.COCO_INDEX):
                P17[c] = (L[j, 0] * sk, L[j, 1] * sk, 0.9) if np.isfinite(L[j, 0]) else (0.0, 0.0, 0.0)
            ut.append(P17)
        return ut


class SlagRutor(Rutor):
    """Rutor som berättar för modellen vilket slag som körs."""

    def __init__(self, modell):
        self.modell = modell

    def rutor(self, paket_fil, paket, slag):
        self.modell.slag = (paket.fil, slag.id)
        yield from super().rutor(paket_fil, paket, slag)


class Delarna(unittest.TestCase):
    def test_personrutan_tacker_lederna_med_marginal(self) -> None:
        L = np.full((13, 3), np.nan)
        L[:8, :2] = [[500, 300], [450, 400], [550, 400], [430, 550], [570, 550], [420, 700], [580, 700], [470, 800]]
        x, y, b, h = AA.personruta(L, 1080, 1920)
        self.assertLess(x, 420)
        self.assertGreater(x + b, 580)
        self.assertLess(y, 300 - AA.RUTA_HUVUD * 500)          # huvudet ovanför näsan får plats
        self.assertGreater(y + h, 800)

    def test_personrutan_inom_bilden_och_for_fa_leder(self) -> None:
        L = np.full((13, 3), np.nan)
        L[:6, :2] = [[5, 5], [10, 20], [30, 20], [10, 60], [30, 60], [20, 90]]
        x, y, b, h = AA.personruta(L, 100, 100)
        self.assertGreaterEqual(x, 0.0)
        self.assertGreaterEqual(y, 0.0)
        self.assertLessEqual(x + b, 100.0)
        L[5] = np.nan
        self.assertIsNone(AA.personruta(L, 100, 100))

    def test_coco_till_filens_leder(self) -> None:
        P17 = np.zeros((17, 3))
        P17[:, 0] = np.arange(17) * 10.0
        P17[:, 1] = 5.0
        P17[:, 2] = 0.9
        P17[9, 2] = 0.1                                          # vänster handled under konfidensen
        L = AA.till_leder(P17, 0.5)
        self.assertEqual(len(L), 13)
        self.assertEqual(L[1][0], 100.0)                        # vänster axel = COCO 5, ÷ 0,5
        self.assertEqual(L[12][0], 320.0)                       # höger fotled = COCO 16
        self.assertIsNone(L[HANDLED_V])

    def test_rycket_ser_bruset_men_inte_rorelsen(self) -> None:
        t = np.arange(240) / FPS
        jamn = np.column_stack([400 + 300 * np.sin(2 * np.pi * t), 600 - 200 * t])
        brus = jamn + np.random.default_rng(2).normal(0.0, 3.0, jamn.shape)
        r_jamn = AA.ryck(t, jamn, 100.0)
        r_brus = AA.ryck(t, brus, 100.0)
        self.assertLess(np.nanmedian(r_jamn), 0.005)
        self.assertGreater(np.nanmedian(r_brus), 20 * np.nanmedian(r_jamn))
        # Vitt brus σ ger andra differensen ≈ σ·√6 per axel; medianen av längden ligger nära.
        self.assertAlmostEqual(np.nanmedian(r_brus) * 100.0, 3.0 * np.sqrt(6) * 1.18, delta=2.5)

    def test_rycket_hoppar_over_luckor_och_saknade(self) -> None:
        t = np.r_[np.arange(10), np.arange(20, 30)] / FPS
        X = np.column_stack([t * 100, t * 0])
        X[15] = np.nan
        r = AA.ryck(t, X, 50.0)
        self.assertTrue(np.isnan(r[[0, 9, 10, 14, 15, 16, 19]]).all())
        self.assertEqual(int(np.isfinite(r).sum()), 8 + 3 + 2)

    def test_jamforelsen_per_led_och_fas(self) -> None:
        rng = np.random.default_rng(3)
        t = -1.5 + (np.arange(600) + 0.5) / FPS
        V = np.full((len(t), 13, 3), np.nan)
        bas = np.array([[0, -170], [-20, -140], [20, -140], [-25, -110], [25, -110], [-25, -80], [25, -80],
                        [-15, -80], [15, -80], [-15, -40], [15, -40], [-15, 0], [15, 0]], float) * 4 + [500, 900]
        V[..., :2] = bas + rng.normal(0.0, 0.5, (len(t), 13, 2))
        V[..., 2] = 0.9
        M = V.copy()
        bal = RE.bal_px(V[..., :2])
        M[:, HOFT_F, 0] += 0.1 * bal                             # en fast skillnad på 0,1 bål
        M[t > 0, KNA_F, 1] += 0.3 * bal                          # grov bara efter träffen
        faser = {"start": -1.0, "topp": -0.3, "traff": 0.0}
        j = AA.jamfor_slag(t, V, M, faser)
        self.assertAlmostEqual(j["bal_px"], bal)
        res = AA.sammanstall([("fo", j)])
        rad = lambda f, led: next(r for r in res["leder"] if r["fas"] == f and r["led"] == LEDER[led])  # noqa: E731
        self.assertAlmostEqual(rad("alla", HOFT_F)["median"], 0.1, delta=0.002)
        self.assertEqual(rad("alla", NASA)["median"], 0.0)
        self.assertEqual(rad("nedsving", KNA_F)["grova"], 0.0)
        self.assertEqual(rad("efter_traff", KNA_F)["grova"], 1.0)
        self.assertEqual({r["fas"] for r in res["leder"]}, set(AA.FASER))
        ryck = [r for r in res["ryck"] if r["fas"] == "alla"]
        self.assertEqual({r["led"] for r in ryck}, {LEDER[k] for k in AA.RYCK_LEDER})
        self.assertTrue(all(r["kvot"] == 1.0 for r in ryck))   # samma punkter: samma ryck
        self.assertEqual(res["rensning"]["fo"]["vision"]["spikar"], {})

    def test_rensningen_raknas_for_bada(self) -> None:
        t = np.arange(0, 1.0, 1 / FPS)
        V = np.full((len(t), 13, 3), 0.9)
        V[..., :2] = np.array([[500, 300], [450, 400], [550, 400], [430, 550], [570, 550], [420, 700], [580, 700],
                               [470, 800], [530, 800], [470, 1000], [530, 1000], [470, 1200], [530, 1200]], float)
        M = V.copy()
        M[100, HANDLED_B, :2] += (0.0, -300.0)                   # en spik i ViTPose
        res = AA.sammanstall([("dtl", AA.jamfor_slag(t, V, M, None))])
        self.assertEqual(res["rensning"]["dtl"]["vitpose"]["spikar"], {LEDER[HANDLED_B]: 1})
        self.assertEqual(res["rensning"]["dtl"]["vision"]["spikar"], {})
        # Utan faser: bara "alla" och "okand".
        self.assertEqual({r["fas"] for r in res["leder"]}, {"alla"})


class Kedjan(unittest.TestCase):
    """De påhittade paketen genom hela kedjan, med en känd skillnad i främre axeln."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.tmp = tempfile.TemporaryDirectory()
        filer, cls.sanning = paketen()
        cls.fil = filer[1]                                      # DTL, högerspelare, inget dolt
        cls.dx = 12.0
        cls.modell = PahittadVitPose(cls.sanning, fast={LEDER_FIL.index("axel_v"): (cls.dx, 0.0)})
        cls.ut = Path(cls.tmp.name) / "ut"
        cls.s3 = Path(cls.tmp.name) / "inget-s3.json"
        cls.res = AA.kor([cls.fil], cls.ut, None, cls.modell, SlagRutor(cls.modell), s3=cls.s3)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.tmp.cleanup()

    def test_tidsparningen_och_slagen(self) -> None:
        jamforda = [s for s in self.res["slag"] if "hoppat" not in s]
        self.assertEqual(len(jamforda), 3)
        for s in jamforda:
            self.assertAlmostEqual(s["tidsparning"]["forskjutning_ms"], -OFF * 1000, delta=0.1)
            self.assertGreater(s["rutor_parade"], 500)

    def test_skillnaden_hittas_i_ratt_led(self) -> None:
        rader = [r for r in self.res["leder"] if r["fas"] == "alla"]
        fram = next(r for r in rader if r["led"] == LEDER[AXEL_F])      # högerspelaren: vänster = främre
        self.assertGreater(fram["median"], 0.0)
        for r in rader:
            if r["led"] != LEDER[AXEL_F]:
                self.assertLess(r["median"], 0.002, r["led"])
        self.assertTrue(all(r["kvot"] == 1.0 for r in self.res["ryck"]))

    def test_personrutan_ur_vision(self) -> None:
        self.assertGreater(len(self.modell.rutor), 1000)
        x, y, b, h = self.modell.rutor[len(self.modell.rutor) // 2]
        self.assertGreater(b, 0.0)
        self.assertGreater(h, b)                                # en stående person: högre än bred

    def test_filerna_och_sparade_leder(self) -> None:
        self.assertTrue((self.ut / "andra-asikt.md").is_file())
        d = json.loads((self.ut / "andra-asikt.json").read_text(encoding="utf-8"))
        self.assertEqual(d["format"], AA.FORMAT)
        self.assertEqual(len(list((self.ut / "vitpose").glob("*.json"))), 3)
        igen = AA.kor([self.fil], self.ut, None, None, None, s3=self.s3, modell_namn="pahittad")   # ur cachen, utan modell
        self.assertEqual(igen["leder"], self.res["leder"])

    def test_kommandot_vagrar_en_mapp_i_repot(self) -> None:
        f = io.StringIO()
        with contextlib.redirect_stdout(f):
            kod = AA.main([str(self.fil), "--ut", str(Path(AA.__file__).resolve().parents[2] / "tools" / "ut")])
        self.assertEqual(kod, 1)
        self.assertIn("ligger i repot", f.getvalue())


if __name__ == "__main__":
    unittest.main()
