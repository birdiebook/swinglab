"""Passets analys: paketen → måtten per slag, sessionen, katalogens bedömning,
jämförelsen mot förra passet och kandidaterna till "Att jobba på".

Allt här är mekaniskt (BESLUT B2): samma paket ger samma analys. Claude läser
`analys.json` och väljer (skillen `svinganalys`), men räknar inget själv.
Formatet står i docs/FORMAT.md ("Analysen").
"""
from __future__ import annotations

import datetime as dt
import json
import math
from pathlib import Path

import numpy as np

from . import faser as F
from . import format as fm
from . import katalog as KAT
from . import matt as M
from . import session as S
from . import tva_kameror as TK
from .paket import MATS, Paket, till_sving

FORMAT = "swinglab-analys/1"
KEDJOR = Path(__file__).resolve().parent / "kedjor.json"
FORSTA_SERIEN_SLAG = 5     # METOD MT2: första serien = de fem första mätta slagen i serie 1
FLAGGAD = ("gul", "rod")


def las_kedjor(sokvag: Path = KEDJOR) -> dict:
    return json.loads(Path(sokvag).read_text(encoding="utf-8"))


def enhet(matt: str) -> str:
    """Måttets enhet, för visningen och "klart när"."""
    if matt in ("tempo", "stans_bredd"):
        return ""
    if matt.endswith("_ms"):
        return "ms"
    if matt.endswith("_s"):
        return "s"
    if "vinkelfart" in matt:
        return "°/s"
    if "fart" in matt:
        return "m/s"
    if "_sway" in matt:                 # knänas sway är cm, inte knäets böjning
        return "cm"
    if any(o in matt for o in ("bojning", "lutning", "kna", "armbage")):
        return "°"
    return "cm"


def decimaler(matt: str) -> int:
    """Två decimaler för kvoter och sekunder, inga för vinkelfarten och ms, annars en
    (handens fart i m/s). METOD MT3"""
    e = enhet(matt)
    return 2 if e in ("", "s") else 0 if e in ("ms", "°/s") else 1


def avrunda(matt: str, v: float | None) -> float | None:
    """Talet som visas och som "klart när" skrivs i. METOD MT3"""
    if v is None:
        return None
    return round(v, decimaler(matt))


# --- slagen ----------------------------------------------------------------------

def mat_paket(p: Paket, langd_m: float) -> list[dict]:
    """Varje slag i paketet: måtten (matt.mat) eller felet. Slag med domen
    inte_sving och slag som Johannes märkt "Detection wrong" mäts inte (METOD MT1),
    som på telefonen. Första serien märks (METOD MT2)."""
    serier = sorted({s.serie for s in p.slag})
    ut = []
    for s in p.slag:
        rad = {"id": s.id, "vy": p.vy, "serie": s.serie, "klubba": s.klubba, "dom": s.dom,
               "plats": s.serie_ordning, "paket": p.fil}
        if s.dom not in MATS:
            rad["utelamnat"] = "domen är inte_sving"
            ut.append(rad)
            continue
        if s.detection_wrong:
            rad["utelamnat"] = "lederna märkta fel (detection_wrong)"
            ut.append(rad)
            continue
        try:
            r = M.mat(fm.fran_dict(till_sving(p, s, langd_m)))
        except (fm.FormatFel, F.SvingFel) as e:
            rad["fel"] = f"{p.fil}: {s.leder}: {e}"
            ut.append(rad)
            continue
        rad.update(cm_per_px=r["cm_per_px"], faser=r["faser"], positioner=r["positioner"], matt=r["matt"])
        ut.append(rad)
    # Första serien: de fem första mätta slagen i den första serien. METOD MT2
    forsta = [r for r in ut if "matt" in r and r["serie"] == serier[0]][:FORSTA_SERIEN_SLAG]
    for r in ut:
        if "matt" in r:
            r["forsta_serien"] = any(r is f for f in forsta)
    return ut


