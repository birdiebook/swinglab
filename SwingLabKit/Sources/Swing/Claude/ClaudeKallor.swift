// GENERERAD av tools/pc/underlag.py --swift. Ändra inte för hand: kör skriptet igen.
//
// Instruktionen till Claude-appen är avsnitten mellan markörerna claude-appen i
// .claude/skills/svinganalys/SKILL.md, och kedjorna är tools/pc/kedjor.json, båda
// ordagrant (BESLUT B53). test_underlag.py fäller filen när den inte längre är källornas.

enum ClaudeKallor {
    /// Reglerna ur skillen svinganalys, kortade (avsnitten claude-appen).
    static let instruktion = #"""
**Claude-appen.** Johannes har kopierat texten i SwingLab ("Ask Claude") och klistrat in
den här. Datan längst ned är räknad på telefonen med samma regler och fältnamn som på
PC:n: `kandidater` och `bedomning` ur analysen (`visat` är talet som visas,
`forsta_serien` första seriens median, `spann: null` egen baslinje, `baslinje` dess median,
sd och svingar, `mot_forra` mot förra passet), `ovningar` ur minnet, `historik` felens
`[visat, status]` pass för pass, `pagaende` den senaste "Att jobba på", och `mallar` med
analysens eller minnets "klart när" och märkning. Följ stegen A–I.
Mät inget och räkna inte om något: varje tal står i datan. Fråga inget: saknas missen
(steg C) eller svaren till treregeln (steg G) gäller stegets regel utan svar. Johannes kan
ha skrivit missen efter texten.

**Svaret.** Först rapporten på svenska, högst 9 rader: varje sak med talet, gränsen och
gränsens sort (steg H), kedjan, övningen och tanken; förra valets läge; missen eller att
den saknades. Sist **ett** kodblock ```json med filen: objektet `fil` med `saker` (1–3).
Bygg varje sak ur sin mall i `mallar`: `ordning` (1, 2, 3 i svingens ordning), mallens
fält ordagrant, `ovning` = ett av `ovning_val` med `steg` ur `steg_val` och en `tanke`
(steg I), och `typ` och `fysik` efter steg G (`fysik_test` är felets test). Ta inte med
`ovning_val`, `steg_val` eller `fysik_test`. Ett fel utan mall går inte att välja. All
text i filen är engelska. Telefonen kontrollerar filen som PC:n och tar emot den bara när
allt stämmer.

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
  `markning`), och samma `block.start`. Steget står kvar eller tar nästa
  (`steg`, METOD MT10). Byt inte en övning som rör sig, och byt inte efter ett
  enda pass.
- `byt_ovning` (4 pass i rad utan tydlig rörelse, METOD MT5): behåll felet och
  blocket men välj en annan övning för det ur `tools/pc/kedjor.json`
  (`kalla: "research3"`), aldrig en vars `id` står i `forra_ovningar`. Den nya
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
`"egen"` är det Johannes egen baslinje (eller passet självt, `grund: "nu"`); `null` är
en gräns vars källa är läst i original (sedan research 5: swayen, tempot och early
extension, BESLUT B45). Väg
därefter: ett rött mot en kontrollerad gräns väger mer än ett gult mot en
egen baslinje på 8 svingar. Säg i rapporten vilken sort varje gräns är.

**I. Övningen, stegen och tanken.** Övningen är aldrig fritext: katalogens
ordagrant (`kalla: "katalog"`) eller en av felets övningar i `kedjor.json`
(`kalla: "research3"`), med dess id i `ovning.id` (katalogens `ovning_id` eller
övningens `id` i kedjorna). Samma id = samma övning, även om texten skrivits om.
En ny övning börjar på `langsamt_med_foremal`; sedan
halv fart, full fart, varierat, ett steg i taget när Johannes klarar steget.
Tanken skrivs på engelska och har **extern fokus**: vad klubban, bollen eller ett
föremål (stol, käpp, vägg, headcover) gör, aldrig vad en led gör ("Leave the stick
standing", inte "Keep your hip still"). Högst 60 tecken, inga siffror.

## Det Claude inte får göra

- **Mäta själv.** Inget tal skattas ur kontaktarket, videon eller lederna.
  Varje tal i filen och rapporten kommer ur `analys.json` eller minnet
  (BESLUT B2); `att_jobba_pa.py --analys` fäller ett eget.
- **Hitta på gränser, kedjor, övningar eller test.** Gränserna kommer ur
  katalogen, analysens förslag eller minnet; kedjorna, övningarna och testen ur
  `kedjor.json`. Saknas något: säg det, och föreslå en rad med källa i
  rapporten i stället.
- **Flytta "klart när"** för en övning som fortsätter.

- **Värdeord eller siffror i appens fritext** (BESLUT B13): inget "good",
  "better", "best", "great", "nice", "perfect", "pure", "crisp", "well done", inga utropstecken, ingen
  totalpoäng. Förändring är tecken och tal i rapporten ("+2,2 cm mot 3 nov").
  Kontrollen fäller värdeord på ordstam (engelska listan, METOD MT8).
- **Svenska i appens text** (BESLUT B30): filens fritext är engelska.
- **Ge ett följdfel en egen övning**, väcka en avslutad övning, eller byta en
  övning som rör sig.

- **Säga att något är rörlighet** utan treregeln, eller säga "är" i stället för
  "troligen".
"""#

    /// tools/pc/kedjor.json, ordagrant.
    static let kedjor = #"""
{
 "version": 1,
 "om": "Tolkningens kunskap för PC:n (skillen svinganalys, tools/pc/analys.py): vilka fel i katalog.json som kan vara följdfel av vilka, i vilken ordning faserna kommer, vilka fysiska test som hör till ett fel, och övningarna ur research 3 §2 som Claude får byta till. Ur docs/research/3_tolkning_och_appar.md §1 och §5; allt är ej läst i original (BESLUT B10). Claude får bara använda kedjor och test som står här (METOD MT6). Texterna som visas (övningarnas text och testen) är engelska (BESLUT B30); varje övning har ett stabilt id som historiken jämför på (tools/pc/historik.py), så att en ändrad formulering inte nollställer steget.",
 "faser": [
  "adress",
  "topp",
  "nedsving",
  "traff",
  "efter_traff",
  "hela"
 ],
 "lag_prioritet": [
  {
   "fel": "tempo",
   "notering": "Tempot har inget belagt samband med utfallet (research 1 §1.9): det väljs bara när inget annat är flaggat."
  }
 ],
 "kedjor": [
  {
   "orsak": "sway_topp",
   "foljd": "reverse_spine",
   "status": "tranare",
   "kalla": "https://www.mytpi.com/improve-my-game/swing-characteristics/reverse-spine-angle",
   "notering": "TPI anger lateral sway i baksvingen som orsak till reverse spine (research 3 §1)."
  },
  {
   "orsak": "sway_topp",
   "foljd": "backens_resa_framat",
   "status": "antagande",
   "kalla": "docs/research/3_tolkning_och_appar.md",
   "notering": "Sway bakåt och för lite resa framåt är samma tema, bäckenets väg (research 3 (a)). Det tidigare i svingen övas."
  },
  {
   "orsak": "sway_topp",
   "foljd": "sway_gap",
   "status": "antagande",
   "kalla": "https://practicecaddie.com/blog/reverse-pivot-golf-swing-fix",
   "notering": "Glidningen matar felet: fötterna ihop tar bort båda (research 3 §2). Felet är ett litet sway gap vid träffen, bröstet inte bakom bäckenet (samre −, BESLUT B45); hos Sportsbox hör bröstet framför bäckenet ihop med reverse pivot. Kontrollerat mot riktningen 2026-10-23: övningen och tanken (bältesspännet före kepsen mot målet) drar åt rätt håll."
  },
  {
   "orsak": "reverse_spine",
   "foljd": "early_extension",
   "status": "tranare",
   "kalla": "https://golfwrx.com/194659/three-common-swing-faults-early-extension/",
   "notering": "Reverse spine ger early extension (research 3 §1)."
  },
  {
   "orsak": "backens_resa_framat",
   "foljd": "tappad_hallning",
   "status": "antagande",
   "kalla": "docs/research/3_tolkning_och_appar.md",
   "notering": "Utan bäckenets förskjutning saknas utrymme, och bröstet reser sig (research 3 (a))."
  },
  {
   "orsak": "early_extension",
   "foljd": "tappad_hallning",
   "status": "antagande",
   "kalla": "docs/research/3_tolkning_och_appar.md",
   "notering": "Loss of posture har ingen egen övning utöver early extensions (research 3 §2)."
  }
 ],
 "ovningar": [
  {
   "fel": "sway_topp",
   "id": "fotterna_ihop_balans",
   "text": "Feet together, 3/4 swings: if the pelvis slides, you lose your balance.",
   "kalla": "https://www.golfmagic.com/best-tips-and-instruction/step-2-how-fix-sway",
   "status": "tranare"
  },
  {
   "fel": "sway_topp",
   "id": "kapp_vid_bakre_hoften",
   "text": "Stick in the ground at the trail hip: the hip turns in a circle, the stick stays put.",
   "kalla": "https://onlinedigeditions.com/article/GolfShots/3261965/550370/article.html",
   "status": "tranare"
  },
  {
   "fel": "sway_topp",
   "id": "reach_over_the_fence",
   "text": "TPI’s Reach Over the Fence.",
   "kalla": "https://www.mytpi.com/improve-my-game/swing-characteristics/reverse-spine-angle",
   "status": "tranare"
  },
  {
   "fel": "reverse_spine",
   "id": "fotterna_ihop",
   "text": "Feet together, 3/4 swings: the slide that feeds the fault disappears.",
   "kalla": "https://practicecaddie.com/blog/reverse-pivot-golf-swing-fix",
   "status": "tranare"
  },
  {
   "fel": "reverse_spine",
   "id": "reach_over_the_fence",
   "text": "TPI’s Reach Over the Fence.",
   "kalla": "https://www.mytpi.com/improve-my-game/swing-characteristics/reverse-spine-angle",
   "status": "tranare"
  },
  {
   "fel": "sway_gap",
   "id": "fotterna_ihop",
   "text": "Feet together, 3/4 swings: the slide that feeds the fault disappears.",
   "kalla": "https://practicecaddie.com/blog/reverse-pivot-golf-swing-fix",
   "status": "tranare"
  },
  {
   "fel": "early_extension",
   "id": "vagg_eller_stol_bakom",
   "text": "Glutes against a wall or chair behind you. Slow swings that keep contact through impact while the pelvis rotates.",
   "kalla": "https://mygolfspy.com/news-opinion/instruction/3-drills-to-fix-early-extension-in-the-golf-swing/",
   "status": "tranare"
  },
  {
   "fel": "tappad_hallning",
   "id": "vagg_eller_stol_bakom",
   "text": "Glutes against a wall or chair behind you. Slow swings that keep contact through impact while the pelvis rotates.",
   "kalla": "https://mygolfspy.com/news-opinion/instruction/3-drills-to-fix-early-extension-in-the-golf-swing/",
   "status": "tranare"
  },
  {
   "fel": "backens_resa_framat",
   "id": "steget_i_nedsvingen",
   "text": "The step drill: step toward the target with the lead foot in the downswing, trail foot up on its toe. Ten reps with a short iron, no ball.",
   "kalla": "https://sportsmonkie.com/golf-hip-rotation-drills/",
   "status": "tranare"
  },
  {
   "fel": "over_the_top",
   "id": "headcover",
   "text": "A headcover outside and slightly behind the ball. If you hit it, the club came from outside.",
   "kalla": "https://golfguidebook.com/how-to-stop-coming-over-the-top/",
   "status": "tranare"
  },
  {
   "fel": "chicken_wing",
   "id": "motorcykelovningen",
   "text": "The motorcycle drill: lead wrist flexed through impact, half swings toward the 4:30 path.",
   "kalla": "https://hackmotion.com/chicken-wing-in-golf/",
   "status": "tillverkare"
  }
 ],
 "fysik": [
  {
   "fel": "early_extension",
   "test": "Toe touch",
   "status": "forskning",
   "kalla": "https://journals.lww.com/nsca-jscr/fulltext/2014/02000/correlation_of_titleist_performance_institute.29.aspx"
  },
  {
   "fel": "early_extension",
   "test": "Bridge with leg extension, trail side",
   "status": "forskning",
   "notering": "Källan säger höger sida: bakre sidan för en högerspelare. För en vänsterspelare speglas det (vänster sida), därför trail side.",
   "kalla": "https://www.bisp-datenbanken.de/Record/PU201403003148"
  },
  {
   "fel": "early_extension",
   "test": "Overhead deep squat",
   "status": "tranare",
   "kalla": "https://www.mytpi.com/articles/swing/early-extension-swing-characteristic"
  },
  {
   "fel": "early_extension",
   "test": "Lead hip internal rotation",
   "status": "tranare",
   "kalla": "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10379059/"
  },
  {
   "fel": "tappad_hallning",
   "test": "Bridge with leg extension, trail side",
   "status": "forskning",
   "notering": "Källan säger höger sida: bakre sidan för en högerspelare. För en vänsterspelare speglas det (vänster sida), därför trail side.",
   "kalla": "https://www.bisp-datenbanken.de/Record/PU201403003148"
  },
  {
   "fel": "sway_topp",
   "test": "Trail hip internal rotation",
   "status": "tranare",
   "kalla": "https://www.mytpi.com/articles/swing/your-hips-and-your-swing"
  },
  {
   "fel": "reverse_spine",
   "test": "Seated trunk rotation",
   "status": "tranare",
   "kalla": "https://www.mytpi.com/improve-my-game/swing-characteristics/reverse-spine-angle"
  },
  {
   "fel": "flying_elbow",
   "test": "90/90, trail shoulder external rotation",
   "status": "tranare",
   "kalla": "https://golfrehabdoc.wordpress.com/tag/golf-swing-faults/"
  },
  {
   "fel": "backens_resa_framat",
   "test": "Hip and ankle mobility",
   "status": "tranare",
   "kalla": "https://www.scottsdaleptperformance.com/overcoming-golf-swing-faults/"
  }
 ]
}
"""#
}
