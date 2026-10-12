# vibe-quiz — Spec (v0.2)

> Repo: `vibe-quiz`, public, MIT license.

## 1. Problem

With auto mode on, it's easy to skim Claude's replies and keep going. The project moves forward, but your understanding doesn't. After a few days you own a codebase (or a research write-up) you can't explain or defend.

**vibe-quiz** keeps you in the loop. Every now and then it pops up a few short multiple-choice questions about what was just built and, more importantly, *why*. You can tune how often and how deep.

## 2. Goals and non-goals

**Goals**
- Questions are grounded in *this* session's actual work: the diff, decisions taken, and research findings. No generic trivia.
- Configurable frequency and depth, with sensible defaults that don't annoy.
- Answering takes about 30 seconds: clickable multiple choice, and skipping is always possible.
- Feedback teaches: a wrong answer gets a short explanation that points to the relevant file or decision.
- Simple: a couple of commands and a handful of settings.

**Non-goals (for now)**
- Tracking scores, history, streaks or weak spots. Each quiz stands on its own.
- Grading or reporting to anyone else (no team dashboards, no "manager mode").
- Teaching general programming. Questions are about *your project*.
- Blocking work. A quiz is never mandatory.

## 3. Core loop

```
work happens → trigger fires → quiz skill gathers context
→ writes N questions → asks via multiple choice → user answers
→ immediate feedback → Claude ends its turn → work continues on the user's next message
```

## 4. Triggers (frequency)

| Mode | Fires when | Mechanism |
|---|---|---|
| `manual` | User runs `/vibe-quiz:quiz` | Skill only |
| `turns` (default) | Every N times Claude finishes a reply | `Stop` hook + counter |
| `commits` | Every N git commits made during the session | `PostToolUse` hook (`if: "Bash(git commit *)"`) adds to the counter; the `Stop` hook delivers the quiz |

`/vibe-quiz:quiz` always works, regardless of mode.

