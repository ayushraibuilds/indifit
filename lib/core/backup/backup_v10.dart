import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import 'backup_schema.dart';
import 'backup_v8.dart';
import 'backup_v9.dart';

/// Validation errors for the schema-v19 / Backup-v10 B05 foundation graph.
class BackupV10ValidationException extends FormatException {
  final String code;

  BackupV10ValidationException(this.code, String message) : super(message);
}

/// Schema-v19 is an extension of the accepted v9 graph. B05 rows contain only
/// portable user intent and versioned progress; device-local media bytes and
/// availability are deliberately never exported or restored.
class BackupV10Data {
  static const int currentVersion = 10;

  final int version;
  final String timestamp;
  final int schemaVersion;
  final BackupData legacy;
  final NutritionBackupGraph nutrition;
  final B04BackupGraph adaptiveCoaching;
  final B05BackupGraph b05;

  const BackupV10Data({
    required this.version,
    required this.timestamp,
    required this.schemaVersion,
    required this.legacy,
    required this.nutrition,
    required this.adaptiveCoaching,
    required this.b05,
  });

  B04BackupGraph get b04 => adaptiveCoaching;

  static Future<BackupV10Data> createFromDatabase(
    AppDatabase db, [
    SharedPreferences? prefs,
  ]) async {
    if (db.schemaVersion < 19) {
      throw BackupV10ValidationException(
        'source_schema_version',
        'Backup-v10 export requires a schema-v19 database.',
      );
    }
    final v9 = await BackupV9Data.createFromDatabase(db, prefs);
    final b05 = await B05BackupGraph.capture(db);
    b05.validateStructure();
    return BackupV10Data(
      version: currentVersion,
      timestamp: v9.timestamp,
      schemaVersion: db.schemaVersion,
      legacy: v9.legacy,
      nutrition: v9.nutrition,
      adaptiveCoaching: v9.adaptiveCoaching,
      b05: b05,
    );
  }

  /// Decodes v10 and all v5-v9 imports. Older payloads carry an empty B05
  /// graph; no dashboard, education, media, or playlist state is inferred.
  static BackupV10Data fromJson(Map<String, dynamic> json) {
    final raw = json['version'];
    if (raw is! int) {
      throw BackupV10ValidationException(
        'missing_version',
        'Backup-v10 payload requires a numeric version.',
      );
    }
    if (raw > currentVersion) {
      throw BackupV10ValidationException(
        'unsupported_newer_version',
        'Unsupported backup format version $raw (latest supported is $currentVersion).',
      );
    }
    if (raw < 5) {
      throw BackupV10ValidationException(
        'unsupported_legacy_version',
        'Backup-v10 compatibility accepts versions 5 through 10 only.',
      );
    }

    if (raw < currentVersion) {
      final v9 = BackupV9Data.fromJson(json);
      return BackupV10Data(
        version: v9.version,
        timestamp: v9.timestamp,
        schemaVersion: v9.schemaVersion,
        legacy: v9.legacy,
        nutrition: v9.nutrition,
        adaptiveCoaching: v9.adaptiveCoaching,
        b05: B05BackupGraph.empty(),
      );
    }

    final v9Json = Map<String, dynamic>.from(json)..['version'] = 9;
    v9Json.remove('b05_graph');
    final v9 = BackupV9Data.fromJson(v9Json);
    final schemaVersion = (json['schema_version'] as num?)?.toInt() ?? 19;
    if (schemaVersion < 19) {
      throw BackupV10ValidationException(
        'schema_version',
        'Backup-v10 B05 graph requires schema v19 or newer.',
      );
    }
    final graph = B05BackupGraph.fromJson(json['b05_graph']);
    return BackupV10Data(
      version: currentVersion,
      timestamp: json['timestamp'] as String? ?? v9.timestamp,
      schemaVersion: schemaVersion,
      legacy: v9.legacy,
      nutrition: v9.nutrition,
      adaptiveCoaching: v9.adaptiveCoaching,
      b05: graph,
    );
  }

