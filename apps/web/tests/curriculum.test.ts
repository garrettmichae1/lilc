import { afterEach, beforeEach, describe, expect, it } from "vitest";
import {
  allLessons,
  challengeLessons,
  continueLesson,
  firstHourCurriculum,
  firstHourLessons,
  firstLesson,
  lessonById,
  lessonRelativePath,
  nextIncomplete,
  nextLesson,
} from "../src/domain/curriculum";
import {
  allTracksComplete,
  emptyProgress,
  hourComplete,
  loadProgress,
  markLessonComplete,
  resetProgressForTests,
  setCurrentLesson,
  showsChallengesDeck,
  showsFirstHourDeck,
  writeRawProgressForTests,
} from "../src/domain/progress";
import { encodeShareHash, parseShareHash, playgroundURL } from "../src/domain/share";
import { runFirstHourSubset } from "../src/domain/subset";
import { appendNotYet, checkLessonWin, matchesWin, notYetMessage } from "../src/domain/win";

describe("first-hour curriculum", () => {
  it("loads twenty sequenced starter files", () => {
    expect(firstHourLessons).toHaveLength(20);
    expect(firstLesson().id).toBe("hello");
    expect(lessonById("function")?.number).toBe(6);
    expect(lessonById("copy")?.number).toBe(20);
    const ids = firstHourLessons.map((lesson) => lesson.id);
    expect(new Set(ids).size).toBe(20);
    for (const lesson of firstHourLessons) {
      expect(lessonRelativePath(lesson).startsWith("lessons/")).toBe(true);
      expect(lesson.source).toContain("int main(");
      expect(lesson.source).toContain("???");
      expect(lesson.solution).not.toContain("???");
      expect(lesson.printHint.length).toBeGreaterThan(0);
    }
  });

  it("runs every first-hour solution on the subset and rejects starters", () => {
    for (const lesson of firstHourLessons) {
      expect(checkLessonWin(lesson, "", lesson.source)).toBe(false);
      const solved = runFirstHourSubset(lesson.solution);
      expect(solved.ok, lesson.id).toBe(true);
      expect(checkLessonWin(lesson, solved.output, lesson.solution), lesson.id).toBe(true);
    }
  });
});

describe("challenge curriculum", () => {
  it("loads twelve fill-in-the-blank challenges", () => {
    expect(challengeLessons).toHaveLength(12);
    expect(allLessons).toHaveLength(32);
    expect(new Set(challengeLessons.map((lesson) => lesson.id)).size).toBe(12);
    for (const lesson of challengeLessons) {
      expect(lessonRelativePath(lesson).startsWith("challenges/")).toBe(true);
      expect(lesson.source).toContain("???");
      expect(lesson.solution).not.toContain("???");
      expect(checkLessonWin(lesson, "", lesson.source)).toBe(false);
    }
  });

  it("runs every challenge solution on the subset and rejects starters", () => {
    for (const lesson of challengeLessons) {
      expect(checkLessonWin(lesson, "", lesson.source)).toBe(false);
      const solved = runFirstHourSubset(lesson.solution);
      expect(solved.ok, `${lesson.id} subset: ${solved.output}`).toBe(true);
      expect(checkLessonWin(lesson, solved.output, lesson.solution), `${lesson.id} win ${solved.output}`).toBe(
        true,
      );
    }
  });
});

