import SwiftUI

struct LinuxCoursePaywallCard: View {
    let course: LinuxCourse
    let store: LinuxCourseStore
    let restore: () -> Void
    let unlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CurriculumDeckHeader(title: "Course", expanded: true)
            VStack(alignment: .leading, spacing: 10) {
                Text("Course")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppPalette.green)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Text(course.title)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppPalette.foreground)
                Text(course.goal)
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.silver)
                Spacer(minLength: 0)
                HStack {
                    Text(store.priceText)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppPalette.foreground)
                    Spacer()
                    Button(store.isPurchasing ? "Working…" : "Unlock") {
                        unlock()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppPalette.green)
                    .disabled(store.isPurchasing)
                    Button("Restore") {
                        restore()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppPalette.green)
                    .disabled(store.isPurchasing)
                }
                if let message = store.storeMessage, !message.isEmpty {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(AppPalette.silver)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 196, alignment: .topLeading)
            .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppPalette.line.opacity(0.7), lineWidth: 1)
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("linux-course-paywall")
        }
    }
}

struct LinuxModuleDeck: View {
    let modules: [LinuxCourseModule]
    let progress: QuizProgressStore
    let open: (LinuxCourseModule) -> Void

    @State private var selection: String

    init(modules: [LinuxCourseModule], progress: QuizProgressStore, open: @escaping (LinuxCourseModule) -> Void) {
        self.modules = modules
        self.progress = progress
        self.open = open
        let start = modules.first(where: { !progress.hasTaken($0.quizId) }) ?? modules.first
        _selection = State(initialValue: start?.id ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CurriculumDeckHeader(title: LinuxCourseCatalog.title, expanded: true)
            TabView(selection: $selection) {
                ForEach(modules) { module in
                    Button {
                        open(module)
                    } label: {
                        LinuxModuleCard(module: module, attempt: progress.bestAttempt(for: module.quizId))
                    }
                    .buttonStyle(.appHaptic)
                    .padding(.horizontal, 4)
                    .tag(module.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 220)
            HStack(spacing: 6) {
                ForEach(modules) { module in
                    Circle()
                        .fill(pipColor(for: module))
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func pipColor(for module: LinuxCourseModule) -> Color {
        if progress.hasTaken(module.quizId) { return AppPalette.green }
        if module.id == selection { return AppPalette.foreground }
        return AppPalette.line
    }
}

private struct LinuxModuleCard: View {
    let module: LinuxCourseModule
    let attempt: QuizAttempt?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(module.kicker)
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
            Text(module.title)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppPalette.foreground)
            Text(module.goal)
                .font(.system(size: 16))
                .foregroundStyle(AppPalette.silver)
                .lineLimit(3)
            Spacer(minLength: 0)
            Text(attempt == nil ? "Open" : "Replay")
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
        .accessibilityIdentifier("linux-module-\(module.id)")
    }
}

struct LinuxStudyScreen: View {
    let module: LinuxCourseModule
    let back: () -> Void
    let takeQuiz: () -> Void

    @State private var pageIndex = 0

    private var page: LinuxCoursePage {
        module.pages[pageIndex]
    }

    private var last: Bool {
        pageIndex == module.pages.count - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            bar
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(page.kicker)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppPalette.green)
                        .textCase(.uppercase)
                        .tracking(0.4)
                    Text(page.title)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppPalette.foreground)
                    ForEach(Array(page.body.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(.system(size: 17))
                            .foregroundStyle(AppPalette.foreground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let diagram = page.diagram {
                        LinuxCourseDiagramView(kind: diagram)
                            .frame(maxWidth: .infinity)
                            .frame(height: 168)
                            .padding(14)
                            .background(AppPalette.editor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .accessibilityLabel(diagram.rawValue)
                    }
                }
                .padding(20)
            }
            bottomBar
        }
        .background(AppPalette.background)
        .foregroundStyle(AppPalette.foreground)
        .buttonStyle(.appHaptic)
        .accessibilityIdentifier("linux-study")
    }

    private var bar: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
            }
            .accessibilityLabel("Back")

            Text(module.title)
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(pageIndex + 1) / \(module.pages.count)")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppPalette.silver)
                .accessibilityLabel("Page \(pageIndex + 1) of \(module.pages.count)")

            if last {
                Button("Quiz", action: takeQuiz)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppPalette.green)
                    .accessibilityLabel("Take quiz")
            }
        }
        .foregroundStyle(AppPalette.foreground)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(AppPalette.panel)
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(AppPalette.line.opacity(0.7)).frame(height: 1)
            Button(last ? "Take quiz" : "Continue") {
                if last {
                    takeQuiz()
                } else {
                    pageIndex += 1
                }
            }
            .font(.system(size: 15, weight: .bold, design: .monospaced))
            .foregroundStyle(AppPalette.onAccent)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(AppPalette.green, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(16)
            .background(AppPalette.panel)
            .accessibilityIdentifier(last ? "linux-take-quiz" : "linux-continue")
        }
    }
}

