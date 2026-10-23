"""Underlaget till Claude-appen (S5b, BESLUT B52): en text som Johannes kopierar i
SwingLab ("Ask Claude") och klistrar in i Claude-appen. Texten är skillens regler
(avsnitten mellan markörerna `claude-appen` i `.claude/skills/svinganalys/SKILL.md`)
och passets data som kompakt JSON: analysen, minnet, felens väg pass för pass och en
mall per fel som går att välja, med de låsta fälten ifyllda.

Telefonen bygger samma text ur sina pass (SwingLabKit `ClaudeUnderlag`). Python är
facit (BESLUT B12, B53): samma påhittade passhistorik ska ge samma text, tecken för
tecken.

    python3 tools/pc/underlag.py --swift     # instruktionen och kedjorna till SwingLabKit,
                                             # och facit i tools/tests/fixturer/claude_facit.json
    python3 tools/pc/underlag.py --facit-text <namn>   # skriv ut en påhittad text

På PC:n skriver `session.py --claude-text` texten för ett riktigt pass.

METOD MT11, MT12
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import random
import re
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "pc"

from . import analys as A  # noqa: E402
from . import att_jobba_pa as AJP  # noqa: E402
from . import historik as H  # noqa: E402
from . import katalog as KAT  # noqa: E402

ROT = Path(__file__).resolve().parents[2]
SKILL = ROT / ".claude" / "skills" / "svinganalys" / "SKILL.md"
KALLOR_SWIFT = ROT / "SwingLabKit" / "Sources" / "Swing" / "Claude" / "ClaudeKallor.swift"
FACIT = ROT / "tools" / "tests" / "fixturer" / "claude_facit.json"
START = "<!-- claude-appen -->"
SLUT = "<!-- /claude-appen -->"
HISTORIK_PASS = 6          # METOD MT11: felens väg i texten, de senaste passen
UPPFOLJNING_RADER = 4      # METOD MT11: uppföljningens senaste rader per övning
Z_DECIMALER = 1            # METOD MT11: z mot baslinjen i texten
RUBRIK = "# SwingLab: Att jobba på efter passet "
DATA_RUBRIK = "## Datan"


# --- instruktionen ---------------------------------------------------------------------

def instruktion(text: str | None = None) -> str:
    """Avsnitten mellan markörerna i SKILL.md, ordagrant och i ordning, med en tom rad
    emellan. Ett avsnitt utan slut, eller ett slut utan start, är ett fel."""
    text = SKILL.read_text(encoding="utf-8") if text is None else text
    delar, i = [], 0
    while True:
        a = text.find(START, i)
        b = text.find(SLUT, i)
        if a < 0:
            if b >= 0:
                raise ValueError("SKILL.md: ett slut på claude-appen utan start")
            break
        if b < 0 or b < a:
            raise ValueError("SKILL.md: claude-appen utan slut")
        nasta = text.find(START, a + len(START))
        if 0 <= nasta < b:
            raise ValueError("SKILL.md: två starter på claude-appen i rad")
        delar.append(text[a + len(START):b].strip("\n"))
        i = b + len(SLUT)
    if not delar:
        raise ValueError("SKILL.md: inga avsnitt för claude-appen")
    return "\n\n".join(delar)


# --- den kompakta JSON:en --------------------------------------------------------------

def tal(v) -> str:
    """Ett tal som Swift skriver det likadant: heltal utan decimaler, annars kortaste formen."""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if not math.isfinite(v):
        return "null"
    if v == int(v) and abs(v) < 1e15:
        return str(int(v))
    return repr(v)


def strang(s: str) -> str:
    return json.dumps(s, ensure_ascii=False)


def skriv(v, djup: int = 0) -> str:
    """JSON med varje fält och listpost på egen rad i de två yttersta nivåerna och kompakt
    därunder. Samma tecken i Swift (`JSONVarde.skriv`)."""
    if v is None:
        return "null"
    if isinstance(v, (bool, int, float)):
        return tal(v)
    if isinstance(v, str):
        return strang(v)
    sep = ",\n" if djup < 2 else ","
    if isinstance(v, dict):
        if not v:
            return "{}"
        inne = sep.join(strang(k) + ":" + skriv(x, djup + 1) for k, x in v.items())
        return "{\n" + inne + "\n}" if djup < 2 else "{" + inne + "}"
    if isinstance(v, (list, tuple)):
        if not v:
            return "[]"
        inne = sep.join(skriv(x, djup + 1) for x in v)
        return "[\n" + inne + "\n]" if djup < 2 else "[" + inne + "]"
    raise TypeError(type(v).__name__)


# --- datan -----------------------------------------------------------------------------

def _datum(pass_id: str) -> dt.date:
    return dt.date(int(pass_id[:4]), int(pass_id[4:6]), int(pass_id[6:8]))


def _z(z):
    return None if z is None else round(z, Z_DECIMALER)


def _utan_null(d: dict, valfria: tuple) -> dict:
    return {k: v for k, v in d.items() if not (k in valfria and v is None)}


def _klart_nar_fil(kn: dict) -> dict:
    """"Klart när" i filens form (FORMAT.md)."""
    return {"villkor": kn["villkor"], "grans": kn["grans"], "pa": kn.get("pa", "forsta_serien"),
            "pass_i_rad": kn.get("pass_i_rad", AJP.PASS_I_RAD)}


def _bedomning(analys: dict) -> list[dict]:
    """Analysens bedömning av de aktiva felen med ett tal. "Klart när" och märkningen står i
    mallarna, och `grund` syns på `spann` (null = egen baslinje). METOD MT11"""
    ut = []
    for b in analys["bedomning"]:
        if b["status"] == "av" or b["visat"] is None:
            continue
        ut.append(_utan_null({
            "id": b["id"], "vy": b["vy"], "enhet": b["enhet"], "status": b["status"],
            "z": _z(b["z"]), "n": b["n"], "visat": b["visat"], "forsta_serien": b["forsta_serien"],
            "spann": b["spann"], "gult": b["gult"], "baslinje": b.get("baslinje"),
            "mot_forra": b.get("mot_forra")}, ("z", "gult", "baslinje", "mot_forra")))
    return ut


def _historik(analyser: dict[str, dict], pass_id: str, katalog: dict) -> dict:
    """Felens väg genom de senaste passen (minnets `fel`): [visat, status] per pass, för aktiva
    fel med minst ett tal. Första serien för det som övas står i `ovningar`. METOD MT11"""
    passen = sorted(p for p in analyser if p <= pass_id)[-HISTORIK_PASS:]
    fel = {}
    for f in katalog["fel"]:
        if not f["aktiv"]:
            continue
        rader = []
        for p in passen:
            b = next((x for x in analyser[p]["bedomning"] if x["id"] == f["id"]), None)
            rader.append(None if b is None or b["visat"] is None else [b["visat"], b["status"]])
        if any(r is not None for r in rader):
            fel[f["id"]] = rader
    return {"pass": passen, "fel": fel}


def _ovning_minne(o: dict) -> dict:
    """Minnets rad för en övning (`historik.py minne`), med uppföljningens senaste rader."""
    if o["lage"] == "avslutad":
        return {"fel": o["fel"], "aktuell": o["aktuell"], "lage": o["lage"], "ovning_id": o["ovning_id"]}
    return {"fel": o["fel"], "aktuell": o["aktuell"], "lage": o["lage"], "klart_skal": o["klart_skal"],
            "ovning_id": o["ovning_id"], "forra_ovningar": o["forra_ovningar"], "steg": o["steg"],
            "typ": o["typ"], "fel_start": o["fel_start"], "valt_i_pass": o["valt_i_pass"],
            "klart_nar": _klart_nar_fil(o["klart_nar"]), "markning": o["markning"],
            "start_forsta_serien": o["start_forsta_serien"], "spridning": o["spridning"],
            "uppfoljning": o["uppfoljning"][-UPPFOLJNING_RADER:], "uppfyllt_i_rad": o["uppfyllt_i_rad"],
            "pass_utan_rorelse": o["pass_utan_rorelse"], "dagar_sedan_felet_valdes": o["dagar_sedan_felet_valdes"],
            "rorelse_sedan_felet_valdes": o["rorelse_sedan_felet_valdes"]}


def _pagaende(docs: list[dict], pass_id: str) -> dict | None:
    """Den senaste "Att jobba på" före passet, i korthet."""
    fore = sorted((d for d in docs if d["pass"] < pass_id), key=lambda d: d["pass"])
    if not fore:
        return None
    d = fore[-1]
    return {"pass": d["pass"],
            "saker": [{"fel": s["fel"], "ovning_id": H.ovning_id(s["ovning"]), "steg": s["ovning"]["steg"],
                       "tanke": s["ovning"]["tanke"], "typ": s["typ"], "block": s["block"]} for s in d["saker"]]}


def _alternativ(fid: str, ov_id: str, katalog: dict, kedjor: dict, tanke: str | None = None) -> dict | None:
    k = next(f for f in katalog["fel"] if f["id"] == fid)
    if ov_id == k["ovning_id"]:
        return {"id": ov_id, "text": k["ovning"], "kalla": "katalog", "tanke": tanke or k["tanke"]}
    x = next((x for x in kedjor["ovningar"] if x["fel"] == fid and x["id"] == ov_id), None)
    if x is None:
        return None
    ut = {"id": ov_id, "text": x["text"], "kalla": "research3"}
    if tanke:
        ut["tanke"] = tanke
    return ut


def mallar(analys: dict, ovningar: list[dict], katalog: dict, kedjor: dict) -> list[dict]:
    """En mall per fel som går att välja (steg A, B, D): grundorsakerna bland kandidaterna,
    eller de okända felen med förslag när inget är flaggat. Mallen bär det kontrollen låser:
    katalogens fält, analysens tal, "klart när" och märkningen (analysens för en ny övning,
    minnets när övningen fortsätter), blocket och följdfelen med kedjans väg, och de övningar
    och steg som går att välja. Ett fel vars övning är klar får ingen mall. METOD MT11"""
    K = {f["id"]: f for f in katalog["fel"]}
    bed = {b["id"]: b for b in analys["bedomning"]}
    kand = analys["kandidater"]
    minne = {o["fel"]: o for o in ovningar if o["lage"] != "avslutad"}
    if kand:
        fel = [k["fel"] for k in kand if not k["foljdfel"]]
    else:
        fel = [b["id"] for b in analys["bedomning"] if b["status"] == "okand" and b["klart_nar"] is not None]
    dag = _datum(analys["pass"])
    ut = []
    for fid in fel:
        k, b, o = K[fid], bed[fid], minne.get(fid)
        if o is not None and o["lage"] == "klart":
            continue
        nuvarande = None
        if o is not None and o["lage"] in ("ny", "fortsatt", "fysik"):
            nuvarande = _alternativ(fid, o["ovning_id"], katalog, kedjor, o["tanke"])
        if nuvarande is not None:
            kn, markning = _klart_nar_fil(o["klart_nar"]), o["markning"]
            i = AJP.STEG.index(o["steg"]) if o["steg"] in AJP.STEG else 0
            val, steg = [nuvarande], list(AJP.STEG[i:i + 2])
        else:
            if b["klart_nar"] is None:
                continue
            kn, markning = _klart_nar_fil(b["klart_nar"]), b["klart_nar"]["markning"]
            provade = ([o["ovning_id"]] + o["forra_ovningar"]) if o is not None else []
            val, sedda = [], set()
            for ov_id in [k["ovning_id"]] + [x["id"] for x in kedjor["ovningar"] if x["fel"] == fid]:
                if ov_id in provade or ov_id in sedda:
                    continue
                sedda.add(ov_id)
                val.append(_alternativ(fid, ov_id, katalog, kedjor))
            steg = [AJP.STEG[0]]
        start = _datum(o["fel_start"]) if o is not None else dag
        foljd = [{"fel": x["fel"], "namn": K[x["fel"]]["namn"], "vag": x["orsaker"][fid], "nu": bed[x["fel"]]["visat"],
                  "enhet": A.enhet(K[x["fel"]]["matt"])} for x in kand if x["foljdfel"] and fid in x["orsaker"]]
        ut.append({"fel": fid, "namn": k["namn"], "vy": k["vy"], "matt": k["matt"], "enhet": A.enhet(k["matt"]),
                   "nu": b["visat"], "spann": k["gront"], "markning": markning, "klart_nar": kn,
                   "foljdfel": foljd, "block": {"start": start.isoformat(), "vecka": (dag - start).days // 7 + 1},
                   "ovning_val": val, "steg_val": steg,
                   "fysik_test": [x["test"] for x in kedjor["fysik"] if x["fel"] == fid]})
    return ut


def data(analys: dict, analyser: dict[str, dict], ovningar: list[dict], docs: list[dict], skapad: str,
         katalog: dict | None = None, kedjor: dict | None = None) -> dict:
    """Passets data till Claude: analysen (`analys`), de tidigare passens analyser
    ({pass: analys}, för felens väg), minnet före passet (`historik.ovningar(…, fore=passet)`)
    och valen (`att_jobba_pa.json`). METOD MT11"""
    katalog = katalog or KAT.las()
    kedjor = kedjor or A.las_kedjor()
    pass_id = analys["pass"]
    alla = dict(analyser)
    alla[pass_id] = analys
    return {
        "pass": pass_id,
        "datum": _datum(pass_id).isoformat(),
        "klubbor": analys["klubbor"],
        "slag": {vy: sum(1 for r in analys["slag"] if r["vy"] == vy and "matt" in r) for vy in ("dtl", "fo")},
        "tempo_vy": analys["tempo_vy"],
        "forra": analys["forra"]["pass"] if analys["forra"] else None,
        "baslinje": {"pass": len(analys["baslinje"]["pass"]), "svingar": analys["baslinje"]["svingar"]},
        "kandidater": analys["kandidater"],
        "bedomning": _bedomning(analys),
        "spridning": [{"matt": s["matt"], "vy": s["vy"], "klubba": s["klubba"], "n": s["n"], "visat": s["visat"]}
                      for s in analys["spridning"] if s["n"] > 0],
        "historik": _historik(alla, pass_id, katalog),
        "ovningar": [_ovning_minne(o) for o in ovningar],
        "pagaende": _pagaende(docs, pass_id),
        "fil": {"format": AJP.FORMAT, "pass": pass_id, "skapad": skapad},
        "mallar": mallar(analys, ovningar, katalog, kedjor),
    }


def text(d: dict, instr: str | None = None) -> str:
    """Hela texten: rubriken, instruktionen och datan i ett kodblock."""
    instr = instruktion() if instr is None else instr
    return (RUBRIK + d["pass"] + "\n\n" + instr + "\n\n" + DATA_RUBRIK + "\n\n```json\n"
            + skriv(d) + "\n```\n")


def ur_historik(rot: Path, pass_id: str, skapad: str) -> str:
    """Texten för ett pass i historiken på PC:n (`session.py --claude-text`): minnet före
    passets val, som kontrollen läser det."""
    analyser = {p: H.las_analys(rot, p) for p in H.lista(rot) if p <= pass_id}
    docs = [d for d in H.att_jobba_pa(rot) if d["pass"] <= pass_id]
    ov = H.ovningar_ur(analyser, docs, till=pass_id, fore=pass_id)
    return text(data(analyser[pass_id], analyser, ov, docs, skapad))


# --- påhittade passhistoriker (facit för Swift) ------------------------------------------

def analysera_historik(historik: dict, katalog: dict | None = None, kedjor: dict | None = None) -> dict[str, dict]:
    """Varje pass i en påhittad historik analyserat som på telefonen: baslinjen ur alla
    tidigare pass och förra passet. `historik["pass"]` = [{pass, slag: [{vy, klubba, matt,
    forsta_serien}]}], äldst först."""
    katalog = katalog or KAT.las()
    kedjor = kedjor or A.las_kedjor()
    analyser: dict[str, dict] = {}
    tidigare: list[dict] = []
    forra = None
    for p in sorted(historik["pass"], key=lambda x: x["pass"]):
        slag = [{"vy": s["vy"], "serie": 1, "klubba": s.get("klubba"), "matt": s["matt"],
                 "forsta_serien": s["forsta_serien"]} for s in p["slag"]]
        a = A.analysera_rader(p["pass"], slag, None, tidigare, forra=forra, katalog=katalog, kedjor=kedjor,
                              baslinje_pass=sorted(analyser), skapad="")
        analyser[p["pass"]] = a
        tidigare = tidigare + A.svingar(a)
        forra = a
    return analyser


def facit_text(historik: dict, instr: str | None = None) -> str:
    """Texten för det senaste passet i en påhittad historik."""
    analyser = analysera_historik(historik)
    sist = max(analyser)
    docs = historik["att_jobba_pa"]
    ov = H.ovningar_ur(analyser, docs, till=sist, fore=sist)
    return text(data(analyser[sist], analyser, ov, docs, historik["skapad"]), instr)


def _vardera(rng: random.Random, medel: float, spr: float) -> float:
    """Ett påhittat värde med sex decimaler: inga medianer på en avrundnings halva, så att
    Pythons round och Swifts avrundning ger samma tal (METOD MT3)."""
    return round(medel + rng.gauss(0, spr), 6)


# Måtten per vy med medel och spridning för ett påhittat pass (cm, grader, kvot).
MATT_FO = {"backen_sway_topp": (-5.0, 1.2), "backen_resa_framat": (6.0, 1.5), "sway_gap_traff": (9.0, 1.5),
           "sidbojning_topp": (2.0, 1.5), "framre_armbage_efter_traff": (12.0, 4.0),
           "framre_armbage_topp": (8.0, 3.0), "axellinje_lutning_traff": (30.0, 2.0), "tempo": (2.9, 0.15)}
MATT_DTL = {"backen_thrust_traff": (3.0, 1.5), "brost_bojning_tapp": (4.0, 1.5), "bakre_armbage_topp": (95.0, 6.0),
            "handbana": (2.0, 2.0), "brost_bojning_adress": (40.0, 1.5), "brost_bojning_traff": (36.0, 2.0),
            "tempo": (2.9, 0.15)}


def _pass(rng: random.Random, pass_id: str, vyer: dict[str, int], flytt: dict[str, float], klubba: str = "7i") -> dict:
    slag = []
    for vy, n in vyer.items():
        matt = MATT_FO if vy == "fo" else MATT_DTL
        for i in range(n):
            m = {k: _vardera(rng, medel + flytt.get(k, 0.0), spr) for k, (medel, spr) in matt.items()}
            slag.append({"vy": vy, "klubba": klubba, "matt": m, "forsta_serien": i < A.FORSTA_SERIEN_SLAG})
    return {"pass": pass_id, "slag": slag}


def _sak(katalog: dict, kedjor: dict, analys: dict, fid: str, ordning: int, ov_id: str, steg: str,
         klart_nar: dict, markning, block_start: str, tanke: str, foljdfel: list[dict]) -> dict:
    k = next(f for f in katalog["fel"] if f["id"] == fid)
    ov = _alternativ(fid, ov_id, katalog, kedjor)
    b = next(x for x in analys["bedomning"] if x["id"] == fid)
    dag = _datum(analys["pass"])
    return {"ordning": ordning, "fel": fid, "namn": k["namn"], "vy": k["vy"], "matt": k["matt"],
            "enhet": A.enhet(k["matt"]), "nu": b["visat"], "spann": k["gront"], "markning": markning,
            "ovning": {"id": ov_id, "text": ov["text"], "tanke": tanke, "kalla": ov["kalla"], "steg": steg},
            "klart_nar": klart_nar, "foljdfel": foljdfel, "typ": "teknik", "fysik": None,
            "block": {"start": block_start, "vecka": (dag - dt.date.fromisoformat(block_start)).days // 7 + 1}}


def facit_historiker() -> dict[str, dict]:
    """De påhittade passhistorikerna (CLAUDE.md, Dataregeln: inga riktiga tal):
    `typiskt` (sex pass i båda vyerna, en övning som fortsätter och följdfel), `forsta` (ett
    pass, en vy, inget minne) och `byt` (en övning utan rörelse i fyra pass: byt övning)."""
    katalog, kedjor = KAT.las(), A.las_kedjor()
    ut = {}

    # typiskt: swayen väljs i pass 2 och fortsätter; resan framåt och sway gap följer den.
    rng = random.Random(52)
    ids = ["20261103-180000", "20261106-180000", "20261110-180000", "20261113-180000", "20261117-180000",
           "20261120-180000"]
    flyttar = [{}, {"backen_resa_framat": -1.5}, {"backen_sway_topp": 0.4, "backen_resa_framat": -2.0},
               {"backen_sway_topp": 0.9, "backen_thrust_traff": 2.5, "sway_gap_traff": -2.5},
               {"backen_sway_topp": 1.2, "backen_resa_framat": -3.0, "backen_thrust_traff": 4.0,
                "sway_gap_traff": -3.0},
               {"backen_sway_topp": 1.4, "backen_resa_framat": -3.5, "backen_thrust_traff": 4.5,
                "sway_gap_traff": -4.0, "brost_bojning_tapp": 3.0, "framre_armbage_efter_traff": 9.0}]
    hist = {"pass": [_pass(rng, p, {"fo": 16, "dtl": 16}, f) for p, f in zip(ids, flyttar)], "att_jobba_pa": [],
            "skapad": "2026-11-20T21:15:00+01:00"}
    analyser = analysera_historik(hist, katalog, kedjor)
    a2 = analyser[ids[1]]
    kn = a2["bedomning"][0]["klart_nar"]
    s = _sak(katalog, kedjor, a2, "sway_topp", 1, "kapp_och_fotterna_ihop", "langsamt_med_foremal",
             {"villkor": kn["villkor"], "grans": kn["grans"], "pa": "forsta_serien", "pass_i_rad": 2},
             kn["markning"], "2026-11-06", "Leave the stick standing.", [])
    hist["att_jobba_pa"].append({"format": AJP.FORMAT, "pass": ids[1], "skapad": "2026-11-06T21:00:00+01:00",
                                 "saker": [s]})
    a4 = analyser[ids[3]]
    s4 = _sak(katalog, kedjor, a4, "sway_topp", 1, "kapp_och_fotterna_ihop", "halv_fart", s["klart_nar"],
              s["markning"], "2026-11-06", "Leave the stick standing.", [])
    hist["att_jobba_pa"].append({"format": AJP.FORMAT, "pass": ids[3], "skapad": "2026-11-13T21:00:00+01:00",
                                 "saker": [s4]})
    ut["typiskt"] = hist

    # forsta: ett pass, bara FO (en telefon), inget minne.
    rng = random.Random(7)
    ut["forsta"] = {"pass": [_pass(rng, "20261201-170000", {"fo": 12}, {"backen_sway_topp": -1.5})],
                    "att_jobba_pa": [], "skapad": "2026-12-01T19:00:00+01:00"}

    # byt: early extension väljs och står still i fyra pass; minnet säger byt övning.
    rng = random.Random(11)
    ids = ["20261201-180000", "20261203-180000", "20261205-180000", "20261208-180000", "20261210-180000",
           "20261212-180000"]
    hist = {"pass": [_pass(rng, p, {"dtl": 14}, {"backen_thrust_traff": 7.0}) for p in ids], "att_jobba_pa": [],
            "skapad": "2026-12-12T20:00:00+01:00"}
    analyser = analysera_historik(hist, katalog, kedjor)
    a1 = analyser[ids[1]]
    b = next(x for x in a1["bedomning"] if x["id"] == "early_extension")
    kn = b["klart_nar"]
    s = _sak(katalog, kedjor, a1, "early_extension", 1, "stol_bakom", "langsamt_med_foremal",
             {"villkor": kn["villkor"], "grans": kn["grans"], "pa": "forsta_serien", "pass_i_rad": 2},
             kn["markning"], "2026-12-03", "Keep the chair touching.", [])
    hist["att_jobba_pa"].append({"format": AJP.FORMAT, "pass": ids[1], "skapad": "2026-12-03T21:00:00+01:00",
                                 "saker": [s]})
    ut["byt"] = hist
    return ut


def _svar_text(fil: dict, fore: str = "", efter: str = "", markning: str = "json") -> str:
    return fore + "```" + markning + "\n" + json.dumps(fil, ensure_ascii=False, indent=1) + "\n```" + efter


def facit_svar(historik: dict) -> list[tuple[str, str]]:
    """Svarstexter för den typiska historiken: giltiga och ogiltiga, som Claude-appen kan ge
    dem. Det giltiga svaret är byggt ur mallen som skillen säger."""
    katalog, kedjor = KAT.las(), A.las_kedjor()
    analyser = analysera_historik(historik, katalog, kedjor)
    sist = max(analyser)
    ov = H.ovningar_ur(analyser, historik["att_jobba_pa"], till=sist, fore=sist)
    d = data(analyser[sist], analyser, ov, historik["att_jobba_pa"], historik["skapad"], katalog, kedjor)
    saker = []
    for i, m in enumerate(d["mallar"][:2]):
        ov0 = m["ovning_val"][0]
        saker.append({"ordning": i + 1, "fel": m["fel"], "namn": m["namn"], "vy": m["vy"], "matt": m["matt"],
                      "enhet": m["enhet"], "nu": m["nu"], "spann": m["spann"], "markning": m["markning"],
                      "ovning": {"id": ov0["id"], "text": ov0["text"],
                                 "tanke": ov0.get("tanke") or "The chair stays in contact.", "kalla": ov0["kalla"],
                                 "steg": m["steg_val"][-1]},
                      "klart_nar": m["klart_nar"], "foljdfel": m["foljdfel"], "typ": "teknik", "fysik": None,
                      "block": m["block"]})
    fil = dict(d["fil"], saker=saker)
    rapport = "Pass 20 nov, 32 slag (16 FO, 16 DTL), 7i. Missen saknades.\n1. Sway …\n\n"
    ut = [("giltigt", _svar_text(fil, rapport, "\n\nSäg till om något är oklart.")),
          ("utan_markning", _svar_text(fil, rapport, markning="")),
          ("bara_json", json.dumps(fil, ensure_ascii=False)),
          ("typografiska", _svar_text(fil, rapport).replace('"', "“", 1).replace('"', "”", 1)),
          ("inget_block", "Jag behöver veta missen först."),
          ("trasig_json", rapport + "```json\n{\"format\": \"swinglab-att-jobba-pa/1\", \"saker\": [\n```\n")]
    fel = json.loads(json.dumps(fil))
    fel["saker"][0]["fel"] = "slice"
    ut.append(("fel_id", _svar_text(fel, rapport)))
    fel = json.loads(json.dumps(fil))
    fel["saker"] = [dict(fel["saker"][0], ordning=i + 1) for i in range(4)]
    ut.append(("for_manga", _svar_text(fel, rapport)))
    fel = json.loads(json.dumps(fil))
    fel["saker"][0]["ovning"]["tanke"] = "Great swing: 3 good reps!"
    fel["saker"][0]["nu"] = -1.0
    fel["saker"][0]["kommentar"] = "x"
    ut.append(("fritext_och_tal", _svar_text(fel, rapport)))
    fel = json.loads(json.dumps(fil))
    fel["saker"][0]["klart_nar"]["grans"] = 0
    fel["saker"][0]["block"]["vecka"] = 9
    ut.append(("last_och_block", _svar_text(fel, rapport)))
    fel = json.loads(json.dumps(fil))
    fel["extra"] = 1
    fel["skapad"] = "2026-13-01"
    fel["saker"][0]["ordning"] = True
    fel["saker"][0]["ovning"]["steg"] = "varierat"
    fel["saker"][0]["ovning"]["text"] = "Feet together."
    fel["saker"][0]["foljdfel"][0]["vag"] = list(reversed(fel["saker"][0]["foljdfel"][0]["vag"]))
    fel["saker"][0]["typ"] = "troligen_rorlighet"
    fel["saker"][1]["fel"] = ["chicken_wing"]
    ut.append(("blandat", _svar_text(fel, rapport)))
    utkast = json.loads(json.dumps(fil))
    utkast["saker"][0]["fel"] = "tempo"
    ut.append(("flera_block", _svar_text(utkast, "Utkast:\n", "\n\nRättat:\n") + _svar_text(fil)))
    ut.append(("annat_block_sist", _svar_text(fil, rapport) + "\n```json\n{\"pass\": 1}\n```\n"))
    return ut


# Texter att leta kodblock i: samma block i Python och Swift (METOD MT12).
KODBLOCK = ["a\n```json\n{1}\n```\nb ```\n2\n``` ```x", "````\nx\n```", "```json {\n```", "```\nöppet",
            "``` \r\n{}\r\n```", "x``\n```\n``` y ```\nz```", "```js`x\n1\n```\n```\n2```", ""]


def facit() -> dict:
    """Facit för Swift: instruktionen, och per påhittad historik indata, Pythons text och
    svaren med Pythons felkoder."""
    katalog, kedjor = KAT.las(), A.las_kedjor()
    hist = facit_historiker()
    ut = {"instruktion": instruktion(), "kodblock": [[k, AJP.kodblock(k)] for k in KODBLOCK], "historiker": []}
    for namn, h in hist.items():
        analyser = analysera_historik(h, katalog, kedjor)
        sist = max(analyser)
        ov = H.ovningar_ur(analyser, h["att_jobba_pa"], till=sist, fore=sist)
        rad = {"namn": namn, "historik": h, "text": facit_text(h), "svar": []}
        if namn == "typiskt":
            for snamn, s in facit_svar(h):
                d, fel = AJP.las_svar(s, analyser[sist], ov, katalog, kedjor)
                rad["svar"].append({"namn": snamn, "text": s, "godkand": d is not None, "fel": AJP.koder(fel)})
        ut["historiker"].append(rad)
    return ut


def facit_json() -> str:
    return json.dumps(facit(), ensure_ascii=False, separators=(",", ":")) + "\n"


# --- källorna till Swift ---------------------------------------------------------------

def _raa(text: str) -> str:
    if '"""#' in text:
        raise ValueError("texten kan inte stå i en rå Swift-sträng")
    return '#"""\n' + text + '\n"""#'


