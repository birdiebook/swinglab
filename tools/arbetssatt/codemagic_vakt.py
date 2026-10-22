"""Codemagics minuter och spärrarna före ett bygge, delade mellan apparna.

    python tools/arbetssatt/codemagic_vakt.py            # månadens minuter per app och arbetsflöde
    python tools/arbetssatt/codemagic_vakt.py --byggen   # varje bygge den här månaden

Kopia från det privata repot birdiebook/arbetssatt (synka.py). Ändra där.

Gratisnivån är 500 minuter macOS M2 i månaden, delade mellan alla appar på
kontot (Idunn och Birdiebook), och ett bygge åt gången. Oktober 2026 tog
minuterna slut den 15:e utan att någon såg det komma: Idunns prov hade vuxit
från 6 till 25–40 minuter och körts en gång per gren, och TestFlight-bygget
fick `402 BILLING_NOT_ENABLED`.

Räkningen: varje bygge från start till slut, avrundat uppåt till hela
minuter, per kalendermånad i UTC. Det är en skattning av Codemagics egen
räkning (som inte går att läsa via API:t); den låg på 536 när Codemagic
spärrade, så den stämmer i alla fall på den sidan.

`hinder()` är spärrarna appens byggskript frågar innan ett bygge startas:
ett bygge går redan (för någon app), dagens TestFlight-bygge är redan gjort
(högst ett per dag, svensk tid), och minuterna räcker inte.

Token: CODEMAGIC_API_TOKEN i miljön eller i en `.env`-fil. Den skrivs aldrig ut.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import sys
import urllib.request
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

API = "https://api.codemagic.io"
GRANS = 500
# Minuter som ett prov eller en förhandsvisning aldrig får äta av: ett TestFlight-bygge med marginal.
RESERV = 20
# Skattningen av ett bygge när inget finns att gå på.
OKANT = 40
PAGAR = ("queued", "preparing", "fetching", "building", "testing", "publishing", "finishing")
# Högst ett TestFlight-bygge per dag och app, räknat i svensk tid (Johannes 2026-10-15).
ZON = ZoneInfo("Europe/Stockholm")
# Där token letas när den inte finns i miljön: hemdatorns gemensamma .env.
ENV_FILER = (Path(r"C:\dev\golf-sg\.env"),)


def token(*filer: Path) -> str:
    if os.environ.get("CODEMAGIC_API_TOKEN"):
        return os.environ["CODEMAGIC_API_TOKEN"].strip()
    for f in (*filer, *ENV_FILER):
        if f.exists():
            for rad in f.read_text(encoding="utf-8-sig").splitlines():
                rad = rad.strip()
                if rad.startswith("CODEMAGIC_API_TOKEN="):
                    return rad.split("=", 1)[1].strip()
    raise SystemExit("CODEMAGIC_API_TOKEN saknas (miljön eller .env).")


def _tid(s: str | None) -> datetime | None:
    return datetime.fromisoformat(s.replace("Z", "+00:00")) if s else None


def minuter(b: dict) -> int:
    """Byggets minuter, avrundat uppåt; 0 för ett bygge som aldrig startade."""
    s, f = _tid(b.get("startedAt")), _tid(b.get("finishedAt"))
    if not s or not f:
        return 0
    return math.ceil((f - s).total_seconds() / 60)


def manadens_start(nu: datetime) -> datetime:
    return nu.astimezone(timezone.utc).replace(day=1, hour=0, minute=0, second=0, microsecond=0)


def arbetsflode(b: dict) -> str:
    return b.get("fileWorkflowId") or b.get("workflowId") or "?"


def manadens(byggen: list[dict], nu: datetime) -> list[dict]:
    start = manadens_start(nu)
    return [b for b in byggen if (_tid(b.get("startedAt")) or _tid(b.get("createdAt")) or start) >= start]


def summa(byggen: list[dict]) -> int:
    return sum(minuter(b) for b in byggen)


def kvar(byggen: list[dict], nu: datetime) -> int:
    return GRANS - summa(manadens(byggen, nu))


def per_flode(byggen: list[dict]) -> dict[tuple[str, str], list[int]]:
    """(app, arbetsflöde) → [antal, minuter]."""
    ut: dict[tuple[str, str], list[int]] = defaultdict(lambda: [0, 0])
    for b in byggen:
        k = (b.get("_app", "?"), arbetsflode(b))
        ut[k][0] += 1
        ut[k][1] += minuter(b)
    return dict(ut)


def skatta(byggen: list[dict], flode: str, app_id: str | None = None) -> int:
    """Det längsta av de tre senaste färdiga byggena i arbetsflödet (tiden varierar mycket mellan maskiner)."""
    klara = sorted((b for b in byggen if arbetsflode(b) == flode and b.get("status") == "finished"
                    and (app_id is None or b.get("appId", app_id) == app_id)),
                   key=lambda b: b.get("startedAt") or "", reverse=True)[:3]
    return max((minuter(b) for b in klara), default=OKANT)


def ryms(byggen: list[dict], nu: datetime, flode: str, app_id: str | None = None,
         reserv: int = RESERV) -> tuple[bool, int, int]:
    """(ryms, kvar, skattning): ryms ett bygge i `flode` med `reserv` minuter kvar efteråt?"""
    k = kvar(byggen, nu)
    s = skatta(byggen, flode, app_id)
    return k - s >= reserv, k, s


def dagens_bygge(byggen: list[dict], nu: datetime, app_id: str, flode: str) -> dict | None:
    """Appens bygge i `flode` som redan startats i dag (svensk tid); ett avbrutet räknas inte."""
    idag = nu.astimezone(ZON).date()
    for b in byggen:
        t = _tid(b.get("startedAt") or b.get("createdAt"))
        if (b.get("appId") == app_id and arbetsflode(b) == flode and t
                and b.get("status") not in ("canceled", "skipped") and t.astimezone(ZON).date() == idag):
            return b
    return None


def hinder(byggen: list[dict], nu: datetime, app_id: str, flode: str, *, en_per_dag: bool = True,
           reserv: int = 0, betalt: bool = False, igen_idag: bool = False) -> list[str]:
    """Det som stoppar ett bygge i `flode` just nu; tom lista när det kan starta.

    `en_per_dag` för TestFlight (inte för prov). `reserv` för prov och förhandsvisningar, som inte får äta
    TestFlights minuter. `betalt` när Johannes slagit på betalning; `igen_idag` bara på Johannes begäran.
    """
    ut: list[str] = []
    for b in byggen:
        if b.get("status") in PAGAR:
            ut.append(f"ett bygge går redan: {b.get('_app', '?')} · {arbetsflode(b)} · {b.get('status')}")
    if en_per_dag and not igen_idag and dagens_bygge(byggen, nu, app_id, flode):
        ut.append("dagens bygge är redan gjort (högst ett per dag): samla till i morgon")
    ok, k, s = ryms(byggen, nu, flode, app_id, reserv)
    if not ok and not betalt:
        ut.append(f"minuterna räcker inte: {k} kvar, bygget skattas till {s}"
                  + (f" och {reserv} ska finnas kvar till TestFlight" if reserv else ""))
    return ut


def hamta(tok: str, nu: datetime) -> list[dict]:
    """Alla appars byggen från den här månaden (och några till), med appens namn i `_app`."""
    def get(url: str) -> dict:
        req = urllib.request.Request(url, headers={"x-auth-token": tok, "User-Agent": "arbetssatt-vakt"})
        with urllib.request.urlopen(req, timeout=90) as r:
            return json.load(r)

    start = manadens_start(nu)
    ut: list[dict] = []
    for app in get(f"{API}/apps").get("applications", []):
        hoppa = 0
        while True:
            sida = get(f"{API}/builds?appId={app['_id']}&skip={hoppa}").get("builds", [])
            for b in sida:
                b["_app"] = app.get("appName", "?")
                b.setdefault("appId", app["_id"])
            ut += sida
            hoppa += len(sida)
            aldst = min((_tid(b.get("createdAt")) for b in sida if b.get("createdAt")), default=None)
            if not sida or (aldst and aldst < start) or hoppa > 1000:
                break
    return ut


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--byggen", action="store_true")
    a = ap.parse_args()
    nu = datetime.now(timezone.utc)
    alla = hamta(token(Path.cwd() / ".env"), nu)
    manad = manadens(alla, nu)
    print(f"Codemagic {nu:%Y-%m}: {summa(manad)} av {GRANS} minuter, {kvar(alla, nu)} kvar")
    for (app, flode), (n, m) in sorted(per_flode(manad).items(), key=lambda x: -x[1][1]):
        print(f"  {m:4} min  {n:3} byggen  {app} · {flode}")
    if a.byggen:
        for b in sorted(manad, key=lambda b: b.get("startedAt") or b.get("createdAt") or ""):
            print(f"  {(b.get('startedAt') or b.get('createdAt') or '')[:16]}  {minuter(b):3} min  "
                  f"{b.get('_app')} · {arbetsflode(b)} · {b.get('status')} · {b.get('branch') or b.get('tag')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
