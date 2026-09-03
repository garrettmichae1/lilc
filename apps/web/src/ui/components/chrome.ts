import {
  codePreview,
  fileName,
  folderName,
  formatShortDate,
  isHeader,
  sizeText,
  type LocalCFile,
  type LocalCFolder,
} from "../../domain/files";
import {
  challengeLessons,
  firstHourLessons,
  type FirstHourLesson,
} from "../../domain/curriculum";
import type { FirstHourProgress } from "../../domain/progress";
import { el, icons, svgIcon } from "../dom";

export function trackMeter(
  lessons: readonly FirstHourLesson[],
  progress: FirstHourProgress,
  currentId: string | undefined,
  label: string,
): HTMLElement {
  const total = lessons.length;
  const done = lessons.filter((lesson) => progress.completedIds.includes(lesson.id)).length;
  return el("div", {
    className: "hour-meter",
    attrs: {
      role: "progressbar",
      "aria-label": label,
      "aria-valuemin": "0",
      "aria-valuemax": String(total),
      "aria-valuenow": String(done),
    },
    children: [
      el("div", {
        className: "lesson-pips",
        children: lessons.map((lesson) => {
          const complete = progress.completedIds.includes(lesson.id);
          const current = currentId !== undefined && lesson.id === currentId;
          return el("span", {
            className: complete ? "pip done" : current ? "pip current" : "pip",
            attrs: { title: lesson.title },
          });
        }),
      }),
      el("span", { className: "hour-count mono", text: `${done}/${total}` }),
    ],
  });
}

export function hourMeter(progress: FirstHourProgress, currentId: string | undefined): HTMLElement {
  return trackMeter(firstHourLessons, progress, currentId, "First hour");
}

export function challengeMeter(progress: FirstHourProgress, currentId: string | undefined): HTMLElement {
  return trackMeter(challengeLessons, progress, currentId, "Challenges");
}

export function logoImg(): HTMLImageElement {
  return el("img", {
    className: "logo",
    attrs: { src: "./logo.svg", alt: "lilC", height: "44" },
  });
}

export function chevron(): SVGSVGElement {
  return svgIcon(icons.chevronRight, 13);
}

export function homeTabIcon(kind: "home" | "learn" | "files", active: boolean): SVGSVGElement {
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("width", "22");
  svg.setAttribute("height", "20");
  svg.setAttribute("viewBox", "0 0 22 20");
  svg.setAttribute("aria-hidden", "true");
  const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
  path.setAttribute("fill", "none");
  path.setAttribute("stroke", "currentColor");
  path.setAttribute("stroke-width", "2");
  path.setAttribute("stroke-linecap", "square");
  path.setAttribute("stroke-linejoin", "miter");
  path.setAttribute(
    "d",
    kind === "home"
      ? "M3 11 L11 3 L19 11 M6 10 V17 H16 V10 M10 17 V13 H13 V17"
      : kind === "learn"
        ? "M4 5 L10 7 V17 L4 15 Z M18 5 L12 7 V17 L18 15 Z"
        : "M3 5 H8 L10 8 H19 V16 H3 Z M3 10 H19",
  );
  svg.append(path);
  svg.style.color = active ? "var(--accent)" : "var(--silver)";
  return svg;
}

export function mainTabBar(options: {
  active: "home" | "learn" | "files";
  openHome: () => void;
  openLearn: () => void;
  openFiles: () => void;
}): HTMLElement {
  const tab = (
    id: "home" | "learn" | "files",
    label: string,
    onClick: () => void,
  ): HTMLButtonElement => {
    const current = options.active === id;
    return el("button", {
      className: current ? "tab active" : "tab",
      attrs: { type: "button", "aria-current": current ? "page" : undefined },
      ...(current ? {} : { on: { click: onClick } }),
      children: [homeTabIcon(id, current), el("span", { text: label })],
    });
  };
  return el("nav", {
    className: "tabbar",
    attrs: { "aria-label": "Main" },
    children: [
      tab("home", "HOME", options.openHome),
      tab("files", "FILES", options.openFiles),
      tab("learn", "LEARN", options.openLearn),
    ],
  });
}

export function folderMark(): HTMLElement {
  const mark = el("div", { className: "folder-mark" });
  mark.append(svgIcon("M3 7h6l2 2h10v9H3z", 14));
  return mark;
}

