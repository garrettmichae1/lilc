const UNIT = "    ";

export interface IndentRange {
  start: number;
  end: number;
}

export function indentSelection(text: string, range: IndentRange, outdent: boolean): {
  text: string;
  range: IndentRange;
} {
  const inclusiveEnd = range.start === range.end ? range.start : Math.max(range.start, range.end - 1);
  const starts: number[] = [];
  let cursor = lineStartAt(text, Math.min(range.start, text.length));
  while (cursor <= inclusiveEnd && cursor <= text.length) {
    starts.push(cursor);
    const next = nextLineStart(text, cursor);
    if (next <= cursor) {
      break;
    }
    cursor = next;
    if (cursor > inclusiveEnd || cursor >= text.length) {
      break;
    }
  }

  let result = text;
  let totalDelta = 0;
  let firstDelta = 0;
  for (const [index, start] of starts.entries()) {
    const adjusted = start + totalDelta;
    if (outdent) {
      const removed = stripLeadingIndent(result, adjusted, UNIT.length);
      result = removed.text;
      if (index === 0) {
        firstDelta = -removed.removed;
      }
      totalDelta -= removed.removed;
    } else {
      result = result.slice(0, adjusted) + UNIT + result.slice(adjusted);
      if (index === 0) {
        firstDelta = UNIT.length;
      }
      totalDelta += UNIT.length;
    }
  }

  const location = Math.max(0, range.start + firstDelta);
  const length = Math.max(0, range.end - range.start + totalDelta - firstDelta);
  return {
    text: result,
    range: { start: location, end: location + length },
  };
}

function lineStartAt(text: string, offset: number): number {
  const clamped = Math.min(Math.max(0, offset), text.length);
  const index = text.lastIndexOf("\n", Math.max(0, clamped - 1));
  return index < 0 ? 0 : index + 1;
}

function nextLineStart(text: string, start: number): number {
  const newline = text.indexOf("\n", start);
  return newline < 0 ? text.length : newline + 1;
}

function stripLeadingIndent(text: string, location: number, max: number): { text: string; removed: number } {
  let removed = 0;
  let result = text;
  while (removed < max && location < result.length) {
    const character = result[location];
    if (character === " ") {
      result = result.slice(0, location) + result.slice(location + 1);
      removed += 1;
    } else if (character === "\t" && removed === 0) {
      result = result.slice(0, location) + result.slice(location + 1);
      return { text: result, removed: 1 };
    } else {
      break;
    }
  }
  return { text: result, removed };
}

/** 4-space C indent for the whole file. Conservative: braces, preprocessor, strings. */
export function formatC(source: string): string {
  const lines = source.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
  let depth = 0;
  let inBlockComment = false;
  const formatted = lines.map((line) => {
    const trimmed = line.trim();
    if (trimmed.length === 0) {
      return "";
    }
    const leadingClose = !inBlockComment && /^[\s}]*}/.test(line) && !trimmed.startsWith("{");
    const indentDepth = Math.max(0, depth - (leadingClose ? 1 : 0));
    const isPreprocessor = !inBlockComment && trimmed.startsWith("#");
    const isLabel = !inBlockComment && /^(case\b|default\s*:|[A-Za-z_][A-Za-z0-9_]*\s*:)/.test(trimmed);
    const spaces = isPreprocessor ? 0 : Math.max(0, indentDepth - (isLabel ? 1 : 0));
    const next = `${" ".repeat(spaces * 4)}${trimmed}`;
    const delta = braceDelta(trimmed, inBlockComment);
    inBlockComment = delta.inBlockComment;
    depth = Math.max(0, depth + delta.delta);
    return next;
  });
  const joined = formatted.join("\n");
  if (source.endsWith("\n") && !joined.endsWith("\n")) {
    return `${joined}\n`;
  }
  return joined;
}

function braceDelta(line: string, inBlockComment: boolean): { delta: number; inBlockComment: boolean } {
  let delta = 0;
  let inString = false;
  let inChar = false;
  let comment = inBlockComment;
  let escape = false;
  for (let index = 0; index < line.length; index += 1) {
    const character = line[index];
    const next = line[index + 1];
    if (comment) {
      if (character === "*" && next === "/") {
        comment = false;
        index += 1;
      }
      continue;
    }
    if (inString) {
      if (escape) {
        escape = false;
      } else if (character === "\\") {
        escape = true;
      } else if (character === '"') {
        inString = false;
      }
      continue;
    }
    if (inChar) {
      if (escape) {
        escape = false;
      } else if (character === "\\") {
        escape = true;
      } else if (character === "'") {
        inChar = false;
      }
      continue;
    }
    if (character === "/" && next === "/") {
      break;
    }
    if (character === "/" && next === "*") {
      comment = true;
      index += 1;
      continue;
    }
    if (character === '"') {
      inString = true;
      continue;
    }
    if (character === "'") {
      inChar = true;
      continue;
    }
    if (character === "{") {
      delta += 1;
    } else if (character === "}") {
      delta -= 1;
    }
  }
  return { delta, inBlockComment: comment };
}
