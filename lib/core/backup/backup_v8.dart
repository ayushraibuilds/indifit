import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import 'backup_schema.dart';

/// The schema-v17 nutrition graph is deliberately kept out of the v7 DTO.
/// This makes the old import path a bounded compatibility adapter instead of
/// spreading version checks through every legacy model.
class BackupV8ValidationException extends FormatException {
  final String code;

  BackupV8ValidationException(this.code, String message) : super(message);
}

class BackupV8Data {
  static const int currentVersion = 8;
  static const int nutritionGraphVersion = 1;
  static const String manifestVersion = 'food-identity-manifest-v1';
  static const String nutrientRegistryVersion = 'nutrient-registry-v1';

  final int version;
  final String timestamp;
  final int schemaVersion;
  final BackupData legacy;
  final NutritionBackupGraph nutrition;

  const BackupV8Data({
    required this.version,
    required this.timestamp,
    required this.schemaVersion,
    required this.legacy,
    required this.nutrition,
  });

  static Future<BackupV8Data> createFromDatabase(
    AppDatabase db, [
    SharedPreferences? prefs,
  ]) async {
    final legacy = await BackupData.createFromDatabase(db, prefs);
    final graph = db.schemaVersion >= 17
        ? await NutritionBackupGraph.capture(db)
        : NutritionBackupGraph.empty();
    return BackupV8Data(
      version: currentVersion,
      timestamp: legacy.timestamp,
      schemaVersion: db.schemaVersion,
      legacy: legacy,
      nutrition: graph,
    );
  }

  /// Decodes v8 and the supported legacy import envelope. Legacy payloads are
  /// returned without nutrition rows; they never fabricate schema-v17 data.
  static BackupV8Data fromJson(Map<String, dynamic> json) {
    final raw = json['version'];
    if (raw is! int) {
      throw BackupV8ValidationException(
        'missing_version',
        'Backup-v8 payload requires a numeric version.',
      );
    }
    if (raw > currentVersion) {
      throw BackupV8ValidationException(
        'unsupported_newer_version',
        'Unsupported backup format version $raw (latest supported is $currentVersion).',
      );
    }
    if (raw < 5) {
      throw BackupV8ValidationException(
        'unsupported_legacy_version',
        'Backup-v8 compatibility accepts versions 5, 6, and 7 only.',
      );
    }

    if (raw < currentVersion) {
      final legacy = BackupData.fromJson(json);
      return BackupV8Data(
        version: raw,
        timestamp: legacy.timestamp,
        schemaVersion: legacy.schemaVersion,
        legacy: legacy,
        nutrition: NutritionBackupGraph.empty(),
      );
    }

    final legacyJson = Map<String, dynamic>.from(json)
      ..['version'] = BackupData.currentVersion;
    legacyJson.remove('nutrition_graph');
    final legacy = BackupData.fromJson(legacyJson);
    final graph = NutritionBackupGraph.fromJson(json['nutrition_graph']);
    final schemaVersion = (json['schema_version'] as num?)?.toInt() ?? 17;
    if (schemaVersion < 17) {
      throw BackupV8ValidationException(
        'schema_version',
        'Backup-v8 nutrition graph requires schema v17 or newer.',
      );
    }
    return BackupV8Data(
      version: currentVersion,
      timestamp: json['timestamp'] as String? ?? legacy.timestamp,
      schemaVersion: schemaVersion,
      legacy: legacy,
      nutrition: graph,
    );
  }

  Map<String, dynamic> toJson() {
    final result = Map<String, dynamic>.from(legacy.toJson())
      ..['version'] = version
      ..['timestamp'] = timestamp
      ..['schema_version'] = schemaVersion;
    if (version >= currentVersion) {
      result['nutrition_graph'] = nutrition.toJson();
    }
    return result;
  }

  Future<void> restoreToDatabase(
    AppDatabase db, [
    SharedPreferences? prefs,
  ]) async {
    if (version < currentVersion) {
      await legacy.restoreToDatabase(db, prefs);
      return;
    }
    await _validateTarget(db);
    await legacy.restoreToDatabaseWithAdditionalMutation(
      db,
      prefs: prefs,
      additionalMutation: (target) => nutrition.restoreInto(target),
    );
  }

  Future<void> restoreToDatabaseWithFailureInjector(
    AppDatabase db, {
    SharedPreferences? prefs,
    required BackupRestoreFailureInjector failureInjector,
  }) async {
    if (version < currentVersion) {
      await legacy.restoreToDatabaseWithFailureInjector(
        db,
        prefs: prefs,
        failureInjector: failureInjector,
      );
      return;
    }
    await _validateTarget(db);
    await legacy.restoreToDatabaseWithFailureInjector(
      db,
      prefs: prefs,
      failureInjector: failureInjector,
      additionalMutation: (target) => nutrition.restoreInto(target),
    );
  }

  Future<void> _validateTarget(AppDatabase db) async {
    if (db.schemaVersion < 17) {
      throw BackupV8ValidationException(
        'target_schema_version',
        'Backup-v8 restore requires a schema-v17 database.',
      );
    }
    await nutrition.validateAgainstTarget(db);
  }
}

class NutritionBackupGraph {
  static const _ownedFoodKinds = {'userCreated', 'imported', 'aiEstimate'};
  static const _ownedFoodSources = {
    'user',
    'import',
    'provider',
    'ai',
    'user_entered',
    'imported_provider',
  };
  static const _userFactSources = {
    'user_entered',
    'imported_provider',
    'ai_estimate',
  };

  final int graphVersion;
  final String manifestVersion;
  final String nutrientRegistryVersion;
  final Map<String, List<Map<String, dynamic>>> tables;

  const NutritionBackupGraph({
    required this.graphVersion,
    required this.manifestVersion,
    required this.nutrientRegistryVersion,
    required this.tables,
  });

  factory NutritionBackupGraph.empty() => const NutritionBackupGraph(
    graphVersion: NutritionBackupGraphVersion.value,
    manifestVersion: BackupV8Data.manifestVersion,
    nutrientRegistryVersion: BackupV8Data.nutrientRegistryVersion,
    tables: <String, List<Map<String, dynamic>>>{},
  );

  static Future<NutritionBackupGraph> capture(AppDatabase db) async {
    final allFoods = await _readRows(db, _specs['nutrition_foods']!);
    final ownedFoodIds = allFoods
        .where(
          (row) =>
              _ownedFoodKinds.contains(row['kind']) ||
              _ownedFoodSources.contains(row['source_type']),
        )
        .map((row) => row['id'] as String)
        .toSet();

    final selected = <String, List<Map<String, dynamic>>>{};
    for (final entry in _specs.entries) {
      final spec = entry.value;
      if (spec.registryOnly) continue;
      final rows = entry.key == 'nutrition_foods'
          ? allFoods.where((row) => ownedFoodIds.contains(row['id'])).toList()
          : await _readRows(db, spec);
      final filtered = rows.where((row) {
        if (spec.filter == null) return true;
        return spec.filter!(row, ownedFoodIds);
      }).toList();
      if (filtered.isNotEmpty) selected[entry.key] = filtered;
    }
    return NutritionBackupGraph(
      graphVersion: NutritionBackupDataVersion.value,
      manifestVersion: BackupV8Data.manifestVersion,
      nutrientRegistryVersion: BackupV8Data.nutrientRegistryVersion,
      tables: _sortedTables(selected),
    );
  }

