# Metod och källor

Varje mått, gräns och konstant i SwingLab, med varifrån den kommer. Koden
hänvisar hit (`// METOD M3`), och en konstant utan rad här är en bugg.

**Källans status:** **mätt** (i det här projektet eller i Golf SG) ·
**standard** · **forskning** ("ej läst i original" = bara hänvisningen eller
sökmotorns sammanfattning är läst) · **tillverkare** (Sportsbox, GEARS,
GolfTEC m.fl.) · **tränare** (TPI, coacher) · **antagande** (ska kalibreras).
"Läst i original" betyder att sidan eller fulltexten är läst: för de flesta källor
gjordes det i research 5 (2026-10-23, `docs/research/5_matt_i_original.md` och 5a–5d).

---

## M1 — Indata: lederna, konfidensen och sidorna

- En sving är en JSON-fil (docs/FORMAT.md): 13 leder i bildens pixlar med
  konfidens, per ruta med egen tid. De 13 är snittet av Apple Visions 2D-leder
  och MediaPipe: näsan, axlarna, armbågarna, handlederna, höfterna, knäna och
  fotlederna. **standard** (båda biblioteken).
- En led med konfidens under **0,3** räknas som saknad i rutan. **antagande**:
  Visions konfidens ligger lägre än MediaPipes synlighet, som Golf SG skär vid
  0,5. Kalibreras mot MediaPipe i S3.
- **Greppregeln:** händerna sitter ihop på greppet, så en saknad handled tar den
  andras plats; saknas båda är händerna borta i rutan. Samma regel som Golf SG
  (`handled_kalibrering.grepp_regel`), där den främre handleden ofta var skymd
  bakifrån i adressen. **mätt** (Golf SG, oktobers mätning, HANDLED_PLAN).
- **Sidorna:** lederna läses om till främre (mot målet) och bakre sida, och
  bildens x vänds så att +X pekar mot målet (FO) eller mot bollen (DTL). En
  vänsterspelare blir då samma figur som en högerspelare. Utan riktningsfält är
  standarden +1 för höger och −1 för vänster (kameran står likadant, spelaren
  är spegelvänd). Provat: en speglad påhittad sving ger samma tal inom 10⁻⁶.

## M2 — Skalan: centimeter per pixel

- Vision 2D har inga världsleder, så skalan kommer ur spelarens längd H och
  antropometriska kvoter: axelhöjd 0,818 H, höfthöjd 0,530 H, (knähöjd 0,285 H),
  fotledshöjd 0,039 H. Drillis & Contini 1966, via Winter, *Biomechanics and
  Motor Control of Human Movement* (tabell över segmentlängder).
  **forskning, ej läst i original.**
- **DTL:** bålen (axelmitt–höftmitt) i adressen ligger i bildens plan: dess
  längd i pixlar motsvarar (0,818 − 0,530) H = 0,288 H.
- **FO:** benen (höftmitt–fotledsmitt) i adressen: (0,530 − 0,039) H = 0,491 H.
  Bålen är förkortad framifrån av framåtböjningen.
- Samma val av segment som Golf SG, som tog längden ur MediaPipes världsleder.
- **Felkällor (antagande):** knäna är böjda i adressen (25° kortar benet ≈ 2 %),
  benen lutar bort från kameran framifrån, och kvoterna gäller en
  genomsnittskropp. Skalan bär därför några procent, ungefär som Golf SG:s
  ±10 %. Ett mått i cm jämförs bäst med sig självt pass mot pass.

## M3 — Utjämningen på ojämna tider

- Varje leds x och y jämnas med en **gaussvikt över tiden**: rutan blir det
  viktade medlet av rutorna inom 3σ, vikten exp(−½(Δt/σ)²), **σ = 7,5 ms**.
  Saknade värden räknas inte, och **en ruta där leden saknas förblir saknad**:
  utjämningen fyller inga luckor.
  **antagande:** samma varians som Golf SG:s glidande medel över 25 ms
  (25/√12 ≈ 7,2 ms), men vikten avtar mjukt och fungerar på ojämna steg.
- Tiden räknas ur rutornas egna tider, aldrig ur rutnumret: 36 % av
  240-rutnätet saknades i oktober. **mätt** (Golf SG).
- Ett värde vid en tid är **linjär interpolation** mellan de två närmaste
  rutorna med värde. Över en lucka längre än **0,10 s** mellan två rutor där
  leden syns interpoleras inte: måttet saknas hellre än gissas. **antagande.**
  Eftersom utjämningen inte fyller är det den råa luckan som spärras. Det är
  rätt för mätningen: en gräns som gällde den utjämnade serien skulle släppa
  igenom råa luckor upp till 0,10 s + 6σ ≈ 0,145 s, där en hand hinner röra sig
  en halvmeter. Provat: en rå lucka på 0,096 s interpoleras, 0,104 s inte, och
  i fixturen `fo_luckor` saknas bäckenet vid toppen (0,146 s) medan huvudet
  finns (0,067 s).
- Uppmätt på påhittade svingar: luckorna gör vikterna osymmetriska, så en jämn
  rörelse förskjuts upp till 4 ms.

## M4 — Faserna

- **Toppen:** händerna (medel av handlederna, efter greppregeln) står högst i
  bild, minst y, mellan 1,5 och 0,05 s före klicket. Golf SG:s definition
  ("videons topp") och fönster när bandets start saknas. **standard** i Golf
  SG; Blast påpekar att tour-intervallet för tempot beror på hur toppen
  definieras (research 1 §1.9).
- **Avvikelser från Golf SG** (`handled_svingmatt.tider`): (1) tiden förfinas
  med en parabel genom rutan och dess två grannar (ojämna steg), i stället för
  rutans tid: vid 240 bilder/s med luckor kan närmaste ruta ligga 4–12 ms från
  toppen. (2) Golf SG söker från bandets start när bandet finns; här finns inget
  band (S1 bygger på videon ensam), så fönstret är alltid 1,5 s. (3) Starten
  och adressläget nedan är nya: Golf SG tog starten ur bandet och litade inte på
  videons, eftersom en waggle flyttar händerna lika mycket.
- **Toppens bias, uppmätt på påhittade svingar** (nedsvingen 3 gånger snabbare
  än baksvingen): utjämningen drar toppen mot baksvingen, i snitt **−9 ms** utan
  brus (sd 1 ms), −10 ± 5 ms med 0,8 px brus och −13 ± 9 ms med 2 px. Tempot
  blir då ≈ 0,1 lägre än figurens. En minsta kvadrat-parabel över ±40 ms eller
  ett större σ gav mindre spridning men dubbelt så stor bias (−17 till −25 ms),
  så den enkla skattaren står kvar: passets median tar bort bruset, inte
  biasen. Mäts mot riktig video i S3.
- **Adressläget:** händernas lägsta punkt (störst y) inom 1,5 s före toppen.
- **Baksvingens start:** sista gången före toppen som händerna var inom
  **5 % av vägen adressläge → topp** från adressläget, interpolerat mellan
  rutorna. Det är detsamma som "första tid efter adressen där händerna rört sig
  mer än tröskeln", men räknat bakåt från toppen så att en waggle före
  adressen inte tas för starten. En baksving under **0,5 s** betyder att
  starten är fel, och då saknas den (Golf SG:s gräns för bandets start; en
  verklig baksving med järn är 0,7–1,0 s). **antagande** (5 % ≈ 3–4 cm med
  järn). Uppmätt: inom 3 ms från figurens start. Fixturen `dtl_kort` (0,25 s)
  ger ingen start och inget tempo. **Bakifrån (DTL) tas starten ur posen i
  stället (M40);** framifrån (FO) gäller definitionen här.
- **Träffen:** `t_klick`, klicket i ljudet (±7 ms, Golf SG). **mätt.**
- **Adressen:** medel över start −0,40…−0,10 s. Saknas starten: toppen −1,2 s
  i stället för starten. **Finish:** medel över träffen +1,0…+1,2 s. Samma
  fönster som Golf SG (`FAS_FONSTER`, `FINISH`). **standard** i Golf SG.
- **Ett läge i en fas** är punktens medel över adressens och finishens fönster,
  och värdet i ögonblicket vid toppen och träffen. En vinkel räknas ur lägena,
  inte som medel av vinklar.

## M40 — Baksvingens start bakifrån (DTL)

- **Problemet:** bakifrån går händernas första rörelse mot kameran och syns knappt
  i bilden, och står kameran högre än händerna ser de ut att sjunka innan de
  stiger. M4:s adressläge (händerna lägst) hamnar då i takeawayn och starten blir
  sen eller saknas. Uppmätt på påhittade 3D-svingar (`tools/pc/tre_d/sving.py`,
  frön 0–11) sedda bakifrån 3 m bort, med 0,8 px brus: starten **+176 till +265 ms**
  sen (kameran på 0,8–1,6 m), och saknas för 0–9 av 12 svingar när kameran står
  över händerna (1,3–1,6 m). Med baksvingen 0,75 s saknas tempot; med 0,95 s blir
  det ≈ 1 för lågt (`dtl_dold`-svingen: 2,15 mot sanna 3,17).
- **Definitionen:** posen = de sex lederna axlarna, armbågarna och handlederna
  (efter greppregeln, M1), utjämnade (M3). **Adressen** är det fönster om
  **0,1 s** (minst **3** rutor per led), med början mellan toppen − 1,5 s och
  toppen − 0,5 s (M4:s gränser), där posen skakar minst; skakningen är medlet över
  lederna av rutornas kvadrerade avstånd till ledens medel i fönstret, och adressens
  pose är medlen. **Starten** är sista gången före toppen som posens medelavstånd
  till adressen var inom **3 %** av medelavståndet vid toppen, men minst **3 gånger**
  skakningen (roten ur), interpolerat mellan rutorna. Lederna är de som har minst 3
  rutor i fönstret och ett värde vid toppen, och de måste vara minst **4** av 6. En
  baksving under 0,5 s ger ingen start (M4). **antagande** (andelarna och fönstret,
  valda på mätningen nedan).
- **Varför posen och inte händerna:** axlarna börjar vrida sig och armbågarna flytta
  sig i bildens plan när händerna går mot kameran, så posens avstånd till adressen
  växer från första stund och vänder inte tillbaka. Prövat på samma svingar (fel
  mot starten på den verkliga banan, M4:s 5 % i 3D, ms, kameran 0,8 → 1,6 m):
  med 0,8 px brus: händernas fart med en tröskel på 3 gånger bruset i stillastående
  (+75 till +160; med 5 gånger saknas 5–8 av 12, eftersom farten är nära noll där
  händerna vänder i sjunkandet); händerna med adressen ur stillastående i stället för
  lägst (oftast +150 till +275, och saknas för upp till alla 12); axlarnas läge ensamma
  (−10 till 0, men −52 ± 47 med posemodellens brus, eftersom den främre axeln skyms
  bakifrån, och +112 till +139 när bålen vrider senare än armarna); bakre armbågen
  och händerna (+16 till +115); hela posen (de sex lederna): +2 till +31, och oftast
  inom ±40 med posemodellens brus. Underarmarnas skenbara längd (skalan) ändras
  lika mycket av att armarna vrids som av att de närmar sig kameran, och gavs inte
  en egen skattare. Bakåt från toppen (inte framåt
  från adressen) behålls, som i M4.
- **Uppmätt (posen, frön 0–11, kameran 0,8 / 1,0 / 1,3 / 1,6 m):** med 0,8 px brus
  starten +31 / +23 / +11 / +2 ms (sd 2–4), största felet på tempot **0,14**; med
  posemodellens brus "bra" (3 px, `tre_d/kamera.py`) +8 / 0 / −12 / −19 ms (sd
  10–17), största tempofelet 0,14; med "typiskt" (5 px) +4 / 0 / −13 / −30 ms (sd
  41–48), största 0,34. Likadant när bålen vrider senare än armarna och med
  baksvingen 0,75 s (största 0,33). Tempofelet här är bara starten; toppens fel (M4) kommer till. Framifrån
  gav samma pose −19 till −15 ms (M4 +71 till +73 på samma 3D-svingar, eftersom
  händerna sjunker lite även där), men FO behåller M4 tills riktiga pass prövats.
- **Utan dold takeaway** (den plana figuren i `generera.py`, frön 0–19, 0,8 px):
  starten −26 till −18 ms mot M4:s (armbågen och axlarna rör sig före händerna nått
  5 %), och tempot −0,06 i snitt mot M4:s −0,12 (toppens bias, M4).
- **Osäker start:** är adressens skakning (roten ur) över **1,5 %** av
  medelavståndet vid toppen är starten **osäker**: den står kvar (adressens fönster
  räknas från den), men tempot, baksvingen och nedsvingen saknas, och
  `faser.start_osaker` är sant. Starten är också osäker när rutorna kring den ligger
  mer än **0,10 s** isär (M3:s `MAX_LUCKA_S`: en led saknas över starten, och
  interpolationen flyttade den tyst: uppmätt upp till 0,27 på tempot med bakre armbågen borta 0,18 s, frön 30–41), och när klippet börjar
  efter toppen − 1,5 s och adressens fönster är klippets första ruta (adressen kan ha
  börjat före klippet). Räcker inte posen (färre än 4 leder) tas starten ur händerna
  (M4) och märks osäker, och bakifrån utan start är `start_osaker` också sant (FO som
  förut: falskt). Gränsen 1,5 % är ett **antagande** tills S3 mätt posemodellens brus
  på golf.
- **Taken i testerna** (`test_faser.StartenBakifran`, slumpade svingar med frön 30–41,
  kameran 0,8 / 1,0 / 1,4 / 1,6 m, 48 svingar; tempofelet från starten räknas med den
  mätta toppen och träffen): med 0,8 px brus märks ingen, tempofelet från starten högst
  **0,15** (uppmätt 0,13) och hela tempot högst **0,20** (uppmätt 0,15). Med
  posemodellens brus "bra" (3 px) märks ingen och tempofelet från starten är högst
  **0,35** (uppmätt 0,31 för ett frö, 95 % under 0,15). Med "typiskt" (5 px) märks 30
  av 48, och av de omärkta har högst **30 %** ett tempofel från starten över 0,25
  (uppmätt 4 av 18). "Dåligt" (10 px) märks alltid.
- **Mätningens version:** 2 sedan denna start, 3 sedan M41–M43 och spridningen (S1e)
  (`matt.MATVERSION`, Swift `ShotMeasuring.version`). Ett slag eller pass mätt med en äldre (utan fältet = 1) mäts
  om, annars får DTL-historiken ett falskt tempohopp (≈ +1) och adressens mått flyttar
  sig: telefonen mäter om slaget när passet öppnas (MS14), och PC:ns `historik.py`
  listar passen vars `analys.json` har en äldre `matversion` (`kor_om` i minnet) så
  att session.py körs igen.
- **På telefonen:** slaget sparar flaggan (`ShotMeasure.startUncertain`), och passet
  räknar slagen med osäker start (`Pass.osakerStart`). Saknas passets tempo och har
  passet sådana slag visar tempokortet och Today-raden "—" (Today utan spann), och
  infobladets källrad slutar med "no tempo when the start is unclear from behind".
  Har bara en del av slagen osäker start är tempot medianen av de övriga. Svartvitt
  och utan värdeord (BESLUT B13). VoiceOver säger "Swing tempo, not measured"
  (`Texter.ejMatt`).
- **Två telefoner:** när båda vyerna filmar tar 3D-måtten redan FO:s start (MK6),
  och tempot tas ur en vy (MT9). Det behövs ingen ny väg för starten.
- **Oprovat på telefonen:** riktiga DTL-pass, waggle och forward press (en waggle
  kan ge ett stillare fönster före den än efter; då kan starten hamna i waggeln).

## M5 — Tempot

- tempo = (topp − start) / (träff − topp), baksvingen och nedsvingen i s.
  Båda vyerna. Saknas starten, eller är den osäker (M40), saknas tempot och baksvingens
  tid; nedsvingens tid (`nedsving_s` = träff − topp) räknas ändå, eftersom den inte
  beror på starten (S1e).
- **Gräns i katalogen:** 2,5–3,1 grönt (Blast Motion, tour), utanför gult,
  aldrig rött. **tillverkare, läst i original** (research 5c §5). Blast definierar
  inte toppen; vår är händernas högsta punkt och ligger ≈ 9 ms tidigt (M4), så tempot
  är troligen något lågt mot Blast. Gränsen behålls (BESLUT B45), med låg prioritet:
  **kvoten skiljer inte nivåer.** Grober 2006 (läst i original): proffs 2,5–3,5 med
  medel nära 3,0, och amatörer har också medel 3,0, med större spridning. Novosel 3:1
  är läst via Grober (boken ej läst), och Grobers 2,8:1 (2010) är en enda spelare.
- **Nedsvingens tid** (`nedsving_s`, finns sedan S1) står i katalogens `matt` vid P7 i
  båda vyerna (S1e), och tempokortet i passet visar baksvingens och nedsvingens
  sekunder. Tour med driver: Sportsbox 0,26 s, Blast 0,23–0,32 s, AMM ≈ 0,25 s
  (tillverkare, läst i original, research 5a, 5c); kortare nedsving med högre fart
  (Madrid 2020, kunde inte läsas). Ingen gräns: egen baslinje. Tiden räknas från
  den uppmätta toppen (≈ 9 ms tidig, M4) till klicket, också när starten saknas.
- **Bakifrån (DTL)** syns takeawayn knappt (den går mot kameran), och händernas start
  (M4) kom sent eller saknades (utredningen 2026-10-23: ett importerat DTL-pass utan
  tempo på Today). Starten bakifrån tas därför ur posen (M40). Är den osäker saknas
  tempot och `faser.start_osaker` är sant; vyerna visar då "—" (M40).

## M6 — Bröstets böjning och tappad hållning (DTL)

- `brost_bojning_<fas>`: linjen höftmitt → axelmitt mot lodlinjen i bild,
  grader, **+ framåt mot bollen**. Adress, topp, träff, finish.
- `brost_bojning_tapp` = adressens − träffens böjning, **+ = bröstet reste sig**
  (loss of posture). Egen baslinje (BESLUT B45): Sportsbox Chest Bend (bröstkorgen i
  3D mot lodlinjen, + framåt, **nollas inte** vid adressen) ger tour adress 39°/44° och
  träff 35°/43° (driver/järn), alltså ett tapp på +4°/+1° (tillverkare, läst i
  original, research 5a). Det är inte linjen höftmitt → axelmitt i bild, och tappet
  är mindre än felet i 2D: Mears 2016 (läst i original, författarens manus) fann
  2D-projektionen av markörerna −6,5 ± 3,6° från 3D i flexion vid toppen, och en
  kamera ger 2–7° (research 5 §1.8). Yamamoto 2023 (läst i original): spridningen
  mellan slagen i framåtlutningen hängde ihop med snittscore (r = 0,80), medelvinkeln
  inte (r = −0,18); spridningen är M44.
- Portat från Golf SG (`vinkel_fran_lod`). GolfTEC (Troyer) anger tour ≈ 40° framåt
  i adressen ("shoulder bend", en sensor, inte linjen i bild). **tillverkare, läst i
  original** (research 5c §1b).

## M7 — Bäckenets thrust (DTL)

- `backen_thrust_<fas>`: höftmittens förflyttning från adressen längs X, cm,
  **+ mot bollen** = early extension. Topp, träff, finish.
- Tecknet följer av M1 och är provat på en påhittad sving (+3 cm mot bollen
  ger +3,0). Det rättar inte frågan i S0 om oktobers tal, som räknades i
  bildens råa x.
- **Gräns i katalogen** (`early_extension`, BESLUT B45): ≤ +4,3 cm grönt, +4,3…+8,4
  gult, över +8,4 rött. Sportsbox Pelvis Thrust (bäckenets mitt mellan höftlederna,
  0 vid adressen, **+ mot bollen**, bara bakifrån, läst i original, research 5a) har
  samma definition, nollpunkt och tecken som M7, och bakifrån ligger rörelsen mot
  bollen i bildens plan. Sportsbox ideal vid träff −2,3…+4,3 cm (−0,9…+1,7 tum, för
  en man av DeChambeaus storlek), tour +1,3 cm (SD 3,6 cm, klubban anges inte):
  grönt till idealets övre gräns, rött över tour-medel + 2 SD (+0,5 + 2 × 1,4 tum =
  8,4 cm). Båda gränserna är **antaganden** byggda på tillverkarens tal
  (`grans_harledd`).
- **Kroppslängden:** källan anger idealet för en man av DeChambeaus storlek och skalar
  sina egna mått med längden; vi skalar inte om gränsen. M2 ger centimetrar ur
  spelarens längd, så en kortare spelare med samma rörelse i proportion får ett mindre
  tal, och gränsen blir då något generösare för honom. **antagande.**
- **Perspektivet bakifrån:** kameran står bakom spelaren och ser bäckenet snett när det
  vrider sig i nedsvingen; höftmitten i bild kan då flytta sig 1–2 cm "mot bollen" utan
  att bäckenet gör det. Talet vid träffen kan alltså vara något för högt mot Sportsbox
  3D-tal. Det prövas på riktiga DTL-pass (S3). **antagande.**
- TPI: early extension = bäckenet mot bollen i nedsvingen (definitionen läst i
  original, research 5c §2); 67 % av > 90 000 screenade, 1 % av tour. TPI:s exempel
  (mer än 3 tum vid träff) anger varken mätsystem eller punkt, så det blir ingen gräns.

## M8 — Lyften (bäckenet och huvudet, båda vyerna)

- `backen_lyft_<fas>`, `huvud_lyft_<fas>`: förflyttningen från adressen i
  höjdled, cm, **+ uppåt**. Topp, träff, finish. Huvudet är näsan.
- Sportsbox Pelvis Lift och Head Lift har samma nollpunkt och tecken (läst i
  original, research 5a). Tour bäcken: −4,3/−3,6 cm vid toppen, +2,3 cm vid träffen
  (driver/järn). Bäckenets lägsta punkt i nedsvingen och lyftet därifrån: M43.

## M9 — Huvudet: mot bollen (DTL) och sway (FO)

- `huvud_mot_bollen_<fas>` (DTL, + mot bollen) och `huvud_sway_<fas>` (FO,
  + mot målet): näsans förflyttning från adressen, cm. Topp, träff, finish.
- Sportsbox Head Sway, Lift och Thrust har samma tecken (läst i original, research
  5a). Inget tourvärde hittat; bedöms bäst tillsammans med bröstets sway
  (research 1 §1.2). Huvudets mått är bland de svagast belagda (research 5 §6).

## M10 — Bröstets thrust (DTL)

- `brost_thrust_<fas>`: axelmittens förflyttning från adressen längs X, cm,
  + mot bollen. Topp, träff, finish. Följer både bäckenets thrust och
  böjningen (M6).

## M11 — Bakre knäet (DTL)

- `bakre_kna_<fas>`: bakre höft–knä–fotled, **böjningen i grader, 0 = rakt
  ben**. Adress, topp, träff. Bakifrån ligger bakre benet närmast kameran.
  Portat från Golf SG (`knavinkel`).

## M12 — Bakre armbågen vid toppen (DTL, flying elbow)

- `bakre_armbage_topp`: bakre överarmen (axel → armbåge) mot lodlinjen nedåt,
  grader, **+ = armbågen pekar bort från bollen**, ut bakom spelaren. 0 =
  armbågen rakt under axeln. **antagande** (TPI:s beskrivning av flying elbow,
  ingen gräns i grader hittad). Egen baslinje.

## M13 — Handens bana (DTL, over the top)

- `handbana`: händernas X i nedsvingen minus i baksvingen **på samma höjd**,
  cm, medel över tre höjder: 25, 50 och 75 % av vägen från adressens höjd till
  toppens. Varje höjd tas där händerna första gången passerar den (baksvingen
  från starten till toppen, nedsvingen från toppen till träffen), linjärt mellan
  rutorna. **+ = utanför (mot bollen) = over the top.** Saknas en höjd saknas
  måttet. **antagande:** ingen gräns i cm hittad; förekomsten 43,5 % kommer från en
  klinik som återger TPI utan källa (research 5c §2). Klubbans bana kommer i S7.
- Uppmätt på påhittade svingar (händerna 4–6 m/s i nedsvingen): rutnätet med
  luckor ger −0,06 cm och utjämningen ytterligare −0,05 cm på 3,2 cm, ≈ 4 %.

## M14 — Sidböjningen och reverse spine (FO)

- `sidbojning_<fas>`: linjen höftmitt → axelmitt mot lodlinjen i bild, grader,
  **+ bort från målet** (som Golf SG: −vinkel_fran_lod). Adress, topp, träff,
  finish.
- **Reverse spine** = negativ sidböjning vid toppen: överkroppen lutar mot
  målet. Katalogen tar `sidbojning_topp` med det sämre hållet nedåt och egen
  baslinje. TPI kopplar felet till ländryggen. **tränare, läst i original**
  (definitionen, inga tal; research 5c §2).
- Sportsbox Chest Side Bend är bröstkorgen i 3D mot vågrätt (+ = bakre sidan lägre),
  inte linjen i bild: tour vid träff 32°/22° (driver/järn), PGA 24,1–37,5° med driver
  (läst i original, research 5a). Mears 2016: 2D underskattar sidböjningen vid träff
  med 8,7 ± 2,9° (läst i original). Ingen gräns.
- **Finishen** (S1e): `sidbojning_finish` står i katalogens `matt` vid P10, framifrån:
  i finishen vetter bröstet mot målet, och bakåtlutningen bort från målet ligger i
  bildens plan. GolfTEC Shoulder Bend i finish: tour 32°, hcp 5–0 20,6°, 31+ 3,2°
  (tillverkare, läst i original, bild; research 5c §1), det mått som skiljer grupperna
  mest. GolfTEC mäter med sensorer i 3D, inte linjen höftmitt → axelmitt i bild, så
  talen tas inte in: egen baslinje.

## M15 — Bäckenets sway (FO)

- `backen_sway_<fas>`: höftmittens förflyttning från adressen längs X, cm,
  **+ mot målet**. Topp, träff, finish. Portat från Golf SG.
- **Gräns vid toppen** (katalogen `sway_topp`, BESLUT B45): ≥ −2,5 grönt, −5…−2,5
  gult, under −5 rött. Sportsbox Pelvis Sway (bäckenets mitt mellan höftlederna, 0
  vid adressen, **+ mot målet**, läst i original, research 5a) har samma definition,
  nollpunkt och tecken som M15, och framifrån ligger sidledet i bildens plan: det
  som skiljer är 2D mot 3D. Tour vid P4: −1,5 cm med driver, 0,0 med järn (tabellen,
  bild). Låghandicap nära 0, höghandicap "flera tum" bort (golf.com, läst i original,
  inga tal). **tillverkare, läst i original**; gränsen är ett **antagande** byggt på
  de två (`grans_harledd`): båda klubbornas tour-tal är gröna, så gränsen beror inte
  på klubban. −2,5 cm ligger nära brusgolvet (≈ 2 cm, research 5 §1.8).
- **Positionen är inte densamma:** måttets definition, nollpunkt och tecken är
  Sportsbox, men inte toppen. Sportsbox TOP är där klubban byter riktning; vår topp är
  händernas högsta punkt (M4) och ligger dessutom ≈ 9 ms tidigt. Kring toppen rör sig
  bäckenet redan mot målet (låghandicappare börjar före toppen, golf.com), så vårt tal
  blir systematiskt mer negativt än Sportsbox, i storleksordningen 1 cm per 20 ms.
  Gränsen behålls; skillnaden mellan händernas och klubbans topp prövas på ett riktigt
  FO-pass (S3, S7). **antagande.**
- GolfTEC:s 3,9 tum mot målet vid toppen mäts på svanskotan, som flyttas mot målet när
  höfterna vrids (research 5a §C, 5c §1): ett annat mått, och det tas inte in.
- **Vid träffen:** tour +11,4 cm (driver), +12,2 cm (järn); proffs cirka 6 tum och
  amatörer sällan över 2 tum (Golf Digest, mätt med Sportsbox). Inget fel vid träffen;
  resan från toppen är M21.

## M16 — Bröstets sway (FO)

- `brost_sway_<fas>`: axelmittens förflyttning från adressen längs X, cm,
  + mot målet. Topp, träff, finish. Sportsbox Chest Sway har samma nollpunkt och
  tecken (läst i original, research 5a): tour −3,3/−0,3 cm vid toppen och −1,8/+3,3 cm
  vid träffen (driver/järn).

## M17 — Axellinjens lutning (FO) — granskas

