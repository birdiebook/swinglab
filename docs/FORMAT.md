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

## Paketet: `swinglab-<pass>-<vy>.zip`

En zip per telefon och pass (BESLUT B27, S2_SPEC §8.3, där manifestets alla fält
står). PC:n (`tools/pc/paket.py`) läser och kräver:

| Fält i `manifest.json` | Krav |
|---|---|
| `format` | `"swinglab-paket/1"` |
| `pass` | `yyyyMMdd-HHmmss` |
| `vy` | `"dtl"` eller `"fo"` |
| `spelhand` | `"hoger"` eller `"vanster"` (blir svingens `hand`) |
| `avstand_m` | valfri, 0,5–20; ger träffen när `traff_s` saknas (METOD MT1) |
| `spelarens_langd_m` | **valfri, nytt i S5**: 1,0–2,5. Saknas den tas längden ur `--langd` eller historiken |
| `serier[]` | `nr` heltal, `klubba` valfri text |
| `slag[]` | `id` (`s01`…), `serie` (ett `nr`), `klick_s`, `traff_s` (valfri), `dom` (`sving`, `inte_sving`, `osaker`), `leder` (fil i zippen), `klipp` (valfri fil i zippen) med `klick_i_klipp_s` |

Övriga fält (`telefon`, `enhet.json`, `ljusprov.json`, `par.json`, `vision`)
läses inte än. Sökvägarna får inte börja med `/` eller innehålla `..`.

**`slag/s01.json`** är SwingLabKits `JointSeries` (S2_SPEC §6.3):

```json
{"source": "vision-2d-r1", "width": 1080, "height": 1920,
 "frames": [{"t": -2.4958, "pts": 9.8498, "confidence": 0.93,
             "joints": [{"x": 540.1, "y": 812.4, "c": 0.93}, null, "… 13 st"]}]}
```

`t` är sekunder relativt klicket, lederna i ordningen ovan (Lederna), i
pixlar i den upprätta bilden. En led är `{"x", "y", "c"}` (Swifts Codable) eller
`[x, y, c]`; `null` är saknad. PC:n gör om varje slag till en sving i
filformatet med `t_klick` = träffen (METOD MT1).

Felen nämner zippen, filen och fältet (`swinglab-…-fo.zip: manifest.json:
slag[3].klick_s ska vara ett tal`), aldrig värdet.

## Analysen: `analys.json`

`tools/pc/session.py <paket> [<paket>]` skriver passets analys
(`"format": "swinglab-analys/1"`), ett paket per vy. Allt i den är mekaniskt
(BESLUT B2).

| Fält | Innehåll |
|---|---|
| `pass`, `skapad`, `spelhand`, `spelarens_langd_m`, `klubbor` | passet |
| `paket[]` | `fil`, `vy`, antal `slag` och `klipp` |
| `slag[]` | per slag: `id`, `vy`, `serie`, `klubba`, `dom`, `plats`, `forsta_serien` (bool), och antingen `faser`, `cm_per_px`, `matt` (som `matt.mat`), `fel` (varför det inte gick att mäta) eller `utelamnat` |
| `session` | `sammanfatta_session` (METOD M25) över de mätta slagen: `dtl`, `fo`, `alla` |
| `forsta_serien` | samma sammanfattning för första serien (METOD MT2) |
| `baslinje` | `pass` (de tidigare passen) och antal `svingar` per vy |
| `forra` | `null`, eller `pass` och `jamforelse` (METOD M26) per grupp |
| `bedomning[]` | ett per fel i katalogen: `bedom_varde` (`id`, `varde`, `status`, `grund`, `z`) plus `namn`, `vy`, `matt`, `fas`, `enhet`, `visat` (avrundat, METOD MT3), `n`, `spann`, `gult`, `kontrollerad`, `kalla_status`, `samre`, `forsta_serien` (avrundad median), `klart_nar` (förslaget: `villkor`, `grans`, `grund`, `markning`, eller `null`), `mot_forra` (`skillnad`, `tydlig`) när förra passet finns |
| `kandidater[]` | de gula och röda felen i läsordning (METOD MT6): `fel`, `status`, `fas`, `orsaker` (flaggade orsaker med vägen genom kedjan), `foljdfel` (bool), `fysik` (kopplade test) |
| `kontaktark` | per vy `{"fil", "rader", "kolumner"}` eller `{"hoppat": skäl}` (METOD MT7) |

