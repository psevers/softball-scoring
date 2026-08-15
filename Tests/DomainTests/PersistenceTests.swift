import Foundation
import SwiftData
import Testing
@testable import SoftballScoring

private struct TrackedPlateAppearanceUndoScenario: Sendable {
    let result: OffensivePlateAppearanceResult
    let movements: [RunnerMovementEvent]
    let rbi: Int
    let countedRunSources: [RunnerSource]
}

private struct DefensiveBallInPlayCorrectionScenario: Sendable {
    let outcome: BallInPlayOutcome
    let movements: [RunnerMovementEvent]
    let startsWithRunnerOnFirst: Bool
    let expectedOuts: Int
    let expectedBases: [Int?]
}

private struct OffensivePlateAppearanceCorrectionScenario: Sendable {
    let result: OffensivePlateAppearanceResult
    let startsWithRunnerOnFirst: Bool
    let movements: [RunnerMovementEvent]
    let expectedOuts: Int
    let expectedBaseSources: [RunnerSource?]
    let expectedAtBats: Int
    let expectedHits: Int
    let expectedDoubles: Int
    let expectedTriples: Int
    let expectedWalks: Int
    let expectedHitByPitch: Int
    let expectedStrikeouts: Int
}

private struct OffensivePlateAppearanceShape: Sendable {
    let result: OffensivePlateAppearanceResult
    let movements: [RunnerMovementEvent]
    let rbi: Int
    let countedRunSources: [RunnerSource]
}

private struct OffensiveScoringCorrectionScenario: Sendable {
    let name: String
    let setup: [OffensivePlateAppearanceShape]
    let original: OffensivePlateAppearanceShape
    let proposed: OffensivePlateAppearanceShape
    let expectedScore: Int
    let expectedOuts: Int
    let expectedBaseSources: [RunnerSource?]
    let expectedRunsBySource: [RunnerSource: Int]
    let expectedBatterRBI: Int
}

private struct OffensiveScoringRemovalScenario: Sendable {
    let name: String
    let proposed: OffensivePlateAppearanceShape
    let expectedOuts: Int
    let expectedBaseSources: [RunnerSource?]
}

private let offensivePlateAppearanceCorrectionScenarios: [OffensivePlateAppearanceCorrectionScenario] = [
    .init(
        result: .walk,
        startsWithRunnerOnFirst: false,
        movements: [.init(source: .batter, destination: .first)],
        expectedOuts: 0,
        expectedBaseSources: [.batter, nil, nil],
        expectedAtBats: 0,
        expectedHits: 0,
        expectedDoubles: 0,
        expectedTriples: 0,
        expectedWalks: 1,
        expectedHitByPitch: 0,
        expectedStrikeouts: 0
    ),
    .init(
        result: .hitByPitch,
        startsWithRunnerOnFirst: false,
        movements: [.init(source: .batter, destination: .first)],
        expectedOuts: 0,
        expectedBaseSources: [.batter, nil, nil],
        expectedAtBats: 0,
        expectedHits: 0,
        expectedDoubles: 0,
        expectedTriples: 0,
        expectedWalks: 0,
        expectedHitByPitch: 1,
        expectedStrikeouts: 0
    ),
    .init(
        result: .strikeout,
        startsWithRunnerOnFirst: false,
        movements: [.init(source: .batter, destination: .out)],
        expectedOuts: 1,
        expectedBaseSources: [nil, nil, nil],
        expectedAtBats: 1,
        expectedHits: 0,
        expectedDoubles: 0,
        expectedTriples: 0,
        expectedWalks: 0,
        expectedHitByPitch: 0,
        expectedStrikeouts: 1
    ),
    .init(
        result: .single,
        startsWithRunnerOnFirst: false,
        movements: [.init(source: .batter, destination: .first)],
        expectedOuts: 0,
        expectedBaseSources: [.batter, nil, nil],
        expectedAtBats: 1,
        expectedHits: 1,
        expectedDoubles: 0,
        expectedTriples: 0,
        expectedWalks: 0,
        expectedHitByPitch: 0,
        expectedStrikeouts: 0
    ),
    .init(
        result: .double,
        startsWithRunnerOnFirst: false,
        movements: [.init(source: .batter, destination: .second)],
        expectedOuts: 0,
        expectedBaseSources: [nil, .batter, nil],
        expectedAtBats: 1,
        expectedHits: 1,
        expectedDoubles: 1,
        expectedTriples: 0,
        expectedWalks: 0,
        expectedHitByPitch: 0,
        expectedStrikeouts: 0
    ),
    .init(
        result: .triple,
        startsWithRunnerOnFirst: false,
        movements: [.init(source: .batter, destination: .third)],
        expectedOuts: 0,
        expectedBaseSources: [nil, nil, .batter],
        expectedAtBats: 1,
        expectedHits: 1,
        expectedDoubles: 0,
        expectedTriples: 1,
        expectedWalks: 0,
        expectedHitByPitch: 0,
        expectedStrikeouts: 0
    ),
    .init(
        result: .reachedOnError,
        startsWithRunnerOnFirst: false,
        movements: [.init(source: .batter, destination: .first)],
        expectedOuts: 0,
        expectedBaseSources: [.batter, nil, nil],
        expectedAtBats: 1,
        expectedHits: 0,
        expectedDoubles: 0,
        expectedTriples: 0,
        expectedWalks: 0,
        expectedHitByPitch: 0,
        expectedStrikeouts: 0
    ),
    .init(
        result: .fieldersChoice,
        startsWithRunnerOnFirst: true,
        movements: [
            .init(source: .first, destination: .out),
            .init(source: .batter, destination: .first)
        ],
        expectedOuts: 1,
        expectedBaseSources: [.batter, nil, nil],
        expectedAtBats: 1,
        expectedHits: 0,
        expectedDoubles: 0,
        expectedTriples: 0,
        expectedWalks: 0,
        expectedHitByPitch: 0,
        expectedStrikeouts: 0
    ),
    .init(
        result: .groundOut,
        startsWithRunnerOnFirst: false,
        movements: [.init(source: .batter, destination: .out)],
        expectedOuts: 1,
        expectedBaseSources: [nil, nil, nil],
        expectedAtBats: 1,
        expectedHits: 0,
        expectedDoubles: 0,
        expectedTriples: 0,
        expectedWalks: 0,
        expectedHitByPitch: 0,
        expectedStrikeouts: 0
    ),
    .init(
        result: .sacrificeBunt,
        startsWithRunnerOnFirst: true,
        movements: [
            .init(source: .first, destination: .second),
            .init(source: .batter, destination: .out)
        ],
        expectedOuts: 1,
        expectedBaseSources: [nil, .first, nil],
        expectedAtBats: 0,
        expectedHits: 0,
        expectedDoubles: 0,
        expectedTriples: 0,
        expectedWalks: 0,
        expectedHitByPitch: 0,
        expectedStrikeouts: 0
    ),
    .init(
        result: .doublePlay,
        startsWithRunnerOnFirst: true,
        movements: [
            .init(source: .first, destination: .out),
            .init(source: .batter, destination: .out)
        ],
        expectedOuts: 2,
        expectedBaseSources: [nil, nil, nil],
        expectedAtBats: 1,
        expectedHits: 0,
        expectedDoubles: 0,
        expectedTriples: 0,
        expectedWalks: 0,
        expectedHitByPitch: 0,
        expectedStrikeouts: 0
    )
]

private let basesLoadedSetup: [OffensivePlateAppearanceShape] = [
    .init(
        result: .single,
        movements: [.init(source: .batter, destination: .first)],
        rbi: 0,
        countedRunSources: []
    ),
    .init(
        result: .single,
        movements: [
            .init(source: .first, destination: .second),
            .init(source: .batter, destination: .first)
        ],
        rbi: 0,
        countedRunSources: []
    ),
    .init(
        result: .single,
        movements: [
            .init(source: .second, destination: .third),
            .init(source: .first, destination: .second),
            .init(source: .batter, destination: .first)
        ],
        rbi: 0,
        countedRunSources: []
    )
]

private let runnerOnFirstSetup: [OffensivePlateAppearanceShape] = [
    .init(
        result: .single,
        movements: [.init(source: .batter, destination: .first)],
        rbi: 0,
        countedRunSources: []
    )
]

private let runnerOnThirdSetup: [OffensivePlateAppearanceShape] = [
    .init(
        result: .triple,
        movements: [.init(source: .batter, destination: .third)],
        rbi: 0,
        countedRunSources: []
    )
]

private let basesLoadedAward: [RunnerMovementEvent] = [
    .init(source: .third, destination: .home),
    .init(source: .second, destination: .third),
    .init(source: .first, destination: .second),
    .init(source: .batter, destination: .first)
]

private let offensiveScoringCorrectionScenarios: [OffensiveScoringCorrectionScenario] = [
    .init(
        name: "bases-loaded hit",
        setup: basesLoadedSetup,
        original: .init(
            result: .single,
            movements: basesLoadedAward,
            rbi: 1,
            countedRunSources: [.third]
        ),
        proposed: .init(
            result: .single,
            movements: [
                .init(source: .third, destination: .home),
                .init(source: .second, destination: .home),
                .init(source: .first, destination: .third),
                .init(source: .batter, destination: .first)
            ],
            rbi: 2,
            countedRunSources: [.third, .second]
        ),
        expectedScore: 2,
        expectedOuts: 0,
        expectedBaseSources: [.batter, nil, .first],
        expectedRunsBySource: [.third: 1, .second: 1],
        expectedBatterRBI: 2
    ),
    .init(
        name: "extra-base hit",
        setup: runnerOnFirstSetup,
        original: .init(
            result: .reachedOnError,
            movements: [
                .init(source: .first, destination: .home),
                .init(source: .batter, destination: .first)
            ],
            rbi: 0,
            countedRunSources: [.first]
        ),
        proposed: .init(
            result: .double,
            movements: [
                .init(source: .first, destination: .home),
                .init(source: .batter, destination: .second)
            ],
            rbi: 1,
            countedRunSources: [.first]
        ),
        expectedScore: 1,
        expectedOuts: 0,
        expectedBaseSources: [nil, .batter, nil],
        expectedRunsBySource: [.first: 1],
        expectedBatterRBI: 1
    ),
    .init(
        name: "home run",
        setup: runnerOnFirstSetup,
        original: .init(
            result: .double,
            movements: [
                .init(source: .first, destination: .home),
                .init(source: .batter, destination: .second)
            ],
            rbi: 1,
            countedRunSources: [.first]
        ),
        proposed: .init(
            result: .homeRun,
            movements: [
                .init(source: .first, destination: .home),
                .init(source: .batter, destination: .home)
            ],
            rbi: 2,
            countedRunSources: [.first, .batter]
        ),
        expectedScore: 2,
        expectedOuts: 0,
        expectedBaseSources: [nil, nil, nil],
        expectedRunsBySource: [.first: 1, .batter: 1],
        expectedBatterRBI: 2
    ),
    .init(
        name: "error without RBI",
        setup: runnerOnThirdSetup,
        original: .init(
            result: .sacrificeFly,
            movements: [
                .init(source: .third, destination: .home),
                .init(source: .batter, destination: .out)
            ],
            rbi: 1,
            countedRunSources: [.third]
        ),
        proposed: .init(
            result: .reachedOnError,
            movements: [
                .init(source: .third, destination: .home),
                .init(source: .batter, destination: .first)
            ],
            rbi: 0,
            countedRunSources: [.third]
        ),
        expectedScore: 1,
        expectedOuts: 0,
        expectedBaseSources: [.batter, nil, nil],
        expectedRunsBySource: [.third: 1],
        expectedBatterRBI: 0
    ),
    .init(
        name: "sacrifice fly",
        setup: runnerOnThirdSetup,
        original: .init(
            result: .reachedOnError,
            movements: [
                .init(source: .third, destination: .home),
                .init(source: .batter, destination: .first)
            ],
            rbi: 0,
            countedRunSources: [.third]
        ),
        proposed: .init(
            result: .sacrificeFly,
            movements: [
                .init(source: .third, destination: .home),
                .init(source: .batter, destination: .out)
            ],
            rbi: 1,
            countedRunSources: [.third]
        ),
        expectedScore: 1,
        expectedOuts: 1,
        expectedBaseSources: [nil, nil, nil],
        expectedRunsBySource: [.third: 1],
        expectedBatterRBI: 1
    ),
    .init(
        name: "bases-loaded walk",
        setup: basesLoadedSetup,
        original: .init(
            result: .hitByPitch,
            movements: basesLoadedAward,
            rbi: 1,
            countedRunSources: [.third]
        ),
        proposed: .init(
            result: .walk,
            movements: basesLoadedAward,
            rbi: 1,
            countedRunSources: [.third]
        ),
        expectedScore: 1,
        expectedOuts: 0,
        expectedBaseSources: [.batter, .first, .second],
        expectedRunsBySource: [.third: 1],
        expectedBatterRBI: 1
    ),
    .init(
        name: "bases-loaded HBP",
        setup: basesLoadedSetup,
        original: .init(
            result: .walk,
            movements: basesLoadedAward,
            rbi: 1,
            countedRunSources: [.third]
        ),
        proposed: .init(
            result: .hitByPitch,
            movements: basesLoadedAward,
            rbi: 1,
            countedRunSources: [.third]
        ),
        expectedScore: 1,
        expectedOuts: 0,
        expectedBaseSources: [.batter, .first, .second],
        expectedRunsBySource: [.third: 1],
        expectedBatterRBI: 1
    )
]

private let offensiveScoringRemovalScenarios: [OffensiveScoringRemovalScenario] = [
    .init(
        name: "home to base",
        proposed: .init(
            result: .double,
            movements: [
                .init(source: .first, destination: .third),
                .init(source: .batter, destination: .second)
            ],
            rbi: 0,
            countedRunSources: []
        ),
        expectedOuts: 0,
        expectedBaseSources: [nil, .batter, .first]
    ),
    .init(
        name: "home to out",
        proposed: .init(
            result: .fieldersChoice,
            movements: [
                .init(source: .first, destination: .out),
                .init(source: .batter, destination: .first)
            ],
            rbi: 0,
            countedRunSources: []
        ),
        expectedOuts: 1,
        expectedBaseSources: [.batter, nil, nil]
    )
]

private let defensiveBallInPlayCorrectionScenarios: [DefensiveBallInPlayCorrectionScenario] = [
    .init(
        outcome: .single,
        movements: [.init(source: .batter, destination: .first)],
        startsWithRunnerOnFirst: false,
        expectedOuts: 0,
        expectedBases: [1, nil, nil]
    ),
    .init(
        outcome: .double,
        movements: [.init(source: .batter, destination: .second)],
        startsWithRunnerOnFirst: false,
        expectedOuts: 0,
        expectedBases: [nil, 1, nil]
    ),
    .init(
        outcome: .triple,
        movements: [.init(source: .batter, destination: .third)],
        startsWithRunnerOnFirst: false,
        expectedOuts: 0,
        expectedBases: [nil, nil, 1]
    ),
    .init(
        outcome: .fieldersChoice,
        movements: [
            .init(source: .batter, destination: .first),
            .init(source: .first, destination: .out)
        ],
        startsWithRunnerOnFirst: true,
        expectedOuts: 1,
        expectedBases: [2, nil, nil]
    ),
    .init(
        outcome: .groundOut,
        movements: [.init(source: .batter, destination: .out)],
        startsWithRunnerOnFirst: false,
        expectedOuts: 1,
        expectedBases: [nil, nil, nil]
    ),
    .init(
        outcome: .sacrificeBunt,
        movements: [
            .init(source: .batter, destination: .out),
            .init(source: .first, destination: .second)
        ],
        startsWithRunnerOnFirst: true,
        expectedOuts: 1,
        expectedBases: [nil, 1, nil]
    )
]

private struct DefensiveScoringCorrectionScenario: Sendable {
    let name: String
    let setupPlays: [BallInPlayEvent]
    let originalPlay: BallInPlayEvent
    let proposedPlay: BallInPlayEvent
    let expectedScore: Int
    let expectedOuts: Int
    let expectedBases: [Int?]
}

private struct ScoringDestinationRemovalScenario: Sendable {
    let name: String
    let replacement: BallInPlayEvent
    let expectedOuts: Int
    let expectedBases: [Int?]
}

private let defensiveScoringCorrectionScenarios: [DefensiveScoringCorrectionScenario] = [
    .init(
        name: "bases-loaded hit",
        setupPlays: [
            .init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ),
            .init(
                outcome: .single,
                opponentBatterSlot: 2,
                movements: [
                    .init(source: .batter, destination: .first),
                    .init(source: .first, destination: .second)
                ],
                rbi: 0,
                thirdOutRunsCounted: nil
            ),
            .init(
                outcome: .single,
                opponentBatterSlot: 3,
                movements: [
                    .init(source: .batter, destination: .first),
                    .init(source: .first, destination: .second),
                    .init(source: .second, destination: .third)
                ],
                rbi: 0,
                thirdOutRunsCounted: nil
            )
        ],
        originalPlay: .init(
            outcome: .fieldersChoice,
            opponentBatterSlot: 4,
            movements: [
                .init(source: .batter, destination: .first),
                .init(source: .first, destination: .second),
                .init(source: .second, destination: .third),
                .init(source: .third, destination: .out)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        ),
        proposedPlay: .init(
            outcome: .single,
            opponentBatterSlot: 4,
            movements: [
                .init(source: .batter, destination: .first),
                .init(source: .first, destination: .second),
                .init(source: .second, destination: .home),
                .init(source: .third, destination: .home)
            ],
            rbi: 2,
            thirdOutRunsCounted: nil
        ),
        expectedScore: 2,
        expectedOuts: 0,
        expectedBases: [4, 3, nil]
    ),
    .init(
        name: "extra-base hit",
        setupPlays: [
            .init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            )
        ],
        originalPlay: .init(
            outcome: .reachedOnError,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .first),
                .init(source: .first, destination: .second)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        ),
        proposedPlay: .init(
            outcome: .double,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .second),
                .init(source: .first, destination: .home)
            ],
            rbi: 1,
            thirdOutRunsCounted: nil
        ),
        expectedScore: 1,
        expectedOuts: 0,
        expectedBases: [nil, 2, nil]
    ),
    .init(
        name: "home run",
        setupPlays: [
            .init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            )
        ],
        originalPlay: .init(
            outcome: .reachedOnError,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .first),
                .init(source: .first, destination: .second)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        ),
        proposedPlay: .init(
            outcome: .homeRun,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .home),
                .init(source: .first, destination: .home)
            ],
            rbi: 2,
            thirdOutRunsCounted: nil
        ),
        expectedScore: 2,
        expectedOuts: 0,
        expectedBases: [nil, nil, nil]
    ),
    .init(
        name: "error without RBI",
        setupPlays: [
            .init(
                outcome: .triple,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .third)],
                rbi: 0,
                thirdOutRunsCounted: nil
            )
        ],
        originalPlay: .init(
            outcome: .reachedOnError,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .first),
                .init(source: .third, destination: .third)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        ),
        proposedPlay: .init(
            outcome: .reachedOnError,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .first),
                .init(source: .third, destination: .home)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        ),
        expectedScore: 1,
        expectedOuts: 0,
        expectedBases: [2, nil, nil]
    ),
    .init(
        name: "sacrifice fly",
        setupPlays: [
            .init(
                outcome: .triple,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .third)],
                rbi: 0,
                thirdOutRunsCounted: nil
            )
        ],
        originalPlay: .init(
            outcome: .reachedOnError,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .first),
                .init(source: .third, destination: .third)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        ),
        proposedPlay: .init(
            outcome: .sacrificeFly,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .out),
                .init(source: .third, destination: .home)
            ],
            rbi: 1,
            thirdOutRunsCounted: nil
        ),
        expectedScore: 1,
        expectedOuts: 1,
        expectedBases: [nil, nil, nil]
    ),
    .init(
        name: "fielder's choice",
        setupPlays: [
            .init(
                outcome: .triple,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .third)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ),
            .init(
                outcome: .single,
                opponentBatterSlot: 2,
                movements: [
                    .init(source: .batter, destination: .first),
                    .init(source: .third, destination: .third)
                ],
                rbi: 0,
                thirdOutRunsCounted: nil
            )
        ],
        originalPlay: .init(
            outcome: .reachedOnError,
            opponentBatterSlot: 3,
            movements: [
                .init(source: .batter, destination: .first),
                .init(source: .first, destination: .second),
                .init(source: .third, destination: .third)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        ),
        proposedPlay: .init(
            outcome: .fieldersChoice,
            opponentBatterSlot: 3,
            movements: [
                .init(source: .batter, destination: .first),
                .init(source: .first, destination: .out),
                .init(source: .third, destination: .home)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        ),
        expectedScore: 1,
        expectedOuts: 1,
        expectedBases: [3, nil, nil]
    )
]

private let scoringDestinationRemovalScenarios: [ScoringDestinationRemovalScenario] = [
    .init(
        name: "home to base",
        replacement: defensiveScoringCorrectionScenarios[1].originalPlay,
        expectedOuts: 0,
        expectedBases: [2, 1, nil]
    ),
    .init(
        name: "home to out",
        replacement: .init(
            outcome: .fieldersChoice,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .first),
                .init(source: .first, destination: .out)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        ),
        expectedOuts: 1,
        expectedBases: [2, nil, nil]
    )
]

private let trackedPlateAppearanceUndoScenarios: [TrackedPlateAppearanceUndoScenario] = [
    .init(
        result: .walk,
        movements: [
            .init(source: .first, destination: .second),
            .init(source: .batter, destination: .first)
        ],
        rbi: 0,
        countedRunSources: []
    ),
    .init(
        result: .hitByPitch,
        movements: [
            .init(source: .first, destination: .second),
            .init(source: .batter, destination: .first)
        ],
        rbi: 0,
        countedRunSources: []
    ),
    .init(
        result: .strikeout,
        movements: [
            .init(source: .first, destination: .first),
            .init(source: .batter, destination: .out)
        ],
        rbi: 0,
        countedRunSources: []
    ),
    .init(
        result: .double,
        movements: [
            .init(source: .first, destination: .home),
            .init(source: .batter, destination: .second)
        ],
        rbi: 1,
        countedRunSources: [.first]
    ),
    .init(
        result: .reachedOnError,
        movements: [
            .init(source: .first, destination: .second),
            .init(source: .batter, destination: .first)
        ],
        rbi: 0,
        countedRunSources: []
    ),
    .init(
        result: .homeRun,
        movements: [
            .init(source: .first, destination: .home),
            .init(source: .batter, destination: .home)
        ],
        rbi: 2,
        countedRunSources: [.first, .batter]
    ),
    .init(
        result: .sacrificeFly,
        movements: [
            .init(source: .first, destination: .home),
            .init(source: .batter, destination: .out)
        ],
        rbi: 1,
        countedRunSources: [.first]
    ),
    .init(
        result: .flyOut,
        movements: [
            .init(source: .first, destination: .first),
            .init(source: .batter, destination: .out)
        ],
        rbi: 0,
        countedRunSources: []
    ),
    .init(
        result: .doublePlay,
        movements: [
            .init(source: .first, destination: .out),
            .init(source: .batter, destination: .out)
        ],
        rbi: 0,
        countedRunSources: []
    )
]

private struct DefensivePitchEditScenario: Sendable {
    let precedingResults: [PitchResult]
    let originalResult: PitchResult
    let proposedResult: PitchResult
    let expectedBalls: Int
    let expectedStrikes: Int
    let expectedBatterSlot: Int
    let expectedOuts: Int
}

private let defensivePitchEditScenarios: [DefensivePitchEditScenario] = [
    .init(
        precedingResults: [.ball, .ball, .ball, .calledStrike],
        originalResult: .foul,
        proposedResult: .ball,
        expectedBalls: 0,
        expectedStrikes: 0,
        expectedBatterSlot: 2,
        expectedOuts: 0
    ),
    .init(
        precedingResults: [.ball, .calledStrike, .swingingStrike],
        originalResult: .foul,
        proposedResult: .calledStrike,
        expectedBalls: 0,
        expectedStrikes: 0,
        expectedBatterSlot: 2,
        expectedOuts: 1
    ),
    .init(
        precedingResults: [.ball, .calledStrike, .swingingStrike],
        originalResult: .foul,
        proposedResult: .swingingStrike,
        expectedBalls: 0,
        expectedStrikes: 0,
        expectedBatterSlot: 2,
        expectedOuts: 1
    ),
    .init(
        precedingResults: [.ball, .ball, .ball, .calledStrike],
        originalResult: .calledStrike,
        proposedResult: .foul,
        expectedBalls: 3,
        expectedStrikes: 2,
        expectedBatterSlot: 1,
        expectedOuts: 0
    )
]

@MainActor
struct PersistenceTests {
    @Test func thirteenPlayerOffensiveOrderReplaysToSameNextBatter() throws {
        let gameID = UUID()
        let lineup = (1...13).map { slot in
            TrackedBatterIdentity(
                playerID: UUID(),
                lineupSlot: slot,
                displayName: "Batter \(slot)",
                jerseyNumber: "\(slot)",
                position: nil
            )
        }
        let records = try lineup.enumerated().map { index, batter in
            try GameEventRecord(
                gameID: gameID,
                sequenceNumber: index + 1,
                body: .offensivePlateAppearance(OffensivePlateAppearanceEvent(
                    batter: batter,
                    battingOrderSize: lineup.count,
                    result: .homeRun,
                    movements: [.init(source: .batter, destination: .home)],
                    rbi: 1,
                    countedRunSources: [.batter],
                    thirdOutClassification: nil
                ))
            )
        }

        let replay = GameEventReplay.replay(
            records: records,
            homeAway: .away,
            startingPitcherID: nil
        )

        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(replay.state.currentTrackedBatterSlot == 1)
        #expect(replay.state.awayScore == 13)
    }

    @Test func historicalOffensiveEventReplaysWithoutCurrentLineupContext() throws {
        let firstPlayerID = UUID()
        let historicalBatter = TrackedBatterIdentity(
            playerID: firstPlayerID,
            lineupSlot: 1,
            displayName: "Batter One",
            jerseyNumber: "1",
            position: .pitcher
        )
        let record = try GameEventRecord(
            gameID: UUID(),
            sequenceNumber: 1,
            body: .offensivePlateAppearance(OffensivePlateAppearanceEvent(
                batter: historicalBatter,
                battingOrderSize: 2,
                result: .walk,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ))
        )
        let replay = GameEventReplay.replay(
            records: [record],
            homeAway: .away,
            startingPitcherID: firstPlayerID
        )

        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(replay.state.currentTrackedBatterSlot == 2)
        #expect(replay.state.firstBaseRunnerPlayerID == firstPlayerID)
    }

    @Test func replayRejectsPlateAppearanceForDifferentBatterAfterPitchSequenceStarts() throws {
        let firstBatter = TrackedBatterIdentity(
            playerID: UUID(),
            lineupSlot: 1,
            displayName: "Original Batter",
            jerseyNumber: "1",
            position: nil
        )
        let replacementIdentity = TrackedBatterIdentity(
            playerID: UUID(),
            lineupSlot: 1,
            displayName: "Different Batter",
            jerseyNumber: "99",
            position: nil
        )
        let gameID = UUID()
        let pitch = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 1,
            body: .offensivePitch(OffensivePitchEvent(
                batter: firstBatter,
                battingOrderSize: 2,
                result: .calledStrike
            ))
        )
        let plateAppearance = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 2,
            body: .offensivePlateAppearance(OffensivePlateAppearanceEvent(
                batter: replacementIdentity,
                battingOrderSize: 2,
                result: .strikeout,
                movements: [.init(source: .batter, destination: .out)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ))
        )

        let replay = GameEventReplay.replay(
            records: [pitch, plateAppearance],
            homeAway: .away,
            startingPitcherID: nil
        )

        #expect(replay.rejectedRecordIDs == [plateAppearance.id])
        #expect(replay.state.strikes == 1)
        #expect(replay.state.currentTrackedBatterSlot == 1)
    }

    @Test func gameAndLineupPersistInContainer() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let season = Season(name: "Summer", isActive: true)
        let player = Player(firstName: "Peyton", lastName: "Wilson")
        context.insert(season)
        context.insert(player)

        let game = Game(
            seasonID: season.id,
            opponentName: "Thunder",
            status: .inProgress,
            startingPitcherID: player.id
        )
        context.insert(game)
        context.insert(LineupEntry(
            playerID: player.id,
            battingOrder: 1,
            startingPosition: .pitcher,
            gameID: game.id
        ))
        try context.save()

        let games = try context.fetch(FetchDescriptor<Game>())
        let entries = try context.fetch(FetchDescriptor<LineupEntry>())

        #expect(games.count == 1)
        #expect(games.first?.opponentName == "Thunder")
        #expect(entries.count == 1)
        #expect(entries.first?.gameID == game.id)
    }

    @Test func timedGameAndContinuousBattingOrderPersistInContainer() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let playerIDs = (0..<14).map { _ in UUID() }
        let game = Game(
            seasonID: UUID(),
            opponentName: "Lightning",
            timeLimitMinutes: 75,
            status: .inProgress,
            startingPitcherID: playerIDs[0]
        )
        context.insert(game)

        for (index, playerID) in playerIDs.enumerated() {
            context.insert(LineupEntry(
                playerID: playerID,
                battingOrder: index + 1,
                startingPosition: index < 9 ? LineupValidation.regulationDefensivePositions[index] : nil,
                gameID: game.id
            ))
        }
        try context.save()

        let reloadContext = ModelContext(container)
        let storedGame = try #require(reloadContext.fetch(FetchDescriptor<Game>()).first)
        let storedEntries = try reloadContext.fetch(FetchDescriptor<LineupEntry>())
            .filter { $0.gameID == game.id }
            .sorted { $0.battingOrder < $1.battingOrder }
        let expectedPositions: [DefensivePosition?] = LineupValidation.regulationDefensivePositions.map(Optional.some)
            + Array(repeating: nil, count: 5)

        #expect(storedGame.timeLimitMinutes == 75)
        #expect(storedGame.format == .timeLimit)
        #expect(storedGame.startingPitcherID == playerIDs[0])
        #expect(storedEntries.count == 14)
        #expect(storedEntries.map(\.playerID) == playerIDs)
        #expect(storedEntries.map(\.battingOrder) == Array(1...14))
        #expect(storedEntries.map(\.startingPosition) == expectedPositions)
    }

    @Test func inningsBasedFormatPersistsThroughFreshContext() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let game = Game(
            seasonID: UUID(),
            opponentName: "Lightning",
            regulationInnings: 7
        )
        container.mainContext.insert(game)
        try container.mainContext.save()

        let reloadContext = ModelContext(container)
        let storedGame = try #require(reloadContext.fetch(FetchDescriptor<Game>()).first)

        #expect(storedGame.format == .innings)
        #expect(storedGame.regulationInnings == 7)
        #expect(storedGame.timeLimitMinutes == nil)
    }

    @Test func coldStoreReloadRestoresOffensiveBatterCountBasesScoreAndProjection() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "softball-scoring-cold-reload-\(UUID().uuidString).store")
        let gameID = UUID()
        let first = TrackedBatterIdentity(
            playerID: UUID(),
            lineupSlot: 1,
            displayName: "Batter One",
            jerseyNumber: "1",
            position: nil
        )
        let second = TrackedBatterIdentity(
            playerID: UUID(),
            lineupSlot: 2,
            displayName: "Batter Two",
            jerseyNumber: "2",
            position: nil
        )

        do {
            let writeContainer = try AppModelContainer.make(storeURL: storeURL)
            let context = writeContainer.mainContext
            context.insert(try GameEventRecord(
                gameID: gameID,
                sequenceNumber: 1,
                body: .offensivePlateAppearance(OffensivePlateAppearanceEvent(
                    batter: first,
                    battingOrderSize: 2,
                    result: .homeRun,
                    movements: [.init(source: .batter, destination: .home)],
                    rbi: 1,
                    countedRunSources: [.batter],
                    thirdOutClassification: nil
                ))
            ))
            context.insert(try GameEventRecord(
                gameID: gameID,
                sequenceNumber: 2,
                body: .offensivePlateAppearance(OffensivePlateAppearanceEvent(
                    batter: second,
                    battingOrderSize: 2,
                    result: .walk,
                    movements: [.init(source: .batter, destination: .first)],
                    rbi: 0,
                    countedRunSources: [],
                    thirdOutClassification: nil
                ))
            ))
            context.insert(try GameEventRecord(
                gameID: gameID,
                sequenceNumber: 3,
                body: .offensivePitch(OffensivePitchEvent(
                    batter: first,
                    battingOrderSize: 2,
                    result: .ball
                ))
            ))
            try context.save()
        }

        let readContainer = try AppModelContainer.make(storeURL: storeURL)
        let records = try readContainer.mainContext.fetch(FetchDescriptor<GameEventRecord>())
            .filter { $0.gameID == gameID }
        let replay = GameEventReplay.replay(
            records: records,
            homeAway: .away,
            startingPitcherID: nil
        )
        let projection = try BattingStatProjector.project(events: try records.map { try $0.decoded() })

        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(replay.state.currentTrackedBatterSlot == 1)
        #expect(replay.state.balls == 1)
        #expect(replay.state.firstBaseRunnerPlayerID == second.playerID)
        #expect(replay.state.awayScore == 1)
        #expect(projection[first.playerID]?.homeRuns == 1)
        #expect(projection[first.playerID]?.runs == 1)
        #expect(projection[second.playerID]?.walks == 1)
    }
}

extension PersistenceTests {
    @Test func offensiveRecorderPersistsCurrentTrackedBatterAndReplaysFromStore() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let players = (1...13).map { slot in
            Player(
                firstName: "Batter",
                lastName: "\(slot)",
                jerseyNumber: "\(slot)"
            )
        }
        let game = Game(
            seasonID: UUID(),
            opponentName: "Thunder",
            homeAway: .away,
            status: .inProgress,
            startingPitcherID: players[0].id
        )
        context.insert(game)
        for (index, player) in players.enumerated() {
            context.insert(player)
            context.insert(LineupEntry(
                playerID: player.id,
                battingOrder: index + 1,
                startingPosition: index < 9 ? LineupValidation.regulationDefensivePositions[index] : nil,
                gameID: game.id
            ))
        }
        try context.save()

