"""Två paket från samma pass → 3D: bäckenets och bröstets vridning, X-factor,
stretchen och höfterna vid träffen, utan markörer (PLAN S6a, BESLUT B14).

Kedjan är simuleringens (`tre_d/`, docs/S6_FELBUDGET.md), på telefonernas paket:

1. **Parningen** (METOD MK1): den styrande telefonens `par.json` ger seriernas
   förskjutning, och klicken paras kring den. Utan `par.json`, eller när den
   säger `osaker`, paras klicken utan förhandsvärde.
2. **Tiden** (METOD MK2): varje telefons leder läggs på träffens tid (klicket
   minus ljudets väg, METOD MT1), så att synken på klicket är gjord.
3. **Kalibreringen** (METOD MK3, BESLUT B38): kamerorna kalibreras själva ur lederna,
   en gång per uppställning (serie mot serie, åttapunktsmetoden och Sampson-felet),
   med brännvidden ur seriens synfält och lodlinjen ur manifestet eller kamerornas
   vågräta. En uppställning över spärren hoppas över.
4. **Synken** (METOD MK4) finjusteras per slag på minsta återprojektionsfel,
   och kalibreringen görs om med den.
5. **Trianguleringen** (METOD MK5): utjämning på varje kameras egna tider och
   konfidensviktad DLT.
6. **Måtten** (METOD MK6) med `tre_d/matt.py`, adressen ur 2D-fasernas start.
7. **Passets trend** (METOD MK7): medianen visas bara över minst 10 slag.

Felen nämner slaget och steget, aldrig ett värde (CLAUDE.md, Dataregeln).
"""
from __future__ import annotations

import math

import numpy as np

from . import faser as F
from . import klick as KL
from . import session as S
from .paket import MATS, Paket, Slag, traff_i_serien
from .tre_d import kalibrering as kal
from .tre_d import matt as M3
from .tre_d import triangulering as tri
from .tre_d.sving import I

LAGE = "utan_markorer"         # BESLUT B14: markörerna väntar (S6b)
MIN_KONF = 0.3                 # METOD M1: under det räknas leden som saknad
F_PX_1920 = 1444.0             # METOD MK3: 26 mm ekvivalent, långsidan 1920 px (S6_FELBUDGET §3)
KALIB_KONF = 0.5               # METOD MK3: punktpar till kalibreringen kräver konfidens över det i båda vyerna
KALIB_PAR = 5000               # METOD MK3: högst så många punktpar (slumpat, frö 0)
KALIB_STEG_S = 1 / 60          # METOD MK3: tidsaxeln för kalibreringens punktpar
KALIB_VARV = 2                 # METOD MK4: kalibrering → synk, två varv
VINKEL_OK = (60.0, 120.0)      # METOD MK3: vinkeln mellan kamerorna som felbudgeten godtar (§6.4)
SAMPSON_MAX_PX = 8.0           # METOD MK3: spärren, Sampson-felets median i px på 1920 px långsida
SYNK_SOK_S = 0.0105            # METOD MK4: ±1,5 × klickets ±7 ms
SYNK_SOK2_S = 0.003            # METOD MK4: andra varvet söker så nära det första
SYNK_STEG_S = 0.0005           # METOD MK4: sökningens steg
SYNK_FONSTER = (-0.35, 0.10)   # METOD MK4: nedsvingen kring träffen, s
SYNK_HALVBREDD = 0.02          # METOD MK4: utjämningen i synksökningen (som simuleringen)
HALVBREDD_2D = 0.04            # METOD MK5: 2D-spåren (S6_FELBUDGET §6.6)
HALVBREDD_VINKEL = 0.03        # METOD MK5: vinkelkurvorna före måtten
RUTNAT_S = 1 / 240             # METOD MK5: den gemensamma tidsaxeln
KANT_S = 0.05                  # METOD MK5: så mycket av varje ände av slagets tid lämnas utanför
MIN_RUTOR = 10                 # METOD MK5: färre rutor i en vy (eller på den gemensamma axeln) = slaget hoppas över
MIN_SLAG = 10                  # METOD MK7, BESLUT B14: passets median kräver minst 10 slag
# METOD MK7: en skillnad mellan två pass är tydlig först över √2 × passmedianens SD
# för kedjan på paketen (typiskt brus, 24 påhittade pass, S6_FELBUDGET §6.7), eftersom
# kamerornas läge, kalibreringen och posemodellens fasta avvikelse byts mellan passen. Grader.
TREND_GOLV = {"backen_vrid_topp": 15.7, "brost_vrid_topp": 13.6, "xfaktor_topp": 19.2, "xfaktor_stretch": 8.1,
              "hofter_oppna_traff": 8.3}
