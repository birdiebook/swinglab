"""Facit för 3D på telefonen (S6c-1, BESLUT B12, B48): påhittade tvåpaketspass och
Pythons tal, som SwingLabKit:s `TreD` ska räkna likadant.

    python3 tools/pc/generera_tre_d.py            # skriver tools/tests/fixturer/tre_d/
    python3 tools/pc/generera_tre_d.py --kontroll # räknar om och jämför (som testet)

Passen kommer ur `generera_paket.tva_paket` (S6a, METOD MK8): 3D-svingar filmade av
en FO- och en DTL-kamera med felbudgetens brus. Inga riktiga leder (CLAUDE.md,
Dataregeln). Två sorters filer (formen: docs/FORMAT.md "Facit för 3D på telefonen"):

- `indata/<pass>.json`: per vy manifestet, `par.json` och `enhet.json` som text (eller
  null), paketets filnamn och lederna per slag kompakt (tiderna int32 i 1e-4 s, lederna
  int16 i 0,1 px och 0,001, base64 i little endian; paketen avrundar redan till de
  stegen), 2D-fasernas start och topp per slag (`rader`) och de sanna måtten (`sant`).
- `<facit>.json`: vilket pass det gäller och per variant det som byts (`andra`: filerna
  per vy) och Pythons `tre_d` (`python`) med de oavrundade talen (`inre`).

`parning.json` bär bara manifesten och `para_slag`:s svar, `manifest_fel.json` trasiga
manifest och `kontrollera_manifest`:s fel, och `komponenter.json` delstegen för ett slag.
"""
from __future__ import annotations

import argparse
import base64
import functools
import json
import math
import shutil
import struct
import sys
import tempfile
import zipfile
from multiprocessing import Pool
from pathlib import Path

import numpy as np

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "pc"

from . import analys as A  # noqa: E402
from . import generera_paket as G  # noqa: E402
from . import paket as P  # noqa: E402
from . import tva_kameror as TK  # noqa: E402

ROT = Path(__file__).resolve().parents[2]
MAPP = ROT / "tools" / "tests" / "fixturer" / "tre_d"
INDATA = MAPP / "indata"
PASS = "20261103-180000"
LANGD_M = 1.80
OM = "PÅHITTAT (CLAUDE.md, Dataregeln). Genererad av tools/pc/generera_tre_d.py; ändra inte för hand."

# --- passen och varianterna ---------------------------------------------------------

# Indata: (tva_paket-argument, ändringar i 2D-faserna {(vy, id): {"start": None, ...}}).
PASS_INDATA = {
    # Utan brus, högerspelare, par.json i DTL:s paket, lodlinjen i manifestet: exakt (MK8).
    "utan_brus": ({"brus": "inget", "seed": 5, "n": 10, "lodlinje": True}, {}),
    # Bra brus, vänsterspelare, lodlinjen och utan par.json (parning på klicken).
    "bra_brus_vanster": ({"brus": "bra", "seed": 31, "n": 10, "hand": "vanster", "lodlinje": True,
                          "par_json": False}, {}),
    # Mycket dåligt brus: Sampson-felet över spärren (MK3).
    "sparren": ({"brus": "mycket_daligt", "seed": 3, "n": 4}, {}),
    # Två serier om fyra slag med typiskt brus. Serie 2: 45° mellan kamerorna (osäker),
    # utan traff_s (träffen ur avstand_m) och klicken med exakt 7,3 s mellanrum (tvetydiga
    # utan par.json). Slag 2 saknar starten i båda vyerna (toppen − 1,2 s), slag 3 båda faserna.
    "tva_serier": ({"brus": "typiskt", "seed": 7, "n": 4,
                    "serier": [{"n": 4}, {"n": 4, "vinkel": 45.0, "traff": False, "jamna_klick": True}]},
                   {("dtl", "s02"): {"start": None}, ("fo", "s02"): {"start": None},
                    ("dtl", "s03"): {"start": None, "topp": None}, ("fo", "s03"): {"start": None, "topp": None}}),
}


def _manifest(paket: dict, vy: str, f) -> None:
    m = json.loads(paket[vy]["manifest"])
    f(m)
    paket[vy]["manifest"] = json.dumps(m, ensure_ascii=False)


