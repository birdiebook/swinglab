import SwiftUI
import UniformTypeIdentifiers
import Swing

@main
struct SwingLabApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            Flikar()
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }
}
