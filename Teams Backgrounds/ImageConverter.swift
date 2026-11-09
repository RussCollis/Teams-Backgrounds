import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Converts source images (any format ImageIO can read) into Teams-ready PNGs.
nonisolated enum ImageConverter {
    /// Teams thumbnail size used in the background picker.
    static let thumbnailWidth = 280
    static let thumbnailHeight = 158

    /// Converts one item into `<uuid>.png` and `<uuid>_thumb.png` inside `folder`.
    static func convert(_ item: BackgroundItem, into folder: URL, options: BuildOptions) throws {
        let source = try loadImage(at: item.sourceURL)

        let full: CGImage
        if options.resizeMode == .original {
            full = try render(source, width: source.width, height: source.height, mode: .fill, sourceURL: item.sourceURL)
        } else {
            full = try render(
                source,
                width: options.resolution.width,
                height: options.resolution.height,
                mode: options.resizeMode,
                sourceURL: item.sourceURL
            )
        }
        try writePNG(full, to: folder.appending(path: item.fileName))

        let thumbnail = try render(
            source,
            width: thumbnailWidth,
            height: thumbnailHeight,
            mode: options.resizeMode == .fit ? .fit : .fill,
            sourceURL: item.sourceURL
        )
        try writePNG(thumbnail, to: folder.appending(path: item.thumbnailFileName))
    }

    /// Small, orientation-corrected preview for the UI.
    static func preview(of url: URL, maxPixelSize: Int = 400) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Loads the full-resolution image with EXIF orientation applied.
    private static func loadImage(at url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw PackagerError.unreadableImage(url)
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0

        // Creating a "thumbnail" at the image's own size is the simplest way to
        // get ImageIO to bake in the EXIF orientation transform.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(width, height, 1)
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw PackagerError.unreadableImage(url)
        }
        return image
    }

    /// Draws `image` into an sRGB canvas of the given size, filling or fitting as requested.
    private static func render(_ image: CGImage, width: Int, height: Int, mode: ResizeMode, sourceURL: URL) throws -> CGImage {
        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            throw PackagerError.renderFailed(sourceURL)
        }

        context.interpolationQuality = .high
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let sourceWidth = CGFloat(image.width)
        let sourceHeight = CGFloat(image.height)
        let scaleX = CGFloat(width) / sourceWidth
        let scaleY = CGFloat(height) / sourceHeight
        // Fill uses the larger scale (cropping overflow); fit uses the smaller (letterboxing).
        let scale = mode == .fit ? min(scaleX, scaleY) : max(scaleX, scaleY)
        let drawWidth = sourceWidth * scale
        let drawHeight = sourceHeight * scale
        let drawRect = CGRect(
            x: (CGFloat(width) - drawWidth) / 2,
            y: (CGFloat(height) - drawHeight) / 2,
            width: drawWidth,
            height: drawHeight
        )
        context.draw(image, in: drawRect)

        guard let output = context.makeImage() else {
            throw PackagerError.renderFailed(sourceURL)
        }
        return output
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw PackagerError.writeFailed(url)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw PackagerError.writeFailed(url)
        }
    }
}
