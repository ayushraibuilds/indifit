import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';

/// Fixed Manifest Version for Exercise Identity Fixtures.
const int kExerciseManifestVersion = 1;

/// Fixed Namespace UUID for IndiFit Exercise Identity (v5 fallback UUIDs).
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
class ExerciseIdentityNormalizer {
  static String normalize(String name) {
    if (name.isEmpty) return '';
    final collapsed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    return collapsed.toLowerCase();
  }
}

/// Manifest containing deterministic catalog identities, approved aliases, and ambiguous fixtures.
class ExerciseCatalogManifest {
  static const int manifestVersion = kExerciseManifestVersion;
  static const Uuid _uuidGen = Uuid();

  /// Static immutable golden UUID map for all 140 bundled catalog exercises (v1).
  /// Decouples exercise identity completely from dynamic string evaluation.
  static const Map<String, String> goldenCatalogUuids = {
    'flat barbell bench press': '089ec703-a25e-5b12-a39a-78b17ee33742',
    'flat barbell bench press (standard)':
        'b70e7a1c-ec87-578f-bfeb-8fbdbceaf2ca',
    'pause flat barbell bench press': 'f5d1ceeb-fe66-51f7-bd58-6c3e9874a969',
    'slow eccentric flat barbell bench press':
        'f9c0eb18-fc35-515c-bf18-f9bf6e1e1a5f',
    'incline dumbbell bench press': '256fb9bd-77a8-5ea5-ab07-cb10d65bce67',
    'incline dumbbell bench press (standard)':
        '2d6bbfa9-7c25-5463-b8c2-4a5eec542dd7',
    'pause incline dumbbell bench press':
        'c3c0efc1-7d1a-512c-afbf-aa58832a8435',
    'slow eccentric incline dumbbell bench press':
        '6dbfc969-9524-5d55-8dd2-8eb99a9b708d',
    'chest dips': '74aa39bb-ff5a-5ff7-8cbe-e75878af3cf3',
    'chest dips (standard)': '8fe2c474-0f11-5d9c-be8a-c60318ce992e',
    'pause chest dips': '2fa5be19-f538-5182-82dc-df4c0840cb8f',
    'slow eccentric chest dips': '52495689-5ee4-59e5-b1a7-640a45fd8100',
    'push-ups': '91fe3e17-b76e-57b1-b4ef-bc615cb38c5d',
    'push-ups (standard)': 'b20a3a7f-ae82-5555-89f5-19ae1fa3c749',
    'pause push-ups': 'bfdfef59-a292-5ee3-a5aa-c3a5e845c43d',
    'slow eccentric push-ups': 'c01c0c9e-561b-53c8-aa5e-26fbd0eb4e5e',
    'cable chest flyes': 'd1ea21fb-ca2a-5fe4-b529-1a48c66e2c3e',
    'cable chest flyes (standard)': 'dbafb9d3-d2eb-5460-a2ef-98cf1eb19bc5',
    'pause cable chest flyes': '8470a7d9-c020-5fe8-ba68-d0bfebe706e2',
    'slow eccentric cable chest flyes': '61bc7ff5-e8d9-5e92-ba7d-fe3910c22d4f',
    'barbell deadlift': 'b102bfa4-6cc5-5e60-accb-82a1ae39b8bc',
    'barbell deadlift (standard)': '7fd950ce-79e5-5558-86d7-fc197b1026ea',
    'pause barbell deadlift': '18b6bdf9-9941-5bb1-9369-1c8d73f41560',
    'slow eccentric barbell deadlift': '3bc421ec-ab46-5c7c-a9fb-ce137b9bf737',
    'lat pulldown': '30dcad52-0a4d-55a4-a33b-e8923f85a51a',
    'lat pulldown (standard)': '924f6bfe-7c00-5dca-b6a0-9bbd38771b0f',
    'pause lat pulldown': 'a9424a05-8453-52ea-aee4-b94ae2a2fbfe',
    'slow eccentric lat pulldown': 'aa3707c7-fc1b-51cf-987c-7fd002d64e5e',
    'bent over barbell row': '84011c13-4413-5779-8e7c-64f6a7860c68',
    'bent over barbell row (standard)': '325be024-0a2a-5752-81c3-117d833ca80b',
    'pause bent over barbell row': '82bc5ef4-2fcc-5752-8c52-3f407263cacd',
    'slow eccentric bent over barbell row':
        '0f26c6a6-7e5f-5099-aa2e-b8ee59d2c99e',
    'one-arm dumbbell row': 'b353d5f5-6116-5410-b6b3-50b2d78aea57',
    'one-arm dumbbell row (standard)': 'c920003d-fd67-5632-af80-571261d344d6',
    'pause one-arm dumbbell row': 'ecdbffb9-e1c9-516a-a217-cf42bad1a131',
    'slow eccentric one-arm dumbbell row':
        '11191d4f-9d7c-5501-9d1e-6dc1e172273c',
    'pull-ups': '4e17e360-9f97-5cd4-a68c-c9dc1dcd7724',
    'pull-ups (standard)': '15b91f5f-c007-5afa-98c0-8e2154eb84b6',
    'pause pull-ups': '96fa8741-f9d7-51a8-b9a6-8276c0d48e9a',
    'slow eccentric pull-ups': 'f1fd96e9-e59c-54dd-ab83-9ee1ad3747be',
    'seated cable row': '9fae7317-b8a5-5f5c-ba93-9d1611fb21dc',
    'seated cable row (standard)': 'a9996115-566e-5d9a-b7b4-2634ffe5e97c',
    'pause seated cable row': 'e78325b4-b36a-5bf3-a6a8-c7e5eecb1066',
    'slow eccentric seated cable row': '916b7eb0-fa0c-5e4c-b7e9-57635901091f',
    'barbell squat': 'd3b5ab04-74f6-5155-9621-50238644eeda',
    'barbell squat (standard)': '73d7db9e-67f2-5311-a106-31bca1914a95',
    'pause barbell squat': '3bf3d06e-5e1d-5d47-b05f-0b954ec89de9',
    'slow eccentric barbell squat': '1b4fa856-03b8-5c6b-81ca-8df9b13721d4',
    'leg press': '081ed879-f46b-592a-8982-345f0f01dd3f',
    'leg press (standard)': '1b692ec8-40d9-53e5-a7dd-47af7606d42b',
    'pause leg press': 'd167dea0-e52d-59dd-9ad9-1c597bbf65ab',
    'slow eccentric leg press': '26ce5ae7-2f08-55a2-b015-c60ae6307d3b',
    'romanian deadlift (rdl)': '7887c839-1b15-5005-a0c9-b942842548e3',
    'romanian deadlift (rdl) (standard)':
        '8f4249e1-62c9-50be-a30c-e5f90b0b61ff',
    'pause romanian deadlift (rdl)': '5742f3b8-9595-591c-a042-bc11a162840c',
    'slow eccentric romanian deadlift (rdl)':
        'ccfda1c6-c811-538c-89cf-be67fa8fe932',
    'leg extensions': '568fcfd9-bb09-5299-a898-801e93216770',
    'leg extensions (standard)': '7c25a9f3-00af-5e09-b667-a6f9d9c024e2',
    'pause leg extensions': '56feb751-efbb-5302-902d-940d45697261',
    'slow eccentric leg extensions': 'e87b0d6a-0a2c-595b-b241-89fc0d6f32fb',
    'seated leg curl': '59ff6c53-7932-57e3-a546-07ac2aa457ae',
    'seated leg curl (standard)': '84776ac4-f142-55cd-92f6-fa35a74956d3',
    'pause seated leg curl': '9fb9ee61-0792-5eef-a5f7-923914649294',
    'slow eccentric seated leg curl': '4f035379-6a9e-52a9-bb2b-b4c608808ba6',
    'standing calf raise': '426ff89a-6639-51d1-a6c1-33184586bbed',
    'standing calf raise (standard)': 'b1e568c2-89f5-5689-b8d7-ee46d1205cf1',
    'pause standing calf raise': '419c463a-1d6a-5e6c-9000-54832b5116f5',
    'slow eccentric standing calf raise':
        '3c34c8f2-ce64-5f74-b002-e55775759e6d',
    'walking lunges': 'd8a67487-1f7a-5bed-b1aa-62537870b25b',
    'walking lunges (standard)': '13e0d854-7591-586e-813f-4a462fbd1722',
    'pause walking lunges': 'f187e832-fdfa-5c75-a9bd-2cb19ff122f7',
    'slow eccentric walking lunges': 'a6b5fe22-9279-5ade-8f1e-f7d1cc323f80',
    'overhead barbell press': 'd2674149-5f1c-529b-9e3e-136fef2d8933',
    'overhead barbell press (standard)': '93e0d927-843c-55e1-aa47-39071e715a63',
    'pause overhead barbell press': '209a82cb-2a0f-5905-8d1a-a35cf35945fb',
    'slow eccentric overhead barbell press':
        '1f05a67e-8cc2-5b02-a6b9-76bee46e3beb',
    'seated dumbbell shoulder press': '37088aa5-6989-5241-8ad9-23f1687a9435',
    'seated dumbbell shoulder press (standard)':
        '1976abfd-1c4a-5d9c-8788-2f86ee8f1b61',
    'pause seated dumbbell shoulder press':
        'e6d19944-fd95-5213-9bcb-89b1cc507ab4',
    'slow eccentric seated dumbbell shoulder press':
        'ea431a7f-19b8-5e5e-9e4c-da6298f4c50e',
    'dumbbell lateral raise': 'c6422f26-c3ca-5a2b-9796-e4a3c17d1563',
    'dumbbell lateral raise (standard)': '5a039bbb-5edf-50a9-bbb5-3f349555689d',
    'pause dumbbell lateral raise': '0fa6d488-a6a9-56e0-ad16-401162373b19',
    'slow eccentric dumbbell lateral raise':
        'b095c880-f806-5b29-a2e0-300632a48796',
    'dumbbell front raise': '7acd7ccb-01ec-5c3a-80c8-7797efcd3302',
    'dumbbell front raise (standard)': '7834b7ff-ccfb-5d3b-b06a-0d36f1621841',
    'pause dumbbell front raise': 'e3003cca-416b-599f-a691-c2d976688108',
    'slow eccentric dumbbell front raise':
        'd095fe23-fbe7-5944-a9e9-b244cc6c52ce',
    'face pulls': '5e5620d2-4170-5f2a-bd3d-a1c0070480c9',
    'face pulls (standard)': 'b8dbb448-b55b-524a-94e8-b485abc563db',
    'pause face pulls': 'f76c4d8d-6b3f-5ac7-8589-1dedba951634',
    'slow eccentric face pulls': '84e64439-e26f-5ad4-80ab-587f29ff1a74',
    'standing barbell curl': '6c8e559c-a8f8-59f0-a761-81d9c4cf4aa7',
    'standing barbell curl (standard)': '5a555f32-2b94-58b7-a627-708df73096f9',
    'pause standing barbell curl': 'c1b4df37-8a58-5053-8f41-f6aeb8990f8f',
    'slow eccentric standing barbell curl':
        '37582935-75f9-5fe3-aa4e-8891f6fdc35a',
    'dumbbell hammer curl': '93760f3b-6f76-5856-9e79-0022911863cc',
    'dumbbell hammer curl (standard)': 'b9ba7916-de0c-5068-a4e1-39fa395b0a31',
    'pause dumbbell hammer curl': '4cab0e37-bdbe-53e9-bf46-50309381ea17',
    'slow eccentric dumbbell hammer curl':
        '64074bfd-2840-5974-ba9e-2e3e46748509',
    'incline dumbbell curl': 'a5650e7a-0cb9-5acb-8d66-889d2289e647',
    'incline dumbbell curl (standard)': '9b638815-f580-511c-9f06-3d3fa0e12d0a',
    'pause incline dumbbell curl': 'aecb66d9-5817-5093-83c6-1e56a236854e',
    'slow eccentric incline dumbbell curl':
        '58200cd2-1ea4-509a-8ef9-77467602f9af',
    'preacher curl': 'cb6bc77b-5a4b-5b00-9e8a-4d0c790f37a7',
    'preacher curl (standard)': 'b6e6e3a7-6896-5362-ba5c-68b66c70263b',
    'pause preacher curl': '5433b78a-3583-56f4-a264-cb1c6495af7b',
    'slow eccentric preacher curl': '4e154d93-302a-5ccb-97a9-fa684cbffbf2',
    'tricep pushdown': '9cb62691-e65f-56f4-9a93-c82a4834a448',
    'tricep pushdown (standard)': '680d6269-6d0f-5d37-bc56-c851de59ef76',
    'pause tricep pushdown': '8c01c75a-b425-53ac-9892-7b5d3f2d664c',
    'slow eccentric tricep pushdown': '4119c3bb-cd5a-5027-91e4-5d3edd747a30',
    'skull crushers (ez bar)': 'b8f0b194-2d41-5514-bc2c-a2bdabbe056e',
    'skull crushers (ez bar) (standard)':
        'a570013f-3743-5c80-8f40-5fed726b4925',
    'pause skull crushers (ez bar)': '1230840b-9006-525b-a392-bfe9faf7cfe5',
    'slow eccentric skull crushers (ez bar)':
        '1fc82856-abad-5a9f-ae6c-73069ff0c36b',
    'overhead dumbbell tricep extension':
        '4f71798e-7893-51a2-b542-090c03df5cb6',
    'overhead dumbbell tricep extension (standard)':
        '81d3dde6-4f93-586f-8f76-c96256e82135',
    'pause overhead dumbbell tricep extension':
        '386ded7b-1307-5ebb-b76d-f5dde4cb1ec3',
    'slow eccentric overhead dumbbell tricep extension':
        '8dd8f09b-5e0c-56b7-bb45-55d58947db72',
    'ab wheel rollout': 'bdd4c5a6-ea2b-55e0-a6e0-206ea683b886',
    'ab wheel rollout (standard)': '3163de96-3fc3-533d-ab06-70ac27ae214c',
    'pause ab wheel rollout': '73601fc7-0d6a-5b78-84d4-499399470903',
    'slow eccentric ab wheel rollout': '695681c5-e86f-5bcc-930a-85d2ef73f583',
    'cable crunch': '0bce1172-7f1c-5d38-9581-0bc2fc6807bb',
    'cable crunch (standard)': '8ea9c7c8-75d9-53d1-a1d6-fefe851f1688',
    'pause cable crunch': '29c7bd7d-342a-54ba-ad69-ebef5f15a7e2',
    'slow eccentric cable crunch': '85c25be6-ccbd-5b87-9e4a-1edac4359256',
    'plank': '3525a526-c7a6-5d33-9758-4428da2760b6',
    'plank (standard)': '6edde0de-7492-5b33-ab28-5f27747c0bbc',
    'pause plank': 'c166fed2-3d32-5641-94e5-8ea16ec447eb',
    'slow eccentric plank': 'ab2ee7bc-cc73-55a9-b542-31821cac14ca',
    'hanging leg raise': '803fcabc-ad1c-52ac-b956-9e85a593c6f3',
    'hanging leg raise (standard)': '4d83d57c-2da7-50e0-a69f-f8dabc69135d',
    'pause hanging leg raise': '704c2f48-894c-5197-9232-236d83fd8118',
    'slow eccentric hanging leg raise': 'da4d6b6f-ec07-5d98-b994-cb0bea76a66f',
  };

