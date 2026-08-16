import AppKit
import ImageIO

struct PhotoAsset {
    let sourceURL: URL
    let previewImage: NSImage
    let pixelSize: CGSize

    static func load(from url: URL) throws -> PhotoAsset {
        guard ["jpg", "jpeg", "png"].contains(url.pathExtension.lowercased()) else {
            throw StudioError.unsupportedImage
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw StudioError.unreadableImage
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2400,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let preview = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw StudioError.unreadableImage
        }
        let image = NSImage(cgImage: preview, size: NSSize(width: preview.width, height: preview.height))

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let rawWidth = properties?[kCGImagePropertyPixelWidth] as? CGFloat ?? CGFloat(preview.width)
        let rawHeight = properties?[kCGImagePropertyPixelHeight] as? CGFloat ?? CGFloat(preview.height)
        let orientation = properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let swapsAxes = [5, 6, 7, 8].contains(orientation)
        let uprightSize = swapsAxes ? CGSize(width: rawHeight, height: rawWidth) : CGSize(width: rawWidth, height: rawHeight)

        return PhotoAsset(sourceURL: url, previewImage: image, pixelSize: uprightSize)
    }
}
