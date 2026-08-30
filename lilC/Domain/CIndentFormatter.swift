import Foundation

enum CIndentFormatter {
    static let spacesPerIndent = 4

    struct Result: Equatable {
        var text: String
        var caretUTF16: Int
    }

    static func format(_ source: String) -> String {
        formatKeepingCaret(source, caretUTF16: 0).text
    }

    static func formatKeepingCaret(_ source: String, caretUTF16: Int = 0) -> Result {
        let pieces = splitLines(source)
        guard !pieces.isEmpty else {
            return Result(text: source, caretUTF16: 0)
        }

        let caret = locateCaret(caretUTF16, in: pieces)
        var mode = ScanMode.code
        var braceDepth = 0
        var hang = 0
        var preprocessorContinues = false
        var formatted: [(body: String, ending: String)] = []
        formatted.reserveCapacity(pieces.count)

        for piece in pieces {
            let facts = scanLine(piece.body, mode: &mode)
            var indentLevel = braceDepth

            if facts.isPreprocessor || preprocessorContinues {
                indentLevel = 0
            } else if facts.isOpenBraceOnly {
                hang = 0
                indentLevel = braceDepth
            } else if facts.startsWithCloseBrace {
                indentLevel = max(0, braceDepth - 1)
            } else if facts.isLabel {
                indentLevel = max(0, braceDepth - 1)
            }

            if !facts.isPreprocessor && !preprocessorContinues && !facts.isOpenBraceOnly {
                indentLevel += hang
            }

            let content = trimTrailingWhitespace(stripLeadingWhitespace(facts.displayBody))
            let body: String
            if content.isEmpty {
                body = ""
            } else if facts.isPreprocessor || preprocessorContinues {
                body = content
            } else {
                body = String(repeating: " ", count: indentLevel * spacesPerIndent) + content
            }
            formatted.append((body, piece.ending))

            if facts.isPreprocessor {
                hang = 0
                preprocessorContinues = facts.endsWithBackslash
            } else if preprocessorContinues {
                preprocessorContinues = facts.endsWithBackslash
            } else if facts.isOpenBraceOnly {
                hang = 0
            } else if facts.isHangOpener {
                hang += 1
            } else if hang > 0 {
                hang = 0
            }

            if !facts.isPreprocessor {
                braceDepth = max(0, braceDepth + facts.braceDelta)
            }
        }

        let text = formatted.map { $0.body + $0.ending }.joined()
        let restored = restoreCaret(caret, in: formatted)
        return Result(text: text, caretUTF16: restored)
    }

    private struct LinePiece {
        var body: String
        var ending: String
    }

    private struct LineFacts {
        var displayBody: String
        var stripped: String
        var braceDelta: Int
        var startsWithCloseBrace: Bool
        var isOpenBraceOnly: Bool
        var isPreprocessor: Bool
        var isLabel: Bool
        var isHangOpener: Bool
        var endsWithBackslash: Bool
    }

    private enum ScanMode {
        case code
        case string
        case charLit
        case blockComment
    }

    private static func splitLines(_ source: String) -> [LinePiece] {
        let ns = source as NSString
        var pieces: [LinePiece] = []
        var start = 0
        var index = 0
        let length = ns.length
        while index < length {
            let unit = ns.character(at: index)
            if unit == 13 {
                let body = ns.substring(with: NSRange(location: start, length: index - start))
                if index + 1 < length, ns.character(at: index + 1) == 10 {
                    pieces.append(LinePiece(body: body, ending: ns.substring(with: NSRange(location: index, length: 2))))
                    index += 2
                } else {
                    pieces.append(LinePiece(body: body, ending: ns.substring(with: NSRange(location: index, length: 1))))
                    index += 1
                }
                start = index
            } else if unit == 10 {
                pieces.append(LinePiece(
                    body: ns.substring(with: NSRange(location: start, length: index - start)),
                    ending: ns.substring(with: NSRange(location: index, length: 1))
                ))
                index += 1
                start = index
            } else {
                index += 1
            }
        }
        if start < length || pieces.isEmpty && length == 0 {
            if start < length {
                pieces.append(LinePiece(body: ns.substring(from: start), ending: ""))
            }
        }
        return pieces
    }

