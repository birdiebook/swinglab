"""S6c-1: fixturerna för 3D på telefonen är fortfarande Pythons tal (BESLUT B12, B48).

`tools/pc/generera_tre_d.py` skriver påhittade tvåpaketspass och Pythons `tre_d` till
tools/tests/fixturer/tre_d/, som SwingLabKit:s TreDTests jämför med. Här räknas de om ur
fixturens egna indata: ändras kedjan i Python ska fixturerna skrivas om, annars prövar
Swift mot gamla tal. Talen jämförs inom 1e-9 (en annan dator kan ge andra sista
bitar ur BLAS). Inga riktiga leder (CLAUDE.md, Dataregeln).
"""
from __future__ import annotations

import json
import math
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from pc import generera_tre_d as GT  # noqa: E402
from pc import tva_kameror as TK  # noqa: E402

TMP = tempfile.TemporaryDirectory()


def lika(a, b, vag: str = "") -> list[str]:
    """Skillnaderna mellan två JSON-värden (tal inom 1e-9 relativt)."""
    if isinstance(a, dict) and isinstance(b, dict):
        if set(a) != set(b):
            return [f"{vag}: nycklarna skiljer"]
        return [f for k in a for f in lika(a[k], b[k], f"{vag}.{k}")]
    if isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            return [f"{vag}: längden skiljer"]
        return [f for i, (x, y) in enumerate(zip(a, b)) for f in lika(x, y, f"{vag}[{i}]")]
    if isinstance(a, (int, float)) and isinstance(b, (int, float)) and not isinstance(a, bool):
        return [] if math.isclose(a, b, rel_tol=1e-9, abs_tol=1e-9) else [f"{vag}: talet skiljer"]
    return [] if a == b else [f"{vag}: skiljer"]


def _las(namn: str) -> dict:
    return json.loads((GT.MAPP / f"{namn}.json").read_text(encoding="utf-8"))


class Fixturerna(unittest.TestCase):
    def test_passen_ar_pythons_tal(self) -> None:
        for namn in GT.PASSEN:
            fx = _las(namn)
            self.assertEqual(set(fx["varianter"]), set(GT.PASSEN[namn][1]), namn)
            for v, r in GT.rakna_om(fx, Path(TMP.name)).items():
                f = lika(r["python"], fx["varianter"][v]["python"], f"{namn}/{v}")
                f += lika(r["inre"], fx["varianter"][v]["inre"], f"{namn}/{v} inre")
                self.assertEqual(f, [], "kör python3 tools/pc/generera_tre_d.py")

    def test_parningen_ar_pythons(self) -> None:
        fx = _las("parning")
        for namn, p in fx["pass"].items():
            for v, r in p["varianter"].items():
                ny = GT._rena(GT._rakna_parning(p, v, Path(TMP.name)))
                self.assertEqual(lika(ny, {"par": r["par"], "info": r["info"]}, f"{namn}/{v}"), [])

    def test_delstegen_ar_pythons(self) -> None:
        k = _las("komponenter")
        ny = GT.komponenter(_las(k["pass"]), Path(TMP.name))
        self.assertEqual(lika(ny, {x: y for x, y in k.items() if x not in ("om", "pass")}), [])

    def test_kompakta_lederna_ar_paketets(self) -> None:
        js = {"width": 1080, "height": 1920, "frames": [
            {"t": -1.2345, "pts": 0.0, "joints": [None, {"x": 540.1, "y": 1919.9, "c": 0.02}] + [None] * 11,
             "confidence": 0.9}]}
        tillbaka = GT.ur_kompakt(GT.kompakt(js))
        self.assertEqual(tillbaka["frames"][0]["t"], -1.2345)
        self.assertEqual(tillbaka["frames"][0]["joints"][1], {"x": 540.1, "y": 1919.9, "c": 0.02})
        self.assertIsNone(tillbaka["frames"][0]["joints"][0])

    def test_urvalet_ar_jamnt_och_heltal(self) -> None:
        # Samma index i Swift (TvaKameror.urval). METOD M50, BESLUT B48
        self.assertEqual(TK.urval(10, 4).tolist(), [0, 2, 5, 7])
        self.assertEqual(int(TK.urval(18_731, 5000)[-1]), 18_727)


if __name__ == "__main__":
    unittest.main()
