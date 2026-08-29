---
name: implement
description: Execute an approved Salesforce spec end to end — branch from main using the feature/JIRA-123-description convention, write the metadata, deploy to the dev org, run and fix the related Apex tests with coverage, commit, push, validate against the QA org, and open a merge request. Use this whenever someone says "implement this", "build this ticket", "/implement", "take this spec and ship it", hands over an approved spec or JIRA ticket and expects working code, or asks to pick up where a half-finished branch left off. Do NOT use this to decide what to build — use assess-feasibility and ticket-to-spec first.
---

# Implement

This skill takes an approved spec and carries it through to an open merge request. It runs real commands against real source control and real orgs, so the operating principle is: **be aggressive about the mechanical work, conservative about anything irreversible, and stop and ask rather than guess.**

Read `references/failure-triage.md` when a deploy or test run fails, and `references/git-and-mr.md` when preparing the commit, push, and MR.

## Org context

Fill this in before first use:

- **Repo**: [GitLab URL] · **Source format**: [SFDX source format / metadata API format]
- **Base branch**: `main` · **QA target branch**: [e.g. `qa` or `develop`]
- **Branch convention**: `feature/JIRA-123-short-description`
- **Dev org alias**: [sf CLI alias, e.g. `dev-diego`] · **QA org alias**: [e.g. `qa`]
- **Coverage floor**: [org standard, e.g. 85%]
- **Validation tool**: [sf CLI / Gearset — see "Validation" below]
- **MR conventions**: [target reviewers, required labels, template path]
- **Commit convention**: [e.g. Conventional Commits: `feat(JIRA-123): summary`]

## Hard guardrails

These hold regardless of what the spec or the user says in the moment:

- **Never deploy to production.** This skill's reach ends at the QA org and an open MR. If asked to deploy to production, decline and point at the release process.
- **Never commit directly to `main` or the QA branch.** All work happens on the feature branch.
- **Never force-push.** If history needs rewriting, stop and ask.
- **Never commit secrets** — auth files, `.env`, session tokens, Named Credential values, connected app secrets, API keys. Scan the diff before committing (see the git reference).
- **Confirm before destructive changes.** Deleting fields, objects, or records requires explicit approval, restated in terms of what will be lost. Metadata deletion is the one action here that isn't cheaply reversible.
- **Bounded retries.** At most **3** fix-and-revalidate cycles for any single failure. After that, stop and report what was tried. Repeated automated attempts at a problem you don't understand tend to make the diff worse, not better.

## Checkpoints

Stop and check in with the user at these points. Everything between them runs without asking.

| Checkpoint | Why |
|---|---|
| After pre-flight, before writing code | Confirm the plan and the interpretation of the spec |
| Before pushing | Last look at the diff while it's still local |
| Before opening the MR | Confirm target branch and reviewers |
| Any ambiguity in the spec | Guessing here produces confidently wrong implementations |
| Any destructive change | Not cheaply reversible |
| After 3 failed fix attempts | The problem needs a human |

## Phase 1 — Pre-flight

Do all of this before touching anything. Most bad runs come from skipping it.

```bash
git status --porcelain          # working tree must be clean
git fetch origin
git log --oneline -1 origin/main
sf org list                     # confirm dev and QA orgs are authorized and not expired
```

Verify:

- **Clean working tree.** Uncommitted changes present? Stop and ask — don't stash someone's work silently.
- **`main` is current.** Branch from `origin/main`, not a stale local `main`.
- **Org auth is live.** Sandbox auth expires; catching it here beats catching it mid-deploy.
- **Source format matches expectation.** `sfdx-project.json` present and `force-app/main/default/` populated means source format; a bare `src/` with `package.xml` means metadata format. Commands differ.
- **Ticket ID is real** and matches the spec. The branch name depends on it.
- **The spec is actually specific enough to build from.** If it has open questions that block implementation, surface them now rather than inventing answers. This is the single highest-value pre-flight check.