def _fyra_slag(paket: dict) -> dict:
    """De fyra första slagen i båda vyerna, och FO:s ensamma slag (s11)."""
    for vy, extra in (("dtl", set()), ("fo", {"s11"})):
        _manifest(paket, vy, lambda m: m.update(slag=[s for s in m["slag"]
                                                      if s["id"] in {"s01", "s02", "s03", "s04"} | extra]))
    return paket


def _lod(f):
    def g(paket: dict) -> dict:
        _fyra_slag(paket)
        for vy in ("dtl", "fo"):
            _manifest(paket, vy, lambda m: f(vy, m["serier"][0]))
        return paket
    return g


def _vrid(grader: float):
    a = math.radians(grader)

    def f(vy, s):
        v = s["lodlinje"]
        s["lodlinje"] = [v[0] * math.cos(a) - v[1] * math.sin(a), v[0] * math.sin(a) + v[1] * math.cos(a), v[2]]
    return f


def _vand(vy, s):
    s["lodlinje"] = [-x for x in s["lodlinje"]]


def _utan(vy, s):
    s.pop("lodlinje", None)


def _trasig(vy, s):
    if vy == "fo":
        s["lodlinje"] = [0.0, -3.217, 0.0]


def _utan_synfalt(vy, s):
    s.pop("format", None)


def _synfalt_ur_enhet(paket: dict) -> dict:
    """FO utan seriens synfält men med enhet.json; DTL utan båda (specifikationen)."""
    _lod(_utan_synfalt)(paket)
    fov = float(np.degrees(2 * np.arctan(960 / 1444.0)))
    paket["fo"]["enhet"] = json.dumps({"modell": "pahittad", "ios": "18.2", "valt_index": 7, "format": [
        {"index": 3, "width": 1920, "height": 1080, "fieldOfView": 40.0},
        {"index": 7, "width": 1920, "height": 1080, "fieldOfView": fov}]})
    return paket


def _detection_wrong(paket: dict) -> dict:
    """Två slag märkta "Detection wrong" och ett "inte_sving": de mäts inte (MK1)."""
    _fyra_slag(paket)

    def fo(m):
        m["slag"][0]["detection_wrong"] = True

    def dtl(m):
        m["slag"][1]["detection_wrong"] = True
        m["slag"][2]["dom"] = "inte_sving"
    _manifest(paket, "fo", fo)
    _manifest(paket, "dtl", dtl)
    return paket


def _par(f):
    def g(paket: dict) -> dict:
        pj = json.loads(paket["dtl"]["par"])
        f(pj)
        paket["dtl"]["par"] = json.dumps(pj)
        return paket
    return g


def _osaker(pj: dict) -> None:
    pj["serier"][0]["osaker"] = True
    pj["serier"][0]["forskjutning_s"] += 3.0


def _annat_pass(pj: dict) -> None:
    pj["serier"][0]["foljare"]["pass"] = "20261103-170000"


def _trasig_par(paket: dict) -> dict:
    paket["dtl"]["par"] = '{"format": "swinglab-par/1"'
    return paket


def _utan_par(paket: dict) -> dict:
    paket["dtl"]["par"] = None
    return paket


# Facit: (indata, varianter).
FACIT = {
    "utan_brus": ("utan_brus", {"grund": None}),
    "lodlinje": ("utan_brus", {"grund": _fyra_slag, "utan_lodlinje": _lod(_utan), "vriden_30": _lod(_vrid(30.0)),
                               "vand": _lod(_vand), "trasig_fo": _lod(_trasig), "synfalt_ur_enhet": _synfalt_ur_enhet,
                               "detection_wrong": _detection_wrong}),
    "bra_brus_vanster": ("bra_brus_vanster", {"grund": None}),
    "sparren": ("sparren", {"grund": None}),
    "tva_serier": ("tva_serier", {"grund": None, "utan_par": _utan_par}),
}

