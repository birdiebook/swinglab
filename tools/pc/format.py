"""Indataformatet: en sving som JSON, samma för telefon och PC (docs/FORMAT.md).

Lederna läses om till spelarens sidor, främre (mot målet) och bakre, och
bildens x vänds så att +X alltid pekar mot målet (FO) eller mot bollen (DTL).
Då räknar resten av koden som för en högerspelare. METOD M1
"""
from __future__ import annotations

import json
import math
from dataclasses import dataclass

import numpy as np

FORMAT = 1

# Ledernas ordning i filen: snittet av Apple Visions 2D-leder och MediaPipe.
LEDER_FIL = ("nasa", "axel_v", "axel_h", "armbage_v", "armbage_h", "handled_v", "handled_h",
             "hoft_v", "hoft_h", "kna_v", "kna_h", "fotled_v", "fotled_h")
# Internt: främre (f) och bakre (b) sida. För en högerspelare är främre = vänster.
LEDER = ("nasa", "axel_f", "axel_b", "armbage_f", "armbage_b", "handled_f", "handled_b",
         "hoft_f", "hoft_b", "kna_f", "kna_b", "fotled_f", "fotled_b")
(NASA, AXEL_F, AXEL_B, ARMBAGE_F, ARMBAGE_B, HANDLED_F, HANDLED_B,
 HOFT_F, HOFT_B, KNA_F, KNA_B, FOTLED_F, FOTLED_B) = range(13)
ANTAL_LEDER = 13

# Varje internt index → index i filen. Vänsterspelaren byter sida på varje par.
FRAN_FIL = {"hoger": tuple(range(13)),
            "vanster": (0, 2, 1, 4, 3, 6, 5, 8, 7, 10, 9, 12, 11)}

MIN_KONFIDENS = 0.3      # METOD M1: under detta räknas leden som saknad i rutan
VYER = ("dtl", "fo")
HANDER = ("hoger", "vanster")
LANGD_M = (1.0, 2.5)     # rimlig kroppslängd; utanför är fältet fel


class FormatFel(ValueError):
    """Felet nämner fältet och rutan, aldrig värdet (CLAUDE.md, Dataregeln)."""


@dataclass
class Sving:
    vy: str                # "dtl" eller "fo"
    hand: str              # "hoger" eller "vanster"
    x_tecken: float        # +1 eller −1: bildens x mot målet (FO) eller bollen (DTL)
    langd_m: float
    t_klick: float
    t: np.ndarray          # (n,) sekunder, stigande
    xy: np.ndarray         # (n, 13, 2) X (+ mot målet/bollen), Y (nedåt), px; NaN = saknad


def _tal(v, falt: str) -> float:
    if isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v):
        raise FormatFel(f"{falt}: ska vara ett ändligt tal")
    return float(v)


def fran_dict(d: dict) -> Sving:
    if not isinstance(d, dict):
        raise FormatFel("svingen ska vara ett JSON-objekt")
    if d.get("format") != FORMAT:
        raise FormatFel(f"format: ska vara {FORMAT}")
    vy, hand = d.get("vy"), d.get("hand")
    if vy not in VYER:
        raise FormatFel("vy: ska vara \"dtl\" eller \"fo\"")
    if hand not in HANDER:
        raise FormatFel("hand: ska vara \"hoger\" eller \"vanster\"")
    falt = "x_mot_malet" if vy == "fo" else "x_mot_bollen"
    # Utan fältet: standardkameran, där vänsterspelaren är spegelvänd.
    tecken = _tal(d[falt], falt) if d.get(falt) is not None else (1.0 if hand == "hoger" else -1.0)
    if tecken not in (1.0, -1.0):
        raise FormatFel(f"{falt}: ska vara 1 eller -1")
    langd = _tal(d.get("spelarens_langd_m"), "spelarens_langd_m")
    if not LANGD_M[0] <= langd <= LANGD_M[1]:
        raise FormatFel("spelarens_langd_m: utanför 1,0–2,5 m")
    t_klick = _tal(d.get("t_klick"), "t_klick")
    rutor = d.get("rutor")
    if not isinstance(rutor, list) or not rutor:
        raise FormatFel("rutor: saknas eller är tom")

    n = len(rutor)
    t = np.empty(n)
    raa = np.empty((n, ANTAL_LEDER, 3))
    for i, r in enumerate(rutor):
        if not isinstance(r, dict):
            raise FormatFel(f"ruta {i}: ska vara ett objekt")
        t[i] = _tal(r.get("t"), f"ruta {i}: t")
        leder = r.get("leder")
        if not isinstance(leder, list) or len(leder) != ANTAL_LEDER:
            raise FormatFel(f"ruta {i}: leder ska vara {ANTAL_LEDER} st")
        for j, led in enumerate(leder):
            if not isinstance(led, list) or len(led) != 3:
                raise FormatFel(f"ruta {i}, {LEDER_FIL[j]}: ska vara [x, y, konfidens]")
            for k in range(3):
                raa[i, j, k] = _tal(led[k], f"ruta {i}, {LEDER_FIL[j]}")

    ordning = np.argsort(t, kind="stable")
    t, raa = t[ordning], raa[ordning]
    karta = FRAN_FIL[hand]
    xy = np.empty((n, ANTAL_LEDER, 2))
    for i_int, i_fil in enumerate(karta):
        xy[:, i_int, 0] = tecken * raa[:, i_fil, 0]
        xy[:, i_int, 1] = raa[:, i_fil, 1]
        saknad = raa[:, i_fil, 2] < MIN_KONFIDENS
        xy[saknad, i_int, :] = np.nan
    return Sving(vy=vy, hand=hand, x_tecken=tecken, langd_m=langd, t_klick=t_klick, t=t, xy=xy)


def las(text: str) -> Sving:
    try:
        d = json.loads(text)
    except json.JSONDecodeError as e:
        raise FormatFel(f"inte giltig JSON (rad {e.lineno})") from None
    return fran_dict(d)


def las_fil(sokvag) -> Sving:
    with open(sokvag, encoding="utf-8") as f:
        try:
            return las(f.read())
        except FormatFel as e:
            raise FormatFel(f"{sokvag}: {e}") from None
