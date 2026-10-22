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

- **Rutnätet** = 1 / medel av de korta stegen, avrundat till heltal, där de
  korta är de positiva stegen upp till **1,75 ×** 5:e percentilen (linjär
  interpolation), mellan avrundningens 3/2 och en tappad rutas 2. Medlet tål en grov tidsskala: en film i standardskalan 600
  har 1/240 s som steg om 2 och 3 enheter, och percentilen ensam gav 300 bilder/s
  i simulatorprovet (S2c: stegen var 2, 3 och 5 enheter); det tål också
  skakning i tiderna. De kortaste stegen,
  inte medianen: oktobers klipp låg på 240-rutnätet med drygt en tredjedel av
  rutorna borta (**mätt**, Golf SG; research 2 §2). Andelen tappade =
  `1 − antal / ((sista − första) · rutnät + 1)`. **Slowmotion** = rutnät ≥
  **100** bilder/s; under det är en import omräknad och vägras (S2_SPEC §5).
  **antagande** (gränsen).
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
- **Avvikelser:** stegen räknas `lo + i·steg` (numpys `arange` gör nästan det),
  och parar inget svaras prior (eller 0), osäker, i stället för sökningens början.

## MS11 — Kvittot, trycket och disken

- **Kvittot** efter varje serie (S2_SPEC §12 S2c): rutnätets frekvens (vit när
  den når 240 − 0,5, gul under, röd under 100 = inte slowmotion, MS1 och MS3),
  tappade rutor (gränserna i MS3), antal rutor, klicken (gul vid noll), filens
  storlek per minut i MB (10⁶ byte, `byte / längd · 60`), längden och det högsta
  värmetrycket under serien. **räkning**; storleken per minut mäts på telefonen
  i S2c (S2_SPEC §2.6 antog några hundra MB i 1080p 240 HEVC).
- **Trycket** (`systemPressureState.level`): nominal och fair vita, serious gul
  och en varning i vyn, critical och shutdown röda. Apple: systemet kan sänka
  kvaliteten under tryck och avbryter sessionen vid shutdown. **tillverkare +
  antagande** (gränsen för varningen).
- **Disken:** under **4 GB** ledigt (`volumeAvailableCapacityForImportantUsage`)
  startar ingen inspelning, och `minFreeDiskSpaceLimit` = **2 GB** stoppar en
  pågående. **antagande** (en minut i 240 bilder/s är några hundra MB).
- **Ljudet ur filen** läses i bitar som klipps exakt vid `ClickDetector.segments`
  (30 s med 1 s överlapp, räknat i prov från filens första ljudprov), med de
  inre gränserna till `detect` (MS4). Omsamplat ljud (AAC 44,1 kHz stereo → 48 kHz
  mono) gav i simulatorn 153 548 och 153 549 prov i två läsningar av samma fil:
  bitarnas gränser följer proven, så telefonen och PC:n kan skilja i sista biten
  på ett omsamplat ljud. Klicken hamnade ändå inom 0,6 ms från de påhittade
  (LPCM inom 0,5 ms). **mätt** i simulatorprovet, påhittad film. `ClickStream` ger samma klick som
  `detectSegmented` på hela signalen och som PC:ns `klick_i_bitar`, provat med
  buffertar av slumpad storlek på recepten `lang` och `bitgrans`. **räkning.**

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
- Talen avrundas till **0,1** (cm, grader) och **0,01** (tempo, stansen,
  sekunder), samma tal som appen visar. **antagande.**
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
  som fälls på ordstam: `bra`, och ord som börjar på bäst, bättr, sämr, fin,
  duktig, topp, dålig, perfekt, utmärk, fantastisk, snygg, grym, super med
  flera (listan i `att_jobba_pa.py`). Undantag: finish…, finn…, fing…, final…,
  och "toppen" efter en preposition eller före "av" (fasen, platsen).
  **antagande** (gränserna); katalogens längsta tanke är 56 tecken.
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
