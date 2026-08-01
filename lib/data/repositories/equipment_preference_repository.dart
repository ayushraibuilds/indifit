import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/fixtures/equipment_fixtures.dart';
import '../../core/fixtures/exercise_identity_fixtures.dart';
import '../database/app_database.dart';
import '../models/b02_execution_models.dart';

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

class EquipmentProfileAggregate {
  final EquipmentProfile profile;
  final List<EquipmentProfileItem> items;

  const EquipmentProfileAggregate({required this.profile, required this.items});
}

enum EquipmentCompatibilityStatus { compatible, incompatible, unknown }

/// A deliberately small compatibility read model. It flags requirements; it
/// never proposes, ranks, or writes a substitution.
class EquipmentCompatibility {
  final EquipmentCompatibilityStatus status;
  final List<String> requiredEquipmentCodes;
  final List<String> unavailableEquipmentCodes;
  final String originalRequirement;

  const EquipmentCompatibility({
    required this.status,
    required this.requiredEquipmentCodes,
    required this.unavailableEquipmentCodes,
    required this.originalRequirement,
  });
}

/// Drift owner for named equipment profiles. Canonical codes are defined once
/// by B01-01's fixture; this repository deliberately has no second registry.
class EquipmentProfileRepository {
  final AppDatabase db;
  final Uuid _uuid;

  /// Derived from the B01-01 fixture rather than maintained as a second list.
  static final Set<String> standardEquipmentCodes = CanonicalEquipmentItem
      .values
      .map((item) => item.id)
      .toSet();

  EquipmentProfileRepository(this.db, [Uuid? uuid])
    : _uuid = uuid ?? const Uuid();

