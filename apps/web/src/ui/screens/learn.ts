import {
  challengeLessons,
  firstHourLessons,
  lessonKicker,
  type FirstHourLesson,
} from "../../domain/curriculum";
import {
  isLessonComplete,
  loadProgress,
  type FirstHourProgress,
} from "../../domain/progress";
import {
  bestQuizAttempt,
  hasTakenQuiz,
} from "../../domain/quiz-progress";
import {
  QUIZ_DECK_TITLE,
  quizKicker,
  quizzes,
  type CQuiz,
} from "../../domain/quizzes";
import type { LocalCWorkspace } from "../../domain/workspace";
import { mainTabBar } from "../components/chrome";
import { el } from "../dom";

export function renderLearn(
  workspace: LocalCWorkspace,
  actions: {
    openHome: () => void;
    openFiles: () => void;
    openEditor: () => void;
    openQuiz: (quiz: CQuiz, review: boolean) => void;
  },
): HTMLElement {
  const progress = loadProgress();
  return el("div", {
    className: "screen",
    children: [
      el("div", {
        className: "scroll",
        children: [
          el("div", {
            className: "pad",
            children: [
              el("div", { className: "learn-title", text: "Learn" }),
              lessonDeck("Lessons", firstHourLessons, progress, workspace, actions.openEditor),
              lessonDeck("Challenges", challengeLessons, progress, workspace, actions.openEditor),
              quizzes.length > 0 ? quizDeck(QUIZ_DECK_TITLE, quizzes, actions.openQuiz) : undefined,
              linuxCourseTeaser(),
            ],
          }),
        ],
      }),
      mainTabBar({
        active: "learn",
        openHome: actions.openHome,
        openLearn: () => undefined,
        openFiles: actions.openFiles,
      }),
    ],
  });
}

function deckHeader(title: string, done: number, total: number): HTMLElement {
  const percent = total === 0 ? 0 : Math.round((done / total) * 100);
  return el("div", {
    className: "deck-header",
    children: [
      el("div", {
        className: "row-between",
        children: [
          el("div", { className: "section-label", text: title }),
          el("span", {
            className: "hour-count mono",
            attrs: { "aria-label": `${done} of ${total} complete` },
            text: `${done}/${total}`,
          }),
        ],
      }),
      el("div", {
        className: "deck-bar",
        attrs: {
          role: "progressbar",
          "aria-label": title,
          "aria-valuemin": "0",
          "aria-valuemax": String(total),
          "aria-valuenow": String(done),
        },
        children: [el("div", { className: "deck-bar-fill", attrs: { style: `width:${percent}%` } })],
      }),
    ],
  });
}

function deckIndexLabel(index: number, total: number): HTMLElement {
  return el("div", {
    className: "deck-index mono",
    attrs: { "aria-live": "polite" },
    text: `${index} / ${total}`,
  });
}

function setDeckIndex(label: HTMLElement, activeId: string, ids: readonly string[]): void {
  const index = ids.indexOf(activeId);
  label.textContent = `${Math.max(1, index + 1)} / ${ids.length}`;
}

function lessonDeck(
  title: string,
  lessons: FirstHourLesson[],
  progress: FirstHourProgress,
  workspace: LocalCWorkspace,
  openEditor: () => void,
): HTMLElement {
  const startId = lessons.find((lesson) => !progress.completedIds.includes(lesson.id))?.id ?? lessons[0]?.id;
  const scroller = el("div", {
    className: "lesson-deck",
    attrs: { role: "list", tabindex: "0", "aria-label": title },
  });
  const ids = lessons.map((lesson) => lesson.id);
  const indexLabel = deckIndexLabel(Math.max(1, ids.indexOf(startId ?? "") + 1), lessons.length);

  for (const lesson of lessons) {
    const complete = isLessonComplete(lesson.id);
    const card = el("button", {
      className: "lesson-swipe-card",
      attrs: {
        type: "button",
        role: "listitem",
        "data-lesson-id": lesson.id,
        "aria-label": `${lessonKicker(lesson)}. ${lesson.title}. ${complete ? "Replay" : "Open"}`,
      },
      on: {
        click: () => {
          workspace.openLesson(lesson);
          openEditor();
        },
      },
      children: [
        el("div", {
          className: "swipe-card-top",
          children: [
            el("div", { className: "lesson-kicker mono", text: lessonKicker(lesson) }),
            complete
              ? el("span", {
                  className: "lesson-star",
                  attrs: { "aria-label": "Completed" },
                  text: "★",
                })
              : undefined,
          ],
        }),
        el("div", { className: "swipe-card-title", text: lesson.title }),
        el("div", { className: "swipe-card-goal", text: lesson.goal }),
        el("div", { className: "swipe-card-cta", text: complete ? "Replay" : "Open" }),
      ],
    });
    scroller.append(card);
  }

  const activeFromScroll = (): string => {
    const cards = [...scroller.querySelectorAll<HTMLElement>("[data-lesson-id]")];
    const mid = scroller.scrollLeft + scroller.clientWidth / 2;
    let best = startId ?? "";
    let bestDist = Number.POSITIVE_INFINITY;
    for (const card of cards) {
      const center = card.offsetLeft + card.offsetWidth / 2;
      const dist = Math.abs(center - mid);
      if (dist < bestDist) {
        bestDist = dist;
        best = card.dataset.lessonId ?? best;
      }
    }
    return best;
  };

  scroller.addEventListener("scroll", () => {
    setDeckIndex(indexLabel, activeFromScroll(), ids);
  });

  queueMicrotask(() => {
    const target = scroller.querySelector<HTMLElement>(`[data-lesson-id="${startId ?? ""}"]`);
    target?.scrollIntoView({ inline: "start", block: "nearest" });
    setDeckIndex(indexLabel, startId ?? "", ids);
  });

  const done = lessons.filter((lesson) => progress.completedIds.includes(lesson.id)).length;
  return el("div", {
    className: "lesson-deck-wrap",
    children: [
      deckHeader(title, done, lessons.length),
      progress.streak > 1 && title === "Lessons"
        ? el("div", {
            className: "muted",
            attrs: { style: "font-size:13px" },
            text: `${progress.streak}-day streak`,
          })
        : undefined,
      scroller,
      indexLabel,
    ],
  });
}

