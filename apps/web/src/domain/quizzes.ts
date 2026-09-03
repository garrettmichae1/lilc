import quizFile from "./quizzes.json";

export const QUESTIONS_PER_QUIZ = 20;
export const QUIZ_DECK_TITLE = "Quizzes";

export interface CQuizQuestion {
  id: string;
  title?: string;
  prompt: string;
  choices: string[];
  correctIndex: number;
  explanation?: string;
  snippet?: string;
}

export interface CQuiz {
  id: string;
  number: number;
  title: string;
  goal: string;
  questions: CQuizQuestion[];
}

export interface CQuizFile {
  title: string;
  questionsPerQuiz: number;
  quizzes: CQuiz[];
}

export function quizNumberFromId(id: string, fallback = 0): number {
  const match = id.match(/(\d+)$/);
  return match ? Number(match[1]) : fallback;
}

export function makeQuizGoal(difficulty?: string, tags: readonly string[] = []): string {
  const topics = tags.map((tag) => tag.replaceAll("-", " "));
  const topicText = topics.length > 0 ? ` on ${topics.join(", ")}` : "";
  if (!difficulty) {
    return `Twenty questions${topicText}.`;
  }
  const level = `${difficulty.charAt(0).toUpperCase()}${difficulty.slice(1)}`;
  return `${level}. Twenty questions${topicText}.`;
}

function asStringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];
}

function normalizeQuestion(value: unknown): CQuizQuestion | undefined {
  if (typeof value !== "object" || value === null) {
    return undefined;
  }
  const question = value as Record<string, unknown>;
  const id = question.id;
  const prompt = question.prompt;
  const choices = asStringArray(question.choices);
  const correctIndex =
    typeof question.correctIndex === "number"
      ? question.correctIndex
      : typeof question.correctAnswerIndex === "number"
        ? question.correctAnswerIndex
        : undefined;
  if (typeof id !== "string" || typeof prompt !== "string" || correctIndex === undefined) {
    return undefined;
  }
  const snippet =
    typeof question.snippet === "string"
      ? question.snippet
      : typeof question.codeSnippet === "string"
        ? question.codeSnippet
        : undefined;
  const title = typeof question.title === "string" ? question.title : undefined;
  const explanation = typeof question.explanation === "string" ? question.explanation : undefined;
  return {
    id,
    prompt,
    choices,
    correctIndex,
    ...(title ? { title } : {}),
    ...(explanation ? { explanation } : {}),
    ...(snippet ? { snippet } : {}),
  };
}

function normalizeQuiz(value: unknown, index: number): CQuiz | undefined {
  if (typeof value !== "object" || value === null) {
    return undefined;
  }
  const quiz = value as Record<string, unknown>;
  if (typeof quiz.id !== "string" || typeof quiz.title !== "string") {
    return undefined;
  }
  const questions = Array.isArray(quiz.questions)
    ? quiz.questions.flatMap((question) => {
        const next = normalizeQuestion(question);
        return next ? [next] : [];
      })
    : [];
  const number = typeof quiz.number === "number" ? quiz.number : quizNumberFromId(quiz.id, index + 1);
  const goal =
    typeof quiz.goal === "string" && quiz.goal.length > 0
      ? quiz.goal
      : makeQuizGoal(
          typeof quiz.difficulty === "string" ? quiz.difficulty : undefined,
          asStringArray(quiz.topicTags),
        );
  return {
    id: quiz.id,
    number,
    title: quiz.title,
    goal,
    questions,
  };
}

export function parseQuizFile(data: unknown): CQuizFile {
  if (typeof data !== "object" || data === null) {
    return { title: QUIZ_DECK_TITLE, questionsPerQuiz: QUESTIONS_PER_QUIZ, quizzes: [] };
  }
  const file = data as Record<string, unknown>;
  const quizzes = Array.isArray(file.quizzes)
    ? file.quizzes.flatMap((quiz, index) => {
        const next = normalizeQuiz(quiz, index);
        return next ? [next] : [];
      })
    : [];
  quizzes.sort((left, right) => left.number - right.number);
  return {
    title: typeof file.title === "string" ? file.title : QUIZ_DECK_TITLE,
    questionsPerQuiz: typeof file.questionsPerQuiz === "number" ? file.questionsPerQuiz : QUESTIONS_PER_QUIZ,
    quizzes,
  };
}

export const quizCatalog: CQuizFile = parseQuizFile(quizFile);
export const quizzes: CQuiz[] = quizCatalog.quizzes;

export function quizById(id: string): CQuiz | undefined {
  return quizzes.find((quiz) => quiz.id === id);
}

export function quizKicker(quiz: CQuiz, total = quizzes.length): string {
  return `Quiz ${quiz.number} of ${total}`;
}

export function isQuestionValid(question: CQuizQuestion): boolean {
  return question.choices.length >= 2 && question.correctIndex >= 0 && question.correctIndex < question.choices.length;
}

export function isQuizReady(quiz: CQuiz): boolean {
  return quiz.questions.length > 0 && quiz.questions.every(isQuestionValid);
}

export function scoreQuiz(quiz: CQuiz, selectedIndexes: readonly number[]): number {
  return quiz.questions.reduce((total, question, index) => {
    const picked = selectedIndexes[index];
    return total + (picked === question.correctIndex ? 1 : 0);
  }, 0);
}

export function choiceLetter(index: number): string {
  return "ABCDEFGHIJKLMNOPQRSTUVWXYZ"[index] ?? String(index + 1);
}
