import XCTest
@testable import ModoCore

final class MergeEngineTests: XCTestCase {

    // MARK: - compileClaudeMD

    func testCompileSinglePreset() {
        let result = MergeEngine.compileClaudeMD(from: [
            (name: "Swift App", content: "Use SwiftUI for all views."),
        ])

        XCTAssertTrue(result.contains("## Swift App"))
        XCTAssertTrue(result.contains("Use SwiftUI for all views."))
        XCTAssertFalse(result.contains("    Use SwiftUI"))
    }

    func testCompileMultiplePresets() {
        let result = MergeEngine.compileClaudeMD(from: [
            (name: "Base", content: "Be concise."),
            (name: "Swift", content: "Use Swift 5.10."),
        ])

        XCTAssertTrue(result.contains("## Base"))
        XCTAssertTrue(result.contains("## Swift"))
        XCTAssertTrue(result.contains("Be concise."))
        XCTAssertTrue(result.contains("Use Swift 5.10."))
        XCTAssertTrue(result.contains("---"))
    }

    func testCompileSkipsEmptyContent() {
        let result = MergeEngine.compileClaudeMD(from: [
            (name: "Empty", content: "   \n  "),
            (name: "Valid", content: "Real content here."),
        ])

        XCTAssertFalse(result.contains("## Empty"))
        XCTAssertTrue(result.contains("## Valid"))
    }

    func testCompilePreservesMultilineContent() {
        let content = "Line one.\nLine two.\nLine three."
        let result = MergeEngine.compileClaudeMD(from: [
            (name: "Multi", content: content),
        ])

        XCTAssertTrue(result.contains("Line one."))
        XCTAssertTrue(result.contains("Line two."))
        XCTAssertTrue(result.contains("Line three."))
        XCTAssertFalse(result.contains("    Line one."))
    }

    func testCompileEmptyListReturnsEmpty() {
        let result = MergeEngine.compileClaudeMD(from: [])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - deepMerge

    func testDeepMergeStringArraysUnion() {
        let base: [String: Any] = [
            "permissions": ["allow": ["swift build", "swift test"]],
        ]
        let overlay: [String: Any] = [
            "permissions": ["allow": ["git push", "swift build"]],
        ]

        let result = MergeEngine.deepMerge(base: base, overlay: overlay)
        let perms = result["permissions"] as! [String: Any]
        let allow = perms["allow"] as! [String]

        XCTAssertEqual(allow.count, 3)
        XCTAssertTrue(allow.contains("swift build"))
        XCTAssertTrue(allow.contains("swift test"))
        XCTAssertTrue(allow.contains("git push"))
    }

    func testDeepMergeNoDuplicatesInStringArrays() {
        let base: [String: Any] = ["tags": ["swift", "ios"]]
        let overlay: [String: Any] = ["tags": ["ios", "macos"]]

        let result = MergeEngine.deepMerge(base: base, overlay: overlay)
        let tags = result["tags"] as! [String]

        XCTAssertEqual(tags.count, 3)
        XCTAssertEqual(tags, ["swift", "ios", "macos"])
    }

    func testDeepMergeNestedDicts() {
        let base: [String: Any] = [
            "permissions": ["allow": ["swift build"]],
        ]
        let overlay: [String: Any] = [
            "permissions": ["deny": ["rm -rf"]],
        ]

        let result = MergeEngine.deepMerge(base: base, overlay: overlay)
        let perms = result["permissions"] as! [String: Any]

        XCTAssertNotNil(perms["allow"])
        XCTAssertNotNil(perms["deny"])
        XCTAssertEqual(perms["allow"] as! [String], ["swift build"])
        XCTAssertEqual(perms["deny"] as! [String], ["rm -rf"])
    }

    func testDeepMergeOverlayWinsForScalars() {
        let base: [String: Any] = ["version": 1, "name": "old"]
        let overlay: [String: Any] = ["version": 2]

        let result = MergeEngine.deepMerge(base: base, overlay: overlay)

        XCTAssertEqual(result["version"] as! Int, 2)
        XCTAssertEqual(result["name"] as! String, "old")
    }

    func testDeepMergeAddsNewKeys() {
        let base: [String: Any] = ["a": 1]
        let overlay: [String: Any] = ["b": 2]

        let result = MergeEngine.deepMerge(base: base, overlay: overlay)

        XCTAssertEqual(result["a"] as! Int, 1)
        XCTAssertEqual(result["b"] as! Int, 2)
    }

    func testDeepMergeDictArraysConcatenated() {
        let base: [String: Any] = [
            "hooks": [["event": "pre-commit", "cmd": "lint"]],
        ]
        let overlay: [String: Any] = [
            "hooks": [["event": "post-commit", "cmd": "notify"]],
        ]

        let result = MergeEngine.deepMerge(base: base, overlay: overlay)
        let hooks = result["hooks"] as! [[String: Any]]

        XCTAssertEqual(hooks.count, 2)
        XCTAssertEqual(hooks[0]["event"] as! String, "pre-commit")
        XCTAssertEqual(hooks[1]["event"] as! String, "post-commit")
    }

    func testDeepMergeEmptyBase() {
        let base: [String: Any] = [:]
        let overlay: [String: Any] = ["key": "value"]

        let result = MergeEngine.deepMerge(base: base, overlay: overlay)

        XCTAssertEqual(result["key"] as! String, "value")
    }

    func testDeepMergeEmptyOverlay() {
        let base: [String: Any] = ["key": "value"]
        let overlay: [String: Any] = [:]

        let result = MergeEngine.deepMerge(base: base, overlay: overlay)

        XCTAssertEqual(result["key"] as! String, "value")
    }

    // MARK: - Full apply (dry run)

    func testApplyDryRunCreatesNoFiles() throws {
        // Create a real preset first
        let presetName = "test-dryrun-\(UUID().uuidString.prefix(8))"
        try PresetStore.create(name: presetName)

        // Write content to the preset's claude.md
        let claudeMDPath = ModoConfig.presetDirectory(named: presetName)
            .appendingPathComponent(ModoConfig.claudeMDFilename)
        try "Test content.".write(to: claudeMDPath, atomically: true, encoding: .utf8)

        // Create a temp project directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("modo-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? PresetStore.delete(name: presetName)
            try? FileManager.default.removeItem(at: tempDir)
        }

        let result = try MergeEngine.apply(
            presetNames: [presetName], to: tempDir, dryRun: true
        )

        // Should report files that would be created
        XCTAssertFalse(result.created.isEmpty)

        // But nothing should actually exist on disk
        let claudeDir = tempDir.appendingPathComponent(".claude")
        XCTAssertFalse(FileManager.default.fileExists(atPath: claudeDir.path))
    }

