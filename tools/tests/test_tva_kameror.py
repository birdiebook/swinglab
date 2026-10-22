"""S6a: två paket från samma pass → 3D utan markörer (tools/pc/tva_kameror.py).

Facit: påhittade 3D-svingar (tre_d/sving.py), filmade av en FO- och en DTL-kamera
med felbudgetens brus (generera_paket.tva_paket). Passets median ska ligga inom
felbudgetens gräns mot sanningen (docs/S6_FELBUDGET.md §6.7, METOD MK8). Inga
riktiga leder (CLAUDE.md, Dataregeln).
"""
from __future__ import annotations

import functools
import io
import json
import sys
import tempfile
import unittest
import zipfile
from contextlib import redirect_stdout
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from pc import analys as A  # noqa: E402
from pc import generera_paket as G  # noqa: E402
from pc import historik as H  # noqa: E402
from pc import katalog as KAT  # noqa: E402
from pc import paket as P  # noqa: E402
from pc import session as S  # noqa: E402
from pc import tva_kameror as TK  # noqa: E402

PASS = "20261103-180000"
TMP = tempfile.TemporaryDirectory()

# Felbudgetens passmedian (10 slag): bias och SD i grader, S6_FELBUDGET.md §6.7,
# raderna "Grund (typiskt brus)" och "Bra brus". Gränsen är |bias| + 3 SD. METOD MK8
FELBUDGET = {
    "bra": {"backen_vrid_topp": (1.7, 5.6), "brost_vrid_topp": (1.2, 4.0), "xfaktor_topp": (-0.8, 7.4),
            "xfaktor_stretch": (3.3, 3.7), "hofter_oppna_traff": (-0.7, 5.5)},
    "typiskt": {"backen_vrid_topp": (1.3, 10.0), "brost_vrid_topp": (1.8, 8.4), "xfaktor_topp": (0.7, 12.9),
                "xfaktor_stretch": (9.5, 6.9), "hofter_oppna_traff": (0.5, 11.7)},
}
GRANS = {b: {m: abs(bias) + 3 * sd for m, (bias, sd) in d.items()} for b, d in FELBUDGET.items()}


@functools.lru_cache(maxsize=None)
def _pass(brus: str, seed: int, n: int = 10, par_json: bool = True, lodlinje: bool = False,
          hand: str = "hoger", bara_fo: int = 1):
    ut = Path(TMP.name) / f"{brus}-{seed}-{n}-{par_json}-{lodlinje}-{hand}-{bara_fo}"
    d, f, facit = G.tva_paket(ut, PASS, n=n, seed=seed, brus=brus, par_json=par_json, lodlinje=lodlinje,
                              hand=hand, bara_fo=bara_fo)
    return d, f, facit


@functools.lru_cache(maxsize=None)
def _resultat(brus: str, seed: int, **kw):
    d, f, facit = _pass(brus, seed, **kw)
    pd, pf = P.las(d), P.las(f)
    r = TK.analysera(pd, pf, A.mat_paket(pd, 1.80) + A.mat_paket(pf, 1.80))
    return r, facit


def _fel(r: dict, facit: dict) -> tuple[dict, dict]:
    """Per slag (skattat − sant) och passets median − de sannas median."""
    sant = {(x["dtl"], x["fo"]): x["sant"] for x in facit["slag"]}
    per_slag = {m: [s["matt"][m] - sant[(s["dtl"], s["fo"])][m] for s in r["slag"] if m in s.get("matt", {})]
                for m in TK.MATT}
    median = {m: r["session"][m]["median"] - facit["median"][m] for m in TK.MATT}
    return per_slag, median


def _skriv_om(zip_in: Path, zip_ut: Path, filer: dict) -> Path:
    """En kopia av paketet där `filer` (namn → text, None = ta bort) är utbytta."""
    with zipfile.ZipFile(zip_in) as zi, zipfile.ZipFile(zip_ut, "w", zipfile.ZIP_STORED) as zo:
        for namn in zi.namelist():
            if namn in filer:
                continue
            zo.writestr(namn, zi.read(namn))
        for namn, text in filer.items():
            if text is not None:
                zo.writestr(namn, text)
    return zip_ut


