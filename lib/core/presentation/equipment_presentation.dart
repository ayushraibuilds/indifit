import 'package:flutter/material.dart';

import '../../data/repositories/equipment_preference_repository.dart';
import '../fixtures/equipment_fixtures.dart';
import '../theme/b05_semantic_colors.dart';

/// Presentation model for a single canonical equipment choice in the UI.
class EquipmentChoicePresentation {
  final String code;
  final String displayName;
  final IconData icon;
  final String description;
  final bool isDefaultImplicit;

  const EquipmentChoicePresentation({
    required this.code,
    required this.displayName,
    required this.icon,
    required this.description,
    this.isDefaultImplicit = false,
  });
}

/// Presentation catalogue and helper mappings for all canonical equipment items.
class EquipmentChoicesPresentation {
  EquipmentChoicesPresentation._();

  static const List<EquipmentChoicePresentation> allChoices = [
    EquipmentChoicePresentation(
      code: 'barbell',
      displayName: 'Barbell',
      icon: Icons.fitness_center_rounded,
      description: 'Olympic or standard barbells and plates',
    ),
    EquipmentChoicePresentation(
      code: 'dumbbell',
      displayName: 'Dumbbell',
      icon: Icons.fitness_center,
      description: 'Fixed or adjustable dumbbells',
    ),
    EquipmentChoicePresentation(
      code: 'kettlebell',
      displayName: 'Kettlebell',
      icon: Icons.sports_handball_rounded,
      description: 'Cast iron or competition kettlebells',
    ),
    EquipmentChoicePresentation(
      code: 'bench',
      displayName: 'Bench',
      icon: Icons.event_seat_rounded,
      description: 'Flat, incline, or adjustable workout bench',
    ),
    EquipmentChoicePresentation(
      code: 'rack',
      displayName: 'Power Rack',
      icon: Icons.grid_view_rounded,
      description: 'Squat rack, power cage, or half rack',
    ),
    EquipmentChoicePresentation(
      code: 'cable',
      displayName: 'Cable Machine',
      icon: Icons.tune_rounded,
      description: 'Cable crossover, functional trainer, or pulley stack',
    ),
    EquipmentChoicePresentation(
      code: 'machine',
      displayName: 'Weight Machine',
      icon: Icons.precision_manufacturing_rounded,
      description: 'Pin-loaded or plate-loaded selectorized machines',
    ),
    EquipmentChoicePresentation(
      code: 'bands',
      displayName: 'Resistance Bands',
      icon: Icons.linear_scale_rounded,
      description: 'Loop bands, tube bands, or pull-up assist bands',
    ),
    EquipmentChoicePresentation(
      code: 'cardio_equipment',
      displayName: 'Cardio Equipment',
      icon: Icons.directions_run_rounded,
      description: 'Treadmill, stationary bike, rower, or ski erg',
    ),
  ];

  static final Map<String, EquipmentChoicePresentation> _byCode = {
    for (final choice in allChoices) choice.code: choice,
  };

  /// Returns the editable items (excluding implicit bodyweight).
  static List<CanonicalEquipmentItem> get editableItems =>
      CanonicalEquipmentItem.values
          .where((item) => item != CanonicalEquipmentItem.bodyweight)
          .toList(growable: false);

  /// Find presentation descriptor by equipment code.
  static EquipmentChoicePresentation? find(String equipmentCode) {
    return _byCode[equipmentCode.trim()];
  }

  /// Get user-friendly display name for an equipment code.
  static String displayNameFor(String equipmentCode) {
    final normalized = equipmentCode.trim();
    if (normalized == 'bodyweight') return 'Bodyweight';
    return _byCode[normalized]?.displayName ??
        CanonicalEquipmentItem.fromId(normalized)?.displayName ??
        normalized;
  }

