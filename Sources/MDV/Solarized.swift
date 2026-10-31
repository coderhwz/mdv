import AppKit

/// Solarized's sRGB palette, resolved by AppKit against each view's appearance.
enum Solarized {
    static let background = adaptive("background", light: 0xfdf6e3, dark: 0x002b36)
    static let surface = adaptive("surface", light: 0xeee8d5, dark: 0x073642)
    static let text = adaptive("text", light: 0x657b83, dark: 0x839496)
    static let emphasized = adaptive("emphasized", light: 0x586e75, dark: 0x93a1a1)
    static let muted = adaptive("muted", light: 0x93a1a1, dark: 0x586e75)
    static let border = adaptive("border", light: 0x93a1a1, dark: 0x586e75)
    static let blue = color(0x268bd2)
    static let cyan = color(0x2aa198)

    private static func adaptive(_ name: String, light: UInt32, dark: UInt32) -> NSColor {
        let lightColor = color(light)
        let darkColor = color(dark)
        return NSColor(name: NSColor.Name("Solarized.\(name)")) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? darkColor : lightColor
        }
    }

    private static func color(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
                green: CGFloat((hex >> 8) & 0xff) / 255,
                blue: CGFloat(hex & 0xff) / 255, alpha: 1)
    }
}

@MainActor
final class SolarizedBackgroundView: NSView {
    var fillColor = Solarized.background

    override func draw(_ dirtyRect: NSRect) {
        fillColor.setFill()
        dirtyRect.fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

@MainActor
final class SolarizedRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        Solarized.background.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 1), xRadius: 5, yRadius: 5).fill()
    }
}
