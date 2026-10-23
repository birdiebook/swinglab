# R5 — Vilka mått SwingLab borde ha, och vilka av dagens som är svagast belagda

Research 2026-10-23. Svenska, korta meningar. Underlag: `katalog.json`,
`katalog_3d.json`, METOD M1–M37 och MK6, research 1 (Del 3, Öppna frågor),
research 3 (§(c), §3) och research 4 (Sportsbox). Ingenting i repot är ändrat.

## Läs först: hur källorna är lästa

- **Status per källa:** "läst i original" = sidan eller fulltexten hämtad och läst ·
  "bara abstract" = abstract eller post i en databas · "kunde inte läsas" = 403/429/
  vägrad anslutning, och det som står kommer ur sökmotorns sammanfattning.
- Många förlag (Taylor & Francis, MDPI, Golf Digest US, TWU, Loughborough, UL,
  ISBS-arkivet i Konstanz) gav 403 eller vägrade. Därför är flera fynd
  "kunde inte läsas". De får inte bli gränser förrän de är lästa (BESLUT B10).
- Typ: **forskning** (peer review) · **tillverkare** (Sportsbox, GolfTEC, HackMotion,
  PING) · **tränare** · **antagande** (min slutsats).
- "Okänt" = jag hittade inte siffran. Inget är gissat.

## Sammanfattning: fem fynd

1. **Viktöverföringen har det bästa beviset av allt vi saknar.** Ett snabbt
   skifte mot främre foten i tidig nedsving hänger ihop med lägre handicap och
   högre klubbfart (Jones 2023, 104 amatörer; Mears 2017, 22 låghandicap;
   Okuda 2010, 13 + 17). Tyngdpunkten (COM) ur lederna följer tryckcentrums
   mönster nära (Mears 2017, sökmotor). Framifrån ligger sidledet i bildens plan.
   **Föreslås: kroppens tyngdpunkt i FO och skiftets tidpunkt.**
2. **Konsistensen är ett mått i sig, och den är mätt med 2D-pose bakifrån.**
   Spridningen i framåtlutningen mellan slag hängde ihop med snittscore
   (r = 0,80) och precision (r = 0,61), men medelvinkeln gjorde det inte
   (r = −0,18) (Yamamoto 2023, 27 golfare, HRNet ur en kamera DTL). SwingLab
   räknar redan sd per mått (M25). **Föreslås: spridningen som eget mått.**
3. **Det vertikala mönstret saknas: sänkningen i tidig nedsving och lyftet in i
   träffen.** Sportsbox tour: bäckenet ≈ 2 tum under adressen tidigt i
   nedsvingen och ≈ 1 tum över vid träffen. Sportsbox har "pelvis drop/lift into
   impact" som egna indikatorer. SwingLab mäter lyftet bara vid topp, träff och
   finish, inte botten. **Billigt: ett minimum till.**
4. **Handledens böjning (HackMotion) går inte att mäta ur kroppens leder.**
   Skillnaden mellan handicapgrupper är ≈ 7–10° (HackMotion), mindre än felet i
   2D-pose (research 2: ARKit MAE 18,8°). Vision har inga handpunkter i
   kroppsposen. Handledens **vinkling** (lead arm–skaft, "lag") blir mätbar i FO
   med klubban (S7); 2D-skaftvinklar stämmer med Vicon (r > 0,9, Hunter 2022).
5. **Flera av dagens mått saknar belagt samband med utfall.** Svagast:
   genomsvingens tid, tempot, huvudets rörelser, knänas sway, flying elbow och
   handens bana. Och ett nytt motfynd: hos 66 skickliga golfare hängde
   klubbfarten **inte** väl ihop med X-factor eller stretch, men väl med
   separationen vid **träffen** (Madrid 2020, kunde inte läsas, sökmotor).
   Det rubbar ordningen i `katalog_3d.json` (stretch före X-factor).

---

## Del 1. Föreslagna mått

Varje rad: definition · vy · varför (källa, effekt, urval) · norm · svårighet i
2D med Vision · prioritet. Källornas status står i Del 3.

### 1.1 Tyngdpunkten och viktöverföringen (FO)

