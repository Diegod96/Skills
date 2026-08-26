---
name: ui-ux-smoke-tester
description: Run a narrow, evidence-backed smoke test against a reachable web UI in an authenticated browser, exercising critical paths and checking visible UX defects with read-only-by-default safety. When the user explicitly requests end-to-end remediation, trace an in-scope defect to its exact feature branch, fix it, deploy to a development org, run applicable Apex tests, re-smoke, then commit and push only after the delivery gates pass. Use for smoke tests, demo checks, live UI verification, or an explicitly requested smoke-and-fix workflow. Do not use for drafting UAT scripts, code-only audits, or full accessibility and regression audits.
---

# UI/UX Smoke Tester

Answer one practical question: **can the intended user complete the requested critical path in this reachable UI, and does it remain visibly usable while doing so?** This is an execution skill. Drive the real browser, observe the rendered page, and return evidence from the run; do not return only a test plan or a list of suggested cases.

Keep the run small and high-value. A smoke test is a focused check of entry, the primary interaction, the expected feedback, and the next meaningful state. It is not a substitute for code review, an acceptance-criteria audit, a stakeholder-ready UAT script, a full accessibility review, or a cross-browser/regression matrix.

## Choose the operating mode

- **Smoke-only** is the default. Exercise the UI, preserve evidence, and report findings without editing source, deploying metadata, committing, or pushing.
- **Smoke-and-deliver** applies only when the user explicitly authorizes end-to-end remediation, including the intended delivery actions. Read [references/remediation-delivery.md](references/remediation-delivery.md) before touching source. Follow the installed `implement` skill for Salesforce implementation mechanics where available, with the existing-branch and delivery gates in that reference taking precedence.

An instruction to “smoke test,” “check,” “diagnose,” or “document bugs” does not authorize remediation. An instruction to “fix” authorizes a scoped local repair, not deployment or git publication by itself. Commit and push only when the user has explicitly requested delivery, shipping, or the deploy/test/commit/push sequence. If authorization is unclear, finish the smoke report and ask before crossing into the next mode.

## Inputs and scope

Establish these before interacting:

- **Target** — application, exact environment or origin, route, and viewport if one is requested.
- **Path** — the one to five critical user journeys to exercise, including the intended persona and safe starting state.
- **Expected result** — the visible outcome supplied by the user, ticket, spec, or known product behavior. If expectations are inferred from the UI, label the assumption rather than presenting it as a requirement.
- **Browser context** — requested browser or surface, profile, authenticated persona, and any team-specific named instance.
- **Data boundary** — records or fixtures that may be read, and whether any mutation has been explicitly authorized.
- **Delivery boundary** — smoke-only, local repair, repair and dev deploy, or smoke-and-deliver through commit and push.

If the route, environment, persona, or expected outcome cannot be determined without guessing, ask for that missing information. Do not manufacture a user, record, login state, or success criterion. If the target is clear but prerequisites are unavailable, report the run as blocked and state what is missing.

## Guardrails

### Read-only by default

Navigation, refresh, scrolling, opening a menu or modal, changing a view-local filter, and other actions that do not persist state are allowed by default. Treat anything that can save, submit, create, update, delete, send, pay, change settings, trigger an automation, or autosave as a mutation.

- Do not perform a mutation unless the user explicitly authorizes that action and target in the current task.
- If a mutation is authorized, restate the exact action, environment, and data target before executing it. Ask for immediate confirmation before destructive, irreversible, externally visible, or high-impact actions.
- Prefer a dedicated disposable/test record. Never change production data merely to obtain a convenient fixture, and stop if the only available fixture requires an unsafe change.
- Record every authorized mutation and its before/after state. Clean it up only when cleanup is explicitly authorized and safe; report anything that remains.
- If an interaction may autosave and its behavior is not known, do not type or submit. Mark that boundary untested and request authorization or a safe fixture.

Do not inspect cookies, passwords, session stores, tokens, or local storage to prove authentication. Verify identity and access through visible UI such as the account menu, profile label, or application chrome. Do not bypass a login or access error with a public URL, search engine, API, or a different account.

