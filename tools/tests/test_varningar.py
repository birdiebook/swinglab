"""Varningarna: mått som visas men är osäkra (METOD M54–M59, S3b lager 1). Påhittade svingar med
inlagda fel och rena svingar utan falska larm; inga riktiga leder (CLAUDE.md, Dataregeln)."""
from __future__ import annotations

import json
import math
import tempfile
import unittest
from unittest import mock

import numpy as np

from _hjalp import M, fm, gen, mat
from pc import analys as A
from pc import faser as F
from pc import farter as FA
from pc import generera_paket as GP
from pc import paket as P
from pc import underlag as U
from pc.format import ARMBAGE_F, AXEL_F, HANDLED_B, HANDLED_F, NASA

FASER = F.Faser(start=1.25, topp=2.2, traff=2.5, adress=(0.85, 1.15), finish=(3.5, 3.7))


def _fixtur(namn: str) -> dict:
    return M.mat(fm.las(gen.fixtursving(namn)))


def _hela(f: F.Faser = FASER) -> tuple:
    """Lederna i varje ruta (inga luckor), faserna, inga positioner och inga farter: resten av
    argumenten till `varningar` när bara måtten och kontrollernas tal prövas."""
    t = np.arange(0, 4, 1 / 240)
    return t, np.zeros((len(t), 13, 2)), f, {}, {}


class IngaFalskaLarm(unittest.TestCase):
    """Rena påhittade svingar med 0,8 och 3 px brus: inga varningar. Kontrollernas tal finns."""

    def test_rena_svingar(self) -> None:
        for vy in ("fo", "dtl"):
            for seed in range(6):
                for brus in (0.8, 3.0):
                    r = mat(vy=vy, seed=seed, brus_px=brus)
                    self.assertEqual(r["kvalitet"]["varningar"], {}, f"{vy} {seed} {brus}")
                    self.assertLess(r["kvalitet"]["traff_hojd"], M.SYNK_ANDEL / 2)
                    if "handfart_max" in r["matt"]:                      # frö 1: ingen toppfart (M35)
                        self.assertGreater(r["kvalitet"]["handfart_kvot"], FA.FILTER_KVOT)

    def test_fixturerna_varnar_bara_dar_felet_ar(self) -> None:
        # De 17 äldre fixturerna: bara de tre med ett fel som kontrollerna ska se.
        varnar = {"fo_luckor", "fo_lucka_arm", "fo_nara_traff"}
        for namn in list(gen.FIXTURSVINGAR)[:17]:
            self.assertEqual(bool(_fixtur(namn)["kvalitet"]["varningar"]), namn in varnar, namn)


class Varningarna(unittest.TestCase):
    def test_bara_visade_matt_sorterade(self) -> None:
        r = _fixtur("fo_nara_traff")
        v = r["kvalitet"]["varningar"]
        self.assertEqual(list(v), sorted(v))
        self.assertFalse(set(v) - set(r["matt"]))
        self.assertFalse(set(v) & set(r["kvalitet"]["saknas"]))
        for orsaker in v.values():
            self.assertEqual(orsaker, sorted(set(orsaker)))
        self.assertEqual(v["tempo"], ["fas_orimlig", "traff_osaker"])

    def test_saknat_matt_varnas_inte(self) -> None:
        # Tempot och baksvingen saknas (starten saknas): bara nedsvingen varnas när fasen är orimlig.
        f = F.Faser(start=None, topp=2.2, traff=2.3, adress=(0.6, 0.9), finish=(3.3, 3.5))
        self.assertEqual(M.varningar({"nedsving_s": 0.1}, {}, None, *_hela(f)), {"nedsving_s": ["fas_orimlig"]})


