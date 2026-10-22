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
| `positioner` | `P1`, `P3`, `P4`, `P5`, `P7`, `P9`, `P10`: tiden i s, eller `null` när positionen saknas (armen blev aldrig vågrät, eller passagen låg i en lucka, METOD M28). P1 och P10 är fönstrens mitt. P3 kan ligga upp till en ruta efter toppen och P5 en ruta före (rutparet över toppen). |
| `matt` | Måtten per namn (METOD M5–M24, M29). Ett mått som inte gick att räkna står inte med. |

Måttens namn och vilka vyer som ger dem: `MATT_DTL` och `MATT_FO` i
`tools/pc/matt.py` (Swift: `Matt.namn`). Tecknen står i varje METOD-rad.

## Katalogen: `katalog.json`

I repots rot (BESLUT B6). `{"version": 1, "om": "…", "fel": [ … ], "matt": [ … ]}`, där varje fel har:

| Fält | Typ | Betydelse |
|---|---|---|
| `id` | text | Unikt. |
| `namn` | text | Det Johannes ser, på engelska (BESLUT B30). |
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
| `ovning_id` | text | Övningens stabila id (`a–z`, `0–9`, `_`). Historiken känner igen övningen på det, inte på texten, så att en omskriven formulering inte nollställer steget. Samma id i katalogen och `tools/pc/kedjor.json` betyder samma text. |
| `ovning` | text | Övningen, på engelska (BESLUT B30). |
| `tanke` | text | Tanken under svingen, med extern fokus (research 3), på engelska. |
| `positioner` | lista | P-positionerna där granskningen visar felets mått (BESLUT B32): `"P1"`, `"P3"`, `"P4"`, `"P5"`, `"P7"`, `"P9"`, `"P10"`, utan dubbletter och i svingens ordning. `[]` = felets eget mått visas inte vid en position (tempot; resan till träffen, vars del fram till P5 står i `matt` med `fel`). |
| `notering` | text | Valfri. Varför gränsen ser ut som den gör. |

`matt` är måtten som granskningen visar vid en position utan att de är fel
(BESLUT B32, METOD M29), t.ex. sway hittills vid P3. Varje post har `matt`, `vy`
och `positioner`, och valfritt `fel`; inga andra fält:

| Fält | Typ | Betydelse |
|---|---|---|
| `matt` | text | Måttets namn; måste finnas i vyn. Ett mått (i en vy) står bara en gång i katalogen, som fel eller här. |
| `vy` | text | `"dtl"` eller `"fo"`. |
| `positioner` | lista | Som felens, men aldrig tom. |
| `fel` | text | Valfri. Katalogens id för felet som måttet hör till (sway hittills vid P3 → `sway_topp`), så att accenten för det du övar på (BESLUT B31) följer med. |

Granskningen vid en position visar felen och måtten vars `positioner` har den,
i den vy som spelas. Måttets värde är svingens, räknat vid positionens tid
(METOD M29).

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
| `serier[]` | `nr` heltal, `klubba` valfri text, `fonster` och `utsnitt` valfria (nedan) |
| `slag[]` | `id` (`s01`…), `serie` (ett `nr`), `klick_s`, `traff_s` (valfri), `dom` (`sving`, `inte_sving`, `osaker`), `leder` (fil i zippen), `klipp` (valfri fil i zippen) med `klick_i_klipp_s` |

**Fönstret och utsnittet** (S2i, redigeraren på telefonen, METOD MS13, BESLUT B34),
per serie och valfria; saknas de gäller hela filen och hela bilden:

```json
"serier": [{"nr": 1, "klubba": "j7",
            "fonster": {"fran_s": 1.25, "till_s": 6.5},
            "utsnitt": {"x": 0.125, "y": 0.25, "b": 0.5, "h": 0.625}}]
```

