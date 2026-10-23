"""Klubban ur handmarkerade punkter (PLAN S7a, BESLUT B47, METOD M45–M49).

Johannes markerar greppet och hoseln på en ruta per P-position, på telefonen eller med
`markera_klubba.py` på PC:n. Samma markering är träningsdata för S7:s detektor och ger
klubbmåtten direkt. Den här modulen äger:

  formatet   `swinglab-klubba/2` (docs/FORMAT.md, "Klubbans märkning"): kontrollen av
             version 1 och 2, uppgraderingen och markeringarna per slag ur en fil;
  rutorna    förslaget till P2, P6 och P8 ur kroppens tider (METOD M45);
  måtten     skaftets vinkel i bild vid varje position och måtten vid P1, P2, P4, P6 och
             P7 i var sin vy (METOD M46–M49), samma tal som SwingLabKits `Klubba`
             (BESLUT B12);
  fixturerna `python3 tools/pc/klubba.py --swift` skriver
             SwingLabKit/Tests/SwingTests/KlubbFixturer.swift.

Punkterna står i hela den upprätta bildens pixlar med y nedåt, som lederna. x speglas med
svingens `x_tecken` (format.py), så att +X pekar mot bollen (DTL) eller målet (FO) och en
vänsterspelare räknas som en högerspelare (METOD M1). Vinklarna räknas med y uppåt.
"""
from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

import numpy as np

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "pc"

from . import faser as F  # noqa: E402
from .format import AXEL_F, HANDLED_F, Sving  # noqa: E402

# --- formatet --------------------------------------------------------------------------

FORMAT_1 = "swinglab-klubba/1"
FORMAT = "swinglab-klubba/2"          # BESLUT B47: P-positionerna och telefonens markeringar
PUNKTER = ("grepp", "skaft_mitt", "klubbhuvud")     # BESLUT B44: klubbhuvudet = GolfPose hosel
POSITIONER = ("P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8", "P9", "P10")
SKAFTETS = ("P2", "P6", "P8")         # METOD M45: definieras av skaftet, inte av kroppen
VAL_1 = ("adress", "topp", "tidig_nedsving", "jamn")
VAL = VAL_1 + POSITIONER
STATUS = ("omarkerad", "markerad", "hoppad")
KALLOR = ("klick", "handlederna_bekraftad")   # BESLUT B44, B47: ett fritt tryck, eller ringen ur handlederna bekräftad med ett tryck
PASS_ID = re.compile(r"^\d{8}-\d{6}$")
FIL = "klubba.json"                   # filen i paketet (docs/FORMAT.md)

# --- måtten ----------------------------------------------------------------------------

TRYCK_PX = 3.0         # METOD M46: antagen osäkerhet per tryck, px i hela bilden (1 sd)
MAX_SD = 4.0           # METOD M46: ett mått vars skattade osäkerhet ur trycken är större saknas, grader
STEG_PX = 0.5          # METOD M46: steget i de centrala differenserna för osäkerheten
CENTRUM_MARGINAL = 0.05   # METOD M48: greppet ska stå så mycket av bildhöjden över flyktpunkten vid toppen
MARGINAL_TELEFON = 0.15  # METOD M45, MF6: telefonens märkning visar utsnittet vidgat så mycket per sida
PINNE_MIN_DY = 0.05    # METOD M48: riktpinnens linje måste gå så mycket av bildhöjden i y, annars bildens mitt

PER_POSITION = ("skaft_vinkel",)      # METOD M46: ett mått per position, skaft_vinkel_p1 … _p10
MATT_DTL = ("skaftplan_p1", "skaft_riktning_topp", "skaft_plan_p6")
MATT_FO = ("skaft_topp", "skaft_arm_p5", "skaft_arm_p6", "skaft_lutning_traff")
SPECIFIKA = {"dtl": MATT_DTL, "fo": MATT_FO}


def nyckel(matt: str, position: str) -> str:
    """Måttets namn vid en position: skaft_vinkel vid P4 → skaft_vinkel_p4; ett mått som
    inte är per position heter som det heter. METOD M46"""
    return f"{matt}_{position.lower()}" if matt in PER_POSITION else matt


def namn(vy: str) -> tuple[str, ...]:
    """Alla klubbmått i vyn, som de står i en svings `matt`."""
    return tuple(nyckel(m, p) for m in PER_POSITION for p in POSITIONER) + SPECIFIKA[vy]


def katalognamn(vy: str) -> tuple[str, ...]:
    """Namnen som katalogens `matt` får peka på: de specifika och familjen per position."""
    return PER_POSITION + SPECIFIKA[vy]


