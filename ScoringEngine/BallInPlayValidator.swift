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
    case invalidRunCount
    case invalidRBI
    case missingThirdOutRunCount
    case missingThirdOutClassification
    case invalidThirdOutRunCount
    case unnecessaryThirdOutRunCount
    case unnecessaryThirdOutClassification
}

enum BallInPlayValidator {
    static let correctionOutcomes: [BallInPlayOutcome] = [
        .single, .double, .triple, .homeRun, .reachedOnError, .fieldersChoice,
        .groundOut, .flyOut, .lineOut, .popOut, .sacrificeBunt, .sacrificeFly,
        .doublePlay
    ]

    static func correctionOutcomes(for stateBefore: GameState) -> [BallInPlayOutcome] {
        correctionOutcomes.filter { outcome in
            stateBefore.outs + outcome.suggestedOuts <= 3
                && !(stateBefore.outs == 2 && [.sacrificeBunt, .sacrificeFly].contains(outcome))
        }
    }

    static func supportsCorrection(
        _ play: BallInPlayEvent,
        stateBefore _: GameState
    ) -> Bool {
        correctionOutcomes.contains(play.outcome)
    }

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

        if let trailingRunner = RunnerMovementRules.runnerThatPassedAnotherRunner(in: play.movements) {
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

}

enum OffensivePlateAppearanceValidator {
    static let correctionResults: [OffensivePlateAppearanceResult] = [
        .walk, .hitByPitch, .strikeout,
        .single, .double, .triple, .reachedOnError, .fieldersChoice,
        .groundOut, .flyOut, .lineOut, .popOut, .sacrificeBunt, .doublePlay
    ]

    static func correctionResults(for stateBefore: GameState) -> [OffensivePlateAppearanceResult] {
        correctionResults.filter { result in
            switch result {
            case .strikeout, .groundOut, .flyOut, .lineOut, .popOut, .sacrificeBunt:
                stateBefore.outs + 1 < 3
                    && (result != .sacrificeBunt || stateBefore.outs < 2)
            case .doublePlay:
                stateBefore.outs + 2 < 3
            case .walk, .hitByPitch, .single, .double, .triple, .reachedOnError, .fieldersChoice:
                true
            case .homeRun, .sacrificeFly:
                false
            }
        }
    }

    static func supportsCorrection(
        _ plateAppearance: OffensivePlateAppearanceEvent,
        stateBefore: GameState
    ) -> Bool {
        let outsOnPlay = plateAppearance.movements.filter { $0.destination == .out }.count
        return correctionResults.contains(plateAppearance.result)
            && plateAppearance.countedRunSources.isEmpty
            && plateAppearance.rbi == 0
            && plateAppearance.thirdOutClassification == nil
            && stateBefore.outs + outsOnPlay < 3
    }

    static func isValid(
        _ plateAppearance: OffensivePlateAppearanceEvent,
        state: GameState,
        trackedTeamHomeAway: HomeAway
    ) -> Bool {
        guard state.isTrackedTeamBatting(homeAway: trackedTeamHomeAway),
              plateAppearance.battingOrderSize > 0,
              (1...plateAppearance.battingOrderSize).contains(plateAppearance.batter.lineupSlot),
              plateAppearance.batter.lineupSlot == state.currentTrackedBatterSlot,
              state.offensiveCountContext?.matches(
                batter: plateAppearance.batter,
                battingOrderSize: plateAppearance.battingOrderSize
              ) != false,
              Set(plateAppearance.movements.map(\.source)) == Set(state.occupiedTrackedRunnerSources),
              plateAppearance.movements.count == state.occupiedTrackedRunnerSources.count,
              plateAppearance.rbi >= 0 else {
            return false
        }

        guard plateAppearance.movements.allSatisfy(isLegalMovement),
              hasNoFinalBaseCollision(plateAppearance.movements),
              RunnerMovementRules.runnerThatPassedAnotherRunner(in: plateAppearance.movements) == nil else {
            return false
        }

        let outsOnPlay = plateAppearance.movements.filter { $0.destination == .out }.count
        guard state.outs + outsOnPlay <= 3 else { return false }

        let homeSources = plateAppearance.movements
            .filter { $0.destination == .home }
            .map(\.source)
        guard Set(plateAppearance.countedRunSources).isSubset(of: Set(homeSources)),
              Set(plateAppearance.countedRunSources).count == plateAppearance.countedRunSources.count,
              plateAppearance.rbi <= plateAppearance.countedRunSources.count else {
            return false
        }

        let createsThirdOut = state.outs + outsOnPlay == 3
        if createsThirdOut && !homeSources.isEmpty {
            guard let classification = plateAppearance.thirdOutClassification else { return false }
            if classification == .forceOrBatterRunner && !plateAppearance.countedRunSources.isEmpty {
                return false
            }
            if classification == .timingPlay,
               outsOnPlay == 1,
               plateAppearance.movements.first(where: { $0.source == .batter })?.destination == .out,
               [.strikeout, .groundOut, .flyOut, .lineOut, .popOut].contains(plateAppearance.result) {
                return false
            }
        } else {
            guard plateAppearance.thirdOutClassification == nil,
                  Set(plateAppearance.countedRunSources) == Set(homeSources) else {
                return false
            }
        }

        guard let batterMovement = plateAppearance.movements.first(where: { $0.source == .batter }) else {
            return false
        }

        switch plateAppearance.result {
        case .walk, .hitByPitch:
            return batterMovement.destination == .first && outsOnPlay == 0
        case .homeRun:
            return plateAppearance.movements.allSatisfy { $0.destination == .home }
                && Set(plateAppearance.countedRunSources) == Set(plateAppearance.movements.map(\.source))
                && plateAppearance.countedRunSources.count == plateAppearance.movements.count
                && plateAppearance.rbi == plateAppearance.countedRunSources.count
        case .single:
            return [.first, .second, .third, .home, .out].contains(batterMovement.destination)
        case .double:
            return [.second, .third, .home, .out].contains(batterMovement.destination)
        case .triple:
            return [.third, .home, .out].contains(batterMovement.destination)
        case .reachedOnError, .fieldersChoice:
            return true
        case .strikeout, .groundOut, .flyOut, .lineOut, .popOut:
            return batterMovement.destination == .out && outsOnPlay >= 1
        case .sacrificeBunt:
            return state.outs < 2
                && batterMovement.destination == .out
                && plateAppearance.movements.contains(where: didExistingRunnerAdvance)
        case .sacrificeFly:
            return state.outs < 2
                && batterMovement.destination == .out
                && homeSources.contains(where: { $0 != .batter })
        case .doublePlay:
            return outsOnPlay == 2
        }
    }

