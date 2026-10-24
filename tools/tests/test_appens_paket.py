"""Kontraktet mellan telefon och PC (S2f, BESLUT B27): paketen som APPEN skrev i
simulatorprovet (`Prov/SwingLabProvPaket.swift`, App/Export.swift, påhittad film och
påhittade leder) läses av PC:ns `paket.py` och körs genom `session.py` utan fel,
PC:ns mått på lederna är Swifts (facit.json, samma byte; BESLUT B12), och klippen
avkodas ruta för ruta med OpenCV (som kontaktarket använder utan ffmpeg).

Körs av kompilera.yml efter simulatorprovet, med mappen i miljövariabeln
SWINGLAB_APPENS_PAKET (/tmp/swinglab_prov/paket). Utan den hoppas provet över: på
Linux finns inget paket som appen skrivit (test_paket.py prövar formen där).

    SWINGLAB_APPENS_PAKET=/tmp/swinglab_prov/paket python3 -m unittest discover -s tools/tests -p test_appens_paket.py -v
"""
from __future__ import annotations

import io
import json
import os
import tempfile
import unittest
import zipfile
from contextlib import redirect_stdout
from pathlib import Path

import _hjalp  # noqa: F401  (sökvägen till tools/)
from pc import paket as P
from pc import session as S

MAPP = os.environ.get("SWINGLAB_APPENS_PAKET")


def _avkoda(data: bytes) -> tuple[int, float]:
    """Klippet avkodat ruta för ruta med OpenCV (kompilera.yml installerar det; utan det
    fäller provet): antalet rutor och den sista rutans tid i s."""
    import cv2
    with tempfile.NamedTemporaryFile(suffix=".mov", delete=False) as t:
        t.write(data)
        namn = t.name
    try:
        v = cv2.VideoCapture(namn)
        n, sist = 0, 0.0
        while True:
            ok, _ = v.read()
            if not ok:
                break
            n += 1
            sist = v.get(cv2.CAP_PROP_POS_MSEC) / 1000.0
        v.release()
        return n, sist
    finally:
        os.unlink(namn)
RELATIV = 1e-6          # BESLUT B12: samma algoritm, bara summeringsordningen skiljer
GOLV = 1e-9


