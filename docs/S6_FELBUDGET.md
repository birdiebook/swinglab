# S6 — felbudget för två iPhones (simulering 2026-10-22)

**Frågan:** hur exakt kan bäckenets och bröstets vridning, X-factor och
stretch bli med två iPhones (DTL och FO), och vad avgör det? Svaret kommer
ur en simulering och inte ur en gissning, innan någon appkod skrivs.

Koden ligger i `tools/pc/tre_d/` och testerna i `tools/tests/test_tre_d_*.py`.
Allt är påhittat: en genererad sving, inga riktiga leder (CLAUDE.md,
Dataregeln). Tabellerna kommer ur

    python3 tools/pc/tre_d/felbudget.py --n 60            # alla, cirka 25 min
    python3 tools/pc/tre_d/felbudget.py --n 200 --bara bas,brus,markor

med frö 1 (`--bara brusdelar` för brusets delar). Varje rad är 60 försök, utom grunden, brusnivåerna och markörerna,
som har 200. Varje försök har en ny slumpad sving, nya kameraplaceringar, nya
tappade rutor och nytt brus. **RMSE över 60 försök har 20–30 % slumpfel**,
eftersom felen har tunga svansar (P95 är ungefär 2 × RMSE). Skillnader under
cirka 2° mellan två rader är alltså brus.

## 0. Svaret

1. **Med posemodellens punkter klarar vi inte 5° per sving.** Med det 2D-brus
   vi antar som typiskt (§3) ger hela kedjan ett RMSE på 13° för bäckenet vid
   toppen, 10° för bröstet, 16° för X-factor, 15° för stretchen och 13° för
   höfterna vid träff. Bara 20–35 % av svingarna hamnar inom 5°.
2. **2D-felet avgör nästan allt.** Kalibreringen (under 1°), synken (under 1°
   vid toppen och 1–3° vid träff), de tappade rutorna (0°) och slutartiden
   (0°) är små. Felet följer posemodellens fel i förhållande till linjens
   längd: höftlinjen är bara cirka 20 cm. En centimeter fel per led ger då
   cirka 4°. Skymda leder fördubblar felet, och med två kameror finns ingen
   tredje vy som kan ta över.
3. **Med bra 2D är målet inom räckhåll.** Med "bra" brus och utan skymning
   blir RMSE 3–5° per sving med perfekt kalibrering och synk, och 4–9° i hela
   kedjan. Med "bra" brus och skymning blir
   passets median (10 slag) 4–7° i SD. Det är alltså S3:s mätning av
   posemodellens fel som avgör om S6 håller, inte kamerorna.
4. **Två kameror behövs (BESLUT B9).** En kamera framifrån ger 15–35° RMSE
   (stretch 35°) och är fel även utan brus (bröstet 9,5°, stretch 19°), eftersom
   förkortningen inte skiljer vridning från böjning och sidböjning.
   Triangulerat utan brus: 0,2–0,4°.
5. **Markörer löser bäckenet.** En pinne genom bältet (60 cm, färgade ändar)
   ger bäckenet 1–1,5°. En stav över ryggen ger bröstet 0,5°, men bara om
   ändarna syns i båda vyerna. Med två kameror skyms ofta en ände.
6. **Facitet i S6 räcker inte som det står.** Att vrida axlarna mot linjer på
   golvet har ett eget fel (människans inriktning, antaget ±3°) och mäter en
   annan linje än vi gör. Ersätt det med en **triangulerad pinne** tvärs över
   bröstet (ger bröstkorgen inom 0,5°), en pinne i bältet, och gärna en
   telefon på bältet som rörelsefacit (§8).
7. **Definitionen flyttar X-factor 10–20°** i samma sving (§5). Våra tal kan
   jämföras med Sportsbox för bäckenet (inom cirka 2°), men inte för bröstet
   eller X-factor.

**Rekommenderad uppställning:** FO och DTL med 90° mellan sig (60–120° går),
3 m från kroppens mitt (2,5–4 m), kamerorna i höfthöjd (1,0–1,2 m), stående
1080p i 240 bilder/s, kalibrering mot minst 6 punkter på mattan spridda över
minst 1 m och inmätta på ±1 cm, synk på klicket och sedan på
återprojektionen, utjämning ±40 ms. Slutartiden påverkar inte vridningen.
Behåll 1/2000 s för klubban (BESLUT B11).

## 1. Kedjan

| Steg | Modul | Vad |
|---|---|---|
| 1 | `sving.py` | En högerspelare med 13 leder över tiden. Bäckenet och bålen har var sin vridning, framåtböjning, sidböjning och sway. Skulderbladen glider med vridningen. Händerna går i ett lutande plan, och armbågarna och knäna ges av invers kinematik. |
| 2 | `kamera.py` | Två pinhole-kameror på en cirkel kring spelaren, med ±5° fel i placeringen runt spelaren. Egna bildtider: 240 bilder/s med 36 % tappade rutor i skurar. Kamerornas rutnät är förskjutna mot varandra. 2D-brus, skymning, utliggare och rörelseoskärpa. |
| 3 | `kalibrering.py` | Inre parametrar med fel som från ChArUco. Yttre ur mattans punkter (homografi eller DLT och Levenberg–Marquardt), eller självkalibrering ur lederna (åttapunktsmetoden, Sampson-fel och lodlinjen från telefonens accelerometer). |
| 4 | `triangulering.py` | Synken: klicket lämnar ±7 ms, och finjusteringen sker på återprojektionen (eller på farten, som jämförelse). LOESS (lokal andragradsregression, robust) på varje kameras egna tider till en gemensam tidsaxel, och sedan konfidensviktad DLT. |
| 5 | `matt.py` | Vridning, X-factor, stretch och öppna höfter (§5). Samma funktion räknar det sanna värdet på de sanna lederna, så felet är bara mätningens. |
| 6 | `felbudget.py` | Monte Carlo, svep över varje felkälla och placering, facitet och definitionerna. |

Världens axlar: x mot målet, z uppåt, y från bollen mot spelarens rygg.

## 2. Svingen (antagande)

Kurvorna går genom nyckelbilder med monoton kubisk interpolation (PCHIP), så
att toppar hamnar där nyckelbilderna säger. Tiderna är adress 0,3 s,
baksving 0,80 s, nedsving 0,27 s (tempo cirka 3) och utsving 0,55 s.

