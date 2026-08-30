import Foundation
import Observation

struct LocalCFile: Identifiable, Codable, Equatable, Sendable {
    var relativePath: String
    var code: String
    var updatedAt: Date

    var id: String { relativePath }

    var name: String {
        URL(fileURLWithPath: relativePath).lastPathComponent
    }

    var folderPath: String {
        let parent = (relativePath as NSString).deletingLastPathComponent
        return parent == "." ? "" : parent
    }

    var isHeader: Bool {
        name.lowercased().hasSuffix(".h")
    }

    enum CodingKeys: String, CodingKey {
        case relativePath, name, code, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        if let path = try container.decodeIfPresent(String.self, forKey: .relativePath) {
            relativePath = path
        } else {
            relativePath = try container.decode(String.self, forKey: .name)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(relativePath, forKey: .relativePath)
        try container.encode(name, forKey: .name)
        try container.encode(code, forKey: .code)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    init(id: UUID = UUID(), name: String, code: String, updatedAt: Date = Date()) {
        _ = id
        self.relativePath = LocalCFile.normalizedName(name)
        self.code = code
        self.updatedAt = updatedAt
    }

    init(relativePath: String, code: String, updatedAt: Date = Date()) {
        self.relativePath = relativePath
        self.code = code
        self.updatedAt = updatedAt
    }

    var sizeText: String {
        let bytes = code.utf8.count
        if bytes < 1024 {
            return "\(bytes) B"
        }
        let kilobytes = Double(bytes) / 1024
        return String(format: "%.1f KB", kilobytes)
    }

    var codePreview: String {
        code
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "Empty C file"
    }

    static func normalizedName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = trimmed.map { character in
            character.isLetter || character.isNumber || character == "." || character == "_" || character == "-"
                ? character
                : "-"
        }
        let fallback = safe.isEmpty ? "hello.c" : String(safe)
        let lower = fallback.lowercased()
        if lower.hasSuffix(".c") || lower.hasSuffix(".h") {
            return fallback
        }
        return "\(fallback).c"
    }

    static func normalizedFolderName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = trimmed.map { character in
            character.isLetter || character.isNumber || character == "_" || character == "-"
                ? character
                : "-"
        }
        return safe.isEmpty ? "project" : String(safe)
    }
}

struct LocalCFolder: Identifiable, Equatable, Sendable {
    var relativePath: String
    var updatedAt: Date

    var id: String { relativePath }

    var name: String {
        URL(fileURLWithPath: relativePath).lastPathComponent
    }

    var parentPath: String {
        let parent = (relativePath as NSString).deletingLastPathComponent
        return parent == "." ? "" : parent
    }
}

enum LocalBrowserEntry: Identifiable {
    case folder(LocalCFolder)
    case file(LocalCFile)

    var id: String {
        switch self {
        case .folder(let folder): folder.id
        case .file(let file): file.id
        }
    }
}

@MainActor
@Observable
final class LocalCWorkspace {
    private let legacyStorageKey = "lilc.local.c.files"
    private let selectedFileNameKey = "lilc.local.selected.file"
    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let directoryURL: URL
    private var liveRunID = UUID()

    var files: [LocalCFile]
    var folders: [LocalCFolder]
    var selectedFileID: String
    var browsePath = ""
    var output = "Local C workspace ready."
    var isRunning = false
    var isWaitingForInput = false
    var lastRunFailed = false
    var lastErrorJump: CErrorJump?
    var stdinLine = ""

