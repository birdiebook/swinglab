"""S3-verktyget (METOD MF1–MF4) utan MediaPipe: en påhittad modell ger Visions leder
plus känt brus i ett påhittat paket, och jämförelsen ska hitta bruset."""
from __future__ import annotations

import atexit
import contextlib
import functools
import io
import shutil
import json
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock

import numpy as np

import _hjalp  # noqa: F401
from pc import generera_paket as GP
from pc import paket as P
from pc import s3_facit as S3
from pc.format import LEDER_FIL

PASS = "20261103-180000"
UTSNITT = {"x": 0.1, "y": 0.05, "b": 0.8, "h": 0.9}
HANDLED_V, HOFT_V, KNA_V, KNA_H = (LEDER_FIL.index(n) for n in ("handled_v", "hoft_v", "kna_v", "kna_h"))


def med_klipp(fil: Path, dolj_var: int = 0, dolj_led: int = HANDLED_V) -> dict:
    """Lägger utsnitt och påhittade klipp (bytes utan bild) i paketet, och döljer
    `dolj_led` i var `dolj_var`:e ruta i Visions leder. Svarar sanningen (lederna
    före döljningen) per slag: {(paketets namn, slag): {t: (13, 3)}}."""
    with zipfile.ZipFile(fil) as z:
        filer = {n: z.read(n) for n in z.namelist()}
    m = json.loads(filer["manifest.json"])
    m["serier"][0]["utsnitt"] = UTSNITT
    sanning = {}
    for s in m["slag"]:
        s.update(klipp=f"klipp/{s['id']}.mov", klick_i_klipp_s=2.5, klipp_langd_s=4.0)
        filer[s["klipp"]] = b"inte en film"
        d = json.loads(filer[s["leder"]])
        sanning[(fil.name, s["id"])] = {
            float(r["t"]): np.array([[j["x"], j["y"], j["c"]] if j else [np.nan] * 3 for j in r["joints"]])
            for r in d["frames"]}
        if dolj_var:
            for i, r in enumerate(d["frames"]):
                if i % dolj_var == 0:
                    r["joints"][dolj_led] = None
        filer[s["leder"]] = json.dumps(d).encode()
    filer["manifest.json"] = json.dumps(m).encode()
    with zipfile.ZipFile(fil, "w", zipfile.ZIP_STORED) as z:
        for n, b in filer.items():
            z.writestr(n, b)
    return sanning


@functools.lru_cache(maxsize=None)
def paketen() -> tuple[tuple[Path, ...], dict]:
    """Två påhittade paket med klipp och utsnitt, gjorda en gång för alla testerna:
    FO döljer Visions främre handled i var 5:e ruta, DTL är orört. (filerna, sanningen)"""
    rot = Path(tempfile.mkdtemp(prefix="swinglab-s3-"))
    atexit.register(shutil.rmtree, rot, True)
    filer, sanning = [], {}
    for vy, seed, dolj in (("fo", 3, 5), ("dtl", 4, 0)):
        f = GP.paket(rot / "in", PASS, vy, n=3, inte_sving=0, seed=seed)
        sanning.update(med_klipp(f, dolj_var=dolj))
        filer.append(f)
    return tuple(filer), sanning


class Rutor:
    """Klippets rutor utan film: samma (svarta) bild för varje ruta inom klippet."""

    BILD = np.zeros((1920, 1080, 3), np.uint8)

    def rutor(self, paket_fil, paket, slag, tider):
        for t in tider:
            yield t, (self.BILD if P.i_klippet(slag, t + slag.klick_i_klipp_s) else None)


