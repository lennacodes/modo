import XCTest
@testable import ModoCore

final class PresetStoreTests: XCTestCase {

    // MARK: - Create & Read

    func testCreatePreset() throws {
        let name = "test-create-\(UUID().uuidString.prefix(8))"
        defer { try? PresetStore.delete(name: name) }

        try PresetStore.create(name: name, description: "A test", tags: ["testing"])

        XCTAssertTrue(PresetStore.exists(name: name))

        let info = try PresetStore.readInfo(name: name)
        XCTAssertEqual(info.name, name)
        XCTAssertEqual(info.description, "A test")
        XCTAssertEqual(info.tags, ["testing"])
    }

    func testCreatePresetCreatesEmptyClaudeMD() throws {
        let name = "test-empty-md-\(UUID().uuidString.prefix(8))"
        defer { try? PresetStore.delete(name: name) }

        try PresetStore.create(name: name)

        let content = PresetStore.readClaudeMD(name: name)
        XCTAssertNotNil(content)
        XCTAssertEqual(content, "")
    }

    func testCreateDuplicateThrows() throws {
        let name = "test-dup-\(UUID().uuidString.prefix(8))"
        defer { try? PresetStore.delete(name: name) }

        try PresetStore.create(name: name)

        XCTAssertThrowsError(try PresetStore.create(name: name)) { error in
            guard case ModoError.presetAlreadyExists = error else {
                XCTFail("Expected presetAlreadyExists, got \(error)")
                return
            }
        }
    }

    // MARK: - Exists

    func testExistsReturnsFalseForMissing() {
        XCTAssertFalse(PresetStore.exists(name: "nonexistent-\(UUID().uuidString)"))
    }

    // MARK: - Delete

    func testDeletePreset() throws {
        let name = "test-delete-\(UUID().uuidString.prefix(8))"
        try PresetStore.create(name: name)

        XCTAssertTrue(PresetStore.exists(name: name))

        try PresetStore.delete(name: name)

        XCTAssertFalse(PresetStore.exists(name: name))
    }

    func testDeleteNonexistentThrows() {
        XCTAssertThrowsError(try PresetStore.delete(name: "does-not-exist-\(UUID().uuidString)")) { error in
            guard case ModoError.presetNotFound = error else {
                XCTFail("Expected presetNotFound, got \(error)")
                return
            }
        }
    }

    // MARK: - Read/Write files

    func testReadSettingsReturnsNilWhenMissing() throws {
        let name = "test-no-settings-\(UUID().uuidString.prefix(8))"
        defer { try? PresetStore.delete(name: name) }

        try PresetStore.create(name: name)

        let settings = PresetStore.readSettings(name: name)
        XCTAssertNil(settings)
    }

    func testReadSettingsReturnsContent() throws {
        let name = "test-settings-\(UUID().uuidString.prefix(8))"
        defer { try? PresetStore.delete(name: name) }

        try PresetStore.create(name: name)

        let settingsJSON = """
        {"permissions": {"allow": ["swift test"]}}
        """
        let settingsPath = ModoConfig.presetDirectory(named: name)
            .appendingPathComponent(ModoConfig.settingsFilename)
        try settingsJSON.write(to: settingsPath, atomically: true, encoding: .utf8)

        let read = PresetStore.readSettings(name: name)
        XCTAssertNotNil(read)
        XCTAssertTrue(read!.contains("swift test"))
    }

    // MARK: - List

