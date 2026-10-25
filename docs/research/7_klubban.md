# 7. Klubban: öppna data, egen märkning, vägval och S7-1 (2026-10-25)

Underlag för etappen S7 (PLAN §S7). Johannes 2026-10-25: **"tanken är att ganska snart
lösa klubban, vi har en del underlag, 40 svingar sedan tidigare och några nya sedan igår,
sedan kollade jag även i annan chatt att det finns en del öppen data med svingar som vi kan
använda"**. Samma dag kom tre svar: svingarna är **bara video, utan markering**; datorn har
ett **NVIDIA RTX 2080 Ti**; och hans sammanställning av öppen data från den andra chatten
(Claude Docs "Swing Lab – öppna resurser"), som stäms av i §1.3.

**Ingenting i koden, katalogen eller METOD är ändrat.** Status som i research 5 och 6
(BESLUT B10):

- **läst** = sidan hämtad och läst i detta pass (GitHub och PyPI; verktyget sammanfattar
  sidan, så ett citat är kort);
- **sökträff** = bara sökmotorns sammanfattning, **ej läst i original**;
- **Johannes lista** = ur hans sammanställning 2026-10-25, ej läst av oss;
- **antagande** = vår bedömning eller uppskattning, inte mätt.

**Vad som gick att läsa:** github.com och pypi.org. Proxyn nekade (eller hittade inte)
universe.roboflow.com, arxiv.org, mdpi.com, peerj.com, epfl.ch, infoscience.epfl.ch,
orbit.dtu.dk och huggingface.co. Alla Roboflow-dataset, artiklarna på arXiv och EPFL:s
artikel är därför sökträffar eller Johannes lista.

## Sammanfattning

- **Det finns inget öppet dataset med grepp och hosel i 240 bilder/s från en iPhone.**
  Det som finns är rutor runt klubbhuvudet (YouTube-bilder, 30 bilder/s, oskärpa), ett
  fåtal små keypoint-set och GolfPose. Den egna märkningen är alltså grunden, och öppen data
  är förträning, förmärkning eller prov.
- **GolfPose är bättre än vi trodde.** Licensen (läst) tillåter uttryckligen att modeller
  tränade på datat byggs in i produkter, också kommersiella. Den förbjuder att sprida rådatan.
  Datat fås på mejl, och punkterna inkluderar hoseln. PLAN §S7 nämnde licensen som ett hinder,
  men det stämmer inte för vikter i appen.
- **De bästa öppna källorna, med licens:**
  - GolfPose: eget EULA, modeller i appen tillåtna.
  - golf-49wbh på Roboflow: CC BY 4.0, rutor för klubba och klubbhuvud, 7 842 bilder. Det
    är Johannes lista; vi kunde inte öppna sidan.
  - ClubheadDB: CC BY-NC 4.0, 10 180 DTL-rutor. Bara för prov.
  - golf-club-tracking på Roboflow: CC BY 4.0, skaft, huvud och händer. Den färdiga modellen
    SwingTrace bygger på Ultralytics och är därför AGPL.
- **Rekommenderad väg:** keypoints top-down, alltså greppet och hoseln i ett utsnitt kring
  Visions händer. Modellen är en egen liten PyTorch-modell (Apache/BSD-beroenden) eller
  RTMPose-s (MMPose, Apache 2.0). Den tränas på 2080 Ti:n på Johannes egen märkning med
  S7c, och exporteras med coremltools (BSD-3). P6 väljs ur modellens skaft ruta för ruta
  (M45), och måtten räknas med samma `klubba.mat` som för handmarkeringarna. Linjen och
  S7b:s spårning är kontroll och förmärkning, inte huvudvägen. Ultralytics väljs bort
  (AGPL).
- **S7-1** (§4) ger `skaft_plan_p6` bakifrån och `skaft_arm_p6` framifrån utan tryck, på
  PC:n först. Casting är definierad framifrån (M49), se §4.1. S7-1 är klar när måtten ligger
  inom 2° respektive 3° i median från Johannes handmarkeringar, på ett pass som modellen inte
  tränats på.

## 1. Öppna data och modeller

### 1.1 Dataset för klubban

"Privat app" betyder Johannes egen app via TestFlight. "Vikter i appen" betyder att en
modell som tränats på datat skeppas i appen. Repot är publikt (B7), så **rådata och
Johannes data hamnar aldrig i repot**, vilken licens det än är.

