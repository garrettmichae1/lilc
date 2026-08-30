import Foundation
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var localWorkspace = LocalCWorkspace()
    @State private var appearance = AppearanceStore.shared
    @State private var agentSettings = AgentSettingsStore.shared
    @State private var activeScreen: AppScreen = .home

    var body: some View {
        NavigationStack {
            Group {
                switch activeScreen {
            case .home:
                HomeScreen(
                    workspace: localWorkspace,
                    startLocal: {
                        localWorkspace.browsePath = localWorkspace.currentFile.folderPath
                        activeScreen = .local
                    },
                    openFiles: {
                        localWorkspace.browsePath = ""
                        activeScreen = .files
                    },
                    deleteFile: {
                        localWorkspace.browsePath = ""
                        activeScreen = .deletePicker
                    },
                    openSettings: { activeScreen = .settings },
                    openAgent: { activeScreen = .agent },
                    agentsVisible: agentSettings.showsAgentSurfaces
                )
            case .files:
                FilesScreen(workspace: localWorkspace, title: nil, primaryActionTitle: "OPEN", allowsCreate: true) { file in
                    localWorkspace.select(file)
                    activeScreen = .local
                } onFolder: { folder in
                    localWorkspace.enterFolder(folder)
                } back: {
                    if !localWorkspace.goUpFromBrowse() {
                        activeScreen = .home
                    }
                }
            case .deletePicker:
                DeleteFileScreen(workspace: localWorkspace) {
                    activeScreen = .home
                }
            case .settings:
                SettingsScreen(workspace: localWorkspace, appearance: appearance, agentSettings: agentSettings) {
                    activeScreen = .home
                }
            case .agent:
                agentDestination
            case .local:
                LocalModeScreen(workspace: localWorkspace, agentSettings: agentSettings) {
                    activeScreen = .home
                } openAgent: {
                    activeScreen = .agent
                }
            }
        }
        .background(AppPalette.background)
        .toolbar(.hidden, for: .navigationBar)
        .id(appearance.colorWay)
        .lilCPreferredScheme(appearance.colorWay)
        }
        .task {
            if AgentRuntimeConfig.surfacesVisibleInThisRelease {
                await agentSettings.loadStore()
            }
        }
    }

    @ViewBuilder
    private var agentDestination: some View {
        if !agentSettings.showsAgentSurfaces {
            Color.clear.onAppear { activeScreen = .home }
        } else {
            AgentChatScreen(
                workspace: localWorkspace,
                settings: agentSettings,
                back: { activeScreen = .home },
                openEditor: { activeScreen = .local }
            )
        }
    }

}

private enum AppScreen {
    case home
    case files
    case deletePicker
    case settings
    case local
    case agent
}

private struct HomeScreen: View {
    let workspace: LocalCWorkspace
    let startLocal: () -> Void
    let openFiles: () -> Void
    let deleteFile: () -> Void
    let openSettings: () -> Void
    let openAgent: () -> Void
    let agentsVisible: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    HomeHeader(openSettings: openSettings)

                    Button(action: startLocal) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Open editor")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(AppPalette.onAccent)
                                Text(workspace.currentFile.name)
                                    .font(.system(size: 15))
                                    .foregroundStyle(AppPalette.onAccent.opacity(0.85))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppPalette.onAccent.opacity(0.8))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .background(AppPalette.green, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Projects")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppPalette.silver)
                                .textCase(.uppercase)
                                .tracking(0.4)
                            Spacer()
                            Button("See all", action: openFiles)
                                .font(.system(size: 15))
                                .foregroundStyle(AppPalette.green)
                        }
                        RecentProjectsList(projects: workspace.recentProjects, open: { folder in
                            workspace.openProject(folder)
                            startLocal()
                        })
                    }

                    VStack(spacing: 0) {
                        HomeActionRow(title: "New file", detail: "A single C file") {
                            workspace.createStandaloneFile()
                            startLocal()
                        }
                        Divider().padding(.leading, 16)
                        HomeActionRow(title: "Open", detail: "Files and projects", action: openFiles)
                        Divider().padding(.leading, 16)
                        HomeActionRow(title: "Delete", detail: "File or folder", isDestructive: true, action: deleteFile)
                    }
                    .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }

            HomeTabBar(openHome: {}, openFiles: openFiles, openAgent: agentsVisible ? openAgent : nil)
        }
        .background(AppPalette.background)
        .foregroundStyle(AppPalette.foreground)
    }
}

