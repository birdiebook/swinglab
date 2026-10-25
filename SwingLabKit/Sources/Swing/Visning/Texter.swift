import Foundation

/// Allt som appen visar och som byggs i SwingLabKit, på engelska (BESLUT B30, B33).
///
/// Det här är den enda filen i paketet med ord till användaren: vymodellerna i
/// Swing/Visning, kvittot och ljusprovet i Capture, och felen när telefonen läser
/// `att_jobba_pa.json`. Övriga filer bygger sina texter av talen och orden här;
/// bara förkortningar och enheter (FO, DTL, B10, cm, s, °) står i koden där de används.
/// Appens egna etiketter (knappar, rubriker, felen i App/) står i
/// `App/Localizable.xcstrings`. Ett nytt språk blir en tabell här och en kolumn i
/// katalogen, ingen ombyggnad av vyerna (BESLUT B33).
///
/// Provet `tools/tests/test_engelska.py` fäller å, ä och ö i strängarna här, och
/// VisningTests fäller dem i det vymodellerna räknar fram.
public enum Texter {
    // MARK: datumen (Tal)

    public static let manader = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    public static let veckodagar = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    /// "Jan 6"
    public static func datum(dag: Int, manad: String) -> String { "\(manad) \(dag)" }

    /// "Sat, Jan 9"
    public static func dag(veckodag: String, datum: String) -> String { "\(veckodag), \(datum)" }

    // MARK: måtten (Etiketter)

    /// Måttens korta namn i vyn, per mått i katalogen: kroppsdel och vad, utan position
    /// (granskningen visar positionen själv) och utan värdeord (BESLUT B13, B40).
    public static let mattnamn: [String: String] = {
        var n: [String: String] = [
            // Johannes godkända namn (BESLUT B40).
            "backen_thrust_traff": "Hips toward ball",
            "brost_bojning_tapp": "Spine angle loss",
            "bakre_armbage_topp": "Trail elbow flare",
            "handbana": "Hands out (downswing)",
            "backen_sway_topp": "Hip sway", "backen_sway_p3": "Hip sway",
            "backen_resa_framat": "Hip shift to target", "backen_resa_p5": "Hip shift to target",
            "sidbojning_topp": "Spine tilt",
            "framre_armbage_efter_traff": "Lead arm fold",
            "genomsving_s": "Follow-through time",
            // Övriga efter samma princip (BESLUT B40).
            "framre_armbage_topp": "Lead elbow bend", "framre_armbage_p3": "Lead elbow bend",
            "brost_bojning_adress": "Spine angle", "brost_bojning_traff": "Spine angle",
            "bakre_kna_adress": "Trail knee flex",
            "stans_bredd": "Stance width",
            "axellinje_lutning_adress": "Shoulder tilt", "axellinje_lutning_traff": "Shoulder tilt",
            "hoftlinje_lutning_adress": "Hip tilt",
            "hander_fore_adress_traff": "Hands toward target",
            "huvud_backen_finish": "Head over hips",
            "sway_gap_traff": "Hip–chest sway gap",
            "tempo": "Swing tempo",
            "handfart_max": "Hand speed",
            "handfart_max_fore_traff_ms": "Hand speed peak timing",
            "framre_arm_vinkelfart_max": "Lead arm speed",
            // Tilläggen bakifrån (PLAN S1c, METOD M38–M39).
            "hand_djup_topp": "Hand depth",
            "framre_arm_plan_topp": "Lead arm to shoulder plane",
            // Tilläggen ur research 5 (PLAN S1e, METOD M41–M43, M5, M14, M18).
            "backen_recentrering": "Hip recentering",
            "backen_skifte_ms": "Hip shift timing",
            "backen_lyft_min": "Hip low point",
            "backen_lyft_in_traff": "Hip rise into impact",
            "sidbojning_finish": "Spine tilt",
            "nedsving_s": "Downswing time",
            "hoftlinje_lutning_topp": "Hip tilt", "hoftlinje_lutning_traff": "Hip tilt",
            // Huvudet bakifrån och framifrån (METOD M8, M9), i granskningen sedan 2026-10-23.
            "huvud_mot_bollen_topp": "Head toward ball", "huvud_mot_bollen_traff": "Head toward ball",
            "huvud_lyft_topp": "Head height", "huvud_lyft_traff": "Head height",
            // Klubban ur markeringarna (PLAN S7a, METOD M46–M49).
            "skaft_vinkel": "Shaft angle", "skaftplan_p1": "Shaft plane", "skaft_mot_plan_p2": "Shaft to plane",
            "skaft_riktning_topp": "Shaft across the line", "skaft_plan_p6": "Clubhead to plane",
            "skaft_topp": "Shaft to level", "skaft_arm_p5": "Lead arm to shaft", "skaft_arm_p6": "Lead arm to shaft",
            "skaft_lutning_traff": "Shaft lean",
            // 3D ur två telefoner (PLAN S6c-2, METOD MK6): Johannes godkända namn (BESLUT B62).
            "backen_vrid_topp": "Pelvis turn at the top", "brost_vrid_topp": "Shoulder turn at the top",
            "xfaktor_topp": "X-factor at the top", "xfaktor_stretch": "X-factor stretch",
            "hofter_oppna_traff": "Hips open at impact",
        ]
        // Tilläggen mot Sportsbox i 2D (PLAN S1b, METOD M30–M37), ett namn per fas.
        for (m, namn) in [("backen_bojning", "Hip hinge"), ("framre_kna", "Lead knee flex"),
                          ("brost_lyft", "Chest height"), ("hand_lyft", "Hand height"),
                          ("framre_kna_sway", "Lead knee sway"), ("bakre_kna_sway", "Trail knee sway")] {
            for fz in ["adress", "topp", "traff", "finish"] { n["\(m)_\(fz)"] = namn }
        }
        return n
    }()

