---
name: permission-fls-auditor
description: Audit the access model for a new or changed Salesforce field, object, component, or feature — field-level security, object CRUD, permission sets, custom permissions, sharing rules, layout and component visibility filters, and Experience Cloud guest/community access — so a feature doesn't ship visible only to sysadmins or exposed to everyone. Use this whenever someone asks "who can see this", "why can't users see the field", "did we set up permissions", "is this exposed to the community", before shipping any new field or component, or when a component visibility filter or custom permission is involved. Use it proactively on any change adding fields, custom permissions, or Experience Cloud components.
---

# Permission & FLS Auditor

This skill checks the access model for a Salesforce change. It exists because permissions are the most common thing to ship broken: the developer builds as an admin, everything works, and the feature reaches production invisible to the people who requested it — or, worse, visible to people who shouldn't have it.

Both failure directions matter, and they're not symmetric. Too-restrictive is embarrassing and gets fixed in a day. Too-permissive is a data exposure that may go unnoticed for months. **Weight the over-exposure check more heavily.**

## Org context

Fill this in:

- **Platform**: Salesforce (HEDA data model, Experience Cloud)
- **Permission strategy**: [permission-set-led, profile-led, or mixed — this changes where to look]
- **Key profiles**: [e.g. staff, admin, read-only, integration user]
- **Key permission sets / groups**: [list them]
- **Custom permissions in use**: [e.g. Gift_Planning — note what each gates]
- **Experience Cloud sites**: [names, and whether guest access is enabled on each]
- **Integration users**: [these need explicit access too and are constantly forgotten]

## The access chain

Access in Salesforce is a chain, and it fails at the weakest link. Check every layer — a field can be perfectly configured at four levels and still be invisible because of the fifth.

1. **Object permissions (CRUD)** — does the user's profile or permission set grant Read/Create/Edit/Delete on the object?
2. **Field-level security** — is the field visible (and writable if needed) for each relevant profile and permission set? Read-only at FLS overrides an editable layout.
3. **Record access (sharing)** — org-wide defaults, role hierarchy, sharing rules, manual shares, Apex sharing. Granting FLS on a field doesn't help if the user can't see the record.
4. **Layout / Lightning page assignment** — is the field on the layout assigned to that profile+record type combination? A field with perfect FLS that isn't on the layout is still invisible.
5. **Component visibility filters** — Lightning page components can be filtered on custom permissions, user fields, record fields, or device. This layer is easy to get wrong because the logic is invisible from the record page itself.
6. **Code-level enforcement** — `with sharing`, `WITH USER_MODE`, `stripInaccessible()`. Apex running `without sharing` bypasses layers 3 and 2 entirely.

Walk all six for each user persona. A finding at layer 4 while layers 1–3 are fine is exactly the "we set up the permissions and it still doesn't show" case.

## Personas to check

For every change, evaluate against each persona that exists in the org — don't just check the intended audience:

- The **intended user** — can they do the thing?
- An **adjacent internal user** who shouldn't have it — are they correctly excluded?
- A **read-only or reporting user** — do they see the field in reports even if not on the layout? (Report access follows FLS, not layouts.)
- The **integration user** — API access is granted through the same FLS/CRUD chain, and integrations fail silently or partially when it's missing.
- **Experience Cloud community users** — a much lower baseline of access, and different license limits.
- **Guest users** — if any site has guest access, check explicitly. Guest user access is the highest-consequence layer and the most frequently overlooked. Guest sharing rules and the "secure guest user record access" setting matter here.

## Custom permission checks

Custom permissions are a good pattern and a common source of subtle bugs:

- Is the custom permission actually assigned to a permission set, and is that permission set assigned to anyone? An unassigned custom permission silently evaluates false for everyone.
- Where is it referenced — component visibility, validation rules, formula fields, Apex (`FeatureManagement.checkPermission()`), flow decisions? Enumerate all of them; a permission whose meaning drifts across several call sites is a maintenance problem.
- Is the visibility logic using the right boolean sense? Filters expressing "show unless" versus "show when" are easy to invert, and inverted logic on a filter that gates sensitive data fails toward exposure.
- When a filter combines a custom permission with a profile check, confirm the AND/OR semantics — Lightning component visibility filters combine multiple conditions in ways people frequently misread.

## Common failure patterns

- Field created, FLS never set → visible only to System Administrator.
- Permission set updated in sandbox, not included in the deployment package → works in sandbox, invisible in production. **Check that permission set changes are actually in the branch.**
- New required field with no FLS for the integration user → integration writes start failing.
- Field added to a layout but not the layout assigned to the relevant record type.
- Component visibility filter referencing a custom permission that's assigned to nobody.
- Sensitive field exposed in a report type or list view even though it's off the layout.
- Guest user inherits access through a sharing rule written for a broader audience.
- `without sharing` Apex used to solve a sharing problem, quietly bypassing record access for all callers.

## Output format

```markdown
# Permission Audit: [feature or field name]

**Verdict:** [Ready / Gaps found / Exposure risk]
**Over-exposure findings:** [count] · **Access gaps:** [count]

## Access matrix

| Persona | Object | FLS | Record access | Layout | Component | Net result |
|---|---|---|---|---|---|---|
| Intended user | ✓ | ✓ | ✓ | ✓ | ✓ | Can use |
| ... | | | | | | |

## Exposure risks
[Anyone who can see this and shouldn't. Lead with these. For each: who, via which
layer, and what they'd be able to see or do.]

## Access gaps
[Anyone who should have it and doesn't. For each: which layer in the chain is the
blocker and the specific fix.]

## Deployment checklist
[What metadata must be in the branch for this to work in production — permission
sets, FLS on the field, layout assignments. This is where sandbox/production drift
gets caught.]

## Not verifiable from here
[Anything requiring org inspection rather than metadata review — actual permission
set assignments, current sharing rule state, guest user configuration.]
```

## Notes

FLS is not stored on the field — it lives in profiles and permission sets. A branch that adds a field but no permission set changes has, by definition, shipped it invisible to everyone but admins. That single check catches a large share of real-world cases.

When something can't be determined from metadata alone (whether a permission set is actually assigned to real users, for instance), say so rather than assuming. Assumed permission state is how over-exposure findings get missed.
