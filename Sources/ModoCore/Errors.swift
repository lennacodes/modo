import Foundation

public enum ModoError: LocalizedError {
    case presetNotFound(String)
    case presetAlreadyExists(String)
    case noPresetsSpecified
    case exportFailed(String)
    case importFailed(String)
    case projectPathNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .presetNotFound(let name):
            return "Preset '\(name)' not found. Run 'modo list' to see available presets."
        case .presetAlreadyExists(let name):
            return "Preset '\(name)' already exists. Pick a different name or remove it first."
        case .noPresetsSpecified:
            return "No presets specified. Usage: modo apply <preset1> [preset2 ...]"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .importFailed(let reason):
            return "Import failed: \(reason)"
        case .projectPathNotFound(let path):
            return "Project path '\(path)' not found. Check the path and try again."
        }
    }
}
