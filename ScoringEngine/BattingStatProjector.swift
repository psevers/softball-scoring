import Foundation

struct BattingLine: Equatable, Sendable {
    var plateAppearances = 0
    var atBats = 0
    var runs = 0
    var hits = 0
    var doubles = 0
    var triples = 0
    var homeRuns = 0
    var runsBattedIn = 0
    var walks = 0
    var hitByPitch = 0
    var strikeouts = 0
    var stolenBases = 0
    var caughtStealing = 0
}

enum BattingStatProjectionError: Error, Equatable {
    case missingRunnerIdentity(sequenceNumber: Int, source: RunnerSource)
}

enum BattingStatProjector {
    /// Projects accepted event history. Corrupt or rejected records must be removed by replay first.
    static func project(events: [DecodedGameEvent]) throws -> [UUID: BattingLine] {
        var lines: [UUID: BattingLine] = [:]
        var firstBaseRunnerID: UUID?
        var secondBaseRunnerID: UUID?
        var thirdBaseRunnerID: UUID?

        for event in events.sorted(by: { $0.sequenceNumber < $1.sequenceNumber }) {
            if case .offensiveBaseRunning(let baseRunning) = event.body {
                var runnerLine = lines[baseRunning.runnerID, default: BattingLine()]
                switch baseRunning.result {
                case .stolenBase:
                    runnerLine.stolenBases += 1
                    if baseRunning.destination == .home { runnerLine.runs += 1 }
                case .caughtStealing:
                    runnerLine.caughtStealing += 1
                }
                lines[baseRunning.runnerID] = runnerLine

                switch baseRunning.source {
                case .batter: break
                case .first: firstBaseRunnerID = nil
                case .second: secondBaseRunnerID = nil
                case .third: thirdBaseRunnerID = nil
                }
                switch baseRunning.destination {
                case .first: firstBaseRunnerID = baseRunning.runnerID
                case .second: secondBaseRunnerID = baseRunning.runnerID
                case .third: thirdBaseRunnerID = baseRunning.runnerID
                case .home, .out: break
                }
                continue
            }

            guard case .offensivePlateAppearance(let plateAppearance) = event.body else { continue }

            let batterID = plateAppearance.batter.playerID
            var batterLine = lines[batterID, default: BattingLine()]
            batterLine.plateAppearances += 1
            batterLine.runsBattedIn += plateAppearance.rbi

            switch plateAppearance.result {
            case .single:
                batterLine.atBats += 1
                batterLine.hits += 1
            case .double:
                batterLine.atBats += 1
                batterLine.hits += 1
                batterLine.doubles += 1
            case .triple:
                batterLine.atBats += 1
                batterLine.hits += 1
                batterLine.triples += 1
            case .homeRun:
                batterLine.atBats += 1
                batterLine.hits += 1
                batterLine.homeRuns += 1
            case .walk:
                batterLine.walks += 1
            case .hitByPitch:
                batterLine.hitByPitch += 1
            case .strikeout:
                batterLine.atBats += 1
                batterLine.strikeouts += 1
            case .sacrificeBunt, .sacrificeFly:
                break
            case .reachedOnError, .fieldersChoice, .groundOut, .flyOut, .lineOut, .popOut, .doublePlay:
                batterLine.atBats += 1
            }
            lines[batterID] = batterLine

            let runnerIDs: [RunnerSource: UUID] = [
                .batter: batterID,
                .first: firstBaseRunnerID,
                .second: secondBaseRunnerID,
                .third: thirdBaseRunnerID
            ].compactMapValues { $0 }

            for source in plateAppearance.countedRunSources {
                guard let runnerID = runnerIDs[source] else {
                    throw BattingStatProjectionError.missingRunnerIdentity(
                        sequenceNumber: event.sequenceNumber,
                        source: source
                    )
                }
                var runnerLine = lines[runnerID, default: BattingLine()]
                runnerLine.runs += 1
                lines[runnerID] = runnerLine
            }

            firstBaseRunnerID = nil
            secondBaseRunnerID = nil
            thirdBaseRunnerID = nil
            for movement in plateAppearance.movements {
                guard let runnerID = runnerIDs[movement.source] else {
                    throw BattingStatProjectionError.missingRunnerIdentity(
                        sequenceNumber: event.sequenceNumber,
                        source: movement.source
                    )
                }
                switch movement.destination {
                case .first: firstBaseRunnerID = runnerID
                case .second: secondBaseRunnerID = runnerID
                case .third: thirdBaseRunnerID = runnerID
                case .home, .out: break
                }
            }
        }

        return lines
    }
}