**A. `com_sway_<fas>` — kroppens tyngdpunkt i sidled**
- **Definition:** helkroppens tyngdpunkt ur lederna med segmentandelar
  (standardtabell, t.ex. Dempster/de Leva; ej läst här), förflyttning från
  adressen längs X, cm, + mot målet. Topp, träff. Också som andel av stansen:
  0 = bakre fotleden, 1 = främre.
- **Vy:** FO.
- **Varför:** Mears 2017 (22 låghandicap, kraftplattor + mocap): COG och COP
  följer varandra nära, och tidigare COP-rörelse mot främre foten gav högre
  klubbfart (kunde inte läsas). Jones 2023 (104 amatörer, J Sports Sci):
  COP-mönstrets huvudkomponenter korrelerade "högt" med handicap och klubbfart;
  lägre handicap = snabbt skifte framåt i början av nedsvingen (bara abstract;
  r-värden saknas). Okuda 2010 (13 skickliga, 17 svaga): de skickliga belastade
  främre foten mer i nedsvingen och vred bäckenet tidigare (läst i original).
  Chu 2010 (308): viktskiftet ingår i modellen som förklarar 44–74 % av
  bollfarten (bara abstract).
- **Norm:** ingen för COM i cm. Kraft: skickliga laddar bakre foten till ≈ 92 %
  av kroppsvikten i baksvingen (Okuda; enheten är tryckfel i texten).
  NISMAT: främre benet bär 33 % vid toppen hos "proficient" (ej peer review,
  urval okänt).
- **Svårighet:** medel. Alla leder behövs; Vision saknar fötter (tår/häl) och
  huvudets topp, så COM blir en skattning. COM är inte COP: COP rör sig mer och
  tidigare. Bäckenets sway (M15) är redan en grov proxy; COM lägger till bål och
  armar.
- **Prioritet:** hög (tillsammans med B).

**B. `skifte_ms` — när skiftet framåt sker**
- **Definition:** tid från toppen tills COM (eller höftmitten) passerar sitt
  adressläge på väg mot målet, ms, även som % av nedsvingen. Saknas om det
  aldrig sker före träffen.
- **Vy:** FO.
- **Varför:** samma källor som A; poängen i Jones 2023 och Okuda 2010 är
  **tidpunkten**, inte mängden. SuperSpeed (15 golfare, opublicerad):
  långsamt skifte tillbaka till främre benet "kostade fart" (tillverkare).
- **Norm:** okänd i ms. SuperSpeed: ≈ 75 % på främre benet när klubban är
  lodrät i nedsvingen (tillverkare, opublicerad).
- **Svårighet:** låg–medel. Kräver skarp bild i nedsvingen (B11); tiden ur
  ett läge, inte en derivata, så bruset är måttligt.
- **Prioritet:** hög. SwingLab har mängden (`backen_resa_framat`) men inte tiden.

### 1.2 Det vertikala: sänkningen och lyftet (båda vyerna)

**C. `backen_lyft_min_nedsving` och `backen_lyft_in_traff`**
- **Definition:** höftmittens lägsta höjd mellan toppen och träffen, från
  adressen, cm (− = nedåt), och dess tid. Lyftet in i träffen = träffens
  höjd − minimum, cm. Samma för bröstet (`brost_lyft_*`).
- **Vy:** båda (höjdled i bildens plan).
- **Varför:** Sportsbox-data i Golf Digest: bäckenet "almost 2 inches lower"
  tidigt i nedsvingen, ≈ 1 tum över start vid träff; bröstet sjunker ≈ 2 tum
  mitt i nedsvingen (läst i original, tillverkare, urval okänt). Sportsbox
  utbildning listar "pelvis drop into imp" och "pelvis lift into imp" (läst,
  bara rubriker). NISMAT: "unweighting" före träffen skiljer bäst skickliga
  från oskickliga, 76 % mot 29 % (ej peer review, urval okänt). Lyftet i
  träffen hör ihop med främre benets kraft: en TWU-studie (63 skickliga) fann
  samband mellan främre fotens kraft och klubbfart; TWU-avhandlingen fann
  främre knäets sträckmoment r ≈ 0,45 (båda kunde inte läsas).
- **Norm:** Sportsbox tour ≈ −5 cm (min) och ≈ +2,5 cm (träff). Japanska
  Golf Digest anger lyft in i träff 11,6 cm för en touring (sökmotor).
