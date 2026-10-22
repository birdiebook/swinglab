---
name: arbetssatt
description: Johannes arbetssätt för alla appar (Idunn, Birdiebook och nya). Använd ALLTID innan ett TestFlight- eller molnbygge startas, innan tester eller CI läggs upp eller ändras, när en ny app eller ett nytt repo påbörjas, och när en läxa ska skrivas ner som kan gälla fler än en app.
---

# Arbetssättet — gäller varje app

Den här filen är en kopia. Sanningen bor i det privata repot `birdiebook/arbetssatt`
(`C:\dev\arbetssatt` på hemdatorn) och synkas in med `synka.py`. **Ändra inte här:**
ändra i `arbetssatt`, och synka. Appens egen CLAUDE.md gäller före den här filen där
de skiljer sig.

## Johannes

- **Johannes gör så lite som möjligt.** Gör stegen själv i stället för att beskriva
  dem. Fråga bara när beslutet är Johannes: en leverans, något som kostar pengar,
  något som syns utåt eller inte går att backa.
- **Kunskap bor i repot**, aldrig bara i en chatt eller i en dators minne. Beslut i
  appens beslutslogg, läxor där de hör hemma. En läxa som gäller fler än en app skrivs
  här, i `arbetssatt`, och appen får en rad med länk.

## Bygget och leveransen

- **Inget bygge utan Johannes ja.** Varje TestFlight-bygge är en leverans.
- **Högst ett bygge per dag.** En intensiv dag buntas till ett bygge. Det som landar
  efter dagens bygge väntar till nästa. Fråga Johannes när det finns något att prova
  på telefonen, inte efter varje etapp.
- **Starta bygget med appens skript, aldrig med en tagg.** En tagg har startat inget
  bygge och ändå sett lyckad ut, tre gånger. Skriptet visar vad bygget bär och vägrar
  när CI är rött, ett annat bygge går eller minuterna inte räcker.
- **Prov i simulator bara när sparad data rörs.** Ett kompileringsfel stoppar bygget
  självt, en trasig vy syns på telefonen och TestFlight har förra bygget kvar. Det som
  inte går att backa är sparad data: ändringar i hur den sparas, läses eller räknas om
  provas först.

## Minuterna (Codemagic)

- **500 minuter macOS i månaden, delade mellan alla appar.** Läxa oktober 2026:
  minuterna tog slut den 15:e på prov som vuxit från 6 till 40 minuter och körts en
  gång per gren, och TestFlight-bygget fick `402 BILLING_NOT_ENABLED`.
- **Mät förbrukningen och spärra.** `python tools/arbetssatt/codemagic_vakt.py` visar
  månadens minuter per app. Appens byggskript frågar `codemagic_vakt.hinder()` före
  varje bygge: ett bygge går redan, dagens bygge är gjort, minuterna räcker inte. Prov
  och förhandsvisningar får aldrig äta reserven till TestFlight. Betalning är
  Johannes beslut (0,095 USD per minut).
- **Ingenting dubbelt i betald CI.** Det som kan köras gratis körs där.

## Testerna

- **Testerna körs gratis i GitHub Actions, i release-läge.** Mätt i Idunn: 395 s i
  debug, 44 s i release, för samma 670 tester. Bygg med `-c release -Xswiftc
  -enable-testing` så att `@testable` fungerar.
- **CI-resultatet ska gå att läsa utan `gh`.** Actions lägger en sammanfattning per
  commit på grenen `ci-resultat` (`tools/arbetssatt/ci_sammanfattning.py`), som läses
  med `git fetch`. Mönstret finns i Idunns `.github/workflows/test.yml`.
- **Ett tungt test räknar en hel påhittad natt eller runda.** Håll dem få, och
  memoisera indata som flera tester delar.
- **Ett test som inte prövar något är värre än inget test.** En stubb får svara fel,
  aldrig tomt. Ett grönt resultat ska ha ett kvitto på att det prövat rätt sak.

## Data

- **Riktig data lämnar aldrig Johannes enheter utan att Johannes själv skickar den.** Testerna
  bär påhittade fixturer. Felmeddelanden nämner fil och rad, aldrig värdet.
- **Hemligheter står aldrig i en committad fil.** Nycklar ligger i `.env` på
  hemdatorn eller i molnmiljöns inställningar.

## Parallellt arbete

- **Ett jobb, ett worktree, en gren.** Två sessioner i samma mapp skriver över
  varandra.
- **Landa med rebase på färsk `origin/main` och `push HEAD:main`.** `git fetch`
  direkt före, alltid.
- **Leta efter olandat arbete på samma yta innan du bygger.** Jämför filerna, inte
  commit-grafen: efter en cherry-pick har innehållet nya hashar.
