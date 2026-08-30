import type { FirstHourLesson } from "./curriculum";

export function notYetMessage(lesson: FirstHourLesson): string {
  return `Not yet. The program must print ${lesson.printHint}.`;
}

export function appendNotYet(output: string, lesson: FirstHourLesson): string {
  const line = notYetMessage(lesson);
  if (output.includes(line)) {
    return output;
  }
  const prefix = output.length === 0 || output.endsWith("\n") ? output : `${output}\n`;
  return `${prefix}${line}\n`;
}

export function checkLessonWin(lesson: FirstHourLesson, output: string, source: string): boolean {
  if (source.includes("???")) {
    return false;
  }
  for (const needle of lesson.requireSource) {
    if (!source.includes(needle)) {
      return false;
    }
  }
  if (
    lesson.requireAnySource.length > 0 &&
    !lesson.requireAnySource.some((needle) => source.includes(needle))
  ) {
    return false;
  }
  const text = output.replace(/\r\n/g, "\n");
  switch (lesson.win.kind) {
    case "contains": {
      const haystack = lesson.win.ignoreCase ? text.toLowerCase() : text;
      const needle = lesson.win.ignoreCase ? lesson.win.text.toLowerCase() : lesson.win.text;
      return haystack.includes(needle);
    }
    case "exact":
      return normalizeExact(text) === normalizeExact(lesson.win.text);
    case "printsNumber":
      return /\d/.test(text);
    case "lines": {
      const got = trimmedLines(text);
      const want = lesson.win.lines;
      return got.length === want.length && got.every((line, index) => line === want[index]);
    }
  }
}

function normalizeExact(text: string): string {
  return text.replace(/\r\n/g, "\n").replace(/\n+$/g, "").trimEnd();
}

function trimmedLines(text: string): string[] {
  const trimmed = text.replace(/\s+$/u, "");
  if (trimmed.length === 0) {
    return [];
  }
  return trimmed.split("\n").map((line) => line.trim());
}
