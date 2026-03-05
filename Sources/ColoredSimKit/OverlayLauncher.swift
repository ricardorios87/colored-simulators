import Foundation

public enum OverlayLauncher {
    public static func launch(deviceName: String, color: SimColor, label: String) throws -> Int32 {
        let overlayPath = try findOverlayBinary()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: overlayPath)
        process.arguments = [
            "--device-name", deviceName,
            "--color", color.hex,
            "--label", label,
        ]
        try process.run()
        return process.processIdentifier
    }

    /// Claim a simulator: resolve device, pick color, spawn overlay, register.
    /// Returns a summary of what was claimed.
    public struct ClaimResult {
        public let udid: String
        public let deviceName: String
        public let color: SimColor
        public let label: String
        public let overlayPID: Int32
    }

    public static func claim(udid: String?, color: String?, label: String, boot: Bool) throws -> ClaimResult {
        try Registry.pruneStale()

        let devices = try SimulatorService.listDevices()
        let registry = Registry.load()
        let claimedUDIDs = Set(registry.keys)

        let device: SimDevice
        if let udid = udid {
            guard let found = devices.allDevices.first(where: { $0.udid == udid }) else {
                throw ClaimError.deviceNotFound(udid)
            }
            device = found
        } else {
            if let unclaimed = devices.bootedDevices.first(where: { !claimedUDIDs.contains($0.udid) }) {
                device = unclaimed
            } else if boot {
                guard let available = devices.availableDevices.first(where: { !$0.isBooted }) else {
                    throw SimError.noSimulatorFound
                }
                try SimulatorService.bootDevice(udid: available.udid)
                Thread.sleep(forTimeInterval: 3)
                device = SimDevice(udid: available.udid, name: available.name, state: "Booted", isAvailable: true)
            } else {
                throw ClaimError.noBootedSimulator
            }
        }

        if let existing = registry[device.udid] {
            throw ClaimError.alreadyClaimed(device.name, existing.color, existing.label)
        }

        let usedColors = Set(registry.values.map(\.color))
        let resolvedColor: SimColor
        if let colorName = color {
            guard let c = SimColor(rawValue: colorName.lowercased()) else {
                throw ClaimError.unknownColor(colorName)
            }
            resolvedColor = c
        } else {
            resolvedColor = SimColor.nextAvailable(excluding: usedColors)
        }

        let pid = try launch(deviceName: device.name, color: resolvedColor, label: label)

        let entry = RegistryEntry(
            udid: device.udid,
            deviceName: device.name,
            color: resolvedColor.rawValue,
            label: label,
            overlayPID: pid,
            createdAt: Date()
        )
        try Registry.add(entry)

        return ClaimResult(
            udid: device.udid,
            deviceName: device.name,
            color: resolvedColor,
            label: label,
            overlayPID: pid
        )
    }

    private static func findOverlayBinary() throws -> String {
        let fm = FileManager.default
        let overlayName = "colored-sim-overlay"

        // 1. Next to the current executable (resolve symlinks for Homebrew)
        let currentExec = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().path
        let execDir = (currentExec as NSString).deletingLastPathComponent
        let nearExec = (execDir as NSString).appendingPathComponent(overlayName)
        if fm.isExecutableFile(atPath: nearExec) {
            return nearExec
        }

        // 2. Search PATH
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                let candidate = "\(dir)/\(overlayName)"
                if fm.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }

        // 3. Common known locations
        let knownPaths = [
            "/opt/homebrew/bin/\(overlayName)",
            "/usr/local/bin/\(overlayName)",
            ".build/debug/\(overlayName)",
            ".build/release/\(overlayName)",
        ]
        for path in knownPaths {
            if fm.isExecutableFile(atPath: path) {
                return path
            }
        }

        throw SimError.overlayBinaryNotFound
    }
}

public enum ClaimError: LocalizedError {
    case deviceNotFound(String)
    case noBootedSimulator
    case alreadyClaimed(String, String, String)
    case unknownColor(String)

    public var errorDescription: String? {
        switch self {
        case .deviceNotFound(let udid):
            return "No simulator found with UDID \(udid)"
        case .noBootedSimulator:
            return "No booted simulators found. Use --boot to auto-boot one."
        case .alreadyClaimed(let name, let color, let label):
            return "Simulator \(name) is already claimed with color \(color) by \"\(label)\""
        case .unknownColor(let color):
            return "Unknown color '\(color)'. Available: \(SimColor.allCases.map(\.rawValue).joined(separator: ", "))"
        }
    }
}
