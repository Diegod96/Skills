---
name: pre-deploy-checklist
description: Run a pre-deployment readiness check on a Salesforce branch or release package before it goes to Gearset — leftover debug code, hardcoded environment values, missing permission set changes, deployment-order dependencies, destructive changes, post-deploy manual steps, and anything that works in sandbox but will fail in production. Use this whenever someone says "is this ready to deploy", "about to push the release", "check this branch before deployment", when preparing a monthly release package, or when validating a Gearset comparison. Use it proactively whenever a branch is about to merge into the release branch.
---

# Pre-Deploy Checklist

This skill catches the class of problem that only shows up at deployment time or, worse, after it. The organizing question is not "is this code good" — the reviewer already handled that — but **"what is true in sandbox that will not be true in production?"**

## Org context

Fill this in:

- **Source control**: GitLab, branch-per-feature, release branch: [name]
- **Deployment**: Gearset, monthly cadence
- **Environments**: [dev sandbox → UAT/full sandbox → production, or your actual path]
- **Deployment window**: [day/time, and who needs to be available]
- **Coverage floor**: [org standard]
- **Known sandbox/production differences**: [record type IDs, integration endpoints, users, data volumes, licensed features]

## Checks

### Environment-dependent values
The core category. Anything that differs between sandbox and production and is baked into the code:

- Hardcoded record IDs — record types, queues, users, profiles, groups, report IDs.
- Hardcoded URLs and endpoints; verify Named Credentials or Custom Settings are used and that the production values exist.
- Email addresses, especially anything pointing at a developer or a test inbox.
- References to sandbox-only users or data.
- Org-specific IDs embedded in flow decision criteria — easy to miss, since flows aren't read as carefully as Apex.

### Leftover development artifacts
- `System.debug()` statements, particularly any logging sensitive data.
- Commented-out code blocks.
- `TODO` / `FIXME` / `HACK` comments — each one is either a decision to accept or a ticket to file.
- Test-only branches in production code (`if (Test.isRunningTest())`).
- Feature flags left in the wrong default state.
- `@isTest(SeeAllData=true)`.

### Deployment package completeness
This is where most real failures come from — the code is fine, the package is incomplete:

- **Permission sets and profile changes included?** A new field without FLS metadata deploys successfully and is invisible in production. Check this first; it's the most common miss.
- Layout and Lightning page changes included, along with their assignments.
- Custom labels, custom metadata records, and custom settings — note that custom settings *data* often doesn't move with metadata and needs a separate step.
- Record types and picklist value additions.
- Translations, if the org uses them.
- Everything the new code *references* — a class referencing a field that isn't in the package fails validation.

### Deployment order and dependencies
- Does anything need to deploy before this (a field before the flow that uses it)?
- Does this depend on another team's work landing first?
- Are there destructive changes? If so, is the destructive package separate, and is deletion sequenced *after* the code that stops referencing the deleted metadata?
- Does anything require a data backfill, and does the backfill run before or after the code?
- Any managed package upgrades or feature enablement needed first?

### Runtime risk in production
Things that behave differently at production scale or with production data:

- Will any new automation fire on existing records? A record-triggered flow doesn't run retroactively, but a scheduled job or batch will hit the whole data set.
- Does a new validation rule block existing records that don't satisfy it? This breaks integrations and bulk updates immediately, and it's the classic Monday-morning incident.
- Does new automation on a high-volume object add processing to an already-busy trigger context?
- Are there scheduled jobs to schedule (or reschedule) post-deploy? These don't carry over automatically.

### Test and validation
- Coverage clears the org floor, and the *specific classes* clear their own minimum.
- All tests pass in a full-copy sandbox, not just dev — data volume differences surface real failures.
- Any test dependent on the current date or fiscal period that might fail when run on deployment day.

### Post-deploy manual steps
Enumerate everything that must be done *by hand* after the deployment succeeds, because these are invisible in the package and get forgotten:

- Schedule or reschedule Apex jobs
- Activate flows (flows deploy inactive in some paths)
- Assign permission sets to actual users
- Load or update custom settings / custom metadata data
- Update Named Credential secrets
- Enable or configure Experience Cloud settings
- Notify integration owners of field changes
- Run backfill scripts

### Communication and rollback
- Who needs to know this is shipping — end users, integration owners, support?
- Is there a rollback plan? (See the `rollback-plan-drafter` skill.)
- What's the smoke test — the specific 2–3 things someone checks in production immediately after deploy to confirm it worked?

## Output format

```markdown
# Pre-Deploy Check: [branch / release name]

**Verdict:** [Ready / Ready with manual steps / Not ready]
**Blockers:** [count] · **Manual steps required:** [count]

## Blockers
[Anything that will fail validation or break production. Each with the specific fix.]

## Package completeness
| Item | In package? | Notes |
|---|---|---|

## Deployment sequence
[Numbered, if order matters. Include destructive changes and backfills in the sequence.]

## Post-deploy manual steps
[Numbered checklist, with owner for each. Write these so someone else could execute
them without asking questions.]

## Smoke test
[The 2–3 specific checks to run in production immediately after deployment, with
the expected result for each.]

## Communication
[Who to notify, before and after.]

## Not verifiable from the branch
[Anything needing org access to confirm — production custom setting values, current
scheduled jobs, actual permission set assignments.]
```

## Notes

The post-deploy manual steps section is the highest-value part of this output. Package contents get validated by Gearset; manual steps get validated by somebody's memory at 7 p.m. on a Tuesday. Write them for a person who wasn't involved in building the feature.

When something can't be checked from the branch alone, list it under "not verifiable" rather than assuming it's fine. A checklist that quietly skips the unverifiable items gives false confidence, which is worse than a shorter honest one.
