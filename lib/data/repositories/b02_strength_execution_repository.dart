import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/fixtures/b02_execution_draft_codec.dart';
import '../../core/fixtures/equipment_fixtures.dart';
import '../../core/fixtures/workout_draft_codec.dart';
import '../database/app_database.dart';
import '../models/b02_execution_models.dart';
import '../services/b02_workout_preparation_orchestrator.dart';
import 'b02_target_recommendation_repository.dart';
import 'calendar_repository.dart';
import 'equipment_preference_repository.dart';

class B02StrengthExecutionException implements Exception {
  final String message;

  const B02StrengthExecutionException(this.message);

  @override
  String toString() => 'B02StrengthExecutionException: $message';
}

class B02StrengthExecutionRecoveryException
    extends B02StrengthExecutionException {
  const B02StrengthExecutionRecoveryException(super.message);
}

class B02StrengthExecutionFinalizationException
    extends B02StrengthExecutionException {
  const B02StrengthExecutionFinalizationException(super.message);
}

/// Canonical B02 launch data. The draft is the mutable execution authority;
/// [executionSnapshotJson] is the immutable occurrence/program provenance.
class B02StrengthExecutionLaunch {
  final int draftId;
  final String? occurrenceId;
  final String executionSnapshotJson;
  final B02ExecutionDraftState state;

  const B02StrengthExecutionLaunch({
    required this.draftId,
    required this.occurrenceId,
    required this.executionSnapshotJson,
    required this.state,
  });

  B02StrengthExecutionLaunch copyWith({B02ExecutionDraftState? state}) {
    return B02StrengthExecutionLaunch(
      draftId: draftId,
      occurrenceId: occurrenceId,
      executionSnapshotJson: executionSnapshotJson,
      state: state ?? this.state,
    );
  }
}

/// Read-only coverage result used before a calendar route leaves the retained
/// B01 bridge. A false result is an explicit lack of canonical metadata, not
/// a mutation or an inferred modality.
class B02StrengthExecutionCoverage {
  final bool supported;
  final String? reason;

  const B02StrengthExecutionCoverage({required this.supported, this.reason});
}

/// Durable owner for B02 strength drafts and canonical performed records.
/// CalendarRepository remains the only owner of occurrence status/events.
class StrengthExecutionRepository {
  final AppDatabase _db;
  final CalendarRepository _calendarRepo;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;
  final EquipmentProfileRepository _equipmentRepo;
  final ExercisePreferenceRepository _preferenceRepo;
  final B02WorkoutPreparationOrchestrator _preparation;

