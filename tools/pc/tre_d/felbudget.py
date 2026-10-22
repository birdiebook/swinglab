"""Felbudgeten för S6: Monte Carlo över hela kedjan, från påhittad sving till mått.

    python3 tools/pc/tre_d/felbudget.py            # alla tabeller (några minuter)
    python3 tools/pc/tre_d/felbudget.py --snabb    # färre försök
    python3 tools/pc/tre_d/felbudget.py --bara bas,bidrag

Varje försök: en slumpad sving (`slumpa_sving`), två kameror med placeringsfel,
egna bildtider med tappade rutor, synkfel, 2D-brus och skymning,
kalibrering (mot mattan eller ur lederna), finjustering av synken,
utjämning, triangulering och måtten. Felet är skattat − sant, där det sanna
räknas med samma definition (matt.py) på de sanna lederna.

Resultaten och slutsatserna står i docs/S6_FELBUDGET.md.
"""
from __future__ import annotations

import argparse
import sys
import time
import warnings
from dataclasses import dataclass, replace, asdict
from pathlib import Path

import numpy as np

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
    __package__ = "tre_d"

from . import kalibrering as kal  # noqa: E402
from . import kamera as km  # noqa: E402
from . import matt  # noqa: E402
from . import triangulering as tri  # noqa: E402
from .sving import I, LEDER, Sving, slumpa_sving, segment_rotation  # noqa: E402

warnings.filterwarnings("ignore", category=RuntimeWarning)  # tomma medel blir NaN, och räknas som bortfall

SNABBA = [I["v_handled"], I["h_handled"], I["v_armbage"], I["h_armbage"]]


@dataclass(frozen=True)
class Uppstallning:
    # placeringen
    avstand: float = 3.0
    hojd: float = 1.0
    vinkel: float = 90.0  # mellan kamerorna; 90 = FO + DTL
    azimut_fo: float = 270.0
    azimut_fel_deg: float = 5.0  # stativens läge runt spelaren (1σ); kameran siktar ändå på spelaren
    f_px: float = km.F_PX
    # bilden
    brus: str = "typiskt"
    skala: str = "kropp"
    tapp: float = km.TAPP
    exponering: float = 1 / 1000
    skymning: bool = True
    # synken
    synkfel_ms: float = 7.0  # likformigt ±, efter klicket
    synk: str = "reprojektion"  # perfekt | ingen | fart | reprojektion
    # kalibreringen
    kalib: str = "matta"  # perfekt | matta | sjalv
    f_rel: float = 0.005  # ChArUco: brännviddens fel (1σ, relativt)
    c_px: float = 3.0  # ChArUco: huvudpunktens fel (1σ)
    matt_n: int = 10
    matt_sida: float = 1.5
    matt_hojd: bool = False
    matt_varld_m: float = 0.005  # mattpunkternas lägen (1σ per axel)
    matt_klick_px: float = 2.0  # punkterna i bilden (1σ per axel)
    grav_deg: float = 1.0  # lodlinjen ur telefonens accelerometer (1σ per axel)
    # utjämningen
    halvbredd: float = 0.02  # 2D-spåren
    # en pinne genom bältet med färgade ändar i stället för höftpunkterna (m, 0 = av)
    hoftpinne: float = 0.0
    markor_px: float = 1.0  # ändarnas läge i bilden (1σ per axel), färgdetektor
    pinne_skymd: bool = True  # False = ändarna antas synas i båda vyerna (bästa fall)
    pinnvinkel: float = 0.0  # pinnens vinkel mot höftlinjen i markplanet
    ryggstav: float = 0.0  # stav i en sele över övre ryggen i stället för axelpunkterna (m, 0 = av)
    hoft_bredd: float = 0.11  # avståndet mellan höftpunkterna, andel av längden (antagande)
    vinkel_utjamning: float = 0.03  # vinkelkurvorna före måtten (halvbredd, s)


def _kameror(u: Uppstallning, rng, gir=True):
    gA = rng.normal(0, u.azimut_fel_deg) if gir else 0.0
    gB = rng.normal(0, u.azimut_fel_deg) if gir else 0.0
    A = km.placera(u.azimut_fo + gA, u.avstand, u.hojd, "FO", u.f_px)
    B = km.placera(u.azimut_fo - u.vinkel + gB, u.avstand, u.hojd, "B", u.f_px)
    return A, B


