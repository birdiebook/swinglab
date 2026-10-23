# Metod och källor

Varje mått, gräns och konstant i SwingLab, med varifrån den kommer. Koden
hänvisar hit (`// METOD M3`), och en konstant utan rad här är en bugg.

**Källans status:** **mätt** (i det här projektet eller i Golf SG) ·
**standard** · **forskning** ("ej läst i original" = bara hänvisningen eller
sökmotorns sammanfattning är läst) · **tillverkare** (Sportsbox, GEARS,
GolfTEC m.fl.) · **tränare** (TPI, coacher) · **antagande** (ska kalibreras).

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
  ger ingen start och inget tempo.
- **Träffen:** `t_klick`, klicket i ljudet (±7 ms, Golf SG). **mätt.**
- **Adressen:** medel över start −0,40…−0,10 s. Saknas starten: toppen −1,2 s
  i stället för starten. **Finish:** medel över träffen +1,0…+1,2 s. Samma
  fönster som Golf SG (`FAS_FONSTER`, `FINISH`). **standard** i Golf SG.
- **Ett läge i en fas** är punktens medel över adressens och finishens fönster,
  och värdet i ögonblicket vid toppen och träffen. En vinkel räknas ur lägena,
  inte som medel av vinklar.

## M5 — Tempot

- tempo = (topp − start) / (träff − topp), baksvingen och nedsvingen i s.
  Båda vyerna. Saknas starten saknas tempot.
- **Gräns i katalogen:** 2,5–3,1 grönt (Blast Motion, tour), utanför gult,
  aldrig rött. **tillverkare, ej läst i original.** Novosel 3:1 och Grober
  2,8:1 (research 1 §1.9). Blasts topp är klubbans, vår är händernas, och vår
  topp ligger ≈ 9 ms tidigt (M4), så tempot är troligen något lågt mot Blast.
  Låg prioritet: inget belagt samband med utfallet.
- **Bakifrån (DTL) saknas tempot oftare, och blir lägre** (utredningen 2026-10-23,
  ett importerat DTL-pass med två slag utan tempo på Today): klicket finns i varje
  slag (utan klick blir det inget slag), så det är starten som saknas. Bakifrån går
  händernas första rörelse i baksvingen i djupled mot kameran och syns knappt i
  bilden, och står kameran högre än händerna ser de ut att sjunka en bit innan de
  stiger, så adressläget (det lägsta) och starten hittas sent. Uppmätt på påhittade
  svingar: 0,2 s osynlig takeaway med en baksving på 0,75 s ger en synlig baksving
  under 0,5 s, och starten och tempot saknas (Today visar då ingen rad); med 0,95 s
  baksving finns tempot men blir ≈ 0,9 lägre. Framifrån (FO) ligger takeawayn i
  bildens plan. **antagande** tills ett riktigt DTL-pass prövats: `faser.start` är
  `null` i PC:ns `analys.json` när det är orsaken.

## M6 — Bröstets böjning och tappad hållning (DTL)

- `brost_bojning_<fas>`: linjen höftmitt → axelmitt mot lodlinjen i bild,
  grader, **+ framåt mot bollen**. Adress, topp, träff, finish.
- `brost_bojning_tapp` = adressens − träffens böjning, **+ = bröstet reste sig**
  (loss of posture). Egen baslinje: 2D-felet (−6,5 ± 3,6° i flexion vid toppen,
  Mears 2016) är lika stort som förlusten (research 1 §1.5).
- Portat från Golf SG (`vinkel_fran_lod`). GolfTEC anger tour ≈ 40° i adressen
  ("shoulder bend"), en annan definition. **tillverkare, ej läst i original.**

## M7 — Bäckenets thrust (DTL)

- `backen_thrust_<fas>`: höftmittens förflyttning från adressen längs X, cm,
  **+ mot bollen** = early extension. Topp, träff, finish.
