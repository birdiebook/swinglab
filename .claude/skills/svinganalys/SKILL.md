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
minnesanteckningar. Repot är publikt (BESLUT B7). Exemplen här är påhittade.

På Windows heter kommandot `python`, inte `python3`.

## Kommandona

Lägg paketen i `data/inkorg/` (eller där Johannes säger att de ligger).

1. **Analysen.** Ett paket per vy, samma pass:
   ```
   python3 tools/pc/session.py data/inkorg/swinglab-<pass>-fo.zip data/inkorg/swinglab-<pass>-dtl.zip
   ```
   Första gången: lägg till `--langd 1.80` (Johannes längd; sparas i
   historiken). Skriver `data/historik/pass/<pass>/analys.json` och ett
   kontaktark per vy med klipp. Förra passet och baslinjen tas ur historiken;
   `--forra <paket> …` om förra passet bara finns som paket.
   Stoppar kommandot på ett formfel: visa raderna för Johannes (de nämner fil
   och fält, aldrig värden) och gissa inte vidare.
2. **Minnet.** Vinterns väg och övningarnas läge:
   ```
   python3 tools/pc/historik.py minne
   ```
3. **Läs.** `analys.json` (`kandidater`, `bedomning`, `forra`), minnet, och
   kontaktarken med Read-verktyget. Fråga Johannes det som bara han vet (steg C
   och G nedan) innan du väljer.
4. **Skriv** `data/historik/pass/<pass>/att_jobba_pa.json` (schemat i
   `docs/FORMAT.md`, "Att jobba på").
5. **Kontrollera** mot analysen, och rätta tills det är OK:
   ```
   python3 tools/pc/att_jobba_pa.py data/historik/pass/<pass>/att_jobba_pa.json --analys data/historik/pass/<pass>/analys.json
   ```
6. **Spara** i historiken (kontrollerar en gång till):
   ```
   python3 tools/pc/historik.py spara-att-jobba-pa data/historik/pass/<pass>/att_jobba_pa.json
   ```
   Filen `data/historik/att_jobba_pa/<pass>.json` är den Johannes delar till
   telefonen (Filer eller AirDrop → "Hämta Att jobba på", BESLUT B28).
7. **Rapporten** till Johannes, i chatten (se Utdata).

## Beslutsförfarandet

Gå igenom stegen i ordning. Varje regel kommer ur
`docs/research/3_tolkning_och_appar.md` (ej läst i original, BESLUT B10) och har
en METOD-rad (MT1–MT8).

**A. Läget för förra valet först.** För varje övning i minnet (`ovningar`):
- `klart` (klart när hölls på första serien `pass_i_rad` pass i rad): saken
  lämnar listan. Skriv det i rapporten som tal ("−0,4 → 0,3 cm, två pass").
- `fortsatt` eller `ny`: behåll samma sak och samma övning. Byt inte en övning
  som rör sig, och byt inte efter ett enda pass.
- `byt_ovning` (4 pass i rad utan tydlig rörelse, METOD MT5): behåll felet men
  välj en annan övning för det, ur research 3 §2 (`kalla: "research3"`), aldrig
  en som står i `forra_ovningar`.
- `fysik` (sex veckor utan någon tydlig rörelse): gå till steg G innan du väljer
  en ny övning.

**B. Kandidaterna.** Utgå från `kandidater` i analysen (gula och röda fel,
redan i läsordning, METOD MT6). Ett grönt fel övas aldrig. Ett `okand` fel
(ingen gräns och ingen baslinje än) får väljas bara när inget flaggat finns
och analysen har ett `klart_nar` för det.

**C. Missen avgör (bollflykten är domaren).** Fråga Johannes passets
vanligaste miss (tunn, fet, push, pull, slice, hook) om han inte sagt den. Ett
fel som inte kan förklara missen flyttas ned; ett avvikande mått med bra träff
och flykt är inte ett fel. Utan svar: fortsätt, och skriv att missen saknades.

**D. Grundorsaken först, en kedja per sak.** Ett fel med `foljdfel: true` i
kandidaterna har en flaggad orsak i `tools/pc/kedjor.json`. Det blir ingen egen
sak: det står under orsakens `foljdfel` och mäts, men övas inte. Varje sak bär
sin egen kedja; två saker får inte ligga i samma kedja. Kedjor som inte står i
`kedjor.json` finns inte för skillen.

**E. Tidigt i svingen före sent.** Adress → topp → nedsving → träff → efter
träffen. Sakerna står i den ordningen. Tempot har låg prioritet och väljs bara
när inget annat är flaggat.

**F. Välj 1–3.** Helst **en** sak att öva; högst två till. Fler än tre fäller
kontrollen. Hellre en sak med en tydlig kedja än tre lösa.

**G. "Troligen rörlighet" bara enligt treregeln** (METOD MT5). Fråga Johannes:
(1) syns felet i full sving (analysen svarar), (2) fallerar ett kopplat test
(`fysik` i kandidaten, ur `kedjor.json`), (3) går rörelsen inte heller långsamt
utan klubba. Alla tre ja → `typ: "troligen_rorlighet"` med en rörlighetsövning,
testa om om 3–4 veckor. 1 och 2 men inte 3 → `"teknik_kroppen_gor_det_svart"`.
Annars `"teknik"`. Utan Johannes svar är det teknik. Säg "troligen", aldrig "är".

**H. Gränsens vikt.** Står `markning: "B10"` är gränsen inte läst i original; står
`"egen"` är det Johannes egen baslinje (eller passet självt, `grund: "nu"`). Väg
därefter: ett rött mot en kontrollerad gräns väger mer än ett gult mot en
egen baslinje på 8 svingar. Säg i rapporten vilken sort varje gräns är.