  StrengthExecutionRepository({
    required AppDatabase db,
    required CalendarRepository calendarRepo,
    Uuid? uuid,
    DateTime Function()? nowUtc,
    EquipmentProfileRepository? equipmentRepo,
    ExercisePreferenceRepository? preferenceRepo,
    B02WorkoutPreparationOrchestrator? preparation,
  }) : _db = db,
       _calendarRepo = calendarRepo,
       _uuid = uuid ?? const Uuid(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _equipmentRepo = equipmentRepo ?? EquipmentProfileRepository(db),
       _preferenceRepo = preferenceRepo ?? ExercisePreferenceRepository(db),
       _preparation =
           preparation ??
           B02WorkoutPreparationOrchestrator(
             evidenceRepository: B02TargetEvidenceRepository(db),
             nowUtc: nowUtc,
           );

  Future<B02StrengthExecutionCoverage> checkScheduledCoverage(
    String occurrenceId,
  ) async {
    final occurrence = await _calendarRepo.getOccurrence(occurrenceId);
    if (occurrence == null) {
      return const B02StrengthExecutionCoverage(
        supported: false,
        reason: 'Scheduled occurrence was not found.',
      );
    }
    final template =
        await (_db.select(_db.sessionTemplates)
              ..where((table) => table.id.equals(occurrence.sessionTemplateId)))
            .getSingleOrNull();
    if (template == null) {
      return const B02StrengthExecutionCoverage(
        supported: false,
        reason: 'Strength template ancestry is missing.',
      );
    }
    if (template.activityType != B02ActivityType.strength.dbValue) {
      return B02StrengthExecutionCoverage(
        supported: false,
        reason:
            'Template activity type ${template.activityType} is not strength.',
      );
    }
    final prescriptions = await (_db.select(
      _db.exercisePrescriptions,
    )..where((table) => table.sessionTemplateId.equals(template.id))).get();
    if (prescriptions.isEmpty) {
      return const B02StrengthExecutionCoverage(
        supported: false,
        reason: 'Strength template has no prescriptions.',
      );
    }
    final stableIds = <String>{};
    for (final prescription in prescriptions) {
      final exerciseId = prescription.exerciseId;
      if (exerciseId == null || exerciseId.trim().isEmpty) {
        return const B02StrengthExecutionCoverage(
          supported: false,
          reason: 'One or more prescriptions have no canonical exercise ID.',
        );
      }
      stableIds.add(exerciseId);
    }
    final resolved = await (_db.select(
      _db.exercises,
    )..where((table) => table.stableId.isIn(stableIds))).get();
    if (resolved.length != stableIds.length) {
      return const B02StrengthExecutionCoverage(
        supported: false,
        reason: 'A prescription references a missing canonical exercise.',
      );
    }
    return const B02StrengthExecutionCoverage(supported: true);
  }

  Future<B02StrengthExecutionLaunch> startScheduledOccurrence({
    required String occurrenceId,
    required String commandId,
    bool confirmedOutsideEffectiveDate = false,
  }) async {
    final occurrence = await _calendarRepo.getOccurrence(occurrenceId);
    if (occurrence == null) {
      throw const B02StrengthExecutionException(
        'Scheduled occurrence was not found.',
      );
    }
    await _requireStrengthTemplate(occurrence.sessionTemplateId);

    // The outer transaction makes CalendarRepository's start and the v2 draft
    // upgrade one atomic operation. A failed upgrade cannot leave a started
    // occurrence with a legacy-shaped draft.
    return _db.transaction(() async {
      final started = await _calendarRepo.start(
        StartOccurrenceCommand(
          occurrenceId: occurrenceId,
          commandId: commandId,
          expectedStatus: _parseOccurrenceStatus(occurrence.status),
          confirmedOutsideEffectiveDate: confirmedOutsideEffectiveDate,
        ),
      );
      final snapshot = started.occurrence.executionSnapshotJson;
      if (snapshot == null) {
        throw const B02StrengthExecutionRecoveryException(
          'Started occurrence has no frozen execution snapshot.',
        );
      }
      return _upgradeOrReadScheduledDraft(
        occurrenceId: occurrenceId,
        snapshotJson: snapshot,
      );
    });
  }

  Future<B02StrengthExecutionLaunch> resumeScheduledOccurrence(
    String occurrenceId,
  ) async {
    final occurrence = await _calendarRepo.getOccurrence(occurrenceId);
    if (occurrence == null) {
      throw const B02StrengthExecutionRecoveryException(
        'Scheduled occurrence was not found.',
      );
    }
    if (occurrence.status != OccurrenceStatus.inProgress.dbValue) {
      throw const B02StrengthExecutionRecoveryException(
        'Only an in-progress occurrence can resume a B02 draft.',
      );
    }
    final draft =
        await (_db.select(_db.workoutDrafts)..where(
              (table) => table.scheduledOccurrenceId.equals(occurrenceId),
            ))
            .getSingleOrNull();
    if (draft == null) {
      throw const B02StrengthExecutionRecoveryException(
        'The linked workout draft is missing; recover or discard explicitly.',
      );
    }
    return _readCanonicalDraft(
      draft: draft,
      expectedSnapshotJson: occurrence.executionSnapshotJson,
      occurrenceId: occurrenceId,
    );
  }

  /// Creates an unscheduled canonical strength draft. The caller supplies the
  /// already-frozen snapshot and explicit group graph; no names are resolved
  /// here and no legacy WorkoutSets row is written.
  Future<B02StrengthExecutionLaunch> startUnscheduledDraft({
    required String routineName,
    required String executionSnapshotJson,
    Iterable<B02ExerciseGroup> groups = const [],
    String? snapshotId,
    DateTime? nowUtc,
  }) async {
    final cleanName = _requiredText(routineName, 'Routine name');
    final snapshot = _decodeSnapshot(executionSnapshotJson);
    final snapshotVersion = _snapshotVersion(snapshot);
    final validatedGroups = groups.toList(growable: false);
    _validateGroupOrdinals(validatedGroups);
    final id = snapshotId?.trim().isNotEmpty == true
        ? snapshotId!.trim()
        : _uuid.v4();
    final now = (nowUtc ?? _nowUtc()).toUtc();

    return _db.transaction(() async {
      await _requireNoActiveDraft();
      final draftId = await _db
          .into(_db.workoutDrafts)
          .insert(
            WorkoutDraftsCompanion.insert(
              routineName: cleanName,
              currentExerciseIndex: 0,
              currentSetIndex: 0,
              elapsedSeconds: 0,
              loggedSetsJson: WorkoutDraftCodec.encode(
                routineName: cleanName,
                currentExerciseIndex: 0,
                currentSetIndex: 0,
                elapsedSeconds: 0,
                loggedSets: const [],
              ),
              updatedAt: Value(now),
              executionSnapshotJson: Value(executionSnapshotJson),
              draftSchemaVersion: const Value(
                B02ExecutionDraftState.schemaVersion,
              ),
              activityType: Value(B02ActivityType.strength.dbValue),
              executionStateJson: Value(
                B02ExecutionDraftCodec.encode(
                  B02ExecutionDraftState(
                    snapshotId: id,
                    snapshotVersion: snapshotVersion,
                    activityType: B02ActivityType.strength,
                    routineName: cleanName,
                    elapsedSeconds: 0,
                    currentExerciseOrdinal: 0,
                    currentSetOrdinal: 0,
                    groups: validatedGroups,
                  ),
                ),
              ),
            ),
          );
      final row = await (_db.select(
        _db.workoutDrafts,
      )..where((table) => table.id.equals(draftId))).getSingle();
      return _readCanonicalDraft(
        draft: row,
        expectedSnapshotJson: executionSnapshotJson,
        occurrenceId: null,
      );
    });
  }

  Future<B02StrengthExecutionLaunch> readDraft(int draftId) async {
    final draft = await (_db.select(
      _db.workoutDrafts,
    )..where((table) => table.id.equals(draftId))).getSingleOrNull();
    if (draft == null) {
      throw const B02StrengthExecutionRecoveryException(
        'The B02 draft was not found.',
      );
    }
    ScheduledSessionOccurrence? occurrence;
    if (draft.scheduledOccurrenceId != null) {
      occurrence = await _calendarRepo.getOccurrence(
        draft.scheduledOccurrenceId!,
      );
      if (occurrence == null) {
        throw const B02StrengthExecutionRecoveryException(
          'The draft occurrence ancestry is missing.',
        );
      }
    }
    return _readCanonicalDraft(
      draft: draft,
      // Unscheduled drafts have no calendar occurrence; their own immutable
      // snapshot is still the recovery authority.
      expectedSnapshotJson:
          occurrence?.executionSnapshotJson ?? draft.executionSnapshotJson,
      occurrenceId: draft.scheduledOccurrenceId,
    );
  }

  /// Resolves the frozen group graph to canonical prescription/exercise
  /// metadata for the player. This is deliberately a repository read: the UI
  /// must never infer stable IDs or modality from a display name.
  Future<List<B02StrengthExecutionSlot>> readExecutionSlots(
    B02StrengthExecutionLaunch launch,
  ) async {
    final snapshot = _decodeSnapshot(launch.executionSnapshotJson);
    final snapshotPrescriptions = <String, Map<String, dynamic>>{
      for (final raw
          in (snapshot['prescriptions'] is List
              ? snapshot['prescriptions'] as List
              : const <dynamic>[]))
        if (raw is Map && raw['id'] is String)
          raw['id'] as String: Map<String, dynamic>.from(raw),
    };
    final prescriptionIds = launch.state.groups
        .expand((group) => group.members)
        .map((member) => member.exercisePrescriptionId)
        .toSet();
    final allPrescriptionIds = {
      ...prescriptionIds,
      ...snapshotPrescriptions.keys,
    };
    if (allPrescriptionIds.isEmpty) return const [];

    final prescriptions = await (_db.select(
      _db.exercisePrescriptions,
    )..where((table) => table.id.isIn(allPrescriptionIds))).get();
    final prescriptionById = {
      for (final prescription in prescriptions) prescription.id: prescription,
    };
    final stableIds = {
      ...prescriptions
          .map((prescription) => prescription.exerciseId)
          .whereType<String>()
          .where((id) => id.trim().isNotEmpty),
      ...snapshotPrescriptions.values
          .map((raw) => raw['exerciseId'])
          .whereType<String>()
          .where((id) => id.trim().isNotEmpty),
    };
    final exercises = stableIds.isEmpty
        ? const <Exercise>[]
        : await (_db.select(
            _db.exercises,
          )..where((table) => table.stableId.isIn(stableIds))).get();
    final resolvedStableIds = exercises
        .map((exercise) => exercise.stableId)
        .whereType<String>()
        .toSet();

    final strengthRows = allPrescriptionIds.isEmpty
        ? const <StrengthSetPrescription>[]
        : await (_db.select(_db.strengthSetPrescriptions)
                ..where(
                  (table) =>
                      table.exercisePrescriptionId.isIn(allPrescriptionIds),
                )
                ..orderBy([(table) => OrderingTerm(expression: table.ordinal)]))
              .get();
    final strengthByPrescription = <String, List<StrengthSetPrescription>>{};
    for (final row in strengthRows) {
      (strengthByPrescription[row.exercisePrescriptionId] ??= []).add(row);
    }
    final templateId = _snapshotObject(snapshot['template'])['id'];
    final template = templateId is String
        ? await (_db.select(
            _db.sessionTemplates,
          )..where((table) => table.id.equals(templateId))).getSingleOrNull()
        : null;
    final week = _snapshotObject(snapshot['week']);
    final equipmentContext = _snapshotObject(snapshot['equipmentProfile']);
    final profileId = equipmentContext['equipmentProfileId'];
    final profile = profileId is String
        ? await _equipmentRepo.getProfile(profileId)
        : null;

    final slots = <B02StrengthExecutionSlot>[];
    for (final group in launch.state.groups) {
      for (var round = 0; round < group.roundCount; round++) {
        for (final member in group.members) {
          final prescription = prescriptionById[member.exercisePrescriptionId];
          final raw = snapshotPrescriptions[member.exercisePrescriptionId];
          final name =
              prescription?.exerciseNameSnapshot ??
              raw?['exerciseNameSnapshot'] as String?;
          final repsRange =
              prescription?.repsRange ?? raw?['repsRange'] as String?;
          final plannedSets =
              prescription?.plannedSets ?? raw?['plannedSets'] as int?;
          final exerciseId =
              prescription?.exerciseId ?? raw?['exerciseId'] as String?;
          if (name == null || repsRange == null || plannedSets == null) {
            continue;
          }
          final reps = _parseRepsRange(repsRange);
          final slot = await _buildSlot(
            id: '${group.id}:$round:${member.ordinal}',
            group: group,
            member: member,
            roundOrdinal: round,
            prescription: prescription,
            raw: raw,
            name: name,
            reps: reps,
            plannedSets: plannedSets,
            exerciseId:
                exerciseId != null && resolvedStableIds.contains(exerciseId)
                ? exerciseId
                : null,
            exercise: exercises.cast<Exercise?>().firstWhere(
              (value) => value?.stableId == exerciseId,
              orElse: () => null,
            ),
            strengthRows:
                strengthByPrescription[member.exercisePrescriptionId] ??
                const [],
            templateDefaultRestSeconds:
                template?.defaultRestSeconds ??
                _rawInt(snapshot['templateDefaultRestSeconds']),
            isDeloadWeek: week['isDeload'] == true,
            profile: profile,
          );
          if (slot != null) slots.add(slot);
        }
      }
    }
    final groupedPrescriptionIds = launch.state.groups
        .expand((group) => group.members)
        .map((member) => member.exercisePrescriptionId)
        .toSet();
    for (final entry in snapshotPrescriptions.entries) {
      if (groupedPrescriptionIds.contains(entry.key)) continue;
      final prescription = prescriptionById[entry.key];
      final raw = entry.value;
      final name =
          prescription?.exerciseNameSnapshot ??
          raw['exerciseNameSnapshot'] as String?;
      final repsRange = prescription?.repsRange ?? raw['repsRange'] as String?;
      final plannedSets =
          prescription?.plannedSets ?? raw['plannedSets'] as int?;
      final exerciseId =
          prescription?.exerciseId ?? raw['exerciseId'] as String?;
      if (name == null || repsRange == null || plannedSets == null) continue;
      final reps = _parseRepsRange(repsRange);
      final slot = await _buildSlot(
        id: 'standalone:${entry.key}',
        group: null,
        member: null,
        roundOrdinal: null,
        prescription: prescription,
        raw: raw,
        name: name,
        reps: reps,
        plannedSets: plannedSets,
        exerciseId: exerciseId != null && resolvedStableIds.contains(exerciseId)
            ? exerciseId
            : null,
        exercise: exercises.cast<Exercise?>().firstWhere(
          (value) => value?.stableId == exerciseId,
          orElse: () => null,
        ),
        strengthRows: strengthByPrescription[entry.key] ?? const [],
        templateDefaultRestSeconds:
            template?.defaultRestSeconds ??
            _rawInt(snapshot['templateDefaultRestSeconds']),
        isDeloadWeek: week['isDeload'] == true,
        profile: profile,
      );
      if (slot != null) slots.add(slot);
    }
    return slots;
  }

  /// Prepares the frozen draft once and returns the player-ready slot read
  /// model. Offers are keyed by slot identity, so retries/resume reuse the
  /// exact same evidence and recommendation instead of issuing a second one.
  Future<B02WorkoutPreparationResult> prepareExecution(
    B02StrengthExecutionLaunch launch,
  ) async {
    final slots = await readExecutionSlots(launch);
    final occurrence = launch.occurrenceId == null
        ? null
        : await _calendarRepo.getOccurrence(launch.occurrenceId!);
    final result = await _preparation.prepare(
      state: launch.state,
      slots: slots,
      executionTimezoneId: occurrence?.effectiveTimezoneId,
    );
    if (result.changed) {
      await saveDraft(draftId: launch.draftId, state: result.state);
    }
    return result;
  }

  Future<B02StrengthExecutionSlot?> _buildSlot({
    required String id,
    required B02ExerciseGroup? group,
    required B02ExerciseGroupMember? member,
    required int? roundOrdinal,
    required ExercisePrescription? prescription,
    required Map<String, dynamic>? raw,
    required String name,
    required (int?, int?) reps,
    required int plannedSets,
    required String? exerciseId,
    required Exercise? exercise,
    required List<StrengthSetPrescription> strengthRows,
    required int? templateDefaultRestSeconds,
    required bool isDeloadWeek,
    required EquipmentProfileAggregate? profile,
  }) async {
    final strength = strengthRows.isEmpty ? null : strengthRows.first;
    final preference = exerciseId == null
        ? null
        : await _preferenceRepo.getExecutionPreference(stableId: exerciseId);
    final equipmentCodes = exercise == null
        ? const <String>[]
        : EquipmentNormalizer.parseEquipmentString(
            exercise.equipment,
          ).canonicalItems.map((item) => item.id).toList(growable: false);
    final item = profile?.items.firstWhere(
      (candidate) =>
          candidate.isAvailable &&
          equipmentCodes.contains(candidate.equipmentCode),
      orElse: () => const EquipmentProfileItem(
        id: '',
        equipmentProfileId: '',
        equipmentCode: '',
        isAvailable: false,
        weightIncrementKg: null,
      ),
    );
    final effectiveItemIncrement = item?.id.isEmpty == true
        ? null
        : item?.weightIncrementKg;
    final targetLoad =
        strength?.targetLoadKg ?? _rawDouble(raw?['targetLoadKg']);
    final targetBasis =
        _rawLoadBasis(strength?.loadBasis) ?? _rawLoadBasis(raw?['loadBasis']);
    final targetMin =
        strength?.targetRepsMin ?? _rawInt(raw?['targetRepsMin']) ?? reps.$1;
    final targetMax =
        strength?.targetRepsMax ?? _rawInt(raw?['targetRepsMax']) ?? reps.$2;
    final targetRpe = strength?.targetRpe ?? _rawInt(raw?['targetRpe']);
    final effortMode = strength?.effortMode == null
        ? _rawEffortMode(raw?['effortMode'])
        : B02EffortMode.parse(strength!.effortMode);
    return B02StrengthExecutionSlot(
      id: id,
      groupId: group?.id,
      groupType: group?.groupType,
      groupLabel: group?.label,
      groupOrdinal: group?.ordinal,
      roundOrdinal: roundOrdinal,
      memberOrdinal: member?.ordinal,
      prescriptionId: prescription?.id ?? raw?['id'] as String? ?? id,
      exerciseId: exerciseId,
      exerciseNameSnapshot: name,
      plannedSets: plannedSets,
      targetRepsMin: targetMin,
      targetRepsMax: targetMax,
      targetRpe: targetRpe,
      targetLoadKg: targetLoad,
      targetLoadBasis: targetBasis,
      prescribedRestSeconds:
          strength?.restSeconds ?? _rawInt(raw?['restSeconds']),
      memberTransitionRestSeconds: member?.transitionRestSeconds,
      groupRestAfterRoundSeconds: group?.restAfterRoundSeconds,
      templateDefaultRestSeconds: templateDefaultRestSeconds,
      exercisePreferenceRestSeconds: preference?.customRestSeconds,
      effortMode: effortMode,
      endedAtFailure: raw?['endedAtFailure'] == true,
      executionPreference: preference,
      effectiveItemIncrementKg: effectiveItemIncrement,
      profileDefaultIncrementKg: profile?.profile.defaultWeightIncrementKg,
      isDeloadWeek: isDeloadWeek,
    );
  }

  static Map<String, dynamic> _snapshotObject(Object? raw) {
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  }

  static int? _rawInt(Object? raw) => raw is int ? raw : null;

  static double? _rawDouble(Object? raw) => raw is num ? raw.toDouble() : null;

  static B02LoadBasis? _rawLoadBasis(Object? raw) {
    if (raw is! String) return null;
    for (final basis in B02LoadBasis.values) {
      if (basis.dbValue == raw) return basis;
    }
    return null;
  }

  static B02EffortMode _rawEffortMode(Object? raw) {
    if (raw is String) {
      for (final mode in B02EffortMode.values) {
        if (mode.dbValue == raw) return mode;
      }
    }
    return B02EffortMode.standard;
  }

  (int?, int?) _parseRepsRange(String raw) {
    final values = RegExp(
      r'\d+',
    ).allMatches(raw).map((match) => int.parse(match.group(0)!)).toList();
    if (values.isEmpty) return (null, null);
    if (values.length == 1) return (values.single, values.single);
    return (values.first, values[1]);
  }

  Future<void> saveDraft({
    required int draftId,
    required B02ExecutionDraftState state,
    DateTime? nowUtc,
  }) async {
    if (state.activityType != B02ActivityType.strength) {
      throw const B02StrengthExecutionException(
        'Strength drafts must carry activityType=strength.',
      );
    }
    final draft = await (_db.select(
      _db.workoutDrafts,
    )..where((table) => table.id.equals(draftId))).getSingleOrNull();
    if (draft == null || draft.executionStateJson == null) {
      throw const B02StrengthExecutionRecoveryException(
        'Only a canonical B02 draft can be updated.',
      );
    }
    final decoded = B02ExecutionDraftCodec.decode(draft.executionStateJson!);
    if (!decoded.isCanonical || decoded.state!.snapshotId != state.snapshotId) {
      throw const B02StrengthExecutionRecoveryException(
        'Draft snapshot identity changed while saving.',
      );
    }
    final changed =
        await (_db.update(
          _db.workoutDrafts,
        )..where((table) => table.id.equals(draftId))).write(
          WorkoutDraftsCompanion(
            currentExerciseIndex: Value(state.currentExerciseOrdinal),
            currentSetIndex: Value(state.currentSetOrdinal),
            elapsedSeconds: Value(state.elapsedSeconds),
            loggedSetsJson: Value(
              WorkoutDraftCodec.encode(
                routineName: state.routineName,
                currentExerciseIndex: state.currentExerciseOrdinal,
                currentSetIndex: state.currentSetOrdinal,
                elapsedSeconds: state.elapsedSeconds,
                loggedSets: const [],
              ),
            ),
            routineName: Value(state.routineName),
            updatedAt: Value((nowUtc ?? _nowUtc()).toUtc()),
            draftSchemaVersion: const Value(
              B02ExecutionDraftState.schemaVersion,
            ),
            activityType: Value(B02ActivityType.strength.dbValue),
            executionStateJson: Value(B02ExecutionDraftCodec.encode(state)),
          ),
        );
    if (changed != 1) {
      throw const B02StrengthExecutionRecoveryException(
        'The B02 draft changed before it could be saved.',
      );
    }
  }

  Future<int> finalizeDraft({
    required int draftId,
    required String commandId,
    required B02ExecutionDraftState state,
    CompletionKind completionKind = CompletionKind.full,
    String? reason,
    DateTime? completedAtUtc,
  }) async {
    if (commandId.trim().isEmpty) {
      throw ArgumentError.value(commandId, 'commandId', 'Must not be blank.');
    }
    final payload = _completionPayload(
      state: state,
      completionKind: completionKind,
      reason: reason,
      completedAtUtc: completedAtUtc,
    );
    final completionMarker = _completionMarker(
      commandId: commandId,
      payload: payload,
    );
    final completionMarkerPrefix = _completionMarkerPrefix(commandId);
    return _db.transaction(() async {
      final markerSession =
          await (_db.select(_db.workoutSessions)
                ..where((table) => table.uuid.equals(completionMarker)))
              .getSingleOrNull();
      if (markerSession != null) {
        if (markerSession.activityType != B02ActivityType.strength.dbValue) {
          throw const B02StrengthExecutionFinalizationException(
            'Completion command marker belongs to a non-strength session.',
          );
        }
        return markerSession.id;
      }
      final conflictingMarker =
          await (_db.select(_db.workoutSessions)
                ..where((table) => table.uuid.like('$completionMarkerPrefix%')))
              .getSingleOrNull();
      if (conflictingMarker != null) {
        throw const B02StrengthExecutionFinalizationException(
          'A retry must use the original completion payload.',
        );
      }
      final draft = await (_db.select(
        _db.workoutDrafts,
      )..where((table) => table.id.equals(draftId))).getSingleOrNull();
      final occurrenceId = draft?.scheduledOccurrenceId;
      final existing = occurrenceId == null
          ? await (_db.select(_db.occurrenceEvents)
                  ..where((table) => table.commandId.equals(commandId)))
                .getSingleOrNull()
          : await (_db.select(_db.occurrenceEvents)..where(
                  (table) =>
                      table.occurrenceId.equals(occurrenceId) &
                      table.commandId.equals(commandId),
                ))
                .getSingleOrNull();
      if (existing != null) {
        return _existingCompletionResult(
          occurrenceId: existing.occurrenceId,
          event: existing,
          payload: payload,
          completionKind: completionKind,
        );
      }
      if (draft == null) {
        throw const B02StrengthExecutionRecoveryException(
          'The B02 draft is missing; no new completion can be inferred.',
        );
      }
      if (draft.executionStateJson == null ||
          draft.executionSnapshotJson == null) {
        throw const B02StrengthExecutionRecoveryException(
          'The draft has no canonical execution state or frozen snapshot.',
        );
      }
      _requireMatchingState(draft, state);
      final occurrence = occurrenceId == null
          ? null
          : await _requireInProgressOccurrence(occurrenceId);
      await _validateBeforeMutation(
        state: state,
        completionKind: completionKind,
      );

      final sessionId = await _db
          .into(_db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              name: state.routineName,
              totalVolume: _calculateVolume(state),
              durationSeconds: state.elapsedSeconds,
              estimatedCalories: 0,
              uuid: Value(completionMarker),
              completedAt: Value((completedAtUtc ?? _nowUtc()).toUtc()),
              scheduledOccurrenceId: Value(occurrence?.id),
              executionSnapshotJson: Value(draft.executionSnapshotJson),
              executionTimezoneId: Value(occurrence?.effectiveTimezoneId),
              completionKind: Value(completionKind.dbValue),
              activityType: Value(B02ActivityType.strength.dbValue),
              activitySchemaVersion: const Value(1),
            ),
          );
      await _persistDetail(sessionId: sessionId, state: state);

      if (occurrence != null) {
        final completion = await _calendarRepo
            .completeWithPersistedSessionInTransaction(
              CompleteOccurrenceCommand(
                occurrenceId: occurrence.id,
                commandId: commandId,
                expectedStatus: OccurrenceStatus.inProgress,
                workoutSessionId: sessionId,
                completionKind: completionKind,
                reason: reason,
              ),
            );
        await (_db.update(
          _db.occurrenceEvents,
        )..where((table) => table.id.equals(completion.event.id))).write(
          OccurrenceEventsCompanion(
            metadataJson: Value(
              jsonEncode({
                'workoutSessionId': sessionId,
                'completionKind': completionKind.dbValue,
                'payload': payload,
              }),
            ),
          ),
        );
      }
      final delete = _db.delete(_db.workoutDrafts)
        ..where((table) => table.id.equals(draft.id));
      if (occurrenceId != null) {
        delete.where(
          (table) => table.scheduledOccurrenceId.equals(occurrenceId),
        );
      }
      final deleted = await delete.go();
      if (deleted != 1) {
        throw const B02StrengthExecutionFinalizationException(
          'The exact B02 draft was not deleted after completion.',
        );
      }
      return sessionId;
    });
  }

