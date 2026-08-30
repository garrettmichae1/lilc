import Foundation

enum AgentTransportError: LocalizedError, Equatable {
    case notConfigured
    case invalidEndpoint
    case missingAPIKey
    case httpStatus(Int, String)
    case decoding
    case cancelled
    case safeguards

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "lilC Agent is not connected to the worker yet."
        case .invalidEndpoint:
            "The agent only talks to lilC’s HTTPS hosts."
        case .missingAPIKey:
            "Could not reach the agent. Turn on Share with AI and try again."
        case .httpStatus(let code, let detail):
            if code == 429 {
                detail.isEmpty ? "Free agent allowance used for this 12-hour window. Try later, or connect GitHub you already have." : detail
            } else {
                "Agent request failed (\(code))."
            }
        case .decoding:
            "The agent response could not be read."
        case .cancelled:
            "Stopped."
        case .safeguards:
            "Safeguards are on. Turn them off in Settings to let the agent delete."
        }
    }
}

enum AgentEndpointPolicy {
    static func validatedGateway(_ raw: String, allowedHosts: [String]) throws -> URL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let host = url.host, !host.isEmpty else {
            throw AgentTransportError.invalidEndpoint
        }
        let scheme = url.scheme?.lowercased() ?? ""
        #if DEBUG
        if (host == "localhost" || host == "127.0.0.1"), scheme == "http" || scheme == "https" {
            return url
        }
        #endif
        guard scheme == "https" else { throw AgentTransportError.invalidEndpoint }
        let blocked = ["localhost", "127.0.0.1", "0.0.0.0", "::1"]
        if blocked.contains(host.lowercased()) { throw AgentTransportError.invalidEndpoint }
        if hostAllowed(host, allowedHosts: allowedHosts) {
            return url
        }
        throw AgentTransportError.invalidEndpoint
    }

    private static func hostAllowed(_ host: String, allowedHosts: [String]) -> Bool {
        let value = host.lowercased()
        if allowedHosts.contains(where: { $0.lowercased() == value }) { return true }
        if value.hasSuffix(".workers.dev") { return true }
        return false
    }
}

struct AgentChatMessage: Identifiable, Equatable {
    enum Role: String {
        case user
        case assistant
        case system
        case tool
    }

    let id: UUID
    var role: Role
    var text: String
    var toolName: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        toolName: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.toolName = toolName
        self.createdAt = createdAt
    }
}

struct AgentToolCall: Equatable {
    var id: String
    var name: String
    var argumentsJSON: String
}

/// Build-time agent routing. Provider keys never belong in source, Info.plist, or UserDefaults.
enum AgentRuntimeConfig {
    /// Flip to true in a later release to show Agent tab, Settings, and IAP again. Architecture stays in the tree.
    static let surfacesVisibleInThisRelease = false

    static let model = "gpt-4o-mini"
    #if DEBUG
    static let gatewayURL = "http://127.0.0.1:8787/v1"
    #else
    static let gatewayURL = "https://api.lilc.app/v1"
    #endif
    static let allowedHosts = ["api.lilc.app"]
}
