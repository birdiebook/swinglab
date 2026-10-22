# Föreslagna beslut för S2 (2026-10-22)

Förslagen hör till [S2_SPEC.md](S2_SPEC.md). De står här och inte i
`docs/BESLUT.md`, eftersom den filen ändras på en annan gren. När Johannes sagt
ja får varje förslag nästa lediga B-nummer i `docs/BESLUT.md`, i samma commit
som koden som bygger på det, och den här filen krymper i takt med det. Ett nej
eller en ändring skrivs om här.

Status: alla är **förslag**. De som kräver Johannes svar är märkta **väntar**.

## F1 — Inspelningen med `AVCaptureMovieFileOutput`
*förslag · S2_SPEC §2.1*

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
- **Omprövas:** om inspelningarna tappar mer än 1 % av rutorna.

## F2 — Exponeringen mäts med auto och låses på 1/2000 s
*förslag · S2_SPEC §2.3–2.4*

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

## F3 — Formatet väljs i SwingLabKit
*förslag · S2_SPEC §2.2 · METOD MS1*

- **Valt:** exakt 1920 × 1080 och 240 bilder/s; bland dem störst synfält,
  sedan binnat (mer ljuskänsligt), sedan 8-bitars. Annars bästa 1080p ≥ 120,
  märkt i gult. Hela formatlistan sparas i paketet (`enhet.json`). Bildtiden
  sätts med intervallets egen `minFrameDuration`.
- **Bortvalt:** Airtimes regel (högsta frekvens, sedan största bild), som inte
  ser synfältet, och `CMTime(value: 1, timescale: 240)`, som kraschar om talet
  inte finns exakt i formatets intervall.

## F4 — Ljusprovet före passet
*förslag · S2_SPEC §2.7 · METOD MS2, MS3*

