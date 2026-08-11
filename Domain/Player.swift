import Foundation
import SwiftData

enum BattingSide: String, CaseIterable, Codable, Identifiable {
    case right = "Right"
    case left = "Left"
    case switchHitter = "Switch"

    var id: String { rawValue }
}

enum ThrowingHand: String, CaseIterable, Codable, Identifiable {
    case right = "Right"
    case left = "Left"

    var id: String { rawValue }
}

enum DefensivePosition: String, CaseIterable, Codable, Identifiable, Sendable {
    case pitcher = "P"
    case catcher = "C"
    case firstBase = "1B"
    case secondBase = "2B"
    case thirdBase = "3B"
    case shortstop = "SS"
    case leftField = "LF"
    case centerField = "CF"
    case rightField = "RF"
    case utility = "UTIL"

    var id: String { rawValue }
}

@Model
final class Player {
    @Attribute(.unique) var id: UUID
    var firstName: String
    var lastName: String
    var jerseyNumber: String
    var battingSideRawValue: String
    var throwingHandRawValue: String
    var defaultPositionRawValue: String
    var isActive: Bool
    var createdAt: Date

    var displayName: String {
        let name = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? "Unnamed Player" : name
    }

    var battingSide: BattingSide {
        get { BattingSide(rawValue: battingSideRawValue) ?? .right }
        set { battingSideRawValue = newValue.rawValue }
    }

    var throwingHand: ThrowingHand {
        get { ThrowingHand(rawValue: throwingHandRawValue) ?? .right }
        set { throwingHandRawValue = newValue.rawValue }
    }

    var defaultPosition: DefensivePosition? {
        get { DefensivePosition(rawValue: defaultPositionRawValue) }
        set { defaultPositionRawValue = newValue?.rawValue ?? "" }
    }

    init(
        id: UUID = UUID(),
        firstName: String,
        lastName: String,
        jerseyNumber: String = "",
        battingSide: BattingSide = .right,
        throwingHand: ThrowingHand = .right,
        defaultPosition: DefensivePosition? = nil,
        isActive: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.jerseyNumber = jerseyNumber
        self.battingSideRawValue = battingSide.rawValue
        self.throwingHandRawValue = throwingHand.rawValue
        self.defaultPositionRawValue = defaultPosition?.rawValue ?? ""
        self.isActive = isActive
        self.createdAt = createdAt
    }
}
