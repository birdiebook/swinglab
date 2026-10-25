# 6. Ranges: vilka mått får ett band med källa (2026-10-25)

Underlag för etappen S4g (PLAN §S4g). Johannes mål 2026-10-25: det som redan är
byggt ska bli bättre, och siffrorna ska gå att förstå direkt med en range, alltså
bara innanför och utanför. Först söks fler källor, så att så många mått som möjligt
får en range med källa. Därefter avgör Johannes resten.

Samma dag kom en princip till: **"om vi inte kan säga vad som är bra eller dåligt för
ett mått då behöver vi fundera på om det ska vara med, om det inte kan hjälpa spelaren
att bli bättre kan infon förvirra mer än hjälpa"** (Johannes 2026-10-25). Varje mått
utan källa har därför fått en dom: (a) behåll, (b) flytta eller (c) ta bort.

**Ingenting i katalogen, METOD eller koden är ändrat.** Det görs i bygget efter
Johannes beslut. Status som i research 5: **läst i original** · **bara abstract** ·
**ej läst i original** (bara sökmotorns sammanfattning, B10) · **tillverkare /
tränare / forskning** · **antagande**.

## Sammanfattning

Katalogen har **80 rader**: 12 fel, 61 mått (26 bakifrån, 35 framifrån), 2 spridningar
och 5 mått i 3D. Varje rad står i §3.

| Kategori | Antal | Vilka |
|---|---|---|
| **Ta in** (samma mått, källan ger spannet) | **1** | `early_extension` |
| **Ta in med förbehåll** (nära, med känd skillnad; spannet ur källan eller ur ett tour-medel) | **23** | 4 fel, 17 mått, 2 i 3D (listan nedan) |
| **Ingen range med källa** | **56** | domarna i tabellen nedan: 15 (a), 33 (b), 8 (c) |

### Måtten som får en range med källa

Järn är standard (Johannes 7-järn i vinter); driverns tal står i §3. "Tour ± golv" är
regeln i §2: Sportsbox tour-medel för mellanjärn plus minus brusgolvet (2 cm, 5°).

| Mått (vy, position) | Range, järn | Källa | Kategori |
|---|---|---|---|
| `early_extension` / `backen_thrust_traff` (DTL, P7) | −2,3…+4,3 cm | Sportsbox ideal (what-is-early-extension), klubban anges inte | ta in |
| `sway_topp` / `backen_sway_topp` (FO, P4) | ≥ −2,5 cm (båda klubborna) | Sportsbox tour J 0,0 / D −1,5 cm, golf.com (gäller sedan B45) | förbehåll: toppen |
| `tempo` (båda) | 2,5–3,1 | Blast tour, Grober 2006 (gäller sedan B45) | förbehåll: toppen |
| `backens_resa_framat` (FO) | +10,2…+14,2 cm | Sportsbox tabell, tour ± golv | förbehåll |
| `sway_gap` / `sway_gap_traff` (FO, P7) | ≥ +6,9 cm | Sportsbox tabell (+8,9 J), Golf Digest (proffs > 6,5 tum) | förbehåll |
| `brost_bojning_adress` (DTL, P1) | 34–45° | K-Vest "PGA norms" (Grathwohl 2024), Sportsbox 44° J | förbehåll: bröstkorgen |
| `brost_lyft_topp` (DTL och FO, P4) | −4,0…0,0 cm | Sportsbox tabell, tour ± golv | förbehåll |
| `brost_lyft_traff` (DTL och FO, P7) | −3,5…+0,5 cm | Sportsbox tabell, tour ± golv | förbehåll |
| `backen_lyft_min` (DTL och FO, P5) | −5,6…−1,6 cm | Sportsbox tabell, tour ± golv | förbehåll |
| `backen_lyft_in_traff` (DTL och FO, P7) | +3,8…+7,8 cm | Sportsbox tabell, tour ± golv | förbehåll |
| `nedsving_s` (DTL och FO, P7) | 0,23–0,32 s | Blast tour (full sving), Sportsbox 0,26 s (D) | förbehåll: toppen |
| `axellinje_lutning_adress` (FO, P1) | +6…+16° | Sportsbox Chest Side Bend 11° J, tour ± golv | förbehåll: bröstkorgen |
| `hoftlinje_lutning_adress` (FO, P1) | −4…+6° | Sportsbox Pelvis Side Bend 1°, tour ± golv | förbehåll |
| `hoftlinje_lutning_topp` (FO, P4) | −13…−3° | Sportsbox −8°, tour ± golv | förbehåll: projektionen |
| `hoftlinje_lutning_traff` (FO, P7) | +2…+12° | Sportsbox +7° J, tour ± golv | förbehåll: projektionen |
| `backen_sway_p3` (FO, P3) | −4,0…0,0 cm | Sportsbox P3 (BAH) −2,0 cm J, tour ± golv | förbehåll: positionen |
| `backen_resa_p5` (FO, P5) | +3,8…+7,8 cm | Sportsbox P4→P5 +5,8 cm J, tour ± golv | förbehåll: positionen |
| `backen_vrid_topp` (3D) | 30–46° | K-Vest topp −46…−30° (absolut), Sportsbox 38° J från adressen | förbehåll: nollan, 3D-trend |
| `hofter_oppna_traff` (3D) | 30–45° (i dag 35–45) | Myers 2008 (nollad vid adressen), Sportsbox 32° J från adressen, GolfTEC, K-Vest | förbehåll: nollan, 3D-trend |

### Domarna för måtten utan källa

