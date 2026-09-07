#if os(Linux)
    import Foundation

    /// Reads battery state from sysfs (the shape UPower exposes under
    /// `/sys/class/power_supply`). True while any battery supply is
    /// discharging.
    public struct UPowerSource: PowerObserving {
        // MARK: Lifecycle

        public init() {
            // Defers to sysfs on each read.
        }

        // MARK: Public

        public var isOnBattery: Bool {
            Self.isDischarging()
        }

        // MARK: Private

        private static let supplyRoot = "/sys/class/power_supply"

        private static func isDischarging() -> Bool {
            let manager = FileManager.default
            guard let names = try? manager.contentsOfDirectory(atPath: supplyRoot) else {
                return false
            }

            for name in names {
                let base = supplyRoot + "/" + name
                let type = (try? String(contentsOfFile: base + "/type", encoding: .utf8))?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let status = (try? String(contentsOfFile: base + "/status", encoding: .utf8))?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if type == "Battery", status == "Discharging" {
                    return true
                }

                // Some kernels expose only status; treat Discharging
                // there as on-battery too.
                if type == nil, status == "Discharging" {
                    return true
                }
            }
            return false
        }
    }
#endif
