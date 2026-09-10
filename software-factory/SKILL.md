---
name: software-factory
description: Use the shared Software Factory for approved MyPenn or Compass Salesforce ticket delivery, package verification, and supervised check-only validation from the current product project.
---

# Software Factory delivery

Stay in the user's current MyPenn or Compass task. The shared tooling lives in `~/Developer/software-factory` (override with `SOFTWARE_FACTORY_ROOT`); product code belongs in the assigned product checkout/worktree. Use [scripts/factory](scripts/factory) as the entry point. It preserves the caller's working directory and invokes the shared implementation.

## Start in the product project

1. Read its current repository instructions. Run `scripts/factory inspect mypenn "$PWD"` for MyPenn or `scripts/factory inspect compass "$PWD"` for Compass. Use this script's absolute path when calling it from another directory. Repository identity checks accept worktrees of the configured repository and reject unrelated clones. Resolve any stale base refs before starting new work; preserve existing ticket branches and user edits.
2. Read `docs/project-integration.md` in the factory repository for the request format, exact commands, evidence and current limitations. Use `contracts/v1/delivery-request.schema.json` for the request. `inspect` is local and does not establish live org access.
3. Capture the selected approved ticket and acceptance criteria. Name the builder, independent accepting owner, explicit component scope/dependencies, tests, environment owner and repair budget (at most two repairs). Reuse existing scoped user authorization; do not invent decisions, target identities, test results or approval references. Profile unknowns stay unresolved until supported by current evidence.
4. For agent-led implementation, read `docs/agent-runtime.md` in the factory repository and create an `agent-project-request` with approved scope, criteria, immutable local check scripts, deadline and cumulative token budget. Call `agents-run REQUEST.json`; this launches the configured builder and a distinct evaluator against an isolated source copy. Inspect `agents-status RUN` for progress and `agents-cancel RUN` to request cancellation. Do not substitute the fixture demo for this run or claim acceptance when runtime settings or checks are unverified.
5. When work crosses research, story, planning, UAT, acceptance or release ownership, read [role handoffs](references/role-handoffs.md). Persist the applicable `role-handoff` contract and run `handoff-check` before a dependent stage. Optional `role-run` helpers require a concrete bounded need and an exact `role-dispatch-request`; ordinary fully specified work continues directly to the one builder and required evaluator.
6. Review the accepted isolated candidate and apply only its scoped changes to the assigned product worktree after confirming the source baseline is unchanged. Follow the project rules for development-org checks that need Salesforce access; worker networking is disabled. Then call `prepare` with the delivery request against the final product candidate. Keep requests, authorization files and evidence outside product commits.

## Read-only PM views

Use `scripts/factory pm-status <absolute-ledger.sqlite> [run-id]` for stable JSON status and `scripts/factory pm-summary <absolute-ledger.sqlite> [run-id]` for a Markdown summary. Both read the named factory ledger and return their output in the current task. They do not create another task, publish to an external system, mutate the ledger, or send stakeholder messages. Treat missing or unresolved evidence as pending rather than inferring completion.

## Supervised verification

- Local package preparation is reversible and needs no extra approval. For a concrete check-only run, use existing authorization covering this ticket, package and target; if it is missing, present the prepared package and exact action for the user to authorize. Record that real decision as a `validation-authorization` artifact bound to the returned candidate. Do not treat skill invocation or permission to install tooling as release authorization.
- Before protected Penn access, require visibly Connected GlobalProtect. Never connect/disconnect it automatically. Browser work uses a verified Work/Development profile. The adapter reads the visible VPN panel itself and verifies the exact sandbox Organization ID; open the panel if it cannot observe the state.
- A named owner must arrange an exclusive org operating window covering tests and cleanup, including manual/Gearset writers. `exclusiveUntil` records that arrangement; it is not a distributed lock. If a job outlives the window, retain ownership and reconcile it before allowing another writer.
- `validate RUN AUTHORIZATION` submits one exact-manifest `sf project deploy start --dry-run` job with named tests. MyPenn uses AdvPartial only for this check-only stage; implementation/testing remains on MyPennDev. Compass uses only its currently qualified profile target. Broad source-directory deploy examples from other skills do not apply to this adapter.
- `report RUN` retrieves the saved job. A pending job needs a later report, not another validate. Missing/uncertain submission receipts require reconciliation; never delete the intent or create a new run merely to retry the same uncertain operation. A failed job requires diagnosis before any newly authorized attempt.
- Check-only success proves package validation and the tests recorded by Salesforce. It does not establish business/UI acceptance, deployment, or promotion. Obtain independent criterion-level behavior/scope/security evidence for the same candidate through existing review/UAT workflows. Source, requirements, target, profile or test-plan changes invalidate the affected evidence and authorization.
- A configured role or an eligible routing decision is not proof that a helper ran. Depend only on a persisted handoff whose runtime settings, input versions, ownership and cumulative budget validate. Partial, rejected, blocked or stale handoffs stop dependent work.

## Handoff

Return the reviewable product change, the run evidence directory, actual check results, unresolved findings and pending stages. Promotion stays with the established project release process; MyPenn requires Gearset and AdvPartial Experience smoke after promotion/publish. The factory has no promotion command. Do not create another user-visible Codex task or send stakeholder messages without the user's request.