class KlubbFel(ValueError):
    """Felet nämner rutans plats och fältet, aldrig värdet (CLAUDE.md, Dataregeln)."""


def _tal(v) -> bool:
    return not isinstance(v, bool) and isinstance(v, (int, float)) and math.isfinite(v)


def _heltal(v) -> bool:
    return not isinstance(v, bool) and isinstance(v, int)


def kontrollera(d) -> list[str]:
    """Formen på märkningen, version 1 och 2 (docs/FORMAT.md, "Klubbans märkning").
    Version 2 tillåter P-positionerna som `val`, `t_klipp` och `forskjutning_ms` som null
    (telefonens markering utan klipp och utan S3) och en markerad ruta utan skaftets mitt.
    Felen nämner rutans plats och fältet, aldrig värdet. BESLUT B44, B47"""
    if not isinstance(d, dict):
        return ["märkningen ska vara ett JSON-objekt"]
    fel = []
    v2 = d.get("format") == FORMAT
    if d.get("format") not in (FORMAT_1, FORMAT):
        fel.append(f"format ska vara {FORMAT_1} eller {FORMAT}")
    if d.get("punkter") != list(PUNKTER):
        fel.append(f"punkter ska vara {list(PUNKTER)}")
    if d.get("pass") is not None and not (isinstance(d["pass"], str) and PASS_ID.match(d["pass"])):
        fel.append("pass ska vara yyyyMMdd-HHmmss eller null")
    if not isinstance(d.get("kalla"), list) or not all(isinstance(k, str) for k in d["kalla"]):
        fel.append("kalla ska vara en lista med filnamn")
    if not isinstance(d.get("andrad"), str):
        fel.append("andrad ska vara en tid")
    rutor = d.get("rutor")
    if not isinstance(rutor, list):
        return fel + ["rutor ska vara en lista"]
    val = VAL if v2 else VAL_1
    kravs = ("grepp", "klubbhuvud") if v2 else PUNKTER
    ids = set()
    for i, r in enumerate(rutor):
        p = f"rutor[{i}]"
        if not isinstance(r, dict):
            fel.append(f"{p} ska vara ett objekt")
            continue
        if not isinstance(r.get("id"), str) or not r["id"]:
            fel.append(f"{p}.id ska vara text")
        elif r["id"] in ids:
            fel.append(f"{p}.id finns två gånger")
        ids.add(r.get("id"))
        if not isinstance(r.get("fil"), str):
            fel.append(f"{p}.fil ska vara text")
        if r.get("vy") not in ("dtl", "fo", None):
            fel.append(f"{p}.vy ska vara dtl, fo eller null")
        if r.get("slag") is not None and not isinstance(r["slag"], str):
            fel.append(f"{p}.slag ska vara text eller null")
        if r.get("val") not in val:
            fel.append(f"{p}.val ska vara en av {', '.join(val)}")
        if r.get("t") is not None and not _tal(r["t"]):
            fel.append(f"{p}.t ska vara ett tal eller null")
        tk = r.get("t_klipp")
        if not ((v2 and tk is None) or (_tal(tk) and tk >= 0)):
            fel.append(f"{p}.t_klipp ska vara ett tal ≥ 0" + (" eller null" if v2 else ""))
        fs = r.get("forskjutning_ms")
        if not ((v2 and fs is None) or _tal(fs)):
            fel.append(f"{p}.forskjutning_ms ska vara ett tal" + (" eller null" if v2 else ""))
        if r.get("t_ruta") is not None and not (_tal(r["t_ruta"]) and r["t_ruta"] >= 0):
            fel.append(f"{p}.t_ruta ska vara ett tal ≥ 0 eller null")
        bh = (r.get("bredd"), r.get("hojd"))
        if not all(_heltal(v) and v > 0 for v in bh):
            fel.append(f"{p}.bredd och hojd ska vara positiva heltal")
            bh = None
        v = r.get("visad")
        if not (isinstance(v, list) and len(v) == 4 and all(_heltal(x) for x in v)):
            fel.append(f"{p}.visad ska vara fyra heltal")
        elif bh and not (v[0] >= 0 and v[1] >= 0 and v[2] > 0 and v[3] > 0
                         and v[0] + v[2] <= bh[0] and v[1] + v[3] <= bh[1]):
            fel.append(f"{p}.visad ska ligga inom bilden")
        if r.get("status") not in STATUS:
            fel.append(f"{p}.status ska vara en av {', '.join(STATUS)}")
        pk = r.get("punkter")
        if not isinstance(pk, dict) or set(pk) != set(PUNKTER):
            fel.append(f"{p}.punkter ska ha exakt {', '.join(PUNKTER)}")
        else:
            for n in PUNKTER:
                q = pk[n]
                if q is None:
                    if r.get("status") == "markerad" and n in kravs:
                        fel.append(f"{p}.punkter.{n} saknas i en markerad ruta")
                    continue
                if q == {"syns_inte": True}:
                    continue
                if not (isinstance(q, dict) and set(q) == {"x", "y", "kalla"} and _tal(q["x"]) and _tal(q["y"])
                        and q["kalla"] in (KALLOR if v2 else KALLOR[:1])):
                    fel.append(f"{p}.punkter.{n} ska vara null, {{x, y, kalla}} eller {{syns_inte: true}}")
                elif bh and not (0 <= q["x"] <= bh[0] and 0 <= q["y"] <= bh[1]):
                    fel.append(f"{p}.punkter.{n} ligger utanför bilden")
        fs = r.get("forslag")
        if not isinstance(fs, dict) or not set(fs) <= set(PUNKTER) or not all(
                isinstance(q, dict) and _tal(q.get("x")) and _tal(q.get("y")) and isinstance(q.get("kalla"), str)
                for q in fs.values()):
            fel.append(f"{p}.forslag ska vara {{punkt: {{x, y, kalla}}}}")
        if len(fel) > 30:
            return fel + ["fler fel hoppas över"]
    return fel


