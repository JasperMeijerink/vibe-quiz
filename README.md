# Vibe Quiz

A Claude Code plugin that keeps you from getting lost in your own projects while vibe coding.

With auto mode on, it's easy to skim Claude's replies and keep going. The project moves forward,
but your understanding doesn't. Every now and then, Vibe Quiz pops up a few short
multiple-choice questions about what was just built in your session and, more importantly,
*why*. Answering takes about 30 seconds, and a wrong answer gets a one-line explanation that
points to the file, commit or decision it came from.

## Demo Video

![A Vibe Quiz pop-up in Claude Code: three multiple-choice questions about a change to a small weather CLI, one wrong answer explained, and a 2/3 summary](docs/images/demo.gif)

## Install

In Claude Code (v2.1.275 or later):

```
/plugin install vibe-quiz --marketplace JasperMeijerink/vibe-quiz
```

Or from your shell:

```bash
claude plugin marketplace add JasperMeijerink/vibe-quiz
claude plugin install vibe-quiz@vibe-quiz
```

Already in a session? Run `/reload-plugins` to load it there without restarting.

The first time a quiz starts on its own, Claude Code asks permission to run the
`vibe-quiz:quiz` skill. Pick "always allow" so it doesn't ask again.

## Commands

| Command | What it does |
|---|---|
| `/vibe-quiz:quiz` | Quiz now about this session's work |
| `/vibe-quiz:quiz <topic>` | Quiz on one part of the work, e.g. `/vibe-quiz:quiz data loading` |
| `/vibe-quiz:quiz --depth <level>` | Pick the depth: `recall`, `understand`, `apply` or `challenge` |
| `/vibe-quiz:pause` | No automatic quizzes for the rest of this session |
| `/vibe-quiz:pause <n>` | Skip the next n automatic quizzes |
| `/vibe-quiz:pause off` | Turn automatic quizzes back on |

To skip a single quiz, press Esc, or pick "Other" and type "skip".

## Settings

Change these in `/config` under Vibe Quiz:

| Setting | Default | Options |
|---|---|---|
| `trigger` | `turns` | `turns` (every N Claude replies), `commits` (every N git commits) or `manual` |
| `interval` | `8` | The N, from 1 to 50 |
| `questions_per_quiz` | `3` | 1 to 4 |
| `depth` | `understand` | `recall`, `understand`, `apply` or `challenge` |
| `focus` | `both` | `decisions`, `implementation` or `both` |

## What it runs and stores

- **Hooks.** When Claude finishes a reply (`Stop`) or makes a git commit (`PostToolUse`), a
  small bundled shell script, `scripts/auto-quiz.sh`, updates a counter and decides whether a quiz
  is due. When one is due, it asks Claude to run the quiz skill.
- **Quiz skill.** Claude reads the current conversation and runs read-only git commands
  (`git status`, `git log`, `git diff`, `git show`) and file reads to write the questions.
- **Stored data.** One small file per session in the plugin's data folder
  (`~/.claude/plugins/data/…/sessions/`) holding the reply count, the commit count and the pause
  state. Your answers, scores and code are never stored. Files older than about a week are
  deleted, and the folder is removed when you uninstall the plugin.
- **No network access.** Nothing is sent anywhere by the plugin itself.

Automatic quizzes only start at the end of one of Claude's replies, never inside subagents. They
wait a little if Claude just asked you something or work is still running, and they stay silent
in non-interactive runs such as `claude -p` and CI.

## Requirements

Claude Code 2.1.275 or later, on macOS, Linux or WSL. The hook script uses POSIX `sh`, `sed` and
`grep`.

## Uninstall

```bash
claude plugin uninstall vibe-quiz@vibe-quiz
```

## Feedback

Found a bug, or a quiz question that missed the mark? Open an issue at
[github.com/JasperMeijerink/vibe-quiz/issues](https://github.com/JasperMeijerink/vibe-quiz/issues).
Want to change the code yourself? See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT, see [LICENSE](LICENSE).
