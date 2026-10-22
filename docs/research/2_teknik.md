# SwingLab — teknik för markörlös svinganalys (research 2)

Datum: 2026-10-22. Cirka 40 sökningar och hämtningar.

**Om källorna.** Många förlag gick inte att hämta härifrån: PMC, arXiv, Springer, PLOS, CVF och Sportsbox hjälpcenter.
Där har jag bara sett sökmotorns utdrag. Sådana rader är märkta **ej läst i original**.
Jag har läst i original: GitHub-sidorna (Pose2Sim, OpenCap, golfdb, GolfPose, anipose, EasyMocap, FreeMoCap), `utilsSync.py` i OpenCap, ClubheadDB på PyPI, Apples dokumentation och WWDC-utskrifterna samt MediaPipes `pose.md`.
Status per rad: **forskning** (granskad), **tillverkare/dokumentation**, **öppen kod**, **antagande** (egen slutsats eller egen räkning).

---

## Sammanfattning och rekommendationer

1. **Det finns ingen oberoende validering av markörlös golf med en kamera som räcker för kinematik.** Den enda golfstudien med mocap som facit (Ingwersen m.fl. 2023) säger att färdiga monokulära 3D-modeller ser rätt ut i bilden men har för stora fel för kinematisk analys. Det stämmer med våra 55–99°. Sportsbox egen jämförelse ger cirka 2° i snitt, men bara i stillastående lägen (adress, topp, träff), mot ett sensorsystem, och skriven av företaget själv.
2. **Vision eller MediaPipe: välj inte 3D ur en kamera från någon av dem.** Använd bara **2D-lederna** och räkna 3D själva genom **triangulering mellan DTL och FO**. För 2D är MediaPipe BlazePose Heavy klart bättre än Apple Vision i Googles egen mätning (mAP 68–74 mot 33–45). Mätningen är tillverkarens egen och bör provas på våra 41 slag. Förslag: Vision 2D på telefonen för direkt återkoppling, och MediaPipe Heavy eller RTMPose på PC:n för siffrorna.
3. **Två kameror byggs så här (antagande, byggt på Pose2Sim och OpenCap):**
   - Inre kalibrering en gång per telefon och linsläge, med ChArUco- eller schackbräde.
   - Yttre kalibrering per pass. Antingen kända punkter i scenen (mattans hörn, boll, alignment-pinnar; Pose2Sim kräver minst 10 punkter), eller självkalibrering ur kroppens leder med bundle adjustment och **klubbans kända längd som skala** (preprint april 2026).
   - Synk: klicket först (±7 ms ≈ 1 bild vid 154 bilder/s). Finjustera sedan med korskorrelation av ledernas fart, som OpenCap och Pose2Sim gör. Interpolera på varje rutas egen tid, eftersom 36 % av rutorna saknas.
   - DTL och FO står nära 90° mot varandra. Det är en bra vinkel för triangulering.
   - Vridningen räknas ur den triangulerade höftlinjen och axellinjen.
   - Väntad noggrannhet: 3–5° i snitt för leder med två eller fler kameror i gång, löpning och hopp (OpenCap 4,5°, Pose2Sim 3–4°). **För golf finns ingen siffra.** Vinkelfart är svagare än vinkel i alla studier jag såg.
4. **Klubbdetektorn måste tränas själva.** Det finns ingen färdig modell som är fri att använda och täcker både skaft och klubbhuvud.
   - GolfPose har fem klubbpunkter och AP cirka 0,86–0,87 för klubban. Datat kräver mejl, och licensen är ett eget EULA.
   - ClubheadDB har bara rutor runt klubbhuvudet, bara DTL, och licensen CC BY-NC 4.0.
   - Roboflow-dataset är små och av okänd kvalitet (CC BY 4.0).
   - Använd GolfPose punktdefinition och märk egna rutor ur egna filmer. Träna en liten nyckelpunktsmodell, till exempel YOLO-pose, och exportera till Core ML. Obs: Ultralytics är AGPL-3.0, vilket är okej för en privat app.
