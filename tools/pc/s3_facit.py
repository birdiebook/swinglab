"""S3: facit för lederna. MediaPipe Pose heavy mot telefonens Vision på samma rutor
(PLAN S3, BESLUT B5, BESLUT B43, METOD MF1–MF4).

    python tools/pc/s3_facit.py <paket.zip> [fler paket] [--ut <mapp>] [--langd 1.80] [--om]

För varje mätt slag med klipp i paketet: MediaPipe heavy på varje ruta i klippet, i
samma utsnitt som telefonen (`paket.utsnitt_px`, BESLUT B34), med punkterna tillbaka i
hela bildens pixlar. Klippets tider (OpenCV) och Visions tider skiljer sig med en
förskjutning per klipp, som skattas ur handledernas banor (MF1); ett slag där den är
tvetydig jämförs inte. Sedan:

- **lederna** per led, fas och vy: medelavvikelsen och spridningen i px och i % av
  kroppslängden, den fasta och den rörliga delen och utliggarna (MF2), andelen rutor
  där Vision saknar leden, och förväxlade sidor;
- **måtten** (S1, `matt.mat`) på båda ledkällorna, parade per slag (MF3);
- överst det som avgör **B5** (räcker Vision?), för hela svingen och för nedsvingen,
  med trösklar ur en simulering av felbudgetens brus i båda källorna (MF3), och
  bootstrap över slagen;
- ett **kontaktark** per vy med båda ledsatserna på några rutor per fas (MF4).

Allt skrivs till en mapp **utanför repot**, som standard `~/swinglab-s3/<pass>/`
(Johannes data, CLAUDE.md Dataregeln): `s3.md`, `s3.json`, `kontaktark-s3-<vy>.png`
och MediaPipes leder per slag i `mediapipe/` (återanvänds nästa körning när utsnittet,
bildens storlek och modellen är desamma; `--om` kör om).

MediaPipe och OpenCV importeras först när de behövs; saknas de säger skriptet vad som
ska installeras. Modellen hämtas till `~/.cache/swinglab/mediapipe/` (BESLUT B43).
"""
from __future__ import annotations

import argparse
import functools
import warnings
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
from . import klipp as KL  # noqa: E402
from . import matt as M  # noqa: E402
from . import paket as P  # noqa: E402
from . import session as S  # noqa: E402
from .analys import enhet  # noqa: E402
from .format import ANTAL_LEDER, LEDER_FIL, MIN_KONFIDENS  # noqa: E402
from .kontaktark import BEN, skriv_png, tider as kolumntider  # noqa: E402
from .tre_d import kamera as KM  # noqa: E402

FORMAT = "swinglab-s3/2"
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
HANDLEDER = (LEDER_FIL.index("handled_v"), LEDER_FIL.index("handled_h"))
MIN_DETEKTION = 0.5          # METOD MF1: MediaPipes detektion och spårning, som Golf SG
MIN_SPARNING = 0.5           # METOD MF1
TID_TOL_S = 0.002            # METOD MF1: en klippruta hör till Visions ruta inom 2 ms
SOK_RUTOR = 3                # METOD MF1: förskjutningen söks ±3 rutor
TVETYDIG_KVOT = 1.1          # METOD MF1: näst bästa förskjutningen inom 10 % = tvetydig
MIN_PAR_FORSKJ = 20          # METOD MF1: rutor med handlederna i båda för att skatta den
RORELSE_S = (0.3, 0.3)       # METOD MF1: handledernas bana jämförs från toppen − 0,3 s till träffen + 0,3 s
BILD_MARGINAL_S = 0.05       # METOD MF1: IMAGE-läget körs på fönstret ± 50 ms (förskjutningen är okänd)
CACHE_VERSION = 3            # sparade MediaPipe-leder: formen (IMAGE-lederna, klippets CRC)

FASER_S3 = ("adress", "baksving", "nedsving", "efter_traff")    # METOD MF2
PAR = (("axel", 1, 2), ("armbage", 3, 4), ("handled", 5, 6), ("hoft", 7, 8), ("kna", 9, 10),
       ("fotled", 11, 12))
SIDBYTE_KVOT = 0.5           # METOD MF2: bytta sidor ger under halva avståndet = förväxlade
MIN_SLAG = 5                 # METOD MF2: färre slag ger "–" i det som avgör B5 och i måtten
BOOTSTRAP = 100              # METOD MF2: dragningar av slagen för intervallen
BOOTSTRAP_SEED = 1

# METOD MF3: trösklarna simuleras ur felbudgetens brus (docs/S6_FELBUDGET.md §3) i båda
# källorna: Vision på varje nivå, MediaPipe på en antagen nivå.
NIVAER = ("bra", "typiskt", "daligt")
NIVA_TEXT = {"bra": "bra", "typiskt": "typiskt", "daligt": "dåligt", "samre_an_daligt": "sämre än dåligt"}
MP_ANTAGEN = "bra"           # METOD MF3: MediaPipe heavy antas på felbudgetens nivå "bra"
SIM_PASS = 5                 # METOD MF3
SIM_SLAG = 10                # METOD MF3
SIM_SEED = 1
GROV_PROCENT = 5.0           # METOD MF3: en grov avvikelse är över 5 % av kroppslängden
B5_FASER = ("alla", "nedsving")


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
    ruta: tuple[float, float, float, float]   # utsnittet som modellen ser, i ledernas px


class Modell(Protocol):
    """Posemodellen bakom ett gränssnitt, så att testerna kör utan MediaPipe."""

    def borja(self, info: SlagInfo) -> None: ...

    def kor(self, bild: np.ndarray, t: float) -> np.ndarray | None:
        """VIDEO-läget (spårning mellan rutorna). bild = utsnittet (h, b, 3) RGB uint8;
        t = rutans tid i klippet (OpenCV). Svarar (33, 3): x och y normerade i utsnittet
        (origo uppe till vänster), synlighet."""
        ...

    def kor_bild(self, bild: np.ndarray) -> np.ndarray | None:
        """IMAGE-läget: rutan för sig, utan spårning och utjämning (för tidsparningen)."""
        ...

    def sluta(self) -> None: ...


class Rutkalla(Protocol):
    def rutor(self, paket_fil: Path, paket: P.Paket, slag: P.Slag) -> Iterator[tuple[float, np.ndarray]]:
        """Varje ruta i slagets klipp: (tiden i klippet enligt läsaren, upprätt RGB)."""
        ...

    def vid(self, paket_fil: Path, paket: P.Paket, slag: P.Slag,
            tider: list[float]) -> dict[float, tuple[float, np.ndarray]]:
        """Rutorna närmast tiderna inom TID_TOL_S: {önskad tid: (rutans tid, bild)}."""
        ...

    def start_tid(self, paket_fil: Path, paket: P.Paket, slag: P.Slag) -> float | None:
        """Klippets start_time ur ffprobe (s), eller None utan ffprobe."""
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
        self.opt_bild = vision.PoseLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=str(fil)), running_mode=vision.RunningMode.IMAGE,
            num_poses=1, min_pose_detection_confidence=MIN_DETEKTION)
        self.lm = None
        self.lm_bild = vision.PoseLandmarker.create_from_options(self.opt_bild)
        self.senast = -1

    def borja(self, info: SlagInfo) -> None:
        self.sluta()
        self.lm = self.vision.PoseLandmarker.create_from_options(self.opt)
        self.senast = -1

    def kor(self, bild: np.ndarray, t: float) -> np.ndarray | None:
        ms = max(self.senast + 1, int(round(t * 1000)))      # tiden ska växa i VIDEO-läget
        self.senast = ms
        r = self.lm.detect_for_video(self.mp.Image(image_format=self.mp.ImageFormat.SRGB,
                                                   data=np.ascontiguousarray(bild)), ms)
        if not r.pose_landmarks:
            return None
        return np.array([[q.x, q.y, q.visibility] for q in r.pose_landmarks[0]], float)

    def kor_bild(self, bild: np.ndarray) -> np.ndarray | None:
        r = self.lm_bild.detect(self.mp.Image(image_format=self.mp.ImageFormat.SRGB,
                                              data=np.ascontiguousarray(bild)))
        if not r.pose_landmarks:
            return None
        return np.array([[q.x, q.y, q.visibility] for q in r.pose_landmarks[0]], float)

    def sluta(self) -> None:
        if self.lm is not None:
            self.lm.close()
            self.lm = None

    def stang(self) -> None:
        """Stänger båda lägena (efter körningen)."""
        self.sluta()
        if self.lm_bild is not None:
            self.lm_bild.close()
            self.lm_bild = None


