---
name: pattern-recognition
description: Systematic methodology for identifying, capturing, and documenting reusable patterns from implementations. Enables learning across sessions via knowledge-core.md updates. Claude invokes this after successful implementations to preserve institutional knowledge.
---

# Pattern Recognition Skill

This skill provides systematic methodology for identifying reusable patterns from completed work and updating the project's knowledge core to preserve institutional knowledge across sessions.

## When Claude Should Use This Skill

Claude will automatically invoke this skill when:
- Implementation successfully completed (tests passing)
- code-implementer finishes major feature work
- chief-architect synthesizes results from multiple agents
- User explicitly requests pattern documentation

## Core Principles

1. **Knowledge preservation** - Capture patterns for future use
2. **Reproducibility** - Document enough detail to replicate the pattern
3. **Simplicity** - Extract the essential pattern, not every detail
4. **Verification** - Patterns must be validated by actual code

## Pattern Recognition Methodology

### Step 1: Implementation Analysis

**Objective**: Review what was just implemented to identify patterns

**Analysis questions**:

1. **Architectural patterns**:
   - What high-level structure was used? (Service layer, Repository, Factory, etc.)
   - How are concerns separated? (Business logic, data access, presentation)

2. **Integration patterns**:
   - How does new code connect to existing code?
   - What interfaces/contracts were established?

3. **Error handling patterns**:
   - How are errors caught, logged, and propagated?

4. **Testing patterns**:
   - What test structure was used? (Arrange-Act-Assert, etc.)
   - How are mocks/stubs created? What edge cases were covered?

5. **Configuration patterns**:
   - How are environment-specific values managed and validated?

**Data to extract**:
- File paths demonstrating the pattern
- Code snippets showing key concepts
- When this pattern should/shouldn't be used
- Alternatives considered and why rejected

### Step 2: Pattern Classification

**Classify into knowledge-core.md sections**:

- **Section 1: Architectural Principles** — broad guidelines affecting the entire codebase ("All API routes must have auth middleware")
- **Section 2: Established Patterns** — concrete, reusable implementation patterns with name, context, example, and files
- **Section 3: Key Decisions & Learnings** — chronological log of decisions with date, rationale, and alternatives considered

**Classification criteria**:
- **Principle**: Applies across many features/files
- **Pattern**: Reusable template for a specific problem
- **Decision**: One-time choice with lasting impact
- **Learning**: New insight or gotcha discovered

### Step 3: Pattern Documentation

**For each pattern identified, document**:

```markdown
### Pattern: [Descriptive Name]

**Context**: [When to use this pattern]
- Use when: [Specific scenarios]
- Don't use when: [Scenarios where it doesn't fit]

**Problem**: [What problem does this solve?]

**Solution**:
[Brief description of the pattern]

**Implementation Example**:
```[language]
// Minimal code example showing pattern
// File: path/to/example.ts
```

**Files Demonstrating Pattern**:
- `path/to/file1.ts` - [What aspect it demonstrates]

**Trade-offs**:
- ✅ Benefits: [List]
- ⚠️ Costs: [List]

**Alternatives Considered**:
1. [Alternative] - Rejected because [reason]
```

**Quality criteria**:
- **Actionable**: Another developer can apply this pattern from the description
- **Specific**: Not vague generalities ("use good code" → ❌)
- **Verified**: Pattern is actually implemented in referenced files
- **Complete**: Includes when to use AND when not to use

### Step 4: Knowledge Core Update

Update the project's `knowledge-core.md` (create it if the project doesn't have one):

1. Read current `knowledge-core.md`
2. Check for duplicates (don't add a pattern that already exists)
3. Append new patterns to the appropriate sections
4. Update the "Last Updated" timestamp

**Merge strategy** (if pattern partially exists):
- Enhance the existing pattern with new examples/files
- Note that the pattern was "reinforced" in the latest implementation
- Don't create duplicate entries

### Step 5: Verification

Before finalizing the update:

- ✓ Pattern has name, context, problem, solution
- ✓ At least 1 file reference provided, and referenced files actually exist
- ✓ Code snippets are actual code (not hallucinated)
- ✓ Pattern is reusable, not a one-off specific to this feature
- ✓ Not a duplicate of an existing pattern (or explains the difference)

**If any check fails**: Fix before updating knowledge-core.md

## Anti-Patterns to Document

Also capture what NOT to do:

```markdown
### Anti-Pattern: Direct Database Access in Controllers

**Problem**: Controller directly queries database

**Why It's Bad**: Violates separation of concerns, hard to test,
business logic mixed with HTTP handling

**Instead Use**: Repository pattern (see Section 2)

**Files that demonstrate the GOOD approach**:
- ✅ `src/controllers/ProductController.ts` (uses ProductService)
```

## Knowledge Core Maintenance

**Regular review** (monthly recommended):
1. Check if documented patterns still apply
2. Mark deprecated patterns as "Superseded by [new pattern]"
3. Consolidate similar patterns
4. Update examples if file paths changed

**Version control**: knowledge-core.md should be committed to git so the team shares accumulated knowledge.

---

**This skill ensures institutional knowledge is captured automatically, making future implementations faster and more consistent.**
