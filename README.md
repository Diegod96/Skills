# Salesforce Team Skills

Fourteen skills covering the path from an unscoped stakeholder request through to a deployed, documented release.

## The pipeline

```
INTAKE                    BUILD                      SHIP
──────                    ─────                      ────
assess-feasibility   →  implement  ──────────→   pre-deploy-checklist
       ↓                sf-code-reviewer           release-notes-generator
ticket-to-spec          test-coverage-gap-finder   rollback-plan-drafter
       ↓                permission-fls-auditor     uat-script-drafter
change-impact-mapper    acceptance-criteria-auditor
```

`implement` is the only skill that executes rather than advises — it runs git and
sf CLI commands against real orgs. The other three build-phase skills are its
manual counterparts: run them on a branch `implement` produced, or on one a human
wrote.

### Intake

| Skill | Runs on | Answers |
|---|---|---|
| **assess-feasibility** | A raw, unapproved request | "Should we do this, and roughly how big is it?" |
| **ticket-to-spec** | An approved request | "Exactly what are we building?" |
| **change-impact-mapper** | A spec or proposed change | "What else does this touch?" |

`assess-feasibility` and `change-impact-mapper` both look at dependencies, but differ in depth and audience — the first is a fast gut-check for a go/no-go decision, the second is a near-exhaustive technical trace once you're committed. When feasibility can't confidently size something because of hidden automation, that's the signal to run the impact mapper.

### Build

| Skill | Runs on | Answers |
|---|---|---|
| **implement** | An approved spec | "Build it, test it, validate it, open the MR." |
| **acceptance-criteria-auditor** | A branch plus its ticket | "Is it built, and what's left?" |
| **sf-code-reviewer** | A branch or MR | "Is this correct and bulk-safe?" |
| **test-coverage-gap-finder** | A branch | "What's actually verified, not just executed?" |
| **permission-fls-auditor** | A feature or field | "Who can see this — and who shouldn't?" |

### Ship

| Skill | Runs on | Answers |
|---|---|---|
| **pre-deploy-checklist** | A release package | "What's true in sandbox that won't be in production?" |
| **uat-script-drafter** | A story headed for user acceptance testing | "How does a non-technical tester verify this?" |
| **release-notes-generator** | Merged tickets and branches | "What changed, and who needs to know?" |
| **rollback-plan-drafter** | A release package | "What do we do if this goes wrong?" |

### Cross-cutting

| Skill | Runs on | Answers |
|---|---|---|
| **apex-architecture** | Any task producing Apex or LWC | "Which layer does this belong in?" |
| **polish** | Any document headed for a human | "Does this read like an engineer wrote it?" |

`apex-architecture` encodes the team's mandatory Controller → Service → Domain → Selector standard. `ticket-to-spec` decomposes by layer, `implement` places code by layer, `sf-code-reviewer` enforces it, and the interrogate lens checks it. See `integration/apex-standards-decisions.md` for the corrections applied and the reasoning behind each rule added in v2.

The three build-phase review skills answer different questions and are worth running in order: `acceptance-criteria-auditor` asks whether the ticket is built, `sf-code-reviewer` whether it is built well, `test-coverage-gap-finder` whether it is proven. The auditor is also the tool for a branch that went cold — it reports what you left unfinished and what moved on `main` while you were away, then hands the gap list to `implement`.

`uat-script-drafter` covers the other half of testing from `test-coverage-gap-finder`: that one finds untested logic and drafts Apex test methods, this one turns acceptance criteria into a click-by-click script a stakeholder can run. It reads a spec's Given/When/Then criteria and Edge cases table directly, so run `ticket-to-spec` first where one exists.

`polish` applies to prose, not to code, metadata, tables, or checklists. `release-notes-generator` and `implement` call it on their prose sections; run it manually on specs, impact maps, and anything going to a stakeholder.

## Setup

Each SKILL.md has an **Org context** section near the top with bracketed placeholders. Fill these in before use — they're what make the output specific to your org rather than generic Salesforce advice. The highest-value ones to populate:

- **Known-fragile automation** — the flows and triggers with a history of surprises. This drives risk flags across `assess-feasibility`, `change-impact-mapper`, and `rollback-plan-drafter`.
- **Integrations, inbound and outbound** — impossible for the skill to infer, and the source of most missed dependencies.
- **Custom permissions and permission strategy** — `permission-fls-auditor` is much weaker without this.
- **Backup tooling and frequency** — `rollback-plan-drafter` depends on it entirely.

If you'd rather not maintain the same context in nine files, pull the shared parts into a single `org-context.md` in the repo and replace each skill's section with a pointer to it. That works well when the skills live in a repo the team reads; it works less well if skills get installed individually, since the reference would break.

## Chaining

The outputs are designed to feed forward:

- Feasibility risk flags → carried into the spec's open questions rather than rediscovered
- Spec metadata list → the starting point for the impact map
- Impact map's "external and downstream" section → the communication list in the pre-deploy checklist
- Pre-deploy manual steps → the "post-deploy steps performed" record in the changelog
- Pre-deploy runtime risks → the decision criteria in the rollback plan

## Suggested first two

`assess-feasibility` and `pre-deploy-checklist` tend to pay off fastest — the first because triage happens constantly and inconsistently, the second because deployment misses are concrete, repeated, and expensive. The review-side skills overlap somewhat with existing tooling, so they're worth tuning against what your current setup already catches before leaning on them.