class KlippRutor:
    """Klippen ur paketet med OpenCV (`klipp.py`): upprätta, i klippets upplösning,
    med OpenCV:s tider. METOD MF1"""

    def _fil(self, tmp: str, paket_fil, paket, slag) -> Path:
        fil = Path(tmp) / f"{slag.id}{Path(slag.klipp).suffix}"
        with zipfile.ZipFile(paket_fil) as z:
            fil.write_bytes(P.las_ur_zip(z, paket.fil, slag.klipp))
        return fil

    def rutor(self, paket_fil, paket, slag):
        with tempfile.TemporaryDirectory() as tmp:
            fil = self._fil(tmp, paket_fil, paket, slag)
            try:
                yield from KL.ramar(fil, slag.lederna["width"], slag.lederna["height"])
            except KL.VridenFel as e:
                raise S3Fel(f"{paket.fil}: {slag.klipp}: {e}") from None

    def vid(self, paket_fil, paket, slag, tider):
        with tempfile.TemporaryDirectory() as tmp:
            fil = self._fil(tmp, paket_fil, paket, slag)
            return KL.ramar_vid(fil, tider, slag.lederna["width"], slag.lederna["height"], TID_TOL_S)

    def start_tid(self, paket_fil, paket, slag):
        with tempfile.TemporaryDirectory() as tmp:
            return KL.start_tid(self._fil(tmp, paket_fil, paket, slag))


# --- lederna och tiderna -------------------------------------------------------------

def _leder(serie: dict, nyckel: str = "t", leder: str = "joints") -> tuple[np.ndarray, np.ndarray]:
    """En serie → (tider (n,), (n, 13, 3) x, y, konfidens med NaN för saknad), sorterat.
    En ruta utan `leder` (IMAGE-lederna utanför fönstret) är helt saknad. Formen är redan
    kontrollerad (paket.las, eller MediaPipes egen serie)."""
    fr = sorted(serie["frames"], key=lambda r: r[nyckel])
    t = np.array([float(r[nyckel]) for r in fr])
    a = np.full((len(fr), ANTAL_LEDER, 3), np.nan)
    for i, r in enumerate(fr):
        for j, led in enumerate(r.get(leder) or []):
            if led is None:
                continue
            v = (led["x"], led["y"], led["c"]) if isinstance(led, dict) else led
            if v[2] >= MIN_KONFIDENS:
                a[i, j] = v
    return t, a


def till_leder(punkter: np.ndarray | None, ruta: tuple[float, float, float, float], bredd: int,
               hojd: int) -> list:
    """MediaPipes 33 punkter (normerade i utsnittet) → filens 13 leder i hela bildens
    pixlar, `[x, y, synlighet]` eller None. `ruta` är utsnittet modellen såg, i ledernas
    px. En punkt utanför utsnittet sparas som saknad, som telefonen gör med Visions
    (METOD MS13). METOD MF1"""
    if punkter is None:
        return [None] * ANTAL_LEDER
    andel = (ruta[0] / bredd, ruta[1] / hojd, ruta[2] / bredd, ruta[3] / hojd)
    ut = []
    for k in MP_INDEX:
        u, v, c = (float(x) for x in punkter[k])
        if not (0.0 <= u <= 1.0 and 0.0 <= v <= 1.0) or not math.isfinite(c):
            ut.append(None)
            continue
        x, y = P.fran_utsnittet(u, v, andel, bredd, hojd)
        ut.append([round(x, 1), round(y, 1), round(c, 3)])
    return ut


def _para(e: np.ndarray, r: np.ndarray, d: float) -> list[tuple[int, int]]:
    """Visions ruta i ↔ klippets ruta j där |r_j − (e_i + d)| ≤ TID_TOL_S, närmast.
    r är stigande."""
    if len(r) == 1:
        j = np.zeros(len(e), int)
    else:
        mal = e + d
        j = np.clip(np.searchsorted(r, mal), 1, len(r) - 1)
        j = np.where(np.abs(r[j - 1] - mal) <= np.abs(r[j] - mal), j - 1, j)
    ok = np.abs(r[j] - (e + d)) <= TID_TOL_S
    return [(int(i), int(j[i])) for i in np.where(ok)[0]]


def para_tider(e: np.ndarray, V: np.ndarray, r: np.ndarray, Mr: np.ndarray, rorelse: np.ndarray) -> dict:
    """Förskjutningen δ mellan klippets tider r (läsarens, stigande) och Visions tider i
    klippet e = t + klick_i_klipp_s, så att r = e + δ för samma ruta. Kandidaterna är
    rutnätet kring δ = 0, ±SOK_RUTOR rutor. För var och en paras rutorna inom TID_TOL_S
    och handledernas medelavstånd Vision–MediaPipe mäts i rutorna `rorelse` (svingens
    snabba del). Den minsta vinner. Tvetydigt: den bästa vid sökningens kant, färre än
    MIN_PAR_FORSKJ rutor med handlederna, eller den näst bästa inom TVETYDIG_KVOT.
    Handledernas fasta skillnad mellan modellerna (medianvektorn per handled och
    kandidat) dras bort innan avståndet räknas. Mr bör komma ur IMAGE-läget, så att
    VIDEO-lägets utjämning inte flyttar banan i tid.
    Svarar δ i ms, rutorna från δ ≈ 0, kvoten, medianen av resten i ms, paren och skälet
    när det är tvetydigt. METOD MF1"""
    ut = {"forskjutning_ms": None, "rutor": None, "kvot": None, "rest_ms_median": None, "par": [],
          "tvetydig": None}
    if len(e) == 0 or len(r) == 0:
        ut["tvetydig"] = "klippet gav inga rutor" if len(r) == 0 else "Vision har inga rutor"
        return ut
    c = int(np.argmin(np.abs(e - np.median(e))))
    j0 = int(np.argmin(np.abs(r - e[c])))
    kand = []
    for m in range(-SOK_RUTOR, SOK_RUTOR + 1):
        if not 0 <= j0 + m < len(r):
            continue
        d = float(r[j0 + m] - e[c])
        par = _para(e, r, d)
        ii = np.array([i for i, _ in par], int)
        jj = np.array([j for _, j in par], int)
        if len(ii):
            keep = rorelse[ii]
            ii, jj = ii[keep], jj[keep]
        vv, mm = V[ii][:, list(HANDLEDER), :2], Mr[jj][:, list(HANDLEDER), :2]
        # Modellernas fasta skillnad per handled (olika leddefinition) dras bort först, så
        # att bara banans form och tiden avgör. METOD MF1
        dd = vv - mm
        if len(dd):
            with warnings.catch_warnings():
                warnings.simplefilter("ignore", RuntimeWarning)
                dd = dd - np.nanmedian(dd, axis=0, keepdims=True)
        dist = np.hypot(dd[..., 0], dd[..., 1])        # (n, 2), NaN där en saknas
        with np.errstate(invalid="ignore"):
            per_ruta = np.nanmean(np.where(np.isfinite(dist), dist, np.nan), axis=1) if len(ii) else dist[:, 0]
        per_ruta = per_ruta[np.isfinite(per_ruta)]
        poang = float(np.mean(per_ruta)) if len(per_ruta) >= MIN_PAR_FORSKJ else math.inf
        kand.append((poang, m, d, par))
    kand.sort(key=lambda k: k[0])
    poang, m, d, par = kand[0]
    ut.update(forskjutning_ms=round(d * 1000.0, 3), rutor=m, par=par)
    if par:
        ut["rest_ms_median"] = round(float(np.median([(r[j] - e[i] - d) * 1000.0 for i, j in par])), 3)
    if not math.isfinite(poang):
        ut["tvetydig"] = f"färre än {MIN_PAR_FORSKJ} rutor med handlederna i båda"
        return ut
    if len(kand) > 1:
        ut["kvot"] = round(kand[1][0] / poang, 3) if poang > 0 else None
        if kand[1][0] <= TVETYDIG_KVOT * poang:
            ut["tvetydig"] = "två förskjutningar passar nästan lika bra"
    if abs(m) == SOK_RUTOR and ut["tvetydig"] is None:
        ut["tvetydig"] = f"den bästa förskjutningen ligger vid sökningens kant (±{SOK_RUTOR} rutor)"
    return ut


