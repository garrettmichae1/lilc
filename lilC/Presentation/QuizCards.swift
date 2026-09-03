import SwiftUI

struct QuizCardDeck: View {
    let title: String
    let quizzes: [CQuiz]
    let progress: QuizProgressStore
    var onHide: (() -> Void)?
    let open: (CQuiz, Bool) -> Void

    @State private var selection: String

    init(
        title: String,
        quizzes: [CQuiz],
        progress: QuizProgressStore,
        onHide: (() -> Void)? = nil,
        open: @escaping (CQuiz, Bool) -> Void
    ) {
        self.title = title
        self.quizzes = quizzes
        self.progress = progress
        self.onHide = onHide
        self.open = open
        let start = quizzes.first(where: { !progress.hasTaken($0.id) }) ?? quizzes.first
        _selection = State(initialValue: start?.id ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CurriculumDeckHeader(title: title, expanded: true, onToggle: onHide)
            TabView(selection: $selection) {
                ForEach(quizzes) { quiz in
                    QuizSwipeCard(
                        quiz: quiz,
                        attempt: progress.bestAttempt(for: quiz.id),
                        start: { open(quiz, false) },
                        review: { open(quiz, true) }
                    )
                    .padding(.horizontal, 4)
                    .tag(quiz.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 280)
            HStack(spacing: 6) {
                ForEach(quizzes) { quiz in
                    Circle()
                        .fill(pipColor(for: quiz))
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func pipColor(for quiz: CQuiz) -> Color {
        if progress.hasTaken(quiz.id) { return AppPalette.green }
        if quiz.id == selection { return AppPalette.foreground }
        return AppPalette.line
    }
}

private struct QuizSwipeCard: View {
    let quiz: CQuiz
    let attempt: QuizAttempt?
    let start: () -> Void
    let review: () -> Void

    var body: some View {
        Group {
            if attempt == nil {
                Button(action: start) {
                    chrome
                }
                .buttonStyle(.appHaptic)
            } else {
                chrome
            }
        }
        .accessibilityElement(children: attempt == nil ? .combine : .contain)
        .accessibilityAddTraits(attempt == nil ? .isButton : [])
    }

    private var chrome: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(quiz.kicker)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppPalette.green)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Spacer()
                if let attempt {
                    Text("\(attempt.score)/\(attempt.total)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppPalette.green)
                        .accessibilityLabel("Best score \(attempt.score) of \(attempt.total)")
                }
            }
            Text(quiz.title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppPalette.foreground)
                .fixedSize(horizontal: false, vertical: true)
            Text(quiz.goal)
                .font(.system(size: 16))
                .foregroundStyle(AppPalette.silver)
                .lineLimit(3)
            Spacer(minLength: 0)
            actions
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.line.opacity(0.7), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var actions: some View {
        if attempt == nil {
            Text("Start")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppPalette.green)
        } else {
            HStack(spacing: 20) {
                Button("Review", action: review)
                Button("Retake", action: start)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppPalette.green)
            .buttonStyle(.appHaptic)
        }
    }
}