  Future<List<EquipmentProfile>> getActiveProfiles() {
    return (db.select(db.equipmentProfiles)
          ..where((t) => t.archivedAtUtc.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  Stream<List<EquipmentProfile>> watchActiveProfiles() {
    return (db.select(db.equipmentProfiles)
          ..where((t) => t.archivedAtUtc.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<EquipmentProfileAggregate?> getProfile(String profileId) async {
    final profile = await (db.select(
      db.equipmentProfiles,
    )..where((t) => t.id.equals(profileId))).getSingleOrNull();
    if (profile == null) return null;
    return EquipmentProfileAggregate(
      profile: profile,
      items: await getItemsForProfile(profileId),
    );
  }

  Future<EquipmentProfile?> getProfileById(String profileId) {
    return (db.select(
      db.equipmentProfiles,
    )..where((t) => t.id.equals(profileId))).getSingleOrNull();
  }

  Future<List<EquipmentProfileItem>> getItemsForProfile(String profileId) {
    return (db.select(db.equipmentProfileItems)
          ..where((t) => t.equipmentProfileId.equals(profileId))
          ..orderBy([(t) => OrderingTerm(expression: t.equipmentCode)]))
        .get();
  }

  Future<String?> getDefaultProfileId() async {
    final settings = await (db.select(
      db.trainingPlanSettings,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    return settings?.defaultEquipmentProfileId;
  }

  Stream<String?> watchDefaultProfileId() {
    return (db.select(db.trainingPlanSettings)..where((t) => t.id.equals(1)))
        .watchSingleOrNull()
        .map((settings) => settings?.defaultEquipmentProfileId);
  }

  Future<void> setDefaultProfileId(String profileId) async {
    await db.transaction(() async {
      await _requireUsableProfile(profileId);
      final changed =
          await (db.update(
            db.trainingPlanSettings,
          )..where((t) => t.id.equals(1))).write(
            TrainingPlanSettingsCompanion(
              defaultEquipmentProfileId: Value(profileId),
              updatedAtUtc: Value(DateTime.now().toUtc()),
            ),
          );
      if (changed != 1) {
        throw StateError('Training plan settings singleton is missing.');
      }
    });
  }

  Future<void> clearDefaultProfile() async {
    final changed =
        await (db.update(
          db.trainingPlanSettings,
        )..where((t) => t.id.equals(1))).write(
          TrainingPlanSettingsCompanion(
            defaultEquipmentProfileId: const Value(null),
            updatedAtUtc: Value(DateTime.now().toUtc()),
          ),
        );
    if (changed != 1) {
      throw StateError('Training plan settings singleton is missing.');
    }
  }

  Future<String> createProfile({
    required String name,
    double? defaultWeightIncrementKg,
    String? note,
    List<EquipmentProfileItemInput> items = const [],
  }) async {
    final cleanName = _requiredText(name, 'Profile name');
    _validateIncrement(defaultWeightIncrementKg, 'Default weight increment');
    _validateItems(items);
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    await db.transaction(() async {
      await _rejectDuplicateProfileName(cleanName);
      await db
          .into(db.equipmentProfiles)
          .insert(
            EquipmentProfilesCompanion.insert(
              id: id,
              name: cleanName,
              defaultWeightIncrementKg: Value(defaultWeightIncrementKg),
              note: Value(_nullableTrim(note)),
              createdAtUtc: now,
              updatedAtUtc: now,
            ),
          );
      await _replaceItems(id, items);
    });
    return id;
  }

  Future<void> updateProfile({
    required String profileId,
    String? name,
    double? defaultWeightIncrementKg,
    bool clearDefaultWeightIncrement = false,
    String? note,
    bool clearNote = false,
    List<EquipmentProfileItemInput>? items,
  }) async {
    if (name != null) _requiredText(name, 'Profile name');
    if (defaultWeightIncrementKg != null) {
      _validateIncrement(defaultWeightIncrementKg, 'Default weight increment');
    }
    if (items != null) _validateItems(items);
    await db.transaction(() async {
      await _requireUsableProfile(profileId);
      if (name != null) {
        await _rejectDuplicateProfileName(name.trim(), exceptId: profileId);
      }
      await (db.update(
        db.equipmentProfiles,
      )..where((t) => t.id.equals(profileId))).write(
        EquipmentProfilesCompanion(
          name: name == null ? const Value.absent() : Value(name.trim()),
          defaultWeightIncrementKg: clearDefaultWeightIncrement
              ? const Value(null)
              : defaultWeightIncrementKg == null
              ? const Value.absent()
              : Value(defaultWeightIncrementKg),
          note: clearNote
              ? const Value(null)
              : note == null
              ? const Value.absent()
              : Value(_nullableTrim(note)),
          updatedAtUtc: Value(DateTime.now().toUtc()),
        ),
      );
      if (items != null) await _replaceItems(profileId, items);
    });
  }

  /// Archived profiles stay queryable for history. The default and an active
  /// travel override must be changed/ended before archiving.
  Future<void> archiveProfile(String profileId) async {
    await db.transaction(() async {
      final profile = await _requireUsableProfile(profileId);
      final defaultId = await getDefaultProfileId();
      if (defaultId == profileId) {
        throw StateError('A default equipment profile cannot be archived.');
      }
      final activeTravel =
          await (db.select(db.travelContexts)..where(
                (t) =>
                    t.equipmentProfileId.equals(profileId) &
                    t.status.equals('active'),
              ))
              .getSingleOrNull();
      if (activeTravel != null) {
        throw StateError(
          'An active travel override still references this profile.',
        );
      }
      await (db.update(
        db.equipmentProfiles,
      )..where((t) => t.id.equals(profile.id))).write(
        EquipmentProfilesCompanion(
          archivedAtUtc: Value(DateTime.now().toUtc()),
          updatedAtUtc: Value(DateTime.now().toUtc()),
        ),
      );
    });
  }

  Future<EquipmentCompatibility> checkCompatibility({
    required String profileId,
    required String exerciseEquipmentRequirement,
    bool exerciseIdentityResolved = true,
  }) async {
    final profile = await _requireUsableProfile(profileId);
    if (!exerciseIdentityResolved) {
      return EquipmentCompatibility(
        status: EquipmentCompatibilityStatus.unknown,
        requiredEquipmentCodes: const [],
        unavailableEquipmentCodes: const [],
        originalRequirement: exerciseEquipmentRequirement,
      );
    }
    final parsed = EquipmentNormalizer.parseEquipmentString(
      exerciseEquipmentRequirement,
    );
    final requirements = parsed.canonicalItems.map((item) => item.id).toList();
    if (parsed.isUnresolved) {
      return EquipmentCompatibility(
        status: EquipmentCompatibilityStatus.unknown,
        requiredEquipmentCodes: requirements,
        unavailableEquipmentCodes: const [],
        originalRequirement: exerciseEquipmentRequirement,
      );
    }
    if (profile.legacyAccessCode == 'full_gym') {
      return EquipmentCompatibility(
        status: EquipmentCompatibilityStatus.compatible,
        requiredEquipmentCodes: requirements,
        unavailableEquipmentCodes: const [],
        originalRequirement: exerciseEquipmentRequirement,
      );
    }
    final items = await getItemsForProfile(profileId);
    final available = items
        .where((item) => item.isAvailable)
        .map((item) => item.equipmentCode)
        .toSet();
    final missing = requirements
        .where(
          (code) =>
              code != CanonicalEquipmentItem.bodyweight.id &&
              !available.contains(code),
        )
        .toList();
    return EquipmentCompatibility(
      status: missing.isEmpty
          ? EquipmentCompatibilityStatus.compatible
          : EquipmentCompatibilityStatus.incompatible,
      requiredEquipmentCodes: requirements,
      unavailableEquipmentCodes: missing,
      originalRequirement: exerciseEquipmentRequirement,
    );
  }

  Future<bool> isEquipmentAvailable({
    required String profileId,
    required String equipmentCode,
  }) async {
    final canonical = CanonicalEquipmentItem.fromId(equipmentCode.trim());
    if (canonical == null) return false;
    final result = await checkCompatibility(
      profileId: profileId,
      exerciseEquipmentRequirement: canonical.displayName,
    );
    return result.status == EquipmentCompatibilityStatus.compatible;
  }

  Future<void> _replaceItems(
    String profileId,
    List<EquipmentProfileItemInput> items,
  ) async {
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
              equipmentCode: item.equipmentCode.trim(),
              isAvailable: Value(item.isAvailable),
              weightIncrementKg: Value(item.weightIncrementKg),
            ),
          );
    }
  }

  Future<EquipmentProfile> _requireUsableProfile(String profileId) async {
    final profile = await getProfileById(profileId);
    if (profile == null) {
      throw StateError('Equipment profile $profileId not found.');
    }
    if (profile.archivedAtUtc != null) {
      throw StateError(
        'Archived equipment profiles cannot be selected or edited.',
      );
    }
    return profile;
  }

  Future<void> _rejectDuplicateProfileName(
    String name, {
    String? exceptId,
  }) async {
    final profiles = await db.select(db.equipmentProfiles).get();
    final normalized = name.toLowerCase();
    if (profiles.any(
      (profile) =>
          profile.id != exceptId &&
          profile.name.trim().toLowerCase() == normalized,
    )) {
      throw ArgumentError(
        'Equipment profile names must be unique (case-insensitive).',
      );
    }
  }

  static void _validateItems(List<EquipmentProfileItemInput> items) {
    final seen = <String>{};
    for (final item in items) {
      final code = item.equipmentCode.trim();
      final canonical = CanonicalEquipmentItem.fromId(code);
      if (canonical == null) {
        throw ArgumentError('Unknown canonical equipment code "$code".');
      }
      if (canonical == CanonicalEquipmentItem.bodyweight) {
        throw ArgumentError(
          'Bodyweight is an implicit capability, not a profile item.',
        );
      }
      if (!seen.add(code)) {
        throw ArgumentError('Duplicate equipment item "$code".');
      }
      _validateIncrement(item.weightIncrementKg, 'Item weight increment');
    }
  }

  static void _validateIncrement(double? value, String label) {
    if (value != null && (!value.isFinite || value <= 0)) {
      throw ArgumentError('$label must be a positive finite number.');
    }
  }

  static String _requiredText(String value, String label) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) throw ArgumentError('$label must not be blank.');
    return trimmed;
  }

  static String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

/// Legacy temporary name kept only to avoid forcing unrelated callers to move
/// during B01 integration. New code must use [EquipmentProfileRepository].
@Deprecated('Use EquipmentProfileRepository')
class EquipmentRepository extends EquipmentProfileRepository {
  EquipmentRepository(super.db, [super.uuid]);
}

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

/// Typed lookup used by Riverpod; exactly one identity form is accepted by the
/// repository before any database work happens.
class ExercisePreferenceLookup {
  final String? stableId;
  final String? rawName;

  const ExercisePreferenceLookup.stable(this.stableId) : rawName = null;
  const ExercisePreferenceLookup.unresolved(this.rawName) : stableId = null;

  @override
  bool operator ==(Object other) {
    return other is ExercisePreferenceLookup &&
        other.stableId == stableId &&
        other.rawName == rawName;
  }

  @override
  int get hashCode => Object.hash(stableId, rawName);
}

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

/// One Drift-owned reusable preference aggregate. Seeded exercise cues and
/// performed-set notes are intentionally outside this repository.
class ExercisePreferenceRepository {
  final AppDatabase db;
  final Uuid _uuid;

  ExercisePreferenceRepository(this.db, [Uuid? uuid])
    : _uuid = uuid ?? const Uuid();

  static String computeIdentityKey({String? stableId, String? rawName}) {
    final id = stableId?.trim();
    final raw = rawName?.trim();
    if (id != null && id.isNotEmpty && (raw == null || raw.isEmpty)) {
      return 'exercise:$id';
    }
    if ((id == null || id.isEmpty) && raw != null && raw.isNotEmpty) {
      return 'raw_name:${ExerciseIdentityNormalizer.normalize(raw)}';
    }
    throw ArgumentError('Provide exactly one of stableId or rawName.');
  }

  Future<ExercisePreferenceAggregate?> getPreference({
    String? stableId,
    String? rawName,
  }) async {
    final key = computeIdentityKey(stableId: stableId, rawName: rawName);
    return _readPreference(key);
  }

  Future<B02ExerciseExecutionPreference?> getExecutionPreference({
    String? stableId,
    String? rawName,
  }) async {
    final aggregate = await getPreference(stableId: stableId, rawName: rawName);
    final row = aggregate?.preference;
    if (row == null) return null;
    return B02ExerciseExecutionPreference(
      warmupPreference: row.warmupPreference == null
          ? null
          : B02WarmupPreference.parse(row.warmupPreference),
      warmupSetCount: row.warmupSetCount,
      customRestSeconds: row.customRestSeconds,
    );
  }

  Stream<ExercisePreferenceAggregate?> watchPreference({
    String? stableId,
    String? rawName,
  }) {
    final key = computeIdentityKey(stableId: stableId, rawName: rawName);
    late StreamController<ExercisePreferenceAggregate?> controller;
    final subscriptions = <StreamSubscription<void>>[];
    var emitting = false;
    Future<void> emit() async {
      if (emitting || controller.isClosed) return;
      emitting = true;
      try {
        controller.add(await _readPreference(key));
      } finally {
        emitting = false;
      }
    }

    controller = StreamController<ExercisePreferenceAggregate?>(
      onListen: () {
        final watches = <Stream<List<dynamic>>>[
          (db.select(
            db.exerciseUserPreferences,
          )..where((t) => t.identityKey.equals(key))).watch(),
          db.select(db.exerciseSetupValues).watch(),
          db.select(db.exercisePersonalCues).watch(),
        ];
        for (final watch in watches) {
          subscriptions.add(watch.map<void>((_) {}).listen((_) => emit()));
        }
        emit();
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  Future<String> savePreference({
    String? stableId,
    String? rawName,
    bool allowUnresolvedRawFallback = false,
    String? generalNote,
    bool clearGeneralNote = false,
    List<SetupValueInput>? setupValues,
    List<String>? personalCues,
  }) async {
    final key = computeIdentityKey(stableId: stableId, rawName: rawName);
    final hasStableId = stableId != null && stableId.trim().isNotEmpty;
    if (!hasStableId && !allowUnresolvedRawFallback) {
      throw ArgumentError(
        'Raw-name preferences are reserved for explicit unresolved compatibility data.',
      );
    }
    if (setupValues != null || personalCues != null) {
      _validatePreferenceChildren(
        setupValues ?? const [],
        personalCues ?? const [],
      );
    }
    if (hasStableId) {
      final exercise = await (db.select(
        db.exercises,
      )..where((t) => t.stableId.equals(stableId.trim()))).getSingleOrNull();
      if (exercise == null) throw ArgumentError('Unknown stable exercise ID.');
    }
    final now = DateTime.now().toUtc();
    return db.transaction(() async {
      final existing = await (db.select(
        db.exerciseUserPreferences,
      )..where((t) => t.identityKey.equals(key))).getSingleOrNull();
      final id = existing?.id ?? _uuid.v4();
      if (existing == null) {
        await db
            .into(db.exerciseUserPreferences)
            .insert(
              ExerciseUserPreferencesCompanion.insert(
                id: id,
                identityKey: key,
                exerciseId: Value(hasStableId ? stableId.trim() : null),
                exerciseNameFallback: Value(
                  hasStableId ? null : rawName!.trim(),
                ),
                generalNote: Value(_nullableTrim(generalNote)),
                createdAtUtc: now,
                updatedAtUtc: now,
              ),
            );
      } else {
        await (db.update(
          db.exerciseUserPreferences,
        )..where((t) => t.id.equals(id))).write(
          ExerciseUserPreferencesCompanion(
            generalNote: clearGeneralNote
                ? const Value(null)
                : generalNote == null
                ? const Value.absent()
                : Value(_nullableTrim(generalNote)),
            updatedAtUtc: Value(now),
          ),
        );
      }
      if (existing == null || setupValues != null) {
        await _replaceSetupValues(id, setupValues ?? const []);
      }
      if (existing == null || personalCues != null) {
        await _replacePersonalCues(id, personalCues ?? const []);
      }
      return id;
    });
  }

  Future<void> deletePreference({String? stableId, String? rawName}) async {
    final key = computeIdentityKey(stableId: stableId, rawName: rawName);
    await db.transaction(() async {
      final preference = await (db.select(
        db.exerciseUserPreferences,
      )..where((t) => t.identityKey.equals(key))).getSingleOrNull();
      if (preference == null) return;
      await (db.delete(
        db.exerciseSetupValues,
      )..where((t) => t.exerciseUserPreferenceId.equals(preference.id))).go();
      await (db.delete(
        db.exercisePersonalCues,
      )..where((t) => t.exerciseUserPreferenceId.equals(preference.id))).go();
      await (db.delete(
        db.exerciseUserPreferences,
      )..where((t) => t.id.equals(preference.id))).go();
    });
  }

  /// Persists execution settings only for an explicit user action. Automatic
  /// warm-up recommendations and current-session rest adjustments never call
  /// this method implicitly.
  Future<void> saveExecutionPreference({
    String? stableId,
    String? rawName,
    bool allowUnresolvedRawFallback = false,
    B02WarmupPreference? warmupPreference,
    bool clearWarmupPreference = false,
    int? warmupSetCount,
    bool clearWarmupSetCount = false,
    int? customRestSeconds,
    bool clearCustomRestSeconds = false,
  }) async {
    B02ExerciseExecutionPreference(
      warmupPreference: warmupPreference,
      warmupSetCount: warmupSetCount,
      customRestSeconds: customRestSeconds,
    );
    if (warmupPreference == null &&
        !clearWarmupPreference &&
        warmupSetCount == null &&
        !clearWarmupSetCount &&
        customRestSeconds == null &&
        !clearCustomRestSeconds) {
      throw ArgumentError('At least one execution preference must be changed.');
    }
    await savePreference(
      stableId: stableId,
      rawName: rawName,
      allowUnresolvedRawFallback: allowUnresolvedRawFallback,
    );
    final key = computeIdentityKey(stableId: stableId, rawName: rawName);
    final changed =
        await (db.update(
          db.exerciseUserPreferences,
        )..where((t) => t.identityKey.equals(key))).write(
          ExerciseUserPreferencesCompanion(
            warmupPreference: clearWarmupPreference
                ? const Value(null)
                : warmupPreference == null
                ? const Value.absent()
                : Value(warmupPreference.dbValue),
            warmupSetCount: clearWarmupSetCount
                ? const Value(null)
                : warmupSetCount == null
                ? const Value.absent()
                : Value(warmupSetCount),
            customRestSeconds: clearCustomRestSeconds
                ? const Value(null)
                : customRestSeconds == null
                ? const Value.absent()
                : Value(customRestSeconds),
            updatedAtUtc: Value(DateTime.now().toUtc()),
          ),
        );
    if (changed != 1) {
      throw StateError('Exercise execution preference was not saved.');
    }
  }

  Future<ExercisePreferenceAggregate?> _readPreference(String key) async {
    final preference = await (db.select(
      db.exerciseUserPreferences,
    )..where((t) => t.identityKey.equals(key))).getSingleOrNull();
    if (preference == null) return null;
    final setupValues =
        await (db.select(db.exerciseSetupValues)
              ..where((t) => t.exerciseUserPreferenceId.equals(preference.id))
              ..orderBy([(t) => OrderingTerm(expression: t.ordinal)]))
            .get();
    final personalCues =
        await (db.select(db.exercisePersonalCues)
              ..where((t) => t.exerciseUserPreferenceId.equals(preference.id))
              ..orderBy([(t) => OrderingTerm(expression: t.ordinal)]))
            .get();
    return ExercisePreferenceAggregate(
      preference: preference,
      setupValues: setupValues,
      personalCues: personalCues,
    );
  }

  Future<void> _replaceSetupValues(
    String preferenceId,
    List<SetupValueInput> setupValues,
  ) async {
    await (db.delete(
      db.exerciseSetupValues,
    )..where((t) => t.exerciseUserPreferenceId.equals(preferenceId))).go();
    for (final setup in setupValues) {
      await db
          .into(db.exerciseSetupValues)
          .insert(
            ExerciseSetupValuesCompanion.insert(
              id: _uuid.v4(),
              exerciseUserPreferenceId: preferenceId,
              ordinal: setup.ordinal,
              label: setup.label.trim(),
              value: setup.value.trim(),
            ),
          );
    }
  }

  Future<void> _replacePersonalCues(
    String preferenceId,
    List<String> personalCues,
  ) async {
    await (db.delete(
      db.exercisePersonalCues,
    )..where((t) => t.exerciseUserPreferenceId.equals(preferenceId))).go();
    for (var ordinal = 0; ordinal < personalCues.length; ordinal++) {
      await db
          .into(db.exercisePersonalCues)
          .insert(
            ExercisePersonalCuesCompanion.insert(
              id: _uuid.v4(),
              exerciseUserPreferenceId: preferenceId,
              ordinal: ordinal,
              cueText: personalCues[ordinal].trim(),
            ),
          );
    }
  }

  static void _validatePreferenceChildren(
    List<SetupValueInput> setupValues,
    List<String> personalCues,
  ) {
    final ordinals = setupValues.map((setup) => setup.ordinal).toList()..sort();
    for (var index = 0; index < ordinals.length; index++) {
      if (ordinals[index] != index) {
        throw ArgumentError(
          'Setup value ordinals must be contiguous from zero.',
        );
      }
    }
    for (final setup in setupValues) {
      if (setup.label.trim().isEmpty || setup.value.trim().isEmpty) {
        throw ArgumentError('Setup labels and values must not be blank.');
      }
    }
    if (personalCues.any((cue) => cue.trim().isEmpty)) {
      throw ArgumentError('Personal cues must not be blank.');
    }
  }

  static String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
