/**
 * @vitest-environment happy-dom
 */
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { firstLesson, lessonById } from "../src/domain/curriculum";
import { resetProgressForTests } from "../src/domain/progress";
import { LocalCWorkspace } from "../src/domain/workspace";
import { renderEditor } from "../src/ui/screens/editor";

describe("web editor typing", () => {
  beforeEach(() => {
    document.body.replaceChildren();
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
});
