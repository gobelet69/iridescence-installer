import AppKit

/// Generates the official 111iridescence v2.1 Iridescence Updater application icon:
/// Luminous Pearl squircle + Obsidian nexus container + pixel-grid update glyph + cross-5 pixel star.
func makeIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let scale = size / 1024.0

    // 1. Luminous Pearl macOS Squircle (824x824 at 100,100, rx=185)
    let sqRect = CGRect(x: 100 * scale, y: 100 * scale, width: 824 * scale, height: 824 * scale)
    let sqRadius = 185 * scale
    let sqPath = CGPath(roundedRect: sqRect, cornerWidth: sqRadius, cornerHeight: sqRadius, transform: nil)
    ctx.saveGState()
    ctx.addPath(sqPath)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let pearlColors = [
        NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0).cgColor,
        NSColor(srgbRed: 0.93, green: 0.91, blue: 0.96, alpha: 1.0).cgColor
    ] as CFArray
    if let grad = CGGradient(colorsSpace: colorSpace, colors: pearlColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(grad, start: CGPoint(x: size * 0.5, y: sqRect.maxY), end: CGPoint(x: size * 0.5, y: sqRect.minY), options: [])
    }

    // Specular border ring
    ctx.setStrokeColor(red: 0x16/255.0, green: 0x10/255.0, blue: 0x1D/255.0, alpha: 0.08)
    ctx.setLineWidth(2 * scale)
    ctx.addPath(sqPath)
    ctx.strokePath()

    // 2. Central Obsidian Hub Pad (616x644 at x=204, y=194)
    let padRect = CGRect(x: 204 * scale, y: (1024 - 186 - 644) * scale, width: 616 * scale, height: 644 * scale)
    let padPath = CGPath(roundedRect: padRect, cornerWidth: 110 * scale, cornerHeight: 110 * scale, transform: nil)
    ctx.setFillColor(red: 0x16/255.0, green: 0x10/255.0, blue: 0x1D/255.0, alpha: 1.0)
    ctx.addPath(padPath)
    ctx.fillPath()

    // Helper to draw discrete pixel blocks
    func drawPixel(_ x: CGFloat, _ svgY: CGFloat, _ w: CGFloat, _ h: CGFloat, _ rx: CGFloat, _ r: CGFloat, _ g: CGFloat, _ b: CGFloat) {
        let appY = (1024.0 - svgY - h) * scale
        let rect = CGRect(x: x * scale, y: appY, width: w * scale, height: h * scale)
        let p = CGPath(roundedRect: rect, cornerWidth: rx * scale, cornerHeight: rx * scale, transform: nil)
        ctx.setFillColor(red: r, green: g, blue: b, alpha: 1.0)
        ctx.addPath(p)
        ctx.fillPath()
    }

    // 3. '111.' Pixel Prefix in Hub Header
    drawPixel(276, 232, 22, 48, 4, 0x0C/255.0, 0xC0/255.0, 0xE8/255.0)
    drawPixel(308, 232, 22, 48, 4, 0x22/255.0, 0x66/255.0, 0xF2/255.0)
    drawPixel(340, 232, 22, 48, 4, 0x8A/255.0, 0x38/255.0, 0xF5/255.0)
    drawPixel(374, 258, 22, 22, 4, 0x12/255.0, 0xCC/255.0, 0xB8/255.0)

    // 4. Circular Pixel-Grid Refresh Arrow Loop (Center at ~512, 540)
    // Top Arc: Left to Right (Cyan -> Electric Blue)
    drawPixel(400, 390, 48, 36, 6, 0x0C/255.0, 0xC0/255.0, 0xE8/255.0)
    drawPixel(460, 370, 52, 36, 6, 0x0C/255.0, 0xC0/255.0, 0xE8/255.0)
    drawPixel(524, 370, 52, 36, 6, 0x22/255.0, 0x66/255.0, 0xF2/255.0)
    drawPixel(588, 390, 48, 36, 6, 0x22/255.0, 0x66/255.0, 0xF2/255.0)

    // Top-Right Arrow Head pointing downwards
    drawPixel(644, 390, 36, 36, 6, 0x22/255.0, 0x66/255.0, 0xF2/255.0)
    drawPixel(644, 436, 36, 44, 6, 0x8A/255.0, 0x38/255.0, 0xF5/255.0)
    drawPixel(688, 420, 36, 36, 6, 0x22/255.0, 0x66/255.0, 0xF2/255.0)

    // Right Arc
    drawPixel(644, 490, 36, 52, 6, 0x8A/255.0, 0x38/255.0, 0xF5/255.0)
    drawPixel(628, 552, 36, 52, 6, 0x70/255.0, 0x2E/255.0, 0xE4/255.0)

    // Bottom Arc: Right to Left (Deep Violet -> Turquoise)
    drawPixel(588, 616, 48, 36, 6, 0x70/255.0, 0x2E/255.0, 0xE4/255.0)
    drawPixel(524, 636, 52, 36, 6, 0x70/255.0, 0x2E/255.0, 0xE4/255.0)
    drawPixel(460, 636, 52, 36, 6, 0x12/255.0, 0xCC/255.0, 0xB8/255.0)
    drawPixel(400, 616, 48, 36, 6, 0x12/255.0, 0xCC/255.0, 0xB8/255.0)

    // Bottom-Left Arrow Head pointing upwards
    drawPixel(356, 586, 36, 44, 6, 0x12/255.0, 0xCC/255.0, 0xB8/255.0)
    drawPixel(356, 540, 36, 36, 6, 0x0C/255.0, 0xC0/255.0, 0xE8/255.0)
    drawPixel(312, 552, 36, 36, 6, 0x12/255.0, 0xCC/255.0, 0xB8/255.0)

    // Left Arc
    drawPixel(356, 440, 36, 52, 6, 0x0C/255.0, 0xC0/255.0, 0xE8/255.0)

    // Center Core: 2x2 Luminous Cyan Kernel
    drawPixel(488, 486, 28, 28, 5, 0x0C/255.0, 0xC0/255.0, 0xE8/255.0)
    drawPixel(524, 486, 28, 28, 5, 0x12/255.0, 0xCC/255.0, 0xB8/255.0)
    drawPixel(488, 522, 28, 28, 5, 0x22/255.0, 0x66/255.0, 0xF2/255.0)
    drawPixel(524, 522, 28, 28, 5, 0x70/255.0, 0x2E/255.0, 0xE4/255.0)

    // 5. Signature 5-Cell Pixel Cross Star (`cross-5`) at top-right (720, 240)
    drawPixel(710, 230, 22, 22, 4, 0xFA/255.0, 0xF9/255.0, 0xFC/255.0)
    drawPixel(684, 230, 22, 22, 4, 0x0C/255.0, 0xC0/255.0, 0xE8/255.0)
    drawPixel(736, 230, 22, 22, 4, 0x0C/255.0, 0xC0/255.0, 0xE8/255.0)
    drawPixel(710, 204, 22, 22, 4, 0x0C/255.0, 0xC0/255.0, 0xE8/255.0)
    drawPixel(710, 256, 22, 22, 4, 0x0C/255.0, 0xC0/255.0, 0xE8/255.0)

    ctx.restoreGState()
    image.unlockFocus()
    return image
}

// Generate iconset
let fm = FileManager.default
let iconsetPath = "/tmp/IridescenceUpdater.iconset"
try? fm.removeItem(atPath: iconsetPath)
try! fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let sizes: [(Int, Int, String)] = [
    (16, 1, "icon_16x16.png"),
    (16, 2, "icon_16x16@2x.png"),
    (32, 1, "icon_32x32.png"),
    (32, 2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png"),
]

for (baseSize, scale, filename) in sizes {
    let px = CGFloat(baseSize * scale)
    let img = makeIcon(size: px)
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        continue
    }
    let outUrl = URL(fileURLWithPath: "\(iconsetPath)/\(filename)")
    try! png.write(to: outUrl)
}

let icnsOut = "Resources/AppIcon.icns"
try? fm.createDirectory(atPath: "Resources", withIntermediateDirectories: true)

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconsetPath, "-o", icnsOut]
try! p.run()
p.waitUntilExit()

print("✔ Generated \(icnsOut) successfully")
