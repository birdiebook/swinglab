"""S3: facit för lederna. MediaPipe Pose heavy mot telefonens Vision på samma rutor
(PLAN S3, BESLUT B5, METOD MF1–MF4).

    python tools/pc/s3_facit.py <paket.zip> [fler paket] [--ut <mapp>] [--langd 1.80] [--om]

För varje mätt slag med klipp i paketet: klippets rutor på Visions tider (MF1), samma
utsnitt som telefonen (`paket.utsnitt_px`, BESLUT B34), MediaPipe heavy på rutan och
punkterna tillbaka till hela bildens pixlar (`paket.fran_utsnittet`). Sedan:

- **lederna** per led, fas och vy: medelavvikelsen och spridningen i px och i % av
  kroppslängden, den fasta och den rörliga delen och utliggarna (MF2), andelen rutor
  där Vision saknar leden, och förväxlade sidor;
- **måtten** (S1, `matt.mat`) på båda ledkällorna, per mått (MF3);
- överst det som avgör **B5** (räcker Vision?), med trösklarna ur felbudgeten och
  "ingen källa" där ingen finns (MF3);
- ett **kontaktark** per vy med båda ledsatserna på några rutor per fas (MF4).

Allt skrivs till en mapp **utanför repot**, som standard `~/swinglab-s3/<pass>/`
(Johannes data, CLAUDE.md Dataregeln): `s3.md`, `s3.json`, `kontaktark-s3-<vy>.png`
och MediaPipes leder per slag i `mediapipe/` (återanvänds nästa körning; `--om` kör om).

MediaPipe och OpenCV importeras först när de behövs; saknas de säger skriptet vad som
ska installeras. Modellen hämtas till `~/.cache/swinglab/mediapipe/` (BESLUT B43).
"""
from __future__ import annotations

import argparse
import json
import math
import sys
import tempfile
import zipfile
from dataclasses import dataclass, replace
from datetime import datetime
from pathlib import Path
from typing import Iterator, Protocol

import numpy as np

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "pc"

from . import faser as F  # noqa: E402
from . import format as fm  # noqa: E402
from . import matt as M  # noqa: E402
from . import paket as P  # noqa: E402
from . import session as S  # noqa: E402
from .analys import enhet  # noqa: E402
from .format import ANTAL_LEDER, LEDER_FIL, MIN_KONFIDENS  # noqa: E402
from .kontaktark import BEN, skriv_png, tider as kolumntider  # noqa: E402
from .tre_d import kamera as KM  # noqa: E402

FORMAT = "swinglab-s3/1"
UT_ROT = Path.home() / "swinglab-s3"

# Modellen (BESLUT B43): samma fil och URL som Golf SG (tools/handled_video.py).
MODELL_FIL = "pose_landmarker_heavy.task"
MODELL_URL = ("https://storage.googleapis.com/mediapipe-models/pose_landmarker/"
              "pose_landmarker_heavy/float16/latest/pose_landmarker_heavy.task")
MODELL_MAPP = Path.home() / ".cache" / "swinglab" / "mediapipe"
GOLF_SG_MAPP = Path.home() / ".cache" / "golf-sg" / "mediapipe"   # samma fil om Golf SG redan hämtat den
PIP = "pip install mediapipe opencv-python"

# MediaPipes index för de 13 lederna i filens ordning (docs/FORMAT.md, Lederna).
MP_INDEX = (0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28)
MP_ANTAL = 33
MIN_DETEKTION = 0.5          # METOD MF1: MediaPipes detektion och spårning, som Golf SG
MIN_SPARNING = 0.5           # METOD MF1
TID_TOL_S = 0.002            # METOD MF1: klippets ruta hör till Visions ruta inom 2 ms

FASER_S3 = ("adress", "baksving", "nedsving", "efter_traff")    # METOD MF2
PAR = (("axel", 1, 2), ("armbage", 3, 4), ("handled", 5, 6), ("hoft", 7, 8), ("kna", 9, 10),
       ("fotled", 11, 12))
SIDBYTE_KVOT = 0.5           # METOD MF2: bytta sidor ger under halva avståndet = förväxlade

# METOD MF3: felbudgetens nivåer (docs/S6_FELBUDGET.md §3) i % av kroppslängden.
# Kroppen i bild vid felbudgetens referens: 1,80 m på 3 m med f = 1444 px.
REF_LANGD_M = 1.80
KROPP_REF_PX = REF_LANGD_M * KM.F_PX / KM.REF_AVSTAND
NIVAER = ("bra", "typiskt", "daligt")
NIVA_TEXT = {"bra": "bra", "typiskt": "typiskt", "daligt": "dåligt", "samre_an_daligt": "sämre än dåligt"}


def nivaer() -> dict[str, dict[str, float]]:
    """Felbudgetens tre nivåer som trösklar: fast del och rörlig del per axel i % av
    kroppslängden, och andelen utliggare. Räknas ur `tre_d.kamera.BRUS`, så att de
    följer felbudgeten. METOD MF3"""
    ut = {}
    for n in NIVAER:
        b = KM.BRUS[n]
        ut[n] = {"fast": 100.0 * b.fast / KROPP_REF_PX,
                 "rorligt": 100.0 * math.hypot(b.vitt, b.vandring) / KROPP_REF_PX,
                 "utliggare": b.utliggare}
    return ut


class S3Fel(RuntimeError):
    """Ett fel som stoppar körningen, utan värden ur datan."""


# --- gränssnitten: modellen och rutorna ----------------------------------------------

@dataclass
class SlagInfo:
    fil: str                    # paketets namn
    vy: str
    slag: str
    bredd: int                  # hela den upprätta bilden (JointSeries)
    hojd: int
    ruta: tuple[int, int, int, int]   # utsnittet i px (x, y, b, h)


class Modell(Protocol):
    """Posemodellen bakom ett gränssnitt, så att testerna kör utan MediaPipe."""

    def borja(self, info: SlagInfo) -> None: ...

    def kor(self, bild: np.ndarray, t: float) -> np.ndarray | None:
        """bild = utsnittet (h, b, 3) RGB uint8; t = Visions tid (s relativt klicket).
        Svarar (33, 3): x och y normerade i utsnittet (origo uppe till vänster), synlighet."""
        ...

    def sluta(self) -> None: ...


