"""Indataformatet (docs/FORMAT.md): läsningen, speglingen och felen."""
from __future__ import annotations

import json
import math
import unittest

import numpy as np

from _hjalp import fm, sving


def _liten(**andra) -> dict:
    d = {"format": 1, "vy": "fo", "hand": "hoger", "x_mot_malet": 1, "spelarens_langd_m": 1.8, "t_klick": 1.0,
         "rutor": [{"t": 0.5, "leder": [[100.0 + j, 200.0 + j, 0.9] for j in range(13)]},
                   {"t": 0.2, "leder": [[300.0 + j, 400.0 + j, 0.9] for j in range(13)]}]}
    d.update(andra)
    return d


class Lasning(unittest.TestCase):
    def test_rutorna_sorteras_pa_tiden(self) -> None:
        s = fm.fran_dict(_liten())
        self.assertEqual(list(s.t), [0.2, 0.5])
        self.assertEqual(s.xy[0, fm.NASA, 0], 300.0)

    def test_hogerspelaren_behaller_sidorna(self) -> None:
        s = fm.fran_dict(_liten())
        self.assertEqual(s.xy[1, fm.AXEL_F, 0], 101.0)          # främre = vänster
        self.assertEqual(s.xy[1, fm.FOTLED_B, 1], 212.0)

    def test_vansterspelaren_byter_sida_och_speglar_x(self) -> None:
        s = fm.fran_dict(_liten(hand="vanster", x_mot_malet=-1))
        self.assertEqual(s.xy[1, fm.AXEL_F, 0], -102.0)         # främre = höger, x vänt
        self.assertEqual(s.xy[1, fm.AXEL_B, 0], -101.0)
        self.assertEqual(s.xy[1, fm.NASA, 1], 200.0)            # y rörs inte

    def test_utan_riktning_ar_vansterspelaren_spegelvand(self) -> None:
        d = _liten(hand="vanster")
        del d["x_mot_malet"]
        self.assertEqual(fm.fran_dict(d).x_tecken, -1.0)
        d = _liten()
        del d["x_mot_malet"]
        self.assertEqual(fm.fran_dict(d).x_tecken, 1.0)

    def test_lag_konfidens_ar_saknad(self) -> None:
        d = _liten()
        d["rutor"][0]["leder"][7][2] = fm.MIN_KONFIDENS - 0.01
        s = fm.fran_dict(d)
        self.assertTrue(np.isnan(s.xy[1, fm.HOFT_F]).all())
        self.assertFalse(np.isnan(s.xy[1, fm.HOFT_B]).any())

    def test_genererad_sving_gar_att_lasa_som_text(self) -> None:
        d, _ = sving(vy="dtl")
        s = fm.las(json.dumps(d))
        self.assertEqual(s.vy, "dtl")
        self.assertGreater(len(s.t), 500)


class Fel(unittest.TestCase):
    def assertFel(self, d: dict, text: str) -> None:
        with self.assertRaises(fm.FormatFel) as e:
            fm.fran_dict(d)
        self.assertIn(text, str(e.exception))

    def test_felen_namner_faltet(self) -> None:
        self.assertFel(_liten(vy="sida"), "vy")
        self.assertFel(_liten(hand="båda"), "hand")
        self.assertFel(_liten(x_mot_malet=2), "x_mot_malet")
        self.assertFel(_liten(spelarens_langd_m=180), "spelarens_langd_m")
        self.assertFel(_liten(format=2), "format")
        self.assertFel(_liten(rutor=[]), "rutor")

    def test_felet_pekar_ut_rutan_men_visar_aldrig_vardet(self) -> None:
        d = _liten()
        d["rutor"][1]["leder"][4] = [123.456, "x", 0.9]
        with self.assertRaises(fm.FormatFel) as e:
            fm.fran_dict(d)
        self.assertIn("ruta 1, armbage_h", str(e.exception))
        self.assertNotIn("123.456", str(e.exception))
        d = _liten()
        d["rutor"][0]["leder"] = d["rutor"][0]["leder"][:12]
        self.assertFel(d, "ruta 0")

    def test_ogiltig_json_namner_raden(self) -> None:
        with self.assertRaises(fm.FormatFel) as e:
            fm.las('{"format": 1,\n "vy": }')
        self.assertIn("rad 2", str(e.exception))

    def test_icke_andliga_tal_falls(self) -> None:
        d = _liten(t_klick=math.inf)
        self.assertFel(d, "t_klick")


if __name__ == "__main__":
    unittest.main()