def _observera(kam, s, t, u: Uppstallning, rng, fast=None):
    brus = km.BRUS[u.brus]
    if not u.skymning:
        brus = replace(brus, skymd_faktor=1.0)
    obs, konf, sky = km.observera(kam, s, t, brus, rng, u.exponering, u.skala, fast)
    markorer = ([I["v_hoft"], I["h_hoft"]] if s.hoftpinne > 0 else []) + \
        ([I["v_axel"], I["h_axel"]] if s.ryggstav > 0 else [])
    if markorer:
        # pinnarnas ändar hittas som färgade fläckar: litet brus, ingen fast avvikelse,
        # och en skymd ände syns inte alls
        for j in markorer:
            P = s.leder(t)[:, j]
            uv = kam.projicera(P) + u.markor_px * rng.standard_normal((len(t), 2))
            dold = sky[:, j] if u.pinne_skymd else np.zeros(len(t), bool)
            uv[dold] = np.nan
            obs[:, j] = uv
            konf[:, j] = np.where(dold, 0.0, 0.95)
    if not u.skymning:
        konf = np.where(np.isfinite(obs[..., 0]), np.clip(rng.normal(0.85, 0.08, konf.shape), 0.02, 1), 0)
    return obs, konf


def _matta(kam_sann, u: Uppstallning, rng):
    K = kal.stord_K(kam_sann.K, u.f_rel, u.c_px, rng)
    X = kal.mattpunkter(u.matt_n, u.matt_sida, u.matt_hojd)
    uv = kam_sann.projicera(X) + u.matt_klick_px * rng.standard_normal((len(X), 2))
    Xm = X + u.matt_varld_m * rng.standard_normal(X.shape) * np.array([1, 1, 0 if not u.matt_hojd else 1])
    Xm[X[:, 2] == 0, 2] = 0.0
    return kal.kalibrera_mot_matta(K, Xm, uv, kam_sann.namn)


def _upp_i_kamera(kam_sann, sigma_deg, rng):
    upp = kam_sann.R @ np.array([0.0, 0.0, 1.0])
    return kal.slumprotation(sigma_deg, rng) @ upp


def nytt_pass(u: Uppstallning, rng: np.random.Generator) -> dict:
    """Det som är gemensamt för ett pass: kamerornas lägen, kalibreringen mot
    mattan och posemodellens fasta avvikelse per led och vy."""
    A, B = _kameror(u, rng)
    if u.kalib == "perfekt":
        kal_AB = (A, B)
    elif u.kalib == "matta":
        kal_AB = (_matta(A, u, rng), _matta(B, u, rng))
    elif u.kalib == "sjalv":
        kal_AB = (None, None)
    else:
        raise ValueError(u.kalib)
    J = len(LEDER)
    return {"A": A, "B": B, "kal": kal_AB, "fastA": rng.standard_normal((J, 2)),
            "fastB": rng.standard_normal((J, 2))}


