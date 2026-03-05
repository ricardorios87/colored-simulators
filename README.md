# colored-sim

Colored borders and floating labels for iOS Simulator windows. Built for multi-agent workflows where multiple AI agents (Claude Code, Cursor, Copilot, etc.) each run on different simulators and you need to tell them apart at a glance.

Inspired by [RocketSim](https://www.rocketsim.app/).

## How it works

`colored-sim` draws a colored border overlay and a floating label on top of an iOS Simulator window. Each agent claims a simulator with a unique color, so you always know which simulator belongs to which agent.

- Borders have rounded corners and track the simulator window as you move/resize it
- Overlays automatically hide when the simulator is behind another window
- Auto-boots a simulator if none is running
- Auto-assigns colors if you don't specify one

## Installation

Requires macOS 13+ and Swift 5.9+.

```bash
git clone https://github.com/ricardorios87/colored-simulators.git
cd colored-simulators
swift build -c release
```

The binaries will be at `.build/release/colored-sim`, `.build/release/colored-sim-overlay`, and `.build/release/colored-sim-mcp`. The first two need to be in the same directory.

To install globally:

```bash
cp .build/release/colored-sim .build/release/colored-sim-overlay .build/release/colored-sim-mcp /usr/local/bin/
```

> **Note:** On first run, macOS will ask for Screen Recording permission. The overlay needs this to detect simulator window positions.

## Usage

### Claim a simulator

```bash
# Auto-pick a booted simulator, auto-assign a color
colored-sim claim --label "Claude Code"

# Specify a color
colored-sim claim --label "Cursor" --color red

# Specify a simulator by UDID
colored-sim claim --udid "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX" --color green --label "Copilot"

# Use a descriptive label
colored-sim claim --label "Claude Code - Building Feature #42" --color blue
```

If no simulator is booted, one will be started automatically. Use `--no-boot` to disable this.

### List simulators

```bash
colored-sim list
```

Shows all booted simulators with their claim status, color, label, and overlay PID.

### Release a simulator

```bash
# Release a specific simulator
colored-sim release --udid "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"

# If only one is claimed, no UDID needed
colored-sim release

# Release all
colored-sim release-all
```

### Available colors

`red`, `blue`, `green`, `orange`, `purple`, `yellow`, `pink`, `cyan`, `teal`

If you don't specify a color, the next unused one is assigned automatically.

## MCP Server

`colored-sim-mcp` is an MCP (Model Context Protocol) server that lets AI agents claim and release simulators natively — no shell access needed.

### Setup for Claude Code

Add to your `~/.claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "colored-sim": {
      "command": "colored-sim-mcp"
    }
  }
}
```

Or if you haven't installed globally, use the full path:

```json
{
  "mcpServers": {
    "colored-sim": {
      "command": "/path/to/colored-simulators/.build/release/colored-sim-mcp"
    }
  }
}
```

### Available MCP Tools

| Tool | Description |
|------|-------------|
| `claim_simulator` | Claim a simulator with a colored border and label. Auto-boots if needed. |
| `release_simulator` | Remove the overlay from a simulator. |
| `release_all_simulators` | Remove all overlays. |
| `list_simulators` | List all booted simulators and their claim status. |

### Agent integration via CLI

Any agent with shell access can also use the CLI directly:

```bash
# Agent starts work
colored-sim claim --label "Agent Name" --color blue

# Agent finishes
colored-sim release-all
```

## How it works (technical)

- **MCP Server** (`colored-sim-mcp`) — JSON-RPC over stdio server that exposes claim/release/list as MCP tools for AI agents
- **CLI** (`colored-sim`) — manages the registry at `~/.colored-sim/registry.json` and spawns overlay processes
- **Overlay** (`colored-sim-overlay`) — a lightweight AppKit process per simulator that draws a borderless `NSWindow` with a colored rounded-rect border and a floating label pill
- **Window tracking** — uses `CGWindowListCopyWindowInfo` to find the Simulator window by name and follow its position every 0.5s
- **Visibility detection** — checks the window z-order and hides the overlay when another window covers more than 50% of the simulator
- **Stale cleanup** — dead overlay processes are automatically pruned from the registry

## License

MIT