    /// Passets rad under rubriken: slagen med klubban markerad (PLAN S7a): "2 with club marked".
    public static func klubbMarkerade(_ n: Int) -> String { "\(n) with club marked" }
    /// Källraden när flyktpunkten bakifrån är bildens mitt (ingen riktpinne, METOD M48).
    public static let flyktpunktAntagen = "assumed: vanishing point at the picture center"
    /// Kortets n: de markerade svingarna som måttet är medianen av (METOD M46).
    public static func n(_ n: Int) -> String { "n\u{00A0}\(n)" }

    /// Spridningen mellan slagen (METOD M44): "Spine angle spread".
    public static func spridningsnamn(_ namn: String) -> String { "\(namn) spread" }

    /// Felets namn på Today och i passet: med positionen när måttet tas i en punkt i
    /// svingen ("Hip sway at top"), annars bara namnet (BESLUT B40).
    public static func felnamn(_ namn: String, fas: String) -> String {
        switch fas {
        case address, top, impact, finish: return "\(namn) at \(fas)"
        case afterImpact: return "\(namn) \(fas)"
        default: return namn
        }
    }

    /// Var i svingen måttet hör hemma, i kortets rubrik.
    public static let address = "address"
    public static let finish = "finish"
    public static let top = "top"
    public static let impact = "impact"
    public static let downswing = "downswing"
    public static let afterImpact = "after impact"
    public static let topToImpact = "top–impact"
    public static let addressToImpact = "address–impact"
    public static let startTopImpact = "start–top–impact"
    public static let impactToFinish = "impact–finish"
    public static let beforeImpact = "before impact"
    /// Skiftets tid räknas från toppen (METOD M42).
    public static let afterTop = "after top"

    /// Tempots vy: det kommer ur ljudet (klicket), inte ur en kamera.
    public static let ljud = "Audio"

    /// Åt vilket håll + pekar.
    public static let target = "target"
    public static let ball = "ball"
    /// Sidböjningen: + bort från målet (METOD M14, BESLUT B40).
    public static let awayFromTarget = "away from target"

    /// "+ to target", "+ away from target"
    public static func plus(_ hall: String) -> String { hall == awayFromTarget ? "+ \(hall)" : "+ to \(hall)" }

    // MARK: 3D ur två telefoner (PLAN S6c-2, BESLUT B62)

