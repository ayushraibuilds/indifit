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
          state: _state(
            goal: _goal(),
            availability: _availability(
              available: false,
              reasonCode: 'unknown_age',
              enabled: false,
            ),
          ),
          targets: {'2026-08-06': _target(_goal(), '2026-08-06')},
        ),
      );
      await _pumpForAsyncState(tester);

      expect(find.text('Goal & targets'), findsOneWidget);
      expect(find.text('Fitness goal'), findsOneWidget);
      expect(find.text('Build muscle'), findsOneWidget);
      expect(find.text('Nutrition strategy'), findsWidgets);
      expect(find.text('Maintenance'), findsWidgets);
      expect(find.text('Weight gain'), findsNothing);
      expect(find.text('Today’s target'), findsOneWidget);
      expect(find.text('2100 kcal'), findsOneWidget);
      expect(find.text('Save today’s targets'), findsOneWidget);
      expect(find.text('Adaptive coaching'), findsOneWidget);
      expect(find.textContaining('Off · IndiFit can suggest'), findsOneWidget);
      expect(find.text('Check availability'), findsOneWidget);
      expect(find.text('Date of birth'), findsNothing);
      expect(find.text('Goals & adaptive coaching'), findsNothing);
      expect(find.text('Refresh targets'), findsNothing);
      expect(find.textContaining('target weight'), findsNothing);
      expect(find.textContaining('ideal weight'), findsNothing);
      expect(find.textContaining('target version'), findsNothing);
      expect(find.textContaining('Manual override'), findsNothing);
      expect(find.textContaining('reason ID'), findsNothing);
      expect(find.textContaining('target ID'), findsNothing);

      await tester.ensureVisible(
        find.byKey(const ValueKey('adaptive-coaching-shell')),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('adaptive-coaching-shell')),
        matchesGoldenFile('goldens/phase5_coaching_off_light.png'),
      );

      await _expandCoaching(tester);

      expect(find.text('Adaptive coaching'), findsOneWidget);
      expect(find.text('Age details'), findsOneWidget);
      expect(find.text('Date of birth'), findsOneWidget);
      expect(
        find.text(
          'Add your date of birth to check whether adaptive coaching is available.',
        ),
        findsOneWidget,
      );
      expect(find.text('Coaching availability'), findsOneWidget);
      expect(find.text('2100 kcal'), findsOneWidget);
      expect(find.text('Save today’s targets'), findsOneWidget);
      await tester.ensureVisible(
        find.text(
          'Add your date of birth to check whether adaptive coaching is available.',
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(NutritionTargetsHubScreen),
        matchesGoldenFile('goldens/phase5_coaching_missing_dob_light.png'),
      );
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

  testWidgets('missing DOB stays unknown and does not deny coaching', (
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
          ),
        ),
        targets: {'2026-08-06': _target(_goal(), '2026-08-06')},
      ),
    );
    await _pumpForAsyncState(tester);
    await _expandCoaching(tester);

    expect(
      find.text(
        'Add your date of birth to check whether adaptive coaching is available.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('unavailable for this age'), findsNothing);
    expect(find.textContaining('ineligible'), findsNothing);
    expect(find.text('2100 kcal'), findsOneWidget);
    expect(find.text('Save today’s targets'), findsOneWidget);
  });

  testWidgets('known ineligible age is described truthfully', (tester) async {
    await tester.pumpWidget(
      _app(
        database,
        dates,
        state: _state(
          goal: _goal(),
          availability: _availability(
            available: false,
            reasonCode: 'underage',
            enabled: false,
            eligibility: _eligibility(
              result: CoachingEligibilityResult.underage,
              reasonCode: 'underage',
            ),
          ),
        ),
        targets: {'2026-08-06': _target(_goal(), '2026-08-06')},
      ),
    );
    await _pumpForAsyncState(tester);
    await _expandCoaching(tester);

    expect(
      find.textContaining('Coaching suggestions are unavailable for this age'),
      findsOneWidget,
    );
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
            eligibility: _eligibility(
              result: CoachingEligibilityResult.eligible,
              reasonCode: 'eligible',
            ),
          ),
        ),
        targets: {'2026-08-06': _target(_goal(), '2026-08-06')},
      ),
    );
    await _pumpForAsyncState(tester);
    await _expandCoaching(tester);

    expect(find.textContaining('Off · IndiFit can suggest'), findsOneWidget);
    expect(
      find.text('Adaptive coaching is available when you choose to use it.'),
      findsOneWidget,
    );
    final coachingSwitch = find.byType(Switch).last;
    await tester.ensureVisible(coachingSwitch);
    await tester.tap(coachingSwitch);
    await tester.pumpAndSettle();
    expect(find.text('Review adaptive coaching'), findsOneWidget);
    expect(
      find.textContaining('Suggestions are never applied automatically'),
      findsOneWidget,
    );
    expect(find.text('Withdraw coaching consent'), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Off · IndiFit can suggest'), findsOneWidget);
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
        find.text('Adaptive coaching is available when you choose to use it.'),
        findsOneWidget,
      );
      expect(find.textContaining('On · IndiFit can suggest'), findsOneWidget);
      expect(find.text('Coaching history'), findsOneWidget);
      await expectLater(
        find.byKey(const ValueKey('adaptive-coaching-shell')),
        matchesGoldenFile('goldens/phase5_coaching_managed_light.png'),
      );
      await tester.ensureVisible(find.text('Coaching history'));
      await tester.tap(find.text('Coaching history'));
      await _pumpForAsyncState(tester);
      expect(find.text('Coaching enabled'), findsOneWidget);
      expect(find.text('eligible'), findsNothing);
      expect(find.text('2100 kcal'), findsOneWidget);
    },
  );

  testWidgets(
    'coaching history stays collapsed and groups meaningful same-day changes',
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
            consentHistory: [
              _consentEvent(id: 'enable-1'),
              _consentEvent(id: 'enable-no-op'),
              _consentEvent(
                id: 'disable-1',
                action: CoachingConsentAction.disable,
              ),
              _consentEvent(id: 'enable-2'),
            ],
          ),
          targets: {'2026-08-06': _target(_goal(), '2026-08-06')},
        ),
      );
      await _pumpForAsyncState(tester);
      await _expandCoaching(tester);

      expect(find.text('Coaching history'), findsOneWidget);
      expect(find.text('3 consent changes'), findsNothing);
      await tester.ensureVisible(find.text('Coaching history'));
      await tester.tap(find.text('Coaching history'));
      await _pumpForAsyncState(tester);

      expect(find.text('3 consent changes'), findsOneWidget);
      expect(find.text('Enabled → Disabled → Enabled · Today'), findsOneWidget);
      expect(find.textContaining('target changed'), findsNothing);
    },
  );

  testWidgets(
    'fitness goal remains Build muscle beside a distinct gain strategy',
    (tester) async {
      final goal = _goal(goalType: NutritionGoalType.gain);
      await tester.pumpWidget(
        _app(
          database,
          dates,
          state: _state(goal: goal),
          targets: {'2026-08-06': _target(goal, '2026-08-06')},
        ),
      );
      await _pumpForAsyncState(tester);

      expect(find.text('Fitness goal'), findsOneWidget);
      expect(find.text('Build muscle'), findsOneWidget);
      expect(find.text('Nutrition strategy'), findsWidgets);
      expect(find.textContaining('Calorie surplus'), findsWidgets);
      expect(find.text('Weight gain'), findsNothing);
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
    expect(find.text('Maintenance · Set by you'), findsNWidgets(2));
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
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(database),
      localScheduleDateServiceProvider.overrideWithValue(dates),
      b04ProductionUserContextProvider.overrideWith((ref) async => _context),
      b04GoalSettingsControllerProvider.overrideWith((ref) {
        final controller = B04GoalSettingsController(
          loadContext: () async => _context,
          goals: NutritionGoalRepository(database: database, dates: dates),
          preferences: CoachingPreferenceRepository(
            database: database,
            dates: dates,
          ),
          dates: dates,
          nowUtc: () => DateTime.utc(2026, 8, 6, 12),
        );
        controller.state = state;
        return controller;
      }),
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
      userProfileProvider.overrideWith((ref) => _GoalProfileNotifier()),
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

NutritionGoalVersionReadModel _goal({
  String effectiveFrom = '2026-08-06',
  NutritionGoalType goalType = NutritionGoalType.maintenance,
}) => NutritionGoalVersionReadModel(
  id: 'goal-${effectiveFrom.replaceAll('-', '')}',
  userId: '1',
  versionNumber: effectiveFrom == '2026-08-06' ? 2 : 1,
  goalType: goalType,
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

CoachingConsentEventReadModel _consentEvent({
  String id = 'consent-1',
  CoachingConsentAction action = CoachingConsentAction.enable,
}) => CoachingConsentEventReadModel(
  id: id,
  userId: '1',
  category: CoachingConsentCategory.adaptiveCoaching,
  action: action,
  consentPolicyVersion: 'test-policy',
  copyVersion: 'test-copy',
  timestampUtc: DateTime.utc(2026, 8, 6, 12),
  localDate: '2026-08-06',
  timezoneId: 'Asia/Kolkata',
  actorSource: 'test',
  relatedOrSupersededEventId: null,
);

class _GoalProfileNotifier extends UserProfileNotifier {
  _GoalProfileNotifier() : super() {
    state = const UserProfileState(
      isLoaded: true,
      hasProfile: true,
      calorieGoal: 2400,
      proteinGoal: 160,
      carbsGoal: 280,
      fatGoal: 75,
      currentWeight: 80,
      userGoal: 'gain',
    );
  }

  @override
  Future<void> loadProfile() async {}
}

Future<void> _pumpForAsyncState(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _expandCoaching(WidgetTester tester) async {
  final action = find.textContaining(
    RegExp('Check availability|Manage coaching|View details|Try again'),
  );
  await tester.ensureVisible(action);
  await tester.tap(action);
  await _pumpForAsyncState(tester);
}
