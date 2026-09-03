import { ONBOARDING_COPY } from "../../domain/onboarding";
import { logoImg } from "../components/chrome";
import { el } from "../dom";

export function renderOnboarding(onFinish: () => void): HTMLElement {
  let page = 0;

  const headline = el("h1", { className: "onboarding-headline", text: ONBOARDING_COPY.page1Headline });
  const line = el("p", { className: "onboarding-line", text: ONBOARDING_COPY.page1Line });
  const primary = el("button", {
    className: "onboarding-primary",
    attrs: { type: "button" },
    text: ONBOARDING_COPY.continueTitle,
  });
  const skip = el("button", {
    className: "onboarding-skip",
    attrs: { type: "button" },
    text: ONBOARDING_COPY.skipTitle,
    on: { click: onFinish },
  });
  const graphic = el("div", { className: "onboarding-graphic" });
  const dots = el("div", {
    className: "onboarding-dots",
    attrs: { "aria-hidden": "true" },
    children: [
      el("span", { className: "onboarding-dot on" }),
      el("span", { className: "onboarding-dot" }),
    ],
  });

  const paint = (): void => {
    const first = page === 0;
    headline.textContent = first ? ONBOARDING_COPY.page1Headline : ONBOARDING_COPY.page2Headline;
    line.textContent = first ? ONBOARDING_COPY.page1Line : ONBOARDING_COPY.page2Line;
    primary.textContent = first ? ONBOARDING_COPY.continueTitle : ONBOARDING_COPY.getStartedTitle;
    skip.hidden = !first;
    dots.replaceChildren(
      el("span", { className: first ? "onboarding-dot on" : "onboarding-dot" }),
      el("span", { className: first ? "onboarding-dot" : "onboarding-dot on" }),
    );
    graphic.replaceChildren(first ? editorMock() : freeMark());
  };

  primary.addEventListener("click", () => {
    if (page === 0) {
      page = 1;
      paint();
      return;
    }
    onFinish();
  });

  paint();

  return el("div", {
    className: "onboarding",
    attrs: { role: "dialog", "aria-label": "Welcome to lilC" },
    children: [
      el("div", { className: "onboarding-top", children: [skip] }),
      el("div", {
        className: "onboarding-body",
        children: [graphic, headline, line],
      }),
      dots,
      primary,
    ],
  });
}

function editorMock(): HTMLElement {
  return el("div", {
    className: "onboarding-stage",
    children: [
      logoImg(),
      el("div", {
        className: "onboarding-editor",
        attrs: { "aria-hidden": "true" },
        children: [
          el("div", {
            className: "onboarding-editor-bar",
            children: [
              el("span", { className: "mono", text: "hello.c" }),
              el("span", { className: "onboarding-run", text: "RUN" }),
            ],
          }),
          el("pre", {
            className: "onboarding-code mono",
            text: 'int main(void) {\n    printf("hello\\n");\n}',
          }),
          el("div", {
            className: "onboarding-out",
            children: [el("span", { className: "onboarding-pip" }), el("span", { className: "mono", text: "hello" })],
          }),
        ],
      }),
    ],
  });
}

function freeMark(): HTMLElement {
  const logo = logoImg();
  logo.className = "logo onboarding-logo-lg";
  return el("div", {
    className: "onboarding-stage",
    children: [
      el("div", { className: "onboarding-halo", children: [logo] }),
    ],
  });
}
