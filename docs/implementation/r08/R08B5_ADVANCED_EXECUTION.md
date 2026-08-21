# R08B.5 Advanced Execution and Grouped Sets

## Scope

R08B.5 makes the execution semantics already owned by canonical B02 usable in
the compact Planned/Quick player. It adds presentation and typed mutation
plumbing only. B02 remains the authority for validation, persistence shape,
progression state, group membership, and replacement policy.

The common path remains the B.2 table:

`load → reps → log`

Uncommon controls are disclosed from the existing “More for this set” section.
The player does not create a second execution surface for advanced sets.

## Canonical inventory

| Canonical concept | Persistence representation | Controller/read representation | Pre-B.5 exposure | R08B.5 presentation |
| --- | --- | --- | --- | --- |
| Set role | `PerformedSets.role`; `B02PerformedSet.role` | `recordSet(role: B02SetRole)` and performed-set draft | B.2 warm-up toggle and row status | Keeps `Warm-up set` and `Working set` distinct in the compact table, editor, progress, and persisted rows. |
| Warm-up recommendation | `B02ExecutionDraftState.warmupRecommendation` and accepted warm-up `PerformedSets` rows | Existing warm-up decision/edit service and controller | Warm-up card existed in the expanded set controls | Keeps recommendation, accepted, edited, and skipped states separate from working-set targets. No warm-up history or inferred target is added. |
| Effort intent | `StrengthSetPrescriptions.effortMode`; performed-set technique JSON/columns; `B02TechniqueFields.effortMode` | `B02TechniqueFields` passed through record/edit | Stored and used by B02, but not editable from the compact player | Advanced disclosure uses `Standard set`, `As many good reps as possible`, and `To failure`. |
| Ended at failure | `PerformedSets.endedAtFailure`; draft technique JSON while the session is active | `B02TechniqueFields.endedAtFailure` | Stored, but not consumer-visible in the execution row | Advanced disclosure exposes `Reached failure`; it never infers failure from RPE or reps. |
| RPE | Nullable target/actual RPE columns and `B02PerformedSet.targetRpe`/`actualRpe` | B.2 input plus typed record/edit mutation | B.2 already exposed the optional factual input | Keeps RPE optional/required as defined by B02, supports truthful edit, and adds one short practical explanation. No recommendation or inference. |
| Tempo | Four persisted tempo components and `B02TechniqueFields` | Typed technique on set record/edit; frozen set prescription read model | Persisted by B02 but not shown in the player | Advanced disclosure edits all four components together and summarizes them compactly. |
| Paused reps | Position and duration columns/technique JSON | `B02PausedRepPosition` and seconds on `B02TechniqueFields` | Persisted but not shown in the player | Advanced disclosure uses consumer-facing position labels and duration. |
| Assistance/load basis | Assistance mode/load columns plus `B02LoadBasis` on targets and actuals | Typed `B02TechniqueFields` and B.2 load-basis display | Load basis was shown; assistance was not | Keeps assistance separate from external load and exposes only canonical modes and units. |
| Drop-set segments | `PerformedSetSegments`; typed intent and ordered segment JSON in the active draft | `B02TechniqueFields.segments`; draft service validates the header/segment relationship | Preserved by persistence but not editable from execution | Advanced disclosure exposes ordered segment reps/load/basis/assistance and keeps one set slot, as B02 defines. |
| Rest-pause segments | `PerformedSetSegments`; typed intent and ordered segment JSON in the active draft | Same typed technique path; positive rest-before validation | Preserved by persistence but not editable from execution | Advanced disclosure exposes ordered clusters and rest-before values. Rest timer presentation remains B.6. |
| Group type | `ExerciseGroups.groupType` and group members | `B02ExerciseGroup`, slot `groupId/groupType/roundOrdinal/memberOrdinal` | Read into slots; player showed only limited context | Consumer labels are `Superset`, `Circuit`, and `Giant set`, only for canonical group types. |
| Group membership/order | `ExerciseGroups`, `ExerciseGroupMembers`, canonical draft current group/round/member fields, performed group fields | `B02GroupExecutionIntegrity` and exact slot identity | Group headers/progress were sparse | Group progress derives member/round order from persisted graph and exact slot fields; adjacency is never treated as grouping. |
| Execution progression | Draft current group/round/member and controller/service mutation state | `B02StrengthExecutionSlot.id` plus canonical group/round/member fields | Controller already mutated canonical state; player did not explain it fully | Current and next member/round are presented from authoritative state. Contradictions fail closed. |

