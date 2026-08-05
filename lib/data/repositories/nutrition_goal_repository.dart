import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../database/app_database.dart' as db;
import '../models/b04_goal_models.dart';
import 'coaching_preference_repository.dart';

/// Sole command/read-model owner for B04 goal and target history.
///
/// The legacy [UserProfiles] goal columns are read only for the initial
/// compatibility import. Every subsequent goal change is an immutable v18
/// row; this repository never updates those legacy columns.
class NutritionGoalRepository {
  final db.AppDatabase _db;
  final Uuid _uuid;
  final LocalScheduleDateService _dates;
  final DateTime Function() _nowUtc;

  NutritionGoalRepository({
    required db.AppDatabase database,
    Uuid? uuid,
    LocalScheduleDateService? dates,
    DateTime Function()? nowUtc,
  }) : _db = database,
       _uuid = uuid ?? const Uuid(),
       _dates = dates ?? LocalScheduleDateService(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  List<String> get supportedAdaptiveGoalRates =>
      List.unmodifiable(B04EnabledPolicyContract.current.supportedGoalRates);

  String defaultAdaptiveGoalRate(NutritionGoalType goalType) {
    final value =
        B04EnabledPolicyContract.current.defaultGoalRates[goalType.stableId];
    if (value == null) {
      throw const B04GoalValidationError(
        'unsupported_goal_type',
        'A custom goal has no enabled adaptive default rate.',
      );
    }
    return value;
  }

  Future<List<NutritionGoalVersionReadModel>> listVersions({
    required String userId,
  }) async {
    final owner = _owner(userId);
    final rows =
        await (_db.select(_db.nutritionGoalVersions)
              ..where((row) => row.userId.equals(owner))
              ..orderBy([(row) => OrderingTerm(expression: row.versionNumber)]))
            .get();
    return List.unmodifiable([for (final row in rows) _fromRow(row)]);
  }

  Future<NutritionGoalVersionReadModel?> activeGoal({
    required String userId,
    required String localDate,
    required String timezoneId,
  }) async {
    final owner = _owner(userId);
    final date = _dates.normalizeLocalDate(localDate);
    _dates.validateTimezone(timezoneId);
    final rows = await (_db.select(
      _db.nutritionGoalVersions,
    )..where((row) => row.userId.equals(owner))).get();
    final effective =
        rows
            .where(
              (row) =>
                  row.effectiveFromLocalDate.compareTo(date) <= 0 &&
                  (row.effectiveToLocalDate == null ||
                      row.effectiveToLocalDate!.compareTo(date) >= 0),
            )
            .toList()
          ..sort((a, b) {
            final byDate = b.effectiveFromLocalDate.compareTo(
              a.effectiveFromLocalDate,
            );
            if (byDate != 0) return byDate;
            return b.versionNumber.compareTo(a.versionNumber);
          });
    return effective.isEmpty ? null : _fromRow(effective.first);
  }

  /// Imports the existing profile once, using the current local date rather
  /// than inventing a historical effective date.
  Future<NutritionGoalVersionReadModel> ensureCompatibilityImport({
    required String userId,
    required NutritionGoalCommand legacyProfile,
  }) async {
    final owner = _owner(userId);
    final existing = await (_db.select(
      _db.nutritionGoalVersions,
    )..where((row) => row.userId.equals(owner))).getSingleOrNull();
    if (existing != null) return _fromRow(existing);
    final command = NutritionGoalCommand(
      userId: owner,
      goalType: legacyProfile.goalType,
      source: NutritionGoalSource.compatibility,
      calorieTargetKcal: legacyProfile.calorieTargetKcal,
      proteinTargetG: legacyProfile.proteinTargetG,
      carbsTargetG: legacyProfile.carbsTargetG,
      fatTargetG: legacyProfile.fatTargetG,
      effectiveFromLocalDate: legacyProfile.effectiveFromLocalDate,
      timezoneId: legacyProfile.timezoneId,
    );
    _validateCommand(command);
    return _insertVersion(command, versionNumber: 1);
  }

  Future<NutritionGoalVersionReadModel> recordUserSetGoal(
    NutritionGoalCommand command,
  ) async {
    if (command.source != NutritionGoalSource.userSet) {
      throw const B04GoalValidationError(
        'invalid_user_set_source',
        'A user-set goal command must use the user_set source.',
      );
    }
    return _recordGoalCommand(command);
  }

  Future<NutritionGoalVersionReadModel> recordManualOverride(
    NutritionGoalCommand command,
  ) async {
    return _recordGoalCommand(
      NutritionGoalCommand(
        userId: command.userId,
        goalType: command.goalType,
        source: NutritionGoalSource.override,
        calorieTargetKcal: command.calorieTargetKcal,
        proteinTargetG: command.proteinTargetG,
        carbsTargetG: command.carbsTargetG,
        fatTargetG: command.fatTargetG,
        effectiveFromLocalDate: command.effectiveFromLocalDate,
        timezoneId: command.timezoneId,
        effectiveToLocalDate: command.effectiveToLocalDate,
        commandId: command.commandId,
        id: command.id,
      ),
    );
  }

  /// Accepts only a canonical policy result. The proposal itself remains
  /// read-only until this explicit command succeeds.
  Future<NutritionGoalVersionReadModel> acceptAdaptiveProposal({
    required AdaptiveGoalProposal proposal,
    required bool adaptiveConsentEnabled,
    required bool ageEligible,
    String? acceptanceCommandId,
  }) async {
    proposal.validate();
    final availability = await CoachingPreferenceRepository(
      database: _db,
      dates: _dates,
      nowUtc: _nowUtc,
    ).adaptiveAvailability(userId: proposal.userId);
    if (!adaptiveConsentEnabled ||
        !availability.preferences.adaptiveCoachingEnabled) {
      throw const B04GoalValidationError(
        'coaching_consent_required',
        'Adaptive coaching must be explicitly enabled before acceptance.',
      );
    }
    if (!ageEligible || availability.eligibility?.isEligible != true) {
      throw const B04GoalValidationError(
        'coaching_unavailable_age',
        'Adaptive coaching is unavailable for the current age eligibility state.',
      );
    }
    _dates.normalizeLocalDate(proposal.effectiveFromLocalDate);
    _dates.validateTimezone(proposal.timezoneId);
    final owner = _owner(proposal.userId);
    final fingerprint =
        proposal.evidenceFingerprint ?? 'proposal:${proposal.id}';
    return _db.transaction(() async {
      final existing =
          await (_db.select(_db.nutritionGoalVersions)..where(
                (row) =>
                    row.userId.equals(owner) &
                    row.targetSource.equals(
                      NutritionGoalSource.adaptive.stableId,
                    ) &
                    row.evidenceFingerprint.equals(fingerprint),
              ))
              .getSingleOrNull();
      if (existing != null) return _fromRow(existing);

      final previous = await _latestForOwner(owner);
      final versionNumber = (previous?.versionNumber ?? 0) + 1;
      final id =
          acceptanceCommandId == null || acceptanceCommandId.trim().isEmpty
          ? _uuid.v4()
          : 'goal-acceptance-${acceptanceCommandId.trim()}';
      final byCommand =
          await (_db.select(_db.nutritionGoalVersions)
                ..where((row) => row.userId.equals(owner) & row.id.equals(id)))
              .getSingleOrNull();
      if (byCommand != null) return _fromRow(byCommand);

      await _db
          .into(_db.nutritionGoalVersions)
          .insert(
            db.NutritionGoalVersionsCompanion.insert(
              id: id,
              userId: owner,
              versionNumber: versionNumber,
              goalType: proposal.goalType.stableId,
              targetSource: NutritionGoalSource.adaptive.stableId,
              calorieTargetKcal: Value(proposal.calorieTargetKcal),
              proteinTargetG: Value(proposal.proteinTargetG),
              carbsTargetG: Value(proposal.carbsTargetG),
              fatTargetG: Value(proposal.fatTargetG),
              policyVersion: Value(proposal.policyVersion),
              calculationVersion: Value(proposal.calculationVersion),
              algorithmVersion: Value(proposal.algorithmVersion),
              effectiveFromLocalDate: proposal.effectiveFromLocalDate,
              timezoneId: proposal.timezoneId,
              supersedesGoalVersionId: Value(previous?.id),
              evidenceFingerprint: Value(fingerprint),
              exactResultNumerator: Value(proposal.exactResultNumerator),
              exactResultDenominator: Value(proposal.exactResultDenominator),
              normalizedMaintenanceKcal: Value(
                proposal.normalizedMaintenanceKcal,
              ),
              createdAtUtc: Value(_nowUtc().toUtc()),
            ),
          );
      await _syncLegacyCompatibilityMirror(owner, proposal);
      final row = await (_db.select(
        _db.nutritionGoalVersions,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      if (row == null) {
        throw const B04GoalConflictError(
          'goal_version_not_persisted',
          'The accepted target version was not persisted.',
        );
      }
      return _fromRow(row);
    });
  }

  Future<GoalEvaluationWindowReadModel> evaluationWindow({
    required String userId,
    required String localDate,
    required String timezoneId,
  }) async {
    final active = await activeGoal(
      userId: userId,
      localDate: localDate,
      timezoneId: timezoneId,
    );
    if (active == null) {
      return const GoalEvaluationWindowReadModel(
        activeGoalVersionId: null,
        resetReason: null,
        activeGoalEffectiveFromLocalDate: null,
        earliestEvaluationLocalDate: null,
      );
    }
    final resetReason = switch (active.source) {
      NutritionGoalSource.adaptive => 'accepted_adaptive_target',
      NutritionGoalSource.compatibility => null,
      NutritionGoalSource.calculated => 'calculated_target_change',
      NutritionGoalSource.override => 'manual_target_change',
      NutritionGoalSource.userSet => 'user_goal_change',
    };
    final earliest = resetReason == null
        ? null
        : _dates.addCalendarDays(
            active.effectiveFromLocalDate,
            active.timezoneId,
            21,
          );
    return GoalEvaluationWindowReadModel(
      activeGoalVersionId: active.id,
      resetReason: resetReason,
      activeGoalEffectiveFromLocalDate: active.effectiveFromLocalDate,
      earliestEvaluationLocalDate: earliest,
    );
  }

  Future<NutritionGoalVersionReadModel> _recordGoalCommand(
    NutritionGoalCommand command,
  ) async {
    final owner = _owner(command.userId);
    _validateCommand(command);
    return _db.transaction(() async {
      final fingerprint = command.commandId == null
          ? null
          : 'command:${command.commandId!.trim()}';
      if (fingerprint != null) {
        final existing =
            await (_db.select(_db.nutritionGoalVersions)..where(
                  (row) =>
                      row.userId.equals(owner) &
                      row.evidenceFingerprint.equals(fingerprint),
                ))
                .getSingleOrNull();
        if (existing != null) return _fromRow(existing);
      }
      final previous = await _latestForOwner(owner);
      final version = await _insertVersion(
        command,
        versionNumber: (previous?.versionNumber ?? 0) + 1,
        supersedesGoalVersionId: previous?.id,
        evidenceFingerprint: fingerprint,
      );
      return version;
    });
  }

  Future<NutritionGoalVersionReadModel> _insertVersion(
    NutritionGoalCommand command, {
    required int versionNumber,
    String? supersedesGoalVersionId,
    String? evidenceFingerprint,
  }) async {
    final id = command.id?.trim().isNotEmpty == true
        ? command.id!.trim()
        : _uuid.v4();
    final existing = await (_db.select(
      _db.nutritionGoalVersions,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (existing != null) return _fromRow(existing);
    await _db
        .into(_db.nutritionGoalVersions)
        .insert(
          db.NutritionGoalVersionsCompanion.insert(
            id: id,
            userId: _owner(command.userId),
            versionNumber: versionNumber,
            goalType: command.goalType.stableId,
            targetSource: command.source.stableId,
            calorieTargetKcal: Value(command.calorieTargetKcal),
            proteinTargetG: Value(command.proteinTargetG),
            carbsTargetG: Value(command.carbsTargetG),
            fatTargetG: Value(command.fatTargetG),
            effectiveFromLocalDate: command.effectiveFromLocalDate,
            effectiveToLocalDate: Value(command.effectiveToLocalDate),
            timezoneId: command.timezoneId,
            supersedesGoalVersionId: Value(supersedesGoalVersionId),
            evidenceFingerprint: Value(evidenceFingerprint),
            createdAtUtc: Value(_nowUtc().toUtc()),
          ),
        );
    await _syncLegacyCompatibilityMirror(_owner(command.userId), command);
    final row = await (_db.select(
      _db.nutritionGoalVersions,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const B04GoalConflictError(
        'goal_version_not_persisted',
        'The goal version was not persisted.',
      );
    }
    return _fromRow(row);
  }

  Future<db.NutritionGoalVersion?> _latestForOwner(String owner) async {
    final rows =
        await (_db.select(_db.nutritionGoalVersions)
              ..where((row) => row.userId.equals(owner))
              ..orderBy([
                (row) => OrderingTerm(
                  expression: row.versionNumber,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first;
  }

  void _validateCommand(NutritionGoalCommand command) {
    final owner = _owner(command.userId);
    if (owner.isEmpty) {
      throw const B04GoalValidationError(
        'missing_user_id',
        'A user ID is required for a goal command.',
      );
    }
    if (command.calorieTargetKcal != null && command.calorieTargetKcal! <= 0) {
      throw const B04GoalValidationError(
        'invalid_calorie_target',
        'A calorie target must be positive.',
      );
    }
    for (final value in [
      command.proteinTargetG,
      command.carbsTargetG,
      command.fatTargetG,
    ]) {
      if (value != null && (!value.isFinite || value < 0)) {
        throw const B04GoalValidationError(
          'invalid_macro_target',
          'Macro targets must be finite and non-negative.',
        );
      }
    }
    _dates.normalizeLocalDate(command.effectiveFromLocalDate);
    _dates.validateTimezone(command.timezoneId);
    if (command.effectiveToLocalDate != null &&
        _dates.compare(
              command.effectiveToLocalDate!,
              command.effectiveFromLocalDate,
            ) <
            0) {
      throw const B04GoalValidationError(
        'invalid_effective_range',
        'A goal end date cannot precede its effective date.',
      );
    }
  }

  NutritionGoalVersionReadModel _fromRow(db.NutritionGoalVersion row) =>
      NutritionGoalVersionReadModel(
        id: row.id,
        userId: row.userId,
        versionNumber: row.versionNumber,
        goalType: NutritionGoalTypeId.parse(row.goalType),
        source: _source(row.targetSource),
        calorieTargetKcal: row.calorieTargetKcal,
        proteinTargetG: row.proteinTargetG,
        carbsTargetG: row.carbsTargetG,
        fatTargetG: row.fatTargetG,
        policyVersion: row.policyVersion,
        calculationVersion: row.calculationVersion,
        algorithmVersion: row.algorithmVersion,
        effectiveFromLocalDate: row.effectiveFromLocalDate,
        effectiveToLocalDate: row.effectiveToLocalDate,
        timezoneId: row.timezoneId,
        supersedesGoalVersionId: row.supersedesGoalVersionId,
        evidenceFingerprint: row.evidenceFingerprint,
        exactResultNumerator: row.exactResultNumerator,
        exactResultDenominator: row.exactResultDenominator,
        normalizedMaintenanceKcal: row.normalizedMaintenanceKcal,
        createdAtUtc: row.createdAtUtc.toUtc(),
      );

  static NutritionGoalSource _source(String value) => switch (value) {
    'user_set' => NutritionGoalSource.userSet,
    'calculated' => NutritionGoalSource.calculated,
    'adaptive' => NutritionGoalSource.adaptive,
    'override' => NutritionGoalSource.override,
    'compatibility' => NutritionGoalSource.compatibility,
    _ => throw const B04GoalValidationError(
      'invalid_goal_source',
      'The stored goal source is not supported.',
    ),
  };

  static String _owner(String userId) => userId.trim();

  Future<void> _syncLegacyCompatibilityMirror(
    String owner,
    Object values,
  ) async {
    final profileId = int.tryParse(owner);
    if (profileId == null) return;
    final calorieTarget = values is AdaptiveGoalProposal
        ? values.calorieTargetKcal
        : (values as NutritionGoalCommand).calorieTargetKcal;
    final proteinTarget = values is AdaptiveGoalProposal
        ? values.proteinTargetG
        : (values as NutritionGoalCommand).proteinTargetG;
    final carbsTarget = values is AdaptiveGoalProposal
        ? values.carbsTargetG
        : (values as NutritionGoalCommand).carbsTargetG;
    final fatTarget = values is AdaptiveGoalProposal
        ? values.fatTargetG
        : (values as NutritionGoalCommand).fatTargetG;
    final goalType = values is AdaptiveGoalProposal
        ? values.goalType
        : (values as NutritionGoalCommand).goalType;
    await (_db.update(
      _db.userProfiles,
    )..where((row) => row.id.equals(profileId))).write(
      db.UserProfilesCompanion(
        calorieGoal: calorieTarget == null
            ? const Value.absent()
            : Value(calorieTarget),
        proteinGoal: proteinTarget == null
            ? const Value.absent()
            : Value(proteinTarget),
        carbsGoal: carbsTarget == null
            ? const Value.absent()
            : Value(carbsTarget),
        fatGoal: fatTarget == null ? const Value.absent() : Value(fatTarget),
        goal: Value(switch (goalType) {
          NutritionGoalType.loss => 'lose',
          NutritionGoalType.maintenance => 'maintain',
          NutritionGoalType.gain => 'gain',
          NutritionGoalType.custom => 'custom',
        }),
      ),
    );
  }
}
