import Foundation
@testable import Swing

// Pythons resultat i Fixturer.swift, avkodade. Formen är den som
// tools/pc/generera.py skriver (resultat_json och session_fixtur).

/// Pythons tal för en sving.
struct PythonSving: Decodable {
    struct Tider: Decodable {
        let start: Double?
        let topp: Double
        let traff: Double
    }

    /// P-positionerna; null = saknas. METOD M28
    struct Positioner: Decodable {
        let p1: Double
        let p3: Double?
        let p4: Double
        let p5: Double?
        let p7: Double
        let p9: Double?
        let p10: Double

        enum CodingKeys: String, CodingKey {
            case p1 = "P1", p3 = "P3", p4 = "P4", p5 = "P5", p7 = "P7", p9 = "P9", p10 = "P10"
        }

        func tid(_ namn: String) -> Double? {
            let d: [String: Double?] = ["P1": p1, "P3": p3, "P4": p4, "P5": p5, "P7": p7, "P9": p9, "P10": p10]
            return d[namn] ?? nil
        }
    }

    let cmPerPx: Double
    let faser: Tider
    let positioner: Positioner
    let matt: [String: Double]

    enum CodingKeys: String, CodingKey {
        case cmPerPx = "cm_per_px"
        case faser, positioner, matt
    }
}

struct PythonSammanfattning: Decodable {
    let n: Int
    let median: Double
    let q1: Double
    let q3: Double
    let sd: Double
    let min: Double
    let max: Double
    let trend: Double
    let avvikare: [Int]
}

struct PythonJamforelse: Decodable {
    let skillnad: Double
    let spridning: Double
    let tydlig: Bool
}

struct PythonBedomning: Decodable {
    let id: String
    let varde: Double?
    let status: String
    let grund: String?
    let z: Double?
}

/// Två påhittade pass och Pythons sammanfattning, jämförelse och bedömning.
struct PythonSession: Decodable {
    let nu: [SvingMatt]
    let forra: [SvingMatt]
    /// "nu"/"forra" → grupp ("dtl", "fo", "alla") → mått → sammanfattning
    let sammanfattning: [String: [String: [String: PythonSammanfattning]]]
    /// grupp → mått → jämförelse
    let jamforelse: [String: [String: PythonJamforelse]]
    let bedomning: [PythonBedomning]
}

func avkoda<T: Decodable>(_ typ: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(typ, from: Data(json.utf8))
}
