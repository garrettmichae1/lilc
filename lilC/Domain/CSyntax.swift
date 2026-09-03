import Foundation
import UIKit

enum CSyntaxKind: Equatable, Sendable {
    case control
    case type
    case preprocessor
    case op
    case string
    case comment
    case number
}

struct CSyntaxToken: Equatable, Sendable {
    let kind: CSyntaxKind
    let range: NSRange
}

enum CSyntaxLexer {
    static func tokens(in source: String) -> [CSyntaxToken] {
        let units = Array(source.utf16)
        let length = units.count
        var index = 0
        var tokens: [CSyntaxToken] = []

        while index < length {
            let char = units[index]
            if isWhitespace(char) {
                index += 1
                continue
            }
            if char == slash, index + 1 < length, units[index + 1] == slash {
                let start = index
                index += 2
                while index < length, units[index] != newline {
                    index += 1
                }
                tokens.append(CSyntaxToken(kind: .comment, range: NSRange(location: start, length: index - start)))
                continue
            }
            if char == slash, index + 1 < length, units[index + 1] == star {
                let start = index
                index += 2
                while index + 1 < length, !(units[index] == star && units[index + 1] == slash) {
                    index += 1
                }
                if index + 1 < length {
                    index += 2
                } else {
                    index = length
                }
                tokens.append(CSyntaxToken(kind: .comment, range: NSRange(location: start, length: index - start)))
                continue
            }
            if char == hash, isDirectiveStart(units, index) {
                let start = index
                index += 1
                while index < length, isSpace(units[index]) {
                    index += 1
                }
                let nameStart = index
                while index < length, isIdentPart(units[index]) {
                    index += 1
                }
                if preprocessor.contains(slice(units, nameStart, index)) {
                    tokens.append(CSyntaxToken(kind: .preprocessor, range: NSRange(location: start, length: index - start)))
                    continue
                }
                index = start + 1
                continue
            }
            if char == quote || char == apos {
                let start = index
                let quote = char
                index += 1
                while index < length {
                    if units[index] == backslash, index + 1 < length {
                        index += 2
                        continue
                    }
                    if units[index] == quote {
                        index += 1
                        break
                    }
                    index += 1
                }
                tokens.append(CSyntaxToken(kind: .string, range: NSRange(location: start, length: index - start)))
                continue
            }
            if isDigit(char) || (char == dot && index + 1 < length && isDigit(units[index + 1])) {
                let start = index
                if char == zero, index + 1 < length, units[index + 1] == xLower || units[index + 1] == xUpper {
                    index += 2
                    while index < length, isHex(units[index]) {
                        index += 1
                    }
                } else {
                    if char == dot {
                        index += 1
                    }
                    while index < length, isDigit(units[index]) {
                        index += 1
                    }
                    if char != dot, index < length, units[index] == dot, index + 1 < length, isDigit(units[index + 1]) {
                        index += 1
                        while index < length, isDigit(units[index]) {
                            index += 1
                        }
                    }
                }
                tokens.append(CSyntaxToken(kind: .number, range: NSRange(location: start, length: index - start)))
                continue
            }
            if isIdentStart(char) {
                let start = index
                index += 1
                while index < length, isIdentPart(units[index]) {
                    index += 1
                }
                let word = slice(units, start, index)
                if control.contains(word) {
                    tokens.append(CSyntaxToken(kind: .control, range: NSRange(location: start, length: index - start)))
                } else if types.contains(word) {
                    tokens.append(CSyntaxToken(kind: .type, range: NSRange(location: start, length: index - start)))
                }
                continue
            }
            if let op = matchOperator(units, index) {
                tokens.append(CSyntaxToken(kind: .op, range: NSRange(location: index, length: op)))
                index += op
                continue
            }
            index += 1
        }
        return tokens
    }

    private static let control: Set<String> = [
        "break", "case", "continue", "default", "do", "else", "for", "goto", "if", "return", "switch", "while",
    ]
    private static let types: Set<String> = [
        "auto", "char", "const", "delete", "double", "enum", "extern", "float", "int", "long", "new",
        "register", "short", "signed", "sizeof", "static", "struct", "typedef", "union", "unsigned", "void", "volatile",
    ]
    private static let preprocessor: Set<String> = [
        "define", "else", "endif", "if", "ifdef", "ifndef", "include",
    ]
}

enum CSyntaxPalette {
    static func color(_ kind: CSyntaxKind, way: AppColorWay) -> UIColor {
        switch way {
        case .dark:
            switch kind {
            case .control: rgb(0xC586C0)
            case .type, .preprocessor, .op: rgb(0x569CD6)
            case .string: rgb(0xCE9178)
            case .comment: rgb(0x6A9955)
            case .number: rgb(0xB5CEA8)
            }
        case .light:
            switch kind {
            case .control: rgb(0xAF00DB)
            case .type, .preprocessor, .op: rgb(0x0000FF)
            case .string: rgb(0xA31515)
            case .comment: rgb(0x008000)
            case .number: rgb(0x098658)
            }
        }
    }

    private static func rgb(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

private let slash: UInt16 = 0x2F
private let star: UInt16 = 0x2A
private let hash: UInt16 = 0x23
private let quote: UInt16 = 0x22
private let apos: UInt16 = 0x27
private let backslash: UInt16 = 0x5C
private let newline: UInt16 = 0x0A
private let dot: UInt16 = 0x2E
private let zero: UInt16 = 0x30
private let xLower: UInt16 = 0x78
private let xUpper: UInt16 = 0x58

private let operators: [String] = [
    "<<=", ">>=",
    "==", "!=", "<=", ">=", "&&", "||", "++", "--", "<<", ">>", "->",
    "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=",
    "+", "-", "*", "/", "%", "=", "<", ">", "!", "&", "|", "^", "~", "?", ":", ".",
]

private func isWhitespace(_ char: UInt16) -> Bool {
    char == 0x20 || char == 0x09 || char == 0x0A || char == 0x0D
}

private func isSpace(_ char: UInt16) -> Bool {
    char == 0x20 || char == 0x09
}

private func isDigit(_ char: UInt16) -> Bool {
    char >= 0x30 && char <= 0x39
}

private func isHex(_ char: UInt16) -> Bool {
    isDigit(char) || (char >= 0x41 && char <= 0x46) || (char >= 0x61 && char <= 0x66)
}

private func isIdentStart(_ char: UInt16) -> Bool {
    (char >= 0x41 && char <= 0x5A) || (char >= 0x61 && char <= 0x7A) || char == 0x5F
}

private func isIdentPart(_ char: UInt16) -> Bool {
    isIdentStart(char) || isDigit(char)
}

private func isDirectiveStart(_ units: [UInt16], _ index: Int) -> Bool {
    var cursor = index
    while cursor > 0 {
        let previous = units[cursor - 1]
        if previous == newline {
            return true
        }
        if !isSpace(previous) {
            return false
        }
        cursor -= 1
    }
    return true
}

private func slice(_ units: [UInt16], _ start: Int, _ end: Int) -> String {
    var text = ""
    text.reserveCapacity(end - start)
    for i in start..<end {
        if let scalar = UnicodeScalar(units[i]) {
            text.append(Character(scalar))
        }
    }
    return text
}

private func matchOperator(_ units: [UInt16], _ index: Int) -> Int? {
    for op in operators {
        let utf16 = Array(op.utf16)
        let end = index + utf16.count
        guard end <= units.count else { continue }
        var ok = true
        for offset in 0..<utf16.count where units[index + offset] != utf16[offset] {
            ok = false
            break
        }
        if ok {
            return utf16.count
        }
    }
    return nil
}
