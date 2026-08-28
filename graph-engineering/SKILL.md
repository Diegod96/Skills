---
name: graph-engineering
description: Design, implement, or audit typed operational graphs for AI-agent systems, including task dependencies, role permissions, runtime state, provenance, deterministic gates, approvals, retries, and recovery. Use for agent orchestration, multi-agent workflows, durable DAGs or state machines, failure localization, and graph-engineering reviews. Do not use for a GraphRAG-only or knowledge-graph modeling request unless it also governs how work executes.
---

# Graph Engineering

Externalize coordination as a typed, versioned, observable graph. Agents perform bounded work; the graph owns scheduling, permissions, state, evidence, approval, and recovery.

Preserve the user's requested scope. Designing a graph does not authorize creating agents, changing infrastructure, invoking paid services, deploying software, or performing other external mutations. Implement those actions only when the request includes them.

## Choose the mode

- **Design**: turn a workflow or goal into an implementation-ready graph specification.
- **Implement**: build or revise graph definitions, contracts, persistence, adapters, or executor code the user requested.
- **Audit**: inspect an existing workflow and its execution evidence for structural, safety, and operability gaps.

If the request mixes modes, state which artifacts will be designed, changed, and only evaluated. Do not turn an architectural brief into a platform build unless implementation was requested.

## Keep four layers distinct

Model each layer that materially affects the workflow:

1. **Work graph** — tasks, dependencies, conditions, parallel branches, joins, gates, and terminal outcomes.
2. **Capability and policy graph** — actors, tools, environments, credentials, read/write scope, separation of duties, and approval authority.
3. **Runtime and provenance graph** — runs, attempts, prompts, tool calls, artifacts, evidence, approvals, retries, supersession, and deployment or publication events.
4. **Knowledge and dependency graph** — domain entities and relationships used to assemble task-specific context or assess impact.

Do not collapse these into one ambiguous diagram. A knowledge graph answers what is related or known; an operational graph determines what may run, who may run it, and what transition is valid.

The planned work graph may be acyclic while runtime history contains revision, retry, approval, and recovery loops. A graph database is optional: an ordinary DAG executor plus durable relational or file-backed state is often sufficient.

## Workflow

### 1. Frame the system boundary

Establish:

- desired outcome and authoritative requirements;
- current repository, harness, tools, environments, and promotion path;
- actors, trust boundaries, and actions requiring human authority;
- quality, cost, latency, compliance, and retention constraints;
- expected scale and failure modes.

Separate confirmed facts, design choices, assumptions, and unresolved questions. Do not assume a named framework, graph database, agent count, or dynamic routing is necessary.

### 2. Define typed node contracts

Each executable node needs an explicit contract:

- purpose and owning role;
- prerequisites and entry condition;
- typed inputs and outputs;
- allowed tools, data, filesystem, network, and environment scope;
- artifacts and evidence it must produce;
- timeout, retry policy, and terminal states;
- success predicate and downstream transitions.

Prefer machine-readable results over prose shared state. Include stable identifiers and schema versions so runs can be resumed, compared, and replayed.

When producing an implementable specification or code, read [references/graph-spec.md](references/graph-spec.md).

### 3. Choose the smallest useful topology

- **Gated sequence** when each stage requires evidence from the previous stage.
- **Structured router** when input type or state selects one of several paths.
- **Fan-out / fan-in** only for independent work with explicit merge semantics.
- **Manager with constrained workers** when one authority should own global state and delegate bounded tasks.
- **Builder / evaluator loop** when revision is expected; define deterministic evaluation, attempt limits, and escalation.
- **Human approval interrupt** for transitions that require accountable authorization.
- **Recovery or compensation branch** for partial failure, rollback, or forward-fix decisions.

Do not add an agent merely because a noun or stage exists. Split work when it benefits from genuine parallelism, different permissions, independent review, materially different context, or failure isolation.

### 4. Make execution durable and observable

Persist enough information to reconstruct why every transition occurred:

- graph definition and schema version;
- source revision and immutable run ID;
- node attempts with input/output hashes and timestamps;
- produced and consumed artifacts;
- tool and environment evidence;
- condition results, errors, retries, and supersession;
- approval identity, decision, scope, and timestamp.

Prefer append-only execution events with a materialized current-state view. A chat transcript may supplement this record but must not be its state authority.

### 5. Encode evidence and authority

Use deterministic systems for facts they can establish: compilation, tests, analyzers, policy checks, deployment validation, schema validation, and actual diffs. Models may interpret this evidence, connect it to requirements, and propose remediation; they must not fabricate a pass or silently replace a required gate with judgment.

Enforce least privilege and separation of duties structurally:

- builders cannot approve their own output;
- reviewers should not mutate the work they are evaluating unless explicitly reassigned to a new attempt;
- approval must identify exactly which graph version, artifacts, and evidence it covers;
- sensitive or production transitions require the user's established authorization path.

### 6. Design recovery before execution

For each meaningful failure class, define whether to retry, revise an upstream owner, skip, compensate, roll back, forward-fix, escalate, or terminate. Bound automatic retries by count, time, cost, and idempotency. Rerun or invalidate the smallest affected subgraph; do not restart unrelated successful work.

Version topology changes. Do not let a production workflow silently rewrite its own graph, policy, or success criteria.

### 7. Validate the graph

Check both static structure and executable behavior:

- all dependencies resolve and the planned DAG has no unintended cycles;
- every join, condition, failure, and approval path has a defined outcome;
- schemas and artifact references are valid;
- permissions are sufficient but not broader than needed;
- parallel writers cannot collide or have an explicit merge owner;
- retries are idempotent or compensating;
- interrupted runs can resume without duplicating effects;
- failure invalidation reaches every affected descendant and no unrelated node;
- deterministic gate failure cannot transition to success;
- provenance connects requirement, attempt, artifact, evidence, approval, and release or publication.

Use representative success, failure, timeout, revision, approval-denial, and resume scenarios. A diagram alone is not validation.

## Implementation choices

Start with the least complex runtime that satisfies the contracts:

- a custom executor when topology is known and existing CLIs or APIs do most work;
- a durable workflow or agent-graph framework when checkpointing, conditional transitions, human interrupts, and replay dominate;
- a graph database only when frequent multi-hop queries over substantial dependency or provenance data justify it.

Keep orchestration independent from worker implementation where practical. Adapters should translate between the graph contract and a tool or agent; tool-specific response shapes should not become global workflow state.

For Salesforce delivery graphs, read [references/salesforce-change-delivery.md](references/salesforce-change-delivery.md). Apply it as a profile, not as a universal requirement.

## Deliverables

Scale the response to the request. A complete design or audit normally includes:

1. system boundary, assumptions, and open decisions;
2. a small diagram of the execution topology;
3. versioned graph definition and node-contract schema;
4. role and permission matrix;
5. runtime state, event, artifact, provenance, and approval model;
6. deterministic gates and acceptance mapping;
7. retry, invalidation, recovery, and escalation behavior;
8. validation scenarios and observability metrics;
9. the smallest pilot that tests the risky design assumptions.

For an audit, classify findings as blocking, material, or improvement; cite the exact node, edge, contract, policy, or runtime evidence; and distinguish missing design from a defect observed in execution.
