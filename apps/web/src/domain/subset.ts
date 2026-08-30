/**
 * Tiny C subset used only when PicoC WASM is not loaded.
 * Enough for the first-hour lessons (hello, variables, if, loop, array, function).
 * Not a compiler. Not GCC. Prefer PicoC whenever it is available.
 */

export interface SubsetResult {
  ok: boolean;
  output: string;
}

const MAX_STEPS = 80_000;

type Value =
  | { kind: "int"; value: number }
  | { kind: "array"; items: number[] };

type Expr =
  | { kind: "int"; value: number }
  | { kind: "string"; value: string }
  | { kind: "var"; name: string }
  | { kind: "unary"; op: "!" | "+" | "-"; expr: Expr }
  | { kind: "binary"; op: string; left: Expr; right: Expr }
  | { kind: "assign"; target: Expr; value: Expr }
  | { kind: "index"; array: Expr; index: Expr }
  | { kind: "call"; name: string; args: Expr[] };

type Stmt =
  | { kind: "block"; body: Stmt[] }
  | { kind: "decl"; name: string; size?: number; init?: Expr }
  | { kind: "if"; test: Expr; consequent: Stmt; alternate?: Stmt }
  | { kind: "for"; init?: Stmt | Expr; test?: Expr; inc?: Expr; body: Stmt }
  | { kind: "return"; value?: Expr }
  | { kind: "expr"; expr: Expr };

interface Fn {
  name: string;
  params: string[];
  body: Stmt[];
}

class ReturnSignal {
  constructor(readonly value: number) {}
}

export function runFirstHourSubset(source: string): SubsetResult {
  try {
    const program = parseProgram(source);
    const output = execute(program);
    return { ok: true, output };
  } catch (error) {
    const message = error instanceof Error ? error.message : "This program needs PicoC.";
    return { ok: false, output: `${message}\n` };
  }
}

function parseProgram(source: string): Map<string, Fn> {
  const tokens = tokenize(source);
  const parser = new Parser(tokens);
  return parser.parseProgram();
}

interface Token {
  kind: string;
  value: string;
}

function tokenize(source: string): Token[] {
  const tokens: Token[] = [];
  let index = 0;
  const length = source.length;
  const two = new Set(["==", "!=", "<=", ">=", "&&", "||", "++", "--"]);

  while (index < length) {
    const char = source[index] ?? "";
    if (char === " " || char === "\t" || char === "\r" || char === "\n") {
      index += 1;
      continue;
    }
    if (char === "/" && source[index + 1] === "/") {
      while (index < length && source[index] !== "\n") {
        index += 1;
      }
      continue;
    }
    if (char === "/" && source[index + 1] === "*") {
      index += 2;
      while (index < length && !(source[index] === "*" && source[index + 1] === "/")) {
        index += 1;
      }
      index += 2;
      continue;
    }
    if (char === "#") {
      while (index < length && source[index] !== "\n") {
        index += 1;
      }
      continue;
    }
    if (char === '"') {
      let value = "";
      index += 1;
      while (index < length && source[index] !== '"') {
        if (source[index] === "\\" && index + 1 < length) {
          const next = source[index + 1];
          value +=
            next === "n" ? "\n" : next === "t" ? "\t" : next === "\\" || next === '"' ? next : next;
          index += 2;
          continue;
        }
        value += source[index];
        index += 1;
      }
      index += 1;
      tokens.push({ kind: "string", value });
      continue;
    }
    if (/[0-9]/.test(char)) {
      let value = "";
      while (index < length && /[0-9]/.test(source[index] ?? "")) {
        value += source[index];
        index += 1;
      }
      tokens.push({ kind: "number", value });
      continue;
    }
    if (/[A-Za-z_]/.test(char)) {
      let value = "";
      while (index < length && /[A-Za-z0-9_]/.test(source[index] ?? "")) {
        value += source[index];
        index += 1;
      }
      tokens.push({ kind: "ident", value });
      continue;
    }
    const pair = source.slice(index, index + 2);
    if (two.has(pair)) {
      tokens.push({ kind: pair, value: pair });
      index += 2;
      continue;
    }
    tokens.push({ kind: char, value: char });
    index += 1;
  }
  tokens.push({ kind: "eof", value: "" });
  return tokens;
}

class Parser {
  private index = 0;

  constructor(private readonly tokens: Token[]) {}

  parseProgram(): Map<string, Fn> {
    const functions = new Map<string, Fn>();
    while (!this.check("eof")) {
      const fn = this.parseFunction();
      functions.set(fn.name, fn);
    }
    if (!functions.has("main")) {
      throw new Error("No main() function.");
    }
    return functions;
  }

