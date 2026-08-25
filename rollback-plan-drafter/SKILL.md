---
name: rollback-plan-drafter
description: Draft a rollback plan for a Salesforce deployment — what to revert, in what order, what data damage needs repairing, what can't be undone, and what the decision criteria are for pulling the trigger. Use this whenever someone asks "what's our rollback plan", "how do we undo this", "what if this goes wrong", "can we revert the deployment", before a risky or large release, or when a deployment has already gone bad and needs a recovery plan now. Use it proactively for any release touching automation on high-volume objects, data model changes, or integrations.
---

# Rollback Plan Drafter

This skill produces a rollback plan for a Salesforce deployment.

The framing that matters most: **Salesforce deployments are not transactional and rollback is not symmetric with deployment.** Reverting metadata does not revert data. If a flow ran for three hours and wrote to 40,000 records, removing the flow stops future damage and repairs nothing. Most of the real work in a rollback is data repair, and most rollback plans ignore it entirely.

So the first job of this skill is to be honest about what can and cannot be undone.

## Org context

Fill this in:

- **Source control**: GitLab, branch-per-feature, release branch: [name]
- **Deployment**: Gearset — [note whether rollback packages are generated as part of the deployment]
- **Backup**: [tool and frequency — e.g. Gearset backups nightly, or third-party. **Rollback plans depend entirely on this; if there's no backup, say so loudly.**]
- **Environments**: [path to production]
- **Escalation**: [who decides to roll back, who executes, who to notify]
- **Deployment window**: [when, and how long the team stays available afterward]

## Classify what's being deployed

Rollback difficulty varies enormously by change type. Sort each item:

| Class | Examples | Rollback |
|---|---|---|
| **Cleanly reversible** | Apex classes, LWC, layouts, validation rules, most flows | Redeploy previous version |
| **Reversible with care** | Permission sets, sharing rules, page assignments | Reversible, but interim state may expose or block access |
| **Reversible, data damage persists** | Record-triggered flows, batch jobs, triggers | Metadata reverts; the records it wrote stay written |
| **Hard to reverse** | New required fields, picklist value removal, field type changes | May require data work and may fail while data violates the old state |
| **Effectively irreversible** | Field/object deletion, mass deletes, external system writes, sent emails | Recoverable only from backup, or not at all |

Anything in the bottom two rows deserves explicit callout in the plan and, ideally, a rethink of the deployment sequence before it ships.

## Data damage assessment

For each piece of automation in the release, work out:

- **What records could it have written to?** Which objects, and roughly how many, per hour of exposure.
- **Is the change detectable?** Is there a field, timestamp, or LastModifiedBy that identifies records the new automation touched? **If there's no way to identify affected records after the fact, that is the single most important finding in the plan** — it means repair requires a backup restore rather than a targeted fix.
- **Is the original value recoverable?** From field history tracking, from a backup, from an external system of record, or not at all.
- **Did anything leave the org?** Emails sent, outbound callouts, platform events published, integration syncs fired. These can't be recalled, and downstream systems may need their own correction.

Where the answer is "we couldn't tell which records were affected," recommend adding a marker field or a timestamp *before* deploying, not after. It's a five-minute change that turns an irreversible situation into a recoverable one.

## Decision criteria

A rollback plan without trigger conditions gets debated in the moment, badly, under pressure. Define in advance:

- **Roll back immediately if:** [data corruption spreading, integration failures, users blocked from core work]
- **Roll back if not resolved in [N] hours:** [degraded but not spreading]
- **Fix forward instead if:** [isolated, low-volume, and a patch is faster than a revert]
- **Who decides:** [named role]

Fix-forward is often the right call and is under-considered. Reverting a package can be riskier than a small targeted patch, especially for partial failures. The plan should say when to prefer it.

## The most important first step

Almost always: **deactivate the automation before reverting anything.** Deactivating a flow or process takes seconds and stops the bleeding; a metadata rollback takes minutes to validate and deploy. Stop the writes first, then fix the metadata, then repair the data. Plans that lead with "redeploy the previous package" have the order wrong.

## Output format

```markdown
# Rollback Plan: [release name]

**Overall reversibility:** [Clean / Partial / Limited]
**Irreversible elements:** [count — list them here if any]
**Estimated rollback time:** [range, and what drives it]

## Decision criteria
| Condition | Action | Decider |
|---|---|---|

## Immediate stabilization
[The first 5 minutes. Usually: deactivate specific flows/jobs by name, disable a
specific integration user, or pause a scheduled job. Name the exact items and where
to find them.]

1. ...

## Metadata rollback
[Ordered steps. Note dependencies — some things must revert before others, and
reverse dependency order is not always simply the reverse of deployment order.]

1. ...

## Data repair
| Affected data | How to identify | Repair method | Recoverable? |
|---|---|---|---|

[If records can't be identified, say so here explicitly and state what the fallback is.]

## Cannot be undone
[Emails sent, callouts made, events published, external records created. For each:
what downstream cleanup is possible, and who owns it.]

## Verification
[How to confirm the rollback actually worked — specific checks, not "verify system
is functioning."]

## Communication
[Who to notify, in what order, with what message. Include integration owners —
they often find out last and are affected first.]

## Preventive notes for next time
[What would have made this rollback easier. Feed these back into the deployment
process rather than rediscovering them next month.]
```

## Notes

Write the plan so someone who didn't build the feature can execute it at 9 p.m. That means naming specific flows, specific record sets, and specific navigation paths rather than describing them in general terms.

Be direct about gaps. If there's no backup covering an affected object, if affected records can't be identified, or if a change is genuinely one-way — say it plainly and near the top. The value of this document comes largely from surfacing those facts *before* the deployment, when there's still time to add a safety net.

If this skill is being used during an active incident rather than as preparation, lead with immediate stabilization and skip the preamble entirely. Get to the specific steps.
