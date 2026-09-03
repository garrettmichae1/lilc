const STORAGE_KEY = "lilc.onboarding.completed";

export const ONBOARDING_COPY = {
  pageCount: 2,
  page1Headline: "Write C. Press Run.",
  page1Line: "lilC runs your code locally",
  continueTitle: "Continue",
  page2Headline: "C stays free. Zero ads.",
  page2Line: "For students and developers.",
  getStartedTitle: "Get Started",
  skipTitle: "Skip",
} as const;

const TIP_KEY = "lilc.files.folderDragTip.seen";

export const FILES_FOLDER_TIP = "Create a folder, then drag C files into it.";

let memoryStore = new Map<string, string>();

function storage(): { getItem(key: string): string | null; setItem(key: string, value: string): void; removeItem(key: string): void } {
  try {
    if (typeof localStorage !== "undefined") {
      return localStorage;
    }
  } catch {
    /* private mode */
  }
  return {
    getItem: (key) => memoryStore.get(key) ?? null,
    setItem: (key, value) => {
      memoryStore.set(key, value);
    },
    removeItem: (key) => {
      memoryStore.delete(key);
    },
  };
}

export function needsOnboarding(): boolean {
  return storage().getItem(STORAGE_KEY) !== "1";
}

export function completeOnboarding(): void {
  storage().setItem(STORAGE_KEY, "1");
}

export function needsFilesFolderTip(): boolean {
  return storage().getItem(TIP_KEY) !== "1";
}

export function dismissFilesFolderTip(): void {
  storage().setItem(TIP_KEY, "1");
}

export function resetOnboardingForTests(): void {
  memoryStore = new Map();
  try {
    storage().removeItem(STORAGE_KEY);
    storage().removeItem(TIP_KEY);
  } catch {
    /* node / private mode */
  }
}
