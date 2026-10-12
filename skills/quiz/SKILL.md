---
name: quiz
description: Quiz the user with short multiple-choice questions about what was built in this session and why, so they keep understanding their own project. Use when the user runs /vibe-quiz:quiz or asks to be quizzed on the current work.
argument-hint: "[topic] [--depth recall|understand|apply|challenge]"
allowed-tools: Bash(git status *) Bash(git diff *) Bash(git log *) Bash(git show *) Read Grep Glob
---

# vibe-quiz: quiz

Run one short pop-up quiz about this session's work. The goal is to check whether the user can
**explain and defend** their own project, not to test trivia. The whole thing should take
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
- `--auto` means the vibe-quiz hook started this quiz, not the user. In that case, whenever
  these steps say to stop or fall back, end your turn without writing anything instead.
- Any other text is the **topic**. Ask only about that part of the work.

## 1. Gather context

Work silently: no commentary while you gather. The conversation is the main source, especially
decisions, trade-offs, rejected alternatives and research conclusions. Back it up with
read-only git commands when the project is a git repo:

- `git status --short`
- `git log --oneline -n 15`, then use the commits made during this conversation
- `git diff --stat` and `git diff --cached --stat` for uncommitted work, then
  `git diff -- <file>` for files you plan to ask about

Ignore git errors (a new repo may have no commits) and carry on. Read a touched file only to
confirm a fact you'll test. Don't change anything.

If earlier quizzes appear in this conversation, prefer work done since the last one, and don't
repeat a question or concept they already covered.

If the session built or decided too little to ask about:
- **Manual quiz:** use the most recent commits instead and say so in the intro line. If there's
  nothing at all, say so in one line and stop.
- **`--auto`:** end your turn silently.

Never invent questions.

## 2. Write the questions

Write `questions_per_quiz` questions at the chosen depth, following `focus`:
- `decisions`: why approach A over B, trade-offs, constraints, research conclusions.
- `implementation`: what code does, data flow, what breaks if X changes, where things live.
- `both`: mix the two, with about two-thirds about decisions.

| Depth | Tests | Example |
|---|---|---|
| `recall` | What was done | "Which library did we add for date parsing?" |
| `understand` | Why it was done | "Why is the cache invalidated on write instead of on a timer?" |
| `apply` | Consequences | "If two users edit the same row at once, what happens with the current lock strategy?" |
| `challenge` | Critique, alternatives | "Which weakness of our retry logic would matter most at 10× traffic?" |

If the session doesn't support the chosen depth (e.g. a small config change), use the deepest
level it does support rather than inventing reasoning that never happened.

**Rules**
- Exactly 4 options with exactly one correct.
- Each question must be answerable from this session alone. No outside knowledge.
- Ask about what the user saw or approved, not details Claude handled silently.
- Unless the depth is `recall`, don't ask about line numbers or exact identifiers.
- Each correct answer needs a source pointer: a file path, a short commit SHA, or
  "decision: <short description>". If you can't name one, drop the question.
- For research work, ask what a conclusion rests on and what would change it.

**Wrong options**, in order of preference:
1. Alternatives that were really considered and rejected in this session.
2. Common misconceptions about this kind of code or approach.
3. True facts from the same session that answer a different question.

Never use joke options, "all/none of the above", or options that differ by a single word.

**Bad → better**
- "On which line is `retryCount` defined?" → "What stops the retry loop from running forever?"
- "What does REST stand for?" → "Why did we return 409 instead of 400 for duplicate sign-ups?"

**Hide the answer**
- All four options must be similar in length, detail and confidence. The correct one must not be
  the longest, the most hedged, or the only one naming a file from the diff.
- No two questions in one quiz have their correct answer in the same position.
- Never reveal the answer key before the user has answered: not in the intro, a question, an
  option or any other text they see first.
- Before asking, check each question: could someone who didn't follow the session pick the right
  answer from its wording alone? If so, rewrite it.

## 3. Ask

Send one short intro line, e.g.
`Quick check-in: 3 questions on the auth refactor. (Esc, or Other → "skip", to skip.)`

Then ask all the questions in a single **AskUserQuestion** call:
- `header`: `Q1`, `Q2`, …
- `question`: the full question.
- Four options, `multiSelect: false`. `label` is the gist of the answer in 5 words or fewer.
  `description` is the full answer in one sentence.
- Never mark any option "(Recommended)".

**Skips.** The user may dismiss the prompt or pick "Other" and type something like "skip". Then
reply `Skipped.` and end your turn. Don't ask again. If the prompt times out, it submits only
the questions already answered: grade those and count the rest as skipped.

**Fallback.** If AskUserQuestion isn't available or is denied:
- **Manual quiz:** use plain text instead. Number the questions, letter the options A–D, ask the
  user to reply like `1B 2D 3A`, and end your turn to wait. Leave out the skip hint.
- **`--auto`:** end your turn silently.

## 4. Feedback

Give one line per answered question:
- right: `✓ Q1`, with no extra praise
- wrong: `✗ Q2 — correct: <answer>. <one-line explanation of why> (<source pointer>)`

An answer typed into "Other" counts as correct if it clearly means the same as the correct option.

End with one summary line over the answered questions:
- `2/3 · missed: <concept of the missed question>`
- or `3/3 · solid` if everything was right
- add `· 1 skipped` if any questions were left unanswered

If the user disputes an answer, re-check the source. If they're right, say so plainly and
correct the score.

## 5. Done

End your turn after the summary line. Don't resume earlier work or start anything new. The user
carries on with their next message.