def uppgradera(d: dict) -> dict:
    """Version 1 som version 2: v1 är en delmängd av v2, så bara formatet byts. BESLUT B47"""
    return {**d, "format": FORMAT} if d.get("format") == FORMAT_1 else d


def las_dict(d, namn: str = "märkningen") -> dict:
    """Kontrollerad och uppgraderad till version 2; KlubbFel med fälten annars."""
    f = kontrollera(d)
    if f:
        raise KlubbFel(f"{namn}: " + "; ".join(f))
    return uppgradera(d)


def _punkt(q) -> tuple[float, float] | None:
    return (float(q["x"]), float(q["y"])) if isinstance(q, dict) and "x" in q else None


def markeringar(d: dict, slag: str | None = None) -> dict[str | None, list[dict]]:
    """Markeringarna per slag ur en (kontrollerad) fil: rutorna vars `val` är en
    P-position och som har Visions tid `t`, som {"position", "t", "grepp", "hosel"} med
    punkterna (x, y) i hela bildens pixlar, eller None där punkten inte är satt eller inte
    syns. En hoppad ruta har inga punkter. `slag` = bara det slaget. METOD M45"""
    ut: dict[str | None, list[dict]] = {}
    for r in d["rutor"]:
        if r["val"] not in POSITIONER or r.get("t") is None or (slag is not None and r.get("slag") != slag):
            continue
        hoppad = r["status"] == "hoppad"
        ut.setdefault(r.get("slag"), []).append({
            "position": r["val"], "t": float(r["t"]),
            "grepp": None if hoppad else _punkt(r["punkter"]["grepp"]),
            "hosel": None if hoppad else _punkt(r["punkter"]["klubbhuvud"]),
            "bredd": r["bredd"], "hojd": r["hojd"]})
    return ut


# --- rutorna: P2, P6 och P8 ------------------------------------------------------------

def forslag_tid(position: str, positioner: dict) -> float | None:
    """Rutan som föreslås för en position, s relativt klicket (METOD M45). Kroppens
    positioner (P1, P3, P4, P5, P7, P9, P10, METOD M28) föreslås där de är. P2, P6 och P8
    definieras av skaftet: mitt mellan P1 och P3 (annars P4), mitt mellan P5 (annars P4) och
    P7, och mitt mellan P7 och P9 (annars P10). Johannes stegar därifrån till rutan där
    skaftet bakifrån är kortast (pekar mot flyktpunkten) eller framifrån parallellt med
    marken. Bara positionerna, så att telefonen och PC:n föreslår samma ruta. None när en
    ände saknas."""
    p = positioner.get

    def mitt(a, b):
        return (a + b) / 2 if a is not None and b is not None else None

    if position == "P2":
        return mitt(p("P1"), p("P3") if p("P3") is not None else p("P4"))
    if position == "P6":
        return mitt(p("P5") if p("P5") is not None else p("P4"), p("P7"))
    if position == "P8":
        return mitt(p("P7"), p("P9") if p("P9") is not None else p("P10"))
    return p(position)


# METOD M45: framifrån går skaftet genom vågrätt mellan positionerna före och efter. Ändarna,
# vinkeln som är vågrätt (M46: 180 = bort från målet, 0 = mot målet) och åt vilket håll
# vinkeln går i den speglade bilden: baksvingen medurs (minskar), nedsvingen moturs (ökar).
SKAFT_VAGRATT = {"P2": ("P1", "P3", 180.0, -1.0), "P6": ("P5", "P7", 180.0, 1.0), "P8": ("P7", "P9", 0.0, 1.0)}


