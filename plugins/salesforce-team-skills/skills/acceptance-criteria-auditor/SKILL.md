---
name: acceptance-criteria-auditor
description: Audit a feature branch against the acceptance criteria of its JIRA ticket or spec and report how much is actually built — which criteria are met with evidence, which are partially implemented, which are missing, and which cannot be judged from code at all. Also surfaces changes in the branch that no criterion asked for. Use this whenever someone asks "is this branch done", "does this meet the AC", "how close is this ticket", "did we build everything", "what's left on this branch", before opening or approving a merge request, when picking up a branch that has been sitting for days or weeks and you need to remember what is left, when returning to your own stale work, when picking up someone else's half-finished branch, or at standup when a ticket's status is in doubt. Do NOT use this to judge whether the code is well written — use sf-code-reviewer for that — or whether it is tested — use test-coverage-gap-finder.
---

# Acceptance Criteria Auditor

Answer one question: **does this branch do what the ticket asked for?** Not whether the code is good, not whether it is tested, not whether it is deployable. Whether it is built.

The common case is a branch you have been away from. You built most of a ticket, got pulled onto something
else, and a week later the context is gone — what you finished, what you left half-done, and whether the
world moved underneath you. That scenario gets its own section, because a stale branch needs two answers:
what is left, and what changed while you were gone.

The three build-phase review skills split cleanly. This one asks whether it is built. `sf-code-reviewer` asks whether it is built well. `test-coverage-gap-finder` asks whether it is proven. Running the other two on a branch that is missing a third of its requirements produces polished, well-tested, incomplete work.

The dominant failure mode is generous grading. You read a criterion, you see code nearby that looks related, and you mark it Met. This is the single thing that makes an audit worthless — a developer who knows the branch is half-finished and receives a report claiming everything is Met will never run the tool again. **When the evidence is ambiguous, the verdict is Partial, not Met.** Reaching for a clean report is how this skill becomes noise.

The second failure mode is treating "I cannot tell from the diff" as failure. Plenty of criteria are about runtime behavior, appearance, or data that no amount of reading source will settle. Those get their own verdict and get handed to a human, rather than being quietly passed or quietly failed.

## Org context

Fill this in:

- **Repo**: [GitLab URL] · **Base branch**: `main`
- **Source format**: [SFDX source format / metadata API format] · **Metadata root**: [e.g. `force-app/main/default`]
- **Ticket source**: [JIRA — how criteria reach you: MCP, pasted text, exported HTML, a spec file from `ticket-to-spec`]
- **AC convention**: [Given/When/Then in a JIRA field, a bulleted list, a linked Confluence page]
- **Definition of done**: [what the team requires beyond the criteria — coverage floor, docs, permission sets]
- **Common unstated requirements**: [things every ticket implies but none state — e.g. new fields always go on a permission set and a layout]

That last line earns its place quickly. Most orgs have two or three requirements so obvious nobody writes them down, and they are the most reliably missing thing on a branch.

## Guardrails

This skill reads. It does not write.

- **Never modify the branch.** No commits, no staging, no edits, no `git checkout` of individual paths.
- **Prefer diffing over switching branches.** `git diff` against the merge base tells you everything without touching the working tree.
- **If a checkout is genuinely needed, run `git status` first** and stop if anything is uncommitted. Someone's in-progress work is not yours to discard.
- **Never infer a criterion that isn't there.** An audit that invents requirements fails the branch for imaginary reasons, which is worse than missing a real gap.

## Getting the criteria

Criteria come from the ticket, the spec, or the user. Never from your own sense of what the feature ought to do.

If a `ticket-to-spec` spec exists, use its Acceptance criteria section and its Edge cases table — the edge cases are criteria too, and they are the ones most often left unbuilt.

**Normalize before auditing.** Real tickets carry criteria as prose bullets, a paragraph, or a screenshot of a conversation. Restate each as a single checkable statement, number them `AC-1`, `AC-2`, and echo the numbered list back at the top of the report. Every finding then references a stable ID, and the developer can argue with a specific one.

