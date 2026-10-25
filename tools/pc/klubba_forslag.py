"""Modellens förslag i klubbmarkeringen (PLAN S7d, BESLUT B93, METOD MF8).

    python tools/pc/klubba_forslag.py <forslag.json> [--paket <swinglab-<pass>-<vy>.zip>]
    python tools/pc/klubba_forslag.py --exempel <ut.json>     # en påhittad fil att utgå från
    python tools/pc/klubba_forslag.py --swift                 # Swift-fixturerna (BESLUT B12)

En detektor på PC:n (S7, BESLUT B92) förmärker Johannes svingar: för varje ruta i ett slag
ger den greppet, hoseln, klubbhuvudets mitt och skaftets mitt, var för sig med konfidens och
eventuellt en ruta (box). Filen `swinglab-klubba-forslag/1` (docs/FORMAT.md) bär det per
pass och vy, delas till telefonen och visas i klubbmarkeringen (S7c) som streckade ringar.
Johannes godkänner med ett tryck eller rättar; **förslaget är aldrig en markering av sig
självt** (B92, som B71). Den här modulen äger formatet:

  kontrollera   formen, med felen på engelska som telefonen visar dem (fältet, aldrig
                värdet), samma text som SwingLabKits `KlubbForslagFil.kontrollera`;
  ruta_for      rutan i filen som hör till en visad ruta (Visions tid inom RUTA_TOL);
  visade        punkterna som telefonen visar (konfidens ≥ VISA_KONFIDENS);
  mot_paket     att filen hör till ett paket: passet, vyn, slagen, bildens storlek och att
                varje tid är en av slagets Visions-rutor;
  ny, lagg_till, skriv   för PC-sessionen som skriver filen.

Tiden `t` är Visions tid i sekunder relativt slagets klick, som `t` i `swinglab-klubba`
och `frames[].t` i paketets `slag/sNN.json`. Från en ruta som OpenCV läst ur klippet:
`t = t_opencv − forskjutning_ms/1000 − klick_i_klipp_s` (MF1), och sedan den närmaste av
slagets Visions-tider (`vision_t`).
"""
from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "pc"

FORMAT = "swinglab-klubba-forslag/1"     # BESLUT B93
PUNKTER = ("grepp", "hosel", "huvud", "skaft_mitt")   # BESLUT B93: hosel = B44:s klubbhuvud, huvud = mitten
GODKANNBARA = ("grepp", "hosel")          # BESLUT B93: bara de blir en markering när de godkänns
VISAS = ("grepp", "hosel", "huvud")       # BESLUT B93: huvudets mitt visas som ledtråd, godkänns aldrig
RUTA_TOL = 0.002          # METOD MF8: en ruta i filen hör till den visade när tiderna skiljer högst så, s
VISA_KONFIDENS = 0.5      # METOD MF8: en punkt med lägre konfidens visas inte på telefonen
MAX_FEL = 30
MAX_BYTES = 20_000_000    # METOD MF8: större än så tas inte emot (cirka 400 rutor × 40 slag)
PASS_ID = re.compile(r"[0-9]{8}-[0-9]{6}")      # fullmatch: inga andra siffror, inget radslut
VYER = ("dtl", "fo")
# Källorna i `swinglab-klubba` (BESLUT B93): en godkänd punkt, och förslagets källa.
KALLA_GODKAND = "godkand_forslag"
KALLA_MODELL = "modell"

REPO = Path(__file__).resolve().parents[2]
SWIFTFIL = REPO / "SwingLabKit" / "Tests" / "SwingTests" / "KlubbForslagFixturer.swift"
FIXTURFIL = REPO / "tools" / "tests" / "fixturer" / "klubba_forslag.json"


class ForslagFel(ValueError):
    """Felen nämner fältet, aldrig värdet (CLAUDE.md, Dataregeln)."""


# --- formen -----------------------------------------------------------------------------

def _tal(v) -> bool:
    return not isinstance(v, bool) and isinstance(v, (int, float)) and math.isfinite(v)


def _heltal(v) -> bool:
    """Ett tal utan decimaler (1 och 1.0 lika, som telefonens JSON-läsare)."""
    return _tal(v) and float(v).is_integer()


def _text(v) -> bool:
    return isinstance(v, str) and v != ""