def forslag_tid_skaft(position: str, marks: list[dict], x_tecken: float) -> float | None:
    """Framifrån (FO): rutan där skaftets vinkel (M46), linjärt i tiden mellan de markerade
    positionerna före och efter (P1 och P3 för P2, P5 och P7 för P6, P7 och P9 för P8), går
    genom vågrätt, s relativt klicket (METOD M45). Vinkeln följer svingens håll (SKAFT_VAGRATT),
    så att ett varv över ±180° räknas rätt. None när en ände saknas eller är hoppad, när
    tiderna inte är i ordning, eller när vinkeln inte passerar vågrätt mellan ändarna."""
    if position not in SKAFT_VAGRATT:
        return None
    fore, efter, vagratt, hall = SKAFT_VAGRATT[position]
    pos = {m["position"]: m for m in marks if m.get("grepp") is not None and m.get("hosel") is not None}
    if fore not in pos or efter not in pos:
        return None
    a, b = pos[fore], pos[efter]
    ta, tb = float(a["t"]), float(b["t"])
    if not tb > ta:
        return None
    s = float(x_tecken)

    def vinkel(m):
        return riktning((s * m["grepp"][0], m["grepp"][1]), (s * m["hosel"][0], m["hosel"][1]))
    va, vb = vinkel(a), vinkel(b)
    spann = ((vb - va) * hall) % 360.0
    dit = ((vagratt - va) * hall) % 360.0
    if not spann > 0 or dit > spann:
        return None
    return ta + (tb - ta) * dit / spann


# --- flyktpunkten ----------------------------------------------------------------------

def flyktpunkt(pinne, bredd: int, hojd: int) -> tuple[tuple[float, float], bool]:
    """Mållinjens flyktpunkt i bild (hela bildens pixlar) och om den är antagen (METOD M48).
    Med riktpinnen (två tryck på en pinne på marken, parallell med mållinjen) ligger den där
    pinnens linje skär bildens vågräta mittlinje (kameran i våg, lodlinjen); utan pinne, eller
    när pinnens linje nästan är vågrät i bild, är den bildens mitt och antagen."""
    mitt = (bredd / 2.0, hojd / 2.0)
    if not pinne or len(pinne) != 2 or pinne[0] is None or pinne[1] is None:
        return mitt, True
    (ax, ay), (bx, by) = pinne
    if abs(by - ay) < PINNE_MIN_DY * hojd:
        return mitt, True
    u = (mitt[1] - ay) / (by - ay)
    return (ax + u * (bx - ax), mitt[1]), False


# --- måtten ----------------------------------------------------------------------------

def _g(v: float) -> float:
    return math.degrees(v)


def _upp(a, b) -> tuple[float, float]:
    """Vektorn a → b med y uppåt (bildens y är nedåt)."""
    return (b[0] - a[0], -(b[1] - a[1]))


def riktning(a, b) -> float:
    """Vektorn a → b mot vågrätt +X, grader i (−180, 180], + moturs med y uppåt."""
    dx, dy = _upp(a, b)
    return _g(math.atan2(dy, dx))


def vinkel_mellan(u, v) -> float:
    """Vinkeln från u till v, grader i (−180, 180], + moturs (vektorerna med y uppåt)."""
    return _g(math.atan2(u[0] * v[1] - u[1] * v[0], u[0] * v[0] + u[1] * v[1]))


def _wrap180(d: float) -> float:
    d = (d + 180.0) % 360.0 - 180.0
    return 180.0 if d == -180.0 else d


def osakerhet(f, punkter: list, tryck_px: float = TRYCK_PX) -> float:
    """Måttets osäkerhet (1 sd, grader) av tryckens: varje punkt i `punkter` osäker
    `tryck_px` i x och i y, oberoende, genom måttets egen geometri `f(punkter)` (centrala
    differenser med steget STEG_PX). METOD M46"""
    s2 = 0.0
    for i in range(len(punkter)):
        for k in (0, 1):
            plus = [list(q) for q in punkter]
            minus = [list(q) for q in punkter]
            plus[i][k] += STEG_PX
            minus[i][k] -= STEG_PX
            d = _wrap180(f(plus) - f(minus)) / (2.0 * STEG_PX)
            s2 += (d * tryck_px) ** 2
    return math.sqrt(s2)


def _matt(ut: dict, sd: dict, namn_: str, f, punkter: list) -> None:
    """Måttet när dess skattade osäkerhet är högst MAX_SD; annars saknas det. METOD M46"""
    o = osakerhet(f, punkter)
    if o <= MAX_SD:
        ut[namn_] = f(punkter)
        sd[namn_] = o