### Classification

**Supported and exposed by B.5:** warm-up/working roles, standard/AMRAP/to-
failure effort, reached-failure fact, optional RPE, four-part tempo, paused
reps, assistance, load basis, drop-set segments, rest-pause segments, and
canonical superset/circuit/giant-set group membership/order.

**Supported but previously poorly exposed:** frozen per-set prescriptions,
advanced technique editing from execution, segment details, group member and
round progress, and the distinction between prescribed advanced details and
actual logged details.

**Internal-only:** UUIDs and prescription/set/group IDs, database enum values,
draft schema versions, controller/repository names, allocation identifiers,
failure/recovery reason codes, and raw exception text. These remain available
to the typed domain and diagnostics but never appear in consumer copy.

**Not supported by the inspected B02 authority:** RIR, readiness scoring,
progression recommendations, automatic RPE/load assignment, e1RM, PR logic,
calorie estimates, or any additional technique/scheduling policy. B.5 also
does not add new meanings for tempo, pause, failure, or group types.

## Presentation and mutation boundaries

### Advanced disclosure

`B02ExecutionAdvancedControls` is mounted inside the B.2 “More for this set”
disclosure. Ordinary rows continue to show only compact target/actual values;
advanced summaries appear only when a canonical technique contains advanced
details. The control reuses `B02TechniqueEditor`, but the player owns the
pending value and passes the typed result through the execution controller.

The draft service validates the technique again before record/edit mutation.
For segment sets, the actual header reps must equal the ordered segment-rep
sum. Existing stable set IDs remain the edit/delete identity.

`B02ExecutionSemantics` contains only consumer-facing labels, compact summaries,
canonical group-round ordering, and a conservative group-integrity check. It
does not decide whether a set or replacement is valid.

### Planned execution

The occurrence snapshot now freezes each canonical strength set prescription,
including its typed technique payload. The repository exposes those immutable,
ordinal-addressed prescriptions through the execution slot read model. Planned
rows therefore show the prescription attached to their actual set ordinal and
retain the planned occurrence, slot, group, round, and member identity.

Replacing a planned exercise continues through the existing B.02/B.04
authority. The execution draft keeps group identity/order and the planned
occurrence; B.5 does not create a Quick session or reattribute logged sets.

### Quick execution

Quick slots continue to be ad-hoc, ungrouped slots unless the canonical Quick
input already supplies an explicit group graph. B.5 does not fabricate planned
prescriptions, group rounds, or substitution restrictions for Quick. The same
typed advanced editor can be reused where Quick semantics already allow the
field, and the draft remains the one active session/draft.

### B.3 and B.4 compatibility

Previous-performance requests now retain exact current role, effort/failure,
assistance, tempo, paused-rep, and segment context. B.3 still decides evidence
eligibility; prior RPE remains a historical fact and is never promoted to a
target or recommendation. Group membership is not used as performance
equivalence.

Replacement remains owned by the canonical B.02 substitution authority and the
existing B.4 replacement flow. B.5 does not derive compatibility from muscle,
equipment, names, movement families, or group membership.

### Failure and recovery

Malformed frozen set-prescription data, non-contiguous set ordinals, missing
group members, or contradictory slot/group identity produce the existing
consumer-safe unavailable/recovery state. The player does not flatten a broken
group into independent exercises and does not guess the next member.

### B.6 boundary

B.5 preserves the existing canonical rest trigger and rest fields. It does not
redesign the timer, add ± controls, implement skip/edit rest, or add wakelock.
B.6 can consume the existing group transition/round/rest scope and the exact
current-member progression state when it owns that presentation.

## Files

The reusable presentation primitives are:

- `lib/features/workout_player/widgets/b02_execution_advanced_controls.dart`
- `lib/features/workout_player/widgets/b02_execution_semantics.dart`

The compact table/player, typed controller/service, frozen snapshot reader,
and shared technique editor were extended without changing the B.2 player
hotspot boundary or B.02 policy.

Focused coverage is in `test/r08b5_advanced_execution_test.dart`; existing B.02,
B.1, B.2, B.3, B.4, and B.234 tests remain the regression authority for their
respective boundaries.
