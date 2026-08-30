import type { LocalCFile } from "./files";
import { fileName } from "./files";

export type DiagnosticKind =
  | "SYNTAX ERROR"
  | "NAME ERROR"
  | "TYPE ERROR"
  | "RUNTIME ERROR"
  | "PROJECT ERROR"
  | "NOT SUPPORTED";

export interface CRunDiagnostic {
  kind: DiagnosticKind;
  title: string;
  explanation: string;
  suggestion: string;
  file?: string;
  line?: number;
  column?: number;
  sourceLine?: string;
  rawMessage: string;
}

export interface CErrorJump {
  fileID: string;
  line: number;
  column: number;
}

interface Advice {
  kind: DiagnosticKind;
  title: string;
  explanation: string;
  suggestion: string;
}

interface Location {
  file: string;
  line: number;
  column: number;
  message: string;
  sourceLine?: string;
}

export function diagnosticDisplayText(diagnostic: CRunDiagnostic): string {
  const lines = [`${diagnostic.kind} · ${diagnostic.title}`];
  if (diagnostic.file && diagnostic.line !== undefined) {
    const position =
      diagnostic.column !== undefined
        ? `${diagnostic.file}:${diagnostic.line}:${diagnostic.column}`
        : `${diagnostic.file}:${diagnostic.line}`;
    lines.push(position);
  }
  lines.push("");
  if (diagnostic.sourceLine && diagnostic.sourceLine.length > 0) {
    lines.push(diagnostic.sourceLine);
    if (diagnostic.column !== undefined) {
      lines.push(`${" ".repeat(Math.max(0, diagnostic.column))}^`);
    }
    lines.push("");
  }
  lines.push(diagnostic.explanation);
  if (diagnostic.suggestion.length > 0) {
    lines.push("");
    lines.push(`Try: ${diagnostic.suggestion}`);
  }
  lines.push("");
  lines.push("PicoC detail:");
  lines.push(diagnostic.rawMessage);
  return `${lines.join("\n")}\n`;
}

export function parseDiagnostic(raw: string): CRunDiagnostic | undefined {
  const normalized = raw.trim();
  if (normalized.length === 0) {
    return undefined;
  }
  const location = parseLocation(normalized);
  let message: string;
  if (location) {
    message = location.message;
  } else {
    const nonempty = normalized
      .split(/\n/)
      .map((line) => line.trim())
      .filter((line) => line.length > 0);
    if (nonempty.length > 1) {
      return undefined;
    }
    message = nonempty[0] ?? normalized;
  }
  const advice = adviceFor(message, normalized);
  if (!advice) {
    return undefined;
  }
  const diagnostic: CRunDiagnostic = {
    kind: advice.kind,
    title: advice.title,
    explanation: advice.explanation,
    suggestion: advice.suggestion,
    rawMessage: normalized,
  };
  if (location?.file) {
    diagnostic.file = location.file;
  }
  if (location?.line !== undefined) {
    diagnostic.line = location.line;
  }
  if (location?.column !== undefined) {
    diagnostic.column = location.column;
  }
  if (location?.sourceLine) {
    diagnostic.sourceLine = location.sourceLine;
  }
  return diagnostic;
}

export function displayOutput(raw: string): { text: string; failed: boolean } {
  const diagnostic = parseDiagnostic(raw);
  if (!diagnostic) {
    return { text: raw, failed: false };
  }
  return { text: diagnosticDisplayText(diagnostic), failed: true };
}

export function resolveErrorJump(
  diagnostic: CRunDiagnostic,
  runFile: LocalCFile,
  extras: LocalCFile[],
  projectFiles: LocalCFile[],
): CErrorJump | undefined {
  if (diagnostic.line === undefined || diagnostic.line <= 0) {
    return undefined;
  }
  const column = Math.max(diagnostic.column ?? 1, 1);
  const reportedName = diagnostic.file?.split("/").pop();
  if (reportedName) {
    const named = projectFiles.find(
      (file) => fileName(file).toLowerCase() === reportedName.toLowerCase(),
    );
    if (named && named.relativePath !== runFile.relativePath) {
      return { fileID: named.relativePath, line: diagnostic.line, column };
    }
  }
  const mapped = mapConcatenatedLine(diagnostic.line, runFile, extras);
  return { fileID: mapped.fileID, line: Math.max(mapped.line, 1), column };
}

