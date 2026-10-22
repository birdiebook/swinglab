"""Sammanfattar en `swift test`-logg till några rader: grönt eller rött, tiden och de långsammaste testerna.

    python tools/arbetssatt/ci_sammanfattning.py <logg> [<logg> ...]

Kopia från det privata repot birdiebook/arbetssatt (synka.py). Ändra där.

Actions kör det efter IdunnKits tester och lägger raderna på grenen
`ci-resultat` (`resultat/<sha>.txt`), eftersom Actions inte går att läsa från
en lokal session utan `gh` (CLAUDE.md, "Bygget"). Läs dem med

    git fetch origin ci-resultat && git show origin/ci-resultat:resultat/<sha>.txt

Ingen hälsodata finns i loggen: testerna bär bara påhittade fixturer.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

# Apple skriver `-[Modul.Klass test]`, Linux `Klass.test`.
FALL = re.compile(r"Test Case '(?:-\[(\w+)\.(\w+) (\w+)\]|()(\w+)\.(\w+))' (passed|failed) \(([0-9.]+) seconds\)")
SUMMA = re.compile(r"Executed (\d+) tests?, with (\d+) failures? .*? in ([0-9.]+) ")
BYGGT = re.compile(r"Build complete! \(([0-9.]+)s\)")


def sammanfatta(namn: str, logg: str, antal: int = 15) -> list[str]:
    fall = [(float(m.group(8)), m.group(2) or m.group(5), m.group(3) or m.group(6), m.group(7))
            for m in FALL.finditer(logg)]
    summor = SUMMA.findall(logg)
    byggt = BYGGT.search(logg)
    fel = [f for f in fall if f[3] == "failed"]
    ut = [f"== {namn}"]
    if summor:
        n, nfel, tid = summor[-1]
        ut.append(f"{'GRÖNT' if int(nfel) == 0 and not fel else 'RÖTT'}: {n} test, {nfel} fel, "
                  f"{float(tid):.0f} s i testerna" + (f", bygget {float(byggt.group(1)):.0f} s" if byggt else ""))
    else:
        ut.append("RÖTT: ingen sammanräkning i loggen (kompilerade det?)")
        ut += [r.strip() for r in logg.splitlines() if "error:" in r][:15]
    for f in fel[:15]:
        ut.append(f"  fel: {f[1]}.{f[2]}")
    if fall:
        ut.append(f"Långsammast (av {len(fall)}):")
        for s, klass, test, _ in sorted(fall, reverse=True)[:antal]:
            ut.append(f"  {s:7.1f} s  {klass}.{test}")
    return ut


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    for p in map(Path, sys.argv[1:]):
        print("\n".join(sammanfatta(p.stem, p.read_text(encoding="utf-8", errors="replace"))))
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