- `axellinje_lutning_<fas>`: linjen bakre axel → främre axel mot vågrätt i
  bild, grader, **+ = bakre axeln lägre**. Adress och träff (vid toppen och i
  finishen är axlarna vridna förbi linjen). Portat från Golf SG.
- **Definitionen granskas i S0.** Referensen är **22–25° med järn** (BESLUT B45):
  Sportsbox Chest Side Bend vid träff 22° med järn (32° med driver) har samma
  nollpunkt och tecken (mot vågrätt, + = bakre sidan lägre) men är bröstkorgen i 3D,
  och Meisters S-faktor (akromionlinjen mot horisontalplanet i 3D) är 25 ± 3° hos
  proffs med järn 5 (forskning, läst i original, research 5b). GolfTEC:s 39° ("shoulder
  tilt") har en oklar referens ("level (upright)") och jämförs inte. En 2D-linje blir
  lägre än 3D (Mears: −8,7° i sidböjning vid träff), och axelpunkterna (akromion) är
  opålitliga vid träffen (Wheat 2007, bara abstract). Ett lågt värde i oktobers mätning
  (Golf SG, HANDLED_PLAN §4) är alltså delvis väntat. **Måttet får ingen tour-gräns**,
  och felet i katalogen är avstängt tills S0 är klar.

## M18 — Höftlinjens lutning (FO)

- `hoftlinje_lutning_<fas>`: linjen bakre höft → främre höft mot vågrätt,
  grader, + = bakre höften lägre. Adress, topp, träff. Portat från Golf SG.
- Katalogens `matt` visar den vid P1, P4 och P7 (P4 och P7 sedan S1e), egen baslinje.
  Sportsbox Pelvis Side Bend har samma nollpunkt och tecken (mot vågrätt, + = bakre
  sidan lägre) men är bäckenet i 3D: tour −8° vid P4 och +8° vid P7 med båda klubborna
  (läst i original, research 5a). Vid toppen är bäckenet vridet ≈ 40°, så linjen i bild
  är förkortad; ingen gräns. Bäckenets lutning ↔ klubbfart r ≈ 0,5 (Han 2016, TWU,
  kunde inte läsas).

## M19 — Sway gap vid träffen (FO)

- `sway_gap_traff` = bäckenets sway − bröstets sway vid träffen, cm. **+ =
  bäckenet längre mot målet än bröstet** (bröstet bakom). Portat från Golf SG.
- **Sportsbox Sway Gap** (läst i original, research 5a) är det vågräta avståndet
  bröstets mitt − bäckenets mitt, **− = bröstet bakom**, och nollas inte vid adressen
  (tour −1,4 tum vid P1). M19 är ändringen från adressen med motsatt tecken:
  M19 = −(gap vid träff − gap vid adress). Det japanska exemplet går ihop: −6,9 +
  (−0,1 − 2,9) = −9,9 cm. Ur tabellens sway (samma definition som M15, M16): tour vid
  träff **+13,2 cm med driver, +8,9 cm med järn**.
- **Riktningen** (BESLUT B45): + är tour-hållet, så katalogens `sway_gap` har
  `samre: "-"` (mindre än den egna baslinjen är sämre). Ingen tour-gräns: den skiljer
  4–6 cm mellan driver och järn, och katalogen bär ingen klubba; den egna baslinjen
  med samma klubba gäller.

## M20 — Händerna vid träffen (FO)

- `hander_fore_adress_traff`: händernas X vid träffen minus i adressen, cm,
  + mot målet.
- `hander_fore_backen_traff`: händernas X minus höftmittens vid träffen, cm,
  + = händerna före bäckenet. Portade från Golf SG.

## M21 — Bäckenets resa framåt (FO)

- `backen_resa_framat` = bäckenets sway vid träffen − vid toppen, cm, + mot
  målet. Sway bakåt och för lite förskjutning framåt är samma tema, bäckenets
  väg (PLAN S1). Egen baslinje, sämre nedåt. **antagande.**
- Ur Sportsbox tabell (Pelvis Sway, samma definition som M15, läst i original,
  research 5a): resan från toppen till träffen är tour +13,0 cm med driver (4,5 −
  (−0,6) tum) och +12,2 cm med järn. Inte i research 5:s förslag till gränser; egen
  baslinje. GolfTEC:s 3,9 och 1,6 tum (topp, träff) mäts på svanskotan och jämförs
  inte. TPI (hanging back, läst i original): normalt "about four inches" närmare målet
  vid träff än vid adressen, utan att kroppsdelen anges.

## M22 — Främre armbågen vid toppen (FO)

- `framre_armbage_topp`: främre axel–armbåge–handled, **böjningen i grader,
  0 = rak arm**. Handleden är armens egen: greppregeln (M1) ersätter en dold
  handled med den andra, vilket duger för händernas läge men inte för en vinkel
  i armbågen. Är den främre handleden dold saknas måttet. För en högerspelare vänsterarmen. Framifrån ligger armen
  ungefär i bildens plan vid toppen; förkortningen gör vinkeln osäker, därför
  egen baslinje. GolfTEC: 76° mot 10° är en demonstratör, ingen elev och ingen
  norm (**tillverkare, läst i original**, research 5c §1b).

## M23 — Chicken wing (FO)

- `framre_armbage_efter_traff`: främre armbågens böjning (som M22, med den
  egna handleden) ur ledernas medel över **träffen +0,05…+0,15 s**. **antagande:** fönstret ligger efter
  bollen men före att armarna viker naturligt mot finishen; ett medel över
  fönstret tål enstaka suddiga rutor. HackMotion anger inga tal. Egen baslinje.

## M24 — Stansens bredd (FO)

- `stans_bredd` = avståndet mellan fotlederna / avståndet mellan axlarna, i
  adressen, utan enhet. Ingen norm som andel av axelbredden hittad; klubbfarten
  steg med stansens bredd hos 8 koreanska proffs (research 1 §1.11).
  **forskning, ej läst i original.** Visas som tal, inte som fel.

## M25 — Sessionen

- Per mått och vy: n, median, kvartilerna (linjär interpolation, som numpys
  standard), sd (n − 1), min, max, **trend** = Spearmans ρ mot svingens plats i
  passet (medelrang för lika värden), och **avvikare** = svingar mer än
  3 × 1,4826 × MAD från medianen (MAD = medianen av |x − medianen|; 1,4826 gör
  MAD till sd för normalfördelning). **standard** (Hampels regel).
- Minst **3** svingar för en sammanfattning. Severin m.fl. 2021 (University of
  Arkansas, 10 motionärer, järn 6 och driver; **forskning, läst i original**, research
  5b): 8 slag räcker för ett stabilt medel av rörelseomfång och toppfarter.
- Tempot sammanfattas också över båda vyerna ihop (`alla`).
- Portat från Golf SG (`sammanfatta`), med medelrang i stället för ordningsrang.

## M26 — Jämförelsen mot förra passet

- Per mått: skillnaden i median (nu − förra) och förra passets spridning som
  **robust sd = (q3 − q1) / 1,349**. **standard** (IQR för normalfördelning).
- **Tydlig** när |skillnaden| > spridningen. **antagande:** konservativt, en
  sving-till-sving-sd; medianens eget fel är mindre. Repeterbarheten är
  sämst mellan dagar (Griffith), så bara pass med kameran på samma plats
  jämförs (research 1 del 4).

## M27 — Katalogen: bedömningen

- Varje fel i `katalog.json` (BESLUT B6) pekar på ett mått i en vy, och passets
  median bedöms.
- **Med gräns:** inom `gront` = grönt; annars inom `gult` = gult, utanför =
  rött. Utan `gult` är allt utanför grönt gult (tempot). Gränserna är slutna.
- **Utan gräns (egen baslinje):** z = (passets median − baslinjens median) /
  baslinjens robusta sd (M26), där baslinjen är måttets värden ur tidigare pass
  i samma vy, med samma klubba och längd; ett pass med flera klubbor bedöms per klubba
  (BESLUT B56). Med `samre` = "+" räknas bara z uppåt som sämre, "−" bara nedåt,
  annars |z|. Upp till **1** = grönt, upp till **2** = gult, längre = rött.
  Baslinjen kräver minst **8** svingar (Severin 2021, M25). **antagande.**
- `kontrollerad: false` = källan i `kalla` är inte läst i original (BESLUT B10).
  Gränsen används ändå, märkt. Efter research 5 är alla lästa utom flying elbows
  (BESLUT B45). Ett fel med `aktiv: false` bedöms inte
  (axellutningen, M17).

## M28 — P-positionerna

- Golfens P-positioner som går att mäta ur kroppens leder (BESLUT B32): **P1
  Adress** = adressens fönster (M4; tiden för videon är fönstrets mitt, måtten
  är fönstrets medel), **P4 Topp** = toppen (M4), **P7 Träff** = klicket (M4),
  **P10 Finish** = finishens fönster (M4, tiden i mitten). P2, P6 och P8
  definieras av klubbskaftet: rutan som Johannes väljer när han markerar klubban (S7a,
  M45). **tränare** (P-systemet, 10 positioner), **antagande** (hur de mäts ur lederna).
- **Sportsbox positioner** (research 5a, läst i original): hjälpcentret listar ADR, BCH,
  TOP, DCH, IMP, FCH och FIN, och tour-tabellen P1–P8 och P10, alltså också BAH (P3) och
  DAH (P5). Utskrivningen av förkortningarna (BCH = backswing club horizontal, BAH =
  backswing arm horizontal, DAH = downswing arm horizontal, DCH = downswing club
  horizontal, FCH = follow-through club horizontal) är **antagande**: 5a ger bara
  förkortningarna och P-numren. TOP är där klubban byter riktning (FO), IMP sista bilden
  före träffen. SwingLabs P4 är händernas högsta punkt och P7 klicket (M4), inte
  Sportsbox; P3, P5 och P9 är armen vågrät i bild (nedan), och P2, P6 och P8 skaftet
  parallellt med marken, valt för ögat (M45).
- **Armen vågrät:** linjen axel → den **egna** handleden har vinkeln 0 mot
  vågrätt i bildens plan, åt vilket håll armen än pekar. Det mäts som
  **höjden** h = axelns y − handledens y (px, y nedåt, **+ = handleden över
  axeln**), och nollstället interpoleras linjärt på h mellan två rutor i följd
  där armen syns: uppåt när h0 < 0 ≤ h1, nedåt när h0 ≥ 0 > h1. Inte på
  vinkeln: atan böjer kurvan när armen är kort i bild (|Δx| litet, som
  bakifrån), och vinkeln gav där upp till 6,4 ms fel (granskningen, DTL P5).
  Lederna är de utjämnade (M3), och handleden är armens egen: greppregeln (M1)
  ersätter inte en dold handled, så en dold handled ger ingen position (som
  armbågarna, M22). Över en rå lucka längre än **0,10 s** räknas ingen passage
  (M3). Främre armen är vänsterarmen för en högerspelare, och en vänsterspelare
  speglas (M1).
  - **P3:** främre armen, den **sista** passagen uppåt från adressens slut, där
    rutparet får gå över toppen (första rutan senast vid toppen).
  - **P5:** främre armen, den **första** passagen nedåt till träffen, där
    rutparet får gå över toppen (andra rutan tidigast vid toppen).
  - **P9:** bakre armen, den **första** passagen uppåt från träffen till
    finishens fönster (träffen + **1,0 s**).
- **Rutparet över toppen** (valt framför "P5 bara om P3 finns"): armen och
  händerna når inte sin högsta punkt samtidigt, så armen kan passera vågrätt
  mellan rutan före och rutan efter toppen. Utan regeln tappas den passagen
  helt: ett par uppåt gav varken P3 eller P5 (armen syns redan under vågrätt
  efter toppen), och ett par nedåt tappade P5. Med regeln hör ett par uppåt till
  P3 och ett nedåt till P5, så P3 kan ligga upp till en ruta efter toppen och P5
  upp till en ruta före. Det är sant om armen; ordningen P3 < P4 < P5 gäller
  därför inom en ruta. **antagande.**
- **Ingen passage gissas över en lucka:** P3 saknas om armen syns under
  vågrätt i någon ruta mellan P3 och toppen, P5 om den syns under vågrätt
  mellan toppen och P5, och P9 om bakre armen syns vid eller över vågrätt
  mellan träffen och P9. Då gick armen över vågrätt i en lucka längre än
  0,10 s, och den synliga passagen är inte den rätta. Blir armen aldrig
  vågrät **saknas positionen**, och måtten vid den (M29). **antagande**
  (P-systemets "armen parallell med marken", mätt i bildens plan).
- **Vyn:** samma definition i båda vyerna. Framifrån (FO) ligger armen nära
  bildens plan i P3, P5 och P9, bakifrån (DTL) är den förkortad. **FO har
  företräde** för positionstiderna när båda telefonerna filmar samma sving; DTL:s
  egna tider används bara när FO saknas, och märks då ungefärliga (BESLUT B32,
  ledarens beslut 2026-10-22). Parningen slag för slag väntar (MT9).
  **antagande.**
- **Uppmätt på påhittade svingar** (frön 0–79 per vy, mot figurens exakta tid):
  ingen bias (|medel| ≤ 0,6 ms). Utan brus och med 0,8 px brus sd 1,2–1,9 ms och
  största felet 3,0–4,8 ms, alltså oftast inom en ruta (4,2 ms vid 240
  bilder/s); med 2 px brus sd 1,4–3,8 ms och största 3,6–9,7 ms. Felet kommer
  från luckorna, som gör utjämningens vikter osymmetriska (M3). Provat:
  `fo_lucka_arm` (handleden borta med rå lucka 0,096 s kring P3: interpoleras;
  0,104 s kring P5: P5 saknas).

## M29 — Måtten vid positionerna

- Ett mått vid en position är måttet räknat vid positionens tid (värdet i
  ögonblicket, M3), eller över fönstret för P1 och P10 (M4). De som redan är en
  fas behåller sina namn (`_adress` = P1, `_topp` = P4, `_traff` = P7,
  `_finish` = P10). Nya, alla FO och alla med egen baslinje (**antagande**):
- `backen_sway_p3`: bäckenets sway (M15) vid P3, cm, + mot målet: "sway
  hittills". Hör till felet `sway_topp` (accenten följer, BESLUT B31).
- `framre_armbage_p3`: främre armbågens böjning (M22) vid P3, grader, **0 =
  rak arm**: vänsterarmen för en högerspelare. Vänsterarmen visas som böjning
  med 0 = rak, vid P3 och P4, inte som skissens inre vinkel (ledarens beslut
  2026-10-22).
- `backen_resa_p5`: bäckenets X vid P5 − vid toppen, cm, + mot målet: "resa
  framåt hittills" (M21 räknat till P5 i stället för träffen). Hör till felet
  `backens_resa_framat`.
- `huvud_backen_finish`: näsans X − höftmittens X i finishens fönster, cm, + =
  huvudet mot målet om bäckenet. Ett läge, ingen förflyttning: framifrån står
  huvudet i adressen ungefär över bäckenet. Ingen källa med samma definition.
- **Kopplingen mått → position** står i `katalog.json` (BESLUT B32,
  docs/FORMAT.md): varje fel har `positioner`, och listan `matt` bär måtten som
  granskningen visar utan att de är fel, med `fel` när måttet hör till ett fel
  (så att accenten följer med). Kopplingen följer skissen (`design/skiss.html`,
  `PM`), med två undantag och ett tillägg:
  - **Resan** visas vid P5, som måttet hittills; felet `backens_resa_framat`
    (resan till träffen) har därför ingen egen position (`[]`), som tempot.
  - **Tappad hållning** (`brost_bojning_tapp`, adressen − träffen) visas vid P7,
    där felet syns. Skissen har den inte; det är en avvikelse mot skissen.
  - **Chicken wing** (M23) visas vid P9 men räknas fortfarande över träffen
    +0,05…+0,15 s, inte i P9:s ögonblick, och vyn märker det "efter träffen"
    (felets `fas: efter_traff`) tills P8 kommer med S7 (ledarens beslut
    2026-10-22).
  - Bäckenets vridning och höfterna öppna (skissens "2 kameror") kommer med S6.
- Uppmätt på påhittade svingar: inom 0,05 cm och 0,05° från figurens tal.

## Tilläggen mot Sportsbox i 2D (S1b)

Mått som går att räkna ur dagens leder i en vy, ur jämförelsen med Sportsbox AI
(`docs/research/4_sportsbox_matt.md`, PLAN S1b). **Definitionerna är våra.**
Sportsbox definitioner och tecken är lästa i original (research 5a): de linjära
måtten (sway, lift, thrust) nollas vid adressen, vinklarna gör det inte (turn mot
linjen genom fotlederna, bend mot lodlinjen, side bend mot vågrätt), och allt är 3D ur
en egen modell. Talen här jämförs bara pass mot pass. Alla har
egen baslinje (M27) och står i katalogens `matt` (BESLUT B32), två av dem med
`fel` så att accenten följer felet. Farterna (M35–M37) bär `status: "oprovad"`
i katalogen och märks så i granskningen. Python och Swift ger samma tal (BESLUT B12).
Uppmätt på påhittade svingar utan brus (frön 0–19 per vy) mot figurens exakta
tal; med 0,8 px brus står spridningen per rad.

## M30 — Höftfällningen, skattad (DTL)

- `backen_bojning_<fas>` (visas som "Hip hinge (est.)"): **medlet av bålens och
  lårets lutning** mot lodlinjen i bild, grader, **+ framåt mot bollen**. Bålen
  är höftmitt → axelmitt (M6), låret bakre knä → bakre höft (bakre benet ligger
  närmast kameran, M11). Adress, topp, träff (P1, P4, P7).
- **Sportsbox har ingen Pelvis Bend** (research 5a: varken som tracker eller i
  tour-tabellen; research 4 §1 hade fel). Bäckenets lutning kräver en punkt
  på bäckenet utöver höftleden (korsbenet eller höftbenskammen), och den finns
  inte bland de 13 lederna: höftlederna syns som en punkt bakifrån och bär ingen
  lutning, och bålen ensam är bröstets böjning (M6). Medlet av bålens och lårets
  riktning uppåt är **normalen till höftvinkelns bisektris** (vinkeln mellan
  bålen och låret nedåt), alltså en skattning som antar höftvinkeln delad lika
  mellan höftleden och ryggen. **antagande.** Står spelaren rak är måttet 0;
  fäller hon bara i höften med rak rygg blir det halva bålens vinkel. Visas som
  ett tal pass mot pass, inte som ett fel.
- **Visar inte early extension** (granskningen 2026-10-22, påhittade svingar):
  en bra sving som håller vinkeln gav −3,5° från adressen till träffen, en sving
  med early extension (bäckenet 6 cm mot bollen, bålen reser sig 8°, bakre knät
  sträcks 20°) +1,1°, och bara bålen som reser sig −6,5°: bålen och låret drar åt
  var sitt håll. Därför inget `fel` i katalogen; early extension är bäckenets
  thrust (M7).
- Saknas bakre knät saknas måttet; bröstets böjning finns kvar.
- Uppmätt: inom 0,001°; med 0,8 px brus sd 0,03–0,09°, största 0,26°.

## M31 — Bröstets lyft (båda vyerna)

- `brost_lyft_<fas>`: axelmittens förflyttning från adressen i höjdled, cm,
  **+ uppåt**, som M8. Topp, träff, finish (P4, P7, P10; katalogen visar topp
  och träff). Höjdled ligger i bildens plan i båda vyerna. Sportsbox Chest Lift har
  samma nollpunkt och tecken (läst i original, research 5a): tour −2,0 cm vid toppen,
  −2,8/−1,5 cm vid träffen (driver/järn), lägst vid P5. Bakifrån hör
  `brost_lyft_traff` till felet `tappad_hallning`.
- Uppmätt: inom 0,002 cm; med 0,8 px brus sd 0,07 cm, största 0,17.

## M32 — Handens lyft (båda vyerna)

- `hand_lyft_<fas>`: greppets (händernas medel efter greppregeln, M1)
  förflyttning från adressen i höjdled, cm, **+ uppåt**. Topp, träff, finish
  (P4, P7, P10; katalogen visar topp och träff). Sportsbox: Mid-Hand Lift.
- Uppmätt: vid träffen och i finishen inom 0,013 cm; **vid toppen −0,06 cm
  i snitt, största 0,18**: toppen är händernas högsta punkt, och utjämningen
  sänker en topp och toppens tid ligger ≈ 9 ms tidigt (M4). Med 0,8 px brus
  sd 0,07 cm.

## M33 — Främre knäets böjning (DTL)

- `framre_kna_<fas>`: främre höft–knä–fotled, böjningen i grader, **0 = rakt
  ben**, som M11. Adress, topp, träff (P1, P4, P7). Sportsbox: Lead Knee
  Flexion, som finns (läst i original, research 5a) men räknar 180° = rakt led, inte
  0. Knäets sträckning mot träffen är det intressanta.
- **Vyn:** böjningen ligger i bildens plan bakifrån, inte framifrån (där sker
  den i djupled och syns knappt). Bakifrån står främre benet bakom det bakre
  och skyms delvis. Måttet tas ändå i DTL: en skymd led får låg konfidens och
  räknas då som saknad (M1, 0,3), så måttet saknas hellre än mäts fel; det
  provas i `tools/tests/test_farter.py` (främre knät med konfidens 0,2). Hur
  ofta Vision tappar det bakifrån mäts i S3. **antagande.**
- Uppmätt: inom 0,003°; med 0,8 px brus sd 0,25–0,35°, största 0,71°
  (kortare lår och smalare vinkel bakifrån än bakre benet i figuren).

## M34 — Knänas sway (FO)

- `framre_kna_sway_<fas>`, `bakre_kna_sway_<fas>`: knäets förflyttning från
  adressen längs X, cm, **+ mot målet**, som M15. Topp, träff, finish (P4, P7,
  P10; katalogen visar topp och träff). Sportsbox: Lead/Trail Knee Sway, som finns
  med samma tecken (läst i original, research 5a); bland de svagast belagda (research
  5 §6).
  `bakre_kna_sway_topp` (bakre knät glider bort från målet i baksvingen) hör
  till felet `sway_topp`.
- Uppmätt: exakt (figurens knän står still på platåerna); med 0,8 px brus sd
  0,10–0,14 cm, största 0,34.

## M35 — Handens fart och när den är störst (FO)

- `handfart_max`: greppets **största fart i nedsvingen** (toppen → träffen),
  **m/s med en decimal**, i bildens plan. `handfart_max_fore_traff_ms`: hur långt
  **före träffen** den största farten kommer, ms, + = före. Sportsbox: Max Hand
  Speed och Hand Speed Max Timing finns (läst i original, research 5a): farten är
  mittpunkten mellan händerna på skaftet, resultant i 3D, och tour med driver har
  handens maxfart 69 ms före träffen. Framifrån,
  där handens båge i nedsvingen ligger närmast bildens plan; djupled (mot
  bollen) syns inte, så farten är en undre gräns för den verkliga.
- **Utjämningen:** farten räknas på ett **rutnät i tiden, 1 ms**, inte i
  rutorna. I varje punkt τ är hastigheten lutningen i en **viktad linjär
  anpassning** över tiden till de **råa** lägena inom **3σ = 22,5 ms** från τ,
  med samma gaussvikt som M3 (σ = 7,5 ms). Punkten räknas bara när minst **två**
  rutor med värde finns före τ och två efter: med en enda ruta på ena sidan
  styr den lutningen med hela sitt brus (granskningen: ±100 °/s vid en lucka).
  Varför inte en differens av de utjämnade lägena: luckorna gör utjämningens
  vikter osymmetriska, så läget förskjuts upp till 4 ms gånger farten (M3),
  olika i varje ruta, och en differens förstorar det: upp till 40 % fel
  (uppmätt). Anpassningen är väntevärdesriktig för en jämn rörelse hur luckorna
  än ligger (provat inom 10⁻⁹). **antagande** (σ från M3).
- **Greppet:** medlet av de två handledernas hastigheter, var och en anpassad
  på sin egen råa serie, och **båda krävs**. Inte greppregelns punkt (M1): den
  hoppar 1–2 cm när en handled försvinner, och hoppet blir en falsk fart. Saknas
  den främre handleden kring toppfarten saknas måttet.
- **Toppen:** största värdet på rutnätet, förfinat med parabeln genom punkten
  och dess två grannar (tiden som M4, värdet ur samma parabel). **Toppen
  saknas** (gissas aldrig) när den ligger i rutnätets ände (träffen kom innan
  farten vände, eller farten sjönk redan från toppen: inte "0 ms"), och när en
  lucka i rutnätet längre än **20 ms** når in inom **20 ms** från toppen: då kan
  den verkliga toppen ligga i luckan, och talet blev upp till 14 % fel
  (granskningen). Luckan räknas med hela sin längd. **antagande.** På påhittade
  svingar med 36 % saknade rutor (som i oktober) saknas toppen i 2 av 20 frön av
  det skälet (en rå lucka på ≈ 33 ms vid toppen); fixturen `fo_lucka_fart`
  (händerna borta 80 ms över toppen) ger inget tal, och `fo_nara_traff`
  (träffen 15 ms efter toppfarten) ger ≈ 17 ms.
- **Osäkert (BESLUT B11):** farten kräver skarp bild, alltså inspelning i
  appen med låst slutartid; Kamera-appens slowmotion suddar händerna i
  nedsvingen. **Oprovat på telefonen**; katalogen märker måtten `oprovad`.
  Bruset drar toppen uppåt (största värdet av brusiga punkter).
- Uppmätt utan brus (frön 0–19): −0,6 % i snitt (anpassningen rundar toppen),
  största 0,06 m/s på ≈ 7,2; tiden sd 3 ms, största 6 ms, eftersom toppen är
  flack. Med 0,8 px brus: +0,2 %, sd 0,06 m/s; tiden sd 7 ms, största 18 ms. Med
  2 px: +2 %, tiden sd 10 ms. Den påhittade svingen står still vid träffen
  (±0,04 s, `generera.py`), så dess toppfart ligger ≈ 175 ms före träffen; i en
  verklig sving ligger den närmare.

## M36 — Genomsvingens tid (båda vyerna)

- `genomsving_s` = finishen − träffen, s. Sportsbox: Follow Through Time finns
  (läst i original, research 5a), utan tour-tal. Inget samband med utfallet hittat:
  det svagast belagda av dagens mått (research 5 §6).
- **Finishen i tid:** första gången efter genomsvingens toppfart som handens
  fart faller under **10 %** av den, linjärt mellan två punkter på rutnätet.
  Toppfarten söks från träffen (uteslutet) till finishens fönster, **träffen
  + 1,0 s** (M4). Farten som i M35, men i bildens plan i båda vyerna, och där
  bara den ena handleden går att räkna gäller den (bakifrån skyms den främre
  ofta): bara kvoten mot den egna toppen används, så skalan och den yttre
  handledens ≈ 3 % högre fart spelar ingen roll. Faller
  farten aldrig under (händerna rör sig ännu efter 1,0 s), eller ligger två
  punkter med fart mer än 0,10 s isär (M3), saknas måttet. **antagande:**
  10 % skiljer en hållen finish från rörelsen dit; ett lågt värde i en
  riktningsändring framifrån (händerna rör sig mot kameran) kan ge en för
  tidig finish.
- **Osäkert:** som M35 kräver farten skarp bild (B11), oprovat på telefonen.
- Uppmätt: inom 3 ms; med 0,8 px brus sd 7 ms, största 18 ms; med 2 px sd 18 ms.

## M37 — Främre armens vinkelfart (FO)

- `framre_arm_vinkelfart_max`: linjen främre axel → **den egna** främre
  handleden (som M22 och M28; greppregeln ersätter inte), **största
  vinkelfarten i nedsvingen** (toppen → träffen), grader/s, som belopp, i
  bildens plan. Vänsterarmen för en högerspelare. Sportsbox: armens största vridfart
  finns (läst i original, research 5a: överarmen 1 005 °/s med driver, i 3D), inte
  jämförbar med vinkeln i bild.
- **Utjämningen och toppen:** som M35, på vinkeln atan2(dy, dx) ur de råa lägena; varje
  rutas vinkel räknas mot den första rutan i fönstret och läggs i (−180°,
  180°], så att ett varv förbi ±180° inte blir ett hopp (provat: 600 °/s genom
  180° ger 600). Toppen som M35.
- **Osäkert:** skarp bild krävs (B11), oprovat på telefonen; en dold handled
  i nedsvingen tar bort punkterna där (fixturen `fo_lucka_arm` tappar toppen).
- Uppmätt utan brus: −0,3 %, största 3 °/s på ≈ 700; med 0,8 px brus
  +1,3 %, största 27 °/s; med 2 px +5 %. Märkt `oprovad` i katalogen.

## Tilläggen bakifrån (S1c)

Johannes beställning 2026-10-23: fler mått bakifrån (DTL) ur dagens leder i 2D
(PLAN S1c). **Definitionerna är våra**, med egen baslinje (M27), i katalogens
`matt` vid P4 utan `fel`, i Python och Swift med samma tal (BESLUT B12). Sportsbox
Hand Thrust (DTL, 0 vid adressen, + mot bollen, läst i original, research 5a) har
samma tecken som händernas djup (M38) men inget tour-tal; för armen mot axellinjen
(M39) finns ingen Sportsbox-definition.

- **Huvudet bakifrån fanns redan** och byggdes inte om: rörelsen mot och från
  bollen är `huvud_mot_bollen_<fas>` (M9) och upp och ned `huvud_lyft_<fas>` (M8,
  båda vyerna), näsan som punkt och vyns skala (M2), adressen = 0, vid toppen och
  träffen (P4, P7) och i finishen. De står inte i katalogens `matt` och syns därför
  inte i granskningen.

## M38 — Händernas djup vid toppen (DTL)

- `hand_djup_topp`: greppets (händernas medel efter greppregeln, M1, som M32)
  förflyttning längs X från adressen till toppen, cm, **+ mot bollen** (bort från
  kroppen), − in mot och bakom kroppen. X bakifrån är djupled mot bollen (M1), samma
  axel som bäckenets thrust (M7). Måttet är händernas egen väg, inte händerna mot
  bröstet: bröstets egen rörelse är `brost_thrust_topp` (M10). Sportsbox Hand Thrust
  (greppets mittpunkt, 0 vid adressen, + mot bollen) finns, utan tour-tal (läst i
  original, research 5a). **antagande.**
- Uppmätt (frön 0–19, utan brus): +0,02 cm i snitt, största 0,06 (toppen ligger
  ≈ 9 ms tidigt, M4, men händerna står still i X där); med 0,8 px brus sd 0,08 cm,
  största 0,22; med 2 px sd 0,21 cm.

## M39 — Främre armen mot axellinjen vid toppen (DTL)

- `framre_arm_plan_topp`: vinkeln i bild från axellinjen (främre axel → bakre axel)
  till främre armen (främre axel → **den egna** främre handleden, som M22 och M37;
  greppregeln ersätter inte), grader, **+ = armen över axelplanet** (brantare uppåt
  än axellinjen), − under (flatare). Räknas med kryss- och skalärprodukten, i
  (−180°, 180°]. Vänsterarmen för en högerspelare; en vänsterspelare speglas (M1).
  **antagande** (ingen källa med samma definition).
- **Varför bara vid toppen:** bakifrån ligger axellinjen i adressen och vid träffen
  i djupled (axlarna skymmer varandra i bild). Vid toppen har axlarna vridit sig
  ≈ 90°, bröstet vetter mot kameran och axellinjen ligger nära bildens plan. Med
  mindre vridning blir linjen förkortad och brantare i bild: med 35° axellutning
  ger 70° vridning ≈ 1,7° brantare linje, 45° vridning ≈ 9,7° (projektionen
  atan(tan τ / sin θ)); armen förkortas på liknande sätt. Talet jämförs därför bäst
  pass mot pass.
- **Axlarna skymmer varandra:** är axellinjen vid toppen kortare än **15 cm** i bild
  (vyns skala, M2) saknas måttet. Uppmätt på påhittade svingar med 0,8 px brus:
  med axlarna 3 cm isär (som i adressen) sd 2,3°, största 3,8°; 15–16 cm sd 0,4°,
  största 0,7°; 39 cm (en full vridning i figuren) sd 0,17°, största 0,36°. Gränsen
  är ett **antagande**: under den är riktningen mer brus än axellinje. Saknas en axel
  eller den främre handleden vid toppen saknas måttet.
- Uppmätt utan brus (frön 0–19, axellinjen 39 cm): −0,03° i snitt, största 0,10°
  (utjämningen sänker handleden i toppen, som M32); med 2 px brus sd 0,42°, största
  0,96°.

## Tilläggen ur research 5 (S1e)

Research 5 läste källorna i original (`docs/research/5_matt_i_original.md`) och
rangordnade mått att ta in (§5). De billiga, ur dagens leder i en vy, i Python och
Swift med samma tal (BESLUT B12, inom 10⁻⁶), i katalogens `matt` med positioner och
utan `fel` (egen baslinje, M27; ingen av dem har en gräns med en källa som stämmer):

| # (§5) | Mått | Var |
|---|---|---|
| 1 | Spridningen mellan slagen, först bröstets böjning | M44 |
| 2 | Recentreringen | M41 |
| 3 | Skiftets tidpunkt | M42 |
| 4 | Bäckenets lägsta punkt och lyftet in i träffen | M43 |
| 5 | Bröstets bakåtlutning i finishen (`sidbojning_finish`, fanns) | M14 |
| 6 | Nedsvingens tid (`nedsving_s`, fanns) | M5 |
| 7 | Höftlinjen vid topp och träff (`hoftlinje_lutning_topp`, `_traff`, fanns) | M18 |

Inget av dem kräver en ändring i faserna (M4): M41–M43 använder toppen, adressens
fönster och träffen som de är.

## M41 — Bäckenets recentrering (FO)

- `backen_recentrering`: bäckenets sway (M15) vid toppen minus dess **minsta** i
  baksvingen, cm, **≥ 0, + = tillbaka mot målet** före toppen. Fönstret är adressens
  slut (M4) → toppen: värdet i ögonblicket vid båda ändarna (M3) och de utjämnade
  rutorna mellan dem. Visas vid P4 ("Hip recentering").
- **Källan:** Sportsbox Recentering (läst i original, research 5a §A): bäckenets
  största sway i baksvingen (P2–P3) minus dess sway vid toppen, där under 1 tum är "för
  lite eller för sent"; proffs svajar 1–3 tum bakåt och recentrerar mellan P2 och P3.
  Låghandicappare börjar flytta tillbaka före toppen (golf.com, läst i original). Ur
  tour-tabellen: −4,1 cm vid P3 till −1,5 cm vid P4 med driver (2,5 cm), −2,0 till 0,0
  med järn (2,0 cm).
  Samma storlek som Sportsbox, med tecknet vänt så att + är mot målet; vårt fönster är
  hela baksvingen, inte bara P2–P3 (P2 kräver klubban, S7). Ingen gräns: Sportsbox
  "under 1 tum" är en indikator utan tal per nivå. **antagande.**
- **Saknas** när bäckenet saknas vid en ände, eller när två tider i följd i fönstret
  ligger mer än **0,10 s** isär (M3): den minsta punkten kan ligga i luckan.
- **Uppmätt** (frön 0–19, figuren glider 3 cm extra bort mitt i baksvingen): utan brus
  −0,002 cm i snitt, största 0,004; med 0,8 px brus +0,07 cm, sd 0,07, största 0,25; med
  2 px +0,24 cm, sd 0,16; med 3 px +0,41 cm, sd 0,22, största 0,96; med 5 px +0,68 cm,
  sd 0,37, största 1,6. Bruset drar talet uppåt: det minsta av brusiga punkter. Ett tal
  under ≈ 0,5 cm skiljer sig inte från noll (research 5 §1.8: ≈ 2 cm i sway).

## M42 — Skiftets tidpunkt (FO)

- `backen_skifte_ms`: tiden från toppen tills höftmitten är **tillbaka i sitt
  adressläge** längs X på väg mot målet, ms, linjärt mellan två värden i följd i
  fönstret toppen → träffen (värdena som M41). **0** när bäckenet redan står i eller
  framför adressläget vid toppen; **saknas** när det inte kommer tillbaka före
  träffen, och vid en lucka som i M41. Visas vid P5 ("Hip shift timing"); i
  granskningen står "—" för ett sådant slag.
- **Censurerat:** ett slag där bäckenet inte är tillbaka före träffen har ett skifte
  som är längre än nedsvingen, inte inget skifte. Passets median (M25) räknas bara
  över slagen med ett tal, så PC:ns analys skriver antalet censurerade bredvid
  (`skifte_ej_tillbaka`: FO-slag där bäckenet står bakom adressläget vid träffen, och
  antalet mätta FO-slag, docs/FORMAT.md). Det enklaste ärliga: talet döljs inte, och
  medianen tolkas med antalet. Telefonens pass visar inte skiftet (bara granskningen).
- **Källan:** tidpunkten skiljer nivåerna, inte läget. Okuda 2010 (13 skickliga mot 17,
  läst i original): de skickliga flyttade vikten till främre foten tidigare i
  nedsvingen. Smith/Mears 2017 (22 låghandicappare): tre PCA-komponenter av
  tryckcentrums och tyngdpunktens mönster förklarade **tillsammans** 74 % av klubbfarten
  (justerat r² 0,742), starkast tryckcentrums tidpunkt och takt i sidled kring
  nedsvingens början. **Tidig förflyttning av tyngdpunkten mot främre foten i sen
  baksving var negativ**: tidigt är inte alltid bättre. Status: research 5b läste
  artikeln i original via Loughboroughs arkiv, men §7 i sammanfattningen listar
  "Smith/Mears 2017 (COG/COP)" som ej läst och 5d som 403; komponenternas r-värden
  och vikter är inte kontrollerade, bara totalen och tecknen. Jones 2023 (104
  amatörer, bara abstract): ett snabbt skifte framåt hörde ihop med lägre handicap.
  Källorna mäter tryckcentrum och tyngdpunkt (kraftplattor, markörer), inte höftmitten;
  vårt mått är en proxy. Ingen norm i ms. **antagande.**
- **Uppmätt** (frön 0–19): passagen själv ligger inom 4 ms från figurens (sd 2 ms);
  talet blir ≈ **9 ms för långt** (utan brus sd 2 ms, största 13; med 0,8 px brus
  +10 ms, sd 6, största 26), eftersom toppen ligger ≈ 9 ms tidigt (M4). Jämförs pass mot
  pass, där biasen är densamma.

## M43 — Bäckenets lägsta punkt och lyftet in i träffen (båda vyerna)

- `backen_lyft_min`: höftmittens **lägsta höjd** mellan toppen och träffen, från
  adressen, cm, **+ upp, − ned** (M8). `backen_lyft_in_traff` = lyftet vid träffen
  (`backen_lyft_traff`) − den lägsta punkten, cm, ≥ 0. Fönstret och luckan som M41.
  Höjdled ligger i bildens plan i båda vyerna. Visas vid P5 och P7 ("Hip low point",
  "Hip rise into impact").
- **Källan:** Sportsbox Pelvis Lift (samma nollpunkt och tecken, läst i original,
  research 5a): tour −4,3 cm vid toppen (driver), lägst vid P4–P5 (−4,3/−3,8 cm), +2,3
  cm vid träffen. Indikatorn "Pelvis Lift at IMP" mäter lyftet från lägsta punkten i
  nedsvingen ("max drop") till träffen, som `backen_lyft_in_traff`, men bara i 3D Pro
  och utan publicerat tal per nivå. Tour-kurvan ger ≈ 6,6 cm (driver) och ≈ 5,8 cm
  (järn) i lyft in i träffen, räknat ur tabellen; ingen gräns: en kurva av medel är
  ingen norm, och klubban skiljer. **tillverkare** (kurvan), **antagande** (måttet).
- **Uppmätt** (frön 0–19, figuren sjunker 3–4 cm extra mitt i nedsvingen): utan brus
  +0,03 cm i snitt (utjämningen höjer en dal), största 0,09; med 0,8 px brus sd 0,07–0,12
  cm, största 0,21; med 2 px sd 0,15–0,28 cm; med 3 px drar bruset den lägsta punkten
  −0,12 cm (sd 0,22–0,28) och lyftet in i träffen +0,19 cm (sd 0,36–0,41); med 5 px
  −0,29 och +0,40 cm (sd 0,34–0,67), största 1,3 cm. Bruset drar den lägsta punkten
  nedåt och lyftet uppåt (det minsta av brusiga punkter).

## M44 — Spridningen mellan slagen

- **Ett tal per pass och mått:** den robusta sd:n **(q3 − q1)/1,349** ur passets
  svingar i vyn (kvartilerna som M25, skalan som M26), i måttets enhet. **Under åtta
  slag inget tal** ("—"): IQR/1,349 är skev när n är litet (≈ 0,63σ vid 3 slag och
  0,84σ vid 8 för normalfördelade värden), och 8 slag räcker för ett stabilt medel
  (Severin 2021, som baslinjen i M27). Talet `n` är det verkliga antalet slag med
  måttet, också vid 1–2. Vid 8 slag är talet alltså fortfarande ≈ 16 % lågt; det
  jämförs pass mot pass, med ungefär samma antal slag.
- **Klubban:** på PC:n räknas spridningen per klubba när passets serier har olika
  klubbor (`analys.json`, `spridning[].klubba`); klubban ändrar svingen. Telefonens
  pass har en klubba. Måtten står i katalogens lista `spridning` (docs/FORMAT.md):
  först bröstets böjning bakifrån i adressen och vid träffen (`brost_bojning_adress`,
  `brost_bojning_traff`, M6).
- **Källan:** Yamamoto 2023 (Front Sports Act Living, PMC10684732; 27
  universitetsgolfare, 20 slag var, 2D-pose ur en kamera bakifrån; **forskning, läst i
  original** enligt research 5d, medan 5b:s tabell C listar samma artikel som bara
  abstract): sd mellan slagen i framåtlutningen mot snittscore r = 0,80, mot precision
  r = 0,61; medelvinkeln r = −0,18. Det enda markörlösa 2D-fyndet med utfall. Studien
  mätte linjen öra–höft; SwingLab läser inte öronen (M1) och tar höftmitt → axelmitt
  (M6). Studiens egen posevalidering saknas, och vissa konfidensintervall i artikeln går
  inte ihop med r-värdena (5d), så r = 0,80 är osäkert. Ingen norm.
- **Robust sd, inte sd:** en felmärkt sving (Vision) drar sd med n − 1 långt; IQR tål
  den. Yamamoto räknade sd, så talen jämförs inte med studiens.
- **Visningen** (BESLUT B46): ett kort i passet ("Spine angle spread", vyns rubrik och
  måttets fas) och ett mått i Progress, med samma kort och diagram som felen: talet,
  förra passets spridning som streck och de tidigare passens spridning som egen
  baslinje (M27 på ett tal per pass: medianen ± en robust sd, minst åtta pass med ett
  tal). Inte på Today. PC:n skriver den i `analys.json` (`spridning`).
- Python och Swift ger samma tal (påhittade pass, `session_fixtur`). **antagande**
  (valet av mått och skalan).

## Klubban ur handmarkerade punkter (S7a)

Johannes markerar klubban för hand i granskningen (PLAN S7a, BESLUT B47): på en ruta per
P-position trycker han på **greppet** (skaftet mitt mellan händerna) och **hoseln** (där
skaftet går in i huvudet, GolfPose punkt, BESLUT B44). Markeringarna är träningsdata för
S7:s detektor och ger klubbmåtten direkt. Måtten räknas per markerad sving i Python
(`tools/pc/klubba.py`) och Swift (`Swing/Klubba.swift`) med samma tal (BESLUT B12, inom
10⁻⁶, `KlubbFixturer.swift`). Punkterna står i hela bildens pixlar och x speglas som
lederna (M1), så att +X pekar mot bollen (DTL) eller målet (FO); vinklarna räknas med y
uppåt. Passet visar medianen och n över de markerade svingarna (även en eller två), som
egen baslinje (M27) och utan fel: med få svingar är det en trend, inte en sak att öva.

## M45 — Klubbans rutor: P1–P10 och märkningen

- **P1, P3, P4, P5, P7, P9 och P10** föreslås där kroppen ger dem (M28): rutan närmast
  positionens tid. **P2, P6 och P8** definieras av skaftet parallellt med marken
  (P-systemet, **tränare**; Sportsbox BCH, DCH och FCH, research 5a, se M28), och det syns
  olika i vyerna:
  - **Bakifrån (DTL)** pekar ett skaft parallellt med marken och mållinjen mot kameran,
    alltså mot flyktpunkten (M48), och är då **kortast i bild**. Rutan är den där skaftet är
    kortast och pekar mot flyktpunkten. **räkning** (perspektivet), **antagande** (att
    skaftet är parallellt med mållinjen där det är parallellt med marken).
  - **Framifrån (FO)** syns "parallellt med marken" direkt: skaftet vågrätt i bild (vinkeln
    180° vid P2 och P6, 0° vid P8, M46). Mållinjen ligger i bildens plan, så uppställningen
    flyttar vinkeln vid ett parallellt skaft högst 1,1° (M49): under en ruta i nedsvingen.
  - **Med två parade telefoner** (S2g) tas tiden ur FO-serien, där parallellt syns, och
    DTL:s ruta är den närmast samma tid. `ClubPairTime` (SwingLabKit) kräver att parningen
    är DTL mot FO (den styrandes vy i `par.json` och följarens; inget par vid `osaker`), tar
    klickparet ur `par.json`:s parning (`pair`: den styrandes klick är `a`, följarens `b`) och
    klicken med de indexen ur var sin telefons klick, och för FO-markeringens tid över med
    träffens förskjutning (`dtlTimes`): DTL:s filtid = FO:s filtid ∓ `traff_forskjutning_s`
    (minus när DTL styr, plus när FO styr), relativt DTL:s klick. Ljudets olika väg till telefonerna (MS6) flyttar alltså inte
    tiden: med FO 1 m längre bort är DTL:s tid FO:s + 1/343 s, vem som än styr (provat i
    `KlubbaMarkeringTests`). **räkning** (parningen, MS9–MS10). `ClubMarking` föreslår den
    tiden bakifrån när den finns, annars kroppens. **Inte inkopplat:** FO-telefonens markeringar finns inte på
    DTL-telefonen (BESLUT B57), och PC:n märker inga P-positioner, så förslaget prövas bara i
    Swift.
- **Förslaget:** P2 mitt mellan P1 och P3 (annars P4), P6 mitt mellan P5 (annars P4) och P7,
  P8 mitt mellan P7 och P9 (annars P10) (`klubba.forslag_tid`, `Klubba.forslagTid`). Bara
  positionerna, inte baksvingens start, så att telefonen och PC:n föreslår samma ruta också
  för slag mätta före S7a. Johannes stegar därifrån; rutan han markerar blir P2, P6 eller P8
  för den svingen (`positioner` i analysen och slagets mått). **antagande** (mittpunkten
  är bara en start).
- **Ordningen** (BESLUT B58): kroppens positioner först och skaftets sist, P1, P3, P4, P5,
  P7, P9, P10, P2, P6, P8, i båda vyerna (`ClubMarking.order`), så att ändarna är markerade
  när P2, P6 och P8 märks.
- **Förslaget ur skaftet framifrån** (BESLUT B57): när positionerna före och efter är
  markerade (P1 och P3 för P2, P5 och P7 för P6, P7 och P9 för P8) föreslås rutan där
  skaftets vinkel (M46, speglad, M1), linjärt i tiden mellan dem, går genom vågrätt
  (`klubba.forslag_tid_skaft`, `Klubba.forslagTidSkaft`, samma tal inom 1e-9). **P2 räknas
  från baksvingens start** (M4, sparad som `ShotMeasure.start`) när den ligger efter P1:
  P1 är adressfönstrets mitt, cirka 0,25 s före starten, och skaftet står still däremellan;
  från P1 hamnade förslaget cirka 0,1 s för tidigt på de påhittade svingarna (fo: 1,544 mot
  1,638 s). Slag mätta före S7a-FO har ingen start, och då räknas från P1. Vinkeln går åt
  svingens håll i den speglade bilden, så att varvet över ±180° räknas rätt: baksvingen
  **medurs** (P1 −95° → −180° → P3 130° är 135°), nedsvingen och genomsvingen **moturs**
  (P5 100° → 180° → P7 256°, P7 −104° → 0° → P9 80°, 184°). **Fel håll:** mer än **270°**
  åt svingens håll mellan ändarna betyder att skaftet gick åt andra hållet (−95° → −85° i
  baksvingen är 350° medurs, −104° → −110° efter träffen 354° moturs), och då finns inget
  förslag ur skaftet (`SKAFT_MAX_SPANN`, `skaftMaxSpann`; de verkliga spannen är 135–184°).
  Inget förslag heller när en ände saknas eller är hoppad, tiderna inte är i ordning eller
  vinkeln inte når vågrätt (en kort baksving); då gäller kroppens. **antagande** (vinkeln
  linjär i tiden; handleden vinklas mest mellan P2 och P3, så förslaget kan ligga någon ruta
  fel; 270° som gräns), oprövat på riktiga svingar.
- **Vad som visas** (`ClubMarking.shownTime`): en markerad position visar sin egen ruta; en
  omarkerad eller hoppad position visar förslaget (framifrån ur skaftet, bakifrån FO-parets
  tid, annars kroppens), och en hoppad utan förslag sin hoppade ruta.
- **Markeringen** (`KlubbMarkering`): positionen, rutans tid (s relativt klicket, Visions
  rutor), greppet och hoseln i hela bildens pixlar, källan (`klick`, eller greppet
  `handlederna_bekraftad`), när den ändrades (`andrad`), och `hoppad` för en position där
  klubban inte syns (inga punkter). Sparas i `pass.json` (`slag[].klubba`) och i paketet som
  `klubba.json` (`swinglab-klubba/2`, FORMAT.md).
- **Rutans tid** är rutan där första punkten sattes (`ClubMarking.frameT`): den följer med
  i ångra och är den som sparas och som videon söks till, också efter ett ångra. Ett steg
  till en annan ruta med en punkt satt frågar först ("Clear the points?") och tömmer dem;
  ett tryck på en annan ruta än den första punktens blir ingen punkt.
- **Märkningen på telefonen** (`ClubMarking`, bakifrån och framifrån, BESLUT B47, B57): ytan
  visar seriens utsnitt
  vidgat med **15 %** per sida (som MF6). Ett tryck sätter greppet och nästa hoseln, och
  **positionen sparas av sig själv** när hoseln är satt och nästa i ordningen (B58) visas;
  ångra och raden med positionerna i samma ordning finns kvar. **Greppet som ring:** handledernas mitt i rutan (konfidens ≥ 0,3, M1)
  visas som en streckad ring; ett tryck inom ringen (**5 %** av ytans bredd) gör den till
  greppet med källan `handlederna_bekraftad`, ett tryck utanför är ett fritt grepp (`klick`),
  så att träningsdatan kan skilja dem (handlederna ligger 5–8 cm från skaftet, B44). Ett
  tryck närmare ytans kant än **3 %** (eller utanför bilden) blir ingen punkt. En satt punkt
  flyttas när fingret börjar inom **5 %** av den och rör sig mer än **4 pt**; punkten följer
  fingrets förflyttning (avståndet mellan finger och punkt behålls), och ett kortare drag är
  ett tryck. Riktpinnen sätts med två tryck, bara bakifrån (M48). **antagande** (gränserna,
  valda för ett finger på en telefon; oprövade på telefonen).
- **Zoomen** (S7c, BESLUT B59): ytan visar en del av märkningens yta (`ClubMarking.zoom`,
  samma proportioner), och trycken räknas om genom den till hela bildens pixlar
  (`klubba.zoom_start` och `yta_till_bild` på PC:n ger samma pixel, `KlubbYtaFixturer`). En
  position öppnas **inzoomad 2,5 ×** kring skaftets förväntade mitt: positionens egen
  markering (skaftets mitt) när den finns, annars greppet (handledernas mitt, annars de
  markerade greppens mitt) plus halva skaftet åt det håll skaftet pekar i grannen, den
  närmaste markerade positionen i svingen; utan granne handledernas mitt. Zoomen sänks bara
  när en cirkel med radien **0,6 · L** kring mitten inte får plats, aldrig under 1 ×; L är
  positionens egen markering, annars medianen av de markerade skaften, annars **0,80 m**
  genom skalan (M2, M49); mitten flyttas in i ytan. Med radien 0,6 · L blir det 2,5 × för ett
  skaft upp till 0,33 av ytans smalaste sida (1080 px bred bild: 360 px). Uppmätt i
  simulatorprovet: **2,50 ×** vid P4 (bilden 270 × 480, skaftet 80 px ur skalan). Granskningen
  av S7c: med cirkeln med hela L och marginalen 1,15 blev det 1,0–1,5 × och klubban lika liten
  som förut. Nyp zoomar med bildens punkt under fingrarna kvar, mellan hela ytan och **8 ×**;
  under ett nyp blir draget varken panorering eller tryck förrän alla fingrar släppt; ett drag
  som inte börjar på en punkt och är längre än 4 pt panorerar; ett dubbeltryck (två tryck
  inom **0,3 s** och **20 pt**) växlar mellan hela ytan och startzoomen och ångrar det första
  tryckets punkt (i riktpinnens steg dess ände). Gränserna för ett tryck (kanten 3 %, ringen
  och en punkt 5 %, drag 4 pt) gäller ytan som syns, alltså fingret på skärmen. **antagande**
  (2,5 ×, 0,6, 8 ×, 0,3 s och 20 pt, valda för ett finger på en telefon; oprövade på
  telefonen).
- **Nästa position** efter en sparad eller hoppad är nästa i ordningen som saknar markering,
  runt till början; ett slag där alla har en markering öppnas klart ("All positions done").
  På en markerad position heter knappen Next och går vidare utan att ändra den; Skip skriver
  aldrig över en markering. Punkt 2 inom 5 % av ytans bredd från punkt 1 blir ingen punkt.
- **Gissningen av greppet** är handledernas mitt (som ringen i S7a), ritad som en ihålig punkt
  "1?"; ett tryck inom 5 % av ytans bredd från den godtar den. Punkterna heter 1 (greppet) och
  2 (klubbhuvudet, alltså hoseln, B44) i bilden.
- **Förstoringsglaset** är 124 pt brett och visar en del av ytan som är 124/3 pt bred, ur
  rutan som stillbild med toleransen 0 (`AVAssetImageGenerator`), så att förstoringen i
  punkter på skärmen är **3,000 ×** (mätt i simulatorprovet: `loupeMagnification` på ytans
  bredd, 258,8 pt; ovanpå zoomen räknas glaset ur det som syns, så att det förstorar 3 ×
  också inzoomat). Det visar hårkorset och de satta punkterna, och står bredvid fingret där
  det inte täcker fingret eller en satt punkt, inskjutet från ytans kant.
- **Tryck per sving:** greppet och hoseln per position, alltså **20** för P1–P10 (Next
  behövs inte längre: 10 tryck färre), plus stegen till P2, P6 och P8 från förslaget,
  uppskattat **2–5** per position: cirka **26–35** tryck per sving, i båda vyerna. En hoppad
  position är ett tryck; riktpinnen två tryck en gång per serie bakifrån. Framifrån kan
  förslaget ur skaftet spara steg vid P2, P6 och P8; hur många mäts på telefonen.

## M46 — Skaftets vinkel vid varje position, och osäkerheten (båda vyerna)

- `skaft_vinkel_p1` … `skaft_vinkel_p10`: vektorn grepp → hosel mot vågrätt i bild,
  grader i (−180°, 180°], **0 = vågrätt mot +X** (bollen DTL, målet FO), **+ = hoseln över
  greppet** (moturs med y uppåt). I katalogen en rad `skaft_vinkel` per vy med alla tio
  positioner; granskningen visar positionens värde (`Klubba.nyckel`). **räkning** i 2D:
  inget antagande utöver punkterna. Bakifrån är skaftet förkortat när det pekar mot
  kameran (P2, P6, P8), så vinkeln där är bildens, inte rummets.
- **Osäkerheten:** ett tryck antas osäkert **3 px** (1 sd i x och i y, i hela bildens
  pixlar; **antagande**, förstoringsglaset 3 ×). Varje måtts osäkerhet räknas genom
  måttets egen geometri: centrala differenser (steget **0,5 px**) för varje punkt som
  ingår, i x och y, och roten ur summan av kvadraterna (`klubba.osakerhet`,
  `Klubba.osakerhet`; Python och Swift samma tal). För en linje mellan två tryck L px isär
  blir det √2·3/L radianer: 4,1° vid 60 px, 2,4° vid 100 px, 0,8° vid 300 px. Riktpinnens
  tryck ingår i måttet vid toppen (M48), hoslarnas men inte skaftet vid P6 i P6-måttet
  (M47), och casting blir osäkert när arm och skaft nästan ligger i linje (acos branta där).
- **Spärren:** ett mått vars skattade osäkerhet är över **4°** saknas (`MAX_SD`). Det är
  samma gräns som förut för en ensam linje (60 px), men den följer nu måttets geometri, så
  att ett kort skaft vid P6 inte stoppar P6-måttet och ett långt skaft inte räddar ett mått
  där punkterna ligger illa till. Vid P2, P6 och P8 bakifrån och ofta vid träffen ligger
  skaftet nästan mot kameran och blir kort i bild; då saknas vinkeln hellre än att visa brus.
  **antagande** (4°, samma gräns som för en ensam linje på 60 px). Hunter 2022
  (Sci Rep 12:14012, läst i original, research 5d) fann 2D-skaftvinklar mot Vicon r > 0,9
  utom i adressen; ingen siffra för handmarkering.

## M47 — Skaftplanet bakifrån: P1 och P6 (DTL)

- **Uppställningen bakifrån** för klubbans mått: kameran **på händernas linje, i händernas
  höjd, riktad längs mållinjen** (texten i appens uppställning). Då ligger kameran i
  P1-skaftplanet (planet genom bollen och händerna som innehåller mållinjens riktning), och
  ett plan genom kameran syns som en linje i bild: en punkt i planet ligger exakt på
  P1-linjen. Prövat i 3D (granskningens `p6.py`, f = 1400 px): en hosel i planet 2,5–4,5 m
  bort ger P6-måttet **0,0°** från händernas linje, men −14,6° till +3,1° från mållinjen i
  höfthöjd och −6,0° till +1,6° från mållinjen på 0,5 m. **räkning** (perspektivet).
- `skaftplan_p1`: linjen genom hoseln och greppet vid P1, förlängd, och dess vinkel mot
  marken i bild sedd från bollens sida (hoseln åt +X), grader, typiskt 50–65°. Det är
  linjen som P6 jämförs med ("shaft plane", P-systemet, **tränare**, ej läst i original).
  **räkning** i bild.
- **P2 mot planet är borttaget** (granskningen 2026-10-23). Det gamla måttet (P2-skaftets
  linje mot P1-linjen) mätte kamerans höjd mer än svingen: vid P2 pekar skaftet bakifrån
  mot kameran, och linjen i bild vände med kamerans höjd (i 3D-provet −28° till +80° för
  samma sving mellan 0,6 och 1,4 m). Avvikelsen från riktningen grepp → flyktpunkt (som
  M48) bär inte heller: P2 bakifrån *är* rutan där skaftet pekar mot flyktpunkten (M45), så
  avvikelsen är noll per definition, och skaftet är då 20–70 px i bild (osäkerheten över
  spärren). Kvar vid P2 är skaftets vinkel i bild (M46) när den bär.
- `skaft_plan_p6`: vinkeln vid hoseln i adressen (≈ bollen) från P1-linjen till hoseln
  vid P6, grader, **+ = över planet** (hoseln utanför linjen, mot bollens sida uppåt),
  − = under (innanför). Ett tal i grader, oberoende av skalan. **Spärren** är måttets
  osäkerhet (M46) ur P1:s två punkter och hoseln vid P6, alltså i praktiken avståndet mellan
  hoslarna; skaftets längd vid P6 spelar ingen roll. Exakt med uppställningen ovan.
  **Källan räcker inte:** Morrison 2018 (Proc IMechE P 232(4):295–304, läst i original,
  research 5b och 5 §5 punkt 11) mätte leveransplanet i 3D (bladmittens bana från mitten
  av nedsvingen till träff, anpassad till ett plan) och fann att avvikelsen från det
  förklarade 57 % av spridningen i träffpunkt. Det är inte P1-linjen i bild och inte P6, så
  måttet är ett **antagande** med egen baslinje och Morrisons tal gäller det inte.

## M48 — Skaftet vid toppen bakifrån: across the line och laid off (DTL)

- `skaft_riktning_topp`: vinkeln vid greppet vid P4 från riktningen **grepp →
  flyktpunkten** till skaftet grepp → hosel, grader, **+ = across the line** (huvudet åt
  bollens sida), − = laid off.
- **Vad som syns i 2D:** across the line och laid off är skaftets riktning i rummet mot
  mållinjen (P-systemet: parallellt vid toppen). Bakifrån pekar ett parallellt skaft från
  kameran och i bild mot mållinjens **flyktpunkt**. Storleken är bildens vinkel, inte
  rummets: förkortningen gör den 2,8–3,7 gånger större (i 3D-provet ger 10° across +29° till
  +37°), och den går inte att räkna om utan djup. Talet jämförs pass mot pass; egen
  baslinje.
- **Flyktpunkten ur riktpinnen** (valfri, en gång per serie, `serier[].riktpinne`): två
  tryck på en pinne på marken parallell med mållinjen. Flyktpunkten ligger på pinnens linje,
  där den skär bildens vågräta mittlinje (horisonten för en kamera i våg). Pinnens linje
  måste gå minst **5 %** av bildhöjden i y, annars används bildens mitt. Prövat i 3D
  (`geo2.py` i granskningen, f = 1400 px, toppen 3,75 m bort): med pinnen tar en vriden
  kamera inget fel (0,0° vid 0–5°), medan bildens mitt ger **3,7–4,7° fel per grads
  vridning**; en kamera som lutar 3° ger med pinnen +4,3° på händernas linje och −11,5° från
  mållinjen i höfthöjd (lodlinjen, MS17, rättar det inte än). **räkning** (pinnen),
  **antagande** (kameran i våg).
- **Utan riktpinne** är flyktpunkten **bildens mitt** (kameran riktad längs mållinjen,
  mitten är den optiska axeln) och måttets källrad i granskningen säger "assumed: vanishing
  point at the picture center" (`ShotMeasure.klubbaFlyktpunktAntagen`, analysens
  `klubba_flyktpunkt`). Uppställningen är M47:s.
