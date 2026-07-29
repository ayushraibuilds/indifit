import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

/// Equipment profile item input DTO.
class EquipmentProfileItemInput {
  final String equipmentCode;
  final bool isAvailable;
  final double? weightIncrementKg;

  const EquipmentProfileItemInput({
    required this.equipmentCode,
    this.isAvailable = true,
    this.weightIncrementKg,
  });
}

/// Durable repository for managing equipment profiles and profile item availability.
class EquipmentRepository {
  final AppDatabase db;
  final Uuid _uuid;

  /// Standard equipment codes recognized by the application system.
  static const Set<String> standardEquipmentCodes = {
    'barbell',
    'dumbbell',
    'cable',
    'machine',
    'bodyweight',
    'smith_machine',
    'kettlebell',
    'bands',
    'plate',
    'cardio_treadmill',
    'cardio_bike',
    'cardio_rower',
    'cardio_elliptical',
    'other',
  };

  EquipmentRepository(this.db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  /// Gets all active (non-archived) equipment profiles.
  Future<List<EquipmentProfile>> getActiveProfiles() async {
    return (db.select(db.equipmentProfiles)
          ..where((t) => t.archivedAtUtc.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  /// Gets a profile by ID along with its equipment item availability list.
  Future<EquipmentProfile?> getProfileById(String profileId) async {
    return (db.select(
      db.equipmentProfiles,
    )..where((t) => t.id.equals(profileId))).getSingleOrNull();
  }

  /// Gets all items associated with an equipment profile ID.
  Future<List<EquipmentProfileItem>> getItemsForProfile(
    String profileId,
  ) async {
    return (db.select(
      db.equipmentProfileItems,
    )..where((t) => t.equipmentProfileId.equals(profileId))).get();
  }

  /// Returns the current default equipment profile ID from TrainingPlanSettings singleton.
  Future<String?> getDefaultProfileId() async {
    final settings = await (db.select(
      db.trainingPlanSettings,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    return settings?.defaultEquipmentProfileId;
  }

  /// Sets the default equipment profile ID in TrainingPlanSettings singleton.
  Future<void> setDefaultProfileId(String profileId) async {
    final profile = await getProfileById(profileId);
    if (profile == null) {
      throw StateError('Equipment profile $profileId does not exist.');
    }
    if (profile.archivedAtUtc != null) {
      throw StateError('Cannot set archived profile $profileId as default.');
    }

    final now = DateTime.now().toUtc();
    final settings = await (db.select(
      db.trainingPlanSettings,
    )..where((t) => t.id.equals(1))).getSingleOrNull();

    if (settings == null) {
      await db
          .into(db.trainingPlanSettings)
          .insert(
            TrainingPlanSettingsCompanion.insert(
              id: const Value(1),
              defaultEquipmentProfileId: Value(profileId),
              updatedAtUtc: now,
            ),
          );
    } else {
      await (db.update(
        db.trainingPlanSettings,
      )..where((t) => t.id.equals(1))).write(
        TrainingPlanSettingsCompanion(
          defaultEquipmentProfileId: Value(profileId),
          updatedAtUtc: Value(now),
        ),
      );
    }
  }

  /// Creates a new equipment profile with item availability overrides.
  Future<String> createProfile({
    required String name,
    double? defaultWeightIncrementKg,
    String? legacyAccessCode,
    String? note,
    List<EquipmentProfileItemInput>? items,
  }) async {
    final now = DateTime.now().toUtc();
    final profileId = _uuid.v4();

    return db.transaction(() async {
      await db
          .into(db.equipmentProfiles)
          .insert(
            EquipmentProfilesCompanion.insert(
              id: profileId,
              name: name,
              defaultWeightIncrementKg: Value(defaultWeightIncrementKg),
              legacyAccessCode: Value(legacyAccessCode),
              note: Value(note),
              createdAtUtc: now,
              updatedAtUtc: now,
            ),
          );

      if (items != null) {
        for (final item in items) {
          await db
              .into(db.equipmentProfileItems)
              .insert(
                EquipmentProfileItemsCompanion.insert(
                  id: _uuid.v4(),
                  equipmentProfileId: profileId,
                  equipmentCode: item.equipmentCode,
                  isAvailable: Value(item.isAvailable),
                  weightIncrementKg: Value(item.weightIncrementKg),
                ),
              );
        }
      }

      return profileId;
    });
  }

  /// Updates an equipment profile and replaces its items.
  Future<void> updateProfile({
    required String profileId,
    String? name,
    double? defaultWeightIncrementKg,
    String? note,
    List<EquipmentProfileItemInput>? items,
  }) async {
    final profile = await getProfileById(profileId);
    if (profile == null) {
      throw StateError('Profile $profileId not found.');
    }
    if (profile.archivedAtUtc != null) {
      throw StateError('Cannot update archived profile $profileId.');
    }

    final now = DateTime.now().toUtc();

    return db.transaction(() async {
      await (db.update(
        db.equipmentProfiles,
      )..where((t) => t.id.equals(profileId))).write(
        EquipmentProfilesCompanion(
          name: name != null ? Value(name) : const Value.absent(),
          defaultWeightIncrementKg: defaultWeightIncrementKg != null
              ? Value(defaultWeightIncrementKg)
              : const Value.absent(),
          note: note != null ? Value(note) : const Value.absent(),
          updatedAtUtc: Value(now),
        ),
      );

      if (items != null) {
        await (db.delete(
          db.equipmentProfileItems,
        )..where((t) => t.equipmentProfileId.equals(profileId))).go();
        for (final item in items) {
          await db
              .into(db.equipmentProfileItems)
              .insert(
                EquipmentProfileItemsCompanion.insert(
                  id: _uuid.v4(),
                  equipmentProfileId: profileId,
                  equipmentCode: item.equipmentCode,
                  isAvailable: Value(item.isAvailable),
                  weightIncrementKg: Value(item.weightIncrementKg),
                ),
              );
        }
      }
    });
  }

  /// Archives an equipment profile with safety checks.
  Future<void> archiveProfile(String profileId) async {
    final defaultId = await getDefaultProfileId();
    if (defaultId == profileId) {
      throw StateError(
        'Cannot archive profile $profileId because it is currently the default equipment profile.',
      );
    }

    final activeTravel =
        await (db.select(db.travelContexts)..where(
              (t) =>
                  t.equipmentProfileId.equals(profileId) &
                  t.status.equals('active'),
            ))
            .get();
    if (activeTravel.isNotEmpty) {
      throw StateError(
        'Cannot archive profile $profileId because it is in use by an active travel context.',
      );
    }

    final now = DateTime.now().toUtc();
    await (db.update(
      db.equipmentProfiles,
    )..where((t) => t.id.equals(profileId))).write(
      EquipmentProfilesCompanion(
        archivedAtUtc: Value(now),
        updatedAtUtc: Value(now),
      ),
    );
  }

  /// Evaluates whether an exercise equipment requirement is satisfied by a given profile.
  /// Bodyweight is always implicitly available across all profiles.
  Future<bool> isEquipmentAvailable({
    required String profileId,
    required String equipmentCode,
  }) async {
    final code = equipmentCode.trim().toLowerCase();
    if (code == 'bodyweight' || code == 'none' || code.isEmpty) {
      return true;
    }

    final item =
        await (db.select(db.equipmentProfileItems)..where(
              (t) =>
                  t.equipmentProfileId.equals(profileId) &
                  t.equipmentCode.equals(code),
            ))
            .getSingleOrNull();

    // If explicit item exists, check isAvailable. If no explicit item exists, assume available if standard.
    return item?.isAvailable ?? true;
  }
}

/// Setup value DTO.
class SetupValueInput {
  final int ordinal;
  final String label;
  final String value;

  const SetupValueInput({
    required this.ordinal,
    required this.label,
    required this.value,
  });
}

/// Exercise preference aggregate read model.
class ExercisePreferenceAggregate {
  final ExerciseUserPreference preference;
  final List<ExerciseSetupValue> setupValues;
  final List<ExercisePersonalCue> personalCues;

  const ExercisePreferenceAggregate({
    required this.preference,
    required this.setupValues,
    required this.personalCues,
  });
}

/// Durable repository for exercise-level user setup preferences, notes, and personal cues.
class ExercisePreferenceRepository {
  final AppDatabase db;
  final Uuid _uuid;

  ExercisePreferenceRepository(this.db, [Uuid? uuid])
    : _uuid = uuid ?? const Uuid();

  /// Computes a portable identity key for preference lookup.
  static String computeIdentityKey({String? stableId, String? rawName}) {
    if (stableId != null && stableId.isNotEmpty) {
      return stableId;
    }
    if (rawName != null && rawName.isNotEmpty) {
      return 'raw_name:${rawName.trim().toLowerCase()}';
    }
    throw ArgumentError(
      'Either stableId or rawName must be provided to compute an identityKey.',
    );
  }

  /// Gets preference aggregate by stable ID or raw exercise name fallback.
  Future<ExercisePreferenceAggregate?> getPreference({
    String? stableId,
    String? rawName,
  }) async {
    final key = computeIdentityKey(stableId: stableId, rawName: rawName);
    final pref = await (db.select(
      db.exerciseUserPreferences,
    )..where((t) => t.identityKey.equals(key))).getSingleOrNull();
    if (pref == null) return null;

    final setups =
        await (db.select(db.exerciseSetupValues)
              ..where((t) => t.exerciseUserPreferenceId.equals(pref.id))
              ..orderBy([(t) => OrderingTerm(expression: t.ordinal)]))
            .get();

    final cues =
        await (db.select(db.exercisePersonalCues)
              ..where((t) => t.exerciseUserPreferenceId.equals(pref.id))
              ..orderBy([(t) => OrderingTerm(expression: t.ordinal)]))
            .get();

    return ExercisePreferenceAggregate(
      preference: pref,
      setupValues: setups,
      personalCues: cues,
    );
  }

  /// Saves or updates exercise user preferences (general note, setup values, personal cues).
  Future<String> savePreference({
    String? stableId,
    String? rawName,
    String? generalNote,
    List<SetupValueInput>? setupValues,
    List<String>? personalCues,
  }) async {
    final key = computeIdentityKey(stableId: stableId, rawName: rawName);
    final now = DateTime.now().toUtc();

    return db.transaction(() async {
      var pref = await (db.select(
        db.exerciseUserPreferences,
      )..where((t) => t.identityKey.equals(key))).getSingleOrNull();
      final prefId = pref?.id ?? _uuid.v4();

      if (pref == null) {
        await db
            .into(db.exerciseUserPreferences)
            .insert(
              ExerciseUserPreferencesCompanion.insert(
                id: prefId,
                identityKey: key,
                exerciseId: Value(stableId),
                exerciseNameFallback: Value(rawName),
                generalNote: Value(generalNote),
                createdAtUtc: now,
                updatedAtUtc: now,
              ),
            );
      } else {
        await (db.update(
          db.exerciseUserPreferences,
        )..where((t) => t.id.equals(prefId))).write(
          ExerciseUserPreferencesCompanion(
            generalNote: Value(generalNote),
            updatedAtUtc: Value(now),
          ),
        );
      }

      // Replace setup values
      if (setupValues != null) {
        await (db.delete(
          db.exerciseSetupValues,
        )..where((t) => t.exerciseUserPreferenceId.equals(prefId))).go();
        for (final s in setupValues) {
          await db
              .into(db.exerciseSetupValues)
              .insert(
                ExerciseSetupValuesCompanion.insert(
                  id: _uuid.v4(),
                  exerciseUserPreferenceId: prefId,
                  ordinal: s.ordinal,
                  label: s.label,
                  value: s.value,
                ),
              );
        }
      }

      // Replace personal cues
      if (personalCues != null) {
        await (db.delete(
          db.exercisePersonalCues,
        )..where((t) => t.exerciseUserPreferenceId.equals(prefId))).go();
        for (var i = 0; i < personalCues.length; i++) {
          await db
              .into(db.exercisePersonalCues)
              .insert(
                ExercisePersonalCuesCompanion.insert(
                  id: _uuid.v4(),
                  exerciseUserPreferenceId: prefId,
                  ordinal: i,
                  cueText: personalCues[i],
                ),
              );
        }
      }

      return prefId;
    });
  }
}
