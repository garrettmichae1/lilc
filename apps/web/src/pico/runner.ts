export interface PicoFile {
  path: string;
  code: string;
}

export interface RunInteractiveOptions {
  source: string;
  mainName: string;
  includeRoot: string;
  files: PicoFile[];
  onOutput: (chunk: string) => void;
  onWaiting: (waiting: boolean) => void;
}

interface PicoModule {
  ccall: (
    name: string,
    returnType: string | null,
    argTypes: string[],
    args: unknown[],
    options?: { async?: boolean },
  ) => unknown;
  UTF8ToString: (ptr: number) => string;
  FS: {
    mkdir: (path: string) => void;
    writeFile: (path: string, data: string) => void;
    unlink: (path: string) => void;
    analyzePath: (path: string) => { exists: boolean; object?: { isFolder?: boolean } };
  };
  lilcOnOutput?: (text: string) => void;
  lilcOnWaiting?: (waiting: boolean) => void;
}

type PicoFactory = (options: {
  locateFile: (path: string, prefix: string) => string;
  lilcOnOutput?: (text: string) => void;
  lilcOnWaiting?: (waiting: boolean) => void;
}) => Promise<PicoModule>;

export class PicoCRunner {
  private module: PicoModule | undefined;
  private loadError: string | undefined;
  private loading: Promise<PicoModule> | undefined;

  async ensureReady(): Promise<PicoModule> {
    if (this.module) {
      return this.module;
    }
    if (this.loadError) {
      throw new Error(this.loadError);
    }
    if (!this.loading) {
      this.loading = loadPicoModule();
    }
    try {
      this.module = await this.loading;
      return this.module;
    } catch (error) {
      this.loadError =
        error instanceof Error
          ? error.message
          : "lilC could not start the local C engine.";
      throw new Error(this.loadError);
    }
  }

  async runInteractive(options: RunInteractiveOptions): Promise<string> {
    const module = await this.ensureReady();
    module.lilcOnOutput = options.onOutput;
    module.lilcOnWaiting = options.onWaiting;
    mountProjectFiles(module, options.files);
    const pointer = await (module.ccall(
      "lilc_picoc_run_source_interactive_project",
      "number",
      ["string", "string", "number", "number", "string"],
      [options.source, options.mainName, 0, 0, options.includeRoot],
      { async: true },
    ) as Promise<number>);
    if (!pointer) {
      return "lilC could not start the local C engine.\n";
    }
    const text = module.UTF8ToString(pointer);
    module.ccall("lilc_picoc_free_output", null, ["number"], [pointer]);
    return text;
  }

  feedStdin(text: string): void {
    if (!this.module) {
      return;
    }
    this.module.ccall("lilc_picoc_feed_stdin", "number", ["string", "number"], [text, lengthBytes(text)]);
  }

  closeStdin(): void {
    this.module?.ccall("lilc_picoc_close_stdin", null, [], []);
  }

  requestStop(): void {
    this.module?.ccall("lilc_picoc_request_stop", null, [], []);
  }
}

function lengthBytes(text: string): number {
  return new TextEncoder().encode(text).length;
}

function mountProjectFiles(module: PicoModule, files: PicoFile[]): void {
  ensureDir(module, "/project");
  for (const file of files) {
    const full = `/project/${file.path}`;
    const parent = full.slice(0, full.lastIndexOf("/"));
    ensureDir(module, parent);
    module.FS.writeFile(full, file.code);
  }
}

function ensureDir(module: PicoModule, path: string): void {
  const parts = path.split("/").filter(Boolean);
  let cursor = "";
  for (const part of parts) {
    cursor += `/${part}`;
    try {
      const info = module.FS.analyzePath(cursor);
      if (!info.exists) {
        module.FS.mkdir(cursor);
      }
    } catch {
      try {
        module.FS.mkdir(cursor);
      } catch {
        /* already exists */
      }
    }
  }
}

async function loadPicoModule(): Promise<PicoModule> {
  const scriptUrl = new URL("picoc.js", document.baseURI).href;
  const wasmUrl = new URL("picoc.wasm", document.baseURI).href;
  let factory: PicoFactory;
  try {
    const imported = (await import(/* @vite-ignore */ scriptUrl)) as { default: PicoFactory };
    factory = imported.default;
  } catch {
    throw new Error("lilC could not start the local C engine.");
  }
  return factory({
    locateFile: (path) => (path.endsWith(".wasm") ? wasmUrl : path),
  });
}
