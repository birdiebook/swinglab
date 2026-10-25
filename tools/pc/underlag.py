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
MAX_NYA_MALLAR = 3         # METOD MT11: mallar för nya fel (övningar som fortsätter kommer till)
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
    """Analysens bedömning av de aktiva felen med ett tal som inte är gröna (ett grönt fel övas
    aldrig, steg B). "Klart när" och märkningen står i mallarna. METOD MT11"""
    ut = []
    for b in analys["bedomning"]:
        if b["status"] in ("av", "gron") or b["visat"] is None:
            continue
        ut.append(_utan_null({
            "id": b["id"], "vy": b["vy"], "enhet": b["enhet"], "status": b["status"], "grund": b["grund"],
            "z": _z(b["z"]), "n": b["n"], "visat": b["visat"], "forsta_serien": b["forsta_serien"],
            "spann": b["spann"], "gult": b["gult"], "baslinje": b.get("baslinje"),
            "mot_forra": b.get("mot_forra")}, ("grund", "z", "gult", "baslinje", "mot_forra")))
    return ut


def _historik(enh: list[dict], pass_id: str, katalog: dict) -> dict:
    """Felens väg genom de senaste passen (minnets `fel`): [visat, status] per pass, för aktiva
    fel med minst ett tal som inte är grönt i alla pass. Första serien för det som övas står i
    `ovningar`. METOD MT11"""
    passen = sorted((u for u in enh if u["pass"] <= pass_id), key=A._ordning)[-HISTORIK_PASS:]
    fel = {}
    for f in katalog["fel"]:
        if not f["aktiv"]:
            continue
        rader = []
        for u in passen:
            b = next((x for x in u["bedomning"] if x["id"] == f["id"]), None)
            rader.append(None if b is None or b["visat"] is None else [b["visat"], b["status"]])
        if any(r is not None and r[1] != "gron" for r in rader):
            fel[f["id"]] = rader
    return {"pass": [u["pass"] for u in passen], "fel": fel}


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
    """En mall per fel som går att välja (steg A, B, D): de tre första grundorsakerna bland
    kandidaterna och varje övning som fortsätter, eller de okända felen med förslag när inget
    är flaggat. Mallen bär det kontrollen låser: katalogens fält, analysens tal och `grund`,
    "klart när" och märkningen (analysens för en ny övning, minnets när övningen fortsätter),
    blocket och följdfelen med kedjans väg, och de övningar och steg som går att välja. Ett fel
    vars övning är klar får ingen mall. METOD MT11"""
    K = {f["id"]: f for f in katalog["fel"]}
    bed = {b["id"]: b for b in analys["bedomning"]}
    kand = analys["kandidater"]
    minne = {o["fel"]: o for o in ovningar if o["lage"] != "avslutad"}
    if kand:
        fel = [k["fel"] for k in kand if not k["foljdfel"]]
    else:
        fel = [b["id"] for b in analys["bedomning"]
               if b["status"] == "okand" and b["klart_nar"] is not None and b["visat"] is not None]
    dag = _datum(analys["pass"])
    ut, nya = [], 0
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
            if b["klart_nar"] is None or nya >= MAX_NYA_MALLAR:
                continue
            nya += 1
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
                  "enhet": A.enhet(bed[x["fel"]]["matt"])} for x in kand if x["foljdfel"] and fid in x["orsaker"]]
        # Måttet och bandet är analysens (klubbans källa och klubbans band, BESLUT B86, B88).
        ut.append({"fel": fid, "namn": k["namn"], "vy": k["vy"], "matt": b["matt"], "enhet": A.enhet(b["matt"]),
                   "nu": b["visat"], "grund": b["grund"], "spann": b["spann"], "markning": markning, "klart_nar": kn,
                   "foljdfel": foljd, "block": {"start": start.isoformat(), "vecka": (dag - start).days // 7 + 1},
                   "ovning_val": val, "steg_val": steg,
                   "fysik_test": [x["test"] for x in kedjor["fysik"] if x["fel"] == fid]})
    return ut


def data(analys: dict, enh: list[dict], ovningar: list[dict], docs: list[dict], skapad: str,
         katalog: dict | None = None, kedjor: dict | None = None) -> dict:
    """Passets data till Claude: passets enhet (huvudklubban, `analys`), enheterna i samma
    sammanhang (`historik.sammanhang`, för felens väg), minnet före passet
    (`historik.ovningar_ur(…, fore=passet)`) och valen (`att_jobba_pa.json`). METOD MT11"""
    katalog = katalog or KAT.las()
    kedjor = kedjor or A.las_kedjor()
    pass_id = analys["pass"]
    sv = analys.get("svingar") or A.svingar_for(analys, analys.get("huvudklubba"))
    return {
        "pass": pass_id,
        "datum": _datum(pass_id).isoformat(),
        "klubba": analys.get("klubba_id", analys.get("huvudklubba")),
        "slag": {vy: sum(1 for s in sv if s["vy"] == vy) for vy in ("dtl", "fo")},
        "tempo_vy": analys["tempo_vy"],
        "forra": analys["forra"]["pass"] if analys["forra"] else None,
        "baslinje": {"pass": len(analys["baslinje"]["pass"]), "svingar": analys["baslinje"]["svingar"]},
        "kandidater": analys["kandidater"],
        "bedomning": _bedomning(analys),
        "spridning": [{"matt": s["matt"], "vy": s["vy"], "n": s["n"], "visat": s["visat"]}
                      for s in analys["spridning"] if s["n"] > 0],
        "historik": _historik(enh + ([] if any(u is analys for u in enh) else [analys]), pass_id, katalog),
        "ovningar": [_ovning_minne(o) for o in ovningar],
        "pagaende": _pagaende(docs, pass_id),
        "fil": {"format": AJP.FORMAT, "pass": pass_id, "skapad": skapad},
        "mallar": mallar(analys, ovningar, katalog, kedjor),
    }


def underlag(enh: list[dict], nu: str, docs: list[dict], skapad: str, katalog: dict | None = None,
             kedjor: dict | None = None) -> dict:
    """Datan för passet `nu` ur alla enheter (`analys.enheter`) och valen: enheterna med samma
    klubba och längd som passets huvudklubba, valen för deras pass och minnet före passets val
    (BESLUT B56). Samma väg som telefonens `ClaudeUnderlag`."""
    katalog = katalog or KAT.las()
    kedjor = kedjor or A.las_kedjor()
    ctx = H.sammanhang(enh, nu)
    nu_u = next(u for u in ctx if u["huvud"] and u["pass"] == nu)
    huvudpass = {u["pass"] for u in ctx if u["huvud"]}
    docs = [d for d in docs if d["pass"] in huvudpass]
    ov = H.ovningar_ur(ctx, docs, till=nu, fore=nu, kedjor=kedjor)
    return data(nu_u, ctx, ov, docs, skapad, katalog, kedjor)


def text(d: dict, instr: str | None = None) -> str:
    """Hela texten: rubriken, instruktionen och datan i ett kodblock."""
    instr = instruktion() if instr is None else instr
    return (RUBRIK + d["pass"] + "\n\n" + instr + "\n\n" + DATA_RUBRIK + "\n\n```json\n"
            + skriv(d) + "\n```\n")


def ur_historik(rot: Path, pass_id: str, skapad: str) -> str:
    """Texten för ett pass i historiken på PC:n (`session.py --claude-text`): minnet före
    passets val, som kontrollen läser det, för passets huvudklubba och längd (BESLUT B56)."""
    return text(underlag(H.enheter(rot, till=pass_id), pass_id, H.att_jobba_pa(rot), skapad))


# --- påhittade passhistoriker (facit för Swift) ------------------------------------------

def analysera_historik(historik: dict, katalog: dict | None = None, kedjor: dict | None = None) -> list[dict]:
    """Varje pass i en påhittad historik analyserat i tur och ordning, varje klubba för sig mot
    de tidigare enheterna med samma klubba och längd (BESLUT B56). `historik["pass"]` = [{pass,
    langd, slag: [{vy, klubba, matt, forsta_serien}]}]. Svarar enheterna (`analys.enheter`)."""
    katalog = katalog or KAT.las()
    kedjor = kedjor or A.las_kedjor()
    enh: list[dict] = []
    for p in sorted(historik["pass"], key=lambda x: x["pass"]):
        slag = [{"vy": s["vy"], "serie": 1, "klubba": s.get("klubba"), "matt": s["matt"],
                 "forsta_serien": s["forsta_serien"]} for s in p["slag"]]
        a = A.analysera_rader(p["pass"], slag, p.get("langd"), enh, katalog=katalog, kedjor=kedjor, skapad="")
        enh = enh + A.enheter(a)
    return enh


def _nu(historik: dict) -> str:
    return historik.get("nu") or max(p["pass"] for p in historik["pass"])


def facit_data(historik: dict) -> dict:
    return underlag(analysera_historik(historik), _nu(historik), historik["att_jobba_pa"], historik["skapad"])


def facit_text(historik: dict, instr: str | None = None) -> str:
    """Texten för passet `nu` (annars det senaste) i en påhittad historik."""
    return text(facit_data(historik), instr)


def _vardera(rng: random.Random, medel: float, spr: float) -> float:
    """Ett påhittat värde med sex decimaler (METOD MT11)."""
    return round(medel + rng.gauss(0, spr), 6)


# Måtten per vy med medel och spridning för ett påhittat pass (cm, grader, kvot). Resan framåt och
# händernas bana ligger innanför research 6:s band (BESLUT B86), som felen utan gräns gjorde förut.
MATT_FO = {"backen_sway_topp": (-5.0, 1.2), "backen_resa_framat": (12.0, 1.5), "sway_gap_traff": (9.0, 1.5),
           "sidbojning_topp": (2.0, 1.5), "framre_armbage_efter_traff": (12.0, 4.0),
           "framre_armbage_topp": (8.0, 3.0), "axellinje_lutning_traff": (30.0, 2.0), "tempo": (2.9, 0.15)}
MATT_DTL = {"backen_thrust_traff": (3.0, 1.5), "brost_bojning_tapp": (4.0, 1.5), "bakre_armbage_topp": (95.0, 6.0),
            "handbana": (-2.0, 2.0), "brost_bojning_adress": (40.0, 1.5), "brost_bojning_traff": (36.0, 2.0),
            "tempo": (2.9, 0.15)}


def _pass(rng: random.Random, pass_id: str, vyer: dict[str, int], flytt: dict[str, float], klubba="j7",
          langd: float | None = 1.80, slag: list | None = None) -> dict:
    """Ett påhittat pass: `vyer` = slag per vy, `flytt` = medlens förskjutning per mått.
    `slag` lägger till slagen till ett pass som redan finns (en andra klubba)."""
    ut = slag if slag is not None else []
    for vy, n in vyer.items():
        matt = MATT_FO if vy == "fo" else MATT_DTL
        for i in range(n):
            m = {k: _vardera(rng, medel + flytt.get(k, 0.0), spr) for k, (medel, spr) in matt.items()}
            ut.append({"vy": vy, "klubba": klubba, "matt": m, "forsta_serien": i < A.FORSTA_SERIEN_SLAG})
    return {"pass": pass_id, "langd": langd, "slag": ut}


def _huvud(enh: list[dict], pass_id: str) -> dict:
    return next(u for u in enh if u["huvud"] and u["pass"] == pass_id)


def _sak(katalog: dict, kedjor: dict, u: dict, fid: str, ordning: int, ov_id: str, steg: str,
         klart_nar: dict, markning, block_start: str, tanke: str, foljdfel: list[dict] = (), typ: str = "teknik",
         fysik=None) -> dict:
    k = next(f for f in katalog["fel"] if f["id"] == fid)
    ov = _alternativ(fid, ov_id, katalog, kedjor)
    b = next(x for x in u["bedomning"] if x["id"] == fid)
    dag = _datum(u["pass"])
    return {"ordning": ordning, "fel": fid, "namn": k["namn"], "vy": k["vy"], "matt": b["matt"],
            "enhet": A.enhet(b["matt"]), "nu": b["visat"], "spann": b["spann"], "markning": markning,
            "ovning": {"id": ov_id, "text": ov["text"], "tanke": tanke, "kalla": ov["kalla"], "steg": steg},
            "klart_nar": klart_nar, "foljdfel": list(foljdfel), "typ": typ, "fysik": fysik,
            "block": {"start": block_start, "vecka": (dag - dt.date.fromisoformat(block_start)).days // 7 + 1}}


def _forslag(u: dict, fid: str) -> tuple[dict, object]:
    """Analysens "klart när" i filens form och märkningen, för ett fel i enheten."""
    kn = next(x for x in u["bedomning"] if x["id"] == fid)["klart_nar"]
    return {"villkor": kn["villkor"], "grans": kn["grans"], "pa": "forsta_serien", "pass_i_rad": 2}, kn["markning"]


def _doc(pass_id: str, saker: list[dict], skapad: str) -> dict:
    return {"format": AJP.FORMAT, "pass": pass_id, "skapad": skapad, "saker": saker}


def _dagar(start: str, steg: int, n: int, tid: str = "180000") -> list[str]:
    d0 = dt.date.fromisoformat(start)
    return [(d0 + dt.timedelta(days=steg * i)).strftime("%Y%m%d") + "-" + tid for i in range(n)]


def facit_historiker() -> dict[str, dict]:
    """De påhittade passhistorikerna (CLAUDE.md, Dataregeln: inga riktiga tal), var och en med
    passet `nu` sist:

    - `typiskt`: sex pass i båda vyerna, swayen väljs och fortsätter, följdfel;
    - `forsta`: ett pass, bara FO, inget minne, okända fel;
    - `byt`: early extension utan rörelse i fyra pass (byt övning);
    - `klart`: swayen klar på "klart när" och böjda armen klar för att den inte längre flaggas;
    - `fysik`: early extension utan rörelse i sex veckor över två övningar (treregeln);
    - `vyer`: ett FO-fel som väntar medan passen är DTL (ny), ett DTL-fel som släpps
      (avslutad), och spridning på färre än 8 slag;
    - `klubbor`: två klubbor i ett pass, ett pass utan klubba och ett med en annan längd;
    - `varsta`: många grundorsaker på en gång (storleken)."""
    katalog, kedjor = KAT.las(), A.las_kedjor()
    ut = {}
    S = "langsamt_med_foremal"

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
    enh = analysera_historik(hist, katalog, kedjor)
    kn, mk = _forslag(_huvud(enh, ids[1]), "sway_topp")
    s = _sak(katalog, kedjor, _huvud(enh, ids[1]), "sway_topp", 1, "kapp_och_fotterna_ihop", S, kn, mk, "2026-11-06",
             "Leave the stick standing.")
    hist["att_jobba_pa"].append(_doc(ids[1], [s], "2026-11-06T21:00:00+01:00"))
    s4 = _sak(katalog, kedjor, _huvud(enh, ids[3]), "sway_topp", 1, "kapp_och_fotterna_ihop", "halv_fart", kn, mk,
              "2026-11-06", "Leave the stick standing.")
    hist["att_jobba_pa"].append(_doc(ids[3], [s4], "2026-11-13T21:00:00+01:00"))
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
    enh = analysera_historik(hist, katalog, kedjor)
    kn, mk = _forslag(_huvud(enh, ids[1]), "early_extension")
    hist["att_jobba_pa"].append(_doc(ids[1], [_sak(katalog, kedjor, _huvud(enh, ids[1]), "early_extension", 1,
                                                   "stol_bakom", S, kn, mk, "2026-12-03", "Keep the chair touching.")],
                                     "2026-12-03T21:00:00+01:00"))
    ut["byt"] = hist

    # klart: swayen hålls två pass i rad på första serien; böjda armen blir grön.
    rng = random.Random(23)
    ids = ["20260105-170000", "20260108-170000", "20260112-170000", "20260115-170000"]
    flyttar = [{}, {"framre_armbage_topp": 9.0}, {"backen_sway_topp": 3.8}, {"backen_sway_topp": 3.8}]
    hist = {"pass": [_pass(rng, p, {"fo": 14}, f) for p, f in zip(ids, flyttar)], "att_jobba_pa": [],
            "skapad": "2026-01-15T19:30:00+01:00"}
    enh = analysera_historik(hist, katalog, kedjor)
    u1 = _huvud(enh, ids[1])
    kn, mk = _forslag(u1, "sway_topp")
    hist["att_jobba_pa"].append(_doc(ids[1], [
        _sak(katalog, kedjor, u1, "sway_topp", 1, "kapp_och_fotterna_ihop", S, kn, mk, "2026-01-08",
             "Leave the stick standing."),
        _sak(katalog, kedjor, u1, "bojd_framre_arm", 2, "vaggen_bakom", S,
             {"villkor": "<=", "grans": -50.0, "pa": "forsta_serien", "pass_i_rad": 2}, "egen", "2026-01-08",
             "The wall stays behind the club.")], "2026-01-08T20:00:00+01:00"))
    ut["klart"] = hist

    # fysik: early extension i sex veckor utan rörelse, över två övningar.
    rng = random.Random(31)
    ids = _dagar("2026-01-05", 4, 12)
    hist = {"pass": [_pass(rng, p, {"dtl": 12}, {"backen_thrust_traff": 7.0 + 0.3 * i}) for i, p in enumerate(ids)],
            "att_jobba_pa": [], "skapad": "2026-02-18T20:00:00+01:00"}
    enh = analysera_historik(hist, katalog, kedjor)
    u0, u5 = _huvud(enh, ids[0]), _huvud(enh, ids[5])
    kn, mk = _forslag(u0, "early_extension")
    k5, m5 = _forslag(u5, "early_extension")
    hist["att_jobba_pa"] += [
        _doc(ids[0], [_sak(katalog, kedjor, u0, "early_extension", 1, "stol_bakom", S, kn, mk, "2026-01-05",
                           "Keep the chair touching.")], "2026-01-05T21:00:00+01:00"),
        _doc(ids[5], [_sak(katalog, kedjor, u5, "early_extension", 1, "vagg_eller_stol_bakom", S, k5, m5,
                           "2026-01-05", "Keep the wall touching.")], "2026-01-25T21:00:00+01:00")]
    ut["fysik"] = hist

    # vyer: pass 1 i båda vyerna, sedan bara DTL. Swayen (FO) väntar, over the top släpps.
    rng = random.Random(41)
    ids = ["20260201-160000", "20260204-160000", "20260207-160000"]
    hist = {"pass": [_pass(rng, ids[0], {"fo": 12, "dtl": 12}, {"backen_sway_topp": -1.0, "handbana": 4.0}),
                     _pass(rng, ids[1], {"dtl": 12}, {"backen_thrust_traff": 6.0}),
                     _pass(rng, ids[2], {"dtl": 6}, {"backen_thrust_traff": 6.0})],
            "att_jobba_pa": [], "skapad": "2026-02-07T18:00:00+01:00"}
    enh = analysera_historik(hist, katalog, kedjor)
    u0, u1 = _huvud(enh, ids[0]), _huvud(enh, ids[1])
    ks, ms = _forslag(u0, "sway_topp")
    ko, mo = {"villkor": "<=", "grans": 1.0, "pa": "forsta_serien", "pass_i_rad": 2}, "egen"
    ke, me = _forslag(u1, "early_extension")
    hist["att_jobba_pa"] += [
        _doc(ids[0], [_sak(katalog, kedjor, u0, "sway_topp", 1, "kapp_och_fotterna_ihop", S, ks, ms, "2026-02-01",
                           "Leave the stick standing."),
                      _sak(katalog, kedjor, u0, "over_the_top", 2, "headcover", S, ko, mo, "2026-02-01",
                           "Miss the headcover.")], "2026-02-01T20:00:00+01:00"),
        _doc(ids[1], [_sak(katalog, kedjor, u1, "early_extension", 1, "stol_bakom", S, ke, me, "2026-02-04",
                           "Keep the chair touching.")], "2026-02-04T20:00:00+01:00")]
    ut["vyer"] = hist

    # klubbor: j7 och driver i samma pass, ett pass utan klubba, och ett med en annan längd.
    rng = random.Random(61)
    ids = ["20260301-150000", "20260303-150000", "20260305-150000", "20260307-150000", "20260309-150000"]
    p0 = _pass(rng, ids[0], {"fo": 12}, {"backen_sway_topp": -1.0})
    _pass(rng, ids[0], {"fo": 10}, {"backen_sway_topp": -2.0}, klubba="dr", slag=p0["slag"])
    p2 = _pass(rng, ids[2], {"fo": 10}, {}, klubba=None)
    _pass(rng, ids[2], {"fo": 6}, {"backen_sway_topp": -0.5}, slag=p2["slag"])
    hist = {"pass": [p0, _pass(rng, ids[1], {"fo": 14}, {"backen_sway_topp": -2.0}, klubba="dr"), p2,
                     _pass(rng, ids[3], {"fo": 12}, {}, langd=1.90),
                     _pass(rng, ids[4], {"fo": 12}, {"backen_sway_topp": 0.5})],
            "att_jobba_pa": [], "skapad": "2026-03-09T17:00:00+01:00"}
    enh = analysera_historik(hist, katalog, kedjor)
    u0, u1 = _huvud(enh, ids[0]), _huvud(enh, ids[1])
    k0, m0 = _forslag(u0, "sway_topp")
    k1, m1 = _forslag(u1, "sway_topp")
    hist["att_jobba_pa"] += [
        _doc(ids[0], [_sak(katalog, kedjor, u0, "sway_topp", 1, "kapp_och_fotterna_ihop", S, k0, m0, "2026-03-01",
                           "Leave the stick standing.")], "2026-03-01T19:00:00+01:00"),
        _doc(ids[1], [_sak(katalog, kedjor, u1, "sway_topp", 1, "fotterna_ihop_balans", S, k1, m1, "2026-03-03",
                           "Keep the feet quiet.")], "2026-03-03T19:00:00+01:00")]
    ut["klubbor"] = hist

    # varsta: många grundorsaker på en gång.
    rng = random.Random(3)
    ids = ["20261103-180000", "20261106-180000", "20261110-180000", "20261113-180000", "20261117-180000",
           "20261120-180000"]
    big = {"framre_armbage_efter_traff": 15, "bakre_armbage_topp": 25, "handbana": 8, "framre_armbage_topp": 12,
           "backen_sway_topp": -2, "backen_thrust_traff": 6, "brost_bojning_tapp": 6, "sidbojning_topp": 6,
           "tempo": 0.8}
    ut["varsta"] = {"pass": [_pass(rng, p, {"fo": 16, "dtl": 16}, f) for p, f in zip(ids, [{}] * 5 + [big])],
                    "att_jobba_pa": [], "skapad": "2026-11-20T21:15:00+01:00"}
    return ut


def _svar_text(fil: dict, fore: str = "", efter: str = "", markning: str = "json", indrag: int | None = None) -> str:
    return fore + "```" + markning + "\n" + json.dumps(fil, ensure_ascii=False, indent=indrag) + "\n```" + efter


def giltigt(d: dict, antal: int = 2) -> dict:
    """Ett svar byggt ur mallarna som skillen säger: de första mallarna, mallens fält, den
    första övningen och det sista steget. En övning i läget fysik får treregelns svar."""
    lage = {o["fel"]: o["lage"] for o in d["ovningar"]}
    saker = []
    for i, m in enumerate(d["mallar"][:antal]):
        ov0 = m["ovning_val"][0]
        fysik, typ = None, "teknik"
        if lage.get(m["fel"]) == "fysik":
            fysik = {"test": m["fysik_test"][0], "treregeln": [True, True, False],
                     "ovning": "Lie on the back and lower one leg slowly."}
            typ = "teknik_kroppen_gor_det_svart"
        saker.append({"ordning": i + 1, **{k: m[k] for k in ("fel", "namn", "vy", "matt", "enhet", "nu", "spann",
                                                             "markning")},
                      "ovning": {"id": ov0["id"], "text": ov0["text"],
                                 "tanke": ov0.get("tanke") or "The chair stays in contact.", "kalla": ov0["kalla"],
                                 "steg": m["steg_val"][-1]},
                      "klart_nar": m["klart_nar"], "foljdfel": m["foljdfel"], "typ": typ, "fysik": fysik,
                      "block": m["block"]})
    return dict(d["fil"], saker=saker)


def _sak_ur_katalogen(katalog: dict, kedjor: dict, u: dict, fid: str, ordning: int = 1, ov_id: str | None = None,
                      **kw) -> dict:
    """En sak för ett fel med katalogens fält och analysens tal, för mutationerna."""
    k = next(f for f in katalog["fel"] if f["id"] == fid)
    b = next(x for x in u["bedomning"] if x["id"] == fid)
    kn = b["klart_nar"] or {"villkor": "<=", "grans": 0, "markning": "egen"}
    s = _sak(katalog, kedjor, u, fid, ordning, ov_id or k["ovning_id"], "langsamt_med_foremal",
             {"villkor": kn["villkor"], "grans": kn["grans"], "pa": "forsta_serien", "pass_i_rad": 2},
             kn["markning"], _datum(u["pass"]).isoformat(), "The club swings past the chair.")
    s.update(kw)
    return s


def mutationer(fil: dict, u: dict) -> list[tuple[str, object]]:
    """En ändring per felkod i ett giltigt svar med två saker (en som fortsätter, en ny), som
    Claude-appen kan ge dem. Svarar (namn, filen eller texten)."""
    katalog, kedjor = KAT.las(), A.las_kedjor()
    ut: list[tuple[str, object]] = []

    def m(namn, f):
        x = json.loads(json.dumps(fil))
        f(x)
        ut.append((namn, x))

    def satt(*vag_och_varde):
        *vag, v = vag_och_varde

        def f(x):
            t = x
            for k in vag[:-1]:
                t = t[k]
            t[vag[-1]] = v
        return f

    s0 = fil["saker"][0]
    ff = s0["foljdfel"][0]
    tempo = {"fel": "tempo", "namn": next(f for f in katalog["fel"] if f["id"] == "tempo")["namn"], "vag": ["tempo"],
             "nu": 2.9, "enhet": ""}
    ny_ov = next(x for x in kedjor["ovningar"] if x["fel"] == fil["saker"][1]["fel"])
    m("objekt", satt("saker", 0, "x"))
    m("okand_nyckel", satt("extra", 1))
    m("saknas", lambda x: x["saker"][0].pop("block"))
    m("format", satt("format", "x"))
    m("pass_form", satt("pass", "20261399-180000"))
    m("inte_analysens", satt("pass", "20261117-180000"))
    m("iso", satt("skapad", "igår"))
    m("antal", satt("saker", []))
    m("dubblett", lambda x: x["saker"].__setitem__(1, dict(x["saker"][0], ordning=2)))
    m("ordning", satt("saker", 0, "ordning", 3))
    m("ordning_bool", satt("saker", 0, "ordning", True))
    m("ej_i_katalogen", satt("saker", 1, "fel", "slice"))
    m("avstangt", lambda x: x["saker"].__setitem__(1, _sak_ur_katalogen(katalog, kedjor, u, "axellutning", 2)))
    m("katalogens", satt("saker", 0, "namn", "x"))
    m("mattets", satt("saker", 0, "enhet", "kg"))
    m("svingens_ordning", lambda x: x.__setitem__("saker", [dict(x["saker"][1], ordning=1),
                                                             dict(x["saker"][0], ordning=2)]))
    m("foljdfel_av_vald", lambda x: x["saker"].insert(1, _sak_ur_katalogen(katalog, kedjor, u, "backens_resa_framat",
                                                                            2)) or x["saker"].pop())
    m("inte_flaggat", lambda x: x["saker"].__setitem__(1, _sak_ur_katalogen(katalog, kedjor, u, "tempo", 2)))
    m("analysens_tal", satt("saker", 0, "nu", -1.0))
    m("nu_bool", satt("saker", 1, "nu", True))
    m("ej_i_kedjorna", satt("saker", 1, "ovning", "kalla", "research3"))
    m("kedjornas", lambda x: x["saker"][1]["ovning"].update(id=ny_ov["id"], text="x", kalla="research3"))
    m("kalla", satt("saker", 1, "ovning", "kalla", "x"))
    m("text", satt("saker", 0, "ovning", "tanke", " "))
    m("for_lang", satt("saker", 0, "ovning", "tanke", "The club swings past the chair " * 3))
    m("siffror", satt("saker", 0, "ovning", "tanke", "Swing past the chair 3 times."))
    m("vardeord", satt("saker", 0, "ovning", "tanke", "A great turn past the chair."))
    m("well_done", satt("saker", 0, "ovning", "tanke", "Well   done, chair."))
    m("utropstecken", satt("saker", 0, "ovning", "tanke", "Turn past the chair!"))
    m("svenska", satt("saker", 0, "ovning", "tanke", "Vänd förbi stolen."))
    m("steg", satt("saker", 0, "ovning", "steg", "x"))
    m("steg_hopp", satt("saker", 0, "ovning", "steg", "varierat"))
    m("steg_forsta", satt("saker", 1, "ovning", "steg", "halv_fart"))
    m("villkor", satt("saker", 0, "klart_nar", "villkor", "x"))
    m("grans_spann", lambda x: x["saker"][1]["klart_nar"].update(villkor="mellan", grans=1))
    m("grans_tal", satt("saker", 0, "klart_nar", "grans", "x"))
    m("pa", satt("saker", 0, "klart_nar", "pa", "x"))
    m("pass_i_rad", satt("saker", 0, "klart_nar", "pass_i_rad", 3))
    m("last", satt("saker", 0, "klart_nar", "grans", 0))
    m("analysens", satt("saker", 1, "klart_nar", "grans", 99))
    m("block_start", satt("saker", 0, "block", "start", "2026-11-07"))
    m("block_vecka", satt("saker", 0, "block", "vecka", 9))
    m("vecka_bool", satt("saker", 1, "block", "vecka", True))
    m("lista", satt("saker", 0, "foljdfel", "x"))
    m("ingen_kedja", lambda x: x["saker"][0]["foljdfel"].append(tempo))
    m("vag", satt("saker", 0, "foljdfel", 0, "vag", list(reversed(ff["vag"]))))
    m("vald", lambda x: x["saker"][0]["foljdfel"].append(dict(ff, fel=x["saker"][1]["fel"])))
    m("typ", satt("saker", 0, "typ", "x"))
    m("kravs", satt("saker", 0, "typ", "troligen_rorlighet"))
    m("treregeln", satt("saker", 0, "fysik", {"test": "Trail hip internal rotation", "treregeln": [True], "ovning": None}))
    m("treregeln_typ", satt("saker", 0, "fysik", {"test": "Trail hip internal rotation",
                                                  "treregeln": [True, True, True], "ovning": None}))
    m("test", satt("saker", 0, "fysik", {"test": "x", "treregeln": [False, False, False], "ovning": None}))
    m("null", satt("saker", 0, "fysik", {"test": "Trail hip internal rotation", "treregeln": [False, False, False],
                                        "ovning": "Lie on the back."}))
    m("fysik_objekt", satt("saker", 0, "fysik", 1))
    djup = {"x": 1}
    for _ in range(30):
        djup = [djup]
    m("djup_32", satt("extra", djup))
    return ut


def facit_svar(namn: str, historik: dict) -> list[tuple[str, str]]:
    """Svarstexterna för en historik: det giltiga svaret (när en mall finns) och ändringarna
    som ger varje felkod (BESLUT B54). Bara det typiska passet får alla ändringar; de andra
    historikerna ger koderna som kräver sitt minne."""
    katalog, kedjor = KAT.las(), A.las_kedjor()
    enh = analysera_historik(historik, katalog, kedjor)
    nu = _nu(historik)
    u = _huvud(enh, nu)
    d = underlag(enh, nu, historik["att_jobba_pa"], historik["skapad"], katalog, kedjor)
    rapport = "Pass, slag och missen.\n1. …\n\n"
    ut = []
    fil = giltigt(d) if d["mallar"] else None
    if fil:
        ut.append(("giltigt", _svar_text(fil, rapport, "\n\nSäg till om något är oklart.", indrag=1)))
    if namn == "typiskt":
        ut += [("utan_markning", _svar_text(fil, rapport, markning="")),
               ("bara_json", json.dumps(fil, ensure_ascii=False)),
               ("typografiska", _svar_text(fil, rapport).replace('"', "“", 1).replace('"', "”", 1)),
               ("inget_block", "Jag behöver veta missen först."),
               ("trasig_json", rapport + "```json\n{\"format\": \"swinglab-att-jobba-pa/1\", \"saker\": [\n```\n"),
               ("inte_att_jobba_pa", rapport + "```json\n[1]\n```\n"),
               ("for_stort", rapport + "x" * (AJP.MAX_SVAR + 1) + _svar_text(fil)),
               ("djup", rapport + "```json\n" + "[" * 40 + "]" * 40 + "\n```\n"),
               ("djup_33", "```json\n{\"extra\": " + "[" * 32 + "]" * 32 + "}\n```"),
               ("flera_block", _svar_text(dict(fil, saker=[dict(fil["saker"][0], fel="tempo")]), "Utkast:\n",
                                          "\n\nRättat:\n") + _svar_text(fil)),
               ("annat_block_sist", _svar_text(fil, rapport) + "\n```json\n{\"pass\": 1}\n```\n")]
        ut += [(n, x if isinstance(x, str) else _svar_text(x, rapport)) for n, x in mutationer(fil, u)]
    elif namn == "forsta":
        # Ett fel utan gräns och utan baslinje är okänt i första passet (reverse spine har ett
        # band sedan BESLUT B86).
        s = _sak_ur_katalogen(katalog, kedjor, u, "chicken_wing")
        ut.append(("okant_med_flaggade", _svar_text(dict(d["fil"], saker=[s]))))
    elif namn == "byt":
        s = _sak_ur_katalogen(katalog, kedjor, u, "early_extension", ov_id="stol_bakom")
        ut.append(("byt_ovning", _svar_text(dict(d["fil"], saker=[s]))))
    elif namn == "fysik":
        s = _sak_ur_katalogen(katalog, kedjor, u, "early_extension", ov_id="stol_bakom")
        ut.append(("redan_provad", _svar_text(dict(d["fil"], saker=[s]))))
        g = json.loads(json.dumps(fil))
        g["saker"][0].update(fysik=None, typ="teknik")
        ut.append(("fysik_forst", _svar_text(g)))
    elif namn == "klart":
        s = _sak_ur_katalogen(katalog, kedjor, u, "sway_topp", ov_id="kapp_och_fotterna_ihop")
        ut.append(("klar", _svar_text(dict(d["fil"], saker=[s]))))
    return ut


# Texter att leta kodblock i: samma block i Python och Swift (METOD MT12).
KODBLOCK = ["a\n```json\n{1}\n```\nb ```\n2\n``` ```x", "````\nx\n```", "```json {\n```", "```\nöppet",
            "``` \r\n{}\r\n```", "x``\n```\n``` y ```\nz```", "```js`x\n1\n```\n```\n2```", ""]
# Avrundningen som Pythons round(): halvor på det exakta binära talet (METOD MT3).
AVRUNDNING = [["backen_sway_topp", 0.35], ["backen_sway_topp", 0.25], ["backen_sway_topp", -0.25],
              ["tempo", 2.675], ["tempo", 1.005], ["backen_sway_topp", 2.5], ["handens_vinkelfart", 2.5],
              ["handens_vinkelfart", 3.5], ["backen_sway_topp", -0.04]]


def facit_kontext(h: dict) -> tuple[dict, list[dict]]:
    """Passet `nu` och minnet före dess val, som kontrollen av ett svar läser dem."""
    enh = analysera_historik(h)
    nu = _nu(h)
    ctx = H.sammanhang(enh, nu)
    docs = [d for d in h["att_jobba_pa"] if d["pass"] in {u["pass"] for u in ctx if u["huvud"]}]
    return _huvud(enh, nu), H.ovningar_ur(ctx, docs, till=nu, fore=nu)


def facit() -> dict:
    """Facit för Swift: instruktionen, kodblocken, avrundningen, och per påhittad historik
    indata, Pythons text och svaren med Pythons felkoder."""
    katalog, kedjor = KAT.las(), A.las_kedjor()
    ut = {"instruktion": instruktion(), "kodblock": [[k, AJP.kodblock(k)] for k in KODBLOCK],
          "avrundning": [[m, v, A.avrunda(m, v)] for m, v in AVRUNDNING], "historiker": []}
    for namn, h in facit_historiker().items():
        u, ov = facit_kontext(h)
        rad = {"namn": namn, "historik": dict(h, nu=_nu(h)), "text": facit_text(h), "svar": []}
        for snamn, s in facit_svar(namn, h):
            d, fel = AJP.las_svar(s, u, ov, katalog, kedjor)
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
        "public enum ClaudeKallor {",
        "    /// Reglerna ur skillen svinganalys, kortade (avsnitten claude-appen).",
        "    public static let instruktion = " + _raa(instruktion()),
        "",
        "    /// tools/pc/kedjor.json, ordagrant.",
        "    public static let kedjor = " + _raa(A.KEDJOR.read_text(encoding="utf-8").rstrip("\n")),
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
