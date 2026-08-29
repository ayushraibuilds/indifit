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
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/privacy/privacy_policy.dart';
import '../../core/services/crash_reporting_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/csv_exporter.dart';

int _boundedPreference(
  int? value, {
  required int min,
  required int max,
  required int fallback,
}) => value != null && value >= min && value <= max ? value : fallback;

class SettingsState {
  final bool remindWorkout;
  final bool remindMeals;
  final bool remindWater;
  final bool remindEvening;
  final bool remindWeekly;
  final bool quietHoursEnabled;
  final int quietHoursStart;
  final int quietHoursEnd;
  final List<int> workoutReminderDays;
  final int workoutReminderHour;
  final int workoutReminderMinute;
  final int lunchReminderHour;
  final int lunchReminderMinute;
  final int dinnerReminderHour;
  final int dinnerReminderMinute;
  final int dailyLoggingReminderHour;
  final int dailyLoggingReminderMinute;
  final int weeklyProgressDay;
  final int weeklyProgressHour;
  final int weeklyProgressMinute;
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
    this.workoutReminderDays = NotificationService.defaultWorkoutReminderDays,
    this.workoutReminderHour = NotificationService.defaultWorkoutReminderHour,
    this.workoutReminderMinute =
        NotificationService.defaultWorkoutReminderMinute,
    this.lunchReminderHour = NotificationService.defaultLunchReminderHour,
    this.lunchReminderMinute = NotificationService.defaultLunchReminderMinute,
    this.dinnerReminderHour = NotificationService.defaultDinnerReminderHour,
    this.dinnerReminderMinute = NotificationService.defaultDinnerReminderMinute,
    this.dailyLoggingReminderHour =
        NotificationService.defaultDailyLoggingReminderHour,
    this.dailyLoggingReminderMinute =
        NotificationService.defaultDailyLoggingReminderMinute,
    this.weeklyProgressDay = NotificationService.defaultWeeklyProgressDay,
    this.weeklyProgressHour = NotificationService.defaultWeeklyProgressHour,
    this.weeklyProgressMinute = NotificationService.defaultWeeklyProgressMinute,
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
    List<int>? workoutReminderDays,
    int? workoutReminderHour,
    int? workoutReminderMinute,
    int? lunchReminderHour,
    int? lunchReminderMinute,
    int? dinnerReminderHour,
    int? dinnerReminderMinute,
    int? dailyLoggingReminderHour,
    int? dailyLoggingReminderMinute,
    int? weeklyProgressDay,
    int? weeklyProgressHour,
    int? weeklyProgressMinute,
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
      workoutReminderDays: workoutReminderDays ?? this.workoutReminderDays,
      workoutReminderHour: workoutReminderHour ?? this.workoutReminderHour,
      workoutReminderMinute:
          workoutReminderMinute ?? this.workoutReminderMinute,
      lunchReminderHour: lunchReminderHour ?? this.lunchReminderHour,
      lunchReminderMinute: lunchReminderMinute ?? this.lunchReminderMinute,
      dinnerReminderHour: dinnerReminderHour ?? this.dinnerReminderHour,
      dinnerReminderMinute: dinnerReminderMinute ?? this.dinnerReminderMinute,
      dailyLoggingReminderHour:
          dailyLoggingReminderHour ?? this.dailyLoggingReminderHour,
      dailyLoggingReminderMinute:
          dailyLoggingReminderMinute ?? this.dailyLoggingReminderMinute,
      weeklyProgressDay: weeklyProgressDay ?? this.weeklyProgressDay,
      weeklyProgressHour: weeklyProgressHour ?? this.weeklyProgressHour,
      weeklyProgressMinute: weeklyProgressMinute ?? this.weeklyProgressMinute,
      offlineOnly: offlineOnly ?? this.offlineOnly,
      crashReportingEnabled:
          crashReportingEnabled ?? this.crashReportingEnabled,
      loading: loading ?? this.loading,
      waterGoal: waterGoal ?? this.waterGoal,
      glassSize: glassSize ?? this.glassSize,
    );
  }
}

