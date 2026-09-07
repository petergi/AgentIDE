import Foundation
import Synchronization

/// Which entry of a worktree's stack the panes are looking at,
/// remembered per worktree so moving between the review and pull
/// request tabs keeps the same branch in view.
public enum StackSelection {
    // MARK: Public

    /// Where remembered entries are stored; tests inject a memory
    /// store, production uses UserDefaults.
    public static var store: any PreferenceStoring {
        get { storeState.withLock { $0 } }
        set { storeState.withLock { $0 = newValue } }
    }

    /// The remembered entry, nil when none was chosen yet.
    public static func branch(for worktreePath: String) -> String? {
        store.string(forKey: key(worktreePath))
    }

    /// Remembers an entry; nil forgets it.
    public static func remember(_ branch: String?, for worktreePath: String) {
        store.set(branch, forKey: key(worktreePath))
    }

    // MARK: Private

    private static let storeState: Mutex<any PreferenceStoring> = .init(UserDefaultsPreferences())

    private static func key(_ worktreePath: String) -> String {
        "stackSelection#" + worktreePath
    }
}
