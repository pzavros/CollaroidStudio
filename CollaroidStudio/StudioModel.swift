import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class StudioModel: ObservableObject {
    @Published private(set) var photo: PhotoAsset?
    @Published var crop = CropState()
    @Published private(set) var dogNumber = 1
    @Published private(set) var isWorking = false
    @Published var statusMessage = "Drop a photo to begin"
    @Published var presentedError: String?
    @Published var exportFolder: URL
    @Published var watchFolder: URL?
    @Published var watchEnabled: Bool
    @Published var jpegQuality: Double
    @Published var includeBorder: Bool
    @Published var adjustments = PhotoAdjustments() {
        didSet {
            refreshAdjustedPreview()
            if let photo {
                adjustmentsByPhoto[photo.sourceURL.standardizedFileURL] = adjustments
            }
        }
    }
    @Published private(set) var adjustedPreviewImage: NSImage?
    @Published private(set) var folderPhotos: [FolderPhotoItem] = []
    @Published private(set) var selectedFolderPhotoID: String?
    @Published private(set) var isRefreshingFolder = false
    @Published var photoBrowserPosition: PhotoBrowserPosition

    private let defaults = UserDefaults.standard
    private let watcher = FolderWatcher()
    private var folderRefreshTask: Task<Void, Never>?
    private var exportedPhotoKeys: Set<String>
    private var adjustmentsByPhoto: [URL: PhotoAdjustments] = [:]
    private var dragOrigin = CGSize.zero

    var hasPhoto: Bool { photo != nil }
    var hasAdjustments: Bool { !adjustments.isNeutral }
    var dogNumberText: String { String(format: "Dog #%03d", dogNumber) }
    var selectedFolderPhotoIndex: Int? {
        guard let selectedFolderPhotoID else { return nil }
        return folderPhotos.firstIndex { $0.id == selectedFolderPhotoID }
    }
    var canSelectPreviousFolderPhoto: Bool {
        guard let index = selectedFolderPhotoIndex else { return false }
        return index > 0
    }
    var canSelectNextFolderPhoto: Bool {
        guard let index = selectedFolderPhotoIndex else { return false }
        return index + 1 < folderPhotos.count
    }
    var folderStatusText: String {
        guard let watchFolder else { return "No photo folder selected" }
        let count = folderPhotos.count
        return "\(watchFolder.lastPathComponent)  •  \(count) photo\(count == 1 ? "" : "s")"
    }

    init() {
        Self.migrateLegacyDefaultsIfNeeded()
        let defaultExport = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Collaroid Dog Fest Prints", isDirectory: true)
        exportFolder = defaults.url(forKey: "exportFolder") ?? defaultExport
        watchFolder = defaults.url(forKey: "watchFolder")
        watchEnabled = defaults.bool(forKey: "watchEnabled")
        let savedQuality = defaults.double(forKey: "jpegQuality")
        jpegQuality = savedQuality == 0 ? 0.95 : savedQuality
        includeBorder = defaults.object(forKey: "includeBorder") as? Bool ?? true
        exportedPhotoKeys = Set(defaults.stringArray(forKey: "exportedPhotoKeys") ?? [])
        photoBrowserPosition = PhotoBrowserPosition(
            rawValue: defaults.string(forKey: "photoBrowserPosition") ?? ""
        ) ?? .left

        createExportFolderIfNeeded()
        refreshDogNumber()
        if watchFolder != nil { refreshFolder(selectFirstPhoto: true) }
        if watchEnabled { startWatching() }
    }

    private static func migrateLegacyDefaultsIfNeeded() {
        guard let legacy = UserDefaults(suiteName: "Collaroid Studio") else { return }
        let target = UserDefaults.standard

        for key in ["exportFolder", "watchFolder"] where target.object(forKey: key) == nil {
            if let url = legacy.url(forKey: key) {
                target.set(url, forKey: key)
            }
        }
        for key in ["watchEnabled", "jpegQuality", "includeBorder", "exportedPhotoKeys", "photoBrowserPosition"]
        where target.object(forKey: key) == nil {
            if let value = legacy.object(forKey: key) {
                target.set(value, forKey: key)
            }
        }
    }

    func choosePhoto() {
        let panel = NSOpenPanel()
        panel.title = "Add Dog Photo"
        panel.allowedContentTypes = [.jpeg, .png]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadPhoto(from: url)
    }

    func loadPhoto(from url: URL) {
        do {
            if let photo {
                adjustmentsByPhoto[photo.sourceURL.standardizedFileURL] = adjustments
            }
            let loadedPhoto = try PhotoAsset.load(from: url)
            photo = loadedPhoto
            crop.reset()
            adjustments = adjustmentsByPhoto[url.standardizedFileURL] ?? PhotoAdjustments()
            refreshAdjustedPreview()
            selectedFolderPhotoID = folderPhotos.first {
                $0.url.standardizedFileURL == url.standardizedFileURL
            }?.id
            statusMessage = url.lastPathComponent
            presentedError = nil
        } catch {
            presentedError = error.localizedDescription
        }
    }

    func beginDrag() { dragOrigin = crop.pan }

    func updateDrag(translation: CGSize, previewSize: CGSize) {
        guard let photo else { return }
        let coverScale = max(previewSize.width / photo.previewImage.size.width,
                             previewSize.height / photo.previewImage.size.height)
        let renderedWidth = photo.previewImage.size.width * coverScale * crop.zoom
        let renderedHeight = photo.previewImage.size.height * coverScale * crop.zoom
        let travelX = max(1, (renderedWidth - previewSize.width) / 2)
        let travelY = max(1, (renderedHeight - previewSize.height) / 2)
        crop.pan.width = min(1, max(-1, dragOrigin.width + translation.width / travelX))
        crop.pan.height = min(1, max(-1, dragOrigin.height + translation.height / travelY))
    }

    func zoomIn() { crop.adjustZoom(by: 1.12) }
    func zoomOut() { crop.adjustZoom(by: 1 / 1.12) }
    func setZoom(_ zoom: CGFloat) {
        crop.zoom = min(2.5, max(1, zoom))
    }

    func zoom(withScrollDelta delta: CGFloat, isPrecise: Bool) {
        guard abs(delta) > 0.01 else { return }
        let sensitivity: CGFloat = isPrecise ? 0.012 : 0.10
        let factor = CGFloat(exp(Double(delta * sensitivity)))
        setZoom(crop.zoom * factor)
    }

    func resetCrop() { crop.reset() }

    func resetAdjustments() {
        adjustments = PhotoAdjustments()
    }

    private func refreshAdjustedPreview() {
        guard let photo else {
            adjustedPreviewImage = nil
            return
        }
        adjustedPreviewImage = PhotoAdjustmentProcessor.previewImage(
            from: photo.previewImage,
            adjustments: adjustments
        )
    }

    func exportAndNext() {
        guard let photo, !isWorking else { return }
        isWorking = true
        statusMessage = "Rendering Dog #\(String(format: "%03d", dogNumber))…"
        let currentCrop = crop
        let currentAdjustments = adjustments
        let shouldIncludeBorder = includeBorder
        let folder = exportFolder
        let quality = jpegQuality
        let startingNumber = dogNumber
        let sourceURL = photo.sourceURL

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let image = try PrintRenderer.render(
                    photo: photo,
                    crop: currentCrop,
                    adjustments: currentAdjustments,
                    includeBorder: shouldIncludeBorder
                )
                let data = try PrintRenderer.jpegData(from: image, quality: quality)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                var number = startingNumber
                var destination = folder.appendingPathComponent(Self.filename(for: number))
                while FileManager.default.fileExists(atPath: destination.path) {
                    number += 1
                    destination = folder.appendingPathComponent(Self.filename(for: number))
                }
                try data.write(to: destination, options: .withoutOverwriting)
                await self?.finishExport(url: destination, number: number, sourceURL: sourceURL)
            } catch {
                await self?.fail(error)
            }
        }
    }

    func printCurrent() {
        guard let photo, !isWorking else { return }
        isWorking = true
        statusMessage = "Preparing print…"
        let currentCrop = crop
        let currentAdjustments = adjustments
        let shouldIncludeBorder = includeBorder
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let image = try PrintRenderer.render(
                    photo: photo,
                    crop: currentCrop,
                    adjustments: currentAdjustments,
                    includeBorder: shouldIncludeBorder
                )
                await self?.finishPrint(image)
            } catch {
                await self?.fail(error)
            }
        }
    }

    private func finishPrint(_ image: CGImage) {
        isWorking = false
        statusMessage = "Ready to print"
        PrintService.printImage(image)
    }

    func chooseExportFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Export Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = exportFolder
        guard panel.runModal() == .OK, let url = panel.url else { return }
        exportFolder = url
        defaults.set(url, forKey: "exportFolder")
        createExportFolderIfNeeded()
        refreshDogNumber()
    }

    func chooseWatchFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Incoming Photo Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        watchFolder = url
        defaults.set(url, forKey: "watchFolder")
        watcher.stop()
        refreshFolder(selectFirstPhoto: true)
        if watchEnabled { startWatching() }
    }

    func setWatchEnabled(_ enabled: Bool) {
        watchEnabled = enabled
        defaults.set(enabled, forKey: "watchEnabled")
        if enabled {
            startWatching()
            refreshFolder()
        } else {
            watcher.stop()
            statusMessage = folderStatusText
        }
    }

    func saveQuality() { defaults.set(jpegQuality, forKey: "jpegQuality") }

    func setIncludeBorder(_ enabled: Bool) {
        includeBorder = enabled
        defaults.set(enabled, forKey: "includeBorder")
        crop.reset()
    }

    func setPhotoBrowserPosition(_ position: PhotoBrowserPosition) {
        photoBrowserPosition = position
        defaults.set(position.rawValue, forKey: "photoBrowserPosition")
    }

    func refreshFolder(selectFirstPhoto: Bool = false) {
        guard let watchFolder else {
            folderPhotos = []
            selectedFolderPhotoID = nil
            return
        }

        folderRefreshTask?.cancel()
        isRefreshingFolder = true
        let exportedKeys = exportedPhotoKeys
        let previousSelection = selectedFolderPhotoID
        let shouldSelect = selectFirstPhoto || (photo == nil && previousSelection == nil)

        folderRefreshTask = Task { [weak self] in
            let scanned = await Task.detached(priority: .utility) {
                PhotoFolderScanner.scan(folder: watchFolder, exportedKeys: exportedKeys)
            }.value
            guard !Task.isCancelled, let self else { return }

            folderPhotos = scanned
            isRefreshingFolder = false

            if let previousSelection, scanned.contains(where: { $0.id == previousSelection }) {
                selectedFolderPhotoID = previousSelection
            } else {
                selectedFolderPhotoID = nil
                if shouldSelect, let first = scanned.first(where: { !$0.isExported }) ?? scanned.first {
                    selectFolderPhoto(first)
                    return
                }
            }
            statusMessage = folderStatusText
        }
    }

    func selectFolderPhoto(_ item: FolderPhotoItem) {
        loadPhoto(from: item.url)
    }

    func selectPreviousFolderPhoto() {
        guard let index = selectedFolderPhotoIndex, index > 0 else { return }
        selectFolderPhoto(folderPhotos[index - 1])
    }

    func selectNextFolderPhoto() {
        guard let index = selectedFolderPhotoIndex, index + 1 < folderPhotos.count else { return }
        selectFolderPhoto(folderPhotos[index + 1])
    }

    private func createExportFolderIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
        } catch {
            presentedError = StudioError.exportFolderUnavailable.localizedDescription
        }
    }

    private func refreshDogNumber() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: exportFolder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        let regex = try? NSRegularExpression(pattern: #"^collaroid-dogfest-(\d+)\.jpg$"#)
        dogNumber = urls.compactMap { url -> Int? in
            let name = url.lastPathComponent
            let range = NSRange(name.startIndex..., in: name)
            guard let match = regex?.firstMatch(in: name, range: range),
                  let numberRange = Range(match.range(at: 1), in: name) else { return nil }
            return Int(name[numberRange])
        }.max().map { $0 + 1 } ?? 1
    }

    private func startWatching() {
        guard watchEnabled, let watchFolder else { return }
        watcher.start(url: watchFolder) { [weak self] in
            Task { @MainActor [weak self] in
                self?.refreshFolder()
                try? await Task.sleep(for: .milliseconds(900))
                self?.refreshFolder()
            }
        }
        statusMessage = "Watching \(watchFolder.lastPathComponent) for new photos"
    }

    private func finishExport(url: URL, number: Int, sourceURL: URL) {
        isWorking = false
        crop.reset()
        dogNumber = number + 1
        let currentIndex = folderPhotos.firstIndex(where: {
            $0.url.standardizedFileURL == sourceURL.standardizedFileURL
        })
        markExported(sourceURL)

        let indicesAfterCurrent = currentIndex.map {
            Array(folderPhotos.indices.dropFirst($0 + 1)) + Array(folderPhotos.indices.prefix($0))
        } ?? Array(folderPhotos.indices)
        if let nextIndex = indicesAfterCurrent.first(where: { !folderPhotos[$0].isExported }) {
            selectFolderPhoto(folderPhotos[nextIndex])
            statusMessage = "Saved \(url.lastPathComponent)  •  Next photo ready"
        } else {
            photo = nil
            adjustedPreviewImage = nil
            selectedFolderPhotoID = nil
            statusMessage = "Saved \(url.lastPathComponent)  •  No unexported photos remaining"
        }
    }

    private func markExported(_ sourceURL: URL) {
        let key: String
        if let index = folderPhotos.firstIndex(where: {
            $0.url.standardizedFileURL == sourceURL.standardizedFileURL
        }) {
            key = folderPhotos[index].exportKey
            folderPhotos[index].isExported = true
        } else {
            key = PhotoFolderScanner.exportKey(for: sourceURL)
        }
        exportedPhotoKeys.insert(key)
        defaults.set(exportedPhotoKeys.sorted(), forKey: "exportedPhotoKeys")
    }

    private func fail(_ error: Error) {
        isWorking = false
        statusMessage = "Ready"
        presentedError = error.localizedDescription
    }

    nonisolated private static func filename(for number: Int) -> String {
        String(format: "collaroid-dogfest-%03d.jpg", number)
    }
}
