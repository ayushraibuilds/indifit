import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/features/settings/about_credits_screen.dart';
import 'package:indifit/features/settings/data_management_sub_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/backup_v5_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Data and privacy uses truthful grouped consumer actions', (
    tester,
  ) async {
    await _pumpDataPrivacy(tester);

    expect(find.text('Data & privacy'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Danger'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Create and share backup'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Restore a backup'),
      findsOneWidget,
    );
    expect(find.text('Copy food & workout CSV'), findsOneWidget);
    expect(find.text('Offline mode'), findsOneWidget);
    expect(find.text('Share crash diagnostics'), findsOneWidget);

    expect(find.text('Regional Food Packs'), findsNothing);
    expect(find.text('Wipe All Local Data'), findsNothing);
    expect(find.text('Delete All Local Data?'), findsNothing);
    expect(find.text('Export Local Backup (Encrypted)'), findsNothing);
    expect(find.text('No Backend Mode'), findsNothing);
    expect(find.text('Anonymous Diagnostic Logging'), findsNothing);
    expect(find.byType(Switch), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Offline mode has one persisted privacy control', (tester) async {
    await _pumpDataPrivacy(tester);

    final offlineSwitch = find.byType(Switch).first;
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(offlineSwitch);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('offline_only'), isTrue);
    expect(find.textContaining('Offline mode is on'), findsOneWidget);
    expect(find.text('Anonymous Diagnostic Logging'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Restore requires inspection and deliberate confirmation', (
    tester,
  ) async {
    await _pumpDataPrivacy(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Restore a backup'));
    await tester.pumpAndSettle();

    final pasteField = find.byType(TextField).first;
    await tester.enterText(
      pasteField,
      jsonEncode(BackupV5Fixtures.validBackupV5Map()),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Inspect backup'));
    await tester.pumpAndSettle();

    expect(find.text('Review before restoring'), findsOneWidget);
    expect(find.textContaining('Existing data is not merged'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Restore backup'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
    await tester.pumpAndSettle();

    expect(find.text('Review before restoring'), findsNothing);
    expect(
      find.widgetWithText(OutlinedButton, 'Restore a backup'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Data and privacy remains usable at narrow width and large text',
    (tester) async {
      await _pumpDataPrivacy(
        tester,
        size: const Size(320, 568),
        textScale: 2,
        theme: AppTheme.darkTheme,
      );

      final semanticsHandle = tester.ensureSemantics();
      try {
        expect(find.text('Data & privacy'), findsOneWidget);
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -1200),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      } finally {
        semanticsHandle.dispose();
      }
    },
  );

  testWidgets('About exposes required third-party credits', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const AboutCreditsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('About & credits'), findsOneWidget);
    expect(find.text('MuscleMap'), findsOneWidget);
    expect(find.text('RepDB'), findsOneWidget);
    expect(find.text('Open Food Facts'), findsOneWidget);
    expect(find.text('Open-source licenses'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpDataPrivacy(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  ThemeData? theme,
}) async {
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;

  final database = AppDatabase.memory();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await database.close();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: MediaQuery(
        data: MediaQueryData.fromView(tester.view).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          theme: theme ?? AppTheme.lightTheme,
          home: const DataManagementSubScreen(),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 2),
  );
}
