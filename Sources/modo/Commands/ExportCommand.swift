import ArgumentParser
import Foundation
import ModoCore

struct Export: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Export a preset as a shareable .modopreset.zip file.",
        discussion: """
            Creates a zip archive of the preset that can be shared with others.
            They can import it with 'modo import <file>'.

            Examples:
              modo export swift-app
              modo export swift-app --to ~/Desktop
            """
    )

    @Argument(help: "Name of the preset to export.")
    var name: String

    @Option(help: "Directory to save the zip file (default: current directory).")
    var to: String?

    func run() throws {
        let dirName = ModoConfig.sanitize(name)

        let destDir: URL
        if let toPath = to {
            destDir = URL(fileURLWithPath: (toPath as NSString).expandingTildeInPath)
        } else {
            destDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        }

        let zipURL = try PresetStore.exportPreset(name: dirName, to: destDir)

        print("")
        Style.success("Exported \(Style.bold(name)) to \(zipURL.lastPathComponent)")
        print("  Path: \(zipURL.path)")
        print("")
        print("  Share this file. Others can import it with:")
        print("    modo import \(zipURL.lastPathComponent)")
        print("")
    }
}
