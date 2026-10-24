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

    // MARK: märkningen (Markning)

    public static let markningEgen = "own"
    public static let markningAv = "off"
    public static let upplasningB10 = "limit not read in original"
    public static let upplasningEgen = "own baseline"
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
    public static func egenBaslinje(_ a: String, _ b: String) -> String { "own baseline \(a) to \(b)" }
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

    /// "Paste from Claude" i appen (S5b-2): det första felet som en rad, fältet och kodens text,
    /// och antalet fel till ("saker[0].ovning.tanke: too long · +2"). Aldrig ett värde ur svaret.
    /// BESLUT B60, METOD MS18
    public static func kontrollfelRad(_ fel: [Kontrollfel]) -> String {
        guard let f = fel.first else { return "" }
        return fel.count > 1 ? f.text + skilje + "+\(fel.count - 1)" : f.text
    }
}
