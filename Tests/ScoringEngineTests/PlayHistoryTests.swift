import Foundation
import Testing
@testable import SoftballScoring

struct PlayHistoryTests {
    @Test func completedBallInPlayPairsPitchAndResultWhilePendingPlayStaysVisible() throws {
        let pitcherID = UUID()
        let gameID = UUID()
        let completedPitch = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 1,
            body: .pitch(.init(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 1))
        )
        let completedPlay = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 2,
            body: .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        )
        let pendingPitch = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 3,
            body: .pitch(.init(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 2))
        )

        let replay = GameEventReplay.replay(
            records: [pendingPitch, completedPlay, completedPitch],
            homeAway: .home,
            startingPitcherID: pitcherID
        )
        let history = PlayHistoryProjector.project(replay: replay)

        #expect(history.sections.count == 1)
        #expect(history.sections[0].entries.count == 2)
        #expect(history.sections[0].entries[0].summary == "1B · Batter to 1B")
        #expect(history.sections[0].entries[0].components.map(\.sequenceNumber) == [1, 2])
        #expect(history.sections[0].entries[1].summary == "Ball In Play · Pending")
        #expect(history.sections[0].entries[1].components.map(\.sequenceNumber) == [3])
        #expect(history.sections[0].entries[1].accessibilityDescription.lowercased().contains("pending"))
    }

    @Test func trackedHistoryUsesEventTimeIdentityAndKeepsBaseRunningSeparate() throws {
        let playerID = UUID()
        let gameID = UUID()
        let batter = TrackedBatterIdentity(
            playerID: playerID,
            lineupSlot: 1,
            displayName: "Historic Batter",
            jerseyNumber: "8",
            position: .shortstop
        )
        let plateAppearance = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 1,
            body: .offensivePlateAppearance(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ))
        )
        let stolenBase = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 2,
            body: .offensiveBaseRunning(.init(
                runnerID: playerID,
                source: .first,
                destination: .second,
                result: .stolenBase
            ))
        )

        let replay = GameEventReplay.replay(
            records: [plateAppearance, stolenBase],
            homeAway: .away,
            startingPitcherID: nil
        )
        let history = PlayHistoryProjector.project(replay: replay)

        #expect(history.sections[0].entries.map(\.actor) == ["Historic Batter", "Historic Batter"])
        #expect(history.sections[0].entries[0].actorContext == "Batting 1 of 10 · #8 · SS")
        #expect(history.sections[0].entries[1].summary == "SB · 1B to 2B")
        #expect(history.sections[0].entries[1].accessibilityDescription.contains("Historic Batter"))
    }

    @Test func rejectedRecordsRemainExplicitAndDoNotHideFollowingHalfInning() throws {
        let pitcherID = UUID()
        let gameID = UUID()
        let malformed = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 1,
            body: .pitch(.init(result: .ball, pitcherID: pitcherID, opponentBatterSlot: 1))
        )
        malformed.payload = Data("not-json".utf8)
        let semanticallyRejected = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 2,
            body: .pitch(.init(result: .ball, pitcherID: pitcherID, opponentBatterSlot: 9))
        )
        let unknown = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 3,
            body: .pitch(.init(result: .ball, pitcherID: pitcherID, opponentBatterSlot: 1))
        )
        unknown.kindRawValue = "futureEvent"

        let replay = GameEventReplay.replay(
            records: [unknown, semanticallyRejected, malformed],
            homeAway: .home,
            startingPitcherID: pitcherID
        )
        let history = PlayHistoryProjector.project(replay: replay)

        #expect(history.sections[0].entries.map(\.summary) == [
            "Unreadable saved event",
            "Play conflicts with earlier history",
            "Unsupported saved event"
        ])
        #expect(history.sections[0].entries.allSatisfy { $0.isProblem })
        #expect(history.sections[0].entries.map(\.components).allSatisfy { $0.count == 1 })
    }

    @Test func historyGroupsEntriesByEventTimeHalfInning() throws {
        let pitcherID = UUID()
        let gameID = UUID()
        var records: [GameEventRecord] = []
        for slot in 1...3 {
            for _ in 1...3 {
                records.append(try GameEventRecord(
                    gameID: gameID,
                    sequenceNumber: records.count + 1,
                    body: .pitch(.init(
                        result: .calledStrike,
                        pitcherID: pitcherID,
                        opponentBatterSlot: slot
                    ))
                ))
            }
        }
        let homeBatter = TrackedBatterIdentity(
            playerID: UUID(),
            lineupSlot: 1,
            displayName: "Home Batter",
            jerseyNumber: "4",
            position: .catcher
        )
        records.append(try GameEventRecord(
            gameID: gameID,
            sequenceNumber: records.count + 1,
            body: .offensivePlateAppearance(.init(
                batter: homeBatter,
                battingOrderSize: 9,
                result: .walk,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ))
        ))

        let replay = GameEventReplay.replay(
            records: records,
            homeAway: .home,
            startingPitcherID: pitcherID
        )
        let history = PlayHistoryProjector.project(replay: replay)

        #expect(history.sections.map(\.title) == ["Top 1", "Bottom 1"])
        #expect(history.sections[0].entries.map(\.summary) == [
            "K · Batter out", "K · Batter out", "K · Batter out"
        ])
        #expect(history.sections[1].entries[0].actor == "Home Batter")
    }
}
