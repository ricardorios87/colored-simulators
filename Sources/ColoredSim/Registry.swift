import Foundation

struct RegistryEntry: Codable {
    let udid: String
    let deviceName: String
    let color: String
    let label: String
    let overlayPID: Int32
    let createdAt: Date
}

struct Registry {
    private static var registryDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".colored-sim")
    }

    private static var registryFile: URL {
        registryDir.appendingPathComponent("registry.json")
    }

    static func load() -> [String: RegistryEntry] {
        guard let data = try? Data(contentsOf: registryFile),
              let entries = try? JSONDecoder().decode([String: RegistryEntry].self, from: data) else {
            return [:]
        }
        return entries
    }

    static func save(_ entries: [String: RegistryEntry]) throws {
        try FileManager.default.createDirectory(at: registryDir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)
        try data.write(to: registryFile)
    }

    static func add(_ entry: RegistryEntry) throws {
        var entries = load()
        entries[entry.udid] = entry
        try save(entries)
    }

    static func remove(udid: String) throws -> RegistryEntry? {
        var entries = load()
        let removed = entries.removeValue(forKey: udid)
        try save(entries)
        return removed
    }

    static func get(udid: String) -> RegistryEntry? {
        load()[udid]
    }

    /// Clean up entries whose overlay process is no longer running
    static func pruneStale() throws {
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