def tempo_vy(rader: list[dict]) -> str:
    """Vyn som tempot (och varje fel med vy "bada") tas ur: den med flest mätta
    slag, FO vid lika. Vyerna läggs aldrig ihop, för då räknas samma sving två
    gånger när båda telefonerna filmar. METOD MT9"""
    n = {vy: sum(1 for r in rader if r["vy"] == vy and "matt" in r) for vy in ("dtl", "fo")}
    return "dtl" if n["dtl"] > n["fo"] else "fo"


def sammanfatta_pass(rader: list[dict], vy_alla: str) -> dict[str, dict]:
    """Som session.sammanfatta_session, men gruppen "alla" är bara `vy_alla`.
    METOD M25, METOD MT9"""
    def m(vy):
        return [r["matt"] for r in rader if r["vy"] == vy and "matt" in r]
    return {"dtl": S.sammanfatta(m("dtl")), "fo": S.sammanfatta(m("fo")), "alla": S.sammanfatta(m(vy_alla))}


def svingar(analys: dict) -> list[dict]:
    """De mätta slagen i passets ordning, i den form session.py och katalog.py läser."""
    return [{"vy": r["vy"], "matt": r["matt"]} for r in analys["slag"] if "matt" in r]


# --- "klart när" -----------------------------------------------------------------

def klart_nar(fel: dict, bed: dict, nu: dict | None, baslinje: list[float]) -> dict | None:
    """Förslaget till "klart när" för ett fel, ur katalogens gräns, den egna
    baslinjen eller passet självt. Claude skriver av det, hittar aldrig på ett
    eget (BESLUT B2). METOD MT3"""
    if not fel["aktiv"]:
        return None
    m = fel["matt"]
    if fel["gront"] is not None:
        lo, hi = fel["gront"]
        markning = None if fel["kontrollerad"] else "B10"
        if lo is None and hi is None:
            return None
        if lo is None:
            return {"villkor": "<=", "grans": hi, "grund": "grans", "markning": markning}
        if hi is None:
            return {"villkor": ">=", "grans": lo, "grund": "grans", "markning": markning}
        return {"villkor": "mellan", "grans": [lo, hi], "grund": "grans", "markning": markning}
    if bed["grund"] == "baslinje":
        s = sorted(baslinje)
        med = S.percentil(s, 0.5)
        spr = (S.percentil(s, 0.75) - S.percentil(s, 0.25)) / S.IQR_SKALA
        grund = "baslinje"
    elif nu is not None and fel["samre"] is not None:
        med, spr, grund = nu["median"], S.robust_sd(nu), "nu"
    else:
        return None
    if not spr > 0:
        return None
    if grund == "nu":
        # En spridning åt det bättre hållet från passets median.
        g = med - spr if fel["samre"] == "+" else med + spr
        return {"villkor": "<=" if fel["samre"] == "+" else ">=", "grans": avrunda(m, g),
                "grund": "nu", "markning": "egen"}
    z = KAT.GRON_Z * spr
    if fel["samre"] == "+":
        return {"villkor": "<=", "grans": avrunda(m, med + z), "grund": grund, "markning": "egen"}
    if fel["samre"] == "-":
        return {"villkor": ">=", "grans": avrunda(m, med - z), "grund": grund, "markning": "egen"}
    return {"villkor": "mellan", "grans": [avrunda(m, med - z), avrunda(m, med + z)], "grund": grund,
            "markning": "egen"}


def uppfyllt(villkor: str, grans, v: float) -> bool:
    """Om värdet uppfyller "klart när". Gränserna är slutna."""
    if villkor == ">=":
        return v >= grans
    if villkor == "<=":
        return v <= grans
    return grans[0] <= v <= grans[1]


# --- kedjorna och kandidaterna ---------------------------------------------------

def orsaker(kedjor: dict, fel_id: str) -> dict[str, list[str]]:
    """Alla fel som kan ligga före `fel_id` i en kedja, med vägen dit
    ({orsak: [orsak, …, fel_id]}). Kedjorna läses transitivt. METOD MT6"""
    fore: dict[str, list[str]] = {}
    for k in kedjor["kedjor"]:
        fore.setdefault(k["foljd"], []).append(k["orsak"])
    ut: dict[str, list[str]] = {}
    ko = [(o, [o, fel_id]) for o in fore.get(fel_id, [])]
    while ko:
        o, vag = ko.pop(0)
        if o in ut or o == fel_id:
            continue
        ut[o] = vag
        ko += [(o2, [o2] + vag) for o2 in fore.get(o, [])]
    return ut


