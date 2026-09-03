import {
  displayOutput,
  parseDiagnostic,
  resolveErrorJump,
  type CErrorJump,
} from "./diagnostics";
import {
  codePreview,
  deletingPathExtension,
  fileName,
  folderName,
  folderPath,
  localizedStandardCompare,
  normalizedFolderName,
  normalizedName,
  parentPath,
  pathExtension,
  sizeText,
  sourceStarter,
  starterFile,
  type LocalBrowserEntry,
  type LocalCFile,
  type LocalCFolder,
} from "./files";
import { foldersFromFiles, loadPersistedWorkspace, savePersistedWorkspace } from "./storage";
import { PicoCRunner } from "../pico/runner";
import { finishConsoleOutput } from "./console-transcript";
import {
  isCurriculumFolder,
  lessonById,
  lessonForPath,
  lessonKicker,
  lessonRelativePath,
  nextIncomplete,
  type FirstHourLesson,
} from "./curriculum";
import {
  allTracksComplete,
  isLessonComplete,
  markLessonComplete,
  setCurrentLesson,
} from "./progress";
import { runFirstHourSubset } from "./subset";
import { appendNotYet, checkLessonWin, completeTheTaskMessage, replacePlaceholderMessage } from "./win";

export interface LessonOutcome {
  token: number;
  lessonId: string;
  status: "passed" | "missed";
  nextId: string | undefined;
  celebrate: boolean;
  replay: boolean;
}

export { codePreview, fileName, folderName, folderPath, sizeText };
export type { LocalBrowserEntry, LocalCFile, LocalCFolder };

