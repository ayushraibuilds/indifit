import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/services/local_schedule_date_service.dart';
import '../database/app_database.dart';
import '../models/b02_execution_models.dart';
import '../services/b02_load_target_recommendation_service.dart';

/// Query inputs are intentionally separate from the pure rule request. This
/// repository gathers canonical facts; it never makes a progression decision.
class B02TargetEvidenceQuery {
  final String? stableExerciseId;
  final bool identityResolved;
  final B02LoadBasis? loadBasis;
  final DateTime nowUtc;
  final String? executionTimezoneId;
  final bool recoveryKnown;

  const B02TargetEvidenceQuery({
    required this.stableExerciseId,
    required this.identityResolved,
    required this.loadBasis,
    required this.nowUtc,
    required this.executionTimezoneId,
    required this.recoveryKnown,
  });
}

/// Canonical, stable-ID-only history reader for the target rule. Legacy
/// `WorkoutSets` are intentionally not queried: their load basis, immutable
/// actual identity, and rich failure facts cannot be recovered safely.
class B02TargetEvidenceRepository {
  final AppDatabase _db;
  final LocalScheduleDateService _civilDates;

  B02TargetEvidenceRepository(this._db, {LocalScheduleDateService? civilDates})
    : _civilDates = civilDates ?? LocalScheduleDateService();

  Future<B02LoadTargetEvidence> gather(B02TargetEvidenceQuery query) async {
    final now = query.nowUtc.toUtc();
    final cutoff = now.subtract(B02LoadTargetRuleV1.comparatorWindow);
    if (!query.identityResolved ||
        query.stableExerciseId == null ||
        query.stableExerciseId!.trim().isEmpty ||
        query.loadBasis == null) {
      return B02LoadTargetEvidence(
        cutoffUtc: cutoff,
        comparators: const [],
        recentWorkingSetCount: null,
        recoveryKnown: query.recoveryKnown,
      );
    }

    final sets = _db.performedSets;
    final exercises = _db.performedExercises;
    final sessions = _db.workoutSessions;
    final statement =
        _db.select(sets).join([
            innerJoin(
              exercises,
              exercises.id.equalsExp(sets.performedExerciseId),
            ),
            innerJoin(sessions, sessions.id.equalsExp(exercises.sessionId)),
          ])
          ..where(
            exercises.actualExerciseId.equals(query.stableExerciseId!.trim()),
          )
          ..where(sets.role.equals(B02SetRole.working.dbValue))
          ..where(sets.actualLoadBasis.equals(query.loadBasis!.dbValue))
          ..where(sets.actualLoadKg.isNotNull())
          ..where(sets.actualReps.isNotNull())
          ..where(
            sessions.activityType.equals(B02ActivityType.strength.dbValue),
          )
          ..where(sessions.completedAt.isBiggerOrEqualValue(cutoff))
          ..orderBy([
            OrderingTerm.desc(sessions.completedAt),
            OrderingTerm.desc(exercises.ordinal),
            OrderingTerm.desc(sets.ordinal),
          ]);
    final rows = await statement.get();
    final comparators = <B02TargetComparator>[
      for (final row in rows)
        B02TargetComparator(
          performedSetId: row.readTable(sets).id,
          stableExerciseId: row.readTable(exercises).actualExerciseId,
          loadBasis: B02LoadBasis.parse(row.readTable(sets).actualLoadBasis),
          actualLoadKg: row.readTable(sets).actualLoadKg!,
          actualReps: row.readTable(sets).actualReps!,
          actualRpe: row.readTable(sets).actualRpe,
          endedAtFailure: row.readTable(sets).endedAtFailure,
          completedAtUtc: row.readTable(sessions).completedAt.toUtc(),
        ),
    ];
    final workloadStart = _sevenCivilDayStartUtc(
      nowUtc: now,
      timezoneId: query.executionTimezoneId,
    );
    return B02LoadTargetEvidence(
      cutoffUtc: cutoff,
      comparators: comparators,
      recentWorkingSetCount: workloadStart == null
          ? null
          : comparators
                .where(
                  (candidate) =>
                      !candidate.completedAtUtc.isBefore(workloadStart),
                )
                .length,
      recoveryKnown: query.recoveryKnown,
    );
  }

  DateTime? _sevenCivilDayStartUtc({
    required DateTime nowUtc,
    required String? timezoneId,
  }) {
    if (timezoneId == null || timezoneId.trim().isEmpty) return null;
    try {
      final location = _civilDates.locationFor(timezoneId);
      final localNow = tz.TZDateTime.from(nowUtc, location);
      return tz.TZDateTime(
        location,
        localNow.year,
        localNow.month,
        localNow.day - 6,
      ).toUtc();
    } on ArgumentError {
      // An absent or invalid historical timezone cannot be treated as UTC.
      return null;
    }
  }
}

/// Draft-only helper. It replaces the frozen offer without touching recorded
/// actual values; an override is represented by the offer's flag while the
/// user's chosen values remain on the corresponding performed set(s).
class B02TargetDraftCoordinator {
  const B02TargetDraftCoordinator();