| Dataset | Innehåll | Licens | Privat app / vikter i appen | Status och URL |
|---|---|---|---|---|
| **GolfPose / GolfSwing** | 2D och 3D för golfare och klubba. 17 kroppspunkter plus 0–5 klubbpunkter: skaft, hosel, häl, tå nere och tå uppe enligt research 2 (sökträff). Modeller finns för golfare, klubba och båda (HRNet-w48, ViTPose-H, DEKR), med AP 0,857–0,942, och detektorer (Faster R-CNN, YOLOX-s) med AP 0,884–0,984. Vyer, bildfrekvens och antal står inte på sidan. | **Eget EULA:** icke-exklusiv licens att använda datat. Läst: *"You are permitted to integrate the machine learning models trained on this Dataset into commercial products or services."* Rådatan får inte publiceras, delas eller säljas. Citera artikeln. Ingen ansiktsigenkänning. | **Ja och ja** enligt texten. Datat stannar på PC:n. Checkpointerna har inga egna villkor; de omfattas troligen av klausulen om tränade modeller (antagande). | läst: https://github.com/MingHanLee/GolfPose (README och LICENSE). Datat och vikterna ligger på gofile, och författaren godkänner på mejl. Punkternas namn är **ej lästa i original**. |
| **ClubheadDB** (2025) | 10 180 DTL-rutor ur YouTube (46 %) och Reddit (54 %), 67+ golfare, 42 % proffs och mest järn. En ruta (YOLO-format) runt klubbhuvudet per bild; en tom fil när huvudet inte syns. Delat per video i 47/10/10 golfare. Bilderna laddas ned med skript. | **CC BY-NC 4.0** (PyPI 1.0.1) | Privat och icke-kommersiellt prov: ja. Vikter tränade på det i appen: oklart (NC och "bearbetat material"), och nej om appen någon gång blir kommersiell. **Bara för prov.** | läst: https://pypi.org/project/clubhead-db/. GitHub-länken (`unknownauthor23/ClubheadDB`) gav 404 i research 2. Ingen artikel ännu. |
| **golf-49wbh** (Roboflow, lvs-rd) | 7 842 bilder med rutor för person, klubba, klubbhuvud och boll. Uppladdade av användare; ursprunget är okänt (ofta YouTube). | CC BY 4.0 | Ja och ja enligt licensen. Risken: den som laddade upp äger kanske inte bilderna (antagande). | Johannes lista: https://universe.roboflow.com/lvs-rd/golf-49wbh. Sidan nekades, och sökningen hittade inte projektet. |
| **golf-49wbh-spfor** (swingfeed) | Samma klasser, troligen en fork, med en förtränad RF-DETR Nano | CC BY 4.0. RF-DETR Nano är Apache 2.0 (läst). Vikterna som Roboflow kör åt en har egna villkor (okontrollerat). | Datat ja. Roboflows vikter: okontrollerat. | Johannes lista: https://universe.roboflow.com/swingfeed/golf-49wbh-spfor |
| **golf-club-tracking** (Roboflow, club-head-tracking) | Rutor för skaft, klubbhuvud och händer. Storleken anges inte. | CC BY 4.0 | Datat ja och ja. | läst via SwingTrace (nedan). Sidan: https://universe.roboflow.com/club-head-tracking/golf-club-tracking (sökträff) |
| **Golf VFA** | 2 839 bilder med boll och klubbhuvud, med rörelseoskärpa | okontrollerad | — | Johannes lista: https://universe.roboflow.com/golgballtracking/golf-vfa-fmccj |
| **azb-dc** | Klubba och klubbhuvud, storleken okänd | CC BY 4.0 | ja och ja | Johannes lista: https://universe.roboflow.com/club-head/azb-dc |
| Roboflow **golf-keypoint** (kilkennyrobo) | keypoint-set, 233 bilder enligt research 2 | CC BY 4.0 (sökträff) | ja och ja, men för litet | sökträff: https://universe.roboflow.com/kilkennyrobo/golf-keypoint |
| Roboflow **Golf Swing** (bloggen) | 68 bilder med kroppen och klubban, där klubbpunkterna ger skaftets vinkel och huvudet | okontrollerad | för litet | sökträff och Johannes lista: https://blog.roboflow.com/golf-swing-analysis-with-vision-ai/ |
| Roboflow **golf-club-keypoints-project** | 60 bilder med klasserna Club, Shaft och Toe | okontrollerad | för litet | sökträff: https://universe.roboflow.com/golf-sv3kn/golf-club-keypoints-project |
| Roboflow, rutor för klubbhuvudet | 8 405 och 1 902 bilder i två set | CC BY 4.0 (sökträff) | ja och ja | sökträff: https://universe.roboflow.com/jonathan-tidbury-kt5x7/golf-club-head · https://universe.roboflow.com/public-bezoe/golf-club---head-object-detection |
| MDPI 2026, "Explainable Graph-Based Golf Swing Analysis…" | Rutor för klubbhuvudet (4 812) och greppet (4 639), märkta för hand i Roboflow | Datat verkar inte vara släppt. | — | sökträff: https://www.mdpi.com/2076-3417/16/8/3813 (nekad) |

