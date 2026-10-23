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
      782.8,
      1712.4
     ],
     "position": "P1",
     "t": 1.116667
    },
    {
     "grepp": [
      608.0,
      1392.5
     ],
     "hosel": [
      640.8,
      1415.4
     ],
     "position": "P2",
     "t": 1.4625
    },
    {
     "grepp": [
      566.3,
      1248.6
     ],
     "hosel": [
      540.3,
      1100.9
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
      558.4,
      1223.9
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
      569.4,
      1103.1
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
      649.2,
      1426.4
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
      776.7,
      1681.5
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
      605.3,
      1315.8
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
      618.0,
      1009.9
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
      560.5,
      1087.0
     ],
     "position": "P10",
     "t": 3.604167
    }
   ],
   "matt": {
    "skaft_plan_p6": 4.9688504513687235,
    "skaft_riktning_topp": 16.02562407952495,
    "skaft_vinkel_p1": -59.99232551219283,
    "skaft_vinkel_p10": 170.01967526905952,
    "skaft_vinkel_p3": 99.98363534871174,
    "skaft_vinkel_p4": -74.99008285069358,
    "skaft_vinkel_p5": 95.01111070959433,
    "skaft_vinkel_p7": -57.99461679191651,
    "skaft_vinkel_p9": 109.99289397986985,
    "skaftplan_p1": 59.99232551219283
   },
   "pinne": [
    [
     585.0,
     2700.0
    ],
    [
     560.0,
     2100.0
    ]
   ],
   "sd": {
    "skaft_plan_p6": 0.7553964298015731,
    "skaft_riktning_topp": 3.0171191887949984,
    "skaft_vinkel_p1": 0.7367936123576231,
    "skaft_vinkel_p10": 2.0254298712676633,
    "skaft_vinkel_p3": 1.620878525460461,
    "skaft_vinkel_p4": 3.0413218683276853,
    "skaft_vinkel_p5": 1.6208529865867465,
    "skaft_vinkel_p7": 0.8102835261041383,
    "skaft_vinkel_p9": 1.6201115174548835,
    "skaftplan_p1": 0.7367936123576231
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
      297.4,
      1712.7
     ],
     "position": "P1",
     "t": 1.116667
    },
    {
     "grepp": [
      472.1,
      1390.0
     ],
     "hosel": [
      439.3,
      1412.9
     ],
     "position": "P2",
     "t": 1.466667
    },
    {
     "grepp": [
      512.9,
      1248.8
     ],
     "hosel": [
      538.9,
      1101.1
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
      522.7,
      1225.0
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
      507.1,
      1109.8
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
      431.7,
      1418.0
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
      303.6,
      1682.2
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
      476.1,
      1318.4
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
      462.0,
      1009.7
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
      519.1,
      1086.3
     ],
     "position": "P10",
     "t": 3.6
    }
   ],
   "matt": {
    "skaft_plan_p6": 5.499398454317531,
    "skaft_riktning_topp": 14.392872378326745,
    "skaft_vinkel_p1": -60.00100844018335,
    "skaft_vinkel_p10": 170.01967526905952,
    "skaft_vinkel_p3": 99.98363534871173,
    "skaft_vinkel_p4": -74.92086602503892,
    "skaft_vinkel_p5": 94.97305051838524,
    "skaft_vinkel_p7": -57.99461679191651,
    "skaft_vinkel_p9": 110.02877091580544,
    "skaftplan_p1": 60.00100844018335
   },
   "pinne": null,
   "sd": {
    "skaft_plan_p6": 0.7454030875583343,
    "skaft_riktning_topp": 2.672058496037277,
    "skaft_vinkel_p1": 0.7366002661244564,
    "skaft_vinkel_p10": 2.0254298712676633,
    "skaft_vinkel_p3": 1.620878525460461,
    "skaft_vinkel_p4": 3.040334673516042,
    "skaft_vinkel_p5": 1.6209470317033052,
    "skaft_vinkel_p7": 0.8102835261041383,
    "skaft_vinkel_p9": 1.619742122068857,
    "skaftplan_p1": 0.7366002661244564
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
      510.9,
      1663.4
     ],
     "position": "P1",
     "t": 1.116667
    },
    {
     "grepp": [
      478.6,
      1354.7
     ],
     "hosel": [
      169.8,
      1327.7
     ],
     "position": "P2",
     "t": 1.458333
    },
    {
     "grepp": [
      350.1,
      1136.0
     ],
     "hosel": [
      208.6,
      967.4
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
      692.4,
      902.0
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
      296.0,
      886.0
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
      136.8,
      1308.3
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
      428.3,
      1640.9
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
      866.1,
      930.7
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
      965.4,
      1162.5
     ],
     "position": "P10",
     "t": 3.6
    }
   ],
   "matt": {
    "skaft_arm_p5": 99.77025386976533,
    "skaft_arm_p6": 114.04817960602566,
    "skaft_lutning_traff": 13.988325289324301,
    "skaft_topp": 10.01746389479782,
    "skaft_vinkel_p1": -95.01241103249662,
    "skaft_vinkel_p10": -19.986165233167277,
    "skaft_vinkel_p2": 175.00303809424628,
    "skaft_vinkel_p3": 130.00554391594815,
    "skaft_vinkel_p4": 10.01746389479782,
    "skaft_vinkel_p5": 99.98032473094051,
    "skaft_vinkel_p6": 175.00303809424628,
    "skaft_vinkel_p7": -103.98832528932431,
    "skaft_vinkel_p8": 5.015374950250288,
    "skaft_vinkel_p9": 79.9980564163527
   },
   "pinne": null,
   "sd": {
    "skaft_arm_p5": 1.012718305688936,
    "skaft_arm_p6": 0.7842011583324106,
    "skaft_lutning_traff": 0.8382252202207042,
    "skaft_topp": 0.8682601372745952,
    "skaft_vinkel_p1": 0.8529607738275795,
    "skaft_vinkel_p10": 1.5189195505407267,
    "skaft_vinkel_p2": 0.7842011583324106,
    "skaft_vinkel_p3": 1.104385558726577,
    "skaft_vinkel_p4": 0.8682601372745952,
    "skaft_vinkel_p5": 1.012718305688936,
    "skaft_vinkel_p6": 0.7842011583324106,
    "skaft_vinkel_p7": 0.8382252202207042,
    "skaft_vinkel_p8": 0.7841790829767752,
    "skaft_vinkel_p9": 1.1052199628147907
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
      570.3,
      1667.7
     ],
     "position": "P1",
     "t": 1.120833
    },
    {
     "grepp": [
      703.2,
      1247.8
     ],
     "hosel": [
      1012.0,
      1220.8
     ],
     "position": "P2",
     "t": 1.658333
    },
    {
     "grepp": [
      665.2,
      945.8
     ],
     "hosel": [
      389.5,
      897.2
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
      1032.1,
      1212.9
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
      652.3,
      1644.1
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
      211.4,
      934.2
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
      111.1,
      1165.3
     ],
     "position": "P10",
     "t": 3.6
    }
   ],
   "matt": {
    "skaft_lutning_traff": 14.007494960799107,
    "skaft_topp": 9.997309534103053,
    "skaft_vinkel_p1": -94.99238280537982,
    "skaft_vinkel_p10": -19.986165233167274,
    "skaft_vinkel_p2": 175.00303809424628,
    "skaft_vinkel_p4": 9.997309534103053,
    "skaft_vinkel_p6": 175.00303809424628,
    "skaft_vinkel_p7": -104.00749496079912,
    "skaft_vinkel_p9": 80.0025788520285
   },
   "pinne": null,
   "sd": {
    "skaft_lutning_traff": 0.8381553113930739,
    "skaft_topp": 0.8683140322607615,
    "skaft_vinkel_p1": 0.852986871919944,
    "skaft_vinkel_p10": 1.5189195505407267,
    "skaft_vinkel_p2": 0.7842011583324106,
    "skaft_vinkel_p4": 0.8683140322607615,
    "skaft_vinkel_p6": 0.7842011583324106,
    "skaft_vinkel_p7": 0.838155311393103,
    "skaft_vinkel_p9": 1.1047253153451293
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
      "kalla": "handlederna_bekraftad",
      "x": 617.8,
      "y": 1426.7
     },
     "klubbhuvud": {
      "kalla": "klick",
      "x": 782.8,
      "y": 1712.4
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
      "x": 608.0,
      "y": 1392.5
     },
     "klubbhuvud": {
      "kalla": "klick",
      "x": 640.8,
      "y": 1415.4
     },
     "skaft_mitt": null
    },
    "slag": "s03",
    "status": "markerad",
    "t": 1.4625,
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
      "x": 540.3,
      "y": 1100.9
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
      "x": 558.4,
      "y": 1223.9
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
      "x": 569.4,
      "y": 1103.1
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
      "x": 649.2,
      "y": 1426.4
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
      "x": 776.7,
      "y": 1681.5
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
      "x": 605.3,
      "y": 1315.8
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
      "x": 618.0,
      "y": 1009.9
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
      "x": 560.5,
      "y": 1087.0
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
   "tid": -0.95
  },
  {
   "position": "P2",
   "positioner": {
    "P1": -1.4,
    "P3": null,
    "P4": -0.3
   },
   "tid": -0.85
  },
  {
   "position": "P6",
   "positioner": {
    "P4": -0.3,
    "P5": -0.12,
    "P7": 0.0
   },
   "tid": -0.06
  },
  {
   "position": "P6",
   "positioner": {
    "P4": -0.3,
    "P5": null,
    "P7": 0.0
   },
   "tid": -0.15
  },
  {
   "position": "P8",
   "positioner": {
    "P10": 1.1,
    "P7": 0.0,
    "P9": 0.2
   },
   "tid": 0.1
  },
  {
   "position": "P8",
   "positioner": {
    "P10": 1.1,
    "P7": 0.0,
    "P9": null
   },
   "tid": 0.55
  },
  {
   "position": "P4",
   "positioner": {
    "P4": -0.3
   },
   "tid": -0.3
  }
 ],
 "forslag_skaft": [
  {
   "markeringar": [
    {
     "grepp": [
      535.8,
      1379.5
     ],
     "hosel": [
      510.9,
      1663.4
     ],
     "position": "P1",
     "t": 1.116667
    },
    {
     "grepp": [
      478.6,
      1354.7
     ],
     "hosel": [
      169.8,
      1327.7
     ],
     "position": "P2",
     "t": 1.458333
    },
    {
     "grepp": [
      350.1,
      1136.0
     ],
     "hosel": [
      208.6,
      967.4
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
      692.4,
      902.0
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
      296.0,
      886.0
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
      136.8,
      1308.3
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
      428.3,
      1640.9
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
      866.1,
      930.7
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
      965.4,
      1162.5
     ],
     "position": "P10",
     "t": 3.6
    }
   ],
   "position": "P2",
   "tid": 1.544284471839736,
   "x_tecken": 1.0
  },
  {
   "markeringar": [
    {
     "grepp": [
      535.8,
      1379.5
     ],
     "hosel": [
      510.9,
      1663.4
     ],
     "position": "P1",
     "t": 1.116667
    },
    {
     "grepp": [
      478.6,
      1354.7
     ],
     "hosel": [
      169.8,
      1327.7
     ],
     "position": "P2",
     "t": 1.458333
    },
    {
     "grepp": [
      350.1,
      1136.0
     ],
     "hosel": [
      208.6,
      967.4
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
      692.4,
      902.0
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
      296.0,
      886.0
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
      136.8,
      1308.3
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
      428.3,
      1640.9
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
      866.1,
      930.7
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
      965.4,
      1162.5
     ],
     "position": "P10",
     "t": 3.6
    }
   ],
   "position": "P6",
   "tid": 2.4002176447255223,
   "x_tecken": 1.0
  },
  {
   "markeringar": [
    {
     "grepp": [
      535.8,
      1379.5
     ],
     "hosel": [
      510.9,
      1663.4
     ],
     "position": "P1",
     "t": 1.116667
    },
    {
     "grepp": [
      478.6,
      1354.7
     ],
     "hosel": [
      169.8,
      1327.7
     ],
     "position": "P2",
     "t": 1.458333
    },
    {
     "grepp": [
      350.1,
      1136.0
     ],
     "hosel": [
      208.6,
      967.4
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
      692.4,
      902.0
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
      296.0,
      886.0
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
      136.8,
      1308.3
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
      428.3,
      1640.9
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
      866.1,
      930.7
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
      965.4,
      1162.5
     ],
     "position": "P10",
     "t": 3.6
    }
   ],
   "position": "P8",
   "tid": 2.847812305494395,
   "x_tecken": 1.0
  },
  {
   "markeringar": [
    {
     "grepp": [
      545.5,
      1383.8
     ],
     "hosel": [
      570.3,
      1667.7
     ],
     "position": "P1",
     "t": 1.120833
    },
    {
     "grepp": [
      703.2,
      1247.8
     ],
     "hosel": [
      1012.0,
      1220.8
     ],
     "position": "P2",
     "t": 1.658333
    },
    {
     "grepp": [
      665.2,
      945.8
     ],
     "hosel": [
      389.5,
      897.2
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
      1032.1,
      1212.9
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
      652.3,
      1644.1
     ],
     "position": "P7",
     "t": 2.495833
    },
    {
     "grepp": [
      390.6,
      1346.4
     ],
     "hosel": [
      81.8,
      1319.4
     ],
     "position": "P8",
     "t": 2.816667
    },
    {
     "grepp": [
      249.6,
      1150.9
     ],
     "hosel": [
      211.4,
      934.2
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
      111.1,
      1165.3
     ],
     "position": "P10",
     "t": 3.6
    }
   ],
   "position": "P2",
   "tid": null,
   "x_tecken": -1.0
  },
  {
   "markeringar": [
    {
     "grepp": [
      545.5,
      1383.8
     ],
     "hosel": [
      570.3,
      1667.7
     ],
     "position": "P1",
     "t": 1.120833
    },
    {
     "grepp": [
      703.2,
      1247.8
     ],
     "hosel": [
      1012.0,
      1220.8
     ],
     "position": "P2",
     "t": 1.658333
    },
    {
     "grepp": [
      665.2,
      945.8
     ],
     "hosel": [
      389.5,
      897.2
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
      1032.1,
      1212.9
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
      652.3,
      1644.1
     ],
     "position": "P7",
     "t": 2.495833
    },
    {
     "grepp": [
      390.6,
      1346.4
     ],
     "hosel": [
      81.8,
      1319.4
     ],
     "position": "P8",
     "t": 2.816667
    },
    {
     "grepp": [
      249.6,
      1150.9
     ],
     "hosel": [
      211.4,
      934.2
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
      111.1,
      1165.3
     ],
     "position": "P10",
     "t": 3.6
    }
   ],
   "position": "P6",
   "tid": null,
   "x_tecken": -1.0
  },
  {
   "markeringar": [
    {
     "grepp": [
      545.5,
      1383.8
     ],
     "hosel": [
      570.3,
      1667.7
     ],
     "position": "P1",
     "t": 1.120833
    },
    {
     "grepp": [
      703.2,
      1247.8
     ],
     "hosel": [
      1012.0,
      1220.8
     ],
     "position": "P2",
     "t": 1.658333
    },
    {
     "grepp": [
      665.2,
      945.8
     ],
     "hosel": [
      389.5,
      897.2
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
      1032.1,
      1212.9
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
      652.3,
      1644.1
     ],
     "position": "P7",
     "t": 2.495833
    },
    {
     "grepp": [
      390.6,
      1346.4
     ],
     "hosel": [
      81.8,
      1319.4
     ],
     "position": "P8",
     "t": 2.816667
    },
    {
     "grepp": [
      249.6,
      1150.9
     ],
     "hosel": [
      211.4,
      934.2
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
      111.1,
      1165.3
     ],
     "position": "P10",
     "t": 3.6
    }
   ],
   "position": "P8",
   "tid": 2.8514552886392828,
   "x_tecken": -1.0
  },
  {
   "markeringar": [
    {
     "grepp": [
      500.0,
      1300.0
     ],
     "hosel": [
      480.0,
      1585.0
     ],
     "position": "P1",
     "t": -1.2
    },
    {
     "grepp": [
      380.0,
      1100.0
     ],
     "hosel": [
      210.0,
      1240.0
     ],
     "position": "P3",
     "t": -0.5
    }
   ],
   "position": "P2",
   "tid": null,
   "x_tecken": 1.0
  }
 ],
 "yta": [
  {
   "bredd": 1080,
   "hojd": 1920,
   "punkt": [
    540.0,
    960.0
   ],
   "u": 0.5,
   "utsnitt": null,
   "v": 0.5,
   "visad": [
    0,
    0,
    1080,
    1920
   ],
   "vy": "dtl"
  },
  {
   "bredd": 1080,
   "hojd": 1920,
   "punkt": [
    310.5,
    1142.5
   ],
   "u": 0.25,
   "utsnitt": [
    0.2,
    0.1,
    0.5,
    0.6
   ],
   "v": 0.75,
   "visad": [
    135,
    19,
    702,
    1498
   ],
   "vy": "dtl"
  },
  {
   "bredd": 1080,
   "hojd": 1920,
   "punkt": [
    33.48,
    1872.074
   ],
   "u": 0.031,
   "utsnitt": [
    0.0,
    0.3,
    0.9,
    0.7
   ],
   "v": 0.969,
   "visad": [
    0,
    374,
    1080,
    1546
   ],
   "vy": "dtl"
  },
  {
   "bredd": 1080,
   "hojd": 1920,
   "punkt": [
    658.08,
    483.36
   ],
   "u": 0.62,
   "utsnitt": [
    0.15,
    0.2,
    0.7,
    0.75
   ],
   "v": 0.18,
   "visad": [
    48,
    168,
    984,
    1752
   ],
   "vy": "fo"
  },
  {
   "bredd": 1080,
   "hojd": 1920,
   "punkt": [
    869.9399999999999,
    458.22
   ],
   "u": 0.97,
   "utsnitt": [
    0.25,
    0.3,
    0.5,
    0.55
   ],
   "v": 0.03,
   "visad": [
    189,
    417,
    702,
    1374
   ],
   "vy": "fo"
  }
 ]
}
"""#
}
