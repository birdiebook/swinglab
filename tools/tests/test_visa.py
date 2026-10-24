"""S6f: visaren (tools/pc/visa.py) på påhittade pass ur generera_paket.tva_paket.

Sidan ska byggas och vara giltig, bära figuren, kamerorna och måtten, och fungera när
3D hoppas över: över spärren (kamerorna och figuren ritas ändå, märkta) och med två
paket märkta samma vy (som första riktiga passet). Inga riktiga leder (CLAUDE.md,
Dataregeln).
"""
from __future__ import annotations

import functools
import io
import json
import math
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile
from contextlib import redirect_stdout
from html.parser import HTMLParser
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from pc import generera_paket as G  # noqa: E402
from pc import paket as P  # noqa: E402
from pc import tva_kameror as TK  # noqa: E402
from pc import visa as V  # noqa: E402

TMP = tempfile.TemporaryDirectory()
LANGD = 1.80
VOIDA = {"meta", "link", "input", "br", "img", "hr", "source", "track", "wbr", "area", "base", "col", "embed", "param"}


@functools.lru_cache(maxsize=None)
def _pass(namn: str, **kw):
    return G.tva_paket(Path(TMP.name) / namn, kw.pop("pass_id"), **kw)


@functools.lru_cache(maxsize=None)
def _data(namn: str, **kw) -> tuple[dict, dict]:
    d, f, facit = _pass(namn, **kw)
    ut = Path(TMP.name) / f"ut-{namn}"
    return V.data([d, f], [P.las(d), P.las(f)], LANGD, None, ut), facit


def _bra():
    return _data("bra", pass_id="20261103-180000", n=10, seed=5, brus="bra")


def _sparren():
    # Mycket dåligt brus: Sampson-felet över spärren (METOD MK3), som fixturen tre_d/sparren.
    return _data("sparren", pass_id="20261104-180000", n=4, seed=3, brus="mycket_daligt")


def _projicera(kam: dict, K: list, X: np.ndarray) -> np.ndarray:
    """Som sidans projicera(): K · R · (X − C)."""
    c = (X - np.array(kam["C"])) @ np.array(kam["R"]).T
    x = c @ np.array(K).T
    return x[..., :2] / x[..., 2:3]


class Giltig(HTMLParser):
    """Taggarna ska gå jämnt ut; skripten och datan samlas."""

    def __init__(self):
        super().__init__()
        self.stack, self.fel, self.skript, self._i = [], [], [], None

    def handle_starttag(self, tag, attrs):
        if tag not in VOIDA:
            self.stack.append(tag)
        if tag == "script":
            self._i = dict(attrs)
            self.skript.append([self._i, ""])

    def handle_endtag(self, tag):
        if not self.stack or self.stack[-1] != tag:
            self.fel.append(tag)
        else:
            self.stack.pop()

    def handle_data(self, data):
        if self.stack and self.stack[-1] == "script":
            self.skript[-1][1] += data


def _las_sidan(text: str) -> tuple[Giltig, dict]:
    g = Giltig()
    g.feed(text)
    g.close()
    data = next(json.loads(s) for a, s in g.skript if a.get("id") == "data")
    return g, data


