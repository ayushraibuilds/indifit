import 'dart:convert';
import 'dart:io' show gzip;

import 'package:crypto/crypto.dart' as crypto;

import '../../core/typed_quantities.dart';

/// Food catalogue packs, format 1 (CAT-1).
///
/// A pack is gzip JSON published next to a small manifest. Food ids are
/// stable forever, so past logs keep resolving; values change by writing a
/// new fact version, never by editing history. The format is specified in
/// docs/implementation/NUTRITION_CATALOGUE_PACKS_PLAN.md § 4.1.
const int kCatalogPackFormat = 1;

/// The pack bundled with this app build. A device without a catalogue state
/// at or above this version applies it on create, upgrade or next open.
/// Pack 2 is built by tool/catalog/build.py (CAT-5, CAT-6).
const int kBundledCatalogPackVersion = 2;
const String kBundledCatalogManifestAsset = 'assets/catalog/manifest.json';
const String kBundledCatalogAssetDirectory = 'assets/catalog/';

/// The app build number that packs compare `min_app_build` against.
const int kCatalogAppBuild = 1;

class CatalogPackError implements Exception {
  final String code;
  final String message;

  const CatalogPackError(this.code, this.message);

  @override
  String toString() => 'CatalogPackError($code): $message';
}

/// The single portable serving definition of a catalogue or user food.
///
/// Per-serving facts are stored without a serving reference column; every
/// reader rebuilds the reference from the food id with this helper, so the
/// direct-log, thali and recipe paths agree on what "1 serving" means.
abstract final class CatalogueServing {
  static const revision = 'b03-food-entry-v1';
  static const source = 'catalogue';

  static ServingDefinitionReference reference(String foodId) =>
      ServingDefinitionReference(
        id: 'food-serving::$foodId',
        revision: revision,
        source: source,
      );

  static Quantity quantity(String foodId, Object amount) => Quantity(
    amount: switch (amount) {
      QuantityAmount value => value,
      num value => QuantityAmount.fromNum(value),
      String value => QuantityAmount.fromString(value),
      _ => throw ArgumentError.value(amount, 'amount'),
    },
    unit: QuantityUnit.serving,
    context: QuantityContext(servingDefinition: reference(foodId)),
  );
}

enum CatalogPackBasis { per100Grams, per100Millilitres, perServing }

extension CatalogPackBasisContract on CatalogPackBasis {
  String get stableId => switch (this) {
    CatalogPackBasis.per100Grams => 'per_100_grams',
    CatalogPackBasis.per100Millilitres => 'per_100_millilitres',
    CatalogPackBasis.perServing => 'per_serving',
  };

  static CatalogPackBasis parse(Object? raw) => switch (raw) {
    'per_100_grams' => CatalogPackBasis.per100Grams,
    'per_100_millilitres' => CatalogPackBasis.per100Millilitres,
    'per_serving' => CatalogPackBasis.perServing,
    _ => throw CatalogPackError(
      'invalid_basis',
      'Unsupported fact basis: $raw.',
    ),
  };
}

class CatalogPackServing {
  final String id;

  /// The household or metric unit this serving is counted in, e.g. `katori`,
  /// `piece`, `glass`, `g`. Lower case.
  final String unit;

  /// How many [unit]s one serving is: "2 pieces" is unit `piece`, amount 2.
  final double amount;

  /// Grams in one serving, when known.
  final double? grams;
  final bool isDefault;

  const CatalogPackServing({
    required this.id,
    required this.unit,
    required this.amount,
    required this.grams,
    required this.isDefault,
  });
}

/// Another name a food is searched by ("Arhar Dal" for Toor Dal).
class CatalogPackAlias {
  final String text;
  final String locale;

  const CatalogPackAlias({required this.text, required this.locale});
}

class CatalogPackFood {
  final String id;
  final String displayName;
  final String? sourceRef;
  final String? category;
  final String sourceId;
  final CatalogPackBasis basis;
  final Map<String, double> values;
  final List<CatalogPackServing> servings;
  final List<CatalogPackAlias> aliases;

  const CatalogPackFood({
    required this.id,
    required this.displayName,
    required this.sourceRef,
    required this.category,
    required this.sourceId,
    required this.basis,
    required this.values,
    required this.servings,
    this.aliases = const [],
  });

