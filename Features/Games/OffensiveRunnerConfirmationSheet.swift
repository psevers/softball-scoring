import SwiftUI

struct OffensiveRunnerConfirmationSheet: View {
    let outcome: BallInPlayOutcome
    let state: GameState
    let homeAway: HomeAway
    let battingOrder: [TrackedBatterIdentity]
    let onCancel: () -> Void
    let onRecord: (OffensivePlateAppearanceDraft) -> Void

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
                ScorebookPaperBackground(gridSpacing: 22)

                ScrollView {
                    VStack(spacing: AppTheme.Spacing.md) {
                        ScorebookSheet {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                                Text(outcome.label)
                                    .font(.title2.weight(.semibold))
                                Text("Confirm every runner's destination. Runs remain tied to the player who actually crossed home.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ScorebookSheet {
                            VStack(spacing: AppTheme.Spacing.sm) {
                                ForEach(state.occupiedTrackedRunnerSources, id: \.self) { source in
                                    runnerRow(source)
                                    if source != state.occupiedTrackedRunnerSources.last {
                                        Rectangle().fill(AppTheme.rule).frame(height: 1)
                                    }
                                }
                            }
                        }

                        ScorebookSheet {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                                Stepper("RBI  \(rbi)", value: $rbi, in: 0...sourcesThatCount.count)
                                    .font(.headline)

                                if needsThirdOutDecision {
                                    thirdOutControls
                                }
                            }
                        }

                        if validationFailed {
                            ScorebookSheet {
                                Label(
                                    "The result, runner destinations, outs, runs, or RBI do not form a legal play.",
                                    systemImage: "exclamationmark.triangle"
                                )
                                .font(.subheadline)
                            }
                        }
                    }
                    .padding(AppTheme.Spacing.md)
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
            Text("RUN ON THIRD OUT")
                .font(.caption2.weight(.bold))
                .tracking(1.2)
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func runnerRow(_ source: RunnerSource) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.label)
                    .font(.headline)
                Text(runnerName(for: source))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