def kandidater(bedomning: list[dict], kedjor: dict) -> list[dict]:
    """De flaggade felen (gult eller rött) i den ordning skillen börjar läsa
    dem: grundorsaker före följdfel, låg prioritet sist, tidigt i svingen före
    sent, rött före gult, sedan längst från grönt. METOD MT6"""
    flaggade = {b["id"]: b for b in bedomning if b["status"] in FLAGGAD}
    lag = {x["fel"] for x in kedjor.get("lag_prioritet", [])}
    fas = {f: i for i, f in enumerate(kedjor["faser"])}
    ut = []
    for fid, b in flaggade.items():
        o = {k: v for k, v in orsaker(kedjor, fid).items() if k in flaggade}
        ut.append({"fel": fid, "status": b["status"], "fas": b["fas"], "orsaker": o,
                   "foljdfel": False if not o else True,
                   "fysik": [x["test"] for x in kedjor["fysik"] if x["fel"] == fid]})
    ut.sort(key=lambda k: (k["foljdfel"], k["fel"] in lag, fas.get(k["fas"], len(fas)),
                           0 if k["status"] == "rod" else 1, -abs(flaggade[k["fel"]]["z"] or 0.0), k["fel"]))
    return ut


# --- två kameror (S6a) -------------------------------------------------------------

def tre_d(paket: list[Paket], slag: list[dict], forra: dict | None, katalog_3d: dict) -> dict:
    """3D ur passets två paket (METOD MK1–MK7), eller {"hoppat": skäl}. Ett fel i 3D
    stoppar aldrig 2D-analysen (BESLUT B37). `trend` är katalogens mått i dess
    ordning med passets median (bara över minst min_slag slag, BESLUT B14) och
    skillnaden mot förra passet."""
    vyer = {p.vy: p for p in paket}
    if set(vyer) != {"dtl", "fo"}:
        return {"hoppat": "3D kräver ett DTL- och ett FO-paket från samma pass"}
    try:
        t = TK.analysera(vyer["dtl"], vyer["fo"], slag)
    except TK.TreDFel as e:
        return {"hoppat": str(e)}
    except (ValueError, ArithmeticError, IndexError, KeyError, np.linalg.LinAlgError) as e:
        return {"hoppat": f"3D gick inte ({type(e).__name__})"}
    mot = TK.jamfor(t, forra.get("tre_d") if forra else None)
    t["mot_forra"] = None if mot is None else {"pass": forra["pass"], "jamforelse": mot}
    trend = []
    for e in katalog_3d["matt"]:
        m = e["matt"]
        sn = t["session"].get(m) if e["lage"] == t["lage"] and t["n"].get(m, 0) >= e["min_slag"] else None
        j = (mot or {}).get(m) if sn else None
        trend.append({"matt": m, "namn": e["namn"], "enhet": e["enhet"], "fas": e["fas"], "lage": t["lage"],
                      "n": t["n"].get(m, 0), "min_slag": e["min_slag"],
                      "median": round(sn["median"], 1) if sn else None,
                      "kvartiler": [round(sn["q1"], 1), round(sn["q3"], 1)] if sn else None,
                      "spann": e["spann"], "kalla_status": e["status"], "kontrollerad": e["kontrollerad"],
                      "mot_forra": None if j is None else {"skillnad": round(j["skillnad"], 1),
                                                           "tydlig": j["tydlig"]}})
    t["trend"] = trend
    return t


# --- hela analysen ---------------------------------------------------------------

def _grupp(vy: str) -> str:
    return "alla" if vy == "bada" else vy