5. **Behåll vår fasmetod.** Klicket som träff (±7 ms) slår SwingNet, som träffar 71–76 % av händelserna inom en tolerans på några bilder och är byggt för cirka 30 bilder/s. SwingNet kan på sin höjd ge adress och avslut, men just de är svagast även där.
6. **Slutartiden är viktigare än bildfrekvensen för klubban.** Oskärpan är fart × exponeringstid. Vid 45 m/s ger 1/1000 s ungefär 45 mm oskärpa och 1/4000 s ungefär 11 mm. Lås exponeringen med `setExposureModeCustom`, använd mycket ljus, och kontrollera flimmer (50 Hz-nät ger 100 Hz flimmer). Rörelseoskärpan förklarar sannolikt varför bäckenets och bröstets toppfart föll på samma bild (antagande).

---

## 1. Noggrannhet: Vision och MediaPipe mot mocap och IMU

| Påstående | Siffror | Status | Källa |
|---|---|---|---|
| Färdiga monokulära 3D-modeller på golf, med markörbaserad mocap som facit: lederna ser rätt ut när de projiceras tillbaka i bilden, men felen är för stora för kinematisk analys. Modellerna går inte att använda för avancerad golfanalys utan vidare träning. | MPJPE okänd (utdraget saknar siffror) | forskning, **ej läst i original** | Ingwersen, Jensen, Hannemose, Dahl, NLDL 2023: https://septentrio.uit.no/index.php/nldl/article/view/6793 · https://orbit.dtu.dk/en/publications/evaluating-current-state-of-monocular-3d-pose-models-for-golf/ |
| BlazePose GHUM mot Apple Vision, 2D, COCO 17 punkter, en person 2–4 m bort. Mätt av Google. | mAP/PCK@0,2: Heavy 68,1/96,4 (yoga), 73,0/97,2 (dans), 74,0/97,5 (HIIT). Apple Vision 32,8/82,7, 36,4/91,4, 44,5/88,6. | tillverkare (Googles egen jämförelse) | https://github.com/google-ai-edge/mediapipe/blob/master/docs/solutions/pose.md |
| MediaPipe-världsleder: 33 punkter i meter med origo mellan höfterna. Metoden kopplas till GHUM. Snabba rörelser tas inte upp. | — | dokumentation | samma som ovan |
| Apple Vision 2D mot hudmarkörer, axelns rörlighet, 20 friska vuxna. Telefonen överskattar rörligheten något. Adduktion var sämst. Skillnaderna förklaras troligen av olika definitioner av bröstkorgens koordinatsystem. | Bias och gränser okända här | forskning, **ej läst i original** | Sensors 2024, 24(2):534: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10818695/ |
| Apple ARKit (inte Vision) mot Vicon, 8 övningar, 10 personer. | MAE 18,8° ± 12,1°, spann 3,75–47° per led och övning, Spearman 0,76 | forskning, **ej läst i original** | Applied Sciences 2022: https://www.mdpi.com/2076-3417/12/10/4806 |
| Pose estimation i RGB mot infraröd mocap, 5 personer, 17 idrottsrörelser. Armbågen var sämst. | MAE 9,7° (atletiska rörelser), 9,0° (idrottsrörelser) | forskning, **ej läst i original** | Sports Engineering 2024: https://link.springer.com/article/10.1007/s12283-024-00460-w |
| MediaPipe med två kameror utan stereokalibrering, med fusion, på träningsövningar. | Median-RMSE 30,1 mot 56,3 för en kamera. Enheten framgick inte. | forskning, **ej läst i original** | Dill m.fl., Sensors 2024, 24(23):7772: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11644880/ |
| AthletePose3D (CVPR-workshop 2025): färdiga modeller klarar idrottsrörelser dåligt. Finjustering sänker MPJPE från 214 mm till 65 mm. Ledvinklarna korrelerar starkt, men **farten skattas sämre**. 12 rörelsetyper, cirka 1,3 miljoner bilder. | se texten | forskning, **ej läst i original**. Licensen är okänd. | https://arxiv.org/abs/2503.07499 |
| Sportsbox mot AMM3D (sensorbaserat system), 30 golfare med ett slag var. Absolut skillnad i snitt över alla vinkelmått: 2,2° vid adress, 2,5° i toppen, 2,0° vid träff. Sway och lift: 0,6 tum i toppen, 0,2 tum vid träff. Ingen separat siffra för bröst- eller bäckenvridning. Skriven av företagets Phil Cheetham. | se texten | tillverkare, **ej läst i original** (sidan kunde inte hämtas) | https://help.sportsbox.ai/sportsbox-ai-accuracy |
| Hur Sportsbox får 3D ur en kamera: företaget säger "30+ punkter på kropp, klubba och boll" ur en video. En utvecklingspartner nämner 6 vyer ur en 2D-video och att den tidiga prototypen hade svårt med noggrannheten utomhus. Ingen granskad studie och ingen vitbok hittad. | — | tillverkare, **ej läst i original** | https://www.sportsbox.ai/about · https://litslink.com/case-studies/ai-golf-swing-analyzer |
| Hur exakt facit är: markörbaserad bröstkorgsriktning i golf har under 1,0° systematiskt och under 3,8° slumpmässigt fel. Vektorn mellan akromion är opålitlig i toppen (−16,0°). | se texten | forskning, **ej läst i original** | Wheat m.fl. 2007: https://shura.shu.ac.uk/614 |
| Polhemus (elektromagnetisk) mot Vicon på 15 elitgolfare: pålitlig mellan pass, men värdena skiljer sig från Vicon vid adress, topp och träff. | — | forskning, **ej läst i original** | https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8271493/ |
| Oberoende sammanställning av kommersiella golfsystem: X-faktor bias −1,4°, gränser −21,4° till +18,6°. Övre bålens vridning bias 1,05°, gränser −11,2° till +13,3°. Originalstudien är okänd. | se texten | **antagande / overifierat** (blogg) | https://www.affinedrift.com/articles/technology-motion-capture.html |

