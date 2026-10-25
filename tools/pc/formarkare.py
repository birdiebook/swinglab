"""S7-1 steg 1: förmärkaren för klubban (PLAN S7, BESLUT B92, METOD MF7).

En detektor för klubba och klubbhuvud, tränad på öppna CC BY 4.0-dataset från Roboflow,
föreslår rutor i Johannes svingar så att han rättar i stället för att märka från noll.
Förslaget är aldrig facit: bara det Johannes klickat räknas som märkning (B71, B92).

    python tools/pc/formarkare.py bygg <coco-mapp> [fler] --ut ~/swinglab-s7/trana
    python tools/pc/formarkare.py trana ~/swinglab-s7/trana --ut ~/swinglab-s7/vikter
    python tools/pc/formarkare.py prov ~/swinglab-s7/trana --vikter <vikter.pth>
    python tools/pc/formarkare.py forslag <paket.zip> [fler] --vikter <vikter.pth> --ut ~/swinglab-s7/forslag

`bygg` läser bara mappar i COCO-format (Roboflows export) och lägger varje bild i träning,
val eller prov **per scen**: bilder vars miniatyrer nästan är lika (samma video, samma
uppställning) hamnar i samma del, så att provet inte mäter grannrutor ur träningen. Johannes
paket är inte COCO och kan inte komma in i träningen den vägen; passet från 2026-10-24 är
provpasset (B92) och körs bara med `forslag`.

Modellen är RF-DETR Nano (Apache 2.0, `pip install "rfdetr[train]"`), aldrig Ultralytics
(AGPL, B92). Den körs i WSL2 på 2080 Ti:n. Allt som skrivs (bilder, vikter, förslag) ska
ligga utanför repot och utanför /mnt (CLAUDE.md, Dataregeln); verktyget vägrar annars.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
import tempfile
import time
import zipfile
from datetime import datetime
from pathlib import Path

import numpy as np

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "pc"

from .session import REPO  # noqa: E402

KLASSER = ("klubba", "klubbhuvud")            # METOD MF7: kategori 1 och 2 i COCO-filen
# Datasetens klassnamn → våra. golf-49wbh: club, club_head; golf-club-tracking: 0 (skaftet),
# 1 (huvudet) och 3 (händerna, tas inte med: golf-49wbh saknar dem). METOD MF7
NAMN = {"club": "klubba", "club_head": "klubbhuvud", "0": "klubba", "1": "klubbhuvud"}
MINIATYR = 16              # METOD MF7: px i scenens miniatyr (16 × 16, gråskala)
LIKA = 0.95                # METOD MF7: korrelationen över vilken två bilder är samma scen
PROV_ANDEL = 0.10          # METOD MF7: andel av varje källas bilder som hålls ut för provet
VAL_ANDEL = 0.10           # METOD MF7: andel för valet av vikter under träningen
DELAR = ("train", "valid", "test")            # Roboflows mappnamn; test = provet
TROSKEL = 0.30             # METOD MF7: förslag med lägre konfidens ritas inte
UTSNITT_SKALA = 2.0        # METOD MF7: utsnittets sida = 2,0 × kroppens höjd i bild
RUTA_PX = 320              # px per ruta i förslagens kontaktark
# Rutorna i kontaktarket, som andel av fasen mellan två tider (faser.py, METOD M4).
FASER_ARK = (("adress", None), ("baksving 1/3", ("start", "topp", 1 / 3)),
             ("baksving 2/3", ("start", "topp", 2 / 3)), ("topp", ("topp", "topp", 0.0)),
             ("nedsving 1/4", ("topp", "traff", 0.25)), ("nedsving 1/2", ("topp", "traff", 0.5)),
             ("nedsving 3/4", ("topp", "traff", 0.75)), ("nedsving 9/10", ("topp", "traff", 0.9)),
             ("traff", ("traff", "traff", 0.0)), ("efter", ("traff", "traff", 0.0, 0.15)),
             ("finish", None))
# METOD MF7: faserna (s relativt klicket) för ett slag som inte fick några uppmätta, så att
# arket ändå visar svingen; märks "antagna" i förslaget.
FASER_ANTAGNA = {"start": -1.1, "topp": -0.28, "traff": 0.0}
FARG = {"klubba": (255, 220, 0), "klubbhuvud": (255, 40, 40)}   # RGB


class FormFel(ValueError):
    pass


def utanfor_repot(p: Path) -> Path:
    """Sökvägen om den får bära Johannes data eller vikter: utanför repot och utanför
    Windows-diskarna i WSL (/mnt). Kastar FormFel annars. CLAUDE.md, Dataregeln"""
    fore = Path(p).expanduser()
    p = fore.resolve()
    if p.is_relative_to(REPO) or any(q.as_posix().startswith("/mnt/") for q in (fore, p)):
        raise FormFel(f"{p}: data och vikter ska ligga utanför repot och /mnt (Dataregeln)")
    return p


# ---------------------------------------------------------------------------- scener

def miniatyr(gra: np.ndarray, n: int = MINIATYR) -> np.ndarray:
    """Bildens miniatyr som vektor med medel 0 och längd 1: medel över n × n block
    (bilden beskärs till en multipel av n). En jämn bild ger nollvektorn. METOD MF7"""
    h, w = gra.shape[:2]
    bh, bw = h // n, w // n
    if bh == 0 or bw == 0:
        raise FormFel(f"bilden är mindre än {n} × {n} px")
    m = gra[:bh * n, :bw * n].astype(np.float64).reshape(n, bh, n, bw).mean(axis=(1, 3)).ravel()
    m -= m.mean()
    norm = np.linalg.norm(m)
    return m / norm if norm > 1e-9 else m


def scener(v: np.ndarray, grans: float = LIKA, bit: int = 2048) -> np.ndarray:
    """Varje bild → scenens nummer: bilder vars miniatyrer korrelerar över `grans` binds
    ihop, och sambanden är transitiva (union-find). Numret är den lägsta bildens index i
    scenen. `v` är (n, d) med rader från `miniatyr`. METOD MF7"""
    n = len(v)
    far = np.arange(n)

    def rot(i: int) -> int:
        while far[i] != i:
            far[i] = far[far[i]]
            i = far[i]
        return i

    for a in range(0, n, bit):
        k = v[a:a + bit] @ v.T
        ii, jj = np.nonzero(k > grans)
        for i, j in zip(ii + a, jj):
            if j <= i:
                continue
            ri, rj = rot(int(i)), rot(int(j))
            if ri != rj:
                far[max(ri, rj)] = min(ri, rj)
    return np.array([rot(i) for i in range(n)])


def dela(namn: list[str], scen: np.ndarray, prov: float = PROV_ANDEL, val: float = VAL_ANDEL) -> list[str]:
    """Varje bild → "train", "valid" eller "test" (provet), en hel scen i taget. Scenerna
    tas i ordningen efter en hash av scenens första filnamn, så att samma källa delas
    likadant oavsett vilka andra källor som byggs med. En scen går till provet om den ryms
    inom `prov` av bilderna, annars till valet om den ryms inom `val`, annars till
    träningen. METOD MF7"""
    n = len(namn)
    medlemmar: dict[int, list[int]] = {}
    for i, s in enumerate(scen):
        medlemmar.setdefault(int(s), []).append(i)
    ordning = sorted(medlemmar.values(),
                     key=lambda m: hashlib.sha1(min(namn[i] for i in m).encode()).hexdigest())
    ut = [""] * n
    fyllt = {"test": 0, "valid": 0}
    tak = {"test": prov * n, "valid": val * n}
    for m in ordning:
        del_ = next((d for d in ("test", "valid") if fyllt[d] + len(m) <= tak[d]), "train")
        if del_ != "train":
            fyllt[del_] += len(m)
        for i in m:
            ut[i] = del_
    return ut


# ---------------------------------------------------------------------------- bygg

def las_coco(mapp: Path) -> list[dict]:
    """Alla bilder i en Roboflow-export (train, valid och test slås ihop, delningen görs om):
    [{"fil", "namn", "bredd", "hojd", "rutor": [{"klass", "bbox"}]}]. Klasser utanför
    NAMN tas bort; en bild utan rutor står kvar som negativ."""
    mapp = Path(mapp)
    ut = []
    for del_ in DELAR:
        fil = mapp / del_ / "_annotations.coco.json"
        if not fil.exists():
            continue
        d = json.loads(fil.read_text(encoding="utf-8"))
        kat = {c["id"]: NAMN.get(c["name"]) for c in d["categories"]}
        rutor: dict[int, list] = {}
        for a in d["annotations"]:
            if kat.get(a["category_id"]):
                rutor.setdefault(a["image_id"], []).append({"klass": kat[a["category_id"]], "bbox": a["bbox"]})
        for im in d["images"]:
            ut.append({"fil": str(mapp / del_ / im["file_name"]), "namn": f"{del_}/{im['file_name']}",
                       "bredd": im["width"], "hojd": im["height"], "rutor": rutor.get(im["id"], [])})
    if not ut:
        raise FormFel(f"{mapp}: ingen _annotations.coco.json i {', '.join(DELAR)}")
    return ut


def coco(bilder: list[dict]) -> dict:
    """COCO-filen i Roboflows form, som RF-DETR läser: kategori 0 är överklassen,
    1 och 2 är KLASSER."""
    kat = [{"id": 0, "name": "klubba-delar", "supercategory": "none"}] + [
        {"id": i + 1, "name": k, "supercategory": "klubba-delar"} for i, k in enumerate(KLASSER)]
    images, anns = [], []
    for i, b in enumerate(bilder):
        images.append({"id": i, "file_name": b["ut_namn"], "width": b["bredd"], "height": b["hojd"]})
        for r in b["rutor"]:
            x, y, w, h = r["bbox"]
            anns.append({"id": len(anns), "image_id": i, "category_id": KLASSER.index(r["klass"]) + 1,
                         "bbox": [x, y, w, h], "area": w * h, "iscrowd": 0})
    return {"info": {"description": "SwingLab S7-1, METOD MF7"}, "images": images,
            "annotations": anns, "categories": kat}


def bygg(kallor: list[Path], ut: Path) -> dict:
    """Träningsmappen: <ut>/{train,valid,test}/ med länkar till bilderna och
    _annotations.coco.json, plus delning.json med antalen per källa och del."""
    import cv2
    ut = utanfor_repot(ut)
    alla: list[dict] = []
    sammanfattning: dict[str, dict] = {}
    for k in kallor:
        k = Path(k).expanduser().resolve()
        bilder = las_coco(k)
        v = np.stack([miniatyr(cv2.imread(b["fil"], cv2.IMREAD_GRAYSCALE)) for b in bilder])
        scen = scener(v)
        delar = dela([b["namn"] for b in bilder], scen)
        for b, d in zip(bilder, delar):
            b.update(kalla=k.name, del_=d, ut_namn=f"{k.name}__{Path(b['namn']).name}")
        s = {"bilder": len(bilder), "scener": int(len(set(scen.tolist())))}
        for d in DELAR:
            i_del = [b for b in bilder if b["del_"] == d]
            s[d] = {"bilder": len(i_del),
                    **{kl: sum(1 for b in i_del for r in b["rutor"] if r["klass"] == kl) for kl in KLASSER}}
        sammanfattning[k.name] = s
        alla += bilder
    for d in DELAR:
        mapp = ut / d
        mapp.mkdir(parents=True, exist_ok=True)
        i_del = [b for b in alla if b["del_"] == d]
        for b in i_del:
            lank = mapp / b["ut_namn"]
            if not lank.exists():
                lank.symlink_to(b["fil"])
        (mapp / "_annotations.coco.json").write_text(json.dumps(coco(i_del)), encoding="utf-8")
    (ut / "bilder.json").write_text(json.dumps({b["ut_namn"]: b["kalla"] for b in alla}), encoding="utf-8")
    r = {"skapad": datetime.now().astimezone().isoformat(timespec="seconds"), "kallor": sammanfattning,
         "lika": LIKA, "miniatyr": MINIATYR}
    (ut / "delning.json").write_text(json.dumps(r, indent=1, ensure_ascii=False), encoding="utf-8")
    return r


# ---------------------------------------------------------------------------- träna och prova

def trana(mapp: Path, ut: Path, epoker: int, batch: int, ackum: int, fortsatt: bool = False) -> dict:
    """RF-DETR Nano från COCO-vikterna (Apache 2.0) på mappen från `bygg`. Valet av vikter
    görs på `valid`; provet (`test`) används inte. Med `fortsatt` tas träningen upp från
    <ut>/last.ckpt (efter ett avbrott, till exempel när WSL uppdateras). Svarar tiden."""
    from rfdetr import RFDETRNano
    ut = utanfor_repot(ut)
    sist = ut / "last.ckpt"
    fortsatt = bool(fortsatt and sist.exists())
    t0 = time.time()
    RFDETRNano().train(dataset_dir=str(Path(mapp).expanduser()), output_dir=str(ut), epochs=epoker,
                       batch_size=batch, grad_accum_steps=ackum, num_workers=2, seed=0,
                       run_test=False, tensorboard=False, progress_bar=None,
                       resume=str(sist) if fortsatt else None)
    r = {"sekunder": round(time.time() - t0), "epoker": epoker, "batch": batch, "ackum": ackum,
         "modell": "RF-DETR Nano", "fortsatt": fortsatt}
    (ut / "tid.json").write_text(json.dumps(r), encoding="utf-8")
    return r


def ladda(vikter: Path):
    from rfdetr import RFDETRNano
    return RFDETRNano(pretrain_weights=str(Path(vikter).expanduser()))


def detektioner(modell, bilder: list, troskel: float) -> list[list[dict]]:
    """Modellens rutor per bild: [{"klass", "bbox" (x, y, b, h i bildens px), "konfidens"}].
    RF-DETR numrerar klasserna från 0 i `class_names`-ordning (utan överklassen), inte med
    COCO-filens id."""
    namn = list(getattr(modell, "class_names", None) or KLASSER)
    ut = []
    for i in range(0, len(bilder), 8):
        res = modell.predict(bilder[i:i + 8], threshold=troskel)
        for d in (res if isinstance(res, list) else [res]):
            rad = []
            for (x0, y0, x1, y1), c, k in zip(d.xyxy, d.confidence, d.class_id):
                if 0 <= int(k) < len(namn) and namn[int(k)] in KLASSER:
                    rad.append({"klass": namn[int(k)], "konfidens": float(c),
                                "bbox": [float(x0), float(y0), float(x1 - x0), float(y1 - y0)]})
            ut.append(rad)
    return ut


def prova(mapp: Path, vikter: Path) -> dict:
    """mAP (COCO, IoU 0,50:0,95 och 0,50) på provet, totalt, per klass och per källa."""
    import contextlib
    import io
    from PIL import Image
    from pycocotools.coco import COCO
    from pycocotools.cocoeval import COCOeval
    mapp = Path(mapp).expanduser()
    fil = mapp / "test" / "_annotations.coco.json"
    gt = COCO(str(fil))
    kalla = json.loads((mapp / "bilder.json").read_text(encoding="utf-8"))
    modell = ladda(vikter)
    ims = gt.dataset["images"]
    t0 = time.time()
    det = detektioner(modell, [Image.open(mapp / "test" / im["file_name"]).convert("RGB") for im in ims], 0.001)
    sek_per_bild = (time.time() - t0) / max(1, len(ims))
    res = [{"image_id": im["id"], "category_id": KLASSER.index(r["klass"]) + 1, "bbox": r["bbox"],
            "score": r["konfidens"]} for im, rad in zip(ims, det) for r in rad]
    dt = gt.loadRes(res) if res else None

    def matt(bild_id=None, kat=None) -> dict:
        if dt is None:
            return {"map": 0.0, "map50": 0.0}
        e = COCOeval(gt, dt, "bbox")
        if bild_id is not None:
            e.params.imgIds = bild_id
        if kat is not None:
            e.params.catIds = [kat]
        with contextlib.redirect_stdout(io.StringIO()):
            e.evaluate(); e.accumulate(); e.summarize()
        return {"map": round(float(e.stats[0]), 4), "map50": round(float(e.stats[1]), 4)}

    r = {"bilder": len(ims), "alla": matt(), "ms_per_bild": round(1000 * sek_per_bild, 1)}
    for i, k in enumerate(KLASSER):
        r[k] = matt(kat=i + 1)
    for kl in sorted(set(kalla.values())):
        ids = [im["id"] for im in ims if kalla.get(im["file_name"]) == kl]
        if ids:
            r[kl] = {"bilder": len(ids), "alla": matt(ids), **{k: matt(ids, i + 1) for i, k in enumerate(KLASSER)}}
    return r


# ---------------------------------------------------------------------------- förslag

def tider_ark(faser: dict) -> list[tuple[str, float]]:
    """Kontaktarkets tider (s relativt klicket) ur svingens faser (METOD M4): adressen och
    finishen som i kontaktark.tider, resten som andelar mellan start, topp och träff."""
    from .kontaktark import tider
    fast = tider(faser)
    start = faser["start"] if faser.get("start") is not None else fast["adress"]
    t = {"start": start, "topp": faser["topp"], "traff": faser["traff"]}
    ut = []
    for namn, d in FASER_ARK:
        if d is None:
            ut.append((namn, fast[namn]))
        else:
            a, b, u, *extra = d
            ut.append((namn, t[a] + u * (t[b] - t[a]) + (extra[0] if extra else 0.0)))
    return ut


def utsnitt(leder_rutor: list[list], bredd: int, hojd: int, skala: float = UTSNITT_SKALA,
            min_konfidens: float = 0.3) -> tuple[int, int, int] | None:
    """Ett kvadratiskt utsnitt (x0, y0, sida) kring golfaren för hela svingen: mitten i
    ledernas gemensamma ruta, sidan `skala` × kroppens höjd (lägst till högst led), högst
    bildens långsida. Är sidan större än bilden åt ett håll ligger utsnittet utanför där (`skar`
    fyller med svart), annars inom bilden. None utan leder. METOD MF7"""
    p = [(x, y) for leder in leder_rutor for j in leder if j is not None
         for x, y, c in [(j["x"], j["y"], j["c"]) if isinstance(j, dict) else j] if c >= min_konfidens]
    if not p:
        return None
    a = np.array(p, float)
    (x0, y0), (x1, y1) = a.min(0), a.max(0)
    sida = int(min(max(bredd, hojd), round(skala * max(y1 - y0, x1 - x0))))
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    ux = int(np.clip(round(cx - sida / 2), min(0, bredd - sida), max(0, bredd - sida)))
    uy = int(np.clip(round(cy - sida / 2), min(0, hojd - sida), max(0, hojd - sida)))
    return ux, uy, sida


def skar(bild: np.ndarray, x0: int, y0: int, sida: int) -> np.ndarray:
    """Utsnittet ur bilden, med svart där det ligger utanför."""
    h, w = bild.shape[:2]
    ut = np.zeros((sida, sida) + bild.shape[2:], bild.dtype)
    ax, ay, bx, by = max(0, x0), max(0, y0), min(w, x0 + sida), min(h, y0 + sida)
    if bx > ax and by > ay:
        ut[ay - y0:by - y0, ax - x0:bx - x0] = bild[ay:by, ax:bx]
    return ut


def _rita(img: np.ndarray, rad: list[dict], text: str) -> np.ndarray:
    import cv2
    ut = img.copy()
    for r in rad:
        x, y, w, h = (int(round(v)) for v in r["bbox"])
        f = FARG[r["klass"]]
        cv2.rectangle(ut, (x, y), (x + w, y + h), f, 2)
        cv2.putText(ut, f"{r['konfidens']:.2f}", (x, max(12, y - 4)), cv2.FONT_HERSHEY_SIMPLEX, 0.45, f, 1)
    return ut


def _etikett(img: np.ndarray, text: str) -> np.ndarray:
    import cv2
    img[:24] = 0
    cv2.putText(img, text, (6, 17), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1, cv2.LINE_AA)
    return img


def forslag(paket_filer: list[Path], vikter: Path, ut: Path, troskel: float = TROSKEL,
            s3: Path | None = None) -> list[dict]:
    """Ett kontaktark per sving (<ut>/<pass>/<vy>-<slag>.jpg) med modellens rutor i 11 lägen
    från adress till finish, och förslagen som JSON bredvid (källa "modell", aldrig facit).
    Klippets ruta läses med S3:s förskjutning när `s3` (eller ~/swinglab-s3/<pass>/s3.json)
    har den för slaget, annars utan (METOD MF1)."""
    import cv2
    from . import analys as A
    from . import klipp as KL
    from . import paket as P
    from . import s3_facit as S3F
    ut = utanfor_repot(ut)
    modell = ladda(vikter)
    resultat = []
    for pf in paket_filer:
        p = P.las(pf)
        fsk = S3F.las_forskjutningar(p.pass_id, s3)
        rader = {r["id"]: r for r in A.mat_paket(p, p.langd_m or 1.8) if "faser" in r}
        mapp = ut / p.pass_id
        mapp.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory() as tmp, zipfile.ZipFile(pf) as z:
            for s in p.slag:
                if not (s.klipp and s.lederna and s.klick_i_klipp_s is not None):
                    continue
                faser = rader[s.id]["faser"] if s.id in rader else FASER_ANTAGNA
                klipp = Path(tmp) / f"{s.id}{Path(s.klipp).suffix}"
                klipp.write_bytes(P.las_ur_zip(z, p.fil, s.klipp))
                lw, lh = s.lederna["width"], s.lederna["height"]
                rutor = s.lederna["frames"]
                lagen = []
                for namn, t in tider_ark(faser):
                    narmast = min(rutor, key=lambda r: abs(r["t"] - t))
                    lagen.append((namn, float(narmast["t"]) + float(s.klick_i_klipp_s), narmast["joints"]))
                # Bara klippets rutor i [0; längd) (METOD MS12), lästa på e + δ (MF1).
                d_s = fsk.get((p.fil, s.id), 0.0) / 1000.0
                lagen = [(n, tk + d_s, j) for n, tk, j in lagen if P.i_klippet(s, tk)]
                bilder = KL.ramar_vid(klipp, [tk for _, tk, _ in lagen], lw, lh, 0.006)
                if not bilder:
                    continue
                h, w = next(iter(bilder.values()))[1].shape[:2]
                sx, sy = w / lw, h / lh
                leder = [[None if j is None else ({"x": j["x"] * sx, "y": j["y"] * sy, "c": j["c"]}
                                                   if isinstance(j, dict) else [j[0] * sx, j[1] * sy, j[2]])
                          for j in jj] for _, _, jj in lagen]
                k = min(w, h)
                u = utsnitt(leder, w, h) or ((w - k) // 2, (h - k) // 2, k)
                x0, y0, sida = u
                lagen = [(n, tk, bilder[tk]) for n, tk, _ in lagen if tk in bilder]
                skurna = [skar(b, x0, y0, sida) for _, _, (_, b) in lagen]
                det = detektioner(modell, skurna, troskel)
                rutor_ark = []
                for (namn, tk, (tr, _)), bild, rad in zip(lagen, skurna, det):
                    rutor_ark.append(_etikett(cv2.resize(_rita(bild, rad, namn), (RUTA_PX, RUTA_PX)), namn))
                while len(rutor_ark) % 6:
                    rutor_ark.append(np.zeros((RUTA_PX, RUTA_PX, 3), np.uint8))
                ark = np.vstack([np.hstack(rutor_ark[i:i + 6]) for i in range(0, len(rutor_ark), 6)])
                namn_ark = f"{p.vy}-{s.id}"
                cv2.imwrite(str(mapp / f"{namn_ark}.jpg"), cv2.cvtColor(ark, cv2.COLOR_RGB2BGR),
                            [cv2.IMWRITE_JPEG_QUALITY, 88])
                d = {"format": "swinglab-forslag/1", "kalla": "modell", "facit": False, "pass": p.pass_id,
                     "vy": p.vy, "slag": s.id, "utsnitt": list(u), "troskel": troskel,
                     "faser": "uppmatta" if s.id in rader else "antagna",
                     "forskjutning_ms": fsk.get((p.fil, s.id)),
                     "rutor": [{"lage": n, "t_klipp": round(tr, 4),
                                "forslag": [{**r, "bbox": [round(r["bbox"][0] + x0, 1), round(r["bbox"][1] + y0, 1),
                                                           round(r["bbox"][2], 1), round(r["bbox"][3], 1)],
                                             "konfidens": round(r["konfidens"], 3)} for r in rad]}
                               for (n, _, (tr, _)), rad in zip(lagen, det)]}
                (mapp / f"{namn_ark}.json").write_text(json.dumps(d, ensure_ascii=False), encoding="utf-8")
                hittat = {k: sum(1 for rad in det if any(r["klass"] == k for r in rad)) for k in KLASSER}
                resultat.append({"ark": str(mapp / f"{namn_ark}.jpg"), "rutor": len(det), **hittat})
    return resultat


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="steg", required=True)
    b = sub.add_parser("bygg")
    b.add_argument("kallor", nargs="+", type=Path)
    b.add_argument("--ut", type=Path, required=True)
    t = sub.add_parser("trana")
    t.add_argument("mapp", type=Path)
    t.add_argument("--ut", type=Path, required=True)
    t.add_argument("--epoker", type=int, default=20)
    t.add_argument("--batch", type=int, default=8)
    t.add_argument("--ackum", type=int, default=2)
    t.add_argument("--fortsatt", action="store_true", help="ta upp träningen från <ut>/last.ckpt")
    pr = sub.add_parser("prov")
    pr.add_argument("mapp", type=Path)
    pr.add_argument("--vikter", type=Path, required=True)
    f = sub.add_parser("forslag")
    f.add_argument("paket", nargs="+", type=Path)
    f.add_argument("--vikter", type=Path, required=True)
    f.add_argument("--ut", type=Path, required=True)
    f.add_argument("--troskel", type=float, default=TROSKEL)
    f.add_argument("--s3", type=Path, help="S3:s s3.json (standard ~/swinglab-s3/<pass>/s3.json)")
    a = ap.parse_args(argv)
    try:
        if a.steg == "bygg":
            r = bygg(a.kallor, a.ut)
        elif a.steg == "trana":
            r = trana(a.mapp, a.ut, a.epoker, a.batch, a.ackum, a.fortsatt)
        elif a.steg == "prov":
            r = prova(a.mapp, a.vikter)
        else:
            r = forslag(a.paket, a.vikter, a.ut, a.troskel, a.s3)
    except FormFel as e:
        print(f"fel: {e}", file=sys.stderr)
        return 2
    print(json.dumps(r, indent=1, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
