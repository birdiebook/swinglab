// GENERERAD av tools/pc/klubba.py --swift. Ändra inte för hand: kör skriptet igen.
//
// PÅHITTADE markeringar (CLAUDE.md, Dataregeln) på Fixturer.swifts påhittade svingar,
// och Pythons klubbmått för dem (METOD M45–M49, BESLUT B12).

enum KlubbFixturer {
    static let json = #"""
{
 "fall": [
  {
   "bredd": 1080,
   "hojd": 2880,
   "markeringar": [
    {
     "grepp": [
      617.8,
      1426.7
     ],
     "hosel": [
      827.8,
      1790.4
     ],
     "position": "P1",
     "t": 1.116667
    },
    {
     "grepp": [
      594.0,
      1344.6
     ],
     "hosel": [
      839.8,
      1516.7
     ],
     "position": "P2",
     "t": 1.591667
    },
    {
     "grepp": [
      566.3,
      1248.6
     ],
     "hosel": [
      528.1,
      1031.9
     ],
     "position": "P3",
     "t": 1.816667
    },
    {
     "grepp": [
      537.7,
      1146.7
     ],
     "hosel": [
      584.2,
      1320.5
     ],
     "position": "P4",
     "t": 2.191667
    },
    {
     "grepp": [
      582.5,
      1252.5
     ],
     "hosel": [
      565.0,
      1053.3
     ],
     "position": "P5",
     "t": 2.308333
    },
    {
     "grepp": [
      614.8,
      1397.5
     ],
     "hosel": [
      813.9,
      1564.6
     ],
     "position": "P6",
     "t": 2.408333
    },
    {
     "grepp": [
      617.7,
      1427.1
     ],
     "hosel": [
      638.9,
      1461.0
     ],
     "position": "P7",
     "t": 2.5
    },
    {
     "grepp": [
      635.6,
      1333.3
     ],
     "hosel": [
      427.8,
      1213.3
     ],
     "position": "P8",
     "t": 2.8125
    },
    {
     "grepp": [
      669.3,
      1150.9
     ],
     "hosel": [
      600.9,
      963.0
     ],
     "position": "P9",
     "t": 3.125
    },
    {
     "grepp": [
      678.7,
      1107.8
     ],
     "hosel": [
      530.9,
      1081.8
     ],
     "position": "P10",
     "t": 3.604167
    }
   ],
   "matt": {
    "skaft_mot_plan_p2": -24.99963050127593,
    "skaft_plan_p6": 26.479471991206324,
    "skaft_riktning_topp": 14.529306667573797,
    "skaft_vinkel_p1": -59.99790791765593,
    "skaft_vinkel_p10": 170.0229837141572,
    "skaft_vinkel_p2": -34.99827741638,
    "skaft_vinkel_p3": 99.99742114797151,
    "skaft_vinkel_p4": -75.02140048634794,
    "skaft_vinkel_p5": 95.02062506598742,
    "skaft_vinkel_p6": -40.005954509808866,
    "skaft_vinkel_p8": 149.99449667149614,
    "skaft_vinkel_p9": 110.00269063718532,
    "skaftplan_p1": 59.99790791765593
   },
   "osakerhet": {
    "100.0": 2.4308540536241865,
    "300.0": 0.8102846845413956,
    "40.0": 6.077135134060467,
    "60.0": 4.0514234227069785
   },
   "sving": "dtl"
  },
  {
   "bredd": 1080,
   "hojd": 2880,
   "markeringar": [
    {
     "grepp": [
      462.4,
      1426.9
     ],
     "hosel": [
      252.3,
      1790.7
     ],
     "position": "P1",
     "t": 1.116667
    },
    {
     "grepp": [
      485.4,
      1345.2
     ],
     "hosel": [
      239.6,
      1517.2
     ],
     "position": "P2",
     "t": 1.591667
    },
    {
     "grepp": [
      512.9,
      1248.8
     ],
     "hosel": [
      551.1,
      1032.2
     ],
     "position": "P3",
     "t": 1.816667
    },
    {
     "grepp": [
      543.5,
      1147.8
     ],
     "hosel": [
      496.9,
      1321.6
     ],
     "position": "P4",
     "t": 2.204167
    },
    {
     "grepp": [
      494.1,
      1259.2
     ],
     "hosel": [
      511.5,
      1060.0
     ],
     "position": "P5",
     "t": 2.3125
    },
    {
     "grepp": [
      466.1,
      1389.0
     ],
     "hosel": [
      267.0,
      1556.2
     ],
     "position": "P6",
     "t": 2.4
    },
    {
     "grepp": [
      462.6,
      1427.8
     ],
     "hosel": [
      441.4,
      1461.7
     ],
     "position": "P7",
     "t": 2.495833
    },
    {
     "grepp": [
      445.8,
      1335.9
     ],
     "hosel": [
      653.6,
      1215.9
     ],
     "position": "P8",
     "t": 2.808333
    },
    {
     "grepp": [
      410.6,
      1150.7
     ],
     "hosel": [
      479.1,
      962.7
     ],
     "position": "P9",
     "t": 3.125
    },
    {
     "grepp": [
      400.9,
      1107.1
     ],
     "hosel": [
      548.7,
      1081.1
     ],
     "position": "P10",
     "t": 3.6
    }
   ],
   "matt": {
    "skaft_mot_plan_p2": -25.010284063631573,
    "skaft_plan_p6": 26.420101189743523,
    "skaft_riktning_topp": 14.323097812421384,
    "skaft_vinkel_p1": -59.992916641381875,
    "skaft_vinkel_p10": 170.0229837141572,
    "skaft_vinkel_p2": -34.9826325777503,
    "skaft_vinkel_p3": 100.0019435836473,
    "skaft_vinkel_p4": -74.99064059094428,
    "skaft_vinkel_p5": 94.99208116609164,
    "skaft_vinkel_p6": -40.02283465361934,
    "skaft_vinkel_p8": 149.99449667149614,
    "skaft_vinkel_p9": 110.01980321597253,
    "skaftplan_p1": 59.992916641381875
   },
   "osakerhet": {
    "100.0": 2.4308540536241865,
    "300.0": 0.8102846845413956,
    "40.0": 6.077135134060467,
    "60.0": 4.0514234227069785
   },
   "sving": "dtl_vanster"
  },
  {
   "bredd": 1080,
   "hojd": 2880,
   "markeringar": [
    {
     "grepp": [
      535.8,
      1379.5
     ],
     "hosel": [
      498.3,
      1807.9
     ],
     "position": "P1",
     "t": 1.116667
    },
    {
     "grepp": [
      413.2,
      1298.8
     ],
     "hosel": [
      94.5,
      1271.0
     ],
     "position": "P2",
     "t": 1.583333
    },
    {
     "grepp": [
      350.1,
      1136.0
     ],
     "hosel": [
      189.4,
      944.4
     ],
     "position": "P3",
     "t": 1.795833
    },
    {
     "grepp": [
      416.7,
      950.7
     ],
     "hosel": [
      672.8,
      905.5
     ],
     "position": "P4",
     "t": 2.191667
    },
    {
     "grepp": [
      337.6,
      1122.4
     ],
     "hosel": [
      289.0,
      846.7
     ],
     "position": "P5",
     "t": 2.308333
    },
    {
     "grepp": [
      445.6,
      1335.3
     ],
     "hosel": [
      146.7,
      1309.2
     ],
     "position": "P6",
     "t": 2.404167
    },
    {
     "grepp": [
      498.4,
      1359.5
     ],
     "hosel": [
      394.4,
      1776.7
     ],
     "position": "P7",
     "t": 2.4875
    },
    {
     "grepp": [
      687.3,
      1344.2
     ],
     "hosel": [
      996.1,
      1317.1
     ],
     "position": "P8",
     "t": 2.8125
    },
    {
     "grepp": [
      827.9,
      1147.3
     ],
     "hosel": [
      869.5,
      911.0
     ],
     "position": "P9",
     "t": 3.125
    },
    {
     "grepp": [
      815.0,
      1107.8
     ],
     "hosel": [
      1002.9,
      1176.2
     ],
     "position": "P10",
     "t": 3.6
    }
   ],
   "matt": {
    "skaft_arm_p5": 99.78723867292791,
    "skaft_arm_p6": 114.05472206121556,
    "skaft_lutning_traff": 13.99746022959456,
    "skaft_topp": 10.009256075682403,
    "skaft_vinkel_p1": -95.00263550333057,
    "skaft_vinkel_p10": -20.00269063718537,
    "skaft_vinkel_p2": 175.0147439441313,
    "skaft_vinkel_p3": 129.9874525318992,
    "skaft_vinkel_p4": 10.009256075682403,
    "skaft_vinkel_p5": 99.99730953410308,
    "skaft_vinkel_p6": 175.00958054943618,
    "skaft_vinkel_p7": -103.99746022959457,
    "skaft_vinkel_p8": 5.015374950250288,
    "skaft_vinkel_p9": 80.01553665711698
   },
   "osakerhet": {
    "100.0": 2.4308540536241865,
    "300.0": 0.8102846845413956,
    "40.0": 6.077135134060467,
    "60.0": 4.0514234227069785
   },
   "sving": "fo"
  },
  {
   "bredd": 1080,
   "hojd": 2880,
   "markeringar": [
    {
     "grepp": [
      545.5,
      1383.8
     ],
     "hosel": [
      583.0,
      1812.2
     ],
     "position": "P1",
     "t": 1.120833
    },
    {
     "grepp": [
      733.5,
      1148.4
     ],
     "hosel": [
      1052.3,
      1120.5
     ],
     "position": "P2",
     "t": 1.779167
    },
    {
     "grepp": [
      665.2,
      945.8
     ],
     "hosel": [
      409.1,
      900.7
     ],
     "position": "P4",
     "t": 2.195833
    },
    {
     "grepp": [
      723.3,
      1239.9
     ],
     "hosel": [
      1022.2,
      1213.8
     ],
     "position": "P6",
     "t": 2.35
    },
    {
     "grepp": [
      582.1,
      1362.7
     ],
     "hosel": [
      686.1,
      1779.9
     ],
     "position": "P7",
     "t": 2.495833
    },
    {
     "grepp": null,
     "hosel": null,
     "position": "P8",
     "t": 2.816667
    },
    {
     "grepp": [
      249.6,
      1150.9
     ],
     "hosel": [
      207.9,
      914.5
     ],
     "position": "P9",
     "t": 3.125
    },
    {
     "grepp": [
      261.5,
      1110.6
     ],
     "hosel": [
      73.6,
      1179.0
     ],
     "position": "P10",
     "t": 3.6
    }
   ],
   "matt": {
    "skaft_lutning_traff": 13.99746022959456,
    "skaft_topp": 9.987558049750769,
    "skaft_vinkel_p1": -95.00263550333058,
    "skaft_vinkel_p10": -20.00269063718537,
    "skaft_vinkel_p2": 174.99846361504643,
    "skaft_vinkel_p4": 9.987558049750769,
    "skaft_vinkel_p6": 175.00958054943612,
    "skaft_vinkel_p7": -103.99746022959457,
    "skaft_vinkel_p9": 79.99616815913298
   },
   "osakerhet": {
    "100.0": 2.4308540536241865,
    "300.0": 0.8102846845413956,
    "40.0": 6.077135134060467,
    "60.0": 4.0514234227069785
   },
   "sving": "fo_vanster"
  }
 ],
 "fil": {
  "andrad": "2026-10-23T12:00:00+02:00",
  "format": "swinglab-klubba/2",
  "kalla": [
   "swinglab-20261103-180000-dtl.zip"
  ],
  "pass": "20261103-180000",
  "punkter": [
   "grepp",
   "skaft_mitt",
   "klubbhuvud"
  ],
  "rutor": [
   {
    "bredd": 1080,
    "fil": "swinglab-20261103-180000-dtl.zip",
    "forskjutning_ms": null,
    "forslag": {},
    "hojd": 2880,
    "id": "dtl-s03-P1",
    "punkter": {
     "grepp": {
      "kalla": "klick",
      "x": 617.8,
      "y": 1426.7
     },
     "klubbhuvud": {
      "kalla": "klick",
      "x": 827.8,
      "y": 1790.4
     },
     "skaft_mitt": null
    },
    "slag": "s03",
    "status": "markerad",
    "t": 1.116667,
    "t_klipp": null,
    "t_ruta": null,
    "val": "P1",
    "visad": [
     0,
     0,
     1080,
     2880
    ],
    "vy": "dtl"
   },
   {
    "bredd": 1080,
    "fil": "swinglab-20261103-180000-dtl.zip",
    "forskjutning_ms": null,
    "forslag": {},
    "hojd": 2880,
    "id": "dtl-s03-P2",
    "punkter": {
     "grepp": {
      "kalla": "klick",
      "x": 594.0,
      "y": 1344.6
     },
     "klubbhuvud": {
      "kalla": "klick",
      "x": 839.8,
      "y": 1516.7
     },
     "skaft_mitt": null
    },
    "slag": "s03",
    "status": "markerad",
    "t": 1.591667,
    "t_klipp": null,
    "t_ruta": null,
    "val": "P2",
    "visad": [
     0,
     0,
     1080,
     2880
    ],
    "vy": "dtl"
   },
   {
    "bredd": 1080,
    "fil": "swinglab-20261103-180000-dtl.zip",
    "forskjutning_ms": null,
    "forslag": {},
    "hojd": 2880,
    "id": "dtl-s03-P3",
    "punkter": {
     "grepp": {
      "kalla": "klick",
      "x": 566.3,
      "y": 1248.6
     },
     "klubbhuvud": {
      "kalla": "klick",
      "x": 528.1,
      "y": 1031.9
     },
     "skaft_mitt": null
    },
    "slag": "s03",
    "status": "markerad",
    "t": 1.816667,
    "t_klipp": null,
    "t_ruta": null,
    "val": "P3",
    "visad": [
     0,
     0,
     1080,
     2880
    ],
    "vy": "dtl"
   },
   {
    "bredd": 1080,
    "fil": "swinglab-20261103-180000-dtl.zip",
    "forskjutning_ms": null,
    "forslag": {},
    "hojd": 2880,
    "id": "dtl-s03-P4",
    "punkter": {
     "grepp": {
      "kalla": "klick",
      "x": 537.7,
      "y": 1146.7
     },
     "klubbhuvud": {
      "kalla": "klick",
      "x": 584.2,
      "y": 1320.5
     },
     "skaft_mitt": null
    },
    "slag": "s03",
    "status": "markerad",
    "t": 2.191667,
    "t_klipp": null,
    "t_ruta": null,
    "val": "P4",
    "visad": [
     0,
     0,
     1080,
     2880
    ],
    "vy": "dtl"
   },
   {
    "bredd": 1080,
    "fil": "swinglab-20261103-180000-dtl.zip",
    "forskjutning_ms": null,
    "forslag": {},
    "hojd": 2880,
    "id": "dtl-s03-P5",
    "punkter": {
     "grepp": {
      "kalla": "klick",
      "x": 582.5,
      "y": 1252.5
     },
     "klubbhuvud": {
      "kalla": "klick",
      "x": 565.0,
      "y": 1053.3
     },
     "skaft_mitt": null
    },
    "slag": "s03",
    "status": "markerad",
    "t": 2.308333,
    "t_klipp": null,
    "t_ruta": null,
    "val": "P5",
    "visad": [
     0,
     0,
     1080,
     2880
    ],
    "vy": "dtl"
   },
   {
    "bredd": 1080,
    "fil": "swinglab-20261103-180000-dtl.zip",
    "forskjutning_ms": null,
    "forslag": {},
    "hojd": 2880,
    "id": "dtl-s03-P6",
    "punkter": {
     "grepp": {
      "kalla": "klick",
      "x": 614.8,
      "y": 1397.5
     },
     "klubbhuvud": {
      "kalla": "klick",
      "x": 813.9,
      "y": 1564.6
     },
     "skaft_mitt": null
    },
    "slag": "s03",
    "status": "markerad",
    "t": 2.408333,
    "t_klipp": null,
    "t_ruta": null,
    "val": "P6",
    "visad": [
     0,
     0,
     1080,
     2880
    ],
    "vy": "dtl"
   },
   {
    "bredd": 1080,
    "fil": "swinglab-20261103-180000-dtl.zip",
    "forskjutning_ms": null,
    "forslag": {},
    "hojd": 2880,
    "id": "dtl-s03-P7",
    "punkter": {
     "grepp": {
      "kalla": "klick",
      "x": 617.7,
      "y": 1427.1
     },
     "klubbhuvud": {
      "kalla": "klick",
      "x": 638.9,
      "y": 1461.0
     },
     "skaft_mitt": null
    },
    "slag": "s03",
    "status": "markerad",
    "t": 2.5,
    "t_klipp": null,
    "t_ruta": null,
    "val": "P7",
    "visad": [
     0,
     0,
     1080,
     2880
    ],
    "vy": "dtl"
   },
   {
    "bredd": 1080,
    "fil": "swinglab-20261103-180000-dtl.zip",
    "forskjutning_ms": null,
    "forslag": {},
    "hojd": 2880,
    "id": "dtl-s03-P8",
    "punkter": {
     "grepp": {
      "kalla": "klick",
      "x": 635.6,
      "y": 1333.3
     },
     "klubbhuvud": {
      "kalla": "klick",
      "x": 427.8,
      "y": 1213.3
     },
     "skaft_mitt": null
    },
    "slag": "s03",
    "status": "markerad",
    "t": 2.8125,
    "t_klipp": null,
    "t_ruta": null,
    "val": "P8",
    "visad": [
     0,
     0,
     1080,
     2880
    ],
    "vy": "dtl"
   },
   {
    "bredd": 1080,
    "fil": "swinglab-20261103-180000-dtl.zip",
    "forskjutning_ms": null,
    "forslag": {},
    "hojd": 2880,
    "id": "dtl-s03-P9",
    "punkter": {
     "grepp": {
      "kalla": "klick",
      "x": 669.3,
      "y": 1150.9
     },
     "klubbhuvud": {
      "kalla": "klick",
      "x": 600.9,
      "y": 963.0
     },
     "skaft_mitt": null
    },
    "slag": "s03",
    "status": "markerad",
    "t": 3.125,
    "t_klipp": null,
    "t_ruta": null,
    "val": "P9",
    "visad": [
     0,
     0,
     1080,
     2880
    ],
    "vy": "dtl"
   },
   {
    "bredd": 1080,
    "fil": "swinglab-20261103-180000-dtl.zip",
    "forskjutning_ms": null,
    "forslag": {},
    "hojd": 2880,
    "id": "dtl-s03-P10",
    "punkter": {
     "grepp": {
      "kalla": "klick",
      "x": 678.7,
      "y": 1107.8
     },
     "klubbhuvud": {
      "kalla": "klick",
      "x": 530.9,
      "y": 1081.8
     },
     "skaft_mitt": null
    },
    "slag": "s03",
    "status": "markerad",
    "t": 3.604167,
    "t_klipp": null,
    "t_ruta": null,
    "val": "P10",
    "visad": [
     0,
     0,
     1080,
     2880
    ],
    "vy": "dtl"
   }
  ]
 },
 "forslag": [
  {
   "position": "P2",
   "positioner": {
    "P1": -1.4,
    "P3": -0.5,
    "P4": -0.3
   },
   "start": -0.9,
   "tid": -0.7
  },
  {
   "position": "P2",
   "positioner": {
    "P1": -1.4,
    "P3": null,
    "P4": -0.3
   },
   "start": null,
   "tid": -0.85
  },
  {
   "position": "P6",
   "positioner": {
    "P4": -0.3,
    "P5": -0.12,
    "P7": 0.0
   },
   "start": null,
   "tid": -0.06
  },
  {
   "position": "P6",
   "positioner": {
    "P4": -0.3,
    "P5": null,
    "P7": 0.0
   },
   "start": null,
   "tid": -0.15
  },
  {
   "position": "P8",
   "positioner": {
    "P10": 1.1,
    "P7": 0.0,
    "P9": 0.2
   },
   "start": null,
   "tid": 0.1
  },
  {
   "position": "P8",
   "positioner": {
    "P10": 1.1,
    "P7": 0.0,
    "P9": null
   },
   "start": null,
   "tid": 0.55
  },
  {
   "position": "P4",
   "positioner": {
    "P4": -0.3
   },
   "start": null,
   "tid": -0.3
  }
 ]
}
"""#
}