- **Svårighet:** låg. `backen_lyft_*` finns (M8); bara minimum och dess tid
  till. Skalan (M2) och kamerans höjd är samma som för lyften i dag.
- **Prioritet:** hög (billig, tour-mönster belagt av tillverkare). Effekt på
  utfallet är bara indirekt belagd (kraft, inte kinematik).

**D. Främre knäets sträckning (DTL)**
- **Definition:** `framre_kna` (M33) som minimum i tidig nedsving och
  sträckningen till träffen, grader, och sträckfartens topp.
- **Varför:** knäets sträckmoment och främre fotens kraft hänger ihop med
  farten (se C). Men en studie fann **snabbare** sträckning hos amatörer än
  proffs med 5-järn (Technology and Health Care 2017, 15 + 10; kunde inte
  läsas). Bourgain 2022 nämner en andra böjningstopp i främre knät utan
  koppling till fart (läst i original).
- **Norm:** ingen.
- **Svårighet:** medel. Främre knät skyms bakifrån (M33); farten kräver
  skarp bild.
- **Prioritet:** medel–låg. Motstridigt; C fångar samma mönster enklare.

### 1.3 Konsistensen

**E. `<mått>_spridning` — spridningen mellan slagen i passet**
- **Definition:** passets robusta sd (IQR/1,349, M26) för utvalda mått, visad
  som eget tal med trend pass mot pass. Först: bröstets böjning (M6) per fas
  och dess variation inom svingen.
- **Vy:** DTL (där studien mätte).
- **Varför:** Yamamoto 2023 (27 universitetsgolfare, 20 slag var, HRNet ur en
  kamera bakifrån, läst i original): sd mellan slag i framåtlutningen mot
  snittscore r = 0,80, mot precision r = 0,61; spridningen inom svingen mot
  smash factor r = 0,45. Medelvinkeln: r = −0,18, ej signifikant. Langdown
  2013/2015 (20 golfare): skickliga har mindre variation i uppställningen,
  men träffens variation skilde inte (bara abstract).
- **Norm:** ingen. Studiens egen posevalidering saknas, och vissa
  konfidensintervall går inte ihop med r-värdena (läst i original).
- **Svårighet:** låg. Finns redan i M25; det är en vy, inte ny mätning.
  Studien använde öra–höft; Vision har öronen men SwingLab läser 13 leder (M1).
- **Prioritet:** hög. Det enda markörlösa 2D-fyndet med utfall jag hittade.

### 1.4 Bäckenets och bålens lutning (FO)

**F. `hoftlinje_lutning_topp` och `_traff` in i katalogens `matt`**
- **Definition:** finns (M18). Visas i dag bara i adressen.
- **Varför:** TWU (25 golfare, hcp ≤ 3): bäckenets lutning i frontalplanet
  korrelerade med klubbfart r ≈ 0,41–0,52 för tre klubbor (kunde inte läsas).
  Sportsbox tour: "Pelvis side bend" ≈ −8° vid toppen och ≈ +8° vid träffen
  (läst i original, tillverkare).
- **Svårighet:** låg–medel. Höftlederna är mjuka punkter i Vision; vid toppen
  är bäckenet vridet ≈ 40°, så linjen förkortas.
- **Prioritet:** medel (inget nytt att räkna, bara att visa).

**G. `sidbojning_traff` och `sidbojning_finish` in i katalogens `matt`**
- **Definition:** finns (M14). Katalogen visar bara toppen (reverse spine).
- **Varför:** GolfTEC (SwingTRU, > 13 000 elever): axlarnas lutning vid träff
  pro 39° mot 27,5° hos > 100-spelare; "shoulder bend" i finishen pro 32°
  bakåt mot 3,2° (läst i original, tillverkare). Chu 2010: bålens sidlutning i
  modellen för bollfart (bara abstract). **Motfynd:** Joyce 2017 (15
  låghandicap) fann **mindre** sidböjning med högre fart, 5-järn (bara abstract).
- **Norm:** finishen 32° (GolfTEC) är ett riktmärke; definitionen är en
  sensor på ryggen, inte linjen i bild. I finishen vetter bröstet mot målet,
  så bakåtböjningen ligger i FO:s bildplan.
- **Svårighet:** låg (finns).
- **Prioritet:** medel för finishen (stor skillnad, gratis); låg för träffen
  (motstridigt, och M17-frågan om axlarna gäller).

