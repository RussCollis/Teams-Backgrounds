import AppKit

// Renders icon.svg into icon.png, every macOS AppIcon size and the in-app Logo.
//
// Usage (from the repository root):
//   swiftc -o /tmp/make-icon Scripts/make-icon.swift && /tmp/make-icon
let root = URL(filePath: FileManager.default.currentDirectoryPath, directoryHint: .isDirectory)
let assets = root.appending(path: "Teams Backgrounds/Assets.xcassets")

guard let svg = NSImage(contentsOf: root.appending(path: "icon.svg")) else {
    FileHandle.standardError.write(Data("Couldn't load icon.svg\n".utf8))
    exit(1)
}

/// Draws the SVG into a square bitmap of `pixels` and writes it as PNG.
func render(_ pixels: Int, to url: URL) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { exit(1) }
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    svg.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
    try data.write(to: url)
    print("Wrote \(url.lastPathComponent) (\(pixels) px)")
}

try render(1024, to: root.appending(path: "icon.png"))
try render(512, to: assets.appending(path: "Logo.imageset/Logo.png"))

let iconSet = assets.appending(path: "AppIcon.appiconset")
for points in [16, 32, 128, 256, 512] {
    try render(points, to: iconSet.appending(path: "icon_\(points)x\(points).png"))
    try render(points * 2, to: iconSet.appending(path: "icon_\(points)x\(points)@2x.png"))
}