export function concatenatedSource(runFile: LocalCFile, extras: LocalCFile[]): string {
  const extraCode = extras.map((file) => file.code).join("\n");
  return extraCode.length === 0 ? runFile.code : `${extraCode}\n${runFile.code}`;
}

function mapConcatenatedLine(
  line: number,
  runFile: LocalCFile,
  extras: LocalCFile[],
): { fileID: string; line: number } {
  if (extras.length === 0) {
    return { fileID: runFile.relativePath, line };
  }
  const source = concatenatedSource(runFile, extras);
  const offset = utf16OffsetOfLine(line, source);
  return ownerOfOffset(offset, runFile, extras);
}

function utf16OffsetOfLine(line: number, source: string): number {
  let current = 1;
  let index = 0;
  while (current < line && index < source.length) {
    const character = source.charCodeAt(index);
    index += 1;
    if (character === 10) {
      current += 1;
    } else if (character === 13) {
      if (index < source.length && source.charCodeAt(index) === 10) {
        index += 1;
      }
      current += 1;
    }
  }
  return index;
}

function ownerOfOffset(
  offset: number,
  runFile: LocalCFile,
  extras: LocalCFile[],
): { fileID: string; line: number } {
  let cursor = 0;
  for (const extra of extras) {
    const extraLength = extra.code.length;
    const extraEnd = cursor + extraLength;
    if (offset < extraEnd) {
      return {
        fileID: extra.relativePath,
        line: lineNumberAt(offset - cursor, extra.code),
      };
    }
    cursor = extraEnd;
    const joinerEnd = cursor + 1;
    if (offset < joinerEnd) {
      return {
        fileID: extra.relativePath,
        line: lineNumberAt(extraLength, extra.code),
      };
    }
    cursor = joinerEnd;
  }
  return {
    fileID: runFile.relativePath,
    line: lineNumberAt(Math.max(0, offset - cursor), runFile.code),
  };
}

function lineNumberAt(offset: number, code: string): number {
  const clamped = Math.min(Math.max(0, offset), code.length);
  let line = 1;
  let index = 0;
  while (index < clamped) {
    const character = code.charCodeAt(index);
    index += 1;
    if (character === 10) {
      line += 1;
    } else if (character === 13) {
      if (index < clamped && code.charCodeAt(index) === 10) {
        index += 1;
      }
      line += 1;
    }
  }
  return Math.max(line, 1);
}

function parseLocation(output: string): Location | undefined {
  const lines = output.split(/\n/);
  const pattern = /^(.+):(\d+):(\d+)\s+(.+)$/;
  for (const [index, line] of lines.entries()) {
    const match = pattern.exec(line);
    if (!match) {
      continue;
    }
    const file = match[1];
    const lineNumber = Number(match[2]);
    const column = Number(match[3]);
    const message = match[4];
    if (!file || !message || Number.isNaN(lineNumber) || Number.isNaN(column)) {
      continue;
    }
    let sourceLine: string | undefined;
    if (index >= 2 && lines[index - 1]?.trim() === "^") {
      sourceLine = lines[index - 2];
    }
    const found: Location = {
      file,
      line: lineNumber,
      column,
      message,
    };
    if (sourceLine) {
      found.sourceLine = sourceLine;
    }
    return found;
  }
  return undefined;
}