def kontrollera(d) -> list[str]:
    """Formen på en förslagsfil (docs/FORMAT.md, `swinglab-klubba-forslag/1`). Felen är på
    engelska, i samma ordning och med samma text som `KlubbForslagFil.kontrollera` i
    SwingLabKit, och nämner fältet, aldrig värdet. Okända fält tillåts (en nyare PC kan lägga
    till fält utan att en äldre telefon säger nej, `okanda`). BESLUT B93"""
    if not isinstance(d, dict):
        return ["file: invalid"]
    fel: list[str] = []

    def krav(o: dict, k: str, plats: str, ok) -> bool:
        if k not in o:
            fel.append(f"{plats} is missing")
            return False
        if not ok(o[k]):
            fel.append(f"{plats}: invalid")
            return False
        return True

    if "format" not in d:
        fel.append("format is missing")
    elif d["format"] != FORMAT:
        fel.append(f"format: must be {FORMAT}")
    krav(d, "pass", "pass", lambda v: isinstance(v, str) and PASS_ID.fullmatch(v) is not None)
    krav(d, "vy", "vy", lambda v: v in VYER)
    if d.get("paket") is not None and not isinstance(d["paket"], str):
        fel.append("paket: invalid")
    krav(d, "skapad", "skapad", _text)
    if krav(d, "modell", "modell", lambda v: isinstance(v, dict)):
        m = d["modell"]
        krav(m, "namn", "modell.namn", _text)
        krav(m, "version", "modell.version", _text)
        if krav(m, "data", "modell.data", lambda v: isinstance(v, list) and len(v) > 0):
            for i, k in enumerate(m["data"]):
                p = f"modell.data[{i}]"
                if not isinstance(k, dict):
                    fel.append(f"{p}: invalid")
                    continue
                krav(k, "namn", f"{p}.namn", _text)
                krav(k, "licens", f"{p}.licens", _text)
                if k.get("kalla") is not None and not isinstance(k["kalla"], str):
                    fel.append(f"{p}.kalla: invalid")
    bh_ok = krav(d, "bredd", "bredd", lambda v: _heltal(v) and v > 0)
    bh_ok = krav(d, "hojd", "hojd", lambda v: _heltal(v) and v > 0) and bh_ok
    bredd, hojd = (d["bredd"], d["hojd"]) if bh_ok else (None, None)
    if krav(d, "slag", "slag", lambda v: isinstance(v, list) and len(v) > 0):
        ids: set[str] = set()
        for i, s in enumerate(d["slag"]):
            p = f"slag[{i}]"
            if not isinstance(s, dict):
                fel.append(f"{p}: invalid")
                continue
            if krav(s, "id", f"{p}.id", _text):
                if s["id"] in ids:
                    fel.append(f"{p}.id: duplicate")
                ids.add(s["id"])
            if not krav(s, "rutor", f"{p}.rutor", lambda v: isinstance(v, list) and len(v) > 0):
                continue
            tider: list[float] = []
            for j, r in enumerate(s["rutor"]):
                _ruta(r, f"{p}.rutor[{j}]", bredd, hojd, tider, fel, krav)
    return fel[:MAX_FEL] + ["more errors skipped"] if len(fel) > MAX_FEL else fel


def _ruta(r, p: str, bredd, hojd, tider: list, fel: list, krav) -> None:
    if not isinstance(r, dict):
        fel.append(f"{p}: invalid")
        return
    if krav(r, "t", f"{p}.t", _tal):
        if any(abs(r["t"] - t) < 2 * RUTA_TOL for t in tider):      # METOD MF8
            fel.append(f"{p}.t: duplicate")
        tider.append(float(r["t"]))
    if r.get("ruta") is not None and not (_heltal(r["ruta"]) and r["ruta"] >= 0):
        fel.append(f"{p}.ruta: invalid")
    if r.get("t_klipp") is not None and not (_tal(r["t_klipp"]) and r["t_klipp"] >= 0):
        fel.append(f"{p}.t_klipp: invalid")
    if not krav(r, "punkter", f"{p}.punkter", lambda v: isinstance(v, dict)):
        return
    pk = r["punkter"]
    if all(pk.get(n) is None for n in PUNKTER):
        fel.append(f"{p}.punkter: no point")
    for n in PUNKTER:
        q = pk.get(n)
        if q is None:
            continue
        pq = f"{p}.punkter.{n}"
        if not isinstance(q, dict):
            fel.append(f"{pq}: invalid")
            continue
        xy = krav(q, "x", f"{pq}.x", _tal)
        xy = krav(q, "y", f"{pq}.y", _tal) and xy
        if xy and bredd is not None and not (0 <= q["x"] <= bredd and 0 <= q["y"] <= hojd):
            fel.append(f"{pq}: outside the image")
        krav(q, "konfidens", f"{pq}.konfidens", lambda v: _tal(v) and 0 <= v <= 1)
        b = q.get("box")
        if b is not None and not (isinstance(b, list) and len(b) == 4 and all(_tal(v) for v in b)
                                  and b[2] > 0 and b[3] > 0):
            fel.append(f"{pq}.box: invalid")