  Future<void> discardDraft({required int draftId, String? commandId}) async {
    await _db.transaction(() async {
      final draft = await (_db.select(
        _db.workoutDrafts,
      )..where((table) => table.id.equals(draftId))).getSingleOrNull();
      if (draft == null) return;
      if (draft.scheduledOccurrenceId != null) {
        final occurrence = await _calendarRepo.getOccurrence(
          draft.scheduledOccurrenceId!,
        );
        if (occurrence == null) {
          throw const B02StrengthExecutionRecoveryException(
            'Cannot discard a draft with missing occurrence ancestry.',
          );
        }
        await _calendarRepo.discardStarted(
          DiscardStartedOccurrenceCommand(
            occurrenceId: occurrence.id,
            commandId: commandId ?? _uuid.v4(),
            expectedStatus: _parseOccurrenceStatus(occurrence.status),
          ),
        );
        return;
      }
      await (_db.delete(
        _db.workoutDrafts,
      )..where((table) => table.id.equals(draftId))).go();
    });
  }

  Future<B02StrengthExecutionLaunch> _upgradeOrReadScheduledDraft({
    required String occurrenceId,
    required String snapshotJson,
  }) async {
    final draft =
        await (_db.select(_db.workoutDrafts)..where(
              (table) => table.scheduledOccurrenceId.equals(occurrenceId),
            ))
            .getSingleOrNull();
    if (draft == null) {
      throw const B02StrengthExecutionRecoveryException(
        'Calendar start did not create its linked workout draft.',
      );
    }
    if (draft.executionStateJson != null) {
      return _readCanonicalDraft(
        draft: draft,
        expectedSnapshotJson: snapshotJson,
        occurrenceId: occurrenceId,
      );
    }
    final state = _stateFromSnapshot(
      snapshotJson: snapshotJson,
      snapshotId: occurrenceId,
    );
    final changed =
        await (_db.update(
          _db.workoutDrafts,
        )..where((table) => table.id.equals(draft.id))).write(
          WorkoutDraftsCompanion(
            draftSchemaVersion: const Value(
              B02ExecutionDraftState.schemaVersion,
            ),
            activityType: Value(B02ActivityType.strength.dbValue),
            executionStateJson: Value(B02ExecutionDraftCodec.encode(state)),
            executionSnapshotJson: Value(snapshotJson),
            updatedAt: Value(_nowUtc().toUtc()),
          ),
        );
    if (changed != 1) {
      throw const B02StrengthExecutionRecoveryException(
        'The scheduled draft changed during its B02 upgrade.',
      );
    }
    final upgraded = await (_db.select(
      _db.workoutDrafts,
    )..where((table) => table.id.equals(draft.id))).getSingle();
    return _readCanonicalDraft(
      draft: upgraded,
      expectedSnapshotJson: snapshotJson,
      occurrenceId: occurrenceId,
    );
  }

