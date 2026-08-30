import { describe, expect, it } from "vitest";
import { displayOutput, parseDiagnostic, resolveErrorJump } from "../src/domain/diagnostics";
import type { LocalCFile } from "../src/domain/files";

describe("friendly diagnostics", () => {
  it("preserves location, source line, and raw PicoC detail", () => {
    const raw = `printf("hello")
               ^
hello.c:3:15 ';' expected`;
    const diagnostic = parseDiagnostic(raw);
    expect(diagnostic?.kind).toBe("SYNTAX ERROR");
    expect(diagnostic?.line).toBe(3);
    expect(diagnostic?.column).toBe(15);
    expect(diagnostic?.sourceLine).toBe('printf("hello")');
    expect(diagnostic?.title).toBe("Missing semicolon");
    expect(diagnosticDisplayHas(diagnostic?.rawMessage, "';' expected")).toBe(true);
    expect(diagnosticDisplayHas(diagnostic ? requireDisplay(diagnostic) : "", "PicoC detail:")).toBe(true);
  });

  it("does not rewrite successful multi-line output that mentions an error phrase", () => {
    const output = "status: ok\n';' expected\n";
    const formatted = displayOutput(output);
    expect(formatted.failed).toBe(false);
    expect(formatted.text).toBe(output);
  });

  it("maps concatenated helper lines onto the helper file", () => {
    const helper: LocalCFile = {
      relativePath: "proj/util.c",
      code: "int add(int a, int b) {\n    return a + b\n}\n",
      updatedAt: 1,
    };
    const main: LocalCFile = {
      relativePath: "proj/main.c",
      code: "int main(void) { return add(1, 2); }\n",
      updatedAt: 1,
    };
    const jump = resolveErrorJump(
      {
        kind: "SYNTAX ERROR",
        title: "Missing semicolon",
        explanation: "C statements normally end with a semicolon.",
        suggestion: "add ;",
        file: "main.c",
        line: 2,
        column: 16,
        sourceLine: "    return a + b",
        rawMessage: "main.c:2:16 ';' expected",
      },
      main,
      [helper],
      [helper, main],
    );
    expect(jump?.fileID).toBe(helper.relativePath);
    expect(jump?.line).toBe(2);
    expect(jump?.column).toBe(16);
  });

  it("maps a catalog of PicoC and runner messages", () => {
    const samples: Array<[string, string, string]> = [
      ["can't get the address of this", "TYPE ERROR", "Cannot take address"],
      ["first argument to '?' should be a number", "TYPE ERROR", "Invalid ternary condition"],
      ["integer value expected instead of double", "TYPE ERROR", "Integer required"],
      ["no value returned from a function returning int", "TYPE ERROR", "Missing return value"],
      ["couldn't find goto label 'done'", "NAME ERROR", "Unknown goto label"],
      ["nested function definitions are not allowed", "NOT SUPPORTED", "Nested functions"],
      ["too many parameters (16 allowed)", "TYPE ERROR", "Too many parameters"],
      ["bad parameter", "TYPE ERROR", "Invalid argument"],
      ["int is not a function - can't call", "TYPE ERROR", "Not a function"],
      ["can't initialize an incomplete type", "TYPE ERROR", "Incomplete type"],
      ["can't define a void variable", "TYPE ERROR", "Void variable"],
      ["struct/union definitions can only be globals", "TYPE ERROR", "Type must be global"],
      ["invalid type in struct", "TYPE ERROR", "Invalid struct member"],
      ["']' expected", "SYNTAX ERROR", "Unclosed array"],
      ["':' expected", "SYNTAX ERROR", "Missing colon"],
      ["'while' expected", "SYNTAX ERROR", "do-while"],
      ["#else without #if", "SYNTAX ERROR", "preprocessor"],
      ["cannot read include file 'notes.h'", "PROJECT ERROR", "Header not found"],
      ["Write some C code, then run it.", "PROJECT ERROR", "Nothing to run"],
      ["lilC could not start the local C engine.", "PROJECT ERROR", "Could not start"],
      ["non-pointer argument to scanf() - argument 1 after format", "TYPE ERROR", "scanf"],
      ["stack is empty - can't go back", "RUNTIME ERROR", "memory"],
      ["(VariableAlloc) out of memory", "RUNTIME ERROR", "memory"],
      ["function definition expected", "SYNTAX ERROR", "parse"],
      ["assertion failed", "RUNTIME ERROR", "Assertion"],
      ["NULL pointer passed to strlen()", "RUNTIME ERROR", "NULL"],
      ["invalid allocation size", "RUNTIME ERROR", "allocation"],
      ["cannot open 'notes.txt' outside this project folder", "PROJECT ERROR", "File I/O"],
      ["system() is not available in lilC local mode.", "NOT SUPPORTED", "unavailable"],
      ["Cannot run this project: it has more than one main() function (a.c, b.c).\n", "PROJECT ERROR", "Multiple main"],
    ];
    for (const [raw, kind, titlePart] of samples) {
      const diagnostic = parseDiagnostic(raw);
      expect(diagnostic, `expected diagnostic for: ${raw}`).toBeTruthy();
      expect(diagnostic?.kind).toBe(kind);
      const blob = `${diagnostic?.title} ${diagnostic?.explanation} ${diagnostic ? requireDisplay(diagnostic) : ""}`;
      expect(blob.toLowerCase()).toContain(titlePart.toLowerCase());
    }
  });
});

function requireDisplay(diagnostic: NonNullable<ReturnType<typeof parseDiagnostic>>): string {
  return displayOutput(diagnostic.rawMessage).text;
}

function diagnosticDisplayHas(text: string | undefined, part: string): boolean {
  return Boolean(text?.includes(part));
}
