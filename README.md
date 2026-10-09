# vibe-quiz
A (Claude) plugin that prompts the user with a quiz to not get lost in your own projects while vibe coding. 

**Status: v0.2 (automatic).** Every 8 Claude replies (by default) a quick multiple-choice quiz pops up about what was just built and why. See [SPEC.md](SPEC.md) §11.

## Try it locally

```bash
claude --plugin-dir /path/to/vibe-quiz
```

Then just work. A quiz pops up on its own every few replies. The first time, Claude Code asks
permission to run the `vibe-quiz:quiz` skill; pick "always allow" so it doesn't ask again.

## Commands

```
/vibe-quiz:quiz                              quiz now
/vibe-quiz:quiz auth refactor --depth apply  quiz on one topic, at a given depth
/vibe-quiz:pause                             no automatic quizzes this session
/vibe-quiz:pause 2                           skip the next 2
/vibe-quiz:pause off                         resume
```

To skip a single quiz, press Esc or pick "Other" and type "skip".

## Settings

Change these in `/config` under Vibe Quiz:

- `trigger`: `turns` (default, every N replies), `commits` (every N git commits) or `manual`
- `interval`: the N, default 8
- `questions_per_quiz` (1–4, default 3)
- `depth`: recall, understand, apply or challenge
- `focus`: decisions, implementation or both

Nothing about your answers is stored. Each quiz stands on its own; the plugin only keeps a
small per-session counter. Needs Claude Code 2.1.271 or later.

## Development

```bash
sh tests/auto-quiz-test.sh
claude plugin validate --strict .
```
