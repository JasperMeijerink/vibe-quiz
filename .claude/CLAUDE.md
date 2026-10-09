# vibe-quiz

A Claude Code plugin. SPEC.md is the source of truth for design decisions —
read it before making changes, and update it when a decision changes.

- Settings come from userConfig in .claude-plugin/plugin.json; do not invent
  other config mechanisms without updating SPEC.md first.
- Persistent state goes in ${CLAUDE_PLUGIN_DATA}, never the plugin root.
- Run `claude plugin validate .` after changing any plugin file.
- Build one milestone at a time (SPEC.md §11).
