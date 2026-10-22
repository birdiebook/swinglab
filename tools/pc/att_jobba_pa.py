"""`att_jobba_pa.json`: det Claude valt, tillbaka till telefonen (S2_SPEC §8.5,
docs/FORMAT.md "Att jobba på").

    python3 tools/pc/att_jobba_pa.py <fil> [--analys analys.json]

Kontrollen håller skillens regler (`.claude/skills/svinganalys/SKILL.md`) i kod:
1–3 saker, bara fel ur katalogen, följdfel bara enligt kedjorna och aldrig som
egen sak, tidigt i svingen före sent, "troligen rörlighet" bara enligt
treregeln, och inga värdeord. Med analysen kontrolleras också att varje tal är
analysens (BESLUT B2): Claude skriver av, mäter aldrig själv. METOD MT8
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
MAX_TANKE = 60             # METOD MT8: tecken i tanken
MAX_OVNING = 300           # METOD MT8: tecken i övningen
MAX_FYSIK = 200            # METOD MT8: tecken i rörlighetsövningen
VILLKOR = (">=", "<=", "mellan")
TYPER = ("teknik", "teknik_kroppen_gor_det_svart", "troligen_rorlighet")
# Treregeln (research 3 §5): [syns i full sving, ett kopplat test fallerar,
# går inte heller långsamt utan klubba] → typen. METOD MT5
TRE_REGELN = {(True, True, True): "troligen_rorlighet", (True, True, False): "teknik_kroppen_gor_det_svart"}
# Värdeord som appens text aldrig bär (BESLUT B13, regel 4). METOD MT8
VARDEORD = ("bättre", "sämre", "bra", "dålig", "dåligt", "dåliga", "bäst", "sämst", "perfekt", "perfekta",
            "utmärkt", "fantastisk", "fantastiskt", "snyggt", "fint", "tyvärr", "grattis", "bravo", "superb",
            "underbar", "jättebra", "felfri", "felfritt")
_VARDEORD = re.compile(r"(?<![\wåäö])(" + "|".join(VARDEORD) + r")(?![\wåäö])", re.I)
PASS_ID = re.compile(r"^\d{8}-\d{6}$")


def _text(v, falt: str, maxlen: int, fel: list[str]) -> None:
    if not isinstance(v, str) or not v.strip():
        fel.append(f"{falt}: ska vara en text")
        return
    if len(v) > maxlen:
        fel.append(f"{falt}: högst {maxlen} tecken")
    if _VARDEORD.search(v):
        fel.append(f"{falt}: värdeord ({_VARDEORD.search(v).group(0).lower()}) hör inte hemma i appens text")
    if "!" in v:
        fel.append(f"{falt}: inga utropstecken")


def _tal(v) -> bool:
    return not isinstance(v, bool) and isinstance(v, (int, float))


def kontrollera(d, katalog: dict | None = None, kedjor: dict | None = None, analys: dict | None = None) -> list[str]:
    """Alla fel i filen. Felen nämner fältet, aldrig värdet."""
    katalog = katalog or KAT.las()
    kedjor = kedjor or A.las_kedjor()
    K = {f["id"]: f for f in katalog["fel"]}
    fas = {f: i for i, f in enumerate(kedjor["faser"])}
    fel: list[str] = []
    if not isinstance(d, dict):
        return ["filen: ska vara ett JSON-objekt"]
    if d.get("format") != FORMAT:
        fel.append(f"format: ska vara {FORMAT}")
    if not isinstance(d.get("pass"), str) or not PASS_ID.match(d["pass"]):
        fel.append("pass: ska vara yyyyMMdd-HHmmss")
    try:
        dt.datetime.fromisoformat(d.get("skapad"))
    except (TypeError, ValueError):
        fel.append("skapad: ska vara en tid i ISO 8601")
    saker = d.get("saker")
    if not isinstance(saker, list) or not 1 <= len(saker) <= MAX_SAKER:
        return fel + [f"saker: ska vara 1–{MAX_SAKER} st"]
    bed = {b["id"]: b for b in analys["bedomning"]} if analys else {}
    if analys and d.get("pass") != analys["pass"]:
        fel.append("pass: är inte analysens pass")
    valda = [s.get("fel") for s in saker if isinstance(s, dict)]
    if len(set(valda)) != len(valda):
        fel.append("saker: samma fel två gånger")
    forra_fas = -1
    for i, s in enumerate(saker):
        p = f"saker[{i}]"
        if not isinstance(s, dict):
            fel.append(f"{p}: ska vara ett objekt")
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
        # Tidigt i svingen före sent (research 3 (a) 2).
        f_i = fas.get(k["fas"], len(fas))
        if f_i < forra_fas:
            fel.append(f"{p}: sker tidigare i svingen än saken före; tidigt går först")
        forra_fas = max(forra_fas, f_i)
        # Ett följdfel av en annan vald sak är ingen egen sak.
        fore = A.orsaker(kedjor, fid)
        if any(o in valda for o in fore):
            fel.append(f"{p}.fel: är följdfel av en annan vald sak och får ingen egen övning")
        if s.get("spann") != k["gront"]:
            fel.append(f"{p}.spann: ska vara katalogens gröna spann")
        if s.get("markning") not in ("B10", "egen", None):
            fel.append(f"{p}.markning: ska vara B10, egen eller null")
        if s.get("nu") is not None and not _tal(s["nu"]):
            fel.append(f"{p}.nu: ska vara ett tal eller null")
        # Övningen.
        o = s.get("ovning")
        if not isinstance(o, dict):
            fel.append(f"{p}.ovning: ska vara ett objekt")
        else:
            _text(o.get("text"), f"{p}.ovning.text", MAX_OVNING, fel)
            _text(o.get("tanke"), f"{p}.ovning.tanke", MAX_TANKE, fel)
            if o.get("kalla") not in ("katalog", "research3"):
                fel.append(f"{p}.ovning.kalla: ska vara katalog eller research3")
            elif o["kalla"] == "katalog" and o.get("text") != k["ovning"]:
                fel.append(f"{p}.ovning.text: ska vara katalogens när kalla är katalog")
        # "Klart när" som ett villkor i tal på första serien.
        kn = s.get("klart_nar")
        if not isinstance(kn, dict):
            fel.append(f"{p}.klart_nar: ska vara ett objekt")
        else:
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
            if isinstance(kn.get("pass_i_rad"), bool) or not isinstance(kn.get("pass_i_rad"), int) \
                    or kn["pass_i_rad"] < 1:
                fel.append(f"{p}.klart_nar.pass_i_rad: ska vara ett heltal ≥ 1")
        # Följdfelen: mäts, övas inte, och bara enligt kedjorna.
        ff = s.get("foljdfel")
        if not isinstance(ff, list):
            fel.append(f"{p}.foljdfel: ska vara en lista")
        else:
            for j, f in enumerate(ff):
                if f not in K:
                    fel.append(f"{p}.foljdfel[{j}]: finns inte i katalogen")
                elif fid not in A.orsaker(kedjor, f):
                    fel.append(f"{p}.foljdfel[{j}]: ingen kedja i kedjor.json från saken")
                elif f in valda:
                    fel.append(f"{p}.foljdfel[{j}]: är också en vald sak")
        # Fysik före teknik bara enligt treregeln.
        typ, fy = s.get("typ"), s.get("fysik")
        if typ not in TYPER:
            fel.append(f"{p}.typ: ska vara en av {', '.join(TYPER)}")
        elif fy is None:
            if typ != "teknik":
                fel.append(f"{p}.fysik: krävs för typen")
        elif not isinstance(fy, dict):
            fel.append(f"{p}.fysik: ska vara ett objekt eller null")
        else:
            tre = fy.get("treregeln")
            if not (isinstance(tre, list) and len(tre) == 3 and all(isinstance(x, bool) for x in tre)):
                fel.append(f"{p}.fysik.treregeln: ska vara tre true/false")
            elif TRE_REGELN.get(tuple(tre), "teknik") != typ:
                fel.append(f"{p}.typ: följer inte treregeln")
            if fy.get("test") not in [x["test"] for x in kedjor["fysik"] if x["fel"] == fid]:
                fel.append(f"{p}.fysik.test: inget test i kedjor.json för felet")
            if typ != "teknik":
                _text(fy.get("ovning"), f"{p}.fysik.ovning", MAX_FYSIK, fel)
        # Mot analysen: talen är analysens (BESLUT B2).
        if analys:
            b = bed.get(fid)
            if b is None:
                fel.append(f"{p}.fel: saknas i analysen")
                continue
            bkn = b.get("klart_nar")
            if b.get("status") not in ("gul", "rod", "okand"):
                fel.append(f"{p}.fel: är inte flaggat i analysen")
            if s.get("nu") != b.get("visat"):
                fel.append(f"{p}.nu: ska vara analysens tal (visat)")
            if s.get("markning") != (bkn or {}).get("markning"):
                fel.append(f"{p}.markning: ska vara analysens")
            if isinstance(kn, dict):
                if bkn is None:
                    fel.append(f"{p}.klart_nar: analysen har inget förslag för felet")
                elif (kn.get("villkor"), kn.get("grans")) != (bkn.get("villkor"), bkn.get("grans")):
                    fel.append(f"{p}.klart_nar: ska vara analysens förslag")
    return fel


def las(sokvag, analys_fil=None) -> dict:
    d = json.loads(Path(sokvag).read_text(encoding="utf-8"))
    analys = json.loads(Path(analys_fil).read_text(encoding="utf-8")) if analys_fil else None
    f = kontrollera(d, analys=analys)
    if f:
        raise ValueError("; ".join(f))
    return d


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Kontrollera en att_jobba_pa.json.")
    ap.add_argument("fil")
    ap.add_argument("--analys", help="analys.json för passet: talen ska vara dess")
    a = ap.parse_args(argv)
    try:
        d = json.loads(Path(a.fil).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        print(f"{a.fil}: går inte att läsa som JSON ({type(e).__name__})")
        return 1
    analys = json.loads(Path(a.analys).read_text(encoding="utf-8")) if a.analys else None
    fel = kontrollera(d, analys=analys)
    print("\n".join(f"{a.fil}: {f}" for f in fel) if fel else f"{a.fil}: OK ({len(d['saker'])} saker)")
    return 1 if fel else 0


if __name__ == "__main__":
    sys.exit(main())