**H. Bäckenets framåtlutning (anterior tilt)**
- **Varför:** Okuda 2010: större bäckenlutning fram/bak hos skickliga vid
  träff och genomsving (läst i original). Horan: män mer bakåtlutning än
  kvinnor vid träff (sökmotor). Griffith: sämst repeterbarhet mellan dagar
  (research 1).
- **Svårighet:** går inte. Ingen punkt på bäckenet utöver höftleden (METOD
  M30). Vision 3D har `root` och `spine`, men ingen bäckenpunkt.
- **Prioritet:** låg. Ingen väg i 2D; M30 står kvar som skattning.

### 1.5 Huvudet

**I. Huvudets lutning och vridning (FO/DTL)**
- **Definition:** linjen öra–öra eller näsa–öra (Vision har öron, ögon och nacke
  som SwingLab inte läser i dag, M1).
- **Varför:** svagt. Byrne & Kenny 2008 (8 golfare, ISBS): mer huvudrörelse i
  en av grupperna; sökmotorns två sammanfattningar säger olika om vilken och
  hur mycket (kunde inte läsas). GolfTEC: huvudet "still over the middle of
  your stance" vid träff (kvalitativt). Bourgain 2022: värdet av huvudet i
  sekvensen är oklart (läst i original). Ingen tournorm i cm hittad.
- **Prioritet:** låg. Inga nya huvudmått; se "svagast belagda".

### 1.6 Handlederna

**J. Främre handledens böjning/sträckning (flexion/extension)**
- **Varför:** HackMotion (> 1 000 000 svingar, läst i original, tillverkare):
  vid toppen 14,5° (< 10 hcp), 17,0° (10–25), 24,3° (> 25); vid träff 3,6°,
  9,0°, 10,7°. Tour vid träff "+10 degrees to -10 degrees". Exempel: samma
  klubbfart, ≈ 23 yards längre med mindre extension (ett slag, inte ett urval).
- **Svårighet:** går inte med kroppsposen. Vinkeln ligger utanför bildplanet i
  båda vyerna, greppet skymmer handen, och skillnaden (≈ 7–10°) är mindre än
  2D-felet. Visions handpose (21 punkter) är inte provad på golfgrepp; ingen
  validering hittad.
- **Prioritet:** låg i 2D. Alternativ: en HackMotion-sensor bredvid, eller
  klubbladets vinkel när S7 finns.

**K. Handledens vinkling och släppet (radial deviation, "lag") — S7**
- **Definition:** vinkeln främre arm (axel → handled) mot skaftet i FO, vid P3
  (armen vågrät), P5 och P6, och när den börjar öppnas i nedsvingen.
- **Varför:** Chu 2010 (308): "delayed release" av armar och handleder i modellen
  (bara abstract). Joyce 2016 (20, hcp 1,9): handledens kinematik mest kopplad
  till klubbfart, 60–67 % förklarad varians (bara abstract). Fedorcik 2012
  (15 + 13): höghandicap 5,7–7,1° mer radial deviation (bara abstract). Suzuki:
  sent släpp ger högre klubbfart (via Bourgain 2022, läst). **Motfynd:** Madrid
  2020 (66, hcp ≤ 3): vinklingens vinkel hängde inte väl ihop med farten
  (kunde inte läsas).
- **Norm:** HackMotion radial deviation vid toppen 8,8° (< 10 hcp) mot 5,6°
  (> 25); tour vinklar "around 20-40 degrees" från adressen (tillverkare).
- **Svårighet:** kräver skaftet. 2D-skaftvinklar mot Vicon: r > 0,9 utom i
  adressen (Hunter 2022, 12 golfare, läst i original). Sportsbox visar "Shaft
  angle face on" och "lwrist angle arm parallel".
- **Prioritet:** hög för S7.

### 1.7 Händernas bana och bredd (FO)

**L. `handbana_langd` och `hand_bredd_topp`**
- **Definition:** greppets väg från toppen till träffen i bildens plan, cm;
  och greppets avstånd till axelmitten vid toppen, cm.
- **Varför:** PING ENSO (> 75 000 svingar): handbanan topp → träff ≈ 50 tum hos
  ensiffriga, rekord 74,4; "longer the arc" ger mer tid att skapa fart (läst i
  original, tillverkare, ingen effektstorlek). deWiz: tour max backswing width
  22 tum (kunde inte läsas, 429). Sportsbox: "Hand Path" och "hand path depth"
  (rubriker).
