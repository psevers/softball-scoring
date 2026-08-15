import Foundation

struct PlayHistory: Equatable, Sendable {
    let sections: [PlayHistorySection]
}

struct PlayHistorySection: Identifiable, Equatable, Sendable {
    var id: String { "\(inning)-\(half.rawValue)" }

    let inning: Int
    let half: InningHalf
    var entries: [PlayHistoryEntry]

    var title: String { "\(half.displayName) \(inning)" }
}

struct PlayHistoryEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let inning: Int
    let half: InningHalf
    let actor: String
    let actorContext: String
    let summary: String
    let detail: String
    let accessibilityDescription: String
    let isProblem: Bool
    let components: [PlayHistoryComponent]

    var deletableDefensiveLogicalPlayResultRecordID: UUID? {
        guard let resultIndex = components.lastIndex(where: {
            $0.editableDefensiveBallInPlayOutcome != nil
        }),
              components[..<resultIndex].contains(where: {
                  $0.defensivePitchResult == .ballInPlay
              }) else {
            return nil
        }
        return components[resultIndex].recordID
    }
}

struct PlayHistoryComponent: Identifiable, Equatable, Sendable {
    var id: UUID { recordID }

    let recordID: UUID
    let sequenceNumber: Int
    let summary: String
    let detail: String
    let accessibilityDescription: String
    let isPitch: Bool
    let defensivePitchResult: PitchResult?
    let editableDefensivePitchResult: PitchResult?
    let editableOffensivePitchResult: OffensivePitchResult?
    let editableOffensiveBaseRunningEvent: OffensiveBaseRunningEvent?
    let editableOffensivePlateAppearanceResult: OffensivePlateAppearanceResult?
    let editableDefensiveBallInPlayOutcome: BallInPlayOutcome?

    init(
        recordID: UUID,
        sequenceNumber: Int,
        summary: String,
        detail: String,
        accessibilityDescription: String,
        isPitch: Bool,
        defensivePitchResult: PitchResult? = nil,
        editableDefensivePitchResult: PitchResult? = nil,
        editableOffensivePitchResult: OffensivePitchResult? = nil,
        editableOffensiveBaseRunningEvent: OffensiveBaseRunningEvent? = nil,
        editableOffensivePlateAppearanceResult: OffensivePlateAppearanceResult? = nil,
        editableDefensiveBallInPlayOutcome: BallInPlayOutcome? = nil
    ) {
        self.recordID = recordID
        self.sequenceNumber = sequenceNumber
        self.summary = summary
        self.detail = detail
        self.accessibilityDescription = accessibilityDescription
        self.isPitch = isPitch
        self.defensivePitchResult = defensivePitchResult
        self.editableDefensivePitchResult = editableDefensivePitchResult
        self.editableOffensivePitchResult = editableOffensivePitchResult
        self.editableOffensiveBaseRunningEvent = editableOffensiveBaseRunningEvent
        self.editableOffensivePlateAppearanceResult = editableOffensivePlateAppearanceResult
        self.editableDefensiveBallInPlayOutcome = editableDefensiveBallInPlayOutcome
    }
}

enum PlayHistoryProjector {
    private struct PendingPlateAppearance {
        let id: UUID
        let inning: Int
        let half: InningHalf
        let actor: String
        let actorContext: String
        var components: [PlayHistoryComponent]
        let initialState: GameState
        var latestState: GameState
        var completedSummary: String?
        var pendingBallInPlay = false
    }