  factory NutritionBackupGraph.fromJson(Object? raw) {
    if (raw is! Map) {
      throw BackupV8ValidationException(
        'nutrition_graph_shape',
        'Backup-v8 nutrition_graph must be an object.',
      );
    }
    final map = Map<String, dynamic>.from(raw);
    final graphVersion = map['graph_version'];
    final manifestVersion = map['manifest_version'];
    final nutrientRegistryVersion = map['nutrient_registry_version'];
    if (graphVersion != NutritionBackupDataVersion.value ||
        manifestVersion != BackupV8Data.manifestVersion ||
        nutrientRegistryVersion != BackupV8Data.nutrientRegistryVersion) {
      throw BackupV8ValidationException(
        'unsupported_contract_version',
        'Backup-v8 graph, identity-manifest, or nutrient-registry version is unsupported.',
      );
    }
    final rawTables = map['tables'];
    if (rawTables is! Map) {
      throw BackupV8ValidationException(
        'nutrition_tables_shape',
        'Backup-v8 nutrition_graph.tables must be an object.',
      );
    }
    final parsed = <String, List<Map<String, dynamic>>>{};
    for (final entry in rawTables.entries) {
      if (!_specs.containsKey(entry.key)) {
        throw BackupV8ValidationException(
          'unknown_nutrition_table',
          'Backup-v8 contains unsupported nutrition table ${entry.key}.',
        );
      }
      if (entry.value is! List) {
        throw BackupV8ValidationException(
          'nutrition_table_shape',
          'Backup-v8 table ${entry.key} must be a list.',
        );
      }
      parsed[entry.key as String] = [
        for (final value in entry.value as List)
          _copyRow(value, entry.key as String),
      ];
    }
    final graph = NutritionBackupGraph(
      graphVersion: graphVersion as int,
      manifestVersion: manifestVersion as String,
      nutrientRegistryVersion: nutrientRegistryVersion as String,
      tables: _sortedTables(parsed),
    );
    graph.validateStructure();
    return graph;
  }

  Map<String, dynamic> toJson() => {
    'graph_version': graphVersion,
    'manifest_version': manifestVersion,
    'nutrient_registry_version': nutrientRegistryVersion,
    'tables': {
      for (final entry in _sortedTables(tables).entries)
        entry.key: entry.value.map(_jsonRow).toList(growable: false),
    },
  };

  void validateStructure() {
    for (final entry in tables.entries) {
      final spec = _specs[entry.key]!;
      if (spec.registryOnly) {
        throw BackupV8ValidationException(
          'registry_rows_not_exportable',
          'Backup-v8 must reference registry table ${entry.key} by version, not export its seed rows.',
        );
      }
      final ids = <String>{};
      for (final row in entry.value) {
        for (final column in spec.columns) {
          if (!row.containsKey(column)) {
            throw BackupV8ValidationException(
              'malformed_row',
              'Backup-v8 ${entry.key} row is missing $column.',
            );
          }
        }
        if (spec.hasId) {
          final id = row['id'];
          if (id is! String || id.trim().isEmpty || !ids.add(id)) {
            throw BackupV8ValidationException(
              'duplicate_portable_id',
              'Backup-v8 ${entry.key} contains a duplicate or invalid portable ID.',
            );
          }
        }
        _validateRow(entry.key, row);
      }
    }
    _validateUniqueRows();
    _topologicallySorted([..._rows('nutrition_foods')], 'variant_of_food_id');
    _topologicallySorted([..._rows('nutrition_estimates')], 'supersedes_id');
    _validateRelationships();
  }

