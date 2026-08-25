# Enterprise Pattern Standards (Controller → Service → Domain → Selector)

**Original author:** Ponmozhi Thirunathan
**Original created:** June 24, 2026
**Original last modified:** July 30, 2026
**This revision:** August 20, 2026 — v2, decisions final
**Disclosure:** AI-assisted tools were used to help improve writing, organization, and formatting. The technical analysis, design decisions, validation, and final recommendations are the authors'.

---

## Revision summary

The layer model and boundaries from v1 are unchanged and correct. This revision fixes two code errors and closes gaps that allow non-compliant code to be written while technically following the document.

**Corrections**

| # | Change | Reason |
|---|---|---|
| C1 | Added `static` to all singleton accessors | v1 examples read `private  MentorshipService instance;` with the keyword stripped. As written, `getInstance()` requires an instance to obtain an instance. Rule 9 already names singleton accessors as an appropriate use of static. |
| C2 | Added `static` to the Controller "Good" example | v1's Good example was non-static while its Bad example was static, inverting the two. `@AuraEnabled` methods do not compile without `static`. |

**Additions**

| # | Change | Reason |
|---|---|---|
| A1 | Bulk-safe signatures throughout; new Rule 12 | v1 examples are single-record. A trigger routing into `approve(Application__c)` has nowhere to go but a loop. |
| A2 | Explicit sharing declarations per layer; new Rule 13 | v1 specifies none. Undeclared classes inherit unpredictably. |
| A3 | FLS enforcement mechanism in Selectors | v1 lists "security enforcement" as a Selector responsibility without naming how. |
| A4 | `BusinessException` defined; error-handling strategy by context | v1 uses it in three examples without defining it or saying where it is caught. |
| A5 | `@TestVisible` injection on singletons; new Rule 15 | Rule 9 exists so classes can be mocked, but a hardcoded singleton is itself an unmockable dependency. |
| A6 | New Rule 14: one trigger per object | v1 mandates one Selector per object with no trigger equivalent. Multiple triggers on one object execute in non-deterministic order. |
| A7 | New section 6: LWC standards | v1 covers the Apex controller as an entry point but not the client that calls it. |
| A8 | New section 9: testing standards per layer | v1's success criteria require independently testable layers without specifying how. |
| A9 | Unit of Work guidance for nested DML | Service-calls-Service produces multiple commits per transaction and an unclear partial-failure story. |
| A10 | New section 8: asynchronous processing | v1 does not say which layer owns Queueable, Batch, or Schedulable. |

All items above are decided and mandatory as of this revision. See `apex-standards-decisions.md` for the reasoning behind the four that were previously open, and the conditions that would justify revisiting each.

---

## Purpose

This document establishes the mandatory Apex and LWC architecture standards for all new development. The goal is a maintainable, scalable, testable, SOLID-compliant codebase.

---

## Core principle

Every piece of logic belongs to exactly one layer.

```text
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

The fastest way to place a piece of logic is to ask which question it answers.

| The code answers... | Layer |
|---|---|
| "Who is asking, and in what shape?" | Controller |
| "What needs to happen?" | Service |
| "Is this action allowed?" | Domain |
| "What data do I need?" | Selector |

When logic appears to fit two layers, it is usually one process (Service) wrapping one rule (Domain). Split it rather than choosing.

---

## 1. Controller layer

### Responsibility

Entry point into Apex from LWC, Aura, Experience Cloud, REST, and Flow. Controllers receive requests and delegate to the Service layer.

### Allowed
Parameter handling, request validation, data transformation, exception handling, Service invocation.

### Not allowed
SOQL, DML, business rules, record updates, trigger logic, complex processing.

### Standard

Entry-point methods **must** be `static`. `@AuraEnabled`, `@RestResource`, and `@InvocableMethod` methods do not compile otherwise. This is the documented exception to Rule 9: the static method's only job is to obtain the service instance and delegate.

Good:
```apex
/**
 * @author       Ponmozhi Thirunathan
 * @created      2026-06-24
 * @modified     2026-08-20
 * @description  Entry point for mentorship application actions from LWC.
 * @objects      Application__c
 */
