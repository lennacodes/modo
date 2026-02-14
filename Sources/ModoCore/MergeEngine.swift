import Foundation

/// Records what was applied to a project, written to .claude/.modo.json.
public struct ApplyRecord: Codable {
    public let presets: [String]
    public let appliedAt: String
    public let modoVersion: String

    public init(presets: [String], appliedAt: String, modoVersion: String) {
        self.presets = presets
        self.appliedAt = appliedAt
        self.modoVersion = modoVersion
    }
}

/// The result of an apply operation.
public struct ApplyResult {
    public var created: [String] = []
    public var modified: [String] = []
    public var backedUp: [String] = []
    public var sectionCount: Int = 0
    public var settingsPresetCount: Int = 0

    public init() {}
}

/// Handles compiling and merging preset content into a project's .claude/ directory.
public enum MergeEngine {

    // MARK: - Apply

    /// Applies one or more presets to a project directory.
    /// When dryRun is true, computes what would happen but does not write any files.
    public static func apply(
        presetNames: [String],
        to projectURL: URL,
        dryRun: Bool = false
    ) throws -> ApplyResult {
        var result = ApplyResult()
        let fm = FileManager.default

        // 1. .claude/ directory
        let claudeDir = projectURL.appendingPathComponent(".claude")
        if !fm.fileExists(atPath: claudeDir.path) {
            if !dryRun {
                try fm.createDirectory(at: claudeDir, withIntermediateDirectories: true)
            }
            result.created.append(".claude/")
        }

        // 2. Compile claude.md
        try compileClaudeMD(
            presetNames: presetNames, projectURL: projectURL,
            result: &result, dryRun: dryRun
        )

        // 3. Merge settings.json
        try mergeSettings(
            presetNames: presetNames, projectURL: projectURL,
            result: &result, dryRun: dryRun
        )

        // 4. Update .gitignore
        try updateGitignore(projectURL: projectURL, result: &result, dryRun: dryRun)

        // 5. Write apply record
        if !dryRun {
            try writeApplyRecord(presetNames: presetNames, projectURL: projectURL)
        }

        return result
    }

    // MARK: - claude.md Compilation

    /// Compiles preset claude.md files into one file with section headers.
    /// This is public so it can be tested directly.
    public static func compileClaudeMD(from presets: [(name: String, content: String)]) -> String {
        var sections: [String] = []

        for preset in presets {
            let trimmed = preset.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            sections.append("## \(preset.name)\n\n\(trimmed)")
        }

        guard !sections.isEmpty else { return "" }
        return sections.joined(separator: "\n\n---\n\n") + "\n"
    }

    private static func compileClaudeMD(
        presetNames: [String], projectURL: URL,
        result: inout ApplyResult, dryRun: Bool
    ) throws {
        var presets: [(name: String, content: String)] = []

        for name in presetNames {
            guard let content = PresetStore.readClaudeMD(name: name),
                  !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { continue }

            let info = try? PresetStore.readInfo(name: name)
            let displayName = info?.name ?? name
            presets.append((name: displayName, content: content))
        }

        guard !presets.isEmpty else { return }

        let compiled = compileClaudeMD(from: presets)
        result.sectionCount = presets.count

        let targetPath = projectURL.appendingPathComponent(".claude/claude.md")
        let existed = FileManager.default.fileExists(atPath: targetPath.path)

        if existed {
            try backupIfExists(targetPath, relativePath: ".claude/claude.md", result: &result, dryRun: dryRun)
        }

        if !dryRun {
            try compiled.write(to: targetPath, atomically: true, encoding: .utf8)
        }

        if existed {
            result.modified.append(".claude/claude.md")
        } else {
            result.created.append(".claude/claude.md")
        }
    }

    // MARK: - settings.json Deep Merge

