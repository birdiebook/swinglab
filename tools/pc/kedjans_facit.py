"""Kedjan på paketen mot sanningen: tabellen i docs/S6_FELBUDGET.md §6.7 ("Kedjan på
paketen"), räknad om med samma kommando varje gång.

    python3 tools/pc/kedjans_facit.py                    # inget (8), bra (24), typiskt (24)
    python3 tools/pc/kedjans_facit.py --brus bra --pass 24 --processer 4

Varje pass är `generera_paket.tva_paket` med 10 slag och frö 100, 101, …, genom
paketen, parningen, 2D-faserna och hela `tva_kameror.analysera`. Felet är passets
median minus de sanna svingarnas median: bias / SD och största |fel| per mått, och
synkens rest (RMS) och Sampson-felet (medel). Påhittade pass (CLAUDE.md, Dataregeln).
METOD MK8
"""
from __future__ import annotations

import argparse
import sys
import tempfile
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

NIVAER = {"inget": ("Inget", 8), "bra": ("Bra", 24), "typiskt": ("Typiskt", 24)}
FORSTA_FRO = 100


def ett_pass(arg: tuple[str, int]) -> dict:
    brus, seed = arg
    with tempfile.TemporaryDirectory() as ut:
        d, f, facit = G.tva_paket(ut, "20261103-180000", n=10, seed=seed, brus=brus)
        pd, pf = P.las(d), P.las(f)
        try:
            r = TK.analysera(pd, pf, A.mat_paket(pd, 1.80) + A.mat_paket(pf, 1.80))
        except TK.TreDFel as e:
            return {"hoppat": str(e)}
    sant = {x["dtl"]: x["synk_ms"] for x in facit["slag"]}
    rest = [s["synk_ms"] - sant[s["dtl"]] for s in r["slag"]]
    return {"fel": {m: r["session"][m]["median"] - facit["median"][m] for m in TK.MATT if m in r["session"]},
            "synk": rest, "sampson": r["kalibrering"][0].get("sampson_px")}


def _tal(x: float, d: int = 1) -> str:
    return f"{x:+.{d}f}".replace(".", ",") if d else f"{x:.0f}"


def rad(namn: str, res: list[dict]) -> str:
    ok = [r for r in res if "fel" in r]
    delar = []
    for m in TK.MATT:
        x = np.array([r["fel"][m] for r in ok if m in r["fel"]])
        delar.append(f"{_tal(x.mean())} / {x.std(ddof=1):.1f}, max {np.abs(x).max():.1f}".replace(".", ","))
    synk = np.sqrt(np.mean(np.square([v for r in ok for v in r["synk"]])))
    samp = np.mean([r["sampson"] for r in ok])
    hopp = len(res) - len(ok)
    return (f"| {namn} ({len(ok)}{f', {hopp} hoppade' if hopp else ''}) | " + " | ".join(delar) +
            f" | {synk:.1f} ms | {samp:.1f} px |").replace(".", ",")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--brus", nargs="*", default=list(NIVAER), choices=list(NIVAER))
    ap.add_argument("--pass", dest="antal", type=int, help="pass per nivå (standard: 8 utan brus, annars 24)")
    ap.add_argument("--processer", type=int, default=4)
    a = ap.parse_args(argv)
    print("| Brus (pass) | Bäcken, topp | Bröst, topp | X-factor, topp | Stretch | Höfter öppna, träff | Synk, RMS | "
          "Sampson |")
    print("|---|---|---|---|---|---|---|---|")
    with Pool(a.processer) as pool:
        for brus in a.brus:
            namn, n = NIVAER[brus]
            res = pool.map(ett_pass, [(brus, FORSTA_FRO + i) for i in range(a.antal or n)])
            print(rad(namn, res), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
