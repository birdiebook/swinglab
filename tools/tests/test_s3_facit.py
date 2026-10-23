"""S3-verktyget (METOD MF1–MF4) utan MediaPipe: en påhittad modell läser rutans nummer
ur bilden och ger Visions leder för just den rutan plus känt brus. Klippets tider är
förskjutna mot Visions (som OpenCV:s mot klippets nolla), så att tidsparningen prövas.
Med OpenCV och ffmpeg prövas samma sak på en riktig film som är lagrad liggande med
vridning i metadata och börjar efter 0."""
from __future__ import annotations

import atexit
import contextlib
import functools
import io
import json
import shutil
import struct
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock

import numpy as np

import _hjalp  # noqa: F401
from pc import generera_paket as GP
from pc import klipp as KL
from pc import kontaktark as KA
from pc import paket as P
from pc import s3_facit as S3
from pc.format import LEDER_FIL

PASS = "20261103-180000"
UTSNITT = {"x": 0.1, "y": 0.05, "b": 0.8, "h": 0.9}
HANDLED_V, HOFT_V, KNA_V, KNA_H = (LEDER_FIL.index(n) for n in ("handled_v", "hoft_v", "kna_v", "kna_h"))
FPS = 240.0
SKIFT = 2.5 + GP.AVSTAND_M / P.LJUDETS_FART      # Visions t = k/240 − SKIFT i de påhittade paketen
OFF = 0.0025                                      # klippets första ruta ligger 2,5 ms efter klippets nolla
FILM_B, FILM_H = 108, 192                         # filmen i en tiondel av ledernas storlek
KOD_Y, KOD_X0, KOD_BIT, KOD_BITAR = 90, 15, 8, 10


def med_klipp(fil: Path, dolj_var: int = 0, off: float = OFF, film: bytes = b"inte en film",
              slag: int | None = None) -> dict:
    """Lägger utsnitt och klipp i paketet: klippets nolla är Visions rutnät + `off`
    (klick_i_klipp_s = SKIFT + off), och döljer Visions främre handled i var
    `dolj_var`:e ruta. Bara de `slag` första får klipp (None = alla). Svarar sanningen per slag: {(paket, slag): ({t: (13, 3)}, klick_i_klipp_s)}."""
    with zipfile.ZipFile(fil) as z:
        filer = {n: z.read(n) for n in z.namelist()}
    m = json.loads(filer["manifest.json"])
    m["serier"][0]["utsnitt"] = UTSNITT
    sanning = {}
    for s in m["slag"][slag:] if slag is not None else []:
        for k in ("klipp", "klick_i_klipp_s", "klipp_langd_s"):
            s.pop(k, None)
    for s in m["slag"][:slag]:
        s.update(klipp=f"klipp/{s['id']}.mov", klick_i_klipp_s=round(SKIFT + off, 6), klipp_langd_s=4.0)
        filer[s["klipp"]] = film
        d = json.loads(filer[s["leder"]])
        sanning[(fil.name, s["id"])] = ({float(r["t"]): np.array([[j["x"], j["y"], j["c"]] if j else [np.nan] * 3
                                                                  for j in r["joints"]]) for r in d["frames"]},
                                        s["klick_i_klipp_s"])
        if dolj_var:
            for i, r in enumerate(d["frames"]):
                if i % dolj_var == 0:
                    r["joints"][dolj_led()] = None
        filer[s["leder"]] = json.dumps(d).encode()
    filer["manifest.json"] = json.dumps(m).encode()
    with zipfile.ZipFile(fil, "w", zipfile.ZIP_STORED) as z:
        for n, b in filer.items():
            z.writestr(n, b)
    return sanning


def dolj_led() -> int:
    return HANDLED_V


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


def rita_kod(n: int) -> np.ndarray:
    """En upprätt filmruta (FILM_H × FILM_B) med rutans nummer som vita block."""
    img = np.zeros((FILM_H, FILM_B, 3), np.uint8)
    for b in range(KOD_BITAR):
        if n >> b & 1:
            x = KOD_X0 + b * KOD_BIT
            img[KOD_Y:KOD_Y + 10, x + 1:x + KOD_BIT - 1] = 255
    return img


