//
//  AppFolderWatcher.swift
//  Inlet
//
//  Watches the app folders with FSEvents, so an app that is installed,
//  removed or renamed shows up in the grid without a relaunch.
//  FSEvents batches changes: `latency` is the quiet time it waits before
//  reporting, which is also the debounce for a big install.
//

import CoreServices
import Foundation

@MainActor
final class AppFolderWatcher {
    /// Seconds FSEvents waits after a change before it reports it. Batches
    /// the many file writes of one install into a single rescan.
    static let latency: CFTimeInterval = 1.0

    private let paths: [String]
    private let onChange: @MainActor () -> Void
    private var stream: FSEventStreamRef?

    /// - Parameters:
    ///   - paths: Folders to watch. Missing folders are skipped.
    ///   - onChange: Runs on the main actor when an app-level change is seen.
    init(paths: [String], onChange: @escaping @MainActor () -> Void) {
        self.paths = paths
        self.onChange = onChange
    }

    /// Starts watching. Safe to call more than once; only the first call does anything.
    func start() {
        guard stream == nil, !paths.isEmpty else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        // FileEvents: report each file, not just each folder, so a new .app is seen.
        // UseCFTypes: the callback receives a CFArray of path strings.
        let flags = UInt32(
            kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagUseCFTypes
                | kFSEventStreamCreateFlagNoDefer
        )
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            appFolderEventCallback,
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            Self.latency,
            flags
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    /// Stops watching and releases the stream.
    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    /// True when a changed path could mean an app was added, removed or renamed.
    /// Changes inside a bundle (its Contents folder, for example, while an app
    /// updates itself) don't change the app list, so they are ignored. The
    /// bundle's own path still reports the install or removal.
    nonisolated static func isRelevant(_ path: String) -> Bool {
        !path.contains(".app/")
    }
}

/// C callback for FSEvents. FSEvents delivers it on the main queue (see
/// `AppFolderWatcher.start()`). It is a plain function, not a closure, because
/// FSEvents needs a C function pointer.
private func appFolderEventCallback(
    _ stream: ConstFSEventStreamRef,
    _ info: UnsafeMutableRawPointer?,
    _ count: Int,
    _ eventPaths: UnsafeMutableRawPointer,
    _ flags: UnsafePointer<FSEventStreamEventFlags>,
    _ ids: UnsafePointer<FSEventStreamEventId>
) {
    guard let info else { return }
    let watcher = Unmanaged<AppFolderWatcher>.fromOpaque(info).takeUnretainedValue()
    let changed = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as? [String] ?? []
    guard changed.contains(where: AppFolderWatcher.isRelevant) else { return }
    MainActor.assumeIsolated {
        watcher.onChange()
    }
}
