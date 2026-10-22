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

    let cmPerPx: Double
    let faser: Tider
    let matt: [String: Double]

    enum CodingKeys: String, CodingKey {
        case cmPerPx = "cm_per_px"
        case faser, matt
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
