import type { LocalCFile, LocalCFolder } from "./files";
import { starterFile } from "./files";

const DB_NAME = "lilc-web";
const STORE = "workspace";
const STATE_KEY = "state";
const LEGACY_KEY = "lilc.local.c.files";
const SELECTED_KEY = "lilc.local.selected.file";

export interface PersistedWorkspace {
  files: LocalCFile[];
  folders: LocalCFolder[];
  selectedFileID: string;
}

export async function loadPersistedWorkspace(): Promise<PersistedWorkspace> {
  const fromIDB = await readIDB();
  if (fromIDB && fromIDB.files.length > 0) {
    return fromIDB;
  }
  const fromLocal = readLocalStorage();
  if (fromLocal && fromLocal.files.length > 0) {
    await savePersistedWorkspace(fromLocal);
    return fromLocal;
  }
  const starter = starterFile();
  return { files: [starter], folders: [], selectedFileID: starter.relativePath };
}

export async function savePersistedWorkspace(state: PersistedWorkspace): Promise<void> {
  try {
    localStorage.setItem(SELECTED_KEY, state.selectedFileID);
    localStorage.setItem(
      LEGACY_KEY,
      JSON.stringify(
        state.files.map((file) => ({
          relativePath: file.relativePath,
          name: file.relativePath.split("/").pop(),
          code: file.code,
          updatedAt: file.updatedAt,
        })),
      ),
    );
  } catch {
    /* quota / private mode */
  }
  await writeIDB(state);
}

async function readIDB(): Promise<PersistedWorkspace | undefined> {
  try {
    const db = await openDB();
    return await new Promise((resolve, reject) => {
      const tx = db.transaction(STORE, "readonly");
      const request = tx.objectStore(STORE).get(STATE_KEY);
      request.onsuccess = () => {
        const value = request.result as PersistedWorkspace | undefined;
        resolve(value && Array.isArray(value.files) ? value : undefined);
      };
      request.onerror = () => reject(request.error);
    });
  } catch {
    return undefined;
  }
}

async function writeIDB(state: PersistedWorkspace): Promise<void> {
  try {
    const db = await openDB();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE, "readwrite");
      tx.objectStore(STORE).put(state, STATE_KEY);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  } catch {
    /* private mode */
  }
}

function openDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, 1);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(STORE)) {
        db.createObjectStore(STORE);
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

function readLocalStorage(): PersistedWorkspace | undefined {
  try {
    const raw = localStorage.getItem(LEGACY_KEY);
    if (!raw) {
      return undefined;
    }
    const parsed = JSON.parse(raw) as Array<{
      relativePath?: string;
      name?: string;
      code: string;
      updatedAt?: number | string;
    }>;
    if (!Array.isArray(parsed) || parsed.length === 0) {
      return undefined;
    }
    const files: LocalCFile[] = parsed.map((item) => ({
      relativePath: item.relativePath ?? item.name ?? "hello.c",
      code: item.code,
      updatedAt:
        typeof item.updatedAt === "number"
          ? item.updatedAt
          : item.updatedAt
            ? Date.parse(item.updatedAt)
            : Date.now(),
    }));
    const selected = localStorage.getItem(SELECTED_KEY);
    const selectedFileID =
      files.find((file) => file.relativePath === selected)?.relativePath ??
      files[0]?.relativePath ??
      "hello.c";
    return { files, folders: foldersFromFiles(files), selectedFileID };
  } catch {
    return undefined;
  }
}

export function foldersFromFiles(files: LocalCFile[]): LocalCFolder[] {
  const map = new Map<string, number>();
  for (const file of files) {
    const parts = file.relativePath.split("/");
    if (parts.length < 2) {
      continue;
    }
    for (let index = 1; index < parts.length; index += 1) {
      const relative = parts.slice(0, index).join("/");
      const previous = map.get(relative) ?? 0;
      map.set(relative, Math.max(previous, file.updatedAt));
    }
  }
  return [...map.entries()].map(([relativePath, updatedAt]) => ({
    relativePath,
    updatedAt,
  }));
}
