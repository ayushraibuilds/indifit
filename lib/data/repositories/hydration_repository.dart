import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/hydration_models.dart';

class HydrationRepository {
  static const String prefHydrationDailyGoalMl = 'pref_hydration_daily_goal_ml';
  static const String prefHydrationEntriesJson = 'pref_hydration_entries_json';

  // Legacy preference keys kept synchronized for backward compatibility
  static const String prefWaterLogged = 'water_logged';
  static const String prefWaterGoal = 'water_goal';
  static const String prefWaterGlassSize = 'water_glass_size';
  static const String prefWaterLastLoggedDate = 'water_last_logged_date';

  static const int defaultDailyGoalMl = 2500;
  static const int defaultGlassSizeMl = 250;
  static const int retentionWindowDays = 90;

  final AppDatabase? _db;
  final SharedPreferences? _prefsInstance;
  final Uuid _uuid;

  HydrationRepository(
    this._db, {
    SharedPreferences? prefs,
    Uuid? uuid,
  })  : _prefsInstance = prefs,
        _uuid = uuid ?? const Uuid();

  Future<SharedPreferences> _getPrefs() async =>
      _prefsInstance ?? await SharedPreferences.getInstance();

  /// Canonical date string from DateTime: YYYY-MM-DD
  static String formatLocalDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Returns current local date key
  static String currentLocalDateKey() => formatLocalDate(DateTime.now());

  /// Returns the daily hydration read model for the specified [localDate].
  ///
  /// Invariant:
  /// - If itemized entries exist in SharedPreferences for [localDate], their sum defines the daily total.
  /// - If no itemized entries exist in SharedPreferences, but the SQLite `daily_hydrations`
  ///   row has `totalMl > 0` (e.g. from legacy records, restore, or after 90-day retention pruning),
  ///   a synthetic entry (`source: 'summary'`) is projected to preserve total volume.
  Future<HydrationDailyReadModel> getDailyHydration(String localDate) async {
    final prefs = await _getPrefs();
    final entriesMap = _loadEntriesMap(prefs);
    final rawList = entriesMap[localDate];

    // Read SQLite row for durable summary & goal
    DailyHydration? record;
    if (_db != null) {
      try {
        record = await (_db.select(_db.dailyHydrations)
              ..where((tbl) => tbl.dateString.equals(localDate)))
            .getSingleOrNull();
      } catch (_) {
        // Database might be opening in test or edge conditions
      }
    }

    final goalMl = record?.goalMl ??
        prefs.getInt(prefHydrationDailyGoalMl) ??
        _goalMlFromLegacyGlasses(prefs);

    if (rawList != null && rawList.isNotEmpty) {
      final entries = rawList
          .map((e) => HydrationIntakeEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.loggedAtUtc.compareTo(b.loggedAtUtc));
      final totalMl = entries.fold<int>(0, (sum, e) => sum + e.amountMl);
      return HydrationDailyReadModel(
        localDate: localDate,
        totalMl: totalMl,
        goalMl: goalMl,
        entries: entries,
      );
    }

    // No itemized entries. Check if durable SQLite row has data
    if (record != null && record.totalMl > 0) {
      final summaryEntry = HydrationIntakeEntry(
        id: 'summary_$localDate',
        localDate: localDate,
        amountMl: record.totalMl,
        loggedAtUtc: record.updatedAt.toUtc(),
        source: 'summary',
      );
      return HydrationDailyReadModel(
        localDate: localDate,
        totalMl: record.totalMl,
        goalMl: record.goalMl,
        entries: [summaryEntry],
      );
    }

    // Check legacy fallback for today if SQLite and itemized entries were empty
    final legacyToday = prefs.getString(prefWaterLastLoggedDate);
    if (record == null && legacyToday == localDate) {
      final legacyLoggedGlasses = prefs.getInt(prefWaterLogged) ?? 0;
      final glassSize = prefs.getInt(prefWaterGlassSize) ?? defaultGlassSizeMl;
      final legacyMl = legacyLoggedGlasses * glassSize;
      if (legacyMl > 0) {
        final summaryEntry = HydrationIntakeEntry(
          id: 'legacy_$localDate',
          localDate: localDate,
          amountMl: legacyMl,
          loggedAtUtc: DateTime.now().toUtc(),
          source: 'summary',
        );
        return HydrationDailyReadModel(
          localDate: localDate,
          totalMl: legacyMl,
          goalMl: goalMl,
          entries: [summaryEntry],
        );
      }
    }

    return HydrationDailyReadModel(
      localDate: localDate,
      totalMl: 0,
      goalMl: goalMl,
      entries: const [],
    );
  }