def las_kod(utsnitt: np.ndarray, x0: float, y0: float, sk: float) -> int:
    """Rutans nummer ur utsnittet, vars hörn ligger i (x0, y0) i ledernas px."""
    ox, oy = int(round(x0 * sk)), int(round(y0 * sk))
    n = 0
    for b in range(KOD_BITAR):
        x = KOD_X0 + b * KOD_BIT + KOD_BIT // 2 - ox
        if utsnitt[KOD_Y + 5 - oy, x].mean() > 128:
            n |= 1 << b
    return n


class Rutor:
    """Ett klipp utan film: rutorna n = 0 … med nummerkoden, och läsarens tid n/240,
    alltså OFF före klippets nolla (som OpenCV, som räknar från strömmens start)."""

    N = int(4.0 * FPS)

    def rutor(self, paket_fil, paket, slag):
        for n in range(self.N):
            yield n / FPS, rita_kod(n)

    def vid(self, paket_fil, paket, slag, tider):
        ut = {}
        for t in tider:
            n = int(round(t * FPS))
            if 0 <= n < self.N and abs(n / FPS - t) <= S3.TID_TOL_S:
                ut[t] = (n / FPS, rita_kod(n))
        return ut


class PahittadModell:
    """Läser rutans nummer ur bilden, tar Visions leder (sanningen) för den rutan på
    filmens egen tid och lägger på känt brus: en fast förskjutning per led, vitt brus och
    knäna förväxlade i var `byt_var`:e ruta. Svarar normerat i utsnittet som MediaPipe."""

    def __init__(self, sanning: dict, fast: dict | None = None, sd: float = 0.0, byt_var: int = 0,
                 off: float = OFF, seed: int = 1):
        self.sanning, self.fast, self.sd, self.byt_var, self.off = sanning, fast or {}, sd, byt_var, off
        self.rng = np.random.default_rng(seed)
        self.info, self.n = None, 0
        self._cache = {}

    def borja(self, info):
        self.info, self.n = info, 0

    def _nycklar(self, facit: dict) -> np.ndarray:
        if id(facit) not in self._cache:
            self._cache[id(facit)] = np.array(sorted(facit))
        return self._cache[id(facit)]

    def kor(self, bild, t):
        rx, ry, rb, rh = self.info.ruta
        n = las_kod(bild, rx, ry, bild.shape[1] / rb)
        facit, klick = self.sanning[(self.info.fil, self.info.slag)]
        nycklar = self._nycklar(facit)
        t_v = n / FPS + self.off - klick
        k = int(np.clip(np.searchsorted(nycklar, t_v), 1, len(nycklar) - 1))
        nara = nycklar[k] if abs(nycklar[k] - t_v) < abs(nycklar[k - 1] - t_v) else nycklar[k - 1]
        if abs(nara - t_v) > 2e-4:
            return None                       # Vision har ingen ruta här (36 % saknas)
        L = facit[float(nara)].copy()
        for j, (dx, dy) in self.fast.items():
            L[j, :2] += (dx, dy)
        if self.sd:
            L[:, :2] += self.rng.normal(0.0, self.sd, (13, 2))
        self.n += 1
        if self.byt_var and self.n % self.byt_var == 0:
            L[[KNA_V, KNA_H]] = L[[KNA_H, KNA_V]]
        ut = np.zeros((33, 3))
        for j, k in enumerate(S3.MP_INDEX):
            ut[k] = ((L[j, 0] - rx) / rb, (L[j, 1] - ry) / rh, 0.9 if np.isfinite(L[j, 0]) else 0.0)
        return ut

    def sluta(self):
        pass


def _png_storlek(fil: Path) -> tuple[int, int]:
    b = fil.read_bytes()
    assert b[:8] == b"\x89PNG\r\n\x1a\n"
    return struct.unpack(">II", b[16:24])


def nivaer_sma() -> dict:
    return S3.nivaer(1, 3)


