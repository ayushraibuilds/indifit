import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import '../fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import '../services/local_schedule_date_service.dart';
import 'backup_schema.dart';
import 'backup_v8.dart';

/// Validation errors for the schema-v18 / Backup-v9 adaptive-coaching graph.
class BackupV9ValidationException extends FormatException {
  final String code;

  BackupV9ValidationException(this.code, String message) : super(message);
}

/// Schema-v18's durable B04 graph is an extension of the already accepted
/// v8 graph.  The extension deliberately keeps the v7 DTO and the v8
/// nutrition graph as separate compatibility authorities.
class BackupV9Data {
  static const int currentVersion = 9;

  final int version;
  final String timestamp;
  final int schemaVersion;
  final BackupData legacy;
  final NutritionBackupGraph nutrition;
  final B04BackupGraph adaptiveCoaching;

  const BackupV9Data({
    required this.version,
    required this.timestamp,
    required this.schemaVersion,
    required this.legacy,
    required this.nutrition,
    required this.adaptiveCoaching,
  });

  B04BackupGraph get b04 => adaptiveCoaching;

  static Future<BackupV9Data> createFromDatabase(
    AppDatabase db, [
    SharedPreferences? prefs,
  ]) async {
    if (db.schemaVersion < 18) {
      throw BackupV9ValidationException(
        'source_schema_version',
        'Backup-v9 export requires a schema-v18 database.',
      );
    }
    final legacy = await BackupData.createFromDatabase(db, prefs);
    final nutrition = await NutritionBackupGraph.capture(db);
    final adaptiveCoaching = await B04BackupGraph.capture(db);
    adaptiveCoaching.validateStructure();
    return BackupV9Data(
      version: currentVersion,
      timestamp: legacy.timestamp,
      schemaVersion: db.schemaVersion,
      legacy: legacy,
      nutrition: nutrition,
      adaptiveCoaching: adaptiveCoaching,
    );
  }

  /// Decodes v9 and all v5-v8 imports.  Older payloads intentionally carry an
  /// empty B04 graph; no consent or eligibility state is inferred from them.
  static BackupV9Data fromJson(Map<String, dynamic> json) {
    final raw = json['version'];
    if (raw is! int) {
      throw BackupV9ValidationException(
        'missing_version',
        'Backup-v9 payload requires a numeric version.',
      );
    }
    if (raw > currentVersion) {
      throw BackupV9ValidationException(
        'unsupported_newer_version',
        'Unsupported backup format version $raw (latest supported is $currentVersion).',
      );
    }
    if (raw < 5) {
      throw BackupV9ValidationException(
        'unsupported_legacy_version',
        'Backup-v9 compatibility accepts versions 5 through 9 only.',
      );
    }

    if (raw < currentVersion) {
      final decoded = BackupV8Data.fromJson(json);
      return BackupV9Data(
        version: decoded.version,
        timestamp: decoded.timestamp,
        schemaVersion: decoded.schemaVersion,
        legacy: decoded.legacy,
        nutrition: decoded.nutrition,
        adaptiveCoaching: B04BackupGraph.empty(),
      );
    }

    final v8Json = Map<String, dynamic>.from(json)..['version'] = 8;
    final decoded = BackupV8Data.fromJson(v8Json);
    final schemaVersion = (json['schema_version'] as num?)?.toInt() ?? 18;
    if (schemaVersion < 18) {
      throw BackupV9ValidationException(
        'schema_version',
        'Backup-v9 adaptive-coaching graph requires schema v18 or newer.',
      );
    }
    final graph = B04BackupGraph.fromJson(json['b04_graph']);
    return BackupV9Data(
      version: currentVersion,
      timestamp: json['timestamp'] as String? ?? decoded.timestamp,
      schemaVersion: schemaVersion,
      legacy: decoded.legacy,
      nutrition: decoded.nutrition,
      adaptiveCoaching: graph,
    );
  }

  Map<String, dynamic> toJson() {
    final base = BackupV8Data(
      version: version >= currentVersion ? 8 : version,
      timestamp: timestamp,
      schemaVersion: schemaVersion,
      legacy: legacy,
      nutrition: nutrition,
    ).toJson();
    if (version >= currentVersion) {
      adaptiveCoaching.validateStructure();
      base['version'] = currentVersion;
      base['b04_graph'] = adaptiveCoaching.toJson();
    }
    return base;
  }

  Future<void> restoreToDatabase(
    AppDatabase db, [
    SharedPreferences? prefs,
  ]) async {
    if (version >= currentVersion) {
      await _validateTarget(db);
      await legacy.restoreToDatabaseWithAdditionalMutation(
        db,
        prefs: prefs,
        additionalMutation: (target) async {
          await nutrition.restoreInto(target);
          adaptiveCoaching.validateStructure();
          await adaptiveCoaching.restoreIntoExistingTransaction(target);
        },
      );
      return;
    }

    if (version >= BackupV8Data.currentVersion) {
      if (db.schemaVersion < 17) {
        throw BackupV8ValidationException(
          'target_schema_version',
          'Backup-v8 restore requires a schema-v17 database.',
        );
      }
      await nutrition.validateAgainstTarget(db);
      await legacy.restoreToDatabaseWithAdditionalMutation(
        db,
        prefs: prefs,
        additionalMutation: (target) async {
          await nutrition.restoreInto(target);
          await B04BackupGraph.empty().restoreIntoExistingTransaction(target);
        },
      );
    } else if (db.schemaVersion >= 18) {
      await legacy.restoreToDatabaseWithAdditionalMutation(
        db,
        prefs: prefs,
        additionalMutation: (target) =>
            B04BackupGraph.empty().restoreIntoExistingTransaction(target),
      );
    } else {
      await legacy.restoreToDatabase(db, prefs);
    }
  }