def _ner(img: np.ndarray, bredd: int) -> np.ndarray:
    """Närmaste granne ned (eller upp) till `bredd` px, utan beroenden."""
    h, w = img.shape[:2]
    hojd = max(1, int(round(h * bredd / w)))
    ys = np.minimum((np.arange(hojd) * h / hojd).astype(int), h - 1)
    xs = np.minimum((np.arange(bredd) * w / bredd).astype(int), w - 1)
    return img[ys][:, xs].copy()


def _klipp_info(paket_fil: Path, s: P.Slag) -> tuple[int, int]:
    """Klippets CRC och storlek ur zippen."""
    with zipfile.ZipFile(paket_fil) as z:
        i = z.getinfo(s.klipp)
    return i.CRC, i.file_size


def _cache_giltig(d: dict, bredd: int, hojd: int, ruta: tuple[int, int, int, int], modell_namn: str,
                  klipp: tuple[int, int] | None = None) -> bool:
    """Sparade leder gäller bara för samma form, utsnitt, bildstorlek, modell och klipp
    (CRC och storlek ur zippen). METOD MF1"""
    return (isinstance(d, dict) and d.get("version") == CACHE_VERSION and d.get("width") == bredd
            and d.get("height") == hojd and d.get("utsnitt_px") == list(ruta) and d.get("modell") == modell_namn
            and (klipp is None or (d.get("klipp_crc"), d.get("klipp_storlek")) == klipp)
            and isinstance(d.get("frames"), list) and all("tk" in f for f in d["frames"][:1]))


def kor_mediapipe(paket_fil: Path, p: P.Paket, s: P.Slag, modell: Modell, rutkalla: Rutkalla,
                  ruta: tuple[int, int, int, int], modell_namn: str,
                  bild_fonster: tuple[float, float] | None) -> dict:
    """MediaPipe på varje ruta i klippet, i utsnittet; tiderna är läsarens. Rutorna i
    `bild_fonster` (läsarens tid, None = alla) körs också i IMAGE-läget för
    tidsparningen (`joints_bild`). METOD MF1"""
    bredd, hojd = s.lederna["width"], s.lederna["height"]
    frames, info = [], None
    try:
        for tk, bild in rutkalla.rutor(paket_fil, p, s):
            h, w = bild.shape[:2]
            cx, cy, cb, ch = KL.skala_ruta(ruta, w, h, bredd, hojd)
            if info is None:
                sx, sy = w / bredd, h / hojd
                info = SlagInfo(fil=p.fil, vy=p.vy, slag=s.id, bredd=bredd, hojd=hojd,
                                ruta=(cx / sx, cy / sy, cb / sx, ch / sy))
                modell.borja(info)
            utsnitt = bild[cy:cy + ch, cx:cx + cb]
            ruta_ut = {"tk": round(float(tk), 6), "joints": till_leder(modell.kor(utsnitt, tk), info.ruta, bredd, hojd)}
            if bild_fonster is None or bild_fonster[0] <= tk <= bild_fonster[1]:
                ruta_ut["joints_bild"] = till_leder(modell.kor_bild(utsnitt), info.ruta, bredd, hojd)
            frames.append(ruta_ut)
    finally:
        if info is not None:
            modell.sluta()
    crc, storlek = _klipp_info(paket_fil, s)
    return {"version": CACHE_VERSION, "source": "mediapipe-pose-heavy", "modell": modell_namn, "width": bredd,
            "height": hojd, "utsnitt_px": list(ruta), "klipp_crc": crc, "klipp_storlek": storlek, "frames": frames}


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


def _stat_led(dx: np.ndarray, dy: np.ndarray, grov: float = math.inf) -> dict:
    """En leds avvikelser (Vision − MediaPipe) i en enhet: medelavståndet och dess
    spridning, den fasta delen (medianens vektor, per axel), den rörliga delen (robust sd
    per axel), utliggarna (> 3 robusta sd från medianen, M25) och de grova (avståndet
    över `grov`, MF3). METOD MF2"""
    d = np.hypot(dx, dy)
    mx, my = float(np.median(dx)), float(np.median(dy))
    sx, sy = _robust_sd(dx), _robust_sd(dy)
    rorligt = math.sqrt((sx * sx + sy * sy) / 2)
    gr = S.MAD_GRANS * rorligt * math.sqrt(2)
    utl = int(np.sum(np.hypot(dx - mx, dy - my) > gr)) if rorligt > 0 else 0
    return {"n": int(len(d)), "medel": float(np.mean(d)), "spridning": float(np.std(d, ddof=1)) if len(d) > 1 else 0.0,
            "fast": math.sqrt((mx * mx + my * my) / 2), "rorligt": rorligt, "utliggare": utl,
            "grova": int(np.sum(d > grov))}


def _sla_ihop(delar: list[dict]) -> dict:
    """Flera leders stat → en: viktat på antalet rutor (medel och kvadraterna)."""
    n = sum(d["n"] for d in delar)
    if n == 0:
        return {"n": 0}
    v = lambda k: sum(d[k] * d["n"] for d in delar) / n  # noqa: E731
    k2 = lambda k: math.sqrt(sum(d[k] ** 2 * d["n"] for d in delar) / n)  # noqa: E731
    medel = v("medel")
    var = sum(((d["n"] - 1) * d["spridning"] ** 2 + d["n"] * (d["medel"] - medel) ** 2) for d in delar)
    return {"n": n, "medel": medel, "spridning": math.sqrt(var / max(1, n - 1)), "fast": k2("fast"),
            "rorligt": k2("rorligt"), "utliggare": sum(d["utliggare"] for d in delar),
            "grova": sum(d["grova"] for d in delar)}


class Insamling:
    """Avvikelserna ruta för ruta per vy, med slaget, fasen och kroppens storlek, så
    att allt kan delas på led, fas och slag (bootstrap). METOD MF2"""

    def __init__(self):
        self.block: dict[str, list[dict]] = {}

    def lagg_till(self, vy: str, slag: str, t: np.ndarray, V: np.ndarray, Mp: np.ndarray, faser: dict | None,
                  kropp_px: float | None) -> None:
        fas = np.array([_fas(float(x), faser) or "okand" for x in t], dtype=object)
        v_ok, m_ok = np.isfinite(V[..., 0]), np.isfinite(Mp[..., 0])
        sb = {}
        for namn, a, b in PAR:
            ok = v_ok[:, a] & v_ok[:, b] & m_ok[:, a] & m_ok[:, b]
            lika = np.hypot(*(V[:, a, :2] - Mp[:, a, :2]).T) + np.hypot(*(V[:, b, :2] - Mp[:, b, :2]).T)
            bytt = np.hypot(*(V[:, a, :2] - Mp[:, b, :2]).T) + np.hypot(*(V[:, b, :2] - Mp[:, a, :2]).T)
            with np.errstate(invalid="ignore"):
                sb[namn] = (int(ok.sum()), int((ok & (bytt < SIDBYTE_KVOT * lika)).sum()))
        self.block.setdefault(vy, []).append({
            "slag": slag, "fas": fas, "v_ok": v_ok, "m_ok": m_ok, "d": V[..., :2] - Mp[..., :2],
            "pr": np.full(len(t), 100.0 / kropp_px if kropp_px else np.nan), "sb": sb})

    def vyer(self) -> list[str]:
        return sorted(self.block)

    def A(self, vy: str) -> dict:
        b = self.block[vy]
        slag = np.concatenate([np.full(len(x["fas"]), k) for k, x in enumerate(b)]) if b else np.zeros(0, int)
        return {"slag": slag, "n_slag": len(b), "fas": np.concatenate([x["fas"] for x in b]),
                "v_ok": np.concatenate([x["v_ok"] for x in b]), "m_ok": np.concatenate([x["m_ok"] for x in b]),
                "d": np.concatenate([x["d"] for x in b]), "pr": np.concatenate([x["pr"] for x in b]),
                "per_slag": [np.where(slag == k)[0] for k in range(len(b))]}

    def sidbyten(self) -> list[dict]:
        ut = []
        for vy in self.vyer():
            for namn, _, _ in PAR:
                n = sum(x["sb"][namn][0] for x in self.block[vy])
                k = sum(x["sb"][namn][1] for x in self.block[vy])
                ut.append({"vy": vy, "par": namn, "n": n, "andel": k / n if n else None})
        return ut


