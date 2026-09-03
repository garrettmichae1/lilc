import Foundation
import Observation

struct QuizAttempt: Codable, Equatable, Sendable {
    var quizId: String
    var selectedIndexes: [Int]
    var score: Int
    var total: Int
    var finishedAt: Date
}

@MainActor
@Observable
final class QuizProgressStore {
    static let storageKey = "lilc.quizzes.progress"

    private let defaults: UserDefaults
    var attempts: [QuizAttempt]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.attempts = Self.load(from: defaults)
    }

    func hasTaken(_ quizId: String) -> Bool {
        attempts.contains { $0.quizId == quizId }
    }

    func latestAttempt(for quizId: String) -> QuizAttempt? {
        attempts.last { $0.quizId == quizId }
    }

    func bestAttempt(for quizId: String) -> QuizAttempt? {
        attempts.filter { $0.quizId == quizId }.max { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.finishedAt < rhs.finishedAt
            }
            return lhs.score < rhs.score
        }
    }

    func record(_ attempt: QuizAttempt) {
        attempts.append(attempt)
        persist()
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(attempts) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> [QuizAttempt] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([QuizAttempt].self, from: data)) ?? []
    }
}
