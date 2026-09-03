import { describe, expect, it } from "vitest";
import { parseDiagnostic, displayOutput, resolveErrorJump, diagnosticDisplayText } from "../src/domain/diagnostics";
import { findMatches, offsetOfLine } from "../src/domain/search";
import { formatC, indentSelection } from "../src/domain/indent";
import { normalizedName, normalizedFolderName, starterFile, STARTER_CODE, helperStarter, headerStarter } from "../src/domain/files";
import { LegalURLs, EXTRA_LEGAL_ROWS_VISIBLE, PICO_C_EXPLANATION } from "../src/domain/legal";
import { LocalCWorkspace } from "../src/domain/workspace";
import { finishConsoleOutput } from "../src/domain/console-transcript";
import { allLessons, firstLesson, lessonById, lessonRelativePath } from "../src/domain/curriculum";
import { loadProgress, markLessonComplete, resetProgressForTests } from "../src/domain/progress";
import {
  completeOnboarding,
  dismissFilesFolderTip,
  FILES_FOLDER_TIP,
  needsFilesFolderTip,
  needsOnboarding,
  ONBOARDING_COPY,
  resetOnboardingForTests,
} from "../src/domain/onboarding";
import { tokenizeC } from "../src/domain/syntax";

describe("legal URLs", () => {
  it("points at public GitHub Pages over HTTPS", () => {
    expect(LegalURLs.home).toBe("https://garrettmichae1.github.io/lilc/");
    expect(LegalURLs.privacy).toBe("https://garrettmichae1.github.io/lilc/privacy.html");
    expect(LegalURLs.terms).toBe("https://garrettmichae1.github.io/lilc/terms.html");
    expect(LegalURLs.privacy.startsWith("https://")).toBe(true);
    expect(LegalURLs.terms.startsWith("https://")).toBe(true);
  });

  it("hides teachers, licenses, and email this release", () => {
    expect(EXTRA_LEGAL_ROWS_VISIBLE).toBe(false);
  });

  it("explains that PicoC is not a compiler and C libraries will not work", () => {
    expect(PICO_C_EXPLANATION).toContain("interpreter, not a compiler");
    expect(PICO_C_EXPLANATION).toContain("C libraries");
    expect(PICO_C_EXPLANATION).toContain("will not work");
    expect(PICO_C_EXPLANATION).not.toContain("beginner programs");
    expect(PICO_C_EXPLANATION).not.toMatch(/standard library/i);
  });
});

describe("file names", () => {
  it("normalizes to .c or .h", () => {
    expect(normalizedName("hello")).toBe("hello.c");
    expect(normalizedName("hello.c")).toBe("hello.c");
    expect(normalizedName("  ")).toBe("hello.c");
    expect(normalizedFolderName("")).toBe("project");
  });
});

describe("search", () => {
  it("finds case-insensitive matches", () => {
    const text = 'int main(void) {\n    printf("Hello");\n    printf("hello");\n}\n';
    expect(findMatches(text, "HELLO")).toHaveLength(2);
    expect(findMatches(text, "   ")).toEqual([]);
    expect(findMatches(text, "")).toEqual([]);
  });

  it("maps jump-to-error onto a line", () => {
    const range = offsetOfLine("a\nb\nc\n", 2, 1);
    expect(range.start).toBe(2);
  });
});

describe("indent", () => {
  it("formats nested braces", () => {
    const messy = "int main(void) {\nreturn 0;\n}\n";
    expect(formatC(messy)).toBe("int main(void) {\n    return 0;\n}\n");
    expect(formatC("")).toBe("");
  });

  it("indents the current line without dropping caret", () => {
    const source = "int main(void) {\nreturn 0;\n}\n";
    const next = indentSelection(source, { start: 17, end: 17 }, false);
    expect(next.text).toContain("    return 0;");
    expect(next.range.start).toBeGreaterThan(17);
  });
});