    private static func isLegalMovement(_ movement: RunnerMovementEvent) -> Bool {
        switch movement.source {
        case .batter, .first:
            true
        case .second:
            movement.destination != .first
        case .third:
            movement.destination != .first && movement.destination != .second
        }
    }

    private static func hasNoFinalBaseCollision(_ movements: [RunnerMovementEvent]) -> Bool {
        let occupiedBases = movements.compactMap { movement -> RunnerDestination? in
            switch movement.destination {
            case .first, .second, .third: movement.destination
            case .home, .out: nil
            }
        }
        return Set(occupiedBases).count == occupiedBases.count
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
}

enum OffensivePitchValidator {
    static func isValid(
        _ pitch: OffensivePitchEvent,
        state: GameState,
        trackedTeamHomeAway: HomeAway
    ) -> Bool {
        guard state.isTrackedTeamBatting(homeAway: trackedTeamHomeAway),
              pitch.battingOrderSize > 0,
              (1...pitch.battingOrderSize).contains(pitch.batter.lineupSlot),
              pitch.batter.lineupSlot == state.currentTrackedBatterSlot,
              state.offensiveCountContext?.matches(
                batter: pitch.batter,
                battingOrderSize: pitch.battingOrderSize
              ) != false else {
            return false
        }

        switch pitch.result {
        case .ball:
            return state.balls < 3
        case .calledStrike, .swingingStrike:
            return state.strikes < 2
        case .foul:
            return true
        }
    }
}

enum OffensiveBaseRunningValidator {
    static func isValid(
        _ event: OffensiveBaseRunningEvent,
        state: GameState,
        trackedTeamHomeAway: HomeAway
    ) -> Bool {
        guard state.isTrackedTeamBatting(homeAway: trackedTeamHomeAway),
              event.source != .batter,
              runnerID(on: event.source, state: state) == event.runnerID else {
            return false
        }

        switch event.result {
        case .caughtStealing:
            return event.destination == .out && state.outs < 3
        case .stolenBase:
            guard event.destination == nextDestination(after: event.source) else { return false }
            switch event.destination {
            case .second: return state.secondBaseRunnerPlayerID == nil
            case .third: return state.thirdBaseRunnerPlayerID == nil
            case .home: return true
            case .first, .out: return false
            }
        }
    }

    private static func runnerID(on source: RunnerSource, state: GameState) -> UUID? {
        switch source {
        case .batter: nil
        case .first: state.firstBaseRunnerPlayerID
        case .second: state.secondBaseRunnerPlayerID
        case .third: state.thirdBaseRunnerPlayerID
        }
    }

    private static func nextDestination(after source: RunnerSource) -> RunnerDestination? {
        switch source {
        case .batter: nil
        case .first: .second
        case .second: .third
        case .third: .home
        }
    }
}

enum RunnerMovementRules {
    static func runnerThatPassedAnotherRunner(
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
