# Role handoffs

Use role handoffs when responsibility changes. The current product task remains the coordinator and retains the complete request history. Do not create another user-visible task merely to represent a role.

The factory publishes strict v1 schemas for `role-handoff`, `role-dispatch-request`, `role-routing-decision` and `role-execution`. Keep these artifacts outside product commits. Every handoff names its owner and distinct accepting owner, exact parent handoff IDs and source/input versions, scope, interfaces, criteria, checks, evidence, findings, required outputs and the remaining cumulative repair/token/deadline budget.

## Existing skill chain

- Research: use a bounded repository explorer for a concrete codebase question. Use deeper research guidance only when the user asks for deep research. Return a `research` handoff with source references, findings and open questions.
- Story and acceptance criteria: use `assess-feasibility` for a raw unapproved request and `ticket-to-spec` for an approved thin request. Return a `story` handoff. Unresolved product decisions make it partial or blocked and return to their named owner.
- Technical planning: use `change-impact-mapper`, `permission-fls-auditor` and `apex-architecture` where their scopes apply. Return a `technical` handoff with exact interfaces, permissions, paths, owners and check IDs.
- Implementation: use `implement` with `ponytail`, then `agents-run` for the isolated Sol/high builder and mandatory Terra/high evaluator when the approved request fits the factory runtime. A technical handoff with unresolved decisions cannot be treated as implementation-ready.
- User journey testing: use `uat-script-drafter` and `ui-ux-smoke-tester` where UI evidence is required. Return a `uat` handoff bound to the exact candidate and observed environment. A failed, blocked or missing visible scenario remains blocking even when unit checks pass.
- Independent acceptance: use `acceptance-criteria-auditor` and `sf-code-reviewer` as applicable. Return an `acceptance` handoff bound to the exact candidate. The builder cannot accept its own work, and optional review does not replace the factory's mandatory evaluator.
- Release coordination: use `pre-deploy-checklist`, `rollback-plan-drafter` and `release-notes-generator` as applicable. Return a `release` handoff with package, authorization, validation, rollback and smoke evidence. This prepares supervised work; it does not promote, deploy, merge or send messages.

## Commands

Validate a persisted handoff against the current input bindings before consuming it:

```sh
scripts/factory handoff-check /absolute/handoff.json /absolute/current-inputs.json
```

Inspect a proposed optional route without dispatching it:

```sh
scripts/factory role-route /absolute/role-dispatch-request.json
```

Run an eligible optional helper only when the request contains an explicit bounded reason, allowed capabilities, exact required outputs, a role/model/effort authorization and an allocation within the inherited remaining budget:

```sh
scripts/factory role-run /absolute/role-dispatch-request.json
```

Optional roles are read-only. Their runtime cannot access external apps, protected environments or product-write authority. The requested and effective model settings must match exactly; there is no silent fallback. Proposed Astra/Luna routes remain configured-only unless a future approved policy adds a supported explicit route.

Reject downstream use when any required field is absent, the accepting owner conflicts, a binding version/hash changed, a deadline or budget is exhausted, a blocking finding remains, or the handoff status is partial, rejected or blocked. Preserve prior findings and usage when escalating; routing does not reset the builder's at-most-two-repair ceiling.