  Future<void> validateAgainstTarget(AppDatabase db) async {
    validateStructure();
    final targetFoods = (await db.select(db.nutritionFoods).get())
        .map((row) => row.id)
        .toSet();
    final targetPreparations =
        (await db.select(db.nutritionFoodPreparations).get())
            .map((row) => row.id)
            .toSet();
    final targetPreparationOwners = {
      for (final row in await db.select(db.nutritionFoodPreparations).get())
        row.id: row.foodId,
    };
    final targetNutrients =
        (await db.select(db.nutritionNutrientDefinitions).get())
            .map((row) => row.id)
            .toSet();
    final targetConstraints =
        (await db.select(db.nutritionConstraintDefinitions).get())
            .map((row) => row.id)
            .toSet();

    final exported = <String, Set<String>>{
      for (final entry in tables.entries)
        entry.key: {
          for (final row in entry.value)
            if (row['id'] is String) row['id'] as String,
        },
    };
    Set<String> known(String key, Set<String> target) => {
      ...target,
      ...?exported[key],
    };
    final foods = known('nutrition_foods', targetFoods);
    final preparations = known(
      'nutrition_food_preparations',
      targetPreparations,
    );
    final preparationOwners = <String, String>{
      ...targetPreparationOwners,
      for (final row in _rows('nutrition_food_preparations'))
        row['id'] as String: row['food_id'] as String,
    };
    final nutrients = targetNutrients;
    final measures = known('nutrition_household_measures', const {});
    final recipes = exported['nutrition_recipes'] ?? const <String>{};
    final versions = exported['nutrition_recipe_versions'] ?? const <String>{};
    final constraints = targetConstraints;
    final estimates = exported['nutrition_estimates'] ?? const <String>{};

    for (final row in _rows('nutrition_food_aliases')) {
      _requireRef(foods, row['food_id'], 'food alias food_id');
    }
    for (final row in _rows('nutrition_food_preparations')) {
      _requireRef(foods, row['food_id'], 'preparation food_id');
    }
    for (final row in _rows('nutrition_foods')) {
      if (row['variant_of_food_id'] != null) {
        _requireRef(
          foods,
          row['variant_of_food_id'],
          'food variant_of_food_id',
        );
      }
    }
    for (final row in _rows('nutrition_food_nutrient_facts')) {
      _requireRef(foods, row['food_id'], 'nutrient fact food_id');
      _requireRef(nutrients, row['nutrient_id'], 'nutrient fact nutrient_id');
      if (row['preparation_id'] != null) {
        _requireRef(preparations, row['preparation_id'], 'fact preparation_id');
      }
    }
    for (final row in _rows('nutrition_quantity_conversions')) {
      _requireRef(foods, row['food_id'], 'conversion food_id');
      if (row['preparation_id'] != null) {
        _requireRef(
          preparations,
          row['preparation_id'],
          'conversion preparation_id',
        );
        if (preparationOwners[row['preparation_id']] != row['food_id']) {
          throw BackupV8ValidationException(
            'conversion_preparation_mismatch',
            'Backup-v8 conversion preparation does not belong to its source food.',
          );
        }
      }
      _validateTransformationTarget(
        row,
        foods: foods,
        preparations: preparations,
        preparationOwners: preparationOwners,
      );
    }
    for (final row in _rows('nutrition_vessel_calibrations')) {
      _requireRef(measures, row['measure_id'], 'vessel measure_id');
      if (row['food_id'] != null) {
        _requireRef(foods, row['food_id'], 'vessel food_id');
      }
      if (row['preparation_id'] != null) {
        _requireRef(
          preparations,
          row['preparation_id'],
          'vessel preparation_id',
        );
      }
    }
    for (final row in _rows('nutrition_recipe_versions')) {
      _requireRef(recipes, row['recipe_id'], 'recipe version recipe_id');
    }
    for (final row in _rows('nutrition_recipes')) {
      if (row['current_version_id'] != null) {
        _requireRef(
          versions,
          row['current_version_id'],
          'recipe current_version_id',
        );
      }
    }
    for (final row in _rows('nutrition_recipe_ingredients')) {
      _requireRef(versions, row['recipe_version_id'], 'ingredient version_id');
      _requireRef(foods, row['food_id'], 'ingredient food_id');
      if (row['preparation_id'] != null) {
        _requireRef(
          preparations,
          row['preparation_id'],
          'ingredient preparation_id',
        );
      }
      if (row['measure_id'] != null) {
        _requireRef(measures, row['measure_id'], 'ingredient measure_id');
      }
    }
    for (final row in _rows('nutrition_estimate_nutrients')) {
      _requireRef(nutrients, row['nutrient_id'], 'estimate nutrient_id');
    }
    for (final row in _rows('nutrition_estimates')) {
      if (row['supersedes_id'] != null) {
        _requireRef(estimates, row['supersedes_id'], 'estimate supersedes_id');
      }
    }
    for (final row in _rows('nutrition_thali_items')) {
      if (row['food_id'] != null) {
        _requireRef(foods, row['food_id'], 'thali food_id');
      }
      if (row['recipe_version_id'] != null) {
        _requireRef(
          versions,
          row['recipe_version_id'],
          'thali recipe_version_id',
        );
      }
      if (row['measure_id'] != null) {
        _requireRef(measures, row['measure_id'], 'thali measure_id');
      }
    }
    for (final row in _rows('nutrition_consumption_snapshots')) {
      if (row['recipe_version_id'] != null) {
        _requireRef(
          versions,
          row['recipe_version_id'],
          'snapshot recipe_version_id',
        );
      }
      if (row['thali_id'] != null) {
        _requireRef(
          _ids('nutrition_thalis'),
          row['thali_id'],
          'snapshot thali_id',
        );
      }
    }
    for (final row in _rows('nutrition_snapshot_items')) {
      if (row['food_id'] != null) {
        _requireRef(foods, row['food_id'], 'snapshot item food_id');
      }
      if (row['recipe_version_id'] != null) {
        _requireRef(
          versions,
          row['recipe_version_id'],
          'snapshot item recipe_version_id',
        );
      }
      if (row['preparation_id'] != null) {
        _requireRef(
          preparations,
          row['preparation_id'],
          'snapshot item preparation_id',
        );
      }
    }
    for (final row in _rows('nutrition_snapshot_nutrients')) {
      _requireRef(nutrients, row['nutrient_id'], 'snapshot nutrient_id');
    }
    for (final row in _rows('nutrition_food_constraint_evidence')) {
      _requireRef(foods, row['food_id'], 'food constraint evidence food_id');
    }
    for (final row in _rows('nutrition_user_constraints')) {
      _requireRef(
        constraints,
        row['definition_id'],
        'user constraint definition_id',
      );
    }
    for (final row in _rows('nutrition_snapshot_constraint_result_evidence')) {
      if (row['food_id'] != null) {
        _requireRef(foods, row['food_id'], 'constraint evidence food_id');
      }
    }
    _validateRecipeVersionGraph();
  }

  void _validateRecipeVersionGraph() {
    final recipes = {
      for (final row in _rows('nutrition_recipes')) row['id'] as String: row,
    };
    final versions = {
      for (final row in _rows('nutrition_recipe_versions'))
        row['id'] as String: row,
    };

    for (final row in versions.values) {
      final versionNumber = row['version_number'];
      if (versionNumber is! int || versionNumber < 1) {
        throw BackupV8ValidationException(
          'invalid_recipe_version_number',
          'Backup-v8 recipe version numbers must be positive integers.',
        );
      }
      final recipeId = row['recipe_id'];
      if (recipeId is! String || !recipes.containsKey(recipeId)) {
        throw BackupV8ValidationException(
          'missing_reference',
          'Backup-v8 recipe version references a missing recipe.',
        );
      }
      final rawSource = row['source'];
      // Older v8 payloads store the legacy provenance value directly (for
      // example, `user_entered`). Only the structured T07 envelope carries
      // recipe-graph ancestry that this validator can inspect.
      if (rawSource is String && !rawSource.trimLeft().startsWith('{')) {
        continue;
      }
      late final Map<String, dynamic> source;
      try {
        if (rawSource is! String) {
          throw const FormatException('Recipe source is not text.');
        }
        final decoded = jsonDecode(rawSource);
        if (decoded is! Map) {
          throw const FormatException('Recipe source is not an object.');
        }
        source = Map<String, dynamic>.from(decoded);
      } on Object catch (error) {
        throw BackupV8ValidationException(
          'malformed_recipe_source',
          'Backup-v8 recipe source is malformed: $error',
        );
      }
      if (source['contract_version'] != 1 ||
          source['kind'] is! String ||
          !{
            'user_authored',
            'duplicated',
            'substituted',
            'imported',
            'unknown',
          }.contains(source['kind'])) {
        throw BackupV8ValidationException(
          'unsupported_recipe_source',
          'Backup-v8 recipe source uses an unsupported contract or kind.',
        );
      }
      for (final field in const [
        'parent_version_id',
        'copied_from_version_id',
        'external_reference',
        'serving_definition_id',
        'serving_definition_revision',
        'serving_definition_source',
        'note',
      ]) {
        final value = source[field];
        if (value != null && value is! String) {
          throw BackupV8ValidationException(
            'malformed_recipe_source',
            'Backup-v8 recipe source field $field is malformed.',
          );
        }
      }
      final parentId = source['parent_version_id'] as String?;
      if (parentId != null) {
        final parent = versions[parentId];
        final parentVersionNumber = parent?['version_number'];
        if (parent == null ||
            parent['recipe_id'] != recipeId ||
            parentVersionNumber is! int ||
            parentVersionNumber >= versionNumber) {
          throw BackupV8ValidationException(
            'invalid_recipe_ancestry',
            'Backup-v8 recipe version ancestry must point to an earlier version of the same recipe.',
          );
        }
      }
      final copiedFromId = source['copied_from_version_id'] as String?;
      if (copiedFromId != null && !versions.containsKey(copiedFromId)) {
        throw BackupV8ValidationException(
          'missing_reference',
          'Backup-v8 copied recipe provenance references a missing version.',
        );
      }
    }

    for (final row in recipes.values) {
      final currentId = row['current_version_id'];
      if (currentId == null) continue;
      final current = versions[currentId];
      if (current == null ||
          current['recipe_id'] != row['id'] ||
          current['status'] != 'published') {
        throw BackupV8ValidationException(
          'invalid_current_version',
          'Backup-v8 recipe current version must be a published version owned by the recipe.',
        );
      }
    }
  }