    /// Kortets och Progress-måttets rubrik: läget, utan markörer (BESLUT B14).
    public static let treDRubrik = "3D · no markers"
    /// Passets kort heter "3D".
    public static let treD = "3D"
    /// "12 swings": slagen som måtten är medianen av.
    public static func svingar(_ n: Int) -> String { n == 1 ? "1 swing" : "\(n) swings" }
    /// Skälen i kortet, korta och i grått (METOD MS19). Varför 3D inte räknades:
    public static let treDInteParat = "No swing filmed by both phones"
    public static let treDKalibrering = "Cameras could not be placed"
    public static let treDVyerna = "Needs one DTL and one FO phone"
    public static let treDPaketet = "Other phone's data unreadable"
    public static let treDInte = "3D not computed"
    /// Varför talen är osäkrare, eller färre:
    public static let treDVinkel = "Camera angle outside 60–120°"
    public static let treDLutning = "Phone tilt not used"
    public static func treDSerie(_ dtl: Int, _ fo: Int) -> String { "Set \(dtl) · \(fo) not measured" }
    public static func treDUtelamnade(_ n: Int) -> String { n == 1 ? "1 swing left out" : "\(n) swings left out" }
    public static func treDFarre(_ min: Int) -> String { "Fewer than \(min) swings" }
    /// Slagen har ändrats sedan 3D räknades: inga tal förrän den räknats om (METOD MS19).
    public static let treDUppdateras = "Updating…"
    /// Uppställningen: telefonen lutar för mycket för 3D (lodlinjen, METOD MS17, MS19).
    public static let lutningForStor = "Tilt too large for 3D"

    // MARK: figuren i 3D (PLAN S6d, BESLUT B73)

    /// De färdiga vinklarna.
    public static let treDFaceOn = "Face on"
    public static let treDDtl = "Down the line"
    public static let treDTop = "Top"
    /// Valet som visar telefonerna där kalibreringen placerade dem.
    public static let treDKameror = "Cameras"
    /// Telefonens etikett i bilden: vyn den filmade som ("FO", "DTL").
    public static func treDTelefon(_ vy: String) -> String { "\(vy) phone" }
    /// Kamerornas två tal, med sin gräns (METOD MK3).
    public static let treDSampson = "Sampson error"
    public static func treDSparr(_ px: String) -> String { "limit \(px) px" }
    public static let treDVinkelMellan = "Angle between phones"
    public static let treDVinkelSpann = "60–120°"
    /// Uppställningen kalibrerades men mättes inte: kamerorna, ingen figur.
    public static let treDOverSparren = "Sampson error over the limit: no figure"
    /// Ett slag utan figur i en uppställning som inte mättes.
    public static let treDIngenFigur = "No figure for this swing"
    /// Spelhastigheten.
    public static let treDFarter = ["1/8×", "1/4×", "1×"]

    // MARK: märkningen (Markning)

    public static let markningEgen = "Your usual"
    public static let markningAv = "off"
    public static let upplasningB10 = "limit not read in original"
    public static let upplasningEgen = "your usual"
    public static let upplasningAv = "off"
    /// Farterna (METOD M35–M37): oprövade på telefonen, kräver skarp bild (BESLUT B11).
    public static let markningOprovad = "untested"
    public static let upplasningOprovad = "untested on the phone, needs a sharp image"

    // MARK: jämförelsen och spannet

    /// "+1.2 cm vs Jan 6"
    public static func mot(_ skillnad: String, _ datum: String) -> String { "\(skillnad) vs \(datum)" }

    /// Spannet i ord för VoiceOver.
    public static func malMellan(_ a: String, _ b: String) -> String { "target \(a) to \(b)" }
    public static func malFran(_ a: String) -> String { "target from \(a)" }
    public static func malTill(_ b: String) -> String { "target up to \(b)" }
    public static func egenBaslinje(_ a: String, _ b: String) -> String { "your usual \(a) to \(b)" }

    // MARK: läget mot bandet (METOD M62, BESLUT B87): för VoiceOver, inga värdeord (B13)

    public static let lageInne = "in range"
    public static let lageNara = "just outside range"
    public static let lageOver = "above range"
    public static let lageUnder = "below range"
    public static let lageOverVanligt = "above your usual"
    public static let lageUnderVanligt = "below your usual"
    public static func forra(_ v: String) -> String { "last \(v)" }

    // MARK: passet

    /// Mellan delarna i en rad ("Sat, Jan 9 · 7i · 34"): hårt mellanslag före
    /// punkten, så att en bruten rad aldrig börjar med "·".
    public static let skilje = "\u{00A0}\u{00B7} "

    /// Filtret Alla/FO/DTL.
    public static let alla = "All"

    /// "2 not measured": pass med samma klubba utan mått, inte med i Utveckling (METOD MS16).
    public static func ejMatta(_ n: Int) -> String { "\(n) not measured" }
    /// "2 at another height": pass med samma klubba mätta med en annan längd (METOD MS16).
    public static func annanLangd(_ n: Int) -> String { "\(n) at another height" }

