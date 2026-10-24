"""`att_jobba_pa.json`: det Claude valt, tillbaka till telefonen (S2_SPEC §8.5,
docs/FORMAT.md "Att jobba på").

    python3 tools/pc/att_jobba_pa.py <fil> --analys <analys.json> [--historik data/historik]
    python3 tools/pc/att_jobba_pa.py --ur-text <svar.txt> --analys <analys.json> [--ut <fil>]

`--ur-text` läser svaret från Claude-appen (S5b): filen tas ur det sista kodblocket och
kontrolleras likadant, så att samma svarstexter prövas här och på telefonen (BESLUT B54).

Kontrollen håller skillens regler (`.claude/skills/svinganalys/SKILL.md`) i kod,
och körs alltid mot passets analys och minnet före passet:

- formen är stängd (inga okända nycklar), 1–3 saker i svingens ordning;
- bara aktiva fel ur katalogen som analysen flaggat, aldrig ett följdfel, och
  ett okänt fel bara när inget är flaggat;
- varje tal är analysens (BESLUT B2), och "klart när" flyttar sig inte så länge
  samma övning fortsätter;
- följdfel bara enligt kedjorna, övningar bara ur katalogen eller kedjor.json,
  "troligen rörlighet" bara enligt treregeln;
- fritexten på engelska (BESLUT B30), utan siffror, värdeord och utropstecken.

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
# Värdeord på ordstam (BESLUT B13, regel 4), på engelska som appen (BESLUT B30).
# Ett ord fälls om det står i VARDEORD eller börjar på en stam, utom undantagen.
# METOD MT8
VARDEORD = ("ok", "okay", "wow", "yay", "bravo", "ideal", "ideally")
STAMMAR = ("good", "better", "best", "worse", "worst", "bad", "poor", "great", "perfect", "nice", "excellen",
           "super", "cool", "neat", "sweet", "kudos", "nail", "crush", "pure", "crisp", "boring", "fine",
           "awesome", "amazing", "fantastic", "terrific", "terribl", "horribl", "awful", "brillian", "superb",
           "wonderful", "outstanding", "impressiv", "beautiful", "lovely", "gorgeous", "flawless", "congrat",
           "unfortunat", "sloppy", "ugly", "incredibl", "remarkabl", "magnificent", "splendid", "marvel",
           "stunning", "spectacular", "fabulous", "solid", "mistake", "wrong")
# Ord som börjar på en stam utan att vara värdeord. "strong" och "weak" saknas med
# flit: ett starkt eller svagt grepp är golfens ord för greppet, inget omdöme.
UNDANTAG = ("badge", "badminton", "bestow", "supinat", "coolin")
# Fraser som är värdeord fast orden var för sig inte är det.
FRASER = re.compile(r"\bwell\s+done\b", re.I | re.A)
# Fritexten är engelska (BESLUT B30): svenska tecken fälls.
SVENSKA = re.compile(r"[åäöÅÄÖ]")
PASS_ID = re.compile(r"\d{8}-\d{6}", re.A)          # med fullmatch
_ORD = re.compile(r"[a-zA-ZåäöéüÅÄÖÉÜ]+")

TOPP = ("format", "pass", "skapad", "saker")
SAK = ("ordning", "fel", "namn", "vy", "matt", "enhet", "nu", "spann", "markning", "ovning", "klart_nar",
       "foljdfel", "typ", "fysik", "block")
OVNING = ("id", "text", "tanke", "kalla", "steg")
KLART = ("villkor", "grans", "pa", "pass_i_rad")
FOLJD = ("fel", "namn", "vag", "nu", "enhet")
FYSIK = ("test", "treregeln", "ovning")
BLOCK = ("start", "vecka")


class Kontrollfel(str):
    """Ett fel i kontrollen: texten som PC:n skriver, och koden (`falt`, `kod`) som telefonen
    visar på engelska och som Python och Swift jämförs på (`ClaudeSvar`, BESLUT B54). Varken
    texten eller koden bär ett värde ur filen, bara fältet (CLAUDE.md, Dataregeln)."""
    falt: str
    kod: str

    def __new__(cls, text: str, falt: str, kod: str):
        s = super().__new__(cls, text)
        s.falt, s.kod = falt, kod
        return s


def _F(falt: str, text: str, kod: str, kod_falt: str | None = None) -> Kontrollfel:
    return Kontrollfel(f"{falt}: {text}", kod_falt if kod_falt is not None else falt, kod)


def koder(fel: list) -> list[list[str]]:
    """Felen som [fält, kod], den form Swift och Python jämförs på."""
    return [[f.falt, f.kod] for f in fel]


def _sok(falt: str, nyckel: str) -> str:
    """Sökvägen till en nyckel: "kommentar" i filen, "saker[0].extra" i en sak."""
    return nyckel if falt == "filen" else f"{falt}.{nyckel}"


def vardeord(text: str) -> str | None:
    """Det första värdeordet i texten, eller None."""
    fras = FRASER.search(text)
    if fras:
        return fras.group(0).lower()
    ord_ = [m.group(0).lower() for m in _ORD.finditer(text)]
    for o in ord_:
        if o.startswith(UNDANTAG):
            continue
        if o in VARDEORD or o.startswith(STAMMAR):
            return o
    return None


def _fritext(v, falt: str, maxlen: int, fel: list) -> None:
    if not isinstance(v, str) or not v.strip():
        fel.append(_F(falt, "ska vara en text", "text"))
        return
    if len(v) > maxlen:
        fel.append(_F(falt, f"högst {maxlen} tecken", "for_lang"))
    if re.search(r"\d", v, re.A):
        fel.append(_F(falt, "inga siffror i fritext; tal hör hemma i klart_nar", "siffror"))
    if vardeord(v):
        # Ordet står inte i felet: felet nämner fältet, aldrig värdet (Dataregeln).
        fel.append(_F(falt, "värdeord hör inte hemma i appens text", "vardeord"))
    if "!" in v:
        fel.append(_F(falt, "inga utropstecken", "utropstecken"))
    if SVENSKA.search(v):
        fel.append(_F(falt, "på engelska, som allt i appen (BESLUT B30)", "svenska"))


def _nycklar(d, tillatna: tuple, falt: str, fel: list) -> bool:
    if not isinstance(d, dict):
        fel.append(_F(falt, "ska vara ett objekt", "objekt"))
        return False
    for k in d:
        if k not in tillatna:
            fel.append(_F(falt, f"okänd nyckel {k}", "okand_nyckel", _sok(falt, k)))
    for k in tillatna:
        if k not in d:
            fel.append(_F(falt, f"{k} saknas", "saknas", _sok(falt, k)))
    return True


def _lika(a, b) -> bool:
    """Pythons == utan att true och false räknas som 1 och 0 (BESLUT B54): samma regel som
    `JSONVarde.lika` i Swift."""
    if isinstance(a, bool) or isinstance(b, bool):
        return isinstance(a, bool) and isinstance(b, bool) and a == b
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(_lika(x, y) for x, y in zip(a, b))
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(_lika(a[k], b[k]) for k in a)
    if isinstance(a, (list, dict)) or isinstance(b, (list, dict)):
        return False
    return a == b


def pass_form(v) -> bool:
    """Ett pass-id: yyyyMMdd-HHmmss med en dag som finns."""
    if not isinstance(v, str) or not PASS_ID.fullmatch(v):
        return False
    try:
        _datum(v)
    except ValueError:
        return False
    return True


def _tal(v) -> bool:
    return not isinstance(v, bool) and isinstance(v, (int, float))


def _datum(pass_id: str) -> dt.date:
    return dt.date(int(pass_id[:4]), int(pass_id[4:6]), int(pass_id[6:8]))


def kontrollera(d, analys: dict, ovningar: list[dict] | None = None, katalog: dict | None = None,
                kedjor: dict | None = None) -> list[Kontrollfel]:
    """Alla fel i filen, mot passets analys och minnets övningar före passet
    (historik.ovningar(…, fore=passet)). Felen nämner fältet, aldrig värdet, och bär en
    kod (`koder`) som telefonen kontrollerar likadant (BESLUT B54)."""
    katalog = katalog or KAT.las()
    kedjor = kedjor or A.las_kedjor()
    K = {f["id"]: f for f in katalog["fel"]}
    fas = {f: i for i, f in enumerate(kedjor["faser"])}
    fel: list[Kontrollfel] = []
    if not _nycklar(d, TOPP, "filen", fel):
        return fel
    if not _lika(d.get("format"), FORMAT):
        fel.append(_F("format", f"ska vara {FORMAT}", "format"))
    pass_ok = pass_form(d.get("pass"))
    if not pass_ok:
        fel.append(_F("pass", "ska vara yyyyMMdd-HHmmss", "pass_form"))
    elif d["pass"] != analys.get("pass"):
        fel.append(_F("pass", "är inte analysens pass", "inte_analysens"))
    if not skapad_ok(d.get("skapad")):
        fel.append(_F("skapad", "ska vara en tid i ISO 8601", "iso"))
    saker = d.get("saker")
    if not isinstance(saker, list) or not 1 <= len(saker) <= MAX_SAKER:
        return fel + [_F("saker", f"ska vara 1–{MAX_SAKER} st", "antal")]
    bed = {b["id"]: b for b in analys.get("bedomning", [])}
    kand = {k["fel"]: k for k in analys.get("kandidater", [])}
    minne = {o["fel"]: o for o in (ovningar or []) if o.get("lage") != "avslutad"}
    valda = [s.get("fel") for s in saker if isinstance(s, dict)]
    if len(set(map(_nyckel, valda))) != len(valda):
        fel.append(_F("saker", "samma fel två gånger", "dubblett"))
    forra_fas = -1
    for i, s in enumerate(saker):
        p = f"saker[{i}]"
        if not _nycklar(s, SAK, p, fel):
            continue
        if not _lika(s.get("ordning"), i + 1):
            fel.append(_F(f"{p}.ordning", f"ska vara {i + 1}", "ordning"))
        fid = s.get("fel")
        k = K.get(fid) if isinstance(fid, str) else None
        if k is None:
            fel.append(_F(f"{p}.fel", "finns inte i katalogen", "ej_i_katalogen"))
            continue
        if not k["aktiv"]:
            fel.append(_F(f"{p}.fel", "är avstängt i katalogen", "avstangt"))
        for f in ("namn", "vy", "matt"):
            if not _lika(s.get(f), k[f]):
                fel.append(_F(f"{p}.{f}", "ska vara katalogens", "katalogens"))
        if not _lika(s.get("enhet"), A.enhet(k["matt"])):
            fel.append(_F(f"{p}.enhet", "ska vara måttets", "mattets"))
        if not _lika(s.get("spann"), k["gront"]):
            fel.append(_F(f"{p}.spann", "ska vara katalogens gröna spann", "katalogens"))
        # Tidigt i svingen före sent (research 3 (a) 2).
        f_i = fas.get(k["fas"], len(fas))
        if f_i < forra_fas:
            fel.append(_F(p, "sker tidigare i svingen än saken före; tidigt går först", "svingens_ordning"))
        forra_fas = max(forra_fas, f_i)
        if any(o in valda for o in A.orsaker(kedjor, fid)):
            fel.append(_F(f"{p}.fel", "är följdfel av en annan vald sak och får ingen egen övning", "foljdfel_av_vald"))

        # Mot analysen: flaggat, inget följdfel, och analysens tal (BESLUT B2).
        b = bed.get(fid)
        if b is None:
            fel.append(_F(f"{p}.fel", "saknas i analysen", "ej_i_analysen"))
            continue
        if b.get("status") in ("gul", "rod"):
            if kand.get(fid, {}).get("foljdfel"):
                fel.append(_F(f"{p}.fel", "är följdfel av ett flaggat fel i analysen; grundorsaken övas", "foljdfel"))
        elif b.get("status") == "okand":
            if kand:
                fel.append(_F(f"{p}.fel", "okänt fel får väljas bara när inget är flaggat", "okant_med_flaggade"))
        else:
            fel.append(_F(f"{p}.fel", "är inte flaggat i analysen", "inte_flaggat"))
        if not _lika(s.get("nu"), b.get("visat")):
            fel.append(_F(f"{p}.nu", "ska vara analysens tal (visat)", "analysens_tal"))

        # Minnet: fortsätter samma övning, eller är den ny? Jämförs på övningens id,
        # inte texten, så att en omskriven text inte nollställer steget.
        o = minne.get(fid)
        ov = s.get("ovning")
        text = ov.get("text") if isinstance(ov, dict) else None
        ov_id = ov.get("id") if isinstance(ov, dict) else None
        fortsatter = o is not None and _lika(o.get("ovning_id", o["ovning"]), ov_id)
        if fortsatter and o["lage"] == "klart":
            fel.append(_F(p, "övningen är klar enligt minnet; släpp saken", "klar"))
        if fortsatter and o["lage"] == "byt_ovning":
            fel.append(_F(f"{p}.ovning", "minnet säger byt övning", "byt_ovning"))
        if o is not None and _nyckel(ov_id) in o.get("forra_ovningar", []):
            fel.append(_F(f"{p}.ovning.id", "övningen är redan provad för felet", "redan_provad"))

        # Övningen: ur katalogen eller kedjor.json, aldrig fritext; id och text hör ihop.
        if _nycklar(ov, OVNING, f"{p}.ovning", fel):
            if ov.get("kalla") == "katalog":
                if not _lika(ov_id, k.get("ovning_id")):
                    fel.append(_F(f"{p}.ovning.id", "ska vara katalogens när kalla är katalog", "katalogens"))
                if not _lika(text, k["ovning"]):
                    fel.append(_F(f"{p}.ovning.text", "ska vara katalogens när kalla är katalog", "katalogens"))
            elif ov.get("kalla") == "research3":
                x = next((x for x in kedjor["ovningar"] if x["fel"] == fid and x.get("id") == ov_id), None)
                if x is None:
                    fel.append(_F(f"{p}.ovning.id", "ska vara en av felets övningar i kedjor.json", "ej_i_kedjorna"))
                elif not _lika(text, x["text"]):
                    fel.append(_F(f"{p}.ovning.text", "ska vara övningens text i kedjor.json", "kedjornas"))
            else:
                fel.append(_F(f"{p}.ovning.kalla", "ska vara katalog eller research3", "kalla"))
            _fritext(ov.get("tanke"), f"{p}.ovning.tanke", MAX_TANKE, fel)
            steg = ov.get("steg")
            if _nyckel(steg) not in STEG:
                fel.append(_F(f"{p}.ovning.steg", f"ska vara ett av {', '.join(STEG)}", "steg"))
            elif fortsatter and o.get("steg") in STEG:
                if not 0 <= STEG.index(steg) - STEG.index(o["steg"]) <= 1:
                    fel.append(_F(f"{p}.ovning.steg", "samma steg eller nästa, inget hopp", "steg_hopp"))
            elif steg != STEG[0]:
                fel.append(_F(f"{p}.ovning.steg", f"en ny övning börjar på {STEG[0]}", "steg_forsta"))

        # "Klart när": analysens förslag för en ny övning, minnets när den fortsätter.
        kn = s.get("klart_nar")
        if _nycklar(kn, KLART, f"{p}.klart_nar", fel):
            if _nyckel(kn.get("villkor")) not in VILLKOR:
                fel.append(_F(f"{p}.klart_nar.villkor", "ska vara >=, <= eller mellan", "villkor"))
            elif kn["villkor"] == "mellan":
                g = kn.get("grans")
                if not (isinstance(g, list) and len(g) == 2 and all(_tal(x) for x in g) and g[0] <= g[1]):
                    fel.append(_F(f"{p}.klart_nar.grans", "ska vara [min, max]", "grans_spann"))
            elif not _tal(kn.get("grans")):
                fel.append(_F(f"{p}.klart_nar.grans", "ska vara ett tal", "grans_tal"))
            if not _lika(kn.get("pa"), "forsta_serien"):
                fel.append(_F(f"{p}.klart_nar.pa", "ska vara forsta_serien", "pa"))
            if kn.get("pass_i_rad") != PASS_I_RAD or isinstance(kn.get("pass_i_rad"), bool):
                fel.append(_F(f"{p}.klart_nar.pass_i_rad", f"ska vara {PASS_I_RAD}", "pass_i_rad"))
            if fortsatter:
                ok = o["klart_nar"]
                if not (_lika(kn.get("villkor"), ok["villkor"]) and _lika(kn.get("grans"), ok["grans"])):
                    fel.append(_F(f"{p}.klart_nar", "ska vara samma som när övningen valdes", "last"))
                if not _lika(s.get("markning"), o.get("markning")):
                    fel.append(_F(f"{p}.markning", "ska vara samma som när övningen valdes", "last"))
            else:
                bkn = b.get("klart_nar")
                if bkn is None:
                    fel.append(_F(f"{p}.klart_nar", "analysen har inget förslag för felet", "inget_forslag"))
                else:
                    if not (_lika(kn.get("villkor"), bkn.get("villkor")) and _lika(kn.get("grans"), bkn.get("grans"))):
                        fel.append(_F(f"{p}.klart_nar", "ska vara analysens förslag", "analysens"))
                    if not _lika(s.get("markning"), bkn.get("markning")):
                        fel.append(_F(f"{p}.markning", "ska vara analysens", "analysens"))

        # Blocket: från första gången felet valdes, i veckor.
        blk = s.get("block")
        if _nycklar(blk, BLOCK, f"{p}.block", fel) and pass_ok:
            start = _datum(o["fel_start"]) if o is not None else _datum(d["pass"])
            if not _lika(blk.get("start"), start.isoformat()):
                fel.append(_F(f"{p}.block.start", "ska vara dagen då felet först valdes", "block_start"))
            if not _lika(blk.get("vecka"), (_datum(d["pass"]) - start).days // 7 + 1):
                fel.append(_F(f"{p}.block.vecka", "ska vara veckan sedan blockets start", "block_vecka"))

        # Följdfelen: mäts, övas inte, och bara enligt kedjorna (flera led går).
        ff = s.get("foljdfel")
        if not isinstance(ff, list):
            fel.append(_F(f"{p}.foljdfel", "ska vara en lista", "lista"))
        else:
            for j, f in enumerate(ff):
                q = f"{p}.foljdfel[{j}]"
                if not _nycklar(f, FOLJD, q, fel):
                    continue
                ffid = f.get("fel")
                if _nyckel(ffid) not in K:
                    fel.append(_F(f"{q}.fel", "finns inte i katalogen", "ej_i_katalogen"))
                    continue
                vag = A.orsaker(kedjor, ffid).get(fid)
                if vag is None:
                    fel.append(_F(f"{q}.fel", "ingen kedja i kedjor.json från saken", "ingen_kedja"))
                elif not _lika(f.get("vag"), vag):
                    fel.append(_F(f"{q}.vag", "ska vara kedjans väg från saken", "vag"))
                if ffid in valda:
                    fel.append(_F(f"{q}.fel", "är också en vald sak", "vald"))
                if not _lika(f.get("namn"), K[ffid]["namn"]):
                    fel.append(_F(f"{q}.namn", "ska vara katalogens", "katalogens"))
                if not _lika(f.get("enhet"), A.enhet(K[ffid]["matt"])):
                    fel.append(_F(f"{q}.enhet", "ska vara måttets", "mattets"))
                if not _lika(f.get("nu"), bed.get(ffid, {}).get("visat")):
                    fel.append(_F(f"{q}.nu", "ska vara analysens tal (visat)", "analysens_tal"))

        # Fysik före teknik bara enligt treregeln.
        typ, fy = s.get("typ"), s.get("fysik")
        if o is not None and o["lage"] == "fysik" and fy is None:
            fel.append(_F(f"{p}.fysik", "minnet säger fysik; pröva treregeln med Johannes först", "fysik_forst"))
        if _nyckel(typ) not in TYPER:
            fel.append(_F(f"{p}.typ", f"ska vara en av {', '.join(TYPER)}", "typ"))
        elif fy is None:
            if typ != "teknik":
                fel.append(_F(f"{p}.fysik", "krävs för typen", "kravs"))
        elif _nycklar(fy, FYSIK, f"{p}.fysik", fel):
            tre = fy.get("treregeln")
            if not (isinstance(tre, list) and len(tre) == 3 and all(isinstance(x, bool) for x in tre)):
                fel.append(_F(f"{p}.fysik.treregeln", "ska vara tre true/false", "treregeln"))
            elif TRE_REGELN.get(tuple(tre), "teknik") != typ:
                fel.append(_F(f"{p}.typ", "följer inte treregeln", "treregeln"))
            if _nyckel(fy.get("test")) not in [x["test"] for x in kedjor["fysik"] if x["fel"] == fid]:
                fel.append(_F(f"{p}.fysik.test", "inget test i kedjor.json för felet", "test"))
            if typ == "teknik":
                if fy.get("ovning") is not None:
                    fel.append(_F(f"{p}.fysik.ovning", "ska vara null för teknik", "null"))
            else:
                _fritext(fy.get("ovning"), f"{p}.fysik.ovning", MAX_FYSIK, fel)
    return fel


def _nyckel(v):
    """Ett värde som går att slå upp i en mängd eller en lista av texter: en lista eller ett
    objekt ur filen (som Claude skrivit fel) blir None i stället för att kasta."""
    if isinstance(v, bool):
        return ("bool", v)                     # true är inte 1 (BESLUT B54)
    return v if isinstance(v, (str, int, float)) or v is None else None


# Tiden i `skapad`: ISO 8601 som datetime.fromisoformat läser den, i den form telefonen
# prövar likadant (BESLUT B54): dagen, och valfritt tiden med sekunder, bråkdel och zon.
SKAPAD = re.compile(r"(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d{1,6})?)?"
                    r"(?:Z|[+-](\d{2}):(\d{2}))?)?", re.A)


def skapad_ok(v) -> bool:
    """`skapad` är en tid i ISO 8601 (FORMAT.md): yyyy-MM-dd, och valfritt THH:mm[:ss[.f]] med
    Z eller ±HH:mm. Samma regel i Swift (`AttJobbaPaKontroll`)."""
    if not isinstance(v, str):
        return False
    m = SKAPAD.fullmatch(v)
    if not m:
        return False
    ar, man, dag, h, mi, s, zh, zm = (int(x) if x is not None else None for x in m.groups())
    try:
        dt.date(ar, man, dag)
    except ValueError:
        return False
    return (h is None or (h <= 23 and mi <= 59 and (s is None or s <= 59))) and \
        (zh is None or (zh <= 23 and zm <= 59))


# --- svaret från Claude-appen (S5b) ------------------------------------------------

PREFIX = "swinglab-att-jobba-pa/"
# Tecken som telefonen eller ett anteckningsprogram byter till: typografiska citattecken blir
# raka och hårda mellanslag vanliga, och BOM och nollbredda tecken tas bort. Bara när blocket
# inte går att läsa som det står (ett ’ i en övnings text är rätt). METOD MT12
UTBYTEN = {"“": '"', "”": '"', "„": '"', "‟": '"', "″": '"',
           " ": " ", " ": " ", " ": " ", "﻿": "", "​": ""}


def kodblock(text: str) -> list[str]:
    """Kodblocken i texten i ordning: det som står mellan en rad som börjar med ``` (med
    valfri märkning, som ```json) och nästa ```. Samma regel i Swift (`ClaudeSvar`)."""
    ut, i, n = [], 0, len(text)
    while i + 3 <= n:
        if text.startswith("```", i):
            j = i + 3
            while j < n and text[j] not in "\n`":
                j += 1
            if j < n and text[j] == "\n":
                k = text.find("```", j + 1)
                if k >= 0:
                    ut.append(text[j + 1:k])
                    i = k + 3
                    continue
        i += 1
    return ut