**Delivery.** A quiz only ever starts from the `Stop` hook. When it fires, the hook returns `hookSpecificOutput.additionalContext` telling Claude to run the quiz skill. `PostToolUse` only counts, because context it injects arrives next to a tool result in the middle of a tool chain, not at a natural pause. ([hooks docs](https://code.claude.com/docs/en/hooks))

Both hooks run `sh ${CLAUDE_PLUGIN_ROOT}/scripts/auto-quiz.sh` (POSIX `sh`, no dependencies, no executable bit needed). Every finished reply counts as a turn, including one that ran a manual quiz.

**Guards.** Don't fire when:
- `stop_hook_active` is true (prevents loops; that reply isn't counted either)
- the moment is busy: `background_tasks` or `session_crons` is non-empty (work is running, or a `/loop` is scheduled), or Claude's last reply ends with a question to the user. The quiz stays due, but fires anyway at 2× the interval, because a dev server or watcher can stay listed all session
- the session is paused (the due quiz is used up)

Subagents fire `SubagentStop`, not `Stop`, so they never start a quiz.

**Non-interactive runs.** A hook can't tell it is running under `claude -p` or CI, and in those runs the multiple-choice prompt doesn't exist. So the hook calls the skill with `--auto`, and an `--auto` quiz without AskUserQuestion does nothing. In practice `claude -p` already denies the model's Skill call (nobody can approve it), and the hook message tells Claude to end its turn silently in that case; this was tested. In an interactive session the first automatic quiz asks permission to run the skill; choosing "always allow" (or `Skill(vibe-quiz:quiz *)` in `permissions.allow`, since the hook passes `--auto`) avoids the prompt after that. The plain-text fallback is only for a manual `/vibe-quiz:quiz`.

**Dropped: `session_end`.** `SessionEnd` can't continue the conversation, and a quiz carried over to the next session would have lost the decisions from this one. It may come back later as an explicit wrap-up command.

## 5. Question design

### Sources (by `focus` setting)
- **decisions**: why approach A over B, trade-offs accepted, constraints that shaped the design, and research conclusions with what they rest on.
- **implementation**: what a piece of code does, data flow, what breaks if X changes, where something lives.
- **both** (default): mix, weighted toward decisions.

Context comes from the recent conversation, `git status` / `git diff` / `git log` for this session, and files touched.

### Depth levels

| Level | Tests | Example |
|---|---|---|
| `recall` | What was done | "Which library did we add for date parsing?" |
| `understand` | Why it was done | "Why is the cache invalidated on write instead of on a timer?" |
| `apply` | Consequences / transfer | "If two users edit the same row at once, what happens with the current lock strategy?" |
| `challenge` | Critique / alternatives | "Which weakness of our retry logic would matter most at 10× traffic?" |

### Format rules
- Multiple choice, **4 options**, exactly one correct. AskUserQuestion takes 1–4 questions per prompt with 2–4 options each, so a quiz is at most 4 questions and fits in one prompt.
- Distractors must be plausible: real alternatives that were considered, common misconceptions, or nearby facts from the same session.
- Spread the correct answer across positions; it must not be the longest or most hedged option.
- Every question must be answerable from what happened in the session. Nothing that needs outside knowledge.
- No gotchas: no line numbers or exact variable names unless the depth is `recall`.
- Each question carries a one-line explanation and a pointer to its source (file, commit, or "decision made at …").
- The answer key is never shown before the user has answered.

## 6. Feedback

- Correct answer: `✓ Q1`, nothing more.
- Wrong answer: the correct answer, the one-line explanation and the source pointer.
- Then one summary line, e.g. "2/3 · missed: auth token refresh". Then Claude ends its turn.

**Disputes.** If the user says an answer was marked wrong unfairly, Claude re-checks the source and corrects itself if the user is right. Claude wrote the questions about its own work, so it can misremember.

**Skipping.** The four slots in the prompt are all answers, so there is no "skip" option. The user skips by pressing Esc or by picking "Other" and typing "skip"; the intro line says so. If the prompt times out because the user is away, it submits only the questions already answered; those are graded and the rest count as skipped. Nothing is recorded either way.

## 7. Configuration

All settings live in `userConfig` in `.claude-plugin/plugin.json`. Claude Code prompts for them on enable and shows them as rows in `/config`. `options` fields need Claude Code v2.1.271 or later.

| Key | Type | Default | Notes |
|---|---|---|---|
| `trigger` | `manual` / `turns` / `commits` | `turns` | When quizzes fire automatically |
| `interval` | number 1–50 | `8` | N for `turns` / `commits` |
| `questions_per_quiz` | number 1–4 | `3` | One prompt per quiz |
| `depth` | `recall` / `understand` / `apply` / `challenge` | `understand` | |
| `focus` | `decisions` / `implementation` / `both` | `both` | What questions are about |

## 8. Commands

| Name | Purpose |
|---|---|
| `/vibe-quiz:quiz [topic] [--depth X]` | Quiz now, optionally on a topic or at a given depth |
| `/vibe-quiz:pause [n\|off]` | Pause automatic quizzes for this session, skip the next n (max 99), or resume (`off`). User-only: Claude can't invoke it |

That's all for now. More commands only when there's a clear need.

## 9. State and storage

Only what automatic triggers need.

- `${CLAUDE_PLUGIN_DATA}/sessions/<session_id>.state`: `key=value` lines with turns and commits since the last quiz, and the pause state. Counted per session, so parallel sessions and worktrees don't interfere.
- Written only by bundled scripts. `CLAUDE_PLUGIN_DATA` is exported to hook processes but not to Claude's Bash tool, so the pause skill calls `scripts/auto-quiz.sh pause` with `${CLAUDE_PLUGIN_DATA}` and `${CLAUDE_SESSION_ID}` substituted into its Markdown.
- When a quiz fires, the script prunes session files older than about a week.
- No answers, scores or source code are stored. Claude Code deletes the data folder when the plugin is uninstalled.

## 10. Repo layout

```
vibe-quiz/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── skills/
│   ├── quiz/
│   │   └── SKILL.md            (includes the question-writing guide)
│   └── pause/SKILL.md
├── hooks/hooks.json
├── scripts/auto-quiz.sh
├── tests/auto-quiz-test.sh
├── .github/workflows/validate.yml
├── evals/                   (v0.3)
├── SPEC.md
├── README.md
├── LICENSE                  (MIT)
└── .gitignore
```

## 11. Milestones

1. **v0.1 Manual (done):** `quiz` skill + `/vibe-quiz:quiz` + userConfig. Use it on your own projects.
2. **v0.2 Automatic (done):** `Stop` hook + counter script for `turns` and `commits`, with the guards from §4; `/vibe-quiz:pause`; `trigger` defaults to `turns`; `claude plugin validate --strict` in CI.
3. **v0.3 Polish:** 3–5 `claude plugin eval` cases for question quality (grounded, no answer leakage, varied answer position); README with demo GIF. Done so far: `marketplace.json`, a publish-ready README (install, what the plugin runs and stores) and the demo GIF (`docs/images/demo.gif`).
4. **v1.0 Reach:** make the repo public with an MIT license (done); submit to Anthropic's directory; make the quiz skill portable (`.agents/skills/`) for Codex and others, documented as "manual mode" there.

## 12. Success criteria

- Your own use: still enabled after 2 weeks, and you don't keep pausing it.
- Questions feel relevant, not like trivia, both in your own use and in the evals.
- The context cost of the always-on part stays small: a short skill description; the full SKILL.md loads only when quizzing.

## 13. Open questions

**Resolved**
- *How a hook starts a quiz at a natural pause:* `Stop` hook + `additionalContext` (§4).
- *Research sessions with no git activity:* `turns` is enough.
- *Parallel agents on different branches:* count per session (§9).
- *What Esc does on the prompt:* it ends the quiz (tested).
- *Where the multiple-choice prompt works:* not in `claude -p`, `dontAsk` mode or with `--permission-prompts none`. The quiz handles that (§4). It works in the desktop app (tested).

**Still open**
- Does the prompt work in the IDE extensions? (It should; test it.)
