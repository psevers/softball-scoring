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

    func testDeleteCompletedDefensiveLogicalPlayRepairsDownstreamHistoryAndPersists() {
        let app = launchApp(
            persistentStoreName: "logical-play-delete-\(UUID().uuidString)"
        )
        app.tabBars.buttons["Games"].tap()
        let liveGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI History Opponent")
        ).firstMatch
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()

        app.buttons["game.history"].tap()
        XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
        app.buttons["history.entry.1"].tap()

        let deletePlay = app.buttons["history.deleteCompletedPlay.2"]
        XCTAssertTrue(deletePlay.waitForExistence(timeout: 3))
        XCTAssertEqual(deletePlay.label, "Delete Completed Play, sequences 1 and 2")
        XCTAssertGreaterThanOrEqual(deletePlay.frame.height, 44)
        XCTAssertTrue(app.buttons["history.deletePitch.1"].exists)
        deletePlay.tap()

        let confirmation = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Sequence 1: Ball In Play pitch")
        ).firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        XCTAssertTrue(confirmation.label.contains("Sequence 2: Single result"))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["history.deleteCompletedPlay.2"].waitForExistence(timeout: 3))

        app.buttons["history.deleteCompletedPlay.2"].tap()
        XCTAssertTrue(app.buttons["Preview Deletion"].waitForExistence(timeout: 3))
        app.buttons["Preview Deletion"].tap()

        XCTAssertTrue(app.navigationBars["Delete Completed Play"].waitForExistence(timeout: 3))
        XCTAssertEqual(
            app.staticTexts["logicalPlayDelete.component.1"].label,
            "Sequence 1 · Ball In Play pitch"
        )
        let form = app.collectionViews.firstMatch
        let resultComponent = app.staticTexts["logicalPlayDelete.component.2"]
        XCTAssertTrue(swipeWithinUntilHittable(resultComponent, in: form))
        XCTAssertEqual(
            resultComponent.label,
            "Sequence 2 · Single result"
        )
        let problem = app.buttons["correction.problem.3"]
        XCTAssertTrue(swipeWithinUntilHittable(problem, in: form))
        XCTAssertFalse(app.buttons["logicalPlayDelete.save"].isEnabled)
        problem.tap()

        XCTAssertTrue(app.navigationBars["Affected Event"].waitForExistence(timeout: 3))
        let repairDeletion = app.buttons["correction.repair.delete"]
        let affectedEventForm = app.collectionViews.element(boundBy: app.collectionViews.count - 1)
        XCTAssertTrue(swipeWithinUntilHittable(repairDeletion, in: affectedEventForm))
        repairDeletion.tap()

        XCTAssertTrue(app.navigationBars["Delete Completed Play"].waitForExistence(timeout: 3))
        XCTAssertTrue(swipeWithinUntilHittable(
            app.staticTexts["Candidate timeline replays cleanly"],
            in: form
        ))
        XCTAssertTrue(app.staticTexts["correction.logicalPlayChange.2"].exists)
        XCTAssertTrue(app.staticTexts["correction.change.3"].exists)
        let save = app.buttons["logicalPlayDelete.save"]
        XCTAssertTrue(save.isEnabled)
        XCTAssertGreaterThanOrEqual(save.frame.height, 44)
        save.tap()

        XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No Plays Yet"].waitForExistence(timeout: 3))
        app.navigationBars["Play History"].buttons.firstMatch.tap()
        XCTAssertEqual(app.staticTexts["game.count"].label, "Count 0 and 0")
        XCTAssertEqual(app.staticTexts["game.count"].value as? String, "0 outs, bases empty")

        app.terminate()
        app.launch()
        app.tabBars.buttons["Games"].tap()
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()
        XCTAssertEqual(app.staticTexts["game.count"].label, "Count 0 and 0")
        XCTAssertEqual(app.staticTexts["game.count"].value as? String, "0 outs, bases empty")
        app.buttons["game.history"].tap()
        XCTAssertTrue(app.staticTexts["No Plays Yet"].waitForExistence(timeout: 3))
    }

    func testUndoBallInPlayResultRecordsReplacementAndRefreshesLiveState() {
        let app = launchApp(atAccessibilityTextSize: true)
        app.tabBars.buttons["Games"].tap()
        let liveGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI Ball In Play Undo Opponent")
        ).firstMatch
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()

        XCTAssertTrue(app.staticTexts["Pitching · 1 pitches · Opp batter 2"].waitForExistence(timeout: 3))
        app.buttons["game.history"].tap()
        XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
        let completedSingle = app.buttons["history.entry.1"]
        XCTAssertTrue(completedSingle.waitForExistence(timeout: 3))
        XCTAssertTrue(completedSingle.label.contains("1B · Batter to 1B"))

        let undo = app.buttons["history.undoLatestAction"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        XCTAssertEqual(undo.label, "Undo Latest Result")
        undo.tap()
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "sequence 2: 1B Result")
        ).firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Only the completed Single result will be removed")
        ).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Ball In Play pitch at sequence 1 will remain counted")
        ).firstMatch.exists)
        app.buttons["Undo 1B Result"].tap()

        let pendingPlay = app.buttons["history.entry.1"]
        XCTAssertTrue(pendingPlay.waitForExistence(timeout: 3))
        XCTAssertTrue(pendingPlay.label.contains("Ball In Play · Pending"))
        app.navigationBars["Play History"].buttons.firstMatch.tap()

        XCTAssertTrue(app.staticTexts["What happened?"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["The pitch is already counted. Finish this play before scoring the next pitch."].exists)
        app.buttons["2B"].tap()
        XCTAssertTrue(app.navigationBars["Record Play"].waitForExistence(timeout: 3))
        app.buttons["Record"].tap()

        XCTAssertTrue(app.staticTexts["Pitching · 1 pitches · Opp batter 2"].waitForExistence(timeout: 3))
        app.buttons["game.history"].tap()
        let correctedDouble = app.buttons["history.entry.1"]
        XCTAssertTrue(correctedDouble.waitForExistence(timeout: 3))
        XCTAssertTrue(correctedDouble.label.contains("2B · Batter to 2B"))
    }

    func testCorrectDefensiveBallInPlayResultPersistsReplayedBasesAndOuts() {
        let app = launchApp(
            atAccessibilityExtraExtraExtraLarge: true,
            persistentStoreName: "play-edit-\(UUID().uuidString)"
        )
        app.tabBars.buttons["Games"].tap()
        let liveGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI Ball In Play Undo Opponent")
        ).firstMatch
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()

        let score = app.staticTexts["game.score"]
        let count = app.staticTexts["game.count"]
        XCTAssertTrue(score.waitForExistence(timeout: 3))
        XCTAssertTrue(count.waitForExistence(timeout: 3))
        XCTAssertEqual(score.label, "Top of inning 1. UI Ball In Play Undo Opponent 0, Us 0")
        XCTAssertEqual(count.value as? String, "0 outs, on 1B")

        func correctPlay(
            outcome: String,
            destination: String,
            proposedSummary: String,
            replaySummary: String,
            historySummary: String
        ) {
            app.buttons["game.history"].tap()
            XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
            app.buttons["history.entry.1"].tap()
            let editPlay = app.buttons["history.editPlay.2"]
            XCTAssertTrue(editPlay.waitForExistence(timeout: 3))
            XCTAssertGreaterThanOrEqual(editPlay.frame.height, 44)
            editPlay.tap()

            XCTAssertTrue(app.navigationBars["Edit Play"].waitForExistence(timeout: 3))
            XCTAssertEqual(
                app.staticTexts["playEdit.countedPitch"].label,
                "Ball In Play pitch · Sequence 1 · Counted"
            )
            let editForm = app.collectionViews.firstMatch
            XCTAssertTrue(editForm.waitForExistence(timeout: 3))
            XCTAssertFalse(app.buttons["playEdit.save"].isEnabled)

            let outcomePicker = app.buttons["playEdit.outcomePicker"]
            let saveButton = app.buttons["playEdit.save"]
            XCTAssertTrue(swipeWithinUntilHittable(
                outcomePicker,
                in: editForm,
                above: saveButton
            ))
            outcomePicker.tap()
            XCTAssertTrue(app.buttons[outcome].waitForExistence(timeout: 3))
            app.buttons[outcome].tap()
            XCTAssertTrue(waitForValue(outcome, on: outcomePicker))
            let confirmRunners = app.buttons["playEdit.confirmRunners"]
            XCTAssertTrue(swipeWithinUntilHittable(
                confirmRunners,
                in: editForm,
                above: saveButton
            ))
            confirmRunners.tap()

            XCTAssertTrue(app.navigationBars["Confirm Correction"].waitForExistence(timeout: 3))
            let batterDestination = app.buttons["runner.destination.batter"]
            XCTAssertTrue(batterDestination.waitForExistence(timeout: 3))
            XCTAssertGreaterThanOrEqual(batterDestination.frame.height, 44)
            batterDestination.tap()
            XCTAssertTrue(app.buttons[destination].waitForExistence(timeout: 3))
            app.buttons[destination].tap()
            app.buttons["Preview"].tap()

            let proposed = app.staticTexts["playEdit.proposed"]
            for _ in 0..<4 where !proposed.exists {
                editForm.swipeUp()
            }
            XCTAssertTrue(proposed.exists)
            XCTAssertTrue(
                proposed.label.contains(proposedSummary),
                "Expected \(outcome) summary \(proposedSummary), got \(proposed.label)"
            )
            XCTAssertTrue(
                proposed.label.contains(replaySummary),
                "Expected \(outcome) replay \(replaySummary), got \(proposed.label)"
            )
            let save = app.buttons["playEdit.save"]
            XCTAssertTrue(save.isEnabled)
            XCTAssertGreaterThanOrEqual(save.frame.height, 44)
            save.tap()

            XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.buttons["history.entry.1"].label.contains(historySummary))
            app.navigationBars["Play History"].buttons.firstMatch.tap()
            XCTAssertTrue(
                app.navigationBars["UI Ball In Play Undo Opponent"]
                    .waitForExistence(timeout: 3)
            )
        }

        correctPlay(
            outcome: "Reached on Error",
            destination: "1B",
            proposedSummary: "Proposed: Reached on Error · Batter to 1B",
            replaySummary: "Outs 0 · Bases 1B 1 · Opponent batter 2",
            historySummary: "E · Batter to 1B"
        )
        correctPlay(
            outcome: "Triple",
            destination: "3B",
            proposedSummary: "Proposed: Triple · Batter to 3B",
            replaySummary: "Outs 0 · Bases 3B 1 · Opponent batter 2",
            historySummary: "3B · Batter to 3B"
        )

        app.terminate()
        app.launch()
        app.tabBars.buttons["Games"].tap()
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()
        XCTAssertEqual(score.label, "Top of inning 1. UI Ball In Play Undo Opponent 0, Us 0")
        XCTAssertEqual(count.value as? String, "0 outs, on 3B")

        correctPlay(
            outcome: "Ground Out",
            destination: "Out",
            proposedSummary: "Proposed: Ground Out · Batter to Out",
            replaySummary: "Outs 1 · Bases empty · Opponent batter 2",
            historySummary: "GO · Batter to Out"
        )
        XCTAssertEqual(score.label, "Top of inning 1. UI Ball In Play Undo Opponent 0, Us 0")
        XCTAssertEqual(count.value as? String, "1 out, bases empty")

        app.terminate()
        app.launch()
        app.tabBars.buttons["Games"].tap()
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()
        XCTAssertEqual(count.value as? String, "1 out, bases empty")
    }

    func testCorrectDefensiveRunAndRBIPersistsScoreBasesAndPitcherReplay() {
        let app = launchApp(
            atAccessibilityExtraExtraExtraLarge: true,
            persistentStoreName: "run-correction-\(UUID().uuidString)"
        )
        app.tabBars.buttons["Games"].tap()
        let liveGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI Run Correction Opponent")
        ).firstMatch
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()

        let score = app.staticTexts["game.score"]
        let count = app.staticTexts["game.count"]
        XCTAssertTrue(score.waitForExistence(timeout: 3))
        XCTAssertEqual(score.label, "Top of inning 1. UI Run Correction Opponent 0, Us 0")
        XCTAssertEqual(count.value as? String, "0 outs, on 1B, 2B")

        app.buttons["game.history"].tap()
        XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
        app.buttons["history.entry.3"].tap()
        let editPlay = app.buttons["history.editPlay.4"]
        XCTAssertTrue(editPlay.waitForExistence(timeout: 3))
        editPlay.tap()

        XCTAssertTrue(app.navigationBars["Edit Play"].waitForExistence(timeout: 3))
        let editForm = app.collectionViews.firstMatch
        let saveButton = app.buttons["playEdit.save"]
        let outcomePicker = app.buttons["playEdit.outcomePicker"]
        XCTAssertTrue(swipeWithinUntilHittable(outcomePicker, in: editForm, above: saveButton))
        outcomePicker.tap()
        XCTAssertTrue(app.buttons["Double"].waitForExistence(timeout: 3))
        app.buttons["Double"].tap()

        let confirmRunners = app.buttons["playEdit.confirmRunners"]
        XCTAssertTrue(swipeWithinUntilHittable(confirmRunners, in: editForm, above: saveButton))
        confirmRunners.tap()
        XCTAssertTrue(app.navigationBars["Confirm Correction"].waitForExistence(timeout: 3))

        let batterDestination = app.buttons["runner.destination.batter"]
        XCTAssertTrue(batterDestination.waitForExistence(timeout: 3))
        batterDestination.tap()
        app.buttons["2B"].tap()
        let firstBaseDestination = app.buttons["runner.destination.first"]
        firstBaseDestination.tap()
        app.buttons["Home"].tap()

        let runsCounted = app.steppers["runner.runsCounted"]
        XCTAssertTrue(runsCounted.waitForExistence(timeout: 3))
        XCTAssertTrue(runsCounted.label.contains("Runs that count  1"))
        app.buttons["runner.runsCounted-Decrement"].tap()
        app.buttons["Preview"].tap()
        let invalidRunCount = app.staticTexts[
            "Every home touch must count because this play does not make the third out."
        ]
        XCTAssertTrue(scrollUntilHittable(invalidRunCount, in: app))
        XCTAssertTrue(app.navigationBars["Confirm Correction"].exists)
        app.buttons["runner.runsCounted-Increment"].tap()
        let rbi = app.steppers["runner.rbi"]
        XCTAssertTrue(rbi.exists)
        app.buttons["runner.rbi-Increment"].tap()
        app.buttons["Preview"].tap()

        let proposed = app.staticTexts["playEdit.proposed"]
        for _ in 0..<4 where !proposed.exists {
            editForm.swipeUp()
        }
        XCTAssertTrue(proposed.exists)
        XCTAssertTrue(proposed.label.contains("Double · Batter to 2B; 1B to Home · 1 run · 1 RBI"))
        XCTAssertTrue(proposed.label.contains("Score 1–0"))
        XCTAssertTrue(proposed.label.contains("Pitcher 2 pitches"))
        XCTAssertTrue(proposed.label.contains("Bases 2B 2"))
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["history.entry.3"].label.contains("1 run · 1 RBI"))
        app.navigationBars["Play History"].buttons.firstMatch.tap()
        XCTAssertEqual(score.label, "Top of inning 1. UI Run Correction Opponent 1, Us 0")
        XCTAssertEqual(count.value as? String, "0 outs, on 2B")

        app.terminate()
        app.launch()
        app.tabBars.buttons["Games"].tap()
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()
        XCTAssertEqual(score.label, "Top of inning 1. UI Run Correction Opponent 1, Us 0")
        XCTAssertEqual(count.value as? String, "0 outs, on 2B")
        XCTAssertTrue(app.staticTexts["Pitching · 2 pitches · Opp batter 3"].exists)
    }

    func testCorrectDefensiveThirdOutTimingPlayPersistsReplayedInning() {
        let app = launchApp(
            atAccessibilityExtraExtraExtraLarge: true,
            persistentStoreName: "third-out-correction-\(UUID().uuidString)"
        )
        app.tabBars.buttons["Games"].tap()
        let liveGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI Third Out Correction Opponent")
        ).firstMatch
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()

        let score = app.staticTexts["game.score"]
        let count = app.staticTexts["game.count"]
        XCTAssertTrue(score.waitForExistence(timeout: 3))
        XCTAssertEqual(score.label, "Bottom of inning 1. UI Third Out Correction Opponent 0, Us 0")
        XCTAssertEqual(count.value as? String, "0 outs, bases empty")

        app.buttons["game.history"].tap()
        XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
        app.buttons["history.entry.7"].tap()
        let editPlay = app.buttons["history.editPlay.8"]
        XCTAssertTrue(editPlay.waitForExistence(timeout: 3))
        editPlay.tap()

        XCTAssertTrue(app.navigationBars["Edit Play"].waitForExistence(timeout: 3))
        let editForm = app.collectionViews.firstMatch
        let saveButton = app.buttons["playEdit.save"]
        XCTAssertFalse(saveButton.isEnabled)
        let confirmRunners = app.buttons["playEdit.confirmRunners"]
        XCTAssertTrue(swipeWithinUntilHittable(confirmRunners, in: editForm, above: saveButton))
        confirmRunners.tap()

        XCTAssertTrue(app.navigationBars["Confirm Correction"].waitForExistence(timeout: 3))
        let thirdOutClassification = app.segmentedControls["runner.thirdOutClassification"]
        XCTAssertTrue(scrollUntilHittable(thirdOutClassification, in: app))
        thirdOutClassification.buttons["Timing Play"].tap()
        let runsCounted = app.steppers["runner.runsCounted"]
        XCTAssertTrue(runsCounted.exists)
        app.buttons["runner.runsCounted-Increment"].tap()
        let rbi = app.steppers["runner.rbi"]
        XCTAssertTrue(rbi.exists)
        app.buttons["runner.rbi-Increment"].tap()
        app.buttons["Preview"].tap()

        let proposed = app.staticTexts["playEdit.proposed"]
        for _ in 0..<4 where !proposed.exists {
            editForm.swipeUp()
        }
        XCTAssertTrue(proposed.exists)
        XCTAssertTrue(proposed.label.contains("Double Play"))
        XCTAssertTrue(proposed.label.contains("1 run · 1 RBI · Timing play third out"))
        XCTAssertTrue(proposed.label.contains("Bottom 1"))
        XCTAssertTrue(proposed.label.contains("Score 1–0"))
        XCTAssertTrue(proposed.label.contains("Count 0–0 · Outs 0 · Bases empty"))
        XCTAssertTrue(proposed.label.contains("Opponent batter 5 · Tracked batter 1"))
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["history.entry.7"].label.contains("1 run · 2 outs · 1 RBI"))
        app.navigationBars["Play History"].buttons.firstMatch.tap()
        XCTAssertEqual(score.label, "Bottom of inning 1. UI Third Out Correction Opponent 1, Us 0")
        XCTAssertEqual(count.value as? String, "0 outs, bases empty")

        app.terminate()
        app.launch()
        app.tabBars.buttons["Games"].tap()
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()
        XCTAssertEqual(score.label, "Bottom of inning 1. UI Third Out Correction Opponent 1, Us 0")
        XCTAssertEqual(count.value as? String, "0 outs, bases empty")
    }

    func testUndoTrackedTeamPitchFromPlayHistoryRestoresLiveBatterAndCount() {
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
        XCTAssertEqual(count.label, "0 – 0")

        let ball = app.buttons["offense.pitch.ball"]
        XCTAssertTrue(scrollUntilHittable(ball, in: app))
        ball.tap()
        XCTAssertTrue(waitForLabel("1 – 0", on: count))

        app.buttons["game.history"].tap()
        XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
        let pitchEntry = app.buttons["history.entry.1"]
        XCTAssertTrue(pitchEntry.waitForExistence(timeout: 3))
        XCTAssertTrue(pitchEntry.label.contains("Player 01"))
        XCTAssertTrue(pitchEntry.label.contains("1–0 count"))

        let undo = app.buttons["history.undoLatestAction"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        XCTAssertEqual(undo.label, "Undo Latest Pitch")
        undo.tap()
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(
                format: "label CONTAINS %@",
                "Top of inning 1, Player 01, batting slot 1 of 14, sequence 1: Ball"
            )
        ).firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "event-time tracked batter and batting-order size will remain unchanged")
        ).firstMatch.exists)
        app.buttons["Undo Ball"].tap()

        XCTAssertTrue(app.staticTexts["No Plays Yet"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["history.undoLatestAction"].exists)
        app.navigationBars["Play History"].buttons.firstMatch.tap()
        XCTAssertTrue(waitForLabel("0 – 0", on: count))
        XCTAssertEqual(currentBatter.label, "Player 01")
    }

    func testEarlierTrackedTeamPitchEditPreservesBatterAndCountAfterRelaunch() {
        let app = launchApp(
            atAccessibilityTextSize: true,
            persistentStoreName: "tracked-pitch-edit-\(UUID().uuidString)"
        )
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
        XCTAssertTrue(scrollUntilHittable(app.buttons["offense.pitch.ball"], in: app))
        app.buttons["offense.pitch.ball"].tap()
        XCTAssertTrue(scrollUntilHittable(app.buttons["offense.pitch.calledStrike"], in: app))
        app.buttons["offense.pitch.calledStrike"].tap()
        XCTAssertTrue(waitForLabel("1 – 1", on: count))

        app.buttons["game.history"].tap()
        XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
        app.buttons["history.entry.1"].tap()
        let editPitch = app.buttons["history.editTrackedPitch.1"]
        XCTAssertTrue(editPitch.waitForExistence(timeout: 3))
        XCTAssertEqual(editPitch.label, "Edit Player 01 Ball pitch, sequence 1")
        editPitch.tap()

        XCTAssertTrue(app.navigationBars["Edit Tracked Pitch"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Top 1 · Player 01 · Batting slot 1 of 14 · Sequence 1"].exists)
        XCTAssertTrue(app.staticTexts["Current: Ball · Count 1–0"].exists)
        XCTAssertFalse(app.buttons["trackedPitchEdit.save"].isEnabled)
        let form = app.collectionViews.firstMatch
        let swingingStrike = app.buttons["trackedPitchEdit.result.swingingStrike"]
        XCTAssertTrue(swipeWithinUntilHittable(swingingStrike, in: form))
        swingingStrike.tap()
        let proposed = app.staticTexts["trackedPitchEdit.proposed"]
        XCTAssertTrue(swipeWithinUntilHittable(proposed, in: form))
        XCTAssertEqual(proposed.label, "Proposed: Swinging Strike · Count 0–1")
        let save = app.buttons["trackedPitchEdit.save"]
        XCTAssertTrue(save.isEnabled)
        save.tap()

        XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["history.entry.1"].label.contains("Player 01"))
        XCTAssertTrue(app.buttons["history.entry.1"].label.contains("0–2 count"))
        app.navigationBars["Play History"].buttons.firstMatch.tap()
        XCTAssertEqual(currentBatter.label, "Player 01")
        XCTAssertEqual(count.label, "0 – 2")

        app.terminate()
        app.launch()
        app.tabBars.buttons["Games"].tap()
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()
        XCTAssertEqual(app.staticTexts["offense.currentBatter"].label, "Player 01")
        XCTAssertEqual(app.staticTexts["game.count"].label, "0 – 2")
    }

    func testUndoTrackedTeamScoringPlateAppearanceRestoresBatterScoreAndBattingLine() {
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
        let homeRun = app.buttons["Home Run"]
        XCTAssertTrue(scrollUntilHittable(homeRun, in: app))
        homeRun.tap()
        XCTAssertTrue(waitForLabel("Player 02", on: currentBatter))

        app.buttons["game.history"].tap()
        XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
        let undo = app.buttons["history.undoLatestAction"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        XCTAssertEqual(undo.label, "Undo Latest Play")
        undo.tap()
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(
                format: "label CONTAINS %@",
                "Top of inning 1, Player 01, batting slot 1 of 14, sequence 1: Home Run"
            )
        ).firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Runner movements: Batter to Home")
        ).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Runs: 1. RBI: 1")
        ).firstMatch.exists)
        app.buttons["Undo Home Run"].tap()

        XCTAssertTrue(app.staticTexts["No Plays Yet"].waitForExistence(timeout: 3))
        app.navigationBars["Play History"].buttons.firstMatch.tap()
        XCTAssertTrue(waitForLabel("Player 01", on: currentBatter))
        XCTAssertTrue(app.staticTexts["Us 0 · Opp 0"].exists)
        let battingLine = app.otherElements["offense.battingLine"]
        XCTAssertTrue(scrollUntilHittable(battingLine, in: app))
        XCTAssertEqual(battingLine.staticTexts["scorebook.stat.pa.value"].label, "0")
        XCTAssertEqual(battingLine.staticTexts["scorebook.stat.hr.value"].label, "0")
        XCTAssertEqual(battingLine.staticTexts["scorebook.stat.r.value"].label, "0")
        XCTAssertEqual(battingLine.staticTexts["scorebook.stat.rbi.value"].label, "0")
    }

    func testUndoTrackedTeamThirdOutPlateAppearanceRestoresOffensiveHalfAndBatter() {
        let app = launchApp(atAccessibilityTextSize: true)
        app.tabBars.buttons["Games"].tap()
        let liveGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI Opponent")
        ).firstMatch
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()

        for expectedBatter in ["Player 02", "Player 03"] {
            let strikeout = app.buttons["Strikeout"]
            XCTAssertTrue(scrollUntilHittable(strikeout, in: app))
            strikeout.tap()
            XCTAssertTrue(waitForLabel(expectedBatter, on: app.staticTexts["offense.currentBatter"]))
        }
        let thirdStrikeout = app.buttons["Strikeout"]
        XCTAssertTrue(scrollUntilHittable(thirdStrikeout, in: app))
        thirdStrikeout.tap()
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Pitching · 0 pitches · Opp batter 1")
        ).firstMatch.waitForExistence(timeout: 3))

        let undo = app.buttons["game.undoLatestAction"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        XCTAssertEqual(undo.label, "Undo Latest Play")
        undo.tap()
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(
                format: "label CONTAINS %@",
                "Top of inning 1, Player 03, batting slot 3 of 14, sequence 3: Strikeout"
            )
        ).firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Runner movements: Batter to Out")
        ).firstMatch.exists)
        app.buttons["Undo Strikeout"].tap()

        let restoredBatter = app.staticTexts["offense.currentBatter"]
        XCTAssertTrue(restoredBatter.waitForExistence(timeout: 3))
        XCTAssertEqual(restoredBatter.label, "Player 03")
        XCTAssertEqual(app.staticTexts["game.count"].label, "0 – 0")

        app.navigationBars["UI Opponent"].buttons.firstMatch.tap()
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()
        XCTAssertTrue(restoredBatter.waitForExistence(timeout: 3))
        XCTAssertEqual(restoredBatter.label, "Player 03")
    }

    func testUndoStolenBaseConfirmsExactRunnerAndPersistsRestoredBaseState() {
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
        let single = app.buttons["1B"]
        XCTAssertTrue(scrollUntilHittable(single, in: app))
        single.tap()
        XCTAssertTrue(app.navigationBars["Record Our Play"].waitForExistence(timeout: 3))
        app.buttons["Record"].tap()
        XCTAssertTrue(waitForLabel("Player 02", on: currentBatter))

        let stealSecond = app.buttons["offense.baseRunning.first.stolenBase"]
        XCTAssertTrue(scrollUntilHittable(stealSecond, in: app))
        stealSecond.tap()
        XCTAssertEqual(currentBatter.label, "Player 02")
        XCTAssertEqual(app.staticTexts["game.count"].label, "0 – 0")

        app.buttons["game.history"].tap()
        XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
        let stolenBase = app.buttons["history.entry.2"]
        XCTAssertTrue(stolenBase.waitForExistence(timeout: 3))
        XCTAssertTrue(stolenBase.label.contains("Player 01"))
        XCTAssertTrue(stolenBase.label.contains("SB · 1B to 2B"))

        let undo = app.buttons["history.undoLatestAction"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        XCTAssertEqual(undo.label, "Undo Latest SB")
        undo.tap()
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(
                format: "label CONTAINS %@",
                "Top of inning 1, Player 01, batting slot 1 of 14, sequence 2: SB · 1B to 2B"
            )
        ).firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "identified runner will return to 1B")
        ).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "active tracked batter, count, and plate-appearance progression will remain unchanged")
        ).firstMatch.exists)
        app.buttons["Undo SB · 1B to 2B"].tap()

        XCTAssertFalse(app.buttons["history.entry.2"].exists)
        XCTAssertTrue(app.buttons["history.entry.1"].waitForExistence(timeout: 3))
        app.navigationBars["Play History"].buttons.firstMatch.tap()
        XCTAssertTrue(waitForLabel("Player 02", on: currentBatter))
        XCTAssertEqual(app.staticTexts["game.count"].label, "0 – 0")
        let restoredRunner = app.buttons["offense.baseRunning.first.stolenBase"]
        XCTAssertTrue(scrollUntilHittable(restoredRunner, in: app))

        app.navigationBars["UI Opponent"].buttons.firstMatch.tap()
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()
        XCTAssertTrue(waitForLabel("Player 02", on: currentBatter))
        XCTAssertTrue(scrollUntilHittable(restoredRunner, in: app))
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

        let liveUndo = app.buttons["game.undoLatestAction"]
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
        let historyUndo = app.buttons["history.undoLatestAction"]
        XCTAssertTrue(historyUndo.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(historyUndo.frame.height, 44)
        historyUndo.tap()
        XCTAssertTrue(app.buttons["Undo Ball"].waitForExistence(timeout: 3))
        app.buttons["Undo Ball"].tap()
        XCTAssertTrue(app.buttons["history.undoLatestAction"].waitForExistence(timeout: 3))

        app.navigationBars["Play History"].buttons.firstMatch.tap()
        XCTAssertTrue(count.waitForExistence(timeout: 3))
        XCTAssertEqual(count.label, "3 – 0")
        XCTAssertTrue(app.staticTexts["Pitching · 3 pitches · Opp batter 1"].exists)
        XCTAssertTrue(app.buttons["game.undoLatestAction"].isHittable)
    }

    func testEarlierDefensivePitchEditCancelsThenSavesAndPersists() {
        let app = launchApp(atAccessibilityExtraExtraExtraLarge: true)
        app.tabBars.buttons["Games"].tap()
        let liveGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI Pitch Edit Opponent")
        ).firstMatch
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()

        let count = app.staticTexts["game.count"]
        XCTAssertTrue(count.waitForExistence(timeout: 3))
        XCTAssertEqual(count.label, "1 – 1")
        XCTAssertTrue(app.staticTexts["Pitching · 2 pitches · Opp batter 1"].exists)
        app.buttons["game.history"].tap()
        XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
        app.buttons["history.entry.1"].tap()

        let editPitch = app.buttons["history.editPitch.1"]
        XCTAssertTrue(editPitch.waitForExistence(timeout: 3))
        XCTAssertEqual(editPitch.label, "Edit Ball pitch, sequence 1")
        XCTAssertGreaterThanOrEqual(editPitch.frame.height, 44)
        editPitch.tap()

        XCTAssertTrue(app.navigationBars["Edit Pitch"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Top 1 · Opponent batter 1 · Sequence 1"].exists)
        XCTAssertTrue(app.staticTexts["Current: Ball · Count 1–0"].exists)
        XCTAssertFalse(app.buttons["pitchEdit.save"].isEnabled)
        let cancel = app.buttons["pitchEdit.cancel"]
        XCTAssertGreaterThanOrEqual(cancel.frame.height, 44)
        cancel.tap()
        XCTAssertTrue(app.buttons["history.editPitch.1"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["history.entry.1"].label.contains("1–1 count"))

        app.buttons["history.editPitch.1"].tap()
        let editForm = app.collectionViews.firstMatch
        XCTAssertTrue(editForm.waitForExistence(timeout: 3))
        let swingingStrike = app.buttons["pitchEdit.result.swingingStrike"]
        XCTAssertTrue(swipeWithinUntilHittable(swingingStrike, in: editForm))
        swingingStrike.tap()
        let proposed = app.staticTexts["pitchEdit.proposed"]
        XCTAssertTrue(swipeWithinUntilHittable(proposed, in: editForm))
        XCTAssertEqual(proposed.label, "Proposed: Swinging Strike · Count 0–1")
        let cleanReplay = app.staticTexts["Candidate timeline replays cleanly"]
        XCTAssertTrue(swipeWithinUntilHittable(cleanReplay, in: editForm))
        let save = app.buttons["pitchEdit.save"]
        XCTAssertTrue(save.isEnabled)
        XCTAssertGreaterThanOrEqual(save.frame.height, 44)
        save.tap()

        XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["history.entry.1"].label.contains("0–2 count"))
        app.navigationBars["Play History"].buttons.firstMatch.tap()
        XCTAssertTrue(count.waitForExistence(timeout: 3))
        XCTAssertEqual(count.label, "0 – 2")
        XCTAssertTrue(app.staticTexts["Pitching · 2 pitches · Opp batter 1"].exists)

        app.navigationBars["UI Pitch Edit Opponent"].buttons.firstMatch.tap()
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()
        XCTAssertTrue(count.waitForExistence(timeout: 3))
        XCTAssertEqual(count.label, "0 – 2")
        XCTAssertTrue(app.staticTexts["Pitching · 2 pitches · Opp batter 1"].exists)
    }

    func testEarlierDefensivePitchDeletionCancelsThenSavesAndPersists() {
        let app = launchApp(atAccessibilityExtraExtraExtraLarge: true)
        app.tabBars.buttons["Games"].tap()
        let liveGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI Pitch Edit Opponent")
        ).firstMatch
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()

        let count = app.staticTexts["game.count"]
        XCTAssertTrue(count.waitForExistence(timeout: 3))
        XCTAssertEqual(count.label, "1 – 1")
        XCTAssertTrue(app.staticTexts["Pitching · 2 pitches · Opp batter 1"].exists)
        app.buttons["game.history"].tap()
        XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
        app.buttons["history.entry.1"].tap()

        let deletePitch = app.buttons["history.deletePitch.1"]
        XCTAssertTrue(deletePitch.waitForExistence(timeout: 3))
        XCTAssertEqual(deletePitch.label, "Delete Ball pitch, sequence 1")
        XCTAssertGreaterThanOrEqual(deletePitch.frame.height, 44)
        deletePitch.tap()

        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(
                format: "label CONTAINS %@",
                "Top of inning 1, opponent batting slot 1, sequence 1: Ball"
            )
        ).firstMatch.waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["history.deletePitch.1"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["history.entry.1"].label.contains("1–1 count"))

        app.buttons["history.deletePitch.1"].tap()
        let previewDeletion = app.buttons["Preview Deletion"]
        XCTAssertTrue(previewDeletion.waitForExistence(timeout: 3))
        previewDeletion.tap()

        XCTAssertTrue(app.navigationBars["Delete Pitch"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Top 1 · Opponent batter 1 · Sequence 1"].exists)
        XCTAssertTrue(app.staticTexts["Delete: Ball · Count 1–0"].exists)
        let cleanReplay = app.staticTexts["Candidate timeline replays cleanly"]
        let deleteForm = app.collectionViews.firstMatch
        XCTAssertTrue(deleteForm.waitForExistence(timeout: 3))
        XCTAssertTrue(swipeWithinUntilHittable(cleanReplay, in: deleteForm))
        let stagedCancel = app.buttons["pitchDelete.cancel"]
        XCTAssertGreaterThanOrEqual(stagedCancel.frame.height, 44)
        stagedCancel.tap()
        XCTAssertTrue(app.buttons["history.deletePitch.1"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["history.entry.1"].label.contains("1–1 count"))

        app.buttons["history.deletePitch.1"].tap()
        XCTAssertTrue(app.buttons["Preview Deletion"].waitForExistence(timeout: 3))
        app.buttons["Preview Deletion"].tap()
        XCTAssertTrue(app.navigationBars["Delete Pitch"].waitForExistence(timeout: 3))
        XCTAssertTrue(swipeWithinUntilHittable(
            app.staticTexts["Candidate timeline replays cleanly"],
            in: app.collectionViews.firstMatch
        ))
        let save = app.buttons["pitchDelete.save"]
        XCTAssertTrue(save.isEnabled)
        XCTAssertGreaterThanOrEqual(save.frame.height, 44)
        save.tap()

        XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["history.entry.2"].label.contains("0–1 count"))
        app.navigationBars["Play History"].buttons.firstMatch.tap()
        XCTAssertTrue(count.waitForExistence(timeout: 3))
        XCTAssertEqual(count.label, "0 – 1")
        XCTAssertTrue(app.staticTexts["Pitching · 1 pitches · Opp batter 1"].exists)

        app.navigationBars["UI Pitch Edit Opponent"].buttons.firstMatch.tap()
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()
        XCTAssertTrue(count.waitForExistence(timeout: 3))
        XCTAssertEqual(count.label, "0 – 1")
        XCTAssertTrue(app.staticTexts["Pitching · 1 pitches · Opp batter 1"].exists)
    }

    func testInvalidatingPitchDeletionRepairsDownstreamEventAndSavesBatchOnce() {
        let app = launchApp(atAccessibilityExtraExtraExtraLarge: true)
        app.tabBars.buttons["Games"].tap()
        let liveGame = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "UI Multi Correction Opponent")
        ).firstMatch
        XCTAssertTrue(liveGame.waitForExistence(timeout: 3))
        liveGame.tap()

        let count = app.staticTexts["game.count"]
        XCTAssertTrue(count.waitForExistence(timeout: 3))
        XCTAssertEqual(count.label, "0 – 1")
        XCTAssertTrue(app.staticTexts["Pitching · 5 pitches · Opp batter 2"].exists)
        app.buttons["game.history"].tap()
        XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
        app.buttons["history.entry.1"].tap()
        app.buttons["history.deletePitch.1"].tap()
        XCTAssertTrue(app.buttons["Preview Deletion"].waitForExistence(timeout: 3))
        app.buttons["Preview Deletion"].tap()

        XCTAssertTrue(app.navigationBars["Delete Pitch"].waitForExistence(timeout: 3))
        let form = app.collectionViews.firstMatch
        let problem = app.buttons["correction.problem.5"]
        XCTAssertTrue(swipeWithinUntilHittable(problem, in: form))
        XCTAssertFalse(app.buttons["pitchDelete.save"].isEnabled)
        XCTAssertTrue(problem.label.contains("Opponent batter 2"))
        problem.tap()

        XCTAssertTrue(app.navigationBars["Affected Event"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Top 1 · Opponent batter 2 · Called Strike"].exists)
        XCTAssertTrue(app.staticTexts[
            "Full replay reached opponent batter 1 with a 3–0 count before rejecting this pitch."
        ].exists)
        let repairDeletion = app.buttons["correction.repair.delete"]
        let affectedEventForm = app.collectionViews.element(boundBy: app.collectionViews.count - 1)
        XCTAssertTrue(swipeWithinUntilHittable(repairDeletion, in: affectedEventForm))
        repairDeletion.tap()

        XCTAssertTrue(app.navigationBars["Delete Pitch"].waitForExistence(timeout: 3))
        XCTAssertTrue(swipeWithinUntilHittable(
            app.staticTexts["Candidate timeline replays cleanly"],
            in: form
        ))
        XCTAssertTrue(app.staticTexts["correction.change.1"].exists)
        XCTAssertTrue(swipeWithinUntilHittable(
            app.staticTexts["correction.change.5"],
            in: form
        ))
        let save = app.buttons["pitchDelete.save"]
        XCTAssertTrue(save.isEnabled)
        save.tap()

        XCTAssertTrue(app.scrollViews["history.page"].waitForExistence(timeout: 3))
        app.navigationBars["Play History"].buttons.firstMatch.tap()
        XCTAssertTrue(count.waitForExistence(timeout: 3))
        XCTAssertEqual(count.label, "3 – 0")
        XCTAssertTrue(app.staticTexts["Pitching · 3 pitches · Opp batter 1"].exists)
        XCTAssertTrue(scrollUntilHittable(app.buttons["Ball"], in: app))
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
        let undo = app.buttons["game.undoLatestAction"]
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

    private func launchApp(
        atAccessibilityTextSize: Bool = false,
        atAccessibilityExtraExtraExtraLarge: Bool = false,
        persistentStoreName: String? = nil
    ) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        let contentSizeCategory: String
        if atAccessibilityExtraExtraExtraLarge {
            contentSizeCategory = "UICTContentSizeCategoryAccessibilityXXXL"
        } else if atAccessibilityTextSize {
            contentSizeCategory = "UICTContentSizeCategoryAccessibilityXL"
        } else {
            contentSizeCategory = "UICTContentSizeCategoryL"
        }
        app.launchArguments = [
            "-uiTesting",
            "-UIPreferredContentSizeCategoryName",
            contentSizeCategory
        ]
        if let persistentStoreName {
            app.launchArguments += [
                "-uiTestingStore",
                FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(persistentStoreName).store")
                    .path
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

    private func swipeWithinUntilHittable(
        _ element: XCUIElement,
        in scrollContainer: XCUIElement,
        above obstruction: XCUIElement? = nil
    ) -> Bool {
        let deadline = Date().addingTimeInterval(20)
        while !isSafelyHittable(element, in: scrollContainer, above: obstruction),
              Date() < deadline {
            if element.exists && element.frame.minY < scrollContainer.frame.minY {
                scrollContainer.swipeDown()
            } else {
                scrollContainer.swipeUp()
            }
        }
        return isSafelyHittable(element, in: scrollContainer, above: obstruction)
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