PARNING = {
    "dtl_styr": ({"brus": "inget", "seed": 3, "n": 4},
                 {"grund": None, "osaker": _par(_osaker), "annat_pass": _par(_annat_pass),
                  "trasig": _trasig_par, "utan": _utan_par}),
    "fo_styr": ({"brus": "inget", "seed": 3, "n": 4, "styr": "fo"}, {"grund": None}),
}


def _manifest_fel() -> list[tuple[str, object]]:
    """Trasiga manifest: (namn, ändring på manifestet)."""
    def satt(nyckel, v):
        return lambda m: m.__setitem__(nyckel, v)

    def slag(i, nyckel, v):
        return lambda m: m["slag"][i].__setitem__(nyckel, v)

    def serie(nyckel, v):
        return lambda m: m["serier"][0].__setitem__(nyckel, v)
    return [
        ("format", satt("format", "swinglab-paket/9")),
        ("pass", satt("pass", "2026-11-03")),
        ("vy", satt("vy", "sidan")),
        ("spelhand_bool", satt("spelhand", True)),
        ("avstand_for_langt", satt("avstand_m", 25.0)),
        ("avstand_bool", satt("avstand_m", True)),
        ("langd", satt("spelarens_langd_m", 3.5)),
        ("serier_inte_lista", satt("serier", {"nr": 1})),
        ("serie_nr_decimal", serie("nr", 1.5)),
        ("serie_nr_bool", serie("nr", True)),
        ("klubba_tal", serie("klubba", 7)),
        ("fonster_baklanges", serie("fonster", {"fran_s": 5.0, "till_s": 2.0})),
        ("fonster_utan_slagen", serie("fonster", {"fran_s": 0.0, "till_s": 1.0})),
        ("utsnitt_utanfor", serie("utsnitt", {"x": 0.5, "y": 0.0, "b": 0.7, "h": 1.0})),
        ("slag_tom", satt("slag", [])),
        ("slag_id", slag(0, "id", "x1")),
        ("slag_id_dubbelt", slag(1, "id", "s01")),
        ("slag_serie_saknas", slag(0, "serie", 9)),
        ("klick_text", slag(0, "klick_s", "12,5")),
        ("klick_bool", slag(0, "klick_s", False)),
        ("traff_text", slag(0, "traff_s", "x")),
        ("detection_wrong_text", slag(0, "detection_wrong", "ja")),
        ("dom", slag(0, "dom", "kanske")),
        ("leder_utanfor", slag(0, "leder", "../slag/s01.json")),
        ("leder_saknas", slag(0, "leder", "slag/s99.json")),
        ("klipp_utan_tid", slag(0, "klipp", "slag/s01.json")),
        ("klipp_langd", lambda m: m["slag"][0].update(klipp="slag/s01.json", klick_i_klipp_s=2.5, klipp_langd_s=-1)),
        ("slag_inte_objekt", lambda m: m["slag"].__setitem__(0, 7)),
    ]


# --- kompakt form ---------------------------------------------------------------

def _b64(fmt: str, tal: list[int]) -> str:
    return base64.b64encode(struct.pack(f"<{len(tal)}{fmt}", *tal)).decode("ascii")


def _ur_b64(fmt: str, text: str) -> list[int]:
    b = base64.b64decode(text)
    n = len(b) // struct.calcsize(fmt)
    return list(struct.unpack(f"<{n}{fmt}", b))


def kompakt(js: dict) -> dict:
    """En JointSeries → {width, height, t, j} (modulens text)."""
    t, j = [], []
    for r in js["frames"]:
        t.append(round(r["t"] * 1e4))
        assert abs(t[-1] / 1e4 - r["t"]) < 1e-9, "tiden har fler än fyra decimaler"
        for led in r["joints"]:
            if led is None:
                j += [0, 0, 0]
                continue
            x, y, c = (led["x"], led["y"], led["c"]) if isinstance(led, dict) else led
            v = [round(x * 10), round(y * 10), round(c * 1000)]
            assert abs(v[0] / 10 - x) < 1e-9 and abs(v[1] / 10 - y) < 1e-9 and abs(v[2] / 1000 - c) < 1e-9
            assert v[2] > 0 and all(-32768 <= x <= 32767 for x in v)
            j += v
    return {"width": js["width"], "height": js["height"], "t": _b64("i", t), "j": _b64("h", j)}


