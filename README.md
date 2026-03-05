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

The binaries will be at `.build/release/colored-sim` and `.build/release/colored-sim-overlay`. Both need to be in the same directory.

To install globally:

```bash
cp .build/release/colored-sim .build/release/colored-sim-overlay /usr/local/bin/
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

## Agent integration

Any agent with shell access can claim a simulator:

```bash
# Agent starts work
colored-sim claim --label "Agent Name" --color blue

# Agent finishes
colored-sim release-all
```

## How it works (technical)

- **CLI** (`colored-sim`) — manages the registry at `~/.colored-sim/registry.json` and spawns overlay processes
- **Overlay** (`colored-sim-overlay`) — a lightweight AppKit process per simulator that draws a borderless `NSWindow` with a colored rounded-rect border and a floating label pill
- **Window tracking** — uses `CGWindowListCopyWindowInfo` to find the Simulator window by name and follow its position every 0.5s
- **Visibility detection** — checks the window z-order and hides the overlay when another window covers more than 50% of the simulator
- **Stale cleanup** — dead overlay processes are automatically pruned from the registry

## License

MIT
