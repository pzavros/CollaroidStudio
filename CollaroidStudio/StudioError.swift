import Foundation

enum StudioError: LocalizedError {
    case unsupportedImage
    case unreadableImage
    case noPhoto
    case renderingFailed
    case exportFolderUnavailable

    var errorDescription: String? {
        switch self {
        case .unsupportedImage: "Please choose a JPG, JPEG, or PNG image."
        case .unreadableImage: "The image could not be read. It may still be copying or may be damaged."
        case .noPhoto: "Add a photo first."
        case .renderingFailed: "The print image could not be rendered."
        case .exportFolderUnavailable: "The export folder is unavailable. Choose another folder in Settings."
        }
    }
}