def mat(marks: list[dict], vy: str, x_tecken: float, bredd: int, hojd: int, sving: Sving | None = None,
        pinne=None, med_sd: bool = False):
    """Klubbmåtten för ett slag ur dess markeringar (METOD M46–M49). `marks` =
    [{"position", "t", "grepp", "hosel"}], punkterna i hela bildens pixlar eller None.
    `sving` = slagets sving (format.py) för armen i FO; utan den saknas skaft_arm_*.
    `pinne` = seriens riktpinne (två punkter) för flyktpunkten bakifrån (M48). Ett mått saknas
    när en punkt saknas eller när dess skattade osäkerhet ur trycken är över MAX_SD.
    `med_sd` = svara också osäkerheten per mått."""
    s = float(x_tecken)
    spegel = lambda q: (s * q[0], q[1])  # noqa: E731
    pos: dict[str, dict] = {}
    for m in marks:
        if m.get("grepp") is None or m.get("hosel") is None or m.get("position") not in POSITIONER:
            continue
        pos[m["position"]] = {"t": float(m["t"]), "g": spegel(m["grepp"]), "h": spegel(m["hosel"])}
    ut: dict[str, float] = {}
    sd: dict[str, float] = {}
    for p, q in pos.items():                                              # METOD M46
        _matt(ut, sd, nyckel("skaft_vinkel", p), lambda x: riktning(x[0], x[1]), [q["g"], q["h"]])
    if vy == "dtl":
        p1 = pos.get("P1")
        if p1:
            # Skaftplanet: linjen genom hoseln och greppet vid P1, vinkeln mot marken sedd
            # från bollens sida (hoseln åt +X). METOD M47
            def plan(x):
                g, h = x[0], x[1]
                return _g(math.atan2(-(g[1] - h[1]), h[0] - g[0]))
            _matt(ut, sd, "skaftplan_p1", plan, [p1["g"], p1["h"]])
            p6 = pos.get("P6")
            if p6:
                # Hoseln vid P6 sedd från hoseln vid P1: + över planet. Bara P1:s punkter och
                # hoseln vid P6 ingår, så skaftets längd vid P6 spelar ingen roll. METOD M47
                _matt(ut, sd, "skaft_plan_p6", lambda x: -vinkel_mellan(_upp(x[1], x[0]), _upp(x[1], x[2])),
                      [p1["g"], p1["h"], p6["h"]])
        p4 = pos.get("P4")
        if p4:
            # Mot riktningen som ett skaft parallellt med mållinjen tar i bild: mot flyktpunkten.
            # Med riktpinnen ingår dess två tryck i osäkerheten. METOD M48
            pin = [spegel(q) for q in pinne] if pinne and len(pinne) == 2 and all(pinne) else None

            def topp(x):
                c, antagen = flyktpunkt([x[2], x[3]] if pin else None, bredd, hojd)
                if antagen:
                    c = (s * bredd / 2.0, hojd / 2.0)          # bildens mitt, speglad
                g = x[0]
                if c[1] - g[1] < CENTRUM_MARGINAL * hojd:
                    return math.nan
                return vinkel_mellan(_upp(g, c), _upp(g, x[1]))
            punkter = [p4["g"], p4["h"]] + (pin or [])
            if math.isfinite(topp(punkter)):
                _matt(ut, sd, "skaft_riktning_topp", topp, punkter)
    else:
        p4, p7 = pos.get("P4"), pos.get("P7")
        if p4:
            _matt(ut, sd, "skaft_topp", lambda x: riktning(x[0], x[1]), [p4["g"], p4["h"]])     # METOD M49
        if p7:
            _matt(ut, sd, "skaft_lutning_traff",                                                # METOD M49
                  lambda x: _g(math.atan2(*_upp(x[1], x[0]))), [p7["g"], p7["h"]])
        if sving is not None:
            axel = F.jamna(sving.t, sving.xy[:, AXEL_F])
            hand = F.jamna(sving.t, sving.xy[:, HANDLED_F])
            for p in ("P5", "P6"):
                q = pos.get(p)
                if not q:
                    continue
                a, w = F.vid(sving.t, axel, q["t"]), F.vid(sving.t, hand, q["t"])
                if not (np.isfinite(a).all() and np.isfinite(w).all()):
                    continue
                arm = (float(a[0] - w[0]), float(-(a[1] - w[1])))
                if not math.hypot(*arm) > 0:
                    continue

                def casting(x, arm=arm):
                    skaft = _upp(x[0], x[1])
                    la, ls = math.hypot(*arm), math.hypot(*skaft)
                    if not ls > 0:
                        return math.nan
                    cos = (arm[0] * skaft[0] + arm[1] * skaft[1]) / (la * ls)
                    return _g(math.acos(max(-1.0, min(1.0, cos))))
                _matt(ut, sd, f"skaft_arm_{p.lower()}", casting, [q["g"], q["h"]])            # METOD M49
    return (ut, sd) if med_sd else ut


