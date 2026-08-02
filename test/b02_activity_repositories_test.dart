import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_activity_session_repository.dart';
import 'package:indifit/data/repositories/b02_health_activity_repository.dart';
import 'package:indifit/features/activity/b02_activity_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ActivitySessionRepository activities;

  setUp(() {
    db = AppDatabase.memory();
    activities = ActivitySessionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  B02CardioSessionDetail manualRunningDetail() => B02CardioSessionDetail(
    activityType: B02ActivityType.running,
    durationSeconds: 1500,
    distanceMetres: 5000,
    observedPaceSecondsPerKm: 300,
    inputMode: B02InputMode.manual,
    isIntervalWorkout: true,
    intervals: [
      B02CardioInterval(
        id: 'interval-0',
        ordinal: 0,
        segmentType: B02CardioSegmentType.work,
        durationSeconds: 300,
      ),
      B02CardioInterval(
        id: 'interval-1',
        ordinal: 1,
        segmentType: B02CardioSegmentType.recovery,
        durationSeconds: 120,
      ),
      B02CardioInterval(
        id: 'interval-2',
        ordinal: 2,
        segmentType: B02CardioSegmentType.work,
        durationSeconds: 300,
      ),
    ],
  );

  B02HealthActivityInput importedRunning({
    String provider = 'health_connect',
    String externalId = 'provider-run-1',
    String fingerprint = 'fingerprint-run-1',
  }) => B02HealthActivityInput(
    provider: provider,
    providerType: provider == 'health_connect'
        ? 'EXERCISE_SESSION_TYPE_RUNNING'
        : 'HKWorkoutActivityTypeRunning',
    sourceName: provider == 'health_connect'
        ? 'Health Connect'
        : 'Apple Health',
    externalId: externalId,
    fingerprint: fingerprint,
    startedAtUtc: DateTime.utc(2026, 1, 1, 6),
    endedAtUtc: DateTime.utc(2026, 1, 1, 6, 25),
    distanceMetres: 5000,
    estimatedCalories: 350,
  );

  group('B02 typed activity repositories', () {
    test('completes a manual running draft with ordered intervals', () async {
      final draft = await activities.createManualDraft(
        routineName: 'Intervals',
        activityType: B02ActivityType.running,
        cardioDetail: manualRunningDetail(),
      );

      final restored = await activities.readDraft(draft.id);
      expect(restored!.state.cardioDetail!.intervals, hasLength(3));
      expect(
        restored.state.cardioDetail!.intervals.map(
          (interval) => interval.ordinal,
        ),
        [0, 1, 2],
      );

      final sessionId = await activities.completeDraft(draft.id);
      final session = await (db.select(
        db.workoutSessions,
      )..where((table) => table.id.equals(sessionId))).getSingle();
      expect(session.activityType, 'running');
      expect(session.durationSeconds, 1500);
      expect(await db.select(db.workoutSets).get(), isEmpty);

      final details = await db.select(db.cardioSessionDetails).get();
      expect(details, hasLength(1));
      expect(details.single.inputMode, 'manual');
      expect(await db.select(db.cardioIntervals).get(), hasLength(3));
      expect(await activities.readDraft(draft.id), isNull);

      final history = await activities.readTypedActivity(sessionId);
      expect(history!.activityType, B02ActivityType.running);
      expect(history.source, B02ActivitySource.manual);
      expect(history.cardioIntervals.map((interval) => interval.ordinal), [
        0,
        1,
        2,
      ]);
      expect(history.isImmutable, isTrue);
    });

    test(
      'completes yoga and mobility as duration-only activity records',
      () async {
        final yogaDraft = await activities.startManualDraft(
          routineName: 'Evening yoga',
          activityType: B02ActivityType.yoga,
          mobilityDetail: B02MobilitySessionDetail(
            practiceType: B02ActivityType.yoga,
            durationSeconds: 1800,
            style: 'vinyasa',
            focusNote: 'hips',
          ),
        );
        final mobilityDraft = await activities.startManualDraft(
          routineName: 'Mobility reset',
          activityType: B02ActivityType.mobility,
          mobilityDetail: B02MobilitySessionDetail(
            practiceType: B02ActivityType.mobility,
            durationSeconds: 600,
          ),
        );

        final yogaSessionId = await activities.completeDraft(yogaDraft.id);
        final mobilitySessionId = await activities.completeDraft(
          mobilityDraft.id,
        );
        final yoga = await activities.readTypedActivity(yogaSessionId);
        final mobility = await activities.readTypedActivity(mobilitySessionId);

        expect(yoga!.mobilityDetail!.practiceType, B02ActivityType.yoga);
        expect(yoga.mobilityDetail!.durationSeconds, 1800);
        expect(
          mobility!.mobilityDetail!.practiceType,
          B02ActivityType.mobility,
        );
        expect(mobility.mobilityDetail!.durationSeconds, 600);
        expect(yoga.cardioDetail, isNull);
        expect(mobility.cardioDetail, isNull);
        expect(await db.select(db.workoutSets).get(), isEmpty);
        expect(await db.select(db.cardioSessionDetails).get(), isEmpty);
        expect(await db.select(db.mobilitySessionDetails).get(), hasLength(2));
      },
    );

    test('rejects non-interval cardio segments without interval intent', () {
      final detail = B02CardioSessionDetail(
        activityType: B02ActivityType.walking,
        durationSeconds: 600,
        inputMode: B02InputMode.manual,
        intervals: [
          B02CardioInterval(
            id: 'interval',
            ordinal: 0,
            segmentType: B02CardioSegmentType.work,
            durationSeconds: 60,
          ),
        ],
      );
      expect(detail.intervals, hasLength(1));
      expect(
        () => activities.createManualDraft(
          routineName: 'Invalid intervals',
          activityType: B02ActivityType.walking,
          cardioDetail: detail,
        ),
        throwsA(isA<B02ValidationException>()),
      );
    });

    test('supports manual cycling and walking alongside running', () async {
      for (final activityType in [
        B02ActivityType.cycling,
        B02ActivityType.walking,
      ]) {
        final draft = await activities.createManualDraft(
          routineName: activityType.dbValue,
          activityType: activityType,
          cardioDetail: B02CardioSessionDetail(
            activityType: activityType,
            durationSeconds: 900,
            inputMode: B02InputMode.manual,
          ),
        );
        final sessionId = await activities.completeDraft(draft.id);
        expect(
          (await activities.readTypedActivity(sessionId))!.activityType,
          activityType,
        );
      }
    });

    test(
      'supports typed history filters and keeps legacy sessions out',
      () async {
        final yogaDraft = await activities.createManualDraft(
          routineName: 'Yoga',
          activityType: B02ActivityType.yoga,
          mobilityDetail: B02MobilitySessionDetail(
            practiceType: B02ActivityType.yoga,
            durationSeconds: 900,
          ),
        );
        await activities.completeDraft(yogaDraft.id);
        await db
            .into(db.workoutSessions)
            .insert(
              WorkoutSessionsCompanion.insert(
                name: 'Legacy history',
                totalVolume: 10,
                durationSeconds: 300,
                estimatedCalories: 20,
              ),
            );

        final allTyped = await activities.readTypedHistory();
        final yogaOnly = await activities.readTypedHistory(
          activityType: B02ActivityType.yoga,
        );
        expect(allTyped, hasLength(1));
        expect(allTyped.single.activityType, B02ActivityType.yoga);
        expect(yogaOnly, hasLength(1));
      },
    );
  });

  group('B02 Health mapping repositories', () {
    test('uses only the reviewed provider mapping', () {
      expect(
        B02HealthProviderTypeMapping.mapProviderType(
          'health_connect',
          'EXERCISE_SESSION_TYPE_RUNNING',
        ),
        B02ActivityType.running,
      );
      expect(
        B02HealthProviderTypeMapping.mapProviderType(
          'health_kit',
          'HKWorkoutActivityTypeCycling',
        ),
        B02ActivityType.cycling,
      );
      expect(
        B02HealthProviderTypeMapping.mapProviderType(
          'health_connect',
          'EXERCISE_SESSION_TYPE_OTHER_WORKOUT',
        ),
        isNull,
      );
      expect(
        B02HealthProviderTypeMapping.providerTypeFor(
          HealthPlatformType.googleHealthConnect,
          HealthWorkoutActivityType.WALKING,
        ),
        'EXERCISE_SESSION_TYPE_WALKING',
      );
      expect(
        B02HealthProviderTypeMapping.providerTypeFor(
          HealthPlatformType.appleHealth,
          HealthWorkoutActivityType.RUNNING,
        ),
        'HKWorkoutActivityTypeRunning',
      );
      expect(
        B02HealthProviderTypeMapping.providerTypeFor(
          HealthPlatformType.appleHealth,
          HealthWorkoutActivityType.OTHER,
        ),
        isNull,
      );
    });

    test(
      'imports once, suppresses duplicates, and keeps providers distinct',
      () async {
        final imports = HealthActivityImportRepository(db, activities);
        final first = await imports.importActivity(importedRunning());
        final duplicate = await imports.importActivity(importedRunning());
        final otherProvider = await imports.importActivity(
          importedRunning(provider: 'health_kit'),
        );

        expect(first.status, B02HealthImportStatus.imported);
        expect(duplicate.status, B02HealthImportStatus.duplicate);
        expect(duplicate.localSessionId, first.localSessionId);
        expect(otherProvider.status, B02HealthImportStatus.imported);
        expect(await db.select(db.workoutSessions).get(), hasLength(2));
        expect(await db.select(db.healthProvenances).get(), hasLength(2));
        expect(
          (await db.select(db.healthProvenances).get())
              .map((provenance) => provenance.provider)
              .toSet(),
          {'health_connect', 'health_kit'},
        );

        final history = await activities.readTypedHistory(
          activityType: B02ActivityType.running,
        );
        expect(history, hasLength(2));
        expect(history.every((record) => record.isImported), isTrue);
        expect(history.every((record) => record.cardioDetail != null), isTrue);
        expect(
          history.every((record) => record.estimatedCalories == 350),
          isTrue,
        );
      },
    );

    test(
      'imports every reviewed cardio modality and preserves interval facts',
      () async {
        final imports = HealthActivityImportRepository(db, activities);
        final cycling = B02HealthActivityInput(
          provider: 'health_connect',
          providerType: 'EXERCISE_SESSION_TYPE_BIKING',
          sourceName: 'Health Connect',
          externalId: 'provider-cycle-1',
          fingerprint: 'fingerprint-cycle-1',
          startedAtUtc: DateTime.utc(2026, 1, 2, 6),
          endedAtUtc: DateTime.utc(2026, 1, 2, 6, 30),
          distanceMetres: 12000,
          isIntervalWorkout: true,
          intervals: [
            B02CardioInterval(
              id: 'cycle-work',
              ordinal: 0,
              segmentType: B02CardioSegmentType.work,
              durationSeconds: 300,
            ),
            B02CardioInterval(
              id: 'cycle-recovery',
              ordinal: 1,
              segmentType: B02CardioSegmentType.recovery,
              durationSeconds: 120,
            ),
          ],
        );
        final walking = B02HealthActivityInput(
          provider: 'health_connect',
          providerType: 'EXERCISE_SESSION_TYPE_WALKING',
          sourceName: 'Health Connect',
          externalId: 'provider-walk-1',
          fingerprint: 'fingerprint-walk-1',
          startedAtUtc: DateTime.utc(2026, 1, 3, 6),
          endedAtUtc: DateTime.utc(2026, 1, 3, 6, 20),
          distanceMetres: 1500,
        );
        final results = <B02HealthImportResult>[];
        results.add(await imports.importActivity(importedRunning()));
        results.add(await imports.importActivity(cycling));
        results.add(await imports.importActivity(walking));

        expect(results.map((result) => result.status), [
          B02HealthImportStatus.imported,
          B02HealthImportStatus.imported,
          B02HealthImportStatus.imported,
        ]);
        final history = await activities.readTypedHistory();
        expect(history.map((record) => record.activityType).toSet(), {
          B02ActivityType.running,
          B02ActivityType.cycling,
          B02ActivityType.walking,
        });
        final cyclingHistory = history.singleWhere(
          (record) => record.activityType == B02ActivityType.cycling,
        );
        expect(cyclingHistory.cardioIntervals, hasLength(2));
        expect(
          cyclingHistory.cardioIntervals.first.segmentType,
          B02CardioSegmentType.work,
        );
      },
    );

    test(
      'keeps unknown and invalid provider records visible without importing',
      () async {
        final imports = HealthActivityImportRepository(db, activities);
        final unknown = await imports.importActivity(
          B02HealthActivityInput(
            provider: 'health_connect',
            providerType: 'EXERCISE_SESSION_TYPE_OTHER_WORKOUT',
            sourceName: 'Health Connect',
            externalId: 'unknown-1',
            fingerprint: 'unknown-fingerprint',
            startedAtUtc: DateTime.utc(2026, 1, 1),
            endedAtUtc: DateTime.utc(2026, 1, 1, 1),
          ),
        );
        final invalid = await imports.importActivity(
          B02HealthActivityInput(
            provider: 'health_connect',
            providerType: 'EXERCISE_SESSION_TYPE_RUNNING',
            sourceName: 'Health Connect',
            externalId: 'invalid-1',
            fingerprint: 'invalid-fingerprint',
            startedAtUtc: DateTime.utc(2026, 1, 1, 2),
            endedAtUtc: DateTime.utc(2026, 1, 1, 2),
          ),
        );

        expect(unknown.status, B02HealthImportStatus.unsupported);
        expect(unknown.imported, isFalse);
        expect(invalid.status, B02HealthImportStatus.invalid);
        expect(invalid.imported, isFalse);
        expect(await db.select(db.workoutSessions).get(), isEmpty);
        expect(await db.select(db.healthProvenances).get(), isEmpty);
        expect(
          unknown.toDisplayMap(unknownInput(unknown)).containsKey('reason'),
          isTrue,
        );
      },
    );

    test(
      'maps exports to native workout types and refuses unsupported mobility export',
      () {
        expect(
          HealthActivityExportRepository.nativeTypeFor(
            B02ActivityType.strength,
            HealthPlatformType.appleHealth,
          ),
          HealthWorkoutActivityType.STRENGTH_TRAINING,
        );
        expect(
          HealthActivityExportRepository.nativeTypeFor(
            B02ActivityType.running,
            HealthPlatformType.googleHealthConnect,
          ),
          HealthWorkoutActivityType.RUNNING,
        );
        expect(
          HealthActivityExportRepository.nativeTypeFor(
            B02ActivityType.cycling,
            HealthPlatformType.appleHealth,
          ),
          HealthWorkoutActivityType.BIKING,
        );
        expect(
          HealthActivityExportRepository.nativeTypeFor(
            B02ActivityType.walking,
            HealthPlatformType.appleHealth,
          ),
          HealthWorkoutActivityType.WALKING,
        );
        expect(
          HealthActivityExportRepository.nativeTypeFor(
            B02ActivityType.yoga,
            HealthPlatformType.appleHealth,
          ),
          HealthWorkoutActivityType.YOGA,
        );
        expect(
          HealthActivityExportRepository.nativeTypeFor(
            B02ActivityType.mobility,
            HealthPlatformType.appleHealth,
          ),
          isNull,
        );
      },
    );
  });

  test(
    'controller exposes loading, draft-ready and completed transitions',
    () async {
      final controller = B02ActivityController(activities);
      addTearDown(controller.dispose);

      await controller.startManual(
        routineName: 'Controller yoga',
        activityType: B02ActivityType.yoga,
        mobilityDetail: B02MobilitySessionDetail(
          practiceType: B02ActivityType.yoga,
          durationSeconds: 300,
        ),
      );
      expect(controller.state.status, B02ActivityControllerStatus.draftReady);
      expect(controller.state.draft, isNotNull);

      await controller.completeDraft();
      expect(controller.state.status, B02ActivityControllerStatus.completed);
      expect(controller.state.completedSessionId, isNotNull);
    },
  );

  test(
    'activity controller exposes partial and recovery without losing draft',
    () async {
      final controller = B02ActivityController(activities);
      addTearDown(controller.dispose);

      await controller.startManual(
        routineName: 'Recoverable mobility',
        activityType: B02ActivityType.mobility,
        mobilityDetail: B02MobilitySessionDetail(
          practiceType: B02ActivityType.mobility,
          durationSeconds: 300,
        ),
      );
      final draft = controller.state.draft!;
      await controller.saveDraft(draft.state);
      expect(controller.state.status, B02ActivityControllerStatus.partial);
      expect(controller.state.draft?.id, draft.id);

      await controller.recover(draft.id);
      expect(controller.state.status, B02ActivityControllerStatus.draftReady);
      await controller.discard();
      expect(controller.state.status, B02ActivityControllerStatus.idle);

      await controller.recover(draft.id);
      expect(controller.state.status, B02ActivityControllerStatus.recovery);
      expect(controller.state.errorMessage, contains('unavailable'));
    },
  );
}

B02HealthActivityInput unknownInput(B02HealthImportResult result) =>
    B02HealthActivityInput(
      provider: result.provider,
      providerType: result.providerType,
      sourceName: 'Health Connect',
      externalId: result.externalId,
      fingerprint: result.fingerprint,
      startedAtUtc: DateTime.utc(2026, 1, 1),
      endedAtUtc: DateTime.utc(2026, 1, 1, 1),
    );
