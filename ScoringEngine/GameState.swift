import Foundation

enum InningHalf: String, Codable, Sendable {
    case top
    case bottom

    var displayName: String { self == .top ? "Top" : "Bottom" }
}

struct PitchCount: Equatable, Sendable {
    var total: Int = 0
    var balls: Int = 0
    var strikes: Int = 0

    var strikePercentage: Double {
        guard total > 0 else { return 0 }
        return Double(strikes) / Double(total)
    }
}

struct GameState: Equatable, Sendable {
    var inning: Int = 1
    var half: InningHalf = .top
    var outs: Int = 0
    var balls: Int = 0
    var strikes: Int = 0
    var homeScore: Int = 0
    var awayScore: Int = 0

    /// Opponent batting order is deliberately lightweight in the MVP.
    /// Slots rotate 1...9 and can later be associated with opponent names.
    var currentOpponentBatterSlot: Int = 1

    var firstBaseRunnerSlot: Int?
    var secondBaseRunnerSlot: Int?
    var thirdBaseRunnerSlot: Int?

    /// A ball-in-play pitch is counted immediately, then the play result completes the PA.
    /// While this is true, no additional pitch may be recorded.
    var isAwaitingBallInPlayResult = false

    var pitchCountsByPitcher: [UUID: PitchCount] = [:]

    var baseRunnerSlots: [Int?] {
        [firstBaseRunnerSlot, secondBaseRunnerSlot, thirdBaseRunnerSlot]
    }

    func pitchCount(for pitcherID: UUID) -> PitchCount {
        pitchCountsByPitcher[pitcherID, default: PitchCount()]
    }

    func runnerSlot(for source: RunnerSource) -> Int? {
        switch source {
        case .batter: currentOpponentBatterSlot
        case .first: firstBaseRunnerSlot
        case .second: secondBaseRunnerSlot
        case .third: thirdBaseRunnerSlot
        }
    }

    var occupiedRunnerSources: [RunnerSource] {
        var result: [RunnerSource] = [.batter]
        if firstBaseRunnerSlot != nil { result.append(.first) }
        if secondBaseRunnerSlot != nil { result.append(.second) }
        if thirdBaseRunnerSlot != nil { result.append(.third) }
        return result
    }

    func isTrackedTeamBatting(homeAway: HomeAway) -> Bool {
        switch (half, homeAway) {
        case (.top, .away), (.bottom, .home): true
        default: false
        }
    }

    func isOpponentBatting(homeAway: HomeAway) -> Bool {
        !isTrackedTeamBatting(homeAway: homeAway)
    }
}
