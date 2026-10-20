import XCTest

/// End-to-end flows through the real interface.
/// The app launches with `--uitesting`, which uses an in-memory save and seeds 1,000 embers.
final class MagmaRunUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func waitFor(_ identifier: String, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element(identifier).waitForExistence(timeout: timeout), "Expected \(identifier) to appear", file: file, line: line)
    }

    private func goBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.waitForExistence(timeout: 3) {
            back.tap()
        }
    }

    // MARK: - Home

    @MainActor
    func testHomeShowsCoreElements() {
        waitFor("home.screen")
        XCTAssertTrue(element("home.play").exists)
        XCTAssertTrue(element("home.forge").exists)
        XCTAssertTrue(element("home.heroes").exists)
        XCTAssertTrue(element("home.records").exists)
        XCTAssertTrue(element("home.howToPlay").exists)
        XCTAssertTrue(element("home.settings").exists)
        XCTAssertTrue(element("home.emberBalance").exists)
    }

    // MARK: - Navigation

    @MainActor
    func testNavigatesToEveryScreenAndBack() {
        waitFor("home.screen")

        element("home.forge").tap()
        waitFor("forge.screen")
        goBack()
        waitFor("home.screen")

        element("home.heroes").tap()
        waitFor("heroes.screen")
        goBack()
        waitFor("home.screen")

        element("home.records").tap()
        waitFor("records.screen")
        XCTAssertTrue(element("records.empty").waitForExistence(timeout: 3))
        goBack()
        waitFor("home.screen")

        element("home.howToPlay").tap()
        waitFor("howToPlay.screen")
        goBack()
        waitFor("home.screen")

        element("home.settings").tap()
        waitFor("settings.screen")
        XCTAssertTrue(element("settings.haptics").exists)
        XCTAssertTrue(element("settings.controls").exists)
        XCTAssertTrue(element("settings.reset").exists)
        goBack()
        waitFor("home.screen")
    }

    // MARK: - Forge

    @MainActor
    func testForgePurchaseShowsConfirmation() {
        waitFor("home.screen")
        element("home.forge").tap()
        waitFor("forge.screen")

        let agility = element("forge.upgrade.agility")
        XCTAssertTrue(agility.waitForExistence(timeout: 3))
        agility.tap()

        XCTAssertTrue(app.staticTexts["Agility forged to level 1."].waitForExistence(timeout: 3))
        // The button now advertises the next level's price.
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Forge Agility for 100")).firstMatch.waitForExistence(timeout: 3))
    }

    @MainActor
    func testForgeRejectsUnaffordableUpgrade() {
        waitFor("home.screen")
        element("home.forge").tap()
        waitFor("forge.screen")

        // Shield level 1 costs 130; buy enough other upgrades to drop below that first.
        let fortune = element("forge.upgrade.fortune")
        XCTAssertTrue(fortune.waitForExistence(timeout: 3))
        for level in 1...4 {
            fortune.tap()
            XCTAssertTrue(app.staticTexts["Fortune forged to level \(level)."].waitForExistence(timeout: 3))
            // Wait for the toast to clear so the next tap is not swallowed by animation.
            _ = app.staticTexts["Fortune forged to level \(level)."].waitForNonExistence(timeout: 4)
        }
        element("forge.upgrade.shield").tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "You need")).firstMatch.waitForExistence(timeout: 3))
    }

    // MARK: - Heroes

    @MainActor
    func testUnlockingHeroEquipsIt() {
        waitFor("home.screen")
        element("home.heroes").tap()
        waitFor("heroes.screen")

        let unlock = element("heroes.action.emberScout")
        XCTAssertTrue(unlock.waitForExistence(timeout: 3))
        unlock.tap()

        XCTAssertTrue(app.staticTexts["Ember Scout unlocked and equipped."].waitForExistence(timeout: 3))
        let card = element("heroes.card.emberScout")
        XCTAssertTrue(card.staticTexts["EQUIPPED"].waitForExistence(timeout: 3))
    }

    // MARK: - Settings

    @MainActor
    func testResetProgressFlow() {
        waitFor("home.screen")
        element("home.settings").tap()
        waitFor("settings.screen")

        element("settings.reset").tap()
        let confirm = app.buttons["Reset everything"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()

        XCTAssertTrue(app.staticTexts["Progress reset. The mountain awaits."].waitForExistence(timeout: 3))
    }

    // MARK: - Game

    @MainActor
    func testStartPauseResumeAndQuitRun() {
        waitFor("home.screen")
        element("home.play").tap()
        waitFor("game.screen")

        let start = element("game.start")
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        // The countdown lasts just over two seconds before the HUD becomes interactive.
        let pause = element("game.pause")
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: pause)
        XCTAssertEqual(XCTWaiter().wait(for: [hittable], timeout: 10), .completed, "Pause button never became tappable")
        pause.tap()

        waitFor("game.pausedOverlay")
        element("game.resume").tap()
        XCTAssertTrue(element("game.pausedOverlay").waitForNonExistence(timeout: 3))

        pause.tap()
        waitFor("game.pausedOverlay")
        element("game.quit").tap()

        waitFor("home.screen")
    }

    // MARK: - iPad

    /// iPad supports every orientation, so the camp and the game must stay usable in landscape.
    @MainActor
    func testLandscapeLayoutOnPad() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "Landscape is only supported on iPad")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }

        waitFor("home.screen")
        XCTAssertTrue(element("home.play").isHittable)
        XCTAssertTrue(element("home.forge").isHittable)
        attachScreenshot(named: "iPad landscape home")

        element("home.forge").tap()
        waitFor("forge.screen")
        XCTAssertTrue(element("forge.upgrade.agility").isHittable)
        attachScreenshot(named: "iPad landscape forge")
        goBack()
        waitFor("home.screen")

        element("home.play").tap()
        waitFor("game.screen")
        let start = element("game.start")
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isHittable)
        attachScreenshot(named: "iPad landscape game ready")
        start.tap()

        let pause = element("game.pause")
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: pause)
        XCTAssertEqual(XCTWaiter().wait(for: [hittable], timeout: 10), .completed)
        attachScreenshot(named: "iPad landscape game running")
        pause.tap()
        waitFor("game.pausedOverlay")
        element("game.quit").tap()
        waitFor("home.screen")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
