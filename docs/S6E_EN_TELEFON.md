# S6e steg 0 — vridningen ur en telefon (simulering 2026-11-05)

**Frågan:** hur väl kan EN telefon, framifrån (FO) eller bakifrån (DTL), skatta bäckenets och
axlarnas vridning och X-factor? Räcker det för att visa dem? Svaret kommer ur samma simulering
som felbudgeten för två telefoner ([S6_FELBUDGET.md](S6_FELBUDGET.md)): samma påhittade
svingar, kameror och 2D-brus, så att talen går att ställa mot varandra.

Koden ligger i `tools/pc/vridning_2d.py` och testerna i `tools/tests/test_vridning_2d.py`.
Allt är påhittat (CLAUDE.md, Dataregeln). Tabellerna kommer ur

    python3 tools/pc/vridning_2d.py            # 120 försök per rad, frö 1, cirka 15 min

Metoden står i METOD M70–M74 och rekommendationen i BESLUT B103–B104. Bara geometri på
2D-lederna: ingen tränad modell, eftersom ingen publicerad 3D-lyftare har vikter som B92 tillåter
(research 2026-11-05, "3d_en_kamera").

## 0. Svaret

1. **Per sving räcker en telefon inte, precis som två telefoner inte gör det.** Med typiskt brus
   är SD 9–17° och P95 20–40° per sving för de mått vyn bär; banden i katalogen är 15–16° breda.
2. **Varje vy bär några mått, ungefär lika bra som två telefoner utan markörer.** Passets median
   (10 slag, typiskt brus), SD: DTL bäckenet vid toppen **6,3°** och höfterna vid träffen
   **5,8°**; FO axlarna vid toppen **7,0°** och X-factor vid toppen **10,1°**. Två telefoner
   (kedjan på paketen, S6_FELBUDGET §6.7): 11,1, 6,0, 9,7 och 13,6°. Två telefoner förlorar på
   självkalibreringen (B38); en telefon behöver ingen, men lutar sig på antaganden (punkt 6).
3. **Varje vy har mått den inte kan bära.** DTL ser axlarna vid toppen nära 90° från blicken, där
   vinkeln viks tillbaka: −12° fel i grundsvingen och −43° när axlarna går till 106°. Därmed
   faller X-factor i DTL. Stretchen får +7 till +20° fel i båda vyerna (maximum av en brusig
   kurva, och vikningen). FO:s höfter vid träffen och bäcken är sämre än DTL:s, eftersom armarna
   skymmer höfterna framifrån i adressen.
4. **Framifrån är det adressens djup som kostar.** FO ser inte linjens djup i adressen. Telefonen
   som står 5° snett mot mållinjen flyttar bäckenet och axlarna 5° (SD 5,6° utan brus), men inte
   X-factor (1,3°): båda linjerna flyttas lika. Axellinjen bär dessutom ett djup av adressens
   sidböjning i den böjda bålen (cirka 6°), som skattaren b2 räknar bort ur linjens lutning och
   bålens böjning.
5. **Den lutande axeln (b) är beroende av svingens modell** och används inte. En lodrät komponent i
   bild kommer lika gärna av sidböjning som av vridning kring den böjda axeln, men de två för
   änden åt motsatta håll i djup. Skattaren är bra när svingen vrider kring den böjda axeln och
   dålig när den vrider kring lodlinjen med sidböjning (grundsvingen), och hoppar ibland till fel
   gren (P95 över 100°).
6. **Antagandena som en telefon lutar sig på** och två telefoner inte gör: att linjen är stel (att
   posemodellens höft- och axelpunkter sitter lika långt isär sedda från alla håll), att FO står
   vinkelrätt mot mållinjen, och i DTL höft- och axelpunkternas avstånd ur kroppens andelar
   (±8 % antaget). Det första är inte prövat: de påhittade svingarna är stela per konstruktion.
7. **Domen:** visa inget per sving. Som passets trend kan en telefon visa de mått vyn bär, som
   skattning med ±spann och utan bedömning, på samma villkor som två telefoner (B14, B62): FO
   bäckenet, axlarna och X-factor vid toppen, DTL bäckenet vid toppen och höfterna vid träffen.
   Aldrig stretchen. Först efter en prövning mot två telefoner på ett riktigt pass (BESLUT B103).

