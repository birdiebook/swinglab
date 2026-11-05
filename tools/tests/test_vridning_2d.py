"""S6e steg 0: vridningen ur en telefon (tools/pc/vridning_2d.py, METOD M70–M73).

Geometrin prövas på linjer som projiceras exakt genom en hålkamera: skattarna ska ge
vinkeln där deras modell gäller, och brista där METOD säger att de brister (den lodräta
komponenten i FO a, sidböjningen i FO b, vikningen vid 90° i DTL c). Sedan hela kedjan på
påhittade svingar utan brus, och Monte Carlo som körs och är deterministisk. Inga riktiga
leder (CLAUDE.md, Dataregeln).
"""
from __future__ import annotations

import math
import sys
import unittest
from dataclasses import replace
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from pc import vridning_2d as V  # noqa: E402
from pc.tre_d import kamera as KM  # noqa: E402
from pc.tre_d.sving import Sving  # noqa: E402

T = np.arange(0.0, 2.2, 1 / 240)
ADRESS = (0.1, 0.4)
TOPP, TRAFF = 1.3, 1.6


def vridning():
    """En vridning (grader, + = stängd): stilla i adressen, 50° vid toppen, −40° vid träffen."""
    return np.interp(T, [0.0, 0.5, TOPP, TRAFF, 2.2], [0.0, 0.0, 50.0, -40.0, -75.0])


def projicera(mitt, linjen):
    """Ändarna mitt ± linjen/2 i kamerans ram (x höger, y ned, z framåt) → normerade
    bildkoordinater (T, 2) för den främre och den bakre änden."""
    f, b = mitt + linjen / 2, mitt - linjen / 2
    return f[:, :2] / f[:, 2:3], b[:, :2] / b[:, 2:3]


def rodrigues(v, axel, vinkel):
    axel = axel / np.linalg.norm(axel)
    c, s = np.cos(vinkel)[:, None], np.sin(vinkel)[:, None]
    return v * c + np.cross(axel, v) * s + axel * (v @ axel)[:, None] * (1 - c)