| Storhet (grundsvingen, vår definition §5) | Värde | Mål ur research 1 |
|---|---|---|
| Bäckenet vid toppen | 42,8° | 40–45° (§1.7) |
| Axellinjen vid toppen | 87,2° | 85–95° (uppdraget) |
| X-factor vid toppen | 44,4° | — (egen trend, §1.8) |
| Stretch | 8,7° | 13–19 % av X-factor ≈ 6–8° (Cheetham, §1.8) |
| Höfterna öppna vid träff | 37,4° | 35–45° (§1.7) |
| Bröstets framåtböjning adress → träff | 38° → 30° | cirka 30–40° (§1.5) |
| Bröstets sidböjning topp / träff | +25° / −30° | 24–38° vid träff (§1.4) |

Slumpade svingar varierar längden (1,70–1,90 m), tempot och vinklarna (±3–4°).

**Kroppsmåtten** följer Drillis & Continis andelar av längden H (via Winter,
*Biomechanics and Motor Control of Human Movement*, fig. 4.1; standard, ej
läst i original i detta pass): lår 0,245 H, underben 0,246 H, överarm
0,186 H, underarm 0,146 H och bål (höftled till axel) 0,288 H.
**Antaganden:** höftpunkterna sitter 0,11 H isär (20 cm) och axelpunkterna
0,20 H isär (36 cm). Det är ledcentrum, inte kroppens ytterkant.
Skulderbladen glider 3,5 cm fram och 2,0 cm bak vid full vridning, så att
axellinjen vrider några grader mer än bröstkorgen vid toppen.

## 3. Kamerorna och bruset (antagande)

**Brännvidden.** iPhones huvudkamera har 26 mm ekvivalent brännvidd (Apples
tekniska data, iPhone 12–15; ej läst i original, 15 Pro har 24 mm). Den
ekvivalenta brännvidden avser 4:3-bildens diagonal, så videons långsida
motsvarar 34,6 mm och kortsidan 19,5 mm. Det ger cirka 67° × 41° och
**f ≈ 1444 px** i stående 1080 × 1920. Stabiliseringen och slowmotion-läget kan
beskära mer, upp mot cirka 1700 px. Brännvidden mäts med ChArUco. På 3 m är
1 px ≈ 2,1 mm, och bilden täcker 4,0 m på höjden men bara 2,2 m på bredden
(±1,1 m). Stående är trångt för FO: står kameran ett par grader fel åt sidan
hamnar händerna vid toppen utanför bilden.

**Bildtiderna.** 240 bilder/s nominellt, med 36 % tappade rutor i skurar (i
snitt 1,5 i rad). Det är oktobers mått i Golf SG: cirka 154 bilder/s ur 240.

**2D-bruset.** Bruset har fyra delar per led och vy. Alla tal gäller vid 3 m
och skalas med personens storlek i bilden, eftersom posemodellen beskär
personen och kör med fast upplösning.

| Nivå | Vitt | Vandring (AR(1), τ 0,15 s) | Fast per led och vy | Utliggare |
|---|---|---|---|---|
| bra | 3 px | 3 px | 3 px | 1 % × 50 px |
| typiskt (grund) | 5 px | 5 px | 5 px | 3 % × 50 px |
| dåligt | 10 px | 10 px | 8 px | 5 % × 50 px |
| mycket dåligt | 20 px | 15 px | 12 px | 8 % × 50 px |

Skymda leder får 2,5 × bruset och låg konfidens (0,35 mot 0,85). En led
räknas som skymd när strålen från kameran passerar ett lem-segment eller
bålens kärna (en kapsel) framför den. Rörelseoskärpan lägger till
0,3 × fart × exponeringstid.

Varför nivåerna är rimliga:

- MediaPipe BlazePose Heavy har PCK@0,2 96–97 % och Apple Vision 83–91 %
  (Googles egen mätning, docs/research/2_teknik.md §1). Vid 3 m är 0,2 ×
  bålens diameter cirka 48 px. Om felet vore normalfördelat motsvarar det
  högst cirka 18 px (Heavy) och 25 px (Vision) i 1σ.
- COCO:s utvärdering av nyckelpunkter (OKS) bygger på hur mycket människor
  sprider sig när de märker samma punkt: σ ≈ 5 % av objektets skala för
  höfterna och 4 % för axlarna (k = 0,107 och 0,079; standard, siffrorna ur
  minnet, ej kontrollerade i detta pass). Med skala ≈ 370 px blir det cirka
  20 px och 15 px. Modellerna tränas på de märkningarna, så höftpunkten är
  oskarp redan i facit.

"Typiskt" (cirka 9 px per led och axel) ligger alltså mitt i spannet.
**Ingen av nivåerna är mätt på golf.** S3 ska mäta den.

## 4. Kalibreringen, trianguleringen och synken

- **Inre parametrar:** ChArUco en gång per telefon och linsläge, med fel
  ±0,5 % i brännvidd och ±3 px i huvudpunkt (antagande). Att i stället ta
  dem ur specifikationen (±5 %, ±20 px) kostar under 1°.
- **Yttre mot mattan:** N punkter i marken (rutnät, hörnen först), klickade
  med ±2 px och inmätta på ±5 mm. Läget skattas ur en homografi (Zhang 2000)
  eller med DLT när punkter ligger ovan marken, och förfinas sedan med
  Levenberg–Marquardt med K fast.
- **Självkalibrering:** lederna i båda vyerna under hela svingen ger
  1 000–3 000 punktpar. Kamerornas relativa läge fås ur den viktade och
  normaliserade åttapunktsmetoden (Hartley 1997), med robusta varv och
  förfining på Sampson-felet. Skalan blir okänd, men vinklar behöver ingen
  skala. Lodlinjen kommer från telefonens accelerometer, och mållinjen behövs
  inte eftersom vridningen mäts mot adressen.
- **Synken:** klicket lämnar ±7 ms (likformigt). Finjusteringen väljer den
  förskjutning som ger minst återprojektionsfel för handleder och armbågar i
  nedsvingen. Vi jämför med korskorrelation av den lodräta farten (som
  Pose2Sim och OpenCap).
