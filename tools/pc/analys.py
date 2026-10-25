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

from . import faser as F
from . import format as fm
from . import katalog as KAT
from . import klubba as KL
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
    if matt.startswith("skaft"):         # klubbans mått ur markeringarna (METOD M46–M49)
        return "°"
    if "_vrid_" in matt or matt.startswith(("xfaktor", "hofter_oppna")):   # 3D (METOD MK6)
        return "°"
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
    if any(o in matt for o in ("bojning", "lutning", "kna", "armbage", "_plan")):     # _plan: METOD M39
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
            sv = fm.fran_dict(till_sving(p, s, langd_m))
            r = M.mat(sv)
        except (fm.FormatFel, F.SvingFel) as e:
            rad["fel"] = f"{p.fil}: {s.leder}: {e}"
            ut.append(rad)
            continue
        if s.klubba_markeringar:
            # Klubbans mått ur telefonens markeringar (S7a, METOD M46–M49) står bland slagets
            # mått, och rutan han valde för P2, P6 och P8 blir slagets position (M45).
            km = s.klubba_markeringar
            pinne = p.serier[s.serie].riktpinne if s.serie in p.serier else None
            r["matt"].update(KL.mat(km, p.vy, sv.x_tecken, km[0]["bredd"], km[0]["hojd"], sv, pinne=pinne))
            # Flyktpunkten bakifrån ur riktpinnen, eller antagen i bildens mitt (METOD M48);
            # framifrån finns ingen.
            if p.vy == "dtl":
                rad["klubba_flyktpunkt"] = "bildens_mitt" if KL.flyktpunkt(pinne, km[0]["bredd"], km[0]["hojd"])[1] \
                    else "riktpinne"
            for m in km:
                if m["position"] in KL.SKAFTETS and m["grepp"] is not None:
                    r["positioner"][m["position"]] = m["t"]
            rad["klubba_markerad"] = any(m["grepp"] is not None for m in km)
        rad.update(cm_per_px=r["cm_per_px"], faser=r["faser"], positioner=r["positioner"], matt=r["matt"])
        ut.append(rad)
    # Första serien: de fem första mätta slagen i den första serien. METOD MT2
    forsta = [r for r in ut if "matt" in r and r["serie"] == serier[0]][:FORSTA_SERIEN_SLAG]
    for r in ut:
        if "matt" in r:
            r["forsta_serien"] = any(r is f for f in forsta)
    return ut


def klubba(rader: list[dict], paket: list[Paket]) -> dict:
    """Klubbans mått i passet (S7a, METOD M46–M49): de markerade slagen per vy, och per mått
    medianen och n över de markerade svingarna, från ett slag (få svingar är en trend, inte
    ett fel att öva, BESLUT B47). `fel` = paketens klubba.json som inte gick att läsa."""
    markerade = {vy: sum(1 for r in rader if r["vy"] == vy and r.get("klubba_markerad")) for vy in ("dtl", "fo")}
    matt = []
    for vy in ("dtl", "fo"):
        for namn in KL.namn(vy):
            v = sorted(r["matt"][namn] for r in rader if r["vy"] == vy and namn in r.get("matt", {}))
            if v:
                med = S.percentil(v, 0.5)
                matt.append({"matt": namn, "vy": vy, "n": len(v), "median": med, "visat": avrunda(namn, med)})
    return {"markerade": markerade, "matt": matt,
            "fel": {p.vy: p.klubba_fel for p in paket if p.klubba_fel}}


def tempo_vy(rader: list[dict]) -> str:
    """Vyn som tempot (och varje fel med vy "bada") tas ur: den med flest slag med
    tempo, FO vid lika. Ett slag utan säker start bakifrån har inget tempo (METOD M40)
    och räknas inte. Vyerna läggs aldrig ihop, för då räknas samma sving två gånger när
    båda telefonerna filmar. METOD MT9"""
    n = {vy: sum(1 for r in rader if r["vy"] == vy and "tempo" in r.get("matt", {})) for vy in ("dtl", "fo")}
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

