# Salesforce review lens

Drop this into `interrogate/references/` and add it to the list of references filled into the reviewer prompt template in Step 3, alongside `rubric.md` and `code-quality-review.md`.

Purpose: interrogate's adversarial signal comes from model diversity, but all four reviewers share whatever lens they're handed. A generic code-quality lens misses the platform-specific failure modes that account for most real Salesforce production incidents, because those failures look like correct code in any other language. This lens gives every reviewer the same Salesforce-specific things to hunt for.

Apply this lens **in addition to** the general rubric, not instead of it.

## Framing for reviewers

Salesforce runs in a multi-tenant environment with hard, non-negotiable runtime limits. Code that is correct in isolation fails when it processes 200 records instead of 1, or when a second automation on the same object fires in the same transaction. Assume the diff will encounter production data volumes and existing automation the author did not check.

Weight findings by what actually breaks in production. A missing null check on a rarely-null field is minor. A SOQL query inside a loop is a guaranteed outage on the first bulk data load.

## What to hunt for

### Bulk safety
The highest-value category. Salesforce processes records in batches of up to 200 per transaction, and integrations routinely load thousands.

- SOQL or DML inside a `for` loop, including inside a called method that is itself inside a loop
- Callouts inside loops (hard limit of 100 per transaction)
- Trigger logic that reads `Trigger.new[0]` or otherwise assumes one record
- Nested collection loops that should be a `Map` lookup
- Tests that only exercise a single record. **A trigger or record-triggered flow with no 200-record test has an untested failure mode regardless of its coverage percentage.**

### Governor limits and scale
- Heap growth from querying large object graphs or building large strings
- Queries that could return more than 50,000 rows
- Recursion guards on triggers, and whether static flags reset correctly across transaction boundaries
- `@future` and Queueable chaining depth

### Automation interaction
Often invisible in a diff, and the source of the most confusing production behavior:

- Does new automation write to a field that appears in its own entry criteria? This produces records that regenerate themselves after deletion.
- Does automation A update a field that triggers automation B, which updates a field that triggers A?
- Does the object already have multiple record-triggered flows at this trigger point with no explicit order set?
- Is logic split across both Apex triggers and flows on the same object, risking double-processing?
- Should same-record field updates be in a before-save context rather than after-save?

### Security and access
- Is `with sharing` / `without sharing` / `inherited sharing` declared explicitly on every class? An unspecified class inherits in surprising ways.
- Is FLS and CRUD enforced on queries returning data to users (`WITH USER_MODE`, `stripInaccessible()`)?
- Dynamic SOQL built from user input without `String.escapeSingleQuotes()`
- For anything reachable from Experience Cloud: what does a community user or guest user see? Guest access is the highest-consequence and most overlooked case.

### Packaging completeness
Unique to this platform and easy to miss when reviewing only code:

- **Does the diff add a field without adding FLS to a permission set?** If so, the feature ships invisible to everyone but System Administrators. This deploys successfully and fails silently, which is why it survives review so often.
- Does the code reference metadata that exists in the author's dev org but is not in this branch? It will compile in dev and fail validation against QA.
- Are layout, Lightning page, or permission set assignments included where users need to see something?
- Does a new required field or validation rule block existing records? This breaks integrations and bulk updates on day one.

### Environment portability
- Hardcoded IDs: record types, queues, profiles, users, groups, reports. These break on deploy to another org and are the classic sandbox-to-production failure.
- Hardcoded URLs, endpoints, or email addresses that should be Named Credentials or Custom Settings
- Org-specific IDs embedded in flow decision criteria, which get read less carefully than Apex

### Test quality, not test coverage
Salesforce's coverage percentage is a deployment gate, not a quality signal. A class can reach 90% with tests that assert nothing.

- Test methods with no assertions, or only trivial ones
- Assertions on inputs rather than outputs
- `@isTest(SeeAllData=true)`
- Missing `Test.startTest()` / `Test.stopTest()` around the code under test
- No `System.runAs()` coverage on anything with sharing implications
- Tests that will break on a date rollover or fiscal period change

### Flows deserve equal scrutiny
Flows are code and usually get reviewed less carefully than Apex. Apply the same standards: DML in loops, hardcoded IDs, missing fault paths, entry criteria the flow's own actions can satisfy.

## Calibration note for reviewers

Do not manufacture findings to appear thorough. If the diff is clean on a category, say so. In a multi-model setup, false positives from several reviewers converge into apparent consensus, which is worse than a single reviewer being wrong — the synthesis step reads agreement as high-confidence signal, so noise that happens to overlap gets promoted rather than filtered.

Distinguish "this violates a rule" from "this will cause a problem here." Explain the consequence, not just the rule.
