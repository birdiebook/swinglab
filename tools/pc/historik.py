"""Vinterns minne på PC:n: passens analyser och varje `att_jobba_pa.json`, så
att tolkningen vet vilka övningar som provats, när, och om måttet rörde sig.

    python3 tools/pc/historik.py lista
    python3 tools/pc/historik.py minne [--till <pass>]
    python3 tools/pc/historik.py spara-att-jobba-pa <fil>

Mappen är `data/historik/` (gitignorerad, CLAUDE.md Dataregeln):

    spelare.json                     längd och spelhand, sparade en gång
    pass/<pass>/analys.json          ur session.py
    pass/<pass>/kontaktark-<vy>.png
    att_jobba_pa/<pass>.json         det Claude valde efter passet

Retentionen mäts på första serien (METOD MT2), rörelsen mot passet då övningen
valdes (METOD MT4), och läget per övning följer METOD MT5.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "pc"

from . import analys as A  # noqa: E402
from . import att_jobba_pa as AJP  # noqa: E402
from . import matt as M  # noqa: E402
from . import session as S  # noqa: E402

ROT = Path(__file__).resolve().parents[2] / "data" / "historik"
MINNE = "swinglab-minne/1"
BYT_OVNING_PASS = 4        # METOD MT5: så många pass utan tydlig rörelse → byt övning
FYSIK_DAGAR = 42           # METOD MT5: sex veckor utan rörelse → fysiken (treregeln)


def _datum(pass_id: str) -> dt.date:
    return dt.date(int(pass_id[:4]), int(pass_id[4:6]), int(pass_id[6:8]))


def _las(p: Path):
    return json.loads(p.read_text(encoding="utf-8"))


def _skriv(p: Path, d) -> Path:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(d, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    return p


# --- passen ----------------------------------------------------------------------

def pass_mapp(rot: Path, pass_id: str) -> Path:
    return Path(rot) / "pass" / pass_id


def lista(rot: Path = ROT) -> list[str]:
    """Passen med analys, äldst först (pass-id sorterar som tiden)."""
    mapp = Path(rot) / "pass"
    return sorted(p.name for p in mapp.glob("*") if (p / "analys.json").is_file()) if mapp.is_dir() else []


def las_analys(rot: Path, pass_id: str) -> dict:
    return _las(pass_mapp(rot, pass_id) / "analys.json")


def spara_analys(rot: Path, analys: dict) -> Path:
    p = pass_mapp(rot, analys["pass"]) / "analys.json"
    A.skriv(analys, p)
    return p


def kor_om(rot: Path = ROT) -> list[str]:
    """Passen vars analys mättes med en äldre version av måtten (`matversion` saknas =
    1): kör session.py igen för dem, annars hoppar talen mellan passen (METOD M40)."""
    return [p for p in lista(rot) if las_analys(rot, p).get("matversion", 1) < M.MATVERSION]


def tidigare(rot: Path, pass_id: str) -> list[str]:
    return [p for p in lista(rot) if p < pass_id]


def enheter(rot: Path, fore: str | None = None, till: str | None = None) -> list[dict]:
    """Passens enheter (`analys.enheter`: huvudklubban och varje annan klubba), äldst först;
    `fore` tar bara pass före det passet, `till` till och med det. Analysen väljer själv de
    med samma klubba, vy och längd (BESLUT B56)."""
    return [u for p in lista(rot) if (fore is None or p < fore) and (till is None or p <= till)
            for u in A.enheter(las_analys(rot, p))]


def sammanhang(enh: list[dict], pass_id: str | None) -> list[dict]:
    """Enheterna som går att jämföra med passets huvudklubba: samma klubba och längd, till och
    med passet (BESLUT B56, som telefonens PassHistory.earlier). Utan pass: det senaste."""
    huvud = [u for u in enh if u["huvud"] and (pass_id is None or u["pass"] <= pass_id)]
    if not huvud:
        return []
    nu = huvud[-1] if pass_id is None else next((u for u in huvud if u["pass"] == pass_id), huvud[-1])
    return [u for u in enh if u["pass"] <= nu["pass"] and A.samma(u, nu["klubba_id"], nu["langd"])]


def spelare(rot: Path = ROT) -> dict:
    p = Path(rot) / "spelare.json"
    return _las(p) if p.is_file() else {}


def spara_spelare(rot: Path, langd_m: float) -> None:
    _skriv(Path(rot) / "spelare.json", dict(spelare(rot), spelarens_langd_m=langd_m))


# --- att jobba på ----------------------------------------------------------------

def kontrollera_att_jobba_pa(rot: Path, d: dict) -> list[str]:
    """Kontrollen mot passets analys och minnet före passet. Utan analys i
    historiken vägras filen: kontrollen hoppas aldrig över (BESLUT B2)."""
    pass_id = d.get("pass") if isinstance(d, dict) else None
    if not AJP.pass_form(pass_id):
        return ["pass: ska vara yyyyMMdd-HHmmss"]
    if not (pass_mapp(rot, pass_id) / "analys.json").is_file():
        return ["pass: analys.json saknas i historiken; kör session.py för passet först"]
    return AJP.kontrollera(d, las_analys(rot, pass_id), ovningar(rot, till=pass_id, fore=pass_id))


def spara_att_jobba_pa(rot: Path, d: dict) -> Path:
    """Kontrollerar filen mot passets analys och minnet, och sparar den."""
    fel = kontrollera_att_jobba_pa(rot, d)
    if fel:
        raise ValueError("; ".join(fel))
    return _skriv(Path(rot) / "att_jobba_pa" / f"{d['pass']}.json", d)


def att_jobba_pa(rot: Path = ROT) -> list[dict]:
    mapp = Path(rot) / "att_jobba_pa"
    return [_las(p) for p in sorted(mapp.glob("*.json"))] if mapp.is_dir() else []


# --- minnet ----------------------------------------------------------------------

def _varde(u: dict, vy: str, matt: str, forsta: bool) -> float | None:
    g = "alla" if vy == "bada" else vy
    s = (u["forsta_serien"] if forsta else u["session"])[g].get(matt)
    return s["median"] if s else None


def _rorelse(villkor: str, grans, start: float, nu: float) -> float:
    """Hur långt värdet rört sig åt rätt håll sedan starten. METOD MT4"""
    if villkor == ">=":
        return nu - start
    if villkor == "<=":
        return start - nu
    c = (grans[0] + grans[1]) / 2
    return abs(start - c) - abs(nu - c)


def _foljning(enh: list[dict], vy: str, matt: str, kn: dict, start: dict | None, start_pass: str):
    """Startvärdet (första serien i startenheten), dess spridning och en rad per senare enhet
    i spåret: första serien, om "klart när" hålls och rörelsen sedan starten. METOD MT4"""
    startv = spr = None
    if start:
        startv = _varde(start, vy, matt, True)
        if startv is None:
            startv = _varde(start, vy, matt, False)
        hela = start["session"]["alla" if vy == "bada" else vy].get(matt)
        spr = S.robust_sd(hela) if hela else None
    rader = []
    for u in enh:
        if u["pass"] <= start_pass:
            continue
        v = _varde(u, vy, matt, True)
        if v is None:
            rader.append({"pass": u["pass"], "forsta_serien": None})
            continue
        rad = {"pass": u["pass"], "forsta_serien": A.avrunda(matt, v),
               "uppfyllt": A.uppfyllt(kn["villkor"], kn["grans"], A.avrunda(matt, v))}
        if startv is not None and spr is not None:
            r = _rorelse(kn["villkor"], kn["grans"], startv, v)
            rad.update(rorelse=A.avrunda(matt, r), tydlig=bool(r > spr))
        rader.append(rad)
    return startv, spr, rader


def ovning_id(ov: dict) -> str:
    """Övningens stabila id. En fil från före id:t (S5) känns igen på texten."""
    return ov.get("id") or ov["text"]


def ovningar(rot: Path, till: str | None = None, fore: str | None = None) -> list[dict]:
    """Varje fel som fått en övning, för passets huvudklubba och längd (`till`, annars det
    senaste passet): den senaste övningen, sedan när, och hur första serien rört sig pass för
    pass. `fore` tar bara med valen före det passet (kontrollen av ett nytt val). METOD MT4,
    METOD MT5, BESLUT B56"""
    enh = sammanhang(enheter(rot, till=till), till)
    return ovningar_ur(enh, att_jobba_pa(rot), till, fore)


def _relevant(spar: dict, u: dict) -> bool:
    """Enheten följer upp spåret: samma klubba, längd och vy som när saken valdes (BESLUT B56).
    För tempot (vy bada) är vyn den som tempot togs ur (METOD MT9)."""
    if not A.samma(u, spar["klubba"], spar["langd"]):
        return False
    return u["tempo_vy"] == spar["spar_vy"] if spar["vy"] == "bada" else spar["vy"] in u["vyer"]


def ovningar_ur(enh: list[dict], alla_docs: list[dict], till: str | None = None, fore: str | None = None,
                kedjor: dict | None = None) -> list[dict]:
    """`ovningar` ur enheterna (`analys.enheter`) och valen (`att_jobba_pa.json`), utan disken:
    samma räkning som telefonen gör ur sina pass (SwingLabKit `Ovningslage`, BESLUT B53).
    Ett val gäller passets huvudklubba; en sak följs upp och avslutas bara av enheter och val
    med samma klubba, längd och vy som när den valdes (BESLUT B56). Ett val för ett pass utan
    enhet läses inte. METOD MT4, METOD MT5

    "Klart när" är det som skrevs när övningen valdes och flyttar sig inte så länge övningen
    fortsätter. Fysiken räknas från första gången felet valdes, över alla övningar för det, och
    bara för ett fel med ett test i kedjorna. Ett fel som inte står i det senaste valet i sitt
    spår är avslutat."""
    kedjor = kedjor or A.las_kedjor()
    med_test = {x["fel"] for x in kedjor["fysik"]}
    U = sorted((u for u in enh if till is None or u["pass"] <= till), key=A._ordning)
    huvud = {u["pass"]: u for u in U if u["huvud"]}
    docs = sorted((d for d in alla_docs if d["pass"] in huvud and (fore is None or d["pass"] < fore)),
                  key=lambda d: d["pass"])
    spar: dict[tuple, dict] = {}
    for d in docs:                                     # äldst först
        u = huvud[d["pass"]]
        aktiva = {k: g["_aktiv"] for k, g in spar.items()}
        for s in d["saker"]:
            # Övningen känns igen på sitt id (kedjor.json, katalogens ovning_id), inte på
            # texten: en omskriven formulering är samma övning och behåller steget.
            fid, text, ov_id = s["fel"], s["ovning"]["text"], ovning_id(s["ovning"])
            k = (fid, u["klubba_id"])
            g = spar.get(k)
            if g is None or not aktiva.get(k, False):  # felet väljs (på nytt): ett nytt block
                tidigare_ov = ([g["ovning_id"]] + g["forra_ovningar"]) if g else []
                g = spar[k] = {"fel": fid, "vy": s["vy"], "matt": s["matt"], "fel_start": d["pass"],
                               "valt_i_pass": d["pass"], "ovning_id": ov_id, "forra_ovningar": tidigare_ov,
                               "klart_nar": s["klart_nar"], "markning": s["markning"], "klubba": u["klubba_id"],
                               "langd": u["langd"], "spar_vy": u["tempo_vy"] if s["vy"] == "bada" else s["vy"]}
            elif g["ovning_id"] != ov_id:              # ny övning för samma fel: ny "klart när"
                g.update(valt_i_pass=d["pass"], ovning_id=ov_id,
                         forra_ovningar=[g["ovning_id"]] + g["forra_ovningar"],
                         klart_nar=s["klart_nar"], markning=s["markning"])
            g.update(ovning=text, tanke=s["ovning"]["tanke"], steg=s["ovning"]["steg"], typ=s["typ"],
                     fysik=s["fysik"], senast_i_pass=d["pass"], _aktiv=True)
        valda = {s["fel"] for s in d["saker"]}
        for k, g in spar.items():
            if _relevant(g, u):
                g["_aktiv"] = k[0] in valda
    ut = []
    for g in spar.values():
        o = {k: v for k, v in g.items() if k not in ("_aktiv", "langd", "spar_vy")}
        kn = o["klart_nar"]
        rel = [u for u in U if _relevant(g, u)]
        start = next((u for u in U if u["pass"] == o["valt_i_pass"] and u["klubba_id"] == o["klubba"]), None)
        fstart = next((u for u in U if u["pass"] == o["fel_start"] and u["klubba_id"] == o["klubba"]), None)
        startv, spr, upp = _foljning(rel, o["vy"], o["matt"], kn, start, o["valt_i_pass"])
        _, _, upp_fel = _foljning(rel, o["vy"], o["matt"], kn, fstart, o["fel_start"])
        uppfyllda = 0
        for x in reversed(upp):
            if not x.get("uppfyllt"):
                break
            uppfyllda += 1
        utan = 0
        for x in reversed(upp):
            if x.get("tydlig"):
                break
            utan += 1
        dagar = (_datum(rel[-1]["pass"]) - _datum(o["fel_start"])).days if rel else 0
        rorelse_i_blocket = any(x.get("tydlig") for x in upp_fel)
        # Ett fel som inte är flaggat i den senaste enheten efter valet är klart (BESLUT B45):
        # gränsen kan ha flyttats (sway_topp, early_extension) eller felet är borta. "Klart
        # när" och märkningen är låsta från valet, men ett grönt fel övas aldrig, så saken
        # lämnar listan och rapporteras som klar, inte tyst borttagen.
        sist = rel[-1] if rel and rel[-1]["pass"] > o["senast_i_pass"] else None
        ej_flaggat = sist is not None and any(b["id"] == o["fel"] and b["status"] == "gron"
                                              for b in sist.get("bedomning", []))
        skal = None
        if not g["_aktiv"]:
            lage = "avslutad"
        elif uppfyllda >= kn.get("pass_i_rad", 1):
            lage, skal = "klart", "klart_nar"
        elif ej_flaggat:
            lage, skal = "klart", "inte_flaggat"
        elif (upp_fel and not rorelse_i_blocket and dagar >= FYSIK_DAGAR and o["fysik"] is None
              and o["fel"] in med_test):
            lage = "fysik"
        elif not upp:
            lage = "ny"
        elif utan >= BYT_OVNING_PASS:
            lage = "byt_ovning"
        else:
            lage = "fortsatt"
        o.update(start_forsta_serien=A.avrunda(o["matt"], startv) if startv is not None else None,
                 spridning=A.avrunda(o["matt"], spr) if spr is not None else None,
                 uppfoljning=upp, pass_sedan=len(upp), dagar_sedan_felet_valdes=dagar,
                 rorelse_sedan_felet_valdes=rorelse_i_blocket, uppfyllt_i_rad=uppfyllda,
                 pass_utan_rorelse=utan, aktuell=g["_aktiv"], lage=lage, klart_skal=skal)
        ut.append(o)
    return ut


def minne(rot: Path = ROT, till: str | None = None) -> dict:
    """Det skillen läser före tolkningen, för det senaste passets huvudklubba och längd
    (BESLUT B56): passen, varje fels väg genom vintern och övningarnas läge."""
    enh = sammanhang(enheter(rot, till=till), till)
    pass_ids = sorted({u["pass"] for u in enh})
    passen, fel, tre_d, klubba = [], {}, {}, {}
    for u in sorted(enh, key=A._ordning):
        p = u["pass"]
        # Klubbans mått ur markerade svingar (S7a): median och n per pass, en trend. METOD M46
        for x in (u.get("klubba") or {}).get("matt", []) if u["huvud"] else []:
            klubba.setdefault(x["matt"], []).append({"pass": p, "vy": x["vy"], "median": x["visat"], "n": x["n"]})
        # 3D-måttens trend (S6a): bara pass med en median över minst min_slag slag. METOD MK7
        for x in (u.get("tre_d") or {}).get("trend", []) if u["huvud"] else []:
            if x["median"] is not None:
                tre_d.setdefault(x["matt"], []).append({"pass": p, "median": x["median"], "kvartiler": x["kvartiler"],
                                                        "n": x["n"], "lage": x["lage"]})
        passen.append({"pass": p, "datum": _datum(p).isoformat(), "klubba": u["klubba_id"],
                       "slag": {vy: sum(1 for s in u["svingar"] if s["vy"] == vy) for vy in ("dtl", "fo")}})
        for b in u["bedomning"]:
            fel.setdefault(b["id"], []).append({"pass": p, "varde": b["visat"], "forsta_serien": b["forsta_serien"],
                                                "status": b["status"]})
    return {"format": MINNE, "till": pass_ids[-1] if pass_ids else None, "pass": passen, "fel": fel,
            "tre_d": tre_d, "klubba": klubba, "ovningar": ovningar(rot, till),
            "kor_om": [p for p in kor_om(rot) if p in pass_ids]}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--rot", default=str(ROT), help="historikens mapp (standard data/historik)")
    sub = ap.add_subparsers(dest="kommando", required=True)
    sub.add_parser("lista")
    m = sub.add_parser("minne")
    m.add_argument("--till", help="minnet fram till och med detta pass")
    s = sub.add_parser("spara-att-jobba-pa")
    s.add_argument("fil")
    a = ap.parse_args(argv)
    rot = Path(a.rot)
    if a.kommando == "lista":
        gamla = set(kor_om(rot))
        for p in lista(rot):
            print(p + ("  (äldre mätning: kör session.py igen)" if p in gamla else ""))
        return 0
    if a.kommando == "minne":
        print(json.dumps(minne(rot, a.till), ensure_ascii=False, indent=1))
        return 0
    try:
        p = spara_att_jobba_pa(rot, _las(Path(a.fil)))
    except (ValueError, KeyError, json.JSONDecodeError) as e:
        print(f"{a.fil}: {e}")
        return 1
    print(f"sparad: {p}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
