"""`att_jobba_pa.json`: det Claude valt, tillbaka till telefonen (S2_SPEC §8.5,
docs/FORMAT.md "Att jobba på").

    python3 tools/pc/att_jobba_pa.py <fil> --analys <analys.json> [--historik data/historik]

Kontrollen håller skillens regler (`.claude/skills/svinganalys/SKILL.md`) i kod,
och körs alltid mot passets analys och minnet före passet:

- formen är stängd (inga okända nycklar), 1–3 saker i svingens ordning;
- bara aktiva fel ur katalogen som analysen flaggat, aldrig ett följdfel, och
  ett okänt fel bara när inget är flaggat;
- varje tal är analysens (BESLUT B2), och "klart när" flyttar sig inte så länge
  samma övning fortsätter;
- följdfel bara enligt kedjorna, övningar bara ur katalogen eller kedjor.json,
  "troligen rörlighet" bara enligt treregeln;
- fritexten utan siffror, värdeord och utropstecken.

METOD MT5, MT6, MT8
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "pc"

from . import analys as A  # noqa: E402
from . import katalog as KAT  # noqa: E402

FORMAT = "swinglab-att-jobba-pa/1"
MAX_SAKER = 3              # METOD MT6: 1–3 saker (research 3 (a) 5)
PASS_I_RAD = 2             # METOD MT5: "klart när" hålls två pass i rad
MAX_TANKE = 60             # METOD MT8: tecken i tanken
MAX_FYSIK = 200            # METOD MT8: tecken i rörlighetsövningen
VILLKOR = (">=", "<=", "mellan")
TYPER = ("teknik", "teknik_kroppen_gor_det_svart", "troligen_rorlighet")
# Stegen inom en övning (research 3 §4 förslag 2), i ordning. METOD MT10
STEG = ("langsamt_med_foremal", "halv_fart", "full_fart", "varierat")
# Treregeln (research 3 §5): [syns i full sving, ett kopplat test fallerar,
# går inte heller långsamt utan klubba] → typen. METOD MT5
TRE_REGELN = {(True, True, True): "troligen_rorlighet", (True, True, False): "teknik_kroppen_gor_det_svart"}
# Värdeord på ordstam (BESLUT B13, regel 4). Ett ord fälls om det är `bra` eller
# börjar på en stam, utom undantagen. METOD MT8
VARDEORD = ("bra",)
STAMMAR = ("bäst", "bättr", "sämr", "sämst", "fin", "duktig", "topp", "dålig", "perfekt", "utmärk", "fantastisk",
           "snygg", "grym", "super", "underbar", "jättebra", "felfri", "klockren", "suverän", "lysande", "imponer",
           "beröm", "grattis", "bravo", "tyvärr", "tråkig", "kanon", "härlig", "strålande", "utmärkt")
UNDANTAG = ("finish", "finn", "fing", "final")      # finishen, finns, fingrarna: inga värdeord
# "toppen" är svingens fas efter en preposition ("i toppen", "till toppen"), eller
# en plats före "av" ("toppen av kepsen").
FAS_FORE = ("i", "till", "vid", "från", "mot", "före", "efter", "nära", "upp")
PASS_ID = re.compile(r"^\d{8}-\d{6}$")
_ORD = re.compile(r"[a-zåäöéü]+", re.I)

TOPP = ("format", "pass", "skapad", "saker")
SAK = ("ordning", "fel", "namn", "vy", "matt", "enhet", "nu", "spann", "markning", "ovning", "klart_nar",
       "foljdfel", "typ", "fysik", "block")
OVNING = ("text", "tanke", "kalla", "steg")
KLART = ("villkor", "grans", "pa", "pass_i_rad")
FOLJD = ("fel", "namn", "vag", "nu", "enhet")
FYSIK = ("test", "treregeln", "ovning")
BLOCK = ("start", "vecka")


def vardeord(text: str) -> str | None:
    """Det första värdeordet i texten, eller None."""
    ord_ = [m.group(0).lower() for m in _ORD.finditer(text)]
    for i, o in enumerate(ord_):
        if o.startswith(UNDANTAG):
            continue
        if o in ("toppen", "toppens") and ((i > 0 and ord_[i - 1] in FAS_FORE)
                                           or (i + 1 < len(ord_) and ord_[i + 1] == "av")):
            continue
        if o in VARDEORD or o.startswith(STAMMAR):
            return o
    return None


def _fritext(v, falt: str, maxlen: int, fel: list[str]) -> None:
    if not isinstance(v, str) or not v.strip():
        fel.append(f"{falt}: ska vara en text")
        return
    if len(v) > maxlen:
        fel.append(f"{falt}: högst {maxlen} tecken")
    if re.search(r"\d", v):
        fel.append(f"{falt}: inga siffror i fritext; tal hör hemma i klart_nar")
    o = vardeord(v)
    if o:
        fel.append(f"{falt}: värdeord ({o}) hör inte hemma i appens text")
    if "!" in v:
        fel.append(f"{falt}: inga utropstecken")


def _nycklar(d, tillatna: tuple, falt: str, fel: list[str]) -> bool:
    if not isinstance(d, dict):
        fel.append(f"{falt}: ska vara ett objekt")
        return False
    for k in d:
        if k not in tillatna:
            fel.append(f"{falt}: okänd nyckel {k}")
    for k in tillatna:
        if k not in d:
            fel.append(f"{falt}: {k} saknas")
    return True


def _tal(v) -> bool:
    return not isinstance(v, bool) and isinstance(v, (int, float))


def _datum(pass_id: str) -> dt.date:
    return dt.date(int(pass_id[:4]), int(pass_id[4:6]), int(pass_id[6:8]))


def kontrollera(d, analys: dict, ovningar: list[dict] | None = None, katalog: dict | None = None,
                kedjor: dict | None = None) -> list[str]:
    """Alla fel i filen, mot passets analys och minnets övningar före passet
    (historik.ovningar(…, fore=passet)). Felen nämner fältet, aldrig värdet."""
    katalog = katalog or KAT.las()
    kedjor = kedjor or A.las_kedjor()
    K = {f["id"]: f for f in katalog["fel"]}
    fas = {f: i for i, f in enumerate(kedjor["faser"])}
    fel: list[str] = []
    if not _nycklar(d, TOPP, "filen", fel):
        return fel
    if d.get("format") != FORMAT:
        fel.append(f"format: ska vara {FORMAT}")
    pass_ok = isinstance(d.get("pass"), str) and bool(PASS_ID.match(d["pass"]))
    if not pass_ok:
        fel.append("pass: ska vara yyyyMMdd-HHmmss")
    elif d["pass"] != analys.get("pass"):
        fel.append("pass: är inte analysens pass")
    try:
        dt.datetime.fromisoformat(d.get("skapad"))
    except (TypeError, ValueError):
        fel.append("skapad: ska vara en tid i ISO 8601")
    saker = d.get("saker")
    if not isinstance(saker, list) or not 1 <= len(saker) <= MAX_SAKER:
        return fel + [f"saker: ska vara 1–{MAX_SAKER} st"]
    bed = {b["id"]: b for b in analys.get("bedomning", [])}
    kand = {k["fel"]: k for k in analys.get("kandidater", [])}
    minne = {o["fel"]: o for o in (ovningar or []) if o.get("lage") != "avslutad"}
    valda = [s.get("fel") for s in saker if isinstance(s, dict)]
    if len(set(valda)) != len(valda):
        fel.append("saker: samma fel två gånger")
    forra_fas = -1
    for i, s in enumerate(saker):
        p = f"saker[{i}]"
        if not _nycklar(s, SAK, p, fel):
            continue
        if s.get("ordning") != i + 1:
            fel.append(f"{p}.ordning: ska vara {i + 1}")
        fid = s.get("fel")
        k = K.get(fid)
        if k is None:
            fel.append(f"{p}.fel: finns inte i katalogen")
            continue
        if not k["aktiv"]:
            fel.append(f"{p}.fel: är avstängt i katalogen")
        for f in ("namn", "vy", "matt"):
            if s.get(f) != k[f]:
                fel.append(f"{p}.{f}: ska vara katalogens")
        if s.get("enhet") != A.enhet(k["matt"]):
            fel.append(f"{p}.enhet: ska vara måttets")
        if s.get("spann") != k["gront"]:
            fel.append(f"{p}.spann: ska vara katalogens gröna spann")
        # Tidigt i svingen före sent (research 3 (a) 2).
        f_i = fas.get(k["fas"], len(fas))
        if f_i < forra_fas:
            fel.append(f"{p}: sker tidigare i svingen än saken före; tidigt går först")
        forra_fas = max(forra_fas, f_i)
        if any(o in valda for o in A.orsaker(kedjor, fid)):
            fel.append(f"{p}.fel: är följdfel av en annan vald sak och får ingen egen övning")

        # Mot analysen: flaggat, inget följdfel, och analysens tal (BESLUT B2).
        b = bed.get(fid)
        if b is None:
            fel.append(f"{p}.fel: saknas i analysen")
            continue
        if b.get("status") in ("gul", "rod"):
            if kand.get(fid, {}).get("foljdfel"):
                fel.append(f"{p}.fel: är följdfel av ett flaggat fel i analysen; grundorsaken övas")
        elif b.get("status") == "okand":
            if kand:
                fel.append(f"{p}.fel: okänt fel får väljas bara när inget är flaggat")
        else:
            fel.append(f"{p}.fel: är inte flaggat i analysen")
        if s.get("nu") != b.get("visat"):
            fel.append(f"{p}.nu: ska vara analysens tal (visat)")

        # Minnet: fortsätter samma övning, eller är den ny?
        o = minne.get(fid)
        ov = s.get("ovning")
        text = ov.get("text") if isinstance(ov, dict) else None
        fortsatter = o is not None and o["ovning"] == text
        if fortsatter and o["lage"] == "klart":
            fel.append(f"{p}: övningen är klar enligt minnet; släpp saken")
        if fortsatter and o["lage"] == "byt_ovning":
            fel.append(f"{p}.ovning: minnet säger byt övning")
        if o is not None and text in o.get("forra_ovningar", []):
            fel.append(f"{p}.ovning.text: övningen är redan provad för felet")

        # Övningen: ur katalogen eller kedjor.json, aldrig fritext.
        if _nycklar(ov, OVNING, f"{p}.ovning", fel):
            if ov.get("kalla") == "katalog":
                if text != k["ovning"]:
                    fel.append(f"{p}.ovning.text: ska vara katalogens när kalla är katalog")
            elif ov.get("kalla") == "research3":
                if text not in [x["text"] for x in kedjor["ovningar"] if x["fel"] == fid]:
                    fel.append(f"{p}.ovning.text: ska vara en av felets övningar i kedjor.json")
            else:
                fel.append(f"{p}.ovning.kalla: ska vara katalog eller research3")
            _fritext(ov.get("tanke"), f"{p}.ovning.tanke", MAX_TANKE, fel)
            steg = ov.get("steg")
            if steg not in STEG:
                fel.append(f"{p}.ovning.steg: ska vara ett av {', '.join(STEG)}")
            elif fortsatter and o.get("steg") in STEG:
                if not 0 <= STEG.index(steg) - STEG.index(o["steg"]) <= 1:
                    fel.append(f"{p}.ovning.steg: samma steg eller nästa, inget hopp")
            elif steg != STEG[0]:
                fel.append(f"{p}.ovning.steg: en ny övning börjar på {STEG[0]}")

        # "Klart när": analysens förslag för en ny övning, minnets när den fortsätter.
        kn = s.get("klart_nar")
        if _nycklar(kn, KLART, f"{p}.klart_nar", fel):
            if kn.get("villkor") not in VILLKOR:
                fel.append(f"{p}.klart_nar.villkor: ska vara >=, <= eller mellan")
            elif kn["villkor"] == "mellan":
                g = kn.get("grans")
                if not (isinstance(g, list) and len(g) == 2 and all(_tal(x) for x in g) and g[0] <= g[1]):
                    fel.append(f"{p}.klart_nar.grans: ska vara [min, max]")
            elif not _tal(kn.get("grans")):
                fel.append(f"{p}.klart_nar.grans: ska vara ett tal")
            if kn.get("pa") != "forsta_serien":
                fel.append(f"{p}.klart_nar.pa: ska vara forsta_serien")
            if kn.get("pass_i_rad") != PASS_I_RAD or isinstance(kn.get("pass_i_rad"), bool):
                fel.append(f"{p}.klart_nar.pass_i_rad: ska vara {PASS_I_RAD}")
            if fortsatter:
                ok = o["klart_nar"]
                if (kn.get("villkor"), kn.get("grans")) != (ok["villkor"], ok["grans"]):
                    fel.append(f"{p}.klart_nar: ska vara samma som när övningen valdes")
                if s.get("markning") != o.get("markning"):
                    fel.append(f"{p}.markning: ska vara samma som när övningen valdes")
            else:
                bkn = b.get("klart_nar")
                if bkn is None:
                    fel.append(f"{p}.klart_nar: analysen har inget förslag för felet")
                else:
                    if (kn.get("villkor"), kn.get("grans")) != (bkn.get("villkor"), bkn.get("grans")):
                        fel.append(f"{p}.klart_nar: ska vara analysens förslag")
                    if s.get("markning") != bkn.get("markning"):
                        fel.append(f"{p}.markning: ska vara analysens")

        # Blocket: från första gången felet valdes, i veckor.
        blk = s.get("block")
        if _nycklar(blk, BLOCK, f"{p}.block", fel) and pass_ok:
            start = _datum(o["fel_start"]) if o is not None else _datum(d["pass"])
            if blk.get("start") != start.isoformat():
                fel.append(f"{p}.block.start: ska vara dagen då felet först valdes")
            if blk.get("vecka") != (_datum(d["pass"]) - start).days // 7 + 1:
                fel.append(f"{p}.block.vecka: ska vara veckan sedan blockets start")

        # Följdfelen: mäts, övas inte, och bara enligt kedjorna (flera led går).
        ff = s.get("foljdfel")
        if not isinstance(ff, list):
            fel.append(f"{p}.foljdfel: ska vara en lista")
        else:
            for j, f in enumerate(ff):
                q = f"{p}.foljdfel[{j}]"
                if not _nycklar(f, FOLJD, q, fel):
                    continue
                ffid = f.get("fel")
                if ffid not in K:
                    fel.append(f"{q}.fel: finns inte i katalogen")
                    continue
                vag = A.orsaker(kedjor, ffid).get(fid)
                if vag is None:
                    fel.append(f"{q}.fel: ingen kedja i kedjor.json från saken")
                elif f.get("vag") != vag:
                    fel.append(f"{q}.vag: ska vara kedjans väg från saken")
                if ffid in valda:
                    fel.append(f"{q}.fel: är också en vald sak")
                if f.get("namn") != K[ffid]["namn"]:
                    fel.append(f"{q}.namn: ska vara katalogens")
                if f.get("enhet") != A.enhet(K[ffid]["matt"]):
                    fel.append(f"{q}.enhet: ska vara måttets")
                if f.get("nu") != bed.get(ffid, {}).get("visat"):
                    fel.append(f"{q}.nu: ska vara analysens tal (visat)")

        # Fysik före teknik bara enligt treregeln.
        typ, fy = s.get("typ"), s.get("fysik")
        if o is not None and o["lage"] == "fysik" and fy is None:
            fel.append(f"{p}.fysik: minnet säger fysik; pröva treregeln med Johannes först")
        if typ not in TYPER:
            fel.append(f"{p}.typ: ska vara en av {', '.join(TYPER)}")
        elif fy is None:
            if typ != "teknik":
                fel.append(f"{p}.fysik: krävs för typen")
        elif _nycklar(fy, FYSIK, f"{p}.fysik", fel):
            tre = fy.get("treregeln")
            if not (isinstance(tre, list) and len(tre) == 3 and all(isinstance(x, bool) for x in tre)):
                fel.append(f"{p}.fysik.treregeln: ska vara tre true/false")
            elif TRE_REGELN.get(tuple(tre), "teknik") != typ:
                fel.append(f"{p}.typ: följer inte treregeln")
            if fy.get("test") not in [x["test"] for x in kedjor["fysik"] if x["fel"] == fid]:
                fel.append(f"{p}.fysik.test: inget test i kedjor.json för felet")
            if typ == "teknik":
                if fy.get("ovning") is not None:
                    fel.append(f"{p}.fysik.ovning: ska vara null för teknik")
            else:
                _fritext(fy.get("ovning"), f"{p}.fysik.ovning", MAX_FYSIK, fel)
    return fel


def main(argv=None) -> int:
    from . import historik as H

    ap = argparse.ArgumentParser(description="Kontrollera en att_jobba_pa.json mot passets analys och minnet.")
    ap.add_argument("fil")
    ap.add_argument("--analys", required=True, help="passets analys.json: talen ska vara dess")
    ap.add_argument("--historik", default=str(H.ROT), help="historikens mapp (minnet före passet)")
    a = ap.parse_args(argv)
    try:
        d = json.loads(Path(a.fil).read_text(encoding="utf-8"))
        analys = json.loads(Path(a.analys).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        print(f"går inte att läsa som JSON ({type(e).__name__})")
        return 1
    pass_id = d.get("pass") if isinstance(d, dict) else None
    ov = H.ovningar(Path(a.historik), till=pass_id, fore=pass_id) if isinstance(pass_id, str) else []
    fel = kontrollera(d, analys, ov)
    print("\n".join(f"{a.fil}: {f}" for f in fel) if fel else f"{a.fil}: OK ({len(d['saker'])} saker)")
    return 1 if fel else 0


if __name__ == "__main__":
    sys.exit(main())
