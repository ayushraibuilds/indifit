import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/router/app_router.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/repositories/health_service.dart';
import 'package:indifit/features/settings/settings_controller.dart';
import 'package:indifit/features/settings/widgets/data_management_section.dart';

import 'support/indifit_test_harness.dart';

class _MockDataErasureService extends DataErasureService {
  int eraseCalls = 0;
  bool isSuccessResult = true;

  _MockDataErasureService({
    required super.db,
    required super.healthService,
  });

  @override
  Future<DataErasureReport> eraseAllData() async {
    eraseCalls++;
    return DataErasureReport(
      isSuccess: isSuccessResult,
      completedAtUtc: DateTime.now().toUtc(),
      remainingUserTableCounts: const {},
      remainingCustomFoodsCount: 0,
      remainingCustomExercisesCount: 0,
      foreignKeyCheckPassed: true,
      preferencesCleared: true,
      secureStorageCleared: true,
      localFilesCleared: true,
      notificationsCancelled: true,
      cloudBackupsPurged: true,
      accountDeleted: true,
      healthDisconnected: true,
      disclosures: const [
        'Health data previously synced to Apple Health or Android Health Connect remains stored in your operating system health app.',
        'Static food and exercise reference catalogs have been retained.',
      ],
      failureReason: isSuccessResult ? null : 'Simulated verification error',
    );
  }
}

class _MockHealthService extends HealthService {
  @override
  Future<void> disconnect() async {}
}

void main() {
  initializeIndiFitTestHarness();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (_) async => true,
        );
    setIndiFitTestPreferences({
      'onboarding_completed': true,
    });
  });

  testWidgets('renders Erase all data in Danger Zone and enforces two-step DELETE confirmation', (
    WidgetTester tester,
  ) async {
    final databases = registerTestDatabaseScope();
    final db = databases.create();
    final fakeErasureService = _MockDataErasureService(
      db: db,
      healthService: _MockHealthService(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dataErasureServiceProvider.overrideWithValue(fakeErasureService),
          settingsControllerProvider.overrideWith(
            (ref) => SettingsController(ref),
          ),
          onboardingCompletedProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: DataManagementSection(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Danger Zone renders the erasure header and action
    expect(find.text('DANGER ZONE'), findsOneWidget);
    expect(find.text('Erase all data and reset'), findsOneWidget);
    final eraseButton = find.widgetWithText(FilledButton, 'Erase all data');
    expect(eraseButton, findsOneWidget);

    // 2. Tap "Erase all data" -> Step 1 modal opens
    await tester.ensureVisible(eraseButton);
    await tester.tap(eraseButton);
    await tester.pumpAndSettle();

    expect(find.text('Erase all personal data?'), findsOneWidget);
    expect(find.text('External Health Data Notice'), findsOneWidget);
    expect(find.text('Continue to confirm'), findsOneWidget);

    // 3. Test Cancel dismisses Step 1
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Erase all personal data?'), findsNothing);
    expect(fakeErasureService.eraseCalls, 0);

    // 4. Tap "Erase all data" again and proceed to Step 2
    await tester.tap(eraseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to confirm'));
    await tester.pumpAndSettle();

    // 5. Verify Step 2 modal: title, text field, disabled danger button
    expect(find.text('Type DELETE to confirm'), findsOneWidget);
    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);

    // The confirm button in the dialog has label "Erase all data"
    final dialogConfirmButton = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Erase all data'),
    );
    expect(dialogConfirmButton, findsOneWidget);

    // Initially disabled (onPressed is null)
    FilledButton buttonWidget = tester.widget<FilledButton>(dialogConfirmButton);
    expect(buttonWidget.onPressed, isNull);

    // 6. Typing partial/incorrect text keeps button disabled
    await tester.enterText(textField, 'del');
    await tester.pump();
    buttonWidget = tester.widget<FilledButton>(dialogConfirmButton);
    expect(buttonWidget.onPressed, isNull);

    await tester.enterText(textField, 'delete');
    await tester.pump();
    buttonWidget = tester.widget<FilledButton>(dialogConfirmButton);
    expect(buttonWidget.onPressed, isNull);

    // 7. Typing exact "DELETE" enables button
    await tester.enterText(textField, 'DELETE');
    await tester.pump();
    buttonWidget = tester.widget<FilledButton>(dialogConfirmButton);
    expect(buttonWidget.onPressed, isNotNull);

    // 8. Tap the enabled "Erase all data" button
    await tester.tap(dialogConfirmButton);
    await tester.pump(); // starts progress and runs eraseAllData()
    await tester.pumpAndSettle();

    expect(fakeErasureService.eraseCalls, 1);
    expect(find.text('All personal data has been erased.'), findsOneWidget);
  });

  testWidgets('shows error dialog when erasure verification report indicates failure', (
    WidgetTester tester,
  ) async {
    final databases = registerTestDatabaseScope();
    final db = databases.create();
    final fakeErasureService = _MockDataErasureService(
      db: db,
      healthService: _MockHealthService(),
    )..isSuccessResult = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dataErasureServiceProvider.overrideWithValue(fakeErasureService),
          settingsControllerProvider.overrideWith(
            (ref) => SettingsController(ref),
          ),
          onboardingCompletedProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: DataManagementSection(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final eraseButton = find.widgetWithText(FilledButton, 'Erase all data');
    await tester.ensureVisible(eraseButton);
    await tester.tap(eraseButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue to confirm'));
    await tester.pumpAndSettle();

    final textField = find.byType(TextField);
    await tester.enterText(textField, 'DELETE');
    await tester.pump();

    final dialogConfirmButton = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Erase all data'),
    );
    await tester.tap(dialogConfirmButton);
    await tester.pumpAndSettle();

    expect(fakeErasureService.eraseCalls, 1);
    expect(find.text('Erasure verification failed'), findsOneWidget);
    expect(find.textContaining('Simulated verification error'), findsOneWidget);
  });

  testWidgets('shows error snackbar when erasure throws unexpected exception', (
    WidgetTester tester,
  ) async {
    final databases = registerTestDatabaseScope();
    final db = databases.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dataErasureServiceProvider.overrideWith((ref) => _ThrowingDataErasureService(
                db: db,
                healthService: _MockHealthService(),
              )),
          settingsControllerProvider.overrideWith(
            (ref) => SettingsController(ref),
          ),
          onboardingCompletedProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: DataManagementSection(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final eraseButton = find.widgetWithText(FilledButton, 'Erase all data');
    await tester.ensureVisible(eraseButton);
    await tester.tap(eraseButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue to confirm'));
    await tester.pumpAndSettle();

    final textField = find.byType(TextField);
    await tester.enterText(textField, 'DELETE');
    await tester.pump();

    final dialogConfirmButton = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Erase all data'),
    );
    await tester.tap(dialogConfirmButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('Erasure failed: Exception: Simulated fatal IO failure'), findsOneWidget);
  });
}

class _ThrowingDataErasureService extends DataErasureService {
  _ThrowingDataErasureService({
    required super.db,
    required super.healthService,
  });

  @override
  Future<DataErasureReport> eraseAllData() async {
    throw Exception('Simulated fatal IO failure');
  }
}