- Tecknet följer av M1 och är provat på en påhittad sving (+3 cm mot bollen
  ger +3,0). Det rättar inte frågan i S0 om oktobers tal, som räknades i
  bildens råa x.
- TPI: early extension = bäckenet mot bollen i bak- eller nedsvingen; exemplet
  är mer än 3 tum (7,6 cm) vid träff. **tränare, ej läst i original.** Egen
  baslinje i katalogen tills tecknet och exemplet är kontrollerade.

## M8 — Lyften (bäckenet och huvudet, båda vyerna)

- `backen_lyft_<fas>`, `huvud_lyft_<fas>`: förflyttningen från adressen i
  höjdled, cm, **+ uppåt**. Topp, träff, finish. Huvudet är näsan.

## M9 — Huvudet: mot bollen (DTL) och sway (FO)

- `huvud_mot_bollen_<fas>` (DTL, + mot bollen) och `huvud_sway_<fas>` (FO,
  + mot målet): näsans förflyttning från adressen, cm. Topp, träff, finish.
- Inget tourvärde hittat; bedöms bäst tillsammans med bröstets sway
  (research 1 §1.2).

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
  måttet. **antagande:** TPI anger förekomsten (43,5 %) men ingen gräns i cm;
  klubbans bana kommer i S7.
- Uppmätt på påhittade svingar (händerna 4–6 m/s i nedsvingen): rutnätet med
  luckor ger −0,06 cm och utjämningen ytterligare −0,05 cm på 3,2 cm, ≈ 4 %.

## M14 — Sidböjningen och reverse spine (FO)

- `sidbojning_<fas>`: linjen höftmitt → axelmitt mot lodlinjen i bild, grader,
  **+ bort från målet** (som Golf SG: −vinkel_fran_lod). Adress, topp, träff,
  finish.
- **Reverse spine** = negativ sidböjning vid toppen: överkroppen lutar mot
  målet. Katalogen tar `sidbojning_topp` med det sämre hållet nedåt och egen
  baslinje. TPI kopplar felet till ländryggen. **tränare, ej läst i original.**
- Sportsbox sidböjning vid träff 24–38° (proffs) är bröstkorgen i 3D, inte
  linjen i bild (research 1 §1.4).

## M15 — Bäckenets sway (FO)

- `backen_sway_<fas>`: höftmittens förflyttning från adressen längs X, cm,
  **+ mot målet**. Topp, träff, finish. Portat från Golf SG.
- **Gräns vid toppen** (katalogen `sway_topp`): ≥ 0 grönt, −5…0 gult, under −5
  rött. Sportsbox: låghandicap nära 0, höghandicap "flera tum" bort från
  målet. GolfTEC: tour 3,9 tum (≈ 10 cm) mot målet. **tillverkare, ej läst i
  original**; gränsen själv är ett **antagande** byggt på de två (research 1
  §1.1). Ingen gräns vid träffen förrän definitionerna stämts av.

## M16 — Bröstets sway (FO)

- `brost_sway_<fas>`: axelmittens förflyttning från adressen längs X, cm,
  + mot målet. Topp, träff, finish.

## M17 — Axellinjens lutning (FO) — granskas

- `axellinje_lutning_<fas>`: linjen bakre axel → främre axel mot vågrätt i
  bild, grader, **+ = bakre axeln lägre**. Adress och träff (vid toppen och i
  finishen är axlarna vridna förbi linjen). Portat från Golf SG.
- **Definitionen granskas i S0.** Oktobers värde passar ingen källa (Golf SG,
  HANDLED_PLAN §4): GolfTEC anger 39° ("shoulder tilt") och Sportsbox 24–38°
  (bröstets sidböjning) för tour. Troligen för att axelpunkterna (akromion) är
  opålitliga vid träffen (Wheat) och linjen i bild inte är bröstets sidböjning. **Måttet får ingen tour-gräns**, och felet i katalogen är
  avstängt tills S0 är klar.

