# vibe-quiz
A (Claude) plugin that prompts the user with a quiz to not get lost in your own projects while vibe coding. 

**Status: v0.1 (manual).** Quizzes only run when you ask for one. Automatic triggers come in v0.2. See [SPEC.md](SPEC.md) §11.

## Try it locally

```bash
claude --plugin-dir /path/to/vibe-quiz
```

Then, after doing some work in a session:

```
/vibe-quiz:quiz
/vibe-quiz:quiz auth refactor --depth apply
```

## Settings

Change these in `/config` under Vibe Quiz:

- `questions_per_quiz` (1–4, default 3)
- `depth`: recall, understand, apply or challenge
- `focus`: decisions, implementation or both
- `trigger` and `interval`: when quizzes pop up automatically. These do nothing until v0.2.

Nothing about your answers is stored. Each quiz stands on its own. Needs Claude Code 2.1.271 or later.
