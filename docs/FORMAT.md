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
| `faser` | `start` (s eller `null`), `topp`, `traff` (METOD M4), och `start_osaker` (bool): bakifrån saknas starten eller bär den inget tempo; framifrån alltid `false` (METOD M40). |
| `positioner` | `P1`, `P3`, `P4`, `P5`, `P7`, `P9`, `P10`: tiden i s, eller `null` när positionen saknas (armen blev aldrig vågrät, eller passagen låg i en lucka, METOD M28). P1 och P10 är fönstrens mitt. P3 kan ligga upp till en ruta efter toppen och P5 en ruta före (rutparet över toppen). I analysen och på telefonen dessutom `P2`, `P6` och `P8` när klubban är markerad där: rutan Johannes valde (S7a, METOD M45). |
| `matt` | Måtten per namn (METOD M5–M24, M29, M30–M39). Ett mått som inte gick att räkna står inte med. Enheten följer namnet (`tools/pc/analys.py` `enhet`, Swift `Avrundning.enhet`): cm, grader, s, ms (`_ms`), m/s (`fart`) och °/s (`vinkelfart`). |

Måttens namn och vilka vyer som ger dem: `MATT_DTL` och `MATT_FO` i
`tools/pc/matt.py` (Swift: `Matt.namn`). Tecknen står i varje METOD-rad.

## Katalogen: `katalog.json`

I repots rot (BESLUT B6). `{"version": 1, "om": "…", "fel": [ … ], "matt": [ … ], "spridning": [ … ], "tre_d": [ … ]}` (`tre_d`: 3D-måtten, nedan),
där varje fel har:

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
| `kontrollerad` | bool | `false` tills källan i `kalla` lästs i original (BESLUT B10; research 5, BESLUT B45). |
| `aktiv` | bool | `false` = felet bedöms inte (axellutningen, METOD M17). |
| `samre` | `"+"`, `"-"` eller `null` | Åt vilket håll måttet blir sämre, för den egna baslinjen. `null` = båda. |
| `ovning_id` | text | Övningens stabila id (`a–z`, `0–9`, `_`). Historiken känner igen övningen på det, inte på texten, så att en omskriven formulering inte nollställer steget. Samma id i katalogen och `tools/pc/kedjor.json` betyder samma text. |
| `ovning` | text | Övningen, på engelska (BESLUT B30). |
| `tanke` | text | Tanken under svingen, med extern fokus (research 3), på engelska. |
| `positioner` | lista | P-positionerna där granskningen visar felets mått (BESLUT B32): `"P1"` … `"P10"` (P2, P6 och P8 för klubbans mått, S7a), utan dubbletter och i svingens ordning. `[]` = felets eget mått visas inte vid en position (tempot; resan till träffen, vars del fram till P5 står i `matt` med `fel`). |
| `grans_harledd` | bool | Valfri. `true` = gränsen är ett antagande härlett ur källan (sway_topp och early_extension, BESLUT B45); infobladets källa säger då "Assumption from manufacturer". Kräver `gront`. |
| `vad` | text | Infobladet (BESLUT B41): en mening på engelska, vad som mäts och mellan vilka punkter. |
| `varfor` | text | Infobladet: en mening på engelska, varför det spelar roll, med felets namn när det finns. |
| `tecken` | text | Infobladet: tecknet på engelska, som koden räknar det ("+ toward ball · − away"). |
| `notering` | text | Valfri. Varför gränsen ser ut som den gör. |

`matt` är måtten som granskningen visar vid en position utan att de är fel
(BESLUT B32, METOD M29), t.ex. sway hittills vid P3. Varje post har `matt`, `vy`
och `positioner`, och valfritt `fel` och `status`; inga andra fält:

| Fält | Typ | Betydelse |
|---|---|---|
| `matt` | text | Måttets namn; måste finnas i vyn, eller vara ett av klubbans mått (`klubba.katalognamn`, `Klubba.katalognamn`, METOD M46–M49). `skaft_vinkel` är ett mått per position: granskningen visar `skaft_vinkel_p4` vid P4 osv. Ett mått (i en vy) står bara en gång i katalogen, som fel eller här. |
| `vy` | text | `"dtl"` eller `"fo"`. |
| `positioner` | lista | Som felens, men aldrig tom. |
| `vad` | text | Som felens: en mening på engelska, vad som mäts och mellan vilka punkter. |
| `varfor` | text | Som felens: en mening på engelska, varför det spelar roll, med felets namn när det finns. |
| `tecken` | text | Som felens: tecknet på engelska, som koden räknar det ("+ toward ball · − away"). |
| `fel` | text | Valfri. Katalogens id för felet som måttet hör till (sway hittills vid P3 → `sway_topp`), så att accenten för det du övar på (BESLUT B31) följer med. |
| `status` | text | Valfri. `"oprovad"` = måttet är oprövat på telefonen (farterna och genomsvingens tid, METOD M35–M37, BESLUT B11); granskningen märker det "untested" i stället för "own". Utan fältet: egen baslinje. |

