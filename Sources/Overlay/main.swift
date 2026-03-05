import AppKit
import CoreGraphics

// MARK: - Argument Parsing (minimal, no dependencies)

func parseArg(_ name: String) -> String? {
    let args = CommandLine.arguments
    guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
    return args[index + 1]
}

guard let deviceName = parseArg("--device-name"),
      let colorHex = parseArg("--color"),
      let label = parseArg("--label") else {
    fputs("Usage: colored-sim-overlay --device-name <name> --color <hex> --label <text>\n", stderr)
    exit(1)
}

func colorFromHex(_ hex: String) -> NSColor {
    let scanner = Scanner(string: hex)
    var value: UInt64 = 0
    scanner.scanHexInt64(&value)
    return NSColor(
        red: CGFloat((value >> 16) & 0xFF) / 255.0,
        green: CGFloat((value >> 8) & 0xFF) / 255.0,
        blue: CGFloat(value & 0xFF) / 255.0,
        alpha: 1.0
    )
}

let borderColor = colorFromHex(colorHex)
let borderWidth: CGFloat = 4.0

// MARK: - Overlay Window

class BorderView: NSView {
    var borderColor: NSColor = .red
    var borderWidth: CGFloat = 4.0
    var cornerRadius: CGFloat = 12.0

    override func draw(_ dirtyRect: NSRect) {
        let inset = borderWidth / 2
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: inset, dy: inset), xRadius: cornerRadius, yRadius: cornerRadius)
        path.lineWidth = borderWidth
        borderColor.setStroke()
        path.stroke()
    }
}

class FloatingTagWindow: NSWindow {
    init(label: String, color: NSColor, at point: NSPoint) {
        let font = NSFont.systemFont(ofSize: 18, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
        ]
        let textSize = (label as NSString).size(withAttributes: attributes)
        let padding: CGFloat = 24
        let height: CGFloat = 38
        let width = textSize.width + padding

        let frame = NSRect(x: point.x, y: point.y, width: width, height: height)
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)

        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces]
        self.ignoresMouseEvents = true
        self.hasShadow = true

        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        container.wantsLayer = true
        container.layer?.backgroundColor = color.withAlphaComponent(0.9).cgColor
        container.layer?.cornerRadius = 10

        let textField = NSTextField(labelWithString: label)
        textField.font = font
        textField.textColor = .white
        textField.frame = NSRect(x: padding / 2, y: (height - textSize.height) / 2, width: textSize.width, height: textSize.height)
        textField.isBezeled = false
        textField.drawsBackground = false

        container.addSubview(textField)
        self.contentView = container
    }
}

class OverlayWindow: NSWindow {
    init(frame: NSRect, color: NSColor, width: CGFloat) {
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces]
        self.ignoresMouseEvents = true
        self.hasShadow = false

        let borderView = BorderView(frame: NSRect(origin: .zero, size: frame.size))
        borderView.borderColor = color
        borderView.borderWidth = width
        self.contentView = borderView
    }

    func updateFrame(_ frame: NSRect) {
        setFrame(frame, display: true)
        if let borderView = contentView as? BorderView {
            borderView.frame = NSRect(origin: .zero, size: frame.size)
            borderView.needsDisplay = true
        }
    }
}

// MARK: - Window Tracker

class SimulatorWindowTracker {
    let deviceName: String
    let color: NSColor
    let label: String
    var overlayWindow: OverlayWindow?
    var tagWindow: FloatingTagWindow?
    var timer: Timer?

