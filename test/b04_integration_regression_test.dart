import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b04_adaptive_target_models.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/repositories/coaching_preference_repository.dart';
import 'package:indifit/data/services/b04_adaptive_target_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() => db.close());

  test('B01-B03 authorities and legacy paths remain isolated from B04', () {
    final matrix = B04AdaptiveCoachingFixtureMatrix.current;
    matrix.validate();

    final authorities = matrix.authorities;
    expect(
      authorities.map((authority) => authority.authority),
      containsAll([
        'NutritionReadModelRepository',
        'NutritionConstraintRepository',
        'NutritionEstimateRepository',
        'LocalScheduleDateService',
      ]),
    );
    expect(
      authorities.where((authority) => authority.duplicateCreated),
      isEmpty,
    );

    const b04ProductionFiles = [
      'lib/core/di/providers.dart',
      'lib/data/models/b04_adaptive_target_models.dart',
      'lib/data/models/b04_briefing_read_models.dart',
      'lib/data/models/b04_recommendation_context_models.dart',
      'lib/data/models/b04_recommendation_history_models.dart',
      'lib/data/models/b04_recommendation_models.dart',
      'lib/data/repositories/b04_briefing_read_repositories.dart',
      'lib/data/repositories/b04_recommendation_history_repository.dart',
      'lib/data/repositories/coaching_preference_repository.dart',
      'lib/data/repositories/nutrition_goal_repository.dart',
      'lib/data/services/b04_adaptive_target_engine.dart',
      'lib/data/services/b04_optional_ai_assistance.dart',
      'lib/features/coaching/b04_production_surface_controller.dart',
      'lib/features/dashboard/b04_daily_briefing_controller.dart',
      'lib/features/progress/b04_weekly_review_controller.dart',
      'lib/features/settings/nutrition_goals_sub_screen.dart',
    ];
    const legacyAuthorities = [
      'FoodRepository',
      'TdeeCalculator',
      'WeeklyReportService',
      'MealPlanService',
      'ProgressStatisticsRepository',
    ];
    for (final path in b04ProductionFiles) {
      final source = File(path).readAsStringSync();
      for (final legacyAuthority in legacyAuthorities) {
        expect(
          source,
          isNot(contains(legacyAuthority)),
          reason: '$path must not use $legacyAuthority as a B04 authority',
        );
      }
    }

    final readBoundary = File(
      'lib/data/repositories/nutrition_read_model_repository.dart',
    ).readAsStringSync();
    expect(readBoundary, contains('NutritionLegacyAdapter'));
    expect(readBoundary, contains('never writes or recalculates'));

    final legacyTdee = File(
      'lib/core/utils/tdee_calculator.dart',
    ).readAsStringSync();
    expect(legacyTdee, contains('-500'));
    expect(legacyTdee, contains('+300'));
    expect(legacyTdee, contains('1200'));
    expect(
      File(
        'lib/data/services/b04_adaptive_target_engine.dart',
      ).readAsStringSync(),
      isNot(contains('TdeeCalculator')),
    );

    final providers = File('lib/core/di/providers.dart').readAsStringSync();
    expect(providers, contains('nutritionReadModelRepositoryProvider'));
    expect(providers, contains('nutritionGoalRepositoryProvider'));
    expect(providers, contains('coachingPreferenceRepositoryProvider'));
    expect(providers, contains('b04RecommendationHistoryRepositoryProvider'));
    expect(providers, contains('b04DailyBriefingReadRepositoryProvider'));
    expect(providers, contains('b04WeeklyReviewReadRepositoryProvider'));

    final dailyController = File(
      'lib/features/dashboard/b04_daily_briefing_controller.dart',
    ).readAsStringSync();
    final weeklyController = File(
      'lib/features/progress/b04_weekly_review_controller.dart',
    ).readAsStringSync();
    for (final source in [dailyController, weeklyController]) {
      expect(source, contains('B04RecommendationHistoryRepository'));
      expect(source, contains('NutritionGoalRepository'));
      expect(source, contains('CoachingPreferenceRepository'));
    }

    final briefingReads = File(
      'lib/data/repositories/b04_briefing_read_repositories.dart',
    ).readAsStringSync();
    expect(briefingReads, contains('B04BriefingRecommendation.fromHistory'));
    expect(
      briefingReads,
      isNot(contains('B04AdaptiveTargetEngine')),
      reason: 'daily/weekly reads must not become a second target engine',
    );
  });

  test(
    'consent and eligibility read only their user-owned append-only histories',
    () async {
      final preferences = CoachingPreferenceRepository(database: db);
      final enabledAt = DateTime.utc(2026, 3, 1, 10);
      await preferences.recordConsent(
        CoachingConsentCommand(
          userId: 'user-a',
          category: CoachingConsentCategory.adaptiveCoaching,
          action: CoachingConsentAction.enable,
          consentPolicyVersion: kB04EnabledPolicyVersion,
          copyVersion: 'b04-16-test-copy',
          timestampUtc: enabledAt,
          localDate: '2026-03-01',
          timezoneId: 'Asia/Kolkata',
          actorSource: 'test',
          eventId: 'b04-16-consent-a',
        ),
      );
      await db
          .into(db.coachingEligibilityEvaluations)
          .insert(
            CoachingEligibilityEvaluationsCompanion.insert(
              id: 'b04-16-eligible-a',
              userId: 'user-a',
              result: 'eligible',
              reasonCode: 'eligible',
              ageInputSource: 'verified_dob',
              evidenceTimestampUtc: enabledAt,
              evaluationUtc: enabledAt,
              evaluationLocalDate: '2026-03-01',
              timezoneId: 'Asia/Kolkata',
              policyVersion: kB04EnabledPolicyVersion,
              minimumAgeRuleVersion: 'minimum-age-v1',
            ),
          );
      await db
          .into(db.coachingEligibilityEvaluations)
          .insert(
            CoachingEligibilityEvaluationsCompanion.insert(
              id: 'b04-16-underage-b',
              userId: 'user-b',
              result: 'underage',
              reasonCode: 'coaching_unavailable_age',
              ageInputSource: 'verified_dob',
              evidenceTimestampUtc: enabledAt,
              evaluationUtc: enabledAt,
              evaluationLocalDate: '2026-03-01',
              timezoneId: 'Asia/Kolkata',
              policyVersion: kB04EnabledPolicyVersion,
              minimumAgeRuleVersion: 'minimum-age-v1',
            ),
          );

      final beforeHistory = await preferences.listConsentHistory(
        userId: 'user-a',
      );
      expect(
        (await preferences.currentPreferences(
          userId: 'user-a',
        )).adaptiveCoachingEnabled,
        isTrue,
      );
      expect(
        (await preferences.currentPreferences(
          userId: 'user-b',
        )).adaptiveCoachingEnabled,
        isFalse,
      );
      expect(
        (await preferences.currentEligibility(userId: 'user-a'))!.result,
        CoachingEligibilityResult.eligible,
      );
      expect(
        (await preferences.currentEligibility(userId: 'user-b'))!.result,
        CoachingEligibilityResult.underage,
      );

      await db
          .update(db.nutritionCoachingPreferences)
          .write(
            const NutritionCoachingPreferencesCompanion(
              adaptiveCoachingEnabled: Value(false),
            ),
          );
      final afterProjectionTamper = await preferences.currentPreferences(
        userId: 'user-a',
      );
      expect(afterProjectionTamper.adaptiveCoachingEnabled, isTrue);
      expect(
        (await preferences.listConsentHistory(
          userId: 'user-a',
        )).map((event) => event.id),
        equals(beforeHistory.map((event) => event.id)),
      );
    },
  );

  test('HOLD-1 replay and ENABLED-1 activation stay future-only', () {
    final engine = B04AdaptiveTargetEngine();
    final hold = engine.evaluate(_request());
    expect(hold.status, B04AdaptiveTargetStatus.unavailable);
    expect(hold.reasonCode, 'adaptive_policy_hold');
    expect(hold.policyVersion, kB04HoldPolicyVersion);
    expect(hold.adaptiveDeltaKcal, 0);
    expect(hold.proposal, isNull);

    final futureActivation = B04ActivationMetadata.enabled(
      effectiveFromLocalDate: '2026-04-01',
      timezoneId: 'Asia/Kolkata',
      scopeUserId: 'user-a',
      mergedBranch: 'batch/b04-adaptive-coaching',
      releaseSelection: 'b04-16-test',
    );
    final beforeActivation = engine.evaluate(
      _request(activation: futureActivation),
    );
    expect(beforeActivation.status, B04AdaptiveTargetStatus.inactive);
    expect(beforeActivation.reasonCode, 'adaptive_policy_inactive');
    expect(beforeActivation.adaptiveDeltaKcal, 0);
    expect(beforeActivation.proposal, isNull);

    final afterActivation = engine.evaluate(
      _request(activation: futureActivation, evaluationLocalDate: '2026-04-01'),
    );
    expect(afterActivation.status, B04AdaptiveTargetStatus.unavailable);
    expect(afterActivation.reasonCode, 'coaching_unavailable_age');
    expect(afterActivation.adaptiveDeltaKcal, 0);
    expect(afterActivation.proposal, isNull);
  });

  test('unsupported policy and cross-user evidence fail closed', () {
    final engine = B04AdaptiveTargetEngine();
    final active = B04ActivationMetadata.enabled(
      effectiveFromLocalDate: '2026-03-01',
      timezoneId: 'Asia/Kolkata',
      scopeUserId: 'user-a',
      mergedBranch: 'batch/b04-adaptive-coaching',
      releaseSelection: 'b04-16-test',
    );

    final unsupported = engine.evaluate(
      _request(activation: active, storedPolicyVersion: 'future-policy'),
    );
    expect(unsupported.status, B04AdaptiveTargetStatus.invalidEvidence);
    expect(unsupported.reasonCode, 'unsupported_policy_version');
    expect(unsupported.adaptiveDeltaKcal, 0);

    final crossUser = engine.evaluate(
      _request(
        activation: active,
        eligibility: CoachingEligibilityReadModel(
          userId: 'user-b',
          result: CoachingEligibilityResult.eligible,
          reasonCode: 'eligible',
          policyVersion: kB04EnabledPolicyVersion,
          evaluationLocalDate: '2026-03-15',
          timezoneId: 'Asia/Kolkata',
          evaluationUtc: _crossUserEvaluationAt,
        ),
      ),
    );
    expect(crossUser.status, B04AdaptiveTargetStatus.invalidEvidence);
    expect(crossUser.reasonCode, 'eligibility_lineage_invalid');
    expect(crossUser.adaptiveDeltaKcal, 0);
  });

  test(
    'readiness hold and safety uncertainty never create numerical output',
    () {
      final readiness = B04TrainingOverlayResult.unavailable;
      expect(readiness.policyVersion, kB04ReadinessHoldPolicyVersion);
      expect(readiness.calorieDeltaKcal, 0);
      expect(readiness.trainingLoadDeltaPercent, 0);
      expect(readiness.trainingIntensityDeltaPercent, 0);
      expect(readiness.scheduleDurationDelta, 0);
      expect(readiness.numericalProposalAllowed, isFalse);

      final matrix = B04AdaptiveCoachingFixtureMatrix.current;
      for (final id in [
        'dietary-possible-unavailable',
        'dietary-unknown-unavailable',
        'dietary-insufficient-unavailable',
        'missing-required-evidence',
      ]) {
        final state = matrix.states.singleWhere((item) => item.id == id);
        expect(
          state.expectedOutcome,
          isIn([
            B04FixtureOutcome.unavailable,
            B04FixtureOutcome.invalidEvidence,
          ]),
          reason: id,
        );
        expect(state.adaptiveDeltaKcal, 0, reason: id);
        expect(state.userSetTargetPreserved, isTrue, reason: id);
      }
    },
  );

  test('local civil-date history remains stable across DST and midnight', () {
    final dates = LocalScheduleDateService();
    const timezoneId = 'America/New_York';

    expect(
      dates.localDateFor(DateTime.utc(2026, 3, 8, 4, 59), timezoneId),
      '2026-03-07',
    );
    expect(
      dates.localDateFor(DateTime.utc(2026, 3, 8, 5), timezoneId),
      '2026-03-08',
    );
    expect(
      dates.localDateFor(DateTime.utc(2026, 3, 9, 3, 59), timezoneId),
      '2026-03-08',
    );
    expect(
      dates.localDateFor(DateTime.utc(2026, 3, 9, 4), timezoneId),
      '2026-03-09',
    );
    expect(dates.addCalendarDays('2026-03-07', timezoneId, 1), '2026-03-08');
    expect(dates.addCalendarDays('2026-03-08', timezoneId, 1), '2026-03-09');
  });
}

B04AdaptiveTargetRequest _request({
  B04ActivationMetadata activation = const B04ActivationMetadata(),
  String evaluationLocalDate = '2026-03-15',
  String? storedPolicyVersion,
  CoachingEligibilityReadModel? eligibility,
}) => B04AdaptiveTargetRequest(
  evaluationId: 'b04-16-evaluation',
  userId: 'user-a',
  evaluationLocalDate: evaluationLocalDate,
  timezoneId: 'Asia/Kolkata',
  evaluatedAtUtc: _evaluationTimestamp(evaluationLocalDate),
  explicitlyInitiated: true,
  adaptiveConsentEnabled: true,
  storedPolicyVersion: storedPolicyVersion,
  activation: activation,
  eligibility: eligibility,
  activeGoal: null,
  goalRate: null,
  bodyMetrics: null,
  maintenanceEvidence: null,
);

DateTime _evaluationTimestamp(String localDate) {
  final date = DateTime.parse(localDate);
  return DateTime.utc(date.year, date.month, date.day, 10);
}

final _crossUserEvaluationAt = DateTime.utc(2026, 3, 15, 10);
