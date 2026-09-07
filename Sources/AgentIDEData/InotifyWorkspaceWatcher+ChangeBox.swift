#if os(Linux)
    import Foundation
    import Synchronization

    /// Holds the last-seen mtimes and the set of changed paths.
    extension InotifyWorkspaceWatcher {
        final class ChangeBox: @unchecked Sendable {
            // MARK: Lifecycle

            init(roots: [String]) {
                self.roots = roots
            }

            deinit {
                // The poll timer lives on the watcher.
            }

            // MARK: Internal

            let roots: [String]
            let changed: Mutex<Set<String>> = .init([])

            func snapshotMtimes() {
                mtimes.withLock { held in
                    held = Self.currentMtimes(roots: roots)
                }
            }

            func scan() {
                let next = Self.currentMtimes(roots: roots)
                let previous = mtimes.withLock { held -> [String: Date] in
                    let prior = held
                    held = next
                    return prior
                }
                var found = Set<String>()
                for (path, date) in next where previous[path] != date {
                    found.insert(path)
                }
                for path in previous.keys where next[path] == nil {
                    found.insert(path)
                }
                guard found.isEmpty == false else {
                    return
                }

                changed.withLock { $0.formUnion(found) }
            }

            // MARK: Private

            private let mtimes: Mutex<[String: Date]> = .init([:])

            private static func currentMtimes(roots: [String]) -> [String: Date] {
                var result = [String: Date]()
                let manager = FileManager.default
                for root in roots {
                    guard let values = try? manager.attributesOfItem(atPath: root),
                          let date = values[.modificationDate] as? Date
                    else {
                        continue
                    }

                    result[root] = date
                    guard let children = try? manager.contentsOfDirectory(atPath: root) else {
                        continue
                    }

                    for name in children {
                        let path = root + "/" + name
                        guard let childValues = try? manager.attributesOfItem(atPath: path),
                              let childDate = childValues[.modificationDate] as? Date
                        else {
                            continue
                        }

                        result[path] = childDate
                    }
                }
                return result
            }
        }
    }
#endif
