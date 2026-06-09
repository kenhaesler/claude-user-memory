---
description: Invoke code-implementer to execute the Implementation Plan with TDD and bounded self-correction.
argument-hint: [optional notes]
---

Execute the Implementation Plan. $ARGUMENTS

Both a ResearchPack and an Implementation Plan must exist — if either is
missing, stop and run `/research` or `/plan` first.

Use the **code-implementer** agent. It must:
- Follow the plan exactly: minimal changes, no improvisation beyond scope
- Apply TDD per step: failing test (RED) → minimal code (GREEN) → refactor
- Use API signatures from the ResearchPack verbatim
- Run the plan's verification commands and report real output
- Self-correct on failures with at most 3 attempts (targeted fix →
  alternative approach → minimal working version), then stop and escalate
  with a full report instead of looping
- Run the pre-commit-review skill (75+ required) and security-validation
  skill (80+ required) before committing
- Commit locally only; the user reviews and pushes

Finish with the implementation report: files changed, test results,
self-corrections, deviations from plan, and suggested knowledge-core.md
patterns.
