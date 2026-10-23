# R5 — Sportsbox i original (2026-10-23)

Läst härifrån med WebFetch och browser-panen. Hjälpcentret gick att läsa. Golf Digest gav 403 i WebFetch men lästes i browser-panen.
Tour-tabellerna finns bara som bilder. Jag öppnade bilderna i full storlek och läste av siffrorna, med inzoomning som kontroll.

Status: **läst i original** · **rättad: var X** · **ej i källan** · **kunde inte läsas** · **ny** (fanns inte i 1/4 förut).

---

## A. Definitioner och tecken (Sportsbox egna)

Huvudkällor:
- T-NUM = https://help.sportsbox.ai/what-is-a-tracker-numbers-in-the-sportsbox-3dgolf-app
- T-VIS = https://help.sportsbox.ai/what-is-a-tracker-in-the-sportsbox-3dgolf-app
- DTL = https://help.sportsbox.ai/what-trackers-and-indicators-are-available-with-dtl-down-the-line
- Måttsidorna har formen `https://help.sportsbox.ai/<mått>`, t.ex. `/pelvis-sway`.

| Mått | Värde/definition | Källa-URL | Status |
|---|---|---|---|
| Nollpunkt, linjära mått | Sway, lift och thrust är 0 vid adress. | T-NUM, /pelvis-sway, /pelvis-lift, /pelvis-thrust | läst i original |
| Nollpunkt, vinklar | Vinklarna nollas **inte** vid adress. Turn mäts mot linjen genom fotlederna, bend mot lodlinjen och side bend mot vågrätt. Tour vid adress: bröstets turn 10°, bend 39°, side bend 15°. | T-NUM, https://help.sportsbox.ai/what-0-degree-line-is-the-turn-angle-based-on-in-the-sportsbox-3dgolf-app | rättad: var "varje kroppsdel mäts relativt adressen (P1 = 0)" i 4 §Grunden |
| 6 DoF-artikeln | Ger bara namnen (lift = upp/ned, thrust = fram/bak, sway = vänster/höger). Inga tecken och ingen nollpunkt. | https://help.sportsbox.ai/six-degrees-of-freedom | läst i original |
| Sway (bäcken, bröst, huvud, händer, knän) | Tum. 0 vid adress. **+ = mot målet, − = bort från målet.** Vy FO. | T-NUM, /pelvis-sway, /chest-sway, /head-sway | läst i original |
| Bäckenets mittpunkt | Punkten mellan höger och vänster höftled. | https://help.sportsbox.ai/what-is-pelvis-lift | ny |
| Skalning | Längd, kön och höftbredd skalar alla mått. Höftbredden räknas ur längd och kön. | https://help.sportsbox.ai/how-do-i-determine-my-hip-measurement-in-the-sportsbox-3dgolf-app | ny |
| Lift (bäcken, bröst, huvud, händer) | Tum. 0 vid adress. **+ = upp, − = ned ("drop").** | T-NUM, /pelvis-lift, /chest-lift | läst i original |
| Pelvis Lift at IMP (indikator) | Är **inte** trackerns värde. Den mäter lyftet från lägsta punkten i nedsvingen ("max drop") till träffen. Bara i 3D Pro. | https://help.sportsbox.ai/what-is-pelvis-lift | ny |
| Thrust (bäcken, bröst, huvud, händer, klubba) | Tum. 0 vid adress. **+ = mot bollen, − = bort från bollen.** Bara vy DTL. | DTL, /pelvis-thrust | läst i original |
| Chest Thrust, felskrivning | Måttsidan beskriver av misstag klubbhuvudet. DTL-artikeln har rätt text: bröstet, + mot bollen. | https://help.sportsbox.ai/chest-trust | ny (källfel) |
| Turn (bäcken, bröst) | Grader. 0 = linjen genom fotlederna. **+ = öppen mot målet, − = vriden bort.** | T-NUM, /pelvis-turn, /chest-turn | läst i original |
| Bend (bröst) | Grader. 0 = lodrätt. **+ = framåt, − = bakåt.** | T-NUM, /chest-bend | läst i original |
| Pelvis Bend | Finns inte som tracker någonstans i hjälpcentret och inte i tour-tabellen. | T-NUM, T-VIS, DTL, https://help.sportsbox.ai/education | ej i källan (4 §1 listar det under 6 DoF ✔) |
| Side Bend (bröst, bäcken) | Grader. 0 = vågrätt. **+ = mot bakre sidan (bakre sidan lägre), − = mot främre sidan.** | T-NUM, /chest-side-bend, /pelvis-side-bend | läst i original |
| Forehead Sway / Lift | Punkt på pannan, tum, 0 vid adress. Sway: − = bort (A), + = mot (T). Huvudets vridning påverkar. Lift: − ned, + upp. | T-VIS | läst i original |
| Head Sway / Lift / Thrust | Samma tecken som för bäckenet. Head Thrust kräver 3D Pro. | /head-sway, /head-lift, /head-thrust, DTL | ny |
| Mid-Hand Sway / Lift (= Hand Sway / Lift) | Greppets mittpunkt, tum, 0 vid adress. Sway: + mot målet. Lift: + upp. | T-VIS, /hand-sway, /hand-lift | läst i original |
| Hand Speed | Mittpunkten mellan händerna på skaftet, mph. Resultant, alltid positiv. | /hand-speed, T-NUM | läst i original |
| Sway Gap | Vågrätt avstånd mellan bröstets och bäckenets mitt, i tum. **− = bröstet längre från målet än bäckenet.** Nollas **inte** vid adress (tour driver −1,4 tum vid P1). | https://help.sportsbox.ai/what-is-sway-gap, T-NUM | läst i original. Nollningen är ny. |
| Sway Gap, ändring | Gap(P) = gap(adress) + (bröstets sway − bäckenets sway). Kontroll mot Kordas tal: −6,9 + (−0,1 − 2,9) = −9,9 cm. | https://www.golfdigest-minna.jp/_ct/17693045 | rättad: var "går inte ihop med subtraktion" (1 §1.3) |
| Sway Gap, ursprung | Hjälpcentret säger att Terry Rowles gjorde begreppet känt. Golf Digest skriver att Sportsbox myntade det. | https://help.sportsbox.ai/sway-gap, https://www.golfdigest.com/story/sway-gap-golf-digest-tip-backswing-downswing | ny |
| Sway Gap, betydelse | Vid toppen: nära 0 eller positivt = "reverse pivot". I nedsvingen ger negativt gap mer höger svingriktning, positivt mer vänster. | /what-is-sway-gap, /sway-gap | ny |
| Club-Hand Gap | Klubbhuvudet mot händerna, vy DTL. **− = bakom händerna, + = före.** Bara 3D Pro. | https://help.sportsbox.ai/club-hand-gap, DTL | läst i original |
| X-Factor | Bröstets turn relativt bäckenets, i grader. **+ = bröstet öppnare mot målet än bäckenet.** Negativt i baksvingen. | https://help.sportsbox.ai/x-factor, T-NUM | ny (tecknet) |
| X-Factor Stretch | X-faktorn när bäckenet vänder, jämförd med dess max i nedsvingen. Exempel: 50° → 55° ger stretch 5°. Talen räknas i belopp. | https://help.sportsbox.ai/rory-mcilroys-incredible-power-pelvis-slide | ny (källa till 4 §7 ◐) |
| Recentrering | Bäckenets största sway i baksvingen (P2–P3) minus dess sway vid toppen. Under 1 tum = för lite eller för sent. | samma | ny |
| Kinematisk sekvens | Ordning, tidpunkt och vridfart för bäcken, bröst, arm och skaft i nedsvingen. Ordningen ska vara bäcken → bröst → arm → klubba. | T-NUM, https://help.sportsbox.ai/transition-order, https://help.sportsbox.ai/what-is-the-kinematic-sequence-in-the-sportsbox-3dgolf-app | läst i original |
| Gain factors | Core = bröstets maxfart / bäckenets. Shoulder = armens / bröstets. Wrist = skaftets / armens. Release = klubbhuvudets / handens. | https://help.sportsbox.ai/what-is-a-gain-factor-in-the-sportsbox-3dgolf-app | läst i original |
| Gain factors, villkor | Bara svingar inspelade i appen, i bra ljus. Bara Pro Premium och Enterprise, inte Pro Lite. | samma | läst i original (planvillkoret är nytt) |
| Knäts och armbågens flexion | 180° = rakt led, lägre = böjt. T-NUM säger "0 vid adress" om flex, vilket motsäger 180°. | T-VIS, DTL, T-NUM | ny (källan är oenig) |
| Positioner | Hjälpcentret listar 7: ADR, BCH, TOP, DCH, IMP, FCH, FIN. Tour-tabellen har 9: P1–P8 och P10 (ingen P9), alltså också BAH (P3) och DAH (P5). TOP = där klubban byter riktning (FO). IMP = sista bilden före träff. FIN = lägst vinkelfart efter FCH. | https://help.sportsbox.ai/what-are-swing-positions, https://help.sportsbox.ai/tour-ranges-for | ny |
| Tempo | Baksvingens tid / nedsvingens. Driver typiskt cirka 3:1. | https://help.sportsbox.ai/what-does-tempo-mean-in-the-sportsbox-3dgolf-app | läst i original |

