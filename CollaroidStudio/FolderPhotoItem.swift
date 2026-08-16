import AppKit
import ImageIO

enum PhotoBrowserPosition: String, CaseIterable, Identifiable {
    case left
    case bottom

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct FolderPhotoItem: Identifiable, @unchecked Sendable {
    let url: URL
    let thumbnail: NSImage
    let modifiedAt: Date
    let exportKey: String
    var isExported: Bool

    var id: String { url.standardizedFileURL.path }
    var filename: String { url.lastPathComponent }
}

enum PhotoFolderScanner {
    static let supportedExtensions = Set(["jpg", "jpeg", "png"])

    static func scan(folder: URL, exportedKeys: Set<String>) -> [FolderPhotoItem] {
        let keys: Set<URLResourceKey> = [
            .contentModificationDateKey,
            .fileSizeKey,
            .isRegularFileKey
        ]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls.compactMap { url -> FolderPhotoItem? in
            guard supportedExtensions.contains(url.pathExtension.lowercased()) else { return nil }
            let values = try? url.resourceValues(forKeys: keys)
            guard values?.isRegularFile != false,
                  let thumbnail = makeThumbnail(for: url) else { return nil }
            let modifiedAt = values?.contentModificationDate ?? .distantPast
            let key = exportKey(
                for: url,
                modifiedAt: modifiedAt,
                fileSize: values?.fileSize ?? 0
            )
            return FolderPhotoItem(
                url: url,
                thumbnail: thumbnail,
                modifiedAt: modifiedAt,
                exportKey: key,
                isExported: exportedKeys.contains(key)
            )
        }
        .sorted {
            if $0.modifiedAt == $1.modifiedAt {
                return $0.filename.localizedStandardCompare($1.filename) == .orderedAscending
            }
            return $0.modifiedAt < $1.modifiedAt
        }
    }

    static func exportKey(for url: URL) -> String {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        let values = try? url.resourceValues(forKeys: keys)
        return exportKey(
            for: url,
            modifiedAt: values?.contentModificationDate ?? .distantPast,
            fileSize: values?.fileSize ?? 0
        )
    }

    private static func exportKey(for url: URL, modifiedAt: Date, fileSize: Int) -> String {
        let timestamp = Int64((modifiedAt.timeIntervalSince1970 * 1_000).rounded())
        return "\(url.standardizedFileURL.path)|\(timestamp)|\(fileSize)"
    }

    private static func makeThumbnail(for url: URL) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 320,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}
