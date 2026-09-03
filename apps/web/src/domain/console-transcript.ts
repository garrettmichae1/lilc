/** PicoC stdout has no TTY echo. The live console appends each submitted stdin
 * line; replacing that buffer with the runner's capture is what erased typed input. */
export function finishConsoleOutput(live: string, captured: string, failed: boolean): string {
  if (failed) {
    return captured.length === 0 ? live : captured;
  }
  if (live.length === 0) {
    return captured;
  }
  if (captured.length === 0) {
    return live;
  }
  if (isSubsequence(captured, live)) {
    return live;
  }
  const kept = longestSubsequencePrefixLength(captured, live);
  return live + captured.slice(kept);
}

export function isSubsequence(needle: string, haystack: string): boolean {
  return longestSubsequencePrefixLength(needle, haystack) === needle.length;
}

function longestSubsequencePrefixLength(needle: string, haystack: string): number {
  let hay = 0;
  let count = 0;
  for (let i = 0; i < needle.length; i += 1) {
    const character = needle[i];
    let found = false;
    while (hay < haystack.length) {
      const next = haystack[hay];
      hay += 1;
      if (next === character) {
        found = true;
        break;
      }
    }
    if (!found) {
      return count;
    }
    count += 1;
  }
  return count;
}