struct LinuxCourseDiagramView: View {
    let kind: LinuxCourseDiagram

    var body: some View {
        Canvas { context, size in
            let ink = AppPalette.foreground
            let accent = AppPalette.green
            let muted = AppPalette.silver
            switch kind {
            case .unixTimeline:
                drawTimeline(context, size: size, ink: ink, accent: accent, muted: muted)
            case .layerStack:
                drawStack(
                    context,
                    size: size,
                    ink: ink,
                    accent: accent,
                    labels: ["Apps", "Shell", "libc", "Kernel", "Hardware"]
                )
            case .fhsTree:
                drawTree(context, size: size, ink: ink, accent: accent, muted: muted)
            case .shellProcess:
                drawFlow(
                    context,
                    size: size,
                    ink: ink,
                    accent: accent,
                    labels: ["Shell", "fork/exec", "Command"]
                )
            case .lsListing:
                drawListing(context, size: size, ink: ink, muted: muted)
            case .permissionGrid:
                drawPermissions(context, size: size, ink: ink, accent: accent, muted: muted)
            case .pipeBoxes:
                drawFlow(
                    context,
                    size: size,
                    ink: ink,
                    accent: accent,
                    labels: ["cmd", "|", "cmd", "|", "cmd"]
                )
            case .bootSequence:
                drawFlow(
                    context,
                    size: size,
                    ink: ink,
                    accent: accent,
                    labels: ["Firmware", "Loader", "Kernel", "pid 1"]
                )
            case .networkStack:
                drawStack(
                    context,
                    size: size,
                    ink: ink,
                    accent: accent,
                    labels: ["Process", "Socket", "Kernel IP", "NIC"]
                )
            case .scriptExec:
                drawFlow(
                    context,
                    size: size,
                    ink: ink,
                    accent: accent,
                    labels: ["#!", "kernel", "interpreter"]
                )
            }
        }
        .accessibilityHidden(true)
    }

