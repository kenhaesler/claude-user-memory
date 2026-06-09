# Agentic Substrate Plugin

Research → Plan → Implement workflow for Claude Code.

## Components

**Agents** (`agents/`) — 9 specialists:

| Agent | Role |
|---|---|
| chief-architect | Orchestrates multi-agent workflows for complex projects |
| docs-researcher | Version-accurate documentation research → ResearchPack |
| implementation-planner | Minimal-change, reversible blueprints → Implementation Plan |
| brahma-analyzer | Cross-artifact consistency analysis before coding |
| code-implementer | Plan execution with TDD and bounded self-correction |
| brahma-investigator | Root-cause analysis and debugging |
| brahma-deployer | Canary-first production deployments |
| brahma-monitor | Observability: metrics, logs, traces, SLOs |
| brahma-optimizer | Measure-first performance tuning and scaling |

**Skills** (`skills/`) — 8 auto-invoked methodologies: research-methodology,
planning-methodology, quality-validation, testing-methodology,
pre-commit-review, security-validation, pattern-recognition,
context-engineering.

**Commands** (`commands/`) — `/workflow`, `/research`, `/plan`, `/implement`.
When command names collide with other plugins, use the namespaced form, e.g.
`/agentic-substrate:workflow`.

**Hooks** (`hooks/hooks.json`) — quality gates that actually block:

- `UserPromptExpansion` on `/plan` → `scripts/validate-research-pack.sh`
  blocks planning (exit 2) when no passing ResearchPack exists
- `UserPromptExpansion` on `/implement` → both validators must pass before
  implementation starts
- `PostToolUse` on `Edit|Write` → `scripts/auto-format.sh` runs prettier /
  black / gofmt / rustfmt when available (never blocks)

`scripts/run-tests.sh` is an opt-in extra: wire it to `PostToolUse` in your
own settings if your test suite is fast enough to run on every edit.

**MCP** (`.mcp.json`) — the DeepWiki server (`https://mcp.deepwiki.com/mcp`),
used by docs-researcher to verify real API signatures against repository
documentation. You will be asked to approve it on first use.

## Conventions the agents follow

- No research, no code: implementation requires a ResearchPack and an
  Implementation Plan
- Quality gates: ResearchPack ≥ 80, Plan ≥ 85, pre-commit review ≥ 75,
  security validation ≥ 80
- Bounded retries: 3 self-correction attempts, then stop and escalate —
  never loop
- Knowledge capture: reusable patterns and decisions are appended to the
  project's `knowledge-core.md`
- Commits are local only; the user reviews and pushes

## Development

```bash
claude plugin validate ./plugins/agentic-substrate --strict
```

Changes to `SKILL.md` files take effect immediately in a session; changes to
agents, hooks, and `.mcp.json` require `/reload-plugins` or a restart.
