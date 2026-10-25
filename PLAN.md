# SwingLab — plan (utkast 2026-10-22)

`BAND` S0 · S1 ✓ · S1b ✓ · S1c · S1d · S1e · S2 · S2j nu · S2k · S3 · S4 · S4e nu · S4f nu · S4g nu · S5 · S5b nu · S6 · S6c nu · S6d nu · S6e · S6f nu · S6g nu · S6h · S7 · S7a · S7c nu · S7b nu · S8

Mål: svinganalys på Sportsbox-nivå för Johannes vinterträning 2026/27, ur
slowmotion från iPhone, down the line och face on. Telefonen filmar, mäter och
visar. PC:n tar emot samma session och fortsätter där, med tyngre mätning och
Claude som tolkar.

Grunden finns redan i Golf SG (`tools/handled_video.py`,
`tools/handled_svingmatt.py`, HANDLED_PLAN §3 HL6): synk på klicket, leder
med MediaPipe och svingmåtten. Analysen 2026-10-18 av 41 slag med järn 7 är
beviset på att kedjan räcker för tre saker att jobba på.

**Underlaget** är tre research-rapporter (2026-10-22) i `docs/research/`:
måtten och gränserna, tekniken, och tolkningen och apparna. Källsidorna gick
inte att läsa från molnet, så varje siffra är "ej läst i original" tills den
kontrollerats (BESLUT B10). Jämförelsen med Sportsbox AI:s mått står i `docs/research/4_sportsbox_matt.md`.

## S0 — Kontrollera oktobers mått

Researchen ifrågasätter två av oktobers tal. Axellutningen vid träffen
passar ingen källa: GolfTEC anger 39° för tour och Sportsbox 24–38° i
bröstets sidböjning. Det är troligen definitionen (axellinjen i bilden mot
vågrätt) eller axelpunkterna, som är opålitliga vid träffen. Tecknet på
thrusten ska också prövas.

Gör: rita axellinjen och bäckenets läge på bildrutan vid träffen för 5 slag
framifrån och 5 bakifrån, jämför med ögat, och räkna om med Sportsbox
definition av sidböjningen (bröstets lutning, inte axelpunkterna).

**Klart när:** båda talen är bekräftade eller rättade i HANDLED_PLAN §4, och
J7-träningen är rättad om del 2 byggde på ett fel tal.

## S1 — Logiken (SwingLabKit)

Ett Swift-paket med bara Foundation, testat på Linux i Actions:

- **Faserna** ur ledernas tidsserie: adress, baksvingens start, topp (händerna
  högst), träff (klicket i ljudet, ±7 ms) och finish.
- **Måtten** per vy, portade från `handled_svingmatt.py`: sway, thrust, lyft,
  bröstets böjning, sidböjning, knävinkel, huvudet och händerna före bollen.
  Dessutom de nya enkla: armbågarna och vänsterarmen vid toppen, chicken wing,
  reverse spine, handens bana och stansen. Nytt ur researchen: **bäckenets
  resa framåt från toppen**, eftersom sway bakåt och för lite förskjutning
  framåt är samma tema, bäckenets väg.
- **Katalogen** (`katalog.json`, BESLUT B6): varje fel med vy, mått,
  definition, grönt spann och övning. Varje gräns bär sin källa och status.
  Där ingen källa har samma definition som vi är gränsen den egna baslinjen
  (X-factor, klubbmåtten, sway gap). Första gränserna: bäckenets sway vid
  toppen ≥ 0 grönt, −5…0 gult, under −5 cm rött; tempo 2,5–3,1. Samma fil
  läses av PC:n.
- **Sessionen**: median, spridning och trend per mått, och skillnaden mot förra
  passet.

**Klart när:** `swift test` är grönt, och Swift ger samma tal som Python på
samma påhittade leder (fixturer genererade av PC-verktyget, inga riktiga
svingar).

## S1b — Små tillägg mot Sportsbox i 2D

Ur jämförelsen med Sportsbox AI ([docs/research/4_sportsbox_matt.md](docs/research/4_sportsbox_matt.md)):
mått som går att räkna ur dagens leder i en vy, i Python och Swift med samma tal
(B12), med METOD-rader och katalogens positioner (B32): bäckenets böjning (DTL),
bröstets lyft, handens lyft, främre knäets böjning (DTL), knänas sway (FO),
follow-through-tid, handfart (max och tidpunkten före träffen) och vänsterarmens
vinkelfart. Farterna kräver skarp bild (B11) och märks osäkra tills de provats
på telefonen. Sportsbox definitioner är ej lästa i original (B10).

**Klart när:** måtten finns i båda språken med samma tal och i katalogen med
positioner, och syns i granskningen (via katalogens positioner); i passet bara de
mått som har ett fel. Farterna märks "untested" där de visas.

**Byggt (grenen `s1b`).** METOD M30–M37: `backen_bojning_*` (DTL, visas som
"Hip hinge (est.)": medlet av bålens och lårets lutning, inte Sportsbox Pelvis
Bend och visar inte early extension), `brost_lyft_*` och `hand_lyft_*` (båda
vyerna), `framre_kna_*` (DTL, saknas när knät skyms), `framre_kna_sway_*` och
`bakre_kna_sway_*` (FO), `genomsving_s` (finishen = handens fart under 10 % av
genomsvingens topp), `handfart_max` (m/s) och `handfart_max_fore_traff_ms` (FO)
och `framre_arm_vinkelfart_max` (FO). Farterna räknas med en viktad linjär
anpassning på ett rutnät om 1 ms (`tools/pc/farter.py`, `Swing/Farter.swift`);
toppen saknas vid en lucka eller i rutnätets ände. Katalogen har 23 nya `matt`
med positioner, två med `fel`, och farterna med `status: "oprovad"` (märkningen
"untested", BESLUT B11). Kvar till ✓: synas i granskningen på telefonen.

## S1c — Fler mått bakifrån (Johannes 2026-10-23)

Beställningen: fler mått för en telefon bakifrån (DTL), små tillägg i 2D ur dagens
leder, som S1b: huvudets rörelse mot och från bollen och upp och ned vid P4 och P7
(adressen = 0), händernas djup vid toppen mot adressen, och främre armen mot
axellinjen vid toppen (+ = över axelplanet), eller varför lederna inte bär den. Och:
varför Today saknade Tempo för ett importerat DTL-pass med två slag.

**Klart när:** måtten finns i Python och Swift med samma tal (B12), med METOD-rader,
i katalogens `matt` med positioner och `vy: dtl`, utan `fel`, med engelska namn
(B30, B33), och syns i granskningen vid P4 på telefonen.

**Byggt (grenen `s1c`).** Huvudet bakifrån fanns redan med andra id:n och är orört:
`huvud_mot_bollen_*` (M9) och `huvud_lyft_*` (M8, båda vyerna), utan rader i
katalogens `matt`. Nytt: `hand_djup_topp` (M38, cm, + mot bollen, "Hand depth") och
`framre_arm_plan_topp` (M39, grader, + över axelplanet, "Lead arm plane"), som
saknas när axellinjen vid toppen är kortare än 15 cm i bild (axlarna skymmer
varandra). Den påhittade DTL-figuren kan vrida axlarna vid toppen (`axel_dx`,
`axel_dz`); fixturerna `dtl` och `dtl_vanster` gör det. Tempot: klicket finns i
varje slag, så det är baksvingens start som saknas; bakifrån syns takeawayn knappt
(METOD M5), oprövat på riktiga DTL-pass. Kvar till ✓: synas i granskningen på telefonen.

## S1d — Tempot bakifrån (Johannes 2026-10-23)

Bakifrån (DTL) försvann tempot: takeawayn går mot kameran och syns knappt, och står
kameran över händerna ser de ut att sjunka först, så starten hittades sent eller inte
alls (utredningen i grenen `s1c`). Gör: en start som håller bakifrån, i Python och
Swift med samma tal (B12), prövad på påhittade svingar mot andra signaler; FO ger samma
tal som förut; saknas en säker start märks tempot osäkert hellre än att visa ett fel
tal.

**Klart när:** testerna har påhittade DTL-svingar med dold takeaway och kameran över
händerna där tempot ligger inom en uttalad gräns från det sanna, och ett test låser
FO:s tal; och ett riktigt DTL-pass på telefonen ger tempot (eller märker det osäkert).

**Byggt (grenen `s1d`).** METOD M40, BESLUT B42: bakifrån tas starten ur posen (axlarna,
armbågarna och handlederna) mot adressens stillaste fönster, bakåt från toppen
(`faser.start_ur_posen`, `Faser.startUrPosen`). Uppmätt på påhittade 3D-svingar sedda
bakifrån: förut +176 till +265 ms sen eller saknad, nu högst 0,14 fel på tempot med
0,8 px brus. Skakar adressen eller räcker inte posen är starten osäker
(`faser.start_osaker`) och tempot saknas. Fixturerna `dtl_dold`, `dtl_osaker` och
`dtl_utan_pose`; `test_faser.StartenBakifran` (gränsen 0,15 och FO:s tal låsta). Måtten bär en
version (2): telefonen mäter om äldre slag och PC:ns historik säger vilka pass som ska köras om. I
vyerna: tempot "—" i passet och på Today när slagen saknar säker start, och skälet i
infobladets källrad. Kvar till ✓: ett riktigt DTL-pass på telefonen.

## S1e — Källorna i original och mått ur research 5 (2026-10-23)

