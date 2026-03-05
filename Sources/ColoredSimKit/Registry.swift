import Foundation

public struct RegistryEntry: Codable {
    public let udid: String
    public let deviceName: String
    public let color: String
    public let label: String
    public let overlayPID: Int32
    public let createdAt: Date

    public init(udid: String, deviceName: String, color: String, label: String, overlayPID: Int32, createdAt: Date) {
        self.udid = udid
        self.deviceName = deviceName
        self.color = color
        self.label = label
        self.overlayPID = overlayPID
        self.createdAt = createdAt
    }
}

public struct Registry {
    private static var registryDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".colored-sim")
    }

    private static var registryFile: URL {
        registryDir.appendingPathComponent("registry.json")
    }

    public static func load() -> [String: RegistryEntry] {
        guard let data = try? Data(contentsOf: registryFile),
              let entries = try? JSONDecoder().decode([String: RegistryEntry].self, from: data) else {
            return [:]
        }
        return entries
    }

    public static func save(_ entries: [String: RegistryEntry]) throws {
        try FileManager.default.createDirectory(at: registryDir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)
        try data.write(to: registryFile)
    }

    public static func add(_ entry: RegistryEntry) throws {
        var entries = load()
        entries[entry.udid] = entry
        try save(entries)
    }

    public static func remove(udid: String) throws -> RegistryEntry? {
        var entries = load()
        let removed = entries.removeValue(forKey: udid)
        try save(entries)
        return removed
    }

    public static func get(udid: String) -> RegistryEntry? {
        load()[udid]
    }

    public static func pruneStale() throws {
        var entries = load()
        var changed = false
        for (udid, entry) in entries {
            if kill(entry.overlayPID, 0) != 0 {
                entries.removeValue(forKey: udid)
                changed = true
            }
        }
        if changed {
            try save(entries)
        }
    }
}
