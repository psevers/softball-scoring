import Foundation
import Testing
@testable import SoftballScoring

struct BattingStatProjectorTests {
    @Test func walkCreditsPlateAppearanceAndWalkWithoutAtBat() throws {
        let batter = TrackedBatterIdentity(
            playerID: UUID(),
            lineupSlot: 1,
            displayName: "M. Wilson",
            jerseyNumber: "8",
            position: .leftField
        )
        let event = DecodedGameEvent(
            sequenceNumber: 1,
            timestamp: .now,
            body: .offensivePlateAppearance(OffensivePlateAppearanceEvent(
                batter: batter,
                battingOrderSize: 1,
                result: .walk,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ))
        )

        let projection = try BattingStatProjector.project(events: [event])

        #expect(projection[batter.playerID] == BattingLine(
            plateAppearances: 1,
            atBats: 0,
            runs: 0,
            hits: 0,
            doubles: 0,
            triples: 0,
            homeRuns: 0,
            runsBattedIn: 0,
            walks: 1,
            hitByPitch: 0,
            strikeouts: 0
        ))
    }

    @Test func laterBatterCreditsRunToOriginalRunnerAndRBIToCurrentBatter() throws {
        let runner = batter(slot: 1, name: "Runner")
        let hitter = batter(slot: 2, name: "Hitter")
        let events = [
            event(
                sequence: 1,
                batter: runner,
                result: .single,
                movements: [.init(source: .batter, destination: .first)]
            ),
            event(
                sequence: 2,
                batter: hitter,
                result: .double,
                movements: [
                    .init(source: .batter, destination: .second),
                    .init(source: .first, destination: .home)
                ],
                rbi: 1,
                countedRunSources: [.first]
            )
        ]

        let projection = try BattingStatProjector.project(events: events)

        #expect(projection[runner.playerID]?.runs == 1)
        #expect(projection[runner.playerID]?.hits == 1)
        #expect(projection[hitter.playerID]?.doubles == 1)
        #expect(projection[hitter.playerID]?.runsBattedIn == 1)
        #expect(projection[hitter.playerID]?.runs == 0)
    }

    @Test func missingEventTimeRunnerIdentityRejectsProjection() {
        let hitter = batter(slot: 1, name: "Hitter")
        let malformedAttribution = event(
            sequence: 4,
            batter: hitter,
            result: .double,
            movements: [
                .init(source: .batter, destination: .second),
                .init(source: .first, destination: .home)
            ],
            rbi: 1,
            countedRunSources: [.first]
        )

        #expect(throws: BattingStatProjectionError.missingRunnerIdentity(
            sequenceNumber: 4,
            source: .first
        )) {
            _ = try BattingStatProjector.project(events: [malformedAttribution])
        }
    }

    @Test func everyPlateAppearanceResultProjectsCanonicalCountingStats() throws {
        let atBatResults: Set<OffensivePlateAppearanceResult> = [
            .single, .double, .triple, .homeRun, .strikeout, .reachedOnError,
            .fieldersChoice, .groundOut, .flyOut, .lineOut, .popOut, .doublePlay
        ]
        let hitResults: Set<OffensivePlateAppearanceResult> = [.single, .double, .triple, .homeRun]

        for result in OffensivePlateAppearanceResult.allCases {
            let batter = batter(slot: 1, name: result.rawValue)
            let projection = try BattingStatProjector.project(events: [event(
                sequence: 1,
                batter: batter,
                result: result,
                movements: [.init(
                    source: .batter,
                    destination: hitResults.contains(result) ? .first : .out
                )]
            )])
            let line = try #require(projection[batter.playerID])

            #expect(line.plateAppearances == 1, "\(result.rawValue) PA")
            #expect(line.atBats == (atBatResults.contains(result) ? 1 : 0), "\(result.rawValue) AB")
            #expect(line.hits == (hitResults.contains(result) ? 1 : 0), "\(result.rawValue) H")
            #expect(line.doubles == (result == .double ? 1 : 0), "\(result.rawValue) 2B")
            #expect(line.triples == (result == .triple ? 1 : 0), "\(result.rawValue) 3B")
            #expect(line.homeRuns == (result == .homeRun ? 1 : 0), "\(result.rawValue) HR")
            #expect(line.walks == (result == .walk ? 1 : 0), "\(result.rawValue) BB")
            #expect(line.hitByPitch == (result == .hitByPitch ? 1 : 0), "\(result.rawValue) HBP")
            #expect(line.strikeouts == (result == .strikeout ? 1 : 0), "\(result.rawValue) SO")
        }
    }

    @Test func stealOfHomeCreditsRunAndStolenBaseWithoutRBI() throws {
        let runner = batter(slot: 1, name: "Runner")
        let steal = DecodedGameEvent(
            sequenceNumber: 2,
            timestamp: Date(timeIntervalSince1970: 2),
            body: .offensiveBaseRunning(OffensiveBaseRunningEvent(
                runnerID: runner.playerID,
                source: .third,
                destination: .home,
                result: .stolenBase
            ))
        )
        let projection = try BattingStatProjector.project(events: [
            event(
                sequence: 1,
                batter: runner,
                result: .triple,
                movements: [.init(source: .batter, destination: .third)]
            ),
            steal
        ])
        let line = try #require(projection[runner.playerID])

        #expect(line.runs == 1)
        #expect(line.stolenBases == 1)
        #expect(line.runsBattedIn == 0)
    }

    private func batter(slot: Int, name: String) -> TrackedBatterIdentity {
        TrackedBatterIdentity(
            playerID: UUID(),
            lineupSlot: slot,
            displayName: name,
            jerseyNumber: "\(slot)",
            position: nil
        )
    }

    private func event(
        sequence: Int,
        batter: TrackedBatterIdentity,
        result: OffensivePlateAppearanceResult,
        movements: [RunnerMovementEvent],
        rbi: Int = 0,
        countedRunSources: [RunnerSource] = []
    ) -> DecodedGameEvent {
        DecodedGameEvent(
            sequenceNumber: sequence,
            timestamp: Date(timeIntervalSince1970: TimeInterval(sequence)),
            body: .offensivePlateAppearance(OffensivePlateAppearanceEvent(
                batter: batter,
                battingOrderSize: max(2, batter.lineupSlot),
                result: result,
                movements: movements,
                rbi: rbi,
                countedRunSources: countedRunSources,
                thirdOutClassification: nil
            ))
        )
    }
}
