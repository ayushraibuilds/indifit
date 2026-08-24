# R08C.4 Plan Builder / Program Authoring

Status: implemented and correctness-reviewed.

## Authority inventory

The builder is a presentation and draft-editing surface over the existing B01
program repository. It does not activate a plan or create occurrences.

| Canonical concept | Persisted representation | C.4 exposure |
| --- | --- | --- |
| Plan identity and notes | `Programs.name` and nullable `Programs.notes` | Plan name and description fields |
| Version lifecycle | `ProgramVersions.status` and existing version repository methods | Drafts are editable; published/started versions offer an editable-copy path |
| Ordered structure | Blocks, weeks, and session templates with ordinals | Add, rename, delete, and review block/week/workout structure |
| Planned day/time | Session-template weekday and optional start minute | Workout day selector and optional start time |
| Exercise prescription | Stable exercise UUID, name snapshot, ordinal, planned sets, reps text | Shared exercise picker, exact-ID exercise rows, set/rep editing, exercise reorder |
| Grouped exercise prescription | B02 group type, group ordinal, round count, round rest, label, ordered member rows, optional member-transition rest | Superset, Circuit, and Giant Set creation/editing, exact member ordering, group reorder, and optional per-member transition rest |
| Graph validation | `ProgramRepository._validateGraph` and `B02GroupPlanValidator` | Save/review is blocked by consumer-facing validation errors |
| Activation/freeze | `ProgramActivationCoordinator` | Existing review screen remains the only activation entry point |

The current B01 program schema does not persist B02 execution-technique fields
such as RPE, tempo, pauses, failure, drop/rest-pause, or other technique
metadata. The builder therefore does not expose those controls or invent a
second prescription schema. Execution-time semantics remain owned by B02.

Legacy/import prescriptions with no resolvable exercise UUID may be preserved
only through the repository's explicit unresolved-compatibility path. New
authoring requires a selection from the shared picker.

## Authoring flow

`ProgramAuthorScreen` keeps a typed in-memory graph while the user edits. It
uses `ExercisePickerSelection.exerciseId` as the prescription identity and
keeps display names as snapshots only. Exercise rows can be edited, deleted
when not referenced by a group, and moved without changing their stable row
IDs. Group editing keeps the group ID and preserves member IDs for members
that remain in the group.

`ProgramRepository.saveDraft` validates the complete graph before replacing
the draft graph and updates plan metadata plus graph rows in one database
transaction. A failed save leaves the prior durable graph and metadata intact;
the UI retains the in-memory draft and offers a retry through the same save
operation.

The review screen remains a pre-activation confirmation surface. Its primary
action calls the existing `ProgramActivationCoordinator`, which owns
validation, version publication, occurrence materialization, and frozen
occurrence behavior.

## Frozen-occurrence safety

Published or otherwise in-use versions are not edited in place. The builder
disables draft mutation and offers `copyToNewDraftVersion`. The copied graph
gets new child row identities, while the source graph and its already-frozen
occurrences remain unchanged. The canonical `Programs` metadata is shared by
versions in the current schema; C.4 does not invent per-version naming
semantics. Graph and occurrence isolation is preserved.

## Integration hook

No Training landing changes are required. The existing C.1 builder entry point
uses:

```dart
context.push('/program-author');
```

The C.3 Plan Library batch can open an existing version with:

```dart
context.push(
  Uri(
    path: '/program-author',
    queryParameters: {'versionId': entry.version.id},
  ).toString(),
);
```

After save, the builder opens `/program-review/<versionId>`. Plan Library
continues to own copy/use entry decisions; C.4 only consumes the version ID.

## Product and accessibility boundaries

The UI uses consumer labels for group types and validation, avoids UUIDs,
repository/controller terminology, and keeps advanced group controls behind
the group-actions menu. The editor is scrollable, constrained on wide layouts,
keyboard-safe, and uses labelled controls/tooltips for exercise and group
actions. Existing B4 picker search/filter and exact-ID behavior are reused
without changing Exercise Library semantics.

## Focused coverage

`test/r08c4_plan_builder_test.dart` covers create/reopen/edit, exact exercise
identity and ordering, validation-before-replacement, transactional rollback
after a persistence failure, grouped member identity and ordering,
frozen-version copy isolation, retained edits after a failed save, and the
shared picker entry point. Existing B01 repository/widget and B4 picker tests
cover the adjacent canonical persistence and picker behavior.
