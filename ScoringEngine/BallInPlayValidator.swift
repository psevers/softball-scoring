import Foundation

enum BallInPlayValidationError: Error, Equatable, Sendable {
    case notDefensiveHalf
    case noPendingBallInPlay
    case batterMismatch
    case missingRunner(RunnerSource)
    case unexpectedRunner(RunnerSource)
    case duplicateRunner(RunnerSource)
    case illegalDestination(RunnerSource, RunnerDestination)
    case baseCollision(RunnerDestination)
    case tooManyOuts
    case outcomeMismatch
    case invalidRBI
    case missingThirdOutRunCount
    case missingThirdOutClassification
    case invalidThirdOutRunCount
    case unnecessaryThirdOutRunCount
    case unnecessaryThirdOutClassification
}

enum BallInPlayValidator {
    static func validate(
        _ play: BallInPlayEvent,
        state: GameState,
        trackedTeamHomeAway: HomeAway
    ) -> BallInPlayValidationError? {
        guard state.isOpponentBatting(homeAway: trackedTeamHomeAway) else { return .notDefensiveHalf }
        guard state.isAwaitingBallInPlayResult else { return .noPendingBallInPlay }
        guard play.opponentBatterSlot == state.currentOpponentBatterSlot else { return .batterMismatch }
        guard play.rbi >= 0 && play.rbi <= 4 else { return .invalidRBI }

        let expectedSources = Set(state.occupiedRunnerSources)
        let movementSources = play.movements.map(\.source)
        let actualSources = Set(movementSources)

        for source in expectedSources where !actualSources.contains(source) {
            return .missingRunner(source)
        }
        for source in actualSources where !expectedSources.contains(source) {
            return .unexpectedRunner(source)
        }
        if movementSources.count != actualSources.count {
            let counts = Dictionary(grouping: movementSources, by: { $0 })
            if let duplicate = counts.first(where: { $0.value.count > 1 })?.key {
                return .duplicateRunner(duplicate)
            }
        }

        for movement in play.movements {
            if !isLegalMovement(movement) {
                return .illegalDestination(movement.source, movement.destination)
            }
        }

        let occupiedFinalBases = play.movements.compactMap { movement -> RunnerDestination? in
            switch movement.destination {
            case .first, .second, .third: movement.destination
            case .home, .out: nil
            }
        }
        if Set(occupiedFinalBases).count != occupiedFinalBases.count,
           let collision = Dictionary(grouping: occupiedFinalBases, by: { $0 })
            .first(where: { $0.value.count > 1 })?.key {
            return .baseCollision(collision)
        }

        if let trailingRunner = runnerThatPassedAnotherRunner(in: play.movements) {
            return .illegalDestination(trailingRunner.source, trailingRunner.destination)
        }

        let outsOnPlay = play.movements.filter { $0.destination == .out }.count
        guard state.outs + outsOnPlay <= 3 else { return .tooManyOuts }
        if state.outs == 2 && (play.outcome == .sacrificeBunt || play.outcome == .sacrificeFly) {
            return .outcomeMismatch
        }

        guard outcomeMatches(play.outcome, movements: play.movements, outsOnPlay: outsOnPlay) else {
            return .outcomeMismatch
        }

        let runsOnPlay = play.movements.filter { $0.destination == .home }.count
        let createsThirdOut = state.outs < 3 && state.outs + outsOnPlay == 3
        let countedRuns: Int
        if createsThirdOut && runsOnPlay > 0 {
            guard let thirdOutRunsCounted = play.thirdOutRunsCounted else { return .missingThirdOutRunCount }
            guard let classification = play.thirdOutClassification else { return .missingThirdOutClassification }
            guard (0...runsOnPlay).contains(thirdOutRunsCounted) else { return .invalidThirdOutRunCount }
            if classification == .forceOrBatterRunner, thirdOutRunsCounted != 0 {
                return .invalidThirdOutRunCount
            }
            if classification == .timingPlay,
               outsOnPlay == 1,
               play.movements.first(where: { $0.source == .batter })?.destination == .out,
               [.groundOut, .flyOut, .lineOut, .popOut].contains(play.outcome) {
                return .invalidThirdOutRunCount
            }
            countedRuns = thirdOutRunsCounted
        } else {
            guard play.thirdOutRunsCounted == nil else { return .unnecessaryThirdOutRunCount }
            guard play.thirdOutClassification == nil else { return .unnecessaryThirdOutClassification }
            countedRuns = runsOnPlay
        }
        guard play.rbi <= countedRuns else { return .invalidRBI }

        return nil
    }

    private static func isLegalMovement(_ movement: RunnerMovementEvent) -> Bool {
        switch movement.source {
        case .batter:
            return true
        case .first:
            return true // Holding at 1B or advancing is legal.
        case .second:
            return movement.destination != .first
        case .third:
            return movement.destination != .first && movement.destination != .second
        }
    }

    private static func outcomeMatches(
        _ outcome: BallInPlayOutcome,
        movements: [RunnerMovementEvent],
        outsOnPlay: Int
    ) -> Bool {
        guard let batter = movements.first(where: { $0.source == .batter }) else { return false }

        switch outcome {
        case .single:
            return [.first, .second, .third, .home, .out].contains(batter.destination)
        case .double:
            return [.second, .third, .home, .out].contains(batter.destination)
        case .triple:
            return [.third, .home, .out].contains(batter.destination)
        case .homeRun:
            return batter.destination == .home
                && outsOnPlay == 0
                && movements.allSatisfy { $0.destination == .home }
        case .reachedOnError, .fieldersChoice:
            return [.first, .second, .third, .home, .out].contains(batter.destination)
        case .groundOut, .flyOut, .lineOut, .popOut:
            return batter.destination == .out && outsOnPlay >= 1
        case .sacrificeFly:
            return batter.destination == .out
                && outsOnPlay >= 1
                && movements.contains { $0.source != .batter && $0.destination == .home }
        case .sacrificeBunt:
            return batter.destination == .out
                && outsOnPlay >= 1
                && movements.contains(where: didExistingRunnerAdvance)
        case .doublePlay:
            return outsOnPlay == 2
        }
    }

    private static func didExistingRunnerAdvance(_ movement: RunnerMovementEvent) -> Bool {
        switch (movement.source, movement.destination) {
        case (.first, .second), (.first, .third), (.first, .home),
             (.second, .third), (.second, .home),
             (.third, .home):
            true
        default:
            false
        }
    }

    private static func runnerThatPassedAnotherRunner(
        in movements: [RunnerMovementEvent]
    ) -> RunnerMovementEvent? {
        let activeMovements = movements.filter { $0.destination != .out }

        for trailing in activeMovements {
            for leading in activeMovements where sourceOrder(trailing.source) < sourceOrder(leading.source) {
                if trailing.destination == .home && leading.destination == .home {
                    continue
                }
                if destinationOrder(trailing.destination) >= destinationOrder(leading.destination) {
                    return trailing
                }
            }
        }
        return nil
    }

    private static func sourceOrder(_ source: RunnerSource) -> Int {
        switch source {
        case .batter: 0
        case .first: 1
        case .second: 2
        case .third: 3
        }
    }

    private static func destinationOrder(_ destination: RunnerDestination) -> Int {
        switch destination {
        case .first: 1
        case .second: 2
        case .third: 3
        case .home: 4
        case .out: 5
        }
    }
}