## M18 — Höftlinjens lutning (FO)

- `hoftlinje_lutning_<fas>`: linjen bakre höft → främre höft mot vågrätt,
  grader, + = bakre höften lägre. Adress, topp, träff. Portat från Golf SG.

## M19 — Sway gap vid träffen (FO)

- `sway_gap_traff` = bäckenets sway − bröstets sway vid träffen, cm. **+ =
  bäckenet längre mot målet än bröstet** (bröstet bakom). Portat från Golf SG.
- Sportsbox definition och tecken är oklara (ett japanskt exempel går inte
  ihop med enkel subtraktion). Egen baslinje, ingen riktning (research 1 §1.3).

## M20 — Händerna vid träffen (FO)

- `hander_fore_adress_traff`: händernas X vid träffen minus i adressen, cm,
  + mot målet.
- `hander_fore_backen_traff`: händernas X minus höftmittens vid träffen, cm,
  + = händerna före bäckenet. Portade från Golf SG.

## M21 — Bäckenets resa framåt (FO)

- `backen_resa_framat` = bäckenets sway vid träffen − vid toppen, cm, + mot
  målet. Sway bakåt och för lite förskjutning framåt är samma tema, bäckenets
  väg (PLAN S1). Egen baslinje, sämre nedåt. **antagande.**
- GolfTEC: tour 3,9 tum mot målet vid toppen och 1,6 tum vid träffen (en annan
  referens än vår); Sportsbox tour +13 cm vid träffen är inte återfunnen.

## M22 — Främre armbågen vid toppen (FO)

- `framre_armbage_topp`: främre axel–armbåge–handled, **böjningen i grader,
  0 = rak arm**. Handleden är armens egen: greppregeln (M1) ersätter en dold
  handled med den andra, vilket duger för händernas läge men inte för en vinkel
  i armbågen. Är den främre handleden dold saknas måttet. För en högerspelare vänsterarmen. Framifrån ligger armen
  ungefär i bildens plan vid toppen; förkortningen gör vinkeln osäker, därför
  egen baslinje. GolfTEC: 76° mot 10° är ett elevexempel, ingen norm.
  **tillverkare, ej läst i original.**

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
- Minst **3** svingar för en sammanfattning. Research: 8–10 svingar per pass
  ger ett stabilt medel (Boise State, n = 10). **forskning, ej läst i
  original.**
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
  i samma vy. Med `samre` = "+" räknas bara z uppåt som sämre, "−" bara nedåt,
  annars |z|. Upp till **1** = grönt, upp till **2** = gult, längre = rött.
  Baslinjen kräver minst **8** svingar (research 1 del 4). **antagande.**
- `kontrollerad: false` = källan är inte läst i original (BESLUT B10).
  Gränsen används ändå, märkt. Ett fel med `aktiv: false` bedöms inte
  (axellutningen, M17).

## M28 — P-positionerna

- Golfens P-positioner som går att mäta ur kroppens leder (BESLUT B32): **P1
  Adress** = adressens fönster (M4; tiden för videon är fönstrets mitt, måtten
  är fönstrets medel), **P4 Topp** = toppen (M4), **P7 Träff** = klicket (M4),
  **P10 Finish** = finishens fönster (M4, tiden i mitten). P2, P6 och P8
  definieras av klubbskaftet och kommer med S7. **tränare** (P-systemet, 10
  positioner), **antagande** (hur de mäts ur lederna).
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
Sportsbox motsvarighet är 3D ur en egen modell och **ej läst i original**
(BESLUT B10), så talen jämförs inte med Sportsbox, bara pass mot pass. Alla har
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
- **Det är inte Sportsbox Pelvis Bend** (bäckenets lutning). Den kräver en punkt
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
  och träff). Höjdled ligger i bildens plan i båda vyerna. Sportsbox: Chest
  Lift. Bakifrån hör `brost_lyft_traff` till felet `tappad_hallning`.
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
  Flexion. Knäets sträckning mot träffen är det intressanta.
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
  P10; katalogen visar topp och träff). Sportsbox: Lead/Trail Knee Sway.
  `bakre_kna_sway_topp` (bakre knät glider bort från målet i baksvingen) hör
  till felet `sway_topp`.
