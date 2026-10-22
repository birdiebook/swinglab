# S2 — appskalet: teknisk spec (2026-10-22)

Den här specen är kontraktet för S2 i [PLAN.md](../PLAN.md). Den ska räcka för
en byggsession utan konversationsminne. Läs den hela före första raden kod, och
läs sedan bara etappen du bygger (§12).

**Varför den är så noggrann.** Ingen Mac finns. App-koden i `App/` har hittills
kompilerats först i TestFlight-bygget, högst ett om dagen. Specens viktigaste
val (§10, S2a) ändrar det: repot är publikt (BESLUT B7), så GitHubs macOS-maskin
är gratis och kan kompilera appen för simulatorn och köra ett prov vid varje
push. Ett kompileringsfel kostar då en push, inte en dag.

**Besluten** F1–F15 står sedan S2a i `docs/BESLUT.md` som B15–B29 (Fn är
B(n+14), tabellen i [S2_BESLUT_FORSLAG.md](S2_BESLUT_FORSLAG.md)). B20 (F6) och
B21 (F7) gäller, B16 (F2) och B26 (F12) väntar på Johannes, övriga prövas. Koden hänvisar med B-numret (`tools/kolla_metod.py`
fäller en `// BESLUT Bn` utan rubrik). **METOD-förslagen** (konstanter och algoritmer) står i §11 och
flyttas till `docs/METOD.md` på samma sätt.

**Status för påståendena.** Varje API-påstående har en källa på
developer.apple.com, läst i original 2026-10-22 (dokumentationens JSON, samma
text som sidan). "antagande" betyder egen slutsats eller räkning, och sådant
mäts på telefonen i den etapp som står vid raden.

---

## 0. Sammanfattning av valen

| Fråga | Val | Förslag |
|---|---|---|
| Inspelning | `AVCaptureMovieFileOutput`, 1080p 240 bilder/s, video och ljud i samma fil | F1 |
| Exponering | Auto med taket 1/2000 s mäter ljuset, sedan låst: `setExposureModeCustom(duration: 1/2000, iso:)` | F2 |
| Fokus, vitbalans, stabilisering | låsta, låst, av | F2 |
| Ljuset före passet | Ljusprovet: ISO-behov, flimmer och tappade rutor, "för mörkt" i EV | F4 |
| Lägsta iOS | 18.2 (filens starttid på telefonens klocka, `startPTS`) | F5 |
| Kompilering utan Mac | `kompilera.yml` på GitHubs macOS, gratis: bygger för simulatorn och kör simulatorprovet vid varje push som rör appen | F6 |
| Två telefoner | Network.framework (`NWListener`/`NWBrowser`/`NWConnection`, Bonjour, TCP), inte Multipeer (avskrivet i iOS 27) | F7 |
| Synk | Klickmönstret paras mellan telefonerna; pingen ger bara ett förhandsvärde; ljudets väg rättas | F8 |
| Klicket | Golf SG:s algoritm (`handled_video.klick`) ordagrant, i 30 s-bitar, plus en kontroll i lederna att det var en sving | F9 |
| Import ur Bilder | `PHAssetResource` av typen `.video` (originalet), inte den omräknade slowmotion | F10 |
| Vision | `VNDetectHumanBodyPoseRequest` på varje ruta ur `AVAssetReader` med rutans egen tid, orienteringen ur spårets transform, i förgrunden och återupptagbart per slag | F11 |
| Lagring | Application Support, videon utanför iCloud-backupen | F12 |
| Paketet | en zip per telefon och pass, okomprimerad och strömmad till disk, manifest v1 | F13 |
| Vägen tillbaka | `.fileImporter` för `att_jobba_pa.json`; exporten syns i Filer | F14 |
| Lederna | 13 leder med Golf SG:s namn och MediaPipes index | F15 |

Det Johannes behöver bestämma står i §13.

---

## 1. Vad Airtime och Idunn redan har som återanvänds

Airtime (`birdiebook/hopp`) och Idunn (`birdiebook/idun`) är byggda utan Mac på
samma sätt. Idunns App-kod har gått igenom TestFlight många gånger. Airtimes
App-kod (H2) och dess TestFlight-väg i GitHub Actions (Airtime BESLUT B9) hade
**inte** gått igenom ett bygge när den här specen skrevs (Airtimes band: H2 nu,
H3 ej gjord). Det som tas därifrån prövas alltså först i S2a:s simulatorbygge.

| Tas | Från | Hur |
|---|---|---|
| Läsa varje rutas tid ur filen utan att avkoda | Airtime `App/VideoFrames.swift` (`AVAssetReaderTrackOutput(track:outputSettings: nil)`, `CMSampleBufferGetPresentationTimeStamp`, sorterat) | Kopieras till `App/MediaReader.swift` nästan ordagrant. Tiderna går in i SwingLabKit (`FrameTiming`, §3.2) i stället för Airtimes `FrameClock`. |
| Exakt ruta för en bild | samma fil, `AVAssetImageGenerator` med `requestedTimeToleranceBefore/After = .zero` och `appliesPreferredTrackTransform = true` | Till miniatyren vid träffen och skelettet över den (S2e). Inte till Vision: en bild per anrop avkodar från närmaste nyckelbild och är för långsamt för 960 rutor. |
| Kamerans skal | Airtime `App/CameraRecorder.swift` (sessionen, `AVCaptureMovieFileOutput`, kön, delegaten, `videoRotationAngle = 90`, stabiliseringen av) och `CameraPreview` | Grunden för `App/Camera.swift`. Ändras: formatvalet går via SwingLabKit (§2.2), bildtiden sätts med `range.minFrameDuration` i stället för `CMTime(value: 1, timescale: rate)` (§2.2, risk R3), och ljud, exponering, fokus och vitbalans läggs till. |
| Inspelningsvyn | Airtime `App/RecordView.swift` (förhandsbilden, den röda knappen, bildfrekvensen i hörnet) | Grunden för `App/RecordView.swift`. |
| Mappar utanför backupen, oläsbar fil flyttas undan | Airtime `App/Store.swift` (`isExcludedFromBackup`, `historik-oläslig-…`) | Samma mönster i `App/Store.swift`. |
| Projektet | Airtime `project.yml`, Idunns test-mål `IdunnProv` (TEST_HOST, eget schema) | §10.1. |
| TestFlight i Actions | Airtime `.github/workflows/testflight.yml` | Kopieras med repo-vakten `birdiebook/swinglab`, bundle-id och schemat bytt. |
| Zip i ren Foundation | Idunn `IdunnKit/Sources/WhoopFrames/ZipArchive.swift` (huvudenas byte, DOS-tid, UTF-8-flaggan) | Formatet återanvänds. Idunns zip byggs i minnet; SwingLabs paket med klipp blir hundratals MB, så skrivaren strömmar till disk (§6.4). |
| Delningsbladet | Idunn `App/RawExport.swift` (`ActivitySheet`, fil i `temporaryDirectory`) | Samma. |
| Filer synliga i Filer-appen | Idunn `project.yml` (`UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`) | Samma, för `Documents/Export`. |
| Mikrofonens fråga | Idunn `App/SoundListener.swift` (`AVAudioApplication`) | Behövs inte: kameran frågar med `AVCaptureDevice.requestAccess(for: .audio)`. |
| CI-resultatet utan `gh` | SwingLabs egen `test.yml` (grenen `ci-resultat`) | Samma mönster i `kompilera.yml`. |
| Klicket | Golf SG `tools/handled_video.py`, `klick()` och `para()` | Portas till Swift (§4). |

Det som **inte** tas: Airtimes `PickedMovie` (`PhotosPicker` med
`preferredItemEncoding: .current`). Om den ger slowmotion-originalet är ett
antagande även i Airtime (Airtime METOD M5). SwingLab hämtar originalet
uttryckligen (§5).

---

## 2. Inspelningen

### 2.1 Fil-utgången: `AVCaptureMovieFileOutput`