describe("diagnostics", () => {
  it("explains a missing semicolon with PicoC detail", () => {
    const raw = `printf("hello")
               ^
hello.c:3:15 ';' expected`;
    const diagnostic = parseDiagnostic(raw);
    expect(diagnostic?.kind).toBe("SYNTAX ERROR");
    expect(diagnostic?.line).toBe(3);
    expect(diagnostic?.column).toBe(15);
    expect(diagnosticDisplayText(diagnostic!)).toContain("PicoC detail:");
    expect(displayOutput(raw).failed).toBe(true);
  });

  it("does not rewrite successful printf output", () => {
    const raw = "hello from lilC\n10\n";
    expect(parseDiagnostic(raw)).toBeUndefined();
    expect(displayOutput(raw)).toEqual({ text: raw, failed: false });
  });

  it("covers runner and PicoC error classes", () => {
    const catalog = [
      "hello.c:3:15 ';' expected",
      "hello.c:1:1 '{' expected",
      "hello.c:1:1 '}' expected",
      "hello.c:1:1 ')' expected",
      "Write some C code, then run it.",
      "main() is not defined",
      "Cannot run this project: it has more than one main() function (a.c, b.c).",
      "system() is not available in lilC local mode.",
      "program stopped: too many steps",
      "hello.c:4:1 is not defined",
    ];
    const missed = catalog.filter((item) => parseDiagnostic(item) === undefined);
    expect(missed).toEqual([]);
  });

  it("maps concatenated helper lines onto the helper file", () => {
    const helper = { relativePath: "proj/util.c", code: "int add(int a, int b) {\n    return a + b;\n}\n", updatedAt: 1 };
    const main = { relativePath: "proj/main.c", code: "int main(void) { return add(1, 2); }\n", updatedAt: 1 };
    const jump = resolveErrorJump(
      {
        kind: "SYNTAX ERROR",
        title: "Missing semicolon",
        explanation: "",
        suggestion: "",
        file: "util.c",
        line: 2,
        column: 1,
        rawMessage: "util.c:2:1 ';' expected",
      },
      main,
      [helper],
      [helper, main],
    );
    expect(jump?.fileID).toBe("proj/util.c");
    expect(jump?.line).toBe(2);
  });
});

describe("console transcript", () => {
  it("keeps echoed stdin when the run finishes", () => {
    const live =
      "Number 1: 5\nNumber 2: 9\nNumber 3: 2\nNumber 4: 1\nNumber 5: 4\nLargest number: 9\n";
    const captured = "Number 1: Number 2: Number 3: Number 4: Number 5: Largest number: 9\n";
    expect(finishConsoleOutput(live, captured, false)).toBe(live);
  });

  it("appends late stdout after echoed input", () => {
    expect(finishConsoleOutput("Number 1: 5\nNumber 2: 9\n", "Number 1: Number 2: Largest number: 9\n", false)).toBe(
      "Number 1: 5\nNumber 2: 9\nLargest number: 9\n",
    );
  });

  it("uses the diagnostic on failure and captured stdout when live is empty", () => {
    expect(finishConsoleOutput("Number 1: 5\n", "SYNTAX ERROR\n", true)).toBe("SYNTAX ERROR\n");
    expect(finishConsoleOutput("", "hello\n", false)).toBe("hello\n");
    expect(finishConsoleOutput("hello\n", "hello\n", false)).toBe("hello\n");
  });
});

