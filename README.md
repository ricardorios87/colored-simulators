# colored-sim

Colored borders and floating labels for iOS Simulator windows. Know which AI agent owns which simulator at a glance.

Inspired by [RocketSim](https://www.rocketsim.app/).

## Install

```bash
brew tap ricardorios87/tap
brew install colored-sim
```

> macOS will ask for **Screen Recording** permission on first run. The overlay needs this to track simulator windows.

<details>
<summary>Build from source</summary>

Requires macOS 13+ and Swift 5.9+.

```bash
git clone https://github.com/ricardorios87/colored-simulators.git
cd colored-simulators
swift build -c release
cp .build/release/colored-sim .build/release/colored-sim-overlay .build/release/colored-sim-mcp /usr/local/bin/
```

</details>

## Quick Start

```bash
# Claim a simulator (auto-boots one if needed, auto-picks a color)
colored-sim claim --label "Claude Code"

# Claim with a specific color
colored-sim claim --label "Cursor" --color red

# See all simulators and who owns them
colored-sim list

# Release when done
colored-sim release-all
```

### Available colors

`red` `blue` `green` `orange` `purple` `yellow` `pink` `cyan` `teal`

Colors are auto-assigned if you don't specify one.

## MCP Setup (for AI agents)

The MCP server lets agents like Claude Code claim simulators as a native tool — no shell needed.

Add to your `~/.claude.json` or project `.mcp.json`:

```json
{
  "mcpServers": {
    "colored-sim": {
      "command": "colored-sim-mcp"
    }
  }
}
```

That's it. Your agent now has these tools:

| Tool | What it does |
|------|-------------|
| `claim_simulator` | Claim a simulator with a colored border and label |
| `release_simulator` | Remove the overlay from a simulator |
| `release_all_simulators` | Remove all overlays |
| `list_simulators` | List booted simulators and their claim status |

## How it works

- A colored rounded-corner border and floating label are drawn on top of the Simulator window
- The overlay tracks the window position as you move or resize it
- Overlays auto-hide when the simulator is behind another window
- If no simulator is booted, one is started automatically
- Dead overlay processes are cleaned up automatically

## License

MIT