    init(defaults: UserDefaults = .standard, fileManager: FileManager = .default, directoryURL: URL? = nil) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.directoryURL = directoryURL ?? Self.defaultDirectoryURL(fileManager: fileManager)
        Self.prepareDirectory(self.directoryURL, fileManager: fileManager)
        let loadedFiles = Self.loadFiles(
            directoryURL: self.directoryURL,
            defaults: defaults,
            fileManager: fileManager,
            legacyStorageKey: legacyStorageKey
        )
        files = loadedFiles
        folders = Self.loadFolders(directoryURL: self.directoryURL, fileManager: fileManager, files: loadedFiles)
        let selectedName = defaults.string(forKey: selectedFileNameKey)
        selectedFileID = loadedFiles.first(where: { $0.relativePath == selectedName || $0.name == selectedName })?.id
            ?? loadedFiles[0].id
    }

    var currentFile: LocalCFile {
        files.first { $0.id == selectedFileID } ?? files[0]
    }

    var currentProjectPath: String {
        currentFile.folderPath
    }

    var projectFiles: [LocalCFile] {
        files
            .filter { $0.folderPath == currentProjectPath }
            .sorted { lhs, rhs in
                if lhs.name == "main.c" { return true }
                if rhs.name == "main.c" { return false }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    var recentProjects: [LocalCFolder] {
        Array(rootFolders.sorted { $0.updatedAt > $1.updatedAt }.prefix(3))
    }

    var rootFolders: [LocalCFolder] {
        folders.filter { $0.parentPath.isEmpty }.sorted { $0.updatedAt > $1.updatedAt }
    }

    var allFiles: [LocalCFile] {
        files.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    var currentFileURL: URL {
        fileURL(for: currentFile.relativePath)
    }

    var currentIncludeRootURL: URL {
        let folder = currentFile.folderPath
        if folder.isEmpty {
            return directoryURL
        }
        return directoryURL.appendingPathComponent(folder, isDirectory: true)
    }

    var browserEntries: [LocalBrowserEntry] {
        let childFolders = folders
            .filter { $0.parentPath == browsePath }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let childFiles = files
            .filter { $0.folderPath == browsePath }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return childFolders.map { .folder($0) } + childFiles.map { .file($0) }
    }

    var browseTitle: String {
        browsePath.isEmpty ? "Files" : URL(fileURLWithPath: browsePath).lastPathComponent
    }

    func select(_ file: LocalCFile) {
        selectedFileID = file.id
        browsePath = file.folderPath
        defaults.set(file.relativePath, forKey: selectedFileNameKey)
    }

    @discardableResult
    func revealErrorJump() -> CErrorJump? {
        guard let jump = lastErrorJump else { return nil }
        if let file = files.first(where: { $0.id == jump.fileID }) {
            select(file)
        }
        return jump
    }

    func openProject(_ folder: LocalCFolder) {
        browsePath = folder.relativePath
        if files.contains(where: { $0.folderPath == folder.relativePath }) == false {
            createFile(in: folder.relativePath, named: "main.c")
        }
        let members = files.filter { $0.folderPath == folder.relativePath }
        let preferred = members.first { $0.name == "main.c" }
            ?? members.first { $0.name.hasSuffix(".c") }
            ?? members.first
        if let preferred {
            select(preferred)
        }
    }

    func goUpFromBrowse() -> Bool {
        guard !browsePath.isEmpty else { return false }
        browsePath = (browsePath as NSString).deletingLastPathComponent
        if browsePath == "." { browsePath = "" }
        return true
    }

    func enterFolder(_ folder: LocalCFolder) {
        browsePath = folder.relativePath
    }

    func searchFiles(matching query: String) -> [LocalCFile] {
        let tokens = query
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !tokens.isEmpty else { return allFiles }

        let rankedMatches: [(file: LocalCFile, nameScore: Int)] = allFiles.compactMap { file in
            let normalizedName = file.relativePath.lowercased()
            let normalizedCode = file.code.lowercased()
            guard tokens.allSatisfy({ normalizedName.contains($0) || normalizedCode.contains($0) }) else {
                return nil
            }
            let nameScore = tokens.filter { normalizedName.contains($0) }.count
            return (file, nameScore)
        }

        return rankedMatches.sorted { lhs, rhs in
            if lhs.1 == rhs.1 {
                return lhs.0.updatedAt > rhs.0.updatedAt
            }
            return lhs.1 > rhs.1
        }
        .map(\.0)
    }

    func searchBrowser(matching query: String) -> [LocalBrowserEntry] {
        let tokens = query
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !tokens.isEmpty else { return browserEntries }

        let matchedFolders = folders.filter { folder in
            tokens.allSatisfy { folder.relativePath.lowercased().contains($0) }
        }
        let matchedFiles = searchFiles(matching: query)
        return matchedFolders.map { .folder($0) } + matchedFiles.map { .file($0) }
    }

    @discardableResult
    func delete(_ file: LocalCFile) -> Bool {
        guard let index = files.firstIndex(where: { $0.id == file.id }) else { return false }
        try? fileManager.removeItem(at: fileURL(for: files[index].relativePath))
        files.remove(at: index)
        ensureNotEmpty()
        if !files.contains(where: { $0.id == selectedFileID }) {
            selectedFileID = files[0].id
            defaults.set(files[0].relativePath, forKey: selectedFileNameKey)
        }
        refreshFolders()
        output = "Deleted \(file.name)."
        return true
    }

    func fileCount(in folder: LocalCFolder) -> Int {
        files.filter {
            $0.folderPath == folder.relativePath || $0.relativePath.hasPrefix(folder.relativePath + "/")
        }.count
    }

    func deleteFolder(_ folder: LocalCFolder) {
        try? fileManager.removeItem(at: fileURL(for: folder.relativePath))
        files.removeAll { $0.relativePath == folder.relativePath || $0.relativePath.hasPrefix(folder.relativePath + "/") }
        folders.removeAll { $0.relativePath == folder.relativePath || $0.relativePath.hasPrefix(folder.relativePath + "/") }
        if browsePath == folder.relativePath || browsePath.hasPrefix(folder.relativePath + "/") {
            browsePath = folder.parentPath
        }
        ensureNotEmpty()
        if !files.contains(where: { $0.id == selectedFileID }) {
            selectedFileID = files[0].id
            defaults.set(files[0].relativePath, forKey: selectedFileNameKey)
        }
        output = "Deleted folder \(folder.name)."
    }

    func deleteAllFiles() {
        if let urls = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) {
            for url in urls {
                try? fileManager.removeItem(at: url)
            }
        }
        let starter = Self.starterFile
        files = [starter]
        folders = []
        browsePath = ""
        selectedFileID = starter.id
        persist(starter)
        output = "All local files erased."
    }

    func createFile() {
        createFile(in: browsePath, named: nil)
    }

    func createStandaloneFile() {
        browsePath = ""
        createFile(in: "", named: nil)
    }

    /// Copies a first-hour lesson into `lessons/` if needed, then selects it.
    /// Does not overwrite a file the student already edited.
    func openLesson(_ lesson: FirstHourLesson) {
        let relative = lesson.relativePath
        if let existing = files.first(where: { $0.relativePath == relative }) {
            select(existing)
            output = "Lesson \(lesson.number) of \(FirstHourCurriculum.lessons.count) — \(lesson.title). Press RUN."
            return
        }
        let file = LocalCFile(relativePath: relative, code: lesson.source)
        files.insert(file, at: 0)
        selectedFileID = file.id
        persist(file)
        refreshFolders()
        output = "Lesson \(lesson.number) of \(FirstHourCurriculum.lessons.count) — \(lesson.title). Press RUN."
    }

    func createHeader() {
        createFile(in: browsePath, named: availableFileName(base: "module", ext: "h", in: browsePath))
    }

    func createFile(in folder: String, named requested: String?) {
        let name = requested ?? availableFileName(base: "program", ext: "c", in: folder)
        let relative = folder.isEmpty ? name : "\(folder)/\(name)"
        let code = name.hasSuffix(".h") ? Self.headerStarter(for: name) : Self.starterCode
        let file = LocalCFile(relativePath: relative, code: code)
        files.insert(file, at: 0)
        selectedFileID = file.id
        defaults.set(file.relativePath, forKey: selectedFileNameKey)
        output = "Created \(relative)."
        persist(file)
        refreshFolders()
    }

    func createFolder(named rawName: String) {
        let name = LocalCFile.normalizedFolderName(rawName)
        let relative = browsePath.isEmpty ? name : "\(browsePath)/\(name)"
        var unique = relative
        var index = 2
        while folders.contains(where: { $0.relativePath == unique }) {
            unique = "\(relative)-\(index)"
            index += 1
        }
        try? fileManager.createDirectory(at: fileURL(for: unique), withIntermediateDirectories: true)
        refreshFolders()
        output = "Created folder \(unique)."
    }

    @discardableResult
    func moveFile(_ file: LocalCFile, into folderRelative: String) -> Bool {
        guard files.contains(where: { $0.id == file.id }) else { return false }
        let destinationFolder = folderRelative
        if file.folderPath == destinationFolder { return true }
        let destName = availableFileName(
            base: (file.name as NSString).deletingPathExtension,
            ext: (file.name as NSString).pathExtension,
            in: destinationFolder
        )
        let destRelative = destinationFolder.isEmpty ? destName : "\(destinationFolder)/\(destName)"
        let sourceURL = fileURL(for: file.relativePath)
        let destURL = fileURL(for: destRelative)
        try? fileManager.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            try fileManager.moveItem(at: sourceURL, to: destURL)
        } catch {
            output = "Could not move \(file.name)."
            return false
        }
        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index].relativePath = destRelative
            files[index].updatedAt = Date()
            if selectedFileID == file.id {
                selectedFileID = destRelative
                defaults.set(destRelative, forKey: selectedFileNameKey)
            }
        }
        refreshFolders()
        output = "Moved \(file.name) into \(destinationFolder.isEmpty ? "Files" : destinationFolder)."
        return true
    }

    func updateCurrentName(_ name: String) {
        renameCurrentFile(to: name)
    }

    func renameCurrentFile(to name: String) {
        guard let index = files.firstIndex(where: { $0.id == selectedFileID }) else { return }
        let folder = files[index].folderPath
        let newName = LocalCFile.normalizedName(name)
        let destRelative = folder.isEmpty ? availableFileName(base: (newName as NSString).deletingPathExtension, ext: (newName as NSString).pathExtension, in: folder, ignoring: files[index].name) : "\(folder)/\(availableFileName(base: (newName as NSString).deletingPathExtension, ext: (newName as NSString).pathExtension, in: folder, ignoring: files[index].name))"
        let oldRelative = files[index].relativePath
        if destRelative != oldRelative {
            try? fileManager.moveItem(at: fileURL(for: oldRelative), to: fileURL(for: destRelative))
        }
        files[index].relativePath = destRelative
        files[index].updatedAt = Date()
        selectedFileID = destRelative
        defaults.set(destRelative, forKey: selectedFileNameKey)
        persist(files[index])
    }

    func updateCurrentCode(_ code: String) {
        guard let index = files.firstIndex(where: { $0.id == selectedFileID }) else { return }
        files[index].code = code
        files[index].updatedAt = Date()
        persist(files[index])
    }

    func agentSafeRelativePath(_ raw: String) -> String? {
        var path = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.hasPrefix("./") { path.removeFirst(2) }
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("..") else { return nil }
        let parts = path.split(separator: "/").map(String.init)
        guard parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { return nil }
        return parts.joined(separator: "/")
    }

    func agentListFilesSummary() -> String {
        if files.isEmpty { return "(no files)" }
        return files
            .sorted { $0.relativePath < $1.relativePath }
            .map { "\($0.relativePath)  \($0.sizeText)" }
            .joined(separator: "\n")
    }

    func agentReadFile(_ rawPath: String) -> String? {
        guard let path = agentSafeRelativePath(rawPath) else { return nil }
        return files.first(where: { $0.relativePath == path })?.code
    }

    @discardableResult
    func agentWriteFile(_ rawPath: String, contents: String) -> String {
        guard let path = agentSafeRelativePath(rawPath) else {
            return "Rejected path. Use a project-relative file such as main.c or folder/file.c."
        }
        let ext = (path as NSString).pathExtension.lowercased()
        guard ext == "c" || ext == "h" else {
            return "Only .c and .h files can be written."
        }
        if let index = files.firstIndex(where: { $0.relativePath == path }) {
            files[index].code = contents
            files[index].updatedAt = Date()
            persist(files[index])
            selectedFileID = path
            defaults.set(path, forKey: selectedFileNameKey)
            return "Updated \(path)."
        }
        let parent = (path as NSString).deletingLastPathComponent
        if parent != ".", !parent.isEmpty {
            try? fileManager.createDirectory(at: fileURL(for: parent), withIntermediateDirectories: true)
        }
        let file = LocalCFile(relativePath: path, code: contents)
        files.insert(file, at: 0)
        selectedFileID = file.id
        defaults.set(file.relativePath, forKey: selectedFileNameKey)
        persist(file)
        refreshFolders()
        return "Created \(path)."
    }

    func agentListFoldersSummary() -> String {
        if folders.isEmpty { return "(no folders)" }
        return folders
            .sorted { $0.relativePath < $1.relativePath }
            .map { "\($0.relativePath)/" }
            .joined(separator: "\n")
    }

    @discardableResult
    func agentCreateFolder(_ rawPath: String) -> String {
        guard let path = agentSafeRelativePath(rawPath) else {
            return "Rejected folder path."
        }
        try? fileManager.createDirectory(at: fileURL(for: path), withIntermediateDirectories: true)
        refreshFolders()
        browsePath = path
        return "Created folder \(path)."
    }

    func agentSelectFile(_ rawPath: String) -> String {
        guard let path = agentSafeRelativePath(rawPath),
              let file = files.first(where: { $0.relativePath == path }) else {
            return "File not found."
        }
        select(file)
        return "Selected \(path)."
    }

    func agentOpenProject(_ rawPath: String) -> String {
        guard let path = agentSafeRelativePath(rawPath),
              let folder = folders.first(where: { $0.relativePath == path }) else {
            return "Folder not found. Create it first."
        }
        openProject(folder)
        return "Opened project \(path)."
    }

    func agentRunFile(_ rawPath: String) -> String {
        let selected = agentSelectFile(rawPath)
        guard selected.hasPrefix("Selected") else { return selected }
        runCurrentFile()
        return "Running \(workspaceCurrentName())."
    }

    func agentStopRun() -> String {
        guard isRunning else { return "Nothing is running." }
        stopLiveRun()
        return "Stopped."
    }

    func agentOutputPreview() -> String {
        let text = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return "(no output yet)" }
        return String(text.suffix(4000))
    }

    func agentDeleteFile(_ rawPath: String, safeguardsOn: Bool) -> String {
        if safeguardsOn {
            return "Safeguards are on. Turn them off in Settings to delete."
        }
        guard let path = agentSafeRelativePath(rawPath),
              let file = files.first(where: { $0.relativePath == path }) else {
            return "File not found."
        }
        _ = delete(file)
        return "Deleted \(path)."
    }

    func agentDeleteFolder(_ rawPath: String, safeguardsOn: Bool) -> String {
        if safeguardsOn {
            return "Safeguards are on. Turn them off in Settings to delete."
        }
        guard let path = agentSafeRelativePath(rawPath),
              let folder = folders.first(where: { $0.relativePath == path }) else {
            return "Folder not found."
        }
        deleteFolder(folder)
        return "Deleted folder \(path)."
    }

    private func workspaceCurrentName() -> String {
        currentFile.relativePath
    }

    func runCurrentFile() {
        startLiveRun()
    }

    func run(_ file: LocalCFile) {
        select(file)
        startLiveRun()
    }

    func startLiveRun() {
        if isRunning {
            LocalCRunner.requestStop()
        }
        persist(currentFile)
        projectFiles.forEach { persist($0) }
        let projectMains = projectFiles.filter {
            $0.name.hasSuffix(".c") && containsMainFunction($0.code)
        }
        if !currentProjectPath.isEmpty, projectMains.count > 1 {
            liveRunID = UUID()
            isRunning = false
            isWaitingForInput = false
            lastRunFailed = true
            lastErrorJump = nil
            let names = projectMains.map(\.name).joined(separator: ", ")
            let raw = "Cannot run this project: it has more than one main() function (\(names)). Keep one main() and turn the others into helper functions.\n"
            output = CDiagnosticFormatter.displayOutput(for: raw).text
            return
        }
        let runFile = fileToCompile()
        let extras = extraSourcesToLink(with: runFile)
        let projectSnapshot = projectFiles
        let includeRoot = currentIncludeRootURL.path
        let extraCode = extras.map(\.code).joined(separator: "\n")
        let code = extraCode.isEmpty ? runFile.code : extraCode + "\n" + runFile.code
        let mainName = runFile.name
        liveRunID = UUID()
        let runID = liveRunID
        stdinLine = ""
        output = ""
        isRunning = true
        isWaitingForInput = false
        lastRunFailed = false
        lastErrorJump = nil
        touchCurrentFile()

        Task.detached { [weak self] in
            let result = LocalCRunner.runInteractive(
                code,
                mainName: mainName,
                extraFileNames: [],
                includeRoot: includeRoot
            ) { chunk in
                Task { @MainActor in
                    guard let workspace = self, workspace.liveRunID == runID else { return }
                    workspace.output += chunk
                }
            } onWaitingForInput: { waiting in
                Task { @MainActor in
                    guard let workspace = self, workspace.liveRunID == runID else { return }
                    workspace.isWaitingForInput = waiting
                }
            }
            await MainActor.run {
                guard let workspace = self, workspace.liveRunID == runID else { return }
                let formatted = CDiagnosticFormatter.displayOutput(for: result)
                if !formatted.text.isEmpty {
                    workspace.output = formatted.text
                }
                workspace.lastRunFailed = formatted.failed
                if formatted.failed, let diagnostic = CDiagnosticFormatter.diagnostic(from: result) {
                    workspace.lastErrorJump = CDiagnosticJump.resolve(
                        diagnostic: diagnostic,
                        runFile: runFile,
                        extras: extras,
                        projectFiles: projectSnapshot
                    )
                } else {
                    workspace.lastErrorJump = nil
                }
                workspace.isRunning = false
                workspace.isWaitingForInput = false
            }
        }
    }

    func submitStdinLine() {
        guard isRunning else { return }
        let line = stdinLine
        stdinLine = ""
        isWaitingForInput = false
        output += line + "\n"
        LocalCRunner.feedStdin(line + "\n")
    }

    func sendStdinEOF() {
        LocalCRunner.closeStdin()
    }

    func stopLiveRun() {
        guard isRunning else { return }
        LocalCRunner.requestStop()
    }

    private func extraSourcesToLink(with runFile: LocalCFile) -> [LocalCFile] {
        guard !currentProjectPath.isEmpty else { return [] }
        return projectFiles.filter {
            $0.relativePath != runFile.relativePath
                && $0.name.hasSuffix(".c")
                && !containsMainFunction($0.code)
        }
    }

    private func fileToCompile() -> LocalCFile {
        if currentFile.name.hasSuffix(".c"),
           containsMainFunction(currentFile.code) || currentProjectPath.isEmpty {
            return currentFile
        }
        return projectFiles.first { $0.name == "main.c" }
            ?? projectFiles.first { $0.name.hasSuffix(".c") && containsMainFunction($0.code) }
            ?? projectFiles.first { $0.name.hasSuffix(".c") }
            ?? currentFile
    }

    private func containsMainFunction(_ code: String) -> Bool {
        code.range(of: #"\bmain\s*\([^)]*\)\s*\{"#, options: .regularExpression) != nil
    }

    private func touchCurrentFile() {
        guard let index = files.firstIndex(where: { $0.id == selectedFileID }) else { return }
        files[index].updatedAt = Date()
        persist(files[index])
    }

    private func availableFileName(base: String, ext: String, in folder: String, ignoring oldName: String? = nil) -> String {
        let cleanExt = ext.isEmpty ? "c" : ext
        var candidate = "\(base).\(cleanExt)"
        var index = 2
        while files.contains(where: { $0.folderPath == folder && $0.name == candidate && $0.name != oldName }) {
            candidate = "\(base)-\(index).\(cleanExt)"
            index += 1
        }
        return candidate
    }

    private func persist(_ file: LocalCFile) {
        let url = fileURL(for: file.relativePath)
        try? fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? file.code.write(to: url, atomically: true, encoding: .utf8)
        defaults.set(file.relativePath, forKey: selectedFileNameKey)
    }

    private func fileURL(for relative: String) -> URL {
        directoryURL.appendingPathComponent(relative)
    }

    private func ensureNotEmpty() {
        if files.isEmpty {
            let starter = Self.starterFile
            files = [starter]
            persist(starter)
        }
    }

    private func refreshFolders() {
        folders = Self.loadFolders(directoryURL: directoryURL, fileManager: fileManager, files: files)
    }

    private static func defaultDirectoryURL(fileManager: FileManager) -> URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        return (documents ?? URL(fileURLWithPath: NSTemporaryDirectory())).appendingPathComponent("lilC", isDirectory: true)
    }

    private static func prepareDirectory(_ directoryURL: URL, fileManager: FileManager) {
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private static func loadFiles(
        directoryURL: URL,
        defaults: UserDefaults,
        fileManager: FileManager,
        legacyStorageKey: String
    ) -> [LocalCFile] {
        let diskFiles = loadFilesFromDisk(directoryURL: directoryURL, fileManager: fileManager)
        if !diskFiles.isEmpty {
            return diskFiles
        }
        if let data = defaults.data(forKey: legacyStorageKey),
           let saved = try? JSONDecoder().decode([LocalCFile].self, from: data),
           !saved.isEmpty {
            saved.forEach { file in
                try? file.code.write(
                    to: directoryURL.appendingPathComponent(file.relativePath),
                    atomically: true,
                    encoding: .utf8
                )
            }
            return saved.sorted { $0.updatedAt > $1.updatedAt }
        }
        let starter = Self.starterFile
        try? starter.code.write(
            to: directoryURL.appendingPathComponent(starter.relativePath),
            atomically: true,
            encoding: .utf8
        )
        return [starter]
    }

    private static func loadFilesFromDisk(directoryURL: URL, fileManager: FileManager) -> [LocalCFile] {
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var loaded: [LocalCFile] = []
        let root = directoryURL.standardizedFileURL.path
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
            if values?.isDirectory == true { continue }
            let ext = url.pathExtension.lowercased()
            guard ext == "c" || ext == "h" else { continue }
            guard let code = try? String(contentsOf: url, encoding: .utf8) else { continue }
            var relative = url.standardizedFileURL.path
            if relative.hasPrefix(root) {
                relative = String(relative.dropFirst(root.count))
                if relative.hasPrefix("/") { relative.removeFirst() }
            }
            loaded.append(LocalCFile(relativePath: relative, code: code, updatedAt: values?.contentModificationDate ?? Date()))
        }
        return loaded.sorted { $0.updatedAt > $1.updatedAt }
    }

    private static func loadFolders(directoryURL: URL, fileManager: FileManager, files: [LocalCFile]) -> [LocalCFolder] {
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var folders: [LocalCFolder] = []
        let root = directoryURL.standardizedFileURL.path
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
            guard values?.isDirectory == true else { continue }
            var relative = url.standardizedFileURL.path
            if relative.hasPrefix(root) {
                relative = String(relative.dropFirst(root.count))
                if relative.hasPrefix("/") { relative.removeFirst() }
            }
            guard !relative.isEmpty else { continue }
            let newestFile = files
                .filter { $0.relativePath.hasPrefix(relative + "/") }
                .map(\.updatedAt)
                .max()
            folders.append(LocalCFolder(relativePath: relative, updatedAt: newestFile ?? values?.contentModificationDate ?? Date()))
        }
        return folders
    }

    private static let starterFile = LocalCFile(name: "hello.c", code: starterCode)

    static func headerStarter(for name: String) -> String {
        let guardName = name
            .uppercased()
            .map { $0.isLetter || $0.isNumber ? $0 : "_" }
        let token = String(guardName)
        return """
        #ifndef \(token)
        #define \(token)

        #endif
        """
    }

    static let starterCode = """
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
    """
}