## Att jobba på: `att_jobba_pa.json`

Det Claude valt efter ett pass, tillbaka till telefonen (S2_SPEC §8.5, BESLUT
B28). Telefonen kräver bara att `format` börjar med `swinglab-att-jobba-pa/`;
`tools/pc/att_jobba_pa.py` kontrollerar resten, och med `--analys` att varje tal
är analysens.

```json
{
 "format": "swinglab-att-jobba-pa/1",
 "pass": "20261103-180000",
 "skapad": "2026-11-03T21:15:00+01:00",
 "saker": [{
  "ordning": 1,
  "fel": "sway_topp",
  "namn": "Bäckenet glider bakåt i baksvingen",
  "vy": "fo", "matt": "backen_sway_topp", "enhet": "cm",
  "nu": -5.7, "spann": [0, null], "markning": "B10",
  "ovning": {"text": "Käpp i marken …", "tanke": "Rör inte käppen.", "kalla": "katalog"},
  "klart_nar": {"villkor": ">=", "grans": 0, "pa": "forsta_serien", "pass_i_rad": 2},
  "foljdfel": ["reverse_spine", "backens_resa_framat", "sway_gap"],
  "typ": "teknik",
  "fysik": null
 }]
}
```

| Fält | Krav |
|---|---|
| `pass` | passet tolkningen bygger på; samma som analysens |
| `saker` | 1–3, i svingens ordning (METOD MT6) |
| `fel`, `namn`, `vy`, `matt`, `spann` | katalogens, för ett aktivt fel |
| `enhet` | måttets (`cm`, `°`, `s` eller tom) |
| `nu` | analysens `visat` för felet (passets median), eller `null` |
| `markning` | analysens: `"B10"` (gräns ej läst i original), `"egen"` (egen baslinje) eller `null` |
| `ovning.text` | högst 300 tecken; ordagrant katalogens när `kalla` är `"katalog"`, annars ur research 3 §2 (`"research3"`) |
| `ovning.tanke` | högst 60 tecken, extern fokus |
| `klart_nar` | analysens `villkor` (`>=`, `<=`, `mellan`) och `grans` (tal, eller `[min, max]`), `pa` = `"forsta_serien"`, `pass_i_rad` ≥ 1 |
| `foljdfel` | fel som mäts men inte övas; varje ett led efter saken i `tools/pc/kedjor.json`, och ingen vald sak |
| `typ` | `"teknik"`, `"teknik_kroppen_gor_det_svart"` eller `"troligen_rorlighet"`, enligt treregeln (METOD MT5) |
| `fysik` | `null`, eller `test` (ur `kedjor.json` för felet), `treregeln` (tre true/false från Johannes) och `ovning` (krävs utom för teknik) |

Ingen text bär värdeord eller utropstecken (BESLUT B13, METOD MT8). Rapporten
till Johannes står i chatten, inte i filen.

## Historiken: `data/historik/`

Gitignorerad, bara på PC:n (`tools/pc/historik.py`):

```
spelare.json                  {"spelarens_langd_m": 1.80}
pass/<pass>/analys.json       session.py
pass/<pass>/kontaktark-<vy>.png
att_jobba_pa/<pass>.json      sparad och kontrollerad med historik.py spara-att-jobba-pa
```

`historik.py minne` skriver `"format": "swinglab-minne/1"`: passen, varje fels
väg genom vintern (`varde`, `forsta_serien`, `status` per pass) och varje
övnings läge (`ny`, `fortsatt`, `byt_ovning`, `fysik`, `klart`; METOD MT4, MT5).