class Rutkalla(Protocol):
    def rutor(self, paket_fil: Path, paket: P.Paket, slag: P.Slag,
              tider: list[float]) -> Iterator[tuple[float, np.ndarray | None]]:
        """För varje tid i `tider` (stigande, s relativt klicket): (tiden, hela den
        upprätta bilden (hojd, bredd, 3) RGB) eller (tiden, None) när klippet saknar
        rutan."""
        ...


def modellfil(angiven: str | None = None, hamta: bool = True) -> Path:
    """Modellfilen: den angivna, annars i ~/.cache/swinglab/mediapipe/ eller Golf SG:s
    cache, annars hämtad dit. Går den inte att hämta: S3Fel med var den ska ligga."""
    if angiven:
        p = Path(angiven).expanduser()
        if not p.is_file():
            raise S3Fel(f"--modell: filen finns inte ({p})")
        return p
    for mapp in (MODELL_MAPP, GOLF_SG_MAPP):
        if (mapp / MODELL_FIL).is_file():
            return mapp / MODELL_FIL
    fil = MODELL_MAPP / MODELL_FIL
    if hamta:
        import urllib.request
        print(f"Hämtar {MODELL_FIL} (cirka 30 MB) till {MODELL_MAPP} …", flush=True)
        try:
            fil.parent.mkdir(parents=True, exist_ok=True)
            tmp = fil.with_suffix(".del")
            urllib.request.urlretrieve(MODELL_URL, tmp)
            tmp.replace(fil)
            return fil
        except OSError:
            pass
    raise S3Fel(f"Modellen {MODELL_FIL} saknas. Hämta den med webbläsaren:\n  {MODELL_URL}\n"
                f"och lägg den här:\n  {fil}")


def saknade_beroenden() -> list[str]:
    """Paketen som saknas för MediaPipe och klippen (tomt = allt finns)."""
    saknas = []
    for modul, namn in (("cv2", "opencv-python"), ("mediapipe", "mediapipe")):
        try:
            __import__(modul)
        except ImportError:
            saknas.append(namn)
    return saknas


class MediaPipeModell:
    """MediaPipe Pose Landmarker heavy i VIDEO-läge, en instans per slag (som Golf SG,
    `handled_video.leder_for_slag`). METOD MF1"""

    def __init__(self, fil: Path):
        import mediapipe as mp
        from mediapipe.tasks.python import BaseOptions, vision
        self.mp, self.vision = mp, vision
        self.opt = vision.PoseLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=str(fil)), running_mode=vision.RunningMode.VIDEO,
            num_poses=1, min_pose_detection_confidence=MIN_DETEKTION, min_tracking_confidence=MIN_SPARNING)
        self.lm = None
        self.senast = -1

    def borja(self, info: SlagInfo) -> None:
        self.sluta()
        self.lm = self.vision.PoseLandmarker.create_from_options(self.opt)
        self.senast = -1

    def kor(self, bild: np.ndarray, t: float) -> np.ndarray | None:
        # Tiden ska växa i VIDEO-läget; klippet börjar 2,5 s före klicket.
        ms = max(self.senast + 1, int(round((t + 10.0) * 1000)))
        self.senast = ms
        r = self.lm.detect_for_video(self.mp.Image(image_format=self.mp.ImageFormat.SRGB,
                                                   data=np.ascontiguousarray(bild)), ms)
        if not r.pose_landmarks:
            return None
        return np.array([[q.x, q.y, q.visibility] for q in r.pose_landmarks[0]], float)

    def sluta(self) -> None:
        if self.lm is not None:
            self.lm.close()
            self.lm = None


class KlippRutor:
    """Klippets rutor med OpenCV, i ordning, parade med Visions tider inom TID_TOL_S
    (klippets tid = Visions tid + klick_i_klipp_s, bara inom [0; klipp_langd_s),
    METOD MS12). Bilden vrids upprätt av OpenCV och skalas till lederna storlek. METOD MF1"""

    def __init__(self):
        import cv2
        self.cv2 = cv2
        self.rest_ms: list[float] = []

    def rutor(self, paket_fil, paket, slag, tider):
        cv2 = self.cv2
        bredd, hojd = slag.lederna["width"], slag.lederna["height"]
        with tempfile.TemporaryDirectory() as tmp, zipfile.ZipFile(paket_fil) as z:
            fil = Path(tmp) / f"{slag.id}{Path(slag.klipp).suffix}"
            fil.write_bytes(P.las_ur_zip(z, paket.fil, slag.klipp))
            cap = cv2.VideoCapture(str(fil))
            if hasattr(cv2, "CAP_PROP_ORIENTATION_AUTO"):
                cap.set(cv2.CAP_PROP_ORIENTATION_AUTO, 1)
            try:
                i, n = 0, len(tider)
                while i < n:
                    ok, ram = cap.read()
                    if not ok:
                        break
                    tk = cap.get(cv2.CAP_PROP_POS_MSEC) / 1000.0
                    if not P.i_klippet(slag, tk):
                        continue
                    while i < n and tider[i] + slag.klick_i_klipp_s < tk - TID_TOL_S:
                        yield tider[i], None
                        i += 1
                    if i < n and abs(tider[i] + slag.klick_i_klipp_s - tk) <= TID_TOL_S:
                        self.rest_ms.append((tk - tider[i] - slag.klick_i_klipp_s) * 1000.0)
                        yield tider[i], self._upprat(ram, bredd, hojd)
                        i += 1
                while i < n:
                    yield tider[i], None
                    i += 1
            finally:
                cap.release()

    def _upprat(self, ram: np.ndarray, bredd: int, hojd: int) -> np.ndarray:
        h, w = ram.shape[:2]
        if (w > h) != (bredd > hojd) and w != h:
            raise S3Fel("klippets bild ligger ner: OpenCV vred den inte upprätt (uppdatera opencv-python)")
        if (w, h) != (bredd, hojd):
            ram = self.cv2.resize(ram, (bredd, hojd))
        return self.cv2.cvtColor(ram, self.cv2.COLOR_BGR2RGB)