Splitting matters here. A bullet reading "the coordinator can assign a mentor and the constituent is notified" is two criteria with two independent verdicts. Auditing it as one produces a Partial that hides which half is missing.

**If the ticket has no usable criteria, stop.** Report `Cannot assess`, say what the ticket does contain, and route to `ticket-to-spec`. Grading a branch against criteria you wrote yourself is circular and produces a confident report about nothing.

## Process

```bash
git fetch origin
git log --oneline origin/main..HEAD          # commits on the branch
git diff --name-status origin/main...HEAD    # files changed
git diff --stat origin/main...HEAD           # size of the change
```

Use three dots. `origin/main...HEAD` diffs against the merge base, which is what the branch actually changed. Two dots includes everything that landed on `main` since the branch started and will have you auditing other people's work.

Then, per criterion:

1. **Decide what evidence would settle it** before searching. "Where would this have to live if it were built?" A criterion about who can see a field is answered in permission set and layout XML, not in Apex.
2. **Search the branch for that evidence**, not for keywords from the criterion. Ticket vocabulary and API names rarely match.
3. **Read the surrounding code.** A field named `Mentor_Assigned_Date__c` existing proves a field exists. It does not prove anything sets it.
4. **Check the conditions.** Most Partials live here: the mechanism exists, one qualifier from the criterion is missing.
5. **Assign a verdict and cite the evidence** by path and line, or state what you searched and did not find.

Then the reverse pass: walk every changed file and ask which criterion justifies it.

## Returning to a stale branch

A branch you left a week ago needs an orientation pass before the criteria audit, because two things drifted: your memory, and `main`.

**Reconstruct where you stopped.**

```bash
git log -1 --format='%h  %ad  %s' --date=relative HEAD   # when work stopped, and on what
git status --porcelain                                    # uncommitted work in the tree
git log --oneline origin/main..HEAD                       # what you committed
git log --oneline origin/$(git branch --show-current)..HEAD 2>/dev/null    # committed but never pushed
```

Uncommitted changes in the working tree are the highest-value thing here and the easiest to miss. They are usually the exact spot where the interruption happened, and they are not in any diff you would otherwise look at. Read them first, and treat them as evidence of an in-flight criterion rather than as noise.

A last commit message like `wip` or `checkpoint` is a signal, not an embarrassment. It marks the criterion that was being worked when the branch went cold — audit that one first.

**Measure the drift.**

```bash
git log --oneline HEAD..origin/main | wc -l        # commits on main since you left

# files that both you and main touched — the collision set
comm -12 <(git diff --name-only origin/main...HEAD | sort) \
         <(git diff --name-only $(git merge-base origin/main HEAD)..origin/main | sort)
```

That last command is the one worth running every time. The intersection is where a rebase will hurt, and on Salesforce it is worse than a normal conflict: two people editing the same object's `.object-meta.xml` or the same permission set produces XML that merges cleanly and is semantically wrong. Flag every file in that intersection whether or not git considers it a conflict.

**Check whether the target moved.** Compare the ticket's last-updated date against the branch's first commit. If the criteria changed after you branched, you may have correctly built a requirement that no longer exists. This is the stale-branch version of "implemented differently than specified," and it is common enough after a week to be worth checking before auditing anything.

Also worth a look: whether another branch shipped part of your ticket while you were away. On a shared object it happens more than people expect, and it turns a Not met into a Met that lives outside your diff. When a criterion looks unbuilt but plausibly overlaps recent work on `main`, search `main` before reporting it missing.

Report all of this in a short orientation block above the criteria findings. The returning developer reads that block first and the audit second.

## Verdicts

Exactly four. Every criterion gets one.

**Met** — specific code or metadata in this branch implements the criterion, including its conditions, and you can cite the location. No citation, no Met.

**Partial** — the mechanism exists but something the criterion states is missing. Say precisely what is missing and what would close it. This is the most useful verdict in the report and the one most often rounded up to Met.

