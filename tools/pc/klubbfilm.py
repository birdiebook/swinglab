"""En påhittad film med en ritad klubba längs en känd båge: facit för klubbhuvudets bana
(PLAN S7b, METOD M61, BESLUT B71). Inga riktiga svingar (CLAUDE.md, Dataregeln).

    python tools/pc/klubbfilm.py      # skriver tools/tests/fixturer/klubbspar.json

Filmen är gråskala i halv upplösning (bilden 600 × 560 px, rutorna 300 × 280), 240 bilder/s
från −1,0 till +0,45 s kring träffen, med var nionde ruta borta (rutnätet är ojämnt som
telefonens). Kroppen är tjocka streck mellan lederna och ritas över klubban, så att
klubbhuvudet döljs bakom kroppen; ett mörkt fält uppe till höger döljer det mot en mörk
bakgrund. Bruset är ett heltal ur en hash per pixel och ruta, så att SwingLabKit
(`KlubbFilm`, SwingDemo) ritar exakt samma bytes; summan per ruta i fixturen prövar det.

Lederna som spårningen får (Visions ställe) är de sanna med ±1,5 px brus, och ankarna
(Johannes tryck vid P1–P10) de sanna punkterna med ±1,5 px brus. Sanningen är hoseln i varje
ruta, där klubbhuvudets skiva har sin mitt.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np

BREDD, HOJD = 600, 560          # hela bilden, px
SKALA = 0.5                     # rutorna i halv upplösning
FPS = 240.0
T0, T1 = -1.0, 0.45
BORT = 9                        # var nionde ruta saknas (i % BORT == 4)

PSI_TOPP, H_TOPP = 2.0, 1.4     # armens vinkel och handledens vinkling vid toppen, rad
PSI_FIN, H_FIN = 2.4, 1.0       # vid finishen
ARM, SKAFT = 120.0, 150.0       # axlarnas mitt → greppet, greppet → hoseln, px

BAKGRUND, MORK = 150, 50        # bakgrunden och det mörka fältet
MORKT_FALT = (330.0, 0.0, 600.0, 110.0)   # x0, y0, x1, y1 i hela bilden
SKAFT_FARG, HUVUD_FARG, KROPP_FARG = 95, 60, 110
SKAFT_R, HUVUD_R = 1.6, 8.0

ANKARE = {"P1": -0.90, "P2": -0.62, "P3": -0.50, "P4": -0.25, "P5": -0.12, "P6": -0.06,
          "P7": 0.0, "P8": 0.06, "P9": 0.15, "P10": 0.40}
LED_BRUS, TRYCK_BRUS = 1.5, 1.5

DTL_KORT = 0.25                 # varianten bakifrån: skaftets vågräta del i bild

# Varianterna (bara Python, METOD M61): de genereras i proven och checkas inte in.
VARIANTER = ("dtl", "oskarpa", "kontrast", "kontrast_brus", "skak", "boll", "skugga", "forskjuten")

FIXTUR = Path(__file__).resolve().parents[1] / "tests" / "fixturer" / "klubbspar.json"
M32 = 0xFFFFFFFF


def hash32(x, y, k):
    """Heltalshash (lowbias32) av pixel och ruta; numpy uint32 eller int, samma som Swift."""
    if isinstance(x, np.ndarray):
        h = (x.astype(np.uint32) * np.uint32(0x9E3779B1)) ^ (y.astype(np.uint32) * np.uint32(0x85EBCA77)) \
            ^ np.uint32((k * 0xC2B2AE3D) & M32)
        h ^= h >> np.uint32(16)
        h *= np.uint32(0x7FEB352D)
        h ^= h >> np.uint32(15)
        h *= np.uint32(0x846CA68B)
        h ^= h >> np.uint32(16)
        return h
    h = ((x * 0x9E3779B1) & M32) ^ ((y * 0x85EBCA77) & M32) ^ ((k * 0xC2B2AE3D) & M32)
    h ^= h >> 16
    h = (h * 0x7FEB352D) & M32
    h ^= h >> 15
    h = (h * 0x846CA68B) & M32
    h ^= h >> 16
    return h


def _smooth(u: float) -> float:
    return u * u * (3.0 - 2.0 * u)


def vinklar(t: float) -> tuple[float, float]:
    """Armens vinkel ψ och handledens vinkling h, rad (ψ = 0: händerna rakt under axlarna)."""
    if t <= -0.80:
        return 0.0, 0.0
    if t <= -0.25:
        s = _smooth((t + 0.80) / 0.55)
        return PSI_TOPP * s, H_TOPP * s * s
    if t <= 0.0:
        u = (t + 0.25) / 0.25
        return PSI_TOPP * (1.0 - u * u), H_TOPP * (1.0 - u * u * u * u)
    if t <= 0.40:
        v = t / 0.40
        w = 2.0 * v - v * v
        return -PSI_FIN * w, -H_FIN * w
    return -PSI_FIN, -H_FIN


def scen(t: float, dtl: bool = False) -> dict:
    """Svingen vid tiden t i hela bildens pixlar: greppet, hoseln och de 13 lederna. Med
    `dtl` förkortas skaftets vågräta del till en fjärdedel, som bakifrån när skaftet pekar mot
    kameran (P2, P6, P8)."""
    psi, h = vinklar(t)
    cx, cy = 300.0 + 8.0 * math.sin(0.5 * psi), 260.0
    hx, hy = 300.0 + 5.0 * math.sin(0.4 * psi), 375.0
    g = (cx + ARM * math.sin(psi), cy + ARM * math.cos(psi))
    d = (math.sin(psi + h) * (DTL_KORT if dtl else 1.0), math.cos(psi + h))
    hosel = (g[0] + SKAFT * d[0], g[1] + SKAFT * d[1])
    ws = 50.0 * math.cos(0.6 * psi)
    wh = 35.0 * math.cos(0.35 * psi)
    sy = 3.0 * math.sin(0.6 * psi)
    axv, axh = (cx + ws, cy + sy), (cx - ws, cy - sy)
    hov, hoh = (hx + wh, hy), (hx - wh, hy)
    leder = [
        (cx + 4.0 * math.sin(0.3 * psi), cy - 55.0),                    # näsan
        axv, axh,
        ((axv[0] + g[0]) / 2.0, (axv[1] + g[1]) / 2.0),                  # armbågarna
        ((axh[0] + g[0]) / 2.0, (axh[1] + g[1]) / 2.0),
        (g[0] + 4.0, g[1]), (g[0] - 4.0, g[1]),                          # handlederna
        hov, hoh,
        (hx + 30.0, 455.0), (hx - 30.0, 455.0),                          # knäna
        (345.0, 530.0), (255.0, 530.0),                                  # fotlederna
    ]
    return {"grepp": g, "hosel": hosel, "leder": leder}


# Kroppen som streck (a, b, radie) mellan lederna och skivor (en punkt två gånger).
def _kropp(leder: list) -> list:
    L = leder
    mitt_axel = ((L[1][0] + L[2][0]) / 2.0, (L[1][1] + L[2][1]) / 2.0)
    mitt_hoft = ((L[7][0] + L[8][0]) / 2.0, (L[7][1] + L[8][1]) / 2.0)
    grepp = ((L[5][0] + L[6][0]) / 2.0, (L[5][1] + L[6][1]) / 2.0)
    return [(mitt_axel, mitt_hoft, 38.0), (L[1], L[2], 14.0), (L[7], L[8], 18.0),
            (L[1], L[3], 9.0), (L[3], L[5], 9.0), (L[2], L[4], 9.0), (L[4], L[6], 9.0),
            (L[7], L[9], 13.0), (L[9], L[11], 13.0), (L[8], L[10], 13.0), (L[10], L[12], 13.0),
            (L[0], L[0], 24.0), (grepp, grepp, 9.0)]


def _streck(px, py, a, b, r):
    """Pixlarna inom r från sträckan a–b (samma räkning som Swift)."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    n2 = dx * dx + dy * dy
    if n2 > 0.0:
        u = ((px - a[0]) * dx + (py - a[1]) * dy) / n2
        u = np.minimum(np.maximum(u, 0.0), 1.0)
    else:
        u = np.zeros_like(px)
    ex = px - (a[0] + u * dx)
    ey = py - (a[1] + u * dy)
    return ex * ex + ey * ey <= r * r


