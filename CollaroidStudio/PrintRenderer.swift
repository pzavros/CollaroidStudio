import AppKit
import CoreImage
import CoreText
import ImageIO
import UniformTypeIdentifiers

struct PhotoAdjustments: Equatable {
    var shadows: Double = 0
    var highlights: Double = 0
    var saturation: Double = 0
    var warmth: Double = 0

    var isNeutral: Bool {
        shadows == 0 && highlights == 0 && saturation == 0 && warmth == 0
    }
}

enum PhotoAdjustmentProcessor {
    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let context = CIContext(options: [
        .cacheIntermediates: true,
        .workingColorSpace: colorSpace
    ])

    static func previewImage(from image: NSImage, adjustments: PhotoAdjustments) -> NSImage {
        guard !adjustments.isNeutral,
              let input = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }

        let output = apply(to: CIImage(cgImage: input), adjustments: adjustments)
        let representation = NSCIImageRep(ciImage: output)
        let adjusted = NSImage(size: representation.size)
        adjusted.addRepresentation(representation)
        return adjusted
    }

    static func renderedImage(from image: CGImage, adjustments: PhotoAdjustments) -> CGImage? {
        guard !adjustments.isNeutral else { return image }
        let input = CIImage(cgImage: image)
        let output = apply(to: input, adjustments: adjustments)
        return context.createCGImage(
            output,
            from: input.extent,
            format: .RGBA8,
            colorSpace: colorSpace
        )
    }

    private static func apply(to input: CIImage, adjustments: PhotoAdjustments) -> CIImage {
        var output = input

        if adjustments.shadows != 0 {
            output = applyShadowAdjustment(
                to: output,
                amount: adjustments.shadows / 100
            )
        }

        if adjustments.highlights != 0 {
            output = applyHighlightAdjustment(
                to: output,
                amount: adjustments.highlights / 100
            )
        }

        if adjustments.saturation != 0,
           let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(1 + adjustments.saturation / 100, forKey: kCIInputSaturationKey)
            output = filter.outputImage ?? output
        }

        if adjustments.warmth != 0,
           let filter = CIFilter(name: "CITemperatureAndTint") {
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            filter.setValue(
                CIVector(x: 6500 - adjustments.warmth * 35, y: 0),
                forKey: "inputTargetNeutral"
            )
            output = filter.outputImage ?? output
        }

        return output
    }

    /// Builds a feathered luminance mask for the lower tonal range, then blends an
    /// exposure-adjusted image through it. Pure black, midtones, and highlights are
    /// protected so the control behaves like a photographic Shadows adjustment
    /// instead of a global brightness change.
    private static func applyShadowAdjustment(to input: CIImage, amount: Double) -> CIImage {
        let shadowCurve = CIVector(x: 0, y: 8.666_667, z: -22, w: 13.333_333)
        return applyTonalAdjustment(
            to: input,
            amount: amount,
            positiveEVScale: 1.0,
            negativeEVScale: 1.2,
            maskCurve: shadowCurve
        )
    }

    /// Mirrors the shadow mask into the upper tonal range. It is strongest around
    /// 75% luminance, feathers through the midtones, and protects pure white so
    /// reducing Highlights does not turn the image's white point gray.
    private static func applyHighlightAdjustment(to input: CIImage, amount: Double) -> CIImage {
        let highlightCurve = CIVector(x: 0, y: -4.666_667, z: 18, w: -13.333_333)
        return applyTonalAdjustment(
            to: input,
            amount: amount,
            positiveEVScale: 0.8,
            negativeEVScale: 1.0,
            maskCurve: highlightCurve
        )
    }

    private static func applyTonalAdjustment(
        to input: CIImage,
        amount: Double,
        positiveEVScale: Double,
        negativeEVScale: Double,
        maskCurve: CIVector
    ) -> CIImage {
        guard let exposure = CIFilter(name: "CIExposureAdjust") else { return input }
        exposure.setValue(input, forKey: kCIInputImageKey)
        exposure.setValue(
            amount * (amount > 0 ? positiveEVScale : negativeEVScale),
            forKey: kCIInputEVKey
        )
        guard let adjusted = exposure.outputImage else { return input }

        guard let grayscale = CIFilter(name: "CIColorControls") else { return input }
        grayscale.setValue(input, forKey: kCIInputImageKey)
        grayscale.setValue(0, forKey: kCIInputSaturationKey)
        guard let luminance = grayscale.outputImage else { return input }

        guard let polynomial = CIFilter(name: "CIColorPolynomial") else { return input }
        polynomial.setValue(luminance, forKey: kCIInputImageKey)
        polynomial.setValue(maskCurve, forKey: "inputRedCoefficients")
        polynomial.setValue(maskCurve, forKey: "inputGreenCoefficients")
        polynomial.setValue(maskCurve, forKey: "inputBlueCoefficients")
        polynomial.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputAlphaCoefficients")
        guard let curvedMask = polynomial.outputImage else { return input }

        guard let clamp = CIFilter(name: "CIColorClamp") else { return input }
        clamp.setValue(curvedMask, forKey: kCIInputImageKey)
        clamp.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputMinComponents")
        clamp.setValue(CIVector(x: 1, y: 1, z: 1, w: 1), forKey: "inputMaxComponents")
        guard let mask = clamp.outputImage else { return input }

        guard let blend = CIFilter(name: "CIBlendWithMask") else { return input }
        blend.setValue(adjusted, forKey: kCIInputImageKey)
        blend.setValue(input, forKey: kCIInputBackgroundImageKey)
        blend.setValue(mask, forKey: kCIInputMaskImageKey)
        return blend.outputImage?.cropped(to: input.extent) ?? input
    }
}

