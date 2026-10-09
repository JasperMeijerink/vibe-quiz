---
name: quiz
description: Quiz the user with short multiple-choice questions about what was built in this session and why, so they keep understanding their own project. Use when the user runs /vibe-quiz:quiz or asks to be quizzed or tested on the current work.
argument-hint: "[topic] [--depth recall|understand|apply|challenge]"
allowed-tools: Bash(git status *) Bash(git diff *) Bash(git log *) Bash(git show *) Read Grep Glob
---

# vibe-quiz: quiz

Run one short pop-up quiz about this session's work. The whole thing should take the user
about 30 seconds.

## Settings

| Setting | Value | Default |
|---|---|---|
| questions_per_quiz | `${user_config.questions_per_quiz}` | 3 |
| depth | `${user_config.depth}` | understand |
| focus | `${user_config.focus}` | both |

If a value above is empty or still reads literally as `${user_config...}`, use the default.
If `questions_per_quiz` is out of range, clamp it to 1–4.

Arguments: `$ARGUMENTS`
- `--depth <level>` overrides the depth for this quiz only.
- Any other text is the **topic**. Ask only about that part of the work.

## Steps

### 1. Gather context

Work out what happened in this session. The conversation is the main source, especially
decisions, trade-offs, rejected alternatives and research conclusions. Back it up with
read-only git commands when the project is a git repo:

- `git status --short`
- `git log --oneline -n 15`, then use the commits made during this conversation
- `git diff --stat` and `git diff --cached --stat` for uncommitted work, then
  `git diff -- <file>` for files you plan to ask about

A new repo may have no commits yet, so ignore errors from `git log` and carry on. Read a
touched file only to confirm a fact you'll test. Don't change anything.

If this session has little or no work in it (for example a fresh session), use the most
recent commits instead and say so in your intro line. If there's nothing to ask about at
all, say so in one line and stop. Don't invent questions.

### 2. Write the questions

Read [references/question-guide.md](references/question-guide.md) first. Then write
`questions_per_quiz` questions at the chosen depth, following `focus`:
- `decisions`: why approach A over B, trade-offs, constraints, research conclusions.
- `implementation`: what code does, data flow, what breaks if X changes, where things live.
- `both`: mix the two, with about two-thirds about decisions.

Hard rules:
- Exactly 4 options with exactly one correct. Distractors must be plausible.
- Each question must be answerable from this session alone. No outside knowledge.
- Below `recall` depth, don't ask about line numbers or exact identifiers.
- Spread the correct answer across positions 1–4. It must not always be first, and it
  must not be the longest or most hedged option.
- For each question, decide the correct option, a one-line explanation, and a source
  pointer (a file path, a short commit SHA, or "decision: <short description>").
- **Never reveal the answer key before the user has answered.** Don't write it in the
  intro, a question, an option description or any other text the user sees first.

### 3. Ask

Send one short intro line first, e.g.
`Quick check-in: 3 questions on the auth refactor. (Esc, or Other → "skip", to skip.)`

Then ask all the questions in a single **AskUserQuestion** call:
- `header`: `Q1`, `Q2`, …
- `question`: the full question.
- Four options, `multiSelect: false`. Each `label` is the short answer (5 words or fewer).
  `description` adds neutral detail and must never hint at which option is correct.
- Never mark any option "(Recommended)".

The quiz is skipped if the user dismisses the prompt, picks "Other" and types something
like "skip", or the prompt times out because they're away. In that case reply `Skipped.`
and end your turn. Don't ask again.

If AskUserQuestion isn't available, fall back to plain text: number the questions, letter
the options A–D, ask the user to reply like `1B 2D 3A`, and end your turn to wait.

### 4. Feedback

For each question, give one line:
- right: `✓ Q1`, with no extra praise
- wrong: `✗ Q2 — correct: <answer>. <explanation> (<source pointer>)`

An answer typed into "Other" counts as correct if it clearly means the same as the correct option.

Finish with a single summary line: `2/3 · missed: <concept of the missed question>`, or
`3/3 · solid` if everything was right.

If the user disputes an answer, re-check the source. If they're right, say so plainly and
correct the score.

### 5. Done

End your turn after the summary line. Don't resume earlier work or start anything new.
The user carries on with their next message.
