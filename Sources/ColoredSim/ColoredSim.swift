import ArgumentParser

@main
struct ColoredSim: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "colored-sim",
        abstract: "Colored borders for iOS Simulators — know which agent owns which simulator",
        subcommands: [
            ClaimCommand.self,
            ReleaseCommand.self,
            ReleaseAllCommand.self,
            ListCommand.self,
        ],
        defaultSubcommand: ListCommand.self
    )
}