def okanda(d: dict) -> list[str]:
    """Fält som formen inte känner (tillåtna, men en felstavning ger inga förslag): för
    PC-sessionen, aldrig på telefonen."""
    ut = [f"{k}" for k in d if k not in ("format", "pass", "vy", "paket", "skapad", "modell", "bredd", "hojd", "slag")]
    for i, s in enumerate(d.get("slag") or []):
        if not isinstance(s, dict):
            continue
        ut += [f"slag[{i}].{k}" for k in s if k not in ("id", "rutor")]
        for j, r in enumerate(s.get("rutor") or []):
            if not isinstance(r, dict):
                continue
            p = f"slag[{i}].rutor[{j}]"
            ut += [f"{p}.{k}" for k in r if k not in ("t", "ruta", "t_klipp", "punkter")]
            if isinstance(r.get("punkter"), dict):
                ut += [f"{p}.punkter.{k}" for k in r["punkter"] if k not in PUNKTER]
                for n in PUNKTER:
                    q = r["punkter"].get(n)
                    if isinstance(q, dict):
                        ut += [f"{p}.punkter.{n}.{k}" for k in q if k not in ("x", "y", "konfidens", "box")]
    return ut


def las_dict(d) -> dict:
    f = kontrollera(d)
    if f:
        raise ForslagFel("suggestions: " + "; ".join(f))
    return d


def las(fil) -> dict:
    """En förslagsfil, kontrollerad; ForslagFel med fälten annars."""
    fil = Path(fil)
    if fil.stat().st_size > MAX_BYTES:
        raise ForslagFel("suggestions: file: too large")
    try:
        d = json.loads(fil.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError):
        raise ForslagFel("suggestions: not valid JSON") from None
    return las_dict(d)


# --- matchningen: ruta → position ------------------------------------------------------

def rutor(d: dict, slag: str, bredd: int | None = None, hojd: int | None = None) -> list[dict]:
    """Slagets rutor ur en kontrollerad fil; tom när slaget saknas eller när bildens storlek
    inte är slagets (`bredd`, `hojd`): punkterna hör då till en annan bild. METOD MF8"""
    if bredd is not None and (d["bredd"] != bredd or d["hojd"] != hojd):
        return []
    s = next((s for s in d["slag"] if s["id"] == slag), None)
    return list(s["rutor"]) if s else []


def ruta_for(rutor_: list[dict], t: float) -> int | None:
    """Index för rutan vars tid ligger närmast den visade rutans `t` och högst RUTA_TOL
    därifrån, den tidigare i filen vid lika avstånd; None annars. Som `KlubbForslagFil.ruta`.
    METOD MF8"""
    bast, bast_d = None, math.inf
    for i, r in enumerate(rutor_):
        dt = abs(r["t"] - t)
        if dt <= RUTA_TOL and dt < bast_d:
            bast, bast_d = i, dt
    return bast


def matcha(rutor_: list[dict], tider: dict) -> dict:
    """Varje positions ruta i filen: {position: index eller None}, ur positionernas visade
    tider ({position: t eller None}). METOD MF8"""
    return {p: (ruta_for(rutor_, t) if t is not None else None) for p, t in tider.items()}


def visade(r: dict) -> dict:
    """Punkterna som telefonen visar i rutan: {punkt: {"x", "y", "box"}} för grepp, hosel och
    huvud med konfidens ≥ VISA_KONFIDENS. Skaftets mitt visas inte. METOD MF8, BESLUT B93"""
    ut = {}
    for n in VISAS:
        q = r["punkter"].get(n)
        if q is not None and q["konfidens"] >= VISA_KONFIDENS:
            ut[n] = {"x": float(q["x"]), "y": float(q["y"]), "box": q.get("box")}
    return ut


