"""Sessionen: varje mått sammanfattat över passets svingar, och jämförelsen mot
förra passet. METOD M25, METOD M26

Percentilen, medianen och rangerna räknas här för hand (inte med np.percentile),
så att Swift kan göra exakt samma sak.

Som kommando läser den telefonens paket och skriver passets analys (S5):

    python3 tools/pc/session.py <paket> [<paket>] [--forra <paket> …] [--langd 1.80]

Ett paket per telefon (vy) och pass. Analysen och kontaktarken hamnar i
`data/historik/pass/<pass>/` (gitignorerad); baslinjen och förra passet tas ur
historiken om `--forra` inte anges. `--ut <mapp>` skriver dit i stället och
lämnar historiken orörd.
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "pc"

MIN_N = 3                # METOD M25: färre svingar ger ingen sammanfattning
MAD_GRANS = 3.0          # METOD M25: avvikare = mer än 3 robusta sd från medianen
MAD_SKALA = 1.4826       # METOD M25: MAD → sd för normalfördelning (standard)
IQR_SKALA = 1.349        # METOD M26: IQR → sd för normalfördelning (standard)


def percentil(sorterad: list[float], p: float) -> float:
    """Linjär interpolation mellan de närmaste (som numpy 'linear'), p i 0…1."""
    n = len(sorterad)
    pos = p * (n - 1)
    lo = int(math.floor(pos))
    hi = min(lo + 1, n - 1)
    return sorterad[lo] + (pos - lo) * (sorterad[hi] - sorterad[lo])


def rang(x: list[float]) -> list[float]:
    """Rangerna 1…n, med medelrangen för lika värden."""
    ordning = sorted(range(len(x)), key=lambda i: x[i])
    r = [0.0] * len(x)
    i = 0
    while i < len(ordning):
        j = i
        while j + 1 < len(ordning) and x[ordning[j + 1]] == x[ordning[i]]:
            j += 1
        medel = (i + j) / 2 + 1
        for k in range(i, j + 1):
            r[ordning[k]] = medel
        i = j + 1
    return r


def pearson(a: list[float], b: list[float]) -> float:
    n = len(a)
    ma, mb = sum(a) / n, sum(b) / n
    sab = sum((a[i] - ma) * (b[i] - mb) for i in range(n))
    saa = sum((v - ma) ** 2 for v in a)
    sbb = sum((v - mb) ** 2 for v in b)
    if saa == 0 or sbb == 0:
        return 0.0
    return sab / math.sqrt(saa * sbb)


def spearman(a: list[float], b: list[float]) -> float:
    return pearson(rang(a), rang(b))


def sammanfatta(rader: list[dict[str, float]]) -> dict[str, dict]:
    """Rader = måtten per sving i passets ordning. Per mått: n, median, q1, q3,
    sd, min, max, trend (Spearman mot ordningen) och avvikare (svingens plats i
    passet, 0 först). METOD M25"""
    ut: dict[str, dict] = {}
    for k in sorted({k for r in rader for k in r}):
        plats = [i for i, r in enumerate(rader) if k in r and math.isfinite(r[k])]
        x = [rader[i][k] for i in plats]
        n = len(x)
        if n < MIN_N:
            continue
        s = sorted(x)
        med = percentil(s, 0.5)
        medel = sum(x) / n
        sd = math.sqrt(sum((v - medel) ** 2 for v in x) / (n - 1))
        mad = percentil(sorted(abs(v - med) for v in x), 0.5)
        grans = MAD_GRANS * MAD_SKALA * mad
        ut[k] = {"n": n, "median": med, "q1": percentil(s, 0.25), "q3": percentil(s, 0.75),
                 "sd": sd, "min": s[0], "max": s[-1],
                 "trend": spearman([float(i) for i in plats], x),
                 "avvikare": [plats[i] for i in range(n) if mad > 0 and abs(x[i] - med) > grans]}
    return ut


def robust_sd(sammanf: dict) -> float:
    """Spridningen ur kvartilerna: (q3 − q1)/1,349. METOD M26"""
    return (sammanf["q3"] - sammanf["q1"]) / IQR_SKALA


def jamfor(nu: dict[str, dict], forra: dict[str, dict]) -> dict[str, dict]:
    """Skillnaden i median mot förra passet, och om den är större än förra
    passets spridning (robust sd). METOD M26"""
    ut = {}
    for k in sorted(set(nu) & set(forra)):
        skillnad = nu[k]["median"] - forra[k]["median"]
        spridning = robust_sd(forra[k])
        ut[k] = {"skillnad": skillnad, "spridning": spridning, "tydlig": abs(skillnad) > spridning}
    return ut


def sammanfatta_session(svingar: list[dict]) -> dict[str, dict]:
    """Svingar = resultaten ur matt.mat (med "vy" och "matt"), i passets ordning.
    Måtten sammanfattas per vy, och för alla svingar ihop (tempot)."""
    return {"dtl": sammanfatta([s["matt"] for s in svingar if s["vy"] == "dtl"]),
            "fo": sammanfatta([s["matt"] for s in svingar if s["vy"] == "fo"]),
            "alla": sammanfatta([s["matt"] for s in svingar])}


# --- kommandot: paket → analys.json ----------------------------------------------

def _las_paket(filer) -> list:
    from . import paket as P
    return [P.las(f) for f in filer]


REPO = Path(__file__).resolve().parents[2]


def utanfor_repot(mapp) -> bool:
    """En mapp för passets data får ligga i repots data/ (gitignorerad) eller
    utanför repot, aldrig någon annanstans i det (CLAUDE.md, Dataregeln)."""
    m = Path(mapp).resolve()
    return not m.is_relative_to(REPO) or m.is_relative_to(REPO / "data")


def main(argv=None) -> int:
    from . import analys as A
    from . import historik as H
    from . import kontaktark as KA
    from . import paket as P

    ap = argparse.ArgumentParser(description="Paketen från telefonen → analys.json och kontaktark.")
    ap.add_argument("paket", nargs="+", help="swinglab-<pass>-<vy>.zip, ett per vy")
    ap.add_argument("--forra", nargs="+", help="förra passets paket (annars ur historiken)")
    ap.add_argument("--langd", type=float, help="spelarens längd i m (sparas i historiken)")
    ap.add_argument("--historik", default=str(H.ROT), help="historikens mapp (standard data/historik)")
    ap.add_argument("--ut", help="skriv hit i stället för i historiken (historiken läses inte)")
    ap.add_argument("--utan-kontaktark", action="store_true")
    a = ap.parse_args(argv)
    rot = Path(a.historik)
    for falt, mapp in (("--ut", a.ut), ("--historik", a.historik)):
        if mapp and not utanfor_repot(mapp):
            print(f"{falt}: mappen ligger i repot men inte i data/; passets data får inte hamna i git.")
            return 1
    try:
        paket = _las_paket(a.paket)
        forra_paket = _las_paket(a.forra) if a.forra else None
    except P.PaketFel as e:
        print("Paketet går inte att läsa:\n  " + "\n  ".join(e.fel))
        return 1
    pass_id = paket[0].pass_id
    langd = a.langd or paket[0].langd_m or (None if a.ut else H.spelare(rot).get("spelarens_langd_m"))
    if langd is None:
        print("Spelarens längd saknas: ange --langd (sparas i historiken till nästa gång).")
        return 1
    if a.langd and not a.ut:
        H.spara_spelare(rot, a.langd)

    tidigare, bas_pass, forra = [], [], None
    if not a.ut:
        tidigare, bas_pass = H.baslinje(rot, pass_id)
        forra = H.forra(rot, pass_id)
    if forra_paket:
        f_pass = forra_paket[0].pass_id
        forra = A.analysera(forra_paket, langd, [], skapad="")
        if f_pass not in bas_pass:
            tidigare = tidigare + A.svingar(forra)
            bas_pass = sorted(bas_pass + [f_pass])
    try:
        analys = A.analysera(paket, langd, tidigare, forra=forra, baslinje_pass=bas_pass)
    except ValueError as e:
        print(f"Analysen stoppade: {e}")
        return 1
    ut = Path(a.ut) if a.ut else H.pass_mapp(rot, pass_id)
    if a.utan_kontaktark:
        analys["kontaktark"] = {p.vy: {"hoppat": "--utan-kontaktark"} for p in paket}
    else:
        try:
            for fil, p in zip(a.paket, paket):
                analys["kontaktark"][p.vy] = KA.bygg(Path(fil), p, [r for r in analys["slag"] if r["vy"] == p.vy], ut)
        except P.PaketFel as e:
            print("Paketet går inte att läsa:\n  " + "\n  ".join(e.fel))
            return 1
    A.skriv(analys, ut / "analys.json")

    matta = [r for r in analys["slag"] if "matt" in r]
    print(f"Pass {pass_id}: {len(matta)} slag mätta av {len(analys['slag'])}"
          + (f", förra passet {analys['forra']['pass']}" if analys["forra"] else ", inget förra pass")
          + f", baslinje ur {len(bas_pass)} pass")
    for r in analys["slag"]:
        if "fel" in r:
            print(f"  ej mätt: {r['fel']}")
    for vy, k in analys["kontaktark"].items():
        print(f"  kontaktark {vy}: {k.get('fil') or 'hoppat (' + k['hoppat'] + ')'}")
    print(f"  kandidater: {', '.join(k['fel'] + ' (' + k['status'] + ')' for k in analys['kandidater']) or 'inga'}")
    print(f"Skrev {ut / 'analys.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
