"""S7-märkverktyget (METOD MF5–MF6): rutvalet på påhittade paket med S3:s förskjutning,
formatet, sidan (genereras och JS parsar, om node finns) och servern som sparar och
bara svarar med nyckeln."""
from __future__ import annotations

import contextlib
import http.client
import io
import json
import re
import shutil
import subprocess
import tempfile
import threading
import unittest
from pathlib import Path

import numpy as np

import _hjalp  # noqa: F401
from pc import markera_klubba as MK
from pc import paket as P
from test_s3_facit import OFF, PASS, UTSNITT, paketen

DELTA_MS = -OFF * 1000


class Rutvalet(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.paket = [(f, P.las(f)) for f in paketen()[0]]
        cls.fsk = {(p.fil, s.id): DELTA_MS for _, p in cls.paket for s in p.slag}
        cls.rutor = MK.valj_rutor(cls.paket, cls.fsk, slag_per_paket=2, jamna=2)

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

    def test_bara_slag_med_s3s_forskjutning(self) -> None:
        fsk = {k: v for k, v in self.fsk.items() if k[1] != "s01"}
        r = MK.valj_rutor(self.paket, fsk, slag_per_paket=6, jamna=0)
        self.assertNotIn("s01", {x["slag"] for x in r})
        self.assertEqual(MK.valj_rutor(self.paket, {}, slag_per_paket=6), [])
        s3 = {"slag": [{"fil": "a.zip", "id": "s01", "tidsparning": {"forskjutning_ms": -2.5}},
                       {"fil": "a.zip", "id": "s02", "tidsparning": {"forskjutning_ms": 1.0}, "hoppat": "tvetydig"},
                       {"fil": "a.zip", "id": "s03", "hoppat": "inget klipp i paketet"}]}
        self.assertEqual(MK.forskjutningar(s3), {("a.zip", "s01"): -2.5})

    def test_rutorna_ar_visions_och_inom_klippet(self) -> None:
        for x in self.rutor:
            _, p = next(q for q in self.paket if q[1].fil == x["fil"])
            s = next(y for y in p.slag if y.id == x["slag"])
            ruta = next(f for f in s.lederna["frames"] if round(f["t"], 4) == x["t"])
            self.assertTrue(P.i_klippet(s, x["t_klipp"]))
            self.assertAlmostEqual(x["t_klipp"], x["t"] + s.klick_i_klipp_s, places=4)
            self.assertEqual(x["forskjutning_ms"], DELTA_MS)
            # Greppets ledtråd: handledernas mitt, eller den som syns (FO döljer ibland den främre).
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
            self.assertTrue(all(v is None for v in x["punkter"].values()))
        self.assertEqual(MK.kontrollera(MK.ny(self.rutor, ["a.zip"], PASS)), [])

    def test_slagen_sprids(self) -> None:
        self.assertEqual(MK.valj_slag(10, 6)[0], 0)
        self.assertEqual(MK.valj_slag(10, 6)[-1], 9)
        self.assertEqual(len(MK.valj_slag(10, 6)), 6)
        self.assertEqual(MK.valj_slag(2, 6), [0, 1])
        self.assertEqual(MK.valj_slag(0, 6), [])

    def test_bilderna_las_pa_forskjutna_tiden(self) -> None:
        anrop = []

        def las_vid(klipp, tider, b, h, tol):
            anrop.append((Path(klipp).suffix, list(tider), tol))
            return {t: (t + 0.0001, np.full((h // 10, b // 10, 3), 128, np.uint8)) for t in tider}

        kallor = {f.name: f for f, _ in self.paket}
        rutor = [dict(x) for x in self.rutor[:5]]            # ett slag
        b = MK.bilder(rutor, kallor, las_vid, rapport=None)
        self.assertEqual(set(b), {x["id"] for x in rutor})
        self.assertTrue(all(v.startswith("data:image/") for v in b.values()))
        self.assertEqual(len(anrop), 1)                       # klippet läses en gång
        suffix, tider, tol = anrop[0]
        self.assertEqual(suffix, ".mov")
        self.assertEqual(tol, MK.TID_TOL_S)
        self.assertEqual(sorted(tider), sorted(x["t_klipp"] + DELTA_MS / 1000 for x in rutor))
        self.assertEqual([x["t_klipp"] for x in rutor], [x["t_klipp"] for x in self.rutor[:5]])
        for x in rutor:                                       # rutans egen tid, för sig
            self.assertAlmostEqual(x["t_ruta"], x["t_klipp"] + DELTA_MS / 1000 + 0.0001, places=6)

    def test_utan_s3_sager_kommandot_vad_som_saknas(self) -> None:
        buf = io.StringIO()
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(buf):
            ut = str(Path(tmp) / "m.json")
            self.assertEqual(MK.main([str(self.paket[0][0]), "--ut", ut, "--s3", str(Path(tmp) / "s3.json")]), 1)
        self.assertIn("Kör S3 först", buf.getvalue())
        self.assertIn("s3_facit.py", buf.getvalue())


def _markering(n: int = 2) -> dict:
    rutor = MK.valj_video(Path("x.mov"), 4.0, 1080, 1920, "fo", n)
    return MK.ny(rutor, ["x.mov"], None)


class Formatet(unittest.TestCase):
    def test_tur_och_retur(self) -> None:
        d = _markering()
        r = d["rutor"][0]
        r["punkter"] = {"grepp": {"x": 500.0, "y": 900.5, "kalla": "klick"}, "skaft_mitt": {"syns_inte": True},
                        "klubbhuvud": {"x": 420.0, "y": 1300.0, "kalla": "klick"}}
        r["status"] = "markerad"
        d["rutor"][1]["status"] = "hoppad"
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp) / "m.json"
            MK.skriv(f, d)
            self.assertEqual(MK.las(f), d)
            self.assertEqual([p.name for p in Path(tmp).iterdir()], ["m.json"])     # inga temporära kvar

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
        with self.assertRaises(MK.MarkFel):
            MK.skriv(Path(tempfile.gettempdir()) / "aldrig.json", d)

    def test_ledtraden_ar_aldrig_en_markering(self) -> None:
        d = _markering()
        d["rutor"][0]["punkter"]["grepp"] = {"x": 1.0, "y": 1.0, "kalla": "forslag"}
        self.assertTrue(any("punkter.grepp" in f for f in MK.kontrollera(d)))
        self.assertNotIn('kalla: "forslag"', MK.SKRIPT)

    def test_video_ateruppttagen_hittar_rutorna(self) -> None:
        # Läsaren ger rutan närmast den valda tiden, upp till en halv ruta bort.
        def las_vid(klipp, tider, b, h, tol):
            return {t: (t + 0.4 / 240, np.zeros((4, 3, 3), np.uint8)) for t in tider}

        forsta = _markering(24)
        MK.bilder(forsta["rutor"], {"x.mov": Path("x.mov")}, las_vid, rapport=None, tol_video=0.5 / 240)
        for r in forsta["rutor"]:
            r["status"] = "hoppad"
        andra = _markering(24)
        MK.bilder(andra["rutor"], {"x.mov": Path("x.mov")}, las_vid, rapport=None, tol_video=0.5 / 240)
        ny = MK.sla_ihop(andra, forsta)
        self.assertEqual(len(ny["rutor"]), 24)
        self.assertTrue(all(r["status"] == "hoppad" for r in ny["rutor"]))

    def test_ny_forskjutning_ar_en_ny_ruta(self) -> None:
        gammal = _markering(2)
        gammal["rutor"][0]["status"] = "hoppad"
        ny = _markering(2)
        ny["rutor"][0]["forskjutning_ms"] = 4.2
        ihop = MK.sla_ihop(ny, gammal)
        self.assertEqual(ihop["rutor"][0]["status"], "omarkerad")
        self.assertEqual(ihop["rutor"][-1]["status"], "hoppad")
        self.assertEqual(len(ihop["rutor"]), 3)

    def test_tidigare_markering_behalls(self) -> None:
        gammal = _markering(3)
        gammal["rutor"][1]["status"] = "hoppad"
        gammal["rutor"][2]["t_klipp"] += 0.5                               # samma id, en annan ruta
        gammal["rutor"][2]["status"] = "hoppad"
        ny = MK.sla_ihop(_markering(3), gammal)
        self.assertEqual(ny["rutor"][1]["status"], "hoppad")              # samma id, fil och tid
        self.assertEqual(ny["rutor"][2]["status"], "omarkerad")           # nya rutan får inte den gamlas
        self.assertEqual(ny["rutor"][2]["id"], "video-03-2")
        self.assertEqual(ny["rutor"][-1], gammal["rutor"][2])             # den gamla sist, oförändrad
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


class Servern(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.fil = Path(self.tmp.name) / "m.json"
        self.srv = MK.server("<html></html>", self.fil)
        self.port = self.srv.server_address[1]
        self.tr = threading.Thread(target=self.srv.serve_forever, kwargs={"poll_interval": 0.02}, daemon=True)
        self.tr.start()

    def tearDown(self) -> None:
        self.srv.shutdown()
        self.srv.server_close()
        self.tmp.cleanup()

    def _anrop(self, metod: str, vag: str, kropp: bytes | None = None, nyckel: bool = True, host: str | None = None,
               typ: str | None = "application/json", langd: str | None = "auto") -> tuple[int, bytes]:
        c = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        c.putrequest(metod, vag + (f"?k={self.srv.nyckel}" if nyckel else ""), skip_host=True,
                     skip_accept_encoding=True)
        c.putheader("Host", host or f"127.0.0.1:{self.port}")
        if typ:
            c.putheader("Content-Type", typ)
        if kropp is not None and langd is not None:
            c.putheader("Content-Length", str(len(kropp)) if langd == "auto" else langd)
        c.endheaders()
        if kropp:
            c.send(kropp)
        r = c.getresponse()
        svar = (r.status, r.read())
        c.close()
        return svar

    def test_sparar_med_nyckeln(self) -> None:
        self.assertEqual(self._anrop("GET", "/", typ=None), (200, b"<html></html>"))
        d = _markering()
        d["rutor"][0]["status"] = "hoppad"
        self.assertEqual(self._anrop("POST", "/spara", json.dumps(d).encode())[0], 200)
        self.assertEqual(MK.las(self.fil)["rutor"][0]["status"], "hoppad")
        d["rutor"][0]["status"] = "markerad"                              # utan punkter: fel
        self.assertEqual(self._anrop("POST", "/spara", json.dumps(d).encode())[0], 400)
        self.assertEqual(MK.las(self.fil)["rutor"][0]["status"], "hoppad")
        self.assertEqual(self._anrop("POST", "/klar", b"{}")[0], 200)
        self.tr.join(5)
        self.assertFalse(self.tr.is_alive())

    def test_nekar_utan_nyckel_fel_host_och_typ(self) -> None:
        d = json.dumps(_markering()).encode()
        self.assertEqual(self._anrop("GET", "/", typ=None, nyckel=False)[0], 403)
        self.assertEqual(self._anrop("POST", "/spara", d, nyckel=False)[0], 403)        # CSRF utan nyckel
        self.assertEqual(self._anrop("POST", "/spara", d, host="evil.example:80")[0], 403)
        self.assertEqual(self._anrop("POST", "/spara", d, typ="text/plain")[0], 415)
        self.assertEqual(self._anrop("POST", "/spara", d, langd="-5")[0], 400)
        self.assertEqual(self._anrop("POST", "/spara", d, langd=None)[0], 411)
        self.assertFalse(self.fil.exists())

    def test_samtidiga_sparningar_blandas_inte(self) -> None:
        d = _markering(40)
        fel = []

        def spara(k):
            dd = json.loads(json.dumps(d))
            dd["rutor"][k]["status"] = "hoppad"
            if self._anrop("POST", "/spara", json.dumps(dd).encode())[0] != 200:
                fel.append(k)

        tr = [threading.Thread(target=spara, args=(k,)) for k in range(8)]
        for t in tr:
            t.start()
        for t in tr:
            t.join(10)
        self.assertEqual(fel, [])
        self.assertEqual(sum(r["status"] == "hoppad" for r in MK.las(self.fil)["rutor"]), 1)
        self.assertEqual([p.name for p in Path(self.tmp.name).iterdir()], ["m.json"])


if __name__ == "__main__":
    unittest.main()
