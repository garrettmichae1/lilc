import firstHour from "./first-hour.json";

export interface FirstHourLesson {
  id: string;
  number: number;
  title: string;
  goal: string;
  fileName: string;
  source: string;
  expectedOutput: string;
}

export interface FirstHourTrack {
  id: string;
  title: string;
  summary: string;
  lessons: FirstHourLesson[];
}

export const firstHourCurriculum: FirstHourTrack = firstHour;

export function lessonRelativePath(lesson: FirstHourLesson): string {
  return `lessons/${lesson.fileName}`;
}

export function lessonById(id: string): FirstHourLesson | undefined {
  return firstHourCurriculum.lessons.find((lesson) => lesson.id === id);
}

export function lessonByNumber(number: number): FirstHourLesson | undefined {
  return firstHourCurriculum.lessons.find((lesson) => lesson.number === number);
}

export function firstLesson(): FirstHourLesson {
  const lesson = firstHourCurriculum.lessons[0];
  if (!lesson) {
    throw new Error("First-hour curriculum is empty.");
  }
  return lesson;
}
