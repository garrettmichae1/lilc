import { afterEach, beforeEach, describe, expect, it } from "vitest";
import {
  continueLesson,
  firstHourCurriculum,
  firstLesson,
  lessonById,
  lessonRelativePath,
  nextLesson,
} from "../src/domain/curriculum";
import {
  emptyProgress,
  hourComplete,
  loadProgress,
  markLessonComplete,
  resetProgressForTests,
  setCurrentLesson,
  writeRawProgressForTests,
} from "../src/domain/progress";
import { encodeShareHash, parseShareHash, playgroundURL } from "../src/domain/share";
import { runFirstHourSubset } from "../src/domain/subset";
import { appendNotYet, checkLessonWin, notYetMessage } from "../src/domain/win";

describe("first-hour curriculum", () => {
  it("loads six sequenced starter files with placeholders", () => {
    expect(firstHourCurriculum.lessons).toHaveLength(6);
    expect(firstLesson().id).toBe("hello");
    expect(lessonById("function")?.number).toBe(6);
    const ids = firstHourCurriculum.lessons.map((lesson) => lesson.id);
    expect(new Set(ids).size).toBe(6);
    for (const lesson of firstHourCurriculum.lessons) {
      expect(lessonRelativePath(lesson).startsWith("lessons/")).toBe(true);
      expect(lesson.source).toContain("int main(");
      expect(lesson.source).toContain("???");
      expect(lesson.solution).not.toContain("???");
      expect(lesson.goal.split(/[.!?]+/).filter((part) => part.trim().length > 0).length).toBeGreaterThanOrEqual(2);
      expect(lesson.printHint.length).toBeGreaterThan(0);
    }
  });

  it("runs every solution on the first-hour subset", () => {
    for (const lesson of firstHourCurriculum.lessons) {
      const result = runFirstHourSubset(lesson.solution);
      expect(result.ok, lesson.id).toBe(true);
      expect(checkLessonWin(lesson, result.output, lesson.solution), lesson.id).toBe(true);
    }
  });

  it("does not treat starters as already complete", () => {
    for (const lesson of firstHourCurriculum.lessons) {
      const result = runFirstHourSubset(lesson.source);
      if (result.ok) {
        expect(checkLessonWin(lesson, result.output, lesson.source), lesson.id).toBe(false);
      }
      expect(checkLessonWin(lesson, result.ok ? result.output : "", lesson.source), lesson.id).toBe(false);
    }
  });
});

describe("lesson win conditions", () => {
  const hello = firstLesson();
  const variables = lessonById("variables")!;
  const iff = lessonById("if")!;
  const loop = lessonById("loop")!;
  const fn = lessonById("function")!;

  it("accepts Hello, world by contains, ignoring case", () => {
    expect(checkLessonWin(hello, "Hello, world\n", hello.solution)).toBe(true);
    expect(checkLessonWin(hello, "hello, world\n", hello.solution)).toBe(true);
    expect(checkLessonWin(hello, ">> Hello, world!\n", hello.solution)).toBe(true);
    expect(checkLessonWin(hello, "???\n", hello.source)).toBe(false);
    expect(checkLessonWin(hello, "Hello, world\n", hello.source)).toBe(false);
  });

  it("requires a printed number for variables", () => {
    expect(checkLessonWin(variables, "7\n", variables.solution)).toBe(true);
    expect(checkLessonWin(variables, "0\n", variables.solution)).toBe(true);
    expect(checkLessonWin(variables, "hello\n", variables.solution)).toBe(false);
  });

  it("requires if/else output pass", () => {
    expect(checkLessonWin(iff, "pass\n", iff.solution)).toBe(true);
    expect(checkLessonWin(iff, "fail\n", iff.solution)).toBe(false);
    expect(checkLessonWin(iff, "pass\n", 'int main(void) { printf("pass\\n"); }\n')).toBe(false);
  });

  it("requires a loop that prints 1 through 5", () => {
    expect(checkLessonWin(loop, "1\n2\n3\n4\n5\n", loop.solution)).toBe(true);
    expect(checkLessonWin(loop, "1\n2\n3\n", loop.solution)).toBe(false);
    expect(
      checkLessonWin(loop, "1\n2\n3\n4\n5\n", 'int main(void) { printf("1\\n2\\n3\\n4\\n5\\n"); }\n'),
    ).toBe(false);
  });

  it("requires twice() to print 42", () => {
    expect(checkLessonWin(fn, "42\n", fn.solution)).toBe(true);
    expect(checkLessonWin(fn, "21\n", fn.solution)).toBe(false);
    expect(checkLessonWin(fn, "42\n", 'int main(void) { printf("42\\n"); }\n')).toBe(false);
  });

  it("formats the not-yet line", () => {
    expect(notYetMessage(hello)).toBe("Not yet. The program must print Hello, world.");
    expect(appendNotYet("oops\n", hello)).toBe("oops\nNot yet. The program must print Hello, world.\n");
    expect(appendNotYet(appendNotYet("oops\n", hello), hello)).toBe(
      "oops\nNot yet. The program must print Hello, world.\n",
    );
  });

  it("names the next lesson", () => {
    expect(nextLesson(hello)?.id).toBe("variables");
    expect(nextLesson(fn)).toBeUndefined();
    expect(continueLesson([]).id).toBe("hello");
    expect(continueLesson(["hello", "variables"]).id).toBe("if");
  });
});

