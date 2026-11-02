import Foundation

/// Application groups retain the order of their first window in the MRU list.
public struct ApplicationWindowGroup: Identifiable {
    public let id: String
    public var windows: [WindowModel]

    public static func applicationID(for window: WindowModel) -> String {
        window.bundleID.isEmpty ? "pid:\(window.pid)" : window.bundleID
    }

    public static func group(_ windows: [WindowModel]) -> [ApplicationWindowGroup] {
        var groups: [ApplicationWindowGroup] = []
        var indices: [String: Int] = [:]
        for window in windows {
            let id = applicationID(for: window)
            if let index = indices[id] {
                groups[index].windows.append(window)
            } else {
                indices[id] = groups.count
                groups.append(ApplicationWindowGroup(id: id, windows: [window]))
            }
        }
        return groups
    }
}
