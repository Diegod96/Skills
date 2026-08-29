# Layer templates

Copy-ready templates for each layer. Read before writing any class.

**Note on the source document:** the singleton and controller examples in the standards doc are missing the `static` keyword (the telltale double space where it was stripped in conversion). The templates below restore it. Both corrections follow the standard's own Rule 9, which names singleton accessors and controller entry points as the cases where static is correct. See `integration/apex-standards-decisions.md`.

## Documentation header (Rule 11)

Required on every class, interface, trigger, and enum.

```apex
/**
 * @author       Jane Doe
 * @created      2026-08-20
 * @modified     2026-08-20
 * @description  Orchestrates the mentorship application approval process.
 * @objects      Application__c, Mentor__c
 */
```

## Controller

Entry points are `static` because the platform requires it. The static method does one thing: get the service instance and delegate.

```apex
public with sharing class MentorshipController {

    @AuraEnabled
    public static void approveApplications(List<Id> applicationIds) {
        try {
            MentorshipService.getInstance().approveApplications(new Set<Id>(applicationIds));
        } catch (BusinessException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ApplicationDTO> getPendingApplications(Id programId) {
        return MentorshipService.getInstance().getPendingApplications(programId);
    }
}
```

Note the collection parameter. Even where the UI submits one record today, a collection signature costs nothing now and prevents a rewrite when a bulk action is added.

## Service

Owns the transaction and the DML boundary. Queries once, passes collections down, writes once.

```apex
public with sharing class MentorshipService {

    private static MentorshipService instance;

    public static MentorshipService getInstance() {
        if (instance == null) {
            instance = new MentorshipService();
        }
        return instance;
    }

    public void approveApplications(Set<Id> applicationIds) {
        Map<Id, Application__c> applications =
            ApplicationSelector.getInstance().selectByIds(applicationIds);

        ApplicationDomain.getInstance().approve(applications.values());

        update applications.values();

        NotificationService.getInstance().sendApprovalNotices(applications.values());
    }
}
```

One query, one DML, regardless of how many records come in. The Domain mutates in memory; the Service persists.

**Nested DML (Rule 17):** the outermost Service owns the transaction. Inner Services return unsaved records through `prepare`-prefixed methods rather than performing their own DML:

```apex
List<Task> notices = NotificationService.getInstance()
    .prepareApprovalNotices(applications.values());

update applications.values();
insert notices;
```

The prefix makes the boundary visible at the call site. Where a child record needs a parent Id, the outermost Service sequences the DML itself. No Unit of Work framework.

## Domain

Owns the rules. No SOQL, no DML. Bulk-shaped for anything a trigger can reach.

