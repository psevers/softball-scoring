import SwiftUI

struct RunnerConfirmationSheet: View {
    let outcome: BallInPlayOutcome
    let state: GameState
    let homeAway: HomeAway
    let onCancel: () -> Void
    let onRecord: (BallInPlayEvent) -> Void

    @State private var destinations: [RunnerSource: RunnerDestination]
    @State private var rbi: Int
    @State private var thirdOutRunsCounted: Int = 0
    @State private var thirdOutClassification: ThirdOutClassification = .forceOrBatterRunner
    @State private var validationError: BallInPlayValidationError?

    init(
        outcome: BallInPlayOutcome,
        state: GameState,
        homeAway: HomeAway,
        onCancel: @escaping () -> Void,
        onRecord: @escaping (BallInPlayEvent) -> Void
    ) {
        self.outcome = outcome
        self.state = state
        self.homeAway = homeAway
        self.onCancel = onCancel
        self.onRecord = onRecord

        let suggestions = Self.suggestedDestinations(outcome: outcome, state: state)
        _destinations = State(initialValue: suggestions)
        let suggestedRuns = suggestions.values.filter { $0 == .home }.count
        _rbi = State(initialValue: outcome == .reachedOnError ? 0 : suggestedRuns)
    }

    private var movements: [RunnerMovementEvent] {
        state.occupiedRunnerSources.compactMap { source in
            destinations[source].map { RunnerMovementEvent(source: source, destination: $0) }
        }
    }

    private var outsOnPlay: Int {
        destinations.values.filter { $0 == .out }.count
    }

    private var runsOnPlay: Int {
        destinations.values.filter { $0 == .home }.count
    }

    private var needsThirdOutDecision: Bool {
        state.outs + outsOnPlay == 3 && runsOnPlay > 0
    }

    private var maximumThirdOutRunsCounted: Int {
        thirdOutClassification == .timingPlay ? runsOnPlay : 0
    }

    private var maximumRBI: Int {
        min(4, needsThirdOutDecision ? min(thirdOutRunsCounted, maximumThirdOutRunsCounted) : runsOnPlay)
    }

