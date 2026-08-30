export function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  options: {
    className?: string;
    text?: string;
    attrs?: Record<string, string | boolean | undefined>;
    on?: Partial<{ [E in keyof HTMLElementEventMap]: (event: HTMLElementEventMap[E]) => void }>;
    children?: Array<Node | string | undefined | false>;
  } = {},
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  if (options.className) {
    node.className = options.className;
  }
  if (options.text !== undefined) {
    node.textContent = options.text;
  }
  if (options.attrs) {
    for (const [key, value] of Object.entries(options.attrs)) {
      if (value === false || value === undefined) {
        continue;
      }
      if (value === true) {
        node.setAttribute(key, "");
      } else {
        node.setAttribute(key, value);
      }
    }
  }
  if (options.on) {
    for (const [name, handler] of Object.entries(options.on)) {
      if (handler) {
        node.addEventListener(name, handler as EventListener);
      }
    }
  }
  if (options.children) {
    for (const child of options.children) {
      if (!child) {
        continue;
      }
      node.append(child);
    }
  }
  return node;
}

export function clear(node: HTMLElement): void {
  node.replaceChildren();
}

export function svgIcon(path: string, size = 16): SVGSVGElement {
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("width", String(size));
  svg.setAttribute("height", String(size));
  svg.setAttribute("viewBox", "0 0 24 24");
  svg.setAttribute("fill", "none");
  svg.setAttribute("stroke", "currentColor");
  svg.setAttribute("stroke-width", "2.2");
  svg.setAttribute("stroke-linecap", "round");
  svg.setAttribute("stroke-linejoin", "round");
  svg.setAttribute("aria-hidden", "true");
  const item = document.createElementNS("http://www.w3.org/2000/svg", "path");
  item.setAttribute("d", path);
  svg.append(item);
  return svg;
}

export const icons = {
  chevronLeft: "M15 18l-6-6 6-6",
  chevronRight: "M9 6l6 6-6 6",
  chevronUp: "M6 15l6-6 6 6",
  chevronDown: "M6 9l6 6 6-6",
  plus: "M12 5v14M5 12h14",
  search: "M11 19a8 8 0 1 1 0-16 8 8 0 0 1 0 16zM21 21l-4.3-4.3",
  share: "M12 5v10M8 9l4-4 4 4M5 15v3a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-3",
  check: "M5 12l5 5L20 7",
  x: "M6 6l12 12M18 6L6 18",
  keyboard: "M4 8h16v10H4zM7 11h.01M11 11h.01M15 11h.01M7 15h10",
  indent: "M4 6h16M8 12h12M4 18h16M4 10v4",
  outdent: "M4 6h16M4 12h12M4 18h16M20 10v4",
  braces: "M8 4c-2 0-3 1.5-3 4s1 4 3 4c-2 0-3 1.5-3 4s1 4 3 4M16 4c2 0 3 1.5 3 4s-1 4-3 4c2 0 3 1.5 3 4s-1 4-3 4",
  star: "M12 3l2.6 5.3 5.8.8-4.2 4.1 1 5.8L12 16.9 6.8 19l1-5.8-4.2-4.1 5.8-.8z",
};