def ur_kompakt(k: dict) -> dict:
    """{width, height, t, j} → en JointSeries med samma tal som paketet bar."""
    t = _ur_b64("i", k["t"])
    j = _ur_b64("h", k["j"])
    frames = []
    for i, ti in enumerate(t):
        leder = []
        for m in range(13):
            x, y, c = j[(i * 13 + m) * 3:(i * 13 + m) * 3 + 3]
            leder.append(None if c == 0 else {"x": x / 10, "y": y / 10, "c": c / 1000})
        frames.append({"t": ti / 1e4, "pts": 0.0, "joints": leder, "confidence": 0.9})
    return {"source": "pahittad-3d-r1", "width": k["width"], "height": k["height"], "frames": frames}


# --- paketen ----------------------------------------------------------------------

def _las_zip(fil: Path, med_leder: bool) -> dict:
    with zipfile.ZipFile(fil) as z:
        namn = sorted(z.namelist())
        m = z.read("manifest.json").decode()
        ut = {"manifest": json.dumps(json.loads(m), ensure_ascii=False),
              "par": z.read("par.json").decode() if "par.json" in namn else None,
              "enhet": z.read("enhet.json").decode() if "enhet.json" in namn else None}
        if med_leder:
            ut["filer"] = namn
            ut["leder"] = {s["id"]: kompakt(json.loads(z.read(s["leder"]))) for s in json.loads(m)["slag"]}
    return ut


def skriv_zip(paket: dict, leder: dict | None, fil: Path) -> Path:
    """Ett paket ur fixturens form (manifest, par, enhet och kompakta leder)."""
    m = json.loads(paket["manifest"])
    with zipfile.ZipFile(fil, "w", zipfile.ZIP_STORED) as z:
        z.writestr("manifest.json", paket["manifest"])
        for s in m["slag"]:
            js = ur_kompakt(leder[s["id"]]) if leder else {"width": 1080, "height": 1920, "frames": [
                {"t": 0.0, "pts": 0.0, "joints": [None] * 13, "confidence": 0.0}]}
            z.writestr(s["leder"], json.dumps(js))
        if paket.get("par") is not None:
            z.writestr("par.json", paket["par"])
        if paket.get("enhet") is not None:
            z.writestr("enhet.json", paket["enhet"])
    return fil


def _filerna(paket: dict) -> dict:
    return {vy: {k: paket[vy][k] for k in ("manifest", "par", "enhet")} for vy in ("dtl", "fo")}


def _variant(bas: dict, f) -> dict:
    p = json.loads(json.dumps(_filerna(bas)))
    return f(p) if f else p


def _andra(bas: dict, ny: dict) -> dict:
    """Det som skiljer varianten från grundpaketen, per vy och fil."""
    ut = {}
    for vy in ("dtl", "fo"):
        d = {k: ny[vy][k] for k in ("manifest", "par", "enhet") if ny[vy][k] != bas[vy][k]}
        if d:
            ut[vy] = d
    return ut


def paketen(indata: dict, andra: dict, mapp: Path, med_leder: bool = True):
    """Ett pass paket med en variants ändringar, lästa med paket.las: (dtl, fo)."""
    bas = indata["paket"]
    ut = []
    for vy in ("dtl", "fo"):
        p = dict(_filerna(bas)[vy], **andra.get(vy, {}))
        fil = skriv_zip(p, bas[vy]["leder"] if med_leder else None, mapp / f"{indata['namn']}-{vy}.zip")
        ut.append(P.las(fil, med_leder=med_leder))
    return ut


def rader(indata: dict) -> list[dict]:
    return [{"vy": r["vy"], "id": r["id"], "faser": {"start": r["start"], "topp": r["topp"]}} for r in indata["rader"]]


def _rakna(indata: dict, andra: dict, mapp: Path, minne: dict | None = None) -> dict:
    dtl, fo = paketen(indata, andra, mapp)
    inre: list = []
    try:
        r = TK.analysera(dtl, fo, rader(indata), inre, minne)
    except TK.TreDFel as e:
        return {"python": {"hoppat": str(e)}, "inre": inre}
    return {"python": r, "inre": inre}


