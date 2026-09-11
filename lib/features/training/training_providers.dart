import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/core_providers.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/b02_execution_compatibility_read_repository.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/repositories/equipment_preference_repository.dart';
import '../../data/repositories/legacy_program_compatibility_adapter.dart';
import '../../data/repositories/plan_library_read_repository.dart';
import '../../data/repositories/plan_overview_read_repository.dart';
import '../../data/repositories/program_activation_coordinator.dart';
import '../../data/repositories/program_lifecycle_repository.dart';
import '../../data/repositories/program_repository.dart';

final programRepositoryProvider = Provider<ProgramRepository>((ref) {
  return ProgramRepository(ref.watch(databaseProvider));
});

final planLibraryReadRepositoryProvider = Provider<PlanLibraryReadRepository>(
  (ref) => PlanLibraryReadRepository(
    ref.watch(databaseProvider),
    programs: ref.watch(programRepositoryProvider),
  ),
);

/// The Plan Library is a read projection of the canonical program graph and
/// active-version pointer. Mutations still flow through B01 repositories and
/// coordinators; this signal only makes mounted library routes reconcile.
final planLibraryRevisionProvider = StreamProvider.autoDispose<Object>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .tableUpdates(
        TableUpdateQuery.onAllTables([
          db.programs,
          db.programVersions,
          db.programBlocks,
          db.programWeeks,
          db.sessionTemplates,
          db.exercisePrescriptions,
          db.exerciseGroups,
          db.exerciseGroupMembers,
          db.trainingPlanSettings,
        ]),
      )
      // Table-update streams establish their subscription with an initial
      // emission. Ignore that baseline so the read provider does not
      // invalidate itself while it is still constructing its first value.
      .skip(1)
      .map<Object>((_) => Object());
});

final planLibrarySnapshotProvider =
    FutureProvider.autoDispose<PlanLibrarySnapshot>((ref) {
      ref.watch(planLibraryRevisionProvider);
      return ref.watch(planLibraryReadRepositoryProvider).read();
    });

final planOverviewReadRepositoryProvider = Provider<PlanOverviewReadRepository>(
  (ref) {
    return PlanOverviewReadRepository(
      plans: ref.watch(planLibraryReadRepositoryProvider),
      calendar: ref.watch(calendarReadRepositoryProvider),
      history: B02ExecutionCompatibilityReadRepository(
        ref.watch(databaseProvider),
      ),
      dates: ref.watch(localScheduleDateServiceProvider),
    );
  },
);

/// One read invalidation boundary for the plan overview. The overview does
/// not own any of these tables; this only asks its composed read authorities
/// to refresh when structure, occurrences, or saved history changes.
final planOverviewRevisionProvider = StreamProvider.autoDispose<Object>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .tableUpdates(
        TableUpdateQuery.onAllTables([
          db.programs,
          db.programVersions,
          db.programBlocks,
          db.programWeeks,
          db.sessionTemplates,
          db.exercisePrescriptions,
          db.exerciseGroups,
          db.exerciseGroupMembers,
          db.trainingPlanSettings,
          db.scheduledSessionOccurrences,
          db.workoutSessions,
          db.performedExerciseGroups,
          db.performedExercises,
          db.performedSets,
          db.performedSetSegments,
          db.cardioSessionDetails,
          db.cardioIntervals,
          db.mobilitySessionDetails,
        ]),
      )
      .skip(1)
      .map<Object>((_) => Object());
});

final planOverviewSnapshotProvider = FutureProvider.autoDispose
    .family<PlanOverviewSnapshot?, String>((ref, versionId) async {
      ref.watch(planOverviewRevisionProvider);
      final timezoneId = await ref
          .watch(localTimezoneServiceProvider)
          .currentTimezoneId();
      return ref
          .watch(planOverviewReadRepositoryProvider)
          .read(versionId: versionId, timezoneId: timezoneId);
    });

final programActivationCoordinatorProvider =
    Provider<ProgramActivationCoordinator>((ref) {
      return ProgramActivationCoordinator(
        ref.watch(databaseProvider),
        dates: ref.watch(localScheduleDateServiceProvider),
      );
    });

final programLifecycleRepositoryProvider = Provider<ProgramLifecycleRepository>(
  (ref) => ProgramLifecycleRepository(ref.watch(databaseProvider)),
);

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(
    ref.watch(databaseProvider),
    dates: ref.watch(localScheduleDateServiceProvider),
  );
});

final calendarReadRepositoryProvider = Provider<CalendarReadRepository>((ref) {
  return CalendarReadRepository(
    ref.watch(databaseProvider),
    dates: ref.watch(localScheduleDateServiceProvider),
  );
});

final equipmentProfileRepositoryProvider = Provider<EquipmentProfileRepository>(
  (ref) {
    return EquipmentProfileRepository(ref.watch(databaseProvider));
  },
);

/// Compatibility alias for callers not yet migrated to the bounded-context
/// name. It is the same provider/owner, not a second authority.
final equipmentRepositoryProvider = equipmentProfileRepositoryProvider;

final exercisePreferenceRepositoryProvider =
    Provider<ExercisePreferenceRepository>((ref) {
      return ExercisePreferenceRepository(ref.watch(databaseProvider));
    });

final programListProvider = StreamProvider<List<Program>>((ref) {
  return ref.watch(programRepositoryProvider).watchAllPrograms();
});

final programVersionDetailProvider =
    StreamProvider.family<ProgramDetailAggregate?, String>((ref, versionId) {
      return ref
          .watch(programRepositoryProvider)
          .watchProgramVersionDetail(versionId);
    });

final equipmentProfileListProvider = StreamProvider<List<EquipmentProfile>>((
  ref,
) {
  return ref.watch(equipmentProfileRepositoryProvider).watchActiveProfiles();
});

final defaultEquipmentProfileIdProvider = StreamProvider<String?>((ref) {
  return ref.watch(equipmentProfileRepositoryProvider).watchDefaultProfileId();
});

final exercisePreferenceAggregateProvider =
    StreamProvider.family<
      ExercisePreferenceAggregate?,
      ExercisePreferenceLookup
    >((ref, lookup) {
      return ref
          .watch(exercisePreferenceRepositoryProvider)
          .watchPreference(stableId: lookup.stableId, rawName: lookup.rawName);
    });

final legacyProgramCompatibilityAdapterProvider =
    Provider<LegacyProgramCompatibilityAdapter>((ref) {
      return LegacyProgramCompatibilityAdapter(ref.watch(databaseProvider));
    });
