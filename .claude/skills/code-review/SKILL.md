---
name: code-review
description: Systematic code review methodology for pre-commit quality assurance. Checks for anti-patterns, code smells, naming consistency, and over-engineering.
auto_invoke: true
tags: [review, quality, anti-patterns, pre-commit]
---

# Code Review Skill

This skill provides systematic code review methodology for catching quality issues before code is committed. It evaluates anti-patterns, naming conventions, complexity, and over-engineering.

## When Claude Should Use This Skill

Claude will automatically invoke this skill when:
- After `code-implementer` finishes but before git commit
- When user explicitly requests review ("review this", "check this code")
- During `brahma-analyzer` consistency checks
- When reviewing pull request changes

## Core Principles

1. **Consistency over perfection** - Follow existing codebase patterns
2. **Readability first** - Code is read more than written
3. **Simplicity** - The best code is the code you don't write
4. **Constructive feedback** - Every critique includes a suggestion
5. **Context matters** - Consider the purpose and constraints

## Review Categories

### Category 1: Anti-Pattern Detection (25 points)

**What to check**:

**God Objects / God Functions**:
- Classes with > 10 public methods
- Functions longer than 50 lines
- Files longer than 500 lines
- Single class handling unrelated responsibilities

**Deep Nesting**:
- More than 3 levels of indentation
- Nested ternaries
- Callback pyramids without async/await

**Magic Numbers/Strings**:
- Hardcoded values without named constants
- String literals repeated across files
- Numeric thresholds without explanation

**Copy-Paste Duplication**:
- Near-identical code blocks (> 5 lines)
- Same logic in multiple places with minor variations
- Repeated error handling patterns

**Scoring**:
- No anti-patterns: 25/25
- Minor anti-patterns (1-2 instances): 18/25
- Significant anti-patterns (3+ instances): 10/25
- Critical anti-patterns (god objects, deep nesting): 5/25

### Category 2: Naming & Conventions (25 points)

**What to check**:

**Naming Consistency**:
- Variables, functions, classes follow existing codebase style
- Boolean variables prefixed with is/has/can/should
- Functions named with verb (get, set, create, update, delete)
- Constants in UPPER_SNAKE_CASE

**Descriptive Names**:
- No single-letter variables (except loop counters i, j, k)
- No cryptic abbreviations (usr, mgr, btn, cfg)
- Names describe purpose, not implementation

**Convention Adherence**:
- Matches project's linting rules
- Consistent use of quotes (single vs double)
- Consistent semicolons (if applicable)
- Consistent import ordering

**Scoring**:
- Consistent, descriptive names throughout: 25/25
- Minor inconsistencies (1-2): 20/25
- Multiple naming issues: 12/25
- Systematic naming problems: 5/25

### Category 3: Complexity Check (25 points)

**What to check**:

**Cyclomatic Complexity**:
- Functions with > 10 decision points (if/else, switch, loops)
- Deeply nested conditionals
- Complex boolean expressions (> 3 conditions)

**Function Length**:
- Functions over 30 lines (warning)
- Functions over 50 lines (flag)
- Consider extracting helper functions

**Parameter Count**:
- Functions with > 4 parameters
- Consider using options/config object instead
- Check if function is doing too much

**Cognitive Complexity**:
- Can a new developer understand this in < 2 minutes?
- Are there non-obvious side effects?
- Is control flow straightforward?

**Scoring**:
- Low complexity, clear flow: 25/25
- Moderate complexity, understandable: 18/25
- High complexity in isolated spots: 12/25
- Pervasive high complexity: 5/25

### Category 4: Over-Engineering Check (25 points)

**What to check**:

**Premature Abstraction**:
- Abstract classes/interfaces with single implementation
- Generic solutions for specific problems
- Factory patterns for simple object creation
- Strategy pattern for single variant

**Unused Generics**:
- Type parameters that are always the same type
- Generic functions called with one type
- Complex type hierarchies for simple data

**Speculative Features**:
- Code paths that are never exercised
- Configuration options nobody uses
- "Future-proof" interfaces for hypothetical requirements
- Feature flags for features not planned

**Excessive Indirection**:
- Wrapper functions that just delegate
- Unnecessary abstraction layers
- Service classes with pass-through methods

**Scoring**:
- Right-sized solution, no over-engineering: 25/25
- Minor over-engineering (1 instance): 20/25
- Moderate over-engineering: 12/25
- Significant over-engineering: 5/25

## Review Process

### Step 1: Scan Changes (< 15 seconds)

1. List all files changed
2. For each file, read the diff
3. Identify the type of change (new feature, bug fix, refactor)
4. Note the primary language and framework

### Step 2: Category Analysis (< 20 seconds)

Apply each category's checks against the changed code:
1. Flag anti-patterns with specific line references
2. Check naming against existing patterns in the codebase
3. Measure complexity of new/changed functions
4. Evaluate whether abstractions are warranted

### Step 3: Score and Report (< 10 seconds)

```markdown
## Code Review Report

**Score: [X]/100**
**Status: PASS/FAIL** (threshold: 75)

### Anti-Pattern Detection: [X]/25
- [findings or "No issues found"]

### Naming & Conventions: [X]/25
- [findings or "No issues found"]

### Complexity Check: [X]/25
- [findings or "No issues found"]

### Over-Engineering Check: [X]/25
- [findings or "No issues found"]

### Summary
- **Strengths**: [what was done well]
- **Suggestions**: [actionable improvements]
```

## Pass Threshold

**Score >= 75/100**: PASS - Code is ready for commit
**Score < 75/100**: FAIL - Address issues before committing

## Contextual Adjustments

- **Prototype/spike code**: Relax thresholds (60/100 pass)
- **Production hotfix**: Focus on correctness, relax style (70/100 pass)
- **Library/shared code**: Stricter thresholds (85/100 pass)
- **Test code**: Skip over-engineering check, focus on readability

## Integration Points

- Runs between implementation completion and security validation
- Works with `security-validation` for comprehensive pre-commit checking
- Feeds patterns into `pattern-recognition` for learning
- Respects project-specific linting rules from CLAUDE.md

## Performance Target

Total review time: < 45 seconds for typical code changes.
