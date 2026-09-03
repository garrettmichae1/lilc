export type CSyntaxKind =
  | "control"
  | "type"
  | "preprocessor"
  | "op"
  | "string"
  | "comment"
  | "number";

export interface CSyntaxToken {
  kind: CSyntaxKind;
  start: number;
  end: number;
}

const CONTROL = new Set([
  "break",
  "case",
  "continue",
  "default",
  "do",
  "else",
  "for",
  "goto",
  "if",
  "return",
  "switch",
  "while",
]);

const TYPES = new Set([
  "auto",
  "char",
  "const",
  "delete",
  "double",
  "enum",
  "extern",
  "float",
  "int",
  "long",
  "new",
  "register",
  "short",
  "signed",
  "sizeof",
  "static",
  "struct",
  "typedef",
  "union",
  "unsigned",
  "void",
  "volatile",
]);

const PREPROCESSOR = new Set(["define", "else", "endif", "if", "ifdef", "ifndef", "include"]);

const OPERATORS = [
  "<<=",
  ">>=",
  "==",
  "!=",
  "<=",
  ">=",
  "&&",
  "||",
  "++",
  "--",
  "<<",
  ">>",
  "->",
  "+=",
  "-=",
  "*=",
  "/=",
  "%=",
  "&=",
  "|=",
  "^=",
  "+",
  "-",
  "*",
  "/",
  "%",
  "=",
  "<",
  ">",
  "!",
  "&",
  "|",
  "^",
  "~",
  "?",
  ":",
  ".",
];

export function tokenizeC(source: string): CSyntaxToken[] {
  const tokens: CSyntaxToken[] = [];
  const length = source.length;
  let index = 0;

  while (index < length) {
    const char = source[index] ?? "";
    if (char === " " || char === "\t" || char === "\n" || char === "\r") {
      index += 1;
      continue;
    }
    if (char === "/" && source[index + 1] === "/") {
      const start = index;
      index += 2;
      while (index < length && source[index] !== "\n") {
        index += 1;
      }
      tokens.push({ kind: "comment", start, end: index });
      continue;
    }
    if (char === "/" && source[index + 1] === "*") {
      const start = index;
      index += 2;
      while (index + 1 < length && !(source[index] === "*" && source[index + 1] === "/")) {
        index += 1;
      }
      index = index + 1 < length ? index + 2 : length;
      tokens.push({ kind: "comment", start, end: index });
      continue;
    }
    if (char === "#" && isDirectiveStart(source, index)) {
      const start = index;
      index += 1;
      while (index < length && (source[index] === " " || source[index] === "\t")) {
        index += 1;
      }
      const nameStart = index;
      while (index < length && isIdentPart(source[index] ?? "")) {
        index += 1;
      }
      if (PREPROCESSOR.has(source.slice(nameStart, index))) {
        tokens.push({ kind: "preprocessor", start, end: index });
        continue;
      }
      index = start + 1;
      continue;
    }
    if (char === '"' || char === "'") {
      const start = index;
      const quote = char;
      index += 1;
      while (index < length) {
        if (source[index] === "\\" && index + 1 < length) {
          index += 2;
          continue;
        }
        if (source[index] === quote) {
          index += 1;
          break;
        }
        index += 1;
      }
      tokens.push({ kind: "string", start, end: index });
      continue;
    }
    if (isDigit(char) || (char === "." && isDigit(source[index + 1] ?? ""))) {
      const start = index;
      if (char === "0" && (source[index + 1] === "x" || source[index + 1] === "X")) {
        index += 2;
        while (index < length && isHex(source[index] ?? "")) {
          index += 1;
        }
      } else {
        if (char === ".") {
          index += 1;
        }
        while (index < length && isDigit(source[index] ?? "")) {
          index += 1;
        }
        if (
          char !== "." &&
          source[index] === "." &&
          isDigit(source[index + 1] ?? "")
        ) {
          index += 1;
          while (index < length && isDigit(source[index] ?? "")) {
            index += 1;
          }
        }
      }
      tokens.push({ kind: "number", start, end: index });
      continue;
    }
    if (isIdentStart(char)) {
      const start = index;
      index += 1;
      while (index < length && isIdentPart(source[index] ?? "")) {
        index += 1;
      }
      const word = source.slice(start, index);
      if (CONTROL.has(word)) {
        tokens.push({ kind: "control", start, end: index });
      } else if (TYPES.has(word)) {
        tokens.push({ kind: "type", start, end: index });
      }
      continue;
    }
    const op = matchOperator(source, index);
    if (op) {
      tokens.push({ kind: "op", start: index, end: index + op });
      index += op;
      continue;
    }
    index += 1;
  }
  return tokens;
}

function isDigit(char: string): boolean {
  return char >= "0" && char <= "9";
}

function isHex(char: string): boolean {
  return isDigit(char) || (char >= "A" && char <= "F") || (char >= "a" && char <= "f");
}

function isIdentStart(char: string): boolean {
  return (char >= "A" && char <= "Z") || (char >= "a" && char <= "z") || char === "_";
}

function isIdentPart(char: string): boolean {
  return isIdentStart(char) || isDigit(char);
}

function isDirectiveStart(source: string, index: number): boolean {
  let cursor = index;
  while (cursor > 0) {
    const previous = source[cursor - 1];
    if (previous === "\n") {
      return true;
    }
    if (previous !== " " && previous !== "\t") {
      return false;
    }
    cursor -= 1;
  }
  return true;
}

function matchOperator(source: string, index: number): number | undefined {
  for (const op of OPERATORS) {
    if (source.startsWith(op, index)) {
      return op.length;
    }
  }
  return undefined;
}
