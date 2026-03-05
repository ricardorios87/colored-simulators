import ColoredSimKit
import Foundation

// MARK: - JSON-RPC Types

struct JSONRPCRequest: Codable {
    let jsonrpc: String
    let id: AnyCodableID?
    let method: String
    let params: [String: AnyCodable]?
}

struct JSONRPCResponse: Codable {
    let jsonrpc: String = "2.0"
    let id: AnyCodableID?
    let result: AnyCodable?
    let error: JSONRPCError?
}

struct JSONRPCError: Codable {
    let code: Int
    let message: String
}

// Flexible ID that handles both Int and String
enum AnyCodableID: Codable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else {
            throw DecodingError.typeMismatch(AnyCodableID.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected Int or String"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let val): try container.encode(val)
        case .string(let val): try container.encode(val)
        }
    }
}

// Flexible JSON value type
indirect enum AnyCodable: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodable])
    case object([String: AnyCodable])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let val = try? container.decode(String.self) { self = .string(val) }
        else if let val = try? container.decode(Bool.self) { self = .bool(val) }
        else if let val = try? container.decode(Int.self) { self = .int(val) }
        else if let val = try? container.decode(Double.self) { self = .double(val) }
        else if let val = try? container.decode([AnyCodable].self) { self = .array(val) }
        else if let val = try? container.decode([String: AnyCodable].self) { self = .object(val) }
        else if container.decodeNil() { self = .null }
        else { throw DecodingError.typeMismatch(AnyCodable.self, .init(codingPath: decoder.codingPath, debugDescription: "Unsupported type")) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let val): try container.encode(val)
        case .int(let val): try container.encode(val)
        case .double(let val): try container.encode(val)
        case .bool(let val): try container.encode(val)
        case .array(let val): try container.encode(val)
        case .object(let val): try container.encode(val)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let val) = self { return val }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let val) = self { return val }
        return nil
    }
}

// MARK: - MCP Server

class MCPServer {
    var clientRootDirectory: String?

    let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    let decoder = JSONDecoder()

    func run() {
        fputs("colored-sim MCP server running on stdio\n", stderr)

        while let line = readLine(strippingNewline: true) {
            guard !line.isEmpty else { continue }

            guard let data = line.data(using: .utf8),
                  let request = try? decoder.decode(JSONRPCRequest.self, from: data) else {
                sendError(id: nil, code: -32700, message: "Parse error")
                continue
            }

            handleRequest(request)
        }
    }

    func handleRequest(_ request: JSONRPCRequest) {
        switch request.method {
        case "initialize":
            handleInitialize(request)
        case "notifications/initialized":
            // No response needed for notifications
            break
        case "tools/list":
            handleToolsList(request)
        case "tools/call":
            handleToolsCall(request)
        default:
            sendError(id: request.id, code: -32601, message: "Method not found: \(request.method)")
        }
    }

    func handleInitialize(_ request: JSONRPCRequest) {
        // Extract client root directory from roots param
        if let params = request.params,
           case .array(let roots) = params["roots"],
           case .object(let firstRoot) = roots.first,
           let uri = firstRoot["uri"]?.stringValue {
            // roots URIs are file:// URLs
            if uri.hasPrefix("file://") {
                clientRootDirectory = String(uri.dropFirst(7))
            } else {
                clientRootDirectory = uri
            }
        }

        let result: AnyCodable = .object([
            "protocolVersion": .string("2024-11-05"),
            "capabilities": .object([
                "tools": .object([:])
            ]),
            "serverInfo": .object([
                "name": .string("colored-sim"),
                "version": .string("1.0.0")
            ])
        ])
        sendResult(id: request.id, result: result)
    }

