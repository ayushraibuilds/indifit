import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/backup/backup_file_adapter.dart';
import '../../core/backup/backup_schema.dart';
import '../../core/backup/backup_v10.dart';
import '../../core/backup/backup_v8.dart';
import '../../core/backup/backup_v9.dart';
import '../../core/di/providers.dart';
import '../../core/privacy/privacy_policy.dart';
import '../../core/services/crash_reporting_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/csv_exporter.dart';

class SettingsState {
  final bool remindWorkout;
  final bool remindMeals;
  final bool remindWater;
  final bool remindEvening;
  final bool remindWeekly;
  final bool quietHoursEnabled;
  final int quietHoursStart;
  final int quietHoursEnd;
  final bool offlineOnly;
  final bool crashReportingEnabled;
  final bool loading;
  final int waterGoal;
  final int glassSize;

  const SettingsState({
    this.remindWorkout = false,
    this.remindMeals = false,
    this.remindWater = false,
    this.remindEvening = false,
    this.remindWeekly = false,
    this.quietHoursEnabled = true,
    this.quietHoursStart = 22,
    this.quietHoursEnd = 7,
    this.offlineOnly = false,
    this.crashReportingEnabled = false,
    this.loading = true,
    this.waterGoal = 8,
    this.glassSize = 250,
  });

  SettingsState copyWith({
    bool? remindWorkout,
    bool? remindMeals,
    bool? remindWater,
    bool? remindEvening,
    bool? remindWeekly,
    bool? quietHoursEnabled,
    int? quietHoursStart,
    int? quietHoursEnd,
    bool? offlineOnly,
    bool? crashReportingEnabled,
    bool? loading,
    int? waterGoal,
    int? glassSize,
  }) {
    return SettingsState(
      remindWorkout: remindWorkout ?? this.remindWorkout,
      remindMeals: remindMeals ?? this.remindMeals,
      remindWater: remindWater ?? this.remindWater,
      remindEvening: remindEvening ?? this.remindEvening,
      remindWeekly: remindWeekly ?? this.remindWeekly,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      offlineOnly: offlineOnly ?? this.offlineOnly,
      crashReportingEnabled:
          crashReportingEnabled ?? this.crashReportingEnabled,
      loading: loading ?? this.loading,
      waterGoal: waterGoal ?? this.waterGoal,
      glassSize: glassSize ?? this.glassSize,
    );
  }
}

class SettingsController extends StateNotifier<SettingsState> {
  final Ref _ref;