  B02StrengthExecutionLaunch _readCanonicalDraft({
    required WorkoutDraft draft,
    required String? expectedSnapshotJson,
    required String? occurrenceId,
  }) {
    if (draft.executionStateJson == null ||
        draft.draftSchemaVersion != B02ExecutionDraftState.schemaVersion ||
        draft.activityType != B02ActivityType.strength.dbValue) {
      throw const B02StrengthExecutionRecoveryException(
        'This is a B01 v1 draft; resume it through the retained legacy bridge.',
      );
    }
    if (expectedSnapshotJson == null ||
        draft.executionSnapshotJson != expectedSnapshotJson) {
      throw const B02StrengthExecutionRecoveryException(
        'The B02 draft snapshot does not match its frozen occurrence.',
      );
    }
    final decoded = B02ExecutionDraftCodec.decode(draft.executionStateJson!);
    if (!decoded.isCanonical ||
        decoded.state!.activityType != B02ActivityType.strength) {
      throw const B02StrengthExecutionRecoveryException(
        'The B02 draft payload is not a canonical strength state.',
      );
    }
    return B02StrengthExecutionLaunch(
      draftId: draft.id,
      occurrenceId: occurrenceId,
      executionSnapshotJson: draft.executionSnapshotJson!,
      state: decoded.state!,
    );
  }