### 1.2 Faser, kropp och analogier

| Dataset eller metod | Innehåll | Licens | För oss | Status |
|---|---|---|---|---|
| **GolfDB / SwingNet** | 1 400 YouTube-svingar med 8 händelser, golfarens ruta, klubbtyp och vy. Ingen klubbmärkning. Klippen finns i 160 × 160. | Koden **CC BY-NC 4.0** (läst). Datats och vikternas licens anges inte. En sökträff säger MIT; det motsägs av README. | Nej. Klicket och kroppens positioner slår SwingNet (research 2 §4). | läst: https://github.com/wmcnally/golfdb |
| PeerJ, GolfDB med 17 kroppspunkter | kroppen, inte klubban | okänd | nej | sökträff: https://peerj.com/articles/cs-3664/ (nekad) |
| **CaddieSet** (CVPRW 2025) | Leder i 8 faser, 15 mått och bolldata. 833 DTL-svingar enligt Johannes lista. Ingen klubbmärkning enligt sökträffarna. | okontrollerad | nej för klubban | sökträff och Johannes lista: https://arxiv.org/abs/2508.20491 (nekad) |
| **RacketVision** (2025) | Racketens pose i bordtennis, tennis och badminton, plus bollen | okänd | Analogi för en stav med två ändar i fart. Inget att ta. | sökträff: https://arxiv.org/abs/2511.17045 |
| RacketDB | rutor för badmintonracketar | okänd | nej | sökträff: https://github.com/muhabdulhaq/racketdb |
| Roboflow "Baseball Batter" | keypoints, oklart om de gäller slagträt | MIT (sökträff) | nej | sökträff: https://universe.roboflow.com/baseball-r7dzp/baseball-batter/dataset/ |
| **EPFL** (Lepetit, Gehring och Fua) | Skaftet som ett par nästan parallella rörliga linjesegment. Kandidaterna anpassas till en global svingmodell (dubbelpendel). Ingen ML. Ger klubbhuvudets 2D-spår ur vanlig video, 35 svingar enligt research 2. | artikel | Idén till väg B och D (§3) | Johannes lista och research 2, **ej läst i original** (epfl.ch nekad): https://www.epfl.ch/labs/cvlab/wp-content/uploads/2018/08/golf.pdf · https://infoscience.epfl.ch/record/82154/files/paper.pdf?version=1 |
| US-patent 12 711 647 | Pose ger greppet, och linjesegment söks i ett utsnitt kring det, eftersom hoseln är svår för keypoints (oskärpa, hoseln utanför bilden) | patent | Bara inspiration. Kombinationen är patenterad i USA. | sökträff: https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/12711647 |
| US-patent 11 229 824 | Hoseln där skaftets kanter vidgas till huvudet (linjedetektion och konturer) | patent | inspiration | sökträff: https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/11229824 |
| **DTU**, monokulär 3D för golf | 3D-posemodeller ur en kamera har för stora fel för golfkinematik | artikel | Stöder B9 och B14 (två kameror). Inget nytt för klubban. | Johannes lista: https://orbit.dtu.dk/en/publications/evaluating-current-state-of-monocular-3d-pose-models-for-golf/ (nekad) |

### 1.3 Avstämning mot Johannes sammanställning

