import ArgumentParser
import Foundation
import ModoCore

struct New: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Create a new preset.",
        discussion: """
            Creates an empty preset you can fill in, or imports from an existing project.

            Examples:
              modo new my-preset
              modo new "Swift App" --description "Base config for Swift projects" --tags swift,ios
              modo new from-project --from ~/code/my-project
            """
    )

    @Argument(help: "Name for the new preset.")
    var name: String

    @Option(help: "Short description of what this preset is for.")
    var description: String = ""

    @Option(help: "Comma-separated tags (e.g. swift,ios,macos).")
    var tags: String = ""

    @Option(help: "Import from an existing project's .claude/ directory.")
    var from: String?

    func run() throws {
        let parsedTags = tags.isEmpty ? [] : tags.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }

        if let fromPath = from {
            let projectURL = URL(fileURLWithPath: (fromPath as NSString).expandingTildeInPath)
            try PresetStore.createFromProject(name: name, projectPath: projectURL)
            print("")
            Style.success("Imported preset \(Style.bold(name)) from \(fromPath)")
        } else {
            try PresetStore.create(name: name, description: description, tags: parsedTags)
            print("")
            Style.success("Created preset \(Style.bold(name))")
        }

        let dirName = ModoConfig.sanitize(name)
        print("  Location: ~/.config/modo/presets/\(dirName)/")
        print("")
        print("  Next steps:")
        print("    modo edit \(dirName)      Edit the CLAUDE.md content")
        print("    modo apply \(dirName)     Apply it to a project")
        print("")
    }
}
