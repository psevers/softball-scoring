import Testing
@testable import SoftballScoring

struct PlayerTests {
    @Test func displayNameCombinesFirstAndLastName() {
        let player = Player(firstName: "Maya", lastName: "Jones", jerseyNumber: "7")
        #expect(player.displayName == "Maya Jones")
    }

    @Test func displayNameTrimsWhitespace() {
        let player = Player(firstName: " Maya ", lastName: " Jones ")
        #expect(player.displayName == "Maya Jones")
    }

    @Test func playerDefaultsRoundTripThroughRawValues() {
        let player = Player(
            firstName: "Maya",
            lastName: "Jones",
            battingSide: .left,
            throwingHand: .right,
            defaultPosition: .shortstop
        )

        #expect(player.battingSide == .left)
        #expect(player.throwingHand == .right)
        #expect(player.defaultPosition == .shortstop)
    }
}
