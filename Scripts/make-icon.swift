import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Renders the Teams Backgrounds app icon at 1024 px and writes all macOS sizes.
let outputDir = URL(filePath: CommandLine.arguments[1], directoryHint: .isDirectory)
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func renderMaster() -> CGImage {
    let size = 1024
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

    // macOS icon grid: 824 pt rounded square centered on a 1024 canvas.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Drop shadow under the tile.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: color(0x000000, 0.35))
    ctx.addPath(tilePath)
    ctx.setFillColor(color(0x5B5FC7))
    ctx.fillPath()
    ctx.restoreGState()

    // Teams-style indigo gradient background.
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let background = CGGradient(colorsSpace: space, colors: [color(0x7B83EB), color(0x4B4FB0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(background, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    // Back "photo" card, tilted.
    func card(_ rect: CGRect, angle: CGFloat, fill: CGColor) {
        ctx.saveGState()
        ctx.translateBy(x: rect.midX, y: rect.midY)
        ctx.rotate(by: angle)
        let r = CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height)
        ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: color(0x1B1D5C, 0.4))
        ctx.addPath(CGPath(roundedRect: r, cornerWidth: 44, cornerHeight: 44, transform: nil))
        ctx.setFillColor(fill)
        ctx.fillPath()
        ctx.restoreGState()
    }
    card(CGRect(x: 250, y: 400, width: 560, height: 330), angle: 0.12, fill: color(0xC5C9F7))

    // Front 16:9 photo card with a landscape scene.
    let photo = CGRect(x: 212, y: 330, width: 600, height: 340)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x1B1D5C, 0.45))
    let photoPath = CGPath(roundedRect: photo, cornerWidth: 44, cornerHeight: 44, transform: nil)
    ctx.addPath(photoPath)
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()

    let inner = photo.insetBy(dx: 22, dy: 22)
    let innerPath = CGPath(roundedRect: inner, cornerWidth: 26, cornerHeight: 26, transform: nil)
    ctx.saveGState()
    ctx.addPath(innerPath)
    ctx.clip()
    let sky = CGGradient(colorsSpace: space, colors: [color(0x9FD8FF), color(0xE6F4FF)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: inner.maxY), end: CGPoint(x: 0, y: inner.minY), options: [])

    // Sun
    ctx.setFillColor(color(0xFFC83D))
    ctx.fillEllipse(in: CGRect(x: inner.maxX - 150, y: inner.maxY - 130, width: 90, height: 90))

    // Mountains (polygons extend past the bottom edge so there are no gaps).
    ctx.setFillColor(color(0x6FBF73))
    ctx.move(to: CGPoint(x: inner.minX - 40, y: inner.minY - 10))
    ctx.addLine(to: CGPoint(x: inner.minX - 40, y: inner.minY + 60))
    ctx.addLine(to: CGPoint(x: inner.minX + 150, y: inner.minY + 190))
    ctx.addLine(to: CGPoint(x: inner.minX + 330, y: inner.minY - 10))
    ctx.closePath()
    ctx.fillPath()
    ctx.setFillColor(color(0x3E9A54))
    ctx.move(to: CGPoint(x: inner.minX + 170, y: inner.minY - 10))
    ctx.addLine(to: CGPoint(x: inner.minX + 400, y: inner.minY + 230))
    ctx.addLine(to: CGPoint(x: inner.maxX + 40, y: inner.minY - 10))
    ctx.closePath()
    ctx.fillPath()

    // Person in front of the background, like a video-call tile.
    let personColor = color(0x2E3192)
    let headCenter = CGPoint(x: 512, y: inner.minY + 150)
    let headRadius: CGFloat = 52
    let shouldersCenter = CGPoint(x: 512, y: inner.minY - 30)
    let shouldersRadius: CGFloat = 130

    // White outline first so the figure separates from the scene.
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillEllipse(in: CGRect(x: headCenter.x - headRadius - 9, y: headCenter.y - headRadius - 9, width: (headRadius + 9) * 2, height: (headRadius + 9) * 2))
    ctx.fillEllipse(in: CGRect(x: shouldersCenter.x - shouldersRadius - 9, y: shouldersCenter.y - shouldersRadius - 9, width: (shouldersRadius + 9) * 2, height: (shouldersRadius + 9) * 2))

    ctx.setFillColor(personColor)
    ctx.fillEllipse(in: CGRect(x: headCenter.x - headRadius, y: headCenter.y - headRadius, width: headRadius * 2, height: headRadius * 2))
    ctx.fillEllipse(in: CGRect(x: shouldersCenter.x - shouldersRadius, y: shouldersCenter.y - shouldersRadius, width: shouldersRadius * 2, height: shouldersRadius * 2))
    ctx.restoreGState()

    return ctx.makeImage()!
}

func write(_ image: CGImage, pixels: Int, name: String) {
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    let url = outputDir.appending(path: name)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}

let master = renderMaster()
var images: [String] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        write(master, pixels: points * scale, name: name)
        images.append("""
            {
              "filename" : "\(name)",
              "idiom" : "mac",
              "scale" : "\(scale)x",
              "size" : "\(points)x\(points)"
            }
        """)
    }
}
let contents = """
{
  "images" : [
\(images.joined(separator: ",\n"))
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

"""
try! contents.write(to: outputDir.appending(path: "Contents.json"), atomically: true, encoding: .utf8)
print("Wrote \(images.count) icons")
