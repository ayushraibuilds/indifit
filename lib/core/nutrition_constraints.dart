import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Version of the durable B03-16 taxonomy.  Changing a label or ordering does
/// not change this value; changing the meaning of a type or target does.
const int kNutritionConstraintTaxonomyVersion = 1;

/// Version of the pure, provider-free evaluation rules.
const String kNutritionConstraintRuleVersion = 'b03-16-rule-v1';

/// Version of the user-constraint value envelope stored in the existing v17
/// `value` column.
const int kNutritionConstraintValueContractVersion = 1;

sealed class NutritionConstraintError implements Exception {
  final String code;
  final String message;

  const NutritionConstraintError(this.code, this.message);

  @override
  String toString() => 'NutritionConstraintError($code): $message';
}

class NutritionConstraintValidationError extends NutritionConstraintError {
  const NutritionConstraintValidationError(super.code, super.message);
}

class NutritionConstraintConflictError extends NutritionConstraintError {
  const NutritionConstraintConflictError(super.code, super.message);
}

class NutritionConstraintNotFoundError extends NutritionConstraintError {
  const NutritionConstraintNotFoundError(super.code, super.message);
}

enum NutritionConstraintType {
  allergy,
  intolerance,
  religiousRestriction,
  ethicalPreference,
  dietaryPattern,
  tasteDislike,
  temporaryAvoidance,
  regionalPreference,
}

/// Alias used by callers that describe the stable type as a category.
typedef NutritionConstraintCategory = NutritionConstraintType;

extension NutritionConstraintTypeContract on NutritionConstraintType {
  String get stableId => switch (this) {
    NutritionConstraintType.allergy => 'allergy',
    NutritionConstraintType.intolerance => 'intolerance',
    NutritionConstraintType.religiousRestriction => 'religious_restriction',
    NutritionConstraintType.ethicalPreference => 'ethical_preference',
    NutritionConstraintType.dietaryPattern => 'dietary_pattern',
    NutritionConstraintType.tasteDislike => 'taste_dislike',
    NutritionConstraintType.temporaryAvoidance => 'temporary_avoidance',
    NutritionConstraintType.regionalPreference => 'regional_preference',
  };

  String get displayLabel => switch (this) {
    NutritionConstraintType.allergy => 'Allergy',
    NutritionConstraintType.intolerance => 'Intolerance',
    NutritionConstraintType.religiousRestriction =>
      'Religious or cultural restriction',
    NutritionConstraintType.ethicalPreference =>
      'Ethical or lifestyle preference',
    NutritionConstraintType.dietaryPattern => 'Dietary pattern',
    NutritionConstraintType.tasteDislike => 'Taste dislike',
    NutritionConstraintType.temporaryAvoidance => 'Temporary avoidance',
    NutritionConstraintType.regionalPreference => 'Regional preference',
  };

  static NutritionConstraintType fromStableId(String value) {
    return NutritionConstraintType.values.firstWhere(
      (type) => type.stableId == value,
      orElse: () => throw NutritionConstraintValidationError(
        'unsupported_constraint_type',
        'Unsupported dietary constraint type: $value.',
      ),
    );
  }
}

enum NutritionConstraintTargetType {
  food,
  foodFamily,
  ingredient,
  allergen,
  animalProduct,
  preparation,
  additive,
  region,
  nutrient,
  unknownOrUnsupported,
}

extension NutritionConstraintTargetTypeContract
    on NutritionConstraintTargetType {
  String get stableId => switch (this) {
    NutritionConstraintTargetType.food => 'food',
    NutritionConstraintTargetType.foodFamily => 'food_family',
    NutritionConstraintTargetType.ingredient => 'ingredient',
    NutritionConstraintTargetType.allergen => 'allergen',
    NutritionConstraintTargetType.animalProduct => 'animal_product',
    NutritionConstraintTargetType.preparation => 'preparation',
    NutritionConstraintTargetType.additive => 'additive',
    NutritionConstraintTargetType.region => 'region',
    NutritionConstraintTargetType.nutrient => 'nutrient',
    NutritionConstraintTargetType.unknownOrUnsupported => 'unknown',
  };

  static NutritionConstraintTargetType fromStableId(String value) {
    return switch (value) {
      'food' => NutritionConstraintTargetType.food,
      'food_family' => NutritionConstraintTargetType.foodFamily,
      'ingredient' => NutritionConstraintTargetType.ingredient,
      'allergen' => NutritionConstraintTargetType.allergen,
      'animal_product' => NutritionConstraintTargetType.animalProduct,
      'preparation' => NutritionConstraintTargetType.preparation,
      'additive' => NutritionConstraintTargetType.additive,
      'region' => NutritionConstraintTargetType.region,
      'nutrient' => NutritionConstraintTargetType.nutrient,
      'unknown' || 'unknown_or_unsupported' =>
        NutritionConstraintTargetType.unknownOrUnsupported,
      _ => throw NutritionConstraintValidationError(
        'unsupported_target_type',
        'Unsupported dietary constraint target type: $value.',
      ),
    };
  }
}

/// Stable target identity.  The target ID is an identity key, never a label.
class NutritionConstraintTarget {
  final NutritionConstraintTargetType type;
  final String id;

  NutritionConstraintTarget({required this.type, required String id})
    : id = id.trim() {
    if (this.id.isEmpty || this.id.contains(':') || this.id.contains('\n')) {
      throw const NutritionConstraintValidationError(
        'invalid_constraint_target',
        'Constraint target IDs must be non-empty portable IDs.',
      );
    }
    if (type == NutritionConstraintTargetType.food &&
        RegExp(r'^\d+$').hasMatch(this.id)) {
      throw const NutritionConstraintValidationError(
        'local_id_not_portable',
        'Database-local numeric food IDs are not portable constraint identity.',
      );
    }
  }

  String get stableKey => '${type.stableId}:$id';

  Map<String, dynamic> toJson() => {'type': type.stableId, 'id': id};

  factory NutritionConstraintTarget.fromJson(Object? raw) {
    if (raw is! Map || raw['type'] is! String || raw['id'] is! String) {
      throw const NutritionConstraintValidationError(
        'malformed_constraint_target',
        'Constraint target must contain a stable type and ID.',
      );
    }
    return NutritionConstraintTarget(
      type: NutritionConstraintTargetTypeContract.fromStableId(
        raw['type'] as String,
      ),
      id: raw['id'] as String,
    );
  }

