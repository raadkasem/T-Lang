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
    let path = NSBezierPath(roundedRect: box, xRadius: s * 0.21, yRadius: s * 0.21)

    // Lapis & Gold: deep manuscript-night ground.
    let ground = NSGradient(
        colors: [
            NSColor(srgbRed: 0.10, green: 0.13, blue: 0.32, alpha: 1.0),
            NSColor(srgbRed: 0.043, green: 0.055, blue: 0.10, alpha: 1.0),
        ]
    )
    ground?.draw(in: path, angle: -90)

    // Soft lapis glow top-left, faint gold dawn bottom-right.
    NSGraphicsContext.current?.saveGraphicsState()
    path.addClip()
    let lapisGlow = NSGradient(
        colors: [
            NSColor(srgbRed: 0.24, green: 0.33, blue: 0.91, alpha: 0.55),
            NSColor(srgbRed: 0.24, green: 0.33, blue: 0.91, alpha: 0.0),
        ]
    )
    lapisGlow?.draw(
        fromCenter: NSPoint(x: s * 0.2, y: s * 0.85), radius: 0,
        toCenter: NSPoint(x: s * 0.2, y: s * 0.85), radius: s * 0.7,
        options: []
    )
    let goldGlow = NSGradient(
        colors: [
            NSColor(srgbRed: 0.91, green: 0.73, blue: 0.29, alpha: 0.34),
            NSColor(srgbRed: 0.91, green: 0.73, blue: 0.29, alpha: 0.0),
        ]
    )
    goldGlow?.draw(
        fromCenter: NSPoint(x: s * 0.85, y: s * 0.15), radius: 0,
        toCenter: NSPoint(x: s * 0.85, y: s * 0.15), radius: s * 0.65,
        options: []
    )
    NSGraphicsContext.current?.restoreGraphicsState()

    // Inner hairline ring, like gold-leaf tooling on a book cover.
    let ringInset = s * 0.135
    let ring = NSBezierPath(
        roundedRect: NSRect(x: ringInset, y: ringInset, width: s - ringInset * 2, height: s - ringInset * 2),
        xRadius: s * 0.165, yRadius: s * 0.165
    )
    ring.lineWidth = max(1, s * 0.008)
    NSColor(srgbRed: 0.91, green: 0.73, blue: 0.29, alpha: 0.45).setStroke()
    ring.stroke()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.baseWritingDirection = .leftToRight

    func glyph(_ string: String, color: NSColor, size fontSize: CGFloat) -> NSAttributedString {
        let shadow = NSShadow()
        shadow.shadowColor = color.withAlphaComponent(0.55)
        shadow.shadowBlurRadius = s * 0.045
        return NSAttributedString(string: string, attributes: [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
            .shadow: shadow,
        ])
    }

    // "A" in lapis (English), "ع" in gold (Arabic) — the two language identities.
    let lapis = NSColor(srgbRed: 0.50, green: 0.59, blue: 1.0, alpha: 1.0)
    let gold = NSColor(srgbRed: 0.93, green: 0.75, blue: 0.32, alpha: 1.0)
    let a = glyph("A", color: lapis, size: s * 0.36)
    let ain = glyph("ع", color: gold, size: s * 0.38)
    let aSize = a.size()
    let ainSize = ain.size()
    let gap = s * 0.015
    let totalWidth = aSize.width + gap + ainSize.width
    let baselineY = (s - max(aSize.height, ainSize.height)) / 2
    a.draw(at: NSPoint(x: (s - totalWidth) / 2, y: baselineY + s * 0.012))
    ain.draw(at: NSPoint(x: (s - totalWidth) / 2 + aSize.width + gap, y: baselineY))

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
