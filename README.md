# Agentic Substrate

**Research-first development workflow for Claude Code, packaged as a plugin.**

> No API hallucinations. No coding from stale training data. Research → Plan → Implement.

---

## Install

In Claude Code:

```
/plugin marketplace add kenhaesler/claude-user-memory
/plugin install agentic-substrate@claude-user-memory
```

That's it — no installer scripts, no files copied into `~/.claude/`, updates
arrive when you run `/plugin marketplace update`.

## What You Get

- **9 agents** — orchestration (chief-architect), core workflow
  (docs-researcher, implementation-planner, brahma-analyzer,
  code-implementer, brahma-investigator), and production specialists
  (brahma-deployer, brahma-monitor, brahma-optimizer)
- **8 skills** — auto-invoked methodologies for research, planning,
  validation, testing, pre-commit review, security, pattern capture, and
  context curation
- **4 commands** — `/workflow`, `/research`, `/plan`, `/implement`
- **Quality gates that actually block** — `UserPromptExpansion` hooks
  validate the ResearchPack (≥ 80) before `/plan` and both artifacts before
  `/implement`, using exit code 2 to stop the phase and feed the defect list
  back to Claude
- **DeepWiki MCP** — bundled so docs-researcher verifies real API signatures
  against repository documentation

See [plugins/agentic-substrate/README.md](plugins/agentic-substrate/README.md)
for component details.

## Usage

**Full automation:**
```
/workflow Add Redis caching to ProductService with 5-minute TTL
```

**Step-by-step:**
```
/research Redis for Node.js
/plan Redis caching implementation
/implement
```

**Direct agents:**
```
Use the chief-architect agent to build a payment system
Use docs-researcher to research the Stripe API
```

## How It Works

1. **Research** — fetch version-accurate docs (DeepWiki + official sources) before coding
2. **Plan** — minimal-change blueprint with verification steps and a rollback procedure
3. **Implement** — TDD execution with bounded self-correction (3 attempts, then escalate)
4. **Learn** — reusable patterns are captured to the project's `knowledge-core.md`

Quality gates block weak inputs between phases. Retries are bounded — agents
stop and report instead of looping.

## Autonomous Mode (optional, separate)

[`autonomous/`](autonomous/README.md) contains a systemd-based runner for
headless `claude -p` operation on a VM (GitHub issue worker, self-improvement,
test fixing) with tool allowlists, session-based rate limiting, and a circuit
breaker. It is independent of the plugin — see its README for setup.

## Repository Layout

```
.claude-plugin/marketplace.json    # marketplace manifest
plugins/agentic-substrate/         # the plugin (agents, skills, commands, hooks, scripts)
autonomous/                        # headless VM runner (optional)
archive/                           # historical docs, reports, and legacy R&D
```

## Philosophy

See [PHILOSOPHY.md](PHILOSOPHY.md). The short version: ground every
implementation in current documentation, make the smallest reversible change,
verify everything, and preserve what you learn.

## License

MIT — see [LICENSE](LICENSE)

---

**Version:** 5.0.0 · *Research → Plan → Implement → Learn*
