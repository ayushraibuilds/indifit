import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/local_schedule_date_service.dart';
import '../database/app_database.dart';
import 'calendar_repository.dart';
import 'equipment_preference_repository.dart';

/// A preview is an explicit user-visible candidate set. Applying it must not
/// re-query the interval and silently pick up a different occurrence.
class TravelPreviewResult {
  final String startLocalDate;
  final String endLocalDate;
  final String timezoneId;
  final String equipmentProfileId;
  final List<ScheduledSessionOccurrence> affectedOccurrences;
  final Map<String, List<String>> occurrenceIncompatibleExercises;

  const TravelPreviewResult({
    required this.startLocalDate,
    required this.endLocalDate,
    required this.timezoneId,
    required this.equipmentProfileId,
    required this.affectedOccurrences,
    required this.occurrenceIncompatibleExercises,
  });

  Set<String> get occurrenceIds =>
      affectedOccurrences.map((row) => row.id).toSet();
}

class TravelPreviewStaleException implements Exception {
  final String message;

  const TravelPreviewStaleException(this.message);

  @override
  String toString() => 'TravelPreviewStaleException: $message';
}

/// A stored membership must be reconciled explicitly when an occurrence moves.
/// There is intentionally no default: a reschedule cannot silently add or
/// retain a travel override.
enum TravelMembershipChoice {
  keepNormal,
  keepTravel,
  addToTravel,
  removeFromTravel,
}

class TravelRescheduleMembershipImpact {
  final TravelContext? context;
  final bool isMember;
  final bool targetIsInsideInterval;

  const TravelRescheduleMembershipImpact({
    required this.context,
    required this.isMember,
    required this.targetIsInsideInterval,
  });

  bool get requiresExplicitChoice => isMember || targetIsInsideInterval;
}

/// The frozen profile provenance used by the scheduled workout adapter.
class EffectiveEquipmentProfileResolution {
  final String? equipmentProfileId;
  final String source;
  final String? travelContextId;

  const EffectiveEquipmentProfileResolution({
    required this.equipmentProfileId,
    required this.source,
    this.travelContextId,
  });

  Map<String, dynamic> toSnapshotJson() => {
    'equipmentProfileId': equipmentProfileId,
    'source': source,
    'travelContextId': travelContextId,
  };
}

/// Durable owner for travel contexts and their explicit occurrence membership.
/// It never rewrites templates, program dates, ordinals, deload flags, or
/// occurrence state without delegating the latter to [CalendarRepository].
class TravelRepository {
  final AppDatabase db;
  final CalendarRepository calendarRepo;
  final EquipmentProfileRepository equipmentRepo;
  final LocalScheduleDateService _dates;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;

