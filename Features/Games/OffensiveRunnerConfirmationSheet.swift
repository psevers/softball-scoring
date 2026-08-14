import SwiftUI

struct OffensiveRunnerConfirmationSheet: View {
    let result: OffensivePlateAppearanceResult
    let state: GameState
    let homeAway: HomeAway
    let battingOrder: [TrackedBatterIdentity]
    let batter: TrackedBatterIdentity?
    let battingOrderSize: Int?
    let allowsScoring: Bool
    let title: String
    let confirmationTitle: String
    let onCancel: () -> Void
    let onRecord: (OffensivePlateAppearanceDraft) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var destinations: [RunnerSource: RunnerDestination]
    @State private var rbi: Int
    @State private var countedRunSources: Set<RunnerSource>
    @State private var thirdOutClassification: ThirdOutClassification = .forceOrBatterRunner
    @State private var validationError: OffensivePlateAppearanceValidationError?

    init(
        outcome: BallInPlayOutcome,
        state: GameState,
        homeAway: HomeAway,
        battingOrder: [TrackedBatterIdentity],
        onCancel: @escaping () -> Void,
        onRecord: @escaping (OffensivePlateAppearanceDraft) -> Void
    ) {
        self.init(
            result: .init(ballInPlayOutcome: outcome),
            state: state,
            homeAway: homeAway,
            battingOrder: battingOrder,
            batter: nil,
            battingOrderSize: nil,
            seedDraft: nil,
            allowsScoring: true,
            title: "Record Our Play",
            confirmationTitle: "Record",
            onCancel: onCancel,
            onRecord: onRecord
        )
    }

    init(
        result: OffensivePlateAppearanceResult,
        state: GameState,
        homeAway: HomeAway,
        battingOrder: [TrackedBatterIdentity],
        batter: TrackedBatterIdentity,
        battingOrderSize: Int,
        initialDraft: OffensivePlateAppearanceDraft,
        allowsScoring: Bool,
        title: String,
        confirmationTitle: String,
        onCancel: @escaping () -> Void,
        onRecord: @escaping (OffensivePlateAppearanceDraft) -> Void
    ) {
        self.init(
            result: result,
            state: state,
            homeAway: homeAway,
            battingOrder: battingOrder,
            batter: batter,
            battingOrderSize: battingOrderSize,
            seedDraft: initialDraft,
            allowsScoring: allowsScoring,
            title: title,
            confirmationTitle: confirmationTitle,
            onCancel: onCancel,
            onRecord: onRecord
        )
    }

