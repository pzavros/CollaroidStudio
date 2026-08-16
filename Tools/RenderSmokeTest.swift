import AppKit
import ImageIO

@main
struct RenderSmokeTest {
    static func main() throws {
        guard CommandLine.arguments.count == 3 || CommandLine.arguments.count == 4 else {
            fputs("Usage: render-smoke-test INPUT_IMAGE OUTPUT_JPEG [ITERATIONS]\n", stderr)
            exit(2)
        }

        let input = URL(fileURLWithPath: CommandLine.arguments[1])
        let output = URL(fileURLWithPath: CommandLine.arguments[2])
        let iterations = CommandLine.arguments.count == 4 ? max(1, Int(CommandLine.arguments[3]) ?? 1) : 1
        let photo = try PhotoAsset.load(from: input)
        fputs("Loaded source: \(Int(photo.pixelSize.width))×\(Int(photo.pixelSize.height))\n", stderr)
        var crop = CropState()
        crop.zoom = 1.35
        crop.pan = CGSize(width: 0.25, height: -0.2)
        var data = Data()
        for iteration in 1...iterations {
            data = try autoreleasepool {
                let rendered = try PrintRenderer.render(photo: photo, crop: crop)
                precondition(rendered.width == 1181)
                precondition(rendered.height == 1748)
                return try PrintRenderer.jpegData(from: rendered, quality: 0.95)
            }
            if iteration % 10 == 0 || iteration == iterations {
                fputs("Rendered \(iteration)/\(iterations)\n", stderr)
            }
        }
        try data.write(to: output, options: .atomic)
        guard let source = CGImageSourceCreateWithURL(output as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            throw StudioError.renderingFailed
        }
        precondition((properties[kCGImagePropertyPixelWidth] as? Int) == 1181)
        precondition((properties[kCGImagePropertyPixelHeight] as? Int) == 1748)
        precondition((properties[kCGImagePropertyDPIWidth] as? Int) == 300)
        precondition((properties[kCGImagePropertyDPIHeight] as? Int) == 300)
        print("PASS: \(iterations) render(s), 1181×1748 JPEG, 300 DPI, \(data.count) bytes")
    }
}