  TravelRepository({
    required this.db,
    required this.calendarRepo,
    required this.equipmentRepo,
    LocalScheduleDateService? dates,
    Uuid? uuid,
    DateTime Function()? nowUtc,
  }) : _dates = dates ?? LocalScheduleDateService(nowUtc: nowUtc),
       _uuid = uuid ?? const Uuid(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  /// Finds candidates by their already-stored civil effective date. The
  /// destination zone validates the context but does not convert occurrence
  /// dates: membership is saved explicitly at apply time to avoid later UTC or
  /// cross-zone inference.
  Future<TravelPreviewResult> previewTravelContext({
    required String startLocalDate,
    required String endLocalDate,
    required String timezoneId,
    required String equipmentProfileId,
  }) async {
    final start = _dates.normalizeLocalDate(startLocalDate);
    final end = _dates.normalizeLocalDate(endLocalDate);
    _dates.validateTimezone(timezoneId);
    if (_dates.compare(start, end) > 0) {
      throw ArgumentError(
        'Travel end date must be on or after the start date.',
      );
    }
    await _requireUsableProfile(equipmentProfileId);
    final occurrences = await calendarRepo.getOccurrencesInLocalDateRange(
      startLocalDate: start,
      endLocalDate: end,
      includeTerminal: false,
    );
    final incompatible = <String, List<String>>{};
    for (final occurrence in occurrences) {
      final prescriptions =
          await (db.select(db.exercisePrescriptions)
                ..where(
                  (table) => table.sessionTemplateId.equals(
                    occurrence.sessionTemplateId,
                  ),
                )
                ..orderBy([(table) => OrderingTerm(expression: table.ordinal)]))
              .get();
      final unavailable = <String>[];
      for (final prescription in prescriptions) {
        final exercise = prescription.exerciseId == null
            ? null
            : await (db.select(db.exercises)..where(
                    (table) => table.stableId.equals(prescription.exerciseId!),
                  ))
                  .getSingleOrNull();
        final compatibility = await equipmentRepo.checkCompatibility(
          profileId: equipmentProfileId,
          exerciseEquipmentRequirement: exercise?.equipment ?? '',
          exerciseIdentityResolved: exercise != null,
        );
        if (compatibility.status != EquipmentCompatibilityStatus.compatible) {
          unavailable.add(prescription.exerciseNameSnapshot);
        }
      }
      if (unavailable.isNotEmpty) incompatible[occurrence.id] = unavailable;
    }
    return TravelPreviewResult(
      startLocalDate: start,
      endLocalDate: end,
      timezoneId: timezoneId,
      equipmentProfileId: equipmentProfileId,
      affectedOccurrences: occurrences,
      occurrenceIncompatibleExercises: incompatible,
    );
  }

  /// Persists precisely the previously previewed membership. A stale preview is
  /// rejected, never recomputed, so the user can inspect the changed plan.
  Future<String> createAndApplyTravelContext({
    required TravelPreviewResult preview,
    String? note,
  }) async {
    _validatePreviewEnvelope(preview);
    await _requireUsableProfile(preview.equipmentProfileId);
    final now = _nowUtc().toUtc();
    final id = _uuid.v4();
    return db.transaction(() async {
      final active = await _activeContexts();
      if (active.isNotEmpty) {
        throw StateError(
          'End or cancel the existing travel context before applying another.',
        );
      }
      await _validatePreviewStillCurrent(preview);
      await db
          .into(db.travelContexts)
          .insert(
            TravelContextsCompanion.insert(
              id: id,
              startLocalDate: preview.startLocalDate,
              endLocalDate: preview.endLocalDate,
              timezoneId: preview.timezoneId,
              equipmentProfileId: preview.equipmentProfileId,
              status: const Value('active'),
              note: Value(_nullableTrim(note)),
              createdAtUtc: now,
            ),
          );
      for (final occurrenceId in preview.occurrenceIds) {
        await db
            .into(db.travelContextOccurrences)
            .insert(
              TravelContextOccurrencesCompanion.insert(
                travelContextId: id,
                occurrenceId: occurrenceId,
                confirmedAtUtc: now,
              ),
            );
      }
      return id;
    });
  }

  /// Cancelling is reversible only in the sense that original plan rows are
  /// untouched; the cancelled context and membership remain auditable.
  Future<void> cancelTravelContext(String travelContextId) =>
      _closeTravelContext(travelContextId, status: 'cancelled');

  /// Marks a context as ended without inferring a replacement or shifting any
  /// planned occurrence.
  Future<void> endTravelContext(String travelContextId) =>
      _closeTravelContext(travelContextId, status: 'ended');

  /// Returns the durable active context. Supplying a date asks whether its
  /// inclusive civil interval contains that date; it never converts via UTC.
  Future<TravelContext?> getActiveTravelContext({String? localDate}) async {
    if (localDate != null) {
      final date = _dates.normalizeLocalDate(localDate);
      for (final context in await _activeContexts()) {
        if (_isWithin(context, date)) return context;
      }
      return null;
    }
    final contexts = await _activeContexts();
    return contexts.isEmpty ? null : contexts.single;
  }

  /// Read model for UI badges. Membership is deliberately returned from the
  /// durable, explicit join table rather than inferred from a date range.
  Future<Set<String>> getActiveTravelMembershipIds() async {
    final context = await getActiveTravelContext();
    if (context == null) return const <String>{};
    final rows = await (db.select(
      db.travelContextOccurrences,
    )..where((table) => table.travelContextId.equals(context.id))).get();
    return rows.map((row) => row.occurrenceId).toSet();
  }

  Future<TravelRescheduleMembershipImpact> getRescheduleMembershipImpact({
    required String occurrenceId,
    required String targetLocalDate,
  }) async {
    final target = _dates.normalizeLocalDate(targetLocalDate);
    final membership = await _activeMembershipForOccurrence(occurrenceId);
    final context = membership == null
        ? await getActiveTravelContext(localDate: target)
        : await _contextById(membership.travelContextId);
    return TravelRescheduleMembershipImpact(
      context: context,
      isMember: membership != null,
      targetIsInsideInterval: context != null && _isWithin(context, target),
    );
  }

  /// Coordinates an otherwise normal calendar reschedule with the explicit
  /// membership choice. [CalendarRepository] remains the sole owner of the
  /// occurrence transition/event; this method only maintains travel linkage.
  Future<OccurrenceMutationResult> rescheduleWithMembership({
    required RescheduleOccurrenceCommand command,
    TravelMembershipChoice? membershipChoice,
  }) async {
    final impact = await getRescheduleMembershipImpact(
      occurrenceId: command.occurrenceId,
      targetLocalDate: command.effectiveLocalDate,
    );
    if (impact.requiresExplicitChoice && membershipChoice == null) {
      throw StateError(
        'Rescheduling this occurrence requires a travel membership choice.',
      );
    }
    _validateMembershipChoice(impact, membershipChoice);
    return db.transaction(() async {
      final result = await calendarRepo.reschedule(command);
      final now = _nowUtc().toUtc();
      if (membershipChoice == TravelMembershipChoice.removeFromTravel) {
        await (db.delete(db.travelContextOccurrences)..where(
              (table) => table.occurrenceId.equals(command.occurrenceId),
            ))
            .go();
      } else if (membershipChoice == TravelMembershipChoice.addToTravel) {
        await db
            .into(db.travelContextOccurrences)
            .insert(
              TravelContextOccurrencesCompanion.insert(
                travelContextId: impact.context!.id,
                occurrenceId: command.occurrenceId,
                confirmedAtUtc: now,
              ),
            );
      }
      return result;
    });
  }

  /// Resolves the profile used for a scheduled occurrence. Membership and the
  /// occurrence's *current stored civil date* must both be inside the context;
  /// this restores the normal profile after an explicit move out of travel.
  Future<EffectiveEquipmentProfileResolution> resolveEffectiveProfile({
    required String occurrenceId,
  }) async {
    final occurrence = await calendarRepo.getOccurrence(occurrenceId);
    if (occurrence == null) {
      throw StateError('Scheduled occurrence $occurrenceId not found.');
    }
    final membership = await _activeMembershipForOccurrence(occurrenceId);
    if (membership != null) {
      final context = await _contextById(membership.travelContextId);
      if (context != null &&
          _isWithin(context, occurrence.effectiveLocalDate)) {
        return EffectiveEquipmentProfileResolution(
          equipmentProfileId: context.equipmentProfileId,
          source: 'travel',
          travelContextId: context.id,
        );
      }
    }
    return EffectiveEquipmentProfileResolution(
      equipmentProfileId: await equipmentRepo.getDefaultProfileId(),
      source: 'default',
    );
  }

  /// Date-only read model used by profile screens; a non-member occurrence is
  /// never overridden merely because its date happens to be inside travel.
  Future<String?> getEffectiveEquipmentProfileId({
    String? occurrenceId,
    String? localDate,
  }) async {
    if (occurrenceId != null) {
      return (await resolveEffectiveProfile(
        occurrenceId: occurrenceId,
      )).equipmentProfileId;
    }
    if (localDate != null) {
      final context = await getActiveTravelContext(localDate: localDate);
      if (context != null) return context.equipmentProfileId;
    }
    return equipmentRepo.getDefaultProfileId();
  }

  Future<void> _closeTravelContext(String id, {required String status}) async {
    final changed =
        await (db.update(db.travelContexts)..where(
              (table) => table.id.equals(id) & table.status.equals('active'),
            ))
            .write(
              TravelContextsCompanion(
                status: Value(status),
                endedAtUtc: Value(_nowUtc().toUtc()),
              ),
            );
    if (changed == 0) {
      final context = await _contextById(id);
      if (context == null) throw StateError('TravelContext $id not found.');
    }
  }

  Future<void> _validatePreviewStillCurrent(TravelPreviewResult preview) async {
    for (final expected in preview.affectedOccurrences) {
      final actual = await calendarRepo.getOccurrence(expected.id);
      if (actual == null ||
          actual.status != expected.status ||
          actual.effectiveLocalDate != expected.effectiveLocalDate ||
          actual.effectiveTimezoneId != expected.effectiveTimezoneId ||
          actual.effectiveLocalDate.compareTo(preview.startLocalDate) < 0 ||
          actual.effectiveLocalDate.compareTo(preview.endLocalDate) > 0 ||
          _isTerminal(actual.status)) {
        throw const TravelPreviewStaleException(
          'The travel preview changed. Review the affected occurrences again.',
        );
      }
    }
  }

  Future<List<TravelContext>> _activeContexts() =>
      (db.select(db.travelContexts)
            ..where((table) => table.status.equals('active'))
            ..orderBy([
              (table) => OrderingTerm(expression: table.createdAtUtc),
            ]))
          .get();

  Future<TravelContext?> _contextById(String id) => (db.select(
    db.travelContexts,
  )..where((table) => table.id.equals(id))).getSingleOrNull();

  Future<TravelContextOccurrence?> _activeMembershipForOccurrence(
    String occurrenceId,
  ) async {
    final rows = await (db.select(
      db.travelContextOccurrences,
    )..where((table) => table.occurrenceId.equals(occurrenceId))).get();
    for (final row in rows) {
      final context = await _contextById(row.travelContextId);
      if (context?.status == 'active') return row;
    }
    return null;
  }

  Future<void> _requireUsableProfile(String profileId) async {
    final profile = await equipmentRepo.getProfileById(profileId);
    if (profile == null || profile.archivedAtUtc != null) {
      throw StateError('Travel requires an active equipment profile.');
    }
  }

  bool _isWithin(TravelContext context, String localDate) =>
      localDate.compareTo(context.startLocalDate) >= 0 &&
      localDate.compareTo(context.endLocalDate) <= 0;

  static bool _isTerminal(String status) => const {
    'completed',
    'partiallyCompleted',
    'skipped',
    'cancelled',
  }.contains(status);

  static String? _nullableTrim(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  void _validatePreviewEnvelope(TravelPreviewResult preview) {
    final start = _dates.normalizeLocalDate(preview.startLocalDate);
    final end = _dates.normalizeLocalDate(preview.endLocalDate);
    _dates.validateTimezone(preview.timezoneId);
    if (start != preview.startLocalDate ||
        end != preview.endLocalDate ||
        _dates.compare(start, end) > 0) {
      throw ArgumentError('Travel preview has an invalid civil-date interval.');
    }
  }

  static void _validateMembershipChoice(
    TravelRescheduleMembershipImpact impact,
    TravelMembershipChoice? choice,
  ) {
    if (impact.isMember) {
      if (!impact.targetIsInsideInterval &&
          choice != TravelMembershipChoice.removeFromTravel) {
        throw ArgumentError(
          'An occurrence moved outside travel must be removed from travel.',
        );
      }
      if (impact.targetIsInsideInterval &&
          choice != TravelMembershipChoice.keepTravel &&
          choice != TravelMembershipChoice.removeFromTravel) {
        throw ArgumentError(
          'A travel member must explicitly remain in or leave travel.',
        );
      }
      return;
    }
    if (impact.targetIsInsideInterval &&
        choice != TravelMembershipChoice.addToTravel &&
        choice != TravelMembershipChoice.keepNormal) {
      throw ArgumentError(
        'An occurrence moved into travel must explicitly join or stay normal.',
      );
    }
    if (!impact.targetIsInsideInterval &&
        choice != null &&
        choice != TravelMembershipChoice.keepNormal) {
      throw ArgumentError('No travel membership exists for this move.');
    }
  }
}