class TestSidan(unittest.TestCase):
    def test_sidan_ar_giltig_och_bar_datan(self):
        d, _ = _bra()
        text = V.html(d)
        g, data = _las_sidan(text)
        self.assertEqual(g.fel, [])
        self.assertEqual(g.stack, [])
        self.assertNotIn("{{", text)
        self.assertEqual(data["format"], V.FORMAT)
        self.assertEqual(data["pass"], "20261103-180000")
        # three.js från cdnjs med exakt version, och sidans eget skript efter det
        src = [a["src"] for a, _ in g.skript if a.get("src")]
        self.assertEqual(src, [V.THREE_JS])
        self.assertRegex(V.THREE_JS, r"^https://cdnjs\.cloudflare\.com/ajax/libs/three\.js/r\d+/three\.min\.js$")

    @unittest.skipUnless(shutil.which("node"), "node saknas")
    def test_skriptet_gar_att_tolka(self):
        g, _ = _las_sidan(V.html(_bra()[0]))
        egna = [s for a, s in g.skript if not a.get("src") and a.get("type") != "application/json"]
        self.assertEqual(len(egna), 1)
        fil = Path(TMP.name) / "visa.js"
        fil.write_text(egna[0], encoding="utf-8")
        r = subprocess.run(["node", "--check", str(fil)], capture_output=True, text=True, timeout=60)
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_figuren_utan_nan_och_etiketterna_i_skarmens_storlek(self):
        """Saknade leder ritas inte i stället för att bli NaN i bufferten (three.js räknade
        en NaN-sfär, första riktiga passet), och kamerornas etiketter har en fast storlek på
        skärmen, FO:s över och DTL:s under, så att de inte täcker varandra."""
        g, _ = _las_sidan(V.html(_bra()[0]))
        skript = next(s for a, s in g.skript if not a.get("src") and a.get("type") != "application/json")
        self.assertNotIn("NaN", re.sub(r"//.*", "", skript))
        self.assertEqual(len(re.findall(r"setDrawRange\(0, n\)", skript)), 2)
        self.assertIn("sizeAttenuation: false", skript)
        self.assertIn('vy === "dtl"', skript)

    def test_figuren_kamerorna_och_matten(self):
        d, facit = _bra()
        t = d["tre_d"]
        self.assertIsNone(t["hoppat"])
        self.assertEqual(len(t["uppstallningar"]), 1)
        u = t["uppstallningar"][0]
        self.assertIsNone(u["hoppat"])
        self.assertLessEqual(u["sampson_px"], TK.SAMPSON_MAX_PX)
        # vinkeln mellan kamerorna är uppställningens (90° i den påhittade)
        self.assertAlmostEqual(u["vinkel_mellan_kamerorna"], facit["vinkel_mellan_kamerorna"], delta=5)
        self.assertEqual(set(u["kameror"]), {"fo", "dtl"})
        # alla parade slag har en figur, och måtten per sving är kedjans
        self.assertEqual({(p["dtl"], p["fo"]) for p in t["par"]}, {(x["dtl"], x["fo"]) for x in facit["slag"]})
        for p in t["par"]:
            self.assertEqual(len(p["t"]), len(p["P"]))
            self.assertTrue(all(len(r) == 3 * len(d["leder"]) for r in p["P"]))
            self.assertEqual(set(p["matt"]), set(TK.MATT))
        self.assertEqual(set(t["session"]), set(TK.MATT))
        # 2D-måtten per vy och P-positionerna står på raderna
        parade = [r for r in d["rader"] if r["par"] is not None]
        self.assertEqual(len(parade), len(facit["slag"]))
        for r in parade:
            self.assertEqual([v and v["id"] for v in r["vyer"]], [t["par"][r["par"]]["dtl"], t["par"][r["par"]]["fo"]])
            for v in r["vyer"]:
                self.assertIn("backen_sway_topp" if v is r["vyer"][1] else "brost_bojning_adress", v["matt"])
                self.assertIn("P4", v["positioner"])
        # det enda oparade slaget (bara FO) står kvar som en egen rad
        self.assertEqual([r["vyer"][0] for r in d["rader"] if r["par"] is None], [None])

    def test_figuren_projicerad_ligger_pa_lederna(self):
        """Kvittot på att sidans projicering får rätt kameror: figuren tillbaka i båda
        bilderna ligger nära Visions leder (medianen inom några px), på samma tid."""
        d, _ = _bra()
        t = d["tre_d"]
        u = t["uppstallningar"][0]
        for r in [r for r in d["rader"] if r["par"] is not None][:3]:
            p = t["par"][r["par"]]
            X = np.array([[np.nan if v is None else v for v in rad] for rad in p["P"]]).reshape(len(p["P"]), -1, 3)
            for vy, v, K in (("dtl", r["vyer"][0], p["KB"]), ("fo", r["vyer"][1], p["KA"])):
                uv = _projicera(u["kameror"][vy], K, X)
                fel = []
                for k in range(0, len(p["t"]), 10):
                    i = int(np.argmin(np.abs(np.array(v["t"]) - (p["t"][k] + v["t0"]))))
                    xy = np.array([np.nan if a is None else a for a in v["xy"][i]], float).reshape(-1, 2)
                    e = np.hypot(*(uv[k] - xy).T)
                    fel += [x for x in e if math.isfinite(x)]
                self.assertLess(float(np.median(fel)), 6.0, f"{r['namn']} {vy}")

    def test_skalan_ar_figurens_langd(self):
        d, _ = _bra()
        t = d["tre_d"]
        self.assertEqual(t["uppstallningar"][0]["skala"], "langd")
        X = np.array([[np.nan if v is None else v for v in rad] for p in t["par"] for rad in p["P"]]).reshape(-1, 13, 3)
        hojd = X[:, V.NASA, 2] - np.nanmean(X[:, V.FOTLEDER, 2], axis=1)
        self.assertAlmostEqual(float(np.nanmedian(hojd)), V.NASA_OVER_FOTLED * LANGD, delta=0.01)


