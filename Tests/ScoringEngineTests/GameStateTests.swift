import Foundation
import Testing
@testable import SoftballScoring

struct GameStateTests {
    private let pitcherID = UUID()

    @Test func initialStateStartsTopFirstWithEmptyCountAndBases() {
        let state = GameState()
        #expect(state.inning == 1)
        #expect(state.half == .top)
        #expect(state.outs == 0)
        #expect(state.balls == 0)
        #expect(state.strikes == 0)
        #expect(state.baseRunnerSlots.allSatisfy { $0 == nil })
        #expect(state.currentOpponentBatterSlot == 1)
        #expect(!state.isAwaitingBallInPlayResult)
    }

    @Test func fourthBallCompletesWalkResetsCountAndAdvancesBatter() {
        let state = replayPitches([.ball, .ball, .ball, .ball])
        #expect(state.balls == 0)
        #expect(state.strikes == 0)
        #expect(state.firstBaseRunnerSlot == 1)
        #expect(state.currentOpponentBatterSlot == 2)
        #expect(state.pitchCount(for: pitcherID) == PitchCount(total: 4, balls: 4, strikes: 0))
    }

    @Test func twoStrikeFoulDoesNotCreateStrikeoutButCountsAsStrikePitch() {
        let state = replayPitches([.calledStrike, .swingingStrike, .foul])
        #expect(state.strikes == 2)
        #expect(state.outs == 0)
        #expect(state.currentOpponentBatterSlot == 1)
        #expect(state.pitchCount(for: pitcherID) == PitchCount(total: 3, balls: 0, strikes: 3))
    }

    @Test func hitByPitchCountsAsPitchButNotBallOrStrikeAndAwardsFirst() {
        let state = replayPitches([.hitByPitch])
        #expect(state.firstBaseRunnerSlot == 1)
        #expect(state.currentOpponentBatterSlot == 2)
        #expect(state.pitchCount(for: pitcherID) == PitchCount(total: 1, balls: 0, strikes: 0))
    }

    @Test func loadedWalkAndHitByPitchForceOneRun() {
        for result in [PitchResult.ball, .hitByPitch] {
            var state = GameState()
            state.half = .top
            state.firstBaseRunnerSlot = 1
            state.secondBaseRunnerSlot = 2
            state.thirdBaseRunnerSlot = 3
            state.currentOpponentBatterSlot = 4
            state.balls = result == .ball ? 3 : 0

            GameReducer.apply(
                makePitchEvent(result, batterSlot: 4),
                to: &state,
                trackedTeamHomeAway: .home
            )

            #expect(state.awayScore == 1)
            #expect(state.firstBaseRunnerSlot == 4)
            #expect(state.secondBaseRunnerSlot == 1)
            #expect(state.thirdBaseRunnerSlot == 2)
        }
    }

    @Test func ballInPlayPitchCountsImmediatelyAndPausesPitching() {
        let state = replayPitches([.ball, .calledStrike, .ballInPlay])
        #expect(state.isAwaitingBallInPlayResult)
        #expect(state.balls == 1)
        #expect(state.strikes == 1)
        #expect(state.pitchCount(for: pitcherID) == PitchCount(total: 3, balls: 1, strikes: 2))
        #expect(state.currentOpponentBatterSlot == 1)
    }

    @Test func additionalPitchIsIgnoredWhileBallInPlayResultIsPending() {
        var state = replayPitches([.ballInPlay])
        let before = state
        GameReducer.apply(makePitchEvent(.ball, batterSlot: 1, sequence: 2), to: &state, trackedTeamHomeAway: .home)
        #expect(state == before)
    }

    @Test func singleWithEmptyBasesPutsBatterOnFirstAndCompletesPlateAppearance() {
        var state = replayPitches([.ballInPlay])
        applyPlay(
            BallInPlayEvent(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ),
            to: &state
        )

        #expect(state.firstBaseRunnerSlot == 1)
        #expect(state.currentOpponentBatterSlot == 2)
        #expect(state.balls == 0)
        #expect(state.strikes == 0)
        #expect(!state.isAwaitingBallInPlayResult)
    }

    @Test func doubleCanAdvanceRunnerFirstToThird() {
        var state = GameState()
        state.half = .top
        state.firstBaseRunnerSlot = 1
        state.currentOpponentBatterSlot = 2
        setPendingBallInPlay(on: &state, batterSlot: 2)

        let play = BallInPlayEvent(
            outcome: .double,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .second),
                .init(source: .first, destination: .third)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        )
        #expect(BallInPlayValidator.validate(play, state: state, trackedTeamHomeAway: .home) == nil)
        applyPlay(play, to: &state)