| Fält | Krav |
|---|---|
| `fonster.fran_s`, `fonster.till_s` | tal, s i seriens fil, `0 <= fran_s < till_s`. Varje slags `klick_s` ligger i fönstret (telefonen räknar bara de klicken). |
| `utsnitt.x`, `y`, `b`, `h` | tal, normaliserade i den **upprätta** bilden med origo uppe till vänster (som lederna), inom 0–1, `b` och `h` positiva |

Lederna i `slag/s01.json` står alltid i **hela** den upprätta bildens pixlar, även
med utsnitt: telefonen för Visions punkter ur rutan tillbaka. PC:n kan låta
MediaPipe se samma ruta (`paket.utsnitt_px`) och föra punkterna tillbaka med
`paket.fran_utsnittet`. Klippen är passthrough och inte beskurna; de är kapade vid
fönstret.

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

### Två telefoner: `par.json` och meddelandena (S2g)

`par.json` ligger i den styrande telefonens pass (`Pass/<id>/par.json`) och följer
med i dess paket (S2_SPEC §8.3). En rad per serie och följare, skriven om när
parningen ändras (METOD MS9, MS10, BESLUT B22). PC:n läser den inte än; den kan
para om med samma algoritm ur båda paketens klick.

```json
{"format": "swinglab-par/1", "pass": "20261024-153012", "modell": "iPhone18,3", "vy": "dtl",
 "serier": [{"serie": 1, "styr_start_vard_s": 81234.51, "styr_avstand_m": 3.0, "styr_klick": 23,
             "foljare": {"modell": "iPhone14,5", "vy": "fo", "avstand_m": 3.5, "pass": "20261024-153012",
                         "serie": 1, "start_vard_s": 90311.02, "hz": 240, "klick": 22},
             "klocka": {"offset": 9076.68, "uncertainty": 0.0012, "samples": 30}, "klocka_ur": "efter",
             "prior_s": 0.1312, "fonster_s": 0.25,
             "forskjutning_s": 0.1327, "traff_forskjutning_s": 0.1312,
             "antal_par": 22, "oparade_styr": 1, "oparade_folj": 0, "median_rest_s": 0.0011, "osaker": false,
             "parning": {"offset": 0.1327, "pairs": [{"a": 0, "b": 0, "residual": 0.0004}], "count": 22,
                         "secondBestCount": 1, "uncertain": false}}]}
```

| Fält | Innehåll |
|---|---|
| `forskjutning_s` | klicken: följarens filtid = den styrandes + den (s i var sin `Video/<serie>.mov`) |
| `traff_forskjutning_s` | träffen: `forskjutning_s − (foljare.avstand_m − styr_avstand_m) / 343` (METOD MS6) |
| `klocka`, `klocka_ur` | pingens skattning (följarens klocka − den styrandes) och ur vilka prov: `efter` stopp, `fore` (vid start och under), `ingen` |
| `prior_s`, `fonster_s` | sökningens mitt och halva bredd; utan `prior_s` söktes ± 10 s |
| `parning` | `ClickPairing` som den är (index i var sin telefons klick) |
| `osaker` | för få par eller ett annat förskjutning parar lika många: PC:n parar om |

Följarens `pass` är den styrandes id när följarens pass var tomt vid första
starten; annars sitt eget. `serie` är serien i följarens pass.

`foljare.json` (`"format": "swinglab-foljare/1"`) ligger bredvid och bär följarnas
serier som de kom (`FollowerRecord`: följarens hello, `LinkSeries` med klicken och
den styrandes pass `leadPass`, och klockans prov före och efter). Den skrivs innan
serien kvitteras, så att parningen kan göras om när kameran öppnas igen.

**Meddelandena** mellan telefonerna (TCP, `_swinglab._tcp`): fyra bytes längd
(big-endian) och sedan JSON med `type` (`hello`, `ping`, `pong`, `start`, `stop`,
`recorded`, `status`, `ack`). Typerna är `LinkMessage` i
`SwingLabKit/Sources/Capture/Link.swift`; de lämnar aldrig telefonerna.

