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

def spara_att_jobba_pa(rot: Path, d: dict) -> Path:
    """Kontrollerar filen mot passets analys (om den finns) och sparar den."""
    analys = las_analys(rot, d["pass"]) if (pass_mapp(rot, d.get("pass", "")) / "analys.json").is_file() else None
    fel = AJP.kontrollera(d, analys=analys)
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


def ovningar(rot: Path, till: str | None = None) -> list[dict]:
    """Varje fel som fått en övning: den senaste övningen, sedan när, och hur
    första serien rört sig pass för pass. METOD MT4, METOD MT5"""
    pass_ids = [p for p in lista(rot) if till is None or p <= till]
    analyser = {p: las_analys(rot, p) for p in pass_ids}
    docs = [d for d in att_jobba_pa(rot) if till is None or d["pass"] <= till]
    senast: dict[str, dict] = {}
    for d in docs:                                     # äldst först
        for s in d["saker"]:
            fid, namn = s["fel"], s["ovning"]["text"]
            g = senast.get(fid)
            if g is None or g["ovning"] != namn:
                senast[fid] = {"fel": fid, "vy": s["vy"], "matt": s["matt"], "ovning": namn,
                               "tanke": s["ovning"]["tanke"], "valt_i_pass": d["pass"],
                               "forra_ovningar": ([g["ovning"]] + g["forra_ovningar"]) if g else [],
                               "klart_nar": s["klart_nar"]}
            else:
                g["klart_nar"] = s["klart_nar"]
            senast[fid]["senast_i_pass"] = d["pass"]
    # Fel som inte längre står i den senaste filen är avslutade eller bytta.
    aktuella = {s["fel"] for s in docs[-1]["saker"]} if docs else set()
    ut = []
    for fid, o in senast.items():
        kn = o["klart_nar"]
        start_pass = o["valt_i_pass"]
        start_a = analyser.get(start_pass)
        start = None
        spr = None
        if start_a:
            start = _varde(start_a, o["vy"], o["matt"], True)
            if start is None:
                start = _varde(start_a, o["vy"], o["matt"], False)
            g = "alla" if o["vy"] == "bada" else o["vy"]
            hela = start_a["session"][g].get(o["matt"])
            spr = S.robust_sd(hela) if hela else None
        upp = []
        for p in pass_ids:
            if p <= start_pass:
                continue
            v = _varde(analyser[p], o["vy"], o["matt"], True)
            if v is None:
                upp.append({"pass": p, "forsta_serien": None})
                continue
            rad = {"pass": p, "forsta_serien": A.avrunda(o["matt"], v),
                   "uppfyllt": A.uppfyllt(kn["villkor"], kn["grans"], A.avrunda(o["matt"], v))}
            if start is not None and spr is not None:
                r = _rorelse(kn["villkor"], kn["grans"], start, v)
                rad.update(rorelse=A.avrunda(o["matt"], r), tydlig=bool(r > spr))
            upp.append(rad)
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
        nagon = any(u.get("tydlig") for u in upp)
        dagar = (_datum(pass_ids[-1]) - _datum(start_pass)).days if pass_ids else 0
        if uppfyllda >= kn.get("pass_i_rad", 1):
            lage = "klart"
        elif not upp:
            lage = "ny"
        elif not nagon and dagar >= FYSIK_DAGAR:
            lage = "fysik"
        elif utan >= BYT_OVNING_PASS:
            lage = "byt_ovning"
        else:
            lage = "fortsatt"
        o.update(start_forsta_serien=A.avrunda(o["matt"], start) if start is not None else None,
                 spridning=A.avrunda(o["matt"], spr) if spr is not None else None,
                 uppfoljning=upp, pass_sedan=len(upp), dagar_sedan=dagar, uppfyllt_i_rad=uppfyllda,
                 pass_utan_rorelse=utan, aktuell=fid in aktuella, lage=lage)
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
