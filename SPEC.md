# vibe-quiz — Spec (v0.1 draft)

> Repo: `vibe-quiz` (private for now). No license yet — all rights reserved. Plan: add MIT when open-sourcing.

## 1. Problem

With auto mode on, it's easy to skim Claude's replies and keep going. The project moves forward, but your understanding doesn't. After a few days you own a codebase (or a research write-up) you can't explain or defend.

**vibe-quiz** keeps you in the loop. From time to time it pauses and asks a few short multiple-choice questions. They cover what was just built and, more importantly, *why*. You can tune how often and how deep.

## 2. Goals and non-goals

**Goals**
- Questions are grounded in *this* session's actual work: the diff, decisions taken, and research findings. No generic trivia.
- Configurable frequency and depth, with sensible defaults that don't annoy.
- Answering takes about 30 seconds: clickable multiple choice, and skipping is always possible.
- Feedback teaches: a wrong answer gets a short explanation that points to the relevant file or decision.
- Weak spots are remembered and revisited.

**Non-goals (for now)**
- Grading or reporting to anyone else (no team dashboards, no "manager mode").
- Teaching general programming. Questions are about *your project*.
- Blocking work. It is never mandatory unless the user opts in.

## 3. Core loop

```
work happens → trigger fires → quiz skill gathers context
→ writes N questions → asks via multiple choice → user answers
→ immediate feedback → result logged → work continues
```

## 4. Triggers (frequency)

| Mode | Fires when | Mechanism |
|---|---|---|
| `manual` | User runs `/vibe-quiz:quiz` | Skill only |
| `commits` | Every N git commits made during the session | `PostToolUse` hook on Bash, matching `git commit` |
| `turns` | Every N times Claude finishes a reply | `Stop` hook + counter |
| `session_end` | User wraps up / runs the end command | Command, or `SessionEnd` hook that leaves a "pending quiz" for next start |

A small script (`scripts/should-quiz.sh`) keeps a counter per project and decides whether to fire. When it fires, the hook tells Claude to run the quiz skill before continuing.

`/vibe-quiz:quiz` always works, regardless of mode.

**Never fire** in non-interactive runs (`claude -p`, CI), inside subagents, or while Claude is mid-way through a multi-step tool chain. Quizzes go at natural pauses only.

## 5. Question design

### Sources (by `focus` setting)
- **decisions**: why approach A over B, trade-offs accepted, constraints that shaped the design, and research conclusions with what they rest on.
- **implementation**: what a piece of code does, data flow, what breaks if X changes, where something lives.
- **both** (default): mix, weighted toward decisions.

Context comes from the recent conversation, `git diff` / `git log` since the last quiz, and files touched.

### Depth levels

| Level | Tests | Example |
|---|---|---|
| `recall` | What was done | "Which library did we add for date parsing?" |
| `understand` | Why it was done | "Why is the cache invalidated on write instead of on a timer?" |
| `apply` | Consequences / transfer | "If two users edit the same row at once, what happens with the current lock strategy?" |
| `challenge` | Critique / alternatives | "Which weakness of our retry logic would matter most at 10× traffic?" |

`adaptive` (on by default) shifts toward lower depth after misses and higher depth after streaks.

### Format rules
- Multiple choice, **4 options**, exactly one correct. Claude Code's question prompt supports up to 4 questions per prompt, with 2–4 options each.
- Distractors must be plausible: real alternatives that were considered, common misconceptions, or nearby facts from the same session.
- Every question must be answerable from what happened in the session. Nothing that needs outside knowledge.
- No gotchas: no line numbers or exact variable names unless the depth is `recall`.
- Each question carries a one-line explanation and a pointer to its source (file, commit, or "decision made at …").

## 6. Feedback

Feedback is set by `on_wrong`:
- `explain` (default): show the correct answer, the explanation and the source pointer.
- `explain_and_retry`: the same, then one follow-up question on the same concept later in the session.
- `log_only`: no interruption. Results show up in `/vibe-quiz:stats`.

