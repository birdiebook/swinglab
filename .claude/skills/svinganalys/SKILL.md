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
3. **Läs.** `analys.json` (`kandidater`, `bedomning`, `forra`, `tempo_vy`),
   minnet, och kontaktarken med Read-verktyget. Fråga Johannes det som bara han
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
   telefonen (Filer eller AirDrop → "Hämta Att jobba på", BESLUT B28).
7. **Rapporten** till Johannes, i chatten (se Utdata).

## Beslutsförfarandet

Gå igenom stegen i ordning. Varje regel kommer ur
`docs/research/3_tolkning_och_appar.md` (ej läst i original, BESLUT B10) och har
en METOD-rad (MT1–MT10).

**A. Läget för förra valet först.** Läs bara övningar i minnet (`ovningar`)
med `aktuell: true`. En övning med `lage: "avslutad"` (klar och släppt, eller
bortvald) är historia: den väcks aldrig, och dess fel börjar ett nytt block om
det väljs igen. För de aktuella:
- `klart` (klart när hölls på första serien två pass i rad): saken lämnar
  listan. Skriv det i rapporten som tal ("−0,4 → 0,3 cm, två pass").
- `fortsatt` eller `ny`: behåll samma sak och samma övning, med **samma "klart
  när" och märkning som när övningen valdes** (minnets `klart_nar` och
  `markning`), och samma `block.start`. Steget står kvar eller tar nästa
  (`steg`, METOD MT10). Byt inte en övning som rör sig, och byt inte efter ett
  enda pass.
- `byt_ovning` (4 pass i rad utan tydlig rörelse, METOD MT5): behåll felet och
  blocket men välj en annan övning för det ur `tools/pc/kedjor.json`
  (`kalla: "research3"`), aldrig en som står i `forra_ovningar`. Den nya
  övningen börjar på första steget och får analysens "klart när".
- `fysik` (sex veckor från första gången felet valdes, utan tydlig rörelse över
  alla dess övningar): gå till steg G innan något annat.

**B. Kandidaterna.** Utgå från `kandidater` i analysen (gula och röda fel,
redan i läsordning, METOD MT6). Ett grönt fel övas aldrig. Ett `okand` fel
(ingen gräns och ingen baslinje än) får väljas bara när `kandidater` är tom
och analysen har ett `klart_nar` för det.

**C. Missen avgör (bollflykten är domaren).** Fråga Johannes passets
vanligaste miss (tunn, fet, push, pull, slice, hook) om han inte sagt den. Ett
fel som inte kan förklara missen flyttas ned; ett avvikande mått med bra träff
och flykt är inte ett fel. Utan svar: fortsätt, och skriv att missen saknades.

**D. Grundorsaken först, en kedja per sak.** Ett fel med `foljdfel: true` i
kandidaterna har en flaggad orsak i `kedjor.json`. Det blir **aldrig** en egen
sak, inte heller ensamt: det står under orsakens `foljdfel` och mäts, men övas
inte. Skriv varje följdfel med kedjans hela väg (`vag`, saken först), även när
det ligger flera led bort, och analysens tal. Två saker får inte ligga i samma
kedja. Kedjor som inte står i `kedjor.json` finns inte för skillen.

**E. Tidigt i svingen före sent.** Adress → topp → nedsving → träff → efter
träffen. Sakerna står i den ordningen. Tempot har låg prioritet och väljs bara
när inget annat är flaggat; det tas ur en vy (`tempo_vy`, METOD MT9).

**F. Välj 1–3.** Helst **en** sak att öva; högst två till. Fler än tre fäller
kontrollen. Hellre en sak med en tydlig kedja än tre lösa.

**G. "Troligen rörlighet" bara enligt treregeln** (METOD MT5). Fråga Johannes:
(1) syns felet i full sving (analysen svarar), (2) fallerar ett kopplat test
(`fysik` i kandidaten, ur `kedjor.json`), (3) går rörelsen inte heller långsamt
utan klubba. Alla tre ja → `typ: "troligen_rorlighet"` med en rörlighetsövning.
1 och 2 men inte 3 → `"teknik_kroppen_gor_det_svart"`. Annars `"teknik"`, med
svaren i `fysik.treregeln` och `fysik.ovning: null`. Utan Johannes svar:
`fysik: null` och teknik, utom när minnet säger `fysik` (då fäller kontrollen
`null`). Säg "troligen", aldrig "är".

**H. Gränsens vikt.** Står `markning: "B10"` är gränsen inte läst i original; står
`"egen"` är det Johannes egen baslinje (eller passet självt, `grund: "nu"`). Väg
därefter: ett rött mot en kontrollerad gräns väger mer än ett gult mot en
egen baslinje på 8 svingar. Säg i rapporten vilken sort varje gräns är.