`spridning` är passets spridning mellan slagen för ett mått, ett tal per pass: den
robusta sd:n ur passets svingar i vyn, och inget tal under 8 slag (METOD M44, BESLUT
B46). Passet visar den som ett kort och Progress som ett mått över passen. Varje post har exakt `matt`, `vy`
(`"dtl"` eller `"fo"`, måttet måste finnas i vyn, en gång), `vad`, `varfor` och
`tecken` (som felens).

Klubbans mått (S7a, BESLUT B47) står i `matt` utan `fel`; passet visar de specifika
(inte `skaft_vinkel`) som kort med medianen och n över de markerade svingarna, när
minst ett slag har måttet.

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
| `spelarens_langd_m` | **valfri, nytt i S5**: 1,0–2,5. Telefonen skriver passets längd (S4c, METOD MS16), utom när den är antagen. Saknas den tas längden ur `--langd` eller historiken |
| `serier[]` | `nr` heltal, `klubba` valfri text, `fonster` och `utsnitt` valfria (nedan), `lodlinje` valfri (nedan, nytt i S6a) |
| `slag[]` | `id` (`s01`…), `serie` (ett `nr`), `klick_s`, `traff_s` (valfri), `dom` (`sving`, `inte_sving`, `osaker`), `leder` (fil i zippen), `klipp` (valfri fil i zippen) med `klick_i_klipp_s` och, valfritt, `klipp_langd_s` (positivt tal) och `detection_wrong` (bool: Johannes märkte lederna fel på telefonen; slaget mäts inte, METOD MT1) |

**Telefonen skriver** (S2f, `SwingLabKit/Sources/Capture/PackageManifest.swift`, App/Export.swift)
bara slag som har leder, eftersom `leder` krävs: ett slag utan dom, eller "Not a swing"
som aldrig fick det täta passet, står inte i paketet. Ett klipp kommer med bara när
klicket hittades i det (`klick_i_klipp_s`). `klipp_langd_s` är klippets längd: ett
passthrough-klipp bär rutor efter redigeringens slut, så PC:n räknar bara klippets rutor
i **[0; klipp_langd_s)** (`paket.i_klippet`, METOD MS12). `matt` står alltid med, `null`
tills telefonen räknar måtten. Utan klipp är paketet samma utom klippen och deras tre fält.
Zippen är okomprimerad (metoden 0, BESLUT B27).

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

**Seriens kameraformat** (`serier[].format`, telefonen skriver det: `index`, `bredd`,
`hojd`, `synfalt`, `binnat`, S2_SPEC §8.3). PC:n läser `synfalt` (vågrätt synfält i
grader över den liggande bildens långsida) för brännvidden i 3D, och annars det valda
formatet i `enhet.json`; ett synfält utanför 10–170° räknas som saknat (METOD MK3).

**Riktpinnen** (S7a, BESLUT B47, METOD M48), per serie och valfri: `"riktpinne": [[x, y],
[x, y]]`, två tryck i hela den upprätta bildens pixlar på en pinne på marken, parallell med
mållinjen, bakifrån. PC:n tar flyktpunkten ur den (`klubba.flyktpunkt`); utan den är
flyktpunkten bildens mitt och analysens slag säger `klubba_flyktpunkt: "bildens_mitt"`.

**Lodlinjen** (S6a, BESLUT B39, METOD MK3), per serie och valfri:
`"lodlinje": [x, y, z]`, uppåt (−gravitationen) i g i kamerans ram i den **upprätta**
bilden: x åt höger, y nedåt, z framåt ur linsen. Längden ska vara 0,8–1,2 (telefonen i
vila på stativet); PC:n normerar den. En telefon som står rak och vågrät ger ungefär
`[0, -1, 0]`. **Telefonen skriver den** (S6b, METOD MS17) med fyra decimaler när den
stod still sekunden före seriens första klick (eller under seriens stilla sekunder); rörde den sig, saknades rörelsen (simulatorn) eller
är serien importerad ur Bilder står fältet inte med, och PC:n tar uppåt ur kamerornas
vågräta. Gamla paket utan fältet läses som förut. Fältet är **mjukt**: fel längd, fel form eller uppåt som inte pekar
mot bildens överkant (y ≥ 0) stoppar aldrig paketet; PC:n använder det då inte och
skriver skälet utan värden i `tre_d.kalibrering[].lodlinje_fel`.

Lederna i `slag/s01.json` står alltid i **hela** den upprätta bildens pixlar, även
med utsnitt: telefonen för Visions punkter ur rutan tillbaka. PC:n kan låta
MediaPipe se samma ruta (`paket.utsnitt_px`) och föra punkterna tillbaka med
`paket.fran_utsnittet`. Klippen är passthrough och inte beskurna; de är kapade vid
fönstret.

**Klubbans markeringar** (S7a, BESLUT B47): `klubba.json` i zippens rot, i formatet
`swinglab-klubba/2` (nedan, "Klubbans märkning"), när något slag i paketet har markeringar.
Telefonen skriver en ruta per markerad eller hoppad position: `id` `<vy>-<slag>-<P>`, `fil`
= paketets namn, `val` = positionen, `t` = Visions tid, `t_klipp` = `t + klick_i_klipp_s`
när klippet följer med och rutan ligger i det, [0; `klipp_langd_s`) (annars null), `forskjutning_ms` och `t_ruta` null, `visad` =
utsnittet som märkningen visade, `skaft_mitt` null och `forslag` tom. Filens `andrad` är när
markeringarna senast ändrades (varje markering bär sin tid i `pass.json`). PC:n
(`paket.py`) läser den till varje slags markeringar; en fil som inte går att läsa stoppar
inte paketet (`Paket.klubba_fel`, i analysen `klubba.fel`).

