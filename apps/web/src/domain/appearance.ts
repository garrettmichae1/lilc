export type ColorWay = "light" | "dark";

export interface ThemePalette {
  background: string;
  panel: string;
  card: string;
  editor: string;
  line: string;
  accent: string;
  amber: string;
  silver: string;
  foreground: string;
  onAccent: string;
  error: string;
}

const light: ThemePalette = {
  background: "rgb(242, 242, 247)",
  panel: "rgb(255, 255, 255)",
  card: "rgb(255, 255, 255)",
  editor: "rgb(255, 255, 255)",
  line: "rgb(209, 209, 214)",
  accent: "rgb(0, 122, 255)",
  amber: "rgb(255, 149, 0)",
  silver: "rgb(142, 142, 147)",
  foreground: "rgb(28, 28, 30)",
  onAccent: "rgb(255, 255, 255)",
  error: "rgb(199, 26, 26)",
};

const dark: ThemePalette = {
  background: "rgb(0, 0, 0)",
  panel: "rgb(28, 28, 30)",
  card: "rgb(44, 44, 46)",
  editor: "rgb(28, 28, 30)",
  line: "rgb(68, 68, 70)",
  accent: "rgb(10, 132, 255)",
  amber: "rgb(255, 159, 10)",
  silver: "rgb(142, 142, 147)",
  foreground: "rgb(242, 242, 247)",
  onAccent: "rgb(255, 255, 255)",
  error: "rgb(255, 107, 107)",
};

export const palettes: Record<ColorWay, ThemePalette> = { light, dark };

export function titleForColorWay(way: ColorWay): string {
  return way === "light" ? "Light" : "Dark";
}

const STORAGE_KEY = "lilc.appearance.colorway";

export function loadColorWay(): ColorWay {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw === "phosphor" || raw === "original") {
      return "light";
    }
    if (raw === "light" || raw === "dark") {
      return raw;
    }
  } catch {
    /* private mode */
  }
  return "light";
}

export function saveColorWay(way: ColorWay): void {
  try {
    localStorage.setItem(STORAGE_KEY, way);
  } catch {
    /* private mode */
  }
}

export const SYNTAX_COLORING_KEY = "lilc.editor.syntaxColoring";

export const syntaxPalettes: Record<
  ColorWay,
  {
    control: string;
    type: string;
    preprocessor: string;
    op: string;
    string: string;
    comment: string;
    number: string;
  }
> = {
  dark: {
    control: "#C586C0",
    type: "#569CD6",
    preprocessor: "#569CD6",
    op: "#569CD6",
    string: "#CE9178",
    comment: "#6A9955",
    number: "#B5CEA8",
  },
  light: {
    control: "#AF00DB",
    type: "#0000FF",
    preprocessor: "#0000FF",
    op: "#0000FF",
    string: "#A31515",
    comment: "#008000",
    number: "#098658",
  },
};

export function loadSyntaxColoring(): boolean {
  try {
    return localStorage.getItem(SYNTAX_COLORING_KEY) === "1";
  } catch {
    return false;
  }
}

export function saveSyntaxColoring(on: boolean): void {
  try {
    localStorage.setItem(SYNTAX_COLORING_KEY, on ? "1" : "0");
  } catch {
    /* private mode */
  }
}

export function applyColorWay(way: ColorWay): void {
  const palette = palettes[way];
  const root = document.documentElement;
  root.dataset.theme = way;
  root.style.colorScheme = way;
  for (const [key, value] of Object.entries(palette)) {
    root.style.setProperty(`--${key}`, value);
  }
  const syntax = syntaxPalettes[way];
  for (const [key, value] of Object.entries(syntax)) {
    root.style.setProperty(`--syntax-${key}`, value);
  }
  const themeMeta = document.querySelector('meta[name="theme-color"]');
  if (themeMeta) {
    themeMeta.setAttribute("content", palette.background);
  }
}
