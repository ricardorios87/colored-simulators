import Foundation

public struct SimDevice: Codable {
    public let udid: String
    public let name: String
    public let state: String
    public let isAvailable: Bool

    public var isBooted: Bool { state == "Booted" }

    public init(udid: String, name: String, state: String, isAvailable: Bool) {
        self.udid = udid
        self.name = name
        self.state = state
        self.isAvailable = isAvailable
    }
}

public struct SimDeviceList: Codable {
    public let devices: [String: [SimDevice]]

    public var allDevices: [SimDevice] {
        devices.values.flatMap { $0 }
    }

    public var bootedDevices: [SimDevice] {
        allDevices.filter(\.isBooted)
    }

    public var availableDevices: [SimDevice] {
        allDevices.filter(\.isAvailable)
    }
}

public enum SimulatorService {
    public static func listDevices() throws -> SimDeviceList {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "devices", "-j"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return try JSONDecoder().decode(SimDeviceList.self, from: data)
    }

    public static func bootDevice(udid: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "boot", udid]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw SimError.bootFailed(udid)
        }

        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-a", "Simulator"]
        try open.run()
        open.waitUntilExit()
    }
}

public enum SimError: LocalizedError {
    case bootFailed(String)
    case noSimulatorFound
    case simulatorNotBooted(String)
    case overlayBinaryNotFound

    public var errorDescription: String? {
        switch self {
        case .bootFailed(let udid):
            return "Failed to boot simulator \(udid)"
        case .noSimulatorFound:
            return "No available simulator found"
        case .simulatorNotBooted(let udid):
            return "Simulator \(udid) is not booted"
        case .overlayBinaryNotFound:
            return "colored-sim-overlay binary not found. Build it with: swift build"
        }
    }
}
