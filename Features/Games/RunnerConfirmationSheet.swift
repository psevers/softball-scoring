import SwiftUI

struct RunnerConfirmationSheet: View {
    let outcome: BallInPlayOutcome
    let state: GameState
    let homeAway: HomeAway
    let allowsScoring: Bool
    let title: String
    let confirmationTitle: String
    let onCancel: () -> Void
    let onRecord: (BallInPlayEvent) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var destinations: [RunnerSource: RunnerDestination]
    @State private var rbi: Int
    @State private var runsCounted: Int
    @State private var thirdOutClassification: ThirdOutClassification = .forceOrBatterRunner
    @State private var validationError: BallInPlayValidationError?

    init(
        outcome: BallInPlayOutcome,
        state: GameState,
        homeAway: HomeAway,
        initialPlay: BallInPlayEvent? = nil,
        allowsScoring: Bool = true,
        title: String = "Record Play",
        confirmationTitle: String = "Record",
        onCancel: @escaping () -> Void,
        onRecord: @escaping (BallInPlayEvent) -> Void
    ) {
        self.outcome = outcome
        self.state = state
        self.homeAway = homeAway
        self.allowsScoring = allowsScoring
        self.title = title
        self.confirmationTitle = confirmationTitle
        self.onCancel = onCancel
        self.onRecord = onRecord

        let suggestions = initialPlay.map { play in
            Dictionary(uniqueKeysWithValues: play.movements.map { ($0.source, $0.destination) })
        } ?? Self.suggestedDestinations(outcome: outcome, state: state)
        _destinations = State(initialValue: suggestions)
        let suggestedRuns = suggestions.values.filter { $0 == .home }.count
        let initialRunsCounted = initialPlay?.thirdOutRunsCounted ?? suggestedRuns
        _runsCounted = State(initialValue: initialRunsCounted)
        _thirdOutClassification = State(
            initialValue: initialPlay?.thirdOutClassification ?? .forceOrBatterRunner
        )
        _rbi = State(initialValue: min(
            initialPlay?.rbi ?? (outcome == .reachedOnError ? 0 : suggestedRuns),
            initialRunsCounted
        ))
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
        min(4, needsThirdOutDecision ? min(runsCounted, maximumThirdOutRunsCounted) : runsCounted)
    }

    private var draft: BallInPlayEvent {
        BallInPlayEvent(
            outcome: outcome,
            opponentBatterSlot: state.currentOpponentBatterSlot,
            movements: movements,
            rbi: rbi,
            thirdOutRunsCounted: needsThirdOutDecision ? runsCounted : nil,
            thirdOutClassification: needsThirdOutDecision ? thirdOutClassification : nil
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScorebookRuledPaperBackground()

                ScrollView {
                    ScorebookLedger {
                        ScorebookPageSection {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                Text(outcome.label)
                                    .font(dynamicTypeSize.isAccessibilitySize ? .headline : AppTheme.Typography.notation)
                                Text("Confirm each runner’s destination.")
                                    .font(dynamicTypeSize.isAccessibilitySize ? .callout : AppTheme.Typography.body)
                                    .foregroundStyle(AppTheme.graphite.opacity(0.72))
                            }
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.vertical, AppTheme.Spacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(AppTheme.rule)
                                    .frame(height: 1)
                            }
                        }

                        ScorebookPageSection(dynamicTypeSize.isAccessibilitySize ? nil : "Runner destinations") {
                            ForEach(state.occupiedRunnerSources, id: \.self) { source in
                                ScorebookLedgerRow {
                                    runnerRow(source)
                                }
                            }
                        }

                        if allowsScoring {
                            ScorebookPageSection(dynamicTypeSize.isAccessibilitySize ? nil : "Scoring") {
                                if runsOnPlay > 0 && !needsThirdOutDecision {
                                    ScorebookLedgerRow {
                                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                            Stepper("Runs that count  \(runsCounted)", value: $runsCounted, in: 0...runsOnPlay)
                                                .font(dynamicTypeSize.isAccessibilitySize ? .body : AppTheme.Typography.notation)
                                                .monospacedDigit()
                                                .accessibilityIdentifier("runner.runsCounted")
                                            Text("Every home touch counts unless the play makes the third out.")
                                                .font(AppTheme.Typography.metadata)
                                                .foregroundStyle(AppTheme.graphite.opacity(0.68))
                                        }
                                    }
                                }

                                ScorebookLedgerRow {
                                    Stepper("RBI  \(rbi)", value: $rbi, in: 0...maximumRBI)
                                        .font(dynamicTypeSize.isAccessibilitySize ? .body : AppTheme.Typography.notation)
                                        .monospacedDigit()
                                        .accessibilityIdentifier("runner.rbi")
                                }

                                if needsThirdOutDecision {
                                    ScorebookLedgerRow {
                                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                            ScorebookLabel("Run on third out")
                                            Picker("Third out", selection: $thirdOutClassification) {
                                                Text("Force / Batter").tag(ThirdOutClassification.forceOrBatterRunner)
                                                Text("Timing Play").tag(ThirdOutClassification.timingPlay)
                                            }
                                            .pickerStyle(.segmented)
                                            .accessibilityIdentifier("runner.thirdOutClassification")
                                            Stepper("Runs that count  \(runsCounted)", value: $runsCounted, in: 0...maximumThirdOutRunsCounted)
                                                .font(dynamicTypeSize.isAccessibilitySize ? .body : AppTheme.Typography.notation)
                                                .monospacedDigit()
                                                .accessibilityIdentifier("runner.runsCounted")
                                            Text("For a force/batter-runner third out this is 0. On a timing play, count only runners who crossed home before the third out.")
                                                .font(AppTheme.Typography.metadata)
                                                .foregroundStyle(AppTheme.graphite.opacity(0.68))
                                        }
                                    }
                                }
                            }
                        }