  SettingsController(this._ref) : super(const SettingsState()) {
    loadPreferences();
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      remindWorkout:
          prefs.getBool(NotificationService.prefRemindWorkout) ?? false,
      remindMeals: prefs.getBool(NotificationService.prefRemindMeals) ?? false,
      remindWater: prefs.getBool(NotificationService.prefRemindWater) ?? false,
      remindEvening:
          prefs.getBool(NotificationService.prefRemindEvening) ?? false,
      remindWeekly:
          prefs.getBool(NotificationService.prefRemindWeekly) ?? false,
      quietHoursEnabled:
          prefs.getBool(NotificationService.prefQuietHoursEnabled) ?? true,
      quietHoursStart:
          prefs.getInt(NotificationService.prefQuietHoursStart) ?? 22,
      quietHoursEnd: prefs.getInt(NotificationService.prefQuietHoursEnd) ?? 7,
      offlineOnly: prefs.getBool('offline_only') ?? false,
      crashReportingEnabled:
          prefs.getBool(CrashReportingService.prefCrashReportingEnabled) ??
          false,
      waterGoal: prefs.getInt('water_goal') ?? 8,
      glassSize: prefs.getInt('water_glass_size') ?? 250,
      loading: false,
    );
  }

  Future<void> toggleReminder(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    await NotificationService.scheduleAllReminders(_ref.read(databaseProvider));
    await loadPreferences();
  }

  Future<void> updateQuietHours({bool? enabled, int? start, int? end}) async {
    final prefs = await SharedPreferences.getInstance();
    if (enabled != null) {
      await prefs.setBool(NotificationService.prefQuietHoursEnabled, enabled);
    }
    if (start != null) {
      await prefs.setInt(NotificationService.prefQuietHoursStart, start);
    }
    if (end != null) {
      await prefs.setInt(NotificationService.prefQuietHoursEnd, end);
    }
    await NotificationService.scheduleAllReminders(_ref.read(databaseProvider));
    await loadPreferences();
  }

  Future<void> toggleOfflineOnly(bool value) async {
    await _ref.read(privacyPolicyProvider.notifier).setOfflineOnly(value);
    if (value) {
      await CrashReportingService.setEnabled(false);
    }
    state = state.copyWith(
      offlineOnly: value,
      crashReportingEnabled: _ref
          .read(privacyPolicyProvider)
          .isTelemetryAllowed,
    );
  }

  Future<void> toggleCrashReporting(bool value) async {
    await _ref.read(privacyPolicyProvider.notifier).setTelemetryEnabled(value);
    final telemetryAllowed = _ref
        .read(privacyPolicyProvider)
        .isTelemetryAllowed;
    await CrashReportingService.setEnabled(telemetryAllowed);
    state = state.copyWith(crashReportingEnabled: telemetryAllowed);
  }

  Future<void> updateWaterGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_goal', goal);
    await _ref.read(waterProvider.notifier).updateGoal(goal);
    state = state.copyWith(waterGoal: goal);
  }

  Future<void> updateGlassSize(int size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_glass_size', size);
    await _ref.read(waterProvider.notifier).updateGlassSize(size);
    state = state.copyWith(glassSize: size);
  }

  Future<String?> performExport(String password) async {
    state = state.copyWith(loading: true);
    File? tempFile;
    try {
      final db = _ref.read(databaseProvider);
      final prefs = await SharedPreferences.getInstance();
      final backupData = await BackupV10Data.createFromDatabase(db, prefs);

      final envelopeJson = BackupFileAdapter.exportV10ToEnvelopeJson(
        data: backupData,
        password: password,
      );

      final tempDir = await getTemporaryDirectory();
      final dateStr = DateTime.now().toIso8601String().split('T').first;
      tempFile = File('${tempDir.path}/indifit_backup_$dateStr.indifit-backup');
      await tempFile.writeAsString(envelopeJson);

      final xFile = XFile(tempFile.path);
      await Share.shareXFiles([
        xFile,
      ], subject: 'IndiFit Health Backup (.indifit-backup)');

      return null;
    } catch (e) {
      return 'Failed to export backup: $e';
    } finally {
      await BackupFileAdapter.cleanupTempFile(tempFile);
      state = state.copyWith(loading: false);
    }
  }

  bool _isRestoring = false;

  Future<void> performRestore(Map<String, dynamic> data) async {
    if (_isRestoring) {
      throw StateError('Restore operation is already in progress.');
    }
    _isRestoring = true;
    state = state.copyWith(loading: true);
    try {
      // 1. Validate and parse payload before any database or preference mutations.
      final version = (data['version'] as num?)?.toInt() ?? 0;
      final db = _ref.read(databaseProvider);
      final prefs = await SharedPreferences.getInstance();
      if (version >= BackupV10Data.currentVersion) {
        await BackupV10Data.fromJson(data).restoreToDatabase(db, prefs);
      } else if (version >= BackupV9Data.currentVersion) {
        await BackupV9Data.fromJson(data).restoreToDatabase(db, prefs);
      } else if (version >= BackupV8Data.currentVersion) {
        await BackupV8Data.fromJson(data).restoreToDatabase(db, prefs);
      } else {
        await BackupData.fromJson(data).restoreToDatabase(db, prefs);
      }

      // 2. Refresh providers post-commit on successful completion
      _ref.invalidate(userProfileProvider);
      await _ref.read(waterProvider.notifier).loadState();
    } catch (e) {
      rethrow;
    } finally {
      _isRestoring = false;
      state = state.copyWith(loading: false);
    }
  }

  Future<void> exportCsvData() async {
    final db = _ref.read(databaseProvider);
    final foodLogs = await db.select(db.foodLogs).get();
    final foodCsv = CsvExporter.exportFoodLogsToCsv(foodLogs);

    final sessions = await db.select(db.workoutSessions).get();
    final sets = await db.select(db.workoutSets).get();
    final workoutCsv = CsvExporter.exportWorkoutSessionsToCsv(sessions, sets);

    final fullCsv =
        '=== FOOD LOGS ===\n$foodCsv\n\n=== WORKOUT SESSIONS ===\n$workoutCsv';
    await Clipboard.setData(ClipboardData(text: fullCsv));
  }

  Future<void> deleteAllData() async {
    final db = _ref.read(databaseProvider);
    await db.delete(db.foodLogs).go();
    await db.delete(db.foodItems).go();
    await db.delete(db.workoutSets).go();
    await db.delete(db.workoutSessions).go();
    await db.delete(db.bodyMeasurements).go();
    await db.delete(db.routineExercises).go();
    await db.delete(db.routineDays).go();
    await db.delete(db.workoutRoutines).go();
  }
}

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsState>((ref) {
      return SettingsController(ref);
    });