  Map<String, dynamic> toJson() {
    final base = BackupV9Data(
      version: version >= currentVersion ? 9 : version,
      timestamp: timestamp,
      schemaVersion: schemaVersion,
      legacy: legacy,
      nutrition: nutrition,
      adaptiveCoaching: adaptiveCoaching,
    ).toJson();
    if (version >= currentVersion) {
      b05.validateStructure();
      base['version'] = currentVersion;
      base['schema_version'] = schemaVersion;
      base['b05_graph'] = b05.toJson();
    }
    return base;
  }

  Future<void> restoreToDatabase(
    AppDatabase db, [
    SharedPreferences? prefs,
  ]) async {
    if (version < currentVersion) {
      await _restoreLegacyVersion(db, prefs);
      return;
    }
    await _validateTarget(db);
    await legacy.restoreToDatabaseWithAdditionalMutation(
      db,
      prefs: prefs,
      additionalMutation: (target) async {
        await nutrition.restoreInto(target);
        adaptiveCoaching.validateStructure();
        await adaptiveCoaching.restoreIntoExistingTransaction(target);
        await b05.restoreIntoExistingTransaction(target);
      },
    );
  }

  Future<void> restoreToDatabaseWithFailureInjector(
    AppDatabase db, {
    SharedPreferences? prefs,
    required BackupRestoreFailureInjector failureInjector,
  }) async {
    if (version < currentVersion) {
      await _restoreLegacyVersionWithFailureInjector(
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
      additionalMutation: (target) async {
        await nutrition.restoreInto(target);
        adaptiveCoaching.validateStructure();
        await adaptiveCoaching.restoreIntoExistingTransaction(
          target,
          failureInjector: failureInjector,
        );
        await b05.restoreIntoExistingTransaction(
          target,
          failureInjector: failureInjector,
        );
      },
    );
  }

  Future<void> _validateTarget(AppDatabase db) async {
    if (db.schemaVersion < 19) {
      throw BackupV10ValidationException(
        'target_schema_version',
        'Backup-v10 restore requires a schema-v19 database.',
      );
    }
    await nutrition.validateAgainstTarget(db);
    adaptiveCoaching.validateStructure();
    b05.validateAgainstTarget(db);
  }

  BackupV9Data _asV9() => BackupV9Data(
    version: version,
    timestamp: timestamp,
    schemaVersion: schemaVersion,
    legacy: legacy,
    nutrition: nutrition,
    adaptiveCoaching: adaptiveCoaching,
  );

  Future<void> _restoreLegacyVersion(
    AppDatabase db,
    SharedPreferences? prefs,
  ) async {
    if (db.schemaVersion < 19) {
      await _asV9().restoreToDatabase(db, prefs);
      return;
    }
    await nutrition.validateAgainstTarget(db);
    adaptiveCoaching.validateStructure();
    await legacy.restoreToDatabaseWithAdditionalMutation(
      db,
      prefs: prefs,
      additionalMutation: (target) async {
        await nutrition.restoreInto(target);
        await adaptiveCoaching.restoreIntoExistingTransaction(target);
        await B05BackupGraph.empty().restoreIntoExistingTransaction(target);
      },
    );
  }

  Future<void> _restoreLegacyVersionWithFailureInjector(
    AppDatabase db, {
    SharedPreferences? prefs,
    required BackupRestoreFailureInjector failureInjector,
  }) async {
    if (db.schemaVersion < 19) {
      await _asV9().restoreToDatabaseWithFailureInjector(
        db,
        prefs: prefs,
        failureInjector: failureInjector,
      );
      return;
    }
    await nutrition.validateAgainstTarget(db);
    adaptiveCoaching.validateStructure();
    await legacy.restoreToDatabaseWithFailureInjector(
      db,
      prefs: prefs,
      failureInjector: failureInjector,
      additionalMutation: (target) async {
        await nutrition.restoreInto(target);
        await adaptiveCoaching.restoreIntoExistingTransaction(
          target,
          failureInjector: failureInjector,
        );
        await B05BackupGraph.empty().restoreIntoExistingTransaction(
          target,
          failureInjector: failureInjector,
        );
      },
    );
  }
}

/// Portable B05 rows. The exact typed column allowlist is the backup contract;
/// arbitrary widget configuration, URLs, credentials, tokens, file paths,
/// bytes, and physical availability cannot enter this graph.
class B05BackupGraph {
  static const int currentGraphVersion = 1;

