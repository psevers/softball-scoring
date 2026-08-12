import XCTest

@MainActor
final class ScrollReachabilityUITests: XCTestCase {
    func testSliceFiveFiveStandardEvidenceSurfacesRemainReachable() {
        captureSliceFiveFiveEvidence(atAccessibilityTextSize: false)
    }

    func testSliceFiveFiveAccessibilityEvidenceSurfacesRemainReachable() {
        captureSliceFiveFiveEvidence(atAccessibilityTextSize: true)
    }

    func testSliceFiveFiveStandardBattingLineRemainsAligned() {
        captureSliceFiveFiveBattingLine(atAccessibilityTextSize: false)
    }

    func testSliceFiveFiveAccessibilityBattingLineRemainsAligned() {
        captureSliceFiveFiveBattingLine(atAccessibilityTextSize: true)
    }

    func testStandardAdministrativeScorebookSurfaces() {
        let app = launchApp()

        app.tabBars.buttons["Team"].tap()
        XCTAssertTrue(app.staticTexts["Player 01"].waitForExistence(timeout: 3))
        captureScreenshot(named: "ticket9-standard-team", from: app)
        let firstPlayer = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Player 01")
        ).firstMatch
        XCTAssertTrue(firstPlayer.waitForExistence(timeout: 3))
        firstPlayer.tap()
        XCTAssertTrue(app.textFields["First name"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.navigationBars["Edit Player"].exists)
        captureScreenshot(named: "ticket9-standard-player-editor", from: app)
        app.buttons["Cancel"].tap()

        app.buttons["Seasons"].tap()
        XCTAssertTrue(app.staticTexts["UI Test Season"].waitForExistence(timeout: 3))
        captureScreenshot(named: "ticket9-standard-season", from: app)

        app.tabBars.buttons["Games"].tap()
        let summaryGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI Summary Opponent")
        ).firstMatch
        XCTAssertTrue(summaryGame.waitForExistence(timeout: 3))
        summaryGame.tap()
        XCTAssertTrue(app.otherElements["game.summary.page"].waitForExistence(timeout: 3))
        captureScreenshot(named: "ticket9-standard-summary", from: app)

