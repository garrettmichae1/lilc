import Foundation

struct CRunDiagnostic: Equatable, Sendable {
    enum Kind: String, Sendable {
        case syntax = "SYNTAX ERROR"
        case name = "NAME ERROR"
        case type = "TYPE ERROR"
        case runtime = "RUNTIME ERROR"
        case project = "PROJECT ERROR"
        case unsupported = "NOT SUPPORTED"
    }

    var kind: Kind
    var title: String
    var explanation: String
    var suggestion: String
    var file: String?
    var line: Int?
    var column: Int?
    var sourceLine: String?
    var rawMessage: String

    var displayText: String {
        var lines = ["\(kind.rawValue) · \(title)"]
        if let file, let line {
            let position = column.map { "\(file):\(line):\($0)" } ?? "\(file):\(line)"
            lines.append(position)
        }
        lines.append("")
        if let sourceLine, !sourceLine.isEmpty {
            lines.append(sourceLine)
            if let column {
                lines.append(String(repeating: " ", count: max(0, column)) + "^")
            }
            lines.append("")
        }
        lines.append(explanation)
        if !suggestion.isEmpty {
            lines.append("")
            lines.append("Try: \(suggestion)")
        }
        lines.append("")
        lines.append("PicoC detail:")
        lines.append(rawMessage)
        return lines.joined(separator: "\n") + "\n"
    }
}

struct CErrorJump: Equatable, Sendable {
    var fileID: String
    var line: Int
    var column: Int
}

enum CDiagnosticJump {
    static func resolve(
        diagnostic: CRunDiagnostic,
        runFile: LocalCFile,
        extras: [LocalCFile],
        projectFiles: [LocalCFile]
    ) -> CErrorJump? {
        guard let line = diagnostic.line, line > 0 else { return nil }
        let column = max(diagnostic.column ?? 1, 1)
        let reportedName = diagnostic.file.map { URL(fileURLWithPath: $0).lastPathComponent }

        if let name = reportedName,
           let named = projectFiles.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }),
           named.id != runFile.id {
            return CErrorJump(fileID: named.id, line: line, column: column)
        }

        let mapped = mapConcatenatedLine(line, runFile: runFile, extras: extras)
        return CErrorJump(fileID: mapped.fileID, line: max(mapped.line, 1), column: column)
    }

    static func concatenatedSource(runFile: LocalCFile, extras: [LocalCFile]) -> String {
        let extraCode = extras.map(\.code).joined(separator: "\n")
        return extraCode.isEmpty ? runFile.code : extraCode + "\n" + runFile.code
    }

    static func mapConcatenatedLine(
        _ line: Int,
        runFile: LocalCFile,
        extras: [LocalCFile]
    ) -> (fileID: String, line: Int) {
        if extras.isEmpty {
            return (runFile.id, line)
        }
        let source = concatenatedSource(runFile: runFile, extras: extras)
        let offset = utf16Offset(ofLine: line, in: source)
        return owner(ofUTF16Offset: offset, runFile: runFile, extras: extras)
    }

    private static func utf16Offset(ofLine line: Int, in source: String) -> Int {
        let ns = source as NSString
        var current = 1
        var index = 0
        let length = ns.length
        while current < line, index < length {
            let character = ns.character(at: index)
            index += 1
            if character == 10 {
                current += 1
            } else if character == 13 {
                if index < length, ns.character(at: index) == 10 {
                    index += 1
                }
                current += 1
            }
        }
        return index
    }

    private static func owner(
        ofUTF16Offset offset: Int,
        runFile: LocalCFile,
        extras: [LocalCFile]
    ) -> (fileID: String, line: Int) {
        var cursor = 0
        for extra in extras {
            let extraLength = (extra.code as NSString).length
            let extraEnd = cursor + extraLength
            if offset < extraEnd {
                return (extra.id, lineNumber(atUTF16Offset: offset - cursor, in: extra.code))
            }
            cursor = extraEnd
            let joinerEnd = cursor + 1
            if offset < joinerEnd {
                return (extra.id, lineNumber(atUTF16Offset: extraLength, in: extra.code))
            }
            cursor = joinerEnd
        }
        return (runFile.id, lineNumber(atUTF16Offset: max(0, offset - cursor), in: runFile.code))
    }

    private static func lineNumber(atUTF16Offset offset: Int, in code: String) -> Int {
        let ns = code as NSString
        let clamped = min(max(0, offset), ns.length)
        var line = 1
        var index = 0
        while index < clamped {
            let character = ns.character(at: index)
            index += 1
            if character == 10 {
                line += 1
            } else if character == 13 {
                if index < clamped, ns.character(at: index) == 10 {
                    index += 1
                }
                line += 1
            }
        }
        return max(line, 1)
    }
}

