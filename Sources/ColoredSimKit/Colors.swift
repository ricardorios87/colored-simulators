import Foundation

public enum SimColor: String, CaseIterable {
    case electric    // VS Code blue
    case emerald     // GitHub green
    case flame       // error red / hot reload
    case amber       // warning yellow
    case violet      // merge/purple
    case cyan        // terminal cyan
    case tangerine   // Xcode orange
    case magenta     // diff pink
    case lime        // success/test pass

    public var hex: String {
        switch self {
        case .electric: return "4FC1FF"
        case .emerald: return "3FB950"
        case .flame: return "F85149"
        case .amber: return "D29922"
        case .violet: return "A371F7"
        case .cyan: return "39D2C0"
        case .tangerine: return "F0883E"
        case .magenta: return "DB61A2"
        case .lime: return "7EE787"
        }
    }

    public var ansi: String {
        switch self {
        case .electric: return "\u{1B}[94m"
        case .emerald: return "\u{1B}[32m"
        case .flame: return "\u{1B}[91m"
        case .amber: return "\u{1B}[33m"
        case .violet: return "\u{1B}[35m"
        case .cyan: return "\u{1B}[36m"
        case .tangerine: return "\u{1B}[33m"
        case .magenta: return "\u{1B}[95m"
        case .lime: return "\u{1B}[92m"
        }
    }

    public static let reset = "\u{1B}[0m"

    public static func nextAvailable(excluding used: Set<String>) -> SimColor {
        var available = allCases.filter { !used.contains($0.rawValue) }
        if available.isEmpty { available = Array(allCases) }
        return available.randomElement()!
    }
}