# --- en körning per slag -------------------------------------------------------------

def _leder(serie: dict) -> tuple[np.ndarray, np.ndarray]:
    """JointSeries → (t (n,), (n, 13, 3) x, y, konfidens med NaN för saknad), sorterat.
    Formen är redan kontrollerad (paket.las, eller MediaPipes egen serie)."""
    fr = sorted(serie["frames"], key=lambda r: r["t"])
    t = np.array([float(r["t"]) for r in fr])
    a = np.full((len(fr), ANTAL_LEDER, 3), np.nan)
    for i, r in enumerate(fr):
        for j, led in enumerate(r["joints"]):
            if led is None:
                continue
            v = (led["x"], led["y"], led["c"]) if isinstance(led, dict) else led
            if v[2] >= MIN_KONFIDENS:
                a[i, j] = v
    return t, a


def till_leder(punkter: np.ndarray | None, ruta: tuple[int, int, int, int], bredd: int,
               hojd: int) -> list:
    """MediaPipes 33 punkter (normerade i utsnittet) → filens 13 leder i hela bildens
    pixlar, `[x, y, synlighet]` eller None. En punkt utanför utsnittet sparas som saknad,
    som telefonen gör med Visions (METOD MS13). METOD MF1"""
    if punkter is None:
        return [None] * ANTAL_LEDER
    x0, y0, b, h = ruta
    andel = (x0 / bredd, y0 / hojd, b / bredd, h / hojd)
    ut = []
    for k in MP_INDEX:
        u, v, c = (float(x) for x in punkter[k])
        if not (0.0 <= u <= 1.0 and 0.0 <= v <= 1.0) or not math.isfinite(c):
            ut.append(None)
            continue
        x, y = P.fran_utsnittet(u, v, andel, bredd, hojd)
        ut.append([round(x, 1), round(y, 1), round(c, 3)])
    return ut


def _ner(img: np.ndarray, bredd: int) -> np.ndarray:
    """Närmaste granne ned till `bredd` px, utan beroenden."""
    h, w = img.shape[:2]
    hojd = max(1, int(round(h * bredd / w)))
    ys = np.minimum((np.arange(hojd) * h / hojd).astype(int), h - 1)
    xs = np.minimum((np.arange(bredd) * w / bredd).astype(int), w - 1)
    return img[ys][:, xs].copy()


def kor_slag(paket_fil: Path, p: P.Paket, s: P.Slag, modell: Modell | None, rutkalla: Rutkalla | None,
             mp_serie: dict | None, kontakt_tider: dict[str, float] | None) -> tuple[dict | None, dict]:
    """MediaPipe på slagets rutor (eller den sparade serien) och kontaktarkets rutor.
    Svarar (MediaPipes JointSeries, {kolumn: utsnittet nedskalat}). METOD MF1, MF4"""
    bredd, hojd = s.lederna["width"], s.lederna["height"]
    ruta = P.utsnitt_px(p.serier[s.serie].utsnitt if s.serie in p.serier else None, bredd, hojd)
    x0, y0, b, h = ruta
    t_v, _ = _leder(s.lederna)
    tider = [float(x) for x in t_v]
    onskade: dict[float, str] = {}
    if kontakt_tider:
        for kol, tk in kontakt_tider.items():
            onskade[tider[int(np.argmin(np.abs(t_v - tk)))]] = kol
    bilder: dict[str, np.ndarray] = {}
    kor_modellen = mp_serie is None
    if not kor_modellen and not onskade:
        return mp_serie, bilder
    if rutkalla is None:
        return mp_serie, bilder
    frames = []
    if kor_modellen:
        modell.borja(SlagInfo(fil=p.fil, vy=p.vy, slag=s.id, bredd=bredd, hojd=hojd, ruta=ruta))
    try:
        for t, bild in rutkalla.rutor(paket_fil, p, s, tider):
            if bild is None:
                continue
            utsnitt = bild[y0:y0 + h, x0:x0 + b]
            if t in onskade:
                bilder[onskade[t]] = _ner(utsnitt, KONTAKT_BREDD)
            if kor_modellen:
                frames.append({"t": t, "joints": till_leder(modell.kor(utsnitt, t), ruta, bredd, hojd)})
    finally:
        if kor_modellen:
            modell.sluta()
    if kor_modellen:
        mp_serie = {"source": "mediapipe-pose-heavy", "width": bredd, "height": hojd,
                    "utsnitt_px": list(ruta), "frames": frames}
    return mp_serie, bilder


# --- jämförelsen ---------------------------------------------------------------------

def _fas(t: float, f: dict | None) -> str | None:
    """Rutans fas ur slagets faser (METOD M4): före baksvingens start (eller toppen −
    1,2 s), baksvingen, nedsvingen, från träffen. METOD MF2"""
    if f is None:
        return None
    s0 = f["start"] if f.get("start") is not None else f["topp"] - F.TOPP_ADRESS_S
    if t < s0:
        return "adress"
    if t < f["topp"]:
        return "baksving"
    if t < f["traff"]:
        return "nedsving"
    return "efter_traff"


def _robust_sd(x: np.ndarray) -> float:
    """MAD → sd (METOD M25)."""
    return S.MAD_SKALA * float(np.median(np.abs(x - np.median(x))))


def _stat_led(dx: np.ndarray, dy: np.ndarray) -> dict:
    """En leds avvikelser (Vision − MediaPipe) i en enhet: medelavståndet och dess
    spridning, den fasta delen (medianens vektor, per axel), den rörliga delen (robust sd
    per axel) och utliggarna (> 3 robusta sd från medianen, M25). METOD MF2"""
    d = np.hypot(dx, dy)
    mx, my = float(np.median(dx)), float(np.median(dy))
    sx, sy = _robust_sd(dx), _robust_sd(dy)
    rorligt = math.sqrt((sx * sx + sy * sy) / 2)
    gr = S.MAD_GRANS * rorligt * math.sqrt(2)
    utl = int(np.sum(np.hypot(dx - mx, dy - my) > gr)) if rorligt > 0 else 0
    return {"n": int(len(d)), "medel": float(np.mean(d)), "spridning": float(np.std(d, ddof=1)) if len(d) > 1 else 0.0,
            "fast_x": mx, "fast_y": my, "fast": math.sqrt((mx * mx + my * my) / 2), "rorligt": rorligt,
            "utliggare": utl}