- **Svårighet:** medel. Djupled syns inte i FO, så längden är en undre gräns
  (som M35). Starkt beroende av kroppslängd.
- **Prioritet:** låg–medel. Bara tillverkare, och farten (M35) mäter samma sak
  mer direkt.

### 1.8 Tiden

**M. `nedsving_s` (och `baksving_s`) in i katalogens `matt`**
- **Definition:** finns som tempots delar (M5). Visa den absoluta tiden.
- **Varför:** Madrid 2020 (66, hcp ≤ 3): kortare nedsving med högre klubbfart
  (kunde inte läsas). Brown 2011 (16 låghandicap, kvinnor): kortare baksving i
  modellen för klubbfart (bara abstract, via sökmotor). Tempots **kvot** har
  inget belagt samband (research 1 §1.9).
- **Svårighet:** låg (klicket ±7 ms, toppen −9 ms bias, M4).
- **Prioritet:** medel. Billigt och robust. Kortare nedsving är delvis en
  följd av högre fart, inte en orsak.

### 1.9 Två telefoner (S6, `katalog_3d.json`)

**N. `xfaktor_traff` — separationen vid träffen**
- **Definition:** bäcken − bröst vid träffen (MK6:s vinklar), grader.
- **Varför:** Madrid 2020 (66): separation vid träff med högre fart; X-factor
  och stretch inte (kunde inte läsas). Meister 2011 (15): X-factor vid träff
  ρ 0,90–0,94 (research 1). NISMAT: 36° ± 5 "proficient", 27° ± 6 "average",
  21° ± 6 "unskilled" (ej peer review, urval okänt). Sportsbox tour: bäcken 40°,
  bröst 30° vid träff (läst i original).
- **Svårighet:** samma som `hofter_oppna_traff` (finns); akromionlinjen vid
  träffen är opålitlig (Wheat, research 1).
- **Prioritet:** hög för S6 (två vinklar som redan räknas).

**O. `axellinje_lutning_topp` i 3D**
- **Varför:** GolfTEC: 36° (pro) mot 29,6° (> 100-spelare) vid toppen (läst i
  original). I FO 2D är axlarna vridna förbi linjen vid toppen (M17), i 3D inte.
- **Prioritet:** medel för S6.

**P. Bäckenets och bröstets största vridfart**
- **Varför:** NISMAT: bäcken 526 mot 413 °/s (proficient mot unskilled); PMC9816382
  (11 + 5): bäckenets fart vid träff skiljer proffs från amatörer (research 1).
- **Svårighet:** hög; derivatan förstärker bruset (research 2).
- **Prioritet:** låg–medel. Sist i S6.

---

## Del 2. Vad apparna visar som SwingLab saknar

| App | Visar | SwingLab saknar | Status · URL |
|---|---|---|---|
| Sportsbox | Indikatorer: "pelvis lift into imp", "pelvis drop into imp", "Chest & Pelvis Sway Transition Max", "Recentering", "Power Position", "Lead wrist angle", "Shaft angle face on", "lwrist angle arm parallel", "Hand Path" | Sänkning/lyft (C), sway-max i övergången, handled, skaft (S7) | läst (bara rubriker) · https://sportsbox-ai.teachable.com/courses/sportsbox-3dgolf-level-2-certification/lectures/51320649 |
| Sportsbox | Tour: pelvis side bend −8°/+8°, sway gap > 6,5 tum vid träff, lyftkurvor | Höftlinjen vid topp/träff i katalogen (F) | läst i original · https://www.australiangolfdigest.com.au/useful-golf-swingfacts-sportsbox-ai-graph |
| GolfTEC SwingTRU | Hip sway, shoulder tilt topp och träff, hip turn träff, shoulder bend finish | Finishens sidböjning i katalogen (G), axellutning topp (O) | läst i original · https://www.golftec.co.za/swingtru · https://golfdigestme.com/swing-numbers-new-study-unlocks-6-swing-secrets/ |
| HackMotion | Handledens flexion/extension och radial/ulnar deviation | Går inte i 2D (J) | läst i original · https://hackmotion.com/insights-from-hackmotion-data/ |
| PING ENSO | Handbanans längd | L (låg) | läst i original · https://golf.com/instruction/sahtih-theegala-golf-swing-ping-enso/ |
| deWiz | Backswing length, max width | L (låg) | kunde inte läsas (429) · https://dewizgolf.com/pages/data-overview |
| Uplift Capture | Ledvinklar, vridfart, sekvens; kräver två iOS-enheter | Sekvens (S6/S7) | bara App Store-text via sökmotor · https://apps.apple.com/us/app/id1501907981 |
| V1 Golf | Skelett, bollspårning, tryckplattor | Tryck (inte i video) | sökmotor · https://apps.apple.com/MX/app/id349715369 |
| Mustard | Betyg 1–10, inga rådata till golfaren | – | sökmotor · https://apps.apple.com/us/app/mustard-golf-swing-analysis/id6499280777 |
| OnForm, Swing Profile, Golf Pose, 3DGolf | Inga mätlistor hittade utöver research 3 | – | ej hittat |

