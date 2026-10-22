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
  namnet måste vara unikt, ett längre namn som "SwingLab – Golf Swing
  Analysis". Bundle-id `se.birdiebook.swinglab`, paketet `SwingLabKit`, repot
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
