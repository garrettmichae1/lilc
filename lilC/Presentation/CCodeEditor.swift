import SwiftUI
import UIKit

struct CaretJump: Equatable {
    var id: UUID
    var line: Int
    var column: Int

    init(line: Int, column: Int, id: UUID = UUID()) {
        self.id = id
        self.line = line
        self.column = column
    }
}

enum EditorSearch {
    static func nsMatches(in text: String, query: String) -> [NSRange] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        let haystack = text as NSString
        var matches: [NSRange] = []
        var search = NSRange(location: 0, length: haystack.length)
        while search.length > 0 {
            let found = haystack.range(of: needle, options: [.caseInsensitive], range: search)
            guard found.location != NSNotFound else { break }
            matches.append(found)
            let next = found.location + max(found.length, 1)
            if next >= haystack.length { break }
            search = NSRange(location: next, length: haystack.length - next)
        }
        return matches
    }
}

struct CCodeEditor: UIViewRepresentable {
    @Binding var text: String
    var fileID: String
    var isFocused: Bool
    var jump: CaretJump?
    var findVisible: Bool
    var findQuery: String
    var findIndex: Int
    var findEpoch: Int
    var overlayHeight: CGFloat
    var onBeginEditing: () -> Void
    var onEndEditing: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        textView.backgroundColor = .clear
        textView.text = text
        textView.font = Self.editorFont
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = .no
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.keyboardType = .asciiCapable
        textView.inputAssistantItem.leadingBarButtonGroups = []
        textView.inputAssistantItem.trailingBarButtonGroups = []
        textView.textContainer.lineFragmentPadding = 0
        let accessory = CSymbolAccessoryView()
        accessory.coordinator = context.coordinator
        textView.inputAccessoryView = accessory
        context.coordinator.accessory = accessory
        applyChrome(textView, context: context)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.textView = textView
        applyChrome(textView, context: context)

        if context.coordinator.fileID != fileID {
            context.coordinator.fileID = fileID
            if textView.text != text {
                textView.text = text
            }
            if jump == nil {
                let location = min(textView.selectedRange.location, (textView.text as NSString).length)
                textView.selectedRange = NSRange(location: location, length: 0)
            }
        } else if textView.text != text {
            let selected = textView.selectedRange
            textView.text = text
            let maxLength = (text as NSString).length
            let location = min(selected.location, maxLength)
            let length = min(selected.length, max(0, maxLength - location))
            textView.selectedRange = NSRange(location: location, length: length)
        }

        applyHighlights(textView)

        if let jump, context.coordinator.appliedJumpID != jump.id {
            context.coordinator.appliedJumpID = jump.id
            selectLine(jump.line, column: jump.column, in: textView)
            if !textView.isFirstResponder {
                textView.becomeFirstResponder()
            }
        }

        if findVisible,
           context.coordinator.appliedFindEpoch != findEpoch {
            context.coordinator.appliedFindEpoch = findEpoch
            let matches = EditorSearch.nsMatches(in: textView.text, query: findQuery)
            if matches.indices.contains(findIndex) {
                let range = matches[findIndex]
                textView.selectedRange = range
                textView.scrollRangeToVisible(range)
            }
        }

