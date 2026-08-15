import Foundation

enum InningHalf: String, Codable, Sendable {
    case top
    case bottom

    var displayName: String { self == .top ? "Top" : "Bottom" }
}

struct PitchCount: Equatable, Sendable {
    var total: Int = 0
    var balls: Int = 0
    var strikes: Int = 0

    var strikePercentage: Double {
        guard total > 0 else { return 0 }
        return Double(strikes) / Double(total)
    }

    var unclassified: Int {
        total - balls - strikes
    }

    func reconciling(_ reconciliation: PitchCountReconciliationEvent) -> PitchCount? {
        let (resultingTotal, totalOverflow) = total.addingReportingOverflow(
            reconciliation.adjustment.total
        )
        let (resultingBalls, ballOverflow) = balls.addingReportingOverflow(
            reconciliation.adjustment.balls
        )
        let (resultingStrikes, strikeOverflow) = strikes.addingReportingOverflow(
            reconciliation.adjustment.strikes
        )
        guard !totalOverflow, !ballOverflow, !strikeOverflow else { return nil }
        let reconciled = PitchCount(
            total: resultingTotal,
            balls: resultingBalls,
            strikes: resultingStrikes
        )
        let (classified, classifiedOverflow) = reconciled.balls.addingReportingOverflow(
            reconciled.strikes
        )
        guard reconciled.total >= 0,
              reconciled.balls >= 0,
              reconciled.strikes >= 0,
              !classifiedOverflow,
              classified <= reconciled.total else {
            return nil
        }
        return reconciled
    }
}

struct OffensiveCountContext: Equatable, Sendable {
    let batter: TrackedBatterIdentity
    let battingOrderSize: Int

    func matches(batter: TrackedBatterIdentity, battingOrderSize: Int) -> Bool {
        self.batter == batter && self.battingOrderSize == battingOrderSize
    }
}

struct GameState: Equatable, Sendable {
    var inning: Int = 1
    var half: InningHalf = .top
    var outs: Int = 0
    var balls: Int = 0
    var strikes: Int = 0
    var homeScore: Int = 0
    var awayScore: Int = 0

    /// Opponent batting order is deliberately lightweight in the MVP.
    /// Slots rotate 1...9 and can later be associated with opponent names.
    var currentOpponentBatterSlot: Int = 1

    /// One-based slot in the tracked team's persisted batting order.
    var currentTrackedBatterSlot: Int = 1

    /// Event-time identity owning the active offensive count. This prevents a later lineup edit
    /// or crafted event from completing another player's plate appearance on the same slot.
    var offensiveCountContext: OffensiveCountContext?

    var firstBaseRunnerSlot: Int?
    var secondBaseRunnerSlot: Int?
    var thirdBaseRunnerSlot: Int?

    var firstBaseRunnerPlayerID: UUID?
    var secondBaseRunnerPlayerID: UUID?
    var thirdBaseRunnerPlayerID: UUID?

    /// A ball-in-play pitch is counted immediately, then the play result completes the PA.
    /// While this is true, no additional pitch may be recorded.
    var isAwaitingBallInPlayResult = false

    var pitchCountsByPitcher: [UUID: PitchCount] = [:]

    var baseRunnerSlots: [Int?] {
        [firstBaseRunnerSlot, secondBaseRunnerSlot, thirdBaseRunnerSlot]
    }

    var trackedBaseRunnerPlayerIDs: [UUID?] {
        [firstBaseRunnerPlayerID, secondBaseRunnerPlayerID, thirdBaseRunnerPlayerID]
    }

    func trackedRunnerPlayerID(for source: RunnerSource, batterID: UUID) -> UUID? {
        switch source {
        case .batter: batterID
        case .first: firstBaseRunnerPlayerID
        case .second: secondBaseRunnerPlayerID
        case .third: thirdBaseRunnerPlayerID
        }
    }

    var occupiedTrackedRunnerSources: [RunnerSource] {
        var result: [RunnerSource] = [.batter]
        if firstBaseRunnerPlayerID != nil { result.append(.first) }
        if secondBaseRunnerPlayerID != nil { result.append(.second) }
        if thirdBaseRunnerPlayerID != nil { result.append(.third) }
        return result
    }

    func pitchCount(for pitcherID: UUID) -> PitchCount {
        pitchCountsByPitcher[pitcherID, default: PitchCount()]
    }

    func runnerSlot(for source: RunnerSource) -> Int? {
        switch source {
        case .batter: currentOpponentBatterSlot
        case .first: firstBaseRunnerSlot
        case .second: secondBaseRunnerSlot
        case .third: thirdBaseRunnerSlot
        }
    }

    var occupiedRunnerSources: [RunnerSource] {
        var result: [RunnerSource] = [.batter]
        if firstBaseRunnerSlot != nil { result.append(.first) }
        if secondBaseRunnerSlot != nil { result.append(.second) }
        if thirdBaseRunnerSlot != nil { result.append(.third) }
        return result
    }