After each quiz there is a one-line summary, e.g. "2/3 · weak spot: auth token refresh". Then work resumes.

## 7. Configuration

All settings live in `userConfig` in `plugin.json`. Claude Code prompts for them on enable and shows them as rows in `/config`.

| Key | Type | Default | Notes |
|---|---|---|---|
| `trigger` | `manual` / `commits` / `turns` / `session_end` | `turns` | When quizzes fire automatically |
| `interval` | number 1–50 | `8` | N for `commits` / `turns` |
| `questions_per_quiz` | number 1–8 | `3` | Over 4 is split across prompts |
| `depth` | `recall` / `understand` / `apply` / `challenge` | `understand` | Starting depth |
| `adaptive` | boolean | `true` | Adjust depth from results |
| `focus` | `decisions` / `implementation` / `both` | `both` | What questions are about |
| `on_wrong` | `explain` / `explain_and_retry` / `log_only` | `explain` | Feedback style |
| `allow_skip` | boolean | `true` | Offer "skip this quiz" |

Per-project overrides (later): an optional `.vibe-quiz.json` in the repo root that takes precedence over the user settings.

## 8. Commands / skills

| Name | Purpose |
|---|---|
| `/vibe-quiz:quiz [topic] [--depth X]` | Quiz now, optionally on a topic or at a given depth |
| `/vibe-quiz:stats` | Score history, streaks, weakest topics for this project |
| `/vibe-quiz:pause [n]` | Pause auto-quizzes for the session (or the next n triggers) |
| `/vibe-quiz:review` | Revisit previously missed concepts |

## 9. State and storage

- Location: `${CLAUDE_PLUGIN_DATA}/projects/<hash-of-project-path>/`. It survives plugin updates and is never written to the plugin root.
- `counter.json`: triggers since the last quiz, last quiz commit SHA.
- `history.jsonl`: one line per question with timestamp, depth, topic, correct/incorrect, and source pointer.
- `weak-spots.json`: concepts missed, with a miss count. Used by `adaptive` and `review`.
- Store no source code and no full answers, only topics and outcomes. Everything stays local.

## 10. Repo layout

```
vibe-quiz/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── skills/
│   ├── quiz/
│   │   ├── SKILL.md
│   │   └── references/question-guide.md
│   └── stats/SKILL.md
├── hooks/hooks.json
├── scripts/should-quiz.sh
├── evals/
├── SPEC.md
├── README.md
└── .gitignore            (LICENSE added when open-sourced)
```

## 11. Milestones

1. **v0.1 Manual:** `quiz` skill + `/vibe-quiz:quiz` + userConfig. Use it on your own projects.
2. **v0.2 Automatic:** hooks + counter script for the `commits` and `turns` triggers.
3. **v0.3 Memory:** history, stats, adaptive depth, review of weak spots.
4. **v0.4 Polish:** evals for question quality, README with demo GIF, `claude plugin validate --strict` in CI, publish the marketplace.
5. **v1.0 Reach:** make the repo public with an MIT license; submit to Anthropic's community directory; make the quiz skill portable (`.agents/skills/`) for Codex and others, documented as "manual mode" there.

## 12. Success criteria

- Your own use: still enabled after 2 weeks, and you don't keep pausing it.
- Most questions get rated "relevant", not "trivia". Add an optional 👍/👎 to measure this.
- Skip rate under ~30% at default settings.
- The context cost of the always-on part stays small: a short skill description; the full SKILL.md loads only when quizzing.

## 13. Open questions (verify before building)

- Best way for a hook to make Claude run the quiz at a natural pause: `Stop` hook returning a "continue" reason, versus injecting context on the next prompt. Check the hooks docs and test both.
- Whether the multiple-choice prompt is available in every mode the user runs (auto mode, IDE plugin, desktop app). Fallback: numbered plain-text options.
- Research-heavy sessions with no git activity: is `turns` alone enough, or is a "files written" trigger needed?
- Interaction with parallel agents on different branches: count per branch or per project?
