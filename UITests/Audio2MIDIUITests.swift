import XCTest

final class Audio2MIDIUITests: XCTestCase {
    func testOnboardingHasOneClearAction() {
        let app = XCUIApplication()
        app.launchArguments = ["-fixture=ready", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.staticTexts["onboarding.title"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["onboarding.continue"].exists)
    }

    func testReadyLibraryAndCreateModes() {
        let app = XCUIApplication()
        app.launchArguments = ["-fixture=ready", "-skipOnboarding", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.otherElements["project.fixture-1"].waitForExistence(timeout: 4))
        app.tabBars.buttons["Create"].tap()
        XCTAssertTrue(app.buttons["mode.piano_cover"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["mode.notes_chords"].exists)
        XCTAssertTrue(app.buttons["mode.stems"].exists)
    }

    func testEmptyLibraryState() {
        let app = XCUIApplication()
        app.launchArguments = ["-fixture=empty", "-skipOnboarding", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.otherElements["library.empty"].waitForExistence(timeout: 4))
    }
}

