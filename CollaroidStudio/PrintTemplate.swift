import CoreGraphics

enum PrintTemplate {
    static let pixelSize = CGSize(width: 1181, height: 1748)
    static let dpi = 300
    static let sideMargin: CGFloat = 54
    static let topMargin: CGFloat = 54
    static let photoHeight: CGFloat = 1422
    static let photoRect = CGRect(
        x: sideMargin,
        y: topMargin,
        width: pixelSize.width - sideMargin * 2,
        height: photoHeight
    )
    static let fullBleedPhotoRect = CGRect(origin: .zero, size: pixelSize)
    static let photoAspect = photoRect.width / photoRect.height
    static let orange = CGColor(srgbRed: 1.0, green: 0.36, blue: 0.12, alpha: 1.0)

    static func photoRect(includeBorder: Bool) -> CGRect {
        includeBorder ? photoRect : fullBleedPhotoRect
    }

    static func photoAspect(includeBorder: Bool) -> CGFloat {
        let rect = photoRect(includeBorder: includeBorder)
        return rect.width / rect.height
    }
}

struct CropState: Equatable {
    var zoom: CGFloat = 1
    var pan = CGSize.zero

    mutating func reset() {
        zoom = 1
        pan = .zero
    }

    mutating func adjustZoom(by factor: CGFloat) {
        zoom = min(2.5, max(1, zoom * factor))
    }

    func sourceRect(imageSize: CGSize, targetAspect: CGFloat) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }

        let sourceAspect = imageSize.width / imageSize.height
        let baseWidth: CGFloat
        let baseHeight: CGFloat
        if sourceAspect > targetAspect {
            baseHeight = imageSize.height
            baseWidth = baseHeight * targetAspect
        } else {
            baseWidth = imageSize.width
            baseHeight = baseWidth / targetAspect
        }

        let visibleWidth = baseWidth / zoom
        let visibleHeight = baseHeight / zoom
        let horizontalTravel = imageSize.width - visibleWidth
        let verticalTravel = imageSize.height - visibleHeight
        let x = horizontalTravel * (1 - min(1, max(-1, pan.width))) / 2
        let y = verticalTravel * (1 - min(1, max(-1, pan.height))) / 2

        return CGRect(x: x, y: y, width: visibleWidth, height: visibleHeight).integral
    }
}
