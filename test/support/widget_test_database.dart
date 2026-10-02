import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';

/// Closes [database] from a widget-test teardown without hanging the suite.
///
/// A widget test runs on a fake clock. When a test ends while a drift query
/// is still in flight (common after a failed expectation, and in some
/// coaching/logging flows even on success), an unbounded `close()` waits for
/// that query forever and the whole `flutter test` run stalls. This closes on
/// the real clock and gives up after [timeout], logging instead of hanging.
Future<void> closeWidgetTestDatabase(
  WidgetTester tester,
  AppDatabase database, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  await tester.runAsync(
    () => database.close().timeout(
      timeout,
      onTimeout: () => debugPrint(
        'database.close() did not finish within ${timeout.inSeconds}s: '
        'a query was still in flight when the test ended.',
      ),
    ),
  );
}