---

## B. Tour-medel, män, driver och mellanjärn (P1–P10)

Källa: https://help.sportsbox.ai/tour-ranges-for. Sidan säger att det är 100+ PGA- och LPGA-proffs.
Värdena finns **bara i bild** (`/hubfs/1-Oct-10-2024-05-55-44-1852-PM.png`). Jag har läst av dem från bilden i full storlek.
Status för hela tabellen: **läst i original (bild)**. Vinklar i grader, sträckor i tum. D = driver, J = mellanjärn.

| Mått | | P1 ADR | P2 BCH | P3 BAH | P4 TOP | P5 DAH | P6 DCH | P7 IMP | P8 FCH | P10 FIN |
|---|---|---|---|---|---|---|---|---|---|---|
| Chest Turn | D | 10 | −43 | −73 | −98 | −51 | 6 | 30 | 69 | 161 |
| | J | 7 | −40 | −69 | −93 | −50 | −1 | 25 | 64 | 154 |
| Pelvis Turn | D | 4 | −23 | −35 | −40 | −11 | 23 | 38 | 55 | 113 |
| | J | 2 | −20 | −32 | −36 | −11 | 17 | 34 | 50 | 106 |
| Chest Bend | D | 39 | 35 | 18 | 1 | 32 | 45 | 35 | 7 | −33 |
| | J | 44 | 35 | 18 | 0 | 30 | 47 | 43 | 12 | −35 |
| Chest Side Bend | D | 15 | −18 | −35 | −38 | −24 | 14 | 32 | 52 | 2 |
| | J | 11 | −20 | −38 | −43 | −28 | 4 | 22 | 49 | 5 |
| Pelvis Side Bend | D | 1 | −4 | −8 | −8 | −5 | 5 | 8 | 10 | 1 |
| | J | 1 | −4 | −8 | −8 | −5 | 3 | 7 | 11 | 1 |
| Sway Gap (tum) | D | −1,4 | −1,9 | −1,9 | −2,2 | −2,6 | −5,1 | −6,7 | −7,5 | −1,4 |
| | J | −1,0 | −1,2 | −1,0 | −1,1 | −1,3 | −3,3 | −4,5 | −5,2 | −0,8 |
| Chest Sway (tum) | D | 0,0 | −1,9 | −2,0 | −1,3 | 0,7 | 0,0 | −0,7 | −0,8 | 6,6 |
| | J | 0,0 | −0,8 | −0,8 | −0,1 | 2,0 | 1,8 | 1,3 | 1,2 | 6,7 |
| Pelvis Sway (tum) | D | 0,0 | −1,4 | −1,6 | −0,6 | 1,9 | 3,7 | 4,5 | 5,3 | 6,5 |
| | J | 0,0 | −0,6 | −0,8 | 0,0 | 2,3 | 4,0 | 4,8 | 5,4 | 6,6 |
| Chest Lift (tum) | D | 0,0 | −0,3 | −0,5 | −0,8 | −2,3 | −1,5 | −1,1 | −0,9 | 4,3 |
| | J | 0,0 | −0,3 | −0,5 | −0,8 | −1,9 | −1,1 | −0,6 | 0,2 | 5,4 |
| Pelvis Lift (tum) | D | 0,0 | −0,6 | −1,2 | −1,7 | −1,5 | 0,1 | 0,9 | 1,2 | 1,3 |
| | J | 0,0 | −0,2 | −0,9 | −1,4 | −1,1 | 0,3 | 0,9 | 1,2 | 2,0 |