**Not met** — nothing in the branch addresses it. Name the searches that came up empty. "No permission set changes in the diff; searched `force-app/main/default/permissionsets/` and the full diff for `Mentor_Assigned_Date__c`" is actionable. "Not implemented" is not, because the reader cannot tell whether you looked.

**Not verifiable from the branch** — the criterion is about rendered appearance, runtime behavior, response times, data that already exists in the org, or an external system. This is not a failure and must not be reported as one. List these separately and hand them to `uat-script-drafter`.

## Where the evidence lives

Salesforce criteria are satisfied in places that are not the obvious file. The recurring mismatches:

| The criterion says | Checking only this is wrong | Also required in the branch |
|---|---|---|
| "the field appears on the record" | the field's `.field-meta.xml` | the layout XML, and FLS on a permission set — a field can exist and be invisible to everyone |
| "only gift officers can do this" | an `isAccessible()` check in Apex | the permission set or custom permission metadata that grants it |
| "status changes to Pending Match" | the assignment in a flow or class | the picklist's value set — the literal string must match a real value exactly |
| "the coordinator is notified" | the email alert element | the email template itself, in the branch, with the merge fields it references |
| "the system prevents saving when..." | Apex validation | whether it is a validation rule, and whether its error message matches the criterion's wording |
| "visible in the community" | internal permissions | guest or community profile access, plus component visibility filters |
| "shows in the report" | the field existing | the report or report type metadata, if the criterion names a specific report |

The picklist row is worth its own sentence. A criterion saying the status becomes "Pending Match" and code assigning `'Pending_Match'` is a defect that passes code review, passes deployment, and fails the first time a user looks at it. Compare the literal against the value set, not against your memory of it.

## Changes no criterion asked for

Run the map backwards. Every file in the diff should trace to a criterion. The ones that do not fall into three buckets, and they need different responses:

- **Necessary but unstated** — a permission set edit the criteria never mentioned but which the feature genuinely requires. Not a problem. Worth noting, because it usually belongs in the ticket's definition of done for next time.
- **Scope creep** — a refactor, a rename, an unrelated fix riding along. Not wrong, but it widens review and deployment risk, and it belongs in the merge request description whether or not anyone objects.
- **A missing criterion** — the developer built something real that the ticket never captured. This is the valuable find. It usually means a conversation happened outside the ticket, and the ticket is now wrong.

Do not moralize about any of these. Report what is unmapped and let the author classify it — the third bucket looks exactly like the second until someone who was in the conversation says otherwise.

## Signals of unfinished work

These also appear in `sf-code-reviewer` and `pre-deploy-checklist`, and they mean something different here. There they are quality and readiness findings. Here they are evidence about a specific criterion, and they downgrade its verdict:

- **`TODO`, `FIXME`, or a commented-out block** inside the method implementing a criterion — that criterion is Partial regardless of how complete the surrounding code looks.
- **A method returning `null`, an empty list, or a constant** where the criterion implies real logic.
- **A flow element with no outbound connector**, or a decision branch that goes nowhere.
- **A test method with no assertions.** It executes the path without checking the outcome, so it is not evidence the criterion is satisfied.
- **Hardcoded values where the criterion implies configurability** — a threshold the business is expected to change, frozen as a literal.
- **`System.debug` left in the implementing method** — weak on its own, but it usually marks the spot where someone stopped.

Tie each signal to the criterion it affects. A `TODO` in an unrelated file is a code review comment, not an audit finding.

## Readiness

Report counts by verdict and one line of judgment. **Do not produce a percentage.** "73% complete" reads as a schedule input, and it is not one: criteria are not equal in size, and the unbuilt ones are disproportionately the hard ones. A number invites a stakeholder to plan around arithmetic that has no basis.

- **Ready for review** — every criterion Met or Not verifiable, nothing unfinished, unmapped changes explained.
- **Close** — one or two Partials, each closable without a design decision.
- **Substantial gaps** — anything Not met, or a Partial needing a decision about what the behavior should be.
- **Not started against these criteria** — the branch has commits but none of them address the ticket. Usually means the wrong branch or the wrong ticket; say which you suspect.
- **Cannot assess** — no usable criteria.

