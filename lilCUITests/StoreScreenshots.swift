import XCTest
import UIKit

/// Host-driven store screenshots. Saves a native PNG into the UITest runner
/// documents at the exact moment of each frame. Do not enable in CI schemes.
@MainActor
final class StoreScreenshots: XCTestCase {
    private var app: XCUIApplication!

    func testCaptureListingScreens() {
        XCUIDevice.shared.orientation = .portrait

        app = XCUIApplication()
        app.launchArguments.append("UITEST_STORE_SHOTS")
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        sleep(2)

        XCTAssertTrue(app.staticTexts["Projects"].waitForExistence(timeout: 8), app.debugDescription)
        capture("01-home")

        XCTAssertTrue(app.buttons["LEARN"].waitForExistence(timeout: 4), app.debugDescription)
        app.buttons["LEARN"].tap()
        XCTAssertTrue(app.staticTexts["Lessons"].waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Challenges"].waitForExistence(timeout: 4), app.debugDescription)

        let helloCard = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Lesson 1 of 20'")).firstMatch
        XCTAssertTrue(helloCard.waitForExistence(timeout: 6), app.debugDescription)
        helloCard.tap()

        let run = app.buttons["RUN"]
        XCTAssertTrue(run.waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(
            (app.textViews.firstMatch.value as? String)?.contains("???") == true
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS '???'")).firstMatch.waitForExistence(timeout: 4),
            app.debugDescription
        )
        dismissKeyboard()
        sleep(1)
        capture("02-lesson-blank")

        replaceEditor(with: Self.helloSolution)
        dismissKeyboard()
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.tap()
        XCTAssertTrue(
            app.staticTexts["Nice."].waitForExistence(timeout: 10)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'hello from lilC'")).firstMatch.waitForExistence(timeout: 2),
            app.debugDescription
        )
        capture("03-hello-run")

        sleep(3)
        replaceEditor(with: Self.syntaxErrorProgram)
        dismissKeyboard()
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.tap()
        XCTAssertTrue(
            app.buttons["Jump to error"].waitForExistence(timeout: 10)
                || app.staticTexts["ERROR"].waitForExistence(timeout: 2)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'SYNTAX ERROR'")).firstMatch.waitForExistence(timeout: 2),
            app.debugDescription
        )
        capture("04-error-jump")

        tapBack()
        sleep(1)
        XCTAssertTrue(app.buttons["HOME"].waitForExistence(timeout: 4), app.debugDescription)
        app.buttons["HOME"].tap()
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 6), app.debugDescription)
        settings.tap()
        XCTAssertTrue(app.staticTexts["Appearance"].waitForExistence(timeout: 6), app.debugDescription)
        sleep(1)
        capture("05-settings")
    }