    private var draft: BallInPlayEvent {
        BallInPlayEvent(
            outcome: outcome,
            opponentBatterSlot: state.currentOpponentBatterSlot,
            movements: movements,
            rbi: rbi,
            thirdOutRunsCounted: needsThirdOutDecision ? thirdOutRunsCounted : nil,
            thirdOutClassification: needsThirdOutDecision ? thirdOutClassification : nil
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScorebookPaperBackground(gridSpacing: 22)

                ScrollView {
                    VStack(spacing: AppTheme.Spacing.md) {
                        ScorebookSheet {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                                Text(outcome.label)
                                    .font(.title2.weight(.semibold))
                                Text("Confirm where everybody ended up. The suggestions are just a head start—change anything that happened differently.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ScorebookSheet {
                            VStack(spacing: AppTheme.Spacing.sm) {
                                ForEach(state.occupiedRunnerSources, id: \.self) { source in
                                    runnerRow(source)
                                    if source != state.occupiedRunnerSources.last {
                                        Rectangle().fill(AppTheme.rule).frame(height: 1)
                                    }
                                }
                            }
                        }

                        ScorebookSheet {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                                Stepper("RBI  \(rbi)", value: $rbi, in: 0...maximumRBI)
                                    .font(.headline)

                                if needsThirdOutDecision {
                                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                        Text("RUN ON THIRD OUT")
                                            .font(.caption2.weight(.bold))
                                            .tracking(1.2)
                                        Picker("Third out", selection: $thirdOutClassification) {
                                            Text("Force / Batter").tag(ThirdOutClassification.forceOrBatterRunner)
                                            Text("Timing Play").tag(ThirdOutClassification.timingPlay)
                                        }
                                        .pickerStyle(.segmented)
                                        Stepper("Runs that count  \(thirdOutRunsCounted)", value: $thirdOutRunsCounted, in: 0...maximumThirdOutRunsCounted)
                                            .font(.headline)
                                        Text("For a force/batter-runner third out this is 0. On a timing play, count only runners who crossed home before the third out.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        if let validationError {
                            ScorebookSheet {
                                Label(validationMessage(validationError), systemImage: "exclamationmark.triangle")
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                }
            }
            .navigationTitle("Record Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Record") { validateAndRecord() }
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: destinations) { _, _ in
                validationError = nil
                thirdOutRunsCounted = min(thirdOutRunsCounted, maximumThirdOutRunsCounted)
                rbi = min(rbi, maximumRBI)
            }
            .onChange(of: thirdOutRunsCounted) { _, _ in
                validationError = nil
                rbi = min(rbi, maximumRBI)
            }
            .onChange(of: thirdOutClassification) { _, _ in
                validationError = nil
                thirdOutRunsCounted = min(thirdOutRunsCounted, maximumThirdOutRunsCounted)
                rbi = min(rbi, maximumRBI)
            }
        }
    }

    private func runnerRow(_ source: RunnerSource) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.label)
                    .font(.headline)
                if let slot = state.runnerSlot(for: source) {
                    Text(source == .batter ? "Opponent Batter \(slot)" : "Batter slot \(slot)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Picker(source.label, selection: destinationBinding(source)) {
                ForEach(legalDestinations(for: source)) { destination in
                    Text(destination.label).tag(destination)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
        .frame(minHeight: AppTheme.TouchTarget.minimum)
    }

    private func destinationBinding(_ source: RunnerSource) -> Binding<RunnerDestination> {
        Binding(
            get: { destinations[source] ?? .out },
            set: { destinations[source] = $0 }
        )
    }

    private func legalDestinations(for source: RunnerSource) -> [RunnerDestination] {
        switch source {
        case .batter, .first:
            RunnerDestination.allCases
        case .second:
            [.second, .third, .home, .out]
        case .third:
            [.third, .home, .out]
        }
    }

    private func validateAndRecord() {
        if let error = BallInPlayValidator.validate(draft, state: state, trackedTeamHomeAway: homeAway) {
            validationError = error
        } else {
            onRecord(draft)
        }
    }

    private func validationMessage(_ error: BallInPlayValidationError) -> String {
        switch error {
        case .baseCollision:
            "Two runners cannot finish on the same base."
        case .tooManyOuts:
            "This play would record more than three outs in the inning."
        case .outcomeMismatch:
            "The batter result does not match the selected runner destination."
        case .invalidRBI:
            "RBI must be between zero and the runs scored on the play."
        case .missingThirdOutRunCount, .missingThirdOutClassification, .invalidThirdOutRunCount:
            "Classify the third out and choose how many runs legally count."
        default:
            "One or more runner movements are not valid for the current game state."
        }
    }

    private static func suggestedDestinations(
        outcome: BallInPlayOutcome,
        state: GameState
    ) -> [RunnerSource: RunnerDestination] {
        var result: [RunnerSource: RunnerDestination] = [:]

        for source in state.occupiedRunnerSources {
            switch source {
            case .batter: result[source] = outcome.suggestedBatterDestination
            case .first: result[source] = .first
            case .second: result[source] = .second
            case .third: result[source] = .third
            }
        }

        switch outcome {
        case .single:
            if state.firstBaseRunnerSlot != nil { result[.first] = .second }
            if state.secondBaseRunnerSlot != nil { result[.second] = .home }
            if state.thirdBaseRunnerSlot != nil { result[.third] = .home }

        case .double:
            if state.firstBaseRunnerSlot != nil { result[.first] = .third }
            if state.secondBaseRunnerSlot != nil { result[.second] = .home }
            if state.thirdBaseRunnerSlot != nil { result[.third] = .home }

        case .triple, .homeRun:
            for source in state.occupiedRunnerSources where source != .batter {
                result[source] = .home
            }

        case .reachedOnError, .fieldersChoice:
            // Only force runners by default. The scorekeeper can advance others explicitly.
            if state.firstBaseRunnerSlot != nil {
                result[.first] = .second
                if state.secondBaseRunnerSlot != nil {
                    result[.second] = .third
                    if state.thirdBaseRunnerSlot != nil { result[.third] = .home }
                }
            }

        case .sacrificeFly:
            if state.thirdBaseRunnerSlot != nil { result[.third] = .home }

        case .doublePlay:
            if state.firstBaseRunnerSlot != nil { result[.first] = .out }
            else if state.secondBaseRunnerSlot != nil { result[.second] = .out }
            else if state.thirdBaseRunnerSlot != nil { result[.third] = .out }

        case .groundOut, .flyOut, .lineOut, .popOut, .sacrificeBunt:
            break
        }

        return result
    }
}
