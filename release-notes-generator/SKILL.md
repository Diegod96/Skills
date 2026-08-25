---
name: release-notes-generator
description: Turn a release's merged branches, JIRA tickets, and commit history into release notes written for the people affected — stakeholder-facing notes explaining what changed and why it matters, plus a technical changelog for the team. Use this whenever someone asks for "release notes", "what shipped this month", "a summary of the release", "changelog", needs to tell stakeholders what's new, or is wrapping up a monthly deployment. Use it also when writing an announcement email about Salesforce changes.
---

# Release Notes Generator

This skill produces two artifacts from the same source material: **stakeholder notes** (what changed and why anyone should care) and a **technical changelog** (what moved, for the team and for future archaeology).

The failure mode to avoid is writing the changelog and calling it release notes. "Refactored OpportunityTriggerHandler to bulkify area assignment logic" tells a stakeholder nothing. The stakeholder version of that item might be "Bulk updates to opportunities no longer fail on large data loads" — or it might not appear at all, if nobody outside the team ever noticed the problem.

## Org context

Fill this in:

- **Source control**: GitLab, branch-per-feature — branch naming: [convention]
- **Tracking**: JIRA — [project keys, issue types in use]
- **Deployment**: Gearset, monthly cadence
- **Audience**: [who receives stakeholder notes — e.g. Development and Alumni Relations staff, specific business owners]
- **Distribution**: [email, Confluence page, Slack channel, all of the above]
- **Tone**: [formal / conversational — match what the org already sends]

## Gathering input

Work from whatever's available, in rough order of usefulness:

1. **JIRA tickets** in the release — the summary and description usually carry the business intent, which is what stakeholder notes need.
2. **Merged branch names and MR titles** — good for completeness, thin on intent.
3. **Commit messages** — the most complete and least readable; use to catch things missing from the above.
4. **The Gearset deployment package** — authoritative on what metadata actually moved.

Cross-check these against each other. Work that appears in the deployment package but not in JIRA is worth flagging — it's either an undocumented change or something that shouldn't be shipping.

## Categorizing

Sort every item into one of these, and be willing to put things in "not user-visible":

- **New** — capability that didn't exist before
- **Improved** — existing capability that works better or differently
- **Fixed** — something that was broken and now isn't
- **Changed** — behavior users will notice and might not expect; **this is the category people actually need to read**
- **Not user-visible** — refactors, test coverage, technical debt, infrastructure

Then write **only** the first four categories into the stakeholder notes. Everything goes in the technical changelog.

## Writing stakeholder notes

For each item, answer: *what can a user do now that they couldn't before, or what will they notice is different?* If you can't answer that, it's probably not a stakeholder item.

Guidelines:

- **Lead with the user's verb, not the system's.** "You can now filter the mentor directory by graduation year" beats "Added graduation year filter to directory component."
- **Name the place.** Users don't know object API names; they know "the Mentor Profile page" or "the monthly gift report." Use the labels they see.
- **Skip the ticket numbers** in the stakeholder version, or park them at the end of the line in small type. They mean nothing to the audience and make the notes feel like an internal document.
- **Call out anything requiring user action** in its own section, at the top. Things that change a workflow, require re-learning a step, or need someone to update a saved report deserve prominence over new features.
- **Say why**, briefly, when the change might otherwise seem arbitrary. A one-clause reason prevents a round of "why did you change this."
- **Group by area or audience**, not by ticket type, when the release touches multiple business areas. A gift officer shouldn't have to read the mentoring changes to find theirs.
- Keep each item to one or two sentences. If it needs more, it needs a linked doc, not a longer bullet.

## Output format

Produce both sections.

```markdown
# Release Notes — [Month Year]

_Deployed [date]_

## Action needed
[Anything users must do, or a workflow that changes. Omit this section entirely if
there's nothing — an empty "None!" section trains people to skip the section.]

## What's new
- **[Feature name]** — [what you can now do, and where.]

## Improvements
- **[Area]** — [what's better and how you'll notice.]

## Fixes
- [What was broken, in the terms a user would have described it. Not the root cause.]

## Changes to existing behavior
- [What's different and why. Be direct — surprises here generate support tickets.]

## Coming next month
[Optional. Only include if there are genuine commitments; speculative roadmap items
in release notes create expectations you'll have to manage.]

---

# Technical Changelog — [Month Year]

**Release branch:** [name] · **Deployed:** [date] · **Tickets:** [count]

## By ticket
| Ticket | Type | Summary | Key metadata |
|---|---|---|---|

## Metadata inventory
[Objects, fields, flows, classes, permission sets added/modified/removed.]

## Post-deploy steps performed
[What was done manually, so the record exists for next time.]

## Notes for future reference
[Anything a developer six months from now would want to know — why an unusual
approach was taken, what was deliberately deferred, known limitations shipped.]
```

## Voice

Run `polish` on the stakeholder section, with the audience set to stakeholder. Release notes are the most-read and least-technical thing this team publishes, and they are exactly where AI-generated prose gets noticed. The patterns that matter most here:

- **Significance inflation** — "this pivotal enhancement underscores our commitment to" says nothing. State what changed.
- **Promotional language** — release notes are not marketing. "Streamlined," "seamless," and "robust" describe nothing a user can act on.
- **Superficial -ing phrases** — "improving efficiency and enhancing the user experience" is filler that survives because it sounds like content.
- **Generic conclusions** — "we look forward to continuing to improve the platform." Cut it or name the specific next thing.
- **Filler and hedging** — "it is important to note that users may wish to" becomes "you'll need to."

Two carve-outs. The technical changelog is reference material, so leave its tables and metadata inventory structured rather than converting them to prose. And the stakeholder register is institutional, not conversational — no first person, no jokes, unless the org already writes that way. `polish` handles this when told the audience is stakeholder rather than developer.

## Notes

The "Changes to existing behavior" section is the one that prevents support tickets, and it's the one most likely to get skipped because it's the least fun to write. Give it real attention. A user who was warned that a button moved is mildly annoyed; a user who discovers it themselves files a ticket.

If the release genuinely contains nothing user-visible — a month of technical debt and infrastructure — say that plainly in a short note rather than padding the stakeholder version with items nobody cares about. Credibility on the notes people *do* need to read depends on not wasting their attention the rest of the time.

Ask about anything ambiguous rather than guessing at business intent. A JIRA ticket reading "update area assignment criteria" could be a bug fix or a policy change, and those get written very differently.