## Establish the browser and environment

Use the applicable browser-control skill or tool and follow its documented setup and selection rules. The browser is evidence, not an assumption.

1. Honor an explicitly requested browser or surface. If none is named, use the available default or the browser appropriate for the target URL.
2. Verify the selected browser, profile, current origin, environment, route, viewport, and visible authenticated persona before testing. For Chrome-family work sessions, verify the requested Work/Development profile and any named authenticated instance required by the team (for example, Dia); never assume the first connected browser is correct.
3. If the page redirects to login, an unauthorized page, the wrong org or environment, or an unexpected account, stop. Classify it as an environment/authentication blocker rather than trying a workaround. If the user must sign in, tell them which browser/profile needs it and wait for the authenticated state.
4. Capture a baseline URL and page state. Take a screenshot or DOM snapshot when it will help prove a visual issue, but do not capture secrets or unnecessary personal data.

Use visible, stable roles, labels, and text to find controls. Re-snapshot after navigation, a modal/menu transition, a tab switch, or a substantial DOM change because prior references may be stale. Do not call a path a pass from hidden DOM state or an API response when the requested outcome is visible in the UI.

## Execute the smoke paths

For each in-scope path:

1. State the starting condition and the expected visible result before taking the action.
2. Perform the smallest sequence that exercises the critical path. Record the action and the actual observation, including visible text, route changes, loading behavior, and control state.
3. Check the primary feedback: success, validation, error, empty, loading, and disabled states as applicable. A spinner that never resolves, a blank panel, a hidden/occluded primary control, or an error shown to the user is a result, not a detail to hand-wave away.
4. Check lightweight UI/UX signals in the path: clipping or overflow, overlapping content, truncation that changes meaning, broken imagery, unreadable labels, unexpected focus loss, unusable controls, layout collapse at the requested viewport, and feedback that is absent or ambiguous. Do not expand this into a full accessibility or visual-regression audit.
5. Capture useful evidence at the point of failure or anomaly: route, visible text, action that led there, screenshot, and a concise locator or control label. Avoid sensitive values.
6. If one path fails, preserve evidence and run other independent, safe paths where doing so will not obscure the failure or create side effects. Do not work around a blocker by changing the requested persona, environment, data boundary, or mutation policy.

Do not turn incidental polish preferences into defects. Report a UI issue when it impairs completion, comprehension, feedback, or confidence in the tested path, or when the request explicitly names that visual behavior.

## Separate rendered failures from console signals

Inspect browser console output only when the selected browser surface exposes it, and label it separately from what the user saw.

| Signal | Path result | How to report it |
|---|---|---|
| Visible error, blank content, wrong state, stuck loading, or broken control | **Fail**; **Blocker** when it prevents a critical path, otherwise a residual issue | Quote the visible observation and action that produced it. |
| Console error or warning with no user-visible impact | Does not fail the path by itself | Put it under **Console-only signals** with source, repetition, and whether it is feature-specific. |
| Network or API failure that changes the rendered result | Treat as a visible failure | Report the user-visible consequence; include the technical signal only as supporting evidence. |
| Network, extension, or third-party noise with no visible impact | No path failure | Record only when reproducible and relevant to the tested feature; do not inflate generic noise. |
| Authentication, permission, environment, or missing-data error before the path can run | **Blocked** | Identify the prerequisite and the exact visible state. Do not call the product behavior failed unless access handling itself is the requested behavior. |

If console inspection was unavailable, say **console not observed**. Never report “no console errors” when the console was not checked.

## Classify outcomes and provenance

Use these path statuses:

- **Pass** — the expected visible result occurred and no blocker was observed.
- **Fail** — the path ran, but the visible result was missing, incorrect, unusable, or contradicted the stated expectation.
- **Blocked** — the path could not be fairly run because of authentication, environment, access, data, tooling, or an unsafe mutation boundary.
- **Not run** — the path was intentionally outside the authorized scope or skipped after its prerequisite became unsafe. Never imply that it passed.

Classify findings independently from path status:

