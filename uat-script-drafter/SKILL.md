---
name: uat-script-drafter
description: Turn an approved JIRA story, spec, or set of acceptance criteria into a step-by-step manual test script that a non-technical tester can execute without help — a business stakeholder, a program admin, a gift officer. Covers prerequisites and test data, click-by-click steps in plain language, expected results the tester can actually see on screen, permission and negative cases, and a pass/fail record sheet. Use this whenever someone asks for a "test script", "UAT script", "test plan", "test cases for this ticket", "how do we test this", "something for the business to test", or is preparing a feature for user acceptance testing, a stakeholder demo, or sign-off before a release. Do NOT use this for Apex unit tests, test classes, or code coverage — use test-coverage-gap-finder for that.
---

# UAT Script Drafter

Produce a manual test script for someone who knows the business process and nothing about Salesforce internals. The reader is a gift officer, a program coordinator, a stakeholder who agreed to spend forty minutes clicking through a feature before it ships. They will not read a spec, they cannot query the database, and if a step confuses them they will guess rather than ask.

The test of a good script: the tester completes it alone, and their pass/fail marks mean something to a developer afterward.

The dominant failure mode is writing steps that only work if you already know the answer. "Verify the record updates correctly" is not a test step — the tester has no idea what correct looks like, so they will glance at the screen, see no error, and mark it Pass. Every expected result must be specific enough that a tester who has never seen the feature can tell the difference between working and broken.

The second failure mode is API names leaking into the script. `Engagement__c`, `Status__c`, "the record-triggered flow" — every one of these is a place the tester stops reading. That vocabulary is correct in a spec and wrong here.

## Org context

Fill this in for your org:

- **UAT environment**: [sandbox name and login URL testers use]
- **Test personas and logins**: [e.g. Gift Officer, Program Admin, Community user — who provides credentials, and how]
- **Where scripts live**: [JIRA Xray / Confluence page / shared spreadsheet — and the naming convention]
- **Who tests**: [names or roles per functional area]
- **Sign-off**: [who accepts UAT results, and what "done" requires]
- **Test data conventions**: [e.g. records prefixed `UAT —`, which are safe to modify, which are protected]
- **Support during UAT**: [who the tester contacts when stuck, and the expected response time]

The personas line is the highest-value one. A script written without knowing which logins exist ends up saying "log in as a user with the appropriate permissions," which is exactly the instruction a non-technical tester cannot follow.

## Process

1. **Read the source** — JIRA story, spec, acceptance criteria. If a spec exists, its Given/When/Then criteria are the skeleton of the script and its Edge cases table is the source of the negative tests. Do not re-derive them.
2. **Identify the personas.** Who is supposed to be able to do this, and who is supposed to be blocked? Each answer is a separate section of the script.
3. **Work out the prerequisites** — what has to exist before step 1 can run. This is the part that gets skipped and the part that wrecks UAT sessions.
4. **Convert each acceptance criterion into a numbered sequence.** One criterion usually becomes three to eight steps.
5. **Add the negative and permission cases** that the criteria imply but do not state.
6. **Translate every step into tester vocabulary** — the plain-language pass described below. This is where most of the value is.
7. **Add the record sheet** so results come back in a form a developer can act on.

## From acceptance criteria to steps

A criterion in the spec reads:

> **Given** a mentorship engagement with no assigned mentor **when** the coordinator saves the record **then** the status is set to Pending Match and the coordinator receives a confirmation email.

That is one criterion and roughly six steps. The conversion rules:

- **Given** becomes prerequisites plus navigation. The tester has to arrive at that state by clicking, and someone has to have created the record.
- **When** becomes the action steps, one interaction per step.
- **Then** becomes expected results, split so that each observable outcome is checked separately. Two outcomes in one step means a half-failure has nowhere to be recorded.

Off-screen outcomes need a way to be seen. A confirmation email is verifiable — tell the tester which inbox and roughly how long to wait. A field the feature writes but no page layout displays is not verifiable by this tester at all; either get it onto a layout for UAT or move that check to the developer's list and say so.

## Test data

Non-technical testers cannot create the awkward records. If the script needs an engagement with no mentor, a lapsed donor, or a constituent with two overlapping program enrollments, someone builds those in advance and the script names them exactly.

State for each prerequisite record: what it is, its exact name as it appears in search, and who creates it. "A test constituent" fails. "The constituent record named `UAT — Marcus Webb`, created by the dev team before the session" works.

Flag anything the tester will consume. A script that sends an application through an approval can usually only be run once per record, so either provide several records or say plainly that a reset is needed between attempts. Testers who hit this discover it halfway through and lose the rest of the session.

## Beyond the happy path

Include what a business tester can actually check. Skip what they cannot.

**Worth including:**

- **Permission cases** — log in as a persona who should not see the feature and confirm they do not. This is the check most often skipped and the one that catches the most embarrassing bugs.
- **Negative input** — required field left blank, a date in the past, a text field over its limit. The tester should see a specific, sensible message rather than a raw platform error.
- **Cancel and back out** — start the process, abandon it partway, confirm nothing was half-saved.
- **Existing records** — run the feature against a record created before this change, not only a freshly made one.
- **The second run** — do it twice on the same record. Duplicate emails and doubled values surface here.
- **Community and mobile** — if the feature touches Experience Cloud, it gets tested as a community user, not only internally. If stakeholders use phones, one path gets checked on a phone.

