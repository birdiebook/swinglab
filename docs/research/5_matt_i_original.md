# 5. Måtten kontrollerade i original (2026-10-23)

Research 1 och 4 skrevs i molnet, där källsidorna var spärrade. Allt stod därför
som "ej läst i original" (BESLUT B10). Den här rundan kördes på hemdatorn, och
där gick sidorna att läsa. Fyra delar kördes parallellt, och var och en har
sitt underlag med en URL och en status per rad:

- [5a — Sportsbox i original](5a_sportsbox_i_original.md): definitioner,
  tecken och tour-tabellen P1–P10.
- [5b — Forskningen i original](5b_forskning_i_original.md): research 1 och
  research 2 §1, plus markörlöst mot markörer i golf.
- [5c — Normerna i original](5c_normer_i_original.md): GolfTEC per handicap,
  TPI, K-Vest, HackMotion och tempo.
- [5d — Mått att ta in](5d_nya_matt.md): vad som saknas och vad som är svagast
  belagt.

Fortsättningen: [6 — Ranges](6_ranges.md) (2026-10-25) går igenom varje rad i
katalogen mot källorna här, föreslår ett band där måttet är detsamma och ger
måtten utan källa en dom (behåll, flytta eller ta bort).

Den här filen är sammanfattningen. Den visar vad som ändras för SwingLab, och
var ett mått motsvarar en METOD-rad. **Ingenting i koden eller katalogen är
ändrat.** Förslagen i §4 och §5 är underlag för den som bygger.

Status som i research 1: **läst i original** · **bara abstract** · **kunde
inte läsas** · **tillverkare/tränare/forskning** · **antagande**. Det som
fortfarande inte gick att läsa står i §7.

## 1. De viktigaste fynden