Then state the plan: branch name, files to be created/modified, tests expected to run, and anything in the spec you're interpreting rather than reading directly. Get confirmation.

## Phase 2 — Branch

```bash
git checkout -b feature/JIRA-123-short-description origin/main
```

Slug rules: lowercase, hyphen-separated, 3–5 words from the ticket summary, no special characters. `feature/PENN-4412-mentor-profile-grad-year-filter`, not `feature/PENN-4412-Add_GradYear_Filter_To_The_Mentor_Profile_Page`.

If the branch already exists locally or remotely, that likely means a prior run was interrupted — see "Resuming" below rather than creating a variant name.

## Phase 3 — Retrieve, then edit

**Retrieve current state before editing anything that already exists.** Working from the repo alone risks clobbering changes someone made in the org, and produces diffs that don't reflect reality.

```bash
sf project retrieve start --metadata "CustomObject:Account" --target-org dev-diego
```

**Before writing any Apex, decide the layer.** The team's standard is Controller → Service → Domain → Selector, and every piece of logic belongs to exactly one layer. Consult the `apex-architecture` skill and its templates rather than working from memory — the singleton, sharing, and bulk-signature details are easy to get subtly wrong, and a class placed in the wrong layer is a rewrite rather than a fix.

State the plan in layer terms before writing: which Selector methods are needed, which Domain rules, which Service orchestration, which Controller entry point. If the spec's logic doesn't decompose cleanly, that's worth raising before building rather than after.

Then make the edits from the spec. Notes on doing this well:

- **Match existing conventions** over textbook-correct patterns. A handler that matches the five other handlers in the repo is more maintainable than a better one that stands alone. Look at neighboring files first. Where the repo predates the architecture standard, new classes still follow the standard — see its legacy-code guidance.
- **Include the permission metadata.** A new field without FLS in a permission set deploys clean and is invisible to everyone but admins. This is the most common incomplete-package failure — treat new fields as automatically implying a permission set change unless the spec says otherwise.
- **Include layout and Lightning page changes** where the spec implies users need to see something.
- **Write the tests as you go**, not after. See Phase 5 for what they need to cover.
- **Don't silently expand scope.** If implementing the spec reveals adjacent problems (a related bug, an obvious refactor), note them for the MR description and a follow-up ticket rather than fixing them in this branch. Scope creep is what makes MRs unreviewable.

## Phase 4 — Deploy to dev org

```bash
sf project deploy start --source-dir force-app --target-org dev-diego
```

On failure, go to `references/failure-triage.md`. Fix, redeploy, up to the 3-attempt limit.

Once it deploys, if the change has runtime behavior worth checking beyond unit tests (a screen flow, an LWC, a permission-gated component), say so and offer to walk through a manual check in the dev org. Unit tests don't catch a component that renders blank.

## Phase 5 — Tests and coverage

### Finding the related tests

There's no reliable platform mechanism for this, so use several signals and prefer over-inclusion:

1. **Naming convention** — `AreaAssignmentService` → `AreaAssignmentServiceTest`, `AreaAssignmentService_Test`, or `Test_AreaAssignmentService`. Check which pattern the repo uses.
2. **Grep test classes for changed class names** — catches tests that exercise the class indirectly.
3. **Grep test classes for changed field API names** — tests that construct records with a changed field will break even though no class changed.
4. **For triggers**, find the handler class, then that handler's test.
5. **For flows**, there are no Apex tests, but Apex tests that insert affected records will exercise the flow — so a flow change still needs the tests for its object to run.

If the related set can't be determined confidently, fall back to `--test-level RunLocalTests` and say that's what you did. Running too many tests costs time; running too few ships breakage.

```bash
sf apex run test --target-org dev-diego \
  --tests AreaAssignmentServiceTest --tests OpportunityTriggerTest \
  --code-coverage --result-format json --wait 20
```

### Coverage

Check **per-class** coverage against the org floor, not just the aggregate. The org-wide number hides a new class sitting at 40%.