    func isTrackedTeamBatting(homeAway: HomeAway) -> Bool {
        switch (half, homeAway) {
        case (.top, .away), (.bottom, .home): true
        default: false
        }
    }

    func isOpponentBatting(homeAway: HomeAway) -> Bool {
        !isTrackedTeamBatting(homeAway: homeAway)
    }
}

struct OffensiveMovementSuggestion: Equatable, Sendable {
    let movements: [RunnerMovementEvent]
    let rbi: Int
    let countedRunSources: [RunnerSource]
}

enum OffensiveMovementSuggestions {
    static func awardedFirstBase(state: GameState) -> OffensiveMovementSuggestion {
        let firstOccupied = state.firstBaseRunnerPlayerID != nil
        let secondOccupied = state.secondBaseRunnerPlayerID != nil
        let basesLoaded = firstOccupied && secondOccupied && state.thirdBaseRunnerPlayerID != nil
        var movements = [RunnerMovementEvent(source: .batter, destination: .first)]

        if firstOccupied {
            movements.append(.init(source: .first, destination: .second))
        }
        if secondOccupied {
            movements.append(.init(source: .second, destination: firstOccupied ? .third : .second))
        }
        if state.thirdBaseRunnerPlayerID != nil {
            movements.append(.init(source: .third, destination: basesLoaded ? .home : .third))
        }

        return OffensiveMovementSuggestion(
            movements: movements,
            rbi: basesLoaded ? 1 : 0,
            countedRunSources: basesLoaded ? [.third] : []
        )
    }

    static func homeRun(state: GameState) -> OffensiveMovementSuggestion {
        let sources = state.occupiedTrackedRunnerSources
        return OffensiveMovementSuggestion(
            movements: sources.map { .init(source: $0, destination: .home) },
            rbi: sources.count,
            countedRunSources: sources
        )
    }

    static func strikeout(state: GameState) -> OffensiveMovementSuggestion {
        OffensiveMovementSuggestion(
            movements: state.occupiedTrackedRunnerSources.map { source in
                .init(source: source, destination: source == .batter ? .out : heldBase(for: source))
            },
            rbi: 0,
            countedRunSources: []
        )
    }

    static func ballInPlay(
        _ outcome: BallInPlayOutcome,
        state: GameState
    ) -> OffensiveMovementSuggestion {
        var destinations: [RunnerSource: RunnerDestination] = [:]
        for source in state.occupiedTrackedRunnerSources {
            destinations[source] = source == .batter
                ? outcome.suggestedBatterDestination
                : heldBase(for: source)
        }

        switch outcome {
        case .single:
            if state.firstBaseRunnerPlayerID != nil { destinations[.first] = .second }
            if state.secondBaseRunnerPlayerID != nil { destinations[.second] = .home }
            if state.thirdBaseRunnerPlayerID != nil { destinations[.third] = .home }
        case .double:
            if state.firstBaseRunnerPlayerID != nil { destinations[.first] = .third }
            if state.secondBaseRunnerPlayerID != nil { destinations[.second] = .home }
            if state.thirdBaseRunnerPlayerID != nil { destinations[.third] = .home }
        case .triple, .homeRun:
            for source in state.occupiedTrackedRunnerSources where source != .batter {
                destinations[source] = .home
            }
        case .reachedOnError, .fieldersChoice:
            if state.firstBaseRunnerPlayerID != nil {
                destinations[.first] = .second
                if state.secondBaseRunnerPlayerID != nil {
                    destinations[.second] = .third
                    if state.thirdBaseRunnerPlayerID != nil { destinations[.third] = .home }
                }
            }
        case .sacrificeFly:
            if state.thirdBaseRunnerPlayerID != nil { destinations[.third] = .home }
        case .doublePlay:
            if state.firstBaseRunnerPlayerID != nil { destinations[.first] = .out }
            else if state.secondBaseRunnerPlayerID != nil { destinations[.second] = .out }
            else if state.thirdBaseRunnerPlayerID != nil { destinations[.third] = .out }
        case .groundOut, .flyOut, .lineOut, .popOut, .sacrificeBunt:
            break
        }

        let movements: [RunnerMovementEvent] = state.occupiedTrackedRunnerSources.compactMap { source in
            destinations[source].map { RunnerMovementEvent(source: source, destination: $0) }
        }
        let countedRunSources: [RunnerSource] = movements
            .filter { $0.destination == RunnerDestination.home }
            .map(\.source)
        return OffensiveMovementSuggestion(
            movements: movements,
            rbi: outcome == .reachedOnError ? 0 : countedRunSources.count,
            countedRunSources: countedRunSources
        )
    }

    private static func heldBase(for source: RunnerSource) -> RunnerDestination {
        switch source {
        case .batter: .out
        case .first: .first
        case .second: .second
        case .third: .third
        }
    }
}
