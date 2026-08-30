import {
  continueLesson,
  firstHourCurriculum,
  firstLesson,
  type FirstHourLesson,
} from "../../domain/curriculum";
import { fileName, type LocalCFolder } from "../../domain/files";
import { hourComplete, isLessonComplete, loadProgress } from "../../domain/progress";
import type { LocalCWorkspace } from "../../domain/workspace";
import { chevron, folderMark, homeTabIcon, hourMeter, logoImg } from "../components/chrome";
import { el, icons, svgIcon } from "../dom";

export function renderHome(
  workspace: LocalCWorkspace,
  actions: {
    openEditor: () => void;
    createFile: () => void;
    openFiles: () => void;
    openDelete: () => void;
    openSettings: () => void;
    openProject: (folder: LocalCFolder) => void;
  },
): HTMLElement {
  return el("div", {
    className: "screen",
    children: [
      el("div", {
        className: "scroll",
        children: [
          el("div", {
            className: "pad",
            children: [
              el("div", {
                className: "home-header",
                children: [
                  logoImg(),
                  el("span", { attrs: { style: "flex:1" } }),
                  el("button", {
                    className: "link-btn",
                    attrs: { type: "button" },
                    text: "Settings",
                    on: { click: actions.openSettings },
                  }),
                ],
              }),
              el("button", {
                className: "hero",
                attrs: { type: "button" },
                on: { click: actions.openEditor },
                children: [
                  el("div", {
                    children: [
                      el("div", { className: "name", text: "Open editor" }),
                      el("div", { className: "file", text: fileName(workspace.currentFile) }),
                    ],
                  }),
                  el("span", { attrs: { style: "margin-left:auto;opacity:0.8" }, children: [chevron()] }),
                ],
              }),
              startLessonButton(workspace, actions.openEditor),
              firstHour(workspace, actions.openEditor),
              projects(workspace, actions),
              actionsCard(actions),
            ],
          }),
        ],
      }),
      tabBar(actions.openFiles),
    ],
  });
}

function startLessonButton(workspace: LocalCWorkspace, openEditor: () => void): HTMLElement {
  const progress = loadProgress();
  const done = hourComplete(progress);
  const next = continueLesson(progress.completedIds);
  const title = done
    ? "Replay lesson 1"
    : progress.completedIds.length === 0
      ? "Start lesson 1"
      : `Continue · Lesson ${next.number}`;
  const lesson = done ? firstLesson() : next;
  return el("button", {
    className: "action-row",
    attrs: { type: "button", style: "background:var(--card);border-radius:14px" },
    on: {
      click: () => {
        workspace.openLesson(lesson);
        openEditor();
      },
    },
    children: [
      el("div", {
        children: [
          el("div", { className: "title-17", attrs: { style: "font-weight:600" }, text: title }),
          el("div", { className: "detail", text: lesson.goal }),
        ],
      }),
      el("span", { attrs: { style: "margin-left:auto;color:var(--silver)" }, children: [chevron()] }),
    ],
  });
}

function firstHour(workspace: LocalCWorkspace, openEditor: () => void): HTMLElement {
  const progress = loadProgress();
  const current = firstHourCurriculum.lessons[progress.currentIndex];
  return el("div", {
    children: [
      el("div", {
        className: "row-between",
        attrs: { style: "align-items:flex-end;margin-bottom:8px" },
        children: [
          el("div", { className: "section-label", attrs: { style: "margin:0" }, text: "First hour" }),
          hourMeter(progress, current?.id),
        ],
      }),
      progress.streak > 1
        ? el("div", {
            className: "muted",
            attrs: { style: "font-size:13px;margin-bottom:8px" },
            text: `${progress.streak}-day streak`,
          })
        : undefined,
      el("div", {
        className: "card",
        children: firstHourCurriculum.lessons.flatMap((lesson, index, list) => {
          const row = lessonRow(workspace, lesson, openEditor);
          if (index === list.length - 1) {
            return [row];
          }
          return [row, el("div", { className: "divider", attrs: { style: "margin-left:44px" } })];
        }),
      }),
    ],
  });
}

