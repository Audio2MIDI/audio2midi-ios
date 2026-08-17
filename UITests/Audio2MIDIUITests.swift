import XCTest

final class Audio2MIDIUITests: XCTestCase {
    func testOnboardingHasOneClearAction() {
        let app = XCUIApplication()
        app.launchArguments = ["-fixture=ready", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.staticTexts["onboarding.title"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["onboarding.continue"].exists)
        attachScreenshot(app, name: "Onboarding")
    }

    func testReadyLibraryAndCreateModes() {
        let app = XCUIApplication()
        app.launchArguments = ["-fixture=ready", "-skipOnboarding", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Midnight Sketch"].waitForExistence(timeout: 4))
        attachScreenshot(app, name: "Ready library")
        app.tabBars.buttons["Create"].tap()
        XCTAssertTrue(app.buttons["mode.piano_cover"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["mode.piano_transcription"].exists)
        XCTAssertTrue(app.buttons["mode.notes_chords"].exists)
        XCTAssertTrue(app.buttons["mode.music2midi"].exists)
        XCTAssertTrue(app.buttons["mode.stems"].exists)
        attachScreenshot(app, name: "Create studio")
    }

    func testEmptyLibraryState() {
        let app = XCUIApplication()
        app.launchArguments = ["-fixture=empty", "-skipOnboarding", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.staticTexts["No projects yet"].waitForExistence(timeout: 4))
        attachScreenshot(app, name: "Empty library")
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