private struct HomeHeader: View {
    let openSettings: () -> Void

    var body: some View {
        HStack {
            Image("LilCLogo")
                .renderingMode(.original)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(height: 44)
                .accessibilityLabel("lilC")
            Spacer()
            Button("Settings", action: openSettings)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppPalette.green)
        }
    }
}

private struct RecentProjectsList: View {
    let projects: [LocalCFolder]
    let open: (LocalCFolder) -> Void

    var body: some View {
        if projects.isEmpty {
            Text("No projects yet. Create a folder in Files.")
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.silver)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            VStack(spacing: 0) {
                ForEach(projects) { folder in
                    Button {
                        open(folder)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppPalette.amber)
                                .frame(width: 32, height: 32)
                                .background(AppPalette.panel)
                                .overlay(Rectangle().stroke(AppPalette.line.opacity(0.8)))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(folder.name)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(AppPalette.foreground)
                                Text("Project")
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppPalette.silver)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppPalette.silver)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 52)
                    }
                    .buttonStyle(.plain)
                    if folder.id != projects.last?.id {
                        Rectangle()
                            .fill(AppPalette.line.opacity(0.8))
                            .frame(height: 1)
                            .padding(.leading, 54)
                    }
                }
            }
            .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct HomeActionRow: View {
    let title: String
    let detail: String
    var isDestructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17))
                        .foregroundStyle(isDestructive ? AppPalette.amber : AppPalette.foreground)
                    Text(detail)
                        .font(.system(size: 15))
                        .foregroundStyle(AppPalette.silver)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppPalette.silver)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

private struct HomeTabBar: View {
    let openHome: () -> Void
    let openFiles: () -> Void
    var openAgent: (() -> Void)? = nil

    var body: some View {
        HStack {
            HomeTabItem(title: "HOME", icon: .home, active: true, action: openHome)
            HomeTabItem(title: "FILES", icon: .files, active: false, action: openFiles)
            if let openAgent {
                Button(action: openAgent) {
                    VStack(spacing: 5) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 22, height: 20)
                        Text("AGENT")
                            .font(AppTypography.terminal(size: 10, weight: .bold))
                    }
                    .foregroundStyle(AppPalette.silver)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(AppPalette.panel)
        .overlay(alignment: .top) {
            Rectangle().fill(AppPalette.line).frame(height: 1)
        }
    }
}

private struct HomeTabItem: View {
    let title: String
    let icon: PixelTabIcon.Kind
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                PixelTabIcon(kind: icon, active: active)
                    .frame(width: 22, height: 20)
                Text(title)
                    .font(AppTypography.terminal(size: 10, weight: .bold))
            }
            .foregroundStyle(active ? AppPalette.green : AppPalette.silver)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct PixelTabIcon: View {
    enum Kind {
        case home
        case files
    }

    let kind: Kind
    let active: Bool

    var body: some View {
        Canvas { context, size in
            let color = active ? AppPalette.green : AppPalette.silver
            context.stroke(Path { path in
                switch kind {
                case .home:
                    let unit = min(size.width / 11, size.height / 10)
                    let x = (size.width - unit * 11) / 2
                    let y = (size.height - unit * 10) / 2
                    path.move(to: CGPoint(x: x + unit * 1, y: y + unit * 5))
                    path.addLine(to: CGPoint(x: x + unit * 5.5, y: y + unit * 1))
                    path.addLine(to: CGPoint(x: x + unit * 10, y: y + unit * 5))
                    path.move(to: CGPoint(x: x + unit * 2.5, y: y + unit * 4.5))
                    path.addLine(to: CGPoint(x: x + unit * 2.5, y: y + unit * 9))
                    path.addLine(to: CGPoint(x: x + unit * 8.5, y: y + unit * 9))
                    path.addLine(to: CGPoint(x: x + unit * 8.5, y: y + unit * 4.5))
                    path.move(to: CGPoint(x: x + unit * 5, y: y + unit * 9))
                    path.addLine(to: CGPoint(x: x + unit * 5, y: y + unit * 6.5))
                    path.addLine(to: CGPoint(x: x + unit * 6.7, y: y + unit * 6.5))
                    path.addLine(to: CGPoint(x: x + unit * 6.7, y: y + unit * 9))
                case .files:
                    let unit = min(size.width / 12, size.height / 9)
                    let x = (size.width - unit * 12) / 2
                    let y = (size.height - unit * 9) / 2
                    path.move(to: CGPoint(x: x + unit * 1, y: y + unit * 2))
                    path.addLine(to: CGPoint(x: x + unit * 4.4, y: y + unit * 2))
                    path.addLine(to: CGPoint(x: x + unit * 5.7, y: y + unit * 3.5))
                    path.addLine(to: CGPoint(x: x + unit * 11, y: y + unit * 3.5))
                    path.addLine(to: CGPoint(x: x + unit * 11, y: y + unit * 8))
                    path.addLine(to: CGPoint(x: x + unit * 1, y: y + unit * 8))
                    path.closeSubpath()
                    path.move(to: CGPoint(x: x + unit * 1, y: y + unit * 4.8))
                    path.addLine(to: CGPoint(x: x + unit * 11, y: y + unit * 4.8))
                }
            }, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter))
        }
        .accessibilityHidden(true)
    }
}