Övriga fält (`telefon`, `ljusprov.json`, `vision`) läses inte än; `enhet.json` läses
bara för brännvidden i 3D (ovan). `par.json` ligger i paketet när passets mapp har den (S2g) och läses
för 3D (S6a, METOD MK1); en `par.json` som inte går att läsa stoppar inte paketet. Sökvägarna får inte börja med `/` eller innehålla `..`.
`enhet.json` är `{"modell", "ios", "format": [CameraFormat …], "valt_index"}` (alla format
bakkameran rapporterar), `ljusprov.json` passets `LightCheck` som i `pass.json`; ett tal
som JSON inte tål skrivs som text (`"inf"`, `"nan"`).

Att det appen skriver är det PC:n läser prövas med appens egna byte: simulatorprovet
packar ett påhittat pass med `Export.swift`, och `tools/tests/test_appens_paket.py` läser
det med `paket.py` och `session.py` i kompilera.yml, och klippen avkodas med OpenCV (BESLUT B27).

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
parningen ändras (METOD MS9, MS10, BESLUT B22). PC:n läser den för 3D (S6a, METOD
MK1): `format`, `pass`, `vy` och per serie `serie`, `forskjutning_s`, `osaker` och
följarens `vy`, `pass` och `serie`. Utan den, eller när en serie är `osaker`, parar PC:n
om på båda paketens klick.

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
`recorded`, `status`, `ack`, och sedan S6c-2 `part` och `part_ack`). Typerna är `LinkMessage` i
`SwingLabKit/Sources/Capture/Link.swift`; de lämnar aldrig telefonerna. En okänd typ hoppas
över (sedan S6c-2). `hello` bär `role`, `device` (stabil per installation sedan S6c-2), `model`,
`app`, `view` och, sedan S6c-2, `mode` (`record` eller `pass`, saknas = `record`) och `caps`
(`["part1"]`: tar emot bitarna); okända nycklar tål avkodaren.

### 3D mellan telefonerna (S6c-2): `part`, `swinglab-slag/1` och `tre_d.json`

En stor överföring går i bitar (BESLUT B61, METOD MS19). `part` bär `{"v": 1, "kind", "pass",
"id", "index", "count", "bytes", "data"}`: `kind` är `slag` (följarens slag till den styrande)
eller `tre_d` (resultatet tillbaka), `id` innehållets summa (CRC-32 i hex och längden,
`"1a2b3c4d-123456"`), `count` = ⌈`bytes` / 196 608⌉ och `data` bitens byte i base64. `part_ack`
bär `{"v", "kind", "pass", "id", "index", "ok"}`: en bit (`index`), eller hela överföringen
(`index` null) när den är sparad (`ok: true`), när summan inte stämde eller mottagaren inte känner
överföringen (`ok: false` utan `fel`: allt skickas igen), eller ett nej (`ok: false` och `fel`:
`pass`, `version` eller `format`: avsändaren slutar). Bitar skickas bara till en telefon vars hello
har `part1`.

`swinglab-slag/1` (`Pass/<id>/annan_telefon.json` hos den som räknar) är en telefons slag utan
video:

```json
{"format": "swinglab-slag/1", "pass": "20261103-180000", "vy": "fo",
 "manifest": "{… manifest.json som text …}", "enhet": "{… enhet.json …}",
 "leder": {"s01": {"width": 1080, "height": 1920, "source": "vision-2d-r1", "enc": "i16",
                   "t": "<base64>", "j": "<base64>"}}}
```

`par` (par.json som text) och `enhet` utelämnas när filen saknas. `t` är tiderna som int32 i 1e-4 s; `j` per ruta och led (13, FORMAT "Lederna") x och y i 0,1 px
som int16 (`enc` `i16`) eller int32 (`i32`) och konfidensen som uint16 i 0,001, little endian.
Konfidensen 0 = saknad. Talen läses tillbaka som n · steg: exakt ledfilens tal
(`JointSeries.rounded`, METOD MS12). "Import other phone" bygger samma bunt ur paketets zip.

`tre_d.json` (`swinglab-tre-d/1`) i båda telefonernas pass och i paketet:

| Fält | Innehåll |
|---|---|
| `format`, `pass` | `"swinglab-tre-d/1"` och passets id |
| `raknad`, `raknad_av` | när (ISO 8601, UTC) och vilken telefons vy som räknade |
| `kallor` | buntarnas summor per vy (`dtl`, `fo`): ett pass vars slag ändrats räknas om |
| `sekunder` | räkningens tid på telefonen (METOD M50) |
| `tre_d` | `TreDResultat`: samma fält som `analys.json`:s `tre_d` utom `mot_forra`, `trend` och `telefon` |
| `hoppat` | i stället för `tre_d`: skälet (METOD M51) |
| `inre` | per uppställning de oavrundade talen (`R`, `t`, `upp`, `forsk` i s, `aterprojektion`, `sampson_px`, `vinkel`, `lodlinje_mot_vagrata`, null för en som inte kalibrerades): PC:n redovisar grenarna (MS19) |