class PahittadModell:
    """Visions leder (sanningen) plus känt brus: en fast förskjutning per led, vitt brus
    och knäna förväxlade i var `byt_var`:e ruta, normerade i utsnittet som MediaPipe."""

    def __init__(self, sanning: dict, fast: dict | None = None, sd: float = 0.0, byt_var: int = 0, seed: int = 1):
        self.sanning, self.fast, self.sd, self.byt_var = sanning, fast or {}, sd, byt_var
        self.rng = np.random.default_rng(seed)
        self.info, self.n = None, 0

    def borja(self, info):
        self.info, self.n = info, 0

    def kor(self, bild, t):
        x0, y0, b, h = self.info.ruta
        assert bild.shape[:2] == (h, b), "modellen ska få utsnittet"
        L = self.sanning[(self.info.fil, self.info.slag)][t].copy()
        for j, (dx, dy) in self.fast.items():
            L[j, :2] += (dx, dy)
        L[:, :2] += self.rng.normal(0.0, self.sd, (13, 2)) if self.sd else 0.0
        self.n += 1
        if self.byt_var and self.n % self.byt_var == 0:
            L[[KNA_V, KNA_H]] = L[[KNA_H, KNA_V]]
        ut = np.zeros((33, 3))
        for j, k in enumerate(S3.MP_INDEX):
            ut[k] = ((L[j, 0] - x0) / b, (L[j, 1] - y0) / h, 0.9)
        return ut

    def sluta(self):
        pass


def _png_storlek(fil: Path) -> tuple[int, int]:
    b = fil.read_bytes()
    assert b[:8] == b"\x89PNG\r\n\x1a\n"
    return struct.unpack(">II", b[16:24])


