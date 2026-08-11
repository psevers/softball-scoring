import XCTest

@MainActor
final class ScrollReachabilityUITests: XCTestCase {
    func testTimeLimitUsesKeyboardFreeThirtyToNinetyMinuteWheel() {
        let app = launchApp(atAccessibilityTextSize: true)
        app.tabBars.buttons["Games"].tap()
        app.buttons["New Game"].tap()
        let timeLimit = app.buttons["Time Limit"]
        XCTAssertTrue(swipeUntilHittable(
            timeLimit,
            in: app,
            listIdentifier: "game.setup.form"
        ))
        timeLimit.tap()

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
        let app = launchApp(atAccessibilityTextSize: true)
        app.tabBars.buttons["Games"].tap()
        app.buttons["New Game"].tap()
        app.textFields["Opponent"].tap()
        app.textFields["Opponent"].typeText("Test Opponent")
        app.keyboards.buttons["return"].tap()
        let setLineup = app.buttons["Set Lineup"]
        XCTAssertTrue(swipeUntilHittable(
            setLineup,
            in: app,
            listIdentifier: "game.setup.form"
        ))
        setLineup.tap()
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

    func testOffensiveQuickResultsPersistRealBatterProgression() {
        let app = launchApp()
        app.tabBars.buttons["Games"].tap()
        let liveGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI Opponent")
        ).firstMatch
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()

        let currentBatter = app.staticTexts["offense.currentBatter"]
        XCTAssertTrue(currentBatter.waitForExistence(timeout: 3))
        XCTAssertEqual(currentBatter.label, "Player 01")

        let walk = app.buttons["Walk"]
        XCTAssertTrue(scrollUntilHittable(walk, in: app))
        walk.tap()
        XCTAssertTrue(waitForLabel("Player 02", on: currentBatter))
        let homeRun = app.buttons["Home Run"]
        XCTAssertTrue(scrollUntilHittable(homeRun, in: app))
        homeRun.tap()
        XCTAssertTrue(waitForLabel("Player 03", on: currentBatter))

        let single = app.buttons["1B"]
        let deadline = Date().addingTimeInterval(5)
        while !single.isHittable && Date() < deadline {
            app.swipeUp()
        }
        XCTAssertTrue(single.isHittable)
        single.tap()
        XCTAssertTrue(app.navigationBars["Record Our Play"].waitForExistence(timeout: 3))
        app.buttons["Record"].tap()
        XCTAssertTrue(waitForLabel("Player 04", on: currentBatter))

        app.navigationBars["UI Opponent"].buttons.firstMatch.tap()
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()
        XCTAssertTrue(waitForLabel("Player 04", on: currentBatter))
    }

    func testNormalOffensivePitchAndBaseRunningControlsPersistDerivedState() {
        let app = launchApp()
        app.tabBars.buttons["Games"].tap()
        let liveGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI Opponent")
        ).firstMatch
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()

        let currentBatter = app.staticTexts["offense.currentBatter"]
        let count = app.staticTexts["game.count"]
        XCTAssertTrue(currentBatter.waitForExistence(timeout: 3))
        XCTAssertEqual(currentBatter.label, "Player 01")

        let ball = app.buttons["offense.pitch.ball"]
        for expectedCount in ["1 – 0", "2 – 0", "3 – 0"] {
            ball.tap()
            XCTAssertTrue(waitForLabel(expectedCount, on: count))
        }
        ball.tap()
        XCTAssertTrue(waitForLabel("Player 02", on: currentBatter))
        XCTAssertTrue(waitForLabel("0 – 0", on: count))

        let stealSecond = app.buttons["offense.baseRunning.first.stolenBase"]
        XCTAssertTrue(scrollUntilHittable(stealSecond, in: app))
        stealSecond.tap()
        let caughtStealing = app.buttons["offense.baseRunning.second.caughtStealing"]
        XCTAssertTrue(scrollUntilHittable(caughtStealing, in: app))
        caughtStealing.tap()
        XCTAssertEqual(currentBatter.label, "Player 02")

        let calledStrike = app.buttons["offense.pitch.calledStrike"]
        XCTAssertTrue(scrollUntilHittable(calledStrike, in: app))
        calledStrike.tap()
        XCTAssertTrue(waitForLabel("0 – 1", on: count))
        app.buttons["offense.pitch.foul"].tap()
        XCTAssertTrue(waitForLabel("0 – 2", on: count))
        app.buttons["offense.pitch.foul"].tap()
        XCTAssertTrue(waitForLabel("0 – 2", on: count))
        app.buttons["offense.pitch.swingingStrike"].tap()
        XCTAssertTrue(waitForLabel("Player 03", on: currentBatter))
        XCTAssertTrue(waitForLabel("0 – 0", on: count))
    }

    private func launchApp(atAccessibilityTextSize: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        if atAccessibilityTextSize {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXL"
            ]
        }
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

    private func waitForLabel(_ label: String, on element: XCUIElement) -> Bool {
        let updated = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label),
            object: element
        )
        return XCTWaiter.wait(for: [updated], timeout: 3) == .completed
    }

    private func waitForScrollToSettle() {
        let settled = expectation(description: "Scroll settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            settled.fulfill()
        }
        wait(for: [settled], timeout: 1)
    }

    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while !element.isHittable && Date() < deadline {
            app.swipeUp()
        }
        return element.isHittable
    }

    private func swipeDownUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        listIdentifier: String
    ) -> Bool {
        let list = app.collectionViews[listIdentifier]
        guard list.waitForExistence(timeout: 2) else { return false }

        let deadline = Date().addingTimeInterval(35)
        while !element.isHittable && Date() < deadline {
            dragDown(in: list)
        }
        return element.isHittable
    }
}