def _rena(x):
    """NaN → None, numpy-tal → Python-tal, så att JSON blir giltig."""
    if isinstance(x, dict):
        return {k: _rena(v) for k, v in x.items()}
    if isinstance(x, (list, tuple)):
        return [_rena(v) for v in x]
    if isinstance(x, (np.floating, float)):
        return float(x) if math.isfinite(x) else None
    if isinstance(x, np.integer):
        return int(x)
    if isinstance(x, np.bool_):
        return bool(x)
    return x


# Tal jämförs inom så mycket (relativt, absolut): numpy och OpenBLAS räknar olika sista
# bitar på olika processorer (Actions byter maskin mellan körningarna), och skillnaden växer
# i Levenberg–Marquardts iterationer som mellan Swift och Python (METOD M50).
TOL = (1e-6, 1e-5)


def lika(a, b, vag: str = "", tol: tuple[float, float] = TOL) -> list[str]:
    """Skillnaderna mellan två JSON-värden; tal inom `tol`, allt annat exakt."""
    if isinstance(a, dict) and isinstance(b, dict):
        if set(a) != set(b):
            return [f"{vag}: nycklarna skiljer"]
        return [f for k in a for f in lika(a[k], b[k], f"{vag}.{k}", tol)]
    if isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            return [f"{vag}: längden skiljer"]
        return [f for i, (x, y) in enumerate(zip(a, b)) for f in lika(x, y, f"{vag}[{i}]", tol)]
    if isinstance(a, (int, float)) and isinstance(b, (int, float)) and not isinstance(a, bool) \
            and not isinstance(b, bool):
        return [] if math.isclose(a, b, rel_tol=tol[0], abs_tol=tol[1]) else [f"{vag}: talet skiljer ({a} mot {b})"]
    return [] if a == b else [f"{vag}: skiljer"]


def storsta_skillnad(a, b) -> float:
    """Den största absoluta skillnaden mellan två JSON-värdens tal (samma form)."""
    if isinstance(a, dict) and isinstance(b, dict):
        return max([storsta_skillnad(a[k], b[k]) for k in a if k in b] or [0.0])
    if isinstance(a, list) and isinstance(b, list):
        return max([storsta_skillnad(x, y) for x, y in zip(a, b)] or [0.0])
    if isinstance(a, (int, float)) and isinstance(b, (int, float)) and not isinstance(a, bool) \
            and not isinstance(b, bool):
        return abs(a - b)
    return 0.0


# --- att bygga ------------------------------------------------------------------------

def bygg_indata(namn: str, mapp: Path) -> dict:
    kw, faser = PASS_INDATA[namn]
    kw = dict(kw)
    n = kw.pop("n")
    d, f, facit = G.tva_paket(mapp / namn, PASS, n=n, **kw)
    pd, pf = P.las(d), P.las(f)
    rad = []
    for r in A.mat_paket(pd, LANGD_M) + A.mat_paket(pf, LANGD_M):
        fs = dict({"start": (r.get("faser") or {}).get("start"), "topp": (r.get("faser") or {}).get("topp")},
                  **faser.get((r["vy"], r["id"]), {}))
        rad.append({"vy": r["vy"], "id": r["id"], **fs})
    return _rena({"om": OM, "namn": namn, "kalla": dict(kw, n=n), "langd_m": LANGD_M,
                  "paket": {"dtl": _las_zip(d, True), "fo": _las_zip(f, True)}, "rader": rad, "sant": facit})


def bygg_facit(namn: str, indata: dict, mapp: Path) -> dict:
    _, varianter = FACIT[namn]
    ut = {"om": OM, "indata": indata["namn"], "varianter": {}}
    minne: dict = {}
    for v, fn in varianter.items():
        andra = _andra(indata["paket"], _variant(indata["paket"], fn))
        ut["varianter"][v] = {"andra": andra, **_rakna(indata, andra, mapp, minne)}
    return _rena(ut)


