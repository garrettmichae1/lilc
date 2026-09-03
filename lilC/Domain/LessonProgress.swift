import Foundation
import Observation

enum LessonTrack: String, Codable, Sendable {
    case firstHour
    case challenge
}

struct LessonProgressState: Equatable, Sendable {
    var completedIds: [String]
    var currentFirstHourIndex: Int
    var currentChallengeIndex: Int

    static let empty = LessonProgressState(
        completedIds: [],
        currentFirstHourIndex: 0,
        currentChallengeIndex: 0
    )

    func isComplete(_ id: String) -> Bool {
        completedIds.contains(id)
    }

    var firstHourDone: Bool {
        FirstHourCurriculum.firstHour.allSatisfy { completedIds.contains($0.id) }
    }

    var challengesDone: Bool {
        FirstHourCurriculum.challenges.allSatisfy { completedIds.contains($0.id) }
    }

    var allDone: Bool {
        firstHourDone && challengesDone
    }

    var showsFirstHourDeck: Bool { !firstHourDone }

    var showsChallengesDeck: Bool { !challengesDone }
}

@MainActor
@Observable
final class LessonProgressStore {
    static let curriculumCollapsedKey = "lilc.home.curriculumCollapsed"

    private let storageKey = "lilc.firstHour.progress"
    private let defaults: UserDefaults

    var state: LessonProgressState

    /// Unused on the Learn tab. Kept so existing defaults do not reset.
    var curriculumCollapsed: Bool {
        didSet { defaults.set(curriculumCollapsed, forKey: Self.curriculumCollapsedKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.state = Self.load(from: defaults, key: storageKey)
        curriculumCollapsed = defaults.bool(forKey: Self.curriculumCollapsedKey)
    }

    func isComplete(_ id: String) -> Bool {
        state.isComplete(id)
    }

    func setCurrent(_ lesson: FirstHourLesson) {
        guard let index = FirstHourCurriculum.index(of: lesson) else { return }
        switch lesson.track {
        case .firstHour:
            state.currentFirstHourIndex = index
        case .challenge:
            state.currentChallengeIndex = index
        }
        persist()
    }

    @discardableResult
    func markComplete(_ id: String) -> LessonProgressState {
        guard FirstHourCurriculum.lesson(id: id) != nil else { return state }
        if !state.completedIds.contains(id) {
            state.completedIds.append(id)
        }
        if let next = FirstHourCurriculum.nextIncomplete(after: id, completedIds: state.completedIds) {
            setCurrent(next)
        }
        persist()
        return state
    }

    func continueLesson() -> FirstHourLesson? {
        if !state.firstHourDone {
            return FirstHourCurriculum.continueLesson(
                in: .firstHour,
                completedIds: state.completedIds,
                currentIndex: state.currentFirstHourIndex
            )
        }
        if !state.challengesDone {
            return FirstHourCurriculum.continueLesson(
                in: .challenge,
                completedIds: state.completedIds,
                currentIndex: state.currentChallengeIndex
            )
        }
        return nil
    }

    private func persist() {
        let payload: [String: Any] = [
            "completedIds": state.completedIds,
            "currentFirstHourIndex": state.currentFirstHourIndex,
            "currentChallengeIndex": state.currentChallengeIndex,
        ]
        defaults.set(payload, forKey: storageKey)
    }

    private static func load(from defaults: UserDefaults, key: String) -> LessonProgressState {
        guard let payload = defaults.dictionary(forKey: key) else { return .empty }
        let ids = payload["completedIds"] as? [String] ?? []
        let known = Set(FirstHourCurriculum.all.map(\.id))
        return LessonProgressState(
            completedIds: ids.filter { known.contains($0) },
            currentFirstHourIndex: payload["currentFirstHourIndex"] as? Int ?? 0,
            currentChallengeIndex: payload["currentChallengeIndex"] as? Int ?? 0
        )
    }
}