class Parningen(unittest.TestCase):
    def setUp(self) -> None:
        self.d, self.f, self.facit = _pass("inget", 3, n=4)
        self.ratt = {(x["dtl"], x["fo"]) for x in self.facit["slag"]}

    def _par(self, d, f):
        par, info = TK.para_slag(P.las(d), P.las(f))
        return {(a.id, b.id) for a, b in par}, info

    def test_par_json_parar_slagen_och_lamnar_fo_s_ensamma_slag(self) -> None:
        par, info = self._par(self.d, self.f)
        self.assertEqual(par, self.ratt)
        self.assertEqual(info["kalla"], "par.json")
        self.assertEqual(info["oparade"], {"dtl": 0, "fo": 1})

    def test_utan_par_json_paras_klicken(self) -> None:
        d, f, facit = _pass("inget", 3, n=4, par_json=False)
        par, info = self._par(d, f)
        self.assertEqual(par, {(x["dtl"], x["fo"]) for x in facit["slag"]})
        self.assertEqual(info["kalla"], "klicken")

    def test_osaker_par_json_paras_om_pa_klicken(self) -> None:
        with zipfile.ZipFile(self.d) as z:
            pj = json.loads(z.read("par.json"))
        pj["serier"][0]["osaker"] = True
        pj["serier"][0]["forskjutning_s"] += 3.0
        d = _skriv_om(self.d, Path(TMP.name) / "osaker-dtl.zip", {"par.json": json.dumps(pj)})
        par, info = self._par(d, self.f)
        self.assertEqual(par, self.ratt)
        self.assertEqual(info["serier"][0]["kalla"], "klicken")

    def test_par_json_for_ett_annat_pass_galler_inte(self) -> None:
        with zipfile.ZipFile(self.d) as z:
            pj = json.loads(z.read("par.json"))
        pj["serier"][0]["foljare"]["pass"] = "20261103-170000"
        d = _skriv_om(self.d, Path(TMP.name) / "annat-pass-dtl.zip", {"par.json": json.dumps(pj)})
        par, info = self._par(d, self.f)
        self.assertEqual(par, self.ratt)                  # klicken parar ändå
        self.assertEqual(info["serier"][0]["kalla"], "klicken")

    def test_trasig_par_json_stoppar_inte_paketet(self) -> None:
        d = _skriv_om(self.d, Path(TMP.name) / "trasig-dtl.zip", {"par.json": '{"format": "swinglab-par/1"'})
        p = P.las(d)
        self.assertIsNone(p.par)
        self.assertIn("par.json", p.par_fel)
        par, info = TK.para_slag(p, P.las(self.f))
        self.assertEqual({(a.id, b.id) for a, b in par}, self.ratt)
        self.assertIn("par_json_fel", info)

    def test_para_utan_prior_hittar_forskjutning_langre_an_sokningen(self) -> None:
        a = [10.0, 17.4, 25.1, 31.9, 40.2]
        b = [x + 37.2 + e for x, e in zip(a, (0.004, -0.003, 0.0, 0.006, -0.002))]
        r = TK.para_utan_prior(a, b)
        self.assertFalse(r["osaker"])
        self.assertEqual(len(r["par"]), 5)
        self.assertAlmostEqual(r["forskjutning"], 37.2, delta=0.005)
        self.assertTrue(TK.para_utan_prior(a[:2], b[:2])["osaker"])


class Lodlinjen(unittest.TestCase):
    def test_lodlinjen_las_och_felet_namner_faltet_utan_varde(self) -> None:
        d, f, _ = _pass("inget", 3, n=4, lodlinje=True)
        p = P.las(f)
        v = np.array(p.serier[1].lodlinje)
        self.assertAlmostEqual(float(np.linalg.norm(v)), 1.0, places=3)
        with zipfile.ZipFile(f) as z:
            m = json.loads(z.read("manifest.json"))
        m["serier"][0]["lodlinje"] = [0.0, -3.217, 0.0]
        fel = _skriv_om(f, Path(TMP.name) / "lod-fo.zip", {"manifest.json": json.dumps(m)})
        with self.assertRaises(P.PaketFel) as e:
            P.las(fel)
        self.assertIn("serier[0].lodlinje", str(e.exception))
        self.assertNotIn("3.217", str(e.exception))


class Facit(unittest.TestCase):
    """Passets median mot sanningen. Felbudgeten: §6.7 (METOD MK8)."""

    def test_utan_brus_ar_kedjan_exakt(self) -> None:
        r, facit = _resultat("inget", 5)
        per_slag, median = _fel(r, facit)
        self.assertEqual(r["parning"]["par"], 10)
        for m in TK.MATT:
            self.assertEqual(len(per_slag[m]), 10, m)
            self.assertLess(max(abs(x) for x in per_slag[m]), 1.0, m)
            self.assertLess(abs(median[m]), 0.5, m)
        sant = {(x["dtl"], x["fo"]): x["synk_ms"] for x in facit["slag"]}
        rest = [s["synk_ms"] - sant[(s["dtl"], s["fo"])] for s in r["slag"]]
        self.assertLess(max(abs(x) for x in rest), 1.0)        # klicket ±7 ms → under 1 ms
        self.assertEqual(r["kalibrering"]["lodlinje"], "kamerornas_vagrata")
        self.assertAlmostEqual(r["kalibrering"]["vinkel_mellan_kamerorna"], facit["vinkel_mellan_kamerorna"],
                               delta=1.0)
        self.assertEqual(r["lage"], "utan_markorer")

    def test_vanster_med_lodlinje_och_utan_par_json(self) -> None:
        r, facit = _resultat("inget", 6, par_json=False, lodlinje=True, hand="vanster")
        _, median = _fel(r, facit)
        self.assertEqual(r["kalibrering"]["lodlinje"], "manifest")
        self.assertEqual(r["parning"]["kalla"], "klicken")
        for m in TK.MATT:
            self.assertLess(abs(median[m]), 0.5, m)

    def _inom_felbudgeten(self, brus: str, frön: tuple[int, ...]) -> None:
        for seed in frön:
            r, facit = _resultat(brus, seed)
            _, median = _fel(r, facit)
            for m in TK.MATT:
                self.assertLessEqual(abs(median[m]), GRANS[brus][m], f"{brus}, frö {seed}, {m}")

    def test_bra_brus_passets_median_inom_felbudgeten(self) -> None:
        self._inom_felbudgeten("bra", (11, 13))

    def test_typiskt_brus_passets_median_inom_felbudgeten(self) -> None:
        self._inom_felbudgeten("typiskt", (21, 22))