  private parseFunction(): Fn {
    this.parseType();
    const name = this.expect("ident").value;
    this.expect("(");
    const params: string[] = [];
    if (this.check("ident") && this.peek().value === "void" && this.looksLikeVoidParams()) {
      this.next();
    } else if (!this.check(")")) {
      do {
        this.parseType();
        params.push(this.expect("ident").value);
      } while (this.match(","));
    }
    this.expect(")");
    const body = this.parseBlock().body;
    return { name, params, body };
  }

  private looksLikeVoidParams(): boolean {
    const next = this.tokens[this.index + 1];
    return next?.kind === ")";
  }

  private parseType(): void {
    const token = this.peek();
    if (token.kind === "ident" && (token.value === "int" || token.value === "void" || token.value === "char")) {
      this.next();
      return;
    }
    throw new Error("Expected a type name.");
  }

  private parseBlock(): { kind: "block"; body: Stmt[] } {
    this.expect("{");
    const body: Stmt[] = [];
    while (!this.check("}") && !this.check("eof")) {
      body.push(this.parseStatement());
    }
    this.expect("}");
    return { kind: "block", body };
  }

  private parseStatement(): Stmt {
    if (this.check("ident") && (this.peek().value === "int" || this.peek().value === "char")) {
      return this.parseDecl();
    }
    if (this.check("ident") && this.peek().value === "if") {
      this.next();
      this.expect("(");
      const test = this.parseExpression();
      this.expect(")");
      const consequent = this.parseStatement();
      let alternate: Stmt | undefined;
      if (this.check("ident") && this.peek().value === "else") {
        this.next();
        alternate = this.parseStatement();
      }
      return alternate
        ? { kind: "if", test, consequent, alternate }
        : { kind: "if", test, consequent };
    }
    if (this.check("ident") && this.peek().value === "for") {
      this.next();
      this.expect("(");
      let init: Stmt | Expr | undefined;
      if (!this.check(";")) {
        init = this.check("ident") && this.peek().value === "int" ? this.parseDecl() : this.parseExpression();
        if (init && !("kind" in init && init.kind === "decl")) {
          this.expect(";");
        }
      } else {
        this.next();
      }
      let test: Expr | undefined;
      if (!this.check(";")) {
        test = this.parseExpression();
      }
      this.expect(";");
      let inc: Expr | undefined;
      if (!this.check(")")) {
        inc = this.parseExpression();
      }
      this.expect(")");
      const body = this.parseStatement();
      return { kind: "for", ...(init ? { init } : {}), ...(test ? { test } : {}), ...(inc ? { inc } : {}), body };
    }
    if (this.check("ident") && this.peek().value === "return") {
      this.next();
      if (this.match(";")) {
        return { kind: "return" };
      }
      const value = this.parseExpression();
      this.expect(";");
      return { kind: "return", value };
    }
    if (this.check("{")) {
      return this.parseBlock();
    }
    const expr = this.parseExpression();
    this.expect(";");
    return { kind: "expr", expr };
  }

  private parseDecl(): Stmt {
    this.parseType();
    const name = this.expect("ident").value;
    let size: number | undefined;
    if (this.match("[")) {
      size = Number(this.expect("number").value);
      this.expect("]");
    }
    let init: Expr | undefined;
    if (this.match("=")) {
      init = this.parseExpression();
    }
    this.expect(";");
    return {
      kind: "decl",
      name,
      ...(size !== undefined ? { size } : {}),
      ...(init ? { init } : {}),
    };
  }

  private parseExpression(): Expr {
    return this.parseAssign();
  }

  private parseAssign(): Expr {
    const left = this.parseOr();
    if (this.match("=")) {
      return { kind: "assign", target: left, value: this.parseAssign() };
    }
    return left;
  }

  private parseOr(): Expr {
    return this.parseBinary(() => this.parseAnd(), ["||"]);
  }

  private parseAnd(): Expr {
    return this.parseBinary(() => this.parseEquality(), ["&&"]);
  }

  private parseEquality(): Expr {
    return this.parseBinary(() => this.parseCompare(), ["==", "!="]);
  }

  private parseCompare(): Expr {
    return this.parseBinary(() => this.parseAdd(), ["<", ">", "<=", ">="]);
  }

  private parseAdd(): Expr {
    return this.parseBinary(() => this.parseMul(), ["+", "-"]);
  }

  private parseMul(): Expr {
    return this.parseBinary(() => this.parseUnary(), ["*", "/", "%"]);
  }

  private parseBinary(next: () => Expr, ops: string[]): Expr {
    let left = next();
    while (ops.includes(this.peek().kind)) {
      const op = this.next().kind;
      left = { kind: "binary", op, left, right: next() };
    }
    return left;
  }

