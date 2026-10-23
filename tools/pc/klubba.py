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
KALLOR = ("klick",)                   # BESLUT B44: varje punkt är ett klick (ett tryck)
PASS_ID = re.compile(r"^\d{8}-\d{6}$")
FIL = "klubba.json"                   # filen i paketet (docs/FORMAT.md)

# --- måtten ----------------------------------------------------------------------------

TRYCK_PX = 3.0         # METOD M46: antagen osäkerhet per tryck, px i hela bilden (1 sd)
MIN_SKAFT_PX = 60.0    # METOD M46: kortare skaft i bild ger inget mått (vinkeln ±4° med TRYCK_PX)
CENTRUM_MARGINAL = 0.05   # METOD M48: greppet ska stå så mycket av bildhöjden över bildens mitt vid toppen

PER_POSITION = ("skaft_vinkel",)      # METOD M46: ett mått per position, skaft_vinkel_p1 … _p10
MATT_DTL = ("skaftplan_p1", "skaft_mot_plan_p2", "skaft_riktning_topp", "skaft_plan_p6")
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
                        and q["kalla"] in KALLOR):
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

def forslag_tid(position: str, positioner: dict, start: float | None) -> float | None:
    """Rutan som föreslås för en position, s relativt klicket (METOD M45). Kroppens
    positioner (P1, P3, P4, P5, P7, P9, P10, METOD M28) föreslås där de är. P2, P6 och P8
    definieras av skaftet: mitt mellan baksvingens start (annars P1) och P3 (annars P4),
    mitt mellan P5 (annars P4) och P7, och mitt mellan P7 och P9 (annars P10). Johannes
    stegar därifrån tills skaftet ser parallellt med marken ut. None när en ände saknas."""
    p = positioner.get

    def mitt(a, b):
        return (a + b) / 2 if a is not None and b is not None else None

    if position == "P2":
        return mitt(start if start is not None else p("P1"), p("P3") if p("P3") is not None else p("P4"))
    if position == "P6":
        return mitt(p("P5") if p("P5") is not None else p("P4"), p("P7"))
    if position == "P8":
        return mitt(p("P7"), p("P9") if p("P9") is not None else p("P10"))
    return p(position)


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


def _wrap90(d: float) -> float:
    """En vinkel mellan två linjer (utan riktning) i (−90, 90]."""
    d = (d + 90.0) % 180.0 - 90.0
    return 90.0 if d == -90.0 else d


def osakerhet(langd_px: float, tryck_px: float = TRYCK_PX) -> float:
    """Vinkelns osäkerhet (1 sd, grader) för en linje mellan två tryck langd_px isär, med
    varje tryck osäkert tryck_px i varje led: √2·σ/L radianer. METOD M46"""
    return _g(math.sqrt(2.0) * tryck_px / langd_px) if langd_px > 0 else math.inf


def mat(marks: list[dict], vy: str, x_tecken: float, bredd: int, hojd: int, sving: Sving | None = None) -> dict:
    """Klubbmåtten för ett slag ur dess markeringar (METOD M46–M49). `marks` =
    [{"position", "t", "grepp", "hosel"}], punkterna i hela bildens pixlar eller None.
    `sving` = slagets sving (format.py) för armen i FO; utan den saknas skaft_arm_*. Ett
    mått saknas när en punkt saknas eller skaftet är kortare än MIN_SKAFT_PX i bild."""
    s = float(x_tecken)
    pos: dict[str, dict] = {}
    for m in marks:
        if m.get("grepp") is None or m.get("hosel") is None or m.get("position") not in POSITIONER:
            continue
        g = (s * m["grepp"][0], m["grepp"][1])
        h = (s * m["hosel"][0], m["hosel"][1])
        if math.hypot(h[0] - g[0], h[1] - g[1]) < MIN_SKAFT_PX:
            continue
        pos[m["position"]] = {"t": float(m["t"]), "g": g, "h": h}
    ut: dict[str, float] = {}
    for p, q in pos.items():                                              # METOD M46
        ut[nyckel("skaft_vinkel", p)] = riktning(q["g"], q["h"])
    if vy == "dtl":
        p1 = pos.get("P1")
        if p1:
            # Skaftplanet: linjen genom hoseln och greppet vid P1, vinkeln mot marken sedd
            # från bollens sida (hoseln åt +X). METOD M47
            g, h = p1["g"], p1["h"]
            plan = _g(math.atan2(-(g[1] - h[1]), h[0] - g[0]))
            ut["skaftplan_p1"] = plan
            p2 = pos.get("P2")
            if p2:
                lutning = _g(math.atan2(-(p2["g"][1] - p2["h"][1]), p2["h"][0] - p2["g"][0]))
                ut["skaft_mot_plan_p2"] = _wrap90(lutning - plan)
            p6 = pos.get("P6")
            if p6 and math.hypot(p6["h"][0] - h[0], p6["h"][1] - h[1]) >= MIN_SKAFT_PX:
                # Hoseln vid P6 sedd från hoseln vid P1: + över planet (utanför linjen).
                ut["skaft_plan_p6"] = -vinkel_mellan(_upp(h, g), _upp(h, p6["h"]))   # METOD M47
        p4 = pos.get("P4")
        if p4:
            # Mot riktningen som ett skaft parallellt med mållinjen tar i bild: mot bildens
            # mitt (kamerans axel längs mållinjen). Bara när greppet står över mitten. METOD M48
            c = (s * bredd / 2.0, hojd / 2.0)
            g = p4["g"]
            if c[1] - g[1] >= CENTRUM_MARGINAL * hojd:
                ut["skaft_riktning_topp"] = vinkel_mellan(_upp(g, c), _upp(g, p4["h"]))
    else:
        p4, p7 = pos.get("P4"), pos.get("P7")
        if p4:
            ut["skaft_topp"] = riktning(p4["g"], p4["h"])                  # METOD M49
        if p7:
            dx, dy = _upp(p7["h"], p7["g"])
            ut["skaft_lutning_traff"] = _g(math.atan2(dx, dy))              # METOD M49
        if sving is not None:
            axel = F.jamna(sving.t, sving.xy[:, AXEL_F])
            hand = F.jamna(sving.t, sving.xy[:, HANDLED_F])
            for p in ("P5", "P6"):
                q = pos.get(p)
                if not q:
                    continue
                a, w = F.vid(sving.t, axel, q["t"]), F.vid(sving.t, hand, q["t"])
                arm = (a[0] - w[0], -(a[1] - w[1]))
                skaft = _upp(q["g"], q["h"])
                la, ls = math.hypot(*arm), math.hypot(*skaft)
                if not (np.isfinite(a).all() and np.isfinite(w).all() and la > 0):
                    continue
                cos = (arm[0] * skaft[0] + arm[1] * skaft[1]) / (la * ls)
                ut[f"skaft_arm_{p.lower()}"] = _g(math.acos(max(-1.0, min(1.0, cos))))   # METOD M49
    return ut


