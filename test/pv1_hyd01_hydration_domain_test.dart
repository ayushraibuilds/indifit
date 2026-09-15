import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/notification_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/widgets/b05_accessibility_primitives.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/hydration_models.dart';
import 'package:indifit/data/repositories/hydration_repository.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:indifit/features/dashboard/widgets/hydration_detail_sheet.dart';
import 'package:indifit/features/dashboard/widgets/hydration_fluid_fill.dart';
import 'package:indifit/features/dashboard/widgets/today_hydration_card.dart';
import 'package:indifit/features/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late HydrationRepository repo;
  late List<MethodCall> platformCalls;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    platformCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (call) async {
            platformCalls.add(call);
            return true;
          },
        );
    db = AppDatabase.memory();
    repo = HydrationRepository(db, prefs: prefs);
  });

  tearDown(() async {
    await db.close();
  });

  group('PV1-HYD-01 Domain Models', () {
    test('HydrationIntakeEntry JSON round-trip preserves fields and UTC timestamp', () {
      final nowUtc = DateTime.utc(2026, 9, 8, 10, 30);
      final entry = HydrationIntakeEntry(
        id: 'entry-123',
        localDate: '2026-09-08',
        amountMl: 350,
        loggedAtUtc: nowUtc,
        source: 'quickAdd',
        containerType: 'glass',
      );

      final json = entry.toJson();
      final reconstructed = HydrationIntakeEntry.fromJson(json);

      expect(reconstructed.id, equals('entry-123'));
      expect(reconstructed.localDate, equals('2026-09-08'));
      expect(reconstructed.amountMl, equals(350));
      expect(reconstructed.loggedAtUtc, equals(nowUtc));
      expect(reconstructed.source, equals('quickAdd'));
      expect(reconstructed.containerType, equals('glass'));
      expect(reconstructed, equals(entry));
    });

    test('HydrationDailyReadModel clamps progress ratio to [0.0, 1.0] while raw ratio preserves surplus', () {
      // 0 ml logged
      const emptyModel = HydrationDailyReadModel(
        localDate: '2026-09-08',
        totalMl: 0,
        goalMl: 2500,
      );
      expect(emptyModel.clampedProgressRatio, equals(0.0));
      expect(emptyModel.rawProgressRatio, equals(0.0));
      expect(emptyModel.progressPercent, equals(0));
      expect(emptyModel.isGoalMet, isFalse);
      expect(emptyModel.remainingMl, equals(2500));

      // 1250 ml logged (50%)
      const halfModel = HydrationDailyReadModel(
        localDate: '2026-09-08',
        totalMl: 1250,
        goalMl: 2500,
      );
      expect(halfModel.clampedProgressRatio, equals(0.5));
      expect(halfModel.rawProgressRatio, equals(0.5));
      expect(halfModel.progressPercent, equals(50));
      expect(halfModel.isGoalMet, isFalse);
      expect(halfModel.remainingMl, equals(1250));

      // 3000 ml logged (surplus, 120%) - Micro-correction 2 pinned!
      const surplusModel = HydrationDailyReadModel(
        localDate: '2026-09-08',
        totalMl: 3000,
        goalMl: 2500,
      );
      expect(surplusModel.clampedProgressRatio, equals(1.0), reason: 'Clamped ratio must never exceed 1.0');
      expect(surplusModel.rawProgressRatio, closeTo(1.2, 0.01));
      expect(surplusModel.progressPercent, equals(120));
      expect(surplusModel.isGoalMet, isTrue);
      expect(surplusModel.remainingMl, equals(0));
      expect(surplusModel.glassesCount(250), equals(12.0));
      expect(surplusModel.totalFlOz, closeTo(101.44, 0.1));
    });
  });

  group('PV1-HYD-01 HydrationRepository & Storage Invariants', () {
    test('logIntake records entry, computes total, and persists to SQLite atomically with UTC updatedAt', () async {
      final nowUtc = DateTime.utc(2026, 9, 8, 8, 15);
      final entry = await repo.logIntake(
        localDate: '2026-09-08',
        amountMl: 500,
        loggedAtUtc: nowUtc,
        source: 'quickAdd',
        containerType: 'bottle',
      );

      expect(entry.amountMl, equals(500));
      expect(entry.loggedAtUtc, equals(nowUtc));

      final readModel = await repo.getDailyHydration('2026-09-08');
      expect(readModel.totalMl, equals(500));
      expect(readModel.entries.length, equals(1));
      expect(readModel.entries.first.id, equals(entry.id));

      // Verify SQLite row
      final records = await db.select(db.dailyHydrations).get();
      expect(records.length, equals(1));
      expect(records.first.dateString, equals('2026-09-08'));
      expect(records.first.totalMl, equals(500));
      expect(records.first.goalMl, equals(2500));
      expect(records.first.updatedAt, isNotNull);
    });

    test('multiple intakes on same date sum correctly and deleting/editing updates total', () async {
      final e1 = await repo.logIntake(localDate: '2026-09-08', amountMl: 250);
      final e2 = await repo.logIntake(localDate: '2026-09-08', amountMl: 500);

      var read = await repo.getDailyHydration('2026-09-08');
      expect(read.totalMl, equals(750));
      expect(read.entries.length, equals(2));

      // Edit e1 from 250 to 300
      await repo.editIntake(localDate: '2026-09-08', entryId: e1.id, newAmountMl: 300);
      read = await repo.getDailyHydration('2026-09-08');
      expect(read.totalMl, equals(800));

      // Delete e2
      await repo.deleteIntake(localDate: '2026-09-08', entryId: e2.id);
      read = await repo.getDailyHydration('2026-09-08');
      expect(read.totalMl, equals(300));
      expect(read.entries.length, equals(1));
    });

    test('Invariant 1: durable SQLite row without itemized entries projects summary entry', () async {
      // Direct insertion into SQLite (simulating historical data or restore where entries were pruned)
      await db.into(db.dailyHydrations).insert(
        DailyHydrationsCompanion.insert(
          dateString: '2026-07-01',
          totalMl: 1750,
          goalMl: 2000,
          updatedAt: Value(DateTime.utc(2026, 7, 1, 20, 0)),
        ),
      );

      final read = await repo.getDailyHydration('2026-07-01');
      expect(read.totalMl, equals(1750));
      expect(read.goalMl, equals(2000));
      expect(read.entries.length, equals(1));
      expect(read.entries.first.source, equals('summary'));
      expect(read.entries.first.amountMl, equals(1750));
    });

    test('Invariant 3: 90-day retention bound prunes old entries from prefs while SQLite remains', () async {
      final prefs = await SharedPreferences.getInstance();

      // Log an entry for today
      await repo.logIntake(localDate: '2026-09-08', amountMl: 250);

      // Directly inject old entry in prefs older than 90 days (100 days ago)
      final oldDate = '2026-05-31';
      final oldJson = '{"$oldDate": [{"id": "old-1", "localDate": "$oldDate", "amountMl": 500, "loggedAtUtc": "2026-05-31T10:00:00.000Z", "source": "manual"}]}';
      await prefs.setString(HydrationRepository.prefHydrationEntriesJson, oldJson);

      // Direct insert into SQLite for old date
      await db.into(db.dailyHydrations).insert(
        DailyHydrationsCompanion.insert(
          dateString: oldDate,
          totalMl: 500,
          goalMl: 2500,
          updatedAt: Value(DateTime.utc(2026, 5, 31, 12)),
        ),
      );

      // Now log new intake: triggers retention prune
      await repo.logIntake(localDate: '2026-09-08', amountMl: 500);

      // Verify old date was pruned from prefs JSON
      final entriesJson = prefs.getString(HydrationRepository.prefHydrationEntriesJson)!;
      expect(entriesJson.contains(oldDate), isFalse, reason: 'Entries older than 90 days must be pruned from SharedPreferences');

      // Verify SQLite row for old date is still preserved
      final oldRecord = await (db.select(db.dailyHydrations)..where((tbl) => tbl.dateString.equals(oldDate))).getSingleOrNull();
      expect(oldRecord, isNotNull, reason: 'SQLite daily summary rows must remain permanent');
      expect(oldRecord!.totalMl, equals(500));
    });

    test('Micro-correction 1: setDailyGoal reconciles water_goal using live glass size from prefs', () async {
      final prefs = await SharedPreferences.getInstance();

      // Case A: 250ml glass (default), goal 2500ml -> 10 glasses
      await repo.setDailyGoal(goalMl: 2500);
      expect(prefs.getInt(HydrationRepository.prefHydrationDailyGoalMl), equals(2500));
      expect(prefs.getInt(HydrationRepository.prefWaterGoal), equals(10));

      // Case B: User has configured 350ml glass size -> goal 2500ml -> (2500/350).round() = 7 glasses
      await prefs.setInt(HydrationRepository.prefWaterGlassSize, 350);
      await repo.setDailyGoal(goalMl: 2500);
      expect(prefs.getInt(HydrationRepository.prefWaterGoal), equals(7),
          reason: 'Must use live glass size (350ml) to compute glasses = 7, not hardcoded 250ml');
    });

    test('updateGlassSize updates glass size and reconciles water_goal and water_logged', () async {
      final prefs = await SharedPreferences.getInstance();
      await repo.setDailyGoal(goalMl: 2500);
      await repo.logIntake(localDate: HydrationRepository.currentLocalDateKey(), amountMl: 1000);

      // Initial: 250ml glasses -> goal = 10, logged = 4
      expect(prefs.getInt(HydrationRepository.prefWaterGoal), equals(10));
      expect(prefs.getInt(HydrationRepository.prefWaterLogged), equals(4));

      // Update glass size to 500ml -> goal = 5, logged = 2
      await repo.updateGlassSize(500);
      expect(prefs.getInt(HydrationRepository.prefWaterGlassSize), equals(500));
      expect(prefs.getInt(HydrationRepository.prefWaterGoal), equals(5));
      expect(prefs.getInt(HydrationRepository.prefWaterLogged), equals(2));
    });

    test('clearAllData wipes SQLite table and all hydration preferences', () async {
      final prefs = await SharedPreferences.getInstance();
      await repo.logIntake(localDate: '2026-09-08', amountMl: 500);
      await repo.setDailyGoal(goalMl: 2500);

      await repo.clearAllData();

      final count = await db.select(db.dailyHydrations).get();
      expect(count, isEmpty);
      expect(prefs.getString(HydrationRepository.prefHydrationEntriesJson), isNull);
      expect(prefs.getInt(HydrationRepository.prefHydrationDailyGoalMl), isNull);
      expect(prefs.getInt(HydrationRepository.prefWaterLogged), isNull);
      expect(prefs.getInt(HydrationRepository.prefWaterGoal), isNull);
    });

    test('deleting summary entry resets SQLite row totalMl to 0 and clears legacy mirrors', () async {
      await db.into(db.dailyHydrations).insert(
        DailyHydrationsCompanion.insert(
          dateString: '2026-09-08',
          totalMl: 1500,
          goalMl: 2500,
          updatedAt: Value(DateTime.utc(2026, 9, 8, 8)),
        ),
      );
      final read = await repo.getDailyHydration('2026-09-08');
      expect(read.entries.length, equals(1));
      expect(read.entries.first.isSummary, isTrue);

      await repo.deleteIntake(localDate: '2026-09-08', entryId: read.entries.first.id);

      final afterDelete = await repo.getDailyHydration('2026-09-08');
      expect(afterDelete.totalMl, equals(0));
      expect(afterDelete.entries.isEmpty, isTrue);

      final row = await (db.select(db.dailyHydrations)..where((tbl) => tbl.dateString.equals('2026-09-08'))).getSingle();
      expect(row.totalMl, equals(0));
    });
  });

  group('PV1-HYD-01 Single Writer & WaterNotifier Unification', () {
    test('WaterNotifier delegates logWater to HydrationRepository without clobbering itemized entries', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          hydrationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(waterProvider.notifier);
      await notifier.loadState();

      // Log 2 glasses of 250ml = 500ml
      await notifier.logWater(2);

      final todayKey = HydrationRepository.currentLocalDateKey();
      final daily = await repo.getDailyHydration(todayKey);

      expect(daily.totalMl, equals(500));
      expect(daily.entries.length, equals(1));
      expect(daily.entries.first.source, equals('quickAdd'));
      expect(daily.entries.first.containerType, equals('glass'));

      // Verify legacy preference mirror was also updated
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('water_logged'), equals(2));
    });
  });

  group('PV1-HYD-01 TodayHydrationCard Widget', () {
    testWidgets('renders progress, summary, and quick-add buttons cleanly', (tester) async {
      const readModel = HydrationDailyReadModel(
        localDate: '2026-09-08',
        totalMl: 1500,
        goalMl: 2500,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            hydrationRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: TodayHydrationCard(
                hydrationRead: const TodayDomainRead.available(readModel),
                selectedDate: DateTime(2026, 9, 8),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HYDRATION'), findsOneWidget);
      expect(find.text('1500 / 2500 ml'), findsOneWidget);
      expect(find.text('1000 ml remaining (60%)'), findsOneWidget);
      expect(find.text('+250 ml'), findsOneWidget);
      expect(find.text('+500 ml'), findsOneWidget);

      // Verify hydration fluid fill indicator value
      final fluidIndicator = tester.widget<HydrationFluidFillIndicator>(
        find.byType(HydrationFluidFillIndicator),
      );
      expect(fluidIndicator.progress, closeTo(0.6, 0.01));
    });

    testWidgets('quick add +250 ml button triggers intake logging and updates repository', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            hydrationRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: TodayHydrationCard(
                hydrationRead: const TodayDomainRead.available(
                  HydrationDailyReadModel(
                    localDate: '2026-09-08',
                    totalMl: 0,
                    goalMl: 2500,
                  ),
                ),
                selectedDate: DateTime(2026, 9, 8),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<B05ActionButton>(
        find.widgetWithText(B05ActionButton, '+250 ml'),
      );

      await tester.runAsync(() async {
        button.onPressed!();
        for (var attempt = 0; attempt < 100; attempt++) {
          final daily = await repo.getDailyHydration('2026-09-08');
          if (daily.totalMl > 0) break;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      // Pump animation frame to show SnackBar
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Added 250 ml water'), findsOneWidget);

      // Verify repository state
      final daily = (await tester.runAsync(() => repo.getDailyHydration('2026-09-08')))!;
      expect(daily.totalMl, equals(250));
      expect(daily.entries.length, equals(1));

      // Pump past SnackBar dismiss timer
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('renders without overflow at 320pt and 2.0x text scaling', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 600 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            hydrationRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 600),
                textScaler: TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: TodayHydrationCard(
                  hydrationRead: const TodayDomainRead.available(
                    HydrationDailyReadModel(
                      localDate: '2026-09-08',
                      totalMl: 3000,
                      goalMl: 2500,
                    ),
                  ),
                  selectedDate: DateTime(2026, 9, 8),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Goal met! (120%)'), findsOneWidget);
    });

    testWidgets('tapping TodayHydrationCard opens HydrationDetailSheet when onTapDetail is null', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            hydrationRepositoryProvider.overrideWithValue(repo),
            hydrationDailyProvider.overrideWith((ref, localDate) async {
              return const HydrationDailyReadModel(
                localDate: '2026-09-08',
                totalMl: 1000,
                goalMl: 2500,
              );
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: TodayHydrationCard(
                hydrationRead: const TodayDomainRead.available(
                  HydrationDailyReadModel(
                    localDate: '2026-09-08',
                    totalMl: 1000,
                    goalMl: 2500,
                  ),
                ),
                selectedDate: DateTime(2026, 9, 8),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the card surface
      await tester.tap(find.byType(TodayHydrationCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HydrationDetailSheet), findsOneWidget);
      expect(find.text('QUICK ADD'), findsOneWidget);
      expect(find.text('DAILY GOAL'), findsOneWidget);
    });
  });

  group('PV1-HYD-01 Notification & Settings Integration', () {
    test('destinationForPayload("water") routes to dashboard root', () {
      expect(NotificationService.destinationForPayload('water'), '/');
    });

    test('scheduleAllReminders explicitly cancels water reminder ID 301 without cancelAll', () async {
      platformCalls.clear();
      await NotificationService.scheduleAllReminders(db);

      expect(platformCalls.any((call) => call.method == 'cancelAll'), isFalse);

      final cancelledIds = platformCalls
          .where((call) => call.method == 'cancel')
          .map((call) => (call.arguments as Map)['id'] as int)
          .toSet();

      expect(cancelledIds, contains(301));
      expect(cancelledIds, isNot(contains(998)));
      expect(cancelledIds, isNot(contains(999)));
    });

    test('water reminder scheduled during quiet hours defers to quiet hours end', () async {
      platformCalls.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(NotificationService.prefRemindWater, true);
      await prefs.setInt(NotificationService.prefWaterReminderHour, 23);
      await prefs.setInt(NotificationService.prefWaterReminderMinute, 0);
      await prefs.setBool(NotificationService.prefQuietHoursEnabled, true);
      await prefs.setInt(NotificationService.prefQuietHoursStart, 22);
      await prefs.setInt(NotificationService.prefQuietHoursEnd, 7);

      await NotificationService.scheduleAllReminders(db);

      final call = platformCalls.singleWhere(
        (candidate) =>
            candidate.method == 'zonedSchedule' &&
            (candidate.arguments as Map)['id'] == 301,
      );
      final arguments = Map<String, Object?>.from(call.arguments as Map);
      final scheduled = DateTime.parse(
        arguments['scheduledDateTime']! as String,
      );
      expect(scheduled.hour, 7);
      expect(scheduled.minute, 0);
    });

    test('SettingsController loads water reminder schedule and setHydrationDailyGoalMl synchronizes state and repository', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          hydrationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(settingsControllerProvider.notifier);
      await controller.loadPreferences();

      var state = container.read(settingsControllerProvider);
      expect(state.waterReminderHour, NotificationService.defaultWaterReminderHour);
      expect(state.waterReminderMinute, NotificationService.defaultWaterReminderMinute);

      await controller.updateWaterReminderSchedule(hour: 11, minute: 30);
      state = container.read(settingsControllerProvider);
      expect(state.waterReminderHour, 11);
      expect(state.waterReminderMinute, 30);

      await controller.setHydrationDailyGoalMl(3000);
      state = container.read(settingsControllerProvider);
      expect(state.waterGoal, 12); // 3000 / 250 = 12 glasses

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(HydrationRepository.prefHydrationDailyGoalMl), 3000);
      expect(prefs.getInt(HydrationRepository.prefWaterGoal), 12);
    });
  });

  group('PV1-HYD-01 HydrationDetailSheet Widget', () {
    Override hydrationDailyOverride() {
      return hydrationDailyProvider.overrideWith((ref, localDate) async {
        ref.watch(todayHydrationRevisionProvider);
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(HydrationRepository.prefHydrationEntriesJson);
        final goal = prefs.getInt(HydrationRepository.prefHydrationDailyGoalMl) ??
            HydrationRepository.defaultDailyGoalMl;
        if (raw != null) {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          final list = decoded[localDate] as List?;
          if (list != null && list.isNotEmpty) {
            final entries = list
                .map((e) => HydrationIntakeEntry.fromJson(e as Map<String, dynamic>))
                .toList()
              ..sort((a, b) => a.loggedAtUtc.compareTo(b.loggedAtUtc));
            final total = entries.fold<int>(0, (sum, e) => sum + e.amountMl);
            return HydrationDailyReadModel(
              localDate: localDate,
              totalMl: total,
              goalMl: goal,
              entries: entries,
            );
          }
        }
        return HydrationDailyReadModel(
          localDate: localDate,
          totalMl: 0,
          goalMl: goal,
        );
      });
    }

    testWidgets('renders header, progress, quick add buttons, custom intake, and reminder toggle', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            hydrationRepositoryProvider.overrideWithValue(repo),
            hydrationDailyOverride(),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: HydrationDetailSheet(
                selectedDate: DateTime(2026, 9, 8),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HYDRATION'), findsOneWidget);
      expect(find.text('QUICK ADD'), findsOneWidget);
      expect(find.text('CUSTOM INTAKE'), findsOneWidget);
      expect(find.text('DAILY GOAL'), findsOneWidget);
      expect(find.text('REMINDERS'), findsOneWidget);
      expect(find.text('Water reminder'), findsOneWidget);
    });

    testWidgets('quick add button logs intake and updates sheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            hydrationRepositoryProvider.overrideWithValue(repo),
            hydrationDailyOverride(),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: HydrationDetailSheet(
                selectedDate: DateTime(2026, 9, 8),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final add500Btn = tester.widget<B05ActionButton>(
        find.widgetWithText(B05ActionButton, '+500 ml'),
      );

      await tester.runAsync(() async {
        add500Btn.onPressed!();
        for (var attempt = 0; attempt < 100; attempt++) {
          final daily = await repo.getDailyHydration('2026-09-08');
          if (daily.totalMl > 0) break;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final daily = (await tester.runAsync(() => repo.getDailyHydration('2026-09-08')))!;
      expect(daily.totalMl, equals(500));
      expect(daily.entries.length, equals(1));
      expect(daily.entries.first.amountMl, equals(500));

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('custom intake logs entry with selected container and updates sheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            hydrationRepositoryProvider.overrideWithValue(repo),
            hydrationDailyOverride(),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: HydrationDetailSheet(
                selectedDate: DateTime(2026, 9, 8),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter 450 ml
      await tester.enterText(find.byType(TextField), '450');
      await tester.pumpAndSettle();

      // Tap Custom chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Custom'));
      await tester.pumpAndSettle();

      final logBtn = tester.widget<B05ActionButton>(
        find.widgetWithText(B05ActionButton, 'Log Water'),
      );

      await tester.runAsync(() async {
        logBtn.onPressed!();
        for (var attempt = 0; attempt < 100; attempt++) {
          final daily = await repo.getDailyHydration('2026-09-08');
          if (daily.totalMl > 0) break;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final daily = (await tester.runAsync(() => repo.getDailyHydration('2026-09-08')))!;
      expect(daily.totalMl, equals(450));
      expect(daily.entries.length, equals(1));
      expect(daily.entries.first.containerType, equals('custom'));

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('deleting an intake entry removes it and updates total', (tester) async {
      late HydrationDailyReadModel initialData;
      await tester.runAsync(() async {
        await repo.logIntake(
          localDate: '2026-09-08',
          amountMl: 300,
          source: 'manual',
          containerType: 'glass',
        );
        initialData = await repo.getDailyHydration('2026-09-08');
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            hydrationRepositoryProvider.overrideWithValue(repo),
            hydrationDailyOverride(),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: HydrationDetailSheet(
                selectedDate: DateTime(2026, 9, 8),
                initialData: initialData,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('300 ml'), findsOneWidget);

      final deleteBtn = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_outline_rounded),
      );

      await tester.runAsync(() async {
        deleteBtn.onPressed!();
        for (var attempt = 0; attempt < 100; attempt++) {
          final daily = await repo.getDailyHydration('2026-09-08');
          if (daily.totalMl == 0) break;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final daily = (await tester.runAsync(() => repo.getDailyHydration('2026-09-08')))!;
      expect(daily.totalMl, equals(0));
      expect(daily.entries.isEmpty, isTrue);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('goal adjustment steppers call setHydrationDailyGoalMl', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            hydrationRepositoryProvider.overrideWithValue(repo),
            hydrationDailyOverride(),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: HydrationDetailSheet(
                selectedDate: DateTime(2026, 9, 8),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final incBtn = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add_circle_outline),
      );

      await tester.runAsync(() async {
        incBtn.onPressed!();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(HydrationRepository.prefHydrationDailyGoalMl), equals(2750));
    });

    testWidgets('renders without overflow at 320pt and 2.0x scale', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 600 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            hydrationRepositoryProvider.overrideWithValue(repo),
            hydrationDailyOverride(),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 600),
                textScaler: TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: HydrationDetailSheet(
                  selectedDate: DateTime(2026, 9, 8),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('HYDRATION'), findsOneWidget);
    });
  });
}
