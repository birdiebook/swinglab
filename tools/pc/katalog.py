"""Katalogen över fel (`katalog.json` i repots rot, BESLUT B6) och bedömningen
av ett pass mot den. METOD M27

Listan `spridning` är passets spridning mellan slagen för ett mått, ett tal per pass
(METOD M44, BESLUT B46).

Ett fel med gräns bedöms grönt, gult eller rött mot gränsen: gult utanför bandet men inom
måttets brusgolv (`golv`) från gränsen, rött längre bort (METOD M62, BESLUT B87). Ett fel utan
gräns (gront = null) bedöms mot den egna baslinjen: medianen och spridningen ur tidigare pass.
En gräns som inte är kontrollerad i original (BESLUT B10) bär `kontrollerad: false` och används
ändå, märkt.

Läget som spelaren ser (METOD M62) räknas av `lage`, `lage_baslinje` och `lage_for`: grönt,
gult, rött med en pil åt det håll värdet ligger, eller inget. Ett band som klubban flyttar
(`klubbberoende`) visas bara på järnpass (`jarn`, `band`); `visas` säger vad sessionen visar (dom b,
BESLUT B86), och `kalla_for` byter felets källa till klubbans när klubban är markerad (over the top,
BESLUT B88). `i_passet` gör båda, och analysen till Claude använder den, så att appen och
underlaget bygger på samma källa och samma band. Swift räknar samma sak
(SwingLabKit `Bandlage`), prövat mot `tools/tests/fixturer/bandlage.json` (BESLUT B12).
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "pc"

from . import klubba as KL
from . import session as S
from .matt import MATT

from .positioner import POSITIONER

# Klubbans mått får också stå vid P2, P6 och P8, som skaftet definierar (S7a, METOD M45).
POSITIONER_KLUBBA = KL.POSITIONER

KATALOG = Path(__file__).resolve().parents[2] / "katalog.json"
# Måtten ur två kameror (S6a) står i katalogens lista tre_d sedan appen fick 3D (S6c-2; förut
# katalog_3d.json, som bara PC:n läste). BESLUT B37, B62
FALT_3D = ("matt", "namn", "enhet", "fas", "lage", "min_slag", "spann", "kalla", "status", "kontrollerad",
           "notering", "vad", "varfor", "tecken")
LAGEN_3D = ("utan_markorer", "med_markorer")      # BESLUT B14
VYER = ("dtl", "fo", "bada")
STATUS = ("tillverkare", "forskning", "tranare", "antagande")
SAMRE = ("+", "-", None)
FALT = ("id", "namn", "vy", "matt", "fas", "gront", "golv", "kalla", "status", "kontrollerad",
        "aktiv", "samre", "ovning_id", "ovning", "tanke", "positioner", "vad", "varfor", "tecken")
# Valfria fält i ett fel: driverns band (används inte än), klubbberoende (bandet bara på järnpass),
# visas (dom b) och klubbans källa (B88).
FEL_VALFRIA = ("notering", "grans_harledd", "gront_driver", "klubbberoende", "visas", "klubba")
KLUBBA_FALT = ("matt", "positioner", "gront", "golv", "kalla", "status", "kontrollerad", "grans_harledd",
               "vad", "varfor", "tecken")
# Infobladet (BESLUT B41): vad som mäts, varför det spelar roll och tecknet, på engelska.
INFO = ("vad", "varfor", "tecken")
MATT_FALT = ("matt", "vy", "positioner") + INFO   # och valfritt fel: felet vars accent måttet följer (B31)
# status: "oprovad" = oprövat på telefonen (METOD M35–M37). Bandet (BESLUT B86, METOD M62): gront med
# golv, kalla, kalla_status och kontrollerad, valfritt grans_harledd och gront_driver; samre med golv för
# den egna baslinjen; klubbberoende: true = klubban flyttar bandet (bara på järnpass); visas: false = dom (b).
MATT_VALFRIA = ("fel", "status", "gront", "gront_driver", "golv", "samre", "kalla", "kalla_status", "kontrollerad",
                "grans_harledd", "klubbberoende", "visas")
MATT_BAND = ("golv", "kalla", "kalla_status", "kontrollerad")
MATT_STATUS = ("oprovad",)
SPRIDNING_FALT = ("matt", "vy") + INFO            # METOD M44
SPRIDNING_VALFRIA = ("samre", "golv")              # METOD M62: rött åt det sämre hållet
MIN_SPRIDNING = 8        # METOD M44: slag för passets spridning (8 räcker, Severin 2021, som M27)
POSITIONER_FEL = "positioner ska vara en lista av " + ", ".join(POSITIONER) + " i svingens ordning"
# Övningens id: stabilt när texten skrivs om, så att historiken känner igen den.
OVNING_ID = __import__("re").compile(r"^[a-z0-9_]+$")

MIN_BASLINJE = 8         # METOD M27: svingar i baslinjen (8 slag räcker, Severin 2021)
GRON_Z = 1.0             # METOD M27: inom 1 robust sd från baslinjen = grönt
GUL_Z = 2.0              # METOD M27: inom 2 = gult, längre bort åt det sämre hållet = rött

LAGEN = ("gron", "gul", "rod", "ingen")    # METOD M62
PILAR = ("over", "under")                  # METOD M62: värdet över eller under bandet
EPS = 1e-9                                 # METOD M62: gränserna är slutna, flyttalens fel räknas inte
# Järnets band gäller på järnpass (BESLUT B86): järnen 4–9 och PW, som id ("j7", "pw") eller
# etikett ("7i", "PW"). Okänd klubba = järn, standarden.
JARN = {f"j{i}" for i in range(4, 10)} | {f"{i}i" for i in range(4, 10)} | {"pw"}


class KatalogFel(ValueError):
    pass


def positionerna_ok(p, tom: bool, klubba: bool = False) -> bool:
    """En lista av positionerna (BESLUT B32), utan dubbletter och i svingens
    ordning. Ett fel får ha en tom lista (tempot: hela svingen), ett mått inte. Klubbans
    mått får alla tio (P2, P6 och P8 kommer ur markeringen, METOD M45), kroppens inte."""
    alla = POSITIONER_KLUBBA if klubba else POSITIONER
    if not isinstance(p, list) or not all(isinstance(x, str) and x in alla for x in p):
        return False
    i = [alla.index(x) for x in p]
    return (tom or len(p) > 0) and i == sorted(set(i))


def _info(namn: str, e: dict) -> list[str]:
    """Infobladets tre fält: text, inte tom (BESLUT B41)."""
    return [f"{namn}: {f} ska vara en text" for f in INFO
            if f in e and not (isinstance(e[f], str) and e[f].strip())]


def _spann_ok(v) -> bool:
    return v is None or (isinstance(v, list) and len(v) == 2
                         and all(x is None or (isinstance(x, (int, float)) and not isinstance(x, bool)) for x in v))


def _golv_ok(v) -> bool:
    return isinstance(v, (int, float)) and not isinstance(v, bool) and v > 0


def _band_fel(namn: str, e: dict) -> list[str]:
    """Ett mått i `matt` eller `spridning` med band eller riktning (BESLUT B86, METOD M62): gront kräver
    golv och källan, samre kräver golv, grans_harledd och gront_driver kräver gront."""
    fel = []
    for g in ("gront", "gront_driver"):
        if g in e and not (e[g] is not None and _spann_ok(e[g])):
            fel.append(f"{namn}: {g} ska vara [min, max]")
    if "gront" in e:
        for f in MATT_BAND:
            if f not in e:
                fel.append(f"{namn}: gront kräver {', '.join(MATT_BAND)}")
                break
    if "samre" in e and e["samre"] not in ("+", "-"):
        fel.append(f"{namn}: samre ska vara \"+\" eller \"-\"")
    if ("gront" in e or "samre" in e) and "golv" not in e:
        fel.append(f"{namn}: gront och samre kräver golv")
    if "golv" in e and not _golv_ok(e["golv"]):
        fel.append(f"{namn}: golv ska vara ett positivt tal")
    if "golv" in e and "gront" not in e and "samre" not in e:
        fel.append(f"{namn}: golv kräver gront eller samre")
    if "kalla_status" in e and e["kalla_status"] not in STATUS:
        fel.append(f"{namn}: kalla_status ska vara en av {', '.join(STATUS)}")
    if "kontrollerad" in e and not isinstance(e["kontrollerad"], bool):
        fel.append(f"{namn}: kontrollerad ska vara true/false")
    if "grans_harledd" in e and not (e["grans_harledd"] is True and "gront" in e):
        fel.append(f"{namn}: grans_harledd ska vara true och kräver gront")
    if "gront_driver" in e and "gront" not in e:
        fel.append(f"{namn}: gront_driver kräver gront")
    fel += _klubbberoende_fel(namn, e)
    if "visas" in e and not isinstance(e["visas"], bool):
        fel.append(f"{namn}: visas ska vara true/false")
    return fel


def _klubbberoende_fel(namn: str, e: dict) -> list[str]:
    """`klubbberoende` (BESLUT B86): true, och bara på ett band med driverns band bredvid."""
    if "klubbberoende" in e and not (e["klubbberoende"] is True and e.get("gront") is not None
                                     and e.get("gront_driver") is not None):
        return [f"{namn}: klubbberoende ska vara true och kräver gront och gront_driver"]
    return []


def _klubba_fel(namn: str, e: dict) -> list[str]:
    """Felets källa när klubban är markerad (BESLUT B88): ett av klubbans mått i felets vy, med
    positioner, band, golv, källa och infoblad."""
    k = e["klubba"]
    if not isinstance(k, dict) or set(k) != set(KLUBBA_FALT):
        return [f"{namn}: klubba ska ha {', '.join(KLUBBA_FALT)}"]
    fel = []
    if e.get("vy") not in ("dtl", "fo") or k["matt"] not in KL.katalognamn(e["vy"]):
        fel.append(f"{namn}: klubbans mått finns inte i vyn")
    if not positionerna_ok(k["positioner"], tom=False, klubba=True):
        fel.append(f"{namn}: klubbans {POSITIONER_FEL}")
    if k["gront"] is None or not _spann_ok(k["gront"]):
        fel.append(f"{namn}: klubbans gront ska vara [min, max]")
    if not _golv_ok(k["golv"]):
        fel.append(f"{namn}: klubbans golv ska vara ett positivt tal")
    if k["status"] not in STATUS:
        fel.append(f"{namn}: klubbans status ska vara en av {', '.join(STATUS)}")
    if not isinstance(k["kontrollerad"], bool) or not isinstance(k["grans_harledd"], bool):
        fel.append(f"{namn}: klubbans kontrollerad och grans_harledd ska vara true/false")
    fel += _info(f"{namn} klubba", k)
    return fel


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
        for f in set(e) - set(FALT) - set(FEL_VALFRIA):
            fel.append(f"{namn}: okänt fält {f}")
        for g in ("gront", "gront_driver"):
            if not _spann_ok(e.get(g)):
                fel.append(f"{namn}: {g} ska vara [min, max] eller null")
        if "golv" in e and not _golv_ok(e["golv"]):
            fel.append(f"{namn}: golv ska vara ett positivt tal")
        if e.get("gront") is None and e.get("gront_driver") is not None:
            fel.append(f"{namn}: gront_driver utan gront")
        fel += _klubbberoende_fel(namn, e)
        if "visas" in e and not isinstance(e["visas"], bool):
            fel.append(f"{namn}: visas ska vara true/false")
        if "klubba" in e:
            fel += _klubba_fel(namn, e)
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
        fel += _band_fel(namn, e)
        if e["vy"] not in ("dtl", "fo"):
            fel.append(f"{namn}: vy ska vara dtl eller fo")
        elif e["matt"] not in MATT[e["vy"]] + KL.katalognamn(e["vy"]):     # klubbans mått: METOD M46–M49
            fel.append(f"{namn}: måttet finns inte i vyn")
        if (e["vy"], e["matt"]) in visade:
            fel.append(f"{namn}: står redan i katalogen")
        visade.add((e["vy"], e["matt"]))
        klubba = e["vy"] in ("dtl", "fo") and e["matt"] in KL.katalognamn(e["vy"])
        if not positionerna_ok(e["positioner"], tom=False, klubba=klubba):
            fel.append(f"{namn}: {POSITIONER_FEL}")
    if not isinstance(k.get("spridning"), list):
        return fel + ["katalogen: listan spridning saknas"]
    spridda = set()
    for i, e in enumerate(k["spridning"]):
        namn = f"spridning {e.get('matt', i) if isinstance(e, dict) else i}"
        if not isinstance(e, dict) or not set(SPRIDNING_FALT) <= set(e) <= set(SPRIDNING_FALT) | set(SPRIDNING_VALFRIA):
            fel.append(f"{namn}: ska ha matt, vy, vad, varfor och tecken, och får ha samre och golv")
            continue
        fel += _info(namn, e)
        fel += _band_fel(namn, e)
        if e["vy"] not in ("dtl", "fo"):
            fel.append(f"{namn}: vy ska vara dtl eller fo")
        elif e["matt"] not in MATT[e["vy"]]:
            fel.append(f"{namn}: måttet finns inte i vyn")
        if (e["vy"], e["matt"]) in spridda:
            fel.append(f"{namn}: står två gånger")
        spridda.add((e["vy"], e["matt"]))
    return fel + kontrollera_3d(k)


def las(sokvag: Path = KATALOG) -> dict:
    k = json.loads(Path(sokvag).read_text(encoding="utf-8"))
    fel = kontrollera(k)
    if fel:
        raise KatalogFel("; ".join(fel))
    return k


def kontrollera_3d(k: dict) -> list[str]:
    """Katalogens tre_d: formen, infobladet (BESLUT B41) och att varje mått är ett av
    3D-måtten (tva_kameror.MATT) en gång. Samma som Katalog.kontrolleraTreD i Swift. BESLUT B37, B62"""
    from .tva_kameror import MATT as MATT_3D
    if not isinstance(k, dict) or not isinstance(k.get("tre_d"), list):
        return ["katalogen: listan tre_d saknas"]
    fel, sedda = [], set()
    for i, e in enumerate(k["tre_d"]):
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
        fel += _info(namn, e)
    saknas = set(MATT_3D) - sedda
    if saknas:
        fel.append("tre_d: saknar " + ", ".join(sorted(saknas)))
    return fel


def las_3d(sokvag: Path = KATALOG) -> dict:
    """3D-måtten ur katalogen, som {"matt": [...]} (formen som analysen läser)."""
    k = json.loads(Path(sokvag).read_text(encoding="utf-8"))
    fel = kontrollera_3d(k)
    if fel:
        raise KatalogFel("; ".join(fel))
    return {"version": 1, "matt": k["tre_d"]}


def _inom(v: float, spann: list) -> bool:
    lo, hi = spann
    return (lo is None or v >= lo - EPS) and (hi is None or v <= hi + EPS)


# --- läget mot bandet (METOD M62, BESLUT B87) ---------------------------------------------

def gult(e: dict) -> list | None:
    """Det gula spannet: bandet vidgat med golvet åt båda hållen (öppna ändar förblir öppna),
    None utan band. Analysen och underlaget till Claude bär det som `gult`. METOD M62"""
    g = e.get("gront")
    if g is None:
        return None
    lo, hi = g
    return [None if lo is None else lo - e["golv"], None if hi is None else hi + e["golv"]]


def jarn(klubba: str | None) -> bool:
    """Klubban är ett järn (4–9 eller PW), som id eller etikett; okänd klubba räknas som järn,
    standarden (BESLUT B86)."""
    return not klubba or klubba.lower() in JARN


def band(e: dict, klubba: str | None = None) -> list | None:
    """Bandet som visas för en post i ett pass med klubban `klubba`. Ett band som klubban flyttar
    (`klubbberoende`, research 6 §6) visas bara på järnpass, och på andra klubbor inget (driverns
    band används inte än); de andra banden gäller alla klubbor. BESLUT B86"""
    if e.get("klubbberoende") and not jarn(klubba):
        return None
    return e.get("gront")


def lage(varde: float, gront: list | None, golv: float) -> dict:
    """Ett värde mot bandet: grönt innanför, gult utanför men inom golvet från gränsen, rött
    längre bort med pilen åt det håll värdet ligger ("over" = större än bandet). Utan band:
    ingen, och ett tal som inte är ändligt har inget läge. Gränserna är slutna. METOD M62"""
    if gront is None or not math.isfinite(varde):
        return {"lage": "ingen", "pil": None}
    lo, hi = gront
    if _inom(varde, gront):
        return {"lage": "gron", "pil": None}
    if lo is not None and varde < lo:
        d, pil = lo - varde, "under"
    else:
        d, pil = varde - hi, "over"
    if d <= golv + EPS:
        return {"lage": "gul", "pil": None}
    return {"lage": "rod", "pil": pil}


def lage_baslinje(varde: float, baslinje: tuple | None, samre: str | None, golv: float | None) -> dict:
    """Ett värde mot den egna baslinjen (medianen ± en robust sd, M27), som inte får grönt eller
    gult (Johannes 2026-10-25): rött med pil bara när måttets sämre håll är känt och värdet ligger
    mer än golvet utanför baslinjens ände åt det hållet. METOD M62"""
    if baslinje is None or samre is None or golv is None or not math.isfinite(varde):
        return {"lage": "ingen", "pil": None}
    lo, hi = baslinje
    if samre == "+" and varde > hi + golv + EPS:
        return {"lage": "rod", "pil": "over"}
    if samre == "-" and varde < lo - golv - EPS:
        return {"lage": "rod", "pil": "under"}
    return {"lage": "ingen", "pil": None}


def baslinje_spann(varden: list[float]) -> tuple | None:
    """Den egna baslinjen som spann: medianen ± en robust sd, None under MIN_BASLINJE värden
    eller utan spridning (som `Baslinje.spann` i Swift). METOD M27"""
    if len(varden) < MIN_BASLINJE:
        return None
    s = sorted(varden)
    med = S.percentil(s, 0.5)
    spr = (S.percentil(s, 0.75) - S.percentil(s, 0.25)) / S.IQR_SKALA
    if not spr > 0:
        return None
    return (med - GRON_Z * spr, med + GRON_Z * spr)


def lage_for(e: dict, varde: float, baslinje: list[float] = (), klubba: str | None = None) -> dict:
    """Läget för en post (fel, mått eller spridning) i ett pass med klubban `klubba`: mot bandet
    när det visas, annars mot den egna baslinjen. Ett avstängt fel har inget läge. METOD M62"""
    if not e.get("aktiv", True):
        return {"lage": "ingen", "pil": None}
    g = band(e, klubba)
    if g is not None:
        return lage(varde, g, e["golv"])
    return lage_baslinje(varde, baslinje_spann(list(baslinje)), e.get("samre"), e.get("golv"))


def visas(e: dict) -> bool:
    """Posten visas för spelaren i sessionen (dom b: `visas: false`, BESLUT B86). Den finns ändå
    kvar i exporten, paketet och underlaget till Claude."""
    return e.get("visas", True)


def kalla_for(fel: dict, klubba_markerad: bool) -> dict:
    """Felet med klubbans källa när klubban är markerad i passet (BESLUT B88): måttet,
    positionerna, bandet, golvet, källan och infobladet ur `klubba`. Annars felet som det står.
    S7 byter bara vad som räknas som markerat, inte detta."""
    k = fel.get("klubba")
    if not klubba_markerad or k is None:
        return fel
    ut = {x: v for x, v in fel.items() if x not in ("klubba", "gront_driver", "grans_harledd", "klubbberoende")}
    ut.update(matt=k["matt"], positioner=k["positioner"], gront=k["gront"], golv=k["golv"], kalla=k["kalla"],
              status=k["status"], kontrollerad=k["kontrollerad"], vad=k["vad"], varfor=k["varfor"],
              tecken=k["tecken"])
    if k["grans_harledd"]:
        ut["grans_harledd"] = True
    return ut


def markerad(fel: dict, slag: list[dict]) -> bool:
    """Klubban är markerad för felets källa (BESLUT B88): något slag i felets vy har klubbmåttet.
    `slag` = rader med `vy` och `matt` (som analysens). Som `Mattkort.visat` i Swift."""
    k = fel.get("klubba")
    return k is not None and any(r.get("vy") == fel["vy"] and k["matt"] in (r.get("matt") or {}) for r in slag)


def i_passet(fel: dict, klubba: str | None, klubba_markerad: bool) -> dict:
    """Felet som det gäller i ett pass med klubban `klubba`: klubbans källa när den är markerad
    (`kalla_for`, BESLUT B88) och sedan bandet efter klubban (`band`, BESLUT B86). Appen
    (`Mattkort.visat`, `Positionsmatt`) och analysen till Claude (`analys._del`, `Passanalys`)
    bygger på samma, så att de aldrig säger olika saker."""
    f = kalla_for(fel, klubba_markerad)
    if f.get("gront") is not None and band(f, klubba) is None:
        f = {x: v for x, v in f.items() if x not in ("gront_driver", "grans_harledd")}
        f["gront"] = None
    return f


def visade(katalog: dict, vy: str) -> list[str]:
    """Det sessionen i vyn `vy` visar för spelaren (BESLUT B64, B86): felens id och måttens namn,
    i katalogens ordning, utan `visas: false`. Klubbans mått visas bara på markerade slag, men står
    med här. Swift: `Katalog.visade(i:)`."""
    ut = [f["id"] for f in katalog["fel"] if visas(f) and f["vy"] in (vy, "bada")]
    ut += [m["matt"] for m in katalog["matt"] if visas(m) and m["vy"] == vy]
    ut += [f"{s['matt']}_spridning" for s in katalog["spridning"] if visas(s) and s["vy"] == vy]
    return ut


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
        ut["status"] = lage(varde, fel["gront"], fel["golv"])["lage"]       # METOD M62
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


# --- facit för Swift (BESLUT B12, METOD M62) ------------------------------------------------

FACIT_BANDLAGE = Path(__file__).resolve().parents[1] / "tests" / "fixturer" / "bandlage.json"
# En påhittad baslinje (median 4, q1 2, q3 6 → spannet 4 ± 2,965), som test_katalog.Baslinjen.
FACIT_BASLINJE = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
FACIT_KLUBBOR = ["j7", "7i", "j4", "9i", "pw", "PW", "dr", "Dr", "t3", "3W", "h4", "4H", "gw", "SW", "", None]


def _prov(gront: list | None, golv: float) -> list[float]:
    """Värden runt bandet: ändarna, innanför, inom golvet och längre bort åt båda håll."""
    ut = []
    lo, hi = gront if gront is not None else (None, None)
    for g, s in ((lo, -1), (hi, 1)):
        if g is not None:
            ut += [g, g + s * golv * 0.5, g + s * golv, g + s * golv * 1.5]
    if lo is not None and hi is not None:
        ut.append((lo + hi) / 2)
    elif lo is not None:
        ut.append(lo + 3 * golv)
    elif hi is not None:
        ut.append(hi - 3 * golv)
    return ut


def facit_bandlage(katalog: dict | None = None) -> dict:
    """Pythons läge för påhittade värden och för varje post i katalogen (METOD M62), vad sessionen
    visar per vy och felens källa med och utan klubban (BESLUT B86–B88). Swift läser filen i
    `BandlageTests` och ska ge samma svar."""
    katalog = katalog or las()
    lagen = []
    for gront, golv in (([-2.5, None], 2), ([None, 4.3], 2), ([-2.3, 4.3], 2), ([2.5, 3.1], 0.2), ([0.23, 0.32], 0.02),
                        ([0, 0], 5)):
        for v in _prov(gront, golv) + [-100.0, 100.0]:
            lagen.append({"varde": v, "gront": gront, "golv": golv, "ut": lage(v, gront, golv)})
    bas = []
    spann = baslinje_spann(FACIT_BASLINJE)
    for samre in ("+", "-", None):
        for v in (spann[0] - 6, spann[0] - 5, spann[0] - 4.9, 4.0, spann[1] + 4.9, spann[1] + 5, spann[1] + 6):
            bas.append({"varde": v, "baslinje": FACIT_BASLINJE, "samre": samre, "golv": 5,
                        "ut": lage_baslinje(v, spann, samre, 5)})
    poster = []
    listor = [("fel", f, f["id"]) for f in katalog["fel"]] + [("matt", m, m["matt"]) for m in katalog["matt"]] + \
             [("spridning", s, s["matt"]) for s in katalog["spridning"]]
    for lista, e, namn in listor:
        if "golv" not in e:
            continue
        for kl in ("j7", "dr"):
            for v in _prov(e.get("gront"), e["golv"]) + [-50.0, 4.0, 50.0]:
                poster.append({"lista": lista, "vy": e["vy"], "namn": namn, "klubba": kl, "varde": v,
                               "baslinje": FACIT_BASLINJE, "ut": lage_for(e, v, FACIT_BASLINJE, kl)})
    kallor = {}
    for f in katalog["fel"]:
        if "klubba" in f:
            for markerad in (False, True):
                k = kalla_for(f, markerad)
                kallor[f"{f['id']}/{'klubba' if markerad else 'utan'}"] = {
                    x: k.get(x) for x in ("matt", "positioner", "gront", "golv", "kalla", "status", "kontrollerad",
                                          "vad", "varfor", "tecken")} | {"grans_harledd": k.get("grans_harledd", False)}
    i_pass = []
    for f in katalog["fel"]:
        for kl in ("j7", "dr", None):
            for m in ((False, True) if "klubba" in f else (False,)):
                g = i_passet(f, kl, m)
                i_pass.append({"fel": f["id"], "klubba": kl, "markerad": m, "matt": g["matt"], "gront": g["gront"],
                               "golv": g["golv"], "grans_harledd": g.get("grans_harledd", False)})
    return {"om": "Pythons läge mot bandet (METOD M62, BESLUT B86–B88), facit för SwingLabKit BandlageTests. "
                  "Skrivs av python3 tools/pc/katalog.py --swift.",
            "lage": lagen, "baslinje": bas, "poster": poster, "i_passet": i_pass,
            "jarn": [{"klubba": kl, "jarn": jarn(kl)} for kl in FACIT_KLUBBOR],
            "visade": {vy: visade(katalog, vy) for vy in ("dtl", "fo")},
            "kallor": kallor}


def facit_json() -> str:
    return json.dumps(facit_bandlage(), ensure_ascii=False, separators=(",", ":")) + "\n"


def main(argv=None) -> int:
    import argparse
    ap = argparse.ArgumentParser(description="Katalogen: kontrollen och facit för Swift (METOD M62).")
    ap.add_argument("--swift", action="store_true", help="skriv tools/tests/fixturer/bandlage.json")
    a = ap.parse_args(argv)
    fel = kontrollera(json.loads(KATALOG.read_text(encoding="utf-8")))
    if fel:
        print("\n".join(fel))
        return 1
    if a.swift:
        FACIT_BANDLAGE.write_text(facit_json(), encoding="utf-8")
        print(f"skrev {FACIT_BANDLAGE}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