    static func project(replay: GameEventReplay.Result) -> PlayHistory {
        var sections: [PlayHistorySection] = []
        var pending: PendingPlateAppearance?
        var identities: [UUID: (identity: TrackedBatterIdentity, orderSize: Int)] = [:]

        func append(_ entry: PlayHistoryEntry) {
            let sectionID = "\(entry.inning)-\(entry.half.rawValue)"
            if let index = sections.firstIndex(where: { $0.id == sectionID }) {
                sections[index].entries.append(entry)
            } else {
                sections.append(PlayHistorySection(
                    inning: entry.inning,
                    half: entry.half,
                    entries: [entry]
                ))
            }
        }

        func flushPending() {
            guard let value = pending else { return }
            append(makeEntry(from: value))
            pending = nil
        }

        for trace in replay.entries {
            if let rejection = trace.rejection {
                append(problemEntry(for: trace, rejection: rejection))
                continue
            }

            guard let body = trace.body else { continue }
            switch body {
            case .pitch(let pitch):
                let actor = "Opponent batter \(pitch.opponentBatterSlot)"
                beginOrContinue(
                    trace: trace,
                    actor: actor,
                    actorContext: "Batting slot \(pitch.opponentBatterSlot)",
                    pending: &pending,
                    flush: flushPending
                )
                pending?.components.append(pitchComponent(trace: trace, pitch: pitch))
                pending?.latestState = trace.stateAfter
                pending?.pendingBallInPlay = pitch.result == .ballInPlay

                if pitch.result == .hitByPitch {
                    pending?.completedSummary = "HBP · Batter to 1B"
                    flushPending()
                } else if pitch.result == .ball, trace.stateBefore.balls == 3 {
                    pending?.completedSummary = "BB · Batter to 1B"
                    flushPending()
                } else if [.calledStrike, .swingingStrike].contains(pitch.result),
                          trace.stateBefore.strikes == 2 {
                    pending?.completedSummary = "K · Batter out"
                    flushPending()
                }

            case .ballInPlay(let play):
                let actor = "Opponent batter \(play.opponentBatterSlot)"
                beginOrContinue(
                    trace: trace,
                    actor: actor,
                    actorContext: "Batting slot \(play.opponentBatterSlot)",
                    pending: &pending,
                    flush: flushPending
                )
                let component = playComponent(trace: trace, play: play)
                pending?.components.append(component)
                pending?.latestState = trace.stateAfter
                pending?.pendingBallInPlay = false
                pending?.completedSummary = component.summary
                flushPending()

            case .offensivePitch(let pitch):
                identities[pitch.batter.playerID] = (pitch.batter, pitch.battingOrderSize)
                beginOrContinue(
                    trace: trace,
                    actor: pitch.batter.displayName,
                    actorContext: actorContext(for: pitch.batter, orderSize: pitch.battingOrderSize),
                    pending: &pending,
                    flush: flushPending
                )
                pending?.components.append(offensivePitchComponent(trace: trace, pitch: pitch))
                pending?.latestState = trace.stateAfter

            case .offensivePlateAppearance(let plateAppearance):
                identities[plateAppearance.batter.playerID] = (
                    plateAppearance.batter,
                    plateAppearance.battingOrderSize
                )
                beginOrContinue(
                    trace: trace,
                    actor: plateAppearance.batter.displayName,
                    actorContext: actorContext(
                        for: plateAppearance.batter,
                        orderSize: plateAppearance.battingOrderSize
                    ),
                    pending: &pending,
                    flush: flushPending
                )
                let component = plateAppearanceComponent(
                    trace: trace,
                    plateAppearance: plateAppearance
                )
                pending?.components.append(component)
                pending?.latestState = trace.stateAfter
                pending?.completedSummary = component.summary
                flushPending()

            case .offensiveBaseRunning(let event):
                flushPending()
                let identity = identities[event.runnerID]
                let actor = identity?.identity.displayName ?? "Tracked runner"
                let context = identity.map { actorContext(for: $0.identity, orderSize: $0.orderSize) }
                    ?? "Event-time player ID \(event.runnerID.uuidString)"
                let notation = event.result.shortLabel
                let movement = "\(event.source.baseLabel) to \(event.destination.label)"
                let summary = "\(notation) · \(movement)"
                let component = PlayHistoryComponent(
                    recordID: trace.recordID,
                    sequenceNumber: trace.sequenceNumber,
                    summary: summary,
                    detail: event.result == .stolenBase ? "Runner advanced" : "Runner out",
                    accessibilityDescription: summary,
                    isPitch: false,
                    editableOffensiveBaseRunningEvent: event
                )
                append(entry(
                    id: trace.recordID,
                    trace: trace,
                    actor: actor,
                    actorContext: context,
                    summary: summary,
                    components: [component]
                ))
            }
        }

        flushPending()
        for index in sections.indices {
            sections[index].entries.sort { firstSequence(in: $0) < firstSequence(in: $1) }
        }
        return PlayHistory(sections: sections)
    }

