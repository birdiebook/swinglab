# 8. UX-granskning med nya ögon (2026-10-25)

En agent utan tillgång till koden, planerna eller besluten granskade appen som förstagångsanvändare: bara [VISION.md](../../VISION.md) och simulatorprovets 109 bilder från main `1ac6b1a` (påhittad data). Johannes väljer vilka ändringar som byggs; rapporten nedan är granskarens, oförändrad.


## Sammanfattning

SwingLab ser lugn och genomarbetad ut. Den mörka, sparsmakade stilen, de stora siffrorna och formkoden (grön prick, gul ring, röd triangel) bär långt, och Focus-bladet och guiden för att markera klubban håller hög klass. Problemet är att appen visar nästan allt på en gång och i mätinstrumentets språk. Passet är en lång lista med 10–14 lika stora kort i en ordning som inte följer hur allvarligt måttet är. Det som är dåligt ligger utspritt, och det man ska öva på ligger längst ner som grå textlänkar. Runt måtten finns felsökningsdata, interna koder och tecken som en hcp 15-spelare inte kan läsa (`B10`, `Sampson error`, `confidence 0.90 median`, `+ TO TARGET`, `P6`). Flera mått saknar bra eller dåligt, vilket strider mot visionens egen regel. Det mesta går att rätta utan att offra djup: sortera, översätt och lägg resten ett tryck bort.

---

## De 10 ändringar som gör mest skillnad

Rankade efter effekt mot arbete.

### 1. Ta bort felsökningsdata och interna koder från användarens vyer
- **Problem:** Användaren möter rå mätteknik och utvecklarkoder:
  - `1.0 ms/frame` och `2.0 per frame · confidence 0.90 median, 0.90 max · person 100%`;
  - kvittot `fps / Dropped / Frames / Clicks / MB/min`;
  - etiketten `B10` med streckad ring;
  - `Sampson error 14.8 px, limit 8 px`;
  - felmeddelandet `saker[0].ovning.tanke: no digits`, med svenska nyckelnamn i ett engelskt gränssnitt.
- **Bilder:** `slag.png`, `import-analys.png`, `redigering-slag.png`, `passet-detection-wrong.png`, `kvitto.png`, `import.png`, `band-granskning-p4.png`, `band-granskning-p6-klubba.png`, `klubba-passet.png`, `klubba-fo-granskning.png`, `tred-figur-kameror.png`, `tred-figur-over-sparren.png`, `claude-fel.png`.
- **Förslag:**
  - Kvittot blir en mening med dom, till exempel "Bra inspelning · 2 slag hörda" eller "⚠ Telefonen tappade var tredje bild – stäng andra appar". Siffrorna ligger kvar bakom "Detaljer".
  - Konfidensraden tas bort helt från Shots.
  - `B10` blir "Preliminärt" eller en ikon med förklaring vid tryck.
  - `Sampson error` blir "Kamerorna stämmer inte överens (för stort fel)".
  - Claude-felet blir "Svaret från Claude gick inte att läsa: swing thought saknas. Be Claude försöka igen."
- **Effekt:** stor · **Arbete:** litet

### 2. Börja passet med en sammanfattning och sortera korten efter status
- **Problem:** Passet har ingen topp. Röda mått ligger långt ner: Hands out är kort 8 i `passet.png`, och i `claude-passet.png` ligger Hip shift rött som kort 3. Gröna kort och kort utan dom tar lika mycket plats. Ask Claude och Focus ligger under alla mått, som grå textlänkar.
- **Bilder:** `passet.png`, `band-passet-dtl.png`, `claude-passet.png`, `session-dtl.png`.
- **Förslag:**
  - Överst kommer ett kort med "Att jobba på" (aktiv Focus, eller knappen "Fråga Claude" om ingen Focus finns) och en rad med "2 röda · 1 gul · 6 bra".
  - Därefter visas korten i ordningen röd, gul, grön.
  - Gröna kort kan fällas ihop till en rad (namn + värde + prick) som fälls ut vid tryck.
  - Mått utan dom hamnar under "Fler mått" (se punkt 3).
- **Effekt:** stor · **Arbete:** litet–medel

