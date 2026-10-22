"""Påhittade ljudsignaler med klick på kända prov (CLAUDE.md, Dataregeln: inget riktigt ljud).

    python3 tools/pc/klickljud.py --swift    # skriver SwingLabKit/Tests/CaptureTests/KlickFixturer.swift

Receptet går att följa i båda språken (S2_SPEC §11.2), så att fixturen bara bär
receptet och Pythons tal, aldrig själva signalen:

- Bruset: LCG `s = (1103515245·s + 12345) mod 2³¹` från fröet, ett steg per prov,
  och provet `(2·s/2³¹ − 1)·brus`.
- Ett klick: 10 prov med växlande tecken, `amp, −amp, amp, …`, från provet `prov`,
  adderat till bruset.
- Allt räknas i double och blir Float32 sist (som ljudet som telefonen läser).

Pythons tal är `klick.klick` på hela signalen (Golf SG:s algoritm) och
`klick.klick_i_bitar` (telefonens bitar om 30 s), och `klick.para` på påhittade
klicklistor för två telefoner. Swift-testerna bygger samma signal och kräver
samma ansats på provet och samma styrka inom 1e-6 relativt (BESLUT B12).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "pc"

from . import klick as KL  # noqa: E402

ROT = Path(__file__).resolve().parents[2]
FIXTURFIL = ROT / "SwingLabKit" / "Tests" / "CaptureTests" / "KlickFixturer.swift"

KLICK_PROV = 10
MOD = 2 ** 31


def _k(sr: int, t: float, amp: float) -> dict:
    return {"prov": int(round(t * sr)), "amp": amp}


# Recepten. Johannes klick har amp 0,5; grannens är svagare (längre bort).
RECEPT = [
    {"namn": "ett_klick", "sr": 48000, "langd_s": 3.0, "fro": 1, "brus": 0.001,
     "klick": [_k(48000, 1.5, 0.5)]},
    {"namn": "tre_klapp", "sr": 48000, "langd_s": 10.0, "fro": 7, "brus": 0.001,
     "klick": [_k(48000, 2.0, 0.5), _k(48000, 4.3, 0.3), _k(48000, 7.71, 0.4)]},
    {"namn": "nara", "sr": 48000, "langd_s": 4.0, "fro": 11, "brus": 0.001,          # 0,4 s isär → ett klick
     "klick": [_k(48000, 1.0, 0.2), _k(48000, 1.4, 0.5)]},
    {"namn": "grannar", "sr": 48000, "langd_s": 12.0, "fro": 23, "brus": 0.001,
     "klick": [_k(48000, 2.0, 0.5), _k(48000, 3.7, 0.04), _k(48000, 5.0, 0.005), _k(48000, 6.0, 0.5),
               _k(48000, 8.2, 0.04), _k(48000, 10.0, 0.5)]},
    {"namn": "bara_brus", "sr": 48000, "langd_s": 5.0, "fro": 5, "brus": 0.001, "klick": []},
    {"namn": "hogt_brus", "sr": 48000, "langd_s": 5.0, "fro": 9, "brus": 0.01,
     "klick": [_k(48000, 1.0, 0.5), _k(48000, 3.0, 0.5)]},
    {"namn": "sr44", "sr": 44100, "langd_s": 4.0, "fro": 13, "brus": 0.001,           # jämnt fönster: 88 prov
     "klick": [_k(44100, 1.0, 0.5), _k(44100, 2.5, 0.3)]},
    {"namn": "lang", "sr": 48000, "langd_s": 61.0, "fro": 3, "brus": 0.001,          # tre bitar; två klick i överlappen
     "klick": [_k(48000, 10.0, 0.5), _k(48000, 29.5, 0.5), _k(48000, 45.0, 0.3), _k(48000, 58.6, 0.5),
               _k(48000, 60.2, 0.4)]},
    # Klick vid bitgränserna: 13 prov in i bit 2 och 3, och i bit 1:s och 2:s sista prov
    # (klicket går över gränsen). Bitarna är [0, 30 s), [29, 59 s), [58, 61 s).
    {"namn": "bitgrans", "sr": 48000, "langd_s": 61.0, "fro": 17, "brus": 0.001,
     "klick": [{"prov": 29 * 48000 + 13, "amp": 0.5}, {"prov": 30 * 48000 - 1, "amp": 0.4},
               {"prov": 58 * 48000 + 13, "amp": 0.3}, {"prov": 59 * 48000 - 1, "amp": 0.5}]},
]

# Två telefoners klick: b ≈ a + förskjutning, med jitter, ett klick som bara a
# hörde, ett som bara b hörde och ett av a:s som b missade.
_A = [1.0, 3.2, 5.9, 8.4, 11.0, 13.3, 16.05]
_JITTER = [0.0012, -0.0021, 0.0035, -0.0008, 0.0017, -0.0031, 0.0004]


def _b(forskjutning: float, extra: float) -> list[float]:
    b = [t + forskjutning + j for t, j in zip(_A, _JITTER)]
    del b[4]                           # b missade a:s femte
    return sorted(b + [extra])         # och hörde ett eget


PARA = [
    {"namn": "utan_prior", "a": _A + [7.15], "b": _b(2.347, 9.9), "prior": None},
    {"namn": "med_prior", "a": _A + [7.15], "b": _b(2.347, 9.9), "prior": 2.30},
    {"namn": "negativ", "a": _A, "b": _b(-4.512, 4.0), "prior": None},
    {"namn": "fel_prior", "a": _A, "b": _b(2.347, 9.9), "prior": 1.0},   # inget inom ± 0,25 s
    # Ett par: sann 2,07 s, men a:s andra klick parar lika bra vid −8,46 s → osäker.
    {"namn": "ett_par", "a": [1.0, 11.53], "b": [3.07], "prior": None},
    {"namn": "tomt_fonster", "a": _A, "b": _b(2.347, 9.9), "prior": 2.347, "prior_fonster": 0.0},
]


def signal(r: dict) -> np.ndarray:
    """Receptets signal som Float32 (se modulens beskrivning)."""
    n = int(round(r["langd_s"] * r["sr"]))
    s = r["fro"]
    u = np.empty(n)
    for i in range(n):
        s = (1103515245 * s + 12345) % MOD
        u[i] = s
    x = (2.0 * (u / float(MOD)) - 1.0) * r["brus"]
    for k in r["klick"]:
        for j in range(KLICK_PROV):
            if k["prov"] + j < n:
                x[k["prov"] + j] += k["amp"] if j % 2 == 0 else -k["amp"]
    return x.astype(np.float32)


def _prov(kl: list[tuple[float, float]], sr: int) -> list[list]:
    return [[int(round(t * sr)), s] for t, s in kl]


def facit_klick(r: dict) -> dict:
    x = signal(r)
    return {"hela": _prov(KL.klick(x, r["sr"]), r["sr"]), "bitar": _prov(KL.klick_i_bitar(x, r["sr"]), r["sr"])}


def facit_para(p: dict) -> dict:
    return KL.para(p["a"], p["b"], prior=p["prior"], prior_fonster=p.get("prior_fonster", KL.PRIOR_FONSTER_S))


def fixtur() -> dict:
    return {"klick": [{**r, **facit_klick(r)} for r in RECEPT],
            "para": [{**p, **facit_para(p)} for p in PARA]}


def swift_kalla() -> str:
    text = json.dumps(fixtur(), ensure_ascii=False, indent=1)
    return "\n".join([
        "// GENERERAD av tools/pc/klickljud.py --swift. Ändra inte för hand: kör skriptet igen.",
        "//",
        "// PÅHITTAT ljud (CLAUDE.md, Dataregeln): bara recepten och Pythons tal. Swift bygger",
        "// signalen ur receptet själv (KlickTests.signal). METOD MS4, MS10.",
        "",
        "enum KlickFixturer {",
        '    static let json = #"""',
        text,
        '"""#',
        "}",
        "",
    ])


def las_fixtur(text: str) -> dict:
    a = text.index('#"""\n') + len('#"""\n')
    b = text.index('\n"""#')
    return json.loads(text[a:b])


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--swift", action="store_true", help=f"skriv {FIXTURFIL.relative_to(ROT)}")
    a = ap.parse_args(argv)
    if not a.swift:
        ap.error("ange --swift")
    FIXTURFIL.parent.mkdir(parents=True, exist_ok=True)
    FIXTURFIL.write_text(swift_kalla(), encoding="utf-8")
    print(f"skrev {FIXTURFIL.relative_to(ROT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
