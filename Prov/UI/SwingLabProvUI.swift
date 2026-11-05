// TILLGÄNGLIGHETEN I SIMULATORN (PLAN S4i, BESLUT B101, METOD MS42). Appen startas på riktigt
// (XCUIApplication) med de påhittade passen som SwingLabProvUIPass skrev till
// /tmp/swinglab_prov/ui-store (SWINGLAB_PROV_ROT, bara i simulatorn), och Apples granskning
// (performAccessibilityAudit: kontrast, träffytor, beskrivningar, Dynamisk text, klippt text,
// egenskaper) körs på Sessions, ett pass och Me, i standardstorleken och i AX3.
//
// Varje fynd skrivs till loggen ("TILLGANGLIGHET: känt|NYTT skärm|storlek|typ|element").
// Kända fynd står i `kanda` och fäller inte; ett nytt fynd fäller. Listan ska krympa: ett känt
// fynd som inte längre syns skrivs ut som "borta", så att raden kan tas bort.
//
// Körs av kompilera.yml efter resten av provet (-only-testing:SwingLabProvUI), aldrig av
// TestFlight. DATAN ÄR PÅHITTAD (SwingDemo, CLAUDE.md: Dataregeln).

import XCTest

final class SwingLabProvUI: XCTestCase {

    static let rot = "/tmp/swinglab_prov/ui-store"
    /// AX3, som matrisen (METOD MS41).
    static let ax3 = "UICTContentSizeCategoryAccessibilityXL"

    /// Kända fynd, "skärm|storlek|typ|element". Krymper när skärmarna rättas. METOD MS42
    static let kanda: Set<String> = []

    static let typer: [(typ: XCUIAccessibilityAuditType, namn: String)] = [
        (.contrast, "kontrast"), (.elementDetection, "element"), (.hitRegion, "träffyta"),
        (.sufficientElementDescription, "beskrivning"), (.dynamicType, "dynamisk text"),
        (.textClipped, "klippt text"), (.trait, "egenskap"),
    ]

    /// Fynden i hela klassen (alla nycklar som syns), för raden om kända fynd som är borta.
    static var sedda: Set<String> = []

    override class func tearDown() {
        for k in kanda.subtracting(sedda).sorted() {
            print("TILLGANGLIGHET: borta \(k) (stryk raden i kanda)")
        }
        super.tearDown()
    }

    @MainActor
    func testStandard() throws {
        try granskaSkarmarna(storlek: "standard", argument: nil)
    }

    @MainActor
    func testAX3() throws {
        try granskaSkarmarna(storlek: "AX3", argument: Self.ax3)
    }

    /// Sessions med passen, passet (FO, tisdag 10 november) och Me. Stannar vid första steget
    /// som inte går, så att felet pekar på rätt ställe.
    @MainActor
    func granskaSkarmarna(storlek: String, argument: String?) throws {
        var app = starta(argument)
        let rad = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Face on")).firstMatch
        guard rad.waitForExistence(timeout: 30) else {
            return XCTFail("\(storlek): ingen rad med FO-passet i Sessions")
        }
        try granska(app, skarm: "sessions", storlek: storlek)

        rad.tap()
        let titel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Nov 10")).firstMatch
        guard titel.waitForExistence(timeout: 30) else {
            return XCTFail("\(storlek): passet öppnades inte")
        }
        try granska(app, skarm: "passet", storlek: storlek)

        app.terminate()
        app = starta(argument)
        let me = app.buttons["Me"].firstMatch
        guard me.waitForExistence(timeout: 30) else {
            return XCTFail("\(storlek): ingen flik Me")
        }
        me.tap()
        guard app.buttons["Import focus"].waitForExistence(timeout: 30) else {
            return XCTFail("\(storlek): Me visades inte")
        }
        try granska(app, skarm: "me", storlek: storlek)
        app.terminate()
    }

    @MainActor
    func starta(_ argument: String?) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SWINGLAB_PROV_ROT"] = Self.rot
        if let argument { app.launchArguments += ["-UIPreferredContentSizeCategoryName", argument] }
        app.launch()
        return app
    }

    /// Fynden samlas under granskningen och läses efteråt, på huvudtråden.
    final class Fynd: @unchecked Sendable {
        var lista: [XCUIAccessibilityAuditIssue] = []
    }

    /// Apples granskning av skärmen som syns. Varje fynd loggas; de nya fäller, samlade i ett fel.
    @MainActor
    func granska(_ app: XCUIApplication, skarm: String, storlek: String) throws {
        let fynd = Fynd()
        try app.performAccessibilityAudit { issue in
            fynd.lista.append(issue)
            return true
        }
        var nya: [String] = []
        for issue in fynd.lista {
            var typ = "typ \(issue.auditType.rawValue)"
            for (t, namn) in Self.typer where issue.auditType.contains(t) {
                typ = namn
                break
            }
            var element = "-"
            if let e = issue.element {
                element = !e.label.isEmpty ? e.label : !e.identifier.isEmpty ? e.identifier : "elementtyp \(e.elementType.rawValue)"
            }
            let nyckel = "\(skarm)|\(storlek)|\(typ)|\(element)"
            Self.sedda.insert(nyckel)
            let kand = Self.kanda.contains(nyckel)
            if !kand { nya.append(nyckel) }
            print("TILLGANGLIGHET: \(kand ? "känt" : "NYTT") \(nyckel) — \(issue.compactDescription)")
        }
        print("TILLGANGLIGHET: \(skarm) \(storlek): \(fynd.lista.count) fynd, \(nya.count) nya")
        XCTAssertTrue(nya.isEmpty, "\(skarm) \(storlek): nya fynd i granskningen: \(nya.joined(separator: "; "))")
    }
}