| Dom | Mått | Varför, kort |
|---|---|---|
| **(a) behåll** | `tappad_hallning` (`brost_bojning_tapp`) | Riktningen är känd: bröstet som reser sig är felet (TPI loss of posture). Band: egen baslinje, sämre uppåt. |
| (a) | `reverse_spine` (`sidbojning_topp`) | Definitionen är ett tecken (TPI): lutning mot målet vid toppen är felet. Band ≥ 0° (antagande ur definitionen). |
| (a) | `over_the_top` (`handbana`) | Definitionen är ett tecken: händerna utanför baksvingens bana. Band ≤ 0 cm (antagande ur definitionen). |
| (a) | `chicken_wing` (`framre_armbage_efter_traff`) | Rakare är bättre (TPI, GolfTEC, Bourgain via research 5). Egen baslinje, sämre uppåt. |
| (a) | `bojd_framre_arm` (`framre_armbage_topp`) | Rakare är bättre (GolfTEC: bättre spelare böjer mindre). Egen baslinje, sämre uppåt. |
| (a) | `huvud_mot_bollen_topp`, `_traff` (DTL) | "Så lite som möjligt": skickliga rör huvudet mindre (Byrne & Kenny 2008, ej läst i original). Egen baslinje på beloppet. |
| (a) | `handfart_max` (FO) | Fysik: mer handfart ger mer klubbfart. Egen baslinje, sämre nedåt. Oprovad tills inspelningen är skarp (B11). |
| (a) | `skaft_riktning_topp` (DTL) | Mål 0: skaftet parallellt med mållinjen vid toppen (P-systemet, tränare). Bandets bredd är ett antagande. |
| (a) | `skaft_plan_p6` (DTL) | Mål 0: klubbhuvudet på adressens skaftplan vid P6 (P-systemet). Över planet (+) är brant. Bandets bredd är ett antagande. |
| (a) | `skaft_topp` (FO) | Med järn: inte förbi parallellt. Band ≥ 0° (tränare, antagande). |
| (a) | `skaft_arm_p6` (FO) | Casting (TPI early release) är att vinkeln öppnas tidigt. Egen baslinje, sämre uppåt. |
| (a) | `skaft_lutning_traff` (FO) | Med järn ska greppet vara före klubbhuvudet; bakåt är scooping (TPI). Band ≥ 0°. |
| (a) | spridningen `brost_bojning_adress`, `_traff` | Mindre är bättre (Yamamoto 2023: r = 0,80 mot score). Egen baslinje, sämre uppåt. |
| **(b) flytta** | `axellutning` (avstängd) | Väntar på S0. Därefter kanske Meister 22–28° med järn (§3). |
| (b) | `flying_elbow` (`bakre_armbage_topp`) | Ingen gräns, inget utfall, källan oläst. Stöd för Claude i kedjan mot over the top. |
| (b) | `bakre_kna_adress`, `framre_kna_adress`, `_topp`, `_traff` (DTL) | Inga tour-tal, och knäets sträckning är motstridig. Stöd för tolkningen av early extension. |
| (b) | `backen_bojning_adress` (DTL) | En skattning (M30), ingen bäckenpunkt. Stöd för hållningen i adressen. |
| (b) | `hand_lyft_topp`, `_traff` (båda vyerna) | Inga tour-tal. Hög hand vid träffen följer av thrust och tapp, som redan har egna kort. |
| (b) | `hand_djup_topp`, `framre_arm_plan_topp` (DTL) | Stil, inte fel: både platt och upprätt fungerar. Inga normer. |
| (b) | `huvud_lyft_topp`, `_traff` (båda vyerna) | Bröstets lyft säger samma sak med ett tour-tal. Stöd för tolkningen. |
| (b) | `skaft_vinkel` (båda vyerna), `skaftplan_p1` (DTL) | Råa vinklar som andra mått och positionerna bygger på. Skaftplanet i adressen är mest klubbans lie. |
| (b) | `stans_bredd`, `hander_fore_adress_traff`, `framre_armbage_p3` (FO) | Inget bra eller dåligt utan klubba och kropp. Armbågen vid P3 täcks av felet vid P4. |
| (b) | `bakre_kna_sway_topp` (FO) | Hör till `sway_topp` och förklarar den. Ensam säger den inget. |
| (b) | `handfart_max_fore_traff_ms`, `framre_arm_vinkelfart_max` (FO) | Riktningen är okänd respektive samma sak som handfarten. |
| (b) | `backen_recentrering`, `backen_skifte_ms` (FO) | Säger något bara tillsammans med swayen; skiftet är censurerat och visas redan bara i granskningen (M42). Sportsbox gräns 2,5 cm fäller tour med järn (2,0 cm). |
| (b) | `sidbojning_finish` (FO) | GolfTEC skiljer grupperna, men i 2D syns bara en tredjedel av bakåtlutningen (§4.1). |
| (b) | `brost_vrid_topp`, `xfaktor_topp`, `xfaktor_stretch` (3D) | Inget samband med nivå mellan spelare (Okuda, Kwon); definitionen flyttar X-faktorn 19°. Stöd för Claude som ansträngning inom spelaren (Meister). |
| **(c) ta bort** | `backen_bojning_topp`, `_traff` (DTL) | Visar inte early extension (M30): bålen och låret drar åt var sitt håll. Thrusten mäter felet. |
| (c) | `genomsving_s` (båda vyerna) | Svagast belagt av alla mått (research 5 §6), inget utfall och inget tour-tal. |
| (c) | `huvud_backen_finish` (FO) | Ingen källa och ingen riktning. |
| (c) | `framre_kna_sway_topp`, `_traff`, `bakre_kna_sway_traff` (FO) | Bara att Sportsbox listar dem; inga tal och inget utfall. |

Räknat per rad: (a) 15, (b) 33, (c) 8. Ett mått som finns i båda vyerna räknas två
gånger.

### Besluten Johannes behöver ta

1. **Regeln "tour ± golv"** för mått där källan bara ger ett medel (§2): bandet är
   Sportsbox tour-medel med järn plus minus brusgolvet, 2 cm eller 5°. Det ger 16 av
   de 23 banden med förbehåll (`sway_gap` räknat med). **Förslag: ja**, märkt antagande i katalogen
   (`grans_harledd`). Utan regeln blir det 8 band i stället för 24.