function quizDeck(
  title: string,
  items: CQuiz[],
  openQuiz: (quiz: CQuiz, review: boolean) => void,
): HTMLElement {
  const startId = items.find((quiz) => !hasTakenQuiz(quiz.id))?.id ?? items[0]?.id;
  const scroller = el("div", {
    className: "lesson-deck",
    attrs: { role: "list", tabindex: "0", "aria-label": title },
  });
  const ids = items.map((quiz) => quiz.id);
  const indexLabel = deckIndexLabel(Math.max(1, ids.indexOf(startId ?? "") + 1), items.length);

  for (const quiz of items) {
    const attempt = bestQuizAttempt(quiz.id);
    const actions = attempt
      ? el("div", {
          className: "swipe-card-ctas",
          children: [
            el("button", {
              className: "swipe-card-cta",
              attrs: { type: "button" },
              text: "Review",
              on: {
                click: (event) => {
                  event.stopPropagation();
                  openQuiz(quiz, true);
                },
              },
            }),
            el("button", {
              className: "swipe-card-cta",
              attrs: { type: "button" },
              text: "Retake",
              on: {
                click: (event) => {
                  event.stopPropagation();
                  openQuiz(quiz, false);
                },
              },
            }),
          ],
        })
      : el("div", { className: "swipe-card-cta", text: "Start" });
    const card = el(attempt ? "div" : "button", {
      className: "lesson-swipe-card quiz-swipe-card",
      attrs: {
        type: attempt ? undefined : "button",
        role: "listitem",
        "data-quiz-id": quiz.id,
        "aria-label": attempt
          ? `${quizKicker(quiz)}. ${quiz.title}. ${attempt.score} of ${attempt.total}.`
          : `${quizKicker(quiz)}. ${quiz.title}. Start`,
      },
      ...(attempt
        ? {}
        : {
            on: {
              click: () => {
                openQuiz(quiz, false);
              },
            },
          }),
      children: [
        el("div", {
          className: "swipe-card-top",
          children: [
            el("div", { className: "lesson-kicker mono", text: quizKicker(quiz) }),
            attempt
              ? el("span", {
                  className: "swipe-card-score",
                  attrs: { "aria-label": `Best score ${attempt.score} of ${attempt.total}` },
                  text: `${attempt.score}/${attempt.total}`,
                })
              : undefined,
          ],
        }),
        el("div", { className: "swipe-card-title", text: quiz.title }),
        el("div", { className: "swipe-card-goal", text: quiz.goal }),
        actions,
      ],
    });
    scroller.append(card);
  }

  const activeFromScroll = (): string => {
    const cards = [...scroller.querySelectorAll<HTMLElement>("[data-quiz-id]")];
    const mid = scroller.scrollLeft + scroller.clientWidth / 2;
    let best = startId ?? "";
    let bestDist = Number.POSITIVE_INFINITY;
    for (const card of cards) {
      const center = card.offsetLeft + card.offsetWidth / 2;
      const dist = Math.abs(center - mid);
      if (dist < bestDist) {
        bestDist = dist;
        best = card.dataset.quizId ?? best;
      }
    }
    return best;
  };

  scroller.addEventListener("scroll", () => {
    setDeckIndex(indexLabel, activeFromScroll(), ids);
  });

  queueMicrotask(() => {
    const target = scroller.querySelector<HTMLElement>(`[data-quiz-id="${startId ?? ""}"]`);
    target?.scrollIntoView({ inline: "start", block: "nearest" });
    setDeckIndex(indexLabel, startId ?? "", ids);
  });

  const done = items.filter((quiz) => hasTakenQuiz(quiz.id)).length;
  return el("div", {
    className: "lesson-deck-wrap",
    children: [deckHeader(title, done, items.length), scroller, indexLabel],
  });
}

function linuxCourseTeaser(): HTMLElement {
  return el("div", {
    className: "lesson-deck-wrap",
    children: [
      el("div", { className: "section-label", text: "Course" }),
      el("div", {
        className: "lesson-swipe-card linux-course-teaser",
        attrs: {
          role: "note",
          "aria-label": "Linux course. Unix, the kernel, and the shell. Unlock it in the lilC iPhone app.",
        },
        children: [
          el("div", { className: "lesson-kicker", text: "On iPhone" }),
          el("div", { className: "swipe-card-title", text: "Linux" }),
          el("div", {
            className: "swipe-card-goal",
            text: "Unix, the kernel, and the shell. Unlock the course in the lilC iPhone app. C lessons stay free here.",
          }),
        ],
      }),
    ],
  });
}
