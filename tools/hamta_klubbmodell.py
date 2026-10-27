"""Hämtar klubbmodellen ur sin GitHub Release till appen (BESLUT B96, PLAN S7-2, METOD MF7).

`klubbmodell.json` i repots rot pekar på releasen (taggen) och bär filernas sha256. Skriptet
hämtar filerna, vägrar en fil vars summa inte stämmer och packar upp:

    Modeller/Klubbmodell.mlpackage   Core ML-paketet, som Xcode kompilerar in i appen (project.yml)
    Modeller/Klubbmodell.json        beskrivningen (swinglab-klubba-coreml/1, docs/FORMAT.md)
    <--prov>/prov-NN.png, prov.json  simulatorprovets ritade bilder och PyTorch-modellens rutor

    python3 tools/hamta_klubbmodell.py [--prov /tmp/swinglab_modell/prov]

kompilera.yml och testflight.yml kör det före `xcodegen generate`. Bara standardbiblioteket.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PEKARE = REPO / "klubbmodell.json"
FORMAT = "swinglab-klubbmodell/1"
BAS = "https://github.com/birdiebook/swinglab/releases/download"


class HamtFel(Exception):
    pass


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def las_pekare(p: Path = PEKARE) -> dict:
    try:
        d = json.loads(p.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        raise HamtFel(f"{p.name}: går inte att läsa ({type(e).__name__})") from None
    if d.get("format") != FORMAT or not d.get("tag") or not isinstance(d.get("filer"), dict):
        raise HamtFel(f"{p.name}: inte {FORMAT} med tag och filer")
    namn = d.get("modell", "")
    for slut in (".mlpackage.zip", ".json", "-prov.zip"):
        if f"{namn}{slut}" not in d["filer"]:
            raise HamtFel(f"{p.name}: filen {namn}{slut} saknas i filer")
    return d


def hamta(pekare: dict, modeller: Path, prov: Path | None, bas: str = BAS) -> list[str]:
    """Hämtar och kontrollerar releasens filer och packar upp dem. Returnerar raderna att skriva ut."""
    namn, rader = pekare["modell"], []
    with tempfile.TemporaryDirectory() as tmp:
        lokala = {}
        for fil, summa in sorted(pekare["filer"].items()):
            if prov is None and fil.endswith("-prov.zip"):
                continue
            mal = Path(tmp) / fil
            try:
                with urllib.request.urlopen(f"{bas}/{pekare['tag']}/{fil}", timeout=300) as r, open(mal, "wb") as f:
                    shutil.copyfileobj(r, f)
            except OSError as e:
                raise HamtFel(f"{fil}: hämtningen föll ({type(e).__name__})") from None
            if sha256(mal) != summa:
                raise HamtFel(f"{fil}: sha256 stämmer inte med {PEKARE.name}")
            lokala[fil] = mal
            rader.append(f"{fil}: {mal.stat().st_size} byte, sha256 stämmer")
        if modeller.exists():
            shutil.rmtree(modeller)
        modeller.mkdir(parents=True)
        with zipfile.ZipFile(lokala[f"{namn}.mlpackage.zip"]) as z:
            if any(not n.startswith("Klubbmodell.mlpackage/") or ".." in n for n in z.namelist()):
                raise HamtFel(f"{namn}.mlpackage.zip: oväntade sökvägar")
            z.extractall(modeller)
        shutil.copyfile(lokala[f"{namn}.json"], modeller / "Klubbmodell.json")
        if prov is not None:
            if prov.exists():
                shutil.rmtree(prov)
            with zipfile.ZipFile(lokala[f"{namn}-prov.zip"]) as z:
                if any(not n.startswith("prov/") or ".." in n for n in z.namelist()):
                    raise HamtFel(f"{namn}-prov.zip: oväntade sökvägar")
                z.extractall(prov.parent)
                if prov.name != "prov":
                    (prov.parent / "prov").rename(prov)
    rader.append(f"klubbmodellen {namn} i {modeller}" + (f", provet i {prov}" if prov else ""))
    return rader


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--prov", type=Path, help="mapp för simulatorprovets bilder (kompilera.yml)")
    ap.add_argument("--modeller", type=Path, default=REPO / "Modeller")
    a = ap.parse_args(argv)
    try:
        for r in hamta(las_pekare(), a.modeller, a.prov):
            print(r)
    except HamtFel as e:
        print(f"fel: {e}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