# --- mot paketet -----------------------------------------------------------------------

def mot_paket(d: dict, paket) -> list[str]:
    """Att en kontrollerad fil hör till paketet (`paket.las`): samma pass och vy, slag som finns,
    bildens storlek som slagets leder, och varje `t` inom RUTA_TOL från en av slagets
    Visions-rutor. Felen som `kontrollera`. METOD MF8"""
    fel = []
    if d["pass"] != paket.pass_id:
        fel.append("pass: no such session")
    if d["vy"] != paket.vy:
        fel.append("vy: does not match the session")
    slag = {s.id: s for s in paket.slag}
    for i, s in enumerate(d["slag"]):
        ps = slag.get(s["id"])
        if ps is None:
            fel.append(f"slag[{i}].id: no such shot")
            continue
        if ps.lederna is None:
            continue
        if (ps.lederna["width"], ps.lederna["height"]) != (d["bredd"], d["hojd"]):
            fel.append(f"slag[{i}]: bredd and hojd do not match the shot")
        vt = sorted(float(f["t"]) for f in ps.lederna["frames"])
        for j, r in enumerate(s["rutor"]):
            if _narmast(vt, r["t"]) is None:
                fel.append(f"slag[{i}].rutor[{j}].t: no such frame")
    return fel[:MAX_FEL] + ["more errors skipped"] if len(fel) > MAX_FEL else fel


def _narmast(vt: list[float], t: float) -> float | None:
    import bisect
    k = bisect.bisect_left(vt, t)
    nara = [vt[i] for i in (k - 1, k) if 0 <= i < len(vt)]
    if not nara:
        return None
    b = min(nara, key=lambda x: abs(x - t))
    return b if abs(b - t) <= RUTA_TOL else None


def vision_t(slag, t_opencv: float, forskjutning_ms: float = 0.0) -> float | None:
    """Visions tid för en ruta som OpenCV läst ur slagets klipp (`paket.Slag` med lederna):
    `t_opencv − forskjutning_ms/1000 − klick_i_klipp_s` (MF1), den närmaste av slagets
    Visions-tider inom en halv ruta (1/480 s). Utan S3:s δ (`forskjutning_ms` 0) kan rutan bli
    grannen när δ är nära en halv ruta. None utan klipp, leder eller en ruta så nära."""
    if slag.klick_i_klipp_s is None or slag.lederna is None:
        return None
    t = t_opencv - forskjutning_ms / 1000.0 - slag.klick_i_klipp_s
    vt = [float(f["t"]) for f in slag.lederna["frames"]]
    if not vt:
        return None
    b = min(vt, key=lambda x: abs(x - t))
    return b if abs(b - t) <= 1 / 480 else None


# --- att skriva filen -------------------------------------------------------------------

def ny(pass_id: str, vy: str, modell: str, version: str, data: list[dict], bredd: int, hojd: int,
       paket: str | None = None, skapad: str | None = None) -> dict:
    """En tom fil att fylla med `lagg_till`. `data` = [{"namn", "licens", "kalla"}] för
    namnangivelsen (B92)."""
    from datetime import datetime
    return {"format": FORMAT, "pass": pass_id, "vy": vy, "paket": paket,
            "skapad": skapad or datetime.now().astimezone().isoformat(timespec="seconds"),
            "modell": {"namn": modell, "version": version, "data": data},
            "bredd": bredd, "hojd": hojd, "slag": []}


def lagg_till(d: dict, slag: str, t: float, punkter: dict, ruta: int | None = None,
              t_klipp: float | None = None) -> None:
    """En ruta i slaget: `punkter` = {punkt: {"x", "y", "konfidens", "box"?}} för de punkter
    modellen ger (grepp, hosel, huvud, skaft_mitt). Rutorna sorteras inte."""
    s = next((s for s in d["slag"] if s["id"] == slag), None)
    if s is None:
        s = {"id": slag, "rutor": []}
        d["slag"].append(s)
    r: dict = {"t": round(float(t), 6)}
    if ruta is not None:
        r["ruta"] = int(ruta)
    if t_klipp is not None:
        r["t_klipp"] = round(float(t_klipp), 6)
    r["punkter"] = {n: punkter[n] for n in PUNKTER if punkter.get(n) is not None}
    s["rutor"].append(r)


