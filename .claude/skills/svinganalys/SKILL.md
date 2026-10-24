---
name: svinganalys
description: Tolka ett SwingLab-pass på PC:n och skriv "Att jobba på" till telefonen. Använd ALLTID när Johannes delar ett sessionspaket (swinglab-<pass>-<vy>.zip), ber om en analys eller tolkning av ett pass, frågar vad han ska öva, eller vill ha en ny att_jobba_pa.json. Kör paketet → analysen → historiken med verktygen i tools/pc/, och väljer 1–3 saker efter reglerna här (research 3), utan att mäta något själv.
---

# Svinganalys — paket → analys → Att jobba på

Mätningen är mekanisk och Claude tolkar (BESLUT B2). Koden i `tools/pc/` räknar
varje tal; skillen väljer vad som är viktigast, i vilken ordning, med vilken
övning och när det är klart. Tolkningen körs i Claude Code på PC:n, inom
abonnemanget (BESLUT B4).

**Dataregeln (CLAUDE.md):** Johannes paket, analyser och val stannar i `data/`
(gitignorerad). Inget av det hamnar i repot, i en commit, i ett test eller i
minnesanteckningar. Repot är publikt (BESLUT B7). `session.py` vägrar en
utmapp i repot utanför `data/`. Exemplen här är påhittade.

På Windows heter kommandot `python`, inte `python3`.

**Språket (BESLUT B30):** allt i `att_jobba_pa.json` visas i appen som det står
och skrivs därför på **engelska**: katalogens och kedjornas namn och övningar
(redan engelska, skrivs av ordagrant), tanken och rörlighetsövningen. Kontrollen
fäller å, ä och ö i fritexten. **Rapporten till Johannes i chatten får vara
svensk.**

## Kommandona

Lägg paketen i `data/inkorg/` (eller där Johannes säger att de ligger).

1. **Analysen.** Ett paket per vy, samma pass:
   ```
   python3 tools/pc/session.py data/inkorg/swinglab-<pass>-fo.zip data/inkorg/swinglab-<pass>-dtl.zip
   ```
   Första gången: lägg till `--langd <m>` (Johannes längd i meter, som han
   anger; den sparas bara i `data/historik/spelare.json`). Skriver
   `data/historik/pass/<pass>/analys.json` och ett kontaktark per vy med klipp.
   Förra passet och baslinjen tas ur historiken; `--forra <paket> …` om förra
   passet bara finns som paket. Stoppar kommandot på ett formfel eller en
   skadad zip: visa raderna för Johannes (de nämner fil och fält, aldrig
   värden) och gissa inte vidare.
2. **Minnet.** Vinterns väg och övningarnas läge:
   ```
   python3 tools/pc/historik.py minne
   ```
   Står pass i `kor_om` mättes de med en äldre version av måtten (METOD M40): kör
   session.py igen för dem (paketen) och läs minnet på nytt, innan du jämför.
3. **Läs.** `analys.json` (`kandidater`, `bedomning`, `forra`, `tempo_vy`,
   `tre_d`; ett pass med flera klubbor har huvudklubban överst och de andra i `delar`,
   och filen gäller huvudklubban, BESLUT B56), minnet (med `tre_d`, 3D-trenden pass för pass), och kontaktarken med
   Read-verktyget. Fråga Johannes det som bara han
   vet (steg C och G nedan) innan du väljer.
4. **Skriv** `data/historik/pass/<pass>/att_jobba_pa.json` efter kontraktet i
   `docs/FORMAT.md` ("Att jobba på"). Formen är stängd: inga egna nycklar.
5. **Kontrollera** mot analysen och minnet, och rätta tills det är OK
   (`--analys` krävs; kontrollen hoppas aldrig över):
   ```
   python3 tools/pc/att_jobba_pa.py data/historik/pass/<pass>/att_jobba_pa.json --analys data/historik/pass/<pass>/analys.json
   ```
6. **Spara** i historiken (kontrollerar en gång till och vägrar utan analys):
   ```
   python3 tools/pc/historik.py spara-att-jobba-pa data/historik/pass/<pass>/att_jobba_pa.json
   ```
   Filen `data/historik/att_jobba_pa/<pass>.json` är den Johannes delar till
   telefonen (Filer eller AirDrop, i appen "Import focus" under Me → Sessions, BESLUT B28).
