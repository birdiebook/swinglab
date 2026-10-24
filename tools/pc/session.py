"""Sessionen: varje mått sammanfattat över passets svingar, och jämförelsen mot
förra passet. METOD M25, METOD M26

Percentilen, medianen och rangerna räknas här för hand (inte med np.percentile),
så att Swift kan göra exakt samma sak.

Som kommando läser den telefonens paket och skriver passets analys (S5):

    python3 tools/pc/session.py <paket> [<paket>] [--forra <paket> …] [--langd 1.80]

Ett paket per telefon (vy) och pass. Analysen och kontaktarken hamnar i
`data/historik/pass/<pass>/` (gitignorerad); baslinjen och förra passet tas ur
historiken om `--forra` inte anges. `--ut <mapp>` skriver dit i stället och
lämnar historiken orörd. `--claude-text` skriver också `claude-text.txt`: samma
underlag som "Ask Claude" på telefonen (S5b), att klistra in i Claude-appen.
"""
from __future__ import annotations

import argparse
import datetime as dt
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


def _skriv_telefon(j: dict | None) -> None:
    """Telefonens 3D mot PC:ns (S6c-2, BESLUT B61): en rad, och det som skiljer. METOD MS19"""
    if j is None:
        return
    if "fel" in j:
        print(f"  3D på telefonen ({j['paket']}): lästes inte ({j['fel']})")
        return
    if "hoppat" in j:
        print(f"  3D på telefonen ({j['paket']}): " + ("samma skäl som PC:n" if j["inom"] else
              f"skiljer: PC:n {j['hoppat']['pc'] or 'räknade'}, telefonen {j['hoppat']['telefon'] or 'räknade'}"))
        return
    print(f"  3D på telefonen ({j['paket']}): " + ("lika" if j["inom"] else "skiljer")
          + f", största skillnad per slag {j['storsta_skillnad']:.2g}° (gräns {j['tol']}°)"
          + (f", {j['sekunder']:.1f} s på telefonen" if j.get("sekunder") is not None else ""))
    for f in j["olika"]:
        print(f"    olika: {f}")
    for a in j.get("avrundade", []):
        print(f"    {a['falt']}: PC {a['pc']}, telefonen {a['telefon']}")
    for x in j.get("bara_telefonen", []):
        print(f"    bara telefonen: {x['dtl']}/{x['fo']} {x['matt']}")
    for x in j["per_slag"]:
        print(f"    {x['dtl']}/{x['fo']} {x['matt']}: {x['skillnad']}°")


