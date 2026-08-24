import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/models/b02_progress_read_models.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/data/repositories/dashboard_personalization_repository.dart';
import 'package:indifit/features/dashboard/dashboard_module_registry.dart';
import 'package:indifit/features/dashboard/dashboard_personalization_controller.dart';
import 'package:indifit/features/dashboard/today_consumer_presentation.dart';
import 'package:indifit/features/dashboard/today_daily_action_surface.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late DashboardPersonalizationController personalization;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.memory();
    personalization = _SeededPersonalizationController(
      repository: DashboardPersonalizationRepository(
        database: database,
        registry: standardDashboardModuleRegistry,
      ),
      layout: _evidenceLayout(),
    );
    await personalization.load();
  });

  tearDown(() => database.close());

  test('optional evidence fails closed when its canonical read is empty', () {
    final empty = const TodayDomainRead<B02ProgressReadModel>.available(
      B02ProgressReadModel(
        query: B02ProgressQuery(
          startLocalDate: '2026-08-03',
          endLocalDate: '2026-08-09',
          timezoneId: 'Asia/Kolkata',
        ),
        activityHistory: [],
        groupHistory: null,
        targetEvidence: null,
        muscleVolume: null,
      ),
    );

    final activity = TodayActivityPresentation.from(empty, loading: false);
    final progress = TodayProgressPresentation.from(empty, loading: false);
    final failed = TodayActivityPresentation.from(
      const TodayDomainRead.unavailable('database failed'),
      loading: false,
    );

    expect(activity.state, TodayPresentationState.empty);
    expect(activity.shouldRender, isFalse);
    expect(progress.state, TodayPresentationState.empty);
    expect(progress.shouldRender, isFalse);
    expect(failed.shouldRender, isFalse);
  });

  test('activity and progress expose only factual B02 evidence', () {
    final read = TodayDomainRead.available(_progressWithEvidence());

    final activity = TodayActivityPresentation.from(read, loading: false);
    final progress = TodayProgressPresentation.from(read, loading: false);
    final copy = [
      activity.headline,
      activity.detail,
      activity.latestActivity,
      progress.headline,
      progress.detail,
      progress.supporting,
    ].whereType<String>().join(' ');

    expect(activity.shouldRender, isTrue);
    expect(activity.sessionCount, 1);
    expect(activity.detail, '1 session logged');
    expect(progress.shouldRender, isTrue);
    expect(progress.headline, 'Bench press');
    expect(progress.detail, '3 working sets recorded');
    expect(copy.toLowerCase(), isNot(contains('calorie')));
    expect(copy.toLowerCase(), isNot(contains('readiness')));
    expect(copy.toLowerCase(), isNot(contains('e1rm')));
    expect(RegExp(r'\bpr\b').hasMatch(copy.toLowerCase()), isFalse);
  });

  test('Next Up has no generic fallback action without canonical work', () {
    final snapshot = TodaySurfaceSnapshot(
      selectedDate: DateTime(2026, 8, 9),
      localDate: '2026-08-09',
      timezoneId: 'Asia/Kolkata',
      calendar: const TodayDomainRead.available(
        CalendarReadSnapshot(
          rangeOccurrences: [],
          overdueOccurrences: [],
          activeProgramVersionId: null,
          activeProgramName: null,
        ),
      ),
      progress: TodayDomainRead.available(_emptyProgress()),
      nutrition: const TodayDomainRead.unavailable('not loaded'),
    );

    final focus = todayFocusPresentation(
      dateRelation: TodayDateRelation.today,
      snapshot: snapshot,
    );

    expect(focus.state, TodayPresentationState.empty);
    expect(focus.action, isNull);
    expect(focus.shouldRender, isFalse);
  });

  testWidgets('evidence modules render facts at narrow width and large text', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 8, 9);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardPersonalizationControllerProvider.overrideWith(
            (ref) => personalization,
          ),
          todaySurfaceSnapshotProvider.overrideWith(
            (ref, date) async => TodaySurfaceSnapshot(
              selectedDate: date,
              localDate: '2026-08-09',
              timezoneId: 'Asia/Kolkata',
              calendar: const TodayDomainRead.available(
                CalendarReadSnapshot(
                  rangeOccurrences: [],
                  overdueOccurrences: [],
                  activeProgramVersionId: null,
                  activeProgramName: null,
                ),
              ),
              progress: TodayDomainRead.available(_progressWithEvidence()),
              nutrition: const TodayDomainRead.unavailable('not loaded'),
            ),
          ),
        ],
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 900),
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: TodayDailyActionSurface(
              selectedDate: selectedDate,
              now: selectedDate,
              userName: 'Ari',
              streakCount: 0,
              onDateChanged: (_) {},
              onRefresh: () async {},
              onOpenSettings: () {},
              onCustomize: () {},
              onOpenWorkoutPlan: () {},
              onLogMeal: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.text('Bench press'), findsOneWidget);
    expect(find.text('No activity yet'), findsNothing);
    expect(find.text('No progress yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('future Today hides trailing-range evidence', (tester) async {
    final selectedDate = DateTime(2026, 8, 10);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardPersonalizationControllerProvider.overrideWith(
            (ref) => personalization,
          ),
          todaySurfaceSnapshotProvider.overrideWith(
            (ref, date) async => TodaySurfaceSnapshot(
              selectedDate: date,
              localDate: '2026-08-10',
              timezoneId: 'Asia/Kolkata',
              calendar: const TodayDomainRead.available(
                CalendarReadSnapshot(
                  rangeOccurrences: [],
                  overdueOccurrences: [],
                  activeProgramVersionId: null,
                  activeProgramName: null,
                ),
              ),
              // This rolling range includes 9 August. It must not appear as
              // evidence while the selected Today context is 10 August.
              progress: TodayDomainRead.available(_progressWithEvidence()),
              nutrition: const TodayDomainRead.unavailable('not loaded'),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: TodayDailyActionSurface(
            selectedDate: selectedDate,
            now: DateTime(2026, 8, 9),
            userName: 'Ari',
            streakCount: 0,
            onDateChanged: (_) {},
            onRefresh: () async {},
            onOpenSettings: () {},
            onCustomize: () {},
            onOpenWorkoutPlan: () {},
            onLogMeal: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Plan ahead'), findsOneWidget);
    expect(find.text('Recent activity'), findsNothing);
    expect(find.text('Bench press'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

List<DashboardModuleLayoutItem> _evidenceLayout() {
  final defaults = standardDashboardModuleRegistry.normalize(const []);
  return [
    defaults[0].copyWith(ordinal: 0, isVisible: true),
    defaults[1].copyWith(ordinal: 1, isVisible: false),
    defaults[2].copyWith(ordinal: 2, isVisible: false),
    defaults[4].copyWith(ordinal: 3, isVisible: true),
    defaults[5].copyWith(ordinal: 4, isVisible: true),
  ];
}

B02ProgressReadModel _emptyProgress() => const B02ProgressReadModel(
  query: B02ProgressQuery(
    startLocalDate: '2026-08-03',
    endLocalDate: '2026-08-09',
    timezoneId: 'Asia/Kolkata',
  ),
  activityHistory: [],
  groupHistory: null,
  targetEvidence: null,
  muscleVolume: null,
);

B02ProgressReadModel _progressWithEvidence() => B02ProgressReadModel(
  query: const B02ProgressQuery(
    startLocalDate: '2026-08-03',
    endLocalDate: '2026-08-09',
    timezoneId: 'Asia/Kolkata',
  ),
  activityHistory: [
    B02ProgressActivityRecord(
      sessionId: 1,
      name: 'Push session',
      activityType: B02ActivityType.strength,
      recordKind: B02HistoryRecordKind.canonical,
      completedAtUtc: DateTime.utc(2026, 8, 9, 8),
      durationSeconds: 2700,
      source: B02ActivitySource.manual,
      legacySetCount: 0,
      performedExerciseCount: 1,
      performedGroupCount: 0,
      cardioIntervalCount: 0,
      hasCardioDetail: false,
      hasMobilityDetail: false,
      cardioDetail: null,
      mobilityDetail: null,
    ),
  ],
  groupHistory: null,
  targetEvidence: [
    B02ProgressTargetEvidence(
      sessionId: 1,
      completedAtUtc: DateTime.utc(2026, 8, 9, 8),
      performedExerciseId: 'performed-exercise-1',
      actualExerciseId: 'bench-press',
      actualExerciseName: 'Bench press',
      status: 'completed',
      expectedExerciseName: null,
      substitutionReason: null,
      workingSetCount: 3,
      totalSetCount: 3,
      recommendation: null,
    ),
  ],
  muscleVolume: null,
);

class _SeededPersonalizationController
    extends DashboardPersonalizationController {
  _SeededPersonalizationController({
    required super.repository,
    required List<DashboardModuleLayoutItem> layout,
  }) : _layout = layout,
       super(userId: 'local-nutrition-user');

  final List<DashboardModuleLayoutItem> _layout;

  @override
  Future<void> load() async {
    state = DashboardPersonalizationState(
      status: DashboardPersonalizationStatus.ready,
      layout: List.unmodifiable(_layout),
    );
  }
}