def tider() -> list[tuple[int, float]]:
    """Rutornas nummer i 240-rutnätet och tid, utan var nionde."""
    n = int(round((T1 - T0) * FPS)) + 1
    return [(i, T0 + i / FPS) for i in range(n) if i % BORT != 4]


def _bas(t: float, px, py, variant: str | None) -> np.ndarray:
    """Scenens gråtoner utan brus."""
    s = scen(t, dtl=variant == "dtl")
    skaft_farg, huvud_farg = (135, 125) if variant in ("kontrast", "kontrast_brus") else (SKAFT_FARG, HUVUD_FARG)
    bas = np.full(px.shape, BAKGRUND, dtype=np.int64)
    x0, y0, x1, y1 = MORKT_FALT
    bas[(px >= x0) & (px < x1) & (py >= y0) & (py < y1)] = MORK
    huvud = s["hosel"]
    if variant == "forskjuten":
        # Huvudets mitt 10 px bortom hoseln längs skaftet (sanningen är fortfarande hoseln).
        g = s["grepp"]
        n = math.sqrt((huvud[0] - g[0]) ** 2 + (huvud[1] - g[1]) ** 2)
        huvud = (huvud[0] + 10.0 * (huvud[0] - g[0]) / n, huvud[1] + 10.0 * (huvud[1] - g[1]) / n)
    bas[_streck(px, py, s["grepp"], huvud, SKAFT_R)] = skaft_farg
    bas[_streck(px, py, huvud, huvud, HUVUD_R)] = huvud_farg
    if variant == "skugga":
        # Klubbans skugga på marken: en mörk fläck som följer huvudet i x.
        bas[_streck(px, py, (huvud[0] + 30.0, 540.0), (huvud[0] + 30.0, 540.0), 12.0)] = 90
    for a, b, r in _kropp(s["leder"]):
        bas[_streck(px, py, a, b, r)] = KROPP_FARG
    return bas


