"""S7-märkverktyget (METOD MF5–MF6): rutvalet på påhittade paket, formatet, sidan
(genereras och JS parsar, om node finns) och servern som sparar."""
from __future__ import annotations

import json
import re
import shutil
import subprocess
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path

import numpy as np

import _hjalp  # noqa: F401
from pc import markera_klubba as MK
from pc import paket as P
from test_s3_facit import PASS, UTSNITT, paketen


class Rutvalet(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.paket = [(f, P.las(f)) for f in paketen()[0]]
        cls.rutor = MK.valj_rutor(cls.paket, slag_per_paket=2, jamna=2)

    def test_rutorna_per_slag_och_vy(self) -> None:
        r = self.rutor
        self.assertEqual(len({x["id"] for x in r}), len(r))
        # Slag 1 och 3 av 3 i båda vyerna; fem rutor per slag.
        self.assertEqual(sorted({(x["vy"], x["slag"]) for x in r}),
                         [("dtl", "s01"), ("dtl", "s03"), ("fo", "s01"), ("fo", "s03")])
        for (vy, slag) in {(x["vy"], x["slag"]) for x in r}:
            mina = [x for x in r if x["vy"] == vy and x["slag"] == slag]
            self.assertEqual([x["val"] for x in mina], ["adress", "topp", "tidig_nedsving", "jamn", "jamn"])
            t = {x["val"]: x["t"] for x in mina if x["val"] != "jamn"}
            self.assertLess(t["adress"], t["topp"])
            self.assertLess(t["topp"], t["tidig_nedsving"])
            self.assertLess(t["tidig_nedsving"], 0.0)          # före träffen

    def test_rutorna_ar_visions_och_inom_klippet(self) -> None:
        for x in self.rutor:
            _, p = next(q for q in self.paket if q[1].fil == x["fil"])
            s = next(y for y in p.slag if y.id == x["slag"])
            ruta = next(f for f in s.lederna["frames"] if round(f["t"], 4) == x["t"])
            self.assertTrue(P.i_klippet(s, x["t_klipp"]))
            self.assertAlmostEqual(x["t_klipp"], x["t"] + 2.5, places=3)
            # Greppets förslag: handledernas mitt, eller den som syns (FO döljer ibland den främre).
            hander = [j for j in (ruta["joints"][5], ruta["joints"][6]) if j]
            g = x["forslag"]["grepp"]
            self.assertAlmostEqual(g["x"], sum(h["x"] for h in hander) / len(hander), delta=0.06)
            self.assertAlmostEqual(g["y"], sum(h["y"] for h in hander) / len(hander), delta=0.06)
            # Utsnittet vidgat med 15 % per sida, inom bilden.
            ux, uy, ub, uh = P.utsnitt_px(tuple(UTSNITT.values()), 1080, 1920)
            vx, vy, vb, vh = x["visad"]
            self.assertLess(vx, ux)
            self.assertEqual((vy, vy + vh), (0, 1920))
            self.assertLessEqual(vx + vb, 1080)
        self.assertEqual(MK.kontrollera(MK.ny(self.rutor, ["a.zip"], PASS)), [])

    def test_slagen_sprids(self) -> None:
        self.assertEqual(MK.valj_slag(10, 6)[0], 0)
        self.assertEqual(MK.valj_slag(10, 6)[-1], 9)
        self.assertEqual(len(MK.valj_slag(10, 6)), 6)
        self.assertEqual(MK.valj_slag(2, 6), [0, 1])
        self.assertEqual(MK.valj_slag(0, 6), [])

    def test_bilderna_ar_den_visade_delen(self) -> None:
        sett = []

        def las_bild(klipp, t, b, h):
            sett.append((Path(klipp).suffix, t))
            return np.full((h, b, 3), 128, np.uint8)

        kallor = {f.name: f for f, _ in self.paket}
        b = MK.bilder(self.rutor[:3], kallor, las_bild, rapport=None)
        self.assertEqual(set(b), {x["id"] for x in self.rutor[:3]})
        self.assertTrue(all(v.startswith("data:image/") for v in b.values()))
        self.assertEqual(sett[0], (".mov", self.rutor[0]["t_klipp"]))


def _markering(n: int = 2) -> dict:
    rutor = MK.valj_video(Path("x.mov"), 4.0, 1080, 1920, "fo", n)
    return MK.ny(rutor, ["x.mov"], None)


class Formatet(unittest.TestCase):
    def test_tur_och_retur(self) -> None:
        d = _markering()
        r = d["rutor"][0]
        r["punkter"] = {"grepp": {"x": 500.0, "y": 900.5, "kalla": "klick"}, "skaft_mitt": {"syns_inte": True},
                        "klubbhuvud": {"x": 420.0, "y": 1300.0, "kalla": "forslag"}}
        r["status"] = "markerad"
        d["rutor"][1]["status"] = "hoppad"
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp) / "m.json"
            MK.skriv(f, d)
            self.assertEqual(MK.las(f), d)

    def test_felen_namner_falt_inte_varden(self) -> None:
        d = _markering()
        r = d["rutor"][0]
        r["status"] = "markerad"                                          # punkterna saknas
        d["rutor"][1]["punkter"]["grepp"] = {"x": 123456.7, "y": 1.0, "kalla": "klick"}   # utanför bilden
        d["rutor"].append(dict(d["rutor"][0]))                            # samma id
        fel = MK.kontrollera(d)
        text = "; ".join(fel)
        self.assertIn("rutor[0].punkter.grepp saknas i en markerad ruta", text)
        self.assertIn("rutor[1].punkter.grepp ligger utanför bilden", text)
        self.assertIn("rutor[2].id finns två gånger", text)
        self.assertNotIn("123456", text)
        d2 = _markering()
        d2["rutor"][0]["punkter"]["grepp"] = {"x": 1.0, "y": 1.0, "kalla": "gissning"}
        self.assertTrue(MK.kontrollera(d2))
        with self.assertRaises(MK.MarkFel):
            MK.skriv(Path(tempfile.gettempdir()) / "aldrig.json", d)

    def test_tidigare_markering_behalls(self) -> None:
        gammal = _markering(3)
        gammal["rutor"][1]["status"] = "hoppad"
        extra = dict(gammal["rutor"][2], id="video-99")
        gammal["rutor"].append(extra)
        ny = MK.sla_ihop(_markering(3), gammal)
        self.assertEqual(ny["rutor"][1]["status"], "hoppad")
        self.assertEqual(ny["rutor"][-1]["id"], "video-99")
        self.assertEqual(MK.kontrollera(ny), [])