  /// Quantity-conversion rows keep the target preparation in their typed
  /// provenance envelope because v17 stores the source food/preparation as
  /// relational columns. Validate that envelope against the target graph
  /// before restore so a malformed target cannot bypass foreign-key checks.
  void _validateTransformationTarget(
    Map<String, dynamic> row, {
    required Set<String> foods,
    required Set<String> preparations,
    required Map<String, String> preparationOwners,
  }) {
    final rawSource = row['source'];
    late final Map<String, dynamic> metadata;
    try {
      if (rawSource is! String) {
        throw const FormatException('Transformation provenance is not text.');
      }
      final decoded = jsonDecode(rawSource);
      if (decoded is! Map) {
        throw const FormatException(
          'Transformation provenance is not an object.',
        );
      }
      metadata = Map<String, dynamic>.from(decoded);
    } on Object catch (error) {
      throw BackupV8ValidationException(
        'malformed_conversion_provenance',
        'Backup-v8 conversion provenance is malformed: $error',
      );
    }
    if (metadata['contract_version'] != 1) {
      throw BackupV8ValidationException(
        'unsupported_conversion_provenance',
        'Backup-v8 conversion provenance uses an unsupported contract.',
      );
    }
    final sourceFoodId = metadata['source_food_id'];
    final sourcePreparationId = metadata['source_preparation_id'];
    final targetFoodId = metadata['target_food_id'];
    final targetPreparationId = metadata['target_preparation_id'];
    if (sourceFoodId != row['food_id'] ||
        sourcePreparationId != row['preparation_id']) {
      throw BackupV8ValidationException(
        'conversion_source_mismatch',
        'Backup-v8 conversion provenance does not match its relational source.',
      );
    }
    if (targetFoodId is! String || targetFoodId.trim().isEmpty) {
      throw BackupV8ValidationException(
        'missing_conversion_target',
        'Backup-v8 conversion provenance requires a target food identity.',
      );
    }
    _requireRef(foods, targetFoodId, 'conversion target food_id');
    if (targetPreparationId != null) {
      if (targetPreparationId is! String ||
          targetPreparationId.trim().isEmpty) {
        throw BackupV8ValidationException(
          'invalid_conversion_target_preparation',
          'Backup-v8 conversion target preparation identity is malformed.',
        );
      }
      _requireRef(
        preparations,
        targetPreparationId,
        'conversion target preparation_id',
      );
      if (preparationOwners[targetPreparationId] != targetFoodId) {
        throw BackupV8ValidationException(
          'conversion_target_preparation_mismatch',
          'Backup-v8 conversion target preparation does not belong to its target food.',
        );
      }
    }
  }

  Future<void> restoreInto(AppDatabase db) async {
    validateStructure();
    await _deleteOwnedRows(db);
    for (final table in _restoreOrder) {
      for (final row in _restoreRows(table)) {
        final spec = _specs[table]!;
        await db.customStatement(
          'INSERT INTO $table (${spec.columns.join(', ')}) VALUES (${List.filled(spec.columns.length, '?').join(', ')})',
          [
            for (final column in spec.columns)
              _databaseValue(
                column,
                table == 'nutrition_recipes' && column == 'current_version_id'
                    ? null
                    : row[column],
              ),
          ],
        );
      }
    }
    for (final row in _rows('nutrition_recipes')) {
      final currentVersionId = row['current_version_id'];
      if (currentVersionId != null) {
        await db.customStatement(
          'UPDATE nutrition_recipes SET current_version_id = ? WHERE id = ?',
          [currentVersionId, row['id']],
        );
      }
    }
    final foreignKeys = await db.customSelect('PRAGMA foreign_key_check').get();
    if (foreignKeys.isNotEmpty) {
      throw BackupV8ValidationException(
        'foreign_key_integrity',
        'Backup-v8 restore produced a foreign-key violation.',
      );
    }
  }

  List<Map<String, dynamic>> _rows(String table) => tables[table] ?? const [];

  Set<String> _ids(String table) => {
    for (final row in _rows(table)) row['id'] as String,
  };

  List<Map<String, dynamic>> _restoreRows(String table) {
    final rows = [..._rows(table)];
    if (table == 'nutrition_foods') {
      return _topologicallySorted(rows, 'variant_of_food_id');
    }
    if (table == 'nutrition_estimates') {
      return _topologicallySorted(rows, 'supersedes_id');
    }
    return rows;
  }

  static List<Map<String, dynamic>> _topologicallySorted(
    List<Map<String, dynamic>> rows,
    String parentColumn,
  ) {
    rows.sort((a, b) => _rowKey(a).compareTo(_rowKey(b)));
    final byId = <String, Map<String, dynamic>>{
      for (final row in rows) row['id'] as String: row,
    };
    final visiting = <String>{};
    final visited = <String>{};
    final ordered = <Map<String, dynamic>>[];

    void visit(Map<String, dynamic> row) {
      final id = row['id'] as String;
      if (visited.contains(id)) return;
      if (!visiting.add(id)) {
        throw BackupV8ValidationException(
          'cyclic_relationship',
          'Backup-v8 $parentColumn contains a cycle.',
        );
      }
      final parentId = row[parentColumn];
      final parent = parentId is String ? byId[parentId] : null;
      if (parent != null) visit(parent);
      visiting.remove(id);
      visited.add(id);
      ordered.add(row);
    }

    for (final row in rows) {
      visit(row);
    }
    return ordered;
  }

  void _validateUniqueRows() {
    for (final entry in _uniqueColumns.entries) {
      for (final columns in entry.value) {
        final seen = <List<Object?>>[];
        for (final row in _rows(entry.key)) {
          final values = [for (final column in columns) row[column]];
          // SQLite permits multiple NULLs in a UNIQUE constraint. Match that
          // behavior while rejecting duplicate fully specified relationships.
          if (values.any((value) => value == null)) continue;
          if (seen.any(_sameValues(values))) {
            throw BackupV8ValidationException(
              'duplicate_unique_relationship',
              'Backup-v8 ${entry.key} contains a duplicate unique relationship.',
            );
          }
          seen.add(values);
        }
      }
    }
  }

