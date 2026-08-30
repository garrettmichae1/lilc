import Foundation
import SwiftUI
import Testing
import UIKit
@testable import lilC

@Suite(.serialized)
struct lilCTests {
    @Test func agentSurfacesStayHiddenInThisRelease() {
        #expect(AgentRuntimeConfig.surfacesVisibleInThisRelease == false)
    }

    @Test func legalURLsArePublicGitHubPages() {
        #expect(LegalURLs.home.absoluteString == "https://garrettmichae1.github.io/lilc/")
        #expect(LegalURLs.privacy.absoluteString == "https://garrettmichae1.github.io/lilc/privacy.html")
        #expect(LegalURLs.terms.absoluteString == "https://garrettmichae1.github.io/lilc/terms.html")
        #expect(LegalURLs.teachers.absoluteString == "https://garrettmichae1.github.io/lilc/teachers.html")
        #expect(LegalURLs.webPlayground.absoluteString == "https://garrettmichae1.github.io/lilc/web/")
        #expect(LegalURLs.privacy.scheme == "https")
        #expect(LegalURLs.terms.scheme == "https")
    }

    @Test func firstHourCurriculumLoadsSixOptionalLessons() {
        #expect(FirstHourCurriculum.lessons.count == 6)
        #expect(FirstHourCurriculum.first.id == "hello")
        #expect(FirstHourCurriculum.lesson(id: "function")?.number == 6)
        #expect(Set(FirstHourCurriculum.lessons.map(\.id)).count == 6)
        #expect(Set(FirstHourCurriculum.lessons.map(\.fileName)).count == 6)
        for lesson in FirstHourCurriculum.lessons {
            #expect(lesson.relativePath.hasPrefix("lessons/"))
            #expect(lesson.source.contains("int main("))
            #expect(lesson.expectedOutput.isEmpty == false)
        }
    }

    @Test func firstHourLessonsRunOnPicoC() {
        for lesson in FirstHourCurriculum.lessons {
            let output = LocalCRunner.run(lesson.source)
            #expect(output == lesson.expectedOutput, "\(lesson.id) produced \(output)")
        }
    }

