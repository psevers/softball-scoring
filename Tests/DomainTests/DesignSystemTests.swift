import SwiftData
import Testing
import UIKit
@testable import SoftballScoring

struct DesignSystemTests {
    @Test func bundledExpressiveFontIsAvailableAtRuntime() {
        #expect(UIFont(name: "PatrickHand-Regular", size: 20) != nil)
    }

    @Test @MainActor func liveScorebookPreviewFixturesExerciseDocumentedStates() throws {
        let offense = PreviewData.offensiveLiveGame
        let offensiveRecords = try records(for: offense)
        let offensiveReplay = GameEventReplay.replay(
            records: offensiveRecords,
            homeAway: .away,
            startingPitcherID: offense.game.startingPitcherID
        )

        #expect(offensiveReplay.rejectedRecordIDs.isEmpty)
        #expect(offensiveReplay.state.currentTrackedBatterSlot == 3)
        #expect(offensiveReplay.state.awayScore == 9)
        #expect(offensiveReplay.state.balls == 1)
        #expect(offensiveReplay.state.strikes == 1)
        #expect(offensiveReplay.state.secondBaseRunnerPlayerID != nil)
        #expect(offensiveReplay.state.thirdBaseRunnerPlayerID != nil)

        let battingLines = try BattingStatProjector.project(
            events: offensiveRecords.map { try $0.decoded() }
        )
        #expect(battingLines.values.contains { $0.homeRuns == 1 && $0.plateAppearances >= 1 })

        let defense = PreviewData.defensiveLiveGame
        let defensiveReplay = GameEventReplay.replay(
            records: try records(for: defense),
            homeAway: .home,
            startingPitcherID: defense.game.startingPitcherID
        )

        #expect(defensiveReplay.rejectedRecordIDs.isEmpty)
        #expect(defensiveReplay.state.outs == 1)
        #expect(defensiveReplay.state.firstBaseRunnerSlot == 2)
        #expect(defensiveReplay.state.balls == 1)
        #expect(defensiveReplay.state.strikes == 1)

        let gated = PreviewData.gatedLiveGame
        let gatedReplay = GameEventReplay.replay(
            records: try records(for: gated),
            homeAway: .away,
            startingPitcherID: gated.game.startingPitcherID
        )
        #expect(gatedReplay.rejectedRecordIDs.count == 1)
    }

    @MainActor
    private func records(for fixture: PreviewData.LiveGameFixture) throws -> [GameEventRecord] {
        try fixture.container.mainContext.fetch(FetchDescriptor<GameEventRecord>())
            .filter { $0.gameID == fixture.game.id }
    }
}
