import ArgumentParser
import Foundation

struct ReleaseCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "release",
        abstract: "Remove the colored overlay from a simulator"
    )

    @Option(name: .long, help: "Simulator UDID to release")
    var udid: String?

    func run() throws {
        try Registry.pruneStale()

        let registry = Registry.load()

        let targetUDID: String
        if let udid = udid {
            targetUDID = udid
        } else if registry.count == 1, let only = registry.keys.first {
            targetUDID = only
        } else if registry.isEmpty {
            print("No claimed simulators.")
            return
        } else {
            print("Multiple claimed simulators. Specify --udid:")
            for (_, entry) in registry {
                print("  \(entry.udid)  \(entry.deviceName)  [\(entry.color)] \"\(entry.label)\"")
            }
            throw ExitCode.failure
        }

        guard let entry = try Registry.remove(udid: targetUDID) else {
            print("No claim found for UDID \(targetUDID)")
            throw ExitCode.failure
        }

        // Kill overlay process
        kill(entry.overlayPID, SIGTERM)
        print("Released \(entry.deviceName) [\(entry.color)] — overlay PID \(entry.overlayPID) terminated.")
    }
}
