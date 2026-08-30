import StoreKit
import SwiftUI

struct AgentPaywallScreen: View {
    let settings: AgentSettingsStore
    let back: () -> Void
    var openSettings: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: back) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                }
                Text("lilC Agent")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                Spacer()
            }
            .foregroundStyle(AppPalette.foreground)
            .padding(12)
            .background(AppPalette.panel)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("A coding agent on your iPhone.")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppPalette.foreground)

                    Text("Prompt in chat. The agent can create folders and C files, write tests, run PicoC, and brainstorm. Deleting stays locked until you turn safeguards off. The editor stays free.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.silver)
                        .lineSpacing(4)

                    VStack(alignment: .leading, spacing: 10) {
                        PaywallPoint(title: "Extra turns", detail: "The free pool is small so everyone can get a turn. This Apple subscription adds extra agent requests on lilC’s worker. No personal OpenAI keys.")
                        PaywallPoint(title: "Controls the IDE", detail: "Projects, files, tests, and Run — with delete locked by default.")
                        PaywallPoint(title: "Off in one switch", detail: "Settings → Show Agent. Turn it off and you only have the free IDE.")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(priceLine)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppPalette.green)
                        Text("Auto-renewable subscription billed by Apple. Cancel in Settings → Apple ID → Subscriptions. Payment is charged to your Apple ID. Unused trial portions, if any, are forfeited when you buy.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppPalette.silver)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppPalette.line.opacity(0.7)))

                    Button {
                        Task { await settings.purchase() }
                    } label: {
                        Text(settings.isPurchasing ? "WORKING…" : "SUBSCRIBE")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppPalette.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(AppPalette.green, in: RoundedRectangle(cornerRadius: 4))
                    }
                    .disabled(settings.isPurchasing)

                    Button("RESTORE PURCHASES") {
                        Task { await settings.restore() }
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppPalette.amber)
                    .frame(maxWidth: .infinity)

                    Button("Privacy, terms, and Apple EULA are in Settings", action: openSettings)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppPalette.silver)

                    if let storeMessage = settings.storeMessage {
                        Text(storeMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppPalette.amber)
                    }

                    #if DEBUG
                    Toggle(isOn: debugUnlockBinding) {
                        Text("DEBUG: preview Agent without StoreKit")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppPalette.silver)
                    }
                    .tint(AppPalette.green)
                    #endif
                }
                .padding(16)
            }
            .background(AppPalette.background)
        }
        .background(AppPalette.background)
        .task { await settings.loadStore() }
    }

    private var priceLine: String {
        if let product = settings.monthlyProduct {
            return "\(product.displayPrice) / month — lilC Agent"
        }
        return "lilC Agent monthly  ·  product lilc.agent.monthly"
    }

    #if DEBUG
    private var debugUnlockBinding: Binding<Bool> {
        Binding(
            get: { UserDefaults.standard.bool(forKey: "lilc.agent.debugUnlock") },
            set: { value in
                UserDefaults.standard.set(value, forKey: "lilc.agent.debugUnlock")
                Task { await settings.refreshEntitlements() }
            }
        )
    }
    #endif
}

private struct PaywallPoint: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(AppPalette.foreground)
            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppPalette.silver)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppPalette.line.opacity(0.7)))
    }
}

struct AgentChatScreen: View {
    let workspace: LocalCWorkspace
    let settings: AgentSettingsStore
    let back: () -> Void
    var openEditor: () -> Void = {}

    @State private var session: AgentSession
    @FocusState private var composerFocused: Bool

    init(workspace: LocalCWorkspace, settings: AgentSettingsStore, back: @escaping () -> Void, openEditor: @escaping () -> Void = {}) {
        self.workspace = workspace
        self.settings = settings
        self.back = back
        self.openEditor = openEditor
        _session = State(initialValue: AgentSession(workspace: workspace, settings: settings))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: back) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Agent")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                    Text("LILC")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppPalette.amber)
                }
                Spacer()
                Text(session.statusLine)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppPalette.silver)
                Button(action: openEditor) {
                    Text("CODE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppPalette.onAccent)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(AppPalette.green, in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(AppPalette.foreground)
            .padding(12)
            .background(AppPalette.panel)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(session.messages) { message in
                            AgentBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: session.messages.count) { _, _ in
                    if let last = session.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            .background(AppPalette.background)

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask the agent to write C…", text: $session.draft, prompt: Text("Ask the agent to write C…").foregroundStyle(AppPalette.silver), axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 14, design: .monospaced))
                    .lilCFieldInk()
                    .lineLimit(1...6)
                    .focused($composerFocused)
                    .padding(12)
                    .background(AppPalette.editor, in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppPalette.line))

                if session.isThinking {
                    Button("STOP", action: session.stop)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppPalette.onAccent)
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(AppPalette.amber, in: RoundedRectangle(cornerRadius: 4))
                } else {
                    Button("SEND", action: session.send)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppPalette.onAccent)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(AppPalette.green, in: RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(12)
            .background(AppPalette.panel)
        }
        .background(AppPalette.background)
    }
}

private struct AgentBubble: View {
    let message: AgentChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
            Text(message.text)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(AppPalette.foreground)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppPalette.line.opacity(0.65)))
    }

    private var label: String {
        switch message.role {
        case .user: "YOU"
        case .assistant: "AGENT"
        case .tool: (message.toolName ?? "tool").uppercased()
        case .system: "SYSTEM"
        }
    }

    private var accent: Color {
        switch message.role {
        case .user: AppPalette.green
        case .assistant: AppPalette.foreground
        case .tool: AppPalette.amber
        case .system: AppPalette.silver
        }
    }
}
