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
def _pass(brus: str, seed: int, n: int = 10, **kw):
    ut = Path(TMP.name) / f"{brus}-{seed}-{n}-{'-'.join(f'{k}{v}' for k, v in sorted(kw.items()))}"
    return G.tva_paket(ut, PASS, n=n, seed=seed, brus=brus, **kw)


ANALYSPASS = (("20261103-180000", 31), ("20261106-180000", 32))


@functools.lru_cache(maxsize=None)
def _analyspass():
    """Två pass med bra brus genom session.py till en historik: analyserna och facit."""
    rot = Path(TMP.name) / "historik"
    ut = {}
    for pass_id, seed in ANALYSPASS:
        d, f, facit = G.tva_paket(Path(TMP.name) / f"analys-{pass_id}", pass_id, n=11, seed=seed, brus="bra")
        with redirect_stdout(io.StringIO()):
            assert S.main([str(d), str(f), "--historik", str(rot), "--utan-kontaktark"]) == 0
        ut[pass_id] = (d, f, facit, H.las_analys(rot, pass_id))
    return rot, ut


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
    median = {m: r["session"][m]["median"] - facit["median"][m] for m in TK.MATT if m in r["session"]}
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

    def test_fo_som_styrande(self) -> None:
        d, f, facit = _pass("inget", 3, n=4, styr="fo")
        par, info = self._par(d, f)
        self.assertEqual(par, {(x["dtl"], x["fo"]) for x in facit["slag"]})
        self.assertEqual(info["kalla"], "par.json")
        self.assertIsNotNone(P.las(f).par)
        self.assertIsNone(P.las(d).par)

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


def _med_lodlinje(zip_in: Path, namn: str, lod) -> Path:
    with zipfile.ZipFile(zip_in) as z:
        m = json.loads(z.read("manifest.json"))
    m["serier"][0]["lodlinje"] = lod(m["serier"][0]["lodlinje"])
    return _skriv_om(zip_in, Path(TMP.name) / namn, {"manifest.json": json.dumps(m)})