2. **Järn som standard.** Där källan skiljer driver och järn tar katalogen järnets
   band, för vinterns 7-järn. Driverns band står i §3 men byggs inte. **Fråga: ska det
   vara så?** Förslag: ja, och driverns band läggs till när klubban förs in i katalogen
   (B45 omprövas då).
3. **Domarna (a), (b) och (c).** 33 mått flyttas ur sessionen till exporten och
   urklippet, och 8 tas bort. Det ger färre kort och siffror per vy (VISION: djupet ett
   tryck bort). **Förslag: ja.**
4. **Band ur en definition** (`reverse_spine` ≥ 0°, `over_the_top` ≤ 0 cm,
   `skaft_lutning_traff` ≥ 0°, `skaft_topp` ≥ 0°): gränsen är felets eget tecken, inte
   ett tal ur en mätning. **Förslag: ja**, märkt tränare/antagande.
5. **`early_extension` får en nedre gräns**, −2,3 cm (källans ideal), i dag öppen
   nedåt. **Förslag: ja**: bäckenet långt bort från bollen vid träffen är utanför
   idealet hos Sportsbox.
6. **`hofter_oppna_traff` 35–45° blir 30–45°**, eftersom vårt mått nollas vid adressen
   (§3, rad 80). **Förslag: ja.** Och 3D får fortfarande ingen bedömning utan markörer
   (B14): bandet är ett riktmärke. Om 3D ska visa innanför och utanför är Johannes val.
7. **`sidbojning_finish` till (b)**: tour-bröstet är vridet 154–161° i finishen, så
   bakåtlutningen ligger mest i djupled framifrån (§4.1). METOD M14:s antagande att
   bröstet vetter mot målet behöver rättas. **Förslag: ja.**
8. **`nedsving_s` med tour-bandet 0,23–0,32 s**: de flesta amatörer ligger utanför,
   eftersom tiden följer farten. **Förslag: ja**, för bandet säger hur långt till tour-fart.
   Alternativt (b).

## 1. Sökningen: vad som gick (2026-10-25)

- **sportsbox.ai gick inte att läsa härifrån heller.** WebFetch svarade
  `getaddrinfo ENOTFOUND` för help.sportsbox.ai, och curl genom proxyn fick 403
  ("connect_rejected"). Samma sak för golf.com, golfdigest.com, australiangolfdigest,
  golftec.co.za, pmc.ncbi.nlm.nih.gov och wikipedia: **ingen sida gick att hämta i den
  här sessionen.** Sportsbox tabell och definitioner gäller därför som research 5a läste
  dem på hemdatorn (bild, läst i original).
- **WebSearch fungerade**, men ger bara sökmotorns sammanfattning. Allt nytt i §5 är
  därför **ej läst i original** (B10), och inget av det blir en gräns.
- Sökt: Sportsbox huvud, knän, armbåge, handfart, chest/hand thrust, pelvis lift into
  impact; GolfTEC SwingTRU (vridning vid toppen); japanska Golf Digest (Sportsbox-
  intervall); skaftlutning vid träff, armens vinkel mot skaftet, skaftet vid toppen;
  stansens bredd; nedsvingens tid per handicap; huvudets rörelse; Myers, Cheetham,
  Bourgain.
- Ingen sökning gav ett nytt tour-tal för ett mått som research 5 saknade, med en
  definition som går att stämma av. Det som kom fram står i §5.

## 2. Regeln för ett band

1. **Samma mått** (B45): samma definition, nollpunkt, tecken, position, klubba, och
   rörelsen i bildens plan. Annars "nej" med skälet.
2. **Nära, med känd skillnad**: tas in med förbehåll när skillnaden är mindre än
   bandets bredd och brusgolvet. Skillnaderna som återkommer:
   - **Toppen:** vår P4 är händernas högsta punkt och ≈ 9 ms tidig (M4); Sportsbox TOP
     är klubbans vändning. Sway blir ≈ 1 cm per 20 ms mer negativ hos oss (M15).
   - **Positionerna P3 och P5:** vår är armen vågrät i bild (M28). Sportsbox BAH och DAH
     tolkas som "arm horizontal"; utskrivningen är ett antagande (M28).
   - **2D mot 3D:** linjära mått (sway, lift, thrust) ligger i bildens plan; vinklar
     projiceras. Kroppslängden skalar båda (M2, Sportsbox).
   - **Bröstkorgen mot linjen:** Sportsbox Chest är bröstkorgen i 3D; vår är axelmitten
     eller linjen höftmitt → axelmitt.
3. **Spannet:** källans eget spann eller ideal där det finns (Sportsbox thrust, Blast,
   K-Vest). Där källan bara ger ett medel: **tour ± golv** (förslag, beslut 1), alltså
   medlet ± 2 cm eller ± 5°, research 5 §1.8:s golv. Ett medel säger inget om
   spridningen bland proffsen: thrustens SD är 3,6 cm, så tour ± 2 cm är ett snävt
   band. Ensidigt där källan säger att mer är proffsens håll (sway gap).
4. **Klubban:** järn som standard (beslut 2). Mellanjärn i Sportsbox, järn 5 hos Meister.
5. **3D:** ett band smalare än passets golv (MK7: bäcken 15,7°, bröst 13,7°, X-factor
   19,2°, stretch 8,1°, höfter 8,5°) säger inget och tas inte in.

## 3. Tabellen: varje rad i katalogen