  /// Explicitly approved 1-to-1 alias mappings (normalized alias -> exact canonical catalog name).
  static const Map<String, String> approvedAliases = {
    'push-ups': 'Push-Ups',
    'push ups': 'Push-Ups',
    'pushup': 'Push-Ups',
    'pushups': 'Push-Ups',
    'barbell squats': 'Barbell Squat',
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
    'lat pulldown machine': 'Lat Pulldown',
    'cable row': 'Seated Cable Row',
    'cable face pulls': 'Face Pulls',
    'ez bar skull crushers': 'Skull Crushers (EZ Bar)',
    'skullcrushers': 'Skull Crushers (EZ Bar)',
  };

  /// Explicitly classified ambiguous legacy exercise names that MUST NOT resolve automatically.
  static const Set<String> ambiguousLegacyNames = {
    'dumbbell curls',
    'dumbbell curl',
    'leg curl machine',
    'leg curl',
    'dumbbell bench press',
    'squats',
    'squat',
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

  /// Parses catalog entries from decoded JSON list or versioned JSON map.
  factory ExerciseCatalogManifest.fromJson(dynamic jsonPayload) {
    List<dynamic> jsonList;
    if (jsonPayload is Map) {
      final map = Map<String, dynamic>.from(jsonPayload);
      final version = map['version'] as int? ?? manifestVersion;
      if (version != manifestVersion) {
        throw FormatException(
          'Unsupported manifest version: $version. Expected $manifestVersion.',
        );
      }
      final rawList = map['exercises'];
      if (rawList is! List) {
        throw const FormatException(
          'Manifest "exercises" payload must be a JSON array.',
        );
      }
      jsonList = rawList;
    } else if (jsonPayload is List) {
      jsonList = jsonPayload;
    } else {
      throw const FormatException(
        'Manifest payload must be a JSON array or object.',
      );
    }

    final entries = <CanonicalExerciseEntry>[];
    for (final item in jsonList) {
      if (item is! Map) {
        throw const FormatException(
          'Catalog exercise entry must be a JSON object.',
        );
      }
      final map = Map<String, dynamic>.from(item);
      final name = map['name'] as String? ?? '';
      if (name.trim().isEmpty) {
        throw const FormatException(
          'Malformed catalog exercise entry with empty name.',
        );
      }
      final normalized = ExerciseIdentityNormalizer.normalize(name);

      // Explicit immutable UUID assignment:
      // 1. Explicit 'uuid' in JSON entry if present
      // 2. Static golden UUID lookup table (manifest v1)
      // 3. Fallback UUID v5 generation (explicitly bound)
      final String uuid =
          map['uuid'] as String? ??
          goldenCatalogUuids[normalized] ??
          _uuidGen.v5(kIndiFitExerciseNamespaceUuid, normalized);

      entries.add(
        CanonicalExerciseEntry(
          uuid: uuid,
          name: name,
          normalizedName: normalized,
          muscleGroups: map['muscle_groups'] as String? ?? '',
          equipment: map['equipment'] as String? ?? '',
          difficulty: map['difficulty'] as String? ?? '',
        ),
      );
    }
    return ExerciseCatalogManifest._(entries);
  }

  /// Factory for raw list compatibility.
  factory ExerciseCatalogManifest.fromJsonList(List<dynamic> jsonList) {
    return ExerciseCatalogManifest.fromJson(jsonList);
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
    final decoded = jsonDecode(content);
    return ExerciseCatalogManifest.fromJson(decoded);
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
    final decoded = jsonDecode(content);
    return ExerciseCatalogManifest.fromJson(decoded);
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

    // 2. Approved 1-to-1 alias match
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

    // 4. Unresolved / User-created custom exercise (preserves user name and raw input)
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
