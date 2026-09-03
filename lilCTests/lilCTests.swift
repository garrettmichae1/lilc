import Foundation
import SwiftUI
import Testing
import UIKit
@testable import lilC

@Suite(.serialized)
struct lilCTests {
    @Test func agentSurfacesStayHiddenInThisRelease() {
        #expect(AgentRuntimeConfig.surfacesVisibleInThisRelease == false)
    }

    @Test func extraLegalRowsStayHiddenInThisRelease() {
        #expect(LegalURLs.extraLegalRowsVisibleInThisRelease == false)
    }

    @Test func picoCSettingsNoteSaysLibrariesWillNotWork() {
        #expect(SettingsScreen.picoCExplanation.contains("interpreter, not a compiler"))
        #expect(SettingsScreen.picoCExplanation.contains("C libraries"))
        #expect(SettingsScreen.picoCExplanation.contains("will not work"))
        #expect(SettingsScreen.picoCExplanation.contains("beginner programs") == false)
        #expect(SettingsScreen.picoCExplanation.contains("standard library") == false)
    }

    @MainActor
    @Test func firstLaunchShowsOnboarding() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let store = OnboardingStore(defaults: suite)
        #expect(store.hasCompleted == false)
        #expect(store.needsOnboarding)
        #expect(OnboardingCopy.pageCount == 2)
    }

    @MainActor
    @Test func completingOnboardingSetsFlagAndSubsequentLaunchSkips() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let first = OnboardingStore(defaults: suite)
        #expect(first.needsOnboarding)
        first.complete()
        #expect(first.hasCompleted)
        #expect(first.needsOnboarding == false)
        #expect(suite.bool(forKey: OnboardingStore.storageKey))

        let subsequent = OnboardingStore(defaults: suite)
        #expect(subsequent.hasCompleted)
        #expect(subsequent.needsOnboarding == false)
    }

    @MainActor
    @Test func skippingOnboardingSetsTheSameFlag() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let store = OnboardingStore(defaults: suite)
        store.complete()
        #expect(OnboardingStore(defaults: suite).needsOnboarding == false)
    }

    @MainActor
    @Test func filesFolderTipShowsOnceUntilDismissed() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let first = OnboardingStore(defaults: suite)
        #expect(first.needsFilesFolderTip)
        #expect(OnboardingCopy.filesFolderTip == "Create a folder, then drag C files into it.")
        first.dismissFilesFolderTip()
        #expect(first.needsFilesFolderTip == false)
        #expect(suite.bool(forKey: OnboardingStore.filesFolderTipKey))
        #expect(OnboardingStore(defaults: suite).needsFilesFolderTip == false)
    }

    @MainActor
    @Test func syntaxColoringDefaultsOffAndPersists() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let first = AppearanceStore(defaults: suite)
        #expect(first.syntaxColoring == false)
        first.syntaxColoring = true
        #expect(suite.bool(forKey: AppearanceStore.syntaxColoringKey))
        let next = AppearanceStore(defaults: suite)
        #expect(next.syntaxColoring)
        next.syntaxColoring = false
        #expect(AppearanceStore(defaults: suite).syntaxColoring == false)
    }

    @MainActor
    @Test func navigationHapticsUseAppleLightImpactAndSelection() {
        AppHaptics.prepare()
        AppHaptics.tap()
        AppHaptics.select()
        AppHaptics.play(.tap)
        AppHaptics.play(.select)
    }

    @Test func syntaxLexerColorsKeywordsOperatorsAndSkipsStrings() {
        let source = """
        #include <stdio.h>
        int main(void) {
            if (x == 1) {
                printf("if");
            }
            // if
            return 0x2A;
        }
        """
        let tokens = CSyntaxLexer.tokens(in: source)
        let labeled = tokens.map { token -> (CSyntaxKind, String) in
            let text = (source as NSString).substring(with: token.range)
            return (token.kind, text)
        }
        #expect(labeled.contains { $0.0 == .preprocessor && $0.1.hasPrefix("#include") })
        #expect(labeled.contains { $0.0 == .type && $0.1 == "int" })
        #expect(labeled.contains { $0.0 == .type && $0.1 == "void" })
        #expect(labeled.contains { $0.0 == .control && $0.1 == "if" })
        #expect(labeled.contains { $0.0 == .control && $0.1 == "return" })
        #expect(labeled.contains { $0.0 == .op && $0.1 == "==" })
        #expect(labeled.contains { $0.0 == .string && $0.1 == "\"if\"" })
        #expect(labeled.contains { $0.0 == .comment && $0.1.contains("if") })
        #expect(labeled.contains { $0.0 == .number && $0.1 == "0x2A" })
        #expect(labeled.contains { $0.0 == .control && $0.1 == "printf" } == false)
        #expect(labeled.filter { $0.0 == .control && $0.1 == "if" }.count == 1)
    }

    @Test func syntaxLexerDoesNotHangOnUnclosedString() {
        let source = "char *s = \"hello"
        let tokens = CSyntaxLexer.tokens(in: source)
        #expect(tokens.contains { $0.kind == .string })
        let texts = tokens.map { (source as NSString).substring(with: $0.range) }
        #expect(texts.contains("char"))
    }

    @Test func onboardingCopyIsTwoTightPages() {
        #expect(OnboardingCopy.page1Headline == "Write C. Press Run.")
        #expect(OnboardingCopy.page1Line == "lilC runs your code locally")
        #expect(OnboardingCopy.continueTitle == "Continue")
        #expect(OnboardingCopy.page2Headline == "C stays free. Zero ads.")
        #expect(OnboardingCopy.page2Line == "For students and developers.")
        #expect(OnboardingCopy.getStartedTitle == "Get Started")
        #expect(OnboardingCopy.skipTitle == "Skip")
        let all = [
            OnboardingCopy.page1Headline,
            OnboardingCopy.page1Line,
            OnboardingCopy.page2Headline,
            OnboardingCopy.page2Line,
        ].joined(separator: " ")
        #expect(all.split(whereSeparator: \.isWhitespace).count <= 18)
        let banned = ["GCC", "Agent", "C Manual", "Classroom", "subscription", "revolutionary"]
        for word in banned {
            #expect(all.localizedCaseInsensitiveContains(word) == false)
        }
    }

    @MainActor
    @Test func onboardingViewRendersInLightAndDark() {
        let previous = AppearanceStore.shared.colorWay
        defer { AppearanceStore.shared.colorWay = previous }
        for way in AppColorWay.allCases {
            AppearanceStore.shared.colorWay = way
            let view = OnboardingView(finish: {})
                .frame(width: 393, height: 852)
                .background(AppPalette.background)
                .lilCPreferredScheme(way)
                .id(way)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            let image = renderer.uiImage
            #expect(image != nil, "Onboarding should render in \(way.title)")
            #expect((image?.size.width ?? 0) >= 393)
            #expect((image?.size.height ?? 0) >= 852)
        }
    }

    @Test func legalURLsArePublicGitHubPages() {
        #expect(LegalURLs.home.absoluteString == "https://garrettmichae1.github.io/lilc/")
        #expect(LegalURLs.privacy.absoluteString == "https://garrettmichae1.github.io/lilc/privacy.html")
        #expect(LegalURLs.terms.absoluteString == "https://garrettmichae1.github.io/lilc/terms.html")
        #expect(LegalURLs.teachers.absoluteString == "https://garrettmichae1.github.io/lilc/teachers.html")
        #expect(LegalURLs.webPlayground.absoluteString == "https://garrettmichae1.github.io/lilc/web/")
        #expect(LegalURLs.privacy.scheme == "https")
        #expect(LegalURLs.terms.scheme == "https")
        #expect(LegalURLs.appStoreNumericID == "6806824902")
        #expect(LegalURLs.writeReviewURL(for: "") == nil)
        #expect(LegalURLs.writeReviewURL()?.absoluteString == "https://apps.apple.com/app/id6806824902?action=write-review")
        #expect(LegalURLs.writeReviewURL(for: "123456789")?.absoluteString == "https://apps.apple.com/app/id123456789?action=write-review")
    }

    @MainActor
    @Test func appReviewPromptFiresOnceThenStops() {
        #expect(AppReviewPrompt.shouldPrompt(alreadyPrompted: false, screenshotsBypass: false))
        #expect(AppReviewPrompt.shouldPrompt(alreadyPrompted: true, screenshotsBypass: false) == false)
        #expect(AppReviewPrompt.shouldPrompt(alreadyPrompted: false, screenshotsBypass: true) == false)
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let store = AppReviewPromptStore(defaults: suite)
        #expect(store.hasPrompted == false)
        store.noteLearningWin()
        #expect(store.hasPrompted)
        store.noteLearningWin()
        #expect(suite.bool(forKey: AppReviewPrompt.storageKey))
        #expect(AppReviewPromptStore(defaults: suite).hasPrompted)
    }

    @Test func firstHourCurriculumLoadsTwentyOptionalLessons() {
        #expect(FirstHourCurriculum.lessons.count == 20)
        #expect(FirstHourCurriculum.firstHour.count == 20)
        #expect(FirstHourCurriculum.first.id == "hello")
        #expect(FirstHourCurriculum.lesson(id: "function")?.number == 6)
        #expect(FirstHourCurriculum.lesson(id: "copy")?.number == 20)
        #expect(Set(FirstHourCurriculum.lessons.map(\.id)).count == 20)
        #expect(Set(FirstHourCurriculum.lessons.map(\.fileName)).count == 20)
        for lesson in FirstHourCurriculum.lessons {
            #expect(lesson.relativePath.hasPrefix("lessons/"))
            #expect(lesson.source.contains("int main("))
            #expect(lesson.source.contains("???"))
            #expect(lesson.solution.contains("???") == false)
        }
    }

    @Test func firstHourLessonsRunOnPicoC() {
        for lesson in FirstHourCurriculum.firstHour {
            #expect(LessonWinChecker.passes(lesson: lesson, output: "", source: lesson.source) == false)
            let output = LocalCRunner.run(lesson.solution)
            #expect(
                LessonWinChecker.passes(lesson: lesson, output: output, source: lesson.solution),
                "\(lesson.id) produced \(output)"
            )
        }
    }

    @Test func challengeStartersNeedWorkAndSolutionsPassPicoC() {
        #expect(FirstHourCurriculum.challenges.count == 12)
        #expect(Set(FirstHourCurriculum.challenges.map(\.id)).count == 12)
        for lesson in FirstHourCurriculum.challenges {
            #expect(lesson.relativePath.hasPrefix("challenges/"))
            #expect(lesson.source.contains("???"))
            #expect(LessonWinChecker.passes(lesson: lesson, output: "", source: lesson.source) == false)
            let output = LocalCRunner.run(lesson.solution)
            #expect(
                LessonWinChecker.passes(lesson: lesson, output: output, source: lesson.solution),
                "\(lesson.id) produced \(output)"
            )
        }
    }

    @Test func homeShowsChallengesDeckWhileFirstHourIsIncomplete() {
        let empty = LessonProgressState.empty
        #expect(empty.showsFirstHourDeck)
        #expect(empty.showsChallengesDeck)
        #expect(empty.allDone == false)

        var firstHourOnly = LessonProgressState.empty
        firstHourOnly.completedIds = FirstHourCurriculum.firstHour.map(\.id)
        #expect(firstHourOnly.showsFirstHourDeck == false)
        #expect(firstHourOnly.showsChallengesDeck)
        #expect(firstHourOnly.allDone == false)

        var challengesOnly = LessonProgressState.empty
        challengesOnly.completedIds = FirstHourCurriculum.challenges.map(\.id)
        #expect(challengesOnly.showsFirstHourDeck)
        #expect(challengesOnly.showsChallengesDeck == false)

        var both = LessonProgressState.empty
        both.completedIds = FirstHourCurriculum.all.map(\.id)
        #expect(both.showsFirstHourDeck == false)
        #expect(both.showsChallengesDeck == false)
        #expect(both.allDone)
    }

    @MainActor
    @Test func lessonProgressHidesDeckWhenEveryChallengeIsDone() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let store = LessonProgressStore(defaults: suite)
        #expect(store.state.allDone == false)
        for lesson in FirstHourCurriculum.all {
            store.markComplete(lesson.id)
        }
        #expect(store.state.firstHourDone)
        #expect(store.state.challengesDone)
        #expect(store.state.allDone)
        #expect(store.state.showsFirstHourDeck == false)
        #expect(store.state.showsChallengesDeck == false)
        #expect(store.continueLesson() == nil)
    }

    @MainActor
    @Test func curriculumCollapsedDefaultsOffAndPersists() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let first = LessonProgressStore(defaults: suite)
        #expect(first.curriculumCollapsed == false)
        first.curriculumCollapsed = true
        #expect(suite.bool(forKey: LessonProgressStore.curriculumCollapsedKey))
        #expect(LessonProgressStore(defaults: suite).curriculumCollapsed)
        first.curriculumCollapsed = false
        #expect(LessonProgressStore(defaults: suite).curriculumCollapsed == false)
    }

    @Test func quizCatalogLoadsStubQuizzesInAnyOrder() throws {
        let json = """
        {
          "title": "Quizzes",
          "questionsPerQuiz": 20,
          "quizzes": [
            {"id":"quiz-03","number":3,"title":"Quiz 3","goal":"Last","questions":[]},
            {"id":"quiz-01","number":1,"title":"Quiz 1","goal":"First","questions":[]}
          ]
        }
        """
        let file = try CQuizCatalog.load(from: Data(json.utf8))
        #expect(file.questionsPerQuiz == 20)
        #expect(file.quizzes.map(\.id) == ["quiz-01", "quiz-03"])
        #expect(file.quizzes.allSatisfy { $0.isReady == false })
    }

    @Test func quizScoresSelectedAnswersAndAllowsStartingAtTheLastQuiz() throws {
        let json = """
        {
          "title": "Quizzes",
          "questionsPerQuiz": 20,
          "quizzes": [
            {
              "id": "quiz-03",
              "number": 3,
              "title": "Quiz 3",
              "goal": "Twenty questions",
              "questions": [
                {
                  "id": "q1",
                  "prompt": "Which is a type?",
                  "choices": ["int", "for"],
                  "correctIndex": 0,
                  "explanation": "int names a type."
                },
                {
                  "id": "q2",
                  "prompt": "What does this print?",
                  "choices": ["0", "1"],
                  "correctIndex": 1,
                  "snippet": "int x = 1;"
                }
              ]
            }
          ]
        }
        """
        let file = try CQuizCatalog.load(from: Data(json.utf8))
        let quiz = try #require(file.quizzes.first)
        #expect(quiz.isReady)
        #expect(quiz.score(selectedIndexes: [0, 1]) == 2)
        #expect(quiz.score(selectedIndexes: [0, 0]) == 1)
        #expect(quiz.score(selectedIndexes: [-1, -1]) == 0)
    }

    @MainActor
    @Test func quizAttemptsPersistAndKeepTheBestScore() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let store = QuizProgressStore(defaults: suite)
        #expect(store.hasTaken("c-quiz-10") == false)

        let first = QuizAttempt(
            quizId: "c-quiz-10",
            selectedIndexes: [0, 0],
            score: 1,
            total: 2,
            finishedAt: Date(timeIntervalSince1970: 1)
        )
        store.record(first)
        #expect(store.hasTaken("c-quiz-10"))
        #expect(store.bestAttempt(for: "c-quiz-10")?.score == 1)

        let better = QuizAttempt(
            quizId: "c-quiz-10",
            selectedIndexes: [0, 1],
            score: 2,
            total: 2,
            finishedAt: Date(timeIntervalSince1970: 2)
        )
        store.record(better)
        #expect(store.bestAttempt(for: "c-quiz-10")?.score == 2)
        #expect(store.latestAttempt(for: "c-quiz-10")?.score == 2)

        let reloaded = QuizProgressStore(defaults: suite)
        #expect(reloaded.bestAttempt(for: "c-quiz-10")?.score == 2)
        #expect(reloaded.hasTaken("c-quiz-10"))
    }

    @Test func quizCatalogLoadsSourceFileShapeAndBundledQuizzes() throws {
        let json = """
        {
          "title": "lilC C Programming Quizzes",
          "quizzes": [
            {
              "id": "c-quiz-10",
              "title": "Undefined Behavior",
              "difficulty": "hard",
              "topicTags": ["undefined-behavior"],
              "questions": [
                {
                  "id": "q1",
                  "title": "Trap",
                  "prompt": "Which is undefined?",
                  "choices": ["initialized int", "uninitialized automatic int"],
                  "correctAnswerIndex": 1,
                  "codeSnippet": "int x;",
                  "explanation": "Uninitialized."
                }
              ]
            },
            {
              "id": "c-quiz-01",
              "title": "Foundations",
              "difficulty": "easy",
              "topicTags": ["types"],
              "questions": [
                {
                  "id": "q1",
                  "prompt": "Which is a type?",
                  "choices": ["int", "for"],
                  "correctAnswerIndex": 0
                }
              ]
            }
          ]
        }
        """
        let file = try CQuizCatalog.load(from: Data(json.utf8))
        #expect(file.quizzes.map(\.id) == ["c-quiz-01", "c-quiz-10"])
        #expect(file.quizzes[0].goal == "Easy. Twenty questions on types.")
        #expect(file.quizzes[1].questions[0].correctIndex == 1)
        #expect(file.quizzes[1].questions[0].snippet == "int x;")
        #expect(CQuizCatalog.quizzes.count == 10)
        #expect(CQuizCatalog.quizzes.allSatisfy { $0.questions.count == 20 && $0.isReady })
        #expect(CQuizCatalog.quiz(id: "c-quiz-10") != nil)
        #expect(CQuizCatalog.quiz(id: "linux-quiz-01") == nil)
    }

    @Test func linuxCourseCatalogHasTenModulesAndDiagrams() {
        #expect(LinuxCourseCatalog.productID == "lilc.linux.course")
        #expect(LinuxCourseStore.productID == "lilc.linux.course")
        #expect(LinuxCourseCatalog.course.productID == "lilc.linux.course")
        #expect(LinuxCourseCatalog.course.priceLabel == "$2.99")
        #expect(LinuxCourseCatalog.modules.count == 10)
        #expect(Set(LinuxCourseCatalog.modules.map(\.id)).count == 10)
        #expect(Set(LinuxCourseCatalog.modules.map(\.quizId)).count == 10)
        for module in LinuxCourseCatalog.modules {
            #expect(module.pages.count >= 8)
            #expect(module.pages.count <= 12)
            #expect(module.quizId == "linux-quiz-\(String(format: "%02d", module.number))")
            #expect(LinuxCourseCatalog.module(id: module.id)?.id == module.id)
            #expect(LinuxCourseCatalog.module(quizId: module.quizId)?.id == module.id)
            for page in module.pages {
                #expect(page.body.isEmpty == false)
                #expect(page.title.isEmpty == false)
            }
        }
        let kinds = Set(LinuxCourseCatalog.modules.flatMap(\.pages).compactMap(\.diagram))
        #expect(kinds == Set(LinuxCourseDiagram.allCases))
        #expect(FirstHourCurriculum.firstHour.count == 20)
        #expect(FirstHourCurriculum.challenges.count == 12)
        #expect(CQuizCatalog.quizzes.count == 10)
    }

    @Test func linuxQuizzesAreTwentyEachAndNamespaced() throws {
        #expect(LinuxQuizCatalog.quizzes.count == 10)
        #expect(LinuxQuizCatalog.quizzes.allSatisfy { $0.questions.count == 20 && $0.isReady })
        for quiz in LinuxQuizCatalog.quizzes {
            #expect(quiz.id.hasPrefix("linux-quiz-"))
            #expect(quiz.questions.allSatisfy { $0.explanation?.isEmpty == false })
            #expect(Set(quiz.questions.map(\.id)).count == 20)
            let score = quiz.score(selectedIndexes: quiz.questions.map(\.correctIndex))
            #expect(score == 20)
        }
        #expect(LinuxQuizCatalog.quiz(id: "linux-quiz-10") != nil)
        #expect(LinuxQuizCatalog.quiz(id: "c-quiz-01") == nil)
    }

    @Test func linuxQuizLookupStaysGatedUntilOwned() {
        #expect(QuizLookup.quiz(id: "c-quiz-01", linuxOwned: false) != nil)
        #expect(QuizLookup.quiz(id: "linux-quiz-01", linuxOwned: false) == nil)
        #expect(QuizLookup.quiz(id: "linux-quiz-01", linuxOwned: true)?.id == "linux-quiz-01")
    }

    @MainActor
    @Test func linuxCourseStartsLockedAndDebugUnlocks() async {
        let suite = UserDefaults(suiteName: "lilc-linux-\(UUID().uuidString)")!
        let locked = LinuxCourseStore(defaults: suite)
        await locked.refreshEntitlements()
        #expect(locked.isOwned == false)
        suite.set(true, forKey: LinuxCourseStore.debugUnlockKey)
        let unlocked = LinuxCourseStore(defaults: suite)
        await unlocked.refreshEntitlements()
        #if DEBUG
        #expect(unlocked.isOwned)
        #else
        #expect(unlocked.isOwned == false)
        #endif
    }

    @Test func invalidParensOutputDoesNotPassValidParens() {
        let lesson = FirstHourCurriculum.lesson(id: "valid-parens")!
        #expect(lesson.win.matches(output: "invalid") == false)
        #expect(lesson.win.matches(output: "invalid\n") == false)
        #expect(lesson.win.matches(output: "valid"))
        #expect(lesson.win.matches(output: "valid\nProgram finished.\n"))
    }

    @Test func twoSumDoesNotPassOnZeroTen() {
        let lesson = FirstHourCurriculum.lesson(id: "two-sum")!
        #expect(lesson.win.matches(output: "0 10") == false)
        #expect(lesson.win.matches(output: "0 10\n") == false)
        #expect(lesson.win.matches(output: "0 1"))
        #expect(lesson.win.matches(output: "0 1\n"))
        #expect(lesson.win.matches(output: "0 1\nProgram finished.\n"))
    }

    @Test func plusOneAndMoveZeroesUseExactWins() {
        let plus = FirstHourCurriculum.lesson(id: "plus-one")!
        #expect(plus.win.matches(output: "1 2 40") == false)
        #expect(plus.win.matches(output: "1 2 4"))
        let move = FirstHourCurriculum.lesson(id: "move-zeroes")!
        #expect(move.win.matches(output: "1 3 12 0 0 9") == false)
        #expect(move.win.matches(output: "1 3 12 0 0\nProgram finished.\n"))
    }

    @Test func palindromeWinIsExactYes() {
        let lesson = FirstHourCurriculum.lesson(id: "palindrome")!
        #expect(lesson.win.matches(output: "yes"))
        #expect(lesson.win.matches(output: "yesterday") == false)
        #expect(lesson.win.matches(output: "no") == false)
    }

    @Test func firstHourHelloRequiresTheFilledInMessage() {
        let hello = FirstHourCurriculum.first
        #expect(hello.source.contains("???"))
        #expect(LessonWinChecker.passes(lesson: hello, output: "hello from lilC\n", source: hello.source) == false)
        #expect(LessonWinChecker.passes(lesson: hello, output: "hello from lilC\n", source: hello.solution))
        #expect(LessonWinChecker.passes(lesson: hello, output: "howdy\n", source: hello.solution) == false)
    }

    @Test func firstHourIfAcceptsWarmOrCool() {
        let lesson = FirstHourCurriculum.lesson(id: "if")!
        #expect(LessonWinChecker.passes(lesson: lesson, output: "warm\n", source: lesson.solution))
        #expect(LessonWinChecker.passes(lesson: lesson, output: "cool\n", source: lesson.solution))
        #expect(LessonWinChecker.passes(lesson: lesson, output: "hot\n", source: lesson.solution) == false)
        #expect(LessonWinChecker.passes(lesson: lesson, output: "warm\n", source: lesson.source) == false)
    }

    @Test(arguments: BridgingLessonCase.all)
    func bridgingLessonRejectsStarterAndWrongOutput(_ row: BridgingLessonCase) {
        let lesson = FirstHourCurriculum.lesson(id: row.id)!
        #expect(lesson.number == row.number)
        #expect(lesson.fileName == row.fileName)
        #expect(lesson.relativePath == "lessons/\(row.fileName)")
        #expect(lesson.source.contains("???"))
        #expect(lesson.solution.contains("???") == false)
        #expect(LessonWinChecker.passes(lesson: lesson, output: row.good, source: lesson.source) == false)
        #expect(LessonWinChecker.passes(lesson: lesson, output: row.good, source: lesson.solution))
        #expect(LessonWinChecker.passes(lesson: lesson, output: row.bad, source: lesson.solution) == false)
        let output = LocalCRunner.run(lesson.solution)
        #expect(
            LessonWinChecker.passes(lesson: lesson, output: output, source: lesson.solution),
            "\(row.id) produced \(output)"
        )
        #expect(FirstHourCurriculum.next(after: lesson)?.id == row.nextId)
    }

    @Test func bridgingLessonsRequireTheTaughtConstruct() {
        let sum = FirstHourCurriculum.lesson(id: "sum-fn")!
        #expect(LessonWinChecker.passes(lesson: sum, output: "7\n", source: sum.solution.replacingOccurrences(of: "sum", with: "add")) == false)
        let opposite = FirstHourCurriculum.lesson(id: "opposite")!
        #expect(LessonWinChecker.passes(lesson: opposite, output: "4\n", source: opposite.solution.replacingOccurrences(of: "opposite", with: "flip")) == false)
        let equals = FirstHourCurriculum.lesson(id: "equals")!
        #expect(LessonWinChecker.passes(lesson: equals, output: "match\n", source: equals.solution.replacingOccurrences(of: "==", with: ">")) == false)
        let remainder = FirstHourCurriculum.lesson(id: "remainder")!
        #expect(LessonWinChecker.passes(lesson: remainder, output: "even\n", source: remainder.solution.replacingOccurrences(of: "%", with: "/")) == false)
        let and = FirstHourCurriculum.lesson(id: "and")!
        #expect(LessonWinChecker.passes(lesson: and, output: "in\n", source: and.solution.replacingOccurrences(of: "&&", with: "||")) == false)
    }

    @MainActor
    @Test func challengeStarterTellsTheUserToFillInTheBlank() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-tests-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)
        let lesson = FirstHourCurriculum.lesson(id: "factorial")!
        workspace.openLesson(lesson)
        #expect(workspace.currentFile.code.contains("???"))
        workspace.startLiveRun()
        #expect(workspace.isRunning == false)
        #expect(workspace.lastRunFailed == false)
        #expect(workspace.lastRunNeedsFillIn)
        #expect(workspace.output.contains("Complete this challenge."))
        #expect(workspace.output.contains("Replace ??? with C code"))
        #expect(workspace.output.contains("The program must print 120."))
        #expect(workspace.output.contains("SYNTAX ERROR") == false)
        #expect(workspace.lastErrorJump != nil)
        #expect(workspace.showLessonNice == false)
    }

    @MainActor
    @Test func firstHourStarterTellsTheUserToFillInTheBlank() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-tests-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)
        let lesson = FirstHourCurriculum.first
        workspace.openLesson(lesson)
        #expect(workspace.currentFile.code.contains("???"))
        workspace.startLiveRun()
        #expect(workspace.lastRunFailed == false)
        #expect(workspace.lastRunNeedsFillIn)
        #expect(workspace.output.contains("Complete this lesson."))
        #expect(workspace.output.contains("Replace ??? with C code"))
        #expect(workspace.output.contains("The program must print hello from lilC."))
        #expect(workspace.output.contains("SYNTAX ERROR") == false)
    }

    @MainActor
    @Test func replayingCompletedLastChallengeDoesNotCelebrateAllDone() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-tests-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)
        for lesson in FirstHourCurriculum.all {
            workspace.lessonProgress.markComplete(lesson.id)
        }
        let last = FirstHourCurriculum.lesson(id: "move-zeroes")!
        workspace.openLesson(last)
        workspace.updateCurrentCode(last.solution)
        workspace.evaluateLessonRun(output: "1 3 12 0 0\n", failed: false, runID: UUID())
        #expect(workspace.showLessonNice)
        #expect(workspace.lessonCelebrate == nil)
        #expect(workspace.output.contains("Nice."))
        #expect(workspace.output.contains("That was the last challenge.") == false)
    }

    @MainActor
    @Test func finishingLastChallengeFirstTimeSetsAllDoneCelebrate() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-tests-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)
        let last = FirstHourCurriculum.lesson(id: "move-zeroes")!
        for lesson in FirstHourCurriculum.all where lesson.id != last.id {
            workspace.lessonProgress.markComplete(lesson.id)
        }
        workspace.openLesson(last)
        workspace.updateCurrentCode(last.solution)
        workspace.evaluateLessonRun(output: "1 3 12 0 0\n", failed: false, runID: UUID())
        #expect(workspace.lessonCelebrate == .allDone)
        #expect(workspace.output.contains("Nice. That was the last challenge."))
    }

    @MainActor
    @Test func replayingACompletedLessonDoesNotAutoAdvance() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-tests-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)
        let hello = FirstHourCurriculum.first
        workspace.openLesson(hello)
        workspace.updateCurrentCode(hello.solution)
        workspace.evaluateLessonRun(output: "hello from lilC\n", failed: false, runID: UUID())
        guard case .next(let next) = workspace.lessonCelebrate else {
            Issue.record("expected first-time advance")
            return
        }
        #expect(next.id == "variables")
        workspace.openLesson(hello)
        workspace.updateCurrentCode(hello.solution)
        workspace.evaluateLessonRun(output: "hello from lilC\n", failed: false, runID: UUID())
        #expect(workspace.showLessonNice)
        #expect(workspace.lessonCelebrate == nil)
        #expect(workspace.currentFile.relativePath == hello.relativePath)
    }

    @MainActor
    @Test func lastFirstHourAdvancesToFirstChallenge() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-tests-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)
        let lastHour = FirstHourCurriculum.firstHour.last!
        for lesson in FirstHourCurriculum.firstHour where lesson.id != lastHour.id {
            workspace.lessonProgress.markComplete(lesson.id)
        }
        workspace.openLesson(lastHour)
        workspace.updateCurrentCode(lastHour.solution)
        workspace.evaluateLessonRun(output: "4 9 1\n", failed: false, runID: UUID())
        guard case .next(let next) = workspace.lessonCelebrate else {
            Issue.record("expected advance into challenges")
            return
        }
        #expect(next.id == "two-sum")
        #expect(next.track == .challenge)
    }

    @MainActor
    @Test func passingALessonAdvancesToTheNextIncomplete() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-tests-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)
        let hello = FirstHourCurriculum.first
        workspace.openLesson(hello)
        workspace.updateCurrentCode(hello.solution)
        workspace.evaluateLessonRun(output: "hello from lilC\n", failed: false, runID: UUID())
        #expect(workspace.lessonProgress.isComplete("hello"))
        #expect(workspace.showLessonNice)
        guard case .next(let next) = workspace.lessonCelebrate else {
            Issue.record("expected slow advance to the next lesson")
            return
        }
        #expect(next.id == "variables")
    }

    @MainActor
    @Test func openLessonCopiesStarterOnceAndDoesNotOverwriteEdits() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-tests-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)
        let lesson = FirstHourCurriculum.first
        workspace.openLesson(lesson)
        #expect(workspace.currentFile.relativePath == lesson.relativePath)
        #expect(workspace.currentFile.code == lesson.source)
        workspace.updateCurrentCode("int main(void) { return 0; }\n")
        workspace.openLesson(lesson)
        #expect(workspace.currentFile.code.contains("return 0;"))
        #expect(workspace.currentFile.code != lesson.source)
    }

    @MainActor
    @Test func catalogEditorShowsOnlyTheOpenLessonAndCreatesAtRoot() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-catalog-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)
        let hello = FirstHourCurriculum.first
        let loop = FirstHourCurriculum.lesson(id: "loop")!
        workspace.openLesson(hello)
        workspace.openLesson(loop)
        #expect(workspace.currentFile.relativePath == loop.relativePath)
        #expect(workspace.currentFile.name == loop.fileName)
        #expect(workspace.projectFiles.map(\.relativePath) == [loop.relativePath])

        workspace.browsePath = "lessons"
        let catalogNames = workspace.browserEntries.compactMap { entry -> String? in
            if case .file(let file) = entry { return file.name }
            return nil
        }
        #expect(catalogNames.contains(hello.fileName))
        #expect(catalogNames.contains(loop.fileName))

        workspace.browsePath = workspace.currentProjectPath
        workspace.createFile()
        #expect(workspace.currentFile.folderPath.isEmpty)
        #expect(workspace.files.contains { $0.folderPath == "lessons" && $0.name.hasPrefix("program") } == false)

        let twoSum = FirstHourCurriculum.lesson(id: "two-sum")!
        workspace.openLesson(twoSum)
        #expect(workspace.currentFile.name == twoSum.fileName)
        workspace.browsePath = workspace.currentProjectPath
        workspace.createFile()
        #expect(workspace.currentFile.folderPath.isEmpty)
        #expect(workspace.files.contains { $0.folderPath == "challenges" && $0.name.hasPrefix("program") } == false)
    }

    @MainActor
    @Test func openProjectDoesNotInventMainInsideCurriculumCatalogs() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-openproj-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)
        let hello = FirstHourCurriculum.first
        workspace.openLesson(hello)
        let lessons = workspace.folders.first { $0.relativePath == "lessons" }!
        workspace.openProject(lessons)
        #expect(workspace.files.contains { $0.relativePath == "lessons/main.c" } == false)

        workspace.deleteFolder(lessons)
        workspace.createFolder(named: "lessons")
        let emptyLessons = workspace.folders.first { $0.relativePath == "lessons" }!
        workspace.openProject(emptyLessons)
        #expect(workspace.files.contains { $0.relativePath == "lessons/main.c" } == false)

        workspace.browsePath = ""
        workspace.createFolder(named: "challenges")
        let emptyChallenges = workspace.folders.first { $0.relativePath == "challenges" }!
        workspace.openProject(emptyChallenges)
        #expect(workspace.files.contains { $0.relativePath == "challenges/main.c" } == false)
    }

    @MainActor
    @Test func newCFileAtRootIncludesMainEvenWhenAnotherRootFileHasMain() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-root-main-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)
        #expect(workspace.currentFile.code.contains("int main(void)"))

        workspace.browsePath = ""
        workspace.createFile()
        #expect(workspace.currentFile.folderPath.isEmpty)
        #expect(workspace.currentFile.code == LocalCWorkspace.starterCode)
        #expect(workspace.currentFile.code.contains("int main(void)"))
    }

    @MainActor
    @Test func firstCFileInNewFolderIncludesMainAndSecondIsHelper() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-helper-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)

        workspace.createFolder(named: "demo")
        workspace.browsePath = "demo"
        workspace.createFile()
        #expect(workspace.currentFile.relativePath == "demo/program.c")
        #expect(workspace.currentFile.code == LocalCWorkspace.starterCode)
        #expect(workspace.currentFile.code.contains("int main(void)"))

        workspace.createFile()
        #expect(workspace.currentFile.relativePath == "demo/program-2.c")
        #expect(workspace.currentFile.code == LocalCWorkspace.helperStarter(for: "program-2.c"))
        #expect(workspace.currentFile.code.contains("int main(void)") == false)
        #expect(workspace.currentFile.code.contains("int program_2(void)"))
        #expect(workspace.currentFile.code.contains("/* helper — add functions here */"))
    }

    @MainActor
    @Test func headerStarterHasGuardsAndNoMain() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-header-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)
        workspace.createFolder(named: "demo")
        workspace.browsePath = "demo"
        workspace.createHeader()
        #expect(workspace.currentFile.name.hasSuffix(".h"))
        #expect(workspace.currentFile.code.contains("#ifndef MODULE_H"))
        #expect(workspace.currentFile.code.contains("#define MODULE_H"))
        #expect(workspace.currentFile.code.contains("#endif"))
        #expect(workspace.currentFile.code.contains("int main(void)") == false)

        workspace.createFile()
        #expect(workspace.currentFile.name.hasSuffix(".c"))
        #expect(workspace.currentFile.code == LocalCWorkspace.starterCode)
    }

    @MainActor
    @Test func secondCFileLinksWithExistingMain() async throws {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-link-helper-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)

        workspace.createFolder(named: "demo")
        let folder = workspace.folders.first { $0.relativePath == "demo" }!
        workspace.openProject(folder)
        #expect(workspace.currentFile.relativePath == "demo/main.c")
        #expect(workspace.currentFile.code.contains("int main(void)"))

        workspace.browsePath = "demo"
        workspace.createFile()
        #expect(workspace.currentFile.relativePath == "demo/program.c")
        #expect(workspace.currentFile.code.contains("int main(void)") == false)
        #expect(workspace.extraSourcesToLink(with: workspace.fileToCompile()).map(\.name) == ["program.c"])

        workspace.startLiveRun()
        try await Task.sleep(for: .milliseconds(800))
        #expect(workspace.isRunning == false)
        #expect(workspace.output.contains("hello from lilC"))
        #expect(!workspace.output.lowercased().contains("already defined"))
        #expect(!workspace.output.contains("more than one main()"))
    }

    @Test func localCFileNamesNormalizeToCFiles() {
        #expect(LocalCFile.normalizedName("hello") == "hello.c")
        #expect(LocalCFile.normalizedName("hello.c") == "hello.c")
        #expect(LocalCFile.normalizedName("  ") == "hello.c")
    }

    @MainActor
    @Test func agentPathsRejectTraversal() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-tests-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)
        #expect(workspace.agentSafeRelativePath("../secret.c") == nil)
        #expect(workspace.agentSafeRelativePath("/etc/passwd") == nil)
        #expect(workspace.agentSafeRelativePath("folder/main.c") == "folder/main.c")
        #expect(workspace.agentSafeRelativePath("./main.c") == "main.c")
    }

    @Test func agentEndpointsRequireHTTPS() throws {
        do {
            _ = try AgentEndpointPolicy.validatedGateway("http://example.com/v1", allowedHosts: ["api.lilc.app"])
            Issue.record("http should be rejected")
        } catch let error as AgentTransportError {
            #expect(error == .invalidEndpoint)
        }
        #if DEBUG
        let local = try AgentEndpointPolicy.validatedGateway("https://localhost/v1", allowedHosts: ["api.lilc.app"])
        #expect(local.host == "localhost")
        #else
        do {
            _ = try AgentEndpointPolicy.validatedGateway("https://localhost/v1", allowedHosts: ["api.lilc.app"])
            Issue.record("localhost should be rejected")
        } catch let error as AgentTransportError {
            #expect(error == .invalidEndpoint)
        }
        #endif
        let url = try AgentEndpointPolicy.validatedGateway("https://api.lilc.app/v1", allowedHosts: ["api.lilc.app"])
        #expect(url.host == "api.lilc.app")
        let worker = try AgentEndpointPolicy.validatedGateway(
            "https://lilc-agent.example.workers.dev/v1",
            allowedHosts: ["api.lilc.app"]
        )
        #expect(worker.host?.hasSuffix(".workers.dev") == true)
    }

    @Test func friendlyDiagnosticsCoverEveryPicoCAndRunnerErrorClass() {
        let catalog = picoCAndRunnerErrorCatalog
        let unrecognized = catalog.filter { CDiagnosticFormatter.diagnostic(from: $0) == nil }
        #expect(
            unrecognized.isEmpty,
            "Formatter missed \(unrecognized.count)/\(catalog.count) error classes: \(unrecognized)"
        )
        let coverage = Double(catalog.count - unrecognized.count) / Double(catalog.count)
        #expect(coverage >= 1.0)
    }

    @Test func friendlyDiagnosticPreservesLocationSourceAndRawDetail() {
        let raw = """
        printf("hello")
                       ^
        hello.c:3:15 ';' expected
        """
        let diagnostic = CDiagnosticFormatter.diagnostic(from: raw)
        #expect(diagnostic?.kind == .syntax)
        #expect(diagnostic?.line == 3)
        #expect(diagnostic?.column == 15)
        #expect(diagnostic?.sourceLine == "printf(\"hello\")")
        #expect(diagnostic?.displayText.contains("PicoC detail:") == true)
        #expect(diagnostic?.displayText.contains("';' expected") == true)
    }

    @Test func editorSearchFindsCaseInsensitiveMatchesInFile() {
        let text = "int main(void) {\n    printf(\"Hello\");\n    printf(\"hello\");\n}\n"
        let matches = EditorSearch.nsMatches(in: text, query: "HELLO")
        #expect(matches.count == 2)
        #expect(EditorSearch.nsMatches(in: text, query: "   ").isEmpty)
        #expect(EditorSearch.nsMatches(in: text, query: "").isEmpty)
        #expect(EditorSearch.nsMatches(in: text, query: "nope").isEmpty)
    }

    @Test func indentFormatterIndentsNestedBracesElseForAndSwitch() {
        let messy = """
        #include <stdio.h>
        int main(void) {
        if (x) {
        foo();
        } else {
        for (i = 0; i < 3; i++) {
        x++;
        }
        }
        switch (n) {
        case 1:
        bar();
        break;
        default:
        baz();
        }
        done:
        return 0;
        }
        """
        let expected = """
        #include <stdio.h>
        int main(void) {
            if (x) {
                foo();
            } else {
                for (i = 0; i < 3; i++) {
                    x++;
                }
            }
            switch (n) {
            case 1:
                bar();
                break;
            default:
                baz();
            }
        done:
            return 0;
        }
        """
        #expect(CIndentFormatter.format(messy) == expected)
    }

    @Test func indentFormatterPreservesBracesInsideStringsAndComments() {
        let source = """
        int main(void) {
        char *s = "hello { world }";
        /* { not a block */
        // { also not
        return 0;
        }
        """
        let formatted = CIndentFormatter.format(source)
        #expect(formatted.contains("    char *s = \"hello { world }\";"))
        #expect(formatted.contains("    /* { not a block */"))
        #expect(formatted.contains("    // { also not"))
        #expect(formatted.contains("    return 0;"))
    }

    @Test func indentFormatterLeavesAlreadyIndentedCodeStableAndEmptyFileAlone() {
        let pretty = """
        int main(void) {
            return 0;
        }
        """
        #expect(CIndentFormatter.format(pretty) == pretty)
        #expect(CIndentFormatter.format("") == "")
        #expect(CIndentFormatter.format("\n") == "\n")
    }

    @Test func indentFormatterPreservesWindowsNewlines() {
        let source = "int main(void) {\r\nreturn 0;\r\n}\r\n"
        let formatted = CIndentFormatter.format(source)
        #expect(formatted == "int main(void) {\r\n    return 0;\r\n}\r\n")
        #expect(formatted.contains("\r\n"))
        #expect(!formatted.contains("\n") || formatted.contains("\r\n"))
    }

    @Test func indentFormatterIsIdempotent() {
        let samples = [
            "",
            "int x;\n",
            "int main(void) {\nreturn 0;\n}\n",
            "if (a)\nfoo();\nelse\nbar();\n",
            "do\nfoo();\nwhile (0);\n",
            "#include <stdio.h>\nint main(void) { return 0; }\n",
            "char *s = \"{\";\n{\nint x;\n}\n",
            "int main(void) {\r\nfoo();\r\n}\r\n",
            "switch (n) {\ncase 1:\nbreak;\ndefault:\nbreak;\n}\n",
            "#define FOO \\\n1\n",
        ]
        for sample in samples {
            let once = CIndentFormatter.format(sample)
            let twice = CIndentFormatter.format(once)
            #expect(once == twice, "not idempotent for:\n\(sample)\nfirst:\n\(once)\nsecond:\n\(twice)")
        }
    }

    @Test func indentFormatterRestoresCaretOntoTheSameContent() {
        let source = "int main(void) {\nreturn 0;\n}\n"
        let caret = (source as NSString).range(of: "return").location
        let result = CIndentFormatter.formatKeepingCaret(source, caretUTF16: caret)
        let around = (result.text as NSString).substring(
            with: NSRange(location: result.caretUTF16, length: min(6, (result.text as NSString).length - result.caretUTF16))
        )
        #expect(around.hasPrefix("return"))
    }

    @Test func indentFormatterHangsSingleLineIfForWhileAndDo() {
        let source = """
        int main(void) {
        if (x)
        foo();
        else
        bar();
        for (i = 0; i < 1; i++)
        x++;
        while (x)
        x--;
        do
        x++;
        while (0);
        }
        """
        let formatted = CIndentFormatter.format(source)
        #expect(formatted.contains("    if (x)\n        foo();"))
        #expect(formatted.contains("    else\n        bar();"))
        #expect(formatted.contains("    for (i = 0; i < 3; i++)") == false)
        #expect(formatted.contains("    for (i = 0; i < 1; i++)\n        x++;"))
        #expect(formatted.contains("    while (x)\n        x--;"))
        #expect(formatted.contains("    do\n        x++;"))
    }

    @Test func keyboardPolicyNeverResignsToChaseStaleFocusState() {
        #expect(
            CCodeEditorKeyboardPolicy.shouldResignFirstResponder(
                swiftUIWantsFocus: false,
                textViewIsFirstResponder: true
            ) == false
        )
        #expect(
            CCodeEditorKeyboardPolicy.shouldApplyBoundText(
                fileChanged: false,
                isFirstResponder: true,
                viewText: "int x;",
                boundText: "int y;"
            ) == false
        )
        #expect(
            CCodeEditorKeyboardPolicy.shouldApplyBoundText(
                fileChanged: false,
                isFirstResponder: false,
                viewText: "int x;",
                boundText: "int y;"
            ) == true
        )
        #expect(
            CCodeEditorKeyboardPolicy.shouldBecomeFirstResponder(
                swiftUIWantsFocus: true,
                textViewIsFirstResponder: false
            ) == true
        )
        #expect(
            CCodeEditorKeyboardPolicy.shouldBecomeFirstResponder(
                swiftUIWantsFocus: true,
                textViewIsFirstResponder: true
            ) == false
        )
    }

    @Test func runConsoleUsesSystemKeyboardSafeAreaAndHidesEditor() {
        #expect(RunConsoleChrome.hidesEditorChrome(isRunning: true))
        #expect(RunConsoleChrome.hidesEditorChrome(isRunning: false) == false)
        #expect(RunConsoleChrome.ignoresSystemKeyboardSafeArea(isRunning: true))
        #expect(RunConsoleChrome.ignoresSystemKeyboardSafeArea(isRunning: false))
        #expect(RunConsoleChrome.keyboardOverlapPadding(isRunning: false, overlap: 336) == 0)
        #expect(RunConsoleChrome.keyboardOverlapPadding(isRunning: true, overlap: 336) == 336)
        #expect(RunConsoleChrome.keyboardOverlapPadding(isRunning: true, overlap: 0) == 0)
        #expect(RunConsoleChrome.ignoresContainerBottom(padding: 336))
        #expect(RunConsoleChrome.ignoresContainerBottom(padding: 0) == false)
    }

    @Test func softwareKeyboardOverlapUsesOnScreenIntersection() {
        let window = CGRect(x: 0, y: 0, width: 390, height: 844)
        #expect(
            SoftwareKeyboardOverlap.amount(
                endFrameInScreen: CGRect(x: 0, y: 508, width: 390, height: 336),
                windowFrameInScreen: window
            ) == 336
        )
        #expect(
            SoftwareKeyboardOverlap.amount(
                endFrameInScreen: CGRect(x: 0, y: 844, width: 390, height: 336),
                windowFrameInScreen: window
            ) == 0
        )
        #expect(
            SoftwareKeyboardOverlap.amount(
                endFrameInScreen: CGRect(x: 0, y: 800, width: 390, height: 0),
                windowFrameInScreen: window
            ) == 0
        )
    }

    @Test func consoleTranscriptKeepsEchoedStdinWhenRunFinishes() {
        let live = "Number 1: 5\nNumber 2: 9\nNumber 3: 2\nNumber 4: 1\nNumber 5: 4\nLargest number: 9\n"
        let captured = "Number 1: Number 2: Number 3: Number 4: Number 5: Largest number: 9\n"
        #expect(ConsoleTranscript.finishing(live: live, captured: captured, failed: false) == live)
    }

    @Test func consoleTranscriptAppendsLateStdoutAfterEchoes() {
        let live = "Number 1: 5\nNumber 2: 9\n"
        let captured = "Number 1: Number 2: Largest number: 9\n"
        #expect(
            ConsoleTranscript.finishing(live: live, captured: captured, failed: false)
                == "Number 1: 5\nNumber 2: 9\nLargest number: 9\n"
        )
    }

    @Test func consoleTranscriptUsesDiagnosticWhenFailed() {
        #expect(
            ConsoleTranscript.finishing(live: "Number 1: 5\n", captured: "SYNTAX ERROR\n", failed: true)
                == "SYNTAX ERROR\n"
        )
        #expect(ConsoleTranscript.finishing(live: "", captured: "hello\n", failed: false) == "hello\n")
        #expect(ConsoleTranscript.finishing(live: "hello\n", captured: "hello\n", failed: false) == "hello\n")
    }

    @Test func runningConsoleOutputHugsContentInsteadOfStretching() {
        let short = "Enter two integers:\n"
        let twoLines = RunningConsoleLayout.lineHeight * 2
        #expect(RunningConsoleLayout.lineCount(in: short) == 1)
        #expect(
            RunningConsoleLayout.compactOutputHeight(output: short, availableHeight: 800) == twoLines
        )
        #expect(
            RunningConsoleLayout.compactOutputHeight(output: "", availableHeight: 800) == twoLines
        )
        let many = (1...20).map { "line \($0)" }.joined(separator: "\n")
        let sixLines = RunningConsoleLayout.lineHeight * 6
        #expect(
            RunningConsoleLayout.compactOutputHeight(output: many, availableHeight: 800) == sixLines
        )
        #expect(
            RunningConsoleLayout.compactOutputHeight(output: many, availableHeight: 100) == twoLines
        )
        #expect(RunningConsoleLayout.consoleLayoutPriority(isRunning: true, outputExpanded: true) == 1)
        #expect(RunningConsoleLayout.consoleLayoutPriority(isRunning: false, outputExpanded: true) == 0)
    }

    @Test func outputChromeSwipeExpandsOnlyWhileRunning() {
        #expect(OutputChromeExpandPolicy.expanded(isRunning: true) == true)
        #expect(OutputChromeExpandPolicy.expanded(isRunning: false) == false)
        #expect(
            OutputChromeExpandPolicy.expanded(
                afterTranslation: -48,
                isRunning: true,
                currentlyExpanded: false
            ) == true
        )
        #expect(
            OutputChromeExpandPolicy.expanded(
                afterTranslation: 80,
                isRunning: true,
                currentlyExpanded: true
            ) == true
        )
        #expect(
            OutputChromeExpandPolicy.expanded(
                afterTranslation: -80,
                isRunning: false,
                currentlyExpanded: false
            ) == false
        )
        #expect(
            OutputChromeExpandPolicy.expanded(
                afterTranslation: -80,
                isRunning: false,
                currentlyExpanded: true
            ) == false
        )
    }

    @MainActor
    @Test func accessoryBarHasOneDismissAndFormatBesideIt() {
        let accessory = CSymbolAccessoryView()
        let labels = accessory.controlAccessibilityLabels
        #expect(labels.last == "Hide keyboard")
        #expect(labels.dropLast().last == "Format code")
        #expect(labels.filter { $0 == "Hide keyboard" }.count == 1)
        #expect(labels.contains("{"))
        #expect(labels.contains("Indent"))
        #expect(labels.contains("Format code"))
    }

    @MainActor
    @Test func formatBufferIndentsTextViewWithoutReplacingIt() {
        var text = "int main(void) {\nreturn 0;\n}\n"
        let editor = CCodeEditor(
            text: Binding(get: { text }, set: { text = $0 }),
            fileID: "main.c",
            isFocused: true,
            jump: nil,
            findVisible: false,
            findQuery: "",
            findIndex: 0,
            findEpoch: 0,
            overlayHeight: 0,
            syntaxColoring: false,
            onBeginEditing: {},
            onEndEditing: {}
        )
        let coordinator = CCodeEditor.Coordinator(parent: editor)
        let textView = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        textView.text = text
        coordinator.textView = textView
        let identity = ObjectIdentifier(textView)
        coordinator.formatBuffer()
        #expect(textView.text == "int main(void) {\n    return 0;\n}\n")
        #expect(text == textView.text)
        #expect(ObjectIdentifier(textView) == identity)
    }

    @MainActor
    @Test func editorHostingKeepsSameTextViewAcrossTypedCharacters() {
        final class Box {
            var text = "int x;"
        }
        let box = Box()
        let host = UIHostingController(
            rootView: EditorKeyboardHarness(
                text: Binding(get: { box.text }, set: { box.text = $0 })
            )
        )
        host.view.bounds = CGRect(x: 0, y: 0, width: 390, height: 800)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()

        let textView = firstTextView(in: host.view)
        #expect(textView != nil)
        guard let textView else { return }
        let identity = ObjectIdentifier(textView)
        let becameFirstResponder = textView.becomeFirstResponder()
        textView.insertText("a")
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))

        let after = firstTextView(in: host.view)
        #expect(after.map(ObjectIdentifier.init) == identity)
        #expect((textView.text ?? "").contains("a"))
        if becameFirstResponder {
            #expect(
                textView.isFirstResponder,
                "Typing must not resign first responder; updateUIView used to resign when FocusState lagged"
            )
        }
        #expect(
            CCodeEditorKeyboardPolicy.shouldResignFirstResponder(
                swiftUIWantsFocus: false,
                textViewIsFirstResponder: true
            ) == false
        )
    }

    @Test func diagnosticJumpMapsConcatenatedHelperLineOntoHelperFile() {
        let helper = LocalCFile(
            relativePath: "proj/util.c",
            code: "int add(int a, int b) {\n    return a + b\n}\n"
        )
        let main = LocalCFile(
            relativePath: "proj/main.c",
            code: "int main(void) { return add(1, 2); }\n"
        )
        let diagnostic = CRunDiagnostic(
            kind: .syntax,
            title: "Missing semicolon",
            explanation: "C statements normally end with a semicolon.",
            suggestion: "add ;",
            file: "main.c",
            line: 2,
            column: 16,
            sourceLine: "    return a + b",
            rawMessage: "main.c:2:16 ';' expected"
        )
        let jump = CDiagnosticJump.resolve(
            diagnostic: diagnostic,
            runFile: main,
            extras: [helper],
            projectFiles: [helper, main]
        )
        #expect(jump?.fileID == helper.id)
        #expect(jump?.line == 2)
        #expect(jump?.column == 16)
    }

    @Test func diagnosticJumpPrefersNamedHelperOrHeaderFile() {
        let header = LocalCFile(relativePath: "proj/util.h", code: "#define N 1\n")
        let helper = LocalCFile(relativePath: "proj/util.c", code: "int add(int a, int b) { return a + b; }\n")
        let main = LocalCFile(relativePath: "proj/main.c", code: "int main(void) { return 0; }\n")
        let helperJump = CDiagnosticJump.resolve(
            diagnostic: CRunDiagnostic(
                kind: .syntax,
                title: "Missing semicolon",
                explanation: "",
                suggestion: "",
                file: "util.c",
                line: 4,
                column: 1,
                sourceLine: nil,
                rawMessage: "util.c:4:1 ';' expected"
            ),
            runFile: main,
            extras: [helper],
            projectFiles: [header, helper, main]
        )
        #expect(helperJump?.fileID == helper.id)
        #expect(helperJump?.line == 4)

        let headerJump = CDiagnosticJump.resolve(
            diagnostic: CRunDiagnostic(
                kind: .project,
                title: "Header not found",
                explanation: "",
                suggestion: "",
                file: "util.h",
                line: 1,
                column: 1,
                sourceLine: nil,
                rawMessage: "util.h:1:1 cannot read include file"
            ),
            runFile: main,
            extras: [helper],
            projectFiles: [header, helper, main]
        )
        #expect(headerJump?.fileID == header.id)
        #expect(headerJump?.line == 1)
    }

    @Test func diagnosticJumpWithoutLineIsNil() {
        let main = LocalCFile(relativePath: "main.c", code: "int main(void) { return 0; }\n")
        let jump = CDiagnosticJump.resolve(
            diagnostic: CRunDiagnostic(
                kind: .project,
                title: "Nothing to run",
                explanation: "",
                suggestion: "",
                file: nil,
                line: nil,
                column: nil,
                sourceLine: nil,
                rawMessage: "Write some C code, then run it."
            ),
            runFile: main,
            extras: [],
            projectFiles: [main]
        )
        #expect(jump == nil)
    }

    @Test func actualPicoCErrorsReceiveFriendlyDiagnostics() {
        let programs = [
            "int main(void) { int n = 1 return n; }",
            "int main(void) { return missing_name; }",
            "int helper(void) { return 1; }",
            "int main(void) { int n; int n; return 0; }",
            "#include \"missing.h\"\nint main(void) { return 0; }",
            "int add(int a, int b) { return a+b; }\nint main(void) { return add(1); }",
            "int add(int a, int b) { return a+b; }\nint main(void) { return add(1, 2, 3); }",
            "int main(void) { int n = 4; return n / 0; }",
            "int main(void) { int n = 4; return n % 0; }",
            "int main(void) { int n = 1; return n << 99; }",
            "int main(void) { int n = 1; return n << -1; }",
            "int main(void) { int n = @; return 0; }",
            "int main(void) { return 0 }",
            "void greet(void) {}\nint main(void) { int n = greet(); return n; }",
            "int answer(void) { }\nint main(void) { return answer(); }",
            "int main(void) { int nums[2] = {1, 2, 3}; return 0; }",
            "struct Point { int x; int y; };\nint main(void) { struct Point p; return p.z; }",
            "int main(void) { int n = 1; return n.x; }",
            "int main(void) { do { return 0; } }",
            "#include\nint main(void) { return 0; }",
            "int main(void) { goto missing; return 0; }",
            "int main(void) { int inner(void) { return 1; } return inner(); }",
            "int main(void) { void v; return 0; }",
            "int main(void) { int n; n(1); return 0; }",
            "int main(void) { return; }",
            "void done(void) { return 1; }\nint main(void) { done(); return 0; }",
            "",
        ]

        for program in programs {
            let raw = LocalCRunner.run(program)
            #expect(
                CDiagnosticFormatter.diagnostic(from: raw) != nil,
                "Expected friendly diagnostic for program:\n\(program)\nraw PicoC output: \(raw)"
            )
        }
    }

    @Test func newPicoCChecksExplainUnterminatedString() {
        let raw = LocalCRunner.run("int main(void) { char *s = \"hello; return 0; }")
        #expect(raw.contains("unterminated string"), "unterminated string raw: \(raw)")
        #expect(CDiagnosticFormatter.diagnostic(from: raw)?.kind == .syntax)
    }

    @Test func newPicoCChecksExplainUnterminatedComment() {
        let raw = LocalCRunner.run("int main(void) { /* open comment\n    return 0;\n}")
        #expect(raw.contains("unterminated comment"), "unterminated comment raw: \(raw)")
        #expect(CDiagnosticFormatter.diagnostic(from: raw)?.kind == .syntax)
    }

    @Test func newPicoCChecksExplainArrayIndexOutOfRange() {
        let raw = LocalCRunner.run("int main(void) { int nums[2]; nums[0] = 1; nums[1] = 2; return nums[2]; }")
        #expect(raw.contains("array index out of range"), "array bounds raw: \(raw)")
        #expect(CDiagnosticFormatter.diagnostic(from: raw)?.kind == .runtime)
    }

    @Test func newPicoCChecksExplainNullPointerIndex() {
        let raw = LocalCRunner.run("int main(void) { int *p = 0; return p[1]; }")
        #expect(raw.lowercased().contains("null pointer"), "null index raw: \(raw)")
        #expect(CDiagnosticFormatter.diagnostic(from: raw)?.kind == .runtime)
    }

    @Test func newPicoCChecksExplainNullPointerDereference() {
        let raw = LocalCRunner.run("int main(void) { int *p = 0; return *p; }")
        #expect(raw.lowercased().contains("null pointer"), "null deref raw: \(raw)")
        #expect(CDiagnosticFormatter.diagnostic(from: raw)?.kind == .runtime)
    }

    @Test func unsizedArrayWithoutStorageFailsInsteadOfCrashing() {
        let smallest = LocalCRunner.run("""
        int main(void) {
            char grades[];
            grades[0] = 'A';
            return 0;
        }
        """)
        #expect(smallest.contains("array 'grades' has no allocated storage"), "smallest raw: \(smallest)")
        let diagnostic = CDiagnosticFormatter.diagnostic(from: smallest)
        #expect(diagnostic?.kind == .arrayMemory)
        #expect(diagnostic?.title.contains("grades") == true)
        #expect(diagnostic?.displayText.contains("ARRAY / MEMORY ERROR") == true)

        let scanfProgram = LocalCRunner.run(
            """
            #include <stdio.h>
            int main(void) {
                int numClasses;
                char grades[];
                printf("How many classes? ");
                scanf("%d", &numClasses);
                for (int i = 0; i < numClasses; i++) {
                    scanf(" %c", &grades[i]);
                }
                return 0;
            }
            """,
            stdin: "2\nA\nB\n"
        )
        #expect(scanfProgram.contains("array 'grades' has no allocated storage"), "scanf raw: \(scanfProgram)")
        #expect(CDiagnosticFormatter.diagnostic(from: scanfProgram)?.kind == .arrayMemory)

        let zeroSize = LocalCRunner.run("int main(void) { int nums[0]; return 0; }")
        #expect(zeroSize.contains("array size must be greater than 0"), "zero size raw: \(zeroSize)")
        #expect(CDiagnosticFormatter.diagnostic(from: zeroSize)?.kind == .arrayMemory)

        let negativeSize = LocalCRunner.run("int main(void) { int nums[-1]; return 0; }")
        #expect(negativeSize.contains("array size must be greater than 0"), "negative size raw: \(negativeSize)")
        #expect(CDiagnosticFormatter.diagnostic(from: negativeSize)?.kind == .arrayMemory)

        let flexible = LocalCRunner.run("""
        struct Bucket { int n; char grades[]; };
        int main(void) { struct Bucket b; b.grades[0] = 'A'; return 0; }
        """)
        #expect(flexible.contains("no allocated storage"), "flexible raw: \(flexible)")
        #expect(CDiagnosticFormatter.diagnostic(from: flexible)?.kind == .arrayMemory)

        let nullScanf = LocalCRunner.run(
            """
            #include <stdio.h>
            int main(void) { int *p = 0; scanf("%d", p); return 0; }
            """,
            stdin: "1\n"
        )
        #expect(nullScanf.lowercased().contains("null pointer"), "null scanf raw: \(nullScanf)")
        #expect(CDiagnosticFormatter.diagnostic(from: nullScanf)?.kind == .runtime)
    }

    @Test func validArrayDeclarationsStillRunAfterUnsizedArrayFailure() {
        let failed = LocalCRunner.run("int main(void) { char grades[]; grades[0] = 'A'; return 0; }")
        #expect(failed.contains("no allocated storage"))

        let sized = LocalCRunner.run("""
        #include <stdio.h>
        int main(void) {
            char grades[20];
            grades[0] = 'A';
            grades[1] = '\\0';
            printf("%s\\n", grades);
            return 0;
        }
        """)
        #expect(sized == "A\n", "sized array raw: \(sized)")

        let unsizedInit = LocalCRunner.run("""
        #include <stdio.h>
        int main(void) {
            char s[] = "hello";
            printf("%s\\n", s);
            return 0;
        }
        """)
        #expect(unsizedInit == "hello\n", "unsized init raw: \(unsizedInit)")

        let intInit = LocalCRunner.run("""
        #include <stdio.h>
        int main(void) {
            int nums[] = {1, 2, 3};
            printf("%d\\n", nums[2]);
            return 0;
        }
        """)
        #expect(intInit == "3\n", "int init raw: \(intInit)")

        let arrayParam = LocalCRunner.run("""
        #include <stdio.h>
        void setfirst(char buf[]) {
            buf[0] = 'Z';
            printf("%c\\n", buf[0]);
        }
        int main(void) {
            char s[4] = "abc";
            setfirst(s);
            return 0;
        }
        """)
        #expect(arrayParam == "Z\n", "array param raw: \(arrayParam)")

        let nestedInit = LocalCRunner.run("""
        #include <stdio.h>
        int main(void) {
            char rows[][4] = {"ab", "cd"};
            printf("%s%s\\n", rows[0], rows[1]);
            return 0;
        }
        """)
        #expect(nestedInit == "abcd\n", "nested init raw: \(nestedInit)")
    }

    @Test func formatterMapsHardToTriggerPicoCMessages() {
        let samples: [(String, CRunDiagnostic.Kind, String)] = [
            ("can't get the address of this", .type, "Cannot take address"),
            ("first argument to '?' should be a number", .type, "Invalid ternary condition"),
            ("integer value expected instead of double", .type, "Integer required"),
            ("no value returned from a function returning int", .type, "Missing return value"),
            ("couldn't find goto label 'done'", .name, "Unknown goto label"),
            ("nested function definitions are not allowed", .unsupported, "Nested functions"),
            ("too many parameters (16 allowed)", .type, "Too many parameters"),
            ("bad parameter", .type, "Invalid argument"),
            ("int is not a function - can't call", .type, "Not a function"),
            ("can't initialize an incomplete type", .type, "Incomplete type"),
            ("array 'grades' has no allocated storage", .arrayMemory, "grades"),
            ("array has no allocated storage", .arrayMemory, "allocated"),
            ("array size must be greater than 0", .arrayMemory, "size"),
            ("array size is too large", .arrayMemory, "size"),
            ("can't define a void variable", .type, "Void variable"),
            ("struct/union definitions can only be globals", .type, "Type must be global"),
            ("invalid type in struct", .type, "Invalid struct member"),
            ("']' expected", .syntax, "Unclosed array"),
            ("':' expected", .syntax, "Missing colon"),
            ("'while' expected", .syntax, "do-while"),
            ("#else without #if", .syntax, "preprocessor"),
            ("cannot read include file 'notes.h'", .project, "Header not found"),
            ("include file 'big.h' is too large", .project, "Header not found"),
            ("cannot include '../secret.h' outside this project folder", .project, "Header not found"),
            ("Write some C code, then run it.", .project, "Nothing to run"),
            ("lilC could not start the local C engine.", .project, "Could not start"),
            ("non-pointer argument to scanf() - argument 1 after format", .type, "scanf"),
            ("stack is empty - can't go back", .runtime, "memory"),
            ("(VariableAlloc) out of memory", .runtime, "memory"),
            ("function definition expected", .syntax, "parse"),
            ("can't use '.' on something that's not a struct or union : it's a int", .type, "struct"),
            ("assertion failed", .runtime, "Assertion"),
            ("NULL pointer passed to strlen()", .runtime, "NULL"),
            ("invalid allocation size", .runtime, "allocation"),
            ("cannot open 'notes.txt' outside this project folder", .project, "File I/O"),
        ]
        for (raw, kind, titlePart) in samples {
            let diagnostic = CDiagnosticFormatter.diagnostic(from: raw)
            #expect(diagnostic != nil, "expected diagnostic for: \(raw)")
            #expect(diagnostic?.kind == kind, "kind for \(raw): \(String(describing: diagnostic?.kind))")
            #expect(
                diagnostic?.title.localizedCaseInsensitiveContains(titlePart) == true
                    || diagnostic?.explanation.localizedCaseInsensitiveContains(titlePart) == true
                    || diagnostic?.displayText.localizedCaseInsensitiveContains(titlePart) == true,
                "title/explanation for \(raw) should mention \(titlePart), got \(diagnostic?.title ?? "nil")"
            )
        }
    }

    @Test func successfulPrintfIsNotRewrittenAsADiagnostic() {
        let output = LocalCRunner.run("""
        #include <stdio.h>
        int main(void) {
            printf("hello from lilC\\n");
            return 0;
        }
        """)
        #expect(output == "hello from lilC\n")
        let formatted = CDiagnosticFormatter.displayOutput(for: output)
        #expect(formatted.failed == false)
        #expect(formatted.text == output)
    }

    @Test func successfulOutputIsNotRewrittenWhenALaterLineLooksLikeAnError() {
        let output = LocalCRunner.run("""
        #include <stdio.h>
        int main(void) {
            printf("status: ok\\n");
            printf("';' expected\\n");
            return 0;
        }
        """)
        #expect(output.contains("status: ok"))
        #expect(output.contains("';' expected"))
        let formatted = CDiagnosticFormatter.displayOutput(for: output)
        #expect(formatted.failed == false)
        #expect(formatted.text == output)
    }

    @Test func localRunnerSupportsStddefStdintLimitsAssertAndBool() {
        let output = LocalCRunner.run("""
        #include <stdio.h>
        #include <stddef.h>
        #include <stdint.h>
        #include <limits.h>
        #include <stdbool.h>
        int main(void) {
            size_t n = sizeof(int);
            uint32_t u = 7;
            bool ok = true;
            printf("%d %u %d %d\\n", (int)n, (unsigned)u, ok, INT_MAX > 0);
            return 0;
        }
        """)
        #expect(output == "4 7 1 1\n")
    }

    @Test func localRunnerExplainsAssertFailure() {
        let raw = LocalCRunner.run("""
        #include <assert.h>
        int main(void) {
            assert(0);
            return 0;
        }
        """)
        #expect(raw.contains("assertion failed"), "assert raw: \(raw)")
        #expect(CDiagnosticFormatter.diagnostic(from: raw)?.kind == .runtime)
    }

    @Test func localRunnerExplainsNullStringArgument() {
        let raw = LocalCRunner.run("""
        #include <string.h>
        int main(void) {
            return (int)strlen(0);
        }
        """)
        #expect(raw.contains("NULL pointer passed to strlen()"), "strlen NULL raw: \(raw)")
        #expect(CDiagnosticFormatter.diagnostic(from: raw)?.kind == .runtime)
    }

    @Test func localRunnerDoesNotLeakHostEnvironment() {
        let output = LocalCRunner.run("""
        #include <stdio.h>
        #include <stdlib.h>
        int main(void) {
            char *value = getenv("HOME");
            if (value == 0) printf("none\\n");
            else printf("leaked\\n");
            return 0;
        }
        """)
        #expect(output == "none\n")
    }

    @Test func localRunnerSupportsPutsAndIfndef() {
        let output = LocalCRunner.run("""
        #include <stdio.h>
        #ifndef SKIP
        int main(void) {
            puts("ready");
            return 0;
        }
        #endif
        """)
        #expect(output == "ready\n")
    }

    @Test func localRunnerBlocksUnsafeFopen() {
        let raw = LocalCRunner.run("""
        #include <stdio.h>
        int main(void) {
            FILE *file = fopen("/etc/passwd", "r");
            if (file) fclose(file);
            return 0;
        }
        """)
        #expect(raw.contains("outside this project folder"), "fopen raw: \(raw)")
        #expect(CDiagnosticFormatter.diagnostic(from: raw)?.kind == .project)
    }

    @Test func localRunnerHandlesSimpleFunctionAndPrintfOutput() {
        let output = LocalCRunner.run("""
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
        """)

        #expect(output == "hello from lilC\n10\n")
    }

    @Test func localRunnerSupportsIntermediateCWithoutAVM() {
        let output = LocalCRunner.run("""
        #include <stdio.h>

        struct Pair {
            int left;
            int right;
        };

        int sum(int values[], int count) {
            int total = 0;
            int i;
            for (i = 0; i < count; i++) {
                total = total + values[i];
            }
            return total;
        }

        int main(void) {
            int values[4] = { 1, 2, 3, 4 };
            int *third = &values[2];
            struct Pair pair;
            pair.left = *third;
            pair.right = sum(values, 4);
            printf("pointer=%d\\n", pair.left);
            printf("sum=%d\\n", pair.right);
            return 0;
        }
        """)

        #expect(output == "pointer=3\nsum=10\n")
    }

    @Test func localRunnerBlocksShellExecution() {
        let output = LocalCRunner.run("""
        #include <stdlib.h>

        int main(void) {
            system("echo unsafe");
            return 0;
        }
        """)

        #expect(output.contains("system() is not available in lilC local mode"))
    }

    @Test func localRunnerStopsRunawayPrograms() {
        let output = LocalCRunner.run("""
        #include <stdio.h>

        int main(void) {
            int i = 0;
            while (1) {
                i++;
            }
            return 0;
        }
        """)

        #expect(output.contains("program stopped: too many steps"))
    }

    @Test func localRunnerReadsScanfFromStdin() {
        let output = LocalCRunner.run("""
        #include <stdio.h>

        int main(void) {
            int count;
            double total = 0.0;
            double grade;
            int i;

            printf("How many grades? ");
            scanf("%d", &count);
            for (i = 0; i < count; i++) {
                printf("Grade: ");
                scanf("%lf", &grade);
                total = total + grade;
            }
            printf("GPA = %.1f\\n", total / count);
            return 0;
        }
        """, stdin: "2\n4.0\n3.0\n")

        #expect(output.contains("How many grades? "))
        #expect(output.contains("GPA = 3.5"))
    }

    @Test func localRunnerReadsGetcharFromStdin() {
        let output = LocalCRunner.run("""
        #include <stdio.h>

        int main(void) {
            int ch = getchar();
            printf("got=%c\\n", ch);
            return 0;
        }
        """, stdin: "Z")

        #expect(output == "got=Z\n")
    }

    @MainActor
    @Test func localWorkspaceCreatesAndPersistsRecentFiles() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-tests-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)

        workspace.createFile()
        workspace.updateCurrentName("calculator")
        workspace.updateCurrentCode("int main(void) { printf(\"ok\\n\"); }")

        #expect(workspace.currentFile.name == "calculator.c")
        #expect(workspace.allFiles.first?.name == "calculator.c")
        #expect((try? String(contentsOf: directory.appendingPathComponent("calculator.c"), encoding: .utf8)) == "int main(void) { printf(\"ok\\n\"); }")
    }

    @MainActor
    @Test func homeNewFileCreatesStandaloneNotInProject() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-tests-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)

        workspace.createFolder(named: "gpa")
        workspace.enterFolder(workspace.folders[0])
        workspace.createFile()
        #expect(workspace.currentFile.folderPath == "gpa")

        workspace.createStandaloneFile()
        #expect(workspace.currentFile.folderPath.isEmpty)
        #expect(workspace.currentFile.name.hasSuffix(".c"))
        #expect(!workspace.currentFile.relativePath.contains("/"))
    }

    @MainActor
    @Test func deleteFolderRemovesNestedFiles() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-tests-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)

        workspace.createFolder(named: "calc")
        let folder = workspace.folders.first { $0.name == "calc" }!
        workspace.enterFolder(folder)
        workspace.createFile()
        #expect(workspace.fileCount(in: folder) >= 1)
        workspace.deleteFolder(folder)
        #expect(workspace.folders.contains(where: { $0.name == "calc" }) == false)
        #expect(workspace.files.contains(where: { $0.folderPath == "calc" }) == false)
    }

    @MainActor
    @Test func agentCanCreateFolderAndFileAndSafeguardsBlockDelete() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-tests-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)

        #expect(workspace.agentCreateFolder("gpa").contains("Created"))
        #expect(workspace.agentWriteFile("gpa/main.c", contents: "int main(void) { return 0; }\n").contains("Created"))
        #expect(workspace.agentWriteFile("gpa/test_gpa.c", contents: "int main(void) { return 0; }\n").contains("Created"))
        #expect(workspace.agentDeleteFile("gpa/main.c", safeguardsOn: true).contains("Safeguards"))
        #expect(workspace.files.contains(where: { $0.relativePath == "gpa/main.c" }))
        #expect(workspace.agentDeleteFile("gpa/main.c", safeguardsOn: false).contains("Deleted"))
        #expect(workspace.files.contains(where: { $0.relativePath == "gpa/main.c" }) == false)
    }

    @MainActor
    @Test func localWorkspaceSearchesAllFilesAndRunsSelectedFile() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-tests-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)

        workspace.renameCurrentFile(to: "hello")
        workspace.updateCurrentCode("int main(void) { printf(\"hello\\n\"); return 0; }")
        workspace.createFile()
        workspace.renameCurrentFile(to: "pointers")
        workspace.updateCurrentCode("int main(void) { int *ptr; printf(\"pointer demo\\n\"); }")

        #expect(workspace.allFiles.count == 2)
        #expect(workspace.searchFiles(matching: "pointer").map(\.name) == ["pointers.c"])

        let hello = workspace.searchFiles(matching: "hello").first!
        workspace.select(hello)
        let output = LocalCRunner.run(hello.code)
        #expect(workspace.currentFile.name == "hello.c")
        #expect(output == "hello\n")
    }

    @MainActor
    @Test func liveRunUsesOnlyTheSelectedRootFile() async throws {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-live-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)

        workspace.renameCurrentFile(to: "hello")
        workspace.updateCurrentCode("""
        #include <stdio.h>
        int main(void) { printf("hello from lilC\\n"); return 0; }
        """)
        workspace.createFile()
        workspace.renameCurrentFile(to: "other")
        workspace.updateCurrentCode("""
        #include <stdio.h>
        int main(void) { printf("other program\\n"); return 0; }
        """)

        let hello = workspace.searchFiles(matching: "hello").first!
        workspace.select(hello)
        workspace.startLiveRun()
        try await Task.sleep(for: .milliseconds(800))
        #expect(workspace.isRunning == false)
        #expect(workspace.output.contains("hello from lilC"))
        #expect(!workspace.output.contains("other program"))
        #expect(!workspace.output.lowercased().contains("already defined"))
    }

    @MainActor
    @Test func liveRunExplainsMultipleMainsAfterMovingFileIntoProject() {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-move-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)

        workspace.renameCurrentFile(to: "moved")
        workspace.updateCurrentCode("""
        #include <stdio.h>
        int main(void) {
            printf("moved program works\\n");
            return 0;
        }
        """)
        let moved = workspace.currentFile

        workspace.createFolder(named: "demo")
        workspace.browsePath = "demo"
        workspace.createFile() // Existing project starter also has main().
        #expect(workspace.moveFile(moved, into: "demo"))
        #expect(workspace.currentFile.relativePath == "demo/program.c")

        let movedInProject = workspace.files.first { $0.relativePath == "demo/moved.c" }!
        workspace.select(movedInProject)
        workspace.startLiveRun()

        #expect(!workspace.isRunning)
        #expect(workspace.output.contains("more than one main()"))
        #expect(workspace.output.contains("moved.c"))
        #expect(workspace.output.contains("program.c"))
    }

    @MainActor
    @Test func liveRunShowsBlockedSystemCall() async throws {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-sys-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)
        workspace.updateCurrentCode("""
        #include <stdlib.h>
        int main(void) { system("echo no"); return 0; }
        """)
        workspace.startLiveRun()
        try await Task.sleep(for: .milliseconds(400))
        #expect(workspace.output.contains("system() is not available"))
    }

    @MainActor
    @Test func liveRunStreamsOutputBeforeAndAfterInput() async throws {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-stdin-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)
        workspace.updateCurrentCode("""
        #include <stdio.h>
        int main(void) {
            int n;
            printf("before input\\n");
            scanf("%d", &n);
            printf("after input: %d\\n", n);
            return 0;
        }
        """)

        workspace.startLiveRun()
        try await Task.sleep(for: .milliseconds(400))
        #expect(workspace.isRunning)
        #expect(workspace.isWaitingForInput)
        #expect(workspace.output.contains("before input"))

        workspace.stdinLine = "7"
        workspace.submitStdinLine()
        try await Task.sleep(for: .milliseconds(600))
        #expect(!workspace.isRunning)
        #expect(workspace.output.contains("before input\n7\nafter input: 7"))
    }

    @MainActor
    @Test func liveRunLinksExtraCFilesInsideAProject() async throws {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-proj-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)

        #expect(workspace.agentCreateFolder("demo").contains("Created"))
        #expect(workspace.agentWriteFile("demo/util.c", contents: "int twice(int n) { return n * 2; }\n").contains("Created"))
        #expect(workspace.agentWriteFile("demo/main.c", contents: """
        #include <stdio.h>
        int twice(int n);
        int main(void) {
            printf("%d\\n", twice(3));
            return 0;
        }
        """).contains("Created"))

        workspace.select(workspace.files.first { $0.relativePath == "demo/main.c" }!)
        workspace.startLiveRun()
        try await Task.sleep(for: .milliseconds(800))
        #expect(workspace.isRunning == false)
        #expect(workspace.output.contains("6"))
    }

    @MainActor
    @Test func liveRunIncludesQuotedHeaderFromTheProjectFolder() async throws {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-hdr-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)

        #expect(workspace.agentCreateFolder("demo").contains("Created"))
        #expect(workspace.agentWriteFile("demo/util.h", contents: """
        #ifndef UTIL_H
        #define UTIL_H
        #define TWICE(n) ((n) * 2)
        #endif
        """).contains("Created"))
        #expect(workspace.agentWriteFile("demo/main.c", contents: """
        #include <stdio.h>
        #include "util.h"
        int main(void) {
            printf("%d\\n", TWICE(4));
            return 0;
        }
        """).contains("Created"))

        workspace.select(workspace.files.first { $0.relativePath == "demo/main.c" }!)
        workspace.startLiveRun()
        try await Task.sleep(for: .milliseconds(800))
        #expect(workspace.isRunning == false)
        #expect(workspace.output.contains("8"))
    }

    @MainActor
    @Test func liveRunCompilesOnlyTheOpenCatalogLesson() async throws {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-catrun-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)
        let hello = FirstHourCurriculum.first
        let loop = FirstHourCurriculum.lesson(id: "loop")!
        workspace.openLesson(hello)
        workspace.updateCurrentCode(hello.solution)
        workspace.openLesson(loop)
        workspace.updateCurrentCode(loop.solution)
        workspace.select(workspace.files.first { $0.relativePath == hello.relativePath }!)
        #expect(workspace.projectFiles.map(\.relativePath) == [hello.relativePath])

        workspace.startLiveRun()
        try await Task.sleep(for: .milliseconds(800))
        #expect(workspace.isRunning == false)
        #expect(workspace.lastRunFailed == false)
        #expect(!workspace.output.contains("more than one main"))
        #expect(workspace.output.contains("hello from lilC"))
        #expect(!workspace.output.contains("1\n2\n3"))
    }

    @MainActor
    @Test func liveRunDoesNotLinkAHelperDroppedInLessons() async throws {
        let suite = UserDefaults(suiteName: "lilc-tests-\(UUID().uuidString)")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lilc-cathelp-\(UUID().uuidString)", isDirectory: true)
        let workspace = LocalCWorkspace(defaults: suite, directoryURL: directory)
        let functionLesson = FirstHourCurriculum.lesson(id: "function")!
        workspace.openLesson(functionLesson)
        workspace.updateCurrentCode(functionLesson.solution)
        #expect(workspace.agentWriteFile("lessons/helper.c", contents: "int twice(int n) { return 0; }\n").contains("Created"))
        workspace.select(workspace.files.first { $0.relativePath == functionLesson.relativePath }!)
        #expect(workspace.projectFiles.map(\.relativePath) == [functionLesson.relativePath])

        workspace.startLiveRun()
        try await Task.sleep(for: .milliseconds(800))
        #expect(workspace.isRunning == false)
        #expect(workspace.output.contains("42"))
        #expect(!workspace.output.lowercased().contains("already defined"))
    }

}

private let picoCAndRunnerErrorCatalog = [
    "';' expected",
    "semicolon expected",
    "'}' expected",
    "'{' expected",
    "brackets not closed",
    "')' expected",
    "'(' expected",
    "close bracket expected",
    "']' expected",
    "':' expected",
    "'while' expected",
    "comma expected",
    "identifier expected",
    "identifier not expected here",
    "expression expected",
    "invalid expression",
    "value expected",
    "statement expected",
    "operator not expected here",
    "value not expected here",
    "type not expected here",
    "illegal character '@'",
    "expected \"'\"",
    "unterminated string",
    "unterminated comment",
    "parse error",
    "bad type declaration",
    "bad function definition",
    "function definition expected",
    "function body expected",
    "\"filename.h\" expected",
    "#else without #if",
    "#endif without #if",
    "cannot open include file 'missing.h'",
    "cannot include '../secret.h' outside this project folder",
    "cannot read include file 'notes.h'",
    "include file 'big.h' is too large",
    "main() is not defined",
    "main is not a function - can't call it",
    "main() should return an int or void",
    "bad parameters to main()",
    "'score' is already defined",
    "data type 'Number' is already defined",
    "member 'x' already defined",
    "'score' is not defined",
    "'score' is undefined",
    "structure 'Point' isn't defined",
    "enum 'Color' isn't defined",
    "type 'Widget' isn't defined",
    "'temp' is out of scope",
    "doesn't have a member called 'score'",
    "need an structure or union member after '.'",
    "couldn't find goto label 'done'",
    "too many arguments to add()",
    "not enough arguments to 'add'",
    "macro arguments missing",
    "too many parameters (16 allowed)",
    "bad parameter",
    "bad argument",
    "too many arguments to scanf() - 10 max",
    "non-pointer argument to scanf() - argument 1 after format",
    "can't assign int from double",
    "can't set int from double in argument 1 of call to add()",
    "not an lvalue",
    "can't assign from an array of size 4 to one of size 2",
    "can't get the address of this",
    "can't initialize an incomplete type",
    "array 'grades' has no allocated storage",
    "array has no allocated storage",
    "array size must be greater than 0",
    "array size is too large",
    "can't define a void variable",
    "array index must be an integer",
    "this int is not an array",
    "array index out of range",
    "too many array elements",
    "too many struct initializers",
    "value required in return",
    "value in return from a void function",
    "a void value isn't much use here",
    "no value returned from a function returning int",
    "first argument to '?' should be a number",
    "integer value expected instead of double",
    "int is not a function - can't call",
    "can't use '.' on something that's not a struct or union : it's a int",
    "invalid type in struct",
    "struct/union definitions can only be globals",
    "enum definitions can only be globals",
    "NULL pointer dereference",
    "NULL pointer passed to scanf()",
    "a. invalid use of a NULL pointer",
    "division by zero",
    "modulo by zero",
    "invalid shift count",
    "program stopped: too many steps",
    "stack underrun",
    "stack is empty - can't go back",
    "(VariableAlloc) out of memory",
    "(PicocParse) out of memory",
    "(LexGetStringConstant) out of memory",
    "(LexTokenize TokenSpace == NULL) out of memory",
    "(ExpressionParseMacroCall) out of memory",
    "(ExpressionParseFunctionCall) out of memory",
    "(TableSetIdentifier) out of memory",
    "(VariableStackFrameAdd) out of memory",
    "out of memory reading 'big.h'",
    "abort",
    "assertion failed",
    "NULL pointer passed to strlen()",
    "invalid allocation size",
    "cannot open '/etc/passwd' outside this project folder",
    "system() is not available in lilC local mode",
    "not supported",
    "nested function definitions are not allowed",
    "invalid operation",
    "Write some C code, then run it.",
    "lilC could not start the local C engine.",
    "lilC could not capture program output.",
    "lilC could not run this C program.",
    "Cannot run this project: it has more than one main() function (a.c, b.c). Keep one main() and turn the others into helper functions.",
]

private struct EditorKeyboardHarness: View {
    @Binding var text: String

    var body: some View {
        CCodeEditor(
            text: $text,
            fileID: "main.c",
            isFocused: true,
            jump: nil,
            findVisible: false,
            findQuery: "",
            findIndex: 0,
            findEpoch: 0,
            overlayHeight: 0,
            syntaxColoring: false,
            onBeginEditing: {},
            onEndEditing: {}
        )
        .frame(width: 390, height: 500)
    }
}

struct BridgingLessonCase: Sendable {
    let id: String
    let number: Int
    let fileName: String
    let good: String
    let bad: String
    let nextId: String?

    static let all: [BridgingLessonCase] = [
        BridgingLessonCase(id: "add", number: 7, fileName: "07-add.c", good: "15\n", bad: "10\n", nextId: "equals"),
        BridgingLessonCase(id: "equals", number: 8, fileName: "08-equals.c", good: "match\n", bad: "no\n", nextId: "while-loop"),
        BridgingLessonCase(id: "while-loop", number: 9, fileName: "09-while.c", good: "3\n2\n1\n", bad: "3\n", nextId: "remainder"),
        BridgingLessonCase(id: "remainder", number: 10, fileName: "10-remainder.c", good: "even\n", bad: "odd\n", nextId: "and"),
        BridgingLessonCase(id: "and", number: 11, fileName: "11-and.c", good: "in\n", bad: "out\n", nextId: "index"),
        BridgingLessonCase(id: "index", number: 12, fileName: "12-index.c", good: "9\n", bad: "4\n", nextId: "count"),
        BridgingLessonCase(id: "count", number: 13, fileName: "13-count.c", good: "2\n", bad: "4\n", nextId: "biggest"),
        BridgingLessonCase(id: "biggest", number: 14, fileName: "14-biggest.c", good: "9\n", bad: "3\n", nextId: "nested"),
        BridgingLessonCase(id: "nested", number: 15, fileName: "15-nested.c", good: "11\n12\n21\n22\n", bad: "11\n12\n", nextId: "swap"),
        BridgingLessonCase(id: "swap", number: 16, fileName: "16-swap.c", good: "2 1\n", bad: "1 2\n", nextId: "sum-fn"),
        BridgingLessonCase(id: "sum-fn", number: 17, fileName: "17-sum.c", good: "7\n", bad: "3\n", nextId: "opposite"),
        BridgingLessonCase(id: "opposite", number: 18, fileName: "18-opposite.c", good: "4\n", bad: "-4\n", nextId: "find"),
        BridgingLessonCase(id: "find", number: 19, fileName: "19-find.c", good: "1\n", bad: "0\n", nextId: "copy"),
        BridgingLessonCase(id: "copy", number: 20, fileName: "20-copy.c", good: "4 9 1\n", bad: "0 0 0\n", nextId: nil),
    ]
}

@MainActor
private func firstTextView(in view: UIView) -> UITextView? {
    if let textView = view as? UITextView {
        return textView
    }
    for child in view.subviews {
        if let found = firstTextView(in: child) {
            return found
        }
    }
    return nil
}
