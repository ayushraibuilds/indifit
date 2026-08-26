import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/repositories/coaching_preference_repository.dart';
import 'package:indifit/data/repositories/nutrition_goal_repository.dart';
import 'package:indifit/data/repositories/nutrition_target_authority.dart';
import 'package:indifit/features/coaching/b04_production_surface_controller.dart';
import 'package:indifit/features/settings/nutrition_targets_hub_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late LocalScheduleDateService dates;

  setUp(() {
    database = AppDatabase.memory();
    dates = LocalScheduleDateService(
      nowUtc: () => DateTime.utc(2026, 8, 6, 12),
    );
  });

  tearDown(() => database.close());

  testWidgets(
    'Goal and targets are one canonical destination with coaching collapsed',
    (tester) async {
      await tester.pumpWidget(
        _app(
          database,
          dates,
          state: _state(goal: _goal()),
          targets: {'2026-08-06': _target(_goal(), '2026-08-06')},
        ),
      );
      await _pumpForAsyncState(tester);

      expect(find.text('Goal & targets'), findsOneWidget);
      expect(find.text('Goal'), findsWidgets);
      expect(find.text('Today’s target'), findsOneWidget);
      expect(find.text('2100 kcal'), findsOneWidget);
      expect(find.text('Save today’s targets'), findsOneWidget);
      expect(find.text('Optional coaching'), findsOneWidget);
      expect(find.text('Adaptive coaching'), findsNothing);
      expect(find.text('Date of birth'), findsNothing);
      expect(find.text('Goals & adaptive coaching'), findsNothing);
      expect(find.text('Refresh targets'), findsNothing);
      expect(find.textContaining('target weight'), findsNothing);
      expect(find.textContaining('ideal weight'), findsNothing);
      expect(find.textContaining('target version'), findsNothing);
      expect(find.textContaining('Manual override'), findsNothing);
      expect(find.textContaining('reason ID'), findsNothing);
      expect(find.textContaining('target ID'), findsNothing);

      await _expandCoaching(tester);

      expect(find.text('Adaptive coaching'), findsOneWidget);
      expect(find.text('Age details'), findsOneWidget);
      expect(find.text('Date of birth'), findsOneWidget);
      expect(
        find.textContaining('Coaching is separate from your goal'),
        findsOneWidget,
      );
      expect(find.text('2100 kcal'), findsOneWidget);
      expect(find.text('Save today’s targets'), findsOneWidget);
    },
  );

  testWidgets(
    'coaching loading remains optional while the canonical target stays usable',
    (tester) async {
      await tester.pumpWidget(
        _app(
          database,
          dates,
          state: _state(goal: _goal(), status: B04GoalSettingsStatus.loading),
          targets: {'2026-08-06': _target(_goal(), '2026-08-06')},
        ),
      );
      await _pumpForAsyncState(tester);

      expect(find.text('2100 kcal'), findsOneWidget);
      expect(find.text('Save today’s targets'), findsOneWidget);

      await _expandCoaching(tester);

      expect(find.text('Loading optional coaching'), findsOneWidget);
      expect(find.text('2100 kcal'), findsOneWidget);
      expect(find.text('Save today’s targets'), findsOneWidget);
    },
  );

  testWidgets('coaching failure does not block target editing', (tester) async {
    await tester.pumpWidget(
      _app(
        database,
        dates,
        state: _state(goal: _goal(), status: B04GoalSettingsStatus.failure),
        targets: {'2026-08-06': _target(_goal(), '2026-08-06')},
      ),
    );
    await _pumpForAsyncState(tester);
    await _expandCoaching(tester);

    expect(find.text('Optional coaching unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('2100 kcal'), findsOneWidget);
    expect(find.text('Save today’s targets'), findsOneWidget);
  });

  testWidgets('ineligible coaching does not block target editing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        database,
        dates,
        state: _state(
          goal: _goal(),
          availability: _availability(
            available: false,
            reasonCode: 'unknown_age',
            enabled: true,
            eligibility: _eligibility(
              result: CoachingEligibilityResult.unknownAge,
              reasonCode: 'unknown_age',
            ),
          ),
        ),
        targets: {'2026-08-06': _target(_goal(), '2026-08-06')},
      ),
    );
    await _pumpForAsyncState(tester);
    await _expandCoaching(tester);

    expect(
      find.textContaining(
        'Coaching suggestions are unavailable until we have your age details',
      ),
      findsOneWidget,
    );
    expect(find.text('2100 kcal'), findsOneWidget);
    expect(find.text('Save today’s targets'), findsOneWidget);
  });

  testWidgets('coaching requires disclosure and explicit consent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        database,
        dates,
        state: _state(
          goal: _goal(),
          availability: _availability(
            available: false,
            reasonCode: 'coaching_consent_required',
            enabled: false,
          ),
        ),
        targets: {'2026-08-06': _target(_goal(), '2026-08-06')},
      ),
    );
    await _pumpForAsyncState(tester);
    await _expandCoaching(tester);

    expect(find.text('Disabled'), findsOneWidget);
    await tester.ensureVisible(find.text('Adaptive coaching'));
    await tester.tap(find.text('Adaptive coaching'));
    await tester.pumpAndSettle();
    expect(find.text('Review adaptive coaching'), findsOneWidget);
    expect(
      find.textContaining('Suggestions are never applied automatically'),
      findsOneWidget,
    );
    expect(find.text('Withdraw coaching consent'), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Disabled'), findsOneWidget);
    expect(find.text('Withdraw coaching consent'), findsNothing);
  });

  testWidgets(
    'usable coaching keeps consent history and target authority separate',
    (tester) async {
      await tester.pumpWidget(
        _app(
          database,
          dates,
          state: _state(
            goal: _goal(),
            availability: _availability(
              available: true,
              reasonCode: 'eligible',
              enabled: true,
              eligibility: _eligibility(
                result: CoachingEligibilityResult.eligible,
                reasonCode: 'eligible',
              ),
            ),
            consentHistory: [_consentEvent()],
          ),
          targets: {'2026-08-06': _target(_goal(), '2026-08-06')},
        ),
      );
      await _pumpForAsyncState(tester);
      await _expandCoaching(tester);

      expect(
        find.text(
          'Coaching suggestions are available when you choose to use them.',
        ),
        findsOneWidget,
      );
      expect(find.text('Enabled'), findsOneWidget);
      expect(find.text('Coaching history'), findsOneWidget);
      await tester.ensureVisible(find.text('Coaching history'));
      await tester.tap(find.text('Coaching history'));
      await _pumpForAsyncState(tester);
      expect(find.text('Coaching enabled'), findsOneWidget);
      expect(find.text('eligible'), findsNothing);
      expect(find.text('2100 kcal'), findsOneWidget);
    },
  );

  testWidgets(
    'historical and future target versions stay date-scoped and read-only',
    (tester) async {
      final goal = _goal();
      await tester.pumpWidget(
        _app(
          database,
          dates,
          state: _state(goal: goal),
          targets: {
            '2026-08-05': _target(
              _goal(effectiveFrom: '2026-08-01'),
              '2026-08-05',
            ),
            '2026-08-06': _target(goal, '2026-08-06'),
            '2026-08-07': _target(goal, '2026-08-07'),
          },
        ),
      );
      await _pumpForAsyncState(tester);

      await tester.tap(find.byTooltip('Previous day'));
      await _pumpForAsyncState(tester);
      expect(find.text('Target for Yesterday'), findsOneWidget);
      expect(
        find.textContaining('Earlier targets are read-only here.'),
        findsOneWidget,
      );
      expect(find.text('Save today’s targets'), findsNothing);

      await tester.tap(find.byTooltip('Next day'));
      await _pumpForAsyncState(tester);
      await tester.tap(find.byTooltip('Next day'));
      await _pumpForAsyncState(tester);
      expect(find.text('Target for Tomorrow'), findsOneWidget);
      expect(
        find.textContaining(
          'Today’s saved target continues to apply unless another target takes effect later.',
        ),
        findsOneWidget,
      );
      expect(find.text('Save today’s targets'), findsNothing);
    },
  );

  testWidgets('unchanged consecutive targets are not repeated in history', (
    tester,
  ) async {
    final goal = _goal();
    await tester.pumpWidget(
      _app(
        database,
        dates,
        state: _state(goal: goal),
        targets: {'2026-08-06': _target(goal, '2026-08-06')},
        history: [goal, goal],
      ),
    );
    await _pumpForAsyncState(tester);

    await tester.ensureVisible(find.text('Target history'));
    await tester.tap(find.text('Target history'));
    await _pumpForAsyncState(tester);

    // One current-goal summary and one meaningful history row.
    expect(find.text('Maintain · Set by you'), findsNWidgets(2));
  });

  testWidgets(
    'combined surface remains usable at narrow width and large text',
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      final media = MediaQueryData.fromView(
        tester.view,
      ).copyWith(textScaler: const TextScaler.linear(1.8));

      await tester.pumpWidget(
        _app(
          database,
          dates,
          media: media,
          state: _state(goal: _goal()),
          targets: {'2026-08-06': _target(_goal(), '2026-08-06')},
        ),
      );
      await _pumpForAsyncState(tester);
      await _expandCoaching(tester);

      expect(find.text('Goal & targets'), findsOneWidget);
      expect(find.text('Adaptive coaching'), findsOneWidget);
      expect(find.text('2100 kcal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _app(
  AppDatabase database,
  LocalScheduleDateService dates, {
  required B04GoalSettingsState state,
  required Map<String, NutritionTargetsForDate> targets,
  List<NutritionGoalVersionReadModel>? history,
  MediaQueryData? media,
}) {
  final controller = B04GoalSettingsController(
    loadContext: () async => _context,
    goals: NutritionGoalRepository(database: database, dates: dates),
    preferences: CoachingPreferenceRepository(database: database, dates: dates),
    dates: dates,
    nowUtc: () => DateTime.utc(2026, 8, 6, 12),
  );
  controller.state = state;

  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(database),
      localScheduleDateServiceProvider.overrideWithValue(dates),
      b04ProductionUserContextProvider.overrideWith((ref) async => _context),
      b04GoalSettingsControllerProvider.overrideWith((ref) => controller),
      nutritionTargetsForDateProvider.overrideWith((ref, query) async {
        final target = targets[query.localDate];
        if (target == null) {
          throw StateError('No test target for ${query.localDate}');
        }
        return target;
      }),
      nutritionGoalHistoryProvider.overrideWith(
        (ref, userId) async => history ?? [state.activeGoal!],
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: media == null
          ? const NutritionTargetsHubScreen()
          : MediaQuery(data: media, child: const NutritionTargetsHubScreen()),
    ),
  );
}

const _context = B04ProductionUserContext(
  userId: '1',
  localDate: '2026-08-06',
  timezoneId: 'Asia/Kolkata',
);

B04GoalSettingsState _state({
  required NutritionGoalVersionReadModel goal,
  B04GoalSettingsStatus status = B04GoalSettingsStatus.ready,
  CoachingAvailabilityReadModel? availability,
  List<CoachingConsentEventReadModel> consentHistory = const [],
}) => B04GoalSettingsState(
  status: status,
  context: _context,
  activeGoal: goal,
  goalHistory: [goal],
  availability: availability,
  consentHistory: consentHistory,
);

NutritionTargetsForDate _target(
  NutritionGoalVersionReadModel goal,
  String localDate,
) => NutritionTargetsForDate(
  localDate: localDate,
  timezoneId: 'Asia/Kolkata',
  goalVersion: goal,
);

NutritionGoalVersionReadModel _goal({String effectiveFrom = '2026-08-06'}) =>
    NutritionGoalVersionReadModel(
      id: 'goal-${effectiveFrom.replaceAll('-', '')}',
      userId: '1',
      versionNumber: effectiveFrom == '2026-08-06' ? 2 : 1,
      goalType: NutritionGoalType.maintenance,
      source: NutritionGoalSource.userSet,
      calorieTargetKcal: effectiveFrom == '2026-08-06' ? 2100 : 1900,
      proteinTargetG: 140,
      carbsTargetG: 220,
      fatTargetG: 65,
      policyVersion: null,
      calculationVersion: null,
      algorithmVersion: null,
      effectiveFromLocalDate: effectiveFrom,
      effectiveToLocalDate: null,
      timezoneId: 'Asia/Kolkata',
      supersedesGoalVersionId: null,
      evidenceFingerprint: null,
      exactResultNumerator: null,
      exactResultDenominator: null,
      normalizedMaintenanceKcal: null,
      createdAtUtc: DateTime.utc(2026, 8, 6, 12),
    );

CoachingAvailabilityReadModel _availability({
  required bool available,
  required String reasonCode,
  required bool enabled,
  CoachingEligibilityReadModel? eligibility,
}) {
  final event = enabled ? _consentEvent() : null;
  return CoachingAvailabilityReadModel(
    available: available,
    reasonCode: reasonCode,
    eligibility: eligibility,
    preferences: CoachingPreferencesReadModel(
      userId: '1',
      adaptiveCoachingEnabled: enabled,
      optionalAiEnabled: false,
      adaptiveCoachingEvent: event,
      optionalAiEvent: null,
    ),
  );
}

CoachingEligibilityReadModel _eligibility({
  required CoachingEligibilityResult result,
  required String reasonCode,
}) => CoachingEligibilityReadModel(
  userId: '1',
  result: result,
  reasonCode: reasonCode,
  policyVersion: 'test-policy',
  evaluationLocalDate: '2026-08-06',
  timezoneId: 'Asia/Kolkata',
  evaluationUtc: DateTime.utc(2026, 8, 6, 12),
);

CoachingConsentEventReadModel _consentEvent() => CoachingConsentEventReadModel(
  id: 'consent-1',
  userId: '1',
  category: CoachingConsentCategory.adaptiveCoaching,
  action: CoachingConsentAction.enable,
  consentPolicyVersion: 'test-policy',
  copyVersion: 'test-copy',
  timestampUtc: DateTime.utc(2026, 8, 6, 12),
  localDate: '2026-08-06',
  timezoneId: 'Asia/Kolkata',
  actorSource: 'test',
  relatedOrSupersededEventId: null,
);

Future<void> _pumpForAsyncState(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _expandCoaching(WidgetTester tester) async {
  final tile = find.text('Optional coaching');
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await _pumpForAsyncState(tester);
}