# --- fixturerna för Swift (BESLUT B12) -------------------------------------------------

FIXTURFIL = Path(__file__).resolve().parents[2] / "SwingLabKit" / "Tests" / "SwingTests" / "KlubbFixturer.swift"
# Trycken på ytan till bildens pixlar, för märkningens logik (Capture, ClubMarking).
YTAFIL = Path(__file__).resolve().parents[2] / "SwingLabKit" / "Tests" / "CaptureTests" / "KlubbYtaFixturer.swift"
FIXTUR_BREDD, FIXTUR_HOJD = 1080, 2880   # högre bild: greppet vid toppen står över mitten (M48)
# Påhittade skaft per position: vinkeln grepp → hosel i den speglade bilden (y uppåt) och
# längden i px. Bakifrån som i bild: P4 60–95 px, P2, P6 och P8 korta (skaftet pekar mot
# kameran), så att spärren på osäkerheten prövas (M46). Framifrån som i bild: de påhittade
# svingarna har 400 px/m (0,25 cm/px), och grepp → hosel är 0,80 m (järn 7) = 320 px när
# skaftet ligger i bildens plan; P2, P6 och P8 (parallellt med mållinjen) 310 px, adressen och
# träffen (skaftet lutar mot kameran) 285–290 px, P3, P5 och P9 220–240 px och finishen
# 160 px (METOD M49, 3D-provet).
SATTA = {
    "dtl": {"P1": (-60.0, 330.0), "P2": (-35.0, 40.0), "P3": (100.0, 150.0), "P4": (-75.0, 80.0),
            "P5": (95.0, 150.0), "P6": (-40.0, 45.0), "P7": (-58.0, 300.0), "P8": (150.0, 35.0),
            "P9": (110.0, 150.0), "P10": (170.0, 120.0)},
    "fo": {"P1": (-95.0, 285.0), "P2": (175.0, 310.0), "P3": (130.0, 220.0), "P4": (10.0, 280.0),
           "P5": (100.0, 240.0), "P6": (175.0, 310.0), "P7": (-104.0, 290.0), "P8": (5.0, 310.0),
           "P9": (80.0, 220.0), "P10": (-20.0, 160.0)},
}
# En påhittad riktpinne bakifrån (två tryck, bildens pixlar) för fallet dtl (M48).
FIXTUR_PINNE = ((585.0, 2700.0), (560.0, 2100.0))


def pahittade_markeringar(indata: str, hoppa: tuple[str, ...] = ()) -> tuple[list[dict], Sving]:
    """Påhittade markeringar på en påhittad sving i filformatet (generera.py): greppet på
    handledernas mitt + en förskjutning i bild, hoseln längs den satta vinkeln (SATTA), på
    rutan närmast förslaget för varje position (M45). Positionerna i `hoppa` hoppas över.
    Svarar markeringarna (i bildens pixlar, ospeglade) och svingen."""
    from . import format as fm
    from . import matt as M
    sv = fm.las(indata)
    r = M.mat(sv)
    d = json.loads(indata)
    t = np.array([x["t"] for x in d["rutor"]])
    marks = []
    for p in POSITIONER:
        tf = forslag_tid(p, r["positioner"])
        if tf is None:
            continue
        k = int(np.argmin(np.abs(t - tf)))
        tk = float(t[k])
        if p in hoppa:
            marks.append({"position": p, "t": tk, "grepp": None, "hosel": None})
            continue
        leder = d["rutor"][k]["leder"]
        hander = [h for h in (leder[5], leder[6]) if h[2] >= 0.3] or [leder[5], leder[6]]
        gx = sum(h[0] for h in hander) / len(hander) + 6.0 * sv.x_tecken
        gy = sum(h[1] for h in hander) / len(hander) - 4.0
        vinkel, langd = SATTA[sv.vy][p]
        # Vinkeln gäller den speglade bilden: x i filen = x_tecken · X.
        hx = gx + sv.x_tecken * langd * math.cos(math.radians(vinkel))
        hy = gy - langd * math.sin(math.radians(vinkel))
        marks.append({"position": p, "t": tk, "grepp": (round(gx, 1), round(gy, 1)),
                      "hosel": (round(hx, 1), round(hy, 1))})
    return marks, sv


