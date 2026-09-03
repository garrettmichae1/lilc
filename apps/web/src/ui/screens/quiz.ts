import {
  latestQuizAttempt,
  recordQuizAttempt,
} from "../../domain/quiz-progress";
import {
  choiceLetter,
  isQuizReady,
  scoreQuiz,
  type CQuiz,
} from "../../domain/quizzes";
import { el, icons, svgIcon } from "../dom";

type Phase = "taking" | "results" | "review";

export class QuizScreen {
  readonly root: HTMLElement;
  private index = 0;
  private selected: number[];
  private phase: Phase;

  constructor(
    private readonly quiz: CQuiz,
    startInReview: boolean,
    private readonly back: () => void,
  ) {
    const latest = latestQuizAttempt(quiz.id);
    if (startInReview && latest && latest.selectedIndexes.length === quiz.questions.length) {
      this.selected = [...latest.selectedIndexes];
      this.phase = "review";
    } else {
      this.selected = Array(quiz.questions.length).fill(-1);
      this.phase = "taking";
    }
    this.root = el("div", { className: "screen" });
    this.paint();
  }

  private paint(): void {
    const children: HTMLElement[] = [this.topbar()];
    if (isQuizReady(this.quiz) && this.phase !== "results") {
      children.push(this.progressStrip());
    }
    if (!isQuizReady(this.quiz)) {
      children.push(this.comingSoon());
    } else if (this.phase === "results") {
      children.push(this.resultsBody());
    } else {
      children.push(this.questionBody(this.phase === "review"));
      children.push(this.nextBar());
    }
    this.root.replaceChildren(...children);
  }

  private topbar(): HTMLElement {
    const count =
      isQuizReady(this.quiz) && this.phase !== "results"
        ? el("div", {
            className: "muted mono quiz-count",
            attrs: { "aria-label": `Question ${this.index + 1} of ${this.quiz.questions.length}` },
            text: `${this.index + 1} / ${this.quiz.questions.length}`,
          })
        : undefined;
    return el("div", {
      className: "topbar quiz-topbar",
      children: [
        el("button", {
          className: "icon-btn",
          attrs: { type: "button", "aria-label": "Back" },
          on: { click: this.back },
          children: [svgIcon(icons.chevronLeft)],
        }),
        el("div", {
          className: "title quiz-topbar-title",
          text: this.quiz.title,
        }),
        count,
      ],
    });
  }

  private progressStrip(): HTMLElement {
    const total = Math.max(this.quiz.questions.length, 1);
    const width = ((this.index + 1) / total) * 100;
    return el("div", {
      className: "quiz-progress",
      attrs: { "aria-hidden": "true" },
      children: [el("span", { attrs: { style: `width:${width}%` } })],
    });
  }

  private comingSoon(): HTMLElement {
    return el("div", {
      className: "scroll pad",
      children: [
        el("div", { className: "swipe-card-title", text: "Questions coming soon" }),
        el("div", {
          className: "muted",
          attrs: { style: "font-size:16px;margin-top:12px;max-width:36em" },
          text: "This quiz card is ready. Drop the 20 questions into quizzes.json and they will show here.",
        }),
      ],
    });
  }