- Saknas när greppet inte står minst **5 %** av bildhöjden över flyktpunkten (riktningen
  mot den blir liten eller vänder), eller när osäkerheten är över spärren (M46).
  **antagande.**

## M49 — Klubban framifrån: toppen, armen och skaftlutningen (FO)

Framifrån ligger mållinjen i bildens plan, så skaftets lutning mot vågrätt och lodrätt
syns direkt; djupled (mot och från kameran) syns inte. Måtten finns i Python och Swift, och
appen märker framifrån med samma flöde som bakifrån, utan riktpinne (BESLUT B57, PLAN S7a).

- `skaft_topp`: vektorn grepp → hosel mot vågrätt vid P4, grader, **0 = parallellt med
  marken mot målet**, **+ = kort av parallellt** (huvudet över greppet), − = förbi
  parallellt. Ett skaft som pekar mot eller från kameran (across eller laid off) förkortas
  i x, och lutningen blir då större i bild än i rummet. **antagande** (2D), egen baslinje.
- `skaft_arm_p5`, `skaft_arm_p6` (casting): vinkeln mellan främre armen (handleden →
  axeln, svingens utjämnade leder vid markeringens tid, M3; den egna handleden, som M22)
  och skaftet (grepp → hosel), grader i [0°, 180°]: **180° = arm och skaft i linje**,
  mindre = mer vinkling i handleden. Casting är att vinkeln ökar tidigt i nedsvingen
  (research 5d K: Chu 2010 och Joyce 2016, bara abstract; Sportsbox "lwrist angle arm
  parallel", bara rubriken). Ingen norm med samma definition; egen baslinje. Saknas när
  axeln eller handleden saknas vid tiden. **antagande** (definitionen i 2D).
- `skaft_lutning_traff`: skaftet hosel → grepp mot lodlinjen vid P7, grader, **+ = greppet
  mot målet** (framåtlutning), − = bakåt. **räkning** i bild; egen baslinje (ingen norm
  läst i original med samma definition).
- **Uppställningen framifrån** för klubbans mått: kameran **mitt för spelaren, i höfthöjd,
  riktad vinkelrätt mot mållinjen** (texten i appens uppställning: "Facing the player, at hip
  height, aimed square to the target line"). Då ligger mållinjen i bildens plan, och ett
  skaft parallellt med den syns i sin fulla längd och sin riktning.
- **Känsligheten för uppställningen**, mätt i 3D (2026-10-23, granskningens metod: en
  påhittad högersving framifrån, punkterna projicerade med en hålkamera, f = 1400 px på
  1920 px långsida, stående 1080 × 1920; fötterna 3,5 m från kameran, bollen 2,9 m; skaftet
  0,80 m; måtten räknade med `klubba.mat`). Utgångsläget är uppställningens text: kameran
  mitt för spelaren (bollen mitt i stansen, framför bröstbenet), i höfthöjd (1,0 m för en
  spelare på 1,80 m), i våg och riktad vinkelrätt mot mållinjen. Ändringen i grader:

  | Uppställningen | `skaft_topp` | `skaft_arm_p5` | `skaft_arm_p6` | `skaft_lutning_traff` |
  |---|---|---|---|---|
  | vriden på platsen, per grad (±10°) | −0,21 | +0,14 | ≤ 0,08 | ≤ 0,03 |
  | höjden 0,6 m / 1,4 m (i våg) | 0,0 (across ±10°: ±1,2) | +4,7 / −4,6 | +4,8 / −4,3 | +0,7 / −0,6 |
  | höjden 1,4 m, lutad 6° nedåt | 0,0 (across ±10°: ±1,2) | −3,8 | −4,4 | −0,1 |
  | flyttad 0,5 m längs mållinjen, riktad mot spelaren | +1,7 | −7,9 | +3,6 | +3,5 |
  | rullad 1° (inte i våg) | +1,0 | 0 | 0 | −1,0 |

  Höjden flyttar casting (armen och skaftet går båda i djupled) med cirka **2,3° per 0,2 m**;
  sidoläget längs mållinjen flyttar casting **1,6°** och skaftlutningen **0,7° per 0,1 m**;
  vridningen på platsen högst **0,21° per grad**. Toppen påverkas av höjden bara när skaftet
  pekar i djupled (across eller laid off ±10° ger ±1,2° på 0,6 eller 1,4 m och 0 i toppens
  höjd). Rullningen går 1:1 in i skaftets vinkel, toppen och skaftlutningen men inte i
  casting (en vinkel mellan två linjer i samma bild); lodlinjen (MS17) rättar den inte än.
  Vid P2, P6 och P8 flyttar uppställningen vinkeln hos ett parallellt skaft högst 1,1° (höjden
  1,4 m och vriden 5°, eller rullad 1°), alltså oftast under en ruta. Alla FO-mått har egen
  baslinje, så det som räknas är samma uppställning pass mot pass. **räkning** (perspektivet), **antagande**
  (svingens punkter i 3D).
- **Osäkerheten** följer M46: 3 px per tryck genom måttets geometri, och måttet saknas över
  4°. Framifrån är skaftet långt i bild: med 400 px/m (de påhittade svingarna, 1080 × 1920)
  och grepp → hosel 0,80 m är det 285–310 px vid P1, P2, P6, P7 och P8, 220–280 px vid P3,
  P4, P5 och P9 och cirka 160 px i finishen, och osäkerheten **0,8–1,1°** (finishen 1,5°;
  `test_klubba`, fixturerna). Casting tar bara skaftets två tryck; armen ur lederna ingår inte
  i osäkerheten, och nära 180° (arm och skaft i linje) spärrar acos branta derivata måttet.

---

# Inspelningen (S2)

Konstanterna i SwingLabKit-modulen `Capture` (S2_SPEC §2–§7, §9). Numreringen
MS följer specens METOD-förslag (§11.1). Swift och Python (`tools/pc/klick.py`)
räknar klicket och parningen lika (BESLUT B12); resten provas med påhittade
värden i `CaptureTests`.

## MS1 — Formatvalet

- Bara format med **exakt 1920 × 1080** (lagrat, liggande) och högsta
  bildfrekvens ≥ **240 − 0,5** bilder/s (flyttalen i telefonens rapport, t.ex.
  239,76). Bland dem: störst vågrätt synfält (`videoFieldOfView`, 0 = okänt
  räknas som minst), sedan binnat (Apple: "greater low light sensitivity"),
  sedan 8-bitars före 10-bitars, sedan lägst index. **antagande**, prövas i S2c.
- Finns inget i 240: högst frekvens ≥ **120** i 1080p, samma ordning vid lika
  frekvens, och vyn visar frekvensen i gult (`FormatChoice.reaches`).
- Valet görs ur det telefonen själv rapporterar (`device.formats`), aldrig ur en
  modellista: Johannes telefoner är iPhone 17 och iPhone 13, och listorna skiljer.

## MS2 — Exponeringsplanen

- Låst tid = 1/2000 s (BESLUT B11), klämd till formatets
  `[minExposure, maxExposure]`. ISO-behovet
  `neededISO = aeISO · (aeTid / låst tid) · 2^(−exposureTargetOffset)`, låst ISO =
  behovet klämt till `[minISO, maxISO]`, EV-bristen `max(0, log2(neededISO / maxISO))`.
  **räkning (fysik):** exponeringen är tid × ISO, och offset är i EV
  (Apple, `exposureTargetOffset`).
- **good** om behovet ≤ maxISO / 2 (ett steg kvar), **marginal** om ≤ maxISO,
  annars **tooDark**. **antagande.**
- Ett tal ur autoexponeringen som inte är ändligt och positivt ersätts (tiden
  med den låsta, ISO med minISO, offset med 0), så att planen alltid går att
  låsa (risk R2) och skriva som JSON.
- Tabellen över belysning (S2_SPEC §2.3, K = 12,5, 18 % grått, N = 1,78): ISO
  1000 ≈ 1 400 lux, 2000 ≈ 700 lux, 4000 ≈ 350 lux på golfaren. **räkning +
  antagande**, en storleksordning (telefonens ISO är inte kalibrerad mot standarden).

## MS3 — Ljusprovet och rutornas tider

- **Rutnätet** i två steg. (1) Skattningen g0 = 1 / medel av de korta stegen,
  de positiva stegen upp till **1,75 ×** 5:e percentilen (linjär interpolation),
  mellan avrundningens 3/2 och en tappad rutas 2. De kortaste stegen, inte
  medianen: oktobers klipp låg på 240-rutnätet med drygt en tredjedel av rutorna
  borta (**mätt**, Golf SG; research 2 §2). (2) Förfiningen med hela spannet:
  `g = Σ max(1, round(steg · g)) / (sista − första)`, upprepad (högst **5** varv)
  tills det avrundade talet står still; svaret är g avrundat. Skälet: en film i
  standardskalan 600 har 1/240 s som steg om 2 och 3 enheter (simulatorprovet
  S2c: stegen var 2, 3 och 5 enheter, och percentilen ensam gav 300), och med
  skurar av tappade rutor vandrade de korta stegens medel till 229–249
  (granskningens simulering). Med förfiningen ger 0,5 s, 3 s och 10 s med 36 %
  tappade i skurar om 1,5 och 60 % i skurar om 2 och 5 rutnätet 240 i 50 av 50
  (`InspelningTests`, tiderna som `tools/pc/tre_d/kamera.py`). **räkning.**
- **Den kända frekvensen** (S2e, efter Johannes första import 2026-10-22: kvittot
  visade **239** på ett slowmotion-original i 240). Orsaken: regeln ovan svarar den
  uppmätta klockan avrundad, och en klocka som går **0,25 %** långsamt (239,4)
  avrundas till 239; 238,5 gav 238–239 och 241,5 gav 241–242 (9 s, 36 % tappade,
  tidsskalorna 600 och 90 000; `testKlockanSomGarFelGerAnda240` visar att den gamla
  regeln gav 239). Skakning avrundas bort och var inte orsaken (likformig ±0,5 ms gav
  240). Nu: de kända frekvenserna **24, 25, 30, 48, 50, 60, 100, 120, 240** som ligger
  inom **±10 %** från skattningen ovan prövas i stigande ordning (så att 120 inte tas
  för en film i 40). För var och en: den frekvens inom **±1 %** vars faser
  `2π·t·g` har den längsta medelvektorn på filens första **1 s** (steg om **0,1**
  varv), sedan minsta kvadrat `t = a + n/g` med rutornas nummer `n = round((t − a)·g)`
  på ett fönster som dubblas till hela filen, så att en klocka som går fel följs utan
  att numren glider. Rutnätet är den kända frekvensen när den anpassade klockan ligger
  inom ±1 % och fasernas medelvektor är minst **0,5** (skakning med sd σ ger
  exp(−2π²σ²g²): 0,5 vid σ ≈ 0,78 ms i 240); annars gäller skattningen ovan, avrundad.
  Den anpassade klockan sparas (`measuredRate`) och ger andelen tappade. Provat
  (`InspelningTests`, påhittade tider som `skurtider`): klockan 240, 239,4, 238,5 och
  241,5 i tidsskalorna 600, 90 000 och utan, 3 s och 9 s, 36 % tappade i skurar,
  skakning 0 och ±0,5 ms (och ±0,8 ms utan tidsskalan 600): 240 i 1 280 av 1 280,
  klockan inom 0,05; 29,97 → 30 och 119,88 → 120; 200, 90, 40 och 300 behåller sitt
  rutnät. **räkning** (metoden), **antagande** (gränserna ±1 % och 0,5).
- **Gränsen för skakning:** tidernas skakning (sd) upp till **0,3 ms** ger
  rutnätet exakt med de korta stegen; **0,5 ms** ger 239–241; **0,8 ms** ger 244–342
  (simulering, 300 påhittade filer om 3 s med 36 % tappade). Med den kända
  frekvensen ger likformig skakning ±0,5 ms i tidsskalan 600 (sd ≈ 0,5 ms med
  avrundningen) 240; ±0,8 ms i tidsskalan 600 gav 246 i 1 av 20 (simulering).
  **antagande** (telefonens skakning).
- Andelen tappade = `1 − antal / ((sista − första) · klocka + 1)`, med den uppmätta
  klockan (`measuredRate`; rutnätet när den saknas).
  **Slowmotion** = rutnät ≥ **100** bilder/s; under det är en import omräknad och
  vägras (S2_SPEC §5). **antagande** (gränsen).
- **Flimret** = `sqrt(a² + b²) / c` ur en minsta kvadrat-anpassning av
  `c + a·cos(2πft) + b·sin(2πft)` på rutornas egna tider, vid 100 Hz (50 Hz-nät)
  och 120 Hz (60 Hz-nät). En kolumn som är noll på rutorna (sinus vid exakt halva
  bildfrekvensen) lämnas ute, så 120 Hz kan underskattas. **standard** (minsta
  kvadrat) för räkningen. Provat: 20 % djup vid 100 Hz på oregelbundna tider ger
  0,20 ± 0,01; konstant ljus < 0,005.
- **Gränserna:** flimmer (det större av 100 och 120 Hz) under 3 % grönt, 3–10 %
  gult, över 10 % rött; tappade rutor under 1 % grönt, 1–5 % gult, över 5 % rött;
  medelljusheten 0,20–0,60 grönt, utanför gult. Domen är den sämsta av ISO
  (MS2), flimmer, rutor och ljushet. **antagande**, kalibreras på de första passen.

## MS4 — Klicket

- Golf SG:s `handled_video.klick()` rad för rad (S2_SPEC §4.1): första
  differensen, RMS i ett centrerat fönster om **0,002 s** (96 prov vid 48 kHz,
  `n − 48 … n + 47`), toppar över **25 ×** bitens median (+ 1e-9), toppar närmare
  än **0,5 s** blir den största (jämfört mot den senaste), och ansatsen är första
  provet över **0,5 ×** toppen inom **0,02 s** före den. Styrkan = toppen / medianen.
  **mätt** i Golf SG: 41 av 41 klick i oktobers mätning, rest mot bandet 1–7 ms i
  median (HANDLED_PLAN §3).
- **Avvikelse:** en signal kortare än fönstret ger inga klick (Golf SG:s
  `np.convolve` byter då plats på fönstret och signalen). Påverkar bara de
  första 2 ms.
- En impuls i prov k ger ansatsen **k − 47** (fönstrets första prov). Specens
  "k − 48" är ett prov fel. Ett klick på 10 prov ger ansatsen ≈ 44 prov (0,9 ms)
  före klicket, lika i båda språken och för båda telefonerna.
- **Bitar om 30 s med 1 s överlapp**, medianen per bit, och klick närmare än
  0,5 s över bitarnas gräns blir det starkaste. **antagande** (minnet på
  telefonen). PC:n delar in likadant (`klick_i_bitar`), och appen klipper ljudet
  vid samma prov (S2c).
- **Bitgränsen:** vid en inre gräns är bitens energi kapad (fönstret och
  `hp[0] = 0`), så ett klick där hittas på fel prov (i receptet `bitgrans` 31 prov för tidigt). En bit
  kastar därför klick vars topp ligger närmare än **0,02 s + fönstret** (1 056
  prov vid 48 kHz) från en inre bitgräns; grannbiten, som överlappar 1 s, ser
  klicket helt. Signalens egen början och slut är ingen inre gräns. Provat på
  påhittat ljud (recepten `lang` och `bitgrans`): klick i överlappen, 13 prov in
  i en bit och i en bits sista prov hittas en gång, på samma prov som utan bitar;
  styrkan skiljer under 1 %. Utan regeln hittas klicket 13 prov in på fel prov.
- **Paritet:** Swift hittar samma ansats på provet och styrkan inom 1e-6
  relativt som Python på 8 påhittade signaler (`KlickFixturer.swift`), och Python
  ger Golf SG:s tal exakt (`tools/tests/test_klick.py`, lokalt där Golf SG finns).
  Swift räknar energin med löpande summa i double, förankrad om var 4096:e prov.

## MS5 — Svingdomen

- Ett klick blir ett slag när glesa leder (var **8:e** ruta i **[−1,6; +0,1] s**
  kring klicket) visar en sving (S2_SPEC §4.3): kroppens längd H = medianen av
  fotledernas mitt − näsan i y, px; händerna = handledernas mitt (greppregeln,
  M1); farten mellan rutorna i H per sekund, med tiden i stegets mitt.
- **Slag** om (a) högsta farten i **[−0,10; +0,05] s** är minst **2,0 H/s** och
  (b) händerna står över axlarnas mitt någon gång i **[−1,6; −0,15] s**. **Inte
  slag** om (a) eller (b) brister (provat: 2,1 H/s genom träffen ger slag,
  1,9 H/s inte). **Osäkert** om färre än **60 %** av rutorna har
  alla 13 leder säkra (MS8) eller kroppens längd saknas.
- Bekräftade och osäkra slag får Vision på varje ruta i **[−2,5; +1,5] s**
  (samma fönster som Golf SG:s MediaPipe).
- **antagande**: 2,0 H/s ≈ 3,2 m/s för H = 1,6 m, med marginal mot proffsens
  händer över 6 m/s vid träffen. Kalibreras på oktobers 41 slag i S2e (alla ska
  bli slag).

## MS6 — Träffen ur klicket

- Träffen = klicket − avstånd / **343 m/s** (ljudets fart i luft vid cirka 20 °C).
  **fysik**; Golf SG mätte cirka 9 ms framifrån på 3 m (HANDLED_PLAN §4), och
  3 / 343 = 8,7 ms. Ett fel på 0,5 m i avståndet är 1,5 ms.

## MS7 — Orienteringen

- EXIF ur spårets `preferredTransform` (a, b, c, d) med toleransen **0,01**:
  (0, 1, −1, 0) → 6, (0, −1, 1, 0) → 8, (1, 0, 0, 1) → 1, (−1, 0, 0, −1) → 3;
  annat (speglat) → 1. Upprätt storlek byter bredd och höjd för 6 och 8. Visions
  punkt (origo nere till vänster) → pixlar `(x·B, (1 − y)·H)`. **vedertagen
  avbildning**; prövas i simulatorn (S2c) och med klapprovet (T2).
- **Vakten:** i adressen (seriens första **0,3 s**) ska kroppens axel, fotledernas
  mitt → näsan, vara mer lodrät än vågrät: |medianen av Δy| > **2 ×** |medianen av
  Δx| över rutorna med de tre lederna säkra. Passet märks när **fler än hälften**
  av slagen brister. **antagande.**

## MS8 — Lederna: konfidensen och personen

- En led räknas som säker vid **c ≥ 0,1**, en observation vid **≥ 0,6**, som
  Apples exempel (WWDC20 session 10653). **tillverkare, ej läst i original.**
  Ledgränsen gäller telefonens svingdom (MS5), observationsgränsen personvalet
  nedan. Mätningen läser samma leder med gränsen 0,3 (M1). Kalibreras i S2e.
- **Flera personer:** bara säkra observationer (≥ 0,6) räknas; finns ingen
  saknar rutan leder. I första rutan räknas de som är minst **hälften** så höga
  (H) som den högsta, och den vars höfters mitt ligger närmast bildens mitt i x
  väljs; sedan den vars höfters mitt ligger närmast föregående ruta. Grannen
  längre bort är mindre i bild. **antagande.**
- **Synligt på telefonen** (S2e, för att kunna kalibrera gränsen 0,6): raden under
  ms/frame i passet visar kandidaterna per analyserad ruta, observationernas
  konfidens som median (på en hundradel, ur en räkning per hundradel; nedre medianen
  vid jämnt antal) och max, och andelen analyserade rutor där en person valdes
  (`VisionStats`). Gränsen står kvar tills telefonens tal (T2, oktobers 41 slag) säger
  annat. **räkning.**

## MS9 — Klockorna

- NTP:s fyra tider: `θ = ((t1 − t0) + (t2 − t3)) / 2`, `δ = (t3 − t0) − (t2 − t1)`.
  **standard** (NTP, RFC 5905).
- Förskjutningen = medianen av θ bland **fjärdedelen** av proven med lägst δ
  (avrundat uppåt, minst ett). Osäkerheten = **största** δ / 2 bland dem: varje
  provs θ ligger inom δ/2 från den sanna förskjutningen hur osymmetrisk vägen än
  är, så det är en gräns för medianen. Specen föreslog minsta δ / 2, som inte är
  en gräns. **antagande** (fjärdedelen). Provat med 30 påhittade ping med 1–20 ms
  osymmetrisk väg: inom osäkerheten och inom 10 ms. Pingen är bara ett
  förhandsvärde; synken är klicket (MS10).
- **När (S2g):** en skur om **30** ping med **20 ms** mellanrum när följaren sagt
  hello, vid varje start och efter varje stopp, och däremellan **en ping i
  sekunden** (hjärtslaget). Proven märks med serien: *under* (från start till stopp)
  och *efter* (efter stopp). t0 stämplas när pingen lämnar telefonen (nätets kö),
  och följaren svarar på nätets kö med t1 och t2 stämplade där, inte på huvudtråden. Är en förbindelse tyst i **4 s** stängs den, och
  följaren försöker igen varje **1 s** (flygplansläge stänger inte TCP av sig
  självt). **antagande** (tiderna). `LinkLeader`, App/Link.swift.

## MS10 — Parningen

- Golf SG:s `para()`: förskjutningen d (b ≈ a + d) som parar flest klick inom
  **30 ms**, sökt i steg om **5 ms** (det första vid lika), förfinad med medianen
  av de parade resterna. **mätt** i Golf SG (klicken mot bandets stötar, oktobers
  mätning). Python (`tools/pc/klick.py para`) ger Golf SG:s förskjutning inom 1e-9.
- Sökfönstret: **prior ± 0,25 s** med ping, **± 0,5 s** när pingen efter stopp
  saknas, **± 10 s** utan. Golf SG sökte ± 3 s. **antagande.** Ett tomt fönster
  (`priorWindow ≤ 0`) söker inget: svaret är prior, inga par och osäker.
- **Osäker parning:** med ett par blir resten 0 vad förskjutningen än är, och
  utan prior väljs lägsta d vid lika antal (påhittat exempel: sann 2,07 s, svar
  −8,46 s). Resultatet bär därför antalet par i sökningen och marginalen, det
  bästa d minst **2 · 30 ms** från det valda och hur många det parar. Parningen
  är **osäker** med färre än **3** par utan prior (**1** med), eller när det näst
  bästa parar lika många. **antagande.** Python och Swift ger samma dom.
- **Två telefoner (S2g):** klockan tas ur proven *efter* stopp, annars ur proven
  *under* serien, annars de 30 sista före starten. Prior = SL − SF + θ, där SL och SF
  är filernas start på var sin värdklocka och θ = följarens klocka − den styrandes;
  förskjutningen är följarens filtid − den styrandes för samma klick. Träffens
  förskjutning = förskjutningen − (följarens avstånd − den styrandes) / 343 (MS6).
  Parningen görs när båda serierna finns och görs om efter varje pingskur; en ändring
  skriver om raden i `par.json` (docs/FORMAT.md "Två telefoner"). `PairEntry.make`.
- **Avvikelser:** stegen räknas `lo + i·steg` (numpys `arange` gör nästan det),
  och parar inget svaras prior (eller 0), osäker, i stället för sökningens början.

## MS11 — Kvittot, trycket och disken

- **Kvittot** efter varje serie (S2_SPEC §12 S2c): rutnätets frekvens (vit när
  den når 240 − 0,5, gul under, röd under 100 = inte slowmotion, MS1 och MS3), med
  den uppmätta klockan inom parentes när den skiljer minst **0,05** ("240 (239.4)"),
  tappade rutor efter källan: en egen inspelning med gränserna i MS3 (under 1 %
  vitt), ett importerat original ur Kamera-appen vitt upp till **45 %**, gult
  **45–55 %**, rött över (Kamera-appens slowmotion-original tappar 30–40 %:
  oktobers klipp 36 %, **mätt** i Golf SG HANDLED_PLAN; Johannes första import
  36 %; gränserna **antagande**), antal rutor, klicken (gul vid noll), filens
  storlek per minut i MB (10⁶ byte, `byte / längd · 60`), längden och det högsta
  värmetrycket under serien. **räkning**; storleken per minut mäts på telefonen
  i S2c (S2_SPEC §2.6 antog några hundra MB i 1080p 240 HEVC).
- **Värmen** (`systemPressureState.level`, raden "Värme" i kvittot och i
  vyn): nominal och fair vita, serious gul
  och en varning i vyn, critical och shutdown röda. Apple: systemet kan sänka
  kvaliteten under tryck och avbryter sessionen vid shutdown. **tillverkare +
  antagande** (gränsen för varningen).
- **Disken:** under **4 GB** ledigt (`volumeAvailableCapacityForImportantUsage`)
  startar ingen inspelning, och `minFreeDiskSpaceLimit` = **2 GB** stoppar en
  pågående. **antagande** (en minut i 240 bilder/s är några hundra MB).
- **Ljudet ur filen** läses i bitar som klipps exakt vid `ClickDetector.segments`
  (30 s med 1 s överlapp, räknat i prov från filens första ljudprov), med de
  inre gränserna till `detect` (MS4). **Tidslinjen:** varje buffert läggs på
  sin egen tid; en lucka över **1 ms** fylls med nollor och ett överlapp hoppas
  över (`AudioTimeline`), så att prov n ligger på första + n / 48 000 och klicken
  inte glider. Antalet prov är spårets, `floor((slut − första) · 48 000)`: kapat
  eller utfyllt med nollor, så att varje läsning ger lika många. Utfyllnaden
  är provad på Linux (`AudioTimeline`); i simulatorn fyllde läsaren själv en
  lucka på 0,1 s med tystnad, så appens egen utfyllnad är där bara provad
  indirekt (klicken inom 0,5 ms). Omsamplat ljud (AAC 44,1 kHz stereo → 48 kHz
  mono) gav i simulatorn 153 548 och 153 549 prov i två läsningar av samma fil:
  bitarnas gränser följer proven, så telefonen och PC:n kan skilja i sista biten
  på ett omsamplat ljud. Klicken hamnade ändå inom 0,6 ms från de påhittade
  (LPCM inom 0,5 ms). **mätt** i simulatorprovet, påhittad film. `ClickStream` ger samma klick som
  `detectSegmented` på hela signalen och som PC:ns `klick_i_bitar`, provat med
  buffertar av slumpad storlek på recepten `lang` och `bitgrans`. **räkning.**

## MS12 — Slagen: Vision-passen, klippen och tiden per ruta

- **Ordningen** (S2_SPEC §4.3, §6.4, `ShotPlan`): först domen på alla slag (det
  glesa passet, var **8:e** ruta i [−1,6; +0,1] s, MS5), sedan för varje
  bekräftat eller osäkert slag lederna (det täta passet, **varje** ruta i
  [−2,5; +1,5] s) och klippet. Fönstren kapas vid filens början och slut. Varje
  steg avgörs av det som står i `pass.json`, så att en avbruten analys
  fortsätter från första slag som saknar något. Ett slags id (`s01` …) ges en
  gång och återanvänds aldrig: numret kommer ur passets räknare
  (`lastShotNumber`), som aldrig går bakåt, även när slaget med det högsta numret
  försvinner. Passet sparas efter varje steg; går det inte att spara stannar
  analysen och säger det. **räkning.**
- **Personen genom serien** (`PoseTrack`): PosePicker (MS8) per ruta, med
  föregående rutas höfter. En ruta utan säker person behålls med 13 saknade
  leder, så att tiden och andelen hela rutor (MS5) syns. Lederna sparas
  avrundade som i paketet: **0,1 px**, konfidensen på **3** decimaler, tiderna
  på **4**. **räkning.**
- **Klippet** (S2_SPEC §8.2): passthrough av [klick − 2,5; klick + 1,5] s,
  kapat vid filens början och slut. Klicket mäts om i klippet med samma
  klickjakt (MS4), det närmast det väntade (seriens klick − klippets begärda
  start); över **10 ms** därifrån, eller inget klick, märks slaget.
  **antagande** (gränsen).
- **Tiden per ruta** (`VisionStats`): `msPerFrame` = Visions egen tid
  (`perform` och avläsningen) per analyserad ruta; `wallMsPerFrame` räknar med
  avkodningen, även av rutorna som det glesa passet hoppar över. Över
  **20 ms** per ruta kan det täta passet ta var 2:a ruta (S2_SPEC §6.1),
  Johannes beslut. **mäts på telefonen** (T2); simulatorns tal säger inget om
  telefonen.
- **Vad som provas var.** Linux (`SlagTests`): ordningen, återupptagningen,
  fönstren, personvalet och domen genom en serie, klippets kontroll,
  avrundningen, linjerna vid träffen och listans rader. Simulatorn
  (`SwingLabProvSlag`): `VNDetectHumanBodyPoseRequest` går **inte att starta i
  simulatorn** ("Unable to setup request", Vision kod 9, även med CPU vald;
  **mätt** 2026-10-22, Xcode 26.6, iOS 26.5-simulatorn). Provet prövar därför
  läsningen kring anropet (varje ruta i fönstret, egen tid, orientering 6), att
  Visions fel stoppar analysen synligt utan att någon dom sparas, och, med
  påhittade leder i Visions ställe (`PoseSource`, `DemoLeder`), domen, lederna
  på disk, klippen, passet och återupptagningen. Passthrough-klippet [0,5; 2,0]
  s gav klicket 0,44 ms före det väntade, på den vita rutan, och längden 1,5000
  s, men filen bär 260 rutor till 1,617 s: rutorna efter redigeringens slut
  följer med (**mätt**, påhittad film). Den som läser klippet utan att avkoda
  (`MediaReader.frameTimes`, PC:n i S2f och S3) räknar därför bara klippets rutor
  i **[0; längd)** i båda ändar: ingen ruta före 0 och ingen på eller efter längden,
  samma halvöppna fönster som läsaren. Paketet bär längden per slag (`klipp_langd_s`,
  telefonens `AVURLAsset.duration`), och PC:n läser bara rutor där (`paket.i_klippet`;
  kontaktarket ritar en svart ruta i stället för en ruta utanför, S2f).
- **Miniatyren ur klippet** (när originalet är borttaget, BESLUT B26): träffen i
  klippets tid = klicket mätt i klippet + (träffen − klicket i serien), inte den
  begärda starten, eftersom var passthrough-klippet börjar inte är dokumenterat.
  Saknas klicket i klippet gäller den begärda starten. **räkning.** `AVAssetReader.timeRange` är halvöppet: rutan exakt på
  fönstrets slut kommer inte med (**mätt**, 240 av 241). **Visions leder själva provas bara på telefonen** (T2, och
  oktobers 41 slag i S2h).

## MS13 — Fönstret och utsnittet (redigeraren, S2i)

- **Icke-destruktivt.** Originalfilen ändras aldrig. Passet sparar per serie
  (`SeriesRecord.edit`, `Edit.swift`) ett **tidsfönster** i filens tid (s) och
  ett **utsnitt**, en rektangel normaliserad 0–1 i den **upprätta** bilden med
  origo uppe till vänster (samma rum som lederna i pixlar, MS7). Saknas
  redigeringen gäller hela filen och hela bilden. **räkning.**
- **Fönstret.** Ett klick blir ett slag bara inom fönstret, gränserna
  inräknade (`countedClicks`). Fönstret och utsnittet klampas när de läses ur
  `pass.json` (`activeWindow`, `activeCrop`), så att en fil som skrivits för hand
  inte kan lägga dem utanför filen eller bilden. Vision-passen (MS5, MS12) och klippet kapas vid
  fönstret som vid filens ändar: det som trimmats bort finns inte för
  analysen. Fönstret är minst **1,0 s** (handtagen går inte förbi varandra;
  kortare än en baksving gör ingen nytta). **antagande.**
- **Utsnittet** är minst **0,2** av bildens sida åt båda hållen (216 × 384 px i
  1080 × 1920), med fria proportioner, och ligger alltid inom bilden. Under
  det har Vision för lite att se. **antagande.**
- **Vision ser bara rutan.** Appen skär ut rutan ur varje ruta före Vision
  (`VisionPoseSource.cutOut`): bufferten görs upprätt med EXIF-orienteringen
  (`CIImage.oriented`), skärs till rutan på hela pixlar (avrundad utåt,
  `CropRect.pixels`; Core Image räknar y nerifrån, `pixelsFromBottom`) och flyttas
  till origo, och Vision får den bilden med orienteringen `.up`. Visions punkter är
  normaliserade mot bilden den fick med origo nere till vänster (WWDC20 session
  10653: "relative to the pixel dimensions of your image", **tillverkare**), så en
  punkt (u, v) blir `x = (x₀ + u·b)·B`, `y = (y₀ + (1 − v)·h)·H` i hela bildens
  pixlar, med (x₀, y₀, b, h) den utskurna rutan som andelar (`snapped`). **räkning.**
  `regionOfInterest` används **inte**: Apple säger att rutan är "normalized to the
  dimensions of the processed image" med origo nere till vänster, men inte om
  kroppens punkter då är relativa rutan eller hela bilden (läst 2026-10-22). Utan
  utsnitt är vägen S2e:s: bufferten med orienteringen, punkterna i hela bilden (MS7).
- **Måtten påverkas inte av utsnittet.** Lederna sparas i **hela den upprätta
  bildens pixlar** (`JointSeries.width/height` är bildens, inte rutans), så
  cm per px (M2, ur kroppens längd i px) och varje mått i px räknas som utan
  utsnitt. Det utsnittet ändrar är vad Vision ser: spelaren större i modellens
  indata och grannen utanför. Hur mycket det flyttar lederna mäts i S3
  (Vision mot MediaPipe). **räkning.**
- **Leder utanför rutan** (Vision kan gissa en led utanför det den såg, och en
  hand kan lämna rutan efter träffen) sparas som **saknade**: analysen ger bara
  leder inom rutan. Personvalet i första rutan (MS8) tar den vars höfter ligger
  närmast **rutans** mitt i x. **antagande.**
- **Ändras fönstret eller utsnittet** görs seriens slag om: lederna, klippet och
  domen tas bort (inte Johannes egen dom), slag utanför fönstret försvinner (id:t
  ges aldrig igen, MS12), filerna i `Leder/` och `Klipp/` tas bort och passet blir
  inspelat igen, så att Analyze gör om det som saknas. **räkning.**
- **Bufferten och den upprätta bilden.** En normaliserad punkt (s, t) i den
  lagrade bufferten (origo uppe till vänster) blir i den upprätta bilden
  (1 − t, s) för EXIF 6, (t, 1 − s) för 8, (1 − s, 1 − t) för 3 och (s, t) för 1
  (`Orientation.upright`, `uprightRect`; samma som `preferredTransform`
  (0, 1, −1, 0, h, 0) gör med pixlarna). **vedertagen avbildning**; **mätt** i
  simulatorprovet: en vit ruta uppe till vänster i en påhittad films buffert
  ligger där i den upprätta bilden (uppe till höger), inte där EXIF 8 eller
  ingen vridning hade lagt den.
- **Granskningen och miniatyrerna** visar rutan: bilden skärs till utsnittet
  (avrundat utåt till hela pixlar, samma i Python `utsnitt_px`) och linjerna
  ritas i rutans koordinater.
- **Paketet** bär `fonster` och `utsnitt` per serie (docs/FORMAT.md), så att
  PC:n kan låta MediaPipe se samma ruta och föra punkterna tillbaka med
  `fran_utsnittet` (origo uppe till vänster, som MediaPipe).
- **Vad som provas var.** Linux (`RedigeringTests`, `test_paket.py`):
  handtagen, rutans flytt, nyp och hörn, Visions region och punkter tillbaka,
  leder utanför rutan, bufferten, klicken utanför fönstret, analysens fönster,
  att slagen görs om, pass.json och manifestets fält. Simulatorn
  (`SwingLabProvRedigering`): markören, att redigeringen sparas och överlever en
  omstart, klicket utanför fönstret, att appens Vision-körning ger Vision den
  utskurna rutan (en markör i filen hamnar rätt i den, med y vänt rätt, och utan
  utsnitt går bufferten som förut), påhittade leder genom rutan och tillbaka, miniatyren i
  rutan och bilderna av redigeraren. **Visions leder i rutan provas bara på
  telefonen.**

## MS14 — Måtten på telefonen (S4b)

- **Lederna till en sving.** Efter det täta passet görs slagets leder (de avrundade, som
  i `Leder/` och paketet) om till en sving i S1:s form (docs/FORMAT.md) och mäts med
  `Matt.mat` (M1–M29): rutornas tid relativt klicket, en saknad led som `[0, 0, 0]`
  (konfidens 0, räknas som saknad, M1), träffen relativt klicket (`impact − klick`,
  MS6) som `t_klick`, vyn och spelhanden ur uppställningen och kamerans riktning som
  standarden för spelhanden. Samma väg som PC:ns `paket.till_sving` (MT1), så att
  telefonen och PC:n ger samma tal på samma slag (BESLUT B12); provat mot filformatet
  (`MatningTests`). **räkning.**
- **Längden** (skalan, M2) är Johannes egen, passets (`PassState.heightM`, sedan S4c:
  tagen från Jag när passet skapas, valbar 140–210 cm i Jag och i passet, MS16). Saknas
  den mäts med **1,80 m** och skalan märks antagen ("assumed") i passet, i stället för
  att stoppa som PC:n gör (MT1): måtten i cm skalar med längden (±5 cm i längd ≈ ±3 % i
  varje cm-mått), vinklarna och tempot inte. **antagande** (en genomsnittlig vuxen man;
  ingen källa). En ny längd i passet mäter om det passets slag när det öppnas.
- **Vilka slag som räknas** i passets mått: domen sving eller osäker (MT1), mätt, och
  inte märkt "Detection wrong" (BESLUT B35). Ett slag som inte går att mäta (händerna
  syns inte före träffen, eller skalans segment syns inte i adressen) räknas inte och
  märks i listan. **räkning.**
- **Passet** visar katalogens mått med sessionen (M25), den egna baslinjen (M27) och
  "vs" förra passet (M26), där de tidigare passen är de med **samma klubba och samma
  vy** (kameran på samma plats, research 1 del 4). **antagande.** Under tre svingar
  (M25:s gräns) visar kortet ändå medianen av de som finns, utan spridning, utan "vs"
  och utan förra passets streck, så att ett pass med ett slag inte står tomt efter
  Analyze. Sessionens sammanfattning och bedömningen ändras inte. **antagande.**
- **Samma längd i jämförelsen.** När passet öppnas mäts det och de tidigare passen
  (samma klubba och vy) med var sin egen längd (MS16), utanför huvudtråden, och de som
  ändrades sparas. Baslinjen och "vs" tar bara pass mätta med **samma längd** som
  passet, så att ett mått i cm aldrig jämförs mellan två skalor. Ett tidigare pass som
  ändå saknar mått (inga leder) eller har en annan längd faller inte bort tyst: passet
  visar antalet ("2 earlier not measured"). **räkning.**
- **Spannets minsta bredd:** axeln rymmer minst fyra steg på måttets sista decimal
  (0,4 cm eller grader, 0,04 för tempot), så att ett mått med samma värde i alla slag
  inte får en axel med samma tal i båda ändar. **räkning.**
- **Ändras fönstret eller utsnittet** (MS13) tas måtten och märkningen bort med
  lederna.
- **Mätningens version** (`ShotMeasuring.version`, **2** sedan starten bakifrån ur
  posen, M40, **3** sedan M41–M43, nedsvingens tid utan starten och spridningen, S1e): ett slag mätt med en äldre (`version` saknas = 1) mäts om när passet
  öppnas, som vid en ny längd. Jämförelsen är `<`, så att en nyare version aldrig mäts
  om med en äldre app. **räkning.**
- **Vad som provas var.** Linux (`MatningTests`): samma mått och positioner som S1 på
  samma sving, samma sving som filformatet, längden och den antagna skalan, slag som
  inte går att mäta, passets median med och utan "Detection wrong", omätningen, gamla
  filer och de tidigare passen. Simulatorn (`SwingLabProvGranskning`): analysen med
  påhittade leder ger måtten i passet, och "Detection wrong" tar bort slaget ur dem.

## MS15 — Granskningen av ett slag: videon och lederna (S4b)

- **Videon** är seriens fil (eller klippet när originalet är borttaget, BESLUT B26,
  med klicket mätt i klippet, MS12), skuren till utsnittet på hela pixlar (MS13).
  **Rutnätet** är slagets egna rutor (lederna har en ruta per videobild i det täta
  fönstret, med bildens egen tid): ett steg är en ruta, en position (M28) visar rutan
  närmast positionens tid. Uppspelningen går i **1/8** fart: 240 bilder/s blir 30 per
  sekund. **antagande** (läsbart med ögat).
- **Lederna följer bilden ruta för ruta.** En videoruta visas från sin tid till nästa,
  så lederna är rutan med den **senaste tiden ≤ spelarens tid** (golv, inte närmaste),
  med 0,5 ms för avrundningen av tiderna (0,1 ms i `Leder/`). Spelarens tid läses var
  **1/240 s**. Ett steg, en position eller en paus söker exakt till rutans tid **plus en
  fjärdedels ruta** (1/960 s), så att spelaren visar just den rutan; efter uppspelning
  söks pausen till rutan spelaren stod på. **räkning.**
- **Klippläget** (originalet borttaget, BESLUT B26): klippets tid räknas ur klicket mätt
  i ljudet (MS12), som ligger inom en till två rutor från bildens tid (passthrough-klippet
  börjar inte exakt där det begärdes). Lederna kan då ligga **upp till ~2 rutor** fel mot
  bilden; med originalet kvar är de på samma ruta. **mätt** (MS12: klicket i klippet
  0,44 ms före det väntade på den påhittade filmen), **antagande** (telefonens klipp).
- **Lederna** ritas som Vision gav dem i rutan, inte utjämnade (M3): granskningen ska
  visa vad Vision såg. Fylld punkt vid konfidens **≥ 0,3** (leden mäts, M1), ihålig
  vid **0,1–0,3** (Vision räknar den säker, MS8, men måtten räknar den som saknad),
  ingen under 0,1. Linjerna är axellinjen, höftlinjen, armarna och benen, streckade när
  en ände är ihålig; näsan är huvudpunkten. Ingen bål och ingen kropp (BESLUT B13).
  **räkning.**
- **Koordinaterna:** en led (x, y) i hela den upprätta bildens pixlar blir
  ((x/B − x₀)/b, (y/H − y₀)/h) i ytan, med (x₀, y₀, b, h) utsnittet på hela pixlar,
  samma ruta som bilden skärs till. Provat i simulatorn med en markör i en påhittad
  film: markören i bilden och leden på markörens koordinat hamnar på samma punkt i
  ytan, med och utan utsnitt.
- **Måtten under videon** är slagets (inte passets median) vid den valda positionen,
  ur katalogens `positioner` och `matt` i slagets vy (M29), med katalogens gräns
  eller den egna baslinjen ur de tidigare passen (MS14).

## MS16 — Flikarna: vilka pass och vilken längd (S4c)

- **Passets längd.** Jag (`AppSettings.heightM`) är standarden för **nya** pass: den
  skrivs in i passet när det skapas (`PassState.heightM`), och passet mäts med sin egen
  längd. En ny längd i Me rör inga gamla pass; en ny längd i passet mäter om bara det
  passet. pass.json bär alltid längden (`null` när den är antagen). Ett pass vars fil
  saknar nyckeln (från före S4c) tar längden som slagen mättes med, så att dess tal står kvar; utan mätta slag
  tar det Me:s längd när det läses, som före S4c. Paketet bär passets längd som
  `spelarens_langd_m`, så att PC:n mäter med samma skala (BESLUT B12); antagen står den
  inte med. **antagande** (Johannes beslut i uppdraget: "passet behåller sin").
- **Idag** visar det **senaste passet med slag som räknas** (MS14), mot de tidigare med
  samma klubba, vy och längd (baslinjen och "vs" som i passet). Ett pass som inte är
  analyserat än syns inte på Idag men i Sessions. **räkning.**
- **Utveckling** tar passen med **samma klubba och samma längd som det senaste** (samma
  regel som baslinjen i MS14), äldst först; varje mått tar själv passen med sin vy (ett
  FO-mått har bara FO-passens svingar). Pass med samma klubba som inte kom med räknas var
  för sig: "1 not measured" (inga slag som räknas) och "2 at another height". Ett pass med
  en annan klubba hör inte hit och räknas inte (research 1 del 4: klubban ändrar svingen).
  Per pass visas medianen (M25) med **spridningen** som en stapel från första till tredje
  kvartilen, serie 1:s median (MT2) och gränsen eller den egna baslinjen (M27). Den egna
  baslinjen tas ur passen **före måttets sista punkt**, och perioden ovanför ("7i · Nov–Jan
  · 6") räknar måttets pass, så att ett DTL-pass sist inte ändrar ett FO-mått. Ett pass
  med färre än tre svingar i ett mått ger ingen punkt (M25). **antagande** (klubban),
  **räkning**.
- **Att jobba på** är `Store.focus` (S2f): den senaste hämtade filen i `AttJobbaPa/`
  (passets id är tiden, så det högsta namnet vinner, `FocusInbox`). Fokus på Today, Att
  jobba på och accenten kommer ur den. **Blocken** i Utveckling (B1, B2 …) är `block.start` för den första
  saken i **alla** hämtade filer (`FocusInbox.readAll`; en fil som inte går igenom
  kontrollen hoppas över), utan dubbletter (MT10); ett block som började före det första
  passet ritas inte. **räkning.**
- **Utanför huvudtråden:** flikarna läser passen (`Store.reading`), mäter dem
  (`Store.measuring`), läser filerna och räknar vyerna i en `Task.detached`; bara de pass
  som fick nya mått sparas på huvudtråden.
- **Accenten** (BESLUT B31) är felen i den senaste filen (`saker[].fel`): deras rad på
  Idag, kort i Passet, linje i Utveckling och rad under granskningens video. Utan fil
  syns ingen accent. Utveckling väljer först det som övas.
- **Vad som provas var.** Linux (`FlikarTests`, `VisningTests`): passets längd och den
  gamla filen, Jags klubbor och spelhand, vilka pass Idag och Utveckling tar, spridningen,
  filerna och blocken. Simulatorn (`SwingLabProvFlikar`): åtta påhittade pass i appens
  Store mäts med appens egen väg, två påhittade filer, flikarna ritas med talen, accenten
  bara på det som övas, och en ny längd i Jag rör inga gamla pass.

## MS17 — Lodlinjen på telefonen (S6b)

- **Proven:** `CMDeviceMotion.gravity` (CoreMotions skattning av gravitationen ur
  accelerometern och gyrot, i g, enhetens ram: x åt höger i stående, y mot skärmens
  överkant, z ut ur skärmen) var **1/30 s** från seriens start till filen är klar
  (App/Motion.swift). Tiden är `CMLogItem.timestamp` på värdklockan, samma som seriens
  `startHost` (BESLUT B19), så att provets tid i filen är `host − startHost`.
  **tillverkare** (Apples CoreMotion), **antagande** (takten: 30 prov i fönstret nedan,
  och klockan). Inspelaren delas i appen: varje serie får en token, och bara den senaste
  serien stoppar den och får proven.
- **Tillåtelsen:** Apples dokumentation visar `CMMotionManager.authorizationStatus` från
  iOS 27.2, och sidan för `NSMotionUsageDescription` varnar för att appen kraschar utan
  nyckeln. Nyckeln står därför i project.yml. **tillverkare, inte bekräftat i original,
  oprövat på iOS 27.2.**
- **Trasiga prov slängs:** tal som inte är ändliga och en längd utanför **0,5–1,5 g**
  (gravitationen har längden 1). Spridningen är därför alltid ändlig, och `pass.json` går
  att spara. **antagande.**
- **Medianen** per axel över **1,0 s** före seriens första klick (stativet står still och
  ingen har rört telefonen sedan starten), med minst **10** giltiga prov. Den gäller bara
  när varje stillastående sekund i serien ligger inom spärren från den: stöts stativet
  efter första klicket blir det `oenig` och inget fält. Är fönstret inte stilla, saknas
  klicket eller värdklockan: seriens **stillastående sekunder** (sekunden från första
  provet, var och en med minst 10 prov och stilla), när varje sekunds median ligger inom
  spärren från deras gemensamma median. **antagande.**
- **Spridningen** är **95:e percentilen** (närmaste rang) av vinkeln mellan proven och
  medianen, så att ett ensamt prov (en skakning vid träffen) inte fäller fönstret.
  **antagande.**
- **Spärren:** spridningen över **1,0°** är rörelse, och två stilla fönster vars medianer
  skiljer mer än 1,0° är oeniga. Felbudgeten ger 0,5–3° fel i lodlinjen under slumpfelet
  (S6_FELBUDGET §6.5), så 1° är en telefon som vrider sig, inte brus. **antagande**
  (kalibreras på telefonen: `spread` står i `pass.json`).
- **Skälen** i `pass.json` (`basis`): `fore_klicket` och `stilla` ger fältet; `oenig`
  (stilla men oeniga), `rorelse` (inget fönster stilla) och `for_fa_prov` (inget fönster med
  10 giltiga prov) ger inget, och PC:n tar kamerornas vågräta (MK3).
- **Klockan syns:** `beforeClickSamples` (proven i sekunden före klicket) och
  `firstSampleOffset` (första provets tid i filen, `t0 − startHost`) sparas. En serie med
  prov men ett tomt fönster, eller en förskjutning på sekunder, är ett klockfel som
  telefonprovet avgör.
- **Kamerans ram** (docs/FORMAT.md): uppåt = −gravitationen. Bakre kamerans lagrade bild
  (EXIF 1) är sensorns liggande bild med telefonens överkant åt vänster: höger = −y,
  ned = −x, framåt ur linsen = −z i enhetens ram. Filens EXIF-orientering (MS7) vrider
  den till den upprätta bilden: 6 (stående, appens läge) 90° medurs, 3 ett halvt varv,
  8 90° moturs. En rak stående telefon ger `[0, -1, 0]`. **standard** (CoreMotions och
  AVFoundations ramar), prövad åt båda håll med påhittade telefoner i stående och
  liggande (`tools/tests/fixturer/lodlinje.json`: `LodlinjeTests.swift` och
  `test_lodlinje.py` mot `paket.lodlinjen`). **Oprövad på telefonen.**
- **Fältet skrivs** med fyra decimaler (0,006°) bara när PC:ns formkontroll tar det
  (längden 0,8–1,2 g och y < 0, MK3) och uppåt lutar högst **45°** från bildens överkant.
  Mer är en telefon som stod i en annan orientering än filens (liggande i en stående fil),
  där lederna inte heller står upp (MS7). **räkning** (45° är gränsen mellan två
  orienteringar).
- **Vad som provas var.** Linux (`LodlinjeTests`): ramen i fyra orienteringar, medianen,
  fönstret och dess enighet med serien, percentilen, skälen, klockans fält, trasiga prov,
  manifestet med och utan fältet och ett gammalt pass. Simulatorn (`SwingLabProvPaket`,
  ingen rörelse): ett pass utan lodlinje paketeras och läses av PC:n, och injicerade prov
  skrivs rätt och läses av `paket.py`. Telefonen: att `gravity` och tiden är det som
  antas här, spridningen på stativet, och tillåtelsen på iOS 27.2.

## MS18 — Knapparna för Claude-appen (S5b-2)

- **Passet:** i passets skärm passet som visas, på Today det senaste passet (`PassHistory.latest`).
  Raden visas bara när passet har ett mätt slag, och den är spärrad under Analyze och medan ett
  paket skrivs. Passet och de tidigare passen med samma klubba, vy och längd mäts som i passets
  skärm (`PassMeasures`, MS14), och `ClaudeKontext` bygger underlaget (MT11) utanför
  huvudtråden. Ett jobb gäller passet det startades för: byts passet eller försvinner raden
  avbryts det, och inget skrivs till urklippet eller raden efteråt. **räkning.**
- **Urklippet:** texten läggs bara på telefonen (`localOnly`, inte Universal Clipboard till
  Macen) och går ut efter **600 s**. Efter "Use" töms urklippet, om `changeCount` visar att det
  fortfarande är Claudes svar. **antagande** (tio minuter räcker för att klistra in i
  Claude-appen; texten bär mätningar, Dataregeln).
- **"Paste from Claude"** bygger underlaget för samma pass igen och kontrollerar svaret mot det
  (MT12). Minnet tas före passets val, så en fil som redan finns för passet ändrar inte
  kontrollen. Har passet redan en fil (`AttJobbaPa/att_jobba_pa-<pass>.json`) frågar bladet
  innan den skrivs över ("Replace", "Cancel"). Focus är filen med det högsta pass-id:t (B36):
  ett svar för ett äldre pass sparas ("Save"), och bladet säger att Focus är kvar. **räkning.**
- **"Copied"** står kvar i **3 s**; "Open Claude" står kvar tills "Paste from Claude" trycks
  eller passet byts. VoiceOver läser upp "Copied" och felraden. **antagande** (det ska hinna
  läsas, utan att bli en ruta som måste stängas).
- **Felraden:** det första felet (fältet och kodens text, BESLUT B54) och antalet fel till
  ("+2"); ett tryck visar alla, och texten går att markera. En okänd nyckel är Claudes text och
  kortas till **24** tecken. **antagande** (en rad, B13; det första felet räcker för att säga
  vad Claude ska rätta; 24 tecken rymmer fältets namn bredvid).

## MS19 — 3D mellan telefonerna och i vyerna (S6c-2)

- **Bunten** (`SlagBunt`, BESLUT B61): manifestet, enhet.json och par.json som text, och lederna
  per slag: tiderna som int32 i 1e-4 s, x och y som int16 i 0,1 px (int32 när ett tal inte ryms,
  t.ex. en 4K-bild) och konfidensen som uint16 i 0,001, little endian i base64. Stegen är
  ledfilens egna (`JointSeries.rounded`, MS12), och talen läses tillbaka som n · steg, så att
  TreD får exakt ledfilens tal. En led med konfidensen 0 efter avrundningen, eller med ett tal som
  inte är ändligt, skickas som saknad: båda räknas som saknade i 3D (MK2) och 2D (M1). Rutans
  `pts` och observationens konfidens följer inte med. **räkning.**
- **Storleken:** 4 + 13 · 6 = 82 byte per ruta, i base64 cirka 109 byte. Det täta fönstret är
  4 s (MS5), högst 960 rutor i 240 Hz: cirka **105 kB per slag** i bunten, och med base64 igen i
  bitarna cirka **140 kB per slag** på kopplingen; ett pass om 20 slag cirka **2,1 MB** i
  bunten och **2,8 MB** på kopplingen (15 bitar). Ledfilerna som JSON är cirka 4 gånger större.
  **räkning** (prövad i `OverforingTests.testStorlekenPerSlag`). Uppmätt i simulatorn på det
  påhittade passet (cirka 2 s leder per slag): 11 slag 608 kB (55 kB per slag) i 4 bitar, 0,03 s
  över loopback, och 2,1 s med ett tapp om 2 s mitt i; `tre_d.json` tillbaka 7,8 kB.
- **Bitarna** (`part`, version 1): **192 kB** per bit (cirka 262 kB som meddelande i base64,
  under ramens 1 MB), id = innehållets summa (CRC-32 och längden). Varje bit kvitteras. När
  alla bitar kommit fogas de ihop och summan prövas utanför huvudtråden: fel summa ger
  `ok: false` och allt skickas igen. Helheten kvitteras först när den är sparad; misslyckas
  sparningen kommer ingen kvittens, och allt kommer igen vid nästa koppling. **Allt som inte
  kvitterats hela skickas igen från början varje gång den andra telefonen säger hello**: den kan
  ha startats om och tappat det den hade, och mottagaren slänger dubbletter. En bit för en
  överföring som mottagaren inte känner, och som inte är den första, ger `ok: false` (börja om).
  En bit med fel antal för storleken, ett index utanför eller större än taket läses inte; en bit
  vars antal eller storlek skiljer från den pågående börjar en ny överföring. **räkning.**
- **Nej med skäl:** `ok: false` med `fel` stryker överföringen, och följaren slutar skicka och
  visar en grå rad: `pass` (den styrande har ett annat pass: "Other phone has another session –
  Import"), `version` (en annan version av bitarna) och `format` (innehållet går inte att läsa,
  eller ett slag som inte tas emot): "Other phone has another app version – Import". Under
  överföringen "Waiting for other phone", efter kvittensen "Sent". **räkning.**
- **Syftet, förmågorna och partnern:** hello bär `mode` (`record` eller `pass`) och `caps`
  (`part1`). Passets koppling (`pass`) kopplar bara till en telefon med samma syfte, så att FO:s
  passvy inte hamnar i DTL:s inspelning; den andra stängs och nästa tjänst prövas. Bitar skickas
  bara till en telefon med `part1`, och en okänd meddelandetyp hoppas över i stället för att
  stänga förbindelsen. Telefonens id är stabilt per installation (ett slumptal i appens
  inställningar), och passets koppling tar bara den telefon som passet parades med vid
  inspelningen (`partner.json` i passets mapp, eller följaren i `foljare.json`); ett äldre pass
  utan känd partner tar vilken som helst med samma pass. **räkning.**
- **Taket:** den styrande tar bara emot `slag`, följaren bara `tre_d`; en överföring i taget per
  telefon och slag, högst **48 MB** för slagen och **2 MB** för 3D, och högst **4** följare
  samtidigt. **antagande** (ett pass om 60 slag är cirka 7 MB).
- **Vem som räknar:** den telefon som har den andra telefonens bunt (den styrande, eller den som
  importerade) räknar när passets alla slag är analyserade (`tre_d.json`:s `kallor` bär buntarnas
  summor). Följaren skickar sin bunt tills den styrande kvitterat just den summan. **räkning.**
- **Importen:** en zip med samma vy som telefonen tas inte emot; en zip från ett annat pass ger
  "Other phone's package is from another session" och en från en annan dag "… another day", i
  grått, men importeras (pass-id:t skiljer när kopplingen aldrig fanns). **räkning.**
- **2D-faserna på telefonen:** start och topp per slag ur `Matt.mat` på slagets leder, med
  domen sving eller osaker och inte Detection wrong, träffen ur manifestet (`traff_s − klick_s`,
  annars avståndet, MT1) och längden ur den räknande telefonens pass, annars DTL-paketets,
  annars 1,80 m (PC:n: det första paketets). Samma som PC:ns `analys.mat_paket` (B12); prövat mot
  fixturernas faser inom 1e-9 s (`TreDTelefonTests`). **Längden påverkar inte faserna** (den ger
  bara skalan i cm; prövat med 1,55 och 1,95 m, `testFasernaBerorInteAvLangden`), så telefonens och
  PC:ns längd får skilja utan att 3D gör det. **räkning.**
- **Bara en räkning gäller:** den styrandes fil är facit. En telefon räknar om bara när ingen fil
  finns, när dess egen bunt ändrats, eller när den själv räknade och den andra buntens summa
  ändrats; en fil som den andra telefonen räknat på de här slagen behålls. Bunten byggs en gång
  per ändring av passet, inte vid varje omladdning, och följaren skickar en summa bara en gång per
  koppling tills den kvitterats. Räkningen avbryts när passet stängs (`Task.isCancelled` mellan
  uppställningarna och kalibreringens varv), och ett avbrutet resultat sparas inte. En fil som
  inte gäller passets slag nu visar inga tal, bara "Updating…", och följer inte med paketet.
  **räkning.**
- **Kortet** (B62): passets median per mått bara med minst **10** svingar (MK7); skillnaden mot
  förra passet med 3D (samma klubba, vy och längd) i grader med en decimal, tydlig när den är
  större än förra passets spridning och golvet (MK7). Skälen i kortet: varför 3D hoppades över
  (inga parade slag, kamerorna gick inte att placera, inte ett DTL- och ett FO-paket, den andra
  telefonens data, annars "3D not computed"), en uppställning som inte mättes, vinkeln mellan
  kamerorna, lodlinjen som inte användes, och slagen som lämnades utanför (`utelamnade` och slag
  med `fel`). **räkning.**
- **Felbandet i Progress:** ± passmedianens SD för kedjan med typiskt brus (S6_FELBUDGET §6.7, MK7:
  golvet / √2): bäckenet **11,1°**, bröstet **9,7°**, X-factor **13,6°**, stretchen **5,7°**,
  höfterna **6,0°**. **antagande** (påhittat brus, tills S3 mätt posemodellens fel).
- **Lutningen i uppställningen:** `CMDeviceMotion.gravity` var 0,1 s medan inspelningen är
  öppen, vriden till kamerans ram som lodlinjen (MS17, EXIF 6). Linjen och talet är lutningen
  åt sidan, atan2(uppåt x, −uppåt y), eftersom den gör kamerornas vågräta fel (MK3); framåt och
  bakåt spelar ingen roll där. "Tilt too large for 3D" när vinkeln mellan uppåt och bildens
  överkant är över **45°** (MS17: då skrivs inget fält). Ett prov utanför 0,5–1,5 g visas inte.
  **standard** (ramarna), **räkning.**
- **Vad som provas var.** Linux: bunten, bitarna, tappen och kvittenserna (`OverforingTests`),
  lutningen (`LutningTests`), faserna och telefonens väg mot Pythons tal (`TreDTelefonTests`),
  kortet och katalogen. Simulatorn (`SwingLabProvTreD`): två telefoner över loopback som för
  över ett påhittat pass, 3D mot Pythons fixtur inom 0,05° per slag, tiden, och bilderna av
  kortet, Progress och lutningen. Telefonen: Bonjour, tiden på en iPhone och riktiga leder.

---

# Tolkningen (S5)

Konstanterna i PC-länken (`tools/pc/paket.py`, `analys.py`, `historik.py`,
`att_jobba_pa.py`, `kontaktark.py`) och reglerna som skillen `svinganalys`
tolkar efter. Numreringen MT hålls skild från M (mätningen) och MS
(inspelningen), så att grenarna inte krockar. Tolkningen räknar inget själv
(BESLUT B2): varje tal och varje "klart när" kommer ur analysen.

## MS20 — Sessionslistan och vyn i sessionen (S4e)

- **Raden** (`Sessionsrad`, BESLUT B64) byggs ur passets pass.json, läst och mätt med passets
  egen längd utanför huvudtråden (`Store.reading`, `Store.measuring`, som flikarna i MS16).
  **Ordningen:** skapad senast först, vid lika tid högst id. **Vyn:** uppställningens
  (`setup.view`), utskriven. **Tiden:** dagen och klockslaget i svensk tid (`Tal.kalender`, som
  datumen i M26). **Klubban:** seriernas klubbor i ordning utan dubbletter, uppställningens när
  passet saknar serier. **Svingarna:** samma regel som sessionens rad ("7i · 8"):
  `countedSwings.count`, alltså sving eller osäker, mätt och inte "Detection wrong" (MS14, B35),
  och bara när analysen är klar (`ShotPlan.next == nil`, då Analyze försvinner); före dess "Not
  analyzed"; 0 för ett pass utan klick. **Paired:** rollen är styr eller följ (B21). **räkning.**
- **Vyn i sessionen** (`Vyfilter`): ett fel, mått eller spridningsmått visas när katalogens `vy`
  är sessionens eller "bada". Passets kort (`Passvisning.kort(i:)`) och granskningens rader per
  position (`Positionsmatt`, M29) går genom samma regel. **räkning.**
- **Raderingen** (`Store.deletePass`) tar passets mapp och `Export/swinglab-<pass>-<dtl|fo>.zip`,
  sedan raden i indexet. `AttJobbaPa/att_jobba_pa-<pass>.json` ligger kvar (B64). Ett pass som
  spelas in eller importeras (`Store.inFlow`) eller vars paket skrivs tas inte bort. Ett raderat
  id står i `Store.deleted`, och `write`, `writeJoints`, `saveFollower`, `savePair`,
  `savePartner`, `saveOtherPhone` och `saveTreD` vägrar det tills ett nytt pass tar id:t.
- **Vad som provas var.** Linux (`SessionerTests`): raderna (ordningen, vyn, tiden, klubborna,
  svingarna med "Detection wrong" och ett halvanalyserat pass, paret och VoiceOver-raden) och
  filtret per vy för katalogens alla fel och för positionerna P1–P10. Simulatorn
  (`SwingLabProvSessioner`): fyra påhittade pass i appens Store, listan ur ett riktigt fönster,
  frågan (också med felet), en FO- och en DTL-session med 3D-kortet, raderingens filer, att det
  raderade passet inte skrivs igen, och Me.

## MT1 — Paketet till svingar

- Varje slag i paketet (S2_SPEC §8.3, docs/FORMAT.md "Paketet") blir en sving i
  filformatet och mäts med M1–M24 oförändrade.
- **Träffen** i lederna tidsskala (s relativt klicket) = `traff_s − klick_s` ur
  manifestet; saknas `traff_s`: −avstånd / 343 m/s (MS6); saknas avståndet: 0
  (klicket). **fysik** (MS6).
- En led som är `null` (Visions konfidens 0) får konfidensen 0 och räknas som
  saknad (M1).
- **Domarna:** `sving` och `osaker` mäts (S2_SPEC §4.3: osäkra behålls men
  märks), `inte_sving` utelämnas. **antagande.**
- **"Detection wrong":** ett slag med `detection_wrong: true` (Johannes märkte på
  telefonen att lederna är fel, BESLUT B35) utelämnas som `inte_sving`, så att telefonen och
  PC:n räknar på samma slag (BESLUT B12). **räkning.**
- `avstand_m` godtas mellan **0,5** och **20** m. **antagande** (rimlighet, ett
  fält utanför är fel).
- **Spelarens längd** (skalan, M2): `--langd`, annars `spelarens_langd_m` i
  manifestet, annars den sparade i historiken (`spelare.json`). Utan längd stoppar
  analysen hellre än gissar.

## MT2 — Första serien

- "Klart när" mäts på **första serien**, före uppvärmningen (research 3 (a) 7 och
  §4: retention nästa pass, inte slutet av samma pass). **forskning, ej läst i
  original** (retention), **antagande** (formen).
- Första serien = de **5** första mätta slagen i serie 1 (design/README.md öppna
  val 4: 5 slag före uppvärmningen). Har serie 1 färre är det alla dess mätta
  slag. **antagande.**
- Första seriens median sammanfattas som passet (M25, minst 3 slag).

## MT3 — "Klart när"-förslaget

- Analysen föreslår villkoret för varje aktivt fel, och Claude skriver av det
  när en övning väljs:
  - **Med gräns** i katalogen: det gröna spannet (`>=` nedre, `<=` övre eller
    `mellan`), märkt **B10** när gränsen inte är kontrollerad.
  - **Med egen baslinje** (M27): gränsen för grönt, baslinjens median ±
    1 robust sd åt det håll `samre` anger, märkt **egen**.
  - **Utan baslinje** (färre än 8 svingar, M27): **en** robust sd (M26) åt det
    bättre hållet från passets median, märkt **egen**. Kräver `samre`.
    **antagande:** en spridning är den minsta flytt som M26 kallar tydlig.
- **Gränsen flyttar sig inte** så länge samma övning fortsätter: kontrollen
  kräver gränsen och märkningen från passet då övningen valdes, och historiken
  bedömer varje senare pass mot den. En ny övning för samma fel får analysens
  förslag igen.
- Talen avrundas till **0,1** (cm, grader, handens fart i m/s), **0,01**
  (tempo, stansen, sekunder) och **1** (vinkelfarten i °/s och tiden i ms,
  M35–M37), samma tal som appen visar. **antagande.** Avrundningen är Pythons `round()`:
  det exakta binära talet, en exakt halva till jämnt (0,35 → 0,3, 0,25 → 0,2); Swift gör
  samma sak med printf (`Avrundning.pyRound`). **räkning.**
- Gränserna är slutna.

## MT4 — Rörelsen

- Övningens start = första seriens median (MT2) i passet då övningen valdes,
  annars passets median. Felets start = samma sak i passet då **felet** först
  valdes (blockets start, MT10).
- Rörelsen i ett senare pass = första seriens median − starten, åt det håll
  villkoret pekar (för `mellan`: närmare spannets mitt).
- **Tydlig** när rörelsen är större än startpassets robusta sd (M26).
  **antagande**, samma konservativa mått som jämförelsen mot förra passet.

## MT5 — Läget för en övning, och treregeln

Läget räknas i den här ordningen; det första som stämmer gäller.

- **Avslutad** när felet inte står i det senaste valet (klart och släppt, eller
  bortvalt). En avslutad övning väcks aldrig; väljs felet igen börjar ett nytt
  block.
- **Klart** när "klart när" hålls på första serien **2** pass i rad
  (`pass_i_rad`, alltid 2; research 3 §4 förslag 6). **antagande.**
- **Klart** också när felet inte är flaggat (grönt) i det senaste passet efter valet
  (`klart_skal: "inte_flaggat"`, BESLUT B45). "Klart när" och märkningen är låsta från
  valet, men katalogens gräns kan flyttas (S1e flyttade swayens och early extensions),
  och ett grönt fel övas aldrig. Saken lämnar då listan och rapporteras som klar, inte
  tyst borttagen. **antagande.**
- **Fysiken:** **42** dagar (sex veckor) från första gången felet valdes, utan
  någon tydlig rörelse sedan dess över alla övningar för felet, treregeln
  inte prövad än, och ett test för felet i kedjorna → pröva treregeln (research 3 §4
  förslag 6). Ett fel utan test kommer aldrig i läget. **antagande.**
- **Spåret** (BESLUT B56): en sak följs upp, räknas och avslutas bara av pass och val med
  samma klubba, längd och vy som när den valdes (tempot: vyn som tempot togs ur, MT9).
- **Ny** när inget pass har kommit efter valet.
- **Byt övning** efter **4** pass i rad utan tydlig rörelse sedan övningen
  valdes (MT4). **antagande:** med cirka två pass i veckan är det två veckor,
  och ett block på 4–6 veckor (research 3 §4) rymmer en andra övning.
- Annars **fortsätt**.
- **Treregeln** (research 3 §5): (1) felet syns i full sving, (2) ett kopplat test
  i `tools/pc/kedjor.json` fallerar, (3) rörelsen går inte heller långsamt utan
  klubba. Alla tre → "troligen rörlighet" (rörlighetsövning, testa om efter
  några veckor); 1 och 2 men inte 3 → "teknik, men kroppen gör det svårt";
  annars teknik. Svaren på 2 och 3 kommer från Johannes. **tränare/antagande,
  ej läst i original**; stödet för testen är svagt (Gulgin 2014, research 3 §5).

## MT6 — Prioriteringen

- **1–3 saker** (research 3 (a) 5: en sak att öva, högst två till att se).
  **tillverkare, ej läst i original** (18Birdies, Sportsbox).
- **Kedjorna** står i `tools/pc/kedjor.json` med källa och status, ur research 3
  §1, och läses transitivt (sway → reverse spine → early extension), så ett
  följdfel kan ligga flera led efter sin orsak. Ett fel med en flaggad orsak är
  ett **följdfel**: det mäts men får ingen egen övning, inte heller ensamt.
  **tränare/antagande, ej läst i original.**
- Ett **okänt** fel (ingen gräns, ingen baslinje) väljs bara när inget fel är
  flaggat.
- **Kandidaternas ordning** i analysen: grundorsaker före följdfel, låg
  prioritet sist (tempot, research 1 §1.9), tidigt i svingen före sent
  (`adress`, `topp`, `nedsving`, `traff`, `efter_traff`, `hela`), rött före gult,
  sedan störst |z|. **antagande** byggt på research 3 (a) 1–2.
- Valda saker står i svingens ordning; `att_jobba_pa.py` fäller annat.

## MT7 — Kontaktarket

- En bild per vy: en rad per slag (högst **12**, de första i passet), fyra
  kolumner: adressens och finishens fönsters mitt (M4), toppen och träffen.
  Rutorna är **180** px breda, med de uppmätta lederna ritade (BESLUT B13: bara
  uppmätta linjer). **antagande** (storleken: läsbar för Claude, liten fil).
- Rutorna läses med ffmpeg, annars OpenCV; utan dem hoppas arket över med en rad.

## MT8 — Texten i `att_jobba_pa.json`

- Appen visar övningen, tanken och "klart när" (design/README.md regel 5).
  **Övningen är aldrig fritext:** katalogens ordagrant, eller en av felets
  övningar ur research 3 §2 i `tools/pc/kedjor.json`.
- **Fritexten** är tanken (högst **60** tecken) och rörlighetsövningen (högst
  **200**). Den bär inga siffror (tal står bara i "klart när", där de är
  analysens), inga utropstecken och inga **värdeord** (BESLUT B13 regel 4),
  som fälls på ordstam på engelska, appens språk (BESLUT B30): ok, wow,
  ideal med flera som hela ord, frasen "well done", och ord som börjar på
  good, better, best, worse, worst, bad, poor, great, perfect, nice, excellen,
  awesome, amazing, super, cool, neat, sweet, kudos, nail, crush, pure, crisp,
  boring, fine, terribl, awful, wonderful, solid, wrong med flera (listan i
  `att_jobba_pa.py`). Undantag: badge, badminton, bestow, supinat…, coolin….
  Golfens ord går igenom (top, finish, lead, trail, grip). "strong" och "weak"
  fälls inte: ett starkt eller svagt grepp är golfens ord, inget omdöme.
  Fritexten är engelska: å, ä och ö fälls. **antagande** (gränserna);
  katalogens längsta tanke är 54 tecken.
- **Övningens id** (`ovning.id`, katalogens `ovning_id`, `id` i kedjorna):
  historiken (MT4, MT5) och kontrollen jämför övningar på id:t, så att en
  omskriven text (som översättningen, BESLUT B30) inte nollställer steget,
  "klart när" eller blocket.
- Formen är stängd: en okänd eller saknad nyckel fälls.
- **Extern fokus** i tanken: vad klubban, bollen eller ett föremål ska göra
  (research 3 (a) 6, medeleffekt ~0,54, Barzyk & Gruber 2024). **forskning, ej
  läst i original.** Går inte att fälla i kod; skillen håller regeln.

## MT9 — Tempot med två telefoner

- Gruppen `alla` (tempot och varje fel med vy `bada`) tas ur **en** vy: den
  med flest slag med tempo, FO vid lika (ett slag bakifrån utan säker start har mått
  men inget tempo, M40). Baslinjen för de felen tas ur samma vy.
  Vyerna läggs aldrig ihop: när båda telefonerna filmar är det samma svingar,
  och n blir dubbelt. **antagande**; parning slag för slag (`par` i
  manifestet) väntar.

## MT10 — Stegen och blocket

- **Stegen** inom en övning (research 3 §4 förslag 2): långsamt med föremålet →
  halv fart → full fart → varierat (`langsamt_med_foremal`, `halv_fart`,
  `full_fart`, `varierat`). En ny övning börjar på första steget; en övning som
  fortsätter står kvar eller tar nästa steg, aldrig ett hopp. **forskning, ej
  läst i original** (ökande variation, Porter & Magill 2010), **antagande**
  (stegen).
- **Blocket** (research 3 §4 förslag 1: 4–6 veckor per grundorsak) börjar den
  dag felet först valdes och fortsätter genom bytta övningar; `vecka` = hela
  veckor sedan starten + 1. **antagande.**

## MT11 — Underlaget till Claude-appen (S5b)

- Texten är rubriken, instruktionen (skillens avsnitt `claude-appen`, BESLUT B53) och
  datan som kompakt JSON i ett kodblock (BESLUT B55), räknad med samma regler som PC:n:
  analysen (M25–M27, MT2, MT3, MT6, MT9), minnet före passets val (MT4, MT5, MT10) och en
  mall per fel som går att välja.
- **Datan:** `klubba` (huvudklubban, BESLUT B56); `kandidater` som analysen; `bedomning`
  för de aktiva felen med ett tal som inte är gröna (`grund`, `z` med **1** decimal,
  `baslinje` = baslinjens median, robusta sd och svingar för ett fel utan gräns);
  `spridning` (M44) med minst ett slag; `historik` = `[visat, status]` för de senaste **6**
  passen, för fel som inte är gröna i alla; `ovningar` = minnet med uppföljningens senaste **4** rader;
  `pagaende` = den senaste filen före passet; `fil` = filens huvud med `skapad`.
  **antagande** (6 pass räcker för trenden i ett block på 4–6 veckor med två pass i
  veckan; 4 rader är `byt_ovning`-gränsen i MT5).
- **Mallen** för ett fel: de **3** första grundorsakerna bland kandidaterna som är nya, och
  varje övning som fortsätter; eller de okända felen med ett tal och förslag när inget är
  flaggat (MT6). **antagande** (MT6: helst en sak, högst tre). Ett fel vars övning är klar får ingen mall. Övningen
  som fortsätter (`ny`, `fortsatt`, `fysik`) ger minnets "klart när" och märkning, samma
  övning och stegen `[nu, nästa]`; annars analysens förslag, övningarna (katalogens och
  kedjornas) som inte provats för felet, och första steget. Blocket från minnets
  `fel_start` eller passets dag. **räkning** (kontrollens regler, MT3, MT5, MT10).
- **Storleken:** instruktionen högst **8 KiB**, datan för ett typiskt pass (två vyer, sex
  pass, en övning som fortsätter) högst **7,5 KiB**, och varje text i facit, även det värsta
  fallet, högst **24 KiB** (`test_underlag.py`, `ClaudeTests`). **antagande** (några kB,
  Johannes 2026-10-23).
- **Talen** skrivs som heltal utan decimaler, annars i kortaste form (Python `repr`,
  Swift `description`). De påhittade måtten har sex decimaler, så att ingen median hamnar
  på en avrundnings halva, där Pythons och Swifts avrundning skiljer sig (MT3).

## MT12 — Svaret från Claude-appen

- **Taket:** urklippet läses bara upp till **64 KiB** (UTF-8), och JSON bara **32** nivåer
  listor och objekt i varandra (filen har sex). **antagande** (ett svar är några kB).
- **Kodblocken:** från ``` med valfri märkning till radslutet, och till nästa ```.
  Det sista blocket som är ett JSON-objekt med `format` eller `saker` gäller; utan block
  hela texten, och det mellan första `{` och sista `}`. **räkning.**
- **Utbytena**, bara när blocket inte går att läsa som det står: “ ” „ ‟ ″ → ", hårt
  mellanslag (U+00A0, U+202F, U+2007) → mellanslag, BOM och nollbrett mellanslag bort.
  **antagande** (det telefonens skiljetecken och anteckningar byter).
- **Kontrollen** är MT3, MT5, MT6, MT8 och MT10 som på PC:n, mot passet som underlaget
  gällde. Felen är fält och kod (BESLUT B54): `for_stort`, `inget_block`, `inte_json`,
  `inte_att_jobba_pa`, och kontrollens koder. true och false är inte tal, och siffror,
  ord och blanktecken i fritexten är ASCII.
- **`skapad`:** `yyyy-MM-dd`, valfritt `THH:mm[:ss[.f]]` (högst sex decimaler) och `Z`
  eller `±HH:mm`, med giltig dag och tid. **räkning.**

---

# Två kameror (S6)

Konstanterna i kedjan från två paket till 3D (`tools/pc/tva_kameror.py`, S6a) och
facitet för den. Numreringen MK hålls skild från M, MS och MT. Simuleringen bakom
valen står i [S6_FELBUDGET.md](S6_FELBUDGET.md); talen där är påhittade svingar
med antaget 2D-brus. **Inget här är mätt på riktiga svingar än.**

## MK1 — Parningen av slagen

- Den styrande telefonens `par.json` (S2g, MS10) ger per serie följarens serie och
  `forskjutning_s`. Slagens klick paras med Golf SG:s `para()` kring den, i ett
  fönster på **± 30 ms** (samma som toleransen). **räkning** (MS10).
- **Utan `par.json`**, när raden säger `osaker`, eller för en serie den inte nämner:
  klicken paras utan förhandsvärde. Varje skillnad b − a mellan två klick prövas
  (ett slags filer kan börja hur långt isär som helst, så MS10:s ± 10 s räcker
  inte), den som parar flest inom 30 ms förfinas med `para()`, och parningen är
  osäker med färre än **3** par eller när en annan förskjutning minst 2 · 30 ms bort
  parar lika många (MS10:s regel). Serierna paras serie mot serie, flest par först.
  **antagande** (formen), **räkning**.
- `par.json` som inte går att läsa stoppar inte paketet: PC:n parar på klicken
  och skriver skälet (utan värden) i `parning.par_json_fel`.
- Bara slag som mäts i båda vyerna kommer med (domen `sving` eller `osaker`, inte
  "Detection wrong", MT1).

## MK2 — Tiden: synken på klicket

- Varje telefons leder läggs på **träffens tid**: `t − (traff_s − klick_s)`, eller
  `t + avstånd / 343` utan `traff_s` (MT1, MS6). Då står träffen på t = 0 i båda,
  och skillnaden i ljudets väg är borta. Det som är kvar är klickets fel (±7 ms,
  MS4), som MK4 tar. **fysik** (MS6).
- En led med konfidens under **0,3** är saknad (M1). Två rutor med samma tid: den
  första.

## MK3 — Kalibreringen: självkalibrering ur lederna

- **Inre parametrar, per slag ur dess egen bild:** brännvidden ur seriens
  kameraformat i manifestet (`serier[].format.synfalt`, `videoFieldOfView`:
  vågrätt över den liggande bildens långsida, som är den upprätta bildens
  långsida), f = (långsida / 2) / tan(synfält / 2); annars det valda formatet i
  `enhet.json` (`valt_index`, `fieldOfView`); annars specifikationen, **f = 1444 px**
  för 1920 px långsida (26 mm ekvivalent, S6_FELBUDGET §3). Huvudpunkten i bildens
  mitt. Ett synfält utanför **10–170°** räknas som saknat. Källan står i
  `f_kalla`. **tillverkare** (Apples `videoFieldOfView`), **antagande** (att
  stabiliseringen är av, vilket appen sätter, och att distorsionen är rättad).
  Varför: med fel brännvidd blir passets median fel utan att Sampson-felet syns
  (granskningen, utan brus: ±5 % ger 1–2,6°, −15 till +20 % ger 4–9°). ChArUco
  väntar.
- **Yttre, per uppställning:** en DTL-serie mot en FO-serie är en uppställning
  (stativen kan flyttas mellan serierna), och dess slag kalibrerar ihop. Båda
  vyerna jämnas (MK5) på en tidsaxel i steg om **1/60 s**, punktpar med konfidens
  över **0,5** i båda vyerna, normerade med varje slags K, högst **5 000** par
  (en permutation, M50). Viktad normaliserad åttapunktsmetod med robusta varv och
  förfining på Sampson-felet (Hartley 1997, `tre_d/kalibrering.py`).
  **standard** (metoden), **antagande** (talen). Skalan är okänd: vinklar behöver
  ingen.
- **Spärren:** Sampson-felets median, i px på en 1920 px långsida, över **8 px**
  ger ingen mätning för uppställningen (`hoppat` i `kalibrering[]`); hoppas alla
  över blir `tre_d.hoppat` uppställningarnas skäl när de är eniga (spärren eller
  kalibreringen själv), annars "ingen serie gick att kalibrera". På PC:n står
  parningen och uppställningarna kvar bredvid skälet (2026-10-24: ett riktigt pass
  stoppade i kalibreringen, men skälet sade spärren och resten saknades). Uppmätt på facit (10 slag): bra brus 2,9 px, typiskt
  4,7, dåligt 9,2, mycket dåligt 14,1. Spärren ligger mellan typiskt och dåligt,
  där passets median enligt felbudgeten blir 18–21° fel (§6.7). **antagande.**
- **Lodlinjen:** ur manifestet (`serier[].lodlinje`, uppåt i kamerans ram, g) när
  någon vy bär den: FO:s direkt, DTL:s vriden till FO, båda = summan. Fältet
  används bara med längden **0,8–1,2 g** (telefonen i vila på stativet) och med
  uppåt mot bildens överkant (y < 0 i kamerans ram): en vänd vektor vänder
  måtten (granskningen, utan brus: höfterna vid träffen −36° mot +36°). Ett fält
  som inte går att använda stoppar aldrig paketet: skälet (utan värden) står i
  `kalibrering[].lodlinje_fel` och i `tre_d.osaker`, och uppställningen tar
  kamerornas vågräta (BESLUT B39). **Skyddet:** vinkeln mellan manifestets uppåt och
  kamerornas vågräta skrivs i `kalibrering[].lodlinje_mot_vagrata` (mätningen som B39
  omprövas med), och över **15°** används de vågräta, med skälet i `lodlinje_fel` och
  `tre_d.osaker`. Uppmätt på facit (kamerorna utan lutning åt sidan, lodlinjen ±1°, 18
  pass utan, med bra och med typiskt brus): 0,1–1,8°. En riktig telefon lutar några grader
  på stativet, och de vågräta är då fel med ungefär lutningen; 15° är en telefon som står
  synligt snett eller ett fält i fel ram. **antagande.** Utan fältet: **kamerornas vågräta**, uppåt
  vinkelrätt mot båda bildernas x-axel. Det antar att ingen telefon lutar åt sidan
  (felet blir ungefär lutningen); felbudgeten ger 0,5–3° fel i lodlinjen under
  slumpfelet, eftersom vridningen mäts mot adressen (§6.5). **antagande.** Står
  kamerorna närmare än cirka 12° samma riktning går lodlinjen inte att få ur
  bilderna, och uppställningen hoppas över.
- **Vinkeln mellan kamerorna** (blickriktningarna i markplanet) skrivs ut, och
  utanför **60–120°**, där felbudgeten växer snabbt (§6.4), står uppställningen i
  `tre_d.osaker`.
- **Uppmätt på facit** (typiskt brus, 12 pass): kalibreringens vridningsfel är i
  snitt 5°, upp till 14°, oberoende av antalet par (1 500–20 000). Det kommer av
  posemodellens fasta avvikelse per led och vy, som är densamma hela passet och
  därför böjer epipolargeometrin. Den syns mest i bröstet: passmedianens SD 9,6°
  mot 6,4° med sanna kameror (S6_FELBUDGET §6.7). Mattan (§6.5: 0,2°) eller en
  utjämning där varje leds fasta avvikelse skattas med kamerorna är följdjobb.

## MK4 — Synken: finjusteringen på återprojektionen

- Per slag väljs den förskjutning av DTL:s tider som ger minst medianfel när
  handlederna och armbågarna trianguleras och projiceras tillbaka i nedsvingen,
  **−0,35…+0,10 s** kring träffen. Sökningen ± **10,5 ms** (1,5 × klickets ±7 ms)
  i steg om **0,5 ms**, med utjämning ±**20 ms** i sökningen, och en parabel genom
  minimum. Simuleringens metod (S6_FELBUDGET §4, §6.3: 2 ms RMS). **antagande.**
- **Två varv:** kalibrera på klicket → synka varje slag → kalibrera om med synken
  → synka igen, nu ± **3 ms** kring det första varvets värde → kalibrera en sista
  gång. **antagande.** Uppmätt på facit:
  synkens rest 0,1 ms utan brus, RMS 1,2 ms med bra brus och 2,1 ms med
  typiskt (24 pass, `tools/pc/kedjans_facit.py`, S6_FELBUDGET §6.7).

## MK5 — Trianguleringen och utjämningen

- Varje vys 2D-spår jämnas på sina egna tider med LOESS (trikubisk kärna, lokal
  andragradsregression, två bisquare-varv, MAD-golv 2 px), halvbredd **±40 ms**,
  och samplas på en gemensam tidsaxel i steg om **1/240 s**. **0,05 s** av varje
  ände av slagets tid lämnas utanför. ±40 ms är felbudgetens rekommendation
  (§6.6: stretchen 14° → 10° mot ±20 ms). **standard** (Cleveland 1979),
  **antagande** (bredden).
- DTL:s tider flyttas med synken (MK4). Lederna trianguleras med konfidensviktad DLT
  i normaliserade koordinater (Hartley & Zisserman). **standard.**
- Återprojektionens median (px) skrivs per slag som en kvalitetssignal.
- Ett slag med färre än **10** rutor i någon vy, eller på den gemensamma
  tidsaxeln, mäts inte. **antagande** (minst ett par utjämningsfönster).

## MK6 — Måtten i 3D

- Definitionerna är felbudgetens (§5, `tre_d/matt.py`): höft- och axellinjen
  projicerade på markplanet (lodlinjen, MK3), vinkeln mot adressen, positiv bort
  från målet. `backen_vrid_topp`, `brost_vrid_topp` (akromionlinjen),
  `xfaktor_topp` = bröst − bäcken vid toppen, `xfaktor_stretch` = största X i
  tidig nedsving (toppen till halva tiden mot träffen) minus X vid toppen, i
  grader, och `hofter_oppna_traff` = −bäckenet vid träffen. **standard** (Kwons
  projektion), egen tillämpning.
- **Adressen** är M4:s fönster, start −0,40…−0,10 s, med baksvingens start ur
  2D-faserna i FO (annars DTL flyttad med synken; saknas starten: toppen −1,2 s,
  M4). **Toppen** är där handledernas mitt står högst i 3D mellan starten och
  träffen. **Träffen** är t = 0 (klicket, MK2). Vinkelkurvorna jämnas ±30 ms före
  måtten (S6_FELBUDGET §6.6).
- **Inom tidsaxeln:** adressens fönster och träffen ska ligga inom slagets
  gemensamma tidsaxel, annars mäts inte slaget (`fel`). Ett värde vid en tid
  utanför vinkelkurvans värden är saknat (inte kurvans ändvärde, som
  `np.interp` annars håller fast). En lucka i en vinkelkurva fylls linjärt bara
  upp till **0,10 s** (samma gräns som M3); en längre förblir saknad.
  **antagande.**
- **Vänsterspelaren** speglas i 3D (x → −x), så att vridningen bort från målet är
  positiv för båda. Provat: en speglad påhittad sving ger samma tal inom 0,5°.
- Märkta `lage: "utan_markorer"` (BESLUT B14).

## MK7 — Passets trend

- Passets median per mått (M25) visas bara över minst **10** slag (BESLUT B14:
  per sving är felet 10–16°). Färre slag ger `n` men ingen median. **Johannes
  beslut** (B14).
- **Mot förra passet:** skillnaden i median (M26). Den är **tydlig** först när den
  är större än både förra passets spridning (M26) och ett **golv** per mått: √2 ×
  passmedianens SD för kedjan med typiskt brus (24 påhittade pass, S6_FELBUDGET
  §6.7): bäckenet **15,7°**, bröstet **13,7°**, X-factor **19,2°**, stretchen
  **8,1°**, höfterna vid träffen **8,5°**. Kamerornas läge, kalibreringen och
  posemodellens fasta avvikelse byts mellan pass, så två pass skiljer sig redan av
  det. **antagande** tills S3 mätt bruset; med "bra" brus blir golvet ungefär hälften.
- Inget 3D-mått bedöms grönt, gult eller rött, och inget blir en sak i
  `att_jobba_pa.json` (BESLUT B14, B37).

## MK8 — Facit för kedjan

- `generera_paket.tva_paket` filmar påhittade 3D-svingar (`tre_d/sving.py`,
  längden 1,80 m, adress **0,8 s** före baksvingen och **0,7 s** efter finishen så
  att M4:s fönster ryms) med en FO- och en DTL-kamera ur felbudgetens uppställning
  (3 m, 1,0 m, 90° ±5°), bildtider med 36 % tappade rutor, 2D-brus och skymning
  (§3), en fast avvikelse per led och vy för hela passet, klickets fel ±7 ms på
  DTL och bollen i (0, −0,6, 0). Följarens (FO:s) fil börjar **12,345 s** före den
  styrandes. Paketen bär `par.json` (i DTL:s paket, eller FO:s med `styr="fo"`),
  seriens synfält ur kamerornas sanna brännvidd (valfri, `f_px`, standard 1444 px)
  och, valfritt, lodlinjen med ±1° fel. En vänsterspelare filmas med
  uppställningen spegelvänd: DTL bakom spelaren. **antagande** (påhittat).
- Facit är samma mått (MK6) på de sanna lederna, med samma adress och topp.
- **Gränsen** i testerna (`tools/tests/test_tva_kameror.py`): passets median minus
  de sannas median ligger inom |bias| + 3 SD av felbudgetens passmedian (§6.7,
  raderna "Bra brus" och "Grund (typiskt brus)"), och utan brus inom 0,5° (varje
  slag inom 1°). Uppmätt för kedjan på 24 pass per nivå står i §6.7.

## MK9 — Visaren: kamerorna, figuren och skalan (S6f)

`tools/pc/visa.py` visar kedjans tal och mäter inget eget:

- **Kamerorna** per uppställning: kalibreringen räknas om med kedjans synk efter
  sista varvet (MK3, MK4), samma anrop som kedjans sista, så att läget, Sampson-felet
  och vinkeln är kedjans. En uppställning över spärren ritas ändå, med figuren
  triangulerad (MK5) och märkt "över spärren": den ger inga mått.
  Stannar kedjan i kalibreringen står kedjans skäl per uppställning (`TreDFel.delvis`),
  och figuren ritas på klicket, märkt: visaren gissar inget eget skäl ur omräkningen.
- **Figuren** är kedjans triangulerade leder på FO:s klocka (träffen = 0); DTL:s klipp
  flyttas med synken. Samma leder projiceras tillbaka i båda klippen med K · R · (X − C).
  Testet kräver att den projicerade figuren ligger inom 6 px (median) från Visions
  leder på påhittade pass med bra brus.
- **Skalan** (bara för bilden): självkalibreringen saknar skala, så världen skalas så
  att näsan över fotlederna (median över rutorna) blir **0,89** × spelarens längd
  (ögonen 0,936 och fotleden 0,039 av längden, Drillis och Contini 1966, **ej läst i
  original**). Utan figur är avståndet mellan kamerorna 1. Inget mått beror på den.
- **MediaPipe** (S3) läggs på Visions tid med S3:s förskjutning (MF1): t = tk −
  förskjutningen − `klick_i_klipp_s`; utan förskjutning 0, och sidan säger det.


## MK10 — Figuren på telefonen: lederna, kamerorna och skalan (S6d)

`TreDFigurer` (SwingLabKit) och `tools/pc/tre_d_figur.py` (facit, BESLUT B12) sparar det kedjan
redan räknar och mäter inget eget (BESLUT B72):

- **Lederna** per slag är MK5:s triangulering med uppställningens sista kalibrering och
  slagets synk (MK3, MK4): samma leder som måtten räknas ur, på tidsaxeln i steg om 1/240 s
  med träffen = 0 på FO:s klocka. De trianguleringar kedjan redan gjort återanvänds; slag
  utan faser och slag i en uppställning över spärren trianguleras för skalan. **räkning.**
- **Kamerorna** per uppställning ur kedjans sista kalibrering (`Kalibrering.varld`):
  centrum C = −Rᵀ t, R och K för uppställningens första slag. Över spärren sparas de ändå,
  men ingen figur (B72). **räkning.**
- **Skalan** (bara för bilden, inget mått beror på den): självkalibreringen saknar skala, så
  världen skalas så att benets längd, lår + smalben (höft–knä–fotled per sida, medianen över
  uppställningens alla rutor och båda sidor) blir **0,491** × spelarens längd (lår 0,245 och
  smalben 0,246 av längden, Drillis och Contini 1966, **ej läst i original**; samma källa som
  MK9 och felbudgetens påhittade kropp). Utan ben är avståndet mellan kamerorna 1
  (`skala: "kamerorna"`). Varför inte MK9:s näsa över fotlederna: den antar en upprätt
  hållning, och på facit (utan brus) blev figuren 27 % för stor, med kamerorna 4,0 m från
  höfterna i stället för 3,15 m och 1,16 m över fotlederna i stället för 0,93 m; benen gav
  3,20 m och 0,93 m. **standard** (proportionerna), **räkning.**
- **Marken** = fotledernas median (alla rutor, båda) minus fotledens höjd, **0,039** ×
  längden (samma källa, ej läst i original). Prövat på facit: kameran 1,0 m över marken inom
  5 cm, som uppställningen den filmades i (MK8). **antagande.**
- **Positionerna** P1–P10 (kroppens, M28) per slag på figurens tid: FO:s 2D-tid minus FO:s
  träff, annars DTL:s minus DTL:s träff och synken, position för position (samma regel som
  baksvingens start i MK6). P2, P6 och P8 kräver klubban och saknas. P7 är 0. **räkning.**
- **Filen:** lederna som int16 i mm (±32,767 m; ett tal utanför blir saknat, aldrig ett annat
  tal). Avrundningen är 0,5 mm, långt under trianguleringens fel. **räkning.**
- **Toleransen mot Python** (TreDFigurTests, tre påhittade pass: utan brus, bra brus med
  vänsterspelare, och över spärren): kamerorna, skalan, marken, synken, tiderna,
  positionerna och lederna inom **1e-6** (m, s eller relativt), samma antal leder och samma
  skäl. **räkning.**

## MK11 — Figurens vy: riktningarna, vinklarna och perspektivet (S6d)

Geometrin i `FigurVy.swift` (SwingLabKit, prövad på Linux), ritad av appens `TreDScen`
(BESLUT B73). Bara bilden: ingen siffra visas ur den.

- **Riktningarna ur kroppen i adressen**, rutorna fram till P1 + **0,15 s** (utan P1 slagets
  första 0,3 s), medianen per led: **mot målet** = bakre fotleden → främre (för en
  högerspelare höger → vänster), vågrätt; utan fotleder höfterna. **Framsidan** är vinkelrät
  mot den, åt det håll näsan står framför höfterna (spelaren böjer sig mot bollen); säger
  näsan mindre än 2 cm, mot FO-kameran. **Stansen** är fotledernas mitt på marken, mållinjens
  ankare. Utan figur: där telefonernas blickar möts (närmaste punkten mellan linjerna, 0,5–20 m
  framför båda), annars 3 m framför FO-kameran, och framsidan mot FO-kameran. Prövat på facit:
  FO-kameran står inom 18° från framsidan och DTL-kameran inom 18° bakom spelaren längs
  mållinjen (MK8: 90° ±5°). **antagande** (adressens fönster), **räkning.**
- **Vinklarna:** Face on ser spelaren framifrån (målet till höger på skärmen för en
  högerspelare), Down the line bakifrån längs mållinjen, båda **6°** över vågrätt; Top uppifrån,
  **89°** (vid 90° saknar vyn ett upp), med målet till höger. Vyn passas till det som ska synas
  (lederna i var sjätte ruta och stansen, med telefonerna också de och en punkt 1 m utanför
  varje telefon, bort från spelaren, där dess namn står): mitten där utbredningen åt
  sidan och i höjd har sin mitt, och det minsta avståndet där varje punkt ryms inom **90 %** av
  ytans halva bredd och **86 %** av dess halva höjd med synfältet **40°** över kortsidan, minst
  0,5 m framför ögat. En sfär kring figuren (första versionen) gjorde den till en tredjedel av
  ytan. **antagande.**
- **Fingret:** **0,008** rad per pt runt lodlinjen och i höjd, höjden **−10°…89,5°**; nypningen
  delar avståndet med faktorn, **0,5–40 m**. **antagande.**
- **Perspektivet:** en hålkamera i ögat med brännvidden (kortsidan / 2) / tan(20°). En linje
  som passerar bakom ögat klipps **0,05 m** framför det; en punkt bakom ritas inte. Strecken
  ritas det bortre först, och opaciteten faller linjärt till **0,55** för den bortersta leden i
  rutan. Halsen är ett streck från axlarnas mitt till näsan. Mållinjen (0,5 m bakåt och 3 m framåt från
  stansen) och pilen ritas bara när riktningarna kommer ur en figur. **standard** (projektionen), **antagande** (talen).
- **Spåren** (S4f:s punkter, M60) ur figurens leder: händerna med greppregeln och brott där
  den byter handled, axlarna och höfterna två serier var, huvudet näsan. Ingen ny utjämning
  (lederna är jämnade före trianguleringen, MK5). Delningen i spelat och kvar och avbrotten är
  `SparSerie`:s (M60), med index som pekar ut punkterna i 3D. **räkning.**
- **Uppspelningen:** farten 1/8 (som granskningen, MS15), 1/4 eller 1, på figurens tidsaxel;
  den stannar vid slutet och börjar om från början. **Johannes beställning.**

## M50 — 3D på telefonen: Swift mot Python (S6c-1)

- **Porten.** `SwingLabKit/Sources/TreD` räknar MK1–MK7 rad för rad som
  `tools/pc/tva_kameror.py` och `tools/pc/tre_d/` (BESLUT B48): parningen, spåren på
  träffens tid, LOESS-utjämningen, självkalibreringen (åttapunktsmetoden, robusta varv,
  Levenberg–Marquardt på Sampson-felet med numerisk Jacobian, ε = **1e-6**, högst **30**
  varv, λ från **1e-3**, ×0,3 vid ett bättre steg och ×10 annars), synken, den viktade
  DLT-trianguleringen, vinkelkurvorna och passets median. Inga nya konstanter i kedjan:
  varje tal är MK1–MK7:s. **standard** (metoderna), **räkning** (porten).
- **Den linjära algebran** är egen och liten (bara Foundation, `Linalg.swift`):
  singulärvärden med ensidig Jacobi (Hestenes), som roterar kolumnerna tills de är
  ortogonala inom **1e-15 · max(m, 4)** relativt (högst 60 svep); nollvektorn är den
  högra singulärvektorn med minst längd, och en 3×3:s tredje vänstra vektor är u₁ × u₂
  (den är bara bestämd upp till tecknet när σ₃ ≈ 0, och E:s fyra lösningar är desamma).
  Ekvationssystem med LU och radpivotering som LAPACK:s gesv. Summor av en vektor med
  numpys parvisa summering (åtta delsummor upp till 128 tal), `np.arange` som numpys
  fill (a + i·((a + steg) − a)) och Pythons `round` via printf (lika till jämnt på det
  binära talet). **standard** (Golub & Van Loan kap. 8.6, ej läst i original),
  **räkning** (numpys källkod).
- **Urvalet till kalibreringen** (högst 5 000 av n punktpar) är index (i · P) mod n för
  i = 0, 1, …, där P är det första heltalet från ⌊n · **0,6180339887498949**⌋ (gyllene
  snittet) utan gemensam faktor med n, i både Python och Swift (BESLUT B48), i stället
  för numpys slumpade urval med frö 0. Det är en permutation (inget par två gånger) och
  sprids jämnt över slagen, tiderna och lederna; ett jämnt steg n/5 000 kan gå i takt med
  ledernas period (13 per ruta) och välja samma leder. **räkning** (Weyls följd, standard).
- **Toleransen mot Python** (TreDTests, fixturerna ur `tools/pc/generera_tre_d.py`):
  kalibreringens R, t och uppåt inom **1e-8**, synken inom **1e-8 s**, återprojektionen
  inom **1e-6 px**, måtten per slag och passets sammanfattning inom **1e-5°**, delstegen
  inom **1e-6**, och de avrundade fälten (Sampson-felet, vinkeln, synken i ms, lodlinjen
  mot de vågräta) inom sitt avrundningssteg; parningen, uppställningarna, skälen
  (`osaker`, `hoppat`, `lodlinje_fel`, `utelamnade`, `fel`) och antalen ska vara
  desamma. Algoritmen är densamma; det som skiljer är summeringsordningen i BLAS och
  LAPACK, som växer i Levenberg–Marquardts iterationer och i utjämningen. Toleransen är
  minst 14 gånger den uppmätta avvikelsen och tusentals gånger under det som syns
  (0,05°, PLAN S6c-2). **Uppmätt i Actions** (5 pass, 12 varianter, största
  avvikelsen, bra brus): måtten per slag 3,3e-7° (stretchen), passets median 7e-8°, R
  1,9e-10, t 7,7e-11, uppåt 3e-11, synken 7,3e-10 s, återprojektionen 2,9e-8 px; de
  avrundade fälten blev samma tal. Utan brus ligger avvikelserna kring 1e-11°.
  **räkning.**
- **Tiden** (Actions, `ubuntu-latest`, release, en tråd): ett pass om **10 slag 1,1 s**,
  **20 slag** i två uppställningar **2,2 s** (TreDTests). Per uppställning om tio slag går
  tiden till synken (två varv, cirka 0,45 s, 44 %: 22 + 7 förskjutningar trianguleras och
  projiceras), trianguleringen och måtten (0,25 s, 25 %: en 4×4-SVD per led och ruta),
  kalibreringen (tre gånger 0,07 s, 20 %) och spåren med de robusta vikterna (0,11 s,
  11 %). **Skattat för iPhone 13** (A15): dess enkeltrådsprestanda är ungefär 1,3–1,5
  gånger Actions-maskinens (Geekbench 6, enkeltråd; ej läst i original, **antagande**),
  så 10 slag tar cirka 0,7–1 s och 20 slag 1,5–2 s; med dubbel marginal för värme och
  annat i appen under **4 s** för 20 slag, under målet 10 s. Simulatorprovet
  (`Prov/SwingLabProvTreD.swift`) bygger och kör TreD på Darwin: fyra slag på 0,46 s i
  simulatorn (Actions macOS-maskin, Apple-processor; Linux 0,51 s), största avvikelse mot
  Python 6e-11°. **Telefonens väg (S6c-2, MS19)** med 2D-faserna ur lederna och den andra
telefonens slag genom bunten: tio slag på **1,0–1,9 s** i simulatorn (tre körningar; Actions-maskinerna skiljer) (iPhone 17 Pro, iOS 26.5,
Actions macOS-maskin), största avvikelse mot Python 6,5e-11° per slag
(`SwingLabProvTreDLink`); på Linux 2,5 s för två pass med faserna (TreDTelefonTests). Telefonen
är inte mätt: `tre_d.json` bär tiden (`sekunder`), så att första passet med två telefoner ger
den. Synken och trianguleringen går per slag och kan delas på kärnorna
  om det behövs.
- **Python-facit** räknas om parallellt (fyra processer, de längsta först, ett pass leder,
  spår och robusta vikter en gång per process) i `tools/tests/test_tre_d_fixturer.py`, och
  talen jämförs inom **1e-6** relativt eller **1e-5** absolut: numpy och OpenBLAS ger
  olika sista bitar på olika processorer (Actions byter maskin mellan körningar), och
  skillnaden växer som mellan Swift och Python. Testet skriver den största skillnaden
  per variant ("TRED-PY"): uppmätt Python mot Python på en annan dator högst 7,4e-7
  (bra brus), 1e-8 för typiskt brus i fyra slag och under 5e-9 utan brus. Omräkningen
  tar 7–15 s i Actions, beroende på maskinen (den med en gång avkodade lederna: 7,4 s).
- **Mot sanningen** gäller MK8:s gränser i Swift också: utan brus varje slag inom 1°
  och passets median inom 0,5°, med bra brus inom felbudgetens |bias| + 3 SD.


## M51 — 3D: vakterna mot trasiga paket och tal (S6c-1)

Samma vakter i Python (`tools/pc/tva_kameror.py`, `paket.py`) och Swift (`TreD`), så att
ett trasigt paket eller en kurva utan värde ger ett skäl och aldrig en krasch, ett minne
som tar slut eller NaN i analysen. **antagande** (gränserna), **räkning** (resten).

- **Paketets form:** Swift kontrollerar manifestet som `paket._kontrollera_manifest`
  (format, `pass`, vy, spelhand, `avstand_m` **0,5–20 m**, längden, serierna med
  `fonster` och `utsnitt`, slagens id (dubbla), serie, klick inom fönstret, `traff_s`,
  `detection_wrong`, domen, filerna) med samma text, och läser paketets JSON med en egen
  läsare som skiljer på tal och sant/falskt och på heltal och decimaltal som Pythons
  json. Ett formfel blir `tre_d.hoppat` (`TvaKameror.treD`). `enhet.json` utan
  `valt_index` väljer som Python (formatet utan `index`).
- **Vyerna:** parningen kräver ett DTL- och ett FO-paket i den ordningen, annars ett fel.
- **Ledernas tider:** ett slag vars spår (efter rutorna med samma tid) spänner över
  **30 s**, eller har en tid som inte är ett ändligt tal, mäts inte
  (`tre_d.utelamnade`, skälet "ledernas tider spänner orimligt långt"). Ett slag är
  några sekunder; 30 s är en fil som inte är ett slag. `np.arange`/`LA.arange` ger dessutom
  ingen axel över 10⁷ steg. Övriga parade slag som inte mäts står där med sitt skäl
  (domen, Detection wrong, lederna saknas, för få rutor).
- **Kalibreringen** kräver minst **9** punktpar: med exakt 8 ger numpys
  `svd(full_matrices=False)` bara 8 högra singulärvektorer, och `Vh[-1]` är då inte
  nollrummet. Ett Sampson-fel eller en vinkel mellan kamerorna som inte är ett tal ger
  `hoppat` ("kamerornas läge gick inte att räkna"); spärren och skyddet mot de vågräta
  är skrivna så att NaN räknas som över gränsen.
- **Synken:** en parabel med en granne utan värde ger toppen själv, och en synk som inte
  är ett tal ger förra värdet. `synk_ms`, `sampson_px`, vinkeln och
  `lodlinje_mot_vagrata` blir aldrig NaN (den sista står bara med när den är ett tal).
## M60 — Spåren i granskningen (S4f)

Ett spår är en punkts bana genom hela slaget i granskningen (PLAN S4f, BESLUT B70). Det är
en bild, inget mått: mätningen och slagets tal rörs inte.

- **Punkterna** ur slagets leder (M1), rutorna i granskningen (MS15): **händerna** =
  handledernas mitt, där en saknad handled tar den andras plats (greppregeln, M1);
  **axlarna** och **höfterna** = två serier var (vänster och höger led), så att vridningen
  syns som att linjerna närmar sig och korsar varandra; **huvudet** = näsan. En led räknas
  från konfidensen **0,3** (M1). **Klubbhuvudet** kommer ur S7b:s bana (M61).
- **Greppregelns byte bryter banan:** där händernas punkt går från mitten till en handled
  (eller tillbaka, eller från den ena till den andra) hoppar den en halv handledsbredd, så
  spåret bryts där i stället för att rita hoppet (`SparSerie.brott`). **räkning.**
- **Utjämningen** (`Spar.jamna`, bara för visningen): gaussvikt över tiden med **σ = 7,5 ms**
  som mätningen (M3), men fönstret krymper **symmetriskt** vid en kant: h = min(3σ, tiden till
  delens första ruta, tiden till dess sista), så att en lucka eller ett brott aldrig drar en
  punkt åt ena hållet. En del slutar där punkten saknas, över en lucka längre än **0,10 s**
  och vid ett brott; delens ändpunkter ritas som de är. Provat: en lucka mitt i en rörelse
  på 2 000 px/s lämnar rutorna bredvid exakt på linjen (mätningens fönster drar dem 1,5 px),
  och en vändning står kvar på samma ruta, 0,1 px från sitt läge. Mätningens `Faser.jamna`
  (M3) är orörd. **antagande** (σ, samma som mätningen).
- **Avbrott:** en ruta där punkten saknas ger ett avbrott i linjen, och likaså en lucka i
  rutnätet längre än **0,10 s** (M3); ingen gissning över luckan. En ensam punkt ritas inte.
- **Spelat och kvar:** hela banan ritas med opaciteten **0,30** (en gång, oberoende av
  rutan), och delen fram till rutan som visas (t ≤ rutans tid, binärsökning) ritas fast
  ovanpå (`SparSerie.delar`, `grans`, `spelade`). Punktens läge i rutan är en prick. Under
  varje linje ligger en **svart kant med opaciteten 0,5, 1,5 pt bredare**, så att spåret syns
  mot en ljus bakgrund. Strecken räknas från seriens start (båglängden), så att de inte
  kryper när rutan byts. **antagande** (0,30, 0,5 och 1,5 pt; oprövat på telefonen).
- **Ritningen** (`SparLager`, appen): seriernas punkter i hela bildens pixlar räknas en gång
  om till ytan med samma avbildning som lederna (`ShotReview.yta`, MS13; provat med ett snett
  utsnitt i `SparTests`). Med ett spår påslaget ritas lederna gråa (`Theme.secondary`), så att
  spåren skiljer sig från dem. Provat i simulatorprovet: händernas spår vid P4 ligger inom 3 px
  från handledernas mitt (`granskning-spar-p4`).
- **Återanvändningen:** datamodellen (`SparSerie`) och delningen (avbrotten, spelat och kvar)
  återanvänds av klubbhuvudets bana (S7b) och av 3D (S6d); 3D ritar med en egen vy.

## M61 — Klubbhuvudets bana mellan ankarna (S7b)

Johannes tryck vid P1–P10 (S7a, M45) är **ankare**. Klubbhuvudet spåras bara mellan två
ankare som är **grannar i svingens ordning** (P1→P2→…→P10): saknas en position mellan två
ankare ritas ingenting där, så att en gissning över en halv sving aldrig ser ut som en bana.
`tools/pc/klubbspar.py` är facit och `KlubbSpar` i SwingLabKit ger samma tal inom 1e-6 (B12),
också med glesa ankare. Indata i hela bildens pixlar, rutorna i sin egen upplösning
(`skala`); klubbmåtten (M46–M49) tar bara tryckta punkter.

**Spårningen** (ruta för ruta i tidsordning, så att appen läser filen en gång):

- **Rörelsen** i ruta k är min(|I_k − I_före|, |I_k − I_efter|) med rutorna närmast
  **2/240 s** före och efter (inom 0,6 · 2/240 s, högst tre rutor bort): det som är där just i
  ruta k, utan spöket där klubban var. **Tröskeln är brusanpassad:** 3,5 · σ, där σ =
  1,4826 · MAD av differensen I_k − I_före i sökrutan, men minst **8** gråtoner. Med brus
  σ ≈ 7 per pixel blir tröskeln cirka 37; med lågt brus (σ ≈ 2,5) cirka 13, så att en låg
  kontrast (25 gråtoner) syns. **antagande** (3,5 och 8).
- **Kroppen maskeras** ur Visions leder i rutan (konfidens ≥ 0,3, M1): streck kring benen och
  armarna (radien **0,18** av bålens längd), bålen (**0,35**), huvudet (**0,40**) och händerna
  (**0,20**); bålens längd är medianen över slaget. **antagande.**
- **Korridoren:** greppet är handledernas mitt (M1, utjämnad M3) plus ankarnas förskjutning
  mellan handlederna och det tryckta greppet, linjärt i tiden; skaftets längd L och riktning
  är ankarnas, linjärt i tiden (vinkeln den kortaste vägen). Sökningen: radien **0,5–1,35 L**
  och vinkeln inom **max(30°, halva vridningen mellan ankarna)**. **antagande.**
- **Skak:** rör sig mer än **1 %** av sökrutan utanför kroppen och korridoren är rutan tappad
  (kameran rör sig, en textur glider). Med textur och skak ±1 px i den påhittade filmen höjer
  den brusanpassade tröskeln sig över texturen, så spärren slår sällan till; den finns för
  det tröskeln inte tar. **antagande.**
- **Fläcken:** de rörliga pixlarna i korridoren delas i fläckar (8-grannar), och klubbhuvudet
  är fläcken med minst **5** pixlar vars yttre kant (den tredje yttersta pixeln) ligger
  närmast L från greppet; en skugga eller en boll ligger längre ut, en bit av skaftet längre
  in. I fläcken är huvudet mitten av bandet ytterst (**0,12 L** brett). Är bandet smalare än
  **0,05 L** tvärs riktningen från greppet syns bara skaftet (huvudet mot en mörk bakgrund,
  eller nästan stilla), och rutan är tappad. **antagande.**

**Sedan, utan bilderna:**

- **Mitten mot hoseln:** spårningen ger huvudets rörliga mitt, ankarna hoseln (B44). Vid
  varje ankare mäts mitten (med ankarets egen korridor) mot hoseln i skaftets koordinater
  (längs och tvärs), och förskjutningen dras av i rutorna mellan ankarna, linjärt mellan
  ankarnas (ett ankare utan mätning tar grannens, inget ger 0). Den räknas bara mellan
  **0,03 L** (under det är det tryckens brus och spårningens egen skevhet) och **0,12 L**
  (över det rör sig något annat vid ankaret, en skugga eller bollen). Provat: med huvudets
  mitt 10 px bortom hoseln (0,067 L) blir felet 1,35 px i median mot 9,4 px utan. **antagande**
  (gränserna).
- **Radien:** punktens avstånd till greppet får skilja högst **0,25 L** från L. **antagande.**
- **Språnget:** högst **120 L per sekund** (0,5 L per ruta vid 240 bilder/s) från förra säkra
  punkten. **antagande.**
- **Grannarna:** en spårad punkt som ligger mer än **0,10 L** från interpolationen mellan sin
  förra och nästa säkra punkt (spårad eller ankare, före prövningen) är tappad. **antagande.**
- **Tappade rutor interpoleras** mellan de säkra grannarna i polära koordinater kring rutans
  grepp (vinkeln och radien linjärt i tiden), märks `interpolerad` och ritas streckade (M60,
  B70). En punkt utanför bilden skrivs inte (banan får en lucka där).
- **Banan jämnas inte** (σ = 0, `SparSerie(bana:)`): spårens σ = 7,5 ms (M60) drar in en båge
  med radien r med ungefär v²σ²/(2r) när farten är v, och vid 40 m/s och skaftets radie
  1,1 m blir det cirka 4 cm, mer än spårningens fel. **räkning.**
- **Planet genom nedsvingen** (`klubbspar.planet`, `KlubbSpar.planet`): för varje ruta från
  P5 till P7 vinkeln vid P1:s hosel från P1-linjen till banans punkt, som `skaft_plan_p6`
  (M47), + = över planet. Närmare P1:s hosel än **0,25** P1-skaft mäts inte. Visas inte som
  tal (B71); bakifrån ritas P1-linjen, märkt "P1 plane".

**I appen** (B71): rutorna läses ur filen som Y-planet, vridet upprätt (EXIF 1–8) med den
kortaste sidan **320 px**, och bara de som behövs just nu hålls i minnet (en ringbuffert om
8 rutor bakom den senast begärda). Saknas mer än **10 %** av de begärda rutorna sparas ingen
bana, och chipet säger varför. **antagande** (320 px, 10 %).

**Facit (påhittat, `tools/pc/klubbfilm.py`, `KlubbFilm`):** bilden 600 × 560 px, rutorna i halv
upplösning, 240 bilder/s med var nionde ruta borta, en klubba med skaftet 150 px längs en känd
båge, brus σ ≈ 7 gråtoner, en kropp som ritas över klubban, ett mörkt fält där huvudet inte
syns, och ankare vid P1–P10 med ±1,5 px tryckbrus. Varianterna genereras i proven och checkas
inte in: bakifrån (skaftets vågräta del förkortad till en fjärdedel), rörelseoskärpa (fyra
lägen över en ruta), låg kontrast (huvudet 25 gråtoner från bakgrunden) med lågt brus och med
vanligt brus, textur med skak ±1 px, en boll som flyger iväg efter träffen, klubbans skugga på
marken, och huvudets mitt 10 px bortom hoseln. Uppmätt (`test_klubbspar`, px i bilden, L =
150 px):

| Film | Spårade: median, p95, max | Grova (> 0,10 L) | Interpolerade: andel, max |
|---|---|---|---|
| grund | 0,59, 2,38, 10,2 | 0 | 45 %, 23,5 |
| oskärpa | 0,44, 2,21, 6,3 | 0 | 45 %, 23,4 |
| låg kontrast, lågt brus | 0,55, 2,26, 3,4 | 0 | 38 %, 21,3 |
| textur och skak | 0,54, 3,09, 6,5 | 0 | 48 %, 23,6 |
| boll | 0,59, 2,41, 10,2 | 0 | 47 %, 23,5 |
| skugga | 0,58, 2,35, 10,2 | 0 | 46 %, 23,5 |
| mitten bredvid hoseln | 1,35, 2,57, 10,5 | 0 | 50 %, 25,6 |
| bakifrån | 1,80, 4,47, 5,5 | 0 | **74 %, 50,8** |
| låg kontrast, vanligt brus | 1,22, 3,48, 4,3 | 0 | **88 %, 49,9** |

Glesa ankare: P1+P7, P1/P4/P7/P10 och P4/P7/P10 ger bara ankarna; P1/P2/P3 ger banan P1–P3
(57 % interpolerade, högst 21 px) och inget efter P3. Planet P5–P7 ligger inom **0,52°** från
sanningens.

**Klart när (den påhittade filmen):** i varje variant spårade rutor median ≤ **2 %** och p95 ≤
**5 %** av skaftet och högst **1 %** grova fel (> 10 % av skaftet); i grunden och varianterna
utom bakifrån och låg kontrast med vanligt brus högst **55 %** interpolerade (grunden **50 %**) och
interpolerade högst **20 %** av skaftet; planet inom **1°**. **Vad som inte håller:** bakifrån
och med låg kontrast i vanligt brus tappar spårningen de flesta rutorna; de spårade är rätt,
men tre av fyra rutor är interpolerade och felet där når en tredjedel av skaftet.
**Klart när (S7b, riktiga klipp):** på DTL-klipp, i **20 slumpvis valda rutor** mellan ankarna
som Johannes märker för hand (S7a:s märkning, utan att se banan), ligger de spårade rutorna
inom **5 %** av skaftet i median och **10 %** i p95, högst **5 %** av dem har grova fel, och
högst **60 %** av rutorna mellan ankarna är interpolerade. **antagande** (gränserna).

---

# Facit (S3 och S7)

Konstanterna i verktygen som Johannes kör på hemdatorn: S3:s jämförelse av Vision mot
MediaPipe (`tools/pc/s3_facit.py`, klippen i `tools/pc/klipp.py`) och S7:s märkning av
klubban (`tools/pc/markera_klubba.py`). Numreringen MF hålls skild från M, MS, MT och MK.
**Inget här är mätt på riktiga svingar än**: verktygen är provade med påhittade paket,
en påhittad modell som läser rutans nummer ur bilden, och en riktig kort film som är
lagrad liggande och börjar efter 0 (`tools/tests/test_s3_facit.py`,
`test_markera_klubba.py`).

## MF1 — MediaPipe på telefonens rutor, och tidsparningen (S3)

- **Modellen:** MediaPipe Pose Landmarker **heavy** (`pose_landmarker_heavy.task`,
  float16), i VIDEO-läge med en instans per slag och detektion och spårning på **0,5**,
  samma som Golf SG (`tools/handled_video.py`), där oktobers mätning gjordes.
  **mätt** (Golf SG) för valet, **tillverkare** för modellen (research 2 §1).
- **Varje ruta i klippet** körs, i ordning, med OpenCV:s tid (`CAP_PROP_POS_MSEC`).
  Den tiden räknas från videoströmmens start, inte från klippets nolla där telefonen mätte
  `klick_i_klipp_s` (**mätt** 2026-10-23: en film med `-itsoffset 0,0025` får
  `start_time` 2,0 ms men OpenCV:s första ruta på 0,0 ms). Visions rutor ligger i klippet
  på e = t + `klick_i_klipp_s`, och samma ruta har OpenCV:s tid r = e + δ.
- **Förskjutningen δ skattas per klipp ur lederna** (`para_tider`): kandidaterna är
  rutnätet kring δ = 0, **±3** rutor (r för klippets rutor kring Visions mittersta ruta).
  För varje kandidat paras rutorna inom **2 ms** (halva steget vid 240 bilder/s,
  4,17 ms, så att grannrutan aldrig tas). Modellernas fasta skillnad per handled (olika
  leddefinition) dras bort först: medianvektorn av Vision − MediaPipe per handled och
  kandidat. Sedan mäts handledernas medelavstånd från toppen − **0,3 s** till träffen +
  **0,3 s**, där händerna rör sig så mycket att en ruta fel syns. Den minsta vinner.
  **Tvetydigt** och slaget jämförs inte: färre än **20** rutor med handlederna i båda,
  den näst bästa inom **10 %** av den bästa, eller den bästa vid sökningens kant. δ,
  rutorna, kvoten och medianen av resten (r − e − δ) skrivs per slag i `s3.json`.
  **antagande** (±3, 10 %, 20, fönstret); provat med en förskjutning på 0,6 och 0,7 ruta,
  där närmaste rutan är fel, och med 0–40 px fast skillnad mellan handlederna.
- **IMAGE-läget för tidsparningen.** VIDEO-läget spårar och jämnar ut mellan rutorna och
  kan släpa efter i snabba rörelser; då låses δ en ruta fel utan att spärrarna märker det.
  Rutorna i fönstret ± **50 ms** körs därför också i IMAGE-läget (varje ruta för sig), och
  δ skattas på dem. Jämförelsen av lederna och måtten görs på VIDEO-läget, som oktobers
  mätning (MediaPipes eftersläpning blir då en del av avvikelsen). **antagande**: att
  IMAGE-läget inte släpar; MediaPipes egen eftersläpning är inte mätt (det kräver en
  riktig sving). Kostnad: cirka 150 rutor till per slag.
- **δ hör till behållaren** och ska vara densamma i passets klipp: ett slag mer än **2 ms**
  från passets median blir tvetydigt, och medianen och spridningen skrivs per paket.
  **antagande** (telefonen skriver alla klipp likadant).
- **ffprobe som kontroll:** finns ffprobe skrivs klippets `start_time`, och en varning när
  δ inte är −start_time inom 2 ms. Den avgör inget: vad telefonens `AVAsset` räknar som
  nolla är inte prövat (i filmprovet är δ = −start_time).
- **Samma utsnitt.** MediaPipe ser seriens utsnitt i hela pixlar
  (`paket.utsnitt_px`, avrundat utåt som telefonens `CropRect.pixels`; i klippets
  upplösning om den skiljer, `klipp.skala_ruta`), och punkterna förs tillbaka med
  `paket.fran_utsnittet` på det utsnitt modellen såg, som telefonen gör med Visions (MS13).
  En punkt utanför utsnittet sparas som saknad, som på telefonen (MS13). **räkning.**
- **Bilden upprätt:** OpenCV vrider klippet med `CAP_PROP_ORIENTATION_AUTO`. Har bilden
  inte samma stående eller liggande form som lederna stoppar verktyget (`klipp.VridenFel`)
  i stället för att gissa vridningen; samma kontroll gör `kontaktark.las_ruta`, som också
  frågar ffmpeg och OpenCV från t − **2 ms** så att rutan närmast t kommer (de ger första
  rutan från tiden). Passets kontaktark (MT7) tar Visions ruta närmast fasen och läser
  klippet med S3:s δ när `~/swinglab-s3/<pass>/s3.json` finns, annars utan. **räkning.**
- **Lederna:** de 13 i filens ordning ur MediaPipes index (FORMAT.md, Lederna),
  synligheten som konfidens; under **0,3** saknad (M1), så att måtten räknas med samma
  kod och samma gräns för båda källorna. M1:s gräns gäller Vision; om MediaPipes
  synlighet ska skäras som Golf SG:s 0,5 avgörs av S3:s tabell. **antagande.**
- MediaPipes leder (VIDEO, och IMAGE i fönstret) sparas per slag i utmappens
  `mediapipe/` med klippets egna tider och läses nästa gång bara när formen, utsnittet,
  bildens storlek, modellfilen och klippet (CRC och storlek ur zippen) är desamma; annars
  körs MediaPipe om (`--om` alltid). **räkning.**

## MF2 — Jämförelsen av lederna

- **Avvikelsen** är Vision − MediaPipe per led och parad ruta, där båda ser leden, i px
  och i % av kroppslängden i bild (spelarens längd / cm per px ur MediaPipes mätning, M2;
  Visions om MediaPipes saknas). MediaPipe är facit, inte sanningen: avvikelsen bär båda
  modellernas fel och deras olika leddefinitioner (därför MF3:s simulering). **räkning.**
- **Faserna** ur slagets faser (M4, MediaPipes, annars Visions): **adress** före
  baksvingens start (eller toppen − 1,2 s, M4), **baksving** till toppen, **nedsving**
  till träffen, **efter träff** därefter. **räkning.**
- Per led, fas och vy: **medel** och **spridning** (sd) av avståndet; den **fasta**
  delen = medianens förskjutning (x, y), som RMS per axel; den **rörliga** delen = den
  robusta sd:n (MAD × 1,4826, M25) per axel, som RMS; **utliggare** = rutor mer än
  **3** robusta sd (M25) från medianen. Samma uppdelning som felbudgetens brus (fast,
  vandring och vitt, utliggare; S6_FELBUDGET §3). För flera leder ihop vägs delarna med
  antalet rutor. Varje rad bär antalet slag den bygger på. **räkning** (formen),
  **standard** (MAD).
- **Antalet mätningar är antalet slag**, inte rutorna: rutorna i ett slag hänger ihop.
  Det som avgör B5 och måttens skillnad får därför ett 95 %-intervall ur **100**
  dragningar av slagen med återläggning (bootstrap; rutorna följer sitt slag, måtten
  parade per slag), och visas som "–" under **5** slag. **standard** (bootstrap),
  **antagande** (5, 100).
- **Nedsvingen för sig:** adressens stillastående rutor är flest och styr medianen och
  MAD:en för hela svingen, så det som avgör B5 visas också för nedsvingen ensam.
- **Saknade leder:** andelen rutor där Vision saknar leden, där MediaPipe saknar den,
  och där Vision saknar den men MediaPipe ser den. **räkning.**
- **Förväxlade sidor:** för varje par (axlar, armbågar, handleder, höfter, knän,
  fotleder) där båda källorna ser båda lederna: förväxlat när Visions två leder mot
  MediaPipes bytta ger under **halva** summan av avstånden mot de rätta. **antagande.**

## MF3 — Det som avgör B5: trösklarna och måtten

- **Trösklarna simuleras**, eftersom skillnaden Vision − MediaPipe bär båda källornas
  fel medan felbudgetens nivåer gäller en källa mot sanningen (med dem direkt hade Vision
  på "typiskt" och MediaPipe på "bra" blivit "dåligt"). Felbudgetens kedja
  (`tre_d.kamera.observera` med uppställningen i `felbudget.Uppstallning`: skymda leder
  med 2,5 × bruset och låg konfidens, oskärpan vid 1/1000 s, utliggarna, en fast avvikelse
  per led och vy för passet) körs på samma påhittade svingar, kameror och rutor:
  **MediaPipe på "bra"** (antagande, ur Googles mätning där heavy ligger klart över
  Vision, research 2 §1) och **Vision** på var och en av nivåerna bra, typiskt och dåligt.
  Skillnaden går genom samma statistik som passet (MF2), i % av kroppen i bild, över
  **5** pass om **10** slag och båda vyerna, för hela svingen och för nedsvingen
  (`simulera`, `nivaer`, cirka 4 s per körning). **antagande** (felbudgetens brus och
  MediaPipes nivå), **räkning** (simuleringen).
- **Gränserna** mellan nivåerna, för den fasta och den rörliga delen: mellan två nivåer
  det **geometriska medlet** av deras medianer; över "dåligt" dess median gånger roten ur
  kvoten mot "typiskt" (lika långt uppåt i log). **Nivån** = den bästa där båda delarna
  ligger under gränsen. Med nivåns egen median som gräns hade bara 18, 35 och 35 % av
  passen på sann nivå bra, typiskt och dåligt klassats rätt (granskningen); med gränserna
  **88, 91 och 94 %** (uppmätt 2026-10-23: 8 nya pass med nytt frö, båda vyerna och
  faserna). Provet kräver minst 75 % per nivå på en mindre simulering.
- **Utliggarna** och de **grova avvikelserna** (avståndet över **5 %** av kroppslängden,
  cirka 9 cm; felbudgetens utliggare är 50 px ≈ 5,8 % vid 3 m) visas bredvid
  simuleringens väntade andel men avgör inte. Utliggarna räknas mot den robusta sd:n och
  blir därför färre när bruset växer; de grova följer nivån. **antagande** (5 %).
- **Vision saknar leden där MediaPipe ser den** och **förväxlade sidor:** ingen
  tröskel; **ingen källa**.
- **Måtten (S1):** varje mått i vyn (`matt.MATT`) räknas med `matt.mat` på Visions och
  på MediaPipes leder för samma slag, parade. Per mått: passets median för båda (M25),
  skillnaden mellan dem med 95 %-intervall (bootstrap av slagparen, MF2), skillnaden slag
  för slag (medel, sd, medel av |skillnad|) och MediaPipe-passets robusta sd (M26).
  **Tydlig** = skillnaden större än den sd:n: samma form som M26 använder för pass mot
  pass, så att en tydlig skillnad betyder att Vision ensam hade visat en ändring som bara
  är ledkällan. Formen är M26:s; som gräns för B5 har den **ingen källa**. Faserna
  (start, topp) jämförs i ms, och skalan som kvoten av cm per px.
- Verktyget fattar inte beslutet: tabellen är underlaget för B5 (och B14, B38).

## MF4 — Kontaktarket för S3

- En bild per vy: en rad per slag, högst **6**, jämnt spridda över passets slag med klipp;
  fyra kolumner på MT7:s tider (adressens och finishens fönsters mitt, toppen, träffen):
  Vision-rutan närmast tiden, klippets ruta på e + δ (MF1) och MediaPipes leder från samma
  klippruta. Utsnittet nedskalat till **200** px bredd, Visions leder vita och MediaPipes
  orange. **antagande** (storleken: läsbar för ögat, liten fil).

## MF5 — Rutvalet för klubbans märkning (S7)

- **Slagen:** mätta slag med klipp (som MT1) **och en säker förskjutning i S3:s
  `s3.json`** (MF1), högst **6** per paket, jämnt spridda över passet med det första och
  det sista. Utan S3:s tabell stannar verktyget och säger att S3 ska köras först.
  **antagande** (antalet: cirka 30 rutor per vy, en kvarts märkning).
- **Rutorna per slag:** adressen (adressfönstrets mitt, MT7), toppen (M4) och **tidig
  nedsving** = P5 (främre armen vågrät i nedsvingen, M28), annars toppen + **1/3** av
  nedsvingens tid; dessutom **2** rutor jämnt mellan adressen och finishens fönsters mitt.
  Adress, topp och tidig nedsving är rutorna som S7:s "klart när" mäts på. Varje tid
  flyttas till närmaste Vision-ruta och tas bara inom klippet (MS12); två val på samma
  ruta blir en. Klippets ruta läses med OpenCV på e + δ och bara om en ruta finns inom
  **2 ms** (MF1), så att bilden, tiden och ledtråden hör till Visions ruta. **antagande**
  (1/3, antalet jämna).
- **En video utan paket** har inga leder: **24** rutor jämnt över klippet, var och en
  rutan närmast den valda tiden (inom en halv ruta). Den valda tiden står kvar i `t_klipp`
  och rutans egen tid sparas i `t_ruta`, så att en återupptagen märkning hittar rutan.
  **antagande.**
- **Greppets ledtråd:** handledernas mitt i rutan, eller den som syns (greppregeln, M1,
  konfidens ≥ 0,3). Handlederna ligger 5–8 cm från skaftet (cirka 4° på skaftets vinkel),
  så ledtråden visas bara som en ring och greppet kräver ett klick: varje sparad punkt är
  ett klick (`kalla: "klick"`). Skaftet och klubbhuvudet har ingen ledtråd förrän en
  detektor finns. **antagande** (avståndet: handledens led mot greppets mitt).
- **En tidigare märkning** behålls ruta för ruta när id, fil, förskjutning och tid
  stämmer (inom **0,1 ms**; Visions tid, för en video den valda tiden); en gammal ruta
  som inte stämmer ligger kvar sist, oförändrad. **räkning.**

## MF6 — Märksidan och servern

- Sidan visar seriens utsnitt vidgat med **15 %** per sida (klubban når utanför spelaren
  vid toppen), inom bilden; utan utsnitt hela bilden. **antagande.**
- Z förstorar **3 ×** kring musen. Bilderna bäddas in som JPEG med kvalitet **88**
  (OpenCV), annars PNG. **antagande** (läsbar hosel, rimlig sidstorlek).
- Punkterna sparas i hela den upprätta bildens pixlar (som lederna, FORMAT.md) med en
  decimal, även när klippet har en annan upplösning. **räkning.**
- **Servern** lyssnar bara på 127.0.0.1 och kräver på varje anrop en slumpad nyckel
  (`secrets.token_urlsafe`, i adressen som webbläsaren öppnar) och Host
  `127.0.0.1:<port>`; en sparning kräver `application/json` och en giltig längd (högst
  **50 MB**). Då kan ingen annan sida i webbläsaren skriva filen. Sparningarna går under
  ett lås till ett unikt temporärt namn och byts in, och sidan skickar dem en i taget.
  **räkning.**
