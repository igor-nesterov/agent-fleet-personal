---
name: csharp-divergence
description: 'Mandatory TeamLead workflow before planning, routing or dispatching .NET implementation at any complexity. Nontrivial features, fixes, refactors and simplifications use isolated senior-csharp-developer and senior-csharp-developer-alt candidates; explicitly trivial mechanical changes use single mode. Defines frozen inputs, blinded worktrees, sealing, verification, selection, integration and cleanup. Participants load only for their assigned divergence role.'
---

# C# divergence

## Entry and mode selection

- TeamLead MUST LOAD this skill BEFORE planning/routing or dispatch of ANY .NET production/unit-TDD implementation, at ANY complexity, including nontrivial LOW bug fixes.
- `analyst` loads BEFORE constructing a .NET implementation DAG. Both developers load before implementation or operational work; advice/research alone does not require coordination.
- Test/performance/review/release/documentation participants load only on divergence input, including selected/integrated handoffs. Follow the assigned role below, not another role's authority.
- Docs, research, diagnosis-only, deployment and C# discussion do not themselves require a pair. Unknown incident cause goes to `diagnostics-engineer` before implementation; forward `debugger_diagnosis`, do not rederive a known diagnosis without falsifying evidence.
- Only TeamLead authorizes `divergence.mode: single`, with one explicit `single_reason` identifying an obvious trivial mechanical change. Complexity labels alone are not triviality.
- Single mode: delegate one suitable implementer with the decision/reason, assigned root/scope, acceptance criteria and implementation handoff. Keep ordinary TDD, independent verification, review and approval gates. Do NOT manufacture paired identities, two worktrees, frozen-ref bookkeeping, seals or comparison.
- Otherwise nontrivial .NET features, fixes, refactors and simplifications ALWAYS use BOTH `senior-csharp-developer` and `senior-csharp-developer-alt`.
- Missing/unavailable named workers, required declared tools, contexts or outputs BLOCK/escalate; never downgrade to single, `code-quality-engineer`, or another substitute. Check capabilities before every dispatch; validation requires execution tools, edits require `edit`.
- TeamLead only orchestrates: construct/filter payloads, dispatch, track state and select from specialist evidence. Delegate technical comparisons and ALL shell/Git/worktree preparation, integration and cleanup to existing capable roles. No direct project work or nested worker delegation.
- Maximum concurrent agents is 2, or a stricter configured limit. Serialized candidates still need separate fresh contexts and complete blinding.

## Paired DAG

```text
diagnosis if unknown -> prepare_worktrees -> implement A + implement B
  -> BOTH sealed -> test BOTH -> performance if required -> compare/select
  -> integrate_selected ONCE -> integrated retest/review gates
  -> applicable release/docs -> owned cleanup
```

- TeamLead/analyst use this DAG even for LOW ephemeral plans; preserve dependencies and `conflicts_with`, not just complexity-based waves.
- Preparation, integration and cleanup are separate TeamLead delegations to `senior-csharp-developer` in fresh operational contexts. An implementation candidate never prepares its peer, integrates itself or spawns workers.
- Candidate/preparation and pre-selection verification waves MUST NOT trigger normal integration/commit gates. Integrated specialist retests and later review gates concern the SAME accumulated selected/integrated artifact, not two extra candidate reviews or an empty verification-task diff.

## Common contracts (augment the generic task payload)

- Use canonical `task_definition.acceptance_criteria`, `implementation_handoff`, `debugger_diagnosis` and filtered `context_snapshot`, never `ac`/`handoff` aliases.
- Map applicable planner fields unchanged into delegated `task_definition` at EVERY complexity. Runtime preparation resolves IDs/absolute roots/refs; planners never invent paths or commits.
- Immutable refs include location and SHA-256. Freeze requirements, acceptance, common tests/commands, budget and limits before either candidate starts. `budget_ref` may record an agreed not-applicable decision, never arbitrary thresholds.
- Candidate payloads contain ONLY their own identity/root and equal frozen inputs. Operational payloads may contain `candidate_set`/root mappings; independent verifiers receive both `candidate_targets` ONLY after BOTH seals. Never leak these collections through filtered plans, envelopes, logs or tool results into candidate contexts.

