/**
 * @vitest-environment happy-dom
 */
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { completeOnboarding, resetOnboardingForTests } from "../src/domain/onboarding";
import { LocalCWorkspace } from "../src/domain/workspace";
import { App } from "../src/ui/app";

describe("learn tab navigation", () => {
  beforeEach(() => {
    document.body.replaceChildren();
    resetOnboardingForTests();
    completeOnboarding();
  });

  afterEach(() => {
    document.body.replaceChildren();
    resetOnboardingForTests();
  });

  it("moves the learning hub onto Learn and returns there from lessons, quizzes, and files", async () => {
    const host = document.createElement("div");
    document.body.append(host);
    const workspace = new LocalCWorkspace();
    await workspace.load();
    new App(host, workspace);

    expect(host.textContent).toContain("Projects");
    expect(host.textContent).toContain("LEARN");
    expect(host.textContent).not.toContain("Quizzes");
    expect(host.querySelectorAll("[data-lesson-id]").length).toBe(0);
    expect([...host.querySelectorAll(".tab")].map((tab) => tab.textContent)).toEqual(["HOME", "FILES", "LEARN"]);

    clickNamed(host, "LEARN");
    expect(host.textContent).toContain("Learn");
    expect(host.textContent).toContain("Lessons");
    expect(host.textContent).toContain("Challenges");
    expect(host.textContent).toContain("Quizzes");

    host.querySelector<HTMLButtonElement>("[data-lesson-id]")?.click();
    expect(host.querySelector("textarea.editor")).toBeInstanceOf(HTMLTextAreaElement);
    host.querySelector<HTMLButtonElement>('[aria-label="Back"]')?.click();
    expect(host.textContent).toContain("Quizzes");
    expect(host.querySelector(".learn-title")?.textContent).toBe("Learn");

    host.querySelector<HTMLElement>("[data-quiz-id]")?.click();
    expect(host.querySelector('[aria-label^="Question"]')).not.toBeNull();
    host.querySelector<HTMLButtonElement>('[aria-label="Back"]')?.click();
    expect(host.querySelector(".learn-title")?.textContent).toBe("Learn");

    clickNamed(host, "FILES");
    expect(host.textContent).toContain("Files");
    host.querySelector<HTMLButtonElement>('[aria-label="Back"]')?.click();
    expect(host.querySelector(".learn-title")?.textContent).toBe("Learn");

    clickNamed(host, "HOME");
    expect(host.textContent).toContain("Projects");
    expect(host.textContent).not.toContain("Quizzes");
    clickNamed(host, "Open editor");
    expect(host.querySelector("textarea.editor")).toBeInstanceOf(HTMLTextAreaElement);
    host.querySelector<HTMLButtonElement>('[aria-label="Back"]')?.click();
    expect(host.textContent).toContain("Projects");
    expect(host.querySelector(".learn-title")).toBeNull();
  });
});

function clickNamed(host: HTMLElement, label: string): void {
  const button = [...host.querySelectorAll("button")].find((node) => {
    const text = node.textContent?.replace(/\s+/g, " ").trim() ?? "";
    return text === label || text.startsWith(label);
  });
  expect(button, `missing button ${label}`).toBeInstanceOf(HTMLButtonElement);
  button?.click();
}