### 3. Visa inte mått som saknar bra eller dåligt, enligt visionens regel
- **Problem:**
  - "Your usual"-korten (Lead arm fold, Lead elbow bend, Spine angle spread, Trail elbow flare) har vit prick och ingen dom.
  - 3D-listan (Pelvis turn, X-factor, Hips open) är rena tal.
  - Hand speed är märkt "untested".
  - Kort med bara `—` visas i `klubba-passet.png`.
  - Axeln på "Your usual" zoomar till ±0,3, till exempel 19.7–20.3 i `band-passet-fo.png`. Då ser 0,1° ut som ett stort utslag.
  - Samma "Your usual"-märke står ibland med röd triangel (Spine angle loss i `band-passet-dtl.png`), ibland utan ruta alls (`band-passet-driver.png`).
- **Bilder:** `passet.png`, `band-passet-fo.png`, `band-passet-driver.png`, `tred-kort.png`, `parad-3d.png`, `granskning-video-p7.png`, `klubba-passet.png`.
- **Förslag:**
  - Mått utan dom flyttas under en hopfälld "Fler mått (underlag)" eller visas bara i Shot-vyn.
  - Har "Your usual" en dom ("utanför ditt vanliga") får den gul ring och texten "ovanligt för dig". Annars visas inget band.
  - Axeln får en lägsta skala så att brus inte ser ut som en avvikelse.
  - Kort med `—` döljs.
- **Effekt:** stor · **Arbete:** litet

### 4. Förklara bandet en gång
- **Problem:** Bandet har fem element: grå stapel, vit linje, tunt streck, ihålig ruta och markör. Det har fyra siffror utan enhet (till exempel `−4  −2.3  4.3  6`). Ingenstans står vad delarna betyder. En ny användare kan inte veta att grått betyder bra område, vitt är spridningen i dina slag och strecket är förra passet.
- **Bilder:** `band-passet-dtl.png`, `band-passet-fo.png`, `passet.png`.
- **Förslag:**
  - Vid tryck på bandet, och en gång vid första passet, visas ett blad med en ritad nyckel: "Grått = bra område · Vit linje = dina slag idag · Streck = förra passet · Ruta = ditt vanliga".
  - Axeln visar bara de två gränserna för bra-området, med enhet ("bra: −2,3 till 4,3 cm").
  - Kortets yttersta axeltal tas bort.
- **Effekt:** medel–stor · **Arbete:** litet

### 5. Säg riktningen i ord, och använd en enda triangelform
- **Problem:**
  - Riktningen kodas med förtecken och en liten rubrik: `−3.0 cm` och `FO · TOP · + TO TARGET`. Spelaren måste räkna ut att minus betyder bort från målet.
  - Den röda triangeln vrids: ▼ eller ▲ vid siffran, ◄ eller ► på bandet. ▼ läses som "minskat sedan sist" (börskonvention) och krockar med raden `±0.0 cm vs Nov 10` direkt under.
  - I `granskning-video-p7.png` står "Hip rise into impact **+1.0** cm ▼". Ett positivt tal med nedåtpil ser motsägelsefullt ut.
- **Bilder:** `claude-passet.png`, `passet-matt.png`, `granskning-video.png`, `granskning-video-p7.png`.
- **Förslag:**
  - Skriv "3,0 cm bort från målet" eller "6,0 cm för lite mot målet" under siffran. Djupet (förtecken, fas, vy) får ligga i detaljvyn.
  - Triangeln vid siffran blir alltid en stående röd triangel (varning). Riktningen visas bara på bandet.
  - Raden "vs Jan 6" får ordet "bättre" eller "sämre" i stället för förtecken.
- **Effekt:** stor · **Arbete:** medel

### 6. Gör Claude och Focus till ett riktigt flöde som syns
- **Problem:**
  - "Ask Claude", "Paste from Claude", "Copied" och "Open Claude" är grå textlänkar under alla mått. Det är fyra steg via urklipp, och ingen bild visar vad som händer i Claude.
  - En sparad Focus syns varken i listan Sessions eller överst i passet.
  - Focus-färgen (blå rubrik och blå prick) ersätter statusfärgen. Hip sway är röd triangel i passet men blå prick i `claude-blad.png`, och "dåligt" försvinner.
  - Focus-bladet säger inte varför måttet är viktigt. "First set ≥ −2.5 cm" är matematik.
- **Bilder:** `claude-passet.png`, `claude-blad.png`, `claude-blad-aldre.png`, `claude-blad-ersatt.png`, `me.png`.
- **Förslag:**
  - En vit huvudknapp "Fråga Claude vad jag ska öva" överst i passet. Efter kopieringen kommer ett blad med "1 Öppna Claude → 2 Klistra in svaret här".
  - Den aktiva Focus visas som ett kort överst på Sessions och i passet.
  - Behåll statussymbolen och lägg en blå etikett "Focus" bredvid.
  - Focus-bladet får en mening med "varför" och "Klart när: höfterna rör sig högst 2,5 cm bort från målet i första serien, två pass i rad".
