import SwiftUI
import SwiftData

@main
struct SoftballScoringApp: App {
    private let container: ModelContainer

    init() {
        do {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
                let arguments = ProcessInfo.processInfo.arguments
                if let index = arguments.firstIndex(of: "-uiTestingStore"),
                   arguments.indices.contains(index + 1) {
                    container = try UITestData.makeContainer(
                        storeURL: URL(fileURLWithPath: arguments[index + 1])
                    )
                } else {
                    container = try UITestData.makeContainer()
                }
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