    func testApplyCreatesClaudeDirectory() throws {
        let presetName = "test-apply-\(UUID().uuidString.prefix(8))"
        try PresetStore.create(name: presetName)

        let claudeMDPath = ModoConfig.presetDirectory(named: presetName)
            .appendingPathComponent(ModoConfig.claudeMDFilename)
        try "Apply test content.".write(to: claudeMDPath, atomically: true, encoding: .utf8)

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("modo-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? PresetStore.delete(name: presetName)
            try? FileManager.default.removeItem(at: tempDir)
        }

        let result = try MergeEngine.apply(presetNames: [presetName], to: tempDir)

        XCTAssertTrue(result.created.contains(".claude/"))
        XCTAssertTrue(result.created.contains(".claude/claude.md"))

        let claudeMD = tempDir.appendingPathComponent(".claude/claude.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: claudeMD.path))

        let content = try String(contentsOf: claudeMD, encoding: .utf8)
        XCTAssertTrue(content.contains("Apply test content."))
    }

    func testApplyMultiplePresetsMergesSettings() throws {
        let preset1 = "test-merge1-\(UUID().uuidString.prefix(8))"
        let preset2 = "test-merge2-\(UUID().uuidString.prefix(8))"
        try PresetStore.create(name: preset1)
        try PresetStore.create(name: preset2)

        // Write settings for each
        let settings1 = """
        {"permissions": {"allow": ["swift build"]}}
        """
        let settings2 = """
        {"permissions": {"allow": ["git push"]}}
        """

        let dir1 = ModoConfig.presetDirectory(named: preset1)
        let dir2 = ModoConfig.presetDirectory(named: preset2)
        try settings1.write(
            to: dir1.appendingPathComponent(ModoConfig.settingsFilename),
            atomically: true, encoding: .utf8
        )
        try settings2.write(
            to: dir2.appendingPathComponent(ModoConfig.settingsFilename),
            atomically: true, encoding: .utf8
        )

        // Write claude.md content
        try "Preset 1 rules.".write(
            to: dir1.appendingPathComponent(ModoConfig.claudeMDFilename),
            atomically: true, encoding: .utf8
        )
        try "Preset 2 rules.".write(
            to: dir2.appendingPathComponent(ModoConfig.claudeMDFilename),
            atomically: true, encoding: .utf8
        )

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("modo-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? PresetStore.delete(name: preset1)
            try? PresetStore.delete(name: preset2)
            try? FileManager.default.removeItem(at: tempDir)
        }

        let result = try MergeEngine.apply(presetNames: [preset1, preset2], to: tempDir)

        XCTAssertEqual(result.sectionCount, 2)
        XCTAssertEqual(result.settingsPresetCount, 2)

        // Verify merged settings
        let settingsPath = tempDir.appendingPathComponent(".claude/settings.json")
        let data = try Data(contentsOf: settingsPath)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let perms = json["permissions"] as! [String: Any]
        let allow = perms["allow"] as! [String]

        XCTAssertTrue(allow.contains("swift build"))
        XCTAssertTrue(allow.contains("git push"))
        XCTAssertEqual(allow.count, 2)
    }

    func testApplyCreatesGitignore() throws {
        let presetName = "test-gitignore-\(UUID().uuidString.prefix(8))"
        try PresetStore.create(name: presetName)

        let claudeMDPath = ModoConfig.presetDirectory(named: presetName)
            .appendingPathComponent(ModoConfig.claudeMDFilename)
        try "Content.".write(to: claudeMDPath, atomically: true, encoding: .utf8)

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("modo-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? PresetStore.delete(name: presetName)
            try? FileManager.default.removeItem(at: tempDir)
        }

        let result = try MergeEngine.apply(presetNames: [presetName], to: tempDir)

        XCTAssertTrue(result.created.contains(".gitignore"))

        let gitignore = try String(
            contentsOf: tempDir.appendingPathComponent(".gitignore"), encoding: .utf8
        )
        XCTAssertTrue(gitignore.contains(".claude/"))
    }

    func testApplyWritesModoJson() throws {
        let presetName = "test-record-\(UUID().uuidString.prefix(8))"
        try PresetStore.create(name: presetName)

        let claudeMDPath = ModoConfig.presetDirectory(named: presetName)
            .appendingPathComponent(ModoConfig.claudeMDFilename)
        try "Content.".write(to: claudeMDPath, atomically: true, encoding: .utf8)

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("modo-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? PresetStore.delete(name: presetName)
            try? FileManager.default.removeItem(at: tempDir)
        }

        _ = try MergeEngine.apply(presetNames: [presetName], to: tempDir)

        let recordPath = tempDir.appendingPathComponent(".claude/\(ModoConfig.applyRecordFilename)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: recordPath.path))

        let data = try Data(contentsOf: recordPath)
        let record = try JSONDecoder().decode(ApplyRecord.self, from: data)
        XCTAssertEqual(record.presets, [presetName])
        XCTAssertEqual(record.modoVersion, ModoConfig.version)
    }

    func testReapplyBacksUpExistingFiles() throws {
        let presetName = "test-backup-\(UUID().uuidString.prefix(8))"
        try PresetStore.create(name: presetName)

        let presetDir = ModoConfig.presetDirectory(named: presetName)
        try "Original content.".write(
            to: presetDir.appendingPathComponent(ModoConfig.claudeMDFilename),
            atomically: true, encoding: .utf8
        )
        try """
        {"permissions": {"allow": ["swift build"]}}
        """.write(
            to: presetDir.appendingPathComponent(ModoConfig.settingsFilename),
            atomically: true, encoding: .utf8
        )

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("modo-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? PresetStore.delete(name: presetName)
            try? FileManager.default.removeItem(at: tempDir)
        }

        // First apply
        let result1 = try MergeEngine.apply(presetNames: [presetName], to: tempDir)
        XCTAssertTrue(result1.backedUp.isEmpty)
        XCTAssertTrue(result1.created.contains(".claude/claude.md"))

        // Second apply — should back up
        let result2 = try MergeEngine.apply(presetNames: [presetName], to: tempDir)
        XCTAssertTrue(result2.backedUp.contains(".claude/claude.md.bak"))
        XCTAssertTrue(result2.backedUp.contains(".claude/settings.json.bak"))
        XCTAssertTrue(result2.modified.contains(".claude/claude.md"))

        // Verify .bak files exist on disk
        let claudeBak = tempDir.appendingPathComponent(".claude/claude.md.bak")
        let settingsBak = tempDir.appendingPathComponent(".claude/settings.json.bak")
        XCTAssertTrue(FileManager.default.fileExists(atPath: claudeBak.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: settingsBak.path))

        // Verify .bak content matches what was there before
        let bakContent = try String(contentsOf: claudeBak, encoding: .utf8)
        XCTAssertTrue(bakContent.contains("Original content."))
    }
}