def _sla_ihop(delar: list[dict]) -> dict:
    """Flera leders stat → en: viktat på antalet rutor (medel och kvadraterna)."""
    n = sum(d["n"] for d in delar)
    if n == 0:
        return {"n": 0}
    v = lambda k: sum(d[k] * d["n"] for d in delar) / n  # noqa: E731
    k2 = lambda k: math.sqrt(sum(d[k] ** 2 * d["n"] for d in delar) / n)  # noqa: E731
    medel = v("medel")
    # spridningen ur delarnas medel och spridning (variansen kring det gemensamma medlet)
    var = sum(((d["n"] - 1) * d["spridning"] ** 2 + d["n"] * (d["medel"] - medel) ** 2) for d in delar)
    return {"n": n, "medel": medel, "spridning": math.sqrt(var / max(1, n - 1)), "fast": k2("fast"),
            "rorligt": k2("rorligt"), "utliggare": sum(d["utliggare"] for d in delar)}


@dataclass
class Insamling:
    """Avvikelserna per (vy, led, fas), i px och i % av kroppslängden, och räkningarna."""

    def __post_init__(self):
        self.d: dict[tuple[str, int, str], list[np.ndarray]] = {}
        self.rakna: dict[tuple[str, int, str], np.ndarray] = {}   # rutor, V saknar, MP saknar, V saknar där MP ser
        self.sidbyte: dict[tuple[str, str], list[int]] = {}

    def lagg_till(self, vy: str, tv: np.ndarray, V: np.ndarray, Mp: np.ndarray, faser: dict | None,
                  kropp_px: float | None) -> None:
        for i, t in enumerate(tv):
            fas = _fas(float(t), faser) or "okand"
            for j in range(ANTAL_LEDER):
                v_ok, m_ok = np.isfinite(V[i, j, 0]), np.isfinite(Mp[i, j, 0])
                r = self.rakna.setdefault((vy, j, fas), np.zeros(4, int))
                r += (1, not v_ok, not m_ok, (not v_ok) and m_ok)
                if v_ok and m_ok:
                    dx, dy = V[i, j, 0] - Mp[i, j, 0], V[i, j, 1] - Mp[i, j, 1]
                    pr = 100.0 / kropp_px if kropp_px else math.nan
                    self.d.setdefault((vy, j, fas), []).append(np.array([dx, dy, dx * pr, dy * pr]))
            for namn, a, b in PAR:
                if not (np.isfinite(V[i, [a, b], 0]).all() and np.isfinite(Mp[i, [a, b], 0]).all()):
                    continue
                lika = np.hypot(*(V[i, a, :2] - Mp[i, a, :2])) + np.hypot(*(V[i, b, :2] - Mp[i, b, :2]))
                bytt = np.hypot(*(V[i, a, :2] - Mp[i, b, :2])) + np.hypot(*(V[i, b, :2] - Mp[i, a, :2]))
                c = self.sidbyte.setdefault((vy, namn), [0, 0])
                c[0] += 1
                c[1] += int(bytt < SIDBYTE_KVOT * lika)

    def _per_led(self, vy: str, j: int, faser: tuple[str, ...]) -> tuple[dict | None, dict | None]:
        rader = [x for f in faser for x in self.d.get((vy, j, f), [])]
        if not rader:
            return None, None
        a = np.array(rader)
        px = _stat_led(a[:, 0], a[:, 1])
        ok = np.isfinite(a[:, 2])
        pr = _stat_led(a[ok, 2], a[ok, 3]) if ok.sum() > 1 else None
        return px, pr

    def tabell(self) -> list[dict]:
        """En rad per (vy, led, fas), också `alla` leder och `alla` faser. METOD MF2"""
        ut = []
        vyer = sorted({k[0] for k in self.rakna})
        for vy in vyer:
            for fas in FASER_S3 + ("alla",):
                fz = tuple(f for f in FASER_S3 + ("okand",)) if fas == "alla" else (fas,)
                delar_px, delar_pr, rakna_alla = [], [], np.zeros(4, int)
                for j in range(ANTAL_LEDER):
                    rk = sum((self.rakna.get((vy, j, f), np.zeros(4, int)) for f in fz), np.zeros(4, int))
                    rakna_alla += rk
                    px, pr = self._per_led(vy, j, fz)
                    if px:
                        delar_px.append(px)
                    if pr:
                        delar_pr.append(pr)
                    ut.append(_rad(vy, LEDER_FIL[j], fas, px, pr, rk))
                ut.append(_rad(vy, "alla", fas, _sla_ihop(delar_px) if delar_px else None,
                               _sla_ihop(delar_pr) if delar_pr else None, rakna_alla))
        return ut

    def sidbyten(self) -> list[dict]:
        return [{"vy": vy, "par": namn, "n": c[0], "andel": c[1] / c[0] if c[0] else None}
                for (vy, namn), c in sorted(self.sidbyte.items())]


def _rad(vy, led, fas, px, pr, rk) -> dict:
    rutor = int(rk[0])
    return {"vy": vy, "led": led, "fas": fas, "rutor": rutor, "n": px["n"] if px else 0,
            "px": _avrunda(px), "procent": _avrunda(pr),
            "utliggare": (px["utliggare"] / px["n"]) if px and px["n"] else None,
            "vision_saknar": rk[1] / rutor if rutor else None,
            "mediapipe_saknar": rk[2] / rutor if rutor else None,
            "vision_saknar_mp_ser": rk[3] / rutor if rutor else None}


def _avrunda(d: dict | None) -> dict | None:
    if not d or d.get("n", 0) == 0:
        return None
    return {k: round(d[k], 3) for k in ("medel", "spridning", "fast", "rorligt") if k in d}