`pass.json` bär `tre_d` med passets median per mått (`n`, `median`, `q1`, `q3`, null under 10 slag)
för Progress och förra passet.

## Analysen: `analys.json`

`tools/pc/session.py <paket> [<paket>]` skriver passets analys
(`"format": "swinglab-analys/1"`), ett paket per vy. Allt i den är mekaniskt
(BESLUT B2).

| Fält | Innehåll |
|---|---|
| `pass`, `skapad`, `spelhand`, `spelarens_langd_m`, `klubbor` | passet |
| `huvudklubba` | huvudklubbans id (flest mätta slag): fälten nedan från `tempo_vy` till `kandidater` gäller den, och "Att jobba på" gäller den (BESLUT B56) |
| `delar[]` | de andra klubborna i passet, var och en med `klubba` och samma fält från `tempo_vy` till `kandidater`, bedömd mot sin egen baslinje |
| `matversion` | måttens version (`matt.MATVERSION`; 2 = METOD M40, 3 = M41–M43, spridningen); saknas = 1, kör session.py igen |
| `paket[]` | `fil`, `vy`, antal `slag` och `klipp` |
| `slag[]` | per slag: `id`, `vy`, `serie`, `klubba`, `dom`, `plats`, `forsta_serien` (bool), och antingen `faser`, `positioner`, `cm_per_px`, `matt` (som `matt.mat`), `fel` (varför det inte gick att mäta) eller `utelamnat` |
| `tempo_vy` | vyn som gruppen `alla` tas ur: flest slag med tempo (METOD MT9) |
| `session` | `dtl`, `fo` och `alla` (bara `tempo_vy`), sammanfattade som METOD M25 |
| `forsta_serien` | samma sammanfattning för första serien: de fem första mätta slagen i serie 1 (METOD MT2) |
| `spridning[]` | ett per mått i katalogens `spridning` och klubba i passet: `matt`, `vy`, `klubba`, `n` (slagen med måttet i vyn och klubban), `varde` (den robusta sd:n, `null` under 8 slag) och `visat` (avrundat), METOD M44 |
| `klubba` | klubbans mått ur markeringarna (S7a, METOD M46–M49): `markerade` (slag med klubban markerad, per vy), `matt[]` (per vy och mått med minst ett slag: `matt`, `vy`, `n`, `median`, `visat`) och `fel` (per vy: `klubba.json` som inte gick att läsa). Slagen bär måtten i `matt`, P2/P6/P8 i `positioner` och `klubba_markerad` (bool) |
| `skifte_ej_tillbaka` | `fo`: FO-slag där bäckenet står bakom adressläget vid träffen, så att skiftet saknas (censurerat, METOD M42), och `fo_matta`: mätta FO-slag |
| `baslinje` | `pass` (de tidigare passen med samma klubba och längd, BESLUT B56) och antal `svingar` per vy |
| `forra` | `null`, eller `pass` (det senaste tidigare passet med samma klubba, längd och en gemensam vy) och `jamforelse` (METOD M26) per grupp |
| `bedomning[]` | ett per fel i katalogen: `bedom_varde` (`id`, `varde`, `status`, `grund`, `z`) plus `namn`, `vy`, `matt`, `fas`, `enhet`, `visat` (avrundat, METOD MT3), `n`, `spann`, `gult`, `kontrollerad`, `kalla_status`, `samre`, `forsta_serien` (avrundad median), `klart_nar` (förslaget: `villkor`, `grans`, `grund`, `markning`, eller `null`), `baslinje` (för ett fel utan gräns: baslinjens `median`, robusta `sd` och `n` svingar, avrundade; `null` med gräns eller under 8 svingar, S5b), `mot_forra` (`skillnad`, `tydlig`) när förra passet finns |
| `kandidater[]` | de gula och röda felen i läsordning (METOD MT6): `fel`, `status`, `fas`, `orsaker` (flaggade orsaker med vägen genom kedjan), `foljdfel` (bool), `fysik` (kopplade test) |
| `kontaktark` | per vy `{"fil", "rader", "kolumner"}` eller `{"hoppat": skäl}` (METOD MT7) |
| `tre_d` | två kameror (S6a, nedan), eller `{"hoppat": skäl}`; med `telefon` när paketet bar telefonens `tre_d.json` (S6c-2, nedan) |

**`tre_d`** (BESLUT B37, METOD MK1–MK7) när passet har ett DTL- och ett FO-paket:

