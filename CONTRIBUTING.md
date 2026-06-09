# Contributing to Agentic Substrate

Thanks for your interest in contributing! This repository provides the
Agentic Substrate plugin for Claude Code: a Research → Plan → Implement
workflow with specialist agents, skills, and hook-enforced quality gates.

## Project Philosophy

1. **Research**: gather authoritative, version-accurate documentation
2. **Plan**: create minimal-change, reversible blueprints
3. **Implement**: execute precisely, with tests and bounded self-correction

All contributions must preserve this workflow and its dependencies
(implementation requires a plan; planning requires research).

## Development Setup

```bash
git clone https://github.com/YOUR_USERNAME/claude-user-memory.git
cd claude-user-memory
git checkout -b feature/your-contribution
```

To test your changes in a live session, add your working copy as a local
marketplace:

```
/plugin marketplace add ./path/to/claude-user-memory
/plugin install agentic-substrate@claude-user-memory
```

Skill (`SKILL.md`) edits take effect immediately; agent, hook, command, and
`.mcp.json` changes need `/reload-plugins` or a session restart.

## Validating Changes

Run these before submitting:

```bash
claude plugin validate ./plugins/agentic-substrate --strict
bash -n plugins/agentic-substrate/scripts/*.sh
python3 -m json.tool < .claude-plugin/marketplace.json
python3 -m json.tool < plugins/agentic-substrate/hooks/hooks.json
```

Then exercise the workflow end-to-end in a scratch project: `/research` →
`/plan` → `/implement`, and confirm the quality gates block when artifacts
are missing or weak.

## Ground Rules

- **Hook semantics**: blocking gates use exit code 2 (or JSON
  `{"decision": "block"}`). Exit 1 does not block — never rely on it.
- **No marketing numbers**: don't add performance percentages or benchmark
  claims to agents, skills, or docs.
- **No dated model pins**: use `opus`/`sonnet` aliases or omit the model.
- **Lean agents**: behavior instructions only — no self-description, fake
  progress displays, or duplicated rosters.
- **Documented frontmatter only**: agents and skills must use fields from the
  official Claude Code docs.
- **No personal references**: configs ship to everyone; use placeholders like
  `$GITHUB_REPO`.
- **Archive is frozen**: `archive/` holds historical material; don't extend it.

## Pull Requests

1. Clear title and a description of what changed and why
2. Validation output (`claude plugin validate --strict` passing)
3. Notes from an end-to-end workflow test
4. CHANGELOG.md entry for user-visible changes (and a `plugin.json` version
   bump when releasing)

## Reporting Issues

Include: the workflow phase (research/plan/implement), which agent or hook
was involved, expected vs actual behavior, and your Claude Code version.
