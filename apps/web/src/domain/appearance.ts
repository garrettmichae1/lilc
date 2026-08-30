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

export function applyColorWay(way: ColorWay): void {
  const palette = palettes[way];
  const root = document.documentElement;
  root.dataset.theme = way;
  root.style.colorScheme = way;
  for (const [key, value] of Object.entries(palette)) {
    root.style.setProperty(`--${key}`, value);
  }
  const themeMeta = document.querySelector('meta[name="theme-color"]');
  if (themeMeta) {
    themeMeta.setAttribute("content", palette.background);
  }
}
