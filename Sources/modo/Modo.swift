import ArgumentParser

@main
struct Modo: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "modo",
        abstract: "Manage and apply reusable Claude Code presets.",
        discussion: """
            Build a library of Claude Code configurations and apply them to any project.
            Presets are stored in ~/.config/modo/presets/.

            Quick start:
              modo new my-preset          Create a preset
              modo edit my-preset         Edit its CLAUDE.md content
              modo apply my-preset        Apply it to the current project
              modo apply base ext rules   Merge multiple presets together
            """,
        version: "1.1.0",
        subcommands: [
            New.self,
            ListPresets.self,
            Show.self,
            Apply.self,
            Edit.self,
            Remove.self,
            Export.self,
            Import.self,
        ],
        defaultSubcommand: ListPresets.self
    )
}
