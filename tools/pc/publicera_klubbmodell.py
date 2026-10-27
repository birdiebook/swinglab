"""Lägger klubbmodellen som en GitHub Release i repot (BESLUT B96, PLAN S7-2, METOD MF7).

Filerna kommer från `formarkare.py release` (paketet, beskrivningen och provet, med pekaren
klubbmodell.json). Skriptet kör på Windows, där git:s inloggning finns:

    python tools/pc/publicera_klubbmodell.py \\\\wsl.localhost\\Ubuntu\\home\\johan\\swinglab-s7\\release\\<namn>

- Spärren i B96 en gång till: varje källa i pekaren är ett öppet dataset.
- Repots `klubbmodell.json` måste vara releasens pekare, så att committen pekar på det som läggs upp.
- En release med samma tagg skrivs aldrig över: en ny modell får ett nytt namn.
- Efteråt hämtas filerna tillbaka och summorna prövas (tools/hamta_klubbmodell.py).

Inloggningen läses med `git credential fill` och skrivs aldrig ut.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import hamta_klubbmodell as H  # noqa: E402
from pc.formarkare import DATASET, OPPNA_LICENSER  # noqa: E402

API = "https://api.github.com/repos/birdiebook/swinglab"
UPLOADS = "https://uploads.github.com/repos/birdiebook/swinglab"


class PubFel(Exception):
    pass


def kontrollera(mapp: Path, repo_pekare: Path = H.PEKARE) -> dict:
    """Pekaren i mappen, om den får publiceras: öppen data, filerna med rätt summa och samma
    pekare som i repot."""
    pekare = H.las_pekare(mapp / "klubbmodell.json")
    if not pekare.get("data"):
        raise PubFel("pekaren saknar träningens data (B96)")
    for d in pekare["data"]:
        if d.get("namn") not in DATASET or d.get("licens") not in OPPNA_LICENSER:
            raise PubFel(f"{d.get('namn')}: inte ett öppet dataset (B96)")
    for fil, summa in pekare["filer"].items():
        if not (mapp / fil).is_file() or H.sha256(mapp / fil) != summa:
            raise PubFel(f"{fil}: saknas eller har fel sha256")
    if H.las_pekare(repo_pekare) != pekare:
        raise PubFel(f"repots {repo_pekare.name} är inte releasens pekare: kopiera den och committa först")
    return pekare


def text(pekare: dict) -> tuple[str, str]:
    """(releasens namn, beskrivning)."""
    data = "\n".join(f"- {d['namn']} ({d['licens']}): {d['kalla']}" for d in pekare["data"])
    return (f"Klubbmodell {pekare['modell']}",
            "SwingLabs klubbmodell (RF-DETR, Apache 2.0) som Core ML, hämtad av appens bygge "
            "(BESLUT B96, tools/hamta_klubbmodell.py). Tränad bara på öppen data, med namnangivelse:\n\n"
            f"{data}\n\nProvet är ritade bilder och PyTorch-modellens rutor (METOD MF7).")


def _token() -> str:
    r = subprocess.run(["git", "credential", "fill"], input="protocol=https\nhost=github.com\n\n",
                       capture_output=True, text=True, timeout=60)
    for rad in r.stdout.splitlines():
        if rad.startswith("password="):
            return rad.removeprefix("password=")
    raise PubFel("git credential fill gav ingen inloggning för github.com")


def _anrop(url: str, token: str, data: bytes | None = None, typ: str = "application/json",
           metod: str | None = None) -> dict:
    req = urllib.request.Request(url, data=data, method=metod or ("POST" if data is not None else "GET"),
                                 headers={"Authorization": f"Bearer {token}", "Content-Type": typ,
                                          "Accept": "application/vnd.github+json",
                                          "X-GitHub-Api-Version": "2022-11-28"})
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.loads(r.read() or b"{}")


def publicera(mapp: Path) -> list[str]:
    pekare = kontrollera(mapp)
    token = _token()
    tag = pekare["tag"]
    try:
        _anrop(f"{API}/releases/tags/{urllib.parse.quote(tag)}", token)
        raise PubFel(f"{tag}: releasen finns redan och skrivs inte över; ge modellen ett nytt namn")
    except urllib.error.HTTPError as e:
        if e.code != 404:
            raise PubFel(f"{tag}: GitHub svarade {e.code}") from None
    namn, beskr = text(pekare)
    rel = _anrop(f"{API}/releases", token, json.dumps(
        {"tag_name": tag, "target_commitish": "main", "name": namn, "body": beskr}).encode())
    rader = [f"release {tag}: {rel.get('html_url')}"]
    for fil in sorted(pekare["filer"]):
        typ = "application/zip" if fil.endswith(".zip") else "application/json"
        a = _anrop(f"{UPLOADS}/releases/{rel['id']}/assets?name={urllib.parse.quote(fil)}", token,
                   (mapp / fil).read_bytes(), typ)
        rader.append(f"{fil}: {a.get('size')} byte")
    with tempfile.TemporaryDirectory() as tmp:
        rader += H.hamta(pekare, Path(tmp) / "Modeller", Path(tmp) / "prov")
    return rader


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("mapp", type=Path, help="formarkare.py release:s mapp för modellen")
    a = ap.parse_args(argv)
    try:
        for r in publicera(a.mapp):
            print(r)
    except (PubFel, H.HamtFel) as e:
        print(f"fel: {e}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