def _fasmask(A: dict, idx: np.ndarray, fas: str) -> np.ndarray:
    return np.ones(len(idx), bool) if fas == "alla" else (A["fas"][idx] == fas)


def _stat_grupp(A: dict, idx: np.ndarray, fas: str, leder, procent: bool) -> tuple[list, dict | None]:
    """Per led och ihop för raderna idx i en fas. METOD MF2"""
    fm_ = _fasmask(A, idx, fas)
    per, delar = [], []
    for j in leder:
        sel = idx[fm_ & A["v_ok"][idx, j] & A["m_ok"][idx, j]]
        if procent:
            sel = sel[np.isfinite(A["pr"][sel])]
        if len(sel) < 2:
            per.append(None)
            continue
        k = A["pr"][sel] if procent else 1.0
        st = _stat_led(A["d"][sel, j, 0] * k, A["d"][sel, j, 1] * k, GROV_PROCENT if procent else math.inf)
        per.append(st)
        delar.append(st)
    return per, (_sla_ihop(delar) if delar else None)


def _avrunda(d: dict | None) -> dict | None:
    if not d or d.get("n", 0) == 0:
        return None
    return {k: round(d[k], 3) for k in ("medel", "spridning", "fast", "rorligt") if k in d}


def tabell(ins: Insamling) -> list[dict]:
    """En rad per (vy, led, fas), också `alla` leder och `alla` faser, med antalet slag
    som bär raden. METOD MF2"""
    ut = []
    for vy in ins.vyer():
        A = ins.A(vy)
        idx = np.arange(len(A["fas"]))
        for fas in FASER_S3 + ("alla",):
            fm_ = _fasmask(A, idx, fas)
            per_px, alla_px = _stat_grupp(A, idx, fas, range(ANTAL_LEDER), False)
            per_pr, alla_pr = _stat_grupp(A, idx, fas, range(ANTAL_LEDER), True)
            for j in list(range(ANTAL_LEDER)) + [None]:
                kol = slice(None) if j is None else j
                rutor = int(fm_.sum()) * (ANTAL_LEDER if j is None else 1)
                v_ok, m_ok = A["v_ok"][fm_][:, kol], A["m_ok"][fm_][:, kol]
                px = alla_px if j is None else per_px[j]
                pr = alla_pr if j is None else per_pr[j]
                ok = (v_ok & m_ok) if j is None else (v_ok & m_ok)
                rad_slag = A["slag"][fm_][ok.any(axis=1)] if j is None else A["slag"][fm_][ok]
                ut.append({"vy": vy, "led": "alla" if j is None else LEDER_FIL[j], "fas": fas, "rutor": rutor,
                           "n": px["n"] if px else 0, "slag": int(len(np.unique(rad_slag))),
                           "px": _avrunda(px), "procent": _avrunda(pr),
                           "utliggare": (px["utliggare"] / px["n"]) if px and px["n"] else None,
                           "vision_saknar": float((~v_ok).sum() / rutor) if rutor else None,
                           "mediapipe_saknar": float((~m_ok).sum() / rutor) if rutor else None,
                           "vision_saknar_mp_ser": float((~v_ok & m_ok).sum() / rutor) if rutor else None})
    return ut


def _b5_varden(A: dict, idx: np.ndarray, fas: str) -> dict | None:
    _, st = _stat_grupp(A, idx, fas, range(ANTAL_LEDER), True)
    if not st or not st.get("n"):
        return None
    return {"fast": st["fast"], "rorligt": st["rorligt"], "utliggare": st["utliggare"] / st["n"],
            "grova": st["grova"] / st["n"]}


def b5_sammanfattning(A: dict, fas: str, bootstrap: int, rng: np.random.Generator) -> dict | None:
    """Fast, rörligt och utliggare över alla leder i fasen (% av kroppslängden), och
    95 %-intervallet ur `bootstrap` dragningar av slagen med återläggning. METOD MF2"""
    idx = np.arange(len(A["fas"]))
    v = _b5_varden(A, idx, fas)
    if v is None:
        return None
    v["slag"] = A["n_slag"]
    if bootstrap and A["n_slag"] > 1:
        dr = {k: [] for k in ("fast", "rorligt", "utliggare", "grova")}
        for _ in range(bootstrap):
            val = rng.integers(0, A["n_slag"], A["n_slag"])
            b = _b5_varden(A, np.concatenate([A["per_slag"][k] for k in val]), fas)
            if b:
                for k in dr:
                    dr[k].append(b[k])
        v["intervall"] = {k: [float(np.percentile(x, 2.5)), float(np.percentile(x, 97.5))] for k, x in dr.items() if x}
    return v


NIVA_DELAR = ("fast", "rorligt")   # METOD MF3: utliggarna och de grova visas men avgör inte nivån
SIM_DELAR = ("fast", "rorligt", "utliggare", "grova")


def niva_for(v: dict, nivaer_fas: dict) -> str:
    """Den bästa nivån där både den fasta och den rörliga delen ligger under nivåns
    övre gräns (`grans`, MF3). Utliggarna räknas mot den robusta sd:n och blir därför
    färre när bruset växer: de visas bredvid simuleringens väntade andel men avgör inte.
    METOD MF3"""
    for n in NIVAER:
        if all(v[k] <= nivaer_fas[n]["grans"][k] for k in NIVA_DELAR):
            return n
    return "samre_an_daligt"


class _MinnesSkymning:
    """`kamera.skymda` beror bara på kameran och lederna, inte på bruset: samma sving i
    samma kamera räknas en gång när flera källor observeras."""

    def __init__(self):
        self.orig = KM.skymda
        self.minne: dict = {}

    def __call__(self, kam, P_):
        k = (id(kam), P_.shape, hash(P_.tobytes()))
        if k not in self.minne:
            self.minne = {k: self.orig(kam, P_)}
        return self.minne[k]

    def __enter__(self):
        KM.skymda = self
        return self

    def __exit__(self, *a):
        KM.skymda = self.orig


