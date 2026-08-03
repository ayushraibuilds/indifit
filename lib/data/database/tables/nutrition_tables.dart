import 'package:drift/drift.dart';

/// The schema-v17 nutrition graph. These tables deliberately contain only
/// durable contracts; repositories and feature writers arrive in later B03
/// tasks.

class NutritionFoods extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get displayName => text()();
  TextColumn get locale => text()();
  TextColumn get sourceType => text()();
  TextColumn get sourceRef => text().nullable()();
  TextColumn get sourceVersion => text().nullable()();
  TextColumn get brand => text().nullable()();
  TextColumn get region => text().nullable()();
  TextColumn get lifecycle => text()();
  TextColumn get variantOfFoodId =>
      text().nullable().references(NutritionFoods, #id)();
  IntColumn get legacyFoodItemId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {sourceType, sourceRef, sourceVersion},
    {legacyFoodItemId},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (kind IN ('canonical', 'preparationVariant', 'regionalVariant', 'restaurantEstimate', 'homemadeEstimate', 'branded', 'servingPresentationVariant', 'userCreated', 'imported', 'aiEstimate', 'legacy', 'unknown'))",
    "CHECK (lifecycle IN ('active', 'deprecated', 'unresolved'))",
    "CHECK (source_type IN ('bundled_asset', 'regional_asset', 'provider', 'user', 'import', 'ai', 'fixture', 'legacy', 'reviewed_catalogue', 'manufacturer_label', 'user_entered', 'imported_provider', 'unknown'))",
    'CHECK (length(trim(id)) > 0)',
    'CHECK (length(trim(display_name)) > 0)',
    "CHECK (source_type <> 'provider' OR source_ref IS NOT NULL)",
    'CHECK (variant_of_food_id IS NULL OR variant_of_food_id <> id)',
  ];
}

class NutritionFoodAliases extends Table {
  TextColumn get id => text()();
  TextColumn get foodId => text().nullable().references(NutritionFoods, #id)();
  TextColumn get alias => text()();
  TextColumn get normalizedAlias => text()();
  TextColumn get locale => text()();
  TextColumn get source => text()();
  RealColumn get confidence => real().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {normalizedAlias, locale},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (length(trim(alias)) > 0)',
    'CHECK (length(trim(normalized_alias)) > 0)',
    'CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1))',
  ];
}

class NutritionFoodPreparations extends Table {
  TextColumn get id => text()();
  TextColumn get foodId => text().references(NutritionFoods, #id)();
  TextColumn get state => text()();
  TextColumn get method => text().nullable()();
  TextColumn get oilContext => text().nullable()();
  TextColumn get region => text().nullable()();
  TextColumn get source => text()();
  TextColumn get version => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {foodId, state, method, oilContext, region, version},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (state IN ('unspecified', 'raw', 'cooked'))",
    'CHECK (length(trim(source)) > 0)',
    'CHECK (length(trim(version)) > 0)',
  ];
}

class NutritionLegacyFoodMappings extends Table {
  IntColumn get legacyFoodItemId => integer()();
  TextColumn get foodId => text().nullable().references(NutritionFoods, #id)();
  TextColumn get mappingStatus => text()();
  TextColumn get evidence => text()();
  DateTimeColumn get mappedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {legacyFoodItemId};

  @override
  List<String> get customConstraints => [
    "CHECK (mapping_status IN ('reviewed', 'ambiguous', 'unresolved', 'legacy'))",
    'CHECK (length(trim(evidence)) > 0)',
  ];
}

class NutritionNutrientDefinitions extends Table {
  TextColumn get id => text()();
  TextColumn get key => text()();
  TextColumn get displayName => text()();
  TextColumn get unit => text()();
  TextColumn get kind => text()();
  IntColumn get sortOrder => integer()();
  IntColumn get version => integer()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {key, version},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (length(trim(id)) > 0)',
    'CHECK (length("key") > 0)',
    'CHECK (version >= 1)',
    'CHECK (sort_order >= 0)',
    "CHECK (unit IN ('energy_kilocalorie', 'mass_gram', 'mass_milligram', 'mass_microgram'))",
  ];
}