def analysera(paket: list[Paket], langd_m: float, tidigare: list[dict], forra: dict | None = None,
              katalog: dict | None = None, kedjor: dict | None = None, baslinje_pass: list[str] = (),
              skapad: str | None = None, katalog_3d: dict | None = None) -> dict:
    """Passets analys. `tidigare` = svingarna ur tidigare pass (baslinjen, M27),
    `forra` = förra passets analys (eller None)."""
    katalog = katalog or KAT.las()
    katalog_3d = katalog_3d or KAT.las_3d()
    kedjor = kedjor or las_kedjor()
    pass_id = paket[0].pass_id
    if any(p.pass_id != pass_id for p in paket):
        raise ValueError("paketen är från olika pass")
    if len({p.vy for p in paket}) != len(paket):
        raise ValueError("två paket med samma vy")
    slag = [r for p in sorted(paket, key=lambda p: p.vy) for r in mat_paket(p, langd_m)]
    a = {"format": FORMAT, "pass": pass_id,
         "skapad": skapad or dt.datetime.now().astimezone().isoformat(timespec="seconds"),
         "paket": [{"fil": p.fil, "vy": p.vy, "slag": len(p.slag),
                    "klipp": sum(1 for s in p.slag if s.klipp)} for p in paket],
         "spelhand": paket[0].spelhand, "spelarens_langd_m": langd_m,
         "klubbor": sorted({r["klubba"] for r in slag if r.get("klubba")}),
         "slag": slag}
    vy_alla = tempo_vy(slag)
    sammanf = sammanfatta_pass(slag, vy_alla)
    forsta = sammanfatta_pass([r for r in slag if r.get("forsta_serien")], vy_alla)
    a["tempo_vy"] = vy_alla
    a["session"] = sammanf
    a["forsta_serien"] = forsta
    a["baslinje"] = {"pass": list(baslinje_pass),
                     "svingar": {vy: sum(1 for s in tidigare if s["vy"] == vy) for vy in ("dtl", "fo")}}
    if forra is not None:
        a["forra"] = {"pass": forra["pass"],
                      "jamforelse": {g: S.jamfor(sammanf[g], forra["session"][g]) for g in sammanf}}
    else:
        a["forra"] = None

    bed = []
    for fel in katalog["fel"]:
        g, m = _grupp(fel["vy"]), fel["matt"]
        vy = vy_alla if fel["vy"] == "bada" else fel["vy"]
        bas = [s["matt"][m] for s in tidigare if s["vy"] == vy and m in s["matt"]]
        sn = sammanf[g].get(m)
        fs = forsta[g].get(m)
        b = KAT.bedom_varde(fel, sn["median"] if sn else None, bas)
        rad = dict(b)
        rad.update(namn=fel["namn"], vy=fel["vy"], matt=m, fas=fel["fas"], enhet=enhet(m),
                   visat=avrunda(m, b["varde"]), n=sn["n"] if sn else 0,
                   spann=fel["gront"], gult=fel["gult"], kontrollerad=fel["kontrollerad"],
                   kalla_status=fel["status"], samre=fel["samre"],
                   forsta_serien=avrunda(m, fs["median"]) if fs else None,
                   klart_nar=klart_nar(fel, b, sn, bas))
        if a["forra"] is not None:
            j = a["forra"]["jamforelse"][g].get(m)
            rad["mot_forra"] = None if j is None else {"skillnad": avrunda(m, j["skillnad"]), "tydlig": j["tydlig"]}
        bed.append(rad)
    a["bedomning"] = bed
    a["kandidater"] = kandidater(bed, kedjor)
    a["tre_d"] = tre_d(paket, slag, forra, katalog_3d)
    a["kontaktark"] = {}
    return a


def skriv(analys: dict, sokvag: Path) -> None:
    sokvag.parent.mkdir(parents=True, exist_ok=True)
    sokvag.write_text(json.dumps(ren(analys), ensure_ascii=False, indent=1, allow_nan=False) + "\n", encoding="utf-8")


def ren(v):
    """NaN och oändligt blir null, så att analysen alltid är giltig JSON."""
    if isinstance(v, float) and not math.isfinite(v):
        return None
    if isinstance(v, dict):
        return {k: ren(x) for k, x in v.items()}
    if isinstance(v, list):
        return [ren(x) for x in v]
    return v
