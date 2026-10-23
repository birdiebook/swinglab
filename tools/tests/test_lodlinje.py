"""Lodlinjen från telefonen (S6b, METOD MS17, MK3, BESLUT B39): samma PÅHITTADE telefoner
som SwingLabKit prövar (`LodlinjeTests.swift`) står i `fixturer/lodlinje.json`. Här prövas
att varje vektor telefonen skriver går igenom PC:ns kontroll (`paket.lodlinjen`) och läses ur
ett paket, att telefonens vridning till kamerans ram stämmer med en egen räkning, och att
varje vektor telefonen inte skriver har ett skäl: PC:n hade vägrat den, eller den lutar mer
än telefonens spärr. Kontraktet är alltså prövat åt båda håll."""
from __future__ import annotations

import json
import math
import tempfile
import unittest
import zipfile
from pathlib import Path

import numpy as np

import _hjalp  # noqa: F401  (sökvägen till tools/)
from pc import generera_paket as GP
from pc import paket as P

FIXTUR = Path(__file__).resolve().parent / "fixturer" / "lodlinje.json"
MAX_LUTNING = 45.0     # METOD MS17: telefonens spärr (Plumb.maxTilt)

# En egen räkning av telefonens vridning, med matriser i stället för Swifts ombyte av axlar.
# Enhetens ram (CoreMotion): x höger, y mot skärmens överkant, z ut ur skärmen (stående).
# Bakre kamerans lagrade bild (EXIF 1): höger = -y, ned = -x, framåt ur linsen = -z.
SENSOR = np.array([[0, -1, 0], [-1, 0, 0], [0, 0, -1]], float)
# EXIF: den lagrade bildens (höger, ned) till den upprätta bildens. 6 = 90° medurs.
EXIF = {1: np.eye(3), 6: np.array([[0, -1, 0], [1, 0, 0], [0, 0, 1]], float),
        3: np.diag([-1.0, -1.0, 1.0]), 8: np.array([[0, 1, 0], [-1, 0, 0], [0, 0, 1]], float)}


def upp_i_kamera(gravitation, exif: int) -> np.ndarray:
    return EXIF[exif] @ SENSOR @ (-np.asarray(gravitation, float))


def lutning(v) -> float:
    v = np.asarray(v, float)
    return math.degrees(math.acos(max(-1.0, min(1.0, -v[1] / np.linalg.norm(v)))))


class Lodlinjen(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.fall = json.loads(FIXTUR.read_text(encoding="utf-8"))["fall"]

    def test_staende_och_liggande_finns(self) -> None:
        skrivs = {f["orientering"] for f in self.fall if f["lodlinje"] is not None}
        self.assertTrue({1, 6} <= skrivs, "en telefon i stående och en i liggande")
        self.assertTrue(any(f["lodlinje"] is None for f in self.fall), "och fall som inte skrivs")

    def test_vridningen_stammer_med_en_egen_rakning(self) -> None:
        # Matriserna är vridningar (det(M) = 1): kamerans ram förblir högerhänt.
        for exif, m in EXIF.items():
            self.assertAlmostEqual(np.linalg.det(m @ SENSOR), 1.0, msg=f"EXIF {exif}")
        for f in self.fall:
            if f["lodlinje"] is None:
                continue
            u = upp_i_kamera(f["gravitation"], f["orientering"])
            np.testing.assert_allclose(f["lodlinje"], u, atol=0.6e-4, err_msg=f["namn"])

    def test_det_telefonen_skriver_tar_pc_n(self) -> None:
        for f in self.fall:
            if f["lodlinje"] is None:
                continue
            v, fel = P.lodlinjen({"lodlinje": f["lodlinje"]}, 1)
            self.assertIsNone(fel, f["namn"])
            self.assertEqual(v, tuple(f["lodlinje"]), f["namn"])
            self.assertLessEqual(lutning(v), MAX_LUTNING, f["namn"])

    def test_det_telefonen_inte_skriver_har_ett_skal(self) -> None:
        for f in self.fall:
            if f["lodlinje"] is not None:
                continue
            u = [float(x) for x in upp_i_kamera(f["gravitation"], f["orientering"])]
            v, fel = P.lodlinjen({"lodlinje": u}, 1)
            # PC:n vägrar den (pekar inte mot överkanten), eller telefonens spärr är strängare.
            self.assertTrue(fel is not None or lutning(u) > MAX_LUTNING, f["namn"])
            if fel is not None:
                self.assertNotIn(str(round(u[1], 4)), fel, "skälet utan värden")

    def test_paketet_med_telefonens_vektorer(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            src = GP.paket(d, "20261103-180000", "fo", n=3, serier=1)
            with zipfile.ZipFile(src) as z:
                filer = {n: z.read(n) for n in z.namelist()}
            m = json.loads(filer["manifest.json"])
            for f in self.fall:
                if f["lodlinje"] is None:
                    continue
                m["serier"][0]["lodlinje"] = f["lodlinje"]
                dst = Path(d) / f"lod-{f['namn']}.zip"
                with zipfile.ZipFile(dst, "w") as z:
                    for n, b in filer.items():
                        z.writestr(n, json.dumps(m) if n == "manifest.json" else b)
                s = P.las(dst).serier[1]
                self.assertIsNone(s.lodlinje_fel, f["namn"])
                self.assertEqual(s.lodlinje, tuple(f["lodlinje"]), f["namn"])
            # Utan fältet (gamla paket och telefonen som rörde sig): som förut.
            del m["serier"][0]["lodlinje"]
            dst = Path(d) / "utan.zip"
            with zipfile.ZipFile(dst, "w") as z:
                for n, b in filer.items():
                    z.writestr(n, json.dumps(m) if n == "manifest.json" else b)
            s = P.las(dst).serier[1]
            self.assertIsNone(s.lodlinje)
            self.assertIsNone(s.lodlinje_fel)


if __name__ == "__main__":
    unittest.main()