| Punkt i sammanställningen | Det vi fann | Följd |
|---|---|---|
| "GolfPose har eget EULA" (som ett hinder) | LICENSE (läst) tillåter modeller tränade på datat i produkter, också kommersiella. Bara rådatan får inte spridas. | GolfPose blir **förträning och förmärkning** om Johannes vill mejla författaren (§5). |
| "GolfPose 2022" | Repot anger ICPR 2024 | Samma arbete, troligen; ett förtryck 2022 är möjligt men okontrollerat. |
| golf-49wbh, -spfor, Golf VFA, azb-dc | Sidorna nekades, och sökningen hittade inte golf-49wbh | Står som Johannes lista. Läses i original på hemdatorn innan något tränas på dem. |
| ClubheadDB "för utvärdering, inte träning" | Bekräftat: CC BY-NC 4.0, DTL, en ruta per bild (läst) | Samma slutsats. Rutan ger klubbhuvudets mitt, inte hoseln, så provet blir grovt (§3). |
| GolfDB "CC BY-NC" | Koden CC BY-NC (läst). Datats licens anges inte. | Används inte. |
| golftracker "PyPI 0.0.5, spårar grepp, häl, tå och boll med OpenCV" | PyPI har version 2.0 (2023-11-25), MIT. Sidan beskriver MediaPipe, fasmärkning för hand och klubbhuvudet märkt för hand i några rutor, **linjärt ifyllt** däremellan. | Sämre än S7b:s spårning mellan ankarna. Inget att ta. |
| swing-analyzer (MIT) | 0.1.2 (läst). Sidan säger själv: ingen spårning av klubbhuvud eller skaft. Planet är en linje genom händerna. | Inget för klubban. |
| golftrainer (sanjeevs) | Samma författare som golftracker (homepage) | Inget att ta. |
| Förslag 1: Apple Vision för händerna | Vi har redan Visions handleder (M1), och de är utsnittets mitt i S7b (M61). `VNDetectHumanHandPoseRequest` ger fingrarna och kan flytta mitten närmare greppet (oprövat). | Ja: utsnittets mitt. |
| Förslag 2: skaftlinjen enligt EPFL i ett utsnitt, med pendelutjämning | Bra framifrån, där skaftet är långt i bild. Bakifrån vid P2, P6 och P8 pekar skaftet mot kameran och är 20–70 px (M47), och linjen ger varken riktning eller hosel just där `skaft_plan_p6` mäts. | Kontroll och förmärkning (väg B), inte huvudväg. |
| Förslag 3: markera klubbhuvudet i första rutan och spåra | Det är S7b, redan byggt med ankare vid P1–P10 (M61, B71). Det kräver tryck och är alltså inte automatiskt. | Märkverktyg (väg C). |
| Förslag 4: klubbhuvuddetektor i **Create ML** på golf-49wbh | Create ML kräver en Mac (`MLObjectDetector`, macOS 10.15+). Johannes har ingen. Rutans mitt är inte hoseln. | Om en detektor behövs: YOLOX eller RF-DETR Nano (Apache) på 2080 Ti:n. Inte i S7-1. |
| Förslag 5: märk egna svingar | Ja: grunden (§2) | Med S7c i appen. |
| Förslag 6: DTL och FO från start? | Ja. Måtten i S7-1 ligger i var sin vy (M47, M49), och en modell kan ta båda. | En modell, båda vyerna. |

## 2. Vår egen data

**Det som finns** (Johannes 2026-10-25): cirka 40 svingar från oktober och några från
2026-10-24, **bara video, ingen markering**. Oktobers slag är filmade med Kamera-appens
slowmotion: utan låst slutartid, med rutor som saknas, i båda vyerna. Det står i Golf SG
HANDLED_PLAN §3, som är privat, och här står inga tal ur det (dataregeln). Kamera-appen
låser inte slutaren (B11), så klubben är suddigare där än i SwingLabs egna klipp. De nya
svingarnas format är okänt (§5).

**Märkningen ger, med S7c i appen** (M45):

- 10 rutor per sving och vy (P1–P10), var och en med greppet och hoseln, för cirka 26–35
  tryck per sving.
- 40 svingar ger cirka **400 märkta rutor** med två punkter, eller cirka 360 när några
  positioner hoppas (antagande: 1 av 10).
- Tiden är uppskattad till 2–4 minuter per sving, alltså 1,5–3 timmar för 40 (antagande;
  det mäts på telefonen, PLAN S7c).
- Kamera-klippen tas in med importen ur Bilder (B11). Då får de leder och P-positioner, och
  P6 blir Johannes egen ruta. Det är just rutan S7-1 mäts på.
- `markera_klubba.py` på en video utan paket väljer 24 jämnt spridda rutor (MF5), men utan
  P-positioner. Det duger som extra träningsdata men inte som facit för P6.

**S7b ger fler rutor:**