SNABBA = [I["v_handled"], I["h_handled"], I["v_armbage"], I["h_armbage"]]

# Måttens namn i analysen och katalogen (katalog_3d.json) ← tre_d/matt.py. METOD MK6
MATT = {"backen_vrid_topp": "backen_topp", "brost_vrid_topp": "brost_topp", "xfaktor_topp": "xfaktor_topp",
        "xfaktor_stretch": "stretch", "hofter_oppna_traff": "hofter_oppna_traff"}


class TreDFel(ValueError):
    """3D gick inte för passet. Meddelandet nämner steget, aldrig ett värde."""


# --- 1. parningen ----------------------------------------------------------------

def _klick(p: Paket, serie: int) -> list[Slag]:
    return sorted((s for s in p.slag if s.serie == serie), key=lambda s: s.klick_s)


def para_utan_prior(a: list[float], b: list[float]) -> dict:
    """Klicken paras utan förhandsvärde: varje skillnad b − a prövas, den som parar
    flest inom 30 ms förfinas med Golf SG:s para() kring sig. Osäker med färre än 3
    par eller när en annan förskjutning (minst 2 · 30 ms bort) parar lika många, som
    MS10. METOD MK1"""
    a_ = np.asarray(a, float)
    b_ = np.asarray(b, float)
    if not len(a_) or not len(b_):
        return {"forskjutning": 0.0, "par": [], "antal": 0, "osaker": True}
    kand = np.unique(np.round((b_[None, :] - a_[:, None]).ravel(), 4))
    antal = np.array([int((np.min(np.abs(a_[:, None] + d - b_[None, :]), axis=0) < KL.TOL_S).sum()) for d in kand])
    i = int(np.argmax(antal))
    bast, flest = float(kand[i]), int(antal[i])
    langt = np.abs(kand - bast) >= 2 * KL.TOL_S
    nast = int(antal[langt].max()) if langt.any() else 0
    r = KL.para(a, b, prior=bast, prior_fonster=KL.TOL_S)
    r["antal"] = flest
    r["osaker"] = flest < KL.MIN_PAR_UTAN_PRIOR or nast >= flest
    return r


def para_slag(dtl: Paket, fo: Paket) -> tuple[list[tuple[Slag, Slag]], dict]:
    """Slagen som båda telefonerna filmat: [(DTL-slaget, FO-slaget)] och hur de
    paras. Ur `par.json` (den styrande telefonens) när den gäller paret, annars ur
    klicken, serie mot serie. METOD MK1"""
    styr = next((p for p in (dtl, fo) if p.par is not None and p.par["vy"] == p.vy), None)
    folj = None if styr is None else (fo if styr is dtl else dtl)
    par: list[tuple[Slag, Slag]] = []
    serier = []
    anvanda: set[tuple[str, int]] = set()

    def lagg_till(sd: list[Slag], sf: list[Slag], r: dict) -> int:
        """r["par"] indexerar DTL-slagen först, FO-slagen sedan."""
        for i_d, i_f, _ in r["par"]:
            par.append((sd[i_d], sf[i_f]))
        return len(r["par"])

    if styr is not None:
        for rad in styr.par["serier"]:
            f = rad["foljare"]
            if f["vy"] != folj.vy or f["pass"] != folj.pass_id or rad["serie"] not in styr.serier \
                    or f["serie"] not in folj.serier:
                continue
            sa, sb = _klick(styr, rad["serie"]), _klick(folj, f["serie"])
            a, b = [s.klick_s for s in sa], [s.klick_s for s in sb]
            if rad.get("osaker"):
                r, kalla = para_utan_prior(a, b), "klicken"
            else:
                r, kalla = KL.para(a, b, prior=rad["forskjutning_s"], prior_fonster=KL.TOL_S), "par.json"
            if r["osaker"]:
                continue
            n = lagg_till(sa, sb, r) if styr is dtl else lagg_till(sb, sa, _vand(r))  # sa är den styrandes
            anvanda |= {(styr.vy, rad["serie"]), (folj.vy, f["serie"])}
            serier.append({"dtl": rad["serie"] if styr is dtl else f["serie"],
                           "fo": f["serie"] if styr is dtl else rad["serie"], "kalla": kalla, "par": n})
    # Serier som par.json inte parat: klicken, serie mot serie, flest par först.
    forslag = []
    for sd in sorted(dtl.serier):
        for sf in sorted(fo.serier):
            if ("dtl", sd) in anvanda or ("fo", sf) in anvanda:
                continue
            sa, sb = _klick(dtl, sd), _klick(fo, sf)
            r = para_utan_prior([s.klick_s for s in sa], [s.klick_s for s in sb])
            if not r["osaker"]:
                forslag.append((-len(r["par"]), sd, sf, sa, sb, r))
    for _, sd, sf, sa, sb, r in sorted(forslag, key=lambda x: x[:3]):
        if ("dtl", sd) in anvanda or ("fo", sf) in anvanda:
            continue
        n = lagg_till(sa, sb, r)
        anvanda |= {("dtl", sd), ("fo", sf)}
        serier.append({"dtl": sd, "fo": sf, "kalla": "klicken", "par": n})
    info = {"kalla": "par.json" if styr is not None else "klicken", "serier": serier, "par": len(par),
            "oparade": {"dtl": len(dtl.slag) - len(par), "fo": len(fo.slag) - len(par)}}
    if dtl.par_fel or fo.par_fel:
        info["par_json_fel"] = dtl.par_fel or fo.par_fel
    return par, info


