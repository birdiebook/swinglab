# SwingLab: mått och gränser hos de bästa, och vad som hänger ihop med utfallet

Research 2026-10-22. Svenska, korta meningar.

**Kontrollerad i original 2026-10-23:** [5_matt_i_original.md](5_matt_i_original.md).
§2 där listar raderna här som var fel. Läs den innan ett tal härifrån används.

## Läs detta först: hur källorna är lästa

- **Inget är läst i original.** Sidhämtning var blockerad i miljön (DNS och proxy nekade alla domäner). Allt nedan kommer från sökmotorns sammanfattningar av sidorna, med URL. Därför står **"ej läst i original"** i princip på varje rad. Siffror ska kontrolleras mot källan innan de blir en gräns i koden.
- 33 sökningar användes. Bredd före djup.
- Status: **forskning** (peer review) · **tillverkare** (Sportsbox, GolfTEC, K-Motion m.fl.) · **tränare** (TPI, coacher) · **antagande** (min slutsats).
- "Okänt" betyder att jag inte hittade siffran. Jag har inte gissat.

## Sammanfattning: de 5 viktigaste fynden för katalogen

1. **Bäckenets sway vid toppen är Johannes tydligaste avvikelse, och den har stöd från två system.** Sportsbox: hos höghandicappare har bäckenet svajat "flera tum" bort från målet vid P4. Hos låghandicappare är värdet "nära 0" ([golf.com](https://golf.com/instruction/one-piece-swing-data-separate-low-high-handicap/), tillverkare). GolfTEC: tourspelarnas höfter ligger 3,9 tum (≈ 10 cm) **mot** målet vid toppen. Höghandicappare ligger på 2,55 tum ([golftec.co.za/swingtru](https://www.golftec.co.za/swingtru), [Golf Digest](https://www.golfdigest.com/story/swing-by-numbers-new-study-unlocks-6-swing-secrets), tillverkare). Oktobers mätning (Golf SG, HANDLED_PLAN §4) ligger i höghandicapmönstret i båda. **Gräns: ≥ 0 cm, varning under −5 cm** (antagande byggt på de två).
2. **Oktobers axellutning vid träff kan inte jämföras med tour som den står.** GolfTEC anger tour 39° "shoulder tilt" vid träff ([golftec.co.za/swingtru](https://www.golftec.co.za/swingtru)). Sportsbox anger bröstets sidböjning vid träff 24,1–37,5° för PGA-proffs ([golfdigest-minna.jp](https://www.golfdigest-minna.jp/_ct/17677047)). Skillnaden är för stor för att vara sving. Den är troligen definition: referens, vy eller projektion. 2D och 3D skiljer 8,7° bara i sidböjning vid träff ([Mears 2016](https://dspace.lboro.ac.uk/2134/21663)). Axelpunkterna (akromion) är opålitliga just vid träff ([Wheat, SHU](https://shura.shu.ac.uk/614)). **Granska definitionen innan gränsen används.**
3. **X-faktorn beror på metoden mer än på spelaren.** 2D och 3D skiljer cirka 16° ([Mears 2016](https://dspace.lboro.ac.uk/2134/21663), forskning). Tre 3D-metoder skiljer sig signifikant, och omräkningen mellan dem är individuell ([Brown 2013](https://doi.org/10.1080/02640414.2013.775474), forskning). Akromion- och thoraxlinje ger olika värden ([Bourgain 2020](https://sam.ensam.eu/handle/10985/19475)). **Använd inga tour-gränser i grader för X-faktorn. Visa Johannes egen trend.** X-faktor **stretch** (ökningen i tidig nedsving) är det mått som oftast hänger ihop med klubbfart ([Cheetham 2001](https://works.bepress.com/philip_martin/5/), [Joyce 2017](https://researchonline.nd.edu.au/health_article/178)).
4. **"Early extension" är två olika mått.** TPI och Sportsbox: bäckenet rör sig **mot bollen** (thrust, translation). "Loss of posture": bröstets framåtböjning minskar. Johannes har båda måtten. Håll isär dem i katalogen. TPI: 67 % av över 90 000 amatörer har early extension, och 99 % av drygt 100 tourspelare har det inte ([mytpi.com](https://www.mytpi.com/articles/swing/early-extension-swing-characteristic), tränare). Tecknet på oktobers thrust måste kontrolleras: är minus mot bollen eller bort från den?
5. **Medianen av 34 svingar är stabil. Dagen är bruset.** Åtta försök räcker för ett stabilt medel i ett labb ([Boise State](https://experts.boisestate.edu/en/publications/the-required-number-of-trials-for-biomechanical-analysis-of-a-gol/), forskning, n = 10). Repeterbarheten är lägst **mellan dagar och mellan testledare**, och sämst för bäckenets framåtböjning ([Griffith](https://research-repository.griffith.edu.au/items/29202738-2d66-5d0d-a5e5-b4e2d8f665c0), forskning). **Krav: minst 8–10 svingar per pass. Jämför pass mot pass, och ändra inte kamerans läge.**

---

## Del 1. Måtten

### 1.1 Bäckenets sway (topp och träff)

| | Värde | Källa | Status |
|---|---|---|---|
| Definition, Sportsbox | Bäckenets sidoförflyttning från adressläget, i tum. Vy FO. | [Golf Digest](https://www.golfdigest.com/story/useful-golf-swingfacts-sportsbox-ai-graph) | tillverkare, ej läst i original |
| Definition, GolfTEC | "Hip sway" vid topp och träff, mätt med sensorer (OptiMotion/SwingTRU). Exakt referenspunkt okänd. | [golftec.co.za/swingtru](https://www.golftec.co.za/swingtru) | tillverkare, ej läst i original |
| Tour vid topp, GolfTEC | 3,9 tum (≈ 9,9 cm) **mot** målet | [golftec.co.za/swingtru](https://www.golftec.co.za/swingtru) | tillverkare, ej läst i original |
| Höghandicap vid topp, GolfTEC | 2,55 tum (≈ 6,5 cm) mot målet ("över 100 slag") | [Golf Digest](https://www.golfdigest.com/story/swing-by-numbers-new-study-unlocks-6-swing-secrets) | tillverkare, ej läst i original |
| Låg vs hög handicap vid topp, Sportsbox | Låghandicap "nära 0". Höghandicap "flera tum" bort från målet. | [golf.com](https://golf.com/instruction/one-piece-swing-data-separate-low-high-handicap/) | tillverkare, ej läst i original |
| Tour vid träff, GolfTEC | 1,6 tum (≈ 4,1 cm) mot målet | [golftec.co.za/swingtru](https://www.golftec.co.za/swingtru) | tillverkare, ej läst i original |
| Vid träff, allmänt | "De flesta" golfare har höfterna upp till 6 tum (≈ 15 cm) mot målet vid träff. Tiger hade > 6 tum i en tidigare sving. | [Golf Digest, Tiger](https://www.golfdigest.com/story/Tiger-woods-golf-swing-technology-metric-golf-digest-video) | tillverkare, ej läst i original |
| Tour vid träff, Sportsbox | +13 cm (Johannes egen tidigare jämförelse) | ej återfunnen i denna sökning | okänt |

**Skillnad i definition.** GolfTEC och Sportsbox ger olika tourvärden vid toppen (≈ +10 cm mot ≈ 0). Det beror troligen på referenspunkten (sensor på korsryggen eller ledernas mittpunkt). Riktningen är ändå samma i båda: **bort från målet vid toppen är amatörmönstret.**

**Oktobers mätning** (HANDLED_PLAN §4): toppen ligger i höghandicapzonen, och träffen mellan GolfTEC:s tour (4 cm) och Sportsbox tour (13 cm). Träffvärdet är därför osäkert som fel.

**Föreslagen gräns (antagande):** topp ≥ 0 cm grönt, −5 till 0 gult, < −5 rött. Träff: ingen gräns förrän definitionen är avstämd.

### 1.2 Huvudets sway

| | Värde | Källa | Status |
|---|---|---|---|
| Tourvärde | Okänt. Inget tourvärde i cm hittat. | – | okänt |
| Amatörvärde | Okänt. | – | okänt |

Huvudets sway vid toppen kan inte bedömas mot en publicerad gräns. Huvudet följer bröstet. Det är därför bättre att bedöma det **tillsammans med bröstets sway** och sway gap (antagande).

### 1.3 Sway gap (bäcken − bröst)

| | Värde | Källa | Status |
|---|---|---|---|
| Definition | Sportsbox term: skillnaden mellan överkroppens och underkroppens sway. Tecken och ordning okända. | [Golf Digest](https://www.golfdigest.com/story/sway-gap-golf-digest-tip-backswing-downswing), [Sportsbox kurs](https://sportsbox-ai.teachable.com/courses/1823246/lectures/50899301) | tillverkare, ej läst i original |
| Tour vid träff | "Negativt sway gap" (bröstet något bakom bäckenet) i 100 % av tourspelarnas svingar enligt Sportsbox. Inget tal i tum hittat. | [golf.com](https://golf.com/instruction/three-musts-solid-ball-striking-sportbox-ai-playsmart/) | tillverkare, ej läst i original |
| Tour > 16,5 cm | Johannes tidigare jämförelse. Ej återfunnen. | – | okänt |

**Varning om tecken:** ett japanskt exempel ger skillnaden −9,9 cm där bröst −0,1 och bäcken +2,9 cm. Det går inte ihop med enkel subtraktion ([golfdigest-minna.jp](https://www.golfdigest-minna.jp/_ct/17693045)). Sportsbox definition är alltså inte säkert "bäcken − bröst". **Våra gränser ska definieras av vår egen formel och tecken, inte kopieras.**

**Samband med utfall:** Golf.com kopplar negativt sway gap till att slå nedåt på bollen (träffbild). Det är ett tränarpåstående. Ingen effektstorlek finns.

### 1.4 Axellinjens lutning / bröstets sidböjning vid träff

| | Värde | Källa | Status |
|---|---|---|---|
| Sportsbox, bröstets sidböjning (höger) vid träff | 24,1–37,5° för PGA-proffs (Sportsbox egen forskning) | [golfdigest-minna.jp](https://www.golfdigest-minna.jp/_ct/17677047) (osäkert vilken av de japanska sidorna som bär siffran) | tillverkare, ej läst i original |
| GolfTEC, "shoulder tilt" vid träff | Tour 39° | [golftec.co.za/swingtru](https://www.golftec.co.za/swingtru) | tillverkare, ej läst i original |
| GolfTEC, "shoulder tilt" vid topp | Tour 36°, höghandicap 29,6° | [Golf Digest](https://www.golfdigest.com/story/swing-by-numbers-new-study-unlocks-6-swing-secrets) | tillverkare, ej läst i original |
| 2D mot 3D | Sidböjning vid träff skiljer 8,7 ± 2,9° mellan 2D och 3D | [Mears 2016](https://dspace.lboro.ac.uk/2134/21663) | forskning, ej läst i original |
| Axellinjens mätpunkter | Inter-akromion-vektorn var opålitlig vid toppen och vid träff. Thoraxvektorn var korrekt i alla faser. | [Wheat, SHU](https://shura.shu.ac.uk/614) | forskning, ej läst i original |

**Skillnad i definition.** "Sidböjning" (Sportsbox) är bröstkorgens lutning i 3D relativt bäckenet eller lodlinjen. "Shoulder tilt" (GolfTEC) är axellinjens lutning. Vår "axellinjens lutning" mäts troligen mellan axelpunkterna i bilden. **Oktobers värde ligger långt under alla tourvärden. Det är troligare ett definitionsfel (referens mot adressen, fel vy eller fel tecken) än en sving.** Kontrollera på en enda bildruta för hand.

**Samband med utfall (blandat):**
- Chu 2010 (n = 308): bålens framåt- och sidolutning hör till variablerna som förklarar bollfart ([UKY](https://scholars.uky.edu/en/publications/the-relationship-between-biomechanical-variables-and-driving-perf/), forskning, ej läst i original).
- Joyce 2017 (n = 15, låghandicap): **mindre** sidböjning i bålen hörde ihop med högre klubbfart med järn 5 ([ND](https://researchonline.nd.edu.au/health_article/178), forskning, ej läst i original).
- Joyce 2016 (n = 35): mindre sidböjning i nedre bålen hörde ihop med högre klubbfart och lägre utgångsvinkel (forskning, ej läst i original; exakt URL ej fastställd, troligen bland [ND health_article](https://researchonline.nd.edu.au/health_article/144)).
- Slutsats (antagande): mer sidböjning är inte entydigt bättre. Använd tour-intervallet som "inom normalt", inte som "mer är bättre".

### 1.5 Bröstets framåtböjning adress → träff (loss of posture)

| | Värde | Källa | Status |
|---|---|---|---|
| GolfTEC, "shoulder bend" vid adress | Tour cirka 40° framåt | sökresultat från GolfTEC-material ([GolfWRX](https://golfwrx.com/427032/body-rotation-the-difference-between-pga-tour-players-and-amateurs/)/[Golf Digest](https://www.golfdigest.com/story/swing-by-numbers-new-study-unlocks-6-swing-secrets)) | tillverkare, ej läst i original |
| GolfTEC, "shoulder bend" i finish | Tour 32° bakåt | [golftec.co.za/swingtru](https://www.golftec.co.za/swingtru) | tillverkare, ej läst i original |
| 2D mot 3D | Bålens flexion vid toppen skiljer −6,5 ± 3,6° | [Mears 2016](https://dspace.lboro.ac.uk/2134/21663) | forskning, ej läst i original |
| Tour vid träff | Okänt i grader | – | okänt |

**Oktobers mätning:** en förlust på några grader. Utan tourvärde vid träff går förlusten inte att bedöma mot en norm. Felet i 2D är av samma storlek som förlusten. **Behåll måttet som egen trend, inte som gräns.**

### 1.6 Bäckenets thrust (early extension)

| | Värde | Källa | Status |
|---|---|---|---|
| Definition, TPI | All rörelse av bäckenet framåt mot bollen i bak- eller nedsving | [mytpi.com](https://www.mytpi.com/articles/swing/early-extension-swing-characteristic) | tränare, ej läst i original |
| Förekomst, amatörer | 67 % av > 90 000 screenade (TPI). En annan TPI-presentation: 64,3 % av > 7 000. | [mytpi.com](https://www.mytpi.com/articles/swing/early-extension-swing-characteristic), [presentation](https://powershealth.org/-/media/files/pdfs/cme/2024/the-body-swing-connection.ashx) | tränare, ej läst i original |
| Förekomst, tour | 99 % av > 100 PGA-, Europa- och LPGA-spelare har det **inte** | [mytpi.com](https://www.mytpi.com/articles/swing/early-extension-swing-characteristic) | tränare, ej läst i original |
| Exempel i 3D | En spelare med thrust > 3 tum (≈ 7,6 cm) mot bollen vid träff, kallat early extension | [mytpi.com](https://cdn.site.mytpi.com/articles/swing/what-you-can-learn-from-no-laying-up's-visit-to-tpi) | tränare, ej läst i original |
| Sportsbox tour i tum | Okänt | – | okänt |
| Forskning om thrust per handicap | Ingen peer review-studie hittad | – | okänt |

**Skillnad i definition:** thrust är translation (cm, sidovy DTL). Loss of posture är vinkel (bröstets böjning). De kan gå åt olika håll: bäckenet kan stanna medan bröstet reser sig. **Tecknet på oktobers värde avgör allt.** Om minus betyder bort från bollen är värdet tour-likt. Om minus betyder mot bollen ligger det nära TPI:s exempel på early extension.

**Samband med utfall:** TPI säger att early extension kostar konsistens och kraft. Ingen effektstorlek. Tränarpåstående.

### 1.7 Bäckenets vridning (topp) och höfterna öppna vid träff

| | Värde | Källa | Status |
|---|---|---|---|
| Sportsbox tour, topp | ≈ −40° | [Golf Digest](https://www.golfdigest.com/story/useful-golf-swingfacts-sportsbox-ai-graph) | tillverkare, ej läst i original |
| Sportsbox tour, träff | ≈ +40° öppen | samma | tillverkare, ej läst i original |
| GolfTEC tour, träff | 36° öppen | [golftec.co.za/swingtru](https://www.golftec.co.za/swingtru) | tillverkare, ej läst i original |
| GolfTEC per handicap, träff | Tour öppnar nästan **dubbelt** så mycket som nybörjare. Lägre handicap = mer öppet. Exakta tal ej hittade. | [Golf Digest](https://www.golfdigest.com/story/swing-by-numbers-new-study-unlocks-6-swing-secrets), [GolfTEC Scramble](https://scramble.golftec.com/blog/2021/02/pros-vs-joes-how-hip-turn-can-increase-distance/) | tillverkare, ej läst i original |
| Zheng 2008 (IJSM 29(12)), träff | PGA −42 ± 12°, LPGA −52 ± 11° (minus = öppen i deras tecken) | [Thieme](https://thieme-connect.de/products/ejournals/html/10.1055/s-2008-1038732) | forskning, ej läst i original |
| Zheng 2008 (IJSM 29(6)), proffs + tre handicapgrupper, 18 per grupp, 240 bilder/s | Bålens vridning vid toppen 60 ± 7° hos proffs. De flesta mått skilde proffs/låg mot hög handicap. Bäckenets tal per grupp ej hittade. | DOI [10.1055/s-2007-989229](https://doi.org/10.1055/s-2007-989229) | forskning, ej läst i original |
| GolfWRX om GEARS | "Inga ideala tal, utan fönster som bra spelare passar in i" | [GolfWRX](https://golfwrx.com/427032/body-rotation-the-difference-between-pga-tour-players-and-amateurs/) | tränare, ej läst i original |

**Oktobers** bäckenvridning vid toppen ligger inom tour. **Föreslagen gräns för öppna höfter vid träff: 35–45° grönt** (tre källor möts). Under 25° gult (antagande).

**Samband med utfall:** bäckenets vinkelhastighet vid träff skilde proffs från 4 av 5 amatörer (p = 0,019; 11 proffs, 5 amatörer) ([PMC9816382](https://pmc.ncbi.nlm.nih.gov/articles/PMC9816382), forskning). Litet urval. Skickliga golfare började bäckenets vridning och viktöverföringen tidigare (13 skickliga mot 17 mindre skickliga) ([JSSM 2010](https://jssm.org/jssm-09-127.xml-abst), forskning, ej läst i original).

### 1.8 X-faktor och X-faktor stretch

| | Värde | Källa | Status |
|---|---|---|---|
| Definition, TPI | Axlarnas vridning minus bäckenets vridning vid toppen. Exempel: axlar 90°, bäcken 50° → 40°. Stretch = ökningen i början av nedsvingen när höfterna startar före axlarna. | [mytpi.com](https://www.mytpi.com/articles/biomechanics/the-difference-between-x-factor-and-x-factor-stretch) | tränare, ej läst i original |
| Cheetham 2001 | Stretch 19 % hos skickliga mot 13 % hos mindre skickliga (signifikant). Skillnaden vid toppen (11 %) var inte signifikant. Urval cirka 19. | [bepress](https://works.bepress.com/philip_martin/5/) | forskning (bokkapitel), ej läst i original |
| McTeigue 1994 (via Cole 2009) | Ingen tydlig skillnad vid toppen mellan amatörer och proffs | [Cole 2009](https://acuresearchbank.acu.edu.au/download/ae6894a7993c13c80893a62be2568b2009d54d21d8f9710ac02ba831c6079456/1086494/Cole_2009_The_X_Factor_and_its_relationship_to.pdf) | forskning (översikt), ej läst i original |
| Meister 2011 | Högsta X-faktor 56° (± 7,4 %) hos 10 proffs, i tidig nedsving. De tre sämsta amatörerna: 48, 46, 46°. Korrelation med klubbfartsindex: toppvärde ρ 0,90, X-faktor vid träff ρ 0,94. n = 15. | [PDF](https://people.stfx.ca/smackenz/Courses/DirectedStudy/Articles/Meister%20-%20Rotational%20Biomechanics%20of%20the%20Elite%20Golf%20Swing.pdf), [scienceblog](https://scienceblog.com/study-of-golf-swings-pinpoints-biomechanical-differences-between-pros-and-amateurs/) | forskning; 56° bara ur sekundär sammanfattning, ej läst i original |
| Myers 2008 | 100 motionärer, driver. Måttliga samband (r ≥ 0,50) mellan bollfart och separation vid toppen, största separation och bålens vridhastighet. | [PDF](https://chs.uky.edu/sites/default/files/2023-12/Myers_2008_Role%20of%20upper%20torso%20and%20pelvis%20during%20golf%20swing.pdf) | forskning, ej läst i original |
| Chu 2010 | 308 golfare. Modellerna förklarade 44–74 % av bollfarten. X-faktorn, sen release, bålens lutning och viktöverföring var signifikanta. | [UKY](https://scholars.uky.edu/en/publications/the-relationship-between-biomechanical-variables-and-driving-perf/) | forskning, ej läst i original |
| Joyce 2017 | 15 låghandicappare. Nedre bålens X-faktor stretch förklarade klubbfart med järn 5. Ingen skillnad mellan driver och järn i X-faktor. | [ND](https://researchonline.nd.edu.au/health_article/178) | forskning, ej läst i original |
| Kwon 2013 | Validitet för olika beräkningar och samband med klubbfart. Resultat ej hittade. | [DOI](https://doi.org/10.1080/14763141.2013.771896) | forskning, okänt resultat |
| Koreansk studie 2005 | "Effektiv X-faktor" ökade utan samband med klubbfart | [koreascience](https://koreascience.or.kr/article/JAKO200534939596037.page) | forskning, ej läst i original |
| Elitjuniorer | Stretch korrelerade högt med klubbfart. X-faktor vid toppen korrelerade **negativt** hos elitjuniorer. | [Studia Sportiva](https://journals.muni.cz/studiasportiva/article/view/7413) | forskning, ej läst i original |

**Skillnader i definition (viktigast i hela rapporten):**
- **Övre linjen:** akromion (axelleder) eller thorax (bröstkorgens segment). Akromion följer skulderbladen och armarna. Vision och MediaPipe ger axelleder, alltså en akromion-lik linje.
- **Projektion:** horisontalplan, svingplan eller ledvinkel i 3D. Bourgain 2020 testade just markörval och projektionsplan ([SAM](https://sam.ensam.eu/handle/10985/19475), resultat ej lästa).
- **2D mot 3D:** cirka 16° skillnad, främst av projektionsfel från bålens framåt- och sidoböjning ([Mears 2016](https://dspace.lboro.ac.uk/2134/21663)).
- **Mellan 3D-metoder:** signifikanta skillnader och individuell omräkning (n = 19) ([Brown 2013](https://doi.org/10.1080/02640414.2013.775474), [Napier](https://www.napier.ac.uk/research-and-innovation/research-search/outputs/the-x-factor-an-evaluation-of-common-methods-used-to-analyse-major-inter-segment)).
- **Stretch:** procent (Cheetham) eller grader (övriga). Toppen definieras olika (bäckenets vändning eller klubbans).

**Rekommendation (antagande):** mät stretch som **ökningen i grader från bäckenets vändning till största värdet**, i samma metod varje gång. Visa trenden. Jämför inte mot 56°.

### 1.9 Tempo

| | Värde | Källa | Status |
|---|---|---|---|
| Novosel/Tour Tempo | 3:1 | via [arXiv Grober](https://arxiv.org/pdf/1001.1137) | tränare, ej läst i original |
| Grober (mätt) | 2,8:1 | [arXiv](https://arxiv.org/pdf/1001.1137) | preprint, ej läst i original |
| Blast Motion tour | 2,5:1–3,1:1. Skillnaden beror ofta på hur toppen definieras. | [Blast](https://blastmotion.com/blog/what-is-golf-swing-tempo-ratio/) | tillverkare, ej läst i original |
| Per handicap | Okänt. Ingen kontrollerad jämförelse hittad. | – | okänt |

**Oktobers tempo ligger inom tour.** Låg prioritet i katalogen. Tempo i sig har inget belagt samband med utfall.

### 1.10 Kinematisk sekvens

| | Värde | Källa | Status |
|---|---|---|---|
| Tinmark 2010 | 45 golfare (11 proffs, 34 elitamatörer). Proximal-till-distal ordning och ökande topphastighet i alla slag, båda könen och alla nivåer. | [PubMed 21309298](https://pubmed.ncbi.nlm.nih.gov/21309298/) | forskning, ej läst i original |
| Cheetham (via Frontiers 2022) | Proffs: bäcken → bröst → arm → klubba. Amatörer: armen toppar före bröstet. | [Frontiers 2022](https://www.frontiersin.org/articles/10.3389/fspor.2022.986281/full) | forskning (sekundärt), ej läst i original |
| Swing Performance Index | Index av bäckenets topphastighet före träff, bäckenets hastighet vid träff och bålens topphastighet efter träff. Stark prediktion, men 11 + 5 golfare. | [PMC9816382](https://pmc.ncbi.nlm.nih.gov/articles/PMC9816382) | forskning |

Kräver vinkelhastighet per segment. 150 bilder/s räcker troligen för bäcken och bröst, men brus i 2D-vinklar förstärks när de deriveras (antagande).

### 1.11 Planerade klubbmått

| Mått | Vad som hittades | Källa | Status |
|---|---|---|---|
| Casting / vinkel vänsterarm–skaft | **Inga gradgränser hittade.** Handledens kinematik var starkast kopplad till klubbfart (20 högnivåamatörer, 60–67 % förklarad varians). Lag är viktig för hög klubbfart enligt McLaughlin & Best 1994 och Robinson 1994. | [ND 150](https://researchonline.nd.edu.au/health_article/150); [Meister PDF](https://people.stfx.ca/smackenz/Courses/DirectedStudy/Articles/Meister%20-%20Rotational%20Biomechanics%20of%20the%20Elite%20Golf%20Swing.pdf) | forskning; 1994-studierna ej lästa i original |
| Sen release | Chu 2010: fördröjd release av armar och handleder hör till bollfart (n = 308) | [UKY](https://scholars.uky.edu/en/publications/the-relationship-between-biomechanical-variables-and-driving-perf/) | forskning, ej läst i original |
| Svingplan | Klubbhuvudet följer ett "funktionellt svingplan" från mitten av nedsvingen till mitten av genomsvingen. Hela svingen är inte plan (RMS > 8 cm). Driverns plan är flackare än järnens. Riktningen skilde inte mellan klubbor. | [ISBS Kwon](https://ojs.ub.uni-konstanz.de/cpa/article/view/3041/2848), [Morrison 2018](https://pure.ulster.ac.uk/ws/files/11652215/Morrison%202018%20Analysis%20of%20the%20delivery%20plane%20in%20the%20golf%20swing%20using%20PC1.pdf) | forskning, ej läst i original |
| Laid off / across the line | Definition: skaftet pekar vänster om målet (laid off) eller höger (across) vid toppen. Inga gradgränser hittade. | [Golf Monthly](https://www.golfmonthly.com/videos/golf-swing-tips/laid-off-mean-golf?pid=124863) | tränare, ej läst i original |
| Skaftlutning vid träff | **Ingen pålitlig siffra hittad.** "30 % deloft" och "15 %" motsäger varandra i samma källa. | sökning gav bara bloggar | okänt |
| Armbåge / chicken wing | Inga tal vid träff. GolfTEC: bättre spelare har mindre böjd vänsterarm vid toppen (exempel 76° mot 10°, en elev, inte norm). | [GolfTEC](https://scramble.golftec.com/blog/2023/03/keep-your-lead-arm-straight-throughout-your-swing/) | tillverkare, ej läst i original |
| Reverse spine | Överkroppen lutar mot målet vid toppen (FO). Kopplas till ländryggsbelastning. Inga skadestudier, bara tränarpraxis och ett fallreferat. | [mytpi.com](https://www.mytpi.com/articles/health/most-common-swing-characteristics-that-cause-lower-back-pain), [IJSPT](https://ijspt.scholasticahq.com/article/23470-a-targeted-approach-to-evaluating-the-golfing-athlete-with-low-back-pain-a-resident-s-case-report) | tränare |
| Over the top | 43,5 % av > 7 000 amatörer (TPI). Ingen gräns för handens bana i cm hittad. | [presentation](https://powershealth.org/-/media/files/pdfs/cme/2024/the-body-swing-connection.ashx) | tränare, ej läst i original |
| Stans | Klubbfart steg med stansbredd hos 8 koreanska proffs (korta inspel 30–70 m). Ingen norm som andel av axelbredd hittad. | [lida](https://lida.sport-iat.de/ta/Record/4051631?lng=en) | forskning, ej läst i original |
| Bollens läge | 11 proffs: läge framåt-bakåt (mot/från spelaren) ändrade klubbfart och attackvinkel. Läge i sidled ändrade bladriktning, bana och attackvinkel. | [JSSM 2018](https://jssm.org/jssm-17-589.xml-Fulltext) | forskning, ej läst i original |

**Slutsats för klubbmåtten:** inga publicerade gränser i grader hittades som går att lita på. Starta dem som **egen baslinje**.

---

## Del 2. Definitionerna skiljer sig — översikt

| Mått | System A | System B | Vad det betyder för oss |
|---|---|---|---|
| X-faktor | 3D thorax − bäcken som ledvinkel (Brown) | Akromionlinje − höftlinje projicerad i horisontalplanet (Kwon) eller i 2D-bild | Vision/MediaPipe ≈ akromion. 2D ger ≈ 16° fel. Inga tour-grader. |
| X-faktor stretch | Procent ökning (Cheetham) | Grader ökning | Välj grader. Definiera "toppen" som bäckenets vändning. |
| Early extension | Bäckenets translation mot bollen (TPI, Sportsbox thrust) | Bröstets böjning minskar (loss of posture) | Två mått, två gränser. Kontrollera tecknet. |
| Sway (bäcken) | Från adress, ledernas mittpunkt (Sportsbox, troligen) | Sensor på bäckenet (GolfTEC) | Tour vid toppen: ≈ 0 (Sportsbox) mot ≈ +10 cm (GolfTEC). Riktningen är enig. |
| Axellutning | Bröstets sidböjning i 3D (Sportsbox 24–38°) | Axellinjens lutning (GolfTEC 39°) | Vårt värde matchar ingen. Granska. |
| Tempo | Start → topp (klubba) | Start → topp (kropp) | Blast: definitionen förklarar skillnaden i tour-intervallet. |

## Del 3. Vad som hänger ihop med utfallet

| Mått | Utfall | Effekt | Urval | Håller för amatörer? | Källa |
|---|---|---|---|---|---|
| X-faktor (topp, max) | Bollfart | r ≥ 0,50 | 100 motionärer | Ja, urvalet är amatörer | [Myers 2008](https://chs.uky.edu/sites/default/files/2023-12/Myers_2008_Role%20of%20upper%20torso%20and%20pelvis%20during%20golf%20swing.pdf) |
| X-faktor + release + lutning + viktöverföring | Bollfart | 44–74 % förklarad varians | 308 | Ja, brett urval | [Chu 2010](https://scholars.uky.edu/en/publications/the-relationship-between-biomechanical-variables-and-driving-perf/) |
| X-faktor max och vid träff | Klubbfartsindex | ρ 0,90–0,94 | 15 | Osäkert, litet urval | [Meister 2011](https://people.stfx.ca/smackenz/Courses/DirectedStudy/Articles/Meister%20-%20Rotational%20Biomechanics%20of%20the%20Elite%20Golf%20Swing.pdf) |
| X-faktor stretch | Skicklighet | 19 % mot 13 % | ≈ 19 | Ja, jämförde nivåer | [Cheetham 2001](https://works.bepress.com/philip_martin/5/) |
| Nedre bålens stretch, mindre sidböjning | Klubbfart, järn 5 | signifikant (storlek ej hittad) | 15 låghandicap | Osäkert | [Joyce 2017](https://researchonline.nd.edu.au/health_article/178) |
| Bäckenets lutning i frontalplanet | Klubbfart | r ≈ 0,41–0,52 | 25 (hcp ≤ 3) | Osäkert | [TWU](https://twu-ir.tdl.org/handle/11274/8754) (URL troligen rätt, ej läst) |
| Tidig tryckförflyttning till främre foten | Klubbfart | samband (storlek ej hittad) | 22 låghandicap; 40 motionärer i en annan studie | Ja (40 motionärer) | [Loughborough](https://repository.lboro.ac.uk/articles/journal_contribution/Comparison_of_centre_of_gravity_and_centre_of_pressure_patterns_in_the_golf_swing/9575672/1), [VU](https://vuir.vu.edu.au/1617/) |
| Bäckenets hastighet vid träff | Proffs mot amatör | p = 0,019 | 11 + 5 | Osäkert | [PMC9816382](https://pmc.ncbi.nlm.nih.gov/articles/PMC9816382) |
| Handledens kinematik | Klubbfart | 60–67 % förklarad varians | 20 högnivåamatörer | Delvis | [ND 150](https://researchonline.nd.edu.au/health_article/150) |
| Bäckenets sway vid toppen | Handicap | riktning, ingen effektstorlek | GolfTEC > 13 000–30 000 | Ja, men ej peer review | [golftec.co.za](https://www.golftec.co.za/swingtru) |
| Early extension | Konsistens, kraft | ingen effektstorlek | TPI > 90 000 | Påstående | [mytpi.com](https://www.mytpi.com/articles/swing/early-extension-swing-characteristic) |

**Träffbild och konsistens:** ingen studie hittades som kopplar ett kroppsmått till träffpunkt eller spridning med effektstorlek. Sambanden ovan gäller nästan bara **fart**. Påståenden om träffbild (sway gap, early extension) kommer från tränare och tillverkare.

## Del 4. Reliabilitet och antal svingar

| Fynd | Urval | Källa | Status |
|---|---|---|---|
| 8 försök räcker för biomekanisk analys. ICC och individuellt SEM gav 4, sekventiellt medel gav 12. | 10 motionärer, 15 slag med järn 6 och driver | [Boise State](https://experts.boisestate.edu/en/publications/the-required-number-of-trials-for-biomechanical-analysis-of-a-gol/) | forskning, ej läst i original |
| Kurvornas repeterbarhet hög (CMD > 0,854) utom bäckenets framåtböjning mellan dagar och mellan testledare | 20 golfare, hcp ≤ 14, 5 slag per klubba | [Griffith](https://research-repository.griffith.edu.au/items/29202738-2d66-5d0d-a5e5-b4e2d8f665c0) (URL troligen rätt) | forskning, ej läst i original |
| Bollens sidled (side carry) gick inte att mäta pålitligt på 15 slag hos medel–hög handicap (ICC < 0,26) | medel–hög handicap, radar | [PMC9739191](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9739191/) | forskning |
| Sportsbox: validerat mot GEARS enligt en leverantör, men inga felsiffror publicerade | – | [LITSLINK](https://litslink.com/case-studies/ai-golf-swing-analyzer) | tillverkare |
| Monokulära 3D-modeller för golf: bara visuell kontroll, inga felsiffror i sammanfattningen | – | [DTU](https://orbit.dtu.dk/en/publications/evaluating-current-state-of-monocular-3d-pose-models-for-golf/) | forskning, ej läst i original |
| MediaPipe mot markörsystem i golf: inga felsiffror i grader hittade | – | – | okänt |

**Brusmått (antagande byggt på fynden):**
- Allt som bygger på **axelpunkterna** vid toppen och vid träff: X-faktor, axellutning. Akromionlinjen är opålitlig just där ([Wheat](https://shura.shu.ac.uk/614)).
- **Bäckenets framåtböjning** och därmed thrust i sidovy: sämst mellan dagar.
- **Derivator** (vinkelhastighet, sekvens): bruset växer med deriveringen.
- **Robusta:** tempo (ljudklick ±7 ms), bäckenets vridning, sway i cm från samma kamera.

**Antal svingar:** minst 8, gärna 10, per pass och klubba. Johannes 34 räcker gott. Jämför pass mot pass bara när kameran står likadant.

## Del 5. Vad som borde ändras i katalogens gränser

1. **Bäckenets sway vid toppen:** gräns ≥ 0 cm (grönt), −5 till 0 (gult), < −5 (rött). Högsta prioritet för Johannes.
2. **Axellinjens lutning vid träff:** stäng av gränsen tills definitionen är kontrollerad mot en bildruta. Oktobers värde är troligen ett mätfel eller en annan referens.
3. **Sway gap och bäckenets sway vid träff:** ingen tour-gräns förrän vårt tecken och vår formel är bekräftade. Sportsbox egen definition är oklar.
4. **Thrust:** bekräfta tecknet. Gräns: 0 eller bort från bollen = grönt, > 3 cm mot bollen = rött (TPI-exemplet, antagande).
5. **Bröstets böjning adress → träff:** egen trend, ingen tour-gräns (2D-felet är lika stort som förlusten).
6. **Höfter öppna vid träff:** 35–45° grönt (Sportsbox, GolfTEC och Zheng möts).
7. **X-faktor och stretch:** visa bara egen trend. Ingen gräns i grader. Stretch före X-faktor vid toppen.
8. **Tempo:** 2,5–3,1 grönt (Blast). Låg prioritet.
9. **Klubbmåtten:** egen baslinje. Inga publicerade gradgränser hittades.
10. **Märk varje gräns** med källa och status i katalogen, och "ej läst i original" tills den är kontrollerad.

## Öppna frågor (nästa research)

- Sportsbox exakta definitioner och tecken (sway gap, thrust, lift): kurssidorna på teachable.com.
- Kwon 2013 och Bourgain 2020: resultaten i siffror.
- Zheng 2008: bäckenets vridning vid träff per handicapgrupp (tabell i fulltext).
- MediaPipe/Vision mot markörsystem i golf: fel i grader för bål och bäcken.
- K-Vest tour-intervall (finns i systemet enligt [K-Motion FAQ](https://www.k-motion.com/faq/), inte publicerade).
- AMM 3D: mäter sway, lift, thrust, rotation, böjning och sidböjning ([golfbusinessnews](https://golfbusinessnews.com/?p=43714)), men inga tal hittade.
