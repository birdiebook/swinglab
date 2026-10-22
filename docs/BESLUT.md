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
  GitHubs macOS-maskin, startas för hand efter Johannes ja, högst ett per dag.
- **Bortvalt:** privat repo, där bygget hade tagit av Codemagics 500 minuter,
  som delas med de andra apparna.
- **Kostnad:** koden syns. Repot bär aldrig en svingvideo, en mätning, en
  e-postadress eller en nyckel.

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
- **Omprövas:** efter telefonproven (S2_SPEC §11.3) i den etapp som bygger det.

## B28 — Vägen tillbaka via Filer
*2026-10-22 · prövas · S2_SPEC §8.5 · S2:s förslag F14*

- **Valt:** "Hämta Att jobba på" öppnar `fileImporter` för en JSON-fil, som
  kopieras in. S5 bestämmer innehållet.
- **Bortvalt (till S5):** "Öppna i SwingLab" direkt ur delningsbladet, som
  kräver en egen filtyp i Info.plist.
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