Research 5 läste källorna i original ([docs/research/5_matt_i_original.md](docs/research/5_matt_i_original.md)).
Beställningen: källstatusen i METOD och katalogen som research 5 läste den, rättelserna
i §2 (Sportsbox vinklar är absoluta, sway gap är löst), gränserna i §4 där källan mäter
samma sak som vi i 2D (samma definition, nollpunkt och tecken, och samma klubba), och
de billiga måtten 1–7 i §5 ur dagens leder.

**Klart när:** METOD och katalogen säger det research 5 läste, varje ändrad gräns har en
rad i ett BESLUT, de nya måtten finns i Python och Swift med samma tal (B12), med
METOD-rader och katalogens positioner, spridningen syns i passet och Progress, och
Johannes har sett de nya måtten och spridningen på telefonen.

**Byggt (grenen `s1e`).** Gränserna (BESLUT B45): `sway_topp` grönt från −2,5 cm,
`early_extension` grönt till +4,3 och rött över +8,4 cm (Sportsbox, samma definition
som M7), `sway_gap` med riktning men egen baslinje (tour-talet beror på klubban),
`axellutning` avstängd med referensen 22–25° med järn, `tappad_hallning` och `tempo`
oförändrade. Måtten: `backen_recentrering` (M41) och `backen_skifte_ms` (M42) framifrån,
`backen_lyft_min` och `backen_lyft_in_traff` (M43) i båda vyerna, och i katalogens `matt`
de som fanns: `sidbojning_finish`, `nedsving_s` och `hoftlinje_lutning_topp`/`_traff`.
Spridningen mellan slagen (M44, BESLUT B46): katalogens lista `spridning`, ett kort i
passet och ett mått i Progress med felens kort och diagram, bilden
`utveckling-spridning` i simulatorprovet. Kvar till ✓: telefonen.

## S2 — Appskalet och första bygget

**Spela in i appen** med låst slutartid, 1/2000 s eller kortare
(`setExposureModeCustom`). Oskärpan är fart × exponeringstid, och Kamera-appens
slowmotion låser den inte. Det kräver starkt, flimmerfritt ljus. Import ur
Bilder finns kvar för gamla klipp. Hitta klicken i
ljudet, kör Apple Vision (kroppen i 2D) på rutorna −2,5…+1,5 s kring
varje slag, märk vyn (DTL eller FO) och klubban, spara. **Exportera
sessionen** som ett paket (BESLUT B3): lederna, måtten och klicktiderna som
JSON, plus de korta klippen kring slagen.

**Klart när:** ett pass inspelat i appen och oktobers klipp (17/10) har körts
på telefonen, och paketet ligger på PC:n.

## S2i — Trimma och utsnitt (Johannes 2026-10-22, efter första telefonprovet)

Efter en import eller inspelning: videon med två handtag för start och slut
(originalfilen ändras aldrig, bara passets tidsfönster) och en ruta för
utsnittet som dras och nyps runt spelaren. Utsnittet gäller alla slag i
klippet: Vision ser bara rutan (appen skär ut den, BESLUT B34), så att spelaren blir
större i bilden, och granskningen visar videon med samma utsnitt. Därefter
Analyze. B13: bara handtagen, rutan och tiden, ingen förklarande text.

**Klart när:** på telefonen: ett klipp på 9 s trimmas till svingen, utsnittet
sätts, och analysen ger leder bara inom rutan; simulatorprovet bevisar
fönstret och utsnittet på en påhittad film.

**Byggt (grenen `s2i`).** SwingLabKit `Capture/Edit.swift` (`TimeWindow`,
`CropRect`, `SeriesEdit`, `PassState.setEdit`, Visions region och punkter,
bufferten mot den upprätta bilden, `TrimTimeline`) med `RedigeringTests`; App
`ClipEditor.swift` (redigeraren), Continue → redigeraren för varje ny serie →
passet, och raden per serie i passet öppnar den igen. Paketets `fonster` och
`utsnitt` i `docs/FORMAT.md` och `tools/pc/paket.py`. METOD MS13, BESLUT B34.
Simulatorprovet: `Prov/SwingLabProvRedigering.swift` (bilderna `redigerare-hel`,
`redigerare`, `redigering-slag`, `redigering-traff`).

## S2j — Tydligare inspelning: bara det som ska tas ställning till (Johannes 2026-10-25)

**Beställningen:** informationen under inspelningen ska bli tydligare. Det som syns är bara det
som är relevant att ta ställning till under inspelningen; resten ligger bakom ett kugghjul.
Johannes godkände en skiss med fyra skärmar (kopplad, spelar in, lutningen, kugghjulet).

1. **Kopplad och redo:** Close till vänster, statusen "● Connected" (grön på svart) i mitten,
   kugghjulet till höger och den röda inspelningsknappen nere i mitten (en röd cirkel i en vit
   ring, som iPhones kameraapp). Ensam telefon: ingen statuspill; Lead som söker: "Searching" i
   grått; tappad: "Other phone lost" med gul ikon; följaren visar "Connected" när den är kopplad.
2. **Spelar in:** den röda pillen "● REC 0:42" och stoppknappen som en röd kvadrat i ringen.
   Svingarna hittills står i kugghjulet som "~3" tills räknaren är kalibrerad (skissen hade dem i
   pillen; granskningen 2026-10-25, MS32).
3. **Varningar** bara när de kräver handling, en i taget, i en svart ruta med gul ikon: den andra
   telefonen slutade spela in, tappad under serien, "Both phones are DTL" med "Switch to FO" (S6g),
   lokalt nätverk av, värmen från critical, under 4 GB ledigt, mikrofonen av, en extern mikrofon
   och fel bildfrekvens. Information flyttar till kugghjulet: värmen under critical, frekvensen
   när den är rätt och parningens restfel.
4. **Lutningen** mitt på skärmen bara när |lutningen| > 2° (av under 1,5°): ett stort tal, "Level
   the phone" och horisontlinjen; över 45° med två telefoner också "Tilt too large for 3D"
   (S6c-2). För alla roller.
5. **Kugghjulet:** bladet "Recording" (medium) med This phone, Other phone, Frame rate, Tilt,
   Swings so far, Swings heard on both, Storage, Thermal, Microphone och Guide lines (sparat per
   användare), och
   Light test längst ned. Rader som inte gäller visas inte.

Formen: grönt och rött bara för inspelningens status (BESLUT B85, undantag i design/README.md),
heldragna svarta rutor med vit text, rundade hörn som i skissen, engelska, inga värdeord (B13),
VoiceOver (statusen som text som ändras ofta, varningen läses upp när den kommer) och Dynamisk
text.

**Byggt (grenen `s2j`, BESLUT B85, METOD MS32):** SwingLabKit `Capture/Inspelningslage.swift`
(`InspelningsStatus`, `InspelningsVarning` med ordningen, `LutningsVisare` med hysteresen,
`AndraStoppadeVakt`, `LevandeSvingar` ur ljudkanalens nivå, `Lagringstid`) med
`InspelningslageTests`, texterna i `Texter`, och `AppSettings.guideLines`; appen
`App/Vyer/InspelningsLager.swift` (lagret, pillen, varningsrutan, knappen, kugghjulets blad och
reglaget), `LutningVy` i ny form och `RecordView` som ger värdena. `LinkLabels`,
`LevandeLutning` och `SammaVyVarning` är borta. Simulatorprovet
`Prov/SwingLabProvInspelningsSkarm.swift` ritar lägena för Lead och ensam och kugghjulets blad
(bilderna `insp-*`), också med största textstorlekarna, och prövar färgerna mot B85.

**Oprövat på telefonerna:** svingräknaren (`peakHoldLevel`, MS32), när följaren hinner starta,
lutningen live och VoiceOver.

**Klart när:** Johannes har spelat in ett pass med två telefoner och ett ensam och (1) sett
"Connected", "Searching" och "Other phone lost" och REC-pillen med tiden, och jämfört "Swings so
far" i kugghjulet med svingarna han slog, (2) sett
varningen när följaren stoppades för hand och när båda stod på samma vy, (3) sett lutningen komma
över 2° och försvinna under 1,5° utan att blinka, (4) öppnat kugghjulet och läst raderna, stängt
av hjälplinjerna och fått dem avstängda nästa gång, och kört Light test därifrån.

## S2k — Den andra telefonens bild live (Johannes ja 2026-10-25, byggs efter S2j)

Follow skickar en liten förhandsbild till Lead över PhoneLink (direkt wifi, inte internet), cirka
360p i 10–15 bilder/s, kodad med H.264 eller JPEG.

- **På Lead:** en liten ruta i hörnet när telefonerna är kopplade. Ett tryck gör bilden stor med
  hjälplinjerna, så att Johannes kan rikta in den andra telefonen utan att gå dit.
- **Under inspelning:** strömmen pausas eller sänks till ett par bilder i sekunden, så att den inte
  stjäl kraft från inspelningen i 240 bilder/s eller värmer telefonen.
- **Dataregeln:** bilden går bara mellan de två parade telefonerna (B61) och sparas inte.

**Klart när:** Lead visar Follows bild med under 0,3 s fördröjning på riktiga telefoner,
inspelningens bildfrekvens påverkas inte, och det termiska trycket stiger inte märkbart under en
uppställning på 5 minuter.

## S3 — Facit: Vision mot MediaPipe

PC:n kör MediaPipe heavy på samma klipp och jämför per led, fas och vy. Måtten
från S1 räknas på båda. Väntat ur researchen: MediaPipe är tydligt bättre i
2D (Googles mätning), och ingen modell är validerad för golf med en kamera.

**Klart när:** tabellen över skillnaden per mått finns, och beslutet är taget:
räcker Vision i telefonen, eller ska MediaPipe in i appen (BESLUT B5).

