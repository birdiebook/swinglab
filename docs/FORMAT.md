# Format

Filerna som telefonen och PC:n delar. Samma format läses av SwingLabKit
(`Swing.Sving.las`) och `tools/pc/format.py`. En påhittad sving i formatet:
`python3 tools/pc/generera.py fo`.

Repot bär aldrig en riktig sving i det här formatet (CLAUDE.md, Dataregeln).

## En sving

En sving är ett JSON-objekt:

```json
{
  "format": 1,
  "vy": "fo",
  "hand": "hoger",
  "x_mot_malet": 1,
  "spelarens_langd_m": 1.80,
  "t_klick": 2.5,
  "rutor": [
    {"t": 0.0042, "leder": [[540.1, 812.4, 0.93], [601.0, 960.2, 0.88], "… 13 st"]},
    {"t": 0.0125, "leder": ["…"]}
  ]
}
```

| Fält | Typ | Betydelse |
|---|---|---|
| `format` | heltal | `1`. Ett nytt format får ett nytt tal. |
| `vy` | text | `"dtl"` (down the line, bakom spelaren längs mållinjen) eller `"fo"` (face on, framför spelaren). |
| `hand` | text | `"hoger"` eller `"vanster"`. Koden räknar som för en högerspelare; en vänsterspelare speglas (METOD M1). |
| `x_mot_malet` | +1 / −1 | **FO.** +1 = målet ligger åt +x i bilden (standard för en högerspelare). |
| `x_mot_bollen` | +1 / −1 | **DTL.** +1 = bollen ligger åt +x i bilden (standard för en högerspelare). |
| `spelarens_langd_m` | tal | Kroppslängden i meter, 1,0–2,5. Ger skalan (METOD M2). |
| `t_klick` | tal | Träffen: klicket i ljudet, s, i rutornas tidsskala. |
| `rutor` | lista | Rutorna, en per videobild med leder. |

Saknas riktningsfältet för vyn gäller +1 för `hoger` och −1 för `vanster`:
kameran står där den brukar, och vänsterspelaren är spegelvänd.

### Rutorna

| Fält | Typ | Betydelse |
|---|---|---|
| `t` | tal | Tiden i s. Stegen får vara ojämna: rutor utan leder saknas helt (i oktober 36 % av 240-rutnätet). Ordningen spelar ingen roll; läsaren sorterar. |
| `leder` | lista | Exakt 13 leder i ordningen nedan, var och en `[x, y, konfidens]`. |

`x` och `y` är bildens pixlar med origo uppe till vänster och **y nedåt**.
Konfidensen är 0–1; under 0,3 räknas leden som saknad i rutan (METOD M1), och
dess koordinater läses inte.

### Lederna

Snittet av Apple Visions 2D-leder (`VNHumanBodyPoseObservation`) och MediaPipe
Pose. Vänster och höger är spelarens egna.

| Index | Namn | Vision | MediaPipe |
|---|---|---|---|
| 0 | `nasa` | nose | 0 |
| 1 | `axel_v` | leftShoulder | 11 |
| 2 | `axel_h` | rightShoulder | 12 |
| 3 | `armbage_v` | leftElbow | 13 |
| 4 | `armbage_h` | rightElbow | 14 |
| 5 | `handled_v` | leftWrist | 15 |
| 6 | `handled_h` | rightWrist | 16 |
| 7 | `hoft_v` | leftHip | 23 |
| 8 | `hoft_h` | rightHip | 24 |
| 9 | `kna_v` | leftKnee | 25 |
| 10 | `kna_h` | rightKnee | 26 |
| 11 | `fotled_v` | leftAnkle | 27 |
| 12 | `fotled_h` | rightAnkle | 28 |

Vision ger y uppåt och normerat 0–1: appen räknar om till pixlar med y nedåt
innan svingen sparas.

### Fel

Ett fel nämner fältet och rutans plats i filen (`ruta 12, armbage_h: …`),
aldrig värdet, så att ett fel går att klistra in utan att data följer med.

## Resultatet för en sving

`matt.mat` (Python) och `Matt.mat` (Swift) ger:

| Fält | Betydelse |
|---|---|
| `cm_per_px` | Skalan (METOD M2). |
| `faser` | `start` (s eller `null`), `topp`, `traff` (METOD M4). |
| `matt` | Måtten per namn (METOD M5–M24). Ett mått som inte gick att räkna står inte med. |

Måttens namn och vilka vyer som ger dem: `MATT_DTL` och `MATT_FO` i
`tools/pc/matt.py` (Swift: `Matt.namn`). Tecknen står i varje METOD-rad.

## Katalogen: `katalog.json`

I repots rot (BESLUT B6). `{"version": 1, "om": "…", "fel": [ … ]}`, där varje fel har:

| Fält | Typ | Betydelse |
|---|---|---|
| `id` | text | Unikt. |
| `namn` | text | Det Johannes ser. |
| `vy` | text | `"dtl"`, `"fo"` eller `"bada"` (måttet över alla svingar, tempot). |
| `matt` | text | Måttets namn; måste finnas i vyn. |
| `fas` | text | Var i svingen felet syns (`adress`, `topp`, `nedsving`, `traff`, `efter_traff`, `hela`). Bara för visningen. |
| `gront` | `[min, max]` eller `null` | Grönt spann; `null` i en ände = öppen. `null` = **egen baslinje**. |
| `gult` | `[min, max]` eller `null` | Gult spann runt det gröna. `null` med en grön gräns = allt utanför grönt är gult. |
| `kalla` | text | URL till källan för definitionen eller gränsen. |
| `status` | text | Gränsens status: `tillverkare`, `forskning`, `tranare` eller `antagande` (egen baslinje är `antagande`). |
| `kontrollerad` | bool | `false` tills källan lästs i original (BESLUT B10). |
| `aktiv` | bool | `false` = felet bedöms inte (axellutningen, METOD M17). |
| `samre` | `"+"`, `"-"` eller `null` | Åt vilket håll måttet blir sämre, för den egna baslinjen. `null` = båda. |
| `ovning` | text | Övningen. |
| `tanke` | text | Tanken under svingen, med extern fokus (research 3). |
| `notering` | text | Valfri. Varför gränsen ser ut som den gör. |

Bedömningen (grönt, gult, rött, okänt, av) står i METOD M27.