def simulera(n_pass: int, n_slag: int, seed: int) -> dict:
    """Felbudgetens kedja (`tre_d.kamera.observera` med `felbudget.Uppstallning`:
    skymning, oskärpa, utliggare, fast avvikelse per led och vy) på påhittade svingar i
    två kameror: MediaPipe på MP_ANTAGEN och Vision på varje nivå, på samma svingar och
    rutor. Skillnaden går genom samma statistik som passet. Svarar
    {nivå: {fas: {del: [värde per pass och vy]}}}. METOD MF3"""
    from .tre_d import felbudget as FB
    from .tre_d.sving import I, slumpa_sving
    u = FB.Uppstallning()
    rng = np.random.default_rng(seed)
    ut = {n: {fas: {k: [] for k in SIM_DELAR} for fas in B5_FASER} for n in NIVAER}
    with _MinnesSkymning():
        for _ in range(n_pass):
            pas = FB.nytt_pass(u, rng)
            ins = {n: Insamling() for n in NIVAER}
            fast = {(kalla, vy): rng.standard_normal((ANTAL_LEDER, 2)) for kalla in ("v", "m") for vy in ("fo", "dtl")}
            for k in range(n_slag):
                sv = slumpa_sving(rng)
                faser = {"start": sv.t_start, "topp": sv.t_topp, "traff": sv.t_traff}
                for vy, kam in (("fo", pas["A"]), ("dtl", pas["B"])):
                    t = KM.bildtider(sv.t_slut, rng)

                    def obs(niva, kalla):
                        o, konf, _ = KM.observera(kam, sv, t, KM.BRUS[niva], rng, u.exponering, u.skala,
                                                  fast[(kalla, vy)])
                        o = o.copy()
                        o[konf < MIN_KONFIDENS] = np.nan
                        return o

                    Mp = obs(MP_ANTAGEN, "m")
                    mitt = 0.5 * (sv.leder(t[:1])[0, I["v_hoft"]] + sv.leder(t[:1])[0, I["h_hoft"]])
                    kropp = sv.langd * kam.K[0, 0] / kam.djup(mitt)
                    for n in NIVAER:
                        ins[n].lagg_till(vy, str(k), t, obs(n, "v"), Mp, faser, kropp)
            for n in NIVAER:
                for vy in ins[n].vyer():
                    A = ins[n].A(vy)
                    for fas in B5_FASER:
                        v = _b5_varden(A, np.arange(len(A["fas"])), fas)
                        for d in SIM_DELAR:
                            ut[n][fas][d].append(v[d])
    return ut


@functools.lru_cache(maxsize=None)
def nivaer(n_pass: int = SIM_PASS, n_slag: int = SIM_SLAG, seed: int = SIM_SEED) -> dict:
    """Trösklarna för skillnaden Vision − MediaPipe ur `simulera`: per fas och nivå
    medianen över passen och vyerna (`median`) och nivåns övre gräns (`grans`), för den
    fasta och den rörliga delen: mellan två nivåer det geometriska medlet av deras
    medianer, över "dåligt" dess median gånger kvoten mot "typiskt" i roten (lika långt
    uppåt i log). Utliggarna och de grova får bara sin median (väntat). METOD MF3"""
    sim = simulera(n_pass, n_slag, seed)
    ut = {"mediapipe": MP_ANTAGEN, "pass": n_pass, "slag": n_slag, "grov_procent": GROV_PROCENT}
    for fas in B5_FASER:
        med = {n: {k: float(np.median(sim[n][fas][k])) for k in SIM_DELAR} for n in NIVAER}
        ut[fas] = {}
        for i, n in enumerate(NIVAER):
            grans = {}
            for k in NIVA_DELAR:
                if i + 1 < len(NIVAER):
                    grans[k] = math.sqrt(med[n][k] * med[NIVAER[i + 1]][k])
                else:
                    grans[k] = med[n][k] * math.sqrt(med[n][k] / med[NIVAER[i - 1]][k])
            ut[fas][n] = {"median": med[n], "grans": grans}
    return ut


def beslut_b5(ins: Insamling, matt: list[dict], niv: dict, min_slag: int, bootstrap: int) -> dict:
    """Det som avgör B5 per vy, för hela svingen och nedsvingen: lederna mot de
    simulerade trösklarna (den sämsta delen avgör nivån), med intervallen; under
    `min_slag` slag "–". Dessutom andelen där Vision saknar leden och MediaPipe ser
    den, sidbytena och hur många mått som skiljer tydligt. METOD MF2, MF3"""
    rng = np.random.default_rng(BOOTSTRAP_SEED)
    sb = ins.sidbyten()
    ut = {}
    for vy in ins.vyer():
        A = ins.A(vy)
        rad = {"slag": A["n_slag"]}
        for fas in B5_FASER:
            v = b5_sammanfattning(A, fas, bootstrap, rng) if A["n_slag"] >= min_slag else None
            if v is not None:
                v["niva"] = niva_for(v, niv[fas])
            rad[fas] = v
        idx = np.arange(len(A["fas"]))
        rutor = len(idx) * ANTAL_LEDER
        rad["vision_saknar_mp_ser"] = float((~A["v_ok"] & A["m_ok"]).sum() / rutor) if rutor else None
        s = [x for x in sb if x["vy"] == vy and x["n"]]
        n = sum(x["n"] for x in s)
        rad["sidbyten"] = sum(x["andel"] * x["n"] for x in s) / n if n else None
        mv = [m for m in matt if m["vy"] == vy and m["tydlig"] is not None]
        rad["matt_tydliga"] = sum(1 for m in mv if m["tydlig"])
        rad["matt_provade"] = len(mv)
        ut[vy] = rad
    return ut


def _median(x: list[float]) -> float:
    return S.percentil(sorted(x), 0.5)