## Analysen: `analys.json`

`tools/pc/session.py <paket> [<paket>]` skriver passets analys
(`"format": "swinglab-analys/1"`), ett paket per vy. Allt i den är mekaniskt
(BESLUT B2).

| Fält | Innehåll |
|---|---|
| `pass`, `skapad`, `spelhand`, `spelarens_langd_m`, `klubbor` | passet |
| `paket[]` | `fil`, `vy`, antal `slag` och `klipp` |
| `slag[]` | per slag: `id`, `vy`, `serie`, `klubba`, `dom`, `plats`, `forsta_serien` (bool), och antingen `faser`, `positioner`, `cm_per_px`, `matt` (som `matt.mat`), `fel` (varför det inte gick att mäta) eller `utelamnat` |
| `tempo_vy` | vyn som gruppen `alla` tas ur (METOD MT9) |
| `session` | `dtl`, `fo` och `alla` (bara `tempo_vy`), sammanfattade som METOD M25 |
| `forsta_serien` | samma sammanfattning för första serien: de fem första mätta slagen i serie 1 (METOD MT2) |
| `baslinje` | `pass` (de tidigare passen) och antal `svingar` per vy |
| `forra` | `null`, eller `pass` och `jamforelse` (METOD M26) per grupp |
| `bedomning[]` | ett per fel i katalogen: `bedom_varde` (`id`, `varde`, `status`, `grund`, `z`) plus `namn`, `vy`, `matt`, `fas`, `enhet`, `visat` (avrundat, METOD MT3), `n`, `spann`, `gult`, `kontrollerad`, `kalla_status`, `samre`, `forsta_serien` (avrundad median), `klart_nar` (förslaget: `villkor`, `grans`, `grund`, `markning`, eller `null`), `mot_forra` (`skillnad`, `tydlig`) när förra passet finns |
| `kandidater[]` | de gula och röda felen i läsordning (METOD MT6): `fel`, `status`, `fas`, `orsaker` (flaggade orsaker med vägen genom kedjan), `foljdfel` (bool), `fysik` (kopplade test) |
| `kontaktark` | per vy `{"fil", "rader", "kolumner"}` eller `{"hoppat": skäl}` (METOD MT7) |

## Att jobba på: `att_jobba_pa.json` — kontraktet med appen

Det Claude valt efter ett pass, tillbaka till telefonen (S2_SPEC §8.5, BESLUT
B28). **Den här formen är kontraktet:** appens vy (S4, fliken Att jobba på)
läser den och visar den som den är, utan att räkna om något. Telefonen kräver
att `format` börjar med `swinglab-att-jobba-pa/`; PC:n kontrollerar resten med
`tools/pc/att_jobba_pa.py <fil> --analys <analys.json>` mot passets analys och
minnet före passet (METOD MT3, MT5, MT6, MT8, MT10). Formen är stängd: en
okänd eller saknad nyckel fälls.

```json
{
 "format": "swinglab-att-jobba-pa/1",
 "pass": "20261103-180000",
 "skapad": "2026-11-03T21:15:00+01:00",
 "saker": [{
  "ordning": 1,
  "fel": "sway_topp",
  "namn": "Sway: the pelvis slides away from the target in the backswing",
  "vy": "fo", "matt": "backen_sway_topp", "enhet": "cm",
  "nu": -5.7, "spann": [0, null], "markning": "B10",
  "ovning": {"id": "kapp_och_fotterna_ihop", "text": "Stick in the ground …", "tanke": "Leave the stick standing.", "kalla": "katalog",
             "steg": "langsamt_med_foremal"},
  "klart_nar": {"villkor": ">=", "grans": 0, "pa": "forsta_serien", "pass_i_rad": 2},
  "foljdfel": [
   {"fel": "reverse_spine", "namn": "Reverse spine: the upper body leans toward the target at the top",
    "vag": ["sway_topp", "reverse_spine"], "nu": 4.0, "enhet": "°"},
   {"fel": "early_extension", "namn": "Early extension: the pelvis moves toward the ball",
    "vag": ["sway_topp", "reverse_spine", "early_extension"], "nu": 3.3, "enhet": "cm"}
  ],
  "typ": "teknik",
  "fysik": null,
  "block": {"start": "2026-11-03", "vecka": 1}
 }]
}
```

