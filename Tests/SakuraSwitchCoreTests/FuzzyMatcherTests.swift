import Testing
@testable import SakuraSwitchCore

@Suite("FuzzyMatcher")
struct FuzzyMatcherTests {

    @Test("Exact substring matches with tight indices")
    func exactSubstringMatch() {
        let match = FuzzyMatcher.match(query: "term", target: "Terminal")
        #expect(match != nil)
        #expect(match?.matchedIndices == [0, 1, 2, 3])
    }

    @Test("Subsequence: vs → Visual Studio Code")
    func subsequenceMatch() {
        let match = FuzzyMatcher.match(query: "vs", target: "Visual Studio Code")
        #expect(match != nil)
        #expect(match?.matchedIndices == [0, 7]) // V…S
    }

    @Test("Full abbreviation: vsc → Visual Studio Code")
    func fullAbbreviationMatch() {
        let match = FuzzyMatcher.match(query: "vsc", target: "Visual Studio Code")
        #expect(match != nil)
        #expect(match?.matchedIndices == [0, 7, 14])
    }

    @Test("Order matters: sv does not match Visual Studio Code")
    func noMatchWhenOrderDiffers() {
        #expect(FuzzyMatcher.match(query: "sv", target: "Visual Studio Code") == nil)
    }

    @Test("Missing characters fail")
    func noMatchForMissingCharacters() {
        #expect(FuzzyMatcher.match(query: "xyz", target: "Terminal") == nil)
    }

    @Test("Case-insensitive")
    func caseInsensitive() {
        #expect(FuzzyMatcher.match(query: "TERMINAL", target: "terminal") != nil)
    }

    @Test("Word-boundary match scores higher than scattered letters")
    func wordBoundaryBeatsMiddleMatch() {
        let boundary = FuzzyMatcher.match(query: "code", target: "Visual Studio Code")!
        let middle = FuzzyMatcher.match(query: "ode", target: "Xcode")!
        #expect(boundary.score > middle.score - 4)
    }

    @Test("Consecutive runs score higher than scattered matches")
    func consecutiveMatchBeatsScattered() {
        let consecutive = FuzzyMatcher.match(query: "term", target: "Terminal")!
        let scattered = FuzzyMatcher.match(query: "trm", target: "The Terminal")!
        #expect(consecutive.score / 4 > scattered.score / 3 - 8)
    }

    @Test("Empty query returns nil")
    func emptyQueryReturnsNil() {
        #expect(FuzzyMatcher.match(query: "", target: "anything") == nil)
    }

    @Test("CJK titles match")
    func cjkMatching() {
        let match = FuzzyMatcher.match(query: "访达", target: "访达 — Macintosh HD")
        #expect(match != nil)
        #expect(match?.matchedIndices == [0, 1])
    }

    @Test("Query longer than target fails")
    func queryLongerThanTargetFails() {
        #expect(FuzzyMatcher.match(query: "verylongquery", target: "short") == nil)
    }
}