def forsok(u: Uppstallning, rng: np.random.Generator, s: Sving | None = None, pas: dict | None = None) -> dict:
    """Ett försök. Returnerar {'sant': mått, '3d': fel, 'fo_en': fel, 'tva_2d': fel, ...}."""
    s = s or slumpa_sving(rng)
    s.hoft_bredd = u.hoft_bredd * s.langd
    if u.hoftpinne > 0 or u.ryggstav > 0:
        s.hoftpinne, s.pinnvinkel, s.ryggstav = u.hoftpinne, u.pinnvinkel, u.ryggstav
    pas = pas or nytt_pass(u, rng)
    A, B = pas["A"], pas["B"]
    kamA, kamB = pas["kal"]
    tA = km.bildtider(s.t_slut, rng, tapp=u.tapp)
    tB = km.bildtider(s.t_slut, rng, tapp=u.tapp)
    delta = rng.uniform(-1, 1) * u.synkfel_ms / 1000
    obsA, kA = _observera(A, s, tA, u, rng, pas["fastA"])
    obsB, kB = _observera(B, s, tB, u, rng, pas["fastB"])
    tB_rap = tB + delta  # B:s klocka går före med delta

    t_g = np.arange(0.05, s.t_slut - 0.05, 1 / 240)
    adress = (0.05, s.t_start - 0.05)
    fonster = (s.t_traff - 0.35, s.t_traff + 0.10)  # nedsvingen kring klicket
    sok = max(0.012, 1.5 * u.synkfel_ms / 1000)

    def sjalvkal(d):
        KA = kal.stord_K(A.K, u.f_rel, u.c_px, rng)
        KB = kal.stord_K(B.K, u.f_rel, u.c_px, rng)
        a, ka = tri.jamna(tA, obsA, kA, t_g, u.halvbredd)
        b, kb = tri.jamna(tB_rap - d, obsB, kB, t_g, u.halvbredd)
        return kal.sjalvkalibrera(KA, a, ka, KB, b, kb, _upp_i_kamera(A, u.grav_deg, rng), rng=rng)

    # synken
    if u.synk == "perfekt":
        d_est = delta
    elif u.synk == "ingen":
        d_est = 0.0
    elif u.synk == "fart":
        d_est = tri.synk_fart(tA, obsA, kA, tB_rap, obsB, kB, SNABBA, fonster, sok, halvbredd=u.halvbredd)
    elif u.synk == "reprojektion":
        if kamA is None:
            d0 = tri.synk_fart(tA, obsA, kA, tB_rap, obsB, kB, SNABBA, fonster, sok, halvbredd=u.halvbredd)
            kamA, kamB = sjalvkal(d0)
        d_est = tri.synk_reprojektion([kamA, kamB], tA, obsA, kA, tB_rap, obsB, kB, SNABBA, fonster, sok,
                                      halvbredd=u.halvbredd)
    else:
        raise ValueError(u.synk)
    if kamA is None or (u.kalib == "sjalv" and u.synk == "reprojektion"):
        kamA, kamB = sjalvkal(d_est)

    uvA, kgA = tri.jamna(tA, obsA, kA, t_g, u.halvbredd)
    uvB, kgB = tri.jamna(tB_rap - d_est, obsB, kB, t_g, u.halvbredd)
    P = tri.triangulera([kamA, kamB], np.stack([uvA, uvB]), np.stack([kgA, kgB]))

    # sant, samma definition på de sanna lederna
    t_s = np.arange(0.05, s.t_slut - 0.05, 0.001)
    P_s = s.leder(t_s)
    sant = matt.svingmatt(P_s, t_s, s.t_start, s.t_traff, adress)
    est = matt.svingmatt(P, t_g, s.t_start, s.t_traff, adress, utjamna=u.vinkel_utjamning)
    ut = {"sant": sant, "3d": {k: est[k] - sant[k] for k in matt.MATT},
          "synk_rest_ms": (d_est - delta) * 1000, "t_topp_fel_ms": (est["t_topp"] - sant["t_topp"]) * 1000}

    # en kamera framifrån (förkortningen), toppen ur bilden (händerna högst = minst v)
    fp = matt.forkortning(uvA[:, I["v_hoft"]], uvA[:, I["h_hoft"]], t_g, adress)
    fs = matt.forkortning(uvA[:, I["v_axel"]], uvA[:, I["h_axel"]], t_g, adress)
    v = 0.5 * (uvA[:, I["v_handled"], 1] + uvA[:, I["h_handled"], 1])
    f = (t_g >= s.t_start) & (t_g < s.t_traff) & np.isfinite(v)
    tt = float(t_g[f][np.argmin(v[f])]) if f.any() else float("nan")
    en = matt.matt_ur_vinklar(t_g, fp, fs, tt, s.t_traff)
    en["hofter_oppna_traff"] = matt._vid(t_g, fp, s.t_traff)
    ut["fo_en"] = {k: en[k] - sant[k] for k in matt.MATT}

    # två vyer utan kalibrering och triangulering (bildmåtten ihop), nominell placering
    nA, nB = _kameror(u, rng, gir=False)
    p2 = matt.bildmatt_tva_vyer(uvA[:, I["v_hoft"]], uvA[:, I["h_hoft"]], uvB[:, I["v_hoft"]], uvB[:, I["h_hoft"]],
                                nA.R[0], nB.R[0], u.f_px / u.avstand, u.f_px / u.avstand, t_g, adress)
    s2 = matt.bildmatt_tva_vyer(uvA[:, I["v_axel"]], uvA[:, I["h_axel"]], uvB[:, I["v_axel"]], uvB[:, I["h_axel"]],
                                nA.R[0], nB.R[0], u.f_px / u.avstand, u.f_px / u.avstand, t_g, adress)
    tv = matt.matt_ur_vinklar(t_g, p2, s2, est["t_topp"], s.t_traff)
    ut["tva_2d"] = {k: tv[k] - sant[k] for k in matt.MATT}
    return ut


def sammanfatta(fel: np.ndarray) -> dict:
    fel = fel[np.isfinite(fel)]
    if len(fel) == 0:
        return dict(bias=np.nan, sd=np.nan, rmse=np.nan, p95=np.nan, inom5=np.nan, n=0)
    return dict(bias=float(fel.mean()), sd=float(fel.std(ddof=1)) if len(fel) > 1 else 0.0,
                rmse=float(np.sqrt(np.mean(fel ** 2))), p95=float(np.percentile(np.abs(fel), 95)),
                inom5=float(np.mean(np.abs(fel) <= 5)), n=len(fel))


