"""Klubbhuvudets bana mellan ankarna (PLAN S7b, METOD M61, BESLUT B71) på den PÅHITTADE
filmen i `klubbfilm.py`: felet mot sanningen, andelen interpolerade rutor, planet genom
nedsvingen och fixturen som Swift räknar samma tal ur (BESLUT B12)."""
from __future__ import annotations

import json
import math
import unittest

import numpy as np

import _hjalp  # noqa: F401
from pc import klubba as K
from pc import klubbfilm as KF
from pc import klubbspar as KS

# "Klart när" för den påhittade filmen (METOD M61), i skaftets längd (150 px i bilden).
SPAR_MEDIAN, SPAR_P95, INTERP_MAX = 0.02, 0.05, 0.20
INTERP_ANDEL = 0.50
GROVT, GROVA_MAX = 0.10, 0.01   # ett spårat fel över 10 % av skaftet är grovt; högst 1 % grova
PLAN_MAX = 1.0          # grader, planet ur banan mot planet ur sanningen
# Varianterna (METOD M61): (andelen interpolerade högst, interpolerade högst i skaft), eller
# None där taket inte nås (redovisas ärligt i M61; de spårade rutorna klarar ändå gränserna).
VARIANT_TAK = {"oskarpa": (0.55, 0.20), "kontrast": (0.55, 0.20), "skak": (0.55, 0.20), "boll": (0.55, 0.20),
               "skugga": (0.55, 0.20), "forskjuten": (0.55, 0.20), "dtl": None, "kontrast_brus": None}


def matt(f: dict, bana: list) -> dict:
    """Felen mot sanningen per källa och andelen interpolerade."""
    fel = {"spar": [], "interpolerad": [], "klick": []}
    for b, s in zip(bana, f["sanning"]):
        if b is not None:
            fel[b["kalla"]].append(math.dist((b["x"], b["y"]), s))
    n = sum(len(v) for v in fel.values())
    return {**fel, "andel": len(fel["interpolerad"]) / max(n, 1), "n": n}


