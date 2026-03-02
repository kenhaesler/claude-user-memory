# Agent Shared Foundation

Shared protocols for all Agentic Substrate agents (v4.2 — Opus 4.6 optimized). Individual agents extend these with role-specific triggers and overrides.

## Adaptive Thinking Protocol (Opus 4.6)

Opus 4.6 uses **adaptive thinking** with effort levels instead of budget_tokens. Claude dynamically decides when and how much to think. Interleaved thinking (between tool calls) is automatic.

| Keyword | Effort Level | Use For |
|---------|-------------|---------|
| **think** | `low` | Routine decisions, clear problems, subagent tasks |
| **think hard** | `medium` | Multiple valid approaches, unclear tradeoffs |
| **think harder** | `high` | Novel problems, high-stakes decisions |
| **ultrathink** | `max` (Opus 4.6 exclusive) | Critical architecture, multi-domain coordination |

**Auto-triggers** (all agents): Irreversible operations, long tool output chains, sequential decisions where mistakes compound, multiple valid approaches with unclear tradeoffs.

**Performance**: 54% improvement on complex tasks (Anthropic research).

**Tuning**: If thinking adds latency without improving quality, respond directly. Think deeply only when multi-step reasoning will meaningfully improve the outcome.

## Opus 4.6 Prompt Principles

Follow these across all agents:

**Investigate before answering** — Never speculate about code you haven't read. If a file is referenced, read it first. Investigate relevant files before answering questions about the codebase.

**Prefer action over suggestion** — Implement changes rather than only suggesting them. If the user's intent is unclear, infer the most useful action and proceed, using tools to discover missing details.

**Use parallel tool calls** — When calling multiple tools with no dependencies between them, make all independent calls in parallel. This significantly improves throughput.

**Avoid over-engineering** — Only make changes that are directly requested or clearly necessary. Keep solutions simple and focused. Don't add features, refactor code, or make improvements beyond what was asked.

**Context awareness** — Your context window will be automatically compacted as it approaches its limit, allowing you to continue working indefinitely. Do not stop tasks early due to token budget concerns.

## DeepWiki Research Protocol

For library/framework research, query DeepWiki MCP first:

1. **Map library to GitHub repo** (e.g., React -> `facebook/react`, Redis -> `redis/redis`)
2. **Query**: `mcp__deepwiki__ask_question(repoName: "[org/repo]", question: "...")`
3. **Fallback**: If DeepWiki unavailable or repo missing, use official docs via WebFetch/WebSearch
4. **If repo doesn't exist in DeepWiki**: Note this and proceed with web sources. Do not block on it.

ResearchPacks without a DeepWiki attempt are invalid for code tasks.

## Anti-Stagnation Protocol

Every agent follows these rules to prevent stalls:

**Progress reporting**: Update status every 30-60 seconds during long operations with one of:
- `Still analyzing [artifact/component]...`
- `Resolving [specific issue]...`
- `Finalizing [deliverable]...`

**Time budgets**: Each agent defines phase-specific time limits. If a phase exceeds its budget by 50%, report partial results and move on.

**Blocker handling**:
1. Report the blocker clearly
2. Attempt resolution (max 2 retries)
3. If still blocked, save progress and report to user with alternatives

**Priority on timeout**: Return partial results (what completed) > Flag blocking issues (must-fix) > Defer nice-to-have findings (would-fix).

## Knowledge-Core Integration

All agents read and write to `knowledge-core.md`:

**At start**: Check knowledge-core.md for established patterns relevant to the current task. Reuse proven patterns rather than inventing new approaches.

**At end**: If the task produced reusable patterns, decisions, or lessons, suggest updates to knowledge-core.md. Include context, problem, solution, and example.

## Quality Scoring Standard

All agents that produce deliverables should score their output:

| Score Range | Meaning | Action |
|-------------|---------|--------|
| 90-100 | Excellent | Proceed confidently |
| 80-89 | Good | Proceed with notes |
| 70-79 | Acceptable | Proceed with caution, flag gaps |
| Below 70 | Insufficient | Do not proceed, fix issues first |

Agent-specific thresholds override these defaults (e.g., ResearchPack >= 80, Implementation Plan >= 85).

## Performance Context (Anthropic Research)

- Multi-agent orchestration: **90.2%** improvement on complex tasks
- Contextual retrieval: **49-67%** better accuracy
- Adaptive thinking: **54%** improvement on complex tasks
- TDD with agentic coding: Significantly fewer regressions
- Parallel tool calling: Near-linear speedup on independent operations
- Tool Search Tool: **85%** token reduction for large tool libraries