enum BrandAssets {
    static var logo: NSImage? {
        if let url = Bundle.main.url(forResource: "collaroid-logo", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSImage(named: NSImage.Name("CollaroidLogo"))
    }
}

enum PrintRenderer {
    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    static func render(
        photo: PhotoAsset,
        crop: CropState,
        adjustments: PhotoAdjustments,
        includeBorder: Bool
    ) throws -> CGImage {
        let width = Int(PrintTemplate.pixelSize.width)
        let height = Int(PrintTemplate.pixelSize.height)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw StudioError.renderingFailed }

        context.setFillColor(CGColor.white)
        context.fill(CGRect(origin: .zero, size: PrintTemplate.pixelSize))

        let fullImage = try loadOriginalUpright(from: photo.sourceURL)

        let sourceSize = CGSize(width: fullImage.width, height: fullImage.height)
        let templatePhotoRect = PrintTemplate.photoRect(includeBorder: includeBorder)
        let sourceRect = crop.sourceRect(
            imageSize: sourceSize,
            targetAspect: PrintTemplate.photoAspect(includeBorder: includeBorder)
        )
        guard let cropped = fullImage.cropping(to: sourceRect),
              let adjusted = PhotoAdjustmentProcessor.renderedImage(
                from: cropped,
                adjustments: adjustments
              ) else {
            throw StudioError.renderingFailed
        }

        context.saveGState()
        context.interpolationQuality = .high
        let photoRect = CGRect(
            x: templatePhotoRect.minX,
            y: PrintTemplate.pixelSize.height - templatePhotoRect.maxY,
            width: templatePhotoRect.width,
            height: templatePhotoRect.height
        )
        context.draw(adjusted, in: photoRect)
        context.restoreGState()

        if includeBorder {
            drawBranding(in: context)
        }
        guard let result = context.makeImage() else { throw StudioError.renderingFailed }
        return result
    }

    /// Decodes the original image at its full pixel dimensions. ImageIO applies
    /// EXIF orientation during decoding, matching the transformed preview.
    private static func loadOriginalUpright(from url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            throw StudioError.unreadableImage
        }
        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
        guard width > 0, height > 0 else { throw StudioError.unreadableImage }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(width, height),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw StudioError.unreadableImage
        }
        return image
    }

    static func jpegData(from image: CGImage, quality: CGFloat) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { throw StudioError.renderingFailed }

        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: min(1, max(0.8, quality)),
            kCGImagePropertyDPIWidth: PrintTemplate.dpi,
            kCGImagePropertyDPIHeight: PrintTemplate.dpi,
            kCGImagePropertyProfileName: "sRGB IEC61966-2.1"
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw StudioError.renderingFailed }
        return data as Data
    }

    private static func drawBranding(in context: CGContext) {
        let logoY: CGFloat = 115
        if let logo = BrandAssets.logo,
           logo.size.width > 1,
           let cgLogo = logo.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let maxSize = CGSize(width: 540, height: 120)
            let scale = min(maxSize.width / CGFloat(cgLogo.width), maxSize.height / CGFloat(cgLogo.height))
            let logoSize = CGSize(width: CGFloat(cgLogo.width) * scale, height: CGFloat(cgLogo.height) * scale)
            let rect = CGRect(
                x: (PrintTemplate.pixelSize.width - logoSize.width) / 2,
                y: logoY,
                width: logoSize.width,
                height: logoSize.height
            )
            context.draw(cgLogo, in: rect)
        } else {
            drawText(
                "OFFICIAL LOGO REQUIRED",
                in: context,
                centerY: logoY + 42,
                font: .systemFont(ofSize: 24, weight: .semibold),
                color: NSColor(cgColor: PrintTemplate.orange) ?? .systemOrange,
                tracking: 2.0
            )
        }

        drawText(
            "DOG FEST 2026",
            in: context,
            centerY: 68,
            font: .systemFont(ofSize: 32, weight: .medium),
            color: NSColor(white: 0.20, alpha: 1),
            tracking: 7.5
        )
    }

    private static func drawText(
        _ text: String,
        in context: CGContext,
        centerY: CGFloat,
        font: NSFont,
        color: NSColor,
        tracking: CGFloat
    ) {
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .kern: tracking
            ]
        )
        let line = CTLineCreateWithAttributedString(attributed)
        let bounds = CTLineGetBoundsWithOptions(line, [.useOpticalBounds])
        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = CGPoint(
            x: (PrintTemplate.pixelSize.width - bounds.width) / 2 - bounds.minX,
            y: centerY - bounds.midY
        )
        CTLineDraw(line, context)
        context.restoreGState()
    }
}