- Tabellen har **ingen thrust, inga huvud- eller handmått och ingen X-faktor**.
- X-faktor = bröstets turn − bäckenets turn (**härlett**, ej publicerat). Driver: P4 −58°, P6 −17°, P7 −8°. Järn: P4 −57°, P7 −9°.
- Kvinnornas tabell finns i bilden `/hubfs/2-Oct-10-2024-05-55-43-9779-PM.png` (läst). Driver P4/P7: bröstets turn −102/32, bäckenets turn −44/42, bröstets side bend −33/30, sway gap −1,3/−5,7, bäckenets sway −1,0/3,4.
- Sidan anger också att chest bend, chest side bend, pelvis side bend och sway gap bara finns i 3D Pro.

### Övriga tour-tal (män om inget annat står)

| Mått | Värde | Källa-URL | Status |
|---|---|---|---|
| Pelvis Thrust, pro | Topp 0,7 tum (SD 1,1), träff 0,5 tum (SD 1,4). Kvinnor: 1,5 (SD 0,6) och 2,1 (SD 1,2). Bara i bild. Rubriken säger av misstag "Pelvis Sway". Klubba anges inte. | https://help.sportsbox.ai/what-is-early-extension | ny |
| Pelvis Thrust vid träff, idealintervall | −0,9 till 1,7 tum, för en man av DeChambeaus storlek. | samma | ny (1 §1.6 "okänt") |
| Pelvis Thrust, rörelsen | Lite framåt i baksvingen, bakåt i nedsvingen, framåt igen in i träffen. | samma | ny |
| Bäckenets sway vid träff, medel | Män cirka 4,5 tum, kvinnor cirka 3,5 tum. Proffs svajar 1–3 tum i baksvingen och recentrerar mellan P2 och P3. | https://help.sportsbox.ai/rory-mcilroy-busting-the-myth-around-sway | ny |
| X-Factor max, tour | Medel 64° (belopp). DeChambeau 72–75°. | https://help.sportsbox.ai/bryson-dechambeaus-long-drives-his-incredible-chest-turn | ny |
| Bäckenets turn vid P6 (DCH) | Tour cirka 17–29° öppen. | https://help.sportsbox.ai/creating-speed-with-min-woo-lee-creating-rotational-force | ny (stämmer med tabellen: 23/17) |
| Max vridfart, driver | Bäcken 484, bröst 725, överarm 1 005, skaft 2 277 °/s. Kvinnor: 510, 716, 960, 1 903. | https://help.sportsbox.ai/what-is-the-kinematic-sequence-in-the-sportsbox-3dgolf-app, T-NUM | ny (4 §7 ◐ blir bekräftat) |
| Gain factors, driver | Core 1,5/1,4 · Shoulder 1,4/1,3 · Wrist 2,3/2,0 · Release 5,0/4,8 (män/kvinnor) | gain factor-artikeln, T-NUM | läst i original |
| Tider, driver | Baksving 0,82 s, nedsving 0,26 s (kvinnor 0,96/0,29). Handens maxfart 69 ms före träff (kvinnor 93). Klubbhuvud 110 mph (kvinnor 95). | T-NUM | ny |
| Noggrannhet mot AMM3D | 30 golfare, en driversving var. Vinklar i snitt 2,2°/2,5°/2,0° (ADR/TOP/IMP). Sträckor 0,6 tum vid TOP och 0,2 tum vid IMP. Största fel: bröstets bend vid IMP 6,0° och bäckenets turn vid TOP 4,9°. Tabellen är en bild. | https://help.sportsbox.ai/sportsbox-ai-accuracy | ny |