Slutsats: det som andra visar och som går i 2D är sänkning/lyft, höftlinjen,
sidböjningen i finishen och övergångens sway-max. Allt annat kräver S6, S7
eller sensor.

---

## Del 3. Källor

| Källa | Vad den ger | Typ | Status | URL |
|---|---|---|---|---|
| Jones, Wallace, Otto 2023, J Sports Sci 41(4) | 104 amatörer, COP-kontinuum kopplat till hcp och fart | forskning | bara abstract | https://www.sponet.de/sponet/Record/4082253?lng=en |
| Mears m.fl. 2017, Eur J Sport Sci | 22 låghandicap, COG ≈ COP, tidigt skifte → fart | forskning | kunde inte läsas (403) | https://dspace.lboro.ac.uk/2134/23307 |
| Ball & Best 2011, J Sports Sci 29(6) | 46 golfare, front foot / reverse | forskning | bara abstract | https://vuir.vu.edu.au/9101/ |
| Okuda, Gribble, Armstrong 2010, JSSM 9 | 13 + 17, bäckenrotation, viktöverföring, bäckenlutning | forskning | läst i original | https://jssm.org/jssm-09-127.xml-Fulltext |
| Chu m.fl. 2010 | 308, release, lutning, viktskifte, 44–74 % | forskning | bara abstract | https://scholars.uky.edu/en/publications/the-relationship-between-biomechanical-variables-and-driving-perf/ |
| Yamamoto m.fl. 2023, Front Sports Act Living | 27, 2D-pose DTL, spridning ↔ score | forskning | läst i original | https://pmc.ncbi.nlm.nih.gov/articles/PMC10684732/ |
| Langdown, Li, Bridge 2013 | 20, variation vid träff och i uppställning | forskning | bara abstract | https://oro.open.ac.uk/47027 |
| Hunter m.fl. 2022, Sci Rep 12:14012 | 2D-skaftvinklar mot Vicon, r > 0,9 | forskning | läst i original | https://pmc.ncbi.nlm.nih.gov/articles/PMC9385988/ |
| Bourgain m.fl. 2022, Sports 10(6) | översikt 92 artiklar; handled, armbåge, knä, huvud | forskning | läst i original (första halvan) | https://pmc.ncbi.nlm.nih.gov/articles/PMC9227529/ |
| Madrid m.fl. 2020, Appl Sci 10:5728 | 66, kort nedsving och separation vid träff ↔ fart; X-factor/stretch och vinkling inte | forskning | kunde inte läsas (403) | https://www.mdpi.com/2076-3417/10/17/5728 |
| Joyce m.fl. 2016 (ND 150) | 20, handled mest kopplad, 60–67 % | forskning | bara abstract | https://researchonline.nd.edu.au/health_article/150 |
| Joyce m.fl. 2013, Sports Biomech 12(2) | 15, bålens kinematik, 34–67 % | forskning | bara abstract | https://ro.ecu.edu.au/ecuworks2013/748 |
| Joyce 2017, Hum Mov Sci 55 | 15, nedre bålens stretch och mindre sidböjning | forskning | bara abstract | https://researchonline.nd.edu.au/health_article/178 |
| Fedorcik m.fl. 2012, JSAMS 15(3) | 15 + 13, radial deviation | forskning | bara abstract (sökmotor) | https://lida.sport-iat.de/ta/Record/4025246 |
| Brown m.fl. 2011, J Sports Sci 29(14) | 16 kvinnor, kort baksving, bäckenets translation | forskning | bara abstract (sökmotor) | https://pure.ulster.ac.uk/en/publications/determination-of-the-swing-technique-characteristics-and-performa-3/ |
| TWU, nedre kroppen och klubbfart | 25, bäckenets sidlutning r 0,41–0,52, knäets moment | forskning | kunde inte läsas (403) | https://twu-ir.tdl.org/handle/11274/8754 |
| TWU, golfer–ground interaction (författare ej sedda) | 63, främre fotens kraft ↔ fart | forskning | kunde inte läsas | https://twu-ir.tdl.org/items/473a3ba9-da5f-492c-a0e1-6b78412eb1ff |
| Technology and Health Care 2017 | 15 + 10, främre knäets vinkelfart | forskning | kunde inte läsas (403) | https://content.iospress.com/articles/technology-and-health-care/thc1266 |
| Byrne & Kenny 2008, ISBS | 8, huvudrörelse | forskning (konferens) | kunde inte läsas | https://researchrepository.ul.ie/articles/conference_contribution/Kinematic_differences_between_high_and_low_handicap_golfers/19823230 |
| NISMAT, "What Differentiates a Good Golfer…" | X-factor vid träff, vridfarter, unweighting | ej peer review | läst i original (PDF) | https://nismat.org/wp-content/uploads/2023/10/What-Differentiates-a-Good-Golfer-from-a-Bad-Golfer.pdf |
| HackMotion, data per handicap | handledsvinklar | tillverkare | läst i original | https://hackmotion.com/insights-from-hackmotion-data/ |
| HackMotion, tour-data | typiska tour-spann | tillverkare | läst i original | https://hackmotion.com/learn-from-pga-tour-player-wrist-data |
| GolfTEC SwingTRU | sex mått, pro-värden | tillverkare | läst i original | https://www.golftec.co.za/swingtru |
| Golf Digest ME, sex hemligheter | pro mot > 100-spelare | tillverkare | läst i original | https://golfdigestme.com/swing-numbers-new-study-unlocks-6-swing-secrets/ |
| GolfTEC, head drop | tour bend 29°/12°, "power squat" | tillverkare | läst i original | https://scramble.golftec.com/blog/2015/04/explaining-head-drop-golf-swing/ |
| Golf.com, tre GolfTEC-misstag | shoulder turn 88° mot mid-70s | tillverkare | läst i original | https://golf.com/instruction/driving/three-huge-swing-mistakes-costing-power-golftec/ |
| Golf Digest AU, Sportsbox swingfacts | tour-kurvor för lyft, sidböjning, sway | tillverkare | läst i original | https://www.australiangolfdigest.com.au/useful-golf-swingfacts-sportsbox-ai-graph |
| Golf.com, Sportsbox låg/hög hcp | sway vid P4 | tillverkare | läst i original | https://golf.com/instruction/one-piece-swing-data-separate-low-high-handicap/ |
| Golf.com, SuperSpeed-studien | 15, viktskifte, opublicerad | tillverkare | läst i original | https://golf.com/instruction/weight-transfer-play-smart-study/ |
| Golf.com, PING ENSO handbana | handbanans längd | tillverkare | läst i original | https://golf.com/instruction/sahtih-theegala-golf-swing-ping-enso/ |
| Apple, Vision 2D-leder | 19 leder: också ögon, öron, nacke, root | standard | läst i original | https://developer.apple.com/documentation/vision/vnhumanbodyposeobservation/jointname.md |
| Apple, Vision 3D-leder | 17 leder: också spine, topHead, centerHead | standard | läst i original | https://developer.apple.com/documentation/vision/vnhumanbodypose3dobservation/jointname.md |
| Brennan m.fl. 2024, Sports Med (metaanalys) | fysik ↔ klubbfart (hopp > maxstyrka) | forskning | bara sökmotor | https://pmc.ncbi.nlm.nih.gov/articles/PMC11239735/ |