  /// Logs a single hydration intake event.
  ///
  /// Sole writer to `_db.dailyHydrations`.
  /// Prunes entries older than [retentionWindowDays] days.
  /// Synchronizes legacy preference mirrors.
  Future<HydrationIntakeEntry> logIntake({
    required String localDate,
    required int amountMl,
    DateTime? loggedAtUtc,
    String source = 'manual',
    String? containerType,
  }) async {
    if (amountMl <= 0) {
      throw ArgumentError.value(
        amountMl,
        'amountMl',
        'Amount must be greater than zero.',
      );
    }

    final entry = HydrationIntakeEntry(
      id: _uuid.v4(),
      localDate: localDate,
      amountMl: amountMl,
      loggedAtUtc: loggedAtUtc?.toUtc() ?? DateTime.now().toUtc(),
      source: source,
      containerType: containerType,
    );

    final prefs = await _getPrefs();
    final entriesMap = _loadEntriesMap(prefs);

    // 90-day retention prune
    _pruneOldEntries(entriesMap);

    final dayList = (entriesMap[localDate] ??= <Map<String, dynamic>>[]);
    dayList.add(entry.toJson());

    await prefs.setString(prefHydrationEntriesJson, jsonEncode(entriesMap));

    // Calculate updated totalMl
    final totalMl = dayList.fold<int>(
      0,
      (sum, item) => sum + ((item['amountMl'] as num?)?.toInt() ?? 0),
    );

    final goalMl = prefs.getInt(prefHydrationDailyGoalMl) ??
        _goalMlFromLegacyGlasses(prefs);

    // Upsert SQLite daily_hydrations row atomically
    if (_db != null) {
      await _db.into(_db.dailyHydrations).insert(
        DailyHydrationsCompanion.insert(
          dateString: localDate,
          totalMl: totalMl,
          goalMl: goalMl,
          updatedAt: Value(DateTime.now().toUtc()),
        ),
        mode: InsertMode.insertOrReplace,
      );
    }

    // Sync legacy mirror
    await _syncLegacyMirror(prefs, localDate, totalMl, goalMl);

    return entry;
  }

  /// Deletes an intake entry by [entryId] on [localDate].
  Future<void> deleteIntake({
    required String localDate,
    required String entryId,
  }) async {
    final prefs = await _getPrefs();
    final entriesMap = _loadEntriesMap(prefs);
    final dayList = entriesMap[localDate];
    if (dayList == null) return;

    dayList.removeWhere((item) => item['id'] == entryId);
    if (dayList.isEmpty) {
      entriesMap.remove(localDate);
    }
    await prefs.setString(prefHydrationEntriesJson, jsonEncode(entriesMap));

    final totalMl = dayList.fold<int>(
      0,
      (sum, item) => sum + ((item['amountMl'] as num?)?.toInt() ?? 0),
    );

    final goalMl = prefs.getInt(prefHydrationDailyGoalMl) ??
        _goalMlFromLegacyGlasses(prefs);

    if (_db != null) {
      await _db.into(_db.dailyHydrations).insert(
        DailyHydrationsCompanion.insert(
          dateString: localDate,
          totalMl: totalMl,
          goalMl: goalMl,
          updatedAt: Value(DateTime.now().toUtc()),
        ),
        mode: InsertMode.insertOrReplace,
      );
    }

    await _syncLegacyMirror(prefs, localDate, totalMl, goalMl);
  }

  /// Edits an intake entry's amount.
  Future<void> editIntake({
    required String localDate,
    required String entryId,
    required int newAmountMl,
  }) async {
    if (newAmountMl <= 0) {
      throw ArgumentError.value(
        newAmountMl,
        'newAmountMl',
        'Amount must be greater than zero.',
      );
    }

    final prefs = await _getPrefs();
    final entriesMap = _loadEntriesMap(prefs);
    final dayList = entriesMap[localDate];
    if (dayList == null) return;

    final index = dayList.indexWhere((item) => item['id'] == entryId);
    if (index == -1) return;

    final existing = Map<String, dynamic>.from(dayList[index]);
    existing['amountMl'] = newAmountMl;
    dayList[index] = existing;

    await prefs.setString(prefHydrationEntriesJson, jsonEncode(entriesMap));

    final totalMl = dayList.fold<int>(
      0,
      (sum, item) => sum + ((item['amountMl'] as num?)?.toInt() ?? 0),
    );

    final goalMl = prefs.getInt(prefHydrationDailyGoalMl) ??
        _goalMlFromLegacyGlasses(prefs);

    if (_db != null) {
      await _db.into(_db.dailyHydrations).insert(
        DailyHydrationsCompanion.insert(
          dateString: localDate,
          totalMl: totalMl,
          goalMl: goalMl,
          updatedAt: Value(DateTime.now().toUtc()),
        ),
        mode: InsertMode.insertOrReplace,
      );
    }

    await _syncLegacyMirror(prefs, localDate, totalMl, goalMl);
  }

