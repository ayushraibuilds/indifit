import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';

/// The kinds of call the app makes (UF-21), each with the time it last
/// went out. Recorded at the choke points the calls already pass through.
enum NetworkCallKind {
  foodLookup('food_lookup'),
  foodDatabase('food_database'),
  ai('ai'),
  tipJar('tip_jar'),
  crashReports('crash_reports');

  const NetworkCallKind(this.id);

  final String id;

  /// Device-local and not backed up; erasing data clears it with the rest
  /// of the preferences.
  String get prefKey => 'network_last_ran_$id';
}

/// "Last ran" for the data receipt (Settings → Manage your data → Network
/// activity). It stores only when each kind of call last went out: no URL,
/// query or payload.
abstract final class NetworkReceipt {
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  @visibleForTesting
  static Future<SharedPreferences> Function() preferences =
      SharedPreferences.getInstance;

  /// Notes that a [kind] call is going out now. Never throws: the receipt
  /// must not get in the way of the call.
  static Future<void> record(NetworkCallKind kind) async {
    try {
      final prefs = await preferences();
      await prefs.setInt(kind.prefKey, clock().toUtc().millisecondsSinceEpoch);
    } on Object catch (error) {
      AppLogger.warning('Network receipt not recorded: $error', 'Receipt');
    }
  }

  /// When [kind] last went out, or null for never.
  static DateTime? lastRan(SharedPreferences prefs, NetworkCallKind kind) {
    final millis = prefs.getInt(kind.prefKey);
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }
}