private struct FilesScreen: View {
    let workspace: LocalCWorkspace
    var title: String? = nil
    let primaryActionTitle: String
    var allowsCreate: Bool = true
    let select: (LocalCFile) -> Void
    var onFolder: (LocalCFolder) -> Void
    let back: () -> Void
    @State private var searchText = ""
    @State private var showCreateOptions = false
    @State private var showFolderName = false
    @State private var folderName = ""
    @FocusState private var searchFocused: Bool

    private var matches: [LocalBrowserEntry] {
        workspace.searchBrowser(matching: searchText)
    }

    private var heading: String {
        title ?? workspace.browseTitle
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: back) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(heading)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                    if !workspace.browsePath.isEmpty {
                        Text(workspace.browsePath)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppPalette.silver)
                    }
                }
                Spacer()
                if allowsCreate {
                    Button {
                        showCreateOptions = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                    }
                }
            }
            .foregroundStyle(AppPalette.foreground)
            .padding(12)
            .background(AppPalette.panel)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppPalette.green)
                TextField("Search files or folders", text: $searchText, prompt: Text("Search files or folders").foregroundStyle(AppPalette.silver))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lilCFieldInk()
                    .focused($searchFocused)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchFocused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(AppPalette.foreground.opacity(0.75))
                }
            }
            .foregroundStyle(AppPalette.foreground)
            .padding(.horizontal, 12)
            .frame(height: 46)
            .background(AppPalette.card)
            .overlay(alignment: .bottom) {
                Rectangle().fill(AppPalette.line.opacity(0.7)).frame(height: 1)
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    if matches.isEmpty {
                        VStack(spacing: 10) {
                            Text("No files found.")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppPalette.foreground)
                            Text(allowsCreate ? "Tap + to create a C file, header, or project." : "Try another search.")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppPalette.foreground.opacity(0.72))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 42)
                    } else {
                        ForEach(matches) { entry in
                            switch entry {
                            case .folder(let folder):
                                FolderBrowserRow(
                                    folder: folder,
                                    subtitle: workspace.browsePath.isEmpty ? "Project folder" : "Folder in this project"
                                ) {
                                    onFolder(folder)
                                }
                                .dropDestination(for: String.self) { paths, _ in
                                    var moved = false
                                    for path in paths {
                                        if let file = workspace.files.first(where: { $0.relativePath == path }) {
                                            moved = workspace.moveFile(file, into: folder.relativePath) || moved
                                        }
                                    }
                                    return moved
                                }
                            case .file(let file):
                                FileBrowserRow(file: file, actionTitle: primaryActionTitle) {
                                    select(file)
                                }
                                .draggable(file.relativePath)
                            }
                        }
                    }
                }
                .padding(12)
            }
            .background(AppPalette.background)
            .dropDestination(for: String.self) { paths, _ in
                var moved = false
                for path in paths {
                    if let file = workspace.files.first(where: { $0.relativePath == path }) {
                        moved = workspace.moveFile(file, into: workspace.browsePath) || moved
                    }
                }
                return moved
            }
        }
        .background(AppPalette.background)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { searchFocused = false }
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
            }
        }
        .confirmationDialog("Create", isPresented: $showCreateOptions, titleVisibility: .visible) {
            Button(workspace.browsePath.isEmpty ? "New standalone C file" : "New C file in this project") {
                workspace.createFile()
                searchText = ""
            }
            Button("New Header") {
                workspace.createHeader()
                searchText = ""
            }
            Button(workspace.browsePath.isEmpty ? "New Project" : "New Folder") {
                folderName = ""
                showFolderName = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert(workspace.browsePath.isEmpty ? "New Project" : "New Folder", isPresented: $showFolderName) {
            TextField(workspace.browsePath.isEmpty ? "project-name" : "folder-name", text: $folderName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Create") {
                workspace.createFolder(named: folderName)
                folderName = ""
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if workspace.browsePath.isEmpty {
                Text("A folder is a project. Open it to add more .c and .h files. Home → New File still creates a single file at the top level.")
            } else {
                Text("Nested folders stay inside this project.")
            }
        }
    }
}

private struct FolderBrowserRow: View {
    let folder: LocalCFolder
    var subtitle: String = "Project folder"
    var openTitle: String = "OPEN"
    var onDelete: (() -> Void)? = nil
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppPalette.amber)
                        .frame(width: 38, height: 38)
                        .background(AppPalette.panel)
                        .overlay(Rectangle().stroke(AppPalette.line.opacity(0.8)))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(folder.name)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppPalette.foreground)
                        Text("\(folder.relativePath)  *  \(folder.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppPalette.foreground.opacity(0.72))
                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppPalette.foreground.opacity(0.64))
                    }
                    Spacer(minLength: 8)
                    Text(openTitle)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppPalette.green)
                }
            }
            .buttonStyle(.plain)

            if let onDelete {
                Button("DELETE", action: onDelete)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppPalette.amber)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(AppPalette.line.opacity(0.7)))
    }
}

