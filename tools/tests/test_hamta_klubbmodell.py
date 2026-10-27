"""S7-2: klubbmodellen ur sin release, summorna och uppackningen (BESLUT B96, METOD MF7)."""
from __future__ import annotations

import hashlib
import json
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import hamta_klubbmodell as H  # noqa: E402
from pc import publicera_klubbmodell as P  # noqa: E402


class Hamtningen(unittest.TestCase):
    """En påhittad release i en lokal mapp (file://), aldrig nätet."""

    NAMN = "klubba-prov-2026-10-27-fp16"

    def _release(self, rot: Path) -> dict:
        tag = rot / "klubbmodell-prov"
        tag.mkdir(parents=True)
        with zipfile.ZipFile(tag / f"{self.NAMN}.mlpackage.zip", "w") as z:
            z.writestr("Klubbmodell.mlpackage/Manifest.json", "{}")
            z.writestr("Klubbmodell.mlpackage/Data/weights.bin", b"\0" * 16)
        with zipfile.ZipFile(tag / f"{self.NAMN}-prov.zip", "w") as z:
            z.writestr("prov/prov.json", "{}")
            z.writestr("prov/prov-01.png", b"png")
        (tag / f"{self.NAMN}.json").write_text('{"format": "swinglab-klubba-coreml/1"}')
        filer = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in tag.iterdir()}
        return {"format": H.FORMAT, "tag": "klubbmodell-prov", "modell": self.NAMN, "filer": filer}

    def test_hamtar_och_packar_upp(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            rot = Path(tmp)
            p = self._release(rot / "rel")
            H.hamta(p, rot / "Modeller", rot / "prov", bas=(rot / "rel").as_uri())
            self.assertTrue((rot / "Modeller" / "Klubbmodell.mlpackage" / "Data" / "weights.bin").is_file())
            self.assertTrue((rot / "Modeller" / "Klubbmodell.json").is_file())
            self.assertEqual(sorted(x.name for x in (rot / "prov").iterdir()), ["prov-01.png", "prov.json"])

    def test_utan_prov_hamtas_det_inte(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            rot = Path(tmp)
            p = self._release(rot / "rel")
            (rot / "rel" / "klubbmodell-prov" / f"{self.NAMN}-prov.zip").unlink()   # bygget behöver det inte
            r = H.hamta(p, rot / "Modeller", None, bas=(rot / "rel").as_uri())
            self.assertFalse(any("prov.zip" in x for x in r))

    def test_fel_summa_vagras(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            rot = Path(tmp)
            p = self._release(rot / "rel")
            p["filer"][f"{self.NAMN}.json"] = "0" * 64
            with self.assertRaisesRegex(H.HamtFel, "sha256"):
                H.hamta(p, rot / "Modeller", None, bas=(rot / "rel").as_uri())
            self.assertFalse((rot / "Modeller").exists())

    def test_pekaren(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp) / "klubbmodell.json"
            f.write_text(json.dumps({"format": H.FORMAT, "tag": "t", "modell": "m", "filer": {"m.json": "x"}}))
            with self.assertRaisesRegex(H.HamtFel, "m.mlpackage.zip"):
                H.las_pekare(f)

    def test_repots_pekare_ar_giltig(self) -> None:
        p = H.las_pekare()
        self.assertTrue(p["tag"].startswith("klubbmodell-"))
        self.assertTrue(all(d["licens"] == "CC BY 4.0" for d in p["data"]))     # B96: bara öppen data


class Publiceringen(unittest.TestCase):
    """Spärrarna före uppladdningen (B96); nätet rörs inte."""

    def _mapp(self, rot: Path, data: list) -> Path:
        m = rot / "rel"
        m.mkdir()
        (m / "m.json").write_text("{}")
        (m / "m.mlpackage.zip").write_bytes(b"x")
        (m / "m-prov.zip").write_bytes(b"y")
        filer = {p.name: H.sha256(p) for p in m.iterdir()}
        pekare = {"format": H.FORMAT, "tag": "klubbmodell-m", "modell": "m", "data": data, "filer": filer}
        (m / "klubbmodell.json").write_text(json.dumps(pekare))
        return m

    OPPEN = [{"namn": "golf-club-tracking", "licens": "CC BY 4.0", "kalla": "https://x"}]

    def test_godkand_nar_allt_stammer(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            m = self._mapp(Path(tmp), self.OPPEN)
            p = P.kontrollera(m, m / "klubbmodell.json")
            self.assertIn("golf-club-tracking (CC BY 4.0)", P.text(p)[1])

    def test_vagrar(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            m = self._mapp(Path(tmp), [{"namn": "oktober-j7", "licens": "privat", "kalla": ""}])
            with self.assertRaisesRegex(P.PubFel, "öppet"):
                P.kontrollera(m, m / "klubbmodell.json")
        with tempfile.TemporaryDirectory() as tmp:
            m = self._mapp(Path(tmp), self.OPPEN)
            (m / "m.json").write_text("{ }")                                  # ändrad efter pekaren
            with self.assertRaisesRegex(P.PubFel, "sha256"):
                P.kontrollera(m, m / "klubbmodell.json")
        with tempfile.TemporaryDirectory() as tmp:
            m = self._mapp(Path(tmp), self.OPPEN)
            annan = Path(tmp) / "annan.json"
            annan.write_text(json.dumps({**json.loads((m / "klubbmodell.json").read_text()), "tag": "klubbmodell-x"}))
            with self.assertRaisesRegex(P.PubFel, "repots"):
                P.kontrollera(m, annan)


if __name__ == "__main__":
    unittest.main()