7. **Rapporten** till Johannes, i chatten (se Utdata).

## I Claude-appen: texten från telefonen (S5b)

Tolkningen går också att göra i Claude-appen på telefonen, utan PC och utan API-nyckel
(BESLUT B52). Appen kopierar en text ("Ask Claude") med reglerna nedan och passets data,
räknad på telefonen; Johannes klistrar in den i Claude-appen och kopierar svaret tillbaka
("Paste from Claude"), där det kontrolleras som på PC:n. Texten är avsnitten mellan
markörerna `claude-appen`, ordagrant och i den ordning de står: `python3
tools/pc/underlag.py --swift` för över dem till appen, och ett prov fäller en skillnad
(BESLUT B53). På PC:n skriver `session.py --claude-text` samma text, så att den går att
pröva mot skillens fulla väg.

<!-- claude-appen -->
**Claude-appen.** Johannes har kopierat texten i SwingLab ("Ask Claude") och klistrat in
den här. Datan längst ned är räknad på telefonen med samma regler och fältnamn som på
PC:n, för passets `klubba` och de tidigare passen med samma klubba, vy och längd:
`kandidater` och `bedomning` ur analysen (felen som inte är gröna; `visat` är talet som
visas, `forsta_serien` första seriens median, `grund` gräns eller egen baslinje, `baslinje`
dess median, sd och svingar, `mot_forra` mot förra passet), `ovningar` ur minnet,
`historik` felens `[visat, status]` pass för pass, `pagaende` den senaste "Att jobba på",
och `mallar` med analysens eller minnets "klart när" och märkning. Kedjorna är
kandidaternas `orsaker` och mallarnas `foljdfel`, övningarna `ovning_val` och testen
`fysik_test`. Följ stegen A–I.

**Frågorna.** Fråga inte efter missen (steg C); Johannes kan ha skrivit den efter texten.
Säger minnet `fysik` för ett fel: ställ treregelns frågor 2 och 3 (steg G) och skriv inget
kodblock förrän han svarat.