        if isFocused != textView.isFirstResponder {
            let shouldFocus = isFocused
            DispatchQueue.main.async {
                guard textView.window != nil else { return }
                if shouldFocus {
                    textView.becomeFirstResponder()
                } else if textView.isFirstResponder {
                    textView.resignFirstResponder()
                }
            }
        }
    }

    private func applyChrome(_ textView: UITextView, context: Context) {
        let foreground = UIColor(AppPalette.foreground)
        let accent = UIColor(AppPalette.green)
        textView.backgroundColor = UIColor(AppPalette.editor)
        textView.textColor = foreground
        textView.tintColor = accent
        textView.keyboardAppearance = AppearanceStore.shared.colorWay == .dark ? .dark : .default
        textView.textContainerInset = UIEdgeInsets(top: 8 + overlayHeight, left: 10, bottom: 8, right: 10)
        textView.typingAttributes = [
            .font: Self.editorFont,
            .foregroundColor: foreground
        ]
        context.coordinator.accessory?.applyPalette()
    }

    private func applyHighlights(_ textView: UITextView) {
        let storage = textView.textStorage
        let full = NSRange(location: 0, length: storage.length)
        guard full.length > 0 else { return }
        let selected = textView.selectedRange
        let foreground = UIColor(AppPalette.foreground)
        storage.beginEditing()
        storage.setAttributes([
            .font: Self.editorFont,
            .foregroundColor: foreground
        ], range: full)
        if findVisible {
            let matches = EditorSearch.nsMatches(in: textView.text, query: findQuery)
            let accent = UIColor(AppPalette.green)
            for (index, range) in matches.enumerated() {
                guard NSMaxRange(range) <= full.length else { continue }
                let color = index == findIndex
                    ? accent.withAlphaComponent(0.28)
                    : accent.withAlphaComponent(0.14)
                storage.addAttribute(.backgroundColor, value: color, range: range)
            }
        }
        storage.endEditing()
        let maxLength = storage.length
        let location = min(selected.location, maxLength)
        let length = min(selected.length, max(0, maxLength - location))
        textView.selectedRange = NSRange(location: location, length: length)
    }

    private func selectLine(_ line: Int, column: Int, in textView: UITextView) {
        let ns = textView.text as NSString
        let length = ns.length
        guard length > 0 else {
            textView.selectedRange = NSRange(location: 0, length: 0)
            return
        }
        var current = 1
        var start = 0
        while current < max(line, 1), start < length {
            let lineRange = ns.lineRange(for: NSRange(location: start, length: 0))
            let next = NSMaxRange(lineRange)
            if next <= start { break }
            start = next
            current += 1
        }
        let lineRange = ns.lineRange(for: NSRange(location: min(start, length - 1), length: 0))
        var contentLength = lineRange.length
        while contentLength > 0 {
            let last = ns.substring(with: NSRange(location: lineRange.location + contentLength - 1, length: 1))
            if last == "\n" || last == "\r" {
                contentLength -= 1
            } else {
                break
            }
        }
        let columnOffset = min(max(column, 1) - 1, contentLength)
        textView.selectedRange = NSRange(location: lineRange.location + columnOffset, length: max(0, contentLength - columnOffset))
        textView.scrollRangeToVisible(NSRange(location: lineRange.location, length: max(contentLength, 1)))
    }

    private static let editorFont = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CCodeEditor
        weak var textView: UITextView?
        weak var accessory: CSymbolAccessoryView?
        var fileID = ""
        var appliedJumpID: UUID?
        var appliedFindEpoch = -1

        init(parent: CCodeEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onBeginEditing()
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onEndEditing()
        }

        func insertSymbol(_ value: String) {
            textView?.insertText(value)
            if let textView {
                parent.text = textView.text ?? ""
            }
        }

        func indentSelection(outdent: Bool) {
            guard let textView else { return }
            let unit = "    "
            let ns = (textView.text ?? "") as NSString
            let selected = textView.selectedRange
            let inclusiveEnd = selected.length == 0
                ? selected.location
                : max(selected.location, selected.location + selected.length - 1)
            var starts: [Int] = []
            var cursor = ns.lineRange(for: NSRange(location: min(selected.location, ns.length), length: 0)).location
            while cursor <= inclusiveEnd, cursor <= ns.length {
                starts.append(cursor)
                let lineRange = ns.lineRange(for: NSRange(location: min(cursor, max(ns.length - 1, 0)), length: 0))
                let next = NSMaxRange(lineRange)
                if next <= cursor { break }
                cursor = next
                if cursor > inclusiveEnd || cursor >= ns.length { break }
            }
            let mutable = NSMutableString(string: ns as String)
            var totalDelta = 0
            var firstDelta = 0
            for (index, start) in starts.enumerated() {
                let adjusted = start + totalDelta
                if outdent {
                    let removed = Self.stripLeadingIndent(from: mutable, at: adjusted, max: unit.count)
                    if index == 0 { firstDelta = -removed }
                    totalDelta -= removed
                } else {
                    mutable.insert(unit, at: min(adjusted, mutable.length))
                    if index == 0 { firstDelta = unit.count }
                    totalDelta += unit.count
                }
            }
            textView.text = mutable as String
            let location = max(0, selected.location + firstDelta)
            let length = max(0, selected.length + totalDelta - firstDelta)
            let maxLength = (textView.text as NSString).length
            textView.selectedRange = NSRange(
                location: min(location, maxLength),
                length: min(length, max(0, maxLength - min(location, maxLength)))
            )
            parent.text = textView.text ?? ""
        }

        private static func stripLeadingIndent(from mutable: NSMutableString, at location: Int, max count: Int) -> Int {
            var removed = 0
            while removed < count, location < mutable.length {
                let character = mutable.substring(with: NSRange(location: location, length: 1))
                if character == " " {
                    mutable.deleteCharacters(in: NSRange(location: location, length: 1))
                    removed += 1
                } else if character == "\t", removed == 0 {
                    mutable.deleteCharacters(in: NSRange(location: location, length: 1))
                    return 1
                } else {
                    break
                }
            }
            return removed
        }
    }
}

