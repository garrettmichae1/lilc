import Foundation

enum LessonWin: Equatable, Sendable {
    case contains(String, ignoreCase: Bool)
    case exact(String)
    case printsNumber
    case lines([String])
    case anyContains([String], ignoreCase: Bool)
    case producedOutput

    func matches(output: String) -> Bool {
        let text = Self.scoringText(output)
        switch self {
        case .contains(let needle, let ignoreCase):
            if ignoreCase {
                return text.lowercased().contains(needle.lowercased())
            }
            return text.contains(needle)
        case .exact(let expected):
            return Self.normalizeExact(text) == Self.normalizeExact(expected)
        case .printsNumber:
            return text.range(of: #"\d"#, options: .regularExpression) != nil
        case .lines(let want):
            let got = Self.trimmedLines(text)
            return got == want
        case .anyContains(let needles, let ignoreCase):
            let haystack = ignoreCase ? text.lowercased() : text
            return needles.contains { needle in
                haystack.contains(ignoreCase ? needle.lowercased() : needle)
            }
        case .producedOutput:
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// Stdout used for scoring, without runner chrome.
    static func scoringText(_ output: String) -> String {
        output
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "Program finished.", with: "")
            .replacingOccurrences(of: "\n\nNice.", with: "\n")
            .replacingOccurrences(of: "Nice.\n", with: "")
    }

    private static func normalizeExact(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .newlines)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func trimmedLines(_ text: String) -> [String] {
        let trimmed = scoringText(text).trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }
        return trimmed.split(separator: "\n", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }
}

enum LessonWinChecker {
    static func passes(lesson: FirstHourLesson, output: String, source: String) -> Bool {
        if source.contains("???") { return false }
        for needle in lesson.requireSource where !source.contains(needle) {
            return false
        }
        if !lesson.requireAnySource.isEmpty,
           !lesson.requireAnySource.contains(where: { source.contains($0) }) {
            return false
        }
        return lesson.win.matches(output: output)
    }

    static func notYetLine(for lesson: FirstHourLesson) -> String {
        "Not yet. The program must print \(lesson.printHint)."
    }

    static func completeTheTaskMessage(for lesson: FirstHourLesson) -> String {
        let kind = lesson.track == .challenge ? "challenge" : "lesson"
        return """
        Complete this \(kind).

        Replace ??? with C code, then press RUN.

        The program must print \(lesson.printHint).
        """
    }

    static let replacePlaceholderMessage = "Replace ??? with C code, then press RUN.\n"

    static func firstPlaceholderJump(in file: LocalCFile) -> CErrorJump? {
        guard let range = file.code.range(of: "???") else { return nil }
        let before = file.code[..<range.lowerBound]
        let line = before.reduce(into: 1) { count, character in
            if character == "\n" { count += 1 }
        }
        let column = (before.split(separator: "\n", omittingEmptySubsequences: false).last?.count ?? 0) + 1
        return CErrorJump(fileID: file.id, line: line, column: max(column, 1))
    }

    static func appendingNotYet(to output: String, lesson: FirstHourLesson) -> String {
        let line = notYetLine(for: lesson)
        if output.contains(line) { return output }
        let prefix = output.isEmpty || output.hasSuffix("\n") ? output : output + "\n"
        return prefix + line + "\n"
    }
}