# --- fixturerna för Swift (BESLUT B12) -------------------------------------------------

FIXTURFIL = Path(__file__).resolve().parents[2] / "SwingLabKit" / "Tests" / "SwingTests" / "KlubbFixturer.swift"
FIXTUR_BREDD, FIXTUR_HOJD = 1080, 2880   # högre bild: greppet vid toppen står över mitten (M48)
# Påhittade skaft per position: vinkeln grepp → hosel i den speglade bilden (y uppåt) och
# längden i px. Valda så att varje mått räknas och P7 i DTL är kort (spärren).
SATTA = {
    "dtl": {"P1": (-60.0, 420.0), "P2": (-35.0, 300.0), "P3": (100.0, 220.0), "P4": (-75.0, 180.0),
            "P5": (95.0, 200.0), "P6": (-40.0, 260.0), "P7": (-58.0, 40.0), "P8": (150.0, 240.0),
            "P9": (110.0, 200.0), "P10": (170.0, 150.0)},
    "fo": {"P1": (-95.0, 430.0), "P2": (175.0, 320.0), "P3": (130.0, 250.0), "P4": (10.0, 260.0),
           "P5": (100.0, 280.0), "P6": (175.0, 300.0), "P7": (-104.0, 430.0), "P8": (5.0, 310.0),
           "P9": (80.0, 240.0), "P10": (-20.0, 200.0)},
}


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
        tf = forslag_tid(p, r["positioner"], r["faser"]["start"])
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


FIXTURFALL = (("dtl", ()), ("dtl_vanster", ()), ("fo", ()), ("fo_vanster", ("P8",)))


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
            "punkter": {"grepp": {"x": m["grepp"][0], "y": m["grepp"][1], "kalla": "klick"} if satt else None,
                        "skaft_mitt": None,
                        "klubbhuvud": {"x": m["hosel"][0], "y": m["hosel"][1], "kalla": "klick"} if satt else None},
            "forslag": {}})
    return {"format": FORMAT, "pass": pass_id, "kalla": [fil], "punkter": list(PUNKTER),
            "andrad": "2026-10-23T12:00:00+02:00", "rutor": rutor}


def fixturer() -> dict:
    """Fallen för Swift: svingen (namnet i Fixturer.swift), markeringarna och Pythons mått;
    och en fil i version 2 som Swift ska läsa. BESLUT B12"""
    fall = []
    for namn_, hoppa in FIXTURFALL:
        marks, sv = fixtur_markeringar(namn_, hoppa)
        fall.append({"sving": namn_, "bredd": FIXTUR_BREDD, "hojd": FIXTUR_HOJD,
                     "markeringar": [{"position": m["position"], "t": m["t"],
                                      "grepp": list(m["grepp"]) if m["grepp"] else None,
                                      "hosel": list(m["hosel"]) if m["hosel"] else None} for m in marks],
                     "matt": mat(marks, sv.vy, sv.x_tecken, FIXTUR_BREDD, FIXTUR_HOJD, sv),
                     "osakerhet": {str(L): osakerhet(L) for L in (40.0, 60.0, 100.0, 300.0)}})
    marks, _ = fixtur_markeringar("dtl")
    fil = fil_ur(marks, "dtl", "20261103-180000", "swinglab-20261103-180000-dtl.zip", "s03")
    return {"fall": fall, "fil": fil,
            "forslag": [{"position": p, "positioner": pos, "start": st, "tid": forslag_tid(p, pos, st)}
                        for p, pos, st in (
                            ("P2", {"P1": -1.4, "P3": -0.5, "P4": -0.3}, -0.9),
                            ("P2", {"P1": -1.4, "P3": None, "P4": -0.3}, None),
                            ("P6", {"P4": -0.3, "P5": -0.12, "P7": 0.0}, None),
                            ("P6", {"P4": -0.3, "P5": None, "P7": 0.0}, None),
                            ("P8", {"P7": 0.0, "P9": 0.2, "P10": 1.1}, None),
                            ("P8", {"P7": 0.0, "P9": None, "P10": 1.1}, None),
                            ("P4", {"P4": -0.3}, None))]}


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


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Klubbmåtten och Swift-fixturerna (METOD M45–M49).")
    ap.add_argument("--swift", action="store_true", help=f"skriv {FIXTURFIL.name}")
    a = ap.parse_args(argv)
    if not a.swift:
        ap.error("ange --swift")
    FIXTURFIL.write_text(swift_kalla(), encoding="utf-8")
    print(f"Skrev {FIXTURFIL}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