  Future<void> restoreToDatabaseWithFailureInjector(
    AppDatabase db, {
    SharedPreferences? prefs,
    required BackupRestoreFailureInjector failureInjector,
  }) async {
    if (version >= currentVersion) {
      await _validateTarget(db);
      await legacy.restoreToDatabaseWithFailureInjector(
        db,
        prefs: prefs,
        failureInjector: failureInjector,
        additionalMutation: (target) async {
          await nutrition.restoreInto(target);
          adaptiveCoaching.validateStructure();
          await adaptiveCoaching.restoreIntoExistingTransaction(
            target,
            failureInjector: failureInjector,
          );
        },
      );
      return;
    }

    if (version >= BackupV8Data.currentVersion) {
      if (db.schemaVersion < 17) {
        throw BackupV8ValidationException(
          'target_schema_version',
          'Backup-v8 restore requires a schema-v17 database.',
        );
      }
      await nutrition.validateAgainstTarget(db);
      await legacy.restoreToDatabaseWithFailureInjector(
        db,
        prefs: prefs,
        failureInjector: failureInjector,
        additionalMutation: (target) async {
          await nutrition.restoreInto(target);
          await B04BackupGraph.empty().restoreIntoExistingTransaction(
            target,
            failureInjector: failureInjector,
          );
        },
      );
    } else if (db.schemaVersion >= 18) {
      await legacy.restoreToDatabaseWithFailureInjector(
        db,
        prefs: prefs,
        failureInjector: failureInjector,
        additionalMutation: (target) =>
            B04BackupGraph.empty().restoreIntoExistingTransaction(
              target,
              failureInjector: failureInjector,
            ),
      );
    } else {
      await legacy.restoreToDatabaseWithFailureInjector(
        db,
        prefs: prefs,
        failureInjector: failureInjector,
      );
    }
  }

  Future<void> _validateTarget(AppDatabase db) async {
    if (db.schemaVersion < 18) {
      throw BackupV9ValidationException(
        'target_schema_version',
        'Backup-v9 restore requires a schema-v18 database.',
      );
    }
    await nutrition.validateAgainstTarget(db);
    adaptiveCoaching.validateStructure();
  }
}

/// Portable, user-owned schema-v18 rows.  The graph contains only typed
/// columns from the accepted B04 tables; prompts, raw provider responses,
/// images and health payloads cannot enter this representation.
class B04BackupGraph {
  static const int currentGraphVersion = 1;

  final int graphVersion;
  final Map<String, List<Map<String, dynamic>>> tables;

  const B04BackupGraph({required this.graphVersion, required this.tables});

  factory B04BackupGraph.empty() => const B04BackupGraph(
    graphVersion: currentGraphVersion,
    tables: <String, List<Map<String, dynamic>>>{},
  );

  static Future<B04BackupGraph> capture(AppDatabase db) async {
    final captured = <String, List<Map<String, dynamic>>>{};
    for (final entry in _b04Specs.entries) {
      captured[entry.key] = await _readRows(db, entry.key, entry.value);
    }
    return B04BackupGraph(
      graphVersion: currentGraphVersion,
      tables: _sortedTables(captured),
    );
  }

  factory B04BackupGraph.fromJson(Object? raw) {
    if (raw is! Map) {
      throw BackupV9ValidationException(
        'b04_graph_shape',
        'Backup-v9 b04_graph must be an object.',
      );
    }
    final map = Map<String, dynamic>.from(raw);
    if (map['graph_version'] != currentGraphVersion) {
      throw BackupV9ValidationException(
        'b04_graph_version',
        'Unsupported Backup-v9 B04 graph version ${map['graph_version']}.',
      );
    }
    final rawTables = map['tables'];
    if (rawTables is! Map) {
      throw BackupV9ValidationException(
        'b04_tables_shape',
        'Backup-v9 b04_graph.tables must be an object.',
      );
    }
    final tables = <String, List<Map<String, dynamic>>>{};
    for (final entry in rawTables.entries) {
      final table = entry.key;
      if (table is! String || !_b04Specs.containsKey(table)) {
        throw BackupV9ValidationException(
          'unknown_b04_table',
          'Backup-v9 B04 graph contains an unknown table.',
        );
      }
      final rawRows = entry.value;
      if (rawRows is! List) {
        throw BackupV9ValidationException(
          'b04_rows_shape',
          'Backup-v9 B04 table $table must contain a list.',
        );
      }
      tables[table] = [for (final rawRow in rawRows) _copyRow(rawRow, table)];
    }
    final graph = B04BackupGraph(
      graphVersion: currentGraphVersion,
      tables: _sortedTables(tables),
    );
    graph.validateStructure();
    return graph;
  }

  Map<String, dynamic> toJson() {
    if (graphVersion != currentGraphVersion) {
      throw BackupV9ValidationException(
        'b04_graph_version',
        'Unsupported Backup-v9 B04 graph version $graphVersion.',
      );
    }
    validateStructure();
    return {
      'graph_version': graphVersion,
      'tables': {
        for (final table in _b04Specs.keys.toList()..sort())
          table: [for (final row in _rows(table)) _jsonRow(row)],
      },
    };
  }

