import ArgumentParser
import Foundation
import ModoCore

struct Remove: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Delete a preset."
    )

    @Argument(help: "Name of the preset to remove.")
    var name: String

    @Flag(help: "Skip the confirmation prompt.")
    var force = false

    func run() throws {
        let dirName = ModoConfig.sanitize(name)
        guard PresetStore.exists(name: dirName) else {
            throw ModoError.presetNotFound(name)
        }

        let info = try PresetStore.readInfo(name: dirName)

        if !force {
            print("  Remove preset \"\(info.name)\"? This cannot be undone. [y/N] ", terminator: "")
            guard let answer = readLine()?.lowercased(), answer == "y" || answer == "yes" else {
                print("  Cancelled.")
                return
            }
        }

        try PresetStore.delete(name: dirName)
        print("")
        Style.success("Removed preset \(Style.bold(info.name))")
        print("")
    }
}