def _vand(r: dict) -> dict:
    """para() med a och b ombytta: paren som (i_b, i_a)."""
    return dict(r, par=[[jb, ia, -x] for ia, jb, x in r["par"]])


# --- 2. tiden --------------------------------------------------------------------

def spar(p: Paket, s: Slag) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Slagets leder på träffens tid (s): t (N,), uv (N, 13, 2) i pixlar, konfidens
    (N, 13). En saknad led eller en under 0,3 (METOD M1) är NaN med konfidens 0.
    METOD MK2"""
    rutor = sorted(s.lederna["frames"], key=lambda r: r["t"])
    t = np.array([float(r["t"]) for r in rutor]) - traff_i_serien(p, s)
    uv = np.full((len(rutor), len(I), 2), np.nan)
    k = np.zeros((len(rutor), len(I)))
    for i, r in enumerate(rutor):
        for j, led in enumerate(r["joints"]):       # formen är kontrollerad av paket.las
            if led is None:
                continue
            x, y, c = (led["x"], led["y"], led["c"]) if isinstance(led, dict) else led
            if c >= MIN_KONF:
                uv[i, j] = x, y
                k[i, j] = c
    _, unika = np.unique(t, return_index=True)       # två rutor på samma tid: den första
    return t[unika], uv[unika], k[unika]


def K_for(p: Paket, s: Slag) -> tuple[np.ndarray, str]:
    """Slagets K ur dess egen bild: brännvidden ur seriens synfält i manifestet
    (`format.synfalt`), annars enhet.json:s valda format, annars specifikationen
    (1444 px på 1920 px långsida). Synfältet är vågrätt över den liggande bildens
    långsida, som är den upprätta bildens långsida. Huvudpunkten i mitten.
    Svarar K och källan. METOD MK3"""
    w, h = s.lederna["width"], s.lederna["height"]
    lang = max(w, h)
    f, kalla = F_PX_1920 * lang / 1920.0, "specifikationen"
    for k, sf in (("serien", p.serier[s.serie].synfalt), ("enhet.json", p.enhet_synfalt)):
        if sf is not None:
            f, kalla = (lang / 2) / math.tan(math.radians(sf[2]) / 2), k
            break
    return np.array([[f, 0.0, w / 2], [0.0, f, h / 2], [0.0, 0.0, 1.0]]), kalla


# --- 3–5. kalibreringen, synken och trianguleringen -------------------------------

def _rutnat(tA: np.ndarray, tB: np.ndarray, steg: float = RUTNAT_S) -> np.ndarray:
    a, b = max(tA[0], tB[0]) + KANT_S, min(tA[-1], tB[-1]) - KANT_S
    if not b > a:
        return np.zeros(0)
    return np.arange(a, b, steg)


def _jamnade(d: dict, forsk: float, steg: float = RUTNAT_S):
    """Båda vyerna utjämnade (±40 ms) på en gemensam tidsaxel, DTL flyttad med synken.
    De robusta vikterna räknas en gång per slag (de beror inte på förskjutningen)."""
    if "vA" not in d:
        d["vA"] = tri.robusta_vikter(d["tA"], d["uvA"], d["kA"], HALVBREDD_2D)
        d["vB"] = tri.robusta_vikter(d["tB"], d["uvB"], d["kB"], HALVBREDD_2D)
    t_g = _rutnat(d["tA"], d["tB"] - forsk, steg)
    a, ka = tri.jamna(d["tA"], d["uvA"], d["kA"], t_g, HALVBREDD_2D, vikter=d["vA"])
    b, kb = tri.jamna(d["tB"] - forsk, d["uvB"], d["kB"], t_g, HALVBREDD_2D, vikter=d["vB"])
    return t_g, a, ka, b, kb


def _upp_i_kamera(lodlinje) -> np.ndarray | None:
    if lodlinje is None:
        return None
    v = np.asarray(lodlinje, float)
    return v / np.linalg.norm(v)


def _normera(uv: np.ndarray, K: np.ndarray) -> np.ndarray:
    return np.column_stack([uv, np.ones(len(uv))]) @ np.linalg.inv(K).T


def kalibrera(slagen: list[dict], forsk: list[float], uppA=None, uppB=None):
    """Kamerorna för en uppställning (en serie per telefon) ur dess slags leder ihop.
    Varje slags punkter normeras med slagets egen K. FO är kamera A, DTL kamera B.
    Lodlinjen: FO:s ur manifestet, annars DTL:s vriden till A, annars kamerornas
    vågräta. Svarar (R, t, upp i A:s ram, info). METOD MK3"""
    x1, x2, w = [], [], []
    for d, f in zip(slagen, forsk):
        _, a, ka, b, kb = _jamnade(d, f, KALIB_STEG_S)
        ok = np.isfinite(a).all(-1) & np.isfinite(b).all(-1) & (ka > KALIB_KONF) & (kb > KALIB_KONF)
        x1.append(_normera(a[ok], d["KA"]))
        x2.append(_normera(b[ok], d["KB"]))
        w.append(np.sqrt(ka[ok] * kb[ok]))
    x1, x2, w = np.concatenate(x1), np.concatenate(x2), np.concatenate(w)
    if len(x1) > KALIB_PAR:
        val = np.random.default_rng(0).choice(len(x1), KALIB_PAR, replace=False)
        x1, x2, w = x1[val], x2[val], w[val]
    f_px = float(np.median([d["KA"][0, 0] for d in slagen]))
    lang = float(np.median([max(d["KA"][0, 2], d["KA"][1, 2]) * 2 for d in slagen]))
    try:
        R, t, samp = kal.relativ_ur_normerade(x1, x2, w, f_px)
    except (ValueError, np.linalg.LinAlgError):
        raise TreDFel("kalibreringen: för få leder syns i båda vyerna") from None
    if uppA is not None and uppB is not None:
        upp, kalla = uppA + R.T @ uppB, "manifest"
    elif uppA is not None:
        upp, kalla = uppA, "manifest"
    elif uppB is not None:
        upp, kalla = R.T @ uppB, "manifest"
    else:
        try:
            upp, kalla = kal.upp_ur_vagrata(R), "kamerornas_vagrata"
        except ValueError:
            raise TreDFel("kalibreringen: kamerorna står för nära samma riktning") from None
    kamA, kamB = kal.varld(np.eye(3), np.eye(3), R, t, upp)
    # Vinkeln mellan blickriktningarna i markplanet (uppställningen, S6_FELBUDGET §6.4).
    fa, fb = kamA.R[2].copy(), kamB.R[2].copy()
    fa[2] = fb[2] = 0.0
    vinkel = math.degrees(math.acos(float(np.clip(fa @ fb / (np.linalg.norm(fa) * np.linalg.norm(fb)), -1, 1))))
    info = {"lodlinje": kalla, "sampson_px": round(samp * f_px * 1920.0 / lang, 2),
            "vinkel_mellan_kamerorna": round(vinkel, 1), "vinkel_ok": VINKEL_OK[0] <= vinkel <= VINKEL_OK[1]}
    return R, t, upp, info


def kameror(d: dict, R, t, upp):
    """Slagets två kameror: uppställningens läge med slagets egen K."""
    return kal.varld(d["KA"], d["KB"], R, t, upp)


def synka(kamA, kamB, d: dict, mitt: float = 0.0, sok: float = SYNK_SOK_S) -> float:
    """Hur mycket DTL:s klocka går före FO:s efter klicket (s), vald på minsta
    återprojektionsfel för handlederna och armbågarna i nedsvingen, sökt ± `sok`
    kring `mitt`. METOD MK4"""
    try:
        return mitt + float(tri.synk_reprojektion([kamA, kamB], d["tA"], d["uvA"], d["kA"], d["tB"] - mitt, d["uvB"],
                                                  d["kB"], SNABBA, SYNK_FONSTER, sok, SYNK_STEG_S, SYNK_HALVBREDD))
    except ValueError:                 # inget i fönstret: förra värdet får stå
        return mitt


def triangulera(kamA, kamB, d: dict, forsk: float):
    """Slagets 3D-leder på den gemensamma tidsaxeln och återprojektionens median (px).
    METOD MK5"""
    t_g, a, ka, b, kb = _jamnade(d, forsk)
    P = tri.triangulera([kamA, kamB], np.stack([a, b]), np.stack([ka, kb]))
    e = tri.aterprojektionsfel([kamA, kamB], P, np.stack([a, b]))
    fin = e[np.isfinite(e)]
    return t_g, P, float(np.median(fin)) if len(fin) else float("nan")


# --- 6. måtten ---------------------------------------------------------------------

def _start(rad_fo: dict | None, rad_dtl: dict | None, d: dict, forsk: float) -> float | None:
    """Baksvingens start på träffens tid ur 2D-faserna (METOD M4): FO:s, annars
    DTL:s flyttad med synken; saknas starten: toppen − 1,2 s. METOD MK6"""
    for rad, skift in ((rad_fo, d["traffA"]), (rad_dtl, d["traffB"] + forsk)):
        if rad and rad.get("faser") and rad["faser"].get("start") is not None:
            return rad["faser"]["start"] - skift
    for rad, skift in ((rad_fo, d["traffA"]), (rad_dtl, d["traffB"] + forsk)):
        if rad and rad.get("faser") and rad["faser"].get("topp") is not None:
            return rad["faser"]["topp"] - skift - F.TOPP_ADRESS_S
    return None


def matt(t: np.ndarray, P: np.ndarray, t_start: float, hand: str) -> dict | str:
    """Måtten ur 3D-lederna på träffens tid (träffen = 0), eller skälet till att de
    saknas. Adressens fönster och träffen ska ligga inom slagets tidsaxel (annars
    hålls ett ändvärde fast). En vänsterspelare speglas, så att vridningen bort från
    målet är positiv för båda. METOD MK6"""
    adress = (t_start + F.ADRESS[0], t_start + F.ADRESS[1])
    if not (len(t) and t[0] <= adress[0] and t[-1] >= 0.0):
        return "adressen eller träffen ligger utanför slagets tid"
    if hand == "vanster":
        P = P.copy()
        P[..., 0] *= -1
    m = M3.svingmatt(P, t, t_start, 0.0, adress, topp="hander", utjamna=HALVBREDD_VINKEL)
    return {namn: m[k] for namn, k in MATT.items() if np.isfinite(m[k])}


# --- hela passet -------------------------------------------------------------------

def _uppstallning(dtl: Paket, fo: Paket, grupp: list[dict], rad: dict) -> tuple[dict, list[dict]]:
    """En uppställning (en DTL-serie mot en FO-serie): kalibreringen i två varv med
    synken, spärren och måtten per slag. Svarar (info, slagens rader). METOD MK3, MK4"""
    sd, sf = grupp[0]["dtl"].serie, grupp[0]["fo"].serie
    info = {"serie": {"dtl": sd, "fo": sf}, "slag": len(grupp),
            "f_kalla": {"dtl": grupp[0]["fKB"], "fo": grupp[0]["fKA"]}}
    fel = [x for x in (fo.serier[sf].lodlinje_fel, dtl.serier[sd].lodlinje_fel) if x]
    if fel:
        info["lodlinje_fel"] = fel
    uppA, uppB = _upp_i_kamera(fo.serier[sf].lodlinje), _upp_i_kamera(dtl.serier[sd].lodlinje)
    forsk = [0.0] * len(grupp)
    try:
        for varv in range(KALIB_VARV):
            R, t, upp, _ = kalibrera(grupp, forsk, uppA, uppB)
            sok = SYNK_SOK_S if varv == 0 else SYNK_SOK2_S
            forsk = [synka(*kameror(d, R, t, upp), d, f, sok) for d, f in zip(grupp, forsk)]
        R, t, upp, k = kalibrera(grupp, forsk, uppA, uppB)
    except TreDFel as e:
        info["hoppat"] = str(e)
        return info, []
    info.update(k)
    if k["sampson_px"] > SAMPSON_MAX_PX:
        info["hoppat"] = "kalibreringen: Sampson-felet är över spärren"
        return info, []
    ut = []
    for d, f in zip(grupp, forsk):
        r = {"dtl": d["dtl"].id, "fo": d["fo"].id, "serie": {"dtl": sd, "fo": sf}, "synk_ms": round(f * 1000, 1)}
        t_start = _start(rad.get(("fo", d["fo"].id)), rad.get(("dtl", d["dtl"].id)), d, f)
        if t_start is None:
            r["fel"] = "faserna saknas i båda vyerna"
            ut.append(r)
            continue
        tg, P, rep = triangulera(*kameror(d, R, t, upp), d, f)
        r["aterprojektion_px"] = round(rep, 1) if math.isfinite(rep) else None
        m = matt(tg, P, t_start, dtl.spelhand)
        r["matt" if isinstance(m, dict) else "fel"] = m
        ut.append(r)
    return info, ut


def analysera(dtl: Paket, fo: Paket, rader: list[dict]) -> dict:
    """3D för passet: parningen, en kalibrering per uppställning (serie mot serie),
    måtten per slag och passets trend. `rader` är 2D-analysens slag
    (analys.mat_paket) för båda paketen. METOD MK1–MK7"""
    par, parning = para_slag(dtl, fo)
    rad = {(r["vy"], r["id"]): r for r in rader}
    grupper: dict[tuple[int, int], list[dict]] = {}
    for sd, sf in par:
        if sd.dom not in MATS or sf.dom not in MATS or sd.detection_wrong or sf.detection_wrong \
                or sd.lederna is None or sf.lederna is None:
            continue
        tA, uvA, kA = spar(fo, sf)
        tB, uvB, kB = spar(dtl, sd)
        if min(len(tA), len(tB), len(_rutnat(tA, tB))) < MIN_RUTOR:
            continue
        (KA, fKA), (KB, fKB) = K_for(fo, sf), K_for(dtl, sd)
        grupper.setdefault((sd.serie, sf.serie), []).append(
            {"dtl": sd, "fo": sf, "tA": tA, "uvA": uvA, "kA": kA, "tB": tB, "uvB": uvB, "kB": kB, "KA": KA, "KB": KB,
             "fKA": fKA, "fKB": fKB, "traffA": traff_i_serien(fo, sf), "traffB": traff_i_serien(dtl, sd)})
    if not grupper:
        raise TreDFel("parningen: inga slag som båda telefonerna filmat och som går att mäta")
    kalib, ut_slag, osaker = [], [], []
    for nyckel in sorted(grupper):
        info, ut = _uppstallning(dtl, fo, grupper[nyckel], rad)
        kalib.append(info)
        ut_slag += ut
        namn = f"serie {nyckel[0]} (DTL) mot {nyckel[1]} (FO)"
        if "hoppat" not in info and not info["vinkel_ok"]:
            osaker.append(f"{namn}: vinkeln mellan kamerorna utanför {VINKEL_OK[0]:.0f}–{VINKEL_OK[1]:.0f}°")
        if info.get("lodlinje_fel"):
            osaker.append(f"{namn}: lodlinjen i manifestet användes inte")
    if not ut_slag:
        raise TreDFel("kalibreringen: ingen serie gick att kalibrera under spärren")
    matta = [r["matt"] for r in ut_slag if "matt" in r]
    sammanf = S.sammanfatta(matta)
    n = {m: sum(1 for x in matta if m in x) for m in MATT}
    return {"lage": LAGE, "min_slag": MIN_SLAG, "matt": list(MATT), "parning": parning, "kalibrering": kalib,
            "osaker": osaker, "slag": ut_slag, "n": n,
            "session": {m: v for m, v in sammanf.items() if v["n"] >= MIN_SLAG}}


def jamfor(nu: dict, forra: dict | None) -> dict | None:
    """Trenden mot förra passet för måtten som har en median i båda: skillnaden
    (METOD M26) och om den är tydlig, alltså större än både förra passets spridning
    och golvet för två pass (TREND_GOLV). METOD MK7"""
    if not forra or "session" not in forra or "session" not in nu:
        return None
    ut = S.jamfor(nu["session"], forra["session"])
    for m, j in ut.items():
        j["golv"] = TREND_GOLV[m]
        j["tydlig"] = abs(j["skillnad"]) > max(j["spridning"], TREND_GOLV[m])
    return ut