- **Valt:** en knapp som på 3 s ger ISO-behovet vid 1/2000 s (som "för mörkt:
  1,3 steg"), flimret vid 100 Hz och andelen tappade rutor ur en provfilm på 2 s.
  Resultatet följer med paketet.
- **Varför:** 1/2000 s kräver i storleksordningen 700–1 400 lux på golfaren vid
  ISO 1000–2000 (egen räkning), mer än en vanlig hall. Det ska synas före passet,
  inte i lederna efteråt.
- **Kostnad:** gränserna (3/10 % flimmer, 1/5 % tappade rutor) är antaganden
  tills de första passen kalibrerat dem.

## F5 — Lägsta iOS är 18.2
*väntar (andra telefonens modell) · S2_SPEC §2.1, §13*

- **Valt:** `deploymentTarget` 18.2, för delegaten med `startPTS` (filens första
  ruta på sessionens klocka), som behövs för att två telefoner ska kunna
  jämföras före klicken.
- **Bortvalt:** iOS 26 (bakgrundsjobb med `BGContinuedProcessingTaskRequest`,
  nyare Network-API), som kräver att båda telefonerna kan köra iOS 26. iOS 17
  som Airtime, som saknar `startPTS`.
- **Omprövas:** när den andra telefonens modell är känd.

## F6 — Appen kompileras och provas i simulatorn på GitHubs macOS, gratis
*Johannes ja 2026-10-22*
*väntar (avviker från arbetssättet) · S2_SPEC §10.2*

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

## F7 — Två telefoner kopplas med Network.framework
*Två telefoner redan i S2: Johannes 2026-10-22*
*förslag · S2_SPEC §7.1*

- **Valt:** `NWListener`, `NWBrowser` och `NWConnection` över TCP med Bonjour
  (`_swinglab._tcp`), peer-to-peer påslaget och Nagle avstängt. Meddelandena är
  JSON med längd före, i SwingLabKit. En telefon styr, övriga följer (fler än en
  följare går).
- **Bortvalt:** Multipeer Connectivity, avskrivet i iOS 27 ("Use Network
  Framework instead"). Det nya `NetworkConnection`-API:t, som kräver iOS 26.
- **Kostnad:** frågan om lokalt nätverk visas första gången; nekas den fungerar
  inte kopplingen (men inspelningen gör det).

## F8 — Klicket är synken, pingen bara ett förhandsvärde
*förslag · S2_SPEC §7.2–7.4 · METOD MS6, MS9, MS10*

- **Valt:** varje telefon spelar in och hittar sina klick själv. Klicken paras
  mellan telefonerna med Golf SG:s `para()` (förskjutningen som parar flest inom
  30 ms). Pingen (NTP-formeln) smalnar bara sökningen. Ljudets väg rättas med
  avståndet till bollen (`d/343`). Kopplingen bär aldrig video.
- **Varför:** ett tapp i kopplingen kostar då ingen data; utan koppling kan PC:n
  para med samma algoritm.
- **Kostnad:** varje telefon måste höra klicket. Finjusteringen på ledernas fart
  görs på PC:n (S6).

## F9 — Klickjakten är Golf SG:s, plus en svingkontroll
*förslag · S2_SPEC §4 · METOD MS4, MS5*

- **Valt:** `handled_video.klick` portad ordagrant till Swift, körd i bitar om
  30 s (minnet), med en paritetsfixtur mot Python. Ett klick blir ett slag först
  när glesa leder kring klicket visar händerna högt före och snabba vid klicket.
  Johannes kan ändra domen.
- **Varför:** Golf SG hittade 41 av 41 klick, men där valde bandet ut klicken.
  På en range finns grannens klick och röster.
- **Kostnad:** svingkontrollens gränser är antaganden tills oktobers 41 slag
  prövat dem (S2e).

## F10 — Import ur Bilder hämtar originalresursen
*förslag · S2_SPEC §5*

- **Valt:** `PhotosPicker` med bibliotek ger id:t; `PHAssetResource` av typen
  `.video` (originalet) skrivs till appen med `PHAssetResourceManager`.
  `FrameTiming` vägrar en fil som inte har ett rutnät på minst 100 bilder/s.
- **Bortvalt:** `loadTransferable` med `.current` som enda väg (Airtime). Om den
  ger originalet för en slowmotion är inte dokumenterat. Den finns kvar som
  reserv vid begränsad åtkomst, bakom samma kontroll.
- **Kostnad:** appen ber om full åtkomst till Bilder.

## F11 — Vision på varje ruta, i förgrunden, återupptagbart
*förslag · S2_SPEC §6*

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

## F12 — Lagringen
*väntar (originalen) · S2_SPEC §8.1*

- **Valt:** allt i Application Support per pass; video och klipp utanför
  iCloud-backupen; exporten i `Documents/Export`, synlig i Filer och i Apple
  Devices över kabel.
- **Väntar:** behålla hela serierna eller "Spara bara klippen" efter export.

## F13 — Paketet är en okomprimerad zip per telefon och pass
*förslag · S2_SPEC §8.3–8.4*

- **Valt:** `swinglab-<pass>-<vy>.zip` med `manifest.json` (`swinglab-paket/1`),
  ett JSON per slag med lederna, och klippen (valbart). Zip-skrivaren strömmar
  till disk och lagrar utan komprimering, likadant på Linux och telefonen.
  Klippen kodas inte om, och klicket mäts om i varje klipp.
- **Bortvalt:** Idunns zip i minnet (paketet blir hundratals MB). En mapp i
  stället för zip (AirDrop och iCloud Drive till Windows hanterar en fil
  enklare). Ett gemensamt paket från båda telefonerna (videon skulle behöva gå
  över kopplingen).
- **Kostnad:** ingen zip64: högst 4 GB per paket.

## F14 — Vägen tillbaka via Filer
*förslag · S2_SPEC §8.5*

- **Valt:** "Hämta Att jobba på" öppnar `fileImporter` för en JSON-fil, som
  kopieras in. S5 bestämmer innehållet.
- **Bortvalt (till S5):** "Öppna i SwingLab" direkt ur delningsbladet, som
  kräver en egen filtyp i Info.plist.

## F15 — Lederna heter som i Golf SG och har MediaPipes index
*förslag · S2_SPEC §6.3*

- **Valt:** 13 leder (näsa, axlar, armbågar, handleder, höfter, knän,
  fotleder) med Golf SG:s namn (`nasa`, `axel_v`, …) och MediaPipes index (0,
  11–16, 23–28). Vänster är personens vänster i både Vision och MediaPipe.
  Pixlar i den upprätta bilden med origo uppe till vänster, som Golf SG:s
  `bild`.
- **Varför:** S3 jämför Vision mot MediaPipe led för led, och PC-sidan läser
  oktobers MediaPipe-leder i samma form.
- **Om S1:s `docs/FORMAT.md` säger annat** vinner FORMAT.md, och den här raden
  skrivs om.