private struct DeleteFileScreen: View {
    let workspace: LocalCWorkspace
    let back: () -> Void
    @State private var searchText = ""
    @State private var pendingFile: LocalCFile?
    @State private var pendingFolder: LocalCFolder?
    @FocusState private var searchFocused: Bool

    private var matches: [LocalBrowserEntry] {
        workspace.searchBrowser(matching: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    if !workspace.goUpFromBrowse() {
                        back()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Delete")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                    if !workspace.browsePath.isEmpty {
                        Text(workspace.browsePath)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppPalette.silver)
                    }
                }
                Spacer()
            }
            .foregroundStyle(AppPalette.foreground)
            .padding(12)
            .background(AppPalette.panel)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppPalette.amber)
                TextField("Search files or folders", text: $searchText, prompt: Text("Search files or folders").foregroundStyle(AppPalette.silver))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lilCFieldInk()
                    .focused($searchFocused)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchFocused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(AppPalette.foreground.opacity(0.75))
                }
            }
            .foregroundStyle(AppPalette.foreground)
            .padding(.horizontal, 12)
            .frame(height: 46)
            .background(AppPalette.card)
            .overlay(alignment: .bottom) {
                Rectangle().fill(AppPalette.line.opacity(0.7)).frame(height: 1)
            }

            Text("Open a folder to delete files inside it, or delete the folder to remove the whole project.")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(AppPalette.amber)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppPalette.background)

            ScrollView {
                LazyVStack(spacing: 10) {
                    if matches.isEmpty {
                        VStack(spacing: 10) {
                            Text("Nothing here.")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppPalette.foreground)
                            Text("Loose files live at the top level. Projects are folders.")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppPalette.foreground.opacity(0.72))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 42)
                    } else {
                        ForEach(matches) { entry in
                            switch entry {
                            case .folder(let folder):
                                FolderBrowserRow(
                                    folder: folder,
                                    subtitle: workspace.browsePath.isEmpty ? "Deletes this project if you choose DELETE" : "Nested folder",
                                    openTitle: "OPEN",
                                    onDelete: { pendingFolder = folder }
                                ) {
                                    workspace.enterFolder(folder)
                                    searchText = ""
                                }
                            case .file(let file):
                                FileBrowserRow(file: file, actionTitle: "DELETE", actionTint: AppPalette.amber) {
                                    pendingFile = file
                                }
                            }
                        }
                    }
                }
                .padding(12)
            }
            .background(AppPalette.background)
        }
        .background(AppPalette.background)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { searchFocused = false }
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
            }
        }
        .alert(
            "Delete \(pendingFile?.name ?? "this file")?",
            isPresented: Binding(
                get: { pendingFile != nil },
                set: { if !$0 { pendingFile = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let file = pendingFile {
                    workspace.delete(file)
                }
                pendingFile = nil
            }
            Button("Cancel", role: .cancel) {
                pendingFile = nil
            }
        } message: {
            Text("This permanently removes \(pendingFile?.relativePath ?? "this file") from this iPhone.")
        }
        .alert(
            "Delete folder \(pendingFolder?.name ?? "")?",
            isPresented: Binding(
                get: { pendingFolder != nil },
                set: { if !$0 { pendingFolder = nil } }
            )
        ) {
            Button("Delete Folder", role: .destructive) {
                if let folder = pendingFolder {
                    workspace.deleteFolder(folder)
                }
                pendingFolder = nil
            }
            Button("Cancel", role: .cancel) {
                pendingFolder = nil
            }
        } message: {
            let count = pendingFolder.map { workspace.fileCount(in: $0) } ?? 0
            Text("This permanently deletes the folder and \(count) file\(count == 1 ? "" : "s") inside it.")
        }
    }
}