const MAIN_PATTERN = /\bmain\s*\([^)]*\)\s*\{/;
const SYSTEM_PATTERN = /\bsystem\s*\(/;

export type WorkspaceListener = () => void;

export class LocalCWorkspace {
  files: LocalCFile[] = [];
  folders: LocalCFolder[] = [];
  selectedFileID = "hello.c";
  browsePath = "";
  output = "Local C workspace ready.";
  isRunning = false;
  isWaitingForInput = false;
  lastRunFailed = false;
  lastErrorJump: CErrorJump | undefined;
  stdinLine = "";
  engineNote = "";
  lessonOutcome: LessonOutcome | undefined;

  private liveRunID = 0;
  private lessonToken = 0;
  private persistTimer: ReturnType<typeof setTimeout> | undefined;
  private readonly listeners = new Set<WorkspaceListener>();
  private readonly runner = new PicoCRunner();

  async load(): Promise<void> {
    const persisted = await loadPersistedWorkspace();
    this.files = persisted.files;
    this.folders = persisted.folders.length > 0 ? persisted.folders : foldersFromFiles(this.files);
    this.selectedFileID = persisted.selectedFileID;
    if (!this.files.some((file) => file.relativePath === this.selectedFileID)) {
      this.selectedFileID = this.files[0]?.relativePath ?? starterFile().relativePath;
    }
    this.notify();
  }

  subscribe(listener: WorkspaceListener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  get currentFile(): LocalCFile {
    return this.files.find((file) => file.relativePath === this.selectedFileID) ?? this.files[0] ?? starterFile();
  }

  get currentProjectPath(): string {
    return folderPath(this.currentFile);
  }

  get isCurriculumCatalog(): boolean {
    return isCurriculumFolder(this.currentProjectPath);
  }

  /** Files shown as editor tabs. Catalog folders are a shelf of standalone programs, so only the open file is a tab. */
  get projectFiles(): LocalCFile[] {
    if (this.isCurriculumCatalog) {
      return [this.currentFile];
    }
    return this.files
      .filter((file) => folderPath(file) === this.currentProjectPath)
      .sort((lhs, rhs) => {
        if (fileName(lhs) === "main.c") {
          return -1;
        }
        if (fileName(rhs) === "main.c") {
          return 1;
        }
        return localizedStandardCompare(fileName(lhs), fileName(rhs));
      });
  }

  get editorTitle(): string {
    if (this.isCurriculumCatalog) {
      return fileName(this.currentFile);
    }
    if (this.currentProjectPath === "") {
      return "lilC";
    }
    return this.currentProjectPath.split("/").pop() ?? "lilC";
  }

  get recentProjects(): LocalCFolder[] {
    return this.rootFolders.sort((a, b) => b.updatedAt - a.updatedAt).slice(0, 3);
  }

  get rootFolders(): LocalCFolder[] {
    return this.folders.filter((folder) => parentPath(folder.relativePath) === "");
  }

  get allFiles(): LocalCFile[] {
    return [...this.files].sort((lhs, rhs) => {
      if (lhs.updatedAt === rhs.updatedAt) {
        return localizedStandardCompare(lhs.relativePath, rhs.relativePath);
      }
      return rhs.updatedAt - lhs.updatedAt;
    });
  }

  get browserEntries(): LocalBrowserEntry[] {
    const childFolders = this.folders
      .filter((folder) => parentPath(folder.relativePath) === this.browsePath)
      .sort((a, b) => localizedStandardCompare(folderName(a), folderName(b)));
    const childFiles = this.files
      .filter((file) => folderPath(file) === this.browsePath)
      .sort((a, b) => localizedStandardCompare(fileName(a), fileName(b)));
    return [
      ...childFolders.map((folder) => ({ kind: "folder" as const, folder })),
      ...childFiles.map((file) => ({ kind: "file" as const, file })),
    ];
  }

  get browseTitle(): string {
    return this.browsePath === "" ? "Files" : this.browsePath.split("/").pop() ?? "Files";
  }

  select(file: LocalCFile): void {
    this.selectedFileID = file.relativePath;
    this.browsePath = folderPath(file);
    this.persistSoon();
    this.notify();
  }

  revealErrorJump(): CErrorJump | undefined {
    const jump = this.lastErrorJump;
    if (!jump) {
      return undefined;
    }
    const file = this.files.find((item) => item.relativePath === jump.fileID);
    if (file) {
      this.select(file);
    }
    return jump;
  }

  openProject(folder: LocalCFolder): void {
    this.browsePath = folder.relativePath;
    if (
      !isCurriculumFolder(folder.relativePath) &&
      !this.files.some((file) => folderPath(file) === folder.relativePath)
    ) {
      this.createFileIn(folder.relativePath, "main.c");
    }
    const members = this.files.filter((file) => folderPath(file) === folder.relativePath);
    const preferred =
      members.find((file) => fileName(file) === "main.c") ??
      members.find((file) => fileName(file).endsWith(".c")) ??
      members[0];
    if (preferred) {
      this.select(preferred);
    }
  }

  goUpFromBrowse(): boolean {
    if (this.browsePath === "") {
      return false;
    }
    this.browsePath = parentPath(this.browsePath);
    this.notify();
    return true;
  }

  enterFolder(folder: LocalCFolder): void {
    this.browsePath = folder.relativePath;
    this.notify();
  }

  searchFiles(query: string): LocalCFile[] {
    const tokens = query.toLowerCase().split(/\s+/).filter(Boolean);
    if (tokens.length === 0) {
      return this.allFiles;
    }
    const ranked = this.allFiles.flatMap((file) => {
      const normalizedName = file.relativePath.toLowerCase();
      const normalizedCode = file.code.toLowerCase();
      if (!tokens.every((token) => normalizedName.includes(token) || normalizedCode.includes(token))) {
        return [];
      }
      const nameScore = tokens.filter((token) => normalizedName.includes(token)).length;
      return [{ file, nameScore }];
    });
    ranked.sort((lhs, rhs) => {
      if (lhs.nameScore === rhs.nameScore) {
        return rhs.file.updatedAt - lhs.file.updatedAt;
      }
      return rhs.nameScore - lhs.nameScore;
    });
    return ranked.map((item) => item.file);
  }

  searchBrowser(query: string): LocalBrowserEntry[] {
    const tokens = query.toLowerCase().split(/\s+/).filter(Boolean);
    if (tokens.length === 0) {
      return this.browserEntries;
    }
    const matchedFolders = this.folders.filter((folder) =>
      tokens.every((token) => folder.relativePath.toLowerCase().includes(token)),
    );
    const matchedFiles = this.searchFiles(query);
    return [
      ...matchedFolders.map((folder) => ({ kind: "folder" as const, folder })),
      ...matchedFiles.map((file) => ({ kind: "file" as const, file })),
    ];
  }

  deleteFile(file: LocalCFile): boolean {
    const index = this.files.findIndex((item) => item.relativePath === file.relativePath);
    if (index < 0) {
      return false;
    }
    this.files.splice(index, 1);
    this.ensureNotEmpty();
    if (!this.files.some((item) => item.relativePath === this.selectedFileID)) {
      this.selectedFileID = this.files[0]?.relativePath ?? starterFile().relativePath;
    }
    this.refreshFolders();
    this.output = `Deleted ${fileName(file)}.`;
    this.persistSoon();
    this.notify();
    return true;
  }

  fileCount(folder: LocalCFolder): number {
    return this.files.filter(
      (file) =>
        folderPath(file) === folder.relativePath ||
        file.relativePath.startsWith(`${folder.relativePath}/`),
    ).length;
  }

  deleteFolder(folder: LocalCFolder): void {
    this.files = this.files.filter(
      (file) =>
        file.relativePath !== folder.relativePath &&
        !file.relativePath.startsWith(`${folder.relativePath}/`),
    );
    this.folders = this.folders.filter(
      (item) =>
        item.relativePath !== folder.relativePath &&
        !item.relativePath.startsWith(`${folder.relativePath}/`),
    );
    if (this.browsePath === folder.relativePath || this.browsePath.startsWith(`${folder.relativePath}/`)) {
      this.browsePath = parentPath(folder.relativePath);
    }
    this.ensureNotEmpty();
    if (!this.files.some((file) => file.relativePath === this.selectedFileID)) {
      this.selectedFileID = this.files[0]?.relativePath ?? starterFile().relativePath;
    }
    this.output = `Deleted folder ${folderName(folder)}.`;
    this.persistSoon();
    this.notify();
  }

  deleteAllFiles(): void {
    const starter = starterFile();
    this.files = [starter];
    this.folders = [];
    this.browsePath = "";
    this.selectedFileID = starter.relativePath;
    this.output = "All local files erased.";
    this.persistSoon();
    this.notify();
  }

  createFile(): void {
    this.createFileIn(this.folderForNewFile(this.browsePath), undefined);
  }

  createStandaloneFile(): void {
    this.browsePath = "";
    this.createFileIn("", undefined);
  }

  openLesson(lesson: FirstHourLesson): void {
    setCurrentLesson(lesson.id);
    this.lessonOutcome = undefined;
    const relative = lessonRelativePath(lesson);
    const existing = this.files.find((file) => file.relativePath === relative);
    if (existing) {
      this.select(existing);
      this.output = `${lessonKicker(lesson)} — ${lesson.title}. Press RUN.`;
      this.notify();
      return;
    }
    const file = { relativePath: relative, code: lesson.source, updatedAt: Date.now() };
    this.files.unshift(file);
    this.selectedFileID = file.relativePath;
    this.output = `${lessonKicker(lesson)} — ${lesson.title}. Press RUN.`;
    this.refreshFolders();
    this.persistSoon();
    this.notify();
  }

  advanceAfterPass(): "celebrate" | FirstHourLesson | undefined {
    const outcome = this.lessonOutcome;
    this.lessonOutcome = undefined;
    if (!outcome || outcome.status !== "passed" || outcome.replay) {
      return undefined;
    }
    if (outcome.celebrate) {
      return "celebrate";
    }
    if (!outcome.nextId) {
      return undefined;
    }
    const next = lessonById(outcome.nextId);
    if (!next) {
      return undefined;
    }
    this.openLesson(next);
    return next;
  }

  evaluateLessonRun(output: string, failed: boolean): void {
    this.output = output;
    this.lastRunFailed = failed;
    this.applyLessonOutcome(this.currentFile, failed);
    this.notify();
  }

  openFreePlay(): void {
    this.lessonOutcome = undefined;
    const existing = this.files.find((file) => file.relativePath === "hello.c");
    if (existing) {
      this.select(existing);
      this.output = "Write any C program. Press RUN.";
      this.notify();
      return;
    }
    this.createStandaloneFile();
    this.output = "Write any C program. Press RUN.";
    this.notify();
  }

  applySharedSource(fileName: string, code: string): void {
    const relative = `shared/${fileName}`;
    const existing = this.files.find((file) => file.relativePath === relative);
    if (existing) {
      existing.code = code;
      existing.updatedAt = Date.now();
      this.select(existing);
      this.output = "Opened a shared program. Press RUN.";
      this.persistSoon();
      this.notify();
      return;
    }
    const file = { relativePath: relative, code, updatedAt: Date.now() };
    this.files.unshift(file);
    this.selectedFileID = file.relativePath;
    this.output = "Opened a shared program. Press RUN.";
    this.refreshFolders();
    this.persistSoon();
    this.notify();
  }

  createHeader(): void {
    const folder = this.folderForNewFile(this.browsePath);
    this.createFileIn(folder, this.availableFileName("module", "h", folder));
  }

  createFileIn(folder: string, requested: string | undefined): void {
    folder = this.folderForNewFile(folder);
    const name = requested ?? this.availableFileName("program", "c", folder);
    const relative = folder === "" ? name : `${folder}/${name}`;
    const code = sourceStarter(name, this.folderContainsMain(folder));
    const file: LocalCFile = { relativePath: relative, code, updatedAt: Date.now() };
    this.files.unshift(file);
    this.selectedFileID = file.relativePath;
    this.output = `Created ${relative}.`;
    this.refreshFolders();
    this.persistSoon();
    this.notify();
  }

  createFolder(rawName: string): void {
    const name = normalizedFolderName(rawName);
    const relative = this.browsePath === "" ? name : `${this.browsePath}/${name}`;
    let unique = relative;
    let index = 2;
    while (this.folders.some((folder) => folder.relativePath === unique)) {
      unique = `${relative}-${index}`;
      index += 1;
    }
    this.folders.push({ relativePath: unique, updatedAt: Date.now() });
    this.output = `Created folder ${unique}.`;
    this.persistSoon();
    this.notify();
  }

  moveFile(file: LocalCFile, destinationFolder: string): boolean {
    if (!this.files.some((item) => item.relativePath === file.relativePath)) {
      return false;
    }
    if (folderPath(file) === destinationFolder) {
      return true;
    }
    const destName = this.availableFileName(
      deletingPathExtension(fileName(file)),
      pathExtension(fileName(file)),
      destinationFolder,
    );
    const destRelative = destinationFolder === "" ? destName : `${destinationFolder}/${destName}`;
    const index = this.files.findIndex((item) => item.relativePath === file.relativePath);
    if (index < 0) {
      return false;
    }
    const current = this.files[index];
    if (!current) {
      return false;
    }
    current.relativePath = destRelative;
    current.updatedAt = Date.now();
    if (this.selectedFileID === file.relativePath) {
      this.selectedFileID = destRelative;
    }
    this.refreshFolders();
    this.output = `Moved ${fileName(file)} into ${destinationFolder === "" ? "Files" : destinationFolder}.`;
    this.persistSoon();
    this.notify();
    return true;
  }

  renameCurrentFile(to: string): void {
    const index = this.files.findIndex((file) => file.relativePath === this.selectedFileID);
    if (index < 0) {
      return;
    }
    const current = this.files[index];
    if (!current) {
      return;
    }
    const folder = folderPath(current);
    const newName = normalizedName(to);
    const destName = this.availableFileName(
      deletingPathExtension(newName),
      pathExtension(newName),
      folder,
      fileName(current),
    );
    const destRelative = folder === "" ? destName : `${folder}/${destName}`;
    current.relativePath = destRelative;
    current.updatedAt = Date.now();
    this.selectedFileID = destRelative;
    this.persistSoon();
    this.notify();
  }

  updateCurrentCode(code: string): void {
    const index = this.files.findIndex((file) => file.relativePath === this.selectedFileID);
    if (index < 0) {
      return;
    }
    const current = this.files[index];
    if (!current) {
      return;
    }
    current.code = code;
    current.updatedAt = Date.now();
    this.persistSoon();
  }

  async runCurrentFile(): Promise<void> {
    await this.startLiveRun();
  }

  submitStdinLine(): void {
    if (!this.isRunning) {
      return;
    }
    const line = this.stdinLine;
    this.stdinLine = "";
    this.isWaitingForInput = false;
    this.output += `${line}\n`;
    this.runner.feedStdin(`${line}\n`);
    this.notify();
  }

  sendStdinEOF(): void {
    this.runner.closeStdin();
  }

  stopLiveRun(): void {
    if (!this.isRunning) {
      return;
    }
    this.runner.requestStop();
  }

  extraSourcesToLink(runFile: LocalCFile): LocalCFile[] {
    if (this.currentProjectPath === "" || this.isCurriculumCatalog) {
      return [];
    }
    return this.projectFiles.filter(
      (file) =>
        file.relativePath !== runFile.relativePath &&
        fileName(file).endsWith(".c") &&
        !containsMainFunction(file.code),
    );
  }

  fileToCompile(): LocalCFile {
    const current = this.currentFile;
    if (this.isCurriculumCatalog || lessonForPath(current.relativePath)) {
      return current;
    }
    if (
      fileName(current).endsWith(".c") &&
      (containsMainFunction(current.code) || this.currentProjectPath === "")
    ) {
      return current;
    }
    return (
      this.projectFiles.find((file) => fileName(file) === "main.c") ??
      this.projectFiles.find((file) => fileName(file).endsWith(".c") && containsMainFunction(file.code)) ??
      this.projectFiles.find((file) => fileName(file).endsWith(".c")) ??
      current
    );
  }

  private async startLiveRun(): Promise<void> {
    if (this.isRunning) {
      this.runner.requestStop();
    }
    const runningLesson = lessonForPath(this.currentFile.relativePath);
    const projectMains = this.projectFiles.filter(
      (file) => fileName(file).endsWith(".c") && containsMainFunction(file.code),
    );
    if (!runningLesson && this.currentProjectPath !== "" && !isCurriculumFolder(this.currentProjectPath) && projectMains.length > 1) {
      this.liveRunID += 1;
      this.isRunning = false;
      this.isWaitingForInput = false;
      this.lastRunFailed = true;
      this.lastErrorJump = undefined;
      const names = projectMains.map((file) => fileName(file)).join(", ");
      const raw = `Cannot run this project: it has more than one main() function (${names}). Keep one main() and turn the others into helper functions.\n`;
      this.output = displayOutput(raw).text;
      this.notify();
      return;
    }

    const runFile = this.fileToCompile();
    if (runFile.code.includes("???")) {
      this.liveRunID += 1;
      this.isRunning = false;
      this.isWaitingForInput = false;
      this.lastRunFailed = false;
      this.lastErrorJump = undefined;
      const lesson = lessonForPath(runFile.relativePath);
      this.output = lesson ? completeTheTaskMessage(lesson) : replacePlaceholderMessage;
      this.lessonToken += 1;
      this.lessonOutcome = lesson
        ? {
            token: this.lessonToken,
            lessonId: lesson.id,
            status: "missed",
            nextId: undefined,
            celebrate: false,
            replay: false,
          }
        : undefined;
      this.notify();
      return;
    }
    const extras = this.extraSourcesToLink(runFile);
    const projectSnapshot = [...this.projectFiles];
    const extraCode = extras.map((file) => file.code).join("\n");
    const code = extraCode.length === 0 ? runFile.code : `${extraCode}\n${runFile.code}`;
    const filesForRun = this.filesForInclude(runFile);
    const mainName = fileName(runFile);
    this.liveRunID += 1;
    const runID = this.liveRunID;
    this.stdinLine = "";
    this.output = "";
    this.isRunning = true;
    this.isWaitingForInput = false;
    this.lastRunFailed = false;
    this.lastErrorJump = undefined;
    this.touchCurrentFile();
    this.notify();

    if (SYSTEM_PATTERN.test(code)) {
      this.finishRun(runID, "system() is not available in lilC local mode.\n", runFile, extras, projectSnapshot);
      return;
    }

    if (code.trim().length === 0) {
      this.finishRun(runID, "Write some C code, then run it.\n", runFile, extras, projectSnapshot);
      return;
    }

    this.engineNote = "";
    try {
      const result = await this.runner.runInteractive({
        source: code,
        mainName,
        includeRoot: this.currentProjectPath === "" ? "/project" : `/project/${this.currentProjectPath}`,
        files: filesForRun.map((file) => ({ path: file.relativePath, code: file.code })),
        onOutput: (chunk) => {
          if (this.liveRunID !== runID) {
            return;
          }
          this.output += chunk;
          this.notify();
        },
        onWaiting: (waiting) => {
          if (this.liveRunID !== runID) {
            return;
          }
          this.isWaitingForInput = waiting;
          this.notify();
        },
      });
      this.finishRun(runID, result, runFile, extras, projectSnapshot);
    } catch (error) {
      const subset = runFirstHourSubset(code);
      if (subset.ok) {
        this.engineNote =
          "First-hour subset. PicoC did not load in this browser. This is not GCC.";
        this.finishRun(runID, subset.output, runFile, extras, projectSnapshot);
        return;
      }
      const message =
        error instanceof Error ? error.message : "lilC could not start the local C engine.\n";
      this.finishRun(runID, `${message}\n`, runFile, extras, projectSnapshot);
    }
  }

  private finishRun(
    runID: number,
    result: string,
    runFile: LocalCFile,
    extras: LocalCFile[],
    projectSnapshot: LocalCFile[],
  ): void {
    if (this.liveRunID !== runID) {
      return;
    }
    const formatted = displayOutput(result);
    this.output = finishConsoleOutput(this.output, formatted.text, formatted.failed);
    this.lastRunFailed = formatted.failed;
    if (formatted.failed) {
      const diagnostic = parseDiagnostic(result);
      this.lastErrorJump = diagnostic
        ? resolveErrorJump(diagnostic, runFile, extras, projectSnapshot)
        : undefined;
    } else {
      this.lastErrorJump = undefined;
    }
    this.isRunning = false;
    this.isWaitingForInput = false;
    this.applyLessonOutcome(runFile, formatted.failed);
    this.notify();
  }

  private applyLessonOutcome(runFile: LocalCFile, runFailed: boolean): void {
    const lesson = lessonForPath(runFile.relativePath);
    if (!lesson) {
      this.lessonOutcome = undefined;
      return;
    }
    this.lessonToken += 1;
    const passed = !runFailed && checkLessonWin(lesson, this.output, runFile.code);
    if (!passed) {
      if (!runFailed || runFile.code.includes("???")) {
        this.output = appendNotYet(this.output, lesson);
      }
      this.lessonOutcome = {
        token: this.lessonToken,
        lessonId: lesson.id,
        status: "missed",
        nextId: undefined,
        celebrate: false,
        replay: false,
      };
      return;
    }
    if (isLessonComplete(lesson.id)) {
      this.output = `${this.output.replace(/\n+$/u, "")}\n\nNice.\n`;
      this.lessonOutcome = {
        token: this.lessonToken,
        lessonId: lesson.id,
        status: "passed",
        nextId: undefined,
        celebrate: false,
        replay: true,
      };
      return;
    }
    const progress = markLessonComplete(lesson.id);
    if (allTracksComplete(progress)) {
      this.output = `${this.output.replace(/\n+$/u, "")}\n\nNice. That was the last challenge.\n`;
      this.lessonOutcome = {
        token: this.lessonToken,
        lessonId: lesson.id,
        status: "passed",
        nextId: undefined,
        celebrate: true,
        replay: false,
      };
      return;
    }
    const next = nextIncomplete(lesson.id, progress.completedIds);
    this.output = `${this.output.replace(/\n+$/u, "")}\n\nNice.\n`;
    this.lessonOutcome = {
      token: this.lessonToken,
      lessonId: lesson.id,
      status: "passed",
      nextId: next?.id,
      celebrate: false,
      replay: false,
    };
  }

  private touchCurrentFile(): void {
    const index = this.files.findIndex((file) => file.relativePath === this.selectedFileID);
    if (index < 0) {
      return;
    }
    const current = this.files[index];
    if (!current) {
      return;
    }
    current.updatedAt = Date.now();
    this.persistSoon();
  }

  private folderForNewFile(folder: string): string {
    if (isCurriculumFolder(folder)) {
      if (this.browsePath === folder) {
        this.browsePath = "";
      }
      return "";
    }
    return folder;
  }

  private folderContainsMain(folder: string): boolean {
    if (folder === "") {
      return false;
    }
    return this.files.some(
      (file) =>
        folderPath(file) === folder && fileName(file).endsWith(".c") && containsMainFunction(file.code),
    );
  }

  private filesForInclude(runFile: LocalCFile): LocalCFile[] {
    if (!this.isCurriculumCatalog) {
      return this.files;
    }
    return this.files.filter(
      (file) =>
        file.relativePath === runFile.relativePath ||
        (folderPath(file) === this.currentProjectPath && fileName(file).endsWith(".h")),
    );
  }

  private availableFileName(base: string, ext: string, folder: string, ignoring?: string): string {
    const cleanExt = ext.length === 0 ? "c" : ext;
    let candidate = `${base}.${cleanExt}`;
    let index = 2;
    while (
      this.files.some(
        (file) => folderPath(file) === folder && fileName(file) === candidate && fileName(file) !== ignoring,
      )
    ) {
      candidate = `${base}-${index}.${cleanExt}`;
      index += 1;
    }
    return candidate;
  }

  private ensureNotEmpty(): void {
    if (this.files.length === 0) {
      this.files = [starterFile()];
    }
  }

  private refreshFolders(): void {
    const fromFiles = foldersFromFiles(this.files);
    const extras = this.folders.filter(
      (folder) => !fromFiles.some((item) => item.relativePath === folder.relativePath),
    );
    this.folders = [...fromFiles, ...extras];
  }

  private persistSoon(): void {
    if (this.persistTimer) {
      clearTimeout(this.persistTimer);
    }
    this.persistTimer = setTimeout(() => {
      void savePersistedWorkspace({
        files: this.files,
        folders: this.folders,
        selectedFileID: this.selectedFileID,
      });
    }, 80);
  }

  private notify(): void {
    for (const listener of this.listeners) {
      listener();
    }
  }
}

function containsMainFunction(code: string): boolean {
  return MAIN_PATTERN.test(code);
}