**Förberett:** verktyget `python tools/pc/s3_facit.py <paket.zip> [fler]` (BESLUT B43,
METOD MF1–MF4): MediaPipe heavy på klippens rutor i telefonens utsnitt, klippets
tidsförskjutning skattad per slag, lederna per led, fas och vy, S1:s mått på båda källorna
parade per slag, det som avgör B5 överst (simulerade trösklar, bootstrap av slagen) och
kontaktark, till `~/swinglab-s3/<pass>/`. Provat med en påhittad modell och en riktig kort
film; väntar på riktiga paket med klipp.

## S4 — Vyn

Passet, Att jobba på, Utveckling och Idag i formspråket B13 med accenten B31,
på engelska (B30). Varje mått som ett tal mot sitt spann, inte en poäng, i den
vy där det hör hemma. Att jobba på visar de 1–3 saker som PC:n och Claude har
valt (S5, kontraktet i `docs/FORMAT.md`).

**Granskningen med video och P-positioner (BESLUT B32):** videon spelas bild
för bild med de uppmätta linjerna ovanpå. Positionsraden P1 Adress, P3, P4
Topp, P5, P7 Träff, P9 och P10 Finish hoppar till positionen, och under
videon visas bara den positionens mått (det du övar på i isblått). Varje mått i
`katalog.json` bär sina positioner, så kopplingen är data. P3, P5 och P9 hittas
ur armarnas vinkel i lederna; P2, P6 och P8 kräver klubban (S7). Videon och
positionsraden byggs med S2:s klipp; måtten per position kräver lederna från
S2e.

**Klart när:** Johannes har läst ett pass på telefonen på rangen, och i
granskningen hoppat mellan positionerna med rätt mått under videon.

**S4b — granskningen med riktig video och passets mått (Johannes 2026-10-22, efter
telefonprovet med S2e+S2i: "Tryckte analys. Oklart vad som hände nu.").** Byggt
(grenen `s4b`): analysens leder görs om till S1:s sving och mäts på telefonen
(`Capture/Matning.swift`, METOD MS14), med Johannes längd eller 1,80 m märkt
"assumed"; passet visar efter Analyze S4:s `PassetVy` med riktig data överst
(katalogen, egen baslinje och "vs" ur tidigare pass med samma klubba och vy) och
slagen under; ett tryck på ett slag öppnar granskningen (`App/Vyer/GranskningVideo.swift`,
`Capture/Granskning.swift`, METOD MS15): videon med utsnittet, spela i 1/8 fart och
stega ruta för ruta, de 13 lederna och linjerna (osäker led ihålig och streckad), en
växel som döljer dem, P1–P10 och slagets mått vid positionen (`Swing/Visning/Positionsmatt.swift`),
och menyn "Detection wrong" (BESLUT B35). Simulatorprovet: `Prov/SwingLabProvGranskning.swift`
(bilderna `granskning-markor`, `passet-matt`, `granskning-video`, `granskning-video-p7`,
`granskning-utan-leder`, `granskning-detection-wrong`, `passet-detection-wrong`).

**S4c — flikarna med riktig data (BESLUT B36, METOD MS16).** Byggt (grenen `s4c`): appen
öppnar i Today, Progress och Me (`App/Vyer/Flikar.swift`). Today: senaste passet med
måtten i korthet, Focus med de 1–3 sakerna ur den senaste `att_jobba_pa.json`
(`Store.focus`, S2f), Start session och Import from Photos. Progress: ett
mått i taget över passen med samma klubba och längd (median, spridning, serie 1, gränsen
eller baslinjen, blocken). Me (`JagVy`): längden, spelhanden och klubborna som standard
för nya pass (passet behåller sin längd, `PassState.heightM`), och Sessions (startvyn med
passen och Import focus). Accenten på det som övas i Today, Passet, Progress och
granskningens rader. Simulatorprovet: `Prov/SwingLabProvFlikar.swift` (bilderna
`flik-idag`, `flik-idag-utan-fokus`, `flik-utveckling`, `flik-utveckling-resa`,
`flik-jobba`, `flik-passet`, `flik-jag`).

**S4d — namnen och infobladet (Johannes 2026-10-23, BESLUT B40, B41).** Beställningen:
måtten heter efter kroppsdel och vad, med entydigt tecken; i granskningen utan position,
på felens rader i Today och passet med positionen när den behövs ("Hip sway at top").
Och ett infoblad: varje fel och mått i `katalog.json` får `vad`, `varfor` och `tecken`
på engelska, och ett tryck på en måttrad (passet, granskningen) eller ⓘ (Today,
Progress) öppnar ett blad i halv höjd med namnet, de tre raderna och källan i grått.
Bara visningsnamnen ändras: id:n, `att_jobba_pa.json` och PC:ns tal är orörda.
**Klart när:** proven kräver fälten överallt (Python och Swift, test_engelska), varje
rad har sitt blad, simulatorprovet ritar bladet, och Johannes har öppnat bladet på
telefonen. **Byggt (grenen `s1c`):** `Texter.mattnamn` och `Texter.felnamn`,
`Swing/Visning/Infoblad.swift` (källan ur `status`, `kontrollerad`, gränsen och
webbplatserna i `kalla`), fälten i `Katalog` och `tools/pc/katalog.py`,
`App/Vyer/InfobladVy.swift` (bladet, trycket och ⓘ), och bilden `infoblad` i
`Prov/SwingLabProvFlikar.swift`. Två tecken i Johannes tabell stämde inte med koden
(hip sway och spine tilt); koden behölls och bladet och kortets rubrik säger kodens
tecken (B40). Efter granskningen: huvudets mått i granskningen (M8, M9), `varfor` utan
orsakssamband som METOD inte stöder, källan "Assumption from manufacturer" för sway_topp,
genomsvingens tid märkt oprövad, Today med bladet som VoiceOver-åtgärd och ⓘ 44×44 pt,
passets kort utan dubbel position, och fixturen `dtl_lucka` vid spärren på 15 cm (M39).

## S4e — Enklare navigering: Sessions och Me (Johannes 2026-10-24)

Beställningen: "navigeringen är för svår och ska förenklas". Två sidor: **Sessions**
(förstasidan) med alla pass, senaste först, och **Me** med profilen (längd, hand och klubbor).
Today och Progress försvinner ur navigeringen. Styrs av VISION.md: enkelt för användaren, och
djupet ett tryck bort i stället för borttaget.

- **Raden** visar översikten innan man går in: vyn (Down the line / Face on), datum och tid,
  klubban och antalet svingar. Ett pass med två telefoner är en rad per vy, med "paired" och en
  länksymbol (sedan S6g heter den styrandes rad "Paired" och har båda vyerna, B82). Ett tryck öppnar passet; ett svep raderar efter en fråga (passets mapp och filer:
  video, leder, mått, parning, 3D och exporten; `att_jobba_pa` ligger kvar, B64; den andra
  telefonens pass rörs inte). + uppe till
  höger ger Record och Import from Photos. En tom lista visar en kort rad och +.
- **Inne i en session bara dess vy:** måttkorten, felen, granskningens rader per position och
  klubbmarkeringen, genom katalogens `vy` (dtl, fo, bada); "bada" som tempot i båda. 3D-kortet
  (S6c-2) i båda.
- **Dolt men kvar:** Focus (Att jobba på) och Progress (och Today) syns inte, men koden och datan
  finns kvar. Import focus ligger i Me. "Ask Claude" och "Paste from Claude" stannar i sessionen.

**Byggt (grenen `s4e`, BESLUT B64, METOD MS20):** `App/Vyer/Flikar.swift` (TabView med Sessions
och Me), `App/Vyer/SessionerVy.swift` (listan, raden och frågan), `Store.deletePass`,
`PassetVy(vy:)`, SwingLabKit `Capture/Sessioner.swift` (`Sessionsrad`) och
`Swing/Visning/Vyfilter.swift`, och `DemoPass.dtl`. Prov: `SessionerTests` (Linux) och
`Prov/SwingLabProvSessioner.swift` (bilderna `sessions`, `sessions-radera`, `sessions-radera-vagrad`,
`session-fo` ur det parade FO-passet, `session-dtl` och `me`, båda sessionerna med 3D-kortet); Todays och Progress bilder ritas inte
längre, inte heller Progress med 3D (`utveckling-3d`).

**Klart när:** Johannes har öppnat appen i Sessions, sett sina pass med rätt vy, tid, klubba och
svingar, öppnat en FO- och en DTL-session och bara sett deras mått, raderat en session med svep
och fråga, och hittat längden och Import focus i Me.

## S4g — Ranges (Johannes 2026-10-24, beslut 2026-10-25)

Johannes ord: ranges ska vara tydliga, alltså vad som är bra. Ett mått som visas ska kunna
säga bra eller dåligt (VISION). Underlaget: [docs/research/6_ranges.md](docs/research/6_ranges.md)
(2026-10-25), ett band per mått där källan mäter samma sak och domar för måtten utan källa.
Johannes beslut 2026-10-25: alla rekommendationer i research 6 gäller preliminärt (BESLUT B86),
tre färger som Sportsbox (B87) och over the top på klubbans plan när klubban är markerad (B88).