def _normalisera(s: str) -> str:
    return "".join(UTBYTEN.get(c, c) for c in s)


MAX_SVAR = 64 * 1024     # METOD MT12: byte i urklippet som läses
MAX_DJUP = 32            # METOD MT12: listor och objekt i varandra


def djup(s: str) -> int:
    """Hur djupt listor och objekt ligger i varandra, utanför texter."""
    d = mx = 0
    i, n, i_text = 0, len(s), False
    while i < n:
        c = s[i]
        if i_text:
            if c == "\\":
                i += 1
            elif c == '"':
                i_text = False
        elif c == '"':
            i_text = True
        elif c in "[{":
            d += 1
            mx = max(mx, d)
        elif c in "]}":
            d -= 1
        i += 1
    return mx


def _json(s: str):
    def nej(x):
        raise ValueError(x)
    if djup(s) > MAX_DJUP:
        raise ValueError("för djupt")
    try:
        return json.loads(s, parse_constant=nej)
    except RecursionError as e:
        raise ValueError("för djupt") from e


def ur_text(text: str) -> tuple[dict | None, list[Kontrollfel]]:
    """Filen ur svaret som Johannes kopierat i Claude-appen: det sista kodblocket som går att
    läsa som en `att_jobba_pa.json` (ett objekt med `format` eller `saker`), annars hela texten
    eller det mellan första { och sista }. Felet säger vad som saknas, aldrig vad som stod.
    METOD MT12"""
    if len(text.encode("utf-8", "surrogatepass")) > MAX_SVAR:
        return None, [Kontrollfel("svaret: för långt", "svaret", "for_stort")]
    block = kodblock(text)
    kandidater = block or [text] + ([text[text.index("{"):text.rindex("}") + 1]]
                                    if "{" in text and "}" in text[text.index("{"):] else [])
    lasbar = False
    for b in reversed(kandidater):
        for variant in (b, _normalisera(b)):
            try:
                v = _json(variant)
            except ValueError:
                continue
            lasbar = True
            if isinstance(v, dict) and ("format" in v or "saker" in v):
                return v, []
            break
    if lasbar:
        return None, [Kontrollfel("svaret: inget block med en att_jobba_pa.json", "svaret", "inte_att_jobba_pa")]
    if block:
        return None, [Kontrollfel("svaret: blocket går inte att läsa som JSON", "svaret", "inte_json")]
    return None, [Kontrollfel("svaret: inget kodblock", "svaret", "inget_block")]


