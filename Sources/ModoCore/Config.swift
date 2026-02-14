import Foundation

/// Central paths and constants for Modo.
public enum ModoConfig {

    /// Current version string.
    public static let version = "1.0.0"

    /// Where all presets live: ~/.config/modo/presets/
    public static var presetsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/modo/presets")
    }

    /// The directory for a specific preset.
    public static func presetDirectory(named name: String) -> URL {
        presetsDirectory.appendingPathComponent(sanitize(name))
    }

    /// Convert a human name to a safe directory name.
    /// "Swift App" -> "swift-app", "My Config!" -> "my-config"
    public static func sanitize(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }

    public static let claudeMDFilename = "claude.md"
    public static let settingsFilename = "settings.json"
    public static let metadataFilename = "preset.json"
    public static let applyRecordFilename = ".modo.json"

    /// Ensure the presets directory exists (called on first use).
    public static func ensureSetup() throws {
        try FileManager.default.createDirectory(
            at: presetsDirectory,
            withIntermediateDirectories: true
        )
    }
}