| Fält | Innehåll |
|---|---|
| `lage` | `"utan_markorer"` (BESLUT B14) |
| `min_slag` | 10: passets median kräver så många slag (MK7) |
| `matt` | måttens namn: `backen_vrid_topp`, `brost_vrid_topp`, `xfaktor_topp`, `xfaktor_stretch`, `hofter_oppna_traff` (grader, MK6) |
| `parning` | `kalla` (`par.json` eller `klicken`), `serier[]` (`dtl`, `fo`, `kalla`, `par`), `par`, `oparade` per vy, och `par_json_fel` när par.json inte gick att läsa (MK1) |
| `kalibrering[]` | en per uppställning (DTL-serie mot FO-serie): `serie` (`dtl`, `fo`), `slag`, `f_kalla` per vy (`serien`, `enhet.json` eller `specifikationen`), `lodlinje_fel` när fältet inte gick att använda, `lodlinje_mot_vagrata` (grader mellan manifestets uppåt och kamerornas vågräta, när manifestet bar fältet; över 15° används de vågräta), och antingen `hoppat` (skälet: kalibreringen gick inte eller Sampson-felet är över spärren) eller `lodlinje` (`manifest` eller `kamerornas_vagrata`), `sampson_px` (på 1920 px långsida), `vinkel_mellan_kamerorna` (grader) och `vinkel_ok` (60–120°) (MK3) |
| `osaker` | skälen till att talen är osäkrare: vinkeln utanför 60–120°, lodlinjen i manifestet användes inte (MK3) |
| `slag[]` | per par: `dtl` och `fo` (slagens id), `serie` per vy, `synk_ms` (DTL:s klocka före FO:s efter klicket, MK4), `aterprojektion_px`, och `matt` eller `fel` |
| `utelamnade[]` | parade slag som inte mäts: `dtl`, `fo` och `skal` (domen är inte sving, Detection wrong, lederna saknas, för få rutor, ledernas tider spänner orimligt långt; METOD MK1, MK5, M51) |
| `n` | antal slag med måttet |
| `session` | M25:s sammanfattning per mått, bara mått med minst `min_slag` slag |
| `mot_forra` | `null`, eller `pass` och `jamforelse` per mått: `skillnad`, `spridning`, `golv`, `tydlig` (MK7) |
| `trend[]` | katalogens mått i `katalog.json`:s `tre_d`-ordning: `matt`, `namn`, `enhet`, `fas`, `lage`, `n`, `min_slag`, `median` och `kvartiler` (1 decimal, `null` under `min_slag`), `spann`, `kalla_status`, `kontrollerad`, `mot_forra` (`skillnad`, `tydlig`) |

Trenden är det skillen läser och rapporterar. Inget i `tre_d` bedöms eller blir en
sak i `att_jobba_pa.json` (B14).

**`tre_d.telefon`** (S6c-2, BESLUT B63, METOD MS19) när ett paket bär telefonens `tre_d.json`:
`paket`, `raknad`, `raknad_av`, `sekunder`, `tol` (0,05°), `olika` (fälten som skiljer: parningen,
skälen, antalen, varje uppställnings fält och varje slags `serie`, `synk_ms`,
`aterprojektion_px`, `fel` och måttens namn), `storsta_skillnad` (grader, per slag),
`storsta_skillnad_median`, `per_slag[]` (`dtl`, `fo`, `matt`, `skillnad` över 0,05°) och
`inom`; dessutom `avrundade[]` (`falt`, `pc`, `telefon`, `skillnad` för de avrundade talen som
skiljer), `bara_telefonen[]` och `bara_pc[]` (mått som bara den ena har, per slag) och
`marginaler[]` (telefonens tal vid grenarna per uppställning: Sampson-felet mot spärren, vinkeln
mot 60–120°, lodlinjen mot skyddet, och synken per slag i ms). Paketet vars vy räknade
(`raknad_av`) jämförs. När PC:n eller telefonen hoppade över: `hoppat` (`pc`, `telefon`) och `inom` = samma
skäl. En fil som inte gick att läsa: `{"paket", "fel"}`.

### Facit för 3D på telefonen (S6c-1)

`tools/tests/fixturer/tre_d/` (BESLUT B48, METOD M50), skrivna av
`tools/pc/generera_tre_d.py`, PÅHITTADE, med radbrytningar så att en ändring ger en liten
diff:

- `indata/<pass>.json`: `paket` per vy (`manifest`, `par` och `enhet` som text eller
  `null`, `filer`: paketets filnamn, och `leder` per slag-id: `{width, height, t, j}` där
  `t` är tiderna som int32 i 1e-4 s och `j` lederna som int16 [x, y, c] per led i 0,1 px
  och 0,001, c = 0 för en saknad led, båda base64 i little endian), `rader`
  (2D-fasernas `start` och `topp` per `vy` och `id`) och `sant` (MK8:s facit).
- `<facit>.json`: `indata` (passet) och `varianter` per namn: `andra` (filerna som byts,
  per vy), `python` (`tre_d`, eller `{"hoppat": skäl}`) och `inre` (R, t, uppåt, synken i
  s och återprojektionen per uppställning, oavrundade).
- `parning.json`: manifesten utan leder och `para_slag`:s svar per variant;
  `manifest_fel.json`: trasiga manifest och `paket._kontrollera_manifest`:s fel;
  `komponenter.json`: delstegen för ett slag.

## 3D-måtten: `katalog.json`:s `tre_d`

Sedan S6c-2 står 3D-måtten i `katalog.json`, listan `tre_d` (BESLUT B37, B62; förut
`katalog_3d.json`, som bara PC:n läste). Appen läser den (`Katalog.treD`) och PC:n
(`tools/pc/katalog.py` `las_3d`). Ett objekt per 3D-mått, varje mått en gång och alla fem med
(MK6), med exakt fälten:

