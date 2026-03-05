import ArgumentParser
import Foundation

struct ClaimCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "claim",
        abstract: "Assign a colored border and floating label to a simulator"
    )

    @Option(name: .long, help: "Simulator UDID. If omitted, picks first available booted simulator.")
    var udid: String?

    @Option(name: .long, help: "Border color: \(SimColor.allCases.map(\.rawValue).joined(separator: ", "))")
    var color: String?

    @Option(name: .long, help: "Floating label text (e.g. agent name)")
    var label: String = "Agent"

    @Flag(name: .long, inversion: .prefixedNo, help: "Boot a simulator if none is booted")
    var boot: Bool = true

    func run() throws {
        try Registry.pruneStale()

        let devices = try SimulatorService.listDevices()
        let registry = Registry.load()
        let claimedUDIDs = Set(registry.keys)

        // Resolve target device
        let device: SimDevice
        if let udid = udid {
            guard let found = devices.allDevices.first(where: { $0.udid == udid }) else {
                throw ValidationError("No simulator found with UDID \(udid)")
            }
            device = found
        } else {
            // Try to find an unclaimed booted simulator
            if let unclaimed = devices.bootedDevices.first(where: { !claimedUDIDs.contains($0.udid) }) {
                device = unclaimed
            } else if boot {
                // Boot one
                guard let available = devices.availableDevices.first(where: { !$0.isBooted }) else {
                    throw SimError.noSimulatorFound
                }
                print("Booting simulator: \(available.name) (\(available.udid))...")
                try SimulatorService.bootDevice(udid: available.udid)
                // Wait for window to appear
                Thread.sleep(forTimeInterval: 3)
                device = SimDevice(
                    udid: available.udid,
                    name: available.name,
                    state: "Booted",
                    isAvailable: true
                )
            } else {
                print("No booted simulators found. Use --boot to auto-boot one.")
                throw ExitCode.failure
            }
        }

        // Check if already claimed
        if let existing = registry[device.udid] {
            print("Simulator \(device.name) is already claimed with color \(existing.color) by \"\(existing.label)\".")
            print("Release it first: colored-sim release --udid \(device.udid)")
            throw ExitCode.failure
        }

        // Resolve color
        let usedColors = Set(registry.values.map(\.color))
        let resolvedColor: SimColor
        if let colorName = color {
            guard let c = SimColor(rawValue: colorName.lowercased()) else {
                throw ValidationError("Unknown color '\(colorName)'. Available: \(SimColor.allCases.map(\.rawValue).joined(separator: ", "))")
            }
            resolvedColor = c
        } else {
            resolvedColor = SimColor.nextAvailable(excluding: usedColors)
        }

        // Find overlay binary path
        let overlayPath = try findOverlayBinary()

        // Spawn overlay process
        let overlayProcess = Process()
        overlayProcess.executableURL = URL(fileURLWithPath: overlayPath)
        overlayProcess.arguments = [
            "--device-name", device.name,
            "--color", resolvedColor.hex,
            "--label", label,
        ]
        try overlayProcess.run()

        let entry = RegistryEntry(
            udid: device.udid,
            deviceName: device.name,
            color: resolvedColor.rawValue,
            label: label,
            overlayPID: overlayProcess.processIdentifier,
            createdAt: Date()
        )
        try Registry.add(entry)

        let c = resolvedColor
        print("\(c.ansi)●\(SimColor.reset) Claimed \(device.name) with \(c.rawValue) border — label: \"\(label)\"")
        print("  UDID: \(device.udid)")
        print("  Overlay PID: \(overlayProcess.processIdentifier)")
    }

    private func findOverlayBinary() throws -> String {
        // Check next to the current binary
        let currentExec = CommandLine.arguments[0]
        let dir = (currentExec as NSString).deletingLastPathComponent
        let candidate = (dir as NSString).appendingPathComponent("colored-sim-overlay")
        if FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }

        // Check common swift build paths
        let buildPaths = [
            ".build/debug/colored-sim-overlay",
            ".build/release/colored-sim-overlay",
        ]
        for path in buildPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        throw SimError.overlayBinaryNotFound
    }
}
