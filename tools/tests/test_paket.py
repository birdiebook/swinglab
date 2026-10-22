"""Paketet från telefonen (S2_SPEC §8.3): formen, felen utan värden och
vägen till S1:s mått (METOD MT1). Bara påhittade paket."""
from __future__ import annotations

import json
import tempfile
import unittest
import zipfile
from pathlib import Path

import _hjalp  # noqa: F401  (sökvägen till tools/)
from pc import analys as A
from pc import format as fm
from pc import generera_paket as GP
from pc import matt as M
from pc import paket as P

PASS = "20261103-180000"


def _skriv_om(src: Path, dst: Path, manifest=None, filer: dict | None = None, utan: tuple = ()) -> Path:
    """Kopia av paketet med ändrat manifest, ändrade eller borttagna filer."""
    with zipfile.ZipFile(src) as zi, zipfile.ZipFile(dst, "w") as zo:
        for n in zi.namelist():
            if n in utan:
                continue
            if n == "manifest.json" and manifest is not None:
                zo.writestr(n, manifest if isinstance(manifest, str) else json.dumps(manifest))
            elif filer and n in filer:
                zo.writestr(n, filer[n])
            else:
                zo.writestr(n, zi.read(n))
    return dst


class Paketet(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tmp = tempfile.TemporaryDirectory()
        cls.mapp = Path(cls.tmp.name)
        cls.fo = GP.paket(cls.mapp, PASS, "fo", n=4, inte_sving=1, osaker=1, serier=1)
        with zipfile.ZipFile(cls.fo) as z:
            cls.manifest = json.loads(z.read("manifest.json"))

    @classmethod
    def tearDownClass(cls) -> None:
        cls.tmp.cleanup()

    def fel(self, **kw) -> list[str]:
        dst = _skriv_om(self.fo, self.mapp / "trasig.zip", **kw)
        with self.assertRaises(P.PaketFel) as e:
            P.las(dst)
        return e.exception.fel

    def test_det_pahittade_paketet_las(self) -> None:
        p = P.las(self.fo)
        self.assertEqual((p.pass_id, p.vy, p.spelhand, len(p.slag)), (PASS, "fo", "hoger", 5))
        self.assertEqual([s.dom for s in p.slag].count("inte_sving"), 1)
        self.assertEqual([s.serie_ordning for s in p.slag], list(range(5)))
        self.assertTrue(all(s.lederna for s in p.slag))

    def test_slaget_ger_generatorns_tal(self) -> None:
        """Paketets väg (JointSeries, t relativt klicket, träffen före klicket)
        ger samma mått som svingen i filformatet. METOD MT1"""
        p = P.las(self.fo)
        s = p.slag[1]
        r = M.mat(fm.fran_dict(P.till_sving(p, s, 1.80)))
        self.assertAlmostEqual(P.traff_i_serien(p, s), -GP.AVSTAND_M / P.LJUDETS_FART, places=3)
        self.assertAlmostEqual(r["faser"]["traff"], P.traff_i_serien(p, s))
        self.assertTrue(-9.0 < r["matt"]["backen_sway_topp"] < -3.0)

    def test_traffen_utan_traff_s_kommer_ur_avstandet(self) -> None:
        m = json.loads(json.dumps(self.manifest))
        for s in m["slag"]:
            s.pop("traff_s")
        p = P.las(_skriv_om(self.fo, self.mapp / "utan_traff.zip", manifest=m))
        self.assertAlmostEqual(P.traff_i_serien(p, p.slag[0]), -3.0 / 343.0)

    def test_leden_som_lista_och_null(self) -> None:
        with zipfile.ZipFile(self.fo) as z:
            d = json.loads(z.read("slag/s01.json"))
        for r in d["frames"]:
            r["joints"] = [None if j is None else [j["x"], j["y"], j["c"]] for j in r["joints"]]
        d["frames"][0]["joints"][3] = None
        p = P.las(_skriv_om(self.fo, self.mapp / "listor.zip", filer={"slag/s01.json": json.dumps(d)}))
        sv = P.till_sving(p, p.slag[0], 1.8)
        self.assertEqual(sv["rutor"][0]["leder"][3], [0.0, 0.0, 0.0])

    def test_inte_en_zip(self) -> None:
        f = self.mapp / "inte.zip"
        f.write_text("hej")
        with self.assertRaises(P.PaketFel) as e:
            P.las(f)
        self.assertIn("inte en zip", str(e.exception))

    def test_manifestet_saknas(self) -> None:
        self.assertIn("manifest.json saknas", self.fel(utan=("manifest.json",))[0])

    def test_manifestet_ar_inte_json(self) -> None:
        self.assertIn("inte giltig JSON", self.fel(manifest="{trasig")[0])

    def test_felen_namner_falt_aldrig_varden(self) -> None:
        m = json.loads(json.dumps(self.manifest))
        m["vy"] = "sidan"
        m["slag"][1]["klick_s"] = "12.3456"
        m["slag"][2]["dom"] = "kanske"
        m["slag"][3]["serie"] = 7
        m["spelarens_langd_m"] = 3.1
        fel = self.fel(manifest=m)
        text = "; ".join(fel)
        for falt in ("vy", "slag[1].klick_s", "slag[2].dom", "slag[3].serie", "spelarens_langd_m"):
            self.assertIn(falt, text)
        for varde in ("sidan", "12.3456", "kanske", "3.1"):
            self.assertNotIn(varde, text)

    def test_ledernas_fil_saknas(self) -> None:
        self.assertIn("slag[0].leder: filen saknas", "; ".join(self.fel(utan=("slag/s01.json",))))

    def test_sokvag_ut_ur_paketet_vagras(self) -> None:
        m = json.loads(json.dumps(self.manifest))
        m["slag"][0]["leder"] = "../hemlig.json"
        self.assertIn("slag[0].leder ska vara en sökväg", "; ".join(self.fel(manifest=m)))

    def test_trasig_led_namner_ruta_och_led(self) -> None:
        with zipfile.ZipFile(self.fo) as z:
            d = json.loads(z.read("slag/s02.json"))
        d["frames"][5]["joints"][6] = {"x": "77.7", "y": 1.0, "c": 0.9}
        fel = "; ".join(self.fel(filer={"slag/s02.json": json.dumps(d)}))
        self.assertIn("slag/s02.json: frames[5], handled_h", fel)
        self.assertNotIn("77.7", fel)

    def test_klipp_kraver_klicket_i_klippet(self) -> None:
        m = json.loads(json.dumps(self.manifest))
        m["slag"][0]["klipp"] = "slag/s02.json"     # en fil som finns
        self.assertIn("klick_i_klipp_s", "; ".join(self.fel(manifest=m)))

    def test_klippets_langd_och_rutorna_i_klippet(self) -> None:
        """S2f: telefonen skriver klippets längd; bara [0; längd) räknas (METOD MS12)."""
        m = json.loads(json.dumps(self.manifest))
        m["slag"][0].update(klipp="slag/s02.json", klick_i_klipp_s=2.5, klipp_langd_s=4.0)
        p = P.las(_skriv_om(self.fo, self.mapp / "langd.zip", manifest=m))
        s = next(x for x in p.slag if x.id == m["slag"][0]["id"])
        self.assertEqual(s.klipp_langd_s, 4.0)
        self.assertEqual([P.i_klippet(s, t) for t in (-0.001, 0.0, 3.999, 4.0, 4.1)], [False, True, True, False, False])
        utan = next(x for x in p.slag if x.id != s.id)
        self.assertIsNone(utan.klipp_langd_s)
        self.assertTrue(P.i_klippet(utan, 100.0))
        m["slag"][0]["klipp_langd_s"] = -1.0
        fel = "; ".join(self.fel(manifest=m))
        self.assertIn("slag[0].klipp_langd_s ska vara ett positivt tal", fel)
        self.assertNotIn("-1.0", fel)


def _skada(src: Path, dst: Path, fil: str) -> Path:
    """Kopia (lagrad, okomprimerad) där en byte mitt i `fil` är ändrad: fel CRC."""
    with zipfile.ZipFile(src) as zi, zipfile.ZipFile(dst, "w", zipfile.ZIP_STORED) as zo:
        for n in zi.namelist():
            zo.writestr(n, zi.read(n))
    with zipfile.ZipFile(dst) as z:
        info = z.getinfo(fil)
    b = bytearray(dst.read_bytes())
    start = info.header_offset + 30 + len(info.filename.encode()) + len(info.extra)
    b[start + info.file_size // 2] ^= 0x01
    dst.write_bytes(bytes(b))
    return dst


class SkadadZip(unittest.TestCase):
    """Granskningen fynd 8: fel CRC blir PaketFel, utan innehållet."""

    def test_skadat_slag_och_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            src = GP.paket(tmp, PASS, "fo", n=2, inte_sving=0)
            for fil in ("slag/s02.json", "manifest.json"):
                with self.assertRaises(P.PaketFel) as e:
                    P.las(_skada(src, Path(tmp) / "skadad.zip", fil))
                self.assertEqual(e.exception.fel, [f"skadad.zip: {fil} är skadad i zippen"])


class Slagen(unittest.TestCase):
    def test_inte_sving_mats_inte_och_forsta_serien_ar_de_fem_forsta(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            p = P.las(GP.paket(tmp, PASS, "dtl", n=7, inte_sving=1, serier=1))
        rader = A.mat_paket(p, 1.80)
        self.assertEqual(sum(1 for r in rader if "matt" in r), 7)
        self.assertEqual([r for r in rader if "utelamnat" in r][0]["id"], "s08")
        self.assertEqual(sum(1 for r in rader if r.get("forsta_serien")), A.FORSTA_SERIEN_SLAG)

    def test_detection_wrong_mats_inte(self) -> None:
        """S2f/S4b: ett slag Johannes märkt "Detection wrong" mäts inte på PC:n, som på
        telefonen (METOD MT1, BESLUT B12); ett fel värde är ett formfel utan värdet."""
        with tempfile.TemporaryDirectory() as tmp:
            src = GP.paket(tmp, PASS, "fo", n=4, inte_sving=0, serier=1)
            with zipfile.ZipFile(src) as z:
                m = json.loads(z.read("manifest.json"))
            m["slag"][1]["detection_wrong"] = True
            m["slag"][2]["detection_wrong"] = False
            p = P.las(_skriv_om(src, Path(tmp) / "fel.zip", manifest=m))
            rader = A.mat_paket(p, 1.80)
            self.assertEqual([r["id"] for r in rader if "utelamnat" in r], [m["slag"][1]["id"]])
            self.assertEqual(sum(1 for r in rader if "matt" in r), 3)
            m["slag"][1]["detection_wrong"] = "ja"
            with self.assertRaises(P.PaketFel) as e:
                P.las(_skriv_om(src, Path(tmp) / "fel2.zip", manifest=m))
            self.assertIn("slag[1].detection_wrong ska vara true eller false", "; ".join(e.exception.fel))
            self.assertNotIn("ja", "; ".join(e.exception.fel))

    def test_forsta_serien_ar_de_fem_forsta_i_serie_ett(self) -> None:
        """Granskningen fynd 11: serie 1 med sju slag ger fem, med tre slag tre. METOD MT2"""
        with tempfile.TemporaryDirectory() as tmp:
            src = GP.paket(tmp, PASS, "fo", n=9, inte_sving=0, serier=1)
            with zipfile.ZipFile(src) as z:
                m = json.loads(z.read("manifest.json"))
            m["serier"].append({"nr": 2, "kalla": "inspelning", "klubba": "j7"})
            for k, sista in ((7, ["s01", "s02", "s03", "s04", "s05"]), (3, ["s01", "s02", "s03"])):
                for i, s in enumerate(m["slag"]):
                    s["serie"] = 1 if i < k else 2
                p = P.las(_skriv_om(src, Path(tmp) / f"serier{k}.zip", manifest=m))
                rader = A.mat_paket(p, 1.80)
                self.assertEqual([r["id"] for r in rader if r["forsta_serien"]], sista)

    def test_ett_slag_som_inte_gar_att_mata_far_ett_fel_utan_varde(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            src = GP.paket(tmp, PASS, "fo", n=3, inte_sving=0)
            with zipfile.ZipFile(src) as z:
                d = json.loads(z.read("slag/s02.json"))
            for r in d["frames"]:
                r["joints"][5] = r["joints"][6] = None       # händerna syns aldrig
            p = P.las(_skriv_om(src, Path(tmp) / "x.zip", filer={"slag/s02.json": json.dumps(d)}))
        rader = A.mat_paket(p, 1.80)
        self.assertIn("händerna syns inte", rader[1]["fel"])
        self.assertIn("matt", rader[0])




class Redigeringen(unittest.TestCase):
    """S2i: fönstret och utsnittet ur telefonens redigerare (METOD MS13)."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.tmp = tempfile.TemporaryDirectory()
        cls.mapp = Path(cls.tmp.name)
        cls.fo = GP.paket(cls.mapp, PASS, "fo", n=3, inte_sving=0, serier=1)
        with zipfile.ZipFile(cls.fo) as z:
            cls.manifest = json.loads(z.read("manifest.json"))

    @classmethod
    def tearDownClass(cls) -> None:
        cls.tmp.cleanup()

    def fel(self, **kw) -> list[str]:
        dst = _skriv_om(self.fo, self.mapp / "trasig.zip", **kw)
        with self.assertRaises(P.PaketFel) as e:
            P.las(dst)
        return e.exception.fel

    def _med_redigering(self, fonster=None, utsnitt=None) -> dict:
        m = json.loads(json.dumps(self.manifest))
        if fonster is not None:
            m["serier"][0]["fonster"] = fonster
        if utsnitt is not None:
            m["serier"][0]["utsnitt"] = utsnitt
        return m

    def test_fonstret_och_utsnittet_las(self) -> None:
        klick = sorted(s["klick_s"] for s in self.manifest["slag"])
        f = {"fran_s": klick[0] - 1.0, "till_s": klick[-1] + 1.0}
        u = {"x": 0.125, "y": 0.25, "b": 0.5, "h": 0.625}
        p = P.las(_skriv_om(self.fo, self.mapp / "redigerad.zip", manifest=self._med_redigering(f, u)))
        s = p.serier[1]
        self.assertEqual(s.fonster, (klick[0] - 1.0, klick[-1] + 1.0))
        self.assertEqual(s.utsnitt, (0.125, 0.25, 0.5, 0.625))
        self.assertEqual(s.klubba, "j7")
        # Utan redigering: None, hela filen och bilden.
        p0 = P.las(self.fo)
        self.assertIsNone(p0.serier[1].fonster)
        self.assertIsNone(p0.serier[1].utsnitt)

    def test_klick_utanfor_fonstret_ar_fel(self) -> None:
        klick = sorted(s["klick_s"] for s in self.manifest["slag"])
        f = {"fran_s": klick[1] - 0.5, "till_s": klick[-1] + 1.0}
        fel = self.fel(manifest=self._med_redigering(f))
        self.assertEqual(len(fel), 1)
        self.assertIn("klick_s ligger utanför seriens fonster", fel[0])
        self.assertNotIn(str(klick[0]), fel[0], "aldrig värdet")

    def test_fel_fonster_och_utsnitt_namner_faltet_utan_varde(self) -> None:
        fall = [
            ({"fran_s": 5.0}, None, "fonster ska ha talen fran_s och till_s"),
            ({"fran_s": 50.0, "till_s": 40.0}, None, "fonster ska ha 0 <= fran_s < till_s"),
            (None, {"x": 0.1, "y": 0.1, "b": 0.5}, "utsnitt ska ha talen x, y, b och h"),
            (None, {"x": 0.7, "y": 0.1, "b": 0.5, "h": 0.5}, "utsnitt ska ligga inom bilden"),
            (None, {"x": 0.1, "y": 0.1, "b": 0.0, "h": 0.5}, "utsnitt ska ligga inom bilden"),
        ]
        for f, u, text in fall:
            fel = self.fel(manifest=self._med_redigering(f, u))
            self.assertTrue(any(text in x for x in fel), (text, fel))
            for x in fel:
                self.assertNotIn("0.7", x)

    def test_utsnittet_i_pixlar_och_tillbaka(self) -> None:
        """Samma pixlar som SwingLabKits CropRect.pixels (RedigeringTests), och en punkt
        i utsnittet (MediaPipe på den utskurna bilden) till hela bildens pixlar."""
        self.assertEqual(P.utsnitt_px((0.1, 0.25, 0.5, 0.5), 1080, 1920), (108, 480, 540, 960))
        x, y, b, h = P.utsnitt_px((0.1001, 0.0, 0.3, 1.0), 270, 480)
        self.assertEqual((x, x + b, h), (27, 109, 480))
        self.assertEqual(P.utsnitt_px((0.01, 0.2, 0.78, 0.7), 270, 480), (2, 96, 212, 336))
        self.assertEqual(P.utsnitt_px(None, 1080, 1920), (0, 0, 1080, 1920))
        u = (0.25, 0.1, 0.5, 0.8)
        self.assertEqual(P.fran_utsnittet(0.5, 0.5, u, 1080, 1920), (540.0, 960.0))
        self.assertEqual(P.fran_utsnittet(0.0, 0.0, u, 1080, 1920), (270.0, 192.0))
        self.assertEqual(P.fran_utsnittet(0.25, 0.75, None, 1080, 1920), (270.0, 1440.0))

if __name__ == "__main__":
    unittest.main()
