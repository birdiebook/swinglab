"""Håller koden och docs/METOD.md ihop.

    python tools/kolla_metod.py

Varje `METOD Mn` i koden måste ha en rubrik `## Mn` i docs/METOD.md, och
varje `B<n>` som koden nämner (`// BESLUT B3`) en rubrik i docs/BESLUT.md.
Körs i GitHub Actions.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROT = Path(__file__).resolve().parent.parent


def rubriker(fil: str, prefix: str) -> set[str]:
    text = (ROT / fil).read_text(encoding="utf-8")
    return set(re.findall(rf"^## ({prefix}\d+)\b", text, re.M))


def main() -> int:
    metod = rubriker("docs/METOD.md", "M")
    beslut = rubriker("docs/BESLUT.md", "B")
    fel = []
    for fil in sorted([*ROT.glob("SwingLabKit/**/*.swift"), *ROT.glob("App/**/*.swift"), *ROT.glob("tools/**/*.py")]):
        text = fil.read_text(encoding="utf-8")
        for n, rad in enumerate(text.splitlines(), 1):
            for ref in re.findall(r"METOD (M\d+)", rad):
                if ref not in metod:
                    fel.append(f"{fil.relative_to(ROT)}:{n}: {ref} saknas i docs/METOD.md")
            for ref in re.findall(r"BESLUT (B\d+)", rad):
                if ref not in beslut:
                    fel.append(f"{fil.relative_to(ROT)}:{n}: {ref} saknas i docs/BESLUT.md")
    print("\n".join(fel) if fel else f"OK ({len(metod)} metoder, {len(beslut)} beslut)")
    return 1 if fel else 0


if __name__ == "__main__":
    sys.exit(main())
