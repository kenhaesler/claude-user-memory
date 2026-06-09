---
description: Invoke implementation-planner to create a surgical, reversible Implementation Plan from an existing ResearchPack.
argument-hint: <feature description>
---

Create an Implementation Plan for: $ARGUMENTS

A validated ResearchPack must exist — if it doesn't, stop and run `/research`
first rather than planning from memory.

Use the **implementation-planner** agent. The plan must contain:
- File changes (new/modified/test) with purposes, grounded in the real
  codebase structure
- Step-by-step sequence where every step has a verification command
- A test plan (happy path, sad path, edge cases)
- Risk assessment with mitigations (3+ risks)
- A complete rollback procedure (`git revert` for committed work,
  `git restore -- [files]` for uncommitted work, config restoration steps)
- Success criteria

Every API in the plan must match the ResearchPack exactly. Validate with the
quality-validation skill (pass: 85+) and fix defects before declaring the
plan ready. When done, note that `/implement` is the next step.