- **Blocker** — a critical path cannot be completed, or a severe visible defect prevents safe or meaningful use.
- **Residual** — the tested path completes, but a visible UX/UI defect remains in the current run.
- **Pre-existing** — evidence shows the issue was present before the target action/build, or it is a documented known issue reproduced in an unaffected baseline. Cite that evidence.
- **Console-only** — a browser signal without a user-visible impact. It is still worth recording when feature-specific or repeated, but it is not automatically a defect or blocker.
- **Observed, provenance unknown** — the issue is real in this run, but there is not enough baseline or history to call it pre-existing or a regression.

A single run cannot prove that an issue is a regression or pre-existing. Do not use either label from intuition. Compare against a supplied baseline, a previous build, an unaffected route, or a documented known issue; otherwise use **Observed, provenance unknown**.

Overall status follows the strongest supported evidence:

- **Pass** — all requested paths ran and passed; no blocker or residual was observed.
- **Pass with residuals** — all requested paths passed, but one or more residual or pre-existing issues were recorded.
- **Fail** — at least one requested path ran and failed due to product behavior or a visible UX/UI defect.
- **Partial** — some paths passed, but another requested path was not run or was blocked; no executed path failed.
- **Blocked** — the authentication, environment, or data gate prevented meaningful execution of the requested smoke scope.

## Report format

Return an evidence-backed report in this shape. Keep the distinction between what was observed and what was inferred.

```markdown
# UI/UX Smoke Test: [application or flow]

**Overall:** [Pass / Pass with residuals / Fail / Partial / Blocked]
**Environment:** [origin] · [route] · [browser/surface] · [profile] · [persona] · [viewport]
**Run mode:** [Read-only / Authorized mutation: exact scope]
**Paths:** [n passed] passed · [n failed] failed · [n blocked] blocked · [n not run] not run
**Data changes:** [None observed / exact records and actions / unknown, with reason]
**Console:** [Not observed / n console-only signals]

## Scope and prerequisites
[Starting data, supplied expectations, assumptions, access checks, and anything that was unavailable.]

## Path results
| ID | Critical path and start state | Actions exercised | Expected visible result | Observed result | Status | Evidence |
|---|---|---|---|---|---|---|
| P1 | ... | ... | ... | ... | Pass | screenshot or route |

## Findings
### Blockers
[Each finding: path/step, expected vs observed, impact, environment, and evidence.]

### Residual or observed UX issues
[Use Residual, Pre-existing, or Observed, provenance unknown and explain the evidence.]

### Console-only signals
[Signal, source, count/repeatability, and whether the UI still passed.]

## Untested boundaries
[Personas, routes, data states, mutations, viewports, browsers, accessibility, integrations, or regression history not covered.]

## Side effects and cleanup
[State explicitly whether data changed. List authorized changes and cleanup status, or say “No mutations performed.”]

## Recommended next action
[Fix and retest a blocker, track a residual, obtain a missing prerequisite, or hand the passing path to UAT.]

## Remediation delivery
[Include only in smoke-and-deliver mode: repository/worktree, exact feature branch,
files changed, dev org and deployment result, applicable Apex tests and coverage,
post-fix smoke result, commit SHA, push result, and anything left uncommitted.]
```

Do not omit the environment, persona, mutation statement, untested boundaries, or data-change statement. Do not include tokens, passwords, or unnecessary personal data in evidence.

## Chaining

- Run after `pre-deploy-checklist` when a release or environment is reachable, or run it against a supplied live build as a focused sanity check.
- In smoke-only mode, send blockers and residuals to the implementation/release owner with the recorded path and evidence. In smoke-and-deliver mode, follow [references/remediation-delivery.md](references/remediation-delivery.md) and carry the in-scope defect through repair, dev deployment, applicable tests, post-fix smoke, commit, and push.
- Feed a passing, repeatable path to `uat-script-drafter` when a stakeholder needs a click-by-click script. The smoke tester executes the path; it does not author the stakeholder's test plan.
- Use `acceptance-criteria-auditor` for whether a branch satisfies its ticket, `sf-code-reviewer` for code correctness, and a dedicated accessibility or regression audit for broad coverage. Those are different questions from “does this reachable UI path work right now?”
