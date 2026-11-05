"""Andra åsikten: ViTPose-B tränad bara på COCO mot telefonens Vision på samma klipp
(PLAN S3b lager 4, METOD MF9, BESLUT B92, B98, B100).

    python tools/pc/andra_asikt.py <paket.zip> [fler paket] [--ut <mapp>] [--langd 1.80] [--om]

För varje mätt slag med klipp i paketet körs ViTPose på varje ruta i klippet, i en
personruta tagen ur Visions leder i samma ruta (ingen egen detektor, BESLUT B100). Klippets
tider paras med Visions som i S3 (`s3_facit.para_tider`, METOD MF1). Sedan, per vy:

- **avståndet** mellan Vision och ViTPose per led och fas, i bålens längd i bild (METOD M53);
- **rycket** i handlederna och armbågarna för var och en: andra differensen mellan rutorna,
  i bål, räknad om till rutnätets steg;
- **rensningen** (METOD M53) på båda ledsatserna: byten och spikar per led.

Allt skrivs till en mapp **utanför repot**, som standard `~/swinglab-analys/<pass>/andra-asikt/`
(CLAUDE.md, Dataregeln): `andra-asikt.json`, `andra-asikt.md` och ViTPose-lederna per slag i
`vitpose/` (återanvänds nästa körning när modellen och klippet är desamma; `--om` kör om).

PyTorch och transformers importeras först när ViTPose behövs; modellen hämtas från Hugging
Face till dess cache.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from datetime import datetime
from pathlib import Path
from typing import Protocol

import numpy as np

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "pc"

from . import paket as P  # noqa: E402
from . import rensa as RE  # noqa: E402
from . import s3_facit as S3F  # noqa: E402
from . import session as S  # noqa: E402
from .format import ANTAL_LEDER, FRAN_FIL, LEDER, MIN_KONFIDENS  # noqa: E402
from .format import ARMBAGE_B, ARMBAGE_F, HANDLED_B, HANDLED_F  # noqa: E402

FORMAT = "swinglab-andra-asikt/1"
UT_ROT = Path.home() / "swinglab-analys"
CACHE_VERSION = 1

# BESLUT B100: ViTPose-B med den klassiska avkodaren, tränad bara på COCO train2017 (originalets
# vitpose-b.pth), MAE-förtränad på ImageNet (BESLUT B98). Apache-2.0.
MODELL = "usyd-community/vitpose-base"
PIP = "pip install torch transformers  (PyTorch med CUDA: se pytorch.org)"

# COCO:s 17 punkter → filens 13 leder (docs/FORMAT.md): näsan, axlarna, armbågarna,
# handlederna, höfterna, knäna och fotlederna, vänster före höger som i filen.
COCO_INDEX = (0, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)

RUTA_MIN_LEDER = 6       # METOD MF9: färre av Visions leder i rutan ger ingen personruta
RUTA_MARGINAL = 0.15     # METOD MF9: rutan växer så mycket av sin största sida åt varje håll
RUTA_HUVUD = 0.12        # METOD MF9: och så mycket av kroppens höjd till uppåt (näsan är Visions översta punkt)
RUTA_MAX_S = 0.05        # METOD MF9: Visions ruta för personrutan högst så långt från klipprutan
GROV_BAL = RE.SPIK_MIN_BAL   # METOD MF9: en grov skillnad är minst en spiks längd (0,25 bål)
STEG_TOL = 0.5           # METOD MF9: rycket bara där båda stegen ligger inom ±50 % av rutnätets steg
BATCH = 32
RYCK_LEDER = (HANDLED_F, HANDLED_B, ARMBAGE_F, ARMBAGE_B)
FASER = ("alla",) + S3F.FASER_S3


class Modell(Protocol):
    """Posemodellen bakom ett gränssnitt, så att testerna kör utan PyTorch."""

    namn: str

    def kor(self, bilder: list[np.ndarray], rutor: list[tuple[float, float, float, float]]) -> list[np.ndarray]:
        """Bilderna (h, b, 3) RGB uint8 och en personruta (x, y, bredd, höjd) i bildens px
        per bild. Svarar (17, 3) per bild: COCO:s punkter i bildens px och konfidensen."""
        ...


class ViTPoseModell:
    """ViTPose ur transformers på GPU:n när den finns. METOD MF9"""

    def __init__(self, namn: str = MODELL):
        import torch
        from transformers import AutoProcessor, VitPoseForPoseEstimation
        self.torch, self.namn = torch, namn
        self.enhet = "cuda" if torch.cuda.is_available() else "cpu"
        self.proc = AutoProcessor.from_pretrained(namn)
        self.modell = VitPoseForPoseEstimation.from_pretrained(namn).to(self.enhet).eval()

    def kor(self, bilder, rutor):
        boxar = [[list(map(float, r))] for r in rutor]
        x = self.proc(bilder, boxes=boxar, return_tensors="pt").to(self.enhet)
        with self.torch.no_grad():
            ut = self.modell(**x)
        res = self.proc.post_process_pose_estimation(ut, boxes=boxar)
        return [np.column_stack([r[0]["keypoints"].float().cpu().numpy(), r[0]["scores"].float().cpu().numpy()])
                for r in res]


def saknade_beroenden() -> list[str]:
    saknas = []
    for modul, namn in (("cv2", "opencv-python"), ("torch", "torch"), ("transformers", "transformers")):
        try:
            __import__(modul)
        except ImportError:
            saknas.append(namn)
    return saknas


# --- personrutan och punkterna -------------------------------------------------------

def personruta(L: np.ndarray, bredd: float, hojd: float) -> tuple[float, float, float, float] | None:
    """Personrutan (x, y, bredd, höjd) ur Visions leder i en ruta (13, ≥2), NaN = saknad,
    i samma px som lederna: lederna som syns, RUTA_MARGINAL av rutans största sida åt varje
    håll och RUTA_HUVUD av höjden till uppåt, inom bilden. None med färre än RUTA_MIN_LEDER
    leder. METOD MF9"""
    ok = np.isfinite(L[:, :2]).all(axis=1)
    if ok.sum() < RUTA_MIN_LEDER:
        return None
    x0, y0 = L[ok, :2].min(axis=0)
    x1, y1 = L[ok, :2].max(axis=0)
    m = RUTA_MARGINAL * max(x1 - x0, y1 - y0)
    x0, x1 = max(0.0, x0 - m), min(float(bredd), x1 + m)
    y0, y1 = max(0.0, y0 - m - RUTA_HUVUD * (y1 - y0)), min(float(hojd), y1 + m)
    if x1 <= x0 or y1 <= y0:
        return None
    return float(x0), float(y0), float(x1 - x0), float(y1 - y0)


def till_leder(punkter: np.ndarray, sk: float) -> list:
    """COCO:s 17 punkter i klippets px → filens 13 leder i ledernas px (÷ sk), `[x, y, c]`,
    eller None under MIN_KONFIDENS (METOD M1). METOD MF9"""
    ut = []
    for k in COCO_INDEX:
        x, y, c = (float(v) for v in punkter[k])
        ut.append([round(x / sk, 1), round(y / sk, 1), round(c, 3)]
                  if math.isfinite(x) and math.isfinite(y) and c >= MIN_KONFIDENS else None)
    return ut


def kor_vitpose(paket_fil: Path, p: P.Paket, s: P.Slag, modell: Modell, rutkalla, e: np.ndarray, V: np.ndarray,
                d0: float, batch: int = BATCH) -> dict:
    """ViTPose på varje ruta i klippet med personrutan ur Visions ruta närmast klipprutans tid
    − d0 (S3:s förskjutning när den finns, annars 0), inom RUTA_MAX_S. Rutor utan personruta
    får inga leder. METOD MF9"""
    bredd, hojd = s.lederna["width"], s.lederna["height"]
    frames: list[dict] = []
    vantar: list[tuple[int, np.ndarray, tuple, float]] = []

    def tom():
        for (k, bild, ruta, sk), L in zip(vantar, modell.kor([b for _, b, _, _ in vantar], [r for _, _, r, _ in vantar])):
            frames[k]["joints"] = till_leder(L, sk)
        vantar.clear()

    for tk, bild in rutkalla.rutor(paket_fil, p, s):
        frames.append({"tk": round(float(tk), 6), "joints": [None] * ANTAL_LEDER})
        if len(e) == 0:
            continue
        i = int(np.argmin(np.abs(e - (tk - d0))))
        if abs(e[i] - (tk - d0)) > RUTA_MAX_S:
            continue
        sk = bild.shape[1] / bredd
        ruta = personruta(V[i], bredd, hojd)
        if ruta is None:
            continue
        vantar.append((len(frames) - 1, bild, tuple(v * sk for v in ruta), sk))
        if len(vantar) >= batch:
            tom()
    if vantar:
        tom()
    crc, storlek = S3F._klipp_info(paket_fil, s)
    return {"version": CACHE_VERSION, "modell": modell.namn, "width": bredd, "height": hojd, "klipp_crc": crc,
            "klipp_storlek": storlek, "frames": frames}


def _cache_giltig(d: dict, bredd: int, hojd: int, modell_namn: str, klipp: tuple[int, int]) -> bool:
    return (isinstance(d, dict) and d.get("version") == CACHE_VERSION and d.get("modell") == modell_namn
            and d.get("width") == bredd and d.get("height") == hojd
            and (d.get("klipp_crc"), d.get("klipp_storlek")) == klipp and isinstance(d.get("frames"), list))


# --- jämförelsen ---------------------------------------------------------------------

def ryck(t: np.ndarray, X: np.ndarray, bal: float) -> np.ndarray:
    """Rycket per ruta för en led (n, 2): andra differensen, med ojämna steg räknad som
    farten som ändras, gånger rutnätets steg h i kvadrat, i bål: |2(v₂ − v₁)/(Δt₁ + Δt₂)|·h²/bål.
    NaN där en punkt saknas eller ett steg ligger utanför h ± STEG_TOL·h. Brus ger ryck;
    en jämn rörelse nästan inget. METOD MF9"""
    ut = np.full(len(t), np.nan)
    if len(t) < 3 or not bal > 0:
        return ut
    dt = np.diff(t)
    h = float(np.median(dt))
    for k in range(1, len(t) - 1):
        d1, d2 = dt[k - 1], dt[k]
        if not (abs(d1 - h) <= STEG_TOL * h and abs(d2 - h) <= STEG_TOL * h):
            continue
        a, b, c = X[k - 1], X[k], X[k + 1]
        if not (np.isfinite(a).all() and np.isfinite(b).all() and np.isfinite(c).all()):
            continue
        acc = 2.0 * ((c - b) / d2 - (b - a) / d1) / (d1 + d2)
        ut[k] = float(np.hypot(*acc)) * h * h / bal
    return ut


def jamfor_slag(t: np.ndarray, V: np.ndarray, M: np.ndarray, faser: dict | None) -> dict:
    """Ett slags parade rutor, lederna i spelarens ordning (främre, bakre; format.LEDER), px.
    Svarar bålen, rutornas fas, avståndet per ruta och led i bål (n, 13), rycket för båda och
    rensningen för båda. METOD MF9"""
    bal = RE.bal_px(V[..., :2])
    fas = np.array([S3F._fas(float(x), faser) or "okand" for x in t], dtype=object)
    with np.errstate(invalid="ignore"):
        d = np.hypot(V[..., 0] - M[..., 0], V[..., 1] - M[..., 1]) / bal
    ryck_v = {j: ryck(t, V[:, j, :2], bal) for j in RYCK_LEDER}
    ryck_m = {j: ryck(t, M[:, j, :2], bal) for j in RYCK_LEDER}
    _, rv = RE.rensa(t, V[..., :2].copy())
    _, rm = RE.rensa(t, M[..., :2].copy())
    return {"bal_px": bal, "fas": fas, "d": d, "ryck_vision": ryck_v, "ryck_vitpose": ryck_m,
            "rensning_vision": rv, "rensning_vitpose": rm, "rutor": len(t)}


def _kvant(x: np.ndarray, p: float) -> float:
    return S.percentil(sorted(float(v) for v in x), p)


def sammanstall(slag: list[tuple[str, dict]]) -> dict:
    """Slagen per vy → tabellerna: avståndet per led och fas (median, 90:e percentilen och
    andelen grova), rycket per led och fas för båda och kvoten, och rensningen summerad.
    METOD MF9"""
    ut = {"leder": [], "ryck": [], "rensning": {}}
    for vy in sorted({v for v, _ in slag}):
        js = [j for v, j in slag if v == vy]
        fas = np.concatenate([j["fas"] for j in js])
        d = np.concatenate([j["d"] for j in js])
        for f in FASER:
            m = np.ones(len(fas), bool) if f == "alla" else fas == f
            for led in range(ANTAL_LEDER):
                x = d[m, led]
                x = x[np.isfinite(x)]
                if len(x) < 2:
                    continue
                ut["leder"].append({"vy": vy, "fas": f, "led": LEDER[led], "n": int(len(x)),
                                    "median": round(_kvant(x, 0.5), 4), "p90": round(_kvant(x, 0.9), 4),
                                    "grova": round(float(np.mean(x >= GROV_BAL)), 4)})
            for led in RYCK_LEDER:
                rv = np.concatenate([j["ryck_vision"][led] for j in js])[m]
                rm = np.concatenate([j["ryck_vitpose"][led] for j in js])[m]
                ok = np.isfinite(rv) & np.isfinite(rm)
                if ok.sum() < 2:
                    continue
                mv, mm = _kvant(rv[ok], 0.5), _kvant(rm[ok], 0.5)
                ut["ryck"].append({"vy": vy, "fas": f, "led": LEDER[led], "n": int(ok.sum()),
                                   "vision": round(mv, 5), "vitpose": round(mm, 5),
                                   "kvot": round(mm / mv, 3) if mv > 0 else None})
        rens = {}
        for kalla in ("vision", "vitpose"):
            summa = {"byten": {}, "byten_oklara": {}, "spikar": {}}
            for j in js:
                for typ, per in j[f"rensning_{kalla}"].items():
                    for k, v in per.items():
                        summa[typ][k] = summa[typ].get(k, 0) + v
            rens[kalla] = {typ: dict(sorted(v.items())) for typ, v in summa.items()}
        ut["rensning"][vy] = {"rutor": sum(j["rutor"] for j in js), "slag": len(js), **rens}
    return ut


def _i_spelarens_ordning(X: np.ndarray, hand: str) -> np.ndarray:
    """Filens ordning (vänster, höger) → spelarens (främre, bakre), som format.py."""
    return X[:, list(FRAN_FIL[hand])]


def kor(paket_filer: list[Path], ut: Path, langd: float | None, modell: Modell | None, rutkalla,
        om: bool = False, s3: Path | None = None, modell_namn: str | None = None, rapport=None) -> dict:
    """Paketen → andra-asikt.json och andra-asikt.md i `ut`. `modell` och `rutkalla` får vara
    None när alla slag har giltiga sparade ViTPose-leder (ange då `modell_namn`). METOD MF9"""
    modell_namn = modell_namn or (modell.namn if modell is not None else MODELL)
    ut.mkdir(parents=True, exist_ok=True)
    cache = ut / "vitpose"
    cache.mkdir(exist_ok=True)
    slag_ut, jamforda = [], []
    pass_ids = set()
    for fil in map(Path, paket_filer):
        p = P.las(fil)
        pass_ids.add(p.pass_id)
        lg = langd or p.langd_m or 1.80     # längden påverkar bara Visions mått, inte jämförelsen
        fsk = S3F.las_forskjutningar(p.pass_id, s3)
        for s in [x for x in p.slag if x.dom in P.MATS and not x.detection_wrong]:
            rad = {"fil": p.fil, "id": s.id, "vy": p.vy}
            slag_ut.append(rad)
            if not s.klipp:
                rad["hoppat"] = "inget klipp i paketet"
                continue
            vr, vfel = S3F._mat_vision(fil, p, s, lg)
            if vr is None:
                rad["hoppat"] = f"Vision mättes inte: {vfel}"
                continue
            tv, V = S3F._leder(s.lederna)
            e = tv + float(s.klick_i_klipp_s)
            bredd, hojd = s.lederna["width"], s.lederna["height"]
            cfil = cache / f"{Path(p.fil).stem}-{s.id}.json"
            raa = None
            if cfil.is_file() and not om:
                try:
                    d = json.loads(cfil.read_text(encoding="utf-8"))
                    raa = d if _cache_giltig(d, bredd, hojd, modell_namn, S3F._klipp_info(fil, s)) else None
                except (OSError, json.JSONDecodeError):
                    raa = None
            if raa is None:
                if modell is None or rutkalla is None:
                    raise S3F.S3Fel("ViTPose behövs men är inte laddad")
                if rapport:
                    rapport(f"  {p.fil} {s.id}: ViTPose …", flush=True)
                d0 = fsk.get((p.fil, s.id), 0.0) / 1000.0
                raa = kor_vitpose(fil, p, s, modell, rutkalla, e, V, d0)
                cfil.write_text(json.dumps(raa, separators=(",", ":")), encoding="utf-8")
            tm, Mv = S3F._leder(raa, "tk")
            fz = vr["faser"]
            rorelse = (tv >= fz["topp"] - S3F.RORELSE_S[0]) & (tv <= fz["traff"] + S3F.RORELSE_S[1])
            pt = S3F.para_tider(e, V, tm, Mv, rorelse)
            rad["tidsparning"] = {k: pt[k] for k in ("forskjutning_ms", "rutor", "kvot", "rest_ms_median")}
            if pt["tvetydig"]:
                rad["hoppat"] = f"tidsparningen är tvetydig: {pt['tvetydig']}"
                continue
            par = [(i, j) for i, j in pt["par"] if P.i_klippet(s, float(e[i]))]
            if len(par) < 3:
                rad["hoppat"] = "för få parade rutor"
                continue
            iv, jm = [i for i, _ in par], [j for _, j in par]
            rad["rutor_parade"] = len(par)
            jamforda.append((p.vy, jamfor_slag(tv[iv], _i_spelarens_ordning(V[iv], p.spelhand),
                                               _i_spelarens_ordning(Mv[jm], p.spelhand), fz)))
    res = {"format": FORMAT, "pass": sorted(pass_ids), "skapad": datetime.now().astimezone().isoformat(timespec="seconds"),
           "modell": {"namn": modell_namn, "traning": "COCO train2017", "fortraning": "MAE, ImageNet-1k",
                      "personrutan": "Visions leder (METOD MF9)"},
           "slag": slag_ut, **sammanstall(jamforda)}
    (ut / "andra-asikt.json").write_text(json.dumps(res, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    (ut / "andra-asikt.md").write_text(markdown(res), encoding="utf-8")
    return res


def markdown(r: dict) -> str:
    """Rapporten: avståndet per led och fas, rycket och rensningen, per vy."""
    rader = [f"# Andra åsikten: ViTPose mot Vision ({', '.join(r['pass'])})", "",
             f"Modellen: `{r['modell']['namn']}`, tränad på {r['modell']['traning']}, förträning "
             f"{r['modell']['fortraning']}. Personrutan ur {r['modell']['personrutan']}.", ""]
    for vy in sorted({x["vy"] for x in r["leder"]}):
        rader += [f"## {vy.upper()}", "", "### Avståndet Vision–ViTPose, bål (median / 90:e percentilen)", "",
                  "| led | " + " | ".join(FASER) + " |", "|---" * (len(FASER) + 1) + "|"]
        for led in LEDER:
            cell = []
            for f in FASER:
                x = next((y for y in r["leder"] if y["vy"] == vy and y["fas"] == f and y["led"] == led), None)
                cell.append("–" if x is None else f"{x['median']:.3f} / {x['p90']:.3f}")
            rader.append(f"| {led} | " + " | ".join(cell) + " |")
        rader += ["", "### Rycket, bål per steg² (median: Vision / ViTPose, kvoten)", "",
                  "| led | " + " | ".join(FASER) + " |", "|---" * (len(FASER) + 1) + "|"]
        for led in (LEDER[j] for j in RYCK_LEDER):
            cell = []
            for f in FASER:
                x = next((y for y in r["ryck"] if y["vy"] == vy and y["fas"] == f and y["led"] == led), None)
                cell.append("–" if x is None else f"{x['vision']:.4f} / {x['vitpose']:.4f} ({x['kvot']})")
            rader.append(f"| {led} | " + " | ".join(cell) + " |")
        rs = r["rensning"][vy]
        rader += ["", f"### Rensningen (METOD M53), {rs['slag']} slag, {rs['rutor']} parade rutor", ""]
        for kalla in ("vision", "vitpose"):
            rader.append(f"- **{kalla}:** " + "; ".join(f"{typ} {rs[kalla][typ] or '–'}" for typ in
                                                         ("byten", "byten_oklara", "spikar")))
        rader.append("")
    hoppade = [s for s in r["slag"] if "hoppat" in s]
    if hoppade:
        rader += ["## Hoppade slag", ""] + [f"- {s['fil']} {s['id']}: {s['hoppat']}" for s in hoppade] + [""]
    return "\n".join(rader)


def standard_ut(paket_filer: list[str]) -> Path:
    return UT_ROT / P.las(paket_filer[0], med_leder=False).pass_id / "andra-asikt"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="ViTPose (bara COCO) mot Vision på samma klipp (METOD MF9).")
    ap.add_argument("paket", nargs="+", help="swinglab-<pass>-<vy>.zip")
    ap.add_argument("--ut", help="mappen för resultatet (utanför repot; standard ~/swinglab-analys/<pass>/andra-asikt)")
    ap.add_argument("--langd", type=float, help="spelarens längd i m (annars ur paketet)")
    ap.add_argument("--s3", help="s3.json med klippens förskjutning (annars ~/swinglab-s3/<pass>/s3.json)")
    ap.add_argument("--modell", default=MODELL, help=f"modellen på Hugging Face (standard {MODELL})")
    ap.add_argument("--om", action="store_true", help="kör ViTPose igen även när sparade leder finns")
    a = ap.parse_args(argv)
    try:
        ut = Path(a.ut) if a.ut else standard_ut(a.paket)
    except P.PaketFel as e:
        print("Paketet går inte att läsa:\n  " + "\n  ".join(e.fel))
        return 1
    if not S.utanfor_repot(ut):
        print("--ut: mappen ligger i repot men inte i data/; passets data får inte hamna i git.")
        return 1
    saknas = saknade_beroenden()
    if saknas:
        print(f"Saknas: {', '.join(saknas)}. Installera med:\n  {PIP}")
        return 1
    try:
        res = kor([Path(f) for f in a.paket], ut, a.langd, ViTPoseModell(a.modell), S3F.KlippRutor(), om=a.om,
                  s3=Path(a.s3) if a.s3 else None, modell_namn=a.modell, rapport=print)
    except (S3F.S3Fel, P.PaketFel) as e:
        print(getattr(e, "fel", None) and "Paketet går inte att läsa:\n  " + "\n  ".join(e.fel) or str(e))
        return 1
    jamf = sum(1 for s in res["slag"] if "hoppat" not in s)
    print(f"Jämförde {jamf} slag av {len(res['slag'])}. Skrev {ut / 'andra-asikt.md'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
