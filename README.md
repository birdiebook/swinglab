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
2. **Hemligheterna, som repository secrets:** GitHub → `birdiebook/swinglab` →
   Settings → Secrets and variables → **Actions** → fliken Secrets → New
   repository secret (inte Codespaces eller Dependabot). `birdiebook` är ett
   personligt konto, så det finns inga organisationshemligheter att dela; Airtime
   behöver samma fyra i `birdiebook/hopp`. En GitHub-hemlighet går inte att läsa
   tillbaka, så värdena hämtas från källan:
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

## Hemdatorn (Johannes)

Ett kommando per steg, i den här ordningen. Inga tal hamnar i repot: allt skrivs
utanför det. Paketen är passets `swinglab-<pass>-dtl.zip` och `-fo.zip` från telefonen
(Send to PC), gärna ett pass med båda vyerna och klipp.

1. **S0, oktobers mått** (i `C:\dev\golf-sg`):
   `python tools/handled_s0.py data/handled/video/2026-10-17 --utom IMG_1048.MOV`
   Titta på kontaktarken `s0_<klipp>.jpg` i samma mapp: ligger axellinjen och bäckenets
   läge där ögat ser dem? Talen står i `s0.json` (tre definitioner av lutningen, tecknen
   per slag). Claude rättar sedan HANDLED_PLAN §4.
2. **S3, Vision mot MediaPipe** (i swinglab-mappen):
   `python tools/pc/s3_facit.py <mapp>\swinglab-<pass>-dtl.zip <mapp>\swinglab-<pass>-fo.zip`
   Första gången säger skriptet om `pip install mediapipe opencv-python` behövs; modellen
   hämtas själv. Cirka en minut per slag; nästa körning återanvänder lederna.
   Titta på `~\swinglab-s3\<pass>\s3.md`, överst det som avgör B5, och
   `kontaktark-s3-<vy>.png` (vitt Vision, orange MediaPipe: vilken sitter rätt?).
   B5 tas sedan med Claude.
3. **S7, märk klubban:**
   `python tools/pc/markera_klubba.py <mapp>\swinglab-<pass>-dtl.zip <mapp>\swinglab-<pass>-fo.zip`
   Sidan öppnas i webbläsaren: klicka grepp, skaftets mitt och klubbhuvudet (hoseln).
   Enter = rutan klar, mellanslag = hoppa över, X = syns inte, Z = zoom, Klar = sluta.
   Märkningen sparas efter varje ruta i `swinglab-<pass>-klubba.json` bredvid paketen,
   och samma kommando fortsätter där du slutade. Titta på räknaren överst: alla rutor
   märkta eller hoppade.

Inte ansluten till Sportsbox, GEARS, TPI eller någon annan nämnd tjänst.
