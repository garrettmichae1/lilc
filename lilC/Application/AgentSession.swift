import Foundation
import Observation

@Observable
@MainActor
final class AgentSession {
    private(set) var messages: [AgentChatMessage] = []
    private(set) var isThinking = false
    var draft = ""
    var statusLine = "Ready"

    private let settings: AgentSettingsStore
    private let workspace: LocalCWorkspace
    private var runTask: Task<Void, Never>?

    init(workspace: LocalCWorkspace, settings: AgentSettingsStore) {
        self.workspace = workspace
        self.settings = settings
        messages = [
            AgentChatMessage(
                role: .assistant,
                text: "I can create projects, write C, add tests, run PicoC, and help you think through a design. I will not delete anything unless you turn safeguards off in Settings."
            )
        ]
    }

    func stop() {
        runTask?.cancel()
        isThinking = false
        statusLine = "Stopped"
    }

    func send() {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isThinking else { return }
        guard settings.canRunAgents else { return }
        draft = ""
        messages.append(AgentChatMessage(role: .user, text: prompt))
        runTask = Task { await loop() }
    }

    private func loop() async {
        isThinking = true
        defer { isThinking = false }

        do {
            let client = try await makeClient()
            var wire = wireMessages()
            var hops = 0
            while hops < 20 {
                if Task.isCancelled { throw AgentTransportError.cancelled }
                hops += 1
                statusLine = hops == 1 ? "Thinking…" : "Working in lilC…"
                let messagesJSON = try JSONSerialization.data(withJSONObject: wire)
                let toolsJSON = try JSONSerialization.data(withJSONObject: Self.toolSpecs)
                let result = try await client.complete(messagesJSON: messagesJSON, toolsJSON: toolsJSON)
                if result.toolCalls.isEmpty {
                    let text = result.assistantText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        messages.append(AgentChatMessage(role: .assistant, text: text))
                    }
                    statusLine = "Ready"
                    return
                }
                if !result.assistantText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    messages.append(AgentChatMessage(role: .assistant, text: result.assistantText))
                }
                var toolCallPayload: [[String: Any]] = []
                for call in result.toolCalls {
                    toolCallPayload.append([
                        "id": call.id,
                        "type": "function",
                        "function": [
                            "name": call.name,
                            "arguments": call.argumentsJSON
                        ]
                    ])
                }
                wire.append([
                    "role": "assistant",
                    "content": result.assistantText,
                    "tool_calls": toolCallPayload
                ])
                for call in result.toolCalls {
                    let output = executeTool(call)
                    messages.append(AgentChatMessage(role: .tool, text: output, toolName: call.name))
                    wire.append([
                        "role": "tool",
                        "tool_call_id": call.id,
                        "content": output
                    ])
                }
            }
            messages.append(
                AgentChatMessage(role: .assistant, text: "Paused after many steps. Send another message to continue.")
            )
            statusLine = "Ready"
        } catch {
            if error is CancellationError || (error as? AgentTransportError) == .cancelled {
                statusLine = "Stopped"
                return
            }
            messages.append(AgentChatMessage(role: .assistant, text: error.localizedDescription))
            statusLine = "Error"
        }
    }

    private func makeClient() async throws -> any AgentCompleting {
        let url = try AgentEndpointPolicy.validatedGateway(
            AgentRuntimeConfig.gatewayURL,
            allowedHosts: AgentRuntimeConfig.allowedHosts
        )
        let jws = await AgentEntitlement.transactionJWS()
        let debugToken = AgentKeychain.loadKey()
        return OpenAICompatibleAgentClient(
            baseURL: url,
            model: AgentRuntimeConfig.model,
            debugToken: debugToken,
            appleTransactionJWS: jws
        )
    }

    private func wireMessages() -> [[String: Any]] {
        var payload: [[String: Any]] = [
            ["role": "system", "content": systemPrompt()]
        ]
        for message in messages {
            switch message.role {
            case .user:
                payload.append(["role": "user", "content": message.text])
            case .assistant:
                if message.text.hasPrefix("I can create projects") { continue }
                payload.append(["role": "assistant", "content": message.text])
            case .tool, .system:
                continue
            }
        }
        return payload
    }

    private func systemPrompt() -> String {
        let project = workspace.currentProjectPath.isEmpty ? "(root)" : workspace.currentProjectPath
        let files = workspace.agentListFilesSummary()
        let folders = workspace.agentListFoldersSummary()
        let deletes = settings.safeguardsOn ? "OFF (cannot delete)" : "ON (may delete files and folders)"
        return """
        You are the lilC agent. You fully operate this iPhone C IDE for the subscriber.
        Runtime is PicoC, not GCC. Avoid function pointers, qsort, and system().
        Current file: \(workspace.currentFile.relativePath)
        Current project: \(project)
        Folders:
        \(folders)
        Files:
        \(files)
        Deleting: \(deletes)
        You may brainstorm without tools. For code, use tools: create folders, write .c/.h including test_*.c, select, run, read output.
        Prefer a folder as a project. Put tests next to the code they cover.
        """
    }

    private func executeTool(_ call: AgentToolCall) -> String {
        let args = (try? JSONSerialization.jsonObject(with: Data(call.argumentsJSON.utf8))) as? [String: Any] ?? [:]
        switch call.name {
        case "list_files":
            return workspace.agentListFilesSummary()
        case "list_folders":
            return workspace.agentListFoldersSummary()
        case "read_file":
            return workspace.agentReadFile(args["path"] as? String ?? "") ?? "File not found."
        case "write_file":
            return workspace.agentWriteFile(args["path"] as? String ?? "", contents: args["contents"] as? String ?? "")
        case "create_folder":
            return workspace.agentCreateFolder(args["path"] as? String ?? "")
        case "open_project":
            return workspace.agentOpenProject(args["path"] as? String ?? "")
        case "select_file":
            return workspace.agentSelectFile(args["path"] as? String ?? "")
        case "run_file":
            return workspace.agentRunFile(args["path"] as? String ?? "")
        case "run_current":
            workspace.runCurrentFile()
            return "Running \(workspace.currentFile.relativePath)."
        case "stop_run":
            return workspace.agentStopRun()
        case "read_output":
            return workspace.agentOutputPreview()
        case "delete_file":
            return workspace.agentDeleteFile(args["path"] as? String ?? "", safeguardsOn: settings.safeguardsOn)
        case "delete_folder":
            return workspace.agentDeleteFolder(args["path"] as? String ?? "", safeguardsOn: settings.safeguardsOn)
        default:
            return "Unknown tool \(call.name)"
        }
    }

    private static let toolSpecs: [[String: Any]] = [
        function("list_files", "List source files in lilC."),
        function("list_folders", "List project folders."),
        function("read_file", "Read a file.", ["path": stringProp], ["path"]),
        function("write_file", "Create or overwrite a .c or .h file (including tests).", [
            "path": stringProp,
            "contents": stringProp
        ], ["path", "contents"]),
        function("create_folder", "Create a project or nested folder.", ["path": stringProp], ["path"]),
        function("open_project", "Open a folder as the current project.", ["path": stringProp], ["path"]),
        function("select_file", "Select a file in the editor.", ["path": stringProp], ["path"]),
        function("run_file", "Select a .c file and run it in PicoC.", ["path": stringProp], ["path"]),
        function("run_current", "Run the selected file."),
        function("stop_run", "Stop a running program."),
        function("read_output", "Read recent program output."),
        function("delete_file", "Delete a file. Blocked while safeguards are on.", ["path": stringProp], ["path"]),
        function("delete_folder", "Delete a folder and its files. Blocked while safeguards are on.", ["path": stringProp], ["path"])
    ]

    private static var stringProp: [String: Any] { ["type": "string"] }

    private static func function(
        _ name: String,
        _ description: String,
        _ properties: [String: Any] = [:],
        _ required: [String] = []
    ) -> [String: Any] {
        var parameters: [String: Any] = [
            "type": "object",
            "properties": properties,
            "additionalProperties": false
        ]
        if !required.isEmpty {
            parameters["required"] = required
        }
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": parameters
            ]
        ]
    }
}