**Leave out:** bulk and data-load behavior, governor limits, order-of-execution questions, anything needing the developer console or a SOQL query. Those are real risks and they belong to `test-coverage-gap-finder` and `sf-code-reviewer`. Putting them in a stakeholder script produces steps nobody can run and erodes trust in the rest of the document.

## Writing the steps

This is the part that determines whether the script is usable.

**One action per step.** If a step contains "and then," split it.

**Name what they click, exactly as it appears, in bold.** Click **Save**, not "save the record." If the button says "Submit for Review," the script says **Submit for Review** and not "submit it."

**Navigate from a known starting point.** Every section begins somewhere unambiguous — usually the Home page after login. "Open the engagement" assumes the tester knows where engagements live. "From the Home page, click the **Engagements** tab, then click `UAT — Marcus Webb`" does not.

**Use the label on the screen, never the API name.** The tester sees "Engagement Status." They never see `Status__c`. If a field's label and API name differ, the label wins, every time.

**Describe outcomes, never mechanisms.** The tester does not need to know a flow ran, a trigger fired, or a record was upserted. They need to know what changed on the screen in front of them.

**Make every expected result falsifiable by looking.** Compare:

| Instead of | Write |
|---|---|
| Verify the status updates correctly | The **Engagement Status** field now reads "Pending Match" |
| Confirm the notification is sent | Within 5 minutes, `coordinator@example.edu` receives an email with the subject "New engagement awaiting match" |
| Check that permissions are enforced | The **Assign Mentor** button does not appear anywhere on the page |
| Ensure the record saves | The page returns to the engagement, and a green confirmation bar appears at the top |

**No hedging in expected results.** "Should probably show" and "may display" leave the tester guessing whether a difference is a bug. State exactly one outcome. If the behavior is genuinely variable, that is a spec gap — raise it rather than papering over it in the script.

**No jargon, no abbreviations, no "etc."** A step ending in "and so on" cannot be passed or failed.

**Say how long.** A rough time estimate per section lets a stakeholder schedule the session honestly. Forty minutes described as "a quick look" is how UAT gets abandoned at step 12.

## Output format

```markdown
# UAT Script: [Ticket ID] — [Feature name in business terms]

**Tester:** ______________  **Date:** __________  **Environment:** [sandbox + URL]
**Estimated time:** [n] minutes

## What you're testing
[2–3 sentences in plain language. What changed and why it matters to the
people who do this work. No API names, no mechanism.]

## Before you start
| # | Prerequisite | Who provides it |
|---|---|---|
| 1 | Login for the [persona] account | [name] |
| 2 | The record named `UAT — [exact name]` | [name] |

**If something goes wrong:** [contact + how to reach them]. Note the step number
and what you saw, then continue to the next section if you can.

## Section 1: [What this section proves, in business terms]
*Persona: [which login] · Estimated: [n] minutes*

| # | Do this | You should see | Pass / Fail | Notes |
|---|---|---|---|---|
| 1.1 | From the Home page, click the **[Tab]** tab | A list of [records] appears | ☐ P ☐ F | |
| 1.2 | Click `UAT — [exact record name]` | The [record] page opens, showing **[Field]** as "[value]" | ☐ P ☐ F | |

## Section 2: [Next scenario]
...

## Section 3: Access checks
*Persona: [a user who should NOT have access]*

| # | Do this | You should see | Pass / Fail | Notes |
|---|---|---|---|---|

## After you finish
[Anything to clean up or leave alone. Who to send the completed script to.]

## For the development team
[Not for the tester. Checks that could not be expressed as clickable steps and
need a developer: off-layout fields, bulk behavior, integration payloads. Say
plainly that these are unverified by UAT.]
```

The Pass/Fail column and the Notes column both matter. Testers who have nowhere to write "it worked but took 30 seconds" will mark Pass and mention it to nobody.

## Voice

The prose sections — "What you're testing," the failure instructions, the closing — go through `polish` with the audience set to stakeholder. These are read as sentences by someone outside the team, and they are exactly where generated padding shows up. Cut significance inflation, promotional adjectives, and filler openers hard.

**The step tables are a deliberate exception.** `polish` states it does not apply to numbered procedural steps, tables, or checklists, and that carve-out is correct here: those cells are scanned and executed, not read, and rewriting them for flow makes them worse. Repeating "click" fifteen times is right. Varying it to "select," "choose," "press," and "hit" is a readability regression, because the tester now wonders whether the four words mean four different things.

So the steps get a different pass, the plain-language rules above rather than a prose edit. Run it as a checklist over every row:

- Would a tester who has never seen this feature know exactly where to click?
- Is the expected result something they can see, and something they could mark Fail against?
- Did an API name, a mechanism, or an abbreviation survive?
- Is there exactly one action and one outcome in the row?

## When the tester finds a problem

Build the script so failures come back usable. A returned script that says "step 2.3 failed" costs a round trip; "step 2.3 — the status stayed 'Draft' and a red bar said Insufficient Privileges" usually does not.

Tell the tester, in the failure instructions, to record what they saw rather than what they expected, and to keep going where possible. Testers who believe they have broken something tend to stop, and one blocked path in section 2 should not cost you sections 3 through 6.

## Notes

If the acceptance criteria are too thin to produce specific expected results, that is a finding about the ticket, not a problem to write around. Say so and go back to `ticket-to-spec` rather than inventing behavior — a script full of invented expected results teaches the tester to distrust the whole document the first time one is wrong.

Where a feature genuinely cannot be verified through the UI by this audience, put it in the "For the development team" section and state that UAT does not cover it. An honest gap is worth more than a step nobody can run, and it gives the pre-deploy check something concrete to pick up.