describe("workspace", () => {
  it("creates a standalone file at the top level", () => {
    const workspace = new LocalCWorkspace();
    workspace.files = [starterFile()];
    workspace.selectedFileID = "hello.c";
    workspace.createFolder("demo");
    workspace.browsePath = "demo";
    workspace.createStandaloneFile();
    expect(workspace.currentFile.relativePath.includes("/")).toBe(false);
    expect(workspace.currentFile.code).toBe(STARTER_CODE);
  });

  it("refuses two mains in a project without touching PicoC", async () => {
    const workspace = new LocalCWorkspace();
    workspace.files = [
      { relativePath: "demo/a.c", code: "int main(void) { return 0; }\n", updatedAt: 1 },
      { relativePath: "demo/b.c", code: "int main(void) { return 1; }\n", updatedAt: 1 },
    ];
    workspace.folders = [{ relativePath: "demo", updatedAt: 1 }];
    workspace.selectedFileID = "demo/a.c";
    await workspace.runCurrentFile();
    expect(workspace.lastRunFailed).toBe(true);
    expect(workspace.output).toContain("Multiple main functions");
  });

  it("explains an empty editor", async () => {
    const workspace = new LocalCWorkspace();
    workspace.files = [{ relativePath: "empty.c", code: "   \n", updatedAt: 1 }];
    workspace.selectedFileID = "empty.c";
    await workspace.runCurrentFile();
    expect(workspace.lastRunFailed).toBe(true);
    expect(workspace.output).toContain("Nothing to run");
  });

  it("erase all restores a starter file", () => {
    const workspace = new LocalCWorkspace();
    workspace.files = [
      { relativePath: "a.c", code: "int x;", updatedAt: 1 },
      { relativePath: "b.c", code: "int y;", updatedAt: 1 },
    ];
    workspace.deleteAllFiles();
    expect(workspace.files).toHaveLength(1);
    expect(workspace.files[0]?.relativePath).toBe("hello.c");
  });

  it("checks first-hour output and advances to the next starter", () => {
    resetProgressForTests();
    const hello = firstLesson();
    const variables = lessonById("variables");
    expect(variables).toBeDefined();
    const workspace = new LocalCWorkspace();
    workspace.files = [
      { relativePath: lessonRelativePath(hello), code: hello.solution, updatedAt: 1 },
    ];
    workspace.selectedFileID = lessonRelativePath(hello);
    workspace.evaluateLessonRun("hello from lilC\n", false);
    expect(workspace.lessonOutcome?.status).toBe("passed");
    expect(workspace.lessonOutcome?.nextId).toBe("variables");
    expect(workspace.lessonOutcome?.replay).toBe(false);
    expect(loadProgress().completedIds).toEqual(["hello"]);
    const next = workspace.advanceAfterPass();
    expect(next === "celebrate" ? undefined : next?.id).toBe("variables");
    expect(workspace.currentFile.code).toBe(variables?.source);
  });

  it("tells the user to complete a challenge instead of a syntax error", async () => {
    resetProgressForTests();
    const twoSum = lessonById("two-sum")!;
    const workspace = new LocalCWorkspace();
    workspace.files = [{ relativePath: lessonRelativePath(twoSum), code: twoSum.source, updatedAt: 1 }];
    workspace.selectedFileID = lessonRelativePath(twoSum);
    await workspace.runCurrentFile();
    expect(workspace.lastRunFailed).toBe(false);
    expect(workspace.output).toContain("Complete this challenge.");
    expect(workspace.output).toContain("Replace ??? with C code");
    expect(workspace.output).toContain("The program must print 0 1.");
    expect(workspace.output).not.toContain("SYNTAX ERROR");
    expect(workspace.lessonOutcome?.status).toBe("missed");
  });

  it("treats lessons and challenges as catalogs of standalone programs", async () => {
    resetProgressForTests();
    const hello = firstLesson();
    const loop = lessonById("loop")!;
    const workspace = new LocalCWorkspace();
    workspace.files = [starterFile()];
    workspace.selectedFileID = "hello.c";
    workspace.openLesson(hello);
    workspace.files.find((file) => file.relativePath === lessonRelativePath(hello))!.code = hello.solution;
    workspace.openLesson(loop);
    workspace.files.find((file) => file.relativePath === lessonRelativePath(loop))!.code = loop.solution;
    workspace.select(workspace.files.find((file) => file.relativePath === lessonRelativePath(hello))!);

    expect(workspace.editorTitle).toBe(hello.fileName);
    expect(workspace.projectFiles.map((file) => file.relativePath)).toEqual([lessonRelativePath(hello)]);
    expect(workspace.fileToCompile().relativePath).toBe(lessonRelativePath(hello));
    expect(workspace.extraSourcesToLink(workspace.currentFile)).toEqual([]);

    workspace.browsePath = "lessons";
    const catalogNames = workspace.browserEntries
      .filter((entry) => entry.kind === "file")
      .map((entry) => (entry.kind === "file" ? entry.file.relativePath : ""));
    expect(catalogNames).toContain(lessonRelativePath(hello));
    expect(catalogNames).toContain(lessonRelativePath(loop));

    await workspace.runCurrentFile();
    expect(workspace.output).not.toContain("more than one main");
    expect(workspace.output).toContain("hello from lilC");
    expect(workspace.output).not.toContain("1\n2\n3");
    expect(workspace.lessonOutcome?.status).toBe("passed");
  });

  it("does not link a sibling helper in lessons or create files inside catalogs", async () => {
    resetProgressForTests();
    const functionLesson = lessonById("function")!;
    const workspace = new LocalCWorkspace();
    workspace.files = [
      { relativePath: lessonRelativePath(functionLesson), code: functionLesson.solution, updatedAt: 1 },
      { relativePath: "lessons/helper.c", code: "int twice(int n) { return 0; }\n", updatedAt: 1 },
    ];
    workspace.folders = [{ relativePath: "lessons", updatedAt: 1 }];
    workspace.selectedFileID = lessonRelativePath(functionLesson);
    expect(workspace.extraSourcesToLink(workspace.currentFile)).toEqual([]);
    expect(workspace.fileToCompile().relativePath).toBe(lessonRelativePath(functionLesson));
    expect(workspace.projectFiles).toHaveLength(1);

    await workspace.runCurrentFile();
    expect(workspace.output).toContain("42");
    expect(workspace.output.toLowerCase()).not.toContain("already defined");
    expect(workspace.lessonOutcome?.status).toBe("passed");

    workspace.browsePath = "lessons";
    workspace.createFile();
    expect(workspace.currentFile.relativePath.includes("/")).toBe(false);
    expect(workspace.files.some((file) => file.relativePath.startsWith("lessons/program"))).toBe(false);

    const twoSum = lessonById("two-sum")!;
    workspace.openLesson(twoSum);
    workspace.browsePath = "challenges";
    workspace.createFile();
    expect(workspace.currentFile.relativePath.includes("/")).toBe(false);
    expect(workspace.files.some((file) => file.relativePath.startsWith("challenges/program"))).toBe(false);
  });

  it("openProject does not invent main.c inside lessons or challenges", () => {
    const workspace = new LocalCWorkspace();
    workspace.files = [{ relativePath: lessonRelativePath(firstLesson()), code: firstLesson().source, updatedAt: 1 }];
    workspace.folders = [{ relativePath: "lessons", updatedAt: 1 }];
    workspace.openProject(workspace.folders[0]!);
    expect(workspace.files.some((file) => file.relativePath === "lessons/main.c")).toBe(false);

    workspace.files = [starterFile()];
    workspace.folders = [
      { relativePath: "lessons", updatedAt: 1 },
      { relativePath: "challenges", updatedAt: 1 },
    ];
    workspace.openProject(workspace.folders[0]!);
    expect(workspace.files.some((file) => file.relativePath === "lessons/main.c")).toBe(false);
    workspace.openProject(workspace.folders[1]!);
    expect(workspace.files.some((file) => file.relativePath === "challenges/main.c")).toBe(false);
  });

  it("uses a main starter at root and for the first C file in a folder", () => {
    const workspace = new LocalCWorkspace();
    workspace.files = [starterFile()];
    workspace.selectedFileID = "hello.c";
    workspace.browsePath = "";
    workspace.createFile();
    expect(workspace.currentFile.relativePath).toBe("program.c");
    expect(workspace.currentFile.code).toBe(STARTER_CODE);
    expect(workspace.currentFile.code).toContain("int main(void)");

    workspace.createFolder("demo");
    workspace.browsePath = "demo";
    workspace.createFile();
    expect(workspace.currentFile.relativePath).toBe("demo/program.c");
    expect(workspace.currentFile.code).toBe(STARTER_CODE);
  });

  it("uses a helper starter for extra C files in a folder that already has main()", () => {
    const workspace = new LocalCWorkspace();
    workspace.files = [starterFile()];
    workspace.selectedFileID = "hello.c";
    workspace.createFolder("demo");
    workspace.openProject(workspace.folders[0]!);
    expect(workspace.currentFile.relativePath).toBe("demo/main.c");
    expect(workspace.currentFile.code).toBe(STARTER_CODE);

    workspace.browsePath = "demo";
    workspace.createFile();
    expect(workspace.currentFile.relativePath).toBe("demo/program.c");
    expect(workspace.currentFile.code).toBe(helperStarter("program.c"));
    expect(workspace.currentFile.code).not.toContain("int main(void)");
    expect(workspace.extraSourcesToLink(workspace.fileToCompile()).map((file) => file.relativePath)).toEqual([
      "demo/program.c",
    ]);

    workspace.createHeader();
    expect(workspace.currentFile.relativePath).toBe("demo/module.h");
    expect(workspace.currentFile.code).toBe(headerStarter("module.h"));
    expect(workspace.currentFile.code).toContain("#ifndef MODULE_H");
    expect(workspace.currentFile.code).not.toContain("int main(void)");
  });

  it("runs one lesson even when other lesson files also have main()", async () => {
    resetProgressForTests();
    const hello = firstLesson();
    const loop = lessonById("loop");
    expect(loop).toBeDefined();
    const workspace = new LocalCWorkspace();
    workspace.files = [
      { relativePath: lessonRelativePath(hello), code: hello.solution, updatedAt: 1 },
      { relativePath: lessonRelativePath(loop!), code: loop!.solution, updatedAt: 1 },
    ];
    workspace.selectedFileID = lessonRelativePath(hello);
    await workspace.runCurrentFile();
    expect(workspace.output).not.toContain("more than one main");
    expect(workspace.lessonOutcome?.status).toBe("passed");
  });

  it("celebrates only the first time every challenge is done", () => {
    resetProgressForTests();
    const last = lessonById("move-zeroes")!;
    for (const lesson of allLessons) {
      if (lesson.id !== last.id) {
        markLessonComplete(lesson.id);
      }
    }
    const workspace = new LocalCWorkspace();
    workspace.files = [{ relativePath: lessonRelativePath(last), code: last.solution, updatedAt: 1 }];
    workspace.selectedFileID = lessonRelativePath(last);
    workspace.evaluateLessonRun("1 3 12 0 0\n", false);
    expect(workspace.lessonOutcome?.celebrate).toBe(true);
    expect(workspace.output).toContain("Nice. That was the last challenge.");
    expect(workspace.advanceAfterPass()).toBe("celebrate");

    workspace.evaluateLessonRun("1 3 12 0 0\n", false);
    expect(workspace.lessonOutcome?.replay).toBe(true);
    expect(workspace.lessonOutcome?.celebrate).toBe(false);
    expect(workspace.advanceAfterPass()).toBeUndefined();
  });
});