        app.tabBars.buttons["Stats"].tap()
        XCTAssertTrue(app.otherElements["stats.empty.page"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No Stats Yet"].exists)
        captureScreenshot(named: "ticket9-standard-stats", from: app)
    }

    func testAccessibilityAdministrativeScorebookSurfacesRemainReachable() {
        let app = launchApp(atAccessibilityTextSize: true)

        app.tabBars.buttons["Team"].tap()
        let lowerRosterPlayer = app.staticTexts["Player 08"]
        XCTAssertTrue(swipeUntilHittable(
            lowerRosterPlayer,
            in: app,
            listIdentifier: "team.roster.list"
        ))
        captureScreenshot(named: "ticket9-ax-team", from: app)
        let lowerRosterPlayerButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Player 08")
        ).firstMatch
        XCTAssertTrue(lowerRosterPlayerButton.isHittable)
        lowerRosterPlayerButton.tap()
        XCTAssertTrue(app.textFields["First name"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.navigationBars["Edit Player"].exists)
        captureScreenshot(named: "ticket9-ax-player-editor", from: app)
        app.buttons["Cancel"].tap()

        let roster = app.collectionViews["team.roster.list"]
        let seasons = app.buttons["Seasons"]
        let deadline = Date().addingTimeInterval(15)
        while !seasons.isHittable && Date() < deadline {
            dragDown(in: roster)
        }
        XCTAssertTrue(seasons.isHittable)
        seasons.tap()
        XCTAssertTrue(app.staticTexts["UI Test Season"].waitForExistence(timeout: 3))
        captureScreenshot(named: "ticket9-ax-season", from: app)

        app.tabBars.buttons["Games"].tap()
        let summaryGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI Summary Opponent")
        ).firstMatch
        XCTAssertTrue(summaryGame.waitForExistence(timeout: 3))
        summaryGame.tap()
        XCTAssertTrue(app.otherElements["game.summary.page"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Player 01"].waitForExistence(timeout: 3))
        captureScreenshot(named: "ticket9-ax-summary", from: app)

        app.tabBars.buttons["Stats"].tap()
        XCTAssertTrue(app.otherElements["stats.empty.page"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No Stats Yet"].isHittable)
        captureScreenshot(named: "ticket9-ax-stats", from: app)
    }

    func testStandardLiveGameStartsWithCompactAtBatAndPitchControls() {
        let app = launchApp()
        app.tabBars.buttons["Games"].tap()
        let liveGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI Opponent")
        ).firstMatch
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()

        XCTAssertTrue(app.staticTexts["offense.currentBatter"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["game.count"].isHittable)
        XCTAssertEqual(app.staticTexts["game.status"].label, "7 innings")
        XCTAssertTrue(app.buttons["offense.pitch.ball"].isHittable)
        XCTAssertTrue(app.buttons["offense.pitch.calledStrike"].isHittable)
        captureScreenshot(named: "ticket8-standard-live", from: app)

        let single = app.buttons["1B"]
        XCTAssertTrue(scrollUntilHittable(single, in: app))
        single.tap()
        XCTAssertTrue(app.navigationBars["Record Our Play"].waitForExistence(timeout: 3))
        captureScreenshot(named: "ticket8-standard-runner", from: app)
    }

    func testPlayHistoryOpensFromLiveGameAndReturnsToUnchangedScoringState() {
        let app = launchApp(atAccessibilityTextSize: true)
        app.tabBars.buttons["Games"].tap()
        let liveGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI History Opponent")
        ).firstMatch
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()

        let count = app.staticTexts["game.count"]
        XCTAssertTrue(count.waitForExistence(timeout: 3))
        let countBeforeHistory = count.label
        let history = app.buttons["game.history"]
        XCTAssertTrue(history.isHittable)
        history.tap()

        XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
        let completedPlay = app.buttons["history.entry.1"]
        let pendingPlay = app.buttons["history.entry.3"]
        XCTAssertTrue(completedPlay.waitForExistence(timeout: 3))
        XCTAssertTrue(completedPlay.label.contains("1B · Batter to 1B"))
        XCTAssertTrue(pendingPlay.waitForExistence(timeout: 3))
        XCTAssertTrue(pendingPlay.label.contains("Ball In Play · Pending"))

        app.navigationBars["Play History"].buttons.firstMatch.tap()
        XCTAssertTrue(count.waitForExistence(timeout: 3))
        XCTAssertEqual(count.label, countBeforeHistory)
        XCTAssertTrue(app.buttons["game.history"].isHittable)
    }

    func testUndoLatestPitchConfirmsCancelsAndRestoresLiveStateFromHistory() {
        let app = launchApp(atAccessibilityTextSize: true)
        app.tabBars.buttons["Games"].tap()
        let liveGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI Undo Opponent")
        ).firstMatch
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()

        let count = app.staticTexts["game.count"]
        XCTAssertTrue(count.waitForExistence(timeout: 3))
        XCTAssertEqual(count.label, "0 – 0")
        XCTAssertTrue(app.staticTexts["Pitching · 4 pitches · Opp batter 2"].exists)

        let liveUndo = app.buttons["game.undoLatestPitch"]
        XCTAssertTrue(liveUndo.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(liveUndo.frame.height, 44)
        liveUndo.tap()
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Top of inning 1, opponent batting slot 1, sequence 4: Ball")
        ).firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "completed the plate appearance for opponent batting slot 1")
        ).firstMatch.exists)
        app.buttons["Cancel"].tap()
        XCTAssertEqual(count.label, "0 – 0")
        XCTAssertTrue(app.staticTexts["Pitching · 4 pitches · Opp batter 2"].exists)

