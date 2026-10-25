"""Klubbens bana i 3D (PLAN S7e, METOD MK12) på en PÅHITTAD sving: två kameror med 90°
mellan sig, lederna och klubbhuvudet projicerade med brus, och sanningen att mäta mot."""
from __future__ import annotations

import math
import unittest

import numpy as np

import _hjalp  # noqa: F401
from pc import klubba_3d as KL
from pc.tre_d.kamera import K_matris, titta_mot
from pc.tre_d.sving import I

F, W, H = 1384.0, 1080, 1920
T = np.arange(-1.5, 1.0, 1 / 240)
MITT = np.array([0.0, -0.3, 1.0])      # svingens mitt
RADIE = 1.4                            # huvudets avstånd från mitten
GREPP_ANDEL = 0.45                     # greppet ligger så långt ut mot huvudet: skaftet 0,55 · RADIE


def vinkel(t: np.ndarray) -> np.ndarray:
    """Huvudets vinkel i svingplanet: adressen nere, toppen −0,28 s, träffen 0 och finishen."""
    return np.interp(t, [-1.5, -1.1, -0.28, 0.0, 0.6, 1.0], [0.0, 0.0, 4.0, 2 * math.pi, 9.0, 9.0])


def huvudet(t: np.ndarray) -> np.ndarray:
    """En bana som inte är plan: planet lutar 55°, och nedsvingen ligger 8 cm innanför."""
    a = vinkel(t)
    u = np.array([1.0, 0.0, 0.0])
    v = np.array([0.0, math.cos(math.radians(55)), math.sin(math.radians(55))])
    n = np.cross(u, v)
    inne = np.where((t > -0.28) & (t < 0.0), 0.08, 0.0)[:, None]
    return MITT + RADIE * (-np.sin(a)[:, None] * u - np.cos(a)[:, None] * v) + inne * n


def leder(t: np.ndarray) -> np.ndarray:
    """13 leder kring stansen som rör sig lite, handlederna i greppet."""
    rng = np.random.default_rng(3)
    bas = rng.uniform([-0.3, -0.25, 0.05], [0.3, 0.25, 1.75], (len(I), 3))
    X = bas[None] + 0.05 * np.sin(2 * t[:, None, None] + np.arange(len(I))[None, :, None])
    G = MITT + GREPP_ANDEL * (huvudet(t) - MITT)
    X[:, I["v_handled"]] = G + [0.02, 0, 0]
    X[:, I["h_handled"]] = G - [0.02, 0, 0]
    return X


def kameror():
    K = K_matris(F, W / 2, H / 2)
    return titta_mot([0.0, -3.0, 1.1], [0.0, 0.0, 0.9], K, "A"), titta_mot([-3.0, 0.0, 1.2], [0.0, 0.0, 0.9], K, "B")


def slaget(brus: float = 1.0, saknas_dtl: tuple | None = None, forskjut_dtl: float = 0.0) -> tuple[dict, tuple]:
    """Slaget som tva_kameror ser det (FO = A, DTL = B), med huvudspåren som förslagsfilen ger dem."""
    rng = np.random.default_rng(7)
    kamA, kamB = kameror()
    X, Hh = leder(T), huvudet(T)
    d = {"KA": kamA.K, "KB": kamB.K, "tA": T.copy(), "tB": T.copy()}
    for kam, s in ((kamA, "A"), (kamB, "B")):
        d["uv" + s] = kam.projicera(X) + rng.normal(0, brus, (len(T), len(I), 2))
        d["k" + s] = np.full((len(T), len(I)), 0.9)
        h = kam.projicera(Hh) + rng.normal(0, brus, (len(T), 2))
        th = T + (forskjut_dtl if s == "B" else 0.0)
        spar = np.column_stack([th, h, np.full(len(T), 0.8)])
        if s == "B" and saknas_dtl:
            spar = spar[(T < saknas_dtl[0]) | (T > saknas_dtl[1])]
        d["huvud" + s] = spar
    return d, (kamA, kamB, X, Hh)


