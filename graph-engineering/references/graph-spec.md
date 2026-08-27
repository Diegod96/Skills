# Operational Graph Specification

Read this reference when producing an implementation-ready graph definition, contracts, executor code, or a detailed audit. Adapt field names to the repository's conventions; preserve the invariants rather than copying this example mechanically.

## Minimum graph definition

An executable graph should identify:

- workflow name and immutable definition version;
- input and output schema versions;
- nodes and their owning roles;
- dependencies, conditions, joins, and transitions;
- permission and isolation requirements;
- retry, timeout, approval, and recovery policy;
- artifact and evidence requirements;
- terminal success, failure, cancellation, and supersession behavior.

Illustrative YAML:

```yaml
workflow:
  name: change-delivery
  version: 1.0.0
  input_schema: schemas/change-request.v1.json
  output_schema: schemas/delivery-result.v1.json

defaults:
  timeout: 20m
  max_attempts: 1

nodes:
  analyze:
    actor: impact-analyst
    input: workflow.input
    permissions: [repository:read]
    output_schema: schemas/impact.v1.json
    produces: [impact-report]
    success_when: output.status == "complete"

  build:
    actor: builder
    depends_on: [analyze]
    when: analyze.output.requires_change == true
    permissions: [assigned-workspace:write, test-environment:execute]
    isolation: assigned-workspace
    input:
      impact: analyze.output
    output_schema: schemas/build-result.v1.json
    produces: [source-diff, build-evidence]
    retry:
      max_attempts: 2
      only_if: error.retryable == true
    on_failure: failed

  verify:
    actor: verifier
    depends_on: [build]
    permissions: [repository:read, checks:execute]
    consumes: [source-diff]
    produces: [verification-evidence]
    success_when: output.required_checks_failed == 0
    on_failure: failed

  approve:
    actor: human-approver
    depends_on: [verify]
    type: approval
    approval_scope: [workflow.version, source-diff, verification-evidence]
    on_approve: succeeded
    on_reject: rejected

terminal_states: [succeeded, failed, rejected, cancelled]
```

Conditions must use structured fields with declared types. Avoid transitions based on parsing free-form summaries.

## Node contract

For each node, define these fields in a schema or equivalent type system:

| Field | Purpose |
| --- | --- |
| `id` and `contract_version` | Stable identity and compatibility |
| `purpose` | One bounded responsibility |
| `actor_role` | Capability and separation-of-duties owner |
| `depends_on` | Prerequisite nodes or artifacts |
| `entry_condition` | Typed predicate for readiness or routing |
| `input_schema` | Required data and artifact references |
| `output_schema` | Result, evidence, errors, and downstream fields |
| `permissions` | Allowed tools, data, network, workspace, and environments |
| `isolation` | Workspace, sandbox, credential, or transaction boundary |
| `timeout` and `retry` | Bounded execution and retryable error classes |
| `success_predicate` | Deterministic completion rule |
| `transitions` | Success, failure, revision, approval, and terminal edges |
| `produces` | Typed artifacts and evidence |

A result envelope can keep routing stable across different workers:

```json
{
  "contract_version": "1",
  "node_id": "verify",
  "attempt_id": "attempt-uuid",
  "status": "succeeded",
  "summary": "Required checks passed",
  "outputs": {},
  "artifacts": [],
  "evidence": [],
  "errors": [],
  "metrics": {}
}
```

Keep `summary` informational. Routing should depend on typed `status`, outputs, evidence, and error codes.

## Runtime state and events

Use an explicit status model. A practical starting set is:

```text
pending -> ready -> running -> succeeded
                    |   |
                    |   +-> waiting_approval -> succeeded / rejected
                    +-----> failed / cancelled
```

Add `superseded` when a later attempt or graph version replaces a result. Distinguish failure from cancellation, rejection, and an intentionally skipped conditional node.

Every state change should emit an event with:

```json
{
  "event_id": "uuid",
  "event_type": "node_attempt.completed",
  "occurred_at": "timestamp",
  "workflow_run_id": "uuid",
  "workflow_version": "1.0.0",
  "node_id": "verify",
  "attempt_id": "uuid",
  "actor_id": "verifier-instance",
  "source_revision": "commit-or-content-hash",
  "input_hash": "sha256",
  "output_hash": "sha256",
  "artifact_refs": [],
  "evidence_refs": [],
  "previous_event_hash": "sha256"
}
```

An event log should be append-only. Corrections create new events or superseding attempts; they do not erase history.

## Artifact and evidence provenance

Artifacts should record type, schema version, content hash, storage location, producing attempt, source revision, and sensitivity or retention label. Evidence should additionally identify which requirement or success predicate it supports.

Maintain these traceable paths where applicable:

```text
requirement -> node contract -> attempt -> artifact -> evidence -> review -> approval -> release
failure -> owning attempt -> revision request -> superseding attempt
```

An approval record must bind the approver's decision to the exact graph version and artifact/evidence hashes. A later material change invalidates the approval or requires an explicitly defined reapproval rule.

## Join and invalidation semantics

For every fan-in, specify:

- whether all, any, quorum, or a named subset of branches is required;
- treatment of skipped, failed, cancelled, and stale branches;
- merge ownership and conflict policy;
- the schema of the joined result.

When a node is revised, invalidate descendants whose inputs or predicates depended on the changed output. Preserve unaffected branches. Compute invalidation from declared data and artifact dependencies, not only from visual edge proximity.

## Retry and compensation

Retry only errors declared retryable and only when the node action is idempotent or protected by an idempotency key. Define limits for attempts, elapsed time, cost, and external side effects.

For non-idempotent effects, specify a compensation or a human recovery decision. Never assume retrying a deployment, payment, message, or data mutation is safe.

## Validation scenarios

At minimum, exercise:

- normal success;
- conditionally skipped branch;
- one parallel branch failing before a join;
- retryable and non-retryable failure;
- evaluator-requested revision reaching the attempt limit;
- approval granted, denied, and expired or invalidated;
- interruption followed by resume;
- changed upstream artifact invalidating the correct descendants;
- duplicate event or worker callback;
- graph-version change during an active run.

Assert state, transitions, emitted events, artifacts, permission checks, and absence of duplicate external effects—not only the final label.

## Review checklist

- Is global state owned by one durable authority?
- Are contracts typed and versioned?
- Are every node's permissions and isolation explicit?
- Is parallel work truly independent, with defined join and merge semantics?
- Can a builder approve its own work?
- Can a required deterministic check be bypassed by model output?
- Are retries bounded and safe?
- Can failure be localized to the smallest affected subgraph?
- Can a run be reconstructed from events and artifact hashes?
- Are approval, release, and recovery transitions auditable?
- Is the chosen runtime simpler than the problem, rather than more complex?
