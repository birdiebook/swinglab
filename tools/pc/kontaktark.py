"""Kontaktarket: en bild per vy med en rad per slag och en kolumn per fas
(adress, topp, träff, finish), med de uppmätta lederna ritade över klippet.
Claude tittar på arket för att se det måtten inte säger (skillen svinganalys).
METOD MT7

Rutorna läses med ffmpeg, annars med OpenCV. Finns ingetdera hoppas arket över
med en rad. PNG skrivs med zlib, utan beroenden.
"""
from __future__ import annotations

import shutil
import struct
import subprocess
import tempfile
import zipfile
import zlib
from pathlib import Path

import numpy as np

from .faser import ADRESS, FINISH, TOPP_ADRESS_S
from .klipp import VridenFel
from .paket import i_klippet, las_ur_zip

BREDD = 180                # METOD MT7: px per ruta i arket
MAX_RADER = 12             # METOD MT7: högst så många slag per ark (de första i passet)
MELLANRUM = 2              # px svart mellan rutorna
NARMAST_S = 0.002          # METOD MF1: läs från t − 2 ms så att rutan närmast t kommer
KOLUMNER = ("adress", "topp", "traff", "finish")
# Linjerna mellan lederna (index i filen, docs/FORMAT.md).
BEN = ((1, 2), (1, 3), (3, 5), (2, 4), (4, 6), (7, 8), (1, 7), (2, 8), (7, 9), (9, 11), (8, 10), (10, 12))


def verktyg() -> str | None:
    """"ffmpeg", "opencv" eller None."""
    if shutil.which("ffmpeg"):
        return "ffmpeg"
    try:
        import cv2  # noqa: F401
        return "opencv"
    except ImportError:
        return None


class PpmFel(ValueError):
    """ffmpeg gav en bild som inte går att läsa."""


def _ppm(b: bytes) -> np.ndarray:
    """En binär PPM (P6, 8 bitar) → (h, w, 3) uint8. Ett trasigt huvud eller för lite
    data kastar PpmFel."""
    delar, pos = [], 0
    while len(delar) < 4:
        while pos < len(b) and b[pos:pos + 1].isspace():
            pos += 1
        if pos >= len(b):
            raise PpmFel("ffmpeg gav en bild med avhugget huvud")
        if b[pos:pos + 1] == b"#":
            slut = b.find(b"\n", pos)
            if slut < 0:
                raise PpmFel("ffmpeg gav en bild med en kommentar utan radslut")
            pos = slut + 1
            continue
        slut = pos
        while slut < len(b) and not b[slut:slut + 1].isspace():
            slut += 1
        delar.append(b[pos:slut])
        pos = slut
    if delar[0] != b"P6" or delar[3] != b"255" or not (delar[1].isdigit() and delar[2].isdigit()):
        raise PpmFel("ffmpeg gav inte en 8-bitars PPM")
    w, h = int(delar[1]), int(delar[2])
    data = b[pos + 1:pos + 1 + w * h * 3]
    if len(data) != w * h * 3:
        raise PpmFel("ffmpeg gav en bild med för lite data")
    return np.frombuffer(data, np.uint8).reshape(h, w, 3).copy()


def las_ruta(klipp: Path, t: float, bredd: int, hojd: int, satt: str) -> np.ndarray | None:
    """Rutan närmast t (s i läsarens tid) som (hojd, bredd, 3) uint8, eller None: ffmpeg
    och OpenCV ger första rutan från tiden, så de frågas från t − 2 ms (halva steget vid
    240 bilder/s). Bilden ska stå upprätt som lederna: ligger den ner kastas
    klipp.VridenFel (METOD MF1); en bild som ffmpeg gav trasig kastar PpmFel."""
    from .klipp import kontrollera_upprat
    t = max(0.0, t - NARMAST_S)
    if satt == "ffmpeg":
        r = subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{t:.4f}", "-i", str(klipp), "-frames:v", "1",
                            "-f", "image2pipe", "-vcodec", "ppm", "pipe:"], capture_output=True, timeout=60)
        if r.returncode != 0 or not r.stdout:
            return None
        img = _ppm(r.stdout)
    else:
        import cv2
        v = cv2.VideoCapture(str(klipp))
        try:
            v.set(cv2.CAP_PROP_POS_MSEC, t * 1000.0)
            ok, bild = v.read()
        finally:
            v.release()
        if not ok:
            return None
        img = cv2.cvtColor(bild, cv2.COLOR_BGR2RGB)
    kontrollera_upprat(img.shape[1], img.shape[0], bredd, hojd)
    if img.shape[:2] != (hojd, bredd):
        ys = np.minimum((np.arange(hojd) * img.shape[0] / hojd).astype(int), img.shape[0] - 1)
        xs = np.minimum((np.arange(bredd) * img.shape[1] / bredd).astype(int), img.shape[1] - 1)
        img = img[ys][:, xs]
    return np.ascontiguousarray(img)


def _punkt(img: np.ndarray, x: float, y: float, r: int = 1) -> None:
    h, w = img.shape[:2]
    xi, yi = int(round(x)), int(round(y))
    img[max(0, yi - r):min(h, yi + r + 1), max(0, xi - r):min(w, xi + r + 1)] = 255


