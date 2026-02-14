import XCTest
@testable import ModoCore

final class ConfigTests: XCTestCase {

    func testSanitizeLowercasesAndHyphenates() {
        XCTAssertEqual(ModoConfig.sanitize("Swift App"), "swift-app")
    }

    func testSanitizeRemovesSpecialCharacters() {
        XCTAssertEqual(ModoConfig.sanitize("My Config!"), "my-config")
    }

    func testSanitizeHandlesMultipleSpaces() {
        XCTAssertEqual(ModoConfig.sanitize("a   b"), "a---b")
    }

    func testSanitizeAlreadyClean() {
        XCTAssertEqual(ModoConfig.sanitize("swift-app"), "swift-app")
    }

    func testSanitizeNumbers() {
        XCTAssertEqual(ModoConfig.sanitize("Project 2"), "project-2")
    }

    func testVersionIsSet() {
        XCTAssertFalse(ModoConfig.version.isEmpty)
    }

    func testPresetDirectoryContainsName() {
        let dir = ModoConfig.presetDirectory(named: "test-name")
        XCTAssertTrue(dir.path.contains("test-name"))
        XCTAssertTrue(dir.path.contains(".config/modo/presets"))
    }
}
