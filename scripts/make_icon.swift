// Generates AppIcon.iconset PNGs + AppIcon.icns for the app bundle.
// Run: swift scripts/make_icon.swift <output-dir>
import AppKit

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources"
let iconsetPath = "\(outputDir)/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

func drawIcon(pixels: CGFloat) -> NSBitmapImageRep? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(pixels),
        pixelsHigh: Int(pixels),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = pixels
    let inset = s * 0.09
    let box = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let path = NSBezierPath(roundedRect: box, xRadius: s * 0.2, yRadius: s * 0.2)
    let gradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.31, green: 0.27, blue: 0.92, alpha: 1.0),
            NSColor(calibratedRed: 0.13, green: 0.62, blue: 0.95, alpha: 1.0),
        ]
    )
    gradient?.draw(in: path, angle: -65)

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.baseWritingDirection = .leftToRight

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowBlurRadius = s * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.01)

    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: s * 0.40, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph,
        .shadow: shadow,
    ]
    let text = NSAttributedString(string: "A ع", attributes: attrs)
    let size = text.size()
    let textRect = NSRect(
        x: (s - size.width) / 2,
        y: (s - size.height) / 2 - s * 0.01,
        width: size.width,
        height: size.height
    )
    text.draw(in: textRect)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let specs: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for spec in specs {
    guard let rep = drawIcon(pixels: spec.pixels),
          let png = rep.representation(using: .png, properties: [:])
    else {
        FileHandle.standardError.write(Data("failed to render \(spec.name)\n".utf8))
        exit(1)
    }
    let url = URL(fileURLWithPath: "\(iconsetPath)/\(spec.name).png")
    try png.write(to: url)
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetPath, "-o", "\(outputDir)/AppIcon.icns"]
try task.run()
task.waitUntilExit()
exit(task.terminationStatus)