class TestHoppat(unittest.TestCase):
    def test_over_sparren_ritas_anda(self):
        d, _ = _sparren()
        t = d["tre_d"]
        self.assertIsNotNone(t["hoppat"])
        u = t["uppstallningar"][0]
        self.assertGreater(u["sampson_px"], TK.SAMPSON_MAX_PX)
        self.assertIn("spärren", u["hoppat"])
        self.assertEqual(set(u["kameror"]), {"fo", "dtl"})
        self.assertTrue(t["par"])
        self.assertTrue(all(p["matt"] == {} for p in t["par"]))      # inga mått över spärren
        self.assertTrue(any(v is not None for p in t["par"] for rad in p["P"] for v in rad))
        g, data = _las_sidan(V.html(d))
        self.assertEqual(g.fel, [])
        self.assertEqual(data["tre_d"]["hoppat"], t["hoppat"])

    def test_kedjans_skal_per_uppstallning(self):
        """Stannar kedjan i kalibreringen säger visaren kedjans skäl, inte ett eget ur en
        omräkning på klicket (första riktiga passet: kedjan sade 'kamerorna står för nära
        samma riktning', visaren 'Sampson-felet är över spärren')."""
        d, f, _ = _pass("bra", pass_id="20261103-180000", n=10, seed=5, brus="bra")
        skal = "kalibreringen: kamerorna står för nära samma riktning"
        orig = TK._uppstallning

        def stopp(dtl, fo, grupp, rad, inre=None):
            if inre is not None:
                inre.append(None)
            return {"serie": {"dtl": grupp[0]["dtl"].serie, "fo": grupp[0]["fo"].serie}, "slag": len(grupp),
                    "hoppat": skal}, []
        TK._uppstallning = stopp
        try:
            t = V.data([d, f], [P.las(d), P.las(f)], LANGD, None, Path(TMP.name) / "ut-kedjans-skal")["tre_d"]
        finally:
            TK._uppstallning = orig
        self.assertEqual(t["hoppat"], skal)
        u = t["uppstallningar"][0]
        self.assertEqual(u["hoppat"], skal)
        self.assertEqual(u["synk"], "klicket")          # kedjan kom inte till synken
        self.assertEqual(t["parning"]["par"], 10)        # parningen ur kedjan, inte räknad om

    def test_tva_paket_med_samma_vy(self):
        """Som första riktiga passet: FO-telefonen märkt DTL. Ingen 3D, skälet säger
        varför, båda klippen visas i den ordning de gavs."""
        d, f, _ = _pass("bra", pass_id="20261103-180000", n=10, seed=5, brus="bra")
        fel = Path(TMP.name) / "felmarkt" / f.name.replace("-fo", "-fo-markt-dtl")
        fel.parent.mkdir(parents=True, exist_ok=True)
        _skriv_om(f, fel, lambda m: m.update(vy="dtl"))
        ut = Path(TMP.name) / "ut-felmarkt"
        with redirect_stdout(io.StringIO()) as o:
            self.assertEqual(V.main([str(d), str(fel), "--ut", str(ut), "--langd", "1.8"]), 0)
        self.assertIn("3D: hoppat", o.getvalue())
        _, data = _las_sidan((ut / "visa.html").read_text(encoding="utf-8"))
        self.assertIn("märkta DTL/DTL", data["tre_d"]["hoppat"])
        self.assertEqual([p["fil"] for p in data["paket"]], [d.name, fel.name])
        self.assertEqual(data["tre_d"]["par"], [])
        self.assertEqual(len(data["rader"]), len(P.las(d).slag) + len(P.las(fel).slag))
        self.assertTrue(all(sum(v is not None for v in r["vyer"]) == 1 for r in data["rader"]))