  factory NutritionConstraintTarget.fromStableKey(String value) {
    final separator = value.indexOf(':');
    if (separator <= 0 || separator == value.length - 1) {
      throw const NutritionConstraintValidationError(
        'malformed_constraint_target',
        'Constraint target keys must use type:id syntax.',
      );
    }
    return NutritionConstraintTarget(
      type: NutritionConstraintTargetTypeContract.fromStableId(
        value.substring(0, separator),
      ),
      id: value.substring(separator + 1),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NutritionConstraintTarget && other.stableKey == stableKey;

  @override
  int get hashCode => stableKey.hashCode;
}

enum NutritionConstraintStrictness { avoid, warn, informational }

extension NutritionConstraintStrictnessContract
    on NutritionConstraintStrictness {
  String get stableId => name;

  static NutritionConstraintStrictness fromStableId(String value) {
    return NutritionConstraintStrictness.values.firstWhere(
      (item) => item.stableId == value,
      orElse: () => throw NutritionConstraintValidationError(
        'unsupported_constraint_strictness',
        'Unsupported constraint strictness: $value.',
      ),
    );
  }
}

enum NutritionConstraintSource { userEntered, imported, legacy, approvedValue }

extension NutritionConstraintSourceContract on NutritionConstraintSource {
  String get stableId => switch (this) {
    NutritionConstraintSource.userEntered => 'user_entered',
    NutritionConstraintSource.imported => 'imported',
    NutritionConstraintSource.legacy => 'legacy',
    NutritionConstraintSource.approvedValue => 'approved_value',
  };

  static NutritionConstraintSource fromStableId(String value) {
    return NutritionConstraintSource.values.firstWhere(
      (item) => item.stableId == value,
      orElse: () => throw NutritionConstraintValidationError(
        'unsupported_constraint_source',
        'Unsupported constraint source: $value.',
      ),
    );
  }
}

enum NutritionConstraintEvidenceStatus {
  confirmed,
  possible,
  notIndicated,
  unknown,
}

extension NutritionConstraintEvidenceStatusContract
    on NutritionConstraintEvidenceStatus {
  String get stableId => switch (this) {
    NutritionConstraintEvidenceStatus.confirmed => 'confirmed',
    NutritionConstraintEvidenceStatus.possible => 'possible',
    NutritionConstraintEvidenceStatus.notIndicated => 'not_indicated',
    NutritionConstraintEvidenceStatus.unknown => 'unknown',
  };

  static NutritionConstraintEvidenceStatus fromStableId(String value) {
    return NutritionConstraintEvidenceStatus.values.firstWhere(
      (item) => item.stableId == value,
      orElse: () => throw NutritionConstraintValidationError(
        'unsupported_evidence_status',
        'Unsupported dietary evidence status: $value.',
      ),
    );
  }
}

enum NutritionConstraintEvidenceSource {
  reviewedCatalogue,
  explicitIngredientList,
  manufacturerDeclaration,
  userEntered,
  recipeIngredientGraph,
  reviewedAllergenDeclaration,
  importedProvider,
  aiEstimate,
  heuristic,
  legacy,
  unknown,
}

extension NutritionConstraintEvidenceSourceContract
    on NutritionConstraintEvidenceSource {
  String get stableId => switch (this) {
    NutritionConstraintEvidenceSource.reviewedCatalogue => 'reviewed_catalogue',
    NutritionConstraintEvidenceSource.explicitIngredientList =>
      'explicit_ingredient_list',
    NutritionConstraintEvidenceSource.manufacturerDeclaration =>
      'manufacturer_declaration',
    NutritionConstraintEvidenceSource.userEntered => 'user_entered',
    NutritionConstraintEvidenceSource.recipeIngredientGraph =>
      'recipe_ingredient_graph',
    NutritionConstraintEvidenceSource.reviewedAllergenDeclaration =>
      'reviewed_allergen_declaration',
    NutritionConstraintEvidenceSource.importedProvider => 'imported_provider',
    NutritionConstraintEvidenceSource.aiEstimate => 'ai_estimate',
    NutritionConstraintEvidenceSource.heuristic => 'heuristic',
    NutritionConstraintEvidenceSource.legacy => 'legacy',
    NutritionConstraintEvidenceSource.unknown => 'unknown',
  };

  static NutritionConstraintEvidenceSource fromStableId(String value) {
    return NutritionConstraintEvidenceSource.values.firstWhere(
      (item) => item.stableId == value,
      orElse: () => throw NutritionConstraintValidationError(
        'unsupported_evidence_source',
        'Unsupported dietary evidence source: $value.',
      ),
    );
  }
}

enum NutritionConstraintOutcome {
  confirmedConflict,
  possibleConflict,
  noKnownConflict,
  insufficientInformation,
}

extension NutritionConstraintOutcomeContract on NutritionConstraintOutcome {
  String get stableId => switch (this) {
    NutritionConstraintOutcome.confirmedConflict => 'confirmed_conflict',
    NutritionConstraintOutcome.possibleConflict => 'possible_conflict',
    NutritionConstraintOutcome.noKnownConflict => 'no_known_conflict',
    NutritionConstraintOutcome.insufficientInformation =>
      'insufficient_information',
  };

  static NutritionConstraintOutcome fromStableId(String value) {
    return NutritionConstraintOutcome.values.firstWhere(
      (item) => item.stableId == value,
      orElse: () => throw NutritionConstraintValidationError(
        'unsupported_constraint_outcome',
        'Unsupported dietary evaluation outcome: $value.',
      ),
    );
  }
}

/// The eight approved definition rows. Target identity is supplied separately
/// by a user constraint; a definition never uses its display label as a key.
class NutritionConstraintDefinition {
  final String id;
  final String key;
  final NutritionConstraintType type;
  final String displayName;
  final Set<NutritionConstraintTargetType> targetTypes;
  final bool severitySupported;
  final bool crossContactSupported;
  final int version;
  final String provenance;
  final bool deprecated;

  NutritionConstraintDefinition({
    required this.id,
    required this.key,
    required this.type,
    required this.displayName,
    required Iterable<NutritionConstraintTargetType> targetTypes,
    required this.severitySupported,
    required this.crossContactSupported,
    this.version = kNutritionConstraintTaxonomyVersion,
    this.provenance = 'reviewed_b03_taxonomy',
    this.deprecated = false,
  }) : targetTypes = Set.unmodifiable(targetTypes) {
    if (id.trim().isEmpty || key.trim().isEmpty || displayName.trim().isEmpty) {
      throw const NutritionConstraintValidationError(
        'invalid_constraint_definition',
        'Constraint definitions require stable identity and display metadata.',
      );
    }
    if (version != kNutritionConstraintTaxonomyVersion ||
        this.targetTypes.isEmpty ||
        provenance.trim().isEmpty) {
      throw const NutritionConstraintValidationError(
        'unsupported_taxonomy_version',
        'Constraint definition uses an unsupported or incomplete taxonomy.',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'key': key,
    'type': type.stableId,
    'display_name': displayName,
    'target_types': targetTypes.map((item) => item.stableId).toList()..sort(),
    'severity_supported': severitySupported,
    'cross_contact_supported': crossContactSupported,
    'version': version,
    'provenance': provenance,
    'deprecated': deprecated,
  };
}

class NutritionConstraintTaxonomy {
  NutritionConstraintTaxonomy._();

  static const _generalTargets = {
    NutritionConstraintTargetType.food,
    NutritionConstraintTargetType.foodFamily,
    NutritionConstraintTargetType.ingredient,
    NutritionConstraintTargetType.allergen,
    NutritionConstraintTargetType.animalProduct,
    NutritionConstraintTargetType.preparation,
    NutritionConstraintTargetType.additive,
  };

  static final List<NutritionConstraintDefinition> definitions =
      List.unmodifiable([
        NutritionConstraintDefinition(
          id: 'nutrition-constraint-type-allergy',
          key: 'allergy',
          type: NutritionConstraintType.allergy,
          displayName: 'Allergy',
          targetTypes: const {
            NutritionConstraintTargetType.food,
            NutritionConstraintTargetType.ingredient,
            NutritionConstraintTargetType.allergen,
          },
          severitySupported: true,
          crossContactSupported: true,
        ),
        NutritionConstraintDefinition(
          id: 'nutrition-constraint-type-intolerance',
          key: 'intolerance',
          type: NutritionConstraintType.intolerance,
          displayName: 'Intolerance',
          targetTypes: const {
            NutritionConstraintTargetType.food,
            NutritionConstraintTargetType.ingredient,
            NutritionConstraintTargetType.allergen,
          },
          severitySupported: true,
          crossContactSupported: true,
        ),
        NutritionConstraintDefinition(
          id: 'nutrition-constraint-type-religious-restriction',
          key: 'religious_restriction',
          type: NutritionConstraintType.religiousRestriction,
          displayName: 'Religious or cultural restriction',
          targetTypes: _generalTargets,
          severitySupported: false,
          crossContactSupported: true,
        ),
        NutritionConstraintDefinition(
          id: 'nutrition-constraint-type-ethical-preference',
          key: 'ethical_preference',
          type: NutritionConstraintType.ethicalPreference,
          displayName: 'Ethical or lifestyle preference',
          targetTypes: _generalTargets,
          severitySupported: false,
          crossContactSupported: true,
        ),
        NutritionConstraintDefinition(
          id: 'nutrition-constraint-type-dietary-pattern',
          key: 'dietary_pattern',
          type: NutritionConstraintType.dietaryPattern,
          displayName: 'Dietary pattern',
          targetTypes: _generalTargets,
          severitySupported: false,
          crossContactSupported: true,
        ),
        NutritionConstraintDefinition(
          id: 'nutrition-constraint-type-taste-dislike',
          key: 'taste_dislike',
          type: NutritionConstraintType.tasteDislike,
          displayName: 'Taste dislike',
          targetTypes: const {
            NutritionConstraintTargetType.food,
            NutritionConstraintTargetType.foodFamily,
            NutritionConstraintTargetType.ingredient,
          },
          severitySupported: false,
          crossContactSupported: false,
        ),
        NutritionConstraintDefinition(
          id: 'nutrition-constraint-type-temporary-avoidance',
          key: 'temporary_avoidance',
          type: NutritionConstraintType.temporaryAvoidance,
          displayName: 'Temporary avoidance',
          targetTypes: _generalTargets,
          severitySupported: false,
          crossContactSupported: true,
        ),
        NutritionConstraintDefinition(
          id: 'nutrition-constraint-type-regional-preference',
          key: 'regional_preference',
          type: NutritionConstraintType.regionalPreference,
          displayName: 'Regional preference',
          targetTypes: const {
            NutritionConstraintTargetType.region,
            NutritionConstraintTargetType.foodFamily,
          },
          severitySupported: false,
          crossContactSupported: false,
        ),
      ]);

  static final Map<String, NutritionConstraintDefinition> _byId = {
    for (final definition in definitions) definition.id: definition,
  };

  static NutritionConstraintDefinition definitionForId(String id) {
    final definition = _byId[id];
    if (definition == null || definition.deprecated) {
      throw NutritionConstraintValidationError(
        'unsupported_constraint_definition',
        'Unknown or deprecated constraint definition: $id.',
      );
    }
    return definition;
  }

  static NutritionConstraintDefinition definitionForType(
    NutritionConstraintType type,
  ) => definitions.firstWhere((definition) => definition.type == type);

  static NutritionConstraintDefinition definitionForKey(String key) =>
      definitions.firstWhere(
        (definition) => definition.key == key,
        orElse: () => throw NutritionConstraintValidationError(
          'unsupported_constraint_definition',
          'Unknown constraint definition key: $key.',
        ),
      );

  static void validateDefinition(NutritionConstraintDefinition definition) {
    final expected = definitionForId(definition.id);
    if (expected.key != definition.key ||
        expected.type != definition.type ||
        expected.version != definition.version ||
        expected.severitySupported != definition.severitySupported ||
        expected.crossContactSupported != definition.crossContactSupported ||
        expected.provenance != definition.provenance ||
        expected.deprecated != definition.deprecated ||
        expected.targetTypes.length != definition.targetTypes.length ||
        !expected.targetTypes.every(definition.targetTypes.contains)) {
      throw const NutritionConstraintValidationError(
        'constraint_definition_mismatch',
        'Persisted constraint definition does not match the approved taxonomy.',
      );
    }
  }

  static void validateRegistry(
    Iterable<NutritionConstraintDefinition> registry,
  ) {
    final values = registry.toList(growable: false);
    final ids = <String>{};
    final types = <NutritionConstraintType>{};
    for (final definition in values) {
      if (!ids.add(definition.id) || !types.add(definition.type)) {
        throw const NutritionConstraintValidationError(
          'duplicate_constraint_definition',
          'Constraint taxonomy IDs and types must be unique.',
        );
      }
      validateDefinition(definition);
    }
    if (ids.length != definitions.length ||
        !definitions.every((definition) => ids.contains(definition.id))) {
      throw const NutritionConstraintValidationError(
        'incomplete_constraint_taxonomy',
        'The approved dietary taxonomy cannot be partially replaced.',
      );
    }
  }
}

class NutritionUserConstraint {
  final String id;
  final String userId;
  final String definitionId;
  final NutritionConstraintType type;
  final NutritionConstraintTarget target;
  final NutritionConstraintStrictness strictness;
  final String? severity;
  final bool crossContact;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final NutritionConstraintSource source;
  final String? notes;
  final bool isActive;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  NutritionUserConstraint({
    required String id,
    required String userId,
    required String definitionId,
    required this.type,
    required this.target,
    required this.strictness,
    this.severity,
    this.crossContact = false,
    required DateTime effectiveFrom,
    this.effectiveTo,
    required this.source,
    this.notes,
    this.isActive = true,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
  }) : effectiveFrom = effectiveFrom.toUtc(),
       createdAtUtc = (createdAtUtc ?? effectiveFrom).toUtc(),
       updatedAtUtc = (updatedAtUtc ?? createdAtUtc ?? effectiveFrom).toUtc(),
       userId = userId.trim(),
       id = id.trim(),
       definitionId = definitionId.trim() {
    validate();
  }

  void validate() {
    if (id.isEmpty || userId.isEmpty || definitionId.isEmpty) {
      throw const NutritionConstraintValidationError(
        'invalid_user_constraint',
        'User constraints require portable ID, owner, and definition.',
      );
    }
    if (effectiveTo != null && effectiveTo!.isBefore(effectiveFrom)) {
      throw const NutritionConstraintValidationError(
        'invalid_effective_period',
        'Constraint effective_to cannot precede effective_from.',
      );
    }
    final definition = NutritionConstraintTaxonomy.definitionForId(
      definitionId,
    );
    if (target.type == NutritionConstraintTargetType.unknownOrUnsupported ||
        definition.type != type ||
        !definition.targetTypes.contains(target.type)) {
      throw const NutritionConstraintValidationError(
        'invalid_constraint_target',
        'Constraint target type is not approved for its definition.',
      );
    }
    if (!definition.severitySupported && severity != null) {
      throw const NutritionConstraintValidationError(
        'unsupported_constraint_severity',
        'This constraint type does not support severity.',
      );
    }
    if (!definition.crossContactSupported && crossContact) {
      throw const NutritionConstraintValidationError(
        'unsupported_cross_contact',
        'This constraint type does not support cross-contact handling.',
      );
    }
    if (severity != null && severity!.trim().isEmpty) {
      throw const NutritionConstraintValidationError(
        'invalid_constraint_severity',
        'Constraint severity cannot be blank.',
      );
    }
  }

  bool isEffectiveAt(DateTime instant) {
    final value = instant.toUtc();
    return isActive &&
        !value.isBefore(effectiveFrom) &&
        (effectiveTo == null || value.isBefore(effectiveTo!));
  }

  String get targetKey => target.stableKey;

  String encodeValue() => jsonEncode(
    _canonicalize({
      'contract_version': kNutritionConstraintValueContractVersion,
      'target': target.toJson(),
      'active': isActive,
    }),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'definition_id': definitionId,
    'type': type.stableId,
    'target': target.toJson(),
    'strictness': strictness.stableId,
    if (severity != null) 'severity': severity,
    'cross_contact': crossContact,
    'effective_from': effectiveFrom.toIso8601String(),
    if (effectiveTo != null) 'effective_to': effectiveTo!.toIso8601String(),
    'source': source.stableId,
    if (notes != null) 'notes': notes,
    'active': isActive,
    'created_at': createdAtUtc.toIso8601String(),
    'updated_at': updatedAtUtc.toIso8601String(),
  };

  NutritionUserConstraint copyWith({
    NutritionConstraintStrictness? strictness,
    String? severity,
    bool clearSeverity = false,
    bool? crossContact,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    bool clearEffectiveTo = false,
    NutritionConstraintSource? source,
    String? notes,
    bool clearNotes = false,
    bool? isActive,
    DateTime? updatedAtUtc,
  }) => NutritionUserConstraint(
    id: id,
    userId: userId,
    definitionId: definitionId,
    type: type,
    target: target,
    strictness: strictness ?? this.strictness,
    severity: clearSeverity ? null : severity ?? this.severity,
    crossContact: crossContact ?? this.crossContact,
    effectiveFrom: effectiveFrom ?? this.effectiveFrom,
    effectiveTo: clearEffectiveTo ? null : effectiveTo ?? this.effectiveTo,
    source: source ?? this.source,
    notes: clearNotes ? null : notes ?? this.notes,
    isActive: isActive ?? this.isActive,
    createdAtUtc: createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? DateTime.now().toUtc(),
  );
}

class NutritionConstraintEvidence {
  final String id;
  final String subjectId;
  final NutritionConstraintTarget target;
  final NutritionConstraintEvidenceStatus status;
  final NutritionConstraintEvidenceSource source;
  final double? confidence;
  final String? notes;
  final String? sourceReference;
  final String? ingredientLineage;
  final int version;

  NutritionConstraintEvidence({
    required String id,
    required String subjectId,
    required this.target,
    required this.status,
    required this.source,
    this.confidence,
    this.notes,
    this.sourceReference,
    this.ingredientLineage,
    this.version = 1,
  }) : id = id.trim(),
       subjectId = subjectId.trim() {
    validate();
  }

  void validate() {
    if (id.isEmpty || subjectId.isEmpty || version < 1) {
      throw const NutritionConstraintValidationError(
        'invalid_constraint_evidence',
        'Evidence requires portable identity, subject, and positive version.',
      );
    }
    if (confidence != null &&
        (!confidence!.isFinite || confidence! < 0 || confidence! > 1)) {
      throw const NutritionConstraintValidationError(
        'invalid_evidence_confidence',
        'Evidence confidence must be between zero and one.',
      );
    }
    if (status == NutritionConstraintEvidenceStatus.confirmed &&
        const {
          NutritionConstraintEvidenceSource.aiEstimate,
          NutritionConstraintEvidenceSource.heuristic,
          NutritionConstraintEvidenceSource.importedProvider,
          NutritionConstraintEvidenceSource.legacy,
          NutritionConstraintEvidenceSource.unknown,
        }.contains(source)) {
      throw const NutritionConstraintValidationError(
        'estimated_evidence_cannot_be_confirmed',
        'Estimated, imported, legacy, or unknown evidence cannot claim confirmed presence.',
      );
    }
    for (final value in [notes, sourceReference, ingredientLineage]) {
      if (value != null && value.trim().isEmpty) {
        throw const NutritionConstraintValidationError(
          'invalid_constraint_evidence',
          'Evidence metadata cannot be blank.',
        );
      }
    }
  }

  bool get isKnownAbsence =>
      status == NutritionConstraintEvidenceStatus.notIndicated &&
      const {
        NutritionConstraintEvidenceSource.reviewedCatalogue,
        NutritionConstraintEvidenceSource.explicitIngredientList,
        NutritionConstraintEvidenceSource.manufacturerDeclaration,
        NutritionConstraintEvidenceSource.reviewedAllergenDeclaration,
        NutritionConstraintEvidenceSource.recipeIngredientGraph,
        NutritionConstraintEvidenceSource.userEntered,
      }.contains(source);

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject_id': subjectId,
    'target': target.toJson(),
    'status': status.stableId,
    'source': source.stableId,
    if (confidence != null) 'confidence': confidence,
    if (notes != null) 'notes': notes,
    if (sourceReference != null) 'source_reference': sourceReference,
    if (ingredientLineage != null) 'ingredient_lineage': ingredientLineage,
    'version': version,
  };

  String encodeStorageNotes() => jsonEncode(
    _canonicalize({
      'contract_version': kNutritionConstraintValueContractVersion,
      if (sourceReference != null) 'source_reference': sourceReference,
      if (ingredientLineage != null) 'ingredient_lineage': ingredientLineage,
      if (notes != null) 'notes': notes,
    }),
  );

  static Map<String, dynamic> decodeStorageNotes(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map ||
          decoded['contract_version'] !=
              kNutritionConstraintValueContractVersion) {
        return {'notes': raw};
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return {'notes': raw};
    }
  }
}

class NutritionConstraintSubjectLine {
  final String id;
  final String foodId;
  final List<NutritionConstraintEvidence> evidence;

  NutritionConstraintSubjectLine({
    required String id,
    required String foodId,
    required Iterable<NutritionConstraintEvidence> evidence,
  }) : id = id.trim(),
       foodId = foodId.trim(),
       evidence = List.unmodifiable(evidence) {
    if (this.id.isEmpty || this.foodId.isEmpty) {
      throw const NutritionConstraintValidationError(
        'invalid_constraint_subject_line',
        'Recipe ingredient lines require stable line and food identity.',
      );
    }
    for (final item in this.evidence) {
      item.validate();
      if (item.subjectId != this.foodId && item.subjectId != this.id) {
        throw const NutritionConstraintValidationError(
          'evidence_subject_mismatch',
          'Ingredient evidence must identify its food or ingredient line.',
        );
      }
    }
  }
}

class NutritionConstraintEvaluationInput {
  final String userId;
  final String subjectId;
  final String? foodId;
  final String? recipeVersionId;
  final List<NutritionConstraintEvidence> evidence;
  final List<NutritionConstraintSubjectLine> lines;
  final DateTime evaluatedAtUtc;

  NutritionConstraintEvaluationInput({
    required String userId,
    required String subjectId,
    String? foodId,
    String? recipeVersionId,
    Iterable<NutritionConstraintEvidence> evidence = const [],
    Iterable<NutritionConstraintSubjectLine> lines = const [],
    DateTime? evaluatedAtUtc,
  }) : userId = userId.trim(),
       subjectId = subjectId.trim(),
       foodId = _optional(foodId),
       recipeVersionId = _optional(recipeVersionId),
       evidence = List.unmodifiable(evidence),
       lines = List.unmodifiable(lines),
       evaluatedAtUtc = (evaluatedAtUtc ?? DateTime.now()).toUtc() {
    validate();
  }

  bool get isRecipe => recipeVersionId != null;

  void validate() {
    if (userId.isEmpty || subjectId.isEmpty) {
      throw const NutritionConstraintValidationError(
        'invalid_evaluation_subject',
        'Evaluation requires user and subject identity.',
      );
    }
    if ((foodId == null) == (recipeVersionId == null)) {
      throw const NutritionConstraintValidationError(
        'invalid_evaluation_subject',
        'Evaluation must identify exactly one direct food or recipe version.',
      );
    }
    if (foodId != null && lines.isNotEmpty) {
      throw const NutritionConstraintValidationError(
        'invalid_evaluation_subject',
        'Direct-food evaluation cannot contain recipe ingredient lines.',
      );
    }
    if (recipeVersionId != null && lines.isEmpty) {
      throw const NutritionConstraintValidationError(
        'unknown_recipe_composition',
        'Recipe evaluation requires its immutable ingredient graph.',
      );
    }
    for (final item in evidence) {
      item.validate();
      if (foodId != null &&
          item.subjectId != foodId &&
          item.subjectId != subjectId) {
        throw const NutritionConstraintValidationError(
          'evidence_subject_mismatch',
          'Direct-food evidence belongs to a different subject.',
        );
      }
    }
  }
}

class NutritionConstraintEvidenceReference {
  final String evidenceId;
  final String subjectId;
  final String? foodId;
  final String? ingredientLineage;
  final String targetKey;
  final NutritionConstraintEvidenceStatus status;
  final NutritionConstraintEvidenceSource source;
  final int version;

  const NutritionConstraintEvidenceReference({
    required this.evidenceId,
    required this.subjectId,
    required this.foodId,
    required this.ingredientLineage,
    required this.targetKey,
    required this.status,
    required this.source,
    required this.version,
  });

  Map<String, dynamic> toJson() => {
    'evidence_id': evidenceId,
    'subject_id': subjectId,
    if (foodId != null) 'food_id': foodId,
    if (ingredientLineage != null) 'ingredient_lineage': ingredientLineage,
    'target_key': targetKey,
    'status': status.stableId,
    'source': source.stableId,
    'version': version,
  };

  factory NutritionConstraintEvidenceReference.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const NutritionConstraintValidationError(
        'malformed_constraint_evidence_reference',
        'Constraint evidence references must be objects.',
      );
    }
    final foodId = raw['food_id'];
    if (foodId != null && foodId is! String) {
      throw const NutritionConstraintValidationError(
        'malformed_constraint_evidence_reference',
        'Constraint evidence food identity must be text.',
      );
    }
    final ingredientLineage = raw['ingredient_lineage'];
    if (ingredientLineage != null && ingredientLineage is! String) {
      throw const NutritionConstraintValidationError(
        'malformed_constraint_evidence_reference',
        'Constraint evidence ingredient lineage must be text.',
      );
    }
    final version = raw['version'];
    if (version is! int || version < 1) {
      throw const NutritionConstraintValidationError(
        'malformed_constraint_evidence_reference',
        'Constraint evidence versions must be positive integers.',
      );
    }
    final targetKey = _requiredString(raw['target_key'], 'target_key');
    NutritionConstraintTarget.fromStableKey(targetKey);
    return NutritionConstraintEvidenceReference(
      evidenceId: _requiredString(raw['evidence_id'], 'evidence_id'),
      subjectId: _requiredString(raw['subject_id'], 'subject_id'),
      foodId: foodId as String?,
      ingredientLineage: ingredientLineage as String?,
      targetKey: targetKey,
      status: NutritionConstraintEvidenceStatusContract.fromStableId(
        _requiredString(raw['status'], 'status'),
      ),
      source: NutritionConstraintEvidenceSourceContract.fromStableId(
        _requiredString(raw['source'], 'source'),
      ),
      version: version,
    );
  }
}