describe("lesson win conditions", () => {
  const hello = firstLesson();
  const variables = lessonById("variables")!;
  const iff = lessonById("if")!;
  const twoSum = lessonById("two-sum")!;
  const parens = lessonById("valid-parens")!;
  const plus = lessonById("plus-one")!;
  const move = lessonById("move-zeroes")!;
  const palindrome = lessonById("palindrome")!;

  it("requires the filled-in Hello message", () => {
    expect(checkLessonWin(hello, "hello from lilC\n", hello.source)).toBe(false);
    expect(checkLessonWin(hello, "hello from lilC\n", hello.solution)).toBe(true);
    expect(checkLessonWin(hello, "howdy\n", hello.solution)).toBe(false);
  });

  it("accepts warm or cool for If after the blank is filled", () => {
    expect(checkLessonWin(iff, "warm\n", iff.solution)).toBe(true);
    expect(checkLessonWin(iff, "cool\n", iff.solution)).toBe(true);
    expect(checkLessonWin(iff, "hot\n", iff.solution)).toBe(false);
    expect(checkLessonWin(iff, "warm\n", iff.source)).toBe(false);
  });

  it("requires year = for variables after the blank is filled", () => {
    expect(checkLessonWin(variables, "year = 2026\n", variables.solution)).toBe(true);
    expect(checkLessonWin(variables, "year = 2026\n", variables.source)).toBe(false);
    expect(checkLessonWin(variables, "hello\n", variables.solution)).toBe(false);
  });

  it.each([
    { id: "add", number: 7, fileName: "07-add.c", good: "15\n", bad: "10\n", next: "equals" },
    { id: "equals", number: 8, fileName: "08-equals.c", good: "match\n", bad: "no\n", next: "while-loop" },
    { id: "while-loop", number: 9, fileName: "09-while.c", good: "3\n2\n1\n", bad: "3\n", next: "remainder" },
    { id: "remainder", number: 10, fileName: "10-remainder.c", good: "even\n", bad: "odd\n", next: "and" },
    { id: "and", number: 11, fileName: "11-and.c", good: "in\n", bad: "out\n", next: "index" },
    { id: "index", number: 12, fileName: "12-index.c", good: "9\n", bad: "4\n", next: "count" },
    { id: "count", number: 13, fileName: "13-count.c", good: "2\n", bad: "4\n", next: "biggest" },
    { id: "biggest", number: 14, fileName: "14-biggest.c", good: "9\n", bad: "3\n", next: "nested" },
    { id: "nested", number: 15, fileName: "15-nested.c", good: "11\n12\n21\n22\n", bad: "11\n12\n", next: "swap" },
    { id: "swap", number: 16, fileName: "16-swap.c", good: "2 1\n", bad: "1 2\n", next: "sum-fn" },
    { id: "sum-fn", number: 17, fileName: "17-sum.c", good: "7\n", bad: "3\n", next: "opposite" },
    { id: "opposite", number: 18, fileName: "18-opposite.c", good: "4\n", bad: "-4\n", next: "find" },
    { id: "find", number: 19, fileName: "19-find.c", good: "1\n", bad: "0\n", next: "copy" },
    { id: "copy", number: 20, fileName: "20-copy.c", good: "4 9 1\n", bad: "0 0 0\n", next: undefined },
  ])("$id: starter fails, solution prints $good, $bad does not win", (row) => {
    const lesson = lessonById(row.id);
    expect(lesson, row.id).toBeDefined();
    if (!lesson) {
      return;
    }
    expect(lesson.number).toBe(row.number);
    expect(lesson.fileName).toBe(row.fileName);
    expect(lessonRelativePath(lesson)).toBe(`lessons/${row.fileName}`);
    expect(lesson.source).toContain("???");
    expect(lesson.solution).not.toContain("???");
    expect(checkLessonWin(lesson, row.good, lesson.source)).toBe(false);
    expect(checkLessonWin(lesson, row.good, lesson.solution)).toBe(true);
    expect(checkLessonWin(lesson, row.bad, lesson.solution)).toBe(false);
    const solved = runFirstHourSubset(lesson.solution);
    expect(solved.ok, `${row.id}: ${solved.output}`).toBe(true);
    expect(checkLessonWin(lesson, solved.output, lesson.solution)).toBe(true);
    expect(nextLesson(lesson)?.id).toBe(row.next);
  });

  it("requires named C in sum, opposite, equals, remainder, and and", () => {
    const sum = lessonById("sum-fn")!;
    expect(checkLessonWin(sum, "7\n", sum.solution.replaceAll("sum", "add"))).toBe(false);
    const opposite = lessonById("opposite")!;
    expect(checkLessonWin(opposite, "4\n", opposite.solution.replaceAll("opposite", "flip"))).toBe(false);
    const equals = lessonById("equals")!;
    expect(checkLessonWin(equals, "match\n", equals.solution.replaceAll("==", ">"))).toBe(false);
    const remainder = lessonById("remainder")!;
    expect(checkLessonWin(remainder, "even\n", remainder.solution.replaceAll("%", "/"))).toBe(false);
    const and = lessonById("and")!;
    expect(checkLessonWin(and, "in\n", and.solution.replaceAll("&&", "||"))).toBe(false);
  });

  it("does not treat invalid as valid parens", () => {
    expect(matchesWin(parens.win, "invalid")).toBe(false);
    expect(matchesWin(parens.win, "invalid\n")).toBe(false);
    expect(matchesWin(parens.win, "valid")).toBe(true);
    expect(matchesWin(parens.win, "valid\nProgram finished.\n")).toBe(true);
  });

  it("does not treat 0 10 as two-sum", () => {
    expect(matchesWin(twoSum.win, "0 10")).toBe(false);
    expect(matchesWin(twoSum.win, "0 1")).toBe(true);
    expect(matchesWin(twoSum.win, "0 1\nProgram finished.\n")).toBe(true);
  });

  it("uses exact wins for plus-one, move-zeroes, palindrome", () => {
    expect(matchesWin(plus.win, "1 2 40")).toBe(false);
    expect(matchesWin(plus.win, "1 2 4")).toBe(true);
    expect(matchesWin(move.win, "1 3 12 0 0 9")).toBe(false);
    expect(matchesWin(move.win, "1 3 12 0 0\nProgram finished.\n")).toBe(true);
    expect(matchesWin(palindrome.win, "yes")).toBe(true);
    expect(matchesWin(palindrome.win, "yesterday")).toBe(false);
  });

  it("formats the not-yet line", () => {
    expect(notYetMessage(twoSum)).toBe("Not yet. The program must print 0 1.");
    expect(appendNotYet("oops\n", twoSum)).toBe("oops\nNot yet. The program must print 0 1.\n");
  });

  it("names the next lesson within a track", () => {
    expect(nextLesson(hello)?.id).toBe("variables");
    expect(nextLesson(lessonById("function")!)?.id).toBe("add");
    expect(nextLesson(lessonById("copy")!)?.id).toBeUndefined();
    expect(nextIncomplete("copy", firstHourLessons.map((lesson) => lesson.id))?.id).toBe("two-sum");
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

  it("marks the hour complete after every first-hour lesson and still shows challenges", () => {
    expect(showsFirstHourDeck()).toBe(true);
    expect(showsChallengesDeck()).toBe(true);
    for (const lesson of firstHourCurriculum.lessons) {
      markLessonComplete(lesson.id);
    }
    const progress = loadProgress();
    expect(hourComplete(progress)).toBe(true);
    expect(showsFirstHourDeck(progress)).toBe(false);
    expect(showsChallengesDeck(progress)).toBe(true);
    expect(allTracksComplete(progress)).toBe(false);
    expect(progress.stars).toBe(20);
  });

  it("hides the challenges deck only after all twelve", () => {
    for (const lesson of allLessons) {
      markLessonComplete(lesson.id);
    }
    const progress = loadProgress();
    expect(allTracksComplete(progress)).toBe(true);
    expect(showsFirstHourDeck(progress)).toBe(false);
    expect(showsChallengesDeck(progress)).toBe(false);
    expect(progress.stars).toBe(32);
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
    expect(parseShareHash("#l=two-sum")).toEqual({ kind: "lesson", id: "two-sum" });
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