- Uppmätt: exakt (figurens knän står still på platåerna); med 0,8 px brus sd
  0,10–0,14 cm, största 0,34.

## M35 — Handens fart och när den är störst (FO)

- `handfart_max`: greppets **största fart i nedsvingen** (toppen → träffen),
  **m/s med en decimal**, i bildens plan. `handfart_max_fore_traff_ms`: hur långt
  **före träffen** den största farten kommer, ms, + = före. Sportsbox: Max Hand
  Speed och Hand Speed Max Timing (Johannes lista, **ej bekräftade**). Framifrån,
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

- `genomsving_s` = finishen − träffen, s. Sportsbox: Follow Through Time
  (Johannes lista, **ej bekräftad**).
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
  bildens plan. Vänsterarmen för en högerspelare. Sportsbox: Max Lead Arm
  Speed (Johannes lista, **ej bekräftad**; Sportsbox mäter i 3D).
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
`matt` vid P4 utan `fel`, i Python och Swift med samma tal (BESLUT B12). Ingen
Sportsbox-definition med samma innehåll är hittad (research 4; Sportsbox är **ej
läst i original**, BESLUT B10).

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
  bröstet: bröstets egen rörelse är `brost_thrust_topp` (M10). Om Sportsbox har en
  Thrust för greppet (6 DoF, research 4) är okänt. **antagande.**
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
  **tillverkare** (Apples CoreMotion), **antagande** (takten: 30 prov i fönstret nedan).
  Kräver ingen tillåtelse: `NSMotionUsageDescription` gäller rörelseaktiviteten och
  stegen (`CMMotionActivityManager`, `CMPedometer`), inte `CMMotionManager`.
  **tillverkare, ej läst i original.**
- **Medianen** per axel över **1,0 s** före seriens första klick (stativet står still och
  ingen har rört telefonen sedan starten), med minst **10** prov. Är fönstret inte stilla,
  saknas klicket eller värdklockan: seriens **stillastående sekunder** (sekunden från
  första provet, var och en med minst 10 prov och stilla), när de är eniga med varandra.
  **antagande.**
- **Spärren för rörelse:** spridningen, den största vinkeln mellan ett prov och
  medianen, över **1,0°** är rörelse. Rör sig telefonen i fönstret och i de stilla
  sekunderna, eller är de stilla sekunderna inte eniga (stativet flyttat mitt i serien),
  sparas `rorelse` i `pass.json` och fältet skrivs inte; PC:n tar då kamerornas vågräta
  (MK3). Felbudgeten ger 0,5–3° fel i lodlinjen under slumpfelet (S6_FELBUDGET §6.5), så
  1° är en telefon som vrider sig, inte brus. **antagande** (kalibreras på telefonen:
  `spread` står i `pass.json`).
- **Kamerans ram** (docs/FORMAT.md): uppåt = −gravitationen. Bakre kamerans lagrade bild
  (EXIF 1) är sensorns liggande bild med telefonens överkant åt vänster: höger = −y,
  ned = −x, framåt ur linsen = −z i enhetens ram. Filens EXIF-orientering (MS7) vrider
  den till den upprätta bilden: 6 (stående, appens läge) 90° medurs, 3 ett halvt varv,
  8 90° moturs. En rak stående telefon ger `[0, -1, 0]`. **standard** (CoreMotions och
  AVFoundations ramar), prövad åt båda håll med påhittade telefoner i stående och
  liggande (`tools/tests/fixturer/lodlinje.json`: `LodlinjeTests.swift` och
  `test_lodlinje.py` mot `paket.lodlinjen`). **Oprövad på telefonen.**
