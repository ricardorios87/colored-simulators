import ArgumentParser
import Foundation

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all booted simulators and their claim status"
    )

    func run() throws {
        try Registry.pruneStale()

        let devices = try SimulatorService.listDevices()
        let registry = Registry.load()
        let booted = devices.bootedDevices

        if booted.isEmpty {
            print("No booted simulators.")
            return
        }

        print("Booted Simulators:")
        print(String(repeating: "-", count: 70))

        for device in booted {
            if let entry = registry[device.udid] {
                let color = SimColor(rawValue: entry.color)
                let ansi = color?.ansi ?? ""
                print("  \(ansi)●\(SimColor.reset) \(device.name)")
                print("    UDID:  \(device.udid)")
                print("    Color: \(entry.color)")
                print("    Label: \"\(entry.label)\"")
                print("    PID:   \(entry.overlayPID)")
            } else {
                print("  ○ \(device.name)")
                print("    UDID:  \(device.udid)")
                print("    Status: unclaimed")
            }
            print()
        }
    }
}
