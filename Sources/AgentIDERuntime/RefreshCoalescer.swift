/// The joinable refresh queue: at most one reading runs and one
/// waits, so the poll, a launch's listing retries and an action's
/// refresh share one reading rather than stacking. Owned by
/// `AgentIDERuntime` so Mac SwiftUI and a future Linux UI share the
/// same coalesce shape.
@preconcurrency
@MainActor
public final class RefreshCoalescer {
    // MARK: Lifecycle

    /// Creates an empty coalescer with nothing running or queued.
    public init() {
        // Fields start empty; the first refresh fills them.
    }

    deinit {
        // Tasks are cancelled by their owners when the runtime goes.
    }

    // MARK: Public

    /// The newest reading (running or queued).
    public var refreshTask: Task<Void, Never>?

    /// The queued follow-up while one is joinable.
    public var queuedRefresh: Task<Void, Never>?

    /// Repositories queued to be forced on the next reading.
    public var pendingForces: Set<String> = []

    /// Whether the next reading asks herdr for its pane listing.
    /// True at launch, since nothing has been listed yet.
    public var pendingPaneRead = true

    /// Records a repository that the next reading must ask about
    /// in full.
    public func force(_ repositoryPath: String?) {
        if let repositoryPath {
            pendingForces.insert(repositoryPath)
        }
    }

    /// Asks the next reading to refresh herdr's pane listing.
    public func requestPaneRead() {
        pendingPaneRead = true
    }

    /// Takes and clears the forced repositories.
    public func takeForces() -> Set<String> {
        let forces = pendingForces
        pendingForces = []
        return forces
    }

    /// Whether this reading should ask herdr, clearing the pending
    /// flag. `due` is true when the listing's safety interval has
    /// passed.
    public func takePaneRead(due: Bool) -> Bool {
        let reads = pendingPaneRead || due
        pendingPaneRead = false
        return reads
    }
}
