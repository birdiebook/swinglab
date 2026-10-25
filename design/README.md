# Skissen

`skiss.html` är en klickbar skiss av SwingLab, till för att Johannes ska
bestämma flöde och utseende innan S2 och S4 byggs. Öppna den i en webbläsare.
Alla tal, datum och slag är påhittade.

Flödet: tre flikar (Idag, Utveckling, Jag). Ett pass är ett eget flöde:
Uppställning → Inspelning → Granskning → Passet. Att jobba på öppnas från Idag.

## Reglerna (BESLUT B13, Johannes 2026-10-22)

1. **Ett analysverktyg, inte en konsumentapp.** Inga belöningar, streaks,
   uppmuntran eller animationer för stämningens skull. Det som rör sig är data
   (ljudets klick, räknaren).
2. **Ingen figur.** Ingen gubbe, inget piktogram och ingen illustrerad person.
   Kameran och granskningen visar en neutral videoyta med bara de uppmätta
   linjerna och punkterna, som ett mätinstrument.
3. **Datan bär sidan.** Ett mått är namn, tal, enhet och spannet som en tunn
   linje med en markör. Geometri bara där den är själva måttet (en vinkel som
   två linjer).
4. **Inga värdeord.** Förändring visas som tecken och tal ("+1.2 cm vs Jan 6",
   på engelska, BESLUT B30),
   och läget som en markör i spannet. Ingen totalpoäng. **Undantag (B94):** raden under spannet
   och bandets nyckel säger "Good" om bandets gränser ("Good: −2.5 to 0 cm"), aldrig om värdet.
5. **Ingen beskrivande text.** Bara etiketter, tal, enheter och det som måste
   läsas för att använda appen: övningens namn, tanken och "klart när" som ett
   villkor i tal. Märkningarna är små symboler med en kort etikett: Your usual (egen
   baslinje, B87), off (avstängt mått). B10 (gräns ej läst i original) står bara i
   infobladets källa sedan S4h (BESLUT B94). **Undantag (B94):** kvittot och Claude-felet
   är en mening med vad man gör, och felsökningens tal ligger bakom "Details".
6. **Svart, vitt och gråskala.** En enda accent (regel 10). En dämpad signalfärg bara där
   den bär information (en varning i uppställningen). Inga skuggor, inga
   gradienter, raka eller lätt rundade hörn (2–4 px), tunna linjer.
   **Undantag (BESLUT B85):** inspelningens status har egna färger, grönt för
   "Connected", rött för inspelningen (pillen och knappens fält, som iPhones
   kameraapp) och gult för varningens ikon, och dess svarta rutor och piller har
   rundade hörn (12 pt, pillerna halvrunda). Bara på inspelningens skärm.
7. **Typografi:** system-ui (SF Pro), tabellsiffror, stora tal med enheten liten
   och grå bredvid.
8. **Primärknappen** är ett vitt fält med svart text, överallt.
9. **Intuitivt utan text.** Kräver en skärm en förklaring är designen fel. Gör om
   den i stället för att lägga till text. **Undantag (BESLUT B59):** klubbans
   märkningsläge är ett verktyg och har en instruktionsrad ("1 · Tap the grip") och en
   guide; undantaget gäller bara där.
10. **Accenten (BESLUT B31).** En enda accent, isblå `#6FD3F7`, och den betyder
    bara "det du övar på": måttet eller måtten i Att jobba på. De bär den i sitt
    kort i Passet, sin rad på Idag, sin linje i Utveckling, sin uppmätta linje i
    Granskningen och i kedjan. Bara tunna linjer, markören och en etikett,
    aldrig ytor, knappar eller bakgrunder. Aldrig som dom över bra eller dåligt.
