import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_preferences_keys.dart';
import '../../core/di/core_providers.dart';
import '../../data/database/app_database.dart';

/// When the "Export your data" reminder is due after a saved workout (FT-1).
///
/// IndiFit has no OS backup and no phone-to-phone transfer (N14-02), so a
/// manual export is the only copy that survives a new phone or a reset.
abstract final class ExportReminderPolicy {
  static const workoutsSinceExport = 10;
  static const daysSinceExport = 30;

  /// Without any export yet, the user must have logged on this many days.
  static const minLoggedDaysWithoutExport = 7;
  static const snooze = Duration(days: 30);

  static bool isDue({
    required DateTime now,
    required DateTime? lastExportAt,
    required DateTime? snoozedUntil,
    required int workoutsSinceReference,
    required DateTime? referenceStart,
    required int loggedDays,
  }) {
    if (snoozedUntil != null && now.isBefore(snoozedUntil)) return false;
    if (lastExportAt == null && loggedDays < minLoggedDaysWithoutExport) {
      return false;
    }
    final since = lastExportAt ?? referenceStart;
    if (workoutsSinceReference >= workoutsSinceExport) return true;
    return since != null && now.difference(since).inDays >= daysSinceExport;
  }
}

class DataExportStatus {
  const DataExportStatus({this.lastExportAt, this.snoozedUntil});

  final DateTime? lastExportAt;
  final DateTime? snoozedUntil;
}

/// Last successful export and the reminder snooze, kept in prefs only.
class DataExportStatusNotifier extends StateNotifier<DataExportStatus> {
  DataExportStatusNotifier(this._prefs) : super(_read(_prefs));

  final SharedPreferences? _prefs;

  static DataExportStatus _read(SharedPreferences? prefs) => DataExportStatus(
    lastExportAt: _date(prefs?.getString(AppPreferenceKeys.lastDataExportAt)),
    snoozedUntil: _date(
      prefs?.getString(AppPreferenceKeys.dataExportReminderSnoozedUntil),
    ),
  );

  static DateTime? _date(String? value) =>
      value == null ? null : DateTime.tryParse(value);

  Future<SharedPreferences> _store() async =>
      _prefs ?? await SharedPreferences.getInstance();

  /// Call only after the share sheet reports success.
  Future<void> recordSuccessfulExport([DateTime? at]) async {
    final when = at ?? DateTime.now();
    final prefs = await _store();
    await prefs.setString(
      AppPreferenceKeys.lastDataExportAt,
      when.toIso8601String(),
    );
    state = DataExportStatus(
      lastExportAt: when,
      snoozedUntil: state.snoozedUntil,
    );
  }

  /// "Later": hides the reminder for [ExportReminderPolicy.snooze].
  Future<void> snoozeReminder([DateTime? now]) async {
    final until = (now ?? DateTime.now()).add(ExportReminderPolicy.snooze);
    final prefs = await _store();
    await prefs.setString(
      AppPreferenceKeys.dataExportReminderSnoozedUntil,
      until.toIso8601String(),
    );
    state = DataExportStatus(
      lastExportAt: state.lastExportAt,
      snoozedUntil: until,
    );
  }
}

final dataExportStatusProvider =
    StateNotifierProvider<DataExportStatusNotifier, DataExportStatus>(
      (ref) => DataExportStatusNotifier(
        sharedPreferencesOrNull(() => ref.watch(sharedPreferencesProvider)),
      ),
    );

/// Whether the reminder card should show now. Recomputed when the export
/// status changes, so exporting or snoozing hides it.
final exportReminderDueProvider = FutureProvider.autoDispose<bool>((ref) async {
  final status = ref.watch(dataExportStatusProvider);
  final now = DateTime.now();
  if (status.snoozedUntil != null && now.isBefore(status.snoozedUntil!)) {
    return false;
  }
  final activity = await readExportReminderActivity(
    ref.read(databaseProvider),
    since: status.lastExportAt,
  );
  return ExportReminderPolicy.isDue(
    now: now,
    lastExportAt: status.lastExportAt,
    snoozedUntil: status.snoozedUntil,
    workoutsSinceReference: activity.workouts,
    referenceStart: activity.firstLoggedAt,
    loggedDays: activity.loggedDays,
  );
});

typedef ExportReminderActivity = ({
  int workouts,
  int loggedDays,
  DateTime? firstLoggedAt,
});

/// Workouts saved after [since] (all of them when null), distinct days with
/// a food log or workout, and the first such record, which stands in for the
/// install date (IndiFit doesn't store one).
Future<ExportReminderActivity> readExportReminderActivity(
  AppDatabase db, {
  DateTime? since,
}) async {
  final workouts = since == null
      ? await db
            .customSelect('SELECT COUNT(*) AS c FROM workout_sessions')
            .getSingle()
      : await db
            .customSelect(
              'SELECT COUNT(*) AS c FROM workout_sessions '
              'WHERE completed_at > ?',
              variables: [Variable.withDateTime(since)],
            )
            .getSingle();
  // Drift stores DateTime as Unix seconds by default.
  final days = await db.customSelect('''
SELECT COUNT(DISTINCT d) AS days, MIN(t) AS first FROM (
  SELECT date(logged_at, 'unixepoch', 'localtime') AS d, logged_at AS t
    FROM food_logs
  UNION ALL
  SELECT date(completed_at, 'unixepoch', 'localtime'), completed_at
    FROM workout_sessions
)''').getSingle();
  final first = days.data['first'] as int?;
  return (
    workouts: workouts.data['c'] as int,
    loggedDays: days.data['days'] as int,
    firstLoggedAt: first == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(first * 1000),
  );
}