    private func drawTimeline(_ context: GraphicsContext, size: CGSize, ink: Color, accent: Color, muted: Color) {
        let y = size.height * 0.42
        var line = Path()
        line.move(to: CGPoint(x: 12, y: y))
        line.addLine(to: CGPoint(x: size.width - 12, y: y))
        context.stroke(line, with: .color(accent), lineWidth: 2)
        let marks = [
            (0.08, "Unix"),
            (0.36, "POSIX"),
            (0.62, "GNU"),
            (0.88, "Linux"),
        ]
        for (t, label) in marks {
            let x = 12 + t * (size.width - 24)
            context.fill(Path(ellipseIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8)), with: .color(accent))
            context.draw(
                Text(label).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(ink),
                at: CGPoint(x: x, y: y + 22)
            )
        }
        context.draw(
            Text("1969 → 1991").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(muted),
            at: CGPoint(x: size.width / 2, y: 18)
        )
    }

    private func drawStack(_ context: GraphicsContext, size: CGSize, ink: Color, accent: Color, labels: [String]) {
        let inset: CGFloat = 16
        let gap: CGFloat = 6
        let count = CGFloat(labels.count)
        let h = (size.height - inset * 2 - gap * (count - 1)) / count
        for (i, label) in labels.enumerated() {
            let y = inset + CGFloat(i) * (h + gap)
            let rect = CGRect(x: inset, y: y, width: size.width - inset * 2, height: h)
            let path = Path(roundedRect: rect, cornerRadius: 6)
            context.stroke(path, with: .color(i == labels.count - 1 || i == labels.count - 2 ? accent : ink), lineWidth: 1.4)
            context.draw(
                Text(label).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(ink),
                at: CGPoint(x: size.width / 2, y: rect.midY)
            )
        }
    }

    private func drawTree(_ context: GraphicsContext, size: CGSize, ink: Color, accent: Color, muted: Color) {
        context.draw(
            Text("/").font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundStyle(accent),
            at: CGPoint(x: size.width / 2, y: 16)
        )
        let row = ["bin", "etc", "home", "usr", "var", "proc"]
        let w = (size.width - 24) / CGFloat(row.count)
        for (i, name) in row.enumerated() {
            let x = 12 + CGFloat(i) * w + w / 2
            var path = Path()
            path.move(to: CGPoint(x: size.width / 2, y: 28))
            path.addLine(to: CGPoint(x: x, y: 58))
            context.stroke(path, with: .color(muted), lineWidth: 1)
            context.draw(
                Text(name).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(ink),
                at: CGPoint(x: x, y: 74)
            )
        }
        context.draw(
            Text("one tree").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(muted),
            at: CGPoint(x: size.width / 2, y: size.height - 16)
        )
    }

    private func drawFlow(_ context: GraphicsContext, size: CGSize, ink: Color, accent: Color, labels: [String]) {
        let inset: CGFloat = 8
        let w = (size.width - inset * 2) / CGFloat(labels.count)
        let y = size.height / 2
        for (i, label) in labels.enumerated() {
            let x = inset + CGFloat(i) * w + w / 2
            if i > 0 {
                var path = Path()
                path.move(to: CGPoint(x: x - w / 2 + 4, y: y))
                path.addLine(to: CGPoint(x: x - 28, y: y))
                context.stroke(path, with: .color(accent), lineWidth: 1.4)
            }
            if label == "|" {
                context.draw(
                    Text("|").font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundStyle(accent),
                    at: CGPoint(x: x, y: y)
                )
            } else {
                let rect = CGRect(x: x - 32, y: y - 18, width: 64, height: 36)
                context.stroke(Path(roundedRect: rect, cornerRadius: 6), with: .color(ink), lineWidth: 1.3)
                context.draw(
                    Text(label).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(ink),
                    at: CGPoint(x: x, y: y)
                )
            }
        }
    }

    private func drawListing(_ context: GraphicsContext, size: CGSize, ink: Color, muted: Color) {
        let lines = [
            "drwxr-xr-x  home",
            "-rw-r--r--  notes",
            "-rwxr-xr-x  tool",
        ]
        for (i, line) in lines.enumerated() {
            context.draw(
                Text(line).font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(i == 0 ? muted : ink),
                at: CGPoint(x: size.width / 2, y: 36 + CGFloat(i) * 36),
                anchor: .center
            )
        }
    }

    private func drawPermissions(_ context: GraphicsContext, size: CGSize, ink: Color, accent: Color, muted: Color) {
        let cols = ["r", "w", "x"]
        let rows = ["owner", "group", "other"]
        let origin = CGPoint(x: 86, y: 28)
        let cell: CGFloat = 28
        for (c, name) in cols.enumerated() {
            context.draw(
                Text(name).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(accent),
                at: CGPoint(x: origin.x + CGFloat(c) * cell + 14, y: 14)
            )
        }
        for (r, name) in rows.enumerated() {
            context.draw(
                Text(name).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(muted),
                at: CGPoint(x: 40, y: origin.y + CGFloat(r) * cell + 14)
            )
            for c in 0..<3 {
                let rect = CGRect(
                    x: origin.x + CGFloat(c) * cell,
                    y: origin.y + CGFloat(r) * cell,
                    width: cell - 4,
                    height: cell - 4
                )
                context.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(ink), lineWidth: 1)
            }
        }
    }
}