---

## C. Källorna i 1_matt_och_granser.md

| Påstående i 1 | Värde i källan | Källa-URL | Status |
|---|---|---|---|
| §1.1 Sportsbox: bäckenets sway från adress, tum, FO | Artikeln bekräftar sway mot målet i tum. Definitionen står i hjälpcentret. | https://www.golfdigest.com/story/useful-golf-swingfacts-sportsbox-ai-graph | läst i original |
| §1.1 GolfTEC tour topp 3,9 tum, höghandicap 2,55 tum mot målet | Bekräftat. **Referenspunkten är svanskotan**, som flyttas mot målet när höfterna vrids. | https://www.golfdigest.com/story/swing-by-numbers-new-study-unlocks-6-swing-secrets | läst i original. Referensen är ny och förklarar skillnaden mot Sportsbox. |
| §1.1 Sportsbox låg/hög handicap vid P4 | Bekräftat: höghandicappers bäcken har gått "flera tum" bort från målet, låghandicappers ligger närmare 0. Låghandicappers börjar flytta tillbaka före toppen. Inga tal. Zephyr Melton, 10 sep 2026, citerar Jeehae Lee. | https://golf.com/instruction/one-piece-swing-data-separate-low-high-handicap/ | läst i original |
| §1.1 Sportsbox tour vid toppen ≈ 0 | −0,6 tum (−1,5 cm) med driver, 0,0 med järn | tour-ranges-for (bild) | läst i original |
| §1.1 "De flesta golfare har höfterna upp till 6 tum mot målet vid träff" | Fel. Artikeln: proffs flyttar höfterna cirka 6 tum, amatörer sällan mer än 2 tum. Under 5 tum är "pretty standard" på touren, 6,5 tum är "high end of the optimal range". Mätt med Sportsbox. | https://www.golfdigest.com/story/Tiger-woods-golf-swing-technology-metric-golf-digest-video | rättad: var "de flesta golfare upp till 6 tum" |
| §1.1 Tiger > 6 tum i en tidig sving | Bekräftat: tidig sving > 6 tum, 2013-svingen 8 tum, idag cirka 6,5 tum. | samma | läst i original |
| §1.1 Sportsbox tour vid träff "+13 cm" | Tabellen ger driver 4,5 tum = **11,4 cm** och järn 4,8 tum = 12,2 cm. Golf Digest skriver "upwards of five inches" (12,7 cm) vid träff, och de 13 cm kommer troligen därifrån. | tour-ranges-for (bild), https://www.golfdigest.com/story/useful-golf-swingfacts-sportsbox-ai-graph | rättad: var +13 cm (ej återfunnen) |
| §1.1 GolfTEC tour vid träff 1,6 tum | Bekräftat. Höghandicap −0,4 tum (bort från målet). | swing-by-numbers | läst i original (höghandicap ny) |
| §1.3 sway gap-definitionen | Se A. Ordningen är "bröst relativt bäcken", negativt = bröstet bakom. Golf Digest kallar det skillnaden i sway mellan över- och underkropp. | https://www.golfdigest.com/story/sway-gap-golf-digest-tip-backswing-downswing | läst i original |
| §1.3 Sportsbox-kursen | Inloggning krävs ("Lesson content locked"). Bara lektionernas namn syns. | https://sportsbox-ai.teachable.com/courses/1823246/lectures/50899301 | kunde inte läsas |
| §1.3 "Negativt sway gap i 100 % av tourspelarna" | Rätt. Det står i punkten "Hips toward the target" (lead hip närmare målet vid träff än vid adress). Inget tal. Det andra 100 %-påståendet gäller att bäckenets turn är större än bröstets vid träff. Zephyr Melton, 3 mar 2025. | https://golf.com/instruction/three-musts-solid-ball-striking-sportbox-ai-playsmart/ | läst i original |
| §1.3 "Tour > 16,5 cm" | Golf Digest: manliga proffs har sway gap "more than 6.5 inches by impact" (= 16,5 cm). Tabellen ger driver −6,7 tum (−17,0 cm) och järn −4,5 tum (−11,4 cm). Sportsbox tecken är **negativt**. Dunlap: −2,5 tum vid toppen och −6,5 tum vid träff. | useful-golf-swingfacts, sway-gap-artikeln, tour-ranges-for | rättad: var "ej återfunnen". Gäller driver, tecknet är minus. |
| §1.3 Japanska exemplet (−9,9 cm) | Korda: gap −6,9 cm vid adress, −9,9 vid toppen, −27,6 vid träff. LPGA-intervall vid träff −11,7 till −16,8 cm. Adressintervallet står som "−1,8〜5,3cm(右)", troligen menat −1,8 till −5,3. | https://www.golfdigest-minna.jp/_ct/17693045 | läst i original. Gåtan är löst, se A. |
| §1.4 Bröstets sidböjning vid träff 24,1–37,5° | Bekräftat. Det är PGA-touren vid träff med driver, i Sportsbox egen undersökning. Samma artikel: bröstets turn vid träff 19,4–37,6°, bäckenets turn 26,3–43,7°. Kitano, 6 jan 2024. | https://www.golfdigest-minna.jp/_ct/17677047 | läst i original (rätt sida). Turn-intervallen är nya. |
| §1.4 Tour-medel för bröstets sidböjning | Driver: 15 vid adress, −38 vid toppen, +32 vid träff. Järn: 11, −43, +22. | tour-ranges-for (bild) | ny |
| §1.4 GolfTEC shoulder tilt, topp 36° / 29,6° | Bekräftat | swing-by-numbers | läst i original |
| §1.4 GolfTEC shoulder tilt, träff 39° | Bekräftat. Höghandicap 27,5°. Det största språnget är mellan handicap 0–5 och proffs. | swing-by-numbers | läst i original (höghandicap ny) |
| §1.5 GolfTEC shoulder bend vid adress cirka 40° | Står inte i Golf Digest-artikeln | swing-by-numbers | ej i källan |
| §1.5 GolfTEC shoulder bend i finish 32° | Bekräftat. Höghandicap 3,2°. | swing-by-numbers | läst i original |
| §1.5 Tour vid träff "okänt i grader" | Sportsbox bröstets bend: adress 39 → träff 35 (driver), 44 → 43 (järn) | tour-ranges-for (bild) | ny |
| §1.6 Sportsbox thrust i tum "okänt" | Medel vid träff 0,5 tum (SD 1,4). Ideal −0,9 till 1,7 tum. | what-is-early-extension | ny |
| §1.7 Sportsbox bäckenets turn, topp ≈ −40° | −40 med driver, −36 med järn | tour-ranges-for (bild), useful-golf-swingfacts | läst i original |
| §1.7 Sportsbox bäckenets turn, träff ≈ +40° | Tabellen ger **+38** med driver och +34 med järn. Golf Digest avrundar till 40 (mot bröstets 30). | samma | rättad: var ≈ +40 |
| §1.7 GolfTEC per handicap vid träff, "exakta tal ej hittade" | Proffs 36° öppen, höghandicap 19,5° | swing-by-numbers | rättad: talen finns |
| Golf Digest påstår "lose almost all their chest turn" vid toppen | Ett skrivfel i artikeln: det är chest **bend** som går mot 0 (1° vid toppen). | useful-golf-swingfacts | ny (källfel) |

