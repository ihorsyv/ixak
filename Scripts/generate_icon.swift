// Draws a modern macOS-style app icon (rounded-square gradient background
// + a hand-drawn hedgehog silhouette) at every size macOS expects, then
// builds AppIcon.icns via iconutil. Fully offline, no external assets.
import AppKit

let sizes: [(Int, String)] = [
    (16, "16x16"), (32, "16x16@2x"),
    (32, "32x32"), (64, "32x32@2x"),
    (128, "128x128"), (256, "128x128@2x"),
    (256, "256x256"), (512, "256x256@2x"),
    (512, "512x512"), (1024, "512x512@2x"),
]

let fm = FileManager.default
let iconsetURL = URL(fileURLWithPath: "Resources/AppIcon.iconset")
try? fm.removeItem(at: iconsetURL)
try fm.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func drawHedgehogIcon(size px: Int) -> NSImage {
    let s = CGFloat(px)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext

    // macOS Big Sur-style rounded-square background with a diagonal gradient.
    let cornerRadius = s * 0.2237
    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.30, green: 0.20, blue: 0.55, alpha: 1.0),
        NSColor(calibratedRed: 0.13, green: 0.09, blue: 0.30, alpha: 1.0),
    ])
    ctx.saveGState()
    bgPath.addClip()
    gradient?.draw(in: bgRect, angle: -60)
    ctx.restoreGState()

    // Hedgehog silhouette, built from bezier shapes, centered in the canvas.
    let cx = s * 0.5
    let cy = s * 0.44
    let bodyW = s * 0.62
    let bodyH = s * 0.40

    let body = NSBezierPath()
    body.appendOval(in: CGRect(x: cx - bodyW / 2, y: cy - bodyH / 2, width: bodyW, height: bodyH))

    // Spikes: a fan of triangles along the back (upper-right arc of the body).
    let spikeColor = NSColor.white
    let bodyColor = NSColor(calibratedWhite: 0.97, alpha: 1.0)

    let spikesPath = NSBezierPath()
    let spikeCount = 8
    let arcStart = 5.0 * .pi / 180
    let arcEnd = 175.0 * .pi / 180
    let radiusX = bodyW / 2
    let radiusY = bodyH / 2
    let spikeLength = s * 0.17

    for i in 0..<spikeCount {
        let t = arcStart + (arcEnd - arcStart) * (Double(i) / Double(spikeCount - 1))
        let baseX = cx + CGFloat(cos(t)) * radiusX
        let baseY = cy + CGFloat(sin(t)) * radiusY * 1.02
        let normalX = CGFloat(cos(t))
        let normalY = CGFloat(sin(t))
        let tipX = baseX + normalX * spikeLength
        let tipY = baseY + normalY * spikeLength

        let perpX = -normalY * (s * 0.028)
        let perpY = normalX * (s * 0.028)

        spikesPath.move(to: CGPoint(x: baseX + perpX, y: baseY + perpY))
        spikesPath.line(to: CGPoint(x: tipX, y: tipY))
        spikesPath.line(to: CGPoint(x: baseX - perpX, y: baseY - perpY))
        spikesPath.close()
    }
    spikeColor.setFill()
    spikesPath.fill()

    // Nose triangle pointing left.
    let nose = NSBezierPath()
    let noseTipX = cx - bodyW / 2 - s * 0.10
    nose.move(to: CGPoint(x: noseTipX, y: cy - s * 0.015))
    nose.line(to: CGPoint(x: cx - bodyW / 2 + s * 0.06, y: cy + s * 0.10))
    nose.line(to: CGPoint(x: cx - bodyW / 2 + s * 0.06, y: cy - s * 0.13))
    nose.close()

    bodyColor.setFill()
    body.fill()
    nose.fill()

    // Small dark eye and nose dot.
    let accent = NSColor(calibratedRed: 0.13, green: 0.09, blue: 0.30, alpha: 1.0)
    let eyeSize = s * 0.028
    let eyeRect = CGRect(x: cx - bodyW * 0.16, y: cy + s * 0.02, width: eyeSize, height: eyeSize)
    accent.setFill()
    NSBezierPath(ovalIn: eyeRect).fill()

    let noseDotSize = s * 0.032
    let noseDotRect = CGRect(x: noseTipX - noseDotSize / 2, y: cy - s * 0.015 - noseDotSize / 2, width: noseDotSize, height: noseDotSize)
    NSBezierPath(ovalIn: noseDotRect).fill()

    image.unlockFocus()
    return image
}

for (px, name) in sizes {
    let image = drawHedgehogIcon(size: px)
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to render icon at size \(px)")
    }
    let fileURL = iconsetURL.appendingPathComponent("icon_\(name).png")
    try png.write(to: fileURL)
    print("Wrote \(fileURL.lastPathComponent)")
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", "Resources/AppIcon.icns"]
try process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("Created Resources/AppIcon.icns")
} else {
    print("iconutil failed with status \(process.terminationStatus)")
}
