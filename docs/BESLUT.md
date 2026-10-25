# Beslut och avvägningar (utkast 2026-10-22)

Varje beslut som formar bygget. Nytt beslut = ny rad i samma commit som koden.
Status: **gäller** · **prövas** · **väntar** (Johannes beslut).

## B1 — En egen app, inte en del av Birdiebook
*2026-10-22 · gäller · Johannes beslut*

- **Valt:** en egen iPhone-app med eget repo, som Idunn och Airtime.
- **Bortvalt:** att väcka HL6 i Golf SG, där video och svingmått är pausade
  (PLANER.md §4) och där spåren är fulla.
- **Följd:** i Golf SG stannar bandet (WHOOP) och autoslaget. Video-delen av
  HANDLED_PLAN HL6 får en rad med länk hit.

## B2 — Mätningen är mekanisk, Claude tolkar
*2026-10-22 · gäller*

- **Valt:** varje tal räknas av koden ur lederna, likadant varje gång. Claude
  väljer vad som är viktigast och skriver övningarna.
- **Varför:** ett mått som skattas av en språkmodell blir inte detsamma två
  gånger, och då går före/efter inte att lita på.

## B3 — Allt stannar på telefonen tills Johannes skickar det
*2026-10-22 · gäller*

- **Valt:** ingen server och inget moln. Sessionen lämnar telefonen bara som
  ett paket som Johannes delar (AirDrop, Filer eller iCloud Drive).
- **Kostnad:** PC-steget är en delning, inte automatiskt.

## B4 — Claude via Claude Code på PC:n, ingen API-nyckel i appen
*2026-10-22 · prövas*

- **Valt:** tolkningen körs i Claude Code (skillen `svinganalys`), och ryms i
  Claude-abonnemanget.
- **Bortvalt:** att anropa API:et från telefonen. Abonnemanget ger ingen
  API-nyckel; API:et faktureras för sig.
- **Omprövas:** om tolkningen behövs på rangen, utan PC.
- **Kompletteras av B52** (2026-10-23): tolkningen går också i Claude-appen på telefonen,
  med samma abonnemang och utan API-nyckel.

## B5 — Vision i 2D på telefonen, MediaPipe på PC:n för siffrorna
*2026-10-22 · prövas*

- **Valt:** Vision (kroppen i 2D) i appen för direkt återkoppling, utan
  beroenden. MediaPipe heavy på PC:n ger talen som sparas, som i oktober.
- **Bortvalt:** Vision 3D. Den saknar validering och antar en kroppslängd på
  1,8 m utan djupdata. 3D kommer i stället ur två kameror (S6).
- **Avgörs av:** facit i S3. Om Vision ligger nära MediaPipe räcker telefonen
  ensam.
- **Kostnad:** Vision kan inte provas på Linux. Det mäts på telefonen och
  jämförs på PC:n.

## B6 — Katalogen är data
*2026-10-22 · gäller*

- **Valt:** felen (vy, mått, gräns, övning) står i `katalog.json`, som läses av
  både appen och PC:n. Ett nytt fel är en ny rad, inte ny kod, så länge måttet
  finns.

## B7 — Repot är publikt
*2026-10-22 · gäller · Johannes beslut*

- **Valt:** publikt repo, som Airtime (B7, B9): TestFlight byggs gratis på
  GitHubs macOS-maskin, startas för hand efter Johannes ja. Ingen dagsgräns:
  "ett bygge om dagen" kom från Codemagics minuter (Johannes 2026-10-22).
- **Bortvalt:** privat repo, där bygget hade tagit av Codemagics 500 minuter,
  som delas med de andra apparna.
- **Kostnad:** koden syns. Repot bär aldrig en svingvideo, en mätning, en
  e-postadress eller en nyckel.
- **Bevisat 2026-10-22:** första bygget gick hela vägen till TestFlight via
  GitHubs macOS (run 39816379051), efter två fel som nu fångas tidigt: tomma
  hemligheter (`birdiebook` är ett personligt konto, så de är repository
  secrets) och en `.p8` som inte var hela filen.

## B8 — Namnet är SwingLab
*2026-10-22 · gäller · Johannes beslut*

- **Valt:** SwingLab. Hemskärmen visar "SwingLab"; i App Store Connect, där
  namnet måste vara unikt, "SwingLab - Golf Swing Analysis" (med vanligt
  bindestreck; formen med tankstreck och kortare former var tagna,
  2026-10-22). Bundle-id `se.birdiebook.swinglab`, paketet `SwingLabKit`, repot
  `birdiebook/swinglab`.
- **Bortvalt:** Sving (arbetsnamnet), Coil, Positions, Swingframe.

## B9 — Två iPhones filmar samtidigt
*2026-10-22 · gäller · Johannes har en andra telefon*

- **Valt:** S6 bygger på två telefoner (DTL och FO), synkade på klicket.
- **Varför:** ur en kamera gav vridningen 55–99° för samma sving (Golf SG,
  HANDLED_PLAN §4). X-factor kräver två vyer.

## B10 — En gräns kontrolleras i original innan den blir kod
*2026-10-22 · gäller*

- **Valt:** researchens siffror kom ur sökmotorns sammanfattningar, eftersom
  molnmiljön nekade källsidorna. En gräns i `katalog.json` får status och
  källa först när källan lästs i original.
- **Kostnad:** katalogen börjar med egen baslinje för de flesta mått.
- **Läget 2026-10-23:** research 5 läste källorna i original på hemdatorn
  (`docs/research/5_matt_i_original.md`, 5a–5d). Katalogens `kontrollerad` följer
  det, och gränserna som det gav står i B45.

## B11 — Inspelningen sker i appen
*2026-10-22 · gäller*

- **Valt:** appen spelar in med låst slutartid (1/2000 s eller kortare).
  Import ur Bilder finns kvar för gamla klipp.
- **Varför:** oskärpan är fart × exponeringstid (45 mm för klubbhuvudet vid
  1/1000 s). Kamera-appen låser inte slutartiden.

## B12 — Python är facit för Swift, med påhittade svingar som Swift-källa
*2026-10-22 · gäller*

- **Valt:** måtten skrivs två gånger, i `tools/pc/` (Python med numpy) och i
  `SwingLabKit/` (Swift med bara Foundation), med samma definitioner (METOD
  M1–M27). `tools/pc/generera.py --swift` bygger påhittade svingar, räknar dem i
  Python och skriver indata och Pythons tal som JSON-strängar i
  `SwingLabKit/Tests/SwingTests/Fixturer.swift`. Swift-testerna kräver samma tal
  inom 0,05. Ett Python-test fäller fixturerna när de inte längre är Pythons tal.
- **Varför:** Swift kan inte köras utan Mac eller CI, Python kan. De påhittade
  svingarna har kända förflyttningar (bäckenet −6 cm vid toppen ger −6,0), så
  Python provas mot facit lokalt och Swift mot Python i Actions.
- **Varför Swift-källa, inte resurser:** en resursfil kräver `Bundle.module`,
  som har strulat på Linux; en strängliteral fungerar överallt (som Idunns
  `Fixtures.swift`).
- **Bortvalt:** en gemensam kärna (C eller Python i appen): fler beroenden i
  appen och ingen vinst så länge måtten är få och enkla.
- **Kostnad:** två implementationer att hålla i takt; fixturfilen är ≈ 1 MB.
- **Omprövas:** om måtten växer så att dubbelskrivningen kostar mer än den ger.

## B13 — Formspråket: svart och vitt, datan bär, ingen figur
*2026-10-22 · gäller · Johannes beslut, efter den klickbara skissen*

- **Valt:** reglerna 1–9 och paletten i `design/README.md`: ett analysverktyg,
  inte en konsumentapp; ingen figur, bara uppmätta linjer över videon; ett mått
  är namn, tal, enhet och spannet; inga värdeord och ingen totalpoäng; ingen
  beskrivande text; svart, vitt och gråskala med en dämpad signalfärg bara för
  varningar; system-ui med tabellsiffror; primärknappen vit med svart text.