    // MARK: sessionslistan (PLAN S4e, BESLUT B64, METOD MS20)

    /// Vyn i listan och i sessionen, utskriven.
    public static func vyNamn(_ vy: Vy) -> String { vy == .dtl ? "Down the line" : "Face on" }
    /// Under antalet svingar i raden ("swings"; talet och ordet ihop är `svingar`).
    public static func svingEtikett(_ n: Int) -> String { n == 1 ? "swing" : "swings" }
    /// I stället för antalet när inget slag har fått sin dom.
    public static let ejAnalyserat = "Not analyzed"
    /// Två telefoner i samma pass (BESLUT B21).
    public static let parad = "paired"
    /// Den styrandes rad för ett parat pass (S6g, BESLUT B82): passet har båda vyerna.
    public static let paradRubrik = "Paired"
    /// Vyerna i ett parat pass, för VoiceOver.
    public static let badaVyerna = "Down the line and Face on"

    // MARK: två telefoner i passet (S6g, BESLUT B80–B83, METOD MS30, MS31)

    /// "DTL", "FO": vyn kort, som etiketten i uppställningen och växlingen i passet.
    public static func vyKort(_ vy: Vy) -> String { vy == .dtl ? "DTL" : "FO" }
    /// "14 swings · 12 from both phones"
    public static func franBada(svingar n: Int, bada: Int) -> String {
        svingar(n) + skilje + "\(bada) from both phones"
    }
    /// Den styrande hämtar klippen: "Getting video from other phone · 60 %".
    public static func hamtar(_ procent: Int) -> String { "Getting video from other phone" + skilje + "\(procent) %" }
    /// Följaren skickar dem.
    public static func skickar(_ procent: Int) -> String { "Sending video to other phone" + skilje + "\(procent) %" }
    /// Den andra vyn i passet innan den andra telefonens slag kommit.
    public static let annanVantar = "Waiting for the other phone's swings"
    /// Den styrande har inte plats för klippen (B84).
    public static let diskFull = "Not enough space for the other phone's video"
    /// Ett slag vars klipp kom utan klick: synken tar parningens tid (MS31).
    public static let ingetKlick = "No click in this video"
    /// I den andra vyns lista: kom utan klick (kort).
    public static let ingetKlickKort = "no click"
    /// I den andra vyns lista: ingen video från den andra telefonen för slaget.
    public static let ingenVideo = "—"
    /// Kopplingen är nere och klippen väntar.
    public static let videoVantar = "Video waits for the other phone"
    /// Båda telefonerna har samma vy (B83): "Both phones are DTL".
    public static func sammaVy(_ vy: Vy) -> String { "Both phones are \(vyKort(vy))" }
    /// Knappen som byter den här telefonens vy: "Switch to FO".
    public static func bytVy(_ vy: Vy) -> String { "Switch to \(vyKort(vy))" }
    /// Raden i passet när den andra telefonens slag har samma vy.
    public static let sammaVyIPasset = "Both phones filmed the same view: no 3D"

    // MARK: inspelningens skärm (PLAN S2j, BESLUT B85, METOD MS32)

    /// Statuspillen.
    public static let inspSoker = "Searching"
    public static let inspKopplad = "Connected"
    public static let inspTappad = "Other phone lost"
    /// "REC 0:42": bara tiden, tills svingräknaren är kalibrerad (METOD MS32).
    public static func inspRec(_ tid: String) -> String { "REC \(tid)" }
    /// Svingarna hittills i kugghjulet, en skattning: "~3".
    public static func inspSvingarHittills(_ n: Int) -> String { "~\(n)" }
    /// Varningarna, en i taget.
    public static let inspAndraStoppade = "Other phone stopped recording"
    public static let inspNatAv = "Local network off"
    public static let inspLagring = "Less than 4 GB free"
    public static let inspMikrofonAv = "Microphone off"
    public static let inspExternMikrofon = "External microphone"
    /// "120 fps, not 240"
    public static func inspBildfrekvens(_ n: Int, onskad: Int) -> String { "\(n) fps, not \(onskad)" }
    /// Lutningen mitt på skärmen.
    public static let inspLutning = "Level the phone"
    /// Kugghjulets värden.
    public static func inspTelefon(roll: String?, vy: Vy) -> String { (roll.map { $0 + skilje } ?? "") + vyKort(vy) }
    public static let inspRollStyr = "Lead"
    public static let inspRollFolj = "Follow"
    /// "6 of 6 · 1.2 ms": par av den styrandes klick, och median |rest|; "· uncertain" när
    /// parningen är osäker (MS10).
    public static func inspHorda(_ par: Int, av: Int, ms: String?, osaker: Bool = false) -> String {
        "\(par) of \(av)" + (ms.map { skilje + $0 + " ms" } ?? "") + (osaker ? skilje + inspOsaker : "")
    }
    public static let inspOsaker = "uncertain"
    /// "about 40 min"
    public static func inspMinuter(_ n: Int) -> String { "about \(n) min" }
    public static func inspFps(_ n: Int) -> String { "\(n) fps" }
    public static let inspMikInbyggd = "Built-in"
    public static let inspMikExtern = "External"
    public static let inspMikAv = "Off"