---

## D. Källorna i 4_sportsbox_matt.md

| Påstående i 4 | Utfall | Källa-URL | Status |
|---|---|---|---|
| 6 DoF: sway/lift/thrust, turn/bend/side bend | Bekräftat, men artikeln ger inga tecken | https://help.sportsbox.ai/six-degrees-of-freedom | läst i original |
| "Teckenkonventionerna är inte bekräftade" | Alla är nu bekräftade, se A | T-NUM, T-VIS, DTL | rättad |
| Pelvis Bend ✔ | Ingen sådan tracker finns | se A | ej i källan |
| Gain factors 1,5/1,4 · 1,4/1,3 · 2,3/2,0 · 5,0/4,8 | Bekräftat: proffs med driver | gain factor-artikeln | läst i original |
| "Sportsbox smash factor" | Bekräftat | samma | läst i original |
| Bara inspelade i appen, bra ljus | Bekräftat | samma | läst i original |
| Universal Swing Score = medel av tre percentiler, samma kön, minst 3 svingar | Bekräftat. Järn eller driver. Efficiency-formeln publiceras inte. Ny uppgift: över 70 % korrelation mellan Swing Score och handicap. | https://help.sportsbox.ai/what-is-sportsbox-universal-swing-score | läst i original |
| Swing Score Report | Bara en översikt i text. Allt innehåll ligger i bilder. | https://help.sportsbox.ai/universal-swing-score-report | läst i original (bilder ej lästa) |
| Mid-Hand Sway heter Hand sway i FON | Bekräftat | T-VIS, T-NUM | läst i original |
| ◐ Mid-Hand Speed / Max Hand Speed | Finns ("Max Hand Speed" i fliken Numbers) | T-VIS | rättad: ◐ → ✔ |
| ◐ Lead Arm Angle | Finns inte. Det som finns är Lead Elbow Flex och Lead Wrist Angle (180° = rak). | T-NUM | rättad |
| ◐ Knee Flexion och Knee Sway | Finns båda | T-VIS, DTL | rättad: ◐ → ✔ |
| ◐ Max turn speeds, Max Shaft Speed, Kinematic Sequence | Finns, med tour-medel (se B) | kinematic sequence-artikeln | rättad: ◐ → ✔ |
| ◐ X-Factor / Stretch | X-Factor är en tracker. Stretch beskrivs i en proffsartikel, inte som en egen tracker i listorna. | /x-factor, /rory-mcilroys-incredible-power-pelvis-slide | rättad: ◐ → ✔ (stretch som begrepp) |
| ◐ Backswing/Downswing/Follow-through time, Tempo, Hand Speed Max Timing | Finns alla | T-NUM | rättad: ◐ → ✔ |
| Golf.com Speed Assessment: vridning, vertikal rörelse, release | Bekräftat. Visar "power leaks" och en möjlig klubbfart. Zephyr Melton, 30 apr 2024. | https://golf.com/instruction/driving/check-clubhead-speed-sportsbox-ai/ | läst i original |
| Golf.com "sway" | Terry Rowles, 11 jun 2023, Sportsbox-anställd. Råd: matcha sway mot greppet. Kontroll vid toppen: bröstbenets linje ska ligga bakom gylfens. Inga tal. | https://golf.com/instruction/key-to-better-ball-striking-sportsbox/ | läst i original |
| Phil Cheetham 6DOF | Bekräftar 6DOF och att segmentens mitt mäts. Inga tecken. | https://www.philcheetham.com/analyzing-the-golf-swing-in-6-degrees-of-freedom-with-amm-6dof-systems/ | läst i original |
| Clubhouse Hawaii, X-factor | Tredjepart. X-faktorn anges i grader per handicap (tour 40–55°, hög 15–25°). Talen stämmer inte med Sportsbox tabell (−58° vid toppen) eller max 64°. **Använd inte.** | https://clubhousehawaii.com/blogs/news/sportsbox-ai-x-factor-swing-analysis | läst i original |
| Golficity-recension | 503 i browser-panen, timeout i WebFetch | https://golficity.com/sportsbox-ai-review-turn-your-phone-into-a-3d-golf-coach/ | kunde inte läsas |
| App Store | Nämner sway, turn, tilt och side bend samt jämförelse mot eliten. Version 2.53.0. | https://apps.apple.com/us/app/sportsbox-3d-golf/id1578921026 | läst i original |

