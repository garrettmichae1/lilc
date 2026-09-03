import type { FirstHourLesson } from "./curriculum";

export function completeTheTaskMessage(lesson: FirstHourLesson): string {
  const kind = lesson.track === "challenge" ? "challenge" : "lesson";
  return `Complete this ${kind}.\n\nReplace ??? with C code, then press RUN.\n\nThe program must print ${lesson.printHint}.\n`;
}

export const replacePlaceholderMessage = "Replace ??? with C code, then press RUN.\n";

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

export function scoringText(output: string): string {
  return output
    .replace(/\r\n/g, "\n")
    .replace(/Program finished\./g, "")
    .replace(/\n\nNice\./g, "\n")
    .replace(/Nice\.\n/g, "");
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
  return matchesWin(lesson.win, output);
}

export function matchesWin(win: FirstHourLesson["win"], output: string): boolean {
  const text = scoringText(output);
  switch (win.kind) {
    case "contains": {
      const haystack = win.ignoreCase ? text.toLowerCase() : text;
      const needle = win.ignoreCase ? win.text.toLowerCase() : win.text;
      return haystack.includes(needle);
    }
    case "exact":
      return normalizeExact(text) === normalizeExact(win.text);
    case "printsNumber":
      return /\d/.test(text);
    case "lines": {
      const got = trimmedLines(text);
      const want = win.lines;
      return got.length === want.length && got.every((line, index) => line === want[index]);
    }
    case "anyContains": {
      const haystack = win.ignoreCase ? text.toLowerCase() : text;
      return win.texts.some((needle) => haystack.includes(win.ignoreCase ? needle.toLowerCase() : needle));
    }
    case "producedOutput":
      return text.trim().length > 0;
  }
}

function normalizeExact(text: string): string {
  return text.replace(/\r\n/g, "\n").replace(/^\s+|\s+$/g, "");
}

function trimmedLines(text: string): string[] {
  const trimmed = scoringText(text).replace(/^\s+|\s+$/g, "");
  if (trimmed.length === 0) {
    return [];
  }
  return trimmed.split("\n").map((line) => line.trim());
}