def tre_d(paket: list[Paket], slag: list[dict], forra: dict | None, katalog_3d: dict | None = None) -> dict:
    """3D ur passets två paket (METOD MK1–MK7), eller {"hoppat": skäl}. Ett fel i 3D,
    var det än uppstår (katalogen, kedjan, jämförelsen, trenden), stoppar aldrig
    2D-analysen (BESLUT B37): ett oväntat fel blir bara typens namn, aldrig ett värde.
    `trend` är katalogens mått i dess ordning med passets median (bara över minst
    min_slag slag, BESLUT B14) och skillnaden mot förra passet."""
    vyer = {p.vy: p for p in paket}
    if set(vyer) != {"dtl", "fo"}:
        return {"hoppat": "3D kräver ett DTL- och ett FO-paket från samma pass"}
    try:
        t = _tre_d(vyer["dtl"], vyer["fo"], slag, forra, katalog_3d or KAT.las_3d())
    except TK.TreDFel as e:
        t = {"hoppat": str(e), **e.delvis}
    except Exception as e:  # noqa: BLE001 — 3D får aldrig stoppa 2D (BESLUT B37)
        t = {"hoppat": f"3D gick inte ({type(e).__name__})"}
    # Telefonens 3D (S6c-2, BESLUT B61): jämförs med PC:ns, som är facit. Ett fel här stoppar
    # inget; skillnaden står i tre_d.telefon. METOD MS19
    # Den räknande telefonens paket först (raknad_av), annars i vyernas ordning.
    def _forst(p) -> tuple:
        return (not (p.tre_d is not None and p.tre_d.get("raknad_av") == p.vy), p.vy)
    for p in sorted(paket, key=_forst):
        if p.tre_d is not None or p.tre_d_fel is not None:
            try:
                t["telefon"] = dict(TK.jamfor_telefon(t, p.tre_d), paket=p.fil) if p.tre_d is not None \
                    else {"paket": p.fil, "fel": p.tre_d_fel}
            except Exception as e:  # noqa: BLE001
                t["telefon"] = {"paket": p.fil, "fel": f"jämförelsen gick inte ({type(e).__name__})"}
            break
    return t


def _tre_d(dtl: Paket, fo: Paket, slag: list[dict], forra: dict | None, katalog_3d: dict) -> dict:
    t = TK.analysera(dtl, fo, slag)
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


def analysera(paket: list[Paket], langd_m: float, tidigare: list[dict] = (), katalog: dict | None = None,
              kedjor: dict | None = None, skapad: str | None = None, katalog_3d: dict | None = None) -> dict:
    """Passets analys. `tidigare` = de tidigare passens enheter (`enheter`, ur historiken):
    varje klubba i passet bedöms mot de tidigare enheterna med samma klubba och längd
    (BESLUT B56, METOD M27)."""
    pass_id = paket[0].pass_id
    if any(p.pass_id != pass_id for p in paket):
        raise ValueError("paketen är från olika pass")
    if len({p.vy for p in paket}) != len(paket):
        raise ValueError("två paket med samma vy")
    slag = [r for p in sorted(paket, key=lambda p: p.vy) for r in mat_paket(p, langd_m)]
    a = analysera_rader(pass_id, slag, langd_m, tidigare, katalog=katalog, kedjor=kedjor, skapad=skapad,
                        spelhand=paket[0].spelhand,
                        paket=[{"fil": p.fil, "vy": p.vy, "slag": len(p.slag),
                                "klipp": sum(1 for s in p.slag if s.klipp)} for p in paket])
    forra = next((u for u in reversed(sorted(tidigare, key=_ordning)) if u["pass"] == (a["forra"] or {}).get("pass")
                  and u["klubba_id"] == a["huvudklubba"]), None)
    a["klubba"] = klubba(slag, paket)
    a["tre_d"] = tre_d(paket, slag, forra, katalog_3d)
    a["kontaktark"] = {}
    return a


def _ordning(u: dict):
    return (u["pass"], not u.get("huvud", True))


def huvudklubba(slag: list[dict]):
    """Klubban med flest mätta slag (vid lika den som sorterar först, utan klubba först): den
    som passets "Att jobba på" gäller (BESLUT B56)."""
    rader = [r for r in slag if "matt" in r] or slag
    if not rader:
        return None
    n: dict = {}
    for r in rader:
        n[r.get("klubba")] = n.get(r.get("klubba"), 0) + 1
    return sorted(n, key=lambda k: (-n[k], k or ""))[0]