---

## E. Låg mot hög handicap enligt Sportsbox

| Mått | Låg/tour | Hög/amatör | Källa-URL | Status |
|---|---|---|---|---|
| Bäckenets sway vid P4 | Nära 0. Recentrering före toppen. | "Flera tum" bort från målet | https://golf.com/instruction/one-piece-swing-data-separate-low-high-handicap/ | läst i original |
| Bäckenets sway vid träff | Proffs cirka 6 tum (mätt med Sportsbox) | Amatörer sällan över 2 tum | https://www.golfdigest.com/story/Tiger-woods-golf-swing-technology-metric-golf-digest-video | läst i original |
| Sway gap vid träff | Proffs (män) över 6,5 tum | "Much smaller", inget tal | https://www.golfdigest.com/story/useful-golf-swingfacts-sportsbox-ai-graph | läst i original |
| Sway, slicer mot tourspelare | Tour: bäcken cirka 5 tum mot målet, bröst cirka 3. | Slicer: bäcken cirka 3, bröst nästan 6. Positionen ("first frame") är oklar. Luke Kerr-Dineen, 7 sep 2022. | https://golf.com/instruction/fatal-mistake-causing-your-slice/ | ny |
| Swing Score och handicap | Över 70 % korrelation | – | https://help.sportsbox.ai/what-is-sportsbox-universal-swing-score | ny |
| Tour mot amatör, X-faktor | Clubhouse Hawaii ger intervall per handicap men stämmer inte med Sportsbox | – | clubhousehawaii (se D) | ej användbar |