- **Bortvalt:** Airtimes volt och piktogram, en svingande figur ("ser ut som
  billig AI"), bättre/sämre-ord och förklarande text.
- **Regeln:** kräver en skärm en förklaring är designen fel. Gör om den i
  stället för att lägga till text.
- **Undantag (B87, 2026-10-25):** läget mot bandet har tre färger, grönt, gult och rött,
  som en prick, en ring och en pil bredvid talet och på spannet. Inga värdeord ändå.

## B14 — Vridningen i två lägen: trend utan markörer, per sving med markörer
*2026-10-22 · gäller · Johannes beslut efter felbudgeten (docs/S6_FELBUDGET.md)*

- **Valt:** utan markörer visas vridningen och X-factor bara som trend per pass
  (median över minst 10 slag). Med en pinne i bältet och en stav över ryggen
  visas de per sving. Appen märker vilket läge talet kommer från.
- **Varför:** simuleringen visar att posemodellens 2D-fel styr, inte kamerorna:
  cirka 10–16° per sving utan markörer, 0,5–1,5° med. Kalibrering, synk,
  tappade rutor och slutartid bidrar under 1–3°.
- **Bortvalt:** bara utan markörer (X-factor per sving blir brus), bara med
  markörer (utrustning varje pass).
- **Omprövas:** när S3 har mätt posemodellens verkliga 2D-fel på golf; ligger
  det på ≤3 px vid 3 m kan läget utan markörer ge mer än trend.

---

Besluten B15–B29 kommer ur S2:s förslag F1–F15 ([S2_SPEC.md](S2_SPEC.md)), i
samma ordning (Fn blev B(n+14)). B20 och B21 har Johannes ja. B16 (slutartiden)
och B26 (originalen) **väntar** på Johannes. Övriga är tekniska val som
arkitekten gjort; de **prövas** och omprövas efter telefonproven (S2_SPEC §11.3).

## B15 — Inspelningen med `AVCaptureMovieFileOutput`
*2026-10-22 · prövas · S2_SPEC §2.1 · S2:s förslag F1*

- **Valt:** `AVCaptureMovieFileOutput` skriver video och ljud i samma fil.
  Rutornas tider läses ur filen efteråt, och hålen räknas (`FrameTiming`).
  Filens starttid på telefonens klocka kommer från delegaten med `startPTS`
  (iOS 18.2).
- **Bortvalt:** `AVAssetWriter` med egna data-utgångar. Den visar varför en ruta
  tappas och kan skriva okomprimerat ljud, men kräver ett par hundra rader egen
  kodning och sammanflätning i 240 bilder/s. Ett fel där (ljudet förskjutet mot
  bilden) syns inte i simulatorn.
- **Kostnad:** utgången säger inte till när en ruta tappas. Inspelningens
  kodek och ljudformat blir telefonens standard (troligen HEVC och AAC).
- **Omprövas:** om inspelningarna tappar mer än 1 % av rutorna, och efter
  telefonproven (S2_SPEC §11.3) i den etapp som bygger det.

## B16 — Exponeringen mäts med auto och låses på 1/2000 s
*2026-10-22 · väntar (Johannes: slutartiden, S2_SPEC §13.3) · S2_SPEC §2.3–2.4 · S2:s förslag F2*

- **Valt:** autoexponeringen får taket 1/2000 s (`activeMaxExposureDuration`) och
  mäter ljuset. Sedan låses tid och ISO med `setExposureModeCustom`, med talen
  ur SwingLabKit som aldrig lämnar formatets gränser. Fokus låses efter en
  sökning i mitten, vitbalansen låses på det auto valt, stabiliseringen är av,
  HDR av och zoomen 1,0.
- **Bortvalt:** auto under hela inspelningen (exponeringen och färgen vandrar
  mellan slagen, och autofokus kan söka i nedsvingen). Stabilisering (beskär och
  flyttar varje ruta olika, vilket stör lederna och S6:s kalibrering).
- **Kostnad:** ett ljus som ändras under passet (moln utomhus) rättas inte.
  Ljusprovet görs om vid behov.
- **Väntar:** 1/2000 s (BESLUT B11) eller kortare; 1/4000 s halverar oskärpan
  men kräver dubbelt ljus. Johannes beslut.
- **Byggt i S2c:** slutartiden står på ett ställe, `Exposure.targetDuration`
  (SwingLabKit). Både autoexponeringens tak och det låsta läget räknas ur den
  (`Exposure.lockedDuration`), så Johannes svar är en rad.
- **Omprövas:** efter telefonproven (S2_SPEC §11.3) i den etapp som bygger det.

## B17 — Formatet väljs i SwingLabKit
*2026-10-22 · prövas · S2_SPEC §2.2 · METOD MS1 · S2:s förslag F3*

- **Valt:** exakt 1920 × 1080 och 240 bilder/s; bland dem störst synfält,
  sedan binnat (mer ljuskänsligt), sedan 8-bitars. Annars bästa 1080p ≥ 120,
  märkt i gult. Hela formatlistan sparas i paketet (`enhet.json`). Bildtiden
  sätts med intervallets egen `minFrameDuration`.
- **Bortvalt:** Airtimes regel (högsta frekvens, sedan största bild), som inte
  ser synfältet, och `CMTime(value: 1, timescale: 240)`, som kraschar om talet
  inte finns exakt i formatets intervall.
- **Omprövas:** efter telefonproven (S2_SPEC §11.3) i den etapp som bygger det.

## B18 — Ljusprovet före passet
*2026-10-22 · prövas · S2_SPEC §2.7 · METOD MS2, MS3 · S2:s förslag F4*

- **Valt:** en knapp som på 3 s ger ISO-behovet vid 1/2000 s (som "för mörkt:
  1,3 steg"), flimret vid 100 Hz och andelen tappade rutor ur en provfilm på 2 s.
  Resultatet följer med paketet.
- **Varför:** 1/2000 s kräver i storleksordningen 700–1 400 lux på golfaren vid
  ISO 1000–2000 (egen räkning), mer än en vanlig hall. Det ska synas före passet,
  inte i lederna efteråt.
- **Kostnad:** gränserna (3/10 % flimmer, 1/5 % tappade rutor) är antaganden
  tills de första passen kalibrerat dem.
- **Omprövas:** efter telefonproven (S2_SPEC §11.3) i den etapp som bygger det.

## B19 — Lägsta iOS är 18.2
*2026-10-22 · prövas · S2_SPEC §2.1, §13 · S2:s förslag F5*

- **Valt:** `deploymentTarget` 18.2, för delegaten med `startPTS` (filens första
  ruta på sessionens klocka), som behövs för att två telefoner ska kunna
  jämföras före klicken.
- **Bortvalt:** iOS 26 (bakgrundsjobb med `BGContinuedProcessingTaskRequest`,
  nyare Network-API), som kräver att båda telefonerna kan köra iOS 26. iOS 17
  som Airtime, som saknar `startPTS`.
- **Telefonerna** är kända (S2_SPEC §13): iPhone 17 och iPhone 13, båda med
  iOS 18.2 eller senare.
- **Omprövas:** om en av telefonerna inte kan köra 18.2, eller om iOS 26 behövs.

## B20 — Appen kompileras och provas i simulatorn på GitHubs macOS, gratis
*2026-10-22 · gäller · Johannes ja · S2_SPEC §10.2 · S2:s förslag F6*

- **Valt:** `kompilera.yml` bygger appen för simulatorn som TestFlight gör
  (Release, utan signering) och kör simulatorprovet vid varje push som rör
  `App/`, `Prov/`, `SwingLabKit/` eller `project.yml`. Provet skriver en egen
  film med kända klick och tappade rutor och kör appens egen läsning, klickjakt,
  klippexport, Vision-anrop och paketering på den. TestFlight startas bara när
  `kompilera` är grönt för samma commit.
- **Varför:** utan Mac kompileras App-koden annars först i TestFlight-bygget, och
  ett fel kostar en dag. Repot är publikt (BESLUT B7), så macOS-maskinen kostar
  inget.
- **Bortvalt:** att läsa igenom App-ändringar extra noga och hoppas (Airtimes
  väg). Simulatorprov i Codemagic (kostar minuter som delas med de andra apparna).
- **Kostnad:** 10–20 min väntan per push som rör appen. Avviker från
  arbetssättets "prov i simulator bara när sparad data rörs", vars skäl var
  minuterna. Håller det skrivs läxan i `birdiebook/arbetssatt`.
- **Byggt i S2a:** `.github/workflows/kompilera.yml` och målet `SwingLabProv`.
  Resultatet läses på grenen `ci-resultat` (`resultat/<sha>.kompilera.txt`),
  och `testflight.yml` vägrar en commit som inte är grön där.

## B21 — Två telefoner kopplas med Network.framework
*2026-10-22 · gäller · Johannes ja · S2_SPEC §7.1 · S2:s förslag F7*

- **Valt:** `NWListener`, `NWBrowser` och `NWConnection` över TCP med Bonjour
  (`_swinglab._tcp`), peer-to-peer påslaget och Nagle avstängt. Meddelandena är
  JSON med längd före, i SwingLabKit. En telefon styr, övriga följer (fler än en
  följare går).
- **Bortvalt:** Multipeer Connectivity, avskrivet i iOS 27 ("Use Network
  Framework instead"). Det nya `NetworkConnection`-API:t, som kräver iOS 26.
- **Kostnad:** frågan om lokalt nätverk visas första gången; nekas den fungerar
  inte kopplingen (men inspelningen gör det).
- **När:** redan i S2 (etapp S2g), inte i S6 (Johannes 2026-10-22).
- **Byggt i S2g:** `Link.swift` och `LinkSession.swift` i SwingLabKit (meddelandena,
  `Wire`, `LinkLeader`, `LinkFollower`, `PairEntry`), prövade på Linux med ett nät i
  minnet som dras ur; `App/Link.swift` med `NWListener`, `NWBrowser` och
  `NWConnection`, prövat i simulatorn över loopback utan Bonjour. Rollen väljs i
  uppställningen (`roll`: ensam, styr, följ) och sparas i `pass.json`. Meddelandena
  är specens, med `hello` och `recorded` som egna typer och en kvittens (`ack`) för
  start, stopp och serien (docs/FORMAT.md "Två telefoner"). Följaren binder sig till
  den styrande vars hello den hört och prövar annars tjänsterna i tur, så att två par i
  samma rum inte korsas. Den styrande kör också en sökare, bara för att se om lokalt
  nätverk är nekat.

## B22 — Klicket är synken, pingen bara ett förhandsvärde
*2026-10-22 · prövas · S2_SPEC §7.2–7.4 · METOD MS6, MS9, MS10 · S2:s förslag F8*

- **Valt:** varje telefon spelar in och hittar sina klick själv. Klicken paras
  mellan telefonerna med Golf SG:s `para()` (förskjutningen som parar flest inom
  30 ms). Pingen (NTP-formeln) smalnar bara sökningen. Ljudets väg rättas med
  avståndet till bollen (`d/343`). Kopplingen bär aldrig video.
- **Varför:** ett tapp i kopplingen kostar då ingen data; utan koppling kan PC:n
  para med samma algoritm.
- **Kostnad:** varje telefon måste höra klicket. Finjusteringen på ledernas fart
  görs på PC:n (S6).
- **Byggt i S2g:** ett tapp förlorar inget. Följaren skickar sin serie tills den
  kvitterats, och den styrande skickar kommandot som gäller (start eller stopp) igen
  när följaren säger hello; ett start för en serie som redan startats görs inte om
  (följaren kan ha stoppats för hand). Följaren tar den styrandes pass-id när dess
  eget pass är tomt, så att båda paketen bär samma id; ett pass med serier byter
  aldrig id. Den styrande skriver `par.json` i sitt pass. Parningen bor inte bara i
  minnet: följarens serie sparas i den styrandes `foljare.json` innan den kvitteras,
  serien bär den styrandes pass-id (en serie från ett annat pass tas inte emot), och
  när kameran öppnas igen läses passets egna serier och följarnas, så att en parning
  som inte hann bli klar görs då. Etiketten på den styrande visar senaste parningen
  per följare (antal par · median |rest|, osäker i signalfärgen).
- **Omprövas:** efter telefonproven (S2_SPEC §11.3) i den etapp som bygger det.

## B23 — Klickjakten är Golf SG:s, plus en svingkontroll
*2026-10-22 · prövas · S2_SPEC §4 · METOD MS4, MS5 · S2:s förslag F9*

- **Valt:** `handled_video.klick` portad ordagrant till Swift, körd i bitar om
  30 s (minnet), med en paritetsfixtur mot Python. Ett klick blir ett slag först
  när glesa leder kring klicket visar händerna högt före och snabba vid klicket.
  Johannes kan ändra domen.
- **Varför:** Golf SG hittade 41 av 41 klick, men där valde bandet ut klicken.
  På en range finns grannens klick och röster.
- **Kostnad:** svingkontrollens gränser är antaganden tills oktobers 41 slag
  prövat dem (S2e).
- **Omprövas:** efter telefonproven (S2_SPEC §11.3) i den etapp som bygger det.

## B24 — Import ur Bilder hämtar originalresursen
*2026-10-22 · prövas · S2_SPEC §5 · S2:s förslag F10*

- **Valt:** `PhotosPicker` med bibliotek ger id:t; `PHAssetResource` av typen
  `.video` (originalet) skrivs till appen med `PHAssetResourceManager`.
  `FrameTiming` vägrar en fil som inte har ett rutnät på minst 100 bilder/s.
- **Bortvalt:** `loadTransferable` med `.current` som enda väg (Airtime). Om den
  ger originalet för en slowmotion är inte dokumenterat. Den finns kvar som
  reserv vid begränsad åtkomst, bakom samma kontroll.
- **Kostnad:** appen ber om full åtkomst till Bilder.
- **Omprövas:** efter telefonproven (S2_SPEC §11.3) i den etapp som bygger det.

## B25 — Vision på varje ruta, i förgrunden, återupptagbart
*2026-10-22 · prövas · S2_SPEC §6 · S2:s förslag F11*

- **Valt:** `VNDetectHumanBodyPoseRequest` på varje ruta ur `AVAssetReader` i
  `[klick − 2,5, klick + 1,5]` s, med rutans egen tid och EXIF-orienteringen ur
  spårets transform. Analysen går med skärmen på, och varje slag sparas när det
  är klart.
- **Bortvalt:** `DetectHumanBodyPoseRequest` (iOS 18, nyare Swift-API, mindre
  beprövat att kompilera blint). `AVAssetImageGenerator` per ruta (avkodar från
  nyckelbilden varje gång). En videokomposition som vrider rutorna (lägger
  rutorna på ett fast rutnät och tappar de verkliga tiderna).
  `BGContinuedProcessingTaskRequest` (iOS 26).
- **Kostnad:** telefonen ligger framme med skärmen på under analysen, uppskattat
  8–12 min för 30 slag (mäts i S2e).
- **Omprövas:** efter telefonproven (S2_SPEC §11.3) i den etapp som bygger det.

## B26 — Lagringen
*2026-10-22 · väntar (Johannes: originalen, S2_SPEC §13.5) · S2_SPEC §8.1 · S2:s förslag F12*

- **Valt:** allt i Application Support per pass; video och klipp utanför
  iCloud-backupen; exporten i `Documents/Export`, synlig i Filer och i Apple
  Devices över kabel.
- **Väntar:** behålla hela serierna eller "Spara bara klippen" efter export.
- **Byggt i S2c:** båda går. `AppSettings.keepOriginals` (standard `true`,
  behåll) i `installningar.json`, och `Store.releaseOriginals` tar bort
  seriernas original bara när den är `false` och passet är exporterat (S2f);
  provat i simulatorprovet.
- **Omprövas:** efter telefonproven (S2_SPEC §11.3) i den etapp som bygger det.

## B27 — Paketet är en okomprimerad zip per telefon och pass
*2026-10-22 · prövas · S2_SPEC §8.3–8.4 · S2:s förslag F13*

- **Valt:** `swinglab-<pass>-<vy>.zip` med `manifest.json` (`swinglab-paket/1`),
  ett JSON per slag med lederna, och klippen (valbart). Zip-skrivaren strömmar
  till disk och lagrar utan komprimering, likadant på Linux och telefonen.
  Klippen kodas inte om, och klicket mäts om i varje klipp.
- **Bortvalt:** Idunns zip i minnet (paketet blir hundratals MB). En mapp i
  stället för zip (AirDrop och iCloud Drive till Windows hanterar en fil
  enklare). Ett gemensamt paket från båda telefonerna (videon skulle behöva gå
  över kopplingen).
- **Kostnad:** ingen zip64: högst 4 GB per paket.
- **Byggt i S2f:** `ZipWriter`, `ZipCatalog` och `PassPackage`/`PackageManifest` i
  SwingLabKit (`Capture`, provade på Linux), `App/Export.swift` med "Send to PC" i
  passet (med eller utan klipp) och delningsbladet. Bara slag med leder kommer med (PC:n
  kräver `leder`), och klippets längd följer med (METOD MS12). `par.json` följer med när
  den finns i passets mapp (S2g, provat med S2g:s egen `Store.savePair`), `telefon.roll` är
  passets roll (`PassSetup.role`), och ett slag märkt "Detection wrong" (BESLUT B35) bär
  `detection_wrong`, som PC:n inte mäter (METOD MT1).
  Gränserna är 0xFFFE filer och 0xFFFF_FFFE byte (fältens största värde betyder zip64 för
  en läsare). Zippen skrivs som `.part` i appens Caches och byter plats med paketet i
  Export först när den är hel; gamla `.part` tas bort när appen startar. Varje bit om
  1 MB läses i en egen autoreleasepool; minnets topp med ett klipp på 400 MB mäts i
  simulatorprovet (`testMinnetMedEttStortKlipp`). Analyze, domen och redigeraren väntar
  medan paketet skrivs, och passet läses om innan statusen "exporterat" sparas.
- **Kontraktet bevisas med appens egna byte:** simulatorprovet (`SwingLabProvPaket`)
  packar ett påhittat pass med appens Export, riktiga passthrough-klipp och leder ur
  SwingDemo:s påhittade sving, och kompilera.yml låter PC:ns `paket.py` och `session.py`
  läsa paketen (`tools/tests/test_appens_paket.py`); PC:ns mått ska vara Swifts på samma
  byte (BESLUT B12). Bortvalt: en Swift-fixtur som skriver paketet på Linux och ett
  Python-test som läser den. Det prövar SwingLabKit men inte appens väg (iOS Foundation,
  klippen ur AVFoundation, Store och Export), och de två jobben i test.yml delar inga
  filer. Flödet körs också när `tools/pc/` ändras, så att båda sidor prövas mot varandra.
- **Omprövas:** efter telefonproven (S2_SPEC §11.3) i den etapp som bygger det.

## B28 — Vägen tillbaka via Filer
*2026-10-22 · prövas · S2_SPEC §8.5 · S2:s förslag F14*

- **Valt:** "Hämta Att jobba på" öppnar `fileImporter` för en JSON-fil, som
  kopieras in. S5 bestämmer innehållet.
- **Bortvalt (till S5):** "Öppna i SwingLab" direkt ur delningsbladet, som
  kräver en egen filtyp i Info.plist.
- **Byggt i S2f:** "Import focus" i startvyn öppnar `fileImporter` (JSON); filen
  kontrolleras av SwingLabKit (`FocusInbox.accept`: formatet, 1–3 saker, stegen och att
  `pass` är ett pass-id) och sparas som `AttJobbaPa/att_jobba_pa-<pass>.json`;
  `Store.focus` är den senaste, för vyerna i S4c. En fil som inte går igenom sparas inte.
  Storleken (högst 1 MB) kontrolleras innan filen läses hel.
- **Vem kontrollerar vad:** telefonen kontrollerar formen. Textens regler (engelska, inga
  värdeord, siffror eller utropstecken i fritext, BESLUT B30, METOD MT8) och talen mot
  analysen kontrolleras av PC:ns `tools/pc/att_jobba_pa.py` innan filen skickas; telefonen
  gör inte om den kontrollen.
- **Omprövas:** efter telefonproven (S2_SPEC §11.3) i den etapp som bygger det.

## B29 — Lederna heter som i Golf SG och har MediaPipes index
*2026-10-22 · prövas · S2_SPEC §6.3 · S2:s förslag F15*

- **Valt:** 13 leder (näsa, axlar, armbågar, handleder, höfter, knän,
  fotleder) med Golf SG:s namn (`nasa`, `axel_v`, …) och MediaPipes index (0,
  11–16, 23–28). Vänster är personens vänster i både Vision och MediaPipe.
  Pixlar i den upprätta bilden med origo uppe till vänster, som Golf SG:s
  `bild`.
- **Varför:** S3 jämför Vision mot MediaPipe led för led, och PC-sidan läser
  oktobers MediaPipe-leder i samma form.
- **Om S1:s `docs/FORMAT.md` säger annat** vinner FORMAT.md, och den här raden
  skrivs om.
- **Omprövas:** efter telefonproven (S2_SPEC §11.3) i den etapp som bygger det.

## B30 — Appen är på engelska
*2026-10-22 · gäller · Johannes beslut*

- **Valt:** allt som syns i appen är engelska: vyerna, kvittot, ljusprovet,
  felmeddelandena, måttens namn och katalogens övningar och tankar. Det som
  kommer från PC:n (`att_jobba_pa.json`, skillen `svinganalys`) skrivs också på
  engelska, och kontrollen av värdeord får en engelsk lista. Tal och datum
  skrivs på engelskt sätt ("−2.4 cm", "Jan 9"). Texterna samlas i en String
  Catalog med engelska som grundspråk, så att fler språk kan läggas till utan
  ombyggnad.
- **Behålls på svenska:** kod, kommentarer, planer, beslut och metod i repot,
  som i de andra apparna.
- **Genomfört** 2026-10-22 (grenen `engelska`): vyerna, kvittot, ljusprovet,
  uppställningen, felen, frågorna om tillåtelse, katalogens och kedjornas fält som
  visas (`namn`, `ovning`, `tanke`, fysiska test) och skillens text till appen.
  Golfens engelska termer (sway, early extension, loss of posture, reverse spine,
  chicken wing, flying elbow, over the top, lead/trail). Id:n och nycklar är
  kontrakt och oförändrade. Hur texterna bor: B33.

## B31 — Accenten: isblått för det du övar på
*2026-10-22 · gäller · Johannes beslut, efter skissen*

- **Valt:** en enda accent, isblå `#6FD3F7` (kontrast 12,3 : 1 mot `#000`,
  tydligt skild från varningens `#B98A4A`). Den betyder bara "det du övar på":
  måttet eller måtten i Att jobba på bär den i sitt kort i Passet, sin rad på
  Idag, sin linje i Utveckling, sin uppmätta linje i Granskningen och i kedjan.
  Allt annat är gråskala. Bara tunna linjer, markören och en etikett, aldrig
  ytor, knappar eller bakgrunder, och aldrig som dom över bra eller dåligt.
  Reglerna står i `design/README.md` (regel 10).
- **Bortvalt:** ingen accent alls, accenten för nuvärdet (markören i varje
  spann, tidslinjen och linjerna över videon), elektriskt blått och
  signalorange.

## B32 — Granskningen: video med P-positioner och måtten per position
*2026-10-22 · gäller · Johannes beslut*

- **Valt:** golfens P-positioner som går att mäta ur kroppens leder: P1 Adress,
  P3 (vänsterarm vågrät upp), P4 Topp, P5 (vänsterarm vågrät ned), P7 Träff,
  P9 (högerarm vågrät) och P10 Finish. Ett tryck hoppar videon dit och visar
  bara den positionens mått. Kopplingen mått → positioner står i
  `katalog.json`.
- **Mätningen:** METOD M28 (P3, P5 och P9 ur armarnas vinkel mot vågrätt) och
  M29 (måtten vid positionerna); kopplingen står i katalogens `positioner` och
  listan `matt` (docs/FORMAT.md), samma i Python och Swift (BESLUT B12).
- **Senare:** P2, P6 och P8 definieras av klubbskaftet och kommer med S7.
- **Bortvalt:** bara faserna adress, topp, träff och finish (för grovt för
  analysen), och alla tio positioner redan nu (tre kräver klubban).

## B33 — Texterna: String Catalog i appen, en textfil i SwingLabKit
*2026-10-22 · gäller · genomförandet av B30*

- **Valt:** två källor, var och en för sin sida.
  - **App/** har `App/Localizable.xcstrings` med engelska som grundspråk
    (`developmentLanguage: en` i `project.yml`). Varje text i App/ går genom den:
    `Text("…")`, `Button("…")` och `String(localized: "…")`; tal och SwingLabKits
    färdiga texter visas med `Text(verbatim:)`.
  - **SwingLabKit** har en enda fil med ord till användaren,
    `Swing/Visning/Texter.swift` (engelska strängar och små funktioner som
    `Texter.mot("+1.2 cm", "Jan 6")`). Vymodellerna, kvittot, ljusprovet och felen
    när telefonen läser `att_jobba_pa.json` bygger sina texter därifrån. Talen
    formateras för hand (`Tal`, `Taltext`): decimalpunkt, äkta minus (−), "Jan 9",
    samma decimaler som PC:n (Avrundning).
- **Varför inte nycklar i SwingLabKit som App/ slår upp:** VisningTests på Linux
  prövar den färdiga texten ("+1.2 cm vs Jan 6", VoiceOver-raderna), och Linux har
  ingen String Catalog och inget `Bundle.module` i paketet (BESLUT B12: fixturerna
  är Swift-källa, inga resurser). Med nycklar hade texten bara gått att se i
  simulatorn. Varför inte `String(localized:)` i paketet: samma skäl, och
  telefonens språk får inte ändra hur ett tal skrivs.
- **Kostnad:** ett nytt språk kräver två ändringar: en kolumn i String Catalog och
  en tabell i `Texter` (t.ex. ett språkval där). Det är litet så länge texterna
  bor i den enda filen.
- **Hålls av prov:** `tools/tests/test_engelska.py` fäller å, ä och ö i String
  Catalog, i strängarna i App/ och i `Texter.swift`, kräver att varje text i App/
  står i katalogen och att varje rad där används. VisningTests fäller å, ä och ö
  (och decimalkomma) i allt vymodellerna räknar fram på de påhittade passen, och
  simulatorprovet (`testEngelskaTexter`) i det som kom med i appen.
- **Behålls på svenska:** kod, kommentarer och dokument (B30), och de fel som bara
  utvecklaren ser (formatet för en sving och katalogens kontroll, samma som
  Pythons). `notering` och `om` i katalogen och kedjorna är dokumentation.
- **Omprövas:** när ett andra språk ska in.

## B34 — Trimma och utsnitt: icke-destruktivt, Vision på den utskurna rutan
*2026-10-22 · prövas · PLAN.md S2i · Johannes efter första telefonprovet*

- **Valt:** redigeraren efter importen eller inspelningen (och från passet för en
  serie) sparar per serie ett tidsfönster och ett utsnitt i `pass.json`; originalet
  rörs aldrig. Klick utanför fönstret blir inga slag. Appen skär ut rutan ur varje
  ruta (upprätt, Core Image) och ger Vision bara den, och lederna förs tillbaka till
  hela bildens pixlar, så att måtten inte ändras (METOD MS13). Paketet bär fönstret
  och utsnittet per serie.
- **Bortvalt:** `regionOfInterest` på frågan. Apples dokumentation avgör inte om
  kroppens punkter då är relativa rutan eller hela bilden, och felet hade bara synts
  på telefonen; med den utskurna bilden är punkterna normaliserade mot bilden Vision
  fick, vilket är dokumenterat (WWDC20 10653) och prövat i simulatorn med en markör.
  Att skriva en trimmad och beskuren kopia av filen (kodar om slowmotion-originalet,
  dubblar lagringen och tappar rutornas egna tider). Ett utsnitt per slag (Johannes
  ställer sig på samma plats i en serie).
- **Kostnad:** en `CIImage` per ruta med utsnitt (ingen kopia av bufferten förrän
  Vision renderar den); tiden per ruta mäts på telefonen (`msPerFrame`, MS12).
- **Omprövas:** efter telefonprovet av S2i, och i S3 om MediaPipe på samma ruta
  skiljer mer än utan ruta.

## B35 — Granskningen med riktig video, och "Detection wrong"
*2026-10-22 · prövas · PLAN.md S4 (S4b) · Johannes efter telefonprovet med S2e+S2i*

- **Valt:** ett tryck på ett slag i passet öppnar granskningen: seriens video i
  `AVPlayer` med utsnittet (S2i), spela/pausa i 1/8 fart och stega ruta för ruta, med
  alla 13 leder och linjerna mellan dem ovanpå som Vision gav dem (METOD MS15), en
  växel som döljer dem, positionsraden P1–P10 och slagets mått vid positionen. En meny
  märker slaget **"Detection wrong"**: det sparas i `pass.json`, slaget räknas inte i
  passets mått, och det går att ångra. Efter Analyze visar passet måtten överst
  (S4:s `PassetVy` med riktig data) och slagen under, med vägen till varje slags
  granskning (METOD MS14).
- **Varför:** Johannes första prov (S2e+S2i) gav "1 Swing" och en miniatyr, men inget
  sätt att se om Vision hittat rätt leder, och inget resultat. Lederna ska gå att
  kontrollera innan måtten tas på allvar.
- **Bortvalt:** att avkoda rutorna själv till bilder (minnet: 960 rutor per slag), en
  bild ur `AVAssetImageGenerator` per steg (avkodar från nyckelbilden varje gång), och
  de utjämnade lederna i överlägget (döljer Visions fel). Att ta bort slaget helt (då
  går märkningen inte att ångra, och paketet tappar slaget). Klubban visas inte (S7).
- **Kostnad:** `AVPlayerLayer` syns inte i simulatorns bilder; provet ritar ytan med
  rutan ur filen i stället, med samma koordinater, så att spelarens lager bara prövas
  på telefonen.
- **Omprövas:** efter telefonprovet av S4b.

## B36 — Flikarna med riktig data: Today, Progress och Me
*2026-10-22 · flikarna ersatta av B64 (2026-10-24); passets längd, paketets längd och fokus gäller · PLAN.md S4 (S4c)*

- **Valt:** appen öppnar i tre flikar som skissen (design/README.md, öppet val 1: tre
  flikar, passet som eget flöde). **Today:** dagen, Start session, Import from Photos,
  det senaste passet med måtten i korthet (ett tryck öppnar passet) och Focus: de 1–3
  sakerna ur den senaste `att_jobba_pa.json` med tanken och kedjan (ett tryck öppnar Att
  jobba på). **Progress:** ett mått i taget över passen med samma klubba och längd
  (median, spridning, serie 1, gränsen eller baslinjen, blocken), det som övas först.
  **Me:** längden, spelhanden och klubborna, som är standarden för nya pass, och Sessions
  med passen, "Import from Photos" och "Import focus" (startvyns form). Accenten (B31)
  följer den senaste filen. Reglerna för vilka pass som visas: METOD MS16.
- **Passet behåller sin längd:** längden flyttar till Me och skrivs in i varje nytt pass;
  passets rad ändrar bara passet (METOD MS16). Förut ändrade passets rad Johannes längd
  och mätte om alla pass. Ett omätt pass från före S4c tar Me:s längd när det läses.
- **En källa för fokus:** Today, Att jobba på och accenten (Passet, Progress,
  granskningen) läser `Store.focus` från S2f:s "Import focus"; bara Progress block läser
  alla filer i `AttJobbaPa/` (`FocusInbox.readAll`), utanför huvudtråden.
- **Paketet bär passets längd** (`spelarens_langd_m`), så att PC:n mäter med samma skala
  (BESLUT B12).
- **Bortvalt:** en fjärde flik för passen (skissens öppna val 1), Utveckling över alla
  klubbor (en driver och ett 7-järn är inte samma sving), och att mäta om tidigare pass
  med en annan längd för jämförelsen (då visar passet andra tal än sina egna).
- **Kostnad:** Sessions är startvyn i ett blad: "New session" står där och på Today.
  Utveckling visar bara den senaste klubban.
- **Omprövas:** efter telefonprovet av S4c.

## B64 — Två flikar: Sessions och Me; sessionen visar bara sin vy
*2026-10-24 · prövas · Johannes beställning · PLAN.md S4e · METOD MS20 · VISION.md*

Ersätter B36:s flikar. Johannes 2026-10-24: "navigeringen är för svår och ska förenklas".
VISION.md (samma dag): enkelhet för användaren utan att offra djupet, och djupet ett tryck
bort i stället för borttaget.

- **Valt: en TabView med två flikar, Sessions och Me.** Sessions är förstasidan: alla pass på
  telefonen, senaste först. Raden säger vyn utskriven (Down the line, Face on), dagen och
  klockslaget, klubban (flera när serierna har olika) och svingarna (samma tal som sessionens rad, alltså
  de som räknas i måtten utan "Detection wrong"; "Not analyzed" tills analysen är klar), och "paired" med en länksymbol när passet filmades med två telefoner. Ett pass
  med två telefoner är alltså en rad per vy, på var sin telefon. Ett tryck öppnar passet; + uppe
  till höger ger Record och Import from Photos. Ett svep åt vänster visar Delete, och en fråga i
  ett blad visar raden, säger vad som försvinner ("Video, joints and measures are removed from
  this phone"; för ett parat pass också att den andra telefonen behåller sitt). Cancel är
  huvudknappen (vitt fält) och står först, också för VoiceOver; Delete är en grå rad utan fyllning
  under den, så att Delete aldrig är förvald. Vägras raderingen eller går den inte, står felet i
  bladet som en vit rad (som B60:s felrad). En tom lista visar "No sessions" och +. **Me:** längden, handen, klubborna och
  "Import focus" (som låg i Me → Sessions).
- **Varför flikar och inte en ikon uppe till vänster:** två namngivna flikar säger direkt att
  appen har två sidor och vad de heter; en personikon i hörnet måste man veta om. Fliken kostar
  en rad längst ned, och passet öppnas ändå över den (helskärm), så den syns aldrig under
  analysen.
- **Inne i sessionen bara sessionens vy**, genom katalogens `vy` (`Vyfilter`): en FO-session
  visar bara FO-kort och FO:s rader under granskningens video, en DTL-session bara DTL; "bada"
  (tempot) i båda. Filtret All/FO/DTL försvinner ur sessionen, och vyns namn står där.
  Klubbmarkeringen var redan per vy (B57). 3D-kortet (S6c-2) visas i båda. Inget djup går
  förlorat: korten för den andra vyn var alltid "—" i en session med en telefon.
- **Dolt men kvar (VISION.md: ett tryck bort, inte borttaget):** Today, Focus (Att jobba på) och
  Progress (också dess 3D-val, B62) syns inte i navigeringen; vyerna (`IdagVy`, `AttJobbaPaVy`, `UtvecklingVy`), deras
  data (`Flikdata`, `Idagvisning`, `Utvecklingsvisning`) och filerna i `AttJobbaPa/` är kvar.
  Accenten (B31) följer fortfarande Focus i sessionens kort och granskningens rader, och "Ask
  Claude" och "Paste from Claude" stannar i sessionen (B60; raden på Today är dold med Today).
- **Raderingen** tar passets mapp (pass.json med måtten, Video/, Klipp/, Leder/, par.json,
  foljare.json, den andra telefonens slag och 3D) och dess paket i Documents/Export, så att
  videon inte ligger kvar i Filer. **`att_jobba_pa-<pass>.json` ligger kvar:** den är liten och
  är vägen tillbaka till det som övas (Focus och accenten). Det är granskarens val 2026-10-24 i
  väntan på att Johannes säger något annat. Ett pass som spelas in, importeras eller vars paket
  skrivs just nu tas inte bort ("The session is in use."). Ett raderat pass skrivs aldrig igen
  under appens körning (`Store.deleted`): en serie som sparas när kameran stängts, analysen, den
  andra telefonens slag och 3D-räkningen vägras, så att passet inte kommer tillbaka; ett nytt pass
  med samma id tar bort spärren. Går mappen inte att ta bort men pass.json är borta, tas raden
  bort ur listan ändå. Den andra telefonens pass rörs inte: inget skickas dit.
- **Frågan är ett blad, inte en systemdialog**, så att simulatorprovet kan rita den (som B60).
  Svepets knapp och bladets Delete är grå (B13: ingen signalfärg för en vanlig handling). Bladet
  har höjderna medium och large och rullar, så att det fungerar med stor text.
- **Bortvalt:** en NavigationStack med Me som ikon (se ovan); passen som en sektion i Me (som
  förut, två tryck bort); en rad för ett parat pass med båda vyerna (telefonerna har var sin
  lista, och raden ska säga en vy); en röd Delete; Delete som huvudknapp; att behålla paketet i Export efter raderingen
  (passet skulle ligga kvar i Filer utan att synas i appen).
- **Kostnad:** Today och Progress syns inte förrän de kommer tillbaka, och Focus syns bara som
  accent i sessionen. En raderad session går inte att få
  tillbaka på telefonen (ett paket som redan skickats till PC:n finns kvar där).
- **Omprövas:** efter Johannes telefonprov av S4e, och när Ranges (PLAN S4g) byggs.

---

Besluten B37–B39 kommer ur S6a (PC-sidan av två kameror). De är tekniska val och
**prövas**; de omprövas när riktiga svingar och markörer finns (PLAN S6a, "Återstår").

## B37 — 3D på PC:n: egen katalog, trend utan bedömning, och 2D först
*2026-10-22 · prövas · PLAN.md S6a · METOD MK1–MK8*

- **Valt:** `tools/pc/tva_kameror.py` gör två paket från samma pass (DTL och FO) till
  3D och skriver `tre_d` i `analys.json` (docs/FORMAT.md). Måtten står i
  **`katalog_3d.json`** i repots rot, som bara PC:n läser (`katalog.las_3d`), och i
  historikens minne (`historik.py minne`, `tre_d`). Utan markörer visas de bara som
  passets median över minst 10 slag (B14) och bedöms aldrig grönt, gult eller rött;
  de blir aldrig en sak i `att_jobba_pa.json`. En skillnad mot förra passet är tydlig
  först över ett golv per mått (METOD MK7). Går 3D inte (ett paket, för få slag i båda,
  kalibreringen) står skälet i `tre_d.hoppat`, och 2D-analysen går som förut. Allt
  3D-arbete, även katalogen, jämförelsen och trenden, ligger bakom ett enda skydd
  (`analys.tre_d`): ett oväntat fel blir `hoppat` med typens namn, aldrig ett värde.
- **Varför egen katalog:** `katalog.json` ligger ordagrant i Swift-fixturerna
  (`Fixturer.swift`, B12) och läses av appen, som kontrollerar varje mått mot sina vyer;
  ett nytt mått där kräver nya fixturer och en ny vy i SwingLabKit. Samma skäl som
  kedjorna i `tools/pc/kedjor.json` (skillen svinganalys, F-S5-1).
- **Bortvalt:** 3D-måtten i `katalog.json` med en ny vy (`"3d"`): rör appen i S6a.
  Att bedöma höfterna vid träffen mot 35–45° (research 1 §1.7): passets median har
  5–12° fel med typiskt brus (S6_FELBUDGET §6.7), så en gräns blir brus; spannet står
  bara som riktmärke.
- **Kostnad:** två kataloger. När appen ska visa trenden (S6b) flyttar måtten in i
  `katalog.json` och fixturerna.
- **Omprövas:** när vyn i appen byggs, eller när markörerna ger mått per sving.

## B38 — Självkalibrering ur lederna per uppställning, brännvidden ur seriens synfält, och en spärr
*2026-10-22 · prövas · METOD MK3, MK4 · S6_FELBUDGET §6.5*

- **Valt:** kamerorna kalibreras ur passets egna leder (åttapunktsmetoden och
  Sampson-felet), en gång per uppställning: en DTL-serie mot en FO-serie, eftersom
  stativen kan flyttas mellan serierna. Varje slag har sin egen K, med brännvidden ur
  seriens synfält i manifestet (`format.synfalt`), annars `enhet.json`, annars
  specifikationen. Synken finjusteras på återprojektionen och kalibreringen görs om
  med den (två varv). En uppställning vars Sampson-fel är över spärren (8 px) mäts
  inte, och vinkeln mellan kamerorna utanför 60–120° märks `osaker`.
- **Varför:** paketen bär inga mattpunkter och ingen ChArUco-mätning än, och
  självkalibreringen kräver ingenting av Johannes. Utan brus är kedjan exakt (under
  0,5° på passets median). Brännvidden går inte att skatta ur Sampson-felet: fel
  brännvidd syns inte där men ger 4–9° på passets median vid −15 till +20 % (granskningen),
  och telefonen skriver redan synfältet. Spärren hindrar att en dålig kalibrering blir
  en trend.
- **Bortvalt:** mattan (6–10 klickade punkter per pass): bäst i felbudgeten (0,2°),
  men kräver punkterna i paketet och ett verktyg att klicka dem. En kalibrering per
  slag: sämre underlag. Hela passet som en uppställning (första versionen av S6a):
  fel när stativen flyttats mellan serierna. Brännvidden ur specifikationen alltid.
- **Kostnad (uppmätt på facit):** med typiskt brus är kalibreringens vridningsfel i
  snitt 5°, upp till 14°, eftersom posemodellens fasta avvikelse per led böjer
  geometrin. Det höjer bröstets passmedian-SD från 6,4° (sanna kameror) till 9,6°.
  Spärren släpper igenom "typiskt" brus (4,7 px) men stoppar "dåligt" (9,2 px).
- **Omprövas:** när S3 mätt den fasta avvikelsen och riktiga pass visat Sampson-felet.
  Är avvikelsen stor: mattan, eller en utjämning där varje leds fasta avvikelse
  skattas med kamerorna.

## B39 — Lodlinjen: valfritt fält i manifestet, annars kamerornas vågräta
*2026-10-22 · prövas · METOD MK3, MS17 · appen skriver fältet sedan S6b (2026-10-23)*

- **Valt:** `serier[].lodlinje` i `manifest.json` (docs/FORMAT.md): uppåt (−gravitationen,
  i g) i kamerans ram i den upprätta bilden, valfritt. PC:n använder det när någon vy
  bär det. Utan det tas uppåt vinkelrätt mot båda bildernas x-axel, vilket antar att
  ingen telefon lutar åt sidan. Fältet är **mjukt**: fel form eller längd, eller uppåt
  som inte pekar mot bildens överkant, gör att det inte används (skälet i
  `tre_d.kalibrering[]` och `tre_d.osaker`), men paketet och 2D går som förut (B37).
  En vänd vektor vänder annars måtten tyst (höfterna vid träffen −36° mot +36°).
- **Varför:** felbudgeten visar att 0,5–3° fel i lodlinjen inte syns (vridningen mäts
  mot adressen), så antagandet räcker tills appen skriver fältet.
- **Appen (S6b, METOD MS17):** `CMDeviceMotion.gravity` i 30 Hz under serien. Medianen
  tas över sekunden före seriens första klick, inte vid starten: där har någon nyss
  tryckt på telefonen. Den gäller bara när den stämmer med seriens stilla sekunder (ett
  stöt efter första klicket ger inget fält); är sekunden inte stilla tas seriens stilla
  sekunder, när de är eniga. Spridningen mäts som 95:e percentilen, och över 1° får
  telefonen inget fält. Skälet (`oenig`, `rorelse`, `for_fa_prov`), fönstrets prov och
  första provets tid i filen står i `pass.json`, så att ett klockfel syns. Logiken ligger
  i SwingLabKit (`Plumb`), appen ger bara proven, och manifestet vrider gravitationen med
  filens orientering. Telefonen skriver bara ett fält som PC:ns kontroll tar och som lutar
  högst 45° från bildens överkant. **Tillåtelsen:** `NSMotionUsageDescription` står i
  project.yml, eftersom Apple visar en tillåtelse för `CMMotionManager` från iOS 27.2 och
  varnar för krasch utan nyckeln: inte bekräftat i original, oprövat på iOS 27.2.
- **PC:ns skydd (METOD MK3):** vinkeln mellan manifestets uppåt och kamerornas vågräta
  skrivs per uppställning, och över 15° används de vågräta. Den vinkeln är mätningen som
  beslutet omprövas med.
- **Följdjobb:** visa i uppställningen om telefonen lutar åt sidan (en vy, inte S6b).
- **Bortvalt:** att kräva fältet (då går dagens paket inte), och lodlinjen ur kroppen
  (fötterna och höfterna i adressen lutar med hållningen). I appen: provet vid seriens
  start (telefonen gungar av trycket), och råa prov i `pass.json` (300 kB per serie, och
  medianen är densamma).
- **Omprövas:** på riktiga pass med fältet, ur `kalibrering[].lodlinje_mot_vagrata`.

## B40 — Måttens namn: kroppsdel och vad, positionen bara där den behövs
*2026-10-23 · gäller · Johannes beslut*

- **Valt:** varje mått heter efter kroppsdelen och vad som mäts, på engelska och utan
  värdeord (B13), och tecknet ska gå att läsa entydigt (infobladet, B41). Johannes
  godkände tolv namn (Hips toward ball, Spine angle loss, Trail elbow flare, Hands out
  (downswing), Hip sway, Hip shift to target, Spine tilt, Lead arm fold, Hip hinge,
  Chest height, Hand height, Follow-through time); resten följer samma princip
  (`Texter.mattnamn`). I granskningen visar positionen redan var måttet tas, och i
  passet står den i kortets rubrik ("FO · top"), så där står namnet utan position;
  felens rader på Today får positionen när måttet tas i en punkt ("Hip sway at top",
  `Texter.felnamn`). Huvudets mått (M8, M9) visas i granskningen som Head toward ball
  och Head height (Johannes ja 2026-10-23).
- **Ändras inte:** id:n, `att_jobba_pa.json` och PC:ns tal: bara visningsnamnen.
- **Tecknen som inte stämde med tabellen** behåller kodens tecken (METOD): `backen_sway_*`
  är + mot målet (M15), inte bort från målet, och `sidbojning_topp` + bort från målet
  (M14), inte mot målet. Tecknet står rätt i infobladet och i kortets rubrik ("+ to
  target", "+ away from target").
- **Bortvalt:** att vända tecknen (PC:ns tal, gränserna och historiken följer dem).

## B41 — Infobladet: beskrivande text bara i bladet
*2026-10-23 · gäller · Johannes beslut · kompletterar B13*

- **Valt:** varje fel och mått i `katalog.json` har `vad` (vad som mäts och mellan
  vilka punkter), `varfor` (varför det spelar roll, med felets namn) och `tecken`, på
  engelska och korta. Ett tryck på en måttrad i passet och granskningen, eller på en
  liten ⓘ i Today och Progress, öppnar ett blad i halv höjd med namnet, de tre raderna
  och källan i grått ("Source: Assumption, own baseline"), svartvitt (design/README),
  accenten bara som förut (B31). Källan byggs ur `status`, `kontrollerad`, gränsen och
  `kalla` (webbplatserna) och påstår aldrig mer än METOD: en gräns som är ett antagande
  byggt på en tillverkares tal (`grans_harledd`, sway_topp, M15) heter "Assumption from
  manufacturer (…)", och de oprövade måtten (farterna och genomsvingens tid, M35–M37)
  säger "untested on the phone" i källan, inte i `varfor`. `varfor` säger aldrig mer än
  METOD-raden: en definition eller "Shows …", inga orsakssamband och inga värdeord
  (`att_jobba_pa.vardeord` i provet).
- **VoiceOver på Today:** dubbeltryck på en rad öppnar passet som förut; bladet är radens
  namngivna åtgärd "About the measure". ⓘ har en tryckyta på 44×44 pt.
- **B13 gäller på skärmarna:** ingen beskrivande text där; bladet är det enda stället.
- **Hålls av prov:** `test_katalog.py` och `KatalogTests` kräver fälten överallt,
  `test_engelska.py` fäller svenska i dem, `VisningTests` att varje rad har sitt blad,
  och simulatorprovet ritar bladet (`infoblad`).
- **Bortvalt:** en förklarande rad under varje mått (bryter B13), och en hjälpsida.
- **Omprövas:** när ett andra språk kommer (fälten blir då en tabell per språk, B33).

## B42 — Starten bakifrån ur posen, och tempot osäkert hellre än fel
*2026-10-23 · prövas · METOD M40 · PLAN S1d*

- **Valt:** bakifrån (DTL) tas baksvingens start ur armarnas och axlarnas pose (sex
  leder) mot adressens stillaste fönster, bakåt från toppen. Framifrån (FO) står M4
  kvar och ger samma tal som förut (testet `test_fo_ar_oforandrad` låser dem). Skakar
  posen i adressen för mycket, eller räcker den inte, märks starten osäker
  (`faser.start_osaker`) och tempot visas inte.
- **Varför:** takeawayn går mot kameran bakifrån, och händerna ensamma tappade
  tempot eller gav det ≈ 1 för lågt på påhittade svingar. Posen gav högst 0,14 fel på
  tempot med lite brus och höll när bålen vrider senare än armarna. Ett osäkert
  tempo som inte visas är bättre än ett fel tal i Today.
- **Bortvalt:** händernas fart mot bruset, axlarnas bredd ensam (den främre axeln
  skyms), underarmarnas skala, och att ta starten ur FO-telefonen via parningen
  (behövs inte när 2D räcker; 3D-måtten tar redan FO:s start, MK6). Samma pose även
  framifrån: bättre på 3D-svingarna, men ändrar FO:s tal utan att något var fel där.
- **I vyerna:** tempot visas som "—" i passet och på Today när passets slag saknar
  säker start, och infobladets källrad säger varför (METOD M40). Inget nytt ord på
  skärmen (B13): förklaringen står bara i bladet (B41).
- **Mätningens version** (METOD M40, MS14): måtten bär version 2. Telefonen mäter om
  ett slag med en äldre när passet öppnas, och PC:ns historik säger vilka pass som ska
  köras om med session.py, så att DTL-historiken inte får ett falskt tempohopp.
- **Kostnad:** gränserna är antaganden. Gamla pass på PC:n måste köras om för hand
  (paketen behövs), och på telefonen mäts varje gammalt pass om en gång när det öppnas.
- **Omprövas:** när S3 mätt posemodellens brus på golf och ett riktigt DTL-pass
  prövats (`faser.start` och `start_osaker` i PC:ns `analys.json`), och om en
  waggle visar sig flytta adressens fönster.

---

Besluten B43–B44 förbereder Johannes steg på hemdatorn (S3 och S7): ett kommando per
steg. De **prövas** tills verktygen körts på riktiga paket.

## B43 — S3 på PC:n: MediaPipe heavy på telefonens rutor och utsnitt, tabellen utanför repot
*2026-10-23 · prövas · PLAN.md S3 · METOD MF1–MF4*

- **Valt:** `python tools/pc/s3_facit.py <paket.zip> [fler]` kör MediaPipe Pose heavy
  (VIDEO-läge, som Golf SG i oktober) på varje ruta i paketets klipp, i seriens utsnitt
  (B34), och för punkterna tillbaka till hela bildens pixlar. Klippets tider (OpenCV) och
  Visions skiljer sig med en förskjutning per klipp, som skattas ur handledernas banor i
  MediaPipes IMAGE-läge (utan VIDEO-lägets utjämning, och med modellernas fasta skillnad
  bortdragen) och ska vara densamma i passets klipp; ett slag där den är tvetydig eller
  avviker jämförs inte, och ffprobes start_time skrivs som kontroll. Lederna jämförs per led, fas och vy, S1:s mått
  räknas med samma kod på båda källorna, parade per slag, och överst står det som avgör B5
  för hela svingen och nedsvingen, med nivågränser ur en simulering av felbudgetens brus i
  båda källorna (geometriska medlet mellan nivåernas medianer), de grova avvikelserna,
  intervall ur bootstrap av slagen och "–" under 5 slag. Tabellen
  (`s3.md`, `s3.json`), kontaktarken och MediaPipes leder skrivs till
  `~/swinglab-s3/<pass>/`; verktyget vägrar en mapp i repot. Modellen hämtas till
  `~/.cache/swinglab/mediapipe/` (eller tas ur Golf SG:s cache); saknas `mediapipe` eller
  `opencv-python` skriver verktyget `pip install`-raden och stannar.
- **Varför:** B5 och B14 väntar på ett mätt 2D-fel, och felbudgeten är byggd på antagna
  nivåer. Med samma rutor och samma utsnitt är skillnaden modellen, inte bilden. En ruta
  fel i tid ger cirka 2 % av kroppslängden i nedsvingen, mer än nivåerna själva, därför
  skattas förskjutningen i stället för att litas på OpenCV:s tid. Skillnaden mellan två
  modeller bär båda modellernas fel, därför simuleras trösklarna i stället för att
  felbudgetens nivåer för en källa används rakt, och gränsen ligger mellan nivåerna, inte
  på nivåns egen median (som klassade de flesta pass en nivå för dåligt). Modellen och
  klippet bakom gränssnitt gör
  att jämförelsen provas på Linux utan MediaPipe, med en påhittad modell som läser rutans
  nummer ur bilden.
- **Bortvalt:** MediaPipe på hela bilden (då blandas utsnittets effekt in; B34 omprövas
  separat), IMAGE-läget (oktobers tal kom ur VIDEO-läget), förskjutningen ur `ffprobe`
  ensam (finns inte alltid, och telefonens nolla är inte prövad), felbudgetens nivåer
  direkt som trösklar, att låta verktyget fatta B5 (trösklarna för saknade leder och
  måtten saknar källa), och tabellen i `data/historik/` (den hör till S3, inte till
  passens historik).
- **Kostnad:** MediaPipe heavy på CPU tar cirka 45 ms per ruta (uppmätt i molnet på en
  påhittad film), alltså cirka 45 s per slag med 960 rutor, plus cirka 150 rutor i
  IMAGE-läget för tidsparningen; lederna sparas så att en ny körning går fort.
  Simuleringen av trösklarna tar cirka 4 s per körning. Avvikelsen är
  mot MediaPipe, inte mot sanningen, och trösklarna vilar på antagandet att MediaPipe
  heavy ligger på felbudgetens nivå "bra".
- **Omprövas:** när tabellen finns för ett riktigt pass i båda vyerna; då tas B5.

## B44 — Klubbans märkning: tre klickade punkter på en lokal sida, sparad bredvid paketet
*2026-10-23 · prövas · PLAN.md S7 · METOD MF5–MF6*

- **Valt:** `python tools/pc/markera_klubba.py <paket.zip|video.mov>` väljer rutorna
  själv (adress, topp och tidig nedsving ur faserna och P5, plus några jämnt spridda, i
  varje vy) och läser dem med S3:s förskjutning, så att bilden är Visions ruta; utan S3:s
  tabell stannar det och säger att S3 ska köras först. Sidan öppnas från en server på
  127.0.0.1 med en slumpad nyckel i adressen. Johannes klickar **grepp**, **skaftets
  mitt** och **klubbhuvudet**, där klubbhuvudets punkt är GolfPose **hosel** (där skaftet
  går in i huvudet; research 2 §3, punktnamnen ej lästa i original, B10). Varje punkt är
  ett klick: handledernas mitt visas bara som ledtråd för greppet och godtas aldrig av sig
  själv. Märkningen (`swinglab-klubba/1`, FORMAT.md) sparas efter varje ruta i
  `swinglab-<pass>-klubba.json` bredvid paketet, och en ny körning fortsätter där den
  slutade.
- **Varför:** S7:s "klart när" mäts mot handmärkta rutor i adress, topp och tidig
  nedsving i båda vyerna, och detektorn tränas på samma märkning. Grepp och hosel ger
  skaftets linje; mitten ger en kontroll när skaftet böjs eller är suddigt. Handlederna
  ligger 5–8 cm från skaftet (cirka 4° på vinkeln), så en godtagen ledtråd hade blivit ett
  fel i facit. En server på den egna datorn kan skriva filen bredvid paketet, vilket en
  fil-sida inte kan; nyckeln och Host-kontrollen gör att ingen annan sida kan.
- **Bortvalt:** GolfPose alla fem klubbpunkter (häl och tå syns sällan i 240 bilder/s
  med 1/2000 s, och skaftets vinkel kräver bara två), ett färdigt märkverktyg (CVAT,
  Label Studio: installation och export för tre punkter), en sida utan server (filen
  hamnar i Hämtade filer; knappen "Ladda ner" finns kvar som reserv), och att godta
  ledtråden med Enter.
- **Kostnad:** cirka 30 rutor per vy och pass med standardvalet; märkningen är Johannes
  tid. Bilderna bäddas in i sidan (några MB). S3 måste ha körts först.
- **Omprövas:** när GolfPose punktdefinition lästs i original, och när detektorn ger
  förslag för skaftet och huvudet.

## B45 — Gränserna ur research 5: bara där källan mäter samma sak
*2026-10-23 · gäller, gränserna och färgerna ändrade av B86 och B87 (2026-10-25) · ledarens beställning (S1e)*

- **Regeln:** en gräns tas in bara när källan har samma definition, nollpunkt och
  tecken som SwingLabs mått i 2D. Annars gäller egen baslinje (METOD M27), och skälet
  står i METOD. En tour-gräns som beror på klubban gäller bara den klubba källan avser;
  katalogen bär ingen klubba, så en sådan gräns blir egen baslinje med en notering.
  Gränserna är **antaganden** byggda på källorna (`grans_harledd`), och `varfor` i
  katalogen säger aldrig mer än källan (B41).
- **Valt, per fel:**

| Fel | Förut | Nu | Källa (läst i original) | Varför |
|---|---|---|---|---|
| `sway_topp` | grönt ≥ 0, gult −5…0 | grönt ≥ −2,5, gult −5…−2,5, rött under −5 cm | Sportsbox tour-ranges-for (tour P4 −1,5 cm med driver, 0,0 med järn), golf.com (låg handicap nära 0, hög "flera tum" bort) | Pelvis Sway = M15 (bäckenets mitt, 0 vid adressen, + mot målet). Tour med driver blev gult förut. Båda klubbornas tour-tal är gröna, så gränsen beror inte på klubban. |
| `early_extension` | egen baslinje | grönt ≤ +4,3, gult +4,3…+8,4, rött över +8,4 cm | Sportsbox what-is-early-extension: ideal −2,3…+4,3 cm, tour +1,3 cm (SD 3,6) | Pelvis Thrust = M7 (0 vid adressen, + mot bollen, bakifrån). Rött över tour-medel + 2 SD. Klubban anges inte i källan. |
| `sway_gap` | egen baslinje, ingen riktning | egen baslinje, `samre: "-"` | Sportsbox what-is-sway-gap och tabellen: tour vid träff +13,2 cm (driver), +8,9 cm (järn) i M19:s form | Definitionen är löst (M19). + = bröstet bakom = tour-hållet. Tour-talet skiljer 4–6 cm mellan klubborna. |
| `tappad_hallning` | egen baslinje | oförändrad, referensen ny | Sportsbox Chest Bend (tour-tapp +4°/+1°), Yamamoto 2023 | Bröstkorgen i 3D, inte linjen i bild, och tappet är mindre än felet i 2D (≈ 5°). Vikten läggs på spridningen (B46, METOD M44). |
| `axellutning` | avstängd, referens GolfTEC 39° | avstängd, referens 22–25° med järn | Sportsbox Chest Side Bend 22° (järn), Meister S-faktor 25 ± 3° (järn 5) | Samma nollpunkt och tecken som M17 men 3D; S0 avgör definitionen. |
| `tempo` | grönt 2,5–3,1 | oförändrat, nedsvingens tid visas | Blast (2,5–3,1), Grober 2006 (amatörer har också medel 3,0) | Kvoten skiljer inte nivåer; `nedsving_s` står i katalogens `matt` vid P7 och tempokortet visar sekunderna. Blast definierar inte toppen. |

- **Bortvalt:**
  - TPI:s exempel för early extension (> 7,6 cm som rött): varken mätsystem eller punkt
    anges, så definitionen går inte att stämma av.
  - En tour-gräns för sway gap per klubba (driver +13, järn +9 cm): se klubban nedan.
  - En gräns för tappet (+1…+4°): mindre än felet i 2D.
  - GolfTEC:s hip sway vid toppen (3,9 tum mot målet) och shoulder tilt (39°): mäts på
    svanskotan respektive mot en oklar referens, inte som M15 och M17.
  - En gräns för bröstets bakåtlutning i finishen (GolfTEC tour 32°, 31+ 3,2°): en
    sensor i 3D, inte linjen i bild (METOD M14).
  - Recentreringens "under 1 tum" (Sportsbox) som gräns: en indikator utan tal per nivå
    (METOD M41).
- **Klubban (Johannes beslut 2026-10-23, svar på research 5 §8):** egen baslinje per
  klubba räcker, och katalogen får inga gränser per klubba.
  - Valt: en gräns tas in bara när den inte beror på klubban (swayen vid toppen, där
    båda klubbornas tour-tal är gröna) eller när källan inte anger någon (thrusten).
    Annars jämförs passet med de egna passen med samma klubba, vy och längd (METOD M27),
    och ett pass med flera klubbor analyseras per klubba på båda sidor (BESLUT B56).
  - Bortvalt: tour-gränser per driver och järn (`klubbor` per gräns, passets klubba i
    bedömningen i Python och Swift, en tabell från uppställningens id till driver/järn).
  - Omprövas när en källa med en klubbas gräns kräver det.
- **Antagandena under gränserna:**
  - `sway_topp`: "samma definition" gäller måttet, inte positionen. Sportsbox TOP är
    klubbans vändning, vår topp händernas högsta punkt (≈ 9 ms tidig, METOD M4), och
    bäckenet rör sig redan mot målet där: vårt tal blir systematiskt mer negativt, i
    storleksordningen 1 cm per 20 ms. Gränsen behålls och prövas på ett riktigt FO-pass.
  - `early_extension`: bakifrån ser kameran bäckenet snett när det vrider sig, och
    höftmitten kan flytta sig 1–2 cm skenbart "mot bollen" (METOD M7). Gränsen behålls
    och prövas på riktiga DTL-pass.
- **En övning som pågår när gränsen ändras:** "klart när" och märkningen är låsta från
  valet (METOD MT5), medan sakens `spann` följer katalogen. Är felet inte längre flaggat
  i det senaste passet efter valet räknas övningen som klar (`lage: "klart"`,
  `klart_skal: "inte_flaggat"`, `tools/pc/historik.py`), och skillen rapporterar den
  som klar, inte tyst borttagen. Det gäller swayen och early extension, vars gränser
  flyttades. Är felet fortfarande flaggat fortsätter övningen med sitt gamla "klart när".
- **Följd:** alla källor i katalogen är lästa i original utom flying elbows
  (`kontrollerad: true` för elva av tolv fel), och märkningen B10 försvinner från de
  tre gränserna (`sway_topp`, `tempo`, `early_extension`); `att_jobba_pa.json` får
  `markning: null` för dem.
- **Omprövas:** när klubban förs in i katalogen (sway gap per klubba), när S0 har
  avgjort axellinjen, och när riktiga pass visar var Johannes ligger mot gränserna.

## B46 — Spridningen mellan slagen som eget tal, med felens kort och diagram
*2026-10-23 · gäller · ledarens beställning (S1e)*

- **Valt:** ett tal per pass och mått: den robusta sd:n ur passets svingar (METOD M44),
  först bröstets böjning bakifrån i adressen och vid träffen, och inget tal under 8
  slag (IQR/1,349 är 0,63σ vid tre slag och 0,84σ vid åtta; Severin 2021: 8 räcker). På
  PC:n räknas den per klubba när serierna har olika klubbor. Måtten står i en egen
  lista `spridning` i `katalog.json` (docs/FORMAT.md) med infobladets tre fält. Passet
  visar ett kort per mått ("Spine angle spread") efter felen, och Progress ett mått
  över passen, med **samma kort, spann och diagram** som felen: förra passets spridning
  som streck och de tidigare passens som egen baslinje. Ingen ny visningstyp, svartvitt
  (B13), utan accent (B31). Simulatorprovet ritar Progress med spridningen vald
  (`utveckling-spridning`), och passets bild har korten. PC:n skriver talen i
  `analys.json`.
- **Varför:** Yamamoto 2023 (läst i original): spridningen i framåtlutningen hängde ihop
  med score (r = 0,80), medelvinkeln inte. Det är det enda markörlösa 2D-fyndet med utfall.
- **Bortvalt:** sd med n − 1 (en felmärkt sving drar den långt); att räkna från tre slag
  som M25 (talet blir en tredjedel för lågt); spridningen som fel med
  gräns (ingen norm); en egen vy med slagen som prickar (kortet och diagrammet räcker);
  spridningen på Today (Today visar felen).
- **Omprövas:** när fler mått ska få sin spridning (en rad i listan), eller när riktiga
  pass visar att spridningen behöver en egen gräns.

## B47 — Klubban markeras för hand i appen: P1–P10, grepp och hosel, samma data som PC:ns
*2026-10-23 · prövas · PLAN.md S7a · METOD M45–M49 · Johannes beställning, rättat efter granskningen*

- **Valt:** i granskningen ett läge "Mark club" (DTL först): Johannes går igenom P1–P10,
  trycker på greppet och sedan på hoseln med ett förstoringsglas (3 ×) och hårkors, och
  positionen sparas av sig själv med rutan där första punkten sattes. Greppet kan tas ur en
  ring vid handlederna med ett tryck på den. Han kan flytta en punkt, ångra (videon går
  tillbaka till den sparade rutan) och hoppa över en position där klubban inte syns. P2, P6
  och P8 bakifrån är rutan där skaftet pekar mot flyktpunkten (kortast), från ett förslag
  mitt mellan kroppens positioner (M45). Riktpinnen, två tryck en gång per serie, ger
  flyktpunkten (M48). Markeringarna sparas i `pass.json` (`slag[].klubba`, valfritt) och
  följer med i paketet som `klubba.json` i formatet **`swinglab-klubba/2`** (FORMAT.md), som
  `markera_klubba.py` och `samla_klubba.py` läser som PC:ns egna. 2–3 markerade svingar per
  pass räcker; passet visar hur många.
- **Varför version 2:** telefonens markering har inget klipp att peka in i när paketet
  skickas utan klipp och ingen S3-förskjutning, den tar P-positioner, inte PC:ns rutval, och
  den har två punkter, inte tre; greppet ur ringen har en egen källa
  (`handlederna_bekraftad`). Version 2 tillåter därför `val` P1–P10, `t_klipp` och
  `forskjutning_ms` som null (null är okänd, inte 0), en markerad ruta utan skaftets mitt
  och den nya källan. En fil i version 1 är en giltig fil i version 2 med ett annat
  formatnamn; PC:n läser båda och skriver 2. **Bortvalt:** ett eget telefonformat (två
  läsare för samma träningsdata), tre punkter på telefonen (mitten tar ett tryck till per
  position och behövs bara som kontroll för ett böjt skaft), och att godta ringen utan tryck
  (handlederna ligger 5–8 cm från skaftet, B44).
- **Måtten** (M46–M49): skaftets vinkel i bild vid varje position och, bakifrån,
  skaftplanet vid P1, across/laid off vid toppen och hoseln mot planet vid P6; framifrån
  skaftet vid toppen, armen mot skaftet vid P5 och P6 (casting) och skaftlutningen vid
  träffen. Ett mått saknas när dess osäkerhet ur trycken (3 px per tryck genom måttets
  geometri) är över 4°. De står bland slagets mått (telefonens `ShotMeasure`, PC:ns
  `analys.json`), i katalogens `matt` med positioner och vy, utan `fel`, och passet visar
  medianen och n över de markerade svingarna. **Med få svingar är de en trend, inte en sak
  att öva**: inget fel, ingen gräns och ingen accent (skillen `svinganalys`). Ingen källa
  har samma definition i 2D (Morrisons leveransplan är 3D och ett annat plan, M47), så alla
  har egen baslinje. **Borttaget efter granskningen:** P2 mot planet (mätte kamerans höjd,
  och avvikelsen mot flyktpunkten är noll per definition vid P2, M47).
- **Uppställningen bakifrån:** på händernas linje, i händernas höjd, riktad längs
  mållinjen (appens uppställning, M47). Då är P6-måttet exakt; utan riktpinne kostar varje
  grads vridning 3,7–4,7° vid toppen, så måttet märks "assumed" (M48).
- **Ingen ommätning:** mätversionen (`MATVERSION` 3) ändras inte. Inget befintligt mått
  ändras; klubbmåtten är nya namn som bara finns på slag med markeringar och räknas om när
  markeringarna eller riktpinnen ändras (telefonen mäter om slaget utanför huvudtråden, PC:n
  räknar dem i varje `session.py`). Ett pass utan markeringar får samma tal som förut.
- **Kostnad:** cirka 26–35 tryck per sving (M45). DTL:s across/laid off vilar på
  flyktpunkten och en kamera i våg (M48).
- **Omprövas:** när Johannes markerat svingar på telefonen (gränserna 3 %, 5 % och 4 pt,
  M45), när FO-läget byggs (och FO-tiden för P2/P6/P8 med två telefoner), och när S7:s
  detektor föreslår punkterna. FO-läget är B57; ordningen är ändrad i B58 (kroppens
  positioner först, skaftets sist).

## B48 — 3D på telefonen: Python-kedjan portad till Swift, med ett jämnt urval
*2026-10-23 · prövas · PLAN.md S6c · METOD M50, MK1–MK7*

- **Valt:** `SwingLabKit/Sources/TreD` (eget mål, beror på Swing och Capture) gör två
  telefoners paket till 3D rad för rad som `tools/pc/tva_kameror.py`: samma algoritmer,
  samma konstanter och samma ordning, med egen linjär algebra (ensidig Jacobi för
  singulärvärdena, LU för ekvationssystemen, Levenberg–Marquardt som Pythons `lm`).
  Utdata är `TreDResultat`, samma form som `analys.json`:s `tre_d`. Python är facit
  (B12): `tools/pc/generera_tre_d.py` skriver påhittade tvåpaketspass och Pythons tal
  till `tools/tests/fixturer/tre_d/`, och Swift ska ge dem inom METOD M50:s tolerans.
- **Ändrat i Python:** kalibreringens högst 5 000 punktpar valdes med numpys slumptal
  (`default_rng(0).choice`), som Swift inte kan räkna om utan att skriva av PCG64 och
  numpys urvalsalgoritm. Nu väljs de som en permutation, index (i · P) mod n med P det
  första heltalet från ⌊n · 0,618…⌋ utan gemensam faktor med n (METOD M50), i båda
  språken. Ett jämnt steg ⌊i · n / 5 000⌋ (granskningens första version) kan gå i takt
  med ledernas period 13 per ruta och välja samma leder; permutationen gör det inte.
  **Prövat mot S6a:s facit** med `python3 tools/pc/kedjans_facit.py` (S6_FELBUDGET
  §6.7, samma 56 pass, frö 100–123): utan brus oförändrat (max 0,3°); med bra och
  typiskt brus samma bias inom 0,1° och samma SD inom 0,1° (bra: bäckenet 5,9, bröstet
  5,7, X-factor 7,8, stretchen 3,5, höfterna 3,5; typiskt: bröstet 9,6 → 9,7, höfterna
  5,9 → 6,0), synken och Sampson-felet oförändrade. MK7:s golv följer tabellen: bröstet
  13,6 → 13,7°, höfterna 8,3 → 8,5°.
- **Också ändrat i Python (METOD M51):** kalibreringen kräver nio punktpar i stället för
  åtta (med åtta räknade numpy fel nollrum), NaN stoppas före analysen (`hoppat` med
  skäl, spärrarna räknar NaN som över), ett slag med orimliga tider mäts inte, parade
  slag som inte mäts står i `tre_d.utelamnade` med skälet, och paketen måste komma i
  ordningen DTL, FO.
- **Varför:** Johannes mål (2026-10-23) är att så mycket som möjligt görs på telefonen.
  En port som ger Pythons tal kan prövas mot samma facit som S6a, och PC:n kan jämföra
  telefonens 3D med sin egen.
- **Bortvalt:** Accelerate (finns inte på Linux, där SwingLabKit testas); en annan
  algoritm i Swift (t.ex. SVD ur AᵀA:s egenvektorer, eller en färdig optimerare), som
  inte går att pröva mot Python tal för tal; att skriva av numpys slumptal.
- **Kostnad:** kedjan finns två gånger. Fixturerna är 3,8 MB JSON, nästan allt passens
  leder (kompakt som int16 i base64, `indata/`); facit per variant står i egna små filer
  och lodlinjens varianter återanvänder ett annat pass leder. Python-testet räknar om
  allt parallellt på 7–15 s i Actions, och TreDTests tar cirka 12 s.
- **Omprövas:** när kedjan ändras i Python (fixturerna skrivs om, B12), eller om
  telefonen blir för långsam (METOD M50:s tid).

---

Besluten B52–B55 kommer ur S5b-1 (Claude-appen på telefonen, grenen `s5b`). Lucka: s7a tar
B47 och s6c börjar på B48.

## B52 — Claude-appen på telefonen via urklippet, utan PC och utan API-nyckel
*2026-10-23 · prövas · Johannes beslut (utformningen) · PLAN.md S5b*

- **Valt:** "Ask Claude" i passet kopierar en färdig text (skillens regler och passets
  data, räknad på telefonen) till urklipp; Johannes klistrar in den i Claude-appen, som
  svarar med rapporten och sist ett kodblock i formatet `att_jobba_pa.json`. "Paste from
  Claude" läser urklippet, kontrollerar filen som PC:n (B54) och sparar den som Focus via
  samma väg som "Import focus" (`FocusInbox`, `Store.focus`). Bara text, inga videor.
- **Varför:** tolkningen behövs på rangen, där PC:n inte finns (B4 omprövad). Urklippet
  går genom abonnemanget utan nyckel och utan server (B3): det är Johannes som klistrar in.
- **Bortvalt:** API:et från telefonen (ingen nyckel i abonnemanget, B4); en delning till
  Claude-appen med fil (Claude läser text lika bra, och en fil kräver ett steg till); att
  telefonen fyller i filen själv ur Claudes val (då blir det två format att hålla ihop).
- **Kostnad:** två klipp per pass; Claudes svar kan vara fel i form, och fångas då av
  kontrollen (B54) i stället för att sparas. Ingen kontaktark: Claude i appen ser inga
  bilder, bara talen.
- **S5b-1 (byggt):** logiken i SwingLabKit (`Swing/Claude/`, `Capture/ClaudeKontext.swift`)
  och PC-sidan (`tools/pc/underlag.py`, `att_jobba_pa.py --ur-text`, `session.py
  --claude-text`). **S5b-2 (byggt, B60):** knapparna och simulatorprovet.
- **Omprövas:** efter de första passen tolkade i Claude-appen: jämför valet med skillens
  fulla väg på PC:n (`session.py --claude-text` ger samma text).

## B53 — Texten byggs ur skillen, och telefonen räknar som PC:n
*2026-10-23 · gäller · PLAN.md S5b*

- **Valt:** instruktionen är avsnitten mellan markörerna `<!-- claude-appen -->` och
  `<!-- /claude-appen -->` i `.claude/skills/svinganalys/SKILL.md`, ordagrant: ett nytt
  avsnitt om Claude-appen, stegen A–I och delar av "Det Claude inte får göra" (J och K
  fyller mallen i). `python3 tools/pc/underlag.py --swift` skriver dem och `kedjor.json`
  till `Swing/Claude/ClaudeKallor.swift`; `test_underlag.py` fäller en källa som glidit
  isär. Datan räknas på telefonen med en Swift-port av `analysera_rader` (`Passanalys`) och
  minnet (`Ovningslage`, `ovningar_ur`), med Python som facit (B12): påhittade
  passhistoriker i `tools/tests/fixturer/claude_facit.json` ska ge samma text tecken för
  tecken.
- **Kedjorna följer med till appen** (ändrar förslaget F-S5-1 i skillen): kandidaterna,
  mallarna och kontrollen behöver dem. De bärs som genererad källa, inte resurs (B12), så
  en ändrad kedja kräver bara att skriptet körs igen.
- **De tidigare passen** är de som kan jämföras: samma klubba, vy och längd, på telefonen
  och på PC:n (BESLUT B56).
- **Bortvalt:** en egen kortversion av reglerna i appen (glider isär från skillen); att
  låta Claude räkna ur rådata (B2).
- **Kostnad:** analysen och minnet finns i två språk till; facit-filen är ≈ 0,55 MB (åtta
  historiker och en ändring per felkod).

## B54 — Svaret: det sista kodblocket, samma kontroll och samma felkoder som PC:n
*2026-10-23 · gäller · PLAN.md S5b*

- **Valt:** urklippet läses som `att_jobba_pa.py --ur-text` gör: det sista kodblocket
  (```` ``` ```` med valfri märkning) som är ett JSON-objekt med `format` eller `saker`,
  annars hela texten eller det mellan första `{` och sista `}` (när Johannes kopierat bara
  blocket). Typografiska citattecken, hårda mellanslag och BOM byts bara när blocket inte
  går att läsa som det står (ett ’ i en övnings text är rätt, METOD MT12). Filen
  kontrolleras med alla regler i `kontrollera` (stängd form, flaggade fel, analysens tal,
  låst "klart när", kedjorna, värdeorden, treregeln), mot passet som underlaget gällde och
  minnet före passets val. Varje fel är ett fält och en kod (`Kontrollfel`); PC:n skriver
  koden på svenska och telefonen på engelska (B30, `Texter.kontrollfelTexter`). Ingen kod
  och ingen text bär ett värde ur svaret: värdeordet står inte längre i PC:ns fel.
- **Samma tolkning i båda språken** (efter granskningen): true och false är inte tal
  (`_lika`, `JSONVarde.lika`), texter jämförs tecken för tecken, siffror, ord och blanktecken
  är ASCII (`re.ASCII`), ett pass-id måste vara en dag som finns, `skapad` läses utan
  avslutande radslut, och avrundningen är Pythons `round()` även i Swift (METOD MT3).
  Urklippet läses bara upp till 64 KiB (`for_stort`) och JSON bara 32 nivåer djupt (annars
  `inte_json`). 60 koder; `ej_i_analysen` går inte att nå, eftersom analysen bedömer hela
  katalogen.
- **Varför:** samma svarstexter prövas i båda språken (facit), och telefonen tar emot en
  fil bara när PC:n hade tagit emot den.
- **Bortvalt:** en mildare kontroll på telefonen (då kan en fil med fel tal bli Focus);
  att rätta Claudes fel automatiskt (då står något annat i Focus än Claude skrev).
- **Kostnad:** `skapad` prövas nu med en regel (dag, valfri tid och zon) i stället för
  `datetime.fromisoformat`, så att Swift kan pröva samma sak.

## B55 — Underlagets språk och form: skillens svenska, data som kompakt JSON med mallar
*2026-10-23 · prövas · PLAN.md S5b*

- **Valt:** instruktionen är på **svenska**, eftersom den är skillens text ordagrant (B53),
  och Johannes läser rapporten på svenska och skriver svenska till Claude. Filens fritext
  är engelska som förut (B30); instruktionen säger det. Datan är **kompakt JSON** i ett
  kodblock, med fältnamnen ur `analys.json` och minnet (så att skillens text gäller utan
  översättning), en rad per fält och listpost i de två yttersta nivåerna, och en **mall**
  per fel som går att välja med de låsta fälten ifyllda (namn, tal, spann, märkning,
  "klart när", följdfelen med kedjans väg, blocket) och valen (övningarna, stegen, testen).
- **Varför:** Claude läser JSON säkrast när talen ska skrivas av exakt, och kontrollen
  jämför tal för tal; mallen gör att Claude bara väljer och skriver tanken. Svenska ger ett
  par procent längre text (å, ä, ö är två byte) men ingen översättning som kan glida.
- **Storleken (METOD MT11):** gröna fel står inte i `bedomning`, fel som är gröna i alla pass
  inte i `historik`, och mallarna är högst tre nya fel plus övningarna som fortsätter. Ett
  typiskt pass med två vyer, sex pass och en övning som fortsätter: ≈ 7,1 kB data och
  8,0 kB instruktion, ≈ 15,3 kB totalt; ett pass i en vy utan minne ≈ 2,6 kB data; det
  värsta fallet i facit (många grundorsaker) ≈ 15,4 kB. Provet håller instruktionen under
  8 KiB, det typiska passets data under 7,5 KiB och varje historik under 24 KiB.
- **Bortvalt:** engelska (en översatt kopia av skillen, eller engelsk rapport till
  Johannes); en tabell i Markdown (kortare, men talen och listorna, som `vag` och
  `spann`, skrivs av sämre); indenterad JSON (≈ 40 % längre); kontaktarken (Claude i appen
  får bara text).
- **Omprövas:** om Claude-appens svar ofta faller i kontrollen (B54) eller rapporten blir
  sämre än på PC:n.

## B56 — En sak följs i sin klubba och vy, och varje klubba analyseras för sig
*2026-10-23 · gäller · Johannes beslut · PLAN.md S5b*

- **A. Uppföljningen:** en sak att jobba på följs bara upp på pass med samma vy och samma
  klubba (och längd) som när den valdes. Ett pass med en annan vy eller klubba påverkar inte
  dess läge, avslutar den inte och räknas inte som "utan rörelse". Ett val gäller passets
  huvudklubba, och avslutar bara saker i samma klubba vars vy passet har (för tempot: vyn som
  tempot togs ur). Ett val för ett pass som inte finns i sammanhanget läses inte, och
  telefonen ger underlaget bara valen för passen den jämför med.
- **B. Flera klubbor i ett pass (PC:n):** varje klubba analyseras för sig och bedöms mot sin
  egen baslinje. `analys.json` har huvudklubban överst (`huvudklubba`, flest mätta slag, vid lika
  den som sorterar först) och de andra i `delar`; "Att jobba på" gäller huvudklubban. Varje
  klubba blir en enhet i historiken (`analys.enheter`), så att en annan klubbas del av ett
  pass bär baslinjen för den klubban.
- **C. PC:n väljer som telefonen:** baslinjen och förra passet (`analysera`), minnet
  (`historik.ovningar`, `minne`) och underlaget (`underlag.ur_historik`) tar bara tidigare
  enheter med samma klubba och längd; vyn skiljer baslinjen per mått (METOD M27) och
  uppföljningen per sak (A). Förra passet är det senaste med en gemensam vy.
- **Klubbans id:** "j7", som i paketet och `PassSetup.club`, inte etiketten "7i".
- **Varför:** ett 7-järn och en driver är inte samma sving (B45), och ett DTL-pass säger inget
  om ett FO-mått. Förut avslutade ett val på en annan klubba en sak, och ett pass utan
  måttet räknades som ett pass utan rörelse.
- **Bortvalt:** att para klubbor över delar av ett pass; ett `att_jobba_pa.json` per klubba
  (formen är kontraktet med appen och bär ingen klubba).
- **Kostnad:** analyser från före B56 saknar `klubba` och tar klubban ur `klubbor` när den är
  en; kör session.py igen för pass med flera klubbor.
- **Omprövas:** om Johannes vill välja saker för en andra klubba i samma pass.

## B60 — Knapparna för Claude-appen: en rad i passet och på Today, svaret i ett blad
*2026-10-24 · prövas · PLAN.md S5b-2*

- **Valt:** "Ask Claude" och "Paste from Claude" som två grå textknappar på en rad med en
  tunn linje ovanför: i passet under måtten (och längden), och på Today under det senaste
  passets rader, före Focus. Raden visas bara för ett mätt pass. Ask lägger texten i
  urklippet och visar "Copied" i grått; finns Claude-appen visas "Open Claude" bredvid, som
  öppnar `claude://`. Paste läser urklippet först efter trycket, så att iOS frågar om
  tillåtelse att klistra in. Ett godkänt svar visas i ett blad med sakerna som i Focus
  (`SakVy`), "Use" och "Cancel"; har passet redan en fil frågar bladet "Replace the focus
  from …?" innan den skrivs över. Ett svar för ett äldre pass än Focus sparas med "Save", och
  en grå rad säger att Focus är kvar ("Saved for Nov 10 · Focus stays Nov 13"). Ett ogiltigt
  svar ger en vit rad under knapparna med fältet och kodens text (METOD MS18), och inget
  ändras. "Use" sparar som "Import focus", så att `Store.focus`, Today och accenten (B31)
  följer med direkt.
- **Dataregeln i urklippet:** texten och svaret bär passets mätningar. Texten läggs därför bara
  på telefonen (`localOnly`: Universal Clipboard för den inte till Macen) och går ut efter 600 s
  (METOD MS18), och urklippet töms efter "Use" när det fortfarande är Claudes svar. Det Johannes
  klistrar in i Claude-appen skickar han själv.
- **`LSApplicationQueriesSchemes: [claude]`** står i project.yml: utan den svarar
  `canOpenURL` alltid nej.
- **Varför:** B13 och Todays enkelhet: ingen ikon, ingen primärknapp och ingen förklaring;
  raden sitter vid passet den gäller. Bladet visar vad som sparas innan något skrivs.
- **Bortvalt:** en meny i passets rad (bredvid "Send to PC"), där "Copied" och felet inte
  får plats; `PasteButton` (ingen fråga, men den ritar en egen systemknapp utanför
  formspråket och Johannes ska se frågan); en dialog för frågan om att skriva över (den går
  inte att rita i provet); att öppna Claude-appen med texten i adressen (texten är ≈ 15 kB).
- **Kostnad:** "Open Claude" bygger på att Claude-appen svarar på `claude://`, vilket inte
  är prövat (simulatorn har ingen Claude-app). Efter 600 s är texten borta ur urklippet och
  Ask får tryckas igen.
- **Omprövas:** efter telefonprovet med Claude-appen på rangen.

## B57 — Klubban framifrån i appen: samma märkning, ingen riktpinne, P2/P6/P8 ur skaftets vinkel
*2026-10-23 · prövas · PLAN.md S7a · METOD M45, M46, M49 · Johannes beställning (S7a-FO), rättat efter granskningen 2026-10-24*

- **Valt:** "Mark club" i granskningen också för FO-serier, med samma flöde som bakifrån (B47):
  grepp och hosel vid varje position med förstoringsglaset (3 ×), ringen ur handlederna som
  greppets förslag, sparning av sig själv när hoseln satts, ångra och positionsraden, i
  ordningen från B58. `ClubMarking` bär vyn och svingens `xTecken` (inga standardvärden).
  Riktpinnen visas inte framifrån: där ligger mållinjen i bildens plan, och inget FO-mått
  behöver flyktpunkten (M48, M49).
- **P2, P6 och P8 framifrån** är rutan där skaftet är vågrätt i bild (M45). Eftersom de märks
  sist (B58) är ändarna markerade, och förslaget är rutan där skaftets vinkel, linjärt i tiden
  mellan dem, går genom vågrätt, åt svingens håll (`Klubba.forslagTidSkaft`,
  `klubba.forslag_tid_skaft`, samma tal i Python och Swift, B12). P2 räknas från
  baksvingens start (`ShotMeasure.start`, M4) när den ligger efter P1, eftersom skaftet står
  still i adressen; från P1 hamnade förslaget cirka 0,1 s för tidigt på de påhittade
  svingarna. Mer än 270° åt svingens håll mellan ändarna är fel håll och ger inget förslag.
  Utan förslag ur skaftet (en ände hoppad, fel håll) gäller kroppens tider. Förslaget gäller
  också en hoppad position; en markerad position visar sin egen ruta.
- **Två parade telefoner:** M45 tar DTL:s P2/P6/P8 ur FO-serien. Logiken finns i SwingLabKit
  (`ClubPairTime`): parningen ska vara DTL mot FO (den styrandes vy i `par.json` och
  följarens), klickparet tas ur parningen med index i var sin telefons klick, och
  FO-markeringens tid förs över med träffens förskjutning (MS6). `ClubMarking` föreslår den
  tiden bakifrån när den finns, annars kroppens. **Inte inkopplat i appen:**
  FO-telefonens markeringar finns bara på FO-telefonen, och ingen väg för dem till
  DTL-telefonen finns än (länken bär bara serierna och klicken, B21–B22). PC:n märker inte
  P-positioner (B44), så förslaget prövas bara i Swift.
- **Uppställningen framifrån:** "Facing the player, at hip height, aimed square to the target
  line" (appens uppställning, String Catalog, B33). Mätt i 3D från just den uppställningen
  (M49): höjden flyttar casting 2,3° per 0,2 m och sidoläget längs mållinjen casting 1,6° och
  skaftlutningen 0,7° per 0,1 m, medan vridningen på plats flyttar varje mått högst 0,21° per
  grad. Alla FO-mått har egen baslinje, så det som räknas är att uppställningen är densamma
  pass mot pass.
- **Bortvalt:** att ta P2 framifrån ur kroppens tider även när ändarna är markerade (skaftets
  vinkel säger mer om just den svingen), riktpinnen framifrån, och att skicka markeringarna
  mellan telefonerna i det här steget (ett nytt meddelande på länken eller en import av
  paketet, prövas inte utan två telefoner).
- **Kostnad:** samma 26–35 tryck per sving som bakifrån (M45), utan riktpinnens två.
  Kamerans rullning går 1:1 in i skaftets vinkel, toppen och skaftlutningen (inte i casting);
  lodlinjen (MS17) rättar den inte än.
- **Omprövas:** när Johannes markerat FO-svingar på telefonen (förslagets avstånd i rutor till
  den ruta han valde), när två telefoner används på riktigt (vägen för FO:s markeringar), och
  när lodlinjen rättar rullningen.


## B58 — Märkningens ordning: kroppens positioner först, skaftets sist
*2026-10-24 · gäller · Johannes beslut · ändrar ordningen i B47 · METOD M45*

- **Valt:** märkningen går igenom P1, P3, P4, P5, P7, P9, P10 och sist P2, P6, P8, i båda
  vyerna (`ClubMarking.order`). Positionsraden visar den ordningen, och nästa position efter
  en sparad eller hoppad är nästa i den. Markeringarna sparas ändå i svingens ordning
  (`pass.json`, `klubba.json`).
- **Varför:** P2, P6 och P8 definieras av skaftet, och deras förslag bygger på positionerna
  runt dem: framifrån skaftets vinkel mellan ändarna (B57), bakifrån FO-parets tid när den
  finns, annars kroppens tider (M45). Med ändarna markerade först gäller förslaget ur skaftet
  varje gång, inte bara vid en ommärkning.
- **Bortvalt:** P1–P10 i svingens ordning (B47), där P3 inte var markerad när P2 märktes; en
  egen ordning per vy.
- **Kostnad:** raden står inte i svingens ordning, och videon hoppar tillbaka i svingen för
  P2, P6 och P8.
- **Omprövas:** när Johannes märkt svingar på telefonen.

## B59 — Märkningsläget är ett verktyg: en instruktionsrad, en guide och inzoomat, undantag från B13 bara där
*2026-10-24 · prövas · PLAN.md S7c · METOD M45 · Johannes ja, efter att ha provat S7a på telefonen*

- **Varför:** Johannes förstod inte vad han skulle göra i S7a:s märkning: "Grip" ensamt,
  "Stick", ringen och en Next som såg spärrad ut, och klubban var liten i bild. Han, och i
  förlängningen andra, ska förstå direkt.
- **Valt:**
  - **Instruktionsraden** överst, i klartext: "1 · Tap the grip", sedan "2 · Tap the
    clubhead", bredvid en liten svartvit skiss av en klubba (Canvas, inga bilder) där punkten
    som nästa tryck sätter lyser: mitt på greppet (mellan händerna), respektive där skaftet
    går in i huvudet. Ordet "hosel" finns inte längre i appen, inte heller i katalogens
    infoblad; i data, formatet och METOD betyder klubbhuvudets punkt fortfarande hoseln (B44).
  - **Zoom:** varje position öppnas inzoomad 2,5 × kring skaftets förväntade mitt, ur
    grannens markering och handlederna, och lägre bara när en cirkel med radien 0,6 · skaftet
    inte får plats (M45); nyp zoomar (högst 8 ×), dra panorerar och dubbeltryck växlar mot
    hela bilden. Trycken blir hela bildens pixlar som förut (provat i `KlubbYtaFixturer`, samma i
    Python). Förstoringsglaset finns kvar och förstorar 3 × ovanpå zoomen.
  - **Punkterna heter 1 och 2** i bilden, och skaftlinjen dras mellan dem när båda är satta.
  - **Gissningen:** ringen ersätts av en ihålig punkt märkt "1?" vid handledernas mitt. Ett
    tryck på den godtar den (källan `handlederna_bekraftad`, B47); ett tryck någon annanstans
    sätter greppet där.
  - **Positionen i klartext** i märkningens ordning (B58): "P4 · Top of backswing · 3 of 10"
    (`Texter.positionsnamn`: kroppens positioner som M28, skaftets som Sportsbox BCH, DCH och
    FCH, research 5a). Next är borttagen, eftersom appen går vidare själv till nästa position
    som saknar markering; "Not visible" heter "Skip"; Undo finns kvar. På en markerad position
    heter knappen Next och ändrar ingenting, och ett helt markerat slag öppnas som "All
    positions done" (granskningen 2026-10-24: Skip skrev över en markering).
  - **Riktpinnen** är ett eget valfritt steg bakifrån, en gång per serie före P1: "Optional:
    tap both ends of an alignment stick on the ground", med en skiss och Skip och Done. Skip
    sparas i serien (`riktpinneHoppad`), så att steget inte kommer igen. Knappen Stick är
    borta ur raden; menyvalet "Alignment stick" öppnar steget igen för att sätta om pinnen
    eller ta bort den (Remove).
  - **Guiden** första gången märkningen öppnas, tre bilder: greppet, klubbhuvudet och klart
    (skaftlinjen och att appen går vidare själv); "?" öppnar den igen. Att den visats sparas i
    användarens inställningar (`clubGuideSeen`).
- **Formen:** märkningsläget är ett verktyg, och ett verktyg som ska användas utan förkunskap
  får en instruktionsrad och en guide. Det är ett undantag från B13 (design/README regel 5 och
  9), och det gäller **bara** märkningsläget: resten av appen har fortfarande ingen
  beskrivande text. Svartvitt, accenten bara som förut (B31, inte här), engelska och String
  Catalog (B30, B33). VoiceOver läser instruktionen som rubrik och positionen i klartext.
- **Bortvalt:** att behålla ordet "hosel" (golfens fackord, men inte ett ord man förstår
  direkt), en film eller animation i guiden (B13 regel 1), riktpinnen som en knapp i raden
  (den förstods inte), och att zooma så att hela klubban alltid syns (då blev klubban liten
  igen; nyp och dubbeltryck ger hela bilden när den behövs).
- **Kostnad:** fler texter i märkningen, ett steg till bakifrån första gången per serie, och
  en gest till att lära sig (dubbeltrycket ångrar ett första tryck som satte en punkt).
- **Omprövas:** när Johannes märkt svingar med S7c på telefonen: om instruktionen och guiden
  räcker, om 2,5 × är rätt start och om dubbeltrycket krockar med trycken.
---

Besluten B61–B63 kommer ur S6c-2 (3D i appen, grenen `s6c2`). Lucka: s7afo tar B57–B59.

## B61 — 3D på telefonen: följaren skickar slagen efter analysen, den styrande räknar
*2026-10-24 · prövas · PLAN.md S6c-2 · METOD MS19, M50*

- **Valt:** när följarens slag är analyserade (Vision) skickar den dem till den styrande över
  PhoneLink: ett paket utan video (`SlagBunt`, `swinglab-slag/1`: manifestet, enhet.json,
  par.json och lederna per slag i kompakt form, docs/FORMAT.md). Stora meddelanden delas i
  bitar om 192 kB (`part`, version 1), varje bit kvitteras och allt som inte kvitterats skickas
  igen när kopplingen kommer tillbaka; helheten kvitteras först när den är sparad
  (`Pass/<id>/annan_telefon.json`). Den styrande räknar 3D med `TreD` i `Task.detached` när
  båda telefonernas slag är analyserade, sparar `tre_d.json` i passet och skickar den tillbaka;
  följaren sparar samma fil. Båda visar alltså samma tal. 2D-faserna (start och topp) räknas på
  telefonen ur samma leder och med samma kod som PC:ns `analys.mat_paket` (MS19).
- **Kopplingen i passet:** PhoneLink startas i passets skärm för ett pass med rollen Lead eller
  Follow, eftersom lederna finns först efter Analyze, när kameran är stängd. Båda telefonerna
  ska alltså ha passet öppet en stund efter analysen. Ett pass räknas om när någon telefons slag
  ändras (Detection wrong, domen, redigeringen): `tre_d.json` bär buntarnas summor. Den
  styrandes fil är facit; en följare som räknat själv efter en import tar den styrandes fil när
  den kommer.
- **Vem som kopplas (granskningen, Dataregeln):** hello bär syftet (`mode`: inspelningen eller
  passets 3D) och förmågorna (`caps`). Passets koppling tar bara en telefon med samma syfte och,
  när den är känd, **bara den telefon som passet parades med vid inspelningen**: telefonens id
  är ett slumptal som är stabilt per installation, och partnern sparas i passets mapp
  (`partner.json`, inte i paketet). Lederna går alltså aldrig till en tredje telefon i rummet.
  Ett nej med skäl (ett annat pass, en annan version, ett innehåll som inte går att läsa) syns som
  en grå rad hos följaren, som slutar skicka och kan importera i stället.
- **Reserven:** "Import other phone" i passet läser den andra telefonens paket
  (`swinglab-<pass>-<vy>.zip`, Send to PC) ur Filer eller AirDrop, fil för fil utan klippen,
  till samma bunt. Den telefon som importerar räknar själv.
- **Varför:** Johannes mål (2026-10-23) är att så mycket som möjligt görs på telefonen. Lederna
  är det enda 3D behöver; videon stannar på sin telefon (BESLUT B22). En överföring per pass
  efter analysen i stället för per serie under passet, eftersom lederna inte finns förrän då.
- **Bortvalt:** att skicka per serie under inspelningen (lederna finns inte än); att skicka
  ledfilerna som JSON (cirka 4 gånger större); zlib (finns inte i Foundation på Linux, där
  logiken prövas); att följaren också räknar (två räkningar som kan skilja); att räkna på PC:n
  bara (B48:s mål).
- **Kostnad:** cirka 105 kB per slag i bunten och 140 kB på kopplingen (960 rutor, MS19), 2–3 MB
  för ett pass om 20 slag. En äldre app (bygget före S6c-2) har inget syfte i hello och kopplar
  inte till passets koppling, och den stänger förbindelsen vid en okänd meddelandetyp; båda
  telefonerna ska ha samma bygge. Följaren måste ha tagit den styrandes pass-id (S2g), annars
  får den ett nej och importen är vägen. Ett pass från före S6c-2 har ingen känd partner.
- **Omprövas:** efter telefonprovet med två telefoner (PLAN S6c-2).

## B62 — 3D i appen: kortet i passet, trenden i Progress och lutningen i uppställningen
*2026-10-24 · gäller · Johannes godkände utformningen · PLAN.md S6c-2 · METOD MS19*

- **Passet:** ett kort "3D" med rubriken "3D · no markers" i grått och de fem måtten (Pelvis
  turn at the top, Shoulder turn at the top, X-factor at the top, X-factor stretch, Hips open at
  impact): passets median, skillnaden mot förra passet med 3D ("+3.1° vs Nov 10", grå, ljusare
  när den är tydlig enligt MK7) och antalet svingar. Kortet syns bara när passet har
  `tre_d.json`. Skälen (hoppat, osaker, utelämnade, färre än 10) står korta och i grått, och
  kortet visar aldrig ett tal där skälet säger nej. Ett tryck på en rad öppnar infobladet (B41).
- **Progress:** de fem måtten är valbara bland de andra, sist, när något pass har 3D. Varje punkt
  är ett pass, median över minst 10 svingar, med passmedianens ungefärliga fel som ett tunt
  spann (felbudgetens SD med typiskt brus, MK7). Inga gränser och inget grönt eller rött (B14,
  B37); spannet 35–45° för höfterna visas inte än.
- **Uppställningen:** en tunn horisontlinje över kamerans bild med lutningen åt sidan i grader,
  svartvit och utan värdeord; över 45° från lodlinjen står "Tilt too large for 3D" (B39, MS17).
  Linjen är en egen vy (`LutningVy`) som inspelningen bara visar.
- **Today** ändras inte.
- **Katalogen:** 3D-måtten flyttar från `katalog_3d.json` till `katalog.json` (listan `tre_d`) och
  Swift-fixturerna, med infobladets `vad`, `varfor` och `tecken` (B37:s kostnad, B41). PC:n läser
  samma lista (`katalog.las_3d`).
- **Bortvalt:** gränser eller färg för 3D utan markörer (B14); 3D på Today; en egen flik.
- **Omprövas:** när markörerna ger mått per sving (B14).

## B63 — Paketet: telefonens 3D följer med, och PC:n räknar själv och jämför
*2026-10-24 · prövas · PLAN.md S6c-2 · METOD MS19*

- **Valt:** `tre_d.json` följer med i paketet (Send to PC) när passet har den. PC:n räknar 3D själv
  som förut och är facit (B12); `analys.json` får `tre_d.telefon`: samma parning,
  uppställningar, skäl och avrundade fält, och största skillnaden per slag mot 0,05°
  (`tva_kameror.jamfor_telefon`), och session.py skriver en rad. En fil som inte går att läsa
  stoppar inget (`tre_d.telefon.fel`).
- **Varför:** S6c-2:s "Klart när" är att telefonen ger samma tre_d som PC:n på riktiga leder;
  jämförelsen gör varje pass till ett prov, utan att PC:n litar på telefonen.
- **Bortvalt:** att PC:n tar telefonens tal (då finns inget facit), och att PC:n slutar räkna 3D.
- **Omprövas:** när riktiga pass visat att telefonen och PC:n är lika.

## B70 — Spåren i granskningen: chips under videon, gråtoner, det spelade fast
*2026-10-24 · prövas · PLAN.md S4f · METOD M60 · Johannes beställning 2026-10-24, granskad 2026-10-24*

- **Varför:** Johannes vill se hur händerna, axlarna, höfterna, huvudet och klubbhuvudet rört
  sig genom svingen, och i förlängningen en 3D-figur (S6d).
- **Valt:**
  - **Valet** är en rad chips direkt under videons kontroller: "Hands · Shoulders · Hips ·
    Head", ett tryck slår på eller av. Ett påslaget chip visar sin linje (gråton och streck)
    och är därmed teckenförklaringen; inget annat behöver läsas. "Club" visas först när S7b
    kan ge klubbhuvudets bana. Valet sparas per användare (`AppSettings.trails`), så att samma
    spår står kvar i nästa slag och nästa pass. VoiceOver läser raden som "Trails" och varje
    chip som en växel ("Hands trail").
  - **Färgen:** svartvitt (B13). Händerna vit 1,6 pt, axlarna grå hel, höfterna grå med långa
    streck, huvudet vita runda prickar, klubbhuvudet vit 2 pt (interpolerade rutor streckade);
    ingen av dem liknar en osäker leds streckade linje. **Ingen accent:** ett spår är inget
    mått, och accenten betyder bara det som övas (B31).
  - **Ritningen:** hela banan svagt (opaciteten 0,30) och det som spelats upp fast ovanpå.
    Hela banans form syns från första rutan, och det spelade växer med videon. En svart kant
    (opaciteten 0,5, 1,5 pt bredare) under varje linje håller den synlig mot en ljus
    bakgrund. Spåren är ett eget lager under lederna och oberoende av ögat, och med ett spår
    påslaget ritas lederna gråa, så att spåren skiljer sig från dem.
  - **Återanvändningen:** datamodellen (`SparSerie`: namngivna punktserier i bildens pixlar
    med tider) och delningen (avbrott, spelat och kvar) återanvänds av S7b:s bana och av 3D
    (S6d); 3D ritar med en egen vy.
- **Bortvalt:** en meny bakom en symbol (valet syns då inte och linjestilarna får ingen
  förklaring), att rita bara det spelade (banans form syns först i slutet), att inte rita
  resten alls, färger per punkt (B13), och skuggor (en kant under linjen är ingen skugga, den
  följer linjen exakt).
- **Kostnad:** en rad till i granskningen (28 pt) och ett chip per punkt som måste få plats i
  telefonens bredd.
- **Omprövas:** när Johannes slagit på spåren på telefonen: om chipsen är tydliga, om 0,30
  och kanten räcker mot en ljus bakgrund, och om axlarna och höfterna ska vara mitten i
  stället för två linjer var.

## B71 — Klubbhuvudets bana: rörelsedifferens mellan grannankare på telefonen, planet utan tal än
*2026-10-24 · prövas · PLAN.md S7b · METOD M61 · Johannes beställning 2026-10-23 och 2026-10-24, granskad 2026-10-24*

- **Varför:** Johannes vill se klubbhuvudet hela vägen genom svingen, och S7:s detektor
  behöver fler märkta rutor än trycken vid P1–P10.
- **Valt:**
  - **Spårningen** är mekanisk (M61): rörelsedifferens mot rutorna 2/240 s före och efter med
    en brusanpassad tröskel, kroppen maskerad ur Visions leder, en korridor kring greppet med
    ankarnas skaft, fläcken vars yttre kant ligger närmast skaftets längd, och prövningar som
    tappar en ruta hellre än låser fel (skak, radien, språnget, grannarna). Ingen tränad
    modell. Där den tappar interpoleras banan mellan säkra punkter och rutan märks
    interpolerad.
  - **Bara mellan grannar i svingens ordning** (P1→P2→…→P10): granskningen visade att P1+P7
    gav en bana över halva svingen som var fel med en skaftlängd. Saknas en position ritas
    inget där, och chipet Club visas först när två grannpositioner är markerade.
  - **På telefonen** i SwingLabKit (`KlubbSpar`, bara Foundation, testbar på Linux) med
    Python som facit (`klubbspar.py`, B12). Appen läser rutorna ur seriens fil en gång i
    tidsordning (`RutStrom`, Y-planet vridet upprätt, en ringbuffert i stället för hela slaget
    i minnet); Kit vet inget om video.
  - **Räkningen** ligger i `Store`, en i taget och per slag, och startar bara när Club slås på
    (eller trycks när banan saknas för slaget), aldrig när ett slag öppnas. Den avbryts när
    Club slås av eller granskningen stängs. Passet läses om ur disken innan banan sparas, och
    den sparas bara om markeringarna inte ändrats under tiden. Saknas filen eller mer än 10 %
    av rutorna sparas ingen bana; en grå rad under chipsen säger varför.
  - **Facit** är en påhittad film i båda språken med samma bytes (hashat brus, summan per
    ruta i fixturen), och i Python varianter med det som riktiga klipp har (M61: bakifrån,
    oskärpa, låg kontrast, textur med skak, boll, skugga, huvudets mitt bredvid hoseln, glesa
    ankare). Varianterna genereras i proven och checkas inte in.
  - **Visningen** är S4f:s spårlager (`SparLager`, B70) med chipet Club: en bredare vit linje
    med en ring där huvudet är i rutan (händerna har en prick), fast där den spelats och
    streckad där den är interpolerad. Bakifrån ritas P1-skaftets linje förlängd och märkt
    "P1 plane", bara när banan är räknad ur dagens markeringar. VoiceOver läser om banan räknas
    och hur många rutor som är interpolerade.
  - **Planet genom nedsvingen** räknas (P5–P7 per ruta mot P1-linjen, M47:s geometri) men
    **visas inte som tal** förrän banan prövats mot handmärkta rutor på riktiga klipp.
  - **Datamodellen för träningen:** banan sparas per slag (`ShotRecord.klubbaBana`) med
    ankarna den räknades ur, och varje ruta bär källan (`klick`, `spar`, `interpolerad`) och
    `granskning` (ogranskad, `godkand` eller `rattad`; en rättad ruta behåller maskinens
    punkt och dess källa). I filen är banans rutor `val: "bana"` i **`swinglab-klubba/3`**
    (FORMAT.md); `samla_klubba.py` skriver version 3 när ett pass har en bana, ersätter banan
    per slag med den senaste, och räknar aldrig banans rutor som markeringar. Banan blir alltså
    aldrig S7:s indata som om den vore en markering. Godkänna och rätta byggs senare.
- **Bortvalt:** en tränad detektor nu (S7, kräver märkta rutor), spårning utan ankare (gav 22
  handrättningar och en hårdkodad mask i förebilden 2026-10-20), en bana mellan ankare som
  inte är grannar, att gissa genom kroppen i stället för att interpolera, en fast tröskel
  (en låg kontrast försvann), spökbilder av klubbhuvudet (omprövas med banan på riktiga
  klipp), planet som tal, och att räkna banan när ett slag öppnas.
- **Kostnad:** några sekunders räkning per slag första gången Club slås på, många
  interpolerade rutor där klubban syns dåligt (45 % i den påhittade filmen, 74 % bakifrån),
  och en ny formatversion.
- **Omprövas:** när banan provats på riktiga DTL-klipp mot handmärkta rutor (S7b:s Klart
  när): gränserna i M61, särskilt bakifrån, mitten mot hoseln, om planet kan visas som tal,
  och spökbilderna.

## B72 — Figuren i 3D: lederna och kamerorna sparas på telefonen som räknar, inte i paketet
*2026-10-24 · prövas · PLAN.md S6d · METOD MK10 · Johannes mål 2026-10-24: Lead-telefonen gör hela analysen*

- **Valt:** den telefon som räknar 3D (den styrande, eller den som importerade) sparar i samma
  räkning kedjans triangulerade leder per slag och kamerorna per uppställning i passets mapp,
  `tre_d_figur/` (docs/FORMAT.md "Figuren i 3D"): ett index och en fil per slag, lederna som
  int16 i mm. Världen är kalibreringens med lodlinjen uppåt och FO-kameran i origo, i meter med
  skalan ur benens längd (MK10). `TvaKameror.analysera` lämnar uppställningarnas kameror och
  trianguleringar genom en valfri samlare, även när passet sedan hoppas över, så att kedjan
  inte räknar om något och måtten är oförändrade. Python är facit (`tools/pc/tre_d_figur.py`,
  B12).
- **Ingen figur där skälet säger nej:** en uppställning över spärren (eller vars kalibrering
  inte gick) får ingen figur. Över spärren sparas ändå kamerorna, Sampson-felet och vinkeln,
  för det är just där uppställningen behöver synas (första riktiga passet, 2026-10-24:
  kamerorna 165–177° isär). Ett slag i en uppställning som mättes får figuren även när dess
  mått fallerade (t.ex. faserna saknas): figuren beror på kamerorna, inte på adressen.
- **Inte i paketet:** B63 säger att `tre_d.json` följer med; figuren gör det inte. PC:n räknar
  sin egen figur i visaren (S6f), och paketet växer inte med cirka 2 MB per pass.
- **Skalan ur benen, inte näsan:** visarens första regel, näsan över fotlederna (0,89 × längden), antar en upprätt
  hållning; i en sving är spelaren böjd större delen av tiden, och på facit blev figuren 27 %
  för stor (kamerorna 4,0 m bort i stället för 3,15 m och 1,16 m upp i stället för 0,93 m).
  Lår och smalben (0,491 × längden) är lika långa i varje hållning och gav 3,20 och 0,93 m.
- **Följaren** får bara `tre_d.json` (B61) och har ingen figur; raden "3D" visas där
  figuren finns och har något att visa. **Ett pass räknat före S6d, eller med en figur ur en
  äldre kedja** (`kedja` i indexet, MK10), räknas om en gång när passet öppnas: hela 3D,
  också `tre_d.json`, så att figuren och måtten kommer ur samma räkning. Talen i kortet kan då
  ändras (en ändrad 2D-analys sedan förra räkningen följer med). Samma buntar prövas bara en
  gång per gång passet är öppet, även när figuren inte gick att skriva.
- **Skalan** har ett skydd (MK10): benen i adressen, sidorna inom 10 %, och kamerorna på ett
  rimligt avstånd och i rimlig höjd; annars reserven med skälet i indexet och ingen mark.
  PC:ns visare använder samma funktion (B12).
- **Lagringen:** figuren skrivs i en ny mapp som ersätter den gamla (rester av en avbruten
  skrivning tas bort först) och ligger utanför backupen, eftersom den räknas om ur passets
  leder.
- **Bortvalt:** att spara figuren i `tre_d.json` (en fil på 2 MB som läses för kortet och
  skickas till följaren), JSON-tal per led (cirka 4 gånger större), att räkna figuren när vyn
  öppnas (sekunder att vänta, och kedjan körs två gånger), och figuren i paketet.
- **Kostnad:** cirka 100 kB per slag på telefonen, och räkningen tar några tiondelar längre
  (slagen i en uppställning över spärren trianguleras för skalan).
- **Omprövas:** när S6g för över klippen (då kan figuren läggas över videon), och när PC:n
  ska jämföra telefonens figur med sin egen.

## B73 — Figurens vy: Canvas med egen projektion, vinklarna ur kroppen, granskningens tidslinje
*2026-10-24 · prövas · PLAN.md S6d · METOD MK11 · Johannes beställning 2026-10-24*

- **Valt:** passets kort "3D · no markers" får en rad "3D" som öppnar figuren i helskärm.
  Figuren är streck och leder, vit på svart (B13): personens vänstra sida vit med fyllda
  leder, den högra grå med ihåliga (som miniatyren vid träffen), näsan som en större prick,
  och det bortre svagare så att djupet syns utan ytor. Under den en tunn markyta (ett rutnät
  om 0,5 m) och mållinjen streckad med en pil mot målet.
- **Ritningen är SwiftUI:s Canvas med en egen perspektivprojektion** (`TreDProjektion` i
  SwingLabKit), inte SceneKit eller RealityKit. En figur av streck har inga ytor som behöver
  djupbuffert; Metal ritar linjer en pixel breda, medan Canvas ger formspråkets linjebredder
  och streck och samma linjestilar som S4f:s spår; och simulatorprovet ritar Canvas med
  ImageRenderer, vilket det inte gör med en Metal-vy. Geometrin (vinklarna, projektionen,
  klippningen bakom ögat) prövas på Linux.
- **Vinklarna:** Face on, Down the line och Top som ett segment; ett finger vrider (runt
  lodlinjen och i höjd), nypning zoomar, dubbeltryck går tillbaka till vinkeln. Riktningarna
  tas ur kroppen i adressen (MK11), inte ur telefonernas lägen, så att en fel uppställning
  inte vrider vyerna.
- **Tidslinjen är granskningens:** spela och pausa, ruta för ruta (1/240 s), dra i tidslinjen
  med P1–P10 som streck, och positionsraden som hoppar dit; farten 1/8 (som granskningen), 1/4
  eller verklig tid. Spåren är S4f:s chips och linjestilar (Hands, Shoulders, Hips, Head),
  delade i spelat och kvar med `SparSerie`; valet är samma som i granskningen. Club visas inte
  förrän klubbhuvudet finns i båda vyerna (S7b på båda telefonerna och S6g).
- **Telefonerna:** valet "Cameras" ritar båda telefonerna där kalibreringen placerade dem (en
  pyramid ur K och R med bildens överkant markerad och vyns namn), vidgar vyn så att de syns,
  och visar Sampson-felet mot spärren och vinkelen mellan dem mot 60–120°. Ett pass över
  spärren öppnar på telefonerna.
- **Skälen** står i grått (S6c-2:s korta texter): utan 3D bara skälet och ingen figur, över
  spärren "Sampson error over the limit: no figure", och en vinkel utanför 60–120°.
- **Prestanda:** bara slaget som visas läses, utanför huvudtråden, och läsningen avbryts när
  slaget byts. Riktningarna och spåren räknas en gång per slag och val, inte per ruta.
- **Bortvalt:** SceneKit (enklast av de två, men linjerna blir hårstrån och provet ritar dem
  inte), RealityKit (byggt för AR och ytor), en modellerad kropp (B13), vinklarna ur
  telefonernas lägen, en egen tidslinje.
- **Kostnad:** ingen djupbuffert (ett streck bakom ett annat ritas efter avståndet, inte per
  pixel), och perspektivet skrivet för hand.
- **Omprövas:** när Johannes vridit figuren på telefonen: om den syns och förstås, om
  vinklarna är de han vill ha, och om markytan och mållinjen räcker som referens.

---

Besluten B80–B83 kommer ur S6g (videon från båda telefonerna på den styrande, Johannes
2026-10-24). Numren börjar ovanför S6d:s, som byggs parallellt.

## B80 — Videon till den styrande: den styrande begär svingarnas klipp, följaren strömmar dem ur filen
*2026-10-24 · prövas · Johannes beställning · PLAN.md S6g · METOD MS30*

Johannes 2026-10-24: "Lead-telefonen ska ha videon från båda telefonerna och kunna göra hela
analysen." B22 sa att kopplingen aldrig bär video; det gäller fortfarande **under** inspelningen
(klicket är synken, ett tapp kostar ingen data). Efter passet bär den nu svingarnas klipp.

- **Valt: den styrande styr (pull).** I passets skärm, på S6c-2:s koppling (syftet "pass", bara
  passets partner, B61), begär den styrande ett klipp per sving (dom sving eller osäker) ur sin
  parning: följarens serie ur `par.json`, och fönstret från **4 s före till 2,5 s efter träffen**
  i följarens fil (den styrandes träff + `traff_forskjutning_s`). Begäran gäller den styrandes
  slag, så ett klick som följaren missade begärs ändå. Begäran (`KlippBegaran`) är en vanlig
  överföring (`part`, `kind: "begaran"`, B61:s kvittenser och nej med skäl) och skickas varje gång
  följaren säger hello och när ett klipp är framme.
- **Följaren skär och strömmar:** klippet skärs passthrough (`AVAssetExportSession`, HEVC som det
  spelades in, ingen omkodning) till `Utskick/<slag>.mov`, och strömmas en bit i taget ur filen
  (`kind: "klipp"`, bitarna om 192 kB med klippets `namn`, högst 8 i luften). Varje bit kvitteras;
  helheten kvitteras först när den styrande sparat `video.json`.
- **Fortsätter där den slutade:** den styrande skriver bitarna i ordning till en `.part`-fil;
  filens storlek är förloppet, också efter att appen startats om. Begäran bär det som redan
  kommit (`har_id`, `har`), och följaren börjar där när klippets summa är samma. En bit längre
  fram får "börja vid `har`", en bit som redan finns kvitteras igen, fel summa börjar om.
- **Följaren behåller hela inspelningen** tills den styrandes begäran säger att allt kommit fram
  (`alltFramme`): "Spara bara klippen" (B26) väntar på det, och de skurna klippen tas bort då.
- **"Get full video"** i passet är reserven: varje parad serie hel (`video-01`), ur originalet
  utan kopia. **Import other phone** (S6c-2, Filer eller AirDrop) tar också klippen ur den andra
  telefonens paket när det skickades med klipp.
- **Raden** "Getting video from other phone · 60 %" hos den styrande och "Sending video to other
  phone · 60 %" hos följaren, grå, bara medan något pågår. `beginBackgroundTask` på båda, så att
  en kort överföring hinner klart när appen läggs undan.
- **Förmågan** `video1` i hello: en äldre app får inga klipp och begär inga.
- **Varför:** den styrande kan då göra hela analysen och visa båda vyerna synkade (B82) utan PC.
  Klippen räcker för analysen och är en bråkdel av inspelningen (MS30). Den styrande vet vilka
  svingar den vill ha och var följaren står, så den styr; följaren behöver inte veta något om
  parningen.
- **Bortvalt:** att följaren skickar på eget initiativ (den vet inte vilka klick den missade);
  hela inspelningarna som standard (minuter i 240 bilder/s är hundratals MB, B26); S6c-2:s
  `PartSender`/`PartReceiver` för video (håller allt i minnet; de bär bara begäran); att koda om
  (tid och batteri, och PC:n vill ha originalets rutor); överföring under inspelningen (klicket
  är synken, B22); mobildata och moln (dataregeln); en egen app-protokollversion (förmågan räcker).
- **Kostnad:** båda telefonerna ska ha passet öppet en stund efter analysen (som S6c-2), base64
  gör kopplingen en tredjedel större än klippen, och följaren har kvar sin inspelning tills den
  styrande kvitterat. Ett klipp som skurits om (följarens app startades om) börjar om från början.
- **Omprövas:** efter Johannes prov med två telefoner (PLAN S6g, Klart när), med tiden och
  storleken på riktiga klipp (MS30).

## B81 — Lagringen på den styrande och paketet: den andra vyns mapp, och två paket
*2026-10-24 · prövas · PLAN.md S6g · METOD MS30, MS31 · docs/FORMAT.md*

- **Valt:** följarens klipp sparas i den styrandes pass under den andra vyn:
  `Pass/<id>/fo/Klipp/<slag>.mov` (den styrandes slag), `fo/Video/<serie>.mov` (hela serier) och
  `fo/video.json` (`swinglab-annan-video/1`: per klipp följarens serie, början, det väntade och det
  mätta klicket, längden, storleken och summan). Mappen ligger utanför backupen (B26). Raderingen
  (B64) tar hela passets mapp, alltså också den andra vyns video; följarens pass rörs inte.
- **Paketet (Send to PC) på den styrande ger två zippar:** sitt eget (oförändrat) och den andra
  vyns, `swinglab-<pass>-fo.zip`, byggt ur följarens bunt (S6c-2: manifestet, enhet.json och
  lederna) och klippen som kommit. Ett klipp läggs på det följarslag vars klick ligger inom 30 ms
  från klippets väntade klick, och `klick_i_klipp_s` flyttas lika mycket som följarens klick
  skiljer från det väntade. **Formatet och kontraktet är oförändrade:** PC:n läser det som om
  följaren skickat det (`paket.py`), provat med appens egna byte
  (`test_appens_paket.py`, `AppensParadePaket`).
- **Bortvalt:** ett gemensamt paket med båda vyerna (ett nytt format för PC:n, och B27:s en zip per
  telefon och pass bär redan 3D-kedjan); klippen under följarens slag-id (ett missat klick har
  inget följarslag; den styrandes slag är det passet visar).
- **Kostnad:** ett klipp för ett klick som följaren missade följer inte med paketet (inga leder
  för det i följarens bunt). Delningsbladet får två filer.
- **Omprövas:** om PC:n ska få klippen för missade klick (då behövs leder ur klippet).

## B82 — Ett parat pass: en rad "Paired", och DTL, FO och 3D i passet
*2026-10-24 · prövas · Johannes beställning · PLAN.md S6g, S4e · METOD MS31 · VISION.md*

Ändrar B64:s rad för ett parat pass på den styrande.

- **Valt: den styrandes rad heter "Paired"** med länksymbolen (dagen, klubban och svingarna som
  förut); följaren har kvar sin rad med sin vy och "paired". VoiceOver: "Paired, Down the line and
  Face on, …".
- **Inne i passet växlar man DTL, FO och 3D** (`Segment` under rubriken). Den här telefonens vy är
  passet som förut (måtten, längden, Claude och slagen); den andra vyn visar sina mått, räknade ur
  följarens leder med passets längd (bara den vyns kort, B64:s filter per vy), och samma
  svingar; 3D visar 3D-kortet (B62), med S6d:s figur när den finns. Under
  växlingen: "14 swings · 12 from both phones", förloppet (B80) och "Get full video".
- **Granskningen** har växlingen DTL/FO ovanför videon när slaget har den andra vyns video. Samma
  rutor, positioner och stegning P1–P10 (den här telefonens leder); den andra telefonens video
  visas på samma träff (MS31), utan leder och spår (de hör till den här vyn), och raderna under är
  den andra vyns mått vid positionen.
- **Varför:** VISION: enkelheten (en rad per pass, ett tryck byter vy) utan att offra djupet (båda
  vyerna och 3D finns kvar, ett tryck bort). Johannes 2026-10-24.
- **Bortvalt:** två rader på den styrande (passet är ett); båda videorna sida vid sida (för små på
  en telefon, och spelaren är en); den andra vyns leder ovanpå (de finns i bunten men inte
  med rutornas tid i klippet; omprövas med S6d); en egen flik.
- **Kostnad:** den andra vyns mått syns först när följarens slag kommit (S6c-2), och dess
  baslinje är bara den styrandes egna tidigare pass med den vyn.
- **Omprövas:** när S6d:s 3D-vy finns, och efter Johannes prov.

## B83 — Samma vy på båda telefonerna: varningen i uppställningen
*2026-10-24 · gäller · Johannes beställning · PLAN.md S6g*

Första riktiga passet (2026-10-24) hade fel vy-etiketter, och då gick 3D inte att räkna (S6f).

- **Valt:** när telefonerna kopplas i uppställningen och den andra har samma vy står
  "Both phones are DTL" i signalfärgen (uppställningens varningar, B13) under kopplingens
  etiketter, med knappen "Switch to FO" så länge passet inte har några serier. Knappen byter den
  här telefonens vy och startar kopplingen om, så att den andra telefonen hör den nya vyn. I
  passet står "Both phones filmed the same view: no 3D" (vit, som B60:s felrad), och den styrande
  begär inga klipp; följaren säger nej till en begäran med samma vy.
- **Bortvalt:** att välja vyn automatiskt (telefonen vet inte var den står), att vägra
  inspelningen (Johannes kan vilja filma ändå).
- **Kostnad:** inga.

## B84 — Granskningen av S6g: klippets början ur filen, inga tysta stopp, och originalen inte för alltid
*2026-10-24 · prövas · granskningen av S6g · PLAN.md S6g · METOD MS30, MS31*

- **Klippets början läses ur filen:** en passthrough-export kan börja på en tidigare I-ruta.
  Den styrande läser videospårets segment: med en edit list börjar klippet där det begärdes,
  annars så mycket tidigare som klippet är längre än begärt. Början sparas (`start_s`), och ett
  klick räknas bara inom 30 ms från det väntade (MS10), inte 0,5 s: ett annat ljud ska inte bli
  synken. Ett slag utan klick märks i den andra vyns lista och i granskningen.
- **Inga tysta stopp:** den styrande säger nej med skälet `disk` (för lite ledigt före första
  biten, eller en skrivning som felar) och passet säger det; följaren säger nej per klipp med
  `saknas` (originalet borta, skärningen gick inte), och den styrande begär det inte igen och döljer
  "Get full video" när originalen är borta.
- **En gammal begäran vinner aldrig:** kopplingen skickar inte en begäran igen vid hello, `nr`
  sparas hos den styrande, och följaren gör inget med en lägre.
- **Följarens original:** tas bort när allt är framme om "Spara bara klippen" gäller och passet är
  exporterat. **Utan begäran** släpps de när den styrande saknar klippen (en äldre app, `video1`
  saknas i dess hello) och annars efter **7 dagar** från passet, också när en begäran aldrig blir
  klar. Bortvalt: att behålla dem tills vidare (telefonen fylls), och att släppa dem direkt efter
  exporten (då finns ingen reserv om kopplingen inte fanns).
- **Taken:** 128 MB per klipp; påbörjade klipp utanför begäran rensas; ett raderat pass skrivs
  aldrig, och den andra vyns mapp ligger utanför backupen från början.
- **"Import other phone"** tar klipp bara ur ett paket från samma pass.
- **Vyerna:** "Paired" och växlingen bara när en följare var kopplad och parades (`par.json` eller
  dess slag finns); "Get full video" bara under den andra vyn, med raden "Video waits for the other
  phone" när kopplingen saknas; den andra vyns lista har inga miniatyrer ur den här vyns video och
  inget utsnitt att redigera.
- **Kostnad:** ett klipp vars klick inte hörs synkas på parningen och märks; en följare som aldrig
  kopplas till en ny app behåller sin inspelning i en vecka.
- **Omprövas:** när riktiga HEVC-klipp visat hur passthrough börjar (PLAN S6g, oprövat).

## B85 — Inspelningens skärm: bara det som kräver ställningstagande, resten bakom kugghjulet
*2026-10-25 · gäller · Johannes beställning och godkända skiss · PLAN.md S2j · METOD MS32*

- **Valt:** skärmen under inspelningen visar bara Close (eller Continue), statusen, kugghjulet,
  inspelningsknappen, en varning när den kräver handling och lutningen när den är över 2°. Under
  serien bara REC-pillen med tiden ("REC 0:42") och stoppknappen. Kugghjulet öppnar bladet
  "Recording" (medium) med This phone, Other phone, Frame rate, Tilt, Swings so far ("~3"),
  Swings heard on both ("· uncertain" när parningen är osäker), Storage, Thermal, Microphone,
  Guide lines och Light test; rader som inte gäller visas inte. Värmen under critical,
  frekvensen när den är rätt och parningens restfel flyttar dit. "Tilt too large for 3D" bara
  med två telefoner. "Other phone stopped recording" först när följaren bekräftat att den spelar
  in i serien (granskningen 2026-10-25).
  Hjälplinjerna går att stänga av, sparat per användare (`installningar.json`).
- **Färgerna, ett undantag från B13 regel 6 bara för inspelningens status:** grönt **#30D158**
  för "Connected", rött för inspelningen (pillen **#D70015**, knappens fält **#FF3B30** i den vita
  ringen, som iPhones kameraapp) och varningens ikon i gult **#F5B54A**. Rutorna är heldragna
  svarta (#000) med vit text, så att texten syns mot all video, och har skissens rundade hörn
  (pillerna halvrunda, rutorna 12 pt), också det bara här. Statusens text är etiketter, inga
  värdeord (B13); lutningens rad "Level the phone" är det enda som säger vad man ska göra, och
  bara när talet är för stort.
- **Ersätter:** inspelningens etiketter för kopplingen (`LinkLabels`, B22: parningen syns nu i
  kugghjulet), varningarna i signalfärgen (B83:s varning är nu den svarta rutan) och lutningen
  som tunn linje hela tiden (B62: nu bara över 2°, för alla roller).
- **Bortvalt:** att visa allt hela tiden (det som varnade blev brus); en egen inställningsskärm
  (ett blad håller kameran synlig); grönt på reglaget för hjälplinjerna (iOS standard): det är
  inte inspelningens status, så det är svartvitt; att räkna svingarna med en egen ljudutgång
  (`AVCaptureAudioDataOutput` bredvid filutgången): nivån ur filens egen ljudkanal rör inte
  inspelningen.
- **Kostnad:** tre nya färger på en skärm. Svingarnas tal är en skattning som kan skilja från
  seriens klick (MS32), så det står i kugghjulet med "~" och flyttar till REC-pillen (skissens
  "REC 0:42 · 3 swings") först när det är kalibrerat på telefonerna. En följare som aldrig
  startar ger ingen varning under serien.
- **Omprövas:** efter första passet med den nya skärmen på telefonerna (PLAN S2j, Klart när),
  och svingarnas plats när räknaren är kalibrerad.

## B86 — Banden ur research 6, preliminärt: Johannes kan ändra per mått
*2026-10-25 · preliminärt · Johannes beslut 2026-10-25 · PLAN.md S4g · METOD M62, M14 · research 6*

- **Valt:** alla rekommendationer i research 6 gäller **preliminärt**. Underlaget är research 6
  (tabellen i §3, en rad per mått). Besluten per mått görs på Johannes privata beslutssida och
  förs in här och i katalogen när han ändrar ett mått. De åtta besluten i research 6:s
  sammanfattning, med förslagen:
  1. **Tour ± golv:** där källan bara ger ett medel är bandet Sportsbox tour-medel med järn ±
     golvet (2 cm, 5°), märkt `grans_harledd` (antagande ur källan). Ensidigt där mer är
     proffsens håll (sway gap).
  2. **Järnets band som standard** (`gront`); driverns står i `gront_driver` och används inte
     än. **Ett band som inte beror på klubban visas på alla klubbor** (Johannes 2026-10-25):
     där research 6 skriver "båda klubborna" eller källan inte skiljer klubborna, till exempel
     swayen vid toppen, tempot, nedsvingens tid, early extension, bröstets böjning i adressen,
     bröstets lyft vid toppen, höftlinjen i adressen och vid toppen, och banden ur definitionen.
     **De nio band som klubban flyttar** (research 6 §6: resan framåt, sway gap, bröstets lyft vid
     träffen, bäckenets lägsta punkt och lyft in i träffen, axellinjen i adressen och swayen vid
     P3; och ur §3 resan till P5 och höftlinjen vid träffen, granskningen 2026-10-25) bär
     `klubbberoende: true` i katalogen och visas bara på järnpass (4–9 och PW); på andra
     klubbor visas inget band, bara den egna baslinjen där den finns.
  3. **Domarna:** (a) behåll; (b) `visas: false`: visas inte för spelaren (passet,
     granskningen och Progress) men finns i exporten, paketet och underlaget till Claude (S5b); (c) bort ur
     katalogen och visningen (åtta rader: höftfällningen vid topp och träff, genomsvingens tid i
     båda vyerna, huvudet över höfterna i finishen, främre knäets sway vid topp och träff och
     bakre knäets vid träff). Måtten räknas ändå, så att paketet och MATVERSION är oförändrade.
  4. **Band ur definitionen:** reverse spine ≥ 0°, over the top ≤ 0 cm, skaftet vid toppen ≥ 0°
     och skaftlutningen vid träff ≥ 0° (felets eget tecken; tränare eller antagande), och mål 0
     för skaftets riktning vid toppen (±10°) och klubbans plan vid P6 (±5°), bredden ett
     antagande.
  5. **Early extension** −2,3…+4,3 cm: Sportsbox ideal, båda ändarna (förut öppet nedåt).
  6. **3D visar ingen bedömning:** banden i `tre_d` blir 30–46° (bäckenets vridning) och
     30–45° (höfterna vid träff) som riktmärken (B14), utan färg.
  7. **Sidböjningen i finishen** till (b), och M14:s mening om bröstet mot målet rättad.
  8. **Nedsvingens tid** 0,23–0,32 s (Blast tour).
  Med egen baslinje och känd riktning (dom a): tappad hållning, chicken wing, böjd främre arm
  och casting (sämre uppåt), handens fart (sämre nedåt) och spridningen mellan slagen (sämre
  uppåt). Huvudet mot bollen har ingen riktning (beloppet), så det får ingen färg.
- **Ett fel som övas visas** även när det är dom (b) (flying elbow kan väljas av Claude):
  annars syns inte det Johannes ska öva på.
- **Analysen till Claude** följer samma klubbregel som appen (`katalog.i_passet`,
  `Fel.iPasset`): en enhet med en annan klubba än järn har inget band för de nio, och klubban står
  i underlaget. Den egna baslinjens z-gränser (M27) gäller fortfarande där.
- **Bortvalt:** två lägen (innanför och utanför), PLAN S4g:s första skiss: gult behövs för det
  som kan vara mätfel (B87). Att ta bort beräkningen av dom (c): måtten och paketet skulle
  ändras utan att något visat att de är fel att räkna. Driverns band nu: katalogen har ingen
  klubba än (B45).
- **Kostnad:** 16 band är tour ± golv och säger inget om spridningen bland proffsen
  (thrustens SD 3,6 cm mot golvet 2 cm), och de flesta amatörer ligger utanför nedsvingens band.
  En driver visar inga band för de nio tills klubban styr bandet.
- **Omprövas:** per mått när Johannes ändrar ett beslut, när klubban förs in i katalogen
  (driverns band), och när riktiga pass visar var Johannes ligger.

## B87 — Tre färger mot bandet: grön prick, gul ring, röd pil
*2026-10-25 · gäller · Johannes beslut 2026-10-25 · METOD M62 · design/README.md regel 11*

- **Valt, som Sportsbox:** **grönt** innanför bandet; **gult** utanför men inom måttets brusgolv
  från gränsen (2 cm, 5°, eller måttets golv i METOD M62: nedsvingen 0,02 s, tempot 0,2, handens
  fart 0,5 m/s, spridningen 1°), alltså "kan vara mätfel"; **rött med en liten pil** åt det håll
  värdet ligger, utanför med mer än golvet. Den egna baslinjen ("Your usual") får ingen färg, utom
  rött med pil när måttets sämre håll är känt och värdet ligger mer än golvet utanför ramen åt
  det hållet.
- **Formen bär betydelsen också utan färg:** grönt är en **fylld prick**, gult en **ring** (en
  ring läses som "ofullständig", och den skiljer sig från både pricken och pilen i form, inte bara
  i fyllnad som en halvfylld prick, som är svår att se i 10 pt) och rött en **fylld triangel** som
  pekar åt värdet: upp eller ner bredvid talet, höger eller vänster på spannets axel (där större
  ligger till höger). Symbolen står bredvid talet i passets kort och granskningens rader, och
  spannets markör tar samma form och färg.
- **Färgerna:** iOS systemfärger i mörkt läge, läsbara på svart: grönt **#30D158** och rött
  **#FF3B30**, samma nyanser som inspelningens skärm (B85), och gult **#FFD60A**
  (systemets gula). Ett undantag från B13 regel 6 bara för läget mot bandet.
- **Accenten (B31) fungerar fortfarande:** det du övar på har kortets rubrik, radens namn och
  kvartilerna i isblått. Har måttet ett läge bär markören läget i stället för accenten; utan läge
  är markören isblå som förut.
- **Inga ord som bra eller dåligt (B13):** skärmen visar bara formen och färgen. VoiceOver läser
  läget som "in range", "just outside range", "above range"/"below range" och "above/below your
  usual".
- **Ersätter:** B45:s gula spann per fel (`gult` i katalogen; analysen räknar det nu ur bandet
  och golvet) och regeln att tempot aldrig blir rött.
- **Bortvalt:** två lägen (innanför och utanför; ett mätfel skulle bli rött), färg utan form
  (färgblinda), en halvfylld prick för gult (för lik den fyllda i liten storlek).
- **Kostnad:** tre färger i passet och granskningen, och en markör som inte längre bär accenten
  när den har ett läge.
- **Omprövas:** efter första passet på telefonen med banden (PLAN S4g, Klart när).

## B88 — Over the top bygger på klubbans plan när klubban är markerad
*2026-10-25 · gäller · Johannes beslut 2026-10-25 · METOD M62, M47, M13*

- **Valt:** felet `over_the_top` har en källa ur klubban (`klubba` i katalogen): `skaft_plan_p6`
  (klubbhuvudet över adressens skaftplan vid P6 = brant). Är klubban markerad i passet (något slag
  i vyn har måttet) bygger kortet på det, och i granskningen raden på slaget som har det; annars
  händernas bana som förut (M13). Bandet: mål 0, ±5° (bredden ett antagande, research 6 rad 38),
  golvet 5°, källan märkt B10 (P-systemet är inte läst i original). Klubbmåttet får då inget eget
  kort eller egen rad.
- **Lätt att byta källa:** valet är en funktion av om klubbmåttet finns (`kalla_for` i Python,
  `Fel.medKalla` i Swift). När S7 spårar klubban automatiskt finns måttet på fler slag, och
  ingenting annat ändras.
- **Analysen till Claude använder samma källa som appen** (Johannes 2026-10-25): har något slag i
  enhetens vy klubbmåttet bygger felets rad på klubbans plan, med dess band, enhet och "klart när";
  annars händernas bana. Underlagets mall och kontrollen av Claudes svar tar måttet och bandet ur
  analysens rad, så att appen och urklippet aldrig säger olika saker. Klubbregeln i B86 gäller
  också där.
- **Bortvalt:** att visa båda korten (samma fel två gånger), och att byta hela passet till
  klubbans plan när bara ett slag är markerat i granskningen.
- **Kostnad:** felets mått kan skifta mellan pass (händernas bana i cm, klubbans plan i grader).
  Minnets uppföljning av en övning följer måttet den valdes på, men felets väg i underlaget
  (`historik` och `minne`) blandar de två när markeringen skiftar. Progress visar händernas bana.
- **Omprövas:** när S7 ger klubban på alla slag, och när riktiga pass visar var klubbans plan
  ligger.

## B90 — Den andra telefonens bild live: JPEG per bild över PhoneLink, en i flykt, ingen under serien
*2026-10-25 · prövas · Johannes ja 2026-10-25 · PLAN.md S2k · METOD MS35*

- **Valt:** Follow skickar en förhandsbild till Lead över samma PhoneLink-koppling: en JPEG per
  bild, 360 × 640, kvaliteten 0,5, cirka 12 bilder/s (6 när telefonen är varm, ingen från
  serious), som meddelandet `preview` med JPEG i base64 och numret, och Lead kvitterar varje bild
  (`preview_ack`). Nästa bild tas först när den förra är kvitterad: högst en i flykt, så att
  fördröjningen inte växer när nätet är långsamt. Förmågan `preview1` i hello: en telefon med ett
  äldre bygge får ingen bild och allt annat fungerar som förut. Lead visar bilden i en liten ruta
  nere till vänster (där kameraappen har sin senaste bild) när telefonerna är kopplade och bilden
  är färsk; ett tryck gör den stor med hjälplinjerna och en stängknapp. Inga ord. Kugghjulet
  visar fördröjningen och takten ("Other phone's view · 0.12 s · 12 fps") hos Lead, så att Klart
  när går att läsa av.
- **Under inspelningen ingen bild** (den säkra vägen): rutan kommer ur en egen
  `AVCaptureVideoDataOutput` i förhandsbildens storlek hos Follow, och det är inte mätt att den
  lämnar 240 bilder/s i filen orörda. Utgången är avstängd när Lead inte tar emot, stängs av före
  varje serie och ljusprov på kamerans kö, och tas bort om filens koppling inte är aktiv bredvid
  den. Rutan hos Lead går under den egna serien och när bilderna slutar komma.
- **Dataregeln:** bilden går bara till den telefon som kopplingen redan godtar (samma syfte och,
  när den är känd, passets partner, B61), finns bara i minnet tills nästa kommer, och sparas
  aldrig: inte i passet, inte i paketet och inte vid ett tapp (den skickas aldrig igen).
- **Varför JPEG:** varje bild står för sig, så en bild som hoppas över (mottrycket, ett tapp, en
  paus) kostar inget, och kodningen är några rader med Core Image utan avkodarens tillstånd,
  nyckelbilder eller en egen inramning. Bandbredden räcker: 2,6–4,5 Mbit/s mot tiotals Mbit/s över
  peer-to-peer-wifi (MS35, räkning). Wire skickar sedan dess snedstrecken oescapade (base64 har ett
  per 64 tecken).
- **Bortvalt:** H.264 via VideoToolbox (en femtedel av bandbredden, men tappade bilder kräver en ny
  nyckelbild och avkodaren ett tillstånd: omprövas om bandbredden inte räcker); en egen förbindelse
  för bilden (ännu en Bonjour-tjänst och parning, och ett tapp på två ställen); en bild under
  inspelningen i 1–2 bilder/s (osäkert vad den egna utgången kostar i 240 bilder/s; omprövas när
  det är mätt); skärmdump av förhandsbildens lager (ritas utanför appen och går inte att läsa);
  att Lead begär bilden (Lead visar den alltid när den är kopplad i inspelningen, så en begäran
  vore ett meddelande till utan nytta).
- **Kostnad:** Follow kör en videoutgång till i uppställningen, och kamerans kö får 240 rutor i
  sekunden att släppa; kodningen tar några ms per bild. Pingen delar förbindelsen med bilden (MS35).
  Ingen bild alls om iOS inte låter utgången ligga bredvid filen, och ingen under serien.
- **Omprövas:** efter telefonprovet (PLAN S2k, Klart när): fördröjningen under 0,3 s, frekvensen
  i Follows kvitto med och utan bilden, och värmen under 5 minuters uppställning. Är frekvensen
  orörd kan bilden gå i 1–2 bilder/s under serien.

## B92 — Klubbmodellen ska kunna användas av andra: ingen NC-data och ingen AGPL i träningen
*2026-10-25 · gäller · Johannes svar på research 7 §5 · PLAN.md S7 · [research 7](research/7_klubban.md)*

- **Valt:** modellen för klubban (S7-1, S7-2) ska kunna användas av andra än Johannes
  (Johannes 2026-10-25). Därför tränas den bara på data och med kod vars licens tillåter det:
  Johannes egna svingar, CC BY 4.0-dataset (golf-49wbh med flera, namnangivelse i appens
  "About") och GolfPose om datat fås (EULA:n tillåter modeller i produkter). Ramverk med
  Apache-, BSD- eller MIT-licens (PyTorch, RTMPose, YOLOX, RF-DETR), aldrig Ultralytics (AGPL).
- **Förmärkning:** en detektor för klubbhuvudet tränas först på golf-49wbh och förmärker
  Johannes svingar, så att han rättar i stället för att märka från noll (Johannes ja
  2026-10-25). Förmärkningen är aldrig facit: bara det Johannes klickat räknas som märkning
  (som B71).
- **Bortvalt:** ClubheadDB och GolfDB (CC BY-NC) i träningen, och även som prov, så att inget
  NC-material behöver redovisas. Create ML (kräver Mac).
- **Träningen** sker på Johannes PC (RTX 2080 Ti, WSL2 för coremltools). Klipp, utsnitt och
  vikter ligger utanför repot (dataregeln); en påhittad modell används i simulatorprovet.
- **Provpasset:** svingarna från 2026-10-24, inspelade i SwingLab, hålls utanför träningen.
- **Omprövas:** om golf-49wbh visar sig ha bilder med oklar rätt, eller om GolfPose-datat
  kommer med villkor som binder vikterna.

## B93 — Modellens förslag i klubbmarkeringen: en fil per pass och vy, godkänn med ett tryck
*2026-10-25 · prövas · PLAN.md S7d · METOD MF8 · Johannes 2026-10-25 (förmärkningen, B92)*

- **Varför:** en detektor tränad på golf-49wbh (B92) ska förmärka Johannes svingar, så att han
  rättar i stället för att märka från noll. Märkningen sker på telefonen (S7c), där P6 blir
  hans egen ruta (research 7 §2), så förslagen måste dit.
- **Valt:**
  - **Formatet** `swinglab-klubba-forslag/1` (FORMAT.md): en JSON per pass och vy med modellens
    namn, version och datasetens licens (namnangivelsen), bildens storlek, och per slag och
    ruta Visions tid och punkterna `grepp`, `hosel`, `huvud` (klubbhuvudets mitt) och
    `skaft_mitt`, var och en med konfidens och valfri box. Tiden är Visions, som i
    `swinglab-klubba`, så att telefonen och PC:n talar om samma ruta (MF8). Formen är öppen
    för nya fält, så att en nyare PC inte stoppar en äldre telefon. Ägaren är
    `tools/pc/klubba_forslag.py` (kontrollen, också mot paketet), och SwingLabKits
    `KlubbForslagFil` ger samma fel (B12).
  - **Importen:** under Me, "Import club suggestions", som "Import focus" (B28): filen ur Filer
    kontrolleras (formen, passet finns, vyn är passets, slagen finns) och sparas som
    `KlubbForslag/<pass>-<vy>.json`; en ny fil ersätter den gamla. Felet visar fältet, aldrig
    värdet.
  - **I markeringen:** förslaget för rutan visas som streckade ringar "1?" och "2?" (modellens
    grepp ersätter ringen ur handlederna); ett tryck på ringen godkänner punkten, och ✓ under
    ytan godkänner allt som saknas med ett tryck, det vanliga fallet. Ett tryck någon annanstans
    eller ett drag rättar. Huvudets mitt visas som en streckad ruta men godkänns aldrig som
    hoseln (MF8). Instruktionsraden och guiden är oförändrade (VISION: inga nya ord när ett
    tecken räcker).
  - **Källan:** en godkänd punkt har `kalla` `godkand_forslag` i `swinglab-klubba` (version 2
    och 3, ingen ny version), med förslaget i `forslag` (`kalla` `modell`); ett tryck när ett
    förslag visades är `klick` med förslaget bredvid, alltså rättat. `klubba.ursprung` skiljer
    klick, ringen, godkänt och rättat, och `samla_klubba.py` räknar dem per pass och kan lämna
    förslagen utanför (`--utan-forslag`), så att proven i research 7 §4.2 kan hållas fria från
    modellens påverkan. Godkända punkter räknas i klubbmåtten som klick (B92: Johannes har
    godkänt dem).
- **Bortvalt:** att godta huvudets mitt som hoseln (3–5 cm fel, som handlederna i B44), en
  "Use"-knapp med text (✓ räcker, VISION), att visa förslaget utan tryck som markering (B71,
  B92), en ny formatversion för källan (läsarna är våra egna och uppdateras samtidigt; en äldre
  PC säger nej till filen och visar fältet), att öppna filen direkt ur dela-menyn (kräver en
  dokumenttyp i appen; Filer räcker som för `att_jobba_pa.json`), och rutans nummer i klippet
  som nyckel (telefonens rutor är Visions, och klippets nummer beror på redigeringen).
- **Kostnad:** PC:n måste räkna Visions tid för varje ruta (MF8, med S3:s δ), och filen blir
  stor med förslag för varje ruta (upp till 20 MB). En äldre PC-kod läser inte en fil med
  `godkand_forslag`.
- **Omprövas:** när Johannes märkt ett pass med förslag (gränsen 0,5, om ✓ förstås, om huvudets
  ruta hjälper), och när modellen ger hoseln direkt (S7-1).