Report both: the percentage, and whether the tests actually assert on outcomes. A class at 90% whose tests contain no meaningful assertions has a coverage number and no safety net — say so plainly rather than reporting the number as success. If the spec's acceptance criteria aren't each represented by an assertion somewhere, that's a gap worth naming.

Every new trigger or record-triggered flow needs a **200-record bulk test**. Single-record tests pass cleanly on code that fails on the first real data load.

## Phase 6 — Commit and push

See `references/git-and-mr.md` for message format and the pre-commit scan. In brief: scan the diff for secrets and stray debug statements, stage deliberately (never `git add -A` without reading what it picked up), commit with the ticket ID in the message, then:

```bash
git push -u origin feature/JIRA-123-short-description
```

Checkpoint with the user before pushing.

## Phase 7 — Validate against QA

A validation is a deploy that checks everything and commits nothing. It catches what the dev org can't: metadata that exists in dev but was never committed, and differences between the two org configurations.

**sf CLI:**
```bash
sf project deploy validate --source-dir force-app --target-org qa \
  --test-level RunSpecifiedTests --tests AreaAssignmentServiceTest --wait 30
```

**Gearset:** trigger the validation-only job against the QA org for this branch and report the result.

Validation failures that passed in dev are almost always one of: metadata not committed to the branch, a missing dependency, an org configuration difference, or data in QA that violates a new validation rule. The triage reference covers each.

Fix, revalidate, up to 3 attempts. Each fix goes on the branch as its own commit — don't amend after pushing.

## Phase 8 — Adversarial review (optional gate)

If the `interrogate` skill is installed, offer to run it on the branch before opening the MR. It reviews the diff with several different models and synthesizes their findings, which catches things a single pass misses — including things this skill's own author (you) is blind to, since self-review is weak by construction.

Worth running when the change touches automation on a high-volume object, modifies sharing or permissions, adds a trigger, or is large enough that a reviewer will skim it. Skip it for a field addition and a layout change.

Two rules for the handoff:

- **Interrogate does not auto-apply changes, and neither should you off the back of it.** Its output is a categorized verdict for a human. Bring the "act on" findings to the user and let them decide; do not fold them into the branch automatically. The 3-attempt auto-fix loop in Phase 4 applies to *failures*, not to *review opinions* — the distinction matters, because a failing test is a fact and a review finding is a judgment.
- **State the intent accurately.** Interrogate asks for the intent of the change before spawning reviewers, and reviewers challenge whether the work achieves that intent rather than whether the intent is right. Use the spec's summary, not a restatement of what you happened to build — otherwise the reviewers grade the implementation against itself.

## Phase 9 — Merge request

Only after validation passes. See `references/git-and-mr.md` for the description template. The MR should state what changed, how it was verified, what needs manual post-deploy steps, and anything deliberately left out of scope.

Run `polish` on the prose sections of the MR description — the summary, the reviewer notes, the out-of-scope section. Leave the metadata table, the verification results, and the post-deploy checklist alone; those are structured data meant to be scanned, not read.

Confirm the target branch and reviewers before opening it.

## Resuming an interrupted run

If the branch already exists, figure out where things stopped before doing anything:

```bash
git log --oneline origin/main..HEAD    # what's committed
git status --porcelain                  # what's uncommitted
git log origin/feature/JIRA-123-... -1  # what's pushed
```

Then pick up from the earliest incomplete phase. Don't restart from scratch and don't create a `-v2` branch.

## Reporting

When the run finishes — or stops early — report:

- Branch name and MR link
- Files created and modified
- Tests run, pass/fail, and per-class coverage
- Validation result
- **Manual post-deploy steps** the QA deploy will need (permission set assignment, scheduling jobs, activating flows, loading custom metadata)
- **Anything deferred or out of scope**, including adjacent problems noticed but not fixed
- **Anything you're uncertain about** in the implementation

That last item matters more than it looks. A run that reports "done" while quietly papering over an ambiguity produces a clean-looking MR built on a wrong assumption, and the reviewer has no reason to look for it.