def ruta(i: int, t: float, variant: str | None = None) -> np.ndarray:
    """Rutan som uint8 (rader × kolumner) i halv upplösning. Utan variant exakt samma bytes
    som SwingLabKit:s `KlubbFilm.ruta`."""
    w, h = int(BREDD * SKALA), int(HOJD * SKALA)
    jj, ii = np.mgrid[0:h, 0:w]
    px = (ii.astype(float) + 0.5) / SKALA
    py = (jj.astype(float) + 0.5) / SKALA
    if variant == "oskarpa":
        # Rörelseoskärpa: medlet av fyra lägen över en hel ruta (slutartiden 1/240 s).
        bas = sum(_bas(t + (j - 1.5) / (4 * FPS), px, py, variant) for j in range(4)) // 4
    else:
        bas = _bas(t, px, py, variant)
    hh = hash32(ii, jj, i)
    summa = (hh & 0xFF) + ((hh >> 8) & 0xFF) + ((hh >> 16) & 0xFF) + ((hh >> 24) & 0xFF)
    if variant == "kontrast":
        # Lågt brus (σ ≈ 2,5 gråtoner) och låg kontrast: den brusanpassade tröskeln.
        v = (bas * 60 + summa.astype(np.int64) + 30 - 510) // 60
    else:
        v = (bas * 20 + summa.astype(np.int64) + 10 - 510) // 20
    return np.clip(v, 0, 255).astype(np.uint8)


def brus(i: int, n: int, amp: float) -> float:
    """±amp/2 ur hashen (deterministiskt), för led n i ruta i."""
    return ((hash32(n, 7919, i) & 0xFFFF) / 65535.0 - 0.5) * amp