def jamfor_matt(rader: list[dict]) -> tuple[list[dict], list[dict]]:
    """Måtten per vy: passets median för Vision och MediaPipe (M25), skillnaden och
    om den är tydlig i M26:s mening (större än MediaPipe-passets robusta sd), och
    skillnaden slag för slag. Fasernas tider likadant, i ms. METOD MF3"""
    matt_ut, faser_ut = [], []
    for vy in sorted({r["vy"] for r in rader}):
        par = [r for r in rader if r["vy"] == vy and r.get("vision") and r.get("mediapipe")]
        sv = S.sammanfatta([r["vision"]["matt"] for r in par])
        smp = S.sammanfatta([r["mediapipe"]["matt"] for r in par])
        for k in M.MATT[vy]:
            d = [r["vision"]["matt"][k] - r["mediapipe"]["matt"][k] for r in par
                 if k in r["vision"]["matt"] and k in r["mediapipe"]["matt"]]
            if not d:
                continue
            rad = {"vy": vy, "matt": k, "enhet": enhet(k), "n": len(d),
                   "skillnad_medel": float(np.mean(d)), "skillnad_sd": float(np.std(d, ddof=1)) if len(d) > 1 else None,
                   "abs_medel": float(np.mean(np.abs(d))),
                   "vision_median": sv[k]["median"] if k in sv else None,
                   "mediapipe_median": smp[k]["median"] if k in smp else None,
                   "mediapipe_spridning": S.robust_sd(smp[k]) if k in smp else None}
            rad["skillnad"] = (rad["vision_median"] - rad["mediapipe_median"]
                               if rad["vision_median"] is not None and rad["mediapipe_median"] is not None else None)
            rad["tydlig"] = (abs(rad["skillnad"]) > rad["mediapipe_spridning"]
                             if rad["skillnad"] is not None and rad["mediapipe_spridning"] is not None else None)
            matt_ut.append(rad)
        for fas in ("start", "topp"):
            d = [(r["vision"]["faser"][fas] - r["mediapipe"]["faser"][fas]) * 1000.0 for r in par
                 if r["vision"]["faser"].get(fas) is not None and r["mediapipe"]["faser"].get(fas) is not None]
            if d:
                faser_ut.append({"vy": vy, "fas": fas, "n": len(d), "skillnad_medel_ms": float(np.mean(d)),
                                 "abs_medel_ms": float(np.mean(np.abs(d))),
                                 "skillnad_sd_ms": float(np.std(d, ddof=1)) if len(d) > 1 else None})
        kv = [r["vision"]["cm_per_px"] / r["mediapipe"]["cm_per_px"] for r in par]
        if kv:
            faser_ut.append({"vy": vy, "fas": "skalan", "n": len(kv), "kvot_median": float(np.median(kv))})
    return matt_ut, faser_ut


def beslut_b5(leder: list[dict], sidbyten: list[dict], matt: list[dict]) -> dict:
    """Det som avgör B5 per vy: lederna mot felbudgetens nivåer (fast, rörligt,
    utliggare; den sämsta av de tre avgör nivån), andelen där Vision saknar leden
    och MediaPipe ser den, sidbytena och hur många mått som skiljer tydligt. METOD MF3"""
    niv = nivaer()
    ut = {}
    for vy in sorted({r["vy"] for r in leder}):
        alla = next(r for r in leder if r["vy"] == vy and r["led"] == "alla" and r["fas"] == "alla")
        pr = alla["procent"]
        rad = {"fast": pr["fast"] if pr else None, "rorligt": pr["rorligt"] if pr else None,
               "utliggare": alla["utliggare"], "vision_saknar_mp_ser": alla["vision_saknar_mp_ser"]}
        niva = None
        if pr:
            for n in NIVAER:
                if (pr["fast"] <= niv[n]["fast"] and pr["rorligt"] <= niv[n]["rorligt"]
                        and (alla["utliggare"] or 0) <= niv[n]["utliggare"]):
                    niva = n
                    break
            niva = niva or "samre_an_daligt"
        rad["niva"] = niva
        sb = [s for s in sidbyten if s["vy"] == vy and s["n"]]
        n_sb = sum(s["n"] for s in sb)
        rad["sidbyten"] = sum(s["andel"] * s["n"] for s in sb) / n_sb if n_sb else None
        mv = [m for m in matt if m["vy"] == vy and m["tydlig"] is not None]
        rad["matt_tydliga"] = sum(1 for m in mv if m["tydlig"])
        rad["matt_provade"] = len(mv)
        ut[vy] = rad
    return ut


# --- kontaktarket --------------------------------------------------------------------

KONTAKT_SLAG = 6             # METOD MF4: rader per vy, jämnt spridda över passet
KONTAKT_BREDD = 200          # METOD MF4: px per ruta
VISION_FARG = (255, 255, 255)
MP_FARG = (255, 150, 0)


def _rita(img: np.ndarray, leder: np.ndarray, farg, r: int) -> None:
    """Lederna (13, ≥2) i bildens px som punkter och linjer i en färg."""
    h, w = img.shape[:2]

    def pkt(x, y, rr):
        xi, yi = int(round(x)), int(round(y))
        img[max(0, yi - rr):min(h, yi + rr + 1), max(0, xi - rr):min(w, xi + rr + 1)] = farg

    for a, b in BEN:
        if np.isfinite(leder[[a, b], :2]).all():
            n = int(max(abs(leder[b, 0] - leder[a, 0]), abs(leder[b, 1] - leder[a, 1]))) + 1
            for u in np.linspace(0.0, 1.0, n):
                pkt(leder[a, 0] + u * (leder[b, 0] - leder[a, 0]), leder[a, 1] + u * (leder[b, 1] - leder[a, 1]), 0)
    for q in leder:
        if np.isfinite(q[:2]).all():
            pkt(q[0], q[1], r)


