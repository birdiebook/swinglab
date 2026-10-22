# SwingLab

Analyserar golfsvingen ur slowmotion med iPhone, down the line och face on:
kroppens lägen och rörelser per fas, felen ur en katalog, och vad som ska
tränas. Se [PLAN.md](PLAN.md) och [CLAUDE.md](CLAUDE.md).

- `SwingLabKit/` — logiken som Swift-paket, testbar på Linux
- `App/` — det tunna SwiftUI-skalet; `Prov/` — simulatorprovet (BESLUT B20)
- `tools/pc/` — PC-sidan: samma mått i Python, och facit för Swift
- `docs/` — beslut, metod och research

## Första gången (Johannes, cirka 20 min)

1. **App Store Connect → Appar → +:** ny app, bundle-id `se.birdiebook.swinglab`
   (registreras annars av första bygget), namnet "SwingLab – Golf Swing
   Analysis" (namnet måste vara unikt; hemskärmen visar "SwingLab", BESLUT B8).
   Lägg till den interna testgruppen med automatisk distribution, som för Airtime.
2. **GitHub → birdiebook/swinglab → Settings → Secrets and variables → Actions:**
   fyra hemligheter, samma som Airtime har:
   - `APP_STORE_CONNECT_ISSUER_ID` och `APP_STORE_CONNECT_KEY_IDENTIFIER`: från
     App Store Connect → Users and Access → Integrations → App Store Connect API.
   - `APP_STORE_CONNECT_PRIVATE_KEY`: hela innehållet i nyckelns `.p8`-fil.
   - `CERTIFICATE_PRIVATE_KEY`: samma base64-nyckel som Airtime och Idunn.

Sedan, efter ett ja: Actions → testflight → Run workflow. Bygget vägrar en commit
som inte är grön i `kompilera`.

Inte ansluten till Sportsbox, GEARS, TPI eller någon annan nämnd tjänst.