enum CDiagnosticFormatter {
    static func diagnostic(from raw: String) -> CRunDiagnostic? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        let location = parseLocation(in: normalized)
        let message: String
        if let location {
            message = location.message
        } else {
            // PicoC syntax/runtime failures print file:line:col. Bare runner
            // messages are a single line. Multi-line stdout must not be rewritten
            // just because it happens to mention an error phrase.
            let nonempty = normalized
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard nonempty.count <= 1 else { return nil }
            message = nonempty.first ?? normalized
        }
        guard let advice = advice(for: message, wholeOutput: normalized) else { return nil }

        return CRunDiagnostic(
            kind: advice.kind,
            title: advice.title,
            explanation: advice.explanation,
            suggestion: advice.suggestion,
            file: location?.file,
            line: location?.line,
            column: location?.column,
            sourceLine: location?.sourceLine,
            rawMessage: normalized
        )
    }

    static func displayOutput(for raw: String) -> (text: String, failed: Bool) {
        guard let diagnostic = diagnostic(from: raw) else {
            return (raw, false)
        }
        return (diagnostic.displayText, true)
    }

    private struct Location {
        var file: String
        var line: Int
        var column: Int
        var message: String
        var sourceLine: String?
    }

    private struct Advice {
        var kind: CRunDiagnostic.Kind
        var title: String
        var explanation: String
        var suggestion: String
    }

    private static func parseLocation(in output: String) -> Location? {
        let lines = output.components(separatedBy: .newlines)
        let pattern = #"^(.+):(\d+):(\d+)\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        for (index, line) in lines.enumerated() {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            guard let match = regex.firstMatch(in: line, range: range),
                  let fileRange = Range(match.range(at: 1), in: line),
                  let lineRange = Range(match.range(at: 2), in: line),
                  let columnRange = Range(match.range(at: 3), in: line),
                  let messageRange = Range(match.range(at: 4), in: line),
                  let lineNumber = Int(line[lineRange]),
                  let column = Int(line[columnRange]) else {
                continue
            }
            let sourceLine: String?
            if index >= 2, lines[index - 1].trimmingCharacters(in: .whitespaces) == "^" {
                sourceLine = lines[index - 2]
            } else {
                sourceLine = nil
            }
            return Location(
                file: String(line[fileRange]),
                line: lineNumber,
                column: column,
                message: String(line[messageRange]),
                sourceLine: sourceLine
            )
        }
        return nil
    }

    private static func advice(for message: String, wholeOutput: String) -> Advice? {
        let text = message.lowercased()
        let all = wholeOutput.lowercased()

        if text.contains("';' expected") || text.contains("semicolon expected") {
            return syntax("Missing semicolon", "C statements normally end with a semicolon.", "add ; at the end of the statement above the caret.")
        }
        if text.contains("'}' expected") || text.contains("brackets not closed") {
            return syntax("Unclosed block", "An opening brace or bracket does not have a matching closing one.", "match every { with } and every ( with ).")
        }
        if text.contains("'{' expected") {
            return syntax("Missing opening brace", "C expected the start of a statement block.", "add { after the function, loop, or condition.")
        }
        if text.contains("')' expected") || text.contains("'(' expected") || text.contains("close bracket expected") {
            return syntax("Unmatched parentheses", "A function call or condition has an unmatched parenthesis.", "check the parentheses around this expression.")
        }
        if text.contains("']' expected") {
            return syntax("Unclosed array bracket", "An opening [ is missing its closing ].", "close the array size or index with ].")
        }
        if text.contains("':' expected") {
            return syntax("Missing colon", "case and default labels must end with a colon.", "write case 1: or default: before the statements.")
        }
        if text.contains("'while' expected") {
            return syntax("Incomplete do-while loop", "A do { ... } loop must finish with while (condition);", "add while (condition); after the closing brace.")
        }
        if text.contains("comma expected") {
            return syntax("Missing comma", "Items in this list must be separated by commas.", "add a comma between arguments, parameters, or initializers.")
        }
        if text.contains("identifier expected") || text.contains("identifier not expected") {
            return syntax("Expected a name", "C expected a valid variable, function, member, or type name here.", "use a name made from letters, digits, and underscores; do not start with a digit.")
        }
        if text.contains("integer value expected") {
            return type("Integer required", "This place needs a whole number, not a different type.", "use an int value or cast to int.")
        }
        if text.contains("expression expected") || text.contains("invalid expression") || text.contains("value expected") {
            return syntax("Incomplete expression", "The expression is missing a value or operator.", "check both sides of operators and remove any extra punctuation.")
        }
        if text.contains("statement expected") || text.contains("operator not expected") || text.contains("value not expected") || text.contains("type not expected") {
            return syntax("Unexpected token", "This token cannot appear at this point in a C statement.", "check the previous line for missing punctuation, then simplify this statement.")
        }
        if text.contains("unterminated string") || text.contains("unterminated character") {
            return syntax("Unclosed string", "A string or character literal is missing its closing quote.", "add a matching \" or ' on the same line, and escape quotes inside the text with \\.")
        }
        if text.contains("unterminated comment") {
            return syntax("Unclosed comment", "A /* comment never reaches its closing */.", "add */ at the end of the comment.")
        }
        if text.contains("illegal character") || text.contains("expected \"'\"") {
            return syntax("Invalid character or quote", "The source contains a character or quote PicoC cannot tokenize.", "replace smart quotes with plain ' or \" and close the string or character literal.")
        }
        if text.contains("#else without") || text.contains("#endif without") || (text.contains("#if") && (text.contains("without") || text.contains("unmatched"))) {
            return syntax("Broken preprocessor condition", "A #else or #endif does not match an earlier #if or #ifdef.", "pair every #if / #ifdef with one #endif, and put #else only in between.")
        }
        if text.contains("filename.h") {
            return syntax("Missing include path", "#include needs a header name in quotes or angle brackets.", "write #include <stdio.h> or #include \"myheader.h\".")
        }
        if text.contains("cannot include") || text.contains("cannot open include") || text.contains("cannot read include") || (text.contains("include file") && text.contains("too large")) {
            return project("Header not found", "The requested header is unavailable, too large, or outside this project folder.", "check the #include spelling and keep quoted .h files in the same project.")
        }
        if text.contains("outside this project folder") {
            return project("File I/O is limited", "fopen, remove, and rename only work on files inside this project folder.", "keep data files in the same project as your .c file, and use a relative path.")
        }
        if text.contains("write some c code") {
            return project("Nothing to run", "The editor is empty, so there is no C program to start.", "type a small program with int main(void) and press Run.")
        }
        if text.contains("lilc could not") {
            return project("Could not start the C engine", "lilC failed before your program could run.", "try Run again. If it keeps happening, restart the app.")
        }
        if text.contains("main() is not defined") {
            return project("No main function", "A runnable C program needs one main function.", "add int main(void) { return 0; }.")
        }
        if text.contains("main is not a function") || text.contains("main() should return") || text.contains("bad parameters to main") {
            return type("Invalid main function", "main must be a function that returns int or void and uses a supported parameter list.", "use int main(void) for a beginner program.")
        }
        if text.contains("already defined") {
            return name("Name defined twice", "Two declarations in this program use the same name where only one is allowed.", "rename or remove one definition. A project must contain only one main().")
        }
        if text.contains("couldn't find goto label") || text.contains("could not find goto label") {
            return name("Unknown goto label", "goto needs a label that exists in the same function.", "add label_name: before the target statement, or fix the spelling.")
        }
        if text.contains("is not defined") || text.contains("is undefined") || text.contains("isn't defined") || text.contains("out of scope") {
            return name("Unknown name", "This variable, function, struct, enum, or type is not visible here.", "check spelling and declare it before use.")
        }
        if text.contains("doesn't have a member") || text.contains("structure or union member") {
            return name("Unknown struct member", "That field is not declared in this struct or union.", "check the struct definition and the spelling after . or ->.")
        }
        if text.contains("not a struct or union") || (text.contains("can't use") && (text.contains("struct") || text.contains("union"))) {
            return type("Not a struct or union", ". and -> only work on a struct, a union, or a pointer to one.", "declare a struct type and use . on the value or -> on a pointer.")
        }
        if text.contains("too many arguments") {
            return type("Too many arguments", "The call supplies more arguments than the function accepts.", "remove extra arguments or update the function parameters.")
        }
        if text.contains("not enough arguments") || text.contains("arguments missing") {
            return type("Missing arguments", "The call does not supply every required argument.", "pass a value for each function parameter.")
        }
        if text.contains("too many parameters") {
            return type("Too many parameters", "This function declares more parameters than PicoC allows.", "keep the parameter list to 16 or fewer, or split the function.")
        }
        if text.contains("bad parameter") || text.contains("bad argument") {
            return type("Invalid argument or parameter", "A parameter or argument is missing or written incorrectly.", "check the commas, types, and names in this list.")
        }
        if text.contains("non-pointer argument to scanf") {
            return type("scanf needs an address", "scanf must write into a variable through a pointer.", "pass &variable for numbers and chars, or a char array for %s.")
        }
        if text.contains("is not a function") {
            return type("Not a function", "This name exists but is not a function, so it cannot be called.", "call a function name, or remove the parentheses if you meant a variable.")
        }
        if text.contains("can't get the address") {
            return type("Cannot take address", "& only works on a real variable or array element, not a temporary value.", "store the value in a variable first, then take its address.")
        }
        if text.contains("can't initialize") || text.contains("incomplete type") {
            return type("Incomplete type", "This type is not fully declared yet, so it cannot be created or initialized.", "finish the struct, union, or array declaration before using it.")
        }
        if text.contains("can't define a void") {
            return type("Void variable", "void means “no value,” so you cannot declare a void variable.", "use a real type such as int, char, or a pointer.")
        }
        if text.contains("can't set") || text.contains("can't assign") || text.contains("not an lvalue") || text.contains("from an array of size") {
            return type("Invalid assignment", "The value on the left cannot receive this value or cannot be changed.", "check the destination type and do not assign to constants, arrays, or temporary values.")
        }
        if text.contains("array index out of range") || text.contains("array index out of bounds") {
            return runtime("Array index out of range", "The program used an index outside the array’s declared size.", "use indexes from 0 through size - 1, and check the index before you use it.")
        }
        if text.contains("array index must be an integer") || text.contains("is not an array") {
            return type("Invalid array access", "Array indexing needs an integer and an actual array or pointer.", "use array[index] with an integer index inside the valid range.")
        }
        if text.contains("too many array elements") || text.contains("too many struct initializers") {
            return type("Too many initializer values", "The initializer contains more values than the destination can hold.", "remove extra values or increase the declared array size.")
        }
        if text.contains("first argument to '?'") {
            return type("Invalid ternary condition", "The ? : operator needs a number or comparison on the left of ?.", "write condition ? valueIfTrue : valueIfFalse.")
        }
        if text.contains("no value returned") {
            return type("Missing return value", "This function promises a result but reached the end without returning one.", "add return someValue; on every path, including the end of the function.")
        }
        if text.contains("void value") || text.contains("void function") || text.contains("value required in return") {
            return type("Wrong return value", "The function’s declared return type does not match this return or expression.", "return a value from non-void functions and no value from void functions.")
        }
        if text.contains("null pointer") {
            return runtime("NULL pointer access", "The program tried to read or write through a pointer that points to nothing.", "check pointer != NULL before dereferencing it with * or ->.")
        }
        if text.contains("assertion failed") {
            return runtime("Assertion failed", "assert() stopped the program because its condition was false.", "fix the condition that failed, or remove the assert once the code is correct.")
        }
        if text.contains("invalid allocation size") {
            return runtime("Invalid allocation size", "malloc and related calls need a non-negative size in bytes.", "pass a size of 0 or more, often count * sizeof(type).")
        }
        if text.contains("division by zero") || text.contains("modulo by zero") {
            return runtime("Division by zero", "Integer division and remainder operations cannot use zero as the divisor.", "check the divisor before using /, %, /=, or %=.")
        }
        if text.contains("invalid shift count") {
            return runtime("Invalid bit shift", "A bit shift count cannot be negative or at least as large as the integer type.", "use a shift count from 0 through the number of bits minus one.")
        }
        if text.contains("program stopped: too many steps") || all.contains("program stopped: too many steps") {
            return runtime("Program ran too long", "lilC stopped the program to protect the app. This often means an infinite loop or runaway recursion.", "check that every loop changes toward its stopping condition.")
        }
        if text.contains("stack underrun") || text.contains("stack is empty") || text.contains("out of memory") {
            return runtime("Program memory exhausted", "The interpreter ran out of its limited stack or heap.", "reduce recursion and large allocations, and free memory you allocate.")
        }
        if text == "abort" || text.hasSuffix(" abort") || text.contains("abort\n") || (text.contains("abort") && text.count < 40) {
            return runtime("Program aborted", "The program called abort(), which stops the run immediately.", "remove abort() or only call it when you really mean to stop.")
        }
        if text.contains("system() is not available") || text.contains("not supported") {
            return unsupported("Feature unavailable in lilC", "This operation is outside lilC’s safe on-device PicoC runtime.", "use a beginner-friendly alternative PicoC can run, or try the same idea on a desktop compiler later.")
        }
        if text.contains("nested function") {
            return unsupported("Nested functions are not allowed", "PicoC does not allow a function defined inside another function.", "move the inner function next to the others, above main.")
        }
        if text.contains("can only be globals") {
            return type("Type must be global", "struct, union, and enum types must be declared at the top level, not inside a function.", "move the type definition above main.")
        }
        if text.contains("invalid type in struct") {
            return type("Invalid struct member type", "A struct or union member uses a type PicoC cannot store there.", "use a complete type for each member and finish nested struct definitions first.")
        }
        if text.contains("invalid operation") || text.contains("invalid use") {
            return type("Invalid operation", "This operator cannot be used with these values.", "check the operand types and pointer values.")
        }
        if text.contains("parse error") || text.contains("bad type declaration") || text.contains("bad function") || text.contains("function body expected") || text.contains("function definition expected") {
            return syntax("Could not parse this code", "The declaration or function near the caret is incomplete.", "check braces, parentheses, types, names, and semicolons around this line.")
        }
        if all.hasPrefix("cannot run this project:") {
            return project("Multiple main functions", "A project can only have one program entry point.", "keep one main() and turn the other files into helper functions.")
        }
        if wholeOutput.range(of: #":\d+:\d+\s+\S+"#, options: .regularExpression) != nil {
            return syntax("Could not run this code", "PicoC stopped on the marked line.", "read the PicoC detail below and fix the code at the caret.")
        }
        return nil
    }

    private static func syntax(_ title: String, _ explanation: String, _ suggestion: String) -> Advice {
        Advice(kind: .syntax, title: title, explanation: explanation, suggestion: suggestion)
    }

    private static func name(_ title: String, _ explanation: String, _ suggestion: String) -> Advice {
        Advice(kind: .name, title: title, explanation: explanation, suggestion: suggestion)
    }

    private static func type(_ title: String, _ explanation: String, _ suggestion: String) -> Advice {
        Advice(kind: .type, title: title, explanation: explanation, suggestion: suggestion)
    }

    private static func runtime(_ title: String, _ explanation: String, _ suggestion: String) -> Advice {
        Advice(kind: .runtime, title: title, explanation: explanation, suggestion: suggestion)
    }

    private static func project(_ title: String, _ explanation: String, _ suggestion: String) -> Advice {
        Advice(kind: .project, title: title, explanation: explanation, suggestion: suggestion)
    }

    private static func unsupported(_ title: String, _ explanation: String, _ suggestion: String) -> Advice {
        Advice(kind: .unsupported, title: title, explanation: explanation, suggestion: suggestion)
    }
}
