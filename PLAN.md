# SwingLab — plan (utkast 2026-10-22)

`BAND` S0 · S1 · S2 · S3 · S4 · S5 · S6 · S7 · S8

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
kontrollerats (BESLUT B10).

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
  toppen ≥ 0 grönt, −5…0 gult, under −5 cm rött; höfterna öppna vid träffen
  35–45°; tempo 2,5–3,1. Samma fil läses av PC:n.
- **Sessionen**: median, spridning och trend per mått, och skillnaden mot förra
  passet.

**Klart när:** `swift test` är grönt, och Swift ger samma tal som Python på
samma påhittade leder (fixturer genererade av PC-verktyget, inga riktiga
svingar).

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

## S3 — Facit: Vision mot MediaPipe

PC:n kör MediaPipe heavy på samma klipp och jämför per led, fas och vy. Måtten
från S1 räknas på båda. Väntat ur researchen: MediaPipe är tydligt bättre i
2D (Googles mätning), och ingen modell är validerad för golf med en kamera.

**Klart när:** tabellen över skillnaden per mått finns, och beslutet är taget:
räcker Vision i telefonen, eller ska MediaPipe in i appen (BESLUT B5).

## S4 — Vyn

Sessionen som bild: din mediansving med skelettet över videon, de flaggade
felen med **Du nu / Mål**, och före och efter mot förra passet. Varje mått som
ett tal mot sitt gröna spann (som Sportsbox), inte en poäng, och ett mått per
bild i den vy där det hör hemma. Lite text,
bilden bär det. Fliken **Att jobba på** visar de 1–3 saker som PC:n och Claude
har valt (S5), med övningar och "klart när".

**Klart när:** Johannes har läst ett pass på telefonen på rangen.

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

Två iPhones filmar samtidigt (DTL och FO), synkade på klicket och finjusterade
på ledernas fart. Varje telefon kalibreras en gång mot ett ChArUco-mönster,
och varje pass mot minst 10 kända punkter på mattan (Pose2Sims metod,
BSD-3). Lederna trianguleras till 3D. Väntat fel 3–5°, men bara mätt på gång,
löpning och hopp. Det ger
bäckenets och bröstets vridning, X-factor, X-factor stretch och höfterna
öppna vid träffen. X-factor visas som egen trend, inte mot en gradgräns
(metoderna skiljer sig med cirka 16°), och stretchen före X-factor vid toppen,
eftersom den oftare hänger ihop med klubbfarten.

**Facit:** stå i adress och vrid axlarna mot markerade linjer på 0°, 45° och
90°.

**Klart när:** vridningen träffar facitlinjerna inom 5°, och X-factor står med
band i vyn.

## S7 — Klubban

En detektor för grepp, skaft och klubbhuvud, tränad på PC:n på egna rutor
(Claude hjälper till att märka) och körd i appen som Core ML. Det finns inget
färdigt att ta: GolfPose har eget EULA, ClubheadDB är CC BY-NC och bara DTL.
Punkterna följer GolfPose definition. Modellen är YOLO-pose eller en med
friare licens (Ultralytics är AGPL). Det ger casting
(vinkeln mellan vänsterarm och skaft i nedsvingen), svingplanet, across the
line och laid off, och skaftlutningen vid träffen.

**Klart när:** skaftets vinkel ligger inom 5° från handmärkta rutor i adress,
topp och tidig nedsving, i båda vyerna.

## S8 — Bollen vid adressen

Bollen hittas i adressbilden (FO) och ger bollens läge i stansen.

**Klart när:** läget stämmer med handmätt inom 2 cm på 10 slag.

## Utanför planen

Svingens faser ur en tränad modell (SwingNet, 71–76 % och CC BY-NC): klicket
och händerna räcker.

Den kinematiska sekvensen: bilden är för suddig i nedsvingen, och bandet ser
bara underarmen. Bladet, klubbans bana och bollflykten kräver en launch
monitor. WHOOP-bandet som källa för tempot ägs av Golf SG (HANDLED_PLAN), och
kopplas in här först om tempot ur videon inte räcker.
