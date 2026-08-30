import Foundation
import StoreKit

struct AgentCompletion {
    var assistantText: String
    var toolCalls: [AgentToolCall]
}

protocol AgentCompleting: Sendable {
    func complete(messagesJSON: Data, toolsJSON: Data) async throws -> AgentCompletion
}

struct OpenAICompatibleAgentClient: AgentCompleting {
    var baseURL: URL
    var model: String
    var debugToken: String?
    var appleTransactionJWS: String?

    func complete(messagesJSON: Data, toolsJSON: Data) async throws -> AgentCompletion {
        let messages = try JSONSerialization.jsonObject(with: messagesJSON)
        let tools = try JSONSerialization.jsonObject(with: toolsJSON)
        var endpoint = baseURL
        if endpoint.path.isEmpty || endpoint.path == "/" {
            endpoint.append(path: "chat/completions")
        } else if !endpoint.path.hasSuffix("chat/completions") {
            endpoint.append(path: "chat/completions")
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AgentKeychain.deviceID(), forHTTPHeaderField: "X-LilC-Device")
        if let appleTransactionJWS, !appleTransactionJWS.isEmpty {
            request.setValue(appleTransactionJWS, forHTTPHeaderField: "X-Apple-Transaction-JWS")
        }
        if let debugToken, !debugToken.isEmpty {
            request.setValue(debugToken, forHTTPHeaderField: "X-LilC-Debug")
        }
        if let github = AgentKeychain.githubToken(), !github.isEmpty {
            request.setValue(github, forHTTPHeaderField: "X-LilC-GitHub")
        }
        request.timeoutInterval = 90

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "tools": tools,
            "tool_choice": "auto"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status < 200 || status >= 300 {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["message"] as? String }
            throw AgentTransportError.httpStatus(status, message ?? "rejected")
        }

        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = root["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any]
        else {
            throw AgentTransportError.decoding
        }

        let text = message["content"] as? String ?? ""
        var calls: [AgentToolCall] = []
        if let rawCalls = message["tool_calls"] as? [[String: Any]] {
            for call in rawCalls {
                let id = call["id"] as? String ?? UUID().uuidString
                let function = call["function"] as? [String: Any]
                let name = function?["name"] as? String ?? ""
                let args = function?["arguments"] as? String ?? "{}"
                calls.append(AgentToolCall(id: id, name: name, argumentsJSON: args))
            }
        }
        return AgentCompletion(assistantText: text, toolCalls: calls)
    }
}

enum AgentEntitlement {
    static let monthlyProductID = "lilc.agent.monthly"

    static func transactionJWS() async -> String? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == monthlyProductID {
                if #available(iOS 18.0, *) {
                    return result.jwsRepresentation
                }
            }
        }
        return nil
    }
}