## 1. Kedjan (METOD M70)

| Steg | Vad |
|---|---|
| Svingen | `slumpa_sving` (längd, tempo och vinklar slumpade), med adress och finish som rymmer M4:s fönster (MK8). Höft- och axelpunkternas avstånd slumpas kring felbudgetens 0,11 och 0,20 av längden, ±8 % (1σ). Två varianter: **lodrät** (sving.py: vridningen kring lodlinjen, sidböjningen lägger till den lodräta komponenten) och **lutande** (vridningen kring segmentets framåtböjda axel, adressens sidböjning står kvar). |
| Kamerorna | Felbudgetens: FO och DTL 3 m bort i höfthöjd, stativets läge ±5° runt spelaren, 240 bilder/s med 36 % tappade rutor, 2D-brus med vitt, vandring, fast avvikelse per led och vy, utliggare och skymning (§3). Klicket ±7 ms. |
| 2D-kedjan | `matt.mat` som den är (rensningen M53, utjämningen M3, faserna M4 och M40) ger toppen och baksvingens start, alltså adressens fönster. |
| Spåren | Rättade mot lodlinjen (telefonens gravity, ±1°) med en homografi, och jämnade med LOESS ±40 ms på 1/240 s (MK5). |
| Skattarna | Vinkelkurvorna (§2), jämnade ±30 ms (MK6). Måtten tas med `tre_d/matt.py` vid 2D-toppen och klicket. |
| Sanningen | Samma mått på de sanna 3D-lederna (MK6): toppen där händerna står högst i 3D, träffen på svingens träff, adressen ur den sanna starten. |
| Passet | 10 slag med samma kameror, fasta avvikelse och spelare (längd och punkternas avstånd); felet är medianen av slagens fel. |

## 2. Skattarna

| Namn | Vy | Vad den använder | Antar | Brister där |
|---|---|---|---|---|
| **FO a**, förkortning (M71) | FO | Linjens vågräta längd mot adressens, θ = arccos(Δx / Δx₀), tecknet ur fasen | Ingen lodrät komponent, linjen i bildens plan i adressen | Sidböjning läses som vridning; axlarna vid toppen +11–13° |
| **FO, stel linje** (M71) | FO | Linjens hela längd i bild och perspektivet: djupet = det som saknas mot adressens längd; roten ur fasen | Stel linje, i bildens plan i adressen | Adressens djup (telefonens läge, sidböjningen i adressen); nära bildens plan |
| **FO b**, lutande axel (M72) | FO | Δx och Δy, vridningen kring en axel som lutar β mot bollen; tecknet ur den lodräta komponenten | Vridningen sker kring den böjda axeln; β ur FO-figuren eller DTL (M6) | Sidböjning (motsatt djup), fel gren |
| **FO b2**, stel linje + adressens djup (M72) | FO | Som den stela linjen, och adressens djup δ₀ = tan β · ΔY₀ ur linjens lutning i adressen | Lutningen i adressen kommer av en sidböjning av den böjda bålen; β ur FO-figuren | Telefonens läge mot mållinjen; nära bildens plan |
| **DTL c**, bredd (M73) | DTL | Linjens bredd i bild och perspektivet, djupet ur linjens sanna längd w; tecknet direkt (främre änden mot bollen = stängd) | w ur kroppens andelar (M2-bålen, 0,11 och 0,20 av längden), ur ett FO-pass, eller linjens största längd efter toppen ("max") | Viks där linjen står vinkelrät mot synlinjen (≈ 90°); fel w |

Perspektivet räknas exakt för en stel linje genom en hålkamera: med ändarnas normerade
bildkoordinater är |A + B·δ|² + δ² = L², där A är ändarnas skillnad, B deras medel (linjens mitt
sedd från blicken) och δ djupskillnaden i enheter av avståndet. De två rötterna speglas kring
linjen vinkelrät mot synlinjen, där den syns längst, inte kring bildens plan (`test_vridning_2d`).

## 3. Resultaten