  /// Sets the daily hydration goal in ml.
  ///
  /// Reconciles `pref_hydration_daily_goal_ml` and legacy `water_goal` using live glass size:
  /// `water_goal = (goalMl / currentGlassSize).round()`.
  Future<void> setDailyGoal({required int goalMl, String? forDate}) async {
    if (goalMl <= 0) {
      throw ArgumentError.value(
        goalMl,
        'goalMl',
        'Goal must be greater than zero.',
      );
    }

    final prefs = await _getPrefs();
    await prefs.setInt(prefHydrationDailyGoalMl, goalMl);

    // Micro-correction 1: use live glass size at call time!
    final glassSize = prefs.getInt(prefWaterGlassSize) ?? defaultGlassSizeMl;
    final validGlassSize = glassSize > 0 ? glassSize : defaultGlassSizeMl;
    final glasses = (goalMl / validGlassSize).round().clamp(1, 100);
    await prefs.setInt(prefWaterGoal, glasses);

    if (_db != null) {
      final targetDate = forDate ?? currentLocalDateKey();
      final existing = await (_db.select(_db.dailyHydrations)
            ..where((tbl) => tbl.dateString.equals(targetDate)))
          .getSingleOrNull();

      final totalMl = existing?.totalMl ?? 0;
      await _db.into(_db.dailyHydrations).insert(
        DailyHydrationsCompanion.insert(
          dateString: targetDate,
          totalMl: totalMl,
          goalMl: goalMl,
          updatedAt: Value(DateTime.now().toUtc()),
        ),
        mode: InsertMode.insertOrReplace,
      );
    }
  }

  /// Updates glass size in preferences and reconciles `water_goal` with canonical goalMl.
  Future<void> updateGlassSize(int newGlassSize) async {
    if (newGlassSize <= 0) {
      throw ArgumentError.value(
        newGlassSize,
        'newGlassSize',
        'Glass size must be positive.',
      );
    }
    final prefs = await _getPrefs();
    await prefs.setInt(prefWaterGlassSize, newGlassSize);

    // Reconcile glasses count using live newGlassSize
    final goalMl = prefs.getInt(prefHydrationDailyGoalMl) ?? defaultDailyGoalMl;
    final glasses = (goalMl / newGlassSize).round().clamp(1, 100);
    await prefs.setInt(prefWaterGoal, glasses);

    final todayStr = currentLocalDateKey();
    final todayHydration = await getDailyHydration(todayStr);
    final loggedGlasses = (todayHydration.totalMl / newGlassSize).round();
    await prefs.setInt(prefWaterLogged, loggedGlasses);
  }

  /// Clears all hydration data (both SQLite rows and SharedPreferences keys).
  Future<void> clearAllData() async {
    if (_db != null) {
      try {
        await _db.delete(_db.dailyHydrations).go();
      } catch (_) {}
    }

    final prefs = await _getPrefs();
    await prefs.remove(prefHydrationEntriesJson);
    await prefs.remove(prefHydrationDailyGoalMl);
    await prefs.remove(prefWaterLogged);
    await prefs.remove(prefWaterGoal);
    await prefs.remove(prefWaterGlassSize);
    await prefs.remove(prefWaterLastLoggedDate);
  }

  // --- Internal Helpers ---

  int _goalMlFromLegacyGlasses(SharedPreferences prefs) {
    if (!prefs.containsKey(prefWaterGoal)) {
      return defaultDailyGoalMl;
    }
    final glasses = prefs.getInt(prefWaterGoal) ?? 8;
    final glassSize = prefs.getInt(prefWaterGlassSize) ?? defaultGlassSizeMl;
    return glasses * glassSize;
  }

  Map<String, List<dynamic>> _loadEntriesMap(SharedPreferences prefs) {
    final rawJson = prefs.getString(prefHydrationEntriesJson);
    if (rawJson == null || rawJson.isEmpty) return <String, List<dynamic>>{};
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        return decoded.map(
          (key, value) => MapEntry(
            key,
            value is List ? List<dynamic>.from(value) : <dynamic>[],
          ),
        );
      }
    } catch (_) {}
    return <String, List<dynamic>>{};
  }

  void _pruneOldEntries(Map<String, List<dynamic>> entriesMap) {
    if (entriesMap.isEmpty) return;
    final cutoff = DateTime.now().subtract(
      const Duration(days: retentionWindowDays),
    );
    final cutoffKey = formatLocalDate(cutoff);

    entriesMap.removeWhere((dateKey, _) => dateKey.compareTo(cutoffKey) < 0);
  }

  Future<void> _syncLegacyMirror(
    SharedPreferences prefs,
    String localDate,
    int totalMl,
    int goalMl,
  ) async {
    final todayStr = currentLocalDateKey();
    if (localDate == todayStr) {
      final glassSize = prefs.getInt(prefWaterGlassSize) ?? defaultGlassSizeMl;
      final validGlassSize = glassSize > 0 ? glassSize : defaultGlassSizeMl;
      final loggedGlasses = (totalMl / validGlassSize).round().clamp(0, 100);
      final goalGlasses = (goalMl / validGlassSize).round().clamp(1, 100);

      await prefs.setInt(prefWaterLogged, loggedGlasses);
      await prefs.setInt(prefWaterGoal, goalGlasses);
      await prefs.setString(prefWaterLastLoggedDate, todayStr);
    }
  }
}