- **Fältet skrivs** med fyra decimaler (0,006°) bara när PC:ns kontroll tar det (längden
  0,8–1,2 g och y < 0, MK3) och uppåt lutar högst **45°** från bildens överkant. Mer är en
  telefon som stod i en annan orientering än filens (liggande i en stående fil), där
  lederna inte heller står upp (MS7). **räkning** (45° är gränsen mellan två
  orienteringar).
- **Vad som provas var.** Linux (`LodlinjeTests`): ramen i fyra orienteringar, medianen,
  fönstret, spärren, manifestet med och utan fältet och ett gammalt pass. Simulatorn
  (`SwingLabProvPaket`, ingen rörelse): ett pass utan lodlinje paketeras och läses av
  PC:n, och injicerade prov skrivs rätt och läses av `paket.py`. Telefonen: att
  `gravity` och tiden är det som antas här, och spridningen på stativet.

---

# Tolkningen (S5)

Konstanterna i PC-länken (`tools/pc/paket.py`, `analys.py`, `historik.py`,
`att_jobba_pa.py`, `kontaktark.py`) och reglerna som skillen `svinganalys`
tolkar efter. Numreringen MT hålls skild från M (mätningen) och MS
(inspelningen), så att grenarna inte krockar. Tolkningen räknar inget själv
(BESLUT B2): varje tal och varje "klart när" kommer ur analysen.

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
  M35–M37), samma tal som appen visar. **antagande.**
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
- **Fysiken:** **42** dagar (sex veckor) från första gången felet valdes, utan
  någon tydlig rörelse sedan dess över alla övningar för felet, och treregeln
  inte prövad än → pröva treregeln (research 3 §4 förslag 6). **antagande.**
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
  med flest mätta slag, FO vid lika. Baslinjen för de felen tas ur samma vy.
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
  (slumpade med frö 0). Viktad normaliserad åttapunktsmetod med robusta varv och
  förfining på Sampson-felet (Hartley 1997, `tre_d/kalibrering.py`).
  **standard** (metoden), **antagande** (talen). Skalan är okänd: vinklar behöver
  ingen.
- **Spärren:** Sampson-felets median, i px på en 1920 px långsida, över **8 px**
  ger ingen mätning för uppställningen (`hoppat` i `kalibrering[]`); hoppas alla
  över blir `tre_d.hoppat`. Uppmätt på facit (10 slag): bra brus 2,9 px, typiskt
  4,7, dåligt 9,2, mycket dåligt 14,1. Spärren ligger mellan typiskt och dåligt,
  där passets median enligt felbudgeten blir 18–21° fel (§6.7). **antagande.**
- **Lodlinjen:** ur manifestet (`serier[].lodlinje`, uppåt i kamerans ram, g) när
  någon vy bär den: FO:s direkt, DTL:s vriden till FO, båda = summan. Fältet
  används bara med längden **0,8–1,2 g** (telefonen i vila på stativet) och med
  uppåt mot bildens överkant (y < 0 i kamerans ram): en vänd vektor vänder
  måtten (granskningen, utan brus: höfterna vid träffen −36° mot +36°). Ett fält
  som inte går att använda stoppar aldrig paketet: skälet (utan värden) står i
  `kalibrering[].lodlinje_fel` och i `tre_d.osaker`, och uppställningen tar
  kamerornas vågräta (BESLUT B39). Utan fältet: **kamerornas vågräta**, uppåt
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
  synkens rest under 0,1 ms utan brus, RMS 1,5 ms med bra brus och 2,4 ms med
  typiskt (24 pass).

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
  §6.7): bäckenet **15,7°**, bröstet **13,6°**, X-factor **19,2°**, stretchen
  **8,1°**, höfterna vid träffen **8,3°**. Kamerornas läge, kalibreringen och
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