  static bool Function(List<Object?>) _sameValues(List<Object?> expected) =>
      (candidate) {
        if (candidate.length != expected.length) return false;
        for (var index = 0; index < expected.length; index++) {
          if (candidate[index] != expected[index]) return false;
        }
        return true;
      };

  void _validateRelationships() {
    final foods = _ids('nutrition_foods');
    final recipes = _ids('nutrition_recipes');
    final versions = _ids('nutrition_recipe_versions');
    final thalis = _ids('nutrition_thalis');
    final snapshots = _ids('nutrition_consumption_snapshots');
    final items = _ids('nutrition_snapshot_items');
    final estimates = _ids('nutrition_estimates');
    final results = _ids('nutrition_snapshot_constraint_results');
    final constraints = _ids('nutrition_user_constraints');
    for (final row in _rows('nutrition_food_preparations')) {
      if (row['food_id'] is String && foods.contains(row['food_id'])) continue;
      // A preparation may belong to a bundled canonical food resolved from the
      // manifest at restore time; target validation handles that reference.
    }
    for (final row in _rows('nutrition_foods')) {
      final parentId = row['variant_of_food_id'];
      if (parentId is String && parentId == row['id']) {
        throw BackupV8ValidationException(
          'cyclic_relationship',
          'Backup-v8 food variants cannot reference themselves.',
        );
      }
    }
    for (final row in _rows('nutrition_recipes')) {
      final currentVersionId = row['current_version_id'];
      if (currentVersionId != null) {
        _requireRef(versions, currentVersionId, 'recipe current_version_id');
      }
    }
    for (final row in _rows('nutrition_recipe_versions')) {
      _requireRef(
        recipes,
        row['recipe_id'],
        'recipe version recipe_id',
        allowTarget: true,
      );
    }
    for (final row in _rows('nutrition_recipe_ingredients')) {
      _requireRef(
        versions,
        row['recipe_version_id'],
        'ingredient recipe_version_id',
        allowTarget: true,
      );
    }
    for (final row in _rows('nutrition_thali_items')) {
      _oneOf(row['food_id'], row['recipe_version_id'], 'thali item reference');
      _requireRef(thalis, row['thali_id'], 'thali item thali_id');
    }
    for (final row in _rows('nutrition_consumption_snapshots')) {
      _atMostOne(
        row['recipe_version_id'],
        row['thali_id'],
        'snapshot owner reference',
      );
    }
    for (final row in _rows('nutrition_snapshot_items')) {
      _oneOf(
        row['food_id'],
        row['recipe_version_id'],
        'snapshot item reference',
      );
      _requireRef(snapshots, row['snapshot_id'], 'snapshot item snapshot_id');
    }
    for (final row in _rows('nutrition_snapshot_nutrients')) {
      _requireRef(
        snapshots,
        row['snapshot_id'],
        'snapshot nutrient snapshot_id',
      );
      if (row['item_id'] != null) {
        _requireRef(items, row['item_id'], 'snapshot nutrient item_id');
      }
    }
    for (final row in _rows('nutrition_estimate_nutrients')) {
      _requireRef(
        estimates,
        row['estimate_id'],
        'estimate nutrient estimate_id',
      );
    }
    final estimateById = {
      for (final row in _rows('nutrition_estimates')) row['id'] as String: row,
    };
    for (final id in estimateById.keys) {
      final seen = <String>{};
      String? cursor = id;
      while (cursor != null) {
        if (!seen.add(cursor)) {
          throw BackupV8ValidationException(
            'cyclic_lineage',
            'Backup-v8 estimate correction lineage contains a cycle.',
          );
        }
        cursor = estimateById[cursor]?['supersedes_id'] as String?;
      }
    }
    for (final row in _rows('nutrition_snapshot_constraint_results')) {
      _requireRef(
        snapshots,
        row['snapshot_id'],
        'constraint result snapshot_id',
      );
      _requireRef(
        constraints,
        row['constraint_id'],
        'constraint result constraint_id',
      );
    }
    for (final row in _rows('nutrition_snapshot_constraint_result_evidence')) {
      _requireRef(results, row['result_id'], 'constraint evidence result_id');
      _oneOf(
        row['food_id'],
        row['snapshot_item_id'],
        'constraint evidence target',
      );
      if (row['snapshot_item_id'] != null) {
        _requireRef(
          items,
          row['snapshot_item_id'],
          'constraint evidence snapshot_item_id',
        );
      }
    }
  }

  static void _validateRow(String table, Map<String, dynamic> row) {
    final amountColumns = const [
      'amount',
      'lower',
      'upper',
      'factor',
      'nominal_value',
      'volume_ml',
      'quantity_value',
      'basis_quantity',
    ];
    for (final column in amountColumns) {
      final value = row[column];
      if (value != null && (value is! num || !value.isFinite || value < 0)) {
        throw BackupV8ValidationException(
          'invalid_numeric',
          'Backup-v8 $table.$column is invalid.',
        );
      }
    }
    final lower = row['lower'];
    final upper = row['upper'];
    if (lower != null && upper != null && (lower as num) > (upper as num)) {
      throw BackupV8ValidationException(
        'invalid_range',
        'Backup-v8 $table has lower greater than upper.',
      );
    }
    final dimensions = <String, Set<String>>{
      'mass': {'milligram', 'gram', 'kilogram'},
      'volume': {'millilitre', 'litre'},
      'count': {'piece'},
      'serving': {'serving'},
      'household_reference': {'household_reference'},
    };
    if (row['quantity_dimension'] != null || row['quantity_unit'] != null) {
      final dimension = row['quantity_dimension'];
      final unit = row['quantity_unit'];
      if (dimension is! String ||
          unit is! String ||
          !dimensions.containsKey(dimension) ||
          !dimensions[dimension]!.contains(unit)) {
        throw BackupV8ValidationException(
          'invalid_quantity',
          'Backup-v8 $table has an invalid quantity dimension/unit pair.',
        );
      }
      if (row['quantity_value'] is num && (row['quantity_value'] as num) <= 0) {
        throw BackupV8ValidationException(
          'invalid_quantity',
          'Backup-v8 $table quantity values must be positive persisted inputs.',
        );
      }
    }
    for (final column in const [
      'factor',
      'nominal_value',
      'volume_ml',
      'basis_quantity',
    ]) {
      if (row[column] is num && (row[column] as num) <= 0) {
        throw BackupV8ValidationException(
          'invalid_positive_value',
          'Backup-v8 $table.$column must be positive.',
        );
      }
    }
    if (row['confidence'] is num &&
        ((row['confidence'] as num) < 0 || (row['confidence'] as num) > 1)) {
      throw BackupV8ValidationException(
        'invalid_confidence',
        'Backup-v8 $table confidence must be between 0 and 1.',
      );
    }
    const allowedStatuses = {
      'known',
      'known_zero',
      'missing',
      'not_applicable',
      'estimated',
    };
    if (row['status'] != null &&
        table.contains('nutrient') &&
        !allowedStatuses.contains(row['status'])) {
      throw BackupV8ValidationException(
        'invalid_nutrient_status',
        'Backup-v8 $table has an unsupported nutrient status.',
      );
    }
    if (row['status'] == 'missing' || row['status'] == 'not_applicable') {
      if (row['amount'] != null ||
          row['lower'] != null ||
          row['upper'] != null) {
        throw BackupV8ValidationException(
          'invalid_missing_fact',
          'Missing nutrient facts cannot carry numeric values.',
        );
      }
    }
    if (table == 'nutrition_snapshot_constraint_results' &&
        !{
          'confirmed_conflict',
          'possible_conflict',
          'no_known_conflict',
          'insufficient_information',
        }.contains(row['result'])) {
      throw BackupV8ValidationException(
        'invalid_constraint_result',
        'Backup-v8 contains an invalid constraint result.',
      );
    }
    _validateEnums(table, row);
  }

