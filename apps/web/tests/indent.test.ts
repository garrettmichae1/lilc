import { describe, expect, it } from "vitest";
import { formatC, indentSelection } from "../src/domain/indent";
import { findMatches } from "../src/domain/search";
import { normalizedFolderName, normalizedName } from "../src/domain/files";

describe("names", () => {
  it("normalizes C file names", () => {
    expect(normalizedName("hello")).toBe("hello.c");
    expect(normalizedName("hello.c")).toBe("hello.c");
    expect(normalizedName("  ")).toBe("hello.c");
    expect(normalizedFolderName("My Project")).toBe("My-Project");
  });
});

describe("find", () => {
  it("finds case-insensitive matches", () => {
    const text = 'int main(void) {\n    printf("Hello");\n    printf("hello");\n}\n';
    expect(findMatches(text, "HELLO")).toHaveLength(2);
    expect(findMatches(text, "   ")).toHaveLength(0);
    expect(findMatches(text, "")).toHaveLength(0);
    expect(findMatches(text, "nope")).toHaveLength(0);
  });
});

describe("indent", () => {
  it("indents and outdents a selection with 4 spaces", () => {
    const source = "int main(void) {\nreturn 0;\n}\n";
    const indented = indentSelection(source, { start: 17, end: 26 }, false);
    expect(indented.text).toContain("    return 0;");
    const out = indentSelection(indented.text, indented.range, true);
    expect(out.text).toContain("\nreturn 0;\n");
  });

  it("formats a simple C function with 4-space indent", () => {
    const formatted = formatC("int main(void) {\nprintf(\"hi\");\n}\n");
    expect(formatted).toBe("int main(void) {\n    printf(\"hi\");\n}\n");
  });
});