def bygg_parning(mapp: Path) -> dict:
    ut = {"om": OM, "pass": {}}
    for namn, (kw, varianter) in PARNING.items():
        kw = dict(kw)
        n = kw.pop("n")
        d, f, _ = G.tva_paket(mapp / f"parning-{namn}", PASS, n=n, **kw)
        indata = {"namn": namn, "paket": {"dtl": _las_zip(d, False), "fo": _las_zip(f, False)}}
        ut["pass"][namn] = {"paket": indata["paket"], "varianter": {}}
        for v, fn in varianter.items():
            andra = _andra(indata["paket"], _variant(indata["paket"], fn))
            dtl, fo = paketen(indata, andra, mapp, med_leder=False)
            par, info = TK.para_slag(dtl, fo)
            ut["pass"][namn]["varianter"][v] = {"andra": andra, "par": [[a.id, b.id] for a, b in par], "info": info}
    return _rena(ut)


def bygg_manifest_fel(indata: dict) -> dict:
    """Trasiga varianter av ett manifest och felen ur paket._kontrollera_manifest."""
    bas = json.loads(indata["paket"]["dtl"]["manifest"])
    filer = indata["paket"]["dtl"]["filer"]
    fall = []
    for namn, f in _manifest_fel():
        m = json.loads(json.dumps(bas))
        f(m)
        fall.append({"namn": namn, "manifest": json.dumps(m, ensure_ascii=False),
                     "fel": P._kontrollera_manifest(m, set(filer))})
    return {"om": OM, "indata": indata["namn"], "filer": filer, "fall": fall}