public with sharing class MentorshipController {

    @AuraEnabled
    public static void approveApplications(List<Id> applicationIds) {
        try {
            MentorshipService.getInstance()
                .approveApplications(new Set<Id>(applicationIds));
        } catch (BusinessException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
```

Bad:
```apex
@AuraEnabled
public static void approveApplication(Id applicationId) {
    Application__c app = [
        SELECT Id, Status__c FROM Application__c WHERE Id = :applicationId
    ];
    app.Status__c = 'Approved';
    update app;
}
```

Note the collection parameter in the Good example. Even where the UI submits one record today, a collection signature costs nothing now and prevents a rewrite when a bulk action is added.

### SOLID alignment
**SRP** — Controllers are responsible only for handling requests.

---

## 2. Service layer

### Responsibility

Services orchestrate business processes and own the transaction. A Service answers: "What needs to happen?"

Examples: Approve Application, Match Mentor, Schedule Appointment, Send Notifications.

### Allowed
Calling Selectors and Domains, DML, transaction orchestration, email initiation, Platform Event publishing, asynchronous job enqueueing, integration orchestration.

### Not allowed
SOQL, object-specific validation rules, trigger logic.

### Standard

The Service queries once up front, passes collections down, and performs one DML at the end. Domains mutate records in memory; the Service persists them.

Good:
```apex
public with sharing class MentorshipService {

    private static MentorshipService instance;

    public static MentorshipService getInstance() {
        if (instance == null) {
            instance = new MentorshipService();
        }
        return instance;
    }

    @TestVisible
    private static void setInstance(MentorshipService mock) {
        instance = mock;
    }

    // Rule 9 compliant: instance method. Rule 12 compliant: bulk signature.
    public void approveApplications(Set<Id> applicationIds) {
        Map<Id, Application__c> applications =
            ApplicationSelector.getInstance().selectByIds(applicationIds);

        ApplicationDomain.getInstance().approve(applications.values());

        update applications.values();
    }
}
```

Bad:
```apex
public class MentorshipService {
    public static void approveApplication(Id applicationId) {
        Application__c app = ApplicationSelector.selectById(applicationId);
        if (app.Profile_Complete__c == false) {
            throw new BusinessException();
        }
        if (app.Status__c != 'Submitted') {
            throw new BusinessException();
        }
        app.Status__c = 'Approved';
    }
}
```

The business rules belong in the Domain. The method is also static (unmockable) and single-record (unusable from a trigger path).

### The DML boundary (Rule 17)

When a Service calls another Service that also performs DML, the transaction accumulates multiple commits and partial-failure behavior becomes unclear.

**The outermost Service owns the transaction. Inner Services return unsaved records; they do not persist.**

Name methods so the boundary is visible at the call site:

- `approveApplications(Set<Id>)` — persists. A public entry point.
- `prepareApprovalNotices(List<Application__c>)` — returns unsaved records for the caller to persist.

```apex
public void approveApplications(Set<Id> applicationIds) {
    Map<Id, Application__c> applications =
        ApplicationSelector.getInstance().selectByIds(applicationIds);

    ApplicationDomain.getInstance().approve(applications.values());

    List<Task> notices = NotificationService.getInstance()
        .prepareApprovalNotices(applications.values());

    update applications.values();
    insert notices;
}
```

Where records must be inserted in order because a child needs a parent Id, the outermost Service sequences the DML itself. That is the case a Unit of Work would otherwise handle, and it is manageable directly at the call depths this codebase has.

**No Unit of Work framework for now.** Adopt one only when a documented case cannot be expressed with the rule above — a call chain deep enough that the outermost Service cannot reasonably know what needs persisting, or cross-object insert ordering spanning three or more Services.

### SOLID alignment
**SRP** — one Service method represents one business process.
**OCP** — new processes can be added without modifying existing ones.

---

## 3. Domain layer

### Responsibility

Domains own all object-specific business rules. A Domain answers: "Is this action allowed?"

Examples: `ApplicationDomain.approve()`, `AppointmentDomain.validateAppointmentDate()`, `MentorDomain.validateCapacity()`.

### Allowed
Business validations, status transition rules, object behavior, trigger processing, record-level logic.

### Not allowed
UI logic, SOQL, DML, multi-object orchestration.

### Standard

```apex
public inherited sharing class ApplicationDomain {

    private static ApplicationDomain instance;

    public static ApplicationDomain getInstance() {
        if (instance == null) {
            instance = new ApplicationDomain();
        }
        return instance;
    }

    @TestVisible
    private static void setInstance(ApplicationDomain mock) {
        instance = mock;
    }

    // Service-facing: throws on violation.
    public void approve(List<Application__c> applications) {
        for (Application__c app : applications) {
            if (app.Status__c != 'Submitted') {
                throw new BusinessException(
                    'Only submitted applications can be approved: ' + app.Id
                );
            }
            app.Status__c = 'Approved';
        }
    }

    // Trigger-facing: adds per-record errors so partial success works on bulk loads.
    public void handleBeforeUpdate(
        List<Application__c> newRecords,
        Map<Id, Application__c> oldMap
    ) {
        for (Application__c app : newRecords) {
            Application__c prior = oldMap.get(app.Id);
            if (prior.Status__c == 'Approved' && app.Status__c == 'Submitted') {
                app.addError('Approved applications cannot return to Submitted.');
            }
        }
    }
}
```

Bad:
```apex
app.Status__c = 'Approved';
```
Direct status transitions must not occur outside the Domain.

`inherited sharing` lets the Domain run in the caller's context rather than forcing a sharing decision at the rule layer.

### Error handling by entry path

A Domain method reachable from both a trigger and a Service call needs a deliberate answer, not an accidental one:

- **Trigger context** — use `addError()`. The platform reports per-record failures and partial success works on bulk data loads. A thrown exception rolls back the entire batch, so one bad record fails 199 good ones.
- **Service context** — throw `BusinessException`. Let it propagate to the Controller, which translates it for the UI.

Provide separate entry points rather than a boolean flag. `approve()` and `handleBeforeUpdate()` above are the pattern.

### SOLID alignment
**SRP** — each Domain owns one object's business rules.
**OCP** — new rules can be added without modifying Services.

---

## 4. Selector layer

### Responsibility

Selectors are the only location where SOQL is written. A Selector answers: "What data is required?"

### Allowed
SOQL, query optimization, security enforcement, reusable query methods.

### Not allowed
DML, business rules, record manipulation, process orchestration.

### Standard

```apex
public with sharing class ApplicationSelector {

    private static ApplicationSelector instance;

    public static ApplicationSelector getInstance() {
        if (instance == null) {
            instance = new ApplicationSelector();
        }
        return instance;
    }

    @TestVisible
    private static void setInstance(ApplicationSelector mock) {
        instance = mock;
    }

    // Bulk-first. Returns a map so callers can look up by Id without a loop.
    public Map<Id, Application__c> selectByIds(Set<Id> applicationIds) {
        return new Map<Id, Application__c>([
            SELECT Id, Status__c, Mentor__c, Profile_Complete__c
            FROM Application__c
            WHERE Id IN :applicationIds
            WITH USER_MODE
        ]);
    }

    // Convenience wrapper, implemented via the bulk method so there is one
    // query definition and no second place to maintain the field list.
    public Application__c selectById(Id applicationId) {
        Map<Id, Application__c> results =
            selectByIds(new Set<Id>{ applicationId });
        if (!results.containsKey(applicationId)) {
            throw new BusinessException('Application not found: ' + applicationId);
        }
        return results.get(applicationId);
    }
}
```

### Security enforcement

Default to `WITH USER_MODE` on Selector queries. It enforces object permissions, field-level security, and sharing for the running user in a single clause, and it is the current platform-recommended mechanism.

**System-context queries need an explicit, separate method.** Trigger and automation logic frequently must read records the running user cannot see, and applying `WITH USER_MODE` there causes intermittent failures that depend on who saved the record. Name these methods so the access level is visible at the call site, and justify each in a comment:

```apex
// System context: called from ApplicationTrigger, where the running user may
// lack read access to the related Mentor record.
public Map<Id, Mentor__c> selectMentorsSystemContext(Set<Id> mentorIds) {
    return new Map<Id, Mentor__c>([
        SELECT Id, Capacity__c FROM Mentor__c WHERE Id IN :mentorIds
    ]);
}
```

Do not solve this by marking the Selector `without sharing`. That removes enforcement for every method on the class rather than the one that needs it.

### SOLID alignment
**SRP** — Selectors retrieve data only.
**DIP** — Services depend on a data access abstraction rather than embedded SOQL.

---

## 5. Trigger standard

One trigger per object (Rule 14). Multiple triggers on the same object execute in non-deterministic order, which produces behavior that changes between deployments for no visible reason.

Triggers contain no logic. They route context to the Domain.

Good:
```apex
trigger ApplicationTrigger on Application__c (
    before insert, before update, after insert, after update
) {
    ApplicationDomain domain = ApplicationDomain.getInstance();

    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            domain.handleBeforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            domain.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
```

Bad:
```apex
trigger ApplicationTrigger on Application__c (before insert) {
    for (Application__c app : Trigger.new) {
        if (app.Status__c == 'Approved') {
            // Business logic directly in the trigger
        }
    }
}
```

### Before vs. after

- **Before** — same-record field changes and validation. No DML needed, no recursion risk.
- **After** — related-record work, anything needing the record Id, Platform Events.

Putting a same-record update in an after context creates an avoidable recursive save.

### Recursion

Where a Domain can re-enter itself within a transaction, guard with a static flag on the Domain class. Reset behavior across transaction boundaries must be considered explicitly; a static that never resets will suppress legitimate processing in a batch context.

---

## 6. LWC standards

The same separation applies on the client. The Apex controller is the boundary between the two.

- **Component** — template plus a JavaScript class handling rendering, user events, and local state.
- **Service module** — a plain JS module (`service/mentorshipService.js`) wrapping imperative Apex calls and shaping responses. Components import it rather than importing Apex directly, which keeps the plumbing in one place and makes it mockable in Jest.
- **Apex controller** — thin, static, delegating to the Apex Service layer.

### Rules

- **No business rules in a component.** If a component decides whether an application is eligible, that rule now exists in two places and will diverge.
- **`@wire` for reads, imperative for writes.**
- **Every imperative call handles errors** and surfaces something usable to the user. A silent catch is worse than an unhandled rejection.
- **No hardcoded labels.** Use custom labels.
- **Experience Cloud components** must behave sensibly for community and guest users, whose permission profile differs substantially from an internal user's.
- **Jest tests** mock the service module, not Apex directly.

---

## 7. Bulkification

Salesforce processes up to 200 records per trigger invocation, and integrations load thousands. **Layering does not protect against bulk failures — it makes them easier to miss**, because a Selector call inside a loop reads like a cheap method invocation rather than a query.

### Signature rules (Rule 12)

| Layer | Signature |
|---|---|
| Selector | `Map<Id, SObject> selectByIds(Set<Id>)`; collections in, collections out |
| Domain | `List<SObject>` for anything reachable from a trigger |
| Service | `Set<Id>` or `List<SObject>`; one query up front, one DML at the end |
| Controller | Collection parameters, even where the UI submits one record |

Single-record convenience methods are permitted only where a genuinely single-record entry point exists, and must delegate to the bulk method.

### Prohibited in all layers

- SOQL or DML inside a loop, including a loop several frames up the call stack
- Callouts inside a loop
- `Trigger.new[0]` or any logic assuming a single record
- Nested collection loops that should be a `Map` lookup

---

## 8. Asynchronous processing

The Service layer owns async orchestration. Domains and Selectors are called from async context but do not decide to go async.

- **Queueable** — default choice. Chainable, accepts non-primitive types, easier to test than `@future`.
- **`@future`** — legacy. New code should use Queueable unless a specific limitation requires otherwise.
- **Batch Apex** — record volumes above roughly 10,000, or where the work must be chunked to stay within limits.
- **Schedulable** — a thin wrapper that calls a Service method. No logic of its own.

Domain rules must be callable from async context, which means they cannot depend on `Trigger` context variables.

---

## 9. Testing standards

Layering exists partly so each layer can be tested in isolation. Structure the suite to use that.

| Layer | Approach |
|---|---|
| **Domain** | No DML. Construct records in memory, call the rule, assert the outcome or thrown exception. Fast, and should be the largest part of the suite. |
| **Selector** | Real data in `@testSetup`. Assert the query returns the right records. Include a `System.runAs()` case with a low-privilege user to verify FLS and sharing enforcement. |
| **Service** | Stub the Selector and Domain using the Apex Stub API. Test orchestration, not rules already covered by Domain tests. |
| **Controller** | Assert delegation and exception translation, not business behavior. |

### Requirements

- **Every trigger path needs a 200-record bulk test.** A layered codebase with only single-record tests has the same production failure profile as an unlayered one.
- **Every test asserts on outcomes.** Coverage percentage is a deployment gate, not a quality signal; a class can reach 90% with tests that assert nothing.
- **Assertion messages state what failed.** `Assert.areEqual(expected, actual, 'Submitted application should be approved')`.
- **No `@isTest(SeeAllData=true)`.**
- **No hardcoded IDs** in test setup.
- **Per-class coverage** meets the org standard, not just the org-wide aggregate.

### Mocking

Use the **Apex Stub API** (`Test.createStub()` with a `System.StubProvider` implementation). No third-party mocking framework.

The Stub API returns an instance typed as the concrete class, so it drops straight into the `@TestVisible` setter with no interface extraction required:

```apex
@isTest
static void approveApplications_delegatesToDomain() {
    ApplicationSelector mockSelector = (ApplicationSelector) Test.createStub(
        ApplicationSelector.class, new ApplicationSelectorStub()
    );
    ApplicationSelector.setInstance(mockSelector);

    MentorshipService.getInstance().approveApplications(new Set<Id>{ fakeId });

    // assert on orchestration, not on rules already covered by Domain tests
}
```

Service-layer stubbing depends on Rule 15. A hardcoded singleton cannot be replaced from a test, which makes Rule 9's stated purpose unreachable.

---

## 10. Cross-cutting standards

### Sharing (Rule 13)

| Layer | Declaration |
|---|---|
| Controller | `with sharing` |
| Service | `with sharing` |
| Domain | `inherited sharing` |
| Selector | `with sharing` |

`without sharing` requires a comment explaining why and approval at design review. Never leave sharing undeclared.

### Exceptions

```apex
/**
 * @description  Thrown when a Domain business rule is violated.
 */
public class BusinessException extends Exception {}
```

- Domains throw it (Service path) or call `addError()` (trigger path).
- Services do not catch it. Let it propagate.
- Controllers catch it and translate to `AuraHandledException`.
- Never swallow an exception. A catch block that logs and continues leaves data half-written.

### Constants and configuration

- Picklist API values, record type developer names, and similar strings belong in a constants class or Custom Metadata, not scattered as literals.
- **No hardcoded IDs** (Rule 16) — record types, queues, profiles, users, groups. These break on deploy to another org.
- Endpoints and credentials use Named Credentials, never literals.

### Documentation header (Rule 11)

```apex
/**
 * @author       Jane Doe
 * @created      2026-08-20
 * @modified     2026-08-20
 * @description  Orchestrates the mentorship application approval process.
 * @objects      Application__c, Mentor__c
 */
```

---

## Mandatory development rules

1. Controllers must be thin.
2. No SOQL outside Selectors.
3. No business rules outside Domains.
4. Services orchestrate. Domains validate and decide.
5. Triggers contain no business logic. Triggers invoke Domains only.
6. Never perform direct status transitions outside Domains.
   Bad: `app.Status__c = 'Approved';`
   Good: `ApplicationDomain.getInstance().approve(applications);`
7. Selectors must be reusable and object-focused. No process-specific query classes.
8. One class, one responsibility.
9. **Prefer instance methods** for Domain, Service, and Selector classes, to allow encapsulation, dependency injection, and mock-based testing.
   Static is appropriate for: controller entry points (`@AuraEnabled`, REST, `@InvocableMethod`); stateless utility and helper classes; factory, singleton accessor, and builder methods.
   Avoid: large static service classes coordinating business logic; static methods that make mocking or extension difficult.
10. **One Selector per object.** Add query methods to the existing Selector rather than creating another class.
11. **Standard documentation header** on every class, interface, trigger, and enum: author, created date, last modified date, description, related objects.
12. **Bulk-safe signatures.** Any method reachable from a trigger takes a collection. Selectors return maps or lists. Single-record convenience methods delegate to the bulk method.
13. **Declare sharing explicitly** on every class. `without sharing` requires justification and design-review approval.
14. **One trigger per object**, containing context routing only.
15. **Singletons expose a `@TestVisible` injection point** so dependencies can be replaced in tests.
16. **No hardcoded IDs, endpoints, or credentials.**
17. **The outermost Service owns the transaction.** Inner Services return unsaved records via `prepare`-prefixed methods rather than performing their own DML.

---

## Layer ownership matrix

| Requirement | Layer |
|---|---|
| LWC request handling | Controller |
| REST request handling | Controller |
| JSON conversion | Controller |
| Exception translation for UI | Controller |
| Approve application process | Service |
| Match mentor process | Service |
| Schedule appointment process | Service |
| Send email process | Service |
| Call external API | Service |
| Enqueue async job | Service |
| DML | Service |
| Application validation | Domain |
| Mentor eligibility validation | Domain |
| Appointment validation | Domain |
| Status transition rules | Domain |
| Trigger processing | Domain |
| Query applications | Selector |
| Query mentors | Selector |
| Query appointments | Selector |
| FLS and sharing enforcement on reads | Selector |

### Service vs. Domain

| Logic | Service | Domain |
|---|---|---|
| Approve application process | ✅ | ❌ |
| Create appointment | ✅ | ❌ |
| Send email | ✅ | ❌ |
| Call Zoom API | ✅ | ❌ |
| Enqueue Queueable | ✅ | ❌ |
| DML | ✅ | ❌ |
| Application eligibility rules | ❌ | ✅ |
| Appointment validation | ❌ | ✅ |
| Trigger logic | ❌ | ✅ |
| Status transition rules | ❌ | ✅ |
| Object-level business rules | ❌ | ✅ |

A useful test: if the logic mentions more than one object, it is probably a Service. If it would still be true with no database involved, it is probably a Domain rule.

---

## Success criteria

A solution is compliant when:

- Controllers contain no business logic and no SOQL
- Services contain no SOQL and no object-specific rules
- Domains contain all business rules and no SOQL or DML
- Selectors contain all SOQL and no DML
- Triggers contain no logic and route to a Domain
- One trigger and one Selector exist per object
- Domain, Service, and Selector methods are instance methods with static singleton accessors
- Sharing is declared explicitly on every class
- Selector queries enforce FLS, with system-context exceptions named and justified
- Methods reachable from a trigger accept collections
- Only the outermost Service in a call chain performs DML
- Singletons expose a `@TestVisible` injection point
- Every trigger path has a 200-record test
- Every class carries the standard documentation header
- Each layer can be tested independently
- New requirements can be implemented with minimal impact to existing code

---

## Legacy code

Most orgs contain code predating this standard. Do not rewrite it opportunistically.

- **New classes** follow the standard fully.
- **Modified legacy classes** follow it for the new logic. Extract the touched logic into the correct layer where that is a contained change; leave the rest.
- **Wholesale refactors** are their own ticket with their own risk assessment, never a rider on a feature branch. A refactor bundled into a feature merge request makes both unreviewable.
- Where a legacy class blocks compliance, note it in the merge request as a follow-up rather than working around it silently.

---

## Documented exceptions

This architecture is the default standard for all Apex development unless an approved exception is documented during design review.

When a deviation appears necessary, state what the standard requires, why this case does not fit, and what the alternative is, then route it to design review. Record the approval in the class header. Silent deviations are what turn a standard into a suggestion.