Alla tal är **skattat − sant** i grader: bias / SD / P95 av |fel|. Kurvan är RMS från starten till
träffen, median över svingarna. Typiskt brus är felbudgetens grund (§3). Bäcken = bäckenets
vridning, axlar = axellinjens (akromion), X = X-factor; topp = toppen (P4), träff = klicket.

### 3.1 Utan brus

Grundsvingen (lodrät), 30 svingar, inget fel utöver de slumpade svingarna:

| Skattare | Bäcken, topp | Axlar, topp | X, topp | Höfter öppna, träff | Kurva bäcken / axlar / X |
|---|---|---|---|---|---|
| FO a | +0,5 / 0,0 | +11,5 / 3,3 | +11,0 / 3,3 | +2,3 / 0,1 | 0,8 / 9,7 / 9,5 |
| FO, stel linje | −0,1 / 0,0 | +6,1 / 3,1 | +6,1 / 3,1 | −0,5 / 0,0 | 0,4 / 6,4 / 6,4 |
| FO b (β DTL) | −8,8 / 1,9 | +6,2 / 3,4 | +15,0 / 4,1 | −4,0 / 1,2 | 8,1 / 10,8 / 12,8 |
| **FO b2** | −0,1 / 0,0 | +1,7 / 1,1 | +1,8 / 1,1 | −0,5 / 0,0 | 0,5 / 2,5 / 2,5 |
| **DTL c (M2)** | +0,4 / 0,7 | −7,0 / 6,5 | −7,4 / 6,7 | −1,2 / 0,6 | 0,3 / 8,2 / 8,2 |
| DTL c (max) | +2,7 / 0,3 | −10,1 / 6,6 | −12,8 / 6,7 | +0,5 / 0,0 | 1,5 / 5,7 / 6,8 |

Samma svingar i varianten **lutande** (bias): FO b2 −0,1 · +1,5 · +1,6 · −0,4 (bäcken, axlar, X,
höfter), FO b (β DTL) −1,0 för bäckenet men −4,0 / 59,2 för axlarna (fel gren i några svingar),
DTL c −38,8 för axlarna vid toppen (axlarna går till 106°). Med **stativet ±5°, klicket ±7 ms och tappade rutor** blir FO b2
−1,7 / 5,6 för bäckenet, +0,4 / 5,3 för axlarna och +2,0 / **1,3** för X-factor; DTL c (M2)
+0,5 / 1,0 för bäckenet och −1,1 / 1,2 för höfterna. Telefonens läge flyttar alltså FO:s linjer
men inte X-factor, och inte DTL.

### 3.2 Per sving

| Brus, skattare | Bäcken, topp | Axlar, topp | X, topp | Höfter öppna, träff | Stretch | Kurva bäcken / axlar / X |
|---|---|---|---|---|---|---|
| Bra, FO a | −2,3 / 13,3 / 31 | +11,5 / 7,0 / 21 | +13,8 / 13,0 / 38 | +1,5 / 12,8 / 22 | +8,6 / 14,2 / 27 | 12,1 / 11,5 / 16,3 |
| Bra, FO b2 | −3,2 / 13,9 / 30 | +1,8 / 7,5 / 16 | +5,0 / 13,3 / 31 | −0,7 / 12,7 / 22 | +12,2 / 41,2 / 33 | 13,3 / 6,6 / 13,4 |
| Bra, DTL c (M2) | +1,3 / 8,7 / 17 | −9,6 / 11,6 / 33 | −10,9 / 14,7 / 34 | −1,0 / 7,3 / 14 | +17,5 / 10,9 / 34 | 6,2 / 9,9 / 11,6 |
| Bra, DTL c (max) | +0,2 / 8,3 / 16 | −13,2 / 11,7 / 35 | −13,3 / 14,7 / 39 | −2,1 / 6,6 / 13 | +7,0 / 12,9 / 34 | 6,1 / 7,6 / 9,9 |
| Typiskt, FO a | −2,9 / 15,8 / 35 | +12,9 / 8,0 / 27 | +15,8 / 16,1 / 46 | −1,5 / 17,0 / 35 | +17,5 / 23,9 / 68 | 17,4 / 12,4 / 20,1 |
| Typiskt, FO b (β DTL) | −20,9 / 30,3 / 85 | +3,6 / 33,8 / 33 | +24,5 / 47,3 / 99 | −10,9 / 21,5 / 56 | +23,5 / 44,2 / 77 | 25,5 / 14,9 / 32,3 |
| Typiskt, FO b2 | −4,8 / 17,4 / 40 | +3,8 / 9,2 / 20 | +8,6 / 16,8 / 39 | −6,0 / 21,7 / 42 | +18,2 / 24,2 / 71 | 18,8 / 8,0 / 19,4 |
| Typiskt, DTL c (M2) | +2,3 / 14,0 / 29 | −11,8 / 13,9 / 34 | −14,1 / 18,4 / 47 | −0,8 / 12,3 / 23 | +19,8 / 14,0 / 44 | 11,1 / 11,7 / 17,1 |
| Typiskt, DTL c (max) | −2,3 / 12,0 / 22 | −17,7 / 13,1 / 42 | −15,4 / 17,9 / 47 | −4,1 / 11,3 / 23 | +13,4 / 15,9 / 41 | 9,8 / 9,8 / 14,4 |
| Dåligt, FO b2 | −7,2 / 33,7 / 56 | +0,8 / 26,1 / 48 | +7,9 / 41,8 / 74 | −10,8 / 38,7 / 87 | +27,1 / 36,1 / 102 | 27,2 / 12,7 / 31,1 |
| Dåligt, DTL c (M2) | +0,4 / 23,9 / 46 | −11,4 / 18,3 / 48 | −11,8 / 31,5 / 60 | +10,8 / 27,7 / 68 | +26,8 / 25,6 / 66 | 23,6 / 16,5 / 29,8 |

