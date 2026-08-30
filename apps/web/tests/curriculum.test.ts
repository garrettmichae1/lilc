import { describe, expect, it } from "vitest";
import {
  firstHourCurriculum,
  firstLesson,
  lessonById,
  lessonRelativePath,
} from "../src/domain/curriculum";
import { encodeShareHash, parseShareHash, playgroundURL } from "../src/domain/share";
import { runFirstHourSubset } from "../src/domain/subset";

describe("first-hour curriculum", () => {
  it("loads six sequenced starter files", () => {
    expect(firstHourCurriculum.lessons).toHaveLength(6);
    expect(firstLesson().id).toBe("hello");
    expect(lessonById("function")?.number).toBe(6);
    const ids = firstHourCurriculum.lessons.map((lesson) => lesson.id);
    expect(new Set(ids).size).toBe(6);
    for (const lesson of firstHourCurriculum.lessons) {
      expect(lessonRelativePath(lesson).startsWith("lessons/")).toBe(true);
      expect(lesson.source).toContain("int main(");
      expect(lesson.expectedOutput.length).toBeGreaterThan(0);
    }
  });

  it("runs every lesson on the first-hour subset", () => {
    for (const lesson of firstHourCurriculum.lessons) {
      const result = runFirstHourSubset(lesson.source);
      expect(result.ok, lesson.id).toBe(true);
      expect(result.output, lesson.id).toBe(lesson.expectedOutput);
    }
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