**Slutsats.** Ingen studie har validerat Apple Vision 3D (`VNDetectHumanBodyPose3DRequest`) mot mocap. Jag hittade heller ingen golfvalidering av MediaPipe. Felen ligger runt 5–10° i lugna rörelser, och de växer vid snabba rörelser och vid toppvärden. Vinkelfarten är svagast.

## 2. Två telefoner: synk, kalibrering och noggrannhet

### Verktyg

| Verktyg | Vad det gör | Kalibrering | Synk | Licens | Status och källa |
|---|---|---|---|---|---|
| **Pose2Sim** | 2D-pose (RTMPose som standard; även MediaPipe BlazePose och OpenPose), triangulering, OpenSim-skalning och invers kinematik. Minst 2 kameror, telefoner fungerar. | Inre: ChArUco eller schackbräde. Yttre: **kända scenpunkter (minst 10, utspridda, klickas i varje vy)** eller ett statiskt bräde (sämst enligt README). Rörligt bräde och kalibrering ur lederna är "coming soon". Kan importera kalibrering från bland annat anipose, FreeMoCap och OpenCap. | Ur lederna: korrelerar lodrät fart och väljer förskjutningen med högst korrelation. Blixt, klapp eller GoPro-tidkod går också. | **BSD-3-Clause**. Obs: RTMPose Whole_body bara för icke-kommersiellt bruk. | öppen kod: https://github.com/perfanalytics/pose2sim |
| **OpenCap** (Stanford) | 2 eller fler iPhones, molnbehandling, OpenPose eller mmpose, LSTM som fyller på markörer, OpenSim. Kan köras lokalt, men inspelningar från appen kräver inloggning på app.opencap.ai. | Schackbräde (README visar `main_calcIntrinsics.py`; detaljerna läste jag inte) | `utilsSync.py`: korskorrelation av ledernas fart. Handslag ("punch": handled över axel 0,2–3 s) går före gång, som går före allmän rörelse. Lågpass 12 eller 30 Hz. Max förskjutning 2 s. **Antar samma bildfrekvens i alla kameror och samplar inte om.** Förskjutningen räknas i hela bilder. | **Apache-2.0** | öppen kod: https://github.com/stanfordnmbl/opencap-core · https://github.com/stanfordnmbl/opencap-core/blob/main/utilsSync.py |
| **anipose** | Triangulering med 2D från DeepLabCut, flera vyer | Ett bräde (detaljerna läste jag inte) | Ej angivet | **BSD-2-Clause** | öppen kod: https://github.com/lambdaloop/anipose |
| **FreeMoCap** | Mocap med flera kameror, beror på `skellytracker` | Ej angivet på sidan | Ej angivet | **AGPL-3.0** (annan licens på begäran) | öppen kod: https://github.com/freemocap/freemocap |
| **EasyMocap** (ZJU) | Flera vyer, SMPL-kropp, verktyg för inre och yttre kalibrering. Exemplen har 8–23 synkade kameror. | Ett verktyg finns, målet är inte angivet | Antar synkade kameror | "other". Enligt andrahandskälla bara för icke-kommersiellt bruk, och SMPL har en egen licens. **Ej läst i original.** | https://github.com/zju3dv/EasyMocap |

