import Foundation

/// Terminal color helpers for pretty output.
public enum Style {
    public static func bold(_ text: String) -> String { "\u{1B}[1m\(text)\u{1B}[0m" }
    public static func green(_ text: String) -> String { "\u{1B}[32m\(text)\u{1B}[0m" }
    public static func yellow(_ text: String) -> String { "\u{1B}[33m\(text)\u{1B}[0m" }
    public static func red(_ text: String) -> String { "\u{1B}[31m\(text)\u{1B}[0m" }
    public static func dim(_ text: String) -> String { "\u{1B}[2m\(text)\u{1B}[0m" }
    public static func cyan(_ text: String) -> String { "\u{1B}[36m\(text)\u{1B}[0m" }

    public static func success(_ text: String) { print("  \(green("✓")) \(text)") }
    public static func warning(_ text: String) { print("  \(yellow("!")) \(text)") }
    public static func error(_ text: String) { print("  \(red("✗")) \(text)") }
}
