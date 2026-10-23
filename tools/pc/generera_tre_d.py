"""Facit för 3D på telefonen (S6c-1, BESLUT B12, B48): påhittade tvåpaketspass och
Pythons tal, som SwingLabKit:s `TreD` ska räkna likadant.

    python3 tools/pc/generera_tre_d.py            # skriver tools/tests/fixturer/tre_d/*.json
    python3 tools/pc/generera_tre_d.py --kontroll # räknar om och jämför (som testet)

Passen kommer ur `generera_paket.tva_paket` (S6a, METOD MK8): 3D-svingar filmade av
en FO- och en DTL-kamera med felbudgetens brus. Inga riktiga leder (CLAUDE.md,
Dataregeln). Varje fixtur bär

- `paket`: per vy manifestet (som JSON), `par.json` och `enhet.json` som text (eller
  null), och lederna per slag kompakt: tiderna som int32 i 1e-4 s och lederna som
  int16 (x och y i 0,1 px, konfidensen i 0,001; 0 = saknad), båda base64 i
  little endian. Paketen avrundar redan till de stegen, så inget går förlorat.
- `rader`: 2D-fasernas start och topp per slag (analys.mat_paket), indata till 3D.
- `sant`: de sanna måtten (facit för kedjan, MK8).
- `varianter`: ändringar i manifest eller `par.json` och Pythons `tre_d` för dem, med
  de oavrundade talen per uppställning (`inre`: R, t, uppåt, synken och
  återprojektionen).

Parningens fixtur (`parning.json`) bär bara manifesten (inga leder) och
`para_slag`:s svar för varje variant. Formen står i docs/FORMAT.md "Facit för 3D".
"""
from __future__ import annotations

import argparse
import base64
import json
import math
import shutil
import struct
import sys
import tempfile
import zipfile
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
PASS = "20261103-180000"
LANGD_M = 1.80

# Passen: (namn, tva_paket-argument, varianter). Varianterna är funktioner på
# {vy: {"manifest": dict, "par": text | None, "enhet": text | None}} → samma form.


def _vrid_lodlinje(grader: float):
    a = math.radians(grader)

    def f(paket: dict) -> dict:
        for vy in ("dtl", "fo"):
            v = paket[vy]["manifest"]["serier"][0]["lodlinje"]
            paket[vy]["manifest"]["serier"][0]["lodlinje"] = [v[0] * math.cos(a) - v[1] * math.sin(a),
                                                              v[0] * math.sin(a) + v[1] * math.cos(a), v[2]]
        return paket
    return f


def _vand_lodlinje(paket: dict) -> dict:
    for vy in ("dtl", "fo"):
        s = paket[vy]["manifest"]["serier"][0]
        s["lodlinje"] = [-x for x in s["lodlinje"]]
    return paket


def _utan_lodlinje(paket: dict) -> dict:
    for vy in ("dtl", "fo"):
        paket[vy]["manifest"]["serier"][0].pop("lodlinje", None)
    return paket


def _trasig_lodlinje(paket: dict) -> dict:
    paket["fo"]["manifest"]["serier"][0]["lodlinje"] = [0.0, -3.217, 0.0]
    return paket


def _utan_synfalt_med_enhet(paket: dict) -> dict:
    """FO utan seriens synfält men med enhet.json; DTL utan båda (specifikationen)."""
    for vy in ("dtl", "fo"):
        paket[vy]["manifest"]["serier"][0].pop("format", None)
    fov = float(np.degrees(2 * np.arctan(960 / 1444.0)))
    paket["fo"]["enhet"] = json.dumps({"modell": "pahittad", "ios": "18.2", "valt_index": 7, "format": [
        {"index": 3, "width": 1920, "height": 1080, "fieldOfView": 40.0},
        {"index": 7, "width": 1920, "height": 1080, "fieldOfView": fov}]})
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


def _detection_wrong(paket: dict) -> dict:
    """Två slag märkta "Detection wrong" och ett "inte_sving": de mäts inte (MK1)."""
    paket["fo"]["manifest"]["slag"][0]["detection_wrong"] = True
    paket["dtl"]["manifest"]["slag"][1]["detection_wrong"] = True
    paket["dtl"]["manifest"]["slag"][2]["dom"] = "inte_sving"
    return paket