**Byggt (grenen `s4g`, BESLUT B86–B88, METOD M62, M14 rättad).** Katalogen: research 6:s band, med källa
(järn i `gront`, driverns i `gront_driver` utan att användas), `golv` per fel och mått i stället
för `gult`, `samre` med golv för egen baslinje med känd riktning, `visas: false` för dom (b) (28
mått och felen flying elbow och axellutningen), dom (c) borttagna (åtta mått, beräkningen kvar),
`klubba` för over the top och 3D:s riktmärken 30–46° och 30–45° utan bedömning. Logiken i Python
(`katalog.lage`, `lage_baslinje`, `lage_for`, `jarn`, `visas`, `visade`, `kalla_for`, facit
`tools/tests/fixturer/bandlage.json`) och Swift (`Bandlage`, `Katalog.visade(i:)`,
`Fel.medKalla`, `Fel.medKlubba`), prövat i `test_katalog.Laget` och `BandlageTests`. Appen: en
grön prick, en gul ring eller en röd pil bredvid talet i passets kort och granskningens rader,
och samma form som markör på spannet (`App/Vyer/Bandet.swift`), de nio band som klubban flyttar
(`klubbberoende`) bara på järnpass och de andra på alla klubbor, den egna baslinjen märkt "Your
usual". Analysen till Claude bygger på samma källa och band som appen (`katalog.i_passet`,
`Fel.iPasset`), och Progress döljer dom (b) som passet. Simulatorprovet: `Prov/SwingLabProvBand.swift` (bilderna
`band-passet-fo`, `band-passet-dtl`, `band-passet-driver`, `band-granskning-p4` utan (b)-måtten och
`band-granskning-p6-klubba`).

**Klart när:** proven i Python och Swift ger samma läge för varje post i katalogen, simulatorn
ritar grönt, gult och rött och en granskning utan (b)-måtten, och Johannes har läst ett järnpass på
telefonen och direkt sett vad som är innanför, nära och utanför, och ändrat de mått han inte håller
med om (B86 omprövas per mått).

## S5 — PC-länken och Claude

- `tools/pc/session.py <paket>` läser paketet, kör det tunga (MediaPipe,
  kontaktark, tre metoder för vridningen) och skriver samma JSON.
- **Skillen `svinganalys`** för Claude Code (abonnemanget, BESLUT B4): läser
  måtten, de flaggade felen och kontaktarken, väljer 1–3 saker i ordning och
  skriver övningar och "klart när". Reglerna ur researchen: det som sker
  tidigare i svingen går före det som sker senare, ett följdfel får ingen egen
  övning, övningens tanke har extern fokus, och "klart när" mäts på första
  serien nästa pass, före uppvärmningen. Skillen minns vintern och byter
  övning när en inte biter.
- **Tillbaka till telefonen:** resultatet blir `att_jobba_pa.json`, som delas
  till appen och visas i S4.

**Klart när:** ett pass har gått telefon → PC → Claude → telefon, utan att
någon fil behövt redigeras för hand.

## S5b — Claude på telefonen (Johannes 2026-10-23)

Claudes tolkning ska också gå att göra på mobilen, utan PC och utan API-nyckel, med
abonnemanget (BESLUT B52). "Ask Claude" i passet kopierar en text: skillens regler (avsnitten
`claude-appen` i SKILL.md, B53) och passets data räknad på telefonen, med en mall per fel
som går att välja (B55). Johannes klistrar in den i Claude-appen. "Paste from Claude" läser
svaret, tar det sista kodblocket och kontrollerar det som PC:n (B54); godkänt blir det Focus
som "Import focus", annars visas fältet som är fel och inget ändras.

**S5b-1 — logiken (byggt, grenen `s5b`):** SwingLabKit `Swing/Claude/` (`Passanalys` och
`Ovningslage` portade ur `analysera_rader` och `ovningar_ur`, `ClaudeUnderlag`,
`ClaudeSvar`, `AttJobbaPaKontroll`, `JSONVarde`, och `ClaudeKallor` genererad ur skillen
och `kedjor.json`), `Capture/ClaudeKontext.swift` (passen → raderna, underlaget ur
`PassHistory.earlier`, `FocusInbox.acceptClaude`), och på PC:n `tools/pc/underlag.py`,
`att_jobba_pa.py --ur-text` och `session.py --claude-text`. Facit:
`tools/tests/fixturer/claude_facit.json` (påhittade passhistoriker, Pythons text och
svarstexter med felkoder), prövat i `test_underlag.py` och `ClaudeTests`. METOD MT11–MT12.

**Efter granskningen (Johannes beslut B56):** en sak följs i sin klubba och vy, ett pass med
flera klubbor analyseras per klubba, och PC:n väljer tidigare pass som telefonen. Svaret får
tak för storlek och djup, true är inte 1, och facit har en ändring per felkod i åtta
historiker.

**S5b-2 — knapparna (byggt, grenen `s5b2`, BESLUT B60, METOD MS18):** "Ask Claude" och "Paste
from Claude" på en grå rad i passet (under måtten) och på Today (under det senaste passets
rader), i `App/Vyer/ClaudeVy.swift`. Ask lägger underlaget i urklippet och visar "Copied", och
"Open Claude" när `claude://` går att öppna. Paste läser urklippet efter trycket, kontrollerar
svaret och visar sakerna i ett blad med "Use" och "Cancel"; finns redan en fil för passet frågar
bladet innan den skrivs över, och ett svar för ett äldre pass sparas utan att bli Focus. Urklippet
stannar på telefonen i 600 s och töms efter "Use". Ett ogiltigt svar ger en rad med fältet och koden, och inget
ändras. Simulatorprovet (`Prov/SwingLabProvClaude.swift`): urklippet är `ClaudeUnderlag` för
samma pass, ett påhittat svar blir Focus och accent på Today, ett ogiltigt ger raden, en fil som
finns ger frågan (Cancel och Replace), ett äldre pass behåller Focus, och bilderna `claude-*`. **Oprövat:** iOS fråga om att klistra in, Claude-appens
`claude://` och ett riktigt svar från Claude-appen; det provas på telefonen.

**Klart när:** Johannes har tolkat ett pass i Claude-appen på rangen och svaret blivit Focus
utan att någon fil redigerats för hand, och samma text (`session.py --claude-text`) har
prövats mot skillens fulla väg på PC:n.

## S4f — Spår i granskningen (Johannes 2026-10-24)

Beställningen: "Jag vill kunna lägga en tracker hela vägen på klubban genom svingen.
Trackern ska också kunna vara andra delar av kroppen: händerna, axlar och höfter, så man ser
hur det rört sig genom rymden. I förlängningen blir det en 3D-figur som följer hur man slår."

I granskningen slår Johannes på spår för valda punkter: händerna (greppet, handledernas mitt
med greppregeln M1), axlarna, höfterna och huvudet; klubbhuvudet när S7b ger banan. Ett spår
är en tunn linje över hela svingen: det som spelats upp ritas fast, resten svagt. Valet är
chips under videon ("Hands · Shoulders · Hips · Head", "Club" när S7b ger banan), sparat per
användare. Svartvitt
med gråtoner och linjestil per punkt (B13), ingen accent (B31). Banan jämnas lätt för
visningen (M60: mätningens σ, fönstret symmetriskt vid en kant), och en ruta där leden saknas
ger ett avbrott, aldrig en gissning.
Ritlagret är en egen vy (`SparLager`) som tar namngivna punktserier i bildens pixlar med tider
(`SparSerie`); S7b ritar med samma lager, och datamodellen och delningen återanvänds av S6d, som
ritar 3D med en egen vy. Mätningen rörs inte.

**Klart när:** simulatorprovet ritar spåren vid P4 och P7, och Johannes har slagit på spåren
på telefonen och förstått direkt vad han ser.

**Byggt (grenen `spar-s4f`).** METOD M60, BESLUT B70. SwingLabKit: `SparSerie` (namngiven serie i
bildens pixlar med tider; delarna, gränsen spelat/kvar och avbrotten) och `Spar.serier` (händerna
med greppregeln och brott där den byter handled, axlarna och höfterna som två serier var,
huvudet; `Spar.jamna`), och `ShotReview.yta` (samma avbildning för lederna och spåren), prövat i
`SparTests`. Appen: `App/Vyer/SparLager.swift` (`SparBild` räknad en gång, lagret med hela banan
svagt och det spelade fast, chipsen `SparVal`), ett eget lager i `ReviewStage` och en egen rad
under videons kontroller; valet sparas i `AppSettings.trails`. Simulatorprovet: bilderna
`granskning-spar-p4` (händerna) och `granskning-spar-p7` (alla fyra, lederna av). **Oprövat på
telefonen:** hur spåren syns mot en riktig bakgrund, och om chipsen får plats och förstås.

## S6 — Två kameror: vridningen och X-factor

Sportsbox-måtten som kräver S6 (turn, X-factor, vridfarter, core och shoulder
gain factor): [docs/research/4_sportsbox_matt.md](docs/research/4_sportsbox_matt.md).

Två iPhones filmar samtidigt, DTL och FO med cirka 90° mellan sig (60–120°
går), 3 m bort och i höfthöjd. Synken tas på klicket och finjusteras på
minsta återprojektionsfel (2 ms; korskorrelation av farten ger 7–13 ms).
Varje telefon kalibreras en gång mot ett ChArUco-mönster, och varje pass mot
minst 6 punkter på mattan spridda minst 1 m och inmätta på ±1 cm (eller
självkalibrering ur lederna med telefonens lodlinje). Lederna trianguleras
till 3D. Det ger bäckenets och bröstets vridning, X-factor, stretchen och
höfterna öppna vid träffen (gränsen 35–45° grönt; Sportsbox, GolfTEC och Zheng
möts, research 1 §1.7). Felbudgeten: `docs/S6_FELBUDGET.md`.

