import Foundation

// MARK: - PreferenceStoring

/// Persistent key-value preferences without naming UserDefaults at
/// every call site, so Domain stays free of Foundation preference
/// APIs and tests can inject a memory store.
public protocol PreferenceStoring: Sendable {
    /// The string stored under `key`, or nil when absent.
    func string(forKey key: String) -> String?

    /// Stores `value` under `key`; nil forgets it.
    func set(_ value: String?, forKey key: String)
}

// MARK: - UserDefaultsPreferences

/// Preferences backed by `UserDefaults.standard`.
public struct UserDefaultsPreferences: PreferenceStoring {
    // MARK: Lifecycle

    public init() {
        // Uses UserDefaults.standard.
    }

    // MARK: Public

    public func string(forKey key: String) -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    public func set(_ value: String?, forKey key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