describe("first-hour progress", () => {
  beforeEach(() => {
    resetProgressForTests();
  });

  afterEach(() => {
    resetProgressForTests();
  });

  it("starts empty and survives a round trip", () => {
    expect(loadProgress()).toEqual(emptyProgress());
    const saved = markLessonComplete("hello");
    expect(saved.completedIds).toEqual(["hello"]);
    expect(saved.stars).toBe(1);
    expect(saved.currentIndex).toBe(1);
    expect(loadProgress()).toEqual(saved);
  });

  it("does not double-count a replayed lesson", () => {
    markLessonComplete("hello");
    const again = markLessonComplete("hello");
    expect(again.completedIds).toEqual(["hello"]);
    expect(again.stars).toBe(1);
  });

  it("keeps the current lesson in localStorage", () => {
    setCurrentLesson("loop");
    expect(loadProgress().currentIndex).toBe(3);
  });

  it("tracks a streak across consecutive days", () => {
    const monday = new Date("2026-08-24T12:00:00");
    const tuesday = new Date("2026-08-25T12:00:00");
    const friday = new Date("2026-08-28T12:00:00");
    expect(markLessonComplete("hello", monday).streak).toBe(1);
    expect(markLessonComplete("variables", tuesday).streak).toBe(2);
    expect(markLessonComplete("if", friday).streak).toBe(1);
  });

  it("marks the hour complete after every lesson", () => {
    for (const lesson of firstHourCurriculum.lessons) {
      markLessonComplete(lesson.id);
    }
    const progress = loadProgress();
    expect(hourComplete(progress)).toBe(true);
    expect(progress.stars).toBe(6);
    expect(progress.currentIndex).toBe(5);
  });

  it("ignores corrupt storage", () => {
    writeRawProgressForTests("{not json");
    expect(loadProgress().completedIds).toEqual([]);
  });
});

describe("shareable playground hash", () => {
  it("round-trips a lesson link", () => {
    const hash = encodeShareHash({ kind: "lesson", id: "hello" });
    expect(hash).toBe("#l=hello");
    expect(parseShareHash(hash)).toEqual({ kind: "lesson", id: "hello" });
    expect(playgroundURL({ kind: "lesson", id: "loop" })).toBe(
      "https://garrettmichae1.github.io/lilc/web/#l=loop",
    );
  });

  it("round-trips a C program without a backend", () => {
    const payload = {
      kind: "source" as const,
      fileName: "warm.c",
      code: '#include <stdio.h>\nint main(void) { printf("hi\\n"); return 0; }\n',
    };
    const parsed = parseShareHash(encodeShareHash(payload));
    expect(parsed).toEqual(payload);
  });

  it("rejects unknown hashes", () => {
    expect(parseShareHash("")).toBeUndefined();
    expect(parseShareHash("#l=not-a-lesson")).toBeUndefined();
    expect(parseShareHash("#c=%%%")).toBeUndefined();
  });
});