class NutritionConstraintEvaluation {
  final String constraintId;
  final NutritionConstraintType type;
  final String targetKey;
  final NutritionConstraintOutcome outcome;
  final List<NutritionConstraintEvidenceReference> evidence;
  final List<String> affectedComponentIds;
  final List<String> missingEvidence;
  final List<String> reasonCodes;
  final bool acknowledged;

  const NutritionConstraintEvaluation({
    required this.constraintId,
    required this.type,
    required this.targetKey,
    required this.outcome,
    required this.evidence,
    required this.affectedComponentIds,
    required this.missingEvidence,
    required this.reasonCodes,
    this.acknowledged = false,
  });

  Map<String, dynamic> toJson() => {
    'constraint_id': constraintId,
    'type': type.stableId,
    'target_key': targetKey,
    'outcome': outcome.stableId,
    'evidence': evidence.map((item) => item.toJson()).toList(),
    'affected_component_ids': affectedComponentIds,
    'missing_evidence': missingEvidence,
    'reason_codes': reasonCodes,
    'acknowledged': acknowledged,
  };

  factory NutritionConstraintEvaluation.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const NutritionConstraintValidationError(
        'malformed_constraint_evaluation',
        'Constraint evaluations must be objects.',
      );
    }
    final evidence = raw['evidence'];
    if (evidence is! List) {
      throw const NutritionConstraintValidationError(
        'malformed_constraint_evaluation',
        'Constraint evaluations require an evidence list.',
      );
    }
    return NutritionConstraintEvaluation(
      constraintId: _requiredString(raw['constraint_id'], 'constraint_id'),
      type: NutritionConstraintTypeContract.fromStableId(
        _requiredString(raw['type'], 'type'),
      ),
      targetKey: _requiredString(raw['target_key'], 'target_key'),
      outcome: NutritionConstraintOutcomeContract.fromStableId(
        _requiredString(raw['outcome'], 'outcome'),
      ),
      evidence: [
        for (final item in evidence)
          NutritionConstraintEvidenceReference.fromJson(item),
      ],
      affectedComponentIds: _stringList(
        raw['affected_component_ids'],
        'affected_component_ids',
      ),
      missingEvidence: _stringList(raw['missing_evidence'], 'missing_evidence'),
      reasonCodes: _stringList(raw['reason_codes'], 'reason_codes'),
      acknowledged: raw['acknowledged'] == true,
    );
  }
}