    init(deviceName: String, color: NSColor, label: String) {
        self.deviceName = deviceName
        self.color = color
        self.label = label
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.update()
        }
        timer?.tolerance = 0.1
        update()
    }

    func update() {
        guard let simWindow = findSimulatorWindow() else {
            overlayWindow?.orderOut(nil)
            tagWindow?.orderOut(nil)
            return
        }

        // Hide overlay when the simulator is mostly covered by another window
        guard simWindow.isTopmost else {
            overlayWindow?.orderOut(nil)
            tagWindow?.orderOut(nil)
            return
        }

        let nsFrame = cgRectToNS(simWindow.frame)

        if let overlay = overlayWindow {
            overlay.updateFrame(nsFrame)
            overlay.orderFront(nil)
        } else {
            let overlay = OverlayWindow(frame: nsFrame, color: color, width: borderWidth)
            overlay.orderFront(nil)
            self.overlayWindow = overlay
        }

        // Position floating tag above the top-right corner of the simulator
        let tagPoint = NSPoint(
            x: nsFrame.maxX - 120,
            y: nsFrame.maxY + 4
        )

        if let tag = tagWindow {
            tag.setFrameOrigin(tagPoint)
            tag.orderFront(nil)
        } else {
            let tag = FloatingTagWindow(label: label, color: color, at: tagPoint)
            tag.orderFront(nil)
            self.tagWindow = tag
        }
    }

    /// Convert a CGRect (top-left origin, as from CGWindowListCopyWindowInfo)
    /// to an NSRect (bottom-left origin, as AppKit expects).
    /// Uses the primary screen's height as the reference, which is how macOS
    /// maps between CG and NS coordinate spaces across all displays.
    func cgRectToNS(_ cgRect: CGRect) -> NSRect {
        // In macOS, NSScreen.screens[0] is always the primary display.
        // CG coordinates use its top-left as (0,0), NS uses its bottom-left.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSRect(
            x: cgRect.origin.x,
            y: primaryHeight - cgRect.origin.y - cgRect.height,
            width: cgRect.width,
            height: cgRect.height
        )
    }

    struct SimulatorWindowInfo {
        let frame: CGRect
        let isTopmost: Bool
    }

    func findSimulatorWindow() -> SimulatorWindowInfo? {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        // CGWindowListCopyWindowInfo returns windows in front-to-back order.
        // Find the simulator window and check if any normal window is in front
        // of it and substantially overlapping its frame.
        var simFrame: CGRect?
        var simFound = false

        for window in windowList {
            guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any] else {
                continue
            }

            let x = (bounds["X"] as? NSNumber)?.doubleValue ?? 0
            let y = (bounds["Y"] as? NSNumber)?.doubleValue ?? 0
            let w = (bounds["Width"] as? NSNumber)?.doubleValue ?? 0
            let h = (bounds["Height"] as? NSNumber)?.doubleValue ?? 0
            let frame = CGRect(x: x, y: y, width: w, height: h)

            if ownerName == "Simulator",
               let windowName = window[kCGWindowName as String] as? String,
               windowName.contains(deviceName) {
                simFrame = frame
                simFound = true
                break
            }
        }

        guard let frame = simFrame, simFound else { return nil }

        // Now check if any window listed before the simulator (i.e. in front)
        // covers most of its area
        var isTopmost = true
        for window in windowList {
            guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0 else { // Only normal-level windows
                continue
            }

            // Stop when we reach the simulator window itself
            if ownerName == "Simulator",
               let windowName = window[kCGWindowName as String] as? String,
               windowName.contains(deviceName) {
                break
            }

            // Skip our own overlay windows and tiny windows
            if ownerName == "colored-sim-overlay" { continue }

            let x = (bounds["X"] as? NSNumber)?.doubleValue ?? 0
            let y = (bounds["Y"] as? NSNumber)?.doubleValue ?? 0
            let w = (bounds["Width"] as? NSNumber)?.doubleValue ?? 0
            let h = (bounds["Height"] as? NSNumber)?.doubleValue ?? 0
            let otherFrame = CGRect(x: x, y: y, width: w, height: h)

            let intersection = frame.intersection(otherFrame)
            if !intersection.isNull {
                let overlapArea = intersection.width * intersection.height
                let simArea = frame.width * frame.height
                // If another window covers >50% of the simulator, consider it occluded
                if simArea > 0 && overlapArea / simArea > 0.5 {
                    isTopmost = false
                    break
                }
            }
        }

        return SimulatorWindowInfo(frame: frame, isTopmost: isTopmost)
    }
}

// MARK: - App Entry

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // No dock icon, no menu bar

let tracker = SimulatorWindowTracker(deviceName: deviceName, color: borderColor, label: label)

// Handle SIGTERM gracefully
signal(SIGTERM) { _ in
    DispatchQueue.main.async {
        NSApplication.shared.terminate(nil)
    }
}

DispatchQueue.main.async {
    tracker.start()
}

app.run()