def svingar_for(analys: dict, kl) -> list[dict]:
    """De mätta slagen med klubban; en analys från före B56 (utan `huvudklubba`) ger alla."""
    if "huvudklubba" not in analys:
        return svingar(analys)
    return [{"vy": r["vy"], "matt": r["matt"]} for r in analys["slag"] if "matt" in r and r.get("klubba") == kl]


def enheter(analys: dict) -> list[dict]:
    """Analysens enheter: passets huvudklubba (analysen själv) och varje annan klubba (`delar`),
    var och en med `pass`, `klubba_id`, `langd`, `vyer`, `huvud` och `svingar` (BESLUT B56). En
    analys från före B56 får klubban ur `klubbor` när den är en. (`klubba` i analysen är S7a:s
    klubbmått.)"""
    kl = analys.get("klubbor") or []
    k0 = analys["huvudklubba"] if "huvudklubba" in analys else (kl[0] if len(kl) == 1 else None)
    langd = analys.get("spelarens_langd_m")
    ut = []
    for d, k, huvud in [(analys, k0, True)] + [(x, x["klubba"], False) for x in analys.get("delar", [])]:
        sv = svingar_for(analys, k)
        u = dict(d)
        u.update({"pass": analys["pass"], "klubba_id": k, "langd": langd, "huvud": huvud,
                  "vyer": sorted({s["vy"] for s in sv}), "svingar": sv, "tempo_vy": d.get("tempo_vy", "fo")})
        ut.append(u)
    return ut


def samma(u: dict, kl, langd) -> bool:
    """Samma klubba och längd: enheten går att jämföra med (BESLUT B56, METOD MS14)."""
    return u["klubba_id"] == kl and u["langd"] == langd


def _del(pass_id: str, slag: list[dict], kl, langd_m, tidigare: list[dict], katalog: dict, kedjor: dict) -> dict:
    """En klubbas del av passet, bedömd mot de tidigare enheterna med samma klubba och längd:
    baslinjen ur alla dem, förra passet den senaste med en gemensam vy (BESLUT B56)."""
    jamf = sorted((u for u in tidigare if u["pass"] < pass_id and samma(u, kl, langd_m)), key=_ordning)
    bas = [s for u in jamf for s in u["svingar"]]
    vyer = {r["vy"] for r in slag if "matt" in r}
    forra = next((u for u in reversed(jamf) if vyer & set(u["vyer"])), None)
    a: dict = {}
    vy_alla = tempo_vy(slag)
    sammanf = sammanfatta_pass(slag, vy_alla)
    forsta = sammanfatta_pass([r for r in slag if r.get("forsta_serien")], vy_alla)
    a["tempo_vy"] = vy_alla
    a["session"] = sammanf
    a["forsta_serien"] = forsta
    # Spridningen mellan slagen, ett tal per pass och mått, för klubban (METOD M44, BESLUT B46).
    a["spridning"] = [dict(e, klubba=kl, visat=avrunda(e["matt"], e["varde"]))
                      for e in KAT.spridning(katalog, [{"vy": r["vy"], "matt": r["matt"]} for r in slag if "matt" in r])]
    # Skiftet (M42) saknas när bäckenet inte är tillbaka i adressläget vid träffen: antalet
    # sådana slag (censurerade), så att passets median inte tyst bara gäller de andra.
    a["skifte_ej_tillbaka"] = {"fo": sum(1 for r in slag if r["vy"] == "fo" and "matt" in r
                                         and "backen_skifte_ms" not in r["matt"]
                                         and r["matt"].get("backen_sway_traff", 0.0) < 0),
                               "fo_matta": sum(1 for r in slag if r["vy"] == "fo" and "matt" in r)}
    a["baslinje"] = {"pass": sorted({u["pass"] for u in jamf}),
                     "svingar": {vy: sum(1 for s in bas if s["vy"] == vy) for vy in ("dtl", "fo")}}
    if forra is not None:
        a["forra"] = {"pass": forra["pass"],
                      "jamforelse": {g: S.jamfor(sammanf[g], forra["session"][g]) for g in sammanf}}
    else:
        a["forra"] = None
    bed = []
    for fel0 in katalog["fel"]:
        # Samma källa och band som appen (BESLUT B86, B88): klubbans plan när klubban är markerad
        # i enhetens slag, och ett band som klubban flyttar bara på järn.
        fel = KAT.i_passet(fel0, kl, KAT.markerad(fel0, slag))
        g, m = _grupp(fel["vy"]), fel["matt"]
        vy = vy_alla if fel["vy"] == "bada" else fel["vy"]
        b_ = [s["matt"][m] for s in bas if s["vy"] == vy and m in s["matt"]]
        sn = sammanf[g].get(m)
        fs = forsta[g].get(m)
        b = KAT.bedom_varde(fel, sn["median"] if sn else None, b_)
        rad = dict(b)
        rad.update(namn=fel["namn"], vy=fel["vy"], matt=m, fas=fel["fas"], enhet=enhet(m),
                   visat=avrunda(m, b["varde"]), n=sn["n"] if sn else 0,
                   spann=fel["gront"], gult=KAT.gult(fel), kontrollerad=fel["kontrollerad"],
                   kalla_status=fel["status"], samre=fel["samre"],
                   forsta_serien=avrunda(m, fs["median"]) if fs else None,
                   klart_nar=klart_nar(fel, b, sn, b_), baslinje=baslinjen(fel, b_))
        if a["forra"] is not None:
            j = a["forra"]["jamforelse"][g].get(m)
            rad["mot_forra"] = None if j is None else {"skillnad": avrunda(m, j["skillnad"]), "tydlig": j["tydlig"]}
        bed.append(rad)
    a["bedomning"] = bed
    a["kandidater"] = kandidater(bed, kedjor)
    return a


