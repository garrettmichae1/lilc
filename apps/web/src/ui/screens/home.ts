import { fileName, type LocalCFolder } from "../../domain/files";
import type { LocalCWorkspace } from "../../domain/workspace";
import { chevron, folderMark, logoImg, mainTabBar } from "../components/chrome";
import { el } from "../dom";

export function renderHome(
  workspace: LocalCWorkspace,
  actions: {
    openEditor: () => void;
    createFile: () => void;
    openFiles: () => void;
    openLearn: () => void;
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
            className: "pad home-stack",
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
              projects(workspace, actions),
              actionsCard(actions),
            ],
          }),
        ],
      }),
      mainTabBar({
        active: "home",
        openHome: () => undefined,
        openLearn: actions.openLearn,
        openFiles: actions.openFiles,
      }),
    ],
  });
}

function projects(
  workspace: LocalCWorkspace,
  actions: { openProject: (folder: LocalCFolder) => void; openFiles: () => void },
): HTMLElement {
  return el("div", {
    className: "home-projects",
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