### Noggrannhet med två eller fler kameror

| Påstående | Siffror | Status | Källa |
|---|---|---|---|
| OpenCap med två iPhones mot markörer: gång, knäböj, resa sig från stol, nedhopp. | MAE 4,5° över 18 rotationsfrihetsgrader, 12,3 mm i förflyttning | forskning, **ej läst i original** | Uhlrich m.fl., PLOS Comput Biol 2023, e1011462: https://pmc.ncbi.nlm.nih.gov/articles/PMC10586693 |
| OpenCap med en kamera (Utah). | 4,8° mot mocap, under 1° skillnad mot OpenCap med två kameror | forskning/tillverkare, **ej läst i original** | https://mobl.mech.utah.edu/opencap-monocular-released/ |
| Pose2Sim mot markörer, en person, nedre extremiteten. | Medelfel 3,0° (gång), 4,1° (löpning), 4,0° (cykling). Höften i löpning hade 15° systematiskt fel. | forskning, **ej läst i original** | Pagnon m.fl., Sensors 2022: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9002957/ |
| Pose2Sim, robusthet: 1 cm kalibreringsfel, färre kameror och sämre bild. | MAE 0,35–1,6° mot referensläget | forskning, **ej läst i original** | https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8512754/ |
| Självkalibrering för idrott med klubba eller klubbträ: kroppens leder plus en stav med känd längd (golfklubba, slagträ, klubba). Tre steg: bundle adjustment utan skala, skala ur stavens längd, och förfining med skala. Utomhus med YOLOv11 tränat på kroppens leder och klubbans två ändar. Syntetiska tester med 3–10 kameror. Kodens licens är okänd. | Felsiffrorna har jag inte sett | forskning (preprint, ej granskad), **ej läst i original** | arXiv 2604.17567: https://arxiv.org/pdf/2604.17567 |
| Yttre kalibrering ur en person som rör sig: orienterade punkter från nacke och ryggrad, faktorisering, RANSAC och bundle adjustment. Bara upp till skala. | — | forskning, **ej läst i original** | Lee m.fl., RA-L 2022: https://vision.ist.i.kyoto-u.ac.jp/pubs/SLee_RAL22.pdf |
| **Golfspecifik noggrannhet för bäckenets och bröstets vridning med två telefoner: okänd.** Jag hittade ingen granskad studie. Onform, GOLFTEC och Uplift säljer system med två kameror utan publicerad validering. | — | — | https://onform.com/blog/onform-launches-fast-reliable-and-accessible-markerless-3d-motion-capture-for-golf/ · https://www.uplift.ai/sports/golf |

### Förslag för SwingLab (antagande)

- **Inre kalibrering:** en gång per telefon i slowmotion-läget (1080×1920, samma lins), med ChArUco. Lås fokus och zoom.
- **Yttre kalibrering per pass:** mattans hörn, bollen och två alignment-pinnar med uppmätta lägen ger mer än 10 kända punkter, som Pose2Sim kräver. Alternativet är självkalibrering ur höfter, axlar och fötter med klubbans längd som skala. Det kräver bundle adjustment, och scipy räcker på PC:n.
- **Synk:** klicket ger ±7 ms. Finjustera med korskorrelation av handledens fart i nedsvingen. Eftersom rutorna har olika tider: interpolera båda vyerna till en gemensam tidsaxel, i stället för OpenCaps förskjutning i hela bilder.
- **Vridningen:** triangulera höger och vänster höft respektive axel, projicera på golvplanet och mät vinkeln mot mållinjen. Golvplanet och mållinjen ges av mattan.