    private static func scanLine(_ body: String, mode: inout ScanMode) -> LineFacts {
        var stripped: [Character] = []
        var display: [Character] = []
        var braceDelta = 0
        var firstCode: Character?
        var i = body.startIndex
        let startedInBlockComment = mode == .blockComment

        while i < body.endIndex {
            let character = body[i]
            let nextIndex = body.index(after: i)
            let next = nextIndex < body.endIndex ? body[nextIndex] : nil

            switch mode {
            case .blockComment:
                display.append(character)
                if character == "*" && next == "/" {
                    display.append("/")
                    mode = .code
                    i = nextIndex
                }
            case .string:
                display.append(character)
                if character == "\\" {
                    if let next {
                        display.append(next)
                        i = nextIndex
                    }
                } else if character == "\"" {
                    mode = .code
                }
            case .charLit:
                display.append(character)
                if character == "\\" {
                    if let next {
                        display.append(next)
                        i = nextIndex
                    }
                } else if character == "'" {
                    mode = .code
                }
            case .code:
                if character == "/" && next == "/" {
                    while i < body.endIndex {
                        display.append(body[i])
                        i = body.index(after: i)
                    }
                    continue
                }
                if character == "/" && next == "*" {
                    display.append(character)
                    display.append("*")
                    mode = .blockComment
                    i = nextIndex
                } else if character == "\"" {
                    display.append(character)
                    mode = .string
                } else if character == "'" {
                    display.append(character)
                    mode = .charLit
                } else {
                    display.append(character)
                    if character == "{" {
                        braceDelta += 1
                    } else if character == "}" {
                        braceDelta -= 1
                    }
                    if !character.isWhitespace && firstCode == nil {
                        firstCode = character
                    }
                    stripped.append(character)
                }
            }
            i = body.index(after: i)
        }

        if mode == .string || mode == .charLit {
            mode = .code
        }

        let strippedText = String(stripped).trimmingCharacters(in: .whitespacesAndNewlines)
        let isPreprocessor = !startedInBlockComment && firstCode == "#"
        let startsWithClose = firstCode == "}"
        let isOpenBraceOnly = strippedText == "{"
        let isLabel = !isPreprocessor && isCaseOrLabel(strippedText)
        let hang = !isPreprocessor && isHangOpener(strippedText)
        let displayBody = String(display)
        let endsWithBackslash = trimmedEndsWithBackslash(displayBody)

        return LineFacts(
            displayBody: displayBody,
            stripped: strippedText,
            braceDelta: isPreprocessor ? 0 : braceDelta,
            startsWithCloseBrace: startsWithClose && !isPreprocessor,
            isOpenBraceOnly: isOpenBraceOnly,
            isPreprocessor: isPreprocessor,
            isLabel: isLabel,
            isHangOpener: hang,
            endsWithBackslash: endsWithBackslash
        )
    }