| Fält | Typ | Betydelse |
|---|---|---|
| `matt` | text | Måttets namn i `tre_d` (MK6). |
| `namn` | text | Det Johannes ser, på engelska (BESLUT B30). |
| `enhet` | text | `"°"`. |
| `fas` | text | `topp`, `nedsving` eller `traff`. |
| `lage` | text | `"utan_markorer"` eller `"med_markorer"` (BESLUT B14). |
| `min_slag` | heltal | Slag som passets median kräver (10, MK7). |
| `spann` | `[min, max]` eller `null` | Riktmärke att visa bredvid trenden, aldrig en bedömning (B37). |
| `kalla`, `status`, `kontrollerad`, `notering` | | Som för felen. |
| `vad`, `varfor`, `tecken` | text | Infobladet (BESLUT B41), på engelska. |

## Att jobba på: `att_jobba_pa.json` — kontraktet med appen

Det Claude valt efter ett pass, tillbaka till telefonen (S2_SPEC §8.5, BESLUT
B28). Telefonen hämtar den med "Import focus" (Filer) och sparar den som
`AttJobbaPa/att_jobba_pa-<pass>.json` i appens mapp; den med högst `pass` är den som
gäller. En fil vars `pass` inte är `yyyyMMdd-HHmmss` tas inte emot. **Den här formen är kontraktet:** appens vy (S4, fliken Att jobba på)
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
  "nu": -5.7, "spann": [-2.5, null], "markning": null,
  "ovning": {"id": "kapp_och_fotterna_ihop", "text": "Stick in the ground …", "tanke": "Leave the stick standing.", "kalla": "katalog",
             "steg": "langsamt_med_foremal"},
  "klart_nar": {"villkor": ">=", "grans": -2.5, "pa": "forsta_serien", "pass_i_rad": 2},
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

## Underlaget till Claude-appen (S5b)