class ToppensAndraSignal(unittest.TestCase):
    """Händerna högst tidigt på en bred platå (drivern 2026-11-03). METOD M55"""

    def test_platan_med_andra_signalen_varnar_tempot(self) -> None:
        for namn in ("fo_topp_plata", "dtl_topp_plata"):
            r = _fixtur(namn)
            k = r["kvalitet"]
            self.assertGreater(k["topp_plata_s"], M.PLATA_BRED_S, namn)
            self.assertGreater(k["topp_andra_s"], M.TOPP_OENIG_S, namn)      # vändningen efter toppen
            for m in M.TOPPENS:
                self.assertIn("topp_osaker", k["varningar"][m], f"{namn} {m}")
            # Toppen är fortfarande händernas högsta punkt: tidigt, och tempot lågt.
            self.assertLess(r["faser"]["topp"], gen.TIDER["topp"] - 0.05, namn)

    def test_standardsvingen_ar_enig(self) -> None:
        for vy in ("fo", "dtl"):
            k = mat(vy=vy, seed=5, brus_px=0.8)["kvalitet"]
            self.assertLess(abs(k["topp_andra_s"]), 0.02, vy)

    def test_smal_plata_provas_inte(self) -> None:
        tom = _hela()
        matt = {"tempo": 3.0, "baksving_s": 0.95, "nedsving_s": 0.3}
        self.assertEqual(M.varningar(matt, {"topp_andra_s": 0.08}, 0.07, *tom), {})
        self.assertEqual(M.varningar(matt, {"topp_andra_s": 0.08}, 0.09, *tom)["tempo"], ["topp_osaker"])
        self.assertEqual(M.varningar(matt, {"topp_andra_s": -0.04}, 0.2, *tom), {})
        self.assertEqual(M.varningar(matt, {}, 0.2, *tom), {})              # ingen andra signal

    def test_armen_forbi_180_grader(self) -> None:
        # Främre armen vrider från 150° bakåt till toppen (190°, förbi lodrätt uppåt) och sedan
        # 200° tillbaka: vinkeln räknas vidare från ruta till ruta, så vändningen är vid 2,0 s.
        t = np.arange(1.7, 2.3, 1 / 240)
        vinkel = np.radians(190 - 2500 * (t - 2.0) ** 2)
        axel = np.zeros((len(t), 2))
        hand = np.stack([-np.sin(vinkel), np.cos(vinkel)], axis=1) * 50        # bakåt = −x, ned = +y
        f = F.Faser(start=1.0, topp=2.0, traff=2.3, adress=(0.6, 0.9), finish=(3.3, 3.5))
        self.assertAlmostEqual(F.andra_toppen(t, hand, axel, hand, f, "fo"), 2.0, delta=1e-3)

    def test_vandningen_bakifran_och_kanten(self) -> None:
        t = np.arange(1.5, 2.6, 1 / 240)
        G = np.stack([-20 * np.exp(-((t - 2.05) / 0.2) ** 2), -70 * np.exp(-((t - 2.0) / 0.3) ** 2)], axis=1)
        f = F.Faser(start=1.0, topp=2.0, traff=2.4, adress=(0.6, 0.9), finish=(3.4, 3.6))
        self.assertIsNone(F.andra_toppen(t, G, G, G, f, "dtl"))             # adressen utanför klippet
        f = F.Faser(start=1.9, topp=2.0, traff=2.4, adress=(1.5, 1.6), finish=(3.4, 3.6))
        self.assertAlmostEqual(F.andra_toppen(t, G, G, G, f, "dtl"), 2.05, delta=1e-3)
        G[:, 0] = -t                                                        # ingen vändning: i kanten
        self.assertIsNone(F.andra_toppen(t, G, G, G, f, "dtl"))


