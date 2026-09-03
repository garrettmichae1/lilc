/**
 * @vitest-environment happy-dom
 */
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { hasTakenQuiz, recordQuizAttempt, resetQuizProgressForTests } from "../src/domain/quiz-progress";
import { quizzes, type CQuiz } from "../src/domain/quizzes";
import { LocalCWorkspace } from "../src/domain/workspace";
import { renderHome } from "../src/ui/screens/home";
import { renderLearn } from "../src/ui/screens/learn";
import { QuizScreen } from "../src/ui/screens/quiz";

const sampleQuiz: CQuiz = {
  id: "c-quiz-10",
  number: 9,
  title: "Sample quiz",
  goal: "Two questions for tests.",
  questions: [
    {
      id: "q1",
      prompt: "Which is a type?",
      choices: ["int", "for"],
      correctIndex: 0,
    },
    {
      id: "q2",
      prompt: "What does this print?",
      choices: ["0", "1"],
      correctIndex: 1,
    },
  ],
};

const homeActions = {
  openEditor: () => undefined,
  createFile: () => undefined,
  openFiles: () => undefined,
  openLearn: () => undefined,
  openDelete: () => undefined,
  openSettings: () => undefined,
  openProject: () => undefined,
};

const learnActions = {
  openHome: () => undefined,
  openFiles: () => undefined,
  openEditor: () => undefined,
  openQuiz: () => undefined,
};

describe("quiz screens", () => {
  beforeEach(() => {
    document.body.replaceChildren();
    resetQuizProgressForTests();
  });

  afterEach(() => {
    document.body.replaceChildren();
    resetQuizProgressForTests();
  });

  it("keeps the learning hub off Home", async () => {
    const workspace = new LocalCWorkspace();
    await workspace.load();
    const home = renderHome(workspace, homeActions);
    document.body.append(home);
    expect(home.textContent).toContain("Projects");
    expect(home.textContent).toContain("LEARN");
    expect(home.textContent).not.toContain("Quizzes");
    expect(home.querySelectorAll("[data-lesson-id]").length).toBe(0);
    expect(home.querySelectorAll("[data-quiz-id]").length).toBe(0);
  });

  it("shows a Quizzes swipe deck with Start, then Review next to Retake after an attempt", async () => {
    const workspace = new LocalCWorkspace();
    await workspace.load();
    const learn = renderLearn(workspace, learnActions);
    document.body.append(learn);
    expect(learn.textContent).toContain("Learn");
    expect(learn.textContent).toContain("Lessons");
    expect(learn.textContent).toContain("Challenges");
    expect(learn.textContent).toContain("Quizzes");
    expect(learn.textContent).not.toContain("Past quizzes");
    expect(learn.querySelectorAll("[data-quiz-id]").length).toBe(quizzes.length);
    expect(learn.querySelector('[data-quiz-id="c-quiz-10"]')?.textContent).toContain("Start");
    expect(learn.querySelector('[data-quiz-id="c-quiz-10"]')?.textContent).not.toContain("Review");

    recordQuizAttempt({
      quizId: "c-quiz-10",
      selectedIndexes: [0, 1],
      score: 2,
      total: 2,
      finishedAt: "2026-01-02T00:00:00.000Z",
    });
    learn.replaceWith(renderLearn(workspace, learnActions));
    const taken = document.querySelector('[data-quiz-id="c-quiz-10"]');
    expect(taken?.textContent).toContain("Review");
    expect(taken?.textContent).toContain("Retake");
    expect(taken?.textContent).not.toContain("Start");
  });

  it("lets the user pick answers, submit, and review", () => {
    const screen = new QuizScreen(sampleQuiz, false, () => undefined);
    document.body.append(screen.root);
    expect(screen.root.textContent).toContain("Which is a type?");
    const next = screen.root.querySelector(".quiz-submit");
    expect(next).toBeInstanceOf(HTMLButtonElement);
    if (!(next instanceof HTMLButtonElement)) {
      return;
    }
    expect(next.disabled).toBe(true);

    const firstChoice = screen.root.querySelector(".quiz-choice");
    expect(firstChoice).toBeInstanceOf(HTMLButtonElement);
    firstChoice?.dispatchEvent(new Event("click", { bubbles: true }));
    const afterPick = screen.root.querySelector(".quiz-submit");
    expect(afterPick).toBeInstanceOf(HTMLButtonElement);
    if (!(afterPick instanceof HTMLButtonElement)) {
      return;
    }
    expect(afterPick.disabled).toBe(false);
    afterPick.click();

    expect(screen.root.textContent).toContain("What does this print?");
    const secondChoices = screen.root.querySelectorAll(".quiz-choice");
    expect(secondChoices[1]).toBeInstanceOf(HTMLButtonElement);
    secondChoices[1]?.dispatchEvent(new Event("click", { bubbles: true }));
    screen.root.querySelector<HTMLButtonElement>(".quiz-submit")?.click();

    expect(screen.root.textContent).toContain("2 / 2");
    expect(hasTakenQuiz("c-quiz-10")).toBe(true);

    screen.root.querySelector<HTMLButtonElement>(".quiz-submit")?.click();
    expect(screen.root.textContent).toContain("Which is a type?");
    expect(screen.root.querySelector(".quiz-choice.correct")).not.toBeNull();
  });

  it("opens a real catalog quiz at the first question", () => {
    const first = quizzes[0];
    expect(first).toBeDefined();
    if (!first) {
      return;
    }
    const screen = new QuizScreen(first, false, () => undefined);
    document.body.append(screen.root);
    expect(screen.root.textContent).toContain(first.questions[0]?.prompt ?? "");
    expect(screen.root.querySelectorAll(".quiz-choice").length).toBe(first.questions[0]?.choices.length);
  });
});