  final int graphVersion;
  final Map<String, List<Map<String, dynamic>>> tables;

  const B05BackupGraph({required this.graphVersion, required this.tables});

  factory B05BackupGraph.empty() => B05BackupGraph(
    graphVersion: currentGraphVersion,
    tables: {for (final table in _b05Specs.keys) table: const []},
  );

  static Future<B05BackupGraph> capture(AppDatabase db) async {
    final captured = <String, List<Map<String, dynamic>>>{};
    for (final entry in _b05Specs.entries) {
      captured[entry.key] = await _readRows(db, entry.key, entry.value);
    }
    return B05BackupGraph(
      graphVersion: currentGraphVersion,
      tables: _sortedTables(captured),
    );
  }

  factory B05BackupGraph.fromJson(Object? raw) {
    if (raw is! Map) {
      throw BackupV10ValidationException(
        'b05_graph_shape',
        'Backup-v10 b05_graph must be an object.',
      );
    }
    final map = Map<String, dynamic>.from(raw);
    _rejectUnknownKeys(map, {'graph_version', 'tables'}, 'b05_graph');
    if (map['graph_version'] != currentGraphVersion) {
      throw BackupV10ValidationException(
        'b05_graph_version',
        'Unsupported Backup-v10 B05 graph version ${map['graph_version']}.',
      );
    }
    final rawTables = map['tables'];
    if (rawTables is! Map) {
      throw BackupV10ValidationException(
        'b05_tables_shape',
        'Backup-v10 b05_graph.tables must be an object.',
      );
    }
    final tables = <String, List<Map<String, dynamic>>>{};
    for (final entry in rawTables.entries) {
      final table = entry.key;
      if (table is! String || !_b05Specs.containsKey(table)) {
        throw BackupV10ValidationException(
          'unknown_b05_table',
          'Backup-v10 B05 graph contains an unknown table.',
        );
      }
      if (entry.value is! List) {
        throw BackupV10ValidationException(
          'b05_rows_shape',
          'Backup-v10 B05 table $table must contain a list.',
        );
      }
      tables[table] = [
        for (final row in entry.value as List) _copyRow(row, table),
      ];
    }
    if (tables.length != _b05Specs.length ||
        !tables.keys.toSet().containsAll(_b05Specs.keys)) {
      throw BackupV10ValidationException(
        'missing_b05_table',
        'Backup-v10 B05 graph must include every schema-v19 B05 table.',
      );
    }
    final graph = B05BackupGraph(
      graphVersion: currentGraphVersion,
      tables: _sortedTables(tables),
    );
    graph.validateStructure();
    return graph;
  }

  Map<String, dynamic> toJson() {
    validateStructure();
    return {
      'graph_version': graphVersion,
      'tables': {
        for (final table in _b05Specs.keys.toList()..sort())
          table: [for (final row in _rows(table)) _jsonRow(row)],
      },
    };
  }