def monte_carlo(u: Uppstallning, n: int, seed: int = 1, metoder=("3d",)) -> dict:
    rng = np.random.default_rng(seed)
    samlat = {m: {k: [] for k in matt.MATT} for m in metoder}
    extra = {"synk_rest_ms": [], "t_topp_fel_ms": []}
    for _ in range(n):
        r = forsok(u, rng)
        for m in metoder:
            for k in matt.MATT:
                samlat[m][k].append(r[m][k])
        for k in extra:
            extra[k].append(r[k])
    ut = {m: {k: sammanfatta(np.array(v)) for k, v in d.items()} for m, d in samlat.items()}
    ut["extra"] = {k: sammanfatta(np.array(v)) for k, v in extra.items()}
    return ut


def pass_monte_carlo(u: Uppstallning, n_pass: int, n_slag: int = 10, seed: int = 1) -> dict:
    """Passets median: samma kameror, kalibrering och fasta avvikelse för alla
    slag i passet. Felet är medianen av slagens fel (det appen visar som trend)."""
    rng = np.random.default_rng(seed)
    samlat = {k: [] for k in matt.MATT}
    for _ in range(n_pass):
        pas = nytt_pass(u, rng)
        fel = {k: [] for k in matt.MATT}
        for _ in range(n_slag):
            r = forsok(u, rng, pas=pas)
            for k in matt.MATT:
                fel[k].append(r["3d"][k])
        for k in matt.MATT:
            samlat[k].append(float(np.nanmedian(fel[k])))
    return {"3d": {k: sammanfatta(np.array(v)) for k, v in samlat.items()}}


# --------------------------------------------------------------------------
# Facit: stå i adress och vrid axlarna mot linjer på marken


def statisk_sving(bal_vrid: float, backen_vrid: float = 0.0, langd: float = 1.80) -> Sving:
    s = Sving(langd=langd)
    for k, v in s.nyckel.items():
        s.nyckel[k] = [v[0]] * len(v)
    s.nyckel["bal_vrid"] = [bal_vrid] * len(s.nyckel["bal_vrid"])
    s.nyckel["backen_vrid"] = [backen_vrid] * len(s.nyckel["backen_vrid"])
    s.__post_init__()
    return s


def _rubrik(L, R):
    v = L - R
    return np.degrees(np.arctan2(v[..., 1], v[..., 0]))