- **Utjämningen:** LOESS med trikubisk kärna, ±20 ms för 2D-spåren och
  ±30 ms för vinkelkurvorna. Två robusta varv (bisquare) tar bort utliggarna.
  Varje kameras rutor används på sina egna tider, utan avrundning till hela
  rutor.
- **Trianguleringen:** DLT i normaliserade koordinater, där varje kameras
  rader vägs med konfidensen. Med två kameror finns bara en överflödig
  ekvation, så vikten kan inte kasta en dålig vy. Ett fel i en vy går rakt in
  i 3D.

## 5. Definitionerna

| Mått | Vår definition |
|---|---|
| Bäckenets vridning θp | Linjen höger höft → vänster höft, projicerad på markplanet (mattans plan). Vinkeln mot samma linje i adressen. Positiv bort från målet. |
| Bröstets vridning θs | Samma sak för linjen höger axel → vänster axel. Posemodellens axelpunkter ligger nära axellederna, så linjen är en **akromionlinje**, inte bröstkorgens (thorax) sidoaxel. |
| X-factor | θs − θp vid toppen. |
| Toppen | Där händernas mitt står högst mellan start och träff (S1). Toppen kan också sättas vid bäckenets vändning (`topp="backen"`); research 1 §1.8 föreslår det för stretchen. |
| Stretch | Största X i tidig nedsving (toppen till halva tiden mot träffen) minus X vid toppen, i grader. |
| Höfterna öppna vid träff | −θp vid träffen (klicket). |

**Jämfört med andra system:**

- **Sportsbox** (tillverkare, ej läst i original) anger bäckenet ≈ −40° vid
  toppen och +40° öppet vid träff, alltså med motsatt tecken mot vårt.
  Sportsbox räknar 3D ur en kamera med en kroppsmodell, troligen som segmentens
  vinkel mot mållinjen. Vi mäter mot adressen, så skillnaden är adressens egen
  vinkel (några grader).
- **GEARS** (markörer på kroppen) och forskningens 3D-metoder (Brown 2013)
  ger segmentens Eulervinklar, där bröstkorgen definieras av markörer på
  bröstbenet och ryggen, inte av axellederna.
- **Kwon** och de flesta 2D-studier projicerar akromionlinjen och höftlinjen
  på horisontalplanet. Det är närmast vår definition.

Samma sving, utan brus, med tre definitioner:

| | Euler (ZXY) | Bröstkorgens sidoaxel, projicerad | Axellinjen (akromion), projicerad |
|---|---|---|---|
| Bröst, topp | 99,0 | 78,6 | 87,2 |
| Bröst, träff | -32,0 | -22,1 | -25,0 |
| Bäcken, topp | 44,5 | 42,8 (höftlinjen) | |
| Bäcken, träff | -40,0 | -37,4 (höftlinjen) | |
| X-factor, topp | 54,5 | 35,8 | 44,4 |

Stretch (axellinjen): 8,7°

Skillnaden kommer av bålens framåt- och sidböjning: en vriden och
böjd bål lutar sidoaxeln, och projektionen på marken krymper vinkeln.
Sidböjningen vid toppen (+25°) gör det mest. Skulderbladen lägger sedan till
8–9° på akromionlinjen. **X-factor skiljer 19° mellan definitionerna (35,8
mot 54,5) i en och samma sving.** Det stämmer med research 1 (§1.8: 2D mot 3D
cirka 16°, signifikanta skillnader mellan 3D-metoder). För bäckenet är
skillnaden bara 1,7–2,6°, eftersom bäckenet böjer och sidböjer mindre.
Skulderbladens glidning är ett antagande. Wheat m.fl. fann −16° för
akromionvektorn vid toppen (ej läst i original).

## 6. Resultaten

Alla tal är i grader och är **skattat − sant**, där det sanna räknas med
samma definition på de sanna lederna.

### 6.1 Grunduppställningen (200 försök)

| Metod | Bäcken, topp | Bröst, topp | X-factor, topp | Stretch | Höfter öppna, träff |
|---|---|---|---|---|---|
| Två kameror, triangulerat | +1,1 / 13,0 | -0,5 / 10,5 | -1,6 / 16,1 | +9,0 / 11,7 | +0,5 / 13,4 |
| Två vyer, bildmått utan kalibrering | +1,4 / 13,8 | +6,2 / 12,4 | +4,8 / 15,7 | +12,9 / 14,0 | +3,4 / 15,0 |
| En kamera FO (förkortning) | -3,5 / 19,0 | -8,9 / 12,4 | -5,4 / 22,8 | +27,9 / 20,3 | -3,8 / 21,4 |

| Metod | Bäcken, topp | Bröst, topp | X-factor, topp | Stretch | Höfter öppna, träff |
|---|---|---|---|---|---|
| Två kameror: RMSE / P95 / inom 5° | 13,0 / 26,4 / 27 % | 10,5 / 19,3 / 35 % | 16,1 / 31,8 / 20 % | 14,8 / 31,6 / 30 % | 13,4 / 27,0 / 29 % |
| Två vyer 2D: RMSE / P95 / inom 5° | 13,9 / 26,4 / 28 % | 13,8 / 26,9 / 30 % | 16,4 / 32,5 / 24 % | 19,0 / 39,7 / 22 % | 15,3 / 30,6 / 25 % |
| En kamera: RMSE / P95 / inom 5° | 19,3 / 42,2 / 28 % | 15,3 / 33,2 / 32 % | 23,4 / 45,0 / 18 % | 34,5 / 59,7 / 8 % | 21,6 / 38,2 / 17 % |

Synkens rest efter finjusteringen: RMS 2,6 ms. Toppens tid: RMS 10,8 ms.

"Två vyer, bildmått" är metoden utan kalibrering: varje bilds vågräta avstånd
läses som linjens komponent längs kamerans antagna riktning. Den ger 1–11°
fel även utan brus (bröstet 10,7°), eftersom den inte tar hänsyn till
perspektiv eller till att stativen står ±5° fel. Triangulerat utan brus blir
felet 0,2–0,4°.

Utan brus och med bra brus (RMSE, 40 försök, frö 11, `monte_carlo(..., metoder=("3d", "tva_2d", "fo_en"))`):

