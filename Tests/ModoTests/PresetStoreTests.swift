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