### How much is left

"How much" is a fair question and a percentage is still the wrong answer. Size each remaining gap instead, and order them:

- **Mechanical** — the change is clear and nobody needs to be consulted. Adding the field to a layout, adding the missing picklist value, granting FLS on the permission set.
- **Needs a decision** — the criterion is ambiguous, or closing it requires choosing behavior nobody has chosen. These are the ones that stall a branch for another week, so name who can unblock each.
- **Unknown until opened** — you can tell something is missing but not how big it is until someone reads the surrounding code. Say so rather than guessing; a guess here is the number that ends up in a sprint plan.

Three mechanical gaps and one decision is a genuinely different situation from four mechanical gaps, and it is the distinction a returning developer actually needs. Lead with the decisions — they have lead time, and the mechanical work can happen while someone is waiting on an answer.

One more case, and it needs stating rather than forcing into a verdict. Sometimes the branch is right and the criterion is stale — the requirement changed mid-sprint and the ticket was never updated. Report it as **implemented differently than specified**, describe both, and ask which is current. Marking it Not met would be wrong, and marking it Met would bury a real divergence.

## Output format

```markdown
# AC Audit: [TICKET-ID] — [branch name]

**Readiness:** [verdict]
**Met:** n · **Partial:** n · **Not met:** n · **Not verifiable from branch:** n
**Changes not traceable to a criterion:** n files

## Where you left off
**Last commit:** [hash, how long ago, message]
**Uncommitted in the working tree:** [files, or none]
**Unpushed commits:** [count, or none]
**Behind `main` by:** [n] commits · **Files touched by both you and `main`:** [list, or none]
**Ticket changed since you branched:** [yes, with what changed / no / unknown]

## Criteria as audited
[The normalized, numbered list. State where they came from and any splitting done.]

## Findings

### AC-1 — [restated criterion] — Met
**Evidence:** `force-app/main/default/classes/EngagementService.cls:42-58` — [what it does and how it satisfies the criterion]

### AC-3 — [restated criterion] — Partial
**Found:** [what exists, with path and line]
**Missing:** [the specific condition or piece that is absent]
**To close:** [smallest change that would satisfy it]

### AC-5 — [restated criterion] — Not met
**Searched:** [paths and terms]
**Found:** nothing.

## Not verifiable from the branch
| # | Criterion | How it needs to be checked |
|---|---|---|

## Changes not traceable to a criterion
| File | What it does | Likely explanation |
|---|---|---|

## Signals of unfinished work
| Location | Signal | Criterion affected |
|---|---|---|

## What's left, in order
| # | Gap | Size | Blocked on |
|---|---|---|---|
| 1 | [AC-3 — missing picklist value] | Mechanical | — |
| 2 | [AC-5 — behavior undefined for null] | Needs a decision | [name] |

## Suggested next step
[One sentence. Usually: raise the decisions now, close the mechanical gaps while waiting,
or send the unverifiable set to UAT.]
```

Order findings by verdict — Not met first, then Partial, then Met. The reader is looking for what is left, not for reassurance.

## Chaining

- **Gaps found** → `implement`, which is built to pick up a half-finished branch. Its Resuming section wants exactly this list.
- **Not verifiable set** → `uat-script-drafter`, which turns them into steps a stakeholder can run.
- **No usable criteria** → `ticket-to-spec`.
- **All criteria Met** → then `sf-code-reviewer` and `test-coverage-gap-finder`. Running those first wastes a careful review on incomplete work.
- **Unmapped changes touching shared automation** → `change-impact-mapper`.

## Notes

The report's value is proportional to how willing it is to say a criterion is not met. Auditors that grade generously are pleasant once and useless afterward.

Where a criterion is genuinely satisfied, say so in one line with a citation and move on. Padding Met findings with restated code makes the report long enough to skim, and skimming is how the Not met items get missed.

If the branch is large and the criteria are few, that gap is itself the finding — either the ticket is under-specified or the branch is doing several tickets' work. Both are worth saying out loud.
