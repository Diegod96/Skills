---
name: apex-architecture
description: Apply the team's mandatory Controller → Service → Domain → Selector layering standard when writing, reviewing, or specifying Apex and LWC. Covers which layer each piece of logic belongs in, the required class templates, bulk-safe method signatures, sharing and security declarations, trigger routing, and per-layer test structure. Use this before writing any Apex class, trigger, or LWC controller, when reviewing code for architecture compliance, when deciding where a new piece of logic goes, when someone asks "which layer does this belong in", "is this compliant", "where should this code live", or when refactoring legacy code toward the standard. Use it proactively on any task that produces Apex.
---

# Apex Architecture Standard

The team's mandatory layering for all new Apex development. Source: *Enterprise Pattern Standards (Controller → Service → Domain → Selector)*, Ponmozhi Thirunathan, last modified 30 July 2026.

**Core principle: every piece of logic belongs to exactly one layer.**

```
LWC / Flow / Experience Cloud
            │
            ▼
       Controller
            │
            ▼
        Service
         /     \
        ▼       ▼
    Domain    Selector
```

Read `references/layer-templates.md` for copy-ready class templates before writing any class.

## Where does this logic go?

The fastest way to place a piece of logic is to ask which question it answers.

| The code answers... | Layer | Example |
|---|---|---|
| "Who is asking, and in what shape?" | **Controller** | Unpack an LWC request, serialize a response, catch and translate exceptions |
| "What needs to happen?" | **Service** | Approve an application, match a mentor, send a notification, call Zoom |
| "Is this action allowed?" | **Domain** | Only submitted applications can be approved; a mentor at capacity cannot take another mentee |
| "What data do I need?" | **Selector** | Get application by Id, get mentors by program, get upcoming appointments |

When logic seems to fit two layers, it is usually one process (Service) wrapping one rule (Domain). Split it rather than picking.

### Service vs. Domain, the common confusion

Services **orchestrate** and own the transaction. Domains **decide** and own the rules.

- Approve application *process* → Service
- Application eligibility *rules* → Domain
- Create appointment, send email, call an external API → Service
- Appointment validation, status transition rules, trigger logic → Domain

A useful test: if the logic mentions more than one object, it is probably a Service. If it would still be true with no database involved, it is probably a Domain rule.

## The rules

1. **Controllers must be thin.** Receive, delegate, return.
2. **No SOQL outside Selectors.**
3. **No business rules outside Domains.**
4. **Services orchestrate. Domains validate and decide.**
5. **Triggers contain no business logic.** Triggers invoke Domains only.
6. **No direct status transitions outside Domains.** `app.Status__c = 'Approved';` is a violation; `ApplicationDomain.getInstance().approve(app);` is correct.
7. **Selectors are reusable and object-focused.** No process-specific query classes.
8. **One class, one responsibility.** A class that queries, validates, orchestrates, and updates must be refactored.
9. **Prefer instance methods** in Domain, Service, and Selector classes, so they can be mocked and extended. Static is correct for controller entry points (`@AuraEnabled`, REST, `@InvocableMethod`), stateless utilities, and the singleton accessor itself.
10. **One Selector per object.** Add methods to the existing Selector rather than creating a second one.
11. **Standard documentation header** on every class, interface, trigger, and enum: author, created date, last modified date, description, related objects.
12. **Bulk-safe signatures.** Any method reachable from a trigger takes a collection. Selectors return maps or lists. Single-record convenience methods delegate to the bulk method.
13. **Declare sharing explicitly** on every class. `without sharing` requires justification and design-review approval.
14. **One trigger per object**, containing context routing only.
15. **Singletons expose a `@TestVisible` injection point** so dependencies can be replaced in tests. Mocking uses the Apex Stub API, not a third-party framework.
16. **No hardcoded IDs, endpoints, or credentials.**
17. **The outermost Service owns the transaction.** Inner Services return unsaved records via `prepare`-prefixed methods.

## Layer boundaries

### Controller
**Allowed:** parameter handling, request validation, data transformation, exception handling, service invocation.
**Not allowed:** SOQL, DML, business rules, record updates, trigger logic, complex processing.

Entry-point methods **must** be `static` — `@AuraEnabled`, `@RestResource`, and `@InvocableMethod` methods do not compile otherwise. This is the documented exception to Rule 9. The static method's only job is to obtain the service instance and delegate.

### Service
**Allowed:** calling Selectors and Domains, DML, transaction orchestration, email, Platform Events, integration orchestration.
**Not allowed:** SOQL, object-specific validation rules, trigger logic.

The Service owns the DML boundary. Domains mutate records in memory; the Service persists them.

**The outermost Service in a call chain performs all DML** (Rule 17). Inner Services return unsaved records through `prepare`-prefixed methods rather than performing their own. `approveApplications()` persists; `prepareApprovalNotices()` returns records for the caller to persist. This keeps one commit per transaction and makes partial-failure behavior predictable. No Unit of Work framework — the naming convention carries the boundary.

