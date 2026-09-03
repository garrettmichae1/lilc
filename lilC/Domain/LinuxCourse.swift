import Foundation

enum LinuxCourseDiagram: String, Codable, Equatable, Sendable, CaseIterable {
    case unixTimeline
    case layerStack
    case fhsTree
    case shellProcess
    case lsListing
    case permissionGrid
    case pipeBoxes
    case bootSequence
    case networkStack
    case scriptExec
}

struct LinuxCoursePage: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let kicker: String
    let title: String
    let body: [String]
    var diagram: LinuxCourseDiagram?
}

struct LinuxCourseModule: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let number: Int
    let title: String
    let goal: String
    let quizId: String
    let pages: [LinuxCoursePage]

    var kicker: String {
        "Module \(number) of \(LinuxCourseCatalog.modules.count)"
    }
}

struct LinuxCourse: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let priceLabel: String
    let productID: String
    let goal: String
    let modules: [LinuxCourseModule]
}

enum LinuxCourseCatalog {
    static let title = "Linux"
    static let productID = "lilc.linux.course"
    static let priceLabel = "$2.99"

    static let course: LinuxCourse = load()
    static var modules: [LinuxCourseModule] { course.modules.sorted { $0.number < $1.number } }

    static func module(id: String) -> LinuxCourseModule? {
        modules.first { $0.id == id }
    }

    static func module(quizId: String) -> LinuxCourseModule? {
        modules.first { $0.quizId == quizId }
    }

    static func load(from data: Data) throws -> LinuxCourse {
        let decoder = JSONDecoder()
        var course = try decoder.decode(LinuxCourse.self, from: data)
        course = LinuxCourse(
            id: course.id,
            title: course.title,
            subtitle: course.subtitle,
            priceLabel: course.priceLabel,
            productID: course.productID,
            goal: course.goal,
            modules: course.modules.sorted { $0.number < $1.number }
        )
        return course
    }

    private static func load() -> LinuxCourse {
        let bundle = Bundle(for: LinuxCourseBundleToken.self)
        guard let url = bundle.url(forResource: "linux-course", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let course = try? load(from: data)
        else {
            return LinuxCourse(
                id: "linux-course",
                title: title,
                subtitle: "Unix, the kernel, and the shell",
                priceLabel: priceLabel,
                productID: productID,
                goal: "Offline study. A quiz after each module.",
                modules: []
            )
        }
        return course
    }
}

enum LinuxQuizCatalog {
    static let questionsPerQuiz = 20
    static let title = "Linux quizzes"

    static let file: CQuizFile = load()
    static var quizzes: [CQuiz] { file.quizzes.sorted { $0.number < $1.number } }

    static func quiz(id: String) -> CQuiz? {
        quizzes.first { $0.id == id }
    }

    static func load(from data: Data) throws -> CQuizFile {
        try CQuizCatalog.load(from: data)
    }

    private static func load() -> CQuizFile {
        let bundle = Bundle(for: LinuxCourseBundleToken.self)
        guard let url = bundle.url(forResource: "linux-quizzes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? load(from: data)
        else {
            return CQuizFile(title: title, questionsPerQuiz: questionsPerQuiz, quizzes: [])
        }
        return file
    }
}

enum QuizLookup {
    static func quiz(id: String, linuxOwned: Bool) -> CQuiz? {
        if let quiz = CQuizCatalog.quiz(id: id) {
            return quiz
        }
        guard linuxOwned else { return nil }
        return LinuxQuizCatalog.quiz(id: id)
    }
}

private final class LinuxCourseBundleToken {}
