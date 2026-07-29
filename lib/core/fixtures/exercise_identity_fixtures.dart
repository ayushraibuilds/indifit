import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';

/// Fixed Namespace UUID for IndiFit Exercise Identity (v5 deterministic UUIDs).
/// Ensures every bundled catalog exercise gets a stable UUID across all runs.
const String kIndiFitExerciseNamespaceUuid =
    '6ba7b811-9dad-11d1-80b4-00c04fd430c8';

/// Status of an exercise identity lookup.
enum ExerciseLookupStatus {
  /// Exact match to canonical catalog entry or approved 1-to-1 alias.
  resolved,

  /// Matches multiple candidate catalog entries and cannot be resolved automatically.
  ambiguous,

  /// Unknown exercise name or custom user exercise; preserved with null canonical UUID.
  unresolved,
}

/// Result of looking up an exercise by name.
class ExerciseLookupResult {
  final ExerciseLookupStatus status;
  final String? canonicalUuid;
  final String? canonicalName;
  final String originalName;

  const ExerciseLookupResult({
    required this.status,
    this.canonicalUuid,
    this.canonicalName,
    required this.originalName,
  });

  bool get isResolved => status == ExerciseLookupStatus.resolved;
  bool get isAmbiguous => status == ExerciseLookupStatus.ambiguous;
  bool get isUnresolved => status == ExerciseLookupStatus.unresolved;

  @override
  String toString() =>
      'ExerciseLookupResult(status: $status, canonicalUuid: $canonicalUuid, canonicalName: $canonicalName, originalName: "$originalName")';
}

/// Canonical entry representing a catalog exercise.
class CanonicalExerciseEntry {
  final String uuid;
  final String name;
  final String normalizedName;
  final String muscleGroups;
  final String equipment;
  final String difficulty;

  const CanonicalExerciseEntry({
    required this.uuid,
    required this.name,
    required this.normalizedName,
    required this.muscleGroups,
    required this.equipment,
    required this.difficulty,
  });
}

/// Normalizer for exercise names.
/// Contract:
/// 1. Trim leading/trailing whitespace
/// 2. Collapse contiguous whitespace characters into a single space
/// 3. Lowercase for case-insensitive matching
/// 4. Does NOT strip technique qualifiers like "(Standard)", "Pause", "Slow Eccentric"
class ExerciseIdentityNormalizer {
  static String normalize(String name) {
    if (name.isEmpty) return '';
    final collapsed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    return collapsed.toLowerCase();
  }
}

/// Manifest containing deterministic catalog identities, approved aliases, and ambiguous fixtures.
class ExerciseCatalogManifest {
  static const Uuid _uuidGen = Uuid();

  /// Generates a deterministic UUID v5 from a normalized catalog exercise name.
  static String generateDeterministicUuid(String normalizedCatalogName) {
    return _uuidGen.v5(kIndiFitExerciseNamespaceUuid, normalizedCatalogName);
  }

  /// Explicitly approved 1-to-1 alias mappings (normalized alias -> exact canonical catalog name).
  static const Map<String, String> approvedAliases = {
    'push-ups': 'Push-Ups',
    'push ups': 'Push-Ups',
    'pushup': 'Push-Ups',
    'pushups': 'Push-Ups',
    'barbell squats': 'Barbell Squat',
    'squat': 'Barbell Squat',
    'seated dumbbell press': 'Seated Dumbbell Shoulder Press',
    'dumbbell shoulder press': 'Seated Dumbbell Shoulder Press',
    'incline dumbbell press': 'Incline Dumbbell Bench Press',
    'single-arm dumbbell row': 'One-Arm Dumbbell Row',
    'single arm dumbbell row': 'One-Arm Dumbbell Row',
    'barbell row': 'Bent Over Barbell Row',
    'leg extension machine': 'Leg Extensions',
    'leg extension': 'Leg Extensions',
    'rdl': 'Romanian Deadlift (RDL)',
    'romanian deadlift': 'Romanian Deadlift (RDL)',
    'flat bench press': 'Flat Barbell Bench Press',
    'bench press': 'Flat Barbell Bench Press',
    'lat pulldown machine': 'Lat Pulldown',
    'cable row': 'Seated Cable Row',
    'cable face pulls': 'Face Pulls',
    'dumbbell curls': 'Dumbbell Hammer Curl',
    'ez bar skull crushers': 'Skull Crushers (EZ Bar)',
    'skullcrushers': 'Skull Crushers (EZ Bar)',
  };

  /// Explicitly classified ambiguous legacy exercise names that MUST NOT resolve automatically.
  static const Set<String> ambiguousLegacyNames = {
    'leg curl machine',
    'leg curl',
    'dumbbell bench press',
    'squats',
    'dips',
    'tricep dips',
    'row',
    'dumbbell bicep curl',
    'bicep dumbbell curl',
    'curl',
    'lunges',
    'extension',
    'press',
  };

  final Map<String, CanonicalExerciseEntry> _catalogByNormalizedName = {};
  final Map<String, CanonicalExerciseEntry> _catalogByUuid = {};

  ExerciseCatalogManifest._(List<CanonicalExerciseEntry> entries) {
    for (final entry in entries) {
      if (_catalogByNormalizedName.containsKey(entry.normalizedName)) {
        throw StateError(
          'Duplicate normalized catalog exercise name: ${entry.normalizedName}',
        );
      }
      if (_catalogByUuid.containsKey(entry.uuid)) {
        throw StateError('Duplicate canonical UUID: ${entry.uuid}');
      }
      _catalogByNormalizedName[entry.normalizedName] = entry;
      _catalogByUuid[entry.uuid] = entry;
    }
  }

