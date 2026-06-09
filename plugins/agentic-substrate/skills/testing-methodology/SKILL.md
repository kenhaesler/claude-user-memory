---
name: testing-methodology
description: Systematic test strategy and design methodology. Guides test type selection, coverage targets, edge case generation, and test quality assessment.
---

# Testing Methodology Skill

This skill provides systematic test strategy and design methodology for writing effective, maintainable tests. It guides test type selection, edge case generation, and quality assessment.

## When Claude Should Use This Skill

Claude will automatically invoke this skill when:
- During RED phase of TDD (before writing tests)
- When `code-implementer` starts implementation
- When user asks about testing strategy
- When reviewing test coverage gaps

## Core Principles

1. **Test behavior, not implementation** - Tests should verify outcomes, not internal details
2. **Fast feedback** - Tests should run quickly and fail clearly
3. **Deterministic** - Same input always produces same result, no flaky tests
4. **Independent** - Each test runs in isolation, no shared mutable state
5. **Readable** - Tests serve as documentation of expected behavior

## Test Type Selection

### Decision Tree

Use this to determine which test type fits the situation:

```
Is it a pure function or utility?
  YES → Unit test
  NO → Does it involve multiple components working together?
    YES → Does it cross a network/process boundary?
      YES → Integration test (with real or mocked external service)
      NO  → Integration test (in-process)
    NO → Does it simulate a real user workflow?
      YES → End-to-end test
      NO  → Unit test with mocks
```

### Test Type Guidelines

**Unit Tests** (70% of test suite):
- Pure functions, utilities, business logic
- Fast (< 10ms each), no I/O
- Mock external dependencies
- Run on every save/commit

**Integration Tests** (20% of test suite):
- Database queries, API endpoints, service interactions
- May use test database or containers
- Verify component boundaries work together
- Run before merge/deploy

**End-to-End Tests** (10% of test suite):
- Critical user journeys only
- Full stack, real browser/client
- Slowest, most brittle, most valuable for critical paths
- Run in CI pipeline

## Edge Case Generation

### Systematic Boundary Analysis

For any function, systematically generate edge cases:

**Numeric inputs**:
- Zero, negative, positive
- Min/max values (Number.MIN_SAFE_INTEGER, Number.MAX_SAFE_INTEGER)
- Floating point precision (0.1 + 0.2)
- NaN, Infinity, -Infinity

**String inputs**:
- Empty string `""`
- Single character
- Very long string (> 10,000 chars)
- Unicode, emoji, special characters
- Strings with whitespace only
- Strings with SQL/HTML special chars

**Collection inputs**:
- Empty array/object `[]`, `{}`
- Single element
- Large collection (> 10,000 items)
- Nested structures
- Duplicate elements

**Null/undefined**:
- null, undefined, missing properties
- Optional parameters omitted
- Empty optional values

**Error paths**:
- Network failures (timeout, connection refused)
- Invalid data format
- Permission denied
- Resource not found
- Concurrent access conflicts

### Pattern: Happy + Sad + Edge

Every feature should have tests covering:

```
1. Happy path (2-3 tests): Normal expected usage
2. Sad path (2-3 tests): Expected error conditions
3. Edge cases (2-4 tests): Boundary values from systematic analysis
```

## Coverage Strategy

### Targets

- **Overall line coverage**: 80% minimum
- **Critical business logic**: 100% branch coverage
- **API endpoints**: 100% of routes tested
- **Error handlers**: Every catch block exercised
- **New code**: 90%+ coverage on all new code

### What NOT to Cover

- Generated code (protobuf, GraphQL codegen)
- Configuration files
- Simple getters/setters with no logic
- Third-party library internals
- One-line delegation methods

### Coverage Anti-Patterns

- Writing tests just to hit coverage numbers (no assertions)
- Testing implementation details that change with refactoring
- Mocking everything (tests pass but code is broken)
- Testing the framework instead of your code

## Test Quality Assessment

Score each test file on these dimensions:

### Isolation (25 points)
- Tests don't depend on external state or other tests
- Each test sets up its own preconditions
- Tests can run in any order
- No shared mutable state between tests

**Scoring**:
- Fully isolated: 25/25
- Minor shared setup (beforeEach resets): 20/25
- Tests depend on run order: 10/25
- Tests share mutable state: 0/25

### Determinism (25 points)
- No randomness without seeding
- No time-dependent assertions without mocking clock
- No network calls without mocking
- No file system side effects without cleanup

**Scoring**:
- Fully deterministic: 25/25
- Minor non-determinism (timing tolerance): 18/25
- Flaky due to external dependency: 5/25
- Consistently flaky: 0/25

### Readability (25 points)
- Test names describe behavior ("should return 404 when user not found")
- Arrange-Act-Assert pattern clearly visible
- No complex setup obscuring the test intent
- Error messages are descriptive

**Scoring**:
- Clear, self-documenting tests: 25/25
- Adequate but could improve: 18/25
- Hard to understand test purpose: 10/25
- Incomprehensible: 0/25

### Coverage (25 points)
- Happy path covered
- Error paths covered
- Edge cases covered
- Branch coverage adequate for complexity

**Scoring**:
- Comprehensive coverage: 25/25
- Happy path + some errors: 18/25
- Happy path only: 10/25
- Minimal or no meaningful assertions: 0/25

## TDD Workflow Integration

### RED Phase (This Skill Activates)

1. **Analyze the feature**: What behavior needs to exist?
2. **Select test type**: Use decision tree above
3. **Generate test cases**: Happy + Sad + Edge pattern
4. **Write failing tests**: Tests should fail for the right reason
5. **Verify failure**: Run tests, confirm they fail as expected

### GREEN Phase

6. **Write minimal code**: Just enough to pass tests
7. **Run tests**: All should pass
8. **No extra code**: Don't add untested functionality

### REFACTOR Phase

9. **Improve code quality**: DRY, naming, structure
10. **Run tests again**: Must still pass
11. **Assess coverage**: Use coverage tool, add tests if gaps exist

## Example Test Structure

```javascript
describe('UserService', () => {
  // Happy path
  describe('createUser', () => {
    it('should create user with valid input', async () => {
      const user = await service.createUser({ name: 'Alice', email: 'alice@example.com' });
      expect(user.id).toBeDefined();
      expect(user.name).toBe('Alice');
    });
  });

  // Sad path
  describe('createUser - error cases', () => {
    it('should reject duplicate email', async () => {
      await service.createUser({ name: 'Alice', email: 'alice@example.com' });
      await expect(service.createUser({ name: 'Bob', email: 'alice@example.com' }))
        .rejects.toThrow('Email already exists');
    });

    it('should reject invalid email format', async () => {
      await expect(service.createUser({ name: 'Alice', email: 'not-an-email' }))
        .rejects.toThrow('Invalid email');
    });
  });

  // Edge cases
  describe('createUser - edge cases', () => {
    it('should handle empty name', async () => {
      await expect(service.createUser({ name: '', email: 'a@b.com' }))
        .rejects.toThrow('Name is required');
    });

    it('should handle very long name', async () => {
      const longName = 'A'.repeat(256);
      await expect(service.createUser({ name: longName, email: 'a@b.com' }))
        .rejects.toThrow('Name too long');
    });
  });
});
```

## Performance Target

- Test case generation: < 15 seconds
- Quality assessment: < 10 seconds
- Coverage analysis: < 10 seconds
- Total time: < 35 seconds per feature
