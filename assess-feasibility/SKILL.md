---
name: assess-feasibility
description: Triage a raw, unapproved Salesforce request — a new feature, a business process change, a "can we just..." ask from a stakeholder — into a fast go/no-go read with a rough effort estimate, risk flags, and what would need to change. Use this whenever someone brings an unscoped request, asks "how hard would it be to...", "is this possible in Salesforce", "can we make it so that...", "what would it take to...", or forwards a stakeholder email or Slack message asking for something new. Use it even when the request sounds small — small-sounding requests that touch shared automation are exactly the ones that blow up estimates. Do NOT use this for work that is already approved and scoped; use ticket-to-spec instead.
---

# Assess Feasibility

This skill produces a **fast, rough-cut read** on whether a Salesforce request is worth taking on and roughly how big it is. The audience is a team lead or a stakeholder deciding whether to greenlight work — not a developer about to build it.

The most important thing to get right is calibration. An estimate that is confidently wrong is worse than one that honestly says "this depends on something I can't see from here." Say what you don't know.

## Org context

Fill this in for your org — it drives most of the risk flags:

- **Platform**: Salesforce (HEDA data model, Experience Cloud, Coveo search)
- **Source control**: GitLab, branch-per-feature
- **Deployment**: Gearset, monthly release cadence
- **Tracking**: JIRA
- **Known-fragile areas**: [list the automation nobody wants to touch — e.g. Area Assignment criteria, POP record flows, anything with a history of recursion]
- **Integrations**: [list outbound/inbound systems — data warehouse, marketing platform, event system, etc.]

The monthly cadence matters for estimates: anything that misses a release window slips a full month, so "two days of work" and "two days of work that has to land next Tuesday" are different answers.

## Process

1. **Restate the request in your own words.** Requests arrive vague. Write down what you think is being asked, then flag the gaps. If the restatement changes the answer materially, say so.
2. **Identify the change type.** Config-only? Declarative automation? Apex? UI/Experience Cloud? Data model change? Integration? Each has a very different effort profile, and requests often turn out to be a different type than they first sound.
3. **Trace obvious dependencies** — what objects, flows, and integrations does this plausibly touch? This is a gut-check pass, not an exhaustive trace. If the surface area looks large, that's a signal to recommend a deeper impact map rather than to estimate harder.
4. **Check for the "innocent-looking landmine" patterns** (see below).
5. **Size it**, with explicit reasoning.
6. **Give a recommendation** — proceed, proceed-with-conditions, needs-more-scoping, or push back.

## Sizing scale

Use T-shirt sizes with a stated basis, not hour counts. Hour counts imply precision that doesn't exist at this stage.

| Size | Rough meaning | Typical shape |
|---|---|---|
| **S** | Under a day | Field add, layout change, report, simple validation rule |
| **M** | A few days | New flow, moderate Apex, a screen, a permission model change |
| **L** | 1–2 weeks | Multi-object automation, integration touchpoint, Experience Cloud work |
| **XL** | Multiple sprints, or spans releases | Data model change, new integration, anything touching known-fragile automation |
| **?** | Can't size yet | Say exactly what you'd need to know to size it |

`?` is a legitimate and often correct answer. Prefer it over a confident guess.

Note separately whether the work **fits the current release window** or slips to the next one.

## Landmine patterns

These are the things that turn an S into an XL. Check each explicitly:

- **Shared automation** — does this touch an object with existing flows/triggers from other teams or vintages? Order of execution problems are the single most common estimate-buster.
- **Recursion risk** — would this write to a field that appears in the entry criteria of any automation on the same object? Flag this hard; it's the pattern behind self-regenerating record loops.
- **Data migration** — does existing data need backfilling or cleanup? This is almost always underestimated and often exceeds the build itself.
- **Integration contracts** — does an external system read or write the fields in question? Changing a field an integration depends on is a cross-team coordination problem, not a Salesforce problem.
- **Permission surface** — will this need new permission sets, custom permissions, or sharing changes? Rollouts across many profiles are slow.
- **Licensing / platform limits** — does this need a feature the org doesn't have licensed, or push against a hard governor or storage limit?
- **Managed packages** — is the affected metadata inside a managed package (limited or no editability)?
- **"Just like X"** — when a stakeholder says "just like we did for X," verify that X actually works the way they think. It often doesn't.

## Output format

Use this structure:

```markdown
# Feasibility: [short request name]

**Verdict:** [Proceed / Proceed with conditions / Needs scoping / Recommend against]
**Size:** [S/M/L/XL/?] — [one line on what drives it]
**Release fit:** [Fits current window / Slips to next / Multi-release]

## What's being asked
[Restated in plain terms. Note any assumptions made to fill gaps.]

## What would need to change
[Bulleted: objects, fields, automation, UI, permissions, integrations.]

## Risks and unknowns
[Landmine patterns that apply. Be specific about *why* each is a risk here.]

## Open questions
[What needs answering before this can be sized more precisely or built.]

## Recommendation
[2–4 sentences. If recommending against, offer the cheaper alternative that
gets the stakeholder most of what they want.]
```

## Calibration notes

Requests are usually described in terms of the *outcome* the stakeholder wants, not the mechanism. Push on the outcome — a request framed as "add a field" is often really "we need to report on X," and there may be a cheaper path to X.

When you genuinely can't tell whether something is M or XL because of what's hidden in existing automation, say that plainly and recommend a change-impact-mapper pass before committing. Bounding the uncertainty is more useful than splitting the difference.

Be willing to recommend against. A well-reasoned "this costs more than it's worth, and here's a 10% solution that gets you 80% of the value" is one of the more valuable outputs this skill can produce.
