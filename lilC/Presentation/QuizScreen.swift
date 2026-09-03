import SwiftUI

struct QuizScreen: View {
    let quiz: CQuiz
    let progress: QuizProgressStore
    var startInReview: Bool
    let back: () -> Void

    @State private var index = 0
    @State private var selected: [Int]
    @State private var phase: Phase

    private enum Phase {
        case taking
        case results
        case review
    }

    init(quiz: CQuiz, progress: QuizProgressStore, startInReview: Bool, back: @escaping () -> Void) {
        self.quiz = quiz
        self.progress = progress
        self.startInReview = startInReview
        self.back = back
        let latest = progress.latestAttempt(for: quiz.id)
        if startInReview, let latest, latest.selectedIndexes.count == quiz.questions.count {
            _selected = State(initialValue: latest.selectedIndexes)
            _phase = State(initialValue: .review)
        } else {
            _selected = State(initialValue: Array(repeating: -1, count: quiz.questions.count))
            _phase = State(initialValue: .taking)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            bar
            if quiz.isReady, phase != .results, !quiz.questions.isEmpty {
                progressStrip
            }
            Group {
                if !quiz.isReady {
                    comingSoon
                } else {
                    switch phase {
                    case .taking:
                        takingBody
                    case .results:
                        resultsBody
                    case .review:
                        reviewBody
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppPalette.background)
        .foregroundStyle(AppPalette.foreground)
        .buttonStyle(.appHaptic)
    }

    private var progressStrip: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(AppPalette.line.opacity(0.7))
                Rectangle()
                    .fill(AppPalette.green)
                    .frame(width: geo.size.width * CGFloat(index + 1) / CGFloat(max(quiz.questions.count, 1)))
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }

    private var bar: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
            }
            .accessibilityLabel("Back")

            Text(quiz.title)
                .font(.system(size: 17, weight: .semibold))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if quiz.isReady, phase != .results, !quiz.questions.isEmpty {
                Text("\(index + 1) / \(quiz.questions.count)")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppPalette.silver)
                    .fixedSize()
                    .accessibilityLabel("Question \(index + 1) of \(quiz.questions.count)")
            }
        }
        .foregroundStyle(AppPalette.foreground)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(AppPalette.panel)
    }

    private var comingSoon: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Questions coming soon")
                .font(.system(size: 22, weight: .semibold))
            Text("This quiz card is ready. Drop the 20 questions into quizzes.json and they will show here.")
                .font(.system(size: 16))
                .foregroundStyle(AppPalette.silver)
            Spacer()
        }
        .padding(20)
    }

    private var takingBody: some View {
        VStack(spacing: 0) {
            ScrollView {
                questionCard(reviewing: false)
                    .padding(20)
            }
            nextBar
        }
    }

    private var reviewBody: some View {
        VStack(spacing: 0) {
            ScrollView {
                questionCard(reviewing: true)
                    .padding(20)
            }
            nextBar
        }
    }

    private var resultsBody: some View {
        let score = quiz.score(selectedIndexes: selected)
        return VStack(alignment: .leading, spacing: 16) {
            Text("\(score) / \(quiz.questions.count)")
                .font(.system(size: 44, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppPalette.green)
            Text(score == quiz.questions.count ? "Every answer correct." : "Review missed questions, or retake to improve.")
                .font(.system(size: 16))
                .foregroundStyle(AppPalette.silver)
            Spacer()
            Button("Review") {
                index = 0
                phase = .review
            }
            .buttonStyle(QuizPrimaryButtonStyle())
            Button("Retake") {
                beginTaking()
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(AppPalette.green)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(20)
    }

    private func questionCard(reviewing: Bool) -> some View {
        let question = quiz.questions[index]
        let picked = selected.indices.contains(index) ? selected[index] : -1
        return VStack(alignment: .leading, spacing: 16) {
            if let title = question.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppPalette.green)
                    .textCase(.uppercase)
                    .tracking(0.4)
            }
            Text(question.prompt)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppPalette.foreground)
            if let snippet = question.snippet, !snippet.isEmpty {
                Text(snippet)
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundStyle(AppPalette.foreground)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppPalette.editor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            VStack(spacing: 0) {
                ForEach(question.choices.indices, id: \.self) { choice in
                    Button {
                        guard !reviewing else { return }
                        selected[index] = choice
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            Text(Self.letter(choice))
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(letterColor(choice, picked: picked, correct: question.correctIndex, reviewing: reviewing))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle().stroke(letterColor(choice, picked: picked, correct: question.correctIndex, reviewing: reviewing), lineWidth: 1.5)
                                )
                            Text(question.choices[choice])
                                .font(.system(size: 17))
                                .foregroundStyle(AppPalette.foreground)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                        .background(choiceBackground(choice, picked: picked, correct: question.correctIndex, reviewing: reviewing))
                    }
                    .buttonStyle(.appHaptic)
                    .disabled(reviewing)
                    if choice < question.choices.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            if reviewing, let explanation = question.explanation, !explanation.isEmpty {
                Text(explanation)
                    .font(.system(size: 15))
                    .foregroundStyle(AppPalette.silver)
            }
        }
    }

    private var nextBar: some View {
        let last = index == quiz.questions.count - 1
        let canAdvance = selected.indices.contains(index) && selected[index] >= 0
        return VStack(spacing: 0) {
            Rectangle().fill(AppPalette.line.opacity(0.7)).frame(height: 1)
            Button(last ? (phase == .review ? "Done" : "Submit") : "Next") {
                if last {
                    if phase == .review {
                        phase = .results
                        return
                    }
                    finish()
                } else {
                    index += 1
                }
            }
            .buttonStyle(QuizPrimaryButtonStyle())
            .disabled(phase == .taking && !canAdvance)
            .padding(16)
            .background(AppPalette.panel)
        }
    }

    private func finish() {
        let attempt = QuizAttempt(
            quizId: quiz.id,
            selectedIndexes: selected,
            score: quiz.score(selectedIndexes: selected),
            total: quiz.questions.count,
            finishedAt: Date()
        )
        progress.record(attempt)
        AppReviewPromptStore.shared.noteLearningWin()
        phase = .results
    }

    private func beginTaking() {
        selected = Array(repeating: -1, count: quiz.questions.count)
        index = 0
        phase = .taking
    }

    private func letterColor(_ choice: Int, picked: Int, correct: Int, reviewing: Bool) -> Color {
        if reviewing {
            if choice == correct { return AppPalette.green }
            if choice == picked { return AppPalette.amber }
            return AppPalette.silver
        }
        return choice == picked ? AppPalette.green : AppPalette.silver
    }

    private func choiceBackground(_ choice: Int, picked: Int, correct: Int, reviewing: Bool) -> Color {
        guard reviewing else { return .clear }
        if choice == correct { return AppPalette.green.opacity(0.12) }
        if choice == picked { return AppPalette.amber.opacity(0.12) }
        return .clear
    }

    private static func letter(_ index: Int) -> String {
        let scalars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        guard scalars.indices.contains(index) else { return "\(index + 1)" }
        return String(scalars[index])
    }
}

private struct QuizPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold, design: .monospaced))
            .foregroundStyle(AppPalette.onAccent)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(AppPalette.green, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity((isEnabled ? 1 : 0.45) * (configuration.isPressed ? 0.85 : 1))
            .onChange(of: configuration.isPressed) { _, isPressed in
                guard isPressed, isEnabled else { return }
                AppHaptics.tap()
            }
    }
}