  void validateStructure() {
    final idsByTable = <String, Set<String>>{};
    final usersByTable = <String, Map<String, String>>{};
    for (final entry in _b04Specs.entries) {
      final table = entry.key;
      final spec = entry.value;
      final ids = <String>{};
      final users = <String, String>{};
      final uniqueValues = <String, String>{};
      for (final row in _rows(table)) {
        final keys = row.keys.toSet();
        final allowed = spec.columns.toSet();
        if (!keys.containsAll(allowed) ||
            keys.any((key) => !allowed.contains(key))) {
          throw BackupV9ValidationException(
            'unknown_or_missing_column',
            'Backup-v9 $table contains an unrecognised or missing typed column.',
          );
        }
        for (final key in keys) {
          if (_forbiddenKey(key)) {
            throw BackupV9ValidationException(
              'sensitive_payload',
              'Backup-v9 B04 graph contains a forbidden payload field.',
            );
          }
        }
        final id = _requiredString(row, 'id', table);
        if (!ids.add(id)) {
          throw BackupV9ValidationException(
            'duplicate_id',
            'Backup-v9 $table contains duplicate portable ID $id.',
          );
        }
        final userId = row['user_id'];
        if (userId != null) {
          if (userId is! String || userId.trim().isEmpty) {
            throw BackupV9ValidationException(
              'invalid_owner',
              'Backup-v9 $table has an invalid user owner.',
            );
          }
          users[id] = userId;
        }
        _validateRequiredColumns(row, table, spec);
        _validateTypedColumns(row, table);
        _validateDates(row, table);
        _validateEnums(row, table);
        _validatePolicyVersions(row, table);
        _validateNumericDomains(row, table);
        final uniqueKey = spec.uniqueColumns
            .map((column) => row[column])
            .toList(growable: false);
        if (uniqueKey.every((value) => value != null)) {
          final encoded = uniqueKey.map(_keyValue).join('\u0000');
          if (uniqueValues.containsKey(encoded)) {
            throw BackupV9ValidationException(
              'duplicate_unique_relationship',
              'Backup-v9 $table contains a duplicate unique relationship.',
            );
          }
          uniqueValues[encoded] = id;
        }
      }
      idsByTable[table] = ids;
      usersByTable[table] = users;
    }

    _validateRelationshipsForGraph(idsByTable, usersByTable);
    for (final entry in _b04Specs.entries) {
      final selfReferenceColumn = entry.value.selfReferenceColumn;
      if (selfReferenceColumn == null) continue;
      _topologicallySorted([..._rows(entry.key)], selfReferenceColumn);
    }
  }

  Future<void> validateAgainstTarget(AppDatabase db) async {
    if (db.schemaVersion < 18) {
      throw BackupV9ValidationException(
        'target_schema_version',
        'Backup-v9 B04 graph requires schema v18.',
      );
    }
    validateStructure();
  }

  /// Public helper for direct graph tests. Production v9 restore calls the
  /// existing-transaction variant so the whole legacy/v8/B04 graph is one
  /// atomic restore unit.
  Future<void> restoreInto(AppDatabase db) async {
    if (db.schemaVersion < 18) {
      throw BackupV9ValidationException(
        'target_schema_version',
        'Backup-v9 B04 graph requires schema v18.',
      );
    }
    validateStructure();
    await db.transaction(() => restoreIntoExistingTransaction(db));
  }

  Future<void> restoreIntoExistingTransaction(
    AppDatabase db, {
    BackupRestoreFailureInjector? failureInjector,
  }) async {
    validateStructure();
    if (failureInjector != null) {
      await failureInjector(
        BackupRestoreFailureStage.relationshipPrevalidation,
      );
    }
    await db.withB04RestoreMutation<void>(() async {
      await _deleteRows(db);
      if (failureInjector != null) {
        await failureInjector(BackupRestoreFailureStage.databaseMutation);
      }

      for (final table in _restoreOrder) {
        for (final row in _restoreRows(table)) {
          final columns = _b04Specs[table]!.columns;
          final values = [
            for (final column in columns)
              _databaseValue(
                column,
                table == 'coaching_eligibility_evaluations' &&
                        column == 'recommendation_id'
                    ? null
                    : row[column],
              ),
          ];
          await db.customStatement(
            'INSERT INTO $table (${columns.join(', ')}) VALUES '
            '(${List.filled(columns.length, '?').join(', ')})',
            values,
          );
        }
      }

      for (final row in _rows('coaching_eligibility_evaluations')) {
        final recommendationId = row['recommendation_id'];
        if (recommendationId == null) continue;
        await db.customStatement(
          'UPDATE coaching_eligibility_evaluations '
          'SET recommendation_id = ? WHERE id = ?',
          [recommendationId, row['id']],
        );
      }

      final foreignKeys = await db
          .customSelect('PRAGMA foreign_key_check')
          .get();
      if (foreignKeys.isNotEmpty) {
        throw BackupV9ValidationException(
          'foreign_key_integrity',
          'Backup-v9 restore produced a foreign-key violation.',
        );
      }
      if (failureInjector != null) {
        await failureInjector(
          BackupRestoreFailureStage.beforeTransactionCommit,
        );
      }
    });
  }

  List<Map<String, dynamic>> _rows(String table) => tables[table] ?? const [];

  Future<void> _deleteRows(AppDatabase db) async {
    for (final table in _deleteOrder) {
      await db.customStatement('DELETE FROM $table');
    }
  }

  List<Map<String, dynamic>> _restoreRows(String table) {
    final rows = [..._rows(table)];
    final parentColumn = _b04Specs[table]!.selfReferenceColumn;
    if (parentColumn == null) return rows;
    return _topologicallySorted(rows, parentColumn);
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
    void visit(String id) {
      if (visited.contains(id)) return;
      if (!visiting.add(id)) {
        throw BackupV9ValidationException(
          'cyclic_relationship',
          'Backup-v9 B04 graph contains a cyclic self-reference.',
        );
      }
      final parent = byId[id]?[parentColumn];
      if (parent != null) {
        if (parent is! String || !byId.containsKey(parent)) {
          throw BackupV9ValidationException(
            'missing_reference',
            'Backup-v9 B04 graph contains a missing self-reference.',
          );
        }
        visit(parent);
      }
      visiting.remove(id);
      visited.add(id);
      ordered.add(byId[id]!);
    }

    for (final row in rows) {
      visit(row['id'] as String);
    }
    return ordered;
  }