class Jamforelsen(unittest.TestCase):
    """Två körningar delas av testerna: FO-paketet döljer Visions främre handled i var
    5:e ruta, DTL-paketet är orört."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.tmp = tempfile.TemporaryDirectory()
        rot = Path(cls.tmp.name)
        filer, cls.sanning = paketen()
        cls.filer = list(filer)
        cls.brus_ut = rot / "brus"
        cls.brus = S3.kor(cls.filer, cls.brus_ut, None, PahittadModell(cls.sanning, fast={HOFT_V: (6.0, -3.0)},
                                                                     sd=2.0, byt_var=10), Rutor())
        cls.utan_ut = rot / "utan"
        cls.utan = S3.kor(cls.filer[1:], cls.utan_ut, None, PahittadModell(cls.sanning), Rutor())

    @classmethod
    def tearDownClass(cls) -> None:
        cls.tmp.cleanup()

    def _rad(self, res, vy, led, fas="alla"):
        return next(r for r in res["leder"] if r["vy"] == vy and r["led"] == led and r["fas"] == fas)

    def test_utan_brus_ar_lederna_och_matten_lika(self) -> None:
        res, ut = self.utan, self.utan_ut
        self.assertLess(self._rad(res, "dtl", "alla")["px"]["medel"], 0.1)      # avrundningen till 0,1 px
        self.assertEqual(res["beslut_b5"]["dtl"]["niva"], "bra")
        self.assertEqual(res["beslut_b5"]["dtl"]["matt_tydliga"], 0)
        cm = [m for m in res["matt"] if m["enhet"] == "cm"]
        self.assertGreater(len(cm), 10)
        self.assertLess(max(abs(m["skillnad"]) for m in cm), 0.1)
        self.assertEqual(json.loads((ut / "s3.json").read_text())["format"], S3.FORMAT)

    def test_kant_brus_hittas(self) -> None:
        res = self.brus
        for vy in ("fo", "dtl"):
            hoft = self._rad(res, vy, "hoft_v")
            # Avvikelsen är Vision − MediaPipe: den fasta förskjutningen med omvänt tecken.
            self.assertAlmostEqual(hoft["px"]["fast"], np.sqrt((36 + 9) / 2), delta=0.5)
            axel = self._rad(res, vy, "axel_v")
            self.assertLess(axel["px"]["fast"], 0.5)
            self.assertAlmostEqual(axel["px"]["rorligt"], 2.0, delta=0.4)
            # Kroppen är 720 px i den påhittade figuren (4 px/cm, 1,80 m).
            self.assertAlmostEqual(hoft["procent"]["fast"], 100 * np.sqrt(22.5) / 720, delta=0.1)
        # Var 5:e ruta saknar Visions främre handled framifrån; MediaPipe ser den.
        hand = self._rad(res, "fo", "handled_v")
        self.assertAlmostEqual(hand["vision_saknar"], 0.2, delta=0.02)
        self.assertAlmostEqual(hand["vision_saknar_mp_ser"], 0.2, delta=0.02)
        self.assertEqual(hand["mediapipe_saknar"], 0.0)
        self.assertEqual(self._rad(res, "dtl", "handled_v")["vision_saknar"], 0.0)
        kna = next(s for s in res["sidbyten"] if s["vy"] == "fo" and s["par"] == "kna")
        self.assertAlmostEqual(kna["andel"], 0.1, delta=0.02)
        axlar = next(s for s in res["sidbyten"] if s["vy"] == "fo" and s["par"] == "axel")
        self.assertEqual(axlar["andel"], 0.0)

    def test_per_fas_och_tabellen(self) -> None:
        res, ut = self.brus, self.brus_ut
        faser = {r["fas"] for r in res["leder"] if r["n"]}
        self.assertTrue(set(S3.FASER_S3) <= faser)
        md = (ut / "s3.md").read_text()
        self.assertIn("## Det som avgör B5", md)
        self.assertIn("ingen källa", md)
        self.assertIn("S6_FELBUDGET §3", md)
        for vy in ("fo", "dtl"):
            k = res["kontaktark"][vy]
            self.assertEqual(len(k["rader"]), 3)
            w, _ = _png_storlek(ut / k["fil"])
            self.assertEqual(w, 4 * (S3.KONTAKT_BREDD + 2))

    def test_sparade_leder_ateranvands(self) -> None:
        ut = self.utan_ut
        self.assertEqual(len(list((ut / "mediapipe").glob("*.json"))), 3)
        # Andra gången behövs varken modellen eller klippen.
        res = S3.kor(self.filer[1:], ut, None, None, None)
        self.assertEqual(sum(p["korda"] for p in res["paket"]), 3)
        self.assertIn("hoppat", res["kontaktark"]["dtl"])
        self.assertLess(self._rad(res, "dtl", "alla")["px"]["medel"], 0.1)

    def test_tillbaka_ur_utsnittet(self) -> None:
        p = np.zeros((33, 3))
        p[:, 2] = 0.9
        p[0] = (0.5, 0.25, 0.8)
        p[11] = (1.2, 0.5, 0.9)              # utanför rutan: saknad, som på telefonen
        ut = S3.till_leder(p, (100, 200, 400, 800), 1080, 1920)
        self.assertEqual(ut[0], [300.0, 400.0, 0.8])
        self.assertIsNone(ut[1])
        self.assertEqual(S3.till_leder(None, (0, 0, 1, 1), 1, 1), [None] * 13)

    def test_kommandot(self) -> None:
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            self.assertEqual(S3.main([str(self.filer[0]), "--ut", str(Path(__file__).parent / "x")]), 1)
        self.assertIn("i repot", buf.getvalue())
        buf = io.StringIO()
        with mock.patch.object(S3, "saknade_beroenden", return_value=["mediapipe"]), \
                contextlib.redirect_stdout(buf):
            self.assertEqual(S3.main([str(self.filer[0]), "--ut", str(Path(self.tmp.name) / "k")]), 1)
        self.assertIn(S3.PIP, buf.getvalue())
        self.assertIn(S3.MODELL_FIL, buf.getvalue())

    def test_nivaerna_ur_felbudgeten(self) -> None:
        n = S3.nivaer()
        self.assertAlmostEqual(n["typiskt"]["fast"], 100 * 5 / 866.4, places=3)
        self.assertLess(n["bra"]["rorligt"], n["typiskt"]["rorligt"])
        self.assertLess(n["typiskt"]["rorligt"], n["daligt"]["rorligt"])


if __name__ == "__main__":
    unittest.main()