class LuckorKringFasen(unittest.TestCase):
    """Måttets egna leder saknas kring dess ögonblick. METOD M56"""

    def test_egna_handleden_vid_toppen(self) -> None:
        k = _fixtur("fo_lucka_topp")["kvalitet"]
        self.assertEqual(k["varningar"], {"framre_armbage_topp": ["luckor_kring_fasen"]})

    def test_nasan_vid_toppen(self) -> None:
        k = _fixtur("fo_luckor")["kvalitet"]
        self.assertEqual(k["varningar"], {"huvud_lyft_topp": ["luckor_kring_fasen"],
                                          "huvud_sway_topp": ["luckor_kring_fasen"]})

    def test_andelen_och_greppet(self) -> None:
        t = np.arange(10) / 100.0
        xy = np.zeros((10, 13, 2))
        xy[2:5, NASA] = np.nan
        xy[3:7, HANDLED_F] = np.nan
        xy[5:9, HANDLED_B] = np.nan
        self.assertAlmostEqual(M.saknad_andel(t, xy, NASA, 0.035), 3 / 9)      # rutorna 0–8 inom ±0,05 s
        self.assertAlmostEqual(M.saknad_andel(t, xy, M.GREPP, 0.065), 2 / 8)   # rutorna 2–9; båda borta i två
        self.assertAlmostEqual(M.saknad_andel(t, xy, HANDLED_F, 0.065), 4 / 8)
        self.assertEqual(M.saknad_andel(t, xy, NASA, 5.0), 1.0)                # inga rutor

    def test_varje_matt_har_leder_eller_inget_ogonblick(self) -> None:
        for vy, namn in M.MATT.items():
            for m in namn:
                leder, tider = M.luckornas_leder(m)
                self.assertEqual(bool(leder), bool(tider), m)
                if m.endswith(("_topp", "_p3")) or m in ("tempo", "handfart_max"):
                    self.assertTrue(leder, m)
                if m.endswith(("_adress", "_finish")) or m in ("handbana", "stans_bredd", "genomsving_s"):
                    self.assertFalse(leder, m)
        self.assertEqual(M.luckornas_leder("framre_armbage_topp"), ((AXEL_F, ARMBAGE_F, HANDLED_F), ("topp",)))
        self.assertEqual(M.luckornas_leder("tempo"), ((M.GREPP,), ("start", "topp")))
        self.assertEqual(M.luckornas_leder("framre_armbage_efter_traff"), ((), ()))


class TraffensSynk(unittest.TestCase):
    """Klicket mot händernas lägsta punkt i videon. METOD M57"""

    def test_sent_klick_varnar_traffens_matt(self) -> None:
        r = _fixtur("dtl_dold_klick")
        k = r["kvalitet"]
        self.assertGreater(k["traff_hojd"], M.SYNK_ANDEL)
        varnade = {m for m, v in k["varningar"].items() if "traff_osaker" in v}
        self.assertEqual(varnade, {m for m in r["matt"] if M.traffens_matt(m)})
        self.assertNotIn("backen_thrust_topp", k["varningar"])
        self.assertLess(_fixtur("dtl_dold")["kvalitet"]["traff_hojd"], M.SYNK_ANDEL)   # samma sving, rätt klick

    def test_tidigt_klick(self) -> None:
        k = _fixtur("fo_nara_traff")["kvalitet"]                           # klicket 0,16 s före figurens träff
        self.assertGreater(k["traff_hojd"], 3 * M.SYNK_ANDEL)

    def test_vilka_matt_beror_pa_traffen(self) -> None:
        for m in ("backen_sway_traff", "sway_gap_traff", "tempo", "nedsving_s", "handfart_max", "genomsving_s",
                  "backen_resa_framat", "brost_bojning_tapp", "framre_armbage_efter_traff"):
            self.assertTrue(M.traffens_matt(m), m)
        for m in ("backen_sway_topp", "baksving_s", "brost_bojning_adress", "huvud_backen_finish", "stans_bredd"):
            self.assertFalse(M.traffens_matt(m), m)