private struct FileBrowserRow: View {
    let file: LocalCFile
    let actionTitle: String
    var actionTint: Color = AppPalette.green
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(file.isHeader ? ".h" : ".c")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppPalette.foreground.opacity(0.84))
                    .frame(width: 38, height: 38)
                    .background(AppPalette.panel)
                    .overlay(Rectangle().stroke(AppPalette.line.opacity(0.8)))

                VStack(alignment: .leading, spacing: 5) {
                    Text(file.folderPath.isEmpty ? file.name : file.relativePath)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppPalette.foreground)
                    Text("\(file.updatedAt.formatted(date: .abbreviated, time: .shortened))  *  \(file.sizeText)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppPalette.foreground.opacity(0.72))
                    Text(file.codePreview)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppPalette.foreground.opacity(0.64))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(actionTitle)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(actionTint)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(AppPalette.line.opacity(0.7)))
        }
        .buttonStyle(.plain)
    }
}

private struct LocalModeScreen: View {
    let workspace: LocalCWorkspace
    let agentSettings: AgentSettingsStore
    let back: () -> Void
    var openAgent: () -> Void = {}
    @State private var draftFileName = ""
    @State private var outputExpanded = true
    @State private var findVisible = false
    @State private var findQuery = ""
    @State private var findIndex = 0
    @State private var findEpoch = 0
    @State private var caretJump: CaretJump?
    @FocusState private var focusedLocalField: LocalEditorField?

