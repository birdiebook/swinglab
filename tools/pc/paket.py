"""Sessionspaketet från telefonen (S2_SPEC §8.3, docs/FORMAT.md "Paketet").

En zip per telefon och pass: `manifest.json`, ett JSON per slag med lederna
(`slag/s01.json`, SwingLabKits `JointSeries`) och klippen (valbart). Läsaren
kontrollerar formen och gör om varje slag till en sving i filformatet
(format.py), så att S1:s mått körs oförändrade. METOD MT1

Felen nämner filen och fältet, aldrig värdet (CLAUDE.md, Dataregeln).
"""
from __future__ import annotations

import json
import math
import re
import zipfile
from dataclasses import dataclass, field
from pathlib import Path

from .format import ANTAL_LEDER, LANGD_M, LEDER_FIL

FORMAT = "swinglab-paket/1"
LJUDETS_FART = 343.0                       # METOD MS6: m/s vid cirka 20 °C
DOMAR = ("sving", "inte_sving", "osaker")
MATS = ("sving", "osaker")                 # METOD MT1: domarna som mäts; inte_sving utelämnas
PASS_ID = re.compile(r"^\d{8}-\d{6}$")
SLAG_ID = re.compile(r"^s\d{2,4}$")
AVSTAND_M = (0.5, 20.0)                    # METOD MT1: rimligt avstånd telefon–boll
KANT = 1e-6                                # METOD MS13: tolerans för utsnittets kant och fönstrets gränser


class PaketFel(ValueError):
    """Ett eller flera formfel. Varje rad nämner fil och fält, aldrig värdet."""

    def __init__(self, fel: list[str]):
        super().__init__("; ".join(fel))
        self.fel = fel


@dataclass
class Slag:
    id: str
    serie: int
    klubba: str | None
    dom: str
    klick_s: float
    traff_s: float | None
    leder: str                 # sökvägen i zippen
    klipp: str | None
    klick_i_klipp_s: float | None
    serie_ordning: int         # platsen i passet (0 först), efter serie och klick
    lederna: dict | None = None    # JointSeries, läst


@dataclass
class Serie:
    """En serie i manifestet. `fonster` (fran_s, till_s) och `utsnitt` (x, y, b, h,
    normaliserat i den upprätta bilden, origo uppe till vänster) kommer ur telefonens
    redigerare (S2i); None = hela filen och hela bilden. METOD MS13"""
    nr: int
    klubba: str | None
    fonster: tuple[float, float] | None = None
    utsnitt: tuple[float, float, float, float] | None = None


@dataclass
class Paket:
    fil: str                   # zippens namn, utan katalog
    manifest: dict
    pass_id: str
    vy: str
    spelhand: str
    avstand_m: float | None
    langd_m: float | None
    slag: list[Slag] = field(default_factory=list)
    serier: dict[int, Serie] = field(default_factory=dict)


def _tal(v) -> bool:
    return not isinstance(v, bool) and isinstance(v, (int, float)) and math.isfinite(v)


def _sakert_namn(namn) -> bool:
    return isinstance(namn, str) and namn and not namn.startswith("/") and ".." not in namn.split("/")


