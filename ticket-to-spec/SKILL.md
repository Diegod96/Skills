---
name: ticket-to-spec
description: Turn an approved but under-specified Salesforce request — a thin JIRA ticket, a Slack thread, a stakeholder email, a feasibility assessment — into a structured technical spec a developer can pick up and build without a follow-up meeting. Use this whenever someone says "write this up", "flesh out this ticket", "turn this into a spec", "what exactly do we need to build here", or hands over a ticket that says what to do but not how or where. Use it also when grooming a backlog or preparing tickets for sprint planning. Do NOT use this to decide whether work should happen at all — use assess-feasibility for that.
---

# Ticket to Spec

This skill converts an approved request into a spec precise enough that a developer can build from it without re-interviewing the stakeholder. The test of a good spec: two developers reading it would build the same thing.

The main failure mode to avoid is inventing requirements. Tickets are thin; the temptation is to fill silence with plausible-sounding detail. Resist it. **Anything not stated in the source belongs in the Open Questions section, not in the requirements.** A spec with eight open questions and honest gaps is more useful than a complete-looking spec built on guesses.

## Org context

Fill this in for your org:

- **Platform**: Salesforce (HEDA data model, Experience Cloud, Coveo search)
- **Source control**: GitLab, branch-per-feature — branch naming convention: [e.g. `feature/JIRA-123-short-description`]
- **Deployment**: Gearset, monthly cadence
- **Tracking**: JIRA — [note required fields, epic structure, story point scale]
- **Naming conventions**: [API name patterns, custom field suffixes, flow naming]
- **Standards**: [test coverage floor, required documentation, code review expectations]

## Process

1. **Read the source material** — ticket, thread, feasibility assessment, whatever exists. If a feasibility assessment exists, carry its risk flags and open questions forward rather than rediscovering them.
2. **Separate stated from inferred.** Keep a mental line between what the source says and what you're assuming. The assumptions get surfaced explicitly, not buried.
3. **Determine the mechanism** — the source describes an outcome; the spec describes the implementation. Choose declarative vs. programmatic and say why. If the choice isn't clear-cut, present the tradeoff rather than picking silently.
4. **Enumerate the metadata** — every object, field, automation, layout, permission set that gets created or modified. Be specific: API names, data types, field lengths, picklist values where known.
5. **Write acceptance criteria** in Given/When/Then form.
6. **Work the edge cases** (see below) — this is where most of the value is.
7. **List open questions** with a note on who can answer each and whether it blocks starting.

## Declarative vs. programmatic

State the choice and the reasoning. Rough heuristics:

- **Flow** — record-triggered logic, screen-based user interaction, scheduled batch work of modest volume. Default here; it's maintainable by admins.
- **Apex** — complex branching, callouts, high-volume bulk processing, anything needing transaction control or that would make a flow unreadable.
- **LWC** — custom UI beyond what a screen flow can express, or UI needing to live in Experience Cloud with specific behavior.
- **Config only** — validation rules, formula fields, layouts, reports. Always check whether the ask reduces to this before designing automation.

If the org already handles a similar case one way, match it. Consistency beats local optimality — a flow that matches five other flows is easier to maintain than a technically superior Apex class that stands alone.

## Edge cases to work through

For every spec, explicitly consider and document the answer (or mark it unknown):

- **Bulk behavior** — what happens on a 200-record data load, or a mass update from an integration?
- **Existing records** — does this apply to records created before the change? Is a backfill needed?
- **Null and empty states** — what if the driving field is blank?
- **Reentry** — what if the user or process runs this twice? Is the operation idempotent?
- **Recursion** — does this write to a field that feeds its own entry criteria, or another automation's? Flag loudly.
- **Permissions** — who can see and do this? What happens for a user who lacks access?
- **Deletion and merge** — what happens when a parent record is deleted or two records are merged?
- **Failure mode** — if this fails mid-process, what state is the data left in, and who finds out?

## Output format

```markdown
# Spec: [Ticket ID] — [Short title]

## Summary
[2–3 sentences: what's being built and why. Business outcome, not mechanism.]

## Approach
[Chosen mechanism and the reasoning. Note alternatives considered and why rejected.]

## Metadata changes

### New
| Type | API name | Details |
|---|---|---|

### Modified
| Type | API name | Change |
|---|---|---|

## Logic
[Step-by-step description of the behavior. Entry criteria, conditions, actions,
and the order they occur in. Precise enough to build from.]

## Acceptance criteria
- **Given** [context] **when** [action] **then** [outcome]
- ...

## Edge cases
| Case | Expected behavior |
|---|---|

## Permissions and visibility
[Who gets access, via what mechanism, and what non-entitled users see.]

## Testing notes
[What needs unit test coverage, what needs manual verification, what test data
is required — especially any data that's awkward to produce.]

## Dependencies and sequencing
[Other tickets, external teams, data loads, or release-ordering constraints.]

## Assumptions made
[Everything filled in that the source material did not state. Be exhaustive here —
this is the section the stakeholder should read to catch misinterpretation early.]

## Open questions
| Question | Who can answer | Blocks start? |
|---|---|---|
```

## Notes on tone and precision

Write for a developer who knows Salesforce but not this particular request. Skip explanations of what a flow is; don't skip the specific entry criteria.

Where you have a real recommendation, make it and defend it in a sentence. Where the source genuinely leaves a choice open, present the options with a leaning rather than pretending there's one obvious answer.

If the source material is so thin that the spec would be mostly assumptions, say so directly at the top and recommend a conversation with the requester before writing further. Producing a confident-looking spec from almost nothing wastes more time than it saves.
