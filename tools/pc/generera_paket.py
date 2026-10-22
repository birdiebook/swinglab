"""Påhittade sessionspaket (S2_SPEC §8.3) för testerna och skillens exempel.
Inga riktiga leder eller klipp (CLAUDE.md, Dataregeln).

    python3 tools/pc/generera_paket.py <ut-mapp> --pass 20261103-180000 --vy fo [--slag 8]
        [--sway-topp -6] [--thrust-traff 3] [--forsta-serien-flytt 0] [--serier 2] [--klipp]

Varje slag är en påhittad sving ur generera.py med kända tal: bäckenets sway vid
toppen (FO) och thrust vid träffen (DTL) sätts per pass, med lite spridning
mellan slagen. `--forsta-serien-flytt` flyttar talet i första serien (de fem
första slagen, METOD MT2), så att retentionen går att prova. Klippen (`--klipp`)
är ffmpegs testbild, utan person, och kräver ffmpeg.

Två telefoner från samma pass (S6a): en påhittad 3D-sving per slag (`tre_d/sving.py`),
filmad av en FO- och en DTL-kamera med bildtider, tappade rutor, 2D-brus och skymning
enligt felbudgeten (docs/S6_FELBUDGET.md), synkfel på klicket och par.json i den
styrande telefonens (DTL:s) paket. Facit (de sanna måtten per slag) skrivs bredvid:

    python3 tools/pc/generera_paket.py <ut-mapp> --pass 20261103-180000 --tva
        [--slag 12] [--brus typiskt] [--utan-par] [--lodlinje] [--vanster]
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

import numpy as np

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "pc"

from . import generera as gen  # noqa: E402
from .analys import FORSTA_SERIEN_SLAG  # noqa: E402
from .format import LEDER_FIL  # noqa: E402
from .faser import ADRESS as F_ADRESS  # noqa: E402
from .paket import FORMAT, LJUDETS_FART  # noqa: E402

AVSTAND_M = 3.0
KLIPP_FORE_S = 2.5          # klippet börjar 2,5 s före klicket (S2_SPEC §8.2)


def leder(d: dict, avstand_m: float, klick_s: float) -> dict:
    """En påhittad sving i filformatet → JointSeries med t relativt klicket."""
    skift = gen.TIDER["klick"] + avstand_m / LJUDETS_FART
    frames = []
    for r in d["rutor"]:
        t = round(r["t"] - skift, 4)
        joints = [None if led[2] <= 0 else {"x": led[0], "y": led[1], "c": led[2]} for led in r["leder"]]
        frames.append({"t": t, "pts": round(klick_s + t, 4), "joints": joints, "confidence": 0.9})
    return {"source": "pahittad-r1", "width": 1080, "height": 1920, "frames": frames}


def _klipp(mapp: Path) -> Path | None:
    """Ett påhittat klipp på 4 s (ffmpegs testbild), eller None utan ffmpeg."""
    if not shutil.which("ffmpeg"):
        return None
    ut = mapp / "klipp.mov"
    r = subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", "testsrc2=size=216x384:rate=60",
                        "-t", "4", "-c:v", "mpeg4", "-q:v", "8", str(ut)], capture_output=True, timeout=120)
    return ut if r.returncode == 0 and ut.is_file() else None


def paket(ut_mapp, pass_id: str, vy: str, n: int = 8, seed: int = 1, sway_topp: float = -6.0,
          thrust_traff: float = 3.0, forsta_serien_flytt: float = 0.0, serier: int = 1, inte_sving: int = 1,
          osaker: int = 0, klipp: bool = False, langd_m: float | None = 1.80, hand: str = "hoger",
          klubba: str = "j7", brus_px: float = 0.8) -> Path:
    """Skriver swinglab-<pass>-<vy>.zip i ut_mapp och svarar med sökvägen."""
    ut_mapp = Path(ut_mapp)
    ut_mapp.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(seed)
    slag, filer = [], {}
    serie_av = (lambda i: 1 if i < FORSTA_SERIEN_SLAG else 2) if serier > 1 else (lambda i: 1)
    totalt = n + inte_sving
    with tempfile.TemporaryDirectory() as tmp:
        klippfil = _klipp(Path(tmp)) if klipp else None
        for i in range(totalt):
            sid = f"s{i + 1:02d}"
            klick_s = round(10.0 + 7.3 * i + float(rng.uniform(0, 1)), 4)
            flytt = forsta_serien_flytt if i < FORSTA_SERIEN_SLAG else 0.0
            if vy == "fo":
                v = sway_topp + flytt + float(rng.normal(0, 0.8))
                d, _ = gen.sving("fo", hand, seed=seed * 100 + i, brus_px=brus_px, decimaler=1,
                                 sway=(0, v, 8 + float(rng.normal(0, 1)), 14))
            else:
                v = thrust_traff + flytt + float(rng.normal(0, 0.6))
                d, _ = gen.sving("dtl", hand, seed=seed * 100 + i, brus_px=brus_px, decimaler=1,
                                 thrust=(0, -2, v, 8))
            dom = "inte_sving" if i >= n else ("osaker" if i < osaker else "sving")
            filer[f"slag/{sid}.json"] = json.dumps(leder(d, AVSTAND_M, klick_s), separators=(",", ":"))
            rad = {"id": sid, "serie": serie_av(i), "klick_s": klick_s, "styrka": 80.0,
                   "traff_s": round(klick_s - AVSTAND_M / LJUDETS_FART, 4), "dom": dom,
                   "andrad_av_johannes": False, "leder": f"slag/{sid}.json"}
            if klippfil:
                rad.update(klipp=f"klipp/{sid}.mov", klick_i_klipp_s=KLIPP_FORE_S)
            slag.append(rad)
        manifest = {
            "format": FORMAT, "skapad": f"{pass_id[:4]}-{pass_id[4:6]}-{pass_id[6:8]}T20:00:00+01:00",
            "app": {"version": "0.0.0", "bygge": "pahittat"}, "pass": pass_id,
            "telefon": {"modell": "pahittad", "ios": "18.2", "roll": "ensam"}, "vy": vy,
            "avstand_m": AVSTAND_M, "spelhand": hand,
            "serier": [{"nr": k, "kalla": "inspelning", "klubba": klubba} for k in range(1, serier + 1)],
            "slag": slag, "vision": {"revision": 1, "ms_per_ruta": 18.0, "glest_steg": 8, "tatt_steg": 1},
            "matt": None}
        if langd_m is not None:
            manifest["spelarens_langd_m"] = langd_m
        fil = ut_mapp / f"swinglab-{pass_id}-{vy}.zip"
        with zipfile.ZipFile(fil, "w", zipfile.ZIP_STORED) as z:
            z.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False, indent=1))
            for namn, text in filer.items():
                z.writestr(namn, text)
            if klippfil:
                for s in slag:
                    z.write(klippfil, s["klipp"])
    return fil


# METOD MK8: facitpassets uppställning (påhittad).
BOLLEN = (0.0, -0.6, 0.0)   # bollens läge i simuleringens värld (tre_d/__init__.py)
T_START_3D = 0.8            # adressen före baksvingen, s (rymmer adressens fönster, METOD M4)
EFTER_3D = 0.7              # efter finishen, s (rymmer finishens fönster, METOD M4)
FOLJ_FORSKJUTNING_S = 12.345    # följarens fil börjar så mycket före den styrandes


class _Spegel:
    """En sving för en vänsterspelare: högerspelarens leder speglade i x (mot
    målet), med vänster och höger bytta (FORMAT.md: vänsterspelaren är spegelvänd)."""

    def __init__(self, s):
        self.s = s
        self.hoftpinne = self.ryggstav = 0.0
        from .tre_d.sving import LEDER
        self.byt = [LEDER.index(("h_" + n[2:]) if n.startswith("v_") else ("v_" + n[2:]) if n.startswith("h_")
                                else n) for n in LEDER]

    def leder(self, t):
        P = self.s.leder(t)[:, self.byt].copy()
        P[..., 0] *= -1
        return P


def _joint_series(t_rel: np.ndarray, klick_s: float, obs: np.ndarray, konf: np.ndarray) -> dict:
    frames = []
    for i, t in enumerate(t_rel):
        joints = [None if not (np.isfinite(obs[i, j]).all() and konf[i, j] > 0) else
                  {"x": round(float(obs[i, j, 0]), 1), "y": round(float(obs[i, j, 1]), 1),
                   "c": round(float(konf[i, j]), 3)} for j in range(obs.shape[1])]
        frames.append({"t": round(float(t), 4), "pts": round(klick_s + float(t), 4), "joints": joints,
                       "confidence": 0.9})
    return {"source": "pahittad-3d-r1", "width": 1080, "height": 1920, "frames": frames}


def tva_paket(ut_mapp, pass_id: str, n: int = 10, seed: int = 1, brus: str = "typiskt", hand: str = "hoger",
              par_json: bool = True, lodlinje: bool = False, langd_m: float = 1.80, synkfel_ms: float = 7.0,
              bara_fo: int = 1, klubba: str = "j7") -> tuple[Path, Path, dict]:
    """Två paket från samma pass (DTL styrande, FO följare) och facit:
    (dtl.zip, fo.zip, {"slag": [{"dtl", "fo", "sant"}], "median": {mått: median av de sanna}}).
    `bara_fo` slag filmas bara av FO (de ska inte paras). METOD MK1–MK7"""
    from dataclasses import replace

    from . import tva_kameror as TK
    from .tre_d import felbudget as FB
    from .tre_d import kalibrering as KAL
    from .tre_d import matt as M3
    from .tre_d import kamera as KM
    from .tre_d.sving import slumpa_sving

    ut_mapp = Path(ut_mapp)
    ut_mapp.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(seed)
    u = replace(FB.Uppstallning(), brus=brus, kalib="perfekt")
    pas = FB.nytt_pass(u, rng)
    kam = {"fo": pas["A"], "dtl": pas["B"]}
    fast = {"fo": pas["fastA"], "dtl": pas["fastB"]}
    avst = {v: float(np.linalg.norm(k.centrum - np.array(BOLLEN))) for v, k in kam.items()}
    filstart = {"dtl": 0.0, "fo": FOLJ_FORSKJUTNING_S}
    filer = {"dtl": {}, "fo": {}}
    slag = {"dtl": [], "fo": []}
    facit = []
    for i in range(n + bara_fo):
        sv = slumpa_sving(rng)
        sv.langd, sv.t_start, sv.efter = langd_m, T_START_3D, EFTER_3D
        sv.__post_init__()
        filmad = sv if hand == "hoger" else _Spegel(sv)
        T0 = 10.0 + 7.3 * i + float(rng.uniform(0, 1))       # svingens t = 0 på en gemensam klocka
        synk = {"dtl": float(rng.uniform(-1, 1)) * synkfel_ms / 1000, "fo": 0.0}
        vyer = ("dtl", "fo") if i < n else ("fo",)
        ids = {}
        for vy in vyer:
            t = KM.bildtider(sv.t_slut, rng)
            obs, konf = FB._observera(kam[vy], filmad, t, u, rng, fast[vy])
            klick_lokal = sv.t_traff + avst[vy] / LJUDETS_FART + synk[vy]
            klick_s = round(T0 + klick_lokal + filstart[vy], 4)
            sid = f"s{len(slag[vy]) + 1:02d}"
            ids[vy] = sid
            filer[vy][f"slag/{sid}.json"] = json.dumps(_joint_series(t - klick_lokal, klick_s, obs, konf),
                                                       separators=(",", ":"))
            slag[vy].append({"id": sid, "serie": 1, "klick_s": klick_s, "styrka": 80.0,
                             "traff_s": round(klick_s - round(avst[vy], 2) / LJUDETS_FART, 4), "dom": "sving",
                             "andrad_av_johannes": False, "leder": f"slag/{sid}.json"})
        if i < n:
            t_s = np.arange(0.05, sv.t_slut - 0.05, 0.001)
            adress = (sv.t_start + F_ADRESS[0], sv.t_start + F_ADRESS[1])
            m = M3.svingmatt(sv.leder(t_s), t_s, sv.t_start, sv.t_traff, adress)
            # synk_ms: hur mycket DTL:s klocka går före FO:s efter klicket (det synken ska hitta)
            facit.append({"dtl": ids["dtl"], "fo": ids["fo"], "sant": {k: m[v] for k, v in TK.MATT.items()},
                          "synk_ms": -synk["dtl"] * 1000})
    roll = {"dtl": "styrande", "fo": "foljare"}
    ut = {}
    for vy in ("dtl", "fo"):
        serie = {"nr": 1, "kalla": "inspelning", "klubba": klubba}
        if lodlinje:
            upp = KAL.slumprotation(FB.Uppstallning().grav_deg, rng) @ (kam[vy].R @ np.array([0.0, 0.0, 1.0]))
            serie["lodlinje"] = [round(float(x), 4) for x in upp]
        manifest = {
            "format": FORMAT, "skapad": f"{pass_id[:4]}-{pass_id[4:6]}-{pass_id[6:8]}T20:00:00+01:00",
            "app": {"version": "0.0.0", "bygge": "pahittat"}, "pass": pass_id,
            "telefon": {"modell": "pahittad", "ios": "18.2", "roll": roll[vy]}, "vy": vy,
            "avstand_m": round(avst[vy], 2), "spelhand": hand, "spelarens_langd_m": langd_m,
            "serier": [serie], "slag": slag[vy],
            "vision": {"revision": 1, "ms_per_ruta": 18.0, "glest_steg": 8, "tatt_steg": 1}, "matt": None}
        fil = ut_mapp / f"swinglab-{pass_id}-{vy}.zip"
        with zipfile.ZipFile(fil, "w", zipfile.ZIP_STORED) as z:
            z.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False, indent=1))
            for namn, text in filer[vy].items():
                z.writestr(namn, text)
            if vy == "dtl" and par_json:
                dd, df = round(avst["dtl"], 2), round(avst["fo"], 2)
                forsk = FOLJ_FORSKJUTNING_S + (df - dd) / LJUDETS_FART
                z.writestr("par.json", json.dumps({
                    "format": "swinglab-par/1", "pass": pass_id, "modell": "pahittad", "vy": "dtl",
                    "serier": [{"serie": 1, "styr_avstand_m": dd, "styr_klick": n,
                                "foljare": {"modell": "pahittad", "vy": "fo", "avstand_m": df, "pass": pass_id,
                                            "serie": 1, "hz": 240, "klick": n + bara_fo},
                                "forskjutning_s": round(forsk, 4), "traff_forskjutning_s": FOLJ_FORSKJUTNING_S,
                                "antal_par": n, "oparade_styr": 0, "oparade_folj": bara_fo, "median_rest_s": 0.001,
                                "osaker": False}]}, indent=1))
        ut[vy] = fil
    median = {k: float(np.median([f["sant"][k] for f in facit])) for k in TK.MATT}
    fa, fb = kam["fo"].R[2].copy(), kam["dtl"].R[2].copy()
    fa[2] = fb[2] = 0.0
    vinkel = float(np.degrees(np.arccos(fa @ fb / (np.linalg.norm(fa) * np.linalg.norm(fb)))))
    return ut["dtl"], ut["fo"], {"pass": pass_id, "slag": facit, "median": median,
                                 "vinkel_mellan_kamerorna": vinkel}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("ut")
    ap.add_argument("--pass", dest="pass_id", required=True)
    ap.add_argument("--vy", choices=("fo", "dtl"))
    ap.add_argument("--tva", action="store_true", help="två telefoner (DTL och FO) ur 3D-svingar, och facit")
    ap.add_argument("--brus", default="typiskt", help="2D-bruset (tre_d/kamera.py BRUS)")
    ap.add_argument("--utan-par", action="store_true", help="utan par.json (parning på klicken)")
    ap.add_argument("--lodlinje", action="store_true", help="lodlinjen i manifestet")
    ap.add_argument("--vanster", action="store_true", help="vänsterspelare")
    ap.add_argument("--slag", type=int, help="slag per paket (8; med --tva 12)")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--sway-topp", type=float, default=-6.0)
    ap.add_argument("--thrust-traff", type=float, default=3.0)
    ap.add_argument("--forsta-serien-flytt", type=float, default=0.0)
    ap.add_argument("--serier", type=int, default=1)
    ap.add_argument("--utan-langd", action="store_true", help="manifestet utan spelarens längd")
    ap.add_argument("--klipp", action="store_true")
    a = ap.parse_args(argv)
    if a.tva:
        dtl, fo, facit = tva_paket(a.ut, a.pass_id, n=a.slag or 12, seed=a.seed, brus=a.brus, par_json=not a.utan_par,
                                   lodlinje=a.lodlinje, hand="vanster" if a.vanster else "hoger")
        f = Path(a.ut) / f"facit-{a.pass_id}.json"
        f.write_text(json.dumps(facit, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print(dtl, fo, f, sep="\n")
        return 0
    if a.vy is None:
        ap.error("--vy krävs utan --tva")
    fil = paket(a.ut, a.pass_id, a.vy, n=a.slag or 8, seed=a.seed, sway_topp=a.sway_topp, thrust_traff=a.thrust_traff,
                forsta_serien_flytt=a.forsta_serien_flytt, serier=a.serier, klipp=a.klipp,
                langd_m=None if a.utan_langd else 1.80)
    print(fil)
    return 0


if __name__ == "__main__":
    sys.exit(main())


__all__ = ["paket", "leder", "LEDER_FIL"]