def _kontrollera_manifest(m, namn_i_zip: set[str]) -> list[str]:
    fel: list[str] = []
    F = "manifest.json"
    if not isinstance(m, dict):
        return [f"{F}: ska vara ett JSON-objekt"]
    if m.get("format") != FORMAT:
        fel.append(f"{F}: format ska vara {FORMAT}")
    if not isinstance(m.get("pass"), str) or not PASS_ID.match(m["pass"]):
        fel.append(f"{F}: pass ska vara yyyyMMdd-HHmmss")
    if m.get("vy") not in ("dtl", "fo"):
        fel.append(f"{F}: vy ska vara dtl eller fo")
    if m.get("spelhand") not in ("hoger", "vanster"):
        fel.append(f"{F}: spelhand ska vara hoger eller vanster")
    if m.get("avstand_m") is not None and not (_tal(m["avstand_m"]) and AVSTAND_M[0] <= m["avstand_m"] <= AVSTAND_M[1]):
        fel.append(f"{F}: avstand_m ska vara ett tal mellan {AVSTAND_M[0]} och {AVSTAND_M[1]}")
    if m.get("spelarens_langd_m") is not None and not (
            _tal(m["spelarens_langd_m"]) and LANGD_M[0] <= m["spelarens_langd_m"] <= LANGD_M[1]):
        fel.append(f"{F}: spelarens_langd_m ska vara ett tal mellan {LANGD_M[0]} och {LANGD_M[1]}")
    serier = m.get("serier")
    nr = set()
    fonster: dict[int, tuple[float, float]] = {}
    if not isinstance(serier, list):
        fel.append(f"{F}: serier ska vara en lista")
    else:
        for i, s in enumerate(serier):
            if not isinstance(s, dict) or isinstance(s.get("nr"), bool) or not isinstance(s.get("nr"), int):
                fel.append(f"{F}: serier[{i}].nr ska vara ett heltal")
                continue
            nr.add(s["nr"])
            if not _kontrollera_redigering(s, "") and isinstance(s.get("fonster"), dict):
                fonster[s["nr"]] = (s["fonster"]["fran_s"], s["fonster"]["till_s"])
            if s.get("klubba") is not None and not isinstance(s["klubba"], str):
                fel.append(f"{F}: serier[{i}].klubba ska vara text")
            fel += _kontrollera_redigering(s, f"{F}: serier[{i}]")
    slag = m.get("slag")
    if not isinstance(slag, list) or not slag:
        fel.append(f"{F}: slag saknas eller är tom")
        return fel
    sedda = set()
    for i, s in enumerate(slag):
        p = f"{F}: slag[{i}]"
        if not isinstance(s, dict):
            fel.append(f"{p}: ska vara ett objekt")
            continue
        sid = s.get("id")
        if not isinstance(sid, str) or not SLAG_ID.match(sid):
            fel.append(f"{p}.id ska vara s och siffror")
        elif sid in sedda:
            fel.append(f"{p}.id finns två gånger")
        sedda.add(sid)
        if isinstance(s.get("serie"), bool) or not isinstance(s.get("serie"), int) or s["serie"] not in nr:
            fel.append(f"{p}.serie ska vara ett nr i serier")
        if not _tal(s.get("klick_s")):
            fel.append(f"{p}.klick_s ska vara ett tal")
        elif s.get("serie") in fonster and not (
                fonster[s["serie"]][0] - KANT <= s["klick_s"] <= fonster[s["serie"]][1] + KANT):
            # Telefonen räknar bara klicken inom fönstret som slag (METOD MS13).
            fel.append(f"{p}.klick_s ligger utanför seriens fonster")
        if s.get("traff_s") is not None and not _tal(s["traff_s"]):
            fel.append(f"{p}.traff_s ska vara ett tal")
        if s.get("dom") not in DOMAR:
            fel.append(f"{p}.dom ska vara en av {', '.join(DOMAR)}")
        if not _sakert_namn(s.get("leder")):
            fel.append(f"{p}.leder ska vara en sökväg i paketet")
        elif s["leder"] not in namn_i_zip:
            fel.append(f"{p}.leder: filen saknas i paketet")
        if s.get("klipp") is not None:
            if not _sakert_namn(s["klipp"]):
                fel.append(f"{p}.klipp ska vara en sökväg i paketet")
            elif s["klipp"] not in namn_i_zip:
                fel.append(f"{p}.klipp: filen saknas i paketet")
            if not _tal(s.get("klick_i_klipp_s")):
                fel.append(f"{p}.klick_i_klipp_s ska vara ett tal när klipp finns")
    return fel


def _kontrollera_redigering(s: dict, p: str) -> list[str]:
    """Seriens `fonster` och `utsnitt` (valfria, S2i): fönstret i filen med
    0 ≤ fran_s < till_s, och utsnittet inom bilden med positiv bredd och höjd. METOD MS13"""
    fel = []
    f = s.get("fonster")
    if f is not None:
        if not isinstance(f, dict) or not all(_tal(f.get(k)) for k in ("fran_s", "till_s")):
            fel.append(f"{p}.fonster ska ha talen fran_s och till_s")
        elif not 0 <= f["fran_s"] < f["till_s"]:
            fel.append(f"{p}.fonster ska ha 0 <= fran_s < till_s")
    u = s.get("utsnitt")
    if u is not None:
        if not isinstance(u, dict) or not all(_tal(u.get(k)) for k in ("x", "y", "b", "h")):
            fel.append(f"{p}.utsnitt ska ha talen x, y, b och h")
        elif not (u["x"] >= -KANT and u["y"] >= -KANT and u["b"] > 0 and u["h"] > 0
                  and u["x"] + u["b"] <= 1 + KANT and u["y"] + u["h"] <= 1 + KANT):
            fel.append(f"{p}.utsnitt ska ligga inom bilden (0–1) med positiv b och h")
    return fel