### Filen

| Fält | Typ | Krav och betydelse |
|---|---|---|
| `format` | text | `"swinglab-att-jobba-pa/1"` |
| `pass` | text | passet tolkningen bygger på (`yyyyMMdd-HHmmss`), samma som analysens |
| `skapad` | text | tiden i ISO 8601 |
| `saker` | lista | **1–3** saker, i svingens ordning (tidigt först, METOD MT6); `ordning` 1, 2, 3 |

### En sak

| Fält | Typ | Krav och betydelse | Vyn visar |
|---|---|---|---|
| `ordning` | heltal | platsen, 1 först | ordningen |
| `fel` | text | katalogens id för ett aktivt fel som analysen flaggat (gult eller rött); aldrig ett följdfel. Ett `okand` fel bara när inget är flaggat | — |
| `namn` | text | katalogens namn för felet | sakens namn |
| `vy`, `matt` | text | katalogens | i vilken vy måttet hör hemma |
| `enhet` | text | måttets: `"cm"`, `"°"`, `"s"` eller `""` | enheten |
| `nu` | tal eller `null` | analysens `visat` för felet: passets median | **Du nu** |
| `spann` | `[min, max]` eller `null` | katalogens gröna spann (`null` i en ände = öppen); `null` = egen baslinje | **Mål** som spann |
| `markning` | text eller `null` | `"B10"` (gränsen ej läst i original), `"egen"` (egen baslinje) eller `null` (kontrollerad gräns); analysens, och oförändrad så länge övningen fortsätter | märkningen B10 eller egen |
| `ovning` | objekt | se Övningen | övningen, stegen och tanken |
| `klart_nar` | objekt | se Klart när | villkoret i tal |
| `foljdfel` | lista | se Följdfelen | kedjan |
| `typ` | text | `"teknik"`, `"teknik_kroppen_gor_det_svart"` eller `"troligen_rorlighet"`, enligt treregeln (METOD MT5) | märkningen rörlighet |
| `fysik` | objekt eller `null` | se Fysiken | testet och rörlighetsövningen |
| `block` | objekt | se Blocket | vecka i blocket |

### Övningen (`ovning`)

| Fält | Typ | Krav och betydelse |
|---|---|---|
| `id` | text | övningens stabila id: katalogens `ovning_id` (`kalla: "katalog"`) eller övningens `id` i `kedjor.json` (`kalla: "research3"`). Historiken och kontrollen jämför övningar på id:t (`tools/pc/historik.py`); en fil utan id (före 2026-10-22) känns igen på texten |
| `text` | text | övningen: katalogens ordagrant (`kalla: "katalog"`), eller en av felets övningar i `tools/pc/kedjor.json` ordagrant (`kalla: "research3"`). Aldrig fritext |
| `tanke` | text | tanken under svingen på engelska, extern fokus, högst 60 tecken, utan siffror, värdeord och utropstecken (METOD MT8) |
| `kalla` | text | `"katalog"` eller `"research3"` |
| `steg` | text | var Johannes är: ett av `"langsamt_med_foremal"`, `"halv_fart"`, `"full_fart"`, `"varierat"`, i den ordningen (METOD MT10). En ny övning börjar på första; en som fortsätter står kvar eller tar nästa |

Vyn visar alla fyra stegen och markerar `steg`.

### Klart när (`klart_nar`)

