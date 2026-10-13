# Privacy policy

*Last updated: 13 October 2026*

Vibe Quiz is a Claude Code plugin by Jasper Meijerink. This policy explains what it does with data.
In short: it stores only a tiny counter on your own computer and sends nothing anywhere.

## What the plugin reads

To write quiz questions, Claude uses what's already in your current Claude Code session's context.
It also runs read-only git commands (`git status`, `git log`, `git diff`, `git show`) and reads
files in your project. This happens locally, within your Claude Code session. The plugin doesn't
read past chats or Claude's memory.

## What the plugin stores

The plugin stores one small file (about 30 bytes) per Claude Code session, on your own computer, in
the plugin's data folder (`~/.claude/plugins/data/…/sessions/`). It holds:

- how many replies or commits have passed since the last quiz
- whether automatic quizzes are paused

Your answers, scores, questions, code and conversation are **never** stored.

## How long it's kept

A session's file is deleted after 7 days without activity. This is checked after every reply Claude
finishes. All files are deleted when you uninstall the plugin.

## What the plugin sends

Nothing. The plugin makes no network requests and doesn't collect analytics or telemetry. Your
session, including the quiz, is handled by Claude Code and Anthropic as usual, under
[Anthropic's privacy policy](https://www.anthropic.com/legal/privacy).

## Contact

Questions about privacy? Open an issue at
[github.com/JasperMeijerink/vibe-quiz/issues](https://github.com/JasperMeijerink/vibe-quiz/issues).