## 3. Klubban: dataset och modeller

| Resurs | Innehåll | Noggrannhet | Licens | Status och källa |
|---|---|---|---|---|
| **GolfPose / GolfSwing** (ICPR 2024) | 2D och 3D för golfare och klubba. 17 kroppspunkter plus upp till 5 klubbpunkter. Klubbpunkterna enligt sökutdrag: skaft, hosel, häl, tå nere, tå uppe. MMPose och MMDetection. | AP för klubban: HRNet-w48 0,857, ViTPose-H 0,870, DEKR 0,858. Golfare och klubba tillsammans: 0,915–0,942. YOLOX-s-detektor AP 0,916–0,984. 3D MPJPE 30,7–39,2 mm. | Eget EULA. Rådata får inte spridas. Kommersiell träning tillåten enligt README. Datat fås på mejl. | öppen kod: https://github.com/MingHanLee/GolfPose. Punktnamnen är **ej lästa i original**. |
| **ClubheadDB** (2025) | 10 180 DTL-bilder ur YouTube (46 %) och Reddit (54 %). En ruta per bild (YOLO-format). 67 golfare, 70 % järn. Ingen baslinje angiven. | — | **CC BY-NC 4.0** | dataset: https://pypi.org/project/clubhead-db/ (GitHub-länken gav 404) |
| **GolfDB** | 1400 YouTube-svingar med händelser, ruta, spelare, klubbtyp och vy. **Ingen klubbmärkning.** | — | Koden: CC BY-NC 4.0. Datasetets licens är inte angiven. | öppen kod: https://github.com/wmcnally/golfdb |
| Roboflow Universe | Flera små golfdataset med klassen club_head, bland annat en keypoint-variant med 233 bilder. Kvaliteten är oprövad. | — | CC BY 4.0 enligt sökutdrag | **ej läst i original**: https://universe.roboflow.com/kilkennyrobo/golf-keypoint · https://universe.roboflow.com/swingfeed/clubheadtrack/dataset/ |
| Klassisk spårning av klubbhuvudet (EPFL) | 2D-spår ur vanlig video, 35 svingar | — | — | forskning, **ej läst i original**: https://www.epfl.ch/labs/cvlab/wp-content/uploads/2018/08/golf.pdf |
| Patent: pose plus linjedetektion för hela klubban, eftersom hoseln är svår att förutsäga | — | — | — | **ej läst i original**: https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/12711647 |

**Core ML.**
- Det finns en Core ML-konvertering av YOLOv8-pose (17 punkter, 640×640, FP16, NMS ingår inte). Källa: https://huggingface.co/hugging-mac/yolov8-pose-coreml (**ej läst i original**).
- Ultralytics exporterar till Core ML och kör på Neural Engine. Källa: https://docs.ultralytics.com/integrations/coreml (**ej läst i original**). Ultralytics licens är AGPL-3.0 (känt, inte kontrollerat i detta pass).
- För RTMPose på Core ML hittade jag inget. Det är **okänt**.

**Vad som är möjligt i nedsvingen (antagande, egen räkning).**
- Klubbhuvudet i 40–50 m/s rör sig 26–32 cm mellan rutorna vid 154 bilder/s, och 17–21 cm vid 240 bilder/s.
- Nära träffen blir klubbhuvudet alltså några få punkter per sving, och varje punkt är en strimma om slutaren inte är kort.
- Skaftet (linjen hand till hosel) syns längre och är lättare. Strimmans riktning kan i sig ge banans riktning.
- Klubbhuvudets fart går att uppskatta ur avståndet mellan rutorna och deras egna tider. Felet är okänt utan facit, till exempel en launch monitor.

## 4. Svingens faser

