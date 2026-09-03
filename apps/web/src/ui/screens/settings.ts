import type { ColorWay } from "../../domain/appearance";
import { titleForColorWay } from "../../domain/appearance";
import { APP_VERSION, EXTRA_LEGAL_ROWS_VISIBLE, LegalURLs, LICENSES_BODY, PICO_C_EXPLANATION } from "../../domain/legal";
import type { LocalCWorkspace } from "../../domain/workspace";
import { confirmDialog } from "../components/chrome";
import { el, icons, svgIcon } from "../dom";

export function renderSettings(
  workspace: LocalCWorkspace,
  colorWay: ColorWay,
  syntaxColoring: boolean,
  actions: {
    back: () => void;
    setColorWay: (way: ColorWay) => void;
    setSyntaxColoring: (on: boolean) => void;
    eraseAll: () => void;
  },
): HTMLElement {
  const screen = el("div", { className: "screen" });
  let overlay: HTMLElement | undefined;
  let licensesOpen = false;

  const paint = (): void => {
    screen.replaceChildren(
      el("div", {
        className: "topbar",
        children: [
          el("button", {
            className: "icon-btn",
            attrs: { type: "button", "aria-label": "Back" },
            on: { click: actions.back },
            children: [svgIcon(icons.chevronLeft)],
          }),
          el("div", { className: "title", attrs: { style: "font-family:system-ui;font-weight:600;font-size:17px" }, text: "Settings" }),
        ],
      }),
      el("div", {
        className: "scroll settings-list",
        children: [
          section(
            "Appearance",
            [
              ...(["light", "dark"] as const).map((way) =>
                el("button", {
                  className: "settings-row",
                  attrs: { type: "button", "aria-pressed": way === colorWay ? "true" : "false" },
                  on: { click: () => actions.setColorWay(way) },
                  children: [
                    el("span", { text: titleForColorWay(way) }),
                    way === colorWay ? el("span", { className: "check", text: "✓", attrs: { "aria-hidden": "true" } }) : undefined,
                  ],
                }),
              ),
              el("button", {
                className: "settings-row",
                attrs: { type: "button", "aria-pressed": syntaxColoring ? "true" : "false" },
                on: { click: () => actions.setSyntaxColoring(!syntaxColoring) },
                children: [
                  el("span", { text: "Syntax Color" }),
                  el("span", { className: syntaxColoring ? "check" : "muted", text: syntaxColoring ? "On" : "Off" }),
                ],
              }),
            ],
            "lilC uses Light or Dark everywhere.",
          ),
          section("PicoC", [
            el("div", {
              className: "settings-row",
              attrs: { style: "display:block;white-space:pre-wrap;line-height:1.45" },
              text: PICO_C_EXPLANATION,
            }),
          ]),
          section(
            "Files",
            [
              el("div", {
                className: "settings-row",
                children: [
                  el("span", { text: "In This Browser" }),
                  el("span", { className: "muted", text: String(workspace.files.length) }),
                ],
              }),
              el("button", {
                className: "settings-row",
                attrs: { type: "button", style: "color:var(--error)" },
                text: "Erase All Files",
                on: {
                  click: () => {
                    overlay = confirmDialog({
                      title: "Erase All Files?",
                      message: "Removes every C file in this browser. A starter file is created.",
                      confirmLabel: "Erase All",
                      destructive: true,
                      onConfirm: () => {
                        actions.eraseAll();
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
            ],
            "Removes every C file in this browser. A starter file is created.",
          ),
          section(
            "Legal",
            [
              ...(EXTRA_LEGAL_ROWS_VISIBLE ? [linkRow("For teachers", LegalURLs.teachers)] : []),
              linkRow("Privacy Policy", LegalURLs.privacy),
              linkRow("Terms of Use", LegalURLs.terms),
              ...(EXTRA_LEGAL_ROWS_VISIBLE
                ? [
                    el("button", {
                      className: "settings-row",
                      attrs: { type: "button" },
                      on: {
                        click: () => {
                          licensesOpen = true;
                          paint();
                        },
                      },
                      children: [
                        el("span", { text: "Licenses" }),
                        el("span", { className: "muted", children: [svgIcon(icons.chevronRight, 14)] }),
                      ],
                    }),
                    linkRow("Email Support", LegalURLs.support),
                  ]
                : []),
            ],
            `Version ${APP_VERSION}`,
          ),
        ],
      }),
    );
    if (licensesOpen) {
      screen.append(licensesSheet(() => {
        licensesOpen = false;
        paint();
      }));
    }
    if (overlay) {
      screen.append(overlay);
    }
  };

  paint();
  return screen;
}

function section(title: string, rows: HTMLElement[], footer?: string): HTMLElement {
  return el("div", {
    children: [
      el("div", { className: "settings-heading", text: title }),
      el("div", { className: "settings-section", children: rows }),
      footer ? el("div", { className: "settings-footer", text: footer }) : undefined,
    ],
  });
}

function linkRow(title: string, href: string): HTMLAnchorElement {
  const row = el("a", {
    className: "settings-row",
    attrs: { href, target: href.startsWith("mailto:") ? undefined : "_blank", rel: "noopener noreferrer" },
    children: [
      el("span", { text: title }),
      el("span", { className: "muted", children: [svgIcon(icons.chevronRight, 14)] }),
    ],
  });
  return row;
}

function licensesSheet(onClose: () => void): HTMLElement {
  return el("div", {
    className: "dialog-backdrop",
    children: [
      el("div", {
        className: "dialog",
        attrs: { style: "max-height:80vh;overflow:auto;width:min(560px,100%)" },
        children: [
          el("div", {
            className: "row-between",
            children: [
              el("h2", { text: "Licenses" }),
              el("button", { className: "link-btn", attrs: { type: "button" }, text: "Done", on: { click: onClose } }),
            ],
          }),
          el("pre", {
            className: "mono",
            attrs: { style: "white-space:pre-wrap;font-size:13px;line-height:1.45" },
            text: LICENSES_BODY,
          }),
        ],
      }),
    ],
  });
}
