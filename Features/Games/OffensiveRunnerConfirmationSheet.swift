import SwiftUI

struct OffensiveRunnerConfirmationSheet: View {
    let outcome: BallInPlayOutcome
    let state: GameState
    let homeAway: HomeAway
    let battingOrder: [TrackedBatterIdentity]
    let onCancel: () -> Void
    let onRecord: (OffensivePlateAppearanceDraft) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var destinations: [RunnerSource: RunnerDestination]
    @State private var rbi: Int
    @State private var countedRunSources: Set<RunnerSource>
    @State private var thirdOutClassification: ThirdOutClassification = .forceOrBatterRunner
    @State private var validationFailed = false

    init(
        outcome: BallInPlayOutcome,
        state: GameState,
        homeAway: HomeAway,
        battingOrder: [TrackedBatterIdentity],
        onCancel: @escaping () -> Void,
        onRecord: @escaping (OffensivePlateAppearanceDraft) -> Void
    ) {
        self.outcome = outcome
        self.state = state
        self.homeAway = homeAway
        self.battingOrder = battingOrder
        self.onCancel = onCancel
        self.onRecord = onRecord

        let suggestion = OffensiveMovementSuggestions.ballInPlay(outcome, state: state)
        _destinations = State(initialValue: Dictionary(
            uniqueKeysWithValues: suggestion.movements.map { ($0.source, $0.destination) }
        ))
        _rbi = State(initialValue: suggestion.rbi)
        _countedRunSources = State(initialValue: Set(suggestion.countedRunSources))
    }

    private var movements: [RunnerMovementEvent] {
        state.occupiedTrackedRunnerSources.compactMap { source in
            destinations[source].map { .init(source: source, destination: $0) }
        }
    }

    private var homeSources: [RunnerSource] {
        movements.filter { $0.destination == .home }.map(\.source)
    }

    private var outsOnPlay: Int {
        movements.filter { $0.destination == .out }.count
    }

    private var needsThirdOutDecision: Bool {
        state.outs + outsOnPlay == 3 && !homeSources.isEmpty
    }

    private var sourcesThatCount: [RunnerSource] {
        if !needsThirdOutDecision { return homeSources }
        return homeSources.filter { countedRunSources.contains($0) }
    }