**Två lägen (BESLUT B14):**
- **Utan markörer:** posemodellens höft- och axelpunkter. Felbudgeten ger
  cirka 10–16° per sving med typiskt 2D-brus, eftersom höftlinjen bara är
  ~20 cm. Vridningen och X-factor visas därför bara som **trend per pass**
  (median över minst 10 slag).
- **Med markörer:** en pinne i bältet och en stav över ryggen med färgade
  ändar, sedda i båda vyerna. Bäckenet inom 1–1,5° och bröstet inom 0,5° per
  sving. Appen märker vilket läge talet kommer från.

X-factor visas som egen trend, inte mot en gradgräns: definitionen ensam
flyttar den cirka 19° i samma sving (Euler, akromionlinjen, bröstkorgens
axel). Stretchen visas före X-factor vid toppen, eftersom den oftare hänger
ihop med klubbfarten.

**Facit:** markörerna själva, triangulerade, mot posemodellens vridning i
samma svingar, och en iPhone på bältet som rörelsefacit. Golvlinjer räcker
inte: människans eget inriktningsfel är lika stort som kravet.

**Klart när:** med markörer ligger vridningen inom 2° från facit per sving;
utan markörer ligger passets median inom 5° från markörernas median på samma
pass; och vyn visar läget (markör eller trend).

### S6a — PC-sidan utan markörer (2026-10-22, grenen `s6a`)

**Gjort:** `tools/pc/tva_kameror.py` gör passets två paket (DTL och FO) till 3D:
slagen paras på `par.json` eller klicken, lederna läggs på träffens tid, kamerorna
kalibreras själva ur lederna en gång per uppställning (serie mot serie), med
brännvidden ur seriens synfält och lodlinjen ur det nya valfria fältet
`serier[].lodlinje` (annars kamerornas vågräta), en uppställning över spärren för
Sampson-felet mäts inte, synken finjusteras per slag på återprojektionen, lederna
trianguleras, och bäckenets och axlarnas vridning,
X-factor, stretchen och höfterna vid träffen blir passets median över minst 10 slag,
märkt "utan markörer". `session.py` skriver `tre_d` i `analys.json`, måtten står i
`katalog_3d.json` (bara PC:n, BESLUT B37; i `katalog.json` sedan S6c-2), minnet bär trenden pass för pass och
skillen `svinganalys` rapporterar den som trend. Ett fel i 3D stoppar aldrig 2D.
METOD MK1–MK8, BESLUT B37–B39.

**Facit (påhittat):** `generera_paket.py --tva` filmar 3D-svingar ur `tre_d/sving.py`
med två kameror och felbudgetens brus, och skriver paketen och de sanna måtten.
Utan brus ligger passets median inom 0,5° och varje slag inom 1°, även för en
vänsterspelare, med FO som styrande och med en annan brännvidd än specifikationens. Med brus ligger
passets median inom felbudgetens gräns (|bias| + 3 SD, S6_FELBUDGET §6.7); uppmätt
över 24 pass per nivå står i §6.7. Självkalibreringen kostar mest i bröstet: med
typiskt brus är kalibreringens fel 5° i snitt, upp till 14° (B38).

**Återstår:**
- **Johannes:** riktiga pass med två telefoner (S2g) och en uppställning enligt
  S6_FELBUDGET §7; markörerna (pinnen i bältet, staven över ryggen) och facitet med
  pinnarna (§8); S3:s mätning av posemodellens 2D-fel, som avgör om trenden bär
  (B14). Klart när ovan är inte nått: det kräver markörerna.
- **Appen (följdjobb):** vyn för trenden med läget (S6b), då måtten flyttar in i
  `katalog.json` (B37). Lodlinjen i manifestet: S6b-1 nedan.
- **PC:n:** markörernas läge (S6b), och mattan eller en kalibrering som skattar
  posemodellens fasta avvikelse om S3 visar att den är stor (B38).

### S6b — Appen: lodlinjen, sedan trendvyn (2026-10-23, grenen `s6b`)

**S6b-1, lodlinjen (gjort):** appen läser `CMDeviceMotion.gravity` i 30 Hz under varje
serie (App/Motion.swift) och ger bara proven. SwingLabKit (`Plumb`, Lodlinje.swift) tar
medianen över sekunden före seriens första klick när den stämmer med seriens stilla
sekunder, annars de stilla sekunderna när de är eniga, och spärrar en telefon som rör sig
(spridningen, 95:e percentilen, över 1°) eller ett stativ som stöts. Den sparar
gravitationen, skälet och klockans två tal i `pass.json` och
vrider den i manifestet till kamerans ram med filens orientering: `serier[].lodlinje`
står med bara när PC:ns kontroll tar den och den lutar högst 45°. Gamla pass och pass utan
rörelse (simulatorn, Bilder) paketeras som förut. Samma påhittade telefoner i stående och
liggande (`tools/tests/fixturer/lodlinje.json`) prövas i Swift och genom `paket.py`;
simulatorprovet visar ett paket utan fältet och ett med injicerade prov, båda lästa av
PC:n. `NSMotionUsageDescription` står i project.yml (tillåtelsen från iOS 27.2). PC:n
skriver vinkeln mellan fältet och kamerornas vågräta per uppställning och faller tillbaka
på de vågräta över 15° (MK3). METOD MS17, MK3, BESLUT B39.

**Oprövat på telefonen:** att `gravity` och dess tid är det som antas (enhetens ram,
värdklockan, avläst ur `beforeClickSamples` och `firstSampleOffset`), spridningen på ett
riktigt stativ (spärren 1°), tillåtelsen på iOS 27.2, och att PC:ns 3D blir densamma
eller bättre med fältet än med kamerornas vågräta (B39 omprövas på
`lodlinje_mot_vagrata`).

**Återstår (S6b-2):** trendvyn med läget, och visa i uppställningen om telefonen lutar.

### S6c — 3D på telefonen (2026-10-23, Johannes mål: så mycket som möjligt på mobilen)

**S6c-1, logiken i SwingLabKit (grenen `s6c`):** målet `TreD` räknar S6a:s kedja rad för rad
som `tools/pc/tva_kameror.py`: parningen (par.json eller klicken), spåren på träffens tid,
självkalibreringen per uppställning med K ur synfältet, lodlinjen med riktningskontroll och
reserv på kamerornas vågräta, spärrarna (Sampson-felet, vinkeln mellan kamerorna), synken
på klicket med finjustering på återprojektionen, trianguleringen, 3D-måtten med MK6:s
tidsaxel och luckregler, passets median över minst 10 slag, `osaker` och `hoppat` med
skäl. Linjär algebra utan Accelerate (ensidig Jacobi, LU, Levenberg–Marquardt). Indata är
paketens värden (`TreDPaket`, lederna som Captures `JointSeries`) och 2D-fasernas start och
topp; utdata är `TreDResultat`, samma form som `analys.json`:s `tre_d`. Python är facit:
`tools/pc/generera_tre_d.py` skriver påhittade pass (utan brus, bra brus med vänsterspelare,
lodlinje och utan par.json, lodlinjens och brännviddens vägar, spärren, parningens fall) och
Pythons tal, och TreDTests kräver dem inom METOD M50:s tolerans. Kalibreringens urval av
punktpar är nu jämnt spritt i båda språken (BESLUT B48). METOD M50, BESLUT B48.

**S6c-2, appen (grenen `s6c2`, gjort):** när följarens slag är analyserade skickar den dem till
den styrande i passets skärm över PhoneLink: ett paket utan video (`SlagBunt`, manifestet,
enhet.json, par.json och lederna kompakt), i bitar om 192 kB (`part`, version 1) som kvitteras och
skickas igen efter ett tapp. Den styrande räknar 3D med `TreD` i `Task.detached` när båda
telefonernas slag är analyserade, med 2D-faserna ur samma leder som PC:n, sparar `tre_d.json` i
passet och skickar den tillbaka; ett pass räknas om när någon telefons slag ändras. "Import other
phone" läser den andra telefonens zip när kopplingen inte fanns. Passet visar kortet "3D · no
markers" med de fem måtten, skillnaden mot förra passet, antalet svingar och skälen i grått;
Progress har de fem måtten med felbudgetens spann runt varje punkt; inspelningen visar
lutningen åt sidan och "Tilt too large for 3D" över 45°. 3D-måtten står i `katalog.json`
(`tre_d`). `tre_d.json` följer med paketet, och PC:n skriver skillnaden mot sin egen
(`tre_d.telefon`). Storleken: cirka 105 kB per slag (960 rutor), 2–3 MB per pass om 20 slag;
uppmätt 55 kB per slag på provets pass. Tiden: tio slag 1,0–1,9 s i simulatorn. BESLUT B61–B63,
METOD MS19, M50.

**Oprövat på telefonerna:** Bonjour och lokalt nätverk i passets skärm (båda telefonerna ska ha
passet öppet efter Analyze), tiden på en iPhone, importen ur Filer och AirDrop, lutningen på
stativet (`gravity` live), och att riktiga leder ger samma tre_d som PC:n (Klart när nedan).

`TvaKameror.analysera` (eller `treD`) tar några sekunder och ska köras i `Task.detached`,
aldrig på huvudtråden.

**Klart när:** S6c-1: TreDTests gröna i Actions mot Pythons tal och mot sanningen, och
tiden per pass uppmätt och skattad för telefonen (M50). S6c-2: ett riktigt pass med två
telefoner ger samma `tre_d` på telefonen som på PC:n: samma parning, uppställningar,
skäl (`osaker`, `hoppat`, `utelamnade`) och avrundade fält, och varje mått per slag inom
**0,05°**. Riktiga leder är inte fixturernas: skiljer något mer, redovisas vilka grenar
som slog om (en jämförelse vid en gräns, t.ex. spärren, skyddet mot de vågräta,
parabelns topp eller synkens minimum) och med hur mycket, innan toleransen ändras.