1. **Sportsbox tour-tabell finns, med medel per position** (P1–P8 och P10,
   driver och mellanjärn, män och kvinnor; [tour-ranges-for](https://help.sportsbox.ai/tour-ranges-for),
   tillverkare). Den finns bara som bild och är avläst i 5a §B. Den har turn, bend,
   side bend, sway, lift och sway gap. Thrust och X-faktor saknas. Thrust har en
   egen sida.
2. **Sportsbox tecken är desamma som SwingLabs.** Sway + mot målet, lift +
   upp, thrust + mot bollen och bäckenets mittpunkt mellan höftlederna.
   Bäckenets sway, lift och thrust (M15, M8, M7) och bröstets sway (M16) går
   alltså att jämföra direkt med Sportsbox tal, i bildens plan. Det
   enda som skiljer är 2D mot 3D.
3. **Bara de linjära måtten nollas vid adressen.** Sportsbox vinklar är
   absoluta: turn mot linjen genom fotlederna, bend mot lodlinjen och side
   bend mot vågrätt. Sway gap är ett absolut avstånd, och tour ligger redan på
   −1,4 tum vid P1. Research 4 §Grunden hade fel här. Jämför man ett tal som
   nollats vid adressen mot tour blir det fel med adressvärdet.
4. **Sway gap är löst.** Sportsbox: vågrätt avstånd bröstets mitt –
   bäckenets mitt, **− = bröstet bakom bäckenet**. SwingLabs M19 är
   förändringen från adressen med motsatt tecken: M19 = bäckenets sway −
   bröstets sway. Det japanska exemplet går ihop: −6,9 + (−0,1 − 2,9) = −9,9 cm.
5. **Tidpunkten skiljer nivåerna, inte läget.** Okuda 2010 (hcp 0,8 mot
   30,8, läst i original) fann ingen skillnad i bäckenets eller bröstets
   vridning vid toppen eller träffen. Skillnaden låg mitt i bak- och nedsvingen
   och i när vikten flyttades. Hos Smith/Mears 2017 förklarade tryckcentrums
   tidpunkt 74 % av klubbfarten (22 låghandicappare, läst i original).
6. **Spridningen mellan slagen hänger ihop med score, medlet gör det inte.**
   Yamamoto 2023 använde 2D-pose ur en kamera bakifrån (27 golfare, läst i
   original). Sd i framåtlutningen mot snittscore gav r = 0,80, medelvinkeln
   r = −0,18. Det är det enda markörlösa 2D-fyndet med utfall.
7. **X-faktorn mäter ansträngning inom spelaren, inte nivå.** Meisters
   ρ 0,90–0,94 gäller inom varje proffs, mellan lätta och hårda slag (10
   proffs, järn 5). Det gäller inte mellan spelare, och n är inte 15. Kwon 2013
   fann inget samband med klubbfart hos 18 skickliga. Bourgain: akromionlinjen
   mot bäckenet ger ≈ 55–60° hos motionärer och bål mot bäcken ≈ 30°. Egen
   trend gäller, som förut.
8. **Brusgolvet.** Ingen granskad studie mäter MediaPipe eller Apple Vision
   mot markörer i golf. Det bästa är tillverkarnas egna siffror för en kamera
   (Onform, Sportsbox): 2–7° i vinkel och 0,5–1,8 cm i sträcka. Apple Vision
   har SEM 7,8–14,3° på axeln utanför golf. **En gräns finare än ≈ 5° eller
   ≈ 2 cm säger inget** (antagande).

## 2. Rättelser i research 1 och 4

| Var | Stod | Rätt | Källa |
|---|---|---|---|
| 4 §Grunden | "Varje kroppsdel mäts relativt adressen" | Bara sway, lift och thrust. Vinklarna och sway gap är absoluta. | 5a §A |
| 4 §1 | Pelvis Bend ✔ | Finns inte hos Sportsbox | 5a §A |
| 4 §4 | Lead Arm Angle ◐ | Finns inte. Lead Elbow Flex och Lead Wrist Angle (180° = rak). | 5a §D |
| 4 §5, §7, §8 | ◐ för knän, farter, sekvens, tider | Alla finns (✔), med tour-medel | 5a §B, §D |
| 1 §1.1 | "+13 cm" bäckenets sway vid träff (ej återfunnen) | Driver 4,5 tum = **11,4 cm**, järn 12,2 cm. 13 cm är Golf Digests "upwards of five inches". | 5a §C |
| 1 §1.1 | "De flesta golfare upp till 6 tum mot målet vid träff" | Proffs cirka 6 tum, amatörer **sällan över 2 tum** (mätt med Sportsbox) | 5a §C |
| 1 §1.1 | GolfTEC 3,9 tum vid toppen, oklar referens | Mätt på **svanskotan**, som flyttas mot målet när höfterna vrids. Inte samma mått som Sportsbox eller M15. | 5a §C, 5c §1 |
| 1 §1.3 | Sway gap: definition och tecken okända, exemplet går inte ihop | Löst, se §1 punkt 4 | 5a §A |
| 1 §1.3 | "Tour > 16,5 cm" ej återfunnen | Golf Digest "more than 6.5 inches". Tabellen ger driver −6,7 tum (−17,0 cm), järn −4,5 tum (−11,4 cm). | 5a §C |
| 1 §1.6 | Sportsbox thrust "okänt" | Tour vid träff +0,5 tum (SD 1,4). Ideal −0,9 till +1,7 tum. | 5a §B |
| 1 §1.7 | Sportsbox höfter vid träff ≈ +40° | **+38** (driver), +34 (järn) | 5a §B |
| 1 §1.7 | GolfTEC per handicap "ej hittade" | Tour 36°, hcp 5–0 28,5°, 31+ 19,5° | 5c §1 |
| 1 §1.8, Del 3 | Meister: ρ 0,90/0,94 mellan spelare, n = 15 | Inom varje proffs, mellan ansträngningsnivåer, n = 10, järn 5 | 5b |
| 1 §1.7, §1.10 | PMC9816382: p = 0,019, 4 av 5 amatörer | Står inte i texten. Index 100 ± 10 mot 82 ± 4. Samma fem amatörer som Meister. | 5b |
| 1 §1.8 | Kwon 2013: resultat ej hittade | **Inget** X-faktormått hängde ihop med klubbfart (18 skickliga) | 5b |
| 1 §1.8 | Myers: "100 motionärer" | 100 golfare med hcp 8 ± 7 | 5b |
| 1 §1.4, §1.8 | Mears: 2D mot 3D | Talen stämmer, men "2D" är markörer projicerade på labbets plan, ingen kamera. 2D **underskattar** sidböjningen vid träff med 8,7°. | 5b |
| 1 §1.9 | Grober 2,8:1 som tour-värde | **En** proffsspelare. Grober 2006: amatörer har också medel 3,0. | 5c §5 |
| 1 §1.11 | Svingplanet: riktningen skilde inte mellan klubbor | Den skilde (Kwon 2012). "RMS > 8 cm" ej återfunnen. | 5b |
| 1 §1.11 | GolfTEC armbåge 76° mot 10° | En demonstratör, ingen norm | 5c §1b |
| 1 Del 3 | Loughborough: storlek ej hittad | 74 % av klubbfarten. Tidig COG mot främre foten **i sen baksving** var negativt. | 5b |
| 1 Öppna frågor | K-Motion FAQ | Domänen är kapad och leder till en spelsajt. **Ta bort länken.** | 5c §3 |

## 3. Normerna, mot SwingLabs mått

Sportsbox tal är tour-medel för män (100+ PGA- och LPGA-proffs). Omräknat till
cm (1 tum = 2,54 cm). D = driver, J = mellanjärn. Allt är tillverkare, läst i
original (bild). Hela tabellen står i 5a §B, kvinnornas tal i 5a §B under tabellen.

### 3.1 FO: sway, lift och sway gap

| SwingLab (METOD) | Sportsbox | P4 topp D / J | P7 träff D / J | Andra källor |
|---|---|---|---|---|
| `backen_sway` (M15) | Pelvis Sway | −1,5 / 0,0 cm | +11,4 / +12,2 cm | Låg hcp nära 0 vid P4, hög "flera tum" bort (golf.com). Amatörer sällan över 5 cm vid träff (Golf Digest). GolfTEC (svanskota) vid träff: tour +4,1 cm, 31+ −1,0 cm. |
| `brost_sway` (M16) | Chest Sway | −3,3 / −0,3 cm | −1,8 / +3,3 cm | – |
| `sway_gap_traff` (M19) | Sway Gap, ändring från P1 med omvänt tecken | ≈ +2 / +0,3 cm | **+13,2 / +8,9 cm** | Sportsbox absolut vid träff: −17,0 / −11,4 cm |
| `backen_lyft` (M8) | Pelvis Lift | −4,3 / −3,6 cm | **+2,3 / +2,3 cm** | Lägst vid P4–P5 (−4,3/−3,8 cm), sedan upp in i träffen |
| `brost_lyft` (M31) | Chest Lift | −2,0 / −2,0 cm | −2,8 / −1,5 cm | Lägst vid P5: −5,8 / −4,8 cm |
| Recentrering (finns inte) | Pelvis Sway P2–P3 → P4 | tour −4,1 → −1,5 cm (D) | – | Sportsbox: under 1 tum (2,5 cm) är för lite eller för sent |

M19 är räknad ur tabellens sway: bäckenets sway − bröstets sway vid P7 =
4,5 − (−0,7) = 5,2 tum (D), 4,8 − 1,3 = 3,5 tum (J).

### 3.2 DTL: thrust och böjning

| SwingLab (METOD) | Sportsbox | Värde | Andra källor |
|---|---|---|---|
| `backen_thrust_traff` (M7) | Pelvis Thrust | Tour +1,3 cm (SD 3,6). Ideal −2,3 till **+4,3 cm** (för en man av DeChambeaus storlek). | TPI: exemplet > 7,6 cm är early extension. 67 % av amatörerna, 1 % av tour. |
| `brost_bojning` (M6) | Chest Bend (mot lodlinjen) | Adress 39 / 44°, träff 35 / 43° | GolfTEC adress cirka 40°, K-Vest 34–45°. Toppen går inte att jämföra i 2D (bröstet är vridet). |
| `brost_bojning_tapp` (M6) | adress − träff | Tour **+4° (D), +1° (J)** | Yamamoto: spridningen säger mer än medlet |

### 3.3 Lutningarna: sidböjning och axellinje

| SwingLab (METOD) | Närmaste källa | Värde vid träff | Kommentar |
|---|---|---|---|
| `axellinje_lutning` (M17): bakre → främre axel mot vågrätt, + = bakre lägre | Meister S-faktor (akromionlinjen mot horisontalplanet, 3D) | **25 ± 3°** (proffs, järn 5) | Närmast vår definition. forskning, läst i original. |
| | Sportsbox Chest Side Bend (mot vågrätt, + = bakre lägre) | 32° (D), **22°** (J). Adress 15 / 11°. PGA-intervall D 24,1–37,5°. | Samma tecken och nollpunkt som M17, men bröstkorgen i 3D |
| | GolfTEC Shoulder Tilt | Tour 39°, hcp 5–0 33,4°, 31+ 27,5° | Referensen "level (upright)" är oklar |
| `sidbojning` (M14): höftmitt → axelmitt mot lodlinjen | Ingen motsvarighet hos Sportsbox | – | Mears: 2D underskattar sidböjningen vid träff med 8,7 ± 2,9° |
| `hoftlinje_lutning` (M18) | Pelvis Side Bend | P4 −8°, P7 +8° (båda klubborna) | TWU: bäckenets lutning ↔ klubbfart r ≈ 0,5 (kunde inte läsas) |
| Finish (FO), bröstets bakåtlutning | GolfTEC Shoulder Bend i finish | Tour 32°, hcp 5–0 20,6°, 31+ **3,2°** | Det mått som skiljer grupperna mest |

**Vad det betyder för S0** (antagande): ett lågt värde för axellutningen vid
träff är delvis väntat. Järnets tour-tal är 22–25°, inte 39°, och en 2D-linje
blir lägre än 3D. Har Golf SG:s tal nollats mot adressen, är skillnaden ännu
cirka 11–15° större. Kontrollen på en bildruta (PLAN S0) behövs fortfarande.
Jämför då mot 22–25° med järn.

### 3.4 3D (två telefoner) och tiden

| SwingLab | Värde | Källa |
|---|---|---|
| `hofter_oppna_traff` | Sportsbox 38° (D), 34° (J), PGA-intervall 26,3–43,7°. GolfTEC tour 36°, hcp 5–0 28,5°, 31+ 19,5°. K-Vest 35–50°. Myers 29/35/38° från låg till hög bollfart. | 5a, 5c, 5b |
| Bröstets vridning, träff | Sportsbox 30° (D), 25° (J). PGA-intervall 19,4–37,6°. K-Vest 26–34°. | 5a, 5c |
| Bröstets och bäckenets vridning, topp | Sportsbox −98 / −40° (D). K-Vest bål −86 till −74°, bäcken −46 till −30°. | 5a, 5c |
| X-faktor | Sportsbox max 64° (belopp). Härlett ur tabellen: −58° vid P4. TPI ≈ 42° vid bäckenets vändning, stretch ≈ 5°. Meister vid träff 33 ± 6°. | 5a, 5c, 5b |
| Max vridfart, driver | Bäcken 484, bröst 725, arm 1 005, skaft 2 277 °/s | 5a |
| `tempo` (M5) | Kvoten skiljer **inte** nivåer: amatörer har också medel 3,0 (Grober 2006). Blast tour 2,5–3,1. | 5c §5 |
| Nedsvingens tid (finns i M5) | Sportsbox 0,26 s (D), Blast 0,23–0,32 s, AMM ≈ 0,25 s. Kortare med högre fart (Madrid 2020, kunde inte läsas). | 5a, 5c, 5d |
| Handens maxfart, tidpunkt (M35) | Sportsbox 69 ms före träff (D) | 5a |

### 3.5 Handleden (HackMotion, tillverkare, > 1 miljon svingar)

| Extension | Under 10 | 10–25 | Över 25 | Tour |
|---|---|---|---|---|
| Topp | 14,5° | 17,0° | 24,3° | 0–30° |
| Träff | 3,6° | 9,0° | 10,7° | −10 till +10° |

Skillnaden mellan grupperna (7–10°) är mindre än felet i 2D. **Går inte ur
kroppens leder** (5d §1.6).

## 4. Förslag till katalogen (inte gjort)

Katalogen har fältet `kontrollerad`. De här raderna har nu en källa som är
läst i original. Gränserna nedan är **antaganden** byggda på källorna. Den
som bygger avgör.

| Fel (`katalog.json`) | I dag | Förslag | Grund |
|---|---|---|---|
| `sway_topp` | grönt ≥ 0, gult −5…0 | Grönt ≥ −2,5, gult −5…−2,5, rött under −5 cm. `kontrollerad: true`, källa tour-ranges-for och golf.com. | Tour med driver ligger på −1,5 cm, och skulle bli gult i dag. "Flera tum" bort = höghandicap. |
| `early_extension` | egen baslinje | Grönt ≤ +4,3 cm, rött över +7,6 cm | Sportsbox ideal −2,3…+4,3 cm. TPI-exemplet > 7,6 cm. Tecknet är detsamma som M7. |
| `sway_gap` | egen baslinje, ingen riktning | Riktning: + är bra (bröstet bakom). Tour D +13 cm, J +9 cm. Gräns per klubba eller egen baslinje. | Definitionen är löst (§1 punkt 4) |
| `axellutning` | avstängd | Avstängd tills S0 är klar, men referensen blir **22–25° med järn** (Sportsbox J, Meister), inte 39° | §3.3 |
| `tappad_hallning` | egen baslinje | Tour +1…+4°. Lägg vikten på spridningen (§5 punkt 1). | 5a, Yamamoto |
| `tempo` | grönt 2,5–3,1 | Behåll. Visa nedsvingens tid bredvid. | Grober 2006 |
| `hofter_oppna_traff` (3D) | – | Normalt 30–45°, gult under 25° | Fem källor möts (§3.4). Okuda: läget skiljer inte nivåer, så inte "mer är bättre". |
| X-faktorn (3D) | egen trend | Behåll egen trend, inga grader | Kwon, Meister, Bourgain |

**Klubban spelar roll.** Sway gap vid träff skiljer 4–6 cm mellan driver och
järn, och sidböjningen skiljer 10°. En tour-gräns kräver att passets klubba är känd.
Annars är egen baslinje med samma klubba det säkra.

## 5. Mått att ta in, rangordnade

Ur 5d med det som 5a–5c lade till. "Billig" = räknas av lederna vi redan läser.

| # | Mått | Vy | Varför | Kostnad |
|---|---|---|---|---|
| 1 | **Spridningen mellan slagen** som eget tal, först bröstets böjning | DTL | Yamamoto: r = 0,80 mot score, medelvinkeln r = −0,18 | Billig, finns i M25 |
| 2 | **Recentrering**: bäckenets största sway bort från målet (P2–P3) minus sway vid toppen | FO | Sportsbox indikator. Tour flyttar 1–3 tum bakåt och sedan tillbaka. Låghandicappare börjar flytta tillbaka före toppen (golf.com). | Billig |
| 3 | **Skiftets tidpunkt**: när höftmitten (eller tyngdpunkten) passerar adressläget mot målet | FO | Okuda (läst), Smith/Mears 2017 (74 %), Jones 2023 (104 amatörer, bara abstract) | Billig med höftmitten |
| 4 | **Sänkningen och lyftet in i träffen**: bäckenets lägsta punkt i nedsvingen och lyftet därifrån till träffen | båda | Sportsbox tour −4,3 → +2,3 cm, egen indikator "Pelvis Lift at IMP" | Billig, ett minimum i M8 |
| 5 | **Bröstets bakåtlutning i finishen** | FO | GolfTEC: 3,2° (31+) till 32° (tour), största spridningen mellan grupper | Billig, finns i M14 |
| 6 | **Nedsvingens tid** i katalogen | båda | Tour 0,23–0,32 s. Kvoten skiljer inte nivåer. | Billig, finns i M5 |
| 7 | **Höftlinjen vid topp och träff** i katalogen | FO | Sportsbox ±8°, TWU r ≈ 0,5 | Billig, finns i M18 |
| 8 | Kroppens tyngdpunkt i sidled | FO | Samma källor som 3 | Medel: kräver segmentmodell, och Vision saknar fötter |
| 9 | Separationen vid träffen | 3D | Meister 33 ± 6°, Madrid 2020 (kunde inte läsas) | Billig i S6 |
| 10 | Handledens vinkling och släppet | FO + klubba | Chu, Joyce (bara abstract). Skaftvinkel i 2D inom ≈ 1° (Hunter 2022). | S7 |
| 11 | **Avvikelse från leveransplanet** | DTL + klubba | Morrison 2018: förklarade 57 % av spridningen i träffpunkt (läst i original). Det enda klubbmåttet med samband med träffbilden. | S7. Kandidat till något unikt. |

**Går inte i 2D:** handledens böjning och sträckning, bäckenets framåtlutning,
nya huvudmått och den kinematiska sekvensen ur en kamera. Den sista gav fel
ordning i golf (Ingwersen 2023), och ska inte visas som spelarens fel.

## 6. Svagast belagda av dagens mått

Ur 5d. Sway gap har strukits från listan, eftersom definitionen nu är löst.

1. `genomsving_s` (M36): inget samband med utfall hittat.
2. `tempo` som kvot (M5). Den absoluta tiden är bättre belagd.
3. Huvudets mått (M8, M9): en konferens med 8 golfare, och motstridig.
4. Knänas sway (M34): bara att Sportsbox listar dem.
5. `flying_elbow` (M12) och `over_the_top`/`handbana` (M13): inga gränser och
   inget utfall. Händernas bana är inte klubbans.
6. `reverse_spine` (M14): bara TPI.
7. `backen_bojning` (M30): en skattning. Bäckenets framåtböjning är minst
   repeterbar mellan dagar (Evans 2012).
8. Ordningen i `katalog_3d.json` (stretch före X-faktor): Kwon och Madrid
   fann inget samband för någon av dem. Separationen vid träffen är bättre
   kandidat. Madrid behöver läsas innan ordningen ändras.

**Bättre belagt än research 1 trodde:** bäckenets sway vid topp och träff (två
tillverkare åt samma håll, GolfTEC:s trappa över sex grupper), thrust (tour-tal
och ideal) och chicken wing (skickliga sträcker armbågen mer, via Bourgain 2022).

## 7. Fortfarande inte läst i original

| Källa | Varför | Vad som hänger på den |
|---|---|---|
| Madrid 2020 (Appl Sci 10:5728, 66 skickliga) | 403 | Separationen vid träff i stället för X-faktor/stretch, nedsvingens tid |
| Zheng 2008, IJSM 29(6) | Betalvägg | Bäckenets vridning per handicapgrupp |
| Cheetham 2001 | bepress nedlagt (finns som PDF på philcheetham.com, läst av 5c: 10 mot 9, 30 Hz) | Stretch 19 % mot 13 % |
| Smith/Mears 2017 (COG/COP, EJSS) och Jones 2023 | 403 / bara abstract | Skiftets tidpunkt: r-värden |
| TWU (Han 2016) | 403 | Höftlinjen ↔ klubbfart |
| Griffith (Evans 2012), Joyce 2016/2017, Chu 2010, Brown 2013 | 403 / bara abstract | Talen i abstract räcker. Effektstorlekar saknas. |
| Sportsbox-kursen (teachable) | Inloggning | Indikatorernas exakta definitioner |
| GEARS, golfdigest.com (US), GolfWRX | 429 / 403 | Inga tal väntas. Golf Digest lästes via ME- och AU-utgåvorna. |

## 8. Öppna frågor

- **S0:** räknades oktobers axellutning mot adressen eller mot vågrätt? Jämför
  med 22–25° (järn) på en bildruta.
- Klubban i passet: ska katalogen ha gränser per klubba (driver/järn), eller
  bara egen baslinje per klubba? **Besvarad** (Johannes 2026-10-23, BESLUT B45):
  egen baslinje per klubba räcker; katalogen får inga gränser per klubba.
- Hur nära kommer tyngdpunkten ur 13 leder en full segmentmodell? Prova på
  en påhittad sving med kända segment.
- Vision har öron, ögon och nacke, men SwingLab läser 13 leder (M1). Öra–höft
  var Yamamotos linje för framåtlutningen.
- Madrid 2020 och Jones 2023 i fulltext, via ett bibliotek eller en förfrågan
  till författaren.
