/**
 * @vitest-environment happy-dom
 */
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { firstLesson, lessonById } from "../src/domain/curriculum";
import { resetProgressForTests } from "../src/domain/progress";
import { loadSyntaxColoring, saveSyntaxColoring, SYNTAX_COLORING_KEY } from "../src/domain/appearance";
import { LocalCWorkspace } from "../src/domain/workspace";
import { renderEditor, nextOutputChromeExpanded } from "../src/ui/screens/editor";

describe("web editor typing", () => {
  beforeEach(() => {
    document.body.replaceChildren();
    localStorage.removeItem(SYNTAX_COLORING_KEY);
  });

  afterEach(() => {
    document.body.replaceChildren();
  });

  it("keeps the textarea focused so physical keys can type C", async () => {
    const workspace = new LocalCWorkspace();
    await workspace.load();
    const screen = renderEditor(workspace, { back: () => undefined });
    document.body.append(screen);
    const textarea = screen.querySelector("textarea.editor");
    expect(textarea).toBeInstanceOf(HTMLTextAreaElement);
    if (!(textarea instanceof HTMLTextAreaElement)) {
      return;
    }
    expect(textarea.readOnly).toBe(false);
    expect(textarea.disabled).toBe(false);

    textarea.focus();
    expect(document.activeElement).toBe(textarea);

    const before = textarea.value;
    textarea.setRangeText("int ", 0, 0, "end");
    textarea.dispatchEvent(new Event("input", { bubbles: true }));
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(document.activeElement).toBe(textarea);
    expect(textarea.value.startsWith("int ")).toBe(true);
    expect(textarea.isConnected).toBe(true);
    expect(workspace.currentFile.code.startsWith("int ")).toBe(true);
    expect(textarea.value.length).toBeGreaterThan(before.length);
  });

  it("keeps the same focused textarea when syntax coloring is on and paints keywords", async () => {
    const workspace = new LocalCWorkspace();
    await workspace.load();
    workspace.updateCurrentCode("int main(void) {\n    return 0;\n}\n");
    const screen = renderEditor(workspace, { back: () => undefined }, { syntaxColoring: true });
    document.body.append(screen);
    const textarea = screen.querySelector("textarea.editor");
    expect(textarea).toBeInstanceOf(HTMLTextAreaElement);
    if (!(textarea instanceof HTMLTextAreaElement)) {
      return;
    }
    expect(textarea.classList.contains("syntax-on")).toBe(true);
    textarea.focus();
    expect(document.activeElement).toBe(textarea);

    const highlight = screen.querySelector("[data-editor-highlight]");
    expect(highlight).toBeInstanceOf(HTMLElement);
    const keyword = [...(highlight?.querySelectorAll("span.tok-type") ?? [])].find(
      (node) => node.textContent === "int",
    );
    expect(keyword).toBeInstanceOf(HTMLElement);

    textarea.setRangeText("if ", 0, 0, "end");
    textarea.dispatchEvent(new Event("input", { bubbles: true }));
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(document.activeElement).toBe(textarea);
    expect(screen.querySelector("textarea.editor")).toBe(textarea);
    expect(textarea.isConnected).toBe(true);
    const control = [...(highlight?.querySelectorAll("span.tok-control") ?? [])].find(
      (node) => node.textContent === "if",
    );
    expect(control).toBeInstanceOf(HTMLElement);
  });

  it("defaults syntax coloring off and persists the setting", () => {
    expect(loadSyntaxColoring()).toBe(false);
    saveSyntaxColoring(true);
    expect(localStorage.getItem(SYNTAX_COLORING_KEY)).toBe("1");
    expect(loadSyntaxColoring()).toBe(true);
    saveSyntaxColoring(false);
    expect(loadSyntaxColoring()).toBe(false);
  });

  it("keeps the same textarea when the next lesson loads", async () => {
    resetProgressForTests();
    const workspace = new LocalCWorkspace();
    await workspace.load();
    workspace.openLesson(firstLesson());
    const screen = renderEditor(workspace, { back: () => undefined });
    document.body.append(screen);
    const textarea = screen.querySelector("textarea.editor");
    expect(textarea).toBeInstanceOf(HTMLTextAreaElement);
    if (!(textarea instanceof HTMLTextAreaElement)) {
      return;
    }
    const host = screen.querySelector("[data-editor-host]");
    workspace.openLesson(lessonById("variables")!);
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(screen.querySelector("textarea.editor")).toBe(textarea);
    expect(screen.querySelector("[data-editor-host]")).toBe(host);
    expect(textarea.isConnected).toBe(true);
    expect(textarea.value).toBe(lessonById("variables")!.source);
  });

  it("shows the lesson file name and only that tab, and plus creates at root", async () => {
    resetProgressForTests();
    const workspace = new LocalCWorkspace();
    await workspace.load();
    workspace.openLesson(firstLesson());
    workspace.openLesson(lessonById("loop")!);
    const screen = renderEditor(workspace, { back: () => undefined });
    document.body.append(screen);

    expect(screen.querySelector(".title")?.textContent).toBe("04-loop.c");
    const tabs = [...screen.querySelectorAll(".file-tab")].map((tab) => tab.textContent);
    expect(tabs).toEqual(["04-loop.c"]);

    const plus = screen.querySelector('[aria-label="New file"]');
    expect(plus).toBeInstanceOf(HTMLButtonElement);
    const before = workspace.currentFile.relativePath;
    (plus as HTMLButtonElement).click();
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(workspace.currentFile.relativePath).toBe(before);
    expect(screen.querySelector(".sheet")).toBeInstanceOf(HTMLElement);
    const createC = [...screen.querySelectorAll(".sheet button")].find((button) =>
      button.textContent?.includes("C file"),
    );
    expect(createC).toBeInstanceOf(HTMLButtonElement);
    (createC as HTMLButtonElement).click();
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(workspace.currentFile.relativePath.includes("/")).toBe(false);
    expect(workspace.currentFile.code).toContain("int main(void)");
    expect(workspace.files.some((file) => file.relativePath.startsWith("lessons/program"))).toBe(false);
  });

  it("shows FMT in the top bar and indents the buffer", async () => {
    const workspace = new LocalCWorkspace();
    await workspace.load();
    workspace.updateCurrentCode("int main(void) {\nreturn 0;\n}\n");
    const screen = renderEditor(workspace, { back: () => undefined });
    document.body.append(screen);

    const format = screen.querySelector('.topbar [aria-label="Format code"]');
    expect(format).toBeInstanceOf(HTMLButtonElement);
    expect(format?.textContent).toBe("FMT");
    (format as HTMLButtonElement).click();

    const textarea = screen.querySelector("textarea.editor");
    expect(textarea).toBeInstanceOf(HTMLTextAreaElement);
    expect((textarea as HTMLTextAreaElement).value).toBe("int main(void) {\n    return 0;\n}\n");
    expect(workspace.currentFile.code).toBe("int main(void) {\n    return 0;\n}\n");
  });

  it("expands output over the editor for the whole run", async () => {
    expect(nextOutputChromeExpanded(-48, true, false)).toBe(true);
    expect(nextOutputChromeExpanded(80, true, true)).toBe(true);
    expect(nextOutputChromeExpanded(-20, true, false)).toBe(true);
    expect(nextOutputChromeExpanded(-80, false, false)).toBe(false);
    expect(nextOutputChromeExpanded(-80, false, true)).toBe(false);

    const workspace = new LocalCWorkspace();
    await workspace.load();
    const screen = renderEditor(workspace, { back: () => undefined });
    document.body.append(screen);
    const handle = screen.querySelector("[data-output-swipe]");
    expect(handle).toBeInstanceOf(HTMLElement);
    if (!(handle instanceof HTMLElement)) {
      return;
    }
    const chrome = screen.querySelector("[data-editor-chrome]");
    expect(chrome?.classList.contains("output-chrome-expanded")).toBe(false);

    workspace.isRunning = true;
    swipe(handle, 240, 180);
    expect(chrome?.classList.contains("output-chrome-expanded")).toBe(true);

    swipe(screen.querySelector("[data-output-swipe]"), 180, 240);
    expect(chrome?.classList.contains("output-chrome-expanded")).toBe(true);

    workspace.isRunning = false;
    swipe(screen.querySelector("[data-output-swipe]"), 240, 180);
    expect(chrome?.classList.contains("output-chrome-expanded")).toBe(false);
  });

  it("hides file tabs and the lesson rail while a program is running", async () => {
    resetProgressForTests();
    const workspace = new LocalCWorkspace();
    await workspace.load();
    workspace.openLesson(firstLesson());
    const screen = renderEditor(workspace, { back: () => undefined });
    document.body.append(screen);
    expect(screen.querySelector(".file-tab")).toBeInstanceOf(HTMLButtonElement);
    expect(screen.querySelector(".lesson-rail")).toBeInstanceOf(HTMLElement);

    workspace.isRunning = true;
    swipe(screen.querySelector("[data-output-swipe]"), 240, 180);
    expect(screen.querySelector(".file-tab")).toBeNull();
    expect(screen.querySelector(".lesson-rail")).toBeNull();
    expect(screen.querySelector(".name-row")).toBeNull();
  });

  it("shows a TODO badge that jumps to ???", async () => {
    resetProgressForTests();
    const workspace = new LocalCWorkspace();
    await workspace.load();
    workspace.openLesson(firstLesson());
    const screen = renderEditor(workspace, { back: () => undefined });
    document.body.append(screen);
    await workspace.runCurrentFile();
    await new Promise((resolve) => setTimeout(resolve, 0));
    const todo = screen.querySelector('[aria-label="Jump to the blank"]');
    expect(todo).toBeInstanceOf(HTMLButtonElement);
    expect(todo?.textContent).toContain("TODO");
    (todo as HTMLButtonElement).click();
    const textarea = screen.querySelector("textarea.editor");
    expect(textarea).toBeInstanceOf(HTMLTextAreaElement);
    expect((textarea as HTMLTextAreaElement).value.slice(
      (textarea as HTMLTextAreaElement).selectionStart,
      (textarea as HTMLTextAreaElement).selectionEnd,
    )).toContain("???");
  });

  it("highlights find matches in the editor overlay", async () => {
    const workspace = new LocalCWorkspace();
    await workspace.load();
    workspace.updateCurrentCode("int main(void) {\n    int n = 1;\n    return 0;\n}\n");
    const screen = renderEditor(workspace, { back: () => undefined });
    document.body.append(screen);
    const find = screen.querySelector('[aria-label="Find"]');
    expect(find).toBeInstanceOf(HTMLButtonElement);
    (find as HTMLButtonElement).click();
    const findInput = screen.querySelector('[aria-label="Find in file"]');
    expect(findInput).toBeInstanceOf(HTMLInputElement);
    if (!(findInput instanceof HTMLInputElement)) {
      return;
    }
    findInput.value = "int";
    findInput.dispatchEvent(new Event("input", { bubbles: true }));
    await new Promise((resolve) => setTimeout(resolve, 0));
    const hits = screen.querySelectorAll("[data-editor-highlight] .find-hit, [data-editor-highlight] .find-hit-current");
    expect(hits.length).toBeGreaterThan(1);
    expect(screen.querySelector("[data-editor-highlight] .find-hit-current")).toBeInstanceOf(HTMLElement);
  });

  it("keeps stdin directly under compact output while running", async () => {
    const workspace = new LocalCWorkspace();
    await workspace.load();
    const screen = renderEditor(workspace, { back: () => undefined });
    document.body.append(screen);
    workspace.isRunning = true;
    workspace.output = "Enter two integers:\n";
    swipe(screen.querySelector("[data-output-swipe]"), 240, 180);

    const pane = screen.querySelector(".output-pane");
    expect(pane?.classList.contains("running")).toBe(true);
    const kids = [...(pane?.children ?? [])];
    const bodyIdx = kids.findIndex((node) => node.classList.contains("output-body"));
    const stdinIdx = kids.findIndex((node) => node.classList.contains("stdin-row"));
    expect(bodyIdx).toBeGreaterThanOrEqual(0);
    expect(stdinIdx).toBe(bodyIdx + 1);
  });
});

function swipe(node: Element | null, from: number, to: number): void {
  expect(node).toBeInstanceOf(HTMLElement);
  if (!(node instanceof HTMLElement)) {
    return;
  }
  node.dispatchEvent(new PointerEvent("pointerdown", { clientY: from, bubbles: true }));
  node.dispatchEvent(new PointerEvent("pointerup", { clientY: to, bubbles: true }));
}