D = driver, J = mellanjärn. Sportsbox = [tour-ranges-for](https://help.sportsbox.ai/tour-ranges-for)
(tour-medel för män, 100+ proffs, läst i original som bild i 5a §B) om inget annat
står. 1 tum = 2,54 cm. "TP" = tour ± golv (§2).

### 3.1 Felen

| # | id · namn | Vy · position | Föreslagen range | Källa · status | Samma mått? | Rekommendation |
|---|---|---|---|---|---|---|
| 1 | `sway_topp` · Hip sway | FO · P4 | ≥ −2,5 cm, båda klubborna (i dag) | Sportsbox P4: D −1,5, J 0,0 cm · [golf.com](https://golf.com/instruction/one-piece-swing-data-separate-low-high-handicap/) låg hcp nära 0 · tillverkare, läst i original | Nära: samma definition, nolla och tecken (M15); toppen skiljer (≈ 1 cm per 20 ms mer negativ hos oss) | Ta in med förbehåll (gäller, B45) |
| 2 | `tempo` · Swing tempo | båda · – | 2,5–3,1 (i dag) | [Blast](https://blastmotion.com/blog/what-is-golf-swing-tempo-ratio/) tour full sving; [Grober 2006](https://arxiv.org/pdf/physics/0611291) proffs 2,5–3,5 · tillverkare/forskning, läst i original | Nära: samma kvot; Blast definierar inte toppen, vår ≈ 9 ms tidig ger ≈ −0,1 | Ta in med förbehåll (gäller). Kvoten skiljer inte nivåer. |
| 3 | `early_extension` · Hips toward ball | DTL · P7 | **−2,3…+4,3 cm** (i dag ≤ +4,3, rött över +8,4) | [Sportsbox ideal](https://help.sportsbox.ai/what-is-early-extension) −0,9…+1,7 tum; tour +1,3 cm (SD 3,6) · tillverkare, läst i original | Ja: Pelvis Thrust = M7 (nolla, tecken, höftledernas mitt), rörelsen i bildens plan. Klubban anges inte; idealet gäller en man av DeChambeaus storlek. Perspektivet kan ge +1–2 cm (M7). | **Ta in** (nedre gränsen ny, beslut 5) |
| 4 | `tappad_hallning` · Spine angle loss | DTL · P7 | Ingen. Egen baslinje, sämre uppåt. | Sportsbox Chest Bend: tapp D +4°, J +1° · tillverkare, läst i original | Nej: bröstkorgen i 3D mot linjen i bild; tappet är mindre än 2D-felet (≈ 5°, Mears −6,5°) | Ingen källa → (a) |
| 5 | `backens_resa_framat` · Hip shift to target | FO · – | J **+10,2…+14,2 cm**; D +11,0…+15,0 | Sportsbox P4→P7: J +12,2, D +13,0 cm (TP) · tillverkare, läst i original | Nära: differens av Pelvis Sway (M21); vår topp tidigare ger ≈ +1 cm | Ta in med förbehåll |
| 6 | `sway_gap` · Hip–chest sway gap | FO · P7 | J **≥ +6,9 cm**; D ≥ +11,2 | Sportsbox i M19:s form: J +8,9, D +13,2 cm; [Golf Digest](https://www.golfdigest.com/story/useful-golf-swingfacts-sportsbox-ai-graph): proffs > 6,5 tum (absolut, D), amatörer "much smaller" · tillverkare, läst i original | Nära: M19 = −(gap(P7) − gap(P1)), räknat ur samma sway (M15, M16); bröstets mitt mot axelmitten | Ta in med förbehåll (ensidigt: mer är proffsens håll) |
| 7 | `axellutning` · Shoulder tilt | FO · P7 | Ingen nu. Efter S0 kanske J 22–28°. | [Meister 2011](https://people.stfx.ca/smackenz/Courses/DirectedStudy/Articles/Meister%20-%20Rotational%20Biomechanics%20of%20the%20Elite%20Golf%20Swing.pdf) S-faktor 25 ± 3° (järn 5); Sportsbox Chest Side Bend J 22°, D 32° · forskning/tillverkare, läst i original | Nej än: akromionlinjen i 3D mot projektionen i bild; vid träffen är axlarna 25–30° öppna. S0 avgör definitionen. | Avstängd → (b) |
| 8 | `reverse_spine` · Spine tilt | FO · P4 | ≥ 0° (ur definitionen) | [TPI](https://www.mytpi.com/improve-my-game/swing-characteristics/reverse-spine-angle): lutning mot målet i baksvingen · tränare, läst i original, inga tal | Nej (inga tal) | Ingen källa → (a) |
| 9 | `chicken_wing` · Lead arm fold | FO · P9 | Ingen. Egen baslinje, sämre uppåt. | [TPI](https://www.mytpi.com/improve-my-game/swing-characteristics/chicken-winging) · tränare, inga tal | Nej (inga tal) | Ingen källa → (a) |
| 10 | `flying_elbow` · Trail elbow flare | DTL · P4 | Ingen | golfrehabdoc (blogg) · antagande, ej läst | Nej | Ingen källa → (b) |
| 11 | `over_the_top` · Hands out | DTL · P5 | ≤ 0 cm (ur definitionen) | [TPI](https://www.mytpi.com/improve-my-game/swing-characteristics/over-the-top) · tränare, ingen gräns i cm | Nej: händernas bana, inte klubbans | Ingen källa → (a) |
| 12 | `bojd_framre_arm` · Lead elbow bend | FO · P4 | Ingen. Egen baslinje, sämre uppåt. | [GolfTEC](https://scramble.golftec.com/blog/2023/03/keep-your-lead-arm-straight-throughout-your-swing/): 76° mot 10° är en demonstratör · tillverkare, läst i original | Nej (ingen norm). Sportsbox Lead Elbow Flex finns, men inget tour-tal hittades. | Ingen källa → (a) |

### 3.2 Måtten bakifrån (DTL)

| # | id · namn | Position | Föreslagen range | Källa · status | Samma mått? | Rekommendation |
|---|---|---|---|---|---|---|
| 13 | `brost_bojning_adress` · Spine angle | P1 | **34–45°** (båda klubborna) | K-Vest "PGA norms" bål 34–45° ([Grathwohl 2024](https://pmc.ncbi.nlm.nih.gov/articles/PMC11642117/), normer utan källa i artikeln); Sportsbox Chest Bend J 44°, D 39°; GolfTEC ≈ 40° · tillverkare via tredje part, läst i original | Nära: samma nolla (lodlinjen) och tecken (+ framåt), absolut i båda; bröstkorgen i 3D mot linjen höftmitt → axelmitt i bild. I adressen ligger böjningen i bildens plan. Skillnaden mellan segmenten är okänd. | Ta in med förbehåll |
| 14 | `bakre_kna_adress` · Trail knee flex | P1 | Ingen | Sportsbox Trail Knee Flex finns (180° = rakt), inget tour-tal hittat | Nej (inga tal) | (b) |
| 15 | `backen_bojning_adress` · Hip hinge | P1 | Ingen | TPI bäckenets framåttippning 15–25° (annat mått) · tränare | Nej: skattningen M30 är inte bäckenets lutning | (b) |
| 16 | `framre_kna_adress` · Lead knee flex | P1 | Ingen | Sportsbox Lead Knee Flex utan tour-tal | Nej | (b) |
| 17 | `backen_bojning_topp` · Hip hinge | P4 | Ingen | – | Nej | (c) |
| 18 | `framre_kna_topp` · Lead knee flex | P4 | Ingen | – | Nej | (b) |
| 19 | `brost_lyft_topp` · Chest height | P4 | **−4,0…0,0 cm** (båda klubborna) | Sportsbox Chest Lift P4 −0,8 tum = −2,0 cm (D och J), TP · tillverkare, läst i original | Nära: samma nolla och tecken (M31), höjdled i bildens plan; axelmitten mot bröstkorgens mitt | Ta in med förbehåll |
| 20 | `hand_lyft_topp` · Hand height | P4 | Ingen | Sportsbox Mid-Hand Lift utan tour-tal | Nej (inga tal) | (b) |
| 21 | `hand_djup_topp` · Hand depth | P4 | Ingen | Sportsbox Hand Thrust: bara enskilda spelare (−41…−46 cm, driver, damer; golfdigest-minna, ej läst i original) | Nej (inget medel) | (b) |
| 22 | `framre_arm_plan_topp` · Lead arm to shoulder plane | P4 | Ingen | – | Nej | (b) |
| 23 | `backen_bojning_traff` · Hip hinge | P7 | Ingen | – | Nej | (c) |
| 24 | `framre_kna_traff` · Lead knee flex | P7 | Ingen | Motstridigt (research 5d D) | Nej | (b) |
| 25 | `brost_lyft_traff` · Chest height | P7 | J **−3,5…+0,5 cm**; D −4,8…−0,8 | Sportsbox P7: J −1,5, D −2,8 cm, TP · tillverkare, läst i original | Nära, som rad 19 | Ta in med förbehåll |
| 26 | `hand_lyft_traff` · Hand height | P7 | Ingen | – | Nej | (b) |
| 27 | `genomsving_s` · Follow-through time | P10 | Ingen | Sportsbox Follow Through Time utan tour-tal | Nej | (c) |
| 28 | `huvud_mot_bollen_topp` · Head toward ball | P4 | Ingen. Egen baslinje på beloppet. | [Byrne & Kenny 2008](https://researchrepository.ul.ie/articles/conference_contribution/Kinematic_differences_between_high_and_low_handicap_golfers/19823230): framåt–bakåt 2,0 cm (hcp 4,5) mot 11,8 cm (hcp 17,8), 8 golfare, driver · forskning, ej läst i original | Nej: markör i 3D, fas och tecken oklara | Ingen källa → (a) |
| 29 | `huvud_lyft_topp` · Head height | P4 | Ingen | Sportsbox Head Lift utan tour-tal | Nej | (b) |
| 30 | `huvud_mot_bollen_traff` · Head toward ball | P7 | Ingen. Egen baslinje på beloppet. | Som rad 28 | Nej | (a) |
| 31 | `huvud_lyft_traff` · Head height | P7 | Ingen | – | Nej | (b) |
| 32 | `backen_lyft_min` · Hip low point | P5 | J **−5,6…−1,6 cm**; D −6,3…−2,3 | Sportsbox Pelvis Lift, lägsta från P4: J −3,6, D −4,3 cm, TP · tillverkare, läst i original | Nära: samma nolla och tecken (M8, M43); vårt fönster topp → träff, tabellen har P4–P7 | Ta in med förbehåll |
| 33 | `backen_lyft_in_traff` · Hip rise into impact | P7 | J **+3,8…+7,8 cm**; D +4,6…+8,6 | Sportsbox: P7 − lägsta = J +5,8, D +6,6 cm, TP; [Pelvis Lift at IMP](https://help.sportsbox.ai/what-is-pelvis-lift) samma definition · tillverkare, läst i original | Nära: samma definition som indikatorn; tour-talet är räknat ur medelkurvan, inte ur slagen | Ta in med förbehåll |
| 34 | `nedsving_s` · Downswing time | P7 | **0,23–0,32 s** (båda klubborna) | [Blast](https://blastmotion.com/blog/what-is-golf-swing-tempo-ratio/) tour full sving; Sportsbox 0,26 s (D); AMM ≈ 0,25 s · tillverkare, läst i original | Nära: topp → träff; vår topp ≈ 9 ms tidig (+0,009 s), Blasts topp odefinierad | Ta in med förbehåll (beslut 8) |
| 35 | `skaft_vinkel` · Shaft angle | P1–P10 | Ingen | – | Nej | (b) |
| 36 | `skaftplan_p1` · Shaft plane | P1 | Ingen | Lie-vinkeln är klubbans (standard), inte svingens | Nej | (b) |
| 37 | `skaft_riktning_topp` · Shaft across the line | P4 | Mål 0; bandets bredd antagande (t.ex. ±10° i bild ≈ ±3° i rummet, M48:s faktor 2,8–3,7) | P-systemet (tränare, ej läst i original) | Nej (inga tal) | (a) |
| 38 | `skaft_plan_p6` · Clubhead to plane | P6 | Mål 0; bandets bredd antagande | P-systemet (tränare); Morrison 2018 mäter ett annat plan | Nej | (a) |

### 3.3 Måtten framifrån (FO)

| # | id · namn | Position | Föreslagen range | Källa · status | Samma mått? | Rekommendation |
|---|---|---|---|---|---|---|
| 39 | `stans_bredd` · Stance width | P1 | Ingen | Driver bredare än järn (2014, [lida](https://lida.sport-iat.de/ta/Record/4033197), ej läst i original); ingen kvot mot axlarna hittad | Nej | (b) |
| 40 | `axellinje_lutning_adress` · Shoulder tilt | P1 | J **+6…+16°**; D +10…+20 | Sportsbox Chest Side Bend P1: J 11°, D 15°, TP · tillverkare, läst i original | Nära: samma nolla (vågrätt) och tecken (+ bakre lägre), absolut; i adressen är axlarna nästan parallella med bildens plan. Bröstkorgen mot axelpunkterna. | Ta in med förbehåll |
| 41 | `hoftlinje_lutning_adress` · Hip tilt | P1 | **−4…+6°** (båda klubborna) | Sportsbox Pelvis Side Bend P1 1°, TP · tillverkare, läst i original | Nära: samma nolla och tecken (M18); höftlederna mot bäckenet | Ta in med förbehåll |
| 42 | `backen_sway_p3` · Hip sway | P3 | J **−4,0…0,0 cm**; D −6,1…−2,1 | Sportsbox P3 (BAH): J −0,8 tum = −2,0 cm, D −4,1 cm, TP | Nära: samma mått som M15; P3 är armen vågrät i bild mot BAH (antagande, M28) | Ta in med förbehåll |
| 43 | `framre_armbage_p3` · Lead elbow bend | P3 | Ingen | – | Nej | (b) |
| 44 | `backen_resa_p5` · Hip shift to target | P5 | J **+3,8…+7,8 cm**; D +4,4…+8,4 | Sportsbox P4→P5 (DAH): J +5,8, D +6,4 cm, TP | Nära: som rad 42 och toppen (§2) | Ta in med förbehåll |
| 45 | `hander_fore_adress_traff` · Hands toward target | P7 | Ingen | Sportsbox Hand Sway utan tour-tal | Nej | (b) |
| 46 | `huvud_backen_finish` · Head over hips | P10 | Ingen | – | Nej | (c) |
| 47 | `framre_kna_sway_topp` · Lead knee sway | P4 | Ingen | Sportsbox Knee Sway utan tour-tal | Nej | (c) |
| 48 | `bakre_kna_sway_topp` · Trail knee sway | P4 | Ingen | Som rad 47 | Nej | (b), stöd för `sway_topp` |
| 49 | `brost_lyft_topp` · Chest height | P4 | **−4,0…0,0 cm** | Som rad 19 | Nära, som rad 19 | Ta in med förbehåll |
| 50 | `hand_lyft_topp` · Hand height | P4 | Ingen | – | Nej | (b) |
| 51 | `framre_arm_vinkelfart_max` · Lead arm speed | P5 | Ingen | Sportsbox överarm 1 005 °/s (3D, D) | Nej: vinkeln i bild mot rummets vridfart | (b) |
| 52 | `framre_kna_sway_traff` · Lead knee sway | P7 | Ingen | – | Nej | (c) |
| 53 | `bakre_kna_sway_traff` · Trail knee sway | P7 | Ingen | – | Nej | (c) |
| 54 | `brost_lyft_traff` · Chest height | P7 | J **−3,5…+0,5 cm**; D −4,8…−0,8 | Som rad 25 | Nära | Ta in med förbehåll |
| 55 | `hand_lyft_traff` · Hand height | P7 | Ingen | – | Nej | (b) |
| 56 | `handfart_max` · Hand speed | P7 | Ingen. Egen baslinje, sämre nedåt. | [deWiz](https://dewizgolf.com/pages/what-is-good-hand-speed-in-golf) tour ≈ 21 mph, skickliga 15–17 mph (driver, ej läst i original) | Nej: sensor i 3D mot en undre gräns i bildens plan | Ingen källa → (a) |
| 57 | `handfart_max_fore_traff_ms` · Hand speed peak timing | P7 | Ingen | Sportsbox 69 ms före träff (D) | Nej: medel i 3D, riktningen för bra okänd | (b) |
| 58 | `genomsving_s` · Follow-through time | P10 | Ingen | – | Nej | (c) |
| 59 | `huvud_lyft_topp` · Head height | P4 | Ingen | – | Nej | (b) |
| 60 | `huvud_lyft_traff` · Head height | P7 | Ingen | – | Nej | (b) |
| 61 | `backen_recentrering` · Hip recentering | P4 | Ingen | [Sportsbox](https://help.sportsbox.ai/rory-mcilroys-incredible-power-pelvis-slide): under 1 tum = för lite eller för sent; tour J 2,0, D 2,5 cm · tillverkare, läst i original | Nära: samma storlek, tecknet vänt, vårt fönster hela baksvingen. Men gränsen 2,5 cm fäller tour med järn, och utan sway bakåt finns inget att recentrera. | (b) |
| 62 | `backen_skifte_ms` · Hip shift timing | P5 | Ingen | Okuda 2010, Smith/Mears 2017, Jones 2023: tidpunkten, inga ms | Nej: tryckcentrum och tyngdpunkt mot höftmitten | (b) |
| 63 | `backen_lyft_min` · Hip low point | P5 | J **−5,6…−1,6 cm** | Som rad 32 | Nära | Ta in med förbehåll |
| 64 | `backen_lyft_in_traff` · Hip rise into impact | P7 | J **+3,8…+7,8 cm** | Som rad 33 | Nära | Ta in med förbehåll |
| 65 | `sidbojning_finish` · Spine tilt | P10 | Ingen | GolfTEC Shoulder Bend i finish: tour 32°, hcp 5–0 20,6°, 31+ 3,2° ([golftec.co.za](https://www.golftec.co.za/swingtru), bild); Sportsbox Chest Bend FIN −33 D / −35 J · tillverkare, läst i original | **Nej**: i finishen är tour-bröstet vridet 154–161°, så bakåtlutningen ligger mest i djupled (§4.1) | (b) |
| 66 | `nedsving_s` · Downswing time | P7 | **0,23–0,32 s** | Som rad 34 | Nära | Ta in med förbehåll |
| 67 | `hoftlinje_lutning_topp` · Hip tilt | P4 | **−13…−3°** (båda klubborna) | Sportsbox Pelvis Side Bend P4 −8°, TP | Nära: bäckenet vridet ≈ 36–40°, så linjen i bild blir 2–2,5° brantare (§4.2) | Ta in med förbehåll |
| 68 | `hoftlinje_lutning_traff` · Hip tilt | P7 | J **+2…+12°**; D +3…+13 | Sportsbox P7: J +7°, D +8°, TP | Nära: vid träffen ≈ +1,5° (§4.2) | Ta in med förbehåll |
| 69 | `skaft_vinkel` · Shaft angle | P1–P10 | Ingen | – | Nej | (b) |
| 70 | `skaft_topp` · Shaft to level | P4 | ≥ 0° med järn (inte förbi parallellt) | Tränare (kortare klubbor når inte parallellt; sökmotor, ej läst i original) | Nej (inga tal) | (a) |
| 71 | `skaft_arm_p5` · Lead arm to shaft | P5 | Ingen | ≈ 90° som tumregel (tränare, sökmotor); Rotary Swing säger att proffs öppnar vinkeln tidigt | Nej, och oenigt | (b) |
| 72 | `skaft_arm_p6` · Lead arm to shaft | P6 | Ingen. Egen baslinje, sämre uppåt. | TPI casting; Chu 2010, Joyce 2016 (bara abstract) | Nej (inga tal) | (a) |
| 73 | `skaft_lutning_traff` · Shaft lean | P7 | ≥ 0° med järn (greppet före) | TPI scooping; AMG "tour average 7,98°" (podcast, klubba och vy anges inte, ej läst i original) | Nej: inget tal med samma definition | (a) |

### 3.4 Spridningen och 3D

| # | id · namn | Vy · position | Föreslagen range | Källa · status | Samma mått? | Rekommendation |
|---|---|---|---|---|---|---|
| 74 | spridning `brost_bojning_adress` · Spine angle spread | DTL · P1 | Ingen. Egen baslinje, sämre uppåt. | [Yamamoto 2023](https://pmc.ncbi.nlm.nih.gov/articles/PMC10684732/): sd mot score r = 0,80, ingen norm · forskning, läst i original (5d) | Nej: sd och öra–höft mot robust sd och höftmitt–axelmitt | (a) |
| 75 | spridning `brost_bojning_traff` · Spine angle spread | DTL · P7 | Som rad 74 | Som rad 74 | Nej | (a) |
| 76 | `backen_vrid_topp` · Pelvis turn at the top | 3D · P4 | **30–46°** (riktmärke) | K-Vest topp −46…−30° (absolut; Grathwohl 2024); Sportsbox J −36 (absolut) = 38° från adressen, D 44°; Meister max 46 ± 6° (järn 5); GolfTEC 2015-bloggen tour 44° ([scramble](https://scramble.golftec.com/blog/2015/03/straight-knee-golf-swing/), ej läst i original) | Nära: höftlinjen på markplanet, + bort från målet; vi nollar vid adressen, källorna mot fotlinjen (adressen 2–4° hos Sportsbox, −2…6° hos K-Vest). Bandet är 16° brett mot golvet 15,7°. | Ta in med förbehåll (3D-trend, B14) |
| 77 | `brost_vrid_topp` · Shoulder turn at the top | 3D · P4 | Ingen | Sportsbox −93° J (bröstkorgen); K-Vest −86…−74°; Meister max 99 ± 6° (akromion) | Nej: akromionlinjen går 8–9° längre än bröstkorgen (S6_FELBUDGET §5); Meisters spann är smalare än golvet 13,7° | (b) |
| 78 | `xfaktor_topp` · X-factor at the top | 3D · P4 | Ingen | Myers: 44/50/59° (bollfart låg → hög, nollat vid adressen); Sportsbox −57° J (härlett); Bourgain 55–60° (akromion) | Nej: definitionen flyttar 19°, golvet 19,2° | (b) |
| 79 | `xfaktor_stretch` · X-factor stretch | 3D · nedsving | Ingen | TPI tour ≈ 5°; [Cheetham 2001](https://www.mytpi.com/articles/biomechanics/the-difference-between-x-factor-and-x-factor-stretch) 19 % mot 13 % | Nej: procent mot grader; talet är mindre än golvet 8,1° | (b) |
| 80 | `hofter_oppna_traff` · Hips open at impact | 3D · P7 | **30–45°** (riktmärke; i dag 35–45) | [Myers 2008](https://chs.uky.edu/sites/default/files/2023-12/Myers_2008_Role%20of%20upper%20torso%20and%20pelvis%20during%20golf%20swing.pdf) 29/35/38° (nollat vid adressen, driver); Sportsbox J 34 − 2 = 32°, D 34° från adressen; PGA 26,3–43,7° absolut (D, [golfdigest-minna](https://www.golfdigest-minna.jp/_ct/17677047)); GolfTEC tour 36°, hcp 5–0 28,5°; K-Vest 35–50° · forskning/tillverkare, läst i original | Nära: Myers nollar vid adressen som vi (ASIS-linjen mot höftlederna); de andra är absoluta och ligger 2–4° högre. Okuda fann ingen skillnad mellan nivåerna. | Ta in med förbehåll (3D-trend, B14) |

## 4. Två fynd som ändrar en METOD-rad (förslag, inte gjort)

### 4.1 Bröstet vetter inte mot målet i finishen

M14 antar att bröstet vetter mot målet i finishen, så att bakåtlutningen ligger i FO:s
bildplan. Sportsbox tour-tabell ger bröstets turn i finishen **161° (D) och 154° (J)**,
där 0° är parallellt med fotlinjen och 90° är bröstet mot målet. Bröstet är alltså
vridet 64–71° förbi målet. En bakåtlutning i bröstets eget plan syns framifrån med
faktorn cos(64–71°) ≈ 0,33–0,44 (räkning): Sportsbox −35° (J) blir ≈ 13–17° i bild.
GolfTEC:s trappa (3,2° till 32°) går därför inte att föra över, och sidböjningen i
finishen blandas in. Förslag: rätta M14:s mening när katalogen ändras, och flytta måttet
till (b).

### 4.2 Höftlinjen i bild förstoras av vridningen

En linje som lutar τ i sitt eget plan och är vriden θ från mållinjen syns framifrån med
lutningen atan(tan τ / cos θ) (räkning). Med Sportsbox tal: vid toppen τ = 8°, θ ≈ 36–40°
ger 9,9–10,4° (2–2,5° mer); vid träffen τ = 7–8°, θ ≈ 34–38° ger 8,4–10,1° (≈ 1,5–2°
mer). Skillnaden är mindre än golvet 5°, så banden i §3 behålls. Talen i bild ligger i
bandets yttre halva.

## 5. Det nya ur sökningen (ej läst i original)

Inget av detta blir en gräns (B10). Det står här så att nästa runda vet vad som ska
läsas på hemdatorn.

| Påstående | Källa | Status | Används |
|---|---|---|---|
| GolfTEC tour: höfterna 44° och axlarna 89° vid toppen | [scramble 2015](https://scramble.golftec.com/blog/2015/03/straight-knee-golf-swing/) | ej läst i original | Nämnt vid rad 76 |
| PGA (D): sway P3 bröst −0,6, bäcken −0,5; P4 bröst −0,2, bäcken +0,3 (enhet oklar) | golfdigest-minna.jp, sökträff (_ct/17545706, 17762141 eller 17751880; vilken sida framgår inte) | ej läst i original | Nej: stämmer inte med tour-tabellen (P3 −1,6, P4 −0,6 tum) |
| LPGA: bäckenets sway vid träff +5,6…+11,7 cm | golfdigest-minna.jp, sökträff | ej läst i original | Nej: damer, D |
| Huvudets rörelse: sidled vid toppen 5,5 mot 12,4 cm; framåt–bakåt 2,0 mot 11,8 cm (hcp 4,5 mot 17,8, 8 golfare, driver) | [Byrne & Kenny 2008](https://researchrepository.ul.ie/articles/conference_contribution/Kinematic_differences_between_high_and_low_handicap_golfers/19823230) | ej läst i original | Riktningen "mindre" för rad 28 och 30 |
| Skaftlutning vid träff, tour 7,98° | [AMG-podcast](https://www.audible.co.uk/podcast/The-Most-Misunderstood-Move-in-Golf-Even-Instruction-Gets-It-Wrong/B0H41JM5LG) | ej läst i original; klubba och vy saknas | Nej |
| Handfart tour ≈ 21 mph, skickliga 15–17 mph (driver) | [deWiz](https://dewizgolf.com/pages/what-is-good-hand-speed-in-golf) | ej läst i original | Nej |
| Cheetham 2001: stretch 19 % mot 13 %; en översikt (Cole 2009) citerar samma studie som 57° mot 50° | [TPI](https://www.mytpi.com/articles/biomechanics/the-difference-between-x-factor-and-x-factor-stretch), [Cole 2009](https://acuresearchbank.acu.edu.au/download/ae6894a7993c13c80893a62be2568b2009d54d21d8f9710ac02ba831c6079456/1086494/Cole_2009_The_X_Factor_and_its_relationship_to.pdf) | ej läst i original; procenten bekräftade av 5c | Nej: källorna är oeniga om enheten |
| Minjee Lee: bäckenet −2 tum vid toppen, +3,3 tum in i träffen | [podcast](https://www.audible.com/pd/B0FG17QNGP) | ej läst i original; en spelare | Nej |
| Stansen bredare med driver än med järn | [lida 4033197](https://lida.sport-iat.de/ta/Record/4033197) | ej läst i original | Stöd för (b) på rad 39 |

## 6. Klubban

Johannes bestämde 2026-10-23 att egen baslinje per klubba räcker och att katalogen inte
får gränser per klubba (B45). Banden i §3 skiljer driver och järn där källan gör det.
Förslaget är att katalogen tar **järnets band** som standard för vinterns 7-järn och att
driverns band väntar tills klubban förs in i katalogen.

Klubban flyttar sju band: `backens_resa_framat`, `sway_gap`, `brost_lyft_traff`,
`backen_lyft_min`, `backen_lyft_in_traff`, `axellinje_lutning_adress` och
`backen_sway_p3`. Driverns tour-medel ligger innanför järnets band utom för
`backen_sway_p3` (−4,1 cm mot −4,0…0,0), men åt andra hållet faller järnets
`sway_gap` (+8,9 cm) under driverns band (≥ +11,2). Ett band för fel klubba säger
alltså fel sak, och appen bör visa järnets band bara på järnpass tills klubban styr
bandet. **Fråga till Johannes: ska det vara så?**

## 7. Fortfarande inte läst i original

Utöver research 5 §7: allt i §5 ovan, Sportsbox Lead Elbow Flex och knäflexion (inga
tour-tal hittade), och Sportsbox-kursen "Driver vs Mid Iron" (inloggning). Nästa runda
bör köras på hemdatorn, där sportsbox.ai och golftec gick att läsa i research 5.