enum SettingsExportStatus { shared, cancelled, unavailable, failed }

/// Result of creating the portable backup file and handing it to a destination
/// through the platform share sheet.
class SettingsExportResult {
  final SettingsExportStatus status;
  final String? message;

  const SettingsExportResult(this.status, {this.message});

  bool get isShared => status == SettingsExportStatus.shared;
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
      workoutReminderDays:
          NotificationService.workoutReminderDaysFromPreferences(prefs),
      workoutReminderHour: _boundedPreference(
        prefs.getInt(NotificationService.prefWorkoutReminderHour),
        min: 0,
        max: 23,
        fallback: NotificationService.defaultWorkoutReminderHour,
      ),
      workoutReminderMinute: _boundedPreference(
        prefs.getInt(NotificationService.prefWorkoutReminderMinute),
        min: 0,
        max: 59,
        fallback: NotificationService.defaultWorkoutReminderMinute,
      ),
      lunchReminderHour: _boundedPreference(
        prefs.getInt(NotificationService.prefLunchReminderHour),
        min: 0,
        max: 23,
        fallback: NotificationService.defaultLunchReminderHour,
      ),
      lunchReminderMinute: _boundedPreference(
        prefs.getInt(NotificationService.prefLunchReminderMinute),
        min: 0,
        max: 59,
        fallback: NotificationService.defaultLunchReminderMinute,
      ),
      dinnerReminderHour: _boundedPreference(
        prefs.getInt(NotificationService.prefDinnerReminderHour),
        min: 0,
        max: 23,
        fallback: NotificationService.defaultDinnerReminderHour,
      ),
      dinnerReminderMinute: _boundedPreference(
        prefs.getInt(NotificationService.prefDinnerReminderMinute),
        min: 0,
        max: 59,
        fallback: NotificationService.defaultDinnerReminderMinute,
      ),
      dailyLoggingReminderHour: _boundedPreference(
        prefs.getInt(NotificationService.prefDailyLoggingReminderHour),
        min: 0,
        max: 23,
        fallback: NotificationService.defaultDailyLoggingReminderHour,
      ),
      dailyLoggingReminderMinute: _boundedPreference(
        prefs.getInt(NotificationService.prefDailyLoggingReminderMinute),
        min: 0,
        max: 59,
        fallback: NotificationService.defaultDailyLoggingReminderMinute,
      ),
      weeklyProgressDay: _boundedPreference(
        prefs.getInt(NotificationService.prefWeeklyProgressDay),
        min: DateTime.monday,
        max: DateTime.sunday,
        fallback: NotificationService.defaultWeeklyProgressDay,
      ),
      weeklyProgressHour: _boundedPreference(
        prefs.getInt(NotificationService.prefWeeklyProgressHour),
        min: 0,
        max: 23,
        fallback: NotificationService.defaultWeeklyProgressHour,
      ),
      weeklyProgressMinute: _boundedPreference(
        prefs.getInt(NotificationService.prefWeeklyProgressMinute),
        min: 0,
        max: 59,
        fallback: NotificationService.defaultWeeklyProgressMinute,
      ),
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