def main(argv=None) -> int:
    from . import analys as A
    from . import historik as H
    from . import kontaktark as KA
    from . import paket as P
    from . import s3_facit as S3F

    ap = argparse.ArgumentParser(description="Paketen från telefonen → analys.json och kontaktark.")
    ap.add_argument("paket", nargs="+", help="swinglab-<pass>-<vy>.zip, ett per vy")
    ap.add_argument("--forra", nargs="+", help="förra passets paket (annars ur historiken)")
    ap.add_argument("--langd", type=float, help="spelarens längd i m (sparas i historiken)")
    ap.add_argument("--historik", default=str(H.ROT), help="historikens mapp (standard data/historik)")
    ap.add_argument("--ut", help="skriv hit i stället för i historiken (historiken läses inte)")
    ap.add_argument("--utan-kontaktark", action="store_true")
    ap.add_argument("--claude-text", action="store_true",
                    help="skriv också underlaget till Claude-appen (claude-text.txt, S5b), samma text som telefonen")
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

    # De tidigare passens enheter; analysen tar de med samma klubba, vy och längd (BESLUT B56).
    tidigare = [] if a.ut else H.enheter(rot, fore=pass_id)
    if forra_paket:
        f_pass = forra_paket[0].pass_id
        if f_pass not in {u["pass"] for u in tidigare}:
            tidigare = tidigare + A.enheter(A.analysera(forra_paket, langd, [], skapad=""))
    try:
        analys = A.analysera(paket, langd, tidigare)
    except ValueError as e:
        print(f"Analysen stoppade: {e}")
        return 1
    ut = Path(a.ut) if a.ut else H.pass_mapp(rot, pass_id)
    if a.utan_kontaktark:
        analys["kontaktark"] = {p.vy: {"hoppat": "--utan-kontaktark"} for p in paket}
    else:
        try:
            for fil, p in zip(a.paket, paket):
                # S3:s förskjutning när den finns, så att bilden är Visions ruta (METOD MF1).
                fsk = {k[1]: v for k, v in S3F.las_forskjutningar(p.pass_id).items() if k[0] == p.fil}
                analys["kontaktark"][p.vy] = KA.bygg(Path(fil), p, [r for r in analys["slag"] if r["vy"] == p.vy], ut,
                                                     forskjutning_ms=fsk)
        except P.PaketFel as e:
            print("Paketet går inte att läsa:\n  " + "\n  ".join(e.fel))
            return 1
    A.skriv(analys, ut / "analys.json")
    if a.claude_text:
        # Samma text som "Ask Claude" på telefonen (BESLUT B52): minnet före passets val.
        from . import underlag as U
        skapad = dt.datetime.now().astimezone().isoformat(timespec="seconds")
        if a.ut:
            text = U.text(U.data(A.ren(analys), {}, [], [], skapad))
        else:
            text = U.ur_historik(rot, pass_id, skapad)
        (ut / "claude-text.txt").write_text(text, encoding="utf-8")

    matta = [r for r in analys["slag"] if "matt" in r]
    print(f"Pass {pass_id}: {len(matta)} slag mätta av {len(analys['slag'])}"
          + (f", förra passet {analys['forra']['pass']}" if analys["forra"] else ", inget förra pass")
          + f", baslinje ur {len(analys['baslinje']['pass'])} pass")
    for r in analys["slag"]:
        if "fel" in r:
            print(f"  ej mätt: {r['fel']}")
    for vy, k in analys["kontaktark"].items():
        print(f"  kontaktark {vy}: {k.get('fil') or 'hoppat (' + k['hoppat'] + ')'}")
    print(f"  kandidater: {', '.join(k['fel'] + ' (' + k['status'] + ')' for k in analys['kandidater']) or 'inga'}")
    k = analys["klubba"]
    if any(k["markerade"].values()) or k["fel"]:
        print("  klubban: " + ", ".join(f"{n} slag markerade ({vy.upper()})" for vy, n in k["markerade"].items() if n)
              + (f", {len(k['matt'])} mått" if k["matt"] else "")
              + "".join(f"; {vy.upper()}: klubba.json lästes inte ({f})" for vy, f in k["fel"].items()))
    t = analys["tre_d"]
    if "hoppat" in t:
        print(f"  3D: hoppat ({t['hoppat']})")
    else:
        med = [x["matt"] for x in t["trend"] if x["median"] is not None]
        print(f"  3D utan markörer: {t['parning']['par']} slag parade ({t['parning']['kalla']}), "
              + (f"trend för {len(med)} mått" if med else f"ingen trend (färre än {t['min_slag']} slag)"))
        for k in t["kalibrering"]:
            print(f"    serie {k['serie']['dtl']} (DTL) mot {k['serie']['fo']} (FO): "
                  + (f"hoppad ({k['hoppat']})" if "hoppat" in k else
                     f"lodlinjen ur {k['lodlinje']}, {k['vinkel_mellan_kamerorna']}° mellan kamerorna"))
        for o in t["osaker"]:
            print(f"    osäker: {o}")
    _skriv_telefon(t.get("telefon"))
    print(f"Skrev {ut / 'analys.json'}")
    if a.claude_text:
        print(f"Skrev {ut / 'claude-text.txt'} (klistra in i Claude-appen)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