```apex
public inherited sharing class ApplicationDomain {

    private static ApplicationDomain instance;

    public static ApplicationDomain getInstance() {
        if (instance == null) {
            instance = new ApplicationDomain();
        }
        return instance;
    }

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

    public void handleBeforeUpdate(
        List<Application__c> newRecords,
        Map<Id, Application__c> oldMap
    ) {
        validateStatusTransitions(newRecords, oldMap);
    }

    private void validateStatusTransitions(
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

**Error handling differs by entry path.** From a trigger, use `addError()` so the platform reports per-record failures and partial success works on bulk loads. From a service call, throw. A Domain method reachable from both needs to handle this deliberately rather than by accident.

`inherited sharing` lets the Domain run in the caller's context rather than forcing a sharing decision at the rule layer.

## Selector

The only place SOQL exists. One per object (Rule 10). Bulk-first.

```apex
public with sharing class ApplicationSelector {

    private static ApplicationSelector instance;

    public static ApplicationSelector getInstance() {
        if (instance == null) {
            instance = new ApplicationSelector();
        }
        return instance;
    }

    public Map<Id, Application__c> selectByIds(Set<Id> applicationIds) {
        return new Map<Id, Application__c>([
            SELECT Id, Status__c, Mentor__c, Profile_Complete__c
            FROM Application__c
            WHERE Id IN :applicationIds
            WITH USER_MODE
        ]);
    }

    // Convenience wrapper. Implemented via the bulk method so there is one query
    // definition, and so it cannot be safely called in a loop by accident.
    public Application__c selectById(Id applicationId) {
        Map<Id, Application__c> results = selectByIds(new Set<Id>{ applicationId });
        if (!results.containsKey(applicationId)) {
            throw new BusinessException('Application not found: ' + applicationId);
        }
        return results.get(applicationId);
    }

    public List<Application__c> selectPendingByProgram(Set<Id> programIds) {
        return [
            SELECT Id, Status__c, Mentor__c
            FROM Application__c
            WHERE Program__c IN :programIds
              AND Status__c = 'Submitted'
            WITH USER_MODE
        ];
    }
}
```

`WITH USER_MODE` enforces field-level security and object permissions for the running user. Use it on anything returning data to a user. Omit it only for system-context operations, and say why in a comment.

## Trigger

One trigger per object. No logic. Routes to the Domain.

```apex
trigger ApplicationTrigger on Application__c (
    before insert, before update, after insert, after update
) {
    ApplicationDomain domain = ApplicationDomain.getInstance();

    if (Trigger.isBefore) {
        if (Trigger.isUpdate) {
            domain.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isInsert) {
            domain.handleBeforeInsert(Trigger.new);
        }
    }
}
```

## Custom exception

```apex
public class BusinessException extends Exception {}
```

The standard references `BusinessException` without defining it. Define it once, in its own file, and use it for rule violations. Do not catch it in the Service — let it reach the Controller, which translates it into something the UI can display.

## Tests

### Domain test — fast, no DML

```apex
@isTest
private class ApplicationDomainTest {

    @isTest
    static void approve_whenStatusNotSubmitted_throwsBusinessException() {
        Application__c app = new Application__c(Status__c = 'Draft');

        try {
            ApplicationDomain.getInstance().approve(new List<Application__c>{ app });
            Assert.fail('Expected BusinessException for a non-submitted application');
        } catch (BusinessException e) {
            Assert.isTrue(
                e.getMessage().contains('Only submitted'),
                'Exception should name the status rule, got: ' + e.getMessage()
            );
        }
    }

    @isTest
    static void approve_whenSubmitted_setsStatusApproved() {
        Application__c app = new Application__c(Status__c = 'Submitted');

        ApplicationDomain.getInstance().approve(new List<Application__c>{ app });

        Assert.areEqual('Approved', app.Status__c, 'Submitted application should be approved');
    }
}
```

No records inserted, so these run in milliseconds. Most of the suite should look like this.

### Bulk test — required for every trigger path

```apex
@isTest
static void approveApplications_with200Records_processesAll() {
    List<Application__c> apps = TestDataFactory.createApplications(200, 'Submitted');
    insert apps;

    Set<Id> ids = new Map<Id, Application__c>(apps).keySet();

    Test.startTest();
    MentorshipService.getInstance().approveApplications(ids);
    Test.stopTest();

    List<Application__c> results = [
        SELECT Id, Status__c FROM Application__c WHERE Id IN :ids
    ];
    Assert.areEqual(200, results.size(), 'All 200 applications should be returned');
    for (Application__c app : results) {
        Assert.areEqual('Approved', app.Status__c, 'Every application should be approved');
    }
}
```

### Service test — stub the dependencies

Instance methods (Rule 9) are what make this work. Stub the Selector and Domain so the test exercises orchestration rather than re-testing rules already covered by the Domain tests.

This requires the singleton to accept an injected instance for tests. Add a `@TestVisible` setter:

```apex
@TestVisible
private static void setInstance(MentorshipService mock) {
    instance = mock;
}
```

Apply the same pattern to Selector and Domain singletons. Without it, the singleton is a hard dependency and the layering delivers testability in theory only.