class NutritionConstraintEvaluationResult {
  final String userId;
  final String subjectId;
  final String? foodId;
  final String? recipeVersionId;
  final NutritionConstraintOutcome outcome;
  final List<NutritionConstraintEvaluation> evaluations;
  final List<String> missingEvidence;
  final List<String> provenanceSummary;
  final String ruleVersion;
  final int taxonomyVersion;
  final DateTime evaluatedAtUtc;
  late final String fingerprint;

  NutritionConstraintEvaluationResult({
    required String userId,
    required String subjectId,
    required String? foodId,
    required String? recipeVersionId,
    required this.outcome,
    required Iterable<NutritionConstraintEvaluation> evaluations,
    required Iterable<String> missingEvidence,
    required Iterable<String> provenanceSummary,
    this.ruleVersion = kNutritionConstraintRuleVersion,
    this.taxonomyVersion = kNutritionConstraintTaxonomyVersion,
    DateTime? evaluatedAtUtc,
    String? fingerprint,
  }) : userId = userId.trim(),
       subjectId = subjectId.trim(),
       foodId = _optional(foodId),
       recipeVersionId = _optional(recipeVersionId),
       evaluatedAtUtc = (evaluatedAtUtc ?? DateTime.utc(1970)).toUtc(),
       evaluations = List.unmodifiable(evaluations),
       missingEvidence = _sortedUnique(missingEvidence),
       provenanceSummary = _sortedUnique(provenanceSummary) {
    if (userId.isEmpty ||
        subjectId.isEmpty ||
        ((foodId == null) == (recipeVersionId == null))) {
      throw const NutritionConstraintValidationError(
        'invalid_evaluation_subject',
        'A dietary evaluation requires one direct food or recipe version.',
      );
    }
    if (ruleVersion != kNutritionConstraintRuleVersion ||
        taxonomyVersion != kNutritionConstraintTaxonomyVersion) {
      throw const NutritionConstraintValidationError(
        'unsupported_evaluation_version',
        'Dietary evaluation uses an unsupported rule or taxonomy version.',
      );
    }
    final computed = _fingerprint(toJson(includeFingerprint: false));
    if (fingerprint != null && fingerprint != computed) {
      throw const NutritionConstraintValidationError(
        'evaluation_fingerprint_mismatch',
        'Dietary evaluation fingerprint does not match its immutable result.',
      );
    }
    this.fingerprint = computed;
  }