11. **Läget mot bandet (BESLUT B87, undantag från regel 4 och 6).** Ett mått med band
    får en symbol bredvid talet och samma symbol som markör på spannet: en **fylld grön
    prick** innanför (`#30D158`), en **gul ring** utanför men inom måttets brusgolv, alltså
    kanske mätfel (`#FFD60A`), och en **röd fylld triangel** som pekar åt värdet, upp eller
    ner bredvid talet och höger eller vänster på spannet (`#FF3B30`). Formen bär betydelsen
    också utan färg. Den egna baslinjen är ramen "Your usual" utan färg, utom den röda
    triangeln när värdet ligger mer än golvet åt måttets sämre håll. Inga ord. Accenten
    (regel 10) står kvar på rubriken, namnet och kvartilerna; markören bär läget när det finns.
    **Sedan S4h (BESLUT B94):** under spannet står bara bra-området med enhet ("Good: −2.5 to 0
    cm") eller den egna baslinjen ("Your usual: 2.0 to 2.6°"), ett undantag från regel 4, och ⓘ;
    ett tryck på spannet eller ⓘ visar nyckeln (vad fältet, prick, ring, triangel, den vita linjen,
    strecket och ramen betyder). Passet börjar med Focus eller de röda måtten, korten står rött,
    gult, grönt, och mått utan läge ligger under "More measures (n)". Granskningens rader står i
    samma ordning.
12. **Det som tar bort (BESLUT B94).** Delete har systemets röda `#FF453A` (HIG:s destruktiva
    stil), i svepet och i frågan; spärrad är den grå med en rad om varför.

## Språket (BESLUT B30, B33)

Appen är på engelska; dokumenten och koden använder de svenska namnen. Skärmarna
heter Today (Idag), Session (Passet), Progress (Utveckling), Focus (Att jobba
på) och Review (Granskning). I appen: Drill (övning), Swing thought (tanke), Done
when (klart när), Mobility (rörlighet), First set (första serien), Shots (slagen),
Audio (tempots vy, ur klicket) och positionerna Address, Top, Impact och Finish.
Måtten: Sway, Hip shift, Thrust, Chest bend, Side bend, Sway gap. Klubborna skrivs
7i, 3W, 4H, PW, Dr överallt. Tal med decimalpunkt och äkta minus ("−2.4 cm"), datum "Jan 9".

## Paletten

| Token | Hex | Används till |
|---|---|---|
| `--ground` | `#000000` | botten |
| `--surface` | `#0D0D0D` | ytor |
| `--raised` | `#161616` | upphöjda ytor |
| `--hair` | `#1C1C1C` | avdelare, rutnät |
| `--line` | `#2E2E2E` | spannens linje, kanter |
| `--cam` | `#0A0A0A` | videoytan |
| `--tertiary` | `#6B6B6B` | etiketter, förra passet |
| `--secondary` | `#A3A3A3` | sekundär text, gränsen i spannet |
| `--text` | `#FFFFFF` | text, tal, markören för nu |
| `--flag` | `#B98A4A` | bara varningar i uppställningen |
| `--acc` | `#6FD3F7` | bara det du övar på (regel 10) |
| `--live` | `#30D158` | bara inspelningens status "Connected" (B85) |
| `--rec` | `#D70015` | bara REC-pillen under inspelningen (B85) |
| `--rec-knapp` | `#FF3B30` | bara inspelningsknappens fält i den vita ringen (B85) |
| `--varning` | `#F5B54A` | bara varningens ikon i inspelningen (B85) |
| `--destruktiv` | `#FF453A` | bara Delete (regel 12, B94) |

## Öppna val

1. **Flödet:** besvarat i S4e (BESLUT B64, som ersätter B36): två flikar, Sessions
   (förstasidan med passen) och Me; passet är ett eget flöde. Today och Progress är
   dolda, koden kvar.
2. **Passets ordning:** genom svingen (som nu) eller med det som ska övas
   först.
3. **Under passet:** bara antalet slag (som nu) eller också uppläsning efter
   varje slag (högtalaren i inspelningen).
4. **Första serien:** 5 slag före uppvärmningen varje pass, som provet för
   "klart när".
5. **Miss per pass:** ska Johannes ange den, så att Claude måste välja ett fel
   som kan förklara den?
6. **Signalfärgen:** behövs den alls, eller räcker gråskalan även för
   varningarna?
7. **Granskningen:** besvarat 2026-10-22: P-positionerna och måtten per position (BESLUT B32).