    private static func beginOrContinue(
        trace: GameEventReplay.Entry,
        actor: String,
        actorContext: String,
        pending: inout PendingPlateAppearance?,
        flush: () -> Void
    ) {
        if let pending,
           pending.inning != trace.stateBefore.inning
            || pending.half != trace.stateBefore.half
            || pending.actor != actor {
            flush()
        }
        if pending == nil {
            pending = PendingPlateAppearance(
                id: trace.recordID,
                inning: trace.stateBefore.inning,
                half: trace.stateBefore.half,
                actor: actor,
                actorContext: actorContext,
                components: [],
                initialState: trace.stateBefore,
                latestState: trace.stateBefore
            )
        }
    }

    private static func makeEntry(from pending: PendingPlateAppearance) -> PlayHistoryEntry {
        let summary: String
        if let completedSummary = pending.completedSummary {
            summary = completedSummary
        } else if pending.pendingBallInPlay {
            summary = "Ball In Play · Pending"
        } else {
            summary = "Plate appearance in progress · \(pending.latestState.balls)–\(pending.latestState.strikes) count"
        }
        let pitchCount = pending.components.filter(\.isPitch).count
        let pitchDetail: String
        switch pitchCount {
        case 0: pitchDetail = "No component pitches recorded"
        case 1: pitchDetail = "1 pitch"
        default: pitchDetail = "\(pitchCount) pitches"
        }
        let materialChange = stateChangeDescription(
            from: pending.initialState,
            to: pending.latestState
        )
        let detail = "\(pitchDetail) · \(materialChange)"
        return PlayHistoryEntry(
            id: pending.id,
            inning: pending.inning,
            half: pending.half,
            actor: pending.actor,
            actorContext: pending.actorContext,
            summary: summary,
            detail: detail,
            accessibilityDescription: accessibilityDescription(
                inning: pending.inning,
                half: pending.half,
                actor: pending.actor,
                summary: summary,
                detail: detail
            ),
            isProblem: false,
            components: pending.components
        )
    }

    private static func problemEntry(
        for trace: GameEventReplay.Entry,
        rejection: GameEventReplay.Rejection
    ) -> PlayHistoryEntry {
        let summary: String
        let detail: String
        switch rejection {
        case .invalidSequence:
            summary = "Invalid event sequence"
            detail = "Sequence must be positive and unique"
        case .unknownKind:
            summary = "Unsupported saved event"
            detail = "This app version does not recognize the event kind"
        case .malformedPayload:
            summary = "Unreadable saved event"
            detail = "The saved play data is malformed"
        case .semanticallyRejected:
            summary = "Play conflicts with earlier history"
            detail = "The play is readable but invalid at this point in the game"
        }
        let actor = "Saved event \(trace.sequenceNumber)"
        let component = PlayHistoryComponent(
            recordID: trace.recordID,
            sequenceNumber: trace.sequenceNumber,
            summary: summary,
            detail: detail,
            accessibilityDescription: "Problem. \(summary). \(detail).",
            isPitch: false
        )
        return PlayHistoryEntry(
            id: trace.recordID,
            inning: trace.stateBefore.inning,
            half: trace.stateBefore.half,
            actor: actor,
            actorContext: "Sequence \(trace.sequenceNumber)",
            summary: summary,
            detail: detail,
            accessibilityDescription: accessibilityDescription(
                inning: trace.stateBefore.inning,
                half: trace.stateBefore.half,
                actor: actor,
                summary: summary,
                detail: detail
            ),
            isProblem: true,
            components: [component]
        )
    }

    private static func entry(
        id: UUID,
        trace: GameEventReplay.Entry,
        actor: String,
        actorContext: String,
        summary: String,
        components: [PlayHistoryComponent]
    ) -> PlayHistoryEntry {
        let detail = stateChangeDescription(from: trace.stateBefore, to: trace.stateAfter)
        return PlayHistoryEntry(
            id: id,
            inning: trace.stateBefore.inning,
            half: trace.stateBefore.half,
            actor: actor,
            actorContext: actorContext,
            summary: summary,
            detail: detail,
            accessibilityDescription: accessibilityDescription(
                inning: trace.stateBefore.inning,
                half: trace.stateBefore.half,
                actor: actor,
                summary: summary,
                detail: detail
            ),
            isProblem: false,
            components: components
        )
    }