**I. Övningen och tanken.** Övningen ur katalogen ordagrant (`kalla:
"katalog"`), eller ur research 3 §2. Tanken har **extern fokus**: vad klubban,
bollen eller ett föremål (stol, käpp, vägg, headcover) gör, aldrig vad en led
gör ("Rör inte käppen", inte "Håll höften stilla"). Högst 60 tecken. Övningen
går långsamt med föremålet → halv fart → full fart.

**J. "Klart när" som ett villkor i tal på första serien.** Skriv av analysens
`klart_nar` för felet (`villkor`, `grans`), med `pa: "forsta_serien"` och
`pass_i_rad: 2`. Första serien är 5 slag före uppvärmningen nästa pass (METOD
MT2). Ett tal som inte står i analysen finns inte.

## Det Claude inte får göra

- **Mäta själv.** Inget tal skattas ur kontaktarket, videon eller lederna.
  Varje tal i filen och rapporten kommer ur `analys.json` eller minnet
  (BESLUT B2); `att_jobba_pa.py --analys` fäller ett eget.
- **Hitta på gränser, kedjor eller test.** Gränserna kommer ur katalogen eller
  analysens förslag, kedjorna och testen ur `kedjor.json`. Saknas något: säg
  det, och föreslå en rad med källa i rapporten i stället.
- **Ändra `katalog.json` eller `kedjor.json`** under en tolkning. Ändringar där
  är egna commits med källa (BESLUT B6, B10).
- **Värdeord i appens text** (BESLUT B13): inget "bättre", "sämre", "bra",
  "bäst", "perfekt", inga utropstecken, ingen totalpoäng. Förändring är tecken
  och tal ("+2,2 cm mot 3 nov"). Kontrollen fäller värdeorden.
- **Ge ett följdfel en egen övning**, eller byta en övning som rör sig.
- **Säga att något är rörlighet** utan treregeln, eller säga "är" i stället för
  "troligen".
- **Lägga in riktig data i repot** eller skriva ut Johannes tal i en commit.

## Utdata

1. **`att_jobba_pa.json`**, kontrollerad (steg 5) och sparad (steg 6).
2. **Rapporten** i chatten, högst 8 rader:
   ```
   Pass 3 nov, 16 slag (8 FO, 8 DTL), j7. Missen: tunn (Johannes).
   1. Bäckenet glider bakåt i baksvingen: −5,7 cm, grönt ≥ 0 (B10). Rött.
      Följdfel som mäts: reverse spine, resan framåt, sway gap.
      Övning: käppen vid bakre höften. Tanke: "Rör inte käppen."
      Klart när: första serien ≥ 0 cm, två pass i rad.
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
python3 tools/pc/att_jobba_pa.py tools/tests/fixturer/att_jobba_pa_exempel.json --analys data/exempel/historik/pass/20261103-180000/analys.json
python3 tools/pc/historik.py --rot data/exempel/historik spara-att-jobba-pa tools/tests/fixturer/att_jobba_pa_exempel.json
python3 tools/pc/generera_paket.py data/exempel --pass 20261106-180000 --vy fo --serier 2 --seed 2 --sway-topp -3.5 --forsta-serien-flytt -0.5 --utan-langd
python3 tools/pc/generera_paket.py data/exempel --pass 20261106-180000 --vy dtl --serier 2 --seed 2 --utan-langd
python3 tools/pc/session.py data/exempel/swinglab-20261106-180000-*.zip --historik data/exempel/historik
python3 tools/pc/historik.py --rot data/exempel/historik minne
```

Pass 1: bara `sway_topp` är flaggad (rött mot ≥ 0, B10). Valet är
`tools/tests/fixturer/att_jobba_pa_exempel.json`: en sak, katalogens övning,
följdfelen ur kedjorna, klart när första serien ≥ 0 cm två pass i rad. Pass 2:
första serien rörde sig tydligt (−5,5 → −3,3 cm, mer än pass 1:s spridning) men
klarar inte villkoret, så läget är `fortsatt`: samma övning. Resan framåt och
tappad hållning är röda mot baslinjen men står som följdfel av `sway_topp` i
kandidaterna, så de får ingen egen övning. (Kör `--ut` eller `--historik` mot en
mapp under `data/`, aldrig utanför den gitignorerade mappen.)

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
  gång och sedan historiken. Bortvalt: att gissa 1,80 m (skalan, M2, bär hela
  längdfelet).
- **F-S5-4 — Första serien.** Valt: serie 1 när passet har flera, annars de fem
  första slagen (METOD MT2). Väntar på design/README.md öppna val 4 (5 slag före
  uppvärmningen) och på hur appen märker serien.
- **F-S5-5 — Övningens läge.** Valt: klart efter 2 pass i rad på första
  serien, byt övning efter 4 pass utan tydlig rörelse, fysiken efter 6 veckor
  (METOD MT4, MT5). Alla tre är antaganden; omprövas efter vinterns första
  block.
- **F-S5-6 — Rapporten i chatten, inte i filen.** Appen visar bara övningen,
  tanken och klart när (BESLUT B13 regel 5). Kedjan och skälen står i chatten.
- **F-S5-7 — Två vyer i samma pass räknas var för sig.** Tempot (`alla`) slår
  ihop båda telefonernas slag, så samma sving räknas två gånger när båda filmar.
  Valt tills vidare: så, eftersom medianen inte flyttas. Omprövas när parningen
  (`par` i manifestet) läses på PC:n.
- **F-S5-8 — MediaPipe och vridningen väntar.** PLAN S5 nämner MediaPipe och tre
  metoder för vridningen. De hör till S3 (facit) och S6 (två kameror); S5 läser
  telefonens leder.
