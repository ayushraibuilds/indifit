import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// The checked-in food identity contract version.
const int kFoodIdentityManifestVersion = 1;

/// B03-D02 deliberately permits only case and Unicode-whitespace
/// normalization. Punctuation, preparation words, brands, portions, and
/// fuzzy/substring matching are outside this contract.
const String kFoodIdentityNormalizationVersion =
    'case-and-unicode-whitespace-v1';

const String kFoodIdentityManifestPath =
    'assets/data/nutrition_food_identity_manifest.json';

/// All durable manifest identifiers intentionally share one namespace. A
/// future format must opt into a new namespace version rather than silently
/// changing collision rules.
const String kFoodIdentityIdentityNamespace = 'global-durable-id-v1';

enum FoodIdentityLookupStatus { resolved, ambiguous, unresolved }

enum FoodIdentityKind {
  canonical,
  preparationVariant,
  regionalVariant,
  restaurantEstimate,
  homemadeEstimate,
  branded,
  servingPresentationVariant,
  userCreated,
  imported,
  recipe,
  aiEstimate,
  legacy,
  unknown,
}

enum FoodIdentityReviewState {
  reviewed,
  ambiguous,
  unresolved,
  deprecated,
  manualReview,
  fixture,
}

enum FoodAliasKind { approved, ambiguous }

/// Exact normalization used by durable identity resolution.
class FoodIdentityNormalizer {
  FoodIdentityNormalizer._();

  // Dart's regular-expression `\s` set is supplemented with the Unicode
  // whitespace code points used in imported food labels. No punctuation or
  // semantic word is removed.
  static final RegExp _unicodeWhitespace = RegExp(
    r'[\s\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000]+',
  );

  static String normalize(String value) {
    if (value.isEmpty) return '';
    return value.trim().replaceAll(_unicodeWhitespace, ' ').toLowerCase();
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Food identity field "$key" must be non-empty.');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('Food identity field "$key" must be a string.');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Food identity field "$key" must be a boolean.');
  }
  return value;
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) {
    throw FormatException('Food identity field "$key" must be an object.');
  }
  return Map<String, dynamic>.from(value);
}

Map<String, String> _requiredStringMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) {
    throw FormatException('Food identity field "$key" must be an object.');
  }
  final result = <String, String>{};
  for (final item in value.entries) {
    if (item.key is! String || item.value is! String) {
      throw FormatException(
        'Food identity field "$key" must contain string keys and values.',
      );
    }
    final source = item.key as String;
    final target = item.value as String;
    if (source.trim().isEmpty || target.trim().isEmpty) {
      throw FormatException(
        'Food identity field "$key" cannot contain blank mappings.',
      );
    }
    result[source] = target;
  }
  return result;
}

List<dynamic> _requiredList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Food identity field "$key" must be an array.');
  }
  return value;
}

FoodIdentityKind _kindFromJson(String value) => switch (value) {
  'canonical' => FoodIdentityKind.canonical,
  'preparationVariant' => FoodIdentityKind.preparationVariant,
  'regionalVariant' => FoodIdentityKind.regionalVariant,
  'restaurantEstimate' => FoodIdentityKind.restaurantEstimate,
  'homemadeEstimate' => FoodIdentityKind.homemadeEstimate,
  'branded' => FoodIdentityKind.branded,
  'servingPresentationVariant' => FoodIdentityKind.servingPresentationVariant,
  'userCreated' => FoodIdentityKind.userCreated,
  'imported' => FoodIdentityKind.imported,
  'recipe' => FoodIdentityKind.recipe,
  'aiEstimate' => FoodIdentityKind.aiEstimate,
  'legacy' => FoodIdentityKind.legacy,
  'unknown' => FoodIdentityKind.unknown,
  _ => throw FormatException('Unknown food identity kind: $value'),
};

FoodIdentityReviewState _reviewStateFromJson(String value) => switch (value) {
  'reviewed' => FoodIdentityReviewState.reviewed,
  'ambiguous' => FoodIdentityReviewState.ambiguous,
  'unresolved' => FoodIdentityReviewState.unresolved,
  'deprecated' => FoodIdentityReviewState.deprecated,
  'manualReview' => FoodIdentityReviewState.manualReview,
  'fixture' => FoodIdentityReviewState.fixture,
  _ => throw FormatException('Unknown food identity review state: $value'),
};

FoodAliasKind _aliasKindFromJson(String value) => switch (value) {
  'approved' => FoodAliasKind.approved,
  'ambiguous' => FoodAliasKind.ambiguous,
  _ => throw FormatException('Unknown food alias kind: $value'),
};

/// Source and provider provenance is kept separate from the local database
/// identity. Provider IDs are never used as local primary keys.
class FoodIdentityProvenance {
  static const Set<String> allowedKinds = {
    'bundled_asset',
    'regional_asset',
    'provider',
    'user',
    'import',
    'ai',
    'fixture',
    'legacy',
  };

  final String kind;
  final String key;
  final String revision;
  final String? path;
  final String? providerNamespace;
  final String? externalId;

  const FoodIdentityProvenance({
    required this.kind,
    required this.key,
    required this.revision,
    this.path,
    this.providerNamespace,
    this.externalId,
  });

  factory FoodIdentityProvenance.fromJson(Map<String, dynamic> json) {
    final provenance = FoodIdentityProvenance(
      kind: _requiredString(json, 'kind'),
      key: _requiredString(json, 'key'),
      revision: _requiredString(json, 'revision'),
      path: _optionalString(json, 'path'),
      providerNamespace: _optionalString(json, 'provider_namespace'),
      externalId: _optionalString(json, 'external_id'),
    );
    if (!allowedKinds.contains(provenance.kind)) {
      throw FormatException(
        'Unknown food identity provenance kind: ${provenance.kind}',
      );
    }
    final hasProviderNamespace = provenance.providerNamespace != null;
    final hasExternalId = provenance.externalId != null;
    if (hasProviderNamespace != hasExternalId) {
      throw const FormatException(
        'Provider namespace and external ID must be supplied together.',
      );
    }
    return provenance;
  }

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'key': key,
    'revision': revision,
    'path': path,
    'provider_namespace': providerNamespace,
    'external_id': externalId,
  };
}

/// Explicit evidence for the durable classification of one source row.
///
/// This is deliberately separate from source-file heuristics. A generator
/// may emit a `manualReview` record when this evidence is absent, but it may
/// not manufacture a reviewed classification.
class FoodIdentitySourceReview {
  final String sourceKey;
  final String sourceFingerprint;
  final String targetId;
  final FoodIdentityKind kind;
  final String classification;
  final FoodIdentityReviewState reviewState;
  final String? variantType;
  final String? parentId;
  final String? familyId;
  final String reason;
  final String? evidenceRef;

  const FoodIdentitySourceReview({
    required this.sourceKey,
    required this.sourceFingerprint,
    required this.targetId,
    required this.kind,
    required this.classification,
    required this.reviewState,
    required this.variantType,
    required this.parentId,
    required this.familyId,
    required this.reason,
    required this.evidenceRef,
  });

  factory FoodIdentitySourceReview.fromJson(Map<String, dynamic> json) {
    return FoodIdentitySourceReview(
      sourceKey: _requiredString(json, 'source_key'),
      sourceFingerprint: _requiredString(json, 'source_fingerprint'),
      targetId: _requiredString(json, 'target_id'),
      kind: _kindFromJson(_requiredString(json, 'kind')),
      classification: _requiredString(json, 'classification'),
      reviewState: _reviewStateFromJson(_requiredString(json, 'review_state')),
      variantType: _optionalString(json, 'variant_type'),
      parentId: _optionalString(json, 'parent_id'),
      familyId: _optionalString(json, 'family_id'),
      reason: _requiredString(json, 'reason'),
      evidenceRef: _optionalString(json, 'evidence_ref'),
    );
  }

  Map<String, dynamic> toJson() => {
    'source_key': sourceKey,
    'source_fingerprint': sourceFingerprint,
    'target_id': targetId,
    'kind': kind.name,
    'classification': classification,
    'review_state': reviewState.name,
    'variant_type': variantType,
    'parent_id': parentId,
    'family_id': familyId,
    'reason': reason,
    'evidence_ref': evidenceRef,
  };
}

