---
name: pause
description: Pause automatic vibe-quiz quizzes for this session, skip the next n, or resume them.
argument-hint: "[n|off]"
disable-model-invocation: true
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/auto-quiz.sh pause *)
---

Run this command exactly once, then reply with its one-line output and nothing else:

```
${CLAUDE_PLUGIN_ROOT}/scripts/auto-quiz.sh pause "${CLAUDE_PLUGIN_DATA}" "${CLAUDE_SESSION_ID}" $ARGUMENTS
```