enum LocalCRunner {
    private static let gate = NSLock()

    static func run(_ code: String, stdin: String = "") -> String {
        gate.lock()
        defer { gate.unlock() }
        guard code.range(of: #"\bsystem\s*\("#, options: .regularExpression) == nil else {
            return "system() is not available in lilC local mode.\n"
        }
        lilc_picoc_set_output_hook(nil, nil)
        let rawOutput: UnsafeMutablePointer<CChar>? = stdin.isEmpty
            ? lilc_picoc_run_source(code)
            : lilc_picoc_run_source_with_stdin(code, stdin)
        guard let rawOutput else {
            return "lilC could not start the local C engine.\n"
        }
        defer {
            lilc_picoc_free_output(rawOutput)
        }
        return String(cString: rawOutput)
    }

    static func runInteractive(
        _ code: String,
        mainName: String = "main.c",
        extraFileNames: [String] = [],
        includeRoot: String? = nil,
        onOutput: @escaping @Sendable (String) -> Void,
        onWaitingForInput: @escaping @Sendable (Bool) -> Void
    ) -> String {
        gate.lock()
        defer { gate.unlock() }
        guard code.range(of: #"\bsystem\s*\("#, options: .regularExpression) == nil else {
            return "system() is not available in lilC local mode.\n"
        }
        let sink = LocalCOutputSink(handler: onOutput, waitHandler: onWaitingForInput)
        let sinkPtr = Unmanaged.passRetained(sink).toOpaque()
        lilc_picoc_set_output_hook(localCOutputHook, sinkPtr)
        lilc_picoc_set_input_wait_hook(localCInputWaitHook, sinkPtr)
        defer {
            lilc_picoc_set_output_hook(nil, nil)
            lilc_picoc_set_input_wait_hook(nil, nil)
            Unmanaged<LocalCOutputSink>.fromOpaque(sinkPtr).release()
        }

        let rawOutput: UnsafeMutablePointer<CChar>?
        if extraFileNames.isEmpty {
            rawOutput = mainName.withCString { main in
                if let includeRoot {
                    includeRoot.withCString { root in
                        lilc_picoc_run_source_interactive_project(code, main, nil, 0, root)
                    }
                } else {
                    lilc_picoc_run_source_interactive_project(code, main, nil, 0, nil)
                }
            }
        } else {
            rawOutput = extraFileNames.withCStrings { extras, count in
                mainName.withCString { main in
                    if let includeRoot {
                        includeRoot.withCString { root in
                            lilc_picoc_run_source_interactive_project(code, main, extras, Int32(count), root)
                        }
                    } else {
                        lilc_picoc_run_source_interactive_project(code, main, extras, Int32(count), nil)
                    }
                }
            }
        }
        guard let rawOutput else {
            return "lilC could not start the local C engine.\n"
        }
        defer {
            lilc_picoc_free_output(rawOutput)
        }
        return String(cString: rawOutput)
    }