Två telefoner per sving (S6_FELBUDGET §6.1, samma brus): typiskt +1,1 / 13,0 (bäcken),
−0,5 / 10,5 (axlar), −1,6 / 16,1 (X), +0,5 / 13,4 (höfter); bra, RMSE 8,8 / 5,7 / 11,0 / 6,7.
Med punkternas avstånd kända (DTL:s w exakt) blir DTL c +2,3 / 12,9 för bäckenet, mot 14,0.

### 3.3 Passets median (30 pass om 10 slag)

| Brus, skattare | Bäcken, topp | Axlar, topp | X, topp | Höfter öppna, träff | Stretch |
|---|---|---|---|---|---|
| Bra, FO b2 | −0,0 / 7,8 / 14 | +1,9 / 6,8 / 11 | +2,2 / 7,0 / 13 | −1,0 / 7,6 / 17 | +6,7 / 5,5 / 15 |
| Bra, DTL c (M2) | +2,1 / 6,8 / 13 | −9,3 / 11,7 / 33 | −11,6 / 14,4 / 38 | −1,5 / 5,1 / 9 | +18,6 / 7,3 / 29 |
| Bra, DTL c (max) | −0,8 / 2,7 / 5 | −13,6 / 8,1 / 29 | −12,7 / 8,5 / 28 | −3,3 / 3,7 / 9 | +7,0 / 6,5 / 17 |
| Typiskt, FO a | −0,5 / 10,8 / 20 | +11,2 / 5,6 / 20 | +11,8 / 10,4 / 29 | +0,3 / 9,3 / 16 | +11,3 / 8,6 / 24 |
| Typiskt, FO b2 | −1,9 / 11,7 / 22 | +2,4 / 7,0 / 14 | +4,2 / 10,1 / 21 | −0,9 / 9,5 / 18 | +11,9 / 7,7 / 22 |
| Typiskt, DTL c (M2) | +0,7 / 6,3 / 11 | −11,9 / 11,8 / 31 | −13,1 / 12,6 / 34 | +0,8 / 5,8 / 12 | +18,2 / 7,8 / 31 |
| Typiskt, DTL c (max) | −3,5 / 4,4 / 11 | −16,7 / 9,5 / 32 | −13,7 / 11,2 / 29 | −2,9 / 5,5 / 12 | +11,0 / 7,7 / 23 |
| Typiskt, lutande, FO b2 | −1,2 / 8,2 / 12 | +2,1 / 6,9 / 14 | +3,4 / 8,1 / 16 | −1,7 / 11,0 / 22 | +5,9 / 4,4 / 13 |
| Typiskt, lutande, DTL c (M2) | +1,3 / 7,1 / 12 | −42,8 / 18,2 / 69 | −44,5 / 16,3 / 71 | +0,9 / 6,0 / 13 | +28,6 / 8,1 / 41 |