def kontaktark(rader: list[dict], ut: Path) -> dict:
    """Ett ark per vy: en rad per valt slag, en kolumn per fas (MT7:s tider), utsnittet
    med Visions leder (vita) och MediaPipes (orange). METOD MF4"""
    res = {}
    for vy in sorted({r["vy"] for r in rader}):
        valda = [r for r in rader if r["vy"] == vy and r.get("bilder")]
        if not valda:
            res[vy] = {"hoppat": "inga rutor ur klippen"}
            continue
        kol = ("adress", "topp", "traff", "finish")
        hojd = max(b.shape[0] for r in valda for b in r["bilder"].values())
        ark = np.zeros((len(valda) * (hojd + 2), len(kol) * (KONTAKT_BREDD + 2), 3), np.uint8)
        for i, r in enumerate(valda):
            x0, y0, b, h = r["ruta"]
            for k, namn in enumerate(kol):
                img = r["bilder"].get(namn)
                if img is None:
                    continue
                img = img.copy()
                s = img.shape[1] / b
                for leder, farg, rr in ((r["v_ruta"].get(namn), VISION_FARG, 2), (r["mp_ruta"].get(namn), MP_FARG, 1)):
                    if leder is not None:
                        q = leder.copy()
                        q[:, 0] = (q[:, 0] - x0) * s
                        q[:, 1] = (q[:, 1] - y0) * s
                        _rita(img, q, farg, rr)
                y, x = i * (hojd + 2), k * (KONTAKT_BREDD + 2)
                ark[y:y + img.shape[0], x:x + img.shape[1]] = img
        fil = ut / f"kontaktark-s3-{vy}.png"
        skriv_png(fil, ark)
        res[vy] = {"fil": fil.name, "rader": [f"{r['fil']}:{r['id']}" for r in valda], "kolumner": list(kol)}
    return res


# --- hela körningen ------------------------------------------------------------------

def _mat(p: P.Paket, s: P.Slag, langd: float) -> tuple[dict | None, str | None]:
    try:
        return M.mat(fm.fran_dict(P.till_sving(p, s, langd))), None
    except (fm.FormatFel, F.SvingFel) as e:
        return None, str(e)