    /// Raden i ord för VoiceOver: "Face on, Sat, Jan 9, 18:05, 7i, 8 swings, paired".
    public static func sessionsrad(vy: String, dag: String, klocka: String, klubba: String, svingar: Int?,
                                   parad: Bool) -> String {
        var d = [vy, dag, klocka, klubba, svingar.map { Texter.svingar($0) } ?? ejAnalyserat]
        if parad { d.append(Texter.parad) }
        return d.joined(separator: ", ")
    }

    // MARK: Att jobba på

    /// "week 5"
    public static func vecka(_ n: Int) -> String { "week \(n)" }

    /// Stegen inom en övning, i S5:s ordning (METOD MT10).
    public static let stegnamn = ["langsamt_med_foremal": "Slow", "halv_fart": "Half speed",
                                  "full_fart": "Full speed", "varierat": "Varied"]

    /// "First set ≥ 0": villkoret på första serien (METOD MT2).
    public static func forstaSerien(_ grans: String) -> String { "First set \(grans)" }

    /// "2 sessions in a row" (och "1 session" när villkoret gäller ett enda pass).
    public static func passIRad(_ n: Int) -> String { n == 1 ? "1 session" : "\(n) sessions in a row" }

    /// Tanken inom typografiska citattecken: “Leave the stick standing.”
    public static func citat(_ text: String) -> String { "\u{201C}\(text)\u{201D}" }

    /// Sakens delar i ord för VoiceOver.
    public static func upplasningFoljd(_ t: String) -> String { "follow-on: \(t)" }
    public static func upplasningOvning(_ t: String) -> String { "drill: \(t)" }
    public static func upplasningSteg(_ t: String) -> String { "step: \(t)" }
    public static func upplasningRorlighet(_ t: String) -> String { "mobility: \(t)" }
    public static func upplasningTanke(_ t: String) -> String { "swing thought: \(t)" }
    public static func upplasningKlartNar(_ t: String) -> String { "done when: \(t)" }

    // MARK: Granskningen

    public static let sway = "Hip sway"
    public static let thrust = "Hips toward ball"

    // MARK: infobladet (BESLUT B41)

    /// Källans rad, ur katalogens `status` och `kalla`: aldrig mer än METOD säger.
    public static let kallaRubrik = "Source"
    static let statusord = ["tillverkare": "Manufacturer", "forskning": "Research", "tranare": "Coach",
                            "antagande": "Assumption"]
    public static let ejKontrollerad = "not verified"
    public static let egenBaslinjeKalla = "own baseline"
    public static let oprovadKalla = "untested on the phone"
    /// Tempot saknas för att baksvingens start är osäker bakifrån (METOD M40).
    public static let startOsakerKalla = "no tempo when the start is unclear from behind"
    /// VoiceOver för ett mått som saknas i passet: "Swing tempo, not measured".
    public static let ejMatt = "not measured"

    /// Gränsen är ett antagande byggt på en tillverkares tal (sway_topp, METOD M15).
    public static let antagandeFran = "Assumption from"

    /// "Manufacturer (golf.com, golftec.co.za), not verified", "Assumption from manufacturer
    /// (golf.com, golftec.co.za), not verified" (`harledd`) eller "Assumption, own baseline".
    public static func kalla(status: String, kontrollerad: Bool, gransFinns: Bool, varden: [String],
                             harledd: Bool = false) -> String {
        var t = statusord[status] ?? status
        if harledd && status != "antagande" { t = "\(antagandeFran) \(t.lowercased())" }
        if status != "antagande" && !varden.isEmpty { t += " (\(varden.joined(separator: ", ")))" }
        if !gransFinns { t += ", \(egenBaslinjeKalla)" }
        if !kontrollerad && status != "antagande" { t += ", \(ejKontrollerad)" }
        return t
    }

