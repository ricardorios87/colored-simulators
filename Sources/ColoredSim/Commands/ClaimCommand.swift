import ArgumentParser
import ColoredSimKit
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
        let result = try OverlayLauncher.claim(udid: udid, color: color, label: label, boot: boot)

        let c = result.color
        print("\(c.ansi)●\(SimColor.reset) Claimed \(result.deviceName) with \(c.rawValue) border — label: \"\(result.label)\"")
        print("  UDID: \(result.udid)")
        print("  Overlay PID: \(result.overlayPID)")
    }
}