/// A durable catalogue or materially distinct food identity.
class FoodIdentityEntry {
  final String id;
  final String machineId;
  final String displayName;
  final String normalizedName;
  final FoodIdentityKind kind;
  final String classification;
  final String locale;
  final String region;
  final FoodIdentityProvenance provenance;
  final FoodIdentityReviewState reviewState;
  final bool deprecated;
  final bool isCatalogue;
  final String? variantType;
  final String? parentId;
  final String? familyId;
  final String? replacementId;

  const FoodIdentityEntry({
    required this.id,
    required this.machineId,
    required this.displayName,
    required this.normalizedName,
    required this.kind,
    required this.classification,
    required this.locale,
    required this.region,
    required this.provenance,
    required this.reviewState,
    required this.deprecated,
    required this.isCatalogue,
    this.variantType,
    this.parentId,
    this.familyId,
    this.replacementId,
  });

  factory FoodIdentityEntry.fromJson(Map<String, dynamic> json) {
    final entry = FoodIdentityEntry(
      id: _requiredString(json, 'id'),
      machineId: _requiredString(json, 'machine_id'),
      displayName: _requiredString(json, 'display_name'),
      normalizedName: _requiredString(json, 'normalized_name'),
      kind: _kindFromJson(_requiredString(json, 'kind')),
      classification: _requiredString(json, 'classification'),
      locale: _requiredString(json, 'locale'),
      region: _requiredString(json, 'region'),
      provenance: FoodIdentityProvenance.fromJson(
        _requiredMap(json, 'provenance'),
      ),
      reviewState: _reviewStateFromJson(_requiredString(json, 'review_state')),
      deprecated: _requiredBool(json, 'deprecated'),
      isCatalogue: _requiredBool(json, 'is_catalogue'),
      variantType: _optionalString(json, 'variant_type'),
      parentId: _optionalString(json, 'parent_id'),
      familyId: _optionalString(json, 'family_id'),
      replacementId: _optionalString(json, 'replacement_id'),
    );
    if (entry.normalizedName !=
        FoodIdentityNormalizer.normalize(entry.displayName)) {
      throw FormatException(
        'Normalized name does not match display name for ${entry.id}.',
      );
    }
    return entry;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'machine_id': machineId,
    'display_name': displayName,
    'normalized_name': normalizedName,
    'kind': kind.name,
    'classification': classification,
    'locale': locale,
    'region': region,
    'provenance': provenance.toJson(),
    'review_state': reviewState.name,
    'deprecated': deprecated,
    'is_catalogue': isCatalogue,
    'variant_type': variantType,
    'parent_id': parentId,
    'family_id': familyId,
    'replacement_id': replacementId,
  };
}

/// A reviewed one-to-one alias or an explicitly ambiguous name.
class FoodIdentityAlias {
  final String id;
  final String value;
  final String normalized;
  final FoodAliasKind kind;
  final String? targetId;
  final FoodIdentityReviewState reviewState;
  final FoodIdentityProvenance provenance;

  const FoodIdentityAlias({
    required this.id,
    required this.value,
    required this.normalized,
    required this.kind,
    required this.targetId,
    required this.reviewState,
    required this.provenance,
  });