    /// Ett mått utan fel: egen baslinje, och farterna oprövade (METOD M27, M35–M37).
    public static func kallaMatt(oprovad: Bool) -> String {
        "\(statusord["antagande"]!), \(egenBaslinjeKalla)" + (oprovad ? ", \(oprovadKalla)" : "")
    }

    // MARK: kvittot och ljusprovet (Capture, METOD MS11)

    public static let kvittoBilder = "fps"
    public static let kvittoTappade = "Dropped"
    public static let kvittoRutor = "Frames"
    public static let kvittoKlick = "Clicks"
    public static let kvittoMBmin = "MB/min"
    public static let kvittoLangd = "Length"
    public static let kvittoVarme = "Heat"
    public static let ljusLjus = "Light"
    public static let ljusISO = "ISO"
    public static let ljusFlimmer = "Flicker"
    public static let ljusRutor = "Frames"
    public static let ljusLjushet = "Brightness"

    /// "Too dark: 1.3 stops"
    public static func forMorkt(_ steg: String) -> String { "Too dark: \(steg) stops" }

    /// "240 fps, 33% dropped"
    public static func rutorOchTappade(_ fps: String, _ tappade: String) -> String { "\(fps) fps, \(tappade) dropped" }

    /// Värmetrycket, `AVCaptureDevice.SystemPressureState.Level` i Apples ord.
    public static let trycket = ["nominal": "normal", "fair": "fair", "serious": "serious",
                                 "critical": "critical", "shutdown": "shutdown"]

    /// Importen ur Bilder vägrar en omräknad fil (S2_SPEC §5, BESLUT B24).
    public static let inteOriginalet = "Not the slow-motion original"

    // MARK: felen när telefonen läser att_jobba_pa.json

    /// Felen nämner fältet, aldrig värdet (docs/FORMAT.md).
    public static func filFel(_ text: String) -> String { "att_jobba_pa: \(text)" }
    public static func saknas(_ falt: String) -> String { "\(falt) is missing" }
    public static func felTyp(_ falt: String) -> String { "\(falt): wrong type" }
    public static func saknarVarde(_ falt: String) -> String { "\(falt): no value" }
    public static func ogiltigt(_ falt: String) -> String { "\(falt): invalid" }
    public static let inteJSON = "not valid JSON"
    public static func formatSkaBorja(_ prefix: String) -> String { "format: must start with \(prefix)" }
    public static let sakerEttTillTre = "saker: must be 1–3"
    public static func stegSkaVara(_ falt: String, _ stegen: String) -> String { "\(falt): must be one of \(stegen)" }
    /// Platsen när felet gäller hela filen.
    public static let filen = "file"

    // MARK: svaret från Claude-appen (S5b)