@unittest.skipUnless(MAPP, "SWINGLAB_APPENS_PAKET saknas: inget paket från appen (körs i kompilera.yml)")
class AppensPaket(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        rot = Path(MAPP)
        cls.facit = json.loads((rot / "facit.json").read_text(encoding="utf-8"))
        cls.med = sorted((rot / "med-klipp").glob("swinglab-*.zip"))
        cls.utan = sorted((rot / "utan-klipp").glob("swinglab-*.zip"))

    def test_bada_paketen_finns(self) -> None:
        self.assertEqual(len(self.med), 1, "paketet med klipp")
        self.assertEqual(len(self.utan), 1, "paketet utan klipp")
        self.assertEqual(self.med[0].name, f"swinglab-{self.facit['pass']}-fo.zip")

    def test_paket_py_laser_dem(self) -> None:
        for fil, klipp in ((self.med[0], True), (self.utan[0], False)):
            p = P.las(fil)
            self.assertEqual(p.pass_id, self.facit["pass"])
            self.assertEqual(sorted(s.id for s in p.slag), sorted(self.facit["slag"]))
            self.assertTrue(all(s.lederna for s in p.slag))
            # Fönstret och utsnittet ur redigeraren, utplattade per serie (METOD MS13).
            serie = p.serier[1]
            self.assertIsNotNone(serie.fonster)
            self.assertIsNotNone(serie.utsnitt)
            if klipp:
                for s in p.slag:
                    self.assertIsNotNone(s.klipp_langd_s)
                    self.assertTrue(P.i_klippet(s, float(s.klick_i_klipp_s)), "klicket bland klippets rutor")
                    with zipfile.ZipFile(fil) as z:
                        data = z.read(s.klipp)            # CRC kontrolleras av zipfile
                    self.assertEqual(data[4:8], b"ftyp", f"{s.klipp} är en QuickTime-fil")
                    n, sist = _avkoda(data)
                    self.assertGreater(n, 0, f"{s.klipp} spelar inte")
                    print(f"PAKET: {s.id} klippet avkodat med OpenCV: {n} rutor, sista vid {sist:.4f} s; "
                          f"telefonens längd {s.klipp_langd_s:.4f} s")
            else:
                self.assertTrue(all(s.klipp is None for s in p.slag))
            # Lodlinjen (S6b, METOD MS17): inga rörelseprov i simulatorn i paketet med klipp,
            # injicerade prov i paketet utan; båda läses, och fältet tas av PC:ns kontroll.
            vantad = self.facit.get("lodlinje", {}).get(fil.parent.name)
            self.assertIsNone(serie.lodlinje_fel, f"{fil.parent.name}: lodlinjen användes inte")
            if vantad is None:
                self.assertIsNone(serie.lodlinje, f"{fil.parent.name}: ingen lodlinje")
            else:
                self.assertEqual(serie.lodlinje, tuple(vantad))
                print(f"PAKET: {fil.parent.name} lodlinjen {list(serie.lodlinje)} läst av paket.py")
            print(f"PAKET: {fil.parent.name}/{fil.name} läst av paket.py: {len(p.slag)} slag, "
                  f"{sum(1 for s in p.slag if s.klipp)} klipp")

    def test_klubbans_markeringar_last_som_pcns(self) -> None:
        """klubba.json som appen skrev (S7a, BESLUT B47): formatet swinglab-klubba/2 som
        markera_klubba.py läser, och markeringarna per slag som paket.py ger analysen."""
        from pc import klubba as KL
        from pc import markera_klubba as MK
        for fil in (self.med[0], self.utan[0]):
            p = P.las(fil)
            self.assertIsNone(p.klubba_fel, f"{fil.parent.name}: {p.klubba_fel}")
            d = MK.las_paket(fil)
            self.assertEqual(KL.kontrollera(d), [])
            self.assertEqual(d["format"], KL.FORMAT)
            for s in p.slag:
                self.assertEqual([m["position"] for m in s.klubba_markeringar], self.facit["slag"][s.id]["klubba"])
            # t_klipp bara när rutan ligger i klippet (FORMAT.md), aldrig utan klipp.
            slag = {x.id: x for x in p.slag}
            klipp = [(r["t_klipp"], slag[r["slag"]]) for r in d["rutor"]]
            if fil.parent.name == "med-klipp":
                self.assertTrue(any(t is not None for t, _ in klipp))
                self.assertTrue(all(P.i_klippet(s, t) for t, s in klipp if t is not None))
            else:
                self.assertTrue(all(t is None for t, _ in klipp))
            print(f"PAKET: {fil.parent.name} klubba.json: {len(d['rutor'])} rutor lästa av markera_klubba.py och paket.py")

    def test_session_py_kor_utan_fel_och_ger_swifts_matt(self) -> None:
        for fil in (self.med[0], self.utan[0]):
            with tempfile.TemporaryDirectory() as ut:
                utskrift = io.StringIO()
                with redirect_stdout(utskrift):
                    kod = S.main([str(fil), "--ut", ut, "--langd", str(self.facit["spelarens_langd_m"])])
                self.assertEqual(kod, 0, utskrift.getvalue())
                analys = json.loads((Path(ut) / "analys.json").read_text(encoding="utf-8"))
            slag = {r["id"]: r for r in analys["slag"]}
            jamforda, storst = 0, 0.0
            for sid, f in self.facit["slag"].items():
                self.assertIn("matt", slag[sid], f"{sid} mättes inte: {slag[sid].get('fel')}")
                pc = slag[sid]["matt"]
                self.assertEqual(set(pc), set(f["matt"]), f"{sid}: samma mått i Python och Swift")
                for k, v in f["matt"].items():
                    d = abs(pc[k] - v)
                    storst = max(storst, d)
                    self.assertLessEqual(d, RELATIV * max(abs(v), abs(pc[k])) + GOLV, f"{sid} {k}: Python mot Swift")
                    jamforda += 1
                self.assertAlmostEqual(pc["backen_sway_topp"], f["sway_satt"], delta=0.5)
            print(f"PAKET: {fil.parent.name} genom session.py: {len(analys['slag'])} slag mätta, "
                  f"{jamforda} mått lika Swifts (största skillnad {storst:.1e}), "
                  + ", ".join(f"{sid} sway i toppen {slag[sid]['matt']['backen_sway_topp']:.2f} cm"
                              for sid in sorted(self.facit["slag"])))


PARAT = (Path(MAPP).parent / "paket-parat") if MAPP else None


@unittest.skipUnless(PARAT, "SWINGLAB_APPENS_PAKET saknas: inget paket från appen (körs i kompilera.yml)")
class AppensParadePaket(unittest.TestCase):
    """S6g (BESLUT B81): Send to PC på den styrande telefonen ger två paket, dess eget (DTL) och den
    andra vyns (FO) byggt ur följarens slag och klippen som kom över kopplingen. Båda har paketets
    format och kontrakt: paket.py läser dem som två telefoners paket, och klippen spelar."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.facit = json.loads((PARAT / "facit.json").read_text(encoding="utf-8"))
        cls.paket = sorted(PARAT.glob("swinglab-*.zip"))

    def test_tva_paket_med_var_sin_vy(self) -> None:
        pid = self.facit["pass"]
        self.assertEqual([f.name for f in self.paket], [f"swinglab-{pid}-dtl.zip", f"swinglab-{pid}-fo.zip"])
        dtl, fo = (P.las(f) for f in self.paket)
        self.assertEqual((dtl.vy, fo.vy), ("dtl", "fo"))
        self.assertEqual(dtl.pass_id, pid)
        self.assertEqual(fo.pass_id, pid)
        self.assertEqual(sorted(s.id for s in dtl.slag), self.facit["dtl_slag"])
        klipp = sorted(s.id for s in fo.slag if s.klipp)
        self.assertEqual(klipp, self.facit["fo_klipp"])
        for s in fo.slag:
            if not s.klipp:
                continue
            self.assertTrue(P.i_klippet(s, float(s.klick_i_klipp_s)), "klicket bland klippets rutor")
            with zipfile.ZipFile(self.paket[1]) as z:
                data = z.read(s.klipp)
            self.assertEqual(data[4:8], b"ftyp", f"{s.klipp} är en QuickTime-fil")
            n, sist = _avkoda(data)
            self.assertGreater(n, 0, f"{s.klipp} spelar inte")
            print(f"PAKET: parat FO {s.id} klippet från den styrande avkodat: {n} rutor, sista vid {sist:.4f} s, "
                  f"klicket i klippet {float(s.klick_i_klipp_s):.4f} s")
        print(f"PAKET: parat {self.paket[0].name} ({len(dtl.slag)} slag) och {self.paket[1].name} "
              f"({len(fo.slag)} slag, {len(klipp)} klipp) lästa av paket.py")


if __name__ == "__main__":
    unittest.main()
