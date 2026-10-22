import Foundation
import Swing

/// Den hämtade `att_jobba_pa.json` (S4c): "Import focus" (S2f, BESLUT B28) sparar en fil
/// per pass som `AttJobbaPa/att_jobba_pa-<pass>.json` i appens mapp, och flikarna läser
/// den senaste därifrån (Idag, Att jobba på, accenten i Passet, Utveckling och
/// granskningen, BESLUT B31) och alla filernas block (Utveckling). En fil som inte går att
/// läsa hoppas över; den rörs aldrig. Läses när en vy öppnas: filen är liten. METOD MS16
enum FokusFiler {
    /// Alla filer som går att läsa, äldst först (passets id är tiden).
    static func alla(root: URL) -> [AttJobbaPa] {
        let mapp = root.appending(path: AttJobbaPa.mapp, directoryHint: .isDirectory)
        let namn = (try? FileManager.default.contentsOfDirectory(atPath: mapp.path)) ?? []
        return AttJobbaPa.filer(namn).compactMap { n in
            guard let data = try? Data(contentsOf: mapp.appending(path: n)) else { return nil }
            return try? AttJobbaPa.las(data)
        }
    }

    /// Den senaste filen, eller nil.
    static func senaste(root: URL) -> AttJobbaPa? {
        alla(root: root).last
    }

    /// Felen som övas just nu (accenten, BESLUT B31); tom utan fil.
    static func ovas(root: URL) -> Set<String> {
        senaste(root: root)?.ovas ?? []
    }
}