    /// Kontrollens koder (AttJobbaPaKontroll och ClaudeSvar, samma som PC:ns) på engelska;
    /// fältet står före, värdet aldrig (Dataregeln). BESLUT B54
    public static let kontrollfelTexter: [String: String] = [
        "objekt": "must be an object", "okand_nyckel": "unknown key", "saknas": "is missing",
        "format": "must be swinglab-att-jobba-pa/1", "pass_form": "must be yyyyMMdd-HHmmss",
        "inte_analysens": "is not this session", "iso": "must be an ISO 8601 time", "antal": "must be 1–3 items",
        "dubblett": "the same fault twice", "ordning": "wrong order number", "ej_i_katalogen": "not in the catalog",
        "avstangt": "switched off in the catalog", "katalogens": "must be the catalog's",
        "mattets": "must be the measure's unit", "svingens_ordning": "earlier in the swing than the item before",
        "foljdfel_av_vald": "follows from another chosen item", "ej_i_analysen": "not in this session",
        "foljdfel": "follows from a flagged fault; practise the cause", "okant_med_flaggade": "unknown while others are flagged",
        "inte_flaggat": "not flagged in this session", "analysens_tal": "must be the session's number",
        "klar": "the drill is done; drop the item", "byt_ovning": "the history says change drill",
        "redan_provad": "drill already tried for this fault", "ej_i_kedjorna": "not a drill for this fault",
        "kedjornas": "must be the drill's text", "kalla": "must be katalog or research3", "text": "must be text",
        "for_lang": "too long", "siffror": "no digits", "vardeord": "no judging words", "utropstecken": "no exclamation marks",
        "svenska": "must be English", "steg": "unknown step", "steg_hopp": "same step or the next",
        "steg_forsta": "a new drill starts at the first step", "villkor": "must be >=, <= or mellan",
        "grans_spann": "must be [min, max]", "grans_tal": "must be a number", "pa": "must be forsta_serien",
        "pass_i_rad": "must be 2", "last": "must stay as when the drill was chosen",
        "analysens": "must be the session's suggestion", "inget_forslag": "the session has no suggestion",
        "block_start": "must be the day the fault was first chosen", "block_vecka": "wrong week",
        "lista": "must be a list", "ingen_kedja": "no chain from the item", "vag": "must be the chain's path",
        "vald": "is also a chosen item", "fysik_forst": "the history says test mobility first",
        "typ": "unknown type", "kravs": "needed for the type", "treregeln": "does not follow the three rules",
        "test": "not a test for this fault", "null": "must be null for technique",
        "inget_block": "no code block from Claude", "inte_json": "the code block is not valid JSON",
        "inte_att_jobba_pa": "no Focus file in the reply", "for_stort": "the reply is too long",
    ]

    /// Kodens text, eller "invalid" för en kod utan text.
    public static func kontrollfel(_ kod: String) -> String { kontrollfelTexter[kod] ?? "invalid" }

    /// Längsta okända nyckel som visas; en längre kortas med "…" (nyckeln är Claudes text, inte
    /// ett mått, men raden ska rymmas). METOD MS18
    public static let maxNyckel = 24

    /// Ett fel som appen visar det: fältet och kodens text, med en okänd nyckel kortad. METOD MS18
    public static func kontrollfelText(_ f: Kontrollfel) -> String {
        var falt = f.falt
        if f.kod == "okand_nyckel" {
            let i = falt.lastIndex(of: ".").map { falt.index(after: $0) } ?? falt.startIndex
            let nyckel = falt[i...]
            if nyckel.count > maxNyckel { falt = String(falt[..<i]) + String(nyckel.prefix(maxNyckel - 1)) + "…" }
        }
        return "\(falt): \(kontrollfel(f.kod))"
    }

    /// "Paste from Claude" i appen (S5b-2): det första felet som en rad, fältet och kodens text,
    /// och antalet fel till ("saker[0].ovning.tanke: too long · +2"). Aldrig ett värde ur svaret.
    /// BESLUT B60, METOD MS18
    public static func kontrollfelRad(_ fel: [Kontrollfel]) -> String {
        guard let f = fel.first else { return "" }
        let t = kontrollfelText(f)
        return fel.count > 1 ? t + skilje + "+\(fel.count - 1)" : t
    }

    /// Alla felen, ett per rad, när Johannes trycker på raden.
    public static func kontrollfelAlla(_ fel: [Kontrollfel]) -> [String] { fel.map(kontrollfelText) }

    /// "Use" kunde inte spara filen: fältet och koden, som felen ovan.
    public static let focusSparadesInte = "\(filen): could not be saved"

    // MARK: klubbans märkning (S7c, BESLUT B59)

    /// P1–P10 i klartext, korta och utan värdeord: kroppens positioner som METOD M28 (armen
    /// "parallel" = vågrät i bild), skaftets som Sportsbox BCH, DCH och FCH (club horizontal,
    /// research 5a, M28).
    public static let positionsnamn: [String: String] = [
        "P1": "Address", "P2": "Club parallel, backswing", "P3": "Lead arm parallel, backswing",
        "P4": "Top of backswing", "P5": "Lead arm parallel, downswing", "P6": "Club parallel, downswing",
        "P7": "Impact", "P8": "Club parallel, follow-through", "P9": "Trail arm parallel", "P10": "Finish"]

    /// "P4 · Top of backswing · 3 of 10": positionen, dess namn och var i märkningens ordning.
    public static func markeringsPosition(_ p: String, nummer: Int, av: Int) -> String {
        "\(p)\(skilje)\(positionsnamn[p] ?? p)\(skilje)\(nummer) of \(av)"
    }
}
