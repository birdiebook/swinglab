"""Katalogen över fel (`katalog.json` i repots rot, BESLUT B6) och bedömningen
av ett pass mot den. METOD M27

Listan `spridning` är passets spridning mellan slagen för ett mått, ett tal per pass
(METOD M44, BESLUT B46).

Ett fel med gräns bedöms grönt, gult eller rött mot gränsen. Ett fel utan gräns
(gront = null) bedöms mot den egna baslinjen: medianen och spridningen ur
tidigare pass. En gräns som inte är kontrollerad i original (BESLUT B10) bär
`kontrollerad: false` och används ändå, märkt.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

from . import klubba as KL
from . import session as S
from .matt import MATT

# Katalogens positioner: alla tio, P2, P6 och P8 för klubbans mått (S7a, METOD M45).
POSITIONER = KL.POSITIONER

KATALOG = Path(__file__).resolve().parents[2] / "katalog.json"
# Måtten ur två kameror (S6a): en egen fil som bara PC:n läser. BESLUT B37
KATALOG_3D = Path(__file__).resolve().parents[2] / "katalog_3d.json"
FALT_3D = ("matt", "namn", "enhet", "fas", "lage", "min_slag", "spann", "kalla", "status", "kontrollerad",
           "notering")
LAGEN_3D = ("utan_markorer", "med_markorer")      # BESLUT B14
VYER = ("dtl", "fo", "bada")
STATUS = ("tillverkare", "forskning", "tranare", "antagande")
SAMRE = ("+", "-", None)
FALT = ("id", "namn", "vy", "matt", "fas", "gront", "gult", "kalla", "status", "kontrollerad",
        "aktiv", "samre", "ovning_id", "ovning", "tanke", "positioner", "vad", "varfor", "tecken")
# Infobladet (BESLUT B41): vad som mäts, varför det spelar roll och tecknet, på engelska.
INFO = ("vad", "varfor", "tecken")
MATT_FALT = ("matt", "vy", "positioner") + INFO   # och valfritt fel: felet vars accent måttet följer (B31)
MATT_VALFRIA = ("fel", "status")               # status: "oprovad" = oprövat på telefonen (METOD M35–M37)
MATT_STATUS = ("oprovad",)
SPRIDNING_FALT = ("matt", "vy") + INFO            # METOD M44
MIN_SPRIDNING = 8        # METOD M44: slag för passets spridning (8 räcker, Severin 2021, som M27)
POSITIONER_FEL = "positioner ska vara en lista av " + ", ".join(POSITIONER) + " i svingens ordning"
# Övningens id: stabilt när texten skrivs om, så att historiken känner igen den.
OVNING_ID = __import__("re").compile(r"^[a-z0-9_]+$")

MIN_BASLINJE = 8         # METOD M27: svingar i baslinjen (8 slag räcker, Severin 2021)
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


def _info(namn: str, e: dict) -> list[str]:
    """Infobladets tre fält: text, inte tom (BESLUT B41)."""
    return [f"{namn}: {f} ska vara en text" for f in INFO
            if f in e and not (isinstance(e[f], str) and e[f].strip())]


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
        # Valfritt: gränsen är ett antagande härlett ur källan (sway_topp, METOD M15). BESLUT B41
        if "grans_harledd" in e and not (isinstance(e["grans_harledd"], bool) and e.get("gront") is not None):
            fel.append(f"{namn}: grans_harledd ska vara true/false och kräver gront")
        if "positioner" in e and not positionerna_ok(e["positioner"], tom=True):
            fel.append(f"{namn}: {POSITIONER_FEL}")
        fel += _info(namn, e)
        for vy in (("dtl", "fo") if e.get("vy") == "bada" else (e.get("vy"),)):
            visade.add((vy, e.get("matt")))
    for i, e in enumerate(k["matt"]):
        namn = f"matt {e.get('matt', i) if isinstance(e, dict) else i}"
        if not isinstance(e, dict) or not set(MATT_FALT) <= set(e) <= set(MATT_FALT) | set(MATT_VALFRIA):
            fel.append(f"{namn}: ska ha matt, vy, positioner, vad, varfor och tecken, och får ha fel och status")
            continue
        fel += _info(namn, e)
        if "status" in e and e["status"] not in MATT_STATUS:
            fel.append(f"{namn}: status ska vara oprovad")
        if "fel" in e and e["fel"] not in sedda:
            fel.append(f"{namn}: fel ska vara ett fel i katalogen")
        if e["vy"] not in ("dtl", "fo"):
            fel.append(f"{namn}: vy ska vara dtl eller fo")
        elif e["matt"] not in MATT[e["vy"]] + KL.katalognamn(e["vy"]):     # klubbans mått: METOD M46–M49
            fel.append(f"{namn}: måttet finns inte i vyn")
        if (e["vy"], e["matt"]) in visade:
            fel.append(f"{namn}: står redan i katalogen")
        visade.add((e["vy"], e["matt"]))
        if not positionerna_ok(e["positioner"], tom=False):
            fel.append(f"{namn}: {POSITIONER_FEL}")
    if not isinstance(k.get("spridning"), list):
        return fel + ["katalogen: listan spridning saknas"]
    spridda = set()
    for i, e in enumerate(k["spridning"]):
        namn = f"spridning {e.get('matt', i) if isinstance(e, dict) else i}"
        if not isinstance(e, dict) or set(e) != set(SPRIDNING_FALT):
            fel.append(f"{namn}: ska ha matt, vy, vad, varfor och tecken")
            continue
        fel += _info(namn, e)
        if e["vy"] not in ("dtl", "fo"):
            fel.append(f"{namn}: vy ska vara dtl eller fo")
        elif e["matt"] not in MATT[e["vy"]]:
            fel.append(f"{namn}: måttet finns inte i vyn")
        if (e["vy"], e["matt"]) in spridda:
            fel.append(f"{namn}: står två gånger")
        spridda.add((e["vy"], e["matt"]))
    return fel


def las(sokvag: Path = KATALOG) -> dict:
    k = json.loads(Path(sokvag).read_text(encoding="utf-8"))
    fel = kontrollera(k)
    if fel:
        raise KatalogFel("; ".join(fel))
    return k


def kontrollera_3d(k: dict) -> list[str]:
    """katalog_3d.json: formen, och att varje mått är ett av 3D-måtten
    (tva_kameror.MATT) en gång. BESLUT B37"""
    from .tva_kameror import MATT as MATT_3D
    if not isinstance(k, dict) or k.get("version") != 1 or not isinstance(k.get("matt"), list):
        return ["katalog_3d: ska ha version 1 och listan matt"]
    fel, sedda = [], set()
    for i, e in enumerate(k["matt"]):
        namn = e.get("matt", f"matt {i}") if isinstance(e, dict) else f"matt {i}"
        if not isinstance(e, dict) or set(e) != set(FALT_3D):
            fel.append(f"{namn}: ska ha fälten {', '.join(FALT_3D)}")
            continue
        if e["matt"] not in MATT_3D:
            fel.append(f"{namn}: inget 3D-mått")
        if e["matt"] in sedda:
            fel.append(f"{namn}: står två gånger")
        sedda.add(e["matt"])
        if e["lage"] not in LAGEN_3D:
            fel.append(f"{namn}: lage ska vara {' eller '.join(LAGEN_3D)}")
        if isinstance(e["min_slag"], bool) or not isinstance(e["min_slag"], int) or e["min_slag"] < 1:
            fel.append(f"{namn}: min_slag ska vara ett positivt heltal")
        v = e["spann"]
        if v is not None and not (isinstance(v, list) and len(v) == 2
                                  and all(x is None or isinstance(x, (int, float)) for x in v)):
            fel.append(f"{namn}: spann ska vara [min, max] eller null")
        if e["status"] not in STATUS:
            fel.append(f"{namn}: status ska vara en av {', '.join(STATUS)}")
        if not isinstance(e["kontrollerad"], bool):
            fel.append(f"{namn}: kontrollerad ska vara true/false")
    saknas = set(MATT_3D) - sedda
    if saknas:
        fel.append("katalog_3d: saknar " + ", ".join(sorted(saknas)))
    return fel


def las_3d(sokvag: Path = KATALOG_3D) -> dict:
    k = json.loads(Path(sokvag).read_text(encoding="utf-8"))
    fel = kontrollera_3d(k)
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


def spridning(katalog: dict, svingar: list[dict]) -> list[dict]:
    """Passets spridning mellan slagen för måtten i katalogens `spridning`: den robusta
    sd:n (q3 − q1)/1,349 ur passets sammanfattning (METOD M25, M26), i katalogens ordning.
    `n` är slagen med måttet i vyn; `varde` är None under MIN_SPRIDNING slag, där IQR/1,349
    är skev (0,63σ vid tre slag). METOD M44"""
    sammanf = S.sammanfatta_session(svingar)
    ut = []
    for e in katalog["spridning"]:
        n = sum(1 for s in svingar if s["vy"] == e["vy"] and math.isfinite(s["matt"].get(e["matt"], math.nan)))
        s = sammanf[e["vy"]].get(e["matt"])
        ut.append({"matt": e["matt"], "vy": e["vy"], "n": n,
                   "varde": S.robust_sd(s) if s and n >= MIN_SPRIDNING else None})
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
