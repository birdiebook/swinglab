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
