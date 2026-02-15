import ArgumentParser
import Foundation
import ModoCore

struct Apply: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Apply one or more presets to a project.",
        discussion: """
            Merges the selected presets into the project's .claude/ directory.
            Multiple presets are combined intelligently:
            - claude.md files are compiled with section headers
            - settings.json files are deep-merged (permissions combined, not overwritten)
            - .gitignore is updated to include .claude/

            Examples:
              modo apply swift-app
              modo apply base-config firefox-ext my-rules
              modo apply swift-app --to ~/code/my-project
              modo apply swift-app --dry-run
            """
    )

    @Argument(help: "Names of presets to apply (space-separated).")
    var presets: [String]

    @Option(help: "Project directory to apply to (default: current directory).")
    var to: String?

    @Flag(name: .long, help: "Show what would happen without writing any files.")
    var dryRun = false

    func run() throws {
        guard !presets.isEmpty else {
            throw ModoError.noPresetsSpecified
        }

        let resolvedNames = presets.map { ModoConfig.sanitize($0) }

        for name in resolvedNames {
            guard PresetStore.exists(name: name) else {
                throw ModoError.presetNotFound(name)
            }
        }

        let projectPath: URL
        if let toPath = to {
            projectPath = URL(fileURLWithPath: (toPath as NSString).expandingTildeInPath)
        } else {
            projectPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        }

        let displayNames = resolvedNames.compactMap { try? PresetStore.readInfo(name: $0).name }

        print("")

        if dryRun {
            print("  \(Style.yellow("Dry run")) — no files will be changed.")
            print("")
        }

        print("  Applying \(resolvedNames.count) preset(s) to \(Style.dim(projectPath.path))...")
        print("")

        let result = try MergeEngine.apply(
            presetNames: resolvedNames, to: projectPath, dryRun: dryRun
        )

        let verb = dryRun ? "Would create" : "Created"
        let modVerb = dryRun ? "Would modify" : "Modified"

        let bakVerb = dryRun ? "Would back up" : "Backed up"
        for file in result.backedUp {
            print("  \(Style.dim("\(bakVerb) \(file)"))")
        }
        for file in result.created {
            if file.hasSuffix("claude.md") && result.sectionCount > 0 {
                Style.success("\(verb) \(file) (\(result.sectionCount) section(s))")
            } else if file.hasSuffix("settings.json") && result.settingsPresetCount > 0 {
                Style.success("\(verb) \(file) (merged from \(result.settingsPresetCount) preset(s))")
            } else {
                Style.success("\(verb) \(file)")
            }
        }
        for file in result.modified {
            if file.hasSuffix("claude.md") && result.sectionCount > 0 {
                Style.success("\(modVerb) \(file) (\(result.sectionCount) section(s))")
            } else if file.hasSuffix("settings.json") && result.settingsPresetCount > 0 {
                Style.success("\(modVerb) \(file) (merged from \(result.settingsPresetCount) preset(s))")
            } else {
                Style.success("\(modVerb) \(file)")
            }
        }

        // Show overwrite warnings (when two presets had the same file)
        for file in result.overwrittenFiles {
            Style.warning("Overwritten: \(file)")
        }

        // Show copied directory files (deduplicated — only show final copy)
        let copyVerb = dryRun ? "Would copy" : "Copied"
        var seenCopied = Set<String>()
        for file in result.copiedFiles.reversed() {
            if seenCopied.insert(file).inserted {
                Style.success("\(copyVerb) \(file)")
            }
        }

        print("")
        if dryRun {
            print("  \(Style.dim("No files were changed. Remove --dry-run to apply for real."))")
        } else {
            print("  \(Style.green("Done!")) Applied: \(displayNames.joined(separator: ", "))")
        }
        print("")
    }
}