describe("onboarding", () => {
  it("shows on first visit, then never after complete", () => {
    resetOnboardingForTests();
    expect(needsOnboarding()).toBe(true);
    completeOnboarding();
    expect(needsOnboarding()).toBe(false);
    expect(needsOnboarding()).toBe(false);
  });

  it("uses the same two-page copy as iOS", () => {
    expect(ONBOARDING_COPY.pageCount).toBe(2);
    expect(ONBOARDING_COPY.page1Headline).toBe("Write C. Press Run.");
    expect(ONBOARDING_COPY.page1Line).toBe("lilC runs your code locally");
    expect(ONBOARDING_COPY.page2Headline).toBe("C stays free. Zero ads.");
    expect(ONBOARDING_COPY.page2Line).toBe("For students and developers.");
    expect(ONBOARDING_COPY.continueTitle).toBe("Continue");
    expect(ONBOARDING_COPY.getStartedTitle).toBe("Get Started");
    expect(ONBOARDING_COPY.skipTitle).toBe("Skip");
  });

  it("shows the files folder tip once until dismissed", () => {
    resetOnboardingForTests();
    expect(needsFilesFolderTip()).toBe(true);
    expect(FILES_FOLDER_TIP).toBe("Create a folder, then drag C files into it.");
    dismissFilesFolderTip();
    expect(needsFilesFolderTip()).toBe(false);
    expect(needsFilesFolderTip()).toBe(false);
  });
});

