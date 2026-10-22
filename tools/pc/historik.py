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


def tidigare(rot: Path, pass_id: str) -> list[str]:
    return [p for p in lista(rot) if p < pass_id]


def forra(rot: Path, pass_id: str) -> dict | None:
    t = tidigare(rot, pass_id)
    return las_analys(rot, t[-1]) if t else None


def baslinje(rot: Path, pass_id: str) -> tuple[list[dict], list[str]]:
    """Svingarna ur alla tidigare pass (M27) och vilka pass de kom ur."""
    t = tidigare(rot, pass_id)
    return [s for p in t for s in A.svingar(las_analys(rot, p))], t


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
    if not isinstance(pass_id, str) or not AJP.PASS_ID.match(pass_id):
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

def _varde(analys: dict, vy: str, matt: str, forsta: bool) -> float | None:
    g = "alla" if vy == "bada" else vy
    s = (analys["forsta_serien"] if forsta else analys["session"])[g].get(matt)
    return s["median"] if s else None


def _rorelse(villkor: str, grans, start: float, nu: float) -> float:
    """Hur långt värdet rört sig åt rätt håll sedan starten. METOD MT4"""
    if villkor == ">=":
        return nu - start
    if villkor == "<=":
        return start - nu
    c = (grans[0] + grans[1]) / 2
    return abs(start - c) - abs(nu - c)


def _foljning(analyser: dict, pass_ids: list[str], vy: str, matt: str, kn: dict, start_pass: str):
    """Startvärdet (första serien i startpasset), startpassets spridning och en
    rad per senare pass: första serien, om "klart när" hålls och rörelsen sedan
    starten. METOD MT4"""
    start_a = analyser.get(start_pass)
    start = spr = None
    if start_a:
        start = _varde(start_a, vy, matt, True)
        if start is None:
            start = _varde(start_a, vy, matt, False)
        hela = start_a["session"]["alla" if vy == "bada" else vy].get(matt)
        spr = S.robust_sd(hela) if hela else None
    rader = []
    for p in pass_ids:
        if p <= start_pass:
            continue
        v = _varde(analyser[p], vy, matt, True)
        if v is None:
            rader.append({"pass": p, "forsta_serien": None})
            continue
        rad = {"pass": p, "forsta_serien": A.avrunda(matt, v),
               "uppfyllt": A.uppfyllt(kn["villkor"], kn["grans"], A.avrunda(matt, v))}
        if start is not None and spr is not None:
            r = _rorelse(kn["villkor"], kn["grans"], start, v)
            rad.update(rorelse=A.avrunda(matt, r), tydlig=bool(r > spr))
        rader.append(rad)
    return start, spr, rader


def ovning_id(ov: dict) -> str:
    """Övningens stabila id. En fil från före id:t (S5) känns igen på texten."""
    return ov.get("id") or ov["text"]


