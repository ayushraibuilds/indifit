import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import 'calendar_repository.dart';
import 'equipment_preference_repository.dart';

/// Preview result for travel mode coordination before user application.
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
}

/// Durable repository for travel context intervals, occurrence membership, and equipment profile override resolution.
class TravelRepository {
  final AppDatabase db;
  final CalendarRepository calendarRepo;
  final EquipmentProfileRepository equipmentRepo;
  final Uuid _uuid;

  TravelRepository({
    required this.db,
    required this.calendarRepo,
    required this.equipmentRepo,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  /// Previews occurrences affected by a travel date range and assesses equipment compatibility.
  Future<TravelPreviewResult> previewTravelContext({
    required String startLocalDate,
    required String endLocalDate,
    required String timezoneId,
    required String equipmentProfileId,
  }) async {
    final occurrences = await calendarRepo.getOccurrencesInLocalDateRange(
      startLocalDate: startLocalDate,
      endLocalDate: endLocalDate,
      includeTerminal: false,
    );

    final incompatibleMap = <String, List<String>>{};

    for (final occ in occurrences) {
      final tmpl = await (db.select(
        db.sessionTemplates,
      )..where((t) => t.id.equals(occ.sessionTemplateId))).getSingleOrNull();
      if (tmpl == null) continue;

      final prescriptions = await (db.select(
        db.exercisePrescriptions,
      )..where((t) => t.sessionTemplateId.equals(tmpl.id))).get();

      final incompatibleList = <String>[];
      for (final rx in prescriptions) {
        // Fetch exercise equipment if available
        String requiredEquip = 'other';
        if (rx.exerciseId != null) {
          final ex = await (db.select(
            db.exercises,
          )..where((t) => t.stableId.equals(rx.exerciseId!))).getSingleOrNull();
          if (ex != null) {
            requiredEquip = ex.equipment;
          }
        }

        final isAvailable = await equipmentRepo.isEquipmentAvailable(
          profileId: equipmentProfileId,
          equipmentCode: requiredEquip,
        );

        if (!isAvailable) {
          incompatibleList.add(rx.exerciseNameSnapshot);
        }
      }

      if (incompatibleList.isNotEmpty) {
        incompatibleMap[occ.id] = incompatibleList;
      }
    }

    return TravelPreviewResult(
      startLocalDate: startLocalDate,
      endLocalDate: endLocalDate,
      timezoneId: timezoneId,
      equipmentProfileId: equipmentProfileId,
      affectedOccurrences: occurrences,
      occurrenceIncompatibleExercises: incompatibleMap,
    );
  }

  /// Creates and applies a new TravelContext and stores explicit occurrence membership records.
  Future<String> createAndApplyTravelContext({
    required String startLocalDate,
    required String endLocalDate,
    required String timezoneId,
    required String equipmentProfileId,
    String? note,
  }) async {
    final preview = await previewTravelContext(
      startLocalDate: startLocalDate,
      endLocalDate: endLocalDate,
      timezoneId: timezoneId,
      equipmentProfileId: equipmentProfileId,
    );

    final now = DateTime.now().toUtc();
    final travelContextId = _uuid.v4();

    return db.transaction(() async {
      // Cancel any currently active travel contexts
      final existingActive = await (db.select(
        db.travelContexts,
      )..where((t) => t.status.equals('active'))).get();
      for (final active in existingActive) {
        await (db.update(
          db.travelContexts,
        )..where((t) => t.id.equals(active.id))).write(
          TravelContextsCompanion(
            status: const Value('ended'),
            endedAtUtc: Value(now),
          ),
        );
      }

      // Insert new travel context
      await db
          .into(db.travelContexts)
          .insert(
            TravelContextsCompanion.insert(
              id: travelContextId,
              startLocalDate: startLocalDate,
              endLocalDate: endLocalDate,
              timezoneId: timezoneId,
              equipmentProfileId: equipmentProfileId,
              status: const Value('active'),
              note: Value(note),
              createdAtUtc: now,
            ),
          );

      // Insert explicit TravelContextOccurrences membership set
      for (final occ in preview.affectedOccurrences) {
        await db
            .into(db.travelContextOccurrences)
            .insert(
              TravelContextOccurrencesCompanion.insert(
                travelContextId: travelContextId,
                occurrenceId: occ.id,
                confirmedAtUtc: now,
              ),
            );
      }

      return travelContextId;
    });
  }

  /// Cancels an active travel context.
  Future<void> cancelTravelContext(String travelContextId) async {
    final travel = await (db.select(
      db.travelContexts,
    )..where((t) => t.id.equals(travelContextId))).getSingleOrNull();
    if (travel == null) {
      throw StateError('TravelContext $travelContextId not found.');
    }

    final now = DateTime.now().toUtc();
    await (db.update(
      db.travelContexts,
    )..where((t) => t.id.equals(travelContextId))).write(
      TravelContextsCompanion(
        status: const Value('cancelled'),
        endedAtUtc: Value(now),
      ),
    );
  }

  /// Gets the currently active TravelContext if any.
  Future<TravelContext?> getActiveTravelContext({String? localDate}) async {
    final activeContexts = await (db.select(
      db.travelContexts,
    )..where((t) => t.status.equals('active'))).get();

    if (activeContexts.isEmpty) return null;

    if (localDate != null) {
      for (final tc in activeContexts) {
        if (localDate.compareTo(tc.startLocalDate) >= 0 &&
            localDate.compareTo(tc.endLocalDate) <= 0) {
          return tc;
        }
      }
      return null;
    }

    return activeContexts.first;
  }

  /// Resolves the effective equipment profile ID for a given occurrence or date.
  /// If occurrence or date is in active travel context membership, returns travel equipmentProfileId; otherwise returns default equipment profile ID.
  Future<String?> getEffectiveEquipmentProfileId({
    String? occurrenceId,
    String? localDate,
  }) async {
    if (occurrenceId != null) {
      final membership = await (db.select(
        db.travelContextOccurrences,
      )..where((t) => t.occurrenceId.equals(occurrenceId))).getSingleOrNull();
      if (membership != null) {
        final tc =
            await (db.select(db.travelContexts)
                  ..where((t) => t.id.equals(membership.travelContextId)))
                .getSingleOrNull();
        if (tc != null && tc.status == 'active') {
          return tc.equipmentProfileId;
        }
      }
    }

    final activeTravel = await getActiveTravelContext(localDate: localDate);
    if (activeTravel != null) {
      return activeTravel.equipmentProfileId;
    }

    return equipmentRepo.getDefaultProfileId();
  }
}
