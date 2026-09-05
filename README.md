# Salesforce Team Skills

Seventeen skills covering the path from an unscoped stakeholder request through to a deployed, documented release, plus the operational graph that can coordinate and audit that work.

## Cursor plugin

This repository is also a native Cursor plugin named `salesforce-team-skills`.
Its manifest lives at `.cursor-plugin/plugin.json` and exposes all seventeen skill
folders without duplicating them.

For local development or personal use, preview and install an exact package into
Cursor's local plugin directory:

```bash
./install-cursor-plugin.sh --dry-run
./install-cursor-plugin.sh
```

The installer reads the manifest, copies only the declared skills and plugin
metadata, removes stale files inside this plugin's destination, and verifies the
installed package. It does not modify other local Cursor plugins. A copied local
package is used because some Cursor builds reject plugin symlinks that resolve
outside `~/.cursor/plugins/local`.

Restart Cursor or run **Developer: Reload Window**, then open **Customize** and
confirm that `salesforce-team-skills` and its seventeen skills are visible. Cursor
lists skills under **Agent Decides** and supports manual invocation with
`/skill-name`.

For marketplace distribution, publish the repository and submit its URL through
Cursor's plugin publishing flow. The repository root is the marketplace plugin
root; no committed generated bundle or copied `skills/` directory is required.

## Grok CLI/TUI plugin

Grok's local CLI/TUI loader uses a separate registry from Cursor. Preview and
install the same seventeen skills as the user-level `salesforce-team-skills`
plugin with:

```bash
./install-grok-plugin.sh --dry-run
./install-grok-plugin.sh
```

The installer builds and validates the plugin package, registers this
repository as a local Grok marketplace, installs it, enables it, and verifies
the files. Skills can be invoked from the Grok CLI/TUI with their
plugin-qualified names, such as `/salesforce-team-skills:ticket-to-spec`.

The **Plugins** dialog in the Grok Bot desktop app is a separate, account-level
Marketplace catalog. Local CLI/TUI marketplaces do not appear in that search
box. To show this plugin there, publish the marketplace to a Git repository
and have the Grok Bot account or team administrator add that repository to the
server-side catalog; a local filesystem install cannot create that catalog
entry.

## The pipeline

```
INTAKE                    BUILD                      SHIP
──────                    ─────                      ────
assess-feasibility   →  implement  ──────────→   pre-deploy-checklist
       ↓                sf-code-reviewer           ui-ux-smoke-tester
ticket-to-spec          test-coverage-gap-finder   release-notes-generator
       ↓                permission-fls-auditor     rollback-plan-drafter
change-impact-mapper    acceptance-criteria-auditor uat-script-drafter
```

`implement` is the skill that executes source-control and Salesforce CLI work against
real orgs. `ui-ux-smoke-tester` also executes: it drives a reachable authenticated
browser in smoke-only mode and, with explicit delivery authorization, can repair a
verified defect on its owning feature branch through dev deployment, tests, commit,
and push. `graph-engineering` can produce orchestration definitions or executor code
when implementation is explicitly requested; designing a graph does not itself
authorize agent creation, infrastructure changes, or deployment. The other
build-phase skills are `implement`'s manual counterparts: run them on a branch
`implement` produced, or on one a human wrote.

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
| **implement** | An approved spec | "Build it, test it, validate it, open the MR, follow checks and reviews." |
| **acceptance-criteria-auditor** | A branch plus its ticket | "Is it built, and what's left?" |
| **sf-code-reviewer** | A branch or MR | "Is this correct and bulk-safe?" |
| **test-coverage-gap-finder** | A branch | "What's actually verified, not just executed?" |
| **permission-fls-auditor** | A feature or field | "Who can see this — and who shouldn't?" |

### Ship

| Skill | Runs on | Answers |
|---|---|---|
| **pre-deploy-checklist** | A release package | "What's true in sandbox that won't be in production?" |
| **ui-ux-smoke-tester** | A reachable authenticated UI | "Can the critical user path work and look right right now?" |
| **uat-script-drafter** | A story headed for user acceptance testing | "How does a non-technical tester verify this?" |
| **release-notes-generator** | Merged tickets and branches | "What changed, and who needs to know?" |
| **rollback-plan-drafter** | A release package | "What do we do if this goes wrong?" |

### Cross-cutting

| Skill | Runs on | Answers |
|---|---|---|
| **apex-architecture** | Any task producing Apex or LWC | "Which layer does this belong in?" |
| **graph-engineering** | An agent workflow, execution graph, or orchestration design | "How should tasks, permissions, evidence, state, and recovery fit together?" |
| **ponytail** | Implementation, refactoring, or code review | "What is the simplest maintainable change that meets the requirements?" |
| **polish** | Any document headed for a human | "Does this read like an engineer wrote it?" |