  Map<String, dynamic> toJson({bool includeFingerprint = true}) => {
    'contract_version': kNutritionConstraintValueContractVersion,
    'user_id': userId,
    'subject_id': subjectId,
    if (foodId != null) 'food_id': foodId,
    if (recipeVersionId != null) 'recipe_version_id': recipeVersionId,
    'outcome': outcome.stableId,
    'evaluations': evaluations.map((item) => item.toJson()).toList(),
    'missing_evidence': missingEvidence,
    'provenance_summary': provenanceSummary,
    'rule_version': ruleVersion,
    'taxonomy_version': taxonomyVersion,
    'evaluated_at': evaluatedAtUtc.toIso8601String(),
    if (includeFingerprint) 'fingerprint': fingerprint,
  };

  factory NutritionConstraintEvaluationResult.fromJson(Object? raw) {
    if (raw is! Map ||
        raw['contract_version'] != kNutritionConstraintValueContractVersion) {
      throw const NutritionConstraintValidationError(
        'unsupported_evaluation_contract',
        'Dietary evaluation evidence uses an unsupported contract version.',
      );
    }
    final evaluations = raw['evaluations'];
    if (evaluations is! List) {
      throw const NutritionConstraintValidationError(
        'malformed_constraint_evaluation',
        'Dietary evaluation evidence requires an evaluation list.',
      );
    }
    final foodId = raw['food_id'];
    final recipeVersionId = raw['recipe_version_id'];
    if ((foodId != null && foodId is! String) ||
        (recipeVersionId != null && recipeVersionId is! String)) {
      throw const NutritionConstraintValidationError(
        'malformed_constraint_evaluation',
        'Dietary evaluation subject identities must be text.',
      );
    }
    final fingerprint = raw['fingerprint'];
    if (fingerprint != null && fingerprint is! String) {
      throw const NutritionConstraintValidationError(
        'malformed_constraint_evaluation',
        'Dietary evaluation fingerprint must be text.',
      );
    }
    final taxonomyVersion = raw['taxonomy_version'];
    if (taxonomyVersion is! int) {
      throw const NutritionConstraintValidationError(
        'malformed_constraint_evaluation',
        'Dietary evaluation taxonomy version must be an integer.',
      );
    }
    final evaluatedAt = raw['evaluated_at'];
    if (evaluatedAt != null && evaluatedAt is! String) {
      throw const NutritionConstraintValidationError(
        'malformed_constraint_evaluation',
        'Dietary evaluation timestamp must be text.',
      );
    }
    return NutritionConstraintEvaluationResult(
      userId: _requiredString(raw['user_id'], 'user_id'),
      subjectId: _requiredString(raw['subject_id'], 'subject_id'),
      foodId: foodId as String?,
      recipeVersionId: recipeVersionId as String?,
      outcome: NutritionConstraintOutcomeContract.fromStableId(
        _requiredString(raw['outcome'], 'outcome'),
      ),
      evaluations: [
        for (final item in evaluations)
          NutritionConstraintEvaluation.fromJson(item),
      ],
      missingEvidence: _stringList(raw['missing_evidence'], 'missing_evidence'),
      provenanceSummary: _stringList(
        raw['provenance_summary'],
        'provenance_summary',
      ),
      ruleVersion: _requiredString(raw['rule_version'], 'rule_version'),
      taxonomyVersion: taxonomyVersion,
      evaluatedAtUtc: evaluatedAt == null
          ? DateTime.utc(1970)
          : DateTime.parse(evaluatedAt).toUtc(),
      fingerprint: fingerprint as String?,
    );
  }
}

