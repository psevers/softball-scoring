import Testing
import UIKit
@testable import SoftballScoring

struct DesignSystemTests {
    @Test func bundledExpressiveFontIsAvailableAtRuntime() {
        #expect(UIFont(name: "PatrickHand-Regular", size: 20) != nil)
    }
}
