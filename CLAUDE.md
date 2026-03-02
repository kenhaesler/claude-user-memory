# Agentic Substrate - Advanced Claude Code Enhancement

This repository contains the **Agentic Substrate** - the foundational layer for Claude Code superintelligence.

## System Version
**Agentic Substrate v4.2** (Opus 4.6 Optimization)

## Core Components

### Shared Foundation
@.claude/templates/agent-shared.md

### Agents (9 specialists across 3 tiers)
@.claude/templates/agents-overview.md

**Tier 1 - Orchestration**: chief-architect
**Tier 2 - Core Workflow**: docs-researcher, implementation-planner, brahma-analyzer, code-implementer, brahma-investigator
**Tier 3 - Production**: brahma-deployer, brahma-monitor, brahma-optimizer

### Skills (8 auto-invoked capabilities)
@.claude/templates/skills-overview.md

### Workflows (Research → Plan → Implement + Advanced Patterns)
@.claude/templates/workflows-overview.md

## Memory Management

### Quick Commands
- `#` - Add memory quickly (prompts for location)
- `/memory` - Edit memory files in system editor
- `/init` - Bootstrap CLAUDE.md for new projects
- `/context` - Analyze and optimize context configuration

### Memory Hierarchy (4 levels)
1. **Enterprise** (`/Library/Application Support/ClaudeCode/CLAUDE.md`) - Organization-wide
2. **Project** (this file) - Team-shared instructions
3. **User** (`~/.claude/CLAUDE.md`) - Personal preferences (all projects)
4. **Imports** - Modular organization via `@path/to/file.md` (max 5 hops)

### Import Syntax
```markdown
@.claude/templates/agents-overview.md     # Relative path
@~/.claude/my-preferences.md              # User home directory
@/absolute/path/to/file.md                # Absolute path
```

**Not evaluated in code spans/blocks** (avoids collisions)

## Usage

Automatic workflow: describe what you want and Claude sequences research → plan → implement. Manual control: invoke agents directly (e.g., "Use docs-researcher to..."). Adaptive thinking: include "think", "think hard", "think harder", or "ultrathink" in your request to set effort levels (low/medium/high/max). Opus 4.6 uses adaptive thinking with interleaved reasoning between tool calls automatically.

## Opus 4.6 Optimizations

- **Adaptive thinking** replaces extended thinking — effort levels (low/medium/high/max) replace budget_tokens
- **Natural language prompts** — agents use conversational instructions instead of aggressive MANDATORY/CRITICAL directives
- **Interleaved thinking** — agents reason between tool calls automatically
- **Context compaction** — server-side compaction enables indefinite sessions
- **Parallel tool calling** — agents execute independent tool calls simultaneously
- **Agent Teams** — native multi-agent orchestration when available (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS)
- **Quality gates enforce** — validation hooks block (exit 1) on failure instead of warning
- **Competing hypotheses** — brahma-investigator spawns parallel theories for complex debugging

## Integration with Global Settings

Global `~/.claude/CLAUDE.md` preferences (context7, research-first, minimal changes, test everything) are respected. Project settings take precedence. Agent files implement the workflow phases.

## Project Context

All development follows the three-phase workflow. Documentation must come from authoritative sources. Plans must include rollback strategies. Implementations must be minimal and tested.

**Example**: `> Add user authentication to the API` triggers research → plan → implement automatically.

## Troubleshooting

- **Agents not triggering**: Be explicit ("Use docs-researcher to...") or check `/agents`
- **Workflow seems slow**: Trades initial speed for fewer bugs, better docs, safer deployments
- **Settings conflict**: Project settings take precedence; workflow requirements cannot be bypassed

## Contributing

1. Enhance agent prompts while maintaining the workflow
2. Ensure all changes support research-first philosophy
3. Test the complete workflow (research → plan → implement) before submitting

## OSS Framework Integration

See `.claude/integrations/` for LangGraph, Deep Agents, DSPy, and CrewAI templates. See `FRAMEWORK-COMPARISON.md` for analysis, `SELF-ENHANCEMENT-BLUEPRINT.md` for roadmap.

---

*Research → Plan → Implement: The foundation of quality software development*

**Note**: This is the source repository for Claude Code CLI user memory. Users copy these files to `~/.claude/` for system-wide enhancement.
