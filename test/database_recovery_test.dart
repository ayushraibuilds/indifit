import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart' show NativeDatabase, SqliteException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/app/database_readiness.dart';
import 'package:indifit/app/database_recovery_screen.dart';
import 'package:indifit/app/indifit_app.dart';
import 'package:indifit/core/di/core_providers.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('app-level gate', () {
    Future<void> pumpApp(
      WidgetTester tester,
      Future<void> Function() ready,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseReadyProvider.overrideWith((ref) => ready())],
          child: const IndiFitApp(),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows the waiting screen while the database opens', (
      tester,
    ) async {
      final opening = Completer<void>();
      await pumpApp(tester, () => opening.future);

      expect(find.byType(DatabasePreparingScreen), findsOneWidget);
      expect(find.byType(DatabaseRecoveryScreen), findsNothing);
    });

    testWidgets('shows the recovery screen when the database cannot open', (
      tester,
    ) async {
      await pumpApp(
        tester,
        () => Future.error(StateError('corrupt database file')),
      );
      await tester.pump();

      expect(find.byType(DatabaseRecoveryScreen), findsOneWidget);
      expect(find.text("IndiFit couldn't open your data"), findsOneWidget);
      expect(find.byType(DatabasePreparingScreen), findsNothing);
    });
  });

  test('Try again opens a fresh connection after a failed open', () async {
    var opens = 0;
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) {
          opens++;
          final db = opens == 1
              ? AppDatabase.executor(
                  NativeDatabase.memory(
                    setup: (_) => throw SqliteException(13, 'disk is full'),
                  ),
                )
              : AppDatabase.memory();
          ref.onDispose(db.close);
          return db;
        }),
      ],
    );
    addTearDown(container.dispose);

    Object? failure;
    try {
      await container.read(databaseReadyProvider.future);
    } on Object catch (error) {
      failure = error;
    }
    expect(failure, isNotNull);
    expect(
      classifyDatabaseOpenFailure(failure!),
      DatabaseOpenFailure.storageFull,
    );

    // What the recovery screen's "Try again" does.
    container.invalidate(databaseProvider);
    await container.read(databaseReadyProvider.future);
    expect(opens, 2);
  });

  group('recovery screen', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      Object? error,
      VoidCallback? onRetry,
      Future<bool> Function()? exportFiles,
      Future<void> Function(String)? contactSupport,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DatabaseRecoveryScreen(
            error: error ?? StateError('corrupt'),
            onRetry: onRetry ?? () {},
            exportFiles: exportFiles ?? () async => true,
            contactSupport: contactSupport ?? (_) async {},
          ),
        ),
      );
    }

    testWidgets('offers try again, a copy of the data and support', (
      tester,
    ) async {
      var retried = 0;
      var exported = 0;
      String? reportedType;
      await pumpScreen(
        tester,
        onRetry: () => retried++,
        exportFiles: () async {
          exported++;
          return true;
        },
        contactSupport: (type) async => reportedType = type,
      );

      await tester.tap(find.text('Try again'));
      await tester.tap(find.text('Save a copy of my data'));
      await tester.pump();
      await tester.tap(find.text('Contact support'));
      await tester.pump();

      expect(retried, 1);
      expect(exported, 1);
      // Only the type is sent, never the message.
      expect(reportedType, 'StateError');
      // Exactly these three actions: nothing that deletes or resets data.
      expect(find.bySubtype<ButtonStyleButton>(), findsNWidgets(3));
    });

    testWidgets('says so when there were no files to share', (tester) async {
      await pumpScreen(tester, exportFiles: () async => false);

      await tester.tap(find.text('Save a copy of my data'));
      await tester.pump();

      expect(
        find.text('No data files were found on this device.'),
        findsOneWidget,
      );
    });

    testWidgets('explains a full disk in plain words', (tester) async {
      await pumpScreen(tester, error: SqliteException(13, 'disk is full'));

      expect(find.text('Your phone is out of storage'), findsOneWidget);
    });
  });

  group('classifyDatabaseOpenFailure', () {
    test('SQLITE_FULL, including extended codes, is storage full', () {
      expect(
        classifyDatabaseOpenFailure(SqliteException(13, 'full')),
        DatabaseOpenFailure.storageFull,
      );
      expect(
        classifyDatabaseOpenFailure(SqliteException(13 | (1 << 8), 'full')),
        DatabaseOpenFailure.storageFull,
      );
    });

    test('ENOSPC from the file system is storage full', () {
      expect(
        classifyDatabaseOpenFailure(
          const FileSystemException('write', 'indifit.db', OSError('', 28)),
        ),
        DatabaseOpenFailure.storageFull,
      );
    });

    test('anything else is a general failure', () {
      expect(
        classifyDatabaseOpenFailure(SqliteException(11, 'malformed')),
        DatabaseOpenFailure.other,
      );
      expect(
        classifyDatabaseOpenFailure(StateError('x')),
        DatabaseOpenFailure.other,
      );
    });
  });

  test('support email encodes spaces as %20, not +', () {
    final uri = supportEmailUri('SqliteException');
    final raw = uri.toString();
    expect(raw, startsWith('mailto:${DatabaseRecoveryScreen.supportEmail}?'));
    expect(raw, isNot(contains('+')));
    expect(raw, contains('IndiFit%20couldn'));
    expect(Uri.decodeComponent(raw), contains('Error type: SqliteException'));
  });

  test('support email carries the app version', () {
    final body = Uri.decodeComponent(
      supportEmailUri('SqliteException', appVersion: '1.0.0 (7)').toString(),
    );
    expect(body, contains('App version: 1.0.0 (7)'));
    expect(body, contains('Error type: SqliteException'));
  });

  test('support email says the version is unknown when it is missing', () {
    for (final version in [null, '', '  ']) {
      final body = Uri.decodeComponent(
        supportEmailUri('SqliteException', appVersion: version).toString(),
      );
      expect(body, contains('App version: unknown'));
    }
  });
}
