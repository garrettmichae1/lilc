import {
  applyColorWay,
  loadColorWay,
  loadSyntaxColoring,
  saveColorWay,
  saveSyntaxColoring,
  type ColorWay,
} from "../domain/appearance";
import { completeOnboarding, needsOnboarding } from "../domain/onboarding";
import type { LocalCFolder } from "../domain/files";
import type { LocalCWorkspace } from "../domain/workspace";
import { el } from "./dom";
import { EditorScreen } from "./screens/editor";
import { renderFilesBrowser } from "./screens/files";
import { renderHome } from "./screens/home";
import { renderLearn } from "./screens/learn";
import { renderOnboarding } from "./screens/onboarding";
import { QuizScreen } from "./screens/quiz";
import { renderSettings } from "./screens/settings";
import { quizById, type CQuiz } from "../domain/quizzes";

export type AppScreen = "home" | "learn" | "files" | "delete" | "settings" | "editor" | "quiz";
type HubScreen = "home" | "learn";

export class App {
  private screen: AppScreen = "home";
  private colorWay: ColorWay = loadColorWay();
  private syntaxColoring = loadSyntaxColoring();
  private editor: EditorScreen | undefined;
  private quiz: QuizScreen | undefined;
  private quizId = "";
  private quizReview = false;
  private editorReturn: HubScreen = "home";
  private filesReturn: HubScreen = "home";
  private showOnboarding = needsOnboarding();
  private readonly shell = el("div", { className: "app-shell screen" });

  constructor(
    private readonly host: HTMLElement,
    private readonly workspace: LocalCWorkspace,
  ) {
    applyColorWay(this.colorWay);
    this.host.replaceChildren(this.shell);
    this.workspace.subscribe(() => {
      if (this.screen !== "editor" && this.screen !== "quiz") {
        this.render();
      }
    });
    this.bindKeyboardChrome();
    this.render();
  }

  private render(): void {
    const next = this.view();
    const children: HTMLElement[] = [next];
    if (this.showOnboarding) {
      children.push(
        renderOnboarding(() => {
          completeOnboarding();
          this.showOnboarding = false;
          this.render();
        }),
      );
    }
    this.shell.replaceChildren(...children);
  }

  private view(): HTMLElement {
    switch (this.screen) {
      case "home":
        return renderHome(this.workspace, this.homeActions());
      case "learn":
        return renderLearn(this.workspace, this.learnActions());
      case "files":
        return renderFilesBrowser(this.workspace, "open", {
          back: () => {
            if (!this.workspace.goUpFromBrowse()) {
              this.screen = this.filesReturn;
            }
            this.render();
          },
          selectFile: (file) => {
            this.workspace.select(file);
            this.showEditor("home");
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
        return renderSettings(this.workspace, this.colorWay, this.syntaxColoring, {
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
          setSyntaxColoring: (on) => {
            this.syntaxColoring = on;
            saveSyntaxColoring(on);
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
            this.screen = this.editorReturn;
            this.editor = undefined;
            this.render();
          }, this.syntaxColoring);
        }
        return this.editor.root;
      case "quiz": {
        const catalogQuiz = quizById(this.quizId);
        if (!catalogQuiz) {
          this.screen = "learn";
          this.quiz = undefined;
          return renderLearn(this.workspace, this.learnActions());
        }
        if (!this.quiz) {
          this.quiz = new QuizScreen(catalogQuiz, this.quizReview, () => {
            this.screen = "learn";
            this.quiz = undefined;
            this.render();
          });
        }
        return this.quiz.root;
      }
    }
  }

  private homeActions(): {
    openEditor: () => void;
    createFile: () => void;
    openFiles: () => void;
    openLearn: () => void;
    openDelete: () => void;
    openSettings: () => void;
    openProject: (folder: LocalCFolder) => void;
  } {
    return {
      openEditor: () => {
        this.workspace.browsePath = this.workspace.currentProjectPath;
        this.showEditor("home");
      },
      createFile: () => {
        this.workspace.createStandaloneFile();
        this.showEditor("home");
      },
      openFiles: () => {
        this.filesReturn = "home";
        this.workspace.browsePath = "";
        this.screen = "files";
        this.render();
      },
      openLearn: () => {
        this.screen = "learn";
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
        this.showEditor("home");
      },
    };
  }

  private learnActions(): {
    openHome: () => void;
    openFiles: () => void;
    openEditor: () => void;
    openQuiz: (quiz: CQuiz, review: boolean) => void;
  } {
    return {
      openHome: () => {
        this.screen = "home";
        this.render();
      },
      openFiles: () => {
        this.filesReturn = "learn";
        this.workspace.browsePath = "";
        this.screen = "files";
        this.render();
      },
      openEditor: () => {
        this.showEditor("learn");
      },
      openQuiz: (quiz, review) => {
        this.quizId = quiz.id;
        this.quizReview = review;
        this.quiz = undefined;
        this.screen = "quiz";
        this.render();
      },
    };
  }

  private showEditor(returnTo: HubScreen): void {
    this.editorReturn = returnTo;
    this.screen = "editor";
    this.editor = new EditorScreen(this.workspace, () => {
      this.screen = this.editorReturn;
      this.editor = undefined;
      this.render();
    }, this.syntaxColoring);
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