def swift_kalla() -> str:
    """Instruktionen ur SKILL.md och kedjor.json som Swift-källa: appen bär dem ordagrant
    (BESLUT B53), och provet fäller en skillnad."""
    return "\n".join([
        "// GENERERAD av tools/pc/underlag.py --swift. Ändra inte för hand: kör skriptet igen.",
        "//",
        "// Instruktionen till Claude-appen är avsnitten mellan markörerna claude-appen i",
        "// .claude/skills/svinganalys/SKILL.md, och kedjorna är tools/pc/kedjor.json, båda",
        "// ordagrant (BESLUT B53). test_underlag.py fäller filen när den inte längre är källornas.",
        "",
        "enum ClaudeKallor {",
        "    /// Reglerna ur skillen svinganalys, kortade (avsnitten claude-appen).",
        "    static let instruktion = " + _raa(instruktion()),
        "",
        "    /// tools/pc/kedjor.json, ordagrant.",
        "    static let kedjor = " + _raa(A.KEDJOR.read_text(encoding="utf-8").rstrip("\n")),
        "}",
        "",
    ])


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--swift", action="store_true", help="skriv ClaudeKallor.swift och claude_facit.json")
    ap.add_argument("--facit-text", help="skriv ut texten för en påhittad historik (typiskt, forsta, byt)")
    a = ap.parse_args(argv)
    if a.swift:
        KALLOR_SWIFT.parent.mkdir(parents=True, exist_ok=True)
        KALLOR_SWIFT.write_text(swift_kalla(), encoding="utf-8")
        FACIT.write_text(facit_json(), encoding="utf-8")
        print(f"skrev {KALLOR_SWIFT.relative_to(ROT)} och {FACIT.relative_to(ROT)}")
        return 0
    if a.facit_text:
        print(facit_text(facit_historiker()[a.facit_text]), end="")
        return 0
    ap.error("ange --swift eller --facit-text")
    return 2


if __name__ == "__main__":
    sys.exit(main())
