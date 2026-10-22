# SwingLab — arbetssätt

SwingLab är en privat iPhone-app som analyserar golfsvingen ur slowmotion, down
the line och face on. Telefonen filmar, mäter och visar; PC:n tar emot samma
session och fortsätter där, med tyngre mätning och Claude som tolkar. Den hör
till Johannes vinterträning, bredvid Airtime (hoppen) och Golf SG (rundorna).

## Dataregeln — läs först

**Videor och mätningar lämnar bara telefonen när Johannes själv skickar dem.**
Repot är publikt (BESLUT B7), så det gäller dubbelt här.

- Appen har ingen server och inget moln. Sessionen lämnar telefonen bara som ett
  paket som Johannes delar (BESLUT B3).
- Testerna bär **påhittade** svingar (genererade leder). Lägg aldrig in riktiga
  leder, mått eller videor i repot: `.gitignore` stänger ute `*.mov`, `*.mp4`,
  `*.csv`, `*.zip` och `data/`.
- Johannes egna tal (oktobers järn 7 och senare pass) står i Golf SG, som är
  privat (HANDLED_PLAN §4), aldrig här. Skriv "oktobers mätning" och länka.
- Felmeddelanden nämner fil och rad, aldrig värdet.

## Arbetssättet — delat med de andra apparna

Det som gäller fler än en app (bygget, minuterna, testerna, datan) står i skillen
`.claude/skills/arbetssatt/`, med verktygen i `tools/arbetssatt/`. Båda är kopior
från `birdiebook/arbetssatt`: ändra där och synka, aldrig i kopian.

## Bygget — ingen Mac

- **Logiken bor i `SwingLabKit/`** (Swift-paket, bara Foundation) och testas på
  Linux i GitHub Actions (`swift:6.1`, release med `-enable-testing`). Det är den
  enda kompilatorn före TestFlight-bygget: **pusha och läs resultatet** innan du
  tror att Swift-kod fungerar: `git fetch origin ci-resultat && git show
  origin/ci-resultat:resultat/<sha>.txt`.
- **PC-sidan bor i `tools/pc/`** (Python med numpy). Den räknar samma mått som
  SwingLabKit och är facit för Swift: samma påhittade leder ska ge samma tal.
  `python3 -m unittest discover -s tools/tests`.
- **Appen i `App/` är ett tunt SwiftUI-skal** (från S2). Xcode-projektet
  genereras ur `project.yml` (XcodeGen) och är gitignorerat. `kompilera.yml`
  arkiverar den för telefonen som TestFlight (utan signering), bygger den för
  simulatorn och kör `Prov/` vid varje push som rör appen
  (BESLUT B20), gratis: `git show origin/ci-resultat:resultat/<sha>.kompilera.txt`,
  och startvyn som `resultat/<sha>.startvy.png`.
- **TestFlight** byggs i GitHub Actions på macOS, gratis eftersom repot är
  publikt (BESLUT B7). Bygget startas **bara för hand**, efter Johannes ja,
  högst ett per dag. Aldrig med en tagg eller push.

## Beslut och metod

- **`docs/BESLUT.md`** — varje beslut: valt, bortvalt, kostnad, när det omprövas.
- **`docs/METOD.md`** — varje mått, gräns och konstant med källa och källans
  status. Koden hänvisar med `// METOD M3` och `// BESLUT B2`;
  `tools/kolla_metod.py` (i Actions) fäller en hänvisning utan rubrik.
- **`docs/research/`** — underlaget från 2026-10-22. Siffrorna där är "ej läst
  i original" tills de kontrollerats (BESLUT B10).

## Planen

Etapper och "Klart när" står i [PLAN.md](PLAN.md), med bandet överst. Byt markör
i bandet i samma commit som en etapp landar.

## Svaren

Korta och direkta: slutsats och nästa steg först.
