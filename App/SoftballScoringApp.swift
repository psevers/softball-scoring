import SwiftUI
import SwiftData

@main
struct SoftballScoringApp: App {
    private let container: ModelContainer

    init() {
        do {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
                container = try UITestData.makeContainer()
            } else {
                container = try AppModelContainer.make()
            }
            #else
            container = try AppModelContainer.make()
            #endif
        } catch {
            fatalError("Unable to create SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