def utsnitt_px(utsnitt, bredd: int, hojd: int) -> tuple[int, int, int, int]:
    """Utsnittet i pixlar i den upprätta bilden bredd × hojd (x, y, b, h), avrundat
    utåt till hela pixlar och inom bilden, som SwingLabKits `CropRect.pixels`. Utan
    utsnitt hela bilden. METOD MS13"""
    if utsnitt is None:
        return 0, 0, bredd, hojd
    x, y, b, h = utsnitt
    e = KANT
    x0 = max(0, min(bredd, math.floor(x * bredd + e)))
    y0 = max(0, min(hojd, math.floor(y * hojd + e)))
    x1 = max(x0, min(bredd, math.ceil((x + b) * bredd - e)))
    y1 = max(y0, min(hojd, math.ceil((y + h) * hojd - e)))
    return x0, y0, x1 - x0, y1 - y0


def fran_utsnittet(u: float, v: float, utsnitt, bredd: int, hojd: int) -> tuple[float, float]:
    """En punkt normaliserad i utsnittet (origo uppe till vänster, som MediaPipe på en
    utskuren bild) → pixlar i hela den upprätta bilden, så att cm per px och måtten
    är desamma som utan utsnitt (telefonen gör samma med Visions punkter). METOD MS13"""
    if utsnitt is None:
        return u * bredd, v * hojd
    x, y, b, h = utsnitt
    return (x + u * b) * bredd, (y + v * h) * hojd


def _led(j, plats: str) -> tuple[list[float] | None, str | None]:
    """En led som [x, y, c] eller None. Både {"x","y","c"} (Swifts Codable) och
    [x, y, c] läses; null är en saknad led."""
    if j is None:
        return None, None
    if isinstance(j, dict):
        v = [j.get("x"), j.get("y"), j.get("c")]
    elif isinstance(j, list) and len(j) == 3:
        v = j
    else:
        return None, f"{plats}: ska vara null, {{x, y, c}} eller [x, y, c]"
    if not all(_tal(x) for x in v):
        return None, f"{plats}: x, y och c ska vara tal"
    return [float(x) for x in v], None


def kontrollera_leder(d, fil: str) -> list[str]:
    """Formen på ett slags JointSeries (S2_SPEC §6.3)."""
    if not isinstance(d, dict):
        return [f"{fil}: ska vara ett JSON-objekt"]
    fel = []
    for k in ("width", "height"):
        if isinstance(d.get(k), bool) or not isinstance(d.get(k), int) or d[k] <= 0:
            fel.append(f"{fil}: {k} ska vara ett positivt heltal")
    rutor = d.get("frames")
    if not isinstance(rutor, list) or not rutor:
        return fel + [f"{fil}: frames saknas eller är tom"]
    for i, r in enumerate(rutor):
        if not isinstance(r, dict):
            fel.append(f"{fil}: frames[{i}] ska vara ett objekt")
            continue
        if not _tal(r.get("t")):
            fel.append(f"{fil}: frames[{i}].t ska vara ett tal")
        leder = r.get("joints")
        if not isinstance(leder, list) or len(leder) != ANTAL_LEDER:
            fel.append(f"{fil}: frames[{i}].joints ska vara {ANTAL_LEDER} st")
            continue
        for j, led in enumerate(leder):
            _, f = _led(led, f"{fil}: frames[{i}], {LEDER_FIL[j]}")
            if f:
                fel.append(f)
        if len(fel) > 20:
            return fel + [f"{fil}: fler fel hoppas över"]
    return fel


def las_ur_zip(z: zipfile.ZipFile, paket: str, fil: str) -> bytes:
    """En fil ur zippen. En skadad fil (fel CRC, trasig post) blir ett PaketFel
    som nämner filen, aldrig innehållet."""
    try:
        return z.read(fil)
    except (zipfile.BadZipFile, EOFError, OSError, ValueError, NotImplementedError):
        raise PaketFel([f"{paket}: {fil} är skadad i zippen"]) from None


