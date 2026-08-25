# Integrating with pstack (`unslop` and `interrogate`)

These two Cursor skills sit at different layers than the Salesforce ten, so they compose rather than overlap. `unslop` is a writing-quality filter that applies to whatever prose a skill produces. `interrogate` is a review engine that applies to whatever diff a skill produces.

## Where each one attaches

```
assess-feasibility ──┐
ticket-to-spec ──────┼──→ prose output ──→ unslop
change-impact-mapper ┤
release-notes-gen ───┤
rollback-plan ───────┘

implement ──→ branch + diff ──→ interrogate ──→ verdict ──→ human
                    ↑
        sf-code-reviewer (fast single pass)
```

## unslop

**What it's for here:** every intake and ship skill produces a document a human reads. `release-notes-generator` is the highest-value attachment point, since release notes are the most-read and least-technical thing the team publishes. The MR description in `implement` is second.

**What's already wired:** `release-notes-generator` has a "Voice" section naming the five patterns that matter most for release notes, and `implement` Phase 9 applies unslop to the prose sections of the MR description.

**Where it should not apply.** unslop's rules are written for narrative prose, and several of them fight with structured technical output:

| unslop rule | Conflict |
|---|---|
| Rule of three | Checklists have the number of items they have |
| Boldface overuse | Severity labels (**Blocking** / **Should fix**) are scannable structure, not decoration |
| Inline-header lists | The skill templates use bold-label rows deliberately — though unslop's own carve-out covers this when the label is followed by genuinely new detail |
| Have opinions / use "I" | Fits an engineering blog; fits an institutional release note poorly |
| Let some mess in | Directly opposed to a spec template that exists to be uniform |

The rule of thumb: **unslop applies to sentences, not to tables, checklists, command output, or metadata inventories.** Both wired-in sections say this explicitly.

**The one live conflict.** unslop is declared `Must always apply` and bans em dashes entirely. Every one of the ten Salesforce SKILL.md files uses em dashes heavily. Three ways to resolve it:

1. **Leave it.** SKILL.md files are instructions to a model, not prose a human reads for pleasure. unslop's target is output, not instructions. This is the lowest-effort answer and probably the right one.
2. **De-dash the skill files.** Consistent, but the em dashes in these files mostly separate a claim from its consequence, which is the construction that most needs the separation. Expect some readability loss.
3. **De-dash only the output templates** inside each skill, leaving the instructional prose alone. Splits the difference; the generated documents come out unslopped by construction.

Worth deciding deliberately rather than discovering it the first time unslop rewrites a spec template.

## interrogate

**What it's for here:** `implement` produces exactly what interrogate consumes — a feature branch with a diff against `main`. And the handoff solves a real gap: `implement` deliberately does not review its own output, because self-review by the same model that wrote the code is weak. Interrogate's whole premise is that the adversarial signal comes from model diversity, which is precisely the thing a self-review lacks.

**What's already wired:** `implement` Phase 8 is an optional interrogate gate before the MR opens, and `sf-code-reviewer` has a section framing the two as tiers rather than alternatives.

**The important artifact: `interrogate-salesforce-lens.md`.** Interrogate hands every reviewer the same rubric and code-quality lens. Generic lenses miss Salesforce's failure modes entirely, because bulkification bugs, governor limit violations, and missing FLS packaging all look like correct code in any other language. Drop the lens file into `interrogate/references/` and add it to the list filled into the reviewer prompt in Step 3, alongside `rubric.md` and `code-quality-review.md`. Without it you get four models doing a competent generic review of code whose real risks are all platform-specific.

**Two boundary rules, both wired into Phase 8:**

- Interrogate says not to auto-apply changes. `implement` has a 3-attempt auto-fix loop. These are compatible only if the boundary holds: **the auto-fix loop is for failures, not for review opinions.** A failing test is a fact; a review finding is a judgment that belongs to a human.
- Interrogate asks for the intent before spawning reviewers, and reviewers challenge whether the work achieves that intent, not whether the intent is right. `implement` should pass the *spec's* summary, not a description of what it built — otherwise the reviewers grade the implementation against itself and find nothing.

**One caveat worth knowing up front:** interrogate needs the Task tool, subagents, and resolvable model slugs. It runs in Cursor, not in claude.ai. The `implement` skill is written to offer it and continue without it, so nothing breaks if it isn't there.

## Ordering

Within a full run, the sequence is:

1. `implement` builds, tests, validates
2. `sf-code-reviewer` — fast single pass, always
3. `interrogate` — multi-model pass, when the change warrants it
4. Human decides on the findings
5. `implement` Phase 9 opens the MR, with `unslop` on the description prose
6. `release-notes-generator` at release time, with `unslop` on the stakeholder section

Steps 2 and 3 are both advisory. Nothing between them modifies the branch without a human saying so.