```yaml
operation: implement | prepare_worktrees | integrate_selected | cleanup_worktrees
execution_context:
  working_directory: absolute assigned repository/worktree root
  base_commit: full frozen SHA
  base_snapshot_ref: immutable manifest ref and sha256 # approved relevant dirty input included
  allowed_paths: [assigned scope]
  shared_readonly_refs: [explicit frozen requirements/base artifacts]
divergence:
  mode: single | paired
  single_reason: TeamLead triviality decision # single only; no paired fields required
  group_id: string
  round_id: string
  candidate_id: string # own identity only
  agent_name: actual assigned named worker
  requirements_ref: immutable ref and sha256
  acceptance_ref: immutable ref and sha256
  tests_ref: immutable ref and sha256
  budget_ref: immutable ref and sha256
  limits_ref: immutable ref and sha256
candidate_set: [object] # operational only: distinct IDs, agent names and absolute roots
owned_paths: [absolute explicitly owned candidate paths] # operational only
preparation_result: object # frozen refs/base, dirty baseline manifest, own-root mapping, owned_paths
artifact_ref: {manifest: absolute immutable patch/snapshot manifest path, sha256: digest}
candidate_targets: [object] # BOTH sealed identities/roots/base refs/artifacts for independent verification
harness_ref: immutable shared test/fixture revision and provenance/digest # when applicable
selection_record:
  group_id: string
  round_id: string
  selected_id: string
  rejected_ids: [string]
  artifact_ref: object
  evidence_refs: [string]
  reasons: [string]
integration_result:
  selected_id: string
  artifact_ref: object
  integrated_artifact_ref: object # actual integrated content/revision, not assumed candidate HEAD
  dirty_preservation: object
  retained_paths: [string]
  blockers: [string]
```

### Seal and evidence interfaces

- Seal an immutable patch/snapshot plus SHA-256 manifest covering ALL tracked/untracked additions, modifications, deletions and binaries. List exact evidence-file-only exclusions; never exclude source.
- An uncommitted candidate is valid: both HEADs may still equal `base_commit`. No fictional `candidate_commit`, forced commit, push, merge or publication into the original shared checkout.
- Seal unsuccessful output too, with failure evidence and untested limits. Missing/unavailable/unsealed output blocks comparison. A conclusively failing sealed candidate may lose to a verified passing candidate; unexecuted required verification is not a conclusive failure.
- Preserve exact commands, exit codes INCLUDING 0, identifiers and digests; do not omit/trim them as prose. Evidence records applicability, results and limits, not self-approval.
- Developers augment their normal output with `execution_context`, `divergence`, `seal_state: sealed | unsealed`, `artifact_ref`, `changed_files`, `verification_evidence`, `rationale`, `untested_limits`, `blockers`, `next_owner: TeamLead`. Operational output adds applicable `preparation_result`/`integration_result` and retained paths.
- `rationale` covers correctness/contracts, simplicity/maintainability and applicable measured metrics. Alternate `quality_checks` retain tool/revision, applicability, executed/passed/failed/unavailable/not_applicable status and evidence/limits; never invent metrics.
- Test/performance outputs augment the normal result with the following per-candidate evidence; performance also records measurements and unmeasured limits. Review output adds `artifact_ref` and `reviewed_identity`.

```json
{
  "candidate_results": [{
    "group_id": "string", "round_id": "string", "candidate_id": "string",
    "working_directory": "absolute root", "base_snapshot_ref": "string",
    "artifact_ref": {}, "acceptance_ref": "string", "harness_ref": "string",
    "tested_identity": "string",
    "runs": [{"command": "string", "exit_code": 0, "result": "string"}],
    "untested_limits": ["string"]
  }]
}
```

## Operational role: prepare_worktrees