| | Bäcken, topp | Bröst, topp | X-factor, topp | Stretch | Höfter öppna, träff |
|---|---|---|---|---|---|
| Inget brus: två kameror | 0,2 | 0,3 | 0,2 | 0,3 | 0,4 |
| Inget brus: två vyer 2D | 4,3 | 10,7 | 8,1 | 1,4 | 4,4 |
| Inget brus: en kamera FO | 4,8 | 9,5 | 11,9 | 18,6 | 5,3 |
| Bra brus: två kameror | 9,5 | 5,7 | 11,7 | 7,0 | 8,2 |
| Bra brus, utan skymning: två kameror | 8,2 | 3,5 | 9,0 | 9,2 | 5,0 |

### 6.2 Vilket bidrag dominerar

En felkälla i taget, med allt annat perfekt (60 försök):

| Felkälla | Bäcken, topp | Bröst, topp | X-factor, topp | Stretch | Höfter öppna, träff |
|---|---|---|---|---|---|
| Inget fel (bara utjämningen) | 0,0 | 0,0 | 0,1 | 0,1 | 0,0 |
| Bara tappade rutor (36 %) | 0,1 | 0,0 | 0,1 | 0,1 | 0,0 |
| Bara 2D-brus, bra | 4,2 | 3,2 | 4,9 | 3,2 | 4,5 |
| Bara 2D-brus, typiskt | 7,1 | 5,5 | 8,9 | 5,7 | 5,9 |
| Bara 2D-brus, dåligt | 12,0 | 9,9 | 15,2 | 11,7 | 13,2 |
| Bara 2D-brus, mycket dåligt | 18,4 | 15,0 | 24,0 | 24,3 | 18,0 |
| Bara skymning (typiskt brus) | 13,0 | 6,4 | 14,6 | 10,1 | 11,9 |
| Bara synkfel ±7 ms, ingen finjustering | 0,1 | 0,0 | 0,1 | 0,7 | 0,7 |
| Bara synkfel ±15 ms, ingen finjustering | 0,2 | 0,1 | 0,1 | 1,5 | 1,6 |
| Bara synkfel ±30 ms, ingen finjustering | 0,4 | 0,1 | 0,4 | 3,3 | 3,2 |
| Bara kalibrering mot mattan (10 p, 1,5 m) | 0,2 | 0,2 | 0,2 | 0,1 | 0,1 |
| Bara inre parametrar ur specifikationen (f ±5 %, c ±20 px) | 0,9 | 0,5 | 1,1 | 0,2 | 0,7 |
| Hela kedjan (grunduppställningen) | 12,9 | 10,4 | 14,2 | 13,8 | 13,4 |

Brusets delar en i taget, med tappade rutor men utan skymning, och med
perfekt kalibrering och synk (60 försök):

| Brusdel | Bäcken, topp | Bröst, topp | X-factor, topp | Stretch | Höfter öppna, träff |
|---|---|---|---|---|---|
| Vitt 5 px | 3,0 | 1,8 | 3,3 | 5,4 | 3,0 |
| Vandring 5 px (τ 0,15 s) | 6,3 | 3,0 | 6,8 | 4,2 | 5,6 |
| Fast 5 px per led och vy | 3,6 | 3,9 | 5,4 | 0,9 | 3,2 |
| Utliggare 3 % × 50 px | 2,0 | 3,5 | 4,2 | 3,4 | 2,9 |
| Typiskt utan fast avvikelse | 6,6 | 3,6 | 7,7 | 7,4 | 6,3 |
| Typiskt, alla delar | 6,7 | 4,9 | 9,1 | 7,8 | 7,4 |

Hela kedjan per brusnivå, med skymning (200 försök):

| Brus | Bäcken, topp | Bröst, topp | X-factor, topp | Stretch | Höfter öppna, träff |
|---|---|---|---|---|---|
| 2D-brus bra | 8,8 | 5,7 | 11,0 | 8,6 | 6,7 |
| 2D-brus typiskt | 13,0 | 10,5 | 16,1 | 14,8 | 13,4 |
| 2D-brus dåligt | 27,1 | 20,1 | 34,7 | 32,4 | 26,2 |
| 2D-brus mycket dåligt | 45,7 | 26,8 | 53,2 | 54,7 | 42,8 |

**Slutsatser:**

- Bara 2D-bruset och skymningen ger fel som syns. Kalibreringen (0,1–0,2°),
  inre parametrar ur specifikationen (under 1,1°) och de tappade rutorna
  (0,1°) gör det inte. Synkfelet kostar 0,7° vid ±7 ms och 3° vid ±30 ms,
  och bara i stretchen och höfterna vid träff.
- Av brusets delar är **vandringen värst** (6,3° för bäckenet vid 5 px). Den
  är långsam, så utjämningen tar inte bort den. Den fasta avvikelsen kostar
  3–5°, och vitt brus 2–3°. Det vita bruset ger stretchen ett fel uppåt
  (+5°), eftersom ett max av en brusig kurva blir för stort.
- Delarna adderas ungefär i kvadrat. 5 px av varje ger 7–9°, och skymningen
  fördubblar det.
- **Tumregeln:** vinkelfelet i radianer ≈ √2 · σ(led) / linjens längd, och
  √2 till mot adressen. För höftlinjen på 20 cm ger 1 cm per led cirka 4–6°.
  För axellinjen på 36 cm ger samma fel 2–3°. Höftpunkternas avstånd styr
  direkt:

| Höftlinjen | Bäcken, topp | Bröst, topp | X-factor, topp | Stretch | Höfter öppna, träff |
|---|---|---|---|---|---|
| 0,09 × längden (16 cm) | 15,6 | 10,4 | 17,0 | 17,6 | 18,4 |
| 0,11 × längden (20 cm) | 12,9 | 10,4 | 14,2 | 13,8 | 13,4 |
| 0,14 × längden (25 cm) | 10,5 | 10,4 | 12,1 | 10,9 | 9,1 |
| 0,17 × längden (31 cm) | 8,6 | 10,4 | 11,0 | 9,8 | 7,3 |

### 6.3 Synken

