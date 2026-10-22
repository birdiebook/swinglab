"""Vyernas demo (S4) håller S5:s kontrakt: `att_jobba_pa` i SwingLabKit/Sources/SwingDemo/Demo.swift
körs genom samma kontroll som PC:n (`tools/pc/att_jobba_pa.py`, METOD MT5, MT6, MT8, MT10).

Analysen och minnet är påhittade och byggs ur filen själv: sakerna är flaggade och talen är
filens. Det kontrollen då prövar är formen, kedjorna, övningarna, stegen, blocket, treregeln och
fritexten, alltså allt som vyn ritar utöver talen."""
from __future__ import annotations

import json
import unittest
from pathlib import Path

import _hjalp  # noqa: F401
from pc import analys as A
from pc import att_jobba_pa as AJP
from pc import katalog as KAT

DEMO = Path(__file__).resolve().parents[2] / "SwingLabKit" / "Sources" / "SwingDemo" / "Demo.swift"


def demots_fil() -> dict:
    text = DEMO.read_text(encoding="utf-8")
    start = text.index('attJobbaPaJSON = #"""') + len('attJobbaPaJSON = #"""')
    return json.loads(text[start:text.index('"""#', start)])


def analys_ur(d: dict, katalog: dict, kedjor: dict) -> dict:
    """En analys där filens saker är röda och varje tal är filens."""
    visat, kn, rod = {}, {}, set()
    for s in d["saker"]:
        rod.add(s["fel"])
        visat[s["fel"]] = s["nu"]
        kn[s["fel"]] = {"villkor": s["klart_nar"]["villkor"], "grans": s["klart_nar"]["grans"],
                        "grund": "baslinje", "markning": s["markning"]}
        for f in s["foljdfel"]:
            visat[f["fel"]] = f["nu"]
    bed = [{"id": f["id"], "fas": f["fas"], "status": "rod" if f["id"] in rod else "gron", "z": None,
            "visat": visat.get(f["id"]), "klart_nar": kn.get(f["id"])} for f in katalog["fel"]]
    return {"pass": d["pass"], "bedomning": bed, "kandidater": A.kandidater(bed, kedjor)}


def minne_ur(d: dict) -> list[dict]:
    """Minnet före passet: en sak som inte står på första steget fortsätter sedan blockets start."""
    ut = []
    for s in d["saker"]:
        if s["ovning"]["steg"] == AJP.STEG[0]:
            continue
        i = AJP.STEG.index(s["ovning"]["steg"])
        ut.append({"fel": s["fel"], "ovning": s["ovning"]["text"], "ovning_id": s["ovning"]["id"], "lage": "fortsatt",
                   "fel_start": s["block"]["start"].replace("-", "") + "-180000",
                   "klart_nar": {k: s["klart_nar"][k] for k in ("villkor", "grans", "pa", "pass_i_rad")},
                   "markning": s["markning"], "steg": AJP.STEG[i - 1], "forra_ovningar": []})
    return ut


class Demot(unittest.TestCase):
    def test_demot_haller_kontraktet(self) -> None:
        d = demots_fil()
        katalog, kedjor = KAT.las(), A.las_kedjor()
        fel = AJP.kontrollera(d, analys_ur(d, katalog, kedjor), minne_ur(d), katalog, kedjor)
        self.assertEqual(fel, [])

    def test_ingen_sak_ar_foljdfel_av_en_annan(self) -> None:
        d = demots_fil()
        kedjor = A.las_kedjor()
        valda = [s["fel"] for s in d["saker"]]
        for s in d["saker"]:
            self.assertFalse(set(A.orsaker(kedjor, s["fel"])) & set(valda), s["fel"])

    def test_kontrollen_faller_ett_fel_i_demot(self) -> None:
        # Kvittot: kontrollen läser verkligen demot (ett följdfel med fel väg fälls).
        d = demots_fil()
        d["saker"][0]["foljdfel"][0]["vag"] = ["sway_topp"]
        katalog, kedjor = KAT.las(), A.las_kedjor()
        fel = AJP.kontrollera(d, analys_ur(d, katalog, kedjor), minne_ur(d), katalog, kedjor)
        self.assertTrue(any("vag" in f for f in fel), fel)


if __name__ == "__main__":
    unittest.main()
