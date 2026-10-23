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
*2026-10-22 · prövas · PLAN.md S4 (S4c)*

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
- **Kostnad:** gränserna är antaganden. Pass som mättes före S1d mäts inte om
  (bara när längden ändras, MS14), så deras DTL-tempo har kvar M4:s start.
- **Omprövas:** när S3 mätt posemodellens brus på golf och ett riktigt DTL-pass
  prövats (`faser.start` och `start_osaker` i PC:ns `analys.json`), och om en
  waggle visar sig flytta adressens fönster.