function lessonRow(
  workspace: LocalCWorkspace,
  lesson: FirstHourLesson,
  openEditor: () => void,
): HTMLButtonElement {
  const complete = isLessonComplete(lesson.id);
  return el("button", {
    className: "action-row",
    attrs: { type: "button" },
    on: {
      click: () => {
        workspace.openLesson(lesson);
        openEditor();
      },
    },
    children: [
      complete
        ? el("div", {
            className: "lesson-check",
            attrs: { "aria-label": "Complete" },
            children: [svgIcon(icons.check, 16)],
          })
        : el("div", {
            className: "mono",
            attrs: { style: "width:28px;color:var(--accent);font-weight:600;font-size:15px" },
            text: String(lesson.number),
          }),
      el("div", {
        attrs: { style: "min-width:0" },
        children: [
          el("div", { className: "title-17", text: lesson.title }),
          el("div", { className: "detail", text: lesson.goal }),
        ],
      }),
      el("span", { attrs: { style: "margin-left:auto;color:var(--silver);flex-shrink:0" }, children: [chevron()] }),
    ],
  });
}

function projects(
  workspace: LocalCWorkspace,
  actions: { openProject: (folder: LocalCFolder) => void; openFiles: () => void },
): HTMLElement {
  return el("div", {
    children: [
      el("div", {
        className: "row-between",
        children: [
          el("div", { className: "section-label", text: "Projects" }),
          el("button", {
            className: "link-btn",
            attrs: { type: "button" },
            text: "See all",
            on: { click: actions.openFiles },
          }),
        ],
      }),
      workspace.recentProjects.length === 0
        ? el("div", {
            className: "card",
            attrs: { style: "padding:16px" },
            children: [
              el("div", {
                className: "muted",
                text: "No projects yet. Create a folder in Files.",
              }),
            ],
          })
        : el("div", {
            className: "card",
            children: workspace.recentProjects.flatMap((folder, index, list) => {
              const row = el("button", {
                className: "project-row",
                attrs: { type: "button" },
                on: { click: () => actions.openProject(folder) },
                children: [
                  folderMark(),
                  el("div", {
                    children: [
                      el("div", { className: "title-17", attrs: { style: "font-weight:600" }, text: folder.relativePath.split("/").pop() ?? folder.relativePath }),
                      el("div", { className: "muted", attrs: { style: "font-size:13px;margin-top:4px" }, text: "Project" }),
                    ],
                  }),
                  el("span", { attrs: { style: "margin-left:auto;color:var(--silver)" }, children: [chevron()] }),
                ],
              });
              if (index === list.length - 1) {
                return [row];
              }
              return [row, el("div", { className: "divider", attrs: { style: "margin-left:54px" } })];
            }),
          }),
    ],
  });
}

function actionsCard(actions: {
  createFile: () => void;
  openFiles: () => void;
  openDelete: () => void;
}): HTMLElement {
  const newFile = actionRow("New file", "A single C file", false, actions.createFile);
  const open = actionRow("Open", "Files and projects", false, actions.openFiles);
  const del = actionRow("Delete", "File or folder", true, actions.openDelete);
  return el("div", {
    className: "card",
    children: [newFile, el("div", { className: "divider" }), open, el("div", { className: "divider" }), del],
  });
}

function actionRow(title: string, detail: string, destructive: boolean, onClick: () => void): HTMLButtonElement {
  return el("button", {
    className: "action-row",
    attrs: { type: "button" },
    on: { click: onClick },
    children: [
      el("div", {
        children: [
          el("div", { className: destructive ? "title-17 destructive" : "title-17", text: title }),
          el("div", { className: "detail", text: detail }),
        ],
      }),
      el("span", { attrs: { style: "margin-left:auto;color:var(--silver)" }, children: [chevron()] }),
    ],
  });
}

function tabBar(openFiles: () => void): HTMLElement {
  return el("nav", {
    className: "tabbar",
    attrs: { "aria-label": "Main" },
    children: [
      el("button", {
        className: "tab active",
        attrs: { type: "button", "aria-current": "page" },
        children: [homeTabIcon("home", true), el("span", { text: "HOME" })],
      }),
      el("button", {
        className: "tab",
        attrs: { type: "button" },
        on: { click: openFiles },
        children: [homeTabIcon("files", false), el("span", { text: "FILES" })],
      }),
    ],
  });
}