class FramifranStelLinje(unittest.TestCase):
    """FO: linjen ligger i bildens plan i adressen och vrids kring lodlinjen; den främre
    änden mot kameran = stängd. Perspektivet finns med (linjens mitt vid sidan av blicken)."""

    def setUp(self):
        th = np.radians(vridning())
        L = 0.20
        self.linjen = np.stack([L * np.cos(th), np.zeros_like(th), -L * np.sin(th)], -1)
        self.mitt = np.tile([0.15, -0.10, 3.0], (len(T), 1))

    def test_stel_linje_ger_vinkeln_med_perspektiv_och_tecken(self):
        """Exakt vid toppen och träffen; bara rutan där rötterna byts kan ligga under 1° fel."""
        nf, nb = projicera(self.mitt, self.linjen)
        y = V.fo_stel(nf, nb, T, ADRESS, TOPP, TRAFF)
        e = np.abs(y - vridning())
        for tid in (TOPP, TRAFF):
            self.assertLess(e[np.searchsorted(T, tid)], 1e-6)
        self.assertLess(np.nanmax(e), 1.0)
        self.assertLess(np.mean(e > 1e-6), 0.01)

    def test_djupet_ar_det_sanna(self):
        """En av de två rötterna är alltid det sanna djupet (hålkameran är exakt)."""
        nf, nb = projicera(self.mitt, self.linjen)
        A, B = nf - nb, (nf + nb) / 2
        L2 = float(A[0] @ A[0])
        sant = self.linjen[:, 2] / self.mitt[:, 2]
        fel = np.minimum(np.abs(V.djupet(A, B, L2, True) - sant), np.abs(V.djupet(A, B, L2, False) - sant))
        self.assertLess(np.max(fel), 1e-9)

    def test_spegelroten_vid_sidan_av_blicken(self):
        """Med linjens mitt vid sidan av blicken speglas rötterna kring synlinjens vinkelräta,
        inte kring bildens plan: en linje i bildens plan har två lösningar, 0° och ≈ 2 ·
        mittens vinkel från blicken."""
        nf, nb = projicera(self.mitt[:1], self.linjen[:1])
        A, B = nf - nb, (nf + nb) / 2
        d = V.djupet(A, B, float(A[0] @ A[0]), True)[0]
        spegel = math.degrees(math.atan2(-d, A[0, 0] + B[0, 0] * d))
        self.assertAlmostEqual(spegel, 2 * math.degrees(math.atan(0.15 / 3.0)), delta=0.2)

    def test_forkortningen_laser_lodrat_lutning_som_vridning(self):
        """FO a räknar den lodräta komponenten som djup; den stela linjen gör det inte (linjen
        mitt i blicken, så att spegelroten inte stör)."""
        lut = np.radians(np.interp(T, [0, 0.5, 1.3, 2.2], [0, 0, 25.0, 25.0]))   # sidböjning, ingen vridning
        linjen = np.stack([0.2 * np.cos(lut), 0.2 * np.sin(lut), np.zeros_like(lut)], -1)
        nf, nb = projicera(np.tile([0.0, 0.0, 3.0], (len(T), 1)), linjen)
        a = V.fo_a(nf - nb, V.i_adressen(T, nf - nb, ADRESS))
        stel = V.fo_stel(nf, nb, T, ADRESS, TOPP, TRAFF)
        i = np.searchsorted(T, TOPP)
        self.assertGreater(a[i], 20.0)
        self.assertLess(abs(stel[i]), 1.0)

    def test_adressens_djup_ur_bojningen(self):
        """En böjd bål (β) som sidböjer s i adressen lyfter främre axeln och för den mot bollen:
        med β räknas den vinkeln (≈ atan(tan β · tan lutningen)) bort."""
        beta, s = math.radians(38.0), math.radians(-10.0)
        # linjen i världen (x mot målet, y bort från bollen, z upp) = Rx(β)·Ry(s)·e_x, som sving.py i adressen
        lv = np.array([math.cos(s), math.sin(beta) * math.sin(s), -math.cos(beta) * math.sin(s)])
        th = np.radians(vridning())
        R = np.stack([np.stack([np.cos(th), np.sin(th), 0 * th], -1), np.stack([-np.sin(th), np.cos(th), 0 * th], -1),
                      np.stack([0 * th, 0 * th, 1 + 0 * th], -1)], -2)          # Rz(−θ), kring lodlinjen
        lw = 0.36 * (R @ lv)
        linjen = np.stack([lw[:, 0], -lw[:, 2], lw[:, 1]], -1)                # kamerans ram (FO tittar längs +y)
        nf, nb = projicera(self.mitt, linjen)
        utan = V.fo_stel(nf, nb, T, ADRESS, TOPP, TRAFF)
        med = V.fo_stel(nf, nb, T, ADRESS, TOPP, TRAFF, beta_deg=38.0)
        i = np.searchsorted(T, TOPP)
        sann = vridning()[i]
        self.assertGreater(abs(utan[i] - sann), 4.0)      # förskjutningen ≈ 6°
        self.assertLess(abs(med[i] - sann), 0.5)


