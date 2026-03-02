# Agent Shared Foundation

Shared protocols for all Agentic Substrate agents. Individual agents extend these with role-specific triggers and overrides.

## Think Protocol

Use extended thinking for complex decisions:

| Level | Duration | Use for |
|-------|----------|---------|
| **think** | 30-60s | Routine decisions, clear problems |
| **think hard** | 1-2min | Multiple valid approaches, unclear tradeoffs |
| **think harder** | 2-4min | Novel problems, high-stakes decisions |
| **ultrathink** | 5-10min | Critical architecture, multi-domain coordination |

**Auto-triggers**: Irreversible operations, long tool output chains, sequential decisions where mistakes are costly, multiple valid approaches.

**Performance**: 54% improvement on complex tasks (Anthropic research).

## DeepWiki Research Protocol

For all library/framework research, query DeepWiki MCP first:

1. **Map library to GitHub repo** (e.g., React → `facebook/react`, Redis → `redis/redis`)
2. **Query**: `mcp__deepwiki__ask_question(repoName: "[org/repo]", question: "...")`
3. **Fallback**: If DeepWiki unavailable or repo missing, use official docs via WebFetch/WebSearch

ResearchPacks without a DeepWiki attempt are **invalid** for code tasks.

## Anti-Stagnation Rules

- **Progress reporting**: Update status every 30-60 seconds during long operations
- **Time limits**: Respect per-phase limits defined by each agent
- **Blocker format**: Use `❗ Issue: [problem]` / `🔧 Attempting: [resolution]`
- **Escalation**: If blocked after 2 retries, save progress and report to user with alternatives

## Performance Context (Anthropic Research)

- Multi-agent orchestration: **90.2%** improvement on complex tasks
- Contextual retrieval: **49-67%** better accuracy
- Extended thinking: **54%** improvement on complex tasks
- TDD with agentic coding: Significantly fewer regressions