| Synkfel, finjustering | Bäcken, topp | Bröst, topp | X-factor, topp | Stretch | Höfter öppna, träff | Synkens rest (ms, RMS) |
|---|---|---|---|---|---|---|
| ±7 ms, ingen | 12,8 | 10,1 | 14,2 | 13,7 | 13,4 | 4,2 |
| ±7 ms, fart | 12,7 | 10,2 | 14,7 | 13,6 | 13,7 | 7,0 |
| ±7 ms, reprojektion | 12,9 | 10,4 | 14,2 | 13,8 | 13,4 | 2,1 |
| ±15 ms, ingen | 13,0 | 10,1 | 14,1 | 13,3 | 13,4 | 9,0 |
| ±15 ms, fart | 12,6 | 10,3 | 14,6 | 13,7 | 13,8 | 9,9 |
| ±15 ms, reprojektion | 12,9 | 10,4 | 14,1 | 13,8 | 13,4 | 2,1 |
| ±30 ms, ingen | 12,7 | 9,9 | 13,9 | 13,0 | 14,0 | 18,0 |
| ±30 ms, fart | 12,6 | 10,2 | 14,6 | 13,8 | 13,8 | 12,6 |
| ±30 ms, reprojektion | 12,9 | 10,4 | 14,2 | 13,7 | 13,4 | 2,1 |

Återprojektionen tar ner synken till cirka 2 ms RMS, oavsett om felet från
början är ±7 eller ±30 ms. Korskorrelation av farten (Pose2Sims och OpenCaps
väg) ger 7–13 ms, alltså sämre än att inte finjustera alls vid ±7 ms.
Farten i bilden ser olika ut i de två vyerna, och provet utan brus ger
5 ms fel. Synken spelar liten roll för vridningen vid toppen, där bäcken och
bröst rör sig långsamt.

### 6.4 Placeringen

| Vinkel | Bäcken, topp | Bröst, topp | X-factor, topp | Stretch | Höfter öppna, träff |
|---|---|---|---|---|---|
| 30° | 29,0 | 34,3 | 35,7 | 42,7 | 30,3 |
| 60° | 16,9 | 10,9 | 14,6 | 15,5 | 14,2 |
| 90° | 12,9 | 10,4 | 14,2 | 13,8 | 13,4 |
| 120° | 14,5 | 11,4 | 18,1 | 18,0 | 13,7 |
| 150° | 24,9 | 22,0 | 34,4 | 42,8 | 23,6 |

| Avstånd | Bäcken, topp | Bröst, topp | X-factor, topp | Stretch | Höfter öppna, träff |
|---|---|---|---|---|---|
| 2 m, felet följer kroppen | 14,2 | 11,3 | 13,7 | 12,4 | 14,0 |
| 3 m, felet följer kroppen | 12,9 | 10,4 | 14,2 | 13,8 | 13,4 |
| 4 m, felet följer kroppen | 12,7 | 10,2 | 14,2 | 14,4 | 13,1 |
| 5 m, felet följer kroppen | 12,8 | 10,2 | 14,3 | 14,4 | 13,1 |
| 2 m, felet fast i px | 11,2 | 9,7 | 9,8 | 8,2 | 9,2 |
| 3 m, felet fast i px | 13,4 | 10,9 | 14,6 | 14,5 | 14,3 |
| 4 m, felet fast i px | 16,9 | 13,9 | 20,1 | 20,9 | 20,5 |
| 5 m, felet fast i px | 21,7 | 16,9 | 24,7 | 27,5 | 23,3 |

| Höjd | Bäcken, topp | Bröst, topp | X-factor, topp | Stretch | Höfter öppna, träff |
|---|---|---|---|---|---|
| 0,5 m | 11,1 | 10,4 | 13,7 | 13,6 | 13,6 |
| 1,0 m | 12,9 | 10,4 | 14,2 | 13,8 | 13,4 |
| 1,5 m | 14,4 | 8,6 | 15,0 | 16,0 | 13,8 |
| 2,0 m | 13,9 | 6,3 | 14,4 | 15,1 | 14,2 |

- **Vinkeln:** 90° är bäst, och 60–120° kostar 0–4°. Vid 30° och 150° blir
  felet två till tre gånger större, eftersom djupet blir dåligt bestämt.
- **Avståndet** spelar nästan ingen roll så länge posemodellens fel följer
  personens storlek i bilden ("felet följer kroppen"). Om felet i stället är
  fast i pixlar växer det med avståndet (5 m: 1,5–2 ×). Stående bild på 2 m
  täcker bara ±0,75 m i bredd, så 2,5–4 m är rimligt och 3 m är grunden.
- **Höjden:** 1,5–2,0 m ger bröstet bättre (6–9° mot 10°), eftersom
  axellinjen syns mer ovanifrån, men bäckenet blir något sämre. Höfthöjd
  (1,0 m) är en bra kompromiss. Om axlarna ska prioriteras kan DTL-kameran
  sitta högre än FO.

### 6.5 Kalibreringen: hur många mattpunkter, hur långt isär

| Mattpunkter | Bäcken, topp | Bröst, topp | X-factor, topp | Stretch | Höfter öppna, träff |
|---|---|---|---|---|---|
| 4 punkter, 1,5 m | 0,2 | 0,3 | 0,2 | 0,1 | 0,2 |
| 6 punkter, 1,5 m | 0,2 | 0,3 | 0,3 | 0,1 | 0,2 |
| 10 punkter, 1,5 m | 0,2 | 0,2 | 0,2 | 0,1 | 0,1 |
| 16 punkter, 1,5 m | 0,2 | 0,2 | 0,2 | 0,1 | 0,1 |
| 10 punkter, 0,5 m | 0,5 | 0,7 | 0,6 | 0,2 | 0,4 |
| 10 punkter, 1,0 m | 0,3 | 0,3 | 0,3 | 0,1 | 0,2 |
| 10 punkter, 3,0 m | 0,2 | 0,2 | 0,2 | 0,1 | 0,1 |
| 10 punkter, 1,5 m + 4 på pinnar | 0,2 | 0,2 | 0,2 | 0,1 | 0,1 |
| 10 punkter, klick 5 px | 0,3 | 0,4 | 0,3 | 0,1 | 0,2 |
| 10 punkter, lägen ±2 cm | 0,6 | 0,6 | 0,6 | 0,2 | 0,4 |
| 10 punkter, klick 0,5 px (ArUco) | 0,2 | 0,2 | 0,2 | 0,1 | 0,1 |