class Sfaren(unittest.TestCase):
    def test_tva_skarningar_och_miss(self):
        C, G = np.zeros(3), np.array([[0.0, 0.0, 5.0], [0.0, 3.0, 5.0]])
        d = np.array([[0.0, 0.0, 1.0], [0.0, 0.0, 1.0]])
        X, traff = KL.sfar(C, d, G, 1.0)
        self.assertTrue(traff[0])
        self.assertFalse(traff[1])
        np.testing.assert_allclose(sorted(X[0, :, 2]), [4.0, 6.0], atol=1e-9)


class Kalibreringen(unittest.TestCase):
    def test_uppstallningen_hittas_med_huvudet(self):
        d, _ = slaget()
        R, t, upp, info = KL.kalibrera([d], [0.0])
        self.assertLess(abs(info["vinkel_mellan_kamerorna"] - 90.0), 3.0, info)
        self.assertLess(info["sampson_huvud_px"], 2.0, info)
        self.assertEqual(info["kalibrering"], "uppstallningen")


class Banan(unittest.TestCase):
    def test_tva_vyer_och_sfaren_mot_sanningen(self):
        d, (kamA, kamB, X, Hh) = slaget(saknas_dtl=(-0.7, -0.5))
        b = KL.bana(kamA, kamB, d, 0.0, T, X)
        self.assertNotIn("fel", b)
        sann = np.column_stack([np.interp(b["t"], T, Hh[:, a]) for a in range(3)])
        e = np.linalg.norm(b["huvud"] - sann, axis=1)
        self.assertLess(np.median(e[b["kalla"] == 2]), 0.01)
        en = b["kalla"] == 1
        self.assertGreater(en.sum(), 20)
        self.assertLess(np.median(e[en]), 0.03)
        self.assertAlmostEqual(b["skaft"], (1 - GREPP_ANDEL) * RADIE, delta=0.02)
        self.assertLess(b["aterprojektion_px"], 3.0)

    def test_fel_synk_ger_ingen_bana(self):
        d, (kamA, kamB, X, _) = slaget(forskjut_dtl=0.3)
        self.assertIn("fel", KL.bana(kamA, kamB, d, 0.0, T, X))

    def test_synken_pa_huvudet(self):
        d, (kamA, kamB, _, _) = slaget(forskjut_dtl=0.003)
        self.assertAlmostEqual(KL.synka_huvud(kamA, kamB, d, 0.0), 0.003, delta=0.0007)

    def test_svingen_klipps_vid_p1_och_finishen(self):
        d, (kamA, kamB, X, _) = slaget()
        b = KL.svingen(KL.bana(kamA, kamB, d, 0.0, T, X), -1.1)
        self.assertGreaterEqual(b["t"][0], -1.1 - KL.FORE_P1_S - 1e-9)
        # huvudet når sin högsta punkt vid 0,6 s och står sedan still (finishen)
        self.assertGreaterEqual(b["t"][-1], 0.6)
        self.assertLessEqual(b["t"][-1], KL.FINISH_SOK_S + KL.EFTER_FINISH_S + 1e-9)
        self.assertEqual(len(b["t"]), len(b["huvud"]))


class EnVy(unittest.TestCase):
    def test_mallen_lagger_huvudet_ratt(self):
        d, (kamA, kamB, X, Hh) = slaget()
        pos = {"P1": -1.1, "P4": -0.28}
        a = KL.bana(kamA, kamB, d, 0.0, T, X)
        mall = KL.djupmall(a, pos, kamA)
        b = KL.bana_en_vy(kamA, T, d["uvA"], d["kA"], d["huvudA"], pos, mall)
        j = KL.jamfor_banor(a, b)
        self.assertLess(j["median"], 0.02, j)

    def test_fasen(self):
        f = KL.fas(np.array([-1.1, -0.28, 0.0, -0.69]), {"P1": -1.1, "P4": -0.28})
        np.testing.assert_allclose(f, [0.0, 1.0, 2.0, 0.5], atol=1e-9)


if __name__ == "__main__":
    unittest.main()