class Lodlinjen(unittest.TestCase):
    """Lodlinjen är valfri och mjuk: en trasig eller vänd stoppar aldrig 2D och
    används inte i 3D (METOD MK3, BESLUT B37, B39)."""

    def test_lodlinjen_las(self) -> None:
        _, f, _ = _pass("inget", 3, n=4, lodlinje=True)
        v = np.array(P.las(f).serier[1].lodlinje)
        self.assertAlmostEqual(float(np.linalg.norm(v)), 1.0, places=3)

    def test_trasig_lodlinje_ger_skalet_utan_varde_och_2d_gar(self) -> None:
        d, f, _ = _pass("inget", 3, n=4, lodlinje=True)
        fel = _med_lodlinje(f, "lod-fo.zip", lambda v: [0.0, -3.217, 0.0])
        p = P.las(fel)                                           # paketet går att läsa
        self.assertIsNone(p.serier[1].lodlinje)
        self.assertIn("lodlinje", p.serier[1].lodlinje_fel)
        self.assertNotIn("3.217", p.serier[1].lodlinje_fel)
        a = A.analysera([P.las(d), p], 1.80, [], skapad="")
        self.assertTrue(any("matt" in r for r in a["slag"] if r["vy"] == "fo"))
        k = a["tre_d"]["kalibrering"][0]
        self.assertIn("lodlinje", k["lodlinje_fel"][0])
        self.assertTrue(any("lodlinjen" in o for o in a["tre_d"]["osaker"]))

    def test_vand_lodlinje_anvands_inte(self) -> None:
        d, f, facit = _pass("inget", 3, n=4, lodlinje=True)
        vand = {"dtl": _med_lodlinje(d, "vand-dtl.zip", lambda v: [-x for x in v]),
                "fo": _med_lodlinje(f, "vand-fo.zip", lambda v: [-x for x in v])}
        pd, pf = P.las(vand["dtl"]), P.las(vand["fo"])
        self.assertIn("överkant", pf.serier[1].lodlinje_fel)
        r = TK.analysera(pd, pf, A.mat_paket(pd, 1.80) + A.mat_paket(pf, 1.80))
        self.assertEqual(r["kalibrering"][0]["lodlinje"], "kamerornas_vagrata")
        per_slag, _ = _fel(r, facit)
        for m in TK.MATT:                                     # tecknet vänds inte
            self.assertLess(max(abs(x) for x in per_slag[m]), 1.0, m)

    def test_vinkeln_mot_kamerornas_vagrata_skrivs(self) -> None:
        # Mätningen för B39:s omprövning: en riktig lodlinje (±1°, kamerorna utan lutning
        # åt sidan) ligger nära de vågräta och används.
        r, _ = _resultat("inget", 3, n=4, lodlinje=True)
        k = r["kalibrering"][0]
        self.assertEqual(k["lodlinje"], "manifest")
        self.assertLess(k["lodlinje_mot_vagrata"], 3.0)
        self.assertNotIn("lodlinje_fel", k)

    def test_lodlinje_langt_fran_vagrata_anvands_inte(self) -> None:
        # Båda telefonernas uppåt vridet 30° kring linsens axel: PC:ns kontroll i paketet
        # tar dem (y < 0), men skyddet i kalibreringen faller tillbaka på de vågräta. METOD MK3
        d, f, facit = _pass("inget", 3, n=4, lodlinje=True)
        a = np.radians(30.0)
        vrid = lambda v: [v[0] * np.cos(a) - v[1] * np.sin(a), v[0] * np.sin(a) + v[1] * np.cos(a), v[2]]  # noqa: E731
        pd, pf = P.las(_med_lodlinje(d, "vrid-dtl.zip", vrid)), P.las(_med_lodlinje(f, "vrid-fo.zip", vrid))
        self.assertIsNotNone(pf.serier[1].lodlinje, "paketets kontroll tar den")
        r = TK.analysera(pd, pf, A.mat_paket(pd, 1.80) + A.mat_paket(pf, 1.80))
        k = r["kalibrering"][0]
        self.assertEqual(k["lodlinje"], "kamerornas_vagrata")
        self.assertGreater(k["lodlinje_mot_vagrata"], TK.LODLINJE_MOT_VAGRATA_MAX)
        self.assertTrue(any("avviker" in x for x in k["lodlinje_fel"]))
        self.assertTrue(any("lodlinjen" in o for o in r["osaker"]))
        per_slag, _ = _fel(r, facit)
        for m in TK.MATT:                                     # som utan fältet: exakt utan brus
            self.assertLess(max(abs(x) for x in per_slag[m]), 1.0, m)


class Brannvidden(unittest.TestCase):
    """f ur seriens synfält, annars enhet.json, annars specifikationen (METOD MK3)."""

    def test_annan_brannvidd_an_specifikationens(self) -> None:
        r, facit = _resultat("inget", 3, n=4, f_px=1444.0 * 1.18)
        self.assertEqual(r["kalibrering"][0]["f_kalla"], {"dtl": "serien", "fo": "serien"})
        per_slag, _ = _fel(r, facit)
        for m in TK.MATT:
            self.assertLess(max(abs(x) for x in per_slag[m]), 1.0, m)

    def test_enhet_json_nar_serien_saknar_synfalt(self) -> None:
        d, f, _ = _pass("inget", 3, n=4, f_px=1700.0, synfalt=False)
        fov = float(np.degrees(2 * np.arctan(960 / 1700.0)))
        enhet = {"modell": "pahittad", "ios": "18.2", "valt_index": 7,
                 "format": [{"index": 3, "width": 1920, "height": 1080, "fieldOfView": 40.0},
                            {"index": 7, "width": 1920, "height": 1080, "fieldOfView": fov}]}
        p = P.las(_skriv_om(f, Path(TMP.name) / "enhet-fo.zip", {"enhet.json": json.dumps(enhet)}))
        K, kalla = TK.K_for(p, p.slag[0])
        self.assertEqual(kalla, "enhet.json")
        self.assertAlmostEqual(K[0, 0], 1700.0, places=3)
        K, kalla = TK.K_for(P.las(d), P.las(d).slag[0])
        self.assertEqual(kalla, "specifikationen")
        self.assertAlmostEqual(K[0, 0], TK.F_PX_1920)


