# Agentic Substrate — Development Guide

This repository is a **Claude Code plugin marketplace**. The product is the
`agentic-substrate` plugin: a Research → Plan → Implement workflow with 9
agents, 8 skills, 4 commands, and hook-enforced quality gates.

## Layout

- `.claude-plugin/marketplace.json` — marketplace manifest (plugin list)
- `plugins/agentic-substrate/` — the plugin itself
  - `.claude-plugin/plugin.json` — plugin manifest (bump `version` on release)
  - `agents/`, `skills/`, `commands/` — auto-discovered components
  - `hooks/hooks.json` — quality-gate wiring (`${CLAUDE_PLUGIN_ROOT}` paths)
  - `scripts/` — hook shell scripts
  - `.mcp.json` — bundled DeepWiki MCP server
- `autonomous/` — standalone headless VM runner (not part of the plugin)
- `archive/` — historical reports, legacy R&D, superseded docs; do not extend

## Conventions

- **Hook semantics**: blocking gates must use exit code 2 (stderr is fed back
  to Claude) or JSON `{"decision": "block"}`. Exit 1 is a non-blocking error
  — never rely on it to gate anything.
- **No marketing numbers**: do not add performance percentages or benchmark
  claims (from Anthropic blog posts or anywhere else) to agents, skills, or
  docs. Describe behavior, not promised speedups.
- **No model pins in prompts**: use aliases (`opus`, `sonnet`) or omit the
  model entirely; never hardcode dated model IDs in agent files or configs.
- **Minimal changes**: prefer surgical edits; keep agents lean — behavior
  instructions, not self-description.
- **Skill frontmatter**: only documented fields (`name`, `description`, etc.).
- **No personal project references**: configs ship to all users; use
  `$GITHUB_REPO`-style placeholders.

## Validating Changes

```bash
claude plugin validate ./plugins/agentic-substrate --strict
bash -n plugins/agentic-substrate/scripts/*.sh
python3 -m json.tool < .claude-plugin/marketplace.json
```

Skill (`SKILL.md`) edits take effect live in a session; agent/hook/MCP changes
need `/reload-plugins` or a restart.

## Releasing

1. Bump `version` in `plugins/agentic-substrate/.claude-plugin/plugin.json`
2. Add a CHANGELOG.md entry
3. Push to `main` — users pick it up via `/plugin marketplace update`