    private init(
        result: OffensivePlateAppearanceResult,
        state: GameState,
        homeAway: HomeAway,
        battingOrder: [TrackedBatterIdentity],
        batter: TrackedBatterIdentity?,
        battingOrderSize: Int?,
        seedDraft: OffensivePlateAppearanceDraft?,
        allowsScoring: Bool,
        title: String,
        confirmationTitle: String,
        onCancel: @escaping () -> Void,
        onRecord: @escaping (OffensivePlateAppearanceDraft) -> Void
    ) {
        self.result = result
        self.state = state
        self.homeAway = homeAway
        self.battingOrder = battingOrder
        self.batter = batter
        self.battingOrderSize = battingOrderSize
        self.allowsScoring = allowsScoring
        self.title = title
        self.confirmationTitle = confirmationTitle
        self.onCancel = onCancel
        self.onRecord = onRecord

        let suggestion = seedDraft ?? Self.suggestion(for: result, state: state)
        _destinations = State(initialValue: Dictionary(
            uniqueKeysWithValues: suggestion.movements.map { ($0.source, $0.destination) }
        ))
        _rbi = State(initialValue: suggestion.rbi)
        _countedRunSources = State(initialValue: Set(suggestion.countedRunSources))
        _thirdOutClassification = State(
            initialValue: suggestion.thirdOutClassification ?? .forceOrBatterRunner
        )
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
            result: result,
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
                                Text(result.label)
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

                        if allowsScoring {
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

                        if let validationError {
                            ScorebookPageSection("Check this play") {
                                ScorebookLedgerRow {
                                    Label(
                                        validationMessage(validationError),
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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmationTitle, action: validateAndRecord)
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: destinations) { _, _ in
                validationError = nil
                countedRunSources.formIntersection(homeSources)
                if !needsThirdOutDecision { countedRunSources = Set(homeSources) }
                rbi = min(rbi, sourcesThatCount.count)
            }
            .onChange(of: thirdOutClassification) { _, classification in
                validationError = nil
                countedRunSources = classification == .timingPlay ? Set(homeSources) : []
                rbi = min(rbi, sourcesThatCount.count)
            }
            .onChange(of: countedRunSources) { _, _ in
                validationError = nil
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
        Menu {
            ForEach(legalDestinations(for: source)) { destination in
                Button(destination.label) {
                    destinations[source] = destination
                }
            }
        } label: {
            Text((destinations[source] ?? .out).label)
                .frame(
                    minWidth: AppTheme.TouchTarget.minimum,
                    minHeight: AppTheme.TouchTarget.minimum + 1
                )
        }
        .accessibilityLabel(source.label)
        .accessibilityValue((destinations[source] ?? .out).label)
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
        let destinations: [RunnerDestination] = switch source {
        case .batter, .first: RunnerDestination.allCases
        case .second: [.second, .third, .home, .out]
        case .third: [.third, .home, .out]
        }
        return allowsScoring ? destinations : destinations.filter { $0 != .home }
    }

    private func validateAndRecord() {
        guard let resolvedBatter = batter
                ?? battingOrder.first(where: { $0.lineupSlot == state.currentTrackedBatterSlot }) else {
            validationError = .invalidBatter
            return
        }
        let event = OffensivePlateAppearanceEvent(
            batter: resolvedBatter,
            battingOrderSize: battingOrderSize ?? battingOrder.count,
            result: draft.result,
            movements: draft.movements,
            rbi: draft.rbi,
            countedRunSources: draft.countedRunSources,
            thirdOutClassification: draft.thirdOutClassification
        )
        if let error = OffensivePlateAppearanceValidator.validate(
            event,
            state: state,
            trackedTeamHomeAway: homeAway
        ) {
            validationError = error
        } else {
            onRecord(draft)
        }
    }

    private func validationMessage(_ error: OffensivePlateAppearanceValidationError) -> String {
        switch error {
        case .notOffensiveHalf:
            "Runner destinations can be recorded only while our team is batting."
        case .invalidBatter:
            "The tracked batter or batting order changed before this play was confirmed."
        case .missingRunner(let source):
            "Choose a destination for \(source.label)."
        case .unexpectedRunner(let source):
            "\(source.label) was not part of this plate appearance."
        case .duplicateRunner(let source):
            "Choose exactly one destination for \(source.label)."
        case .illegalDestination(let source, let destination):
            "\(source.label) cannot finish at \(destination.label) from this starting base."
        case .baseCollision(let destination):
            "Two runners cannot both finish at \(destination.label)."
        case .runnerPassing(let source, let destination):
            "\(source.label) cannot reach \(destination.label) by passing a runner ahead."
        case .tooManyOuts:
            "This play would record more than three outs in the inning."
        case .invalidRunSources:
            "Count exactly the runners whose home touches legally score on this play."
        case .invalidRBI:
            "RBI must be between zero and the legally counted runs on this play."
        case .invalidThirdOutClassification:
            "Classify a run with the third out before choosing which home touches count."
        case .outcomeMismatch:
            "The batter result does not match the selected runner destinations."
        }
    }

    private static func suggestion(
        for result: OffensivePlateAppearanceResult,
        state: GameState
    ) -> OffensivePlateAppearanceDraft {
        let suggestion: OffensiveMovementSuggestion = switch result {
        case .walk, .hitByPitch:
            OffensiveMovementSuggestions.awardedFirstBase(state: state)
        case .strikeout:
            OffensiveMovementSuggestions.strikeout(state: state)
        case .homeRun:
            OffensiveMovementSuggestions.homeRun(state: state)
        case .single:
            OffensiveMovementSuggestions.ballInPlay(.single, state: state)
        case .double:
            OffensiveMovementSuggestions.ballInPlay(.double, state: state)
        case .triple:
            OffensiveMovementSuggestions.ballInPlay(.triple, state: state)
        case .reachedOnError:
            OffensiveMovementSuggestions.ballInPlay(.reachedOnError, state: state)
        case .fieldersChoice:
            OffensiveMovementSuggestions.ballInPlay(.fieldersChoice, state: state)
        case .groundOut:
            OffensiveMovementSuggestions.ballInPlay(.groundOut, state: state)
        case .flyOut:
            OffensiveMovementSuggestions.ballInPlay(.flyOut, state: state)
        case .lineOut:
            OffensiveMovementSuggestions.ballInPlay(.lineOut, state: state)
        case .popOut:
            OffensiveMovementSuggestions.ballInPlay(.popOut, state: state)
        case .sacrificeBunt:
            OffensiveMovementSuggestions.ballInPlay(.sacrificeBunt, state: state)
        case .sacrificeFly:
            OffensiveMovementSuggestions.ballInPlay(.sacrificeFly, state: state)
        case .doublePlay:
            OffensiveMovementSuggestions.ballInPlay(.doublePlay, state: state)
        }
        return OffensivePlateAppearanceDraft(
            result: result,
            movements: suggestion.movements,
            rbi: suggestion.rbi,
            countedRunSources: suggestion.countedRunSources,
            thirdOutClassification: nil
        )
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
