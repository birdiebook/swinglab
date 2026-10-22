"""Katalogen över fel (`katalog.json` i repots rot, BESLUT B6) och bedömningen
av ett pass mot den. METOD M27

Ett fel med gräns bedöms grönt, gult eller rött mot gränsen. Ett fel utan gräns
(gront = null) bedöms mot den egna baslinjen: medianen och spridningen ur
tidigare pass. En gräns som inte är kontrollerad i original (BESLUT B10) bär
`kontrollerad: false` och används ändå, märkt.
"""
from __future__ import annotations

import json
from pathlib import Path

from . import session as S
from .matt import MATT
from .positioner import POSITIONER

KATALOG = Path(__file__).resolve().parents[2] / "katalog.json"
VYER = ("dtl", "fo", "bada")
STATUS = ("tillverkare", "forskning", "tranare", "antagande")
SAMRE = ("+", "-", None)
FALT = ("id", "namn", "vy", "matt", "fas", "gront", "gult", "kalla", "status", "kontrollerad",
        "aktiv", "samre", "ovning_id", "ovning", "tanke", "positioner")
MATT_FALT = ("matt", "vy", "positioner")       # och valfritt fel: felet vars accent måttet följer (B31)
POSITIONER_FEL = "positioner ska vara en lista av " + ", ".join(POSITIONER) + " i svingens ordning"
# Övningens id: stabilt när texten skrivs om, så att historiken känner igen den.
OVNING_ID = __import__("re").compile(r"^[a-z0-9_]+$")

MIN_BASLINJE = 8         # METOD M27: svingar i baslinjen (8 försök räcker, research 1 del 4)
GRON_Z = 1.0             # METOD M27: inom 1 robust sd från baslinjen = grönt
GUL_Z = 2.0              # METOD M27: inom 2 = gult, längre bort åt det sämre hållet = rött


class KatalogFel(ValueError):
    pass


def positionerna_ok(p, tom: bool) -> bool:
    """En lista av positionerna (BESLUT B32), utan dubbletter och i svingens
    ordning. Ett fel får ha en tom lista (tempot: hela svingen), ett mått inte."""
    if not isinstance(p, list) or not all(isinstance(x, str) and x in POSITIONER for x in p):
        return False
    i = [POSITIONER.index(x) for x in p]
    return (tom or len(p) > 0) and i == sorted(set(i))


def kontrollera(k: dict) -> list[str]:
    """Katalogens form. Felen nämner felets id (eller måttet) och fältet."""
    fel = []
    if k.get("version") != 1 or not isinstance(k.get("fel"), list):
        return ["katalogen: ska ha version 1 och listan fel"]
    if not isinstance(k.get("matt"), list):
        return ["katalogen: listan matt saknas"]
    sedda = set()
    visade = set()                                     # (vy, mått) som granskningen visar
    for i, e in enumerate(k["fel"]):
        namn = e.get("id", f"fel {i}")
        for f in FALT:
            if f not in e:
                fel.append(f"{namn}: {f} saknas")
        if namn in sedda:
            fel.append(f"{namn}: id finns två gånger")
        sedda.add(namn)
        if e.get("vy") not in VYER:
            fel.append(f"{namn}: vy ska vara dtl, fo eller bada")
        elif e.get("matt") not in (set(MATT["dtl"]) & set(MATT["fo"]) if e["vy"] == "bada" else MATT[e["vy"]]):
            fel.append(f"{namn}: måttet finns inte i vyn")
        if e.get("status") not in STATUS:
            fel.append(f"{namn}: status ska vara en av {', '.join(STATUS)}")
        if e.get("samre", None) not in SAMRE:
            fel.append(f"{namn}: samre ska vara \"+\", \"-\" eller null")
        for g in ("gront", "gult"):
            v = e.get(g)
            if v is not None and not (isinstance(v, list) and len(v) == 2
                                      and all(x is None or isinstance(x, (int, float)) for x in v)):
                fel.append(f"{namn}: {g} ska vara [min, max] eller null")
        if e.get("gront") is None and e.get("gult") is not None:
            fel.append(f"{namn}: gult utan gront")
        if "ovning_id" in e and not (isinstance(e["ovning_id"], str) and OVNING_ID.match(e["ovning_id"])):
            fel.append(f"{namn}: ovning_id ska vara a–z, 0–9 och _")
        if not isinstance(e.get("kontrollerad"), bool) or not isinstance(e.get("aktiv"), bool):
            fel.append(f"{namn}: kontrollerad och aktiv ska vara true/false")
        if "positioner" in e and not positionerna_ok(e["positioner"], tom=True):
            fel.append(f"{namn}: {POSITIONER_FEL}")
        for vy in (("dtl", "fo") if e.get("vy") == "bada" else (e.get("vy"),)):
            visade.add((vy, e.get("matt")))
    for i, e in enumerate(k["matt"]):
        namn = f"matt {e.get('matt', i) if isinstance(e, dict) else i}"
        if not isinstance(e, dict) or not set(MATT_FALT) <= set(e) <= set(MATT_FALT) | {"fel"}:
            fel.append(f"{namn}: ska ha matt, vy och positioner, och får ha fel")
            continue
        if "fel" in e and e["fel"] not in sedda:
            fel.append(f"{namn}: fel ska vara ett fel i katalogen")
        if e["vy"] not in ("dtl", "fo"):
            fel.append(f"{namn}: vy ska vara dtl eller fo")
        elif e["matt"] not in MATT[e["vy"]]:
            fel.append(f"{namn}: måttet finns inte i vyn")
        if (e["vy"], e["matt"]) in visade:
            fel.append(f"{namn}: står redan i katalogen")
        visade.add((e["vy"], e["matt"]))
        if not positionerna_ok(e["positioner"], tom=False):
            fel.append(f"{namn}: {POSITIONER_FEL}")
    return fel