- Mellan grannankarna spåras klubbhuvudet ruta för ruta (M61). P1 → P10 är cirka 1,5–2 s,
  alltså 360–480 rutor vid 240 bilder/s.
- I den påhittade filmen spårades 55 % av rutorna, och bakifrån bara en av fyra. Det ger
  grovt 100–250 föreslagna klubbhuvuden per sving (antagande).
- Greppet i de rutorna är korridorens grepp: handlederna plus ankarnas förskjutning,
  linjärt i tiden.
- Förslagen blir träningsdata först när de är **godkända eller rättade** (B71: banans rutor
  räknas aldrig som markeringar, och godkänna och rätta är inte byggt).
- Grannrutor i 240 bilder/s är nästan lika, så **antalet svingar och pass väger mer än
  antalet rutor**.

**Räcker det?** Det är ett antagande, inte mätt:

- En modell med två eller tre punkter i ett utsnitt kring händerna, som börjar från
  förtränade vikter (COCO-kroppen), brukar bli användbar på några hundra märkta rutor, om
  de kommer från många svingar.
- 30–40 svingar per vy från minst två pass är en rimlig start, med ett helt pass utanför
  träningen som prov.
- Modellen lär sig Johannes, hans klubbor, hans range och hans ljus. Det är målet för en
  privat app, men den håller sämre på en annan plats, i mörker eller med drivern, och det
  syns först i provet.
- Gör det inte det: märk fler där modellen är osäker (aktiv inlärning, nedan) och lägg
  till GolfPose som förträning.

**Hur Claude kan hjälpa till med märkningen (S7b):**

1. **Granska i stället för att klicka.** Claude lägger förslagen (S7b:s spår, en
   förmärkning, modellens punkter) på ett kontaktark per sving och pekar ut rutorna som ser
   fel ut. Ett ja eller nej är billigare än två tryck. Det kräver att Johannes delar bilderna
   med Claude (dataregeln, §5).
2. **Inga punkter direkt från Claude.** Claudes pixelnoggrannhet i en bild är inte mätt
   här, och ett facit med fel på några procent av bilden skulle sätta golvet för hela
   modellen (antagande). Det går att mäta på tio märkta rutor om Johannes vill.
3. **Aktiv inlärning.** Efter första träningen kör Claude modellen på alla omärkta rutor
   och väljer de 50–100 där den är minst säker eller där den och S7b inte är överens.
   Johannes märker bara dem.
4. **Förmärkning ur en öppen modell.** GolfPose klubbmodell, om vikterna fås, eller en
   detektor tränad på golf-49wbh föreslår hoseln eller huvudets ruta. Johannes godkänner
   med ett tryck, som ringen för greppet i S7a (`handlederna_bekraftad`). Källan blir ny i
   formatet, till exempel `forslag_bekraftad`, och det kräver en rad i FORMAT och ett
   beslut.
5. **Kedjan.** Claude skriver verktygen för att plocka rutorna, träna, utvärdera och göra
   kontaktarken. Det är kod i `tools/pc/` utan data.

## 3. Vägval för modellen