### S6d — 3D-banor och 3D-figur ur två telefoner (Johannes 2026-10-24)

S6c triangulerar redan 13 leder per ruta. Visa banorna (S4f:s punkter) i 3D och en figur av
streck och leder som spelas upp med svingen och kan vridas, i formspråket B13: ett
mätinstrument, ingen modellerad kropp. Klubban kommer med när S7b ger klubbhuvudet i båda vyerna.
Johannes mål (2026-10-24): Lead-telefonen gör hela analysen för ett pass med två telefoner, 3D
och synken mellan det de ser; S6d är figuren, S6g videon och S6h 3D-måtten.

**Byggt (grenen `s6d`, BESLUT B72, B73, METOD MK10, MK11):**
- **Datan:** telefonen som räknar 3D sparar i samma räkning lederna per slag och kamerorna per
  uppställning i `tre_d_figur/` (index och en fil per slag, int16 i mm, docs/FORMAT.md
  "Figuren i 3D"), i meter med skalan ur benens längd i adressen (med skydd och reserv, samma
  funktion i PC:ns visare) och lodlinjen uppåt. Inte i paketet.
  `TvaKameror.analysera` lämnar kamerorna och trianguleringarna genom en samlare, även för en
  uppställning över spärren (kameror, ingen figur). Python är facit (`tools/pc/tre_d_figur.py`,
  `figur.json`, TreDFigurTests inom 1e-6). Ett pass räknat före S6d räknas om när det öppnas.
- **Figuren:** passets kort "3D · no markers" har en rad "3D" som öppnar figuren i helskärm:
  streck och leder (vänster vit och fylld, höger grå och ihålig, det bortre svagare), en tunn
  markyta och mållinjen med en pil, ritad med Canvas och en egen projektion (B73). Ett finger
  vrider, nypning zoomar, dubbeltryck och segmentet Face on · Down the line · Top ger de
  färdiga vinklarna (ur kroppen i adressen). Granskningens tidslinje: spela, ruta för ruta,
  P1–P10, farten 1/8, 1/4 eller 1, och spåren Hands, Shoulders, Hips och Head i 3D med S4f:s
  `SparSerie` och val. Pilarna uppe till höger byter sving; bara den som visas läses.
- **Kamerorna:** valet "Cameras" ritar telefonerna där kalibreringen placerade dem, med
  Sampson-felet mot spärren och vinkeln mellan dem mot 60–120°. Ett pass över spärren öppnar på
  telefonerna med skälet; ett pass utan 3D visar bara skälet i grått.
- **Simulatorprovet** (`Prov/SwingLabProvTreDFigur.swift`): figuren vid P4 och P7 från de tre
  vinklarna (`tred-figur-p4-faceOn` osv.), telefonerna (`tred-figur-kameror`), över spärren
  (`tred-figur-over-sparren`), utan 3D (`tred-figur-utan`), och figuren sparad och läst.

**Oprövat på telefonen:** att vrida och nypa med fingrarna, farten i verklig tid, tiden att
räkna figuren på en iPhone, och ett riktigt pass.

**Klart när:** ett riktigt pass med två telefoner spelas upp i 3D på telefonen, och banorna går
att vrida och stega P1–P10.

### S6e — 3D ur en telefon (Johannes 2026-10-24)

En modell som skattar djupet ur 2D-lederna (monokulär lyftning). Ett stort jobb, med licens
och facit att utreda (S6:s två telefoner är facit). Görs senare, om två telefoner känns
krångligt i praktiken.

### S6f — Visaren på PC:n (Johannes 2026-10-24)

Första riktiga passet med två telefoner (2026-10-24) gav ingen 3D: telefonerna var märkta
med fel vy, och kalibreringen satte kamerorna 165–177° isär med Sampson-felet långt över
spärren. Siffrorna i terminalen sa att något var fel, men inte vad. En bild av lederna och
kamerorna hade visat båda felen direkt. Visaren är PC:ns verkstad och facit (VISION), ingen
andra app: den visar det kedjan redan räknar, så att ett trasigt pass syns och ett bra pass
går att granska. Den dubblerar inte S6d, som är 3D på telefonen. Formspråket är B13: ett
mätinstrument, ingen modellerad kropp.

**Gör:** `tools/pc/visa.py <dtl.zip> <fo.zip> [--ut <mapp>]` skriver en fristående sida per
pass, `~/swinglab-analys/<pass>/visa.html` (en utmapp i repot utanför `data/` vägras, som i
`session.py`), med klippen kopierade bredvid. Den öppnas i webbläsaren utan server och visar:

- båda vyernas klipp sida vid sida med Visions leder ovanpå, och MediaPipes när S3 sparat dem
  (`~/swinglab-s3/<pass>/mediapipe/`, flyttade med S3:s förskjutning), med stegning P1–P10
  ur 2D-faserna och uppspelning i takt på träffens tid;
- 3D-figuren ur `tva_kameror.py`:s triangulerade leder (three.js), som går att vrida och
  spelas i takt med klippen, och 3D-lederna projicerade tillbaka i båda klippen;
- kamerorna där kalibreringen placerade dem, per uppställning, med Sampson-felet mot
  spärren, vinkeln mellan kamerorna mot 60–120° och varje pakets vy-etikett, så att en
  fel märkt telefon eller en trasig kalibrering syns direkt. En uppställning över spärren
  ritas ändå, märkt "över spärren": det är det som ska synas;
- måtten per sving (2D per vy och 3D per par) och skälen när 3D hoppades över.

3D-lederna sparas inte i `analys.json` (formen är oförändrad); visaren anropar kedjan själv,
med en valfri krok i `TK.analysera` som lämnar uppställningarnas slag.

**Klart när:** testerna bygger sidan på påhittade pass (med 3D, över spärren och med två
paket med samma vy) och den bär figuren, kamerorna och måtten; och Johannes har öppnat ett
riktigt pass i visaren och sett kamerorna och figuren där kalibreringen satte dem.

### S6g — Videon från båda telefonerna på Lead (Johannes 2026-10-24)

Johannes mål: Lead-telefonen ska ha videon från båda telefonerna och kunna göra hela analysen.

**Beställningen:**

1. **Ett parat pass blir en rad "Paired"** i Sessions på Lead. Inne i passet växlar man mellan
   DTL, FO och 3D. Videorna spelas synkat på träffens tid, och P1–P10-stegningen gäller båda
   vyerna. Follow-telefonen har kvar sin egen rad.
2. **Överföringen sker automatiskt via appens koppling** (PhoneLink, direkt wifi/AWDL, ingen
   mobildata) efter passet. Bara svingarnas klipp, från 4 s före till 2,5 s efter träffen. Lead
   styr: den begär klipp för de tider den vill ha ur parningen (par.json, klicken och
   förskjutningen), också för ett klick som Follow missade. Follow behåller hela inspelningen tills
   Lead kvitterat att alla klipp kommit fram; "Get full video" i passet på Lead är reserven. En rad
   med förloppet ("Getting video from other phone · 60 %"), och överföringen fortsätter där den
   slutade när kopplingen återkommer. `beginBackgroundTask`, så att en kort överföring hinner klart
   om appen läggs undan. AirDrop och "Import other phone" (S6c-2) är reserven och tar också video.
3. **Passet visar vad som finns,** t.ex. "14 swings · 12 from both phones".
4. **Samma vy på båda telefonerna:** appen säger tydligt till redan i uppställningen när de kopplas
   (första riktiga passet 2026-10-24 hade fel vy-etiketter, och då gick 3D inte att räkna).

**Byggt (grenen `s6g`, BESLUT B80–B83, METOD MS30, MS31, docs/FORMAT.md "Video mellan
telefonerna"):** SwingLabKit `Capture/Klipp.swift` (`KlippBegaran`, `KlippSandare`,
`KlippMottagare`, `Klippfil`) och `Capture/Parad.swift` (`AnnanVideo`, `Parstatus`,
`AnnanSession`, `AnnanPaket`, `ImportKlipp`, `Vyvakt`), förmågan `video1` och vägen genom
`LinkLeader`/`LinkFollower` (`stream`, `streamAck`); appen `App/KlippKoppling.swift` (på 3D:s
koppling i passet), `App/Vyer/ParadVy.swift` (växlingen, raderna, raden "Paired",
den andra vyns lista och varningen), granskningens växling DTL/FO, Send to PC med två paket,
och varningen i uppställningen med "Switch to FO". Prov: `KlippTests` (Linux),
`Prov/SwingLabProvVideo.swift` (simulatorn) och `AppensParadePaket` i
`tools/tests/test_appens_paket.py` (PC:n läser den styrandes två paket).

**Efter granskningen (B84):** klippets början läses ur filen och klicket räknas bara inom 30 ms,
slag utan klick märks, nej med skälen `disk` och `saknas`, en gammal begäran vinner aldrig,
följarens original släpps när allt är framme (och efter en vecka), taket 128 MB per klipp, "Paired"
bara med par.json eller den andra telefonens slag, "Get full video" under den andra vyn. Efter S6d
bär 3D-fliken i Leads parade pass S6d:s rad "3D", som öppnar figuren (prövat i simulatorn).

**Uppmätt i simulatorn** (påhittad film, loopback, MS30): fyra klipp 2,74 MB i 15 bitar på 2,0 s
med ett avbrott om 1,5 s (inga bitar igen), också klippet för klicket följaren missade (märkt utan klick); hela
serien 1,37 MB på 0,09 s; den andra vyns vita ruta på samma träff som den styrandes; den andra
vyns paket med tre klipp läst av `paket.py`. Räknat för riktiga klipp: cirka 33 MB per sving,
460 MB för 14 svingar.

