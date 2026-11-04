import Foundation

/// A small event-driven watcher per pane; coalesce bursts without polling folders.
final class DirectoryMonitor {
    private var source: DispatchSourceFileSystemObject?
    private var pendingRefresh: DispatchWorkItem?

    init(url: URL, onChange: @escaping () -> Void) {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: [.write, .delete, .rename], queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.pendingRefresh?.cancel()
            let refresh = DispatchWorkItem(block: onChange)
            self?.pendingRefresh = refresh
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: refresh)
        }
        source.setCancelHandler { close(descriptor) }
        self.source = source
        source.resume()
    }

    deinit {
        pendingRefresh?.cancel()
        source?.cancel()
    }
}