| Väg | Ger | Bakifrån vid P6 (skaftet kort i bild) | Ramverk och licens | Core ML på iPhone | Träning gratis |
|---|---|---|---|---|---|
| **A. Keypoints top-down**: greppet, hoseln och ev. skaftets mitt i ett utsnitt kring Visions händer | Båda punkterna i varje ruta, och därmed skaftet, P6 och måtten. Konfidensen per punkt. | Hoseln ligger nära greppet men syns som ett hörn mot huvudet. Modellen lär sig det om P6 bakifrån finns i märkningen. Det svåraste fallet, prövas först. | **Egen liten modell i PyTorch** (BSD) med en timm-stam (Apache), till exempel ResNet18 eller MobileNetV3. Eller **RTMPose-s/m** i MMPose (Apache 2.0; senaste release v1.3.0 i januari 2024, mmcv är krångligt på Windows, så WSL2). **ViTPose** (Apache 2.0) är för stor för telefonen. **Ultralytics YOLO-pose: AGPL-3.0**, och vikter tränade ur den räknas också som AGPL (SwingTrace säger det själv). | PyTorch → `coremltools` (BSD-3, version 9.0, hjul bara för macOS och Linux, så WSL2 på PC:n) → `.mlpackage` i FP16. RTMPose-s är 5,5 M parametrar och 0,68 GFLOP (13,9 ms på Snapdragon 865 med ncnn, läst), så några ms på Neural Engine (antagande). Bara rutorna kring P1 och P5–P7 behövs, 40–80 rutor, alltså under en sekund. | 2080 Ti: se tabellen nedan. |
| **B. Linjedetektion** av skaftet: Hough eller LSD i OpenCV, M-LSD, EPFL:s parallella segment med pendelmodell | Skaftets riktning, men inte var det slutar | **Faller bort:** 20–70 px mot kameran, inga långa segment | OpenCV (Apache 2.0), M-LSD (Apache 2.0, TensorFlow/TFLite, ingen Core ML angiven, läst) | Klassisk: Swift med Accelerate, eller Vision `VNDetectContoursRequest` (oprövat) | Ingen träning |
| **C. Spårning** mellan rutor med markeringen som start: S7b, TAPIR och BootsTAPIR, CoTracker, Vision `VNTrackObjectRequest` | Banan mellan ankarna. Kräver tryck, så den är inte automatisk. | S7b: tre av fyra rutor interpolerade bakifrån i den påhittade filmen (M61) | S7b är vår egen. **TAPNet** (TAPIR, BootsTAPIR, TAPNext): Apache 2.0, kod och vikter (läst). **CoTracker: CC BY-NC** (läst). | S7b går redan på telefonen (B71). TAPIR (ResNet18) är inte provad i Core ML. | — |
| **D. Klassisk bildbehandling i 240 bilder/s**: rörelsedifferens, oskärpestrimman, skaftets linje | Klubbhuvudets rörliga fläck (S7b), skaftets linje när det är långt | Rörelsen vid P6 är stor, men skaftet är kort och huvudet skyms ofta av händerna bakifrån | egen | går redan (M61) | — |
| **E. Detektor med rutor**: klubbhuvud, ev. greppet | Rutans mitt, inte hoseln. Förskjutningen mot hoseln mäts vid ankarna, som M61 gör. | Liten ruta nära händerna | **YOLOX** (Apache 2.0, Nano 0,9 M och s 9 M parametrar, läst), **RTMDet** (MMDetection, Apache 2.0), **RF-DETR** Nano, S, M och L (Apache 2.0; Atto, Femto, Pico, XL och 2XL är PML 1.0, läst; Nano har 30,5 M parametrar). Ultralytics AGPL. | YOLOX via ONNX eller PyTorch → coremltools (oprövat). RF-DETR: Core ML anges inte. | golf-49wbh på 2080 Ti:n |

**Förtränade vikter:** COCO-kropparnas och ImageNet-stammarnas vikter bär sina datasets
villkor. COCO:s märkning är CC BY 4.0 och bilderna Flickrs. ImageNet är för forskning och
icke-kommersiellt bruk. Det är känt men inte kontrollerat i detta pass, och för en privat
app är det inget hinder.

**RTX 2080 Ti** (Turing, 11 GB enligt kortets specifikation; Johannes sa 12 GB, se §5):

- FP16 med tensorkärnor (`torch.autocast` med fp16), men ingen bf16.
- Ingen Flash Attention 2, som kräver Ampere. Det spelar ingen roll för väg A.
- Allt nedan är **uppskattningar** (antagande) och mäts vid första körningen:

| Modell | Indata | Batch som ryms i 11 GB (fp16) | Tid |
|---|---|---|---|
| Egen: ResNet18 eller MobileNetV3 med 2–3 punkter (heatmap eller SimCC) | 256 × 256, gråskala | 64–128 | 1 000 rutor × 200 epoker: 10–30 min |
| RTMPose-s / -m, finjusterad från COCO | 256 × 192 | 64–128 | 20–60 min |
| ViTPose-B (86 M) | 256 × 192 | 32 | några timmar; för stor för telefonen |
| YOLOX-s på golf-49wbh (7 842 bilder) | 640 × 640 | 16–32 | 100 epoker: 3–6 h |
| RF-DETR Nano på golf-49wbh | 384–640 | 4–8 | många timmar (DETR vill ha långa scheman) |

**Colab** (gratis T4) går bara för öppen data. Johannes rutor till Google är data som
lämnar PC:n (dataregeln), så träningen på egen data sker på 2080 Ti:n.

**Modellen i appen utan att hamna i repot:**

- Vikter tränade på Johannes svingar är härledda ur hans data, och repot är publikt (B7).
  Därför hör de inte hemma i repot, och inte i ett byggsteg i Actions som läser repot.