def las(sokvag: Path = KATALOG) -> dict:
    k = json.loads(Path(sokvag).read_text(encoding="utf-8"))
    fel = kontrollera(k)
    if fel:
        raise KatalogFel("; ".join(fel))
    return k


def _inom(v: float, spann: list) -> bool:
    lo, hi = spann
    return (lo is None or v >= lo) and (hi is None or v <= hi)


def bedom_varde(fel: dict, varde: float | None, baslinje: list[float]) -> dict:
    """Ett fel bedömt för ett värde (passets median). Status: gron, gul, rod,
    okand (inget värde eller ingen baslinje) eller av (felet är avstängt)."""
    ut = {"id": fel["id"], "varde": varde, "status": "okand", "grund": None, "z": None}
    if not fel["aktiv"]:
        ut["status"] = "av"
        return ut
    if varde is None:
        return ut
    if fel["gront"] is not None:
        ut["grund"] = "grans"
        if _inom(varde, fel["gront"]):
            ut["status"] = "gron"
        elif fel["gult"] is not None:
            ut["status"] = "gul" if _inom(varde, fel["gult"]) else "rod"
        else:
            ut["status"] = "gul"
        return ut
    if len(baslinje) < MIN_BASLINJE:
        return ut
    s = sorted(baslinje)
    q1, med, q3 = S.percentil(s, 0.25), S.percentil(s, 0.5), S.percentil(s, 0.75)
    spr = (q3 - q1) / S.IQR_SKALA
    if not spr > 0:
        return ut
    z = (varde - med) / spr
    samre = z if fel["samre"] == "+" else -z if fel["samre"] == "-" else abs(z)
    ut.update(grund="baslinje", z=z,
              status="gron" if samre <= GRON_Z else "gul" if samre <= GUL_Z else "rod")
    return ut


def _grupp(vy: str) -> str:
    return "alla" if vy == "bada" else vy


def bedom(katalog: dict, nu: list[dict], tidigare: list[dict]) -> list[dict]:
    """Passet `nu` (resultaten ur matt.mat) bedömt mot katalogen. Baslinjen är
    måttets värden i `tidigare` pass (alla svingar ur dem, i samma vy)."""
    sammanf = S.sammanfatta_session(nu)
    ut = []
    for fel in katalog["fel"]:
        g = sammanf[_grupp(fel["vy"])].get(fel["matt"])
        bas = [s["matt"][fel["matt"]] for s in tidigare
               if (fel["vy"] == "bada" or s["vy"] == fel["vy"]) and fel["matt"] in s["matt"]]
        ut.append(bedom_varde(fel, g["median"] if g else None, bas))
    return ut
