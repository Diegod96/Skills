# Apex standards: decision log

Records the questions the v1 standard left open, what was decided, why, and what would justify revisiting. Supersedes the earlier gaps document.

Two errors in v1 were corrected rather than decided: the missing `static` on all three singleton accessors, and the inverted `static` between the Controller Good and Bad examples. Neither was a design question — the document's own Rule 9 already implied both, and `@AuraEnabled` does not compile without `static`.

---

## D1. Bulk signatures — **mandatory** (Rule 12)

**Decision.** Any method reachable from a trigger accepts a collection. Selectors return `Map<Id, SObject>` or `List<SObject>`. Single-record convenience methods are permitted only where a genuinely single-record entry point exists, and must delegate to the bulk method rather than holding a second query definition.

**Why.** This is platform physics, not preference. Triggers process up to 200 records per invocation and integrations load thousands, so a single-record Domain method reachable from a trigger has no correct caller. v1 already had this tension: `handleBeforeUpdate(List, Map)` is bulk while `approve(Application__c)` is not, and the only way to connect them is a loop.

The layering makes this worse rather than better, which is the part worth internalizing. In flat code a query inside a loop is visible as a query. Behind a Selector it reads as a cheap method call, and reviewers stop seeing it.

**Would revisit if:** never. There is no version of this that is optional.

---

## D2. DML boundary — **outermost Service owns the transaction**, no Unit of Work (Rule 17)

**Decision.** The outermost Service in a call chain performs all DML. Inner Services return unsaved records through `prepare`-prefixed methods. No Unit of Work framework is adopted.

**Why.** The alternative — fflib's `SObjectUnitOfWork` or a homegrown equivalent — is real machinery for a team of this size to maintain, and it earns its cost in deep call chains with complex cross-object insert ordering. Mentoring Hub's service calls are shallow and form-driven. Paying that cost now is buying insurance against a problem the codebase does not have.

The `prepare` naming convention is what makes this workable: the boundary is visible at the call site, so a reviewer can see when an inner Service is about to violate it.

**Correcting something I said earlier.** I previously described retrofitting a Unit of Work as expensive and implied that argued for deciding early. That was overstated. Because this architecture already confines DML to the Service layer, a later retrofit touches Service classes only — Domains and Selectors never perform DML, so they are untouched by the change. The layering itself is the thing that makes deferring safe, which is a point in favor of deferring rather than against.

**Would revisit if:** a call chain becomes deep enough that the outermost Service cannot reasonably know everything that needs persisting, or cross-object insert ordering spans three or more Services. Either is a design-review trigger, not a unilateral call.

---

## D3. Sharing declarations — **mandatory and explicit** (Rule 13)

**Decision.**

| Layer | Declaration |
|---|---|
| Controller | `with sharing` |
| Service | `with sharing` |
| Domain | `inherited sharing` |
| Selector | `with sharing` |

`without sharing` requires a justifying comment and design-review approval. Undeclared sharing is a defect.

Selector queries default to `WITH USER_MODE`. System-context queries get separately named methods with a justifying comment, never a `without sharing` on the class.

**Why.** An undeclared class inherits sharing from its caller in ways that are hard to reason about and easy to get wrong, and the failure is silent — the code works for the developer testing as an admin and behaves differently for a staff user. `inherited sharing` on Domains is the right default because a business rule should not impose a sharing decision on its caller; the rule is the same regardless of who can see the record.

The system-context carve-out matters more than it looks. Applying `WITH USER_MODE` blindly to Selector methods called from triggers produces failures that depend on *who saved the record*, which is among the more miserable things to diagnose. Naming those methods explicitly makes the access level visible where it is called rather than buried in the query.

**Would revisit if:** never for the requirement itself. The specific per-layer defaults could shift if a use case demands it, through design review.

---

## D4. Singleton testability — **`@TestVisible` setter, Apex Stub API** (Rule 15)

**Decision.** Every Domain, Service, and Selector singleton exposes:

```apex
@TestVisible
private static void setInstance(MentorshipService mock) {
    instance = mock;
}
```

Mocking uses the platform Apex Stub API (`Test.createStub()` with a `System.StubProvider`). No third-party mocking framework.

**Why.** Rule 9 mandates instance methods specifically so classes can be mocked, but a hardcoded singleton is itself an unmockable dependency — `MentorshipService.getInstance()` called from inside a Service cannot be replaced from a test. Without this, Rule 9 delivers testability on paper and the success criteria's "unit tests can target each layer independently" is unreachable.

The alternatives considered were an fflib-style `Application` factory registry, and constructor injection. The registry is more powerful and appropriate at larger scale; it is also a framework to adopt and teach for a benefit the setter already delivers. Constructor injection fights the singleton pattern v1 already committed to.

The Stub API specifically, rather than a library, because it returns an instance typed as the concrete class. That drops straight into the setter with no interface extraction — meaning no `IApplicationSelector` interfaces to write and maintain alongside every class.

**Would revisit if:** the number of classes needing coordinated mock setup in a single test grows to where per-class setter calls become unwieldy. That is the point where a central registry earns its cost.

---

## Previously resolved in v2

These were gaps rather than open questions, and were closed in the v2 draft:

- **`BusinessException`** — defined as a bare `extends Exception`, thrown by Domains on the Service path, `addError()` on the trigger path, caught and translated by Controllers. The split by entry path matters: a thrown exception in trigger context fails all 200 records when one is bad.
- **One trigger per object** (Rule 14) — multiple triggers on one object execute in non-deterministic order.
- **LWC standards** (section 6) — component, service module, thin Apex controller; no business rules on the client.
- **Testing standards** (section 9) — Domain tests DML-free and forming the bulk of the suite, Selector tests with `System.runAs()`, Service tests stubbed, mandatory 200-record bulk test per trigger path.

---

## Rollout

D1 and D3 change code being written today and are the ones to communicate first. D4 changes how tests are written and is worth pairing with one worked example in the repo. D2 mostly constrains a pattern the team is not yet using, so it costs nothing now and prevents a later cleanup.

None of the four requires touching existing code. Per the legacy-code section, new classes comply fully; modified classes comply for the new logic only.
