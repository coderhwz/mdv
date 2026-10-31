import AppKit

let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let tile = NSBezierPath(roundedRect: NSRect(x: 84, y: 84, width: 856, height: 856), xRadius: 192, yRadius: 192)
NSGradient(starting: NSColor(calibratedRed: 0.19, green: 0.30, blue: 0.36, alpha: 1),
           ending: NSColor(calibratedRed: 0.08, green: 0.15, blue: 0.20, alpha: 1))!.draw(in: tile, angle: -90)
let paper = NSBezierPath(roundedRect: NSRect(x: 270, y: 224, width: 484, height: 582), xRadius: 36, yRadius: 36)
NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
paper.fill()
let ink = NSColor(calibratedRed: 0.15, green: 0.25, blue: 0.30, alpha: 1)
let mark = NSBezierPath()
mark.move(to: NSPoint(x: 350, y: 540)); mark.line(to: NSPoint(x: 350, y: 680))
mark.line(to: NSPoint(x: 416, y: 606)); mark.line(to: NSPoint(x: 482, y: 680)); mark.line(to: NSPoint(x: 482, y: 540))
mark.lineWidth = 28; mark.lineJoinStyle = .round; mark.lineCapStyle = .round
ink.setStroke(); mark.stroke()
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 610, y: 686)); arrow.line(to: NSPoint(x: 610, y: 548))
arrow.move(to: NSPoint(x: 564, y: 592)); arrow.line(to: NSPoint(x: 610, y: 546)); arrow.line(to: NSPoint(x: 656, y: 592))
arrow.lineWidth = 24; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round; arrow.stroke()
for (y, width) in [(448.0, 324.0), (380.0, 324.0), (312.0, 210.0)] {
    ink.withAlphaComponent(0.25).setFill()
    NSBezierPath(roundedRect: NSRect(x: 350, y: y, width: width, height: 18), xRadius: 9, yRadius: 9).fill()
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let folder = destination.deletingLastPathComponent().appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        NSImage(cgImage: bitmap.cgImage!, size: NSSize(width: pixels, height: pixels)).draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(name))
    }
}
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", folder.path, "-o", destination.path]
try process.run(); process.waitUntilExit()
guard process.terminationStatus == 0 else { exit(1) }
try FileManager.default.removeItem(at: folder)