function adviceFor(message: string, wholeOutput: string): Advice | undefined {
  const text = message.toLowerCase();
  const all = wholeOutput.toLowerCase();

  if (text.includes("';' expected") || text.includes("semicolon expected")) {
    return syntax("Missing semicolon", "C statements normally end with a semicolon.", "add ; at the end of the statement above the caret.");
  }
  if (text.includes("'}' expected") || text.includes("brackets not closed")) {
    return syntax("Unclosed block", "An opening brace or bracket does not have a matching closing one.", "match every { with } and every ( with ).");
  }
  if (text.includes("'{' expected")) {
    return syntax("Missing opening brace", "C expected the start of a statement block.", "add { after the function, loop, or condition.");
  }
  if (text.includes("')' expected") || text.includes("'(' expected") || text.includes("close bracket expected")) {
    return syntax("Unmatched parentheses", "A function call or condition has an unmatched parenthesis.", "check the parentheses around this expression.");
  }
  if (text.includes("']' expected")) {
    return syntax("Unclosed array bracket", "An opening [ is missing its closing ].", "close the array size or index with ].");
  }
  if (text.includes("':' expected")) {
    return syntax("Missing colon", "case and default labels must end with a colon.", "write case 1: or default: before the statements.");
  }
  if (text.includes("'while' expected")) {
    return syntax("Incomplete do-while loop", "A do { ... } loop must finish with while (condition);", "add while (condition); after the closing brace.");
  }
  if (text.includes("comma expected")) {
    return syntax("Missing comma", "Items in this list must be separated by commas.", "add a comma between arguments, parameters, or initializers.");
  }
  if (text.includes("identifier expected") || text.includes("identifier not expected")) {
    return syntax("Expected a name", "C expected a valid variable, function, member, or type name here.", "use a name made from letters, digits, and underscores; do not start with a digit.");
  }
  if (text.includes("integer value expected")) {
    return type("Integer required", "This place needs a whole number, not a different type.", "use an int value or cast to int.");
  }
  if (text.includes("expression expected") || text.includes("invalid expression") || text.includes("value expected")) {
    return syntax("Incomplete expression", "The expression is missing a value or operator.", "check both sides of operators and remove any extra punctuation.");
  }
  if (text.includes("statement expected") || text.includes("operator not expected") || text.includes("value not expected") || text.includes("type not expected")) {
    return syntax("Unexpected token", "This token cannot appear at this point in a C statement.", "check the previous line for missing punctuation, then simplify this statement.");
  }
  if (text.includes("unterminated string") || text.includes("unterminated character")) {
    return syntax("Unclosed string", "A string or character literal is missing its closing quote.", 'add a matching " or \' on the same line, and escape quotes inside the text with \\.');
  }
  if (text.includes("unterminated comment")) {
    return syntax("Unclosed comment", "A /* comment never reaches its closing */.", "add */ at the end of the comment.");
  }
  if (text.includes("illegal character") || text.includes("expected \"'\"")) {
    return syntax("Invalid character or quote", "The source contains a character or quote PicoC cannot tokenize.", "replace smart quotes with plain ' or \" and close the string or character literal.");
  }
  if (text.includes("#else without") || text.includes("#endif without") || (text.includes("#if") && (text.includes("without") || text.includes("unmatched")))) {
    return syntax("Broken preprocessor condition", "A #else or #endif does not match an earlier #if or #ifdef.", "pair every #if / #ifdef with one #endif, and put #else only in between.");
  }
  if (text.includes("filename.h")) {
    return syntax("Missing include path", "#include needs a header name in quotes or angle brackets.", 'write #include <stdio.h> or #include "myheader.h".');
  }
  if (text.includes("cannot include") || text.includes("cannot open include") || text.includes("cannot read include") || (text.includes("include file") && text.includes("too large"))) {
    return project("Header not found", "The requested header is unavailable, too large, or outside this project folder.", "check the #include spelling and keep quoted .h files in the same project.");
  }
  if (text.includes("outside this project folder")) {
    return project("File I/O is limited", "fopen, remove, and rename only work on files inside this project folder.", "keep data files in the same project as your .c file, and use a relative path.");
  }
  if (text.includes("write some c code")) {
    return project("Nothing to run", "The editor is empty, so there is no C program to start.", "type a small program with int main(void) and press Run.");
  }
  if (text.includes("lilc could not")) {
    return project("Could not start the C engine", "lilC failed before your program could run.", "try Run again. If it keeps happening, reload the page.");
  }
  if (text.includes("main() is not defined")) {
    return project("No main function", "A runnable C program needs one main function.", "add int main(void) { return 0; }.");
  }
  if (text.includes("main is not a function") || text.includes("main() should return") || text.includes("bad parameters to main")) {
    return type("Invalid main function", "main must be a function that returns int or void and uses a supported parameter list.", "use int main(void) for a beginner program.");
  }
  if (text.includes("already defined")) {
    return name("Name defined twice", "Two declarations in this program use the same name where only one is allowed.", "rename or remove one definition. A project must contain only one main().");
  }
  if (text.includes("couldn't find goto label") || text.includes("could not find goto label")) {
    return name("Unknown goto label", "goto needs a label that exists in the same function.", "add label_name: before the target statement, or fix the spelling.");
  }
  if (text.includes("is not defined") || text.includes("is undefined") || text.includes("isn't defined") || text.includes("out of scope")) {
    return name("Unknown name", "This variable, function, struct, enum, or type is not visible here.", "check spelling and declare it before use.");
  }
  if (text.includes("doesn't have a member") || text.includes("structure or union member")) {
    return name("Unknown struct member", "That field is not declared in this struct or union.", "check the struct definition and the spelling after . or ->.");
  }
  if (text.includes("not a struct or union") || (text.includes("can't use") && (text.includes("struct") || text.includes("union")))) {
    return type("Not a struct or union", ". and -> only work on a struct, a union, or a pointer to one.", "declare a struct type and use . on the value or -> on a pointer.");
  }
  if (text.includes("too many arguments")) {
    return type("Too many arguments", "The call supplies more arguments than the function accepts.", "remove extra arguments or update the function parameters.");
  }
  if (text.includes("not enough arguments") || text.includes("arguments missing")) {
    return type("Missing arguments", "The call does not supply every required argument.", "pass a value for each function parameter.");
  }
  if (text.includes("too many parameters")) {
    return type("Too many parameters", "This function declares more parameters than PicoC allows.", "keep the parameter list to 16 or fewer, or split the function.");
  }
  if (text.includes("bad parameter") || text.includes("bad argument")) {
    return type("Invalid argument or parameter", "A parameter or argument is missing or written incorrectly.", "check the commas, types, and names in this list.");
  }
  if (text.includes("non-pointer argument to scanf")) {
    return type("scanf needs an address", "scanf must write into a variable through a pointer.", "pass &variable for numbers and chars, or a char array for %s.");
  }
  if (text.includes("is not a function")) {
    return type("Not a function", "This name exists but is not a function, so it cannot be called.", "call a function name, or remove the parentheses if you meant a variable.");
  }
  if (text.includes("can't get the address")) {
    return type("Cannot take address", "& only works on a real variable or array element, not a temporary value.", "store the value in a variable first, then take its address.");
  }
  if (text.includes("can't initialize") || text.includes("incomplete type")) {
    return type("Incomplete type", "This type is not fully declared yet, so it cannot be created or initialized.", "finish the struct, union, or array declaration before using it.");
  }
  if (text.includes("can't define a void")) {
    return type("Void variable", "void means “no value,” so you cannot declare a void variable.", "use a real type such as int, char, or a pointer.");
  }
  if (text.includes("can't set") || text.includes("can't assign") || text.includes("not an lvalue") || text.includes("from an array of size")) {
    return type("Invalid assignment", "The value on the left cannot receive this value or cannot be changed.", "check the destination type and do not assign to constants, arrays, or temporary values.");
  }
  if (text.includes("array index out of range") || text.includes("array index out of bounds")) {
    return runtime("Array index out of range", "The program used an index outside the array’s declared size.", "use indexes from 0 through size - 1, and check the index before you use it.");
  }
  if (text.includes("array index must be an integer") || text.includes("is not an array")) {
    return type("Invalid array access", "Array indexing needs an integer and an actual array or pointer.", "use array[index] with an integer index inside the valid range.");
  }
  if (text.includes("too many array elements") || text.includes("too many struct initializers")) {
    return type("Too many initializer values", "The initializer contains more values than the destination can hold.", "remove extra values or increase the declared array size.");
  }
  if (text.includes("first argument to '?'")) {
    return type("Invalid ternary condition", "The ? : operator needs a number or comparison on the left of ?.", "write condition ? valueIfTrue : valueIfFalse.");
  }
  if (text.includes("no value returned")) {
    return type("Missing return value", "This function promises a result but reached the end without returning one.", "add return someValue; on every path, including the end of the function.");
  }
  if (text.includes("void value") || text.includes("void function") || text.includes("value required in return")) {
    return type("Wrong return value", "The function’s declared return type does not match this return or expression.", "return a value from non-void functions and no value from void functions.");
  }
  if (text.includes("null pointer")) {
    return runtime("NULL pointer access", "The program tried to read or write through a pointer that points to nothing.", "check pointer != NULL before dereferencing it with * or ->.");
  }
  if (text.includes("assertion failed")) {
    return runtime("Assertion failed", "assert() stopped the program because its condition was false.", "fix the condition that failed, or remove the assert once the code is correct.");
  }
  if (text.includes("invalid allocation size")) {
    return runtime("Invalid allocation size", "malloc and related calls need a non-negative size in bytes.", "pass a size of 0 or more, often count * sizeof(type).");
  }
  if (text.includes("division by zero") || text.includes("modulo by zero")) {
    return runtime("Division by zero", "Integer division and remainder operations cannot use zero as the divisor.", "check the divisor before using /, %, /=, or %=.");
  }
  if (text.includes("invalid shift count")) {
    return runtime("Invalid bit shift", "A bit shift count cannot be negative or at least as large as the integer type.", "use a shift count from 0 through the number of bits minus one.");
  }
  if (text.includes("program stopped: too many steps") || all.includes("program stopped: too many steps")) {
    return runtime("Program ran too long", "lilC stopped the program to protect the app. This often means an infinite loop or runaway recursion.", "check that every loop changes toward its stopping condition.");
  }
  if (text.includes("stack underrun") || text.includes("stack is empty") || text.includes("out of memory")) {
    return runtime("Program memory exhausted", "The interpreter ran out of its limited stack or heap.", "reduce recursion and large allocations, and free memory you allocate.");
  }
  if (text === "abort" || text.endsWith(" abort") || text.includes("abort\n") || (text.includes("abort") && text.length < 40)) {
    return runtime("Program aborted", "The program called abort(), which stops the run immediately.", "remove abort() or only call it when you really mean to stop.");
  }
  if (text.includes("system() is not available") || text.includes("not supported")) {
    return unsupported("Feature unavailable in lilC", "This operation is outside lilC’s safe PicoC runtime.", "use a beginner-friendly alternative PicoC can run, or try the same idea on a desktop compiler later.");
  }
  if (text.includes("nested function")) {
    return unsupported("Nested functions are not allowed", "PicoC does not allow a function defined inside another function.", "move the inner function next to the others, above main.");
  }
  if (text.includes("can only be globals")) {
    return type("Type must be global", "struct, union, and enum types must be declared at the top level, not inside a function.", "move the type definition above main.");
  }
  if (text.includes("invalid type in struct")) {
    return type("Invalid struct member type", "A struct or union member uses a type PicoC cannot store there.", "use a complete type for each member and finish nested struct definitions first.");
  }
  if (text.includes("invalid operation") || text.includes("invalid use")) {
    return type("Invalid operation", "This operator cannot be used with these values.", "check the operand types and pointer values.");
  }
  if (text.includes("parse error") || text.includes("bad type declaration") || text.includes("bad function") || text.includes("function body expected") || text.includes("function definition expected")) {
    return syntax("Could not parse this code", "The declaration or function near the caret is incomplete.", "check braces, parentheses, types, names, and semicolons around this line.");
  }
  if (all.startsWith("cannot run this project:")) {
    return project("Multiple main functions", "A project can only have one program entry point.", "keep one main() and turn the other files into helper functions.");
  }
  if (/:\d+:\d+\s+\S+/.test(wholeOutput)) {
    return syntax("Could not run this code", "PicoC stopped on the marked line.", "read the PicoC detail below and fix the code at the caret.");
  }
  return undefined;
}

function syntax(title: string, explanation: string, suggestion: string): Advice {
  return { kind: "SYNTAX ERROR", title, explanation, suggestion };
}

function name(title: string, explanation: string, suggestion: string): Advice {
  return { kind: "NAME ERROR", title, explanation, suggestion };
}

function type(title: string, explanation: string, suggestion: string): Advice {
  return { kind: "TYPE ERROR", title, explanation, suggestion };
}

function runtime(title: string, explanation: string, suggestion: string): Advice {
  return { kind: "RUNTIME ERROR", title, explanation, suggestion };
}

function project(title: string, explanation: string, suggestion: string): Advice {
  return { kind: "PROJECT ERROR", title, explanation, suggestion };
}

function unsupported(title: string, explanation: string, suggestion: string): Advice {
  return { kind: "NOT SUPPORTED", title, explanation, suggestion };
}
