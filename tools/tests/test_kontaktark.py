"""Kontaktarket (METOD MT7). PNG-skrivaren och tiderna provas alltid; arket ur
ett påhittat klipp bara där ffmpeg eller OpenCV finns."""
from __future__ import annotations

import shutil
import struct
import tempfile
import unittest
import zlib
from pathlib import Path

import numpy as np

import _hjalp  # noqa: F401
from pc import analys as A
from pc import faser as F
from pc import generera_paket as GP
from pc import kontaktark as KA
from pc import paket as P


def _las_png(fil: Path) -> np.ndarray:
    b = fil.read_bytes()
    assert b[:8] == b"\x89PNG\r\n\x1a\n"
    w, h = struct.unpack(">II", b[16:24])
    pos, data = 8, b""
    while pos < len(b):
        n = struct.unpack(">I", b[pos:pos + 4])[0]
        typ = b[pos + 4:pos + 8]
        if typ == b"IDAT":
            data += b[pos + 8:pos + 8 + n]
        pos += 12 + n
    raa = zlib.decompress(data)
    return np.frombuffer(raa, np.uint8).reshape(h, 1 + 3 * w)[:, 1:].reshape(h, w, 3)


class Delarna(unittest.TestCase):
    def test_png_tur_och_retur(self) -> None:
        img = (np.arange(4 * 5 * 3) % 256).astype(np.uint8).reshape(4, 5, 3)
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp) / "x.png"
            KA.skriv_png(f, img)
            self.assertTrue(np.array_equal(_las_png(f), img))

    def test_tiderna(self) -> None:
        t = KA.tider({"start": -1.3, "topp": -0.3, "traff": -0.01})
        self.assertAlmostEqual(t["adress"], -1.3 + sum(F.ADRESS) / 2)
        self.assertAlmostEqual(t["finish"], -0.01 + sum(F.FINISH) / 2)
        t = KA.tider({"start": None, "topp": -0.3, "traff": 0.0})
        self.assertAlmostEqual(t["adress"], -0.3 - F.TOPP_ADRESS_S + sum(F.ADRESS) / 2)

    def test_lederna_ritas_vita(self) -> None:
        img = np.zeros((20, 20, 3), np.uint8)
        leder = [None] * 13
        leder[1], leder[2] = {"x": 2, "y": 10, "c": 0.9}, [18, 10, 0.9]
        KA.rita_leder(img, leder, 1.0, 1.0)
        self.assertTrue((img[10, 2:19] == 255).all())
        self.assertEqual(int(img[0].sum()), 0)

    def test_utan_klipp_hoppas_arket_over(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            fil = GP.paket(tmp, "20261103-180000", "fo", n=3, inte_sving=0)
            p = P.las(fil)
            r = KA.bygg(fil, p, A.mat_paket(p, 1.8), Path(tmp), satt="ffmpeg")
            self.assertEqual(r, {"hoppat": "paketet har inga klipp till mätta slag"})


class SkadatKlipp(unittest.TestCase):
    """Granskningen fynd 8: ett klipp med fel CRC blir PaketFel, utan innehållet."""

    def test_skadat_klipp(self) -> None:
        import json
        import zipfile
        with tempfile.TemporaryDirectory() as tmp:
            src = GP.paket(tmp, "20261103-180000", "fo", n=2, inte_sving=0)
            dst = Path(tmp) / "med_klipp.zip"
            with zipfile.ZipFile(src) as zi, zipfile.ZipFile(dst, "w", zipfile.ZIP_STORED) as zo:
                m = json.loads(zi.read("manifest.json"))
                for s in m["slag"]:
                    s.update(klipp=f"klipp/{s['id']}.mov", klick_i_klipp_s=2.5)
                zo.writestr("manifest.json", json.dumps(m))
                for n in zi.namelist():
                    if n != "manifest.json":
                        zo.writestr(n, zi.read(n))
                for s in m["slag"]:
                    zo.writestr(s["klipp"], bytes(range(256)) * 8)
            p = P.las(dst)
            with zipfile.ZipFile(dst) as z:
                info = z.getinfo("klipp/s01.mov")
            b = bytearray(dst.read_bytes())
            b[info.header_offset + 30 + len(info.filename) + len(info.extra) + 100] ^= 0x01
            dst.write_bytes(bytes(b))
            with self.assertRaises(P.PaketFel) as e:
                KA.bygg(dst, p, A.mat_paket(p, 1.8), Path(tmp) / "ut", satt="ffmpeg")
        self.assertEqual(e.exception.fel, ["med_klipp.zip: klipp/s01.mov är skadad i zippen"])


@unittest.skipIf(shutil.which("ffmpeg") is None, "ffmpeg saknas")
class Arket(unittest.TestCase):
    def test_ett_ark_med_en_rad_per_slag_och_fyra_faser(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            fil = GP.paket(tmp, "20261103-180000", "fo", n=3, inte_sving=1, klipp=True)
            p = P.las(fil)
            r = KA.bygg(fil, p, A.mat_paket(p, 1.8), Path(tmp) / "ut")
            self.assertEqual((r["rader"], r["kolumner"]), (["s01", "s02", "s03"], list(KA.KOLUMNER)))
            img = _las_png(Path(tmp) / "ut" / r["fil"])
        hojd = int(round(KA.BREDD * 1920 / 1080 / 2)) * 2
        self.assertEqual(img.shape, (3 * (hojd + KA.MELLANRUM), 4 * (KA.BREDD + KA.MELLANRUM), 3))
        self.assertGreater(float(img.mean()), 20.0)          # rutorna är lästa, inte svarta


if __name__ == "__main__":
    unittest.main()
