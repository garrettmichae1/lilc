
export const QUIZ_PROGRESS_KEY = "lilc.quizzes.progress";

export interface QuizAttempt {
  quizId: string;
  selectedIndexes: number[];
  score: number;
  total: number;
  finishedAt: string;
}

let memoryStore = new Map<string, string>();

function storage(): { getItem(key: string): string | null; setItem(key: string, value: string): void } {
  try {
    if (typeof localStorage !== "undefined") {
      return localStorage;
    }
  } catch {
    /* private mode */
  }
  return {
    getItem: (key) => memoryStore.get(key) ?? null,
    setItem: (key, value) => {
      memoryStore.set(key, value);
    },
  };
}

export function resetQuizProgressForTests(): void {
  memoryStore = new Map();
  try {
    localStorage.removeItem(QUIZ_PROGRESS_KEY);
  } catch {
    /* node / private mode */
  }
}

export function loadQuizAttempts(): QuizAttempt[] {
  try {
    const raw = storage().getItem(QUIZ_PROGRESS_KEY);
    if (!raw) {
      return [];
    }
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) {
      return [];
    }
    return parsed.filter(isAttempt);
  } catch {
    return [];
  }
}

export function saveQuizAttempts(attempts: QuizAttempt[]): void {
  try {
    storage().setItem(QUIZ_PROGRESS_KEY, JSON.stringify(attempts));
  } catch {
    /* quota / private mode */
  }
}

export function recordQuizAttempt(attempt: QuizAttempt): QuizAttempt[] {
  const attempts = [...loadQuizAttempts(), attempt];
  saveQuizAttempts(attempts);
  return attempts;
}

export function hasTakenQuiz(quizId: string, attempts: readonly QuizAttempt[] = loadQuizAttempts()): boolean {
  return attempts.some((attempt) => attempt.quizId === quizId);
}

export function latestQuizAttempt(
  quizId: string,
  attempts: readonly QuizAttempt[] = loadQuizAttempts(),
): QuizAttempt | undefined {
  for (let index = attempts.length - 1; index >= 0; index -= 1) {
    const attempt = attempts[index];
    if (attempt?.quizId === quizId) {
      return attempt;
    }
  }
  return undefined;
}

export function bestQuizAttempt(
  quizId: string,
  attempts: readonly QuizAttempt[] = loadQuizAttempts(),
): QuizAttempt | undefined {
  const matches = attempts.filter((attempt) => attempt.quizId === quizId);
  if (matches.length === 0) {
    return undefined;
  }
  return matches.reduce((best, attempt) => {
    if (attempt.score > best.score) {
      return attempt;
    }
    if (attempt.score === best.score && attempt.finishedAt > best.finishedAt) {
      return attempt;
    }
    return best;
  });
}

function isAttempt(value: unknown): value is QuizAttempt {
  if (typeof value !== "object" || value === null) {
    return false;
  }
  const attempt = value as Partial<QuizAttempt>;
  return (
    typeof attempt.quizId === "string" &&
    Array.isArray(attempt.selectedIndexes) &&
    attempt.selectedIndexes.every((item) => typeof item === "number") &&
    typeof attempt.score === "number" &&
    typeof attempt.total === "number" &&
    typeof attempt.finishedAt === "string"
  );
}