| Påstående | Status | Källa |
|---|---|---|
| SwingNet (MobileNetV2 + LSTM) hittar 8 händelser i 76,1 % av fallen (med augmentering) och 6 av 8 i 91,8 %. README: 71,5 % utan augmentering. Indata 160×160. | forskning + öppen kod | https://github.com/wmcnally/golfdb · https://openaccess.thecvf.com/content_CVPRW_2019/html/CVSports/McNally_GolfDB_A_Video_Database_for_Golf_Swing_Sequencing_CVPRW_2019_paper.html (artikeln **ej läst i original**) |
| Toleransen i PCE (hur många bilder fel som räknas som rätt), siffror per händelse och videornas bildfrekvens: **okända**, eftersom artikeln inte gick att hämta. | — | arXiv 1903.06528 |
| CaddieSet: adress och avslut är svårast att märka och träffa, eftersom tidpunkten är subjektiv. Utan dem nådde en finjusterad SwingNet 94,1 % på de 6 övriga. | forskning (preprint), **ej läst i original** | https://arxiv.org/pdf/2508.20491 |
| Licens: koden CC BY-NC 4.0. | öppen kod | https://github.com/wmcnally/golfdb |

**Bedömning (antagande).**
- Träffen ur klicket (±7 ms, cirka 1 bild) är bättre än SwingNet. SwingNet är tränat på YouTube-video i låg upplösning och ger fel i hela bilder vid ungefär 30 bilder/s.
- "Händerna högst" ger toppen för händerna. Klubbans topp kommer ofta lite senare. Definiera vilken topp ni menar.
- SwingNet tillför mest för adress och avslut. Där är det svagast, och en enkel regel räcker troligen: händernas fart under en tröskel före svingen och efter den.
- Att ta in SwingNet kostar en modell med icke-kommersiell licens och en PyTorch-väg. Det lönar sig inte.

## 5. Bildfrekvens och oskärpa

| Påstående | Status | Källa |
|---|---|---|
| Oskärpa = fart × exponeringstid. 44,7 m/s ger 4,5 mm vid 1/10 000 s och 45 mm (ett helt klubbhuvud) vid 1/1000 s. Automatisk exponering väljer ofta för lång tid. Shutter styr oskärpan, inte bildfrekvensen. | **antagande** (forum, men räkningen är fysik) | https://www.kinovea.org/en/forum/viewtopic.php?id=435 · https://golfsimulatorforum.com/forum/golf-simulator-forum/simulator-builds/355519-high-speed-swing-analysis-camera-setup |
| LED som inte drivs med likström gav flimmer i höghastighetsfilm. En byggare uppskattar cirka 60 000 lumen för skarpa bilder. | **antagande** (forum) | samma golfsimulatorforum-tråd |
| Kameran i höjd med händerna vid adress, på stativ, båda vyerna. Händerna mitt i bilden. Zooma inte: nära kamera förvränger svingplanet. Ställ skärpan på en pinne där händerna blir. | tillverkare (Titleist), **ej läst i original** | https://www.titleist.com/teamtitleist/team-titleist/f/golf-tips/54984/online-golf-instruction-how-to-film-your-swing |
| V1: FO 6–10 fot (cirka 1,8–3 m) i höfthöjd, DTL 8–12 fot (cirka 2,4–3,7 m). Det strider mot Titleists råd om händernas höjd. | tillverkare, **ej läst i original** | https://swing-analysis.v1sports.com/swing-analysis/swing-recording.md |
| Vision: personen bör vara minst en tredjedel av bildens höjd. Ett känt intresseområde (ROI) ger bättre pose. | dokumentation | https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images |
| Exponeringstid och ISO låses i AVFoundation med `setExposureModeCustom(duration:iso:)`. Gränserna kommer från `activeFormat.minExposureDuration` och `maxISO`. Gränsvärdena för slowmotion-formatet läste jag inte. | dokumentation, **ej läst i original** (sidan gav bara titeln) | https://developer.apple.com/documentation/avfoundation/avcapturedevice/setexposuremodecustom(duration:iso:completionhandler:) |
| Kinematisk sekvens: proffs når toppfart i ordningen bäcken, bröst, arm, klubba. Föraren mot 7-järn skiljer 10–20 ms i timing. Absoluta tider mellan topparna fick jag inte fram: **okänt**. Golfstudier mäter ofta med 240 Hz (Polhemus). | forskning, **ej läst i original** | https://scholarworks.boisestate.edu/ijpah/vol5/iss1/129/ · https://www.mytpi.com/articles/biomechanics/kinematic-sequence-revisited |
| AthletePose3D: vinkel korrelerar bra, fart sämre (se §1). | forskning, **ej läst i original** | https://arxiv.org/abs/2503.07499 |

