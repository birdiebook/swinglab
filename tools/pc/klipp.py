"""Klippens rutor med OpenCV, för S3 och S7 (METOD MF1).

OpenCV vrider bilden upprätt (`CAP_PROP_ORIENTATION_AUTO`), och varje ruta bär sin
egen tid ur `CAP_PROP_POS_MSEC`. Den tiden räknas från videoströmmens start, inte
nödvändigtvis från klippets nolla där telefonen mätte `klick_i_klipp_s`: skillnaden
(förskjutningen) skattas per klipp ur lederna (`s3_facit.para_tider`). Här finns bara
läsningen och kontrollen att bilden står upp.
"""
from __future__ import annotations

from pathlib import Path
from typing import Iterator

import numpy as np


class VridenFel(ValueError):
    """Klippets bild ligger ner mot lederna: vridningen gick inte att läsa."""


def kontrollera_upprat(w: int, h: int, bredd: int, hojd: int) -> None:
    """Bilden (w × h) ska ha samma liggande eller stående form som lederna (bredd ×
    hojd). En kvadrat går inte att pröva."""
    if w != h and bredd != hojd and (w > h) != (bredd > hojd):
        raise VridenFel("klippets bild ligger ner mot lederna: OpenCV vred den inte upprätt "
                        "(uppdatera opencv-python)")


def ramar(fil: Path, bredd: int, hojd: int) -> Iterator[tuple[float, np.ndarray]]:
    """Varje ruta i klippet i ordning: (tiden i s enligt OpenCV, upprätt RGB-bild i
    klippets egen upplösning). Kastar VridenFel om bilden ligger ner."""
    import cv2
    cap = cv2.VideoCapture(str(fil))
    if hasattr(cv2, "CAP_PROP_ORIENTATION_AUTO"):
        cap.set(cv2.CAP_PROP_ORIENTATION_AUTO, 1)
    try:
        forsta = True
        while True:
            ok, ram = cap.read()
            if not ok:
                return
            if forsta:
                kontrollera_upprat(ram.shape[1], ram.shape[0], bredd, hojd)
                forsta = False
            yield cap.get(cv2.CAP_PROP_POS_MSEC) / 1000.0, cv2.cvtColor(ram, cv2.COLOR_BGR2RGB)
    finally:
        cap.release()


def ramar_vid(fil: Path, tider: list[float], bredd: int, hojd: int, tol: float) -> dict[float, tuple[float, np.ndarray]]:
    """Rutorna närmast de önskade tiderna (OpenCV:s tider), inom `tol` s:
    {önskad tid: (rutans tid, bilden)}. En tid utan ruta inom tol saknas i svaret."""
    kvar = sorted(tider)
    ut: dict[float, tuple[float, np.ndarray]] = {}
    basta: dict[float, tuple[float, np.ndarray]] = {}
    for r, bild in ramar(fil, bredd, hojd):
        for t in kvar:
            if abs(r - t) <= tol and (t not in basta or abs(r - t) < abs(basta[t][0] - t)):
                basta[t] = (r, bild)
        if kvar and r > kvar[-1] + tol:
            break
    for t in kvar:
        if t in basta:
            ut[t] = basta[t]
    return ut


def skala_ruta(ruta: tuple[int, int, int, int], w: int, h: int, bredd: int, hojd: int) -> tuple[int, int, int, int]:
    """Utsnittet i ledernas px → klippets px (samma bild i en annan upplösning), utåt
    till hela pixlar. Med samma storlek oförändrat."""
    if (w, h) == (bredd, hojd):
        return ruta
    sx, sy = w / bredd, h / hojd
    x0, y0 = int(np.floor(ruta[0] * sx)), int(np.floor(ruta[1] * sy))
    x1 = min(w, int(np.ceil((ruta[0] + ruta[2]) * sx)))
    y1 = min(h, int(np.ceil((ruta[1] + ruta[3]) * sy)))
    return x0, y0, x1 - x0, y1 - y0


def start_tid(fil: Path) -> float | None:
    """Videoströmmens start_time ur ffprobe (s), eller None när ffprobe saknas eller inte
    svarar. Bara en kontroll av förskjutningen (METOD MF1)."""
    import shutil
    import subprocess
    if not shutil.which("ffprobe"):
        return None
    try:
        r = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=start_time",
                            "-of", "csv=p=0", str(fil)], capture_output=True, text=True, timeout=30)
        return float(r.stdout.strip().split("\n")[0].rstrip(","))
    except (OSError, ValueError, subprocess.SubprocessError):
        return None