        app.buttons["game.history"].tap()
        XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
        let historyUndo = app.buttons["history.undoLatestPitch"]
        XCTAssertTrue(historyUndo.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(historyUndo.frame.height, 44)
        historyUndo.tap()
        XCTAssertTrue(app.buttons["Undo Ball"].waitForExistence(timeout: 3))
        app.buttons["Undo Ball"].tap()
        XCTAssertTrue(app.buttons["history.undoLatestPitch"].waitForExistence(timeout: 3))

        app.navigationBars["Play History"].buttons.firstMatch.tap()
        XCTAssertTrue(count.waitForExistence(timeout: 3))
        XCTAssertEqual(count.label, "3 – 0")
        XCTAssertTrue(app.staticTexts["Pitching · 3 pitches · Opp batter 1"].exists)
        XCTAssertTrue(app.buttons["game.undoLatestPitch"].isHittable)
    }

    func testUndoThirdOutStrikeoutRestoresDefensiveHalfInning() {
        let app = launchApp(atAccessibilityTextSize: true)
        app.tabBars.buttons["Games"].tap()
        let liveGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI Strikeout Undo Opponent")
        ).firstMatch
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()

        XCTAssertTrue(app.staticTexts["offense.currentBatter"].waitForExistence(timeout: 3))
        let undo = app.buttons["game.undoLatestPitch"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        undo.tap()
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Top of inning 1, opponent batting slot 3, sequence 9: Called Strike")
        ).firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Undo Called Strike"].waitForExistence(timeout: 3))
        app.buttons["Undo Called Strike"].tap()

        let restoredCount = app.staticTexts["game.count"]
        XCTAssertTrue(restoredCount.waitForExistence(timeout: 3))
        XCTAssertEqual(restoredCount.label, "0 – 2")
        XCTAssertTrue(app.staticTexts["Pitching · 8 pitches · Opp batter 3"].exists)

        app.navigationBars["UI Strikeout Undo Opponent"].buttons.firstMatch.tap()
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()
        XCTAssertTrue(app.staticTexts["Pitching · 8 pitches · Opp batter 3"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["game.count"].label, "0 – 2")
    }

    func testAccessibilityRunnerConfirmationStartsWithDestinationAndRBIControls() {
        let app = launchApp(atAccessibilityTextSize: true)
        app.tabBars.buttons["Games"].tap()
        let liveGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI Opponent")
        ).firstMatch
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()
        captureScreenshot(named: "ticket8-ax-live", from: app)

        let single = app.buttons["1B"]
        XCTAssertTrue(scrollUntilHittable(single, in: app))
        let double = app.buttons["2B"]
        let triple = app.buttons["3B"]
        let homeRun = app.buttons["HR"]
        XCTAssertGreaterThan(single.frame.width, app.frame.width * 0.35)
        XCTAssertEqual(single.frame.minY, double.frame.minY, accuracy: 1)
        XCTAssertGreaterThan(triple.frame.minY, single.frame.minY)
        XCTAssertEqual(triple.frame.minY, homeRun.frame.minY, accuracy: 1)
        single.tap()
        XCTAssertTrue(app.navigationBars["Record Our Play"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["runner.destination.batter"].isHittable)
        let rbi = app.steppers["runner.rbi"]
        XCTAssertTrue(rbi.exists)
        XCTAssertLessThanOrEqual(rbi.frame.maxY, app.frame.maxY)
        captureScreenshot(named: "ticket8-ax-runner", from: app)
    }

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
        let app = launchApp(atAccessibilityTextSize: true)
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
        let app = launchApp(atAccessibilityTextSize: true)
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
        XCTAssertTrue(scrollUntilHittable(ball, in: app))
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
        XCTAssertTrue(scrollFromTopUntilHittable(calledStrike, in: app))
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