**Bedömning (antagande).**
- 154 bilder/s ger 6,5 ms mellan rutorna. Det räcker för att skilja topparna åt om de ligger tiotals ms isär. Frekvensen är troligen inte flaskhalsen.
- Flaskhalsen är oskärpan på armar och händer nära träffen och djupgissningen ur en kamera. Därför toppar bäcken och bröst på samma bild.
- Gör så här:
  1. Lås exponeringen till 1/2000 s eller kortare (ungefär 22 mm oskärpa på klubbhuvudet, mindre på kroppen). Kompensera med mycket ljus och hellre högre ISO än lång slutare.
  2. Använd flimmerfritt ljus. I Sverige flimrar nätet med 100 Hz.
  3. Räkna vridningen ur triangulerade höfter och axlar, inte ur en kamera.
  4. Filtrera vinkeln med lågpass på rutornas egna tider innan ni deriverar.
  5. Jämför med en IMU (till exempel en telefon i bältet) som facit för bäckenets fart.

## 6. Apple-plattformen

| Påstående | Status | Källa |
|---|---|---|
| `VNDetectHumanBodyPose3DRequest`: från iOS 17. 17 leder i meter relativt rotleden. Använder AVDepthData om det finns, för bättre noggrannhet. Stateful request. | dokumentation | https://developer.apple.com/documentation/vision/vndetecthumanbodypose3drequest |
| Returnerar bara **ett skelett, den mest framträdande personen**. Utan djupdata är `bodyHeight` en **referenslängd på 1,8 m**. `heightEstimation` anger vilken metod som användes. `cameraOriginMatrix` ger kamerans läge relativt personen. `pointInImage` projicerar tillbaka till 2D. LiDAR ger skala. Inget sägs om avstånd, kroppstyp eller fart. Inga exempel från idrott, bara träning och yoga. | dokumentation (WWDC23 session 111241) | https://developer.apple.com/videos/play/wwdc2023/111241/ |
| Kända svagheter i Vision 2D: sämre nära bildkanten, vid framåtböjd eller upp-och-ner-kropp, vid fladdrande kläder och när en person skymmer en annan. Konfidens per punkt. Apples exempel filtrerar på över 0,1 per punkt och över 0,6 per observation. | dokumentation (WWDC20 session 10653) | https://developer.apple.com/videos/play/wwdc2020/10653/ |
| `VNDetectTrajectoriesRequest`: följer föremål i **parabelbana** (en rät linje räknas också). Kräver **stabil scen och stativ**. Stateful, kräver tidsstämplar. `frameAnalysisSpacing`, `trajectoryLength`, min- och maxstorlek. Nytt spår om föremålet lämnar bilden. Från iOS 14. | dokumentation | https://developer.apple.com/documentation/vision/vndetecttrajectoriesrequest · https://developer.apple.com/videos/play/wwdc2020/10099/ |
| Apples idrottsexempel "Action & Vision" (sittsäck i hål): pose, spår, egen Core ML-detektor för brädet, en action-klassificerare tränad i Create ML på 45 poser, och skala ur brädets kända mått. Inget exempel för golf. | dokumentation / exempelkod | https://developer.apple.com/documentation/vision/building-a-feature-rich-app-for-sports-analysis |
| Ingen oberoende validering av Vision 3D hittad. | — | — |

**Bedömning (antagande).**
- Vision 3D ger skala ur en antagen längd på 1,8 m om djupdata saknas, och slowmotion-video har ingen djupdata. Den är också modellbaserad ur en kamera, alltså samma problem som MediaPipe-världsleder. Använd den inte för vridning.
- `VNDetectTrajectoriesRequest` passar inte klubbhuvudet: bågen är ingen parabel över längre sträckor, och klubbhuvudet syns i för få rutor. Bollen lämnar bilden på en eller två rutor. Spårningen kan möjligen ge bollens startriktning men är **oprövad**.
- Mallen för golf finns i Apples eget exempel: Vision 2D plus en egen Core ML-detektor (för oss klubban) plus skala ur ett känt mått (för oss mattan eller klubbans längd).
