import SwiftUI
import SwiftData

struct LiveGameView: View {
    let game: Game

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GameEventRecord.sequenceNumber) private var allEventRecords: [GameEventRecord]
    @Query(sort: [SortDescriptor(\Player.lastName), SortDescriptor(\Player.firstName)]) private var players: [Player]

    @State private var errorMessage: String?
    @State private var feedbackTick = 0
    @State private var selectedOutcome: BallInPlayOutcome?

    private var gameRecords: [GameEventRecord] {
        allEventRecords.filter { $0.gameID == game.id }
    }

    private var validatedHomeAway: HomeAway? {
        HomeAway(rawValue: game.homeAwayRawValue)
    }

    private var homeAway: HomeAway {
        validatedHomeAway ?? .away
    }

    private var replay: GameEventReplay.Result {
        guard let validatedHomeAway else {
            return GameEventReplay.Result(state: GameState(), rejectedRecordIDs: [])
        }
        return GameEventReplay.replay(
            records: gameRecords,
            homeAway: validatedHomeAway,
            startingPitcherID: game.startingPitcherID
        )
    }

    private var state: GameState { replay.state }

    private var pitcher: Player? {
        guard let pitcherID = game.startingPitcherID else { return nil }
        return players.first { $0.id == pitcherID }
    }

    private var pitcherCount: PitchCount {
        guard let pitcherID = game.startingPitcherID else { return PitchCount() }
        return state.pitchCount(for: pitcherID)
    }

    var body: some View {
        ZStack {
            ScorebookPaperBackground(gridSpacing: 22)

            ScrollView {
                VStack(spacing: AppTheme.Spacing.md) {
                    scoreHeader
                    inningCard

                    if validatedHomeAway == nil || !replay.rejectedRecordIDs.isEmpty {
                        historyWarning
                    } else if state.isOpponentBatting(homeAway: homeAway) {
                        defensiveScoringSurface
                    } else {
                        offensePlaceholder
                    }
                }
                .padding(AppTheme.Spacing.md)
            }
        }
        .navigationTitle(game.opponentName)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Scoring Paused", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "The play could not be saved.")
        }
        .sheet(item: $selectedOutcome) { outcome in
            RunnerConfirmationSheet(
                outcome: outcome,
                state: state,
                homeAway: homeAway,
                onCancel: { selectedOutcome = nil },
                onRecord: recordBallInPlay
            )
            .presentationDetents([.large])
            .interactiveDismissDisabled()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackTick)
    }

    private var scoreHeader: some View {
        ScorebookSheet {
            VStack(spacing: AppTheme.Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(homeAway == .home ? game.opponentName.uppercased() : "US")
                            .font(.caption.weight(.semibold))
                        Text("\(state.awayScore)")
                            .font(.system(size: 32, weight: .semibold, design: .serif).monospacedDigit())
                    }
                    Spacer()
                    Text("\(state.half.displayName.uppercased()) \(state.inning)")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.graphite.opacity(0.8))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(homeAway == .home ? "US" : game.opponentName.uppercased())
                            .font(.caption.weight(.semibold))
                        Text("\(state.homeScore)")
                            .font(.system(size: 32, weight: .semibold, design: .serif).monospacedDigit())
                    }
                }

                Rectangle().fill(AppTheme.rule).frame(height: 1)

                HStack {
                    Text(homeAway == .home ? "Opponent is away" : "Opponent is home")
                    Spacer()
                    Text(game.gameDate.formatted(date: .abbreviated, time: .omitted))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var inningCard: some View {
        ScorebookSheet {
            HStack(spacing: AppTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("OUTS")
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                    HStack(spacing: AppTheme.Spacing.sm) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(index < state.outs ? AppTheme.graphite : Color.clear)
                                .overlay(Circle().stroke(AppTheme.graphite.opacity(0.7), lineWidth: 1))
                                .frame(width: 15, height: 15)
                        }
                    }

                    Text("COUNT")
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .padding(.top, AppTheme.Spacing.xs)
                    Text("\(state.balls) – \(state.strikes)")
                        .font(.title2.bold().monospacedDigit())
                }

                Spacer()

                ScorebookDiamondView(
                    firstBaseRunner: state.firstBaseRunnerSlot,
                    secondBaseRunner: state.secondBaseRunnerSlot,
                    thirdBaseRunner: state.thirdBaseRunnerSlot
                )
                .frame(width: 128, height: 128)
            }
        }
    }

    private var defensiveScoringSurface: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ScorebookSheet {
                VStack(spacing: AppTheme.Spacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PITCHER")
                                .font(.caption2.weight(.bold))
                                .tracking(1.2)
                            Text(pitcher?.displayName ?? "Starting Pitcher")
                                .font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("PITCHES")
                                .font(.caption2.weight(.bold))
                                .tracking(1.2)
                            Text("\(pitcherCount.total)")
                                .font(.title2.bold().monospacedDigit())
                        }
                    }

                    Rectangle().fill(AppTheme.rule).frame(height: 1)

                    HStack {
                        Text("Opponent Batter \(state.currentOpponentBatterSlot)")
                            .font(.headline)
                        Spacer()
                        Text("B \(pitcherCount.balls)  ·  S \(pitcherCount.strikes)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if state.isAwaitingBallInPlayResult {
                outcomePad
            } else {
                pitchPad
            }
        }
    }

    private var pitchPad: some View {
        ScorebookSheet {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("PITCH")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                    pitchButton(.ball)
                    pitchButton(.calledStrike)
                    pitchButton(.swingingStrike)
                    pitchButton(.foul)
                    pitchButton(.ballInPlay)
                    pitchButton(.hitByPitch)
                }
            }
        }
    }

    private var outcomePad: some View {
        ScorebookSheet {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BALL IN PLAY")
                            .font(.caption2.weight(.bold))
                            .tracking(1.2)
                        Text("What happened?")
                            .font(.headline)
                    }
                    Spacer()
                    Image(systemName: "pencil.line")
                        .foregroundStyle(AppTheme.graphite.opacity(0.65))
                }

                outcomeSection("HIT", [.single, .double, .triple, .homeRun])
                outcomeSection("REACHED", [.reachedOnError, .fieldersChoice])
                outcomeSection("OUT", [.groundOut, .flyOut, .lineOut, .popOut, .sacrificeBunt, .sacrificeFly, .doublePlay])

                Text("The pitch is already counted. Finish this play before scoring the next pitch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func outcomeSection(_ title: String, _ outcomes: [BallInPlayOutcome]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: AppTheme.Spacing.xs)], spacing: AppTheme.Spacing.xs) {
                ForEach(outcomes) { outcome in
                    Button {
                        selectedOutcome = outcome
                    } label: {
                        Text(outcome.shortLabel)
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.gameAction)
                            .foregroundStyle(AppTheme.graphite)
                            .background(AppTheme.paper)
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                                    .stroke(AppTheme.graphite.opacity(0.5), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func pitchButton(_ result: PitchResult) -> some View {
        Button {
            recordPitch(result)
        } label: {
            Text(result.shortLabel)
                .font(.headline)
                .foregroundStyle(AppTheme.graphite)
                .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.gameAction)
                .background(AppTheme.paper)
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                        .stroke(AppTheme.graphite.opacity(0.55), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(!replay.rejectedRecordIDs.isEmpty)
        .accessibilityLabel(result.label)
    }

    private var historyWarning: some View {
        ScorebookSheet {
            Label(
                "Saved game data is unreadable. New scoring is disabled to avoid compounding the problem.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.subheadline)
        }
    }

    private var offensePlaceholder: some View {
        ScorebookSheet {
            VStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "pencil.and.outline")
                    .font(.title2)
                Text("Our Half-Inning")
                    .font(.headline)
                Text("The defensive scoring engine is live. Player-attributed offensive scoring arrives in Slice 5.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func recordPitch(_ result: PitchResult) {
        do {
            try GameEventRecorder.recordPitch(
                result: result,
                game: game,
                existingRecords: gameRecords,
                modelContext: modelContext
            )
            feedbackTick += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recordBallInPlay(_ play: BallInPlayEvent) {
        do {
            try GameEventRecorder.recordBallInPlay(
                play: play,
                game: game,
                existingRecords: gameRecords,
                modelContext: modelContext
            )
            selectedOutcome = nil
            feedbackTick += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        Text("Create a game in preview data to exercise LiveGameView")
    }
    .modelContainer(PreviewData.container)
}
