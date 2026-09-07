/// The shared poll and reconcile loop that Mac SwiftUI and a future
/// Linux UI both drive. Phase 0 owns refresh coalescing; later
/// phases move more of `DashboardModel`'s reconcile work here.
/// Depends on Domain and Data at the package level so those layers
/// can move into the runtime without reshaping the target graph.
@preconcurrency
@MainActor
public final class AgentIDERuntime {
    // MARK: Lifecycle

    /// Creates a runtime with a fresh refresh coalescer.
    public init(refresh: RefreshCoalescer = RefreshCoalescer()) {
        self.refresh = refresh
    }

    deinit {
        // Owned by the dashboard for the life of the window.
    }

    // MARK: Public

    /// Joinable refresh queue shared by every caller that wants a
    /// fresh reading of the system.
    public let refresh: RefreshCoalescer
}