### Domain
**Allowed:** business validations, status transition rules, object behavior, trigger processing, record-level logic.
**Not allowed:** UI logic, SOQL, DML, multi-object orchestration.

### Selector
**Allowed:** SOQL, query optimization, security enforcement, reusable query methods.
**Not allowed:** DML, business rules, record manipulation, process orchestration.

## Bulk-safe signatures (Rule 12)

**Production signatures must be bulk-safe**, because triggers process up to 200 records per transaction and integrations load thousands. A layered architecture does not protect against a SOQL query inside a loop; it just moves the query into a Selector that gets called inside the loop, where a reviewer reads it as a cheap method call rather than a query.

Rules of thumb:

- **Selectors** take collections and return collections or maps: `selectByIds(Set<Id> ids)` returning `Map<Id, Application__c>`. Provide a single-record convenience method only where a genuinely single-record entry point exists, and implement it by calling the bulk method.
- **Domains** take `List<SObject>` for anything reachable from a trigger. A `approve(Application__c app)` that a trigger path can reach is a defect.
- **Services** query once up front, pass collections down, and perform one DML at the end.
- **Never call a Selector or perform DML inside a loop**, including a loop in a caller several frames up. Layering makes this easier to miss, not harder, because the query is out of sight.

See `references/layer-templates.md` for bulk-shaped templates.

## Sharing and security

Declare sharing explicitly on every class. An undeclared class inherits in ways that surprise people.

- **Controllers**: `with sharing` by default.
- **Services**: `with sharing` by default.
- **Selectors**: `with sharing`, and enforce field-level security in queries using `WITH USER_MODE` (or `Security.stripInaccessible()` where the query feeds a response to a user). The Selector is the natural and correct place for this, since it is the only layer touching SOQL.
- **Domains**: `inherited sharing`, so they run in the caller's context.
- Any `without sharing` class requires a comment explaining why and is a design-review item.

Selector queries default to `WITH USER_MODE`. **System-context queries get separately named methods with a justifying comment, never a `without sharing` on the class** — applying `WITH USER_MODE` blindly to Selector methods called from triggers produces failures that depend on who saved the record, and disabling enforcement class-wide to fix one method is worse than the problem.

## LWC

The same separation applies on the client, and the Apex controller is the boundary between them.

- **Component** — template plus a JavaScript class handling rendering, user events, and local state. No business rules.
- **Service module** — a plain JS module (`service/mentorshipService.js`) wrapping imperative Apex calls and shaping the response. Components import it rather than importing Apex directly, so the wire and imperative plumbing lives in one place and is mockable in Jest.
- **Apex controller** — thin, static, delegating to the Apex Service layer.

Practical rules:

- Never put a business rule in a component. If the component decides whether an application is eligible, that rule now exists in two places and will diverge.
- Prefer `@wire` for reads, imperative Apex for writes.
- Every imperative call needs error handling that surfaces something usable to the user.
- Components reachable from Experience Cloud must behave sensibly for community and guest users, who have a very different permission profile.

## Tests by layer

Layering exists partly so each layer can be tested in isolation. Structure tests to take advantage of it.

- **Selector tests** — real DML in `@testSetup`, assert the query returns the right records and respects sharing. Include a `System.runAs()` case with a low-privilege user.
- **Domain tests** — pure, fast, no DML needed for most rules. Construct records in memory, call the rule, assert the outcome or the thrown exception. These should be the largest and quickest part of the suite.
- **Service tests** — mock the Selector and Domain using the Apex Stub API so the test exercises orchestration rather than re-testing rules. Instance methods (Rule 9) are what make this possible; a static service cannot be stubbed.
- **Controller tests** — assert delegation and exception translation, not business behavior.
- **Bulk tests** — every trigger path needs a 200-record test. A layered codebase with only single-record tests has the same production failure profile as an unlayered one.

## Legacy code

Most orgs contain code predating the standard. Do not rewrite it opportunistically.

- **New classes** follow the standard fully.
- **Modified legacy classes** follow it for the new logic. Extract the touched logic into the right layer if that is a contained change; leave the rest.
- **Wholesale refactors** are their own ticket with their own risk assessment, not a rider on a feature branch. A refactor bundled into a feature MR makes both unreviewable.
- When a legacy class blocks compliance, note it in the MR as a follow-up rather than silently working around it.

## Documented exceptions

The standard is the default "unless an approved exception is documented during design review." When a deviation looks necessary, do not just do it: state what the standard requires, why this case does not fit, and what the alternative is, and route it to design review. Silent deviations are what turn a standard into a suggestion.

## Compliance checklist

A solution is compliant when:

- Controllers contain no business logic and no SOQL
- Services contain no SOQL and no object-specific rules
- Domains contain all business rules and no SOQL or DML
- Selectors contain all SOQL and no DML
- Triggers contain no logic and route to a Domain
- One Selector exists per object
- Domain, Service, and Selector methods are instance methods with static singleton accessors
- Every class has the standard documentation header
- Sharing is declared explicitly on every class
- Signatures reachable from a trigger are bulk-safe
- Each layer can be tested independently
