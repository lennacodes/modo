import Foundation

/// Metadata stored in each preset's preset.json file.
public struct PresetInfo: Codable, Equatable {
    public let name: String
    public var description: String
    public var tags: [String]

    public init(name: String, description: String = "", tags: [String] = []) {
        self.name = name
        self.description = description
        self.tags = tags
    }
}

/// Handles reading and writing presets on disk.
public enum PresetStore {

    // MARK: - List

    /// Returns all presets sorted by name.
    public static func listAll() throws -> [(dirName: String, info: PresetInfo)] {
        try ModoConfig.ensureSetup()

        let fm = FileManager.default
        let base = ModoConfig.presetsDirectory

        guard let entries = try? fm.contentsOfDirectory(
            at: base,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var results: [(String, PresetInfo)] = []
        for entry in entries {
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            guard isDir else { continue }

            let metaURL = entry.appendingPathComponent(ModoConfig.metadataFilename)
            guard let data = try? Data(contentsOf: metaURL),
                  let info = try? JSONDecoder().decode(PresetInfo.self, from: data)
            else { continue }

            results.append((entry.lastPathComponent, info))
        }

        return results.sorted { $0.1.name.lowercased() < $1.1.name.lowercased() }
    }

    // MARK: - Create

    /// Creates a new preset directory with metadata and an empty claude.md.
    public static func create(name: String, description: String = "", tags: [String] = []) throws {
        try ModoConfig.ensureSetup()

        let dirName = ModoConfig.sanitize(name)
        let dir = ModoConfig.presetDirectory(named: name)

        if FileManager.default.fileExists(atPath: dir.path) {
            throw ModoError.presetAlreadyExists(dirName)
        }

        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let info = PresetInfo(name: name, description: description, tags: tags)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(info)
        try data.write(to: dir.appendingPathComponent(ModoConfig.metadataFilename))

        try "".write(
            to: dir.appendingPathComponent(ModoConfig.claudeMDFilename),
            atomically: true,
            encoding: .utf8
        )
    }

    /// Creates a preset by importing from an existing project's .claude/ directory.
    public static func createFromProject(name: String, projectPath: URL) throws {
        try ModoConfig.ensureSetup()

        let dir = ModoConfig.presetDirectory(named: name)
        if FileManager.default.fileExists(atPath: dir.path) {
            throw ModoError.presetAlreadyExists(ModoConfig.sanitize(name))
        }

        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var claudeMD = ""
        let dotClaudeMD = projectPath.appendingPathComponent(".claude/claude.md")
        let rootClaudeMD = projectPath.appendingPathComponent("CLAUDE.md")
        if let content = try? String(contentsOf: dotClaudeMD, encoding: .utf8) {
            claudeMD = content
        } else if let content = try? String(contentsOf: rootClaudeMD, encoding: .utf8) {
            claudeMD = content
        }

        let settingsPath = projectPath.appendingPathComponent(".claude/settings.json")
        if FileManager.default.fileExists(atPath: settingsPath.path) {
            try FileManager.default.copyItem(
                at: settingsPath,
                to: dir.appendingPathComponent(ModoConfig.settingsFilename)
            )
        }

        try claudeMD.write(
            to: dir.appendingPathComponent(ModoConfig.claudeMDFilename),
            atomically: true,
            encoding: .utf8
        )

        let info = PresetInfo(name: name, description: "", tags: [])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(info).write(
            to: dir.appendingPathComponent(ModoConfig.metadataFilename)
        )
    }

    // MARK: - Read

    public static func exists(name: String) -> Bool {
        FileManager.default.fileExists(atPath: ModoConfig.presetDirectory(named: name).path)
    }

    public static func readInfo(name: String) throws -> PresetInfo {
        let metaURL = ModoConfig.presetDirectory(named: name)
            .appendingPathComponent(ModoConfig.metadataFilename)
        let data = try Data(contentsOf: metaURL)
        return try JSONDecoder().decode(PresetInfo.self, from: data)
    }

    public static func readClaudeMD(name: String) -> String? {
        let path = ModoConfig.presetDirectory(named: name)
            .appendingPathComponent(ModoConfig.claudeMDFilename)
        return try? String(contentsOf: path, encoding: .utf8)
    }

    public static func readSettings(name: String) -> String? {
        let path = ModoConfig.presetDirectory(named: name)
            .appendingPathComponent(ModoConfig.settingsFilename)
        return try? String(contentsOf: path, encoding: .utf8)
    }

    // MARK: - Delete

    public static func delete(name: String) throws {
        let dir = ModoConfig.presetDirectory(named: name)
        guard FileManager.default.fileExists(atPath: dir.path) else {
            throw ModoError.presetNotFound(name)
        }
        try FileManager.default.removeItem(at: dir)
    }

    // MARK: - Export / Import

    /// Exports a preset as a .modopreset.zip file.
    public static func exportPreset(name: String, to destinationDir: URL) throws -> URL {
        let dirName = ModoConfig.sanitize(name)
        guard exists(name: dirName) else {
            throw ModoError.presetNotFound(name)
        }

        let sourceDir = ModoConfig.presetDirectory(named: dirName)
        let zipName = "\(dirName).modopreset.zip"
        let zipPath = destinationDir.appendingPathComponent(zipName)

        // Remove existing zip if present
        if FileManager.default.fileExists(atPath: zipPath.path) {
            try FileManager.default.removeItem(at: zipPath)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [
            "-c", "-k", "--sequesterRsrc", "--keepParent",
            sourceDir.path, zipPath.path,
        ]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ModoError.exportFailed("Failed to create zip file.")
        }

        return zipPath
    }

    /// Imports a preset from a .modopreset.zip file.
    /// Returns the directory name of the imported preset.
    public static func importPreset(from zipURL: URL) throws -> String {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Extract
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zipURL.path, tempDir.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ModoError.importFailed("Failed to unzip file.")
        }

        // Find the extracted preset directory
        let contents = try FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        guard let extractedDir = contents.first(where: {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }) else {
            throw ModoError.importFailed("No preset found in zip file.")
        }

        // Read metadata to get the name
        let metaURL = extractedDir.appendingPathComponent(ModoConfig.metadataFilename)
        guard let data = try? Data(contentsOf: metaURL),
              let info = try? JSONDecoder().decode(PresetInfo.self, from: data) else {
            throw ModoError.importFailed("Invalid preset: missing or corrupt preset.json.")
        }

        let dirName = ModoConfig.sanitize(info.name)
        let targetDir = ModoConfig.presetsDirectory.appendingPathComponent(dirName)

        if FileManager.default.fileExists(atPath: targetDir.path) {
            throw ModoError.presetAlreadyExists(dirName)
        }

        try FileManager.default.copyItem(at: extractedDir, to: targetDir)

        return dirName
    }
}