  private parseUnary(): Expr {
    if (this.check("!") || this.check("+") || this.check("-")) {
      const op = this.next().kind as "!" | "+" | "-";
      return { kind: "unary", op, expr: this.parseUnary() };
    }
    return this.parsePostfix();
  }

  private parsePostfix(): Expr {
    let expr = this.parsePrimary();
    while (true) {
      if (this.match("(")) {
        if (expr.kind !== "var") {
          throw new Error("Can only call a function name.");
        }
        const args: Expr[] = [];
        if (!this.check(")")) {
          do {
            args.push(this.parseExpression());
          } while (this.match(","));
        }
        this.expect(")");
        expr = { kind: "call", name: expr.name, args };
        continue;
      }
      if (this.match("[")) {
        const index = this.parseExpression();
        this.expect("]");
        expr = { kind: "index", array: expr, index };
        continue;
      }
      break;
    }
    return expr;
  }

  private parsePrimary(): Expr {
    if (this.check("number")) {
      return { kind: "int", value: Number(this.next().value) };
    }
    if (this.check("string")) {
      return { kind: "string", value: this.next().value };
    }
    if (this.check("ident")) {
      const name = this.next().value;
      if (name === "void") {
        throw new Error("Unexpected void.");
      }
      return { kind: "var", name };
    }
    if (this.match("(")) {
      const expr = this.parseExpression();
      this.expect(")");
      return expr;
    }
    throw new Error("Expected an expression.");
  }

  private peek(): Token {
    return this.tokens[this.index] ?? { kind: "eof", value: "" };
  }

  private next(): Token {
    const token = this.peek();
    this.index += 1;
    return token;
  }

  private check(kind: string): boolean {
    return this.peek().kind === kind;
  }

  private match(kind: string): boolean {
    if (this.check(kind)) {
      this.next();
      return true;
    }
    return false;
  }

  private expect(kind: string): Token {
    if (!this.check(kind)) {
      throw new Error(`Expected ${kind}.`);
    }
    return this.next();
  }
}