    @MainActor
    @Test func openLessonCopiesStarterOnceAndDoesNotOverwriteEdits() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-tests-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)
        let lesson = FirstHourCurriculum.first
        workspace.openLesson(lesson)
        #expect(workspace.currentFile.relativePath == lesson.relativePath)
        #expect(workspace.currentFile.code == lesson.source)
        workspace.updateCurrentCode("int main(void) { return 0; }\n")
        workspace.openLesson(lesson)
        #expect(workspace.currentFile.code.contains("return 0;"))
        #expect(workspace.currentFile.code != lesson.source)
    }

    @Test func localCFileNamesNormalizeToCFiles() {
        #expect(LocalCFile.normalizedName("hello") == "hello.c")
        #expect(LocalCFile.normalizedName("hello.c") == "hello.c")
        #expect(LocalCFile.normalizedName("  ") == "hello.c")
    }

    @MainActor
    @Test func agentPathsRejectTraversal() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-tests-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)
        #expect(workspace.agentSafeRelativePath("../secret.c") == nil)
        #expect(workspace.agentSafeRelativePath("/etc/passwd") == nil)
        #expect(workspace.agentSafeRelativePath("folder/main.c") == "folder/main.c")
        #expect(workspace.agentSafeRelativePath("./main.c") == "main.c")
    }

    @Test func agentEndpointsRequireHTTPS() throws {
        do {
            _ = try AgentEndpointPolicy.validatedGateway("http://example.com/v1", allowedHosts: ["api.lilc.app"])
            Issue.record("http should be rejected")
        } catch let error as AgentTransportError {
            #expect(error == .invalidEndpoint)
        }
        #if DEBUG
        let local = try AgentEndpointPolicy.validatedGateway("https://localhost/v1", allowedHosts: ["api.lilc.app"])
        #expect(local.host == "localhost")
        #else
        do {
            _ = try AgentEndpointPolicy.validatedGateway("https://localhost/v1", allowedHosts: ["api.lilc.app"])
            Issue.record("localhost should be rejected")
        } catch let error as AgentTransportError {
            #expect(error == .invalidEndpoint)
        }
        #endif
        let url = try AgentEndpointPolicy.validatedGateway("https://api.lilc.app/v1", allowedHosts: ["api.lilc.app"])
        #expect(url.host == "api.lilc.app")
        let worker = try AgentEndpointPolicy.validatedGateway(
            "https://lilc-agent.example.workers.dev/v1",
            allowedHosts: ["api.lilc.app"]
        )
        #expect(worker.host?.hasSuffix(".workers.dev") == true)
    }

    @Test func friendlyDiagnosticsCoverEveryPicoCAndRunnerErrorClass() {
        let catalog = picoCAndRunnerErrorCatalog
        let unrecognized = catalog.filter { CDiagnosticFormatter.diagnostic(from: $0) == nil }
        #expect(
            unrecognized.isEmpty,
            "Formatter missed \(unrecognized.count)/\(catalog.count) error classes: \(unrecognized)"
        )
        let coverage = Double(catalog.count - unrecognized.count) / Double(catalog.count)
        #expect(coverage >= 1.0)
    }

    @Test func friendlyDiagnosticPreservesLocationSourceAndRawDetail() {
        let raw = """
        printf("hello")
                       ^
        hello.c:3:15 ';' expected
        """
        let diagnostic = CDiagnosticFormatter.diagnostic(from: raw)
        #expect(diagnostic?.kind == .syntax)
        #expect(diagnostic?.line == 3)
        #expect(diagnostic?.column == 15)
        #expect(diagnostic?.sourceLine == "printf(\"hello\")")
        #expect(diagnostic?.displayText.contains("PicoC detail:") == true)
        #expect(diagnostic?.displayText.contains("';' expected") == true)
    }

    @Test func editorSearchFindsCaseInsensitiveMatchesInFile() {
        let text = "int main(void) {\n    printf(\"Hello\");\n    printf(\"hello\");\n}\n"
        let matches = EditorSearch.nsMatches(in: text, query: "HELLO")
        #expect(matches.count == 2)
        #expect(EditorSearch.nsMatches(in: text, query: "   ").isEmpty)
        #expect(EditorSearch.nsMatches(in: text, query: "").isEmpty)
        #expect(EditorSearch.nsMatches(in: text, query: "nope").isEmpty)
    }

    @Test func indentFormatterIndentsNestedBracesElseForAndSwitch() {
        let messy = """
        #include <stdio.h>
        int main(void) {
        if (x) {
        foo();
        } else {
        for (i = 0; i < 3; i++) {
        x++;
        }
        }
        switch (n) {
        case 1:
        bar();
        break;
        default:
        baz();
        }
        done:
        return 0;
        }
        """
        let expected = """
        #include <stdio.h>
        int main(void) {
            if (x) {
                foo();
            } else {
                for (i = 0; i < 3; i++) {
                    x++;
                }
            }
            switch (n) {
            case 1:
                bar();
                break;
            default:
                baz();
            }
        done:
            return 0;
        }
        """
        #expect(CIndentFormatter.format(messy) == expected)
    }

    @Test func indentFormatterPreservesBracesInsideStringsAndComments() {
        let source = """
        int main(void) {
        char *s = "hello { world }";
        /* { not a block */
        // { also not
        return 0;
        }
        """
        let formatted = CIndentFormatter.format(source)
        #expect(formatted.contains("    char *s = \"hello { world }\";"))
        #expect(formatted.contains("    /* { not a block */"))
        #expect(formatted.contains("    // { also not"))
        #expect(formatted.contains("    return 0;"))
    }

    @Test func indentFormatterLeavesAlreadyIndentedCodeStableAndEmptyFileAlone() {
        let pretty = """
        int main(void) {
            return 0;
        }
        """
        #expect(CIndentFormatter.format(pretty) == pretty)
        #expect(CIndentFormatter.format("") == "")
        #expect(CIndentFormatter.format("\n") == "\n")
    }

    @Test func indentFormatterPreservesWindowsNewlines() {
        let source = "int main(void) {\r\nreturn 0;\r\n}\r\n"
        let formatted = CIndentFormatter.format(source)
        #expect(formatted == "int main(void) {\r\n    return 0;\r\n}\r\n")
        #expect(formatted.contains("\r\n"))
        #expect(!formatted.contains("\n") || formatted.contains("\r\n"))
    }

    @Test func indentFormatterIsIdempotent() {
        let samples = [
            "",
            "int x;\n",
            "int main(void) {\nreturn 0;\n}\n",
            "if (a)\nfoo();\nelse\nbar();\n",
            "do\nfoo();\nwhile (0);\n",
            "#include <stdio.h>\nint main(void) { return 0; }\n",
            "char *s = \"{\";\n{\nint x;\n}\n",
            "int main(void) {\r\nfoo();\r\n}\r\n",
            "switch (n) {\ncase 1:\nbreak;\ndefault:\nbreak;\n}\n",
            "#define FOO \\\n1\n",
        ]
        for sample in samples {
            let once = CIndentFormatter.format(sample)
            let twice = CIndentFormatter.format(once)
            #expect(once == twice, "not idempotent for:\n\(sample)\nfirst:\n\(once)\nsecond:\n\(twice)")
        }
    }

    @Test func indentFormatterRestoresCaretOntoTheSameContent() {
        let source = "int main(void) {\nreturn 0;\n}\n"
        let caret = (source as NSString).range(of: "return").location
        let result = CIndentFormatter.formatKeepingCaret(source, caretUTF16: caret)
        let around = (result.text as NSString).substring(
            with: NSRange(location: result.caretUTF16, length: min(6, (result.text as NSString).length - result.caretUTF16))
        )
        #expect(around.hasPrefix("return"))
    }

    @Test func indentFormatterHangsSingleLineIfForWhileAndDo() {
        let source = """
        int main(void) {
        if (x)
        foo();
        else
        bar();
        for (i = 0; i < 1; i++)
        x++;
        while (x)
        x--;
        do
        x++;
        while (0);
        }
        """
        let formatted = CIndentFormatter.format(source)
        #expect(formatted.contains("    if (x)\n        foo();"))
        #expect(formatted.contains("    else\n        bar();"))
        #expect(formatted.contains("    for (i = 0; i < 3; i++)") == false)
        #expect(formatted.contains("    for (i = 0; i < 1; i++)\n        x++;"))
        #expect(formatted.contains("    while (x)\n        x--;"))
        #expect(formatted.contains("    do\n        x++;"))
    }

    @Test func keyboardPolicyNeverResignsToChaseStaleFocusState() {
        #expect(
            CCodeEditorKeyboardPolicy.shouldResignFirstResponder(
                swiftUIWantsFocus: false,
                textViewIsFirstResponder: true
            ) == false
        )
        #expect(
            CCodeEditorKeyboardPolicy.shouldApplyBoundText(
                fileChanged: false,
                isFirstResponder: true,
                viewText: "int x;",
                boundText: "int y;"
            ) == false
        )
        #expect(
            CCodeEditorKeyboardPolicy.shouldApplyBoundText(
                fileChanged: false,
                isFirstResponder: false,
                viewText: "int x;",
                boundText: "int y;"
            ) == true
        )
        #expect(
            CCodeEditorKeyboardPolicy.shouldBecomeFirstResponder(
                swiftUIWantsFocus: true,
                textViewIsFirstResponder: false
            ) == true
        )
        #expect(
            CCodeEditorKeyboardPolicy.shouldBecomeFirstResponder(
                swiftUIWantsFocus: true,
                textViewIsFirstResponder: true
            ) == false
        )
    }

    @MainActor
    @Test func accessoryBarHasOneDismissAndFormatBesideIt() {
        let accessory = CSymbolAccessoryView()
        let labels = accessory.controlAccessibilityLabels
        #expect(labels.last == "Hide keyboard")
        #expect(labels.dropLast().last == "Indent code")
        #expect(labels.filter { $0 == "Hide keyboard" }.count == 1)
        #expect(labels.contains("{"))
        #expect(labels.contains("Indent"))
    }

    @MainActor
    @Test func formatBufferIndentsTextViewWithoutReplacingIt() {
        var text = "int main(void) {\nreturn 0;\n}\n"
        let editor = CCodeEditor(
            text: Binding(get: { text }, set: { text = $0 }),
            fileID: "main.c",
            isFocused: true,
            jump: nil,
            findVisible: false,
            findQuery: "",
            findIndex: 0,
            findEpoch: 0,
            overlayHeight: 0,
            onBeginEditing: {},
            onEndEditing: {}
        )
        let coordinator = CCodeEditor.Coordinator(parent: editor)
        let textView = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        textView.text = text
        coordinator.textView = textView
        let identity = ObjectIdentifier(textView)
        coordinator.formatBuffer()
        #expect(textView.text == "int main(void) {\n    return 0;\n}\n")
        #expect(text == textView.text)
        #expect(ObjectIdentifier(textView) == identity)
    }

    @MainActor
    @Test func editorHostingKeepsSameTextViewAcrossTypedCharacters() {
        final class Box {
            var text = "int x;"
        }
        let box = Box()
        let host = UIHostingController(
            rootView: EditorKeyboardHarness(
                text: Binding(get: { box.text }, set: { box.text = $0 })
            )
        )
        host.view.bounds = CGRect(x: 0, y: 0, width: 390, height: 800)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()

        let textView = firstTextView(in: host.view)
        #expect(textView != nil)
        guard let textView else { return }
        let identity = ObjectIdentifier(textView)
        let becameFirstResponder = textView.becomeFirstResponder()
        textView.insertText("a")
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))

        let after = firstTextView(in: host.view)
        #expect(after.map(ObjectIdentifier.init) == identity)
        #expect((textView.text ?? "").contains("a"))
        if becameFirstResponder {
            #expect(
                textView.isFirstResponder,
                "Typing must not resign first responder; updateUIView used to resign when FocusState lagged"
            )
        }
        #expect(
            CCodeEditorKeyboardPolicy.shouldResignFirstResponder(
                swiftUIWantsFocus: false,
                textViewIsFirstResponder: true
            ) == false
        )
    }

    @Test func diagnosticJumpMapsConcatenatedHelperLineOntoHelperFile() {
        let helper = LocalCFile(
            relativePath: "proj/util.c",
            code: "int add(int a, int b) {\n    return a + b\n}\n"
        )
        let main = LocalCFile(
            relativePath: "proj/main.c",
            code: "int main(void) { return add(1, 2); }\n"
        )
        let diagnostic = CRunDiagnostic(
            kind: .syntax,
            title: "Missing semicolon",
            explanation: "C statements normally end with a semicolon.",
            suggestion: "add ;",
            file: "main.c",
            line: 2,
            column: 16,
            sourceLine: "    return a + b",
            rawMessage: "main.c:2:16 ';' expected"
        )
        let jump = CDiagnosticJump.resolve(
            diagnostic: diagnostic,
            runFile: main,
            extras: [helper],
            projectFiles: [helper, main]
        )
        #expect(jump?.fileID == helper.id)
        #expect(jump?.line == 2)
        #expect(jump?.column == 16)
    }

    @Test func diagnosticJumpPrefersNamedHelperOrHeaderFile() {
        let header = LocalCFile(relativePath: "proj/util.h", code: "#define N 1\n")
        let helper = LocalCFile(relativePath: "proj/util.c", code: "int add(int a, int b) { return a + b; }\n")
        let main = LocalCFile(relativePath: "proj/main.c", code: "int main(void) { return 0; }\n")
        let helperJump = CDiagnosticJump.resolve(
            diagnostic: CRunDiagnostic(
                kind: .syntax,
                title: "Missing semicolon",
                explanation: "",
                suggestion: "",
                file: "util.c",
                line: 4,
                column: 1,
                sourceLine: nil,
                rawMessage: "util.c:4:1 ';' expected"
            ),
            runFile: main,
            extras: [helper],
            projectFiles: [header, helper, main]
        )
        #expect(helperJump?.fileID == helper.id)
        #expect(helperJump?.line == 4)

        let headerJump = CDiagnosticJump.resolve(
            diagnostic: CRunDiagnostic(
                kind: .project,
                title: "Header not found",
                explanation: "",
                suggestion: "",
                file: "util.h",
                line: 1,
                column: 1,
                sourceLine: nil,
                rawMessage: "util.h:1:1 cannot read include file"
            ),
            runFile: main,
            extras: [helper],
            projectFiles: [header, helper, main]
        )
        #expect(headerJump?.fileID == header.id)
        #expect(headerJump?.line == 1)
    }

    @Test func diagnosticJumpWithoutLineIsNil() {
        let main = LocalCFile(relativePath: "main.c", code: "int main(void) { return 0; }\n")
        let jump = CDiagnosticJump.resolve(
            diagnostic: CRunDiagnostic(
                kind: .project,
                title: "Nothing to run",
                explanation: "",
                suggestion: "",
                file: nil,
                line: nil,
                column: nil,
                sourceLine: nil,
                rawMessage: "Write some C code, then run it."
            ),
            runFile: main,
            extras: [],
            projectFiles: [main]
        )
        #expect(jump == nil)
    }

    @Test func actualPicoCErrorsReceiveFriendlyDiagnostics() {
        let programs = [
            "int main(void) { int n = 1 return n; }",
            "int main(void) { return missing_name; }",
            "int helper(void) { return 1; }",
            "int main(void) { int n; int n; return 0; }",
            "#include \"missing.h\"\nint main(void) { return 0; }",
            "int add(int a, int b) { return a+b; }\nint main(void) { return add(1); }",
            "int add(int a, int b) { return a+b; }\nint main(void) { return add(1, 2, 3); }",
            "int main(void) { int n = 4; return n / 0; }",
            "int main(void) { int n = 4; return n % 0; }",
            "int main(void) { int n = 1; return n << 99; }",
            "int main(void) { int n = 1; return n << -1; }",
            "int main(void) { int n = @; return 0; }",
            "int main(void) { return 0 }",
            "void greet(void) {}\nint main(void) { int n = greet(); return n; }",
            "int answer(void) { }\nint main(void) { return answer(); }",
            "int main(void) { int nums[2] = {1, 2, 3}; return 0; }",
            "struct Point { int x; int y; };\nint main(void) { struct Point p; return p.z; }",
            "int main(void) { int n = 1; return n.x; }",
            "int main(void) { do { return 0; } }",
            "#include\nint main(void) { return 0; }",
            "int main(void) { goto missing; return 0; }",
            "int main(void) { int inner(void) { return 1; } return inner(); }",
            "int main(void) { void v; return 0; }",
            "int main(void) { int n; n(1); return 0; }",
            "int main(void) { return; }",
            "void done(void) { return 1; }\nint main(void) { done(); return 0; }",
            "",
        ]

        for program in programs {
            let raw = LocalCRunner.run(program)
            #expect(
                CDiagnosticFormatter.diagnostic(from: raw) != nil,
                "Expected friendly diagnostic for program:\n\(program)\nraw PicoC output: \(raw)"
            )
        }
    }

    @Test func newPicoCChecksExplainUnterminatedString() {
        let raw = LocalCRunner.run("int main(void) { char *s = \"hello; return 0; }")
        #expect(raw.contains("unterminated string"), "unterminated string raw: \(raw)")
        #expect(CDiagnosticFormatter.diagnostic(from: raw)?.kind == .syntax)
    }

    @Test func newPicoCChecksExplainUnterminatedComment() {
        let raw = LocalCRunner.run("int main(void) { /* open comment\n    return 0;\n}")
        #expect(raw.contains("unterminated comment"), "unterminated comment raw: \(raw)")
        #expect(CDiagnosticFormatter.diagnostic(from: raw)?.kind == .syntax)
    }

    @Test func newPicoCChecksExplainArrayIndexOutOfRange() {
        let raw = LocalCRunner.run("int main(void) { int nums[2]; nums[0] = 1; nums[1] = 2; return nums[2]; }")
        #expect(raw.contains("array index out of range"), "array bounds raw: \(raw)")
        #expect(CDiagnosticFormatter.diagnostic(from: raw)?.kind == .runtime)
    }

    @Test func newPicoCChecksExplainNullPointerIndex() {
        let raw = LocalCRunner.run("int main(void) { int *p = 0; return p[1]; }")
        #expect(raw.lowercased().contains("null pointer"), "null index raw: \(raw)")
        #expect(CDiagnosticFormatter.diagnostic(from: raw)?.kind == .runtime)
    }

    @Test func newPicoCChecksExplainNullPointerDereference() {
        let raw = LocalCRunner.run("int main(void) { int *p = 0; return *p; }")
        #expect(raw.lowercased().contains("null pointer"), "null deref raw: \(raw)")
        #expect(CDiagnosticFormatter.diagnostic(from: raw)?.kind == .runtime)
    }

    @Test func formatterMapsHardToTriggerPicoCMessages() {
        let samples: [(String, CRunDiagnostic.Kind, String)] = [
            ("can't get the address of this", .type, "Cannot take address"),
            ("first argument to '?' should be a number", .type, "Invalid ternary condition"),
            ("integer value expected instead of double", .type, "Integer required"),
            ("no value returned from a function returning int", .type, "Missing return value"),
            ("couldn't find goto label 'done'", .name, "Unknown goto label"),
            ("nested function definitions are not allowed", .unsupported, "Nested functions"),
            ("too many parameters (16 allowed)", .type, "Too many parameters"),
            ("bad parameter", .type, "Invalid argument"),
            ("int is not a function - can't call", .type, "Not a function"),
            ("can't initialize an incomplete type", .type, "Incomplete type"),
            ("can't define a void variable", .type, "Void variable"),
            ("struct/union definitions can only be globals", .type, "Type must be global"),
            ("invalid type in struct", .type, "Invalid struct member"),
            ("']' expected", .syntax, "Unclosed array"),
            ("':' expected", .syntax, "Missing colon"),
            ("'while' expected", .syntax, "do-while"),
            ("#else without #if", .syntax, "preprocessor"),
            ("cannot read include file 'notes.h'", .project, "Header not found"),
            ("include file 'big.h' is too large", .project, "Header not found"),
            ("cannot include '../secret.h' outside this project folder", .project, "Header not found"),
            ("Write some C code, then run it.", .project, "Nothing to run"),
            ("lilC could not start the local C engine.", .project, "Could not start"),
            ("non-pointer argument to scanf() - argument 1 after format", .type, "scanf"),
            ("stack is empty - can't go back", .runtime, "memory"),
            ("(VariableAlloc) out of memory", .runtime, "memory"),
            ("function definition expected", .syntax, "parse"),
            ("can't use '.' on something that's not a struct or union : it's a int", .type, "struct"),
            ("assertion failed", .runtime, "Assertion"),
            ("NULL pointer passed to strlen()", .runtime, "NULL"),
            ("invalid allocation size", .runtime, "allocation"),
            ("cannot open 'notes.txt' outside this project folder", .project, "File I/O"),
        ]
        for (raw, kind, titlePart) in samples {
            let diagnostic = CDiagnosticFormatter.diagnostic(from: raw)
            #expect(diagnostic != nil, "expected diagnostic for: \(raw)")
            #expect(diagnostic?.kind == kind, "kind for \(raw): \(String(describing: diagnostic?.kind))")
            #expect(
                diagnostic?.title.localizedCaseInsensitiveContains(titlePart) == true
                    || diagnostic?.explanation.localizedCaseInsensitiveContains(titlePart) == true
                    || diagnostic?.displayText.localizedCaseInsensitiveContains(titlePart) == true,
                "title/explanation for \(raw) should mention \(titlePart), got \(diagnostic?.title ?? "nil")"
            )
        }
    }

    @Test func successfulPrintfIsNotRewrittenAsADiagnostic() {
        let output = LocalCRunner.run("""
        #include <stdio.h>
        int main(void) {
            printf("hello from lilC\\n");
            return 0;
        }
        """)
        #expect(output == "hello from lilC\n")
        let formatted = CDiagnosticFormatter.displayOutput(for: output)
        #expect(formatted.failed == false)
        #expect(formatted.text == output)
    }

    @Test func successfulOutputIsNotRewrittenWhenALaterLineLooksLikeAnError() {
        let output = LocalCRunner.run("""
        #include <stdio.h>
        int main(void) {
            printf("status: ok\\n");
            printf("';' expected\\n");
            return 0;
        }
        """)
        #expect(output.contains("status: ok"))
        #expect(output.contains("';' expected"))
        let formatted = CDiagnosticFormatter.displayOutput(for: output)
        #expect(formatted.failed == false)
        #expect(formatted.text == output)
    }

    @Test func localRunnerSupportsStddefStdintLimitsAssertAndBool() {
        let output = LocalCRunner.run("""
        #include <stdio.h>
        #include <stddef.h>
        #include <stdint.h>
        #include <limits.h>
        #include <stdbool.h>
        int main(void) {
            size_t n = sizeof(int);
            uint32_t u = 7;
            bool ok = true;
            printf("%d %u %d %d\\n", (int)n, (unsigned)u, ok, INT_MAX > 0);
            return 0;
        }
        """)
        #expect(output == "4 7 1 1\n")
    }

    @Test func localRunnerExplainsAssertFailure() {
        let raw = LocalCRunner.run("""
        #include <assert.h>
        int main(void) {
            assert(0);
            return 0;
        }
        """)
        #expect(raw.contains("assertion failed"), "assert raw: \(raw)")
        #expect(CDiagnosticFormatter.diagnostic(from: raw)?.kind == .runtime)
    }

    @Test func localRunnerExplainsNullStringArgument() {
        let raw = LocalCRunner.run("""
        #include <string.h>
        int main(void) {
            return (int)strlen(0);
        }
        """)
        #expect(raw.contains("NULL pointer passed to strlen()"), "strlen NULL raw: \(raw)")
        #expect(CDiagnosticFormatter.diagnostic(from: raw)?.kind == .runtime)
    }

    @Test func localRunnerDoesNotLeakHostEnvironment() {
        let output = LocalCRunner.run("""
        #include <stdio.h>
        #include <stdlib.h>
        int main(void) {
            char *value = getenv("HOME");
            if (value == 0) printf("none\\n");
            else printf("leaked\\n");
            return 0;
        }
        """)
        #expect(output == "none\n")
    }

    @Test func localRunnerSupportsPutsAndIfndef() {
        let output = LocalCRunner.run("""
        #include <stdio.h>
        #ifndef SKIP
        int main(void) {
            puts("ready");
            return 0;
        }
        #endif
        """)
        #expect(output == "ready\n")
    }

    @Test func localRunnerBlocksUnsafeFopen() {
        let raw = LocalCRunner.run("""
        #include <stdio.h>
        int main(void) {
            FILE *file = fopen("/etc/passwd", "r");
            if (file) fclose(file);
            return 0;
        }
        """)
        #expect(raw.contains("outside this project folder"), "fopen raw: \(raw)")
        #expect(CDiagnosticFormatter.diagnostic(from: raw)?.kind == .project)
    }

    @Test func localRunnerHandlesSimpleFunctionAndPrintfOutput() {
        let output = LocalCRunner.run("""
        #include <stdio.h>

        int add(int a, int b) {
            return a + b;
        }

        int main(void) {
            int x = add(5, 5);
            printf("hello from lilC\\n");
            printf("%d\\n", x);
            return 0;
        }
        """)

        #expect(output == "hello from lilC\n10\n")
    }

    @Test func localRunnerSupportsIntermediateCWithoutAVM() {
        let output = LocalCRunner.run("""
        #include <stdio.h>

        struct Pair {
            int left;
            int right;
        };

        int sum(int values[], int count) {
            int total = 0;
            int i;
            for (i = 0; i < count; i++) {
                total = total + values[i];
            }
            return total;
        }

        int main(void) {
            int values[4] = { 1, 2, 3, 4 };
            int *third = &values[2];
            struct Pair pair;
            pair.left = *third;
            pair.right = sum(values, 4);
            printf("pointer=%d\\n", pair.left);
            printf("sum=%d\\n", pair.right);
            return 0;
        }
        """)

        #expect(output == "pointer=3\nsum=10\n")
    }

    @Test func localRunnerBlocksShellExecution() {
        let output = LocalCRunner.run("""
        #include <stdlib.h>

        int main(void) {
            system("echo unsafe");
            return 0;
        }
        """)

        #expect(output.contains("system() is not available in lilC local mode"))
    }

    @Test func localRunnerStopsRunawayPrograms() {
        let output = LocalCRunner.run("""
        #include <stdio.h>

        int main(void) {
            int i = 0;
            while (1) {
                i++;
            }
            return 0;
        }
        """)

        #expect(output.contains("program stopped: too many steps"))
    }

    @Test func localRunnerReadsScanfFromStdin() {
        let output = LocalCRunner.run("""
        #include <stdio.h>

        int main(void) {
            int count;
            double total = 0.0;
            double grade;
            int i;

            printf("How many grades? ");
            scanf("%d", &count);
            for (i = 0; i < count; i++) {
                printf("Grade: ");
                scanf("%lf", &grade);
                total = total + grade;
            }
            printf("GPA = %.1f\\n", total / count);
            return 0;
        }
        """, stdin: "2\n4.0\n3.0\n")

        #expect(output.contains("How many grades? "))
        #expect(output.contains("GPA = 3.5"))
    }

    @Test func localRunnerReadsGetcharFromStdin() {
        let output = LocalCRunner.run("""
        #include <stdio.h>

        int main(void) {
            int ch = getchar();
            printf("got=%c\\n", ch);
            return 0;
        }
        """, stdin: "Z")

        #expect(output == "got=Z\n")
    }

    @MainActor
    @Test func localWorkspaceCreatesAndPersistsRecentFiles() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-tests-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)

        workspace.createFile()
        workspace.updateCurrentName("calculator")
        workspace.updateCurrentCode("int main(void) { printf(\"ok\\n\"); }")

        #expect(workspace.currentFile.name == "calculator.c")
        #expect(workspace.allFiles.first?.name == "calculator.c")
        #expect((try? String(contentsOf: directory.appendingPathComponent("calculator.c"), encoding: .utf8)) == "int main(void) { printf(\"ok\\n\"); }")
    }

    @MainActor
    @Test func homeNewFileCreatesStandaloneNotInProject() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-tests-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)

        workspace.createFolder(named: "gpa")
        workspace.enterFolder(workspace.folders[0])
        workspace.createFile()
        #expect(workspace.currentFile.folderPath == "gpa")

        workspace.createStandaloneFile()
        #expect(workspace.currentFile.folderPath.isEmpty)
        #expect(workspace.currentFile.name.hasSuffix(".c"))
        #expect(!workspace.currentFile.relativePath.contains("/"))
    }

    @MainActor
    @Test func deleteFolderRemovesNestedFiles() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-tests-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)

        workspace.createFolder(named: "calc")
        let folder = workspace.folders.first { $0.name == "calc" }!
        workspace.enterFolder(folder)
        workspace.createFile()
        #expect(workspace.fileCount(in: folder) >= 1)
        workspace.deleteFolder(folder)
        #expect(workspace.folders.contains(where: { $0.name == "calc" }) == false)
        #expect(workspace.files.contains(where: { $0.folderPath == "calc" }) == false)
    }

    @MainActor
    @Test func agentCanCreateFolderAndFileAndSafeguardsBlockDelete() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-tests-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)

        #expect(workspace.agentCreateFolder("gpa").contains("Created"))
        #expect(workspace.agentWriteFile("gpa/main.c", contents: "int main(void) { return 0; }\n").contains("Created"))
        #expect(workspace.agentWriteFile("gpa/test_gpa.c", contents: "int main(void) { return 0; }\n").contains("Created"))
        #expect(workspace.agentDeleteFile("gpa/main.c", safeguardsOn: true).contains("Safeguards"))
        #expect(workspace.files.contains(where: { $0.relativePath == "gpa/main.c" }))
        #expect(workspace.agentDeleteFile("gpa/main.c", safeguardsOn: false).contains("Deleted"))
        #expect(workspace.files.contains(where: { $0.relativePath == "gpa/main.c" }) == false)
    }

    @MainActor
    @Test func localWorkspaceSearchesAllFilesAndRunsSelectedFile() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-tests-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)

        workspace.renameCurrentFile(to: "hello")
        workspace.updateCurrentCode("int main(void) { printf(\"hello\\n\"); return 0; }")
        workspace.createFile()
        workspace.renameCurrentFile(to: "pointers")
        workspace.updateCurrentCode("int main(void) { int *ptr; printf(\"pointer demo\\n\"); }")

        #expect(workspace.allFiles.count == 2)
        #expect(workspace.searchFiles(matching: "pointer").map(\.name) == ["pointers.c"])

        let hello = workspace.searchFiles(matching: "hello").first!
        workspace.select(hello)
        let output = LocalCRunner.run(hello.code)
        #expect(workspace.currentFile.name == "hello.c")
        #expect(output == "hello\n")
    }

    @MainActor
    @Test func liveRunUsesOnlyTheSelectedRootFile() async throws {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-live-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)

        workspace.renameCurrentFile(to: "hello")
        workspace.updateCurrentCode("""
        #include <stdio.h>
        int main(void) { printf("hello from lilC\\n"); return 0; }
        """)
        workspace.createFile()
        workspace.renameCurrentFile(to: "other")
        workspace.updateCurrentCode("""
        #include <stdio.h>
        int main(void) { printf("other program\\n"); return 0; }
        """)

        let hello = workspace.searchFiles(matching: "hello").first!
        workspace.select(hello)
        workspace.startLiveRun()
        try await Task.sleep(for: .milliseconds(800))
        #expect(workspace.isRunning == false)
        #expect(workspace.output.contains("hello from lilC"))
        #expect(!workspace.output.contains("other program"))
        #expect(!workspace.output.lowercased().contains("already defined"))
    }

    @MainActor
    @Test func liveRunExplainsMultipleMainsAfterMovingFileIntoProject() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-move-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)

        workspace.renameCurrentFile(to: "moved")
        workspace.updateCurrentCode("""
        #include <stdio.h>
        int main(void) {
            printf("moved program works\\n");
            return 0;
        }
        """)
        let moved = workspace.currentFile

        workspace.createFolder(named: "demo")
        workspace.browsePath = "demo"
        workspace.createFile() // Existing project starter also has main().
        #expect(workspace.moveFile(moved, into: "demo"))
        #expect(workspace.currentFile.relativePath == "demo/program.c")

        let movedInProject = workspace.files.first { $0.relativePath == "demo/moved.c" }!
        workspace.select(movedInProject)
        workspace.startLiveRun()

        #expect(!workspace.isRunning)
        #expect(workspace.output.contains("more than one main()"))
        #expect(workspace.output.contains("moved.c"))
        #expect(workspace.output.contains("program.c"))
    }

    @MainActor
    @Test func liveRunShowsBlockedSystemCall() async throws {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-sys-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)
        workspace.updateCurrentCode("""
        #include <stdlib.h>
        int main(void) { system("echo no"); return 0; }
        """)
        workspace.startLiveRun()
        try await Task.sleep(for: .milliseconds(400))
        #expect(workspace.output.contains("system() is not available"))
    }

    @MainActor
    @Test func liveRunStreamsOutputBeforeAndAfterInput() async throws {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-stdin-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)
        workspace.updateCurrentCode("""
        #include <stdio.h>
        int main(void) {
            int n;
            printf("before input\\n");
            scanf("%d", &n);
            printf("after input: %d\\n", n);
            return 0;
        }
        """)

        workspace.startLiveRun()
        try await Task.sleep(for: .milliseconds(400))
        #expect(workspace.isRunning)
        #expect(workspace.isWaitingForInput)
        #expect(workspace.output.contains("before input"))

        workspace.stdinLine = "7"
        workspace.submitStdinLine()
        try await Task.sleep(for: .milliseconds(600))
        #expect(!workspace.isRunning)
        #expect(workspace.output.contains("before input"))
        #expect(workspace.output.contains("after input: 7"))
    }

    @MainActor
    @Test func liveRunLinksExtraCFilesInsideAProject() async throws {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-proj-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)

        #expect(workspace.agentCreateFolder("demo").contains("Created"))
        #expect(workspace.agentWriteFile("demo/util.c", contents: "int twice(int n) { return n * 2; }\n").contains("Created"))
        #expect(workspace.agentWriteFile("demo/main.c", contents: """
        #include <stdio.h>
        int twice(int n);
        int main(void) {
            printf("%d\\n", twice(3));
            return 0;
        }
        """).contains("Created"))

        workspace.select(workspace.files.first { $0.relativePath == "demo/main.c" }!)
        workspace.startLiveRun()
        try await Task.sleep(for: .milliseconds(800))
        #expect(workspace.isRunning == false)
        #expect(workspace.output.contains("6"))
    }

    @MainActor
    @Test func liveRunIncludesQuotedHeaderFromTheProjectFolder() async throws {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-hdr-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)

        #expect(workspace.agentCreateFolder("demo").contains("Created"))
        #expect(workspace.agentWriteFile("demo/util.h", contents: """
        #ifndef UTIL_H
        #define UTIL_H
        #define TWICE(n) ((n) * 2)
        #endif
        """).contains("Created"))
        #expect(workspace.agentWriteFile("demo/main.c", contents: """
        #include <stdio.h>
        #include "util.h"
        int main(void) {
            printf("%d\\n", TWICE(4));
            return 0;
        }
        """).contains("Created"))

        workspace.select(workspace.files.first { $0.relativePath == "demo/main.c" }!)
        workspace.startLiveRun()
        try await Task.sleep(for: .milliseconds(800))
        #expect(workspace.isRunning == false)
        #expect(workspace.output.contains("8"))
    }

}

private let picoCAndRunnerErrorCatalog = [
    "';' expected",
    "semicolon expected",
    "'}' expected",
    "'{' expected",
    "brackets not closed",
    "')' expected",
    "'(' expected",
    "close bracket expected",
    "']' expected",
    "':' expected",
    "'while' expected",
    "comma expected",
    "identifier expected",
    "identifier not expected here",
    "expression expected",
    "invalid expression",
    "value expected",
    "statement expected",
    "operator not expected here",
    "value not expected here",
    "type not expected here",
    "illegal character '@'",
    "expected \"'\"",
    "unterminated string",
    "unterminated comment",
    "parse error",
    "bad type declaration",
    "bad function definition",
    "function definition expected",
    "function body expected",
    "\"filename.h\" expected",
    "#else without #if",
    "#endif without #if",
    "cannot open include file 'missing.h'",
    "cannot include '../secret.h' outside this project folder",
    "cannot read include file 'notes.h'",
    "include file 'big.h' is too large",
    "main() is not defined",
    "main is not a function - can't call it",
    "main() should return an int or void",
    "bad parameters to main()",
    "'score' is already defined",
    "data type 'Number' is already defined",
    "member 'x' already defined",
    "'score' is not defined",
    "'score' is undefined",
    "structure 'Point' isn't defined",
    "enum 'Color' isn't defined",
    "type 'Widget' isn't defined",
    "'temp' is out of scope",
    "doesn't have a member called 'score'",
    "need an structure or union member after '.'",
    "couldn't find goto label 'done'",
    "too many arguments to add()",
    "not enough arguments to 'add'",
    "macro arguments missing",
    "too many parameters (16 allowed)",
    "bad parameter",
    "bad argument",
    "too many arguments to scanf() - 10 max",
    "non-pointer argument to scanf() - argument 1 after format",
    "can't assign int from double",
    "can't set int from double in argument 1 of call to add()",
    "not an lvalue",
    "can't assign from an array of size 4 to one of size 2",
    "can't get the address of this",
    "can't initialize an incomplete type",
    "can't define a void variable",
    "array index must be an integer",
    "this int is not an array",
    "array index out of range",
    "too many array elements",
    "too many struct initializers",
    "value required in return",
    "value in return from a void function",
    "a void value isn't much use here",
    "no value returned from a function returning int",
    "first argument to '?' should be a number",
    "integer value expected instead of double",
    "int is not a function - can't call",
    "can't use '.' on something that's not a struct or union : it's a int",
    "invalid type in struct",
    "struct/union definitions can only be globals",
    "enum definitions can only be globals",
    "NULL pointer dereference",
    "a. invalid use of a NULL pointer",
    "division by zero",
    "modulo by zero",
    "invalid shift count",
    "program stopped: too many steps",
    "stack underrun",
    "stack is empty - can't go back",
    "(VariableAlloc) out of memory",
    "(PicocParse) out of memory",
    "(LexGetStringConstant) out of memory",
    "(LexTokenize TokenSpace == NULL) out of memory",
    "(ExpressionParseMacroCall) out of memory",
    "(ExpressionParseFunctionCall) out of memory",
    "(TableSetIdentifier) out of memory",
    "(VariableStackFrameAdd) out of memory",
    "out of memory reading 'big.h'",
    "abort",
    "assertion failed",
    "NULL pointer passed to strlen()",
    "invalid allocation size",
    "cannot open '/etc/passwd' outside this project folder",
    "system() is not available in lilC local mode",
    "not supported",
    "nested function definitions are not allowed",
    "invalid operation",
    "Write some C code, then run it.",
    "lilC could not start the local C engine.",
    "lilC could not capture program output.",
    "lilC could not run this C program.",
    "Cannot run this project: it has more than one main() function (a.c, b.c). Keep one main() and turn the others into helper functions.",
]

private struct EditorKeyboardHarness: View {
    @Binding var text: String

    var body: some View {
        CCodeEditor(
            text: $text,
            fileID: "main.c",
            isFocused: true,
            jump: nil,
            findVisible: false,
            findQuery: "",
            findIndex: 0,
            findEpoch: 0,
            overlayHeight: 0,
            onBeginEditing: {},
            onEndEditing: {}
        )
        .frame(width: 390, height: 500)
    }
}

private func firstTextView(in view: UIView) -> UITextView? {
    if let textView = view as? UITextView {
        return textView
    }
    for child in view.subviews {
        if let found = firstTextView(in: child) {
            return found
        }
    }
    return nil
}
