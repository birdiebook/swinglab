"""Delat för testerna: sökvägen till tools/ och påhittade svingar som räknas en gång."""
from __future__ import annotations

import functools
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from pc import format as fm  # noqa: E402
from pc import generera as gen  # noqa: E402
from pc import matt as M  # noqa: E402


@functools.lru_cache(maxsize=None)
def _sving(nyckel: str) -> tuple[str, str]:
    args = json.loads(nyckel)
    d, facit = gen.sving(**{k: (tuple(map(tuple, v)) if k == "dolj" else v) for k, v in args.items()})
    return json.dumps(d), json.dumps(facit)


def sving(**args) -> tuple[dict, dict]:
    """(svingen som dict, facit). Samma argument ger samma sving, räknad en gång."""
    d, f = _sving(json.dumps(args, sort_keys=True))
    return json.loads(d), json.loads(f)


@functools.lru_cache(maxsize=None)
def _matt(nyckel: str) -> str:
    d, _ = _sving(nyckel)
    return json.dumps(M.mat(fm.las(d)))


def mat(**args) -> dict:
    """Måtten för den påhittade svingen (matt.mat), räknade en gång."""
    return json.loads(_matt(json.dumps(args, sort_keys=True)))
