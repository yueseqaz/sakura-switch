import Foundation

/// Tiny JSON persistence layer on top of Application Support.
/// No database dependency; files are written atomically.
public enum JSONFileStore {

    /// `~/Library/Application Support/SakuraSwitch`
    public static var appSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("SakuraSwitch", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public static func url(forFile fileName: String) -> URL {
        appSupportDirectory.appendingPathComponent(fileName)
    }

    public static func load<T: Decodable>(_ type: T.Type, fileName: String) -> T? {
        let url = url(forFile: fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            Log.settings.error("Failed to decode \(fileName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    @discardableResult
    public static func save<T: Encodable>(_ value: T, fileName: String) -> Bool {
        let url = url(forFile: fileName)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(value)
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            Log.settings.error("Failed to save \(fileName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