Två telefoner, passets median (kedjan på paketen, §6.7): bra −0,2 / 5,9 · +1,4 / 5,7 · +2,1 / 7,8 ·
+1,0 / 3,5 (bäcken, axlar, X, höfter) och stretch +1,9 / 3,5; typiskt −0,1 / 11,1 · +1,2 / 9,7 ·
+0,9 / 13,6 · +0,9 / 6,0 och stretch +4,7 / 5,7.

### 3.4 Var skattarna brister: kurvans fel efter den sanna vinkeln (RMSE)

| Skattare, linje | 0–15° | 15–30° | 30–60° | 60–80° | 80–100° | över 100° |
|---|---|---|---|---|---|---|
| Inget brus, FO a, axlar | 7,5 | 8,6 | 11,2 | 12,5 | 11,3 | – |
| Inget brus, FO b2, axlar | 2,8 | 3,9 | 2,8 | 2,6 | 1,9 | – |
| Inget brus, DTL c (M2), axlar | 0,4 | 1,7 | 10,5 | 12,3 | 8,4 | – |
| Typiskt, FO b2, bäcken | 19,3 | 20,4 | 21,2 | – | – | – |
| Typiskt, FO b2, axlar | 9,0 | 8,8 | 9,5 | 10,4 | 10,8 | 23,1 |
| Typiskt, DTL c (M2), bäcken | 13,1 | 11,8 | 13,1 | – | – | – |
| Typiskt, DTL c (M2), axlar | 9,1 | 33,3 | 14,9 | 13,8 | 18,4 | 55,3 |

Utan brus är bäckenet nästan exakt i alla skattare utom FO b (under 1°). Axlarna visar var
geometrin brister: FO a räknar sidböjningen som vridning, DTL c tappar efter 30°, där axlarnas mitt
vid toppen har flyttat cirka 0,3 m mot DTL-kameran (linjen ser 11 % längre ut) och vinkeln närmar
sig vikningen. Med brus är FO:s bäcken lika dåligt i alla vinklar: felet sitter i adressens
referens, där armarna skymmer höfterna.

### 3.5 Placeringen (typiskt brus, per sving)

| Placering | FO b2 bäcken, topp | FO b2 axlar, topp | FO b2 X, topp | DTL c bäcken, topp | DTL c höfter, träff |
|---|---|---|---|---|---|
| 3 m, 1,0 m (grund) | −4,8 / 17,4 | +3,8 / 9,2 | +8,6 / 16,8 | +2,3 / 14,0 | −0,8 / 12,3 |
| 0,7 m höjd | −3,7 / 14,8 | +5,1 / 8,9 | +8,8 / 14,4 | +0,9 / 13,8 | −1,6 / 12,2 |
| 1,5 m höjd | −4,2 / 19,3 | +1,3 / 8,2 | +5,5 / 18,8 | +5,2 / 19,4 | +0,8 / 13,2 |
| 1,5 m höjd, utan lodlinjen | −8,1 / 20,5 | +0,1 / 10,0 | +8,2 / 23,2 | +7,6 / 18,0 | +3,0 / 14,9 |
| 2,5 m bort | −5,4 / 18,0 | +3,6 / 9,3 | +9,0 / 17,1 | +1,7 / 14,9 | −1,1 / 12,3 |
| 4,0 m bort | −4,3 / 17,1 | +3,9 / 9,2 | +8,2 / 16,4 | +2,5 / 13,8 | −0,3 / 12,4 |

Höfthöjd eller lägre är bäst; 1,5 m gör bäckenet sämre i båda vyerna. Rättningen mot lodlinjen tar
bort 2–4° bias vid 1,5 m. Avståndet spelar ingen roll när posemodellens fel följer kroppens
storlek i bild (som i felbudgeten §6.4).

## 4. Domen per mått och vy

