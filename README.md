# SwingLab

Analyserar golfsvingen ur slowmotion med iPhone, down the line och face on:
kroppens lägen och rörelser per fas, felen ur en katalog, och vad som ska
tränas. Se [PLAN.md](PLAN.md) och [CLAUDE.md](CLAUDE.md).

- `SwingLabKit/` — logiken som Swift-paket, testbar på Linux
- `App/` — det tunna SwiftUI-skalet; `Prov/` — simulatorprovet (BESLUT B20)
- `tools/pc/` — PC-sidan: samma mått i Python, och facit för Swift
- `docs/` — beslut, metod och research

## Första gången (Johannes, cirka 20 min)

0. **Registrera bundle-id:t först**, annars är listan tom i steg 1:
   developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → +
   → App IDs → App → Explicit `se.birdiebook.swinglab`. Inga capabilities.
1. **App Store Connect → Appar → +:** ny iOS-app med bundle-id
   `se.birdiebook.swinglab` ur listan, namnet "SwingLab - Golf Swing Analysis"
   (måste vara unikt; hemskärmen visar "SwingLab", BESLUT B8), SKU `swinglab`,
   språk svenska. Under TestFlight: en intern testgrupp med automatisk
   distribution. Tryck aldrig "Add for Review".
2. **Hemligheterna, som organisationshemligheter** så att SwingLab och Airtime
   delar dem: GitHub → organisationen `birdiebook` → Settings → Secrets and
   variables → Actions → New organization secret, med tillgång för `swinglab`
   och `hopp`. En GitHub-hemlighet går inte att läsa tillbaka, så värdena hämtas
   från källan:
   1. `APP_STORE_CONNECT_ISSUER_ID` och `APP_STORE_CONNECT_KEY_IDENTIFIER`: App
      Store Connect → Users and Access → Integrations → App Store Connect API
      (Issuer ID överst, Key ID på nyckelns rad).
   2. `APP_STORE_CONNECT_PRIVATE_KEY`: hela innehållet i nyckelns `.p8`-fil. Den
      laddas bara ner en gång; finns den inte kvar, skapa en ny nyckel med
      rollen Admin och använd dess Key ID i punkt 1.
   3. `CERTIFICATE_PRIVATE_KEY`: base64 av `C:\Users\johan\.idun\cert_key.pem`.
      I PowerShell:
      `[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\Users\johan\.idun\cert_key.pem")) | Set-Clipboard`

Sedan, efter ett ja: Actions → testflight → Run workflow på `main`. Bygget kräver
grönt i `kompilera` för den commiten, eller för en tidigare commit om inget i
`App/`, `Prov/`, `SwingLabKit/` eller `project.yml` har ändrats sedan dess. Annars
(eller om det inte finns något resultat): Actions → kompilera → Run workflow på
`main` först.

Inte ansluten till Sportsbox, GEARS, TPI eller någon annan nämnd tjänst.
