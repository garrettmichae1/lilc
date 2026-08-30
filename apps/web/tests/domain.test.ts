import { describe, expect, it } from "vitest";
import { parseDiagnostic, displayOutput, resolveErrorJump, diagnosticDisplayText } from "../src/domain/diagnostics";
import { findMatches, offsetOfLine } from "../src/domain/search";
import { formatC, indentSelection } from "../src/domain/indent";
import { normalizedName, normalizedFolderName, starterFile, STARTER_CODE } from "../src/domain/files";
import { LegalURLs } from "../src/domain/legal";
import { LocalCWorkspace } from "../src/domain/workspace";
import { firstHourCurriculum, firstLesson, lessonById, lessonRelativePath } from "../src/domain/curriculum";
import { loadProgress, resetProgressForTests } from "../src/domain/progress";

describe("legal URLs", () => {
  it("points at public GitHub Pages over HTTPS", () => {
    expect(LegalURLs.home).toBe("https://garrettmichae1.github.io/lilc/");
    expect(LegalURLs.privacy).toBe("https://garrettmichae1.github.io/lilc/privacy.html");
    expect(LegalURLs.terms).toBe("https://garrettmichae1.github.io/lilc/terms.html");
    expect(LegalURLs.privacy.startsWith("https://")).toBe(true);
    expect(LegalURLs.terms.startsWith("https://")).toBe(true);
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

  it("checks first-hour output and advances to the next starter", async () => {
    resetProgressForTests();
    const hello = firstLesson();
    const variables = lessonById("variables");
    expect(variables).toBeDefined();
    const workspace = new LocalCWorkspace();
    workspace.files = [
      { relativePath: lessonRelativePath(hello), code: hello.solution, updatedAt: 1 },
    ];
    workspace.selectedFileID = lessonRelativePath(hello);
    await workspace.runCurrentFile();
    expect(workspace.lastRunFailed).toBe(false);
    expect(workspace.lessonOutcome?.status).toBe("passed");
    expect(workspace.lessonOutcome?.nextId).toBe("variables");
    expect(loadProgress().completedIds).toEqual(["hello"]);
    const next = workspace.advanceAfterPass();
    expect(next === "celebrate" ? undefined : next?.id).toBe("variables");
    expect(workspace.currentFile.code).toBe(variables?.source);
  });

  it("keeps PicoC-style failure text and adds a not-yet line", async () => {
    resetProgressForTests();
    const hello = firstLesson();
    const workspace = new LocalCWorkspace();
    workspace.files = [{ relativePath: lessonRelativePath(hello), code: hello.source, updatedAt: 1 }];
    workspace.selectedFileID = lessonRelativePath(hello);
    await workspace.runCurrentFile();
    expect(workspace.lessonOutcome?.status).toBe("missed");
    expect(workspace.output).toContain("Not yet. The program must print Hello, world.");
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

  it("celebrates after the last lesson", async () => {
    resetProgressForTests();
    const last = firstHourCurriculum.lessons[firstHourCurriculum.lessons.length - 1];
    expect(last).toBeDefined();
    const workspace = new LocalCWorkspace();
    workspace.files = [{ relativePath: lessonRelativePath(last!), code: last!.solution, updatedAt: 1 }];
    workspace.selectedFileID = lessonRelativePath(last!);
    await workspace.runCurrentFile();
    expect(workspace.lessonOutcome?.celebrate).toBe(true);
    expect(workspace.advanceAfterPass()).toBe("celebrate");
  });
});
