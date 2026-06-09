---
description: Invoke docs-researcher for rapid, version-accurate documentation research. Produces a validated ResearchPack.
argument-hint: <library, API, or topic>
---

Research the following before any implementation: $ARGUMENTS

Use the **docs-researcher** agent. It should:
- Detect the exact library version from this project's dependency files
- Prefer DeepWiki MCP and official documentation; cite every API with a
  source URL and version
- Deliver a ResearchPack: key APIs (3+ with exact signatures), setup steps,
  version-specific gotchas, one minimal working example, implementation
  checklist, sources, and open questions

Validate the ResearchPack with the quality-validation skill (pass: 80+).
If it scores below 80, list the specific defects and fix them before
declaring the research complete. When done, note that `/plan` is the next step.