- Vägen som håller: modellfilen förs till telefonen som paketen, via dela-menyn eller
  Filer, och appen kompilerar den med `MLModel.compileModel(at:)` (oprövat).
- För simulatorprovet tränas en **påhittad** modell på `klubbfilm.py`. Den får ligga i
  repot och prövar att kedjan i appen fungerar, inte noggrannheten.
- Beslut att ta (§5).

## 4. Rekommendation: S7-1

**Väg A, keypoints top-down, med B och C som stöd.** Skälen:

- `skaft_plan_p6` hänger på **hoselns läge vid P6** bakifrån. Där är skaftet för kort för
  en linje (B), och spårningen tappar oftast (C, D).
- En punktmodell lär sig hörnet mellan skaft och huvud ur märkningen. Det är samma två
  punkter som S7a redan märker (B44), så märkningen är facit och träningsdata på en gång.
- Måtten räknas med **samma `klubba.mat`** som för handmarkeringarna. Definitionerna,
  spärren och mätversionen ändras alltså inte, bara punkternas källa.
- Linjen (B) prövar modellen framifrån, där skaftet är långt. S7b (C) och en
  GolfPose-förmärkning ger fler märkta rutor.
- Ultralytics (AGPL) och NC-data i träningen undviks, så att vikterna inte binds. Det spelar
  roll om appen någon gång ska nå andra än Johannes (VISION).

### 4.1 Casting bakifrån eller framifrån

Uppdraget sa casting (`skaft_arm_p6`) och planet (`skaft_plan_p6`) i DTL. Men
`skaft_arm_p6` är definierat **framifrån** (M49, katalogen: vy `fo`):

- Bakifrån vid P6 pekar skaftet mot kameran (M45), och armen går också i djupled. Vinkeln
  mellan dem i bild säger då mest om perspektivet.
- Förslaget: **en modell, båda vyerna.** S7-1 ger `skaft_plan_p6` bakifrån och
  `skaft_arm_p6` framifrån.
- Med två parade telefoner (S6g) får ett slag båda måtten.
- Vill Johannes ha casting bakifrån krävs ett nytt mått med egen METOD-rad. Det avråds
  (§5).

### 4.2 S7-1: Klubban utan tryck vid P6, på PC:n (förslag)

**Gör:**

1. **Märk.** Johannes märker alla svingar med S7c i appen, i båda vyerna. Kamera-klippen
   tas in med importen ur Bilder.
   - Ett pass hålls helt utanför träningen som prov, gärna de nya i SwingLabs egen
     inspelning (240 bilder/s, låst slutare, B11).
   - Provet ska ha minst 10 svingar per vy med P1, P5, P6 och P7 märkta.
   - 5 svingar per vy märks en gång till en annan dag. Det mäter handmärkningens eget brus.
2. **Plocka rutorna.** `samla_klubba.py` samlar markeringarna utanför repot. Ett nytt
   verktyg läser rutorna ur klippen och skär utsnitten:
   - utsnittet är centrerat på handledernas mitt (M1);
   - sidan är 2 × 1,35 L, med L ur kroppens skala (M2, M49) eller ankarna;
   - bilden är gråskala, som Y-planet i `RutStrom` (B71), så att appen kan använda samma
     rutor.
   Bilderna och utsnitten ligger bara utanför repot.
3. **Träna.** Två punkter (greppet och hoseln), plus skaftets mitt om det hjälper. Prövas
   mot handmärkningen, inte mot sig själv.
   - Ökningen av datat: oskärpa längs rörelsen, ljus och kontrast, liten vridning och
     skala, och spegling med vänsterspelarens regel (M1).
   - En egen liten modell (ResNet18 eller MobileNetV3) först. RTMPose-s som jämförelse om
     den egna missar målet.
   - GolfPose som förträning om datat fås.
4. **P6 utan tryck.** Modellen körs på varje ruta P5 → P7 (kroppens tider, M28).
   - **Bakifrån:** P6 är rutan där skaftet är kortast och pekar mot flyktpunkten (M45).
   - **Framifrån:** rutan där skaftets vinkel går genom vågrätt (`forslag_tid_skaft`, M45).
   - P1 tas ur adressfönstret (M28) med modellens punkter.