  private questionBody(reviewing: boolean): HTMLElement {
    const question = this.quiz.questions[this.index];
    if (!question) {
      return el("div", { className: "scroll" });
    }
    const picked = this.selected[this.index] ?? -1;
    const snippet =
      question.snippet && question.snippet.length > 0
        ? el("pre", { className: "quiz-snippet", text: question.snippet })
        : undefined;
    const explanation =
      reviewing && question.explanation
        ? el("div", { className: "muted", attrs: { style: "font-size:15px" }, text: question.explanation })
        : undefined;
    return el("div", {
      className: "scroll pad",
      attrs: { style: "gap:16px" },
      children: [
        question.title
          ? el("div", { className: "quiz-kicker mono", text: question.title })
          : undefined,
        el("div", { className: "quiz-prompt", text: question.prompt }),
        snippet,
        el("div", {
          className: "card quiz-choices",
          children: question.choices.flatMap((choice, choiceIndex) => {
            const row = el("button", {
              className: choiceClass(choiceIndex, picked, question.correctIndex, reviewing),
              attrs: {
                type: "button",
                disabled: reviewing ? "true" : undefined,
                "aria-pressed": !reviewing && choiceIndex === picked ? "true" : "false",
              },
              on: {
                click: () => {
                  if (reviewing) {
                    return;
                  }
                  this.selected[this.index] = choiceIndex;
                  this.paint();
                },
              },
              children: [
                el("span", { className: "quiz-letter", text: choiceLetter(choiceIndex) }),
                el("span", { className: "title-17", text: choice }),
              ],
            });
            if (choiceIndex === question.choices.length - 1) {
              return [row];
            }
            return [row, el("div", { className: "divider", attrs: { style: "margin-left:56px" } })];
          }),
        }),
        explanation,
      ],
    });
  }

  private nextBar(): HTMLElement {
    const last = this.index === this.quiz.questions.length - 1;
    const canAdvance = (this.selected[this.index] ?? -1) >= 0;
    const label = last ? (this.phase === "review" ? "Done" : "Submit") : "Next";
    return el("div", {
      className: "quiz-footer",
      children: [
        el("button", {
          className: "quiz-submit",
          attrs: {
            type: "button",
            disabled: this.phase === "taking" && !canAdvance ? "true" : undefined,
          },
          text: label,
          on: {
            click: () => {
              if (this.phase === "taking" && !canAdvance) {
                return;
              }
              if (last) {
                if (this.phase === "review") {
                  this.phase = "results";
                  this.paint();
                  return;
                }
                this.finish();
                return;
              }
              this.index += 1;
              this.paint();
            },
          },
        }),
      ],
    });
  }

  private resultsBody(): HTMLElement {
    const score = scoreQuiz(this.quiz, this.selected);
    const perfect = score === this.quiz.questions.length;
    return el("div", {
      className: "scroll pad",
      children: [
        el("div", { className: "quiz-score", text: `${score} / ${this.quiz.questions.length}` }),
        el("div", {
          className: "muted",
          attrs: { style: "font-size:16px" },
          text: perfect ? "Every answer correct." : "Review missed questions, or retake to improve.",
        }),
        el("span", { attrs: { style: "flex:1" } }),
        el("button", {
          className: "quiz-submit",
          attrs: { type: "button", style: "margin-top:24px" },
          text: "Review",
          on: {
            click: () => {
              this.index = 0;
              this.phase = "review";
              this.paint();
            },
          },
        }),
        el("button", {
          className: "link-btn",
          attrs: { type: "button", style: "align-self:center;min-height:44px" },
          text: "Retake",
          on: {
            click: () => {
              this.beginTaking();
            },
          },
        }),
      ],
    });
  }

  private finish(): void {
    recordQuizAttempt({
      quizId: this.quiz.id,
      selectedIndexes: [...this.selected],
      score: scoreQuiz(this.quiz, this.selected),
      total: this.quiz.questions.length,
      finishedAt: new Date().toISOString(),
    });
    this.phase = "results";
    this.paint();
  }

  private beginTaking(): void {
    this.selected = Array(this.quiz.questions.length).fill(-1);
    this.index = 0;
    this.phase = "taking";
    this.paint();
  }
}

function choiceClass(choice: number, picked: number, correct: number, reviewing: boolean): string {
  const classes = ["quiz-choice"];
  if (reviewing) {
    if (choice === correct) {
      classes.push("correct");
    } else if (choice === picked) {
      classes.push("missed");
    }
  } else if (choice === picked) {
    classes.push("picked");
  }
  return classes.join(" ");
}