def film(variant: str | None = None) -> dict:
    """Hela filmen: rutorna, lederna, ankarna och sanningen. Lederna och ankarna i hela
    bildens pixlar. `variant` (VARIANTER) prövar spårningen mot det som riktiga klipp har."""
    rutor, leder, sanning = [], [], []
    dtl = variant == "dtl"
    for i, t in tider():
        s = scen(t, dtl=dtl)
        rutor.append(ruta(i, t, variant))
        leder.append([(x + brus(i, 2 * n, 2 * LED_BRUS), y + brus(i, 2 * n + 1, 2 * LED_BRUS))
                      for n, (x, y) in enumerate(s["leder"])])
        sanning.append(s["hosel"])
    t_rutor = [t for _, t in tider()]
    ankare = []
    for nr, (pos, ta) in enumerate(ANKARE.items()):
        k = min(range(len(t_rutor)), key=lambda j: abs(t_rutor[j] - ta))
        s = scen(t_rutor[k], dtl=dtl)
        ankare.append({"position": pos, "t": t_rutor[k],
                       "grepp": (s["grepp"][0] + brus(nr, 101, 2 * TRYCK_BRUS), s["grepp"][1] + brus(nr, 102, 2 * TRYCK_BRUS)),
                       "hosel": (s["hosel"][0] + brus(nr, 103, 2 * TRYCK_BRUS), s["hosel"][1] + brus(nr, 104, 2 * TRYCK_BRUS))})
    if variant == "skak":
        # Textur i bakgrunden och en kamera som skakar ±1 px (rutans px) mellan rutorna.
        yy, xx = np.mgrid[0:rutor[0].shape[0], 0:rutor[0].shape[1]]
        tex = (60 * np.sin(xx / 3.0) * np.sin(yy / 4.0)).astype(np.int32)
        rng = np.random.default_rng(2)
        rutor = [np.clip(r.astype(np.int32) + np.roll(tex, int(rng.integers(-1, 2)), axis=1), 0, 255).astype(np.uint8)
                 for r in rutor]
    if variant == "boll":
        # En ljus boll som ligger vid huvudet och flyger iväg efter träffen.
        k7 = min(range(len(t_rutor)), key=lambda j: abs(t_rutor[j]))
        hx, hy = sanning[k7]
        yy, xx = np.mgrid[0:rutor[0].shape[0], 0:rutor[0].shape[1]]
        ut = []
        for k, r in enumerate(rutor):
            r = r.copy()
            tk = t_rutor[k]
            bx, by = ((hx - 2500 * tk) * SKALA, (hy - 600 * tk) * SKALA) if tk > 0 else ((hx - 6) * SKALA, hy * SKALA)
            r[(xx + 0.5 - bx) ** 2 + (yy + 0.5 - by) ** 2 <= 4] = 240
            ut.append(r)
        rutor = ut
    return {"t": t_rutor, "rutor": rutor, "leder": leder, "sanning": sanning, "ankare": ankare}


def summa(r: np.ndarray) -> int:
    """Rutans kontrollsumma: Σ (index + 1) · byte mod 2³²."""
    v = r.reshape(-1).astype(np.uint64)
    return int((v * (np.arange(v.size, dtype=np.uint64) + 1)).sum() % (1 << 32))


def fixtur() -> dict:
    """Facit till Swift (BESLUT B12): rutornas summor, ankarna, Pythons bana och planet,
    och sanningen."""
    from . import klubbspar as KS
    f = film()
    bana = KS.spara(f["t"], f["rutor"], f["leder"], f["ankare"], SKALA, BREDD, HOJD)
    glesa = {}
    for keep in (("P1", "P2", "P3"), ("P1", "P4", "P7", "P10"), ("P5", "P6", "P7", "P8")):
        a = [x for x in f["ankare"] if x["position"] in keep]
        glesa[",".join(keep)] = KS.spara(f["t"], f["rutor"], f["leder"], a, SKALA, BREDD, HOJD)
    return {"bredd": BREDD, "hojd": HOJD, "skala": SKALA, "glesa": glesa,
            "t": f["t"], "summa": [summa(r) for r in f["rutor"]],
            "ankare": [{"position": a["position"], "t": a["t"], "grepp": list(a["grepp"]), "hosel": list(a["hosel"])}
                       for a in f["ankare"]],
            "bana": bana, "planet": KS.planet(bana, f["t"], f["ankare"], 1.0),
            "sanning": [list(p) for p in f["sanning"]]}


def main() -> int:
    FIXTUR.write_text(json.dumps(fixtur(), ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"skrev {FIXTUR}")
    return 0


if __name__ == "__main__":
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from pc import klubbfilm as _kf
    raise SystemExit(_kf.main())
