---
name: sf-code-reviewer
description: Review Salesforce Apex, LWC, Aura, and Flow metadata against platform-specific correctness and maintainability standards — bulkification, SOQL/DML in loops, governor limits, hardcoded IDs, sharing and security enforcement, null handling, and flow design. Use this whenever reviewing a merge request or branch containing Salesforce code, when someone asks "review this Apex", "does this scale", "is this bulk safe", "any problems with this trigger/class/flow", or before approving a merge into the release branch. Use it proactively on any Apex touching triggers, batch jobs, or SOQL. Do NOT use for general non-Salesforce code review.
---

# Salesforce Code Reviewer

This skill reviews Salesforce code for the failure modes specific to the platform — the ones that pass code review in any other language and then break in production at 200 records.

Prioritize ruthlessly. A review that lists thirty issues of mixed severity gets skimmed and ignored. Lead with the things that will actually cause an incident, and be clear about which comments are blocking versus optional.

## Org context

Fill this in:

- **Source control**: GitLab, branch-per-feature
- **Deployment**: Gearset, monthly cadence
- **API version target**: [e.g. 61.0]
- **Coverage floor**: [org standard, e.g. 85% — above the platform's 75% minimum]
- **Team conventions**: [trigger framework in use, naming patterns, logging approach]
- **Existing utility classes**: [list them — reviewers should catch reimplementation of things that already exist]

## Severity levels

Label every finding:

- **Blocking** — will cause a production failure, data corruption, or security exposure. Must be fixed before merge.
- **Should fix** — real problem, but survivable; fix now unless there's schedule pressure and a follow-up ticket.
- **Consider** — style, maintainability, or a better-available-approach note. Author's call.

Don't inflate severity to force compliance. Reviewers who mark everything blocking get ignored on the things that matter.

## Apex review checklist

### Bulkification (highest-value category)
- **SOQL inside a loop** — the single most common cause of production failure. Query once, collect into a Map keyed by Id, look up inside the loop.
- **DML inside a loop** — collect into a List, DML once after.
- **Callouts inside a loop** — hard limit of 100 per transaction, and each one costs wall-clock time against the 120s limit.
- **Trigger logic assuming a single record** — anything reading `Trigger.new[0]` without a good reason is a bug waiting for a data load.
- **Nested loops over collections** that could be a Map lookup — O(n²) work fails at scale even without hitting a specific governor limit.

### Governor limits and scale
- Heap-size risk from querying large object graphs or building large strings; consider `SOQL for` loops or Batch Apex.
- Query rows: a query returning >50,000 rows kills the transaction regardless of how few you use.
- Batch jobs with `QueryLocator` scope set inappropriately for the work per record.
- Recursion guards on triggers — static flags, and whether they're reset appropriately across transaction boundaries.
- `@future` and Queueable chaining depth and limits.

### Security
- `with sharing` / `without sharing` / `inherited sharing` declared explicitly on every class. An unspecified class inherits in ways that surprise people.
- FLS and CRUD enforcement — `WITH USER_MODE` / `Security.stripInaccessible()` / `WITH SECURITY_ENFORCED` on queries returning data to users.
- SOQL injection — dynamic query strings built from user input without `String.escapeSingleQuotes()`.
- Sensitive data in debug logs.

### Correctness
- **Hardcoded IDs** — record type IDs, user IDs, queue IDs, profile IDs. These break on deploy to another org and are a classic sandbox-to-production failure.
- Hardcoded URLs, org-specific labels, or environment-dependent strings.
- Null handling on query results, `Map.get()` returns, and relationship traversals (`a.Parent__r.Field__c` throws when the lookup is empty).
- `List.get(0)` or `[0]` on a query result without a size check.
- Exception handling that swallows errors — an empty catch block, or a catch that logs and continues in a way that leaves data half-written.
- `addError()` usage in triggers versus exceptions in service classes.
- Assumptions about picklist values as string literals scattered through code rather than centralized.

### Maintainability
- Business logic in triggers rather than delegated to a handler or service class.
- Duplicated logic that already exists in a utility class.
- Test-only branches in production code paths (`if (Test.isRunningTest())`).
- API version drift — old classes on very old API versions can behave differently than expected.

## Architecture compliance

The team's mandatory layering is Controller → Service → Domain → Selector. Check every Apex diff against it. If the `apex-architecture` skill is installed, defer to it for the full standard; the checks below are the violations that show up most in review.

- **SOQL outside a Selector** (Rule 2) — in a Service, Domain, Controller, or trigger. Blocking.
- **Business rules outside a Domain** (Rule 3) — validation or status logic in a Service is the most common version.
- **Direct status transitions** (Rule 6) — `app.Status__c = 'Approved';` anywhere but the Domain. Blocking, because it bypasses every rule the Domain enforces.
- **Logic in a trigger** (Rule 5) — triggers route to a Domain and do nothing else.
- **Fat controller** (Rule 1) — DML, queries, or branching business logic in an `@AuraEnabled` method.
- **A second Selector for an object** (Rule 10) — add methods to the existing one.
- **Static Service/Domain/Selector methods** (Rule 9) — these cannot be stubbed, so they break per-layer testing. Static is correct only for controller entry points, stateless utilities, and singleton accessors.
- **Missing documentation header** (Rule 11).
- **Undeclared sharing** — every class states `with sharing`, `without sharing`, or `inherited sharing`; `without sharing` needs a justifying comment.
- **Single-record signatures on a trigger path** (Rule 12) — a Domain or Selector method reachable from a trigger must take a collection. Layering hides this failure rather than preventing it: a Selector call inside a loop looks like a cheap method call.
- **DML in a nested Service** (Rule 17) — only the outermost Service in a call chain performs DML. Inner Services return unsaved records via `prepare`-prefixed methods.
- **Singleton with no `@TestVisible` setter** (Rule 15) — without it the class cannot be stubbed, which makes Rule 9's whole purpose unreachable.
- **`without sharing` used to solve a system-context query** — that disables enforcement for every method on the class. The fix is a separately named system-context method.

Two notes on judgment. Legacy code predating the standard is not a finding unless the diff touches it — flag the new logic, not the file's history. And a documented design-review exception is compliant; if the author says one exists, ask for the reference rather than marking it blocking.

## Flow review checklist

Flows deserve the same scrutiny as Apex and usually get less:

- **DML or SOQL ("Get/Update/Create Records") inside a loop element** — same failure as Apex, same fix: assign to a collection variable and act on it after the loop.
- **Entry criteria that the flow's own actions can satisfy** — this is the self-regenerating loop pattern. Check whether any field the flow writes appears in its own start criteria.
- **Missing "only when a record is updated to meet the condition" setting** where it's appropriate — without it, the flow re-fires on every save.
- **Fault paths** — unhandled fault connectors mean silent failures with no error surfaced to anyone.
- **Multiple flows on the same object at the same trigger point** without explicit ordering set.
- **Before-save vs. after-save** — same-record field updates belong in before-save (cheaper, no recursion), related-record work in after-save.
- **Hardcoded IDs** in flow decision criteria and assignments — as bad here as in Apex, and less visible.
- Naming and description fields populated, so the next person can tell what the flow does without opening every element.

## LWC review checklist

- Wire adapters versus imperative Apex — unnecessary imperative calls in `connectedCallback` that could be reactive wires.
- Missing error handling on imperative Apex calls.
- DOM manipulation bypassing the framework.
- Hardcoded labels rather than custom labels (matters for accessibility and any future i18n).
- Accessibility basics — labels on inputs, keyboard reachability, ARIA where the component is doing something non-standard.
- Unsanitized HTML rendering.
- For Experience Cloud components: behavior for guest users and users lacking the relevant permission.

## Output format

```markdown
# Review: [branch or file names]

**Verdict:** [Approve / Approve with comments / Request changes]
**Blocking issues:** [count] · **Should fix:** [count] · **Consider:** [count]

## Blocking

### [File:line] — [short issue name]
[What's wrong and why it matters in concrete terms — what actually happens in
production, not just which rule it violates.]

**Suggested fix:**
```apex
[corrected code]
```

## Should fix
[Same structure, more concise.]

## Consider
[Brief bullets.]

## Notes
[Anything positive worth reinforcing, or context-dependent observations where the
right answer depends on information not visible in the diff.]
```

## Relationship to `interrogate`

If the `interrogate` skill is installed, these two are tiers rather than competitors. This skill is a single fast pass with deep Salesforce domain knowledge — cheap enough to run on every branch. Interrogate spawns several different models on the same diff and synthesizes where they agree, which costs more and catches blind spots a single pass shares with itself.

Run this one by default. Escalate to interrogate when the change touches automation on a high-volume object, modifies sharing or permissions, or is large enough that a human reviewer will skim it. Feed interrogate the Salesforce lens (`integration/interrogate-salesforce-lens.md`) so its reviewers apply these same platform-specific checks rather than generic code-quality ones.

## Review tone

Explain *why*, in terms of consequences. "SOQL in a loop" is a rule; "this will hit the 100-query limit on any data load over 100 records and throw for the whole batch" is a reason. The second one teaches; the first one just gets pattern-matched around.

When something looks wrong but might be intentional given context you can't see, ask rather than assert. And when the diff is genuinely clean, say so — a review that manufactures findings to look thorough trains people to discount the real ones.