"Ask Claude" på telefonen och `session.py --claude-text` på PC:n skriver samma text
(BESLUT B52–B55, METOD MT11): `# SwingLab: Att jobba på efter passet <pass>`, skillens
avsnitt `claude-appen`, och `## Datan` med ett kodblock ```` ```json ```` som bär ett objekt
med fälten i den här ordningen:

| Fält | Innehåll |
|---|---|
| `pass`, `datum`, `klubba` | passet och huvudklubban |
| `slag` | mätta slag per vy (`dtl`, `fo`) |
| `tempo_vy`, `forra` | analysens; `forra` är förra passets id eller `null` |
| `baslinje` | antal tidigare `pass` och `svingar` per vy |
| `kandidater` | analysens |
| `bedomning` | de aktiva felen med ett tal som inte är gröna: `id`, `vy`, `enhet`, `status`, `grund`, `z` (1 decimal), `n`, `visat`, `forsta_serien`, `spann`, `gult`, `baslinje`, `mot_forra` (de valfria står inte med när de är `null`) |
| `spridning` | analysens `matt`, `vy`, `n` och `visat`, för mått med minst ett slag |
| `historik` | `pass` (de senaste sex med samma klubba och längd) och `fel`: per aktivt fel som inte är grönt i alla `[visat, status]` eller `null` per pass |
| `ovningar` | minnet före passets val (`historik.py minne`), uppföljningen med de senaste fyra raderna; en avslutad övning bara `fel`, `aktuell`, `lage`, `ovning_id` |
| `pagaende` | den senaste filen före passet: `pass` och per sak `fel`, `ovning_id`, `steg`, `tanke`, `typ`, `block`; eller `null` |
| `fil` | `format`, `pass` och `skapad` för svaret |
| `mallar` | per fel som går att välja (högst tre nya, och övningarna som fortsätter): sakens fält utom `ordning`, `ovning`, `typ` och `fysik`, analysens `grund`, och valen `ovning_val` (`id`, `text`, `kalla`, och `tanke` för katalogens eller den som fortsätter), `steg_val` och `fysik_test` |

Svaret är rapporten och sist ett kodblock med `fil` och `saker`, i formen ovan ("Att
jobba på"). Telefonen och `att_jobba_pa.py --ur-text` läser det likadant (METOD MT12).

## Historiken: `data/historik/`

Gitignorerad, bara på PC:n (`tools/pc/historik.py`):

```
spelare.json                  {"spelarens_langd_m": <m>}
pass/<pass>/analys.json       session.py
pass/<pass>/kontaktark-<vy>.png
att_jobba_pa/<pass>.json      sparad och kontrollerad med historik.py spara-att-jobba-pa
```

`historik.py minne` skriver `"format": "swinglab-minne/1"` för det senaste passets
huvudklubba och längd (BESLUT B56): passen (med `klubba`), varje fels
väg genom vintern (`varde`, `forsta_serien`, `status` per pass), 3D-trenden (`tre_d`:
per mått en rad per pass med median, `pass`, `median`, `kvartiler`, `n`, `lage`; S6a,
METOD MK7), klubbans mått (`klubba`: per mått en rad per pass med `pass`, `vy`, `median` och
`n`; S7a, METOD M46) och en rad per
fel som fått en övning (`ovningar[]`): `ovning` (senaste texten), `ovning_id`,
`valt_i_pass`, `fel_start`, `forra_ovningar` (id:n), `klart_nar` och `markning` (från valet), `steg`,
`uppfoljning` (första serien, uppfyllt, rörelse och tydlig per pass),
`pass_utan_rorelse`, `dagar_sedan_felet_valdes`, `rorelse_sedan_felet_valdes`,
`aktuell`, `lage` (`avslutad`, `klart`, `fysik`, `ny`, `byt_ovning`,
`fortsatt`; METOD MT4, MT5), `klart_skal` (`"klart_nar"` när "klart när" hölls,
`"inte_flaggat"` när felet inte längre är flaggat i det senaste passet efter valet,
till exempel när gränsen flyttats, BESLUT B45; annars `null`), och `kor_om`: passen vars
analys har en äldre `matversion` (METOD M40), som ska köras om med session.py.

## S3:s tabell: `s3.json` (utanför repot)

`tools/pc/s3_facit.py` skriver i `~/swinglab-s3/<pass>/` (BESLUT B43, METOD MF1–MF4):
`s3.md` (tabellen att läsa), `s3.json` (samma tal), `kontaktark-s3-<vy>.png` och
`mediapipe/<paket>-<slag>.json`: MediaPipes leder för varje ruta i klippet, i hela
bildens pixlar, med `version` (3), `"source": "mediapipe-pose-heavy"`, `modell`, `width`,
`height`, `utsnitt_px`, `klipp_crc`, `klipp_storlek` och `frames[]` med `tk` (rutans tid
enligt OpenCV, s), `joints` (VIDEO-läget) och, i tidsparningens fönster, `joints_bild`
(IMAGE-läget).
`s3.json` har `"format": "swinglab-s3/2"`:

| Fält | Innehåll |
|---|---|
| `pass`, `skapad`, `modell` | passen, tiden, modellfilen och läget (`VIDEO`) |
| `min_slag`, `bootstrap` | slagen som krävs för B5 och måtten (5), dragningarna för intervallen (100) (MF2) |
| `paket[]` | `fil`, `vy`, `slag`, `matbara`, `med_klipp`, `korda`, `jamforda`, `rutor` (Visions), `rutor_parade`, och `forskjutning_median_ms`, `forskjutning_spridning_ms` (MF1) |
| `nivaer` | trösklarna ur simuleringen: `mediapipe` (antagen nivå), `pass`, `slag`, `grov_procent`, och per `alla` och `nedsving` per nivå `median` (`fast`, `rorligt` i % av kroppslängden per axel, `utliggare`, `grova` som andel) och `grans` (`fast`, `rorligt`: nivåns övre gräns) (MF3) |
| `beslut_b5` | per vy: `slag`, och per `alla` och `nedsving` antingen `null` (under `min_slag`) eller `fast`, `rorligt`, `utliggare`, `grova`, `slag`, `intervall` (per del `[2,5 %, 97,5 %]`) och `niva` (`bra`, `typiskt`, `daligt`, `samre_an_daligt`); dessutom `vision_saknar_mp_ser`, `sidbyten`, `matt_tydliga` av `matt_provade` |
| `leder[]` | per `vy`, `led` (filens namn eller `alla`) och `fas` (`adress`, `baksving`, `nedsving`, `efter_traff`, `alla`): `rutor`, `n`, `slag`, `px` och `procent` (`medel`, `spridning`, `fast`, `rorligt`), `utliggare`, `vision_saknar`, `mediapipe_saknar`, `vision_saknar_mp_ser` (MF2) |
| `sidbyten[]` | `vy`, `par`, `n`, `andel` |
| `matt[]` | per vy och mått: `enhet`, `n` (slag), och från `min_slag` slag `vision_median`, `mediapipe_median`, `skillnad`, `intervall`, `skillnad_medel`, `skillnad_sd`, `abs_medel`, `mediapipe_spridning`, `tydlig` (annars `null`) (MF3) |
| `faser[]` | `start` och `topp` i ms (Vision − MediaPipe), och `skalan` som kvot av cm per px |
| `slag[]` | per slag: `fil`, `id`, `vy`; med klipp `tidsparning` (`forskjutning_ms`, `rutor`, `kvot`, `rest_ms_median`, och `ffprobe_start_ms` när ffprobe finns, MF1) och `rutor_parade`; `varning` när δ inte stämmer med start_time; och `vision_fel`, `mediapipe_fel` eller `hoppat` (inget klipp, eller tidsparningen tvetydig eller avvikande, med skälet) |
| `kontaktark` | per vy `{"fil", "rader", "kolumner"}` eller `{"hoppat": skäl}` |

## Klubbans märkning: `swinglab-klubba/2` (utanför repot)

`tools/pc/markera_klubba.py` skriver den bredvid paketet som `swinglab-<pass>-klubba.json`
(en video: `<video>-klubba.json`), efter varje ruta (BESLUT B44, METOD MF5–MF6). Samma fil
läses när verktyget körs igen; en ruta med samma id, fil, förskjutning och tid behåller sin
märkning. Telefonen skriver samma format som `klubba.json` i paketet (ovan, S7a, BESLUT
B47), och `tools/pc/samla_klubba.py <paket|märkfiler> --ut <mapp>` samlar båda per pass till
en träningsmapp utanför repot (`<pass>.json` och `index.json`) för S7.

**Version 2** (S7a) ändrar tre saker mot version 1 och är annars samma: `val` får också
vara `P1` … `P10` (telefonens markering vid en position), `t_klipp` och `forskjutning_ms`
får vara `null` (inget klipp i paketet, ingen S3-förskjutning), och en `markerad` ruta
kräver bara `grepp` och `klubbhuvud` (telefonen trycker två punkter; `skaft_mitt` är `null`).
En fil i version 1 är alltså giltig i version 2; PC:n (`klubba.kontrollera`, `las`) läser
båda och skriver version 2, och SwingLabKit (`KlubbFil.las`) läser båda. Formatets ägare
är `tools/pc/klubba.py`.

```json
{"format": "swinglab-klubba/2", "pass": "20261103-180000",
 "kalla": ["swinglab-20261103-180000-dtl.zip", "swinglab-20261103-180000-fo.zip"],
 "punkter": ["grepp", "skaft_mitt", "klubbhuvud"], "andrad": "2026-11-03T21:15:00+01:00",
 "rutor": [{"id": "fo-s03-topp", "fil": "swinglab-20261103-180000-fo.zip", "vy": "fo", "slag": "s03",
            "val": "topp", "t": -0.3125, "t_klipp": 2.1913, "forskjutning_ms": -2.0, "t_ruta": 2.189292,
            "bredd": 1080, "hojd": 1920, "visad": [54, 0, 972, 1920], "status": "markerad",
            "punkter": {"grepp": {"x": 512.3, "y": 640.0, "kalla": "klick"},
                        "skaft_mitt": {"x": 600.1, "y": 560.4, "kalla": "klick"},
                        "klubbhuvud": {"syns_inte": true}},
            "forslag": {"grepp": {"x": 505.0, "y": 652.1, "kalla": "handlederna"}}}]}
