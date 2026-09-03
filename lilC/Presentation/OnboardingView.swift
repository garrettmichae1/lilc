import SwiftUI

struct OnboardingView: View {
    var finish: () -> Void

    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            topBar

            TabView(selection: $page) {
                runPage.tag(0)
                freePage.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            pageDots
                .padding(.bottom, 22)

            Button(action: advance) {
                Text(page == 0 ? OnboardingCopy.continueTitle : OnboardingCopy.getStartedTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppPalette.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppPalette.green, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("onboarding.primary")
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(AppPalette.background.ignoresSafeArea())
        .foregroundStyle(AppPalette.foreground)
        .lilCPreferredScheme(AppearanceStore.shared.colorWay)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.root")
    }

    private var topBar: some View {
        HStack {
            Spacer()
            if page == 0 {
                Button(OnboardingCopy.skipTitle, action: finish)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppPalette.green)
                    .accessibilityIdentifier("onboarding.skip")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .frame(height: 44)
    }

    private var runPage: some View {
        onboardingPage(
            graphic: { editorGraphic },
            headline: OnboardingCopy.page1Headline,
            line: OnboardingCopy.page1Line
        )
    }

    private var freePage: some View {
        onboardingPage(
            graphic: { freeGraphic },
            headline: OnboardingCopy.page2Headline,
            line: OnboardingCopy.page2Line
        )
    }

    private func onboardingPage<Graphic: View>(
        @ViewBuilder graphic: () -> Graphic,
        headline: String,
        line: String
    ) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            graphic()
            Spacer(minLength: 20)
            Text(headline)
                .font(.system(size: 28, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppPalette.foreground)
                .accessibilityIdentifier("onboarding.headline")
            Text(line)
                .font(.system(size: 17))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppPalette.silver)
                .padding(.top, 8)
                .accessibilityIdentifier("onboarding.line")
            Spacer(minLength: 12)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var editorGraphic: some View {
        VStack(spacing: 22) {
            logoMark(height: 92)
            OnboardingEditorMock()
        }
    }

    private var freeGraphic: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(AppPalette.green.opacity(AppearanceStore.shared.colorWay == .dark ? 0.14 : 0.10))
                    .frame(width: 168, height: 168)
                    .blur(radius: 2)
                Circle()
                    .stroke(AppPalette.green.opacity(0.28), lineWidth: 1.5)
                    .frame(width: 148, height: 148)
                logoMark(height: 120)
            }
        }
    }

    private func logoMark(height: CGFloat) -> some View {
        Image("LilCLogo")
            .renderingMode(.original)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(height: height)
            .clipShape(Circle())
            .shadow(color: AppPalette.green.opacity(0.22), radius: 18, y: 4)
            .accessibilityLabel("lilC")
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<OnboardingCopy.pageCount, id: \.self) { index in
                Circle()
                    .fill(index == page ? AppPalette.green : AppPalette.line)
                    .frame(width: 7, height: 7)
                    .shadow(color: index == page ? AppPalette.green.opacity(0.45) : .clear, radius: 4)
            }
        }
        .accessibilityHidden(true)
    }

    private func advance() {
        if page == 0 {
            withAnimation(.easeInOut(duration: 0.28)) {
                page = 1
            }
        } else {
            finish()
        }
    }
}

private struct OnboardingEditorMock: View {
    @State private var runGlow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("hello.c")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppPalette.foreground)
                Spacer()
                Text("RUN")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppPalette.onAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppPalette.green, in: RoundedRectangle(cornerRadius: 4))
                    .shadow(color: AppPalette.green.opacity(runGlow ? 0.55 : 0.18), radius: runGlow ? 10 : 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Rectangle()
                .fill(AppPalette.line.opacity(0.8))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 3) {
                mockLine("int main(void) {")
                mockLine("    printf(\"hello\\n\");")
                mockLine("}")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.editor)

            Rectangle()
                .fill(AppPalette.line.opacity(0.8))
                .frame(height: 1)

            HStack(spacing: 8) {
                Circle()
                    .fill(AppPalette.green)
                    .frame(width: 6, height: 6)
                    .shadow(color: AppPalette.green.opacity(0.7), radius: 3)
                Text("hello")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppPalette.green)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppPalette.line.opacity(0.7), lineWidth: 1)
        }
        .overlay {
            OnboardingScanlines()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .shadow(color: AppPalette.green.opacity(AppearanceStore.shared.colorWay == .dark ? 0.18 : 0.08), radius: 20, y: 8)
        .padding(.horizontal, 8)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                runGlow = true
            }
        }
    }

    private func mockLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(AppPalette.foreground)
    }
}

private struct OnboardingScanlines: View {
    var body: some View {
        Canvas { context, size in
            let opacity = AppearanceStore.shared.colorWay == .dark ? 0.06 : 0.035
            var y: CGFloat = 0
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(AppPalette.foreground.opacity(opacity)), lineWidth: 1)
                y += 3
            }
        }
        .allowsHitTesting(false)
    }
}
