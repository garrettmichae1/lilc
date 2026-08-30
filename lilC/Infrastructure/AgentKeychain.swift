import Foundation
import Security

enum AgentKeychain {
    private static let debugService = "app.lilc.agent.debug-token"
    private static let deviceService = "app.lilc.device-id"
    private static let githubService = "app.lilc.github-token"

    static func loadKey() -> String? { load(debugService) }

    static func saveKey(_ value: String) { save(value, service: debugService) }

    static func deleteKey() { delete(debugService) }

    static var hasKey: Bool { loadKey()?.isEmpty == false }

    static func deviceID() -> String {
        if let existing = load(deviceService), !existing.isEmpty { return existing }
        let id = UUID().uuidString
        save(id, service: deviceService)
        return id
    }

    static func githubToken() -> String? { load(githubService) }

    static func saveGitHubToken(_ value: String) { save(value, service: githubService) }

    static func deleteGitHubToken() {
        delete(githubService)
        NotificationCenter.default.post(name: .lilCGitHubChanged, object: nil)
    }

    static func consumeGitHubCallback(_ url: URL) -> Bool {
        guard url.scheme == "lilc", url.host == "github-oauth" else { return false }
        let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "token" })?
            .value
        guard let token, !token.isEmpty else { return false }
        saveGitHubToken(token)
        NotificationCenter.default.post(name: .lilCGitHubChanged, object: nil)
        return true
    }

    private static func load(_ service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ value: String, service: String) {
        delete(service)
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: Data(trimmed.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func delete(_ service: String) {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ] as CFDictionary)
    }
}

extension Notification.Name {
    static let lilCGitHubChanged = Notification.Name("lilCGitHubChanged")
}