def las(sokvag, med_leder: bool = True) -> Paket:
    """Läser och kontrollerar ett paket. Kastar PaketFel med alla formfel."""
    sokvag = Path(sokvag)
    namn = sokvag.name
    try:
        z = zipfile.ZipFile(sokvag)
    except (zipfile.BadZipFile, OSError):
        raise PaketFel([f"{namn}: inte en zip som går att läsa"]) from None
    with z:
        i_zip = set(z.namelist())
        if "manifest.json" not in i_zip:
            raise PaketFel([f"{namn}: manifest.json saknas"])
        try:
            m = json.loads(las_ur_zip(z, namn, "manifest.json").decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError) as e:
            rad = getattr(e, "lineno", None)
            raise PaketFel([f"{namn}: manifest.json är inte giltig JSON" + (f" (rad {rad})" if rad else "")]) from None
        fel = [f"{namn}: {f}" for f in _kontrollera_manifest(m, i_zip)]
        if fel:
            raise PaketFel(fel)
        klubba = {s["nr"]: s.get("klubba") for s in m["serier"]}
        serier = {}
        for s in m["serier"]:
            f, u = s.get("fonster"), s.get("utsnitt")
            serier[s["nr"]] = Serie(nr=s["nr"], klubba=s.get("klubba"),
                                    fonster=(float(f["fran_s"]), float(f["till_s"])) if f is not None else None,
                                    utsnitt=tuple(float(u[k]) for k in ("x", "y", "b", "h")) if u is not None else None)
        ordning = sorted(range(len(m["slag"])), key=lambda i: (m["slag"][i]["serie"], m["slag"][i]["klick_s"]))
        plats = {i: k for k, i in enumerate(ordning)}
        p = Paket(fil=namn, manifest=m, pass_id=m["pass"], vy=m["vy"], spelhand=m["spelhand"],
                  avstand_m=m.get("avstand_m"), langd_m=m.get("spelarens_langd_m"), serier=serier)
        for i in ordning:
            s = m["slag"][i]
            p.slag.append(Slag(id=s["id"], serie=s["serie"], klubba=klubba.get(s["serie"]), dom=s["dom"],
                               klick_s=float(s["klick_s"]),
                               traff_s=float(s["traff_s"]) if s.get("traff_s") is not None else None,
                               leder=s["leder"], klipp=s.get("klipp"),
                               klick_i_klipp_s=s.get("klick_i_klipp_s"), serie_ordning=plats[i]))
        if med_leder:
            for s in p.slag:
                try:
                    d = json.loads(las_ur_zip(z, namn, s.leder).decode("utf-8"))
                except PaketFel as e:
                    fel += e.fel
                    continue
                except (json.JSONDecodeError, UnicodeDecodeError) as e:
                    rad = getattr(e, "lineno", None)
                    fel.append(f"{namn}: {s.leder} är inte giltig JSON" + (f" (rad {rad})" if rad else ""))
                    continue
                f = kontrollera_leder(d, s.leder)
                if f:
                    fel += [f"{namn}: {x}" for x in f]
                else:
                    s.lederna = d
        if fel:
            raise PaketFel(fel)
    return p


def traff_i_serien(p: Paket, s: Slag) -> float:
    """Träffen i lederna tidsskala (s relativt klicket): traff_s − klick_s ur
    manifestet, annars −avstånd/343 (MS6), annars klicket självt. METOD MT1"""
    if s.traff_s is not None:
        return s.traff_s - s.klick_s
    if p.avstand_m is not None:
        return -p.avstand_m / LJUDETS_FART
    return 0.0


def till_sving(p: Paket, s: Slag, langd_m: float) -> dict:
    """Slaget som en sving i filformatet (docs/FORMAT.md, format 1). En saknad
    led får konfidensen 0 och räknas då som saknad (METOD M1). Kamerans riktning
    är standarden för spelhanden (FORMAT.md). METOD MT1"""
    rutor = []
    for r in s.lederna["frames"]:
        leder = []
        for j in r["joints"]:
            v, _ = _led(j, "")
            leder.append(v if v is not None else [0.0, 0.0, 0.0])
        rutor.append({"t": float(r["t"]), "leder": leder})
    return {"format": 1, "vy": p.vy, "hand": p.spelhand, "spelarens_langd_m": langd_m,
            "t_klick": traff_i_serien(p, s), "rutor": rutor}