class FramifranLutandeAxel(unittest.TestCase):
    """FO b: vridningen kring en axel som lutar β mot kameran ger en lodrät komponent med
    tecken; en sidböjning utan vridning läses som vridning (skattaren brister där)."""

    BETA = 30.0

    def linjen(self, phi):
        b = math.radians(self.BETA)
        axel = np.array([0.0, -math.cos(b), -math.sin(b)])          # uppåt och mot kameran, kamerans ram
        l0 = np.tile([0.2, 0.0, 0.0], (len(phi), 1))
        return rodrigues(l0, axel, phi)

    def test_lutande_axel_ger_vinkeln_i_markplanet(self):
        phi = -np.radians(vridning())                               # φ < 0 = stängd
        linjen = self.linjen(phi)
        mitt = np.tile([0.0, 0.0, 3.0], (len(T), 1))
        nf, nb = projicera(mitt, linjen)
        y = V.fo_b(nf, nb, V.i_adressen(T, nf - nb, ADRESS), self.BETA)
        sann = np.degrees(np.arctan2(-linjen[:, 2], linjen[:, 0]))
        self.assertLess(np.nanmax(np.abs(y - sann)), 0.6)
        self.assertGreater(y[np.searchsorted(T, TOPP)], 30.0)     # tecknet ur den lodräta komponenten
        self.assertLess(y[np.searchsorted(T, TRAFF)], -20.0)

    def test_sidbojning_laser_som_vridning(self):
        lut = np.radians(np.interp(T, [0, 0.5, 1.3, 2.2], [0, 0, 10.0, 10.0]))   # främre änden nedåt
        linjen = np.stack([0.2 * np.cos(lut), 0.2 * np.sin(lut), np.zeros_like(lut)], -1)
        nf, nb = projicera(np.tile([0.0, 0.0, 3.0], (len(T), 1)), linjen)
        y = V.fo_b(nf, nb, V.i_adressen(T, nf - nb, ADRESS), self.BETA)
        self.assertGreater(y[np.searchsorted(T, TOPP)], 10.0)


class Bakifran(unittest.TestCase):
    """DTL c: linjen pekar längs blicken i adressen; med den sanna längden ges vinkeln med
    tecken, men över 90° viks den tillbaka."""

    def vinkel(self, grader, x=-0.20):
        th = np.radians(grader)
        L = 0.36
        linjen = np.stack([L * np.sin(th), np.zeros_like(th), L * np.cos(th)], -1)   # +x = mot bollen
        mitt = np.tile([x, -0.10, 3.0], (len(th), 1))
        nf, nb = projicera(mitt, linjen)
        return V.dtl_c(nf, nb, L / 3.0, T[:len(th)], ADRESS)

    def test_bredden_ger_vinkeln_med_tecken(self):
        y = self.vinkel(vridning())
        self.assertLess(np.nanmax(np.abs(y - vridning())), 0.05)

    def test_over_90_grader_viks_vinkeln(self):
        """Vikningen sker där linjen står vinkelrät mot synlinjen: 110° blir 70° mitt i
        blicken, och 70° − 2 · mittens vinkel från blicken vid sidan av den."""
        g = np.interp(T, [0, 0.5, 1.3, 2.2], [0, 0, 110.0, 110.0])
        i = np.searchsorted(T, TOPP)
        self.assertAlmostEqual(float(self.vinkel(g, x=0.0)[i]), 70.0, delta=0.2)
        self.assertAlmostEqual(float(self.vinkel(g)[i]), 70.0 - 2 * math.degrees(math.atan(0.2 / 3.0)), delta=0.3)


class Lodlinjen(unittest.TestCase):
    def test_lodratt_rattar_lutningen(self):
        """En lutande kamera: två punkter lodrätt över varandra hamnar lodrätt i den rättade bilden."""
        kam = KM.titta_mot([0.0, -3.15, 1.6], [0.3, 0.0, 0.9])     # tittar nedåt och snett
        rull = np.radians(4.0)
        Rz = np.array([[math.cos(rull), -math.sin(rull), 0], [math.sin(rull), math.cos(rull), 0], [0, 0, 1]])
        kam = KM.Kamera(K=kam.K, R=Rz @ kam.R, t=Rz @ kam.t)
        P = np.array([[0.2, 0.1, 0.4], [0.2, 0.1, 1.5]])
        uv = V.tillampa(V.lodratt(kam.K, kam.R @ np.array([0.0, 0.0, 1.0])), kam.projicera(P))
        self.assertAlmostEqual(uv[0, 0], uv[1, 0], delta=1e-6)
        self.assertGreater(uv[0, 1], uv[1, 1])                      # den lägre punkten längre ned i bild