  B02ExecutionDraftState _stateFromSnapshot({
    required String snapshotJson,
    required String snapshotId,
  }) {
    final snapshot = _decodeSnapshot(snapshotJson);
    final routineName = snapshot['routineName'];
    if (routineName is! String || routineName.trim().isEmpty) {
      throw const B02StrengthExecutionRecoveryException(
        'The frozen strength snapshot lacks a routine name.',
      );
    }
    final rawGroups = snapshot['groups'];
    if (rawGroups is! List) {
      throw const B02StrengthExecutionRecoveryException(
        'The frozen strength snapshot lacks its group graph.',
      );
    }
    final groups = rawGroups
        .map(
          (raw) =>
              B02ExerciseGroup.fromJson(Map<String, dynamic>.from(raw as Map)),
        )
        .toList(growable: false);
    _validateGroupOrdinals(groups);
    return B02ExecutionDraftState(
      snapshotId: snapshotId,
      snapshotVersion: _snapshotVersion(snapshot),
      activityType: B02ActivityType.strength,
      routineName: routineName.trim(),
      elapsedSeconds: 0,
      currentExerciseOrdinal: 0,
      currentSetOrdinal: 0,
      groups: groups,
    );
  }

  Future<void> _requireStrengthTemplate(String templateId) async {
    final template = await (_db.select(
      _db.sessionTemplates,
    )..where((table) => table.id.equals(templateId))).getSingleOrNull();
    if (template == null) {
      throw const B02StrengthExecutionException(
        'Strength template ancestry is missing.',
      );
    }
    if (template.activityType != B02ActivityType.strength.dbValue) {
      throw B02StrengthExecutionException(
        'Template activity type ${template.activityType} is not strength.',
      );
    }
    final prescriptions = await (_db.select(
      _db.exercisePrescriptions,
    )..where((table) => table.sessionTemplateId.equals(templateId))).get();
    final stableIds = prescriptions
        .map((row) => row.exerciseId)
        .whereType<String>()
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    if (stableIds.length != prescriptions.length &&
        prescriptions.any(
          (row) => row.exerciseId == null || row.exerciseId!.trim().isEmpty,
        )) {
      throw const B02StrengthExecutionException(
        'B02 strength execution requires resolved stable exercise IDs.',
      );
    }
    final resolved = await (_db.select(
      _db.exercises,
    )..where((table) => table.stableId.isIn(stableIds))).get();
    if (resolved.length != stableIds.length) {
      throw const B02StrengthExecutionException(
        'A strength prescription references a missing canonical exercise.',
      );
    }
  }

