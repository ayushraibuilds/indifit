/// Canonical equipment item definitions.
enum CanonicalEquipmentItem {
  barbell('barbell', 'Barbell'),
  dumbbell('dumbbell', 'Dumbbell'),
  cable('cable', 'Cable'),
  machine('machine', 'Machine'),
  bodyweight('bodyweight', 'Bodyweight'),
  bands('bands', 'Resistance Bands'),
  kettlebell('kettlebell', 'Kettlebell'),
  bench('bench', 'Bench'),
  rack('rack', 'Power Rack'),
  cardioEquipment('cardio_equipment', 'Cardio Equipment');

  final String id;
  final String displayName;

  const CanonicalEquipmentItem(this.id, this.displayName);

  static CanonicalEquipmentItem? fromId(String id) {
    for (final item in CanonicalEquipmentItem.values) {
      if (item.id == id) return item;
    }
    return null;
  }
}

/// Result of looking up or normalizing equipment strings.
enum EquipmentLookupStatus { resolved, unresolved }

class EquipmentLookupResult {
  final EquipmentLookupStatus status;
  final List<CanonicalEquipmentItem> canonicalItems;
  final String originalString;

  const EquipmentLookupResult({
    required this.status,
    required this.canonicalItems,
    required this.originalString,
  });

  bool get isResolved =>
      status == EquipmentLookupStatus.resolved && canonicalItems.isNotEmpty;
  bool get isUnresolved =>
      status == EquipmentLookupStatus.unresolved || canonicalItems.isEmpty;
}

/// Normalizer & lookup fixture for equipment strings and legacy categories.
class EquipmentNormalizer {
  /// Equipment item alias mappings (normalized alias -> CanonicalEquipmentItem).
  static final Map<String, CanonicalEquipmentItem> aliasMap = {
    'barbell': CanonicalEquipmentItem.barbell,
    'barbells': CanonicalEquipmentItem.barbell,
    'dumbbell': CanonicalEquipmentItem.dumbbell,
    'dumbbells': CanonicalEquipmentItem.dumbbell,
    'db': CanonicalEquipmentItem.dumbbell,
    'cable': CanonicalEquipmentItem.cable,
    'cables': CanonicalEquipmentItem.cable,
    'machine': CanonicalEquipmentItem.machine,
    'machines': CanonicalEquipmentItem.machine,
    'bodyweight': CanonicalEquipmentItem.bodyweight,
    'body weight': CanonicalEquipmentItem.bodyweight,
    'calisthenics': CanonicalEquipmentItem.bodyweight,
    'bands': CanonicalEquipmentItem.bands,
    'resistance bands': CanonicalEquipmentItem.bands,
    'band': CanonicalEquipmentItem.bands,
    'kettlebell': CanonicalEquipmentItem.kettlebell,
    'kettlebells': CanonicalEquipmentItem.kettlebell,
    'kb': CanonicalEquipmentItem.kettlebell,
    'bench': CanonicalEquipmentItem.bench,
    'benches': CanonicalEquipmentItem.bench,
    'rack': CanonicalEquipmentItem.rack,
    'power rack': CanonicalEquipmentItem.rack,
    'squat rack': CanonicalEquipmentItem.rack,
    'cardio': CanonicalEquipmentItem.cardioEquipment,
    'cardio equipment': CanonicalEquipmentItem.cardioEquipment,
    'treadmill': CanonicalEquipmentItem.cardioEquipment,
    'exercise bike': CanonicalEquipmentItem.cardioEquipment,
    'elliptical': CanonicalEquipmentItem.cardioEquipment,
    'rower': CanonicalEquipmentItem.cardioEquipment,
  };

  /// Mappings for legacy UserProfiles.equipmentAccess categories.
  static final Map<String, List<CanonicalEquipmentItem>> legacyCategoryMap = {
    'full_gym': [
      CanonicalEquipmentItem.barbell,
      CanonicalEquipmentItem.dumbbell,
      CanonicalEquipmentItem.cable,
      CanonicalEquipmentItem.machine,
      CanonicalEquipmentItem.bodyweight,
      CanonicalEquipmentItem.bench,
      CanonicalEquipmentItem.rack,
    ],
    'dumbbells': [
      CanonicalEquipmentItem.dumbbell,
      CanonicalEquipmentItem.bodyweight,
      CanonicalEquipmentItem.bench,
    ],
    'dumbbell': [
      CanonicalEquipmentItem.dumbbell,
      CanonicalEquipmentItem.bodyweight,
      CanonicalEquipmentItem.bench,
    ],
    'bodyweight': [CanonicalEquipmentItem.bodyweight],
  };

  /// Normalizes single or combined equipment string (e.g. "Barbell, Bench" or "Dumbbells").
  static EquipmentLookupResult parseEquipmentString(String raw) {
    final original = raw;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return EquipmentLookupResult(
        status: EquipmentLookupStatus.unresolved,
        canonicalItems: const [],
        originalString: original,
      );
    }

    // Split combined strings by comma, slash, or plus
    final tokens = trimmed
        .split(RegExp(r'[,/+]'))
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty);
    final resolvedItems = <CanonicalEquipmentItem>[];
    bool hasUnresolved = false;

    for (final token in tokens) {
      final match = aliasMap[token];
      if (match != null) {
        if (!resolvedItems.contains(match)) {
          resolvedItems.add(match);
        }
      } else {
        hasUnresolved = true;
      }
    }

    if (resolvedItems.isNotEmpty && !hasUnresolved) {
      return EquipmentLookupResult(
        status: EquipmentLookupStatus.resolved,
        canonicalItems: resolvedItems,
        originalString: original,
      );
    } else if (resolvedItems.isNotEmpty && hasUnresolved) {
      // Partial match: preserve resolved items, but mark as unresolved overall
      return EquipmentLookupResult(
        status: EquipmentLookupStatus.unresolved,
        canonicalItems: resolvedItems,
        originalString: original,
      );
    } else {
      return EquipmentLookupResult(
        status: EquipmentLookupStatus.unresolved,
        canonicalItems: const [],
        originalString: original,
      );
    }
  }

  /// Map legacy equipmentAccess string to list of canonical equipment items.
  static EquipmentLookupResult parseLegacyCategory(String rawCategory) {
    final original = rawCategory;
    final clean = rawCategory.trim().toLowerCase();
    final items = legacyCategoryMap[clean];

    if (items != null) {
      return EquipmentLookupResult(
        status: EquipmentLookupStatus.resolved,
        canonicalItems: items,
        originalString: original,
      );
    }

    return EquipmentLookupResult(
      status: EquipmentLookupStatus.unresolved,
      canonicalItems: const [],
      originalString: original,
    );
  }

  /// Validates fixture integrity for equipment aliases and categories.
  static void validateFixtures() {
    // 1. Alias map entries must map to valid canonical items
    for (final entry in aliasMap.entries) {
      if (entry.key.trim().isEmpty) {
        throw StateError('Malformed empty equipment alias key');
      }
    }

    // 2. Legacy category map entries must map to valid non-empty canonical item lists
    for (final entry in legacyCategoryMap.entries) {
      if (entry.key.trim().isEmpty) {
        throw StateError('Malformed empty legacy category key');
      }
      if (entry.value.isEmpty) {
        throw StateError(
          'Legacy category "${entry.key}" maps to empty equipment list',
        );
      }
    }
  }
}