def facit_forsok(u: Uppstallning, rng, vinklar=(45.0, 90.0), tid=1.0, pinne_klick_px=2.0,
                 manniska_deg=3.0) -> dict:
    """Facit i adress. För varje vinkel: en stillastående pose där axellinjen
    (projicerad) står på vinkeln, filmad `tid` s, triangulerad och jämförd med
    posen på 0°. Dessutom en pinne (1 m) tvärs över bröstet, vars ändar
    klickas i båda vyerna. Returnerar fel per vinkel för axellinjen mot
    golvlinjen (med människans inriktningsfel), axellinjen mot pinnen, och
    pinnen mot bröstkorgens sanna sidoaxel."""
    A, B = _kameror(u, rng)
    kamA, kamB = (_matta(A, u, rng), _matta(B, u, rng)) if u.kalib != "perfekt" else (A, B)
    ut = {}
    matningar = {}
    for vin in (0.0,) + tuple(vinklar):
        # Euler-vridning som ger axellinjen på `vin` (fixpunkt)
        E = vin
        for _ in range(8):
            s = statisk_sving(E)
            P0 = s.leder([0.5])[0]
            ref = _rubrik(statisk_sving(0.0).leder([0.5])[0][I["v_axel"]], statisk_sving(0.0).leder([0.5])[0][I["h_axel"]])
            proj = -(_rubrik(P0[I["v_axel"]], P0[I["h_axel"]]) - ref)
            E += vin - proj
        s = statisk_sving(E)
        tA = km.bildtider(tid, rng, tapp=u.tapp)
        tB = km.bildtider(tid, rng, tapp=u.tapp)
        obsA, kA = _observera(A, s, tA, u, rng)
        obsB, kB = _observera(B, s, tB, u, rng)
        t_g = np.arange(0.1, tid - 0.1, 1 / 240)
        uvA, kgA = tri.jamna(tA, obsA, kA, t_g, u.halvbredd)
        uvB, kgB = tri.jamna(tB, obsB, kB, t_g, u.halvbredd)
        P = tri.triangulera([kamA, kamB], np.stack([uvA, uvB]), np.stack([kgA, kgB]))
        axel = _rubrik(P[:, I["v_axel"]], P[:, I["h_axel"]])
        axel = float(np.degrees(np.arctan2(np.nanmean(np.sin(np.radians(axel))), np.nanmean(np.cos(np.radians(axel))))))
        # pinnen: 1 m längs bröstkorgens sidoaxel, 12 cm framför bröstet
        _, Rt, k = s.segment(np.array([0.5]))
        am = 0.5 * (s.leder([0.5])[0][I["v_axel"]] + s.leder([0.5])[0][I["h_axel"]])
        lat, bak = Rt[0][:, 0], Rt[0][:, 1]
        ander = np.array([am - 0.12 * bak + 0.5 * lat, am - 0.12 * bak - 0.5 * lat])
        uv_p = np.stack([kamera.projicera(ander) + pinne_klick_px * rng.standard_normal((2, 2))
                         for kamera in (A, B)])[:, None]
        Pp = tri.triangulera([kamA, kamB], uv_p, np.ones((2, 1, 2)))[0]
        pinne = float(_rubrik(Pp[0], Pp[1]))
        thorax = float(np.degrees(np.arctan2(lat[1], lat[0])))
        matningar[vin] = (axel, pinne, thorax)
    a0, p0, th0 = matningar[0.0]
    for vin in vinklar:
        a, p, th = matningar[vin]
        axel_rel = -(a - a0)
        pinne_rel = -(p - p0)
        thorax_rel = -(th - th0)
        # människan når linjen med ett eget fel (antagande, ±manniska_deg)
        manniska = rng.normal(0, manniska_deg)
        ut[vin] = {
            "axel_mot_golvlinje": axel_rel - vin + manniska,
            "axel_mot_pinne": axel_rel - pinne_rel,
            "pinne_mot_thorax": pinne_rel - thorax_rel,
            "axel_matfel": axel_rel - vin,
        }
    return ut


def facit_monte_carlo(u: Uppstallning, n: int, seed: int = 7, **kw) -> dict:
    rng = np.random.default_rng(seed)
    alla = {}
    for _ in range(n):
        r = facit_forsok(u, rng, **kw)
        for vin, d in r.items():
            for k, v in d.items():
                alla.setdefault(vin, {}).setdefault(k, []).append(v)
    return {vin: {k: sammanfatta(np.array(v)) for k, v in d.items()} for vin, d in alla.items()}


# --------------------------------------------------------------------------
# Definitionerna i modellen


def definitioner(s: Sving | None = None) -> dict:
    """Samma sving med olika definitioner: Euler-vinkeln (ZXY), bröstkorgens
    sidoaxel projicerad, och axellinjen (akromion) projicerad."""
    s = s or Sving()
    t = np.arange(0.05, s.t_slut - 0.05, 0.001)
    P = s.leder(t)
    adress = (0.05, s.t_start - 0.05)
    m = matt.svingmatt(P, t, s.t_start, s.t_traff, adress)
    Rp, Rt, k = s.segment(t)
    th = matt.linjevinkel(Rt[:, :, 0], np.zeros_like(Rt[:, :, 0]), t, adress)
    pe = matt.linjevinkel(Rp[:, :, 0], np.zeros_like(Rp[:, :, 0]), t, adress)
    tt, ti = m["t_topp"], s.t_traff
    vid = lambda y, x: float(np.interp(x, t, y))  # noqa: E731
    eul_p, eul_t = k["backen_vrid"], k["bal_vrid"]
    return {
        "topp": {"backen_euler": vid(eul_p, tt), "backen_linje": m["backen_topp"],
                 "brost_euler": vid(eul_t, tt), "thorax_linje": vid(th, tt), "axel_linje": m["brost_topp"],
                 "x_euler": vid(eul_t - eul_p, tt), "x_thorax": vid(th - pe, tt), "x_axel": m["xfaktor_topp"]},
        "traff": {"backen_euler": vid(eul_p, ti), "backen_linje": -m["hofter_oppna_traff"],
                  "brost_euler": vid(eul_t, ti), "thorax_linje": vid(th, ti), "axel_linje": m["brost_traff"]},
        "stretch_axel": m["stretch"],
    }


# --------------------------------------------------------------------------
# Tabellerna

NAMN = {"backen_topp": "Bäcken, topp", "brost_topp": "Bröst, topp", "xfaktor_topp": "X-factor, topp",
        "stretch": "Stretch", "hofter_oppna_traff": "Höfter öppna, träff"}


