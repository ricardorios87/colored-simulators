import Foundation

public enum GitHelper {
    /// Detect the current git branch, optionally from a specific directory.
    public static func currentBranch(at directory: String? = nil) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--abbrev-ref", "HEAD"]
        if let dir = directory {
            process.currentDirectoryURL = URL(fileURLWithPath: dir)
        }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let branch = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if branch == "HEAD" { return nil } // detached HEAD
            return branch
        } catch {
            return nil
        }
    }

    /// Build a label from agent name + git branch.
    public static func buildLabel(agentName: String, directory: String? = nil) -> String {
        if let branch = currentBranch(at: directory) {
            return "\(agentName) · \(branch)"
        }
        return agentName
    }
}