def skriv(fil, d: dict) -> None:
    """Kontrollerar och skriver filen (kompakt JSON; den kan ha tusentals rutor)."""
    las_dict(d)
    Path(fil).write_text(json.dumps(d, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")


# --- den påhittade fixturen (BESLUT B12) ------------------------------------------------

def pahittad() -> dict:
    """En PÅHITTAD förslagsfil (CLAUDE.md, Dataregeln): två slag, tider som Visions rutor vid
    240 bilder/s (avrundade till 0,1 ms), alla punkttyper, en låg konfidens och en box."""
    d = ny("20261024-171500", "dtl", "klubba-golf49", "0.1.0",
           [{"namn": "golf-49wbh", "licens": "CC BY 4.0", "kalla": "https://universe.roboflow.com/"}],
           1080, 1920, paket="swinglab-20261024-171500-dtl.zip", skapad="2026-10-25T21:15:00+02:00")
    for k in range(6):
        t = round(-0.3125 + k / 240, 4)
        g = (512.0 + 3 * k, 640.0 - 2 * k)
        h = (600.0 + 5 * k, 980.0 + 4 * k)
        punkter = {"grepp": {"x": g[0], "y": g[1], "konfidens": 0.9 - 0.05 * k},
                   "hosel": {"x": h[0], "y": h[1], "konfidens": 0.8 if k != 3 else 0.42,
                             "box": [h[0] - 20, h[1] - 20, 60.0, 40.0]},
                   "huvud": {"x": h[0] + 25, "y": h[1] + 8, "konfidens": 0.85,
                             "box": [h[0] - 10, h[1] - 12, 70.0, 42.0]}}
        if k == 5:
            punkter = {"huvud": punkter["huvud"]}
        if k == 2:
            punkter["skaft_mitt"] = {"x": (g[0] + h[0]) / 2, "y": (g[1] + h[1]) / 2, "konfidens": 0.7}
        lagg_till(d, "s01", t, punkter, ruta=520 + k, t_klipp=round(t + 2.5, 6))
    lagg_till(d, "s03", 0.0, {"grepp": {"x": 530.0, "y": 1100.0, "konfidens": 0.95},
                              "hosel": {"x": 560.0, "y": 1500.0, "konfidens": 0.9}})
    return d


def _fel_varianter() -> list[tuple[str, object]]:
    """Trasiga varianter av den påhittade filen och vad som är fel; felen jämförs med Swift."""
    import copy

    def med(f):
        d = copy.deepcopy(pahittad())
        f(d)
        return d
    return [
        ("inte_objekt", [1, 2]),
        ("format", med(lambda d: d.update(format="swinglab-klubba-forslag/2"))),
        ("utan_format", med(lambda d: d.pop("format"))),
        ("pass", med(lambda d: d.update({"pass": "../x"}))),
        ("vy", med(lambda d: d.update(vy="sidan"))),
        ("modell", med(lambda d: d["modell"].update(namn="", data=[]))),
        ("licens", med(lambda d: d["modell"]["data"][0].pop("licens"))),
        ("bredd", med(lambda d: d.update(bredd=1080.5, hojd=True))),
        ("slag_tom", med(lambda d: d.update(slag=[]))),
        ("slag_id", med(lambda d: d["slag"][1].update(id="s01"))),
        ("t", med(lambda d: d["slag"][0]["rutor"][1].update(t=None))),
        ("t_dubbel", med(lambda d: d["slag"][0]["rutor"][2].update(t=-0.3125 + 1 / 240 + 0.001))),
        ("ruta_nr", med(lambda d: d["slag"][0]["rutor"][0].update(ruta=-1, t_klipp="2"))),
        ("ingen_punkt", med(lambda d: d["slag"][1]["rutor"][0].update(punkter={"grepp": None}))),
        ("utanfor", med(lambda d: d["slag"][1]["rutor"][0]["punkter"]["hosel"].update(x=1081.0))),
        ("konfidens", med(lambda d: d["slag"][1]["rutor"][0]["punkter"]["grepp"].update(konfidens=1.5))),
        ("utan_y", med(lambda d: d["slag"][1]["rutor"][0]["punkter"]["grepp"].pop("y"))),
        ("box", med(lambda d: d["slag"][0]["rutor"][0]["punkter"]["hosel"].update(box=[1.0, 2.0, 0.0, 4.0]))),
        ("punkt_text", med(lambda d: d["slag"][1]["rutor"][0]["punkter"].update(hosel="x"))),
        ("manga", med(lambda d: d["slag"][0].update(rutor=[{"t": None, "punkter": None}] * 20))),
    ]


def fixturer() -> dict:
    d = pahittad()
    r = rutor(d, "s01", 1080, 1920)
    tider = {"P4": -0.3125, "P5": -0.3125 + 2 / 240 + 0.0015, "P6": -0.3125 + 2 / 240 + 0.0025,
             "P7": 0.0, "P1": None}
    return {
        "fil": json.dumps(d, ensure_ascii=False, indent=1),
        "matcha": {"slag": "s01", "tider": tider, "index": matcha(r, tider)},
        "fel_storlek": len(rutor(d, "s01", 1920, 1080)),
        "visade": [visade(x) for x in r],
        "varianter": [{"namn": n, "json": json.dumps(v, ensure_ascii=False), "fel": kontrollera(v)}
                      for n, v in _fel_varianter()],
    }


def swift_kalla() -> str:
    data = json.dumps(fixturer(), ensure_ascii=False, indent=1, sort_keys=True)
    return "\n".join([
        "// GENERERAD av tools/pc/klubba_forslag.py --swift. Ändra inte för hand: kör skriptet igen.",
        "//",
        "// En PÅHITTAD förslagsfil (CLAUDE.md, Dataregeln), Pythons matchning och felen för trasiga",
        "// varianter (METOD MF8, BESLUT B12, B93).",
        "",
        "enum KlubbForslagFixturer {",
        "    static let json = #\"\"\"",
        data,
        "\"\"\"#",
        "}",
        "",
    ])


def fixtur_text() -> str:
    return json.dumps(pahittad(), ensure_ascii=False, indent=1) + "\n"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Kontrollerar modellens förslag till klubbmarkeringen (S7d).")
    ap.add_argument("fil", nargs="?", help="swinglab-<pass>-<vy>-forslag.json")
    ap.add_argument("--paket", help="paketet filen hör till: passet, vyn, slagen och rutornas tider prövas")
    ap.add_argument("--exempel", metavar="UT", help="skriv den påhittade filen dit")
    ap.add_argument("--swift", action="store_true", help=f"skriv {SWIFTFIL.name} och {FIXTURFIL.name}")
    a = ap.parse_args(argv)
    if a.swift:
        SWIFTFIL.write_text(swift_kalla(), encoding="utf-8")
        FIXTURFIL.write_text(fixtur_text(), encoding="utf-8")
        print(f"Skrev {SWIFTFIL} och {FIXTURFIL}")
        return 0
    if a.exempel:
        Path(a.exempel).write_text(fixtur_text(), encoding="utf-8")
        print(f"Skrev {a.exempel}")
        return 0
    if not a.fil:
        ap.error("ange en fil, --exempel eller --swift")
    try:
        d = las(a.fil)
    except (ForslagFel, OSError) as e:
        print(f"{Path(a.fil).name}: {e}")
        return 1
    fel = []
    if a.paket:
        from . import paket as P
        try:
            fel = mot_paket(d, P.las(a.paket))
        except P.PaketFel as e:
            print(f"Paketet går inte att läsa: {e}")
            return 1
    for k in okanda(d):
        print(f"Okänt fält (läses inte): {k}")
    if fel:
        print(f"{Path(a.fil).name}: " + "; ".join(fel))
        return 1
    n = {p: sum(1 for s in d["slag"] for r in s["rutor"] if r["punkter"].get(p) is not None) for p in PUNKTER}
    visas = {p: sum(1 for s in d["slag"] for r in s["rutor"] if p in visade(r)) for p in VISAS}
    print(f"OK: {len(d['slag'])} slag, {sum(len(s['rutor']) for s in d['slag'])} rutor; punkter "
          + ", ".join(f"{p} {n[p]}" for p in PUNKTER) + "; visas på telefonen "
          + ", ".join(f"{p} {visas[p]}" for p in VISAS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
