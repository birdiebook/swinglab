// S5:s exempel på att_jobba_pa.json, ordagrant som Swift-källa (som S1:s fixturer, BESLUT B12).
// Källan: tools/tests/fixturer/att_jobba_pa_exempel.json på grenen s5-pc (formen i docs/FORMAT.md,
// Att jobba på). Byt texten här när S5 ändrar exemplet.

enum AttJobbaPaFixtur {
    static let exempel = #"""
{
 "format": "swinglab-att-jobba-pa/1",
 "pass": "20261103-180000",
 "skapad": "2026-11-03T21:15:00+01:00",
 "saker": [
  {
   "ordning": 1,
   "fel": "sway_topp",
   "namn": "Bäckenet glider bakåt i baksvingen",
   "vy": "fo",
   "matt": "backen_sway_topp",
   "enhet": "cm",
   "nu": -5.7,
   "spann": [0, null],
   "markning": "B10",
   "ovning": {
    "text": "Käpp i marken utanför bakre höften. Baksving till toppen och stopp: höften roterar, käppen står kvar. Sedan fötterna ihop, 3/4-svingar.",
    "tanke": "Rör inte käppen.",
    "kalla": "katalog"
   },
   "klart_nar": {"villkor": ">=", "grans": 0, "pa": "forsta_serien", "pass_i_rad": 2},
   "foljdfel": ["reverse_spine", "backens_resa_framat", "sway_gap"],
   "typ": "teknik",
   "fysik": null
  }
 ]
}
"""#
}
