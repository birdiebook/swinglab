"""S6c-1: fixturerna för 3D på telefonen är fortfarande Pythons tal (BESLUT B12, B48).

`tools/pc/generera_tre_d.py` skriver påhittade tvåpaketspass och Pythons `tre_d` till
tools/tests/fixturer/tre_d/, som SwingLabKit:s TreDTests jämför med. Här räknas de om ur
fixturens egna indata (parallellt, ett pass spår och vikter en gång): ändras kedjan i
Python ska fixturerna skrivas om, annars prövar Swift mot gamla tal. Talen jämförs inom
1e-9 (en annan dator kan ge andra sista bitar ur BLAS). Inga riktiga leder (CLAUDE.md,
Dataregeln).
"""
from __future__ import annotations

import json
import sys
import tempfile
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from pc import generera_tre_d as GT  # noqa: E402
from pc import paket as P  # noqa: E402
from pc import tva_kameror as TK  # noqa: E402

TMP = tempfile.TemporaryDirectory()


class Fixturerna(unittest.TestCase):
    def test_passen_ar_pythons_tal(self) -> None:
        for namn, (indata, varianter) in GT.FACIT.items():
            fx = GT.las(namn)
            self.assertEqual(fx["indata"], indata, namn)
            self.assertEqual(set(fx["varianter"]), set(varianter), namn)
        # Varianterna och delstegen (komponenter.json) räknas om parallellt.
        start = time.time()
        fel = GT.rakna_om()
        print(f"TRED-PY omräkningen {time.time() - start:.1f} s", file=sys.stderr)
        self.assertEqual(fel, [], "kör python3 tools/pc/generera_tre_d.py")

    def test_parningen_ar_pythons(self) -> None:
        fx = GT.las("parning")
        for namn, p in fx["pass"].items():
            for v, r in p["varianter"].items():
                dtl, fo = GT.paketen({"namn": namn, "paket": p["paket"]}, r["andra"], Path(TMP.name), med_leder=False)
                par, info = TK.para_slag(dtl, fo)
                ny = GT._rena({"par": [[a.id, b.id] for a, b in par], "info": info})
                self.assertEqual(GT.lika(ny, {"par": r["par"], "info": r["info"]}, f"{namn}/{v}"), [])
        # Paketen i fel ordning: ett fel, inte en tyst parning (BESLUT B48).
        with self.assertRaises(TK.TreDFel):
            TK.para_slag(fo, dtl)

    def test_manifestens_fel_ar_pythons(self) -> None:
        fx = GT.las("manifest_fel")
        for f in fx["fall"]:
            self.assertEqual(P._kontrollera_manifest(json.loads(f["manifest"]), set(fx["filer"])), f["fel"], f["namn"])
            self.assertTrue(f["fel"], f["namn"])

    def test_kompakta_lederna_ar_paketets(self) -> None:
        js = {"width": 1080, "height": 1920, "frames": [
            {"t": -1.2345, "pts": 0.0, "joints": [None, {"x": 540.1, "y": 1919.9, "c": 0.02}] + [None] * 11,
             "confidence": 0.9}]}
        tillbaka = GT.ur_kompakt(GT.kompakt(js))
        self.assertEqual(tillbaka["frames"][0]["t"], -1.2345)
        self.assertEqual(tillbaka["frames"][0]["joints"][1], {"x": 540.1, "y": 1919.9, "c": 0.02})
        self.assertIsNone(tillbaka["frames"][0]["joints"][0])

    def test_urvalet_ar_en_permutation(self) -> None:
        # Samma index i Swift (TvaKameror.urval). METOD M50, BESLUT B48
        self.assertEqual(TK.urval(10, 4).tolist(), [0, 7, 4, 1])
        v = TK.urval(18_731, 5000)
        self.assertEqual(len(set(v.tolist())), 5000)
        self.assertEqual(v[:3].tolist(), [0, 11_576, 4_421])
        self.assertEqual(sorted(TK.urval(26, 26).tolist()), list(range(26)))

    def test_tidsspannet_och_parens_vyer(self) -> None:
        self.assertEqual(TK.utelamnat(TK.np.array([0.0] * 9)), "för få rutor")
        self.assertIn("orimligt", TK.utelamnat(TK.np.array([0.0] * 9 + [31.0])))
        self.assertIn("orimligt", TK.utelamnat(TK.np.array([0.0] * 9 + [float("nan")])))
        self.assertIsNone(TK.utelamnat(TK.np.linspace(0, 3, 50)))


if __name__ == "__main__":
    unittest.main()