1. Inspect dirty status and record the staged/unstaged/untracked baseline. Preserve unrelated user changes. Never stash/reset/commit user work.
2. Freeze the same full `base_commit` and content-addressed `base_snapshot_ref` for both. Relevant dirty prerequisites require user approval and identical snapshots in both roots; unresolved approval/preservation prerequisites block.
3. Provision two distinct IDs/agent names and absolute isolated worktree roots from the frozen base. Return group/round, own-root mappings, frozen requirements/acceptance/tests/budget/limits, dirty baseline and explicit `owned_paths` in `preparation_result`.
4. Finish before either candidate starts. Do not implement. TeamLead dispatches fresh candidate contexts containing only the candidate's opaque owned root/identity, identical acceptance criteria, commands, limits and implementation handoff.

## Developer role: implement

1. Advice/research may run directly. Before production/unit-TDD edits, require TeamLead's explicit single decision/reason or complete paired envelope. Otherwise request the decision/route back to TeamLead without edits or child delegation.
2. In paired mode verify own identity/root and frozen base/snapshot digests before editing. Do not change the frozen requirements, acceptance, tests, budget or limits.
3. Treat assigned `execution_context.working_directory` as repository root for EVERY command/read/edit/search. Worktrees are NOT OS/security sandboxes: instruction-level ban on peer branch/worktree/patch reads, listing peer roots and outside-root access/search, except explicit shared readonly requirements/base artifacts.
4. No peer metadata, solution hints, summaries, findings, status, progress logs or shared progress files until BOTH outputs seal, even during serial execution. Keep evidence in the owned root. If contaminated, stop and return contamination evidence for a new paired round.
5. Own production code and unit/TDD, following the assigned developer's specialization unchanged. `test-engineer` owns independent verification and test/fixture-only changes; `performance-engineer` owns planned measurement and retests measured fixes. No assertion weakening or overlapping test edits; use `conflicts_with` or separate roots.
6. Never commit/push/merge or modify the original shared checkout to expose results. Record commands/exit codes, results, rationale and limits; seal successful OR unsuccessful output using the interfaces above.
7. After sealing make no edits. Return blockers/next owner to TeamLead; no self-approval, nested delegation or outbound sends. Honor `outbound_communication_policy.mode: request_only`.

## Test role: independent verification

1. Require BOTH sealed candidate targets and shared frozen acceptance/tests/commands. Missing/unsealed identity blocks; never infer code from a claimed commit.
2. Verify BOTH candidates independently, including a candidate with a sealed failure. In each assigned root validate base/snapshot and patch/snapshot manifest SHA-256 before/after runs; bind each command/exit/result to exact group/round/candidate/base/artifact/acceptance identity.
3. Candidate unit/TDD additions remain separately sealed; they do not replace the common suite. Test/fixture or temporary harness changes require ONE consistent `harness_ref`, provenance/digest and composed tested identities for both. Never weaken assertions to select a winner; acceptance changes require a new frozen paired round.
4. No first-run findings reach the other candidate before BOTH seals. No candidate repairs. Report each separately, distinguishing conclusive failure from unavailable/unexecuted checks and stating untested limits.
5. Use `conflicts_with` for waiting/shared fixtures, ports, services and noisy resources even across worktrees; do not contaminate serialized measurements.
6. After exact winner integration, retest actual integrated identity plus approved common tests ONCE. Production remediation returns to TeamLead, never a hidden verifier fix.

## Performance role: conditional measurements

1. Measure only when acceptance or a justified risk requires it, after BOTH seals. Receive both candidate targets, equal frozen budgets/tests/limits and exact artifacts.
2. Use the same baseline/workload/environment/commands and requirements or explicitly agreed-assumption budgets. No arbitrary thresholds, invented gains or unauthorized live/prod load.
3. Validate manifest digests before/after in assigned roots; bind results to group/round/candidate/base/artifact/acceptance/harness and exact tested identity. Harness changes must be consistent/provenanced for both.
4. Serialize noisy measurements with `conflicts_with` against ALL competing builds/tests/load on shared CPU, memory, disk and network, even across worktrees. Include waiting/shared services, ports and fixtures. Worktrees are not noise isolation.
5. Required unavailable measurements block; state unmeasured limits. Retest measured fixes on actual integrated identity; revisions invalidate affected evidence. Route substantive .NET fixes to TeamLead for a paired round.