    private static func pitchComponent(
        trace: GameEventReplay.Entry,
        pitch: PitchEvent
    ) -> PlayHistoryComponent {
        let count = "Count \(trace.stateAfter.balls)–\(trace.stateAfter.strikes)"
        let total = trace.stateAfter.pitchCount(for: pitch.pitcherID).total
        let detail = "\(count) · Pitch \(total)"
        return PlayHistoryComponent(
            recordID: trace.recordID,
            sequenceNumber: trace.sequenceNumber,
            summary: pitch.result.label,
            detail: detail,
            accessibilityDescription: "\(pitch.result.label). \(count). Pitch count \(total).",
            isPitch: true,
            defensivePitchResult: pitch.result,
            editableDefensivePitchResult: editableDefensivePitchResult(
                pitch.result,
                stateBefore: trace.stateBefore
            )
        )
    }

    private static func editableDefensivePitchResult(
        _ result: PitchResult,
        stateBefore: GameState
    ) -> PitchResult? {
        switch result {
        case .ball where stateBefore.balls < 3:
            result
        case .calledStrike where stateBefore.strikes < 2:
            result
        case .swingingStrike where stateBefore.strikes < 2:
            result
        case .foul:
            result
        case .ball, .calledStrike, .swingingStrike, .ballInPlay, .hitByPitch:
            nil
        }
    }

    private static func offensivePitchComponent(
        trace: GameEventReplay.Entry,
        pitch: OffensivePitchEvent
    ) -> PlayHistoryComponent {
        let result: String
        switch pitch.result {
        case .ball: result = "Ball"
        case .calledStrike: result = "Called Strike"
        case .swingingStrike: result = "Swinging Strike"
        case .foul: result = "Foul"
        }
        let detail = "Count \(trace.stateAfter.balls)–\(trace.stateAfter.strikes)"
        return PlayHistoryComponent(
            recordID: trace.recordID,
            sequenceNumber: trace.sequenceNumber,
            summary: result,
            detail: detail,
            accessibilityDescription: "\(result). \(detail).",
            isPitch: true,
            editableOffensivePitchResult: pitch.result
        )
    }

    private static func playComponent(
        trace: GameEventReplay.Entry,
        play: BallInPlayEvent
    ) -> PlayHistoryComponent {
        let summary = completedPlaySummary(
            notation: play.outcome.shortLabel,
            movements: play.movements,
            runs: countedRuns(in: play, stateBefore: trace.stateBefore),
            outs: play.movements.filter { $0.destination == .out }.count,
            rbi: play.rbi
        )
        return PlayHistoryComponent(
            recordID: trace.recordID,
            sequenceNumber: trace.sequenceNumber,
            summary: summary,
            detail: stateChangeDescription(from: trace.stateBefore, to: trace.stateAfter),
            accessibilityDescription: summary,
            isPitch: false,
            editableDefensiveBallInPlayOutcome: BallInPlayValidator.supportsCorrection(
                play,
                stateBefore: trace.stateBefore
            ) ? play.outcome : nil
        )
    }

    private static func plateAppearanceComponent(
        trace: GameEventReplay.Entry,
        plateAppearance: OffensivePlateAppearanceEvent
    ) -> PlayHistoryComponent {
        let summary = completedPlaySummary(
            notation: notation(for: plateAppearance.result),
            movements: plateAppearance.movements,
            runs: plateAppearance.countedRunSources.count,
            outs: plateAppearance.movements.filter { $0.destination == .out }.count,
            rbi: plateAppearance.rbi
        )
        return PlayHistoryComponent(
            recordID: trace.recordID,
            sequenceNumber: trace.sequenceNumber,
            summary: summary,
            detail: stateChangeDescription(from: trace.stateBefore, to: trace.stateAfter),
            accessibilityDescription: summary,
            isPitch: false,
            editableOffensivePlateAppearanceResult:
                OffensivePlateAppearanceValidator.supportsCorrection(
                    plateAppearance,
                    stateBefore: trace.stateBefore
                ) ? plateAppearance.result : nil
        )
    }