def fixtur_markeringar(namn_: str, hoppa: tuple[str, ...] = ()) -> tuple[list[dict], Sving]:
    """Påhittade markeringar på en av Fixturer.swifts svingar (generera.py --swift)."""
    from . import generera as gen
    return pahittade_markeringar(gen.fixtursving(namn_), hoppa)


FIXTURFALL = (("dtl", (), FIXTUR_PINNE), ("dtl_vanster", (), None), ("fo", (), None), ("fo_vanster", ("P8",), None))


def visad_telefonen(utsnitt, bredd: int, hojd: int) -> list[int]:
    """Det telefonens märkning visar (`ClubMarking.shownCrop`): seriens utsnitt vidgat 15 %
    per sida, inom bilden, på hela pixlar som `paket.utsnitt_px`. Hela bilden utan utsnitt.
    METOD M45"""
    from .paket import utsnitt_px
    if utsnitt is None:
        return [0, 0, bredd, hojd]
    x, y, b, h = utsnitt
    if x <= 0 and y <= 0 and b >= 1 and h >= 1:
        return [0, 0, bredd, hojd]
    mx, my = b * MARGINAL_TELEFON, h * MARGINAL_TELEFON
    x0, y0 = max(0.0, x - mx), max(0.0, y - my)
    x1, y1 = min(1.0, x + b + mx), min(1.0, y + h + my)
    return list(utsnitt_px((x0, y0, x1 - x0, y1 - y0), bredd, hojd))


def yta_till_bild(u: float, v: float, visad: list) -> tuple[float, float]:
    """Ett tryck på telefonens yta (0–1 i det visade utsnittet) i hela bildens pixlar: samma
    pixel som telefonen sparar (`ClubMarking.imagePoint`). METOD M45"""
    return (visad[0] + u * visad[2], visad[1] + v * visad[3])


def fil_ur(marks: list[dict], vy: str, pass_id: str, fil: str, slag: str, bredd: int = FIXTUR_BREDD,
           hojd: int = FIXTUR_HOJD, rutor: list | None = None) -> dict:
    """Markeringarna som en fil i version 2, som telefonen skriver den (PassPackage, BESLUT
    B47): `t_klipp` och `forskjutning_ms` null, `visad` hela bilden. `rutor` = lägg till."""
    rutor = list(rutor or [])
    for m in marks:
        satt = m["grepp"] is not None
        rutor.append({
            "id": f"{vy}-{slag}-{m['position']}", "fil": fil, "vy": vy, "slag": slag, "val": m["position"],
            "t": m["t"], "t_klipp": None, "forskjutning_ms": None, "t_ruta": None,
            "bredd": bredd, "hojd": hojd, "visad": [0, 0, bredd, hojd],
            "status": "markerad" if satt else "hoppad",
            "punkter": {"grepp": {"x": m["grepp"][0], "y": m["grepp"][1],
                                  "kalla": m.get("grepp_kalla", "klick")} if satt else None,
                        "skaft_mitt": None,
                        "klubbhuvud": {"x": m["hosel"][0], "y": m["hosel"][1], "kalla": "klick"} if satt else None},
            "forslag": {}})
    return {"format": FORMAT, "pass": pass_id, "kalla": [fil], "punkter": list(PUNKTER),
            "andrad": "2026-10-23T12:00:00+02:00", "rutor": rutor}


def _som_lista(marks: list[dict]) -> list[dict]:
    return [{"position": m["position"], "t": m["t"], "grepp": list(m["grepp"]) if m["grepp"] else None,
             "hosel": list(m["hosel"]) if m["hosel"] else None} for m in marks]