def jamfor_matt(rader: list[dict], min_slag: int, bootstrap: int) -> tuple[list[dict], list[dict]]:
    """Måtten per vy, parade per slag: passets median för Vision och MediaPipe (M25),
    skillnaden mellan medianerna med 95 %-intervall ur bootstrap av slagparen, skillnaden
    slag för slag, och om skillnaden är tydlig i M26:s mening (större än MediaPipe-
    passets robusta sd). Under `min_slag` slag bara antalet. Fasernas tider i ms. METOD MF3"""
    rng = np.random.default_rng(BOOTSTRAP_SEED)
    matt_ut, faser_ut = [], []
    for vy in sorted({r["vy"] for r in rader}):
        par = [r for r in rader if r["vy"] == vy and r.get("vision") and r.get("mediapipe")]
        for k in M.MATT[vy]:
            pv = [(r["vision"]["matt"][k], r["mediapipe"]["matt"][k]) for r in par
                  if k in r["vision"]["matt"] and k in r["mediapipe"]["matt"]]
            if not pv:
                continue
            rad = {"vy": vy, "matt": k, "enhet": enhet(k), "n": len(pv), "vision_median": None,
                   "mediapipe_median": None, "skillnad": None, "intervall": None, "skillnad_medel": None,
                   "skillnad_sd": None, "abs_medel": None, "mediapipe_spridning": None, "tydlig": None}
            if len(pv) >= min_slag:
                v, m = [a for a, _ in pv], [b for _, b in pv]
                d = [a - b for a, b in pv]
                sm = sorted(m)
                rad.update(vision_median=_median(v), mediapipe_median=_median(m),
                           skillnad=_median(v) - _median(m), skillnad_medel=float(np.mean(d)),
                           skillnad_sd=float(np.std(d, ddof=1)), abs_medel=float(np.mean(np.abs(d))),
                           mediapipe_spridning=(S.percentil(sm, 0.75) - S.percentil(sm, 0.25)) / S.IQR_SKALA)
                rad["tydlig"] = abs(rad["skillnad"]) > rad["mediapipe_spridning"]
                if bootstrap:
                    b = []
                    for _ in range(bootstrap):
                        val = rng.integers(0, len(pv), len(pv))
                        b.append(_median([v[i] for i in val]) - _median([m[i] for i in val]))
                    rad["intervall"] = [float(np.percentile(b, 2.5)), float(np.percentile(b, 97.5))]
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
    med Visions leder (vita) och MediaPipes (orange) från samma ruta. METOD MF4"""
    res = {}
    kol = ("adress", "topp", "traff", "finish")
    for vy in sorted({r["vy"] for r in rader}):
        valda = [r for r in rader if r["vy"] == vy and r.get("bilder")]
        if not valda:
            res[vy] = {"hoppat": "inga rutor ur klippen"}
            continue
        hojd = max(b[0].shape[0] for r in valda for b in r["bilder"].values())
        ark = np.zeros((len(valda) * (hojd + 2), len(kol) * (KONTAKT_BREDD + 2), 3), np.uint8)
        for i, r in enumerate(valda):
            for k, namn in enumerate(kol):
                if namn not in r["bilder"]:
                    continue
                img, ruta, v_led, m_led = r["bilder"][namn]
                img = img.copy()
                s = img.shape[1] / ruta[2]
                for leder, farg, rr in ((v_led, VISION_FARG, 2), (m_led, MP_FARG, 1)):
                    q = leder.copy()
                    q[:, 0] = (q[:, 0] - ruta[0]) * s
                    q[:, 1] = (q[:, 1] - ruta[1]) * s
                    _rita(img, q, farg, rr)
                y, x = i * (hojd + 2), k * (KONTAKT_BREDD + 2)
                ark[y:y + img.shape[0], x:x + img.shape[1]] = img
        fil = ut / f"kontaktark-s3-{vy}.png"
        skriv_png(fil, ark)
        res[vy] = {"fil": fil.name, "rader": [f"{r['fil']}:{r['id']}" for r in valda], "kolumner": list(kol)}
    return res


def _kontaktbilder(paket_fil, p, s, rutkalla, ruta, kt, tv, e, V, tm, Mp, d_s) -> dict:
    """Kolumnernas rutor: Vision-rutan närmast tiden, klippets ruta på e + δ, och
    MediaPipes leder från samma klippruta. METOD MF4"""
    bredd, hojd = s.lederna["width"], s.lederna["height"]
    onskat = {}
    for namn, tk in kt.items():
        i = int(np.argmin(np.abs(tv - tk)))
        onskat[namn] = (i, float(e[i] + d_s))
    fatt = rutkalla.vid(paket_fil, p, s, [x[1] for x in onskat.values()])
    ut = {}
    for namn, (i, rt) in onskat.items():
        if rt not in fatt or not len(tm):
            continue
        r_fatt, bild = fatt[rt]
        h, w = bild.shape[:2]
        cx, cy, cb, ch = KL.skala_ruta(ruta, w, h, bredd, hojd)
        sx = w / bredd
        j = int(np.argmin(np.abs(tm - r_fatt)))
        ut[namn] = (_ner(bild[cy:cy + ch, cx:cx + cb], KONTAKT_BREDD), (cx / sx, cy / (h / hojd), cb / sx),
                    V[i], Mp[j])
    return ut


# --- hela körningen ------------------------------------------------------------------

_VISIONS_MATT: dict[tuple, tuple[dict | None, str | None]] = {}


def _mat_vision(fil: Path, p: P.Paket, s: P.Slag, langd: float) -> tuple[dict | None, str | None]:
    """Visions mått för slaget, en gång per paketfil och längd (samma tal varje gång)."""
    st = Path(fil).stat()
    nyckel = (str(Path(fil).resolve()), st.st_mtime_ns, st.st_size, s.id, langd)
    if nyckel not in _VISIONS_MATT:
        _VISIONS_MATT[nyckel] = _mat(p, s, langd)
    return _VISIONS_MATT[nyckel]


def _mat(p: P.Paket, s: P.Slag, langd: float) -> tuple[dict | None, str | None]:
    try:
        return M.mat(fm.fran_dict(P.till_sving(p, s, langd))), None
    except (fm.FormatFel, F.SvingFel) as e:
        return None, str(e)


def kontrollera_passet(pts: list[dict]) -> dict:
    """Förskjutningen hör till klippens behållare och ska vara densamma i passets klipp:
    ett slag mer än TID_TOL_S från passets median blir tvetydigt (en ruta fel, t.ex. av
    en modell som släpar). Svarar medianen och spridningen (största − minsta) i ms.
    METOD MF1"""
    ds = [pt["forskjutning_ms"] for pt in pts if not pt["tvetydig"]]
    if not ds:
        return {}
    dm = float(np.median(ds))
    for pt in pts:
        if not pt["tvetydig"] and abs(pt["forskjutning_ms"] - dm) > TID_TOL_S * 1000:
            pt["tvetydig"] = "förskjutningen avviker från passets median"
    return {"forskjutning_median_ms": round(dm, 3), "forskjutning_spridning_ms": round(max(ds) - min(ds), 3)}


def forskjutningar(s3: dict) -> dict[tuple[str, str], float]:
    """S3:s förskjutning per (paket, slag) i ms ur s3.json, bara för slag där den inte
    var tvetydig (METOD MF1). Läses av S7 och kontaktarket."""
    return {(r["fil"], r["id"]): float(r["tidsparning"]["forskjutning_ms"]) for r in s3.get("slag", [])
            if "hoppat" not in r and (r.get("tidsparning") or {}).get("forskjutning_ms") is not None}


def las_forskjutningar(pass_id: str, fil: Path | None = None) -> dict[tuple[str, str], float]:
    """Förskjutningarna ur `fil` eller ~/swinglab-s3/<pass>/s3.json; tomt när den saknas
    eller inte går att läsa."""
    fil = fil or UT_ROT / pass_id / "s3.json"
    try:
        return forskjutningar(json.loads(Path(fil).read_text(encoding="utf-8")))
    except (OSError, json.JSONDecodeError, AttributeError, KeyError, TypeError, ValueError):
        return {}


def kor(paket_filer: list[Path], ut: Path, langd: float | None, modell: Modell | None, rutkalla: Rutkalla | None,
        om: bool = False, kontakt_slag: int = KONTAKT_SLAG, modell_namn: str = MODELL_FIL,
        min_slag: int = MIN_SLAG, bootstrap: int = BOOTSTRAP, niv: dict | None = None, rapport=None) -> dict:
    """Paketen → s3.json, s3.md och kontaktarken i `ut`. `modell` och `rutkalla` får
    vara None när alla slag redan har giltiga sparade MediaPipe-leder (då blir det
    inget kontaktark). METOD MF1–MF4"""
    paket = [(Path(f), P.las(f)) for f in paket_filer]
    niv = niv or nivaer()
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
                            .astype(int)).tolist()) if med_klipp and kontakt_slag > 0 else set()
        info = {"fil": p.fil, "vy": p.vy, "slag": len(p.slag), "matbara": len(matbara), "med_klipp": len(med_klipp),
                "korda": 0, "jamforda": 0, "rutor": 0, "rutor_parade": 0}
        # Fas 1: MediaPipe och tidsparningen per slag.
        forsta = []
        for k, s in enumerate(med_klipp):
            bredd, hojd = s.lederna["width"], s.lederna["height"]
            ruta = P.utsnitt_px(p.serier[s.serie].utsnitt, bredd, hojd)
            vr, vfel = _mat_vision(fil, p, s, lg)
            tv, V = _leder(s.lederna)
            e = tv + float(s.klick_i_klipp_s)
            rorelse = np.ones(len(tv), bool)
            bild_fonster = None
            if vr:
                fz = vr["faser"]
                rorelse = (tv >= fz["topp"] - RORELSE_S[0]) & (tv <= fz["traff"] + RORELSE_S[1])
                if rorelse.any():
                    bild_fonster = (float(e[rorelse].min()) - BILD_MARGINAL_S, float(e[rorelse].max()) + BILD_MARGINAL_S)
            cfil = cache / f"{Path(p.fil).stem}-{s.id}.json"
            mp_raa = None
            if cfil.is_file() and not om:
                try:
                    d = json.loads(cfil.read_text(encoding="utf-8"))
                    mp_raa = d if _cache_giltig(d, bredd, hojd, ruta, modell_namn, _klipp_info(fil, s)) else None
                except (OSError, json.JSONDecodeError):
                    mp_raa = None
            if mp_raa is None:
                if modell is None or rutkalla is None:
                    raise S3Fel("MediaPipe behövs men är inte laddad")
                if rapport:
                    rapport(f"  {p.fil} {s.id}: MediaPipe …", flush=True)
                mp_raa = kor_mediapipe(fil, p, s, modell, rutkalla, ruta, modell_namn, bild_fonster)
                cfil.write_text(json.dumps(mp_raa, separators=(",", ":")), encoding="utf-8")
            info["korda"] += 1
            info["rutor"] += len(s.lederna["frames"])
            tm, Mp = _leder(mp_raa, "tk")
            _, Mb = _leder(mp_raa, "tk", "joints_bild")
            pt = para_tider(e, V, tm, Mb, rorelse)
            slag_rad = {"fil": p.fil, "id": s.id, "vy": p.vy,
                        "tidsparning": {k2: pt[k2] for k2 in ("forskjutning_ms", "rutor", "kvot", "rest_ms_median")},
                        "rutor_parade": len(pt["par"])}
            if vfel:
                slag_rad["vision_fel"] = vfel
            if pt["tvetydig"]:
                slag_rad["hoppat"] = f"tidsparningen är tvetydig: {pt['tvetydig']}"
            start = getattr(rutkalla, "start_tid", None)
            start = start(fil, p, s) if start and rutkalla is not None else None
            if start is not None:
                slag_rad["tidsparning"]["ffprobe_start_ms"] = round(start * 1000.0, 3)
                if pt["forskjutning_ms"] is not None and abs(pt["forskjutning_ms"] + start * 1000.0) > TID_TOL_S * 1000:
                    slag_rad["varning"] = "förskjutningen stämmer inte med klippets start_time (ffprobe)"
            forsta.append((k, s, ruta, vr, tv, V, e, tm, Mp, pt, slag_rad))
        # Fas 2: förskjutningen hör till behållaren och ska stämma mellan passets klipp.
        info.update(kontrollera_passet([x[9] for x in forsta]))
        for x in forsta:
            if x[9]["tvetydig"]:
                x[10]["hoppat"] = f"tidsparningen är tvetydig: {x[9]['tvetydig']}"
        # Fas 3: jämförelsen på de parade rutorna.
        for k, s, ruta, vr, tv, V, e, tm, Mp, pt, slag_rad in forsta:
            slag_ut.append(slag_rad)
            if pt["tvetydig"]:
                if rapport:
                    rapport(f"  {p.fil} {s.id}: jämförs inte, {slag_rad['hoppat']}", flush=True)
                continue
            # Bara Visions rutor inom klippet (MS12) och med en parad klippruta.
            par = [(i, j) for i, j in pt["par"] if P.i_klippet(s, float(e[i]))]
            iv, jm = [i for i, _ in par], [j for _, j in par]
            mp_serie = {"frames": [{"t": float(tv[i]), "joints": [None if not np.isfinite(Mp[j, q, 0]) else
                                                                  [float(Mp[j, q, 0]), float(Mp[j, q, 1]),
                                                                   float(Mp[j, q, 2])] for q in range(ANTAL_LEDER)]}
                                   for i, j in par]}
            mr, mfel = _mat(p, replace(s, lederna={**s.lederna, **mp_serie}), lg) if par else (None, "inga parade rutor")
            if mfel:
                slag_rad["mediapipe_fel"] = mfel
            info["jamforda"] += 1
            info["rutor_parade"] += len(par)
            ref = mr or vr
            kropp = lg * 100.0 / ref["cm_per_px"] if ref else None
            if par:
                ins.lagg_till(p.vy, f"{p.fil}:{s.id}", tv[iv], V[iv], Mp[jm], (mr or vr or {}).get("faser"), kropp)
            rad = {"fil": p.fil, "id": s.id, "vy": p.vy, "vision": vr, "mediapipe": mr}
            if k in val and vr and rutkalla is not None:
                rad["bilder"] = _kontaktbilder(fil, p, s, rutkalla, ruta, kolumntider(vr["faser"]), tv, e, V, tm, Mp,
                                               pt["forskjutning_ms"] / 1000.0)
            rader.append(rad)
        for s in matbara:
            if not s.klipp:
                slag_ut.append({"fil": p.fil, "id": s.id, "vy": p.vy, "hoppat": "inget klipp i paketet"})
        paket_ut.append(info)
    matt, faser = jamfor_matt(rader, min_slag, bootstrap)
    res = {"format": FORMAT, "pass": sorted({p.pass_id for _, p in paket}),
           "skapad": datetime.now().astimezone().isoformat(timespec="seconds"),
           "modell": {"fil": modell_namn, "lage": "VIDEO"}, "min_slag": min_slag, "bootstrap": bootstrap,
           "paket": paket_ut, "nivaer": niv, "beslut_b5": beslut_b5(ins, matt, niv, min_slag, bootstrap),
           "leder": tabell(ins), "sidbyten": ins.sidbyten(), "matt": matt, "faser": faser, "slag": slag_ut,
           "kontaktark": kontaktark(rader, ut)}
    (ut / "s3.json").write_text(json.dumps(res, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    (ut / "s3.md").write_text(markdown(res), encoding="utf-8")
    return res


# --- tabellen ------------------------------------------------------------------------

def _t(v, d: int = 1, pct: bool = False) -> str:
    if v is None or (isinstance(v, float) and not math.isfinite(v)):
        return "–"
    return f"{v * 100:.{d}f} %" if pct else f"{v:.{d}f}"


def _ki(v: dict | None, k: str, d: int = 2, pct: bool = False) -> str:
    if not v:
        return "–"
    s = _t(v[k], d, pct)
    iv = (v.get("intervall") or {}).get(k)
    return s + (f" ({_t(iv[0], d, pct)}–{_t(iv[1], d, pct)})" if iv else "")


def markdown(r: dict) -> str:
    niv = r["nivaer"]
    b = r["beslut_b5"]
    vyer = list(b)
    rad = lambda c: "| " + " | ".join(c) + " |"  # noqa: E731
    hd = lambda c: [rad(c), rad(["---"] * len(c))]  # noqa: E731
    L = [f"# S3: Vision mot MediaPipe — pass {', '.join(r['pass'])}", "",
         f"Modellen: `{r['modell']['fil']}` ({r['modell']['lage']}). Skapad {r['skapad']}. "
         "Avvikelsen är Vision − MediaPipe; MediaPipe är facit, inte sanningen (METOD MF2).", "",
         "## Det som avgör B5 (räcker Vision?)", "",
         "Verktyget avgör inte beslutet: tabellen är underlaget (BESLUT B5, B14, B38). "
         f"Talen är % av kroppslängden per axel, med 95 %-intervall ur bootstrap av slagen; under "
         f"{r['min_slag']} slag står \"–\" (METOD MF2). Trösklarna är simulerade: skillnaden när Vision har "
         f"felbudgetens brus på nivån och MediaPipe på nivån **{NIVA_TEXT[niv['mediapipe']]}** (antagande; "
         f"{niv['pass']} pass om {niv['slag']} slag, METOD MF3).", ""]

    def tr(fas, k, pct=False):
        if k in NIVA_DELAR:
            return " · ".join(f"{NIVA_TEXT[x]} ≤ {_t(niv[fas][x]['grans'][k], 2)} %" for x in NIVAER)
        return " · ".join(f"{NIVA_TEXT[x]} {_t(niv[fas][x]['median'][k], 1, True)}" for x in NIVAER)

    kol = [f"{v.upper()} {'hela' if f == 'alla' else 'nedsving'}" for v in vyer for f in B5_FASER]
    L += hd(["Fråga"] + kol + ["Tröskel (hela · nedsving)", "Källa"])

    def cell(v, f, k, pct=False):
        return _ki(b[v][f], k, 1 if pct else 2, pct)

    for namn, k, pct in (("Lederna, fast avvikelse per led", "fast", False),
                         ("Lederna, rörligt fel ruta för ruta", "rorligt", False),
                         ("Utliggare (andel rutor)", "utliggare", True),
                         (f"Grova avvikelser, över {_t(niv.get('grov_procent', GROV_PROCENT), 0)} % av kroppslängden",
                          "grova", True)):
        avgor = k in NIVA_DELAR
        L.append(rad([namn] + [cell(v, f, k, pct) for v in vyer for f in B5_FASER]
                     + [("" if avgor else "väntat ") + tr("alla", k, pct) + " · nedsving: " + tr("nedsving", k, pct),
                        "simulering av S6_FELBUDGET §3 (antagande), METOD MF3" + ("" if avgor else "; avgör inte nivån")]))
    L.append(rad(["**Felbudgetens nivå** (den sämsta av fast och rörligt)"]
                 + [f"**{NIVA_TEXT[b[v][f]['niva']]}**" if b[v][f] else "–" for v in vyer for f in B5_FASER]
                 + ["typiskt räcker för trenden utan markörer", "BESLUT B14, S6_FELBUDGET §6.7"]))
    L.append(rad(["Slag"] + [str(b[v]["slag"]) for v in vyer for _ in B5_FASER] + [f"minst {r['min_slag']}", "METOD MF2"]))
    L.append(rad(["Vision saknar leden där MediaPipe ser den"]
                 + [_t(b[v]["vision_saknar_mp_ser"], 1, True) for v in vyer for _ in B5_FASER] + ["ingen källa", "–"]))
    L.append(rad(["Vänster och höger förväxlade"] + [_t(b[v]["sidbyten"], 1, True) for v in vyer for _ in B5_FASER]
                 + ["ingen källa", "–"]))
    L.append(rad(["Mått där passets median skiljer tydligt"]
                 + [f"{b[v]['matt_tydliga']} av {b[v]['matt_provade']}" for v in vyer for _ in B5_FASER]
                 + ["skillnaden > MediaPipe-passets robusta sd", "METOD M26 (formen; ingen källa för B5)"]))
    L += ["", "## Paketen", ""]
    L += hd(["Paket", "Vy", "Slag", "Mätbara", "Med klipp", "Körda", "Jämförda", "Visions rutor", "Parade"])
    for p in r["paket"]:
        L.append(rad([p["fil"], p["vy"], str(p["slag"]), str(p["matbara"]), str(p["med_klipp"]), str(p["korda"]),
                      str(p["jamforda"]), str(p["rutor"]), str(p["rutor_parade"])]))
    L += ["", "## Tidsparningen per slag", "",
          "Klippets tider (OpenCV) mot Visions: förskjutningen δ (ur MediaPipes IMAGE-läge), i rutor från 0, "
          "den näst bästas kvot, resten efter parningen och klippets start_time ur ffprobe (bara en kontroll). "
          "δ ska vara densamma i passets klipp (METOD MF1).", ""]
    for p in r["paket"]:
        if "forskjutning_median_ms" in p:
            L.append(f"- {p['fil']}: δ median {_t(p['forskjutning_median_ms'], 2)} ms, spridning "
                     f"{_t(p['forskjutning_spridning_ms'], 2)} ms")
    L.append("")
    L += hd(["Paket", "Slag", "δ ms", "Rutor", "Kvot", "Rest ms (median)", "ffprobe start ms", "Parade", "Anm."])
    for s in r["slag"]:
        if "tidsparning" not in s:
            continue
        tp = s["tidsparning"]
        anm = "; ".join(x for x in (s.get("hoppat"), s.get("varning")) if x)
        L.append(rad([s["fil"], s["id"], _t(tp["forskjutning_ms"], 2), str(tp["rutor"]), _t(tp["kvot"], 2),
                      _t(tp["rest_ms_median"], 2), _t(tp.get("ffprobe_start_ms"), 2), str(s["rutor_parade"]), anm]))
    L += ["", "## Lederna per led (alla faser)", "",
          "Medel och spridning = avståndet Vision–MediaPipe. Fast = medianens förskjutning, "
          "rörligt = robust sd, båda per axel (METOD MF2).", ""]
    for vy in vyer:
        L += [f"### {vy.upper()}", ""]
        L += hd(["Led", "Slag", "n", "Medel px", "Spridning px", "Medel %", "Spridning %", "Fast %", "Rörligt %",
                 "Utliggare", "Vision saknar", "MediaPipe saknar"])
        for x in (y for y in r["leder"] if y["vy"] == vy and y["fas"] == "alla"):
            px, pr = x["px"] or {}, x["procent"] or {}
            L.append(rad([x["led"], str(x["slag"]), str(x["n"]), _t(px.get("medel")), _t(px.get("spridning")),
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
          "Parade per slag. Skillnad = passets median Vision − MediaPipe, med 95 %-intervall ur bootstrap av "
          f"slagen. Tydlig = större än MediaPipe-passets robusta sd (formen i METOD M26). Under {r['min_slag']} "
          "slag står bara antalet.", ""]
    L += hd(["Vy", "Mått", "Enhet", "Slag", "Vision", "MediaPipe", "Skillnad (95 %)", "Slag för slag: medel ± sd",
             "Medel |skillnad|", "MediaPipe sd", "Tydlig"])
    for m in sorted(r["matt"], key=lambda m: (m["vy"], not m["tydlig"], m["matt"])):
        sd = f" ± {_t(m['skillnad_sd'], 2)}" if m["skillnad_sd"] is not None else ""
        iv = f" ({_t(m['intervall'][0], 2)}–{_t(m['intervall'][1], 2)})" if m["intervall"] else ""
        L.append(rad([m["vy"], m["matt"], m["enhet"], str(m["n"]), _t(m["vision_median"], 2),
                      _t(m["mediapipe_median"], 2), _t(m["skillnad"], 2) + iv, _t(m["skillnad_medel"], 2) + sd,
                      _t(m["abs_medel"], 2), _t(m["mediapipe_spridning"], 2),
                      "ja" if m["tydlig"] else ("nej" if m["tydlig"] is not None else "–")]))
    L += ["", "## Faserna och skalan", ""]
    L += hd(["Vy", "Vad", "n", "Vision − MediaPipe"])
    for f in r["faser"]:
        v = (f"kvot {f['kvot_median']:.3f}" if f["fas"] == "skalan" else
             f"{f['skillnad_medel_ms']:.1f} ms (medel |·| {f['abs_medel_ms']:.1f} ms)")
        L.append(rad([f["vy"], f["fas"], str(f["n"]), v]))
    L += ["", "## Kontaktarken", "", "Vitt = Vision, orange = MediaPipe, från samma ruta. Kolumnerna: adress, topp, "
          "träff, finish.", ""]
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
    """~/swinglab-s3/<pass>/ ur paketens manifest (utan att läsa lederna)."""
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
        print(f"MediaPipe: {fil}\nUt: {ut}\nSimulerar trösklarna …", flush=True)
        modell = MediaPipeModell(fil)
        try:
            res = kor([Path(f) for f in a.paket], ut, a.langd, modell, KlippRutor(), om=a.om,
                      kontakt_slag=a.kontakt_slag, modell_namn=fil.name, rapport=print)
        finally:
            modell.stang()
    except P.PaketFel as e:
        print("Paketet går inte att läsa:\n  " + "\n  ".join(e.fel))
        return 1
    except S3Fel as e:
        print(str(e))
        return 1
    for vy, b in res["beslut_b5"].items():
        for fas in B5_FASER:
            v = b[fas]
            print(f"  {vy.upper()} {'hela' if fas == 'alla' else 'nedsving'}: "
                  + (f"nivå {NIVA_TEXT[v['niva']]}, fast {_t(v['fast'], 2)} %, rörligt {_t(v['rorligt'], 2)} %"
                     if v else f"färre än {res['min_slag']} slag"))
        print(f"  {vy.upper()}: {b['matt_tydliga']} av {b['matt_provade']} mått skiljer tydligt")
    hoppade = [s for s in res["slag"] if "tidsparning" in s and "hoppat" in s]
    if hoppade:
        print(f"  {len(hoppade)} slag jämfördes inte: tidsparningen var tvetydig (se s3.md)")
    print(f"Skrev {ut / 's3.md'}, s3.json och kontaktarken")
    return 0


if __name__ == "__main__":
    sys.exit(main())
