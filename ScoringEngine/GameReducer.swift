import Foundation

enum GameReducer {
    static func apply(
        _ event: DecodedGameEvent,
        to state: inout GameState,
        trackedTeamHomeAway: HomeAway
    ) {
        switch event.body {
        case .pitch(let pitch):
            applyPitch(pitch, to: &state, trackedTeamHomeAway: trackedTeamHomeAway)
        case .pitchCountReconciliation(let reconciliation):
            guard let count = state.pitchCount(for: reconciliation.pitcherID)
                .reconciling(reconciliation) else { return }
            state.pitchCountsByPitcher[reconciliation.pitcherID] = count
        case .ballInPlay(let play):
            applyBallInPlay(play, to: &state, trackedTeamHomeAway: trackedTeamHomeAway)
        case .offensivePitch(let pitch):
            applyOffensivePitch(pitch, to: &state, trackedTeamHomeAway: trackedTeamHomeAway)
        case .offensiveBaseRunning(let event):
            applyOffensiveBaseRunning(event, to: &state, trackedTeamHomeAway: trackedTeamHomeAway)
        case .offensivePlateAppearance(let plateAppearance):
            applyOffensivePlateAppearance(
                plateAppearance,
                to: &state,
                trackedTeamHomeAway: trackedTeamHomeAway
            )
        }
    }

    private static func applyOffensiveBaseRunning(
        _ event: OffensiveBaseRunningEvent,
        to state: inout GameState,
        trackedTeamHomeAway: HomeAway
    ) {
        guard OffensiveBaseRunningValidator.isValid(
            event,
            state: state,
            trackedTeamHomeAway: trackedTeamHomeAway
        ) else {
            return
        }

        switch event.source {
        case .batter: return
        case .first: state.firstBaseRunnerPlayerID = nil
        case .second: state.secondBaseRunnerPlayerID = nil
        case .third: state.thirdBaseRunnerPlayerID = nil
        }

        switch event.destination {
        case .first: state.firstBaseRunnerPlayerID = event.runnerID
        case .second: state.secondBaseRunnerPlayerID = event.runnerID
        case .third: state.thirdBaseRunnerPlayerID = event.runnerID
        case .home:
            scoreTrackedTeamRun(state: &state, trackedTeamHomeAway: trackedTeamHomeAway)
        case .out:
            state.outs += 1
            if state.outs >= 3 { advanceHalfInning(state: &state) }
        }
    }

    private static func applyOffensivePitch(
        _ pitch: OffensivePitchEvent,
        to state: inout GameState,
        trackedTeamHomeAway: HomeAway
    ) {
        guard OffensivePitchValidator.isValid(
            pitch,
            state: state,
            trackedTeamHomeAway: trackedTeamHomeAway
        ) else {
            return
        }

        switch pitch.result {
        case .ball:
            state.balls += 1
        case .calledStrike, .swingingStrike:
            state.strikes += 1
        case .foul:
            if state.strikes < 2 { state.strikes += 1 }
        }
        if state.offensiveCountContext == nil {
            state.offensiveCountContext = OffensiveCountContext(
                batter: pitch.batter,
                battingOrderSize: pitch.battingOrderSize
            )
        }
    }

    private static func applyOffensivePlateAppearance(
        _ plateAppearance: OffensivePlateAppearanceEvent,
        to state: inout GameState,
        trackedTeamHomeAway: HomeAway
    ) {
        guard OffensivePlateAppearanceValidator.isValid(
            plateAppearance,
            state: state,
            trackedTeamHomeAway: trackedTeamHomeAway
        ) else {
            return
        }

        let runnerIDs: [RunnerSource: UUID] = Dictionary(
            uniqueKeysWithValues: state.occupiedTrackedRunnerSources.compactMap { source in
                state.trackedRunnerPlayerID(
                    for: source,
                    batterID: plateAppearance.batter.playerID
                ).map { (source, $0) }
            }
        )

        state.firstBaseRunnerPlayerID = nil
        state.secondBaseRunnerPlayerID = nil
        state.thirdBaseRunnerPlayerID = nil
        for movement in plateAppearance.movements {
            guard let runnerID = runnerIDs[movement.source] else { continue }
            switch movement.destination {
            case .first: state.firstBaseRunnerPlayerID = runnerID
            case .second: state.secondBaseRunnerPlayerID = runnerID
            case .third: state.thirdBaseRunnerPlayerID = runnerID
            case .home, .out: break
            }
        }

        for _ in plateAppearance.countedRunSources {
            scoreTrackedTeamRun(state: &state, trackedTeamHomeAway: trackedTeamHomeAway)
        }
        state.outs += plateAppearance.movements.filter { $0.destination == .out }.count
        state.balls = 0
        state.strikes = 0
        state.offensiveCountContext = nil
        state.currentTrackedBatterSlot = state.currentTrackedBatterSlot == plateAppearance.battingOrderSize
            ? 1
            : state.currentTrackedBatterSlot + 1

        if state.outs >= 3 {
            advanceHalfInning(state: &state)
        }
    }

