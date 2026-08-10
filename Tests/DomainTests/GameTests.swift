import Foundation
import Testing
@testable import SoftballScoring

struct GameTests {
    @Test func gameRoundTripsSetupValues() {
        let seasonID = UUID()
        let pitcherID = UUID()
        let game = Game(
            seasonID: seasonID,
            opponentName: "Thunder",
            homeAway: .home,
            regulationInnings: 7,
            status: .inProgress,
            startingPitcherID: pitcherID
        )

        #expect(game.seasonID == seasonID)
        #expect(game.opponentName == "Thunder")
        #expect(game.homeAway == .home)
        #expect(game.regulationInnings == 7)
        #expect(game.status == .inProgress)
        #expect(game.startingPitcherID == pitcherID)
    }

    @Test func lineupRequiresNineUniquePlayersEveryRegulationPositionAndPitcherAtP() {
        let ids = (0..<9).map { _ in UUID() }
        let positions = LineupValidation.regulationDefensivePositions
        let entries = zip(ids, positions).map { LineupDraftEntryValue(playerID: $0.0, position: $0.1) }

        #expect(LineupValidation.canStart(entries: entries, startingPitcherID: ids[0]))
        #expect(!LineupValidation.canStart(entries: Array(entries.prefix(8)), startingPitcherID: ids[0]))
        #expect(!LineupValidation.canStart(entries: entries, startingPitcherID: UUID()))

        var duplicatePlayer = entries
        duplicatePlayer[8] = .init(playerID: ids[0], position: .rightField)
        #expect(!LineupValidation.canStart(entries: duplicatePlayer, startingPitcherID: ids[0]))

        var duplicatePosition = entries
        duplicatePosition[8] = .init(playerID: ids[8], position: .centerField)
        #expect(!LineupValidation.canStart(entries: duplicatePosition, startingPitcherID: ids[0]))

        #expect(!LineupValidation.canStart(entries: entries, startingPitcherID: ids[1]))
    }

    @Test func lineupRejectsMissingPositionEvenWhenNinePlayersArePresent() {
        let ids = (0..<9).map { _ in UUID() }
        var entries = zip(ids, LineupValidation.regulationDefensivePositions)
            .map { LineupDraftEntryValue(playerID: $0.0, position: $0.1) }
        entries[4] = .init(playerID: ids[4], position: nil)

        #expect(!LineupValidation.canStart(entries: entries, startingPitcherID: ids[0]))
    }

    @Test func lineupEntryDefaultsCurrentPositionToStartingPosition() {
        let entry = LineupEntry(
            playerID: UUID(),
            battingOrder: 1,
            startingPosition: .shortstop,
            gameID: UUID()
        )

        #expect(entry.startingPosition == .shortstop)
        #expect(entry.currentPosition == .shortstop)
    }
}