class Sparren(unittest.TestCase):
    """En dålig kalibrering mäts inte, och ett fel i 3D lämnar 2D orört (BESLUT B37)."""

    def test_samre_an_sparren_hoppas_over_och_2d_gar(self) -> None:
        d, f, _ = _pass("mycket_daligt", 3, n=4)
        a = A.analysera([P.las(d), P.las(f)], 1.80, [], skapad="")
        self.assertIn("spärren", a["tre_d"]["hoppat"])
        self.assertTrue(any("matt" in r for r in a["slag"]))

    def test_ovantat_fel_ger_typens_namn(self) -> None:
        d, f, _ = _pass("inget", 3, n=4)
        orig = TK.analysera
        TK.analysera = lambda *a: (_ for _ in ()).throw(RuntimeError("3.217"))
        try:
            a = A.analysera([P.las(d), P.las(f)], 1.80, [], skapad="")
        finally:
            TK.analysera = orig
        self.assertEqual(a["tre_d"], {"hoppat": "3D gick inte (RuntimeError)"})
        self.assertTrue(any("matt" in r for r in a["slag"]))


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
        k = r["kalibrering"][0]
        self.assertEqual(k["lodlinje"], "kamerornas_vagrata")
        self.assertAlmostEqual(k["vinkel_mellan_kamerorna"], facit["vinkel_mellan_kamerorna"], delta=1.0)
        self.assertEqual(r["lage"], "utan_markorer")
        self.assertEqual(r["osaker"], [])

    def test_vanster_med_lodlinje_och_utan_par_json(self) -> None:
        # Vänsterspelaren filmas med uppställningen spegelvänd: DTL bakom spelaren.
        r, facit = _resultat("inget", 6, par_json=False, lodlinje=True, hand="vanster")
        _, median = _fel(r, facit)
        self.assertEqual(r["kalibrering"][0]["lodlinje"], "manifest")
        self.assertEqual(r["parning"]["kalla"], "klicken")
        for m in TK.MATT:
            self.assertLess(abs(median[m]), 0.5, m)

    def _inom(self, brus: str, namn: str, t: dict, facit: dict) -> None:
        for m in TK.MATT:
            fel = t["session"][m]["median"] - facit["median"][m]
            self.assertLessEqual(abs(fel), GRANS[brus][m], f"{brus}, {namn}, {m}")

    def test_bra_brus_passets_median_inom_felbudgeten(self) -> None:
        for pass_id, (_, _, facit, a) in _analyspass()[1].items():     # Analysens två pass
            self._inom("bra", pass_id, a["tre_d"], facit)

    def test_typiskt_brus_passets_median_inom_felbudgeten(self) -> None:
        r, facit = _resultat("typiskt", 21)
        self._inom("typiskt", "frö 21", r, facit)


