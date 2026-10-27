"""S7-1 steg 1: förmärkaren för klubban (PLAN S7, BESLUT B92, METOD MF7).

En detektor för klubba och klubbhuvud, tränad på öppna CC BY 4.0-dataset från Roboflow,
föreslår rutor i Johannes svingar så att han rättar i stället för att märka från noll.
Förslaget är aldrig facit: bara det Johannes klickat räknas som märkning (B71, B92).

    python tools/pc/formarkare.py bygg <coco-mapp> [fler] --ut ~/swinglab-s7/trana
    python tools/pc/formarkare.py trana ~/swinglab-s7/trana --ut ~/swinglab-s7/vikter
    python tools/pc/formarkare.py prov ~/swinglab-s7/trana --vikter <vikter.pth>
    python tools/pc/formarkare.py forslag <paket.zip> [fler] --vikter <vikter.pth> --ut ~/swinglab-s7/forslag
    python tools/pc/formarkare.py facit <paket.zip> [fler] --markering <klubba.json> --vikter <vikter.pth>
    python tools/pc/formarkare.py matt <paket.zip> [fler] --vikter <vikter med händer> --ut ~/swinglab-s7/matt

`bygg` läser bara mappar i COCO-format (Roboflows export) och lägger varje bild i träning,
val eller prov **per scen**: bilder vars miniatyrer nästan är lika (samma video, samma
uppställning) hamnar i samma del, så att provet inte mäter grannrutor ur träningen. Johannes
paket är inte COCO och kan inte komma in i träningen den vägen; passet från 2026-10-24 är
provpasset (B92) och körs bara med `forslag`.

`forslag` gör ett kontaktark per sving och förslagsfilen `swinglab-<pass>-<vy>-forslag.json`
(`swinglab-klubba-forslag/1`, docs/FORMAT.md, S7d) som Johannes delar till telefonen. Kontrollera
den före delningen: `python tools/pc/klubba_forslag.py <fil> --paket <zip>` (MF8).

Modellen är RF-DETR Nano (Apache 2.0, `pip install "rfdetr[train]"`), aldrig Ultralytics
(AGPL, B92). Den körs i WSL2 på 2080 Ti:n. Allt som skrivs (bilder, vikter, förslag) ska
ligga utanför repot och utanför /mnt (CLAUDE.md, Dataregeln); verktyget vägrar annars.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
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
ALLA_KLASSER = KLASSER + ("hander",)          # METOD MF7: händerna bara i golf-club-tracking (klass 3)
MODELLER = {"nano": "RFDETRNano", "small": "RFDETRSmall"}   # RF-DETR i Apache 2.0 (B92)
# Datasetens klassnamn → våra. golf-49wbh: club, club_head; golf-club-tracking: 0 (skaftet),
# 1 (huvudet) och 3 (händerna, bara när `klasser` tar med dem: golf-49wbh saknar dem). METOD MF7
NAMN = {"club": "klubba", "club_head": "klubbhuvud", "0": "klubba", "1": "klubbhuvud", "3": "hander"}
MINIATYR = 16              # METOD MF7: px i scenens miniatyr (16 × 16, gråskala)
LIKA = 0.95                # METOD MF7: korrelationen över vilken två bilder är samma scen
PROV_ANDEL = 0.10          # METOD MF7: andel av varje källas bilder som hålls ut för provet
VAL_ANDEL = 0.10           # METOD MF7: andel för valet av vikter under träningen
DELAR = ("train", "valid", "test")            # Roboflows mappnamn; test = provet
TROSKEL = 0.30             # METOD MF7: modellens rutor med lägre konfidens ritas inte i kontaktarket
UTSNITT_SKALA = 2.0        # METOD MF7: utsnittets sida kring kroppen (utan händer) = 2,0 × kroppens höjd
HAND_SKALA = 1.8           # METOD MF7: utsnittets sida kring händerna = 1,8 × kroppens höjd (rutans egen, median)
KROPP_MIN_LEDER = 6        # METOD MF7: en ruta räknas i kroppens höjd med minst så många leder
HANDLEDER = (5, 6)         # handled_v och handled_h i filens ordning (format.LEDER_FIL)
GRANNAR_RUTOR = 3          # METOD MF7: en säker granne söks högst så många rutor bort åt varje håll
GRANNAR_TOL = (0.02, 0.25) # METOD MF7: avstånd från grannarnas linje: × kroppens höjd + × grannarnas avstånd
GRANNAR_MIN = 0.2          # METOD MF7: lägsta egna konfidens som grannarna kan lyfta
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

def las_coco(mapp: Path, klasser: tuple[str, ...] = KLASSER) -> list[dict]:
    """Alla bilder i en Roboflow-export (train, valid och test slås ihop, delningen görs om):
    [{"fil", "namn", "bredd", "hojd", "rutor": [{"klass", "bbox"}]}]. Klasser utanför
    NAMN eller `klasser` tas bort; en bild utan rutor står kvar som negativ."""
    mapp = Path(mapp)
    ut = []
    for del_ in DELAR:
        fil = mapp / del_ / "_annotations.coco.json"
        if not fil.exists():
            continue
        d = json.loads(fil.read_text(encoding="utf-8"))
        kat = {c["id"]: (NAMN.get(c["name"]) if NAMN.get(c["name"]) in klasser else None) for c in d["categories"]}
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


def coco(bilder: list[dict], klasser: tuple[str, ...] = KLASSER) -> dict:
    """COCO-filen i Roboflows form, som RF-DETR läser: kategori 0 är överklassen,
    1, 2 … är `klasser`."""
    kat = [{"id": 0, "name": "klubba-delar", "supercategory": "none"}] + [
        {"id": i + 1, "name": k, "supercategory": "klubba-delar"} for i, k in enumerate(klasser)]
    images, anns = [], []
    for i, b in enumerate(bilder):
        images.append({"id": i, "file_name": b["ut_namn"], "width": b["bredd"], "height": b["hojd"]})
        for r in b["rutor"]:
            x, y, w, h = r["bbox"]
            anns.append({"id": len(anns), "image_id": i, "category_id": klasser.index(r["klass"]) + 1,
                         "bbox": [x, y, w, h], "area": w * h, "iscrowd": 0})
    return {"info": {"description": "SwingLab S7-1, METOD MF7"}, "images": images,
            "annotations": anns, "categories": kat}


def bygg(kallor: list[Path], ut: Path, klasser: tuple[str, ...] = KLASSER) -> dict:
    """Träningsmappen: <ut>/{train,valid,test}/ med länkar till bilderna och
    _annotations.coco.json, plus delning.json med antalen per källa och del och `klasser`."""
    import cv2
    ut = utanfor_repot(ut)
    alla: list[dict] = []
    sammanfattning: dict[str, dict] = {}
    for k in kallor:
        k = Path(k).expanduser().resolve()
        bilder = las_coco(k, klasser)
        v = np.stack([miniatyr(cv2.imread(b["fil"], cv2.IMREAD_GRAYSCALE)) for b in bilder])
        scen = scener(v)
        delar = dela([b["namn"] for b in bilder], scen)
        for b, d in zip(bilder, delar):
            b.update(kalla=k.name, del_=d, ut_namn=f"{k.name}__{Path(b['namn']).name}")
        s = {"bilder": len(bilder), "scener": int(len(set(scen.tolist())))}
        for d in DELAR:
            i_del = [b for b in bilder if b["del_"] == d]
            s[d] = {"bilder": len(i_del),
                    **{kl: sum(1 for b in i_del for r in b["rutor"] if r["klass"] == kl) for kl in klasser}}
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
        (mapp / "_annotations.coco.json").write_text(json.dumps(coco(i_del, klasser)), encoding="utf-8")
    (ut / "bilder.json").write_text(json.dumps({b["ut_namn"]: b["kalla"] for b in alla}), encoding="utf-8")
    r = {"skapad": datetime.now().astimezone().isoformat(timespec="seconds"), "kallor": sammanfattning,
         "lika": LIKA, "miniatyr": MINIATYR, "klasser": list(klasser)}
    (ut / "delning.json").write_text(json.dumps(r, indent=1, ensure_ascii=False), encoding="utf-8")
    return r


# ---------------------------------------------------------------------------- träna och prova

def trana(mapp: Path, ut: Path, epoker: int, batch: int, ackum: int, fortsatt: bool = False,
          storlek_: str = "nano") -> dict:
    """RF-DETR (`storlek_` i MODELLER, med sin egen upplösning) från COCO-vikterna (Apache 2.0)
    på mappen från `bygg`. Valet av vikter görs på `valid`; provet (`test`) används inte. Med
    `fortsatt` tas träningen upp från <ut>/last.ckpt (efter ett avbrott, till exempel när WSL
    uppdateras). Storleken skrivs i <ut>/modell.json, så att `ladda` tar rätt modell. Svarar tiden."""
    import rfdetr
    ut = utanfor_repot(ut)
    ut.mkdir(parents=True, exist_ok=True)
    (ut / "modell.json").write_text(json.dumps({"storlek": storlek_}), encoding="utf-8")
    sist = ut / "last.ckpt"
    fortsatt = bool(fortsatt and sist.exists())
    t0 = time.time()
    getattr(rfdetr, MODELLER[storlek_])().train(
        dataset_dir=str(Path(mapp).expanduser()), output_dir=str(ut), epochs=epoker, batch_size=batch,
        grad_accum_steps=ackum, num_workers=2, seed=0, run_test=False, tensorboard=False,
        progress_bar=None, resume=str(sist) if fortsatt else None)
    r = {"sekunder": round(time.time() - t0), "epoker": epoker, "batch": batch, "ackum": ackum,
         "modell": f"RF-DETR {storlek_}", "fortsatt": fortsatt}
    (ut / "tid.json").write_text(json.dumps(r), encoding="utf-8")
    return r


def storlek(vikter: Path) -> str:
    """Modellens storlek ur <vikternas mapp>/modell.json; nano när den saknas (de första vikterna)."""
    try:
        return json.loads((Path(vikter).expanduser().parent / "modell.json").read_text(encoding="utf-8"))["storlek"]
    except (OSError, KeyError, json.JSONDecodeError):
        return "nano"


def ladda(vikter: Path):
    import rfdetr
    return getattr(rfdetr, MODELLER[storlek(vikter)])(pretrain_weights=str(Path(vikter).expanduser()))


def detektioner(modell, bilder: list, troskel: float) -> list[list[dict]]:
    """Modellens rutor per bild: [{"klass", "bbox" (x, y, b, h i bildens px), "konfidens"}].
    RF-DETR numrerar klasserna från 0 i `class_names`-ordning (utan överklassen), inte med
    COCO-filens id."""
    namn = list(getattr(modell, "class_names", None) or ALLA_KLASSER)
    ut = []
    for i in range(0, len(bilder), 8):
        res = modell.predict(bilder[i:i + 8], threshold=troskel)
        for d in (res if isinstance(res, list) else [res]):
            rad = []
            for (x0, y0, x1, y1), c, k in zip(d.xyxy, d.confidence, d.class_id):
                if 0 <= int(k) < len(namn) and namn[int(k)] in ALLA_KLASSER:
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
    kat = {c["name"]: c["id"] for c in gt.dataset["categories"] if c["id"] != 0}
    t0 = time.time()
    det = detektioner(modell, [Image.open(mapp / "test" / im["file_name"]).convert("RGB") for im in ims], 0.001)
    sek_per_bild = (time.time() - t0) / max(1, len(ims))
    res = [{"image_id": im["id"], "category_id": kat[r["klass"]], "bbox": r["bbox"],
            "score": r["konfidens"]} for im, rad in zip(ims, det) for r in rad if r["klass"] in kat]
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
    for k, i in kat.items():
        r[k] = matt(kat=i)
    for kl in sorted(set(kalla.values())):
        ids = [im["id"] for im in ims if kalla.get(im["file_name"]) == kl]
        if ids:
            r[kl] = {"bilder": len(ids), "alla": matt(ids), **{k: matt(ids, i) for k, i in kat.items()}}
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


def _xyc(j) -> tuple[float, float, float]:
    return (j["x"], j["y"], j["c"]) if isinstance(j, dict) else (j[0], j[1], j[2])


def kroppen(leder_rutor: list[list], min_konfidens: float = 0.3) -> tuple[float, float, float] | None:
    """(kroppens höjd, mitt x, mitt y) i px över svingens rutor. Höjden är medianen av varje rutas
    egen höjd (lägst till högst led, rutor med minst KROPP_MIN_LEDER leder), så att den inte beror
    på vilka rutor som är med: över hela svingen räknade, med armarna uppe i finishen, blev den för
    stor och utsnittet för stort (provpassets DTL vid P6, 2026-10-27). Utan sådana rutor ledernas
    gemensamma ruta. Mitten är den gemensamma rutans. None utan leder. METOD MF7"""
    p = [_xyc(j)[:2] for leder in leder_rutor for j in leder if j is not None and _xyc(j)[2] >= min_konfidens]
    if not p:
        return None
    a = np.array(p, float)
    (x0, y0), (x1, y1) = a.min(0), a.max(0)
    hojder = []
    for leder in leder_rutor:
        y = [_xyc(j)[1] for j in leder if j is not None and _xyc(j)[2] >= min_konfidens]
        if len(y) >= KROPP_MIN_LEDER:
            hojder.append(max(y) - min(y))
    h = float(np.median(hojder)) if hojder else float(max(y1 - y0, x1 - x0))
    return h, float((x0 + x1) / 2), float((y0 + y1) / 2)


def hander(leder: list, min_konfidens: float = 0.3) -> tuple[float, float] | None:
    """Händernas mitt i rutan: handledernas mitt, eller den som syns (greppregeln, METOD M1)."""
    h = [_xyc(leder[i])[:2] for i in HANDLEDER
         if i < len(leder) and leder[i] is not None and _xyc(leder[i])[2] >= min_konfidens]
    return (sum(x for x, _ in h) / len(h), sum(y for _, y in h) / len(h)) if h else None


def utsnitt(leder: list, kropp: tuple[float, float, float], bredd: int, hojd: int) -> tuple[int, int, int]:
    """Rutans kvadratiska utsnitt (x0, y0, sida) i klippets px: kring händerna med sidan
    HAND_SKALA × kroppens höjd, så att klubban ryms åt alla håll utan att bli liten; utan
    händer kring kroppens mitt med UTSNITT_SKALA. Högst bildens långsida; det som ligger utanför
    bilden fyller `skar` med svart. METOD MF7"""
    H, cx, cy = kropp
    m = hander(leder)
    sida = HAND_SKALA * H if m else UTSNITT_SKALA * H
    if m:
        cx, cy = m
    sida = int(max(1, min(max(bredd, hojd), round(sida))))
    return int(round(cx - sida / 2)), int(round(cy - sida / 2)), sida


def skar(bild: np.ndarray, x0: int, y0: int, sida: int) -> np.ndarray:
    """Utsnittet ur bilden, med svart där det ligger utanför."""
    h, w = bild.shape[:2]
    ut = np.zeros((sida, sida) + bild.shape[2:], bild.dtype)
    ax, ay, bx, by = max(0, x0), max(0, y0), min(w, x0 + sida), min(h, y0 + sida)
    if bx > ax and by > ay:
        ut[ay - y0:by - y0, ax - x0:bx - x0] = bild[ay:by, ax:bx]
    return ut


def over_tiden(p: list[dict | None], hojd_px: float, grans: float | None = None,
               n: int = GRANNAR_RUTOR) -> tuple[list[dict | None], dict]:
    """Klubbhuvudets punkter i svingens rutor i ordning (None där modellen inte gav något) prövas
    mot grannarna: närmaste punkt med konfidens ≥ `grans` (MF8) högst `n` rutor bort åt varje
    håll. Med en sådan granne åt båda håll ska punkten ligga högst 0,02 × kroppens höjd +
    0,25 × grannarnas avstånd från linjen mellan dem. En punkt som gör det och själv har minst
    GRANNAR_MIN får den svagare grannens konfidens om den är högre än den egna; en som inte gör
    det stryks, också en säker. Utan granne åt båda håll gäller modellens egen konfidens. Svarar
    (punkterna med konfidens ≥ `grans`, annars None; {"lyfta", "strukna"}). METOD MF7"""
    if grans is None:
        from .klubba_forslag import VISA_KONFIDENS as grans
    saker = [q is not None and q["konfidens"] >= grans for q in p]
    ut: list[dict | None] = [None] * len(p)
    lyfta = strukna = 0
    for i, q in enumerate(p):
        if q is None:
            continue
        v = next((j for j in range(i - 1, max(-1, i - n - 1), -1) if saker[j]), None)
        h = next((j for j in range(i + 1, min(len(p), i + n + 1)) if saker[j]), None)
        if v is None or h is None:
            ut[i] = q if saker[i] else None
            continue
        a, b = p[v], p[h]
        u = (i - v) / (h - v)
        ex, ey = a["x"] + u * (b["x"] - a["x"]), a["y"] + u * (b["y"] - a["y"])
        tol = GRANNAR_TOL[0] * hojd_px + GRANNAR_TOL[1] * math.hypot(b["x"] - a["x"], b["y"] - a["y"])
        if math.hypot(q["x"] - ex, q["y"] - ey) > tol:
            strukna += saker[i]
            continue
        k = q["konfidens"]
        if not saker[i] and k >= GRANNAR_MIN:
            k = min(a["konfidens"], b["konfidens"])
            lyfta += 1
        if k >= grans:
            ut[i] = {**q, "konfidens": round(float(k), 3)}
    return ut, {"lyfta": lyfta, "strukna": strukna}


def _rita(img: np.ndarray, rad: list[dict], punkt: tuple[float, float] | None = None) -> np.ndarray:
    """Modellens rutor (konfidens ≥ TROSKEL) och, grön, punkten som står i förslagsfilen."""
    import cv2
    ut = img.copy()
    for r in rad:
        if r["konfidens"] < TROSKEL:
            continue
        x, y, w, h = (int(round(v)) for v in r["bbox"])
        f = FARG[r["klass"]]
        cv2.rectangle(ut, (x, y), (x + w, y + h), f, 2)
        cv2.putText(ut, f"{r['konfidens']:.2f}", (x, max(12, y - 4)), cv2.FONT_HERSHEY_SIMPLEX, 0.45, f, 1)
    if punkt is not None:
        cv2.circle(ut, (int(round(punkt[0])), int(round(punkt[1]))), max(4, ut.shape[0] // 60), (0, 230, 0), -1)
    return ut


def _etikett(img: np.ndarray, text: str) -> np.ndarray:
    import cv2
    img[:24] = 0
    cv2.putText(img, text, (6, 17), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1, cv2.LINE_AA)
    return img


def forslag(paket_filer: list[Path], vikter: Path, ut: Path, s3: Path | None = None) -> list[dict]:
    """Förslagsfilen `swinglab-<pass>-<vy>-forslag.json` (`swinglab-klubba-forslag/1`,
    docs/FORMAT.md) med klubbhuvudets mitt för varje Visions-ruta från adressen till finishen,
    prövad över tiden (`over_tiden`) och kontrollerad mot paketet, och ett kontaktark per sving
    (<ut>/<pass>/<vy>-<slag>.jpg) i 11 lägen med modellens rutor och filens punkt. Förslaget är
    aldrig facit (B92). Klippets ruta läses med S3:s förskjutning när `s3` (eller
    ~/swinglab-s3/<pass>/s3.json) har den för slaget, annars utan (METOD MF1)."""
    import cv2
    from . import analys as A
    from . import klubba_forslag as KF
    from . import paket as P
    from . import s3_facit as S3F
    ut = utanfor_repot(ut)
    version, data = modell_info(vikter)
    modell = ladda(vikter)
    resultat = []
    for pf in paket_filer:
        p = P.las(pf)
        fsk = S3F.las_forskjutningar(p.pass_id, s3)
        rader = {r["id"]: r for r in A.mat_paket(p, p.langd_m or 1.8) if "faser" in r}
        mapp = ut / p.pass_id
        mapp.mkdir(parents=True, exist_ok=True)
        forsta = next((s for s in p.slag if s.lederna), None)
        if forsta is None:
            continue
        fil_d = KF.ny(p.pass_id, p.vy, f"rfdetr-{storlek(vikter)}-klubba", version, data, forsta.lederna["width"],
                      forsta.lederna["height"], paket=p.fil)
        with tempfile.TemporaryDirectory() as tmp, zipfile.ZipFile(pf) as z:
            for s in p.slag:
                if not (s.klipp and s.lederna and s.klick_i_klipp_s is not None):
                    continue
                lw, lh = s.lederna["width"], s.lederna["height"]
                if (lw, lh) != (fil_d["bredd"], fil_d["hojd"]):
                    resultat.append({"slag": f"{p.vy}-{s.id}", "hoppat": "annan bildstorlek än passets första slag"})
                    continue
                faser = rader[s.id]["faser"] if s.id in rader else FASER_ANTAGNA
                klipp = Path(tmp) / f"{s.id}{Path(s.klipp).suffix}"
                klipp.write_bytes(P.las_ur_zip(z, p.fil, s.klipp))
                lagen = tider_ark(faser)
                rutor = _svingens_rutor(modell, klipp, s, fsk.get((p.fil, s.id), 0.0), lagen, lw, lh)
                if not rutor:
                    continue
                skala = rutor[0]["skala"]
                raa = [huvud_punkt(r["rad"], r["x0"], r["y0"], 1 / skala, 1 / skala, lw, lh, GRANNAR_MIN)
                       for r in rutor]
                hojd_px = rutor[0]["kropp_hojd"] / skala
                punkter, filtret = over_tiden(raa, hojd_px)
                for r, q in zip(rutor, punkter):
                    if q is not None:
                        KF.lagg_till(fil_d, s.id, r["t"], {"huvud": q}, ruta=r["nr"], t_klipp=r["t_cv"])
                # Kontaktarket: de 11 lägenas rutor ur samma genomgång.
                ark = []
                for r, q in zip(rutor, punkter):
                    if r.get("bild") is None:
                        continue
                    pkt = None if q is None else (q["x"] * skala - r["x0"], q["y"] * skala - r["y0"])
                    ark.append(_etikett(cv2.resize(_rita(r["bild"], r["rad"], pkt), (RUTA_PX, RUTA_PX)), r["lage"]))
                while len(ark) % 6:
                    ark.append(np.zeros((RUTA_PX, RUTA_PX, 3), np.uint8))
                namn_ark = f"{p.vy}-{s.id}"
                cv2.imwrite(str(mapp / f"{namn_ark}.jpg"),
                            cv2.cvtColor(np.vstack([np.hstack(ark[i:i + 6]) for i in range(0, len(ark), 6)]),
                                         cv2.COLOR_RGB2BGR), [cv2.IMWRITE_JPEG_QUALITY, 88])
                resultat.append({"slag": namn_ark, "faser": "uppmatta" if s.id in rader else "antagna",
                                 "rutor": len(rutor),
                                 "huvud_03": sum(1 for q in raa if q is not None and q["konfidens"] >= TROSKEL),
                                 "huvud_visas": sum(1 for q in raa if q is not None and q["konfidens"] >= KF.VISA_KONFIDENS),
                                 "i_filen": sum(1 for q in punkter if q is not None), **filtret})
        if fil_d["slag"]:
            fil = mapp / f"swinglab-{p.pass_id}-{p.vy}-forslag.json"
            KF.skriv(fil, fil_d)
            fel = KF.mot_paket(KF.las(fil), p)
            if fel:
                raise FormFel(f"{fil.name}: " + "; ".join(fel))
            resultat.append({"forslagsfil": str(fil), "slag": len(fil_d["slag"]),
                             "rutor": sum(len(x["rutor"]) for x in fil_d["slag"])})
    return resultat


def _svingens_rutor(modell, klipp: Path, s, forskjutning_ms: float, lagen: list[tuple[str, float]],
                    lw: int, lh: int, batch: int = 16) -> list[dict]:
    """Varje ruta i klippet vars Visions-ruta (`klubba_forslag.vision_t`, MF1) ligger från det
    första till det sista av `lagen` (namn, Visions t), i ordning: {"t", "t_cv", "nr", "x0", "y0",
    "sida" (utsnittet i klippets px), "rad" (modellens rutor i utsnittet, konfidens ≥ 0,1),
    "skala" (klippets px per leds px), "kropp_hojd" (klippets px), och för rutan närmast
    varje läge "lage" och "bild" (utsnittet)}. Rutorna läses en i taget, så att en sving om 600
    rutor inte ligger i minnet. Tom utan leder i svingen."""
    from . import klipp as KL
    from . import klubba_forslag as KF
    from . import paket as P
    alla = {round(float(f["t"]), 6): f["joints"] for f in s.lederna["frames"]}
    if not alla:
        return []
    # Varje läge → den närmaste Visions-rutan; fönstret går från den första av dem till den sista.
    narmast: dict[float, str] = {}
    for namn, t in lagen:
        narmast.setdefault(min(alla, key=lambda x: abs(x - t)), namn)
    fran, till = min(narmast), max(narmast)
    vision = {t: j for t, j in alla.items() if fran <= t <= till}
    ut: list[dict] = []
    vantar: list[dict] = []
    kropp = None
    senast = -math.inf

    def kor() -> None:
        for r, rad in zip(vantar, detektioner(modell, [r["_bild"] for r in vantar], 0.1)):
            r["rad"] = rad
            bild = r.pop("_bild")
            if r["t"] in narmast:
                r.update(lage=narmast[r["t"]], bild=bild)
            ut.append(r)
        vantar.clear()

    for nr, (t_cv, bild) in enumerate(KL.ramar(klipp, lw, lh)):
        if t_cv - forskjutning_ms / 1000.0 - s.klick_i_klipp_s > till + KF.RUTA_TOL:
            break
        if not P.i_klippet(s, t_cv):
            continue
        t = KF.vision_t(s, t_cv, forskjutning_ms)
        t = None if t is None else round(t, 6)
        # Två rutor i filen får inte ligga närmare än 2 · RUTA_TOL (METOD MF8).
        if t is None or t < fran or t > till or t - senast < 2 * KF.RUTA_TOL:
            continue
        senast = t
        h, w = bild.shape[:2]
        skala = w / lw
        if kropp is None:
            kropp = kroppen([[None if j is None else (lambda x, y, c: [x * skala, y * skala, c])(*_xyc(j))
                              for j in jj] for jj in vision.values()])
            if kropp is None:
                return []
        leder = [None if j is None else (lambda x, y, c: [x * skala, y * skala, c])(*_xyc(j))
                 for j in vision.get(t, [])]
        x0, y0, sida = utsnitt(leder, kropp, w, h)
        vantar.append({"t": t, "t_cv": t_cv, "nr": nr, "x0": x0, "y0": y0, "sida": sida, "skala": skala,
                       "kropp_hojd": kropp[0], "_bild": skar(bild, x0, y0, sida)})
        if len(vantar) >= batch:
            kor()
    if vantar:
        kor()
    return ut


def huvud_punkt(rad: list[dict], x0: float, y0: float, sx: float, sy: float, bredd: int, hojd: int,
                min_konfidens: float | None = None) -> dict | None:
    """Klubbhuvudets punkt `huvud` i förslagsfilen ur modellens rutor i utsnittet: den säkraste
    rutan för klubbhuvudet med konfidens ≥ MF8:s gräns, flyttad med utsnittets hörn (x0, y0) till
    klippets px och skalad (sx, sy) till ledernas px; punkten är rutans mitt och `box` rutan,
    beskuren till bilden. Aldrig `hosel` (huvudets mitt ligger 3–5 cm från hoseln) och aldrig
    `grepp` (klubbans ruta har inget entydigt hörn för händerna). None utan en sådan ruta eller
    med mitten utanför bilden. METOD MF7, BESLUT B93"""
    from . import klubba_forslag as KF
    grans = KF.VISA_KONFIDENS if min_konfidens is None else min_konfidens
    kand = [r for r in rad if r["klass"] == "klubbhuvud" and r["konfidens"] >= grans]
    if not kand:
        return None
    r = max(kand, key=lambda r: r["konfidens"])
    bx, by, bw, bh = r["bbox"]
    a = ((bx + x0) * sx, (by + y0) * sy)
    b = ((bx + bw + x0) * sx, (by + bh + y0) * sy)
    cx, cy = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    if not (0 <= cx <= bredd and 0 <= cy <= hojd):
        return None
    ax, ay = max(0.0, a[0]), max(0.0, a[1])
    ex, ey = min(float(bredd), b[0]), min(float(hojd), b[1])
    q = {"x": round(cx, 1), "y": round(cy, 1), "konfidens": round(float(r["konfidens"]), 3)}
    if ex - ax >= 0.1 and ey - ay >= 0.1:
        q["box"] = [round(ax, 1), round(ay, 1), round(ex - ax, 1), round(ey - ay, 1)]
    return q


# Datasetens namnangivelse i förslagsfilen och i appens "About" (CC BY 4.0, BESLUT B92).
DATASET = {"golf-49wbh": ("CC BY 4.0", "https://universe.roboflow.com/lvs-rd/golf-49wbh"),
           "golf-club-tracking": ("CC BY 4.0", "https://universe.roboflow.com/club-head-tracking/golf-club-tracking"),
           "azb-dc": ("CC BY 4.0", "https://universe.roboflow.com/club-head/azb-dc")}


def modell_info(vikter: Path) -> tuple[str, list[dict]]:
    """(version, data) för förslagsfilen ur vikternas mapp: versionen är mappens namn och
    vikternas datum, datat källorna i träningsmappens delning.json med licens och adress."""
    vikter = Path(vikter).expanduser()
    datum = datetime.fromtimestamp(vikter.stat().st_mtime).strftime("%Y-%m-%d")
    kallor: list[str] = []
    try:
        cfg = json.loads((vikter.parent / "training_config.json").read_text(encoding="utf-8"))
        mapp = Path((cfg.get("train_config") or cfg)["dataset_dir"])
        kallor = list(json.loads((mapp / "delning.json").read_text(encoding="utf-8"))["kallor"])
    except (OSError, KeyError, TypeError, json.JSONDecodeError):
        pass
    if not kallor:
        raise FormFel(f"{vikter.parent}: träningens källor går inte att läsa (training_config.json, delning.json)")
    data = []
    for k in kallor:
        if k not in DATASET:
            raise FormFel(f"{k}: licensen är inte känd (DATASET i formarkare.py)")
        data.append({"namn": k, "licens": DATASET[k][0], "kalla": DATASET[k][1]})
    return f"{vikter.parent.name.removeprefix('vikter-')}-{datum}", data


# ---------------------------------------------------------------------------- mot Johannes märkning

TRAFF_MARGINAL = 0.5       # METOD MF7: hoseln räknas som träffad inom huvudets ruta vidgad 0,5 × rutans största sida
KONF_KLASSER = (0.1, 0.3, 0.5)   # METOD MF7: förslagen redovisas i konfidensklasserna 0,1–0,3, 0,3–0,5 och ≥ 0,5


def grepp_punkt(rad: list[dict], x0: float, y0: float, sx: float, sy: float,
                min_konfidens: float = 0.05) -> dict | None:
    """Greppet ur händerna: mitten av modellens säkraste ruta för händerna, flyttad med utsnittets
    hörn och skalad som `huvud_punkt`; None utan händer (modellen saknar klassen eller ser dem
    inte). Mot Johannes grepp ligger den 3–4 % av skaftet bort, mot Visions handleders 10–11 %.
    METOD MF7"""
    kand = [r for r in rad if r["klass"] == "hander" and r["konfidens"] >= min_konfidens]
    if not kand:
        return None
    r = max(kand, key=lambda r: r["konfidens"])
    bx, by, bw, bh = r["bbox"]
    return {"x": (bx + bw / 2 + x0) * sx, "y": (by + bh / 2 + y0) * sy, "konfidens": float(r["konfidens"])}


def _riktning(a: tuple[float, float], b: tuple[float, float]) -> float:
    return math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))


def bedom(huvud: dict | None, punkter: dict, grepp: dict | None = None) -> dict | None:
    """En märkt ruta mot modellens säkraste huvud där (i samma px): {"konfidens", "traff"
    (hoseln inom huvudets ruta vidgad TRAFF_MARGINAL), "avstand" (huvudets mitt → hoseln i andel
    av skaftets längd, greppet → hoseln)}, och med modellens `grepp` (`grepp_punkt`) också
    "grepp_fel" (i andel av skaftet) och, med huvudet, "vinkel" (skaftets riktning greppet → huvudet
    mot Johannes greppet → hoseln, i grader). None när rutan saknar greppet eller hoseln. Utan
    huvud: konfidens 0 och ingen träff. En punkt som inte syns (`{"syns_inte": true}`) saknas.
    METOD MF7"""
    g, h = punkter.get("grepp"), punkter.get("klubbhuvud")
    if not (g and "x" in g and h and "x" in h):
        return None
    skaft = math.hypot(g["x"] - h["x"], g["y"] - h["y"])
    if skaft <= 0:
        return None
    ut: dict = {"konfidens": 0.0, "traff": False, "avstand": None}
    if huvud is not None:
        bx, by, bw, bh = huvud.get("box") or [huvud["x"], huvud["y"], 0.0, 0.0]
        m = TRAFF_MARGINAL * max(bw, bh)
        ut = {"konfidens": float(huvud["konfidens"]),
              "traff": bool(bx - m <= h["x"] <= bx + bw + m and by - m <= h["y"] <= by + bh + m),
              "avstand": math.hypot(huvud["x"] - h["x"], huvud["y"] - h["y"]) / skaft}
    if grepp is not None:
        ut["grepp_fel"] = math.hypot(grepp["x"] - g["x"], grepp["y"] - g["y"]) / skaft
        if huvud is not None:
            d = _riktning((grepp["x"], grepp["y"]), (huvud["x"], huvud["y"])) - _riktning((g["x"], g["y"]), (h["x"], h["y"]))
            ut["vinkel"] = abs((d + 180) % 360 - 180)
    return ut


def sammanfatta(rader: list[dict]) -> dict:
    """Träffarna per konfidensklass, och avståndet till hoseln (median och p90 i andel av skaftet)
    bland träffarna. METOD MF7"""
    def klass(k: float) -> str:
        if k >= KONF_KLASSER[2]:
            return f"≥{KONF_KLASSER[2]}"
        if k >= KONF_KLASSER[1]:
            return f"{KONF_KLASSER[1]}–{KONF_KLASSER[2]}"
        if k >= KONF_KLASSER[0]:
            return f"{KONF_KLASSER[0]}–{KONF_KLASSER[1]}"
        return f"<{KONF_KLASSER[0]}"
    ut: dict = {"rutor": len(rader), "klasser": {}}
    for r in rader:
        k = ut["klasser"].setdefault(klass(r["konfidens"]), {"rutor": 0, "traff": 0})
        k["rutor"] += 1
        k["traff"] += r["traff"]
    a = sorted(r["avstand"] for r in rader if r["traff"] and r["avstand"] is not None)
    if a:
        ut["avstand_median"] = round(float(np.median(a)), 3)
        ut["avstand_p90"] = round(float(np.quantile(a, 0.9)), 3)
    g = [r["grepp_fel"] for r in rader if r.get("grepp_fel") is not None]
    if g:
        ut["grepp_fel_median"] = round(float(np.median(g)), 3)
        ut["grepp_fel_p90"] = round(float(np.quantile(g, 0.9)), 3)
    v = [r["vinkel"] for r in rader if r.get("vinkel") is not None]
    if v:
        ut["vinkel_median"] = round(float(np.median(v)), 2)
        ut["vinkel_p90"] = round(float(np.quantile(v, 0.9)), 2)
        ut["vinkel_max"] = round(float(max(v)), 2)
    return ut


def mot_markering(paket_filer: list[Path], markering: Path, vikter: Path) -> dict:
    """Modellen mot Johannes märkning (`swinglab-klubba`, markera_klubba.py eller telefonen): för
    varje märkt ruta läses klippets ruta (`t_ruta`), utsnittet kring händerna körs genom modellen
    och det säkraste huvudet prövas mot hoseln (`bedom`). Svarar sammanfattningen per vy och per
    läge. En video utan paket (markera_klubba.py på ett klipp) har inga leder: där ser modellen
    hela bilden, som en kvadrat med svart utanför, och vyn redovisas som `<vy> (hela bilden)`.
    Provpasset (B92) får mätas så här men aldrig tränas på. METOD MF7"""
    from . import klipp as KL
    from . import paket as P
    mk = json.loads(Path(markering).read_text(encoding="utf-8"))
    modell = ladda(vikter)
    rader: list[dict] = []
    for pf in paket_filer:
        pf = Path(pf)
        if pf.suffix.lower() != ".zip":
            for r in [r for r in mk["rutor"] if r.get("fil") == pf.name and r.get("status") == "markerad"]:
                bilder = KL.ramar_vid(pf, [r["t_ruta"]], r["bredd"], r["hojd"], 0.001)
                if r["t_ruta"] not in bilder:
                    continue
                bild = bilder[r["t_ruta"]][1]
                h, w = bild.shape[:2]
                k = max(w, h)
                x0, y0 = (w - k) // 2, (h - k) // 2
                rad = detektioner(modell, [skar(bild, x0, y0, k)], 0.05)[0]
                b = bedom(huvud_punkt(rad, x0, y0, r["bredd"] / w, r["hojd"] / h, r["bredd"], r["hojd"], 0.05),
                          r["punkter"], grepp_punkt(rad, x0, y0, r["bredd"] / w, r["hojd"] / h))
                if b is not None:
                    rader.append({**b, "vy": f"{r['vy']} (hela bilden)", "val": r["val"], "id": r["id"]})
            continue
        p = P.las(pf)
        mina = [r for r in mk["rutor"] if r.get("fil") == p.fil and r.get("status") == "markerad"]
        with tempfile.TemporaryDirectory() as tmp, zipfile.ZipFile(pf) as z:
            for sid in sorted({r["slag"] for r in mina}):
                s = next((x for x in p.slag if x.id == sid), None)
                if s is None or not (s.klipp and s.lederna):
                    continue
                klipp = Path(tmp) / f"{sid}{Path(s.klipp).suffix}"
                klipp.write_bytes(P.las_ur_zip(z, p.fil, s.klipp))
                lw, lh = s.lederna["width"], s.lederna["height"]
                rr = [r for r in mina if r["slag"] == sid]
                bilder = KL.ramar_vid(klipp, [r["t_ruta"] for r in rr], lw, lh, 0.001)
                if not bilder:
                    continue
                h, w = next(iter(bilder.values()))[1].shape[:2]
                skala = w / lw
                vision = {round(float(f["t"]), 6): f["joints"] for f in s.lederna["frames"]}
                skalad = lambda jj: [None if j is None else (lambda x, y, c: [x * skala, y * skala, c])(*_xyc(j))
                                     for j in jj]
                t0, t1 = min(r["t"] for r in rr) - 1.5, max(r["t"] for r in rr) + 1.5
                kropp = kroppen([skalad(j) for t, j in vision.items() if t0 <= t <= t1])
                if kropp is None:
                    continue
                for r in rr:
                    if r["t_ruta"] not in bilder:
                        continue
                    leder = skalad(vision[min(vision, key=lambda t: abs(t - r["t"]))])
                    x0, y0, sida = utsnitt(leder, kropp, w, h)
                    rad = detektioner(modell, [skar(bilder[r["t_ruta"]][1], x0, y0, sida)], 0.05)[0]
                    sx, sy = r["bredd"] / w, r["hojd"] / h     # märkningens px (hela den upprätta bilden)
                    b = bedom(huvud_punkt(rad, x0, y0, sx, sy, r["bredd"], r["hojd"], 0.05), r["punkter"],
                              grepp_punkt(rad, x0, y0, sx, sy))
                    if b is not None:
                        rader.append({**b, "vy": r["vy"], "val": r["val"], "id": r["id"]})
    ut = {"alla": sammanfatta(rader)}
    for vy in sorted({r["vy"] for r in rader}):
        ut[vy] = sammanfatta([r for r in rader if r["vy"] == vy])
    for val in sorted({r["val"] for r in rader}):
        ut[f"lage {val}"] = sammanfatta([r for r in rader if r["val"] == val])
    ut["rader"] = [{"id": r["id"], "konfidens": round(r["konfidens"], 3), "traff": r["traff"],
                    "avstand": None if r["avstand"] is None else round(r["avstand"], 3),
                    "vinkel": None if r.get("vinkel") is None else round(r["vinkel"], 2)} for r in rader]
    return ut


# ---------------------------------------------------------------------------- måtten utan tryck

KROPPENS = ("P1", "P3", "P4", "P5", "P7", "P9", "P10")   # METOD M28: positionerna ur kroppen
POS_TOL_S = 0.010          # METOD MF7: en kroppsposition tar skaftet ur en ruta högst så långt bort
P1_NEDAT = (-150.0, -30.0) # METOD MF7: skaftets vinkel vid P1 (M46, speglad) ska ligga här, nedåt mot bollen
KORTAST_JAMNA = 5          # METOD MF7: skaftets längd bakifrån jämnas med medianen över så många rutor
# METOD M45: rutorna mellan vilka skaftet söker P2, P6 och P8 (före, efter; reserv för före).
SKAFT_FONSTER = {"P2": ("P1", "P3", "P4"), "P6": ("P5", "P7", "P4"), "P8": ("P7", "P9", "P10")}


def skaft_serie(rutor: list[dict], lw: int, lh: int, grans: float | None = None) -> list[dict]:
    """Skaftet i varje ruta ur `_svingens_rutor`: greppet ur händerna (`grepp_punkt`) och
    klubbhuvudets mitt (`huvud_punkt`), var för sig med konfidens ≥ `grans` (MF8), i ledernas px:
    [{"t", "g", "h", "kg", "kh"}] för rutorna där båda finns, i tidsordning. Huvudets mitt står för
    hoseln (cirka 4 % av skaftet bort, MF7). Inte prövad över tiden (`over_tiden`): bakifrån vid P6
    rör sig huvudet snabbast och i en skarp båge förbi händerna, och filtret strök just de rutorna
    (provpassets DTL, 2026-10-27). METOD MF7"""
    if not rutor:
        return []
    from .klubba_forslag import VISA_KONFIDENS
    grans = VISA_KONFIDENS if grans is None else grans
    skala = rutor[0]["skala"]
    gr = [grepp_punkt(r["rad"], r["x0"], r["y0"], 1 / skala, 1 / skala, grans) for r in rutor]
    hu = [huvud_punkt(r["rad"], r["x0"], r["y0"], 1 / skala, 1 / skala, lw, lh, grans) for r in rutor]
    return [{"t": r["t"], "g": (g["x"], g["y"]), "h": (h["x"], h["y"]), "kg": g["konfidens"], "kh": h["konfidens"]}
            for r, g, h in zip(rutor, gr, hu) if g is not None and h is not None]


def _narmast(serie: list[dict], t: float, tol: float) -> dict | None:
    if not serie:
        return None
    q = min(serie, key=lambda q: abs(q["t"] - t))
    return q if abs(q["t"] - t) <= tol else None


def auto_positioner(serie: list[dict], positioner: dict, vy: str, x_tecken: float,
                    start: float | None = None) -> dict[str, dict]:
    """Positionerna utan tryck: {position: skaftets ruta} ur skaftets serie. Kroppens
    positioner (M28) tar rutan närmast kroppens tid, högst POS_TOL_S bort. P2, P6 och P8
    definieras av skaftet (M45) mellan positionerna före och efter (SKAFT_FONSTER): framifrån
    rutan där skaftets vinkel går genom vågrätt åt svingens håll (`klubba.forslag_tid_skaft`
    mellan grannrutor), bakifrån rutan där skaftet är kortast (pekar mot kameran), med
    längden jämnad över KORTAST_JAMNA rutor. P1 saknas när skaftet inte pekar nedåt (P1_NEDAT).
    En position utan ruta saknas. METOD MF7"""
    from . import klubba as KL
    ut: dict[str, dict] = {}
    for p in KROPPENS:
        t = positioner.get(p)
        q = _narmast(serie, t, POS_TOL_S) if t is not None else None
        if q is not None:
            ut[p] = {**q, "kalla": "kroppen"}
    # P1 är adressen: pekar skaftet inte nedåt mot bollen är kroppens P1 en annan ruta (en
    # förberedelse, s24 i provpasset), och P1 saknas hellre än blir fel.
    if "P1" in ut:
        g, h = ut["P1"]["g"], ut["P1"]["h"]
        v = KL.riktning((x_tecken * g[0], g[1]), (x_tecken * h[0], h[1]))
        if not P1_NEDAT[0] <= v <= P1_NEDAT[1]:
            del ut["P1"]
    for p, (fore, efter, reserv) in SKAFT_FONSTER.items():
        ta = positioner.get(fore) if positioner.get(fore) is not None else positioner.get(reserv)
        tb = positioner.get(efter) if positioner.get(efter) is not None else positioner.get(reserv)
        if ta is None or tb is None or not tb > ta:
            continue
        inom = [q for q in serie if ta <= q["t"] <= tb]
        if len(inom) < 2:
            continue
        if vy == "fo":
            for a, b in zip(inom, inom[1:]):
                marks = [{"position": KL.SKAFT_VAGRATT[p][0], "t": a["t"], "grepp": a["g"], "hosel": a["h"]},
                         {"position": KL.SKAFT_VAGRATT[p][1], "t": b["t"], "grepp": b["g"], "hosel": b["h"]}]
                t = KL.forslag_tid_skaft(p, marks, x_tecken, start if p == "P2" else None)
                if t is not None:
                    ut[p] = {**(a if abs(a["t"] - t) <= abs(b["t"] - t) else b), "kalla": "skaftet"}
                    break
        else:
            langd = [math.dist(q["g"], q["h"]) for q in inom]
            k = KORTAST_JAMNA // 2
            jamn = [float(np.median(langd[max(0, i - k):i + k + 1])) for i in range(len(langd))]
            ut[p] = {**inom[int(np.argmin(jamn))], "kalla": "skaftet"}
    return ut


def matt_utan_tryck(paket_filer: list[Path], vikter: Path, ut: Path, s3: Path | None = None) -> dict:
    """Klubbmåtten utan tryck för varje mätt slag (S7-1, research 7 §4.2): skaftet i varje ruta
    från P1 till P9 ur en modell med händer (`skaft_serie`), positionerna ur kroppen och skaftet
    (`auto_positioner`) och måtten med samma `klubba.mat` som för Johannes markeringar. Skriver
    <ut>/<pass>/klubba-auto-<vy>.json (aldrig en markering, B71, B92) och svarar en sammanfattning
    per vy: hur många slag som fick P6 och varje mått, och P6 mot förslaget mitt mellan P5 och P7
    (klubba.forslag_tid). METOD MF7"""
    from . import analys as A
    from . import format as fm
    from . import klubba as KL
    from . import paket as P
    from . import s3_facit as S3F
    ut = utanfor_repot(ut)
    modell = ladda(vikter)
    sammanfattning: dict = {}
    for pf in paket_filer:
        p = P.las(pf)
        fsk = S3F.las_forskjutningar(p.pass_id, s3)
        rader = {r["id"]: r for r in A.mat_paket(p, p.langd_m or 1.8) if "positioner" in r}
        slag_ut = []
        with tempfile.TemporaryDirectory() as tmp, zipfile.ZipFile(pf) as z:
            for s in p.slag:
                if s.id not in rader or not (s.klipp and s.lederna and s.klick_i_klipp_s is not None):
                    continue
                pos = rader[s.id]["positioner"]
                fran = pos.get("P1")
                till = pos.get("P9") if pos.get("P9") is not None else pos.get("P10")
                if fran is None or till is None:
                    continue
                klipp = Path(tmp) / f"{s.id}{Path(s.klipp).suffix}"
                klipp.write_bytes(P.las_ur_zip(z, p.fil, s.klipp))
                lw, lh = s.lederna["width"], s.lederna["height"]
                rutor = _svingens_rutor(modell, klipp, s, fsk.get((p.fil, s.id), 0.0),
                                        [("P1", fran - 0.02), ("P9", till + 0.02)], lw, lh)
                serie = skaft_serie(rutor, lw, lh)
                sv = fm.fran_dict(P.till_sving(p, s, p.langd_m or 1.8))
                faser = rader[s.id].get("faser") or {}
                auto = auto_positioner(serie, pos, p.vy, sv.x_tecken, faser.get("start"))
                marks = [{"position": k, "t": v["t"], "grepp": v["g"], "hosel": v["h"]} for k, v in auto.items()]
                pinne = p.serier[s.serie].riktpinne if s.serie in p.serier else None
                matt = KL.mat(marks, p.vy, sv.x_tecken, lw, lh, sv, pinne=pinne)
                forslag_p6 = KL.forslag_tid("P6", pos)
                slag_ut.append({
                    "slag": s.id, "rutor": len(rutor), "skaft": len(serie),
                    "positioner": {k: {"t": round(v["t"], 4), "kalla": v["kalla"],
                                       "grepp": [round(c, 1) for c in v["g"]], "hosel": [round(c, 1) for c in v["h"]],
                                       "konfidens": [round(v["kg"], 3), round(v["kh"], 3)]} for k, v in auto.items()},
                    "p6_mot_forslaget_ms": None if "P6" not in auto or forslag_p6 is None
                    else round(1000 * (auto["P6"]["t"] - forslag_p6), 1),
                    "matt": {k: round(v, 2) for k, v in matt.items()}})
        mapp = ut / p.pass_id
        mapp.mkdir(parents=True, exist_ok=True)
        (mapp / f"klubba-auto-{p.vy}.json").write_text(json.dumps(
            {"format": "swinglab-klubba-auto/1", "kalla": "modell", "facit": False, "pass": p.pass_id, "vy": p.vy,
             "vikter": str(vikter), "slag": slag_ut}, ensure_ascii=False, indent=1), encoding="utf-8")
        namn_ = KL.namn(p.vy)
        sammanfattning[p.vy] = {
            "slag": len(slag_ut),
            "med_p6": sum(1 for x in slag_ut if "P6" in x["positioner"]),
            "p6_mot_forslaget_ms_median": (round(float(np.median([abs(x["p6_mot_forslaget_ms"]) for x in slag_ut
                                                                  if x["p6_mot_forslaget_ms"] is not None])), 1)
                                           if any(x["p6_mot_forslaget_ms"] is not None for x in slag_ut) else None),
            "matt": {m: sum(1 for x in slag_ut if m in x["matt"]) for m in namn_ if any(m in x["matt"] for x in slag_ut)}}
    return sammanfattning


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="steg", required=True)
    b = sub.add_parser("bygg")
    b.add_argument("kallor", nargs="+", type=Path)
    b.add_argument("--ut", type=Path, required=True)
    b.add_argument("--klasser", default=",".join(KLASSER), help=f"bland {','.join(ALLA_KLASSER)}")
    t = sub.add_parser("trana")
    t.add_argument("mapp", type=Path)
    t.add_argument("--ut", type=Path, required=True)
    t.add_argument("--epoker", type=int, default=20)
    t.add_argument("--batch", type=int, default=8)
    t.add_argument("--ackum", type=int, default=2)
    t.add_argument("--fortsatt", action="store_true", help="ta upp träningen från <ut>/last.ckpt")
    t.add_argument("--storlek", choices=sorted(MODELLER), default="nano")
    pr = sub.add_parser("prov")
    pr.add_argument("mapp", type=Path)
    pr.add_argument("--vikter", type=Path, required=True)
    fa = sub.add_parser("facit")
    fa.add_argument("paket", nargs="+", type=Path)
    fa.add_argument("--markering", type=Path, required=True, help="swinglab-<pass>-klubba.json")
    fa.add_argument("--vikter", type=Path, required=True)
    ma = sub.add_parser("matt")
    ma.add_argument("paket", nargs="+", type=Path)
    ma.add_argument("--vikter", type=Path, required=True, help="en modell med händer")
    ma.add_argument("--ut", type=Path, required=True)
    ma.add_argument("--s3", type=Path, help="S3:s s3.json (standard ~/swinglab-s3/<pass>/s3.json)")
    f = sub.add_parser("forslag")
    f.add_argument("paket", nargs="+", type=Path)
    f.add_argument("--vikter", type=Path, required=True)
    f.add_argument("--ut", type=Path, required=True)
    f.add_argument("--s3", type=Path, help="S3:s s3.json (standard ~/swinglab-s3/<pass>/s3.json)")
    a = ap.parse_args(argv)
    try:
        if a.steg == "bygg":
            klasser = tuple(k for k in a.klasser.split(",") if k)
            if not klasser or any(k not in ALLA_KLASSER for k in klasser):
                raise FormFel(f"--klasser: bland {', '.join(ALLA_KLASSER)}")
            r = bygg(a.kallor, a.ut, klasser)
        elif a.steg == "trana":
            r = trana(a.mapp, a.ut, a.epoker, a.batch, a.ackum, a.fortsatt, a.storlek)
        elif a.steg == "prov":
            r = prova(a.mapp, a.vikter)
        elif a.steg == "matt":
            r = matt_utan_tryck(a.paket, a.vikter, a.ut, a.s3)
        elif a.steg == "facit":
            r = mot_markering(a.paket, a.markering, a.vikter)
        else:
            r = forslag(a.paket, a.vikter, a.ut, a.s3)
    except FormFel as e:
        print(f"fel: {e}", file=sys.stderr)
        return 2
    print(json.dumps(r, indent=1, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