class NutritionConstraintAcknowledgement {
  final String commandId;
  final String userId;
  final String evaluationFingerprint;
  final String constraintId;
  final String reason;
  final DateTime acknowledgedAtUtc;

  NutritionConstraintAcknowledgement({
    required String commandId,
    required String userId,
    required String evaluationFingerprint,
    required String constraintId,
    required String reason,
    DateTime? acknowledgedAtUtc,
  }) : commandId = commandId.trim(),
       userId = userId.trim(),
       evaluationFingerprint = evaluationFingerprint.trim(),
       constraintId = constraintId.trim(),
       reason = reason.trim(),
       acknowledgedAtUtc = (acknowledgedAtUtc ?? DateTime.now()).toUtc() {
    if (this.commandId.isEmpty ||
        this.userId.isEmpty ||
        this.evaluationFingerprint.isEmpty ||
        this.constraintId.isEmpty ||
        this.reason.isEmpty) {
      throw const NutritionConstraintValidationError(
        'invalid_constraint_acknowledgement',
        'Acknowledgement requires command, user, evaluation, constraint, and reason.',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'command_id': commandId,
    'user_id': userId,
    'evaluation_fingerprint': evaluationFingerprint,
    'constraint_id': constraintId,
    'reason': reason,
    'acknowledged_at': acknowledgedAtUtc.toIso8601String(),
  };

  factory NutritionConstraintAcknowledgement.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const NutritionConstraintValidationError(
        'malformed_constraint_acknowledgement',
        'Constraint acknowledgements must be objects.',
      );
    }
    final acknowledgedAt = raw['acknowledged_at'];
    if (acknowledgedAt is! String) {
      throw const NutritionConstraintValidationError(
        'malformed_constraint_acknowledgement',
        'Constraint acknowledgements require a timestamp.',
      );
    }
    return NutritionConstraintAcknowledgement(
      commandId: _requiredString(raw['command_id'], 'command_id'),
      userId: _requiredString(raw['user_id'], 'user_id'),
      evaluationFingerprint: _requiredString(
        raw['evaluation_fingerprint'],
        'evaluation_fingerprint',
      ),
      constraintId: _requiredString(raw['constraint_id'], 'constraint_id'),
      reason: _requiredString(raw['reason'], 'reason'),
      acknowledgedAtUtc: DateTime.parse(acknowledgedAt).toUtc(),
    );
  }
}