def rita_leder(img: np.ndarray, leder: list, sx: float, sy: float) -> None:
    """Lederna som vita punkter och linjer (bara uppmätta linjer, BESLUT B13)."""
    p = []
    for j in leder:
        if j is None:
            p.append(None)
            continue
        x, y, c = (j["x"], j["y"], j["c"]) if isinstance(j, dict) else j
        p.append((x * sx, y * sy) if c > 0 else None)
    for a, b in BEN:
        if p[a] is None or p[b] is None:
            continue
        n = int(max(abs(p[b][0] - p[a][0]), abs(p[b][1] - p[a][1]))) + 1
        for u in np.linspace(0.0, 1.0, n):
            _punkt(img, p[a][0] + u * (p[b][0] - p[a][0]), p[a][1] + u * (p[b][1] - p[a][1]), 0)
    for q in p:
        if q is not None:
            _punkt(img, *q, 1)


def skriv_png(sokvag: Path, img: np.ndarray) -> None:
    """RGB-bild (h, w, 3) uint8 som PNG."""
    h, w = img.shape[:2]
    raa = b"".join(b"\x00" + img[y].tobytes() for y in range(h))

    def bit(typ: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + typ + data + struct.pack(">I", zlib.crc32(typ + data) & 0xFFFFFFFF)

    sokvag.write_bytes(b"\x89PNG\r\n\x1a\n" + bit(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                       + bit(b"IDAT", zlib.compress(raa, 6)) + bit(b"IEND", b""))


def tider(faser: dict) -> dict[str, float]:
    """Kolumnernas tider (s relativt klicket): adressens och finishens fönsters
    mitt (M4), toppen och träffen. METOD MT7"""
    s0 = faser["start"] if faser.get("start") is not None else faser["topp"] - TOPP_ADRESS_S
    return {"adress": s0 + sum(ADRESS) / 2, "topp": faser["topp"], "traff": faser["traff"],
            "finish": faser["traff"] + sum(FINISH) / 2}


def bygg(paket_fil: Path, paket, slag_rader: list[dict], ut: Path, satt: str | None = None,
         forskjutning_ms: dict[str, float] | None = None) -> dict:
    """Arket för ett paket. Svarar {"fil", "rader", "kolumner"} eller {"hoppat": skäl}.
    Varje kolumn tar Visions ruta närmast fasens tid och läser klippets ruta på samma
    tid, flyttad med S3:s förskjutning för slaget (`forskjutning_ms`, slagets id → ms;
    0 utan S3, METOD MF1). Ett skadat klipp i zippen kastar paket.PaketFel."""
    satt = satt or verktyg()
    if satt is None:
        return {"hoppat": "varken ffmpeg eller OpenCV finns"}
    matta = {r["id"]: r for r in slag_rader if "faser" in r}
    med_klipp = [s for s in paket.slag if s.klipp and s.id in matta and s.lederna][:MAX_RADER]
    if not med_klipp:
        return {"hoppat": "paketet har inga klipp till mätta slag"}
    w0, h0 = med_klipp[0].lederna["width"], med_klipp[0].lederna["height"]
    hojd = int(round(BREDD * h0 / w0 / 2)) * 2
    ark = np.zeros((len(med_klipp) * (hojd + MELLANRUM), len(KOLUMNER) * (BREDD + MELLANRUM), 3), np.uint8)
    rader = []
    with tempfile.TemporaryDirectory() as tmp, zipfile.ZipFile(paket_fil) as z:
        for i, s in enumerate(med_klipp):
            klipp = Path(tmp) / f"{s.id}{Path(s.klipp).suffix}"
            klipp.write_bytes(las_ur_zip(z, paket.fil, s.klipp))
            rutor = s.lederna["frames"]
            sx, sy = BREDD / s.lederna["width"], hojd / s.lederna["height"]
            d_s = (forskjutning_ms or {}).get(s.id, 0.0) / 1000.0
            for k, (fas, t) in enumerate(tider(matta[s.id]["faser"]).items()):
                narmast = min(rutor, key=lambda r: abs(r["t"] - t))
                tk = float(narmast["t"]) + float(s.klick_i_klipp_s)
                # Bara klippets rutor i [0; längd), inte de som följer med efter (METOD MS12).
                try:
                    img = las_ruta(klipp, tk + d_s, BREDD, hojd, satt) if i_klippet(s, tk) else None
                except (VridenFel, PpmFel) as e:
                    return {"hoppat": str(e)}
                if img is None:
                    img = np.zeros((hojd, BREDD, 3), np.uint8)
                rita_leder(img, narmast["joints"], sx, sy)
                y, x = i * (hojd + MELLANRUM), k * (BREDD + MELLANRUM)
                ark[y:y + hojd, x:x + BREDD] = img
            rader.append(s.id)
    ut.mkdir(parents=True, exist_ok=True)
    fil = ut / f"kontaktark-{paket.vy}.png"
    skriv_png(fil, ark)
    return {"fil": fil.name, "rader": rader, "kolumner": list(KOLUMNER)}