class Film(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.f = KF.film()
        cls.bana = KS.spara(cls.f["t"], cls.f["rutor"], cls.f["leder"], cls.f["ankare"], KF.SKALA, KF.BREDD, KF.HOJD)

    def fel(self, kalla: str) -> list[float]:
        return [math.dist((b["x"], b["y"]), s) for b, s in zip(self.bana, self.f["sanning"])
                if b is not None and b["kalla"] == kalla]

    def test_felet_mot_sanningen(self) -> None:
        spar, interp = self.fel("spar"), self.fel("interpolerad")
        n = len(spar) + len(interp) + len(self.fel("klick"))
        andel = len(interp) / n
        print(f"\nS7b: {len(spar)} spårade (median {np.median(spar):.2f} px, p95 {np.percentile(spar, 95):.2f}, "
              f"max {max(spar):.2f}), {len(interp)} interpolerade (median {np.median(interp):.2f} px, "
              f"max {max(interp):.2f}), andelen interpolerade {andel:.2f}")
        self.assertLessEqual(np.median(spar), SPAR_MEDIAN * KF.SKAFT)
        self.assertLessEqual(np.percentile(spar, 95), SPAR_P95 * KF.SKAFT)
        self.assertLessEqual(max(interp), INTERP_MAX * KF.SKAFT)
        self.assertLessEqual(andel, INTERP_ANDEL)
        self.assertLessEqual(sum(e > GROVT * KF.SKAFT for e in spar), GROVA_MAX * len(spar))

    def test_banan_gar_fran_forsta_till_sista_ankaret(self) -> None:
        t = self.f["t"]
        k0 = t.index(self.f["ankare"][0]["t"])
        k1 = t.index(self.f["ankare"][-1]["t"])
        self.assertTrue(all(b is None for b in self.bana[:k0]))
        self.assertTrue(all(b is not None for b in self.bana[k0:k1 + 1]))
        self.assertTrue(all(b is None for b in self.bana[k1 + 1:]))
        self.assertEqual(sum(1 for b in self.bana if b and b["kalla"] == "klick"), len(self.f["ankare"]))

    def test_glesa_ankare_ritar_inget_fel(self) -> None:
        """Bara grannar i svingens ordning ger en bana: P1+P7, P1/P4/P7/P10 och P4/P7/P10 ger
        bara ankarna, och P1/P2/P3 ger banan P1–P3 och inget annat."""
        f = self.f
        for keep in (["P1", "P7"], ["P1", "P4", "P7", "P10"], ["P4", "P7", "P10"]):
            a = [x for x in f["ankare"] if x["position"] in keep]
            b = KS.spara(f["t"], f["rutor"], f["leder"], a, KF.SKALA, KF.BREDD, KF.HOJD)
            self.assertEqual(sum(x is not None for x in b), len(keep), keep)
            self.assertTrue(all(x["kalla"] == "klick" for x in b if x is not None))
        a = [x for x in f["ankare"] if x["position"] in ("P1", "P2", "P3")]
        b = KS.spara(f["t"], f["rutor"], f["leder"], a, KF.SKALA, KF.BREDD, KF.HOJD)
        k3 = f["t"].index(a[-1]["t"])
        self.assertTrue(all(x is None for x in b[k3 + 1:]))
        m = matt(f, b)
        self.assertTrue(all(e <= INTERP_MAX * KF.SKAFT for e in m["interpolerad"] + m["spar"]))

    def test_mort_falt_och_kroppen_ger_interpolerat(self) -> None:
        """Klubbhuvudet i det mörka fältet (toppen) syns inte och interpoleras; nära finishen
        (nästan stilla) likaså."""
        t = self.f["t"]
        for tq in (-0.30, 0.39):
            k = min(range(len(t)), key=lambda j: abs(t[j] - tq))
            self.assertEqual(self.bana[k]["kalla"], "interpolerad", tq)
        # I nedsvingen syns det och spåras.
        k = min(range(len(t)), key=lambda j: abs(t[j] + 0.03))
        self.assertEqual(self.bana[k]["kalla"], "spar")

    def test_planet_genom_nedsvingen(self) -> None:
        sann = [{"x": p[0], "y": p[1], "kalla": "sann"} for p in self.f["sanning"]]
        ps = {p["t"]: p["grader"] for p in KS.planet(sann, self.f["t"], self.f["ankare"], 1.0)}
        pb = KS.planet(self.bana, self.f["t"], self.f["ankare"], 1.0)
        self.assertGreater(len(pb), 10)
        fel = [abs(p["grader"] - ps[p["t"]]) for p in pb]
        print(f"\nS7b planet: {len(pb)} rutor P5–P7, felet median {np.median(fel):.2f}°, max {max(fel):.2f}°")
        self.assertLessEqual(max(fel), PLAN_MAX)
        # Utan P5 inget plan.
        self.assertEqual(KS.planet(self.bana, self.f["t"], [a for a in self.f["ankare"] if a["position"] != "P5"], 1.0), [])

    def test_fixturen_ar_aktuell(self) -> None:
        """Swift räknar samma bana ur samma film; fixturen ska vara Pythons nuvarande tal."""
        d = json.loads(KF.FIXTUR.read_text(encoding="utf-8"))
        self.assertEqual(d["summa"], [KF.summa(r) for r in self.f["rutor"]])
        self.assertEqual(len(d["bana"]), len(self.bana))
        for a, b in zip(d["bana"], self.bana):
            self.assertEqual(a is None, b is None)
            if a is not None:
                self.assertEqual(a["kalla"], b["kalla"])
                self.assertAlmostEqual(a["x"], b["x"], places=9)
                self.assertAlmostEqual(a["y"], b["y"], places=9)
        self.assertEqual(len(d["planet"]), len(KS.planet(self.bana, self.f["t"], self.f["ankare"], 1.0)))
        for namn, bana in d["glesa"].items():
            a = [x for x in self.f["ankare"] if x["position"] in namn.split(",")]
            ny = KS.spara(self.f["t"], self.f["rutor"], self.f["leder"], a, KF.SKALA, KF.BREDD, KF.HOJD)
            self.assertEqual([None if x is None else x["kalla"] for x in bana],
                             [None if x is None else x["kalla"] for x in ny], namn)


class Varianter(unittest.TestCase):
    """Filmen med det som riktiga klipp har (METOD M61): bakifrån, oskärpa, låg kontrast (med
    och utan brus), textur och skak, en boll, en skugga och huvudets mitt bredvid hoseln.
    Genereras här och checkas inte in. Ingen variant får grova fel bland de spårade rutorna."""

    def test_varianterna(self) -> None:
        for v in KF.VARIANTER:
            with self.subTest(v):
                f = KF.film(v)
                m = matt(f, KS.spara(f["t"], f["rutor"], f["leder"], f["ankare"], KF.SKALA, KF.BREDD, KF.HOJD))
                sp, ip = m["spar"], m["interpolerad"]
                print(f"\nS7b {v}: {len(sp)} spårade (median {np.median(sp):.2f} px, p95 {np.percentile(sp, 95):.2f}, "
                      f"max {max(sp):.1f}), {len(ip)} interpolerade ({m['andel']:.0%}, max {max(ip):.1f} px)")
                self.assertEqual(m["n"], len(f["t"]) - f["t"].index(f["ankare"][0]["t"])
                                 - (len(f["t"]) - 1 - f["t"].index(f["ankare"][-1]["t"])))
                self.assertLessEqual(np.median(sp), SPAR_MEDIAN * KF.SKAFT)
                self.assertLessEqual(np.percentile(sp, 95), SPAR_P95 * KF.SKAFT)
                self.assertLessEqual(sum(e > GROVT * KF.SKAFT for e in sp), GROVA_MAX * len(sp))
                tak = VARIANT_TAK[v]
                if tak is not None:
                    self.assertLessEqual(m["andel"], tak[0])
                    self.assertLessEqual(max(ip), tak[1] * KF.SKAFT)


class Delar(unittest.TestCase):
    def test_utan_ankare_ingen_bana(self) -> None:
        f = {"t": [0.0, 0.01], "rutor": [np.zeros((4, 4), np.uint8)] * 2, "leder": [[None] * 13] * 2}
        self.assertEqual(KS.spara(f["t"], f["rutor"], f["leder"], [], 1.0), [None, None])

    def test_hashen_som_swift(self) -> None:
        """Samma heltal ur numpy och ur Python-heltal (Swift räknar som det senare)."""
        x, y = np.array([0, 1, 299, 5], dtype=np.uint32), np.array([0, 2, 279, 77], dtype=np.uint32)
        for k in (0, 4, 348):
            self.assertEqual([int(v) for v in KF.hash32(x, y, k)], [KF.hash32(int(a), int(b), k) for a, b in zip(x, y)])

    def test_formatets_version_3(self) -> None:
        """Banans rutor i `swinglab-klubba/3` (BESLUT B71): godkända av kontrollen, aldrig
        markeringar, och en rättad ruta kräver klick och maskinens punkt i förslaget."""
        def ruta(id_, val, status="markerad", kh=None, **extra):
            return {"id": id_, "fil": "f.zip", "vy": "dtl", "slag": "s01", "val": val, "t": -0.1, "t_klipp": None,
                    "forskjutning_ms": None, "t_ruta": None, "bredd": 1080, "hojd": 1920, "visad": [0, 0, 1080, 1920],
                    "status": status, "punkter": {"grepp": None, "skaft_mitt": None, "klubbhuvud": kh},
                    "forslag": {}, **extra}
        d = {"format": K.FORMAT_3, "pass": "20261103-180000", "kalla": ["f.zip"], "punkter": list(K.PUNKTER),
             "andrad": "2026-11-03T21:15:00+01:00",
             "rutor": [ruta("a", "bana", kh={"x": 10.0, "y": 20.0, "kalla": "spar"}, granskning=None),
                       ruta("b", "bana", kh={"x": 11.0, "y": 21.0, "kalla": "interpolerad"}, granskning="godkand")]}
        self.assertEqual(K.kontrollera(d), [])
        self.assertEqual(K.markeringar(d), {})
        self.assertEqual([b["kalla"] for b in K.bana(d)["s01"]], ["spar", "interpolerad"])
        r = ruta("c", "bana", kh={"x": 12.0, "y": 22.0, "kalla": "klick"}, granskning="rattad")
        self.assertTrue(K.kontrollera({**d, "rutor": [r]}))          # förslaget saknas
        r["forslag"] = {"klubbhuvud": {"x": 13.0, "y": 23.0, "kalla": "spar"}}
        self.assertEqual(K.kontrollera({**d, "rutor": [r]}), [])
        # Version 2 känner inte banan.
        self.assertTrue(K.kontrollera({**d, "format": K.FORMAT}))
        self.assertTrue(K.kontrollera({**d, "rutor": [ruta("e", "bana", kh={"x": 1.0, "y": 2.0, "kalla": "klick"})]}))


if __name__ == "__main__":
    unittest.main()