  B02ExecutionDraftState freezeRecommendation(
    B02ExecutionDraftState draft,
    B02TargetRecommendation recommendation,
  ) {
    final matching = draft.performedExercises.where(
      (exercise) => exercise.id == recommendation.performedExerciseId,
    );
    if (matching.length != 1) {
      throw B02ValidationException(
        'Target recommendation must belong to exactly one draft exercise.',
      );
    }
    return draft.copyWith(
      performedExercises: [
        for (final exercise in draft.performedExercises)
          exercise.id == recommendation.performedExerciseId
              ? exercise.copyWith(targetRecommendation: recommendation)
              : exercise,
      ],
    );
  }

  B02ExecutionDraftState recordOverride(
    B02ExecutionDraftState draft,
    String performedExerciseId,
  ) {
    final matching = draft.performedExercises.where(
      (exercise) => exercise.id == performedExerciseId,
    );
    if (matching.length != 1 || matching.single.targetRecommendation == null) {
      throw B02ValidationException(
        'A user override requires an existing target recommendation.',
      );
    }
    final changed = matching.single.copyWith(
      targetRecommendation: matching.single.targetRecommendation!.copyWith(
        wasOverridden: true,
      ),
    );
    return draft.copyWith(
      performedExercises: [
        for (final exercise in draft.performedExercises)
          exercise.id == performedExerciseId ? changed : exercise,
      ],
    );
  }
}

/// Insert-once persistence for completed B02 target evidence. It refuses to
/// overwrite a historical offer, including its override flag and rationale.
class B02TargetRecommendationPersistenceRepository {
  final AppDatabase _db;

  B02TargetRecommendationPersistenceRepository(this._db);

  Future<void> persistCompleted(B02TargetRecommendation recommendation) async {
    await _db.transaction(() async {
      final parent =
          await (_db.select(_db.performedExercises)..where(
                (table) => table.id.equals(recommendation.performedExerciseId),
              ))
              .getSingleOrNull();
      if (parent == null) {
        throw B02ValidationException(
          'Cannot persist target evidence without its performed exercise.',
        );
      }
      final session = await (_db.select(
        _db.workoutSessions,
      )..where((table) => table.id.equals(parent.sessionId))).getSingleOrNull();
      if (session == null ||
          session.activityType != B02ActivityType.strength.dbValue) {
        throw B02ValidationException(
          'Target evidence may only be frozen for a canonical strength session.',
        );
      }
      final existing =
          await (_db.select(_db.exerciseTargetRecommendations)
                ..where((table) => table.performedExerciseId.equals(parent.id)))
              .getSingleOrNull();
      if (existing != null) {
        throw B02ValidationException(
          'Completed target evidence is immutable and already exists.',
        );
      }
      await _db
          .into(_db.exerciseTargetRecommendations)
          .insert(
            ExerciseTargetRecommendationsCompanion.insert(
              id: recommendation.id,
              performedExerciseId: recommendation.performedExerciseId,
              ruleVersion: recommendation.ruleVersion,
              confidence: recommendation.confidence.dbValue,
              completenessJson: jsonEncode(recommendation.completeness),
              recommendedLoadKg: Value(recommendation.recommendedLoadKg),
              loadBasis: Value(recommendation.loadBasis?.dbValue),
              targetRepsMin: Value(recommendation.targetRepsMin),
              targetRepsMax: Value(recommendation.targetRepsMax),
              targetRpe: Value(recommendation.targetRpe),
              incrementKg: Value(recommendation.incrementKg),
              evidenceCutoffUtc: Value(recommendation.evidenceCutoffUtc),
              comparatorCount: Value(recommendation.comparatorCount),
              rationaleCodesJson: jsonEncode(recommendation.rationaleCodes),
              wasOverridden: Value(recommendation.wasOverridden),
            ),
          );
    });
  }

  Future<B02TargetRecommendation?> readCompleted(
    String performedExerciseId,
  ) async {
    final row =
        await (_db.select(_db.exerciseTargetRecommendations)..where(
              (table) => table.performedExerciseId.equals(performedExerciseId),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    final completeness = jsonDecode(row.completenessJson);
    final rationale = jsonDecode(row.rationaleCodesJson);
    if (completeness is! Map || rationale is! List) {
      throw const B02ValidationException(
        'Persisted target evidence contains invalid JSON.',
      );
    }
    return B02TargetRecommendation.fromJson({
      'id': row.id,
      'performedExerciseId': row.performedExerciseId,
      'ruleVersion': row.ruleVersion,
      'confidence': row.confidence,
      'completeness': completeness.map((key, value) => MapEntry('$key', value)),
      if (row.recommendedLoadKg != null)
        'recommendedLoadKg': row.recommendedLoadKg,
      if (row.loadBasis != null) 'loadBasis': row.loadBasis,
      if (row.targetRepsMin != null) 'targetRepsMin': row.targetRepsMin,
      if (row.targetRepsMax != null) 'targetRepsMax': row.targetRepsMax,
      if (row.targetRpe != null) 'targetRpe': row.targetRpe,
      if (row.incrementKg != null) 'incrementKg': row.incrementKg,
      if (row.evidenceCutoffUtc != null)
        'evidenceCutoffUtc': row.evidenceCutoffUtc!.toUtc().toIso8601String(),
      'comparatorCount': row.comparatorCount,
      'rationaleCodes': rationale,
      'wasOverridden': row.wasOverridden,
    });
  }
}