function execute(functions: Map<string, Fn>): string {
  let output = "";
  let steps = 0;
  const frames: Array<Map<string, Value>> = [new Map()];

  const lookup = (name: string): Value => {
    for (let index = frames.length - 1; index >= 0; index -= 1) {
      const found = frames[index]?.get(name);
      if (found) {
        return found;
      }
    }
    throw new Error(`Unknown name '${name}'.`);
  };

  const setVar = (name: string, value: Value): void => {
    for (let index = frames.length - 1; index >= 0; index -= 1) {
      const frame = frames[index];
      if (frame?.has(name)) {
        frame.set(name, value);
        return;
      }
    }
    frames[frames.length - 1]?.set(name, value);
  };

  const bump = (): void => {
    steps += 1;
    if (steps > MAX_STEPS) {
      throw new Error("Stopped: this loop ran too long.");
    }
  };

  const asInt = (value: Value | number | string): number => {
    if (typeof value === "number") {
      return value | 0;
    }
    if (typeof value === "string") {
      throw new Error("Expected a number.");
    }
    if (value.kind === "int") {
      return value.value | 0;
    }
    throw new Error("Expected a number.");
  };

  const evalExpr = (expr: Expr): Value | number | string => {
    bump();
    switch (expr.kind) {
      case "int":
        return expr.value | 0;
      case "string":
        return expr.value;
      case "var":
        return lookup(expr.name);
      case "unary": {
        const value = asInt(evalExpr(expr.expr));
        if (expr.op === "!") {
          return value === 0 ? 1 : 0;
        }
        return expr.op === "-" ? -value : value;
      }
      case "binary": {
        const left = asInt(evalExpr(expr.left));
        const right = asInt(evalExpr(expr.right));
        switch (expr.op) {
          case "+":
            return (left + right) | 0;
          case "-":
            return (left - right) | 0;
          case "*":
            return (left * right) | 0;
          case "/":
            if (right === 0) {
              throw new Error("Division by zero.");
            }
            return (left / right) | 0;
          case "%":
            if (right === 0) {
              throw new Error("Division by zero.");
            }
            return left % right;
          case "<":
            return left < right ? 1 : 0;
          case ">":
            return left > right ? 1 : 0;
          case "<=":
            return left <= right ? 1 : 0;
          case ">=":
            return left >= right ? 1 : 0;
          case "==":
            return left === right ? 1 : 0;
          case "!=":
            return left !== right ? 1 : 0;
          case "&&":
            return left !== 0 && right !== 0 ? 1 : 0;
          case "||":
            return left !== 0 || right !== 0 ? 1 : 0;
          default:
            throw new Error(`Unknown operator ${expr.op}.`);
        }
      }
      case "assign": {
        const value = evalExpr(expr.value);
        writeTarget(expr.target, value);
        return value;
      }
      case "index": {
        const arrayValue = evalExpr(expr.array);
        if (typeof arrayValue === "number" || typeof arrayValue === "string" || arrayValue.kind !== "array") {
          throw new Error("Indexing needs an array.");
        }
        const index = asInt(evalExpr(expr.index));
        const item = arrayValue.items[index];
        if (item === undefined) {
          throw new Error("Array index out of range.");
        }
        return item;
      }
      case "call":
        return call(expr.name, expr.args.map(evalExpr));
    }
  };

  const writeTarget = (target: Expr, value: Value | number | string): void => {
    if (target.kind === "var") {
      setVar(target.name, toValue(value));
      return;
    }
    if (target.kind === "index") {
      const arrayValue = evalExpr(target.array);
      if (typeof arrayValue === "number" || typeof arrayValue === "string" || arrayValue.kind !== "array") {
        throw new Error("Indexing needs an array.");
      }
      const index = asInt(evalExpr(target.index));
      if (index < 0 || index >= arrayValue.items.length) {
        throw new Error("Array index out of range.");
      }
      arrayValue.items[index] = asInt(value);
      return;
    }
    throw new Error("Cannot assign to that.");
  };

  const runStmt = (stmt: Stmt): void => {
    bump();
    switch (stmt.kind) {
      case "block":
        for (const item of stmt.body) {
          runStmt(item);
        }
        return;
      case "decl": {
        if (stmt.size !== undefined) {
          frames[frames.length - 1]?.set(stmt.name, {
            kind: "array",
            items: Array.from({ length: stmt.size }, () => 0),
          });
          return;
        }
        const value = stmt.init === undefined ? 0 : asInt(evalExpr(stmt.init));
        frames[frames.length - 1]?.set(stmt.name, { kind: "int", value });
        return;
      }
      case "if":
        if (asInt(evalExpr(stmt.test)) !== 0) {
          runStmt(stmt.consequent);
        } else if (stmt.alternate) {
          runStmt(stmt.alternate);
        }
        return;
      case "for": {
        if (stmt.init) {
          if ("kind" in stmt.init && stmt.init.kind === "decl") {
            runStmt(stmt.init);
          } else {
            evalExpr(stmt.init as Expr);
          }
        }
        while (stmt.test === undefined || asInt(evalExpr(stmt.test)) !== 0) {
          runStmt(stmt.body);
          if (stmt.inc) {
            evalExpr(stmt.inc);
          }
        }
        return;
      }
      case "return":
        throw new ReturnSignal(stmt.value === undefined ? 0 : asInt(evalExpr(stmt.value)));
      case "expr":
        evalExpr(stmt.expr);
    }
  };

  const call = (name: string, args: Array<Value | number | string>): number => {
    if (name === "printf") {
      output += formatPrintf(args);
      return 0;
    }
    const fn = functions.get(name);
    if (!fn) {
      throw new Error(`Unknown function '${name}'.`);
    }
    if (fn.params.length !== args.length) {
      throw new Error(`${name}() expected ${fn.params.length} argument(s).`);
    }
    const frame = new Map<string, Value>();
    fn.params.forEach((param, index) => {
      frame.set(param, toValue(args[index] ?? 0));
    });
    frames.push(frame);
    try {
      for (const stmt of fn.body) {
        runStmt(stmt);
      }
      return 0;
    } catch (error) {
      if (error instanceof ReturnSignal) {
        return error.value;
      }
      throw error;
    } finally {
      frames.pop();
    }
  };

  call("main", []);
  return output;
}

function toValue(value: Value | number | string): Value {
  if (typeof value === "number") {
    return { kind: "int", value: value | 0 };
  }
  if (typeof value === "string") {
    throw new Error("Cannot store a string in an int.");
  }
  return value;
}

function formatPrintf(args: Array<Value | number | string>): string {
  const format = args[0];
  if (typeof format !== "string") {
    throw new Error("printf() needs a format string.");
  }
  let index = 1;
  let result = "";
  for (let cursor = 0; cursor < format.length; cursor += 1) {
    const char = format[cursor];
    if (char !== "%") {
      result += char;
      continue;
    }
    const spec = format[cursor + 1];
    cursor += 1;
    if (spec === "%") {
      result += "%";
      continue;
    }
    const arg = args[index];
    index += 1;
    if (spec === "d") {
      result += String(typeof arg === "number" ? arg | 0 : arg && typeof arg === "object" && arg.kind === "int" ? arg.value : 0);
      continue;
    }
    if (spec === "s") {
      result += typeof arg === "string" ? arg : "";
      continue;
    }
    result += spec ?? "";
  }
  return result;
}