    func testListIncludesCreatedPreset() throws {
        let name = "test-list-\(UUID().uuidString.prefix(8).lowercased())"
        defer { try? PresetStore.delete(name: name) }

        try PresetStore.create(name: name, description: "Listed")

        let sanitized = ModoConfig.sanitize(name)
        let all = try PresetStore.listAll()
        let found = all.first { $0.dirName == sanitized }

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.info.description, "Listed")
    }

    // MARK: - Export / Import

    func testExportAndImport() throws {
        let name = "test-export-\(UUID().uuidString.prefix(8))"
        defer { try? PresetStore.delete(name: name) }

        try PresetStore.create(name: name, description: "Exportable", tags: ["test"])

        // Write some claude.md content
        let claudeMDPath = ModoConfig.presetDirectory(named: name)
            .appendingPathComponent(ModoConfig.claudeMDFilename)
        try "Export test content.".write(to: claudeMDPath, atomically: true, encoding: .utf8)

        // Export
        let exportDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("modo-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: exportDir) }

        let zipURL = try PresetStore.exportPreset(name: name, to: exportDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipURL.path))
        XCTAssertTrue(zipURL.lastPathComponent.hasSuffix(".modopreset.zip"))

        // Delete the original
        try PresetStore.delete(name: name)
        XCTAssertFalse(PresetStore.exists(name: name))

        // Import it back
        let importedName = try PresetStore.importPreset(from: zipURL)

        XCTAssertTrue(PresetStore.exists(name: importedName))

        let info = try PresetStore.readInfo(name: importedName)
        XCTAssertEqual(info.description, "Exportable")
        XCTAssertEqual(info.tags, ["test"])

        let content = PresetStore.readClaudeMD(name: importedName)
        XCTAssertEqual(content, "Export test content.")
    }

    // MARK: - List commands/skills/rules

    func testListCommandsReturnsFilenames() throws {
        let name = "test-cmds-\(UUID().uuidString.prefix(8))"
        defer { try? PresetStore.delete(name: name) }

        try PresetStore.create(name: name)

        let cmdsDir = ModoConfig.presetDirectory(named: name)
            .appendingPathComponent(ModoConfig.commandsDirName)
        try FileManager.default.createDirectory(at: cmdsDir, withIntermediateDirectories: true)
        try "Review code.".write(to: cmdsDir.appendingPathComponent("review.md"), atomically: true, encoding: .utf8)
        try "Deploy app.".write(to: cmdsDir.appendingPathComponent("deploy.md"), atomically: true, encoding: .utf8)

        let commands = PresetStore.listCommands(name: name)
        XCTAssertEqual(commands, ["deploy.md", "review.md"])
    }

    func testListSkillsReturnsFolderNames() throws {
        let name = "test-skills-\(UUID().uuidString.prefix(8))"
        defer { try? PresetStore.delete(name: name) }

        try PresetStore.create(name: name)

        let skillDir = ModoConfig.presetDirectory(named: name)
            .appendingPathComponent(ModoConfig.skillsDirName)
            .appendingPathComponent("explain")
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        try "Explain code.".write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let skills = PresetStore.listSkills(name: name)
        XCTAssertEqual(skills, ["explain"])
    }

    func testListRulesReturnsFilenames() throws {
        let name = "test-rules-\(UUID().uuidString.prefix(8))"
        defer { try? PresetStore.delete(name: name) }

        try PresetStore.create(name: name)

        let rulesDir = ModoConfig.presetDirectory(named: name)
            .appendingPathComponent(ModoConfig.rulesDirName)
        try FileManager.default.createDirectory(at: rulesDir, withIntermediateDirectories: true)
        try "Use Swift 5.10.".write(to: rulesDir.appendingPathComponent("swift.md"), atomically: true, encoding: .utf8)

        let rules = PresetStore.listRules(name: name)
        XCTAssertEqual(rules, ["swift.md"])
    }

    func testListCommandsReturnsEmptyWhenNoDirectory() throws {
        let name = "test-nocmds-\(UUID().uuidString.prefix(8))"
        defer { try? PresetStore.delete(name: name) }

        try PresetStore.create(name: name)

        let commands = PresetStore.listCommands(name: name)
        XCTAssertEqual(commands, [])
    }

    func testCreateFromProjectCopiesSubdirectories() throws {
        let name = "test-fromproj-\(UUID().uuidString.prefix(8))"
        defer { try? PresetStore.delete(name: name) }

        // Create a fake project with .claude/ structure
        let fakeProject = FileManager.default.temporaryDirectory
            .appendingPathComponent("modo-test-proj-\(UUID().uuidString)")
        let claudeDir = fakeProject.appendingPathComponent(".claude")
        let cmdsDir = claudeDir.appendingPathComponent("commands")
        let skillsDir = claudeDir.appendingPathComponent("skills/explain")
        let rulesDir = claudeDir.appendingPathComponent("rules")

        try FileManager.default.createDirectory(at: cmdsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: skillsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rulesDir, withIntermediateDirectories: true)

        try "Instructions.".write(to: claudeDir.appendingPathComponent("claude.md"), atomically: true, encoding: .utf8)
        try "Review code.".write(to: cmdsDir.appendingPathComponent("review.md"), atomically: true, encoding: .utf8)
        try "Explain skill.".write(to: skillsDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        try "Swift rules.".write(to: rulesDir.appendingPathComponent("swift.md"), atomically: true, encoding: .utf8)

        defer { try? FileManager.default.removeItem(at: fakeProject) }

        try PresetStore.createFromProject(name: name, projectPath: fakeProject)

        let commands = PresetStore.listCommands(name: name)
        let skills = PresetStore.listSkills(name: name)
        let rules = PresetStore.listRules(name: name)

        XCTAssertEqual(commands, ["review.md"])
        XCTAssertEqual(skills, ["explain"])
        XCTAssertEqual(rules, ["swift.md"])
    }

    func testImportDuplicateThrows() throws {
        let name = "test-impdup-\(UUID().uuidString.prefix(8))"
        defer { try? PresetStore.delete(name: name) }

        try PresetStore.create(name: name)

        let exportDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("modo-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: exportDir) }

        let zipURL = try PresetStore.exportPreset(name: name, to: exportDir)

        // Try importing when original still exists
        XCTAssertThrowsError(try PresetStore.importPreset(from: zipURL)) { error in
            guard case ModoError.presetAlreadyExists = error else {
                XCTFail("Expected presetAlreadyExists, got \(error)")
                return
            }
        }
    }
}