class Analysen(unittest.TestCase):
    """session.py med två paket: 3D i analys.json, trenden mot förra passet och i minnet."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.rot = Path(TMP.name) / "historik"
        cls.paket = {}
        for pass_id, seed, n in (("20261103-180000", 31, 11), ("20261106-180000", 32, 11)):
            ut = Path(TMP.name) / f"analys-{pass_id}"
            d, f, _ = G.tva_paket(ut, pass_id, n=n, seed=seed, brus="bra")
            cls.paket[pass_id] = (d, f)
            with redirect_stdout(io.StringIO()):
                assert S.main([str(d), str(f), "--historik", str(cls.rot), "--utan-kontaktark"]) == 0
        cls.a1 = H.las_analys(cls.rot, "20261103-180000")
        cls.a2 = H.las_analys(cls.rot, "20261106-180000")

    def test_trenden_star_i_analysen_med_katalogens_matt(self) -> None:
        t = self.a1["tre_d"]
        self.assertEqual([x["matt"] for x in t["trend"]], [e["matt"] for e in KAT.las_3d()["matt"]])
        for x in t["trend"]:
            self.assertEqual(x["lage"], "utan_markorer")
            self.assertEqual(x["n"], 11)
            self.assertIsNotNone(x["median"])
            self.assertIsNone(x["mot_forra"])
        self.assertEqual(len(t["slag"]), 11)

    def test_andra_passet_jamfors_med_forra(self) -> None:
        t = self.a2["tre_d"]
        self.assertEqual(t["mot_forra"]["pass"], "20261103-180000")
        for x in t["trend"]:
            self.assertEqual(set(x["mot_forra"]), {"skillnad", "tydlig"})
            j = t["mot_forra"]["jamforelse"][x["matt"]]
            self.assertEqual(j["tydlig"], abs(j["skillnad"]) > max(j["spridning"], TK.TREND_GOLV[x["matt"]]))
            v1 = next(y for y in self.a1["tre_d"]["trend"] if y["matt"] == x["matt"])["median"]
            self.assertAlmostEqual(x["mot_forra"]["skillnad"], x["median"] - v1, delta=0.11)

    def test_minnet_bar_trenden(self) -> None:
        m = H.minne(self.rot)
        self.assertEqual(set(m["tre_d"]), set(TK.MATT))
        self.assertEqual([x["pass"] for x in m["tre_d"]["xfaktor_stretch"]], ["20261103-180000", "20261106-180000"])

    def test_farre_an_tio_slag_ger_ingen_median(self) -> None:
        d, f, _ = _pass("inget", 7, n=6)
        pd, pf = P.las(d), P.las(f)
        a = A.analysera([pd, pf], 1.80, [], skapad="")
        t = a["tre_d"]
        self.assertEqual(t["session"], {})
        self.assertTrue(all(x["median"] is None and x["n"] == 6 for x in t["trend"]))

    def test_ett_paket_hoppar_over_3d_men_inte_2d(self) -> None:
        d, _ = self.paket["20261103-180000"]
        a = A.analysera([P.las(d)], 1.80, [], skapad="")
        self.assertIn("hoppat", a["tre_d"])
        self.assertTrue(any("matt" in r for r in a["slag"]))

    def test_analysen_ar_giltig_json_utan_nan(self) -> None:
        text = (self.rot / "pass" / "20261103-180000" / "analys.json").read_text(encoding="utf-8")
        self.assertNotIn("NaN", text)
        json.loads(text)


class Katalogen(unittest.TestCase):
    def test_katalog_3d_ar_hel(self) -> None:
        k = KAT.las_3d()
        self.assertEqual({e["matt"] for e in k["matt"]}, set(TK.MATT))
        self.assertTrue(all(e["lage"] == "utan_markorer" and e["min_slag"] == TK.MIN_SLAG for e in k["matt"]))

    def test_kontrollen_faller_fel(self) -> None:
        k = KAT.las_3d()
        k["matt"][0]["lage"] = "ibland"
        k["matt"][1]["matt"] = "backen_vrid_topp"
        del k["matt"][2]["spann"]
        fel = "; ".join(KAT.kontrollera_3d(k))
        for ord_ in ("lage", "två gånger", "fälten", "saknar"):
            self.assertIn(ord_, fel)


if __name__ == "__main__":
    unittest.main()