  static void _validateEnums(String table, Map<String, dynamic> row) {
    const enums = <String, Map<String, Set<String>>>{
      'nutrition_foods': {
        'kind': {
          'canonical',
          'preparationVariant',
          'regionalVariant',
          'restaurantEstimate',
          'homemadeEstimate',
          'branded',
          'servingPresentationVariant',
          'userCreated',
          'imported',
          'aiEstimate',
          'legacy',
          'unknown',
        },
        'lifecycle': {'active', 'deprecated', 'unresolved'},
      },
      'nutrition_food_preparations': {
        'state': {'unspecified', 'raw', 'cooked'},
      },
      'nutrition_food_nutrient_facts': {
        'status': {
          'known',
          'known_zero',
          'missing',
          'not_applicable',
          'estimated',
        },
        'basis': {
          'per_100_grams',
          'per_100_millilitres',
          'per_serving',
          'absolute',
        },
        'source': {
          'reviewed_catalogue',
          'manufacturer_label',
          'user_entered',
          'imported_provider',
          'recipe_calculation',
          'ai_estimate',
          'heuristic',
          'legacy',
          'unknown',
        },
      },
      'nutrition_quantity_conversions': {
        'owner_scope': {'catalogue', 'user'},
      },
      'nutrition_food_constraint_evidence': {
        'status': {'confirmed', 'possible', 'not_indicated', 'unknown'},
      },
      'nutrition_recipe_versions': {
        'status': {'draft', 'published', 'archived'},
      },
      'nutrition_estimates': {
        'source': {
          'reviewed_catalogue',
          'manufacturer_label',
          'user_entered',
          'imported_provider',
          'recipe_calculation',
          'ai_estimate',
          'heuristic',
          'legacy',
          'unknown',
        },
        'status': {'known', 'estimated', 'missing', 'superseded'},
      },
      'nutrition_estimate_nutrients': {
        'status': {
          'known',
          'known_zero',
          'missing',
          'not_applicable',
          'estimated',
        },
        'unit': {
          'energy_kilocalorie',
          'mass_gram',
          'mass_milligram',
          'mass_microgram',
        },
      },
      'nutrition_snapshot_nutrients': {
        'status': {
          'known',
          'known_zero',
          'missing',
          'not_applicable',
          'estimated',
        },
        'unit': {
          'energy_kilocalorie',
          'mass_gram',
          'mass_milligram',
          'mass_microgram',
        },
      },
      'nutrition_consumption_snapshots': {
        'completeness': {
          'complete',
          'partial',
          'unknown',
          'not_applicable',
          'invalid',
        },
        'estimate_status': {'none', 'estimated', 'mixed', 'unknown'},
      },
      'nutrition_user_constraints': {
        'strictness': {'avoid', 'warn', 'informational'},
      },
      'nutrition_snapshot_constraint_result_evidence': {
        'evidence_kind': {
          'food',
          'ingredient',
          'cross_contact',
          'user_override',
        },
        'status': {'confirmed', 'possible', 'not_indicated', 'unknown'},
      },
    };
    for (final entry
        in enums[table]?.entries ?? const <MapEntry<String, Set<String>>>[]) {
      final value = row[entry.key];
      if (value is! String || !entry.value.contains(value)) {
        throw BackupV8ValidationException(
          'invalid_enum',
          'Backup-v8 $table.${entry.key} has an unsupported value.',
        );
      }
    }
  }

  Future<void> _deleteOwnedRows(AppDatabase db) async {
    for (final statement in const [
      'DELETE FROM nutrition_snapshot_constraint_result_evidence',
      'DELETE FROM nutrition_snapshot_constraint_results',
      'DELETE FROM nutrition_snapshot_nutrients',
      'DELETE FROM nutrition_snapshot_items',
      'DELETE FROM nutrition_consumption_snapshots',
      'DELETE FROM nutrition_thali_items',
      'DELETE FROM nutrition_thalis',
      'DELETE FROM nutrition_estimate_nutrients',
      'DELETE FROM nutrition_estimates',
      'DELETE FROM nutrition_recipe_ingredients',
      'DELETE FROM nutrition_recipe_versions',
      'DELETE FROM nutrition_recipes',
      'DELETE FROM nutrition_user_corrections',
      'DELETE FROM nutrition_vessel_calibrations',
      'DELETE FROM nutrition_quantity_conversions WHERE owner_scope = \'user\'',
      'DELETE FROM nutrition_food_nutrient_facts WHERE source IN (\'user_entered\', \'imported_provider\', \'ai_estimate\') OR food_id IN (SELECT id FROM nutrition_foods WHERE kind IN (\'userCreated\', \'imported\', \'aiEstimate\'))',
      'DELETE FROM nutrition_food_constraint_evidence WHERE food_id IN (SELECT id FROM nutrition_foods WHERE kind IN (\'userCreated\', \'imported\', \'aiEstimate\')) OR evidence_source IN (\'user\', \'user_entered\', \'user_override\', \'imported_provider\')',
      'DELETE FROM nutrition_food_preparations WHERE food_id IN (SELECT id FROM nutrition_foods WHERE kind IN (\'userCreated\', \'imported\', \'aiEstimate\'))',
      'DELETE FROM nutrition_food_aliases WHERE food_id IN (SELECT id FROM nutrition_foods WHERE kind IN (\'userCreated\', \'imported\', \'aiEstimate\')) OR source IN (\'user\', \'user_entered\', \'imported_provider\')',
      'DELETE FROM nutrition_user_constraints',
      'DELETE FROM nutrition_foods WHERE kind IN (\'userCreated\', \'imported\', \'aiEstimate\')',
      'DELETE FROM nutrition_household_measures',
    ]) {
      await db.customStatement(statement);
    }
  }