| Fält | Typ | Krav och betydelse |
|---|---|---|
| `villkor` | text | `">="`, `"<="` eller `"mellan"` |
| `grans` | tal, eller `[min, max]` för `mellan` | analysens förslag när övningen väljs; samma som när övningen valdes så länge den fortsätter (METOD MT3) |
| `pa` | text | `"forsta_serien"`: medianen av de fem första slagen i serie 1 nästa pass, före uppvärmningen (METOD MT2) |
| `pass_i_rad` | heltal | `2`: villkoret ska hållas två pass i rad |

Vyn skriver det som ett villkor i tal på engelska (BESLUT B30), till exempel
"First set ≥ 0 cm" och "2 sessions in a row".

### Följdfelen (`foljdfel[]`): kedjan

Fel som mäts men inte övas, eftersom saken är deras grundorsak. Ett följdfel
kan ligga **flera led** efter saken: kedjorna i `tools/pc/kedjor.json` läses
transitivt (METOD MT6).

| Fält | Typ | Krav och betydelse |
|---|---|---|
| `fel` | text | katalogens id; ingen vald sak |
| `namn` | text | katalogens namn |
| `vag` | lista | kedjans väg från saken till följdfelet, saken först (`["sway_topp", "reverse_spine", "early_extension"]`) |
| `nu` | tal eller `null` | analysens `visat` för följdfelet |
| `enhet` | text | måttets |

Vyn ritar kedjan grundorsak → följdfel med följdfelens tal.

### Fysiken (`fysik`)

`null` tills treregeln prövats. Annars:

| Fält | Typ | Krav och betydelse |
|---|---|---|
| `test` | text | ett test för felet i `kedjor.json` (`fysik`) |
| `treregeln` | `[bool, bool, bool]` | syns i full sving, testet fallerar, går inte heller långsamt utan klubba (svaren 2 och 3 från Johannes) |
| `ovning` | text eller `null` | rörlighetsövningen, högst 200 tecken, utan siffror och värdeord; `null` när `typ` är `"teknik"` |

### Blocket (`block`)

| Fält | Typ | Krav och betydelse |
|---|---|---|
| `start` | text | dagen (`yyyy-MM-dd`) då felet först valdes; följer felet genom bytta övningar, och börjar om när felet väljs igen efter ett uppehåll |
| `vecka` | heltal | hela veckor från `start` till passet + 1 (METOD MT10) |

Vyn visar "week 3" i blocket (research 3 §4: 4–6 veckor per grundorsak).

All text i filen är engelska, eftersom appen visar den som den står (BESLUT
B30): `namn` och övningarna är katalogens och kedjornas, och fritexten (`tanke`,
`fysik.ovning`) skrivs på engelska; kontrollen fäller å, ä och ö där. Ingen text
bär värdeord, siffror i fritext eller utropstecken (BESLUT B13, METOD MT8).
Rapporten till Johannes står i chatten, inte i filen, och får vara svensk.

## Historiken: `data/historik/`

Gitignorerad, bara på PC:n (`tools/pc/historik.py`):

```
spelare.json                  {"spelarens_langd_m": <m>}
pass/<pass>/analys.json       session.py
pass/<pass>/kontaktark-<vy>.png
att_jobba_pa/<pass>.json      sparad och kontrollerad med historik.py spara-att-jobba-pa
```

`historik.py minne` skriver `"format": "swinglab-minne/1"`: passen, varje fels
väg genom vintern (`varde`, `forsta_serien`, `status` per pass) och en rad per
fel som fått en övning (`ovningar[]`): `ovning` (senaste texten), `ovning_id`,
`valt_i_pass`, `fel_start`, `forra_ovningar` (id:n), `klart_nar` och `markning` (från valet), `steg`,
`uppfoljning` (första serien, uppfyllt, rörelse och tydlig per pass),
`pass_utan_rorelse`, `dagar_sedan_felet_valdes`, `rorelse_sedan_felet_valdes`,
`aktuell` och `lage` (`avslutad`, `klart`, `fysik`, `ny`, `byt_ovning`,
`fortsatt`; METOD MT4, MT5).