  /// Parses catalog entries from decoded JSON list (from assets/data/exercises.json).
  factory ExerciseCatalogManifest.fromJsonList(List<dynamic> jsonList) {
    final entries = <CanonicalExerciseEntry>[];
    for (final item in jsonList) {
      final name = item['name'] as String? ?? '';
      if (name.trim().isEmpty) {
        throw FormatException(
          'Malformed catalog exercise entry with empty name.',
        );
      }
      final normalized = ExerciseIdentityNormalizer.normalize(name);
      final uuid = generateDeterministicUuid(normalized);
      entries.add(
        CanonicalExerciseEntry(
          uuid: uuid,
          name: name,
          normalizedName: normalized,
          muscleGroups: item['muscle_groups'] as String? ?? '',
          equipment: item['equipment'] as String? ?? '',
          difficulty: item['difficulty'] as String? ?? '',
        ),
      );
    }
    return ExerciseCatalogManifest._(entries);
  }

  /// Loads catalog manifest from asset file `assets/data/exercises.json`.
  static Future<ExerciseCatalogManifest> loadFromAssetFile([
    String path = 'assets/data/exercises.json',
  ]) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('Exercise asset file not found at $path', path);
    }
    final content = await file.readAsString();
    final List<dynamic> jsonList = jsonDecode(content);
    return ExerciseCatalogManifest.fromJsonList(jsonList);
  }

  /// Synchronously loads catalog manifest from file path (useful in unit tests).
  static ExerciseCatalogManifest loadFromAssetFileSync([
    String path = 'assets/data/exercises.json',
  ]) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('Exercise asset file not found at $path', path);
    }
    final content = file.readAsStringSync();
    final List<dynamic> jsonList = jsonDecode(content);
    return ExerciseCatalogManifest.fromJsonList(jsonList);
  }

  int get totalEntries => _catalogByNormalizedName.length;

  CanonicalExerciseEntry? getByNormalizedName(String normalizedName) =>
      _catalogByNormalizedName[normalizedName];

  CanonicalExerciseEntry? getByUuid(String uuid) => _catalogByUuid[uuid];

  List<CanonicalExerciseEntry> get allEntries =>
      _catalogByNormalizedName.values.toList();
}

/// Lookup engine for exercise identities.
class ExerciseIdentityLookup {
  final ExerciseCatalogManifest _manifest;

  ExerciseIdentityLookup(this._manifest);

  /// Resolves an input exercise display name to an [ExerciseLookupResult].
  /// Flow:
  /// 1. Exact match against catalog normalized names -> resolved
  /// 2. Match against approved 1-to-1 aliases -> resolved
  /// 3. Match against ambiguous legacy names set -> ambiguous
  /// 4. Otherwise -> unresolved (preserves original display name, null UUID)
  ExerciseLookupResult lookup(String rawName) {
    final originalName = rawName;
    final normalized = ExerciseIdentityNormalizer.normalize(rawName);

    if (normalized.isEmpty) {
      return ExerciseLookupResult(
        status: ExerciseLookupStatus.unresolved,
        originalName: originalName,
      );
    }

    // 1. Direct catalog match
    final directMatch = _manifest.getByNormalizedName(normalized);
    if (directMatch != null) {
      return ExerciseLookupResult(
        status: ExerciseLookupStatus.resolved,
        canonicalUuid: directMatch.uuid,
        canonicalName: directMatch.name,
        originalName: originalName,
      );
    }

    // 2. Approved alias match
    final aliasTarget = ExerciseCatalogManifest.approvedAliases[normalized];
    if (aliasTarget != null) {
      final targetNormalized = ExerciseIdentityNormalizer.normalize(
        aliasTarget,
      );
      final aliasMatch = _manifest.getByNormalizedName(targetNormalized);
      if (aliasMatch != null) {
        return ExerciseLookupResult(
          status: ExerciseLookupStatus.resolved,
          canonicalUuid: aliasMatch.uuid,
          canonicalName: aliasMatch.name,
          originalName: originalName,
        );
      }
    }

    // 3. Ambiguous legacy name match
    if (ExerciseCatalogManifest.ambiguousLegacyNames.contains(normalized)) {
      return ExerciseLookupResult(
        status: ExerciseLookupStatus.ambiguous,
        originalName: originalName,
      );
    }

    // 4. Unresolved / User-created custom exercise
    return ExerciseLookupResult(
      status: ExerciseLookupStatus.unresolved,
      originalName: originalName,
    );
  }

  /// Validates fixture integrity (no alias collisions, valid targets, no orphan aliases).
  void validateFixtures() {
    // 1. Validate approved aliases
    for (final entry in ExerciseCatalogManifest.approvedAliases.entries) {
      final aliasNormalized = entry.key;
      final targetName = entry.value;

      if (aliasNormalized.isEmpty || targetName.isEmpty) {
        throw StateError(
          'Malformed alias entry: "${entry.key}" -> "${entry.value}"',
        );
      }

      final targetNormalized = ExerciseIdentityNormalizer.normalize(targetName);
      final targetMatch = _manifest.getByNormalizedName(targetNormalized);

      if (targetMatch == null) {
        throw StateError(
          'Approved alias "${entry.key}" points to non-existent catalog entry "$targetName"',
        );
      }

      if (ExerciseCatalogManifest.ambiguousLegacyNames.contains(
        aliasNormalized,
      )) {
        throw StateError(
          'Conflict: Alias "${entry.key}" is also listed as ambiguous.',
        );
      }
    }

    // 2. Validate ambiguous names
    for (final ambiguous in ExerciseCatalogManifest.ambiguousLegacyNames) {
      if (ambiguous.isEmpty) {
        throw StateError('Malformed empty ambiguous name entry.');
      }
    }
  }
}