def fixturer() -> dict:
    """Fallen för Swift: svingen (namnet i Fixturer.swift), markeringarna, riktpinnen och
    Pythons mått och osäkerheter; en fil i version 2 som Swift ska läsa; förslagen till P2,
    P6 och P8; och tryck på ytan i hela bildens pixlar. BESLUT B12"""
    fall = []
    for namn_, hoppa, pinne in FIXTURFALL:
        marks, sv = fixtur_markeringar(namn_, hoppa)
        ut, sd = mat(marks, sv.vy, sv.x_tecken, FIXTUR_BREDD, FIXTUR_HOJD, sv, pinne=pinne, med_sd=True)
        fall.append({"sving": namn_, "bredd": FIXTUR_BREDD, "hojd": FIXTUR_HOJD,
                     "pinne": [list(q) for q in pinne] if pinne else None,
                     "markeringar": _som_lista(marks), "matt": ut, "sd": sd})
    marks, _ = fixtur_markeringar("dtl")
    marks[0] = {**marks[0], "grepp_kalla": "handlederna_bekraftad"}
    fil = fil_ur(marks, "dtl", "20261103-180000", "swinglab-20261103-180000-dtl.zip", "s03")
    yta = []
    # Samma tryck, samma pixel i båda vyerna; framifrån ett utsnitt kring spelaren med plats för
    # klubban vid toppen och i finishen.
    for vy, utsnitt, u, v in (("dtl", None, 0.5, 0.5), ("dtl", (0.2, 0.1, 0.5, 0.6), 0.25, 0.75),
                              ("dtl", (0.0, 0.3, 0.9, 0.7), 0.031, 0.969), ("fo", (0.15, 0.2, 0.7, 0.75), 0.62, 0.18),
                              ("fo", (0.25, 0.3, 0.5, 0.55), 0.97, 0.03)):
        visad = visad_telefonen(utsnitt, 1080, 1920)
        yta.append({"vy": vy, "utsnitt": list(utsnitt) if utsnitt else None, "bredd": 1080, "hojd": 1920, "u": u,
                    "v": v, "visad": visad, "punkt": list(yta_till_bild(u, v, visad))})
    # Framifrån: förslaget ur skaftets vinkel mellan de markerade positionerna (M45), på de
    # påhittade svingarna och på ett skaft som inte når vågrätt (inget förslag).
    skaft = []
    for namn_ in ("fo", "fo_vanster"):
        marks, sv = fixtur_markeringar(namn_)
        for p in SKAFTETS:
            skaft.append({"position": p, "x_tecken": sv.x_tecken, "markeringar": _som_lista(marks),
                          "tid": forslag_tid_skaft(p, marks, sv.x_tecken)})
    kort = [{"position": "P1", "t": -1.2, "grepp": (500.0, 1300.0), "hosel": (480.0, 1585.0)},
            {"position": "P3", "t": -0.5, "grepp": (380.0, 1100.0), "hosel": (210.0, 1240.0)}]
    skaft.append({"position": "P2", "x_tecken": 1.0, "markeringar": _som_lista(kort),
                  "tid": forslag_tid_skaft("P2", kort, 1.0)})
    return {"fall": fall, "fil": fil, "yta": yta, "forslag_skaft": skaft,
            "forslag": [{"position": p, "positioner": pos, "tid": forslag_tid(p, pos)}
                        for p, pos in (
                            ("P2", {"P1": -1.4, "P3": -0.5, "P4": -0.3}),
                            ("P2", {"P1": -1.4, "P3": None, "P4": -0.3}),
                            ("P6", {"P4": -0.3, "P5": -0.12, "P7": 0.0}),
                            ("P6", {"P4": -0.3, "P5": None, "P7": 0.0}),
                            ("P8", {"P7": 0.0, "P9": 0.2, "P10": 1.1}),
                            ("P8", {"P7": 0.0, "P9": None, "P10": 1.1}),
                            ("P4", {"P4": -0.3}))]}


def swift_kalla() -> str:
    data = json.dumps(fixturer(), ensure_ascii=False, indent=1, sort_keys=True)
    return "\n".join([
        "// GENERERAD av tools/pc/klubba.py --swift. Ändra inte för hand: kör skriptet igen.",
        "//",
        "// PÅHITTADE markeringar (CLAUDE.md, Dataregeln) på Fixturer.swifts påhittade svingar,",
        "// och Pythons klubbmått för dem (METOD M45–M49, BESLUT B12).",
        "",
        "enum KlubbFixturer {",
        "    static let json = #\"\"\"",
        data,
        "\"\"\"#",
        "}",
        "",
    ])


def swift_yta() -> str:
    data = json.dumps(fixturer()["yta"], ensure_ascii=False, indent=1, sort_keys=True)
    return "\n".join([
        "// GENERERAD av tools/pc/klubba.py --swift. Ändra inte för hand: kör skriptet igen.",
        "//",
        "// Tryck på telefonens yta och pixeln PC:n räknar ur `visad` (METOD M45, BESLUT B12).",
        "",
        "enum KlubbYtaFixturer {",
        "    static let json = #\"\"\"",
        data,
        "\"\"\"#",
        "}",
        "",
    ])


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Klubbmåtten och Swift-fixturerna (METOD M45–M49).")
    ap.add_argument("--swift", action="store_true", help=f"skriv {FIXTURFIL.name}")
    a = ap.parse_args(argv)
    if not a.swift:
        ap.error("ange --swift")
    FIXTURFIL.write_text(swift_kalla(), encoding="utf-8")
    YTAFIL.write_text(swift_yta(), encoding="utf-8")
    print(f"Skrev {FIXTURFIL} och {YTAFIL}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