    private func captureSliceFiveFiveEvidence(atAccessibilityTextSize: Bool) {
        let app = launchApp(atAccessibilityTextSize: atAccessibilityTextSize)

        XCTAssertTrue(app.scrollViews["games.home.ledger"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["New Game"].isHittable)
        captureScreenshot(named: "games-home", from: app)

        let defensiveGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI Defense Opponent")
        ).firstMatch
        XCTAssertTrue(defensiveGame.waitForExistence(timeout: 3))
        defensiveGame.tap()
        XCTAssertTrue(app.navigationBars["UI Defense Opponent"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Ball"].isHittable)
        XCTAssertTrue(app.buttons["Called Strike"].isHittable)
        captureScreenshot(named: "live-defense", from: app)
        app.buttons["Ball In Play"].tap()
        XCTAssertTrue(app.buttons["1B"].waitForExistence(timeout: 3))
        app.buttons["1B"].tap()
        XCTAssertTrue(app.navigationBars["Record Play"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["runner.destination.batter"].isHittable)
        XCTAssertTrue(app.steppers["runner.rbi"].exists)
        captureScreenshot(named: "runner-confirmation-defense", from: app)
        app.buttons["Cancel"].tap()
        app.navigationBars["UI Defense Opponent"].buttons.firstMatch.tap()

        app.buttons["New Game"].tap()
        XCTAssertTrue(app.navigationBars["New Game"].waitForExistence(timeout: 3))
        captureScreenshot(named: "new-game", from: app)
        app.textFields["Opponent"].tap()
        app.textFields["Opponent"].typeText("Evidence Opponent")
        app.keyboards.buttons["return"].tap()
        let setLineup = app.buttons["Set Lineup"]
        XCTAssertTrue(swipeUntilHittable(
            setLineup,
            in: app,
            listIdentifier: "game.setup.form"
        ))
        setLineup.tap()
        addStartingLineup(in: app)
        let lineupSummary = app.staticTexts["lineup.summary"]
        XCTAssertTrue(swipeDownUntilHittable(
            lineupSummary,
            in: app,
            listIdentifier: "lineup.list"
        ))
        XCTAssertEqual(lineupSummary.label, "9 batters · 9 / 9 fielders")
        XCTAssertTrue(app.buttons["Start Game"].isEnabled)
        captureScreenshot(named: "lineup", from: app)
        app.navigationBars["Set Lineup"].buttons.firstMatch.tap()
        app.buttons["Cancel"].tap()

        let offensiveGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI Opponent")
        ).firstMatch
        XCTAssertTrue(offensiveGame.waitForExistence(timeout: 3))
        offensiveGame.tap()
        XCTAssertTrue(app.staticTexts["offense.currentBatter"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["offense.pitch.ball"].isHittable)
        captureScreenshot(named: "live-offense", from: app)
        let single = app.buttons["1B"]
        XCTAssertTrue(scrollUntilHittable(single, in: app))
        single.tap()
        XCTAssertTrue(app.navigationBars["Record Our Play"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["runner.destination.batter"].isHittable)
        XCTAssertTrue(app.steppers["runner.rbi"].exists)
        captureScreenshot(named: "runner-confirmation", from: app)
        app.buttons["Cancel"].tap()
        app.navigationBars["UI Opponent"].buttons.firstMatch.tap()

        app.tabBars.buttons["Team"].tap()
        XCTAssertTrue(app.staticTexts["Player 01"].waitForExistence(timeout: 3))
        captureScreenshot(named: "team-roster", from: app)
        let firstPlayer = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Player 01")
        ).firstMatch
        XCTAssertTrue(firstPlayer.isHittable)
        firstPlayer.tap()
        XCTAssertTrue(app.navigationBars["Edit Player"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["First name"].isHittable)
        captureScreenshot(named: "player-editor", from: app)
        app.buttons["Cancel"].tap()
        app.buttons["Seasons"].tap()
        XCTAssertTrue(app.staticTexts["UI Test Season"].waitForExistence(timeout: 3))
        captureScreenshot(named: "season-list", from: app)
        app.buttons["team.add"].tap()
        XCTAssertTrue(app.navigationBars["New Season"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["Name, e.g. 2026 Summer"].isHittable)
        captureScreenshot(named: "season-editor", from: app)
        app.buttons["Cancel"].tap()

        app.tabBars.buttons["Games"].tap()
        let summaryGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI Summary Opponent")
        ).firstMatch
        XCTAssertTrue(summaryGame.waitForExistence(timeout: 3))
        summaryGame.tap()
        XCTAssertTrue(app.otherElements["game.summary.page"].waitForExistence(timeout: 3))
        captureScreenshot(named: "game-summary", from: app)

        app.tabBars.buttons["Stats"].tap()
        XCTAssertTrue(app.otherElements["stats.empty.page"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No Stats Yet"].isHittable)
        captureScreenshot(named: "stats-empty", from: app)
    }

    private func addStartingLineup(in app: XCUIApplication) {
        let startGame = app.buttons["Start Game"]
        for index in 1...9 {
            let playerName = String(format: "Player %02d", index)
            let addPlayer = app.buttons["lineup.add.\(playerName)"]
            XCTAssertTrue(
                swipeUntilHittable(addPlayer, in: app, above: startGame),
                "\(playerName) was not reachable"
            )
            addPlayer.tap()
            XCTAssertTrue(
                waitForValue("\(index) batters, \(index) of 9 fielders", on: startGame),
                "\(playerName) was not added"
            )
        }
    }

    private func captureSliceFiveFiveBattingLine(atAccessibilityTextSize: Bool) {
        let app = launchApp(atAccessibilityTextSize: atAccessibilityTextSize)
        let offensiveGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI Opponent")
        ).firstMatch
        XCTAssertTrue(offensiveGame.waitForExistence(timeout: 3))
        offensiveGame.tap()

        let battingLine = app.otherElements["offense.battingLine"]
        XCTAssertTrue(scrollUntilHittable(battingLine, in: app))
        let stats = [
            (id: "pa", label: "PA"), (id: "ab", label: "AB"), (id: "r", label: "R"),
            (id: "h", label: "H"), (id: "2b", label: "2B"), (id: "3b", label: "3B"),
            (id: "hr", label: "HR"), (id: "rbi", label: "RBI"), (id: "bb", label: "BB"),
            (id: "hbp", label: "HBP"), (id: "so", label: "SO"), (id: "sb", label: "SB"),
            (id: "cs", label: "CS")
        ]
        for (index, stat) in stats.enumerated() {
            let column = battingLine.staticTexts[stat.label]
            XCTAssertTrue(
                scrollUntilHittable(column, in: app),
                "Batting column \(stat.label) was not reachable"
            )
            if index == 0 {
                captureScreenshot(named: "batting-line-top", from: app)
            }
        }
        assertBattingStatValuesAlign(stats, in: battingLine)
        captureScreenshot(named: "batting-line-bottom", from: app)
    }

    private func assertBattingStatValuesAlign(
        _ expectedStats: [(id: String, label: String)],
        in battingLine: XCUIElement
    ) {
        let stats = expectedStats.map { stat in
            (
                label: battingLine.staticTexts["scorebook.stat.\(stat.id).label"],
                value: battingLine.staticTexts["scorebook.stat.\(stat.id).value"]
            )
        }

        for stat in stats {
            XCTAssertTrue(stat.label.exists, "Missing batting-stat label")
            XCTAssertTrue(stat.value.exists, "Missing batting-stat value")
        }

        var visualRows: [[(label: XCUIElement, value: XCUIElement)]] = []
        for stat in stats {
            if let previous = visualRows.last?.last,
               stat.label.frame.minX > previous.label.frame.minX {
                visualRows[visualRows.count - 1].append(stat)
            } else {
                visualRows.append([stat])
            }
        }
        for row in visualRows where row.count > 1 {
            let valueBaselines = row.map { Int($0.value.frame.minY.rounded()) }
            XCTAssertEqual(
                Set(valueBaselines).count,
                1,
                "Batting-stat values must align within each visual row; got \(valueBaselines)"
            )
        }
    }

    private func launchApp(atAccessibilityTextSize: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        let contentSizeCategory = atAccessibilityTextSize
            ? "UICTContentSizeCategoryAccessibilityXL"
            : "UICTContentSizeCategoryL"
        app.launchArguments = [
            "-uiTesting",
            "-UIPreferredContentSizeCategoryName",
            contentSizeCategory
        ]
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

    private func captureScreenshot(named name: String, from app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        let deadline = Date().addingTimeInterval(20)
        while !element.isHittable && Date() < deadline {
            app.swipeUp()
        }
        return element.isHittable
    }

    private func scrollFromTopUntilHittable(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<8 {
            app.swipeDown()
        }
        return scrollUntilHittable(element, in: app)
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
