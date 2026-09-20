import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/achievement_service.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/progress_statistics_repository.dart';
import 'package:indifit/features/progress/achievements_screen.dart';
import 'package:indifit/features/progress/widgets/achievement_detail_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAchievementRepository extends ProgressStatisticsRepository {
  final Map<String, DateTime> _unlockedMap = {};
  int _totalWorkouts = 0;
  double _totalVolumeKg = 0;
  int _totalMealsLogged = 0;

  _TestAchievementRepository(super.database);

  void seed({
    int totalWorkouts = 0,
    double totalVolumeKg = 0,
    int totalMealsLogged = 0,
    Map<String, DateTime>? unlockedMap,
  }) {
    _totalWorkouts = totalWorkouts;
    _totalVolumeKg = totalVolumeKg;
    _totalMealsLogged = totalMealsLogged;
    if (unlockedMap != null) _unlockedMap.addAll(unlockedMap);
  }

  @override
  Future<LifetimeAchievementStats> getLifetimeStats() async =>
      LifetimeAchievementStats(
        totalWorkouts: _totalWorkouts,
        totalVolumeKg: _totalVolumeKg,
        totalMealsLogged: _totalMealsLogged,
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
  late _TestAchievementRepository testRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'user_streak_count': 0,
    });
    db = AppDatabase.memory();
    testRepo = _TestAchievementRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrapWithTheme(Widget child, {double textScale = 1.0, Size size = const Size(390, 844)}) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        extensions: const [B05SemanticColors.dark],
      ),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child,
      ),
    );
  }

  group('PV1-PROD-03B: Achievements Screen & Detail Sheet Tests', () {
    testWidgets('1. AchievementDetailSheet displays exact evidence, unlock date, and X to go math', (tester) async {
      final achievement = Achievement(
        id: 'volume_1000',
        title: 'Iron Lifter',
        description: 'Lift a cumulative total of 1,000 kg volume.',
        icon: Icons.military_tech_rounded,
        color: const Color(0xFFCD7F32),
        currentProgress: 1200.0,
        maxProgress: 1000.0,
        isUnlocked: true,
        evidence: '1,200 kg / 1,000 kg volume recorded',
        unlockedAt: DateTime.utc(2026, 7, 20, 15, 30),
      );

      await tester.pumpWidget(
        wrapWithTheme(
          Scaffold(
            body: AchievementDetailSheet(achievement: achievement),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('achievement_detail_sheet')), findsOneWidget);
      expect(find.text('Iron Lifter'), findsOneWidget);
      expect(find.text('How this was unlocked: 1,200 kg / 1,000 kg volume recorded'), findsOneWidget);
      expect(find.text('Unlocked on 20 Jul 2026'), findsOneWidget);
      // Volume chain math: 5000 - 1200 = 3,800 kg to Heavy Mover
      expect(find.text('3,800 kg to Heavy Mover (5,000 kg)'), findsOneWidget);
      // Basis disclosure note
      expect(find.textContaining('Basis: Verified completed workout sessions'), findsOneWidget);
    });

    testWidgets('2. AchievementDetailSheet progression math for streak and meal chains', (tester) async {
      final streakBadge = Achievement(
        id: 'streak_7',
        title: 'Consistency Master',
        description: 'Maintain a 7-day streak.',
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFFF7A00),
        currentProgress: 10.0,
        maxProgress: 7.0,
        isUnlocked: true,
        evidence: '10 of 7 day streak logged',
        unlockedAt: DateTime.utc(2026, 8, 1, 12, 0),
      );

      await tester.pumpWidget(
        wrapWithTheme(
          Scaffold(body: AchievementDetailSheet(achievement: streakBadge)),
        ),
      );
      await tester.pump();

      // 30 - 10 = 20 days to Iron Discipline
      expect(find.text('20 days to Iron Discipline (30 days)'), findsOneWidget);
      expect(find.textContaining('Basis: Consecutive calendar days'), findsOneWidget);

      final mealsBadge = Achievement(
        id: 'meals_10',
        title: 'Nutrition Tracker',
        description: 'Log 10 meals in your food diary.',
        icon: Icons.restaurant_rounded,
        color: const Color(0xFF10B981),
        currentProgress: 15.0,
        maxProgress: 10.0,
        isUnlocked: true,
        evidence: '15 of 10 meals logged',
        unlockedAt: DateTime.utc(2026, 8, 5, 12, 0),
      );

      await tester.pumpWidget(
        wrapWithTheme(
          Scaffold(body: AchievementDetailSheet(achievement: mealsBadge)),
        ),
      );
      await tester.pump();

      // 50 - 15 = 35 meals to Macro Master
      expect(find.text('35 meals to Macro Master (50 meals)'), findsOneWidget);
      expect(find.textContaining('Basis: Food entries logged in your local food diary'), findsOneWidget);
    });

    testWidgets('3. Fresh install shows empty state and 0 / 9 Unlocked', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            progressStatisticsRepositoryProvider.overrideWithValue(testRepo),
          ],
          child: wrapWithTheme(const AchievementsScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('0 / 9 Unlocked'), findsOneWidget);
      expect(find.text('No Badges Unlocked Yet'), findsOneWidget);
      expect(find.text('ALL BADGES'), findsOneWidget);
      expect(find.byKey(const Key('recently_unlocked_carousel')), findsNothing);
    });

    testWidgets('4. Unlocked badges render Recently Unlocked carousel and tapping card opens detail sheet', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      testRepo.seed(
        totalWorkouts: 1,
        unlockedMap: {
          'first_workout': DateTime.utc(2026, 8, 14, 10, 0),
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            progressStatisticsRepositoryProvider.overrideWithValue(testRepo),
          ],
          child: wrapWithTheme(const AchievementsScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('1 / 9 Unlocked'), findsOneWidget);
      expect(find.text('RECENTLY UNLOCKED'), findsOneWidget);
      expect(find.byKey(const Key('recently_unlocked_carousel')), findsOneWidget);

      // Tap on first_workout card
      final cardFinder = find.byKey(const Key('achievement_card_first_workout'));
      expect(cardFinder, findsOneWidget);
      await tester.ensureVisible(cardFinder);
      await tester.pumpAndSettle();
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      // Detail sheet should open
      expect(find.byKey(const Key('achievement_detail_sheet')), findsOneWidget);
      expect(find.text('First Sweat'), findsWidgets);
    });

    testWidgets('5. Responsive single-column layout on 320pt width at 2.0x text scale without overflow', (tester) async {
      testRepo.seed(
        totalWorkouts: 1,
        unlockedMap: {
          'first_workout': DateTime.utc(2026, 8, 14, 10, 0),
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            progressStatisticsRepositoryProvider.overrideWithValue(testRepo),
          ],
          child: wrapWithTheme(
            const AchievementsScreen(),
            textScale: 2.0,
            size: const Size(320, 600),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 700));

      // Must render with 0 RenderFlex overflow errors
      expect(tester.takeException(), isNull);

      // Scroll through the vertical list to ensure all badge cards are accessible
      await tester.drag(find.byType(ListView).first, const Offset(0, -800));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. All 9 unlocked state renders All 9 Badges Unlocked banner', (tester) async {
      final all9Ids = AchievementService.workoutAchievementIds.union(
        AchievementService.nonWorkoutAchievementIds,
      );
      testRepo.seed(
        totalWorkouts: 1,
        totalVolumeKg: 10000,
        totalMealsLogged: 50,
        unlockedMap: {
          for (final id in all9Ids) id: DateTime.utc(2026, 8, 14, 10, 0),
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            progressStatisticsRepositoryProvider.overrideWithValue(testRepo),
          ],
          child: wrapWithTheme(const AchievementsScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('All 9 Badges Unlocked!'), findsOneWidget);
      expect(find.textContaining('Incredible dedication!'), findsOneWidget);
      expect(find.text('No Badges Unlocked Yet'), findsNothing);
    });

    testWidgets('7. Compact evidence formatting preserves dates and trims redundant suffixes', (tester) async {
      testRepo.seed(
        totalWorkouts: 1,
        totalVolumeKg: 1200,
        totalMealsLogged: 10,
        unlockedMap: {
          'first_workout': DateTime.utc(2026, 8, 14, 10, 0),
          'volume_1000': DateTime.utc(2026, 8, 14, 10, 0),
          'meals_10': DateTime.utc(2026, 8, 14, 10, 0),
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            progressStatisticsRepositoryProvider.overrideWithValue(testRepo),
          ],
          child: wrapWithTheme(const AchievementsScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 700));

      // Workout evidence: '1 of 1 workout logged' -> '1 of 1 workout · 14 Aug 2026'
      expect(find.text('1 of 1 workout · 14 Aug 2026'), findsWidgets);

      // Volume evidence: '1,200 kg / 1,000 kg volume recorded' -> '1,200 kg / 1,000 kg · 14 Aug 2026'
      expect(find.text('1,200 kg / 1,000 kg · 14 Aug 2026'), findsWidgets);

      // Meal evidence: '10 of 10 meals logged' -> '10 of 10 meals · 14 Aug 2026'
      expect(find.text('10 of 10 meals · 14 Aug 2026'), findsWidgets);
    });
  });
}