class Jamforelsen(unittest.TestCase):
    """Två körningar delas av testerna: med känt brus (FO) och utan (DTL)."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.tmp = tempfile.TemporaryDirectory()
        rot = Path(cls.tmp.name)
        filer, cls.sanning = paketen()
        cls.filer = list(filer)
        kw = {"min_slag": 3, "bootstrap": 20, "niv": nivaer_sma()}
        cls.brus_ut = rot / "brus"
        cls.brus = S3.kor(cls.filer[:1], cls.brus_ut, None,
                          PahittadModell(cls.sanning, fast={HOFT_V: (6.0, -3.0)}, sd=2.0, byt_var=10), Rutor(), **kw)
        cls.utan_ut = rot / "utan"
        cls.utan = S3.kor(cls.filer[1:], cls.utan_ut, None, PahittadModell(cls.sanning), Rutor(), **kw)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.tmp.cleanup()

    def _rad(self, res, vy, led, fas="alla"):
        return next(r for r in res["leder"] if r["vy"] == vy and r["led"] == led and r["fas"] == fas)

    def test_tidsparningen_hittar_forskjutningen(self) -> None:
        for res in (self.brus, self.utan):
            for s in res["slag"]:
                tp = s["tidsparning"]
                self.assertNotIn("hoppat", s)
                self.assertAlmostEqual(tp["forskjutning_ms"], -OFF * 1000, delta=0.1)
                self.assertEqual(tp["rutor"], -1)          # 0,6 ruta: närmaste rutan var fel
                self.assertLess(abs(tp["rest_ms_median"]), 0.1)
                self.assertGreater(s["rutor_parade"], 500)

    def test_utan_brus_ar_lederna_och_matten_lika(self) -> None:
        res, ut = self.utan, self.utan_ut
        self.assertLess(self._rad(res, "dtl", "alla")["px"]["medel"], 0.1)      # avrundningen till 0,1 px
        b = res["beslut_b5"]["dtl"]
        self.assertEqual(b["alla"]["niva"], "bra")
        self.assertEqual(b["nedsving"]["niva"], "bra")
        self.assertEqual(b["matt_tydliga"], 0)
        cm = [m for m in res["matt"] if m["enhet"] == "cm"]
        self.assertGreater(len(cm), 10)
        self.assertLess(max(abs(m["skillnad"]) for m in cm), 0.1)
        self.assertEqual(json.loads((ut / "s3.json").read_text())["format"], S3.FORMAT)

    def test_kant_brus_hittas(self) -> None:
        res = self.brus
        for vy in ("fo",):
            hoft = self._rad(res, vy, "hoft_v")
            # Avvikelsen är Vision − MediaPipe: den fasta förskjutningen med omvänt tecken.
            self.assertAlmostEqual(hoft["px"]["fast"], np.sqrt((36 + 9) / 2), delta=0.5)
            axel = self._rad(res, vy, "axel_v")
            self.assertLess(axel["px"]["fast"], 0.5)
            self.assertAlmostEqual(axel["px"]["rorligt"], 2.0, delta=0.4)
            self.assertEqual(axel["slag"], 3)
            # Kroppen är 720 px i den påhittade figuren (4 px/cm, 1,80 m).
            self.assertAlmostEqual(hoft["procent"]["fast"], 100 * np.sqrt(22.5) / 720, delta=0.1)
            b = res["beslut_b5"][vy]["alla"]
            self.assertEqual(b["slag"], 3)
            lo, hi = b["intervall"]["rorligt"]
            self.assertLessEqual(lo, b["rorligt"])
            self.assertGreaterEqual(hi, b["rorligt"])
        # Var 5:e ruta saknar Visions främre handled framifrån; MediaPipe ser den.
        hand = self._rad(res, "fo", "handled_v")
        self.assertAlmostEqual(hand["vision_saknar"], 0.2, delta=0.02)
        self.assertAlmostEqual(hand["vision_saknar_mp_ser"], 0.2, delta=0.02)
        self.assertEqual(hand["mediapipe_saknar"], 0.0)
        self.assertEqual(self._rad(self.utan, "dtl", "handled_v")["vision_saknar"], 0.0)
        kna = next(s for s in res["sidbyten"] if s["vy"] == "fo" and s["par"] == "kna")
        self.assertAlmostEqual(kna["andel"], 0.1, delta=0.02)
        axlar = next(s for s in res["sidbyten"] if s["vy"] == "fo" and s["par"] == "axel")
        self.assertEqual(axlar["andel"], 0.0)
        m = next(x for x in res["matt"] if x["intervall"])
        self.assertLessEqual(m["intervall"][0], m["intervall"][1])

    def test_per_fas_och_tabellen(self) -> None:
        res, ut = self.brus, self.brus_ut
        faser = {r["fas"] for r in res["leder"] if r["n"]}
        self.assertTrue(set(S3.FASER_S3) <= faser)
        md = (ut / "s3.md").read_text()
        self.assertIn("## Det som avgör B5", md)
        self.assertIn("nedsving", md)
        self.assertIn("ingen källa", md)
        self.assertIn("## Tidsparningen per slag", md)
        for vy in ("fo",):
            k = res["kontaktark"][vy]
            self.assertEqual(len(k["rader"]), 3)
            w, _ = _png_storlek(ut / k["fil"])
            self.assertEqual(w, 4 * (S3.KONTAKT_BREDD + 2))

    def test_sparade_leder_ateranvands_och_farre_an_fem_slag(self) -> None:
        ut = self.utan_ut
        self.assertEqual(len(list((ut / "mediapipe").glob("*.json"))), 3)
        # Andra gången behövs varken modellen eller klippen; tre slag är för få för B5.
        res = S3.kor(self.filer[1:], ut, None, None, None, bootstrap=0, niv=nivaer_sma())
        self.assertEqual(sum(p["korda"] for p in res["paket"]), 3)
        self.assertIn("hoppat", res["kontaktark"]["dtl"])
        self.assertIsNone(res["beslut_b5"]["dtl"]["alla"])
        self.assertTrue(all(m["skillnad"] is None and m["tydlig"] is None for m in res["matt"]))
        self.assertIn("–", (ut / "s3.md").read_text())
        # Ett annat utsnitt eller en annan modell gör de sparade lederna ogiltiga.
        d = json.loads(next((ut / "mediapipe").glob("*.json")).read_text())
        self.assertTrue(S3._cache_giltig(d, 1080, 1920, tuple(d["utsnitt_px"]), S3.MODELL_FIL))
        self.assertFalse(S3._cache_giltig(d, 1080, 1920, (0, 0, 1080, 1920), S3.MODELL_FIL))
        self.assertFalse(S3._cache_giltig(d, 1080, 1920, tuple(d["utsnitt_px"]), "pose_landmarker_full.task"))
        with self.assertRaises(S3.S3Fel):
            S3.kor(self.filer[1:], ut, None, None, None, modell_namn="annan.task", niv=nivaer_sma())


class Delarna(unittest.TestCase):
    def test_tvetydig_tidsparning(self) -> None:
        e = np.arange(200) / FPS
        V = np.full((200, 13, 3), np.nan)
        V[:, list(S3.HANDLEDER)] = [500.0, 800.0, 0.9]          # handlederna står still
        r = e + 0.001
        res = S3.para_tider(e, V, r, V.copy(), np.ones(200, bool))
        self.assertEqual(res["tvetydig"], "två förskjutningar passar nästan lika bra")
        V[:, list(S3.HANDLEDER), 0] = 500.0 + 3000.0 * e[:, None]  # handlederna rör sig
        res = S3.para_tider(e, V, r, V.copy(), np.ones(200, bool))
        self.assertIsNone(res["tvetydig"])
        self.assertAlmostEqual(res["forskjutning_ms"], 1.0, places=3)
        # Den rätta förskjutningen utanför sökningen: vid kanten = tvetydig.
        res = S3.para_tider(e, V, e + 5 / FPS, V.copy(), np.ones(200, bool))
        self.assertIsNotNone(res["tvetydig"])
        res = S3.para_tider(e, V, r, V.copy(), np.zeros(200, bool))
        self.assertIn("färre än", res["tvetydig"])

    def test_tillbaka_ur_utsnittet(self) -> None:
        p = np.zeros((33, 3))
        p[:, 2] = 0.9
        p[0] = (0.5, 0.25, 0.8)
        p[11] = (1.2, 0.5, 0.9)              # utanför rutan: saknad, som på telefonen
        ut = S3.till_leder(p, (100, 200, 400, 800), 1080, 1920)
        self.assertEqual(ut[0], [300.0, 400.0, 0.8])
        self.assertIsNone(ut[1])
        self.assertEqual(S3.till_leder(None, (0, 0, 1, 1), 1, 1), [None] * 13)

    def test_nivaerna_simuleras_med_bada_kallornas_brus(self) -> None:
        n = nivaer_sma()
        self.assertEqual(n["mediapipe"], S3.MP_ANTAGEN)
        for fas in S3.B5_FASER:
            for k in S3.NIVA_DELAR:
                self.assertLess(n[fas]["bra"][k], n[fas]["typiskt"][k])
                self.assertLess(n[fas]["typiskt"][k], n[fas]["daligt"][k])
        # Skillnaden bär MediaPipes brus också: över en enda källas fasta del (5 px av 866).
        self.assertGreater(n["alla"]["typiskt"]["fast"], 100 * 5 / 866.4)
        v = dict(n["alla"]["typiskt"])
        self.assertEqual(S3.niva_for(v, n["alla"]), "typiskt")
        v["rorligt"] = n["alla"]["daligt"]["rorligt"] * 2
        self.assertEqual(S3.niva_for(v, n["alla"]), "samre_an_daligt")

    def test_kommandot(self) -> None:
        filer = paketen()[0]
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            self.assertEqual(S3.main([str(filer[0]), "--ut", str(Path(__file__).parent / "x")]), 1)
        self.assertIn("i repot", buf.getvalue())
        buf = io.StringIO()
        with tempfile.TemporaryDirectory() as tmp, \
                mock.patch.object(S3, "saknade_beroenden", return_value=["mediapipe"]), \
                contextlib.redirect_stdout(buf):
            self.assertEqual(S3.main([str(filer[0]), "--ut", tmp]), 1)
        self.assertIn(S3.PIP, buf.getvalue())
        self.assertIn(S3.MODELL_FIL, buf.getvalue())


def _har_cv2() -> bool:
    try:
        import cv2  # noqa: F401
        return True
    except ImportError:
        return False


@unittest.skipUnless(_har_cv2() and shutil.which("ffmpeg") and shutil.which("ffprobe"), "OpenCV eller ffmpeg saknas")
class Filmen(unittest.TestCase):
    """En riktig film: lagrad liggande med vridningen i metadata (som iPhones), och med
    första rutan efter 0 (`-itsoffset`). KlippRutor ska vrida den upprätt och parningen
    hitta förskjutningen; den påhittade modellen läser rutans nummer ur bilden."""

    @classmethod
    def setUpClass(cls) -> None:
        import cv2
        cls.tmp = tempfile.TemporaryDirectory()
        rot = Path(cls.tmp.name)
        vw = cv2.VideoWriter(str(rot / "in.mp4"), cv2.VideoWriter_fourcc(*"mp4v"), FPS, (FILM_H, FILM_B))
        for n in range(int(4.0 * FPS)):
            vw.write(cv2.rotate(rita_kod(n), cv2.ROTATE_90_CLOCKWISE))      # liggande i filen
        vw.release()
        cls.film = rot / "film.mov"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-display_rotation", "90", "-itsoffset", str(OFF),
                        "-i", str(rot / "in.mp4"), "-c", "copy", str(cls.film)], check=True, timeout=60)
        start = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v", "-show_entries",
                                "stream=start_time", "-of", "csv=p=0", str(cls.film)],
                               capture_output=True, text=True, check=True).stdout.strip().rstrip(",")
        cls.off = float(start)
        f = rot / "swinglab-film-dtl.zip"
        shutil.copy(paketen()[0][1], f)
        cls.sanning = med_klipp(f, off=cls.off, film=cls.film.read_bytes(), slag=1)
        cls.paket = f

    @classmethod
    def tearDownClass(cls) -> None:
        cls.tmp.cleanup()

    def test_klipprutor_vrider_och_parar(self) -> None:
        res = S3.kor([self.paket], Path(self.tmp.name) / "ut", None, PahittadModell(self.sanning, off=self.off),
                     S3.KlippRutor(), min_slag=3, bootstrap=0, niv=nivaer_sma(), kontakt_slag=1)
        self.assertGreater(self.off, 0.0)
        jamforda = [s for s in res["slag"] if "tidsparning" in s]
        self.assertEqual(len(jamforda), 1)
        for s in jamforda:
            self.assertNotIn("hoppat", s)
            self.assertAlmostEqual(s["tidsparning"]["forskjutning_ms"], -self.off * 1000, delta=0.2)
        alla = next(r for r in res["leder"] if r["led"] == "alla" and r["fas"] == "alla")
        self.assertLess(alla["px"]["medel"], 0.1)
        self.assertIn("fil", res["kontaktark"]["dtl"])

    def test_las_ruta_kontrollerar_vridningen(self) -> None:
        for satt in ("opencv", "ffmpeg"):
            img = KA.las_ruta(self.film, 1.0, FILM_B, FILM_H, satt)
            self.assertEqual(img.shape, (FILM_H, FILM_B, 3))
            with self.assertRaises(KL.VridenFel):
                KA.las_ruta(self.film, 1.0, FILM_H, FILM_B, satt)


if __name__ == "__main__":
    unittest.main()