    private static func isCaseOrLabel(_ stripped: String) -> Bool {
        let text = stripped.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !text.hasPrefix("#") else { return false }
        if text.hasPrefix("case") || text.hasPrefix("default") {
            return containsLabelColon(text)
        }
        guard let colon = text.firstIndex(of: ":") else { return false }
        if text[colon...].hasPrefix("::") { return false }
        if let question = text.firstIndex(of: "?"), question < colon { return false }
        let name = text[..<colon].trimmingCharacters(in: .whitespaces)
        guard isIdentifier(name) else { return false }
        let after = text[text.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        return after.isEmpty || after.hasPrefix("//")
    }

    private static func containsLabelColon(_ text: String) -> Bool {
        guard let colon = text.firstIndex(of: ":") else { return false }
        if text[colon...].hasPrefix("::") { return false }
        if let question = text.firstIndex(of: "?"), question < colon { return false }
        return true
    }

    private static func isIdentifier(_ text: String) -> Bool {
        guard let first = text.first, first.isLetter || first == "_" else { return false }
        return text.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    private static func isHangOpener(_ stripped: String) -> Bool {
        var text = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        while text.hasPrefix("}") {
            text.removeFirst()
            text = text.trimmingCharacters(in: .whitespaces)
        }
        guard !text.isEmpty, !text.hasSuffix("{"), !text.hasSuffix(";") else { return false }
        if text == "else" || text == "do" { return true }
        if text.hasPrefix("else") {
            let rest = text.dropFirst(4).trimmingCharacters(in: .whitespaces)
            if rest.isEmpty { return true }
            return isControlHeader(rest, names: ["if"])
        }
        return isControlHeader(text, names: ["if", "for", "while", "switch"])
    }

    private static func isControlHeader(_ text: String, names: [String]) -> Bool {
        for name in names {
            guard text.hasPrefix(name) else { continue }
            let afterName = String(text.dropFirst(name.count))
            let trimmed = afterName.drop(while: { $0 == " " || $0 == "\t" })
            guard trimmed.first == "(" else { continue }
            let parenSource = String(trimmed)
            guard let close = matchingParen(in: parenSource) else { continue }
            let afterClose = parenSource.index(after: close)
            let after = String(parenSource[afterClose...]).trimmingCharacters(in: .whitespaces)
            if after.isEmpty { return true }
        }
        return false
    }

    private static func matchingParen(in text: String) -> String.Index? {
        var depth = 0
        var i = text.startIndex
        var inString = false
        var inChar = false
        while i < text.endIndex {
            let character = text[i]
            if inString {
                if character == "\\" {
                    i = text.index(after: i)
                    if i < text.endIndex { i = text.index(after: i) }
                    continue
                }
                if character == "\"" { inString = false }
            } else if inChar {
                if character == "\\" {
                    i = text.index(after: i)
                    if i < text.endIndex { i = text.index(after: i) }
                    continue
                }
                if character == "'" { inChar = false }
            } else if character == "\"" {
                inString = true
            } else if character == "'" {
                inChar = true
            } else if character == "(" {
                depth += 1
            } else if character == ")" {
                depth -= 1
                if depth == 0 { return i }
            }
            i = text.index(after: i)
        }
        return nil
    }

    private static func stripLeadingWhitespace(_ line: String) -> String {
        String(line.drop(while: { $0 == " " || $0 == "\t" }))
    }

    private static func trimTrailingWhitespace(_ line: String) -> String {
        var end = line.endIndex
        while end > line.startIndex {
            let previous = line.index(before: end)
            if line[previous] == " " || line[previous] == "\t" {
                end = previous
            } else {
                break
            }
        }
        return String(line[..<end])
    }

    private static func trimmedEndsWithBackslash(_ line: String) -> Bool {
        trimTrailingWhitespace(line).hasSuffix("\\")
    }

    private struct CaretMark {
        var line: Int
        var contentOffset: Int
    }

    private static func locateCaret(_ caretUTF16: Int, in pieces: [LinePiece]) -> CaretMark {
        var remaining = max(0, caretUTF16)
        for (index, piece) in pieces.enumerated() {
            let bodyLen = (piece.body as NSString).length
            let endLen = (piece.ending as NSString).length
            let lineLen = bodyLen + endLen
            if remaining < lineLen || index == pieces.count - 1 {
                let position = min(remaining, bodyLen)
                let leading = leadingWhitespaceUTF16(piece.body)
                return CaretMark(line: index, contentOffset: max(0, position - leading))
            }
            remaining -= lineLen
        }
        return CaretMark(line: max(pieces.count - 1, 0), contentOffset: 0)
    }

    private static func restoreCaret(_ mark: CaretMark, in pieces: [(body: String, ending: String)]) -> Int {
        guard !pieces.isEmpty else { return 0 }
        let line = min(max(mark.line, 0), pieces.count - 1)
        var offset = 0
        for index in 0..<line {
            offset += (pieces[index].body as NSString).length
            offset += (pieces[index].ending as NSString).length
        }
        let body = pieces[line].body as NSString
        let leading = leadingWhitespaceUTF16(pieces[line].body)
        let maxContent = max(0, body.length - leading)
        let column = leading + min(mark.contentOffset, maxContent)
        return offset + min(column, body.length)
    }

    private static func leadingWhitespaceUTF16(_ line: String) -> Int {
        var count = 0
        for character in line {
            if character == " " || character == "\t" {
                count += (String(character) as NSString).length
            } else {
                break
            }
        }
        return count
    }
}