  factory FoodIdentityAlias.fromJson(Map<String, dynamic> json) {
    return FoodIdentityAlias(
      id: _requiredString(json, 'id'),
      value: _requiredString(json, 'value'),
      normalized: _requiredString(json, 'normalized'),
      kind: _aliasKindFromJson(_requiredString(json, 'kind')),
      targetId: _optionalString(json, 'target_id'),
      reviewState: _reviewStateFromJson(_requiredString(json, 'review_state')),
      provenance: FoodIdentityProvenance.fromJson(
        _requiredMap(json, 'provenance'),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'value': value,
    'normalized': normalized,
    'kind': kind.name,
    'target_id': targetId,
    'review_state': reviewState.name,
    'provenance': provenance.toJson(),
  };
}

/// Explicit compatibility evidence for an old asset/local/source key.
class FoodLegacyMapping {
  final String id;
  final String sourceKey;
  final String sourceType;
  final int? legacyLocalId;
  final String? targetId;
  final FoodIdentityReviewState reviewState;
  final FoodIdentityProvenance provenance;
  final String evidence;

  const FoodLegacyMapping({
    required this.id,
    required this.sourceKey,
    required this.sourceType,
    required this.legacyLocalId,
    required this.targetId,
    required this.reviewState,
    required this.provenance,
    required this.evidence,
  });

  factory FoodLegacyMapping.fromJson(Map<String, dynamic> json) {
    final rawLocalId = json['legacy_local_id'];
    if (rawLocalId != null && rawLocalId is! int) {
      throw const FormatException('Legacy local ID must be an integer.');
    }
    if (rawLocalId is int && rawLocalId < 1) {
      throw const FormatException('Legacy local ID must be positive.');
    }
    return FoodLegacyMapping(
      id: _requiredString(json, 'id'),
      sourceKey: _requiredString(json, 'source_key'),
      sourceType: _requiredString(json, 'source_type'),
      legacyLocalId: rawLocalId as int?,
      targetId: _optionalString(json, 'target_id'),
      reviewState: _reviewStateFromJson(_requiredString(json, 'review_state')),
      provenance: FoodIdentityProvenance.fromJson(
        _requiredMap(json, 'provenance'),
      ),
      evidence: _requiredString(json, 'evidence'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'source_key': sourceKey,
    'source_type': sourceType,
    'legacy_local_id': legacyLocalId,
    'target_id': targetId,
    'review_state': reviewState.name,
    'provenance': provenance.toJson(),
    'evidence': evidence,
  };
}

/// Fixture-only identities that are intentionally outside the canonical seed
/// catalogue, such as user-created, provider, AI-estimate, recipe, and
/// unknown records.
class FoodIdentityFixture {
  final String id;
  final FoodIdentityKind kind;
  final String displayName;
  final String? portableId;
  final String? providerNamespace;
  final String? externalId;
  final String? barcode;
  final String? canonicalTargetId;
  final FoodIdentityReviewState reviewState;
  final FoodIdentityProvenance provenance;

  const FoodIdentityFixture({
    required this.id,
    required this.kind,
    required this.displayName,
    required this.portableId,
    required this.providerNamespace,
    required this.externalId,
    required this.barcode,
    required this.canonicalTargetId,
    required this.reviewState,
    required this.provenance,
  });

  factory FoodIdentityFixture.fromJson(Map<String, dynamic> json) {
    return FoodIdentityFixture(
      id: _requiredString(json, 'id'),
      kind: _kindFromJson(_requiredString(json, 'kind')),
      displayName: _requiredString(json, 'display_name'),
      portableId: _optionalString(json, 'portable_id'),
      providerNamespace: _optionalString(json, 'provider_namespace'),
      externalId: _optionalString(json, 'external_id'),
      barcode: _optionalString(json, 'barcode'),
      canonicalTargetId: _optionalString(json, 'canonical_target_id'),
      reviewState: _reviewStateFromJson(_requiredString(json, 'review_state')),
      provenance: FoodIdentityProvenance.fromJson(
        _requiredMap(json, 'provenance'),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'display_name': displayName,
    'portable_id': portableId,
    'provider_namespace': providerNamespace,
    'external_id': externalId,
    'barcode': barcode,
    'canonical_target_id': canonicalTargetId,
    'review_state': reviewState.name,
    'provenance': provenance.toJson(),
  };
}

class FoodIdentityLookupResult {
  final FoodIdentityLookupStatus status;
  final String originalValue;
  final String normalizedValue;
  final FoodIdentityEntry? entry;
  final FoodIdentityAlias? alias;

  const FoodIdentityLookupResult({
    required this.status,
    required this.originalValue,
    required this.normalizedValue,
    this.entry,
    this.alias,
  });

  bool get isResolved => status == FoodIdentityLookupStatus.resolved;
  bool get isAmbiguous => status == FoodIdentityLookupStatus.ambiguous;
  bool get isUnresolved => status == FoodIdentityLookupStatus.unresolved;
  bool get isDeprecated => entry?.deprecated ?? false;
}

class FoodLegacyLookupResult {
  final FoodIdentityLookupStatus status;
  final String sourceKey;
  final FoodLegacyMapping? mapping;
  final FoodIdentityEntry? entry;

  const FoodLegacyLookupResult({
    required this.status,
    required this.sourceKey,
    this.mapping,
    this.entry,
  });

  bool get isResolved => status == FoodIdentityLookupStatus.resolved;
  bool get isAmbiguous => status == FoodIdentityLookupStatus.ambiguous;
  bool get isUnresolved => status == FoodIdentityLookupStatus.unresolved;
}

/// A complete, atomically loaded food identity manifest.
class FoodIdentityManifest {
  final int version;
  final String normalizationVersion;
  final String identityNamespace;
  final List<FoodIdentityEntry> entries;
  final List<FoodIdentityAlias> aliases;
  final List<FoodLegacyMapping> legacyMappings;
  final List<FoodIdentityFixture> identityFixtures;
  final Map<String, String> sourceToId;
  final Map<String, String> sourceFingerprintToId;
  final Map<String, FoodIdentitySourceReview> sourceReviews;

  late final Map<String, FoodIdentityEntry> _entryById;
  late final Map<String, FoodIdentityEntry> _entryByMachineId;
  late final Map<String, FoodIdentityEntry> _entryBySourceKey;
  late final Map<String, FoodLegacyMapping> _legacyBySourceKey;

  FoodIdentityManifest._({
    required this.version,
    required this.normalizationVersion,
    required this.identityNamespace,
    required List<FoodIdentityEntry> entries,
    required List<FoodIdentityAlias> aliases,
    required List<FoodLegacyMapping> legacyMappings,
    required List<FoodIdentityFixture> identityFixtures,
    required Map<String, String> sourceToId,
    required Map<String, String> sourceFingerprintToId,
    required Map<String, FoodIdentitySourceReview> sourceReviews,
  }) : entries = List.unmodifiable(entries),
       aliases = List.unmodifiable(aliases),
       legacyMappings = List.unmodifiable(legacyMappings),
       identityFixtures = List.unmodifiable(identityFixtures),
       sourceToId = Map.unmodifiable(sourceToId),
       sourceFingerprintToId = Map.unmodifiable(sourceFingerprintToId),
       sourceReviews = Map.unmodifiable(sourceReviews) {
    _validate();
    _entryById = {for (final entry in this.entries) entry.id: entry};
    _entryByMachineId = {
      for (final entry in this.entries) entry.machineId: entry,
    };
    _entryBySourceKey = {
      for (final entry in this.entries) entry.provenance.key: entry,
    };
    _legacyBySourceKey = {
      for (final mapping in this.legacyMappings) mapping.sourceKey: mapping,
    };
  }

  /// Parses and fully validates a decoded manifest before exposing it.
  ///
  /// All lists are built locally and the graph is validated before the
  /// returned object is constructed. A malformed manifest therefore cannot
  /// partially replace a previously loaded manifest.
  factory FoodIdentityManifest.fromJson(dynamic payload) {
    if (payload is! Map) {
      throw const FormatException('Food identity manifest must be an object.');
    }
    final json = Map<String, dynamic>.from(payload);
    final rawVersion = json['version'];
    if (rawVersion is! int) {
      throw const FormatException(
        'Food identity manifest version is required.',
      );
    }
    if (rawVersion != kFoodIdentityManifestVersion) {
      throw FormatException(
        'Unsupported food identity manifest version: $rawVersion. '
        'Expected $kFoodIdentityManifestVersion.',
      );
    }
    final normalizationVersion = _requiredString(json, 'normalization_version');
    if (normalizationVersion != kFoodIdentityNormalizationVersion) {
      throw FormatException(
        'Unsupported food identity normalization version: '
        '$normalizationVersion.',
      );
    }
    final identityNamespace = _requiredString(json, 'identity_namespace');
    if (identityNamespace != kFoodIdentityIdentityNamespace) {
      throw FormatException(
        'Unsupported food identity namespace: $identityNamespace.',
      );
    }

    final entries = _parseList(
      _requiredList(json, 'entries'),
      FoodIdentityEntry.fromJson,
      'entry',
    );
    final aliases = _parseList(
      _requiredList(json, 'aliases'),
      FoodIdentityAlias.fromJson,
      'alias',
    );
    final legacyMappings = _parseList(
      _requiredList(json, 'legacy_mappings'),
      FoodLegacyMapping.fromJson,
      'legacy mapping',
    );
    final identityFixtures = _parseList(
      _requiredList(json, 'identity_fixtures'),
      FoodIdentityFixture.fromJson,
      'identity fixture',
    );
    final sourceToId = _requiredStringMap(json, 'source_to_id');
    final sourceFingerprintToId = _requiredStringMap(
      json,
      'source_fingerprints',
    );
    final rawReviews = _requiredMap(json, 'source_reviews');
    final sourceReviews = <String, FoodIdentitySourceReview>{};
    for (final item in rawReviews.entries) {
      if (item.value is! Map) {
        throw const FormatException(
          'Food identity source_reviews must map strings to objects.',
        );
      }
      final review = FoodIdentitySourceReview.fromJson(
        Map<String, dynamic>.from(item.value as Map),
      );
      if (review.sourceKey != item.key) {
        throw StateError(
          'Source review key ${item.key} does not match ${review.sourceKey}.',
        );
      }
      sourceReviews[item.key] = review;
    }

    return FoodIdentityManifest._(
      version: rawVersion,
      normalizationVersion: normalizationVersion,
      identityNamespace: identityNamespace,
      entries: entries,
      aliases: aliases,
      legacyMappings: legacyMappings,
      identityFixtures: identityFixtures,
      sourceToId: sourceToId,
      sourceFingerprintToId: sourceFingerprintToId,
      sourceReviews: sourceReviews,
    );
  }

  static List<T> _parseList<T>(
    List<dynamic> rawItems,
    T Function(Map<String, dynamic>) parser,
    String label,
  ) {
    final result = <T>[];
    for (final item in rawItems) {
      if (item is! Map) {
        throw FormatException('Food identity $label must be an object.');
      }
      result.add(parser(Map<String, dynamic>.from(item)));
    }
    return result;
  }

  static Future<FoodIdentityManifest> loadFromAsset([
    String path = kFoodIdentityManifestPath,
  ]) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException(
        'Food identity manifest not found at $path',
        path,
      );
    }
    final decoded = jsonDecode(await file.readAsString());
    return FoodIdentityManifest.fromJson(decoded);
  }

  static FoodIdentityManifest loadFromAssetFileSync([
    String path = kFoodIdentityManifestPath,
  ]) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException(
        'Food identity manifest not found at $path',
        path,
      );
    }
    return FoodIdentityManifest.fromJson(jsonDecode(file.readAsStringSync()));
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'normalization_version': normalizationVersion,
    'identity_namespace': identityNamespace,
    'entries': entries.map((entry) => entry.toJson()).toList(),
    'aliases': aliases.map((alias) => alias.toJson()).toList(),
    'legacy_mappings': legacyMappings
        .map((mapping) => mapping.toJson())
        .toList(),
    'identity_fixtures': identityFixtures
        .map((fixture) => fixture.toJson())
        .toList(),
    'source_to_id': sourceToId,
    'source_fingerprints': sourceFingerprintToId,
    'source_reviews': {
      for (final item in sourceReviews.entries) item.key: item.value.toJson(),
    },
  };

  List<FoodIdentityEntry> get catalogueEntries =>
      entries.where((entry) => entry.isCatalogue).toList(growable: false);

  FoodIdentityEntry? getById(String id) => _entryById[id];

  FoodIdentityEntry? getByMachineId(String machineId) =>
      _entryByMachineId[machineId];

  FoodIdentityEntry? getBySourceKey(String sourceKey) =>
      _entryBySourceKey[sourceKey];

  FoodLegacyMapping? getLegacyMapping(String sourceKey) =>
      _legacyBySourceKey[sourceKey];

  int get canonicalCatalogueCount => catalogueEntries
      .where((entry) => entry.kind == FoodIdentityKind.canonical)
      .length;

  int get preparationVariantCount => entries
      .where((entry) => entry.kind == FoodIdentityKind.preparationVariant)
      .length;

  int get regionalVariantCount => entries
      .where((entry) => entry.kind == FoodIdentityKind.regionalVariant)
      .length;

  int get restaurantEstimateCount => entries
      .where((entry) => entry.kind == FoodIdentityKind.restaurantEstimate)
      .length;

  int get homemadeEstimateCount => entries
      .where((entry) => entry.kind == FoodIdentityKind.homemadeEstimate)
      .length;

  int get brandedCount =>
      entries.where((entry) => entry.kind == FoodIdentityKind.branded).length;

  int get servingPresentationVariantCount => entries
      .where(
        (entry) => entry.kind == FoodIdentityKind.servingPresentationVariant,
      )
      .length;

  int get deprecatedCount => entries.where((entry) => entry.deprecated).length;

  int get ambiguousCount =>
      aliases
          .where(
            (alias) => alias.reviewState == FoodIdentityReviewState.ambiguous,
          )
          .length +
      legacyMappings
          .where(
            (mapping) =>
                mapping.reviewState == FoodIdentityReviewState.ambiguous,
          )
          .length;

  int get unresolvedCount =>
      aliases
          .where(
            (alias) => alias.reviewState == FoodIdentityReviewState.unresolved,
          )
          .length +
      legacyMappings
          .where(
            (mapping) =>
                mapping.reviewState == FoodIdentityReviewState.unresolved,
          )
          .length +
      identityFixtures
          .where((fixture) => fixture.kind == FoodIdentityKind.unknown)
          .length;

  int get manualReviewCount =>
      entries
          .where(
            (entry) =>
                entry.reviewState == FoodIdentityReviewState.manualReview,
          )
          .length +
      aliases
          .where(
            (alias) =>
                alias.reviewState == FoodIdentityReviewState.manualReview,
          )
          .length +
      legacyMappings
          .where(
            (mapping) =>
                mapping.reviewState == FoodIdentityReviewState.manualReview,
          )
          .length +
      identityFixtures
          .where(
            (fixture) =>
                fixture.reviewState == FoodIdentityReviewState.manualReview,
          )
          .length;

  void _validate() {
    if (identityNamespace != kFoodIdentityIdentityNamespace) {
      throw StateError(
        'Unsupported food identity namespace: $identityNamespace',
      );
    }
    _validateUnique('entry ID', entries.map((entry) => entry.id));
    _validateUnique(
      'canonical machine identifier',
      entries.map((entry) => entry.machineId),
    );
    _validateUnique('alias ID', aliases.map((alias) => alias.id));
    _validateUnique(
      'legacy mapping ID',
      legacyMappings.map((mapping) => mapping.id),
    );
    _validateUnique(
      'identity fixture ID',
      identityFixtures.map((fixture) => fixture.id),
    );

    final entryIds = entries.map((entry) => entry.id).toSet();
    final canonicalNames = <String, String>{};
    final sourceKeys = <String>{};
    for (final entry in entries) {
      if (entry.provenance.kind == 'provider' &&
          (entry.provenance.providerNamespace == null ||
              entry.provenance.externalId == null)) {
        throw StateError(
          'Provider entry ${entry.id} lacks namespace/external identity.',
        );
      }
      if (!sourceKeys.add(entry.provenance.key)) {
        throw StateError(
          'Duplicate canonical source key: ${entry.provenance.key}',
        );
      }
      if (entry.reviewState == FoodIdentityReviewState.deprecated &&
          !entry.deprecated) {
        throw StateError(
          'Deprecated entry ${entry.id} must set deprecated=true.',
        );
      }
      if (entry.deprecated &&
          entry.reviewState != FoodIdentityReviewState.deprecated) {
        throw StateError(
          'Entry ${entry.id} marked deprecated with a non-deprecated state.',
        );
      }
      if (entry.kind == FoodIdentityKind.canonical) {
        final previous = canonicalNames[entry.normalizedName];
        if (previous != null) {
          throw StateError(
            'Duplicate normalized canonical name "${entry.normalizedName}" '
            'for $previous and ${entry.id}.',
          );
        }
        canonicalNames[entry.normalizedName] = entry.id;
        if (entry.variantType != null || entry.parentId != null) {
          throw StateError(
            'Canonical entry ${entry.id} cannot carry variant metadata.',
          );
        }
      } else if (entry.variantType == null) {
        throw StateError(
          'Distinct entry ${entry.id} must declare variant_type.',
        );
      }
      if (entry.kind == FoodIdentityKind.recipe ||
          entry.kind == FoodIdentityKind.userCreated ||
          entry.kind == FoodIdentityKind.imported ||
          entry.kind == FoodIdentityKind.aiEstimate) {
        throw StateError(
          'Non-catalogue identity kind ${entry.kind.name} must be an '
          'identity_fixture, not a catalogue entry (${entry.id}).',
        );
      }
      if (entry.parentId == entry.id) {
        throw StateError('Entry ${entry.id} cannot parent itself.');
      }
      if (entry.replacementId == entry.id) {
        throw StateError('Entry ${entry.id} cannot replace itself.');
      }
      if (entry.parentId != null && !entryIds.contains(entry.parentId)) {
        throw StateError(
          'Entry ${entry.id} references unknown parent ${entry.parentId}.',
        );
      }
      if (entry.parentId != null && entry.familyId == null) {
        throw StateError(
          'Variant ${entry.id} with a parent must declare its family.',
        );
      }
      if (entry.familyId != null && entry.familyId!.trim().isEmpty) {
        throw StateError('Entry ${entry.id} has an empty family reference.');
      }
      if (entry.kind == FoodIdentityKind.canonical && entry.familyId != null) {
        throw StateError(
          'Canonical entry ${entry.id} cannot reference a variant family.',
        );
      }
      if (entry.replacementId != null &&
          !entryIds.contains(entry.replacementId)) {
        throw StateError(
          'Entry ${entry.id} references unknown replacement '
          '${entry.replacementId}.',
        );
      }
    }

    _validateParentCycles();

    final aliasesByNormalized = <String, FoodIdentityAlias>{};
    for (final alias in aliases) {
      final normalized = FoodIdentityNormalizer.normalize(alias.value);
      if (normalized.isEmpty || normalized != alias.normalized) {
        throw StateError('Alias ${alias.id} has invalid normalized value.');
      }
      if (aliasesByNormalized.containsKey(normalized)) {
        throw StateError('Alias collision for normalized value: $normalized');
      }
      aliasesByNormalized[normalized] = alias;
      if (alias.kind == FoodAliasKind.approved) {
        if (alias.targetId == null || !entryIds.contains(alias.targetId)) {
          throw StateError(
            'Approved alias ${alias.id} references an unknown target.',
          );
        }
        if (alias.reviewState != FoodIdentityReviewState.reviewed) {
          throw StateError(
            'Approved alias ${alias.id} must have reviewed state.',
          );
        }
        final canonicalTarget = canonicalNames[alias.normalized];
        if (canonicalTarget != null && canonicalTarget != alias.targetId) {
          throw StateError(
            'Alias ${alias.id} collides with canonical name '
            '${alias.normalized}.',
          );
        }
      } else {
        if (alias.targetId != null ||
            alias.reviewState != FoodIdentityReviewState.ambiguous) {
          throw StateError(
            'Ambiguous alias ${alias.id} must have no target and ambiguous '
            'review state.',
          );
        }
      }
    }

    final legacyKeys = <String>{};
    for (final mapping in legacyMappings) {
      if (!legacyKeys.add(mapping.sourceKey)) {
        throw StateError('Duplicate legacy source key: ${mapping.sourceKey}');
      }
      if (mapping.targetId != null && !entryIds.contains(mapping.targetId)) {
        throw StateError(
          'Legacy mapping ${mapping.id} references unknown target '
          '${mapping.targetId}.',
        );
      }
      if (mapping.reviewState == FoodIdentityReviewState.reviewed &&
          mapping.targetId == null) {
        throw StateError(
          'Reviewed legacy mapping ${mapping.id} must have a target.',
        );
      }
      if (mapping.targetId != null &&
          mapping.reviewState != FoodIdentityReviewState.reviewed) {
        throw StateError(
          'Legacy mapping ${mapping.id} can resolve only from reviewed state.',
        );
      }
      if ((mapping.reviewState == FoodIdentityReviewState.ambiguous ||
              mapping.reviewState == FoodIdentityReviewState.unresolved) &&
          mapping.targetId != null) {
        throw StateError(
          'Unresolved/ambiguous legacy mapping ${mapping.id} cannot target '
          '${mapping.targetId}.',
        );
      }
    }

    final portableFixtureIds = <String>{};
    for (final fixture in identityFixtures) {
      final portableId = fixture.portableId;
      if (portableId != null && !portableFixtureIds.add(portableId)) {
        throw StateError('Duplicate fixture portable ID: $portableId');
      }
      final hasNamespace = fixture.providerNamespace != null;
      final hasExternalId = fixture.externalId != null;
      if (hasNamespace != hasExternalId) {
        throw StateError(
          'Fixture ${fixture.id} must provide namespace and external ID '
          'together.',
        );
      }
      if ((fixture.kind == FoodIdentityKind.imported ||
              fixture.kind == FoodIdentityKind.branded) &&
          (!hasNamespace || !hasExternalId)) {
        throw StateError(
          'Imported/branded fixture ${fixture.id} lacks provider identity.',
        );
      }
      if (fixture.canonicalTargetId != null &&
          !entryIds.contains(fixture.canonicalTargetId)) {
        throw StateError(
          'Fixture ${fixture.id} references unknown canonical target.',
        );
      }
      if ((fixture.kind == FoodIdentityKind.userCreated ||
              fixture.kind == FoodIdentityKind.imported ||
              fixture.kind == FoodIdentityKind.aiEstimate) &&
          fixture.canonicalTargetId != null) {
        throw StateError(
          'Fixture ${fixture.id} cannot be auto-attached to a catalogue '
          'identity.',
        );
      }
    }

    _validateSourceIdentityEvidence(entryIds);
    _validateGlobalIdentityNamespace();
  }

  void _validateSourceIdentityEvidence(Set<String> entryIds) {
    final catalogue = entries.where((entry) => entry.isCatalogue).toList();
    final catalogueIds = catalogue.map((entry) => entry.id).toSet();
    if (sourceToId.length != catalogue.length ||
        sourceFingerprintToId.length != catalogue.length ||
        sourceReviews.length != catalogue.length) {
      throw StateError(
        'Every catalogue source row requires exactly one source ID, '
        'fingerprint, and explicit review record.',
      );
    }
    if (sourceFingerprintToId.values.toSet().length != catalogue.length) {
      throw StateError(
        'Source fingerprints must resolve one-to-one to catalogue IDs.',
      );
    }

    final reviewTargets = <String>{};
    for (final entry in catalogue) {
      final sourceKey = entry.provenance.key;
      final mappedId = sourceToId[sourceKey];
      if (mappedId != entry.id) {
        throw StateError(
          'Source $sourceKey must map explicitly to ${entry.id}.',
        );
      }
      final review = sourceReviews[sourceKey];
      if (review == null) {
        throw StateError('Missing source review evidence for $sourceKey.');
      }
      if (review.targetId != entry.id ||
          review.kind != entry.kind ||
          review.classification != entry.classification ||
          review.reviewState != entry.reviewState ||
          review.variantType != entry.variantType ||
          review.parentId != entry.parentId ||
          review.familyId != entry.familyId) {
        throw StateError(
          'Source review evidence disagrees with manifest entry ${entry.id}.',
        );
      }
      if (!reviewTargets.add(review.targetId)) {
        throw StateError(
          'Source review evidence resolves multiple rows to ${review.targetId}.',
        );
      }
    }

    for (final item in sourceToId.entries) {
      if (!catalogue.any((entry) => entry.provenance.key == item.key)) {
        throw StateError(
          'Source ID mapping targets unknown source ${item.key}.',
        );
      }
      if (!catalogueIds.contains(item.value)) {
        throw StateError(
          'Source ID mapping targets unknown entry ${item.value}.',
        );
      }
    }
    for (final item in sourceFingerprintToId.entries) {
      if (!catalogueIds.contains(item.value)) {
        throw StateError(
          'Source fingerprint ${item.key} targets unknown entry ${item.value}.',
        );
      }
    }
    for (final review in sourceReviews.values) {
      if (!sourceToId.containsKey(review.sourceKey) ||
          sourceToId[review.sourceKey] != review.targetId) {
        throw StateError(
          'Source review ${review.sourceKey} has no matching source mapping.',
        );
      }
      if (!sourceFingerprintToId.containsValue(review.targetId)) {
        throw StateError(
          'Source review ${review.sourceKey} has no fingerprint mapping.',
        );
      }
      if (review.reviewState == FoodIdentityReviewState.reviewed &&
          (review.reason.trim().isEmpty ||
              review.evidenceRef?.trim().isEmpty != false)) {
        throw StateError(
          'Reviewed source ${review.sourceKey} must include evidence and '
          'evidence_ref.',
        );
      }
      if (review.reviewState == FoodIdentityReviewState.manualReview &&
          review.reason.trim().isEmpty) {
        throw StateError(
          'Manual-review source ${review.sourceKey} must include a reason.',
        );
      }
      if (review.reviewState != FoodIdentityReviewState.reviewed &&
          review.evidenceRef != null) {
        throw StateError(
          'Unreviewed source ${review.sourceKey} cannot carry reviewed '
          'evidence metadata.',
        );
      }
      if (!entryIds.contains(review.targetId)) {
        throw StateError(
          'Source review ${review.sourceKey} targets unknown entry.',
        );
      }
    }
  }

  void _validateGlobalIdentityNamespace() {
    final claims = <String, String>{};

    void claim(String value, String owner) {
      final previous = claims[value];
      if (previous != null && previous != owner) {
        throw StateError(
          'Global durable identity collision for "$value": $previous and $owner.',
        );
      }
      claims[value] = owner;
    }

    for (final entry in entries) {
      final owner = 'entry:${entry.id}';
      claim(entry.id, owner);
      // A catalogue entry commonly uses the same value for its portable and
      // machine IDs. That is one identity, not a collision; a machine ID that
      // belongs to another entry is rejected by the owner check.
      claim(entry.machineId, owner);
      if (entry.familyId != null) {
        claim(entry.familyId!, 'family:${entry.familyId}');
      }
    }
    for (final alias in aliases) {
      claim(alias.id, 'alias:${alias.id}');
    }
    for (final mapping in legacyMappings) {
      claim(mapping.id, 'legacy:${mapping.id}');
    }
    for (final fixture in identityFixtures) {
      claim(fixture.id, 'fixture:${fixture.id}');
      if (fixture.portableId != null) {
        claim(fixture.portableId!, 'fixture-portable:${fixture.id}');
      }
    }
  }

  void _validateParentCycles() {
    final parents = {for (final entry in entries) entry.id: entry.parentId};
    final visiting = <String>{};
    final visited = <String>{};

    void visit(String id) {
      if (visited.contains(id)) return;
      if (!visiting.add(id)) {
        throw StateError('Food identity variant parent cycle includes $id.');
      }
      final parent = parents[id];
      if (parent != null) visit(parent);
      visiting.remove(id);
      visited.add(id);
    }

    for (final id in parents.keys) {
      visit(id);
    }
  }

  static void _validateUnique(String label, Iterable<String> values) {
    final seen = <String>{};
    for (final value in values) {
      if (!seen.add(value)) throw StateError('Duplicate $label: $value');
    }
  }

  /// Creates a deterministic first-pass manifest from the reviewed bundled
  /// assets. The generated output is checked in and is thereafter authoritative
  /// as explicit JSON; runtime loading never regenerates IDs.
  static Map<String, dynamic> generateFromAssetFilesSync({
    String basePath = 'assets/data/indian_foods.json',
    String regionalDirectory = 'assets/data/regional',
    Map<String, String>? sourceToId,
    Map<String, String>? sourceFingerprintToId,
    Map<String, Map<String, dynamic>>? sourceReviews,
  }) {
    FoodIdentityManifest? reviewedManifest;
    if (sourceToId == null ||
        sourceFingerprintToId == null ||
        sourceReviews == null) {
      final manifestFile = File(kFoodIdentityManifestPath);
      if (manifestFile.existsSync()) {
        reviewedManifest = FoodIdentityManifest.loadFromAssetFileSync();
      }
    }
    final explicitSourceToId = sourceToId ?? reviewedManifest?.sourceToId;
    final explicitSourceFingerprints =
        sourceFingerprintToId ?? reviewedManifest?.sourceFingerprintToId;
    final explicitReviews =
        sourceReviews ??
        reviewedManifest?.sourceReviews.map(
          (key, value) => MapEntry(key, value.toJson()),
        );
    if (explicitSourceToId == null || explicitSourceFingerprints == null) {
      throw StateError(
        'Maintenance generation requires an explicit reviewed source-to-ID '
        'mapping and source fingerprints.',
      );
    }

    final rows = <_AssetFoodRow>[];
    rows.addAll(_readAssetRows(basePath, sourceId: 'base'));
    final regionalDirectoryFile = Directory(regionalDirectory);
    final regionalFiles =
        regionalDirectoryFile
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in regionalFiles) {
      final region = file.uri.pathSegments.last.replaceFirst('.json', '');
      rows.addAll(_readAssetRows(file.path, sourceId: 'regional/$region'));
    }

    final entryIds = <String, String>{};
    final sourceKeysByFingerprint = <String, String>{};
    final rowFingerprints = <String, String>{};
    for (final row in rows) {
      final id =
          explicitSourceToId[row.sourceKey] ??
          explicitSourceFingerprints[row.sourceFingerprint];
      if (id == null) {
        throw StateError(
          'Missing reviewed source-to-ID mapping for ${row.sourceKey} '
          '(fingerprint ${row.sourceFingerprint}); manual review is required.',
        );
      }
      String? previousRow;
      for (final item in entryIds.entries) {
        if (item.value == id) {
          previousRow = item.key;
          break;
        }
      }
      if (previousRow != null && previousRow != row.sourceKey) {
        throw StateError(
          'Reviewed source mapping assigns $id to both $previousRow and '
          '${row.sourceKey}.',
        );
      }
      var fingerprint = row.sourceFingerprint;
      final previousFingerprint = sourceKeysByFingerprint[fingerprint];
      if (previousFingerprint == null &&
          explicitSourceToId.containsKey(row.sourceKey) &&
          explicitSourceFingerprints[fingerprint] != null &&
          explicitSourceFingerprints[fingerprint] != id) {
        fingerprint = row.disambiguatedSourceFingerprint;
      }
      if (previousFingerprint != null && previousFingerprint != row.sourceKey) {
        if (!explicitSourceToId.containsKey(row.sourceKey)) {
          throw StateError(
            'Source fingerprint $fingerprint is not unique; manual '
            'disambiguation is required.',
          );
        }
        fingerprint = row.disambiguatedSourceFingerprint;
      }
      entryIds[row.sourceKey] = id;
      rowFingerprints[row.sourceKey] = fingerprint;
      sourceKeysByFingerprint[fingerprint] = row.sourceKey;
    }

    final entries = <Map<String, dynamic>>[];
    final generatedSourceReviews = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final id = entryIds[row.sourceKey]!;
      final review =
          explicitReviews?[row.sourceKey] ??
          explicitReviews?.values.firstWhere(
            (item) =>
                item['source_fingerprint'] == rowFingerprints[row.sourceKey],
            orElse: () => <String, dynamic>{},
          );
      final hasReview = review != null && review.isNotEmpty;
      final kind = hasReview
          ? _kindFromJson(review['kind'] as String)
          : FoodIdentityKind.unknown;
      final variantType = hasReview
          ? review['variant_type'] as String?
          : 'unresolved';
      final parentId = hasReview ? review['parent_id'] as String? : null;
      final familyId = hasReview ? review['family_id'] as String? : null;
      final reviewState = hasReview
          ? _reviewStateFromJson(review['review_state'] as String)
          : FoodIdentityReviewState.manualReview;
      final classification = hasReview
          ? review['classification'] as String
          : row.classification;
      final sourceReview = <String, dynamic>{
        'source_key': row.sourceKey,
        'source_fingerprint': rowFingerprints[row.sourceKey],
        'target_id': id,
        'kind': kind.name,
        'classification': classification,
        'review_state': reviewState.name,
        'variant_type': variantType,
        'parent_id': parentId,
        'family_id': familyId,
        'reason': hasReview
            ? review['reason'] as String
            : 'No explicit reviewed source metadata; manual review required.',
        'evidence_ref': hasReview ? review['evidence_ref'] : null,
      };
      generatedSourceReviews[row.sourceKey] = sourceReview;
      entries.add({
        'id': id,
        'machine_id': id,
        'display_name': row.displayName,
        'normalized_name': row.normalizedName,
        'kind': kind.name,
        'classification': classification,
        'locale': 'en-IN',
        'region': row.sourceId == 'base'
            ? 'bundled'
            : row.sourceId.split('/').last,
        'provenance': {
          'kind': row.sourceId == 'base' ? 'bundled_asset' : 'regional_asset',
          'key': row.sourceKey,
          'revision': 'b03-asset-v1',
          'path': row.path,
          'provider_namespace': null,
          'external_id': null,
        },
        'review_state': reviewState.name,
        'deprecated': false,
        'is_catalogue': true,
        'variant_type': variantType,
        'parent_id': parentId,
        'family_id': familyId,
        'replacement_id': null,
      });
    }

    final aliases = <Map<String, dynamic>>[];
    void addApprovedAlias(
      String id,
      String value,
      String targetName, {
      String? targetSourceId,
    }) {
      final targetKey =
          'asset:${targetSourceId ?? 'base'}:${FoodIdentityNormalizer.normalize(targetName)}';
      final target =
          entryIds[targetKey] ??
          reviewedManifest?.entries
              .where(
                (entry) =>
                    entry.displayName == targetName &&
                    entry.provenance.key.startsWith(
                      'asset:${targetSourceId ?? 'base'}:',
                    ),
              )
              .map((entry) => entry.id)
              .firstWhere(
                (id) => entryIds.values.contains(id),
                orElse: () => '',
              );
      if (target == null || target.isEmpty) {
        throw StateError('Generator alias target is missing: $targetName');
      }
      aliases.add({
        'id': id,
        'value': value,
        'normalized': FoodIdentityNormalizer.normalize(value),
        'kind': 'approved',
        'target_id': target,
        'review_state': 'reviewed',
        'provenance': {
          'kind': 'fixture',
          'key': 'alias:$id',
          'revision': 'b03-food-identity-v1',
          'path': null,
          'provider_namespace': null,
          'external_id': null,
        },
      });
    }

    void addAmbiguousAlias(String id, String value) {
      aliases.add({
        'id': id,
        'value': value,
        'normalized': FoodIdentityNormalizer.normalize(value),
        'kind': 'ambiguous',
        'target_id': null,
        'review_state': 'ambiguous',
        'provenance': {
          'kind': 'fixture',
          'key': 'alias:$id',
          'revision': 'b03-food-identity-v1',
          'path': null,
          'provider_namespace': null,
          'external_id': null,
        },
      });
    }

    addApprovedAlias(
      'alias-whole-wheat-chapati',
      'Whole Wheat Chapati',
      'Whole Wheat Roti / Chapati',
    );
    addApprovedAlias('alias-masala-dosai', 'Masala Dosai', 'Masala Dosa');
    addApprovedAlias(
      'alias-cholar-dal',
      'Cholar Dal',
      'Chholar Dal',
      targetSourceId: 'regional/bengali',
    );
    addApprovedAlias(
      'alias-methi-thepla',
      'Methi Thepla',
      'Thepla (Methi)',
      targetSourceId: 'regional/gujarati',
    );
    addApprovedAlias(
      'alias-kanda-poha',
      'Kanda Poha',
      'Poha (Kanda Poha)',
      targetSourceId: 'regional/maharashtrian',
    );
    addApprovedAlias(
      'alias-sarson-saag',
      'Sarson Saag',
      'Sarson ka Saag',
      targetSourceId: 'regional/punjabi',
    );

    const genericNames = [
      'Dal',
      'Curry',
      'Sabzi',
      'Roti',
      'Chapati',
      'Biryani',
      'Dosa',
      'Chawal',
      'Paneer Curry',
    ];
    for (var index = 0; index < genericNames.length; index++) {
      addAmbiguousAlias(
        'alias-generic-${index.toString().padLeft(2, '0')}',
        genericNames[index],
      );
    }

    final legacyIdsByTarget = <String, String>{
      for (final mapping in reviewedManifest?.legacyMappings ?? const [])
        if (mapping.targetId != null) mapping.targetId!: mapping.id,
    };
    final legacyMappings = <Map<String, dynamic>>[];
    for (final row in rows) {
      final id = entryIds[row.sourceKey]!;
      legacyMappings.add({
        'id': legacyIdsByTarget[id] ?? 'legacy-source-$id',
        'source_key': row.sourceKey,
        'source_type': row.sourceId == 'base'
            ? 'legacy_food_seed'
            : 'regional_asset_row',
        'legacy_local_id': row.sourceId == 'base' ? row.index + 1 : null,
        'target_id': id,
        'review_state': 'reviewed',
        'provenance': {
          'kind': 'legacy',
          'key': 'legacy-evidence:${row.sourceKey}',
          'revision': 'b03-legacy-map-v1',
          'path': row.path,
          'provider_namespace': null,
          'external_id': null,
        },
        'evidence': row.sourceId == 'base'
            ? 'Exact reviewed bundled asset key; local integer is compatibility evidence only.'
            : 'Exact reviewed regional asset key; no local integer identity is assumed.',
      });
    }
    legacyMappings.addAll([
      {
        'id': 'legacy-ambiguous-generic-dosa',
        'source_key': 'legacy:old-db:generic-dosa',
        'source_type': 'legacy_display_name',
        'legacy_local_id': null,
        'target_id': null,
        'review_state': 'ambiguous',
        'provenance': {
          'kind': 'legacy',
          'key': 'legacy-evidence:legacy:old-db:generic-dosa',
          'revision': 'b03-legacy-map-v1',
          'path': null,
          'provider_namespace': null,
          'external_id': null,
        },
        'evidence':
            'Generic legacy display name has multiple reviewed preparation/regional candidates.',
      },
      {
        'id': 'legacy-unresolved-unknown-9999',
        'source_key': 'legacy:old-db:food-9999',
        'source_type': 'legacy_local_record',
        'legacy_local_id': 9999,
        'target_id': null,
        'review_state': 'unresolved',
        'provenance': {
          'kind': 'legacy',
          'key': 'legacy-evidence:legacy:old-db:food-9999',
          'revision': 'b03-legacy-map-v1',
          'path': null,
          'provider_namespace': null,
          'external_id': null,
        },
        'evidence':
            'No reviewed stable identifier or exact source key is available; preserve as legacy unresolved.',
      },
    ]);

    entries.add({
      'id': 'food-fixture-deprecated-0001',
      'machine_id': 'fixture-deprecated-food-v1',
      'display_name': 'Legacy Festival Curry',
      'normalized_name': 'legacy festival curry',
      'kind': 'canonical',
      'classification': 'fixture-only deprecated identity',
      'locale': 'en-IN',
      'region': 'fixture',
      'provenance': {
        'kind': 'fixture',
        'key': 'fixture:deprecated:legacy-festival-curry',
        'revision': 'b03-food-identity-v1',
        'path': null,
        'provider_namespace': null,
        'external_id': null,
      },
      'review_state': 'deprecated',
      'deprecated': true,
      'is_catalogue': false,
      'variant_type': null,
      'parent_id': null,
      'family_id': null,
      'replacement_id': null,
    });

    final identityFixtures = [
      {
        'id': 'identity-user-created-0001',
        'kind': 'userCreated',
        'display_name': 'My Homemade Lentil Bowl',
        'portable_id': 'food-user-fixture-0001',
        'provider_namespace': null,
        'external_id': null,
        'barcode': null,
        'canonical_target_id': null,
        'review_state': 'fixture',
        'provenance': {
          'kind': 'user',
          'key': 'fixture:user-created:0001',
          'revision': 'b03-food-identity-v1',
          'path': null,
          'provider_namespace': null,
          'external_id': null,
        },
      },
      {
        'id': 'identity-imported-provider-0001',
        'kind': 'imported',
        'display_name': 'Imported Provider Granola',
        'portable_id': 'food-import-fixture-0001',
        'provider_namespace': 'open_food_facts',
        'external_id': 'fixture-off-0001',
        'barcode': '8900000000001',
        'canonical_target_id': null,
        'review_state': 'fixture',
        'provenance': {
          'kind': 'provider',
          'key': 'fixture:provider:open_food_facts:fixture-off-0001',
          'revision': 'b03-food-identity-v1',
          'path': null,
          'provider_namespace': 'open_food_facts',
          'external_id': 'fixture-off-0001',
        },
      },
      {
        'id': 'identity-branded-provider-0001',
        'kind': 'branded',
        'display_name': 'Fixture Brand Paneer',
        'portable_id': 'food-branded-fixture-0001',
        'provider_namespace': 'fixture-manufacturer',
        'external_id': 'fixture-paneer-0001',
        'barcode': '8900000000002',
        'canonical_target_id': null,
        'review_state': 'fixture',
        'provenance': {
          'kind': 'provider',
          'key': 'fixture:provider:fixture-manufacturer:fixture-paneer-0001',
          'revision': 'b03-food-identity-v1',
          'path': null,
          'provider_namespace': 'fixture-manufacturer',
          'external_id': 'fixture-paneer-0001',
        },
      },
      {
        'id': 'identity-ai-estimate-0001',
        'kind': 'aiEstimate',
        'display_name': 'AI Estimate: Mixed Curry',
        'portable_id': 'estimate-fixture-0001',
        'provider_namespace': 'fixture-ai-model',
        'external_id': 'estimate-request-0001',
        'barcode': null,
        'canonical_target_id': null,
        'review_state': 'fixture',
        'provenance': {
          'kind': 'ai',
          'key': 'fixture:ai-estimate:0001',
          'revision': 'b03-food-identity-v1',
          'path': null,
          'provider_namespace': 'fixture-ai-model',
          'external_id': 'estimate-request-0001',
        },
      },
      {
        'id': 'identity-restaurant-estimate-0001',
        'kind': 'restaurantEstimate',
        'display_name': 'Restaurant Estimate: Curry Plate',
        'portable_id': 'estimate-restaurant-fixture-0001',
        'provider_namespace': null,
        'external_id': null,
        'barcode': null,
        'canonical_target_id': null,
        'review_state': 'fixture',
        'provenance': {
          'kind': 'fixture',
          'key': 'fixture:restaurant-estimate:0001',
          'revision': 'b03-food-identity-v1',
          'path': null,
          'provider_namespace': null,
          'external_id': null,
        },
      },
      {
        'id': 'identity-homemade-estimate-0001',
        'kind': 'homemadeEstimate',
        'display_name': 'Homemade Generic Estimate: Dal',
        'portable_id': 'estimate-homemade-fixture-0001',
        'provider_namespace': null,
        'external_id': null,
        'barcode': null,
        'canonical_target_id': null,
        'review_state': 'fixture',
        'provenance': {
          'kind': 'fixture',
          'key': 'fixture:homemade-estimate:0001',
          'revision': 'b03-food-identity-v1',
          'path': null,
          'provider_namespace': null,
          'external_id': null,
        },
      },
      {
        'id': 'identity-recipe-0001',
        'kind': 'recipe',
        'display_name': 'Fixture Recipe: Lentil Bowl',
        'portable_id': 'recipe-fixture-0001',
        'provider_namespace': null,
        'external_id': null,
        'barcode': null,
        'canonical_target_id': null,
        'review_state': 'fixture',
        'provenance': {
          'kind': 'fixture',
          'key': 'fixture:recipe:0001',
          'revision': 'b03-food-identity-v1',
          'path': null,
          'provider_namespace': null,
          'external_id': null,
        },
      },
      {
        'id': 'identity-unknown-0001',
        'kind': 'unknown',
        'display_name': 'Unresolved Imported Food',
        'portable_id': null,
        'provider_namespace': null,
        'external_id': null,
        'barcode': null,
        'canonical_target_id': null,
        'review_state': 'unresolved',
        'provenance': {
          'kind': 'legacy',
          'key': 'fixture:unknown:0001',
          'revision': 'b03-food-identity-v1',
          'path': null,
          'provider_namespace': null,
          'external_id': null,
        },
      },
    ];

    final payload = {
      'version': kFoodIdentityManifestVersion,
      'normalization_version': kFoodIdentityNormalizationVersion,
      'identity_namespace': kFoodIdentityIdentityNamespace,
      'entries': entries,
      'aliases': aliases,
      'legacy_mappings': legacyMappings,
      'identity_fixtures': identityFixtures,
      'source_to_id': {
        for (final row in rows) row.sourceKey: entryIds[row.sourceKey],
      },
      'source_fingerprints': {
        for (final row in rows)
          rowFingerprints[row.sourceKey]!: entryIds[row.sourceKey]!,
      },
      'source_reviews': generatedSourceReviews,
    };
    // Validate the complete generated graph before it is written by the
    // maintenance/test caller.
    FoodIdentityManifest.fromJson(payload);
    return payload;
  }

