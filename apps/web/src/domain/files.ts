export interface LocalCFile {
  relativePath: string;
  code: string;
  updatedAt: number;
}

export interface LocalCFolder {
  relativePath: string;
  updatedAt: number;
}

export type LocalBrowserEntry =
  | { kind: "folder"; folder: LocalCFolder }
  | { kind: "file"; file: LocalCFile };

export function fileName(file: LocalCFile): string {
  const parts = file.relativePath.split("/");
  return parts[parts.length - 1] ?? file.relativePath;
}

export function folderName(folder: LocalCFolder): string {
  const parts = folder.relativePath.split("/");
  return parts[parts.length - 1] ?? folder.relativePath;
}

export function folderPath(file: LocalCFile): string {
  const index = file.relativePath.lastIndexOf("/");
  return index <= 0 ? "" : file.relativePath.slice(0, index);
}

export function parentPath(relative: string): string {
  const index = relative.lastIndexOf("/");
  return index <= 0 ? "" : relative.slice(0, index);
}

export function isHeader(file: LocalCFile): boolean {
  return fileName(file).toLowerCase().endsWith(".h");
}

export function sizeText(file: LocalCFile): string {
  const bytes = new TextEncoder().encode(file.code).length;
  if (bytes < 1024) {
    return `${bytes} B`;
  }
  return `${(bytes / 1024).toFixed(1)} KB`;
}

export function codePreview(file: LocalCFile): string {
  const line = file.code
    .split(/\r?\n/)
    .map((item) => item.trim())
    .find((item) => item.length > 0);
  return line ?? "Empty C file";
}

export function normalizedName(name: string): string {
  const trimmed = name.trim();
  const safe = Array.from(trimmed)
    .map((character) =>
      /[A-Za-z0-9._-]/.test(character) ? character : "-",
    )
    .join("");
  const fallback = safe.length === 0 ? "hello.c" : safe;
  const lower = fallback.toLowerCase();
  if (lower.endsWith(".c") || lower.endsWith(".h")) {
    return fallback;
  }
  return `${fallback}.c`;
}

export function normalizedFolderName(name: string): string {
  const trimmed = name.trim();
  const safe = Array.from(trimmed)
    .map((character) => (/[A-Za-z0-9_-]/.test(character) ? character : "-"))
    .join("");
  return safe.length === 0 ? "project" : safe;
}

export function deletingPathExtension(name: string): string {
  const index = name.lastIndexOf(".");
  return index <= 0 ? name : name.slice(0, index);
}

export function pathExtension(name: string): string {
  const index = name.lastIndexOf(".");
  return index <= 0 ? "" : name.slice(index + 1);
}

export const STARTER_CODE = `#include <stdio.h>

int add(int a, int b) {
    return a + b;
}

int main(void) {
    int x = add(5, 5);
    printf("hello from lilC\\n");
    printf("%d\\n", x);
    return 0;
}
`;

export function headerStarter(name: string): string {
  const token = name
    .toUpperCase()
    .split("")
    .map((character) => (/[A-Z0-9]/.test(character) ? character : "_"))
    .join("");
  return `#ifndef ${token}
#define ${token}

#endif
`;
}

export function helperStarter(name: string): string {
  const stem = deletingPathExtension(name);
  const ident = Array.from(stem)
    .map((character) => (/[A-Za-z0-9]/.test(character) ? character : "_"))
    .join("");
  const functionName = ident.length === 0 || /^[0-9]/.test(ident) ? "helper" : ident;
  return `#include <stdio.h>

/* helper — add functions here */

int ${functionName}(void) {
    return 0;
}
`;
}

export function sourceStarter(name: string, folderHasMain: boolean): string {
  if (name.endsWith(".h")) {
    return headerStarter(name);
  }
  return folderHasMain ? helperStarter(name) : STARTER_CODE;
}

export function starterFile(): LocalCFile {
  return {
    relativePath: "hello.c",
    code: STARTER_CODE,
    updatedAt: Date.now(),
  };
}

export function formatShortDate(timestamp: number): string {
  try {
    return new Intl.DateTimeFormat(undefined, {
      dateStyle: "medium",
      timeStyle: "short",
    }).format(new Date(timestamp));
  } catch {
    return new Date(timestamp).toLocaleString();
  }
}

export function localizedStandardCompare(a: string, b: string): number {
  return a.localeCompare(b, undefined, { numeric: true, sensitivity: "base" });
}
