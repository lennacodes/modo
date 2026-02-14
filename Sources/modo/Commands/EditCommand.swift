import ArgumentParser
import Foundation
import ModoCore

struct Edit: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Open a preset's CLAUDE.md in your text editor."
    )

    @Argument(help: "Name of the preset to edit.")
    var name: String

    @Flag(help: "Open the settings.json instead of claude.md.")
    var settings = false

    @Flag(help: "Open the preset folder in Finder.")
    var folder = false

    func run() throws {
        let dirName = ModoConfig.sanitize(name)
        guard PresetStore.exists(name: dirName) else {
            throw ModoError.presetNotFound(name)
        }

        let presetDir = ModoConfig.presetDirectory(named: dirName)

        if folder {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [presetDir.path]
            try process.run()
            process.waitUntilExit()
            return
        }

        let filename = settings ? ModoConfig.settingsFilename : ModoConfig.claudeMDFilename
        let filePath = presetDir.appendingPathComponent(filename)

        if settings && !FileManager.default.fileExists(atPath: filePath.path) {
            try "{}".write(to: filePath, atomically: true, encoding: .utf8)
        }

        let editor = ProcessInfo.processInfo.environment["EDITOR"]

        let process = Process()
        if let editor = editor {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [editor, filePath.path]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-t", filePath.path]
        }

        try process.run()
        process.waitUntilExit()
    }
}
