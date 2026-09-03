/**
 * @vitest-environment happy-dom
 */
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { dismissFilesFolderTip, FILES_FOLDER_TIP, resetOnboardingForTests } from "../src/domain/onboarding";
import { LocalCWorkspace } from "../src/domain/workspace";
import { renderFilesBrowser } from "../src/ui/screens/files";

describe("files folder tip", () => {
  beforeEach(() => {
    document.body.replaceChildren();
    resetOnboardingForTests();
  });

  afterEach(() => {
    document.body.replaceChildren();
    resetOnboardingForTests();
  });

  it("shows a dismissible tip on the open files page", async () => {
    const workspace = new LocalCWorkspace();
    await workspace.load();
    const screen = renderFilesBrowser(workspace, "open", {
      back: () => undefined,
      selectFile: () => undefined,
      enterFolder: () => undefined,
      deleteFile: () => undefined,
      deleteFolder: () => undefined,
    });
    document.body.append(screen);

    const tip = screen.querySelector("[data-folder-tip]");
    expect(tip).toBeInstanceOf(HTMLElement);
    expect(screen.querySelector(".folder-tip-text")?.textContent).toBe(FILES_FOLDER_TIP);
    const close = screen.querySelector('[aria-label="Dismiss"]');
    expect(close).toBeInstanceOf(HTMLButtonElement);
    expect(screen.querySelector('[aria-label="Back"]')).toBeInstanceOf(HTMLButtonElement);
    expect(screen.querySelector('[aria-label="Create"]')).toBeInstanceOf(HTMLButtonElement);

    (close as HTMLButtonElement).click();
    expect(screen.querySelector("[data-folder-tip]")).toBeNull();

    const again = renderFilesBrowser(workspace, "open", {
      back: () => undefined,
      selectFile: () => undefined,
      enterFolder: () => undefined,
      deleteFile: () => undefined,
      deleteFolder: () => undefined,
    });
    expect(again.querySelector("[data-folder-tip]")).toBeNull();
  });

  it("does not show the tip on delete", async () => {
    const workspace = new LocalCWorkspace();
    await workspace.load();
    const screen = renderFilesBrowser(workspace, "delete", {
      back: () => undefined,
      selectFile: () => undefined,
      enterFolder: () => undefined,
      deleteFile: () => undefined,
      deleteFolder: () => undefined,
    });
    expect(screen.querySelector("[data-folder-tip]")).toBeNull();
  });

  it("stays until the close button is tapped", async () => {
    dismissFilesFolderTip();
    resetOnboardingForTests();
    const workspace = new LocalCWorkspace();
    await workspace.load();
    const screen = renderFilesBrowser(workspace, "open", {
      back: () => undefined,
      selectFile: () => undefined,
      enterFolder: () => undefined,
      deleteFile: () => undefined,
      deleteFolder: () => undefined,
    });
    document.body.append(screen);
    const bubble = screen.querySelector(".folder-tip");
    expect(bubble).toBeInstanceOf(HTMLElement);
    (bubble as HTMLElement).click();
    expect(screen.querySelector("[data-folder-tip]")).toBeInstanceOf(HTMLElement);
  });
});
