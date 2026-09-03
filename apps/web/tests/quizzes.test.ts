import { afterEach, beforeEach, describe, expect, it } from "vitest";
import {
  bestQuizAttempt,
  hasTakenQuiz,
  recordQuizAttempt,
  resetQuizProgressForTests,
} from "../src/domain/quiz-progress";
import {
  QUESTIONS_PER_QUIZ,
  isQuizReady,
  parseQuizFile,
  quizById,
  quizzes,
  scoreQuiz,
  type CQuiz,
} from "../src/domain/quizzes";

const sampleQuiz: CQuiz = {
  id: "quiz-03",
  number: 3,
  title: "Quiz 3",
  goal: "Take this one first if you want.",
  questions: [
    {
      id: "q1",
      prompt: "Which is a type?",
      choices: ["int", "for"],
      correctIndex: 0,
      explanation: "int names a type.",
    },
    {
      id: "q2",
      prompt: "What does this print?",
      choices: ["0", "1"],
      correctIndex: 1,
      snippet: 'printf("%d", 1);',
    },
  ],
};

describe("quiz catalog", () => {
  it("loads ten ready quizzes that can be opened in any order", () => {
    expect(quizzes).toHaveLength(10);
    expect(quizzes.map((quiz) => quiz.number)).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    expect(quizById("c-quiz-01")?.title).toContain("Foundations");
    expect(quizById("c-quiz-10")?.title).toContain("Undefined Behavior");
    expect(QUESTIONS_PER_QUIZ).toBe(20);
    for (const quiz of quizzes) {
      expect(quiz.questions).toHaveLength(20);
      expect(isQuizReady(quiz)).toBe(true);
    }
  });

  it("sorts catalog by number even if the file is out of order", () => {
    const file = parseQuizFile({
      title: "Quizzes",
      questionsPerQuiz: 20,
      quizzes: [
        { id: "quiz-03", number: 3, title: "Quiz 3", goal: "Last", questions: [] },
        { id: "quiz-01", number: 1, title: "Quiz 1", goal: "First", questions: [] },
      ],
    });
    expect(file.quizzes.map((quiz) => quiz.id)).toEqual(["quiz-01", "quiz-03"]);
  });

  it("accepts the source quiz file shape", () => {
    const file = parseQuizFile({
      title: "lilC C Programming Quizzes",
      quizzes: [
        {
          id: "c-quiz-10",
          title: "Undefined Behavior",
          difficulty: "hard",
          topicTags: ["undefined-behavior"],
          questions: [
            {
              id: "q1",
              title: "Trap",
              prompt: "Which is undefined?",
              choices: ["int x = 0;", "int x; printf(\"%d\", x);"],
              correctAnswerIndex: 1,
              codeSnippet: "int x;",
              explanation: "Reading an uninitialized automatic int is undefined.",
            },
          ],
        },
        {
          id: "c-quiz-01",
          title: "Foundations",
          difficulty: "easy",
          topicTags: ["types"],
          questions: [
            {
              id: "q1",
              prompt: "Which is a type?",
              choices: ["int", "for"],
              correctAnswerIndex: 0,
            },
          ],
        },
      ],
    });
    expect(file.quizzes.map((quiz) => quiz.id)).toEqual(["c-quiz-01", "c-quiz-10"]);
    expect(file.quizzes[0]?.goal).toBe("Easy. Twenty questions on types.");
    expect(file.quizzes[1]?.questions[0]?.correctIndex).toBe(1);
    expect(file.quizzes[1]?.questions[0]?.snippet).toBe("int x;");
  });

  it("scores selected answers", () => {
    expect(isQuizReady(sampleQuiz)).toBe(true);
    expect(scoreQuiz(sampleQuiz, [0, 1])).toBe(2);
    expect(scoreQuiz(sampleQuiz, [0, 0])).toBe(1);
    expect(scoreQuiz(sampleQuiz, [-1, -1])).toBe(0);
  });
});

describe("quiz progress", () => {
  beforeEach(() => {
    resetQuizProgressForTests();
  });

  afterEach(() => {
    resetQuizProgressForTests();
  });

  it("records attempts for any quiz, including the last one first", () => {
    expect(hasTakenQuiz("c-quiz-10")).toBe(false);
    recordQuizAttempt({
      quizId: "c-quiz-10",
      selectedIndexes: [0, 0],
      score: 1,
      total: 2,
      finishedAt: "2026-01-01T00:00:00.000Z",
    });
    expect(hasTakenQuiz("c-quiz-10")).toBe(true);
    expect(bestQuizAttempt("c-quiz-10")?.score).toBe(1);

    recordQuizAttempt({
      quizId: "c-quiz-10",
      selectedIndexes: [0, 1],
      score: 2,
      total: 2,
      finishedAt: "2026-01-02T00:00:00.000Z",
    });
    expect(bestQuizAttempt("c-quiz-10")?.score).toBe(2);
  });
});