def ovningar(rot: Path, till: str | None = None, fore: str | None = None) -> list[dict]:
    """Varje fel som fått en övning: den senaste övningen, sedan när, och hur
    första serien rört sig pass för pass. `fore` tar bara med valen före det
    passet (kontrollen av ett nytt val). METOD MT4, METOD MT5

    "Klart när" är det som skrevs när övningen valdes och flyttar sig inte så
    länge övningen fortsätter. Fysiken räknas från första gången felet valdes,
    över alla övningar för det. Ett fel som inte står i det senaste valet är
    avslutat."""
    pass_ids = [p for p in lista(rot) if till is None or p <= till]
    analyser = {p: las_analys(rot, p) for p in pass_ids}
    docs = [d for d in att_jobba_pa(rot) if (till is None or d["pass"] <= till) and (fore is None or d["pass"] < fore)]
    senast: dict[str, dict] = {}
    forra_fel: set[str] = set()
    for d in docs:                                     # äldst först
        for s in d["saker"]:
            # Övningen känns igen på sitt id (kedjor.json, katalogens ovning_id), inte på
            # texten: en omskriven formulering är samma övning och behåller steget.
            fid, text, ov_id = s["fel"], s["ovning"]["text"], ovning_id(s["ovning"])
            g = senast.get(fid)
            if g is None or fid not in forra_fel:      # felet väljs (på nytt): ett nytt block
                tidigare_ov = ([g["ovning_id"]] + g["forra_ovningar"]) if g else []
                g = senast[fid] = {"fel": fid, "vy": s["vy"], "matt": s["matt"], "fel_start": d["pass"],
                                   "valt_i_pass": d["pass"], "ovning_id": ov_id, "forra_ovningar": tidigare_ov,
                                   "klart_nar": s["klart_nar"], "markning": s["markning"]}
            elif g["ovning_id"] != ov_id:              # ny övning för samma fel: ny "klart när"
                g.update(valt_i_pass=d["pass"], ovning_id=ov_id,
                         forra_ovningar=[g["ovning_id"]] + g["forra_ovningar"],
                         klart_nar=s["klart_nar"], markning=s["markning"])
            g.update(ovning=text, tanke=s["ovning"]["tanke"], steg=s["ovning"]["steg"], typ=s["typ"],
                     fysik=s["fysik"], senast_i_pass=d["pass"])
        forra_fel = {s["fel"] for s in d["saker"]}
    ut = []
    for fid, o in senast.items():
        kn = o["klart_nar"]
        start, spr, upp = _foljning(analyser, pass_ids, o["vy"], o["matt"], kn, o["valt_i_pass"])
        _, _, upp_fel = _foljning(analyser, pass_ids, o["vy"], o["matt"], kn, o["fel_start"])
        uppfyllda = 0
        for u in reversed(upp):
            if not u.get("uppfyllt"):
                break
            uppfyllda += 1
        utan = 0
        for u in reversed(upp):
            if u.get("tydlig"):
                break
            utan += 1
        dagar = (_datum(pass_ids[-1]) - _datum(o["fel_start"])).days if pass_ids else 0
        rorelse_i_blocket = any(u.get("tydlig") for u in upp_fel)
        if fid not in forra_fel:
            lage = "avslutad"
        elif uppfyllda >= kn.get("pass_i_rad", 1):
            lage = "klart"
        elif upp_fel and not rorelse_i_blocket and dagar >= FYSIK_DAGAR and o["fysik"] is None:
            lage = "fysik"
        elif not upp:
            lage = "ny"
        elif utan >= BYT_OVNING_PASS:
            lage = "byt_ovning"
        else:
            lage = "fortsatt"
        o.update(start_forsta_serien=A.avrunda(o["matt"], start) if start is not None else None,
                 spridning=A.avrunda(o["matt"], spr) if spr is not None else None,
                 uppfoljning=upp, pass_sedan=len(upp), dagar_sedan_felet_valdes=dagar,
                 rorelse_sedan_felet_valdes=rorelse_i_blocket, uppfyllt_i_rad=uppfyllda,
                 pass_utan_rorelse=utan, aktuell=fid in forra_fel, lage=lage)
        ut.append(o)
    return ut


def minne(rot: Path = ROT, till: str | None = None) -> dict:
    """Det skillen läser före tolkningen: passen, varje fels väg genom vintern
    och övningarnas läge."""
    pass_ids = [p for p in lista(rot) if till is None or p <= till]
    passen, fel = [], {}
    for p in pass_ids:
        a = las_analys(rot, p)
        passen.append({"pass": p, "datum": _datum(p).isoformat(), "klubbor": a.get("klubbor", []),
                       "slag": {vy: sum(1 for r in a["slag"] if r["vy"] == vy and "matt" in r) for vy in ("dtl", "fo")}})
        for b in a["bedomning"]:
            fel.setdefault(b["id"], []).append({"pass": p, "varde": b["visat"], "forsta_serien": b["forsta_serien"],
                                                "status": b["status"]})
    return {"format": MINNE, "till": pass_ids[-1] if pass_ids else None, "pass": passen, "fel": fel,
            "ovningar": ovningar(rot, till)}


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
        for p in lista(rot):
            print(p)
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
