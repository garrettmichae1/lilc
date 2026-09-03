import SwiftUI

struct SettingsScreen: View {
    let workspace: LocalCWorkspace
    let appearance: AppearanceStore
    let agentSettings: AgentSettingsStore
    let back: () -> Void

    @State private var document: LegalDocument?
    @State private var confirmEraseAll = false
    @State private var customKey = ""
    @State private var githubConnected = false
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            settingsBar

            List {
                appearanceSection
                picoCSection
                filesSection
                if AgentRuntimeConfig.surfacesVisibleInThisRelease {
                    agentSection
                }
                rateSection
                legalSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listSectionSpacing(22)
            .environment(\.defaultMinListRowHeight, 44)
            .tint(AppPalette.green)
            .background(AppPalette.background)
        }
        .background(AppPalette.background)
        .sheet(item: $document) { item in
            LegalDocumentView(document: item)
        }
        .task {
            guard AgentRuntimeConfig.surfacesVisibleInThisRelease else { return }
            githubConnected = AgentKeychain.githubToken() != nil
            await agentSettings.loadStore()
        }
        .onReceive(NotificationCenter.default.publisher(for: .lilCGitHubChanged)) { _ in
            guard AgentRuntimeConfig.surfacesVisibleInThisRelease else { return }
            githubConnected = AgentKeychain.githubToken() != nil
        }
        .alert("Erase All Files?", isPresented: $confirmEraseAll) {
            Button("Erase All", role: .destructive) {
                workspace.deleteAllFiles()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes every C file on this iPhone. A starter file is created.")
        }
    }