**Svaret.** Först rapporten på svenska, högst 9 rader: varje sak med talet, gränsen och
gränsens sort (steg H), kedjan, övningen och tanken; förra valets läge; missen eller att
den saknades. Sist **ett** kodblock ```json med filen: `fil`s fält med `saker` tillagd,
inget yttre objekt och inga egna nycklar. Varje sak byggs ur sin mall i `mallar`, med
fälten i den här ordningen: `ordning` (1, 2, 3 i svingens ordning); mallens `fel`, `namn`,
`vy`, `matt`, `enhet`, `nu`, `spann` och `markning` ordagrant; `ovning` = ett av
`ovning_val` (`id`, `text`, `kalla`) med en `tanke` (steg I) och ett `steg` ur `steg_val`;
mallens `klart_nar`, `foljdfel` och `block` ordagrant; `typ` och `fysik` efter steg G
(`"teknik"` och `null` utan treregelns svar). Ta inte med `grund`, `ovning_val`,
`steg_val` eller `fysik_test`. Ett fel utan mall går inte att välja. All text i filen är
engelska. Telefonen kontrollerar filen som PC:n och tar emot den bara när allt stämmer.
<!-- /claude-appen -->

## Beslutsförfarandet

Gå igenom stegen i ordning. Varje regel kommer ur
`docs/research/3_tolkning_och_appar.md` (ej läst i original, BESLUT B10) och har
en METOD-rad (MT1–MT10).

<!-- claude-appen -->
**A. Läget för förra valet först.** Läs bara övningar i minnet (`ovningar`)
med `aktuell: true`. En övning med `lage: "avslutad"` (klar och släppt, eller
bortvald) är historia: den väcks aldrig, och dess fel börjar ett nytt block om
det väljs igen. För de aktuella:
- `klart`: saken lämnar listan. Med `klart_skal: "klart_nar"` hölls "klart när" på
  första serien två pass i rad: skriv det i rapporten som tal ("−0,4 → 0,3 cm, två
  pass"). Med `"inte_flaggat"` är felet grönt i senaste passet, ofta för att
  katalogens gräns flyttats medan övningen pågick (BESLUT B45): skriv "klar, inte
  längre flaggat" med talet och gränsen, och ta aldrig bort saken tyst. "Klart när" och
  märkningen från valet står kvar i minnet men gäller inte längre.
- `fortsatt` eller `ny`: behåll samma sak och samma övning, med **samma "klart
  när" och märkning som när övningen valdes** (minnets `klart_nar` och
  `markning`), och samma `block.start`. Steget står kvar, eller tar nästa när
  den senaste uppföljningen är `tydlig` (`steg`, METOD MT10). Byt inte en övning
  som rör sig, och byt inte efter ett enda pass.
- `byt_ovning` (4 pass i rad utan tydlig rörelse, METOD MT5): behåll felet och
  blocket men välj en annan övning för det ur kedjorna (`kalla: "research3"`),
  aldrig en vars `id` står i `forra_ovningar`. Den nya övningen börjar på första
  steget och får analysens "klart när". Är alla provade: välj inte felet, och säg
  att treregeln (steg G) är nästa steg.
- `fysik` (sex veckor från första gången felet valdes, utan tydlig rörelse över
  alla dess övningar, och felet har ett test): gå till steg G innan något annat.

**B. Kandidaterna.** Utgå från `kandidater` i analysen (gula och röda fel,
redan i läsordning, METOD MT6). Ett grönt fel övas aldrig. Ett `okand` fel
(ingen gräns och ingen baslinje än) får väljas bara när `kandidater` är tom
och analysen har ett `klart_nar` för det.

**C. Missen avgör (bollflykten är domaren).** Passets vanligaste miss (tunn,
fet, push, pull, slice, hook) kommer från Johannes; på PC:n frågar du om han inte
sagt den. Ett fel som inte kan förklara missen flyttas ned; ett avvikande mått med
bra träff och flykt är inte ett fel. Utan svar: fortsätt, och skriv att missen
saknades.

**D. Grundorsaken först, en kedja per sak.** Ett fel med `foljdfel: true` i
kandidaterna har en flaggad orsak i kedjorna. Det blir **aldrig** en egen
sak, inte heller ensamt: det står under orsakens `foljdfel` och mäts, men övas
inte. Skriv varje följdfel med kedjans hela väg (`vag`, saken först), även när
det ligger flera led bort, och analysens tal. Två saker får inte ligga i samma
kedja. Kedjor som inte står i kedjorna finns inte för skillen.

**E. Tidigt i svingen före sent.** Adress → topp → nedsving → träff → efter
träffen. Sakerna står i den ordningen. Tempot har låg prioritet och väljs bara
när inget annat är flaggat; det tas ur en vy (`tempo_vy`, METOD MT9).

**F. Välj 1–3.** Helst **en** sak att öva; högst två till. Fler än tre fäller
kontrollen. Hellre en sak med en tydlig kedja än tre lösa.

**G. "Troligen rörlighet" bara enligt treregeln** (METOD MT5). Frågorna:
(1) syns felet i full sving (analysen svarar), (2) fallerar ett kopplat test
(`fysik` i kandidaten), (3) går rörelsen inte heller långsamt utan klubba
(Johannes svarar på 2 och 3). Alla tre ja → `typ: "troligen_rorlighet"` med en rörlighetsövning.
1 och 2 men inte 3 → `"teknik_kroppen_gor_det_svart"`. Annars `"teknik"`, med
svaren i `fysik.treregeln` och `fysik.ovning: null`. Utan Johannes svar:
`fysik: null` och teknik, utom när minnet säger `fysik`: då krävs svaren (kontrollen
fäller `null`). Säg "troligen", aldrig "är".

**H. Gränsens vikt.** Står `markning: "B10"` är gränsen inte läst i original; står
`"egen"` är det Johannes egen baslinje (eller passet självt, `grund: "nu"`); `null` är
en gräns vars källa är läst i original (sedan research 5: swayen, tempot och early
extension, BESLUT B45). Väg
därefter: ett rött mot en kontrollerad gräns väger mer än ett gult mot en
egen baslinje på 8 svingar. Säg i rapporten vilken sort varje gräns är.

**I. Övningen, stegen och tanken.** Övningen är aldrig fritext: katalogens
ordagrant (`kalla: "katalog"`) eller en av felets övningar i kedjorna
(`kalla: "research3"`), med dess id i `ovning.id` (katalogens `ovning_id` eller
övningens `id` i kedjorna). Samma id = samma övning, även om texten skrivits om.
En ny övning börjar på `langsamt_med_foremal`; sedan
halv fart, full fart, varierat, ett steg i taget när Johannes klarar steget (den
senaste uppföljningen är `tydlig`).
Tanken skrivs på engelska och har **extern fokus**: vad klubban, bollen eller ett
föremål (stol, käpp, vägg, headcover) gör, aldrig vad en led gör ("Leave the stick
standing", inte "Keep your hip still"). Högst 60 tecken, inga siffror.

<!-- /claude-appen -->

**J. "Klart när" som ett villkor i tal på första serien.** En ny övning: skriv
av analysens `klart_nar` för felet (`villkor`, `grans`) och dess `markning`.
En övning som fortsätter: minnets, oförändrat. Alltid `pa: "forsta_serien"`
(de fem första slagen i serie 1, före uppvärmningen, METOD MT2) och
`pass_i_rad: 2`. Ett tal som inte står i analysen eller minnet finns inte.

**K. Blocket.** `block.start` är dagen då felet först valdes (minnets
`fel_start`, eller passets dag för ett nytt fel), `vecka` hela veckor sedan
dess + 1. Ett block är 4–6 veckor per grundorsak (research 3 §4).

## 3D-trenden: vridningen och X-factor (S6a)

När passet har ett DTL- och ett FO-paket räknar `session.py` vridningen i 3D
(`tre_d` i analysen, BESLUT B37, METOD MK1–MK7). Läget är **utan markörer**
(BESLUT B14): talen är passets median, aldrig en sving.

- Läs `tre_d.trend`: bäckenets och axlarnas vridning vid toppen, X-factor, stretchen
  och höfterna vid träffen, med `median`, `kvartiler`, `n` och `mot_forra`. Står
  `median: null` har passet färre än `min_slag` (10) slag i båda vyerna: säg det, och
  skriv inget tal. Står `tre_d.hoppat`: skriv skälet i en rad.
- **Bara som trend.** Inget 3D-mått bedöms grönt, gult eller rött, och inget blir en
  sak i `att_jobba_pa.json` (kontrollen känner inte dem). Trenden **påverkar aldrig
  valet** (BESLUT B14, B37): den står i rapporten som en egen rad, märkt "trend, utan
  markörer" ("stretch 9°, ingen tydlig ändring").
- **Tydlig** förändring bara när `mot_forra.tydlig` är sann: skillnaden är då större
  än både förra passets spridning och golvet för två pass (MK7). Annars: "ingen
  tydlig ändring".
- **Stretchen före X-factor**, och X-factor aldrig mot en gradgräns eller mot
  Sportsbox (definitionen flyttar den cirka 19°). Höfternas `spann` (35–45°) är ett
  riktmärke, inte en bedömning.
- Står något i `tre_d.osaker` (kamerorna utanför 60–120°, lodlinjen i manifestet
  användes inte): säg det i en rad, och att talen därför är osäkrare. En uppställning
  med `hoppat` i `tre_d.kalibrering[]` är inte mätt: säg vilken serie och skälet.

## Klubbans mått (S7a)

Klubbmåtten (`analys.klubba`, `skaft_*`, METOD M46–M49) finns bara på svingar som
Johannes markerat för hand, ofta 2–3 per pass: rapportera dem som en rad med median och
n, och med få svingar som **trend, inte en sak att öva** (BESLUT B47); de väljs aldrig i
`att_jobba_pa.json`.

<!-- claude-appen -->
## Det Claude inte får göra

- **Mäta själv.** Inget tal skattas ur bilderna, videon eller lederna.
  Varje tal i filen och rapporten kommer ur analysen eller minnet
  (BESLUT B2); kontrollen fäller ett eget.
- **Hitta på gränser, kedjor, övningar eller test.** Gränserna kommer ur
  katalogen, analysens förslag eller minnet; kedjorna, övningarna och testen ur
  kedjorna. Saknas något: säg det, och föreslå en rad med källa i rapporten i
  stället.
- **Flytta "klart när"** för en övning som fortsätter.
<!-- /claude-appen -->
- **Ändra `katalog.json` eller `kedjor.json`** under en tolkning. Ändringar där
  är egna commits med källa (BESLUT B6, B10).
<!-- claude-appen -->
- **Värdeord eller siffror i appens fritext** (BESLUT B13): inget "good",
  "better", "best", "great", "nice", "perfect", "pure", "crisp", "well done", inga utropstecken, ingen
  totalpoäng. Förändring är tecken och tal i rapporten ("+2,2 cm mot 3 nov").
  Kontrollen fäller värdeord på ordstam (engelska listan, METOD MT8).
- **Svenska i appens text** (BESLUT B30): filens fritext är engelska.
- **Ge ett följdfel en egen övning**, väcka en avslutad övning, eller byta en
  övning som rör sig.
<!-- /claude-appen -->
- **Välja ett 3D-mått som sak, bedöma det mot en gräns, eller rapportera det per
  sving** (BESLUT B14, B37). Det är passets trend, märkt "utan markörer".
<!-- claude-appen -->
- **Säga att något är rörlighet** utan treregeln, eller säga "är" i stället för
  "troligen".
<!-- /claude-appen -->
- **Lägga in riktig data i repot** eller skriva ut Johannes tal i en commit.

## Utdata

1. **`att_jobba_pa.json`**, kontrollerad (steg 5) och sparad (steg 6).
2. **Rapporten** i chatten, högst 9 rader (påhittade tal):
   ```
   Pass 3 nov, 16 slag (8 FO, 8 DTL), j7. Missen: tunn (Johannes).
   1. Bäckenet glider bakåt i baksvingen: −5,7 cm, grönt ≥ −2,5 (kontrollerad gräns). Rött.
      Kedjan: → reverse spine → early extension; → resan framåt → tappad hållning; → sway gap.
      Övning: käppen vid bakre höften, långsamt med käppen. Tanke: "Leave the stick standing."
      Klart när: första serien ≥ −2,5 cm, två pass i rad. Block vecka 1.
   Förra valet: — (första passet).
   3D (trend, utan markörer, 12 slag): stretch 9°, höfter öppna vid träff 38°; ingen tydlig ändring.
   Fil att dela: data/historik/att_jobba_pa/20261103-180000.json
   ```
   Lite text: tal, tecken och kedjan. Ingen beröm, inga värdeord.

## Exemplet (påhittat, körs av `tools/tests/test_exempel.py`)

```
python3 tools/pc/generera_paket.py data/exempel --pass 20261103-180000 --vy fo --serier 2 --utan-langd
python3 tools/pc/generera_paket.py data/exempel --pass 20261103-180000 --vy dtl --serier 2 --utan-langd
python3 tools/pc/session.py data/exempel/swinglab-20261103-180000-*.zip --historik data/exempel/historik --langd 1.80
python3 tools/pc/historik.py --rot data/exempel/historik minne
python3 tools/pc/att_jobba_pa.py tools/tests/fixturer/att_jobba_pa_exempel.json --analys data/exempel/historik/pass/20261103-180000/analys.json --historik data/exempel/historik
python3 tools/pc/historik.py --rot data/exempel/historik spara-att-jobba-pa tools/tests/fixturer/att_jobba_pa_exempel.json
python3 tools/pc/generera_paket.py data/exempel --pass 20261106-180000 --vy fo --serier 2 --seed 2 --sway-topp -3.5 --forsta-serien-flytt -0.5 --utan-langd
python3 tools/pc/generera_paket.py data/exempel --pass 20261106-180000 --vy dtl --serier 2 --seed 2 --utan-langd
python3 tools/pc/session.py data/exempel/swinglab-20261106-180000-*.zip --historik data/exempel/historik
python3 tools/pc/historik.py --rot data/exempel/historik minne
```

Längden 1,80 m hör till den påhittade spelaren. Pass 1: bara `sway_topp` är
flaggad (rött mot ≥ −2,5, kontrollerad gräns, `markning: null`). Valet är
`tools/tests/fixturer/att_jobba_pa_exempel.json`: en sak, katalogens övning på
första steget, följdfelen ur kedjorna med hela vägen (även early extension
två led bort), klart när första serien ≥ −2,5 cm två pass i rad, block vecka 1.
Pass 2: första serien rörde sig tydligt (−5,5 → −3,3 cm, mer än pass 1:s
spridning) men klarar inte villkoret, så läget är `fortsatt`: samma övning,
nästa steg (`halv_fart`), samma "klart när". Resan framåt och tappad hållning
är röda mot baslinjen men följdfel av `sway_topp`, så de får ingen egen övning.

## BESLUT-förslag (för Johannes; flyttas till docs/BESLUT.md när de godkänts)

- **F-S5-1 — Kedjorna och testen i `tools/pc/kedjor.json`, inte i katalogen.**
  Valt: en egen fil som bara PC:n läser, med källa och status per kedja.
  Bortvalt: fält i `katalog.json`, som appen läser och vars ordagranna kopia
  ligger i Swift-fixturerna (BESLUT B12): varje ändring av en kedja hade krävt
  nya fixturer. Omprövas om appen ska rita kedjan (research 3 (c)). **Ändrat av BESLUT
  B53:** kedjorna följer med till appen som genererad källa (`underlag.py --swift`), för
  Claude-appen.
- **F-S5-2 — Claude skriver av, koden kontrollerar.** Valt: analysen föreslår
  "klart när" och talet som visas för varje fel (METOD MT3), och
  `att_jobba_pa.py --analys` fäller ett tal, en gräns, en kedja eller ett
  test som inte kommer ur analysen eller `kedjor.json`. Varför: BESLUT B2 i kod,
  inte bara i text. Kostnad: Claude kan inte sätta ett mellanmål (halva vägen);
  vill Johannes det blir det en ny regel i MT3.
- **F-S5-3 — Spelarens längd i manifestet.** Valt: valfritt fält
  `spelarens_langd_m` i `manifest.json` (S2f skriver det), annars `--langd` en
  gång och sedan historiken. Bortvalt: att gissa en längd (skalan, M2, bär hela
  längdfelet).
- **F-S5-4 — Första serien.** Valt: de fem första mätta slagen i serie 1
  (METOD MT2). Väntar på design/README.md öppna val 4 (5 slag före
  uppvärmningen) och på hur appen märker serien.
- **F-S5-5 — Övningens läge.** Valt: klart efter 2 pass i rad på första
  serien, byt övning efter 4 pass utan tydlig rörelse, fysiken efter 6 veckor
  (METOD MT4, MT5). Alla tre är antaganden; omprövas efter vinterns första
  block.
- **F-S5-6 — Rapporten i chatten, inte i filen.** Appen visar bara övningen,
  tanken och klart när (BESLUT B13 regel 5). Kedjan och skälen står i chatten.
- **F-S5-7 — Tempot ur en vy.** Valt: gruppen `alla` (tempot) tas ur vyn med
  flest mätta slag, aldrig ur båda ihop (samma sving två gånger, METOD MT9).
  Omprövas när parningen (`par` i manifestet) läses på PC:n: då medel per par.
- **F-S5-8 — MediaPipe och vridningen väntar.** PLAN S5 nämner MediaPipe och tre
  metoder för vridningen. De hör till S3 (facit) och S6 (två kameror); S5 läser
  telefonens leder.
- **F-S5-9 — Formen är kontraktet med appen.** Valt: `att_jobba_pa.json` med
  1–3 `saker[]`, villkor `>=`, `<=` eller `mellan`, kedjan, stegen och blocket
  (docs/FORMAT.md), stängd för okända nycklar. S4:s vy läser den som den är.
- **F-S5-10 — "Klart när" flyttar sig inte, och fysiken räknas per fel.** Valt:
  gränsen från valet gäller så länge övningen fortsätter; blocket och de sex
  veckorna räknas från första gången felet valdes, över bytta övningar
  (METOD MT3, MT5, MT10).
