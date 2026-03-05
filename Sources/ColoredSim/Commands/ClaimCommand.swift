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

    @Option(name: .long, help: "Agent name. The current git branch is auto-appended.")
    var label: String = "Agent"

    @Option(name: .long, help: "Git repo directory for branch detection. Defaults to current directory.")
    var dir: String?

    @Flag(name: .long, inversion: .prefixedNo, help: "Boot a simulator if none is booted")
    var boot: Bool = true

    func run() throws {
        let fullLabel = GitHelper.buildLabel(agentName: label, directory: dir)
        let result = try OverlayLauncher.claim(udid: udid, color: color, label: fullLabel, boot: boot)

        let c = result.color
        print("\(c.ansi)●\(SimColor.reset) Claimed \(result.deviceName) with \(c.rawValue) border — label: \"\(result.label)\"")
        print("  UDID: \(result.udid)")
        print("  Overlay PID: \(result.overlayPID)")
    }
}
