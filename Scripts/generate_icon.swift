// Renders the 🦔 emoji into every PNG size macOS expects for an .icns,
// then invokes iconutil to build AppIcon.icns. Runs fully offline.
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

func renderEmoji(_ emoji: String, size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let bgRect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor(calibratedWhite: 1.0, alpha: 0.0).setFill()
    bgRect.fill()

    let fontSize = CGFloat(size) * 0.78
    let font = NSFont.systemFont(ofSize: fontSize)
    let attrs: [NSAttributedString.Key: Any] = [.font: font]
    let str = NSAttributedString(string: emoji, attributes: attrs)
    let strSize = str.size()
    let origin = NSPoint(
        x: (CGFloat(size) - strSize.width) / 2,
        y: (CGFloat(size) - strSize.height) / 2
    )
    str.draw(at: origin)

    image.unlockFocus()
    return image
}

for (px, name) in sizes {
    let image = renderEmoji("🦔", size: px)
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
