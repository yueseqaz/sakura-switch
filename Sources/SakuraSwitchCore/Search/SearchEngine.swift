import Foundation

/// A window with a search score and per-field matches for highlighting.
public struct SearchHit {
    public let window: WindowModel
    public let score: Int
    public let appMatch: FuzzyMatch?
    public let titleMatch: FuzzyMatch?
    /// The window is the remembered result for the current query.
    public let isMemoryPreferred: Bool
}

/// Combines fuzzy matching, field weighting, search memory and MRU order.
public enum SearchEngine {

    public static let memoryBoost = 10_000

    /// - Parameters:
    ///   - windows: expected to be in MRU order (index = MRU rank).
    ///   - query: raw user input (may be empty).
    public static func search(windows: [WindowModel],
                              query: String,
                              memory: SearchMemory,
                              fuzzyEnabled: Bool) -> [SearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return windows.map { SearchHit(window: $0, score: 0, appMatch: nil, titleMatch: nil, isMemoryPreferred: false) }
        }

        let preferredKey = memory.preferredKey(for: trimmed)
        let lowerQuery = trimmed.lowercased()

        struct Candidate {
            let hit: SearchHit
            let mruIndex: Int
        }

        var candidates: [Candidate] = []
        candidates.reserveCapacity(windows.count)

        for (mruIndex, window) in windows.enumerated() {
            var score = 0
            var appMatch: FuzzyMatch?
            var titleMatch: FuzzyMatch?
            var matched = false

            if fuzzyEnabled {
                // App name has the highest weight, window title second,
                // bundle ID is a tiebreaker.
                if let m = FuzzyMatcher.match(query: trimmed, target: window.appName) {
                    appMatch = m
                    score += m.score * 2
                    matched = true
                }
                if let m = FuzzyMatcher.match(query: trimmed, target: window.windowTitle) {
                    titleMatch = m
                    score += (m.score * 3) / 2
                    matched = true
                }
                if window.bundleID.lowercased().contains(lowerQuery) {
                    score += 30
                    matched = true
                } else if let m = FuzzyMatcher.match(query: trimmed, target: window.bundleID) {
                    score += m.score / 2
                    matched = true
                }
            } else {
                // Plain substring matching.
                let appHit = window.appName.lowercased().contains(lowerQuery)
                let titleHit = window.windowTitle.lowercased().contains(lowerQuery)
                let bundleHit = window.bundleID.lowercased().contains(lowerQuery)
                if appHit { score += 100; matched = true }
                if titleHit { score += 60; matched = true }
                if bundleHit { score += 20; matched = true }
            }

            guard matched else { continue }

            let isPreferred = preferredKey != nil && window.key == preferredKey!
            if isPreferred { score += memoryBoost }

            let hit = SearchHit(window: window,
                                score: score,
                                appMatch: appMatch,
                                titleMatch: titleMatch,
                                isMemoryPreferred: isPreferred)
            candidates.append(Candidate(hit: hit, mruIndex: mruIndex))
        }

        // Higher score first; equal scores keep MRU order (explicit tiebreak,
        // because Swift's sort is not stable).
        return candidates.sorted { a, b in
            if a.hit.score != b.hit.score { return a.hit.score > b.hit.score }
            return a.mruIndex < b.mruIndex
        }.map { $0.hit }
    }
}