**Oprövat på telefonerna:** AWDL utan gemensamt wifi, tiden och storleken för riktiga HEVC-klipp
(MS30 räknar 33 MB per klipp), var ett passthrough-klipp av HEVC börjar (klicket mäts om),
bakgrunden, och Import other phone med klipp ur AirDrop.

**Klart när:** Johannes har filmat ett pass med två telefoner, och på Lead (1) sett raden "Paired"
och i passet växlat DTL, FO och 3D, (2) sett förloppet och "N swings · M from both phones" med M lika
med svingarna som båda telefonerna filmade, (3) stegat P1–P10 i granskningen och sett FO-videon på
samma ruta som DTL vid träffen, (4) dragit ur kopplingen mitt i (flygplansläge) och sett att den
fortsatte, (5) hämtat hela videon med "Get full video", (6) fått varningen när båda telefonerna
stod på samma vy, och (7) skickat Send to PC och fått två paket som `session.py` och
`tva_kameror.py` läser.

### S6h — 3D-måtten bredvid 2D (Johannes 2026-10-24, inte byggt)

När båda vyerna finns visas mått som räknas bättre i 3D, **sway, thrust och lift i verklig
riktning**, som "3D" bredvid 2D-måtten. **2D är huvudmåttet** med gränserna tills markörerna
visat att 3D håller (BESLUT B14); 3D-talet visas utan bedömning, som S6c:s kort. Sträckor (cm)
visas bara när figurens skala kommer ur benen (`skala == "langd"`, METOD MK10), aldrig med
reserven, och räknas med samma funktion i båda språken (`tre_d_figur.skala` och
`TreDFigurer.skala`, B12).

**Klart när:** sway, thrust och lift räknas ur figurens leder i båda språken med samma tal
(B12), syns som "3D" bredvid 2D-måttet i ett parat pass, och jämförelsen mot markörerna (S6)
avgör om 3D får egna gränser.

## S7 — Klubban

Sportsbox-måtten som kräver S7 (club-hand gap, skaftets fart, wrist och release
factor, P2/P6/P8): [docs/research/4_sportsbox_matt.md](docs/research/4_sportsbox_matt.md).

**Underlaget 2026-10-25:** [docs/research/7_klubban.md](docs/research/7_klubban.md): öppna
dataset och modeller med licens, den egna märkningen, vägvalet (keypoints top-down på
2080 Ti:n) och förslaget till S7-1 (`skaft_plan_p6` bakifrån och `skaft_arm_p6` framifrån utan
tryck), med frågor till Johannes. GolfPose licens (läst) tillåter modeller i appen; bara
rådatan får inte spridas.

**Johannes svar 2026-10-25 (BESLUT B92):** modellen ska kunna användas av andra, så ingen
NC-data och ingen AGPL. En detektor på golf-49wbh förmärker hans svingar och han rättar.
Passet från 2026-10-24 (SwingLab) är provet. Träningen körs på PC:n (2080 Ti, WSL2).

En detektor för grepp, skaft och klubbhuvud, tränad på PC:n på egna rutor
(Claude hjälper till att märka) och körd i appen som Core ML. Det finns inget
färdigt att ta: GolfPose har eget EULA, ClubheadDB är CC BY-NC och bara DTL.
Punkterna följer GolfPose definition. Modellen är YOLO-pose eller en med
friare licens (Ultralytics är AGPL). Det ger casting
(vinkeln mellan vänsterarm och skaft i nedsvingen), svingplanet, across the
line och laid off, och skaftlutningen vid träffen.

**Klart när:** skaftets vinkel ligger inom 5° från handmärkta rutor i adress,
topp och tidig nedsving, i båda vyerna.

**Förberett:** verktyget `python tools/pc/markera_klubba.py <paket.zip|video.mov>`
(BESLUT B44, METOD MF5–MF6), efter S3: rutorna väljs ur faserna (adress, topp, tidig
nedsving och några jämna, båda vyerna) och läses med S3:s tidsförskjutning, Johannes
klickar grepp, skaftets mitt och hoseln på en lokal sida, och märkningen sparas bredvid
paketet (`swinglab-klubba/1`, FORMAT.md).

### S7a — Klubban markerad för hand i appen (Johannes 2026-10-23)

Beställningen: klubban markeras för hand i appen, som en enklare väg före den tränade
detektorn. Markeringarna ger klubbmått direkt och blir träningsdata. Alla P-positioner
P1–P10. DTL först i appen, sedan FO (nedan); datamodellen och formatet är
vyoberoende. Greppet är skaftet mitt mellan händerna och klubbhuvudet hoseln (B44). P2, P6
och P8 är skaftet parallellt med marken: appen föreslår en ruta mellan kroppens tider,
Johannes stegar till den ruta där skaftet ser parallellt ut, och den rutan blir positionen
för svingen. Ett tryck nära kanten eller utanför bilden blir ingen punkt. 2–3 svingar per
pass räcker, och passet visar hur många som är markerade.

**Klart när:** måtten ur markeringarna finns i Python och Swift med samma tal (B12, inom
10⁻⁶), med METOD-rader, katalogens positioner och vy och egen baslinje; formatet läses åt
båda håll mot `markera_klubba.py`; simulatorprovet ritar granskningen med skaftlinjen och
märkningsläget med förstoringsglaset; och Johannes har markerat 2–3 svingar i ett riktigt
DTL-pass på telefonen och sett måtten i passet.

**Byggt (grenen `s7a`).** BESLUT B47, METOD M45–M49 (och M28 med P2, P6, P8 och Sportsbox
positioner). Datamodellen `KlubbMarkering` (position, rutans tid, greppet och hoseln i hela
bildens pixlar, källan `klick` eller `handlederna_bekraftad`, `andrad`, hoppad) i
`Swing/Klubba.swift`, sparad i `pass.json` (`slag[].klubba`, valfri) och i paketet som
`klubba.json` i formatet `swinglab-klubba/2` (FORMAT.md; version 1 är en delmängd och läses
av båda); riktpinnen per serie (`serier[].riktpinne`). Ägaren på PC:n är `tools/pc/klubba.py`;
`markera_klubba.py` skriver version 2, `paket.py` läser markeringarna och riktpinnen,
analysen lägger klubbmåtten bland slagets mått med P2/P6/P8 och `klubba` (median och n),
historikens minne bär dem, och `tools/pc/samla_klubba.py` samlar telefonens och PC:ns
markeringar till en träningsmapp utanför repot. Måtten: skaftets vinkel vid varje position
(båda vyerna); DTL skaftplanet vid P1, across/laid off vid toppen (flyktpunkten ur
riktpinnen eller bildens mitt, märkt "assumed") och hoseln mot planet vid P6; FO skaftet
vid toppen, armen mot skaftet vid P5 och P6 (casting) och skaftlutningen vid träffen; varje
mått spärras på sin osäkerhet ur trycken (4°). Appen: "Mark club" i granskningens meny
(DTL), `ClubMarking` i SwingLabKit (trycken, kanten, rutans tid från första trycket, ringen,
flytt efter 4 pt, ångra, hoppa, förslaget), `App/Vyer/KlubbaVy.swift` (ytan, glaset 3 × ur
en stillbild, P1–P10 med VoiceOver, riktpinnen), uppställningens rad för DTL, skaftlinjen
i granskningen, P2/P6/P8 i positionsraden när de är markerade, och passets rad "N with club
marked" och korten med median och n. Prov: `tools/tests/test_klubba.py`, `KlubbaTests`,
`KlubbaMarkeringTests`, `Prov/SwingLabProvKlubba.swift` (bilderna `klubba-granskning`,
`klubba-markera`, `klubba-markera-utan-finger`, `klubba-markera-ringen`, `klubba-passet`; de tre
märkbilderna är ersatta i S7c),
och paketprovet bär markeringar som PC:n läser (`test_appens_paket.py`). Mätversionen är
oförändrad (B47). Efter granskningen 2026-10-23: P2 mot planet borttaget (M47).

**FO (grenen `s7afo`, BESLUT B57, B58).** "Mark club" även för FO-serier, samma flöde (grepp
och hosel, glaset 3 ×, ringen, sparning av sig själv, ångra, positionsraden), utan riktpinne
(`ClubMarking.view`, `stickAvailable`, `xTecken` ur svingen). Ordningen i båda vyerna är
kroppens positioner först och skaftets sist: P1, P3, P4, P5, P7, P9, P10, P2, P6, P8
(Johannes 2026-10-24, B58). P2, P6 och P8 framifrån föreslås där skaftets vinkel mellan de
markerade ändarna går genom vågrätt, P2 från baksvingens start (`ShotMeasure.start`), och
inget förslag ur skaftet över 270° (fel håll) (`forslag_tid_skaft` och
`Klubba.forslagTidSkaft`, samma tal, M45); förslaget gäller också en hoppad position. Två
telefoner: `ClubPairTime` (parningen DTL mot FO, klicken ur paret med index, träffens
förskjutning) ger FO-markeringens tid till DTL-slaget, och `ClubMarking` föreslår den bakifrån
när den finns, annars kroppens (prövat i Swift). Analysen skriver `klubba_flyktpunkt` bara
bakifrån. Uppställningen framifrån har sin rad ("Facing the player, at hip height, aimed
square to the target line") och sin känslighet i M49 (3D-provet från den uppställningen:
höjden 2,3° per 0,2 m på casting, sidoläget 1,6° per 0,1 m, vridningen högst 0,21° per grad,
rullningen 1:1). Fixturernas FO-skaft har längder som i bild (0,80 m vid 400 px/m: 160–310 px,
osäkerheten 0,8–1,5°), och vänsterspelaren framifrån har P3 och P5. Prov: `test_klubba`
(förslaget ur skaftet med starten och fel håll, flyktpunkten bara bakifrån, trycken till samma
pixel), `KlubbaTests`, `KlubbaMarkeringTests` (ordningen, förslaget räknat för hand, den
hoppade positionen, paret), simulatorprovet `testMarkeraKlubbanFramifran` (märker i appens
ordning och prövar förslaget mot värden räknade för hand; bilderna `klubba-fo-granskning` och
`klubba-fo-markera`).