  static List<_AssetFoodRow> _readAssetRows(
    String path, {
    required String sourceId,
  }) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('Food asset not found at $path', path);
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! List) {
      throw FormatException('Food asset $path must be an array.');
    }
    final rows = <_AssetFoodRow>[];
    for (var index = 0; index < decoded.length; index++) {
      final item = decoded[index];
      if (item is! Map) {
        throw FormatException('Food asset row $path#$index must be an object.');
      }
      final json = Map<String, dynamic>.from(item);
      final displayName = _requiredString(json, 'name');
      final normalizedName = FoodIdentityNormalizer.normalize(displayName);
      final classification = _requiredString(json, 'category');
      rows.add(
        _AssetFoodRow(
          index: index,
          sourceId: sourceId,
          path: path,
          displayName: displayName,
          normalizedName: normalizedName,
          classification: classification,
          sourceData: json,
        ),
      );
    }
    return rows;
  }
}

class _AssetFoodRow {
  final int index;
  final String sourceId;
  final String path;
  final String displayName;
  final String normalizedName;
  final String classification;
  final Map<String, dynamic> sourceData;

  const _AssetFoodRow({
    required this.index,
    required this.sourceId,
    required this.path,
    required this.displayName,
    required this.normalizedName,
    required this.classification,
    required this.sourceData,
  });