  CatalogPackServing get defaultServing =>
      servings.firstWhere((serving) => serving.isDefault);
}

class CatalogPackRetirement {
  final String id;
  final String? replacedBy;

  const CatalogPackRetirement({required this.id, required this.replacedBy});
}

class CatalogPackSource {
  final String id;
  final String licence;
  final String? attribution;

  /// Whether the values were reviewed against a reference. Pack v1 is not.
  final bool reviewed;

  const CatalogPackSource({
    required this.id,
    required this.licence,
    required this.attribution,
    required this.reviewed,
  });
}

class CatalogPack {
  final int version;
  final int? base;
  final bool isDelta;
  final int minAppBuild;
  final String registryVersion;
  final List<CatalogPackSource> sources;
  final List<CatalogPackFood> foods;
  final List<CatalogPackRetirement> retire;

  /// The sha256 of the gzip bytes this pack was decoded from.
  final String sha256;

  const CatalogPack({
    required this.version,
    required this.base,
    required this.isDelta,
    required this.minAppBuild,
    required this.registryVersion,
    required this.sources,
    required this.foods,
    required this.retire,
    required this.sha256,
  });

  /// Verifies [bytes] against [expectedSha256], then decodes and validates
  /// the pack. Every rule here mirrors a table constraint or an invariant
  /// the importer relies on, so a pack that decodes can always be applied.
  static CatalogPack decode(
    List<int> bytes, {
    required String expectedSha256,
    required String registryVersion,
    required Set<String> nutrientIds,
    int appBuild = kCatalogAppBuild,
  }) {
    final digest = crypto.sha256.convert(bytes).toString();
    if (digest != expectedSha256.trim().toLowerCase()) {
      throw const CatalogPackError(
        'sha256_mismatch',
        'The pack does not match its published checksum.',
      );
    }
    final Object? raw;
    try {
      raw = jsonDecode(utf8.decode(gzip.decode(bytes)));
    } on FormatException catch (error) {
      throw CatalogPackError('malformed_pack', error.message);
    } on Exception {
      throw const CatalogPackError('malformed_pack', 'The pack is not gzip.');
    }
    return parse(
      raw,
      sha256: digest,
      registryVersion: registryVersion,
      nutrientIds: nutrientIds,
      appBuild: appBuild,
    );
  }

  static CatalogPack parse(
    Object? raw, {
    required String sha256,
    required String registryVersion,
    required Set<String> nutrientIds,
    int appBuild = kCatalogAppBuild,
  }) {
    final json = _map(raw, 'pack');
    if (json['format'] != kCatalogPackFormat) {
      throw CatalogPackError(
        'unsupported_format',
        'Pack format ${json['format']} is not supported.',
      );
    }
    final version = _positiveInt(json['version'], 'version');
    final kind = json['kind'];
    if (kind != 'full' && kind != 'delta') {
      throw CatalogPackError('invalid_kind', 'Unknown pack kind: $kind.');
    }
    final isDelta = kind == 'delta';
    final base = json['base'] == null
        ? null
        : _positiveInt(json['base'], 'base');
    if (isDelta && (base == null || base >= version)) {
      throw const CatalogPackError(
        'invalid_base',
        'A delta pack needs a base below its version.',
      );
    }
    final minAppBuild = _positiveInt(json['min_app_build'], 'min_app_build');
    if (minAppBuild > appBuild) {
      throw CatalogPackError(
        'app_too_old',
        'Pack $version needs app build $minAppBuild or later.',
      );
    }
    final packRegistry = '${json['registry_version']}';
    if (packRegistry != registryVersion) {
      throw CatalogPackError(
        'registry_mismatch',
        'Pack registry $packRegistry does not match $registryVersion.',
      );
    }

    final sources = [
      for (final entry in _list(json['sources'], 'sources'))
        _source(_map(entry, 'source')),
    ];
    final sourceIds = sources.map((source) => source.id).toSet();
    if (sourceIds.length != sources.length) {
      throw const CatalogPackError('duplicate_source', 'Source ids repeat.');
    }

    final foods = <CatalogPackFood>[];
    final foodIds = <String>{};
    for (final entry in _list(json['foods'], 'foods')) {
      final food = _food(_map(entry, 'food'), nutrientIds, sourceIds);
      if (!foodIds.add(food.id)) {
        throw CatalogPackError('duplicate_food', 'Food ${food.id} repeats.');
      }
      foods.add(food);
    }
    final retire = <CatalogPackRetirement>[];
    for (final entry in _list(json['retire'] ?? const [], 'retire')) {
      final map = _map(entry, 'retire');
      final id = _text(map['id'], 'retire.id');
      final replacedBy = map['replaced_by'] == null
          ? null
          : _text(map['replaced_by'], 'retire.replaced_by');
      if (replacedBy == id) {
        throw CatalogPackError(
          'invalid_retirement',
          'Food $id cannot replace itself.',
        );
      }
      retire.add(CatalogPackRetirement(id: id, replacedBy: replacedBy));
    }
    if (!isDelta) {
      for (final retirement in retire) {
        final replacement = retirement.replacedBy;
        if (replacement != null && !foodIds.contains(replacement)) {
          throw CatalogPackError(
            'dangling_replacement',
            'Retired food ${retirement.id} points at missing $replacement.',
          );
        }
      }
    }
    return CatalogPack(
      version: version,
      base: base,
      isDelta: isDelta,
      minAppBuild: minAppBuild,
      registryVersion: packRegistry,
      sources: List.unmodifiable(sources),
      foods: List.unmodifiable(foods),
      retire: List.unmodifiable(retire),
      sha256: sha256,
    );
  }