class Kedjan(unittest.TestCase):
    """Hela försöket på påhittade svingar utan brus (METOD M70)."""

    @classmethod
    def setUpClass(cls):
        s = Sving()
        s.t_start, s.efter = V.T_START_3D, V.EFTER_3D
        s.__post_init__()
        cls.r = V.forsok(V.REN, np.random.default_rng(1), s=s)

    def test_sanningen_ar_felbudgetens(self):
        """Grundsvingen har felbudgetens tal (S6_FELBUDGET §2) också med den längre adressen."""
        sant = self.r["sant"]
        for k, v in (("backen_topp", 42.8), ("brost_topp", 87.2), ("xfaktor_topp", 44.4),
                     ("hofter_oppna_traff", 37.4)):
            self.assertAlmostEqual(sant[k], v, delta=0.05, msg=k)

    def test_fo_stel_linje_med_adressens_djup(self):
        fel = self.r["fo_stel_b"]["fel"]
        for k in ("backen_topp", "brost_topp", "xfaktor_topp"):
            self.assertLess(abs(fel[k]), 2.5, k)
        self.assertLess(abs(fel["hofter_oppna_traff"]), 1.0)

    def test_fo_utan_bojningen_bar_adressens_djup(self):
        self.assertGreater(self.r["fo_stel"]["fel"]["brost_topp"], 4.0)
        self.assertLess(abs(self.r["fo_stel_b"]["fel"]["brost_topp"]), abs(self.r["fo_stel"]["fel"]["brost_topp"]))

    def test_dtl_bredden(self):
        fel = self.r["dtl_c"]["fel"]
        self.assertLess(abs(fel["backen_topp"]), 1.0)
        self.assertLess(abs(fel["hofter_oppna_traff"]), 2.0)
        self.assertLess(abs(fel["brost_traff"]), 1.0)

    def test_dtl_viker_axlarna_vid_toppen(self):
        """Axlarna står bortom 90° mot DTL:s blick vid toppen: vinkeln viks och blir för liten."""
        self.assertLess(self.r["dtl_c"]["fel"]["brost_topp"], -5.0)

    def test_varianten_lutande_passar_fo_b(self):
        """FO b bygger på vridningen kring den böjda axeln: axlarnas kurva blir mycket bättre
        i den varianten än i grundsvingen (vridningen kring lodlinjen och en sidböjning)."""
        u = replace(V.REN, variant="lutande")
        s = V.ny_sving(u, np.random.default_rng(5))
        lut = V.forsok(u, np.random.default_rng(1), s=s)
        self.assertGreater(lut["sant"]["xfaktor_topp"], self.r["sant"]["xfaktor_topp"])
        self.assertLess(lut["fo_b"]["kurva"]["brost"], 0.6 * self.r["fo_b"]["kurva"]["brost"])

    def test_en_vy_som_inte_gick_ger_inget(self):
        self.assertIsNone(V.kurvor("fo_a", {"fo": {"fel": "händerna syns inte"}}, None))


class MonteCarlo(unittest.TestCase):
    def test_kors_och_ar_deterministisk(self):
        u = replace(V.EnKamera(), brus="bra")
        a = V.monte_carlo(u, 3, seed=2, skattare=("fo_stel_b", "dtl_c"))
        b = V.monte_carlo(u, 3, seed=2, skattare=("fo_stel_b", "dtl_c"))
        for k in ("fo_stel_b", "dtl_c"):
            for m in V.MATT:
                self.assertEqual(a[k]["matt"][m]["n"], 3)
                self.assertTrue(math.isfinite(a[k]["matt"][m]["bias"]), (k, m))
                self.assertEqual(a[k]["matt"][m]["bias"], b[k]["matt"][m]["bias"])

    def test_passets_median(self):
        r = V.pass_monte_carlo(replace(V.EnKamera(), brus="bra"), 1, 2, seed=3, skattare=("dtl_c",))
        self.assertEqual(r["dtl_c"]["backen_topp"]["n"], 1)

    def test_tabellen(self):
        res = V.monte_carlo(V.REN, 2, seed=4, skattare=("fo_a",))
        text = V.tabell("Prov", [("Inget brus", res)], ("fo_a",))
        self.assertIn("FO a, förkortning", text)
        self.assertIn("| Inget brus |", text)


if __name__ == "__main__":
    unittest.main()