---

## Viktigast för SwingLabs katalog

1. **Bara linjära mått nollas vid adress.** Vinklarna är absoluta: turn mot fotledslinjen, bend mot lodlinjen, side bend mot vågrätt. Sway gap är ett absolut avstånd (tour P1 −1,4 tum). Jämför vi en adressnollad sidböjning eller ett adressnollat gap mot tour blir det fel. Det är troligen orsaken till oktobers "axellutning långt under tour".
2. **Tecken att ta efter (Sportsbox):** sway + mot målet · lift + upp · thrust + mot bollen · turn + öppen · bend + framåt · side bend + när bakre sidan är lägre · sway gap − när bröstet är bakom bäckenet · X-faktor = bröst − bäcken (negativ i baksvingen).
3. **Tour-medel, män, driver:** bäckenets sway P4 −0,6 tum (−1,5 cm), P7 +4,5 tum (+11,4 cm). Sway gap P4 −2,2 tum (−5,6 cm), P7 −6,7 tum (−17,0 cm). Bröstets side bend P4 −38°, P7 +32°. Bäckenets turn −40/+38. Bröstets turn −98/+30. Bröstets bend 39 → 35.
4. **Järnet skiljer sig:** sway gap vid träff −4,5 tum mot −6,7 med driver, och side bend +22° mot +32°. Gränser behöver klubba, eller så ska vi bara jämföra med samma klubba.
5. **"+13 cm" och "> 16,5 cm" är Golf Digests avrundningar** av driver-tabellen ("upwards of five inches", "more than 6.5 inches"). Använd tabellens tal: +11,4 cm och −17,0 cm.
6. **Thrust vid träff har nu ett tour-tal:** medel +0,5 tum (SD 1,4), ideal −0,9 till +1,7 tum. Positivt (mot bollen) över cirka 1,7 tum (4,3 cm) = early extension enligt Sportsbox.
7. **GolfTEC:s +3,9 tum vid toppen** mäts på svanskotan, som flyttas mot målet när höfterna vrids. Det är inte samma mått som Sportsbox bäckenmitt, och de två ska inte blandas i en gräns.
8. **Sportsbox egen noggrannhet mot AMM3D** (30 driversvingar): cirka 2–2,5° i vinkel och 0,2–0,6 tum i sträcka. Bröstets bend vid träff är sämst (6°). Det är golvet för vad en tour-jämförelse kan säga, även för 3D ur en kamera.
