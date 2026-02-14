import ArgumentParser
import Foundation
import ModoCore

struct Show: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Preview a preset's contents."
    )

    @Argument(help: "Name of the preset to show.")
    var name: String

    func run() throws {
        let dirName = ModoConfig.sanitize(name)
        guard PresetStore.exists(name: dirName) else {
            throw ModoError.presetNotFound(name)
        }

        let info = try PresetStore.readInfo(name: dirName)

        print("")
        print("  \(Style.bold(info.name))")

        if !info.description.isEmpty {
            print("  \(Style.dim(info.description))")
        }
        if !info.tags.isEmpty {
            print("  Tags: \(info.tags.joined(separator: ", "))")
        }

        if let content = PresetStore.readClaudeMD(name: dirName),
           !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("")
            print("  \(Style.bold("claude.md"))")
            let lines = content.components(separatedBy: .newlines)
            let preview = lines.prefix(15).map { "    \($0)" }.joined(separator: "\n")
            print(preview)
            if lines.count > 15 {
                print("    \(Style.dim("... (\(lines.count - 15) more lines)"))")
            }
        }

        if let content = PresetStore.readSettings(name: dirName),
           !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("")
            print("  \(Style.bold("settings.json"))")
            let lines = content.components(separatedBy: .newlines)
            let preview = lines.prefix(15).map { "    \($0)" }.joined(separator: "\n")
            print(preview)
            if lines.count > 15 {
                print("    \(Style.dim("... (\(lines.count - 15) more lines)"))")
            }
        }

        print("")
    }
}
