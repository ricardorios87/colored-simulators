import Foundation

enum SimColor: String, CaseIterable {
    case red
    case blue
    case green
    case orange
    case purple
    case yellow
    case pink
    case cyan
    case teal

    /// Returns hex color string for the overlay process
    var hex: String {
        switch self {
        case .red: return "FF3B30"
        case .blue: return "007AFF"
        case .green: return "34C759"
        case .orange: return "FF9500"
        case .purple: return "AF52DE"
        case .yellow: return "FFCC00"
        case .pink: return "FF2D55"
        case .cyan: return "32ADE6"
        case .teal: return "30B0C7"
        }
    }

    /// ANSI terminal color for CLI output
    var ansi: String {
        switch self {
        case .red: return "\u{1B}[31m"
        case .blue: return "\u{1B}[34m"
        case .green: return "\u{1B}[32m"
        case .orange: return "\u{1B}[33m"
        case .purple: return "\u{1B}[35m"
        case .yellow: return "\u{1B}[33m"
        case .pink: return "\u{1B}[35m"
        case .cyan: return "\u{1B}[36m"
        case .teal: return "\u{1B}[36m"
        }
    }

    static let reset = "\u{1B}[0m"

    /// Pick the next available color not already in use
    static func nextAvailable(excluding used: Set<String>) -> SimColor {
        for color in allCases where !used.contains(color.rawValue) {
            return color
        }
        return .red
    }
}
