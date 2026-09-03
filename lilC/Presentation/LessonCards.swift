import SwiftUI

struct LessonCardDeck: View {
    let title: String
    let lessons: [FirstHourLesson]
    let progress: LessonProgressState
    var onHide: (() -> Void)?
    let open: (FirstHourLesson) -> Void

    @State private var selection: String

    init(
        title: String,
        lessons: [FirstHourLesson],
        progress: LessonProgressState,
        onHide: (() -> Void)? = nil,
        open: @escaping (FirstHourLesson) -> Void
    ) {
        self.title = title
        self.lessons = lessons
        self.progress = progress
        self.onHide = onHide
        self.open = open
        let current = lessons.first(where: { !progress.isComplete($0.id) }) ?? lessons.first
        _selection = State(initialValue: current?.id ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CurriculumDeckHeader(title: title, expanded: true, onToggle: onHide)
            TabView(selection: $selection) {
                ForEach(lessons) { lesson in
                    Button {
                        open(lesson)
                    } label: {
                        LessonSwipeCard(lesson: lesson, completed: progress.isComplete(lesson.id))
                    }
                    .buttonStyle(.appHaptic)
                    .padding(.horizontal, 4)
                    .tag(lesson.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 196)
            HStack(spacing: 6) {
                ForEach(lessons) { lesson in
                    Circle()
                        .fill(pipColor(for: lesson))
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func pipColor(for lesson: FirstHourLesson) -> Color {
        if progress.isComplete(lesson.id) { return AppPalette.green }
        if lesson.id == selection { return AppPalette.foreground }
        return AppPalette.line
    }
}

private struct LessonSwipeCard: View {
    let lesson: FirstHourLesson
    let completed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(lesson.kicker)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppPalette.green)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Spacer()
                if completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppPalette.green)
                        .accessibilityLabel("Completed")
                }
            }
            Text(lesson.title)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppPalette.foreground)
            Text(lesson.goal)
                .font(.system(size: 16))
                .foregroundStyle(AppPalette.silver)
                .lineLimit(3)
            Spacer(minLength: 0)
            Text(completed ? "Replay" : "Open")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppPalette.green)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.line.opacity(0.7), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

struct CurriculumDeckHeader: View {
    let title: String
    var expanded: Bool
    var onToggle: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppPalette.silver)
                .textCase(.uppercase)
                .tracking(0.4)
            Spacer(minLength: 8)
            if let onToggle {
                Button(action: onToggle) {
                    Text(expanded ? "−" : "+")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(AppPalette.silver)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.appHaptic)
                .accessibilityLabel(expanded ? "Hide Learn" : "Show Learn")
            }
        }
    }
}