  String get sourceKey => 'asset:$sourceId:$normalizedName';

  /// Stable content identity used only by maintenance tooling. Display names
  /// is intentionally excluded so an English cosmetic rename does not change
  /// the reviewed portable ID. Localized/source labels remain evidence for
  /// distinguishing otherwise identical source rows; nutrition/source
  /// changes still require a fresh explicit review.
  String get sourceFingerprint {
    final keys = sourceData.keys.where((key) => key != 'name').toList()..sort();
    final identityFields = <String, dynamic>{
      'source_id': sourceId,
      for (final key in keys) key: sourceData[key],
    };
    final canonical = jsonEncode(identityFields);
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  /// Deterministic fallback for a newly reviewed row whose non-name source
  /// data is byte-for-byte identical to an existing row. Existing rows never
  /// switch to this form automatically; the explicit source-to-ID mapping is
  /// what authorizes the new identity.
  String get disambiguatedSourceFingerprint => sha256
      .convert(utf8.encode('$sourceFingerprint|$normalizedName'))
      .toString();
}

/// Exact-only resolver. It never strips punctuation, preparation terms, brand
/// labels, portions, or uses fuzzy/substring matching.
class FoodIdentityResolver {
  final FoodIdentityManifest manifest;
  late final Map<String, List<FoodIdentityEntry>> _entriesByNormalized;
  late final Map<String, FoodIdentityAlias> _aliasesByNormalized;