class Filterkanslighet(unittest.TestCase):
    """Handens toppfart mot en smalare utjämning. METOD M58"""

    def test_hopp_i_handlederna(self) -> None:
        k = _fixtur("fo_fartfel")["kvalitet"]
        self.assertLess(k["handfart_kvot"], FA.FILTER_KVOT)
        self.assertEqual(k["varningar"], {"handfart_max": ["filterkanslig"],
                                          "handfart_max_fore_traff_ms": ["filterkanslig"]})

    def test_kvoten(self) -> None:
        tau = FA.rutnat(0.0, 0.1)
        self.assertAlmostEqual(FA.kvot_mot_smal(tau, (8.0, 0.05), lambda x: np.full(len(x), 10.0)), 0.8)
        # Bara punkterna inom NARA_S från toppens tid räknas, och NaN hoppas över.
        smal = lambda x: np.where(np.abs(x - 0.05) <= 0.005, np.nan, np.where(x > 0.08, 100.0, 9.0))  # noqa: E731
        self.assertAlmostEqual(FA.kvot_mot_smal(tau, (9.0, 0.05), smal), 1.0)
        self.assertIsNone(FA.kvot_mot_smal(tau, (9.0, 0.05), lambda x: np.full(len(x), np.nan)))

    def test_smalare_utjamning_samma_rakning(self) -> None:
        # Utan brus ger en jämn rörelse samma fart med båda utjämningarna (M35 är väntevärdesriktig).
        t = np.arange(0, 0.2, 1 / 240)
        p = np.stack([300 * t, 0 * t], axis=1)
        tau = FA.rutnat(0.05, 0.15)
        np.testing.assert_allclose(FA.hastighet(t, p, tau, FA.SMAL_SIGMA_S)[:, 0], 300.0, rtol=1e-9)


class FasernasLangd(unittest.TestCase):
    """En nedsving eller ett tempo utanför det rimliga. METOD M59"""

    def test_granserna(self) -> None:
        tom = _hela()
        for ned, tempo, varnas in ((0.30, 3.0, False), (0.19, 3.0, True), (0.46, 3.0, True), (0.30, 1.9, True),
                                   (0.30, 4.6, True), (0.20, 2.0, False), (0.45, 4.5, False)):
            v = M.varningar({"nedsving_s": ned, "tempo": tempo, "baksving_s": ned * tempo}, {}, None, *tom)
            self.assertEqual(bool(v), varnas, (ned, tempo))
            if varnas:
                self.assertEqual(set(v), set(M.TOPPENS))

    def test_platan_ger_lagt_tempo(self) -> None:
        # Toppen tidigt på platån: tempot under 2 är också orimligt (som drivern 2026-11-03).
        r = _fixtur("fo_topp_plata")
        self.assertLess(r["matt"]["tempo"], M.TEMPO_RIMLIGT[0])
        self.assertEqual(r["kvalitet"]["varningar"]["tempo"], ["fas_orimlig", "topp_osaker"])


class Flodet(unittest.TestCase):
    """Varningarna och kontrollernas tal följer med i analysen och i frågan till Claude."""

    def test_analysens_rader(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            p = P.las(GP.paket(tmp, "20261105-180000", "fo", n=3, inte_sving=0))
            rader = A.mat_paket(p, 1.80)
            self.assertTrue(all("varningar" not in r for r in rader))
            self.assertTrue(all(set(r["kontroller"]) == set(M.KONTROLLER) for r in rader))
            with mock.patch.object(M, "SYNK_ANDEL", -1.0):                    # varje klick "osynkat"
                rader = A.mat_paket(p, 1.80)
        self.assertTrue(all("traff_osaker" in r["varningar"]["tempo"] for r in rader))
        self.assertEqual(A._sving(rader[0])["varningar"], rader[0]["varningar"])

    def test_fragan_har_varningarna_efter_saknas(self) -> None:
        h = U.facit_fragor()["varningar"]
        text = U.facit_fraga(h)
        d = json.loads(text.split("```json\n")[1].split("\n```")[0])
        tempo = next(m for m in d["matt"] if m["matt"] == "tempo")
        self.assertEqual(tempo["saknas"], {"start_osaker": 1})
        self.assertEqual(tempo["varningar"], {"topp_osaker": 2, "traff_osaker": 2})
        nycklar = list(tempo)
        self.assertEqual(nycklar.index("varningar"), nycklar.index("saknas") + 1)
        self.assertEqual(len(tempo["varden"]), 5)                           # osäkra värden står kvar
        sway = next(m for m in d["matt"] if m["matt"] == "backen_sway_topp")
        self.assertEqual(sway["varningar"], {"luckor_kring_fasen": 1})
        self.assertEqual(list(sway).index("varningar"), list(sway).index("varden") + 1)
        self.assertTrue(all("varningar" not in m for m in d["matt"] if m["matt"] not in ("tempo", "backen_sway_topp")))


if __name__ == "__main__":
    unittest.main()