  static Map<String, List<Map<String, dynamic>>> _sortedTables(
    Map<String, List<Map<String, dynamic>>> input,
  ) => {
    for (final table in input.keys.toList()..sort())
      table: [
        ...input[table]!..sort((a, b) => _rowKey(a).compareTo(_rowKey(b))),
      ],
  };

  static String _rowKey(Map<String, dynamic> row) => [
    row['id'],
    row['food_id'],
    row['recipe_version_id'],
    row['snapshot_id'],
    row['position'],
  ].map((value) => '$value').join('|');

  static Map<String, dynamic> _jsonRow(Map<String, dynamic> row) => {
    for (final key in row.keys.toList()..sort()) key: _jsonValue(row[key]),
  };

  static Map<String, dynamic> _copyRow(Object? raw, Object table) {
    if (raw is! Map) {
      throw BackupV8ValidationException(
        'malformed_row',
        'Backup-v8 $table contains a non-object row.',
      );
    }
    return Map<String, dynamic>.from(raw);
  }

  static dynamic _jsonValue(Object? value) {
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is Map) {
      return {
        for (final k in value.keys.toList()..sort()) '$k': _jsonValue(value[k]),
      };
    }
    if (value is Iterable) return value.map(_jsonValue).toList(growable: false);
    return value;
  }

  static dynamic _databaseValue(String column, Object? value) {
    if (value is String && _dateColumns.contains(column)) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toUtc().millisecondsSinceEpoch;
    }
    return value;
  }

  static void _requireRef(
    Set<String> known,
    Object? value,
    String owner, {
    bool allowTarget = false,
  }) {
    if (value is! String ||
        value.isEmpty ||
        (!known.contains(value) && !allowTarget)) {
      throw BackupV8ValidationException(
        'missing_reference',
        'Backup-v8 $owner references a missing portable ID.',
      );
    }
  }

  static void _oneOf(Object? first, Object? second, String owner) {
    if ((first == null) == (second == null)) {
      throw BackupV8ValidationException(
        'invalid_one_of',
        'Backup-v8 $owner must contain exactly one reference.',
      );
    }
  }

  static void _atMostOne(Object? first, Object? second, String owner) {
    if (first != null && second != null) {
      throw BackupV8ValidationException(
        'invalid_one_of',
        'Backup-v8 $owner may contain at most one reference.',
      );
    }
  }
}

class NutritionBackupGraphVersion {
  static const int value = 1;
}

class NutritionBackupDataVersion {
  static const int value = 1;
}

class _NutritionTableSpec {
  final List<String> columns;
  final String orderBy;
  final bool registryOnly;
  final bool hasId;
  final bool Function(Map<String, dynamic>, Set<String>)? filter;

  const _NutritionTableSpec({
    required this.columns,
    required this.orderBy,
    this.registryOnly = false,
    this.hasId = true,
    this.filter,
  });
}

Future<List<Map<String, dynamic>>> _readRows(
  AppDatabase db,
  _NutritionTableSpec spec,
) async {
  final table = _specs.entries.firstWhere((entry) => entry.value == spec).key;
  final rows = await db
      .customSelect(
        'SELECT ${spec.columns.join(', ')} FROM $table ORDER BY ${spec.orderBy}',
      )
      .get();
  return [
    for (final row in rows)
      {for (final column in spec.columns) column: row.data[column]},
  ];
}

const _dateColumns = {
  'created_at',
  'updated_at',
  'mapped_at',
  'effective_from',
  'effective_to',
  'evaluated_at',
};

