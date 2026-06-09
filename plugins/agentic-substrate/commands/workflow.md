---
description: Complete Research → Plan → Implement workflow in one command, orchestrated by chief-architect with quality gates.
argument-hint: <feature description>
---

Run the complete Research → Plan → Implement workflow for: $ARGUMENTS

Use the **chief-architect** agent to orchestrate all phases:

1. **Research** — delegate to docs-researcher to produce a ResearchPack
   (version-accurate APIs, official sources, citations). Validate it with the
   quality-validation skill; do not proceed below a score of 80.
2. **Plan** — delegate to implementation-planner to produce a minimal-change
   Implementation Plan with verification steps and a rollback procedure.
   Validate (85+ required) and confirm every API in the plan matches the
   ResearchPack exactly.
3. **Implement** — delegate to code-implementer to execute the plan with TDD
   and bounded self-correction (3 attempts, then stop and escalate). Run the
   pre-commit-review and security-validation skills before any commit.
4. **Capture** — apply the pattern-recognition skill and suggest
   knowledge-core.md updates for reusable patterns and decisions.

Present the execution plan before delegating. If any quality gate fails,
return the artifact to its agent with the specific defects instead of
proceeding. Finish with a single report: outcome, files changed, test
results, issues encountered, and knowledge captured.
