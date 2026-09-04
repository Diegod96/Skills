---
name: ponytail
description: Simplify implementation and code review by reusing existing code, standard libraries, and native platform features before adding custom code or dependencies. Use for coding tasks involving unnecessary complexity, boilerplate, dependency choices, or requests for Ponytail, YAGNI, or the simplest working solution.
license: MIT
---

# Ponytail

Choose the smallest maintainable change that fully meets the user's request.
Read the affected code and trace the relevant callers and data flow before
choosing a solution. For bugs, identify the root cause and check whether a
shared fix would affect callers with different contracts.

## Choose a solution

Consider these options in order, stopping when one meets all requirements:

1. Remove speculative work that the task does not need. Keep explicit requirements.
2. Reuse an existing helper, component, type, or established pattern.
3. Use the standard library.
4. Use a native platform feature that provides the required behavior.
5. Use an already installed dependency.
6. Write the minimum readable custom code. A one-liner is useful only when it
   remains clear and correct; line count is not the acceptance criterion.

Add a dependency or abstraction when it solves a demonstrated requirement
more maintainably than the available alternatives. Avoid scaffolding for
hypothetical future needs. Keep adjacent cleanup outside the requested change.
If a simpler alternative changes required behavior, explain the tradeoff and
get the user's decision before substituting it.

## Apply within the development workflow

For Salesforce work, preserve the team's Controller → Service → Domain →
Selector architecture. Reuse methods in the appropriate layer; do not collapse
layers or remove mandated patterns just to shrink the diff. Consult
`apex-architecture` when available for the team's exact templates.

Consider standard Lightning components, platform APIs, and declarative
features when they meet the required behavior and fit existing automation.
Check transaction behavior, bulk execution, permissions, and downstream effects
before replacing custom logic with a platform feature. Declarative does not
automatically mean simpler or safer.

Preserve CRUD/FLS and sharing enforcement, bulkification, governor-limit
protections, validation at trust boundaries, accessibility, and error handling
that prevents data loss. Include permission and dependent metadata required
for the feature to work for its intended users.

Use the repository's existing test tools and required validation gates.
Choose focused checks that can expose the changed behavior or regression;
there is no one-test cap. Do not replace Apex tests, required coverage,
integration checks, or requested UAT with a demonstration script.

In a review, report actionable simplifications with evidence and distinguish
optional cleanup from correctness issues. Review authorization does not permit
editing or deleting code. Implementation and release actions remain governed
by the task's scope and existing authorization.

## Invocation and output

Use this guidance alongside implementation or review for the relevant coding
task. Do not impose a persona or carry it into unrelated requests. If the user
asks for `lite`, suggest alternatives while preserving their chosen design;
`full` is the default workflow above; `ultra` examines unnecessary additions
more aggressively but still preserves every requirement and validation gate.
Honor a request to stop using Ponytail.

Report what changed, why the simpler approach satisfies the requirements,
what was verified, and any material limitations. Match the detail the user
requested; do not impose a code-first format or a fixed explanation limit.

## Source

Adapted from [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail),
`skills/ponytail/SKILL.md` at commit
`974d940a1c5344210874150b98ff0d2c861fab6a` (retrieved 2026-09-04).
The upstream MIT notice is retained in [LICENSE](LICENSE).
This team adaptation scopes activation to the task, preserves requested
behavior and Salesforce architecture, and uses existing testing requirements.
It does not require upstream lifecycle hooks, an MCP server, or a Node runtime.
