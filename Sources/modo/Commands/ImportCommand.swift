import ArgumentParser
import Foundation
import ModoCore

struct Import: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Import a preset from a .modopreset.zip file.",
        discussion: """
            Imports a preset that was exported by someone else (or by you on another machine).

            Examples:
              modo import swift-app.modopreset.zip
              modo import ~/Downloads/firefox-ext.modopreset.zip
            """
    )

    @Argument(help: "Path to the .modopreset.zip file.")
    var file: String

    func run() throws {
        let filePath = (file as NSString).expandingTildeInPath
        let fileURL = URL(fileURLWithPath: filePath)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ModoError.importFailed("File not found: \(file)")
        }

        let dirName = try PresetStore.importPreset(from: fileURL)
        let info = try PresetStore.readInfo(name: dirName)

        print("")
        Style.success("Imported preset \(Style.bold(info.name))")
        print("  Location: ~/.config/modo/presets/\(dirName)/")
        print("")
        print("  Next steps:")
        print("    modo show \(dirName)      Preview its contents")
        print("    modo apply \(dirName)     Apply it to a project")
        print("")
    }
}
