import SwiftUI
import UniformTypeIdentifiers
import Swing

@main
struct SwingLabApp: App {
    @State private var store = SwingLabApp.valjStore()

    var body: some Scene {
        WindowGroup {
            Flikar()
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }

    /// Appens Store. I simulatorn pekar UI-provet den på sina påhittade pass med
    /// SWINGLAB_PROV_ROT (PLAN S4i, BESLUT B101); på telefonen finns vägen inte.
    static func valjStore() -> Store {
        #if targetEnvironment(simulator)
        if let rot = ProcessInfo.processInfo.environment["SWINGLAB_PROV_ROT"] {
            let url = URL(fileURLWithPath: rot, isDirectory: true)
            return Store(root: url, exportFolder: url.appending(path: "Export"))
        }
        #endif
        return Store()
    }
}