| Kalibrering | Bäcken, topp | Bröst, topp | X-factor, topp | Stretch | Höfter öppna, träff |
|---|---|---|---|---|---|
| Mattan, 10 punkter | 12,9 | 10,4 | 14,2 | 13,8 | 13,4 |
| Självkalibrering, lodlinje ±0,5° | 14,3 | 10,9 | 17,1 | 16,0 | 9,9 |
| Självkalibrering, lodlinje ±1° | 14,3 | 10,9 | 17,1 | 16,0 | 9,9 |
| Självkalibrering, lodlinje ±3° | 14,3 | 10,6 | 17,2 | 15,9 | 9,9 |
| Självkalibrering, dåligt brus | 21,5 | 16,5 | 28,2 | 25,3 | 24,2 |

- Kalibreringen är aldrig flaskhalsen. **6 punkter spridda över 1,5 m räcker**
  (0,2–0,3°), och 4 punkter går nästan lika bra. Spridningen betyder mer än
  antalet: 0,5 m ger 0,5–0,7°. Pose2Sims krav på minst 10 punkter är
  generöst, men fler punkter ger en kontroll på felklick.
- Lägena ±2 cm kostar 0,6°, klick på 5 px 0,3°, och punkter ovan marken ger
  inget.
- **Självkalibreringen med lodlinjen är likvärdig med mattan** (inom
  slumpfelet), och lodlinjens fel (0,5–3°) spelar ingen roll, eftersom vi mäter
  mot adressen. Den kräver inget måttband, men skalan saknas, så sway i cm
  kräver ändå ett känt mått: mattan eller klubbans längd. Med dåligt brus blir
  den sämre.

### 6.6 Exponeringen och utjämningen

| Slutartid | Bäcken, topp | Bröst, topp | X-factor, topp | Stretch | Höfter öppna, träff |
|---|---|---|---|---|---|
| 1/250 s | 12,6 | 10,5 | 14,3 | 13,9 | 13,4 |
| 1/500 s | 12,9 | 10,4 | 14,1 | 13,8 | 13,4 |
| 1/1000 s | 12,9 | 10,4 | 14,2 | 13,8 | 13,4 |
| 1/2000 s | 12,9 | 10,4 | 14,2 | 13,8 | 13,4 |

| Halvbredd | Bäcken, topp | Bröst, topp | X-factor, topp | Stretch | Höfter öppna, träff |
|---|---|---|---|---|---|
| ±10 ms | 14,4 | 8,9 | 17,2 | 14,2 | 13,6 |
| ±20 ms | 12,9 | 10,4 | 14,2 | 13,8 | 13,4 |
| ±40 ms | 11,3 | 8,6 | 13,9 | 9,6 | 11,6 |
| ±60 ms | 11,2 | 8,1 | 13,7 | 8,4 | 10,8 |

Slutartiden påverkar inte vridningen: höfter och axlar rör sig långsamt. Den
gäller armarna och klubban (B11). En bredare utjämning (±40–60 ms) sänker
stretchens fel från 14° till 8–10° och de andra med 1–2°. **Använd ±40 ms**
för 2D-spåren. Med ±60 ms börjar det jämna ut verkliga toppar.

### 6.7 Passets median

| Uppställning | Bäcken, topp | Bröst, topp | X-factor, topp | Stretch | Höfter öppna, träff |
|---|---|---|---|---|---|
| Grund (typiskt brus) | +1,3 / 10,0 | +1,8 / 8,4 | +0,7 / 12,9 | +9,5 / 6,9 | +0,5 / 11,7 |
| Bra brus | +1,7 / 5,6 | +1,2 / 4,0 | -0,8 / 7,4 | +3,3 / 3,7 | -0,7 / 5,5 |
| Dåligt brus | -2,1 / 17,8 | +0,9 / 9,3 | +2,8 / 21,2 | +17,7 / 11,5 | +6,2 / 14,9 |
| Bra brus, självkalibrering (40 pass) | -0,0 / 6,1 | +0,2 / 4,7 | -0,1 / 6,0 | +4,2 / 3,5 | -0,5 / 5,5 |
| Typiskt brus, självkalibrering (40 pass) | -1,9 / 7,4 | +0,2 / 7,6 | +2,0 / 11,0 | +6,1 / 4,7 | +3,0 / 8,6 |

Raderna med självkalibrering är `pass_monte_carlo(replace(Uppstallning(), brus=…,
kalib="sjalv"), 40, 10, seed=1)` (S6a).

**Kedjan på paketen (S6a, `tools/pc/tva_kameror.py`).** Påhittade pass om 10 slag ur
`generera_paket.tva_paket` (frö 100–123), genom paketen, parningen, 2D-faserna,
självkalibreringen per pass, synken och trianguleringen. Felet är passets median
minus de sanna svingarnas median (bias / SD, och största |fel|):

| Brus (pass) | Bäcken, topp | Bröst, topp | X-factor, topp | Stretch | Höfter öppna, träff |
|---|---|---|---|---|---|
| Inget (8) | -0,2 / 0,1 | -0,1 / 0,1 | +0,1 / 0,1 | -0,2 / 0,1 | +0,1 / 0,0 |
| Bra (24) | -0,3 / 5,9, max 14,5 | +1,3 / 5,7, max 12,4 | +2,1 / 7,8, max 20,2 | +1,9 / 3,5, max 9,1 | +1,1 / 3,6, max 7,5 |
| Typiskt (24) | -0,1 / 11,1, max 30,6 | +1,2 / 9,6, max 21,1 | +0,9 / 13,6, max 27,1 | +4,7 / 5,7, max 17,6 | +0,9 / 5,9, max 14,7 |
| Typiskt, sanna kameror (24) | -0,3 / 10,4 | +0,6 / 6,4 | +0,6 / 13,1 | +4,4 / 5,5 | +1,4 / 5,9 |