---

## Föreslås in i katalogen (rangordnad)

1. **Spridningen mellan slagen** (E), först bröstets böjning i DTL. Bäst belagt
   av 2D-fynden (Yamamoto 2023, r = 0,80 mot score). Ingen ny mätning.
2. **Skiftets tidpunkt framåt** (B), FO. Stark forskning på tryck (Jones 2023,
   Mears 2017, Okuda 2010); i video via höften eller COM.
3. **Kroppens tyngdpunkt i sidled** (A), FO. Samma källor; medel svårighet.
4. **Sänkningen och lyftet in i träffen** (C), båda vyerna. Billigt; Sportsbox
   tour-kurva och egen indikator.
5. **Separationen vid träffen** (N), 3D. Madrid 2020 och Meister 2011; två
   vinklar som S6 redan räknar.
6. **Handledens vinkling/släpp** (K), FO med klubban (S7). Mycket forskning,
   motstridig om vinkeln, enig om att handleden spelar roll.
7. **Sidböjningen i finishen** (G), FO. Finns redan; GolfTEC 32° mot 3,2°.
8. **Höftlinjen vid topp och träff** (F), FO. Finns redan; TWU r ≈ 0,5.
9. **Nedsvingens tid** (M), båda vyerna. Finns redan; Madrid 2020.
10. **Axellutningen vid toppen i 3D** (O). GolfTEC 36° mot 29,6°.
11. Låg: främre knäets sträckning (D), handbanans längd (L), vridfarterna (P).
    Inte alls i 2D: handledens böjning (J), bäckenets framåtlutning (H),
    nya huvudmått (I).

