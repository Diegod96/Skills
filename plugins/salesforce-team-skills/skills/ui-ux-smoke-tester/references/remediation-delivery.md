# Remediation Delivery

Read this reference only after the smoke has found an actionable, in-scope defect and the user has explicitly authorized the requested delivery boundary.

The goal is to repair the defect on the feature branch that owns it, prove the repair in a development org, and publish only a verified, focused commit. Do not create a convenient new branch when the work already belongs to an existing ticket branch.

## Delivery gates

Move only left to right:

```text
reproduce → identify owning branch → repair → deploy to dev → applicable tests
          → post-fix smoke → focused commit → non-force push
```

Stop before commit and push if deployment fails, an applicable Apex test fails, the defect still reproduces in the post-fix smoke, or the diff contains unrelated work. When no Apex tests apply, say so explicitly and use the successful scoped deployment, relevant static checks, and post-fix smoke as the delivery gate; do not invent a meaningless test run.

Use at most three repair-and-verify attempts for the same failure. After that, preserve the evidence and report the blocker instead of widening the change.

## Prove the owning branch

Do not assume the current checkout or the newest similarly named branch owns the defect. Establish the ticket and branch from the best available combination of:

- the story, acceptance criterion, or release item under test;
- the branch or merge request that introduced the affected component;
- git history for the affected files and feature identifiers;
- deployment/release context supplied by the user;
- an exact existing `feature/<ticket>-...` branch locally or on the remote.

Fetch remote refs, inspect `git worktree list --porcelain`, and compare candidate branches before editing. If the exact owning branch is already checked out in another worktree, work there rather than trying to check it out again. Verify both the absolute worktree path and `git branch --show-current` immediately before the first edit.

If more than one branch plausibly owns the defect, the ticket-to-branch mapping conflicts with the release evidence, or no owning branch can be established, stop and ask. A plausible branch name is not enough evidence for a source mutation.

Resume the original ticket branch. Do not create `-fix`, `-remediation`, or `-v2` variants unless the user explicitly asks for a new branch. For MentorHub `MENT-*` work, use the exact original `feature/MENT-*` ticket branch, synchronize against the project-defined `origin/AdvPartial` baseline, deploy and test in `MyPennDev`, and never develop on or deploy changes to `AdvPartial` itself.

## Protect the worktree

Before editing:

```bash
git status --short --branch
git fetch origin
git worktree list --porcelain
git rev-list --left-right --count HEAD...@{upstream}
```

- Preserve unrelated modified and untracked files; they belong to the user.
- Do not stash, discard, reset, or overwrite someone else's work.
- If existing changes overlap the fix, stop and report the conflict.
- Do not rebase, merge the target baseline, or rewrite history merely to make the branch look current. Follow the repository's established synchronization policy and report divergence before changing branch history.
- Read repository instructions and relevant architecture conventions before editing.

## Repair the reproduced defect

Use the smoke's shortest reproduction and visible failure as the acceptance boundary. Trace the rendered component through its controller, service, domain, selector, Flow, metadata, labels, and permission surface as applicable. Make the smallest complete fix that resolves the reproduced issue without absorbing adjacent findings.

Inspect the existing tests and neighboring implementation patterns before writing. Add or update tests for changed Apex behavior. For LWC, Flow, metadata, styling, or configuration changes, run the relevant repository checks rather than claiming Apex coverage proves the UI behavior.

Keep Salesforce architecture and security requirements intact. When the `implement`, `apex-architecture`, or Salesforce review skills are available and applicable, use them rather than duplicating their detailed rules here.

## Deploy only to the configured development org

Resolve the project-specific development alias from repository instructions or the user's request. Verify the alias and that it is a non-production org before deploying. Never infer a target from whichever org happens to be the CLI default, and never deploy to production.

Deploy the smallest complete metadata set that contains the repair and its dependencies. Record the org alias, deployment identifier, component count, and result. A static parse or local build is not deployment evidence.

On a failed deployment, diagnose the actual error, make only supported corrections, and retry within the three-attempt limit. Do not commit or push a change that has not deployed successfully to the configured development org.

## Run applicable Apex tests

Determine the applicable test set from changed classes, triggers, fields, objects, and Flow entry conditions. Prefer explicit related tests with code coverage; use the repository's broader test level when the related set cannot be determined confidently.

Record test class names, pass/fail counts, and relevant per-class coverage. All applicable tests must pass. If a deployment command ran zero tests, do not describe it as tested.

If no Apex tests apply, state `No applicable Apex tests` and name the non-Apex checks used. Do not substitute manual UAT for Apex tests, and do not claim a UI smoke provides Apex coverage.

## Re-smoke the repair

After the successful dev deployment and tests, repeat the shortest failing path in the development org using the same persona, viewport, and data boundary when possible. Confirm both that the original visible defect is gone and that the next meaningful state still works.

Keep the re-smoke read-only unless the original authorization included the exact data mutation required. If verification is blocked by authentication, missing data, or an unsafe mutation boundary, report it and stop before publication unless the user explicitly accepts that unverified boundary.

## Commit and push the owning branch

Commit and push only when smoke-and-deliver authorization already covers those actions and every delivery gate has passed.

Before committing:

- inspect the complete diff and `git status`;
- exclude unrelated user changes and generated noise;
- scan for secrets, credentials, debug statements, and environment-specific values;
- stage explicit files rather than the whole worktree;
- use the repository's commit convention and include the ticket identifier.

Push the exact owning feature branch to its matching remote branch. Never force-push. If the remote advanced, fetch and reconcile safely according to repository policy; do not overwrite it.

An explicit smoke-and-deliver request is the push authorization, so do not ask for a redundant checkpoint immediately before an ordinary non-force push. Stop and ask if the diff expanded beyond the reproduced defect, the target branch changed, unrelated commits would be published, or reconciliation would rewrite history.

Do not open a merge request or deploy to a QA/release org unless the user separately requests it or a documented project workflow explicitly includes it.

## Report the delivered result

Add a Remediation delivery section to the smoke report with:

- repository, absolute worktree, exact branch, ticket, and remote branch;
- root cause and files changed;
- dev org alias and deployment result/identifier;
- Apex tests, pass/fail, and coverage, or why none applied;
- post-fix smoke path and result;
- commit SHA and push result;
- data changes and cleanup status;
- anything uncommitted, deferred, or still uncertain.

Do not call the issue delivered if any gate is missing. Say exactly where the sequence stopped and what would unblock it.