    private var draft: OffensivePlateAppearanceDraft {
        OffensivePlateAppearanceDraft(
            result: .init(ballInPlayOutcome: outcome),
            movements: movements,
            rbi: rbi,
            countedRunSources: sourcesThatCount,
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
                            ForEach(state.occupiedTrackedRunnerSources, id: \.self) { source in
                                ScorebookLedgerRow {
                                    runnerRow(source)
                                }
                            }
                        }

                        ScorebookPageSection(dynamicTypeSize.isAccessibilitySize ? nil : "Scoring") {
                            ScorebookLedgerRow {
                                Stepper("RBI  \(rbi)", value: $rbi, in: 0...sourcesThatCount.count)
                                    .font(dynamicTypeSize.isAccessibilitySize ? .body : AppTheme.Typography.notation)
                                    .monospacedDigit()
                                    .accessibilityIdentifier("runner.rbi")
                            }

                            if needsThirdOutDecision {
                                ScorebookLedgerRow {
                                    thirdOutControls
                                }
                            }
                        }

                        ScorebookPageSection {
                            ScorebookLedgerRow {
                                DisclosureGroup("Run credit help") {
                                    Text("Runs remain tied to the player who actually crossed home.")
                                        .font(AppTheme.Typography.body)
                                        .foregroundStyle(AppTheme.graphite.opacity(0.72))
                                        .padding(.top, AppTheme.Spacing.xs)
                                }
                                .font(dynamicTypeSize.isAccessibilitySize ? .callout : .body)
                            }
                        }

                        if validationFailed {
                            ScorebookPageSection("Check this play") {
                                ScorebookLedgerRow {
                                    Label(
                                        "The result, runner destinations, outs, runs, or RBI do not form a legal play.",
                                        systemImage: "exclamationmark.triangle"
                                    )
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
            .navigationTitle("Record Our Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Record", action: validateAndRecord)
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: destinations) { _, _ in
                validationFailed = false
                countedRunSources.formIntersection(homeSources)
                if !needsThirdOutDecision { countedRunSources = Set(homeSources) }
                rbi = min(rbi, sourcesThatCount.count)
            }
            .onChange(of: thirdOutClassification) { _, classification in
                validationFailed = false
                countedRunSources = classification == .timingPlay ? Set(homeSources) : []
                rbi = min(rbi, sourcesThatCount.count)
            }
            .onChange(of: countedRunSources) { _, _ in
                validationFailed = false
                rbi = min(rbi, sourcesThatCount.count)
            }
        }
    }

    private var thirdOutControls: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            ScorebookLabel("Run on third out")
            Picker("Third out", selection: $thirdOutClassification) {
                Text("Force / Batter").tag(ThirdOutClassification.forceOrBatterRunner)
                Text("Timing Play").tag(ThirdOutClassification.timingPlay)
            }
            .pickerStyle(.segmented)

            if thirdOutClassification == .timingPlay {
                ForEach(homeSources, id: \.self) { source in
                    Toggle("\(runnerName(for: source)) scored before the out", isOn: countedBinding(source))
                }
            } else {
                Text("No run can score when the third out is a force or the batter-runner is out before reaching first.")
                    .font(AppTheme.Typography.metadata)
                    .foregroundStyle(AppTheme.graphite.opacity(0.68))
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
            Text(runnerName(for: source))
                .font(dynamicTypeSize.isAccessibilitySize ? .headline : AppTheme.Typography.notation)
            Text(source.label)
                .font(dynamicTypeSize.isAccessibilitySize ? .body : AppTheme.Typography.metadata)
                .foregroundStyle(AppTheme.graphite.opacity(0.68))
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

    private func runnerName(for source: RunnerSource) -> String {
        let playerID: UUID?
        switch source {
        case .batter:
            playerID = battingOrder.first(where: { $0.lineupSlot == state.currentTrackedBatterSlot })?.playerID
        case .first:
            playerID = state.firstBaseRunnerPlayerID
        case .second:
            playerID = state.secondBaseRunnerPlayerID
        case .third:
            playerID = state.thirdBaseRunnerPlayerID
        }
        return battingOrder.first(where: { $0.playerID == playerID })?.displayName ?? source.label
    }

    private func destinationBinding(_ source: RunnerSource) -> Binding<RunnerDestination> {
        Binding(
            get: { destinations[source] ?? .out },
            set: { destinations[source] = $0 }
        )
    }

    private func countedBinding(_ source: RunnerSource) -> Binding<Bool> {
        Binding(
            get: { countedRunSources.contains(source) },
            set: { counts in
                if counts { countedRunSources.insert(source) }
                else { countedRunSources.remove(source) }
            }
        )
    }

    private func legalDestinations(for source: RunnerSource) -> [RunnerDestination] {
        switch source {
        case .batter, .first: RunnerDestination.allCases
        case .second: [.second, .third, .home, .out]
        case .third: [.third, .home, .out]
        }
    }

    private func validateAndRecord() {
        guard let batter = battingOrder.first(where: { $0.lineupSlot == state.currentTrackedBatterSlot }) else {
            validationFailed = true
            return
        }
        let event = OffensivePlateAppearanceEvent(
            batter: batter,
            battingOrderSize: battingOrder.count,
            result: draft.result,
            movements: draft.movements,
            rbi: draft.rbi,
            countedRunSources: draft.countedRunSources,
            thirdOutClassification: draft.thirdOutClassification
        )
        guard OffensivePlateAppearanceValidator.isValid(
            event,
            state: state,
            trackedTeamHomeAway: homeAway
        ) else {
            validationFailed = true
            return
        }
        onRecord(draft)
    }
}

#Preview("Our runner confirmation") {
    OffensiveRunnerConfirmationSheet(
        outcome: .double,
        state: PreviewData.offensiveRunnerConfirmationState,
        homeAway: .away,
        battingOrder: PreviewData.runnerConfirmationBattingOrder,
        onCancel: {},
        onRecord: { _ in }
    )
}

#Preview("Our runner confirmation · Accessibility XL") {
    OffensiveRunnerConfirmationSheet(
        outcome: .double,
        state: PreviewData.offensiveRunnerConfirmationState,
        homeAway: .away,
        battingOrder: PreviewData.runnerConfirmationBattingOrder,
        onCancel: {},
        onRecord: { _ in }
    )
    .environment(\.dynamicTypeSize, .accessibility3)
}