## Svagast belagda av dagens mått (svagast först)

1. **`genomsving_s`** (M36). Bara från Johannes Sportsbox-lista, inget samband
   med utfall hittat, oprovat på telefonen.
2. **`tempo`** (M5). Kvoten har inget belagt samband (research 1 §1.9); den
   absoluta nedsvingstiden har det (M ovan).
3. **Huvudets mått** (`huvud_sway/lyft/mot_bollen`, M8–M9). En konferens med 8
   golfare och motstridiga sammanfattningar; GolfTEC kvalitativt.
4. **Knänas sway** (`*_kna_sway_*`, M34). Bara att Sportsbox listar dem.
5. **`flying_elbow`** (M12). Ingen siffra, inget utfall. Bourgain nämner bakre
   axelns flexion vid toppen hos erfarna (Healy), inte armbågens riktning.
6. **`over_the_top` / `handbana`** (M13). Ingen gräns i cm; händernas bana är
   inte klubbans (Coleman & Rankin: klubbhuvudet upp till 0,5 m från armens
   plan, via Bourgain).
7. **`reverse_spine`** (M14). Bara TPI; det enda talet (Sportsbox) gäller
   bröstkorgen i 3D.
8. **`sway_gap`** (M19). Definition okänd; Sportsbox tour > 6,5 tum vid träff
   är tillverkarens enda tal, och vårt tecken är inte avstämt.
9. **`backen_bojning_*`** (M30). En egen skattning, inte bäckenets lutning;
   bäckenets framåtböjning är minst repeterbar mellan dagar (Griffith).
10. **`tappad_hallning`** (M6). 2D-felet är lika stort som förlusten, och
    medelvinkeln hängde inte ihop med score (Yamamoto, r = −0,18). Spridningen
    gjorde det; flytta tyngden dit (E).
11. **`xfaktor_stretch` före `xfaktor_topp`** (katalog_3d). Madrid 2020 (66)
    fann inget bra samband med någon av dem; separationen vid träff i stället.
    Kontrollera i original innan ordningen ändras.

Bättre belagda än research 1 trodde: `bojd_framre_arm`/`chicken_wing` (skickliga
sträcker armbågen mer, Zheng och Egret via Bourgain), `framre_arm_vinkelfart_max`
(NISMAT 1167 mot 1010 °/s, ej peer review), `sway_topp` (två tillverkare, samma
riktning).

## Öppna frågor

- Madrid 2020 och Mears 2017 i fulltext: r-värden, och om X-factor/stretch
  verkligen saknar samband hos 66 skickliga.
- Jones 2023: korrelationerna mot handicap och fart, och vilken komponent som
  bär tidpunkten för skiftet.
- Hur nära COM ur 13 leder kommer COM ur en full segmentmodell (påhittad sving
  med kända segment räcker för ett första mått).
- Visions handpose på golfgrepp: hittas handens punkter alls i P4 och P7?
- Byrne & Kenny 2008: vilken grupp rörde huvudet mest.