  static CatalogPackSource _source(Map<String, Object?> json) =>
      CatalogPackSource(
        id: _text(json['id'], 'source.id'),
        licence: _text(json['licence'], 'source.licence'),
        attribution: json['attribution'] as String?,
        reviewed: json['review'] == 'reviewed',
      );

  static CatalogPackFood _food(
    Map<String, Object?> json,
    Set<String> nutrientIds,
    Set<String> sourceIds,
  ) {
    final id = _text(json['id'], 'food.id');
    final sourceId = _text(json['source_id'], 'food.source_id');
    if (!sourceIds.contains(sourceId)) {
      throw CatalogPackError(
        'unknown_source',
        'Food $id cites unknown source $sourceId.',
      );
    }
    final facts = _map(json['facts'], 'food.facts');
    final basis = CatalogPackBasisContract.parse(facts['basis']);
    final values = <String, double>{};
    for (final entry in _map(facts['values'], 'food.facts.values').entries) {
      if (!nutrientIds.contains(entry.key)) {
        throw CatalogPackError(
          'unknown_nutrient',
          'Food $id has unknown nutrient ${entry.key}.',
        );
      }
      final value = entry.value;
      if (value is! num || !value.isFinite || value < 0) {
        throw CatalogPackError(
          'invalid_value',
          'Food $id has an invalid ${entry.key} value.',
        );
      }
      values[entry.key] = value.toDouble();
    }
    if (!values.containsKey('energy')) {
      throw CatalogPackError('missing_energy', 'Food $id has no energy.');
    }
    final servings = <CatalogPackServing>[];
    for (final entry in _list(json['servings'], 'food.servings')) {
      final map = _map(entry, 'serving');
      final amount = map['amount'];
      final grams = map['grams'];
      if (amount is! num || !amount.isFinite || amount <= 0) {
        throw CatalogPackError(
          'invalid_serving',
          'Food $id has a serving without a positive amount.',
        );
      }
      if (grams != null && (grams is! num || !grams.isFinite || grams <= 0)) {
        throw CatalogPackError(
          'invalid_serving',
          'Food $id has a serving with invalid grams.',
        );
      }
      servings.add(
        CatalogPackServing(
          id: _text(map['id'], 'serving.id'),
          unit: _text(map['unit'], 'serving.unit').toLowerCase(),
          amount: amount.toDouble(),
          grams: (grams as num?)?.toDouble(),
          isDefault: map['default'] == true,
        ),
      );
    }
    if (servings.where((serving) => serving.isDefault).length != 1) {
      throw CatalogPackError(
        'invalid_serving',
        'Food $id needs exactly one default serving.',
      );
    }
    final defaultServing = servings.firstWhere((serving) => serving.isDefault);
    if (basis == CatalogPackBasis.per100Grams && defaultServing.grams == null) {
      throw CatalogPackError(
        'invalid_serving',
        'Food $id is per 100 g, so its default serving needs grams.',
      );
    }
    final aliases = [
      for (final entry in _list(json['aliases'] ?? const [], 'food.aliases'))
        CatalogPackAlias(
          text: _text(_map(entry, 'alias')['text'], 'alias.text'),
          locale: _text(_map(entry, 'alias')['locale'], 'alias.locale'),
        ),
    ];
    return CatalogPackFood(
      id: id,
      displayName: _text(json['display_name'], 'food.display_name'),
      sourceRef: json['source_ref'] as String?,
      category: json['category'] as String?,
      sourceId: sourceId,
      basis: basis,
      values: Map.unmodifiable(values),
      servings: List.unmodifiable(servings),
      aliases: List.unmodifiable(aliases),
    );
  }
}

