import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/core/config/app_preferences_keys.dart';
import 'package:indifit/core/services/auto_backup_secret_store.dart';
import 'package:indifit/core/services/auto_backup_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/features/settings/settings_controller.dart';
import 'package:indifit/features/settings/widgets/fresh_backup_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// R-06 + N14-13: a fresh copy before a restore, and on going to the
/// background at most every 30 minutes when something changed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('background backup', () {
    late AppDatabase db;
    late Directory documents;
    late SharedPreferences prefs;
    late AutoBackupService service;
    final noon = DateTime(2026, 10, 22, 12);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.memory();
      documents = await Directory.systemTemp.createTemp('indifit-r06-');
      service = AutoBackupService(
        db,
        prefs: prefs,
        secretStore: const _FakeSecretStore(),
        documentsDirectoryProvider: () async => documents,
      );
    });

    tearDown(() async {
      await db.close();
      await documents.delete(recursive: true);
    });

    Future<void> logFood(String name) => db
        .into(db.foodLogs)
        .insert(
          FoodLogsCompanion.insert(
            name: name,
            calories: 200,
            proteinG: 5,
            carbsG: 30,
            fatG: 5,
            servingLogged: 1,
            servingUnit: 'bowl',
            mealType: 'lunch',
            uuid: Value('uuid-$name'),
          ),
        );

    File copy(int index) =>
        File('${documents.path}/backups/indifit_auto_backup_$index.json');

    test('the first background backup saves a copy', () async {
      await logFood('Poha');
      expect(
        await service.runBackgroundBackup(now: noon),
        AutoBackupOutcome.created,
      );
      expect(await copy(1).exists(), isTrue);
      expect(
        prefs.getInt(AppPreferenceKeys.autoBackupLastBackgroundAt),
        noon.millisecondsSinceEpoch,
      );
    });

    test('runs at most once every 30 minutes', () async {
      await logFood('Poha');
      await service.runBackgroundBackup(now: noon);
      await logFood('Dal');
      expect(
        await service.runBackgroundBackup(
          now: noon.add(const Duration(minutes: 29)),
        ),
        isNull,
      );
      expect(await copy(2).exists(), isFalse);
      expect(
        await service.runBackgroundBackup(
          now: noon.add(const Duration(minutes: 30)),
        ),
        AutoBackupOutcome.created,
      );
      expect(await copy(2).exists(), isTrue);
    });

    test('skips writing when nothing changed', () async {
      await logFood('Poha');
      await service.runBackgroundBackup(now: noon);
      expect(
        await service.runBackgroundBackup(
          now: noon.add(const Duration(hours: 1)),
        ),
        AutoBackupOutcome.unchanged,
      );
      expect(await copy(2).exists(), isFalse);
    });

    test('keeps three rolling copies', () async {
      for (var i = 0; i < 5; i++) {
        await logFood('Food $i');
        await service.runBackgroundBackup(now: noon.add(Duration(hours: i)));
      }
      expect(await copy(3).exists(), isTrue);
      expect(
        await File(
          '${documents.path}/backups/indifit_auto_backup_4.json',
        ).exists(),
        isFalse,
      );
    });

    test('the background time is not in backups', () async {
      await prefs.setInt(AppPreferenceKeys.autoBackupLastBackgroundAt, 1);
      final backup = jsonEncode(
        (await BackupData.createFromDatabase(db, prefs)).toJson(),
      );
      expect(backup, isNot(contains('auto_backup_last_background_at')));
    });
  });

  group('fresh backup before a restore', () {
    Future<List<String>> runGate(
      WidgetTester tester, {
      required AutoBackupOutcome outcome,
      String? answer,
    }) async {
      final events = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            freshBackupProvider.overrideWithValue(() async {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              events.add('backup');
              return outcome;
            }),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () async {
                  if (await ensureFreshBackup(context, ref)) {
                    events.add('restore');
                  }
                },
                child: const Text('Restore'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Restore'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      if (answer != null) {
        expect(find.text('Continue without a fresh backup?'), findsOneWidget);
        await tester.tap(find.text(answer));
        await tester.pumpAndSettle();
      }
      return events;
    }

    testWidgets('the copy is saved before the restore goes on', (tester) async {
      expect(await runGate(tester, outcome: AutoBackupOutcome.created), [
        'backup',
        'restore',
      ]);
    });

    testWidgets('unchanged data needs no new copy and no prompt', (
      tester,
    ) async {
      expect(await runGate(tester, outcome: AutoBackupOutcome.unchanged), [
        'backup',
        'restore',
      ]);
      expect(find.text('Continue without a fresh backup?'), findsNothing);
    });

    testWidgets('a failure asks, and Cancel stops the restore', (tester) async {
      expect(
        await runGate(
          tester,
          outcome: AutoBackupOutcome.failed,
          answer: 'Cancel',
        ),
        ['backup'],
      );
    });

    testWidgets('a failure asks, and Continue goes on without one', (
      tester,
    ) async {
      expect(
        await runGate(
          tester,
          outcome: AutoBackupOutcome.failed,
          answer: 'Continue',
        ),
        ['backup', 'restore'],
      );
    });

    test('both restore paths ask for a fresh copy first', () async {
      final source = await File(
        'lib/features/settings/widgets/data_management_section.dart',
      ).readAsString();
      final restores = 'performRestore('.allMatches(source).length;
      expect(restores, 2);
      for (final match in 'performRestore('.allMatches(source)) {
        final before = source.substring(0, match.start);
        final gate = before.lastIndexOf('ensureFreshBackup(context, ref)');
        final previousRestore = before.lastIndexOf('performRestore(');
        expect(gate, greaterThan(previousRestore));
      }
    });
  });

  group('a backup file before an erase', () {
    Future<bool?> runOffer(
      WidgetTester tester, {
      required String answer,
      SettingsExportStatus? exported,
    }) async {
      bool? result;
      var exports = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await offerBackupBeforeErase(
                  context,
                  export: () async {
                    exports++;
                    return exported;
                  },
                );
              },
              child: const Text('Erase'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Erase'));
      await tester.pumpAndSettle();
      expect(find.text('Keep a copy before erasing?'), findsOneWidget);
      await tester.tap(find.text(answer));
      await tester.pumpAndSettle();
      expect(exports, answer == 'Export backup file' ? 1 : 0);
      return result;
    }

    testWidgets('a shared file goes on to the erase', (tester) async {
      expect(
        await runOffer(
          tester,
          answer: 'Export backup file',
          exported: SettingsExportStatus.shared,
        ),
        isTrue,
      );
    });

    testWidgets('a cancelled export stops the erase', (tester) async {
      expect(
        await runOffer(
          tester,
          answer: 'Export backup file',
          exported: SettingsExportStatus.cancelled,
        ),
        isFalse,
      );
    });

    testWidgets('erasing without a copy goes on', (tester) async {
      expect(await runOffer(tester, answer: 'Erase without a copy'), isTrue);
    });

    testWidgets('Cancel stops the erase', (tester) async {
      expect(await runOffer(tester, answer: 'Cancel'), isFalse);
    });
  });
}

class _FakeSecretStore implements AutoBackupSecretStore {
  const _FakeSecretStore();

  @override
  Future<String?> read() async => 'device-secret';

  @override
  Future<String> readOrCreate() async => 'device-secret';

  @override
  Future<void> clear() async {}
}
