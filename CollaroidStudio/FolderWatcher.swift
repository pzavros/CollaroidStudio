import Foundation

final class FolderWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: Int32 = -1
    private let queue = DispatchQueue(label: "studio.collaroid.folder-watcher", qos: .utility)

    func start(url: URL, onChange: @escaping @Sendable () -> Void) {
        stop()
        descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .rename],
            queue: queue
        )
        newSource.setEventHandler(handler: onChange)
        newSource.setCancelHandler { [descriptor] in close(descriptor) }
        source = newSource
        newSource.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
        descriptor = -1
    }

    deinit { stop() }
}
