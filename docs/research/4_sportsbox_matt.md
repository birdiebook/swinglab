# Sportsbox AI:s mått mot SwingLab (2026-10-22)

Referens över vad Sportsbox AI (3DGolf) mäter, och vad SwingLab har, kan få och
väljer bort. Underlag för etappen S1b och för S6/S7 i [PLAN.md](../../PLAN.md).

**Källornas status (BESLUT B10):** sportsbox.ai är spärrad i molnmiljön, så
Sportsbox hjälpcenter är läst via sökmotorns sammanfattningar, **ej läst i
original**.

- ✔ = bekräftat av Sportsbox hjälpcenter (ej läst i original).
- ◐ = från Johannes lista (2026-10-22), inte bekräftat av någon källa.

**SwingLab-kolumnen:** ✅ finns · 🟡 finns i annan form · ⬜ litet tillägg (S1b) ·
❌ kräver S6 (två kameror) eller S7 (klubban) · – medvetet bortvalt.

Ett skäl till skillnaderna: Sportsbox mäter i 3D ur en kamera med en egen
AI-modell. SwingLab mäter varje mått i den vy där det ligger i bildens plan
(METOD), och vridningar först med två kameror (B9, B14).

## Grunden: sex frihetsgrader (6 DoF) ✔

Varje kroppsdel mäts relativt adressen (P1 = 0).

| Typ | Mått | Riktning | Enhet |
|---|---|---|---|
| Linjärt | Sway | sidled, längs mållinjen (Toward/Away target) | tum/cm |
| | Lift | höjdled (Up/Down) | tum/cm |
| | Thrust | djupled, mot/från bollen (Toward/Away ball) | tum/cm |
| Vinkel | Turn | rotation kring vertikal axel (Open/Closed) | grader |
| | Bend | lutning framåt/bakåt | grader |
| | Side Bend | sidolutning | grader |

Teckenkonventionerna per mått är inte bekräftade, utom Forehead Sway (nedan).

## 1. Bäcken (Pelvis), 6 DoF ✔

| Mått | Vad det visar | SwingLab |
|---|---|---|
| Pelvis Turn | höftvridning (topp, träff: öppna höfter) | ❌ S6 |
| Pelvis Sway | glidning bort från/mot målet | ✅ FO (`backen_sway_*`) |
| Pelvis Lift | bäckenet upp/ned | ✅ (`backen_lyft_*`) |
| Pelvis Thrust | mot bollen = early extension | ✅ DTL (`backen_thrust_*`) |
| Pelvis Bend | bäckenets tilt framåt/bakåt | ⬜ S1b (DTL) |
| Pelvis Side Bend | höftlinjens sidolutning | 🟡 höftlinjen i bild (FO), inte Sportsbox definition |

## 2. Bröstkorg (Chest), 6 DoF ✔

| Mått | Vad det visar | SwingLab |
|---|---|---|
| Chest Turn | bröstets vridning | ❌ S6 |
| Chest Sway | överkroppens sidoförflyttning | ✅ FO (`brost_sway_*`) |
| Chest Lift | överkroppen upp/ned | ⬜ S1b |
| Chest Thrust | bröstet mot/från bollen | ✅ DTL (`brost_thrust_*`) |
| Chest Bend | framåtböjning, tappad hållning | ✅ DTL (`brost_bojning_*`) |
| Chest Side Bend | sidolutning | ✅ FO i 2D (`sidbojning_*`) |

## 3. Huvud ✔

| Mått | Definition | SwingLab |
|---|---|---|
| Forehead Sway | punkt mitt på pannan, adress = 0, Away (bort från målet) negativt, Toward positivt; påverkas också av huvudets vridning | ✅ (näsan som punkt, `huvud_sway_*`) |
| Forehead Lift | samma punkt i höjdled | ✅ (`huvud_lyft_*`) |

## 4. Händer och armar

| Mått | Status | Definition | SwingLab |
|---|---|---|---|
| Mid-Hand Sway | ✔ | punkt på greppet mellan händerna, sidled från adressen; visar svingens bredd (en annan sida kallar den Hand sway, FON) | ✅ (händerna mot adressen) |
| Mid-Hand Lift | ✔ | samma punkt i höjdled | ⬜ S1b |
| Mid-Hand Speed / Max Hand Speed | ◐ | handens fart och max | ⬜ S1b (kräver låst slutartid, B11; oprovat) |
| Lead Arm Angle | ◐ | vänsterarmens vinkel | 🟡 vänsterarmens böjning, 0 = rak (M28/M29) |

## 5. Ben och knän ◐

| Mått | SwingLab |
|---|---|
| Lead/Trail Knee Flexion | 🟡 bakre knät (DTL, `bakre_kna_*`); främre ⬜ S1b |
| Lead/Trail Knee Sway | ⬜ S1b (FO) |

## 6. Relationsmått

| Mått | Status | Definition | SwingLab |
|---|---|---|---|
| Sway Gap | ✔ | vågrätt avstånd mellan bröstets och bäckenets mitt | ✅ (`sway_gap_traff`) |
| Club-Hand Gap (DTL) | ✔ | klubbhuvudet mot händerna: negativt = bakom händerna, positivt = före | ❌ S7 |

## 7. Kinematik, farter och gain factors