    private var findMatches: [NSRange] {
        EditorSearch.nsMatches(in: workspace.currentFile.code, query: findQuery)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: back) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                }
                Text(workspace.currentProjectPath.isEmpty ? "Local Mode" : URL(fileURLWithPath: workspace.currentProjectPath).lastPathComponent)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                Spacer()
                Button {
                    workspace.browsePath = workspace.currentProjectPath
                    workspace.createFile()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(AppPalette.green)
                ShareLink(item: workspace.currentFileURL) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(AppPalette.green)
                Button(action: toggleFind) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(findVisible ? AppPalette.foreground : AppPalette.green)
                .accessibilityLabel("Find")
                if agentSettings.showsAgentSurfaces {
                    Button(action: openAgent) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(AppPalette.green)
                    .accessibilityLabel("Agent")
                }
                if workspace.isRunning {
                    Button("STOP") {
                        workspace.stopLiveRun()
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppPalette.onAccent)
                    .padding(.horizontal, 16)
                    .frame(height: 34)
                    .background(AppPalette.amber, in: RoundedRectangle(cornerRadius: 4))
                } else {
                    Button("RUN") {
                        dismissKeyboard()
                        commitFileName()
                        workspace.runCurrentFile()
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppPalette.onAccent)
                    .padding(.horizontal, 16)
                    .frame(height: 34)
                    .background(AppPalette.green, in: RoundedRectangle(cornerRadius: 4))
                }
            }
            .foregroundStyle(AppPalette.foreground)
            .padding(12)
            .background(AppPalette.panel)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(workspace.projectFiles) { file in
                        Button {
                            dismissKeyboard()
                            commitFileName()
                            workspace.select(file)
                            draftFileName = workspace.currentFile.name
                        } label: {
                            Text(file.name)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(file.id == workspace.selectedFileID ? AppPalette.onAccent : AppPalette.foreground)
                                .padding(.horizontal, 12)
                                .frame(height: 32)
                                .background(file.id == workspace.selectedFileID ? AppPalette.green : AppPalette.card, in: RoundedRectangle(cornerRadius: 4))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppPalette.line.opacity(0.75)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(AppPalette.background)

            HStack(spacing: 8) {
                TextField("hello.c", text: $draftFileName, prompt: Text("hello.c").foregroundStyle(AppPalette.silver))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lilCFieldInk()
                    .focused($focusedLocalField, equals: .fileName)
                    .onSubmit(commitFileName)
                Button(action: commitFileName) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 34, height: 30)
                }
                .foregroundStyle(AppPalette.onAccent)
                .background(AppPalette.green, in: RoundedRectangle(cornerRadius: 4))
                KeyboardHideButton(action: dismissKeyboard)
            }
            .foregroundStyle(AppPalette.green)
            .padding(12)
            .background(AppPalette.card)

            ZStack(alignment: .top) {
                CCodeEditor(
                    text: Binding(
                        get: { workspace.currentFile.code },
                        set: { workspace.updateCurrentCode($0) }
                    ),
                    fileID: workspace.selectedFileID,
                    isFocused: focusedLocalField == .editor,
                    jump: caretJump,
                    findVisible: findVisible,
                    findQuery: findQuery,
                    findIndex: findIndex,
                    findEpoch: findEpoch,
                    overlayHeight: findVisible ? 36 : 0,
                    onBeginEditing: { focusedLocalField = .editor },
                    onEndEditing: {
                        if focusedLocalField == .editor {
                            focusedLocalField = nil
                        }
                    }
                )
                .background(AppPalette.editor)

                if findVisible {
                    EditorFindBar(
                        query: $findQuery,
                        matchIndex: findIndex,
                        matchCount: findMatches.count,
                        onPrevious: { stepFind(-1) },
                        onNext: { stepFind(1) },
                        onClose: closeFind
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("OUTPUT")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppPalette.green)
                    if workspace.isWaitingForInput {
                        RunStatusBadge(text: "WAITING FOR INPUT", color: AppPalette.amber, pulsing: true)
                    } else if workspace.isRunning {
                        RunStatusBadge(text: "RUNNING", color: AppPalette.green, pulsing: false)
                    } else if workspace.lastRunFailed {
                        if workspace.lastErrorJump != nil {
                            Button(action: jumpToError) {
                                RunStatusBadge(text: "ERROR", color: AppPalette.error, pulsing: false)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Jump to error")
                        } else {
                            RunStatusBadge(text: "ERROR", color: AppPalette.error, pulsing: false)
                        }
                    }
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            outputExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(outputExpanded ? "HIDE" : "SHOW")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                            Image(systemName: outputExpanded ? "chevron.down" : "chevron.up")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(AppPalette.silver)
                    }
                    .buttonStyle(.plain)
                    KeyboardHideButton(action: dismissKeyboard)
                }
                if outputExpanded {
                    outputBody
                    if workspace.isRunning {
                        HStack(spacing: 8) {
                            Text(">")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(workspace.isWaitingForInput ? AppPalette.amber : AppPalette.silver)
                            TextField(
                                workspace.isWaitingForInput ? "type input, then ENTER" : "program input",
                                text: Binding(
                                    get: { workspace.stdinLine },
                                    set: { workspace.stdinLine = $0 }
                                ),
                                prompt: Text(workspace.isWaitingForInput ? "type input, then ENTER" : "program input")
                                    .foregroundStyle(AppPalette.silver)
                            )
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .lilCFieldInk()
                            .submitLabel(.send)
                            .focused($focusedLocalField, equals: .stdin)
                            .onSubmit {
                                workspace.submitStdinLine()
                                focusedLocalField = .stdin
                            }
                            Button("ENTER") {
                                workspace.submitStdinLine()
                                focusedLocalField = .stdin
                            }
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppPalette.onAccent)
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(AppPalette.green, in: RoundedRectangle(cornerRadius: 4))
                            Button("EOF") {
                                workspace.sendStdinEOF()
                            }
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppPalette.silver)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppPalette.panel)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(
                                            workspace.isWaitingForInput ? AppPalette.amber : AppPalette.line,
                                            lineWidth: workspace.isWaitingForInput ? 1.5 : 1
                                        )
                                )
                        )
                    }
                }
            }
            .padding(12)
            .frame(minHeight: outputExpanded ? 92 : 44, alignment: .top)
            .background(AppPalette.card)
        }
        .background(AppPalette.background)
        .onAppear {
            draftFileName = workspace.currentFile.name
        }
        .onChange(of: workspace.selectedFileID) { _, _ in
            draftFileName = workspace.currentFile.name
            clampFindIndex()
        }
        .onChange(of: workspace.isWaitingForInput) { _, waiting in
            if waiting {
                outputExpanded = true
                focusedLocalField = .stdin
            }
        }
        .onChange(of: workspace.isRunning) { _, running in
            if running {
                outputExpanded = true
                if focusedLocalField == .editor || focusedLocalField == .fileName {
                    dismissKeyboard()
                }
            }
        }
        .onChange(of: findQuery) { _, _ in
            findIndex = 0
            findEpoch += 1
        }
        .onKeyPress(.escape) {
            if findVisible {
                closeFind()
                return .handled
            }
            return .ignored
        }
    }

    @ViewBuilder
    private var outputBody: some View {
        let outputText = Text(workspace.output.isEmpty ? " " : workspace.output)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(AppPalette.foreground)
            .frame(maxWidth: .infinity, alignment: .leading)

        ScrollView {
            if workspace.lastErrorJump != nil {
                outputText
                    .contentShape(Rectangle())
                    .onTapGesture(perform: jumpToError)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Jumps to the error line")
            } else {
                outputText
                    .textSelection(.enabled)
            }
        }
    }

    private func dismissKeyboard() {
        focusedLocalField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func commitFileName() {
        workspace.renameCurrentFile(to: draftFileName)
        draftFileName = workspace.currentFile.name
        dismissKeyboard()
    }

    private func toggleFind() {
        if findVisible {
            closeFind()
        } else {
            findVisible = true
            focusedLocalField = .find
        }
    }

    private func closeFind() {
        findVisible = false
        findQuery = ""
        findIndex = 0
        findEpoch += 1
        if focusedLocalField == .find {
            focusedLocalField = nil
        }
    }

    private func stepFind(_ delta: Int) {
        let count = findMatches.count
        guard count > 0 else { return }
        findIndex = (findIndex + delta + count) % count
        findEpoch += 1
    }

    private func clampFindIndex() {
        let count = findMatches.count
        if count == 0 {
            findIndex = 0
        } else if findIndex >= count {
            findIndex = count - 1
        }
    }

    private func jumpToError() {
        guard let jump = workspace.revealErrorJump() else { return }
        outputExpanded = true
        focusedLocalField = .editor
        caretJump = CaretJump(line: jump.line, column: jump.column)
    }
}

private enum LocalEditorField: Hashable {
    case fileName
    case editor
    case stdin
    case find
}

private struct KeyboardHideButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "keyboard.chevron.compact.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.silver)
                .frame(width: 34, height: 30)
                .background(AppPalette.panel, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppPalette.line.opacity(0.75)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hide keyboard")
    }
}

private struct RunStatusBadge: View {
    let text: String
    let color: Color
    let pulsing: Bool
    @State private var isBright = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .opacity(pulsing ? (isBright ? 1.0 : 0.35) : 1.0)
            Text(text)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .frame(height: 20)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.4), lineWidth: 1))
        .onAppear {
            guard pulsing else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                isBright = true
            }
        }
    }
}

private enum AppTypography {
    static func terminal(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func body(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