- **Effekt:** stor · **Arbete:** medel

### 7. Inspelningen: visa vy och roll, och ge varningar en åtgärd
- **Problem:**
  - Kameraskärmen säger inte om telefonen filmar DTL eller FO, var man ska ställa sig eller vad de streckade linjerna betyder.
  - "No sessions" har ingen vägledning.
  - Det finns ingen bild av hur man parar telefonerna eller väljer roll.
  - "Searching", "Other phone lost" och "Other phone stopped recording" saknar åtgärd.
  - Inställningarna visar `Swings heard on both 6 of 6 · 1.2 ms · uncertain` och `Other phone's view 0.12 s · 12 fps`.
  - **Lead/Follow** krockar med golfens lead/trail (Lead arm fold, Lead elbow bend).
  - Vid 50° lutning ritas linjen vågrätt (`insp-ensam-lutning-for-stor.png`), så bilden säger emot siffran.
- **Bilder:** `startvy.png`, `insp-ensam-redo.png`, `insp-lead-soker.png`, `insp-lead-tappad.png`, `insp-lead-spelar-in.png`, `insp-installningar-lead.png`, `insp-installningar-andra-bild.png`, `insp-ensam-lutning-for-stor.png`.
- **Förslag:**
  - En etikett överst: "Face on · bakom bollen, 3 m" med en liten bild av placeringen. Linjerna får texten "huvud här" och "fötter här" första gången.
  - Tomt läge: "Tryck + för att filma ditt första pass" med en ritning av de två placeringarna.
  - "Searching" får texten "Öppna SwingLab på den andra telefonen och tryck +". "Other phone lost" får knappen "Anslut igen".
  - Lead/Follow byts mot "Styr" och "Följer" (eller "Huvudtelefon" och "Andra telefonen").
  - Synkraden blir "Båda hörde 6 av 6 slag ✓".
- **Effekt:** stor · **Arbete:** medel

### 8. P1–P10: namn först, rätt ordning och tydlig "klar"-markering
- **Problem:**
  - P1–P10 är facktermer, och bara fyra har namn. P2, P6 och P8 är nästan osynliga när de är avstängda.
  - I "Mark club" går ordningen P1, P3, P4, P5, P7, P9, P10, P2, P6, P8.
  - Klara positioner stryks över. Det läses som "borttagen".
  - Rubriken säger "Tap the grip" även när modellens förslag (1?, 2?) redan visas.
  - Det finns fyra sätt att gå vidare: Done, Next, ✓ och Skip.
  - Guiden säger "Or tap 1? to use the app's guess", vilket är kryptiskt.
- **Bilder:** `granskning-video.png`, `klubba-greppet.png`, `klubba-forslag.png`, `klubba-forslag-rattat.png`, `klubba-fo-markera.png`, `klubba-guide-1.png`, `klubba-guide-3.png`.
- **Förslag:**
  - Visa namnet (Address, Takeaway, Top, Impact …) och P-numret litet under.
  - Markera i ordningen P1→P10.
  - Klar visas med bock och inte överstrykning.
  - Vid förslag blir rubriken "Stämmer linjen? Tryck ✓ eller dra punkterna".
  - En knapp för att gå vidare: ✓ eller Nästa. Done finns bara uppe till höger.
- **Effekt:** medel · **Arbete:** litet–medel

### 9. Konsekvens och Apple HIG i de vanliga kontrollerna
- **Problem:**
  - Segmentväljaren heter All/FO/DTL i ett pass och DTL/FO/3D i ett annat.
  - 3D nås via en liten rad "3D >" längst ner.
  - "Session" uppe till höger dubblerar bakåtpilen.
  - Delete är grå och inte röd. Aktiv och spärrad Delete ser likadana ut, och "The session is in use" säger inte varför eller vad man gör.
  - Vippknapparna är inverterade (vit med svart knapp).
  - Antalet slag motsäger sig: "4 swings" mot "10 swings" (`parad-3d.png`), och 8 slag mot "3D … 10 swings" (`session-dtl.png`).
  - Längden står som "Height 190 cm" på Me men "1.80 m assumed" i passet.
  - Det finns ingen bild av hur man startar en radering (svep?) eller öppnar Mark club ("…"?).