        #expect(state.secondBaseRunnerSlot == 2)
        #expect(state.thirdBaseRunnerSlot == 1)
        #expect(state.firstBaseRunnerSlot == nil)
    }

    @Test func grandSlamScoresFourAndClearsBases() {
        var state = GameState()
        state.half = .top
        state.firstBaseRunnerSlot = 1
        state.secondBaseRunnerSlot = 2
        state.thirdBaseRunnerSlot = 3
        state.currentOpponentBatterSlot = 4
        setPendingBallInPlay(on: &state, batterSlot: 4)

        let play = BallInPlayEvent(
            outcome: .homeRun,
            opponentBatterSlot: 4,
            movements: [
                .init(source: .batter, destination: .home),
                .init(source: .first, destination: .home),
                .init(source: .second, destination: .home),
                .init(source: .third, destination: .home)
            ],
            rbi: 4,
            thirdOutRunsCounted: nil
        )
        applyPlay(play, to: &state)

        #expect(state.awayScore == 4)
        #expect(state.baseRunnerSlots.allSatisfy { $0 == nil })
        #expect(state.currentOpponentBatterSlot == 5)
    }

    @Test func homeRunValidatesFromEveryStartingBaseState() {
        for occupancyMask in 0..<8 {
            var state = GameState()
            state.half = .top
            state.firstBaseRunnerSlot = occupancyMask & 1 == 0 ? nil : 1
            state.secondBaseRunnerSlot = occupancyMask & 2 == 0 ? nil : 2
            state.thirdBaseRunnerSlot = occupancyMask & 4 == 0 ? nil : 3
            state.currentOpponentBatterSlot = 4
            setPendingBallInPlay(on: &state, batterSlot: 4)

            let movements = state.occupiedRunnerSources.map {
                RunnerMovementEvent(source: $0, destination: .home)
            }
            let play = BallInPlayEvent(
                outcome: .homeRun,
                opponentBatterSlot: 4,
                movements: movements,
                rbi: movements.count,
                thirdOutRunsCounted: nil
            )

            #expect(
                BallInPlayValidator.validate(play, state: state, trackedTeamHomeAway: .home) == nil,
                "occupancy mask \(occupancyMask)"
            )
        }
    }

    @Test func validatorRejectsMissingUnexpectedAndDuplicateRunnerSources() {
        var state = GameState()
        state.half = .top
        state.firstBaseRunnerSlot = 1
        state.currentOpponentBatterSlot = 2
        setPendingBallInPlay(on: &state, batterSlot: 2)

        let missing = BallInPlayEvent(
            outcome: .single,
            opponentBatterSlot: 2,
            movements: [.init(source: .batter, destination: .first)],
            rbi: 0,
            thirdOutRunsCounted: nil
        )
        #expect(BallInPlayValidator.validate(missing, state: state, trackedTeamHomeAway: .home) == .missingRunner(.first))

        var emptyState = GameState()
        emptyState.half = .top
        setPendingBallInPlay(on: &emptyState, batterSlot: 1)
        let unexpected = BallInPlayEvent(
            outcome: .single,
            opponentBatterSlot: 1,
            movements: [
                .init(source: .batter, destination: .first),
                .init(source: .third, destination: .home)
            ],
            rbi: 1,
            thirdOutRunsCounted: nil
        )
        #expect(BallInPlayValidator.validate(unexpected, state: emptyState, trackedTeamHomeAway: .home) == .unexpectedRunner(.third))

        let duplicate = BallInPlayEvent(
            outcome: .single,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .first),
                .init(source: .first, destination: .second),
                .init(source: .first, destination: .third)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        )
        #expect(BallInPlayValidator.validate(duplicate, state: state, trackedTeamHomeAway: .home) == .duplicateRunner(.first))
    }

    @Test func runnerMayHoldAndCreditedHitBatterMayBeOut() {
        var state = GameState()
        state.half = .top
        state.firstBaseRunnerSlot = 1
        state.currentOpponentBatterSlot = 2
        setPendingBallInPlay(on: &state, batterSlot: 2)

        let play = BallInPlayEvent(
            outcome: .single,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .out),
                .init(source: .first, destination: .first)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        )

        #expect(BallInPlayValidator.validate(play, state: state, trackedTeamHomeAway: .home) == nil)
    }

    @Test func playCannotCreateMoreThanThreeOuts() {
        var state = GameState()
        state.half = .top
        state.outs = 2
        state.firstBaseRunnerSlot = 1
        state.currentOpponentBatterSlot = 2
        setPendingBallInPlay(on: &state, batterSlot: 2)

        let play = BallInPlayEvent(
            outcome: .doublePlay,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .out),
                .init(source: .first, destination: .out)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        )

        #expect(BallInPlayValidator.validate(play, state: state, trackedTeamHomeAway: .home) == .tooManyOuts)
    }

    @Test func representativeTripleErrorOutAndSacrificeBuntOutcomesValidate() {
        for (outcome, destination) in [
            (BallInPlayOutcome.triple, RunnerDestination.third),
            (.reachedOnError, .first),
            (.lineOut, .out),
            (.popOut, .out)
        ] {
            var state = GameState()
            state.half = .top
            setPendingBallInPlay(on: &state, batterSlot: 1)
            let play = BallInPlayEvent(
                outcome: outcome,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: destination)],
                rbi: 0,
                thirdOutRunsCounted: nil
            )
            #expect(BallInPlayValidator.validate(play, state: state, trackedTeamHomeAway: .home) == nil)
        }

        var sacrificeState = GameState()
        sacrificeState.half = .top
        sacrificeState.firstBaseRunnerSlot = 1
        sacrificeState.currentOpponentBatterSlot = 2
        setPendingBallInPlay(on: &sacrificeState, batterSlot: 2)
        let sacrifice = BallInPlayEvent(
            outcome: .sacrificeBunt,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .out),
                .init(source: .first, destination: .second)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        )
        #expect(BallInPlayValidator.validate(sacrifice, state: sacrificeState, trackedTeamHomeAway: .home) == nil)
    }

    @Test func validatorRejectsTwoRunnersEndingOnSameBase() {
        var state = GameState()
        state.half = .top
        state.firstBaseRunnerSlot = 1
        state.currentOpponentBatterSlot = 2
        setPendingBallInPlay(on: &state, batterSlot: 2)

        let play = BallInPlayEvent(
            outcome: .single,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .first),
                .init(source: .first, destination: .first)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        )
        #expect(BallInPlayValidator.validate(play, state: state, trackedTeamHomeAway: .home) == .baseCollision(.first))
    }

    @Test func validatorRejectsRunnerMovingBackward() {
        var state = GameState()
        state.half = .top
        state.secondBaseRunnerSlot = 1
        state.currentOpponentBatterSlot = 2
        setPendingBallInPlay(on: &state, batterSlot: 2)

        let play = BallInPlayEvent(
            outcome: .single,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .second),
                .init(source: .second, destination: .first)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        )
        #expect(BallInPlayValidator.validate(play, state: state, trackedTeamHomeAway: .home) == .illegalDestination(.second, .first))
    }

    @Test func validatorRejectsTrailingRunnerPassingRunnerAhead() {
        var state = GameState()
        state.half = .top
        state.firstBaseRunnerSlot = 1
        state.currentOpponentBatterSlot = 2
        setPendingBallInPlay(on: &state, batterSlot: 2)

        let play = BallInPlayEvent(
            outcome: .single,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .second),
                .init(source: .first, destination: .first)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        )

        #expect(BallInPlayValidator.validate(play, state: state, trackedTeamHomeAway: .home) == .illegalDestination(.batter, .second))
    }

    @Test func validatorRequiresDispositionWhenRunAndThirdOutOccurTogether() {
        var state = GameState()
        state.half = .top
        state.outs = 2
        state.thirdBaseRunnerSlot = 1
        state.currentOpponentBatterSlot = 2
        setPendingBallInPlay(on: &state, batterSlot: 2)

        let play = BallInPlayEvent(
            outcome: .flyOut,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .out),
                .init(source: .third, destination: .home)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        )
        #expect(BallInPlayValidator.validate(play, state: state, trackedTeamHomeAway: .home) == .missingThirdOutRunCount)
    }

    @Test func runCanBeExplicitlySuppressedOnThirdOut() {
        var state = GameState()
        state.half = .top
        state.outs = 2
        state.thirdBaseRunnerSlot = 1
        state.currentOpponentBatterSlot = 2
        setPendingBallInPlay(on: &state, batterSlot: 2)

        let play = BallInPlayEvent(
            outcome: .flyOut,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .out),
                .init(source: .third, destination: .home)
            ],
            rbi: 0,
            thirdOutRunsCounted: 0,
            thirdOutClassification: .forceOrBatterRunner
        )
        applyPlay(play, to: &state)

        #expect(state.awayScore == 0)
        #expect(state.half == .bottom)
        #expect(state.outs == 0)
    }

    @Test func runCanExplicitlyCountBeforeNonForceThirdOut() {
        var state = GameState()
        state.half = .top
        state.outs = 2
        state.secondBaseRunnerSlot = 1
        state.thirdBaseRunnerSlot = 2
        state.currentOpponentBatterSlot = 3
        setPendingBallInPlay(on: &state, batterSlot: 3)

        let play = BallInPlayEvent(
            outcome: .single,
            opponentBatterSlot: 3,
            movements: [
                .init(source: .batter, destination: .first),
                .init(source: .second, destination: .out),
                .init(source: .third, destination: .home)
            ],
            rbi: 1,
            thirdOutRunsCounted: 1,
            thirdOutClassification: .timingPlay
        )
        applyPlay(play, to: &state)

        #expect(state.awayScore == 1)
        #expect(state.half == .bottom)
    }

    @Test func doublePlayRecordsExactlyTwoOuts() {
        var state = GameState()
        state.half = .top
        state.firstBaseRunnerSlot = 1
        state.currentOpponentBatterSlot = 2
        setPendingBallInPlay(on: &state, batterSlot: 2)

        let play = BallInPlayEvent(
            outcome: .doublePlay,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .out),
                .init(source: .first, destination: .out)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        )
        applyPlay(play, to: &state)
        #expect(state.outs == 2)
        #expect(state.baseRunnerSlots.allSatisfy { $0 == nil })
    }

    @Test func timingPlayCanCountOnlySomeHomeTouches() {
        var state = GameState()
        state.half = .top
        state.outs = 1
        state.secondBaseRunnerSlot = 1
        state.thirdBaseRunnerSlot = 2
        state.currentOpponentBatterSlot = 3
        setPendingBallInPlay(on: &state, batterSlot: 3)

        let play = BallInPlayEvent(
            outcome: .doublePlay,
            opponentBatterSlot: 3,
            movements: [
                .init(source: .batter, destination: .out),
                .init(source: .second, destination: .out),
                .init(source: .third, destination: .home)
            ],
            rbi: 1,
            thirdOutRunsCounted: 1,
            thirdOutClassification: .timingPlay
        )
        #expect(BallInPlayValidator.validate(play, state: state, trackedTeamHomeAway: .home) == nil)
        applyPlay(play, to: &state)
        #expect(state.awayScore == 1)
        #expect(state.half == .bottom)
    }

    @Test func rbiCannotExceedRunsThatCountOnThirdOut() {
        var state = GameState()
        state.half = .top
        state.outs = 2
        state.thirdBaseRunnerSlot = 1
        state.currentOpponentBatterSlot = 2
        setPendingBallInPlay(on: &state, batterSlot: 2)

        let play = BallInPlayEvent(
            outcome: .flyOut,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .out),
                .init(source: .third, destination: .home)
            ],
            rbi: 1,
            thirdOutRunsCounted: 0,
            thirdOutClassification: .forceOrBatterRunner
        )
        #expect(BallInPlayValidator.validate(play, state: state, trackedTeamHomeAway: .home) == .invalidRBI)
    }

    @Test func ordinaryBatterOutAsThirdOutCannotCountRun() {
        var state = GameState()
        state.half = .top
        state.outs = 2
        state.thirdBaseRunnerSlot = 1
        state.currentOpponentBatterSlot = 2
        setPendingBallInPlay(on: &state, batterSlot: 2)

        let play = BallInPlayEvent(
            outcome: .groundOut,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .out),
                .init(source: .third, destination: .home)
            ],
            rbi: 1,
            thirdOutRunsCounted: 1,
            thirdOutClassification: .timingPlay
        )
        #expect(BallInPlayValidator.validate(play, state: state, trackedTeamHomeAway: .home) == .invalidThirdOutRunCount)
    }

    @Test func forcedThirdOutCannotCountRun() {
        var state = GameState()
        state.half = .top
        state.outs = 2
        state.firstBaseRunnerSlot = 1
        state.thirdBaseRunnerSlot = 2
        state.currentOpponentBatterSlot = 3
        setPendingBallInPlay(on: &state, batterSlot: 3)

        let play = BallInPlayEvent(
            outcome: .fieldersChoice,
            opponentBatterSlot: 3,
            movements: [
                .init(source: .batter, destination: .first),
                .init(source: .first, destination: .out),
                .init(source: .third, destination: .home)
            ],
            rbi: 1,
            thirdOutRunsCounted: 1,
            thirdOutClassification: .forceOrBatterRunner
        )

        #expect(BallInPlayValidator.validate(play, state: state, trackedTeamHomeAway: .home) == .invalidThirdOutRunCount)
    }

    @Test func batterRunnerThirdOutInDoublePlayCannotCountRun() {
        var state = GameState()
        state.half = .top
        state.outs = 1
        state.firstBaseRunnerSlot = 1
        state.secondBaseRunnerSlot = 2
        state.thirdBaseRunnerSlot = 3
        state.currentOpponentBatterSlot = 4
        setPendingBallInPlay(on: &state, batterSlot: 4)

        let play = BallInPlayEvent(
            outcome: .doublePlay,
            opponentBatterSlot: 4,
            movements: [
                .init(source: .batter, destination: .out),
                .init(source: .first, destination: .out),
                .init(source: .second, destination: .third),
                .init(source: .third, destination: .home)
            ],
            rbi: 1,
            thirdOutRunsCounted: 1,
            thirdOutClassification: .forceOrBatterRunner
        )

        #expect(BallInPlayValidator.validate(play, state: state, trackedTeamHomeAway: .home) == .invalidThirdOutRunCount)
    }

    @Test func tagThirdOutAfterEarlierForceCanCountTimingRun() {
        var state = GameState()
        state.half = .top
        state.outs = 1
        state.firstBaseRunnerSlot = 1
        state.secondBaseRunnerSlot = 2
        state.thirdBaseRunnerSlot = 3
        state.currentOpponentBatterSlot = 4
        setPendingBallInPlay(on: &state, batterSlot: 4)

        let play = BallInPlayEvent(
            outcome: .doublePlay,
            opponentBatterSlot: 4,
            movements: [
                .init(source: .batter, destination: .first),
                .init(source: .first, destination: .out),
                .init(source: .second, destination: .out),
                .init(source: .third, destination: .home)
            ],
            rbi: 1,
            thirdOutRunsCounted: 1,
            thirdOutClassification: .timingPlay
        )

        #expect(BallInPlayValidator.validate(play, state: state, trackedTeamHomeAway: .home) == nil)
    }

    @Test func creditedHitBatterTaggedAdvancingCanEndTimingPlay() {
        var state = GameState()
        state.half = .top
        state.outs = 2
        state.thirdBaseRunnerSlot = 1
        state.currentOpponentBatterSlot = 2
        setPendingBallInPlay(on: &state, batterSlot: 2)

        let play = BallInPlayEvent(
            outcome: .single,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .out),
                .init(source: .third, destination: .home)
            ],
            rbi: 1,
            thirdOutRunsCounted: 1,
            thirdOutClassification: .timingPlay
        )

        #expect(BallInPlayValidator.validate(play, state: state, trackedTeamHomeAway: .home) == nil)
        applyPlay(play, to: &state)
        #expect(state.awayScore == 1)
        #expect(state.half == .bottom)
    }

    @Test func sacrificeFlyRequiresRunnerToScore() {
        var state = GameState()
        state.half = .top
        state.thirdBaseRunnerSlot = 1
        state.currentOpponentBatterSlot = 2
        setPendingBallInPlay(on: &state, batterSlot: 2)

        let play = BallInPlayEvent(
            outcome: .sacrificeFly,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .out),
                .init(source: .third, destination: .third)
            ],
            rbi: 0,
            thirdOutRunsCounted: nil
        )
        #expect(BallInPlayValidator.validate(play, state: state, trackedTeamHomeAway: .home) == .outcomeMismatch)
    }

    @Test func sacrificeFlyIsRejectedWithTwoOuts() {
        var state = GameState()
        state.half = .top
        state.outs = 2
        state.thirdBaseRunnerSlot = 1
        state.currentOpponentBatterSlot = 2
        setPendingBallInPlay(on: &state, batterSlot: 2)

        let play = BallInPlayEvent(
            outcome: .sacrificeFly,
            opponentBatterSlot: 2,
            movements: [
                .init(source: .batter, destination: .out),
                .init(source: .third, destination: .home)
            ],
            rbi: 0,
            thirdOutRunsCounted: 0,
            thirdOutClassification: .forceOrBatterRunner
        )
        #expect(BallInPlayValidator.validate(play, state: state, trackedTeamHomeAway: .home) == .outcomeMismatch)
    }

    @Test func thirdOutTransitionsHalfAndClearsBases() {
        let strikeout = [PitchResult.calledStrike, .calledStrike, .calledStrike]
        let state = replayPitches(strikeout + strikeout + strikeout)
        #expect(state.inning == 1)
        #expect(state.half == .bottom)
        #expect(state.outs == 0)
        #expect(state.baseRunnerSlots.allSatisfy { $0 == nil })
        #expect(state.currentOpponentBatterSlot == 4)
        #expect(state.pitchCount(for: pitcherID).total == 9)
    }

    @Test func defensivePitchEventsDoNotApplyDuringTrackedTeamsOffensiveHalf() {
        var state = GameState()
        state.half = .top
        let event = makePitchEvent(.ball, batterSlot: 1)
        GameReducer.apply(event, to: &state, trackedTeamHomeAway: .away)
        #expect(state == GameState())
    }

    @Test(arguments: [9, 13])
    func trackedBattingOrderUsesActualLineupLengthAndWraps(_ lineupCount: Int) {
        let lineup = (1...lineupCount).map { slot in
            TrackedBatterIdentity(
                playerID: UUID(),
                lineupSlot: slot,
                displayName: "Batter \(slot)",
                jerseyNumber: "\(slot)",
                position: slot == 1 ? .pitcher : nil
            )
        }
        var state = GameState()

        for (index, batter) in lineup.enumerated() {
            let plateAppearance = OffensivePlateAppearanceEvent(
                batter: batter,
                battingOrderSize: lineup.count,
                result: .homeRun,
                movements: [.init(source: .batter, destination: .home)],
                rbi: 1,
                countedRunSources: [.batter],
                thirdOutClassification: nil
            )
            GameReducer.apply(
                DecodedGameEvent(
                    sequenceNumber: index + 1,
                    timestamp: Date(timeIntervalSince1970: TimeInterval(index + 1)),
                    body: .offensivePlateAppearance(plateAppearance)
                ),
                to: &state,
                trackedTeamHomeAway: .away
            )
        }

        #expect(state.currentTrackedBatterSlot == 1)
        #expect(state.awayScore == lineupCount)
        #expect(state.trackedBaseRunnerPlayerIDs.allSatisfy { $0 == nil })
    }

    @Test func trackedTeamWalkPlacesRealPlayerOnFirstAndAdvancesBatter() {
        let lineup = (1...2).map { slot in
            TrackedBatterIdentity(
                playerID: UUID(),
                lineupSlot: slot,
                displayName: "Batter \(slot)",
                jerseyNumber: "\(slot)",
                position: nil
            )
        }
        var state = GameState()
        let walk = OffensivePlateAppearanceEvent(
            batter: lineup[0],
            battingOrderSize: lineup.count,
            result: .walk,
            movements: [.init(source: .batter, destination: .first)],
            rbi: 0,
            countedRunSources: [],
            thirdOutClassification: nil
        )

        GameReducer.apply(
            DecodedGameEvent(sequenceNumber: 1, timestamp: .now, body: .offensivePlateAppearance(walk)),
            to: &state,
            trackedTeamHomeAway: .away
        )

        #expect(state.firstBaseRunnerPlayerID == lineup[0].playerID)
        #expect(state.currentTrackedBatterSlot == 2)
        #expect(state.outs == 0)
    }

    @Test func offensiveQuickWalkForcesLoadedBasesAndCreditsOneRun() {
        var state = GameState()
        state.firstBaseRunnerPlayerID = UUID()
        state.secondBaseRunnerPlayerID = UUID()
        state.thirdBaseRunnerPlayerID = UUID()

        let suggestion = OffensiveMovementSuggestions.awardedFirstBase(state: state)

        #expect(suggestion.movements == [
            .init(source: .batter, destination: .first),
            .init(source: .first, destination: .second),
            .init(source: .second, destination: .third),
            .init(source: .third, destination: .home)
        ])
        #expect(suggestion.countedRunSources == [.third])
        #expect(suggestion.rbi == 1)
    }

    @Test func offensiveQuickWalkHoldsUnforcedRunners() {
        var state = GameState()
        state.secondBaseRunnerPlayerID = UUID()
        state.thirdBaseRunnerPlayerID = UUID()

        let suggestion = OffensiveMovementSuggestions.awardedFirstBase(state: state)

        #expect(suggestion.movements == [
            .init(source: .batter, destination: .first),
            .init(source: .second, destination: .second),
            .init(source: .third, destination: .third)
        ])
        #expect(suggestion.countedRunSources.isEmpty)
        #expect(suggestion.rbi == 0)
    }

    @Test func offensiveQuickHomeRunSendsEveryRunnerHome() {
        var state = GameState()
        state.firstBaseRunnerPlayerID = UUID()
        state.thirdBaseRunnerPlayerID = UUID()

        let suggestion = OffensiveMovementSuggestions.homeRun(state: state)

        #expect(suggestion.movements == [
            .init(source: .batter, destination: .home),
            .init(source: .first, destination: .home),
            .init(source: .third, destination: .home)
        ])
        #expect(suggestion.countedRunSources == [.batter, .first, .third])
        #expect(suggestion.rbi == 3)
    }

    @Test func offensiveQuickStrikeoutHoldsRunnersAndRecordsBatterOut() {
        var state = GameState()
        state.firstBaseRunnerPlayerID = UUID()

        let suggestion = OffensiveMovementSuggestions.strikeout(state: state)

        #expect(suggestion.movements == [
            .init(source: .batter, destination: .out),
            .init(source: .first, destination: .first)
        ])
        #expect(suggestion.countedRunSources.isEmpty)
        #expect(suggestion.rbi == 0)
    }

    @Test func offensiveSingleSuggestionsAdvanceAndAttributeLoadedRunners() {
        var state = GameState()
        state.firstBaseRunnerPlayerID = UUID()
        state.secondBaseRunnerPlayerID = UUID()
        state.thirdBaseRunnerPlayerID = UUID()

        let suggestion = OffensiveMovementSuggestions.ballInPlay(.single, state: state)

        #expect(suggestion.movements == [
            .init(source: .batter, destination: .first),
            .init(source: .first, destination: .second),
            .init(source: .second, destination: .home),
            .init(source: .third, destination: .home)
        ])
        #expect(suggestion.countedRunSources == [.second, .third])
        #expect(suggestion.rbi == 2)
    }

    @Test func offensiveDoublePlaySuggestionsRecordTwoOutsWhenRunnerIsAvailable() {
        var state = GameState()
        state.firstBaseRunnerPlayerID = UUID()

        let suggestion = OffensiveMovementSuggestions.ballInPlay(.doublePlay, state: state)

        #expect(suggestion.movements == [
            .init(source: .batter, destination: .out),
            .init(source: .first, destination: .out)
        ])
        #expect(suggestion.countedRunSources.isEmpty)
        #expect(suggestion.rbi == 0)
    }

    @Test func correctionResultsIncludeScoringShapesButOmitThirdOutOnlyShapes() {
        var emptyBases = GameState()
        let emptyResults = OffensivePlateAppearanceValidator.correctionResults(for: emptyBases)
        #expect(!emptyResults.contains(.sacrificeBunt))
        #expect(!emptyResults.contains(.doublePlay))

        emptyBases.firstBaseRunnerPlayerID = UUID()
        emptyBases.secondBaseRunnerPlayerID = UUID()
        emptyBases.thirdBaseRunnerPlayerID = UUID()
        let loadedResults = OffensivePlateAppearanceValidator.correctionResults(for: emptyBases)
        #expect(loadedResults.contains(.walk))
        #expect(loadedResults.contains(.hitByPitch))
        #expect(loadedResults.contains(.sacrificeFly))

        emptyBases.outs = 2
        let twoOutLoadedResults = OffensivePlateAppearanceValidator.correctionResults(for: emptyBases)
        #expect(twoOutLoadedResults.contains(.single))
        #expect(twoOutLoadedResults.contains(.double))
        #expect(twoOutLoadedResults.contains(.triple))
        #expect(!twoOutLoadedResults.contains(.sacrificeFly))
    }

    @Test func offensiveValidatorIdentifiesRunRBIAndMovementProblems() {
        let lineup = trackedLineup(count: 2)
        var state = GameState()
        state.firstBaseRunnerPlayerID = lineup[0].playerID
        state.currentTrackedBatterSlot = 2

        func plateAppearance(
            movements: [RunnerMovementEvent],
            rbi: Int,
            countedRunSources: [RunnerSource]
        ) -> OffensivePlateAppearanceEvent {
            OffensivePlateAppearanceEvent(
                batter: lineup[1],
                battingOrderSize: lineup.count,
                result: .double,
                movements: movements,
                rbi: rbi,
                countedRunSources: countedRunSources,
                thirdOutClassification: nil
            )
        }

        let scoringMovements: [RunnerMovementEvent] = [
            .init(source: .batter, destination: .second),
            .init(source: .first, destination: .home)
        ]
        #expect(OffensivePlateAppearanceValidator.validate(
            plateAppearance(movements: scoringMovements, rbi: 0, countedRunSources: []),
            state: state,
            trackedTeamHomeAway: .away
        ) == .invalidRunSources)
        #expect(OffensivePlateAppearanceValidator.validate(
            plateAppearance(movements: scoringMovements, rbi: 2, countedRunSources: [.first]),
            state: state,
            trackedTeamHomeAway: .away
        ) == .invalidRBI)
        #expect(OffensivePlateAppearanceValidator.validate(
            plateAppearance(
                movements: [
                    .init(source: .batter, destination: .second),
                    .init(source: .first, destination: .second)
                ],
                rbi: 0,
                countedRunSources: []
            ),
            state: state,
            trackedTeamHomeAway: .away
        ) == .baseCollision(.second))

        state.outs = 2
        let halfInningEndingPlay = plateAppearance(
            movements: [
                .init(source: .batter, destination: .second),
                .init(source: .first, destination: .out)
            ],
            rbi: 0,
            countedRunSources: []
        )
        #expect(OffensivePlateAppearanceValidator.validate(
            halfInningEndingPlay,
            state: state,
            trackedTeamHomeAway: .away
        ) == nil)
        #expect(OffensivePlateAppearanceValidator.correctionScopeError(
            halfInningEndingPlay,
            stateBefore: state
        ) == .endsHalfInning)
    }

    @Test func offensiveValidatorRejectsSacrificeBuntWithMultipleOutsOnPlay() {
        let lineup = trackedLineup(count: 3)
        var state = GameState()
        state.firstBaseRunnerPlayerID = lineup[0].playerID
        state.secondBaseRunnerPlayerID = lineup[1].playerID
        state.currentTrackedBatterSlot = 3
        let play = OffensivePlateAppearanceEvent(
            batter: lineup[2],
            battingOrderSize: lineup.count,
            result: .sacrificeBunt,
            movements: [
                .init(source: .first, destination: .out),
                .init(source: .second, destination: .third),
                .init(source: .batter, destination: .out)
            ],
            rbi: 0,
            countedRunSources: [],
            thirdOutClassification: nil
        )

        #expect(!OffensivePlateAppearanceValidator.isValid(
            play,
            state: state,
            trackedTeamHomeAway: .away
        ))
    }

    @Test func offensiveValidatorRejectsRunnerPassing() {
        let lineup = trackedLineup(count: 3)
        var state = GameState()
        state.firstBaseRunnerPlayerID = lineup[0].playerID
        state.secondBaseRunnerPlayerID = lineup[1].playerID
        state.currentTrackedBatterSlot = 3
        let play = OffensivePlateAppearanceEvent(
            batter: lineup[2],
            battingOrderSize: lineup.count,
            result: .single,
            movements: [
                .init(source: .batter, destination: .first),
                .init(source: .first, destination: .home),
                .init(source: .second, destination: .second)
            ],
            rbi: 1,
            countedRunSources: [.first],
            thirdOutClassification: nil
        )

        #expect(!OffensivePlateAppearanceValidator.isValid(
            play,
            state: state,
            trackedTeamHomeAway: .away
        ))
    }

    @Test func ordinaryOffensiveBatterOutAsThirdOutCannotCountTimingRun() {
        let lineup = trackedLineup(count: 2)
        var state = GameState()
        state.outs = 2
        state.thirdBaseRunnerPlayerID = lineup[0].playerID
        state.currentTrackedBatterSlot = 2
        let play = OffensivePlateAppearanceEvent(
            batter: lineup[1],
            battingOrderSize: lineup.count,
            result: .groundOut,
            movements: [
                .init(source: .batter, destination: .out),
                .init(source: .third, destination: .home)
            ],
            rbi: 1,
            countedRunSources: [.third],
            thirdOutClassification: .timingPlay
        )

        #expect(!OffensivePlateAppearanceValidator.isValid(
            play,
            state: state,
            trackedTeamHomeAway: .away
        ))
    }

    @Test func strikeoutAsThirdOutCannotCountTimingRun() {
        let lineup = trackedLineup(count: 2)
        var state = GameState()
        state.outs = 2
        state.thirdBaseRunnerPlayerID = lineup[0].playerID
        state.currentTrackedBatterSlot = 2
        let play = OffensivePlateAppearanceEvent(
            batter: lineup[1],
            battingOrderSize: lineup.count,
            result: .strikeout,
            movements: [
                .init(source: .batter, destination: .out),
                .init(source: .third, destination: .home)
            ],
            rbi: 1,
            countedRunSources: [.third],
            thirdOutClassification: .timingPlay
        )

        #expect(!OffensivePlateAppearanceValidator.isValid(
            play,
            state: state,
            trackedTeamHomeAway: .away
        ))
    }

    @Test func offensiveThirdOutPreservesNextTrackedBatterForFollowingInning() {
        let lineup = trackedLineup(count: 5)
        var state = GameState()
        state.outs = 2
        let strikeout = OffensivePlateAppearanceEvent(
            batter: lineup[0],
            battingOrderSize: lineup.count,
            result: .strikeout,
            movements: [.init(source: .batter, destination: .out)],
            rbi: 0,
            countedRunSources: [],
            thirdOutClassification: nil
        )

        GameReducer.apply(
            DecodedGameEvent(sequenceNumber: 1, timestamp: .now, body: .offensivePlateAppearance(strikeout)),
            to: &state,
            trackedTeamHomeAway: .away
        )

        #expect(state.half == .bottom)
        #expect(state.currentTrackedBatterSlot == 2)
        #expect(state.outs == 0)
    }

    @Test func stolenBaseAndCaughtStealingUpdateRunnerWithoutAdvancingBatter() {
        let runnerID = UUID()
        var state = GameState()
        state.firstBaseRunnerPlayerID = runnerID

        GameReducer.apply(
            DecodedGameEvent(
                sequenceNumber: 1,
                timestamp: .now,
                body: .offensiveBaseRunning(OffensiveBaseRunningEvent(
                    runnerID: runnerID,
                    source: .first,
                    destination: .second,
                    result: .stolenBase
                ))
            ),
            to: &state,
            trackedTeamHomeAway: .away
        )

        #expect(state.firstBaseRunnerPlayerID == nil)
        #expect(state.secondBaseRunnerPlayerID == runnerID)
        #expect(state.currentTrackedBatterSlot == 1)
        #expect(state.outs == 0)

        GameReducer.apply(
            DecodedGameEvent(
                sequenceNumber: 2,
                timestamp: .now,
                body: .offensiveBaseRunning(OffensiveBaseRunningEvent(
                    runnerID: runnerID,
                    source: .second,
                    destination: .out,
                    result: .caughtStealing
                ))
            ),
            to: &state,
            trackedTeamHomeAway: .away
        )

        #expect(state.secondBaseRunnerPlayerID == nil)
        #expect(state.currentTrackedBatterSlot == 1)
        #expect(state.outs == 1)
    }

    @Test func stealOfHomeScoresRunnerWithoutRBI() {
        let runnerID = UUID()
        var state = GameState()
        state.thirdBaseRunnerPlayerID = runnerID

        GameReducer.apply(
            DecodedGameEvent(
                sequenceNumber: 1,
                timestamp: .now,
                body: .offensiveBaseRunning(OffensiveBaseRunningEvent(
                    runnerID: runnerID,
                    source: .third,
                    destination: .home,
                    result: .stolenBase
                ))
            ),
            to: &state,
            trackedTeamHomeAway: .away
        )

        #expect(state.awayScore == 1)
        #expect(state.thirdBaseRunnerPlayerID == nil)
        #expect(state.currentTrackedBatterSlot == 1)
    }

    @Test func caughtStealingAsThirdOutAdvancesHalfAndClearsOtherRunners() {
        let caughtRunnerID = UUID()
        var state = GameState()
        state.outs = 2
        state.firstBaseRunnerPlayerID = UUID()
        state.secondBaseRunnerPlayerID = caughtRunnerID

        GameReducer.apply(
            DecodedGameEvent(
                sequenceNumber: 1,
                timestamp: .now,
                body: .offensiveBaseRunning(OffensiveBaseRunningEvent(
                    runnerID: caughtRunnerID,
                    source: .second,
                    destination: .out,
                    result: .caughtStealing
                ))
            ),
            to: &state,
            trackedTeamHomeAway: .away
        )

        #expect(state.half == .bottom)
        #expect(state.outs == 0)
        #expect(state.trackedBaseRunnerPlayerIDs.allSatisfy { $0 == nil })
        #expect(state.currentTrackedBatterSlot == 1)
    }

    @Test func baseRunningValidatorRejectsCollisionWrongRunnerAndWrongHalf() {
        let runnerID = UUID()
        var state = GameState()
        state.firstBaseRunnerPlayerID = runnerID
        state.secondBaseRunnerPlayerID = UUID()
        let steal = OffensiveBaseRunningEvent(
            runnerID: runnerID,
            source: .first,
            destination: .second,
            result: .stolenBase
        )

        #expect(!OffensiveBaseRunningValidator.isValid(
            steal,
            state: state,
            trackedTeamHomeAway: .away
        ))

        state.secondBaseRunnerPlayerID = nil
        let wrongRunner = OffensiveBaseRunningEvent(
            runnerID: UUID(),
            source: .first,
            destination: .second,
            result: .stolenBase
        )
        #expect(!OffensiveBaseRunningValidator.isValid(
            wrongRunner,
            state: state,
            trackedTeamHomeAway: .away
        ))

        #expect(!OffensiveBaseRunningValidator.isValid(
            steal,
            state: state,
            trackedTeamHomeAway: .home
        ))
    }

    private func replayPitches(_ results: [PitchResult]) -> GameState {
        var state = GameState()
        state.half = .top // tracked team is home, so opponent bats top
        for (index, result) in results.enumerated() {
            let event = makePitchEvent(result, batterSlot: state.currentOpponentBatterSlot, sequence: index + 1)
            GameReducer.apply(event, to: &state, trackedTeamHomeAway: .home)
        }
        return state
    }

    private func trackedLineup(count: Int) -> [TrackedBatterIdentity] {
        (1...count).map { slot in
            TrackedBatterIdentity(
                playerID: UUID(),
                lineupSlot: slot,
                displayName: "Batter \(slot)",
                jerseyNumber: "\(slot)",
                position: nil
            )
        }
    }

    private func makePitchEvent(_ result: PitchResult, batterSlot: Int, sequence: Int = 1) -> DecodedGameEvent {
        DecodedGameEvent(
            sequenceNumber: sequence,
            timestamp: Date(timeIntervalSince1970: TimeInterval(sequence)),
            body: .pitch(PitchEvent(result: result, pitcherID: pitcherID, opponentBatterSlot: batterSlot))
        )
    }

    private func setPendingBallInPlay(on state: inout GameState, batterSlot: Int) {
        let event = makePitchEvent(.ballInPlay, batterSlot: batterSlot)
        GameReducer.apply(event, to: &state, trackedTeamHomeAway: .home)
    }

    private func applyPlay(_ play: BallInPlayEvent, to state: inout GameState) {
        GameReducer.apply(
            DecodedGameEvent(sequenceNumber: 99, timestamp: .now, body: .ballInPlay(play)),
            to: &state,
            trackedTeamHomeAway: .home
        )
    }
}