PASSEN = {
    # Utan brus, högerspelare, par.json i DTL:s paket: kedjan är exakt (MK8).
    "utan_brus": ({"brus": "inget", "seed": 5, "n": 10}, {"grund": None}),
    # Bra brus, vänsterspelare, lodlinjen i manifestet och utan par.json (parning på klicken).
    "bra_brus_vanster": ({"brus": "bra", "seed": 31, "n": 10, "hand": "vanster", "lodlinje": True,
                          "par_json": False}, {"grund": None}),
    # Fyra slag utan brus med lodlinjen: lodlinjens och brännviddens vägar (MK3).
    "lodlinje": ({"brus": "inget", "seed": 3, "n": 4, "lodlinje": True},
                 {"grund": None, "utan_lodlinje": _utan_lodlinje, "vriden_30": _vrid_lodlinje(30.0),
                  "vand": _vand_lodlinje, "trasig_fo": _trasig_lodlinje,
                  "synfalt_ur_enhet": _utan_synfalt_med_enhet, "detection_wrong": _detection_wrong}),
    # Mycket dåligt brus: Sampson-felet över spärren, ingen serie mäts (MK3).
    "sparren": ({"brus": "mycket_daligt", "seed": 3, "n": 4}, {"grund": None}),
}

PARNING = {
    "dtl_styr": ({"brus": "inget", "seed": 3, "n": 4},
                 {"grund": None, "osaker": _par(_osaker), "annat_pass": _par(_annat_pass),
                  "trasig": _trasig_par, "utan": _utan_par}),
    "fo_styr": ({"brus": "inget", "seed": 3, "n": 4, "styr": "fo"}, {"grund": None}),
}


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
        namn = set(z.namelist())
        m = json.loads(z.read("manifest.json"))
        ut = {"manifest": m, "par": z.read("par.json").decode() if "par.json" in namn else None,
              "enhet": z.read("enhet.json").decode() if "enhet.json" in namn else None}
        if med_leder:
            ut["leder"] = {s["id"]: kompakt(json.loads(z.read(s["leder"]))) for s in m["slag"]}
    return ut


def skriv_zip(paket: dict, leder: dict | None, fil: Path) -> Path:
    """Ett paket ur fixturens form (manifest, par, enhet och kompakta leder)."""
    with zipfile.ZipFile(fil, "w", zipfile.ZIP_STORED) as z:
        z.writestr("manifest.json", json.dumps(paket["manifest"]))
        for s in paket["manifest"]["slag"]:
            js = ur_kompakt(leder[s["id"]]) if leder else {"width": 1080, "height": 1920, "frames": [
                {"t": 0.0, "pts": 0.0, "joints": [None] * 13, "confidence": 0.0}]}
            z.writestr(s["leder"], json.dumps(js))
        if paket.get("par") is not None:
            z.writestr("par.json", paket["par"])
        if paket.get("enhet") is not None:
            z.writestr("enhet.json", paket["enhet"])
    return fil


def _variant(bas: dict, f) -> dict:
    p = json.loads(json.dumps({vy: {k: v for k, v in bas[vy].items() if k != "leder"} for vy in ("dtl", "fo")}))
    return f(p) if f else p


def _andra(bas: dict, ny: dict) -> dict:
    """Det som skiljer varianten från grundpaketen, per vy och fil."""
    ut = {}
    for vy in ("dtl", "fo"):
        d = {k: ny[vy][k] for k in ("manifest", "par", "enhet") if ny[vy][k] != bas[vy][k]}
        if d:
            ut[vy] = d
    return ut


def paketen(fixtur: dict, variant: str, mapp: Path, med_leder: bool = True):
    """Fixturens paket för en variant, lästa med paket.las: (dtl, fo)."""
    bas = fixtur["paket"]
    ut = []
    for vy in ("dtl", "fo"):
        p = dict({k: bas[vy][k] for k in ("manifest", "par", "enhet")}, **fixtur["varianter"][variant]["andra"].get(vy, {}))
        fil = skriv_zip(p, bas[vy]["leder"] if med_leder else None, mapp / f"{variant}-{vy}.zip")
        ut.append(P.las(fil, med_leder=med_leder))
    return ut


def rader(fixtur: dict) -> list[dict]:
    return [{"vy": r["vy"], "id": r["id"], "faser": {"start": r["start"], "topp": r["topp"]}} for r in fixtur["rader"]]


def _rakna(fixtur: dict, variant: str, mapp: Path) -> dict:
    dtl, fo = paketen(fixtur, variant, mapp)
    inre: list = []
    try:
        r = TK.analysera(dtl, fo, rader(fixtur), inre)
    except TK.TreDFel as e:
        return {"python": {"hoppat": str(e)}, "inre": inre}
    return {"python": r, "inre": inre}


def _rakna_parning(fixtur: dict, variant: str, mapp: Path) -> dict:
    dtl, fo = paketen(fixtur, variant, mapp, med_leder=False)
    par, info = TK.para_slag(dtl, fo)
    return {"par": [[a.id, b.id] for a, b in par], "info": info}


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