class NutritionFoodNutrientFacts extends Table {
  TextColumn get id => text()();
  TextColumn get foodId => text().references(NutritionFoods, #id)();
  TextColumn get nutrientId =>
      text().references(NutritionNutrientDefinitions, #id)();
  RealColumn get amount => real().nullable()();
  RealColumn get lower => real().nullable()();
  RealColumn get upper => real().nullable()();
  TextColumn get status => text()();
  TextColumn get source => text()();
  TextColumn get sourceRef => text().nullable()();
  RealColumn get confidence => real().nullable()();
  IntColumn get factVersion => integer()();
  TextColumn get basis => text()();
  RealColumn get basisQuantity => real().nullable()();
  TextColumn get basisUnit => text().nullable()();
  TextColumn get preparationId =>
      text().nullable().references(NutritionFoodPreparations, #id)();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {foodId, nutrientId, factVersion},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (status IN ('known', 'known_zero', 'missing', 'not_applicable', 'estimated'))",
    "CHECK (source IN ('reviewed_catalogue', 'manufacturer_label', 'user_entered', 'imported_provider', 'recipe_calculation', 'ai_estimate', 'heuristic', 'legacy', 'unknown'))",
    "CHECK (basis IN ('per_100_grams', 'per_100_millilitres', 'per_serving', 'absolute'))",
    'CHECK (amount IS NULL OR amount >= 0)',
    'CHECK (lower IS NULL OR lower >= 0)',
    'CHECK (upper IS NULL OR upper >= 0)',
    'CHECK (lower IS NULL OR upper IS NULL OR lower <= upper)',
    'CHECK (lower IS NULL OR amount IS NULL OR lower <= amount)',
    'CHECK (upper IS NULL OR amount IS NULL OR amount <= upper)',
    'CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1))',
    'CHECK (fact_version >= 1)',
    'CHECK (basis_quantity IS NULL OR basis_quantity > 0)',
    "CHECK ((basis IN ('per_serving', 'absolute')) OR basis_quantity IS NOT NULL)",
    "CHECK ((basis IN ('per_100_grams', 'per_100_millilitres')) = (basis_unit IS NOT NULL))",
    "CHECK ((status IN ('missing', 'not_applicable')) = (amount IS NULL AND lower IS NULL AND upper IS NULL))",
  ];
}

class NutritionQuantityConversions extends Table {
  TextColumn get id => text()();
  TextColumn get foodId => text().references(NutritionFoods, #id)();
  TextColumn get preparationId =>
      text().nullable().references(NutritionFoodPreparations, #id)();
  TextColumn get sourceUnit => text()();
  TextColumn get targetUnit => text()();
  RealColumn get factor => real()();
  RealColumn get lower => real().nullable()();
  RealColumn get upper => real().nullable()();
  TextColumn get method => text()();
  TextColumn get source => text()();
  RealColumn get confidence => real().nullable()();
  TextColumn get ruleVersion => text()();
  TextColumn get ownerScope => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {foodId, preparationId, sourceUnit, targetUnit, ruleVersion},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (factor > 0)',
    'CHECK (lower IS NULL OR lower > 0)',
    'CHECK (upper IS NULL OR upper > 0)',
    'CHECK (lower IS NULL OR upper IS NULL OR lower <= upper)',
    'CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1))',
    "CHECK (owner_scope IN ('catalogue', 'user'))",
  ];
}

class NutritionHouseholdMeasures extends Table {
  TextColumn get id => text()();
  TextColumn get key => text()();
  TextColumn get displayName => text()();
  TextColumn get dimension => text()();
  TextColumn get baseUnit => text()();
  RealColumn get nominalValue => real()();
  RealColumn get lower => real().nullable()();
  RealColumn get upper => real().nullable()();
  TextColumn get locale => text()();
  IntColumn get version => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {key, locale, version},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (dimension IN ('volume', 'mass', 'count', 'household_reference'))",
    'CHECK (nominal_value > 0)',
    'CHECK (lower IS NULL OR lower > 0)',
    'CHECK (upper IS NULL OR upper > 0)',
    'CHECK (lower IS NULL OR upper IS NULL OR lower <= upper)',
    'CHECK (version >= 1)',
    "CHECK ((dimension = 'mass' AND base_unit IN ('milligram', 'gram', 'kilogram')) OR (dimension = 'volume' AND base_unit IN ('millilitre', 'litre')) OR (dimension = 'count' AND base_unit = 'piece') OR (dimension = 'household_reference' AND base_unit = 'household_reference'))",
  ];
}

class NutritionVesselCalibrations extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get label => text()();
  TextColumn get measureId =>
      text().references(NutritionHouseholdMeasures, #id)();
  RealColumn get volumeMl => real()();
  RealColumn get lower => real().nullable()();
  RealColumn get upper => real().nullable()();
  TextColumn get method => text()();
  TextColumn get foodId => text().nullable().references(NutritionFoods, #id)();
  TextColumn get preparationId =>
      text().nullable().references(NutritionFoodPreparations, #id)();
  RealColumn get confidence => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {userId, label},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (volume_ml > 0)',
    'CHECK (lower IS NULL OR lower > 0)',
    'CHECK (upper IS NULL OR upper > 0)',
    'CHECK (lower IS NULL OR upper IS NULL OR lower <= upper)',
    'CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1))',
  ];
}

class NutritionRecipes extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get lifecycle => text()();
  TextColumn get currentVersionId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (lifecycle IN ('active', 'archived', 'deleted'))",
  ];
}

class NutritionRecipeVersions extends Table {
  TextColumn get id => text()();
  TextColumn get recipeId => text().references(NutritionRecipes, #id)();
  IntColumn get versionNumber => integer()();
  TextColumn get status => text()();
  RealColumn get yieldQuantity => real().nullable()();
  TextColumn get yieldUnit => text().nullable()();
  RealColumn get servingQuantity => real().nullable()();
  TextColumn get calcRuleVersion => text()();
  TextColumn get source => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {recipeId, versionNumber},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (status IN ('draft', 'published', 'archived'))",
    'CHECK (version_number >= 1)',
    'CHECK (yield_quantity IS NULL OR yield_quantity > 0)',
    'CHECK (serving_quantity IS NULL OR serving_quantity > 0)',
  ];
}

class NutritionRecipeIngredients extends Table {
  TextColumn get id => text()();
  TextColumn get recipeVersionId =>
      text().references(NutritionRecipeVersions, #id)();
  IntColumn get position => integer()();
  TextColumn get foodId => text().references(NutritionFoods, #id)();
  TextColumn get preparationId =>
      text().nullable().references(NutritionFoodPreparations, #id)();
  RealColumn get quantityValue => real()();
  TextColumn get quantityDimension => text()();
  TextColumn get quantityUnit => text()();
  TextColumn get measureId =>
      text().nullable().references(NutritionHouseholdMeasures, #id)();
  RealColumn get lower => real().nullable()();
  RealColumn get upper => real().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {recipeVersionId, position},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (position >= 0)',
    'CHECK (quantity_value > 0)',
    "CHECK (quantity_dimension IN ('mass', 'volume', 'count', 'serving', 'household_reference'))",
    "CHECK (quantity_unit IN ('milligram', 'gram', 'kilogram', 'millilitre', 'litre', 'piece', 'serving', 'household_reference'))",
    "CHECK ((quantity_dimension = 'mass' AND quantity_unit IN ('milligram', 'gram', 'kilogram')) OR (quantity_dimension = 'volume' AND quantity_unit IN ('millilitre', 'litre')) OR (quantity_dimension = 'count' AND quantity_unit = 'piece') OR (quantity_dimension = 'serving' AND quantity_unit = 'serving') OR (quantity_dimension = 'household_reference' AND quantity_unit = 'household_reference'))",
    'CHECK (lower IS NULL OR lower > 0)',
    'CHECK (upper IS NULL OR upper > 0)',
    'CHECK (lower IS NULL OR upper IS NULL OR lower <= upper)',
  ];
}

class NutritionUserCorrections extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get targetType => text()();
  TextColumn get targetId => text()();
  TextColumn get field => text()();
  TextColumn get oldValue => text().nullable()();
  TextColumn get newValue => text().nullable()();
  TextColumn get reason => text()();
  TextColumn get source => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class NutritionEstimates extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get source => text()();
  TextColumn get provider => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get ruleVersion => text().nullable()();
  TextColumn get inputHash => text().nullable()();
  TextColumn get assumptions => text().nullable()();
  RealColumn get confidence => real().nullable()();
  RealColumn get lower => real().nullable()();
  RealColumn get upper => real().nullable()();
  TextColumn get status => text()();
  TextColumn get supersedesId =>
      text().nullable().references(NutritionEstimates, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (source IN ('reviewed_catalogue', 'manufacturer_label', 'user_entered', 'imported_provider', 'recipe_calculation', 'ai_estimate', 'heuristic', 'legacy', 'unknown'))",
    "CHECK (status IN ('known', 'estimated', 'missing', 'superseded'))",
    'CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1))',
    'CHECK (lower IS NULL OR lower >= 0)',
    'CHECK (upper IS NULL OR upper >= 0)',
    'CHECK (lower IS NULL OR upper IS NULL OR lower <= upper)',
  ];
}

class NutritionEstimateNutrients extends Table {
  TextColumn get id => text()();
  TextColumn get estimateId => text().references(NutritionEstimates, #id)();
  TextColumn get nutrientId =>
      text().references(NutritionNutrientDefinitions, #id)();
  RealColumn get amount => real().nullable()();
  RealColumn get lower => real().nullable()();
  RealColumn get upper => real().nullable()();
  TextColumn get status => text()();
  TextColumn get unit => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {estimateId, nutrientId},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (status IN ('known', 'known_zero', 'missing', 'not_applicable', 'estimated'))",
    "CHECK (unit IN ('energy_kilocalorie', 'mass_gram', 'mass_milligram', 'mass_microgram'))",
    'CHECK (amount IS NULL OR amount >= 0)',
    'CHECK (lower IS NULL OR lower >= 0)',
    'CHECK (upper IS NULL OR upper >= 0)',
    'CHECK (lower IS NULL OR upper IS NULL OR lower <= upper)',
    'CHECK (lower IS NULL OR amount IS NULL OR lower <= amount)',
    'CHECK (upper IS NULL OR amount IS NULL OR amount <= upper)',
  ];
}

class NutritionThalis extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get lifecycle => text()();
  IntColumn get currentVersion => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (lifecycle IN ('active', 'archived', 'deleted'))",
    'CHECK (current_version >= 1)',
  ];
}

class NutritionThaliItems extends Table {
  TextColumn get id => text()();
  TextColumn get thaliId => text().references(NutritionThalis, #id)();
  IntColumn get position => integer()();
  TextColumn get foodId => text().nullable().references(NutritionFoods, #id)();
  TextColumn get recipeVersionId =>
      text().nullable().references(NutritionRecipeVersions, #id)();
  RealColumn get quantityValue => real()();
  TextColumn get quantityDimension => text()();
  TextColumn get quantityUnit => text()();
  TextColumn get measureId =>
      text().nullable().references(NutritionHouseholdMeasures, #id)();
  BoolColumn get optional => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {thaliId, position},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (position >= 0)',
    'CHECK ((food_id IS NOT NULL) != (recipe_version_id IS NOT NULL))',
    'CHECK (quantity_value > 0)',
    "CHECK (quantity_dimension IN ('mass', 'volume', 'count', 'serving', 'household_reference'))",
    "CHECK (quantity_unit IN ('milligram', 'gram', 'kilogram', 'millilitre', 'litre', 'piece', 'serving', 'household_reference'))",
    "CHECK ((quantity_dimension = 'mass' AND quantity_unit IN ('milligram', 'gram', 'kilogram')) OR (quantity_dimension = 'volume' AND quantity_unit IN ('millilitre', 'litre')) OR (quantity_dimension = 'count' AND quantity_unit = 'piece') OR (quantity_dimension = 'serving' AND quantity_unit = 'serving') OR (quantity_dimension = 'household_reference' AND quantity_unit = 'household_reference'))",
  ];
}

class NutritionConsumptionSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get loggedAt => dateTime()();
  TextColumn get mealCategory => text()();
  TextColumn get mealGroupId => text().nullable()();
  TextColumn get sourceType => text()();
  TextColumn get recipeVersionId =>
      text().nullable().references(NutritionRecipeVersions, #id)();
  TextColumn get thaliId =>
      text().nullable().references(NutritionThalis, #id)();
  TextColumn get calculatorVersion => text()();
  TextColumn get completeness => text()();
  TextColumn get estimateStatus => text()();
  TextColumn get localDate => text().nullable()();
  TextColumn get timezoneId => text().nullable()();
  TextColumn get lineage => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (completeness IN ('complete', 'partial', 'unknown', 'not_applicable', 'invalid'))",
    "CHECK (estimate_status IN ('none', 'estimated', 'mixed', 'unknown'))",
  ];
}

class NutritionSnapshotItems extends Table {
  TextColumn get id => text()();
  TextColumn get snapshotId =>
      text().references(NutritionConsumptionSnapshots, #id)();
  IntColumn get position => integer()();
  TextColumn get foodId => text().nullable().references(NutritionFoods, #id)();
  TextColumn get preparationId =>
      text().nullable().references(NutritionFoodPreparations, #id)();
  TextColumn get recipeVersionId =>
      text().nullable().references(NutritionRecipeVersions, #id)();
  RealColumn get quantityValue => real()();
  TextColumn get quantityDimension => text()();
  TextColumn get quantityUnit => text()();
  TextColumn get quantityContextId => text().nullable()();
  RealColumn get lower => real().nullable()();
  RealColumn get upper => real().nullable()();
  TextColumn get sourceRef => text().nullable()();
  TextColumn get basis => text().nullable()();
  TextColumn get conversionVersion => text().nullable()();
  TextColumn get calculationVersion => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {snapshotId, position},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (position >= 0)',
    'CHECK ((food_id IS NOT NULL) OR (recipe_version_id IS NOT NULL))',
    'CHECK (quantity_value > 0)',
    "CHECK (quantity_dimension IN ('mass', 'volume', 'count', 'serving', 'household_reference'))",
    "CHECK (quantity_unit IN ('milligram', 'gram', 'kilogram', 'millilitre', 'litre', 'piece', 'serving', 'household_reference'))",
    "CHECK ((quantity_dimension = 'mass' AND quantity_unit IN ('milligram', 'gram', 'kilogram')) OR (quantity_dimension = 'volume' AND quantity_unit IN ('millilitre', 'litre')) OR (quantity_dimension = 'count' AND quantity_unit = 'piece') OR (quantity_dimension = 'serving' AND quantity_unit = 'serving') OR (quantity_dimension = 'household_reference' AND quantity_unit = 'household_reference'))",
    'CHECK (lower IS NULL OR lower >= 0)',
    'CHECK (upper IS NULL OR upper >= 0)',
    'CHECK (lower IS NULL OR upper IS NULL OR lower <= upper)',
  ];
}

class NutritionSnapshotNutrients extends Table {
  TextColumn get id => text()();
  TextColumn get snapshotId =>
      text().references(NutritionConsumptionSnapshots, #id)();
  TextColumn get itemId =>
      text().nullable().references(NutritionSnapshotItems, #id)();
  TextColumn get nutrientId =>
      text().references(NutritionNutrientDefinitions, #id)();
  RealColumn get amount => real().nullable()();
  RealColumn get lower => real().nullable()();
  RealColumn get upper => real().nullable()();
  TextColumn get status => text()();
  TextColumn get unit => text()();
  TextColumn get sourceVersion => text()();
  TextColumn get basis => text().nullable()();
  TextColumn get factVersion => text().nullable()();
  TextColumn get lineage => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {snapshotId, itemId, nutrientId},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (status IN ('known', 'known_zero', 'missing', 'not_applicable', 'estimated'))",
    "CHECK (unit IN ('energy_kilocalorie', 'mass_gram', 'mass_milligram', 'mass_microgram'))",
    'CHECK (amount IS NULL OR amount >= 0)',
    'CHECK (lower IS NULL OR lower >= 0)',
    'CHECK (upper IS NULL OR upper >= 0)',
    'CHECK (lower IS NULL OR upper IS NULL OR lower <= upper)',
    'CHECK (lower IS NULL OR amount IS NULL OR lower <= amount)',
    'CHECK (upper IS NULL OR amount IS NULL OR amount <= upper)',
    "CHECK ((status IN ('missing', 'not_applicable')) = (amount IS NULL AND lower IS NULL AND upper IS NULL))",
  ];
}

class NutritionFoodConstraintEvidence extends Table {
  TextColumn get id => text()();
  TextColumn get foodId => text().references(NutritionFoods, #id)();
  TextColumn get constraintKey => text()();
  TextColumn get status => text()();
  TextColumn get evidenceSource => text()();
  RealColumn get confidence => real().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get version => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {foodId, constraintKey, version},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (status IN ('present', 'absent', 'unknown', 'cross_contact'))",
    'CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1))',
    'CHECK (version >= 1)',
  ];
}

class NutritionConstraintDefinitions extends Table {
  TextColumn get id => text()();
  TextColumn get key => text()();
  TextColumn get type => text()();
  TextColumn get displayName => text()();
  BoolColumn get severitySupported =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get crossContactSupported =>
      boolean().withDefault(const Constant(false))();
  IntColumn get version => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {key, version},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (length("key") > 0)',
    'CHECK (version >= 1)',
  ];
}

class NutritionUserConstraints extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get definitionId =>
      text().references(NutritionConstraintDefinitions, #id)();
  TextColumn get value => text()();
  TextColumn get strictness => text()();
  TextColumn get severity => text().nullable()();
  BoolColumn get crossContact => boolean().withDefault(const Constant(false))();
  DateTimeColumn get effectiveFrom => dateTime()();
  DateTimeColumn get effectiveTo => dateTime().nullable()();
  TextColumn get source => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (strictness IN ('avoid', 'warn', 'informational'))",
    'CHECK (effective_to IS NULL OR effective_to >= effective_from)',
  ];
}

class NutritionSnapshotConstraintResults extends Table {
  TextColumn get id => text()();
  TextColumn get snapshotId =>
      text().references(NutritionConsumptionSnapshots, #id)();
  TextColumn get constraintId =>
      text().references(NutritionUserConstraints, #id)();
  TextColumn get result => text()();
  TextColumn get ruleVersion => text()();
  DateTimeColumn get evaluatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {snapshotId, constraintId},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (result IN ('safe', 'conflict', 'unknown', 'not_evaluated'))",
  ];
}

/// Typed evidence rows replace the proposal's serialized evidence ID list.
class NutritionSnapshotConstraintResultEvidence extends Table {
  TextColumn get id => text()();
  TextColumn get resultId =>
      text().references(NutritionSnapshotConstraintResults, #id)();
  TextColumn get foodId => text().nullable().references(NutritionFoods, #id)();
  TextColumn get snapshotItemId =>
      text().nullable().references(NutritionSnapshotItems, #id)();
  TextColumn get evidenceKind => text()();
  TextColumn get status => text()();
  TextColumn get source => text()();
  TextColumn get version => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK ((food_id IS NOT NULL) OR (snapshot_item_id IS NOT NULL))',
    "CHECK (evidence_kind IN ('food', 'ingredient', 'cross_contact', 'user_override'))",
    "CHECK ((evidence_kind = 'food' AND food_id IS NOT NULL) OR (evidence_kind <> 'food' AND snapshot_item_id IS NOT NULL))",
    "CHECK (status IN ('present', 'absent', 'unknown', 'cross_contact'))",
    'CHECK (length(trim(source)) > 0)',
    'CHECK (length(trim(version)) > 0)',
  ];
}
