import { allLessons, lessonForPath, lessonKicker, lessonRelativePath } from "../../domain/curriculum";
import { fileName } from "../../domain/files";
import { formatC, indentSelection } from "../../domain/indent";
import { encodeShareHash, playgroundURL, type SharePayload } from "../../domain/share";
import { findMatches, offsetOfLine } from "../../domain/search";
import { tokenizeC } from "../../domain/syntax";
import type { LocalCWorkspace } from "../../domain/workspace";
import { el, icons, svgIcon } from "../dom";

const SYMBOLS = ["{", "}", "(", ")", ";", "*", "&"] as const;

export const NICE_DELAY_MS = 2400;

/** Full-screen OUTPUT for the whole live run. Swipe cannot collapse it. */
export function nextOutputChromeExpanded(
  _translationY: number,
  isRunning: boolean,
  _currentlyExpanded: boolean,
): boolean {
  return isRunning;
}

export function renderEditor(
  workspace: LocalCWorkspace,
  actions: { back: () => void },
  options: { syntaxColoring?: boolean } = {},
): HTMLElement {
  const syntaxColoring = options.syntaxColoring === true;
  const screen = el("div", { className: "screen" });
  const editor = el("textarea", {
    className: "editor",
    attrs: {
      spellcheck: "false",
      autocapitalize: "off",
      autocomplete: "off",
      autocorrect: "off",
      enterkeyhint: "enter",
      "aria-label": "C source",
    },
  });
  editor.readOnly = false;
  editor.disabled = false;
  editor.value = workspace.currentFile.code;

  let draftName = fileName(workspace.currentFile);
  let findVisible = false;
  let findQuery = "";
  let findIndex = 0;
  let editorFocused = false;
  let outputExpanded = true;
  let outputChromeExpanded = false;
  let lastFileID = workspace.selectedFileID;
  let applyingBoundText = false;
  let niceVisible = false;
  let handledToken = 0;
  let advanceTimer: ReturnType<typeof setTimeout> | undefined;
  let createOverlay: HTMLElement | undefined;

  editor.addEventListener("input", () => {
    if (applyingBoundText) {
      return;
    }
    workspace.updateCurrentCode(editor.value);
    paintHighlight();
    syncHighlightScroll();
  });
  editor.addEventListener("scroll", () => {
    syncHighlightScroll();
  });
  editor.addEventListener("focus", () => {
    setEditorFocused(true);
  });
  editor.addEventListener("blur", () => {
    queueMicrotask(() => {
      setEditorFocused(document.activeElement === editor);
    });
  });
  editor.addEventListener("keydown", (event) => {
    if (event.key === "Tab") {
      event.preventDefault();
      applyIndent(event.shiftKey);
    }
    if (event.key === "Escape" && findVisible) {
      closeFind();
    }
  });

  const nameField = el("input", {
    className: "field",
    attrs: {
      type: "text",
      placeholder: "hello.c",
      autocapitalize: "off",
      autocomplete: "off",
      autocorrect: "off",
      spellcheck: "false",
      "aria-label": "File name",
    },
  });
  nameField.addEventListener("change", commitName);
  nameField.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      commitName();
      nameField.blur();
    }
  });

  const findInput = el("input", {
    attrs: {
      type: "search",
      placeholder: "Find",
      autocapitalize: "off",
      autocomplete: "off",
      autocorrect: "off",
      spellcheck: "false",
      "aria-label": "Find in file",
    },
  });
  findInput.addEventListener("input", () => {
    findQuery = findInput.value;
    findIndex = 0;
    revealFind();
    paint();
  });
  findInput.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      stepFind(event.shiftKey ? -1 : 1);
    }
  });

  const stdinField = el("input", {
    className: "field",
    attrs: {
      type: "text",
      autocapitalize: "off",
      autocomplete: "off",
      autocorrect: "off",
      spellcheck: "false",
      "aria-label": "Program input",
    },
  });
  stdinField.addEventListener("input", () => {
    workspace.stdinLine = stdinField.value;
  });
  stdinField.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      submitStdin();
    }
  });

  const chrome = el("div", { className: "screen", attrs: { style: "min-height:0;flex:1", "data-editor-chrome": "" } });
  const topSlot = el("div");
  const tabsSlot = el("div");
  const nameSlot = el("div");
  const lessonSlot = el("div");
  const editorHost = el("div", { className: "editor-wrap", attrs: { "data-editor-host": "" } });
  const findSlot = el("div");
  const highlight = el("pre", {
    className: "editor-highlight",
    attrs: { "aria-hidden": "true", "data-editor-highlight": "" },
  });
  const outputSlot = el("div", { attrs: { "data-output-slot": "" } });
  const symbolSlot = el("div");
  editorHost.append(findSlot, highlight, editor);
  chrome.append(topSlot, tabsSlot, nameSlot, lessonSlot, editorHost, outputSlot, symbolSlot);
  screen.append(chrome);

  const setEditorFocused = (focused: boolean): void => {
    editorFocused = focused;
    const bar = symbolSlot.firstElementChild;
    if (bar) {
      bar.classList.toggle("visible", focused);
    }
  };

  const paintHighlight = (): void => {
    const source = editor.value;
    const matches = findVisible ? findMatches(source, findQuery) : [];
    const overlayOn = syntaxColoring || matches.length > 0;
    highlight.hidden = !overlayOn;
    editor.classList.toggle("overlay-on", overlayOn);
    if (!overlayOn) {
      highlight.replaceChildren();
      return;
    }
    const tokens = syntaxColoring ? tokenizeC(source) : [];
    const frag = document.createDocumentFragment();
    let cursor = 0;
    let tokenIndex = 0;
    while (cursor < source.length) {
      while (tokenIndex < tokens.length && (tokens[tokenIndex]?.end ?? 0) <= cursor) {
        tokenIndex += 1;
      }
      const token = tokens[tokenIndex];
      const inToken = token !== undefined && cursor >= token.start && cursor < token.end;
      let matchIndex = -1;
      for (let index = 0; index < matches.length; index += 1) {
        const match = matches[index];
        if (match && cursor >= match.start && cursor < match.start + match.length) {
          matchIndex = index;
          break;
        }
      }
      const tokenEnd = inToken && token ? token.end : (token?.start ?? source.length);
      const matchEnd =
        matchIndex >= 0
          ? (matches[matchIndex]?.start ?? 0) + (matches[matchIndex]?.length ?? 0)
          : (matches.find((match) => match.start > cursor)?.start ?? source.length);
      const end = Math.max(cursor + 1, Math.min(source.length, tokenEnd, matchEnd));
      const className = [
        inToken && token ? `tok-${token.kind}` : "",
        matchIndex >= 0 ? (matchIndex === findIndex ? "find-hit-current" : "find-hit") : "",
      ]
        .filter(Boolean)
        .join(" ");
      const text = source.slice(cursor, end);
      if (className.length > 0) {
        const span = document.createElement("span");
        span.className = className;
        span.textContent = text;
        frag.append(span);
      } else {
        frag.append(text);
      }
      cursor = end;
    }
    frag.append("\n");
    highlight.replaceChildren(frag);
  };

  const syncHighlightScroll = (): void => {
    highlight.scrollTop = editor.scrollTop;
    highlight.scrollLeft = editor.scrollLeft;
  };

  const paint = (): void => {
    if (workspace.selectedFileID !== lastFileID) {
      lastFileID = workspace.selectedFileID;
      draftName = fileName(workspace.currentFile);
      editor.value = workspace.currentFile.code;
      findIndex = 0;
    } else if (document.activeElement !== editor && editor.value !== workspace.currentFile.code) {
      applyingBoundText = true;
      editor.value = workspace.currentFile.code;
      applyingBoundText = false;
    }

    nameField.value = draftName;
    findInput.value = findQuery;
    stdinField.value = workspace.stdinLine;
    stdinField.placeholder = workspace.isWaitingForInput ? "type input, then ENTER" : "program input";
    editor.classList.toggle("find-open", findVisible);
    editor.classList.toggle("syntax-on", syntaxColoring);
    highlight.classList.toggle("find-open", findVisible);
    paintHighlight();
    syncHighlightScroll();

    const matches = findMatches(editor.value, findQuery);
    const matchLabel = matches.length === 0 ? "0/0" : `${Math.min(findIndex + 1, matches.length)}/${matches.length}`;

    topSlot.replaceChildren(topBar());
    if (workspace.isRunning) {
      tabsSlot.replaceChildren();
      nameSlot.replaceChildren();
      lessonSlot.replaceChildren();
    } else {
      tabsSlot.replaceChildren(fileTabs());
      nameSlot.replaceChildren(nameRow());
      const rail = lessonRail();
      if (rail) {
        lessonSlot.replaceChildren(rail);
      } else {
        lessonSlot.replaceChildren();
      }
    }
    paintFindBar(matchLabel);
    if (workspace.isRunning) {
      outputExpanded = true;
      outputChromeExpanded = true;
    } else {
      outputChromeExpanded = false;
    }
    chrome.classList.toggle("editor-running", workspace.isRunning);
    chrome.classList.toggle(
      "output-chrome-expanded",
      outputChromeExpanded && outputExpanded,
    );
    outputSlot.replaceChildren(outputPane());
    symbolSlot.replaceChildren(symbolBar());
    paintCelebration();
    if (workspace.isWaitingForInput) {
      outputExpanded = true;
      queueMicrotask(() => stdinField.focus());
    }
  };

  const dismissCreate = (): void => {
    createOverlay?.remove();
    createOverlay = undefined;
  };

  const showCreate = (): void => {
    dismissCreate();
    workspace.browsePath = workspace.isCurriculumCatalog ? "" : workspace.currentProjectPath;
    createOverlay = el("div", {
      className: "sheet",
      on: {
        click: (event) => {
          if (event.target === createOverlay) {
            dismissCreate();
          }
        },
      },
      children: [
        el("div", {
          className: "sheet-card",
          children: [
            el("button", {
              attrs: { type: "button" },
              text: workspace.browsePath === "" ? "New standalone C file" : "New C file in this project",
              on: {
                click: () => {
                  workspace.createFile();
                  dismissCreate();
                  paint();
                },
              },
            }),
            el("button", {
              attrs: { type: "button" },
              text: "New Header",
              on: {
                click: () => {
                  workspace.createHeader();
                  dismissCreate();
                  paint();
                },
              },
            }),
            el("button", {
              attrs: { type: "button", style: "color:var(--silver)" },
              text: "Cancel",
              on: { click: dismissCreate },
            }),
          ],
        }),
      ],
    });
    screen.append(createOverlay);
  };

  const topBar = (): HTMLElement =>
    el("div", {
      className: "topbar",
      children: [
        el("button", {
          className: "icon-btn",
          attrs: { type: "button", "aria-label": "Back" },
          on: { click: actions.back },
          children: [svgIcon(icons.chevronLeft, 16)],
        }),
        el("div", {
          className: "title",
          text: workspace.editorTitle,
        }),
        el("span", { attrs: { style: "flex:1" } }),
        el("button", {
          className: "icon-btn",
          attrs: { type: "button", "aria-label": "New file", style: "color:var(--accent)" },
          on: {
            click: showCreate,
          },
          children: [svgIcon(icons.plus, 14)],
        }),
        el("button", {
          className: "icon-btn",
          attrs: { type: "button", "aria-label": "Find", "aria-pressed": findVisible ? "true" : "false" },
          on: { click: toggleFind },
          children: [svgIcon(icons.search, 14)],
        }),
        el("button", {
          className: "icon-btn",
          attrs: { type: "button", "aria-label": "Share" },
          on: { click: shareFile },
          children: [svgIcon(icons.share, 14)],
        }),
        el("button", {
          className: "format-btn",
          attrs: { type: "button", "aria-label": "Format code" },
          text: "FMT",
          on: { click: formatBuffer },
        }),
        workspace.isRunning
          ? el("button", {
              className: "run-btn stop",
              attrs: { type: "button" },
              text: "STOP",
              on: { click: () => workspace.stopLiveRun() },
            })
          : el("button", {
              className: "run-btn",
              attrs: { type: "button" },
              text: "RUN",
              on: { click: run },
            }),
      ],
    });

  const fileTabs = (): HTMLElement =>
    el("div", {
      className: "file-tabs",
      children: workspace.projectFiles.map((file) =>
        el("button", {
          className: file.relativePath === workspace.selectedFileID ? "file-tab active" : "file-tab",
          attrs: { type: "button" },
          text: fileName(file),
          on: {
            click: () => {
              commitName();
              workspace.select(file);
              paint();
            },
          },
        }),
      ),
    });

  const nameRow = (): HTMLElement =>
    el("div", {
      className: "name-row",
      children: [
        nameField,
        el("button", {
          className: "icon-btn accent",
          attrs: { type: "button", "aria-label": "Save file name" },
          on: { click: commitName },
          children: [svgIcon(icons.check, 13)],
        }),
      ],
    });

  const paintFindBar = (matchLabel: string): void => {
    if (!findVisible) {
      findSlot.replaceChildren();
      return;
    }
    findSlot.replaceChildren(
      el("div", {
        className: "find-bar",
        children: [
          findInput,
          el("span", { className: "muted mono", attrs: { style: "font-size:11px" }, text: matchLabel }),
          el("button", {
            className: "icon-btn",
            attrs: { type: "button", "aria-label": "Previous match" },
            text: "↑",
            on: { click: () => stepFind(-1) },
          }),
          el("button", {
            className: "icon-btn",
            attrs: { type: "button", "aria-label": "Next match" },
            text: "↓",
            on: { click: () => stepFind(1) },
          }),
          el("button", {
            className: "icon-btn",
            attrs: { type: "button", "aria-label": "Close find" },
            on: { click: closeFind },
            children: [svgIcon(icons.x, 14)],
          }),
        ],
      }),
    );
  };

  const lessonRail = (): HTMLElement | undefined => {
    const lesson = lessonForPath(workspace.currentFile.relativePath);
    if (!lesson) {
      return undefined;
    }
    return el("div", {
      className: "lesson-rail",
      children: [
        el("div", {
          className: "lesson-rail-copy",
          children: [
            el("div", {
              className: "lesson-kicker",
              text: lessonKicker(lesson),
            }),
            el("div", { className: "lesson-goal", text: lesson.goal }),
          ],
        }),
        niceVisible
          ? el("span", {
              className: "lesson-nice",
              attrs: { "aria-live": "polite" },
              text: "Nice.",
            })
          : undefined,
      ],
    });
  };

  const paintCelebration = (): void => {
    screen.querySelector("[data-celebrate]")?.remove();
  };

  const outputPane = (): HTMLElement => {
    const failed = workspace.lastRunFailed;
    const waiting = workspace.isWaitingForInput;
    const status = waiting
      ? badge("WAITING FOR INPUT", "var(--amber)", true)
      : workspace.isRunning
        ? badge("RUNNING", "var(--accent)", false)
        : workspace.lastRunNeedsFillIn
          ? workspace.lastErrorJump
            ? el("button", {
                attrs: { type: "button", "aria-label": "Jump to the blank" },
                on: { click: jumpToError },
                children: [badge("TODO", "var(--amber)", false)],
              })
            : badge("TODO", "var(--amber)", false)
          : failed
            ? workspace.lastErrorJump
              ? el("button", {
                  attrs: { type: "button", "aria-label": "Jump to error" },
                  on: { click: jumpToError },
                  children: [badge("ERROR", "var(--error)", false)],
                })
              : badge("ERROR", "var(--error)", false)
            : undefined;

    const body = el("div", {
      className: workspace.lastErrorJump ? "output-body clickable" : "output-body",
      text: workspace.output.length === 0 ? " " : workspace.output,
    });
    if (workspace.lastErrorJump) {
      body.addEventListener("click", jumpToError);
    }

    const swipeHandle = el("div", {
      className: "output-swipe",
      attrs: {
        "data-output-swipe": "",
        role: "presentation",
        "aria-label": workspace.isRunning
          ? "Output. Full screen until the program ends"
          : "Output",
      },
      children: [
        el("div", {
          className: "mono",
          attrs: { style: "font-size:11px;font-weight:700;color:var(--accent)" },
          text: "OUTPUT",
        }),
        status,
      ],
    });
    bindOutputSwipe(swipeHandle);

    return el("div", {
      className: workspace.isRunning ? "output-pane running" : "output-pane",
      children: [
        el("div", {
          className: "row-between",
          children: [
            swipeHandle,
            el("button", {
              className: "link-btn",
              attrs: { type: "button", style: "color:var(--silver);font-size:10px;font-family:ui-monospace,monospace" },
              on: {
                click: () => {
                  if (workspace.isRunning) {
                    return;
                  }
                  outputExpanded = !outputExpanded;
                  paint();
                },
              },
              children: [
                el("span", { text: outputExpanded ? "HIDE " : "SHOW " }),
                svgIcon(outputExpanded ? icons.chevronDown : icons.chevronUp, 10),
              ],
            }),
          ],
        }),
        outputExpanded ? body : undefined,
        outputExpanded && workspace.engineNote
          ? el("div", {
              className: "muted mono",
              attrs: { style: "font-size:11px;margin-top:8px" },
              text: workspace.engineNote,
            })
          : undefined,
        outputExpanded && workspace.isRunning ? stdinRow() : undefined,
      ],
    });
  };

  function bindOutputSwipe(handle: HTMLElement): void {
    let startY = 0;
    handle.addEventListener("pointerdown", (event) => {
      startY = event.clientY;
    });
    handle.addEventListener("pointerup", (event) => {
      applyOutputSwipe(event.clientY - startY);
    });
  }

  function applyOutputSwipe(translationY: number): void {
    const next = nextOutputChromeExpanded(translationY, workspace.isRunning, outputChromeExpanded);
    if (next === outputChromeExpanded) {
      return;
    }
    outputChromeExpanded = next;
    if (next) {
      outputExpanded = true;
    }
    paint();
  }

  const stdinRow = (): HTMLElement =>
    el("div", {
      className: waitingClass(),
      children: [
        el("span", {
          className: "mono",
          attrs: { style: `font-weight:700;color:${workspace.isWaitingForInput ? "var(--amber)" : "var(--silver)"}` },
          text: ">",
        }),
        stdinField,
        el("button", {
          className: "run-btn",
          attrs: { type: "button", style: "height:30px;padding:0 10px;font-size:11px" },
          text: "ENTER",
          on: { click: submitStdin },
        }),
        el("button", {
          className: "link-btn",
          attrs: { type: "button", style: "color:var(--silver);font-size:11px;font-family:ui-monospace,monospace" },
          text: "EOF",
          on: { click: () => workspace.sendStdinEOF() },
        }),
      ],
    });

  const waitingClass = (): string =>
    workspace.isWaitingForInput ? "stdin-row waiting" : "stdin-row";

  const symbolBar = (): HTMLElement =>
    el("div", {
      className: editorFocused ? "symbol-bar visible" : "symbol-bar",
      attrs: { "aria-label": "C symbols", "data-symbol-bar": "" },
      children: [
        ...SYMBOLS.map((symbol) =>
          el("button", {
            attrs: { type: "button", "aria-label": symbol },
            text: symbol,
            on: { click: () => insertText(symbol) },
          }),
        ),
        el("button", {
          className: "indent",
          attrs: { type: "button", "aria-label": "Indent" },
          text: "⇥",
          on: { click: () => applyIndent(false) },
        }),
        el("button", {
          className: "indent",
          attrs: { type: "button", "aria-label": "Outdent" },
          text: "⇤",
          on: { click: () => applyIndent(true) },
        }),
        el("button", {
          className: "indent",
          attrs: { type: "button", "aria-label": "Format code" },
          text: "FMT",
          on: { click: formatBuffer },
        }),
        el("button", {
          className: "indent",
          attrs: { type: "button", "aria-label": "Hide keyboard" },
          on: { click: hideKeyboard },
          children: [svgIcon(icons.keyboard, 16)],
        }),
      ],
    });

  function badge(text: string, color: string, pulse: boolean): HTMLElement {
    return el("span", {
      className: pulse ? "badge pulse" : "badge",
      attrs: { style: `color:${color};background:color-mix(in srgb, ${color} 18%, transparent)` },
      children: [el("span", { className: "dot" }), el("span", { text })],
    });
  }

  function commitName(): void {
    draftName = nameField.value;
    workspace.renameCurrentFile(draftName);
    draftName = fileName(workspace.currentFile);
    nameField.value = draftName;
    paint();
  }

  function run(): void {
    hideKeyboard();
    commitName();
    outputExpanded = true;
    outputChromeExpanded = true;
    void workspace.runCurrentFile();
  }

  function submitStdin(): void {
    workspace.stdinLine = stdinField.value;
    workspace.submitStdinLine();
    stdinField.value = "";
    stdinField.focus();
    paint();
  }

  function insertText(value: string): void {
    editor.focus();
    const start = editor.selectionStart;
    const end = editor.selectionEnd;
    editor.setRangeText(value, start, end, "end");
    workspace.updateCurrentCode(editor.value);
    paintHighlight();
    syncHighlightScroll();
    editor.focus();
  }

  function applyIndent(outdent: boolean): void {
    const next = indentSelection(editor.value, { start: editor.selectionStart, end: editor.selectionEnd }, outdent);
    editor.value = next.text;
    editor.setSelectionRange(next.range.start, next.range.end);
    workspace.updateCurrentCode(editor.value);
    paintHighlight();
    syncHighlightScroll();
    editor.focus();
  }

  function formatBuffer(): void {
    const caret = editor.selectionStart;
    const formatted = formatC(editor.value);
    if (formatted === editor.value) {
      editor.focus();
      return;
    }
    editor.value = formatted;
    const nextCaret = Math.min(caret, formatted.length);
    editor.setSelectionRange(nextCaret, nextCaret);
    workspace.updateCurrentCode(editor.value);
    paintHighlight();
    syncHighlightScroll();
    editor.focus();
  }

  function hideKeyboard(): void {
    editor.blur();
    nameField.blur();
    findInput.blur();
    stdinField.blur();
    editorFocused = false;
    paint();
  }

  function toggleFind(): void {
    if (findVisible) {
      closeFind();
    } else {
      findVisible = true;
      paint();
      findInput.focus();
    }
  }

  function closeFind(): void {
    findVisible = false;
    findQuery = "";
    findIndex = 0;
    paint();
  }

  function stepFind(delta: number): void {
    const matches = findMatches(editor.value, findQuery);
    if (matches.length === 0) {
      return;
    }
    findIndex = (findIndex + delta + matches.length) % matches.length;
    revealFind();
    paint();
  }

  function revealFind(): void {
    const matches = findMatches(editor.value, findQuery);
    const match = matches[findIndex];
    if (!match) {
      return;
    }
    editor.focus();
    editor.setSelectionRange(match.start, match.start + match.length);
  }

  function jumpToError(): void {
    const jump = workspace.revealErrorJump();
    if (!jump) {
      return;
    }
    paint();
    const range = offsetOfLine(editor.value, jump.line, jump.column);
    editor.focus();
    editor.setSelectionRange(range.start, Math.max(range.start, Math.min(range.end, editor.value.length)));
  }

  async function shareFile(): Promise<void> {
    const payload = sharePayload();
    const url = playgroundURL(payload, `${location.origin}${location.pathname}`);
    try {
      history.replaceState(null, "", encodeShareHash(payload));
    } catch {
      location.hash = encodeShareHash(payload);
    }
    try {
      if (navigator.share) {
        await navigator.share({
          title: "lilC",
          text: "Run this C program in the browser. No account.",
          url,
        });
        return;
      }
    } catch {
      /* user cancelled or share failed; copy instead */
    }
    try {
      await navigator.clipboard.writeText(url);
      workspace.output = "Copied a playground link. Anyone can open it — no account.";
      paint();
    } catch {
      workspace.output = url;
      paint();
    }
  }

  function sharePayload(): SharePayload {
    const file = workspace.currentFile;
    const lesson = allLessons.find(
      (item) => file.relativePath === lessonRelativePath(item) && file.code === item.source,
    );
    if (lesson) {
      return { kind: "lesson", id: lesson.id };
    }
    return { kind: "source", fileName: fileName(file), code: file.code };
  }

  const unsubscribe = workspace.subscribe(() => {
    if (!screen.isConnected) {
      if (advanceTimer !== undefined) {
        clearTimeout(advanceTimer);
        advanceTimer = undefined;
      }
      unsubscribe();
      return;
    }
    const outcome = workspace.lessonOutcome;
    if (outcome && outcome.token !== handledToken) {
      handledToken = outcome.token;
      if (advanceTimer !== undefined) {
        clearTimeout(advanceTimer);
        advanceTimer = undefined;
      }
      niceVisible = outcome.status === "passed";
      if (outcome.status === "passed" && !outcome.replay) {
        advanceTimer = setTimeout(() => {
          advanceTimer = undefined;
          niceVisible = false;
          const result = workspace.advanceAfterPass();
          if (result === "celebrate") {
            actions.back();
            return;
          }
          paint();
        }, NICE_DELAY_MS);
      } else if (outcome.status === "passed" && outcome.replay) {
        advanceTimer = setTimeout(() => {
          advanceTimer = undefined;
          niceVisible = false;
          paint();
        }, NICE_DELAY_MS);
      }
    }
    if (
      document.activeElement === editor &&
      !workspace.isRunning &&
      !workspace.isWaitingForInput &&
      workspace.selectedFileID === lastFileID &&
      !niceVisible
    ) {
      return;
    }
    paint();
  });

  paint();
  return screen;
}

export class EditorScreen {
  readonly root: HTMLElement;

  constructor(workspace: LocalCWorkspace, back: () => void, syntaxColoring = false) {
    this.root = renderEditor(workspace, { back }, { syntaxColoring });
  }
}
