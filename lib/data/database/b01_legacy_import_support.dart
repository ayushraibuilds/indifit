import 'package:uuid/uuid.dart';

import '../../core/fixtures/exercise_identity_fixtures.dart';

/// Deterministic identifiers and identity lookup used by the one-time v14
/// importer. Backup-v5 import can reuse these rules instead of inventing a
/// second legacy-program or exercise-matching policy.
class B01LegacyImportSupport {
  static const Uuid _uuid = Uuid();

  static final ExerciseCatalogManifest _catalogManifest =
      ExerciseCatalogManifest.fromJsonList([
        for (final entry in ExerciseCatalogManifest.goldenCatalogUuids.entries)
          {'uuid': entry.value, 'name': entry.key},
      ]);

  static final ExerciseIdentityLookup _identityLookup = ExerciseIdentityLookup(
    _catalogManifest,
  );

  static ExerciseLookupResult lookupExerciseName(String rawName) =>
      _identityLookup.lookup(rawName);

  static String legacyExerciseStableId({
    required int sourceExerciseId,
    required String name,
  }) => _id('legacy-exercise:$sourceExerciseId:$name');

  static String programId(int legacyRoutineId) =>
      _id('legacy-program:$legacyRoutineId');

  static String programVersionId(int legacyRoutineId) =>
      _id('legacy-program-version:$legacyRoutineId');

  static String blockId(int legacyRoutineId) =>
      _id('legacy-program-block:$legacyRoutineId');

  static String weekId(int legacyRoutineId) =>
      _id('legacy-program-week:$legacyRoutineId');

  static String sessionTemplateId(int legacyRoutineId, int legacyDayId) =>
      _id('legacy-session-template:$legacyRoutineId:$legacyDayId');

  static String prescriptionId(int legacyRoutineId, int legacyExerciseId) =>
      _id('legacy-prescription:$legacyRoutineId:$legacyExerciseId');

  static String equipmentProfileId(int legacyUserProfileId) =>
      _id('legacy-equipment-profile:$legacyUserProfileId');

  static String equipmentProfileItemId(
    int legacyUserProfileId,
    String equipmentCode,
  ) => _id('legacy-equipment-item:$legacyUserProfileId:$equipmentCode');

  static String _id(String name) =>
      _uuid.v5(Namespace.url.value, 'https://indifit.local/b01/$name');
}