- **Bilder:** `passet.png`, `parad-dtl.png`, `parad-3d.png`, `granskning-dtl.png`, `sessions-radera.png`, `sessions-radera-vagrad.png`, `insp-installningar-ensam.png`, `me.png`.
- **Förslag:**
  - En väljare för alla pass: Alla · FO · DTL · 3D.
  - 3D blir ett eget kort med en liten figur.
  - "Session" tas bort.
  - Delete i systemets röda destruktiva stil. Spärrad Delete visas tydligt spärrad med orsak ("Passet används av Focus" eller "laddas från andra telefonen").
  - Vippknapparna får iOS-standarden.
  - Antalet slag räknas på ett sätt.
  - Längden hämtas från Me i passet.
- **Effekt:** medel · **Arbete:** litet

### 10. Dynamisk text och kontrast
- **Problem:** Med stor text växer siffrorna, men flera delar växer inte:
  - axeltal, statusprickar och tempostapelns `0.85 / 0.30 s` (`passet-dtl-stor.png`, `tred-kort-stor.png`).
  - Gradtecknet bryts till egen rad i 3D-kortet.
  - Faslistan Address/Top/Impact/Finish bryts i två rader (`granskning-fo-stor.png`).

  Tidskoden på videon (`−0.299 s`) är ljusgrå på grått. Avstängda P-flikar och små versalrubriker är mörkgrå på svart.
- **Bilder:** `passet-dtl-stor.png`, `tred-kort-stor.png`, `granskning-fo-stor.png`, `insp-installningar-lead-stor.png`, `granskning-video.png`.
- **Förslag:**
  - Skala axel, prick och triangel med textstorleken.
  - Byt till en layout i en kolumn vid AX-storlekar.
  - Tidskoden får mörk bakgrund.
  - Sekundär text ska ha minst 4.5:1 i kontrast.
- **Effekt:** medel · **Arbete:** medel

---

## Uppgifterna steg för steg: här fastnar en ny användare

| Uppgift | Fastnar på | Bild saknas |
|---|---|---|
| Spela in med en telefon | Vet inte vilken vy telefonen är ställd på, eller var man ska stå. Kvittot efteråt är tekniskt. | Ljustestet, val av vy |
| Spela in med två telefoner | Hur parar man, vem väljer Lead? "Searching" utan instruktion. Synkraden går inte att läsa. | Parning och rollval |
| Förstå dåligt mått | Måste skrolla igenom 10+ kort. Förtecknen och ▼ vilseleder, och bandet saknar nyckel. | — |
| Hitta vad jag ska öva | Claude ligger längst ner som grå länk, och urklippsdansen är oförklarad. Focus syns inte efteråt. | Claude-sidan, var Focus visas sedan |
| Markera klubban | Guiden är bra. Förslagsläget säger fel sak, ordningen hoppar och överstrykning ser ut som borttaget. | Ingången (menyn "…") |
| Titta på 3D | Ingången är liten. Figuren saknar mått, och felen säger orsak men inte åtgärd ("Camera angle outside 60–120°" → "Ställ telefonerna i rät vinkel, nu 130°"). | — |
| Radera pass | Delete ser inte destruktiv ut. "In use" förklaras inte. | Hur man startar raderingen |

Ikonerna 👁 (dölj leder) och "…" i Shot-vyn förklaras inte heller.

---

## Jargong, ord och siffror som bör bytas