`AVCaptureMovieFileOutput` skriver video och ljud till en QuickTime-fil
([dokumentation](https://developer.apple.com/documentation/avfoundation/avcapturemoviefileoutput)).
Båda spåren får sina tider från sessionens klocka, så ljudets klick och
bildernas tider ligger på samma tidslinje i filen. Golf SG mätte det på Kamera-
appens filer: bollen skyms 4–6 ms före klicket i alla fyra klippen, vilket
stämmer med ljudets väg på cirka 3 m (Golf SG HANDLED_PLAN §3).

- **Rutornas tider:** varje ruta har sin egen tid i filen och läses med
  `AVAssetReader` (§3.1). Tappas rutor syns det som hål i tiderna. Utgången
  säger inte till när den tappar en ruta; `FrameTiming` (§3.2) räknar hålen
  efteråt och skriver dem i manifestet och i kvittot efter varje inspelning.
- **Filens starttid på telefonens klocka:** delegaten
  `fileOutput(_:didStartRecordingTo:startPTS:from:)` ger "the timestamp of the
  first buffer written to the file, synced with
  AVCaptureSession.synchronizationClock", **från iOS 18.2**
  ([dokumentation](https://developer.apple.com/documentation/avfoundation/avcapturefileoutputrecordingdelegate/fileoutput(_:didstartrecordingto:startpts:from:))).
  Implementeras den anropas inte den gamla `didStartRecordingTo` utan `startPTS`.
  Tiden räknas om till värdklockan med
  `CMSyncConvertTime(startPTS, from: session.synchronizationClock ?? CMClock.hostTimeClock, to: CMClock.hostTimeClock)`
  ([CMSyncConvertTime](https://developer.apple.com/documentation/coremedia/cmsyncconverttime(_:from:to:)),
  [synchronizationClock, iOS 15.4](https://developer.apple.com/documentation/avfoundation/avcapturesession/synchronizationclock);
  `CMClockOrTimebase` är `CFTypeRef`, så en `CMClock` går att skicka). Det ger
  filens tid noll på värdklockan, som två telefoner jämför med pingen (§7).
- **Krasch eller avbrott:** `movieFragmentInterval` är 10 s som standard; en
  fil som inte avslutas är läsbar fram till sista fragmentet
  ([dokumentation](https://developer.apple.com/documentation/avfoundation/avcapturemoviefileoutput/moviefragmentinterval)).
  Lämnas som den är.
- **Disken:** `minFreeDiskSpaceLimit` stoppar inspelningen och anropar
  delegaten med ett fel när gränsen nås
  ([dokumentation](https://developer.apple.com/documentation/avfoundation/avcapturefileoutput/minfreediskspacelimit)).
  Sätts till 2 GB. Före start kontrolleras
  `volumeAvailableCapacityForImportantUsage` (URLResourceValues); under 4 GB
  ber appen Johannes frigöra plats.
- **Utgångens inställningar rörs inte.** `setOutputSettings(_:for:)` kastar ett
  undantag för en nyckel som inte finns i `supportedOutputSettingsKeys(for:)`
  ([dokumentation](https://developer.apple.com/documentation/avfoundation/avcapturemoviefileoutput/setoutputsettings(_:for:))),
  och ett Objective-C-undantag går inte att fånga i Swift: appen kraschar.
  Kodek (HEVC på telefonerna, antagande) och ljudformat (AAC, antagande) blir
  standard. Det som faktiskt skrevs läses ur filen och står i manifestet.

**Bortvalt: `AVAssetWriter` med `AVCaptureVideoDataOutput` och
`AVCaptureAudioDataOutput`.** Den ger orsaken till varje tappad ruta och kan
skriva okomprimerat ljud, men kräver egen kodning i 240 bilder/s, egen
sammanflätning av spåren och egen start och stopp: ett par hundra rader som
först kompileras på macOS och vars fel (ljudet förskjutet mot bilden) inte
syns i ett simulatorprov. Omprövas om inspelningarna tappar mer än 1 % av
rutorna (F1).

### 2.2 Formatet: 1080p i 240 bilder/s

Kameran är `AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)`
(som Airtime). Varje `AVCaptureDevice.Format` beskrivs för SwingLabKit som ett
värde, och valet görs där (testbart på Linux):

```swift
// SwingLabKit, modulen Capture (§9). Fylls i App/Camera.swift ur device.formats.
public struct CameraFormat: Codable, Equatable, Sendable {
    public var index: Int              // plats i device.formats
    public var width: Int              // CMVideoFormatDescriptionGetDimensions(f.formatDescription), lagrat (liggande)
    public var height: Int
    public var maxFrameRate: Double    // max över f.videoSupportedFrameRateRanges.map(\.maxFrameRate)
    public var fieldOfView: Double     // f.videoFieldOfView, vågrätt i grader i sensorns liggande läge, 0 = okänt
    public var binned: Bool            // f.isVideoBinned
    public var minISO: Double, maxISO: Double                 // f.minISO, f.maxISO
    public var minExposure: Double, maxExposure: Double       // f.minExposureDuration.seconds, f.maxExposureDuration.seconds
    public var tenBit: Bool            // pixelformatet är 10-bitars (CMFormatDescriptionGetMediaSubType == 'x420' eller 'x422')
    public var hdrSupported: Bool      // f.isVideoHDRSupported
}
public enum FormatChoice {
    /// Index i listan, eller nil. METOD MS1.
    public static func choose(_ formats: [CameraFormat], wantedRate: Double = 240) -> Int?
}
```

Regeln (METOD MS1, antagande som prövas i S2c): bara format med exakt
1920 × 1080 och `maxFrameRate ≥ wantedRate − 0,5`. Bland dem: störst
`fieldOfView`, sedan `binned == true` (binning ger "greater low light
sensitivity at the cost of reduced resolution",
[isVideoBinned](https://developer.apple.com/documentation/avfoundation/avcapturedevice/format/isvideobinned)),
sedan 8-bitars framför 10-bitars, sedan lägst index. Finns inget i 240 tas
högsta frekvensen ≥ 120 i 1080p, och vyn visar frekvensen i gult. Hela listan
skrivs till `enhet.json` i paketet, så att formaten på Johannes telefoner går
att läsa på PC:n utan att gissa.

Inställningen, i den ordning Apple anger
([activeFormat](https://developer.apple.com/documentation/avfoundation/avcapturedevice/activeformat)):

```swift
session.beginConfiguration()
// in- och utgångar läggs till först, var och en bakom canAddInput/canAddOutput
try device.lockForConfiguration()
device.activeFormat = format                       // sessionens preset blir .inputPriority
let range = format.videoSupportedFrameRateRanges.max { $0.maxFrameRate < $1.maxFrameRate }!
device.activeVideoMinFrameDuration = range.minFrameDuration   // INTE CMTime(value: 1, timescale: 240)
device.activeVideoMaxFrameDuration = range.minFrameDuration   // fast takt: ingen sänkning i mörker
device.videoZoomFactor = 1.0
if format.isVideoHDRSupported { device.automaticallyAdjustsVideoHDREnabled = false; device.isVideoHDREnabled = false }
device.unlockForConfiguration()
session.commitConfiguration()
```

`activeVideoMinFrameDuration` och `activeVideoMaxFrameDuration` kastar
`invalidArgumentException` för ett värde som inte finns i formatets
`videoSupportedFrameRateRanges`
([min](https://developer.apple.com/documentation/avfoundation/avcapturedevice/activevideominframeduration),
[max](https://developer.apple.com/documentation/avfoundation/avcapturedevice/activevideomaxframeduration)).
Att ta `range.minFrameDuration` ur själva intervallet undviker att 240,0 och
1/240 inte är samma tal i flyttal (risk R3).

**Orienteringen.** Telefonen står på stativ i stående läge och appen är låst
till stående. Videoanslutningen får `videoRotationAngle = 90` när
`isVideoRotationAngleSupported(90)` (iOS 17,
[dokumentation](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/videorotationangle)),
som i Airtime. Rutorna lagras liggande (1920 × 1080) med en rotation i spårets
`preferredTransform`; uppräta är de 1080 × 1920. §6.2 och §8.3 räknar om.

**Synfältet.** `videoFieldOfView` är formatets vågräta synfält i sensorns
liggande läge
([dokumentation](https://developer.apple.com/documentation/avfoundation/avcapturedevice/format/videofieldofview)).
I stående läge blir det det lodräta. Exempel (antagande, egen räkning): 70°
lodrätt och 3 m avstånd ger 2·3·tan 35° ≈ 4,2 m i höjd och, med 16:9, ≈ 2,4 m i
bredd. Det räcker för golfaren och klubban i toppen. Vision vill ha personen
minst en tredjedel av bildens höjd
([Detecting Human Body Poses in Images](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images)).
Vyn visar hjälplinjer: fötterna i nedre femtedelen, huvudet under övre
fjärdedelen.

**Stabiliseringen av.** `preferredVideoStabilizationMode = .off` (standard,
men sätts uttryckligen som i Airtime). Stabilisering "introduces additional
latency … and may consume more system memory", och enheter med stabilisering
stöder den bara på en del av formaten
([dokumentation](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/preferredvideostabilizationmode)).
Skälet för SwingLab (antagande): stabiliseringen beskär och flyttar varje ruta
olika, så att en led som står still rör sig i bilden och S6:s kalibrering mot
mattan inte gäller ruta för ruta. Telefonen står på stativ.

**Linsens distorsionsrättning** (`isGeometricDistortionCorrectionEnabled`,
standard `true` där den finns,
[dokumentation](https://developer.apple.com/documentation/avfoundation/avcapturedevice/isgeometricdistortioncorrectionenabled))
lämnas som den är men skrivs i manifestet. S6:s inre kalibrering görs med
samma läge.

### 2.3 Exponeringen: låst slutartid 1/2000 s

Oskärpan är fart × exponeringstid (BESLUT B11, research 2 §5). Inställningen
sker i två steg.

**Steg 1, mät ljuset** (när vyn öppnas). Autoexponeringen får taket 1/2000 s:
`device.activeMaxExposureDuration = clamp(1/2000, format.minExposureDuration, format.maxExposureDuration)`
och `exposureMode = .continuousAutoExposure`, med mätpunkten i mitten
(`exposurePointOfInterest = (0.5, 0.5)` om `isExposurePointOfInterestSupported`).
`activeMaxExposureDuration` sätter "the maximum exposure duration … in the
autoexposure algorithm", och kastar ett undantag utanför formatets gränser
([dokumentation](https://developer.apple.com/documentation/avfoundation/avcapturedevice/activemaxexposureduration)).
När `isAdjustingExposure` varit `false` i 0,5 s läses `exposureDuration`,
`iso` och `exposureTargetOffset` ("the metered exposure level's offset from the
target exposure value, in EV units",
[dokumentation](https://developer.apple.com/documentation/avfoundation/avcapturedevice/exposuretargetoffset)).

**Steg 2, lås.** SwingLabKit räknar fram det låsta läget:

```swift
public struct ExposurePlan: Codable, Equatable, Sendable {
    public enum Light: String, Codable, Sendable { case good, marginal, tooDark }
    public var duration: Double        // s, det som låses
    public var iso: Double             // det som låses, inom [minISO, maxISO]
    public var neededISO: Double       // vad 1/2000 s hade krävt
    public var deficitEV: Double       // > 0 betyder för mörkt med så många steg
    public var light: Light
}
public enum Exposure {
    /// METOD MS2. aeOffsetEV är exposureTargetOffset: negativt = för mörkt.
    public static func plan(aeDuration: Double, aeISO: Double, aeOffsetEV: Double,
                            target: Double = 1.0 / 2000, format: CameraFormat) -> ExposurePlan
}
```

Räkningen (METOD MS2): `duration = max(target, format.minExposure)`;
`neededISO = aeISO · (aeDuration / duration) · 2^(−aeOffsetEV)`;
`iso = clamp(neededISO, minISO, maxISO)`; `deficitEV = max(0, log2(neededISO / maxISO))`.
Ljuset är **good** om `neededISO ≤ maxISO / 2` (ett steg kvar), **marginal**
om `≤ maxISO`, annars **tooDark**. Appen låser med

```swift
try device.lockForConfiguration()
device.setExposureModeCustom(duration: CMTime(seconds: plan.duration, preferredTimescale: 1_000_000),
                             iso: Float(plan.iso), completionHandler: nil)
device.unlockForConfiguration()
```

`setExposureModeCustom(duration:iso:completionHandler:)` "throws an exception
if you set the exposure duration or ISO values to an unsupported level"
([dokumentation](https://developer.apple.com/documentation/avfoundation/avcapturedevice/setexposuremodecustom(duration:iso:completionhandler:))).
Därför går båda talen genom `Exposure.plan`, som aldrig lämnar formatets
gränser (testat på Linux), och `isExposureModeSupported(.custom)` kontrolleras
först.

**Vad formatet säger om ljuset** (antagande, egen räkning med
reflektansmätarens konstant K = 12,5 och ett grått motiv på 18 %):
exponeringsvärdet vid ISO 100 är EV₁₀₀ = log₂(N²/t) − log₂(S/100), luminansen
L = K · 2^EV₁₀₀ / 100 cd/m², och belysningen på ett grått motiv E = π·L/0,18.
Med bländaren N = 1,78 och t = 1/2000 s:

| ISO | EV₁₀₀ | Belysning på golfaren |
|---|---|---|
| 1000 | 9,3 | cirka 1 400 lux |
| 2000 | 8,3 | cirka 700 lux |
| 4000 | 7,3 | cirka 350 lux |

En vanlig inomhushall ligger kring några hundra lux (antagande). Inomhus
räcker det alltså bara med starka lampor, och formatets `maxISO` avgör hur
mörkt det får vara. `maxISO` för 240-formaten på Johannes telefoner är inte
känt; det står i `enhet.json` efter första körningen. Tabellen är en
storleksordning: telefonens ISO är inte kalibrerad mot standarden, och
videoexponeringens mål är inte exakt 18 % grått.

### 2.4 Fokus och vitbalans låsta

- **Fokus:** om `isFocusPointOfInterestSupported` sätts
  `focusPointOfInterest = (0.5, 0.5)` (koordinaterna är alltid sensorns
  liggande läge,
  [dokumentation](https://developer.apple.com/documentation/avfoundation/avcapturedevice/focuspointofinterest)),
  sedan `focusMode = .autoFocus` (en sökning). När `isAdjustingFocus` blivit
  `false` låses linsen med
  `setFocusModeLocked(lensPosition: AVCaptureDevice.currentLensPosition)`
  ([dokumentation](https://developer.apple.com/documentation/avfoundation/avcapturedevice/setfocusmodelocked(lensposition:completionhandler:))).
  Linsläget (0–1, `lensPosition`) skrivs i manifestet. Golfaren ska stå i
  adress under de två sekunderna. Skäl: autofokus som söker mitt i nedsvingen
  ger suddiga rutor just där måtten tas, och S6:s inre kalibrering gäller ett
  linsläge.
- **Vitbalans:** `setWhiteBalanceModeLocked(with: AVCaptureDevice.currentWhiteBalanceGains)`
  efter att autovitbalansen fått 1 s
  ([dokumentation](https://developer.apple.com/documentation/avfoundation/avcapturedevice/setwhitebalancemodelocked(with:completionhandler:))).
  Varje kanal måste ligga i `1.0 … maxWhiteBalanceGain`, annars ett undantag;
  att skicka konstanten `currentWhiteBalanceGains` undviker att räkna egna
  värden. Skäl: färgen ska inte vandra mellan slagen (Vision och S7:s
  klubbdetektor).
- Alla tre lås görs mellan `lockForConfiguration()` och `unlockForConfiguration()`;
  utan låset kastas ett undantag (samma sidor).

### 2.5 Ljudet

Ljudet spelas in i samma fil: en `AVCaptureDeviceInput` för
`AVCaptureDevice.default(for: .audio)` läggs till sessionen. Sessionen ställer
själv in appens `AVAudioSession` för inspelning med bakre kameran
(`automaticallyConfiguresApplicationAudioSession`, standard `true`,
[dokumentation](https://developer.apple.com/documentation/avfoundation/avcapturesession/automaticallyconfiguresapplicationaudiosession));
det lämnas så.

- **48 kHz:** samplingsfrekvensen i filen är telefonens (antagande: 48 kHz,
  AAC). Den läses om till 48 kHz mono Float32 när filen läses (§3.1), så att
  klickalgoritmen alltid får samma frekvens som i Golf SG (som läste om med
  ffmpeg till 48 kHz mono). Filens egen frekvens och kodek står i manifestet.
- **Mikrofonen:** före start kontrolleras att
  `AVAudioSession.sharedInstance().currentRoute.inputs.first?.portType == .builtInMic`.
  Annars (AirPods eller annan Bluetooth-mikrofon) visas en varning: ljudet kan
  komma med hundratals millisekunders fördröjning och från fel plats (risk R9).
- **AAC och klicket** (antagande): AAC sprider en skarp ansats något bakåt i
  tiden (kodarens korta block). Golf SG:s rest mot bandet, 1–7 ms i median på
  Kamera-appens AAC-filer, visar att det räcker för träffen (±1–2 rutor). För
  två telefoner med samma kodek tar felet till stor del ut sig.

### 2.6 Under inspelningen

- `UIApplication.shared.isIdleTimerDisabled = true` medan kameran är öppen och
  medan analysen går, `false` annars.
- **Värme:** `device.systemPressureState.level` observeras (KVO). Vid
  `.serious` eller högre visas en varning, och nivån skrivs per inspelning i
  manifestet. Systemet kan sänka kvaliteten under tryck och avbryter sessionen
  vid `shutdown`
  ([dokumentation](https://developer.apple.com/documentation/avfoundation/avcapturedevice/systempressurestate-swift.class)).
  Tappade rutor och tryck står då bredvid varandra i kvittot.
- **Avbrott** (samtal, appen i bakgrunden): `AVCaptureSession.wasInterruptedNotification`
  ([dokumentation](https://developer.apple.com/documentation/avfoundation/avcapturesession/wasinterruptednotification))
  → inspelningen avslutas, filen sparas och vyn säger det. Kameran går inte i
  bakgrunden.
- **Längden:** en inspelning är en *serie* (start → stopp), typiskt 5–15
  slag. Filens storlek per minut är okänd (antagande: några hundra MB i 1080p
  240 HEVC); den mäts i S2c och visas i kvittot. Efter analysen behålls bara
  klippen kring slagen om Johannes väljer det (§13, F12).

### 2.7 Ljusprovet före passet (METOD MS3)

En knapp i inspelningsvyn, "Ljusprov", tar 3 s:

1. Steg 1 i §2.3 ger `ExposurePlan`: ISO-behovet och EV-bristen.
2. Exponeringen låses (steg 2) och 2 s spelas in till `tmp/`.
3. Filen läses (§3.1): rutornas tider ger `FrameTiming` (tappade rutor), och
   ljusheten per ruta (medel av Y-planet i mittersta tredjedelen, läst med
   `kCVPixelFormatType_420YpCbCr8BiPlanarFullRange` nedskalat till 480 × 270 via
   `kCVPixelBufferWidthKey`/`kCVPixelBufferHeightKey`; skalning är tillåten för
   8-bitars format,
   [AVAssetReaderTrackOutput](https://developer.apple.com/documentation/avfoundation/avassetreadertrackoutput))
   ger flimret och nivån.
4. Filen tas bort. Resultatet visas som ett kort med tre rader och sparas i
   passet (`ljusprov.json` i paketet).

```swift
public struct LightCheck: Codable, Equatable, Sendable {
    public var exposure: ExposurePlan
    public var timing: FrameTiming
    public var flicker100: Double      // relativt djup vid 100 Hz (50 Hz-nät)
    public var flicker120: Double      // vid 120 Hz (60 Hz-nät), se nedan
    public var meanLuma: Double        // 0–1
    public var verdict: ExposurePlan.Light
}
public enum Flicker {
    /// Minsta kvadrat-anpassning av c + a·cos(2πft) + b·sin(2πft) på rutornas egna tider
    /// (tål tappade rutor). Svarar sqrt(a²+b²)/c. METOD MS3.
    public static func depth(luma: [Double], times: [Double], hz: Double) -> Double
    public static func check(exposure: ExposurePlan, timing: FrameTiming,
                             luma: [Double], times: [Double]) -> LightCheck
}
```

Gränserna (METOD MS3, antaganden som kalibreras på första passen): flimmer
under 3 % grönt, 3–10 % gult, över 10 % rött; tappade rutor under 1 % grönt,
1–5 % gult, över 5 % rött; ljusheten 0,20–0,60 grönt. Domen är den sämsta av
ISO, flimmer och rutor. 100 Hz ligger under halva bildfrekvensen (120 Hz) och
syns tydligt; 120 Hz ligger exakt på halva och syns bara i den fas som träffar
rutorna, så `flicker120` kan underskatta. I Sverige gäller 100 Hz.

Vyn visar "För mörkt: 1,3 steg" i stället för ISO-talet, och "Ljuset
flimrar" med procent. Lite text, en färg per rad.

---

## 3. Rutornas tider och ljudet ur en fil

Samma kod läser en egen inspelning, ett importerat original (§5) och ett
exporterat klipp. Den bor i `App/MediaReader.swift`; allt som går att räkna
utan AVFoundation bor i SwingLabKit.

### 3.1 Läsningen (App)

```swift
enum MediaReader {
    /// Varje rutas visningstid i sekunder, sorterade. Avkodar inte (outputSettings: nil). Från Airtime VideoFrames.load.
    static func frameTimes(_ url: URL) async throws -> [Double]
    /// Ljudet som 48 kHz mono Float32, i bitar om högst `segment` sekunder med `overlap` s överlapp.
    static func audio(_ url: URL, segment: Double = 30, overlap: Double = 1,
                      _ each: (_ startSeconds: Double, _ samples: [Float]) throws -> Void) async throws
    /// Spårets preferredTransform (a, b, c, d) och lagrade storlek (bredd, höjd).
    static func geometry(_ url: URL) async throws -> (a: Double, b: Double, c: Double, d: Double, width: Int, height: Int)
    /// Medelljusheten per ruta (§2.7).
    static func luma(_ url: URL) async throws -> (times: [Double], luma: [Double])
}
```

- Ljudet läses med `AVAssetReaderTrackOutput(track: audioTrack, outputSettings:)`
  där inställningarna är `AVFormatIDKey: kAudioFormatLinearPCM`,
  `AVSampleRateKey: 48_000`, `AVNumberOfChannelsKey: 1`,
  `AVLinearPCMBitDepthKey: 32`, `AVLinearPCMIsFloatKey: true`,
  `AVLinearPCMIsBigEndianKey: false`, `AVLinearPCMIsNonInterleaved: false`.
  En spårutgång ger okomprimerat; för ljud måste `AVFormatIDKey` vara
  `kAudioFormatLinearPCM`, och bara `AVSampleRateConverterAudioQualityKey`
  stöds inte
  ([AVAssetReaderTrackOutput](https://developer.apple.com/documentation/avfoundation/avassetreadertrackoutput)).
  Att omsamplingen och nedmixningen fungerar prövas i simulatorprovet (S2c),
  inte på telefonen.
- Ljudets tid för prov *n* i en bit är bitens första `CMSampleBuffer`s
  visningstid plus n/48 000. `AVAssetReader` följer spårets redigeringslista,
  så AAC:s inledande tystnad (priming) är redan bortklippt (antagande, prövas i
  simulatorprovet med AAC-ljud på kända tider).
- `alwaysCopiesSampleData = false` på alla utgångar (Airtime).

### 3.2 Tiderna (SwingLabKit)

```swift
public struct FrameTiming: Codable, Equatable, Sendable {
    public var count: Int
    public var gridRate: Double        // rutnätets frekvens: de korta stegen, förfinat med hela spannet (METOD MS3)
    public var meanRate: Double        // (count − 1) / (sista − första)
    public var missingFraction: Double // 1 − count / ((sista − första)·gridRate + 1), ≥ 0
    public var largestGap: Double      // s
    public var isSlowMotion: Bool      // gridRate ≥ 100
    public static func analyze(_ times: [Double]) -> FrameTiming
}
```

Rutnätet tas ur de kortaste stegen, inte medianen, eftersom oktobers klipp låg
på 240-rutnätet med drygt en tredjedel av rutorna borta (research 2 §2, 154
bilder/s i snitt); medianen hade gett fel om hälften saknats.
`isSlowMotion == false` på en import betyder att filen är omräknad: den vägras
med texten "Inte slowmotion-originalet" (§5).

---

## 4. Klicket (METOD MS4)

Golf SG hittade alla 41 klick i oktobers klipp och parade dem med bandets stöt,
med rest 1–7 ms i median per klipp (HANDLED_PLAN §3). Algoritmen portas
**ordagrant**, så att Swift och Python ger samma tal på samma ljud.

### 4.1 Algoritmen (ur `tools/handled_video.py`, `klick()`)

Indata: `x`, mono Float, `sr` = 48 000. Konstanter: fönstret `W_S = 0,002` s,
faktorn `F = 25`, minsta avstånd `GAP_S = 0,5` s, ansatsens sökfönster `ONSET_S = 0,02` s.

1. `hp[0] = 0`, `hp[n] = x[n] − x[n−1]` (Pythons `np.diff(x, prepend=x[0])`).
2. `w = max(1, Int(sr · W_S))` (96 vid 48 kHz), `h = (w − 1) / 2` (heltal, 47).
3. Energin `e[n] = sqrt( (1/w) · Σ hp[m]² )` över `m = n − (w − 1 − h) … n + h`
   (vid 48 kHz: n − 48 … n + 47), där prov utanför signalen räknas som 0 men
   divisionen ändå är med `w`. Det är `np.convolve(hp², ones(w)/w, mode="same")`
   (kontrollerat i numpy 2026-10-22: en impuls i prov 150 syns i e[103…198]).
   Räkna med löpande summa i `Double` (O(N)).
4. `bas = median(e) + 1e-9`. Medianen över hela biten (se 4.2).
5. Toppar: gå igenom alla `i` där `e[i] > F · bas`, i stigande ordning.
   Om det finns en senaste topp `p` och `i − p < sr · GAP_S`: om `e[i] > e[p]`
   ersätts `p` med `i`; gå vidare. Annars läggs `i` till som ny topp. (Notera:
   jämförelsen är mot den *senaste* toppen, som flyttas när den ersätts.)
6. Ansats per topp `p`: `a = max(0, p − Int(sr · ONSET_S))`; ansatsen `o` är
   första index i `a…p` där `e[o] > 0,5 · e[p]`.
7. Svaret per topp: `(tid = o / sr, styrka = e[p] / bas)`.

Ansatsen ligger upp till `h` prov (47 vid 48 kHz, 1 ms) före själva ljudet, eftersom
fönstret är centrerat. Det är samma i Python och Swift och lika för två
telefoner.

```swift
public struct Click: Codable, Equatable, Sendable {
    public var time: Double       // s från bitens början (Detector) eller filens (merge)
    public var strength: Double   // e[p] / bas
}
public enum ClickDetector {
    public struct Params: Codable, Equatable, Sendable {
        public var window = 0.002, factor = 25.0, minGap = 0.5, onsetLookback = 0.02, onsetFraction = 0.5
    }
    public static func detect(_ x: [Float], sampleRate: Double = 48_000, params: Params = .init()) -> [Click]
    /// Slår ihop bitarnas klick: tiderna flyttas med bitens start, och två klick
    /// närmare än minGap blir det starkaste.
    public static func merge(_ segments: [(start: Double, clicks: [Click])], minGap: Double = 0.5) -> [Click]
}
```

### 4.2 Bitar om 30 s

En serie på 15 min är 43 miljoner prov; hela ljudet och energin i minnet är
cirka 350 MB, och medianen kräver en sortering av allt. Appen läser därför 30 s
åt gången med 1 s överlapp (§3.1) och kör `detect` per bit. Medianen blir per
bit. För ett klipp under 30 s (oktobers klipp är längre, men PC-sidans facit
körs på samma bitar) är det exakt Golf SG:s algoritm. Medianen domineras av
bakgrundsljudet, som är stabilt över minuter, så skillnaden mot hela klippets
median är liten (antagande, mäts i S2h: oktobers 41 klick ska hittas lika).
**PC-sidan (`tools/pc/`) ska dela in i samma bitar** så att talen stämmer.

### 4.3 Är det ett slag? (METOD MS5)

På en range finns grannens klick, röster och klubban mot mattan. Golf SG
slapp frågan, eftersom bandets stöt valde ut klicken. SwingLab har inget band,
så ett klick blir ett slag först när lederna visar en sving:

1. **Glest:** Vision på var 8:e ruta i `[klick − 1,6 s, klick + 0,1 s]`
   (≈ 30 per sekund vid 240).
2. **Regeln** (SwingLabKit, `SwingCheck.verdict`):
   - kroppens längd `H` = medianen av (fotledernas mitt − näsan) i y, i pixlar;
   - händernas fart `v(t)` = förflyttningen av handledernas mitt mellan rutorna,
     delad med tiden och med `H` (kroppslängder per sekund);
   - **ja** om (a) högsta `v` i `[−0,10, +0,05]` s är minst 2,0 H/s, (b)
     händerna (handledernas mitt) står över axlarnas mitt någon gång i
     `[−1,6, −0,15]` s, och (c) minst 60 % av rutorna har alla 13 leder med
     konfidens ≥ 0,1;
   - **nej** om (a) eller (b) brister och (c) håller;
   - **osäkert** om (c) brister. Osäkra behålls men märks.
3. **Tätt:** bara bekräftade (och osäkra) slag får Vision på varje ruta i
   `[−2,5, +1,5]` s (§6).

Talen 2,0 H/s och fönstren är antaganden (proffsens händer rör sig fortare än
6 m/s vid träffen; 2,0 H/s ≈ 3,2 m/s för H = 1,6 m, alltså marginal för
glesa rutor). De kalibreras på oktobers 41 slag i S2h: alla 41 ska bli **ja**.
Johannes kan ändra domen på ett slag i listan efter analysen.

```swift
public enum SwingVerdict: String, Codable, Sendable { case swing, notSwing, uncertain }
public enum SwingCheck {
    /// series: lederna glest kring klicket, t relativt klicket. METOD MS5.
    public static func verdict(_ series: JointSeries) -> SwingVerdict
}
```

### 4.4 Träffen ur klicket

Ljudet når telefonen `d / 343` s efter träffen, där `d` är avståndet från
bollen till telefonen i meter (ljudets fart i luft vid cirka 20 °C). Golf SG
mätte cirka 9 ms framifrån på 3 m (HANDLED_PLAN §4), vilket stämmer med
3/343 = 8,7 ms. Uppställningen frågar efter avståndet (standard 3,0 m) och
manifestet skriver både klicket och `traff = klick − d/343` (METOD MS6). Ett fel
på 0,5 m i avståndet är 1,5 ms, en tredjedels ruta vid 240 bilder/s.

---

## 5. Import ur Bilder (för gamla klipp)

**Fällan.** En slowmotion ur Kamera-appen ligger i Bilder som originalfilen
(240 bilder/s, realtid) plus en justering som säger var den ska gå långsamt.
Begärs den "aktuella" versionen fås det renderade resultatet:
`PHVideoRequestOptionsVersion.current` är "the rendered output from all
previously made adjustments", medan `.original` är "the originally captured or
imported version of the asset, regardless of any edits"
([current](https://developer.apple.com/documentation/photos/phvideorequestoptionsversion/current),
[original](https://developer.apple.com/documentation/photos/phvideorequestoptionsversion/original)).
Det renderade blir en `AVComposition` med omskalad tid (eller en fil i 30
bilder/s med nedsaktningen inbakad), så att varje tid blir ungefär 8 gånger
för lång (Airtime METOD M5). Golf SG fick samma råd för PC:n: originalet, inte
en delad kopia.

**Vägen:**

1. `PhotosPicker(selection:matching: .videos, preferredItemEncoding: .current, photoLibrary: .shared())`
   ([dokumentation](https://developer.apple.com/documentation/photosui/photospicker/init(selection:matching:preferreditemencoding:photolibrary:label:))).
   Med ett bibliotek får `PhotosPickerItem.itemIdentifier` värdet (annars `nil`,
   [dokumentation](https://developer.apple.com/documentation/photosui/photospickeritem/itemidentifier)).
   Flera val på en gång (`selection: [PhotosPickerItem]`) så att oktobers fyra
   klipp går i ett svep.
2. `PHPhotoLibrary.requestAuthorization(for: .readWrite)` (iOS 14,
   [dokumentation](https://developer.apple.com/documentation/photos/phphotolibrary/requestauthorization(for:handler:)))
   och `PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)`.
3. Kontroll: `asset.mediaSubtypes.contains(.videoHighFrameRate)` ("created by
   the Slow-Mo feature in the Camera app",
   [dokumentation](https://developer.apple.com/documentation/photos/phassetmediasubtype/videohighframerate)).
   Saknas den går importen ändå vidare, men `FrameTiming` avgör.
4. Resursen: `PHAssetResource.assetResources(for: asset)` och den med
   `type == .video` ("the original video data",
   [dokumentation](https://developer.apple.com/documentation/photos/phassetresourcetype/video)),
   **inte** `.fullSizeVideo` ("a modified version").
5. `PHAssetResourceManager.default().writeData(for: resource, toFile: url, options: opts)`
   med `opts.isNetworkAccessAllowed = true` (hämtar ur iCloud vid behov) och
   `progressHandler` till vyn
   ([writeData](https://developer.apple.com/documentation/photos/phassetresourcemanager/writedata(for:tofile:options:completionhandler:)),
   [isNetworkAccessAllowed](https://developer.apple.com/documentation/photos/phassetresourcerequestoptions/isnetworkaccessallowed)).
   Filen skrivs till passets `Video/`-mapp. `writeData` kräver att filen inte
   finns.
6. `FrameTiming.analyze` på filens tider. `isSlowMotion == false` → filen tas
   bort och vyn säger "Inte slowmotion-originalet".

**Om Johannes bara ger begränsad åtkomst** och klippet inte finns bland de
valda bilderna, eller nekar: reserven är `item.loadTransferable(type: PickedMovie.self)`
som i Airtime, och samma kontroll i steg 6 fäller en omräknad fil. Vyn ber då om
full åtkomst. Rutornas tider läses alltid ur filen, aldrig ur en nominell
frekvens.

Ett importerat klipp får vy, klubba och avstånd i samma uppställning som en
inspelning. `recordedAt` är `asset.creationDate`.

---

## 6. Vision på telefonen

### 6.1 Körningen

För varje slag och fönster (glest eller tätt, §4.3):

```swift
let reader = try AVAssetReader(asset: asset)
reader.timeRange = CMTimeRange(start: CMTime(seconds: max(0, t0), preferredTimescale: 600),
                               end: CMTime(seconds: t1, preferredTimescale: 600))
let out = AVAssetReaderTrackOutput(track: videoTrack, outputSettings:
    [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange])
out.alwaysCopiesSampleData = false
reader.add(out); reader.startReading()
let request = VNDetectHumanBodyPoseRequest()           // tillståndslös, återanvänds
var k = 0
while let sb = out.copyNextSampleBuffer() {
    autoreleasepool {                                   // annars växer minnet med varje pixelbuffert
        defer { k += 1 }
        guard CMSampleBufferGetNumSamples(sb) > 0, k % stride == 0 else { return }
        let t = CMSampleBufferGetPresentationTimeStamp(sb).seconds
        let handler = VNImageRequestHandler(cmSampleBuffer: sb, orientation: exif, options: [:])
        try? handler.perform([request])
        let obs = request.results ?? []                 // [VNHumanBodyPoseObservation]
        // → PoseFrame (värden, §6.3) för varje observation; valet görs i SwingLabKit
    }
}
```

- `reader.timeRange` sätts före läsningen
  ([dokumentation](https://developer.apple.com/documentation/avfoundation/avassetreader/timerange)).
  Rutorna kommer med sina egna tider; inga rutor fylls i. Golf SG:s MediaPipe
  fick samma fönster, −2,5…+1,5 s.
- `VNImageRequestHandler(cmSampleBuffer:orientation:options:)` (iOS 14,
  [dokumentation](https://developer.apple.com/documentation/vision/vnimagerequesthandler/init(cmsamplebuffer:orientation:options:)-335k4)).
  Apple: "Use a physical device to perform your testing. Performing requests in
  Simulator may produce inaccurate results". Simulatorprovet prövar därför bara
  att anropet går och att tomt svar hanteras, inte lederna.
- `VNDetectHumanBodyPoseRequest` (iOS 14, revision 1,
  [dokumentation](https://developer.apple.com/documentation/vision/vndetecthumanbodyposerequest)).
  Den nyare `DetectHumanBodyPoseRequest` (iOS 18, Swift-struktur, async,
  [dokumentation](https://developer.apple.com/documentation/vision/detecthumanbodyposerequest))
  väljs bort: samma modell enligt allt som syns, men nyare och med mindre
  beprövad kod att kompilera blint.
- **Varje ruta avkodas** även i den glesa körningen; HEVC går inte att hoppa i
  utan nyckelbilder. Det är Vision som kostar, och den körs bara på var 8:e.
- `stride` är 1 i den täta körningen. Om S2e mäter mer än 20 ms per ruta kan
  den sättas till 2 (120 bilder/s), ett beslut för Johannes.

### 6.2 Orienteringen

Rutorna i filen är liggande (1920 × 1080) och spårets `preferredTransform`
säger hur de ska vridas. Vision får EXIF-orienteringen, så att personen står
upp när modellen ser bilden. Vision är sämre när personen "is bent over or
upside down" (WWDC20 session 10653), och en liggande person är samma problem
(antagande).

```swift
public enum Orientation {
    /// EXIF 1 (.up), 3 (.down), 6 (.right) eller 8 (.left) ur preferredTransform. METOD MS7.
    public static func exif(a: Double, b: Double, c: Double, d: Double) -> UInt32
    /// Upprätt storlek: bredd och höjd byter plats för 6 och 8.
    public static func uprightSize(width: Int, height: Int, exif: UInt32) -> (width: Int, height: Int)
    /// Visions normaliserade punkt (origo nere till vänster) → pixlar i den upprätta bilden (origo uppe till vänster).
    public static func pixels(x: Double, y: Double, uprightWidth: Int, uprightHeight: Int) -> (x: Double, y: Double)
}
```

Tabellen (METOD MS7, vedertagen avbildning, prövas i S2c-provet med en
syntetisk film med känd transform och på telefonen med klapprovet):
`(0, 1, −1, 0)` → 6 (`.right`, stående, kamerans vanliga läge);
`(0, −1, 1, 0)` → 8 (`.left`); `(1, 0, 0, 1)` → 1 (`.up`);
`(−1, 0, 0, −1)` → 3 (`.down`). Jämförs med tolerans 0,01.

Visions punkter är normaliserade 0–1 med origo nere till vänster
([Detecting Human Body Poses](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images);
WWDC20 10653: "the same lower left origin as other Vision algorithms …
relative to the pixel dimensions of your image"). Att de gäller den
**orienterade** bilden när en orientering skickas med står inte uttryckligen i
dokumentationen. Därför finns två vakter:

1. `JointSeries.orientationSuspect` i SwingLabKit: i adressen (de första 0,3 s)
   ska kroppens axel (fotledernas mitt → näsan) vara mer lodrät än vågrät
   (|Δy| > 2·|Δx|). Brister det på fler än hälften av slagen märks passet
   "orienteringen misstänkt" i vyn och i manifestet.
2. Klapprovet (§11.3, telefonprov T2): skelettet ritas över bilden vid träffen.

### 6.3 Lederna (F15)

Vision ger 19 punkter. SwingLab sparar de 13 som Golf SG använde, med Golf
SG:s namn och MediaPipes index, så att S3 kan jämföra led för led:

| SwingLab | MediaPipe | Vision `VNHumanBodyPoseObservation.JointName` |
|---|---|---|
| `nasa` | 0 | `.nose` |
| `axel_v` | 11 | `.leftShoulder` |
| `axel_h` | 12 | `.rightShoulder` |
| `armbage_v` | 13 | `.leftElbow` |
| `armbage_h` | 14 | `.rightElbow` |
| `handled_v` | 15 | `.leftWrist` |
| `handled_h` | 16 | `.rightWrist` |
| `hoft_v` | 23 | `.leftHip` |
| `hoft_h` | 24 | `.rightHip` |
| `kna_v` | 25 | `.leftKnee` |
| `kna_h` | 26 | `.rightKnee` |
| `fotled_v` | 27 | `.leftAnkle` |
| `fotled_h` | 28 | `.rightAnkle` |

Vänster och höger är personens egna: "this is the subject's right arm, not the
one on the right side of the image" (WWDC20 session 10653). Golf SG:s `LED`
(`handled_video.py`) har samma index. Övriga Vision-punkter (ögon, öron,
`neck`, `root`) sparas inte i S2.

- Punkterna hämtas med `observation.recognizedPoints(.all)` och slås upp per
  namn. "Ignore any recognized points with a confidence value of 0, because
  they're invalid" (Apple, samma sida); de sparas som saknade (`null`).
- Konfidensen sparas per led. SwingLabKit räknar en led som säker vid
  `c ≥ 0,1` och en observation som säker vid `confidence ≥ 0,6`, som Apples
  exempel (WWDC20 10653) (METOD MS8).
- **Flera personer** (grannen i bild): Vision ger en observation per person.
  SwingLabKit väljer: i första rutan den vars höfter ligger närmast bildens
  mitt i x och som är högst (`H`); sedan den vars höfters mitt ligger närmast
  föregående ruta. `PosePicker.pick(_:previous:)` på värden, testat på Linux.

```swift
public struct PoseJoint: Codable, Equatable, Sendable { public var x: Double; public var y: Double; public var c: Double }
public struct PoseFrame: Codable, Equatable, Sendable {
    public var t: Double                       // s relativt klicket
    public var pts: Double                     // s i källfilen
    public var joints: [PoseJoint?]            // 13, ordningen ovan; px i den upprätta bilden, origo uppe till vänster
    public var confidence: Double              // observationens
}
public struct JointSeries: Codable, Equatable, Sendable {
    public static let names = ["nasa", "axel_v", "axel_h", "armbage_v", "armbage_h", "handled_v", "handled_h",
                               "hoft_v", "hoft_h", "kna_v", "kna_h", "fotled_v", "fotled_h"]
    public var source: String                  // "vision-2d-r1"
    public var width: Int, height: Int         // upprätt bild, 1080 × 1920
    public var frames: [PoseFrame]
    public var orientationSuspect: Bool { get }
}
public enum PosePicker {
    public static func pick(_ candidates: [PoseFrame], previousHipMid: (x: Double, y: Double)?, width: Int) -> Int?
}
```

**Om S1 har landat** med en egen typ för ledernas tidsserie (se `docs/FORMAT.md`
och `SwingLabKit/`): använd den, och låt `JointSeries` ovan bli den typen.
FORMAT.md vinner vid krock; namnen och ordningen i tabellen är det som måste
hålla.

### 6.4 Hastighet, minne och bakgrund

- **Hastigheten** är okänd: Apple anger ingen. Ett tätt fönster är 4 s × 240 =
  960 rutor. Vid 15–25 ms per ruta (antagande) är det 15–25 s per slag och
  8–12 min för 30 slag; det glesa fönstret lägger till cirka 15 %. S2e mäter
  och skriver `msPerFrame` i manifestet.
- **Minnet:** `autoreleasepool` runt varje ruta och
  `alwaysCopiesSampleData = false`. Ett slags leder är cirka 960 × 13 × 3 tal.
- **Förgrund och återupptagbart.** Appen i bakgrunden stängs av iOS inom
  sekunder, och Vision på GPU/Neural Engine i bakgrunden är inte att lita på.
  `BGContinuedProcessingTaskRequest` (iOS 26,
  [dokumentation](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest))
  låter ett jobb som startats med en knapp fortsätta i bakgrunden, men kräver
  iOS 26 på båda telefonerna och har egna villkor för GPU. Väljs bort i S2.
  I stället: analysen går i förgrunden med skärmen på (`isIdleTimerDisabled`),
  ett slag i taget, och varje slags leder sparas så fort de är klara. Avbryts
  appen fortsätter analysen vid nästa start från första slag som saknar leder.
- Vision körs på en egen `Task.detached(priority: .userInitiated)`, aldrig på
  huvudtråden. Vyn visar "Slag 7 av 23" och en stapel.

---

## 7. Två telefoner (S2g; byggs nu eller i S6, §13)

### 7.1 Kopplingen: Network.framework

- **Multipeer Connectivity är avskrivet i iOS 27** ("Use Network Framework
  instead", [MCSession](https://developer.apple.com/documentation/multipeerconnectivity/mcsession)),
  och väljs bort.
- **Nyare `NetworkListener`/`NetworkConnection`** finns från iOS 26
  ([NetworkConnection](https://developer.apple.com/documentation/network/networkconnection)).
  Väljs bort: iOS 26 på båda telefonerna, och ny kod att kompilera blint.
- **Valt:** `NWListener` + `NWBrowser` + `NWConnection` (iOS 12–13, inte
  avskrivna, [Network](https://developer.apple.com/documentation/network)),
  med Bonjour-tjänsten `_swinglab._tcp` och `NWParameters.tcp` där
  `includePeerToPeer = true` ("enables peer-to-peer link technologies",
  [dokumentation](https://developer.apple.com/documentation/network/nwparameters/includepeertopeer))
  så att telefonerna hittar varandra även utan gemensamt wifi, och
  `NWProtocolTCP.Options.noDelay = true` (stänger av Nagle,
  [dokumentation](https://developer.apple.com/documentation/network/nwprotocoltcp/options/nodelay))
  så att pingen inte väntar. Apples exempel för samma sak:
  [Building a custom peer-to-peer protocol](https://developer.apple.com/documentation/network/building-a-custom-peer-to-peer-protocol).
- Info.plist kräver `NSLocalNetworkUsageDescription` och `NSBonjourServices`
  med `_swinglab._tcp` (Apple, [Multipeer Connectivity](https://developer.apple.com/documentation/multipeerconnectivity),
  samma krav för Bonjour i Network). Inget entitlement behövs för Bonjour
  (multicast-entitlementet gäller bara egen multicast, antagande).
- **Roller:** en telefon *styr* (lyssnar och visar knappen), övriga *följer*
  (söker och ansluter). Protokollet tillåter flera följare, eftersom en tredje
  kamera är på tal (grenen `s6-tredje`). Följaren väljer sin egen vy.

**Meddelanden** (SwingLabKit, testbara på Linux): varje meddelande är JSON med
fyra bytes längd före (big-endian), eftersom TCP är en ström.

```swift
public enum LinkMessage: Codable, Equatable, Sendable {
    case hello(role: String, model: String, app: String)
    case ping(id: Int, t0: Double)                         // styrande telefonens värdklocka
    case pong(id: Int, t0: Double, t1: Double, t2: Double) // följarens klocka vid mottagning och svar
    case start(passID: String, series: Int)
    case stop(series: Int)
    case recorded(series: Int, startHost: Double, frameRate: Double, clicks: [Click])
    case status(recording: Bool, freeGB: Double, pressure: String)
}
public enum Wire {
    public static func frame(_ m: LinkMessage) throws -> Data
    public struct Reader { public init(); public mutating func feed(_ d: Data) throws -> [LinkMessage] }
}
```

### 7.2 Klockorna (METOD MS9)

Värdklockan är `CMClock.hostTimeClock.time.seconds` på båda telefonerna (samma
klocka som `startPTS` räknas om till, §2.1). Pingen är NTP:s fyra tider:
`θ = ((t1 − t0) + (t2 − t3)) / 2`, `δ = (t3 − t0) − (t2 − t1)`.

```swift
public struct PingSample: Codable, Equatable, Sendable { public var t0, t1, t2, t3: Double }
public struct ClockOffset: Codable, Equatable, Sendable {
    public var offset: Double        // följarens klocka − styrande
    public var uncertainty: Double   // största δ / 2 bland de använda proven
    public var samples: Int
}
public enum ClockSync {
    /// Medianen av θ bland den fjärdedel av proven som har lägst δ. METOD MS9.
    public static func estimate(_ s: [PingSample]) -> ClockOffset?
    /// Drift i ppm mellan två mätningar.
    public static func drift(_ a: ClockOffset, at ta: Double, _ b: ClockOffset, at tb: Double) -> Double
}
```

30 ping med 20 ms mellanrum vid anslutning, före varje start och efter varje
stopp. Felet är högst största δ / 2 bland de använda proven, eftersom varje
provs θ ligger inom δ/2 från den sanna förskjutningen (antagande: några ms över wifi eller
peer-to-peer). Pingen behövs bara som förhandsvärde: den slutliga synken är
klicket.

### 7.3 Start, stopp och klicket som synk (METOD MS10)

1. Styrande trycker Start → `start` till alla följare, som startar sin egen
   inspelning direkt. Starten behöver inte vara samtidig: serierna överlappar
   med sekunder, och klicken synkar.
2. Stopp på samma sätt. Varje telefon hittar sina klick (§4) och följaren
   skickar `recorded` med klicken och `startHost` (filens noll på dess
   värdklocka).
3. Styrande parar klicken (`ClickPairing`, ur Golf SG:s `para()`): sök
   förskjutningen `d` i steg om 5 ms som parar flest klick inom 30 ms, förfina
   med medianen av de parade resterna. Med pingen söks bara `prior ± 0,25 s`;
   utan ping `± 10 s`. Parningen är **osäker** med färre än 3 par utan ping
   (1 med), eller när ett annat `d` (minst 60 ms bort) parar lika många; då
   visas den som osäker och PC:n parar om (METOD MS10).
4. Ljudets väg rättas: `träff_A = klick_A − d_A/343`, och bildernas förskjutning
   mellan telefonerna är skillnaden i träff. Avstånden står i uppställningen.
5. Resultatet skrivs i den styrande telefonens `par.json` (§8): par, rester och
   median av |rest| som kvalitet. Finjusteringen på ledernas fart görs på PC:n
   i S6 (research 2 §2).

```swift
public struct ClickPairing: Codable, Equatable, Sendable {
    public var offset: Double                  // s: b ≈ a + offset
    public var pairs: [Pair]
    public var count: Int                      // flest parade i sökningen
    public var secondBestOffset: Double?       // bästa d minst 2·tolerance bort (marginalen)
    public var secondBestCount: Int
    public var uncertain: Bool                 // count < 3 utan prior (1 med), eller secondBestCount ≥ count
    public struct Pair: Codable, Equatable, Sendable { public var a: Int; public var b: Int; public var residual: Double }
    public static func pair(_ a: [Double], _ b: [Double], prior: Double?, priorWindow: Double = 0.25,
                            search: Double = 10, step: Double = 0.005, tolerance: Double = 0.03) -> ClickPairing
    public static func soundDelay(distance: Double, speed: Double = 343) -> Double
}
```

### 7.4 Om en telefon tappar

Varje telefon spelar in för sig. Kopplingen bär bara kommandon och klicktider,
aldrig video (dataregeln), så ett tapp kostar ingen data:

- **Tapp under inspelning:** följaren fortsätter tills någon trycker stopp på
  den, eller tills kopplingen kommer tillbaka och `stop` når fram. Styrande
  visar en röd rad "Följaren tappad". `NWBrowser` söker vidare och ansluter
  igen av sig själv.
- **Ingen ping efter stopp:** pingen före start används, och sökningen i steg 3
  vidgas till `± 0,5 s`.
- **Ingen koppling alls:** varje telefon gör sitt paket med samma pass-id
  (Johannes skriver samma id, eller PC:n parar på tid), och PC:n parar klicken
  med samma algoritm. Inget går förlorat.
- **Lokalt nätverk nekat:** `NWBrowser` hamnar i `.waiting` med ett fel; vyn
  ber Johannes slå på "Lokalt nätverk" för SwingLab i Inställningar.

---

## 8. Lagring och exportpaketet

### 8.1 Mapparna (F12)

```
Application Support/SwingLab/
  pass.json                      index: id, datum, antal slag, status per pass
  Pass/<pass-id>/
    pass.json                    passets tillstånd (PassState, Codable): serier, klick, slag, domar
    Video/<serie>.mov            egna inspelningar och importerade original   (utanför backupen)
    Klipp/s01.mov …              −2,5…+1,5 s kring varje slag                  (utanför backupen)
    Leder/s01.json …             JointSeries per slag
    ljusprov.json
  AttJobbaPa/att_jobba_pa-<datum>.json
Documents/Export/swinglab-<pass-id>-<vy>.zip   synlig i Filer och i Apple Devices över kabel (utanför backupen)
```

- `isExcludedFromBackup = true` sätts på `Video/`, `Klipp/` och `Export/`
  (Airtime `Store.swift`): videon är stor och går att spela in igen.
- Pass-id: `yyyyMMdd-HHmmss` i lokal tid vid passets start. Inga namn eller
  e-post i någon fil.
- `pass.json` som inte går att läsa skrivs aldrig över: den flyttas till
  `pass-unreadable-<tid>.json` och vyn säger det (Airtime).
- **Originalen** tas bort efter export bara om Johannes slår på "Spara bara
  klippen" (§13).

### 8.2 Klippen

`AVAssetExportSession(asset:presetName: AVAssetExportPresetPassthrough)` med
`timeRange = [klick − 2,5, klick + 1,5]` och `export(to: url, as: .mov)`
(async; `@backDeployed` till iOS 13,
[dokumentation](https://developer.apple.com/documentation/avfoundation/avassetexportsession/export(to:as:isolation:))).
Passthrough kodar inte om. Var klippet exakt börjar (nyckelbilden före, eller en
redigeringslista) är inte dokumenterat. Därför mäts klicket om **i klippet**
med samma algoritm (det klick som ligger närmast 2,5 s), och manifestet
skriver `klickIKlipp` ur klippet självt. PC:n använder bara klippets egna tider.
Skiljer det mer än 10 ms från väntat märks slaget.

### 8.3 Paketet (F13)

En zip per telefon och pass: `swinglab-<pass-id>-<dtl|fo>.zip`.

```
manifest.json
enhet.json            telefonens modell, iOS, alla kameraformat (CameraFormat), valt index
ljusprov.json         LightCheck, om provet gjordes
par.json              bara på styrande telefon med följare: ClickPairing per serie och ClockOffset
slag/s01.json …       ett slag: klicket, träffen, domen, lederna (JointSeries)
klipp/s01.mov …       om "Med klipp" (standard)
```

Två nivåer, som Idunns "Med ljudklipp": **med klipp** (standard, för PC:ns
MediaPipe i S3/S5) och **utan klipp** (några MB, går att dela var som helst).

**manifest.json** (format `swinglab-paket/1`; flyttas till `docs/FORMAT.md` när
S1 landat, och FORMAT.md vinner vid krock):

```json
{
  "format": "swinglab-paket/1",
  "skapad": "2026-10-24T15:42:10+02:00",
  "app": {"version": "0.1.0", "bygge": "12"},
  "pass": "20261024-153012",
  "telefon": {"modell": "iPhone18,1", "ios": "26.1", "roll": "ensam|styr|folj"},
  "vy": "dtl|fo",
  "avstand_m": 3.0,
  "spelhand": "hoger|vanster",
  "serier": [{
    "nr": 1, "kalla": "inspelning|bilder", "klubba": "j7", "start_lokal": "…",
    "start_vard_s": 81234.512345, "langd_s": 182.4,
    "rutor": {"antal": 43776, "natets_hz": 240, "snitt_hz": 239.9, "saknas": 0.0004, "storsta_hal_s": 0.0083},
    "format": {"index": 31, "bredd": 1920, "hojd": 1080, "synfalt": 69.4, "binnat": true},
    "exponering": {"tid_s": 0.0005, "iso": 1250, "behov_iso": 1250, "brist_ev": 0, "lins": 0.62, "distorsionsratt": true},
    "ljud": {"hz": 48000, "kanaler": 1, "kodek": "aac", "mikrofon": "builtInMic"},
    "tryck": "nominal|fair|serious|critical",
    "orientering": 6, "orientering_misstankt": false
  }],
  "slag": [{
    "id": "s01", "serie": 1, "klick_s": 12.3456, "styrka": 88.1, "traff_s": 12.3369,
    "dom": "sving|inte_sving|osaker", "andrad_av_johannes": false,
    "klipp": "klipp/s01.mov", "klick_i_klipp_s": 2.5021, "leder": "slag/s01.json",
    "par": {"telefon": "fo", "slag": "s01", "rest_ms": 1.2}
  }],
  "vision": {"revision": 1, "ms_per_ruta": 18.4, "glest_steg": 8, "tatt_steg": 1},
  "matt": null
}
```

Tiderna är sekunder i serien (`klick_s`, `traff_s`) eller i klippet
(`klick_i_klipp_s`). `traff_s = klick_s − avstand_m/343`. `matt` fylls med
S1:s mått per slag när S1 har landat; annars `null` och PC:n räknar.

**slag/s01.json:** `JointSeries` (§6.3): `t` relativt klicket, `pts` i
serien, `x`/`y` i pixlar i den upprätta bilden (1080 × 1920, origo uppe till
vänster, som Golf SG:s `bild` ur MediaPipe), `c` per led, `null` för saknad.
Tal avrundas till 0,1 px och 4 decimaler i tid. Kodas som arrayer per ruta, inte
ett objekt per led, för storlekens skull (cirka 300 kB per slag, antagande).

### 8.4 Zip-skrivaren (SwingLabKit)

```swift
public final class ZipWriter {
    public init(url: URL) throws                               // skapar filen
    public func add(name: String, data: Data) throws           // liten fil ur minnet
    public func addFile(name: String, from source: URL) throws // stor fil: CRC i ett första svep, sedan kopiering i 1 MB-bitar
    public func finish() throws                                // katalogen och slutposten
}
```

- Bara metoden 0 (lagrad, ingen komprimering): video är redan komprimerad,
  och DEFLATE finns inte i Foundation på Linux (Idunns `ZipArchive` lagrar där
  av samma skäl). Samma bitar på Linux och telefonen.
- Huvudena som i Idunns `ZipArchive` (version 20, flaggan 0x0800 för UTF-8,
  DOS-tid i UTC). CRC-32 med egen tabell (IEEE 0xEDB88320).
- Ingen zip64: över 4 GB eller 65 535 filer kastar `ZipWriter.Error.tooLarge`,
  och vyn föreslår "utan klipp". 30 slag × 2 telefoner är långt under.
- `FileHandle(forWritingTo:)`, `write(contentsOf:)`, `read(upToCount:)` finns
  i Foundation på både Linux och iOS.
- Paketet skrivs till `Documents/Export/` och delas med `ActivitySheet`
  (Idunn). Vart det går väljer Johannes (BESLUT B3): AirDrop, Filer, iCloud
  Drive, eller Apple Devices över kabel till Windows.

### 8.5 Vägen tillbaka: `att_jobba_pa.json` (F14)

S5 äger innehållet. S2 bygger bara mottagningen:

- Knappen "Hämta Att jobba på" öppnar `.fileImporter(isPresented:allowedContentTypes: [.json], allowsMultipleSelection: false)`.
  Den valda URL:en läses inom `startAccessingSecurityScopedResource()` /
  `stopAccessingSecurityScopedResource()` och kopieras till `AttJobbaPa/`.
- SwingLabKit kontrollerar bara att `format` börjar med `swinglab-att-jobba-pa/`
  och att filen är giltig JSON; resten visas som den är tills S4/S5 byggt vyn.
- Att dela direkt från PC:n till appen ("Öppna i SwingLab" via
  `CFBundleDocumentTypes` och `onOpenURL`) väntar till S5; det kräver en egen
  filtyp och fler Info.plist-nycklar.

---

## 9. Vad som bor var

**SwingLabKit, ny modul `Capture`** (bara Foundation, testad på Linux). S1 äger
`Package.swift`: lägg till målet `Capture` och testmålet `CaptureTests` där,
efter S1 landat eller med rebase. Filerna:

| Fil | Innehåll | Avsnitt |
|---|---|---|
| `ClickDetector.swift` | `Click`, `ClickDetector.detect/merge` | §4.1–4.2 |
| `SwingCheck.swift` | `SwingVerdict`, `SwingCheck.verdict` | §4.3 |
| `FrameTiming.swift` | `FrameTiming.analyze` | §3.2 |
| `CameraFormat.swift` | `CameraFormat`, `FormatChoice.choose` | §2.2 |
| `Exposure.swift` | `ExposurePlan`, `Exposure.plan` | §2.3 |
| `Flicker.swift` | `Flicker.depth/check`, `LightCheck` | §2.7 |
| `Orientation.swift` | `Orientation.exif/uprightSize/pixels` | §6.2 |
| `Pose.swift` | `PoseJoint`, `PoseFrame`, `JointSeries`, `PosePicker` | §6.3 |
| `Link.swift` | `LinkMessage`, `Wire` | §7.1 |
| `ClockSync.swift` | `PingSample`, `ClockOffset`, `ClockSync` | §7.2 |
| `ClickPairing.swift` | `ClickPairing` | §7.3 |
| `Package.swift` (i modulen: `PackageManifest.swift`) | manifestets typer, `PassState` | §8 |
| `ZipWriter.swift` | `ZipWriter` | §8.4 |

**App/** (tunt; bara det som kräver Apples ramverk):

| Fil | Innehåll |
|---|---|
| `SwingLabApp.swift` | `@main`, `Store` i miljön, mörkt tema |
| `Store.swift` | mapparna (§8.1), `PassState` läs och skriv |
| `Camera.swift` | session, format, exponering, fokus, vitbalans, inspelning, `startPTS`, tryck |
| `RecordView.swift` | förhandsbilden, hjälplinjerna, ljuskortet, start/stopp, kvittot |
| `MediaReader.swift` | §3.1 |
| `PhotoImport.swift` | §5 |
| `PoseRunner.swift` | §6.1 |
| `Analysis.swift` | serie → klick → glest → dom → tätt → klipp, återupptagbart |
| `Export.swift` | paketet, `ActivitySheet`, `fileImporter` |
| `Link.swift` | §7, bara i S2g |
| `PassView.swift` | listan över pass och slag, domen per slag, miniatyren med skelettet |

**Prov/** (simulatorprovet, §10.2).

Formspråket (färger, piktogram) bestäms på grenen `design`. S2 bygger
funktionen med systemets standardvyer i mörkt läge och lite text; S4 ger den
formen.

---

## 10. Bygget utan Mac

### 10.1 project.yml

Som Airtimes, med: `name: SwingLab`, `deploymentTarget: iOS: "18.2"` (F5),
paketet `SwingLabKit` med S1:s produkter och `Capture`, `PRODUCT_BUNDLE_IDENTIFIER: se.birdiebook.swinglab`,
`SWIFT_VERSION: "5.0"` (som Airtime och Idunn: Swift 6:s stränga
samtidighetskontroll i appen ger kompileringsfel som inte syns på Linux),
`TARGETED_DEVICE_FAMILY: "1"`, en app-ikon i `App/Assets.xcassets/AppIcon.appiconset/icon-1024.png`
(utan ikon vägrar App Store Connect bygget; en enfärgad platshållare räcker tills
`design` har en), och Info.plist-nycklarna:

| Nyckel | Värde | Varför |
|---|---|---|
| `CFBundleDisplayName` | SwingLab | BESLUT B8 |
| `NSCameraUsageDescription` | "SwingLab filmar svingen i slowmotion. Videon stannar på telefonen." | kameran; saknas den kraschar appen vid frågan |
| `NSMicrophoneUsageDescription` | "SwingLab spelar in ljudet för att hitta träffens klick. Ljudet stannar på telefonen." | ljudet (§2.5) |
| `NSPhotoLibraryUsageDescription` | "SwingLab hämtar slowmotion-originalet ur Bilder för att mäta svingen." | §5 |
| `NSLocalNetworkUsageDescription` | "SwingLab kopplar ihop två telefoner som filmar samma sving." | §7 |
| `NSBonjourServices` | `[_swinglab._tcp]` | §7 |
| `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace` | true | `Documents/Export` i Filer (Idunn) |
| `UISupportedInterfaceOrientations` | `[UIInterfaceOrientationPortrait]` | låst stående (§2.2) |
| `ITSAppUsesNonExemptEncryption` | false | annars fastnar bygget på exportfrågan (Airtime) |
| `UILaunchScreen` | `{}` | Airtime |

Inga entitlements och inga bakgrundslägen.

Ett andra mål, `SwingLabProv` (`bundle.unit-test`, `TEST_HOST` = appen,
`CODE_SIGNING_ALLOWED: "NO"`), och ett eget schema `SwingLabProv`, precis som
Idunns `IdunnProv`, så att schemat `SwingLab` som TestFlight arkiverar är
orört.

### 10.2 Kompileringsprovet och simulatorprovet (F6)

`.github/workflows/kompilera.yml`, på `runs-on: macos-latest`:

```yaml
on:
  push:
    paths: ["App/**", "Prov/**", "SwingLabKit/**", "project.yml", ".github/workflows/kompilera.yml"]
  workflow_dispatch:
concurrency: { group: kompilera-${{ github.ref }}, cancel-in-progress: true }
jobs:
  kompilera:
    if: github.repository == 'birdiebook/swinglab'
    runs-on: macos-latest
    timeout-minutes: 40
    steps:
      - uses: actions/checkout@v4
      - uses: maxim-lobanov/setup-xcode@v1
        with: { xcode-version: latest-stable }
      - run: brew install xcodegen && xcodegen generate
      - name: Bygg som TestFlight, utan signering
        run: |
          set -o pipefail
          xcodebuild build -project SwingLab.xcodeproj -scheme SwingLab -configuration Release \
            -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO 2>&1 | tee bygg.log
      - name: Simulatorprovet
        run: |
          set -o pipefail
          UDID=$(xcrun simctl list devices available -j | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; print(next(x['udid'] for k,v in d.items() if 'iOS' in k for x in v if x['name'].startswith('iPhone')))")
          xcodebuild test -project SwingLab.xcodeproj -scheme SwingLabProv -destination "id=$UDID" 2>&1 | tee prov.log
      # + sammanfattningen på grenen ci-resultat som i test.yml: de första 30 raderna med "error:",
      #   "** BUILD SUCCEEDED/FAILED **" och provets "Executed N tests, with M failures".
```

- **Kostnad:** inga pengar. GitHubs standardmaskiner, macOS inräknat, är
  gratis för publika repon (BESLUT B7; Airtime BESLUT B9 bygger på samma). Ingen
  Codemagic-minut. Arbetssättets regel om prov i simulatorn "bara när sparad
  data rörs" kom av att minuterna kostade; här kostar provet bara väntan.
- **Gränsen:** TestFlight-bygget startas bara när `kompilera` är grönt för
  samma commit, efter Johannes ja, högst ett per dag (CLAUDE.md).

**Simulatorprovet** (`Prov/SwingLabProv.swift`, XCTest) prövar App-koden mot
riktiga AVFoundation-anrop, med en film som provet själv skriver:

1. `SyntheticMovie.write(...)` med `AVAssetWriter`: H.264, 270 × 480 upprätt
   (lagrat 480 × 270 med `transform` = 90°), 240 bilder/s på rutnätet men var
   tredje ruta utelämnad, en vit ruta vid 1,000 s och 2,200 s och i övrigt grå,
   och ljud med ett klick (en ansats på 5 ms brus) på samma tider. Två
   varianter: ljud som LPCM och som AAC.
2. `MediaReader.frameTimes` → `FrameTiming`: rutnätet 240, saknas ≈ 1/3.
3. `MediaReader.geometry` → `Orientation.exif` = 6, upprätt 270 × 480.
4. `MediaReader.audio` → `ClickDetector`: två klick, inom 1 ms (LPCM) och 3 ms
   (AAC) från 1,000 och 2,200. Prövar omsamplingen till 48 kHz mono och AAC:s
   redigeringslista.
5. `MediaReader.luma`: de vita rutorna ligger på klicktiderna inom en ruta.
   Prövar att bild och ljud läses på samma tidslinje.
6. Klippet: passthrough-export av [0,5, 2,0] s, klicket mätt i klippet stämmer
   med den vita rutan i klippet inom en ruta.
7. `PoseRunner` på klippet: inga observationer, inget fel, en `JointSeries`
   med alla leder `null`.
8. Paketet: ett påhittat pass packas, och zip-filen läses tillbaka med en liten
   katalogläsare i provet (namn, storlek, CRC).
9. (S2g) `NWListener` och `NWConnection` på `127.0.0.1` utan Bonjour:
   `hello` och tio `ping`/`pong` går fram, `ClockSync.estimate` ger |θ| < 5 ms.

Det provet **inte** kan: kameran (finns inte i simulatorn), Visions leder,
Bilder, två telefoner, värmen och verkligt ljus. Det är §11.3.

### 10.3 TestFlight

`.github/workflows/testflight.yml` kopieras från Airtime med
`if: github.repository == 'birdiebook/swinglab'`, `fetch-signing-files "se.birdiebook.swinglab"`
och `--project "SwingLab.xcodeproj" --scheme "SwingLab"`. Johannes del första
gången (README, som Airtime): appen i App Store Connect (namnet "SwingLab –
Golf Swing Analysis", BESLUT B8), den interna testgruppen med automatisk
distribution, och de fyra hemligheterna i repot.

---

## 11. Metod, provning och risker

### 11.1 METOD-förslag (flyttas till docs/METOD.md med koden)

| Id | Vad | Status |
|---|---|---|
| MS1 | Formatvalet (§2.2) | antagande |
| MS2 | Exponeringsplanen: ISO-behov, EV-brist, gränserna good/marginal/tooDark (§2.3), och tabellen över belysning med K = 12,5 | räkning: fysik + antagande |
| MS3 | Ljusprovet: flimmer som anpassad sinus på rutornas tider, gränserna 3/10 %, 1/5 % tappade rutor, ljushet 0,20–0,60 (§2.7) | antagande |
| MS4 | Klickalgoritmen med konstanterna 0,002 s, 25, 0,5 s, 0,02 s, 0,5, och 30 s-bitar (§4.1–4.2) | mätt i Golf SG (41 av 41, HANDLED_PLAN §3); bitarna antagande |
| MS5 | Svingdomen: 2,0 H/s, fönstren, 60 % (§4.3) | antagande, kalibreras på oktobers 41 slag |
| MS6 | Träffen = klick − avstånd/343 (§4.4) | fysik; 9 ms på 3 m mätt i Golf SG |
| MS7 | Orienteringen ur transformen (§6.2) | vedertagen; prövas i simulatorn och på telefonen |
| MS8 | Konfidensgränserna 0,1 per led och 0,6 per observation (§6.3) | Apples exempel (WWDC20 10653) |
| MS9 | Klockan: NTP-formeln, fjärdedelen med lägst δ (§7.2) | standard (NTP) + antagande |
| MS10 | Parningen: 5 ms steg, 30 ms tolerans, ± 0,25 / 10 s (§7.3) | Golf SG `para()` (mätt), fönstren antagande |

### 11.2 Det som provas på Linux (SwingLabKit, `swift test`)

Alla tester bär påhittad data (CLAUDE.md, dataregeln):

- `ClickDetector`: en impuls i prov k ger ansatsen k − 47 vid 48 kHz; två
  klick 0,4 s isär blir ett; brus utan klick ger inget; bitar med överlapp ger
  samma klick som hela signalen när klicket ligger i överlappet, 13 prov in i en
  bit eller i en bits sista prov (en bit kastar klick närmare än 0,02 s +
  fönstret från en inre bitgräns, METOD MS4).
  **Paritet med Python:** signalen byggs av ett recept båda språken kan följa
  (LCG `x = (1103515245·x + 12345) mod 2³¹`, frö 1, brus ±0,001, klick som
  10 prov med amplitud 0,5 på kända prov), och de väntade talen räknas med Golf
  SG:s `klick()` och läggs som fixtur i testerna (`ClickParity.json`, bara tal
  ur receptet). Ansatsens prov ska vara exakt lika, styrkan inom 0,1 %.
- `FrameTiming`: jämnt 240, 240 med var tredje borta, 30 bilder/s (inte
  slowmotion), en enda ruta.
- `FormatChoice`: påhittade formatlistor med 120/240, binnat eller inte, olika
  synfält, 10-bitars; inget 240 → bästa 120; tom lista → `nil`.
- `Exposure.plan`: ISO aldrig utanför gränserna, tiden aldrig under
  `minExposure`, rätt dom vid offset 0, −1 och −3 EV.
- `Flicker.depth`: en sinus på 100 Hz med 20 % djup på oregelbundna tider ger
  0,20 ± 0,01; konstant ljus ger < 0,005.
- `Orientation`: de fyra transformerna, storleken, och punkten (0,5; 0,9) →
  (540, 192) i 1080 × 1920.
- `PosePicker`, `SwingCheck` (en påhittad sving med topp och snabba händer vid
  noll ger `.swing`; samma med stilla händer ger `.notSwing`; saknade leder ger
  `.uncertain`), `JointSeries.orientationSuspect` (liggande kropp).
- `Wire`: meddelanden delade på godtyckliga ställen i strömmen kommer fram
  hela; för lång längd ger fel.
- `ClockSync`: påhittade ping med känt θ och slumpmässig asymmetrisk fördröjning
  ger θ inom `uncertainty`.
- `ClickPairing`: två listor med känd förskjutning, ett extra klick i varje och
  ett saknat; med och utan prior.
- `ZipWriter`: en liten och en stor fil (5 MB) skrivs och läses tillbaka med
  en katalogläsare i testet; CRC mot känt värde ("123456789" → 0xCBF43926).
- Manifestet: kodas och avkodas, nycklarna som i §8.3.

### 11.3 Det som bara går att prova på telefonen — Johannes på 5 minuter

| Prov | Gör | Ser | Tid |
|---|---|---|---|
| T1 Ljuset | Öppna SwingLab där passet ska vara, ge kamera och mikrofon, tryck Ljusprov | ISO-raden, flimret och "240 bilder/s, 0 % tappade" | 1 min |
| T2 Klapprovet | Stå 3 m bort i bild, lyft **vänster** hand, klappa tre gånger, spela in 10 s | Tre klick hittade; skelettet över klappbilden; vänster hand i vänsterfärgen; rutan där händerna möts ligger inom 2 rutor från klicket | 2 min |
| T3 Importen | Hämta IMG_1050 ur Bilder (oktober, framifrån) | 14 slag, "154 bilder/s" och domen "sving" på alla | 1 min |
| T4 Exporten | Exportera T3:s pass utan klipp till Filer | Zip-filen i Filer → SwingLab → Export | 1 min |

Det som bara telefonen visar: formaten och `maxISO` (enhet.json), tappade rutor
i verklig inspelning, flimret i lokalen, Visions leder, hastighet och
orientering, vänster/höger, Bilder-importen med iCloud, värmen över ett helt
pass, mikrofonen och, i S2g, kopplingen mellan två telefoner med frågan om
lokalt nätverk.

### 11.4 Risker

| # | Risk | Vad den kan fälla | Förebyggs |
|---|---|---|---|
| R1 | Kompileringsfel i App/ | TestFlight-bygget, en dag | `kompilera.yml` (§10.2) före varje TestFlight; `SWIFT_VERSION 5.0`; signaturerna i specen är lästa ur Apples dokumentation |
| R2 | Objective-C-undantag (krasch) från ogiltiga värden: bildtid, ISO, exponeringstid, linsläge, vitbalans, `setOutputSettings`, `activeMaxExposureDuration`, HDR utan stöd, `focusPointOfInterest` utan stöd, in- eller utgång utan `canAdd` | appen kraschar på telefonen | alla tal går genom SwingLabKit med gränserna (testat); `isXSupported` före varje inställning; `setOutputSettings` används inte |
| R3 | `CMTime(value: 1, timescale: 240)` finns inte exakt i formatets intervall | krasch när kameran öppnas | `range.minFrameDuration` ur intervallet (§2.2) |
| R4 | Info.plist saknar en nyckel | krasch vid frågan om kamera, mikrofon eller Bilder; tyst fel för lokalt nätverk | tabellen §10.1; simulatorprovet startar appen |
| R5 | Slowmotion ur Bilder kommer omräknad | tiderna 8 gånger för långa | `PHAssetResource` `.video` (§5) och `FrameTiming.isSlowMotion` vägrar |
| R6 | Visions koordinater i fel rum (orientering) eller vänster/höger förväxlat | alla mått fel utan att det syns | `Orientation` testad; `orientationSuspect`; T2; S3 jämför mot MediaPipe |
| R7 | Tappade rutor i egen inspelning | fart och faser fel | rutornas egna tider genom hela kedjan; kvittot efter varje serie; Ljusprovet; trycket loggat; F1 omprövas över 1 % |
| R8 | Grannens klick, röster | falska slag | svingdomen (§4.3); Johannes kan ändra domen |
| R9 | Bluetooth-mikrofon | klicket förskjutet hundratals ms | kontrollen av `builtInMic` (§2.5) |
| R10 | För mörkt eller flimmer | suddiga eller flimrande rutor, sämre leder | Ljusprovet; "för mörkt" i EV före passet |
| R11 | Värme under ett långt pass | lägre frekvens eller avbrott | `systemPressureState` loggas och varnar |
| R12 | Disken full | inspelningen stoppas | `minFreeDiskSpaceLimit`, kontroll före start, "Spara bara klippen" |
| R13 | Stor zip i minnet | appen stängs av iOS | `ZipWriter` strömmar till disk |
| R14 | Analysen avbryts | förlorat arbete | sparas per slag, återupptas (§6.4) |
| R15 | Passthrough-klippet börjar före begärd tid | fel tider i paketet | klicket mäts om i klippet (§8.2) |
| R16 | Signering, ny bundle-id, saknad ikon | uppladdningen | Johannes del i README; platshållarikon; `--create` i `fetch-signing-files` (Airtime) |
| R17 | Airtimes TestFlight-väg i Actions är oprövad | första bygget | prövas i S2a med det minsta skalet; misslyckas den är Codemagic reserven (Idunns väg, kostar minuter) |
| R18 | Riktig data i det publika repot | dataregeln | provets film genereras; Kit-testerna bär påhittade tal; `.gitignore` stänger ute video och zip |

---

## 12. Etapperna

Varje etapp landar för sig, med grönt i `test.yml` (Linux) och, när App/ rörs,
i `kompilera.yml`. Bandet i PLAN.md får S2a… när Johannes godkänt uppdelningen.
Läs §9 för filerna och §11.2 för testerna.

### S2a — Byggkedjan och skalet

- `project.yml` (§10.1), `App/SwingLabApp.swift` med en tom startvy ("SwingLab",
  knapparna Nytt pass, Hämta ur Bilder, Hämta Att jobba på, avstängda),
  ikonen, `kompilera.yml` (§10.2) med de första stegen i simulatorprovet som
  inte kräver senare etapper (provmålet startar appen), `testflight.yml`
  (§10.3), README:s "Första gången" (som Airtime).
- F1–F15 förs in i `docs/BESLUT.md` som B15–B29. Det Johannes sagt ja till
  gäller (B20, B21); det som är Johannes beslut och obesvarat väntar (B16
  slutartiden, §13.3; B26 originalen, §13.5); övriga är arkitektens tekniska
  val och prövas, och omprövas efter telefonproven (§11.3).

**Klart när:** `kompilera` är grönt på GitHub, Johannes har gjort sin del i
README, och efter hans ja ligger ett bygge i TestFlight som öppnar startvyn.

### S2b — SwingLabKit `Capture`: klicket, tiderna och värdena

Bara Linux. Kan byggas parallellt med S2a (egna filer). Typerna i §9 för
klicket, tiderna, formatet, exponeringen, ljusprovet, orienteringen, lederna och
svingdomen, med testerna i §11.2 och paritetsfixturen för klicket
(`tools/pc/klick.py`, `tools/pc/klickljud.py`). `ClockSync` och `ClickPairing`
byggs redan här, eftersom två telefoner ingår i S2 (Johannes 2026-10-22); bara
nätverkskoden (`Link`, `Wire`) väntar till S2g. `ZipWriter` och manifestets
typer hör till S2f, `PassState` till S2c (med `Store.swift`).

**Klart när:** `swift test` grönt, klickets paritet exakt på ansatsens prov,
och `METOD MS1–MS10` står i docs/METOD.md.

### S2c — Inspelningen

`Camera.swift`, `RecordView.swift`, `MediaReader.swift`, Ljusprovet (§2), kvittot
efter varje serie (antal rutor, frekvens, tappade, filstorlek per minut,
trycket), `Store.swift` och `PassState`, uppställningen (vy, klubba, avstånd,
spelhand). Simulatorprovets steg 1–5 (§10.2). `MediaReader.audio` klipper ljudet
exakt vid `ClickDetector.segments`-proven (30 s med 1 s överlapp, räknat i prov
från filens första ljudprov) och anger inre gränser till `detect`, så att PC:ns
bitar får samma medianer och samma klick.

**Klart när:** `kompilera` grönt med provet, och på telefonen: T1 visar 240
bilder/s och tappade rutor, och en serie med tre klapp ger tre klick i kvittot.

### S2d — Import ur Bilder

`PhotoImport.swift` (§5), samma kvitto som en inspelning.

**Klart när:** T3: oktobers fyra klipp importerade i ett svep, alla med
`isSlowMotion`, och 41 klick (inklusive eventuella falska, som S2e sållar).

### S2e — Slagen och lederna

`PoseRunner.swift`, `Analysis.swift` (§4.3, §6), klippen (§8.2), listan över
slag med domen och miniatyren vid träffen med skelettet ritat, mätt
`msPerFrame`. Simulatorprovets steg 6–7.

**Klart när:** T2 godkänt (vänster rätt, orienteringen rätt, klappen inom 2
rutor från klicket), och oktobers 41 slag har domen "sving" och leder, med 0
falska slag. Avviker domen kalibreras MS5 här, med siffrorna i METOD.

**Byggt (grenen `s2e`).** SwingLabKit `Capture/Shots.swift`: `ShotRecord` (slagen i
`PassState.shots`, id:n ges en gång), `ShotPlan` (ordningen: domen på alla, sedan
leder och klipp slag för slag; fönstren kapade vid filen; återupptagbart ur
`pass.json`), `PoseSource` (protokollet för Vision-steget), `PoseTrack` (personen
genom serien med `PosePicker`, rutor utan person behålls), `ClipCheck` (klicket i
klippet, 10 ms), `VisionStats` (`msPerFrame`), `ImpactOverlay` (linjerna vid
träffen) och `ShotRow` (listans rader som värden). App: `PoseRunner.swift`
(`VisionPoseSource`), `Analysis.swift` (stegen, klippen, miniatyren),
`PassView.swift` (passen i startvyn, slagen med domen, miniatyren och "Analyze"
med förloppet). Domen ändras med en meny på raden. METOD MS12.

**Vad som provas var:**

| Var | Vad |
|---|---|
| Linux (`CaptureTests/SlagTests`) | slagen ur klicken och id:n, ordningen och återupptagningen, Johannes ändrade dom, fönstren, personvalet och domen genom en serie med en granne i bild, rutor utan person, Visions punkter till pixlar, avrundningen, klippets kontroll, `msPerFrame`, linjerna vid träffen, listans rader, ett gammalt `pass.json` utan slag |
| Simulatorn (`Prov/SwingLabProvSlag`) | steg 6: passthrough-klippet, klicket i klippet på den vita rutan (−0,44 ms från väntat); steg 7: Vision går inte att starta i simulatorn (kod 9, även på CPU), så provet prövar `VisionPoseSource`s läsning fram till anropet (varje ruta, egen tid, lagrad bild, EXIF 6, alla leder `null` utan personer), att Visions fel är ett Vision-fel och att analysen då stannar synligt utan dom; kedjan: `Analysis` på ett pass ur filmen med påhittade leder (`DemoLeder`) i Visions ställe: domen, `Leder/s01.json`, `Klipp/s01.mov`, passet, ett avbrott som syns och fortsätter, Johannes ändrade dom, och listan ritad (`slag.png`, `traff.png`) |
| Bara telefonen | Visions leder: att en person hittas, vänster och höger, orienteringen, `msPerFrame` på riktigt (T2); domen på oktobers 41 slag (S2h) |

**T2 på 2 minuter:** Nytt pass (FO, 3 m) → stå i bild, lyft vänster hand och klappa
tre gånger → stopp → Close → passet i listan → Analyze. Se: tre slag (klappen ger
troligen "Not a swing", det är rätt), tryck på domen och välj "Swing" på ett, Analyze
igen; miniatyren visar axel- och höftlinjen över dig, den fyllda pricken på din
vänstra handled, och raden under rubriken visar ms/frame.

### S2f — Paketet och vägen tillbaka

`ZipWriter` och manifestets typer (`PackageManifest.swift`) byggs i SwingLabKit
med testerna i §11.2 och används från `Export.swift`; manifestet (§8.3), `enhet.json`,
`ljusprov.json`, med och utan klipp, `ActivitySheet`, `fileImporter` (§8.5).
Simulatorprovets steg 8.

**Klart när:** T4, och ett paket med klipp från S2e ligger på PC:n och läses
med Pythons `zipfile` (manifestet, ett slag, ett klipp som spelar).

### S2g — Två telefoner (kan flyttas till S6, §13)

`Link.swift` (App) och `Link` (`LinkMessage`, `Wire`) i SwingLabKit, `par.json`.
`ClockSync` och `ClickPairing` finns redan (S2b). Simulatorprovets steg 9.

**Klart när:** två telefoner i samma rum: Följ ansluter av sig själv, Start och
Stopp på den styrande styr båda, tre klapp paras med median |rest| under 5 ms,
och ett tapp (flygplansläge på följaren i 10 s mitt i en serie) förlorar inget
klick.

### S2h — Facit: S2:s "Klart när"

Ett pass inspelat i appen (minst 10 slag) och oktobers klipp körda på
telefonen; båda paketen på PC:n. Golf SG:s `klick()` och SwingLabs Swift hittar
samma klick i oktobers klipp, med tiden inom ±1 prov (talen jämförs lokalt och
stannar i Golf SG, dataregeln). Inte exakt: ljudet läses om till 48 kHz på två
olika sätt (ffmpeg och AVAssetReader), och telefonen fyller luckor och kapar
längden till spårets (METOD MS11). Bandet i PLAN.md: S2 ✓.

---

## 13. Det Johannes behöver bestämma

1. **Telefonerna:** *besvarat 2026-10-22: iPhone 17 och iPhone 13.* Båda
   filmar 1080p i 240 bilder/s och kör iOS 18.2 eller senare. Appen ska fungera
   på olika modeller: formatet väljs ur det telefonen själv rapporterar (F3),
   aldrig ur en modellista. iPhone 17 är huvudtelefonen (passet, Vision,
   paketet); iPhone 13 är den andra. Ljusprovet (F4) körs på båda, eftersom
   13:ans sensor och `maxISO` i 240-formatet kan kräva mer ljus; den telefon
   som har minst marginal får den bäst belysta vyn.
2. **Ljuset:** inomhus krävs troligen flimmerfria lampor (§2.3, cirka 700–1 400
   lux på golfaren vid ISO 1000–2000). Köp är Johannes beslut; Ljusprovet (T1)
   visar först hur långt det är kvar.
3. **Slutartiden:** 1/2000 s (BESLUT B11) eller kortare (1/4000 s halverar
   oskärpan men kräver dubbelt ljus).
4. **Två telefoner i S2 eller i S6:** *besvarat 2026-10-22: i S2.* S2g byggs
   som en del av S2.
5. **Originalen:** behålla hela serierna, eller "Spara bara klippen" efter
   export (sparar flera GB per pass).
6. **Ett TestFlight-bygge per etapp eller ihop:** förslaget är S2a ensam
   (prövar byggkedjan med minst möjligt), sedan S2c–S2f i ett bygge.
7. **Kompileringsprovet på varje push** (F6): *besvarat 2026-10-22: ja.*
   Läxan skrivs i `birdiebook/arbetssatt` om den håller.
