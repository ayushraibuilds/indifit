import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/notification_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/widgets/indi_fit_bottom_sheet.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/features/settings/widgets/notification_settings_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (_) async => true,
        );
  });

  testWidgets('renders supported reminders and separates OS access state', (
    tester,
  ) async {
    final database = AppDatabase.memory();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      unawaited(database.close());
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: NotificationSettingsSection(
                permissionStatusLoader: _grantedPermission,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Allowed'), findsOneWidget);
    expect(find.text('Weekly progress report'), findsOneWidget);
    expect(find.text('Daily logging reminder'), findsOneWidget);
    expect(find.text('Evening Log Nudge'), findsNothing);
    expect(find.text('Edit schedule'), findsNWidgets(2));
    expect(find.text('Edit times'), findsOneWidget);
    expect(find.text('Weekly AI Report'), findsNothing);
    expect(find.text('Water Intake'), findsNothing);
    expect(find.textContaining('Hydration'), findsNothing);
    expect(find.textContaining('Keep your streak alive'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'weekly reminder routes to factual Progress, not the retired AI report',
    () {
      expect(
        NotificationService.destinationForPayload('weekly_report'),
        '/progress',
      );
    },
  );

  testWidgets('shows denied access and routes through the existing requester', (
    tester,
  ) async {
    var requestCount = 0;
    final database = AppDatabase.memory();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      unawaited(database.close());
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotificationSettingsSection(
                permissionStatusLoader: _deniedPermission,
                permissionRequester: () async {
                  requestCount++;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not allowed'), findsOneWidget);
    final allowButton = find.text('Allow notifications');
    expect(allowButton, findsOneWidget);
    await tester.tap(allowButton);
    await tester.pumpAndSettle();

    expect(requestCount, 1);
    expect(
      find.textContaining('device is blocking notifications'),
      findsOneWidget,
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/phase5_notifications_blocked_light.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps a permission-request failure visible', (tester) async {
    final database = AppDatabase.memory();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      unawaited(database.close());
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotificationSettingsSection(
                permissionStatusLoader: _deniedPermission,
                permissionRequester: () async {
                  throw StateError('permission denied by test');
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Allow notifications'));
    await tester.pumpAndSettle();

    expect(
      find.text('Notification access could not be requested. Try again.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides quiet-hour fields when disabled', (tester) async {
    SharedPreferences.setMockInitialValues({
      NotificationService.prefQuietHoursEnabled: false,
    });
    await _pumpSection(tester);

    expect(find.text('Off'), findsOneWidget);
    expect(find.text('Start time'), findsNothing);
    expect(find.text('End time'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('labels an existing overnight quiet-hours window', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      NotificationService.prefQuietHoursEnabled: true,
      NotificationService.prefQuietHoursStart: 22,
      NotificationService.prefQuietHoursEnd: 7,
    });
    await _pumpSection(tester);

    expect(find.textContaining('overnight'), findsOneWidget);
    expect(find.text('10:00 PM'), findsOneWidget);
    expect(find.text('7:00 AM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('workout schedule editor exposes days and time on demand', (
    tester,
  ) async {
    await _pumpSection(tester, size: const Size(320, 568), textScale: 2);

    final edit = find.text('Edit schedule').first;
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();

    expect(find.text('Workout reminder schedule'), findsOneWidget);
    expect(find.text('Days'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);
    expect(find.text('Reminder time'), findsOneWidget);
    expect(find.text('Save schedule'), findsOneWidget);
    await expectLater(
      find.byType(IndiFitBottomSheet),
      matchesGoldenFile('goldens/phase5_notification_schedule_editor_dark.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('stored schedules are rendered instead of fixed copy', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      NotificationService.prefWorkoutReminderDays: ['1', '3', '5'],
      NotificationService.prefWorkoutReminderHour: 6,
      NotificationService.prefWorkoutReminderMinute: 45,
      NotificationService.prefLunchReminderHour: 12,
      NotificationService.prefLunchReminderMinute: 15,
      NotificationService.prefDinnerReminderHour: 19,
      NotificationService.prefDinnerReminderMinute: 40,
      NotificationService.prefWeeklyProgressDay: DateTime.saturday,
      NotificationService.prefWeeklyProgressHour: 9,
      NotificationService.prefWeeklyProgressMinute: 20,
    });
    await _pumpSection(tester);

    expect(find.textContaining('Mon · Wed · Fri · 6:45 AM'), findsOneWidget);
    expect(
      find.textContaining('Lunch 12:15 PM · Dinner 7:40 PM'),
      findsOneWidget,
    );
    expect(find.textContaining('Saturday · 9:20 AM'), findsOneWidget);
    await expectLater(
      find.byType(NotificationSettingsSection),
      matchesGoldenFile('goldens/phase5_notifications_editable_dark.png'),
    );
  });

  testWidgets('workout day edits save through the production schedule path', (
    tester,
  ) async {
    await _pumpSection(tester);

    final edit = find.text('Edit schedule').first;
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Tue'));
    await tester.pump();
    final save = find.text('Save schedule');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(NotificationService.prefWorkoutReminderDays), [
      '1',
      '3',
      '4',
      '5',
      '6',
      '7',
    ]);
    expect(find.text('Save schedule'), findsNothing);
  });

  testWidgets('remains usable at narrow width and large text', (tester) async {
    await _pumpSection(tester, size: const Size(320, 568), textScale: 2);

    expect(find.text('Quiet Hours'), findsOneWidget);
    expect(find.text('Start time'), findsOneWidget);
    expect(find.text('End time'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<NotificationPermissionStatus> _grantedPermission() async {
  return NotificationPermissionStatus.granted;
}

Future<NotificationPermissionStatus> _deniedPermission() async {
  return NotificationPermissionStatus.denied;
}

Future<void> _pumpSection(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final database = AppDatabase.memory();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    unawaited(database.close());
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: MediaQueryData.fromView(
            tester.view,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: const Scaffold(
            body: SingleChildScrollView(
              child: NotificationSettingsSection(
                permissionStatusLoader: _grantedPermission,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