**Kvar:** telefonen i båda vyerna (trycken, glaset, gränserna 3 %, 5 % och 4 pt,
riktpinnen bakifrån, förslaget ur skaftet framifrån), och vägen för FO-telefonens
markeringar till DTL-telefonen (ett meddelande på länken eller paketet in i appen, B57):
utan den används `ClubPairTime` inte i appen. Rullningen rättas med lodlinjen (MS17) när
den kommer in i måtten.

### S7c — En tydligare markering (Johannes ja 2026-10-24)

Johannes provade S7a på telefonen och förstod inte vad han skulle göra: "Grip" ensamt,
"Stick", ringen och en Next som såg spärrad ut, och klubban var liten. Han, och i förlängningen
andra, ska förstå direkt (BESLUT B59, METOD M45).

**Byggt (grenen `s7afo`).** Instruktionsraden överst ("1 · Tap the grip", "2 · Tap the
clubhead") med en skiss av en klubba där punkten lyser; ordet "hosel" är borta ur appen och
katalogens infoblad (data och METOD oförändrade). Varje position öppnas inzoomad högst 2,5 ×
kring händerna och den förväntade klubban; nyp, dra och dubbeltryck; trycken blir hela bildens
pixlar (`KlubbYtaFixturer`, samma i Python). Punkterna heter 1 och 2, skaftlinjen dras mellan
dem, och gissningen av greppet är en ihålig "1?". Positionen i klartext i den nya ordningen
(B58): "P4 · Top of backswing · 3 of 10". Next borta, "Not visible" heter "Skip", Undo kvar.
Riktpinnen är ett eget valfritt steg bakifrån före P1, en gång per serie (Skip sparas i serien).
Guiden med tre bilder första gången och under "?" (inställningen `clubGuideSeen`). Undantaget
från B13 gäller bara märkningsläget (B59, design/README regel 9). Prov: `KlubbaMarkeringTests`
(zoomen, trycken inzoomat, positionen i klartext, riktpinnens steg, guidens inställning),
`test_klubba` (zoomen i Python), simulatorprovet (bilderna `klubba-guide-1` … `3`,
`klubba-riktpinne`, `klubba-greppet`, `klubba-klubbhuvudet`, `klubba-klar`, `klubba-fo-markera`).

**Klart när:** Johannes har markerat 2–3 svingar på telefonen med S7c utan att fråga vad han
ska göra, i båda vyerna.

### S7b — Klubbhuvudets bana mellan ankarna (Johannes ja 2026-10-23)

Johannes tryck vid P1–P10 (S7a) blir **ankare**. Mellan två ankare spåras klubbhuvudet
mekaniskt med rörelsedifferens: pixlar som skiljer sig från rutan t−2 och t+2, kroppen
maskerad ut ur Visions leder, och sökningen begränsad till en korridor mellan ankarnas
punkter och längs den förväntade bågen. Där spårningen tappar (bakom kroppen, mot en mörk
bakgrund) interpoleras banan till nästa ankare, och rutan märks interpolerad.

Det ger klubbhuvudets hela bana, och därmed svingplanet och "över eller under planet"
genom hela nedsvingen (Morrison, research 5 §5 punkt 11); ett spår i granskningen, som
spökbilder av klubbhuvudet i stil med Willett-klippet; och fler rutor till S7:s träning,
där varje spårad ruta mellan ankarna godkänns eller rättas med ett tryck.

**Förebild:** sessionen "Range session video effect" (2026-10-20). Rörelsedifferensen
spårade 317 rutor i ett DTL-klipp men behövde 22 handrättningar och en hårdkodad mask;
koden sparades inte. Ankarna och kroppsmasken ur lederna ska ta bort handpåläggningen.

**Plats i S7a:s datamodell:** varje punkt bär sin källa (`kalla`, i dag bara `klick`), så
att en spårad eller interpolerad punkt blir en ny källa i samma format
(`swinglab-klubba/2`, FORMAT.md) och en ruta mellan ankarna en ruta med en annan `val`;
klubbmåtten tar i dag bara tryckta punkter.

**Byggt (grenen `spar`, 2026-10-24, efter granskningen).** METOD M61, BESLUT B71.
`tools/pc/klubbspar.py` (facit) och `KlubbSpar` i SwingLabKit (samma tal inom 1e-6, också med
glesa ankare): bara mellan grannar i svingens ordning, rörelsedifferensen 2/240 s före och efter
med en brusanpassad tröskel, kroppen maskerad ur lederna, korridoren kring greppet, fläcken
vars yttre kant ligger närmast skaftets längd, mitten mot hoseln mätt vid ankarna, och
prövningarna skak, radien, språnget och grannarna; där den tappar interpoleras banan polärt.
Facit är den påhittade filmen `klubbfilm.py` / `KlubbFilm` (samma bytes i båda språken) och i
Python åtta varianter (bakifrån, oskärpa, låg kontrast med och utan brus, textur med skak, boll,
skugga, mitten bredvid hoseln): **inga grova fel bland de spårade rutorna i någon variant**,
grunden median 0,59 px och p95 2,38 px (skaftet 150 px) med 45 % interpolerade; bakifrån och med
låg kontrast i vanligt brus är tre av fyra rutor interpolerade (M61). Datamodellen `KlubbBana`
och `swinglab-klubba/3` i båda språken, och `samla_klubba.py` med version 3. Appen: `RutStrom`
läser Y-planet ur filen en gång med en ringbuffert (`KlubbRutor`, EXIF 1–8), `Store` räknar en
bana i taget när Club slås på och kan avbrytas, chipet visar läget, och bakifrån ritas
P1-planet. Planet räknas men visas inte som tal (B71). Prov: `test_klubbspar` (varianterna,
glesa ankare, samla och formatet), `KlubbSparTests`, `KlubbBanaTests`, `KlubbRutorTests`,
simulatorprovet `SwingLabProvSpar` (rutorna ur en riktig film upprätt, bilderna
`klubba-bana-p6`, `klubba-bana-p10` och `klubba-bana-dtl`).

**Oprövat på telefonen:** banan på riktiga klipp (mitten mot hoseln, rörelseoskärpa,
bakgrund, bakifrån), tiden för att läsa rutorna och räkna, och att `RutStrom` läser riktiga
slow motion-filer i rätt ordning.
**Kvar till ✓:** S7b:s Klart när på DTL-klipp mot 20 slumpvis valda handmärkta rutor (M61);
godkänn och rätta i appen.

**Klart när:** banan ligger inom en överenskommen gräns (sätts i METOD) från handmärkta
rutor mellan ankarna, på DTL-klipp, med andelen interpolerade rutor redovisad.

## S8 — Bollen vid adressen

Bollen hittas i adressbilden (FO) och ger bollens läge i stansen.

**Klart när:** läget stämmer med handmätt inom 2 cm på 10 slag.

## Läget och nästa steg (2026-10-23, morgonen)

**Landat:** S1, S1b (små Sportsbox-mått, METOD M30–M37), S2a–S2g (appen, paketet
till PC:n och vägen tillbaka, två telefoner), S2i, S4 med S4b (granskningen med
video, leder och passets mått) och S4c (flikarna Today, Progress och Me med
riktig data, fokus ur `Store.focus`, passets egen längd), S5 (PC-sidan och
skillen). TestFlight-vägen via GitHub är bevisad.

**Bygge:** TestFlight på morgonen med allt ovan (Johannes ja 2026-10-22).

**Väntar på Johannes:** telefonproven (T2, trimning och utsnitt, granskningen,
Send to PC och Import focus, två telefoner, flikarna och Me:s längd), S0 på
hemdatorn, märkta rutor ur riktiga klipp för S7.

**S6a landat (PC):** två paket → 3D med självkalibrering per uppställning,
vridningen och X-factor som trend utan markörer (B37–B39 prövas). Väntar på
riktiga pass med två telefoner och markörerna; i appen återstår lodlinjen i
manifestet (B39) och trendvyn (S6b).

## Idéer — inte planerade

Idéer som kräver fram och tillbaka med Johannes innan de blir etapper. En rad
per idé: vad, vad den kräver, och när den blir aktuell. En idé blir en etapp
först på Johannes beslut.

| Idé | Kräver | Aktuell när | Första steg |
|---|---|---|---|
| (3D-svingen är nu etapperna S6d och S6e, 2026-10-24) | | | |

## Utanför planen

Svingens faser ur en tränad modell (SwingNet, 71–76 % och CC BY-NC): klicket
och händerna räcker.

Den kinematiska sekvensen: bilden är för suddig i nedsvingen, och bandet ser
bara underarmen. Bladet, klubbans bana och bollflykten kräver en launch
monitor. WHOOP-bandet som källa för tempot ägs av Golf SG (HANDLED_PLAN), och
kopplas in här först om tempot ur videon inte räcker.
