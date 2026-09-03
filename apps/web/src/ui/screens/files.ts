import { dismissFilesFolderTip, FILES_FOLDER_TIP, needsFilesFolderTip } from "../../domain/onboarding";
import { fileName, type LocalCFile, type LocalCFolder } from "../../domain/files";
import type { LocalCWorkspace } from "../../domain/workspace";
import { confirmDialog, fileRow, folderRow, promptDialog } from "../components/chrome";
import { el, icons, svgIcon } from "../dom";

export function renderFilesBrowser(
  workspace: LocalCWorkspace,
  mode: "open" | "delete",
  actions: {
    back: () => void;
    selectFile: (file: LocalCFile) => void;
    enterFolder: (folder: LocalCFolder) => void;
    deleteFile: (file: LocalCFile) => void;
    deleteFolder: (folder: LocalCFolder) => void;
  },
): HTMLElement {
  const screen = el("div", { className: "screen" });
  let search = "";
  let overlay: HTMLElement | undefined;

  const paint = (): void => {
    const matches = workspace.searchBrowser(search);
    const heading = mode === "delete" ? "Delete" : workspace.browseTitle;
    const nodes: Node[] = [
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
            children: [
              el("div", { className: "title", text: heading }),
              workspace.browsePath
                ? el("div", {
                    className: "muted mono",
                    attrs: { style: "font-size:10px" },
                    text: workspace.browsePath,
                  })
                : undefined,
            ],
          }),
          el("span", { attrs: { style: "flex:1" } }),
          mode === "open"
            ? el("button", {
                className: "icon-btn",
                attrs: { type: "button", "aria-label": "Create" },
                on: { click: showCreate },
                children: [svgIcon(icons.plus, 15)],
              })
            : undefined,
        ],
      }),
    ];
    nodes.push(
      el("div", {
        className: "files-body",
        children: [
          searchBar(),
          mode === "delete"
            ? el("div", {
                className: "hint",
                text: "Open a folder to delete files inside it, or delete the folder to remove the whole project.",
              })
            : undefined,
          el("div", {
            className: "scroll file-list",
            children:
              matches.length === 0
                ? [
                    el("div", {
                      className: "empty",
                      children: [
                        el("div", {
                          className: "title-15",
                          text: mode === "delete" ? "Nothing here." : "No files found.",
                        }),
                        el("div", {
                          className: "muted mono",
                          attrs: { style: "font-size:12px;margin-top:10px" },
                          text:
                            mode === "delete"
                              ? "Loose files live at the top level. Projects are folders."
                              : "Tap + to create a C file, header, or project.",
                        }),
                      ],
                    }),
                  ]
                : matches.map((entry) => {
                    if (entry.kind === "folder") {
                      const row = folderRow(
                        entry.folder,
                        mode === "delete"
                          ? workspace.browsePath === ""
                            ? "Deletes this project if you choose DELETE"
                            : "Nested folder"
                          : workspace.browsePath === ""
                            ? "Project folder"
                            : "Folder in this project",
                        "OPEN",
                        () => actions.enterFolder(entry.folder),
                        mode === "delete"
                          ? () => askDeleteFolder(entry.folder)
                          : undefined,
                      );
                      if (mode === "open") {
                        bindFolderDrop(row, entry.folder);
                      }
                      return row;
                    }
                    const row = fileRow(
                      entry.file,
                      mode === "delete" ? "DELETE" : "OPEN",
                      () => {
                        if (mode === "delete") {
                          askDeleteFile(entry.file);
                        } else {
                          actions.selectFile(entry.file);
                        }
                      },
                      mode === "delete",
                    );
                    if (mode === "open") {
                      bindFileDrag(row, entry.file);
                    }
                    return row;
                  }),
          }),
        ],
      }),
    );
    if (mode === "open" && needsFilesFolderTip() && !overlay) {
      nodes.push(folderTip());
    }
    screen.replaceChildren(...nodes);
    if (overlay) {
      screen.append(overlay);
    }
  };

  const bindFileDrag = (row: HTMLElement, file: LocalCFile): void => {
    row.draggable = true;
    row.addEventListener("dragstart", (event) => {
      event.dataTransfer?.setData("text/plain", file.relativePath);
      event.dataTransfer?.setData("application/x-lilc-file", file.relativePath);
    });
  };

  const bindFolderDrop = (row: HTMLElement, folder: LocalCFolder): void => {
    row.addEventListener("dragover", (event) => {
      event.preventDefault();
      row.classList.add("drop-target");
    });
    row.addEventListener("dragleave", () => {
      row.classList.remove("drop-target");
    });
    row.addEventListener("drop", (event) => {
      event.preventDefault();
      row.classList.remove("drop-target");
      const path =
        event.dataTransfer?.getData("application/x-lilc-file") ||
        event.dataTransfer?.getData("text/plain") ||
        "";
      const file = workspace.files.find((item) => item.relativePath === path);
      if (file) {
        workspace.moveFile(file, folder.relativePath);
        paint();
      }
    });
  };

  const folderTip = (): HTMLElement =>
    el("div", {
      className: "folder-tip",
      attrs: { "data-folder-tip": "", role: "status" },
      children: [
        el("p", { className: "folder-tip-text", text: FILES_FOLDER_TIP }),
        el("button", {
          className: "folder-tip-close",
          attrs: { type: "button", "aria-label": "Dismiss" },
          on: {
            click: () => {
              dismissFilesFolderTip();
              paint();
            },
          },
          children: [svgIcon(icons.x, 12)],
        }),
      ],
    });

  const searchBar = (): HTMLElement => {
    const input = el("input", {
      attrs: {
        type: "search",
        placeholder: "Search files or folders",
        value: search,
        autocapitalize: "off",
        autocomplete: "off",
        autocorrect: "off",
        spellcheck: "false",
        "aria-label": "Search files or folders",
      },
    });
    input.addEventListener("input", () => {
      search = input.value;
      paint();
      const next = screen.querySelector("input");
      if (next instanceof HTMLInputElement) {
        next.focus();
        next.setSelectionRange(search.length, search.length);
      }
    });
    return el("div", {
      className: "search-bar",
      children: [
        el("span", {
          attrs: { style: "color:var(--accent);display:grid" },
          children: [svgIcon(icons.search, 14)],
        }),
        input,
        search
          ? el("button", {
              className: "icon-btn",
              attrs: { type: "button", "aria-label": "Clear search" },
              on: {
                click: () => {
                  search = "";
                  paint();
                },
              },
              children: [svgIcon(icons.x, 15)],
            })
          : undefined,
      ],
    });
  };

  const showCreate = (): void => {
    overlay = el("div", {
      className: "sheet",
      on: {
        click: (event) => {
          if (event.target === overlay) {
            overlay = undefined;
            paint();
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
                  overlay = undefined;
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
                  overlay = undefined;
                  paint();
                },
              },
            }),
            el("button", {
              attrs: { type: "button" },
              text: workspace.browsePath === "" ? "New Project" : "New Folder",
              on: {
                click: () => {
                  overlay = promptDialog({
                    title: workspace.browsePath === "" ? "New Project" : "New Folder",
                    message:
                      workspace.browsePath === ""
                        ? "A folder is a project. Open it to add more .c and .h files. Home → New File still creates a single file at the top level."
                        : "Nested folders stay inside this project.",
                    placeholder: workspace.browsePath === "" ? "project-name" : "folder-name",
                    onCreate: (value) => {
                      workspace.createFolder(value);
                      overlay = undefined;
                      paint();
                    },
                    onCancel: () => {
                      overlay = undefined;
                      paint();
                    },
                  });
                  paint();
                },
              },
            }),
            el("button", {
              attrs: { type: "button", style: "color:var(--silver)" },
              text: "Cancel",
              on: {
                click: () => {
                  overlay = undefined;
                  paint();
                },
              },
            }),
          ],
        }),
      ],
    });
    paint();
  };

  const askDeleteFile = (file: LocalCFile): void => {
    overlay = confirmDialog({
      title: `Delete ${fileName(file)}?`,
      message: `This permanently removes ${file.relativePath} from this browser.`,
      confirmLabel: "Delete",
      destructive: true,
      onConfirm: () => {
        actions.deleteFile(file);
        overlay = undefined;
        paint();
      },
      onCancel: () => {
        overlay = undefined;
        paint();
      },
    });
    paint();
  };

  const askDeleteFolder = (folder: LocalCFolder): void => {
    const count = workspace.fileCount(folder);
    overlay = confirmDialog({
      title: `Delete folder ${folder.relativePath.split("/").pop() ?? folder.relativePath}?`,
      message: `This permanently deletes the folder and ${count} file${count === 1 ? "" : "s"} inside it.`,
      confirmLabel: "Delete Folder",
      destructive: true,
      onConfirm: () => {
        actions.deleteFolder(folder);
        overlay = undefined;
        paint();
      },
      onCancel: () => {
        overlay = undefined;
        paint();
      },
    });
    paint();
  };

  paint();
  return screen;
}
