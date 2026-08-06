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

  static String _owner(String userId) => userId.trim();
}