def analysera_rader(pass_id: str, slag: list[dict], langd_m: float | None, tidigare: list[dict] = (),
                    katalog: dict | None = None, kedjor: dict | None = None, skapad: str | None = None,
                    spelhand: str | None = None, paket: list[dict] = ()) -> dict:
    """Analysen ur passets slag (rader som `mat_paket` ger: `vy`, `serie`, `klubba`, och `matt`
    med `forsta_serien` för de mätta), utan paketen och 3D. `tidigare` = de tidigare passens
    enheter (`enheter`). Varje klubba analyseras för sig (BESLUT B56): huvudklubban överst,
    de andra i `delar`. Telefonen räknar samma sak ur sina slag (SwingLabKit `Passanalys`,
    BESLUT B12, BESLUT B53), och underlaget till Claude-appen byggs ur den (`underlag.py`)."""
    katalog = katalog or KAT.las()
    kedjor = kedjor or las_kedjor()
    huvud = huvudklubba(slag)
    a = {"format": FORMAT, "pass": pass_id, "matversion": M.MATVERSION,
         "skapad": skapad or dt.datetime.now().astimezone().isoformat(timespec="seconds"),
         "paket": list(paket), "spelhand": spelhand, "spelarens_langd_m": langd_m,
         "klubbor": sorted({r["klubba"] for r in slag if r.get("klubba")}), "huvudklubba": huvud,
         "slag": slag}
    a.update(_del(pass_id, [r for r in slag if r.get("klubba") == huvud], huvud, langd_m, tidigare, katalog, kedjor))
    andra = sorted({r.get("klubba") for r in slag if "matt" in r and r.get("klubba") != huvud}, key=lambda k: k or "")
    a["delar"] = [dict(klubba=k, **_del(pass_id, [r for r in slag if r.get("klubba") == k], k, langd_m, tidigare,
                                       katalog, kedjor)) for k in andra]
    a["klubba"] = klubba(slag, [])
    return a


def baslinjen(fel: dict, bas: list[float]) -> dict | None:
    """Den egna baslinjen för ett fel utan gräns: medianen, den robusta sd:n och antalet
    svingar ur de tidigare passen, avrundade som måttet (METOD M27, MT3); None för ett fel
    med gräns, ett avstängt fel eller färre än 8 svingar."""
    if not fel["aktiv"] or fel["gront"] is not None or len(bas) < KAT.MIN_BASLINJE:
        return None
    s = sorted(bas)
    spr = (S.percentil(s, 0.75) - S.percentil(s, 0.25)) / S.IQR_SKALA
    return {"median": avrunda(fel["matt"], S.percentil(s, 0.5)), "sd": avrunda(fel["matt"], spr), "n": len(bas)}


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
