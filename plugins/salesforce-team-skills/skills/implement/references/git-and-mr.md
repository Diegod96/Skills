# Git and Merge Requests

Conventions for the commit, push, and MR phases.

## Pre-commit scan

Run before staging anything. These take seconds and prevent the two worst outcomes: a leaked credential, and a reviewer wading through noise.

```bash
git diff --stat                    # what changed, at a glance
git diff                           # read it — actually read it
git status --porcelain             # untracked files that shouldn't be committed
```

Check for:

- **Secrets** — auth files (`.sfdx/`, `.sf/`), `.env`, session IDs, connected app consumer secrets, Named Credential passwords, API keys, hardcoded org IDs used as credentials. If anything like this appears in the diff, stop and remove it before committing. A secret that reaches the remote requires history rewriting to remove properly, which is a stop-and-ask situation.
- **Stray `System.debug()`** statements, especially any logging record data.
- **Commented-out code** left from working through the problem.
- **Unrelated files** picked up incidentally — `.forceignore` changes, IDE settings, `package.xml` regenerated with unrelated content, retrieved metadata that isn't part of this ticket.
- **Retrieved-but-unmodified metadata.** Phase 3 retrieves current state before editing; that can pull in files whose only change is API version or formatting churn. Don't commit those — they bloat the diff and obscure the real change.

**Stage deliberately.** Prefer `git add <specific paths>` over `git add -A`. If using `-A`, read `git status` first and confirm every path belongs.

## Commit messages

Use the repo's existing convention — check `git log --oneline -20` before assuming. If it's Conventional Commits:

```
feat(PENN-4412): add graduation year filter to mentor directory

Adds Graduation_Year__c filter to the mentor search component and
includes FLS for the Mentoring Staff permission set.

- New field Mentor_Profile__c.Graduation_Year__c (Number, 4)
- Updated mentorSearch LWC with year range filter
- Permission set: Mentoring_Staff read access on new field
```

Rules that matter regardless of convention:

- **Ticket ID in the subject line.** It's the link between the code and the reasoning behind it, and it's what someone doing archaeology in eighteen months will search for.
- **Subject under ~72 characters**, imperative mood, no trailing period.
- **Body explains why**, not what — the diff already shows what. The useful body content is the reasoning that isn't visible in the code: why this approach over the alternative, what constraint drove an unusual choice.
- **One logical change per commit** where practical. Fixes from failed validation attempts go in as separate commits, not amended into the original — the sequence is useful history.

**Never amend a pushed commit.** Once it's on the remote, add a new commit instead.

## Push

```bash
git push -u origin feature/PENN-4412-mentor-grad-year-filter
```

Never `--force` or `--force-with-lease`. If history needs rewriting, stop and ask — the cost of a messy history is much lower than the cost of destroying someone else's work.

If the push is rejected because the remote has commits you don't (someone else worked on the branch), stop and report rather than resolving automatically. This usually means two people are on the same ticket, which is a coordination problem, not a git problem.

## Merge request

Open against the **QA branch**, not `main`, unless the org's flow says otherwise.

### Description template

```markdown
## Ticket
[JIRA-123](link) — [ticket title]

## What changed
[2–4 sentences in plain terms. What the feature does, and the approach taken.]

## Metadata
| Type | Name | Change |
|---|---|---|
| Custom Field | Mentor_Profile__c.Graduation_Year__c | New |
| LWC | mentorSearch | Modified |
| Permission Set | Mentoring_Staff | Modified — FLS on new field |

## Verification
- **Dev org deploy:** ✅
- **Tests run:** MentorSearchControllerTest, MentorProfileTriggerTest
- **Results:** 14/14 passing
- **Coverage:** MentorSearchController 91%, MentorProfileTriggerHandler 88%
- **QA validation:** ✅ [link or job ID]
- **Manual checks performed:** [what was clicked through in the dev org, if anything]

## Post-deploy manual steps
[Numbered, written so someone else can execute them without asking questions.
Permission set assignments, job scheduling, flow activation, custom metadata loads.
Write "None" only if you actually checked.]

## Out of scope / follow-ups
[Adjacent issues noticed but deliberately not fixed here, with a note on whether
a ticket exists. Reviewers appreciate knowing you saw the thing and chose not to
touch it — otherwise they'll flag it themselves.]

## Reviewer notes
[Anything you're uncertain about, an approach you'd like a second opinion on, or
a part of the diff that deserves closer attention than the rest. Being specific
here gets better reviews than "LGTM-bait" descriptions.]
```

### Before opening

- Confirm target branch and reviewers with the user.
- Apply the repo's required labels.
- If the MR is large, say so in the description and suggest a review order — reviewers give up on unstructured 40-file diffs.
- Link the JIRA ticket both directions if the integration doesn't do it automatically.

### After opening

Continue with Phase 10 and [babysit-pr.md](babysit-pr.md) to inspect checks and review feedback for the current revision.

Report the MR link, and state plainly anything that still needs a human: unresolved uncertainties, environment configuration outside the branch, manual steps, and any test assertion that was changed during the run.

The "reviewer notes" section is worth real effort. A reviewer told where to look gives a better review than one handed a clean-looking diff and no guidance — and an implementation run that surfaces its own uncertainties is far more trustworthy than one that reports unqualified success.
