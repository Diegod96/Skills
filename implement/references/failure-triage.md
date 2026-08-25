# Failure Triage

Read this when a deploy, test run, or validation fails. Work top-down: identify the category first, because the fix for "test failed" is completely different depending on why.

## Contents

- [Principles](#principles)
- [Deploy failures](#deploy-failures)
- [Test failures](#test-failures)
- [Coverage shortfalls](#coverage-shortfalls)
- [Validation failures that passed in dev](#validation-failures-that-passed-in-dev)
- [When to stop](#when-to-stop)

## Principles

**Read the whole error, not the first line.** Salesforce deploy errors list every failing component; the first one is often a downstream symptom of the third one. Fix the root, redeploy once, rather than fixing symptoms one at a time.

**Fix the cause, not the test.** When a test fails, the default assumption is that the code is wrong, not the test. Changing an assertion to match new behavior is legitimate *only* when the behavior change is what the spec asked for — and when that happens, say so explicitly in the report, because it's exactly the move that hides regressions.

**Never weaken a test to make it pass.** Deleting assertions, adding `SeeAllData=true`, wrapping the failing call in a try/catch that swallows, or narrowing a bulk test to one record are all ways to turn a red build green while making the codebase worse. If a test genuinely can't pass without one of these, that's a finding to report, not a fix to apply.

**One change per attempt.** Changing three things and revalidating means not knowing which one mattered.

## Deploy failures

### Compile errors
Straightforward: missing references, typos, signature mismatches. Fix and redeploy.

Watch for the case where the code references a field or object that exists in the org but isn't in the branch — it compiles in the dev org and fails validation later. If you added a reference to existing metadata, confirm that metadata is committed.

### Missing dependency
`Invalid field / No such column / Dependent class is invalid`. The package doesn't include something the code needs. Usually a field, custom label, custom metadata type, or record type that exists in the dev org but was never retrieved into the branch.

Retrieve the missing metadata into the branch and redeploy. This is the most common cause of validation passing in dev and failing in QA.

### Field integrity / picklist errors
Picklist values referenced in code or flows that don't exist in the target, record type mismatches, field type incompatibilities. Check whether the value exists in *both* orgs.

### Required field / validation rule blocks existing data
Adding a required field or a validation rule fails when existing records violate it. This one is a design problem, not a deployment problem: it will also break integrations and bulk updates the moment it ships. Options, in order of preference:

1. Make the field non-required at the database level and enforce it in the UI/flow instead
2. Add the validation rule with a bypass condition (custom permission, or a date-based clause so it only applies to records created after go-live)
3. Backfill existing data first, as a sequenced step before the deploy

Raise this to the user rather than picking silently — it changes the deployment plan.

### Mixed DML
`MIXED_DML_OPERATION`. Setup objects (User, PermissionSetAssignment, Group) can't be modified in the same transaction as standard objects. Split into `@future` or Queueable, or in tests use `System.runAs()` to isolate the setup DML.

### Component in a managed package
Some metadata inside managed packages can't be modified. If the spec requires it, the spec needs revisiting — stop and report.

### Flow deployment quirks
Flows deploy as new versions and may deploy **inactive** depending on the path used. If the flow needs to be active, confirm activation is part of the deployment or flag it as a manual post-deploy step. A flow that deployed successfully but sits inactive is a silent failure — everything looks green and nothing runs.

## Test failures

Sort into these before fixing:

### The change broke existing behavior
The most important category. An existing test that used to pass now fails, and the spec didn't ask for that behavior to change. **This is a real regression — fix the implementation.**

Common cause on the Salesforce platform: new automation on an object interacts with existing automation. A new before-save flow changes a field that an existing test asserts on, or a new trigger adds a query that pushes an existing test over a governor limit.

### The test encodes an assumption the spec deliberately changed
Legitimate to update the test. Update the assertion to the new expected value, keep the test's structure, and **report that you changed a test assertion and why.** A reviewer should always know when this happened.

### The test is brittle, not wrong
Date-dependent tests failing on a rollover, tests depending on org data, tests depending on execution order, tests with hardcoded IDs. The test needs fixing regardless of this ticket. Fix it if it's small, note it as a follow-up if it isn't, and don't let it silently expand the diff.

### Bulk failure
Passes at 1 record, fails at 200. Almost always SOQL or DML inside a loop, or a query without a selective filter. Fix the code — this is exactly the failure the bulk test exists to catch, and it's the one most likely to reach production if worked around.

### Permission-related failure
A test using `System.runAs()` with a low-privilege user fails on access. Usually means FLS or object permissions are missing from the permission set in the branch — a packaging gap, not a code bug. Add the permission metadata.

### New test fails
The test may be wrong, or the implementation may be. Read the spec's acceptance criteria to decide which. If the spec is ambiguous about the expected behavior, that's a checkpoint — ask.

## Coverage shortfalls

If per-class coverage is below the floor, add tests for the uncovered paths. Look at what's actually uncovered rather than adding volume:

- Catch blocks with no test that triggers the exception
- Early returns and guard clauses
- Branches for non-default record types
- Null and empty-collection paths

Do not pad coverage by calling methods without asserting on them. It clears the gate and provides nothing, and it makes the next person's coverage report misleading.

If coverage can't reasonably be reached — dead code, unreachable defensive branches — say so rather than contorting the tests. Dead code is worth deleting; that's a real finding.

## Validation failures that passed in dev

The dev org and QA differ, so this category is common and the causes are predictable:

| Symptom | Likely cause | Fix |
|---|---|---|
| Missing field/object | Metadata in dev org, never committed to branch | Retrieve into branch, commit |
| Invalid picklist value | Value added in dev, not in QA and not in branch | Include the picklist metadata |
| Test fails only in QA | QA data violates a new rule, or QA has more data | Check the assertion's data assumptions |
| Permission errors | Permission set changes not in the package | Add permission set metadata |
| Flow errors | Referenced flow/subflow version differs | Include the dependency |
| Callout/Named Credential errors | QA endpoint differs or isn't configured | Flag as environment config, not a code fix |
| Timeout | Test volume against a larger QA data set | Narrow the test scope or investigate query selectivity |

The pattern behind most of these: **the dev org has metadata that the branch doesn't.** Before assuming a code problem, diff what's in the branch against what the code references.

Environment configuration problems (missing Named Credentials, unconfigured endpoints, licensing differences) are **not** fixable from the branch. Report them as environment work with a suggested owner rather than attempting a code workaround.

## When to stop

Stop and report after 3 attempts on the same failure, or immediately if:

- The fix would require weakening a test
- The failure suggests the spec is wrong or incomplete
- The failure is environment configuration rather than code
- The fix would meaningfully expand scope beyond the ticket
- The same error recurs after a fix that should have addressed it — this usually means the diagnosis is wrong, and further attempts compound the misunderstanding

When stopping, report: what failed, the categories ruled out, what was attempted, and the current best hypothesis. A precise handoff is far more useful than a fourth attempt.