  /// Get semantic icon for an equipment code.
  static IconData iconFor(String equipmentCode) {
    final normalized = equipmentCode.trim();
    if (normalized == 'bodyweight') return Icons.accessibility_new_rounded;
    return _byCode[normalized]?.icon ?? Icons.fitness_center;
  }

  /// Starter profile presets.
  static const List<EquipmentPreset> presets = [
    EquipmentPreset(
      id: 'full_gym',
      name: 'Full Gym',
      description: 'Complete commercial or high-end gym setup.',
      includedItems: [
        CanonicalEquipmentItem.barbell,
        CanonicalEquipmentItem.dumbbell,
        CanonicalEquipmentItem.kettlebell,
        CanonicalEquipmentItem.bench,
        CanonicalEquipmentItem.rack,
        CanonicalEquipmentItem.cable,
        CanonicalEquipmentItem.machine,
        CanonicalEquipmentItem.cardioEquipment,
      ],
      standardIncrements: {
        'barbell': 5.0,
        'dumbbell': 2.5,
        'machine': 5.0,
        'cable': 2.5,
      },
    ),
    EquipmentPreset(
      id: 'home_gym',
      name: 'Home Gym',
      description: 'Free weights, bench, bands, and kettlebells.',
      includedItems: [
        CanonicalEquipmentItem.dumbbell,
        CanonicalEquipmentItem.bench,
        CanonicalEquipmentItem.kettlebell,
        CanonicalEquipmentItem.bands,
      ],
      standardIncrements: {
        'dumbbell': 2.5,
        'kettlebell': 2.0,
      },
    ),
    EquipmentPreset(
      id: 'dumbbells_only',
      name: 'Dumbbells Only',
      description: 'Pair of adjustable or fixed dumbbells and bench.',
      includedItems: [
        CanonicalEquipmentItem.dumbbell,
        CanonicalEquipmentItem.bench,
      ],
      standardIncrements: {
        'dumbbell': 2.5,
      },
    ),
    EquipmentPreset(
      id: 'bands_calisthenics',
      name: 'Bands & Calisthenics',
      description: 'Resistance bands and bodyweight movements.',
      includedItems: [
        CanonicalEquipmentItem.bands,
      ],
      standardIncrements: {},
    ),
  ];
}

/// Representation of an equipment starter preset.
class EquipmentPreset {
  final String id;
  final String name;
  final String description;
  final List<CanonicalEquipmentItem> includedItems;
  final Map<String, double> standardIncrements;

  const EquipmentPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.includedItems,
    required this.standardIncrements,
  });
}

/// Presentation model for a single equipment chip in a profile card.
class EquipmentProfileItemChipPresentation {
  final String code;
  final String name;
  final IconData icon;
  final String? incrementText;

  const EquipmentProfileItemChipPresentation({
    required this.code,
    required this.name,
    required this.icon,
    this.incrementText,
  });
}

/// View model for displaying an equipment profile with formatted metadata.
class EquipmentProfilePresentation {
  final String id;
  final String name;
  final bool isDefault;
  final String? note;
  final double? defaultIncrementKg;
  final int availableCount;
  final List<String> availableItemNames;
  final List<String> availableItemCodes;
  final List<EquipmentProfileItemChipPresentation> itemChips;
  final String summaryText;
  final String? legacyAccessCode;

  const EquipmentProfilePresentation({
    required this.id,
    required this.name,
    required this.isDefault,
    this.note,
    this.defaultIncrementKg,
    required this.availableCount,
    required this.availableItemNames,
    required this.availableItemCodes,
    required this.itemChips,
    required this.summaryText,
    this.legacyAccessCode,
  });

  String get formattedItemCount => availableCount == 1
      ? '1 equipment type available'
      : '$availableCount equipment types available';

  String? get formattedDefaultIncrement {
    if (defaultIncrementKg == null) return null;
    final val = defaultIncrementKg!;
    final formattedNum = val % 1 == 0 ? val.toInt().toString() : val.toString();
    return '$formattedNum kg';
  }