  Future<void> updateWorkoutReminderSchedule({
    required List<int> days,
    required int hour,
    required int minute,
  }) async {
    final normalizedDays = days.toSet().toList()..sort();
    if (normalizedDays.isEmpty ||
        normalizedDays.any(
          (day) => day < DateTime.monday || day > DateTime.sunday,
        )) {
      throw ArgumentError.value(days, 'days', 'Select at least one valid day.');
    }
    _validateTime(hour, minute);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      NotificationService.prefWorkoutReminderDays,
      normalizedDays.map((day) => '$day').toList(),
    );
    await prefs.setInt(NotificationService.prefWorkoutReminderHour, hour);
    await prefs.setInt(NotificationService.prefWorkoutReminderMinute, minute);
    await _rescheduleAndReload();
  }

  Future<void> updateMealReminderSchedule({
    required int lunchHour,
    required int lunchMinute,
    required int dinnerHour,
    required int dinnerMinute,
  }) async {
    _validateTime(lunchHour, lunchMinute);
    _validateTime(dinnerHour, dinnerMinute);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(NotificationService.prefLunchReminderHour, lunchHour);
    await prefs.setInt(
      NotificationService.prefLunchReminderMinute,
      lunchMinute,
    );
    await prefs.setInt(NotificationService.prefDinnerReminderHour, dinnerHour);
    await prefs.setInt(
      NotificationService.prefDinnerReminderMinute,
      dinnerMinute,
    );
    await _rescheduleAndReload();
  }

  Future<void> updateDailyLoggingReminderSchedule({
    required int hour,
    required int minute,
  }) async {
    _validateTime(hour, minute);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(NotificationService.prefDailyLoggingReminderHour, hour);
    await prefs.setInt(
      NotificationService.prefDailyLoggingReminderMinute,
      minute,
    );
    await _rescheduleAndReload();
  }

  Future<void> updateWeeklyProgressSchedule({
    required int day,
    required int hour,
    required int minute,
  }) async {
    if (day < DateTime.monday || day > DateTime.sunday) {
      throw ArgumentError.value(day, 'day', 'Use a valid weekday.');
    }
    _validateTime(hour, minute);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(NotificationService.prefWeeklyProgressDay, day);
    await prefs.setInt(NotificationService.prefWeeklyProgressHour, hour);
    await prefs.setInt(NotificationService.prefWeeklyProgressMinute, minute);
    await _rescheduleAndReload();
  }

  Future<void> _rescheduleAndReload() async {
    await NotificationService.scheduleAllReminders(_ref.read(databaseProvider));
    await loadPreferences();
  }

  static void _validateTime(int hour, int minute) {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Use a valid local time.');
    }
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

  Future<SettingsExportResult> performExport(String password) async {
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
      await tempFile.writeAsString(envelopeJson, flush: true);

      final xFile = XFile(tempFile.path);
      final shareResult = await Share.shareXFiles([
        xFile,
      ], subject: 'IndiFit backup (.indifit-backup)');

      return exportResultForShareStatus(shareResult.status);
    } catch (_) {
      return SettingsExportResult(
        SettingsExportStatus.failed,
        message: ProductFailurePresentation.fromCode(
          'backup_export_failed',
        ).message,
      );
    } finally {
      await BackupFileAdapter.cleanupTempFile(tempFile);
      state = state.copyWith(loading: false);
    }
  }

  static SettingsExportResult exportResultForShareStatus(
    ShareResultStatus status,
  ) => switch (status) {
    ShareResultStatus.success => const SettingsExportResult(
      SettingsExportStatus.shared,
    ),
    ShareResultStatus.dismissed => const SettingsExportResult(
      SettingsExportStatus.cancelled,
      message: 'No backup was shared.',
    ),
    ShareResultStatus.unavailable => const SettingsExportResult(
      SettingsExportStatus.unavailable,
      message: 'Sharing is unavailable on this device. No backup was shared.',
    ),
  };

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

  Future<String?> exportCsvData() async {
    try {
      final db = _ref.read(databaseProvider);
      final foodLogs = await db.select(db.foodLogs).get();
      final foodCsv = CsvExporter.exportFoodLogsToCsv(foodLogs);

      final sessions = await db.select(db.workoutSessions).get();
      final sets = await db.select(db.workoutSets).get();
      final workoutCsv = CsvExporter.exportWorkoutSessionsToCsv(sessions, sets);

      final fullCsv =
          '=== FOOD LOGS ===\n$foodCsv\n\n=== WORKOUT SESSIONS ===\n$workoutCsv';
      await Clipboard.setData(ClipboardData(text: fullCsv));
      return null;
    } catch (_) {
      return ProductFailurePresentation.fromCode('csv_export_failed').message;
    }
  }
}

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsState>((ref) {
      return SettingsController(ref);
    });
