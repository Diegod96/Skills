---
name: change-impact-mapper
description: Trace the full blast radius of a proposed or in-progress Salesforce change — what other flows, triggers, Apex classes, validation rules, permission sets, layouts, reports, integrations, and Experience Cloud components will be affected if a given field, object, or automation is modified or removed. Use this whenever someone asks "what else does this touch", "what breaks if I change X", "is this field safe to delete", "what depends on this flow", before deprecating or renaming metadata, when reviewing a spec for hidden dependencies, or when a change touches an object with automation from multiple teams or eras. Use it proactively on any change to shared or high-traffic objects even when nobody asked.
---

# Change Impact Mapper

This skill traces dependencies for a Salesforce change. Where `assess-feasibility` gives a fast gut-check, this aims to be **close to exhaustive** — the point is to find the dependency nobody remembered.

The output is only as good as its honesty about coverage. Salesforce dependency tracing has real blind spots (dynamic SOQL, hardcoded IDs in unexpected places, external systems nobody documented). Always state what was searched and what could not be. A map that claims completeness it doesn't have is actively dangerous, because it stops people from looking further.

## Org context

Fill this in:

- **Platform**: Salesforce (HEDA data model, Experience Cloud, Coveo search)
- **Metadata source**: [GitLab repo path, or "retrieve from org via SFDX/Gearset"]
- **Known-fragile automation**: [the flows and triggers with a history of surprises]
- **Outbound integrations**: [systems that read Salesforce data, and via what — API, ETL, reports]
- **Inbound integrations**: [systems that write into Salesforce]
- **Managed packages installed**: [these have metadata you can't edit and may reference your fields]

## What to trace

Work through each category. For each, note whether it was checked and how.

### Automation
- Record-triggered, schedule-triggered, and platform-event flows on the affected object
- Screen flows that reference the field or object
- Subflows invoked by any of the above
- Apex triggers, and any handler classes they delegate to
- Process Builder and Workflow Rules (legacy, often forgotten, still running)
- Approval processes and their entry criteria and field updates
- Assignment, escalation, and auto-response rules
- Duplicate and matching rules

### Code
- Apex classes referencing the field or object, including SOQL field lists
- Dynamic SOQL and dynamic field access — **string-based references won't show in standard dependency views**, so grep the codebase for the API name as a literal string
- Test classes that construct the affected records (these break loudly and are easy to miss in estimates)
- LWC and Aura components, including `@wire` adapters and imported schema references
- Visualforce pages and controllers
- Custom metadata and custom settings that store field API names as values

### Declarative config
- Validation rules on the object and on related objects
- Formula fields, roll-up summaries, and cross-object formulas that reference it
- Page layouts, compact layouts, and Lightning record pages — including component visibility filters
- Dynamic forms and field-level conditional visibility
- List views with filters on the field
- Path, Kanban, and highlights-panel configurations

### Access
- Profiles and permission sets granting object or field access
- Custom permissions used in visibility or validation logic
- Sharing rules and criteria-based sharing referencing the field
- Restriction rules and scoping rules

### Downstream consumption
- Reports and report types including the field
- Dashboards built on those reports
- Einstein/CRM Analytics datasets and recipes
- Experience Cloud pages, components, and audience targeting criteria
- Coveo (or other search) indexing configuration and result templates
- Email templates, letterheads, and merge fields
- Integration field mappings — outbound ETL jobs, marketing platform syncs, data warehouse extracts
- Scheduled jobs and Data Loader routines run by other teams

## Method

1. **Start with the platform's own answer.** Setup → Where is this used? and the dependency API give a real baseline, but they miss dynamic references and everything outside Salesforce. Treat this as the floor, not the ceiling.
2. **Grep the metadata repo** for the API name as a raw string. This catches dynamic SOQL, formula text, flow XML, and hardcoded references that dependency views miss.
3. **Check for label vs. API name divergence** — searches on the label miss code referencing the API name and vice versa. Search both.
4. **Trace one hop out.** Roll-up summaries, cross-object formulas, and master-detail relationships mean changes propagate to parent and child objects. Check those objects' automation too.
5. **Ask about the things you can't see.** External systems, other teams' scheduled jobs, and reports in private folders won't appear in any search. List them as explicit unknowns with a suggested owner to ask.

## Recursion and ordering analysis

When the change touches automation, run this specifically — it's the highest-value part of the map:

- **Self-triggering**: does any automation write to a field that appears in its own entry criteria? This produces records that regenerate themselves after deletion and is difficult to diagnose after the fact.
- **Mutual triggering**: does flow A update a field that triggers flow B, which updates a field that triggers flow A?
- **Order of execution**: when multiple record-triggered flows exist on the same object at the same trigger point, their relative order is not guaranteed unless explicitly set. Flag any change that adds a flow to an object that already has several.
- **Trigger + flow coexistence**: automation split across Apex triggers and flows on the same object is a frequent source of double-processing and field-value ping-pong.

## Output format

```markdown
# Impact Map: [what's changing]

**Change:** [precise description — e.g. "change Account.Region__c picklist values"]
**Blast radius:** [Contained / Moderate / Wide] — [one line]
**Highest-risk finding:** [the single thing most likely to break]

## Direct dependencies
[Things that reference the changed metadata directly.]

| Type | Name | How it's affected | Action needed |
|---|---|---|---|

## Indirect dependencies
[One hop out — parent/child objects, roll-ups, cross-object formulas.]

| Type | Name | Path | Action needed |
|---|---|---|---|

## Automation interaction analysis
[Recursion, ordering, and double-processing risk. If none found, say so explicitly
and note what was checked.]

## External and downstream
[Integrations, reports, dashboards, search indexes, Experience Cloud.]

## Coverage and blind spots
**Searched:** [what was actually checked and how]
**Not searchable from here:** [external systems, private reports, other teams' jobs —
with who to ask about each]

## Recommended sequence
[If the change requires ordering — deprecate then remove, backfill then switch,
coordinate with an external team first — lay it out as numbered steps.]
```

## A note on deletion requests

"Is this field safe to delete?" deserves extra care, because deletion is the one change that can't be quietly patched afterward. Even with a clean map, prefer recommending the safe sequence: stop writing to it, monitor for a full business cycle (including month-end and any quarterly processes), then remove. Point out that fields in reports and integration mappings fail at *runtime*, often silently, and often weeks later — which is exactly when nobody connects the failure to the deletion.