    func testCaptureSettingsOnly() {
        XCUIDevice.shared.orientation = .portrait

        app = XCUIApplication()
        app.launchArguments.append("UITEST_STORE_SHOTS")
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        sleep(2)

        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8), app.debugDescription)
        settings.tap()
        XCTAssertTrue(app.staticTexts["Appearance"].waitForExistence(timeout: 6), app.debugDescription)
        XCTAssertTrue(app.staticTexts["PicoC"].waitForExistence(timeout: 4), app.debugDescription)
        sleep(1)
        capture("05-settings")
    }

    func testStdinStaysAboveKeyboardWhileWaiting() {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments.append("UITEST_STORE_SHOTS")
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let helloCard = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Lesson 1 of 20'")).firstMatch
        XCTAssertTrue(helloCard.waitForExistence(timeout: 8), app.debugDescription)
        helloCard.tap()

        let run = app.buttons["RUN"]
        XCTAssertTrue(run.waitForExistence(timeout: 8), app.debugDescription)
        replaceEditor(with: Self.stdinPromptProgram)
        dismissKeyboard()
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.tap()
        assertStdinSitsAboveKeyboard()
    }

    func testStdinStaysAboveKeyboardWhenRunWithEditorKeyboardUp() {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments.append("UITEST_STORE_SHOTS")
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let helloCard = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Lesson 1 of 20'")).firstMatch
        XCTAssertTrue(helloCard.waitForExistence(timeout: 8), app.debugDescription)
        helloCard.tap()

        let run = app.buttons["RUN"]
        XCTAssertTrue(run.waitForExistence(timeout: 8), app.debugDescription)
        replaceEditor(with: Self.stdinPromptProgram)
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 6), "Editor keyboard should stay up")
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.tap()
        assertStdinSitsAboveKeyboard()
    }

    private func assertStdinSitsAboveKeyboard() {
        XCTAssertTrue(
            app.otherElements["waiting-for-input"].waitForExistence(timeout: 10)
                || app.staticTexts["WAITING FOR INPUT"].waitForExistence(timeout: 2),
            app.debugDescription
        )

        let stdin = app.textFields["program-stdin"]
        XCTAssertTrue(stdin.waitForExistence(timeout: 6), app.debugDescription)
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 6), "Keyboard should be up for stdin")

        let keyboard = app.keyboards.element
        XCTAssertLessThan(
            stdin.frame.maxY,
            keyboard.frame.minY + 12,
            "stdin field is covered by the keyboard: stdin.maxY=\(stdin.frame.maxY) keyboard.minY=\(keyboard.frame.minY)"
        )

        let prompt = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Enter your name'")).firstMatch
        if prompt.waitForExistence(timeout: 4) {
            XCTAssertLessThan(
                prompt.frame.maxY,
                keyboard.frame.minY + 12,
                "program prompt is covered by the keyboard"
            )
        }
    }

    private func capture(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let data = shot.pngRepresentation
        savePNG(data, name: name)

        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        UIPasteboard.general.string = "READY:\(name)"
        Thread.sleep(forTimeInterval: 0.4)
        UIPasteboard.general.string = "IDLE:\(name)"
    }

    private func savePNG(_ data: Data, name: String) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("store-shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: dir.appendingPathComponent("\(name).png"))
    }

    private func replaceEditor(with text: String) {
        let editor = app.textViews["code-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 8), app.debugDescription)
        editor.tap()
        sleep(1)
        editor.press(forDuration: 1.2)
        let selectAll = app.menuItems["Select All"]
        if selectAll.waitForExistence(timeout: 3) {
            selectAll.tap()
            sleep(1)
        } else {
            editor.tap()
            sleep(1)
            editor.press(forDuration: 1.4)
            if selectAll.waitForExistence(timeout: 3) {
                selectAll.tap()
                sleep(1)
            }
        }
        editor.typeText(text)
        sleep(1)
    }

    private func dismissKeyboard() {
        if app.keyboards.element.exists {
            app.keyboards.buttons["done"].tapIfExists()
            app.keyboards.buttons["Done"].tapIfExists()
        }
        if app.keyboards.element.exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }
    }

    private func tapBack() {
        let labeled = app.buttons["Back"]
        if labeled.waitForExistence(timeout: 2), labeled.isHittable {
            labeled.tap()
            return
        }
        let chevron = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'back' OR label CONTAINS[c] 'chevron'")).firstMatch
        if chevron.exists, chevron.isHittable {
            chevron.tap()
            return
        }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.07)).tap()
    }

    private static let helloSolution = """
    #include <stdio.h>

    int main(void) {
        printf("hello from lilC\\n");
        return 0;
    }

    """

    private static let syntaxErrorProgram = """
    #include <stdio.h>

    int main(void) {
        printf("hello from lilC\\n"
        return 0;
    }

    """

    private static let stdinPromptProgram = """
    #include <stdio.h>

    int main(void) {
        char name[80];
        printf("=== Input / Output Test ===\\n");
        printf("Enter your name:\\n");
        scanf("%79s", name);
        printf("Hi %s\\n", name);
        return 0;
    }

    """
}

private extension XCUIElement {
    func tapIfExists(requireHittable: Bool = true) {
        guard exists else { return }
        if requireHittable, !isHittable { return }
        tap()
    }
}