    private static func completedPlaySummary(
        notation: String,
        movements: [RunnerMovementEvent],
        runs: Int,
        outs: Int,
        rbi: Int
    ) -> String {
        var parts = [notation]
        parts.append(contentsOf: movements.map {
            "\(movementSourceLabel($0.source)) to \($0.destination.label)"
        })
        if runs > 0 { parts.append("\(runs) \(runs == 1 ? "run" : "runs")") }
        if outs > 0 { parts.append("\(outs) \(outs == 1 ? "out" : "outs")") }
        if rbi > 0 { parts.append("\(rbi) RBI") }
        return parts.joined(separator: " · ")
    }

    private static func notation(for result: OffensivePlateAppearanceResult) -> String {
        switch result {
        case .single: "1B"
        case .double: "2B"
        case .triple: "3B"
        case .homeRun: "HR"
        case .walk: "BB"
        case .hitByPitch: "HBP"
        case .strikeout: "K"
        case .reachedOnError: "E"
        case .fieldersChoice: "FC"
        case .groundOut: "GO"
        case .flyOut: "FO"
        case .lineOut: "LO"
        case .popOut: "PO"
        case .sacrificeBunt: "SAC"
        case .sacrificeFly: "SF"
        case .doublePlay: "DP"
        }
    }

    private static func actorContext(
        for batter: TrackedBatterIdentity,
        orderSize: Int
    ) -> String {
        var parts = ["Batting \(batter.lineupSlot) of \(orderSize)"]
        if !batter.jerseyNumber.isEmpty { parts.append("#\(batter.jerseyNumber)") }
        if let position = batter.position { parts.append(position.rawValue) }
        return parts.joined(separator: " · ")
    }

    private static func firstSequence(in entry: PlayHistoryEntry) -> Int {
        entry.components.map(\.sequenceNumber).min() ?? .max
    }

    private static func countedRuns(in play: BallInPlayEvent, stateBefore: GameState) -> Int {
        let homeTouches = play.movements.filter { $0.destination == .home }.count
        let outs = play.movements.filter { $0.destination == .out }.count
        return stateBefore.outs + outs == 3 ? play.thirdOutRunsCounted ?? 0 : homeTouches
    }

    private static func movementSourceLabel(_ source: RunnerSource) -> String {
        switch source {
        case .batter: "Batter"
        case .first: "Runner 1B"
        case .second: "Runner 2B"
        case .third: "Runner 3B"
        }
    }

    private static func stateChangeDescription(from before: GameState, to after: GameState) -> String {
        var parts: [String] = []
        let runs = (after.homeScore + after.awayScore) - (before.homeScore + before.awayScore)
        if runs > 0 { parts.append("\(runs) \(runs == 1 ? "run" : "runs") scored") }
        if before.half == after.half, before.inning == after.inning {
            let outs = after.outs - before.outs
            if outs > 0 { parts.append("\(outs) \(outs == 1 ? "out" : "outs") recorded") }
        } else {
            parts.append("Inning advanced to \(after.half.displayName) \(after.inning)")
        }
        let bases = [
            after.firstBaseRunnerSlot ?? (after.firstBaseRunnerPlayerID == nil ? nil : 0),
            after.secondBaseRunnerSlot ?? (after.secondBaseRunnerPlayerID == nil ? nil : 0),
            after.thirdBaseRunnerSlot ?? (after.thirdBaseRunnerPlayerID == nil ? nil : 0)
        ]
        let occupied = bases.compactMap { $0 }.count
        if before.baseRunnerSlots != after.baseRunnerSlots
            || before.trackedBaseRunnerPlayerIDs != after.trackedBaseRunnerPlayerIDs {
            parts.append("\(occupied) \(occupied == 1 ? "runner" : "runners") on base")
        }
        return parts.isEmpty ? "No score, out, or base change" : parts.joined(separator: " · ")
    }

    private static func accessibilityDescription(
        inning: Int,
        half: InningHalf,
        actor: String,
        summary: String,
        detail: String
    ) -> String {
        "\(half.displayName) of inning \(inning). \(actor). \(summary). \(detail)."
    }
}