```

| Fält | Krav och betydelse |
|---|---|
| `format` | `"swinglab-klubba/2"` (läses också `"swinglab-klubba/1"`) |
| `pass` | passet (`yyyyMMdd-HHmmss`), eller `null` för en video utan paket |
| `kalla` | filerna som rutorna kommer ur (namnen) |
| `punkter` | exakt `["grepp", "skaft_mitt", "klubbhuvud"]` |
| `andrad` | senaste sparningen, ISO 8601 |
| `rutor[].id` | unikt: `<vy>-<slag>-<val>` (`-jamn-1` …), eller `video-01` …; en ny ruta med en gammal rutas id men en annan tid får `-2` |
| `fil`, `vy`, `slag` | paketets (eller videons) namn, `"dtl"`/`"fo"`/`null`, slagets id eller `null` |
| `val` | `adress`, `topp`, `tidig_nedsving` eller `jamn` (PC:ns rutval, MF5), eller `P1` … `P10` (telefonens markering, M45; bara version 2) |
| `t` | Visions tid, s relativt klicket (`null` för en video) |
| `t_klipp` | den valda tiden i klippet, s: `t + klick_i_klipp_s` för ett paket, tiden jämnt över klippet för en video; `null` (version 2) när paketet inte har klippet |
| `forskjutning_ms` | S3:s förskjutning för slaget (MF1): rutan läses på OpenCV:s tid `t_klipp + forskjutning_ms / 1000`; 0 för en video; `null` (version 2) när den inte är känd (telefonen). **null betyder inte 0:** den som läser bilden ur klippet måste hämta S3:s δ för slaget (`s3.json`, MF1), annars kan rutan bli en annan än Visions |
| `t_ruta` | rutans egen tid enligt OpenCV (s), eller `null` innan den lästs |
| `bredd`, `hojd` | hela den upprätta bilden i px |
| `visad` | delen som sidan visar, `[x, y, b, h]` i px inom bilden (MF6) |
| `status` | `omarkerad`, `markerad` (alla tre punkterna satta; i version 2 räcker `grepp` och `klubbhuvud`) eller `hoppad` |
| `punkter` | exakt de tre: `null` (inte satt), `{"x", "y", "kalla"}` i hela bildens pixlar, eller `{"syns_inte": true}`. `kalla` är `klick` (ett tryck) eller, i version 2, `handlederna_bekraftad` för greppet: ringen ur handlederna som Johannes bekräftade med ett tryck (B47), så att träningsdatan kan skilja den från ett fritt tryck |
| `forslag` | ledtrådarna som visades, `{punkt: {"x", "y", "kalla"}}` (`kalla` = varifrån, t.ex. `handlederna`); de blir aldrig en punkt av sig själva |

**Punkterna** (B44): **grepp** = skaftet mitt mellan händerna; **skaftets mitt** = mitt
mellan greppet och hoseln; **klubbhuvud** = GolfPose hosel, där skaftet går in i huvudet
(research 2 §3, ej läst i original). Felen nämner rutans plats och fältet, aldrig värdet.
