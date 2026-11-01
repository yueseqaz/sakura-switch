import Foundation

/// Result of matching a query against a target string.
public struct FuzzyMatch: Equatable {
    /// Higher is better.
    public let score: Int
    /// UTF-16 offsets of matched characters in the *original* target string,
    /// used for highlight rendering.
    public let matchedIndices: [Int]
}

/// Fuzzy subsequence matcher.
///
/// - Matches query characters in order against the target (case-insensitive).
/// - Separators (space, `-`, `_`, `.`, `/`) in the target are transparent:
///   they can be skipped freely but boost the following character as a
///   word boundary. This makes first-letter abbreviations work:
///   `vs` → "Visual Studio Code".
/// - Scoring (fzf-style):
///   - base match +16
///   - word-boundary bonus +14, first-character bonus +10
///   - consecutive bonus +8
///   - gap penalty −1 per skipped character (capped)
public enum FuzzyMatcher {

    public static let separatorCharacters: Set<Character> = [" ", "-", "_", ".", "/", "·", "　"]

    public static func match(query: String, target: String) -> FuzzyMatch? {
        let q = Array(query.lowercased().unicodeScalars)
        guard !q.isEmpty else { return nil }

        // Normalize target: lowercase scalars, dropping separators,
        // remembering the original UTF-16 index of each kept scalar and
        // whether it starts a word.
        var chars: [Unicode.Scalar] = []
        var originalIndices: [Int] = []
        var wordStarts: [Bool] = []
        var prevWasSeparator = true
        var utf16Offset = 0
        for scalar in target.unicodeScalars {
            let width = String(scalar).utf16.count
            let isSeparator = separatorCharacters.contains(Character(String(scalar)))
            if isSeparator {
                prevWasSeparator = true
            } else {
                let lowered = String(scalar).lowercased()
                chars.append(lowered.unicodeScalars.first ?? scalar)
                originalIndices.append(utf16Offset)
                wordStarts.append(prevWasSeparator)
                prevWasSeparator = false
            }
            utf16Offset += width
        }

        let n = chars.count
        let m = q.count
        guard n >= m else { return nil }

        // dp[i][j] = best score matching the first i query chars where the
        // i-th match lands exactly on target index j. -1 = unreachable.
        // parent[i][j] = the j' used for dp[i-1][j'] for backtracking.
        var dp = [[Int]](repeating: [Int](repeating: -1, count: n), count: m + 1)
        var parent = [[Int]](repeating: [Int](repeating: -1, count: n), count: m + 1)

        // Base case: matching query[0] anywhere.
        for j in 0..<n {
            guard chars[j] == q[0] else { continue }
            var s = 16
            if wordStarts[j] { s += 14 }
            if j == 0 { s += 10 }
            dp[1][j] = s
        }

        // Recurrence.
        if m > 1 {
            for i in 2...m {
                let c = q[i - 1]
                var bestPrev = -1
                var bestPrevScore = -1
                for j in 0..<n {
                    // Before considering j as a match for q[i-1], update the
                    // running best from dp[i-1][0..<j].
                    let prev = dp[i - 1][j]
                    if prev > bestPrevScore {
                        bestPrevScore = prev
                        bestPrev = j
                    }
                    guard chars[j] == c, bestPrevScore >= 0 else { continue }
                    var s = bestPrevScore + 16
                    // Consecutive match bonus (only if directly following).
                    if bestPrev == j - 1 { s += 8 }
                    if wordStarts[j] { s += 14 }
                    // Gap penalty, capped so long ranges stay viable.
                    let gap = j - bestPrev - 1
                    if gap > 0 { s -= min(gap, 8) }
                    dp[i][j] = s
                    parent[i][j] = bestPrev
                }
            }
        }

        // Find the best ending point for the full query.
        var bestEnd = -1
        var bestScore = -1
        for j in 0..<n where dp[m][j] > bestScore {
            bestScore = dp[m][j]
            bestEnd = j
        }
        guard bestEnd >= 0 else { return nil }

        // Backtrack to collect matched indices.
        var indices = [Int](repeating: 0, count: m)
        var j = bestEnd
        var i = m
        while i >= 1 {
            indices[i - 1] = originalIndices[j]
            let p = parent[i][j]
            i -= 1
            if i >= 1 {
                j = p >= 0 ? p : j
            }
        }

        return FuzzyMatch(score: bestScore, matchedIndices: indices.sorted())
    }
}