  Future<void> _requireNoActiveDraft() async {
    final active = await _db.select(_db.workoutDrafts).get();
    if (active.isNotEmpty) {
      throw const B02StrengthExecutionException(
        'Another active workout draft must be resumed or discarded first.',
      );
    }
  }

  Future<ScheduledSessionOccurrence> _requireInProgressOccurrence(
    String occurrenceId,
  ) async {
    final occurrence = await _calendarRepo.getOccurrence(occurrenceId);
    if (occurrence == null ||
        occurrence.status != OccurrenceStatus.inProgress.dbValue) {
      throw const B02StrengthExecutionFinalizationException(
        'Only an in-progress scheduled occurrence can be finalized.',
      );
    }
    return occurrence;
  }

  void _requireMatchingState(WorkoutDraft draft, B02ExecutionDraftState state) {
    final decoded = B02ExecutionDraftCodec.decode(draft.executionStateJson!);
    if (!decoded.isCanonical ||
        B02ExecutionDraftCodec.encode(decoded.state!) !=
            B02ExecutionDraftCodec.encode(state)) {
      throw const B02StrengthExecutionRecoveryException(
        'Finalization state does not match the durable B02 draft.',
      );
    }
  }

  Future<void> _validateBeforeMutation({
    required B02ExecutionDraftState state,
    required CompletionKind completionKind,
  }) async {
    if (state.elapsedSeconds < 1) {
      throw const B02StrengthExecutionFinalizationException(
        'A strength session requires a positive duration.',
      );
    }
    if (state.performedExercises.isEmpty ||
        state.performedExercises.every(
          (exercise) => exercise.sets.every(
            (set) => set.actualReps == null || set.actualReps! <= 0,
          ),
        )) {
      throw const B02StrengthExecutionFinalizationException(
        'A strength session requires at least one performed set with reps.',
      );
    }
    if (completionKind == CompletionKind.full) {
      if (state.performedExercises.any(
        (exercise) => exercise.status != 'completed',
      )) {
        throw const B02StrengthExecutionFinalizationException(
          'Incomplete exercise slots require explicit partial completion.',
        );
      }
      for (final group in state.groups) {
        final groupExercises = state.performedExercises.where(
          (exercise) => exercise.performedExerciseGroupId == group.id,
        );
        final expected = group.roundCount * group.members.length;
        if (groupExercises.length < expected ||
            groupExercises.any((exercise) => exercise.status != 'completed')) {
          throw const B02StrengthExecutionFinalizationException(
            'Incomplete group slots require explicit partial completion.',
          );
        }
      }
    }
    final exerciseIds = <String>{};
    final expectedIds = <String>{};
    final prescriptionIds = <String>{};
    for (final exercise in state.performedExercises) {
      exerciseIds.add(exercise.actualExerciseId);
      if (!const {
        'completed',
        'partial',
        'inProgress',
        'skipped',
      }.contains(exercise.status)) {
        throw const B02StrengthExecutionFinalizationException(
          'Performed exercise has an unsupported completion status.',
        );
      }
      if (exercise.expectedExerciseId != null) {
        expectedIds.add(exercise.expectedExerciseId!);
      }
      if (exercise.sourceExercisePrescriptionId != null) {
        prescriptionIds.add(exercise.sourceExercisePrescriptionId!);
      }
      if (exercise.performedExerciseGroupId != null &&
          !state.groups.any(
            (group) => group.id == exercise.performedExerciseGroupId,
          )) {
        throw const B02StrengthExecutionFinalizationException(
          'Performed exercise references an unknown frozen group slot.',
        );
      }
    }
    final actualRows = await (_db.select(
      _db.exercises,
    )..where((table) => table.stableId.isIn(exerciseIds))).get();
    if (actualRows.length != exerciseIds.length) {
      throw const B02StrengthExecutionFinalizationException(
        'A performed exercise has no canonical stable ID parent.',
      );
    }
    if (expectedIds.isNotEmpty) {
      final expectedRows = await (_db.select(
        _db.exercises,
      )..where((table) => table.stableId.isIn(expectedIds))).get();
      if (expectedRows.length != expectedIds.length) {
        throw const B02StrengthExecutionFinalizationException(
          'A prescribed exercise identity is no longer available.',
        );
      }
    }
    if (prescriptionIds.isNotEmpty) {
      final prescriptionRows = await (_db.select(
        _db.exercisePrescriptions,
      )..where((table) => table.id.isIn(prescriptionIds))).get();
      if (prescriptionRows.length != prescriptionIds.length) {
        throw const B02StrengthExecutionFinalizationException(
          'A source exercise prescription is no longer available.',
        );
      }
    }
  }