    static func feedStdin(_ text: String) {
        let bytes = Array(text.utf8)
        bytes.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            base.withMemoryRebound(to: CChar.self, capacity: buffer.count) { chars in
                _ = lilc_picoc_feed_stdin(chars, Int32(buffer.count))
            }
        }
    }

    static func closeStdin() {
        lilc_picoc_close_stdin()
    }

    static func requestStop() {
        lilc_picoc_request_stop()
    }
}

private extension Array where Element == String {
    func withCStrings<R>(_ body: (UnsafePointer<UnsafePointer<CChar>?>, Int) -> R) -> R {
        let cStrings = map { strdup($0) }
        defer {
            cStrings.forEach { free($0) }
        }
        let pointers: [UnsafePointer<CChar>?] = cStrings.map { UnsafePointer($0) }
        return pointers.withUnsafeBufferPointer { buffer in
            body(buffer.baseAddress!, count)
        }
    }
}

private final class LocalCOutputSink: @unchecked Sendable {
    let handler: @Sendable (String) -> Void
    let waitHandler: @Sendable (Bool) -> Void

    init(
        handler: @escaping @Sendable (String) -> Void,
        waitHandler: @escaping @Sendable (Bool) -> Void
    ) {
        self.handler = handler
        self.waitHandler = waitHandler
    }
}

private func localCOutputHook(_ bytes: UnsafePointer<CChar>?, _ length: Int32, _ context: UnsafeMutableRawPointer?) {
    guard let bytes, let context, length > 0 else { return }
    let sink = Unmanaged<LocalCOutputSink>.fromOpaque(context).takeUnretainedValue()
    let buffer = UnsafeBufferPointer(start: UnsafeRawPointer(bytes).assumingMemoryBound(to: UInt8.self), count: Int(length))
    if let chunk = String(bytes: buffer, encoding: .utf8) {
        sink.handler(chunk)
    }
}

private func localCInputWaitHook(_ waiting: Int32, _ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    let sink = Unmanaged<LocalCOutputSink>.fromOpaque(context).takeUnretainedValue()
    sink.waitHandler(waiting != 0)
}