  static Map<String, List<Map<String, dynamic>>> _sortedTables(
    Map<String, List<Map<String, dynamic>>> input,
  ) => {
    for (final table in input.keys.toList()..sort())
      table: [
        ...input[table]!..sort((a, b) => _rowKey(a).compareTo(_rowKey(b))),
      ],
  };

  static String _rowKey(Map<String, dynamic> row) => '${row['id']}';

  static Map<String, dynamic> _copyRow(Object? raw, String table) {
    if (raw is! Map) {
      throw BackupV9ValidationException(
        'malformed_row',
        'Backup-v9 $table contains a non-object row.',
      );
    }
    return Map<String, dynamic>.from(raw);
  }

  static Map<String, dynamic> _jsonRow(Map<String, dynamic> row) => {
    for (final key in row.keys.toList()..sort()) key: _jsonValue(row[key]),
  };

  static dynamic _jsonValue(Object? value) {
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is Map) {
      return {
        for (final key in value.keys.toList()..sort())
          '$key': _jsonValue(value[key]),
      };
    }
    if (value is Iterable) return value.map(_jsonValue).toList(growable: false);
    return value;
  }

  static dynamic _databaseValue(String column, Object? value) {
    if (value is DateTime) return _unixSeconds(value);
    if (value is bool) return value ? 1 : 0;
    if (value is String && _timestampColumns.contains(column)) {
      final parsed = _dateTime(value);
      if (parsed != null) return _unixSeconds(parsed);
    }
    return value;
  }

  static int _unixSeconds(DateTime value) =>
      value.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;

  static Future<List<Map<String, dynamic>>> _readRows(
    AppDatabase db,
    String table,
    _B04TableSpec spec,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT ${spec.columns.join(', ')} FROM $table ORDER BY id',
        )
        .get();
    return [
      for (final row in rows)
        {for (final column in spec.columns) column: row.data[column]},
    ];
  }

  static void _validateRequiredColumns(
    Map<String, dynamic> row,
    String table,
    _B04TableSpec spec,
  ) {
    for (final column in spec.columns) {
      if (spec.nullableColumns.contains(column)) continue;
      if (row[column] == null) {
        throw BackupV9ValidationException(
          'missing_required_field',
          'Backup-v9 $table.$column is required.',
        );
      }
    }
  }

  static String _requiredString(
    Map<String, dynamic> row,
    String column,
    String table,
  ) {
    final value = row[column];
    if (value is! String || value.trim().isEmpty) {
      throw BackupV9ValidationException(
        'invalid_string',
        'Backup-v9 $table.$column must be a non-empty string.',
      );
    }
    return value;
  }

  static void _validateTypedColumns(Map<String, dynamic> row, String table) {
    for (final entry in row.entries) {
      final column = entry.key;
      final value = entry.value;
      if (value == null) continue;

      if (_timestampColumns.contains(column)) {
        if ((value is num && value is! int) || _dateTime(value) == null) {
          throw BackupV9ValidationException(
            'invalid_typed_column',
            'Backup-v9 $table.$column must be a UTC timestamp.',
          );
        }
        continue;
      }
      if (_integerColumns.contains(column)) {
        if (value is! int) {
          throw BackupV9ValidationException(
            'invalid_typed_column',
            'Backup-v9 $table.$column must be an integer.',
          );
        }
        continue;
      }
      if (_numericColumns.contains(column)) {
        if (value is! num || !value.isFinite) {
          throw BackupV9ValidationException(
            'invalid_typed_column',
            'Backup-v9 $table.$column must be a finite number.',
          );
        }
        continue;
      }
      if (_booleanColumns.contains(column)) {
        if (value is! bool && !(value is int && (value == 0 || value == 1))) {
          throw BackupV9ValidationException(
            'invalid_typed_column',
            'Backup-v9 $table.$column must be a boolean.',
          );
        }
        continue;
      }
      if (value is! String) {
        throw BackupV9ValidationException(
          'invalid_typed_column',
          'Backup-v9 $table.$column must be a typed string value.',
        );
      }
    }
  }

  static void _validateDates(Map<String, dynamic> row, String table) {
    for (final column in _timestampColumns) {
      if (!row.containsKey(column) || row[column] == null) continue;
      if (_dateTime(row[column]) == null) {
        throw BackupV9ValidationException(
          'invalid_timestamp',
          'Backup-v9 $table.$column is not a valid UTC timestamp.',
        );
      }
    }
    final localDateColumns = [
      'effective_from_local_date',
      'effective_to_local_date',
      'local_date',
      'evaluation_local_date',
      'local_period_start',
      'local_period_end',
    ];
    for (final column in localDateColumns) {
      final value = row[column];
      if (value == null) continue;
      final timezone = row['timezone_id'];
      if (value is! String || timezone is! String) {
        throw BackupV9ValidationException(
          'invalid_local_time',
          'Backup-v9 $table has an invalid local date/timezone pair.',
        );
      }
      try {
        final dates = LocalScheduleDateService();
        dates.normalizeLocalDate(value);
        dates.validateTimezone(timezone);
      } catch (_) {
        throw BackupV9ValidationException(
          'invalid_local_time',
          'Backup-v9 $table has an invalid local date/timezone pair.',
        );
      }
    }
    if (row['effective_to_local_date'] != null &&
        row['effective_from_local_date'] != null &&
        '${row['effective_to_local_date']}'.compareTo(
              '${row['effective_from_local_date']}',
            ) <
            0) {
      throw BackupV9ValidationException(
        'invalid_effective_range',
        'Backup-v9 $table contains a backwards effective-date range.',
      );
    }
    if (row['local_period_start'] != null &&
        row['local_period_end'] != null &&
        '${row['local_period_end']}'.compareTo('${row['local_period_start']}') <
            0) {
      throw BackupV9ValidationException(
        'invalid_period_range',
        'Backup-v9 $table contains a backwards local period.',
      );
    }
  }

  static void _validateEnums(Map<String, dynamic> row, String table) {
    const enums = <String, Map<String, Set<String>>>{
      'nutrition_goal_versions': {
        'goal_type': {'loss', 'maintenance', 'gain', 'custom'},
        'target_source': {
          'user_set',
          'calculated',
          'adaptive',
          'override',
          'compatibility',
        },
      },
      'coaching_consent_events': {
        'consent_category': {'adaptive_coaching', 'optional_ai'},
        'action': {'enable', 'disable', 'withdraw'},
      },
      'recovery_observations': {
        'status': {'known', 'estimated', 'missing', 'unknown', 'invalid'},
        'freshness': {'fresh', 'stale', 'unknown'},
      },
      'readiness_snapshots': {
        'completeness': {'complete', 'incomplete', 'unknown'},
        'status': {'available', 'cautious', 'unavailable'},
      },
      'recommendations': {
        'scope': {
          'daily',
          'weekly',
          'training',
          'nutrition',
          'meal_opportunity',
        },
        'status': {
          'available',
          'cautious',
          'confirm',
          'unavailable',
          'dismissed',
          'superseded',
        },
      },
      'coaching_eligibility_evaluations': {
        'result': {
          'eligible',
          'underage',
          'unknown_age',
          'conflicting_age',
          'withheld_age',
          'invalid_evidence',
          'policy_unavailable',
        },
        'age_input_source': {
          'verified_dob',
          'user_entered_dob',
          'missing',
          'unknown',
          'withheld',
          'conflicting',
          'invalid',
          'policy',
        },
      },
      'recommendation_feedback': {
        'action': {
          'acknowledge',
          'dismiss',
          'accept',
          'override',
          'snooze',
          'not_relevant',
        },
      },
    };
    for (final entry
        in enums[table]?.entries ?? const <MapEntry<String, Set<String>>>[]) {
      final value = row[entry.key];
      if (value is! String || !entry.value.contains(value)) {
        throw BackupV9ValidationException(
          'invalid_enum',
          'Backup-v9 $table.${entry.key} has an unsupported value.',
        );
      }
    }
    if (table == 'coaching_eligibility_evaluations') {
      const validPairs = {
        'eligible': {'verified_dob', 'user_entered_dob'},
        'underage': {'verified_dob', 'user_entered_dob'},
        'unknown_age': {'missing', 'unknown'},
        'conflicting_age': {'conflicting'},
        'withheld_age': {'withheld'},
        'invalid_evidence': {'invalid'},
        'policy_unavailable': {'policy'},
      };
      if (!validPairs[row['result']]!.contains(row['age_input_source'])) {
        throw BackupV9ValidationException(
          'invalid_result_source',
          'Backup-v9 eligibility result and age source do not agree.',
        );
      }
    }
  }

  static void _validatePolicyVersions(Map<String, dynamic> row, String table) {
    final policy = row['policy_version'];
    if (policy == null) return;
    if (policy is! String ||
        !{
          kB04HoldPolicyVersion,
          kB04EnabledPolicyVersion,
          kB04ReadinessHoldPolicyVersion,
        }.contains(policy)) {
      throw BackupV9ValidationException(
        'unsupported_policy_version',
        'Backup-v9 $table contains an unsupported policy version.',
      );
    }
  }

  static void _validateNumericDomains(Map<String, dynamic> row, String table) {
    for (final column in const [
      'version_number',
      'projection_version',
      'priority',
      'calorie_target_kcal',
      'normalized_maintenance_kcal',
      'proposed_delta_kcal',
    ]) {
      final value = row[column];
      if (value != null &&
          (value is! int || (column == 'priority' && value < 0))) {
        throw BackupV9ValidationException(
          'invalid_integer',
          'Backup-v9 $table.$column must be a valid integer domain value.',
        );
      }
    }
    final versionNumber = row['version_number'];
    if (versionNumber is int && versionNumber < 1) {
      throw BackupV9ValidationException(
        'invalid_version_number',
        'Backup-v9 $table version number must be positive.',
      );
    }
    final projectionVersion = row['projection_version'];
    if (projectionVersion is int && projectionVersion < 1) {
      throw BackupV9ValidationException(
        'invalid_projection_version',
        'Backup-v9 $table projection version must be positive.',
      );
    }
    for (final column in const ['confidence', 'value', 'lower', 'upper']) {
      final value = row[column];
      if (value is num && !value.isFinite) {
        throw BackupV9ValidationException(
          'invalid_numeric',
          'Backup-v9 $table.$column must be finite.',
        );
      }
    }
    final confidence = row['confidence'];
    if (confidence is num && (confidence < 0 || confidence > 1)) {
      throw BackupV9ValidationException(
        'invalid_confidence',
        'Backup-v9 $table confidence must be between 0 and 1.',
      );
    }
    for (final column in const ['lower', 'upper', 'value']) {
      final value = row[column];
      if (value is num && value < 0) {
        throw BackupV9ValidationException(
          'invalid_numeric',
          'Backup-v9 $table.$column cannot be negative.',
        );
      }
    }
    final lower = row['lower'];
    final upper = row['upper'];
    if (lower is num && upper is num && lower > upper) {
      throw BackupV9ValidationException(
        'invalid_range',
        'Backup-v9 $table contains a backwards numeric range.',
      );
    }
    for (final column in const [
      'exact_result_numerator',
      'exact_result_denominator',
    ]) {
      final value = row[column];
      if (value == null) continue;
      if (value is! String) {
        throw BackupV9ValidationException(
          'invalid_exact_result',
          'Backup-v9 $table contains a non-string exact result.',
        );
      }
      try {
        final parsed = BigInt.parse(value);
        if (column == 'exact_result_denominator' && parsed == BigInt.zero) {
          throw const FormatException();
        }
      } catch (_) {
        throw BackupV9ValidationException(
          'invalid_exact_result',
          'Backup-v9 $table contains an invalid exact result.',
        );
      }
    }
    if ((row['exact_result_numerator'] == null) !=
        (row['exact_result_denominator'] == null)) {
      throw BackupV9ValidationException(
        'invalid_exact_result',
        'Backup-v9 exact results must include both numerator and denominator.',
      );
    }
    final normalized = row['normalized_maintenance_kcal'];
    if (normalized is num && normalized <= 0) {
      throw BackupV9ValidationException(
        'invalid_normalized_maintenance',
        'Backup-v9 $table normalized maintenance must be positive.',
      );
    }
  }

  void _validateRelationships(
    Map<String, Set<String>> idsByTable,
    Map<String, Map<String, String>> usersByTable,
  ) {
    final goals = _rowsForValidation('nutrition_goal_versions');
    final consents = _rowsForValidation('coaching_consent_events');
    final readiness = _rowsForValidation('readiness_snapshots');
    final recommendations = _rowsForValidation('recommendations');
    final feedback = _rowsForValidation('recommendation_feedback');

    void ref({
      required String table,
      required Map<String, dynamic> row,
      required String column,
      required String parentTable,
      required String owner,
    }) {
      final value = row[column];
      if (value == null) return;
      if (value is! String || !idsByTable[parentTable]!.contains(value)) {
        throw BackupV9ValidationException(
          'missing_reference',
          'Backup-v9 $table.$column references a missing row.',
        );
      }
      final childUser = row['user_id'];
      final parentUser = usersByTable[parentTable]![value];
      if (childUser != null && childUser != parentUser) {
        throw BackupV9ValidationException(
          'cross_user_reference',
          'Backup-v9 $owner crosses user ownership boundaries.',
        );
      }
    }

    for (final row in goals) {
      ref(
        table: 'nutrition_goal_versions',
        row: row,
        column: 'supersedes_goal_version_id',
        parentTable: 'nutrition_goal_versions',
        owner: 'goal lineage',
      );
      final parent = row['supersedes_goal_version_id'];
      if (parent != null &&
          (row['version_number'] as num) <=
              (goals.firstWhere(
                    (item) => item['id'] == parent,
                  )['version_number']
                  as num)) {
        throw BackupV9ValidationException(
          'invalid_event_order',
          'Backup-v9 goal versions must increase along supersedes lineage.',
        );
      }
    }
    for (final row in consents) {
      ref(
        table: 'coaching_consent_events',
        row: row,
        column: 'related_or_superseded_event_id',
        parentTable: 'coaching_consent_events',
        owner: 'consent lineage',
      );
      final parentId = row['related_or_superseded_event_id'];
      if (parentId != null) {
        final parent = consents.firstWhere((item) => item['id'] == parentId);
        if (parent['consent_category'] != row['consent_category'] ||
            !_isBefore(parent['timestamp_utc'], row['timestamp_utc'])) {
          throw BackupV9ValidationException(
            'invalid_event_order',
            'Backup-v9 consent events must retain category and chronological order.',
          );
        }
      }
    }
    for (final row in readiness) {
      ref(
        table: 'readiness_snapshots',
        row: row,
        column: 'supersedes_snapshot_id',
        parentTable: 'readiness_snapshots',
        owner: 'readiness lineage',
      );
    }
    for (final row in recommendations) {
      ref(
        table: 'recommendations',
        row: row,
        column: 'goal_version_id',
        parentTable: 'nutrition_goal_versions',
        owner: 'recommendation goal lineage',
      );
      ref(
        table: 'recommendations',
        row: row,
        column: 'readiness_snapshot_id',
        parentTable: 'readiness_snapshots',
        owner: 'recommendation readiness lineage',
      );
      ref(
        table: 'recommendations',
        row: row,
        column: 'supersedes_recommendation_id',
        parentTable: 'recommendations',
        owner: 'recommendation lineage',
      );
    }
    for (final row in _rowsForValidation('readiness_snapshot_evidence')) {
      ref(
        table: 'readiness_snapshot_evidence',
        row: row,
        column: 'readiness_snapshot_id',
        parentTable: 'readiness_snapshots',
        owner: 'readiness evidence',
      );
      ref(
        table: 'readiness_snapshot_evidence',
        row: row,
        column: 'observation_id',
        parentTable: 'recovery_observations',
        owner: 'readiness evidence',
      );
      final snapshotUser =
          usersByTable['readiness_snapshots']![row['readiness_snapshot_id']];
      final observationUser =
          usersByTable['recovery_observations']![row['observation_id']];
      if (snapshotUser != observationUser) {
        throw BackupV9ValidationException(
          'cross_user_reference',
          'Backup-v9 readiness evidence crosses user ownership boundaries.',
        );
      }
    }
    for (final row in _rowsForValidation('recommendation_evidence')) {
      ref(
        table: 'recommendation_evidence',
        row: row,
        column: 'recommendation_id',
        parentTable: 'recommendations',
        owner: 'recommendation evidence',
      );
      final recommendationUser =
          usersByTable['recommendations']![row['recommendation_id']];
      if (recommendationUser != row['user_id']) {
        throw BackupV9ValidationException(
          'cross_user_reference',
          'Backup-v9 recommendation evidence crosses user ownership boundaries.',
        );
      }
    }
    for (final row in _rowsForValidation('coaching_eligibility_evaluations')) {
      ref(
        table: 'coaching_eligibility_evaluations',
        row: row,
        column: 'goal_version_id',
        parentTable: 'nutrition_goal_versions',
        owner: 'eligibility goal lineage',
      );
      ref(
        table: 'coaching_eligibility_evaluations',
        row: row,
        column: 'recommendation_id',
        parentTable: 'recommendations',
        owner: 'eligibility recommendation lineage',
      );
    }
    for (final row in feedback) {
      ref(
        table: 'recommendation_feedback',
        row: row,
        column: 'recommendation_id',
        parentTable: 'recommendations',
        owner: 'feedback recommendation lineage',
      );
      ref(
        table: 'recommendation_feedback',
        row: row,
        column: 'related_feedback_id',
        parentTable: 'recommendation_feedback',
        owner: 'feedback lineage',
      );
    }
  }

  void _validateRelationshipsForGraph(
    Map<String, Set<String>> idsByTable,
    Map<String, Map<String, String>> usersByTable,
  ) {
    _validateRelationships(idsByTable, usersByTable);
  }

  List<Map<String, dynamic>> _rowsForValidation(String table) => _rows(table);

  static DateTime? _dateTime(Object? value) {
    if (value is DateTime) return value.toUtc();
    if (value is String) {
      try {
        return parseLegacyBackupTimestamp(value);
      } catch (_) {
        return null;
      }
    }
    if (value is num) {
      if (value is! int) return null;
      try {
        return DateTime.fromMillisecondsSinceEpoch(
          value * Duration.millisecondsPerSecond,
          isUtc: true,
        );
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static bool _isBefore(Object? first, Object? second) {
    final left = _dateTime(first);
    final right = _dateTime(second);
    return left != null && right != null && left.isBefore(right);
  }

  static String _keyValue(Object? value) => _jsonValue(value).toString();

  static bool _forbiddenKey(String key) {
    final normalized = key.toLowerCase();
    return normalized.contains('prompt') ||
        normalized.contains('raw_response') ||
        normalized.contains('image') ||
        normalized.contains('secret') ||
        normalized.contains('token') ||
        normalized.contains('password') ||
        normalized.contains('health_payload') ||
        normalized.contains('medical_restriction');
  }
}

class _B04TableSpec {
  final List<String> columns;
  final Set<String> nullableColumns;
  final List<String> uniqueColumns;
  final String? selfReferenceColumn;

  const _B04TableSpec({
    required this.columns,
    this.nullableColumns = const {},
    required this.uniqueColumns,
    this.selfReferenceColumn,
  });
}

const _b04Specs = <String, _B04TableSpec>{
  'nutrition_goal_versions': _B04TableSpec(
    columns: [
      'id',
      'user_id',
      'version_number',
      'goal_type',
      'target_source',
      'calorie_target_kcal',
      'protein_target_g',
      'carbs_target_g',
      'fat_target_g',
      'policy_version',
      'calculation_version',
      'algorithm_version',
      'effective_from_local_date',
      'effective_to_local_date',
      'timezone_id',
      'supersedes_goal_version_id',
      'evidence_fingerprint',
      'exact_result_numerator',
      'exact_result_denominator',
      'normalized_maintenance_kcal',
      'created_at_utc',
    ],
    nullableColumns: {
      'calorie_target_kcal',
      'protein_target_g',
      'carbs_target_g',
      'fat_target_g',
      'policy_version',
      'calculation_version',
      'algorithm_version',
      'effective_to_local_date',
      'supersedes_goal_version_id',
      'evidence_fingerprint',
      'exact_result_numerator',
      'exact_result_denominator',
      'normalized_maintenance_kcal',
    },
    uniqueColumns: ['user_id', 'version_number'],
    selfReferenceColumn: 'supersedes_goal_version_id',
  ),
  'coaching_consent_events': _B04TableSpec(
    columns: [
      'id',
      'user_id',
      'consent_category',
      'action',
      'consent_policy_version',
      'copy_version',
      'timestamp_utc',
      'local_date',
      'timezone_id',
      'actor_source',
      'related_or_superseded_event_id',
      'created_at_utc',
    ],
    nullableColumns: {'related_or_superseded_event_id'},
    uniqueColumns: ['user_id', 'consent_category', 'action', 'timestamp_utc'],
    selfReferenceColumn: 'related_or_superseded_event_id',
  ),
  'nutrition_coaching_preferences': _B04TableSpec(
    columns: [
      'id',
      'user_id',
      'adaptive_coaching_enabled',
      'optional_ai_enabled',
      'projection_version',
      'is_archived',
      'created_at_utc',
      'updated_at_utc',
    ],
    uniqueColumns: ['user_id'],
  ),
  'recovery_observations': _B04TableSpec(
    columns: [
      'id',
      'user_id',
      'kind',
      'observed_at_utc',
      'local_date',
      'timezone_id',
      'status',
      'unit',
      'value',
      'lower',
      'upper',
      'source',
      'provenance',
      'freshness',
      'provider_external_id',
      'source_version',
      'evidence_timestamp_utc',
      'created_at_utc',
    ],
    nullableColumns: {
      'value',
      'lower',
      'upper',
      'provider_external_id',
      'source_version',
      'evidence_timestamp_utc',
    },
    uniqueColumns: ['user_id', 'source', 'provider_external_id'],
  ),
  'readiness_snapshots': _B04TableSpec(
    columns: [
      'id',
      'user_id',
      'local_date',
      'timezone_id',
      'completeness',
      'status',
      'band',
      'confidence',
      'calculation_version',
      'policy_version',
      'unavailable_reason',
      'evidence_fingerprint',
      'created_at_utc',
      'superseded_at_utc',
      'supersedes_snapshot_id',
    ],
    nullableColumns: {
      'band',
      'confidence',
      'policy_version',
      'unavailable_reason',
      'evidence_fingerprint',
      'superseded_at_utc',
      'supersedes_snapshot_id',
    },
    uniqueColumns: ['user_id', 'local_date', 'calculation_version'],
    selfReferenceColumn: 'supersedes_snapshot_id',
  ),
  'readiness_snapshot_evidence': _B04TableSpec(
    columns: [
      'id',
      'readiness_snapshot_id',
      'observation_id',
      'evidence_kind',
      'status',
      'value',
      'lower',
      'upper',
      'unit',
      'source_version',
      'created_at_utc',
    ],
    nullableColumns: {'value', 'lower', 'upper', 'unit', 'source_version'},
    uniqueColumns: ['readiness_snapshot_id', 'observation_id'],
  ),
  'recommendations': _B04TableSpec(
    columns: [
      'id',
      'user_id',
      'scope',
      'local_period_start',
      'local_period_end',
      'timezone_id',
      'status',
      'priority',
      'confidence',
      'completeness',
      'action',
      'explanation',
      'missing_inputs',
      'uncertainty',
      'alternatives',
      'rule_version',
      'calculation_version',
      'algorithm_version',
      'model_version',
      'provider_version',
      'policy_version',
      'goal_version_id',
      'readiness_snapshot_id',
      'context_fingerprint',
      'evidence_fingerprint',
      'exact_result_numerator',
      'exact_result_denominator',
      'normalized_maintenance_kcal',
      'proposed_delta_kcal',
      'created_at_utc',
      'effective_at_utc',
      'superseded_at_utc',
      'supersedes_recommendation_id',
      'replay_hash',
    ],
    nullableColumns: {
      'confidence',
      'completeness',
      'missing_inputs',
      'uncertainty',
      'alternatives',
      'calculation_version',
      'algorithm_version',
      'model_version',
      'provider_version',
      'policy_version',
      'goal_version_id',
      'readiness_snapshot_id',
      'evidence_fingerprint',
      'exact_result_numerator',
      'exact_result_denominator',
      'normalized_maintenance_kcal',
      'proposed_delta_kcal',
      'effective_at_utc',
      'superseded_at_utc',
      'supersedes_recommendation_id',
      'replay_hash',
    },
    uniqueColumns: ['user_id', 'replay_hash'],
    selfReferenceColumn: 'supersedes_recommendation_id',
  ),
  'recommendation_evidence': _B04TableSpec(
    columns: [
      'id',
      'recommendation_id',
      'user_id',
      'evidence_kind',
      'source_type',
      'source_id',
      'source_version',
      'status',
      'value',
      'lower',
      'upper',
      'unit',
      'exact_result_numerator',
      'exact_result_denominator',
      'normalized_maintenance_kcal',
      'local_date',
      'timezone_id',
      'created_at_utc',
    ],
    nullableColumns: {
      'source_id',
      'source_version',
      'value',
      'lower',
      'upper',
      'unit',
      'exact_result_numerator',
      'exact_result_denominator',
      'normalized_maintenance_kcal',
      'local_date',
      'timezone_id',
    },
    uniqueColumns: ['recommendation_id', 'evidence_kind', 'source_id'],
  ),
  'coaching_eligibility_evaluations': _B04TableSpec(
    columns: [
      'id',
      'user_id',
      'result',
      'reason_code',
      'age_input_source',
      'evidence_timestamp_utc',
      'evaluation_utc',
      'evaluation_local_date',
      'timezone_id',
      'policy_version',
      'minimum_age_rule_version',
      'goal_version_id',
      'recommendation_id',
      'attempted_proposal_id',
      'evidence_fingerprint',
      'created_at_utc',
    ],
    nullableColumns: {
      'goal_version_id',
      'recommendation_id',
      'attempted_proposal_id',
      'evidence_fingerprint',
    },
    uniqueColumns: ['user_id', 'evaluation_utc', 'policy_version'],
  ),
  'recommendation_feedback': _B04TableSpec(
    columns: [
      'id',
      'user_id',
      'recommendation_id',
      'action',
      'reason',
      'source',
      'local_date',
      'timezone_id',
      'created_at_utc',
      'related_feedback_id',
    ],
    nullableColumns: {'reason', 'related_feedback_id'},
    uniqueColumns: [
      'user_id',
      'recommendation_id',
      'action',
      'related_feedback_id',
    ],
    selfReferenceColumn: 'related_feedback_id',
  ),
};

const _restoreOrder = [
  'coaching_consent_events',
  'nutrition_coaching_preferences',
  'nutrition_goal_versions',
  'recovery_observations',
  'coaching_eligibility_evaluations',
  'readiness_snapshots',
  'readiness_snapshot_evidence',
  'recommendations',
  'recommendation_evidence',
  'recommendation_feedback',
];

const _deleteOrder = [
  'recommendation_feedback',
  'recommendation_evidence',
  'coaching_eligibility_evaluations',
  'readiness_snapshot_evidence',
  'recommendations',
  'readiness_snapshots',
  'recovery_observations',
  'nutrition_goal_versions',
  'nutrition_coaching_preferences',
  'coaching_consent_events',
];

const _timestampColumns = {
  'timestamp_utc',
  'created_at_utc',
  'updated_at_utc',
  'observed_at_utc',
  'evidence_timestamp_utc',
  'evaluation_utc',
  'superseded_at_utc',
  'effective_at_utc',
};

const _integerColumns = {
  'version_number',
  'projection_version',
  'calorie_target_kcal',
  'normalized_maintenance_kcal',
  'priority',
  'proposed_delta_kcal',
};

const _numericColumns = {
  'protein_target_g',
  'carbs_target_g',
  'fat_target_g',
  'value',
  'lower',
  'upper',
  'confidence',
};

const _booleanColumns = {
  'adaptive_coaching_enabled',
  'optional_ai_enabled',
  'is_archived',
};