  void validateStructure() {
    if (graphVersion != currentGraphVersion) {
      throw BackupV10ValidationException(
        'b05_graph_version',
        'Unsupported Backup-v10 B05 graph version $graphVersion.',
      );
    }
    if (tables.length != _b05Specs.length ||
        !tables.keys.toSet().containsAll(_b05Specs.keys)) {
      throw BackupV10ValidationException(
        'missing_b05_table',
        'Backup-v10 B05 graph must include every schema-v19 B05 table.',
      );
    }
    for (final entry in _b05Specs.entries) {
      final table = entry.key;
      final spec = entry.value;
      final seenIds = <String>{};
      final seenUnique = <String>{};
      for (final row in _rows(table)) {
        final allowed = spec.columns.toSet();
        if (row.keys.length != allowed.length ||
            row.keys.any((key) => !allowed.contains(key))) {
          throw BackupV10ValidationException(
            'unknown_or_missing_column',
            'Backup-v10 $table contains an unrecognised or missing typed column.',
          );
        }
        if (row.keys.any(_forbiddenKey)) {
          throw BackupV10ValidationException(
            'sensitive_payload',
            'Backup-v10 B05 graph contains a forbidden payload field.',
          );
        }
        final id = _requiredString(row, 'id', table);
        if (!seenIds.add(id)) {
          throw BackupV10ValidationException(
            'duplicate_id',
            'Backup-v10 $table contains duplicate portable ID $id.',
          );
        }
        _validateRequiredColumns(row, table, spec);
        _validateTypedColumns(row, table);
        _validateEnums(row, table);
        _validateDomains(row, table);
        final unique = spec.uniqueColumns.map((column) => row[column]);
        if (unique.every((value) => value != null)) {
          final encoded = unique.map(_keyValue).join('\u0000');
          if (!seenUnique.add(encoded)) {
            throw BackupV10ValidationException(
              'duplicate_unique_relationship',
              'Backup-v10 $table contains a duplicate unique relationship.',
            );
          }
        }
      }
    }
  }

  void validateAgainstTarget(AppDatabase db) {
    if (db.schemaVersion < 19) {
      throw BackupV10ValidationException(
        'target_schema_version',
        'Backup-v10 B05 graph requires schema v19.',
      );
    }
    validateStructure();
  }

  Future<void> restoreInto(AppDatabase db) async {
    validateAgainstTarget(db);
    await db.transaction(() => restoreIntoExistingTransaction(db));
  }

  Future<void> restoreIntoExistingTransaction(
    AppDatabase db, {
    BackupRestoreFailureInjector? failureInjector,
  }) async {
    validateAgainstTarget(db);
    if (failureInjector != null) {
      await failureInjector(
        BackupRestoreFailureStage.relationshipPrevalidation,
      );
    }
    await _deleteRows(db);
    if (failureInjector != null) {
      await failureInjector(BackupRestoreFailureStage.databaseMutation);
    }
    for (final table in _b05RestoreOrder) {
      final spec = _b05Specs[table]!;
      for (final row in _rows(table)) {
        await db.customStatement(
          'INSERT INTO $table (${spec.columns.join(', ')}) VALUES '
          '(${List.filled(spec.columns.length, '?').join(', ')})',
          [
            for (final column in spec.columns)
              _databaseValue(column, row[column]),
          ],
        );
      }
    }
    final foreignKeys = await db.customSelect('PRAGMA foreign_key_check').get();
    if (foreignKeys.isNotEmpty) {
      throw BackupV10ValidationException(
        'foreign_key_integrity',
        'Backup-v10 restore produced a foreign-key violation.',
      );
    }
    if (failureInjector != null) {
      await failureInjector(BackupRestoreFailureStage.beforeTransactionCommit);
    }
  }

  List<Map<String, dynamic>> _rows(String table) => tables[table] ?? const [];

  static Future<void> _deleteRows(AppDatabase db) async {
    for (final table in _b05DeleteOrder) {
      await db.customStatement('DELETE FROM $table');
    }
  }