class NutritionConstraintEvaluator {
  const NutritionConstraintEvaluator();

  NutritionConstraintEvaluationResult evaluate({
    required NutritionConstraintEvaluationInput subject,
    required Iterable<NutritionUserConstraint> constraints,
    Iterable<String> acknowledgedConstraintIds = const [],
    String ruleVersion = kNutritionConstraintRuleVersion,
  }) {
    subject.validate();
    if (ruleVersion != kNutritionConstraintRuleVersion) {
      throw const NutritionConstraintValidationError(
        'unsupported_evaluation_version',
        'Unsupported dietary evaluation rule version.',
      );
    }
    final at = subject.evaluatedAtUtc;
    final active =
        constraints
            .where(
              (constraint) =>
                  constraint.userId == subject.userId &&
                  constraint.isEffectiveAt(at),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final acknowledgements = acknowledgedConstraintIds.toSet();
    final results = <NutritionConstraintEvaluation>[];
    final allProvenance = <String>{};
    final allMissing = <String>{};
    for (final constraint in active) {
      constraint.validate();
      final relevant = <NutritionConstraintEvidence>[];
      final components = <String>{};
      final missing = <String>{};
      final sources = <String>{};
      for (final item in _subjectEvidence(subject)) {
        if (_isUnknownComposition(item) ||
            _matches(constraint, item, subject)) {
          relevant.add(item);
          sources.add(item.source.stableId);
          if (item.status == NutritionConstraintEvidenceStatus.unknown) {
            missing.add('${item.subjectId}:${item.target.stableKey}');
          }
          if (item.status == NutritionConstraintEvidenceStatus.confirmed ||
              item.status == NutritionConstraintEvidenceStatus.possible) {
            components.add(item.ingredientLineage ?? item.subjectId);
          }
        }
      }
      final outcome = _outcomeFor(relevant: relevant);
      if (outcome == NutritionConstraintOutcome.insufficientInformation) {
        missing.add('${subject.subjectId}:${constraint.targetKey}');
      }
      final reasons = <String>{
        switch (outcome) {
          NutritionConstraintOutcome.confirmedConflict => 'confirmed_presence',
          NutritionConstraintOutcome.possibleConflict => 'possible_presence',
          NutritionConstraintOutcome.noKnownConflict => 'reviewed_no_detection',
          NutritionConstraintOutcome.insufficientInformation =>
            'composition_or_evidence_unknown',
        },
      };
      if (constraint.crossContact) {
        reasons.add('cross_contact_requested');
      }
      if (constraint.type == NutritionConstraintType.regionalPreference) {
        reasons.add('regional_preference_is_not_allergen_evidence');
      }
      final sortedEvidence = relevant.map((item) => _reference(item)).toList()
        ..sort((a, b) => a.evidenceId.compareTo(b.evidenceId));
      results.add(
        NutritionConstraintEvaluation(
          constraintId: constraint.id,
          type: constraint.type,
          targetKey: constraint.targetKey,
          outcome: outcome,
          evidence: sortedEvidence,
          affectedComponentIds: _sortedUnique(components),
          missingEvidence: _sortedUnique(missing),
          reasonCodes: _sortedUnique(reasons),
          acknowledged: acknowledgements.contains(constraint.id),
        ),
      );
      allProvenance.addAll(sources);
      allMissing.addAll(missing);
    }
    final overall = _aggregate(results.map((item) => item.outcome));
    if (active.isEmpty) allMissing.clear();
    return NutritionConstraintEvaluationResult(
      userId: subject.userId,
      subjectId: subject.subjectId,
      foodId: subject.foodId,
      recipeVersionId: subject.recipeVersionId,
      outcome: overall,
      evaluations: results,
      missingEvidence: allMissing,
      provenanceSummary: allProvenance,
      ruleVersion: ruleVersion,
      taxonomyVersion: kNutritionConstraintTaxonomyVersion,
      evaluatedAtUtc: subject.evaluatedAtUtc,
    );
  }

  Iterable<NutritionConstraintEvidence> _subjectEvidence(
    NutritionConstraintEvaluationInput subject,
  ) sync* {
    yield* subject.evidence;
    for (final line
        in subject.lines.toList()..sort((a, b) => a.id.compareTo(b.id))) {
      yield* line.evidence;
    }
  }

  NutritionConstraintOutcome _outcomeFor({
    required List<NutritionConstraintEvidence> relevant,
  }) {
    if (relevant.any(
      (item) => item.status == NutritionConstraintEvidenceStatus.confirmed,
    )) {
      return NutritionConstraintOutcome.confirmedConflict;
    }
    if (relevant.any(
      (item) => item.status == NutritionConstraintEvidenceStatus.possible,
    )) {
      return NutritionConstraintOutcome.possibleConflict;
    }
    if (relevant.any(
      (item) => item.status == NutritionConstraintEvidenceStatus.unknown,
    )) {
      return NutritionConstraintOutcome.insufficientInformation;
    }
    if (relevant.any((item) => item.isKnownAbsence)) {
      return NutritionConstraintOutcome.noKnownConflict;
    }
    // No evidence for a target is not evidence of absence. A recipe with any
    // line lacking evidence is explicitly incomplete, even if another line is
    // reviewed.
    return NutritionConstraintOutcome.insufficientInformation;
  }

  bool _matches(
    NutritionUserConstraint constraint,
    NutritionConstraintEvidence evidence,
    NutritionConstraintEvaluationInput subject,
  ) {
    final target = constraint.target;
    final evidenceTarget = evidence.target;
    if (target == evidenceTarget) return true;
    if (target.type == NutritionConstraintTargetType.food &&
        evidenceTarget.type == NutritionConstraintTargetType.food &&
        target.id == evidenceTarget.id) {
      return true;
    }
    if (target.type == NutritionConstraintTargetType.food &&
        subject.foodId == target.id &&
        evidenceTarget.type ==
            NutritionConstraintTargetType.unknownOrUnsupported) {
      return true;
    }
    if (target.type == NutritionConstraintTargetType.region &&
        evidenceTarget.type == NutritionConstraintTargetType.region &&
        target.id == evidenceTarget.id) {
      return true;
    }
    if (target.type == NutritionConstraintTargetType.animalProduct &&
        evidenceTarget.type == NutritionConstraintTargetType.animalProduct &&
        target.id == evidenceTarget.id) {
      return true;
    }
    if (constraint.type == NutritionConstraintType.dietaryPattern &&
        target.type == NutritionConstraintTargetType.ingredient &&
        target.id == evidenceTarget.id) {
      return true;
    }
    // These are deliberately small, explicit rule fixtures. They use only
    // typed evidence and never inspect names or infer an allergy.
    if (constraint.type == NutritionConstraintType.dietaryPattern &&
        target.type == NutritionConstraintTargetType.foodFamily) {
      return target.id == evidenceTarget.id ||
          _patternConflicts(target.id, evidenceTarget);
    }
    if (constraint.type == NutritionConstraintType.religiousRestriction) {
      return _religiousConflicts(target.id, evidenceTarget);
    }
    return false;
  }

  bool _patternConflicts(String pattern, NutritionConstraintTarget evidence) {
    if (evidence.type == NutritionConstraintTargetType.animalProduct) {
      return switch (pattern) {
        'vegan' => true,
        'vegetarian' => const {
          'meat',
          'poultry',
          'fish',
          'shellfish',
          'egg',
        }.contains(evidence.id),
        'eggetarian' => const {
          'meat',
          'poultry',
          'fish',
          'shellfish',
        }.contains(evidence.id),
        _ => false,
      };
    }
    return false;
  }

  bool _religiousConflicts(
    String observance,
    NutritionConstraintTarget evidence,
  ) {
    return switch (observance) {
      'jain' =>
        (evidence.type == NutritionConstraintTargetType.ingredient &&
                const {'onion', 'garlic'}.contains(evidence.id)) ||
            evidence.type == NutritionConstraintTargetType.animalProduct,
      'halal' =>
        (evidence.type == NutritionConstraintTargetType.animalProduct &&
                evidence.id == 'pork') ||
            (evidence.type == NutritionConstraintTargetType.additive &&
                evidence.id == 'alcohol'),
      _ => false,
    };
  }

  NutritionConstraintEvidenceReference _reference(
    NutritionConstraintEvidence evidence,
  ) => NutritionConstraintEvidenceReference(
    evidenceId: evidence.id,
    subjectId: evidence.subjectId,
    foodId: evidence.subjectId,
    ingredientLineage: evidence.ingredientLineage,
    targetKey: evidence.target.stableKey,
    status: evidence.status,
    source: evidence.source,
    version: evidence.version,
  );

  bool _isUnknownComposition(NutritionConstraintEvidence evidence) =>
      evidence.status == NutritionConstraintEvidenceStatus.unknown &&
      evidence.target.type ==
          NutritionConstraintTargetType.unknownOrUnsupported;

  NutritionConstraintOutcome _aggregate(
    Iterable<NutritionConstraintOutcome> outcomes,
  ) {
    final values = outcomes.toSet();
    if (values.contains(NutritionConstraintOutcome.confirmedConflict)) {
      return NutritionConstraintOutcome.confirmedConflict;
    }
    if (values.contains(NutritionConstraintOutcome.possibleConflict)) {
      return NutritionConstraintOutcome.possibleConflict;
    }
    if (values.contains(NutritionConstraintOutcome.insufficientInformation)) {
      return NutritionConstraintOutcome.insufficientInformation;
    }
    return NutritionConstraintOutcome.noKnownConflict;
  }
}

List<String> _sortedUnique(Iterable<String> values) {
  final result =
      values.where((value) => value.trim().isNotEmpty).toSet().toList()..sort();
  return List.unmodifiable(result);
}

String? _optional(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw NutritionConstraintValidationError(
      'malformed_constraint_evaluation',
      'Dietary constraint field $field must be non-blank text.',
    );
  }
  return value.trim();
}

List<String> _stringList(Object? value, String field) {
  if (value is! List || value.any((item) => item is! String)) {
    throw NutritionConstraintValidationError(
      'malformed_constraint_evaluation',
      'Dietary constraint field $field must be a string list.',
    );
  }
  return _sortedUnique(value.cast<String>());
}

Map<String, dynamic> _canonicalize(Map<String, dynamic> value) {
  dynamic normalize(Object? input) {
    if (input is Map) {
      final keys = input.keys.map((item) => item.toString()).toList()..sort();
      return {for (final key in keys) key: normalize(input[key])};
    }
    if (input is Iterable) return input.map(normalize).toList();
    return input;
  }

  return Map<String, dynamic>.from(normalize(value) as Map);
}

String _fingerprint(Map<String, dynamic> value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonicalize(value)))).toString();
