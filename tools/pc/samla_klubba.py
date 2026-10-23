"""Samlar klubbans markeringar till en träningsmapp utanför repot (PLAN S7a, BESLUT B47).

    python tools/pc/samla_klubba.py <paket.zip|klubba.json> [fler] --ut ~/swinglab-klubba

Telefonens markeringar (`klubba.json` i paketet) och PC:ns (`swinglab-<pass>-klubba.json`
från markera_klubba.py) läses som samma data, `swinglab-klubba/2` (docs/FORMAT.md), och
skrivs per pass till `<ut>/<pass>.json`, med `index.json` över passen, rutorna och
källorna. Bilderna tas inte med: en ruta pekar på sitt paket (`fil`), slag och tid, och
läses ur klippet med S3:s förskjutning när S7:s träning byggs. Ingen träning här.
Mappen får inte ligga i repot: markeringarna är Johannes data (CLAUDE.md, Dataregeln).
"""
from __future__ import annotations

import argparse
import json
import sys
import zipfile
from datetime import datetime
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "pc"

from . import klubba as KL  # noqa: E402
from .session import REPO  # noqa: E402


def las_kalla(fil: Path) -> dict | None:
    """Märkningen ur ett paket (klubba.json) eller en fil, i version 2; None när paketet
    inte har någon. KlubbFel när formen inte stämmer."""
    fil = Path(fil)
    if fil.suffix.lower() == ".zip":
        with zipfile.ZipFile(fil) as z:
            if KL.FIL not in z.namelist():
                return None
            text = z.read(KL.FIL).decode("utf-8")
        namn = f"{fil.name}: {KL.FIL}"
    else:
        text = fil.read_text(encoding="utf-8")
        namn = fil.name
    try:
        d = json.loads(text)
    except json.JSONDecodeError as e:
        raise KL.KlubbFel(f"{namn}: inte giltig JSON (rad {e.lineno})") from None
    return KL.las_dict(d, namn)


def sla_ihop(markeringar: list[dict]) -> dict[str, dict]:
    """Per pass (eller `video` utan pass): rutorna ur alla källor i ordning. Samma ruta
    (id, fil och tid inom 0,1 ms) tas en gång, den senast ändrade; en annan ruta med ett
    id som redan finns får `-2`, `-3` … (som markera_klubba.sla_ihop)."""
    ut: dict[str, dict] = {}
    for d in sorted(markeringar, key=lambda x: x["andrad"]):
        nyckel = d["pass"] or "video"
        m = ut.setdefault(nyckel, {"format": KL.FORMAT, "pass": d["pass"], "kalla": [], "punkter": list(KL.PUNKTER),
                                   "andrad": d["andrad"], "rutor": []})
        m["kalla"] += [k for k in d["kalla"] if k not in m["kalla"]]
        m["andrad"] = max(m["andrad"], d["andrad"])
        for r in d["rutor"]:
            r = dict(r)
            gammal = next((i for i, x in enumerate(m["rutor"]) if x["id"] == r["id"] and x["fil"] == r["fil"]
                           and _samma_tid(x, r)), None)
            if gammal is not None:
                m["rutor"][gammal] = r
                continue
            ids, bas, k = {x["id"] for x in m["rutor"]}, r["id"], 2
            while r["id"] in ids:
                r["id"] = f"{bas}-{k}"
                k += 1
            m["rutor"].append(r)
    return ut


def _samma_tid(a: dict, b: dict) -> bool:
    ta = a["t"] if a.get("t") is not None else a.get("t_klipp")
    tb = b["t"] if b.get("t") is not None else b.get("t_klipp")
    return ta is not None and tb is not None and abs(ta - tb) <= 1e-4


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Klubbans markeringar → en träningsmapp (S7a).")
    ap.add_argument("kallor", nargs="+", help="paket (swinglab-*.zip) och märkfiler (*-klubba.json)")
    ap.add_argument("--ut", required=True, help="träningsmappen, utanför repot")
    a = ap.parse_args(argv)
    ut = Path(a.ut).expanduser()
    if ut.resolve().is_relative_to(REPO):
        print("--ut: mappen ligger i repot; markeringarna är Johannes data och får inte hamna i git.")
        return 1
    lasta, utan = [], []
    for k in a.kallor:
        try:
            d = las_kalla(Path(k))
        except (KL.KlubbFel, OSError, zipfile.BadZipFile) as e:
            print(f"Går inte att läsa: {e}")
            return 1
        (lasta if d is not None else utan).append(d if d is not None else Path(k).name)
    per_pass = sla_ihop(lasta)
    ut.mkdir(parents=True, exist_ok=True)
    index = {"format": "swinglab-klubba-index/1", "skapad": datetime.now().astimezone().isoformat(timespec="seconds"),
             "pass": []}
    for nyckel, m in sorted(per_pass.items()):
        (ut / f"{nyckel}.json").write_text(json.dumps(m, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        markerade = [r for r in m["rutor"] if r["status"] == "markerad"]
        index["pass"].append({"pass": m["pass"], "fil": f"{nyckel}.json", "kalla": m["kalla"],
                              "rutor": len(m["rutor"]), "markerade": len(markerade),
                              "positioner": sorted({r["val"] for r in markerade if r["val"] in KL.POSITIONER},
                                                   key=KL.POSITIONER.index)})
    (ut / "index.json").write_text(json.dumps(index, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"{sum(p['markerade'] for p in index['pass'])} markerade rutor i {len(index['pass'])} pass → {ut}"
          + (f"; utan markeringar: {', '.join(utan)}" if utan else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
