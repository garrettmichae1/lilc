import { applyColorWay, loadColorWay, saveColorWay, type ColorWay } from "../domain/appearance";
import type { LocalCWorkspace } from "../domain/workspace";
import { el } from "./dom";
import { EditorScreen } from "./screens/editor";
import { renderFilesBrowser } from "./screens/files";
import { renderHome } from "./screens/home";
import { renderSettings } from "./screens/settings";

export type AppScreen = "home" | "files" | "delete" | "settings" | "editor";

export class App {
  private screen: AppScreen = "home";
  private colorWay: ColorWay = loadColorWay();
  private editor: EditorScreen | undefined;
  private readonly shell = el("div", { className: "app-shell screen" });

  constructor(
    private readonly host: HTMLElement,
    private readonly workspace: LocalCWorkspace,
  ) {
    applyColorWay(this.colorWay);
    this.host.replaceChildren(this.shell);
    this.workspace.subscribe(() => {
      if (this.screen !== "editor") {
        this.render();
      }
    });
    this.bindKeyboardChrome();
    this.render();
  }

  private render(): void {
    const next = this.view();
    this.shell.replaceChildren(next);
  }

  private view(): HTMLElement {
    switch (this.screen) {
      case "home":
        return renderHome(this.workspace, {
          openEditor: () => {
            this.workspace.browsePath = this.workspace.currentProjectPath;
            this.openEditor();
          },
          createFile: () => {
            this.workspace.createStandaloneFile();
            this.openEditor();
          },
          openFiles: () => {
            this.workspace.browsePath = "";
            this.screen = "files";
            this.render();
          },
          openDelete: () => {
            this.workspace.browsePath = "";
            this.screen = "delete";
            this.render();
          },
          openSettings: () => {
            this.screen = "settings";
            this.render();
          },
          openProject: (folder) => {
            this.workspace.openProject(folder);
            this.openEditor();
          },
        });
      case "files":
        return renderFilesBrowser(this.workspace, "open", {
          back: () => {
            if (!this.workspace.goUpFromBrowse()) {
              this.screen = "home";
            }
            this.render();
          },
          selectFile: (file) => {
            this.workspace.select(file);
            this.openEditor();
          },
          enterFolder: (folder) => {
            this.workspace.enterFolder(folder);
            this.render();
          },
          deleteFile: () => undefined,
          deleteFolder: () => undefined,
        });
      case "delete":
        return renderFilesBrowser(this.workspace, "delete", {
          back: () => {
            if (!this.workspace.goUpFromBrowse()) {
              this.screen = "home";
            }
            this.render();
          },
          selectFile: () => undefined,
          enterFolder: (folder) => {
            this.workspace.enterFolder(folder);
            this.render();
          },
          deleteFile: (file) => {
            this.workspace.deleteFile(file);
            this.render();
          },
          deleteFolder: (folder) => {
            this.workspace.deleteFolder(folder);
            this.render();
          },
        });
      case "settings":
        return renderSettings(this.workspace, this.colorWay, {
          back: () => {
            this.screen = "home";
            this.render();
          },
          setColorWay: (way) => {
            this.colorWay = way;
            saveColorWay(way);
            applyColorWay(way);
            this.render();
          },
          eraseAll: () => {
            this.workspace.deleteAllFiles();
            this.render();
          },
        });
      case "editor":
        if (!this.editor) {
          this.editor = new EditorScreen(this.workspace, () => {
            this.screen = "home";
            this.render();
          });
        }
        return this.editor.root;
    }
  }

  private openEditor(): void {
    this.screen = "editor";
    if (!this.editor) {
      this.editor = new EditorScreen(this.workspace, () => {
        this.screen = "home";
        this.render();
      });
    }
    this.render();
  }

  private bindKeyboardChrome(): void {
    const update = (): void => {
      const keyboardUp = isKeyboardUp();
      const tools = this.shell.querySelector("[data-keyboard-tools]");
      const symbols = this.shell.querySelector("[data-symbol-bar]");
      tools?.classList.toggle("visible", keyboardUp || isCoarsePointer());
      symbols?.classList.toggle("visible", keyboardUp || isCoarsePointer() || document.activeElement?.classList.contains("editor") === true);
      const inset = keyboardInset();
      document.documentElement.style.setProperty("--keyboard-inset", `${inset}px`);
    };
    window.visualViewport?.addEventListener("resize", update);
    window.visualViewport?.addEventListener("scroll", update);
    document.addEventListener("focusin", update);
    document.addEventListener("focusout", () => {
      window.setTimeout(update, 50);
    });
    update();
  }
}

function isCoarsePointer(): boolean {
  return window.matchMedia("(pointer: coarse)").matches;
}

function keyboardInset(): number {
  const viewport = window.visualViewport;
  if (!viewport) {
    return 0;
  }
  return Math.max(0, window.innerHeight - viewport.height - viewport.offsetTop);
}

function isKeyboardUp(): boolean {
  return keyboardInset() > 80;
}