  static Future<List<Map<String, dynamic>>> _readRows(
    AppDatabase db,
    String table,
    _B05TableSpec spec,
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

  static List<Map<String, dynamic>> _sortedRows(
    Iterable<Map<String, dynamic>> rows,
  ) {
    final sorted = [...rows];
    sorted.sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
    return sorted;
  }

  static Map<String, List<Map<String, dynamic>>> _sortedTables(
    Map<String, List<Map<String, dynamic>>> input,
  ) => {
    for (final table in input.keys.toList()..sort())
      table: _sortedRows(input[table] ?? const []),
  };

  static Map<String, dynamic> _copyRow(Object? raw, String table) {
    if (raw is! Map) {
      throw BackupV10ValidationException(
        'malformed_row',
        'Backup-v10 $table contains a non-object row.',
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

  static void _validateRequiredColumns(
    Map<String, dynamic> row,
    String table,
    _B05TableSpec spec,
  ) {
    for (final column in spec.columns) {
      if (!spec.nullableColumns.contains(column) && row[column] == null) {
        throw BackupV10ValidationException(
          'missing_required_field',
          'Backup-v10 $table.$column is required.',
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
      throw BackupV10ValidationException(
        'invalid_string',
        'Backup-v10 $table.$column must be a non-empty string.',
      );
    }
    return value;
  }

  static void _validateTypedColumns(Map<String, dynamic> row, String table) {
    for (final entry in row.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (_timestampColumns.contains(entry.key)) {
        if (_dateTime(value) == null) {
          throw BackupV10ValidationException(
            'invalid_timestamp',
            'Backup-v10 $table.${entry.key} must be a UTC timestamp.',
          );
        }
      } else if (_integerColumns.contains(entry.key)) {
        if (value is! int) {
          throw BackupV10ValidationException(
            'invalid_integer',
            'Backup-v10 $table.${entry.key} must be an integer.',
          );
        }
      } else if (_booleanColumns.contains(entry.key)) {
        if (value is! bool && !(value is int && (value == 0 || value == 1))) {
          throw BackupV10ValidationException(
            'invalid_boolean',
            'Backup-v10 $table.${entry.key} must be a boolean.',
          );
        }
      } else if (value is! String) {
        throw BackupV10ValidationException(
          'invalid_typed_column',
          'Backup-v10 $table.${entry.key} must be a typed string value.',
        );
      }
    }
  }

  static void _validateEnums(Map<String, dynamic> row, String table) {
    final states = <String>{
      'notStarted',
      'inProgress',
      'completed',
      'dismissed',
    };
    final downloadPreferences = <String>{'manual', 'ask', 'automatic'};
    final deletionChoices = <String>{'keep', 'delete', 'unset'};
    if (table == 'education_content_progress' &&
        !states.contains(row['state'])) {
      throw BackupV10ValidationException(
        'invalid_enum',
        'Backup-v10 education content state is unsupported.',
      );
    }
    if (table == 'media_pack_preferences') {
      if (!downloadPreferences.contains(row['download_preference'])) {
        throw BackupV10ValidationException(
          'invalid_enum',
          'Backup-v10 media download preference is unsupported.',
        );
      }
      final deletion = row['deletion_choice'];
      if (deletion != null && !deletionChoices.contains(deletion)) {
        throw BackupV10ValidationException(
          'invalid_enum',
          'Backup-v10 media deletion choice is unsupported.',
        );
      }
    }
  }

  static void _validateDomains(Map<String, dynamic> row, String table) {
    if (row.containsKey('user_id')) {
      _requiredString(row, 'user_id', table);
    }
    if (table == 'dashboard_module_preferences') {
      _requiredString(row, 'module_id', table);
    } else if (table == 'education_content_progress') {
      _requiredString(row, 'content_id', table);
      _requiredString(row, 'content_version', table);
    } else if (table == 'media_pack_preferences') {
      _requiredString(row, 'pack_id', table);
      _requiredString(row, 'manifest_identity', table);
    } else if (table == 'workout_playlist_preferences') {
      _requiredString(row, 'provider_id', table);
    }
    if (table == 'dashboard_module_preferences' &&
        row['ordinal'] is int &&
        row['ordinal'] < 0) {
      throw BackupV10ValidationException(
        'invalid_ordinal',
        'Backup-v10 dashboard module ordinal must be non-negative.',
      );
    }
    if (table == 'workout_playlist_preferences') {
      final reference = _requiredString(row, 'playlist_reference', table);
      if (reference.length > 512 || _controlCharacters.hasMatch(reference)) {
        throw BackupV10ValidationException(
          'invalid_playlist_reference',
          'Backup-v10 playlist reference is outside the portable contract.',
        );
      }
      final uri = Uri.tryParse(reference);
      if (uri == null ||
          uri.scheme.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.fragment.isNotEmpty) {
        throw BackupV10ValidationException(
          'invalid_playlist_reference',
          'Backup-v10 playlist reference must be a normalized provider URI.',
        );
      }
      if ({
        'file',
        'data',
        'javascript',
        'content',
      }.contains(uri.scheme.toLowerCase())) {
        throw BackupV10ValidationException(
          'unsafe_playlist_reference',
          'Backup-v10 playlist reference uses a disallowed URI scheme.',
        );
      }
    }
    if (table == 'media_pack_preferences') {
      final acknowledgement = row['content_acknowledgement'];
      if (acknowledgement is String &&
          _controlCharacters.hasMatch(acknowledgement)) {
        throw BackupV10ValidationException(
          'invalid_content_acknowledgement',
          'Backup-v10 media acknowledgement contains a control character.',
        );
      }
    }
  }

  static bool _forbiddenKey(String key) {
    const forbidden = {
      'prompt',
      'raw_payload',
      'image',
      'images',
      'health_payload',
      'medical_restriction',
      'credential',
      'credentials',
      'token',
      'secret',
      'password',
      'file_path',
      'path',
      'bytes',
      'cache',
      'availability',
      'verified_on_device',
      'temporary_progress',
    };
    return forbidden.contains(key.toLowerCase());
  }

  static String _keyValue(Object? value) => '$value';

  static DateTime? _dateTime(Object? value) {
    if (value is DateTime) return value.toUtc();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        value * Duration.millisecondsPerSecond,
        isUtc: true,
      );
    }
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }

  static void _rejectUnknownKeys(
    Map<String, dynamic> map,
    Set<String> allowed,
    String context,
  ) {
    if (map.keys.any((key) => !allowed.contains(key))) {
      throw BackupV10ValidationException(
        'unknown_$context',
        'Backup-v10 $context contains an unknown field.',
      );
    }
  }
}

class _B05TableSpec {
  final List<String> columns;
  final Set<String> nullableColumns;
  final List<String> uniqueColumns;

  const _B05TableSpec({
    required this.columns,
    this.nullableColumns = const {},
    required this.uniqueColumns,
  });
}

const _b05Specs = <String, _B05TableSpec>{
  'dashboard_module_preferences': _B05TableSpec(
    columns: [
      'id',
      'user_id',
      'module_id',
      'ordinal',
      'is_visible',
      'is_collapsed',
      'updated_at_utc',
    ],
    uniqueColumns: ['user_id', 'module_id'],
  ),
  'education_content_progress': _B05TableSpec(
    columns: [
      'id',
      'user_id',
      'content_id',
      'content_version',
      'state',
      'updated_at_utc',
    ],
    uniqueColumns: ['user_id', 'content_id'],
  ),
  'media_pack_preferences': _B05TableSpec(
    columns: [
      'id',
      'user_id',
      'pack_id',
      'manifest_identity',
      'last_known_installed_version',
      'download_preference',
      'deletion_choice',
      'content_acknowledgement',
      'updated_at_utc',
    ],
    nullableColumns: {
      'last_known_installed_version',
      'deletion_choice',
      'content_acknowledgement',
    },
    uniqueColumns: ['user_id', 'pack_id'],
  ),
  'workout_playlist_preferences': _B05TableSpec(
    columns: [
      'id',
      'user_id',
      'provider_id',
      'playlist_reference',
      'display_label',
      'updated_at_utc',
    ],
    nullableColumns: {'display_label'},
    uniqueColumns: ['user_id'],
  ),
};

const _b05RestoreOrder = [
  'dashboard_module_preferences',
  'education_content_progress',
  'media_pack_preferences',
  'workout_playlist_preferences',
];

const _b05DeleteOrder = [
  'workout_playlist_preferences',
  'media_pack_preferences',
  'education_content_progress',
  'dashboard_module_preferences',
];

const _timestampColumns = {'updated_at_utc'};
const _integerColumns = {'ordinal'};
const _booleanColumns = {'is_visible', 'is_collapsed'};
final _controlCharacters = RegExp(r'[\u0000-\u001f\u007f]');