/// The small manifest published next to packs.
class CatalogPackManifest {
  final int latest;

  /// The oldest app build that can apply [latest], when the manifest says.
  /// Each pack repeats its own `min_app_build`, which [CatalogPack.decode]
  /// enforces; this lets a client skip the download altogether.
  final int? minAppBuild;
  final List<CatalogPackManifestEntry> packs;

  const CatalogPackManifest({
    required this.latest,
    required this.packs,
    this.minAppBuild,
  });

  factory CatalogPackManifest.parse(Object? raw) {
    final json = _map(raw, 'manifest');
    if (json['format'] != kCatalogPackFormat) {
      throw CatalogPackError(
        'unsupported_format',
        'Manifest format ${json['format']} is not supported.',
      );
    }
    final packs = [
      for (final entry in _list(json['packs'], 'packs'))
        CatalogPackManifestEntry._parse(_map(entry, 'manifest pack')),
    ];
    return CatalogPackManifest(
      latest: _positiveInt(json['latest'], 'latest'),
      minAppBuild: json['min_app_build'] == null
          ? null
          : _positiveInt(json['min_app_build'], 'min_app_build'),
      packs: List.unmodifiable(packs),
    );
  }

  /// The pack that takes a device from [installed] to [latest]: the delta
  /// whose base is [installed] when the manifest has one, else the full pack.
  CatalogPackManifestEntry entryFrom(int? installed) {
    for (final pack in packs) {
      if (pack.version == latest && pack.isDelta && pack.base == installed) {
        return pack;
      }
    }
    return fullPack(latest);
  }

  /// The full pack for [version], which every client can apply.
  CatalogPackManifestEntry fullPack(int version) => packs.firstWhere(
    (pack) => pack.version == version && !pack.isDelta,
    orElse: () => throw CatalogPackError(
      'missing_pack',
      'The manifest has no full pack $version.',
    ),
  );
}

class CatalogPackManifestEntry {
  final int version;
  final int? base;
  final bool isDelta;
  final String url;
  final String sha256;
  final int bytes;

  const CatalogPackManifestEntry({
    required this.version,
    required this.base,
    required this.isDelta,
    required this.url,
    required this.sha256,
    required this.bytes,
  });

  factory CatalogPackManifestEntry._parse(Map<String, Object?> json) {
    final kind = json['kind'];
    if (kind != 'full' && kind != 'delta') {
      throw CatalogPackError('invalid_kind', 'Unknown pack kind: $kind.');
    }
    return CatalogPackManifestEntry(
      version: _positiveInt(json['version'], 'version'),
      base: json['base'] == null ? null : _positiveInt(json['base'], 'base'),
      isDelta: kind == 'delta',
      url: _text(json['url'], 'url'),
      sha256: _text(json['sha256'], 'sha256'),
      bytes: _positiveInt(json['bytes'], 'bytes'),
    );
  }
}

Map<String, Object?> _map(Object? raw, String label) {
  if (raw is Map) return raw.cast<String, Object?>();
  throw CatalogPackError('malformed_pack', 'Expected an object for $label.');
}

List<Object?> _list(Object? raw, String label) {
  if (raw is List) return raw.cast<Object?>();
  throw CatalogPackError('malformed_pack', 'Expected a list for $label.');
}

String _text(Object? raw, String label) {
  if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  throw CatalogPackError('malformed_pack', 'Expected text for $label.');
}

int _positiveInt(Object? raw, String label) {
  if (raw is int && raw >= 1) return raw;
  throw CatalogPackError('malformed_pack', 'Expected a positive $label.');
}
