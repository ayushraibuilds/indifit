import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/health_provider.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/health_service.dart';
import 'package:indifit/features/settings/data_management_sub_screen.dart';
import 'package:indifit/features/settings/health_sync_hub_screen.dart';
import 'package:indifit/features/settings/notification_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHealthService extends HealthService {
  @override
  Future<HealthDataSummary> fetchTodayHealthData() async =>
      const HealthDataSummary(
        steps: 7420,
        activeCalories: 450,
        sleepHours: 7.5,
        isConnected: true,
      );

  @override
  Future<String?> getLastSyncTime() async => '2026-08-26T10:30:00Z';

  @override
  Future<List<Map<String, dynamic>>> importOutdoorActivities([
    AppDatabase? db,
  ]) async => [];

  @override
  Future<Map<HealthCategory, bool>> getAllCategoryStates() async => {
    HealthCategory.steps: true,
    HealthCategory.activeEnergy: true,
    HealthCategory.sleep: true,
    HealthCategory.workoutImport: true,
    HealthCategory.workoutExport: true,
    HealthCategory.weightExport: true,
  };
}

class _FakeHealthNotifier extends HealthStateNotifier {
  _FakeHealthNotifier(super.service) {
    state = const HealthState(
      status: HealthStatus.available,
      summary: HealthDataSummary(
        steps: 7420,
        activeCalories: 450,
        sleepHours: 7.5,
        isConnected: true,
      ),
    );
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> connectAndRefresh() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _FakeHealthService fakeHealthService;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
      'pref_remind_workout': true,
      'pref_remind_meals': false,
      'pref_remind_evening': true,
      'pref_quiet_hours_enabled': true,
      'pref_quiet_hours_start': 22,
      'pref_quiet_hours_end': 7,
      'auto_sync_health_on_open': true,
    });
    db = AppDatabase.memory();
    fakeHealthService = _FakeHealthService();
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestWidget({
    required Widget child,
    ThemeData? theme,
    Size size = const Size(390, 844),
    double textScale = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        healthServiceProvider.overrideWithValue(fakeHealthService),
        healthStateProvider.overrideWith(
          (ref) => _FakeHealthNotifier(fakeHealthService),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: MaterialApp(theme: theme ?? AppTheme.lightTheme, home: child),
      ),
    );
  }

  group('R08G.7 — Data Management & Danger Zone', () {
    testWidgets('Danger Zone is visually distinct and states real consequences', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(child: const DataManagementSubScreen()),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Check section headings
      expect(find.text('Backup'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('DANGER ZONE'), findsOneWidget);

      // Check Danger Zone contents
      expect(find.text('Irreversible actions'), findsOneWidget);
      expect(find.text('Reset onboarding wizard'), findsOneWidget);
      expect(find.textContaining('Wipe all local data'), findsNothing);

      // Consequence explanations
      expect(
        find.textContaining('logged meal and workout history remains safe'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Permanently wipe all food logs'),
        findsNothing,
      );
      expect(find.textContaining('This cannot be undone'), findsNothing);

      // Dead / duplicate navigation removed
      expect(
        find.text('Apple Health & Health Connect Sync'),
        findsNothing,
        reason:
            'Health sync belongs exclusively under Settings -> Health integration',
      );

      // Deferred features remain absent
      expect(find.textContaining('Hydration'), findsNothing);
      expect(find.textContaining('Water'), findsNothing);
      expect(find.textContaining('Travel'), findsNothing);
      expect(find.textContaining('Coming soon'), findsNothing);
      expect(find.textContaining('SQLite'), findsNothing);
      expect(find.textContaining('telemetry'), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Reset Onboarding requires confirmation dialog before executing',
      (tester) async {
        await tester.pumpWidget(
          createTestWidget(child: const DataManagementSubScreen()),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Scroll to Danger Zone
        final resetButton = find
            .widgetWithText(OutlinedButton, 'Start setup again')
            .first;
        await tester.scrollUntilVisible(resetButton, 300);
        await tester.pumpAndSettle();

        // Tap Reset Onboarding
        await tester.tap(resetButton);
        await tester.pumpAndSettle();

        // Verify confirmation dialog appeared
        expect(find.text('Start setup again?'), findsOneWidget);
        expect(find.textContaining('resets setup'), findsOneWidget);
        expect(
          find.textContaining('does not delete logged data or backups'),
          findsOneWidget,
        );

        // Cancel button dismisses dialog
        final cancelButton = find.widgetWithText(TextButton, 'Cancel');
        expect(cancelButton, findsOneWidget);
        await tester.tap(cancelButton);
        await tester.pumpAndSettle();

        // Dialog is gone
        expect(find.text('Start setup again?'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Wipe All Local Data remains unavailable without complete authority',
      (tester) async {
        await tester.pumpWidget(
          createTestWidget(child: const DataManagementSubScreen()),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.textContaining('Wipe all local data'), findsNothing);
        expect(find.textContaining('Delete all local data'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Export and Restore dialogs open with proper options', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(child: const DataManagementSubScreen()),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Tap Create and share backup
      await tester.tap(find.text('Create and share backup'));
      await tester.pumpAndSettle();
      expect(find.text('Create a backup'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Tap Restore a backup
      await tester.tap(find.text('Restore a backup'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(AlertDialog, 'Restore a backup'),
        findsOneWidget,
      );
      expect(find.text('Choose a backup file'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('R08G.7 — Notifications & Reminders Screen', () {
    testWidgets(
      'Notification settings renders clean reminder toggles and Quiet Hours',
      (tester) async {
        await tester.pumpWidget(
          createTestWidget(child: const NotificationSettingsScreen()),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.text('Reminders'), findsOneWidget);
        expect(find.text('Workout Reminder'), findsOneWidget);
        expect(find.text('Meal Logging'), findsOneWidget);
        expect(find.text('Evening Log Nudge'), findsOneWidget);
        expect(find.text('Quiet Hours'), findsOneWidget);
        expect(find.text('Start time'), findsOneWidget);
        expect(find.text('End time'), findsOneWidget);

        // Unsupported AI report is hidden
        expect(find.text('Weekly AI Report'), findsNothing);

        // No hydration or water toggles
        expect(find.textContaining('Hydration'), findsNothing);
        expect(find.textContaining('Water'), findsNothing);

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('R08G.7 — Health Sync Hub Screen', () {
    testWidgets(
      'Health sync hub renders connection status, permissions and sync action',
      (tester) async {
        await tester.pumpWidget(
          createTestWidget(child: const HealthSyncHubScreen()),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.text('HEALTH CONNECTION'), findsOneWidget);
        expect(find.text('Connection status'), findsOneWidget);
        expect(find.text('WHAT INDIFIT MAY USE'), findsOneWidget);
        expect(find.text('Steps'), findsAtLeastNWidgets(1));
        expect(find.text('Active energy'), findsAtLeastNWidgets(1));
        expect(find.text('Sleep'), findsAtLeastNWidgets(1));
        expect(find.text('Resting heart rate'), findsOneWidget);
        expect(find.text('Walking, running, and cycling'), findsOneWidget);
        expect(find.text('Body weight'), findsOneWidget);
        expect(find.text('Workout Export (Write)'), findsNothing);
        expect(find.text('Auto-sync on app open'), findsNothing);

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('R08G.7 — Responsive Narrow (320px) & 2x Text Scale Resilience', () {
    testWidgets(
      'DataManagementSubScreen adapts to 320px width and 2x text scale in dark mode',
      (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: const DataManagementSubScreen(),
            theme: AppTheme.darkTheme,
            size: const Size(320, 568),
            textScale: 2.0,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.text('Backup'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'NotificationSettingsScreen adapts to 320px width and 2x text scale in dark mode',
      (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: const NotificationSettingsScreen(),
            theme: AppTheme.darkTheme,
            size: const Size(320, 568),
            textScale: 2.0,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.text('Reminders'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'HealthSyncHubScreen adapts to 320px width and 2x text scale in dark mode',
      (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: const HealthSyncHubScreen(),
            theme: AppTheme.darkTheme,
            size: const Size(320, 568),
            textScale: 2.0,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.text('HEALTH CONNECTION'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
