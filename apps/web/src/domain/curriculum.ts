import challengesTrack from "./challenges.json";
import firstHour from "./first-hour.json";

export type LessonTrackId = "firstHour" | "challenge";

export type LessonWin =
  | { kind: "contains"; text: string; ignoreCase: boolean }
  | { kind: "exact"; text: string }
  | { kind: "printsNumber" }
  | { kind: "lines"; lines: string[] }
  | { kind: "anyContains"; texts: string[]; ignoreCase: boolean }
  | { kind: "producedOutput" };

export interface FirstHourLesson {
  id: string;
  track: LessonTrackId;
  number: number;
  title: string;
  goal: string;
  fileName: string;
  printHint: string;
  requireSource: string[];
  requireAnySource: string[];
  win: LessonWin;
  source: string;
  solution: string;
}

export interface FirstHourTrack {
  id: string;
  title: string;
  summary: string;
  lessons: FirstHourLesson[];
}

export const firstHourCurriculum: FirstHourTrack = firstHour as FirstHourTrack;
export const challengesCurriculum: FirstHourTrack = challengesTrack as FirstHourTrack;

export const firstHourLessons: FirstHourLesson[] = firstHourCurriculum.lessons;
export const challengeLessons: FirstHourLesson[] = challengesCurriculum.lessons;
export const allLessons: FirstHourLesson[] = [...firstHourLessons, ...challengeLessons];

export function lessonRelativePath(lesson: FirstHourLesson): string {
  return lesson.track === "challenge" ? `challenges/${lesson.fileName}` : `lessons/${lesson.fileName}`;
}

export function lessonKicker(lesson: FirstHourLesson): string {
  if (lesson.track === "challenge") {
    return `Challenge ${lesson.number} of ${challengeLessons.length}`;
  }
  return `Lesson ${lesson.number} of ${firstHourLessons.length}`;
}

export function lessonById(id: string): FirstHourLesson | undefined {
  return allLessons.find((lesson) => lesson.id === id);
}

export function lessonByNumber(number: number): FirstHourLesson | undefined {
  return firstHourLessons.find((lesson) => lesson.number === number);
}

export function lessonForPath(relativePath: string): FirstHourLesson | undefined {
  return allLessons.find((lesson) => lessonRelativePath(lesson) === relativePath);
}

export function firstLesson(): FirstHourLesson {
  const lesson = firstHourLessons[0];
  if (!lesson) {
    throw new Error("First-hour curriculum is empty.");
  }
  return lesson;
}

export function nextLesson(lesson: FirstHourLesson): FirstHourLesson | undefined {
  const list = lesson.track === "challenge" ? challengeLessons : firstHourLessons;
  return list.find((item) => item.number === lesson.number + 1);
}

export function continueLessonInTrack(
  track: LessonTrackId,
  completedIds: readonly string[],
): FirstHourLesson | undefined {
  const list = track === "challenge" ? challengeLessons : firstHourLessons;
  return list.find((lesson) => !completedIds.includes(lesson.id));
}

export function continueLesson(completedIds: readonly string[]): FirstHourLesson {
  return (
    continueLessonInTrack("firstHour", completedIds) ??
    continueLessonInTrack("challenge", completedIds) ??
    firstLesson()
  );
}

export function nextIncomplete(afterId: string, completedIds: readonly string[]): FirstHourLesson | undefined {
  const current = lessonById(afterId);
  if (!current) {
    return continueLessonInTrack("firstHour", completedIds) ?? continueLessonInTrack("challenge", completedIds);
  }
  const sequential = nextLesson(current);
  if (sequential && !completedIds.includes(sequential.id)) {
    return sequential;
  }
  const unfinished = continueLessonInTrack(current.track, completedIds);
  if (unfinished) {
    return unfinished;
  }
  if (current.track === "firstHour") {
    return continueLessonInTrack("challenge", completedIds);
  }
  return undefined;
}

export function isCurriculumFolder(folder: string): boolean {
  return folder === "lessons" || folder === "challenges";
}
