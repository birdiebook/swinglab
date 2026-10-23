# SwingLab — plan (utkast 2026-10-22)

`BAND` S0 · S1 ✓ · S1b ✓ · S1c · S1d · S1e · S2 · S3 · S4 · S5 · S6 · S6c · S7 · S7a · S7b · S8

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
`katalog_3d.json` (bara PC:n, BESLUT B37), minnet bär trenden pass för pass och
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

**S6c-2, appen (annan gren):** lederna per slag förs över mellan telefonerna med
PhoneLink (följaren skickar sina slag till den styrande efter serien), 3D räknas på
telefonen med `TreD`, ett kort i passet visar talen, Progress visar "3D · no markers"
som trend utan gränser (B14, B37), och uppställningen visar om telefonen lutar (B39,
lodlinjen).

**Klart när:** S6c-1: TreDTests gröna i Actions mot Pythons tal och mot sanningen, och
tiden per pass uppmätt och skattad för telefonen (M50). S6c-2: ett pass med två telefoner
ger samma `tre_d` på telefonen som på PC:n inom M50:s tolerans.

## S7 — Klubban

Sportsbox-måtten som kräver S7 (club-hand gap, skaftets fart, wrist och release
factor, P2/P6/P8): [docs/research/4_sportsbox_matt.md](docs/research/4_sportsbox_matt.md).

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
P1–P10. DTL först i appen; FO i nästa steg, men datamodellen och formatet vyoberoende
redan nu. Greppet är skaftet mitt mellan händerna och klubbhuvudet hoseln (B44). P2, P6
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
`klubba-markera`, `klubba-markera-utan-finger`, `klubba-markera-ringen`, `klubba-passet`),
och paketprovet bär markeringar som PC:n läser (`test_appens_paket.py`). Mätversionen är
oförändrad (B47). Efter granskningen 2026-10-23: P2 mot planet borttaget (M47). **Kvar:**
telefonen (trycken, glaset, gränserna 3 %, 5 % och 4 pt, riktpinnen), och FO-läget i appen.

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
klubbmåtten tar i dag bara tryckta punkter. Inget av S7b är byggt.

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
| **3D-svingen** (2026-10-22): svingen i 3D som går att vrida och stega genom P1–P10, likt Sportsbox | S6:s triangulerade leder (en kamera ger en gissning, 10–16° per sving); formspråket B13: ett mätinstrument med leder, linjer, bäckenets och bröstets plan och X-factor som vinkel, ingen modellerad kropp | S6 ger 3D-leder från två telefoner | En skiss i webbläsaren på S6-simuleringens påhittade 3D-sving (`tools/pc/tre_d/sving.py`), för att bestämma utseendet |

## Utanför planen

Svingens faser ur en tränad modell (SwingNet, 71–76 % och CC BY-NC): klicket
och händerna räcker.

Den kinematiska sekvensen: bilden är för suddig i nedsvingen, och bandet ser
bara underarmen. Bladet, klubbans bana och bollflykten kräver en launch
monitor. WHOOP-bandet som källa för tempot ägs av Golf SG (HANDLED_PLAN), och
kopplas in här först om tempot ur videon inte räcker.
