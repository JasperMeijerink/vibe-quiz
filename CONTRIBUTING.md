# Contributing to Vibe Quiz

Thanks for wanting to help! Bug reports, ideas for better quiz questions and pull requests are all
welcome. For anything bigger than a small fix, please open an issue first so we can agree on the
approach.

You only need this page if you want to change the plugin. To use it, see the
[README](README.md).

## How the project is organised

- [SPEC.md](SPEC.md) describes how the plugin is designed, the decisions behind it, and the
  milestones planned next. It's the source of truth: if a change alters a design decision, update
  SPEC.md in the same pull request.
- `skills/quiz/SKILL.md` is the quiz itself: how Claude gathers context, writes the questions and
  gives feedback.
- `skills/pause/SKILL.md` is the `/vibe-quiz:pause` command.
- `hooks/hooks.json` and `scripts/auto-quiz.sh` decide when an automatic quiz starts.
- `tests/auto-quiz-test.sh` tests that script.
- The README's demo animation lives on the `media` branch, not in `main`. Everything in `main`
  is part of the plugin that users install, so large media files stay out of it.

The plugin is deliberately simple: two commands, a handful of settings, and no tracking of scores
or answers. Please keep it that way unless an issue agrees otherwise.

## Try your changes

Clone the repo and start Claude Code with the plugin loaded from your checkout, for that session
only:

```bash
claude --plugin-dir /path/to/vibe-quiz
```

After editing a file, run `/reload-plugins` in the session, or start a new one, to load your
changes.

## Run the checks

Before opening a pull request, run:

```bash
sh tests/auto-quiz-test.sh
claude plugin validate --strict .
```

GitHub CI runs both on every pull request, plus `shellcheck` on the shell scripts. It also runs
the script test on Windows under Git Bash, so keep `scripts/auto-quiz.sh` to POSIX `sh` and the
tools Git for Windows ships (`sed`, `grep`, `find`).

## Pull requests

- Open the pull request against `main`. It's squash-merged, so one tidy description is enough.
- If the change affects how the plugin behaves, raise `version` in `.claude-plugin/plugin.json`.
  Users who installed from the marketplace only get an update when the version changes.
- Update the README if something users see changes, such as commands, settings or what the
  plugin runs and stores.

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
