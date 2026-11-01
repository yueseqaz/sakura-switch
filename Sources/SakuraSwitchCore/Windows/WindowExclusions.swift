import Foundation

/// Exclusion list filtering by bundle ID.
public enum WindowExclusions {

    /// Validate a user-entered bundle ID (at least "tld.app" shape).
    public static func isValid(bundleID: String) -> Bool {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // Allowed: letters, digits, hyphen, underscore, dot-separated segments.
        let pattern = "^[A-Za-z0-9_-]+(\\.[A-Za-z0-9_-]+)+$"
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    public static func isExcluded(bundleID: String, list: Set<String>) -> Bool {
        list.contains(bundleID)
    }

    /// Remove excluded windows; keeps input order.
    public static func filter(_ windows: [WindowModel], excluding list: Set<String>) -> [WindowModel] {
        windows.filter { !list.contains($0.bundleID) }
    }
}
