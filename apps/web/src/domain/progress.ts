import {
  allLessons,
  challengeLessons,
  firstHourLessons,
  lessonById,
  nextIncomplete,
} from "./curriculum";

export const PROGRESS_KEY = "lilc.firstHour.progress";

export interface FirstHourProgress {
  version: 1;
  completedIds: string[];
  currentIndex: number;
  currentChallengeIndex: number;
  stars: number;
  streak: number;
  lastCompletedDay: string;
}

const VERSION = 1 as const;

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

export function emptyProgress(): FirstHourProgress {
  return {
    version: VERSION,
    completedIds: [],
    currentIndex: 0,
    currentChallengeIndex: 0,
    stars: 0,
    streak: 0,
    lastCompletedDay: "",
  };
}

export function resetProgressForTests(): void {
  memoryStore = new Map();
  try {
    localStorage.removeItem(PROGRESS_KEY);
  } catch {
    /* node / private mode */
  }
}

export function writeRawProgressForTests(raw: string): void {
  try {
    storage().setItem(PROGRESS_KEY, raw);
  } catch {
    /* private mode */
  }
}

export function loadProgress(): FirstHourProgress {
  try {
    const raw = storage().getItem(PROGRESS_KEY);
    if (!raw) {
      return emptyProgress();
    }
    const parsed = JSON.parse(raw) as Partial<FirstHourProgress>;
    if (parsed.version !== VERSION || !Array.isArray(parsed.completedIds)) {
      return emptyProgress();
    }
    const known = new Set(allLessons.map((lesson) => lesson.id));
    const completedIds = parsed.completedIds.filter((id): id is string => typeof id === "string" && known.has(id));
    const lastHourIndex = Math.max(0, firstHourLessons.length - 1);
    const lastChallengeIndex = Math.max(0, challengeLessons.length - 1);
    const currentIndex =
      typeof parsed.currentIndex === "number"
        ? Math.min(Math.max(0, parsed.currentIndex), lastHourIndex)
        : 0;
    const currentChallengeIndex =
      typeof parsed.currentChallengeIndex === "number"
        ? Math.min(Math.max(0, parsed.currentChallengeIndex), lastChallengeIndex)
        : 0;
    return {
      version: VERSION,
      completedIds,
      currentIndex,
      currentChallengeIndex,
      stars: typeof parsed.stars === "number" ? Math.max(0, parsed.stars) : completedIds.length,
      streak: typeof parsed.streak === "number" ? Math.max(0, parsed.streak) : 0,
      lastCompletedDay: typeof parsed.lastCompletedDay === "string" ? parsed.lastCompletedDay : "",
    };
  } catch {
    return emptyProgress();
  }
}

export function saveProgress(progress: FirstHourProgress): void {
  try {
    storage().setItem(PROGRESS_KEY, JSON.stringify(progress));
  } catch {
    /* quota / private mode */
  }
}

export function setCurrentLesson(id: string): FirstHourProgress {
  const progress = loadProgress();
  const lesson = lessonById(id);
  if (!lesson) {
    return progress;
  }
  if (lesson.track === "challenge") {
    progress.currentChallengeIndex = Math.max(0, challengeLessons.findIndex((item) => item.id === id));
  } else {
    progress.currentIndex = Math.max(0, firstHourLessons.findIndex((item) => item.id === id));
  }
  saveProgress(progress);
  return progress;
}

export function markLessonComplete(id: string, now = new Date()): FirstHourProgress {
  const progress = loadProgress();
  const known = allLessons.some((lesson) => lesson.id === id);
  if (!known) {
    return progress;
  }
  if (!progress.completedIds.includes(id)) {
    progress.completedIds = [...progress.completedIds, id];
    progress.stars += 1;
    const today = dayKey(now);
    if (progress.lastCompletedDay === today) {
      if (progress.streak === 0) {
        progress.streak = 1;
      }
    } else if (progress.lastCompletedDay === dayKey(addDays(now, -1))) {
      progress.streak += 1;
    } else {
      progress.streak = 1;
    }
    progress.lastCompletedDay = today;
  }
  const next = nextIncomplete(id, progress.completedIds);
  if (next) {
    if (next.track === "challenge") {
      progress.currentChallengeIndex = Math.max(
        0,
        challengeLessons.findIndex((lesson) => lesson.id === next.id),
      );
    } else {
      progress.currentIndex = Math.max(
        0,
        firstHourLessons.findIndex((lesson) => lesson.id === next.id),
      );
    }
  }
  saveProgress(progress);
  return progress;
}

export function isLessonComplete(id: string): boolean {
  return loadProgress().completedIds.includes(id);
}

export function hourComplete(progress: FirstHourProgress = loadProgress()): boolean {
  return firstHourLessons.every((lesson) => progress.completedIds.includes(lesson.id));
}

export function challengesComplete(progress: FirstHourProgress = loadProgress()): boolean {
  return challengeLessons.every((lesson) => progress.completedIds.includes(lesson.id));
}

export function allTracksComplete(progress: FirstHourProgress = loadProgress()): boolean {
  return hourComplete(progress) && challengesComplete(progress);
}

export function showsFirstHourDeck(progress: FirstHourProgress = loadProgress()): boolean {
  return !hourComplete(progress);
}

export function showsChallengesDeck(progress: FirstHourProgress = loadProgress()): boolean {
  return !challengesComplete(progress);
}

export function dayKey(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function addDays(date: Date, amount: number): Date {
  const next = new Date(date.getTime());
  next.setDate(next.getDate() + amount);
  return next;
}