    private var settingsBar: some View {
        HStack {
            Button(action: {
                AppHaptics.tap()
                back()
            }) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
            }
            .accessibilityLabel("Back")

            Text("Settings")
                .font(.headline)
            Spacer()
        }
        .foregroundStyle(AppPalette.foreground)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppPalette.panel)
    }

    private var appearanceSection: some View {
        Section {
            ForEach(AppColorWay.allCases) { way in
                Button {
                    appearance.colorWay = way
                } label: {
                    HStack {
                        Text(way.title)
                            .font(.body)
                            .foregroundStyle(AppPalette.foreground)
                        Spacer()
                        if appearance.colorWay == way {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppPalette.green)
                                .accessibilityHidden(true)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.appHapticSelect)
                .accessibilityLabel(way.title)
                .accessibilityAddTraits(appearance.colorWay == way ? [.isSelected] : [])
                .listRowBackground(AppPalette.card)
            }
            Toggle(isOn: Binding(
                get: { appearance.syntaxColoring },
                set: { appearance.syntaxColoring = $0 }
            )) {
                Text("Syntax Color")
                    .font(.body)
                    .foregroundStyle(AppPalette.foreground)
            }
            .listRowBackground(AppPalette.card)
            .accessibilityLabel("Syntax Color")
        } header: {
            Text("Appearance")
        } footer: {
            Text("lilC uses Light or Dark everywhere.")
        }
    }

    private var picoCSection: some View {
        Section {
            Text(Self.picoCExplanation)
                .font(.body)
                .foregroundStyle(AppPalette.foreground)
                .fixedSize(horizontal: false, vertical: true)
                .listRowBackground(AppPalette.card)
                .accessibilityLabel("About PicoC")
        } header: {
            Text("PicoC")
        }
    }

    private var filesSection: some View {
        Section {
            LabeledContent("On This iPhone") {
                Text("\(workspace.files.count)")
                    .font(.body)
                    .foregroundStyle(AppPalette.silver)
            }
            .font(.body)
            .listRowBackground(AppPalette.card)

            Button("Erase All Files", role: .destructive) {
                AppHaptics.tap()
                confirmEraseAll = true
            }
            .font(.body)
            .foregroundStyle(AppPalette.error)
            .listRowBackground(AppPalette.card)
        } header: {
            Text("Files")
        } footer: {
            Text("Removes every C file on this iPhone. A starter file is created.")
        }
    }

    private var rateSection: some View {
        Section {
            if let url = LegalURLs.writeReviewURL() {
                Link(destination: url) {
                    settingsLinkLabel("Write a Review")
                }
                .appHapticTap()
                .listRowBackground(AppPalette.card)
                .accessibilityLabel("Write a Review")
                .accessibilityIdentifier("write-review")
            }
        } footer: {
            Text("Writing a review helps others discover lilC :)")
        }
    }

    @ViewBuilder
    private var agentSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { agentSettings.agentsEnabled },
                set: { agentSettings.agentsEnabled = $0 }
            )) {
                Text("Show Agent")
                    .font(.body)
            }
            .listRowBackground(AppPalette.card)

            if agentSettings.agentsEnabled {
                Toggle(isOn: Binding(
                    get: { agentSettings.sharingConsent },
                    set: { agentSettings.sharingConsent = $0 }
                )) {
                    Text("Share with AI")
                        .font(.body)
                }
                .listRowBackground(AppPalette.card)

                Toggle(isOn: Binding(
                    get: { agentSettings.safeguardsOn },
                    set: { agentSettings.safeguardsOn = $0 }
                )) {
                    Text("Safeguards")
                        .font(.body)
                }
                .listRowBackground(AppPalette.card)

                LabeledContent("Plan") {
                    Text(agentSettings.isSubscribed ? "Extra turns" : "Free pool")
                        .font(.body)
                        .foregroundStyle(AppPalette.silver)
                }
                .font(.body)
                .listRowBackground(AppPalette.card)
            }
        } header: {
            Text("Agent")
        } footer: {
            if agentSettings.agentsEnabled {
                Text("Share with AI is required before a prompt is sent. Safeguards prevent the agent from deleting files.")
            } else {
                Text("Adds an Agent tab. Off for this learning release unless you turn it on.")
            }
        }

        if agentSettings.agentsEnabled {
            Section {
                if let githubStart = URL(string: AgentRuntimeConfig.gatewayURL + "/auth/github/start") {
                    Link("Connect GitHub", destination: githubStart)
                        .font(.body)
                        .appHapticTap()
                        .listRowBackground(AppPalette.card)
                }
                if githubConnected {
                    Button("Disconnect GitHub", role: .destructive) {
                        AppHaptics.tap()
                        AgentKeychain.deleteGitHubToken()
                    }
                    .font(.body)
                    .listRowBackground(AppPalette.card)
                }
                if !agentSettings.isSubscribed {
                    Button(agentSettings.isPurchasing ? "Working…" : "Extra Agent Turns") {
                        AppHaptics.tap()
                        Task { await agentSettings.purchase() }
                    }
                    .font(.body)
                    .disabled(agentSettings.isPurchasing)
                    .listRowBackground(AppPalette.card)
                    Button("Restore Purchases") {
                        AppHaptics.tap()
                        Task { await agentSettings.restore() }
                    }
                    .font(.body)
                    .listRowBackground(AppPalette.card)
                }
            }

            #if DEBUG
            Section {
                SecureField("Worker debug token", text: $customKey)
                    .font(.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .listRowBackground(AppPalette.card)
                Button("Save Token") {
                    AppHaptics.tap()
                    AgentKeychain.saveKey(customKey)
                    customKey = ""
                }
                .font(.body)
                .listRowBackground(AppPalette.card)
                Button("Remove Key", role: .destructive) {
                    AppHaptics.tap()
                    AgentKeychain.deleteKey()
                }
                .font(.body)
                .listRowBackground(AppPalette.card)
            } header: {
                Text("Debug")
            } footer: {
                Text("Debug only. Token for the lilC worker, not an OpenAI key.")
            }
            #endif
        }
    }

    private var legalSection: some View {
        Section {
            if LegalURLs.extraLegalRowsVisibleInThisRelease {
                Link(destination: LegalURLs.teachers) {
                    settingsLinkLabel("For teachers")
                }
                .appHapticTap()
                .listRowBackground(AppPalette.card)
                Link(destination: LegalURLs.webPlayground) {
                    settingsLinkLabel("Web playground")
                }
                .appHapticTap()
                .listRowBackground(AppPalette.card)
            }
            Link(destination: LegalURLs.privacy) {
                settingsLinkLabel("Privacy Policy")
            }
            .appHapticTap()
            .listRowBackground(AppPalette.card)
            Link(destination: LegalURLs.terms) {
                settingsLinkLabel("Terms of Use")
            }
            .appHapticTap()
            .listRowBackground(AppPalette.card)
            if LegalURLs.extraLegalRowsVisibleInThisRelease {
                legalRow("Licenses") { document = .licenses }
                Link(destination: LegalURLs.support) {
                    settingsLinkLabel("Email Support")
                }
                .appHapticTap()
                .listRowBackground(AppPalette.card)
            }
        } header: {
            Text("Legal")
        } footer: {
            Text("Version \(appVersion)")
        }
    }

    private func legalRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            settingsLinkLabel(title)
        }
        .buttonStyle(.appHaptic)
        .listRowBackground(AppPalette.card)
    }

    private func settingsLinkLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundStyle(AppPalette.foreground)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppPalette.silver)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
    }

    /// Learner-facing note. PicoC is an on-device interpreter, not a compiler.
    static let picoCExplanation = """
    PicoC is an interpreter, not a compiler. It runs C on this iPhone. Standard C libraries and extras a desktop compiler provides will not work here.
    """
}

private enum LegalDocument: String, Identifiable {
    case licenses

    var id: String { rawValue }
    var title: String { "Licenses" }

    var body: String {
        """
        PicoC
        Copyright (c) 2009-2011, Zik Saleeba
        Copyright (c) 2015, Joseph Poirier
        All rights reserved.

        Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

        * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
        * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
        * Neither the name of the Zik Saleeba nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

        THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.

        lilC source (except vendored PicoC) is licensed under the Apache License 2.0. See LICENSE, NOTICE, and TRADEMARKS.md in the project repository.
        """
    }
}

private struct LegalDocumentView: View {
    let document: LegalDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(document.body)
                    .font(.body)
                    .foregroundStyle(AppPalette.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .background(AppPalette.background)
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .lilCPreferredScheme(AppearanceStore.shared.colorWay)
    }
}
