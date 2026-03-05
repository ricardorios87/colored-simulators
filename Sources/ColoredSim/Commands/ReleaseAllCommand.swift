import ArgumentParser
import ColoredSimKit
import Foundation

struct ReleaseAllCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "release-all",
        abstract: "Remove all colored overlays"
    )

    func run() throws {
        let registry = Registry.load()

        if registry.isEmpty {
            print("No claimed simulators.")
            return
        }

        for (_, entry) in registry {
            kill(entry.overlayPID, SIGTERM)
            print("Released \(entry.deviceName) [\(entry.color)]")
        }

        try Registry.save([:])
        print("All overlays removed.")
    }
}
