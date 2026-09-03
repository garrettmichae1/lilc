import Foundation

struct CQuizQuestion: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var title: String?
    let prompt: String
    let choices: [String]
    let correctIndex: Int
    var explanation: String?
    var snippet: String?

    var isValid: Bool {
        choices.count >= 2 && choices.indices.contains(correctIndex)
    }

    init(
        id: String,
        title: String? = nil,
        prompt: String,
        choices: [String],
        correctIndex: Int,
        explanation: String? = nil,
        snippet: String? = nil
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.choices = choices
        self.correctIndex = correctIndex
        self.explanation = explanation
        self.snippet = snippet
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        prompt = try container.decode(String.self, forKey: .prompt)
        choices = try container.decode([String].self, forKey: .choices)
        if let index = try container.decodeIfPresent(Int.self, forKey: .correctIndex) {
            correctIndex = index
        } else {
            correctIndex = try container.decode(Int.self, forKey: .correctAnswerIndex)
        }
        explanation = try container.decodeIfPresent(String.self, forKey: .explanation)
        let code = try container.decodeIfPresent(String.self, forKey: .snippet)
            ?? container.decodeIfPresent(String.self, forKey: .codeSnippet)
        snippet = code.flatMap { $0.isEmpty ? nil : $0 }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(choices, forKey: .choices)
        try container.encode(correctIndex, forKey: .correctIndex)
        try container.encodeIfPresent(explanation, forKey: .explanation)
        try container.encodeIfPresent(snippet, forKey: .snippet)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case prompt
        case choices
        case correctIndex
        case correctAnswerIndex
        case explanation
        case snippet
        case codeSnippet
    }
}

struct CQuiz: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let number: Int
    let title: String
    let goal: String
    let questions: [CQuizQuestion]

    var kicker: String {
        "Quiz \(number) of \(CQuizCatalog.quizzes.count)"
    }

    var isReady: Bool {
        !questions.isEmpty && questions.allSatisfy(\.isValid)
    }

    init(id: String, number: Int, title: String, goal: String, questions: [CQuizQuestion]) {
        self.id = id
        self.number = number
        self.title = title
        self.goal = goal
        self.questions = questions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        questions = try container.decode([CQuizQuestion].self, forKey: .questions)
        if let number = try container.decodeIfPresent(Int.self, forKey: .number) {
            self.number = number
        } else {
            self.number = Self.number(from: id)
        }
        if let goal = try container.decodeIfPresent(String.self, forKey: .goal), !goal.isEmpty {
            self.goal = goal
        } else {
            let difficulty = try container.decodeIfPresent(String.self, forKey: .difficulty)
            let tags = try container.decodeIfPresent([String].self, forKey: .topicTags) ?? []
            self.goal = Self.makeGoal(difficulty: difficulty, tags: tags)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(number, forKey: .number)
        try container.encode(title, forKey: .title)
        try container.encode(goal, forKey: .goal)
        try container.encode(questions, forKey: .questions)
    }

    func score(selectedIndexes: [Int]) -> Int {
        zip(questions, selectedIndexes).reduce(0) { total, pair in
            total + (pair.0.choices.indices.contains(pair.1) && pair.1 == pair.0.correctIndex ? 1 : 0)
        }
    }

    static func number(from id: String) -> Int {
        let digits = String(id.reversed().prefix(while: \.isNumber).reversed())
        return Int(digits) ?? 0
    }

    static func makeGoal(difficulty: String?, tags: [String]) -> String {
        let topics = tags.map { $0.replacingOccurrences(of: "-", with: " ") }
        let topicText = topics.isEmpty ? "" : " on \(topics.joined(separator: ", "))"
        guard let difficulty, !difficulty.isEmpty else {
            return "Twenty questions\(topicText)."
        }
        let level = difficulty.prefix(1).uppercased() + difficulty.dropFirst()
        return "\(level). Twenty questions\(topicText)."
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case number
        case title
        case goal
        case questions
        case difficulty
        case topicTags
    }
}

struct CQuizFile: Codable, Equatable, Sendable {
    var title: String
    var questionsPerQuiz: Int
    var quizzes: [CQuiz]

    init(title: String, questionsPerQuiz: Int, quizzes: [CQuiz]) {
        self.title = title
        self.questionsPerQuiz = questionsPerQuiz
        self.quizzes = quizzes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Quizzes"
        questionsPerQuiz = try container.decodeIfPresent(Int.self, forKey: .questionsPerQuiz) ?? 20
        quizzes = try container.decode([CQuiz].self, forKey: .quizzes)
    }
}

enum CQuizCatalog {
    static let questionsPerQuiz = 20
    static let title = "Quizzes"

    static let file: CQuizFile = load()
    static var quizzes: [CQuiz] { file.quizzes.sorted { $0.number < $1.number } }

    static func quiz(id: String) -> CQuiz? {
        quizzes.first { $0.id == id }
    }

    static func load(from data: Data) throws -> CQuizFile {
        let decoder = JSONDecoder()
        var file = try decoder.decode(CQuizFile.self, from: data)
        file.quizzes.sort { $0.number < $1.number }
        return file
    }

    private static func load() -> CQuizFile {
        let bundle = Bundle(for: QuizBundleToken.self)
        guard let url = bundle.url(forResource: "quizzes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? load(from: data)
        else {
            return CQuizFile(title: title, questionsPerQuiz: questionsPerQuiz, quizzes: [])
        }
        return file
    }
}

private final class QuizBundleToken {}