## TeamLead role: compare, select and remediate

- Compare specialist evidence only: correctness, contracts and user product constraints FIRST, then simplicity, maintainability and measured metrics. Delegate unresolved technical judgments or block.
- No votes, personality preferences or presumed model/runtime diversity. Models are user-configurable; a different agent name is not diversity. Report only diversity actually tested.
- Neither qualifies -> diagnosis/replan and new PAIRED round or block; no silent hybrid or solo repair.
- Substantive changes invalidate evidence and require a new paired round with equal frozen inputs, fresh contexts/seals and retests.
- Only explicitly TeamLead-approved trivial mechanical nonsemantic fixes (format/comment-only; NO behavior, contract, test, dependency, build or eligibility change) may avoid a new pair. Still reseal, retest/review affected evidence and reconfirm selection.
- Record `selection_record` with group/round, selected/rejected identities, selected artifact, evidence refs and reasons. Required missing/blocked/failed/skipped checks block selection/release absent an explicit authorized waiver. Record waivers; never label them passes. This does not make an unsealed output comparable or a failing candidate eligible.
- A conclusively failing loser does not block a verified passing winner; required independent verification still runs in BOTH roots. Distinguish losing-candidate failure from missing verification or failed winner/integrated eligibility checks.

## Operational role: integrate_selected

1. Require BOTH seals, completed independent comparison, `selection_record` and winner evidence. Run in a fresh operational context, not either candidate's implementation context.
2. Recheck the shared dirty baseline, winner manifest and hashes. Foreign drift/conflicts block; never overwrite user work.
3. Apply EXACTLY ONE selected patch/snapshot plus approved common tests ONCE. No assumed cherry-pick/candidate commit, forced commit, mixed partial solutions or duplicate accepted tests from both.
4. Return actual `integrated_artifact_ref`, preservation evidence, retained paths/blockers in `integration_result` for retest and gates. Any revision invalidates affected evidence.

## Review, release and documentation roles

- Load only for divergence input. Artifact review/release/documentation handoffs require completed independent comparison/selection after BOTH seals. Use selected/integrated evidence, not losing-candidate claims, stale verification or assumed candidate commits.
- Plan-scope security review stays before implementation under its existing complexity gate; it reviews the plan, not candidate artifacts. It does NOT wait for seals/selection. Post-selection artifact prerequisites apply to wave/artifact review, not plan validation.
- Apply existing security, C#/NuGet and verified-deployment activation/approval gates unchanged to selected/integrated accumulated changes. Do not force deployment review from generic extensions or require two extra candidate reviews.
- Bind specialist retests and review findings to the SAME actual integrated artifact/root/revision; reject stale evidence after edits. `code-quality-engineer` may provide source-grounded simplicity/maintainability analysis after BOTH seals, not votes or self-selected fixes.
- Reviewers return findings/remediation to TeamLead, never silently patch production or bypass paired remediation. A nontrivial .NET simplification is not a solo `code-quality-engineer` implementation.
- Release requires winner `artifact_ref` mapped through `selection_record` to actual `integrated_artifact_ref`/release revision, with independent tests, applicable measurements and reviews. Comparison patches are not release artifacts; normal committed/approved artifact rules and step approvals still apply.
- Release/docs consume only applicable winner/integrated evidence; no untested model/runtime-diversity claims or pre-seal peer hints. Documentation uses the assigned root and returns discrepancies to TeamLead.
- Required missing/blocked/failed/skipped validation blocks absent an explicit authorized waiver; a report-only note or accepted-risk prose is not authorization. Retain role boundaries, capability preconditions and communication approvals.

## Operational role: cleanup_worktrees

- Delegate only after integration and needed diagnostics. Remove ONLY explicit owned candidate paths, never repository roots, foreign changes or broad directory trees.
- Preserve failure evidence, including worktrees still needed for diagnostics. Return retained paths, blockers and next owner; no automatic cleanup by candidates.