def _skriv_om(fran: Path, till: Path, andra, extra: dict | None = None) -> None:
    """Paketet med manifestet ändrat (och filer tillagda), till en ny zip."""
    with zipfile.ZipFile(fran) as z, zipfile.ZipFile(till, "w") as u:
        m = json.loads(z.read("manifest.json"))
        andra(m)
        for n in z.namelist():
            if n != "manifest.json":
                u.writestr(n, z.read(n))
        for n, b in (extra or {}).items():
            u.writestr(n, b)
        u.writestr("manifest.json", json.dumps(m))


class TestKommandot(unittest.TestCase):
    def test_vagrar_utmapp_i_repot(self):
        d, f, _ = _pass("bra", pass_id="20261103-180000", n=10, seed=5, brus="bra")
        with redirect_stdout(io.StringIO()) as o:
            self.assertEqual(V.main([str(d), str(f), "--ut", str(Path(__file__).parent / "visa-ut")]), 1)
        self.assertIn("i repot", o.getvalue())
        self.assertFalse((Path(__file__).parent / "visa-ut").exists())

    def test_klippen_och_mediapipe(self):
        """Klippet kopieras bredvid sidan, och S3:s MediaPipe-leder läggs på Visions tid
        med S3:s förskjutning (METOD MF1)."""
        d, f, _ = _pass("bra", pass_id="20261103-180000", n=10, seed=5, brus="bra")
        mapp = Path(TMP.name) / "klipp"
        mapp.mkdir(exist_ok=True)
        fk = mapp / f.name

        def med_klipp(m):
            m["slag"][0].update(klipp="klipp/s01.mov", klick_i_klipp_s=2.5)
        _skriv_om(f, fk, med_klipp, {"klipp/s01.mov": b"inte en riktig film"})
        p = P.las(fk)
        s = p.slag[0]
        s3 = Path(TMP.name) / "s3"
        (s3 / "mediapipe").mkdir(parents=True, exist_ok=True)
        forsk_ms = 4.0
        rutor = [{"tk": r["t"] + 2.5 + forsk_ms / 1000, "joints": [[j["x"] + 3, j["y"], 0.9] if isinstance(j, dict)
                                                                   else ([j[0] + 3, j[1], 0.9] if j else None)
                                                                   for j in r["joints"]]}
                 for r in s.lederna["frames"]]
        (s3 / "mediapipe" / f"{fk.stem}-{s.id}.json").write_text(json.dumps({"frames": rutor}), encoding="utf-8")
        (s3 / "s3.json").write_text(json.dumps({"slag": [{"fil": fk.name, "id": s.id, "tidsparning":
                                                           {"forskjutning_ms": forsk_ms}}]}), encoding="utf-8")
        ut = Path(TMP.name) / "ut-klipp"
        with redirect_stdout(io.StringIO()):
            self.assertEqual(V.main([str(d), str(fk), "--ut", str(ut), "--s3", str(s3)]), 0)
        _, data = _las_sidan((ut / "visa.html").read_text(encoding="utf-8"))
        self.assertTrue(data["mediapipe"])
        v = next(r["vyer"][1] for r in data["rader"] if r["vyer"][1] and r["vyer"][1]["id"] == s.id)
        self.assertEqual(v["klipp"], f"klipp/{fk.stem}-{s.id}.mov")
        self.assertEqual((ut / v["klipp"]).read_bytes(), b"inte en riktig film")
        self.assertAlmostEqual(v["klipp_t"], 2.5 + forsk_ms / 1000, places=6)
        self.assertTrue(v["mp"]["kand"])
        np.testing.assert_allclose(v["mp"]["t"], v["t"], atol=2e-4)
        i = len(v["t"]) // 2
        vx = [x for x in v["xy"][i][0::2]]
        mx = [x for x in v["mp"]["xy"][i][0::2]]
        self.assertEqual([a + 3 for a, b in zip(vx, mx) if a is not None], [b for a, b in zip(vx, mx) if a is not None])


if __name__ == "__main__":
    unittest.main()
