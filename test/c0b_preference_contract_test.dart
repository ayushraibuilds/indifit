import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/theme_provider.dart';
import 'package:indifit/core/di/user_profile_provider.dart';
import 'package:indifit/core/presentation/today_onboarding_handoff.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/core/services/crash_reporting_service.dart';
import 'package:indifit/core/services/notification_service.dart';
import 'package:indifit/data/repositories/health_service.dart';
import 'package:indifit/features/onboarding/b05_adaptive_onboarding.dart';
import 'package:indifit/features/settings/settings_controller.dart';
import 'package:indifit/features/settings/unit_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/indifit_test_harness.dart';

void main() {
  initializeIndiFitTestHarness();

  setUp(setIndiFitTestPreferences);

  test('public preference keys retain their persisted spellings', () {
    expect(PrivacyPolicyNotifier.prefOfflineOnly, 'offline_only');
    expect(
      PrivacyPolicyNotifier.prefCrashReportingEnabled,
      'pref_crash_reporting_enabled',
    );
    expect(
      CrashReportingService.prefCrashReportingEnabled,
      PrivacyPolicyNotifier.prefCrashReportingEnabled,
    );
    expect(ThemeModeNotifier.prefKey, 'user_theme_mode');
    expect(UnitPreferenceNotifier.key, 'display_units');
    expect(
      todayOnboardingHandoffPendingKey,
      'today_onboarding_handoff_pending',
    );

    expect(
      <String>[
        NotificationService.prefRemindWorkout,
        NotificationService.prefRemindMeals,
        NotificationService.prefRemindWater,
        NotificationService.prefRemindEvening,
        NotificationService.prefRemindWeekly,
        NotificationService.prefQuietHoursEnabled,
        NotificationService.prefQuietHoursStart,
        NotificationService.prefQuietHoursEnd,
        NotificationService.prefWorkoutReminderDays,
        NotificationService.prefWorkoutReminderHour,
        NotificationService.prefWorkoutReminderMinute,
        NotificationService.prefLunchReminderHour,
        NotificationService.prefLunchReminderMinute,
        NotificationService.prefDinnerReminderHour,
        NotificationService.prefDinnerReminderMinute,
        NotificationService.prefDailyLoggingReminderHour,
        NotificationService.prefDailyLoggingReminderMinute,
        NotificationService.prefWeeklyProgressDay,
        NotificationService.prefWeeklyProgressHour,
        NotificationService.prefWeeklyProgressMinute,
        NotificationService.prefLastScheduledTimezoneId,
        NotificationService.prefLastUtcOffsetMinutes,
      ],
      <String>[
        'pref_remind_workout',
        'pref_remind_meals',
        'pref_remind_water',
        'pref_remind_evening',
        'pref_remind_weekly',
        'pref_quiet_hours_enabled',
        'pref_quiet_hours_start',
        'pref_quiet_hours_end',
        'pref_workout_reminder_days',
        'pref_workout_reminder_hour',
        'pref_workout_reminder_minute',
        'pref_lunch_reminder_hour',
        'pref_lunch_reminder_minute',
        'pref_dinner_reminder_hour',
        'pref_dinner_reminder_minute',
        'pref_daily_logging_reminder_hour',
        'pref_daily_logging_reminder_minute',
        'pref_weekly_progress_day',
        'pref_weekly_progress_hour',
        'pref_weekly_progress_minute',
        'last_scheduled_timezone_id',
        'last_utc_offset_minutes',
      ],
    );

    expect(
      HealthService.integrationEnabledPrefKey,
      'health_integration_enabled',
    );
    expect(
      HealthService.permissionRequestedPrefix,
      'health_permission_requested_',
    );
    expect(HealthService.categoryPrefKeys, <HealthCategory, String>{
      HealthCategory.steps: 'health_category_steps',
      HealthCategory.activeEnergy: 'health_category_active_energy',
      HealthCategory.sleep: 'health_category_sleep',
      HealthCategory.restingHeartRate: 'health_category_resting_heart_rate',
      HealthCategory.workoutImport: 'health_category_workout_import',
      HealthCategory.workoutExport: 'health_category_workout_export',
      HealthCategory.weightExport: 'health_category_weight_export',
    });
  });

  test('empty preferences preserve established consumer defaults', () async {
    final prefs = await SharedPreferences.getInstance();
    final privacy = PrivacyPolicyNotifier(prefs);
    final theme = ThemeModeNotifier(prefs);
    final profile = UserProfileNotifier();
    final health = HealthService();
    addTearDown(privacy.dispose);
    addTearDown(theme.dispose);
    addTearDown(profile.dispose);

    await profile.loadProfile();

    expect(privacy.state.isOfflineOnly, isFalse);
    expect(privacy.state.isTelemetryEnabled, isFalse);
    expect(theme.state, ThemeMode.system);
    expect(const SettingsState().quietHoursEnabled, isTrue);
    expect(const SettingsState().quietHoursStart, 22);
    expect(const SettingsState().quietHoursEnd, 7);
    expect(const SettingsState().waterGoal, 8);
    expect(const SettingsState().glassSize, 250);
    expect(NotificationService.defaultWorkoutReminderDays, <int>[
      1,
      2,
      3,
      4,
      5,
      6,
      7,
    ]);
    expect(NotificationService.defaultWorkoutReminderHour, 7);
    expect(NotificationService.defaultWorkoutReminderMinute, 30);
    expect(NotificationService.defaultLunchReminderHour, 13);
    expect(NotificationService.defaultLunchReminderMinute, 30);
    expect(NotificationService.defaultDinnerReminderHour, 20);
    expect(NotificationService.defaultDinnerReminderMinute, 30);
    expect(NotificationService.defaultDailyLoggingReminderHour, 21);
    expect(NotificationService.defaultDailyLoggingReminderMinute, 15);
    expect(NotificationService.defaultWeeklyProgressDay, DateTime.sunday);
    expect(NotificationService.defaultWeeklyProgressHour, 10);
    expect(NotificationService.defaultWeeklyProgressMinute, 0);

    expect(profile.state.isLoaded, isTrue);
    expect(profile.state.hasProfile, isFalse);
    expect(profile.state.calorieGoal, 2000);
    expect(profile.state.proteinGoal, 120);
    expect(profile.state.carbsGoal, 230);
    expect(profile.state.fatGoal, 65);
    expect(profile.state.currentWeight, 74.5);
    expect(profile.state.userSex, 'male');
    expect(profile.state.userAge, 25);
    expect(profile.state.userActivityLevel, 'moderate');
    expect(profile.state.userGoal, 'maintain');
    expect(profile.state.dietPreference, 'veg');
    expect(profile.state.equipmentAccess, 'full_gym');
    expect(profile.state.injuriesLimitations, isEmpty);

    expect(await health.getIntegrationEnabled(), isFalse);
    expect(await health.getAllCategoryStates(), <HealthCategory, bool>{
      for (final category in HealthCategory.values) category: true,
    });
    expect(prefs.getBool(todayOnboardingHandoffPendingKey) ?? false, isFalse);
  });

  test(
    'onboarding draft stores retain their exact resumable key sets',
    () async {
      const store = B05OnboardingDraftStore();
      await store.saveProfileDraft(
        const B05ProfileOnboardingDraft(
          currentPage: 4,
          sex: 'female',
          name: 'Maya',
          age: '31',
          height: '165',
          weight: '62',
          activityLevel: 'active',
          goal: 'gain',
          targetWeight: '66',
          dietPreference: 'non-veg',
        ),
      );
      await store.saveRoutineDraft(
        const B05RoutineWizardDraft(
          currentStep: 3,
          selectedGoal: 'strength',
          selectedEquipment: 'gym',
          daysPerWeek: 4,
          selectedExperience: 'intermediate',
          injuries: '',
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), <String>{
        'onboarding_draft_page',
        'onboarding_draft_sex',
        'onboarding_draft_name',
        'onboarding_draft_age',
        'onboarding_draft_height',
        'onboarding_draft_weight',
        'onboarding_draft_activity',
        'onboarding_draft_goal',
        'onboarding_draft_target_weight',
        'onboarding_draft_diet',
        'onboarding_draft_flow_version',
        'onboarding_draft_routine_step',
        'onboarding_draft_routine_goal',
        'onboarding_draft_routine_equipment',
        'onboarding_draft_routine_days',
        'onboarding_draft_routine_experience',
        'onboarding_draft_routine_injuries',
      });

      await store.clearProfileDraft();
      await store.clearRoutineDraft();
      expect(prefs.getKeys(), isEmpty);
    },
  );

  test('Today handoff remains absent, pending, then removable', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(todayOnboardingHandoffPendingKey) ?? false, isFalse);
    await markTodayOnboardingHandoffPending();
    expect(prefs.getBool(todayOnboardingHandoffPendingKey), isTrue);
    await clearTodayOnboardingHandoff();
    expect(prefs.containsKey(todayOnboardingHandoffPendingKey), isFalse);
  });
}