                        ScorebookPageSection {
                            ScorebookLedgerRow {
                                DisclosureGroup("Suggestion help") {
                                    Text("Destinations are a starting point. Change anything that happened differently.")
                                        .font(AppTheme.Typography.body)
                                        .foregroundStyle(AppTheme.graphite.opacity(0.72))
                                        .padding(.top, AppTheme.Spacing.xs)
                                }
                                .font(dynamicTypeSize.isAccessibilitySize ? .callout : .body)
                            }
                        }

                        if let validationError {
                            ScorebookPageSection("Check this play") {
                                ScorebookLedgerRow {
                                    Label(validationMessage(validationError), systemImage: "exclamationmark.triangle")
                                        .font(AppTheme.Typography.body)
                                        .foregroundStyle(AppTheme.destructive)
                                }
                            }
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                }
                .overlay(alignment: .leading) {
                    ScorebookMarginRule()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmationTitle) { validateAndRecord() }
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: destinations) { _, _ in
                validationError = nil
                runsCounted = needsThirdOutDecision
                    ? min(runsCounted, maximumThirdOutRunsCounted)
                    : runsOnPlay
                rbi = min(rbi, maximumRBI)
            }
            .onChange(of: runsCounted) { _, _ in
                validationError = nil
                rbi = min(rbi, maximumRBI)
            }
            .onChange(of: thirdOutClassification) { _, _ in
                validationError = nil
                runsCounted = min(runsCounted, maximumThirdOutRunsCounted)
                rbi = min(rbi, maximumRBI)
            }
        }
    }

    private func runnerRow(_ source: RunnerSource) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppTheme.Spacing.md) {
                runnerIdentity(source)
                Spacer(minLength: AppTheme.Spacing.sm)
                destinationPicker(source)
                    .fixedSize()
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                runnerIdentity(source)
                destinationPicker(source)
            }
        }
        .frame(minHeight: AppTheme.TouchTarget.minimum)
    }

    private func runnerIdentity(_ source: RunnerSource) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(source.label)
                .font(dynamicTypeSize.isAccessibilitySize ? .headline : AppTheme.Typography.notation)
            if let slot = state.runnerSlot(for: source) {
                Text(source == .batter ? "Opponent Batter \(slot)" : "Batter slot \(slot)")
                    .font(dynamicTypeSize.isAccessibilitySize ? .body : AppTheme.Typography.metadata)
                    .foregroundStyle(AppTheme.graphite.opacity(0.68))
            }
        }
    }

    private func destinationPicker(_ source: RunnerSource) -> some View {
        Picker(source.label, selection: destinationBinding(source)) {
            ForEach(legalDestinations(for: source)) { destination in
                Text(destination.label).tag(destination)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .accessibilityIdentifier("runner.destination.\(source.rawValue)")
    }

    private func destinationBinding(_ source: RunnerSource) -> Binding<RunnerDestination> {
        Binding(
            get: { destinations[source] ?? .out },
            set: { destinations[source] = $0 }
        )
    }

    private func legalDestinations(for source: RunnerSource) -> [RunnerDestination] {
        var destinations: [RunnerDestination] = switch source {
        case .batter, .first:
            RunnerDestination.allCases
        case .second:
            [.second, .third, .home, .out]
        case .third:
            [.third, .home, .out]
        }
        if !allowsScoring {
            destinations.removeAll { $0 == .home }
        }
        return destinations
    }

    private func validateAndRecord() {
        if runsOnPlay > 0 && !needsThirdOutDecision && runsCounted != runsOnPlay {
            validationError = .invalidRunCount
            return
        }
        if let error = BallInPlayValidator.validate(draft, state: state, trackedTeamHomeAway: homeAway) {
            validationError = error
        } else {
            onRecord(draft)
        }
    }

    private func validationMessage(_ error: BallInPlayValidationError) -> String {
        switch error {
        case .notDefensiveHalf:
            "Runner destinations can be recorded only while the opponent is batting."
        case .noPendingBallInPlay:
            "The counted Ball In Play pitch is no longer awaiting a result."
        case .batterMismatch:
            "The opponent batter changed before this play was confirmed."
        case .missingRunner(let source):
            "Choose a destination for \(source.label)."
        case .unexpectedRunner(let source):
            "\(source.label) was not on base when this play began."
        case .duplicateRunner(let source):
            "Choose exactly one destination for \(source.label)."
        case .illegalDestination(let source, let destination):
            "\(source.label) cannot finish at \(destination.label) from this starting base."
        case .baseCollision(let destination):
            "Two runners cannot both finish at \(destination.label)."
        case .tooManyOuts:
            "This play would record more than three outs in the inning."
        case .outcomeMismatch:
            "The batter result does not match the selected runner destination."
        case .invalidRunCount:
            "Every home touch must count because this play does not make the third out."
        case .invalidRBI:
            "RBI must be between zero and the legally counted runs on this play."
        case .missingThirdOutRunCount:
            "Choose how many apparent runs count on the third out."
        case .missingThirdOutClassification:
            "Classify the third out as a force/batter-runner out or a timing play."
        case .invalidThirdOutRunCount:
            "Classify the third out and choose how many runs legally count."
        case .unnecessaryThirdOutRunCount:
            "Remove the third-out run count because this play does not create the third out."
        case .unnecessaryThirdOutClassification:
            "Remove the third-out classification because this play does not create the third out."
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

#Preview("Opponent runner confirmation") {
    RunnerConfirmationSheet(
        outcome: .double,
        state: PreviewData.defensiveRunnerConfirmationState,
        homeAway: .home,
        onCancel: {},
        onRecord: { _ in }
    )
}