class Sidan(unittest.TestCase):
    def test_sidan_genereras_och_js_parsar(self) -> None:
        d = _markering()
        d["rutor"][0]["forslag"] = {"grepp": {"x": 1.0, "y": 2.0, "kalla": "handlederna"}}
        d["kalla"] = ["</script><b>"]                                      # får inte bryta sidan
        html = MK.sida(d, {"video-01": MK.koda(np.zeros((4, 3, 3), np.uint8))}, True, "m.json")
        for namn in ("data", "bilder", "lage"):
            m = re.search(rf'<script type="application/json" id="{namn}">(.*?)</script>', html, re.S)
            self.assertIsNotNone(m, namn)
            json.loads(m.group(1))
        self.assertEqual(json.loads(re.search(r'id="data">(.*?)</script>', html, re.S).group(1)), d)
        skript = re.findall(r"<script>(.*?)</script>", html, re.S)
        self.assertEqual(len(skript), 1)
        self.assertNotIn("http://", skript[0])
        self.assertNotIn("https://", html)
        node = shutil.which("node")
        if node is None:
            self.skipTest("node saknas: bara sidans form provad")
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp) / "sida.js"
            f.write_text(skript[0], encoding="utf-8")
            r = subprocess.run([node, "--check", str(f)], capture_output=True, text=True, timeout=30)
            self.assertEqual(r.returncode, 0, r.stderr)

    def test_servern_sparar_och_stanger(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            fil = Path(tmp) / "m.json"
            d = _markering()
            srv = MK.server("<html></html>", fil)
            tr = threading.Thread(target=srv.serve_forever, daemon=True)
            tr.start()
            bas = f"http://127.0.0.1:{srv.server_address[1]}"
            try:
                self.assertEqual(urllib.request.urlopen(bas + "/", timeout=5).read(), b"<html></html>")
                d["rutor"][0]["status"] = "hoppad"
                req = urllib.request.Request(bas + "/spara", data=json.dumps(d).encode(), method="POST")
                self.assertEqual(urllib.request.urlopen(req, timeout=5).status, 200)
                self.assertEqual(MK.las(fil)["rutor"][0]["status"], "hoppad")
                d["rutor"][0]["status"] = "markerad"                      # utan punkter: fel
                req = urllib.request.Request(bas + "/spara", data=json.dumps(d).encode(), method="POST")
                with self.assertRaises(urllib.error.HTTPError) as e:
                    urllib.request.urlopen(req, timeout=5)
                self.assertEqual(e.exception.code, 400)
                self.assertEqual(MK.las(fil)["rutor"][0]["status"], "hoppad")
                urllib.request.urlopen(urllib.request.Request(bas + "/klar", data=b"", method="POST"), timeout=5)
                tr.join(5)
                self.assertFalse(tr.is_alive())
            finally:
                srv.server_close()


if __name__ == "__main__":
    unittest.main()
