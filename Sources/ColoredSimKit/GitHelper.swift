import Foundation

public enum GitHelper {
    /// Detect the current git branch, optionally from a specific directory.
    public static func currentBranch(at directory: String? = nil) -> String? {
        guard let branch = runGit(["rev-parse", "--abbrev-ref", "HEAD"], at: directory),
              branch != "HEAD" else { return nil } // detached HEAD
        return branch
    }

    /// Name of the linked worktree the directory is in, or nil for the main worktree.
    /// Detected by `--git-dir` differing from `--git-common-dir`: in a linked
    /// worktree git-dir is `<repo>/.git/worktrees/<name>`, in the main worktree
    /// they're equal.
    public static func currentWorktreeName(at directory: String? = nil) -> String? {
        guard let gitDir = runGit(["rev-parse", "--absolute-git-dir"], at: directory),
              let commonDir = runGit(["rev-parse", "--path-format=absolute", "--git-common-dir"], at: directory)
        else { return nil }
        let normalize: (String) -> String = { ($0 as NSString).standardizingPath }
        if normalize(gitDir) == normalize(commonDir) { return nil }
        return (gitDir as NSString).lastPathComponent
    }

    /// Build a label from agent name + git branch, prefixing the branch with
    /// the worktree name when running inside a linked worktree (e.g.
    /// "Claude · feat-login:my-branch").
    public static func buildLabel(agentName: String, directory: String? = nil) -> String {
        guard let branch = currentBranch(at: directory) else { return agentName }
        if let worktree = currentWorktreeName(at: directory) {
            return "\(agentName) · \(worktree):\(branch)"
        }
        return "\(agentName) · \(branch)"
    }

    private static func runGit(_ args: [String], at directory: String?) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
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
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
