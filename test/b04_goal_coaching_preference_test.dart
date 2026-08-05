import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_v9.dart';
import 'package:indifit/core/di/user_profile_provider.dart';
import 'package:indifit/core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/repositories/coaching_preference_repository.dart';
import 'package:indifit/data/repositories/nutrition_goal_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NutritionGoalRepository goals;
  late CoachingPreferenceRepository preferences;

  setUp(() {
    db = AppDatabase.memory();
    goals = NutritionGoalRepository(database: db);
    preferences = CoachingPreferenceRepository(database: db);
  });

  tearDown(() => db.close());

  NutritionGoalCommand legacyCommand({
    String userId = 'user-a',
    String date = '2026-01-01',
  }) => NutritionGoalCommand(
    userId: userId,
    goalType: NutritionGoalType.maintenance,
    calorieTargetKcal: 2000,
    proteinTargetG: 140,
    carbsTargetG: 220,
    fatTargetG: 60,
    effectiveFromLocalDate: date,
    timezoneId: 'Asia/Kolkata',
  );

  test(
    'compatibility import, same-day replacement and historical reads',
    () async {
      final imported = await goals.ensureCompatibilityImport(
        userId: 'user-a',
        legacyProfile: legacyCommand(),
      );
      expect(imported.source, NutritionGoalSource.compatibility);

      final replacement = await goals.recordUserSetGoal(
        const NutritionGoalCommand(
          userId: 'user-a',
          goalType: NutritionGoalType.loss,
          calorieTargetKcal: 1800,
          proteinTargetG: 150,
          carbsTargetG: 180,
          fatTargetG: 60,
          effectiveFromLocalDate: '2026-02-01',
          timezoneId: 'Asia/Kolkata',
          commandId: 'goal-change-1',
        ),
      );
      expect(replacement.isUserSet, isTrue);
      expect(replacement.supersedesGoalVersionId, imported.id);

      final retry = await goals.recordUserSetGoal(
        const NutritionGoalCommand(
          userId: 'user-a',
          goalType: NutritionGoalType.loss,
          calorieTargetKcal: 1800,
          proteinTargetG: 150,
          carbsTargetG: 180,
          fatTargetG: 60,
          effectiveFromLocalDate: '2026-02-01',
          timezoneId: 'Asia/Kolkata',
          commandId: 'goal-change-1',
        ),
      );
      expect(retry.id, replacement.id);
      expect(await goals.listVersions(userId: 'user-a'), hasLength(2));

      final oldRead = await goals.activeGoal(
        userId: 'user-a',
        localDate: '2026-01-31',
        timezoneId: 'Asia/Kolkata',
      );
      final newRead = await goals.activeGoal(
        userId: 'user-a',
        localDate: '2026-02-01',
        timezoneId: 'Asia/Kolkata',
      );
      expect(oldRead!.id, imported.id);
      expect(newRead!.id, replacement.id);

      final reset = await goals.evaluationWindow(
        userId: 'user-a',
        localDate: '2026-02-01',
        timezoneId: 'Asia/Kolkata',
      );
      expect(reset.resetReason, 'user_goal_change');
      expect(reset.earliestEvaluationLocalDate, '2026-02-22');
      expect(reset.isReadyOn('2026-02-21'), isFalse);
      expect(reset.isReadyOn('2026-02-22'), isTrue);
    },
  );

  test(
    'consent is default-off, separate, append-only and retry-idempotent',
    () async {
      final before = await preferences.currentPreferences(userId: 'user-a');
      expect(before.adaptiveCoachingEnabled, isFalse);
      expect(before.optionalAiEnabled, isFalse);

      final timestamp = DateTime.utc(2026, 2, 1, 10);
      final enable = await preferences.recordConsent(
        CoachingConsentCommand(
          userId: 'user-a',
          category: CoachingConsentCategory.adaptiveCoaching,
          action: CoachingConsentAction.enable,
          consentPolicyVersion: kB04EnabledPolicyVersion,
          copyVersion: 'coaching-copy-v1',
          timestampUtc: timestamp,
          localDate: '2026-02-01',
          timezoneId: 'Asia/Kolkata',
          actorSource: 'settings',
          eventId: 'consent-enable-1',
        ),
      );
      final retry = await preferences.recordConsent(
        CoachingConsentCommand(
          userId: 'user-a',
          category: CoachingConsentCategory.adaptiveCoaching,
          action: CoachingConsentAction.enable,
          consentPolicyVersion: kB04EnabledPolicyVersion,
          copyVersion: 'coaching-copy-v1',
          timestampUtc: timestamp,
          localDate: '2026-02-01',
          timezoneId: 'Asia/Kolkata',
          actorSource: 'settings',
          eventId: 'transport-retry-id',
        ),
      );
      expect(retry.id, enable.id);

      await preferences.recordConsent(
        CoachingConsentCommand(
          userId: 'user-a',
          category: CoachingConsentCategory.optionalAi,
          action: CoachingConsentAction.enable,
          consentPolicyVersion: 'AI-CONSENT-1',
          copyVersion: 'ai-copy-v1',
          timestampUtc: timestamp.add(const Duration(minutes: 1)),
          localDate: '2026-02-01',
          timezoneId: 'Asia/Kolkata',
          actorSource: 'settings',
          eventId: 'consent-ai-1',
        ),
      );
      final enabled = await preferences.currentPreferences(userId: 'user-a');
      expect(enabled.adaptiveCoachingEnabled, isTrue);
      expect(enabled.optionalAiEnabled, isTrue);

      await preferences.recordConsent(
        CoachingConsentCommand(
          userId: 'user-a',
          category: CoachingConsentCategory.adaptiveCoaching,
          action: CoachingConsentAction.withdraw,
          consentPolicyVersion: kB04EnabledPolicyVersion,
          copyVersion: 'coaching-copy-v1',
          timestampUtc: timestamp.add(const Duration(hours: 1)),
          localDate: '2026-02-01',
          timezoneId: 'Asia/Kolkata',
          actorSource: 'settings',
          eventId: 'consent-withdraw-1',
          relatedOrSupersededEventId: enable.id,
        ),
      );
      final disabled = await preferences.currentPreferences(userId: 'user-a');
      expect(disabled.adaptiveCoachingEnabled, isFalse);
      expect(
        await preferences.listConsentHistory(userId: 'user-a'),
        hasLength(3),
      );
      final projection = await db
          .select(db.nutritionCoachingPreferences)
          .getSingle();
      expect(projection.adaptiveCoachingEnabled, isFalse);
      expect(projection.optionalAiEnabled, isTrue);
    },
  );

  test(
    'eligibility and consent gate adaptive availability without rewriting goals',
    () async {
      await goals.ensureCompatibilityImport(
        userId: 'user-a',
        legacyProfile: legacyCommand(),
      );
      await preferences.recordConsent(
        CoachingConsentCommand(
          userId: 'user-a',
          category: CoachingConsentCategory.adaptiveCoaching,
          action: CoachingConsentAction.enable,
          consentPolicyVersion: kB04EnabledPolicyVersion,
          copyVersion: 'copy-v1',
          timestampUtc: DateTime.utc(2026, 2, 1),
          localDate: '2026-02-01',
          timezoneId: 'Asia/Kolkata',
          actorSource: 'settings',
        ),
      );

      final noAge = await preferences.adaptiveAvailability(userId: 'user-a');
      expect(noAge.available, isFalse);
      expect(noAge.reasonCode, 'coaching_unavailable_age');

      await db
          .into(db.coachingEligibilityEvaluations)
          .insert(
            CoachingEligibilityEvaluationsCompanion.insert(
              id: 'age-underage',
              userId: 'user-a',
              result: 'underage',
              reasonCode: 'coaching_unavailable_age',
              ageInputSource: 'verified_dob',
              evidenceTimestampUtc: DateTime.utc(2026, 1, 31),
              evaluationUtc: DateTime.utc(2026, 2, 1),
              evaluationLocalDate: '2026-02-01',
              timezoneId: 'Asia/Kolkata',
              policyVersion: kB04EnabledPolicyVersion,
              minimumAgeRuleVersion: 'minimum-age-v1',
            ),
          );
      final underage = await preferences.adaptiveAvailability(userId: 'user-a');
      expect(underage.available, isFalse);
      expect(underage.reasonCode, 'coaching_unavailable_age');

      await db
          .into(db.coachingEligibilityEvaluations)
          .insert(
            CoachingEligibilityEvaluationsCompanion.insert(
              id: 'age-birthday',
              userId: 'user-a',
              result: 'eligible',
              reasonCode: 'eligible',
              ageInputSource: 'verified_dob',
              evidenceTimestampUtc: DateTime.utc(2026, 2, 2),
              evaluationUtc: DateTime.utc(2026, 2, 2),
              evaluationLocalDate: '2026-02-02',
              timezoneId: 'Asia/Kolkata',
              policyVersion: kB04EnabledPolicyVersion,
              minimumAgeRuleVersion: 'minimum-age-v1',
            ),
          );
      final birthday = await preferences.adaptiveAvailability(userId: 'user-a');
      expect(birthday.available, isTrue);
      expect(birthday.eligibility!.result, CoachingEligibilityResult.eligible);

      await db
          .into(db.coachingEligibilityEvaluations)
          .insert(
            CoachingEligibilityEvaluationsCompanion.insert(
              id: 'age-withheld',
              userId: 'user-a',
              result: 'withheld_age',
              reasonCode: 'coaching_unavailable_age',
              ageInputSource: 'withheld',
              evidenceTimestampUtc: DateTime.utc(2026, 2, 3),
              evaluationUtc: DateTime.utc(2026, 2, 3),
              evaluationLocalDate: '2026-02-03',
              timezoneId: 'Asia/Kolkata',
              policyVersion: kB04EnabledPolicyVersion,
              minimumAgeRuleVersion: 'minimum-age-v1',
            ),
          );
      final withheld = await preferences.adaptiveAvailability(userId: 'user-a');
      expect(withheld.available, isFalse);
      expect(
        withheld.eligibility!.result,
        CoachingEligibilityResult.withheldAge,
      );
    },
  );

  test(
    'acceptance stores canonical exact metadata once and rejects HOLD-1',
    () async {
      await goals.ensureCompatibilityImport(
        userId: 'user-a',
        legacyProfile: legacyCommand(),
      );
      await preferences.recordConsent(
        CoachingConsentCommand(
          userId: 'user-a',
          category: CoachingConsentCategory.adaptiveCoaching,
          action: CoachingConsentAction.enable,
          consentPolicyVersion: kB04EnabledPolicyVersion,
          copyVersion: 'copy-v1',
          timestampUtc: DateTime.utc(2026, 2, 1),
          localDate: '2026-02-01',
          timezoneId: 'Asia/Kolkata',
          actorSource: 'settings',
        ),
      );
      await db
          .into(db.coachingEligibilityEvaluations)
          .insert(
            CoachingEligibilityEvaluationsCompanion.insert(
              id: 'age-eligible',
              userId: 'user-a',
              result: 'eligible',
              reasonCode: 'eligible',
              ageInputSource: 'verified_dob',
              evidenceTimestampUtc: DateTime.utc(2026, 1, 31),
              evaluationUtc: DateTime.utc(2026, 2, 1),
              evaluationLocalDate: '2026-02-01',
              timezoneId: 'Asia/Kolkata',
              policyVersion: kB04EnabledPolicyVersion,
              minimumAgeRuleVersion: 'minimum-age-v1',
            ),
          );
      final proposal = AdaptiveGoalProposal(
        id: 'proposal-1',
        userId: 'user-a',
        goalType: NutritionGoalType.loss,
        goalRate: '-0.50% body weight/week',
        calorieTargetKcal: 1800,
        policyVersion: kB04EnabledPolicyVersion,
        effectiveFromLocalDate: '2026-03-01',
        timezoneId: 'Asia/Kolkata',
        evidenceFingerprint: 'frozen-result-1',
        exactResultNumerator: '1800',
        exactResultDenominator: '1',
        normalizedMaintenanceKcal: 2000,
      );
      await expectLater(
        goals.acceptAdaptiveProposal(
          proposal: proposal,
          adaptiveConsentEnabled: false,
          ageEligible: true,
        ),
        throwsA(
          isA<B04GoalValidationError>().having(
            (error) => error.code,
            'code',
            'coaching_consent_required',
          ),
        ),
      );
      final accepted = await goals.acceptAdaptiveProposal(
        proposal: proposal,
        adaptiveConsentEnabled: true,
        ageEligible: true,
        acceptanceCommandId: 'accept-1',
      );
      final retry = await goals.acceptAdaptiveProposal(
        proposal: proposal,
        adaptiveConsentEnabled: true,
        ageEligible: true,
        acceptanceCommandId: 'retry-with-new-command',
      );
      expect(retry.id, accepted.id);
      expect(retry.source, NutritionGoalSource.adaptive);
      expect(retry.exactResultNumerator, '1800');
      expect(retry.normalizedMaintenanceKcal, 2000);
      expect(await goals.listVersions(userId: 'user-a'), hasLength(2));

      final hold = proposal.copyWithPolicyVersion(kB04HoldPolicyVersion);
      await expectLater(
        goals.acceptAdaptiveProposal(
          proposal: hold,
          adaptiveConsentEnabled: true,
          ageEligible: true,
        ),
        throwsA(
          isA<B04GoalValidationError>().having(
            (error) => error.code,
            'code',
            'adaptive_policy_not_enabled',
          ),
        ),
      );

      final conflictingProposal = AdaptiveGoalProposal(
        id: 'proposal-conflict',
        userId: proposal.userId,
        goalType: proposal.goalType,
        goalRate: proposal.goalRate,
        calorieTargetKcal: 1750,
        policyVersion: proposal.policyVersion,
        effectiveFromLocalDate: proposal.effectiveFromLocalDate,
        timezoneId: proposal.timezoneId,
        evidenceFingerprint: proposal.evidenceFingerprint,
        exactResultNumerator: proposal.exactResultNumerator,
        exactResultDenominator: proposal.exactResultDenominator,
        normalizedMaintenanceKcal: proposal.normalizedMaintenanceKcal,
      );
      await expectLater(
        goals.acceptAdaptiveProposal(
          proposal: conflictingProposal,
          adaptiveConsentEnabled: true,
          ageEligible: true,
        ),
        throwsA(
          isA<B04GoalConflictError>().having(
            (error) => error.code,
            'code',
            'adaptive_acceptance_conflict',
          ),
        ),
      );
    },
  );

  test(
    'equal-time history uses deterministic creation order and policy lineage',
    () async {
      final timestamp = DateTime.utc(2026, 2, 1, 10);
      await db
          .into(db.coachingConsentEvents)
          .insert(
            CoachingConsentEventsCompanion.insert(
              id: 'consent-tie-enable',
              userId: 'user-a',
              consentCategory: 'adaptive_coaching',
              action: 'enable',
              consentPolicyVersion: kB04EnabledPolicyVersion,
              copyVersion: 'copy-v1',
              timestampUtc: timestamp,
              localDate: '2026-02-01',
              timezoneId: 'Asia/Kolkata',
              actorSource: 'settings',
              createdAtUtc: Value(timestamp),
            ),
          );
      await db
          .into(db.coachingConsentEvents)
          .insert(
            CoachingConsentEventsCompanion.insert(
              id: 'consent-tie-disable',
              userId: 'user-a',
              consentCategory: 'adaptive_coaching',
              action: 'disable',
              consentPolicyVersion: kB04EnabledPolicyVersion,
              copyVersion: 'copy-v1',
              timestampUtc: timestamp,
              localDate: '2026-02-01',
              timezoneId: 'Asia/Kolkata',
              actorSource: 'settings',
              createdAtUtc: Value(timestamp.add(const Duration(minutes: 1))),
            ),
          );
      final current = await preferences.currentPreferences(
        userId: 'user-a',
        atUtc: timestamp,
      );
      expect(current.adaptiveCoachingEnabled, isFalse);
      expect(current.adaptiveCoachingEvent!.id, 'consent-tie-disable');
      expect(
        (await preferences.listConsentHistory(
          userId: 'user-a',
        )).map((event) => event.id),
        ['consent-tie-enable', 'consent-tie-disable'],
      );

      await db
          .into(db.coachingEligibilityEvaluations)
          .insert(
            CoachingEligibilityEvaluationsCompanion.insert(
              id: 'eligibility-tie-enabled',
              userId: 'user-a',
              result: 'eligible',
              reasonCode: 'eligible',
              ageInputSource: 'verified_dob',
              evidenceTimestampUtc: timestamp,
              evaluationUtc: timestamp,
              evaluationLocalDate: '2026-02-01',
              timezoneId: 'Asia/Kolkata',
              policyVersion: kB04EnabledPolicyVersion,
              minimumAgeRuleVersion: 'minimum-age-v1',
              createdAtUtc: Value(timestamp),
            ),
          );
      await db
          .into(db.coachingEligibilityEvaluations)
          .insert(
            CoachingEligibilityEvaluationsCompanion.insert(
              id: 'eligibility-tie-hold',
              userId: 'user-a',
              result: 'underage',
              reasonCode: 'coaching_unavailable_age',
              ageInputSource: 'verified_dob',
              evidenceTimestampUtc: timestamp,
              evaluationUtc: timestamp,
              evaluationLocalDate: '2026-02-01',
              timezoneId: 'Asia/Kolkata',
              policyVersion: kB04HoldPolicyVersion,
              minimumAgeRuleVersion: 'minimum-age-v1',
              createdAtUtc: Value(timestamp.add(const Duration(minutes: 1))),
            ),
          );
      expect(
        (await preferences.currentEligibility(userId: 'user-a'))!.result,
        CoachingEligibilityResult.underage,
      );
    },
  );

  test(
    'eligible HOLD history cannot expose or accept an enabled proposal',
    () async {
      await goals.ensureCompatibilityImport(
        userId: 'user-a',
        legacyProfile: legacyCommand(),
      );
      await preferences.recordConsent(
        CoachingConsentCommand(
          userId: 'user-a',
          category: CoachingConsentCategory.adaptiveCoaching,
          action: CoachingConsentAction.enable,
          consentPolicyVersion: kB04EnabledPolicyVersion,
          copyVersion: 'copy-v1',
          timestampUtc: DateTime.utc(2026, 2, 1),
          localDate: '2026-02-01',
          timezoneId: 'Asia/Kolkata',
          actorSource: 'settings',
        ),
      );
      await db
          .into(db.coachingEligibilityEvaluations)
          .insert(
            CoachingEligibilityEvaluationsCompanion.insert(
              id: 'eligible-under-hold',
              userId: 'user-a',
              result: 'eligible',
              reasonCode: 'eligible',
              ageInputSource: 'verified_dob',
              evidenceTimestampUtc: DateTime.utc(2026, 2, 1),
              evaluationUtc: DateTime.utc(2026, 2, 1),
              evaluationLocalDate: '2026-02-01',
              timezoneId: 'Asia/Kolkata',
              policyVersion: kB04HoldPolicyVersion,
              minimumAgeRuleVersion: 'minimum-age-v1',
            ),
          );

      final availability = await preferences.adaptiveAvailability(
        userId: 'user-a',
      );
      expect(availability.available, isFalse);
      expect(availability.reasonCode, 'adaptive_policy_hold');

      final proposal = AdaptiveGoalProposal(
        id: 'proposal-under-hold',
        userId: 'user-a',
        goalType: NutritionGoalType.loss,
        goalRate: '-0.50% body weight/week',
        calorieTargetKcal: 1800,
        policyVersion: kB04EnabledPolicyVersion,
        effectiveFromLocalDate: '2026-03-01',
        timezoneId: 'Asia/Kolkata',
        evidenceFingerprint: 'hold-result',
        exactResultNumerator: '1800',
        exactResultDenominator: '1',
        normalizedMaintenanceKcal: 2000,
      );
      await expectLater(
        goals.acceptAdaptiveProposal(
          proposal: proposal,
          adaptiveConsentEnabled: true,
          ageEligible: true,
        ),
        throwsA(
          isA<B04GoalValidationError>().having(
            (error) => error.code,
            'code',
            'adaptive_policy_not_enabled',
          ),
        ),
      );
      expect(await goals.listVersions(userId: 'user-a'), hasLength(1));
    },
  );

  test(
    'future effective targets preserve the current legacy mirror and goal retries conflict safely',
    () async {
      final profileId = await db
          .into(db.userProfiles)
          .insert(
            UserProfilesCompanion.insert(
              calorieGoal: const Value(2000),
              proteinGoal: const Value(140),
              carbsGoal: const Value(220),
              fatGoal: const Value(60),
            ),
          );
      final dates = LocalScheduleDateService(
        nowUtc: () => DateTime.utc(2026, 1, 10, 12),
      );
      final repository = NutritionGoalRepository(database: db, dates: dates);
      await repository.ensureCompatibilityImport(
        userId: '$profileId',
        legacyProfile: legacyCommand(userId: '$profileId'),
      );

      final future = await repository.recordUserSetGoal(
        const NutritionGoalCommand(
          userId: '1',
          goalType: NutritionGoalType.loss,
          calorieTargetKcal: 1800,
          effectiveFromLocalDate: '2026-02-01',
          timezoneId: 'Asia/Kolkata',
          commandId: 'future-goal-1',
        ),
      );
      expect(future.calorieTargetKcal, 1800);
      expect(future.proteinTargetG, 140);
      expect(future.carbsTargetG, 220);
      expect(future.fatTargetG, 60);
      final profile = await (db.select(
        db.userProfiles,
      )..where((row) => row.id.equals(profileId))).getSingle();
      expect(profile.calorieGoal, 2000);
      expect(profile.goal, 'maintain');

      await expectLater(
        repository.recordUserSetGoal(
          const NutritionGoalCommand(
            userId: '1',
            goalType: NutritionGoalType.loss,
            calorieTargetKcal: 1700,
            effectiveFromLocalDate: '2026-02-01',
            timezoneId: 'Asia/Kolkata',
            commandId: 'future-goal-1',
          ),
        ),
        throwsA(
          isA<B04GoalConflictError>().having(
            (error) => error.code,
            'code',
            'goal_command_conflict',
          ),
        ),
      );
    },
  );

  test(
    'profile updates use canonical goal history and failed database writes do not update legacy state',
    () async {
      SharedPreferences.setMockInitialValues({});
      await db.into(db.userProfiles).insert(UserProfilesCompanion.insert());
      final profileNotifier = UserProfileNotifier(db);
      await profileNotifier.loadProfile();
      await profileNotifier.updateProfile(
        goal: 'gain',
        calorieGoal: 2600,
        proteinGoal: 160,
      );

      final repository = NutritionGoalRepository(database: db);
      final versions = await repository.listVersions(userId: '1');
      expect(versions, hasLength(2));
      expect(versions.last.source, NutritionGoalSource.userSet);
      expect(versions.last.goalType, NutritionGoalType.gain);
      expect(versions.last.calorieTargetKcal, 2600);
      expect(versions.last.proteinTargetG, 160);
      expect((await db.select(db.userProfiles).getSingle()).calorieGoal, 2600);
      expect(
        (await SharedPreferences.getInstance()).getInt('calorie_goal'),
        null,
      );

      final beforeFailure = profileNotifier.state;
      final closedDb = AppDatabase.memory();
      final failedNotifier = UserProfileNotifier(closedDb);
      await closedDb.close();
      await expectLater(
        failedNotifier.updateProfile(goal: 'loss', calorieGoal: 1700),
        throwsA(anything),
      );
      expect(profileNotifier.state.calorieGoal, beforeFailure.calorieGoal);
      expect(profileNotifier.state.userGoal, beforeFailure.userGoal);
    },
  );

  test(
    'goal and consent history survive restart and Backup v9 restore',
    () async {
      final directory = await Directory.systemTemp.createTemp('b04-goals-');
      final file = File('${directory.path}/goals.db');
      final first = AppDatabase.executor(NativeDatabase(file));
      await first
          .into(first.userProfiles)
          .insert(UserProfilesCompanion.insert());
      final firstGoals = NutritionGoalRepository(database: first);
      final firstPreferences = CoachingPreferenceRepository(database: first);
      await firstGoals.ensureCompatibilityImport(
        userId: '1',
        legacyProfile: legacyCommand(userId: '1'),
      );
      await firstPreferences.recordConsent(
        CoachingConsentCommand(
          userId: '1',
          category: CoachingConsentCategory.adaptiveCoaching,
          action: CoachingConsentAction.enable,
          consentPolicyVersion: kB04EnabledPolicyVersion,
          copyVersion: 'copy-v1',
          timestampUtc: DateTime.utc(2026, 1, 1),
          localDate: '2026-01-01',
          timezoneId: 'Asia/Kolkata',
          actorSource: 'settings',
        ),
      );
      await first.close();

      final reopened = AppDatabase.executor(NativeDatabase(file));
      final reopenedGoals = NutritionGoalRepository(database: reopened);
      final reopenedPreferences = CoachingPreferenceRepository(
        database: reopened,
      );
      expect(await reopenedGoals.listVersions(userId: '1'), hasLength(1));
      expect(
        (await reopenedPreferences.currentPreferences(
          userId: '1',
        )).adaptiveCoachingEnabled,
        isTrue,
      );

      final backup = await BackupV9Data.createFromDatabase(reopened);
      final restored = AppDatabase.memory();
      final decoded = BackupV9Data.fromJson(backup.toJson());
      await decoded.restoreToDatabase(restored);
      expect(
        await NutritionGoalRepository(
          database: restored,
        ).listVersions(userId: '1'),
        hasLength(1),
      );
      expect(
        (await CoachingPreferenceRepository(
          database: restored,
        ).currentPreferences(userId: '1')).adaptiveCoachingEnabled,
        isTrue,
      );
      await reopened.close();
      await restored.close();
      await directory.delete(recursive: true);
    },
  );
}

extension on AdaptiveGoalProposal {
  AdaptiveGoalProposal copyWithPolicyVersion(String policyVersion) =>
      AdaptiveGoalProposal(
        id: id,
        userId: userId,
        goalType: goalType,
        goalRate: goalRate,
        calorieTargetKcal: calorieTargetKcal,
        proteinTargetG: proteinTargetG,
        carbsTargetG: carbsTargetG,
        fatTargetG: fatTargetG,
        policyVersion: policyVersion,
        calculationVersion: calculationVersion,
        algorithmVersion: algorithmVersion,
        effectiveFromLocalDate: effectiveFromLocalDate,
        timezoneId: timezoneId,
        evidenceFingerprint: evidenceFingerprint,
        exactResultNumerator: exactResultNumerator,
        exactResultDenominator: exactResultDenominator,
        normalizedMaintenanceKcal: normalizedMaintenanceKcal,
      );
}