  Future<void> _persistDetail({
    required int sessionId,
    required B02ExecutionDraftState state,
  }) async {
    final groupIds = <String, String>{
      for (final group in state.groups) group.id: _uuid.v4(),
    };
    final exerciseIds = <String, String>{
      for (final exercise in state.performedExercises) exercise.id: _uuid.v4(),
    };
    final setIds = <String, String>{
      for (final exercise in state.performedExercises)
        for (final set in exercise.sets) set.id: _uuid.v4(),
    };
    final sourceGroups = await _existingGroupIds(state.groups);
    final sourcePrescriptions = await _existingPrescriptionIds(state);

    for (final group in state.groups) {
      final groupExercises = state.performedExercises.where(
        (exercise) => exercise.performedExerciseGroupId == group.id,
      );
      final expected = group.roundCount * group.members.length;
      final completed = groupExercises
          .where((exercise) => exercise.status == 'completed')
          .length;
      final status = completed >= expected ? 'completed' : 'partial';
      final completedRounds = [
        for (var round = 0; round < group.roundCount; round++)
          if (group.members.every(
            (member) => groupExercises.any(
              (exercise) =>
                  exercise.groupRoundOrdinal == round &&
                  exercise.groupMemberOrdinal == member.ordinal &&
                  exercise.status == 'completed',
            ),
          ))
            round,
      ].length;
      await _db
          .into(_db.performedExerciseGroups)
          .insert(
            PerformedExerciseGroupsCompanion.insert(
              id: groupIds[group.id]!,
              sessionId: sessionId,
              sourceExerciseGroupId: Value(
                sourceGroups.contains(group.id) ? group.id : null,
              ),
              groupTypeSnapshot: group.groupType.dbValue,
              labelSnapshot: Value(group.label),
              ordinal: group.ordinal,
              plannedRounds: group.roundCount,
              completedRounds: Value(completedRounds),
              status: Value(status),
            ),
          );
    }

    for (final exercise in state.performedExercises) {
      final persistedExerciseId = exerciseIds[exercise.id]!;
      await _db
          .into(_db.performedExercises)
          .insert(
            PerformedExercisesCompanion.insert(
              id: persistedExerciseId,
              sessionId: sessionId,
              performedExerciseGroupId: Value(
                exercise.performedExerciseGroupId == null
                    ? null
                    : groupIds[exercise.performedExerciseGroupId],
              ),
              sourceExercisePrescriptionId: Value(
                exercise.sourceExercisePrescriptionId != null &&
                        sourcePrescriptions.contains(
                          exercise.sourceExercisePrescriptionId,
                        )
                    ? exercise.sourceExercisePrescriptionId
                    : null,
              ),
              groupMemberOrdinal: Value(exercise.groupMemberOrdinal),
              groupRoundOrdinal: Value(exercise.groupRoundOrdinal),
              ordinal: exercise.ordinal,
              expectedExerciseId: Value(exercise.expectedExerciseId),
              expectedExerciseNameSnapshot: Value(
                exercise.expectedExerciseNameSnapshot,
              ),
              actualExerciseId: exercise.actualExerciseId,
              actualExerciseNameSnapshot: exercise.actualExerciseNameSnapshot,
              status: Value(exercise.status),
              substitutionReason: Value(exercise.substitutionReason),
            ),
          );
      for (final set in exercise.sets) {
        final persistedSetId = setIds[set.id]!;
        await _db
            .into(_db.performedSets)
            .insert(
              PerformedSetsCompanion.insert(
                id: persistedSetId,
                performedExerciseId: persistedExerciseId,
                ordinal: set.ordinal,
                role: set.role.dbValue,
                targetLoadKg: Value(set.targetLoadKg),
                targetLoadBasis: Value(set.targetLoadBasis?.dbValue),
                targetRepsMin: Value(set.targetRepsMin),
                targetRepsMax: Value(set.targetRepsMax),
                targetRpe: Value(set.targetRpe),
                actualLoadKg: Value(set.actualLoadKg),
                actualLoadBasis: Value(set.actualLoadBasis?.dbValue),
                actualReps: Value(set.actualReps),
                actualRpe: Value(set.actualRpe),
                effortMode: Value(set.technique.effortMode.dbValue),
                endedAtFailure: Value(set.technique.endedAtFailure),
                tempoEccentricSeconds: Value(
                  set.technique.tempoEccentricSeconds,
                ),
                tempoBottomPauseSeconds: Value(
                  set.technique.tempoBottomPauseSeconds,
                ),
                tempoConcentricSeconds: Value(
                  set.technique.tempoConcentricSeconds,
                ),
                tempoLockoutPauseSeconds: Value(
                  set.technique.tempoLockoutPauseSeconds,
                ),
                pausedRepPosition: Value(
                  set.technique.pausedRepPosition?.dbValue,
                ),
                pausedRepSeconds: Value(set.technique.pausedRepSeconds),
                assistanceMode: Value(set.technique.assistanceMode?.dbValue),
                assistanceKg: Value(set.technique.assistanceKg),
                notes: Value(set.notes),
              ),
            );
        for (final segment in set.technique.segments) {
          await _db
              .into(_db.performedSetSegments)
              .insert(
                PerformedSetSegmentsCompanion.insert(
                  id: _uuid.v4(),
                  performedSetId: persistedSetId,
                  ordinal: segment.ordinal,
                  reps: segment.reps,
                  externalLoadKg: Value(segment.externalLoadKg),
                  loadBasis: Value(segment.loadBasis?.dbValue),
                  assistanceKg: Value(segment.assistanceKg),
                  restBeforeSeconds: Value(segment.restBeforeSeconds),
                ),
              );
        }
      }
      final recommendation = exercise.targetRecommendation;
      if (recommendation != null) {
        await _insertTargetRecommendation(
          recommendation: recommendation,
          persistedExerciseId: persistedExerciseId,
        );
      }
    }
    for (final period in state.restPeriods) {
      await _db
          .into(_db.performedRestPeriods)
          .insert(
            PerformedRestPeriodsCompanion.insert(
              id: _uuid.v4(),
              sessionId: sessionId,
              performedSetId: Value(
                period.performedSetId == null
                    ? null
                    : setIds[period.performedSetId],
              ),
              performedExerciseGroupId: Value(
                period.performedExerciseGroupId == null
                    ? null
                    : groupIds[period.performedExerciseGroupId],
              ),
              scope: period.scope.dbValue,
              recommendedSeconds: Value(period.recommendedSeconds),
              selectedSeconds: Value(period.selectedSeconds),
              actualSeconds: Value(period.actualSeconds),
              source: period.source.dbValue,
              startedAtUtc: period.startedAtUtc.toUtc(),
              endedAtUtc: Value(period.endedAtUtc?.toUtc()),
              endReason: Value(period.endReason?.dbValue),
            ),
          );
    }
  }

  Future<Set<String>> _existingGroupIds(List<B02ExerciseGroup> groups) async {
    if (groups.isEmpty) return const {};
    final rows = await (_db.select(
      _db.exerciseGroups,
    )..where((table) => table.id.isIn(groups.map((group) => group.id)))).get();
    return rows.map((row) => row.id).toSet();
  }

  Future<Set<String>> _existingPrescriptionIds(
    B02ExecutionDraftState state,
  ) async {
    final ids = state.performedExercises
        .map((exercise) => exercise.sourceExercisePrescriptionId)
        .whereType<String>()
        .toSet();
    if (ids.isEmpty) return const {};
    final rows = await (_db.select(
      _db.exercisePrescriptions,
    )..where((table) => table.id.isIn(ids))).get();
    return rows.map((row) => row.id).toSet();
  }

  Future<void> _insertTargetRecommendation({
    required B02TargetRecommendation recommendation,
    required String persistedExerciseId,
  }) async {
    final rebound = recommendation.copyWith(
      performedExerciseId: persistedExerciseId,
    );
    await _db
        .into(_db.exerciseTargetRecommendations)
        .insert(
          ExerciseTargetRecommendationsCompanion.insert(
            id: rebound.id,
            performedExerciseId: persistedExerciseId,
            ruleVersion: rebound.ruleVersion,
            confidence: rebound.confidence.dbValue,
            completenessJson: jsonEncode(rebound.completeness),
            recommendedLoadKg: Value(rebound.recommendedLoadKg),
            loadBasis: Value(rebound.loadBasis?.dbValue),
            targetRepsMin: Value(rebound.targetRepsMin),
            targetRepsMax: Value(rebound.targetRepsMax),
            targetRpe: Value(rebound.targetRpe),
            incrementKg: Value(rebound.incrementKg),
            evidenceCutoffUtc: Value(rebound.evidenceCutoffUtc),
            comparatorCount: Value(rebound.comparatorCount),
            rationaleCodesJson: jsonEncode(rebound.rationaleCodes),
            wasOverridden: Value(rebound.wasOverridden),
          ),
        );
  }