def las_svar(text: str, analys: dict, ovningar: list[dict] | None = None, katalog: dict | None = None,
             kedjor: dict | None = None) -> tuple[dict | None, list[Kontrollfel]]:
    """Svaret ur Claude-appen kontrollerat mot passets analys och minnet före passet, som en fil
    från PC:n: (filen, []) när den går igenom, annars (None, felen). METOD MT12"""
    d, fel = ur_text(text)
    if d is None:
        return None, fel
    fel = kontrollera(d, analys, ovningar, katalog, kedjor)
    return (None, fel) if fel else (d, [])


def main(argv=None) -> int:
    from . import historik as H

    ap = argparse.ArgumentParser(description="Kontrollera en att_jobba_pa.json mot passets analys och minnet.")
    ap.add_argument("fil", nargs="?", help="att_jobba_pa.json (eller --ur-text)")
    ap.add_argument("--analys", required=True, help="passets analys.json: talen ska vara dess")
    ap.add_argument("--historik", default=str(H.ROT), help="historikens mapp (minnet före passet)")
    ap.add_argument("--ur-text", help="svaret från Claude-appen som text: filen tas ur det sista kodblocket (S5b)")
    ap.add_argument("--ut", help="med --ur-text: skriv den godkända filen hit")
    a = ap.parse_args(argv)
    if (a.fil is None) == (a.ur_text is None):
        ap.error("ange en fil eller --ur-text")
    try:
        analys = json.loads(Path(a.analys).read_text(encoding="utf-8"))
        if a.ur_text:
            text = Path(a.ur_text).read_text(encoding="utf-8")
        else:
            d = json.loads(Path(a.fil).read_text(encoding="utf-8"))
    except UnicodeDecodeError:
        print("går inte att läsa som UTF-8")
        return 1
    except (OSError, json.JSONDecodeError) as e:
        print(f"går inte att läsa som JSON ({type(e).__name__})")
        return 1
    if a.ur_text:
        pass_id = analys.get("pass")
        ov = H.ovningar(Path(a.historik), till=pass_id, fore=pass_id) if isinstance(pass_id, str) else []
        d, fel = las_svar(text, analys, ov)
        if fel:
            print("\n".join(f"{a.ur_text}: {f}" for f in fel))
            return 1
        if a.ut:
            Path(a.ut).write_text(json.dumps(d, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print(f"{a.ur_text}: OK ({len(d['saker'])} saker)" + (f", skrev {a.ut}" if a.ut else ""))
        return 0
    pass_id = d.get("pass") if isinstance(d, dict) else None
    ov = H.ovningar(Path(a.historik), till=pass_id, fore=pass_id) if isinstance(pass_id, str) else []
    fel = kontrollera(d, analys, ov)
    print("\n".join(f"{a.fil}: {f}" for f in fel) if fel else f"{a.fil}: OK ({len(d['saker'])} saker)")
    return 1 if fel else 0


if __name__ == "__main__":
    sys.exit(main())