def bygg(namn: str, kw: dict, varianter: dict, mapp: Path, parning: bool = False) -> dict:
    kw = dict(kw)
    n = kw.pop("n")
    d, f, facit = G.tva_paket(mapp / namn, PASS, n=n, **kw)
    bas = {"dtl": _las_zip(d, not parning), "fo": _las_zip(f, not parning)}
    fixtur = {"om": "PÅHITTAT (CLAUDE.md, Dataregeln). Genererad av tools/pc/generera_tre_d.py; ändra inte för hand.",
              "namn": namn, "kalla": dict(kw, n=n), "langd_m": LANGD_M, "paket": bas, "varianter": {}}
    if not parning:
        pd, pf = P.las(d), P.las(f)
        fixtur["rader"] = [{"vy": r["vy"], "id": r["id"],
                            "start": (r.get("faser") or {}).get("start"), "topp": (r.get("faser") or {}).get("topp")}
                           for r in A.mat_paket(pd, LANGD_M) + A.mat_paket(pf, LANGD_M)]
        fixtur["sant"] = facit
    for v, fn in varianter.items():
        ny = _variant(bas, fn)
        fixtur["varianter"][v] = {"andra": _andra(bas, ny)}
        fixtur["varianter"][v].update(_rakna_parning(fixtur, v, mapp) if parning else _rakna(fixtur, v, mapp))
    return _rena(fixtur)


def komponenter(fixtur: dict, mapp: Path) -> dict:
    """Delstegen för passets första par, så att en avvikelse i Swift går att hitta: spåren,
    de robusta vikterna, utjämningen, en kalibrering på klicket, synken, trianguleringen
    och vinkelkurvorna (METOD M50)."""
    from .tre_d import matt as M3
    from .tre_d import triangulering as TRI
    dtl, fo = paketen(fixtur, "grund", mapp)
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
    return _rena({
        "par": [d["dtl"].id, d["fo"].id],
        "spar_a": {"n": len(d["tA"]), "t": d["tA"][:3].tolist(), "uv": d["uvA"][:3].tolist(), "k": d["kA"][:3].tolist()},
        "vikter_a": {"w_summa": w.sum(0).tolist(), "w0_summa": w0.sum(0).tolist(), "w_rad": w[len(w) // 2].tolist()},
        "jamnade": {"n": len(t_g), "t0": float(t_g[0]), "index": val, "a": a[val].tolist(), "ka": ka[val].tolist(),
                    "b": b[val].tolist(), "kb": kb[val].tolist()},
        "kalibrering": {"R": R.tolist(), "t": t.tolist(), "upp": upp.tolist(), "sampson_px": info["sampson_px"]},
        "synk": forsk,
        "triangulering": {"n": len(tg), "index": val, "P": P3[[min(i, len(tg) - 1) for i in val]].tolist(),
                          "rep": rep},
        "vinklar": {"adress": [-1.2, -0.9], "index": val, "backen": pv[[min(i, len(tg) - 1) for i in val]].tolist(),
                    "brost": sv[[min(i, len(tg) - 1) for i in val]].tolist()},
    })


def alla(mapp: Path) -> dict[str, dict]:
    ut = {namn: bygg(namn, kw, v, mapp) for namn, (kw, v) in PASSEN.items()}
    ut["komponenter"] = {"om": "PÅHITTAT (CLAUDE.md, Dataregeln). Genererad av tools/pc/generera_tre_d.py.",
                         "pass": "bra_brus_vanster", **komponenter(ut["bra_brus_vanster"], mapp)}
    ut["parning"] = {"om": "PÅHITTAT (CLAUDE.md, Dataregeln). Genererad av tools/pc/generera_tre_d.py.",
                     "pass": {namn: bygg(namn, kw, v, mapp, parning=True) for namn, (kw, v) in PARNING.items()}}
    return ut


def rakna_om(fixtur: dict, mapp: Path) -> dict[str, dict]:
    """Pythons svar på fixturens egna indata, per variant (testet jämför med det som står)."""
    return {v: _rena(_rakna(fixtur, v, mapp)) for v in fixtur["varianter"]}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--kontroll", action="store_true", help="räkna om fixturerna och jämför")
    a = ap.parse_args(argv)
    tmp = Path(tempfile.mkdtemp())
    try:
        if a.kontroll:
            fel = 0
            for fil in sorted(MAPP.glob("*.json")):
                if fil.stem in ("parning", "komponenter"):
                    continue
                fx = json.loads(fil.read_text(encoding="utf-8"))
                for v, r in rakna_om(fx, tmp).items():
                    if r["python"] != fx["varianter"][v]["python"]:
                        print(f"{fil.name}: {v} är inte Pythons tal längre")
                        fel += 1
            return 1 if fel else 0
        MAPP.mkdir(parents=True, exist_ok=True)
        for namn, fx in alla(tmp).items():
            (MAPP / f"{namn}.json").write_text(json.dumps(fx, ensure_ascii=False, allow_nan=False,
                                                          separators=(",", ":")) + "\n", encoding="utf-8")
            print(MAPP / f"{namn}.json")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
