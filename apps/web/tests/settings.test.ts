/**
 * @vitest-environment happy-dom
 */
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { LocalCWorkspace } from "../src/domain/workspace";
import { renderSettings } from "../src/ui/screens/settings";

describe("settings", () => {
  beforeEach(() => {
    document.body.replaceChildren();
  });

  afterEach(() => {
    document.body.replaceChildren();
  });

  it("hides For teachers, licenses, and email this release", async () => {
    const workspace = new LocalCWorkspace();
    await workspace.load();
    const screen = renderSettings(workspace, "light", false, {
      back: () => undefined,
      setColorWay: () => undefined,
      setSyntaxColoring: () => undefined,
      eraseAll: () => undefined,
    });
    document.body.append(screen);
    expect(screen.textContent).toContain("Privacy Policy");
    expect(screen.textContent).toContain("Terms of Use");
    expect(screen.textContent).not.toContain("For teachers");
    expect(screen.textContent).not.toContain("Licenses");
    expect(screen.textContent).not.toContain("Email Support");
  });
});