    func handleToolsList(_ request: JSONRPCRequest) {
        let tools: AnyCodable = .object([
            "tools": .array([
                .object([
                    "name": .string("claim_simulator"),
                    "description": .string("Claim an iOS Simulator with a colored border and floating label. Auto-boots a simulator if none is running. Returns the UDID, device name, color, and overlay PID."),
                    "inputSchema": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "label": .object([
                                "type": .string("string"),
                                "description": .string("Agent name (e.g. 'Claude Code', 'Cursor'). The current git branch is auto-appended to the label.")
                            ]),
                            "color": .object([
                                "type": .string("string"),
                                "description": .string("Border color: red, blue, green, orange, purple, yellow, pink, cyan, teal. Auto-assigned if omitted."),
                                "enum": .array(SimColor.allCases.map { .string($0.rawValue) })
                            ]),
                            "udid": .object([
                                "type": .string("string"),
                                "description": .string("Simulator UDID. If omitted, picks the first available unclaimed booted simulator.")
                            ]),
                            "boot": .object([
                                "type": .string("boolean"),
                                "description": .string("Boot a simulator if none is booted. Defaults to true."),
                                "default": .bool(true)
                            ]),
                            "directory": .object([
                                "type": .string("string"),
                                "description": .string("Project directory path for git branch detection. Pass your current working directory.")
                            ])
                        ]),
                        "required": .array([.string("label")])
                    ])
                ]),
                .object([
                    "name": .string("release_simulator"),
                    "description": .string("Remove the colored overlay from a simulator. If only one simulator is claimed, no UDID is needed."),
                    "inputSchema": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "udid": .object([
                                "type": .string("string"),
                                "description": .string("Simulator UDID to release. Optional if only one is claimed.")
                            ])
                        ])
                    ])
                ]),
                .object([
                    "name": .string("release_all_simulators"),
                    "description": .string("Remove all colored overlays from all simulators."),
                    "inputSchema": .object([
                        "type": .string("object"),
                        "properties": .object([:])
                    ])
                ]),
                .object([
                    "name": .string("list_simulators"),
                    "description": .string("List all booted iOS Simulators and their claim status (color, label, overlay PID)."),
                    "inputSchema": .object([
                        "type": .string("object"),
                        "properties": .object([:])
                    ])
                ])
            ])
        ])
        sendResult(id: request.id, result: tools)
    }

    func handleToolsCall(_ request: JSONRPCRequest) {
        guard let params = request.params,
              let nameVal = params["name"]?.stringValue else {
            sendError(id: request.id, code: -32602, message: "Missing tool name")
            return
        }

        let arguments: [String: AnyCodable] = {
            if case .object(let args) = params["arguments"] { return args }
            return [:]
        }()

        switch nameVal {
        case "claim_simulator":
            handleClaimSimulator(id: request.id, arguments: arguments)
        case "release_simulator":
            handleReleaseSimulator(id: request.id, arguments: arguments)
        case "release_all_simulators":
            handleReleaseAllSimulators(id: request.id)
        case "list_simulators":
            handleListSimulators(id: request.id)
        default:
            sendError(id: request.id, code: -32602, message: "Unknown tool: \(nameVal)")
        }
    }

    // MARK: - Tool Handlers

    func handleClaimSimulator(id: AnyCodableID?, arguments: [String: AnyCodable]) {
        let agentName = arguments["label"]?.stringValue ?? "Agent"
        let directory = arguments["directory"]?.stringValue
            ?? clientRootDirectory
            ?? ProcessInfo.processInfo.environment["PWD"]
        let label = GitHelper.buildLabel(agentName: agentName, directory: directory)
        let color = arguments["color"]?.stringValue
        let udid = arguments["udid"]?.stringValue
        let boot = arguments["boot"]?.boolValue ?? true

        do {
            let result = try OverlayLauncher.claim(udid: udid, color: color, label: label, boot: boot)

            sendToolResult(id: id, text: """
                Claimed simulator with colored border.
                  Device: \(result.deviceName)
                  UDID: \(result.udid)
                  Color: \(result.color.rawValue)
                  Label: \(result.label)
                  Overlay PID: \(result.overlayPID)
                """)
        } catch {
            sendToolResult(id: id, text: "Error: \(error.localizedDescription)", isError: true)
        }
    }

    func handleReleaseSimulator(id: AnyCodableID?, arguments: [String: AnyCodable]) {
        do {
            try Registry.pruneStale()
            let registry = Registry.load()

            let targetUDID: String
            if let udid = arguments["udid"]?.stringValue {
                targetUDID = udid
            } else if registry.count == 1, let only = registry.keys.first {
                targetUDID = only
            } else if registry.isEmpty {
                sendToolResult(id: id, text: "No claimed simulators.")
                return
            } else {
                let list = registry.values.map { "\($0.udid) — \($0.deviceName) [\($0.color)] \"\($0.label)\"" }.joined(separator: "\n  ")
                sendToolResult(id: id, text: "Multiple claimed simulators. Specify a UDID:\n  \(list)", isError: true)
                return
            }

            guard let entry = try Registry.remove(udid: targetUDID) else {
                sendToolResult(id: id, text: "No claim found for UDID \(targetUDID)", isError: true)
                return
            }

            kill(entry.overlayPID, SIGTERM)
            sendToolResult(id: id, text: "Released \(entry.deviceName) [\(entry.color)] — overlay removed.")
        } catch {
            sendToolResult(id: id, text: "Error: \(error.localizedDescription)", isError: true)
        }
    }

    func handleReleaseAllSimulators(id: AnyCodableID?) {
        do {
            let registry = Registry.load()
            if registry.isEmpty {
                sendToolResult(id: id, text: "No claimed simulators.")
                return
            }

            var released: [String] = []
            for (_, entry) in registry {
                kill(entry.overlayPID, SIGTERM)
                released.append("\(entry.deviceName) [\(entry.color)]")
            }
            try Registry.save([:])
            sendToolResult(id: id, text: "Released all simulators:\n  \(released.joined(separator: "\n  "))")
        } catch {
            sendToolResult(id: id, text: "Error: \(error.localizedDescription)", isError: true)
        }
    }

    func handleListSimulators(id: AnyCodableID?) {
        do {
            try Registry.pruneStale()
            let devices = try SimulatorService.listDevices()
            let registry = Registry.load()
            let booted = devices.bootedDevices

            if booted.isEmpty {
                sendToolResult(id: id, text: "No booted simulators.")
                return
            }

            var lines: [String] = ["Booted Simulators:"]
            for device in booted {
                if let entry = registry[device.udid] {
                    lines.append("  [\(entry.color)] \(device.name) — \"\(entry.label)\" (UDID: \(device.udid), PID: \(entry.overlayPID))")
                } else {
                    lines.append("  [unclaimed] \(device.name) (UDID: \(device.udid))")
                }
            }
            sendToolResult(id: id, text: lines.joined(separator: "\n"))
        } catch {
            sendToolResult(id: id, text: "Error: \(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - Response Helpers

    func sendResult(id: AnyCodableID?, result: AnyCodable) {
        let response = JSONRPCResponse(id: id, result: result, error: nil)
        send(response)
    }

    func sendError(id: AnyCodableID?, code: Int, message: String) {
        let response = JSONRPCResponse(id: id, result: nil, error: JSONRPCError(code: code, message: message))
        send(response)
    }

    func sendToolResult(id: AnyCodableID?, text: String, isError: Bool = false) {
        let content: AnyCodable = .object([
            "content": .array([
                .object([
                    "type": .string("text"),
                    "text": .string(text)
                ])
            ]),
            "isError": .bool(isError)
        ])
        sendResult(id: id, result: content)
    }

    func send(_ response: JSONRPCResponse) {
        guard let data = try? encoder.encode(response),
              let json = String(data: data, encoding: .utf8) else { return }
        print(json)
        fflush(stdout)
    }
}

// MARK: - Entry Point

let server = MCPServer()
server.run()