**I. Övningen, stegen och tanken.** Övningen är aldrig fritext: katalogens
ordagrant (`kalla: "katalog"`) eller en av felets övningar i `kedjor.json`
(`kalla: "research3"`). En ny övning börjar på `langsamt_med_foremal`; sedan
halv fart, full fart, varierat, ett steg i taget när Johannes klarar steget.
Tanken skrivs på engelska och har **extern fokus**: vad klubban, bollen eller ett
föremål (stol, käpp, vägg, headcover) gör, aldrig vad en led gör ("Don't touch
the stick", inte "Keep your hip still"). Högst 60 tecken, inga siffror.

**J. "Klart när" som ett villkor i tal på första serien.** En ny övning: skriv
av analysens `klart_nar` för felet (`villkor`, `grans`) och dess `markning`.
En övning som fortsätter: minnets, oförändrat. Alltid `pa: "forsta_serien"`
(de fem första slagen i serie 1, före uppvärmningen, METOD MT2) och
`pass_i_rad: 2`. Ett tal som inte står i analysen eller minnet finns inte.

**K. Blocket.** `block.start` är dagen då felet först valdes (minnets
`fel_start`, eller passets dag för ett nytt fel), `vecka` hela veckor sedan
dess + 1. Ett block är 4–6 veckor per grundorsak (research 3 §4).

## Det Claude inte får göra

- **Mäta själv.** Inget tal skattas ur kontaktarket, videon eller lederna.
  Varje tal i filen och rapporten kommer ur `analys.json` eller minnet
  (BESLUT B2); `att_jobba_pa.py --analys` fäller ett eget.
- **Hitta på gränser, kedjor, övningar eller test.** Gränserna kommer ur
  katalogen, analysens förslag eller minnet; kedjorna, övningarna och testen ur
  `kedjor.json`. Saknas något: säg det, och föreslå en rad med källa i
  rapporten i stället.
- **Flytta "klart när"** för en övning som fortsätter.
- **Ändra `katalog.json` eller `kedjor.json`** under en tolkning. Ändringar där
  är egna commits med källa (BESLUT B6, B10).
- **Värdeord eller siffror i appens fritext** (BESLUT B13): inget "good",
  "better", "best", "great", "nice", "perfect", inga utropstecken, ingen
  totalpoäng. Förändring är tecken och tal i rapporten ("+2,2 cm mot 3 nov").
  Kontrollen fäller värdeord på ordstam (engelska listan, METOD MT8).
- **Svenska i appens text** (BESLUT B30): filens fritext är engelska.
- **Ge ett följdfel en egen övning**, väcka en avslutad övning, eller byta en
  övning som rör sig.
- **Säga att något är rörlighet** utan treregeln, eller säga "är" i stället för
  "troligen".
- **Lägga in riktig data i repot** eller skriva ut Johannes tal i en commit.

## Utdata

1. **`att_jobba_pa.json`**, kontrollerad (steg 5) och sparad (steg 6).
2. **Rapporten** i chatten, högst 8 rader (påhittade tal):
   ```
   Pass 3 nov, 16 slag (8 FO, 8 DTL), j7. Missen: tunn (Johannes).
   1. Bäckenet glider bakåt i baksvingen: −5,7 cm, grönt ≥ 0 (B10). Rött.
      Kedjan: → reverse spine → early extension; → resan framåt → tappad hållning; → sway gap.
      Övning: käppen vid bakre höften, långsamt med käppen. Tanke: "Don't touch the stick."
      Klart när: första serien ≥ 0 cm, två pass i rad. Block vecka 1.
   Förra valet: — (första passet).
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
flaggad (rött mot ≥ 0, B10). Valet är
`tools/tests/fixturer/att_jobba_pa_exempel.json`: en sak, katalogens övning på
första steget, följdfelen ur kedjorna med hela vägen (även early extension
två led bort), klart när första serien ≥ 0 cm två pass i rad, block vecka 1.
Pass 2: första serien rörde sig tydligt (−5,5 → −3,3 cm, mer än pass 1:s
spridning) men klarar inte villkoret, så läget är `fortsatt`: samma övning,
nästa steg (`halv_fart`), samma "klart när". Resan framåt och tappad hållning
är röda mot baslinjen men följdfel av `sway_topp`, så de får ingen egen övning.

## BESLUT-förslag (för Johannes; flyttas till docs/BESLUT.md när de godkänts)

- **F-S5-1 — Kedjorna och testen i `tools/pc/kedjor.json`, inte i katalogen.**
  Valt: en egen fil som bara PC:n läser, med källa och status per kedja.
  Bortvalt: fält i `katalog.json`, som appen läser och vars ordagranna kopia
  ligger i Swift-fixturerna (BESLUT B12): varje ändring av en kedja hade krävt
  nya fixturer. Omprövas om appen ska rita kedjan (research 3 (c)).
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
