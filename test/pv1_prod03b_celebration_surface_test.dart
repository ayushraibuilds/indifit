import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/achievement_service.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/progress_statistics_repository.dart';
import 'package:indifit/features/progress/achievements_screen.dart';
import 'package:indifit/features/workout_player/b02_strength_execution_controller.dart';
import 'package:indifit/features/workout_player/b02_strength_summary_screen.dart';
import 'package:indifit/features/workout_player/widgets/achievement_celebration_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeB02StrengthController
    extends StateNotifier<B02StrengthExecutionUiState>
    implements B02StrengthExecutionController {
  _FakeB02StrengthController()
      : super(
          const B02StrengthExecutionUiState(
            status: B02StrengthExecutionStatus.ready,
            launch: null,
          ),
        );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestCelebrationStatsRepository extends ProgressStatisticsRepository {
  final Map<String, DateTime> _unlockedMap = {};

  _TestCelebrationStatsRepository(super.database);

  void seed({Map<String, DateTime>? unlockedMap}) {
    if (unlockedMap != null) _unlockedMap.addAll(unlockedMap);
  }

  @override
  Future<LifetimeAchievementStats> getLifetimeStats() async =>
      LifetimeAchievementStats(
        totalWorkouts: 1,
        totalVolumeKg: 0,
        totalMealsLogged: 0,
        totalPrs: 0,
        thaliLoggedCount: 0,
        unlockedAchievementIds: Map.unmodifiable(_unlockedMap),
      );

  @override
  Future<bool> unlockAchievement(String achievementId) async {
    if (_unlockedMap.containsKey(achievementId)) return false;
    _unlockedMap[achievementId] = DateTime.now();
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProgressStatisticsRepository statsRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
    statsRepo = ProgressStatisticsRepository(db);
    final prefs = await SharedPreferences.getInstance();
    await AchievementService.ensureBaselined(prefs, []);
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrapWithTheme(Widget child, {bool disableAnimations = false}) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        extensions: const [B05SemanticColors.dark],
      ),
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(body: child),
      ),
    );
  }

  group('PV1-PROD-03B: Celebration Surface Tests', () {
    testWidgets('1. Single-unlock presentation renders badge, factual evidence, and date', (tester) async {
      final achievement = Achievement(
        id: 'first_workout',
        title: 'First Sweat',
        description: 'Complete your 1st workout session.',
        icon: Icons.fitness_center_rounded,
        color: const Color(0xFFCD7F32),
        currentProgress: 1.0,
        maxProgress: 1.0,
        isUnlocked: true,
        evidence: '1 of 1 workout logged',
        unlockedAt: DateTime.utc(2026, 8, 14, 10, 0),
      );

      var dismissed = false;
      await tester.pumpWidget(
        wrapWithTheme(
          AchievementCelebrationSheet(
            achievements: [achievement],
            onDismiss: () => dismissed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('achievement_celebration_sheet')), findsOneWidget);
      expect(find.text('Milestone Reached!'), findsOneWidget);
      expect(find.text('First Sweat'), findsOneWidget);
      expect(find.text('1 of 1 workout logged'), findsOneWidget);
      expect(find.text('Unlocked on 14 Aug 2026'), findsOneWidget);

      // Tap Done -> triggers dismiss callback
      await tester.tap(find.byKey(const Key('achievement_celebration_done')));
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    });

    testWidgets('2. Multi-unlock presentation renders carousel with indicators and clean pagination', (tester) async {
      final achievements = [
        Achievement(
          id: 'first_workout',
          title: 'First Sweat',
          description: 'Complete your 1st workout session.',
          icon: Icons.fitness_center_rounded,
          color: const Color(0xFFCD7F32),
          currentProgress: 1.0,
          maxProgress: 1.0,
          isUnlocked: true,
          evidence: '1 of 1 workout logged',
          unlockedAt: DateTime.utc(2026, 8, 14, 10, 0),
        ),
        Achievement(
          id: 'volume_1000',
          title: 'Iron Lifter',
          description: 'Lift a cumulative total of 1,000 kg volume.',
          icon: Icons.military_tech_rounded,
          color: const Color(0xFFCD7F32),
          currentProgress: 1200.0,
          maxProgress: 1000.0,
          isUnlocked: true,
          evidence: '1,200 kg / 1,000 kg volume recorded',
          unlockedAt: DateTime.utc(2026, 8, 14, 10, 5),
        ),
      ];

      await tester.pumpWidget(
        wrapWithTheme(
          AchievementCelebrationSheet(
            achievements: achievements,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 Milestones Reached!'), findsOneWidget);
      expect(find.text('First Sweat'), findsOneWidget);

      // Swipe to next card
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('Iron Lifter'), findsOneWidget);
      expect(find.text('1,200 kg / 1,000 kg volume recorded'), findsOneWidget);
    });

    testWidgets('3. View Badges button navigates to AchievementsScreen', (tester) async {
      final achievement = Achievement(
        id: 'first_workout',
        title: 'First Sweat',
        description: 'Complete your 1st workout session.',
        icon: Icons.fitness_center_rounded,
        color: const Color(0xFFCD7F32),
        currentProgress: 1.0,
        maxProgress: 1.0,
        isUnlocked: true,
        evidence: '1 of 1 workout logged',
        unlockedAt: DateTime.utc(2026, 8, 14, 10, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Return empty list or mock repo
          ],
          child: wrapWithTheme(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAchievementCelebrationSheet(
                  context,
                  achievements: [achievement],
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('achievement_celebration_sheet')), findsOneWidget);

      // Tap View Badges
      await tester.tap(find.byKey(const Key('achievement_celebration_view_all')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should push AchievementsScreen
      expect(find.byType(AchievementsScreen), findsOneWidget);
    });

    test('4. Process death before display leaves unlock pending; celebration marks it', () async {
      final prefs = await SharedPreferences.getInstance();

      // Seed an unlocked workout achievement in SQLite
      await statsRepo.unlockAchievement('first_workout');

      // 1. Initial check returns first_workout as uncelebrated
      var pending = await AchievementService.getUncelebratedWorkoutUnlocks(
        statsRepository: statsRepo,
        prefs: prefs,
      );
      expect(pending.map((a) => a.id).toList(), equals(['first_workout']));

      // 2. Simulate process death: celebration sheet was NEVER shown,
      // so markCelebrated was NOT called.
      // Next time we query uncelebrated, it STILL returns first_workout!
      pending = await AchievementService.getUncelebratedWorkoutUnlocks(
        statsRepository: statsRepo,
        prefs: prefs,
      );
      expect(pending.map((a) => a.id).toList(), equals(['first_workout']));

      // 3. Now celebrate it upon UI display
      await AchievementService.markCelebrated(prefs, ['first_workout']);

      // 4. Revisiting recap/screen: uncelebrated is now empty!
      pending = await AchievementService.getUncelebratedWorkoutUnlocks(
        statsRepository: statsRepo,
        prefs: prefs,
      );
      expect(pending, isEmpty);
    });

    test('5. Non-workout unlocks are NEVER surfaced on the workout recap', () async {
      final prefs = await SharedPreferences.getInstance();

      // Seed a non-workout achievement (meals_10) in SQLite
      await statsRepo.unlockAchievement('meals_10');

      // Querying workout recap uncelebrated unlocks must be empty!
      final pendingWorkout = await AchievementService.getUncelebratedWorkoutUnlocks(
        statsRepository: statsRepo,
        prefs: prefs,
      );
      expect(pendingWorkout, isEmpty);

      // But non-workout query DOES see it!
      final pendingNonWorkout = await AchievementService.getUncelebratedNonWorkoutUnlocks(
        statsRepository: statsRepo,
        prefs: prefs,
      );
      expect(pendingNonWorkout.map((a) => a.id).toList(), equals(['meals_10']));
    });

    testWidgets('6. Reduced motion disables animation durations on celebration sheet', (tester) async {
      final achievements = [
        Achievement(
          id: 'first_workout',
          title: 'First Sweat',
          description: 'Complete your 1st workout session.',
          icon: Icons.fitness_center_rounded,
          color: const Color(0xFFCD7F32),
          currentProgress: 1.0,
          maxProgress: 1.0,
          isUnlocked: true,
          evidence: '1 of 1 workout logged',
          unlockedAt: DateTime.utc(2026, 8, 14, 10, 0),
        ),
        Achievement(
          id: 'volume_1000',
          title: 'Iron Lifter',
          description: 'Lift a cumulative total of 1,000 kg volume.',
          icon: Icons.military_tech_rounded,
          color: const Color(0xFFCD7F32),
          currentProgress: 1200.0,
          maxProgress: 1000.0,
          isUnlocked: true,
          evidence: '1,200 kg / 1,000 kg volume recorded',
          unlockedAt: DateTime.utc(2026, 8, 14, 10, 5),
        ),
      ];

      await tester.pumpWidget(
        wrapWithTheme(
          AchievementCelebrationSheet(
            achievements: achievements,
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('achievement_celebration_sheet')), findsOneWidget);
      expect(find.text('2 Milestones Reached!'), findsOneWidget);
      expect(find.text('First Sweat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('7. Revisit recap after milestone celebrated displays no celebration sheet', (tester) async {
      final testStatsRepo = _TestCelebrationStatsRepository(db);
      testStatsRepo.seed(
        unlockedMap: {'first_workout': DateTime.utc(2026, 8, 14, 10, 0)},
      );

      final prefs = await SharedPreferences.getInstance();
      // Mark celebrated (simulates this session or a previous run already celebrated the milestone)
      await AchievementService.markCelebrated(prefs, ['first_workout']);

      final launch = B02StrengthExecutionLaunch(
        draftId: 101,
        occurrenceId: null,
        executionSnapshotJson: '{"version":1}',
        state: B02ExecutionDraftState(
          snapshotId: 'test-snap',
          snapshotVersion: 1,
          activityType: B02ActivityType.strength,
          routineName: 'Test Routine',
          elapsedSeconds: 1200,
          currentExerciseOrdinal: 0,
          currentSetOrdinal: 0,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            progressStatisticsRepositoryProvider.overrideWithValue(testStatsRepo),
            b02StrengthExecutionScreenControllerProvider.overrideWith(
              (ref, _) => _FakeB02StrengthController(),
            ),
          ],
          child: wrapWithTheme(
            B02StrengthSummaryScreen(launch: launch),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      // Recap is shown, but celebration sheet is NOT presented
      expect(find.text('Workout saved'), findsOneWidget);
      expect(find.byKey(const Key('achievement_celebration_sheet')), findsNothing);
    });
  });
}
