import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../database/app_database.dart' as db;
import '../models/b04_goal_models.dart';

/// Command/read-model owner for the B04 coaching preference surface.
///
/// Consent events are the only historical authority. The v18 preference row
/// is maintained as a projection for compatibility, but reads recompute state
/// from the event stream so a stale projection can never grant consent.
class CoachingPreferenceRepository {
  final db.AppDatabase _db;
  final Uuid _uuid;
  final LocalScheduleDateService _dates;
  final DateTime Function() _nowUtc;

  CoachingPreferenceRepository({
    required db.AppDatabase database,
    Uuid? uuid,
    LocalScheduleDateService? dates,
    DateTime Function()? nowUtc,
  }) : _db = database,
       _uuid = uuid ?? const Uuid(),
       _dates = dates ?? LocalScheduleDateService(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  Future<List<CoachingConsentEventReadModel>> listConsentHistory({
    required String userId,
    CoachingConsentCategory? category,
  }) async {
    final owner = _owner(userId);
    final rows =
        await (_db.select(_db.coachingConsentEvents)
              ..where(
                (row) =>
                    row.userId.equals(owner) &
                    (category == null
                        ? const Constant(true)
                        : row.consentCategory.equals(category.stableId)),
              )
              ..orderBy([
                (row) => OrderingTerm(
                  expression: row.timestampUtc,
                  mode: OrderingMode.asc,
                ),
                (row) => OrderingTerm(
                  expression: row.createdAtUtc,
                  mode: OrderingMode.asc,
                ),
                (row) =>
                    OrderingTerm(expression: row.id, mode: OrderingMode.asc),
              ]))
            .get();
    return List.unmodifiable([for (final row in rows) _fromRow(row)]);
  }

  Future<CoachingConsentEventReadModel> recordConsent(
    CoachingConsentCommand command,
  ) async {
    _validateConsent(command);
    final owner = _owner(command.userId);
    return _db.transaction(() async {
      final requestedId = command.eventId?.trim();
      if (requestedId != null && requestedId.isNotEmpty) {
        final byId = await (_db.select(
          _db.coachingConsentEvents,
        )..where((row) => row.id.equals(requestedId))).getSingleOrNull();
        if (byId != null) {
          _assertSameConsent(byId, command);
          return _fromRow(byId);
        }
      }

      // A retry may arrive with a newly generated transport ID. The durable
      // event identity is the semantic command tuple, so return the existing
      // event instead of appending a duplicate.
      final sameCommand =
          await (_db.select(_db.coachingConsentEvents)..where(
                (row) =>
                    row.userId.equals(owner) &
                    row.consentCategory.equals(command.category.stableId) &
                    row.action.equals(command.action.stableId) &
                    row.consentPolicyVersion.equals(
                      command.consentPolicyVersion,
                    ) &
                    row.copyVersion.equals(command.copyVersion) &
                    row.timestampUtc.equals(command.timestampUtc.toUtc()),
              ))
              .getSingleOrNull();
      if (sameCommand != null) {
        _assertSameConsent(sameCommand, command);
        return _fromRow(sameCommand);
      }

      final id = requestedId == null || requestedId.isEmpty
          ? _uuid.v4()
          : requestedId;
      if (command.relatedOrSupersededEventId != null) {
        final related =
            await (_db.select(_db.coachingConsentEvents)..where(
                  (row) => row.id.equals(command.relatedOrSupersededEventId!),
                ))
                .getSingleOrNull();
        if (related == null ||
            related.userId != owner ||
            related.consentCategory != command.category.stableId) {
          throw const B04GoalConflictError(
            'invalid_related_consent_event',
            'A consent event may only relate to an event owned by the same user and category.',
          );
        }
        if (!related.timestampUtc.isBefore(command.timestampUtc.toUtc())) {
          throw const B04GoalConflictError(
            'invalid_consent_event_order',
            'A related consent event must precede the new event.',
          );
        }
      }
      final timestamp = command.timestampUtc.toUtc();
      await _db
          .into(_db.coachingConsentEvents)
          .insert(
            db.CoachingConsentEventsCompanion.insert(
              id: id,
              userId: owner,
              consentCategory: command.category.stableId,
              action: command.action.stableId,
              consentPolicyVersion: command.consentPolicyVersion,
              copyVersion: command.copyVersion,
              timestampUtc: timestamp,
              localDate: command.localDate,
              timezoneId: command.timezoneId,
              actorSource: command.actorSource,
              relatedOrSupersededEventId: Value(
                command.relatedOrSupersededEventId,
              ),
              createdAtUtc: Value(_nowUtc().toUtc()),
            ),
          );
      final event = (await (_db.select(
        _db.coachingConsentEvents,
      )..where((row) => row.id.equals(id))).getSingleOrNull());
      if (event == null) {
        throw const B04GoalConflictError(
          'consent_event_not_persisted',
          'The consent event was not persisted.',
        );
      }
      await _refreshProjection(owner);
      return _fromRow(event);
    });
  }

  Future<CoachingPreferencesReadModel> currentPreferences({
    required String userId,
    DateTime? atUtc,
  }) async {
    final owner = _owner(userId);
    final cutoff = (atUtc ?? _nowUtc()).toUtc();
    final rows =
        await (_db.select(_db.coachingConsentEvents)
              ..where(
                (row) =>
                    row.userId.equals(owner) &
                    row.timestampUtc.isSmallerOrEqualValue(cutoff),
              )
              ..orderBy([
                (row) => OrderingTerm(
                  expression: row.timestampUtc,
                  mode: OrderingMode.desc,
                ),
                (row) => OrderingTerm(
                  expression: row.createdAtUtc,
                  mode: OrderingMode.desc,
                ),
                (row) =>
                    OrderingTerm(expression: row.id, mode: OrderingMode.desc),
              ]))
            .get();
    CoachingConsentEventReadModel? adaptive;
    CoachingConsentEventReadModel? ai;
    for (final row in rows) {
      final event = _fromRow(row);
      if (event.category == CoachingConsentCategory.adaptiveCoaching &&
          adaptive == null) {
        adaptive = event;
      }
      if (event.category == CoachingConsentCategory.optionalAi && ai == null) {
        ai = event;
      }
    }
    return CoachingPreferencesReadModel(
      userId: owner,
      adaptiveCoachingEnabled: adaptive?.action == CoachingConsentAction.enable,
      optionalAiEnabled: ai?.action == CoachingConsentAction.enable,
      adaptiveCoachingEvent: adaptive,
      optionalAiEvent: ai,
    );
  }

  Future<CoachingEligibilityReadModel?> currentEligibility({
    required String userId,
    DateTime? atUtc,
  }) async {
    final owner = _owner(userId);
    final cutoff = (atUtc ?? _nowUtc()).toUtc();
    final rows =
        await (_db.select(_db.coachingEligibilityEvaluations)
              ..where(
                (row) =>
                    row.userId.equals(owner) &
                    row.evaluationUtc.isSmallerOrEqualValue(cutoff),
              )
              ..orderBy([
                (row) => OrderingTerm(
                  expression: row.evaluationUtc,
                  mode: OrderingMode.desc,
                ),
                (row) => OrderingTerm(
                  expression: row.createdAtUtc,
                  mode: OrderingMode.desc,
                ),
                (row) =>
                    OrderingTerm(expression: row.id, mode: OrderingMode.desc),
              ]))
            .get();
    if (rows.isEmpty) return null;
    final row = rows.first;
    return CoachingEligibilityReadModel(
      id: row.id,
      userId: row.userId,
      result: _eligibilityResult(row.result),
      reasonCode: row.reasonCode,
      policyVersion: row.policyVersion,
      evaluationLocalDate: row.evaluationLocalDate,
      timezoneId: row.timezoneId,
      evaluationUtc: row.evaluationUtc.toUtc(),
    );
  }

  /// Appends one deterministic age-eligibility evaluation.
  ///
  /// The caller supplies an explicit civil date of birth (or an explicit
  /// unavailable/conflicting state). This command never reads the legacy
  /// profile age integer and never stores the raw date of birth. The hashed
  /// evidence fingerprint is sufficient to make same-day retries idempotent
  /// while allowing a later correction to append a new evaluation.
  Future<CoachingEligibilityReadModel> recordEligibility(
    CoachingEligibilityCommand command,
  ) async {
    _validateEligibilityCommand(command);
    final owner = _owner(command.userId);
    final localDate = _dates.normalizeLocalDate(command.localDate);
    final timezoneId = command.timezoneId.trim();
    final requestedId = command.evaluationId?.trim();
    final source = command.source.stableId;
    final dob = command.dateOfBirthLocalDate == null
        ? null
        : _dates.normalizeLocalDate(command.dateOfBirthLocalDate!);
    final evaluation = _evaluateAge(
      dateOfBirthLocalDate: dob,
      source: command.source,
      localDate: localDate,
    );
    final evidenceFingerprint = _ageEvidenceFingerprint(
      owner: owner,
      source: source,
      dateOfBirthLocalDate: dob,
      localDate: localDate,
      timezoneId: timezoneId,
    );

    return _db.transaction(() async {
      if (requestedId != null && requestedId.isNotEmpty) {
        final existing = await (_db.select(
          _db.coachingEligibilityEvaluations,
        )..where((row) => row.id.equals(requestedId))).getSingleOrNull();
        if (existing != null) {
          _assertSameEligibility(
            existing,
            command: command,
            localDate: localDate,
            timezoneId: timezoneId,
            source: source,
            evaluation: evaluation,
            evidenceFingerprint: evidenceFingerprint,
          );
          return _eligibilityReadModel(existing);
        }
      }

      final latest =
          await (_db.select(_db.coachingEligibilityEvaluations)
                ..where((row) => row.userId.equals(owner))
                ..orderBy([
                  (row) => OrderingTerm(
                    expression: row.evaluationUtc,
                    mode: OrderingMode.desc,
                  ),
                  (row) => OrderingTerm(
                    expression: row.createdAtUtc,
                    mode: OrderingMode.desc,
                  ),
                  (row) =>
                      OrderingTerm(expression: row.id, mode: OrderingMode.desc),
                ])
                ..limit(1))
              .getSingleOrNull();
      // A repeated submission of the same evidence for the same local day is
      // a retry, not a new historical fact. A different fingerprint (for
      // example a corrected DOB) always appends a new row.
      if (latest != null &&
          latest.evidenceFingerprint == evidenceFingerprint &&
          latest.evaluationLocalDate == localDate &&
          latest.timezoneId == timezoneId &&
          latest.policyVersion == command.policyVersion) {
        return _eligibilityReadModel(latest);
      }

      var evaluationUtc = command.evaluationUtc.toUtc();
      if (latest != null && !evaluationUtc.isAfter(latest.evaluationUtc)) {
        evaluationUtc = latest.evaluationUtc.add(const Duration(seconds: 1));
      }
      final id = requestedId == null || requestedId.isEmpty
          ? _uuid.v4()
          : requestedId;
      await _db
          .into(_db.coachingEligibilityEvaluations)
          .insert(
            db.CoachingEligibilityEvaluationsCompanion.insert(
              id: id,
              userId: owner,
              result: evaluation.result.stableId,
              reasonCode: evaluation.reasonCode,
              ageInputSource: source,
              evidenceTimestampUtc: command.evidenceTimestampUtc.toUtc(),
              evaluationUtc: evaluationUtc,
              evaluationLocalDate: localDate,
              timezoneId: timezoneId,
              policyVersion: command.policyVersion,
              minimumAgeRuleVersion: command.minimumAgeRuleVersion,
              evidenceFingerprint: Value(evidenceFingerprint),
            ),
          );
      final row = await (_db.select(
        _db.coachingEligibilityEvaluations,
      )..where((item) => item.id.equals(id))).getSingleOrNull();
      if (row == null) {
        throw const B04GoalConflictError(
          'eligibility_not_persisted',
          'The eligibility evaluation was not persisted.',
        );
      }
      return _eligibilityReadModel(row);
    });
  }

  Future<CoachingAvailabilityReadModel> adaptiveAvailability({
    required String userId,
    DateTime? atUtc,
  }) async {
    final preferences = await currentPreferences(userId: userId, atUtc: atUtc);
    final eligibility = await currentEligibility(userId: userId, atUtc: atUtc);
    if (!preferences.adaptiveCoachingEnabled) {
      return CoachingAvailabilityReadModel(
        available: false,
        reasonCode: 'coaching_consent_required',
        eligibility: eligibility,
        preferences: preferences,
      );
    }
    if (eligibility == null || !eligibility.isEligible) {
      return CoachingAvailabilityReadModel(
        available: false,
        reasonCode: eligibility?.reasonCode ?? 'coaching_unavailable_age',
        eligibility: eligibility,
        preferences: preferences,
      );
    }
    if (eligibility.policyVersion != kB04EnabledPolicyVersion) {
      return CoachingAvailabilityReadModel(
        available: false,
        reasonCode: 'adaptive_policy_hold',
        eligibility: eligibility,
        preferences: preferences,
      );
    }
    return CoachingAvailabilityReadModel(
      available: true,
      reasonCode: 'eligible',
      eligibility: eligibility,
      preferences: preferences,
    );
  }

  Future<void> _refreshProjection(String owner) async {
    final preferences = await currentPreferences(userId: owner);
    await _db
        .into(_db.nutritionCoachingPreferences)
        .insertOnConflictUpdate(
          db.NutritionCoachingPreferencesCompanion.insert(
            id: 'coaching-preferences:$owner',
            userId: owner,
            adaptiveCoachingEnabled: Value(preferences.adaptiveCoachingEnabled),
            optionalAiEnabled: Value(preferences.optionalAiEnabled),
            projectionVersion: const Value(1),
            updatedAtUtc: Value(_nowUtc().toUtc()),
          ),
        );
  }

  void _validateConsent(CoachingConsentCommand command) {
    if (_owner(command.userId).isEmpty ||
        command.consentPolicyVersion.trim().isEmpty ||
        command.copyVersion.trim().isEmpty ||
        command.actorSource.trim().isEmpty) {
      throw const B04GoalValidationError(
        'invalid_consent_command',
        'Consent requires an owner, policy/copy versions and actor source.',
      );
    }
    _dates.normalizeLocalDate(command.localDate);
    _dates.validateTimezone(command.timezoneId);
    if (command.timestampUtc.isUtc == false) {
      // Naive/local timestamps cannot be replayed deterministically.
      throw const B04GoalValidationError(
        'consent_timestamp_not_utc',
        'Consent timestamps must be explicit UTC instants.',
      );
    }
  }

  void _assertSameConsent(
    db.CoachingConsentEvent row,
    CoachingConsentCommand command,
  ) {
    if (row.userId != _owner(command.userId) ||
        row.consentCategory != command.category.stableId ||
        row.action != command.action.stableId ||
        row.consentPolicyVersion != command.consentPolicyVersion ||
        row.copyVersion != command.copyVersion ||
        row.timestampUtc.toUtc() != command.timestampUtc.toUtc() ||
        row.localDate != command.localDate ||
        row.timezoneId != command.timezoneId ||
        row.actorSource != command.actorSource ||
        row.relatedOrSupersededEventId != command.relatedOrSupersededEventId) {
      throw const B04GoalConflictError(
        'consent_event_id_conflict',
        'The consent event ID is already used for different content.',
      );
    }
  }

  CoachingConsentEventReadModel _fromRow(db.CoachingConsentEvent row) =>
      CoachingConsentEventReadModel(
        id: row.id,
        userId: row.userId,
        category: row.consentCategory == 'adaptive_coaching'
            ? CoachingConsentCategory.adaptiveCoaching
            : CoachingConsentCategory.optionalAi,
        action: switch (row.action) {
          'enable' => CoachingConsentAction.enable,
          'disable' => CoachingConsentAction.disable,
          'withdraw' => CoachingConsentAction.withdraw,
          _ => throw const B04GoalValidationError(
            'invalid_consent_action',
            'The stored consent action is not supported.',
          ),
        },
        consentPolicyVersion: row.consentPolicyVersion,
        copyVersion: row.copyVersion,
        timestampUtc: row.timestampUtc.toUtc(),
        localDate: row.localDate,
        timezoneId: row.timezoneId,
        actorSource: row.actorSource,
        relatedOrSupersededEventId: row.relatedOrSupersededEventId,
      );

  static CoachingEligibilityResult _eligibilityResult(String value) =>
      switch (value) {
        'eligible' => CoachingEligibilityResult.eligible,
        'underage' => CoachingEligibilityResult.underage,
        'unknown_age' => CoachingEligibilityResult.unknownAge,
        'conflicting_age' => CoachingEligibilityResult.conflictingAge,
        'withheld_age' => CoachingEligibilityResult.withheldAge,
        'invalid_evidence' => CoachingEligibilityResult.invalidEvidence,
        'policy_unavailable' => CoachingEligibilityResult.policyUnavailable,
        _ => throw const B04GoalValidationError(
          'invalid_eligibility_result',
          'The stored eligibility result is not supported.',
        ),
      };

  CoachingEligibilityReadModel _eligibilityReadModel(
    db.CoachingEligibilityEvaluation row,
  ) => CoachingEligibilityReadModel(
    id: row.id,
    userId: row.userId,
    result: _eligibilityResult(row.result),
    reasonCode: row.reasonCode,
    policyVersion: row.policyVersion,
    evaluationLocalDate: row.evaluationLocalDate,
    timezoneId: row.timezoneId,
    evaluationUtc: row.evaluationUtc.toUtc(),
  );

  _EligibilityEvaluation _evaluateAge({
    required String? dateOfBirthLocalDate,
    required CoachingAgeEvidenceSource source,
    required String localDate,
  }) {
    switch (source) {
      case CoachingAgeEvidenceSource.missing:
        return const _EligibilityEvaluation(
          result: CoachingEligibilityResult.unknownAge,
          reasonCode: 'age_missing',
        );
      case CoachingAgeEvidenceSource.unknown:
        return const _EligibilityEvaluation(
          result: CoachingEligibilityResult.unknownAge,
          reasonCode: 'age_unknown',
        );
      case CoachingAgeEvidenceSource.withheld:
        return const _EligibilityEvaluation(
          result: CoachingEligibilityResult.withheldAge,
          reasonCode: 'age_withheld',
        );
      case CoachingAgeEvidenceSource.conflicting:
        return const _EligibilityEvaluation(
          result: CoachingEligibilityResult.conflictingAge,
          reasonCode: 'age_conflicting',
        );
      case CoachingAgeEvidenceSource.invalid:
        return const _EligibilityEvaluation(
          result: CoachingEligibilityResult.invalidEvidence,
          reasonCode: 'age_invalid',
        );
      case CoachingAgeEvidenceSource.userEnteredDob:
      case CoachingAgeEvidenceSource.verifiedDob:
        if (dateOfBirthLocalDate == null) {
          return const _EligibilityEvaluation(
            result: CoachingEligibilityResult.invalidEvidence,
            reasonCode: 'age_invalid',
          );
        }
        final birth = _civilDate(dateOfBirthLocalDate);
        final current = _civilDate(localDate);
        if (birth.isAfter(current)) {
          return const _EligibilityEvaluation(
            result: CoachingEligibilityResult.invalidEvidence,
            reasonCode: 'age_invalid',
          );
        }
        var years = current.year - birth.year;
        if (current.month < birth.month ||
            (current.month == birth.month && current.day < birth.day)) {
          years -= 1;
        }
        return years >= 18
            ? const _EligibilityEvaluation(
                result: CoachingEligibilityResult.eligible,
                reasonCode: 'eligible',
              )
            : const _EligibilityEvaluation(
                result: CoachingEligibilityResult.underage,
                reasonCode: 'coaching_unavailable_age',
              );
    }
  }

  void _validateEligibilityCommand(CoachingEligibilityCommand command) {
    if (_owner(command.userId).isEmpty ||
        command.minimumAgeRuleVersion.trim().isEmpty ||
        command.policyVersion.trim().isEmpty) {
      throw const B04GoalValidationError(
        'invalid_eligibility_command',
        'Eligibility requires an owner and versioned policy rules.',
      );
    }
    if (command.policyVersion != kB04EnabledPolicyVersion) {
      throw const B04GoalValidationError(
        'unsupported_eligibility_policy',
        'Eligibility must use the reviewed B04 age policy version.',
      );
    }
    _dates.normalizeLocalDate(command.localDate);
    _dates.validateTimezone(command.timezoneId);
    final evaluationUtc = command.evaluationUtc.toUtc();
    final evidenceUtc = command.evidenceTimestampUtc.toUtc();
    if (!command.evaluationUtc.isUtc || !command.evidenceTimestampUtc.isUtc) {
      throw const B04GoalValidationError(
        'eligibility_timestamp_not_utc',
        'Eligibility timestamps must be explicit UTC instants.',
      );
    }
    final derivedDate = _dates.localDateFor(evaluationUtc, command.timezoneId);
    if (derivedDate != _dates.normalizeLocalDate(command.localDate)) {
      throw const B04GoalValidationError(
        'eligibility_local_date_mismatch',
        'Eligibility local date must match the evaluation timezone.',
      );
    }
    if (evidenceUtc.isAfter(evaluationUtc)) {
      throw const B04GoalValidationError(
        'eligibility_evidence_after_evaluation',
        'Age evidence cannot be recorded after its evaluation.',
      );
    }
    final hasDob = command.dateOfBirthLocalDate?.trim().isNotEmpty == true;
    final dobSource =
        command.source == CoachingAgeEvidenceSource.userEnteredDob ||
        command.source == CoachingAgeEvidenceSource.verifiedDob;
    if (dobSource != hasDob) {
      throw const B04GoalValidationError(
        'eligibility_evidence_source_mismatch',
        'Date-of-birth evidence must match its explicit source state.',
      );
    }
    if (!dobSource && hasDob) {
      throw const B04GoalValidationError(
        'eligibility_unexpected_dob',
        'Unavailable age states cannot carry a date of birth.',
      );
    }
    if (hasDob) _dates.normalizeLocalDate(command.dateOfBirthLocalDate!);
  }

  void _assertSameEligibility(
    db.CoachingEligibilityEvaluation row, {
    required CoachingEligibilityCommand command,
    required String localDate,
    required String timezoneId,
    required String source,
    required _EligibilityEvaluation evaluation,
    required String evidenceFingerprint,
  }) {
    if (row.userId != _owner(command.userId) ||
        row.result != evaluation.result.stableId ||
        row.reasonCode != evaluation.reasonCode ||
        row.ageInputSource != source ||
        row.evaluationLocalDate != localDate ||
        row.timezoneId != timezoneId ||
        row.policyVersion != command.policyVersion ||
        row.minimumAgeRuleVersion != command.minimumAgeRuleVersion ||
        row.evidenceFingerprint != evidenceFingerprint) {
      throw const B04GoalConflictError(
        'eligibility_evaluation_id_conflict',
        'The eligibility evaluation ID is already used for different evidence.',
      );
    }
  }

  String _ageEvidenceFingerprint({
    required String owner,
    required String source,
    required String? dateOfBirthLocalDate,
    required String localDate,
    required String timezoneId,
  }) {
    final value = [
      owner,
      source,
      dateOfBirthLocalDate ?? '',
      localDate,
      timezoneId,
      kB04MinimumAgeRuleVersion,
    ].join('|');
    return sha256.convert(value.codeUnits).toString();
  }

  static DateTime _civilDate(String value) {
    final year = int.parse(value.substring(0, 4));
    final month = int.parse(value.substring(5, 7));
    final day = int.parse(value.substring(8, 10));
    return DateTime.utc(year, month, day);
  }

  static String _owner(String userId) => userId.trim();
}

class _EligibilityEvaluation {
  final CoachingEligibilityResult result;
  final String reasonCode;

  const _EligibilityEvaluation({
    required this.result,
    required this.reasonCode,
  });
}