    /// Recursively merges two dictionaries.
    /// String arrays are unioned. Dict arrays are concatenated.
    /// Nested dicts are merged recursively. Everything else: overlay wins.
    /// Public for testing.
    public static func deepMerge(base: [String: Any], overlay: [String: Any]) -> [String: Any] {
        var result = base

        for (key, overlayValue) in overlay {
            if let baseDict = base[key] as? [String: Any],
               let overlayDict = overlayValue as? [String: Any] {
                result[key] = deepMerge(base: baseDict, overlay: overlayDict)

            } else if let baseArray = base[key] as? [String],
                      let overlayArray = overlayValue as? [String] {
                var combined = baseArray
                for item in overlayArray where !combined.contains(item) {
                    combined.append(item)
                }
                result[key] = combined

            } else if let baseArray = base[key] as? [[String: Any]],
                      let overlayArray = overlayValue as? [[String: Any]] {
                result[key] = baseArray + overlayArray

            } else {
                result[key] = overlayValue
            }
        }

        return result
    }

    private static func mergeSettings(
        presetNames: [String], projectURL: URL,
        result: inout ApplyResult, dryRun: Bool
    ) throws {
        let targetPath = projectURL.appendingPathComponent(".claude/settings.json")
        let existed = FileManager.default.fileExists(atPath: targetPath.path)

        var merged: [String: Any] = [:]
        if existed,
           let data = try? Data(contentsOf: targetPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            merged = existing
        }

        var mergeCount = 0
        for name in presetNames {
            guard let settingsString = PresetStore.readSettings(name: name),
                  !settingsString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let data = settingsString.data(using: .utf8),
                  let presetSettings = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            merged = deepMerge(base: merged, overlay: presetSettings)
            mergeCount += 1
        }

        result.settingsPresetCount = mergeCount
        guard !merged.isEmpty else { return }

        if existed {
            try backupIfExists(targetPath, relativePath: ".claude/settings.json", result: &result, dryRun: dryRun)
        }

        if !dryRun {
            let data = try JSONSerialization.data(
                withJSONObject: merged,
                options: [.prettyPrinted, .sortedKeys]
            )
            try data.write(to: targetPath, options: .atomic)
        }

        if existed {
            result.modified.append(".claude/settings.json")
        } else {
            result.created.append(".claude/settings.json")
        }
    }

    // MARK: - Gitignore

    private static func updateGitignore(
        projectURL: URL, result: inout ApplyResult, dryRun: Bool
    ) throws {
        let gitignorePath = projectURL.appendingPathComponent(".gitignore")
        let entry = ".claude/"

        if FileManager.default.fileExists(atPath: gitignorePath.path) {
            var content = try String(contentsOf: gitignorePath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            if !lines.contains(entry) {
                if !dryRun {
                    content += "\n\n# Claude Code configuration\n\(entry)\n"
                    try content.write(to: gitignorePath, atomically: true, encoding: .utf8)
                }
                result.modified.append(".gitignore")
            }
        } else {
            if !dryRun {
                let content = "# Claude Code configuration\n\(entry)\n"
                try content.write(to: gitignorePath, atomically: true, encoding: .utf8)
            }
            result.created.append(".gitignore")
        }
    }

    // MARK: - Backup

    /// Backs up an existing file by copying it to <name>.bak.
    /// Returns the relative path of the backup if one was created.
    private static func backupIfExists(
        _ targetPath: URL, relativePath: String, result: inout ApplyResult, dryRun: Bool
    ) throws {
        guard FileManager.default.fileExists(atPath: targetPath.path) else { return }

        let bakPath = targetPath.appendingPathExtension("bak")

        if !dryRun {
            // Remove old backup if present
            if FileManager.default.fileExists(atPath: bakPath.path) {
                try FileManager.default.removeItem(at: bakPath)
            }
            try FileManager.default.copyItem(at: targetPath, to: bakPath)
        }

        result.backedUp.append(relativePath + ".bak")
    }

    // MARK: - Apply Record

    private static func writeApplyRecord(presetNames: [String], projectURL: URL) throws {
        let formatter = ISO8601DateFormatter()
        let record = ApplyRecord(
            presets: presetNames,
            appliedAt: formatter.string(from: Date()),
            modoVersion: ModoConfig.version
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(record)

        let recordPath = projectURL
            .appendingPathComponent(".claude")
            .appendingPathComponent(ModoConfig.applyRecordFilename)
        try data.write(to: recordPath, options: .atomic)
    }
}