Kedjan ligger inom felbudgetens grundrader ovan (alla 48 pass inom |bias| + 3 SD), med
två skillnader. Höfterna vid träffen blir bättre (3,6–5,9 mot 5,5–11,7°), eftersom
utjämningen är ±40 ms (§6.6). Bröstet blir sämre med självkalibrering än med sanna
kameror (9,6 mot 6,4° med typiskt brus): kalibreringens vridningsfel är i snitt 5°,
upp till 14° (12 pass), och det kommer av posemodellens fasta avvikelse, inte av
antalet punktpar (BESLUT B38). Synkens rest är 1,5 ms RMS med bra brus och 2,4 ms med
typiskt. Testerna (`tools/tests/test_tva_kameror.py`) kör fem av passen.

Medianen av 10 slag tar bort det slumpmässiga, men inte den fasta avvikelsen,
som är densamma hela passet. Med bra brus blir passets SD 4–7°, och
stretchen får ett fel uppåt på 3°. Med typiskt brus blir den 7–13°. Som trend
från pass till pass gäller bara spridningen, eftersom en fast avvikelse som
är lika varje pass tar ut sig själv.

### 6.8 Markörer i stället för posemodellens punkter

| Punkter | Bäcken, topp | Bröst, topp | X-factor, topp | Stretch | Höfter öppna, träff |
|---|---|---|---|---|---|
| Posemodellens punkter (grund) | 13,0 | 10,5 | 16,1 | 14,8 | 13,4 |
| Pinne 60 cm i bältet + stav 50 cm över ryggen, ändarna syns | 0,8 | 0,5 | 1,0 | 1,1 | 0,5 |
| Bara pinnen i bältet, ändarna syns | 1,0 | 9,4 | 9,4 | 7,7 | 0,5 |
| Bara pinnen i bältet, med skymning | 1,4 | 9,4 | 11,1 | 6,8 | 0,7 |

En pinne genom bältesöglorna med färgade ändar (antaget fel 1 px) ger
**bäckenet inom 1–1,5°**, även med skymning. Linjen är tre gånger längre, och en
färgdetektor har varken fast avvikelse eller vandring. Staven över ryggen (en
sele) ger bröstkorgen inom 0,5°, men bara om ändarna syns. I adressen ligger
staven i linje med DTL-kameran, så den bortre änden skyms. Det kräver en
DTL-kamera som står 15–30° vid sidan av linjen, eller fler markörer på staven.
Det är oprövat.

## 7. Rekommenderad uppställning

| | Rekommendation | Varför (§) |
|---|---|---|
| Kamerorna | FO och DTL, 90° mellan sig (60–120° går) | 6.4 |
| Avstånd | 3 m från kroppens mitt (2,5–4 m) | 6.4, och stående bild täcker ±1,1 m på 3 m |
| Höjd | 1,0–1,2 m (höfthöjd); DTL får sitta högre för bröstet | 6.4 |
| Format | Stående 1080p, 240 bilder/s, fokus och zoom låsta | 3 |
| Slutare och ljus | 1/2000 s för klubban (B11); spelar ingen roll för vridningen | 6.6 |
| Inre kalibrering | ChArUco en gång per telefon och läge | 4, 6.2 |
| Mattan | ≥ 6 punkter (hellre 8–10 för kontroll), spridda ≥ 1 m, inmätta på ±1 cm; gärna ArUco-markörer i hörnen | 6.5 |
| Alternativ | Självkalibrering ur lederna och accelerometerns lodlinje, plus ett känt mått för skalan | 6.5 |
| Synk | Klicket, sedan minsta återprojektionsfel på handleder och armbågar (inte korskorrelation av fart) | 6.3 |
| Utjämning | LOESS ±40 ms på 2D, ±30 ms på vinklarna | 6.6 |
| Posemodell | Den med minst fel på höfter och axlar i S3. Mät vandringen, inte bara medelfelet | 6.2 |
| Visa | Passets median med band = passets spridning, X-factor och stretch som egen trend (PLAN S6) | 6.7 |

**Är S6 realistisk?** Ja, som trendmått per pass, om posemodellen når "bra"
nivå. Nej, som mått per sving inom 5° med posemodellens höftpunkter. Klart
när-kravet (5° mot facit i adress) nås i simuleringen bara med bra brus och
utan skymning: 87–93 % inom 5° (§8). Med typiskt brus blir det 43–57 %.

## 8. Facitet

Simulerat: en stillastående pose i adress med axellinjen på 0°, 45° och 90°,
filmad 1 s per vinkel och triangulerad. Den jämförs med tre saker: golvlinjen
(människan når den med ett antaget fel på ±3°), en pinne på 1 m tvärs över
bröstet (12 cm framför, ändarna klickade med ±2 px) och den sanna linjen.

| Brus, vinkel (bias / SD; typiskt 30 försök ur `--n 60`, bra 30 försök med `facit_monte_carlo`, frö 1) | Axellinjen mot golvlinjen | Axellinjen mot pinnen | Pinnen mot bröstkorgen | Mätfelet mot sann axellinje | Inom 5° mot golvlinjen |
|---|---|---|---|---|---|
| typiskt, 45° | +0,3 / 7,4 | +3,9 / 6,2 | +0,1 / 0,5 | +0,8 / 6,2 | 57 % |
| typiskt, 90° | +1,0 / 7,8 | +8,1 / 6,7 | +0,0 / 0,7 | +1,8 / 6,7 | 43 % |
| bra, 45° | -0,6 / 5,5 | +3,2 / 3,9 | -0,1 / 0,5 | -0,1 / 3,9 | 57 % |
| bra, 90° | -0,7 / 5,6 | +5,7 / 4,4 | +0,0 / 0,6 | -0,6 / 4,3 | 67 % |
| bra, utan skymning, 45° | -0,4 / 3,6 | +2,9 / 2,4 | +0,0 / 0,5 | -0,2 / 2,4 | 93 % |
| bra, utan skymning, 90° | -0,1 / 3,4 | +5,8 / 2,3 | +0,1 / 0,4 | -0,4 / 2,3 | 87 % |

- **Golvlinjerna är ett svagt facit.** Människans eget inriktningsfel ligger i
  samma storlek som kravet (5°). Ingen ser heller sin akromionlinje
  projicerad på golvet när överkroppen lutar 38° framåt.
