"""Påhittade sessionspaket (S2_SPEC §8.3) för testerna och skillens exempel.
Inga riktiga leder eller klipp (CLAUDE.md, Dataregeln).

    python3 tools/pc/generera_paket.py <ut-mapp> --pass 20261103-180000 --vy fo [--slag 8]
        [--sway-topp -6] [--thrust-traff 3] [--forsta-serien-flytt 0] [--serier 2] [--klipp]

Varje slag är en påhittad sving ur generera.py med kända tal: bäckenets sway vid
toppen (FO) och thrust vid träffen (DTL) sätts per pass, med lite spridning
mellan slagen. `--forsta-serien-flytt` flyttar talet i första serien (de fem
första slagen, METOD MT2), så att retentionen går att prova. Klippen (`--klipp`)
är ffmpegs testbild, utan person, och kräver ffmpeg.
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


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("ut")
    ap.add_argument("--pass", dest="pass_id", required=True)
    ap.add_argument("--vy", choices=("fo", "dtl"), required=True)
    ap.add_argument("--slag", type=int, default=8)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--sway-topp", type=float, default=-6.0)
    ap.add_argument("--thrust-traff", type=float, default=3.0)
    ap.add_argument("--forsta-serien-flytt", type=float, default=0.0)
    ap.add_argument("--serier", type=int, default=1)
    ap.add_argument("--utan-langd", action="store_true", help="manifestet utan spelarens längd")
    ap.add_argument("--klipp", action="store_true")
    a = ap.parse_args(argv)
    fil = paket(a.ut, a.pass_id, a.vy, n=a.slag, seed=a.seed, sway_topp=a.sway_topp, thrust_traff=a.thrust_traff,
                forsta_serien_flytt=a.forsta_serien_flytt, serier=a.serier, klipp=a.klipp,
                langd_m=None if a.utan_langd else 1.80)
    print(fil)
    return 0


if __name__ == "__main__":
    sys.exit(main())


__all__ = ["paket", "leder", "LEDER_FIL"]