def _rad(namn, res, falt="3d", vis=("rmse",)):
    celler = []
    for k in matt.MATT:
        r = res[falt][k]
        if vis == ("rmse",):
            celler.append(f"{r['rmse']:.1f}")
        else:
            celler.append(f"{r['bias']:+.1f} / {r['sd']:.1f}")
    return f"| {namn} | " + " | ".join(celler) + " |"


def _huvud(forsta, extra=""):
    kol = [NAMN[k] for k in matt.MATT] + ([extra] if extra else [])
    return f"| {forsta} | " + " | ".join(kol) + " |\n|" + "---|" * (len(kol) + 1)


def svep(rubrik, forsta, rader, n, seed, falt="3d", vis=("rmse",), extra=False):
    print(f"\n### {rubrik}\n")
    print(_huvud(forsta, "Synkens rest (ms, RMS)" if extra else ""))
    for namn, u in rader:
        t0 = time.time()
        res = monte_carlo(u, n, seed, metoder=(falt,) if falt != "3d" else ("3d",))
        rad = _rad(namn, res, falt, vis)
        if extra:
            rad += f" {res['extra']['synk_rest_ms']['rmse']:.1f} |"
        print(rad, flush=True)
        print(f"<!-- {namn}: {time.time() - t0:.0f} s -->", file=sys.stderr)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--n", type=int, default=60)
    ap.add_argument("--snabb", action="store_true")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--bara", default="")
    a = ap.parse_args(argv)
    n = 12 if a.snabb else a.n
    bara = set(filter(None, a.bara.split(",")))
    vill = lambda x: not bara or x in bara  # noqa: E731
    bas = Uppstallning()
    print(f"Felbudget, {n} försök per rad, frö {a.seed}. Tal i grader (RMSE om inget annat står).")

    if vill("definitioner"):
        d = definitioner()
        print("\n### Definitionerna i modellen (grundsvingen, utan brus)\n")
        print("| | Euler (ZXY) | Bröstkorgens sidoaxel, projicerad | Axellinjen (akromion), projicerad |\n|---|---|---|---|")
        print(f"| Bröst, topp | {d['topp']['brost_euler']:.1f} | {d['topp']['thorax_linje']:.1f} | {d['topp']['axel_linje']:.1f} |")
        print(f"| Bröst, träff | {d['traff']['brost_euler']:.1f} | {d['traff']['thorax_linje']:.1f} | {d['traff']['axel_linje']:.1f} |")
        print(f"| Bäcken, topp | {d['topp']['backen_euler']:.1f} | {d['topp']['backen_linje']:.1f} (höftlinjen) | |")
        print(f"| Bäcken, träff | {d['traff']['backen_euler']:.1f} | {d['traff']['backen_linje']:.1f} (höftlinjen) | |")
        print(f"| X-factor, topp | {d['topp']['x_euler']:.1f} | {d['topp']['x_thorax']:.1f} | {d['topp']['x_axel']:.1f} |")
        print(f"\nStretch (axellinjen): {d['stretch_axel']:.1f}°")

    if vill("bas"):
        print("\n### Grunduppställningen: bias / SD\n")
        res = monte_carlo(bas, n, a.seed, metoder=("3d", "tva_2d", "fo_en"))
        print(_huvud("Metod"))
        for m, namn in (("3d", "Två kameror, triangulerat"), ("tva_2d", "Två vyer, bildmått utan kalibrering"),
                        ("fo_en", "En kamera FO (förkortning)")):
            print(_rad(namn, res, m, vis=("bias",)))
        print("\n| Metod | " + " | ".join(NAMN[k] for k in matt.MATT) + " |\n|" + "---|" * 6)
        for m, namn in (("3d", "Två kameror: RMSE / P95 / inom 5°"), ("tva_2d", "Två vyer 2D: RMSE / P95 / inom 5°"),
                        ("fo_en", "En kamera: RMSE / P95 / inom 5°")):
            print(f"| {namn} | " + " | ".join(
                f"{res[m][k]['rmse']:.1f} / {res[m][k]['p95']:.1f} / {100 * res[m][k]['inom5']:.0f} %"
                for k in matt.MATT) + " |")
        e = res["extra"]
        print(f"\nSynkens rest efter finjusteringen: RMS {e['synk_rest_ms']['rmse']:.1f} ms. "
              f"Toppens tid: RMS {e['t_topp_fel_ms']['rmse']:.1f} ms.")

    if vill("bidrag"):
        ren = replace(bas, brus="inget", synkfel_ms=0.0, synk="perfekt", kalib="perfekt", tapp=0.0,
                      skymning=False, exponering=0.0)
        rader = [
            ("Inget fel (bara utjämningen)", ren),
            ("Bara tappade rutor (36 %)", replace(ren, tapp=0.36)),
            ("Bara 2D-brus, bra", replace(ren, brus="bra")),
            ("Bara 2D-brus, typiskt", replace(ren, brus="typiskt")),
            ("Bara 2D-brus, dåligt", replace(ren, brus="daligt")),
            ("Bara 2D-brus, mycket dåligt", replace(ren, brus="mycket_daligt")),
            ("Bara skymning (typiskt brus)", replace(ren, brus="typiskt", skymning=True)),
            ("Bara synkfel ±7 ms, ingen finjustering", replace(ren, synkfel_ms=7.0, synk="ingen")),
            ("Bara synkfel ±15 ms, ingen finjustering", replace(ren, synkfel_ms=15.0, synk="ingen")),
            ("Bara synkfel ±30 ms, ingen finjustering", replace(ren, synkfel_ms=30.0, synk="ingen")),
            ("Bara kalibrering mot mattan (10 p, 1,5 m)", replace(ren, kalib="matta")),
            ("Bara inre parametrar ur specifikationen (f ±5 %, c ±20 px)",
             replace(ren, kalib="matta", f_rel=0.05, c_px=20.0)),
            ("Hela kedjan (grunduppställningen)", bas),
        ]
        svep("Bidragen ett i taget: RMSE", "Felkälla", rader, n, a.seed)

    if vill("brusdelar"):
        ren = replace(bas, synkfel_ms=0.0, synk="perfekt", kalib="perfekt", skymning=False)
        delar = {"Vitt 5 px": km.Brus(5, 0, 0, 0), "Vandring 5 px (τ 0,15 s)": km.Brus(0, 5, 0, 0),
                 "Fast 5 px per led och vy": km.Brus(0, 0, 5, 0), "Utliggare 3 % × 50 px": km.Brus(0, 0, 0, 0.03),
                 "Typiskt utan fast avvikelse": km.Brus(5, 5, 0, 0.03), "Typiskt, alla delar": km.BRUS["typiskt"]}
        rader = []
        for namn, b in delar.items():
            km.BRUS["_" + namn] = b
            rader.append((namn, replace(ren, brus="_" + namn)))
        svep("Brusets delar, en i taget (tappade rutor, ingen skymning): RMSE", "Brusdel", rader, n, a.seed)

    if vill("brus"):
        rader = [(f"2D-brus {b}", replace(bas, brus=b)) for b in ("bra", "typiskt", "daligt", "mycket_daligt")]
        svep("Hela kedjan per brusnivå: RMSE", "Brus", rader, n, a.seed)

    if vill("synk"):
        rader = []
        for ms in (7.0, 15.0, 30.0):
            for metod in ("ingen", "fart", "reprojektion"):
                rader.append((f"±{ms:.0f} ms, {metod}", replace(bas, synkfel_ms=ms, synk=metod)))
        svep("Synken: RMSE och synkens rest", "Synkfel, finjustering", rader, n, a.seed, extra=True)

    if vill("vinkel"):
        rader = [(f"{v:.0f}°", replace(bas, vinkel=v)) for v in (30, 60, 90, 120, 150)]
        svep("Vinkeln mellan kamerorna (FO fast, den andra flyttas mot spelarens rygg): RMSE",
             "Vinkel", rader, n, a.seed)

    if vill("avstand"):
        rader = []
        for d in (2.0, 3.0, 4.0, 5.0):
            rader.append((f"{d:.0f} m, felet följer kroppen", replace(bas, avstand=d)))
        for d in (2.0, 3.0, 4.0, 5.0):
            rader.append((f"{d:.0f} m, felet fast i px", replace(bas, avstand=d, skala="px")))
        svep("Avståndet: RMSE", "Avstånd", rader, n, a.seed)

    if vill("hojd"):
        rader = [(f"{h:.1f} m", replace(bas, hojd=h)) for h in (0.5, 1.0, 1.5, 2.0)]
        svep("Kamerornas höjd: RMSE", "Höjd", rader, n, a.seed)

    if vill("matta"):
        ren_k = replace(bas, brus="inget", synkfel_ms=0.0, synk="perfekt", tapp=0.0, skymning=False, exponering=0.0)
        rader = []
        for nn, sida in ((4, 1.5), (6, 1.5), (10, 1.5), (16, 1.5), (10, 0.5), (10, 1.0), (10, 3.0)):
            rader.append((f"{nn} punkter, {sida:.1f} m", replace(ren_k, matt_n=nn, matt_sida=sida)))
        rader.append(("10 punkter, 1,5 m + 4 på pinnar", replace(ren_k, matt_hojd=True)))
        rader.append(("10 punkter, klick 5 px", replace(ren_k, matt_klick_px=5.0)))
        rader.append(("10 punkter, lägen ±2 cm", replace(ren_k, matt_varld_m=0.02)))
        rader.append(("10 punkter, klick 0,5 px (ArUco)", replace(ren_k, matt_klick_px=0.5)))
        svep("Mattan (bara kalibreringsfel, inget 2D-brus): RMSE", "Mattpunkter", rader, n, a.seed)

    if vill("sjalv"):
        rader = [
            ("Mattan, 10 punkter", bas),
            ("Självkalibrering, lodlinje ±0,5°", replace(bas, kalib="sjalv", grav_deg=0.5)),
            ("Självkalibrering, lodlinje ±1°", replace(bas, kalib="sjalv", grav_deg=1.0)),
            ("Självkalibrering, lodlinje ±3°", replace(bas, kalib="sjalv", grav_deg=3.0)),
            ("Självkalibrering, dåligt brus", replace(bas, kalib="sjalv", brus="daligt")),
        ]
        svep("Mattan eller självkalibrering: RMSE", "Kalibrering", rader, n, a.seed)

    if vill("exponering"):
        rader = [(f"1/{int(round(1 / e))} s", replace(bas, exponering=e)) for e in (1 / 250, 1 / 500, 1 / 1000, 1 / 2000)]
        svep("Exponeringstiden (oskärpa): RMSE", "Slutartid", rader, n, a.seed)

    if vill("utjamning"):
        rader = [(f"±{h * 1000:.0f} ms", replace(bas, halvbredd=h)) for h in (0.01, 0.02, 0.04, 0.06)]
        svep("Utjämningens halvbredd: RMSE", "Halvbredd", rader, n, a.seed)

    if vill("hoftbredd"):
        rader = [(f"{a:.2f} × längden ({a * 1.8 * 100:.0f} cm)", replace(bas, hoft_bredd=a)) for a in (0.09, 0.11, 0.14, 0.17)]
        svep("Avståndet mellan höftpunkterna: RMSE", "Höftlinjen", rader, n, a.seed)

    if vill("markor"):
        rader = [
            ("Posemodellens punkter (grund)", bas),
            ("Pinne 60 cm i bältet + stav 50 cm över ryggen, ändarna syns", replace(bas, hoftpinne=0.6, ryggstav=0.5, pinne_skymd=False)),
            ("Bara pinnen i bältet, ändarna syns", replace(bas, hoftpinne=0.6, pinne_skymd=False)),
            ("Bara pinnen i bältet, med skymning", replace(bas, hoftpinne=0.6)),
        ]
        svep("Färgade markörer i stället för posemodellens höft- och axelpunkter: RMSE", "Punkter", rader, n, a.seed)

    if vill("pass"):
        print("\n### Passets median (10 slag, samma kalibrering och fasta avvikelse): bias / SD\n")
        print(_huvud("Uppställning"))
        for namn, u in (("Grund (typiskt brus)", bas), ("Bra brus", replace(bas, brus="bra")),
                        ("Dåligt brus", replace(bas, brus="daligt"))):
            r = pass_monte_carlo(u, max(n // 3, 4), 10, seed=a.seed)
            print(_rad(namn, r, "3d", vis=("bias",)))

    if vill("facit"):
        print("\n### Facit i adress: bias / SD (grader)\n")
        print("| Vinkel | Axellinjen mot golvlinjen (människa ±3°) | Axellinjen mot pinnen | Pinnen mot bröstkorgen | "
              "Mätfelet mot sann axellinje | Inom 5° mot golvlinjen |\n|---|---|---|---|---|---|")
        fm = facit_monte_carlo(bas, max(n // 2, 6), seed=a.seed)
        for vin, d in fm.items():
            print(f"| {vin:.0f}° | " + " | ".join(
                f"{d[k]['bias']:+.1f} / {d[k]['sd']:.1f}" for k in
                ("axel_mot_golvlinje", "axel_mot_pinne", "pinne_mot_thorax", "axel_matfel"))
                  + f" | {100 * d['axel_mot_golvlinje']['inom5']:.0f} % |")
    return 0


if __name__ == "__main__":
    sys.exit(main())
