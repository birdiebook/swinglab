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
4. **Inga värdeord.** Förändring visas som tecken och tal ("+1,2 cm mot 6 jan"),
   och läget som en markör i spannet. Ingen totalpoäng.
5. **Ingen beskrivande text.** Bara etiketter, tal, enheter och det som måste
   läsas för att använda appen: övningens namn, tanken och "klart när" som ett
   villkor i tal. Märkningarna är små symboler med en kort etikett: B10 (gräns
   ej läst i original), egen (egen baslinje), av (avstängt mått).
6. **Svart, vitt och gråskala.** Ingen accentfärg. En dämpad signalfärg bara där
   den bär information (en varning i uppställningen). Inga skuggor, inga
   gradienter, raka eller lätt rundade hörn (2–4 px), tunna linjer.
7. **Typografi:** system-ui (SF Pro), tabellsiffror, stora tal med enheten liten
   och grå bredvid.
8. **Primärknappen** är ett vitt fält med svart text, överallt.
9. **Intuitivt utan text.** Kräver en skärm en förklaring är designen fel. Gör om
   den i stället för att lägga till text.

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

## Öppna val

1. **Flödet:** tre flikar med passet som eget flöde, eller en fjärde flik för
   passen.
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
