import firstHour from "./first-hour.json";

export type LessonWin =
  | { kind: "contains"; text: string; ignoreCase: boolean }
  | { kind: "exact"; text: string }
  | { kind: "printsNumber" }
  | { kind: "lines"; lines: string[] };

export interface FirstHourLesson {
  id: string;
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

export function lessonRelativePath(lesson: FirstHourLesson): string {
  return `lessons/${lesson.fileName}`;
}

export function lessonById(id: string): FirstHourLesson | undefined {
  return firstHourCurriculum.lessons.find((lesson) => lesson.id === id);
}

export function lessonByNumber(number: number): FirstHourLesson | undefined {
  return firstHourCurriculum.lessons.find((lesson) => lesson.number === number);
}

export function lessonForPath(relativePath: string): FirstHourLesson | undefined {
  return firstHourCurriculum.lessons.find((lesson) => lessonRelativePath(lesson) === relativePath);
}

export function firstLesson(): FirstHourLesson {
  const lesson = firstHourCurriculum.lessons[0];
  if (!lesson) {
    throw new Error("First-hour curriculum is empty.");
  }
  return lesson;
}

export function nextLesson(lesson: FirstHourLesson): FirstHourLesson | undefined {
  return firstHourCurriculum.lessons.find((item) => item.number === lesson.number + 1);
}

export function continueLesson(completedIds: readonly string[]): FirstHourLesson {
  const incomplete = firstHourCurriculum.lessons.find((lesson) => !completedIds.includes(lesson.id));
  return incomplete ?? firstLesson();
}