def komponenter(indata: dict, mapp: Path) -> dict:
    """Delstegen för passets första par, så att en avvikelse i Swift går att hitta: spåren,
    de robusta vikterna, utjämningen, en kalibrering på klicket, synken, trianguleringen
    och vinkelkurvorna (METOD M50)."""
    from .tre_d import matt as M3
    from .tre_d import triangulering as TRI
    dtl, fo = paketen(indata, {}, mapp)
    par, _ = TK.para_slag(dtl, fo)
    grupp = []
    for sd, sf in par:
        tA, uvA, kA = TK.spar(fo, sf)
        tB, uvB, kB = TK.spar(dtl, sd)
        (KA, _), (KB, _) = TK.K_for(fo, sf), TK.K_for(dtl, sd)
        grupp.append({"dtl": sd, "fo": sf, "tA": tA, "uvA": uvA, "kA": kA, "tB": tB, "uvB": uvB, "kB": kB,
                      "KA": KA, "KB": KB, "traffA": P.traff_i_serien(fo, sf), "traffB": P.traff_i_serien(dtl, sd)})
    d = grupp[0]
    w0, w = TRI.robusta_vikter(d["tA"], d["uvA"], d["kA"], TK.HALVBREDD_2D)
    t_g, a, ka, b, kb = TK._jamnade(d, 0.0)
    val = [0, len(t_g) // 3, 2 * len(t_g) // 3, len(t_g) - 1]
    R, t, upp, info = TK.kalibrera(grupp, [0.0] * len(grupp), None, None)
    kamA, kamB = TK.kameror(d, R, t, upp)
    forsk = TK.synka(kamA, kamB, d, 0.0, TK.SYNK_SOK_S)
    tg, P3, rep = TK.triangulera(kamA, kamB, d, forsk)
    pv, sv = M3.vridningar(P3, tg, (-1.2, -0.9))
    ii = [min(i, len(tg) - 1) for i in val]
    return _rena({
        "om": OM, "pass": indata["namn"], "par": [d["dtl"].id, d["fo"].id],
        "spar_a": {"n": len(d["tA"]), "t": d["tA"][:3].tolist()},
        "vikter_a": {"w_summa": w.sum(0).tolist(), "w0_summa": w0.sum(0).tolist()},
        "jamnade": {"n": len(t_g), "t0": float(t_g[0]), "index": val, "a": a[val].tolist(), "ka": ka[val].tolist(),
                    "b": b[val].tolist(), "kb": kb[val].tolist()},
        "kalibrering": {"R": R.tolist(), "t": t.tolist(), "upp": upp.tolist(), "sampson_px": info["sampson_px"]},
        "synk": forsk,
        "triangulering": {"n": len(tg), "index": val, "P": P3[ii].tolist(), "rep": rep},
        "vinklar": {"adress": [-1.2, -0.9], "index": val, "backen": pv[ii].tolist(), "brost": sv[ii].tolist()},
    })


def _skriv(fil: Path, d: dict) -> None:
    fil.parent.mkdir(parents=True, exist_ok=True)
    fil.write_text(json.dumps(d, ensure_ascii=False, allow_nan=False, indent=1) + "\n", encoding="utf-8")
    print(fil)


# --- att räkna om (testet och --kontroll) ---------------------------------------------

@functools.lru_cache(maxsize=None)
def las_indata(namn: str) -> dict:
    return json.loads((INDATA / f"{namn}.json").read_text(encoding="utf-8"))


def las(namn: str) -> dict:
    return json.loads((MAPP / f"{namn}.json").read_text(encoding="utf-8"))


_MINNE: dict = {}


def _om_ett(jobb: tuple[str, str]) -> tuple[str, str, list[str]]:
    """Räknar om en variant ur sin fixtur (eller delstegen) och svarar skillnaderna mot det
    som står."""
    namn, v = jobb
    if namn == "komponenter":
        k = las(namn)
        mapp = Path(tempfile.mkdtemp())
        try:
            return namn, v, lika(komponenter(las_indata(k["pass"]), mapp), k, namn)
        finally:
            shutil.rmtree(mapp, ignore_errors=True)
    fx = las(namn)
    indata = las_indata(fx["indata"])
    mapp = Path(tempfile.mkdtemp())
    try:
        r = _rena(_rakna(indata, fx["varianter"][v]["andra"], mapp, _MINNE.setdefault(fx["indata"], {})))
    finally:
        shutil.rmtree(mapp, ignore_errors=True)
    var = fx["varianter"][v]
    fel = lika(r["python"], var["python"], f"{namn}/{v}") + lika(r["inre"], var["inre"], f"{namn}/{v} inre")
    skillnad = max(storsta_skillnad(r["python"], var["python"]), storsta_skillnad(r["inre"], var["inre"]))
    return namn, v, fel + [f"TRED-PY största skillnad {namn}/{v} {skillnad:.2g}"]


def rakna_om(processer: int = 4) -> list[str]:
    """Alla fixturers varianter och delstegen omräknade, parallellt: skillnaderna mot det
    som står."""
    def slag(namn: str, v: str) -> int:
        fx = las(namn)
        m = fx["varianter"][v]["andra"].get("dtl", {}).get("manifest") \
            or las_indata(fx["indata"])["paket"]["dtl"]["manifest"]
        return len(json.loads(m)["slag"])
    # De längsta först, så att processerna blir klara samtidigt; minnet för spåren och
    # vikterna gäller varianterna av samma pass i samma process.
    jobb = sorted(((namn, v) for namn in FACIT for v in las(namn)["varianter"]), key=lambda x: (-slag(*x), x))
    jobb.insert(4, ("komponenter", ""))
    with Pool(processer) as pool:
        ut = [f for _, _, fel in pool.map(_om_ett, jobb, chunksize=1) for f in fel]
    for f in ut:
        if f.startswith("TRED-PY"):
            print(f, file=sys.stderr)
    return [f for f in ut if not f.startswith("TRED-PY")]


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--kontroll", action="store_true", help="räkna om fixturerna och jämför")
    a = ap.parse_args(argv)
    if a.kontroll:
        fel = rakna_om()
        print("\n".join(fel) if fel else "OK")
        return 1 if fel else 0
    tmp = Path(tempfile.mkdtemp())
    try:
        indata = {namn: bygg_indata(namn, tmp) for namn in PASS_INDATA}
        for namn, d in indata.items():
            _skriv(INDATA / f"{namn}.json", d)
        for namn, (pass_namn, _) in FACIT.items():
            _skriv(MAPP / f"{namn}.json", bygg_facit(namn, indata[pass_namn], tmp))
        _skriv(MAPP / "parning.json", bygg_parning(tmp))
        _skriv(MAPP / "manifest_fel.json", bygg_manifest_fel(indata["utan_brus"]))
        _skriv(MAPP / "komponenter.json", komponenter(indata["bra_brus_vanster"], tmp))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