export function fileRow(
  file: LocalCFile,
  actionTitle: string,
  onClick: () => void,
  destructive = false,
): HTMLButtonElement {
  return el("button", {
    className: "browser-card",
    attrs: { type: "button" },
    on: { click: onClick },
    children: [
      el("div", { className: "ext-mark", text: isHeader(file) ? ".h" : ".c" }),
      el("div", {
        children: [
          el("div", {
            className: "title-15",
            text: file.relativePath.includes("/") ? file.relativePath : fileName(file),
          }),
          el("div", {
            className: "muted mono",
            attrs: { style: "font-size:10px;font-weight:500;margin-top:5px" },
            text: `${formatShortDate(file.updatedAt)}  *  ${sizeText(file)}`,
          }),
          el("div", {
            className: "muted mono",
            attrs: { style: "font-size:11px;margin-top:5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:58vw" },
            text: codePreview(file),
          }),
        ],
      }),
      el("span", {
        className: destructive ? "action-chip danger" : "action-chip",
        text: actionTitle,
      }),
    ],
  });
}

export function folderRow(
  folder: LocalCFolder,
  subtitle: string,
  openTitle: string,
  onOpen: () => void,
  onDelete?: () => void,
): HTMLElement {
  const row = el("div", { className: "browser-card" });
  const open = el("button", {
    className: "row-between",
    attrs: { type: "button", style: "flex:1;min-width:0;padding:0;gap:12px" },
    on: { click: onOpen },
    children: [
      folderMark(),
      el("div", {
        attrs: { style: "min-width:0;text-align:left" },
        children: [
          el("div", { className: "title-15", text: folderName(folder) }),
          el("div", {
            className: "muted mono",
            attrs: { style: "font-size:10px;margin-top:5px" },
            text: `${folder.relativePath}  *  ${formatShortDate(folder.updatedAt)}`,
          }),
          el("div", {
            className: "muted mono",
            attrs: { style: "font-size:11px;margin-top:5px" },
            text: subtitle,
          }),
        ],
      }),
      el("span", { className: "action-chip", text: openTitle }),
    ],
  });
  row.append(open);
  if (onDelete) {
    row.append(
      el("button", {
        className: "action-chip danger",
        attrs: { type: "button" },
        text: "DELETE",
        on: { click: onDelete },
      }),
    );
  }
  return row;
}

export function confirmDialog(options: {
  title: string;
  message: string;
  confirmLabel: string;
  destructive?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}): HTMLElement {
  return el("div", {
    className: "dialog-backdrop",
    attrs: { role: "dialog", "aria-modal": "true" },
    children: [
      el("div", {
        className: "dialog",
        children: [
          el("h2", { text: options.title }),
          el("p", { text: options.message }),
          el("div", {
            className: "dialog-actions",
            children: [
              el("button", {
                className: "link-btn",
                attrs: { type: "button" },
                text: "Cancel",
                on: { click: options.onCancel },
              }),
              el("button", {
                className: "link-btn",
                attrs: {
                  type: "button",
                  style: options.destructive ? "color:var(--error)" : "",
                },
                text: options.confirmLabel,
                on: { click: options.onConfirm },
              }),
            ],
          }),
        ],
      }),
    ],
  });
}

export function promptDialog(options: {
  title: string;
  message: string;
  placeholder: string;
  onCreate: (value: string) => void;
  onCancel: () => void;
}): HTMLElement {
  const input = el("input", {
    className: "field",
    attrs: {
      type: "text",
      placeholder: options.placeholder,
      autocapitalize: "off",
      autocomplete: "off",
      autocorrect: "off",
      spellcheck: "false",
      style: "border:1px solid var(--line);border-radius:8px;padding:10px 12px;width:100%;margin:8px 0 16px",
    },
  });
  const submit = () => options.onCreate(input.value);
  input.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      submit();
    }
  });
  queueMicrotask(() => input.focus());
  return el("div", {
    className: "dialog-backdrop",
    attrs: { role: "dialog", "aria-modal": "true" },
    children: [
      el("div", {
        className: "dialog",
        children: [
          el("h2", { text: options.title }),
          el("p", { text: options.message }),
          input,
          el("div", {
            className: "dialog-actions",
            children: [
              el("button", {
                className: "link-btn",
                attrs: { type: "button" },
                text: "Cancel",
                on: { click: options.onCancel },
              }),
              el("button", {
                className: "link-btn",
                attrs: { type: "button" },
                text: "Create",
                on: { click: submit },
              }),
            ],
          }),
        ],
      }),
    ],
  });
}
