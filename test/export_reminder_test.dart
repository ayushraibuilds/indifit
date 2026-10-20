// FT-1 export reminder and U-1 "Your data, your phone" card.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/core/config/app_preferences_keys.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/features/settings/data_export_status.dart';
import 'package:indifit/features/settings/settings_controller.dart';
import 'package:indifit/features/settings/widgets/your_data_card.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime(2026, 10, 20, 9);

  group('ExportReminderPolicy', () {
    bool due({
      DateTime? lastExportAt,
      DateTime? snoozedUntil,
      int workouts = 0,
      DateTime? firstLoggedAt,
      int loggedDays = 30,
    }) => ExportReminderPolicy.isDue(
      now: now,
      lastExportAt: lastExportAt,
      snoozedUntil: snoozedUntil,
      workoutsSinceReference: workouts,
      referenceStart: firstLoggedAt,
      loggedDays: loggedDays,
    );

    test('after an export: 10 workouts or 30 days', () {
      final exported = now.subtract(const Duration(days: 5));
      expect(due(lastExportAt: exported, workouts: 9), isFalse);
      expect(due(lastExportAt: exported, workouts: 10), isTrue);
      expect(
        due(lastExportAt: now.subtract(const Duration(days: 29))),
        isFalse,
      );
      expect(due(lastExportAt: now.subtract(const Duration(days: 30))), isTrue);
    });

    test('never exported: needs 7 logged days as well', () {
      final start = now.subtract(const Duration(days: 40));
      expect(due(firstLoggedAt: start, loggedDays: 6), isFalse);
      expect(due(firstLoggedAt: start, loggedDays: 6, workouts: 12), isFalse);
      expect(due(firstLoggedAt: start, loggedDays: 7), isTrue);
      expect(
        due(
          firstLoggedAt: now.subtract(const Duration(days: 10)),
          loggedDays: 7,
        ),
        isFalse,
      );
      expect(
        due(
          firstLoggedAt: now.subtract(const Duration(days: 10)),
          loggedDays: 7,
          workouts: 10,
        ),
        isTrue,
      );
    });

    test('a snooze hides it until it ends', () {
      final exported = now.subtract(const Duration(days: 60));
      expect(
        due(
          lastExportAt: exported,
          snoozedUntil: now.add(const Duration(days: 1)),
        ),
        isFalse,
      );
      expect(due(lastExportAt: exported, snoozedUntil: now), isTrue);
    });
  });

  group('DataExportStatusNotifier', () {
    test('Later snoozes for 30 days and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = DataExportStatusNotifier(prefs);
      await notifier.snoozeReminder(now);
      final until = now.add(const Duration(days: 30));
      expect(notifier.state.snoozedUntil, until);
      expect(
        DataExportStatusNotifier(prefs).state.snoozedUntil,
        until,
        reason: 'read back from prefs',
      );
    });

    test('export date and snooze stay out of backups', () async {
      SharedPreferences.setMockInitialValues({
        AppPreferenceKeys.lastDataExportAt: now.toIso8601String(),
        AppPreferenceKeys.dataExportReminderSnoozedUntil: now.toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final backup = await BackupData.createFromDatabase(db, prefs);
      final saved = backup.toJson().toString();
      expect(saved, isNot(contains(AppPreferenceKeys.lastDataExportAt)));
      expect(
        saved,
        isNot(contains(AppPreferenceKeys.dataExportReminderSnoozedUntil)),
      );
    });
  });

  group('export date', () {
    Future<ProviderContainer> container() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('updates only after a successful share', () async {
      final c = await container();
      final controller = c.read(settingsControllerProvider.notifier);

      for (final status in [
        ShareResultStatus.dismissed,
        ShareResultStatus.unavailable,
      ]) {
        await controller.recordShareOutcome(status);
        expect(c.read(dataExportStatusProvider).lastExportAt, isNull);
      }

      final result = await controller.recordShareOutcome(
        ShareResultStatus.success,
      );
      expect(result.status, SettingsExportStatus.shared);
      expect(c.read(dataExportStatusProvider).lastExportAt, isNotNull);
      final prefs = c.read(sharedPreferencesProvider);
      expect(prefs.getString(AppPreferenceKeys.lastDataExportAt), isNotNull);
    });
  });

  group('reminder activity from the database', () {
    test('counts workouts since the export and distinct logged days', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      Future<void> workout(DateTime at) => db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              name: 'Push',
              totalVolume: 0,
              durationSeconds: 60,
              estimatedCalories: 0,
              completedAt: Value(at),
            ),
          );
      await workout(DateTime(2026, 9, 1, 8));
      await workout(DateTime(2026, 9, 1, 19));
      await workout(DateTime(2026, 10, 2, 8));
      await db
          .into(db.foodLogs)
          .insert(
            FoodLogsCompanion.insert(
              name: 'Poha',
              calories: 250,
              proteinG: 5,
              carbsG: 45,
              fatG: 6,
              servingLogged: 1,
              servingUnit: 'bowl',
              mealType: 'breakfast',
              loggedAt: Value(DateTime(2026, 9, 3, 8)),
            ),
          );

      final all = await readExportReminderActivity(db);
      expect(all.workouts, 3);
      expect(all.loggedDays, 3);
      expect(all.firstLoggedAt, DateTime(2026, 9, 1, 8));

      final since = await readExportReminderActivity(
        db,
        since: DateTime(2026, 9, 15),
      );
      expect(since.workouts, 1);
    });
  });

  group('cards', () {
    Future<void> pump(
      WidgetTester tester,
      Widget child, {
      Map<String, Object> prefs = const {},
      List<Override> overrides = const [],
    }) async {
      SharedPreferences.setMockInitialValues(prefs);
      final store = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(store),
            ...overrides,
          ],
          child: MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: child)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Your data card says Never before any export', (tester) async {
      await pump(tester, const YourDataCard());
      expect(find.text('Your data, your phone'), findsOneWidget);
      expect(find.text('Last export: Never'), findsOneWidget);
      expect(find.text('Export now'), findsOneWidget);
      expect(find.textContaining(kNewPhoneStartsEmpty), findsOneWidget);
    });

    testWidgets('Your data card shows the last export date', (tester) async {
      await pump(
        tester,
        const YourDataCard(),
        prefs: {
          AppPreferenceKeys.lastDataExportAt: DateTime(
            2026,
            10,
            12,
          ).toIso8601String(),
        },
      );
      expect(find.text('Last export: 12 Oct 2026'), findsOneWidget);
    });

    testWidgets('onboarding variant has no export button', (tester) async {
      await pump(tester, const YourDataCard(showExportAction: false));
      expect(find.text('Export now'), findsNothing);
      expect(find.text('Last export: Never'), findsOneWidget);
    });

    testWidgets('reminder is hidden when not due', (tester) async {
      await pump(
        tester,
        const ExportReminderCard(),
        overrides: [exportReminderDueProvider.overrideWith((ref) => false)],
      );
      expect(find.byKey(const Key('export_reminder_card')), findsNothing);
    });

    testWidgets('reminder shows when due and Later hides it', (tester) async {
      await pump(
        tester,
        const ExportReminderCard(),
        overrides: [
          exportReminderDueProvider.overrideWith(
            (ref) => ref.watch(dataExportStatusProvider).snoozedUntil == null,
          ),
        ],
      );
      expect(find.byKey(const Key('export_reminder_card')), findsOneWidget);
      expect(find.text('Export now'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('export_reminder_card')), findsNothing);
    });
  });
}
