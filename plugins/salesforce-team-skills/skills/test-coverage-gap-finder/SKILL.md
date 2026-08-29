---
name: test-coverage-gap-finder
description: Find untested logic paths in Salesforce Apex and flows, and draft the test methods that would close them — including bulk, negative, permission, and edge-case scenarios that percentage coverage numbers hide. Use this whenever someone asks "what needs tests", "is this covered", "write tests for this class", "why is coverage failing", before submitting a branch for deployment, or when a class technically meets the coverage threshold but the tests only exercise the happy path. Use it proactively on any branch adding Apex or record-triggered flows.
---

# Test Coverage Gap Finder

This skill identifies what a Salesforce test suite is *not* exercising, and drafts the tests that would close the gap.

The central idea: **Salesforce's coverage percentage is a poor proxy for test quality.** A class can hit 90% with a single test that inserts one record and asserts nothing. The number is a deployment gate, not a quality signal. This skill looks at what's actually verified.

## Org context

Fill this in:

- **Coverage floor**: [org standard, e.g. 85% — the platform minimum is 75% org-wide and 1% per class for deployment]
- **Test data strategy**: [TestDataFactory class name, or "each test builds its own"]
- **Deployment**: Gearset, monthly cadence — [note whether the pipeline runs local tests or all tests]
- **Known problem areas**: [classes with historically brittle tests]

## What counts as a gap

Look for each of these. Percentage coverage catches only the first.

### Uncovered lines
Branches, catch blocks, and early returns never executed. Standard, and the easiest to find.

### Covered but unasserted
Lines that execute during a test but whose *outcome* is never checked. This is the largest and most under-reported category. A test that calls a method and asserts nothing about the result contributes coverage percentage and zero confidence. Scan for test methods with no `Assert` calls, or with only trivial ones (`Assert.isNotNull(result)` on something that obviously can't be null).

### Bulk gaps
Tests that insert one record where production will see 200. This is the gap that matters most on the Salesforce platform, because single-record tests pass cleanly on code that fails immediately on a real data load. **Any trigger, trigger handler, or record-triggered flow without a 200-record test has a real gap regardless of its coverage number.**

### Negative-path gaps
- Validation rule failures and the resulting `DmlException`
- Required field omissions
- Callout failures and timeouts (via mock)
- Governor limit boundaries
- Catch blocks with no test that actually triggers the exception

### Permission gaps
Nearly all Apex tests run as an admin-adjacent context by default, which means sharing and FLS problems don't surface. Tests using `System.runAs()` with a realistic, low-privilege user are the only way to catch these. Flag any class with sharing implications and no `runAs` coverage — especially anything reachable from Experience Cloud, where the caller may be a community or guest user with a very different permission profile.

### Edge-case gaps
- Null and blank inputs
- Empty collections
- Records with empty lookups (relationship traversal on a null parent)
- Duplicate or conflicting input data
- Boundary values on any numeric or date logic
- Record types other than the default

### Flow test gaps
Flow tests are underused and worth calling out separately — they can cover entry criteria, decision branches, and fault paths declaratively. For any record-triggered flow, check whether tests exist for the criteria-not-met path, not just the happy path.

## Test quality checks

Beyond gaps, flag these anti-patterns in existing tests:

- `@isTest(SeeAllData=true)` — makes tests dependent on org data and brittle across environments.
- Hardcoded IDs in test setup.
- Tests that pass whether or not the code works (assert-free, or asserting on inputs rather than outputs).
- Missing `Test.startTest()` / `Test.stopTest()` around the code under test — without it, async work doesn't execute and governor limits aren't isolated.
- Shared mutable state between test methods.
- Tests that will break on a date rollover, or that depend on the current fiscal period.
- No `@testSetup` where repeated setup is expensive.

## Draft tests

When drafting, produce runnable test methods, not sketches. Each should:

- Have a name that states the scenario: `testOpportunityUpdate_bulkInsert200_allRecordsProcessed`, not `testMethod2`.
- Arrange, act, assert — with `Test.startTest()`/`Test.stopTest()` bracketing the act.
- Assert on the specific expected outcome with a message explaining what failed: `Assert.areEqual(expected, actual, 'Area assignment should populate on insert when Region is set')`.
- Use the org's test data factory if one exists, rather than inventing a parallel pattern.
- For negative paths, use try/catch with an explicit `Assert.fail()` if no exception was thrown.

## Output format

```markdown
# Coverage Gaps: [class/flow names or branch]

**Reported coverage:** [X% — note if this is misleading and why]
**Meaningful gaps:** [count] · **Blocking for deploy:** [count]

## Critical gaps
[Things that would let a real production failure through. Bulk gaps on triggers
and unasserted core logic belong here.]

### [Class.method] — [gap description]
**Risk:** [what breaks in production if this path is wrong]
**Suggested test:**
```apex
[complete, runnable test method]
```

## Secondary gaps
[Real but lower-risk. Same structure, more concise.]

## Existing test quality issues
[Anti-patterns found in the current suite, with the fix.]

## Coverage math
[If the class is near the deployment threshold, note which tests would need to be
added to clear it — but keep this separate from the quality assessment so the two
don't get conflated.]
```

## A note on framing

It's worth being explicit with the team about the distinction this skill draws. Coverage percentage is a compliance number that Gearset needs in order to deploy; test quality is what prevents the 2 a.m. page. They correlate weakly. When a class sits at 92% with three assert-free tests, report both facts and don't let the good number bury the bad one.

Conversely, don't manufacture gaps to look thorough. If a class is well-tested, say so and move on.