describe("syntax coloring", () => {
  it("colors keywords and operators but not words inside strings or comments", () => {
    const source = `#include <stdio.h>
int main(void) {
    if (x == 1) {
        printf("if");
    }
    // if
    return 0x2A;
}
`;
    const labeled = tokenizeC(source).map((token) => ({
      kind: token.kind,
      text: source.slice(token.start, token.end),
    }));
    expect(labeled.some((token) => token.kind === "preprocessor" && token.text.startsWith("#include"))).toBe(true);
    expect(labeled.some((token) => token.kind === "type" && token.text === "int")).toBe(true);
    expect(labeled.some((token) => token.kind === "control" && token.text === "if")).toBe(true);
    expect(labeled.some((token) => token.kind === "op" && token.text === "==")).toBe(true);
    expect(labeled.some((token) => token.kind === "string" && token.text === '"if"')).toBe(true);
    expect(labeled.some((token) => token.kind === "comment" && token.text.includes("if"))).toBe(true);
    expect(labeled.some((token) => token.kind === "number" && token.text === "0x2A")).toBe(true);
    expect(labeled.some((token) => token.kind === "control" && token.text === "printf")).toBe(false);
    expect(labeled.filter((token) => token.kind === "control" && token.text === "if")).toHaveLength(1);
  });

  it("does not hang on an unclosed string", () => {
    const source = 'char *s = "hello';
    const tokens = tokenizeC(source);
    expect(tokens.some((token) => token.kind === "string")).toBe(true);
  });
});