5. **Måtten och spärren.** `klubba.mat` på modellens punkter. Ett mått saknas hellre än är
   fel:
   - när punktens konfidens är låg;
   - när skaftets längd vid P1 skiljer mer än 0,25 L från medianen (som M61:s radie);
   - när modellen och linjen (B) framifrån skiljer mer än 5°.
   Källan i formatet blir ny (till exempel `modell`), skild från `klick`, och modellens
   rutor räknas aldrig som markeringar (som B71).
6. **Mät och skriv.** En METOD-rad (MF7) med provets tal, en BESLUT-rad för vägen och
   licenserna, och FORMAT för källan.

**Klart när:** på provpasset, som modellen inte sett, och mot Johannes handmarkeringar:

- **P6-rutan** ligger inom ±2 rutor (±8 ms vid 240 bilder/s) från Johannes P6 i minst
  80 % av svingarna per vy.
- **Punkterna:** greppets och hoselns fel har medianen högst 2 % av P1-skaftets längd i
  bild och p95 högst 6 %, vid P1, P4, P5, P6 och P7, per vy.
- **`skaft_plan_p6`** (DTL): |auto − hand| har medianen högst **2°** och p95 högst **4°**.
  4° är spärren i M46. Ett hoselfel på 2 % (cirka 6 px) blir cirka 1° när P1- och
  P6-hoslarna ligger 300–500 px isär (räkning).
- **`skaft_arm_p6`** (FO): medianen högst **3°** och p95 högst **6°**. Två punkters fel på
  ett skaft om 285–310 px, plus armen ur lederna.
- **Täckningen:** ett värde i minst 80 % av svingarna, och **inga grova fel** (> 8°) bland
  dem som får ett värde.
- **Handmärkningens brus** redovisas bredvid. Är det större än målen ovan gäller i stället
  att modellen ligger inom 1,5 gånger det.
- S7:s ursprungliga Klart när, skaftets vinkel inom 5° i adress, topp och tidig nedsving i
  båda vyerna, redovisas på samma prov.

Alla gränser är **antaganden**, valda efter M46:s spärr och S7:s 5°. De sätts i METOD när
provet är gjort.

**S7-2 (därefter):** samma modell på telefonen.

- Core ML i FP16, med samma punkter som PyTorch inom 0,5 px på provets rutor.
- Tiden per slag mäts på telefonen.
- Modellfilen förs till telefonen utanför repot (§3).
- Den påhittade modellen används i simulatorprovet.
- Måtten visas med en källrad ("automatic") och kan rättas med S7c:s tryck.

## 5. Frågor till Johannes

1. **GPU:** 2080 Ti har 11 GB enligt specifikationen; du skrev 12 GB. Vad säger
   `nvidia-smi`? Går WSL2 med CUDA på datorn? coremltools har inget Windows-hjul, och mmcv
   är krångligt på Windows.
2. **De nya svingarna (2026-10-24):** filmade i SwingLab (240 bilder/s, låst slutare)
   eller i Kamera-appen? Hur många, och i vilka vyer? Kan det passet vara provet som
   modellen aldrig tränas på?
3. **Märkningen:** cirka 1,5–3 timmar för 40 svingar med S7c i appen, gärna uppdelat. Går
   det, och vill du hellre märka på telefonen eller på PC:n? Bara telefonen ger P6 som
   facit.
4. **GolfPose:** ska vi mejla författaren om datat? Licensen tillåter vikter i appen men
   inte att datat delas vidare. Det stannar på PC:n.
5. **Claude och bilderna:** får Claude se kontaktark ur dina klipp, för att granska
   förslag och välja rutor att märka? Det är data som lämnar PC:n, på ditt initiativ, som
   paketen i S5.
6. **Rättningen i Golf SG (2026-10-17):** där finns greppet och klubbhuvudet i fyra faser
   på några slag (HANDLED_PLAN §3). Ska den med? Klubbhuvudet där är kanske inte hoseln.
7. **Casting:** räcker casting framifrån och planet bakifrån i S7-1 (§4.1), eller vill du
   ha bakifrån först, och då bara planet?
8. **Modellfilen till telefonen:** via dela-menyn eller Filer (utanför repot), eller ett
   privat repo eller en privat release?
9. **Andra spelare:** ska modellen någon gång användas av andra än du? Det avgör om NC-data
   och AGPL alls kan komma i fråga, och om öppen data behövs för bredden.
10. **Din sammanställning:** får vi länka Claude Docs-dokumentet "Swing Lab – öppna
    resurser" härifrån, eller räcker avstämningen i §1.3?
