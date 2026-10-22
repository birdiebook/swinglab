# SwingLab — plan (utkast 2026-10-22)

`BAND` S0 · S1 ✓ · S2 · S3 · S4 · S5 · S6 · S7 · S8

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
  toppen ≥ 0 grönt, −5…0 gult, under −5 cm rött; tempo 2,5–3,1. Samma fil
  läses av PC:n.
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

## S2i — Trimma och utsnitt (Johannes 2026-10-22, efter första telefonprovet)

Efter en import eller inspelning: videon med två handtag för start och slut
(originalfilen ändras aldrig, bara passets tidsfönster) och en ruta för
utsnittet som dras och nyps runt spelaren. Utsnittet gäller alla slag i
klippet: Vision letar bara inom rutan (`regionOfInterest`), så att spelaren blir
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