- **Pinnen är ett bra facit för bröstkorgen** (inom 0,5–0,7°). Den mäter
  thorax, inte akromionlinjen. Skillnaden mellan dem vid 90° (+6–8° i
  modellen, ur skulderbladens antagna glidning) är just definitionsskillnaden
  i §5, och den ska mätas, inte gömmas.
- **Förslaget:**
  1. **Statiskt:** stå i adress med en pinne (alignment stick) tvärs över
     bröstet, ändarna tejpade i en färg som inte finns i bilden, och vrid till
     ungefär 0°, 45° och 90°. Pinnens ändar trianguleras (de syns tydligt,
     och en färgdetektor ger under 1 px). Jämför posemodellens axellinje med
     pinnen. Lägg samtidigt en pinne genom bältet för bäckenet.
  2. **I rörelse:** vridövningen med en klubba eller pinne över bröstet
     (armarna i kors), halvsvingar med pinnen i bältet, och en iPhone i en
     löparväska på bältet som spelar in CoreMotion (attityd, 100 Hz). På
     2 s glider gyrot under 1–2° (antagande), och det ger bäckenets fart
     som en sanning (research 2 §5 punkt 5).
  3. **Klart när (förslag):** posemodellens vridning av bäcken och bröst
     ligger inom 5° från pinnarna i passets median (10 försök per vinkel),
     och spridningen per sving står som band i vyn.

## 9. Vad som är antagande

- **2D-brusets storlek och form** (§3). Hela slutsatsen hänger på det. Det
  är inte mätt för golf. S3 ska mäta repeterbarheten i stillastående
  (vandringen och det vita bruset) och avvikelsen mot pinnarna (den fasta
  delen). Om den fasta avvikelsen i verkligheten följer kroppen (posemodellen
  sätter punkten konsekvent på samma ställe på kroppen) i stället för bilden,
  försvinner den ur vridningen, och felet blir mindre än här.
- **Skymningsmodellen** (kapslar och 2,5 × bruset). Den är grov, och
  skymningen fördubblar felet, så den behöver mätas.
- **Svingen**: kurvorna, sidböjningen och skulderbladens glidning. De styr
  definitionsskillnaderna i §5, men knappt mätfelen.
- **Brännvidden** 1444 px ur 26 mm ekvivalent (mäts med ChArUco).
- **Linsens distorsion** är inte med. iPhones video antas vara rättad, och
  ChArUco skattar resten.
- **Människans inriktning** mot golvlinjer: ±3°.
- **Telefonen som rörelsefacit**: gyrots drift under 1–2° på 2 s.
- Varje försök har en ny slumpad sving, men alla är samma typ av sving
  (järn, högerspelare, tempo cirka 3).

## 10. Förslag till METOD och BESLUT

Förslagen förs inte in här. `PLAN.md`, `docs/BESLUT.md` och `docs/METOD.md`
är orörda. Numren sätts när raderna förs in.

**METOD (förslag):**

| Rad | Innehåll | Status |
|---|---|---|
| Vridningen i 3D | Linjen höger → vänster (höfter eller axlar), triangulerad, projicerad på mattans plan, vinkeln mot adressen. Positiv bort från målet. | standard (Kwons projektion), egen tillämpning |
| X-factor och stretch | X = axellinjen − höftlinjen vid toppen (händerna högst). Stretch = max X under toppen … halva tiden till träffen, minus X vid toppen, i grader. | forskning (Cheetham, ej läst i original), egen definition |
| Synk | Klicket (±7 ms), sedan minsta medianfel vid återprojektion av handleder och armbågar i nedsvingen, med sökfönster ±1,5 × felet och steg 0,5 ms. | antagande, simulerat: 2 ms RMS |
| Utjämning | LOESS: trikubisk kärna, lokal andragradsregression, två bisquare-varv med MAD-golv 2 px. ±40 ms för 2D och ±30 ms för vinklarna. | standard (Cleveland 1979) |
| Triangulering | DLT i normaliserade koordinater, varje kameras rader vägda med konfidensen. | standard (Hartley & Zisserman) |
| Kalibrering mot mattan | ≥ 6 punkter spridda ≥ 1 m. Homografi (Zhang) eller DLT, sedan LM med K fast. | standard; antalet simulerat |
| Självkalibrering | Viktad åttapunktsmetod, Sampson-LM och accelerometerns lodlinje. Skalan ur ett känt mått. | standard (Hartley 1997), antagande för golf |
| Kameran | f ≈ 1444 px (26 mm ekvivalent, 1080 × 1920 stående) tills ChArUco mätt den. | tillverkare, ej läst i original |
| 2D-brus | Nivåerna i §3 tills S3 mätt dem. | antagande |
| Kroppsmått | Drillis & Contini (andelar av H). Höftpunkterna 0,11 H isär och axelpunkterna 0,20 H. | standard, ej läst i original; antagande |

**BESLUT (förslag):**

- **Vridningen ur två kameror mäts som projicerad linje mot adressen.**
  Valt: akromion- och höftlinjen i markplanet. Bortvalt: segmentens
  Eulervinklar (kräver bröstkorgens orientering, som posemodellen inte ger)
  och vinkel mot mållinjen (kräver mållinjen ur mattan). Kostnad: talen går
  inte att jämföra med Sportsbox eller GEARS för bröstet och X-factor
  (10–20° isär); bäckenet går (cirka 2°). Omprövas om markörer på bröstet
  kommer in.
- **Synken finjusteras på återprojektionen, inte på farten.** Simulerat:
  2 ms mot 7–13 ms.
- **Kalibreringen sker mot mattan med ≥ 6 punkter**, med självkalibrering ur
  lederna och lodlinjen som reserv. Pose2Sims krav på 10 punkter är inte
  nödvändigt.
- **S6:s facit blir triangulerade pinnar** (bröstet och bältet) och en telefon
  på bältet, inte golvlinjer. Klart när enligt §8 punkt 3. Det ändrar PLAN S6
  och är Johannes beslut.
- **Vridningen visas som passets median med band**, inte per sving med en
  gradgräns, tills S3 visat att 2D-felet är på "bra" nivå. Det stämmer med
  PLAN S6 för X-factor och utvidgar det till bäcken och bröst.
- **Väntar på S3:** om posemodellens höftpunkter visar sig typiska eller
  sämre, prövas pinnen i bältet som träningsverktyg (bäckenet inom 1°).
