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
        case .ballInPlay(let play):
            applyBallInPlay(play, to: &state, trackedTeamHomeAway: trackedTeamHomeAway)
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

    private static func advanceHalfInning(state: inout GameState) {
        state.outs = 0
        state.balls = 0
        state.strikes = 0
        state.firstBaseRunnerSlot = nil
        state.secondBaseRunnerSlot = nil
        state.thirdBaseRunnerSlot = nil
        state.isAwaitingBallInPlayResult = false

        switch state.half {
        case .top: state.half = .bottom
        case .bottom:
            state.half = .top
            state.inning += 1
        }
    }
}
