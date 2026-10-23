"""Utjämningen och faserna (METOD M3, M4) på ojämna tider."""
from __future__ import annotations

import json
import math
import unittest

import numpy as np

from _hjalp import fm, gen, M
from pc import faser as F


def _ojamna(n: int = 600, seed: int = 0) -> np.ndarray:
    rng = np.random.default_rng(seed)
    t = np.arange(n) / 240.0
    return t[rng.random(n) >= 0.36]


class Utjamning(unittest.TestCase):
    def test_konstant_och_linjar_bevaras_pa_ojamna_tider(self) -> None:
        t = _ojamna()
        y = np.stack([np.full_like(t, 7.0), 3.0 * t + 1.0], -1)
        j = F.jamna(t, y)
        np.testing.assert_allclose(j[:, 0], 7.0)
        mitt = (t > 0.1) & (t < t[-1] - 0.1)                   # kanterna är ensidiga
        # Luckorna gör vikterna osymmetriska: en linje förskjuts högst ~5 ms (uppmätt 4 ms).
        np.testing.assert_allclose(j[mitt, 1], 3.0 * t[mitt] + 1.0, atol=3.0 * 0.005)

    def test_utjamningen_fyller_inga_luckor(self) -> None:
        t = np.arange(200) / 240.0
        y = np.ones((200, 1))
        y[50:52] = np.nan
        j = F.jamna(t, y)
        self.assertTrue(np.isnan(j[50:52]).all())               # saknad förblir saknad
        self.assertTrue(np.isfinite(j[:50]).all() and np.isfinite(j[52:]).all())

    def test_luckans_langd_ar_den_raa(self) -> None:
        """vid() spärrar på den råa luckan: 0,096 s interpoleras, 0,104 s inte."""
        t = np.arange(300) / 240.0
        p = np.stack([t, t], -1)
        for saknas, ok in ((22, True), (24, False)):            # (saknas + 1)/240 s mellan rutorna
            q = p.copy()
            q[100:100 + saknas] = np.nan
            v = F.vid(t, F.jamna(t, q), t[100 + saknas // 2])
            self.assertEqual(bool(np.isfinite(v).all()), ok, saknas)

    def test_vid_interpolerar_och_vagrar_over_lucka(self) -> None:
        t = np.array([0.0, 0.1, 0.2, 0.5])
        p = np.array([[0.0, 0.0], [1.0, 2.0], [np.nan, np.nan], [4.0, 8.0]])
        np.testing.assert_allclose(F.vid(t, p, 0.05), [0.5, 1.0])
        np.testing.assert_allclose(F.vid(t, p, 0.1), [1.0, 2.0])
        self.assertTrue(np.isnan(F.vid(t, p, 0.3)).all())        # 0,1 → 0,5 är längre än MAX_LUCKA_S
        self.assertTrue(np.isnan(F.vid(t, p, 0.6)).all())        # utanför serien

    def test_toppunkten_pa_ojamna_steg(self) -> None:
        f = lambda x: (x - 0.123) ** 2  # noqa: E731
        self.assertAlmostEqual(F.toppunkt(0.10, f(0.10), 0.12, f(0.12), 0.17, f(0.17)), 0.123, places=12)
        self.assertEqual(F.toppunkt(0.0, 1.0, 1.0, 0.0, 2.0, -1.0), 1.0)   # rak linje: ingen topp


class Faserna(unittest.TestCase):
    def _hander(self, t: np.ndarray, vy: str = "fo") -> np.ndarray:
        figur = gen.figur_fo if vy == "fo" else gen.figur_dtl
        L = figur(t, dict(gen.FO if vy == "fo" else gen.DTL), 180.0)
        g = gen._hander(L)
        return np.stack([g[:, 0] * gen.K_PX, -g[:, 1] * gen.K_PX], -1)   # px, y nedåt

    def test_definitionen_pa_tata_exakta_rutor(self) -> None:
        """Utan utjämning och med täta rutor ger definitionen figurens tider."""
        t = np.arange(0, 3.8, 0.0005)
        for vy, figur, p in (("fo", gen.figur_fo, gen.FO), ("dtl", gen.figur_dtl, gen.DTL)):
            f = F.hitta_faser(t, self._hander(t, vy), gen.TIDER["klick"])
            self.assertAlmostEqual(f.topp, gen.TIDER["topp"], delta=0.001)
            self.assertAlmostEqual(f.start, gen.facit_start(figur, dict(p), 180.0), delta=0.0005)
            self.assertEqual(f.traff, gen.TIDER["klick"])
            self.assertAlmostEqual(f.adress[1], f.start - 0.10)
            self.assertEqual(f.finish, (gen.TIDER["klick"] + 1.0, gen.TIDER["klick"] + 1.2))

    def test_utjamningen_flyttar_toppen_tidigare(self) -> None:
        """Nedsvingen är snabbare än baksvingen, så utjämningen drar toppen mot
        baksvingen: uppmätt 7–10 ms (METOD M4). Testet håller måttet på biasen."""
        t = _ojamna(912, seed=4)
        f = F.hitta_faser(t, F.jamna(t, self._hander(t)), gen.TIDER["klick"])
        self.assertLess(f.topp, gen.TIDER["topp"])
        self.assertGreater(f.topp, gen.TIDER["topp"] - 0.012)

    def test_starten_saknas_nar_handerna_inte_ror_sig_forst(self) -> None:
        t = np.arange(0, 3.0, 1 / 240)
        G = np.stack([np.zeros_like(t), 100 - 120 * np.clip(t - 2.0, 0, None)], -1)  # upp på 0,25 s
        G[t > 2.25, 1] = 100.0
        f = F.hitta_faser(t, G, 2.5)
        self.assertIsNone(f.start)                              # baksvingen 0,25 s < MIN_BAKSVING_S
        self.assertAlmostEqual(f.adress[1], f.topp - F.TOPP_ADRESS_S - 0.10)

    def test_utan_hander_gar_svingen_inte_att_mata(self) -> None:
        t = np.arange(0, 3.0, 1 / 240)
        with self.assertRaises(F.SvingFel):
            F.hitta_faser(t, np.full((len(t), 2), np.nan), 2.5)

    def test_greppregeln(self) -> None:
        xy = np.zeros((3, 13, 2))
        xy[:, 5] = [[1, 1], [np.nan, np.nan], [np.nan, np.nan]]
        xy[:, 6] = [[2, 2], [3, 3], [np.nan, np.nan]]
        g = F.grepp_regel(xy)
        np.testing.assert_array_equal(g[1, 5], [3, 3])
        self.assertTrue(np.isnan(g[2, 5:7]).all())
        np.testing.assert_array_equal(g[0, 5:7], [[1, 1], [2, 2]])
        self.assertTrue(math.isnan(xy[1, 5, 0]))                # indata rörs inte


if __name__ == "__main__":
    unittest.main()


TEMPO_GRANS = 0.15     # tempot bakifrån mot det sanna (METOD M40): uppmätt högst 0,14 med 0,8 px brus

# FO:s tal före S1d (Fixturer.swift på main 003f4c0): starten, toppen och tempot. Starten
# bakifrån (METOD M40) får inte röra FO.
FO_LAST = {
    "fo": (1.3700535504485585, 2.190764845115089, 2.65400385985215),
    "fo_vanster": (1.3711832888938646, 2.194963846729204, 2.7005997453161825),
    "fo_luckor": (1.3711914872024167, 2.1912625475052763, 2.6562085476716644),
    "fo_kort_arm": (1.3865977289866698, 2.1885694174131665, 2.5751218193315673),
    "fo_lucka_arm": (1.3717504565248213, 2.1936779375984607, 2.6832134604664026),
    "fo_lucka_fart": (1.3677341218327328, 2.191039459571005, 2.664758860775893),
    "fo_nara_traff": (1.3682827506944757, 2.192639887080475, 5.594167377139506),
}


def _mat_dold(**args) -> tuple[dict, dict]:
    d, facit = gen.sving_dold(**args)
    return M.mat(fm.fran_dict(d)), facit


class StartenBakifran(unittest.TestCase):
    """Bakifrån går takeawayn mot kameran och syns knappt, och står kameran över
    händerna ser de ut att sjunka först (METOD M40). Påhittade 3D-svingar sedda
    bakifrån, mot starten på den verkliga banan (`generera.facit_start_3d`)."""

    def test_dold_takeaway_med_kameran_over_handerna(self) -> None:
        for hojd in (1.0, 1.4, 1.6):
            for baksving in (0.75, 0.95):
                for seed in (1, 2):
                    with self.subTest(hojd=hojd, baksving=baksving, seed=seed):
                        r, facit = _mat_dold(seed=seed, hojd=hojd, baksving=baksving)
                        self.assertFalse(r["faser"]["start_osaker"])
                        self.assertAlmostEqual(r["matt"]["tempo"], facit["tempo"], delta=TEMPO_GRANS)

    def test_handernas_start_tappar_tempot_bakifran(self) -> None:
        """Felet som M40 rättar: händernas start (M4) saknas med baksvingen 0,75 s, och
        med 0,95 s ger den ett tempo ≈ 1 för lågt."""
        for baksving in (0.75, 0.95):
            d, facit = gen.sving_dold(seed=1, baksving=baksving)
            s = fm.fran_dict(d)
            b = F.jamna(s.t, F.grepp_regel(s.xy))
            f = F.hitta_faser(s.t, (b[:, 5] + b[:, 6]) / 2, s.t_klick)
            if f.start is not None:
                self.assertLess((f.topp - f.start) / (f.traff - f.topp), facit["tempo"] - 0.5)
            self.assertEqual(f.start is None, baksving == 0.75)

    def test_skakig_adress_ger_osaker_start_och_inget_tempo(self) -> None:
        r, _ = _mat_dold(seed=23, brus_px=10.0)
        self.assertIsNotNone(r["faser"]["start"])               # adressen räknas ändå från den
        self.assertTrue(r["faser"]["start_osaker"])
        for k in ("tempo", "baksving_s"):
            self.assertNotIn(k, r["matt"])
        # Nedsvingens tid beror inte på starten: toppen till klicket (METOD M5, S1e).
        self.assertAlmostEqual(r["matt"]["nedsving_s"], r["faser"]["traff"] - r["faser"]["topp"], delta=1e-12)

    def test_utan_posen_tas_starten_ur_handerna_och_ar_osaker(self) -> None:
        d, _ = gen.sving("dtl", seed=24, brus_px=0.8, dolj=(("armbage_v", 0.0, 9.9), ("armbage_h", 0.0, 9.9),
                                                            ("axel_v", 2.10, 2.30)))
        s = fm.fran_dict(d)
        r = M.mat(s)
        b = F.jamna(s.t, F.grepp_regel(s.xy))
        f = F.hitta_faser(s.t, (b[:, 5] + b[:, 6]) / 2, s.t_klick)
        self.assertEqual(r["faser"]["start"], f.start)
        self.assertTrue(r["faser"]["start_osaker"])
        self.assertNotIn("tempo", r["matt"])

    def test_figuren_i_bildens_plan(self) -> None:
        """Utan dold takeaway (händerna i bildens plan) ligger posens start nära
        händernas (M4): uppmätt −26…−18 ms med 0,8 px brus (frön 0–19), eftersom
        armbågen och axlarna rör sig före händerna når 5 % av vägen."""
        for seed in range(4):
            r = M.mat(fm.fran_dict(gen.sving("dtl", seed=seed, brus_px=0.8)[0]))
            _, facit = gen.sving("dtl", seed=seed, brus_px=0.8)
            self.assertFalse(r["faser"]["start_osaker"])
            self.assertAlmostEqual(r["faser"]["start"], facit["_start"], delta=0.030)

    def test_dtl_utan_start_ar_osaker(self) -> None:
        r = M.mat(fm.fran_dict(gen.sving("dtl", start=1.95)[0]))          # baksvingen 0,25 s
        self.assertIsNone(r["faser"]["start"])
        self.assertTrue(r["faser"]["start_osaker"])
        fo = M.mat(fm.fran_dict(gen.sving("fo", start=1.95)[0]))
        self.assertIsNone(fo["faser"]["start"])
        self.assertFalse(fo["faser"]["start_osaker"])                    # framifrån M4 som förut

    def _dold_fixtur(self) -> dict:
        return json.loads(gen.fixtursving("dtl_dold"))

    def test_lucka_over_starten_ar_osaker(self) -> None:
        """En led borta 0,18 s över starten (mer än MAX_LUCKA_S) flyttade starten tyst."""
        d = self._dold_fixtur()
        self.assertFalse(M.mat(fm.fran_dict(d))["faser"]["start_osaker"])
        for r in d["rutor"]:
            if 1.02 <= r["t"] <= 1.20:
                r["leder"][4] = [0.0, 0.0, 0.0]                              # bakre armbågen
        r = M.mat(fm.fran_dict(d))
        self.assertTrue(r["faser"]["start_osaker"])
        self.assertNotIn("tempo", r["matt"])

    def test_klipp_som_borjar_strax_fore_takeawayn_ar_osakert(self) -> None:
        for t0, osaker in ((0.9, True), (0.2, False)):                   # toppen − 1,5 s ≈ 0,25 s
            d = self._dold_fixtur()
            d["rutor"] = [r for r in d["rutor"] if r["t"] >= t0]
            self.assertEqual(M.mat(fm.fran_dict(d))["faser"]["start_osaker"], osaker, t0)

    def _fel(self, **kw) -> list[tuple[bool, float, float]]:
        """(osäker, tempofelet från starten, hela tempofelet) för slumpade svingar, frön 30–41
        och kameran på 0,8 / 1,0 / 1,4 / 1,6 m. Tempofelet från starten räknas med den
        mätta toppen och träffen, så att toppens fel (M4) inte kommer med."""
        ut = []
        for hojd in (0.8, 1.0, 1.4, 1.6):
            for seed in range(30, 42):
                d, facit = gen.sving_dold(seed=seed, hojd=hojd, variera=True, **kw)
                r = M.mat(fm.fran_dict(d))
                f = r["faser"]
                self.assertIsNotNone(f["start"], (hojd, seed))
                ned = f["traff"] - f["topp"]
                ut.append((f["start_osaker"], (facit["_start"] - f["start"]) / ned,
                           r["matt"].get("tempo", math.nan) - facit["tempo"]))
        return ut

    def test_noggrannheten_pa_andra_fron(self) -> None:
        """0,8 px brus: ingen osäker, tempofelet från starten högst 0,15 (uppmätt 0,13) och
        hela tempofelet högst 0,20 (uppmätt 0,15). METOD M40"""
        for osaker, e_start, e_hel in self._fel(brus_px=0.8):
            self.assertFalse(osaker)
            self.assertLessEqual(abs(e_start), 0.15)
            self.assertLessEqual(abs(e_hel), 0.20)

    def test_tre_px_markeras_inte(self) -> None:
        """Posemodellens brus "bra" (3 px): ingen märks osäker, och tempofelet från starten
        är högst 0,35 (uppmätt 0,31 för ett frö, 95 % under 0,15). METOD M40"""
        for osaker, e_start, _ in self._fel(profil="bra"):
            self.assertFalse(osaker)
            self.assertLessEqual(abs(e_start), 0.35)

    def test_fem_px_omarkta_fel(self) -> None:
        """Posemodellens brus "typiskt" (5 px): av de omärkta har högst 30 % ett tempofel från
        starten över 0,25 (uppmätt 4 av 18), och minst 10 av 48 är omärkta (uppmätt 18). METOD M40"""
        omarkta = [abs(e) for osaker, e, _ in self._fel(profil="typiskt") if not osaker]
        self.assertGreaterEqual(len(omarkta), 10)
        self.assertLessEqual(sum(e > 0.25 for e in omarkta) / len(omarkta), 0.30)

    def test_fo_ar_oforandrad(self) -> None:
        for namn, (start, topp, tempo) in FO_LAST.items():
            with self.subTest(namn=namn):
                r = gen.resultat_json(gen.fixtursving(namn))
                self.assertAlmostEqual(r["faser"]["start"], start, delta=1e-9)
                self.assertAlmostEqual(r["faser"]["topp"], topp, delta=1e-9)
                self.assertAlmostEqual(r["matt"]["tempo"], tempo, delta=1e-9)
                self.assertFalse(r["faser"]["start_osaker"])