| Mått | Status | Definition (proffsens medel med driver, män/kvinnor) | SwingLab |
|---|---|---|---|
| Max Pelvis/Chest Turn Speed | ◐ | toppfart i vridning, °/s | ❌ S6 och skarp bild |
| Max Lead Arm Speed | ◐ | vänsterarmens toppfart, °/s | ⬜ S1b i 2D, osäkert |
| Max Shaft Speed | ◐ | skaftets toppfart, °/s | ❌ S7 |
| Kinematic Sequence | ◐ | ordning och tidpunkt för topparna bäcken → bröst → arm → klubba | ❌ S6 + S7 |
| X-Factor / X-Factor Stretch | ◐ | separationen bröst–bäcken vid toppen och ökningen i tidig nedsving | ❌ S6 (trend utan markörer, B14) |
| Core Gain Factor | ✔ | bröstets toppfart / bäckenets (1,5 / 1,4) | ❌ S6 |
| Shoulder Gain Factor | ✔ | vänsterarmens toppfart / bröstets (1,4 / 1,3) | ❌ S6 |
| Wrist Gain Factor | ✔ | skaftets toppfart / vänsterarmens (2,3 / 2,0) | ❌ S7 |
| Release Factor | ✔ | klubbhuvudets toppfart / handens (5,0 / 4,8), "Sportsbox smash factor" | ❌ S7 |

Gain factors fylls bara i för svingar inspelade i Sportsbox app, inte importerade,
och kräver bra ljus ✔. Det stöder B11 (inspelning i appen med låst slutartid).

## 8. Timing, tempo och positioner

| Mått | Status | SwingLab |
|---|---|---|
| Backswing / Downswing Time | ◐ | ✅ (tempots delar, M-raderna för tempo) |
| Follow Through Time | ◐ | ⬜ S1b |
| Tempo Ratio (t.ex. 3:1) | ◐ | ✅ |
| Hand Speed Max Timing | ◐ | ⬜ S1b (med handfarten) |
| Måtten per position (P1–P10) | ✔ | ✅ P1, P3, P4, P5, P7, P9, P10 (B32, M28); P2, P6, P8 ❌ S7 |

## 9. Betyg ✔

| Mått | Definition | SwingLab |
|---|---|---|
| Universal Swing Score | medel av tre delbetyg, vart och ett en percentil mot spelare av samma kön i Sportsbox databas; minst 3 svingar med en klubba | – B13: ingen totalpoäng, och ingen databas |
| Speed Score | percentil för fart | – |
| Efficiency Score | percentil; formeln är inte publicerad | – |
| Consistency Score | percentil för spridning | – (SwingLab visar den egna spridningen) |

Separat: Sportsbox Speed Assessment uppskattar den högsta möjliga klubbfarten ur
vridning, vertikal rörelse och release (Golf.com).

## Sammanfattning

- **Har nu:** sway, thrust och lyft för bäcken, bröst och huvud; bröstets böjning
  och sidböjning; sway gap; armar och händer; bakre knät; tempo; måtten per
  position.
- **S1b, små tillägg i 2D:** bäckenets böjning, bröstets lyft, handens lyft,
  främre knät, knäns sway, follow-through-tid, handfart och dess tidpunkt,
  vänsterarmens fart.
- **S6, två kameror:** alla turn-mått, X-factor och stretch, vridfarterna, core
  och shoulder gain factor.
- **S7, klubban:** club-hand gap, skaftets fart, wrist och release factor, den
  kinematiska sekvensen till klubban, P2/P6/P8.
- **Bortvalt:** Universal Swing Score (B13).

## Källor

- [Six Degrees of Freedom](https://help.sportsbox.ai/six-degrees-of-freedom)
- [Gain Factor](https://help.sportsbox.ai/what-is-a-gain-factor-in-the-sportsbox-3dgolf-app)
- [What is Universal Swing Score](https://help.sportsbox.ai/what-is-sportsbox-universal-swing-score)
- [Universal Swing Score Report](https://help.sportsbox.ai/universal-swing-score-report)
- [Sway Gap](https://help.sportsbox.ai/what-is-sway-gap)
- [Tracker (NUMBERS)](https://help.sportsbox.ai/what-is-a-tracker-numbers-in-the-sportsbox-3dgolf-app)
- [Tracker (VISUALS)](https://help.sportsbox.ai/what-is-a-tracker-in-the-sportsbox-3dgolf-app)
- [Trackers i 3D Player](https://help.sportsbox.ai/what-trackers-are-included-with-3d-practice)
- [Golf.com – Speed Assessment](https://golf.com/instruction/driving/check-clubhead-speed-sportsbox-ai/)
- [Golf.com – sway](https://golf.com/instruction/key-to-better-ball-striking-sportsbox/)
- [Golf Digest – sway gap](https://www.golfdigest.com/story/sway-gap-golf-digest-tip-backswing-downswing)
- [Phil Cheetham – 6DOF](https://www.philcheetham.com/analyzing-the-golf-swing-in-6-degrees-of-freedom-with-amm-6dof-systems/)
- [Golficity – recension](https://golficity.com/sportsbox-ai-review-turn-your-phone-into-a-3d-golf-coach/)
- [Clubhouse Hawaii – X-factor](https://clubhousehawaii.com/blogs/news/sportsbox-ai-x-factor-swing-analysis)
- [App Store – Sportsbox 3D Golf](https://apps.apple.com/us/app/sportsbox-3d-golf/id1578921026)
