#if os(Linux)
    import Foundation
    import Synchronization

    /// A Linux stand-in for FSEvents: polls root modification times
    /// on a dispatch timer. Full inotify watches can replace this
    /// later without changing `FileWatching` call sites.
    public final class InotifyWorkspaceWatcher: FileWatching, Sendable {
        // MARK: Lifecycle

        /// Creates a watcher over some root directories.
        public init(roots: [String]) {
            self.roots = roots
            box = ChangeBox(roots: roots)
        }

        deinit {
            source.withLock { timer in
                timer?.cancel()
                timer = nil
            }
        }

        // MARK: Public

        /// Whether the poll timer is running; false answers every
        /// question with "assume changed".
        public var isWatching: Bool {
            watching.withLock { $0 }
        }

        /// Starts polling; safe to call more than once.
        public func start() {
            guard started.withLock({ let was = $0; $0 = true; return was }) == false else {
                return
            }

            box.snapshotMtimes()
            let timer = DispatchSource.makeTimerSource(queue: Self.queue)
            timer.schedule(deadline: .now() + Self.interval, repeating: Self.interval)
            timer.setEventHandler { [box] in
                box.scan()
            }
            timer.resume()
            source.withLock { $0 = timer }
            watching.withLock { $0 = true }
        }

        /// The directories changed since last asked, cleared by the
        /// asking.
        public func consumeChangedPaths() -> Set<String> {
            box.changed.withLock { changed in
                let consumed = changed
                changed = []
                return consumed
            }
        }

        // MARK: Private

        /// How often roots are re-stat'd while a full inotify
        /// implementation is still pending.
        private static let pollIntervalSeconds = 2
        private static let interval: DispatchTimeInterval = .seconds(pollIntervalSeconds)

        private static let queue: DispatchQueue = .init(label: "agentide.inotify-poll")

        private let roots: [String]
        private let box: ChangeBox
        private let started: Mutex<Bool> = .init(false)
        private let watching: Mutex<Bool> = .init(false)
        private let source: Mutex<(any DispatchSourceTimer)?> = .init(nil)
    }
#endif