  Future<int> _existingCompletionResult({
    required String occurrenceId,
    required OccurrenceEvent event,
    required String payload,
    required CompletionKind completionKind,
  }) async {
    final expectedType = completionKind == CompletionKind.full
        ? 'completed'
        : 'partiallyCompleted';
    if (event.eventType != expectedType || event.metadataJson == null) {
      throw const B02StrengthExecutionFinalizationException(
        'This command ID belongs to a different occurrence action.',
      );
    }
    final metadata = _decodeMetadata(event.metadataJson!);
    if (metadata['payload'] != payload ||
        metadata['completionKind'] != completionKind.dbValue) {
      throw const B02StrengthExecutionFinalizationException(
        'A retry must use the original completion payload.',
      );
    }
    final sessionId = metadata['workoutSessionId'];
    if (sessionId is! int) {
      throw const B02StrengthExecutionFinalizationException(
        'Completion event does not identify its session.',
      );
    }
    final session =
        await (_db.select(_db.workoutSessions)..where(
              (table) =>
                  table.id.equals(sessionId) &
                  table.scheduledOccurrenceId.equals(occurrenceId),
            ))
            .getSingleOrNull();
    if (session == null ||
        session.activityType != B02ActivityType.strength.dbValue) {
      throw const B02StrengthExecutionFinalizationException(
        'Completion event/session ancestry is inconsistent.',
      );
    }
    return session.id;
  }

  static String _completionPayload({
    required B02ExecutionDraftState state,
    required CompletionKind completionKind,
    required String? reason,
    required DateTime? completedAtUtc,
  }) => jsonEncode({
    'state': state.toJson(),
    'completionKind': completionKind.dbValue,
    'reason': reason?.trim(),
    'completedAtUtc': completedAtUtc?.toUtc().toIso8601String(),
  });

  static String _completionMarkerPrefix(String commandId) =>
      'b02-completion:${base64Url.encode(utf8.encode(commandId))}:';

  static String _completionMarker({
    required String commandId,
    required String payload,
  }) =>
      '${_completionMarkerPrefix(commandId)}'
      '${sha256.convert(utf8.encode(payload))}';

  static double _calculateVolume(B02ExecutionDraftState state) {
    var total = 0.0;
    for (final exercise in state.performedExercises) {
      for (final set in exercise.sets) {
        if (set.role != B02SetRole.working ||
            set.actualReps == null ||
            set.actualLoadKg == null) {
          continue;
        }
        if (set.technique.segments.isEmpty) {
          total += set.actualLoadKg! * set.actualReps!;
        } else {
          for (final segment in set.technique.segments) {
            if (segment.externalLoadKg != null) {
              total += segment.externalLoadKg! * segment.reps;
            }
          }
        }
      }
    }
    return total;
  }

  static Map<String, dynamic> _decodeSnapshot(String json) {
    try {
      final value = jsonDecode(json);
      if (value is! Map) {
        throw const FormatException('Snapshot must be an object.');
      }
      return Map<String, dynamic>.from(value);
    } catch (error) {
      throw B02StrengthExecutionRecoveryException(
        'Execution snapshot is invalid: $error',
      );
    }
  }

  static Map<String, dynamic> _decodeMetadata(String json) {
    try {
      final value = jsonDecode(json);
      if (value is! Map) {
        throw const FormatException('Metadata must be an object.');
      }
      return Map<String, dynamic>.from(value);
    } catch (error) {
      throw B02StrengthExecutionFinalizationException(
        'Completion metadata is invalid: $error',
      );
    }
  }

  static int _snapshotVersion(Map<String, dynamic> snapshot) {
    final value = snapshot['version'];
    if (value is! int || value < 1) {
      throw const B02StrengthExecutionRecoveryException(
        'Execution snapshot has no supported version.',
      );
    }
    return value;
  }

  static void _validateGroupOrdinals(List<B02ExerciseGroup> groups) {
    final sorted = groups.map((group) => group.ordinal).toList()..sort();
    for (var index = 0; index < sorted.length; index++) {
      if (sorted[index] != index) {
        throw const B02StrengthExecutionException(
          'Frozen group ordinals must be contiguous from zero.',
        );
      }
    }
  }

  static String _requiredText(String value, String field) {
    final clean = value.trim();
    if (clean.isEmpty) {
      throw ArgumentError.value(value, field, 'Must not be blank.');
    }
    return clean;
  }

  static OccurrenceStatus _parseOccurrenceStatus(String value) {
    return OccurrenceStatus.values.firstWhere(
      (status) => status.dbValue == value,
      orElse: () => throw B02StrengthExecutionException(
        'Unsupported occurrence status $value.',
      ),
    );
  }
}

/// Thin successor seam used by the player/controller. It intentionally does
/// not absorb CalendarRepository or WorkoutRepository responsibilities.
class StrengthExecutionCompatibilityAdapter {
  final StrengthExecutionRepository _repository;

  StrengthExecutionCompatibilityAdapter(this._repository);

  Future<B02StrengthExecutionCoverage> checkScheduledCoverage(
    String occurrenceId,
  ) => _repository.checkScheduledCoverage(occurrenceId);

  Future<B02StrengthExecutionLaunch> startScheduledOccurrence({
    required String occurrenceId,
    required String commandId,
    bool confirmedOutsideEffectiveDate = false,
  }) => _repository.startScheduledOccurrence(
    occurrenceId: occurrenceId,
    commandId: commandId,
    confirmedOutsideEffectiveDate: confirmedOutsideEffectiveDate,
  );

  Future<B02StrengthExecutionLaunch> resumeScheduledOccurrence(
    String occurrenceId,
  ) => _repository.resumeScheduledOccurrence(occurrenceId);

  Future<B02StrengthExecutionLaunch> readDraft(int draftId) =>
      _repository.readDraft(draftId);

  Future<List<B02StrengthExecutionSlot>> readExecutionSlots(
    B02StrengthExecutionLaunch launch,
  ) => _repository.readExecutionSlots(launch);

  Future<B02WorkoutPreparationResult> prepareExecution(
    B02StrengthExecutionLaunch launch,
  ) => _repository.prepareExecution(launch);

  Future<B02StrengthExecutionLaunch> startUnscheduledDraft({
    required String routineName,
    required String executionSnapshotJson,
    Iterable<B02ExerciseGroup> groups = const [],
    String? snapshotId,
  }) => _repository.startUnscheduledDraft(
    routineName: routineName,
    executionSnapshotJson: executionSnapshotJson,
    groups: groups,
    snapshotId: snapshotId,
  );

  Future<void> saveDraft({
    required int draftId,
    required B02ExecutionDraftState state,
  }) => _repository.saveDraft(draftId: draftId, state: state);

  Future<int> finalizeDraft({
    required int draftId,
    required String commandId,
    required B02ExecutionDraftState state,
    CompletionKind completionKind = CompletionKind.full,
    String? reason,
    DateTime? completedAtUtc,
  }) => _repository.finalizeDraft(
    draftId: draftId,
    commandId: commandId,
    state: state,
    completionKind: completionKind,
    reason: reason,
    completedAtUtc: completedAtUtc,
  );

  Future<void> discardDraft({required int draftId, String? commandId}) =>
      _repository.discardDraft(draftId: draftId, commandId: commandId);
}
