import AppKit
import SakuraSwitchCore

/// Builds attributed strings with accent-colored matched characters.
/// `FuzzyMatch.matchedIndices` are UTF-16 offsets — directly usable as
/// NSAttributedString ranges (length 1 per matched unit).
enum MatchHighlight {

    static func attributed(_ text: String,
                           match: FuzzyMatch?,
                           base: NSColor,
                           emphasis: NSColor = DS.accent,
                           font: NSFont) -> NSAttributedString {
        let full = NSRange(location: 0, length: (text as NSString).length)
        let out = NSMutableAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: base,
        ])
        guard let match else { return out }
        for index in match.matchedIndices {
            let range = NSRange(location: index, length: 1)
            guard NSIntersectionRange(range, full).length == 1 else { continue }
            out.addAttribute(.foregroundColor, value: emphasis, range: range)
        }
        return out
    }
}
