import AppKit

let folder = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let transform = NSAffineTransform(); transform.scale(by: CGFloat(pixels) / 1024); transform.concat()
        let background = NSBezierPath(roundedRect: NSRect(x: 25, y: 25, width: 974, height: 974), xRadius: 220, yRadius: 220)
        NSGradient(starting: NSColor(calibratedRed: 0.13, green: 0.66, blue: 1, alpha: 1), ending: NSColor(calibratedRed: 0.04, green: 0.32, blue: 0.96, alpha: 1))!.draw(in: background, angle: -90)
        NSColor.white.setFill()
        NSBezierPath(roundedRect: NSRect(x: 170, y: 275, width: 684, height: 545), xRadius: 165, yRadius: 165).fill()
        let tail = NSBezierPath(); tail.move(to: NSPoint(x: 290, y: 340)); tail.line(to: NSPoint(x: 232, y: 170)); tail.line(to: NSPoint(x: 475, y: 305)); tail.close(); tail.fill()
        NSColor(calibratedRed: 0.06, green: 0.46, blue: 0.99, alpha: 1).setStroke()
        let arrow = NSBezierPath(); arrow.lineWidth = 48; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
        arrow.move(to: NSPoint(x: 512, y: 685)); arrow.line(to: NSPoint(x: 512, y: 434))
        arrow.move(to: NSPoint(x: 409, y: 535)); arrow.line(to: NSPoint(x: 512, y: 432)); arrow.line(to: NSPoint(x: 615, y: 535))
        arrow.stroke()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(folder)/icon_\(size)x\(size)\(suffix).png"))
    }
}

// ICNS stores PNG representations in length-prefixed chunks.
func bigEndian(_ number: UInt32) -> Data {
    var value = number.bigEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}
var chunks = Data()
for (kind, file) in [("icp4", "icon_16x16.png"), ("icp5", "icon_32x32.png"),
                     ("icp6", "icon_32x32@2x.png"), ("ic07", "icon_128x128.png"),
                     ("ic08", "icon_256x256.png"), ("ic09", "icon_512x512.png"),
                     ("ic10", "icon_512x512@2x.png")] {
    let png = try Data(contentsOf: URL(fileURLWithPath: folder + "/" + file))
    chunks.append(Data(kind.utf8)); chunks.append(bigEndian(UInt32(png.count + 8))); chunks.append(png)
}
var icon = Data("icns".utf8); icon.append(bigEndian(UInt32(chunks.count + 8))); icon.append(chunks)
try icon.write(to: URL(fileURLWithPath: folder).deletingLastPathComponent().appendingPathComponent("AppIcon.icns"))
