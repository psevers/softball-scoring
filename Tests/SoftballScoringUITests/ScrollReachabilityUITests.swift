import XCTest

@MainActor
final class ScrollReachabilityUITests: XCTestCase {
    func testTimeLimitUsesKeyboardFreeThirtyToNinetyMinuteWheel() {
        let app = launchApp()
        app.tabBars.buttons["Games"].tap()
        app.buttons["New Game"].tap()
        app.buttons["Time Limit"].tap()

        let wheel = app.pickerWheels.firstMatch
        XCTAssertTrue(wheel.waitForExistence(timeout: 2))
        XCTAssertFalse(app.keyboards.firstMatch.exists)

        wheel.adjust(toPickerWheelValue: "90 minutes")
        XCTAssertEqual(wheel.value as? String, "90 minutes")
        wheel.adjust(toPickerWheelValue: "30 minutes")
        XCTAssertEqual(wheel.value as? String, "30 minutes")

        XCTAssertTrue(swipeUntilHittable(
            app.buttons["Set Lineup"],
            in: app,
            listIdentifier: "game.setup.form"
        ))
    }

    func testTeamRosterSwipeReachesInactivePlayerAndOpensEditor() {
        let app = launchApp()
        app.tabBars.buttons["Team"].tap()

        let lastPlayer = app.staticTexts["Player 15"]
        XCTAssertTrue(swipeUntilHittable(lastPlayer, in: app, listIdentifier: "team.roster.list"))
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Player 15")).firstMatch.tap()
        XCTAssertTrue(app.textFields["First name"].waitForExistence(timeout: 2))
    }

    func testSetLineupSwipeReachesCompleteFourteenPlayerBattingOrder() {
        let app = launchApp()
        app.tabBars.buttons["Games"].tap()
        app.buttons["New Game"].tap()
        app.textFields["Opponent"].tap()
        app.textFields["Opponent"].typeText("Test Opponent")
        app.keyboards.buttons["return"].tap()
        app.buttons["Set Lineup"].tap()
        let startGame = app.buttons["Start Game"]

        for index in 1...14 {
            let playerName = String(format: "Player %02d", index)
            let addPlayer = app.buttons["lineup.add.\(playerName)"]
            XCTAssertTrue(
                swipeUntilHittable(addPlayer, in: app, above: startGame),
                "Player \(index) was not reachable"
            )
            waitForScrollToSettle()
            addPlayer.tap()
            let defenderCount = min(index, 9)
            XCTAssertTrue(
                waitForValue(
                    "\(index) batters, \(defenderCount) of 9 fielders",
                    on: startGame
                ),
                "Player \(index) was not added; add frame \(addPlayer.frame), Start frame \(startGame.frame), value \(String(describing: startGame.value))"
            )
        }

        let lastBatter = app.staticTexts["Player 14"]
        XCTAssertTrue(swipeUntilHittable(lastBatter, in: app, listIdentifier: "lineup.list"))

        let pitcher = app.buttons["lineup.pitcher"]
        XCTAssertTrue(swipeUntilHittable(pitcher, in: app, listIdentifier: "lineup.list"))

        let summary = app.staticTexts["lineup.summary"]
        XCTAssertTrue(swipeDownUntilHittable(summary, in: app, listIdentifier: "lineup.list"))
        XCTAssertEqual(summary.label, "14 batters · 9 / 9 fielders")

        XCTAssertTrue(startGame.isHittable)
        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: startGame
        )
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 3), .completed)

        startGame.tap()
        let savedGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Test Opponent")
        ).firstMatch
        XCTAssertTrue(savedGame.waitForExistence(timeout: 5))
        savedGame.tap()
        XCTAssertTrue(app.navigationBars["Test Opponent"].waitForExistence(timeout: 3))
    }

    private func launchApp() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        return app
    }

    private func swipeUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        listIdentifier: String = "lineup.list",
        above obstruction: XCUIElement? = nil
    ) -> Bool {
        let list = app.collectionViews[listIdentifier]
        guard list.waitForExistence(timeout: 2) else { return false }

        let deadline = Date().addingTimeInterval(15)
        while !isSafelyHittable(element, in: list, above: obstruction) && Date() < deadline {
            if element.exists && element.frame.minY < list.frame.minY {
                dragDown(in: list)
            } else {
                dragUp(in: list)
            }
        }
        return isSafelyHittable(element, in: list, above: obstruction)
    }

    private func isSafelyHittable(
        _ element: XCUIElement,
        in list: XCUIElement,
        above obstruction: XCUIElement?
    ) -> Bool {
        guard element.isHittable else { return false }
        guard element.frame.minY >= list.frame.minY else { return false }
        guard let obstruction else { return true }
        return element.frame.maxY < obstruction.frame.minY
    }

    private func dragUp(in list: XCUIElement) {
        let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.78))
        let end = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.38))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func dragDown(in list: XCUIElement) {
        let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28))
        let end = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.68))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func waitForValue(_ value: String, on element: XCUIElement) -> Bool {
        let updated = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", value),
            object: element
        )
        return XCTWaiter.wait(for: [updated], timeout: 2) == .completed
    }

    private func waitForScrollToSettle() {
        let settled = expectation(description: "Scroll settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            settled.fulfill()
        }
        wait(for: [settled], timeout: 1)
    }

    private func swipeDownUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        listIdentifier: String
    ) -> Bool {
        let list = app.collectionViews[listIdentifier]
        guard list.waitForExistence(timeout: 2) else { return false }

        let deadline = Date().addingTimeInterval(15)
        while !element.isHittable && Date() < deadline {
            dragDown(in: list)
        }
        return element.isHittable
    }
}