class Analysen(unittest.TestCase):
    """session.py med två paket: 3D i analys.json, trenden mot förra passet och i minnet."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.rot, p = _analyspass()
        cls.paket = {k: v[:2] for k, v in p.items()}
        cls.a1 = p["20261103-180000"][3]
        cls.a2 = p["20261106-180000"][3]

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
        d, f, _ = _pass("inget", 3, n=4)
        pd, pf = P.las(d), P.las(f)
        a = A.analysera([pd, pf], 1.80, [], skapad="")
        t = a["tre_d"]
        self.assertEqual(t["session"], {})
        self.assertTrue(all(x["median"] is None and x["n"] == 4 for x in t["trend"]))

    def test_ett_paket_hoppar_over_3d_men_inte_2d(self) -> None:
        d, _ = self.paket["20261103-180000"]
        a = A.analysera([P.las(d)], 1.80, [], skapad="")
        self.assertIn("hoppat", a["tre_d"])
        self.assertTrue(any("matt" in r for r in a["slag"]))

    def test_analysen_ar_giltig_json_utan_nan(self) -> None:
        text = (self.rot / "pass" / "20261103-180000" / "analys.json").read_text(encoding="utf-8")
        self.assertNotIn("NaN", text)
        json.loads(text)


def _telefonens_fil(t: dict, pass_id: str) -> dict:
    """tre_d.json som telefonen skriver den (BESLUT B61): bara kedjans fält, utan trenden."""
    falt = ("lage", "min_slag", "matt", "parning", "kalibrering", "osaker", "slag", "utelamnade", "n", "session")
    return {"format": "swinglab-tre-d/1", "pass": pass_id, "raknad": "2026-11-03T18:30:00Z", "raknad_av": "dtl",
            "kallor": {"dtl": "0-1", "fo": "0-2"}, "sekunder": 1.2,
            "tre_d": json.loads(json.dumps({k: t[k] for k in falt}))}


class Telefonen(unittest.TestCase):
    """S6c-2: telefonens tre_d.json i paketet mot PC:ns 3D (BESLUT B61, METOD MS19)."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.rot, p = _analyspass()
        cls.d, cls.f, _, cls.a = p["20261103-180000"]

    def test_samma_tal_ar_lika(self) -> None:
        j = TK.jamfor_telefon(self.a["tre_d"], _telefonens_fil(self.a["tre_d"], "20261103-180000"))
        self.assertTrue(j["inom"], j)
        self.assertEqual(j["olika"], [])
        self.assertEqual(j["storsta_skillnad"], 0.0)

    def test_skillnaderna_skrivs(self) -> None:
        fil = _telefonens_fil(self.a["tre_d"], "20261103-180000")
        s = next(x for x in fil["tre_d"]["slag"] if "matt" in x)
        s["matt"]["xfaktor_stretch"] += 0.1
        fil["tre_d"]["osaker"] = ["serie 1 (DTL) mot 1 (FO): lodlinjen i manifestet användes inte"]
        fil["tre_d"]["kalibrering"][0]["sampson_px"] += 0.01
        j = TK.jamfor_telefon(self.a["tre_d"], fil)
        self.assertFalse(j["inom"])
        self.assertIn("osaker", j["olika"])
        # Ett avrundat tal: skillnaden skrivs (granskningen av S6c-2).
        a = next(x for x in j["avrundade"] if x["falt"] == "kalibrering[0].sampson_px")
        self.assertAlmostEqual(a["skillnad"], 0.01, places=6)
        self.assertNotIn("kalibrering[0].sampson_px", j["olika"])
        self.assertEqual([(x["dtl"], x["matt"]) for x in j["per_slag"]], [(s["dtl"], "xfaktor_stretch")])
        self.assertAlmostEqual(j["storsta_skillnad"], 0.1, places=9)
        # Under gränsen: lika.
        fil = _telefonens_fil(self.a["tre_d"], "20261103-180000")
        fil["tre_d"]["slag"][0]["matt"]["backen_vrid_topp"] += 0.04
        self.assertTrue(TK.jamfor_telefon(self.a["tre_d"], fil)["inom"])

    def test_mått_bara_telefonen_har_och_marginalerna(self) -> None:
        fil = _telefonens_fil(self.a["tre_d"], "20261103-180000")
        s = next(x for x in fil["tre_d"]["slag"] if "matt" in x)
        s["matt"]["nytt_matt"] = 1.0
        fil["inre"] = [{"R": [], "t": [], "upp": [], "forsk": [0.0012, -0.0004], "aterprojektion": [1.2, None],
                        "sampson_px": 7.5, "vinkel": 118.0, "lodlinje_mot_vagrata": 3.0}, None]
        j = TK.jamfor_telefon(self.a["tre_d"], fil)
        self.assertFalse(j["inom"])
        self.assertEqual(j["bara_telefonen"], [{"dtl": s["dtl"], "fo": s["fo"], "matt": "nytt_matt"}])
        m = j["marginaler"][0]
        self.assertAlmostEqual(m["sampson_mot_sparren_px"], 0.5)
        self.assertAlmostEqual(m["vinkel_mot_granserna"], 2.0)
        self.assertAlmostEqual(m["lodlinje_mot_skyddet"], 12.0)
        self.assertEqual([round(x, 6) for x in m["synk_ms"]], [1.2, -0.4])
        self.assertIsNone(j["marginaler"][1])

    def test_hoppat_jamfors_pa_skalet(self) -> None:
        fil = {"format": "swinglab-tre-d/1", "pass": "x", "hoppat": "kalibreringen: ingen serie gick att kalibrera under spärren"}
        j = TK.jamfor_telefon({"hoppat": fil["hoppat"]}, fil)
        self.assertTrue(j["inom"])
        self.assertFalse(TK.jamfor_telefon(self.a["tre_d"], fil)["inom"])

    def _med_fil(self, fil: dict, namn: str) -> Path:
        ut = Path(TMP.name) / f"telefon-{namn}" / Path(self.d).name
        ut.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(self.d) as a, zipfile.ZipFile(ut, "w", zipfile.ZIP_STORED) as b:
            for i in a.infolist():
                b.writestr(i, a.read(i.filename))
            b.writestr("tre_d.json", json.dumps(fil))
        return ut

    def test_session_skriver_skillnaden(self) -> None:
        """Paketet bär telefonens tre_d.json: session.py skriver tre_d.telefon och en rad."""
        d = self._med_fil(_telefonens_fil(self.a["tre_d"], "20261103-180000"), "lika")
        self.assertEqual(P.las(d).tre_d["format"], "swinglab-tre-d/1")
        ut = Path(TMP.name) / "telefon-lika-ut"
        buf = io.StringIO()
        with redirect_stdout(buf):
            self.assertEqual(S.main([str(d), str(self.f), "--ut", str(ut), "--langd", "1.8", "--utan-kontaktark"]), 0)
        t = json.loads((ut / "analys.json").read_text(encoding="utf-8"))["tre_d"]
        self.assertEqual(t["telefon"]["paket"], d.name)
        self.assertTrue(t["telefon"]["inom"], t["telefon"])
        self.assertIn("3D på telefonen", buf.getvalue())

    def test_den_raknande_telefonens_paket_tas(self) -> None:
        """Båda paketen bär en fil: den vars vy räknade (raknad_av) jämförs."""
        fil = _telefonens_fil(self.a["tre_d"], "20261103-180000")
        fil["raknad_av"] = "fo"
        pd, pf = P.las(self.d), P.las(self.f)
        pd.tre_d = dict(fil, raknad_av="fo")
        pf.tre_d = fil
        a = A.analysera([pd, pf], 1.80, [], skapad="")
        self.assertEqual(a["tre_d"]["telefon"]["paket"], pf.fil)

    def test_trasig_fil_stoppar_inget(self) -> None:
        d = self._med_fil({"format": "swinglab-tre-d/1", "pass": "20261103-999999", "hoppat": "x"}, "trasig")
        p = P.las(d)
        self.assertIsNone(p.tre_d)
        self.assertEqual(p.tre_d_fel, "tre_d.json: pass ska vara paketets")
        a = A.analysera([p, P.las(self.f)], 1.80, [], skapad="")
        self.assertEqual(a["tre_d"]["telefon"], {"paket": p.fil, "fel": p.tre_d_fel})
        self.assertIn("session", a["tre_d"])