| Nu | Förslag |
|---|---|
| DTL / FO / Down the line / Face on | "Bakifrån" / "Framifrån" med en liten ikon av placeringen; DTL och FO bara som förkortning i detaljvyn |
| Lead / Follow (telefonroller) | "Styr" / "Följer", eftersom de krockar med lead arm |
| P1–P10, P6 i rubrik | Namn först: Address, Takeaway, Lead arm parallel, Top … Finish; P-nr litet |
| `+ TO TARGET`, `+ TO BALL`, `+ AWAY FROM TARGET` | Bort från rubriken; värdet skrivs i ord: "3 cm mot bollen" |
| `−3.0 cm` (Hip sway) | "3,0 cm bort från målet" |
| `FO · TOP-IMPACT`, `AUDIO · START–TOP–IMPACT` | "Från top till träff" / "Takt (från ljudet)" |
| Swing tempo `2.90 : 1` + `0.85 / 0.30 s` | "Takt 2,9 : 1 (backswing 0,85 s, nedsving 0,30 s)" med etiketter på stapeln |
| Hip–chest sway gap | "Höfter före bröst (mot målet)" |
| Spine angle loss / spread | "Tappar framåtlutningen" / "Hur jämn lutningen är" |
| Trail elbow flare, Lead arm fold, Hands out | "Höger armbåge ut", "Vänster arm viks", "Händerna ut från kroppen" (följ Me → Hand) |
| Shaft across the line, Clubhead to plane, Shaft lean | Behåll gärna, men lägg en bild eller förklaring vid tryck |
| X-factor, X-factor stretch, Pelvis turn | "Skillnad axlar–höfter", "Extra vridning i nedsvingen", "Höftvridning" |
| `Your usual` | "Ditt vanliga" och bara med dom: "ovanligt för dig" |
| `untested` (Hand speed) | Dölj tills måttet är provat |
| `B10` | "Preliminärt mått" |
| `3D · NO MARKERS` | "3D" (markörlöst är teknik) |
| `Sampson error … limit 8 px` | "Kamerorna stämmer överens ✓ / ✗" |
| `Angle between phones 60–120°` | "Vinkel mellan telefonerna 93° ✓ (ska vara 60–120°)" |
| `median` (shot-chips) | "Snitt" eller "Typiskt" |
| `7i · 34` | "7-järn · 34 slag" |
| `Set 1 · 0.0–3.2 s` + beskärningsikon | "Serie 1"; beskärningen heter "Klipp" |
| fps / Dropped / Frames / Clicks / MB/min | En mening med dom (se punkt 1) |
| `Thermal Fair` | "Telefonen är varm – pausa snart" bara när det gäller |
| `Swings heard on both 6 of 6 · 1.2 ms · uncertain` | "Båda hörde 6 av 6 slag ✓" |
| `Other phone's view 0.12 s · 12 fps` | "Förhandsbild från andra telefonen" |
| `Detection wrong` | "Fel slag hittat – tryck för att rätta" |
| `First set ≥ −2.5 cm` | "Första serien: högst 2,5 cm bort från målet" |
| `WEEK 1` | "Vecka 1 av Focus" |
| `HEIGHT 1.80 m assumed` | "Längd 190 cm (från Me)" eller "Ange din längd för rätt cm" med länk |
| `Import focus`, `Import club suggestions` | Förklara eller flytta in i Claude-flödet |
| Tal utan dom i 3D-listan och "Your usual"-korten | Se punkt 3 |

---

## Färgsystemet för banden

- **Fungerar:**
  - Form och färg samverkar: fylld prick, ihålig ring och triangel. Det håller vid röd–grön färgblindhet och i gråskala.
  - Symbolen syns både vid siffran och på bandet.
  - Rött, gult och grönt följer en konvention som alla känner.
- **Fungerar inte:**
  1. Triangeln vrids (▲▼◄►) och kan läsas som en trendpil.
  2. Blått (Focus) ersätter statusen i stället för att läggas till.
  3. Vit prick betyder både "ingen dom" och "ditt vanliga". Ruta och streck kräver en nyckel som inte finns.
  4. "Your usual" har ibland dom, ibland inte, och ibland ingen ruta alls.
  5. Den grå stapeln (bra-området) och den mörkgrå axeln ligger nära varandra i ljushet.
- **Rekommendation:**
  - Fyra lägen: grön prick (bra), gul ring (nära), röd stående triangel (utanför) och grått streck (ingen dom, och då bara under "Fler mått").
  - Focus blir en blå etikett.
  - En nyckel vid tryck.

---

## Det som redan fungerar och inte får förstöras

- Den lugna mörka stilen: en stor siffra per mått och status direkt bredvid. Det är snabbt att skumma när ordningen blir rätt.
- Formkoden (prick, ring, triangel) är färgblindsäker.
- Raden "vs Jan 6" på varje mått: jämförelsen med förra passet är värdefull.
- Shot-vyn: video med leder, slag-chips per sving, kurvan med faslinje, mini-band per rad och spårknapparna Hands/Shoulders/Hips/Head.
- Focus-bladet: Drill, Swing thought, Done when och hastighetsstegen Slow → Half → Full → Varied. Det är konkret träning, precis vad visionen lovar.
- Guiden för att markera klubban: illustrationerna, förstoringslupen, modellens förslag (streckat = gissning, heldraget = ditt) och Undo/Skip.
- Vattenpasset med linje och grader. "Switch to FO" är en åtgärd i ett tryck, och precis så borde fler varningar se ut.
- 3D-vyn med Face on/DTL/Top, 1/8× och kamerorna ritade ovanifrån.
- Raderingsdialogen förklarar vad som händer på den andra telefonen.
- "assumed" vid längden och "Not analyzed" i listan är ärliga lägen.
- Stöd för stor text finns redan i siffrorna. Bygg vidare och ta inte bort det.