  factory EquipmentProfilePresentation.fromAggregate(
    EquipmentProfileAggregate aggregate, {
    bool isDefault = false,
  }) {
    final availableItems = aggregate.items.where((i) => i.isAvailable).toList();
    final itemNames = availableItems
        .map((i) => EquipmentChoicesPresentation.displayNameFor(i.equipmentCode))
        .toList(growable: false);
    final itemCodes = availableItems
        .map((i) => i.equipmentCode)
        .toList(growable: false);

    final chips = availableItems.map((item) {
      final choice = EquipmentChoicesPresentation.find(item.equipmentCode);
      final incText = item.weightIncrementKg != null
          ? '+${item.weightIncrementKg! % 1 == 0 ? item.weightIncrementKg!.toInt() : item.weightIncrementKg}kg'
          : null;
      return EquipmentProfileItemChipPresentation(
        code: item.equipmentCode,
        name: choice?.displayName ?? item.equipmentCode,
        icon: choice?.icon ?? Icons.fitness_center,
        incrementText: incText,
      );
    }).toList(growable: false);

    final summary = availableItems.isEmpty
        ? 'Bodyweight only'
        : '${availableItems.length} available · ${itemNames.join(', ')}';

    return EquipmentProfilePresentation(
      id: aggregate.profile.id,
      name: aggregate.profile.name,
      isDefault: isDefault,
      note: aggregate.profile.note,
      defaultIncrementKg: aggregate.profile.defaultWeightIncrementKg,
      availableCount: availableItems.length,
      availableItemNames: itemNames,
      availableItemCodes: itemCodes,
      itemChips: chips,
      summaryText: summary,
      legacyAccessCode: aggregate.profile.legacyAccessCode,
    );
  }
}

/// Presentation view model for equipment compatibility status.
class EquipmentCompatibilityPresentation {
  final EquipmentCompatibilityStatus status;
  final String label;
  final String detail;
  final B05SemanticStatus semanticStatus;
  final List<String> requiredItemNames;
  final List<String> missingItemNames;

  const EquipmentCompatibilityPresentation({
    required this.status,
    required this.label,
    required this.detail,
    required this.semanticStatus,
    required this.requiredItemNames,
    required this.missingItemNames,
  });

  factory EquipmentCompatibilityPresentation.fromCompatibility(
    EquipmentCompatibility compatibility,
  ) {
    final requiredNames = compatibility.requiredEquipmentCodes
        .map(EquipmentChoicesPresentation.displayNameFor)
        .toList(growable: false);
    final missingNames = compatibility.unavailableEquipmentCodes
        .map(EquipmentChoicesPresentation.displayNameFor)
        .toList(growable: false);

    switch (compatibility.status) {
      case EquipmentCompatibilityStatus.compatible:
        return EquipmentCompatibilityPresentation(
          status: compatibility.status,
          label: 'Compatible',
          detail: 'All required equipment is available in your profile.',
          semanticStatus: B05SemanticStatus.success,
          requiredItemNames: requiredNames,
          missingItemNames: const [],
        );
      case EquipmentCompatibilityStatus.incompatible:
        final missingStr = missingNames.isNotEmpty
            ? missingNames.join(', ')
            : 'Required equipment missing';
        return EquipmentCompatibilityPresentation(
          status: compatibility.status,
          label: 'Missing Equipment',
          detail: 'Requires: $missingStr',
          semanticStatus: B05SemanticStatus.warning,
          requiredItemNames: requiredNames,
          missingItemNames: missingNames,
        );
      case EquipmentCompatibilityStatus.unknown:
        return EquipmentCompatibilityPresentation(
          status: compatibility.status,
          label: 'Unverified Equipment',
          detail: 'Equipment requirement could not be automatically verified.',
          semanticStatus: B05SemanticStatus.info,
          requiredItemNames: requiredNames,
          missingItemNames: const [],
        );
    }
  }
}