    private static func applyPitch(
        _ pitch: PitchEvent,
        to state: inout GameState,
        trackedTeamHomeAway: HomeAway
    ) {
        guard state.isOpponentBatting(homeAway: trackedTeamHomeAway),
              !state.isAwaitingBallInPlayResult,
              pitch.opponentBatterSlot == state.currentOpponentBatterSlot else { return }

        var count = state.pitchCountsByPitcher[pitch.pitcherID, default: PitchCount()]
        count.total += 1
        switch pitch.result.pitchStatClassification {
        case .ball: count.balls += 1
        case .strike: count.strikes += 1
        case .neither: break
        }
        state.pitchCountsByPitcher[pitch.pitcherID] = count

        switch pitch.result {
        case .ball:
            if state.balls == 3 {
                completeAwardedFirstBase(
                    batterSlot: pitch.opponentBatterSlot,
                    state: &state,
                    trackedTeamHomeAway: trackedTeamHomeAway
                )
            } else {
                state.balls += 1
            }

        case .calledStrike, .swingingStrike:
            if state.strikes == 2 {
                completeStrikeout(state: &state)
            } else {
                state.strikes += 1
            }

        case .foul:
            if state.strikes < 2 { state.strikes += 1 }

        case .ballInPlay:
            state.isAwaitingBallInPlayResult = true

        case .hitByPitch:
            completeAwardedFirstBase(
                batterSlot: pitch.opponentBatterSlot,
                state: &state,
                trackedTeamHomeAway: trackedTeamHomeAway
            )
        }
    }

    private static func applyBallInPlay(
        _ play: BallInPlayEvent,
        to state: inout GameState,
        trackedTeamHomeAway: HomeAway
    ) {
        guard BallInPlayValidator.validate(play, state: state, trackedTeamHomeAway: trackedTeamHomeAway) == nil else {
            return
        }

        let runnerSlots: [RunnerSource: Int] = Dictionary(
            uniqueKeysWithValues: state.occupiedRunnerSources.compactMap { source in
                state.runnerSlot(for: source).map { (source, $0) }
            }
        )

        state.firstBaseRunnerSlot = nil
        state.secondBaseRunnerSlot = nil
        state.thirdBaseRunnerSlot = nil

        let outsOnPlay = play.movements.filter { $0.destination == .out }.count
        let homeTouches = play.movements.filter { $0.destination == .home }.count
        let createsThirdOut = state.outs + outsOnPlay == 3
        let runsToCount = createsThirdOut ? (play.thirdOutRunsCounted ?? 0) : homeTouches

        for movement in play.movements {
            guard let slot = runnerSlots[movement.source] else { continue }
            switch movement.destination {
            case .first: state.firstBaseRunnerSlot = slot
            case .second: state.secondBaseRunnerSlot = slot
            case .third: state.thirdBaseRunnerSlot = slot
            case .home: break
            case .out: break
            }
        }

        for _ in 0..<runsToCount {
            scoreOpponentRun(state: &state, trackedTeamHomeAway: trackedTeamHomeAway)
        }

        state.outs += outsOnPlay
        state.isAwaitingBallInPlayResult = false
        completePlateAppearance(state: &state)

        if state.outs >= 3 {
            advanceHalfInning(state: &state)
        }
    }

    private static func completeStrikeout(state: inout GameState) {
        state.outs += 1
        completePlateAppearance(state: &state)

        if state.outs >= 3 { advanceHalfInning(state: &state) }
    }

    private static func completeAwardedFirstBase(
        batterSlot: Int,
        state: inout GameState,
        trackedTeamHomeAway: HomeAway
    ) {
        if let first = state.firstBaseRunnerSlot {
            if let second = state.secondBaseRunnerSlot {
                if state.thirdBaseRunnerSlot != nil {
                    scoreOpponentRun(state: &state, trackedTeamHomeAway: trackedTeamHomeAway)
                }
                state.thirdBaseRunnerSlot = second
            }
            state.secondBaseRunnerSlot = first
        }
        state.firstBaseRunnerSlot = batterSlot
        completePlateAppearance(state: &state)
    }

    private static func completePlateAppearance(state: inout GameState) {
        state.balls = 0
        state.strikes = 0
        state.currentOpponentBatterSlot = state.currentOpponentBatterSlot == 9 ? 1 : state.currentOpponentBatterSlot + 1
    }

    private static func scoreOpponentRun(state: inout GameState, trackedTeamHomeAway: HomeAway) {
        if trackedTeamHomeAway == .home { state.awayScore += 1 }
        else { state.homeScore += 1 }
    }

    private static func scoreTrackedTeamRun(state: inout GameState, trackedTeamHomeAway: HomeAway) {
        if trackedTeamHomeAway == .home { state.homeScore += 1 }
        else { state.awayScore += 1 }
    }

    private static func advanceHalfInning(state: inout GameState) {
        state.outs = 0
        state.balls = 0
        state.strikes = 0
        state.firstBaseRunnerSlot = nil
        state.secondBaseRunnerSlot = nil
        state.thirdBaseRunnerSlot = nil
        state.firstBaseRunnerPlayerID = nil
        state.secondBaseRunnerPlayerID = nil
        state.thirdBaseRunnerPlayerID = nil
        state.isAwaitingBallInPlayResult = false
        state.offensiveCountContext = nil

        switch state.half {
        case .top: state.half = .bottom
        case .bottom:
            state.half = .top
            state.inning += 1
        }
    }
}
