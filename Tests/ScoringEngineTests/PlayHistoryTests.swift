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
        #expect(history.sections[0].entries[0].deletableDefensiveLogicalPlayResultRecordID == completedPlay.id)
        #expect(history.sections[0].entries[1].summary == "Ball In Play · Pending")
        #expect(history.sections[0].entries[1].components.map(\.sequenceNumber) == [3])
        #expect(history.sections[0].entries[1].deletableDefensiveLogicalPlayResultRecordID == nil)
        #expect(history.sections[0].entries[1].accessibilityDescription.lowercased().contains("pending"))
    }

    @Test func unreadableRecordDoesNotSplitCompletedBallInPlay() throws {
        let pitcherID = UUID()
        let gameID = UUID()
        let pitch = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 1,
            body: .pitch(.init(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 1))
        )
        let unreadable = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 2,
            body: .pitch(.init(result: .ball, pitcherID: pitcherID, opponentBatterSlot: 1))
        )
        unreadable.payload = Data("not-json".utf8)
        let play = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 3,
            body: .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        )

        let replay = GameEventReplay.replay(
            records: [play, unreadable, pitch],
            homeAway: .home,
            startingPitcherID: pitcherID
        )
        let entries = PlayHistoryProjector.project(replay: replay).sections[0].entries

        #expect(entries.count == 2)
        #expect(entries[0].summary == "1B · Batter to 1B")
        #expect(entries[0].components.map(\.sequenceNumber) == [1, 3])
        #expect(entries[1].isProblem)
        #expect(entries[1].components.map(\.sequenceNumber) == [2])
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

    @Test func baseRunningDoesNotUseIdentityFromALaterEvent() {
        let playerID = UUID()
        let original = TrackedBatterIdentity(
            playerID: playerID,
            lineupSlot: 1,
            displayName: "Original Name",
            jerseyNumber: "8",
            position: .shortstop
        )
        let updated = TrackedBatterIdentity(
            playerID: playerID,
            lineupSlot: 4,
            displayName: "Future Name",
            jerseyNumber: "18",
            position: .leftField
        )
        let plateAppearance = OffensivePlateAppearanceEvent(
            batter: original,
            battingOrderSize: 10,
            result: .single,
            movements: [.init(source: .batter, destination: .first)],
            rbi: 0,
            countedRunSources: [],
            thirdOutClassification: nil
        )
        let running = OffensiveBaseRunningEvent(
            runnerID: playerID,
            source: .first,
            destination: .second,
            result: .stolenBase
        )
        let futurePlateAppearance = OffensivePlateAppearanceEvent(
            batter: updated,
            battingOrderSize: 12,
            result: .single,
            movements: [.init(source: .batter, destination: .first)],
            rbi: 0,
            countedRunSources: [],
            thirdOutClassification: nil
        )
        let replay = GameEventReplay.Result(
            state: GameState(),
            rejectedRecordIDs: [],
            entries: [
                acceptedEntry(sequence: 1, body: .offensivePlateAppearance(plateAppearance)),
                acceptedEntry(sequence: 2, body: .offensiveBaseRunning(running)),
                acceptedEntry(sequence: 3, body: .offensivePlateAppearance(futurePlateAppearance))
            ]
        )

        let entries = PlayHistoryProjector.project(replay: replay).sections[0].entries

        #expect(entries[1].actor == "Original Name")
        #expect(entries[1].actorContext == "Batting 1 of 10 · #8 · SS")
    }

    @Test func automaticDefensiveCompletionsDescribeMaterialStateChanges() {
        let pitcherID = UUID()
        var walkBefore = GameState()
        walkBefore.balls = 3
        walkBefore.firstBaseRunnerSlot = 2
        walkBefore.secondBaseRunnerSlot = 3
        walkBefore.thirdBaseRunnerSlot = 4
        var walkAfter = walkBefore
        walkAfter.balls = 0
        walkAfter.awayScore = 1
        walkAfter.currentOpponentBatterSlot = 2
        walkAfter.firstBaseRunnerSlot = 1
        walkAfter.secondBaseRunnerSlot = 2
        walkAfter.thirdBaseRunnerSlot = 3

        var strikeoutBefore = GameState()
        strikeoutBefore.outs = 2
        strikeoutBefore.strikes = 2
        strikeoutBefore.currentOpponentBatterSlot = 2
        var strikeoutAfter = GameState()
        strikeoutAfter.half = .bottom

        let replay = GameEventReplay.Result(
            state: strikeoutAfter,
            rejectedRecordIDs: [],
            entries: [
                acceptedEntry(
                    sequence: 1,
                    body: .pitch(.init(result: .ball, pitcherID: pitcherID, opponentBatterSlot: 1)),
                    before: walkBefore,
                    after: walkAfter
                ),
                acceptedEntry(
                    sequence: 2,
                    body: .pitch(.init(
                        result: .calledStrike,
                        pitcherID: pitcherID,
                        opponentBatterSlot: 2
                    )),
                    before: strikeoutBefore,
                    after: strikeoutAfter
                )
            ]
        )

        let sections = PlayHistoryProjector.project(replay: replay).sections

        #expect(sections[0].entries[0].detail.contains("1 run scored"))
        #expect(sections[0].entries[0].detail.contains("3 runners on base"))
        #expect(sections[0].entries[1].detail.contains("Inning advanced to Bottom 1"))
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

    @Test func onlyNonTerminalDefensiveCountPitchesExposeTheirEditResult() throws {
        let pitcherID = UUID()
        let gameID = UUID()
        let records = try [
            PitchResult.ball,
            .calledStrike,
            .swingingStrike,
            .foul,
            .ballInPlay
        ].enumerated().map { index, result in
            try GameEventRecord(
                gameID: gameID,
                sequenceNumber: index + 1,
                body: .pitch(.init(
                    result: result,
                    pitcherID: pitcherID,
                    opponentBatterSlot: 1
                ))
            )
        }
        let replay = GameEventReplay.replay(
            records: records,
            homeAway: .home,
            startingPitcherID: pitcherID
        )

        let components = PlayHistoryProjector.project(replay: replay)
            .sections[0].entries[0].components

        #expect(components.map(\.editableDefensivePitchResult) == [
            .ball,
            .calledStrike,
            .swingingStrike,
            .foul,
            nil
        ])
    }

    @Test func trackedTeamPitchesExposeTheirEventTimeResultForEditing() throws {
        let batter = TrackedBatterIdentity(
            playerID: UUID(),
            lineupSlot: 1,
            displayName: "Avery Stone",
            jerseyNumber: "8",
            position: .shortstop
        )
        let records = try OffensivePitchResult.allCases.enumerated().map { index, result in
            try GameEventRecord(
                gameID: UUID(),
                sequenceNumber: index + 1,
                body: .offensivePitch(.init(
                    batter: batter,
                    battingOrderSize: 10,
                    result: result
                ))
            )
        }
        let replay = GameEventReplay.replay(
            records: records,
            homeAway: .away,
            startingPitcherID: UUID()
        )

        let entry = try #require(PlayHistoryProjector.project(replay: replay).sections.first?.entries.first)

        #expect(entry.actor == "Avery Stone")
        #expect(entry.actorContext == "Batting 1 of 10 · #8 · SS")
        #expect(entry.components.map(\.editableOffensivePitchResult) == OffensivePitchResult.allCases)
    }

    @Test func trackedPlateAppearancesIncludingThirdOutExposeTheirEditResult() throws {
        let batter = TrackedBatterIdentity(
            playerID: UUID(),
            lineupSlot: 1,
            displayName: "Avery Stone",
            jerseyNumber: "8",
            position: .shortstop
        )
        let editable = OffensivePlateAppearanceEvent(
            batter: batter,
            battingOrderSize: 10,
            result: .single,
            movements: [.init(source: .batter, destination: .first)],
            rbi: 0,
            countedRunSources: [],
            thirdOutClassification: nil
        )
        let scoring = OffensivePlateAppearanceEvent(
            batter: batter,
            battingOrderSize: 10,
            result: .homeRun,
            movements: [.init(source: .batter, destination: .home)],
            rbi: 1,
            countedRunSources: [.batter],
            thirdOutClassification: nil
        )
        let thirdOut = OffensivePlateAppearanceEvent(
            batter: batter,
            battingOrderSize: 10,
            result: .groundOut,
            movements: [.init(source: .batter, destination: .out)],
            rbi: 0,
            countedRunSources: [],
            thirdOutClassification: nil
        )
        var thirdOutState = GameState()
        thirdOutState.outs = 2
        let history = PlayHistoryProjector.project(replay: .init(
            state: GameState(),
            rejectedRecordIDs: [],
            entries: [
                acceptedEntry(sequence: 1, body: .offensivePlateAppearance(editable)),
                acceptedEntry(sequence: 2, body: .offensivePlateAppearance(scoring)),
                acceptedEntry(
                    sequence: 3,
                    body: .offensivePlateAppearance(thirdOut),
                    before: thirdOutState
                )
            ]
        ))
        let components = history.sections.flatMap(\.entries).flatMap(\.components)

        #expect(
            components.map(\.editableOffensivePlateAppearanceResult)
                == [.single, .homeRun, .groundOut]
        )
    }

    @Test func correctionEligibilityIncludesMultiOutAndThirdOutPlays() {
        var state = GameState()
        let homeRun = BallInPlayEvent(
            outcome: .homeRun,
            opponentBatterSlot: 1,
            movements: [.init(source: .batter, destination: .home)],
            rbi: 1,
            thirdOutRunsCounted: nil
        )
        let doublePlay = BallInPlayEvent(
            outcome: .doublePlay,
            opponentBatterSlot: 1,
            movements: [
                .init(source: .batter, destination: .out),
                .init(source: .first, destination: .out)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        )

        #expect(BallInPlayValidator.supportsCorrection(homeRun, stateBefore: state))
        #expect(BallInPlayValidator.supportsCorrection(doublePlay, stateBefore: state))

        state.outs = 2
        #expect(BallInPlayValidator.correctionOutcomes(for: state).contains(.homeRun))
        #expect(BallInPlayValidator.correctionOutcomes(for: state).contains(.groundOut))
        #expect(!BallInPlayValidator.correctionOutcomes(for: state).contains(.sacrificeFly))
        #expect(!BallInPlayValidator.correctionOutcomes(for: state).contains(.doublePlay))
        let thirdOut = BallInPlayEvent(
            outcome: .groundOut,
            opponentBatterSlot: 1,
            movements: [.init(source: .batter, destination: .out)],
            rbi: 0,
            thirdOutRunsCounted: nil
        )
        #expect(BallInPlayValidator.supportsCorrection(thirdOut, stateBefore: state))
    }

    private func acceptedEntry(
        sequence: Int,
        body: GameEventBody,
        before: GameState = GameState(),
        after: GameState = GameState()
    ) -> GameEventReplay.Entry {
        GameEventReplay.Entry(
            recordID: UUID(),
            sequenceNumber: sequence,
            timestamp: Date(timeIntervalSince1970: TimeInterval(sequence)),
            body: body,
            stateBefore: before,
            stateAfter: after,
            rejection: nil
        )
    }
}
