import Foundation

struct SimDevice: Codable {
    let udid: String
    let name: String
    let state: String
    let isAvailable: Bool

    var isBooted: Bool { state == "Booted" }
}

struct SimDeviceList: Codable {
    let devices: [String: [SimDevice]]

    var allDevices: [SimDevice] {
        devices.values.flatMap { $0 }
    }

    var bootedDevices: [SimDevice] {
        allDevices.filter(\.isBooted)
    }

    var availableDevices: [SimDevice] {
        allDevices.filter(\.isAvailable)
    }
}

enum SimulatorService {
    static func listDevices() throws -> SimDeviceList {
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

    static func bootDevice(udid: String) throws {
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

        // Open Simulator.app so the window appears
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-a", "Simulator"]
        try open.run()
        open.waitUntilExit()
    }

}

enum SimError: LocalizedError {
    case bootFailed(String)
    case noSimulatorFound
    case simulatorNotBooted(String)
    case overlayBinaryNotFound

    var errorDescription: String? {
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
