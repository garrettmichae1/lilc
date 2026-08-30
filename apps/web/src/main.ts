import { LocalCWorkspace } from "./domain/workspace";
import "./styles/app.css";
import { App } from "./ui/app";

const root = document.querySelector("#app");
if (!(root instanceof HTMLElement)) {
  throw new Error("lilC could not find #app.");
}

const workspace = new LocalCWorkspace();
void workspace.load().then(
  () => {
    new App(root, workspace);
  },
  () => {
    new App(root, workspace);
  },
);