final Map<String, _NutritionTableSpec> _specs = {
  'nutrition_foods': _NutritionTableSpec(
    columns: const [
      'id',
      'kind',
      'display_name',
      'locale',
      'source_type',
      'source_ref',
      'source_version',
      'brand',
      'region',
      'lifecycle',
      'variant_of_food_id',
      'legacy_food_item_id',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
  ),
  'nutrition_food_aliases': _NutritionTableSpec(
    columns: const [
      'id',
      'food_id',
      'alias',
      'normalized_alias',
      'locale',
      'source',
      'confidence',
      'is_active',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
    filter: (row, foods) =>
        foods.contains(row['food_id']) ||
        {'user', 'user_entered', 'imported_provider'}.contains(row['source']),
  ),
  'nutrition_food_preparations': _NutritionTableSpec(
    columns: const [
      'id',
      'food_id',
      'state',
      'method',
      'oil_context',
      'region',
      'source',
      'version',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
    filter: (row, foods) => foods.contains(row['food_id']),
  ),
  'nutrition_legacy_food_mappings': _NutritionTableSpec(
    columns: const [
      'legacy_food_item_id',
      'food_id',
      'mapping_status',
      'evidence',
      'mapped_at',
    ],
    orderBy: 'legacy_food_item_id',
    registryOnly: true,
    hasId: false,
  ),
  'nutrition_nutrient_definitions': _NutritionTableSpec(
    columns: const [
      'id',
      'key',
      'display_name',
      'unit',
      'kind',
      'sort_order',
      'version',
      'is_active',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
    registryOnly: true,
  ),
  'nutrition_food_nutrient_facts': _NutritionTableSpec(
    columns: const [
      'id',
      'food_id',
      'nutrient_id',
      'amount',
      'lower',
      'upper',
      'status',
      'source',
      'source_ref',
      'confidence',
      'fact_version',
      'basis',
      'basis_quantity',
      'basis_unit',
      'preparation_id',
      'is_current',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
    filter: (row, foods) =>
        foods.contains(row['food_id']) ||
        NutritionBackupGraph._userFactSources.contains(row['source']),
  ),
  'nutrition_quantity_conversions': _NutritionTableSpec(
    columns: const [
      'id',
      'food_id',
      'preparation_id',
      'source_unit',
      'target_unit',
      'factor',
      'lower',
      'upper',
      'method',
      'source',
      'confidence',
      'rule_version',
      'owner_scope',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
    filter: (row, _) => row['owner_scope'] == 'user',
  ),
  'nutrition_household_measures': _NutritionTableSpec(
    columns: const [
      'id',
      'key',
      'display_name',
      'dimension',
      'base_unit',
      'nominal_value',
      'lower',
      'upper',
      'locale',
      'version',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
  ),
  'nutrition_vessel_calibrations': _NutritionTableSpec(
    columns: const [
      'id',
      'user_id',
      'label',
      'measure_id',
      'volume_ml',
      'lower',
      'upper',
      'method',
      'food_id',
      'preparation_id',
      'confidence',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
  ),
  'nutrition_recipes': _NutritionTableSpec(
    columns: const [
      'id',
      'user_id',
      'name',
      'description',
      'lifecycle',
      'current_version_id',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
  ),
  'nutrition_recipe_versions': _NutritionTableSpec(
    columns: const [
      'id',
      'recipe_id',
      'version_number',
      'status',
      'yield_quantity',
      'yield_unit',
      'serving_quantity',
      'calc_rule_version',
      'source',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
  ),
  'nutrition_recipe_ingredients': _NutritionTableSpec(
    columns: const [
      'id',
      'recipe_version_id',
      'position',
      'food_id',
      'preparation_id',
      'quantity_value',
      'quantity_dimension',
      'quantity_unit',
      'measure_id',
      'lower',
      'upper',
      'notes',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
  ),
  'nutrition_user_corrections': _NutritionTableSpec(
    columns: const [
      'id',
      'user_id',
      'target_type',
      'target_id',
      'field',
      'old_value',
      'new_value',
      'reason',
      'source',
      'created_at',
    ],
    orderBy: 'id',
  ),
  'nutrition_estimates': _NutritionTableSpec(
    columns: const [
      'id',
      'user_id',
      'source',
      'provider',
      'model',
      'rule_version',
      'input_hash',
      'assumptions',
      'confidence',
      'lower',
      'upper',
      'status',
      'supersedes_id',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
  ),
  'nutrition_estimate_nutrients': _NutritionTableSpec(
    columns: const [
      'id',
      'estimate_id',
      'nutrient_id',
      'amount',
      'lower',
      'upper',
      'status',
      'unit',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
  ),
  'nutrition_thalis': _NutritionTableSpec(
    columns: const [
      'id',
      'user_id',
      'name',
      'description',
      'lifecycle',
      'current_version',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
  ),
  'nutrition_thali_items': _NutritionTableSpec(
    columns: const [
      'id',
      'thali_id',
      'position',
      'food_id',
      'recipe_version_id',
      'quantity_value',
      'quantity_dimension',
      'quantity_unit',
      'measure_id',
      'optional',
      'notes',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
  ),
  'nutrition_consumption_snapshots': _NutritionTableSpec(
    columns: const [
      'id',
      'user_id',
      'logged_at',
      'meal_category',
      'meal_group_id',
      'source_type',
      'recipe_version_id',
      'thali_id',
      'calculator_version',
      'completeness',
      'estimate_status',
      'local_date',
      'timezone_id',
      'lineage',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
  ),
  'nutrition_snapshot_items': _NutritionTableSpec(
    columns: const [
      'id',
      'snapshot_id',
      'position',
      'food_id',
      'preparation_id',
      'recipe_version_id',
      'quantity_value',
      'quantity_dimension',
      'quantity_unit',
      'quantity_context_id',
      'lower',
      'upper',
      'source_ref',
      'basis',
      'conversion_version',
      'calculation_version',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
  ),
  'nutrition_snapshot_nutrients': _NutritionTableSpec(
    columns: const [
      'id',
      'snapshot_id',
      'item_id',
      'nutrient_id',
      'amount',
      'lower',
      'upper',
      'status',
      'unit',
      'source_version',
      'basis',
      'fact_version',
      'lineage',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
  ),
  'nutrition_food_constraint_evidence': _NutritionTableSpec(
    columns: const [
      'id',
      'food_id',
      'constraint_key',
      'status',
      'evidence_source',
      'confidence',
      'notes',
      'version',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
    filter: (row, foods) =>
        foods.contains(row['food_id']) ||
        {
          'user',
          'user_entered',
          'user_override',
          'imported_provider',
        }.contains(row['evidence_source']),
  ),
  'nutrition_constraint_definitions': _NutritionTableSpec(
    columns: const [
      'id',
      'key',
      'type',
      'display_name',
      'severity_supported',
      'cross_contact_supported',
      'version',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
    registryOnly: true,
  ),
  'nutrition_user_constraints': _NutritionTableSpec(
    columns: const [
      'id',
      'user_id',
      'definition_id',
      'value',
      'strictness',
      'severity',
      'cross_contact',
      'effective_from',
      'effective_to',
      'source',
      'notes',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
  ),
  'nutrition_snapshot_constraint_results': _NutritionTableSpec(
    columns: const [
      'id',
      'snapshot_id',
      'constraint_id',
      'result',
      'rule_version',
      'evaluated_at',
      'created_at',
      'updated_at',
    ],
    orderBy: 'id',
  ),
  'nutrition_snapshot_constraint_result_evidence': _NutritionTableSpec(
    columns: const [
      'id',
      'result_id',
      'food_id',
      'snapshot_item_id',
      'evidence_kind',
      'status',
      'source',
      'version',
      'created_at',
    ],
    orderBy: 'id',
  ),
};

const _restoreOrder = [
  'nutrition_foods',
  'nutrition_food_aliases',
  'nutrition_food_preparations',
  'nutrition_household_measures',
  'nutrition_vessel_calibrations',
  'nutrition_quantity_conversions',
  'nutrition_food_nutrient_facts',
  'nutrition_recipes',
  'nutrition_recipe_versions',
  'nutrition_recipe_ingredients',
  'nutrition_user_corrections',
  'nutrition_estimates',
  'nutrition_estimate_nutrients',
  'nutrition_thalis',
  'nutrition_thali_items',
  'nutrition_consumption_snapshots',
  'nutrition_snapshot_items',
  'nutrition_snapshot_nutrients',
  'nutrition_food_constraint_evidence',
  'nutrition_user_constraints',
  'nutrition_snapshot_constraint_results',
  'nutrition_snapshot_constraint_result_evidence',
];

const _uniqueColumns = <String, List<List<String>>>{
  'nutrition_foods': [
    ['source_type', 'source_ref', 'source_version'],
    ['legacy_food_item_id'],
  ],
  'nutrition_food_aliases': [
    ['normalized_alias', 'locale'],
  ],
  'nutrition_food_preparations': [
    ['food_id', 'state', 'method', 'oil_context', 'region', 'version'],
  ],
  'nutrition_food_nutrient_facts': [
    ['food_id', 'nutrient_id', 'fact_version'],
  ],
  'nutrition_quantity_conversions': [
    ['food_id', 'preparation_id', 'source_unit', 'target_unit', 'rule_version'],
  ],
  'nutrition_household_measures': [
    ['key', 'locale', 'version'],
  ],
  'nutrition_vessel_calibrations': [
    ['user_id', 'label'],
  ],
  'nutrition_recipe_versions': [
    ['recipe_id', 'version_number'],
  ],
  'nutrition_recipe_ingredients': [
    ['recipe_version_id', 'position'],
  ],
  'nutrition_estimate_nutrients': [
    ['estimate_id', 'nutrient_id'],
  ],
  'nutrition_thali_items': [
    ['thali_id', 'position'],
  ],
  'nutrition_snapshot_items': [
    ['snapshot_id', 'position'],
  ],
  'nutrition_snapshot_nutrients': [
    ['snapshot_id', 'item_id', 'nutrient_id'],
  ],
  'nutrition_food_constraint_evidence': [
    ['food_id', 'constraint_key', 'version'],
  ],
  'nutrition_snapshot_constraint_results': [
    ['snapshot_id', 'constraint_id'],
  ],
};