final class CSymbolAccessoryView: UIInputView {
    weak var coordinator: CCodeEditor.Coordinator?
    private let stack = UIStackView()
    private var symbolButtons: [UIButton] = []
    private var indentButton: UIButton?
    private var outdentButton: UIButton?

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 40), inputViewStyle: .keyboard)
        allowsSelfSizing = true
        autoresizingMask = [.flexibleWidth]
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        layoutMargins = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)

        for symbol in ["{", "}", "(", ")", ";", "*", "&"] {
            let button = makeButton(title: symbol, label: symbol)
            button.addAction(UIAction { [weak self] _ in
                self?.coordinator?.insertSymbol(symbol)
            }, for: .touchUpInside)
            symbolButtons.append(button)
            stack.addArrangedSubview(button)
        }

        let outdent = makeButton(systemName: "decrease.indent", label: "Outdent")
        outdent.addAction(UIAction { [weak self] _ in
            self?.coordinator?.indentSelection(outdent: true)
        }, for: .touchUpInside)
        outdentButton = outdent
        stack.addArrangedSubview(outdent)

        let indent = makeButton(systemName: "increase.indent", label: "Indent")
        indent.addAction(UIAction { [weak self] _ in
            self?.coordinator?.indentSelection(outdent: false)
        }, for: .touchUpInside)
        indentButton = indent
        stack.addArrangedSubview(indent)

        applyPalette()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 40)
    }

    func applyPalette() {
        let ink = UIColor(AppPalette.foreground)
        let accent = UIColor(AppPalette.green)
        for button in symbolButtons {
            button.tintColor = ink
            button.setTitleColor(ink, for: .normal)
        }
        indentButton?.tintColor = accent
        outdentButton?.tintColor = accent
    }

    private func makeButton(title: String? = nil, systemName: String? = nil, label: String) -> UIButton {
        let button = UIButton(type: .system)
        button.accessibilityLabel = label
        if let title {
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 18, weight: .medium)
        }
        if let systemName {
            let image = UIImage(systemName: systemName)
            button.setImage(image, for: .normal)
            button.setPreferredSymbolConfiguration(
                UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold),
                forImageIn: .normal
            )
        }
        return button
    }
}

struct EditorFindBar: View {
    @Binding var query: String
    var matchIndex: Int
    var matchCount: Int
    var onPrevious: () -> Void
    var onNext: () -> Void
    var onClose: () -> Void
    @FocusState private var fieldFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            TextField("", text: $query)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .lilCFieldInk()
                .submitLabel(.search)
                .focused($fieldFocused)
                .onSubmit(onNext)
                .accessibilityLabel("Find in file")
            if !query.isEmpty {
                Text(matchCount == 0 ? "0" : "\(matchIndex + 1)/\(matchCount)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppPalette.silver)
                    .monospacedDigit()
                    .accessibilityLabel("\(matchCount) matches")
            }
            Button(action: onPrevious) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .disabled(matchCount == 0)
            .accessibilityLabel("Previous match")
            Button(action: onNext) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .disabled(matchCount == 0)
            .accessibilityLabel("Next match")
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("Close find")
        }
        .foregroundStyle(AppPalette.foreground)
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(AppPalette.panel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppPalette.line.opacity(0.7)).frame(height: 1)
        }
        .onAppear { fieldFocused = true }
    }
}
