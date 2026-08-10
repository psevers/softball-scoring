import SwiftData

@MainActor
enum AppModelContainer {
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            Team.self,
            Player.self,
            Season.self,
            Game.self,
            LineupEntry.self,
            GameEventRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