class Katalogen(unittest.TestCase):
    def test_katalogens_3d_ar_hel(self) -> None:
        """3D-måtten står i katalog.json (BESLUT B62), i analysens ordning, med infobladet."""
        k = KAT.las_3d()
        self.assertEqual([e["matt"] for e in k["matt"]], list(TK.MATT))
        self.assertTrue(all(e["lage"] == "utan_markorer" and e["min_slag"] == TK.MIN_SLAG for e in k["matt"]))
        self.assertTrue(all(e[f].strip() for e in k["matt"] for f in ("vad", "varfor", "tecken")))
        self.assertFalse((Path(__file__).resolve().parents[2] / "katalog_3d.json").exists())

    def test_kontrollen_faller_fel(self) -> None:
        k = KAT.las()
        k["tre_d"][0]["lage"] = "ibland"
        k["tre_d"][1]["matt"] = "backen_vrid_topp"
        del k["tre_d"][2]["spann"]
        k["tre_d"][3]["vad"] = " "
        fel = "; ".join(KAT.kontrollera(k))
        for ord_ in ("lage", "två gånger", "fälten", "saknar", "vad ska vara en text"):
            self.assertIn(ord_, fel)
        del k["tre_d"]
        self.assertIn("katalogen: listan tre_d saknas", KAT.kontrollera(k))


if __name__ == "__main__":
    unittest.main()