`apex-architecture` encodes the team's mandatory Controller → Service → Domain → Selector standard. `ticket-to-spec` decomposes by layer, `implement` places code by layer, `sf-code-reviewer` enforces it, and the interrogate lens checks it. See `integration/apex-standards-decisions.md` for the corrections applied and the reasoning behind each rule added in v2.

`ponytail` adapts [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)
under its MIT license. It favors reuse, standard libraries, and native features
while preserving the full request, Salesforce layering, permissions, and required
tests. `implement` and `sf-code-reviewer` refer to it during solution selection
and review. Invoke it directly with `$ponytail` in Codex or `/ponytail` where
supported. It is a portable skill with no lifecycle hooks or MCP dependency;
upstream provenance and adaptation notes are in `ponytail/SKILL.md`.

`graph-engineering` is broader than Salesforce dependency mapping. It designs or audits the operational control plane: typed task edges, constrained roles, runtime state, provenance, deterministic quality gates, human approvals, and recovery. Use `change-impact-mapper` to discover what a Salesforce change touches; use `graph-engineering` when those findings must become an executable, observable workflow.

The three build-phase review skills answer different questions and are worth running in order: `acceptance-criteria-auditor` asks whether the ticket is built, `sf-code-reviewer` whether it is built well, `test-coverage-gap-finder` whether it is proven. The auditor is also the tool for a branch that went cold — it reports what you left unfinished and what moved on `main` while you were away, then hands the gap list to `implement`.

`uat-script-drafter` covers the other half of testing from `test-coverage-gap-finder`: that one finds untested logic and drafts Apex test methods, this one turns acceptance criteria into a click-by-click script a stakeholder can run. It reads a spec's Given/When/Then criteria and Edge cases table directly, so run `ticket-to-spec` first where one exists.

`ui-ux-smoke-tester` is the execution counterpart to that script: it drives a small
number of critical paths in a reachable authenticated UI and reports observed
behavior, visible UX defects, browser-console signals, blockers, and untested
boundaries. With explicit smoke-and-deliver authorization, it can also trace an
in-scope defect to its original feature branch, repair it, deploy to a development
org, run applicable Apex tests, re-smoke, then commit and push after every gate
passes. It does not draft a UAT script, judge whether a branch meets its ticket, or
replace a full accessibility or regression audit.

`polish` applies to prose, not to code, metadata, tables, or checklists. `release-notes-generator` and `implement` call it on their prose sections; run it manually on specs, impact maps, and anything going to a stakeholder.

## Setup

Most Salesforce SKILL.md files have an **Org context** section near the top with bracketed placeholders. Fill these in before use — they're what make the output specific to your org rather than generic Salesforce advice. The `ui-ux-smoke-tester` instead establishes the browser, environment, profile, persona, and data boundary at run time. The highest-value org-context fields to populate:

- **Known-fragile automation** — the flows and triggers with a history of surprises. This drives risk flags across `assess-feasibility`, `change-impact-mapper`, and `rollback-plan-drafter`.
- **Integrations, inbound and outbound** — impossible for the skill to infer, and the source of most missed dependencies.
- **Custom permissions and permission strategy** — `permission-fls-auditor` is much weaker without this.
- **Backup tooling and frequency** — `rollback-plan-drafter` depends on it entirely.

If you'd rather not maintain the same context in multiple files, pull the shared parts into a single `org-context.md` in the repo and replace each Salesforce skill's section with a pointer to it. That works well when the skills live in a repo the team reads; it works less well if skills get installed individually, since the reference would break.

## Chaining

The outputs are designed to feed forward:

- Feasibility risk flags → carried into the spec's open questions rather than rediscovered
- Spec metadata list → the starting point for the impact map
- Impact map's "external and downstream" section → the communication list in the pre-deploy checklist
- Pre-deploy manual steps → the "post-deploy steps performed" record in the changelog
- Pre-deploy runtime risks → the decision criteria in the rollback plan
- Reachable release environment → `ui-ux-smoke-tester`'s evidence-backed critical-path result
- Smoke blockers and residuals → a repair/retest loop or a stakeholder-ready UAT script

## Suggested first two

`assess-feasibility` and `pre-deploy-checklist` tend to pay off fastest — the first because triage happens constantly and inconsistently, the second because deployment misses are concrete, repeated, and expensive. The review-side skills overlap somewhat with existing tooling, so they're worth tuning against what your current setup already catches before leaning on them.