def kor(paket_filer: list[Path], ut: Path, langd: float | None, modell: Modell | None, rutkalla: Rutkalla | None,
        om: bool = False, kontakt_slag: int = KONTAKT_SLAG, modell_namn: str = MODELL_FIL) -> dict:
    """Paketen → s3.json, s3.md och kontaktarken i `ut`. `modell` och `rutkalla` får
    vara None när alla slag redan har sparade MediaPipe-leder. METOD MF1–MF4"""
    paket = [(Path(f), P.las(f)) for f in paket_filer]
    ut.mkdir(parents=True, exist_ok=True)
    cache = ut / "mediapipe"
    cache.mkdir(exist_ok=True)
    ins = Insamling()
    rader, slag_ut, paket_ut = [], [], []
    for fil, p in paket:
        lg = langd or p.langd_m
        if lg is None:
            raise S3Fel(f"{p.fil}: spelarens längd saknas i paketet: ange --langd")
        matbara = [s for s in p.slag if s.dom in P.MATS and not s.detection_wrong]
        med_klipp = [s for s in matbara if s.klipp]
        val = set(np.unique(np.round(np.linspace(0, len(med_klipp) - 1, min(kontakt_slag, len(med_klipp))))
                            .astype(int)).tolist()) if med_klipp else set()
        info = {"fil": p.fil, "vy": p.vy, "slag": len(p.slag), "matbara": len(matbara), "med_klipp": len(med_klipp),
                "korda": 0, "rutor": 0, "rutor_med_bild": 0}
        for k, s in enumerate(med_klipp):
            vr, vfel = _mat(p, s, lg)
            cfil = cache / f"{Path(p.fil).stem}-{s.id}.json"
            mp_serie = None
            if cfil.is_file() and not om:
                try:
                    mp_serie = json.loads(cfil.read_text(encoding="utf-8"))
                except (OSError, json.JSONDecodeError):
                    mp_serie = None
            behover = mp_serie is None
            kt = None
            if k in val:
                kt = kolumntider(vr["faser"]) if vr else None
            if behover and (modell is None or rutkalla is None):
                raise S3Fel("MediaPipe behövs men är inte laddad")
            mp_serie, bilder = kor_slag(fil, p, s, modell, rutkalla, mp_serie, kt)
            if behover:
                cfil.write_text(json.dumps(mp_serie, separators=(",", ":")), encoding="utf-8")
            info["korda"] += 1
            info["rutor"] += len(s.lederna["frames"])
            info["rutor_med_bild"] += len(mp_serie["frames"])
            ms = replace(s, lederna={**s.lederna, "frames": mp_serie["frames"]})
            mr, mfel = _mat(p, ms, lg) if mp_serie["frames"] else (None, "inga rutor ur klippet")
            rad = {"fil": p.fil, "id": s.id, "vy": p.vy, "vision": vr, "mediapipe": mr}
            slag_ut.append({"fil": p.fil, "id": s.id, "vy": p.vy, "rutor": len(mp_serie["frames"]),
                            **({"vision_fel": vfel} if vfel else {}), **({"mediapipe_fel": mfel} if mfel else {})})
            # Lederna ruta för ruta, på rutorna som MediaPipe fick.
            tv, V = _leder(s.lederna)
            tm, Mp = _leder({"frames": mp_serie["frames"]})
            plats = {float(t): i for i, t in enumerate(tv)}
            idx = [plats[float(t)] for t in tm if float(t) in plats]
            idm = [i for i, t in enumerate(tm) if float(t) in plats]
            faser = (mr or vr or {}).get("faser")
            ref = mr or vr
            kropp = lg * 100.0 / ref["cm_per_px"] if ref else None
            if idx:
                ins.lagg_till(p.vy, tv[idx], V[idx], Mp[idm], faser, kropp)
            if bilder:
                rad["bilder"] = bilder
                rad["ruta"] = P.utsnitt_px(p.serier[s.serie].utsnitt, s.lederna["width"], s.lederna["height"])
                rad["v_ruta"], rad["mp_ruta"] = {}, {}
                for namn, tk in (kt or {}).items():
                    if len(tv):
                        rad["v_ruta"][namn] = V[int(np.argmin(np.abs(tv - tk)))]
                    if len(tm):
                        rad["mp_ruta"][namn] = Mp[int(np.argmin(np.abs(tm - tk)))]
            rader.append(rad)
        for s in matbara:
            if not s.klipp:
                slag_ut.append({"fil": p.fil, "id": s.id, "vy": p.vy, "hoppat": "inget klipp i paketet"})
        paket_ut.append(info)
    leder = ins.tabell()
    sidb = ins.sidbyten()
    matt, faser = jamfor_matt(rader)
    res = {"format": FORMAT, "pass": sorted({p.pass_id for _, p in paket}),
           "skapad": datetime.now().astimezone().isoformat(timespec="seconds"),
           "modell": {"fil": modell_namn, "lage": "VIDEO"}, "paket": paket_ut,
           "nivaer": nivaer(), "beslut_b5": beslut_b5(leder, sidb, matt), "leder": leder, "sidbyten": sidb,
           "matt": matt, "faser": faser, "slag": slag_ut, "kontaktark": kontaktark(rader, ut)}
    (ut / "s3.json").write_text(json.dumps(res, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    (ut / "s3.md").write_text(markdown(res), encoding="utf-8")
    return res


# --- tabellen ------------------------------------------------------------------------

def _t(v, d: int = 1, pct: bool = False) -> str:
    if v is None or (isinstance(v, float) and not math.isfinite(v)):
        return "–"
    return f"{v * 100:.{d}f} %" if pct else f"{v:.{d}f}"


def markdown(r: dict) -> str:
    niv = r["nivaer"]
    vyer = list(r["beslut_b5"])
    rad = lambda c: "| " + " | ".join(c) + " |"  # noqa: E731
    hd = lambda c: [rad(c), rad(["---"] * len(c))]  # noqa: E731
    L = [f"# S3: Vision mot MediaPipe — pass {', '.join(r['pass'])}", "",
         f"Modellen: `{r['modell']['fil']}` ({r['modell']['lage']}). Skapad {r['skapad']}. "
         "Avvikelsen är Vision − MediaPipe; MediaPipe är facit, inte sanningen (METOD MF2).", "",
         "## Det som avgör B5 (räcker Vision?)", "",
         "Verktyget avgör inte beslutet: tabellen är underlaget (BESLUT B5, B14, B38).", ""]
    b = r["beslut_b5"]

    def tr(n, k, pct=False):
        return " · ".join(f"{NIVA_TEXT[x]} ≤ {_t(niv[x][k], 2, pct)}" + ("" if pct else " %") for x in n)

    L += hd(["Fråga"] + [v.upper() for v in vyer] + ["Tröskel", "Källa"])
    L.append(rad(["Lederna, fast avvikelse per led (per axel, % av kroppslängden)"]
                 + [_t(b[v]["fast"], 2) for v in vyer] + [tr(NIVAER, "fast"), "S6_FELBUDGET §3 (antagande), METOD MF3"]))
    L.append(rad(["Lederna, rörligt fel ruta för ruta (per axel, %)"]
                 + [_t(b[v]["rorligt"], 2) for v in vyer] + [tr(NIVAER, "rorligt"), "S6_FELBUDGET §3 (antagande), METOD MF3"]))
    L.append(rad(["Utliggare (andel rutor)"] + [_t(b[v]["utliggare"], 1, True) for v in vyer]
                 + [tr(NIVAER, "utliggare", True), "S6_FELBUDGET §3 (antagande), METOD MF3"]))
    L.append(rad(["**Felbudgetens nivå** (den sämsta av de tre)"] + [f"**{NIVA_TEXT.get(b[v]['niva'], '–')}**" for v in vyer]
                 + ["typiskt räcker för trenden utan markörer", "BESLUT B14, S6_FELBUDGET §6.7"]))
    L.append(rad(["Vision saknar leden där MediaPipe ser den"] + [_t(b[v]["vision_saknar_mp_ser"], 1, True) for v in vyer]
                 + ["ingen källa", "–"]))
    L.append(rad(["Vänster och höger förväxlade"] + [_t(b[v]["sidbyten"], 1, True) for v in vyer]
                 + ["ingen källa", "–"]))
    L.append(rad(["Mått där passets median skiljer tydligt"]
                 + [f"{b[v]['matt_tydliga']} av {b[v]['matt_provade']}" for v in vyer]
                 + ["skillnaden > MediaPipe-passets robusta sd", "METOD M26 (formen; ingen källa för B5)"]))
    L += ["", "## Paketen", ""]
    L += hd(["Paket", "Vy", "Slag", "Mätbara", "Med klipp", "Körda", "Rutor", "Med bild"])
    for p in r["paket"]:
        L.append(rad([p["fil"], p["vy"], str(p["slag"]), str(p["matbara"]), str(p["med_klipp"]), str(p["korda"]),
                      str(p["rutor"]), str(p["rutor_med_bild"])]))
    L += ["", "## Lederna per led (alla faser)", "",
          "Medel och spridning = avståndet Vision–MediaPipe. Fast = medianens förskjutning, "
          "rörligt = robust sd, båda per axel (METOD MF2).", ""]
    for vy in vyer:
        L += [f"### {vy.upper()}", ""]
        L += hd(["Led", "n", "Medel px", "Spridning px", "Medel %", "Spridning %", "Fast %", "Rörligt %",
                 "Utliggare", "Vision saknar", "MediaPipe saknar"])
        for x in (y for y in r["leder"] if y["vy"] == vy and y["fas"] == "alla"):
            px, pr = x["px"] or {}, x["procent"] or {}
            L.append(rad([x["led"], str(x["n"]), _t(px.get("medel")), _t(px.get("spridning")),
                          _t(pr.get("medel"), 2), _t(pr.get("spridning"), 2), _t(pr.get("fast"), 2),
                          _t(pr.get("rorligt"), 2), _t(x["utliggare"], 1, True), _t(x["vision_saknar"], 1, True),
                          _t(x["mediapipe_saknar"], 1, True)]))
        L.append("")
    L += ["## Lederna per fas (medelavvikelse i % av kroppslängden; Vision saknar inom parentes)", ""]
    for vy in vyer:
        L += [f"### {vy.upper()}", ""]
        L += hd(["Led"] + list(FASER_S3) + ["alla"])
        for led in list(LEDER_FIL) + ["alla"]:
            celler = []
            for fas in FASER_S3 + ("alla",):
                x = next((y for y in r["leder"] if y["vy"] == vy and y["led"] == led and y["fas"] == fas), None)
                pr = (x or {}).get("procent") or {}
                celler.append(f"{_t(pr.get('medel'), 2)} ({_t((x or {}).get('vision_saknar'), 0, True)})")
            L.append(rad([led] + celler))
        L.append("")
    L += ["## Förväxlade sidor", ""]
    L += hd(["Vy", "Par", "Rutor", "Andel"])
    for s in r["sidbyten"]:
        L.append(rad([s["vy"], s["par"], str(s["n"]), _t(s["andel"], 1, True)]))
    L += ["", "## Måtten (S1) på båda ledkällorna", "",
          "Skillnad = passets median Vision − MediaPipe. Tydlig = större än MediaPipe-passets "
          "robusta sd (formen i METOD M26).", ""]
    L += hd(["Vy", "Mått", "Enhet", "n", "Vision", "MediaPipe", "Skillnad", "Slag för slag: medel ± sd",
             "Medel |skillnad|", "MediaPipe sd", "Tydlig"])
    for m in sorted(r["matt"], key=lambda m: (m["vy"], not m["tydlig"], m["matt"])):
        sd = f" ± {_t(m['skillnad_sd'], 2)}" if m["skillnad_sd"] is not None else ""
        L.append(rad([m["vy"], m["matt"], m["enhet"], str(m["n"]), _t(m["vision_median"], 2),
                      _t(m["mediapipe_median"], 2), _t(m["skillnad"], 2), _t(m["skillnad_medel"], 2) + sd,
                      _t(m["abs_medel"], 2), _t(m["mediapipe_spridning"], 2),
                      "ja" if m["tydlig"] else ("nej" if m["tydlig"] is not None else "–")]))
    L += ["", "## Faserna och skalan", ""]
    L += hd(["Vy", "Vad", "n", "Vision − MediaPipe"])
    for f in r["faser"]:
        v = (f"kvot {f['kvot_median']:.3f}" if f["fas"] == "skalan" else
             f"{f['skillnad_medel_ms']:.1f} ms (medel |·| {f['abs_medel_ms']:.1f} ms)")
        L.append(rad([f["vy"], f["fas"], str(f["n"]), v]))
    L += ["", "## Kontaktarken", "", "Vitt = Vision, orange = MediaPipe. Kolumnerna: adress, topp, träff, finish.", ""]
    for vy, k in r["kontaktark"].items():
        L.append(f"- {vy.upper()}: " + (f"`{k['fil']}` ({len(k['rader'])} slag)" if "fil" in k else f"hoppat ({k['hoppat']})"))
    fel = [s for s in r["slag"] if "vision_fel" in s or "mediapipe_fel" in s or "hoppat" in s]
    if fel:
        L += ["", "## Slag som inte jämfördes helt", ""]
        for s in fel:
            L.append(f"- {s['fil']} {s['id']}: " + "; ".join(
                f"{k.replace('_', ' ')}: {s[k]}" for k in ("hoppat", "vision_fel", "mediapipe_fel") if k in s))
    return "\n".join(L) + "\n"


# --- kommandot -----------------------------------------------------------------------

def standard_ut(paket_filer: list[str]) -> Path:
    """~/swinglab-s3/<pass>/ ur första paketets manifest (utan att läsa lederna)."""
    pass_id = sorted({P.las(f, med_leder=False).pass_id for f in paket_filer})
    return UT_ROT / ("-".join([pass_id[0], pass_id[-1]]) if len(pass_id) > 1 else pass_id[0])


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="S3: MediaPipe heavy mot Vision på paketets klipp.")
    ap.add_argument("paket", nargs="+", help="swinglab-<pass>-<vy>.zip")
    ap.add_argument("--ut", help="utmappen (standard ~/swinglab-s3/<pass>/), aldrig i repot")
    ap.add_argument("--langd", type=float, help="spelarens längd i m om paketet saknar den")
    ap.add_argument("--om", action="store_true", help="kör MediaPipe igen även där lederna är sparade")
    ap.add_argument("--modell", help=f"sökvägen till {MODELL_FIL} (annars ~/.cache/swinglab/mediapipe/)")
    ap.add_argument("--kontakt-slag", type=int, default=KONTAKT_SLAG, help="rader per vy i kontaktarket")
    a = ap.parse_args(argv)
    try:
        ut = Path(a.ut).expanduser() if a.ut else standard_ut(a.paket)
        if not S.utanfor_repot(ut):
            print("--ut: mappen ligger i repot; passets data får inte hamna i git.")
            return 1
        saknas = saknade_beroenden()
        if saknas:
            print("S3 kräver MediaPipe och OpenCV. Installera dem med:\n  " + PIP
                  + f"\nModellen hämtas sedan automatiskt till {MODELL_MAPP / MODELL_FIL}"
                  + f"\n(eller hämta den själv från {MODELL_URL} och lägg den där).")
            return 1
        fil = modellfil(a.modell)
        print(f"MediaPipe: {fil}\nUt: {ut}", flush=True)
        res = kor([Path(f) for f in a.paket], ut, a.langd, MediaPipeModell(fil), KlippRutor(), om=a.om,
                  kontakt_slag=a.kontakt_slag)
    except P.PaketFel as e:
        print("Paketet går inte att läsa:\n  " + "\n  ".join(e.fel))
        return 1
    except S3Fel as e:
        print(str(e))
        return 1
    for vy, b in res["beslut_b5"].items():
        print(f"  {vy.upper()}: felbudgetens nivå {NIVA_TEXT.get(b['niva'], '–')}, fast {_t(b['fast'], 2)} %, rörligt "
              f"{_t(b['rorligt'], 2)} %, {b['matt_tydliga']} av {b['matt_provade']} mått skiljer tydligt")
    print(f"Skrev {ut / 's3.md'}, s3.json och kontaktarken")
    return 0


if __name__ == "__main__":
    sys.exit(main())