        try GameEventRecorder.recordOffensivePlateAppearance(
            expectedBatter: TrackedBatterIdentity(
                playerID: players[0].id,
                lineupSlot: 1,
                displayName: "Batter 1",
                jerseyNumber: "1",
                position: .pitcher
            ),
            result: .walk,
            movements: [.init(source: .batter, destination: .first)],
            rbi: 0,
            countedRunSources: [],
            game: game,
            existingRecords: [],
            modelContext: context
        )

        let records = try context.fetch(FetchDescriptor<GameEventRecord>())
        let lineupEntries = try context.fetch(FetchDescriptor<LineupEntry>())
        let storedPlayers = try context.fetch(FetchDescriptor<Player>())
        let battingOrder = try #require(TrackedBattingOrder.resolve(
            gameID: game.id,
            lineupEntries: lineupEntries,
            players: storedPlayers
        ))
        let storedRecord = try #require(records.first)
        let storedEvent = try storedRecord.decoded()
        guard case .offensivePlateAppearance(let plateAppearance) = storedEvent.body else {
            Issue.record("Expected an offensive plate appearance")
            return
        }
        let replay = GameEventReplay.replay(
            records: records,
            homeAway: .away,
            startingPitcherID: game.startingPitcherID
        )

        #expect(battingOrder.count == 13)
        #expect(plateAppearance.batter.playerID == players[0].id)
        #expect(plateAppearance.batter.lineupSlot == 1)
        #expect(plateAppearance.batter.displayName == "Batter 1")
        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(replay.state.currentTrackedBatterSlot == 2)
        #expect(replay.state.firstBaseRunnerPlayerID == players[0].id)
    }

    @Test func defensivePitchCanBeRecordedAfterOffensivePlateAppearances() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let player = Player(firstName: "Pitcher", lastName: "One", jerseyNumber: "1")
        let game = Game(
            seasonID: UUID(),
            opponentName: "Thunder",
            homeAway: .away,
            status: .inProgress,
            startingPitcherID: player.id
        )
        context.insert(game)
        context.insert(player)
        context.insert(LineupEntry(
            playerID: player.id,
            battingOrder: 1,
            startingPosition: .pitcher,
            gameID: game.id
        ))
        try context.save()

        for _ in 0..<3 {
            try GameEventRecorder.recordOffensivePlateAppearance(
                expectedBatter: TrackedBatterIdentity(
                    playerID: player.id,
                    lineupSlot: 1,
                    displayName: "Pitcher One",
                    jerseyNumber: "1",
                    position: .pitcher
                ),
                result: .strikeout,
                movements: [.init(source: .batter, destination: .out)],
                rbi: 0,
                countedRunSources: [],
                game: game,
                existingRecords: [],
                modelContext: context
            )
        }

        try GameEventRecorder.recordPitch(
            result: .ball,
            game: game,
            existingRecords: [],
            modelContext: context
        )

        let records = try context.fetch(FetchDescriptor<GameEventRecord>())
        let replay = GameEventReplay.replay(
            records: records,
            homeAway: .away,
            startingPitcherID: player.id
        )

        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(replay.state.half == .bottom)
        #expect(replay.state.balls == 1)
    }

    @Test func recorderRejectsStaleDisplayedBatterBeforeApplyingNextPlateAppearance() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let players = [
            Player(firstName: "Batter", lastName: "One", jerseyNumber: "1"),
            Player(firstName: "Batter", lastName: "Two", jerseyNumber: "2")
        ]
        let game = Game(
            seasonID: UUID(),
            opponentName: "Thunder",
            homeAway: .away,
            status: .inProgress,
            startingPitcherID: players[0].id
        )
        context.insert(game)
        for (index, player) in players.enumerated() {
            context.insert(player)
            context.insert(LineupEntry(
                playerID: player.id,
                battingOrder: index + 1,
                startingPosition: index == 0 ? .pitcher : nil,
                gameID: game.id
            ))
        }
        try context.save()

        let displayedBatter = TrackedBatterIdentity(
            playerID: players[0].id,
            lineupSlot: 1,
            displayName: "Batter One",
            jerseyNumber: "1",
            position: .pitcher
        )
        try GameEventRecorder.recordOffensivePlateAppearance(
            expectedBatter: displayedBatter,
            result: .homeRun,
            movements: [.init(source: .batter, destination: .home)],
            rbi: 1,
            countedRunSources: [.batter],
            game: game,
            existingRecords: [],
            modelContext: context
        )

        do {
            try GameEventRecorder.recordOffensivePlateAppearance(
                expectedBatter: displayedBatter,
                result: .homeRun,
                movements: [.init(source: .batter, destination: .home)],
                rbi: 1,
                countedRunSources: [.batter],
                game: game,
                existingRecords: [],
                modelContext: context
            )
            Issue.record("Expected a stale displayed batter to be rejected")
        } catch GameEventRecorderError.batterMismatch {
            // Expected: the first write advanced the authoritative batting order.
        } catch {
            Issue.record("Expected batterMismatch, got \(error)")
        }

        let records = try context.fetch(FetchDescriptor<GameEventRecord>())
        #expect(records.count == 1)
    }

    @Test func normalOffensivePitchFlowCompletesPlayerAttributedWalkAndStrikeout() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let players = [
            Player(firstName: "Batter", lastName: "One", jerseyNumber: "1"),
            Player(firstName: "Batter", lastName: "Two", jerseyNumber: "2")
        ]
        let game = Game(
            seasonID: UUID(),
            opponentName: "Thunder",
            homeAway: .away,
            status: .inProgress,
            startingPitcherID: players[0].id
        )
        context.insert(game)
        for (index, player) in players.enumerated() {
            context.insert(player)
            context.insert(LineupEntry(
                playerID: player.id,
                battingOrder: index + 1,
                startingPosition: index == 0 ? .pitcher : nil,
                gameID: game.id
            ))
        }
        try context.save()

        let displayedBatter = TrackedBatterIdentity(
            playerID: players[0].id,
            lineupSlot: 1,
            displayName: "Batter One",
            jerseyNumber: "1",
            position: .pitcher
        )
        for _ in 0..<4 {
            try GameEventRecorder.recordOffensivePitch(
                expectedBatter: displayedBatter,
                result: .ball,
                game: game,
                existingRecords: [],
                modelContext: context
            )
        }

        let records = try context.fetch(FetchDescriptor<GameEventRecord>())
        let replay = GameEventReplay.replay(
            records: records,
            homeAway: .away,
            startingPitcherID: players[0].id
        )
        let decoded = try records.map { try $0.decoded() }
        let battingLine = try BattingStatProjector.project(events: decoded)[players[0].id]

        #expect(records.count == 4)
        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(replay.state.currentTrackedBatterSlot == 2)
        #expect(replay.state.firstBaseRunnerPlayerID == players[0].id)
        #expect(replay.state.balls == 0)
        #expect(battingLine?.plateAppearances == 1)
        #expect(battingLine?.walks == 1)

        let secondDisplayedBatter = TrackedBatterIdentity(
            playerID: players[1].id,
            lineupSlot: 2,
            displayName: "Batter Two",
            jerseyNumber: "2",
            position: nil
        )
        for result in [
            OffensivePitchResult.calledStrike,
            .foul,
            .foul,
            .swingingStrike
        ] {
            try GameEventRecorder.recordOffensivePitch(
                expectedBatter: secondDisplayedBatter,
                result: result,
                game: game,
                existingRecords: [],
                modelContext: context
            )
        }

        let completedRecords = try context.fetch(FetchDescriptor<GameEventRecord>())
        let completedReplay = GameEventReplay.replay(
            records: completedRecords,
            homeAway: .away,
            startingPitcherID: players[0].id
        )
        let completedProjection = try BattingStatProjector.project(
            events: try completedRecords.map { try $0.decoded() }
        )

        #expect(completedRecords.count == 8)
        #expect(completedReplay.rejectedRecordIDs.isEmpty)
        #expect(completedReplay.state.currentTrackedBatterSlot == 1)
        #expect(completedReplay.state.outs == 1)
        #expect(completedReplay.state.strikes == 0)
        #expect(completedProjection[players[1].id]?.plateAppearances == 1)
        #expect(completedProjection[players[1].id]?.strikeouts == 1)

        try GameEventRecorder.recordOffensiveBaseRunning(
            expectedRunnerID: players[0].id,
            source: .first,
            result: .stolenBase,
            game: game,
            existingRecords: [],
            modelContext: context
        )
        try GameEventRecorder.recordOffensiveBaseRunning(
            expectedRunnerID: players[0].id,
            source: .second,
            result: .caughtStealing,
            game: game,
            existingRecords: [],
            modelContext: context
        )

        let baseRunningRecords = try context.fetch(FetchDescriptor<GameEventRecord>())
        let baseRunningReplay = GameEventReplay.replay(
            records: baseRunningRecords,
            homeAway: .away,
            startingPitcherID: players[0].id
        )
        let baseRunningProjection = try BattingStatProjector.project(
            events: try baseRunningRecords.map { try $0.decoded() }
        )

        #expect(baseRunningRecords.count == 10)
        #expect(baseRunningReplay.rejectedRecordIDs.isEmpty)
        #expect(baseRunningReplay.state.trackedBaseRunnerPlayerIDs.allSatisfy { $0 == nil })
        #expect(baseRunningReplay.state.outs == 2)
        #expect(baseRunningProjection[players[0].id]?.stolenBases == 1)
        #expect(baseRunningProjection[players[0].id]?.caughtStealing == 1)
    }

    @Test func pitchEventPersistsAndReplaysIntoCount() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let pitcherID = UUID()
        let gameID = UUID()

        let record = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 1,
            timestamp: Date(timeIntervalSince1970: 1),
            body: .pitch(PitchEvent(result: .ball, pitcherID: pitcherID, opponentBatterSlot: 1))
        )
        context.insert(record)
        try context.save()

        let records = try context.fetch(FetchDescriptor<GameEventRecord>())
        let replay = GameEventReplay.replay(
            records: records,
            homeAway: .home,
            startingPitcherID: pitcherID
        )

        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(replay.state.balls == 1)
        #expect(replay.state.pitchCount(for: pitcherID).total == 1)
    }

    @Test func replayRejectsDuplicateSequenceNumber() throws {
        let pitcherID = UUID()
        let gameID = UUID()
        let first = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 1,
            timestamp: Date(timeIntervalSince1970: 1),
            body: .pitch(PitchEvent(result: .ball, pitcherID: pitcherID, opponentBatterSlot: 1))
        )
        let duplicate = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 1,
            timestamp: Date(timeIntervalSince1970: 2),
            body: .pitch(PitchEvent(result: .calledStrike, pitcherID: pitcherID, opponentBatterSlot: 1))
        )

        let replay = GameEventReplay.replay(
            records: [first, duplicate],
            homeAway: .home,
            startingPitcherID: pitcherID
        )

        #expect(replay.rejectedRecordIDs == [duplicate.id])
        #expect(replay.state.balls == 1)
        #expect(replay.state.strikes == 0)
    }

    @Test func replayRejectsPitchAttributedToWrongPitcher() throws {
        let expectedPitcherID = UUID()
        let wrongPitcherID = UUID()
        let record = try GameEventRecord(
            gameID: UUID(),
            sequenceNumber: 1,
            body: .pitch(PitchEvent(result: .ball, pitcherID: wrongPitcherID, opponentBatterSlot: 1))
        )

        let replay = GameEventReplay.replay(
            records: [record],
            homeAway: .home,
            startingPitcherID: expectedPitcherID
        )

        #expect(replay.rejectedRecordIDs == [record.id])
        #expect(replay.state == GameState())
    }

    @Test func replayRestoresPendingBallInPlayState() throws {
        let pitcherID = UUID()
        let record = try GameEventRecord(
            gameID: UUID(),
            sequenceNumber: 1,
            body: .pitch(PitchEvent(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 1))
        )

        let replay = GameEventReplay.replay(
            records: [record],
            homeAway: .home,
            startingPitcherID: pitcherID
        )

        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(replay.state.isAwaitingBallInPlayResult)
        #expect(replay.state.pitchCount(for: pitcherID).total == 1)
    }

    @Test func replayRestoresCompletedBallInPlayState() throws {
        let pitcherID = UUID()
        let gameID = UUID()
        let pitch = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 1,
            body: .pitch(PitchEvent(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 1))
        )
        let play = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 2,
            body: .ballInPlay(BallInPlayEvent(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        )

        let replay = GameEventReplay.replay(
            records: [play, pitch],
            homeAway: .home,
            startingPitcherID: pitcherID
        )

        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(!replay.state.isAwaitingBallInPlayResult)
        #expect(replay.state.firstBaseRunnerSlot == 1)
        #expect(replay.state.currentOpponentBatterSlot == 2)
        #expect(replay.state.pitchCount(for: pitcherID).total == 1)
    }

    @Test func thirdOutTimingRunSurvivesPersistedReplay() throws {
        let pitcherID = UUID()
        let gameID = UUID()
        var sequence = 0
        func record(_ body: GameEventBody) throws -> GameEventRecord {
            sequence += 1
            return try GameEventRecord(gameID: gameID, sequenceNumber: sequence, body: body)
        }
        func pitch(_ result: PitchResult, batter: Int) throws -> GameEventRecord {
            try record(.pitch(PitchEvent(result: result, pitcherID: pitcherID, opponentBatterSlot: batter)))
        }
        func play(
            _ outcome: BallInPlayOutcome,
            batter: Int,
            movements: [RunnerMovementEvent],
            rbi: Int = 0,
            countedRuns: Int? = nil
        ) throws -> GameEventRecord {
            try record(.ballInPlay(BallInPlayEvent(
                outcome: outcome,
                opponentBatterSlot: batter,
                movements: movements,
                rbi: rbi,
                thirdOutRunsCounted: countedRuns,
                thirdOutClassification: countedRuns == nil ? nil : .timingPlay
            )))
        }

        let records = try [
            pitch(.ballInPlay, batter: 1),
            play(.triple, batter: 1, movements: [.init(source: .batter, destination: .third)]),
            pitch(.ballInPlay, batter: 2),
            play(.single, batter: 2, movements: [
                .init(source: .batter, destination: .first),
                .init(source: .third, destination: .third)
            ]),
            pitch(.ballInPlay, batter: 3),
            play(.single, batter: 3, movements: [
                .init(source: .batter, destination: .out),
                .init(source: .first, destination: .second),
                .init(source: .third, destination: .third)
            ]),
            pitch(.calledStrike, batter: 4),
            pitch(.calledStrike, batter: 4),
            pitch(.calledStrike, batter: 4),
            pitch(.ballInPlay, batter: 5),
            play(.single, batter: 5, movements: [
                .init(source: .batter, destination: .first),
                .init(source: .second, destination: .out),
                .init(source: .third, destination: .home)
            ], rbi: 1, countedRuns: 1)
        ]

        let replay = GameEventReplay.replay(
            records: records.reversed(),
            homeAway: .home,
            startingPitcherID: pitcherID
        )

        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(replay.state.awayScore == 1)
        #expect(replay.state.half == .bottom)
        #expect(replay.state.outs == 0)
        #expect(replay.state.baseRunnerSlots.allSatisfy { $0 == nil })
        #expect(replay.state.currentOpponentBatterSlot == 6)
        #expect(replay.state.pitchCount(for: pitcherID).total == 7)
    }

    @Test func recorderRejectsWrongGameAndMalformedHistory() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let game = makeGame()
        let wrongGameRecord = try GameEventRecord(
            gameID: UUID(),
            sequenceNumber: 1,
            body: .pitch(PitchEvent(result: .ball, pitcherID: game.startingPitcherID!, opponentBatterSlot: 1))
        )

        #expect(throws: GameEventRecorderError.self) {
            try GameEventRecorder.recordPitch(
                result: .ball,
                game: game,
                existingRecords: [wrongGameRecord],
                modelContext: container.mainContext
            )
        }


        let phantom = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(PitchEvent(result: .ball, pitcherID: game.startingPitcherID!, opponentBatterSlot: 1))
        )
        #expect(throws: GameEventRecorderError.self) {
            try GameEventRecorder.recordPitch(
                result: .calledStrike,
                game: game,
                existingRecords: [phantom],
                modelContext: container.mainContext
            )
        }

        let malformed = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(PitchEvent(result: .ball, pitcherID: game.startingPitcherID!, opponentBatterSlot: 1))
        )
        malformed.kindRawValue = "unknown"
        container.mainContext.insert(malformed)
        try container.mainContext.save()
        #expect(throws: GameEventRecorderError.self) {
            try GameEventRecorder.recordPitch(
                result: .ball,
                game: game,
                existingRecords: [malformed],
                modelContext: container.mainContext
            )
        }
    }

    @Test func recorderAssignsNextSequenceAndSaves() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let game = makeGame()
        let existing = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 7,
            body: .pitch(PitchEvent(result: .ball, pitcherID: game.startingPitcherID!, opponentBatterSlot: 1))
        )
        container.mainContext.insert(existing)
        try container.mainContext.save()

        try GameEventRecorder.recordPitch(
            result: .calledStrike,
            game: game,
            existingRecords: [existing],
            modelContext: container.mainContext
        )

        let saved = try container.mainContext.fetch(FetchDescriptor<GameEventRecord>())
        #expect(saved.count == 2)
        let appended = saved.first { $0.sequenceNumber == 8 }
        #expect(try appended?.decoded().body == .pitch(PitchEvent(
            result: .calledStrike,
            pitcherID: game.startingPitcherID!,
            opponentBatterSlot: 1
        )))
    }

    @Test func repeatedRecorderCallsUseAuthoritativeStoredSequence() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let game = makeGame()
        let staleSnapshot: [GameEventRecord] = []

        try GameEventRecorder.recordPitch(
            result: .ball,
            game: game,
            existingRecords: staleSnapshot,
            modelContext: container.mainContext
        )
        try GameEventRecorder.recordPitch(
            result: .calledStrike,
            game: game,
            existingRecords: staleSnapshot,
            modelContext: container.mainContext
        )

        let records = try container.mainContext.fetch(FetchDescriptor<GameEventRecord>())
        #expect(records.map(\.sequenceNumber).sorted() == [1, 2])
        let replay = GameEventReplay.replay(
            records: records,
            homeAway: .home,
            startingPitcherID: game.startingPitcherID
        )
        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(replay.state.balls == 1)
        #expect(replay.state.strikes == 1)
    }

    @Test func reconciliationAppendsForStartingPitcherAndSurvivesFreshContext() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let pitch = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ball,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        context.insert(game)
        context.insert(pitch)
        try context.save()

        let editor = try GameEventCorrection.preparePitchCountReconciliation(
            game: game,
            modelContext: context
        )
        let adjusted = try GameEventCorrection.savePitchCountReconciliation(
            totalAdjustment: 3,
            ballAdjustment: 1,
            strikeAdjustment: 1,
            session: editor,
            game: game,
            modelContext: context
        )

        #expect(editor.pitcherID == pitcherID)
        #expect(editor.currentCount == PitchCount(total: 1, balls: 1, strikes: 0))
        #expect(adjusted.records.map(\.sequenceNumber) == [1, 2])
        #expect(adjusted.replay.state.pitchCount(for: pitcherID) == PitchCount(
            total: 4,
            balls: 2,
            strikes: 1
        ))
        #expect(adjusted.replay.state.pitchCount(for: pitcherID).unclassified == 1)
        #expect(adjusted.replay.state.balls == 1)
        #expect(adjusted.replay.state.strikes == 0)
        #expect(adjusted.replay.state.outs == 0)
        #expect(adjusted.battingLines.isEmpty)

        let freshContext = ModelContext(container)
        let freshGame = try #require(freshContext.fetch(FetchDescriptor<Game>()).first)
        let reloaded = try LiveGameSnapshotLoader.load(
            game: freshGame,
            modelContext: freshContext
        )
        #expect(reloaded.replay.state == adjusted.replay.state)
        #expect(reloaded.battingLines == adjusted.battingLines)
        #expect(reloaded.records.map(\.sequenceNumber) == [1, 2])
    }

    @Test func reconciliationPreservesExistingBattingProjection() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let homeRun = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .offensivePlateAppearance(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .homeRun,
                movements: [.init(source: .batter, destination: .home)],
                rbi: 1,
                countedRunSources: [.batter],
                thirdOutClassification: nil
            ))
        )
        context.insert(homeRun)
        try context.save()
        let before = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        let editor = try GameEventCorrection.preparePitchCountReconciliation(
            game: game,
            modelContext: context
        )

        let adjusted = try GameEventCorrection.savePitchCountReconciliation(
            totalAdjustment: 2,
            ballAdjustment: 1,
            strikeAdjustment: 0,
            session: editor,
            game: game,
            modelContext: context
        )

        #expect(before.battingLines[batter.playerID]?.homeRuns == 1)
        #expect(adjusted.battingLines == before.battingLines)
        #expect(adjusted.replay.state.homeScore == before.replay.state.homeScore)
        #expect(adjusted.replay.state.awayScore == before.replay.state.awayScore)
        #expect(adjusted.replay.state.outs == before.replay.state.outs)
        #expect(adjusted.replay.state.trackedBaseRunnerPlayerIDs == before.replay.state.trackedBaseRunnerPlayerIDs)
    }

    @Test func latestReconciliationCanBeIdentifiedAndUndone() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let pitch = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .calledStrike,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        context.insert(pitch)
        try context.save()
        let editor = try GameEventCorrection.preparePitchCountReconciliation(
            game: game,
            modelContext: context
        )
        _ = try GameEventCorrection.savePitchCountReconciliation(
            totalAdjustment: 2,
            ballAdjustment: 0,
            strikeAdjustment: 1,
            session: editor,
            game: game,
            modelContext: context
        )

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let restored = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.action == .pitchCountReconciliation(.init(
            pitcherID: pitcherID,
            totalAdjustment: 2,
            ballAdjustment: 0,
            strikeAdjustment: 1
        )))
        #expect(candidate.confirmationTitle == "Undo latest pitch reconciliation?")
        #expect(candidate.confirmationDetail.contains("Pitch total +2"))
        #expect(candidate.confirmationDetail.contains("unclassified +1"))
        #expect(restored.records.map(\.id) == [pitch.id])
        #expect(restored.replay.state.pitchCount(for: pitcherID) == PitchCount(
            total: 1,
            balls: 0,
            strikes: 1
        ))
        #expect(restored.replay.state.strikes == 1)
    }

    @Test func invalidReconciliationNeverPersists() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let editor = try GameEventCorrection.preparePitchCountReconciliation(
            game: game,
            modelContext: context
        )

        #expect(throws: GameEventCorrectionError.invalidReconciliation) {
            _ = try GameEventCorrection.savePitchCountReconciliation(
                totalAdjustment: 1,
                ballAdjustment: 1,
                strikeAdjustment: 1,
                session: editor,
                game: game,
                modelContext: context
            )
        }
        #expect(try context.fetch(FetchDescriptor<GameEventRecord>()).isEmpty)
    }

    @Test func reconciliationRejectsWrongGameAndStaleTimeline() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let otherGame = makeGame()
        let editor = try GameEventCorrection.preparePitchCountReconciliation(
            game: game,
            modelContext: context
        )

        #expect(throws: GameEventCorrectionError.gameMismatch) {
            _ = try GameEventCorrection.savePitchCountReconciliation(
                totalAdjustment: 1,
                ballAdjustment: 0,
                strikeAdjustment: 0,
                session: editor,
                game: otherGame,
                modelContext: context
            )
        }

        let interveningPitch = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ball,
                pitcherID: try #require(game.startingPitcherID),
                opponentBatterSlot: 1
            ))
        )
        context.insert(interveningPitch)
        try context.save()
        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.savePitchCountReconciliation(
                totalAdjustment: 1,
                ballAdjustment: 0,
                strikeAdjustment: 0,
                session: editor,
                game: game,
                modelContext: context
            )
        }
        let stored = try context.fetch(FetchDescriptor<GameEventRecord>())
        #expect(stored.map(\.id) == [interveningPitch.id])
    }

    @Test func reconciliationRollsBackWhenSaveFails() throws {
        struct ForcedSaveError: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let editor = try GameEventCorrection.preparePitchCountReconciliation(
            game: game,
            modelContext: context
        )

        #expect(throws: ForcedSaveError.self) {
            _ = try GameEventCorrection.savePitchCountReconciliation(
                totalAdjustment: 1,
                ballAdjustment: 0,
                strikeAdjustment: 0,
                session: editor,
                game: game,
                modelContext: context,
                save: { _ in throw ForcedSaveError() }
            )
        }
        let freshContext = ModelContext(container)
        #expect(try freshContext.fetch(FetchDescriptor<GameEventRecord>()).isEmpty)
    }

    @Test func recorderRollsBackInsertionWhenSaveFails() throws {
        struct ForcedSaveError: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let game = makeGame()

        #expect(throws: ForcedSaveError.self) {
            try GameEventRecorder.recordPitch(
                result: .ball,
                game: game,
                existingRecords: [],
                modelContext: container.mainContext,
                save: { _ in throw ForcedSaveError() }
            )
        }

        let records = try container.mainContext.fetch(FetchDescriptor<GameEventRecord>())
        #expect(records.isEmpty)
    }

    @Test func undoLatestDefensiveCountPitchRestoresReplayDerivedState() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = game.startingPitcherID!
        let records = try [PitchResult.ball, .calledStrike, .foul].enumerated().map { index, result in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                body: .pitch(.init(
                    result: result,
                    pitcherID: pitcherID,
                    opponentBatterSlot: 1
                ))
            )
        }
        records.forEach(context.insert)
        try context.save()

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let snapshot = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.sequenceNumber == 3)
        #expect(candidate.inning == 1)
        #expect(candidate.half == .top)
        #expect(candidate.opponentBatterSlot == 1)
        #expect(candidate.action == .pitch(.foul))
        #expect(snapshot.records.map(\.id) == Array(records.dropLast()).map(\.id))
        #expect(snapshot.replay.state.balls == 1)
        #expect(snapshot.replay.state.strikes == 1)
        #expect(snapshot.replay.state.pitchCount(for: pitcherID) == PitchCount(total: 2, balls: 1, strikes: 1))
    }

    @Test func undoLatestTrackedTeamCountPitchRestoresEventTimeBatterCountAndProjection() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let records = try seedOffensivePitches(
            [.ball, .calledStrike],
            game: game,
            batter: batter,
            modelContext: context
        )
        let before = try LiveGameSnapshotLoader.load(game: game, modelContext: context)

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let restored = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.action == .offensivePitch(.calledStrike))
        #expect(candidate.actor == .trackedBatter(batter, battingOrderSize: 10))
        #expect(candidate.confirmationDetail.contains("Avery Stone"))
        #expect(candidate.confirmationDetail.contains("batting slot 1 of 10"))
        #expect(candidate.confirmationDetail.contains("sequence 2: Called Strike"))
        #expect(restored.records.map(\.id) == [records[0].id])
        #expect(restored.records.map(\.sequenceNumber) == [1])
        #expect(restored.replay.state.balls == 1)
        #expect(restored.replay.state.strikes == 0)
        #expect(restored.replay.state.currentTrackedBatterSlot == 1)
        #expect(restored.replay.state.offensiveCountContext == OffensiveCountContext(
            batter: batter,
            battingOrderSize: 10
        ))
        #expect(restored.battingLines == before.battingLines)
        #expect(restored.battingLines.isEmpty)
    }

    @Test(arguments: OffensivePitchResult.allCases)
    func undoRestoresPriorOffensiveCountForEveryNonTerminalTrackedTeamPitch(
        _ result: OffensivePitchResult
    ) throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let priorResults: [OffensivePitchResult]
        let expectedBalls: Int
        let expectedStrikes: Int
        switch result {
        case .ball:
            priorResults = [.calledStrike]
            expectedBalls = 0
            expectedStrikes = 1
        case .calledStrike, .swingingStrike:
            priorResults = [.ball]
            expectedBalls = 1
            expectedStrikes = 0
        case .foul:
            priorResults = [.calledStrike, .swingingStrike]
            expectedBalls = 0
            expectedStrikes = 2
        }
        let records = try seedOffensivePitches(
            priorResults + [result],
            game: game,
            batter: batter,
            modelContext: context
        )

        let restored = try GameEventCorrection.undoLatestAction(
            GameEventCorrection.prepareUndoLatestAction(game: game, modelContext: context),
            game: game,
            modelContext: context
        )

        #expect(restored.records.map(\.id) == Array(records.dropLast()).map(\.id))
        #expect(restored.replay.state.balls == expectedBalls)
        #expect(restored.replay.state.strikes == expectedStrikes)
        #expect(restored.replay.state.pitchCountsByPitcher.isEmpty)
        #expect(restored.replay.state.offensiveCountContext == OffensiveCountContext(
            batter: batter,
            battingOrderSize: 10
        ))
        #expect(restored.battingLines.isEmpty)
    }

    @Test func cancellingTrackedTeamPitchUndoLeavesOriginalTimelineUnchanged() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let records = try seedOffensivePitches(
            [.ball, .foul],
            game: game,
            batter: makeTrackedBatter(),
            modelContext: context
        )
        let before = try LiveGameSnapshotLoader.load(game: game, modelContext: context)

        _ = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        let after = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(after.records.map(\.id) == records.map(\.id))
        #expect(after.records.map(\.sequenceNumber) == [1, 2])
        #expect(after.replay.state == before.replay.state)
        #expect(after.battingLines == before.battingLines)
    }

    @Test func staleTrackedBatterIdentityRejectsUndoAndPreservesOriginalTimeline() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let replacement = makeTrackedBatter(
            displayName: "Jordan Lee",
            jerseyNumber: "12",
            position: .centerField
        )
        let records = try seedOffensivePitches(
            [.ball, .foul],
            game: game,
            batter: makeTrackedBatter(),
            modelContext: context
        )
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        records[1].payload = try GameEventCodec.encode(.offensivePitch(.init(
            batter: replacement,
            battingOrderSize: 10,
            result: .foul
        ))).payload
        try context.save()

        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context
            )
        }
        let stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
            .sorted { $0.sequenceNumber < $1.sequenceNumber }
        #expect(stored.map(\.id) == records.map(\.id))
        #expect(stored.map(\.sequenceNumber) == [1, 2])
        #expect(try stored[1].decoded().body == .offensivePitch(.init(
            batter: replacement,
            battingOrderSize: 10,
            result: .foul
        )))
    }

    @Test func mismatchedTrackedBatterCandidateReplayFailsWithoutChangingHistory() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let firstBatter = makeTrackedBatter()
        let differentBatter = makeTrackedBatter(
            displayName: "Jordan Lee",
            jerseyNumber: "12",
            position: .centerField
        )
        let records = try [firstBatter, differentBatter].enumerated().map { index, batter in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                body: .offensivePitch(.init(
                    batter: batter,
                    battingOrderSize: 10,
                    result: index == 0 ? .ball : .foul
                ))
            )
        }
        records.forEach(context.insert)
        try context.save()

        #expect(throws: GameEventCorrectionError.invalidTimeline) {
            _ = try GameEventCorrection.prepareUndoLatestAction(
                game: game,
                modelContext: context
            )
        }
        let stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
            .sorted { $0.sequenceNumber < $1.sequenceNumber }
        #expect(stored.map(\.id) == records.map(\.id))
        #expect(stored.map(\.sequenceNumber) == [1, 2])
    }

    @Test func failedTrackedTeamPitchUndoSaveRollsBackOriginalTimeline() throws {
        struct ForcedSaveError: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let records = try seedOffensivePitches(
            [.ball, .foul],
            game: game,
            batter: makeTrackedBatter(),
            modelContext: context
        )
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(throws: ForcedSaveError.self) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context,
                save: { _ in throw ForcedSaveError() }
            )
        }
        let stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
            .sorted { $0.sequenceNumber < $1.sequenceNumber }
        #expect(stored.map(\.id) == records.map(\.id))
        #expect(stored.map(\.sequenceNumber) == [1, 2])
        #expect(try stored.map { try $0.decoded().body } == records.map { try $0.decoded().body })
    }

    @Test func trackedTeamPitchUndoSurvivesFreshContextAndColdStoreReload() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "softball-scoring-offensive-pitch-undo-\(UUID().uuidString).store")
        let gameID = UUID()
        let batter = makeTrackedBatter()
        var expectedState: GameState?
        var expectedRecordIDs: [UUID] = []

        do {
            let container = try AppModelContainer.make(storeURL: storeURL)
            let context = container.mainContext
            let game = makeOffensiveGame(id: gameID)
            context.insert(game)
            let records = try seedOffensivePitches(
                [.ball, .calledStrike, .foul],
                game: game,
                batter: batter,
                modelContext: context
            )

            let restored = try GameEventCorrection.undoLatestAction(
                GameEventCorrection.prepareUndoLatestAction(game: game, modelContext: context),
                game: game,
                modelContext: context
            )
            expectedState = restored.replay.state
            expectedRecordIDs = Array(records.dropLast()).map(\.id)

            let freshContext = ModelContext(container)
            let freshGame = try #require(freshContext.fetch(FetchDescriptor<Game>()).first)
            let fresh = try LiveGameSnapshotLoader.load(game: freshGame, modelContext: freshContext)
            #expect(fresh.replay.state == expectedState)
            #expect(fresh.records.map(\.id) == expectedRecordIDs)
            #expect(fresh.replay.state.balls == 1)
            #expect(fresh.replay.state.strikes == 1)
            #expect(fresh.replay.state.offensiveCountContext == OffensiveCountContext(
                batter: batter,
                battingOrderSize: 10
            ))
        }

        let reloadedContainer = try AppModelContainer.make(storeURL: storeURL)
        let reloadedContext = ModelContext(reloadedContainer)
        let reloadedGame = try #require(reloadedContext.fetch(FetchDescriptor<Game>()).first)
        let reloaded = try LiveGameSnapshotLoader.load(
            game: reloadedGame,
            modelContext: reloadedContext
        )
        #expect(reloaded.replay.state == expectedState)
        #expect(reloaded.records.map(\.id) == expectedRecordIDs)
        #expect(reloaded.replay.state.offensiveCountContext == OffensiveCountContext(
            batter: batter,
            battingOrderSize: 10
        ))
    }

    @Test func scoringAfterTrackedTeamPitchUndoPreservesSurvivorsAndUsesAuthoritativeSequence() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let player = Player(
            firstName: "Avery",
            lastName: "Stone",
            jerseyNumber: "8",
            defaultPosition: .shortstop
        )
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter(playerID: player.id)
        context.insert(player)
        context.insert(LineupEntry(
            playerID: player.id,
            battingOrder: 1,
            startingPosition: .shortstop,
            gameID: game.id
        ))
        let records = try seedOffensivePitches(
            [.ball, .calledStrike, .foul],
            sequences: [1, 3, 6],
            game: game,
            batter: batter,
            battingOrderSize: 1,
            modelContext: context
        )

        let restored = try GameEventCorrection.undoLatestAction(
            GameEventCorrection.prepareUndoLatestAction(game: game, modelContext: context),
            game: game,
            modelContext: context
        )
        try GameEventRecorder.recordOffensivePitch(
            expectedBatter: batter,
            result: .swingingStrike,
            game: game,
            existingRecords: restored.records,
            modelContext: context
        )

        let stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
            .filter { $0.gameID == game.id }
            .sorted { $0.sequenceNumber < $1.sequenceNumber }
        #expect(stored.map(\.sequenceNumber) == [1, 3, 4])
        #expect(stored.prefix(2).map(\.id) == records.prefix(2).map(\.id))
        #expect(stored.prefix(2).map(\.timestamp) == records.prefix(2).map(\.timestamp))
        #expect(!stored.contains { $0.id == records[2].id })
        #expect(try stored.last?.decoded().body == .offensivePitch(.init(
            batter: batter,
            battingOrderSize: 1,
            result: .swingingStrike
        )))
    }

    @Test func undoLatestTrackedTeamPlateAppearanceRestoresCountBasesBatterAndBattingProjection() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let pitches = try seedOffensivePitches(
            [.ball, .calledStrike],
            game: game,
            batter: batter,
            modelContext: context
        )
        let plateAppearance = OffensivePlateAppearanceEvent(
            batter: batter,
            battingOrderSize: 10,
            result: .single,
            movements: [.init(source: .batter, destination: .first)],
            rbi: 0,
            countedRunSources: [],
            thirdOutClassification: nil
        )
        let completedRecord = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 3,
            body: .offensivePlateAppearance(plateAppearance)
        )
        context.insert(completedRecord)
        try context.save()

        let completed = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        #expect(completed.replay.state.currentTrackedBatterSlot == 2)
        #expect(completed.replay.state.firstBaseRunnerPlayerID == batter.playerID)
        #expect(completed.battingLines[batter.playerID] == BattingLine(
            plateAppearances: 1,
            atBats: 1,
            hits: 1
        ))

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let restored = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.actor == .trackedBatter(batter, battingOrderSize: 10))
        #expect(candidate.action.buttonTitle == "Undo Latest Play")
        #expect(candidate.confirmationTitle == "Undo latest plate appearance?")
        #expect(candidate.confirmationDetail.contains("Avery Stone"))
        #expect(candidate.confirmationDetail.contains("sequence 3: Single"))
        #expect(candidate.confirmationDetail.contains("Runner movements: Batter to 1B"))
        #expect(candidate.confirmationDetail.contains("Runs: 0. RBI: 0"))
        #expect(restored.records.map(\.id) == pitches.map(\.id))
        #expect(restored.replay.state.balls == 1)
        #expect(restored.replay.state.strikes == 1)
        #expect(restored.replay.state.currentTrackedBatterSlot == 1)
        #expect(restored.replay.state.firstBaseRunnerPlayerID == nil)
        #expect(restored.replay.state.offensiveCountContext == OffensiveCountContext(
            batter: batter,
            battingOrderSize: 10
        ))
        #expect(restored.battingLines.isEmpty)
    }

    @Test(arguments: trackedPlateAppearanceUndoScenarios)
    fileprivate func undoTrackedTeamPlateAppearanceRestoresExactPrePlaySnapshot(
        _ scenario: TrackedPlateAppearanceUndoScenario
    ) throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let runner = makeTrackedBatter(displayName: "Riley North")
        let batter = makeTrackedBatter(
            displayName: "Morgan Field",
            jerseyNumber: "21",
            position: .leftField,
            lineupSlot: 2
        )
        let baselineRecords: [GameEventRecord] = try [
            .init(
                gameID: game.id,
                sequenceNumber: 1,
                body: .offensivePlateAppearance(.init(
                    batter: runner,
                    battingOrderSize: 10,
                    result: .walk,
                    movements: [.init(source: .batter, destination: .first)],
                    rbi: 0,
                    countedRunSources: [],
                    thirdOutClassification: nil
                ))
            ),
            .init(
                gameID: game.id,
                sequenceNumber: 2,
                body: .offensivePitch(.init(
                    batter: batter,
                    battingOrderSize: 10,
                    result: .ball
                ))
            ),
            .init(
                gameID: game.id,
                sequenceNumber: 3,
                body: .offensivePitch(.init(
                    batter: batter,
                    battingOrderSize: 10,
                    result: .calledStrike
                ))
            )
        ]
        baselineRecords.forEach(context.insert)
        try context.save()
        let baseline = try LiveGameSnapshotLoader.load(game: game, modelContext: context)

        let completedRecord = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 4,
            body: .offensivePlateAppearance(.init(
                batter: batter,
                battingOrderSize: 10,
                result: scenario.result,
                movements: scenario.movements,
                rbi: scenario.rbi,
                countedRunSources: scenario.countedRunSources,
                thirdOutClassification: nil
            ))
        )
        context.insert(completedRecord)
        try context.save()
        let completed = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        #expect(completed.replay.rejectedRecordIDs.isEmpty)
        #expect(completed.battingLines != baseline.battingLines)

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let restored = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.confirmationDetail.contains("sequence 4: \(scenario.result.label)"))
        #expect(candidate.confirmationDetail.contains("Runs: \(scenario.countedRunSources.count)"))
        #expect(candidate.confirmationDetail.contains("RBI: \(scenario.rbi)"))
        #expect(restored.records.map(\.id) == baselineRecords.map(\.id))
        #expect(restored.replay.state == baseline.replay.state)
        #expect(restored.battingLines == baseline.battingLines)
        #expect(restored.history == baseline.history)
    }

    @Test func trackedTeamPlateAppearanceUndoKeepsEventTimeIdentityWhenCurrentPlayerMetadataDiffers() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let playerID = UUID()
        let historicalBatter = makeTrackedBatter(
            playerID: playerID,
            displayName: "Historical Name",
            jerseyNumber: "8",
            position: .shortstop
        )
        context.insert(Player(
            id: playerID,
            firstName: "Current",
            lastName: "Name",
            jerseyNumber: "99",
            defaultPosition: .centerField
        ))
        context.insert(LineupEntry(
            playerID: playerID,
            battingOrder: 1,
            startingPosition: .centerField,
            gameID: game.id
        ))
        let record = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .offensivePlateAppearance(.init(
                batter: historicalBatter,
                battingOrderSize: 10,
                result: .walk,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ))
        )
        context.insert(record)
        try context.save()

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(candidate.actor == .trackedBatter(historicalBatter, battingOrderSize: 10))
        #expect(candidate.confirmationDetail.contains("Historical Name"))
        #expect(!candidate.confirmationDetail.contains("Current Name"))
    }

    @Test func cancellingOrFailingTrackedTeamPlateAppearanceUndoPreservesRecordAndBattingLine() throws {
        struct ForcedSaveError: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let record = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .offensivePlateAppearance(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .homeRun,
                movements: [.init(source: .batter, destination: .home)],
                rbi: 1,
                countedRunSources: [.batter],
                thirdOutClassification: nil
            ))
        )
        context.insert(record)
        try context.save()
        let before = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        let afterCancel = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(afterCancel.records.map(\.id) == [record.id])
        #expect(afterCancel.battingLines == before.battingLines)

        #expect(throws: ForcedSaveError.self) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context,
                save: { _ in throw ForcedSaveError() }
            )
        }
        let afterFailure = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(afterFailure.records.map(\.id) == [record.id])
        #expect(afterFailure.replay.state == before.replay.state)
        #expect(afterFailure.battingLines == before.battingLines)
    }

    @Test func staleTrackedTeamPlateAppearanceUndoPreservesTheNewerCompletedPlay() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let record = try GameEventRecord(
            gameID: game.id,
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
        context.insert(record)
        try context.save()
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        record.payload = try GameEventCodec.encode(.offensivePlateAppearance(.init(
            batter: batter,
            battingOrderSize: 10,
            result: .homeRun,
            movements: [.init(source: .batter, destination: .home)],
            rbi: 1,
            countedRunSources: [.batter],
            thirdOutClassification: nil
        ))).payload
        try context.save()

        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context
            )
        }
        let after = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(after.records.map(\.id) == [record.id])
        #expect(after.battingLines[batter.playerID]?.homeRuns == 1)
        #expect(after.battingLines[batter.playerID]?.runs == 1)
    }

    @Test func invalidTrackedTeamCandidateReplayPreservesCompletedPlayAndProjection() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let mismatchedBatter = makeTrackedBatter(displayName: "Different Batter")
        let records = try [
            GameEventRecord(
                gameID: game.id,
                sequenceNumber: 1,
                body: .offensivePitch(.init(
                    batter: mismatchedBatter,
                    battingOrderSize: 10,
                    result: .ball
                ))
            ),
            GameEventRecord(
                gameID: game.id,
                sequenceNumber: 2,
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
        ]
        records.forEach(context.insert)
        try context.save()
        let before = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        #expect(!before.replay.rejectedRecordIDs.isEmpty)

        #expect(throws: GameEventCorrectionError.invalidTimeline) {
            _ = try GameEventCorrection.prepareUndoLatestAction(
                game: game,
                modelContext: context
            )
        }
        let after = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(after.records.map(\.id) == records.map(\.id))
        #expect(after.replay.state == before.replay.state)
        #expect(after.battingLines == before.battingLines)
    }

    @Test func failedTrackedTeamCandidateProjectionPreservesCompletedPlayAndBattingLine() throws {
        struct ForcedProjectionError: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let record = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .offensivePlateAppearance(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .homeRun,
                movements: [.init(source: .batter, destination: .home)],
                rbi: 1,
                countedRunSources: [.batter],
                thirdOutClassification: nil
            ))
        )
        context.insert(record)
        try context.save()
        let before = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(throws: ForcedProjectionError.self) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context,
                projectBattingLines: { _ in throw ForcedProjectionError() }
            )
        }
        let after = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(after.records.map(\.id) == [record.id])
        #expect(after.replay.state == before.replay.state)
        #expect(after.battingLines == before.battingLines)
    }

    @Test func trackedTeamPlateAppearanceUndoSurvivesFreshContextAndColdStoreReload() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "softball-scoring-plate-appearance-undo-\(UUID().uuidString).store")
        let gameID = UUID()
        let batter = makeTrackedBatter()
        var expectedState: GameState?
        var expectedHistory: PlayHistory?

        do {
            let container = try AppModelContainer.make(storeURL: storeURL)
            let context = container.mainContext
            let game = makeOffensiveGame(id: gameID)
            context.insert(game)
            let records = try [
                GameEventRecord(
                    gameID: game.id,
                    sequenceNumber: 1,
                    body: .offensivePitch(.init(
                        batter: batter,
                        battingOrderSize: 10,
                        result: .ball
                    ))
                ),
                GameEventRecord(
                    gameID: game.id,
                    sequenceNumber: 2,
                    body: .offensivePlateAppearance(.init(
                        batter: batter,
                        battingOrderSize: 10,
                        result: .homeRun,
                        movements: [.init(source: .batter, destination: .home)],
                        rbi: 1,
                        countedRunSources: [.batter],
                        thirdOutClassification: nil
                    ))
                )
            ]
            records.forEach(context.insert)
            try context.save()

            let restored = try GameEventCorrection.undoLatestAction(
                GameEventCorrection.prepareUndoLatestAction(game: game, modelContext: context),
                game: game,
                modelContext: context
            )
            expectedState = restored.replay.state
            expectedHistory = restored.history
            #expect(restored.records.map(\.id) == [records[0].id])
            #expect(restored.replay.state.balls == 1)
            #expect(restored.replay.state.currentTrackedBatterSlot == 1)
            #expect(restored.battingLines.isEmpty)

            let freshContext = ModelContext(container)
            let freshGame = try #require(freshContext.fetch(FetchDescriptor<Game>()).first)
            let fresh = try LiveGameSnapshotLoader.load(game: freshGame, modelContext: freshContext)
            #expect(fresh.replay.state == expectedState)
            #expect(fresh.history == expectedHistory)
            #expect(fresh.battingLines.isEmpty)
        }

        let reloadedContainer = try AppModelContainer.make(storeURL: storeURL)
        let reloadedContext = ModelContext(reloadedContainer)
        let reloadedGame = try #require(reloadedContext.fetch(FetchDescriptor<Game>()).first)
        let reloaded = try LiveGameSnapshotLoader.load(
            game: reloadedGame,
            modelContext: reloadedContext
        )
        #expect(reloaded.replay.state == expectedState)
        #expect(reloaded.history == expectedHistory)
        #expect(reloaded.battingLines.isEmpty)
    }

    @Test func undoTrackedTeamThirdOutRestoresPriorHalfInningAndTwoOutBattingProjection() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batters = (1...3).map { slot in
            makeTrackedBatter(
                displayName: "Batter \(slot)",
                jerseyNumber: "\(slot)",
                lineupSlot: slot
            )
        }
        let records = try batters.enumerated().map { index, batter in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                body: .offensivePlateAppearance(.init(
                    batter: batter,
                    battingOrderSize: 10,
                    result: .strikeout,
                    movements: [.init(source: .batter, destination: .out)],
                    rbi: 0,
                    countedRunSources: [],
                    thirdOutClassification: nil
                ))
            )
        }
        records.forEach(context.insert)
        try context.save()
        let completed = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        #expect(completed.replay.state.half == .bottom)
        #expect(completed.replay.state.outs == 0)

        let restored = try GameEventCorrection.undoLatestAction(
            GameEventCorrection.prepareUndoLatestAction(game: game, modelContext: context),
            game: game,
            modelContext: context
        )

        #expect(restored.records.map(\.id) == Array(records.dropLast()).map(\.id))
        #expect(restored.replay.state.inning == 1)
        #expect(restored.replay.state.half == .top)
        #expect(restored.replay.state.outs == 2)
        #expect(restored.replay.state.currentTrackedBatterSlot == 3)
        #expect(restored.replay.state.balls == 0)
        #expect(restored.replay.state.strikes == 0)
        #expect(restored.battingLines[batters[0].playerID]?.strikeouts == 1)
        #expect(restored.battingLines[batters[1].playerID]?.strikeouts == 1)
        #expect(restored.battingLines[batters[2].playerID] == nil)
    }

    @Test func undoLatestStolenBaseRestoresRunnerCountBatterAndBattingProjection() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let runner = makeTrackedBatter()
        let activeBatter = makeTrackedBatter(
            displayName: "Jordan Lee",
            jerseyNumber: "12",
            position: .centerField,
            lineupSlot: 2
        )
        let records = try [
            GameEventBody.offensivePlateAppearance(.init(
                batter: runner,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePitch(.init(
                batter: activeBatter,
                battingOrderSize: 10,
                result: .ball
            )),
            .offensiveBaseRunning(.init(
                runnerID: runner.playerID,
                source: .first,
                destination: .second,
                result: .stolenBase
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let restored = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.action == .offensiveBaseRunning(.init(
            runnerID: runner.playerID,
            source: .first,
            destination: .second,
            result: .stolenBase
        )))
        #expect(candidate.actor == .trackedBatter(runner, battingOrderSize: 10))
        #expect(candidate.confirmationDetail.contains("Avery Stone"))
        #expect(candidate.confirmationDetail.contains("sequence 3: SB · 1B to 2B"))
        #expect(restored.records.map(\.id) == Array(records.dropLast()).map(\.id))
        #expect(restored.replay.state.firstBaseRunnerPlayerID == runner.playerID)
        #expect(restored.replay.state.secondBaseRunnerPlayerID == nil)
        #expect(restored.replay.state.currentTrackedBatterSlot == 2)
        #expect(restored.replay.state.balls == 1)
        #expect(restored.replay.state.strikes == 0)
        #expect(restored.replay.state.offensiveCountContext == OffensiveCountContext(
            batter: activeBatter,
            battingOrderSize: 10
        ))
        #expect(restored.battingLines[runner.playerID]?.plateAppearances == 1)
        #expect(restored.battingLines[runner.playerID]?.hits == 1)
        #expect(restored.battingLines[runner.playerID]?.stolenBases == 0)
        #expect(restored.battingLines[runner.playerID]?.caughtStealing == 0)
    }

    @Test func acceptedDuplicatePlayerIDHistoryUsesSourceBaseProvenanceForUndoConfirmation() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let originatingRunner = makeTrackedBatter()
        let laterSnapshot = makeTrackedBatter(
            playerID: originatingRunner.playerID,
            displayName: "Later Snapshot",
            jerseyNumber: "12",
            position: .centerField,
            lineupSlot: 2
        )
        let records = try [
            GameEventBody.offensivePlateAppearance(.init(
                batter: originatingRunner,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePlateAppearance(.init(
                batter: laterSnapshot,
                battingOrderSize: 10,
                result: .double,
                movements: [
                    .init(source: .batter, destination: .second),
                    .init(source: .first, destination: .third)
                ],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensiveBaseRunning(.init(
                runnerID: originatingRunner.playerID,
                source: .third,
                destination: .home,
                result: .stolenBase
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(candidate.actor == .trackedBatter(originatingRunner, battingOrderSize: 10))
        #expect(candidate.confirmationDetail.contains("Avery Stone"))
        #expect(!candidate.confirmationDetail.contains("Later Snapshot"))
    }

    @Test func acceptedSameIDReplacementUsesNewSourceBaseProvenanceForUndoConfirmation() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let earlierRunner = makeTrackedBatter()
        let replacementRunner = makeTrackedBatter(
            playerID: earlierRunner.playerID,
            displayName: "Replacement Snapshot",
            jerseyNumber: "12",
            position: .centerField,
            lineupSlot: 2
        )
        let records = try [
            GameEventBody.offensivePlateAppearance(.init(
                batter: earlierRunner,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePlateAppearance(.init(
                batter: replacementRunner,
                battingOrderSize: 10,
                result: .single,
                movements: [
                    .init(source: .batter, destination: .first),
                    .init(source: .first, destination: .third)
                ],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensiveBaseRunning(.init(
                runnerID: replacementRunner.playerID,
                source: .first,
                destination: .second,
                result: .stolenBase
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(candidate.actor == .trackedBatter(replacementRunner, battingOrderSize: 10))
        #expect(candidate.confirmationDetail.contains("Replacement Snapshot"))
        #expect(!candidate.confirmationDetail.contains("Avery Stone"))
    }

    @Test func consecutiveStealsTraceUndoConfirmationBackToOriginatingPlateAppearance() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let runner = makeTrackedBatter()
        let records = try [
            GameEventBody.offensivePlateAppearance(.init(
                batter: runner,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensiveBaseRunning(.init(
                runnerID: runner.playerID,
                source: .first,
                destination: .second,
                result: .stolenBase
            )),
            .offensiveBaseRunning(.init(
                runnerID: runner.playerID,
                source: .second,
                destination: .third,
                result: .stolenBase
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(candidate.actor == .trackedBatter(runner, battingOrderSize: 10))
        #expect(candidate.confirmationDetail.contains("sequence 3: SB · 2B to 3B"))
    }

    @Test func undoStealOfHomeRemovesRunAndSBWhileRestoringRunnerToThird() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let runner = makeTrackedBatter()
        let activeBatter = makeTrackedBatter(
            displayName: "Jordan Lee",
            jerseyNumber: "12",
            position: .centerField,
            lineupSlot: 2
        )
        let records = try [
            GameEventBody.offensivePlateAppearance(.init(
                batter: runner,
                battingOrderSize: 10,
                result: .triple,
                movements: [.init(source: .batter, destination: .third)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePitch(.init(
                batter: activeBatter,
                battingOrderSize: 10,
                result: .calledStrike
            )),
            .offensiveBaseRunning(.init(
                runnerID: runner.playerID,
                source: .third,
                destination: .home,
                result: .stolenBase
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()
        let before = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        #expect(before.replay.state.awayScore == 1)
        #expect(before.battingLines[runner.playerID]?.runs == 1)
        #expect(before.battingLines[runner.playerID]?.stolenBases == 1)

        let restored = try GameEventCorrection.undoLatestAction(
            GameEventCorrection.prepareUndoLatestAction(game: game, modelContext: context),
            game: game,
            modelContext: context
        )

        #expect(restored.replay.state.awayScore == 0)
        #expect(restored.replay.state.thirdBaseRunnerPlayerID == runner.playerID)
        #expect(restored.replay.state.currentTrackedBatterSlot == 2)
        #expect(restored.replay.state.strikes == 1)
        #expect(restored.battingLines[runner.playerID]?.runs == 0)
        #expect(restored.battingLines[runner.playerID]?.triples == 1)
        #expect(restored.battingLines[runner.playerID]?.stolenBases == 0)
    }

    @Test func undoThirdOutCaughtStealingRestoresPriorHalfRunnerOutsAndActiveBatter() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batters = (1...4).map { slot in
            makeTrackedBatter(
                displayName: "Player \(slot)",
                jerseyNumber: "\(slot)",
                position: .shortstop,
                lineupSlot: slot
            )
        }
        let records = try [
            GameEventBody.offensivePlateAppearance(.init(
                batter: batters[0],
                battingOrderSize: 10,
                result: .strikeout,
                movements: [.init(source: .batter, destination: .out)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePlateAppearance(.init(
                batter: batters[1],
                battingOrderSize: 10,
                result: .strikeout,
                movements: [.init(source: .batter, destination: .out)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePlateAppearance(.init(
                batter: batters[2],
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePitch(.init(
                batter: batters[3],
                battingOrderSize: 10,
                result: .calledStrike
            )),
            .offensiveBaseRunning(.init(
                runnerID: batters[2].playerID,
                source: .first,
                destination: .out,
                result: .caughtStealing
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()
        let before = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        #expect(before.replay.state.half == .bottom)
        #expect(before.battingLines[batters[2].playerID]?.caughtStealing == 1)

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let restored = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.actor == .trackedBatter(batters[2], battingOrderSize: 10))
        #expect(candidate.confirmationTitle == "Undo latest caught stealing?")
        #expect(candidate.confirmationDetail.contains("sequence 5: CS · 1B to Out"))
        #expect(restored.replay.state.inning == 1)
        #expect(restored.replay.state.half == .top)
        #expect(restored.replay.state.outs == 2)
        #expect(restored.replay.state.firstBaseRunnerPlayerID == batters[2].playerID)
        #expect(restored.replay.state.currentTrackedBatterSlot == 4)
        #expect(restored.replay.state.strikes == 1)
        #expect(restored.replay.state.offensiveCountContext == OffensiveCountContext(
            batter: batters[3],
            battingOrderSize: 10
        ))
        #expect(restored.battingLines[batters[2].playerID]?.hits == 1)
        #expect(restored.battingLines[batters[2].playerID]?.caughtStealing == 0)
    }

    @Test func wrongRunnerBaseRunningHistoryCannotBecomeAnUndoCandidate() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let runner = makeTrackedBatter()
        let records = try [
            GameEventBody.offensivePlateAppearance(.init(
                batter: runner,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensiveBaseRunning(.init(
                runnerID: UUID(),
                source: .first,
                destination: .second,
                result: .stolenBase
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        #expect(throws: GameEventCorrectionError.invalidTimeline) {
            _ = try GameEventCorrection.prepareUndoLatestAction(
                game: game,
                modelContext: context
            )
        }
        let stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
            .sorted { $0.sequenceNumber < $1.sequenceNumber }
        #expect(stored.map(\.id) == records.map(\.id))
        #expect(stored.map(\.sequenceNumber) == [1, 2])
    }

    @Test func staleStolenBaseUndoPreservesNewerHistory() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let seeded = try seedStolenBaseUndoTimeline(game: game, modelContext: context)
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        seeded.records[0].timestamp = seeded.records[0].timestamp.addingTimeInterval(1)
        try context.save()

        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context
            )
        }
        let stored = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(stored.records.map(\.id) == seeded.records.map(\.id))
        #expect(stored.replay.state.secondBaseRunnerPlayerID == seeded.runner.playerID)
        #expect(stored.battingLines[seeded.runner.playerID]?.stolenBases == 1)
    }

    @Test func failedStolenBaseProjectionOrSaveLeavesTimelineAndAttributionUnchanged() throws {
        struct ForcedProjectionError: Error {}
        struct ForcedSaveError: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let seeded = try seedStolenBaseUndoTimeline(game: game, modelContext: context)
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(throws: ForcedProjectionError.self) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context,
                projectBattingLines: { _ in throw ForcedProjectionError() }
            )
        }
        #expect(throws: ForcedSaveError.self) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context,
                save: { _ in throw ForcedSaveError() }
            )
        }

        let stored = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(stored.records.map(\.id) == seeded.records.map(\.id))
        #expect(stored.replay.state.secondBaseRunnerPlayerID == seeded.runner.playerID)
        #expect(stored.battingLines[seeded.runner.playerID]?.stolenBases == 1)
    }

    @Test func stolenBaseUndoSurvivesFreshContextAndColdStoreReload() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "softball-scoring-base-running-undo-\(UUID().uuidString).store")
        let gameID = UUID()
        var expectedState: GameState?
        var expectedLines: [UUID: BattingLine] = [:]
        var expectedRecordIDs: [UUID] = []

        do {
            let container = try AppModelContainer.make(storeURL: storeURL)
            let context = container.mainContext
            let game = makeOffensiveGame(id: gameID)
            context.insert(game)
            let seeded = try seedStolenBaseUndoTimeline(game: game, modelContext: context)
            let restored = try GameEventCorrection.undoLatestAction(
                GameEventCorrection.prepareUndoLatestAction(game: game, modelContext: context),
                game: game,
                modelContext: context
            )
            expectedState = restored.replay.state
            expectedLines = restored.battingLines
            expectedRecordIDs = Array(seeded.records.dropLast()).map(\.id)

            let freshContext = ModelContext(container)
            let freshGame = try #require(freshContext.fetch(FetchDescriptor<Game>()).first)
            let fresh = try LiveGameSnapshotLoader.load(game: freshGame, modelContext: freshContext)
            #expect(fresh.replay.state == expectedState)
            #expect(fresh.battingLines == expectedLines)
            #expect(fresh.records.map(\.id) == expectedRecordIDs)
            #expect(fresh.replay.state.firstBaseRunnerPlayerID == seeded.runner.playerID)
        }

        let reloadedContainer = try AppModelContainer.make(storeURL: storeURL)
        let reloadedContext = ModelContext(reloadedContainer)
        let reloadedGame = try #require(reloadedContext.fetch(FetchDescriptor<Game>()).first)
        let reloaded = try LiveGameSnapshotLoader.load(
            game: reloadedGame,
            modelContext: reloadedContext
        )
        #expect(reloaded.replay.state == expectedState)
        #expect(reloaded.battingLines == expectedLines)
        #expect(reloaded.records.map(\.id) == expectedRecordIDs)
    }

    @Test func undoLatestBallInPlayResultPreservesCountedPitchAndRestoresPendingState() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = game.startingPitcherID!
        let pitch = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ballInPlay,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        let result = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        )
        context.insert(pitch)
        context.insert(result)
        try context.save()
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let restored = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.action == .ballInPlayResult(.single))
        #expect(candidate.precedingBallInPlayPitchSequenceNumber == 1)
        #expect(candidate.confirmationTitle == "Undo latest result?")
        #expect(candidate.confirmationDetail.contains("Only the completed Single result will be removed"))
        #expect(candidate.confirmationDetail.contains("Ball In Play pitch at sequence 1 will remain counted"))
        #expect(restored.records.map(\.id) == [pitch.id])
        #expect(restored.replay.state.isAwaitingBallInPlayResult)
        #expect(restored.replay.state.currentOpponentBatterSlot == 1)
        #expect(restored.replay.state.baseRunnerSlots == [nil, nil, nil])
        #expect(restored.replay.state.outs == 0)
        #expect(restored.replay.state.awayScore == 0)
        #expect(restored.replay.state.pitchCount(for: pitcherID) == PitchCount(total: 1, balls: 0, strikes: 1))
    }

    @Test(arguments: [
        BallInPlayOutcome.single,
        .double,
        .homeRun,
        .groundOut
    ])
    func undoBallInPlayResultRestoresPreResultStateForHitsHomeRunAndOrdinaryOut(
        _ outcome: BallInPlayOutcome
    ) throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = game.startingPitcherID!
        let destination: RunnerDestination = switch outcome {
        case .single: .first
        case .double: .second
        case .homeRun: .home
        case .groundOut: .out
        default: try #require(nil)
        }
        let bodies: [GameEventBody] = [
            .pitch(.init(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 1)),
            .ballInPlay(.init(
                outcome: outcome,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: destination)],
                rbi: outcome == .homeRun ? 1 : 0,
                thirdOutRunsCounted: nil
            ))
        ]
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let expected = try LiveGameSnapshotLoader.makeSnapshot(
            game: game,
            records: [records[0]]
        )
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let restored = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.action == .ballInPlayResult(outcome))
        #expect(restored.records.map(\.id) == [records[0].id])
        #expect(restored.replay.state == expected.replay.state)
        #expect(restored.replay.state.isAwaitingBallInPlayResult)
        #expect(restored.replay.state.pitchCount(for: pitcherID) == PitchCount(total: 1, balls: 0, strikes: 1))
    }

    @Test func undoMultiOutBallInPlayResultRestoresRunnerOutsAndPendingBatter() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = game.startingPitcherID!
        let bodies = twoConsecutiveSingles(pitcherID: pitcherID).prefix(2) + [
            .pitch(.init(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 2)),
            .ballInPlay(.init(
                outcome: .doublePlay,
                opponentBatterSlot: 2,
                movements: [
                    .init(source: .first, destination: .out),
                    .init(source: .batter, destination: .out)
                ],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        ]
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let restored = try GameEventCorrection.undoLatestAction(
            GameEventCorrection.prepareUndoLatestAction(game: game, modelContext: context),
            game: game,
            modelContext: context
        )

        #expect(restored.replay.state.outs == 0)
        #expect(restored.replay.state.currentOpponentBatterSlot == 2)
        #expect(restored.replay.state.firstBaseRunnerSlot == 1)
        #expect(restored.replay.state.isAwaitingBallInPlayResult)
        #expect(restored.replay.state.pitchCount(for: pitcherID) == PitchCount(total: 2, balls: 0, strikes: 2))
    }

    @Test func undoThirdOutBallInPlayResultRestoresPriorHalfInningAndTwoOutState() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = game.startingPitcherID!
        let bodies = (1...3).flatMap { slot in
            [
                GameEventBody.pitch(.init(
                    result: .ballInPlay,
                    pitcherID: pitcherID,
                    opponentBatterSlot: slot
                )),
                .ballInPlay(.init(
                    outcome: .groundOut,
                    opponentBatterSlot: slot,
                    movements: [.init(source: .batter, destination: .out)],
                    rbi: 0,
                    thirdOutRunsCounted: nil
                ))
            ]
        }
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let completed = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        #expect(completed.replay.state.half == .bottom)
        let restored = try GameEventCorrection.undoLatestAction(
            GameEventCorrection.prepareUndoLatestAction(game: game, modelContext: context),
            game: game,
            modelContext: context
        )

        #expect(restored.replay.state.half == .top)
        #expect(restored.replay.state.inning == 1)
        #expect(restored.replay.state.outs == 2)
        #expect(restored.replay.state.currentOpponentBatterSlot == 3)
        #expect(restored.replay.state.isAwaitingBallInPlayResult)
        #expect(restored.replay.state.pitchCount(for: pitcherID) == PitchCount(total: 3, balls: 0, strikes: 3))
    }

    @Test func undoBallFourRestoresCountBatterForcedRunnersScoreAndPitcherTotals() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = game.startingPitcherID!
        let bodies = twoConsecutiveSingles(pitcherID: pitcherID) + [
            .pitch(.init(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 3)),
            .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 3,
                movements: [
                    .init(source: .second, destination: .third),
                    .init(source: .first, destination: .second),
                    .init(source: .batter, destination: .first)
                ],
                rbi: 0,
                thirdOutRunsCounted: nil
            )),
            .pitch(.init(result: .ball, pitcherID: pitcherID, opponentBatterSlot: 4)),
            .pitch(.init(result: .ball, pitcherID: pitcherID, opponentBatterSlot: 4)),
            .pitch(.init(result: .ball, pitcherID: pitcherID, opponentBatterSlot: 4)),
            .pitch(.init(result: .ball, pitcherID: pitcherID, opponentBatterSlot: 4))
        ]
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let completed = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        #expect(completed.replay.state.currentOpponentBatterSlot == 5)
        #expect(completed.replay.state.awayScore == 1)
        #expect(completed.replay.state.firstBaseRunnerSlot == 4)
        #expect(completed.replay.state.secondBaseRunnerSlot == 3)
        #expect(completed.replay.state.thirdBaseRunnerSlot == 2)

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let restored = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.action == .pitch(.ball))
        #expect(candidate.opponentBatterSlot == 4)
        #expect(candidate.confirmationDetail.contains("completed the plate appearance for opponent batting slot 4"))
        #expect(restored.records.map(\.id) == Array(records.dropLast()).map(\.id))
        #expect(restored.replay.state.balls == 3)
        #expect(restored.replay.state.strikes == 0)
        #expect(restored.replay.state.currentOpponentBatterSlot == 4)
        #expect(restored.replay.state.awayScore == 0)
        #expect(restored.replay.state.firstBaseRunnerSlot == 3)
        #expect(restored.replay.state.secondBaseRunnerSlot == 2)
        #expect(restored.replay.state.thirdBaseRunnerSlot == 1)
        #expect(restored.replay.state.pitchCount(for: pitcherID) == PitchCount(total: 6, balls: 3, strikes: 3))
    }

    @Test func undoHitByPitchRemovesAwardedBaseAndEveryForcedMovement() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = game.startingPitcherID!
        let bodies = twoConsecutiveSingles(pitcherID: pitcherID) + [
            .pitch(.init(result: .hitByPitch, pitcherID: pitcherID, opponentBatterSlot: 3))
        ]
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let completed = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        #expect(completed.replay.state.currentOpponentBatterSlot == 4)
        #expect(completed.replay.state.firstBaseRunnerSlot == 3)
        #expect(completed.replay.state.secondBaseRunnerSlot == 2)
        #expect(completed.replay.state.thirdBaseRunnerSlot == 1)

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let restored = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.action == .pitch(.hitByPitch))
        #expect(candidate.completedPlateAppearance)
        #expect(restored.records.map(\.id) == Array(records.dropLast()).map(\.id))
        #expect(restored.replay.state.currentOpponentBatterSlot == 3)
        #expect(restored.replay.state.firstBaseRunnerSlot == 2)
        #expect(restored.replay.state.secondBaseRunnerSlot == 1)
        #expect(restored.replay.state.thirdBaseRunnerSlot == nil)
        #expect(restored.replay.state.pitchCount(for: pitcherID) == PitchCount(total: 2, balls: 0, strikes: 2))
    }

    @Test(arguments: [PitchResult.calledStrike, .swingingStrike])
    func undoStrikeThreeRestoresTwoStrikeCountOutsBatterAndHalfInning(
        _ strikeResult: PitchResult
    ) throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = game.startingPitcherID!
        let records = try (1...9).map { sequence in
            let batterSlot = ((sequence - 1) / 3) + 1
            return try GameEventRecord(
                gameID: game.id,
                sequenceNumber: sequence,
                body: .pitch(.init(
                    result: strikeResult,
                    pitcherID: pitcherID,
                    opponentBatterSlot: batterSlot
                ))
            )
        }
        records.forEach(context.insert)
        try context.save()

        let completed = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        #expect(completed.replay.state.inning == 1)
        #expect(completed.replay.state.half == .bottom)
        #expect(completed.replay.state.outs == 0)
        #expect(completed.replay.state.currentOpponentBatterSlot == 4)

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let restored = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.action == .pitch(strikeResult))
        #expect(candidate.opponentBatterSlot == 3)
        #expect(candidate.completedPlateAppearance)
        #expect(restored.records.map(\.id) == Array(records.dropLast()).map(\.id))
        #expect(restored.replay.state.inning == 1)
        #expect(restored.replay.state.half == .top)
        #expect(restored.replay.state.outs == 2)
        #expect(restored.replay.state.balls == 0)
        #expect(restored.replay.state.strikes == 2)
        #expect(restored.replay.state.currentOpponentBatterSlot == 3)
        #expect(restored.replay.state.pitchCount(for: pitcherID) == PitchCount(total: 8, balls: 0, strikes: 8))
    }

    @Test func preparingUndoThenCancellingLeavesDurableTimelineAndSnapshotUnchanged() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        context.insert(try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ball,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        ))
        try context.save()
        let before = try LiveGameSnapshotLoader.load(game: game, modelContext: context)

        _ = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        let freshContext = ModelContext(container)
        let after = try LiveGameSnapshotLoader.load(game: game, modelContext: freshContext)
        #expect(after.records.map(\.id) == before.records.map(\.id))
        #expect(after.records.map(\.sequenceNumber) == before.records.map(\.sequenceNumber))
        #expect(after.records.map(\.timestamp) == before.records.map(\.timestamp))
        #expect(after.replay.state == before.replay.state)
        #expect(after.battingLines == before.battingLines)
        #expect(after.history == before.history)
    }

    @Test func undoUsesOnlyFreshlyPersistedRecordsAndDoesNotSavePendingContextChanges() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        context.insert(try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ball,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        ))
        try context.save()
        context.insert(try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .pitch(.init(
                result: .calledStrike,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        ))

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        _ = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        let durableRecords = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
        #expect(candidate.sequenceNumber == 1)
        #expect(durableRecords.isEmpty)
        #expect(context.hasChanges)
    }

    @Test(arguments: [
        PitchResult.ball,
        .calledStrike,
        .swingingStrike,
        .foul
    ])
    func undoSupportsEveryNonTerminalDefensiveCountPitch(_ result: PitchResult) throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        context.insert(try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: result,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        ))
        try context.save()

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let snapshot = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(snapshot.records.isEmpty)
        #expect(snapshot.replay.state == GameState())
    }

    @Test func undoRejectsWrongGameMovedLatestActionAndStaleTimeline() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let record = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ball,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        )
        context.insert(record)
        try context.save()
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(throws: GameEventCorrectionError.gameMismatch) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: makeGame(),
                modelContext: context
            )
        }

        record.payload = try GameEventCodec.encode(.pitch(.init(
            result: .calledStrike,
            pitcherID: game.startingPitcherID!,
            opponentBatterSlot: 1
        ))).payload
        try context.save()
        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context
            )
        }

        let refreshedCandidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        context.insert(try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .pitch(.init(
                result: .ball,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        ))
        try context.save()
        #expect(throws: GameEventCorrectionError.latestActionChanged) {
            _ = try GameEventCorrection.undoLatestAction(
                refreshedCandidate,
                game: game,
                modelContext: context
            )
        }
    }

    @Test func undoRejectsBallInPlayOrCorruptLatestActions() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = game.startingPitcherID!
        context.insert(try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ballInPlay,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        ))
        try context.save()

        #expect(throws: GameEventCorrectionError.noUndoAvailable) {
            _ = try GameEventCorrection.prepareUndoLatestAction(
                game: game,
                modelContext: context
            )
        }

        let corrupt = try #require(try context.fetch(FetchDescriptor<GameEventRecord>()).first)
        corrupt.kindRawValue = "unknown"
        try context.save()
        #expect(throws: GameEventCorrectionError.invalidTimeline) {
            _ = try GameEventCorrection.prepareUndoLatestAction(
                game: game,
                modelContext: context
            )
        }
    }

    @Test func undoOffersLatestCompletedBallInPlayResultAsOneScoringAction() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        context.insert(try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ballInPlay,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        ))
        context.insert(try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        ))
        try context.save()

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        let latestRecordID = try context.fetch(FetchDescriptor<GameEventRecord>())
            .first { $0.sequenceNumber == 2 }?.id
        #expect(candidate.id == latestRecordID)
        #expect(candidate.action == .ballInPlayResult(.single))
    }

    @Test func cancellingBallInPlayResultUndoLeavesCompletedPlayIntact() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let records = try seedCompletedSingle(game: game, modelContext: context)
        let before = try LiveGameSnapshotLoader.load(game: game, modelContext: context)

        _ = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        let after = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(after.records.map(\.id) == records.map(\.id))
        #expect(after.replay.state == before.replay.state)
        #expect(!after.replay.state.isAwaitingBallInPlayResult)
    }

    @Test func invalidBallInPlayCandidateReplayLeavesCompletedRecordsIntact() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let records = try seedCompletedSingle(game: game, modelContext: context)
        records[1].payload = try GameEventCodec.encode(.ballInPlay(.init(
            outcome: .single,
            opponentBatterSlot: 1,
            movements: [],
            rbi: 0,
            thirdOutRunsCounted: nil
        ))).payload
        try context.save()

        #expect(throws: GameEventCorrectionError.invalidTimeline) {
            _ = try GameEventCorrection.prepareUndoLatestAction(
                game: game,
                modelContext: context
            )
        }

        let stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
        let storedIDs = stored.map(\.id).sorted { $0.uuidString < $1.uuidString }
        let originalIDs = records.map(\.id).sorted { $0.uuidString < $1.uuidString }
        #expect(storedIDs == originalIDs)
    }

    @Test func wrongGameAndStaleBallInPlayUndoLeaveCompletedPlayIntact() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let records = try seedCompletedSingle(game: game, modelContext: context)
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(throws: GameEventCorrectionError.gameMismatch) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: makeGame(),
                modelContext: context
            )
        }
        #expect(try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>()).count == 2)

        records[1].payload = try GameEventCodec.encode(.ballInPlay(.init(
            outcome: .double,
            opponentBatterSlot: 1,
            movements: [.init(source: .batter, destination: .second)],
            rbi: 0,
            thirdOutRunsCounted: nil
        ))).payload
        try context.save()
        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context
            )
        }
        #expect(try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>()).count == 2)
    }

    @Test func failedBallInPlayResultUndoSaveRollsBackCompletedPlay() throws {
        struct ForcedSaveError: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let records = try seedCompletedSingle(game: game, modelContext: context)
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(throws: ForcedSaveError.self) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context,
                save: { _ in throw ForcedSaveError() }
            )
        }

        let stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
            .sorted { $0.sequenceNumber < $1.sequenceNumber }
        let storedBody = try stored[1].decoded().body
        let originalBody = try records[1].decoded().body
        #expect(stored.map(\.id) == records.map(\.id))
        #expect(stored.map(\.sequenceNumber) == [1, 2])
        #expect(storedBody == originalBody)
    }

    @Test func pendingBallInPlayStateSurvivesFreshContextAndColdStoreReloadAfterUndo() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "softball-scoring-bip-undo-reload-\(UUID().uuidString).store")
        let gameID = UUID()
        let pitcherID = UUID()
        var expectedState: GameState?
        var expectedRecordID: UUID?

        do {
            let container = try AppModelContainer.make(storeURL: storeURL)
            let context = container.mainContext
            let game = Game(
                id: gameID,
                seasonID: UUID(),
                opponentName: "Thunder",
                homeAway: .home,
                status: .inProgress,
                startingPitcherID: pitcherID
            )
            context.insert(game)
            let records = try seedCompletedSingle(game: game, modelContext: context)
            let restored = try GameEventCorrection.undoLatestAction(
                GameEventCorrection.prepareUndoLatestAction(game: game, modelContext: context),
                game: game,
                modelContext: context
            )
            expectedState = restored.replay.state
            expectedRecordID = records[0].id

            let freshContext = ModelContext(container)
            let freshGame = try #require(freshContext.fetch(FetchDescriptor<Game>()).first)
            let fresh = try LiveGameSnapshotLoader.load(game: freshGame, modelContext: freshContext)
            #expect(fresh.replay.state == expectedState)
            #expect(fresh.records.count == 1)
            #expect(fresh.records.first?.id == expectedRecordID)
            #expect(fresh.replay.state.isAwaitingBallInPlayResult)
            #expect(fresh.replay.state.pitchCount(for: pitcherID) == PitchCount(total: 1, balls: 0, strikes: 1))
        }

        let reloadedContainer = try AppModelContainer.make(storeURL: storeURL)
        let reloadedContext = ModelContext(reloadedContainer)
        let reloadedGame = try #require(reloadedContext.fetch(FetchDescriptor<Game>()).first)
        let reloaded = try LiveGameSnapshotLoader.load(
            game: reloadedGame,
            modelContext: reloadedContext
        )
        #expect(reloaded.replay.state == expectedState)
        #expect(reloaded.records.count == 1)
        #expect(reloaded.records.first?.id == expectedRecordID)
        #expect(reloaded.replay.state.isAwaitingBallInPlayResult)
    }

    @Test func failedUndoSaveRollsBackEveryOriginalRecord() throws {
        struct ForcedSaveError: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let records = try [PitchResult.ball, .calledStrike].enumerated().map { index, result in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                body: .pitch(.init(
                    result: result,
                    pitcherID: game.startingPitcherID!,
                    opponentBatterSlot: 1
                ))
            )
        }
        records.forEach(context.insert)
        try context.save()
        let expectedIDs = records.map(\.id)
        let expectedSequences = records.map(\.sequenceNumber)
        let expectedTimestamps = records.map(\.timestamp)
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(throws: ForcedSaveError.self) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context,
                save: { _ in throw ForcedSaveError() }
            )
        }

        let stored = try context.fetch(FetchDescriptor<GameEventRecord>())
            .sorted { $0.sequenceNumber < $1.sequenceNumber }
        #expect(stored.map(\.id) == expectedIDs)
        #expect(stored.map(\.sequenceNumber) == expectedSequences)
        #expect(stored.map(\.timestamp) == expectedTimestamps)
    }

    @Test func scoringAfterUndoUsesMaximumSurvivingSequenceWithoutCollision() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let first = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .pitch(.init(
                result: .ball,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        )
        let latest = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 7,
            body: .pitch(.init(
                result: .calledStrike,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        )
        context.insert(first)
        context.insert(latest)
        try context.save()

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let corrected = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )
        try GameEventRecorder.recordPitch(
            result: .foul,
            game: game,
            existingRecords: corrected.records,
            modelContext: context
        )

        let stored = try context.fetch(FetchDescriptor<GameEventRecord>())
        #expect(stored.map(\.sequenceNumber).sorted() == [2, 3])
        #expect(stored.first { $0.id == first.id }?.timestamp == first.timestamp)
        #expect(!stored.contains { $0.id == latest.id })
    }

    @Test func undoSurvivesFreshPersistenceContextAndColdStoreReload() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "softball-scoring-undo-reload-\(UUID().uuidString).store")
        let gameID = UUID()
        let pitcherID = UUID()
        let batters = (1...4).map { slot in
            TrackedBatterIdentity(
                playerID: UUID(),
                lineupSlot: slot,
                displayName: "Batter \(slot)",
                jerseyNumber: "\(slot)",
                position: nil
            )
        }
        var expectedState: GameState?
        var expectedBattingLines: [UUID: BattingLine]?
        var expectedHistory: PlayHistory?
        var expectedRecordIDs: [UUID]?
        var expectedSequences: [Int]?
        var expectedTimestamps: [Date]?

        do {
            let container = try AppModelContainer.make(storeURL: storeURL)
            let context = container.mainContext
            let game = Game(
                id: gameID,
                seasonID: UUID(),
                opponentName: "Thunder",
                homeAway: .away,
                status: .inProgress,
                startingPitcherID: pitcherID
            )
            context.insert(game)
            let bodies: [GameEventBody] = [
                .offensivePlateAppearance(.init(
                    batter: batters[0],
                    battingOrderSize: batters.count,
                    result: .homeRun,
                    movements: [.init(source: .batter, destination: .home)],
                    rbi: 1,
                    countedRunSources: [.batter],
                    thirdOutClassification: nil
                )),
                .offensivePlateAppearance(.init(
                    batter: batters[1],
                    battingOrderSize: batters.count,
                    result: .strikeout,
                    movements: [.init(source: .batter, destination: .out)],
                    rbi: 0,
                    countedRunSources: [],
                    thirdOutClassification: nil
                )),
                .offensivePlateAppearance(.init(
                    batter: batters[2],
                    battingOrderSize: batters.count,
                    result: .strikeout,
                    movements: [.init(source: .batter, destination: .out)],
                    rbi: 0,
                    countedRunSources: [],
                    thirdOutClassification: nil
                )),
                .offensivePlateAppearance(.init(
                    batter: batters[3],
                    battingOrderSize: batters.count,
                    result: .strikeout,
                    movements: [.init(source: .batter, destination: .out)],
                    rbi: 0,
                    countedRunSources: [],
                    thirdOutClassification: nil
                )),
                .pitch(.init(result: .calledStrike, pitcherID: pitcherID, opponentBatterSlot: 1)),
                .pitch(.init(result: .calledStrike, pitcherID: pitcherID, opponentBatterSlot: 1)),
                .pitch(.init(result: .calledStrike, pitcherID: pitcherID, opponentBatterSlot: 1))
            ]
            for (index, body) in bodies.enumerated() {
                context.insert(try GameEventRecord(
                    gameID: gameID,
                    sequenceNumber: index + 1,
                    body: body
                ))
            }
            try context.save()
            let diagnostic = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
            #expect(
                diagnostic.replay.rejectedRecordIDs.isEmpty,
                "Rejected entries: \(diagnostic.replay.entries.map { ($0.sequenceNumber, String(describing: $0.rejection)) })"
            )

            let candidate = try GameEventCorrection.prepareUndoLatestAction(
                game: game,
                modelContext: context
            )
            let immediate = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context
            )
            expectedState = immediate.replay.state
            expectedBattingLines = immediate.battingLines
            expectedHistory = immediate.history
            expectedRecordIDs = immediate.records.map(\.id)
            expectedSequences = immediate.records.map(\.sequenceNumber)
            expectedTimestamps = immediate.records.map(\.timestamp)
            #expect(immediate.replay.state.half == .bottom)
            #expect(immediate.replay.state.outs == 0)
            #expect(immediate.replay.state.currentOpponentBatterSlot == 1)
            #expect(immediate.replay.state.balls == 0)
            #expect(immediate.replay.state.strikes == 2)
            #expect(immediate.replay.state.pitchCount(for: pitcherID) == PitchCount(total: 2, balls: 0, strikes: 2))
            #expect(immediate.battingLines[batters[0].playerID]?.homeRuns == 1)

            let freshContext = ModelContext(container)
            let freshGame = try #require(freshContext.fetch(FetchDescriptor<Game>()).first)
            let fresh = try LiveGameSnapshotLoader.load(game: freshGame, modelContext: freshContext)
            #expect(fresh.replay.state == expectedState)
            #expect(fresh.battingLines == expectedBattingLines)
            #expect(fresh.history == expectedHistory)
            #expect(fresh.records.map(\.id) == expectedRecordIDs)
            #expect(fresh.records.map(\.sequenceNumber) == expectedSequences)
            #expect(fresh.records.map(\.timestamp) == expectedTimestamps)
        }

        let reloadedContainer = try AppModelContainer.make(storeURL: storeURL)
        let reloadedContext = ModelContext(reloadedContainer)
        let reloadedGame = try #require(reloadedContext.fetch(FetchDescriptor<Game>()).first)
        let reloaded = try LiveGameSnapshotLoader.load(
            game: reloadedGame,
            modelContext: reloadedContext
        )
        #expect(reloaded.replay.state == expectedState)
        #expect(reloaded.battingLines == expectedBattingLines)
        #expect(reloaded.history == expectedHistory)
        #expect(reloaded.records.map(\.id) == expectedRecordIDs)
        #expect(reloaded.records.map(\.sequenceNumber) == expectedSequences)
        #expect(reloaded.records.map(\.timestamp) == expectedTimestamps)
    }

    @Test func recorderRejectsInvalidDurableHomeAwayValue() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let game = makeGame()
        game.homeAwayRawValue = "sideways"

        #expect(throws: GameEventRecorderError.self) {
            try GameEventRecorder.recordPitch(
                result: .ball,
                game: game,
                existingRecords: [],
                modelContext: container.mainContext
            )
        }

        let records = try container.mainContext.fetch(FetchDescriptor<GameEventRecord>())
        #expect(records.isEmpty)
    }

    @Test func liveGameSnapshotLoadsOneGameFromFreshAuthoritativeRecords() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let otherGame = makeGame()
        context.insert(game)
        context.insert(otherGame)

        let strike = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .pitch(.init(
                result: .calledStrike,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        )
        let ball = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ball,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        )
        let unrelated = try GameEventRecord(
            gameID: otherGame.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ball,
                pitcherID: otherGame.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        )
        context.insert(strike)
        context.insert(unrelated)
        context.insert(ball)
        try context.save()

        let snapshot = try LiveGameSnapshotLoader.load(game: game, modelContext: context)

        #expect(snapshot.records.map(\.id) == [ball.id, strike.id])
        #expect(snapshot.replay.state.balls == 1)
        #expect(snapshot.replay.state.strikes == 1)
        #expect(snapshot.replay.state.pitchCount(for: game.startingPitcherID!).total == 2)
        #expect(snapshot.battingLines.isEmpty)
        #expect(snapshot.history.sections[0].entries[0].components.map(\.sequenceNumber) == [1, 2])
    }

    @Test func liveGameSessionSurfacesMismatchedGameInsteadOfKeepingStaleSnapshot() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let game = makeGame()
        let otherGame = makeGame()
        let session = LiveGameSession(gameID: game.id)

        session.refresh(game: game, modelContext: container.mainContext)
        #expect(session.snapshot != nil)

        session.refresh(game: otherGame, modelContext: container.mainContext)

        #expect(session.snapshot == nil)
        #expect(session.loadError == "The live-game session does not match this game.")
    }

    @Test func stagedDefensivePitchDeletionSavesExactRecordAndPreservesSequenceGap() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let timestamps = [
            Date(timeIntervalSince1970: 1_786_600_000),
            Date(timeIntervalSince1970: 1_786_600_010),
            Date(timeIntervalSince1970: 1_786_600_020)
        ]
        let results: [PitchResult] = [.ball, .calledStrike, .foul]
        let records = try results.enumerated().map { index, result in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                timestamp: timestamps[index],
                body: .pitch(.init(
                    result: result,
                    pitcherID: pitcherID,
                    opponentBatterSlot: 1
                ))
            )
        }
        records.forEach(context.insert)
        try context.save()

        let session = try GameEventCorrection.prepareDefensivePitchDeletion(
            recordID: records[1].id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensivePitchDeletion(
            session,
            game: game,
            modelContext: context
        )

        #expect(session.originalResult == .calledStrike)
        #expect(preview.canSave)
        #expect(preview.firstInvalidRecord == nil)
        #expect(preview.snapshot.records.map(\.sequenceNumber) == [1, 3])
        #expect(preview.snapshot.replay.state.balls == 1)
        #expect(preview.snapshot.replay.state.strikes == 1)
        #expect(preview.snapshot.replay.state.pitchCount(for: pitcherID) == PitchCount(
            total: 2,
            balls: 1,
            strikes: 1
        ))

        let stagedStored = try context.fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stagedStored.map(\.id) == records.map(\.id))

        _ = try GameEventCorrection.saveDefensivePitchDeletion(
            preview,
            game: game,
            modelContext: context
        )

        let reloaded = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(reloaded.records.map(\.id) == [records[0].id, records[2].id])
        #expect(reloaded.records.map(\.sequenceNumber) == [1, 3])
        #expect(reloaded.records.map(\.timestamp) == [timestamps[0], timestamps[2]])
        #expect(reloaded.replay.state.balls == 1)
        #expect(reloaded.replay.state.strikes == 1)
        #expect(reloaded.replay.state.pitchCount(for: pitcherID) == PitchCount(
            total: 2,
            balls: 1,
            strikes: 1
        ))
    }

    @Test func completedDefensiveLogicalPlayDeletionRemovesExactPairAndReplaysPrePitchState() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let timestamps = (0..<3).map {
            Date(timeIntervalSince1970: 1_786_650_000 + Double($0 * 10))
        }
        let ball = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            timestamp: timestamps[0],
            body: .pitch(.init(
                result: .ball,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        let inPlayPitch = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            timestamp: timestamps[1],
            body: .pitch(.init(
                result: .ballInPlay,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        let result = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 3,
            timestamp: timestamps[2],
            body: .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        )
        [ball, inPlayPitch, result].forEach(context.insert)
        try context.save()

        let deletion = try GameEventCorrection.prepareDefensiveLogicalPlayDeletion(
            resultRecordID: result.id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensiveLogicalPlayDeletion(
            deletion,
            game: game,
            modelContext: context
        )

        #expect(deletion.components.map(\.recordID) == [inPlayPitch.id, result.id])
        #expect(deletion.components.map(\.sequenceNumber) == [2, 3])
        #expect(deletion.components.map(\.summary) == ["Ball In Play pitch", "Single result"])
        #expect(preview.canSave)
        #expect(preview.firstInvalidRecord == nil)
        #expect(preview.snapshot.records.map(\.id) == [ball.id])
        #expect(preview.snapshot.replay.state.balls == 1)
        #expect(preview.snapshot.replay.state.strikes == 0)
        #expect(preview.snapshot.replay.state.baseRunnerSlots == [nil, nil, nil])
        #expect(preview.snapshot.replay.state.outs == 0)
        #expect(preview.snapshot.replay.state.awayScore == 0)
        #expect(preview.snapshot.replay.state.currentOpponentBatterSlot == 1)
        #expect(preview.snapshot.replay.state.pitchCount(for: pitcherID) == PitchCount(
            total: 1,
            balls: 1,
            strikes: 0
        ))

        let storedBeforeSave = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        let expectedStoredIDs = [ball.id, inPlayPitch.id, result.id]
        #expect(storedBeforeSave.map(\.id) == expectedStoredIDs)

        _ = try GameEventCorrection.saveDefensiveLogicalPlayDeletion(
            preview,
            game: game,
            modelContext: context
        )
        let reloaded = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )

        #expect(reloaded.records.map(\.id) == [ball.id])
        #expect(reloaded.records.map(\.sequenceNumber) == [1])
        #expect(reloaded.records.map(\.timestamp) == [timestamps[0]])
        #expect(reloaded.replay.state == preview.snapshot.replay.state)
    }

    @Test func completedTrackedTeamLogicalPlayDeletionRemovesItsPitchesAndResultOnly() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let firstBatter = makeTrackedBatter()
        let secondBatter = makeTrackedBatter(
            displayName: "Jordan Lee",
            jerseyNumber: "12",
            position: .centerField,
            lineupSlot: 2
        )
        let timestamps = (0..<5).map {
            Date(timeIntervalSince1970: 1_786_655_000 + Double($0 * 10))
        }
        let bodies: [GameEventBody] = [
            .offensivePlateAppearance(.init(
                batter: firstBatter,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePitch(.init(
                batter: secondBatter,
                battingOrderSize: 10,
                result: .ball
            )),
            .offensiveBaseRunning(.init(
                runnerID: firstBatter.playerID,
                source: .first,
                destination: .second,
                result: .stolenBase
            )),
            .offensivePitch(.init(
                batter: secondBatter,
                battingOrderSize: 10,
                result: .calledStrike
            )),
            .offensivePlateAppearance(.init(
                batter: secondBatter,
                battingOrderSize: 10,
                result: .double,
                movements: [
                    .init(source: .second, destination: .home),
                    .init(source: .batter, destination: .second)
                ],
                rbi: 1,
                countedRunSources: [.second],
                thirdOutClassification: nil
            ))
        ]
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                timestamp: timestamps[index],
                body: body
            )
        }
        records.forEach(context.insert)
        try context.save()

        let deletion = try GameEventCorrection.prepareOffensiveLogicalPlayDeletion(
            resultRecordID: records[4].id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageOffensiveLogicalPlayDeletion(
            deletion,
            game: game,
            modelContext: context
        )

        #expect(deletion.components.map(\.recordID) == [records[1].id, records[3].id, records[4].id])
        #expect(deletion.components.map(\.sequenceNumber) == [2, 4, 5])
        #expect(deletion.components.map(\.summary) == [
            "Ball pitch", "Called Strike pitch", "Double result"
        ])
        #expect(preview.canSave)
        #expect(preview.firstInvalidRecord == nil)
        #expect(preview.snapshot.records.map(\.id) == [records[0].id, records[2].id])
        #expect(preview.snapshot.replay.state.balls == 0)
        #expect(preview.snapshot.replay.state.strikes == 0)
        #expect(preview.snapshot.replay.state.outs == 0)
        #expect(preview.snapshot.replay.state.awayScore == 0)
        #expect(preview.snapshot.replay.state.currentTrackedBatterSlot == 2)
        #expect(preview.snapshot.replay.state.secondBaseRunnerPlayerID == firstBatter.playerID)
        #expect(preview.snapshot.battingLines[firstBatter.playerID]?.plateAppearances == 1)
        #expect(preview.snapshot.battingLines[firstBatter.playerID]?.hits == 1)
        #expect(preview.snapshot.battingLines[firstBatter.playerID]?.stolenBases == 1)
        #expect(preview.snapshot.battingLines[secondBatter.playerID] == nil)

        let storedBeforeSave = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(storedBeforeSave.map(\.id) == records.map(\.id))

        _ = try GameEventCorrection.saveOffensiveLogicalPlayDeletion(
            preview,
            game: game,
            modelContext: context
        )
        let reloaded = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )

        #expect(reloaded.records.map(\.id) == [records[0].id, records[2].id])
        #expect(reloaded.records.map(\.sequenceNumber) == [1, 3])
        #expect(reloaded.records.map(\.timestamp) == [timestamps[0], timestamps[2]])
        #expect(reloaded.replay.state == preview.snapshot.replay.state)
        #expect(reloaded.battingLines == preview.snapshot.battingLines)
    }

    @Test func trackedTeamLogicalPlayDeletionStagesInvalidDownstreamPitchForRepair() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let firstBatter = makeTrackedBatter()
        let secondBatter = makeTrackedBatter(lineupSlot: 2)
        let bodies: [GameEventBody] = [
            .offensivePitch(.init(
                batter: firstBatter,
                battingOrderSize: 10,
                result: .ball
            )),
            .offensivePlateAppearance(.init(
                batter: firstBatter,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePitch(.init(
                batter: secondBatter,
                battingOrderSize: 10,
                result: .calledStrike
            ))
        ]
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let deletion = try GameEventCorrection.prepareOffensiveLogicalPlayDeletion(
            resultRecordID: records[1].id,
            game: game,
            modelContext: context
        )
        let invalidPreview = try GameEventCorrection.stageOffensiveLogicalPlayDeletion(
            deletion,
            game: game,
            modelContext: context
        )

        #expect(!invalidPreview.canSave)
        #expect(invalidPreview.firstInvalidRecord?.id == records[2].id)
        #expect(invalidPreview.firstInvalidRecord?.canDeleteOffensivePitch == true)
        #expect(throws: GameEventCorrectionError.invalidCandidate) {
            _ = try GameEventCorrection.saveOffensiveLogicalPlayDeletion(
                invalidPreview,
                game: game,
                modelContext: context
            )
        }

        let repaired = try GameEventCorrection.stageOffensivePitchDeletion(
            recordID: records[2].id,
            in: invalidPreview.correctionSession,
            game: game,
            modelContext: context
        )

        #expect(repaired.canSave)
        #expect(repaired.firstInvalidRecord == nil)
        #expect(repaired.stagedLogicalPlayDeletions[0].recordIDs == [
            records[0].id, records[1].id
        ])
        #expect(repaired.stagedOffensivePitchChanges.map(\.recordID) == [records[2].id])

        _ = try GameEventCorrection.saveGameEventCorrection(
            repaired,
            game: game,
            modelContext: context
        )
        let reloaded = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(reloaded.records.isEmpty)
        #expect(reloaded.replay.state == GameState())
        #expect(reloaded.battingLines.isEmpty)
    }

    @Test func trackedTeamLogicalPlayDeletionCanDeleteAffectedDownstreamCompletedPlay() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let firstBatter = makeTrackedBatter()
        let secondBatter = makeTrackedBatter(lineupSlot: 2)
        let bodies: [GameEventBody] = [
            .offensivePitch(.init(
                batter: firstBatter,
                battingOrderSize: 10,
                result: .ball
            )),
            .offensivePlateAppearance(.init(
                batter: firstBatter,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePitch(.init(
                batter: secondBatter,
                battingOrderSize: 10,
                result: .calledStrike
            )),
            .offensivePlateAppearance(.init(
                batter: secondBatter,
                battingOrderSize: 10,
                result: .single,
                movements: [
                    .init(source: .first, destination: .second),
                    .init(source: .batter, destination: .first)
                ],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ))
        ]
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let deletion = try GameEventCorrection.prepareOffensiveLogicalPlayDeletion(
            resultRecordID: records[1].id,
            game: game,
            modelContext: context
        )
        let invalidPreview = try GameEventCorrection.stageOffensiveLogicalPlayDeletion(
            deletion,
            game: game,
            modelContext: context
        )

        #expect(!invalidPreview.canSave)
        #expect(invalidPreview.firstInvalidRecord?.id == records[2].id)
        #expect(
            invalidPreview.firstInvalidRecord?.logicalPlayDeletion?.resultRecordID
                == records[3].id
        )

        let repaired = try GameEventCorrection.stageOffensiveLogicalPlayDeletion(
            resultRecordID: records[3].id,
            in: invalidPreview.correctionSession,
            game: game,
            modelContext: context
        )

        #expect(repaired.canSave)
        #expect(repaired.firstInvalidRecord == nil)
        #expect(repaired.stagedLogicalPlayDeletions.map(\.recordIDs) == [
            [records[0].id, records[1].id],
            [records[2].id, records[3].id]
        ])

        _ = try GameEventCorrection.saveGameEventCorrection(
            repaired,
            game: game,
            modelContext: context
        )
        let reloaded = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(reloaded.records.isEmpty)
        #expect(reloaded.replay.state == GameState())
        #expect(reloaded.battingLines.isEmpty)
    }

    @Test func trackedTeamLogicalPlayDeletionCanDeleteAffectedBaseRunningEvent() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let bodies: [GameEventBody] = [
            .offensivePlateAppearance(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensiveBaseRunning(.init(
                runnerID: batter.playerID,
                source: .first,
                destination: .second,
                result: .stolenBase
            ))
        ]
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let deletion = try GameEventCorrection.prepareOffensiveLogicalPlayDeletion(
            resultRecordID: records[0].id,
            game: game,
            modelContext: context
        )
        let invalidPreview = try GameEventCorrection.stageOffensiveLogicalPlayDeletion(
            deletion,
            game: game,
            modelContext: context
        )

        #expect(invalidPreview.firstInvalidRecord?.id == records[1].id)
        #expect(invalidPreview.firstInvalidRecord?.canDeleteOffensiveBaseRunning == true)
        let repaired = try GameEventCorrection.stageOffensiveBaseRunningDeletion(
            recordID: records[1].id,
            in: invalidPreview.correctionSession,
            game: game,
            modelContext: context
        )

        #expect(repaired.canSave)
        #expect(repaired.firstInvalidRecord == nil)
        _ = try GameEventCorrection.saveGameEventCorrection(
            repaired,
            game: game,
            modelContext: context
        )
        let reloaded = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(reloaded.records.isEmpty)
        #expect(reloaded.replay.state == GameState())
        #expect(reloaded.battingLines.isEmpty)
    }

    @Test func trackedTeamThirdOutDeletionCanDeleteAffectedDefensiveLogicalPlay() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batters = (1...3).map { makeTrackedBatter(lineupSlot: $0) }
        let bodies: [GameEventBody] = batters.map { batter in
            .offensivePlateAppearance(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .strikeout,
                movements: [.init(source: .batter, destination: .out)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ))
        } + [
            .pitch(.init(
                result: .ballInPlay,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            )),
            .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        ]
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let deletion = try GameEventCorrection.prepareOffensiveLogicalPlayDeletion(
            resultRecordID: records[2].id,
            game: game,
            modelContext: context
        )
        let invalidPreview = try GameEventCorrection.stageOffensiveLogicalPlayDeletion(
            deletion,
            game: game,
            modelContext: context
        )

        #expect(invalidPreview.firstInvalidRecord?.id == records[3].id)
        #expect(
            invalidPreview.firstInvalidRecord?.logicalPlayDeletion?.resultRecordID
                == records[4].id
        )
        let repaired = try GameEventCorrection.stageDefensiveLogicalPlayDeletion(
            resultRecordID: records[4].id,
            in: invalidPreview.correctionSession,
            game: game,
            modelContext: context
        )

        #expect(repaired.canSave)
        #expect(repaired.firstInvalidRecord == nil)
        #expect(repaired.stagedLogicalPlayDeletions.map(\.recordIDs) == [
            [records[2].id],
            [records[3].id, records[4].id]
        ])
        _ = try GameEventCorrection.saveGameEventCorrection(
            repaired,
            game: game,
            modelContext: context
        )
        let reloaded = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(reloaded.records.map(\.id) == [records[0].id, records[1].id])
        #expect(reloaded.replay.state.outs == 2)
        #expect(reloaded.replay.state.half == .top)
        #expect(reloaded.replay.state.currentTrackedBatterSlot == 3)
    }

    @Test func trackedTeamLogicalPlayDeletionFailuresPreserveCompleteOriginalPlay() throws {
        struct ProjectionFailure: Error {}
        struct SaveFailure: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let otherGame = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let bodies: [GameEventBody] = [
            .offensivePitch(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .ball
            )),
            .offensivePlateAppearance(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .homeRun,
                movements: [.init(source: .batter, destination: .home)],
                rbi: 1,
                countedRunSources: [.batter],
                thirdOutClassification: nil
            ))
        ]
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let deletion = try GameEventCorrection.prepareOffensiveLogicalPlayDeletion(
            resultRecordID: records[1].id,
            game: game,
            modelContext: context
        )
        #expect(throws: GameEventCorrectionError.gameMismatch) {
            _ = try GameEventCorrection.stageOffensiveLogicalPlayDeletion(
                deletion,
                game: otherGame,
                modelContext: context
            )
        }
        #expect(throws: ProjectionFailure.self) {
            _ = try GameEventCorrection.stageOffensiveLogicalPlayDeletion(
                deletion,
                game: game,
                modelContext: context,
                projectBattingLines: { _ in throw ProjectionFailure() }
            )
        }

        let preview = try GameEventCorrection.stageOffensiveLogicalPlayDeletion(
            deletion,
            game: game,
            modelContext: context
        )
        #expect(throws: SaveFailure.self) {
            _ = try GameEventCorrection.saveOffensiveLogicalPlayDeletion(
                preview,
                game: game,
                modelContext: context,
                save: { _ in throw SaveFailure() }
            )
        }
        var stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stored.map(\.id) == records.map(\.id))
        #expect(try stored.map { try $0.decoded().body } == bodies)

        let newer = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 3,
            body: .offensivePitch(.init(
                batter: makeTrackedBatter(lineupSlot: 2),
                battingOrderSize: 10,
                result: .calledStrike
            ))
        )
        context.insert(newer)
        try context.save()

        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.saveOffensiveLogicalPlayDeletion(
                preview,
                game: game,
                modelContext: context
            )
        }
        stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stored.map(\.id) == records.map(\.id) + [newer.id])
    }

    @Test func logicalPlayDeletionStagesFirstInvalidDownstreamRecordForAtomicRepair() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let records = try [
            GameEventBody.pitch(.init(
                result: .ball,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            )),
            .pitch(.init(
                result: .ballInPlay,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            )),
            .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            )),
            .pitch(.init(
                result: .calledStrike,
                pitcherID: pitcherID,
                opponentBatterSlot: 2
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let deletion = try GameEventCorrection.prepareDefensiveLogicalPlayDeletion(
            resultRecordID: records[2].id,
            game: game,
            modelContext: context
        )
        let invalidPreview = try GameEventCorrection.stageDefensiveLogicalPlayDeletion(
            deletion,
            game: game,
            modelContext: context
        )

        #expect(!invalidPreview.canSave)
        #expect(invalidPreview.firstInvalidRecord?.id == records[3].id)
        #expect(invalidPreview.firstInvalidRecord?.sequenceNumber == 4)
        #expect(invalidPreview.firstInvalidRecord?.canDeletePitch == true)
        #expect(invalidPreview.snapshot.records.map(\.id) == [records[0].id, records[3].id])
        #expect(throws: GameEventCorrectionError.invalidCandidate) {
            _ = try GameEventCorrection.saveDefensiveLogicalPlayDeletion(
                invalidPreview,
                game: game,
                modelContext: context
            )
        }

        let stagedSession = invalidPreview.correctionSession
        let repaired = try GameEventCorrection.stagePitchDeletion(
            recordID: records[3].id,
            in: stagedSession,
            game: game,
            modelContext: context
        )

        #expect(repaired.canSave)
        #expect(repaired.firstInvalidRecord == nil)
        #expect(repaired.stagedLogicalPlayDeletions[0].recordIDs == [
            records[1].id, records[2].id
        ])
        #expect(repaired.stagedChanges.map(\.recordID) == [records[3].id])

        _ = try GameEventCorrection.saveGameEventCorrection(
            repaired,
            game: game,
            modelContext: context
        )
        let reloaded = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(reloaded.records.map(\.id) == [records[0].id])
        #expect(reloaded.records.map(\.sequenceNumber) == [1])
        #expect(reloaded.replay.state.balls == 1)
        #expect(reloaded.replay.state.currentOpponentBatterSlot == 1)
        #expect(reloaded.replay.state.pitchCount(for: pitcherID).total == 1)
    }

    @Test func logicalPlayDeletionFailuresPreserveBothOriginalComponents() throws {
        struct SaveFailure: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let otherGame = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let records = try defensiveBallInPlayRecords(
            for: [
                .init(
                    outcome: .single,
                    opponentBatterSlot: 1,
                    movements: [.init(source: .batter, destination: .first)],
                    rbi: 0,
                    thirdOutRunsCounted: nil
                )
            ],
            gameID: game.id,
            pitcherID: pitcherID
        )
        records.forEach(context.insert)
        try context.save()

        let deletion = try GameEventCorrection.prepareDefensiveLogicalPlayDeletion(
            resultRecordID: records[1].id,
            game: game,
            modelContext: context
        )
        #expect(throws: GameEventCorrectionError.gameMismatch) {
            _ = try GameEventCorrection.stageDefensiveLogicalPlayDeletion(
                deletion,
                game: otherGame,
                modelContext: context
            )
        }
        let preview = try GameEventCorrection.stageDefensiveLogicalPlayDeletion(
            deletion,
            game: game,
            modelContext: context
        )
        #expect(throws: SaveFailure.self) {
            _ = try GameEventCorrection.saveDefensiveLogicalPlayDeletion(
                preview,
                game: game,
                modelContext: context,
                save: { _ in throw SaveFailure() }
            )
        }

        var stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stored.map(\.id) == records.map(\.id))
        #expect(try stored.map { try $0.decoded().body } == records.map { try $0.decoded().body })

        let newer = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 3,
            body: .pitch(.init(
                result: .ball,
                pitcherID: pitcherID,
                opponentBatterSlot: 2
            ))
        )
        context.insert(newer)
        try context.save()

        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.saveDefensiveLogicalPlayDeletion(
                preview,
                game: game,
                modelContext: context
            )
        }
        stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stored.map(\.id) == records.map(\.id) + [newer.id])
    }

    @Test func logicalPlayDeletionReproducesCandidateAfterColdStoreReload() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "softball-scoring-logical-play-delete-\(UUID().uuidString).store")
        let gameID = UUID()
        let pitcherID = UUID()
        let survivorID = UUID()
        let survivorTimestamp = Date(timeIntervalSince1970: 1_786_660_000)
        var expectedState = GameState()

        do {
            let container = try AppModelContainer.make(storeURL: storeURL)
            let context = container.mainContext
            let game = Game(
                id: gameID,
                seasonID: UUID(),
                opponentName: "Thunder",
                homeAway: .home,
                status: .inProgress,
                startingPitcherID: pitcherID
            )
            context.insert(game)
            let survivor = try GameEventRecord(
                id: survivorID,
                gameID: gameID,
                sequenceNumber: 1,
                timestamp: survivorTimestamp,
                body: .pitch(.init(
                    result: .ball,
                    pitcherID: pitcherID,
                    opponentBatterSlot: 1
                ))
            )
            let pair = try defensiveBallInPlayRecords(
                for: [
                    .init(
                        outcome: .homeRun,
                        opponentBatterSlot: 1,
                        movements: [.init(source: .batter, destination: .home)],
                        rbi: 1,
                        thirdOutRunsCounted: nil
                    )
                ],
                gameID: gameID,
                pitcherID: pitcherID
            )
            pair[0].sequenceNumber = 2
            pair[1].sequenceNumber = 3
            context.insert(survivor)
            pair.forEach(context.insert)
            try context.save()

            let deletion = try GameEventCorrection.prepareDefensiveLogicalPlayDeletion(
                resultRecordID: pair[1].id,
                game: game,
                modelContext: context
            )
            let preview = try GameEventCorrection.stageDefensiveLogicalPlayDeletion(
                deletion,
                game: game,
                modelContext: context
            )
            expectedState = preview.snapshot.replay.state
            _ = try GameEventCorrection.saveDefensiveLogicalPlayDeletion(
                preview,
                game: game,
                modelContext: context
            )
        }

        let reloadedContainer = try AppModelContainer.make(storeURL: storeURL)
        let reloadedContext = ModelContext(reloadedContainer)
        let reloadedGame = try #require(reloadedContext.fetch(FetchDescriptor<Game>()).first)
        let reloaded = try LiveGameSnapshotLoader.load(
            game: reloadedGame,
            modelContext: reloadedContext
        )

        #expect(reloaded.records.map(\.id) == [survivorID])
        #expect(reloaded.records.map(\.sequenceNumber) == [1])
        #expect(reloaded.records.map(\.timestamp) == [survivorTimestamp])
        #expect(reloaded.replay.state == expectedState)
        #expect(reloaded.replay.state.balls == 1)
        #expect(reloaded.replay.state.currentOpponentBatterSlot == 1)
        #expect(reloaded.replay.state.pitchCount(for: pitcherID) == PitchCount(
            total: 1,
            balls: 1,
            strikes: 0
        ))
        #expect(reloaded.battingLines.isEmpty)
    }

    @Test func deletingPitchThatInvalidatesLaterPlayDisablesSaveAndPreservesHistory() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let pitch = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ballInPlay,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        let result = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        )
        context.insert(pitch)
        context.insert(result)
        try context.save()

        let session = try GameEventCorrection.prepareDefensivePitchDeletion(
            recordID: pitch.id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensivePitchDeletion(
            session,
            game: game,
            modelContext: context
        )

        #expect(!preview.canSave)
        #expect(preview.firstInvalidRecord == DefensivePitchCorrectionInvalidRecord(
            id: result.id,
            sequenceNumber: 2,
            summary: "Play conflicts with the proposed pitch"
        ))
        #expect(preview.snapshot.replay.rejectedRecordIDs == [result.id])
        #expect(throws: GameEventCorrectionError.invalidCandidate) {
            _ = try GameEventCorrection.saveDefensivePitchDeletion(
                preview,
                game: game,
                modelContext: context
            )
        }

        let stored = try context.fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stored.map(\.id) == [pitch.id, result.id])
    }

    @Test func multipleStagedPitchChangesRepairInvalidTimelineAndSaveAtomically() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let timestamps = (0..<5).map {
            Date(timeIntervalSince1970: 1_786_700_000 + Double($0 * 10))
        }
        let records = try (1...5).map { sequence in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: sequence,
                timestamp: timestamps[sequence - 1],
                body: .pitch(.init(
                    result: sequence <= 4 ? .ball : .calledStrike,
                    pitcherID: pitcherID,
                    opponentBatterSlot: sequence <= 4 ? 1 : 2
                ))
            )
        }
        records.forEach(context.insert)
        try context.save()

        let session = try GameEventCorrection.beginGameEventCorrection(
            game: game,
            modelContext: context
        )
        let invalidCandidate = try GameEventCorrection.stagePitchDeletion(
            recordID: records[0].id,
            in: session,
            game: game,
            modelContext: context
        )

        #expect(!invalidCandidate.canSave)
        #expect(invalidCandidate.stagedChanges.map(\.recordID) == [records[0].id])
        #expect(invalidCandidate.firstInvalidRecord?.id == records[4].id)
        #expect(invalidCandidate.firstInvalidRecord?.sequenceNumber == 5)
        #expect(invalidCandidate.firstInvalidRecord?.context ==
            "Top 1 · Opponent batter 2 · Called Strike")
        #expect(invalidCandidate.firstInvalidRecord?.explanation ==
            "Full replay reached opponent batter 1 with a 3–0 count before rejecting this pitch.")

        let repairedCandidate = try GameEventCorrection.stagePitchDeletion(
            recordID: records[4].id,
            in: invalidCandidate,
            game: game,
            modelContext: context
        )

        #expect(repairedCandidate.canSave)
        #expect(repairedCandidate.firstInvalidRecord == nil)
        #expect(repairedCandidate.stagedChanges.map(\.recordID) == [records[0].id, records[4].id])
        #expect(repairedCandidate.stagedChanges.map(\.sequenceNumber) == [1, 5])

        let stagedStored = try context.fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stagedStored.map(\.id) == records.map(\.id))

        _ = try GameEventCorrection.saveGameEventCorrection(
            repairedCandidate,
            game: game,
            modelContext: context
        )

        let reloaded = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(reloaded.records.map(\.id) == Array(records[1...3]).map(\.id))
        #expect(reloaded.records.map(\.sequenceNumber) == [2, 3, 4])
        #expect(reloaded.records.map(\.timestamp) == Array(timestamps[1...3]))
        #expect(reloaded.replay.rejectedRecordIDs.isEmpty)
        #expect(reloaded.replay.state.currentOpponentBatterSlot == 1)
        #expect(reloaded.replay.state.balls == 3)
        #expect(reloaded.replay.state.strikes == 0)
        #expect(reloaded.replay.state.pitchCount(for: pitcherID) == PitchCount(
            total: 3,
            balls: 3,
            strikes: 0
        ))
        #expect(reloaded.battingLines.isEmpty)
    }

    @Test func failedOrStaleBatchCorrectionPreservesEveryOriginalRecord() throws {
        struct ProjectionFailure: Error {}
        struct SaveFailure: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let otherGame = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let records = try [PitchResult.ball, .calledStrike, .foul]
            .enumerated()
            .map { index, result in
                try GameEventRecord(
                    gameID: game.id,
                    sequenceNumber: index + 1,
                    body: .pitch(.init(
                        result: result,
                        pitcherID: pitcherID,
                        opponentBatterSlot: 1
                    ))
                )
            }
        records.forEach(context.insert)
        try context.save()

        let session = try GameEventCorrection.beginGameEventCorrection(
            game: game,
            modelContext: context
        )
        #expect(!session.canSave)
        #expect(throws: GameEventCorrectionError.gameMismatch) {
            _ = try GameEventCorrection.stagePitchDeletion(
                recordID: records[0].id,
                in: session,
                game: otherGame,
                modelContext: context
            )
        }
        #expect(throws: ProjectionFailure.self) {
            _ = try GameEventCorrection.stagePitchEdit(
                recordID: records[0].id,
                result: .swingingStrike,
                in: session,
                game: game,
                modelContext: context,
                projectBattingLines: { _ in throw ProjectionFailure() }
            )
        }

        let edited = try GameEventCorrection.stagePitchEdit(
            recordID: records[0].id,
            result: .swingingStrike,
            in: session,
            game: game,
            modelContext: context
        )
        let mixedBatch = try GameEventCorrection.stagePitchDeletion(
            recordID: records[1].id,
            in: edited,
            game: game,
            modelContext: context
        )
        #expect(mixedBatch.canSave)
        #expect(mixedBatch.stagedChanges.map(\.action) == [
            .edit(.swingingStrike),
            .delete
        ])

        #expect(throws: SaveFailure.self) {
            _ = try GameEventCorrection.saveGameEventCorrection(
                mixedBatch,
                game: game,
                modelContext: context,
                save: { _ in throw SaveFailure() }
            )
        }
        var stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stored.map(\.id) == records.map(\.id))
        let storedBodies = try stored.map { try $0.decoded().body }
        let originalBodies = try records.map { try $0.decoded().body }
        #expect(storedBodies == originalBodies)

        let newer = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 4,
            body: .pitch(.init(
                result: .ball,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        context.insert(newer)
        try context.save()

        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.saveGameEventCorrection(
                mixedBatch,
                game: game,
                modelContext: context
            )
        }
        stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stored.map(\.id) == records.map(\.id) + [newer.id])
    }

    @Test func batchCorrectionSurvivesColdStoreReloadWithMatchingProjections() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "softball-scoring-batch-correction-reload-\(UUID().uuidString).store")
        let gameID = UUID()
        let pitcherID = UUID()
        var survivingIDs: [UUID] = []

        do {
            let container = try AppModelContainer.make(storeURL: storeURL)
            let context = container.mainContext
            let game = Game(
                id: gameID,
                seasonID: UUID(),
                opponentName: "Thunder",
                homeAway: .home,
                status: .inProgress,
                startingPitcherID: pitcherID
            )
            context.insert(game)
            let records = try (1...5).map { sequence in
                try GameEventRecord(
                    gameID: gameID,
                    sequenceNumber: sequence,
                    body: .pitch(.init(
                        result: sequence <= 4 ? .ball : .calledStrike,
                        pitcherID: pitcherID,
                        opponentBatterSlot: sequence <= 4 ? 1 : 2
                    ))
                )
            }
            records.forEach(context.insert)
            try context.save()

            let session = try GameEventCorrection.beginGameEventCorrection(
                game: game,
                modelContext: context
            )
            let invalid = try GameEventCorrection.stagePitchDeletion(
                recordID: records[0].id,
                in: session,
                game: game,
                modelContext: context
            )
            let repaired = try GameEventCorrection.stagePitchDeletion(
                recordID: records[4].id,
                in: invalid,
                game: game,
                modelContext: context
            )
            _ = try GameEventCorrection.saveGameEventCorrection(
                repaired,
                game: game,
                modelContext: context
            )
            survivingIDs = Array(records[1...3]).map(\.id)
        }

        let reloadedContainer = try AppModelContainer.make(storeURL: storeURL)
        let reloadedContext = ModelContext(reloadedContainer)
        let reloadedGame = try #require(reloadedContext.fetch(FetchDescriptor<Game>()).first)
        let reloaded = try LiveGameSnapshotLoader.load(
            game: reloadedGame,
            modelContext: reloadedContext
        )

        #expect(reloaded.records.map(\.id) == survivingIDs)
        #expect(reloaded.records.map(\.sequenceNumber) == [2, 3, 4])
        #expect(reloaded.replay.rejectedRecordIDs.isEmpty)
        #expect(reloaded.replay.state.currentOpponentBatterSlot == 1)
        #expect(reloaded.replay.state.balls == 3)
        #expect(reloaded.replay.state.pitchCount(for: pitcherID) == PitchCount(
            total: 3,
            balls: 3,
            strikes: 0
        ))
        #expect(reloaded.battingLines.isEmpty)
        #expect(reloaded.history.sections.flatMap(\.entries).count == 1)
    }

    @Test func rejectedPitchDeletionInputsAndSaveFailurePreserveEveryRecord() throws {
        struct ProjectionFailure: Error {}
        struct SaveFailure: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let otherGame = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let original = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ball,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        context.insert(original)
        try context.save()

        #expect(throws: GameEventCorrectionError.pitchNotDeletable) {
            _ = try GameEventCorrection.prepareDefensivePitchDeletion(
                recordID: UUID(),
                game: game,
                modelContext: context
            )
        }
        #expect(GameEventCorrectionError.pitchNotDeletable.errorDescription ==
            "This saved event is not a defensive pitch that can be deleted.")

        let session = try GameEventCorrection.prepareDefensivePitchDeletion(
            recordID: original.id,
            game: game,
            modelContext: context
        )
        #expect(throws: GameEventCorrectionError.gameMismatch) {
            _ = try GameEventCorrection.stageDefensivePitchDeletion(
                session,
                game: otherGame,
                modelContext: context
            )
        }
        #expect(throws: ProjectionFailure.self) {
            _ = try GameEventCorrection.stageDefensivePitchDeletion(
                session,
                game: game,
                modelContext: context,
                projectBattingLines: { _ in throw ProjectionFailure() }
            )
        }

        let preview = try GameEventCorrection.stageDefensivePitchDeletion(
            session,
            game: game,
            modelContext: context
        )
        #expect(throws: GameEventCorrectionError.gameMismatch) {
            _ = try GameEventCorrection.saveDefensivePitchDeletion(
                preview,
                game: otherGame,
                modelContext: context
            )
        }
        #expect(throws: SaveFailure.self) {
            _ = try GameEventCorrection.saveDefensivePitchDeletion(
                preview,
                game: game,
                modelContext: context,
                save: { _ in throw SaveFailure() }
            )
        }

        var stored = try context.fetch(FetchDescriptor<GameEventRecord>())
        #expect(stored.map(\.id) == [original.id])

        let newer = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .pitch(.init(
                result: .foul,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        context.insert(newer)
        try context.save()
        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.stageDefensivePitchDeletion(
                session,
                game: game,
                modelContext: context
            )
        }

        stored = try context.fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stored.map(\.id) == [original.id, newer.id])
    }

    @Test func pitchDeletionDoesNotSaveOrRollbackPendingUIContextChanges() throws {
        struct SaveFailure: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let original = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ball,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        context.insert(original)
        try context.save()

        let pendingPlayer = Player(
            firstName: "Pending",
            lastName: "Change",
            jerseyNumber: "99"
        )
        context.insert(pendingPlayer)
        let session = try GameEventCorrection.prepareDefensivePitchDeletion(
            recordID: original.id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensivePitchDeletion(
            session,
            game: game,
            modelContext: context
        )

        #expect(throws: SaveFailure.self) {
            _ = try GameEventCorrection.saveDefensivePitchDeletion(
                preview,
                game: game,
                modelContext: context,
                save: { _ in throw SaveFailure() }
            )
        }
        #expect(try context.fetch(FetchDescriptor<Player>()).map(\.id) == [pendingPlayer.id])

        _ = try GameEventCorrection.saveDefensivePitchDeletion(
            preview,
            game: game,
            modelContext: context
        )

        let freshContext = ModelContext(container)
        #expect(try freshContext.fetch(FetchDescriptor<Player>()).isEmpty)
        #expect(try freshContext.fetch(FetchDescriptor<GameEventRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Player>()).map(\.id) == [pendingPlayer.id])
    }

    @Test func recordingAfterPitchDeletionUsesMaximumSurvivingSequence() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let sequences = [1, 2, 4]
        let results: [PitchResult] = [.ball, .calledStrike, .foul]
        let records = try zip(sequences, results).map { sequence, result in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: sequence,
                body: .pitch(.init(
                    result: result,
                    pitcherID: pitcherID,
                    opponentBatterSlot: 1
                ))
            )
        }
        records.forEach(context.insert)
        try context.save()

        let session = try GameEventCorrection.prepareDefensivePitchDeletion(
            recordID: records[1].id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensivePitchDeletion(
            session,
            game: game,
            modelContext: context
        )
        let corrected = try GameEventCorrection.saveDefensivePitchDeletion(
            preview,
            game: game,
            modelContext: context
        )

        try GameEventRecorder.recordPitch(
            result: .calledStrike,
            game: game,
            existingRecords: corrected.records,
            modelContext: context
        )

        let reloaded = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(reloaded.records.map(\.sequenceNumber) == [1, 4, 5])
        #expect(reloaded.replay.rejectedRecordIDs.isEmpty)
        #expect(reloaded.replay.state.balls == 1)
        #expect(reloaded.replay.state.strikes == 2)
    }

    @Test func defensivePitchDeletionSurvivesColdStoreReload() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "softball-scoring-pitch-deletion-reload-\(UUID().uuidString).store")
        let gameID = UUID()
        let pitcherID = UUID()

        do {
            let container = try AppModelContainer.make(storeURL: storeURL)
            let context = container.mainContext
            let game = Game(
                id: gameID,
                seasonID: UUID(),
                opponentName: "Thunder",
                homeAway: .home,
                status: .inProgress,
                startingPitcherID: pitcherID
            )
            context.insert(game)
            let bodies: [GameEventBody] = [
                .pitch(.init(result: .ball, pitcherID: pitcherID, opponentBatterSlot: 1)),
                .pitch(.init(result: .calledStrike, pitcherID: pitcherID, opponentBatterSlot: 1)),
                .pitch(.init(result: .swingingStrike, pitcherID: pitcherID, opponentBatterSlot: 1)),
                .pitch(.init(result: .calledStrike, pitcherID: pitcherID, opponentBatterSlot: 1)),
                .pitch(.init(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 2)),
                .ballInPlay(.init(
                    outcome: .single,
                    opponentBatterSlot: 2,
                    movements: [.init(source: .batter, destination: .first)],
                    rbi: 0,
                    thirdOutRunsCounted: nil
                )),
                .pitch(.init(result: .ball, pitcherID: pitcherID, opponentBatterSlot: 3))
            ]
            let records = try bodies.enumerated().map { index, body in
                try GameEventRecord(
                    gameID: gameID,
                    sequenceNumber: index + 1,
                    body: body
                )
            }
            records.forEach(context.insert)
            try context.save()
            let session = try GameEventCorrection.prepareDefensivePitchDeletion(
                recordID: records[0].id,
                game: game,
                modelContext: context
            )
            let preview = try GameEventCorrection.stageDefensivePitchDeletion(
                session,
                game: game,
                modelContext: context
            )
            _ = try GameEventCorrection.saveDefensivePitchDeletion(
                preview,
                game: game,
                modelContext: context
            )
        }

        let reloadedContainer = try AppModelContainer.make(storeURL: storeURL)
        let reloadedContext = ModelContext(reloadedContainer)
        let reloadedGame = try #require(reloadedContext.fetch(FetchDescriptor<Game>()).first)
        let reloaded = try LiveGameSnapshotLoader.load(
            game: reloadedGame,
            modelContext: reloadedContext
        )

        #expect(reloaded.records.map(\.sequenceNumber) == [2, 3, 4, 5, 6, 7])
        #expect(reloaded.replay.rejectedRecordIDs.isEmpty)
        #expect(reloaded.replay.state.inning == 1)
        #expect(reloaded.replay.state.half == .top)
        #expect(reloaded.replay.state.outs == 1)
        #expect(reloaded.replay.state.currentOpponentBatterSlot == 3)
        #expect(reloaded.replay.state.firstBaseRunnerSlot == 2)
        #expect(reloaded.replay.state.balls == 1)
        #expect(reloaded.replay.state.strikes == 0)
        #expect(reloaded.replay.state.pitchCount(for: pitcherID) == PitchCount(
            total: 5,
            balls: 1,
            strikes: 4
        ))
        #expect(reloaded.history.sections.flatMap(\.entries).count == 3)
    }

    @Test func stagedDefensivePitchEditReplaysBeforeSavingAndPreservesRecordIdentity() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let originalTimestamp = Date(timeIntervalSince1970: 1_786_600_000)
        let original = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            timestamp: originalTimestamp,
            body: .pitch(.init(
                result: .ball,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        let later = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .pitch(.init(
                result: .calledStrike,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        context.insert(original)
        context.insert(later)
        try context.save()

        let session = try GameEventCorrection.prepareDefensivePitchEdit(
            recordID: original.id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensivePitchEdit(
            .swingingStrike,
            in: session,
            game: game,
            modelContext: context
        )

        #expect(session.inning == 1)
        #expect(session.half == .top)
        #expect(session.opponentBatterSlot == 1)
        #expect(session.originalResult == .ball)
        #expect(session.stateBefore.balls == 0)
        #expect(session.stateBefore.strikes == 0)
        #expect(session.originalStateAfter.balls == 1)
        #expect(preview.proposedResult == .swingingStrike)
        #expect(preview.canSave)
        #expect(preview.firstInvalidRecord == nil)
        #expect(preview.snapshot.replay.state.balls == 0)
        #expect(preview.snapshot.replay.state.strikes == 2)
        #expect(preview.snapshot.replay.state.pitchCount(for: pitcherID) == PitchCount(
            total: 2,
            balls: 0,
            strikes: 2
        ))

        let stagedStored = try context.fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(try stagedStored[0].decoded().body == .pitch(.init(
            result: .ball,
            pitcherID: pitcherID,
            opponentBatterSlot: 1
        )))

        let saved = try GameEventCorrection.saveDefensivePitchEdit(
            preview,
            game: game,
            modelContext: context
        )

        #expect(saved.records.map(\.id) == [original.id, later.id])
        #expect(saved.records.map(\.sequenceNumber) == [1, 2])
        #expect(saved.records[0].gameID == game.id)
        #expect(saved.records[0].timestamp == originalTimestamp)
        #expect(try saved.records[0].decoded().body == .pitch(.init(
            result: .swingingStrike,
            pitcherID: pitcherID,
            opponentBatterSlot: 1
        )))

        let freshContext = ModelContext(container)
        let persisted = try freshContext.fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(persisted.map(\.id) == [original.id, later.id])
        #expect(persisted[0].timestamp == originalTimestamp)
        #expect(try persisted[0].decoded().body == .pitch(.init(
            result: .swingingStrike,
            pitcherID: pitcherID,
            opponentBatterSlot: 1
        )))
    }

    @Test(arguments: defensivePitchEditScenarios)
    fileprivate func defensivePitchEditSavesEverySupportedReplacementAtCountBoundaries(
        _ scenario: DefensivePitchEditScenario
    ) throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let results = scenario.precedingResults + [scenario.originalResult]
        let records = try results.enumerated().map { index, result in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                body: .pitch(.init(
                    result: result,
                    pitcherID: pitcherID,
                    opponentBatterSlot: 1
                ))
            )
        }
        records.forEach(context.insert)
        try context.save()

        let selectedRecord = try #require(records.last)
        let session = try GameEventCorrection.prepareDefensivePitchEdit(
            recordID: selectedRecord.id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensivePitchEdit(
            scenario.proposedResult,
            in: session,
            game: game,
            modelContext: context
        )
        let saved = try GameEventCorrection.saveDefensivePitchEdit(
            preview,
            game: game,
            modelContext: context
        )

        #expect(preview.canSave)
        #expect(saved.replay.rejectedRecordIDs.isEmpty)
        #expect(saved.replay.state.balls == scenario.expectedBalls)
        #expect(saved.replay.state.strikes == scenario.expectedStrikes)
        #expect(saved.replay.state.currentOpponentBatterSlot == scenario.expectedBatterSlot)
        #expect(saved.replay.state.outs == scenario.expectedOuts)
        #expect(try saved.records.last?.decoded().body == .pitch(.init(
            result: scenario.proposedResult,
            pitcherID: pitcherID,
            opponentBatterSlot: 1
        )))
    }

    @Test func recordingAfterPitchEditUsesCorrectedMainContextAndNextSequence() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let records = try [PitchResult.ball, .calledStrike].enumerated().map { index, result in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                body: .pitch(.init(
                    result: result,
                    pitcherID: pitcherID,
                    opponentBatterSlot: 1
                ))
            )
        }
        records.forEach(context.insert)
        try context.save()
        let session = try GameEventCorrection.prepareDefensivePitchEdit(
            recordID: records[0].id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensivePitchEdit(
            .swingingStrike,
            in: session,
            game: game,
            modelContext: context
        )
        let corrected = try GameEventCorrection.saveDefensivePitchEdit(
            preview,
            game: game,
            modelContext: context
        )

        try GameEventRecorder.recordPitch(
            result: .calledStrike,
            game: game,
            existingRecords: corrected.records,
            modelContext: context
        )

        let freshSnapshot = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(freshSnapshot.records.map(\.sequenceNumber) == [1, 2, 3])
        #expect(freshSnapshot.replay.rejectedRecordIDs.isEmpty)
        #expect(freshSnapshot.replay.state.outs == 1)
        #expect(freshSnapshot.replay.state.currentOpponentBatterSlot == 2)
        #expect(freshSnapshot.replay.state.balls == 0)
        #expect(freshSnapshot.replay.state.strikes == 0)
    }

    @Test func pitchEditPerformsNoThrowableProjectionAfterCommit() throws {
        struct UnexpectedSecondProjection: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let original = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ball,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        context.insert(original)
        try context.save()
        let session = try GameEventCorrection.prepareDefensivePitchEdit(
            recordID: original.id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensivePitchEdit(
            .calledStrike,
            in: session,
            game: game,
            modelContext: context
        )
        var projectionCalls = 0

        _ = try GameEventCorrection.saveDefensivePitchEdit(
            preview,
            game: game,
            modelContext: context,
            projectBattingLines: { events in
                projectionCalls += 1
                guard projectionCalls == 1 else { throw UnexpectedSecondProjection() }
                return try BattingStatProjector.project(events: events)
            }
        )

        #expect(projectionCalls == 1)
        let persisted = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
        #expect(try persisted.first?.decoded().body == .pitch(.init(
            result: .calledStrike,
            pitcherID: pitcherID,
            opponentBatterSlot: 1
        )))
    }

    @Test func defensivePitchEditSurvivesColdStoreReloadWithDerivedStateAndHistory() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "softball-scoring-pitch-edit-reload-\(UUID().uuidString).store")
        let gameID = UUID()
        let pitcherID = UUID()
        let editedRecordID = UUID()
        let editedTimestamp = Date(timeIntervalSince1970: 1_786_600_100)

        do {
            let container = try AppModelContainer.make(storeURL: storeURL)
            let context = container.mainContext
            let game = Game(
                id: gameID,
                seasonID: UUID(),
                opponentName: "Thunder",
                homeAway: .home,
                status: .inProgress,
                startingPitcherID: pitcherID
            )
            context.insert(game)
            context.insert(try GameEventRecord(
                id: editedRecordID,
                gameID: gameID,
                sequenceNumber: 1,
                timestamp: editedTimestamp,
                body: .pitch(.init(
                    result: .ball,
                    pitcherID: pitcherID,
                    opponentBatterSlot: 1
                ))
            ))
            context.insert(try GameEventRecord(
                gameID: gameID,
                sequenceNumber: 2,
                body: .pitch(.init(
                    result: .calledStrike,
                    pitcherID: pitcherID,
                    opponentBatterSlot: 1
                ))
            ))
            try context.save()

            let session = try GameEventCorrection.prepareDefensivePitchEdit(
                recordID: editedRecordID,
                game: game,
                modelContext: context
            )
            let preview = try GameEventCorrection.stageDefensivePitchEdit(
                .swingingStrike,
                in: session,
                game: game,
                modelContext: context
            )
            _ = try GameEventCorrection.saveDefensivePitchEdit(
                preview,
                game: game,
                modelContext: context
            )
        }

        let reloadedContainer = try AppModelContainer.make(storeURL: storeURL)
        let reloadedContext = ModelContext(reloadedContainer)
        let reloadedGame = try #require(reloadedContext.fetch(FetchDescriptor<Game>()).first)
        let reloaded = try LiveGameSnapshotLoader.load(
            game: reloadedGame,
            modelContext: reloadedContext
        )

        #expect(reloaded.replay.state.balls == 0)
        #expect(reloaded.replay.state.strikes == 2)
        #expect(reloaded.replay.state.pitchCount(for: pitcherID) == PitchCount(
            total: 2,
            balls: 0,
            strikes: 2
        ))
        #expect(reloaded.records.map(\.sequenceNumber) == [1, 2])
        #expect(reloaded.records[0].id == editedRecordID)
        #expect(reloaded.records[0].gameID == gameID)
        #expect(reloaded.records[0].timestamp == editedTimestamp)
        #expect(try reloaded.records[0].decoded().body == .pitch(.init(
            result: .swingingStrike,
            pitcherID: pitcherID,
            opponentBatterSlot: 1
        )))
        #expect(reloaded.history.sections[0].entries[0].components.map(\.summary) == [
            "Swinging Strike", "Called Strike"
        ])
    }

    @Test func invalidDownstreamPitchDisablesSaveAndLeavesDurableTimelineUntouched() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let results: [PitchResult] = [.calledStrike, .swingingStrike, .foul, .calledStrike]
        let records = try results.enumerated().map { index, result in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                body: .pitch(.init(
                    result: result,
                    pitcherID: pitcherID,
                    opponentBatterSlot: 1
                ))
            )
        }
        records.forEach(context.insert)
        try context.save()
        let originalRevisions = try records.map { try $0.decoded() }

        let session = try GameEventCorrection.prepareDefensivePitchEdit(
            recordID: records[2].id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensivePitchEdit(
            .calledStrike,
            in: session,
            game: game,
            modelContext: context
        )

        #expect(!preview.canSave)
        #expect(preview.firstInvalidRecord == DefensivePitchCorrectionInvalidRecord(
            id: records[3].id,
            sequenceNumber: 4,
            summary: "Play conflicts with the proposed pitch"
        ))
        #expect(preview.snapshot.replay.rejectedRecordIDs == [records[3].id])
        #expect(throws: GameEventCorrectionError.invalidCandidate) {
            _ = try GameEventCorrection.saveDefensivePitchEdit(
                preview,
                game: game,
                modelContext: context
            )
        }

        let stored = try context.fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stored.map(\.id) == records.map(\.id))
        #expect(try stored.map { try $0.decoded() } == originalRevisions)
    }

    @Test func completedDefensiveBallInPlayCanBeCorrectedWithoutReplacingItsCountedPitch() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let pitchTimestamp = Date(timeIntervalSince1970: 1_786_800_000)
        let resultTimestamp = Date(timeIntervalSince1970: 1_786_800_010)
        let pitch = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            timestamp: pitchTimestamp,
            body: .pitch(.init(
                result: .ballInPlay,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        let result = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            timestamp: resultTimestamp,
            body: .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        )
        context.insert(pitch)
        context.insert(result)
        try context.save()

        let edit = try GameEventCorrection.prepareDefensiveBallInPlayEdit(
            recordID: result.id,
            game: game,
            modelContext: context
        )
        let proposedPlay = BallInPlayEvent(
            outcome: .reachedOnError,
            opponentBatterSlot: 1,
            movements: [.init(source: .batter, destination: .first)],
            rbi: 0,
            thirdOutRunsCounted: nil
        )
        let preview = try GameEventCorrection.stageDefensiveBallInPlayEdit(
            proposedPlay,
            in: edit,
            game: game,
            modelContext: context
        )

        #expect(edit.precedingPitchSequenceNumber == 1)
        #expect(edit.originalPlay.outcome == .single)
        #expect(preview.canSave)
        #expect(preview.snapshot.replay.state.firstBaseRunnerSlot == 1)
        #expect(preview.snapshot.replay.state.currentOpponentBatterSlot == 2)
        #expect(preview.snapshot.replay.state.pitchCount(for: pitcherID) == PitchCount(
            total: 1,
            balls: 0,
            strikes: 1
        ))

        _ = try GameEventCorrection.saveDefensiveBallInPlayEdit(
            preview,
            game: game,
            modelContext: context
        )

        let reloaded = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(reloaded.records.map(\.id) == [pitch.id, result.id])
        #expect(reloaded.records.map(\.sequenceNumber) == [1, 2])
        #expect(reloaded.records.map(\.timestamp) == [pitchTimestamp, resultTimestamp])
        #expect(try reloaded.records[0].decoded().body == .pitch(.init(
            result: .ballInPlay,
            pitcherID: pitcherID,
            opponentBatterSlot: 1
        )))
        #expect(try reloaded.records[1].decoded().body == .ballInPlay(proposedPlay))
        #expect(reloaded.history.sections[0].entries[0].summary == "E · Batter to 1B")
    }

    @Test(arguments: defensiveBallInPlayCorrectionScenarios)
    fileprivate func representativeNonScoringDefensiveBallInPlayCorrectionsReplay(
        _ scenario: DefensiveBallInPlayCorrectionScenario
    ) throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        var records: [GameEventRecord] = []

        if scenario.startsWithRunnerOnFirst {
            records.append(try GameEventRecord(
                gameID: game.id,
                sequenceNumber: 1,
                body: .pitch(.init(
                    result: .ballInPlay,
                    pitcherID: pitcherID,
                    opponentBatterSlot: 1
                ))
            ))
            records.append(try GameEventRecord(
                gameID: game.id,
                sequenceNumber: 2,
                body: .ballInPlay(.init(
                    outcome: .single,
                    opponentBatterSlot: 1,
                    movements: [.init(source: .batter, destination: .first)],
                    rbi: 0,
                    thirdOutRunsCounted: nil
                ))
            ))
        }

        let batterSlot = scenario.startsWithRunnerOnFirst ? 2 : 1
        let pitchSequence = records.count + 1
        let resultSequence = pitchSequence + 1
        let originalMovements: [RunnerMovementEvent] = scenario.startsWithRunnerOnFirst
            ? [
                .init(source: .batter, destination: .first),
                .init(source: .first, destination: .second)
            ]
            : [.init(source: .batter, destination: .first)]
        records.append(try GameEventRecord(
            gameID: game.id,
            sequenceNumber: pitchSequence,
            body: .pitch(.init(
                result: .ballInPlay,
                pitcherID: pitcherID,
                opponentBatterSlot: batterSlot
            ))
        ))
        let result = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: resultSequence,
            body: .ballInPlay(.init(
                outcome: .reachedOnError,
                opponentBatterSlot: batterSlot,
                movements: originalMovements,
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        )
        records.append(result)
        records.forEach(context.insert)
        try context.save()

        let edit = try GameEventCorrection.prepareDefensiveBallInPlayEdit(
            recordID: result.id,
            game: game,
            modelContext: context
        )
        let proposedPlay = BallInPlayEvent(
            outcome: scenario.outcome,
            opponentBatterSlot: batterSlot,
            movements: scenario.movements,
            rbi: 0,
            thirdOutRunsCounted: nil
        )
        let preview = try GameEventCorrection.stageDefensiveBallInPlayEdit(
            proposedPlay,
            in: edit,
            game: game,
            modelContext: context
        )
        #expect(preview.canSave)

        _ = try GameEventCorrection.saveDefensiveBallInPlayEdit(
            preview,
            game: game,
            modelContext: context
        )
        let reloaded = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )

        #expect(reloaded.replay.rejectedRecordIDs.isEmpty)
        #expect(reloaded.replay.state.outs == scenario.expectedOuts)
        #expect(reloaded.replay.state.baseRunnerSlots == scenario.expectedBases)
        #expect(reloaded.replay.state.currentOpponentBatterSlot == batterSlot + 1)
        #expect(reloaded.replay.state.pitchCount(for: pitcherID).total == (scenario.startsWithRunnerOnFirst ? 2 : 1))
        #expect(try reloaded.records.last?.decoded().body == .ballInPlay(proposedPlay))
    }

    @Test func defensiveDoublePlayCorrectionRecordsTwoExplicitOuts() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let originalPlay = BallInPlayEvent(
            outcome: .reachedOnError,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .first),
                .init(source: .first, destination: .second)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        )
        let records = try defensiveBallInPlayRecords(
            for: [
                .init(
                    outcome: .single,
                    opponentBatterSlot: 1,
                    movements: [.init(source: .batter, destination: .first)],
                    rbi: 0,
                    thirdOutRunsCounted: nil
                ),
                originalPlay
            ],
            gameID: game.id,
            pitcherID: pitcherID
        )
        records.forEach(context.insert)
        try context.save()

        let target = try #require(records.last)
        let edit = try GameEventCorrection.prepareDefensiveBallInPlayEdit(
            recordID: target.id,
            game: game,
            modelContext: context
        )
        let doublePlay = BallInPlayEvent(
            outcome: .doublePlay,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .out),
                .init(source: .first, destination: .out)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        )
        let preview = try GameEventCorrection.stageDefensiveBallInPlayEdit(
            doublePlay,
            in: edit,
            game: game,
            modelContext: context
        )

        #expect(preview.canSave)
        #expect(preview.snapshot.replay.rejectedRecordIDs.isEmpty)
        #expect(preview.snapshot.replay.state.outs == 2)
        #expect(preview.snapshot.replay.state.baseRunnerSlots == [nil, nil, nil])
        #expect(preview.snapshot.replay.state.currentOpponentBatterSlot == 3)
        #expect(preview.snapshot.replay.state.pitchCount(for: pitcherID).total == 2)

        _ = try GameEventCorrection.saveDefensiveBallInPlayEdit(
            preview,
            game: game,
            modelContext: context
        )
        let reloaded = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )

        #expect(reloaded.replay.state == preview.snapshot.replay.state)
        #expect(reloaded.records.map(\.id) == records.map(\.id))
        #expect(try reloaded.records.last?.decoded().body == .ballInPlay(doublePlay))
    }

    @Test func thirdOutCorrectionRecalculatesForceAndTimingRunsBeforeInningTransition() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let forceThirdOut = BallInPlayEvent(
            outcome: .doublePlay,
            opponentBatterSlot: 4,
            movements: [
                .init(source: .batter, destination: .out),
                .init(source: .first, destination: .out),
                .init(source: .third, destination: .home)
            ],
            rbi: 0,
            thirdOutRunsCounted: 0,
            thirdOutClassification: .forceOrBatterRunner
        )
        let records = try defensiveBallInPlayRecords(
            for: [
                .init(
                    outcome: .triple,
                    opponentBatterSlot: 1,
                    movements: [.init(source: .batter, destination: .third)],
                    rbi: 0,
                    thirdOutRunsCounted: nil
                ),
                .init(
                    outcome: .single,
                    opponentBatterSlot: 2,
                    movements: [
                        .init(source: .batter, destination: .first),
                        .init(source: .third, destination: .third)
                    ],
                    rbi: 0,
                    thirdOutRunsCounted: nil
                ),
                .init(
                    outcome: .flyOut,
                    opponentBatterSlot: 3,
                    movements: [
                        .init(source: .batter, destination: .out),
                        .init(source: .first, destination: .first),
                        .init(source: .third, destination: .third)
                    ],
                    rbi: 0,
                    thirdOutRunsCounted: nil
                ),
                forceThirdOut
            ],
            gameID: game.id,
            pitcherID: pitcherID
        )
        records.forEach(context.insert)
        try context.save()

        let original = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(original.replay.state.awayScore == 0)
        #expect(original.replay.state.half == .bottom)
        #expect(original.replay.state.currentOpponentBatterSlot == 5)

        let target = try #require(records.last)
        let edit = try GameEventCorrection.prepareDefensiveBallInPlayEdit(
            recordID: target.id,
            game: game,
            modelContext: context
        )
        let timingThirdOut = BallInPlayEvent(
            outcome: .doublePlay,
            opponentBatterSlot: 4,
            movements: forceThirdOut.movements,
            rbi: 1,
            thirdOutRunsCounted: 1,
            thirdOutClassification: .timingPlay
        )
        let preview = try GameEventCorrection.stageDefensiveBallInPlayEdit(
            timingThirdOut,
            in: edit,
            game: game,
            modelContext: context
        )

        #expect(preview.canSave)
        #expect(preview.snapshot.replay.rejectedRecordIDs.isEmpty)
        #expect(preview.snapshot.replay.state.awayScore == 1)
        #expect(preview.snapshot.replay.state.half == .bottom)
        #expect(preview.snapshot.replay.state.outs == 0)
        #expect(preview.snapshot.replay.state.balls == 0)
        #expect(preview.snapshot.replay.state.strikes == 0)
        #expect(preview.snapshot.replay.state.baseRunnerSlots == [nil, nil, nil])
        #expect(preview.snapshot.replay.state.currentOpponentBatterSlot == 5)
        #expect(preview.snapshot.replay.state.currentTrackedBatterSlot == 1)
        #expect(preview.snapshot.replay.state.pitchCount(for: pitcherID).total == 4)

        let invalidThirdOuts = [
            BallInPlayEvent(
                outcome: .doublePlay,
                opponentBatterSlot: 4,
                movements: forceThirdOut.movements,
                rbi: 0,
                thirdOutRunsCounted: nil
            ),
            BallInPlayEvent(
                outcome: .doublePlay,
                opponentBatterSlot: 4,
                movements: forceThirdOut.movements,
                rbi: 1,
                thirdOutRunsCounted: 1,
                thirdOutClassification: .forceOrBatterRunner
            ),
            BallInPlayEvent(
                outcome: .doublePlay,
                opponentBatterSlot: 4,
                movements: [
                    .init(source: .batter, destination: .out),
                    .init(source: .first, destination: .out),
                    .init(source: .third, destination: .out)
                ],
                rbi: 0,
                thirdOutRunsCounted: nil
            )
        ]
        for invalidThirdOut in invalidThirdOuts {
            #expect(throws: GameEventCorrectionError.ballInPlayNotEditable) {
                _ = try GameEventCorrection.stageDefensiveBallInPlayEdit(
                    invalidThirdOut,
                    in: edit,
                    game: game,
                    modelContext: context
                )
            }
        }

        let unchanged = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(unchanged.replay.state.awayScore == 0)
        #expect(try unchanged.records.last?.decoded().body == .ballInPlay(forceThirdOut))

        _ = try GameEventCorrection.saveDefensiveBallInPlayEdit(
            preview,
            game: game,
            modelContext: context
        )
        let reloaded = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )

        #expect(reloaded.replay.state == preview.snapshot.replay.state)
        #expect(reloaded.records.map(\.id) == records.map(\.id))
        #expect(try reloaded.records.last?.decoded().body == .ballInPlay(timingThirdOut))
    }

    @Test(arguments: defensiveScoringCorrectionScenarios)
    fileprivate func representativeDefensiveScoringCorrectionsReplay(
        _ scenario: DefensiveScoringCorrectionScenario
    ) throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let allPlays = scenario.setupPlays + [scenario.originalPlay]
        let records = try defensiveBallInPlayRecords(
            for: allPlays,
            gameID: game.id,
            pitcherID: pitcherID
        )
        records.forEach(context.insert)
        try context.save()

        let target = try #require(records.last)
        let edit = try GameEventCorrection.prepareDefensiveBallInPlayEdit(
            recordID: target.id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensiveBallInPlayEdit(
            scenario.proposedPlay,
            in: edit,
            game: game,
            modelContext: context
        )

        #expect(preview.canSave, "\(scenario.name) should replay cleanly")
        #expect(preview.snapshot.replay.rejectedRecordIDs.isEmpty)
        #expect(preview.snapshot.replay.state.awayScore == scenario.expectedScore)
        #expect(preview.snapshot.replay.state.outs == scenario.expectedOuts)
        #expect(preview.snapshot.replay.state.baseRunnerSlots == scenario.expectedBases)
        #expect(preview.snapshot.replay.state.currentOpponentBatterSlot == allPlays.count + 1)
        #expect(preview.snapshot.replay.state.pitchCount(for: pitcherID).total == allPlays.count)

        _ = try GameEventCorrection.saveDefensiveBallInPlayEdit(
            preview,
            game: game,
            modelContext: context
        )
        let reloaded = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )

        #expect(reloaded.replay.rejectedRecordIDs.isEmpty)
        #expect(reloaded.replay.state.awayScore == scenario.expectedScore)
        #expect(reloaded.replay.state.outs == scenario.expectedOuts)
        #expect(reloaded.replay.state.baseRunnerSlots == scenario.expectedBases)
        #expect(reloaded.replay.state.currentOpponentBatterSlot == allPlays.count + 1)
        #expect(reloaded.replay.state.pitchCount(for: pitcherID).total == allPlays.count)
        #expect(try reloaded.records.last?.decoded().body == .ballInPlay(scenario.proposedPlay))
    }

    @Test(arguments: scoringDestinationRemovalScenarios)
    fileprivate func changingHomeDestinationAndRBIRemovesTheReplayedRun(
        _ removal: ScoringDestinationRemovalScenario
    ) throws {
        let scenario = try #require(defensiveScoringCorrectionScenarios.first {
            $0.name == "extra-base hit"
        })
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let plays = scenario.setupPlays + [scenario.proposedPlay]
        let records = try defensiveBallInPlayRecords(
            for: plays,
            gameID: game.id,
            pitcherID: pitcherID
        )
        records.forEach(context.insert)
        try context.save()
        let target = try #require(records.last)

        let edit = try GameEventCorrection.prepareDefensiveBallInPlayEdit(
            recordID: target.id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensiveBallInPlayEdit(
            removal.replacement,
            in: edit,
            game: game,
            modelContext: context
        )
        #expect(preview.canSave)
        #expect(preview.snapshot.replay.state.awayScore == 0)
        #expect(preview.snapshot.replay.state.outs == removal.expectedOuts)
        #expect(preview.snapshot.replay.state.baseRunnerSlots == removal.expectedBases)
        #expect(preview.snapshot.history.sections.last?.entries.last?.summary.contains("RBI") == false)

        _ = try GameEventCorrection.saveDefensiveBallInPlayEdit(
            preview,
            game: game,
            modelContext: context
        )
        let reloaded = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )

        #expect(reloaded.replay.state.awayScore == 0)
        #expect(reloaded.replay.state.outs == removal.expectedOuts)
        #expect(reloaded.replay.state.baseRunnerSlots == removal.expectedBases)
        #expect(try reloaded.records.last?.decoded().body == .ballInPlay(removal.replacement))
    }

    @Test func survivingDownstreamPitchesReplayAfterScoringCorrection() throws {
        let scenario = try #require(defensiveScoringCorrectionScenarios.first {
            $0.name == "extra-base hit"
        })
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let completedPlays = scenario.setupPlays + [scenario.originalPlay]
        var records = try defensiveBallInPlayRecords(
            for: completedPlays,
            gameID: game.id,
            pitcherID: pitcherID
        )
        let target = try #require(records.last)
        records.append(try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 5,
            body: .pitch(.init(result: .ball, pitcherID: pitcherID, opponentBatterSlot: 3))
        ))
        records.append(try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 6,
            body: .pitch(.init(result: .calledStrike, pitcherID: pitcherID, opponentBatterSlot: 3))
        ))
        records.forEach(context.insert)
        try context.save()

        let edit = try GameEventCorrection.prepareDefensiveBallInPlayEdit(
            recordID: target.id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensiveBallInPlayEdit(
            scenario.proposedPlay,
            in: edit,
            game: game,
            modelContext: context
        )

        #expect(preview.canSave)
        #expect(preview.snapshot.replay.rejectedRecordIDs.isEmpty)
        #expect(preview.snapshot.replay.state.awayScore == 1)
        #expect(preview.snapshot.replay.state.baseRunnerSlots == [nil, 2, nil])
        #expect(preview.snapshot.replay.state.balls == 1)
        #expect(preview.snapshot.replay.state.strikes == 1)
        #expect(preview.snapshot.replay.state.currentOpponentBatterSlot == 3)
        #expect(preview.snapshot.replay.state.pitchCount(for: pitcherID).total == 4)

        _ = try GameEventCorrection.saveDefensiveBallInPlayEdit(
            preview,
            game: game,
            modelContext: context
        )
        let reloaded = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )

        #expect(reloaded.records.map(\.id) == records.map(\.id))
        #expect(reloaded.replay.state == preview.snapshot.replay.state)
        #expect(try reloaded.records[4].decoded().body == .pitch(.init(
            result: .ball,
            pitcherID: pitcherID,
            opponentBatterSlot: 3
        )))
        #expect(try reloaded.records[5].decoded().body == .pitch(.init(
            result: .calledStrike,
            pitcherID: pitcherID,
            opponentBatterSlot: 3
        )))
    }

    @Test func invalidDefensiveBallInPlayCorrectionInputsLeaveCompletedPlayUntouched() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let pitch = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ballInPlay,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        let originalPlay = BallInPlayEvent(
            outcome: .single,
            opponentBatterSlot: 1,
            movements: [.init(source: .batter, destination: .first)],
            rbi: 0,
            thirdOutRunsCounted: nil
        )
        let result = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .ballInPlay(originalPlay)
        )
        context.insert(pitch)
        context.insert(result)
        try context.save()
        let edit = try GameEventCorrection.prepareDefensiveBallInPlayEdit(
            recordID: result.id,
            game: game,
            modelContext: context
        )
        let invalidPlays = [
            BallInPlayEvent(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [],
                rbi: 0,
                thirdOutRunsCounted: nil
            ),
            BallInPlayEvent(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [
                    .init(source: .batter, destination: .first),
                    .init(source: .batter, destination: .second)
                ],
                rbi: 0,
                thirdOutRunsCounted: nil
            ),
            BallInPlayEvent(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [
                    .init(source: .batter, destination: .first),
                    .init(source: .first, destination: .second)
                ],
                rbi: 0,
                thirdOutRunsCounted: nil
            ),
            BallInPlayEvent(
                outcome: .groundOut,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ),
            BallInPlayEvent(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .home)],
                rbi: 2,
                thirdOutRunsCounted: nil
            )
        ]

        for invalidPlay in invalidPlays {
            #expect(throws: GameEventCorrectionError.ballInPlayNotEditable) {
                _ = try GameEventCorrection.stageDefensiveBallInPlayEdit(
                    invalidPlay,
                    in: edit,
                    game: game,
                    modelContext: context
                )
            }
        }

        let stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stored.map(\.id) == [pitch.id, result.id])
        #expect(try stored.last?.decoded().body == .ballInPlay(originalPlay))
    }

    @Test func invalidDownstreamPlayCanBeRepairedAndSavedInTheSameCorrection() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let bodies = twoConsecutiveSingles(pitcherID: pitcherID)
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                body: body
            )
        }
        records.forEach(context.insert)
        try context.save()
        let edit = try GameEventCorrection.prepareDefensiveBallInPlayEdit(
            recordID: records[1].id,
            game: game,
            modelContext: context
        )
        let groundOut = BallInPlayEvent(
            outcome: .groundOut,
            opponentBatterSlot: 1,
            movements: [.init(source: .batter, destination: .out)],
            rbi: 0,
            thirdOutRunsCounted: nil
        )

        let preview = try GameEventCorrection.stageDefensiveBallInPlayEdit(
            groundOut,
            in: edit,
            game: game,
            modelContext: context
        )

        let staged = try #require(preview.correctionSession)
        #expect(!staged.canSave)
        #expect(staged.firstInvalidRecord?.id == records[3].id)
        #expect(staged.firstInvalidRecord?.sequenceNumber == 4)
        #expect(staged.firstInvalidRecord?.context == "Top 1 · Opponent batter 2 · Single")
        #expect(staged.snapshot.replay.rejectedRecordIDs == [records[3].id])

        let repaired = try GameEventCorrection.stageBallInPlayEdit(
            recordID: records[3].id,
            play: .init(
                outcome: .single,
                opponentBatterSlot: 2,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ),
            in: staged,
            game: game,
            modelContext: context
        )
        #expect(repaired.canSave)
        #expect(repaired.firstInvalidRecord == nil)
        #expect(repaired.snapshot.replay.rejectedRecordIDs.isEmpty)
        #expect(repaired.stagedBallInPlayChanges.map(\.recordID) == [records[1].id, records[3].id])

        _ = try GameEventCorrection.saveGameEventCorrection(
            repaired,
            game: game,
            modelContext: context
        )

        let stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stored.map(\.id) == records.map(\.id))
        #expect(try stored[0].decoded().body == bodies[0])
        #expect(try stored[1].decoded().body == .ballInPlay(groundOut))
        #expect(try stored[2].decoded().body == bodies[2])
        #expect(try stored[3].decoded().body == .ballInPlay(.init(
            outcome: .single,
            opponentBatterSlot: 2,
            movements: [.init(source: .batter, destination: .first)],
            rbi: 0,
            thirdOutRunsCounted: nil
        )))
    }

    @Test func scoringDownstreamPlayCanBeRepairedInTheSameCorrection() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let bodies: [GameEventBody] = [
            .pitch(.init(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 1)),
            .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            )),
            .pitch(.init(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 2)),
            .ballInPlay(.init(
                outcome: .double,
                opponentBatterSlot: 2,
                movements: [
                    .init(source: .first, destination: .home),
                    .init(source: .batter, destination: .second)
                ],
                rbi: 1,
                thirdOutRunsCounted: nil
            ))
        ]
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let edit = try GameEventCorrection.prepareDefensiveBallInPlayEdit(
            recordID: records[1].id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensiveBallInPlayEdit(
            .init(
                outcome: .groundOut,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .out)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ),
            in: edit,
            game: game,
            modelContext: context
        )
        let staged = try #require(preview.correctionSession)
        #expect(staged.firstInvalidRecord?.id == records[3].id)
        #expect(staged.firstInvalidRecord?.canEditBallInPlay == true)

        let homeRun = BallInPlayEvent(
            outcome: .homeRun,
            opponentBatterSlot: 2,
            movements: [.init(source: .batter, destination: .home)],
            rbi: 1,
            thirdOutRunsCounted: nil
        )
        let repaired = try GameEventCorrection.stageBallInPlayEdit(
            recordID: records[3].id,
            play: homeRun,
            in: staged,
            game: game,
            modelContext: context
        )
        #expect(repaired.canSave)
        #expect(repaired.firstInvalidRecord == nil)
        #expect(repaired.snapshot.replay.state.awayScore == 1)
        #expect(repaired.snapshot.replay.state.outs == 1)
        #expect(repaired.snapshot.replay.state.baseRunnerSlots == [nil, nil, nil])

        _ = try GameEventCorrection.saveGameEventCorrection(
            repaired,
            game: game,
            modelContext: context
        )

        let stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stored.map(\.id) == records.map(\.id))
        #expect(try stored[1].decoded().body == .ballInPlay(.init(
            outcome: .groundOut,
            opponentBatterSlot: 1,
            movements: [.init(source: .batter, destination: .out)],
            rbi: 0,
            thirdOutRunsCounted: nil
        )))
        #expect(try stored[3].decoded().body == .ballInPlay(homeRun))
    }

    @Test func staleOrFailedBallInPlayCorrectionPreservesOriginalTimeline() throws {
        struct SaveFailure: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let otherGame = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let pitch = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ballInPlay,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        let result = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        )
        context.insert(pitch)
        context.insert(result)
        try context.save()
        let originalResultBody = try result.decoded().body
        let edit = try GameEventCorrection.prepareDefensiveBallInPlayEdit(
            recordID: result.id,
            game: game,
            modelContext: context
        )
        let errorPlay = BallInPlayEvent(
            outcome: .reachedOnError,
            opponentBatterSlot: 1,
            movements: [.init(source: .batter, destination: .first)],
            rbi: 0,
            thirdOutRunsCounted: nil
        )
        #expect(throws: GameEventCorrectionError.gameMismatch) {
            _ = try GameEventCorrection.stageDefensiveBallInPlayEdit(
                errorPlay,
                in: edit,
                game: otherGame,
                modelContext: context
            )
        }
        let preview = try GameEventCorrection.stageDefensiveBallInPlayEdit(
            errorPlay,
            in: edit,
            game: game,
            modelContext: context
        )
        #expect(throws: SaveFailure.self) {
            _ = try GameEventCorrection.saveDefensiveBallInPlayEdit(
                preview,
                game: game,
                modelContext: context,
                save: { _ in throw SaveFailure() }
            )
        }

        var stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(try stored.last?.decoded().body == originalResultBody)

        let newer = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 3,
            body: .pitch(.init(
                result: .ball,
                pitcherID: pitcherID,
                opponentBatterSlot: 2
            ))
        )
        context.insert(newer)
        try context.save()
        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.saveDefensiveBallInPlayEdit(
                preview,
                game: game,
                modelContext: context
            )
        }
        stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stored.map(\.id) == [pitch.id, result.id, newer.id])
        #expect(try stored[1].decoded().body == originalResultBody)
    }

    @Test func correctedDefensiveBallInPlaySurvivesColdStoreReload() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "softball-scoring-play-edit-reload-\(UUID().uuidString).store")
        let gameID = UUID()
        let pitcherID = UUID()
        let pitchID = UUID()
        let resultID = UUID()

        do {
            let container = try AppModelContainer.make(storeURL: storeURL)
            let context = container.mainContext
            let game = Game(
                id: gameID,
                seasonID: UUID(),
                opponentName: "Thunder",
                homeAway: .home,
                status: .inProgress,
                startingPitcherID: pitcherID
            )
            let pitch = try GameEventRecord(
                id: pitchID,
                gameID: gameID,
                sequenceNumber: 1,
                body: .pitch(.init(
                    result: .ballInPlay,
                    pitcherID: pitcherID,
                    opponentBatterSlot: 1
                ))
            )
            let result = try GameEventRecord(
                id: resultID,
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
            context.insert(game)
            context.insert(pitch)
            context.insert(result)
            try context.save()

            let edit = try GameEventCorrection.prepareDefensiveBallInPlayEdit(
                recordID: resultID,
                game: game,
                modelContext: context
            )
            let groundOut = BallInPlayEvent(
                outcome: .groundOut,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .out)],
                rbi: 0,
                thirdOutRunsCounted: nil
            )
            let preview = try GameEventCorrection.stageDefensiveBallInPlayEdit(
                groundOut,
                in: edit,
                game: game,
                modelContext: context
            )
            _ = try GameEventCorrection.saveDefensiveBallInPlayEdit(
                preview,
                game: game,
                modelContext: context
            )
        }

        let reloadedContainer = try AppModelContainer.make(storeURL: storeURL)
        let reloadedContext = ModelContext(reloadedContainer)
        let reloadedGame = try #require(reloadedContext.fetch(FetchDescriptor<Game>()).first)
        let reloaded = try LiveGameSnapshotLoader.load(
            game: reloadedGame,
            modelContext: reloadedContext
        )

        #expect(reloaded.records.map(\.id) == [pitchID, resultID])
        #expect(reloaded.replay.state.outs == 1)
        #expect(reloaded.replay.state.baseRunnerSlots == [nil, nil, nil])
        #expect(reloaded.replay.state.currentOpponentBatterSlot == 2)
        #expect(reloaded.replay.state.pitchCount(for: pitcherID) == PitchCount(
            total: 1,
            balls: 0,
            strikes: 1
        ))
        #expect(reloaded.history.sections[0].entries[0].summary == "GO · Batter to Out · 1 out")
    }

    @Test func rejectedPitchEditInputsAndSaveFailurePreserveEveryOriginalRecord() throws {
        struct ProjectionFailure: Error {}
        struct SaveFailure: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let otherGame = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let original = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ball,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        context.insert(original)
        try context.save()

        let session = try GameEventCorrection.prepareDefensivePitchEdit(
            recordID: original.id,
            game: game,
            modelContext: context
        )
        #expect(throws: GameEventCorrectionError.gameMismatch) {
            _ = try GameEventCorrection.stageDefensivePitchEdit(
                .calledStrike,
                in: session,
                game: otherGame,
                modelContext: context
            )
        }
        #expect(throws: GameEventCorrectionError.pitchNotEditable) {
            _ = try GameEventCorrection.stageDefensivePitchEdit(
                .hitByPitch,
                in: session,
                game: game,
                modelContext: context
            )
        }
        #expect(throws: ProjectionFailure.self) {
            _ = try GameEventCorrection.stageDefensivePitchEdit(
                .calledStrike,
                in: session,
                game: game,
                modelContext: context,
                projectBattingLines: { _ in throw ProjectionFailure() }
            )
        }

        let preview = try GameEventCorrection.stageDefensivePitchEdit(
            .calledStrike,
            in: session,
            game: game,
            modelContext: context
        )
        let forgedUnsupportedPreview = DefensivePitchEditPreview(
            session: session,
            proposedResult: .hitByPitch,
            snapshot: preview.snapshot,
            firstInvalidRecord: nil
        )
        #expect(throws: GameEventCorrectionError.pitchNotEditable) {
            _ = try GameEventCorrection.saveDefensivePitchEdit(
                forgedUnsupportedPreview,
                game: game,
                modelContext: context
            )
        }
        #expect(throws: SaveFailure.self) {
            _ = try GameEventCorrection.saveDefensivePitchEdit(
                preview,
                game: game,
                modelContext: context,
                save: { _ in throw SaveFailure() }
            )
        }
        var stored = try context.fetch(FetchDescriptor<GameEventRecord>())
        #expect(stored.count == 1)
        #expect(try stored[0].decoded().body == .pitch(.init(
            result: .ball,
            pitcherID: pitcherID,
            opponentBatterSlot: 1
        )))

        let newer = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .pitch(.init(
                result: .foul,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        context.insert(newer)
        try context.save()
        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.stageDefensivePitchEdit(
                .calledStrike,
                in: session,
                game: game,
                modelContext: context
            )
        }
        stored = try context.fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stored.map(\.id) == [original.id, newer.id])
        #expect(try stored[0].decoded().body == .pitch(.init(
            result: .ball,
            pitcherID: pitcherID,
            opponentBatterSlot: 1
        )))
    }

    @Test func trackedTeamPitchEditPreservesEventTimeIdentityAndLaterBatterProgression() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let nextBatter = makeTrackedBatter(
            displayName: "Jordan Lee",
            jerseyNumber: "12",
            position: .centerField,
            lineupSlot: 2
        )
        let editedRecordID = UUID()
        let editedTimestamp = Date(timeIntervalSince1970: 1_787_000_000)
        let bodies: [GameEventBody] = [
            .offensivePitch(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .ball
            )),
            .offensivePitch(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .calledStrike
            )),
            .offensivePlateAppearance(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePitch(.init(
                batter: nextBatter,
                battingOrderSize: 10,
                result: .ball
            ))
        ]
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(
                id: index == 0 ? editedRecordID : UUID(),
                gameID: game.id,
                sequenceNumber: index + 1,
                timestamp: index == 0 ? editedTimestamp : editedTimestamp.addingTimeInterval(Double(index)),
                body: body
            )
        }
        records.forEach(context.insert)
        try context.save()

        let editSession = try GameEventCorrection.prepareOffensivePitchEdit(
            recordID: editedRecordID,
            game: game,
            modelContext: context
        )
        #expect(editSession.batter == batter)
        #expect(editSession.battingOrderSize == 10)
        #expect(editSession.originalResult == .ball)
        let session = try GameEventCorrection.beginGameEventCorrection(
            game: game,
            modelContext: context
        )
        let noOp = try GameEventCorrection.stageOffensivePitchEdit(
            recordID: editedRecordID,
            result: .ball,
            in: session,
            game: game,
            modelContext: context
        )
        #expect(!noOp.canSave)
        let staged = try GameEventCorrection.stageOffensivePitchEdit(
            recordID: editedRecordID,
            result: .swingingStrike,
            in: session,
            game: game,
            modelContext: context
        )

        #expect(staged.canSave)
        #expect(staged.firstInvalidRecord == nil)
        #expect(staged.snapshot.replay.state.currentTrackedBatterSlot == 2)
        #expect(staged.snapshot.replay.state.balls == 1)
        #expect(staged.snapshot.replay.state.strikes == 0)
        #expect(staged.snapshot.battingLines[batter.playerID]?.hits == 1)
        _ = try GameEventCorrection.saveGameEventCorrection(
            staged,
            game: game,
            modelContext: context
        )

        let freshContext = ModelContext(container)
        let saved = try LiveGameSnapshotLoader.load(game: game, modelContext: freshContext)
        let editedRecord = try #require(saved.records.first)
        #expect(editedRecord.id == editedRecordID)
        #expect(editedRecord.gameID == game.id)
        #expect(editedRecord.sequenceNumber == 1)
        #expect(editedRecord.timestamp == editedTimestamp)
        #expect(try editedRecord.decoded().body == .offensivePitch(.init(
            batter: batter,
            battingOrderSize: 10,
            result: .swingingStrike
        )))
        #expect(saved.replay.state.currentTrackedBatterSlot == 2)
        #expect(saved.replay.state.balls == 1)
        #expect(saved.replay.state.strikes == 0)
        #expect(saved.battingLines[batter.playerID]?.hits == 1)
    }

    @Test func trackedTeamPitchDeletionPreservesSurvivorsAndProjectionAfterFreshContext() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let nextBatter = makeTrackedBatter(
            displayName: "Jordan Lee",
            jerseyNumber: "12",
            position: .centerField,
            lineupSlot: 2
        )
        let timestamps = (0..<4).map {
            Date(timeIntervalSince1970: 1_787_100_000 + Double($0 * 10))
        }
        let bodies: [GameEventBody] = [
            .offensivePitch(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .ball
            )),
            .offensivePitch(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .calledStrike
            )),
            .offensivePlateAppearance(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePitch(.init(
                batter: nextBatter,
                battingOrderSize: 10,
                result: .ball
            ))
        ]
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                timestamp: timestamps[index],
                body: body
            )
        }
        records.forEach(context.insert)
        try context.save()

        let deletion = try GameEventCorrection.prepareOffensivePitchDeletion(
            recordID: records[0].id,
            game: game,
            modelContext: context
        )
        #expect(deletion.batter == batter)
        #expect(deletion.battingOrderSize == 10)
        #expect(deletion.originalResult == .ball)
        #expect(deletion.sequenceNumber == 1)
        #expect(deletion.confirmationDetail.contains(
            "Avery Stone, batting slot 1 of 10, sequence 1: Ball"
        ))

        let staged = try GameEventCorrection.stageOffensivePitchDeletion(
            deletion,
            game: game,
            modelContext: context
        )

        #expect(staged.canSave)
        #expect(staged.firstInvalidRecord == nil)
        #expect(staged.snapshot.records.map(\.id) == Array(records.dropFirst()).map(\.id))
        #expect(staged.snapshot.replay.state.currentTrackedBatterSlot == 2)
        #expect(staged.snapshot.replay.state.balls == 1)
        #expect(staged.snapshot.replay.state.strikes == 0)
        #expect(staged.snapshot.battingLines[batter.playerID]?.hits == 1)

        let storedBeforeSave = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(storedBeforeSave.map(\.id) == records.map(\.id))

        _ = try GameEventCorrection.saveGameEventCorrection(
            staged,
            game: game,
            modelContext: context
        )

        let saved = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(saved.records.map(\.id) == Array(records.dropFirst()).map(\.id))
        #expect(saved.records.map(\.sequenceNumber) == [2, 3, 4])
        #expect(saved.records.map(\.timestamp) == Array(timestamps.dropFirst()))
        #expect(try saved.records.map { try $0.decoded().body } == Array(bodies.dropFirst()))
        #expect(saved.replay.state == staged.snapshot.replay.state)
        #expect(saved.battingLines == staged.snapshot.battingLines)
    }

    @Test func trackedTeamPitchDeletionRejectsWalkThatNoLongerMatchesStartedCount() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let records = try [
            GameEventBody.offensivePitch(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .ball
            )),
            .offensivePitch(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .ball
            )),
            .offensivePitch(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .ball
            )),
            .offensivePlateAppearance(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .walk,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let original = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        #expect(original.replay.rejectedRecordIDs.isEmpty)
        #expect(original.replay.state.currentTrackedBatterSlot == 2)
        #expect(original.battingLines[batter.playerID]?.walks == 1)

        let session = try GameEventCorrection.beginGameEventCorrection(
            game: game,
            modelContext: context
        )
        let invalid = try GameEventCorrection.stageOffensivePitchDeletion(
            recordID: records[0].id,
            in: session,
            game: game,
            modelContext: context
        )

        #expect(!invalid.canSave)
        #expect(invalid.firstInvalidRecord?.id == records[3].id)
        #expect(invalid.firstInvalidRecord?.sequenceNumber == 4)
        #expect(invalid.snapshot.replay.state.currentTrackedBatterSlot == 1)
        #expect(invalid.snapshot.replay.state.balls == 2)
        #expect(invalid.snapshot.battingLines[batter.playerID] == nil)
        #expect(throws: GameEventCorrectionError.invalidCandidate) {
            _ = try GameEventCorrection.saveGameEventCorrection(
                invalid,
                game: game,
                modelContext: context
            )
        }

        let stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
        #expect(stored.count == records.count)
    }

    @Test func trackedTeamPitchEditStagesRepairForInvalidLaterPitch() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let records = try seedOffensivePitches(
            [.ball, .calledStrike, .swingingStrike],
            game: game,
            batter: batter,
            modelContext: context
        )
        let originalBodies = try records.map { try $0.decoded().body }
        let session = try GameEventCorrection.beginGameEventCorrection(
            game: game,
            modelContext: context
        )

        let invalid = try GameEventCorrection.stageOffensivePitchEdit(
            recordID: records[0].id,
            result: .calledStrike,
            in: session,
            game: game,
            modelContext: context
        )

        #expect(!invalid.canSave)
        #expect(invalid.firstInvalidRecord?.id == records[2].id)
        #expect(invalid.firstInvalidRecord?.canEditOffensivePitch == true)
        #expect(throws: GameEventCorrectionError.invalidCandidate) {
            _ = try GameEventCorrection.saveGameEventCorrection(
                invalid,
                game: game,
                modelContext: context
            )
        }
        #expect(try records.map { try $0.decoded().body } == originalBodies)

        let repaired = try GameEventCorrection.stageOffensivePitchEdit(
            recordID: records[2].id,
            result: .foul,
            in: invalid,
            game: game,
            modelContext: context
        )

        #expect(repaired.canSave)
        #expect(repaired.firstInvalidRecord == nil)
        #expect(repaired.snapshot.replay.state.balls == 0)
        #expect(repaired.snapshot.replay.state.strikes == 2)
    }

    @Test func trackedTeamPitchDeletionRemainsStagedThroughDownstreamRepair() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let records = try seedOffensivePitches(
            [.ball, .ball, .calledStrike, .swingingStrike],
            game: game,
            batter: batter,
            modelContext: context
        )
        let originalBodies = try records.map { try $0.decoded().body }
        let session = try GameEventCorrection.beginGameEventCorrection(
            game: game,
            modelContext: context
        )

        let deletion = try GameEventCorrection.stageOffensivePitchDeletion(
            recordID: records[0].id,
            in: session,
            game: game,
            modelContext: context
        )
        let invalid = try GameEventCorrection.stageOffensivePitchEdit(
            recordID: records[1].id,
            result: .calledStrike,
            in: deletion,
            game: game,
            modelContext: context
        )

        #expect(!invalid.canSave)
        #expect(invalid.firstInvalidRecord?.id == records[3].id)
        #expect(invalid.firstInvalidRecord?.canEditOffensivePitch == true)
        #expect(invalid.firstInvalidRecord?.canDeleteOffensivePitch == true)
        #expect(throws: GameEventCorrectionError.invalidCandidate) {
            _ = try GameEventCorrection.saveGameEventCorrection(
                invalid,
                game: game,
                modelContext: context
            )
        }
        #expect(try records.map { try $0.decoded().body } == originalBodies)

        let repaired = try GameEventCorrection.stageOffensivePitchDeletion(
            recordID: records[3].id,
            in: invalid,
            game: game,
            modelContext: context
        )

        #expect(repaired.canSave)
        #expect(repaired.firstInvalidRecord == nil)
        #expect(repaired.snapshot.records.map(\.id) == [records[1].id, records[2].id])
        #expect(repaired.snapshot.replay.state.balls == 0)
        #expect(repaired.snapshot.replay.state.strikes == 2)
    }

    @Test func trackedTeamPitchDeletionRejectsWrongGameStaleSessionAndSaveFailure() throws {
        struct ProjectionFailure: Error {}
        struct SaveFailure: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let otherGame = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let record = try #require(seedOffensivePitches(
            [.ball],
            game: game,
            batter: batter,
            modelContext: context
        ).first)

        #expect(throws: GameEventCorrectionError.offensivePitchNotDeletable) {
            _ = try GameEventCorrection.prepareOffensivePitchDeletion(
                recordID: UUID(),
                game: game,
                modelContext: context
            )
        }
        #expect(GameEventCorrectionError.offensivePitchNotDeletable.errorDescription ==
            "This saved event is not a tracked-team pitch that can be deleted.")

        let deletion = try GameEventCorrection.prepareOffensivePitchDeletion(
            recordID: record.id,
            game: game,
            modelContext: context
        )
        #expect(throws: GameEventCorrectionError.gameMismatch) {
            _ = try GameEventCorrection.stageOffensivePitchDeletion(
                deletion,
                game: otherGame,
                modelContext: context
            )
        }
        #expect(throws: ProjectionFailure.self) {
            _ = try GameEventCorrection.stageOffensivePitchDeletion(
                deletion,
                game: game,
                modelContext: context,
                projectBattingLines: { _ in throw ProjectionFailure() }
            )
        }

        let staged = try GameEventCorrection.stageOffensivePitchDeletion(
            deletion,
            game: game,
            modelContext: context
        )
        #expect(throws: GameEventCorrectionError.gameMismatch) {
            _ = try GameEventCorrection.saveGameEventCorrection(
                staged,
                game: otherGame,
                modelContext: context
            )
        }
        #expect(throws: SaveFailure.self) {
            _ = try GameEventCorrection.saveGameEventCorrection(
                staged,
                game: game,
                modelContext: context,
                save: { _ in throw SaveFailure() }
            )
        }
        var stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
        #expect(stored.map(\.id) == [record.id])
        #expect(try stored[0].decoded().body == .offensivePitch(.init(
            batter: batter,
            battingOrderSize: 10,
            result: .ball
        )))

        let newer = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .offensivePitch(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .foul
            ))
        )
        context.insert(newer)
        try context.save()

        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.stageOffensivePitchDeletion(
                deletion,
                game: game,
                modelContext: context
            )
        }
        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.saveGameEventCorrection(
                staged,
                game: game,
                modelContext: context
            )
        }
        stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stored.map(\.id) == [record.id, newer.id])
    }

    @Test func trackedTeamPitchEditRejectsWrongGameStaleSessionAndSaveFailure() throws {
        struct ProjectionFailure: Error {}
        struct SaveFailure: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let otherGame = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let record = try #require(seedOffensivePitches(
            [.ball],
            game: game,
            batter: batter,
            modelContext: context
        ).first)
        let session = try GameEventCorrection.beginGameEventCorrection(
            game: game,
            modelContext: context
        )
        let editSession = try GameEventCorrection.prepareOffensivePitchEdit(
            recordID: record.id,
            game: game,
            modelContext: context
        )

        #expect(throws: GameEventCorrectionError.gameMismatch) {
            _ = try GameEventCorrection.stageOffensivePitchEdit(
                recordID: record.id,
                result: .calledStrike,
                in: session,
                game: otherGame,
                modelContext: context
            )
        }
        #expect(throws: ProjectionFailure.self) {
            _ = try GameEventCorrection.stageOffensivePitchEdit(
                recordID: record.id,
                result: .calledStrike,
                in: session,
                game: game,
                modelContext: context,
                projectBattingLines: { _ in throw ProjectionFailure() }
            )
        }
        let staged = try GameEventCorrection.stageOffensivePitchEdit(
            recordID: record.id,
            result: .calledStrike,
            in: session,
            game: game,
            modelContext: context
        )
        #expect(throws: SaveFailure.self) {
            _ = try GameEventCorrection.saveGameEventCorrection(
                staged,
                game: game,
                modelContext: context,
                save: { _ in throw SaveFailure() }
            )
        }
        let storedAfterFailedSave = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
        #expect(storedAfterFailedSave.count == 1)
        #expect(try storedAfterFailedSave[0].decoded().body == .offensivePitch(.init(
            batter: batter,
            battingOrderSize: 10,
            result: .ball
        )))

        let newer = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .offensivePitch(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .foul
            ))
        )
        context.insert(newer)
        try context.save()
        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.stageOffensivePitchEdit(
                .swingingStrike,
                in: editSession,
                game: game,
                modelContext: context
            )
        }
        #expect(GameEventCorrectionError.staleTimeline.localizedDescription.contains("reopen"))
        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.stageOffensivePitchEdit(
                recordID: record.id,
                result: .swingingStrike,
                in: session,
                game: game,
                modelContext: context
            )
        }
        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.saveGameEventCorrection(
                staged,
                game: game,
                modelContext: context
            )
        }
    }

    @Test func trackedTeamBaseRunningEditChangesStealToCaughtStealingAndPreservesEventContext() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let runner = makeTrackedBatter()
        let activeBatter = makeTrackedBatter(
            displayName: "Jordan Lee",
            jerseyNumber: "12",
            position: .centerField,
            lineupSlot: 2
        )
        let editedRecordID = UUID()
        let editedTimestamp = Date(timeIntervalSince1970: 1_787_300_000)
        let records = try [
            GameEventRecord(
                gameID: game.id,
                sequenceNumber: 1,
                body: .offensivePlateAppearance(.init(
                    batter: runner,
                    battingOrderSize: 10,
                    result: .single,
                    movements: [.init(source: .batter, destination: .first)],
                    rbi: 0,
                    countedRunSources: [],
                    thirdOutClassification: nil
                ))
            ),
            GameEventRecord(
                gameID: game.id,
                sequenceNumber: 2,
                body: .offensivePitch(.init(
                    batter: activeBatter,
                    battingOrderSize: 10,
                    result: .ball
                ))
            ),
            GameEventRecord(
                id: editedRecordID,
                gameID: game.id,
                sequenceNumber: 3,
                timestamp: editedTimestamp,
                body: .offensiveBaseRunning(.init(
                    runnerID: runner.playerID,
                    source: .first,
                    destination: .second,
                    result: .stolenBase
                ))
            )
        ]
        records.forEach(context.insert)
        try context.save()

        let editSession = try GameEventCorrection.prepareOffensiveBaseRunningEdit(
            recordID: editedRecordID,
            game: game,
            modelContext: context
        )
        #expect(editSession.runner == runner)
        #expect(editSession.originalEvent.source == .first)
        #expect(editSession.originalEvent.destination == .second)
        #expect(editSession.originalEvent.result == .stolenBase)
        #expect(editSession.stateBefore.currentTrackedBatterSlot == 2)
        #expect(editSession.stateBefore.balls == 1)

        let proposed = OffensiveBaseRunningEvent(
            runnerID: runner.playerID,
            source: .first,
            destination: .out,
            result: .caughtStealing
        )
        let staged = try GameEventCorrection.stageOffensiveBaseRunningEdit(
            proposed,
            in: editSession,
            game: game,
            modelContext: context
        )

        #expect(staged.canSave)
        #expect(staged.firstInvalidRecord == nil)
        #expect(staged.snapshot.replay.state.firstBaseRunnerPlayerID == nil)
        #expect(staged.snapshot.replay.state.secondBaseRunnerPlayerID == nil)
        #expect(staged.snapshot.replay.state.outs == 1)
        #expect(staged.snapshot.replay.state.currentTrackedBatterSlot == 2)
        #expect(staged.snapshot.replay.state.balls == 1)
        #expect(staged.snapshot.battingLines[runner.playerID]?.stolenBases == 0)
        #expect(staged.snapshot.battingLines[runner.playerID]?.caughtStealing == 1)

        _ = try GameEventCorrection.saveGameEventCorrection(
            staged,
            game: game,
            modelContext: context
        )

        let reloaded = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(reloaded.records[2].id == editedRecordID)
        #expect(reloaded.records[2].sequenceNumber == 3)
        #expect(reloaded.records[2].timestamp == editedTimestamp)
        #expect(try reloaded.records[2].decoded().body == .offensiveBaseRunning(proposed))
        #expect(reloaded.replay.state == staged.snapshot.replay.state)
        #expect(reloaded.battingLines == staged.snapshot.battingLines)
    }

    @Test func trackedTeamBaseRunningEditCanSelectDifferentEventTimeEligibleRunner() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let thirdBaseRunner = makeTrackedBatter()
        let firstBaseRunner = makeTrackedBatter(
            displayName: "Jordan Lee",
            jerseyNumber: "12",
            position: .centerField,
            lineupSlot: 2
        )
        let records = try [
            GameEventBody.offensivePlateAppearance(.init(
                batter: thirdBaseRunner,
                battingOrderSize: 10,
                result: .triple,
                movements: [.init(source: .batter, destination: .third)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePlateAppearance(.init(
                batter: firstBaseRunner,
                battingOrderSize: 10,
                result: .single,
                movements: [
                    .init(source: .third, destination: .third),
                    .init(source: .batter, destination: .first)
                ],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensiveBaseRunning(.init(
                runnerID: thirdBaseRunner.playerID,
                source: .third,
                destination: .out,
                result: .caughtStealing
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let editSession = try GameEventCorrection.prepareOffensiveBaseRunningEdit(
            recordID: records[2].id,
            game: game,
            modelContext: context
        )
        #expect(editSession.runner == thirdBaseRunner)
        #expect(Set(editSession.eligibleRunners.map(\.identity.playerID)) == [
            thirdBaseRunner.playerID,
            firstBaseRunner.playerID
        ])
        #expect(editSession.eligibleRunners.first(where: {
            $0.identity.playerID == firstBaseRunner.playerID
        })?.source == .first)

        let proposed = OffensiveBaseRunningEvent(
            runnerID: firstBaseRunner.playerID,
            source: .first,
            destination: .second,
            result: .stolenBase
        )
        let staged = try GameEventCorrection.stageOffensiveBaseRunningEdit(
            proposed,
            in: editSession,
            game: game,
            modelContext: context
        )

        #expect(staged.canSave)
        #expect(staged.snapshot.replay.state.thirdBaseRunnerPlayerID == thirdBaseRunner.playerID)
        #expect(staged.snapshot.replay.state.secondBaseRunnerPlayerID == firstBaseRunner.playerID)
        #expect(staged.snapshot.replay.state.outs == 0)
        #expect(staged.snapshot.battingLines[thirdBaseRunner.playerID]?.caughtStealing == 0)
        #expect(staged.snapshot.battingLines[firstBaseRunner.playerID]?.stolenBases == 1)
    }

    @Test func trackedTeamBaseRunningEditStealOfHomeReplaysScoreAndAttributionWithoutRBI() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let runner = makeTrackedBatter()
        let activeBatter = makeTrackedBatter(lineupSlot: 2)
        let records = try [
            GameEventBody.offensivePlateAppearance(.init(
                batter: runner,
                battingOrderSize: 10,
                result: .triple,
                movements: [.init(source: .batter, destination: .third)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePitch(.init(
                batter: activeBatter,
                battingOrderSize: 10,
                result: .calledStrike
            )),
            .offensiveBaseRunning(.init(
                runnerID: runner.playerID,
                source: .third,
                destination: .out,
                result: .caughtStealing
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let editSession = try GameEventCorrection.prepareOffensiveBaseRunningEdit(
            recordID: records[2].id,
            game: game,
            modelContext: context
        )
        let staged = try GameEventCorrection.stageOffensiveBaseRunningEdit(
            .init(
                runnerID: runner.playerID,
                source: .third,
                destination: .home,
                result: .stolenBase
            ),
            in: editSession,
            game: game,
            modelContext: context
        )

        #expect(staged.canSave)
        #expect(staged.snapshot.replay.state.awayScore == 1)
        #expect(staged.snapshot.replay.state.outs == 0)
        #expect(staged.snapshot.replay.state.currentTrackedBatterSlot == 2)
        #expect(staged.snapshot.replay.state.strikes == 1)
        #expect(staged.snapshot.battingLines[runner.playerID]?.runs == 1)
        #expect(staged.snapshot.battingLines[runner.playerID]?.stolenBases == 1)
        #expect(staged.snapshot.battingLines[runner.playerID]?.caughtStealing == 0)
        #expect(staged.snapshot.battingLines[runner.playerID]?.runsBattedIn == 0)
        #expect(
            staged.snapshot.battingLines[activeBatter.playerID, default: BattingLine()]
                .runsBattedIn == 0
        )
    }

    @Test func trackedTeamBaseRunningEditThirdOutCaughtStealingPreservesNextTrackedBatter() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batters = (1...4).map { slot in
            makeTrackedBatter(
                displayName: "Player \(slot)",
                jerseyNumber: "\(slot)",
                lineupSlot: slot
            )
        }
        let bodies: [GameEventBody] = [
            .offensivePlateAppearance(.init(
                batter: batters[0],
                battingOrderSize: 10,
                result: .strikeout,
                movements: [.init(source: .batter, destination: .out)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePlateAppearance(.init(
                batter: batters[1],
                battingOrderSize: 10,
                result: .strikeout,
                movements: [.init(source: .batter, destination: .out)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePlateAppearance(.init(
                batter: batters[2],
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePitch(.init(
                batter: batters[3],
                battingOrderSize: 10,
                result: .ball
            )),
            .offensiveBaseRunning(.init(
                runnerID: batters[2].playerID,
                source: .first,
                destination: .second,
                result: .stolenBase
            ))
        ]
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let editSession = try GameEventCorrection.prepareOffensiveBaseRunningEdit(
            recordID: records[4].id,
            game: game,
            modelContext: context
        )
        let staged = try GameEventCorrection.stageOffensiveBaseRunningEdit(
            .init(
                runnerID: batters[2].playerID,
                source: .first,
                destination: .out,
                result: .caughtStealing
            ),
            in: editSession,
            game: game,
            modelContext: context
        )

        #expect(staged.canSave)
        #expect(staged.snapshot.replay.state.inning == 1)
        #expect(staged.snapshot.replay.state.half == .bottom)
        #expect(staged.snapshot.replay.state.outs == 0)
        #expect(staged.snapshot.replay.state.trackedBaseRunnerPlayerIDs == [nil, nil, nil])
        #expect(staged.snapshot.replay.state.currentTrackedBatterSlot == 4)
        #expect(staged.snapshot.replay.state.balls == 0)
        #expect(staged.snapshot.replay.state.offensiveCountContext == nil)
        #expect(staged.snapshot.battingLines[batters[2].playerID]?.stolenBases == 0)
        #expect(staged.snapshot.battingLines[batters[2].playerID]?.caughtStealing == 1)
        #expect(staged.snapshot.battingLines[batters[3].playerID] == nil)
    }

    @Test func trackedTeamBaseRunningEditSupportsExplicitDownstreamBaseRunningRepair() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let thirdBaseRunner = makeTrackedBatter()
        let firstBaseRunner = makeTrackedBatter(lineupSlot: 2)
        let bodies: [GameEventBody] = [
            .offensivePlateAppearance(.init(
                batter: thirdBaseRunner,
                battingOrderSize: 10,
                result: .triple,
                movements: [.init(source: .batter, destination: .third)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePlateAppearance(.init(
                batter: firstBaseRunner,
                battingOrderSize: 10,
                result: .single,
                movements: [
                    .init(source: .third, destination: .third),
                    .init(source: .batter, destination: .first)
                ],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensiveBaseRunning(.init(
                runnerID: thirdBaseRunner.playerID,
                source: .third,
                destination: .home,
                result: .stolenBase
            )),
            .offensiveBaseRunning(.init(
                runnerID: firstBaseRunner.playerID,
                source: .first,
                destination: .second,
                result: .stolenBase
            ))
        ]
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()
        let session = try GameEventCorrection.beginGameEventCorrection(
            game: game,
            modelContext: context
        )

        let invalid = try GameEventCorrection.stageOffensiveBaseRunningEdit(
            recordID: records[2].id,
            event: .init(
                runnerID: firstBaseRunner.playerID,
                source: .first,
                destination: .out,
                result: .caughtStealing
            ),
            in: session,
            game: game,
            modelContext: context
        )

        #expect(!invalid.canSave)
        #expect(invalid.firstInvalidRecord?.id == records[3].id)
        #expect(invalid.firstInvalidRecord?.canEditOffensiveBaseRunning == true)
        #expect(invalid.firstInvalidRecord?.offensiveBaseRunningRunners.map(\.identity.playerID) == [
            thirdBaseRunner.playerID
        ])

        let repaired = try GameEventCorrection.stageOffensiveBaseRunningEdit(
            recordID: records[3].id,
            event: .init(
                runnerID: thirdBaseRunner.playerID,
                source: .third,
                destination: .home,
                result: .stolenBase
            ),
            in: invalid,
            game: game,
            modelContext: context
        )

        #expect(repaired.canSave)
        #expect(repaired.firstInvalidRecord == nil)
        #expect(repaired.stagedOffensiveBaseRunningChanges.count == 2)
        #expect(repaired.snapshot.replay.state.awayScore == 1)
        #expect(repaired.snapshot.replay.state.outs == 1)
        #expect(repaired.snapshot.battingLines[thirdBaseRunner.playerID]?.stolenBases == 1)
        #expect(repaired.snapshot.battingLines[firstBaseRunner.playerID]?.caughtStealing == 1)
    }

    @Test func trackedTeamBaseRunningEditRejectsIllegalCandidatesAndFailuresAtomically() throws {
        struct SaveFailure: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let secondBaseRunner = makeTrackedBatter()
        let firstBaseRunner = makeTrackedBatter(lineupSlot: 2)
        let records = try [
            GameEventBody.offensivePlateAppearance(.init(
                batter: secondBaseRunner,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePlateAppearance(.init(
                batter: firstBaseRunner,
                battingOrderSize: 10,
                result: .single,
                movements: [
                    .init(source: .first, destination: .second),
                    .init(source: .batter, destination: .first)
                ],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensiveBaseRunning(.init(
                runnerID: secondBaseRunner.playerID,
                source: .second,
                destination: .out,
                result: .caughtStealing
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()
        let originalBodies = try records.map { try $0.decoded().body }
        let editSession = try GameEventCorrection.prepareOffensiveBaseRunningEdit(
            recordID: records[2].id,
            game: game,
            modelContext: context
        )

        for illegal in [
            OffensiveBaseRunningEvent(
                runnerID: UUID(),
                source: .first,
                destination: .out,
                result: .caughtStealing
            ),
            OffensiveBaseRunningEvent(
                runnerID: firstBaseRunner.playerID,
                source: .first,
                destination: .second,
                result: .stolenBase
            ),
            OffensiveBaseRunningEvent(
                runnerID: secondBaseRunner.playerID,
                source: .second,
                destination: .home,
                result: .stolenBase
            )
        ] {
            #expect(throws: GameEventCorrectionError.offensiveBaseRunningNotEditable) {
                _ = try GameEventCorrection.stageOffensiveBaseRunningEdit(
                    illegal,
                    in: editSession,
                    game: game,
                    modelContext: context
                )
            }
        }

        #expect(throws: GameEventCorrectionError.gameMismatch) {
            _ = try GameEventCorrection.stageOffensiveBaseRunningEdit(
                .init(
                    runnerID: secondBaseRunner.playerID,
                    source: .second,
                    destination: .third,
                    result: .stolenBase
                ),
                in: editSession,
                game: makeOffensiveGame(),
                modelContext: context
            )
        }

        let staged = try GameEventCorrection.stageOffensiveBaseRunningEdit(
            .init(
                runnerID: secondBaseRunner.playerID,
                source: .second,
                destination: .third,
                result: .stolenBase
            ),
            in: editSession,
            game: game,
            modelContext: context
        )
        #expect(throws: SaveFailure.self) {
            _ = try GameEventCorrection.saveGameEventCorrection(
                staged,
                game: game,
                modelContext: context,
                save: { _ in throw SaveFailure() }
            )
        }
        var stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\.sequenceNumber)]
        ))
        #expect(try stored.map { try $0.decoded().body } == originalBodies)

        let newer = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 4,
            body: .offensivePitch(.init(
                batter: makeTrackedBatter(lineupSlot: 3),
                battingOrderSize: 10,
                result: .ball
            ))
        )
        context.insert(newer)
        try context.save()
        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.stageOffensiveBaseRunningEdit(
                .init(
                    runnerID: secondBaseRunner.playerID,
                    source: .second,
                    destination: .third,
                    result: .stolenBase
                ),
                in: editSession,
                game: game,
                modelContext: context
            )
        }
        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.saveGameEventCorrection(
                staged,
                game: game,
                modelContext: context
            )
        }
        stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
        #expect(stored.count == 4)

        let wrongHalfContainer = try AppModelContainer.make(inMemory: true)
        let wrongHalfContext = wrongHalfContainer.mainContext
        let wrongHalfGame = makeGame()
        let wrongHalfRecord = try GameEventRecord(
            gameID: wrongHalfGame.id,
            sequenceNumber: 1,
            body: .offensiveBaseRunning(.init(
                runnerID: UUID(),
                source: .first,
                destination: .out,
                result: .caughtStealing
            ))
        )
        wrongHalfContext.insert(wrongHalfRecord)
        try wrongHalfContext.save()
        #expect(throws: GameEventCorrectionError.invalidTimeline) {
            _ = try GameEventCorrection.prepareOffensiveBaseRunningEdit(
                recordID: wrongHalfRecord.id,
                game: wrongHalfGame,
                modelContext: wrongHalfContext
            )
        }
    }

    @Test func trackedTeamPlateAppearanceEditPreservesEventIdentityAndReprojectsBattingLines() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let leadRunner = makeTrackedBatter()
        let batter = makeTrackedBatter(
            displayName: "Jordan Lee",
            jerseyNumber: "12",
            position: .centerField,
            lineupSlot: 2
        )
        let editedRecordID = UUID()
        let editedTimestamp = Date(timeIntervalSince1970: 1_787_200_000)
        let records = try [
            GameEventRecord(
                gameID: game.id,
                sequenceNumber: 1,
                body: .offensivePlateAppearance(.init(
                    batter: leadRunner,
                    battingOrderSize: 10,
                    result: .single,
                    movements: [.init(source: .batter, destination: .first)],
                    rbi: 0,
                    countedRunSources: [],
                    thirdOutClassification: nil
                ))
            ),
            GameEventRecord(
                id: editedRecordID,
                gameID: game.id,
                sequenceNumber: 2,
                timestamp: editedTimestamp,
                body: .offensivePlateAppearance(.init(
                    batter: batter,
                    battingOrderSize: 10,
                    result: .single,
                    movements: [
                        .init(source: .first, destination: .second),
                        .init(source: .batter, destination: .first)
                    ],
                    rbi: 0,
                    countedRunSources: [],
                    thirdOutClassification: nil
                ))
            )
        ]
        records.forEach(context.insert)
        try context.save()

        let editSession = try GameEventCorrection.prepareOffensivePlateAppearanceEdit(
            recordID: editedRecordID,
            game: game,
            modelContext: context
        )
        #expect(editSession.batter == batter)
        #expect(editSession.battingOrderSize == 10)
        #expect(editSession.runnerIdentities[.first] == leadRunner)

        let proposed = OffensivePlateAppearanceEvent(
            batter: batter,
            battingOrderSize: 10,
            result: .reachedOnError,
            movements: [
                .init(source: .first, destination: .second),
                .init(source: .batter, destination: .first)
            ],
            rbi: 0,
            countedRunSources: [],
            thirdOutClassification: nil
        )
        let staged = try GameEventCorrection.stageOffensivePlateAppearanceEdit(
            proposed,
            in: editSession,
            game: game,
            modelContext: context
        )

        #expect(staged.canSave)
        #expect(staged.firstInvalidRecord == nil)
        #expect(staged.snapshot.replay.state.currentTrackedBatterSlot == 3)
        #expect(staged.snapshot.replay.state.firstBaseRunnerPlayerID == batter.playerID)
        #expect(staged.snapshot.replay.state.secondBaseRunnerPlayerID == leadRunner.playerID)
        #expect(staged.snapshot.battingLines[batter.playerID]?.hits == 0)
        #expect(staged.snapshot.battingLines[batter.playerID]?.atBats == 1)

        _ = try GameEventCorrection.saveGameEventCorrection(
            staged,
            game: game,
            modelContext: context
        )

        let saved = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        let savedRecord = try #require(saved.records.first(where: { $0.id == editedRecordID }))
        #expect(savedRecord.sequenceNumber == 2)
        #expect(savedRecord.timestamp == editedTimestamp)
        #expect(try savedRecord.decoded().body == .offensivePlateAppearance(proposed))
        #expect(saved.replay.state == staged.snapshot.replay.state)
        #expect(saved.battingLines == staged.snapshot.battingLines)
    }

    @Test(arguments: offensivePlateAppearanceCorrectionScenarios)
    fileprivate func trackedTeamPlateAppearanceEditReplaysRepresentativeNonScoringResults(
        _ scenario: OffensivePlateAppearanceCorrectionScenario
    ) throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let leadRunner = makeTrackedBatter()
        let batter = makeTrackedBatter(
            displayName: "Jordan Lee",
            jerseyNumber: "12",
            position: .centerField,
            lineupSlot: scenario.startsWithRunnerOnFirst ? 2 : 1
        )
        var records: [GameEventRecord] = []
        if scenario.startsWithRunnerOnFirst {
            records.append(try GameEventRecord(
                gameID: game.id,
                sequenceNumber: 1,
                body: .offensivePlateAppearance(.init(
                    batter: leadRunner,
                    battingOrderSize: 10,
                    result: .single,
                    movements: [.init(source: .batter, destination: .first)],
                    rbi: 0,
                    countedRunSources: [],
                    thirdOutClassification: nil
                ))
            ))
        }
        let originalMovements: [RunnerMovementEvent] = scenario.startsWithRunnerOnFirst
            ? [
                .init(source: .first, destination: .second),
                .init(source: .batter, destination: .first)
            ]
            : [.init(source: .batter, destination: .first)]
        let originalResult: OffensivePlateAppearanceResult = scenario.result == .reachedOnError
            ? .single
            : .reachedOnError
        let editedRecord = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: records.count + 1,
            body: .offensivePlateAppearance(.init(
                batter: batter,
                battingOrderSize: 10,
                result: originalResult,
                movements: originalMovements,
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ))
        )
        records.append(editedRecord)
        records.forEach(context.insert)
        try context.save()

        let editSession = try GameEventCorrection.prepareOffensivePlateAppearanceEdit(
            recordID: editedRecord.id,
            game: game,
            modelContext: context
        )
        let proposed = OffensivePlateAppearanceEvent(
            batter: batter,
            battingOrderSize: 10,
            result: scenario.result,
            movements: scenario.movements,
            rbi: 0,
            countedRunSources: [],
            thirdOutClassification: nil
        )
        let staged = try GameEventCorrection.stageOffensivePlateAppearanceEdit(
            proposed,
            in: editSession,
            game: game,
            modelContext: context
        )
        #expect(staged.canSave)
        #expect(staged.firstInvalidRecord == nil)
        _ = try GameEventCorrection.saveGameEventCorrection(
            staged,
            game: game,
            modelContext: context
        )

        let saved = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        let state = saved.replay.state
        let playerIDsBySource: [RunnerSource: UUID] = [
            .batter: batter.playerID,
            .first: leadRunner.playerID
        ]
        #expect(state.half == .top)
        #expect(state.awayScore == 0)
        #expect(state.homeScore == 0)
        #expect(state.outs == scenario.expectedOuts)
        #expect([
            state.firstBaseRunnerPlayerID,
            state.secondBaseRunnerPlayerID,
            state.thirdBaseRunnerPlayerID
        ] == scenario.expectedBaseSources.map { $0.flatMap { playerIDsBySource[$0] } })
        let line = try #require(saved.battingLines[batter.playerID])
        #expect(line.plateAppearances == 1)
        #expect(line.atBats == scenario.expectedAtBats)
        #expect(line.hits == scenario.expectedHits)
        #expect(line.doubles == scenario.expectedDoubles)
        #expect(line.triples == scenario.expectedTriples)
        #expect(line.walks == scenario.expectedWalks)
        #expect(line.hitByPitch == scenario.expectedHitByPitch)
        #expect(line.strikeouts == scenario.expectedStrikeouts)
        #expect(line.runs == 0)
        #expect(line.runsBattedIn == 0)
    }

    @Test(arguments: offensiveScoringCorrectionScenarios)
    fileprivate func trackedTeamPlateAppearanceEditReplaysRepresentativeScoringResults(
        _ scenario: OffensiveScoringCorrectionScenario
    ) throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let setupBatters = scenario.setup.indices.map { index in
            makeTrackedBatter(
                displayName: "Runner \(index + 1)",
                jerseyNumber: "\(index + 1)",
                lineupSlot: index + 1
            )
        }
        let batter = makeTrackedBatter(
            displayName: "Scoring Batter",
            jerseyNumber: "44",
            lineupSlot: scenario.setup.count + 1
        )
        var records = try zip(setupBatters, scenario.setup).enumerated().map {
            index, pair in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                body: .offensivePlateAppearance(.init(
                    batter: pair.0,
                    battingOrderSize: 10,
                    result: pair.1.result,
                    movements: pair.1.movements,
                    rbi: pair.1.rbi,
                    countedRunSources: pair.1.countedRunSources,
                    thirdOutClassification: nil
                ))
            )
        }
        let editedRecord = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: records.count + 1,
            body: .offensivePlateAppearance(.init(
                batter: batter,
                battingOrderSize: 10,
                result: scenario.original.result,
                movements: scenario.original.movements,
                rbi: scenario.original.rbi,
                countedRunSources: scenario.original.countedRunSources,
                thirdOutClassification: nil
            ))
        )
        records.append(editedRecord)
        records.forEach(context.insert)
        try context.save()

        let editSession = try GameEventCorrection.prepareOffensivePlateAppearanceEdit(
            recordID: editedRecord.id,
            game: game,
            modelContext: context
        )
        let proposed = OffensivePlateAppearanceEvent(
            batter: batter,
            battingOrderSize: 10,
            result: scenario.proposed.result,
            movements: scenario.proposed.movements,
            rbi: scenario.proposed.rbi,
            countedRunSources: scenario.proposed.countedRunSources,
            thirdOutClassification: nil
        )
        let staged = try GameEventCorrection.stageOffensivePlateAppearanceEdit(
            proposed,
            in: editSession,
            game: game,
            modelContext: context
        )

        #expect(staged.canSave)
        #expect(staged.firstInvalidRecord == nil)
        #expect(staged.snapshot.replay.state.awayScore == scenario.expectedScore)
        #expect(staged.snapshot.battingLines[batter.playerID]?.runsBattedIn
            == scenario.expectedBatterRBI)

        _ = try GameEventCorrection.saveGameEventCorrection(
            staged,
            game: game,
            modelContext: context
        )
        let saved = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        let state = saved.replay.state
        let playerIDsBySource = editSession.runnerIdentities.mapValues(\.playerID)
        #expect(state.half == .top)
        #expect(state.awayScore == scenario.expectedScore)
        #expect(state.homeScore == 0)
        #expect(state.outs == scenario.expectedOuts)
        #expect(state.currentTrackedBatterSlot == scenario.setup.count + 2)
        #expect([
            state.firstBaseRunnerPlayerID,
            state.secondBaseRunnerPlayerID,
            state.thirdBaseRunnerPlayerID
        ] == scenario.expectedBaseSources.map { $0.flatMap { playerIDsBySource[$0] } })
        #expect(saved.battingLines[batter.playerID]?.runsBattedIn
            == scenario.expectedBatterRBI)
        for (source, identity) in editSession.runnerIdentities {
            #expect(saved.battingLines[identity.playerID]?.runs
                == scenario.expectedRunsBySource[source, default: 0])
        }
        #expect(try saved.records.first(where: { $0.id == editedRecord.id })?.decoded().body
            == .offensivePlateAppearance(proposed))
    }

    @Test(arguments: offensiveScoringRemovalScenarios)
    fileprivate func trackedTeamPlateAppearanceEditRemovingHomeTouchRemovesRunAndScore(
        _ scenario: OffensiveScoringRemovalScenario
    ) throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let runner = makeTrackedBatter(displayName: "Lead Runner")
        let batter = makeTrackedBatter(
            displayName: "Scoring Batter",
            jerseyNumber: "12",
            lineupSlot: 2
        )
        let records = try [
            GameEventRecord(
                gameID: game.id,
                sequenceNumber: 1,
                body: .offensivePlateAppearance(.init(
                    batter: runner,
                    battingOrderSize: 10,
                    result: .single,
                    movements: [.init(source: .batter, destination: .first)],
                    rbi: 0,
                    countedRunSources: [],
                    thirdOutClassification: nil
                ))
            ),
            GameEventRecord(
                gameID: game.id,
                sequenceNumber: 2,
                body: .offensivePlateAppearance(.init(
                    batter: batter,
                    battingOrderSize: 10,
                    result: .double,
                    movements: [
                        .init(source: .first, destination: .home),
                        .init(source: .batter, destination: .second)
                    ],
                    rbi: 1,
                    countedRunSources: [.first],
                    thirdOutClassification: nil
                ))
            )
        ]
        records.forEach(context.insert)
        try context.save()

        let editSession = try GameEventCorrection.prepareOffensivePlateAppearanceEdit(
            recordID: records[1].id,
            game: game,
            modelContext: context
        )
        let proposed = OffensivePlateAppearanceEvent(
            batter: batter,
            battingOrderSize: 10,
            result: scenario.proposed.result,
            movements: scenario.proposed.movements,
            rbi: scenario.proposed.rbi,
            countedRunSources: scenario.proposed.countedRunSources,
            thirdOutClassification: nil
        )
        let staged = try GameEventCorrection.stageOffensivePlateAppearanceEdit(
            proposed,
            in: editSession,
            game: game,
            modelContext: context
        )
        #expect(staged.canSave)
        #expect(staged.snapshot.replay.state.awayScore == 0)

        _ = try GameEventCorrection.saveGameEventCorrection(
            staged,
            game: game,
            modelContext: context
        )
        let saved = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        let playerIDsBySource = editSession.runnerIdentities.mapValues(\.playerID)
        #expect(saved.replay.state.awayScore == 0)
        #expect(saved.replay.state.outs == scenario.expectedOuts)
        #expect([
            saved.replay.state.firstBaseRunnerPlayerID,
            saved.replay.state.secondBaseRunnerPlayerID,
            saved.replay.state.thirdBaseRunnerPlayerID
        ] == scenario.expectedBaseSources.map { $0.flatMap { playerIDsBySource[$0] } })
        #expect(saved.battingLines[runner.playerID]?.runs == 0)
        #expect(saved.battingLines[batter.playerID]?.runsBattedIn == 0)
    }

    @Test func trackedTeamScoringPlateAppearanceEditStagesDownstreamPlateAppearanceRepair() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let firstBatter = makeTrackedBatter()
        let secondBatter = makeTrackedBatter(
            displayName: "Jordan Lee",
            jerseyNumber: "12",
            position: .centerField,
            lineupSlot: 2
        )
        let thirdBatter = makeTrackedBatter(
            displayName: "Riley Chen",
            jerseyNumber: "18",
            position: .shortstop,
            lineupSlot: 3
        )
        let plateAppearances = [
            OffensivePlateAppearanceEvent(
                batter: firstBatter,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ),
            OffensivePlateAppearanceEvent(
                batter: secondBatter,
                battingOrderSize: 10,
                result: .single,
                movements: [
                    .init(source: .first, destination: .second),
                    .init(source: .batter, destination: .first)
                ],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ),
            OffensivePlateAppearanceEvent(
                batter: thirdBatter,
                battingOrderSize: 10,
                result: .single,
                movements: [
                    .init(source: .second, destination: .third),
                    .init(source: .first, destination: .second),
                    .init(source: .batter, destination: .first)
                ],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )
        ]
        let records = try plateAppearances.enumerated().map { index, plateAppearance in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                body: .offensivePlateAppearance(plateAppearance)
            )
        }
        records.forEach(context.insert)
        try context.save()
        let originalBodies = try records.map { try $0.decoded().body }

        let editSession = try GameEventCorrection.prepareOffensivePlateAppearanceEdit(
            recordID: records[1].id,
            game: game,
            modelContext: context
        )
        let invalid = try GameEventCorrection.stageOffensivePlateAppearanceEdit(
            .init(
                batter: secondBatter,
                battingOrderSize: 10,
                result: .single,
                movements: [
                    .init(source: .first, destination: .home),
                    .init(source: .batter, destination: .first)
                ],
                rbi: 1,
                countedRunSources: [.first],
                thirdOutClassification: nil
            ),
            in: editSession,
            game: game,
            modelContext: context
        )

        #expect(!invalid.canSave)
        #expect(invalid.firstInvalidRecord?.id == records[2].id)
        #expect(invalid.firstInvalidRecord?.canEditOffensivePlateAppearance == true)
        #expect(
            Set(invalid.firstInvalidRecord?.offensiveRunnerIdentities.map(\.playerID) ?? [])
                == Set([secondBatter.playerID, thirdBatter.playerID])
        )
        #expect(throws: GameEventCorrectionError.invalidCandidate) {
            _ = try GameEventCorrection.saveGameEventCorrection(
                invalid,
                game: game,
                modelContext: context
            )
        }
        #expect(try records.map { try $0.decoded().body } == originalBodies)

        let repaired = try GameEventCorrection.stageOffensivePlateAppearanceEdit(
            recordID: records[2].id,
            plateAppearance: .init(
                batter: thirdBatter,
                battingOrderSize: 10,
                result: .single,
                movements: [
                    .init(source: .first, destination: .second),
                    .init(source: .batter, destination: .first)
                ],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ),
            in: invalid,
            game: game,
            modelContext: context
        )

        #expect(repaired.canSave)
        #expect(repaired.firstInvalidRecord == nil)
        #expect(repaired.stagedOffensivePlateAppearanceChanges.count == 2)
        #expect(repaired.snapshot.replay.state.awayScore == 1)
        #expect(repaired.snapshot.replay.state.outs == 0)
        #expect(repaired.snapshot.replay.state.firstBaseRunnerPlayerID == thirdBatter.playerID)
        #expect(repaired.snapshot.replay.state.secondBaseRunnerPlayerID == secondBatter.playerID)
        #expect(repaired.snapshot.replay.state.currentTrackedBatterSlot == 4)
        #expect(repaired.snapshot.battingLines[firstBatter.playerID]?.runs == 1)
        #expect(repaired.snapshot.battingLines[secondBatter.playerID]?.runsBattedIn == 1)

        _ = try GameEventCorrection.saveGameEventCorrection(
            repaired,
            game: game,
            modelContext: context
        )
        let saved = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(saved.replay.state == repaired.snapshot.replay.state)
        #expect(saved.battingLines == repaired.snapshot.battingLines)
        #expect(saved.replay.state.awayScore == 1)
        #expect(saved.battingLines[firstBatter.playerID]?.runs == 1)
        #expect(saved.battingLines[secondBatter.playerID]?.runsBattedIn == 1)
    }

    @Test func trackedTeamThirdOutDoublePlayCorrectionReplaysScoreAndPlayerAttribution() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let leadRunner = makeTrackedBatter(
            displayName: "Avery Stone",
            jerseyNumber: "8",
            lineupSlot: 1
        )
        let trailRunner = makeTrackedBatter(
            displayName: "Jordan Lee",
            jerseyNumber: "12",
            lineupSlot: 2
        )
        let firstOutBatter = makeTrackedBatter(
            displayName: "Riley Chen",
            jerseyNumber: "18",
            lineupSlot: 3
        )
        let doublePlayBatter = makeTrackedBatter(
            displayName: "Morgan Diaz",
            jerseyNumber: "24",
            lineupSlot: 4
        )
        let originalThirdOut = OffensivePlateAppearanceEvent(
            batter: doublePlayBatter,
            battingOrderSize: 10,
            result: .doublePlay,
            movements: [
                .init(source: .third, destination: .home),
                .init(source: .first, destination: .out),
                .init(source: .batter, destination: .out)
            ],
            rbi: 0,
            countedRunSources: [],
            thirdOutClassification: .forceOrBatterRunner
        )
        let bodies: [GameEventBody] = [
            .offensivePlateAppearance(.init(
                batter: leadRunner,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePlateAppearance(.init(
                batter: trailRunner,
                battingOrderSize: 10,
                result: .single,
                movements: [
                    .init(source: .first, destination: .third),
                    .init(source: .batter, destination: .first)
                ],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePlateAppearance(.init(
                batter: firstOutBatter,
                battingOrderSize: 10,
                result: .groundOut,
                movements: [
                    .init(source: .first, destination: .first),
                    .init(source: .third, destination: .third),
                    .init(source: .batter, destination: .out)
                ],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePlateAppearance(originalThirdOut)
        ]
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                body: body
            )
        }
        records.forEach(context.insert)
        try context.save()

        let editSession = try GameEventCorrection.prepareOffensivePlateAppearanceEdit(
            recordID: records[3].id,
            game: game,
            modelContext: context
        )
        let invalidThirdOuts = [
            OffensivePlateAppearanceEvent(
                batter: doublePlayBatter,
                battingOrderSize: 10,
                result: .doublePlay,
                movements: originalThirdOut.movements,
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ),
            OffensivePlateAppearanceEvent(
                batter: doublePlayBatter,
                battingOrderSize: 10,
                result: .doublePlay,
                movements: originalThirdOut.movements,
                rbi: 1,
                countedRunSources: [.third],
                thirdOutClassification: .forceOrBatterRunner
            ),
            OffensivePlateAppearanceEvent(
                batter: doublePlayBatter,
                battingOrderSize: 10,
                result: .doublePlay,
                movements: originalThirdOut.movements,
                rbi: 1,
                countedRunSources: [.first],
                thirdOutClassification: .timingPlay
            )
        ]
        for invalidThirdOut in invalidThirdOuts {
            #expect(throws: GameEventCorrectionError.offensivePlateAppearanceNotEditable) {
                _ = try GameEventCorrection.stageOffensivePlateAppearanceEdit(
                    invalidThirdOut,
                    in: editSession,
                    game: game,
                    modelContext: context
                )
            }
        }
        let timingThirdOut = OffensivePlateAppearanceEvent(
            batter: doublePlayBatter,
            battingOrderSize: 10,
            result: .doublePlay,
            movements: originalThirdOut.movements,
            rbi: 1,
            countedRunSources: [.third],
            thirdOutClassification: .timingPlay
        )
        let staged = try GameEventCorrection.stageOffensivePlateAppearanceEdit(
            timingThirdOut,
            in: editSession,
            game: game,
            modelContext: context
        )

        #expect(staged.canSave)
        #expect(staged.firstInvalidRecord == nil)
        #expect(staged.snapshot.replay.state.awayScore == 1)
        #expect(staged.snapshot.replay.state.inning == 1)
        #expect(staged.snapshot.replay.state.half == .bottom)
        #expect(staged.snapshot.replay.state.outs == 0)
        #expect(staged.snapshot.replay.state.balls == 0)
        #expect(staged.snapshot.replay.state.strikes == 0)
        #expect(staged.snapshot.replay.state.firstBaseRunnerPlayerID == nil)
        #expect(staged.snapshot.replay.state.secondBaseRunnerPlayerID == nil)
        #expect(staged.snapshot.replay.state.thirdBaseRunnerPlayerID == nil)
        #expect(staged.snapshot.replay.state.currentTrackedBatterSlot == 5)
        #expect(staged.snapshot.battingLines[leadRunner.playerID]?.runs == 1)
        #expect(staged.snapshot.battingLines[trailRunner.playerID]?.runs == 0)
        #expect(staged.snapshot.battingLines[doublePlayBatter.playerID]?.plateAppearances == 1)
        #expect(staged.snapshot.battingLines[doublePlayBatter.playerID]?.atBats == 1)
        #expect(staged.snapshot.battingLines[doublePlayBatter.playerID]?.runsBattedIn == 1)

        let storedBeforeSave = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(try storedBeforeSave[3].decoded().body == .offensivePlateAppearance(originalThirdOut))

        _ = try GameEventCorrection.saveGameEventCorrection(
            staged,
            game: game,
            modelContext: context
        )
        let reloaded = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(reloaded.replay.state == staged.snapshot.replay.state)
        #expect(reloaded.battingLines == staged.snapshot.battingLines)
        #expect(reloaded.replay.state.currentTrackedBatterSlot == 5)
        #expect(reloaded.battingLines[leadRunner.playerID]?.runs == 1)
        #expect(reloaded.battingLines[doublePlayBatter.playerID]?.runsBattedIn == 1)
        #expect(try reloaded.records[3].decoded().body == .offensivePlateAppearance(timingThirdOut))
        #expect(reloaded.records[3].id == records[3].id)
        #expect(reloaded.records[3].sequenceNumber == records[3].sequenceNumber)
        #expect(reloaded.records[3].timestamp == records[3].timestamp)
    }

    @Test func trackedTeamPlateAppearanceEditRejectsIllegalCandidates() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let leadRunner = makeTrackedBatter()
        let batter = makeTrackedBatter(
            displayName: "Jordan Lee",
            jerseyNumber: "12",
            position: .centerField,
            lineupSlot: 2
        )
        let records = try [
            GameEventRecord(
                gameID: game.id,
                sequenceNumber: 1,
                body: .offensivePlateAppearance(.init(
                    batter: leadRunner,
                    battingOrderSize: 10,
                    result: .single,
                    movements: [.init(source: .batter, destination: .first)],
                    rbi: 0,
                    countedRunSources: [],
                    thirdOutClassification: nil
                ))
            ),
            GameEventRecord(
                gameID: game.id,
                sequenceNumber: 2,
                body: .offensivePlateAppearance(.init(
                    batter: batter,
                    battingOrderSize: 10,
                    result: .single,
                    movements: [
                        .init(source: .first, destination: .second),
                        .init(source: .batter, destination: .first)
                    ],
                    rbi: 0,
                    countedRunSources: [],
                    thirdOutClassification: nil
                ))
            )
        ]
        records.forEach(context.insert)
        try context.save()
        let editSession = try GameEventCorrection.prepareOffensivePlateAppearanceEdit(
            recordID: records[1].id,
            game: game,
            modelContext: context
        )
        let wrongBatter = makeTrackedBatter(
            displayName: "Wrong Batter",
            jerseyNumber: "99",
            position: .catcher,
            lineupSlot: 2
        )
        let illegalCandidates: [OffensivePlateAppearanceEvent] = [
            .init(
                batter: wrongBatter,
                battingOrderSize: 10,
                result: .single,
                movements: [
                    .init(source: .first, destination: .second),
                    .init(source: .batter, destination: .first)
                ],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ),
            .init(
                batter: batter,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .first, destination: .second)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ),
            .init(
                batter: batter,
                battingOrderSize: 10,
                result: .single,
                movements: [
                    .init(source: .first, destination: .second),
                    .init(source: .batter, destination: .first),
                    .init(source: .batter, destination: .second)
                ],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ),
            .init(
                batter: batter,
                battingOrderSize: 10,
                result: .single,
                movements: [
                    .init(source: .first, destination: .first),
                    .init(source: .batter, destination: .second)
                ],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ),
            .init(
                batter: batter,
                battingOrderSize: 10,
                result: .single,
                movements: [
                    .init(source: .first, destination: .home),
                    .init(source: .batter, destination: .first)
                ],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ),
            .init(
                batter: batter,
                battingOrderSize: 10,
                result: .single,
                movements: [
                    .init(source: .first, destination: .home),
                    .init(source: .batter, destination: .first)
                ],
                rbi: 0,
                countedRunSources: [.batter],
                thirdOutClassification: nil
            ),
            .init(
                batter: batter,
                battingOrderSize: 10,
                result: .single,
                movements: [
                    .init(source: .first, destination: .home),
                    .init(source: .batter, destination: .first)
                ],
                rbi: 2,
                countedRunSources: [.first],
                thirdOutClassification: nil
            ),
            .init(
                batter: batter,
                battingOrderSize: 10,
                result: .sacrificeBunt,
                movements: [
                    .init(source: .first, destination: .out),
                    .init(source: .batter, destination: .out)
                ],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )
        ]

        for candidate in illegalCandidates {
            #expect(throws: GameEventCorrectionError.offensivePlateAppearanceNotEditable) {
                _ = try GameEventCorrection.stageOffensivePlateAppearanceEdit(
                    candidate,
                    in: editSession,
                    game: game,
                    modelContext: context
                )
            }
        }
        let stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(try stored.map { try $0.decoded().body } == records.map { try $0.decoded().body })

    }

    @Test func trackedTeamPlateAppearanceEditRejectsWrongGameStaleSessionAndFailuresAtomically() throws {
        struct ProjectionFailure: Error {}
        struct SaveFailure: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let otherGame = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let original = OffensivePlateAppearanceEvent(
            batter: batter,
            battingOrderSize: 10,
            result: .single,
            movements: [.init(source: .batter, destination: .first)],
            rbi: 0,
            countedRunSources: [],
            thirdOutClassification: nil
        )
        let record = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .offensivePlateAppearance(original)
        )
        context.insert(record)
        try context.save()
        let editSession = try GameEventCorrection.prepareOffensivePlateAppearanceEdit(
            recordID: record.id,
            game: game,
            modelContext: context
        )
        let proposed = OffensivePlateAppearanceEvent(
            batter: batter,
            battingOrderSize: 10,
            result: .reachedOnError,
            movements: [.init(source: .batter, destination: .first)],
            rbi: 0,
            countedRunSources: [],
            thirdOutClassification: nil
        )

        #expect(throws: GameEventCorrectionError.gameMismatch) {
            _ = try GameEventCorrection.stageOffensivePlateAppearanceEdit(
                proposed,
                in: editSession,
                game: otherGame,
                modelContext: context
            )
        }
        #expect(throws: ProjectionFailure.self) {
            _ = try GameEventCorrection.stageOffensivePlateAppearanceEdit(
                proposed,
                in: editSession,
                game: game,
                modelContext: context,
                projectBattingLines: { _ in throw ProjectionFailure() }
            )
        }
        let staged = try GameEventCorrection.stageOffensivePlateAppearanceEdit(
            proposed,
            in: editSession,
            game: game,
            modelContext: context
        )
        #expect(throws: SaveFailure.self) {
            _ = try GameEventCorrection.saveGameEventCorrection(
                staged,
                game: game,
                modelContext: context,
                save: { _ in throw SaveFailure() }
            )
        }
        let afterFailedSave = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
        #expect(afterFailedSave.count == 1)
        #expect(try afterFailedSave[0].decoded().body == .offensivePlateAppearance(original))

        let newer = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .offensivePitch(.init(
                batter: makeTrackedBatter(
                    displayName: "Jordan Lee",
                    jerseyNumber: "12",
                    position: .centerField,
                    lineupSlot: 2
                ),
                battingOrderSize: 10,
                result: .ball
            ))
        )
        context.insert(newer)
        try context.save()
        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.stageOffensivePlateAppearanceEdit(
                proposed,
                in: editSession,
                game: game,
                modelContext: context
            )
        }
        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.saveGameEventCorrection(
                staged,
                game: game,
                modelContext: context
            )
        }
        let stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stored.map(\.id) == [record.id, newer.id])
        #expect(try stored[0].decoded().body == .offensivePlateAppearance(original))
    }

    private func twoConsecutiveSingles(pitcherID: UUID) -> [GameEventBody] {
        [
            .pitch(.init(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 1)),
            .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            )),
            .pitch(.init(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 2)),
            .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 2,
                movements: [
                    .init(source: .first, destination: .second),
                    .init(source: .batter, destination: .first)
                ],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        ]
    }

    private func defensiveBallInPlayRecords(
        for plays: [BallInPlayEvent],
        gameID: UUID,
        pitcherID: UUID
    ) throws -> [GameEventRecord] {
        try plays.enumerated().flatMap { index, play in
            let pitchSequence = index * 2 + 1
            return [
                try GameEventRecord(
                    gameID: gameID,
                    sequenceNumber: pitchSequence,
                    body: .pitch(.init(
                        result: .ballInPlay,
                        pitcherID: pitcherID,
                        opponentBatterSlot: play.opponentBatterSlot
                    ))
                ),
                try GameEventRecord(
                    gameID: gameID,
                    sequenceNumber: pitchSequence + 1,
                    body: .ballInPlay(play)
                )
            ]
        }
    }

    private func seedCompletedSingle(
        game: Game,
        modelContext: ModelContext
    ) throws -> [GameEventRecord] {
        let pitcherID = try #require(game.startingPitcherID)
        let records = try [
            GameEventBody.pitch(.init(
                result: .ballInPlay,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            )),
            .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(modelContext.insert)
        try modelContext.save()
        return records
    }

    private func makeOffensiveGame(id: UUID = UUID()) -> Game {
        Game(
            id: id,
            seasonID: UUID(),
            opponentName: "Thunder",
            homeAway: .away,
            status: .inProgress,
            startingPitcherID: UUID()
        )
    }

    private func makeTrackedBatter(
        playerID: UUID = UUID(),
        displayName: String = "Avery Stone",
        jerseyNumber: String = "8",
        position: DefensivePosition = .shortstop,
        lineupSlot: Int = 1
    ) -> TrackedBatterIdentity {
        TrackedBatterIdentity(
            playerID: playerID,
            lineupSlot: lineupSlot,
            displayName: displayName,
            jerseyNumber: jerseyNumber,
            position: position
        )
    }

    private func seedOffensivePitches(
        _ results: [OffensivePitchResult],
        sequences: [Int]? = nil,
        game: Game,
        batter: TrackedBatterIdentity,
        battingOrderSize: Int = 10,
        modelContext: ModelContext
    ) throws -> [GameEventRecord] {
        let sequenceNumbers = sequences ?? results.indices.map { $0 + 1 }
        let records = try zip(sequenceNumbers, results).map { sequence, result in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: sequence,
                body: .offensivePitch(.init(
                    batter: batter,
                    battingOrderSize: battingOrderSize,
                    result: result
                ))
            )
        }
        records.forEach(modelContext.insert)
        try modelContext.save()
        return records
    }

    private func seedStolenBaseUndoTimeline(
        game: Game,
        modelContext: ModelContext
    ) throws -> (
        records: [GameEventRecord],
        runner: TrackedBatterIdentity,
        activeBatter: TrackedBatterIdentity
    ) {
        let runner = makeTrackedBatter()
        let activeBatter = makeTrackedBatter(
            displayName: "Jordan Lee",
            jerseyNumber: "12",
            position: .centerField,
            lineupSlot: 2
        )
        let records = try [
            GameEventBody.offensivePlateAppearance(.init(
                batter: runner,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePitch(.init(
                batter: activeBatter,
                battingOrderSize: 10,
                result: .ball
            )),
            .offensiveBaseRunning(.init(
                runnerID: runner.playerID,
                source: .first,
                destination: .second,
                result: .stolenBase
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(modelContext.insert)
        try modelContext.save()
        return (records, runner, activeBatter)
    }

    private func makeGame() -> Game {
        Game(
            seasonID: UUID(),
            opponentName: "Thunder",
            homeAway: .home,
            status: .inProgress,
            startingPitcherID: UUID()
        )
    }
}