Kraven: VISION (ett mått som visas ska kunna säga bra eller dåligt), katalogens `tre_d`-band
(bäckenet 30–46°, höfterna vid träff 30–45°, axlar och X-factor utan band) och MK7:s golv för två
telefoner (√2 × passmedianens SD). SD nedan är passets median med typiskt brus; per sving är alla
över 7°.

| Mått | FO | DTL | Två telefoner | Dom (en telefon) |
|---|---|---|---|---|
| Bäckenets vridning vid toppen | b2: −1,9 / 11,7 | c: +0,7 / 6,3 | −0,1 / 11,1 | Skattning med ±spann, båda vyerna (bäst DTL) |
| Axlarnas vridning vid toppen | b2: +2,4 / 7,0 | viks: −11,9 / 11,8 | +1,2 / 9,7 | Skattning med ±spann i FO; aldrig DTL |
| X-factor vid toppen | b2: +4,2 / 10,1 | viks: −13,1 / 12,6 | +0,9 / 13,6 | Skattning med ±spann i FO; aldrig DTL |
| X-factor stretch | +11,9 / 7,7 | +18,2 / 7,8 | +4,7 / 5,7 | Visas inte |
| Höfterna öppna vid träff | b2: −0,9 / 9,5 (per sving 21,7) | c: +0,8 / 5,8 | +0,9 / 6,0 | Skattning med ±spann i DTL; inte FO |

Ingen av dem kan säga bra eller dåligt: bäckenets band är 16° brett mot ±6–12° i passets median.
Det är samma läge som för två telefoner utan markörer, där trenden visas utan färg (B14, B62).
Spannet som skulle visas står i METOD M74.

## 5. Vad som är antagande

- **2D-bruset** (S6_FELBUDGET §3), som för två telefoner. S3 mäter det. Skymningsmodellen gör FO:s
  höfter sämre än DTL:s; den är grov.
- **Den stela linjen.** Posemodellens höft- och axelpunkter antas sitta lika långt isär sedda från
  alla håll. De påhittade svingarna är stela per konstruktion (utom skulderbladen), så
  simuleringen gynnar en telefon. En punkt som flyttar sig på kroppen med blickvinkeln ger fel
  som inte finns här. Det är det viktigaste att pröva på riktiga pass.
- **Svingens kinematik.** Två varianter (lodrät och lutande) som ger samma tal för FO b2 och DTL c
  men helt olika för FO b. Riktiga svingar ligger någonstans däremellan.
- **Adressens djup i FO** ur sidböjningen av en böjd bål (b2). Riktiga axlar kan sänka den bakre
  sidan på andra sätt (greppet), och då stämmer korrektionen sämre.
- **Höft- och axelpunkternas avstånd** (0,11 och 0,20 av längden ±8 %) för DTL. Två telefoner kan
  mäta Johannes egna en gång.
- **Telefonens läge mot mållinjen** ±5° (felbudgeten). En FO-telefon som står mer snett flyttar
  bäckenet och axlarna lika mycket.
- **Bäckenets böjning** som 22/38 av bålens i FO b och b2 (felbudgetens sving). Liten betydelse för
  b2, eftersom höftlinjen knappt lutar i adressen.

## 6. Nästa steg (S6e steg 1)

1. **Pröva mot två telefoner på ett riktigt pass:** kör skattarna på varje telefons paket för sig
   och jämför med trianguleringen (`tva_kameror.py`) per sving och i passets median. Det mäter den
   stela linjen och adressens djup på riktiga leder. Talen skrivs här, inte i repot (dataregeln).
2. **Mät punkternas avstånd** (höfter och axlar) i det parade passet och använd dem i DTL.
3. **FO-telefonens läge:** en kontroll i uppställningen att telefonen står vinkelrätt mot
   mållinjen (en pinne på marken längs mållinjen ska ligga vågrätt i bild), om FO ska visa
   bäckenet och axlarna. X-factor klarar sig utan.
4. **Pinnen i bältet** (S6_FELBUDGET §6.8) borde hjälpa en telefon också: dess längd är känd, så
   DTL:s w blir exakt och linjen tre gånger längre. Inte simulerat.
5. **Apple Visions 3D** (`VNDetectHumanBodyPose3DRequest`) kan bara prövas på en iPhone eller Mac;
   den jämförs mot samma facit när ett riktigt parat pass finns.
