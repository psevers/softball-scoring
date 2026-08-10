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

    @Test func timedGameRoundTripsItsDurationAndDisplayFormat() {
        let game = Game(
            seasonID: UUID(),
            opponentName: "Thunder",
            timeLimitMinutes: 75
        )

        #expect(game.format == .timeLimit)
        #expect(game.timeLimitMinutes == 75)
        #expect(game.formatDescription == "75 minute time limit")
    }

    @Test func timedGameReportsRemainingTimeWithoutFinalizingItself() {
        let start = Date(timeIntervalSince1970: 1_000)
        let game = Game(
            seasonID: UUID(),
            opponentName: "Thunder",
            timeLimitMinutes: 3,
            status: .inProgress,
            startedAt: start
        )

        #expect(game.timeStatus(at: start.addingTimeInterval(65)) == "1:55 remaining")
        #expect(game.timeStatus(at: start.addingTimeInterval(180)) == "Time expired")
        #expect(game.status == .inProgress)
    }

    @Test func invalidOrExtremeDurableTimeValuesDoNotCrashStatusRendering() {
        let start = Date(timeIntervalSince1970: 1_000)
        let game = Game(
            seasonID: UUID(),
            opponentName: "Thunder",
            timeLimitMinutes: Int.max,
            startedAt: start
        )

        #expect(game.timeStatus(at: start) != nil)

        game.regulationInnings = 0
        #expect(game.format == nil)
        #expect(game.formatDescription == "Unreadable format")
        #expect(game.timeStatus(at: start) == nil)

        game.regulationInnings = .min
        #expect(game.format == nil)
        #expect(game.timeStatus(at: start) == nil)
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

    @Test(arguments: [11, 12, 13])
    func lineupAllowsContinuousBattingOrders(_ lineupCount: Int) {
        let ids = (0..<lineupCount).map { _ in UUID() }
        let defenders = zip(ids.prefix(9), LineupValidation.regulationDefensivePositions)
            .map { LineupDraftEntryValue(playerID: $0.0, position: $0.1) }
        let battingOnlyPlayers = ids.dropFirst(9)
            .map { LineupDraftEntryValue(playerID: $0, position: nil) }

        #expect(LineupValidation.canStart(
            entries: defenders + battingOnlyPlayers,
            startingPitcherID: ids[0]
        ))
    }

    @Test func lineupRejectsMoreThanNineDefensiveAssignments() {
        let ids = (0..<10).map { _ in UUID() }
        let defenders = zip(ids.prefix(9), LineupValidation.regulationDefensivePositions)
            .map { LineupDraftEntryValue(playerID: $0.0, position: $0.1) }
        let tenthDefender = LineupDraftEntryValue(playerID: ids[9], position: .utility)

        #expect(!LineupValidation.canStart(
            entries: defenders + [tenthDefender],
            startingPitcherID: ids[0]
        ))
    }

    @Test func lineupRejectsDuplicateBattingOnlyPlayer() {
        let ids = (0..<9).map { _ in UUID() }
        let defenders = zip(ids, LineupValidation.regulationDefensivePositions)
            .map { LineupDraftEntryValue(playerID: $0.0, position: $0.1) }

        #expect(!LineupValidation.canStart(
            entries: defenders + [.init(playerID: ids[8], position: nil)],
            startingPitcherID: ids[0]
        ))
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