  FoodIdentityResolver(this.manifest) {
    final entriesByNormalized = <String, List<FoodIdentityEntry>>{};
    for (final entry in manifest.entries) {
      entriesByNormalized
          .putIfAbsent(entry.normalizedName, () => [])
          .add(entry);
    }
    _entriesByNormalized = {
      for (final item in entriesByNormalized.entries)
        item.key: List.unmodifiable(item.value),
    };
    _aliasesByNormalized = {
      for (final alias in manifest.aliases) alias.normalized: alias,
    };
  }

  FoodIdentityLookupResult resolve(String rawValue) {
    final normalized = FoodIdentityNormalizer.normalize(rawValue);
    if (normalized.isEmpty) {
      return FoodIdentityLookupResult(
        status: FoodIdentityLookupStatus.unresolved,
        originalValue: rawValue,
        normalizedValue: normalized,
      );
    }

    final candidates = _entriesByNormalized[normalized];
    if (candidates != null && candidates.length > 1) {
      return FoodIdentityLookupResult(
        status: FoodIdentityLookupStatus.ambiguous,
        originalValue: rawValue,
        normalizedValue: normalized,
      );
    }
    if (candidates != null && candidates.length == 1) {
      final candidate = candidates.single;
      if (candidate.reviewState == FoodIdentityReviewState.ambiguous) {
        return FoodIdentityLookupResult(
          status: FoodIdentityLookupStatus.ambiguous,
          originalValue: rawValue,
          normalizedValue: normalized,
        );
      }
      if (candidate.reviewState == FoodIdentityReviewState.unresolved ||
          candidate.reviewState == FoodIdentityReviewState.manualReview) {
        return FoodIdentityLookupResult(
          status: FoodIdentityLookupStatus.unresolved,
          originalValue: rawValue,
          normalizedValue: normalized,
        );
      }
      return FoodIdentityLookupResult(
        status: FoodIdentityLookupStatus.resolved,
        originalValue: rawValue,
        normalizedValue: normalized,
        entry: candidate,
      );
    }

    final alias = _aliasesByNormalized[normalized];
    if (alias != null && alias.kind == FoodAliasKind.ambiguous) {
      return FoodIdentityLookupResult(
        status: FoodIdentityLookupStatus.ambiguous,
        originalValue: rawValue,
        normalizedValue: normalized,
        alias: alias,
      );
    }
    if (alias != null && alias.targetId != null) {
      return FoodIdentityLookupResult(
        status: FoodIdentityLookupStatus.resolved,
        originalValue: rawValue,
        normalizedValue: normalized,
        entry: manifest.getById(alias.targetId!),
        alias: alias,
      );
    }
    return FoodIdentityLookupResult(
      status: FoodIdentityLookupStatus.unresolved,
      originalValue: rawValue,
      normalizedValue: normalized,
    );
  }

  FoodLegacyLookupResult resolveLegacy(String sourceKey) {
    final mapping = manifest.getLegacyMapping(sourceKey);
    if (mapping == null) {
      return FoodLegacyLookupResult(
        status: FoodIdentityLookupStatus.unresolved,
        sourceKey: sourceKey,
      );
    }
    if (mapping.reviewState == FoodIdentityReviewState.ambiguous) {
      return FoodLegacyLookupResult(
        status: FoodIdentityLookupStatus.ambiguous,
        sourceKey: sourceKey,
        mapping: mapping,
      );
    }
    if (mapping.targetId == null) {
      return FoodLegacyLookupResult(
        status: FoodIdentityLookupStatus.unresolved,
        sourceKey: sourceKey,
        mapping: mapping,
      );
    }
    return FoodLegacyLookupResult(
      status: FoodIdentityLookupStatus.resolved,
      sourceKey: sourceKey,
      mapping: mapping,
      entry: manifest.getById(mapping.targetId!),
    );
  }
}
