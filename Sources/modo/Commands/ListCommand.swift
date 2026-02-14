import ArgumentParser
import Foundation
import ModoCore

struct ListPresets: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all presets."
    )

    func run() throws {
        let presets = try PresetStore.listAll()

        if presets.isEmpty {
            print("")
            print("  No presets yet. Create one with:")
            print("    modo new my-preset")
            print("")
            return
        }

        print("")
        print("  \(Style.bold("Presets")) (\(presets.count))")
        print("")

        for (dirName, info) in presets {
            var line = "  \(Style.cyan(dirName.padding(toLength: 20, withPad: " ", startingAt: 0)))"
            if !info.description.isEmpty {
                line += Style.dim(info.description)
            }
            if !info.tags.isEmpty {
                let tagStr = info.tags.map { "[\($0)]" }.joined(separator: " ")
                line += "  \(Style.dim(tagStr))"
            }
            print(line)
        }

        print("")
    }
}
