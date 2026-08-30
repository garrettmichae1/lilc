export interface SearchMatch {
  start: number;
  length: number;
}

export function findMatches(text: string, query: string): SearchMatch[] {
  const needle = query.trim();
  if (needle.length === 0) {
    return [];
  }
  const haystack = text.toLowerCase();
  const find = needle.toLowerCase();
  const matches: SearchMatch[] = [];
  let from = 0;
  while (from < haystack.length) {
    const index = haystack.indexOf(find, from);
    if (index < 0) {
      break;
    }
    matches.push({ start: index, length: needle.length });
    from = index + Math.max(needle.length, 1);
  }
  return matches;
}

export function offsetOfLine(text: string, line: number, column: number): { start: number; end: number } {
  const lines = text.split(/\n/);
  const target = Math.max(line, 1) - 1;
  let start = 0;
  for (let index = 0; index < lines.length && index < target; index += 1) {
    start += (lines[index]?.length ?? 0) + 1;
  }
  const lineText = lines[target] ?? "";
  const columnOffset = Math.min(Math.max(column, 1) - 1, lineText.length);
  const lineStart = start;
  const contentLength = lineText.endsWith("\r") ? lineText.length - 1 : lineText.length;
  return {
    start: lineStart + columnOffset,
    end: lineStart + Math.max(contentLength, columnOffset),
  };
}
