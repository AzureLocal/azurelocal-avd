# azurelocal-avd — Claude Code

@AGENTS.md

<!--
  This file is a thin shim. All cross-tool repo instructions live in AGENTS.md,
  imported above via Claude Code's @path syntax (inlined at session launch).
  Keep only genuinely Claude-Code-specific notes below.
-->

## Claude Code notes

- Subagents, skills, and hooks for this repo live in `.claude/`. The repo-level MCP config is `.mcp.json`.
- Use **plan mode** before broad, repo-wide changes.
- Follow the `.ai/` session protocol: read `.ai/state/*` at session start, and update `.ai/state/HANDOFF.md` before ending a session.
- See the [agents standard](https://platform.hybridsolutions.cloud/standards/agents/) for the full multi-model model.


## Claude Code actions in this repo

**Run autonomously:**
- Read, search, and grep any file in this repo
- Write and edit files in this repo
- `git add`, `git commit`, `git push`
- `gh issue`, `gh pr`, `gh run` CLI commands
- `az` CLI read operations: `az ... show`, `az ... list`
- Run PowerShell scripts in `scripts/` already committed

**Always confirm before:**
- Creating or deleting Azure resources
- Any `az` CLI write operation that modifies Azure state
- Running destructive operations
- Making API calls to external services
- Installing software
