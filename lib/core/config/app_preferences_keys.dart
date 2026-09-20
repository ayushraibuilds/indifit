/// Centralized registry of all SharedPreferences keys used across IndiFit.
///
/// Every key string in this catalogue is byte-identical to persisted keys on disk.
/// Drift column names (e.g. `equipment_access`, `injuries_limitations`) are deliberately
/// not used here; actual disk keys are `user_equipment` and `user_injuries`.
///
/// Restore-only keys are marked with `@deprecated` to ensure they are never targeted
/// by active write flows.
abstract final class AppPreferenceKeys {
  // --- Core System & Privacy ---
  static const offlineOnly = 'offline_only';
  static const crashReportingEnabled = 'pref_crash_reporting_enabled';
  static const dpdpAiConsentAccepted = 'dpdp_ai_consent_accepted';
  static const dpdpAiConsentAcceptedAt = 'dpdp_ai_consent_accepted_at';
  static const userThemeMode = 'user_theme_mode';
  static const displayUnits = 'display_units';

  // --- Onboarding Status ---
  static const onboardingCompleted = 'onboarding_completed';
  static const onboardingSkipped = 'onboarding_skipped';
  static const todayOnboardingHandoffPending = 'today_onboarding_handoff_pending';

  // --- Hydration ---
  static const waterLogged = 'water_logged';
  static const waterGoal = 'water_goal';
  static const waterGlassSize = 'water_glass_size';
  static const waterLastLoggedDate = 'water_last_logged_date';
  static const prefHydrationDailyGoalMl = 'pref_hydration_daily_goal_ml';
  static const prefHydrationEntriesJson = 'pref_hydration_entries_json';

  // --- Streaks & Freezes (Active) ---
  static const userStreakCount = 'user_streak_count';
  static const streakFreezesCount = 'streak_freezes_count';
  static const lastFreezeClaimedAt = 'last_freeze_claimed_at';

  // --- User Profile & Goals (Active - exact disk strings) ---
  static const userName = 'user_name';
  static const userAge = 'user_age';
  static const userHeight = 'user_height';
  static const userWeight = 'user_weight';
  static const currentWeight = 'current_weight';
  static const userTargetWeight = 'user_target_weight';
  static const userSex = 'user_sex';
  static const userActivityLevel = 'user_activity_level';
  static const userGoal = 'user_goal';
  static const userDietPreference = 'user_diet_preference';
  static const userEquipment = 'user_equipment';
  static const userInjuries = 'user_injuries';
  static const calorieGoal = 'calorie_goal';
  static const proteinGoal = 'protein_goal';
  static const carbsGoal = 'carbs_goal';
  static const fatGoal = 'fat_goal';

  // --- Notifications & Quiet Hours ---
  static const prefRemindWorkout = 'pref_remind_workout';
  static const prefRemindMeals = 'pref_remind_meals';
  static const prefRemindWater = 'pref_remind_water';
  static const prefRemindEvening = 'pref_remind_evening';
  static const prefRemindWeekly = 'pref_remind_weekly';
  static const prefQuietHoursEnabled = 'pref_quiet_hours_enabled';
  static const prefQuietHoursStart = 'pref_quiet_hours_start';
  static const prefQuietHoursEnd = 'pref_quiet_hours_end';
  static const prefWorkoutReminderDays = 'pref_workout_reminder_days';
  static const prefWorkoutReminderHour = 'pref_workout_reminder_hour';
  static const prefWorkoutReminderMinute = 'pref_workout_reminder_minute';
  static const prefLunchReminderHour = 'pref_lunch_reminder_hour';
  static const prefLunchReminderMinute = 'pref_lunch_reminder_minute';
  static const prefDinnerReminderHour = 'pref_dinner_reminder_hour';
  static const prefDinnerReminderMinute = 'pref_dinner_reminder_minute';
  static const prefWaterReminderHour = 'pref_water_reminder_hour';
  static const prefWaterReminderMinute = 'pref_water_reminder_minute';
  static const prefDailyLoggingReminderHour = 'pref_daily_logging_reminder_hour';
  static const prefDailyLoggingReminderMinute = 'pref_daily_logging_reminder_minute';
  static const prefWeeklyProgressDay = 'pref_weekly_progress_day';
  static const prefWeeklyProgressHour = 'pref_weekly_progress_hour';
  static const prefWeeklyProgressMinute = 'pref_weekly_progress_minute';
  static const lastScheduledTimezoneId = 'last_scheduled_timezone_id';
  static const lastUtcOffsetMinutes = 'last_utc_offset_minutes';

  // --- Health Integration ---
  static const healthIntegrationEnabled = 'health_integration_enabled';
  static const healthPermissionRequestedPrefix = 'health_permission_requested_';
  static const healthLastSyncTime = 'health_last_sync_time';
  static const healthCategorySteps = 'health_category_steps';
  static const healthCategoryActiveEnergy = 'health_category_active_energy';
  static const healthCategorySleep = 'health_category_sleep';
  static const healthCategoryRestingHeartRate = 'health_category_resting_heart_rate';
  static const healthCategoryWorkoutImport = 'health_category_workout_import';
  static const healthCategoryWorkoutExport = 'health_category_workout_export';
  static const healthCategoryWeightExport = 'health_category_weight_export';

  // --- Food & Diary ---
  static const prefDiaryMealSlots = 'pref_diary_meal_slots';

  // --- Achievements & Weekly Actions ---
  static const unlockedAchievementIds = 'unlocked_achievement_ids';
  static const weeklyActionType = 'weekly_action_type';
  static const weeklyActionText = 'weekly_action_text';
  static const weeklyActionTarget = 'weekly_action_target';

  // --- Auto Backup ---
  static const autoBackupLastContentFingerprintV2 = 'auto_backup_last_content_fingerprint_v2';

  // --- Resumable Onboarding Draft Keys (17 keys) ---
  static const onboardingDraftPage = 'onboarding_draft_page';
  static const onboardingDraftSex = 'onboarding_draft_sex';
  static const onboardingDraftName = 'onboarding_draft_name';
  static const onboardingDraftAge = 'onboarding_draft_age';
  static const onboardingDraftHeight = 'onboarding_draft_height';
  static const onboardingDraftWeight = 'onboarding_draft_weight';
  static const onboardingDraftActivity = 'onboarding_draft_activity';
  static const onboardingDraftGoal = 'onboarding_draft_goal';
  static const onboardingDraftTargetWeight = 'onboarding_draft_target_weight';
  static const onboardingDraftDiet = 'onboarding_draft_diet';
  static const onboardingDraftFlowVersion = 'onboarding_draft_flow_version';
  static const onboardingDraftRoutineStep = 'onboarding_draft_routine_step';
  static const onboardingDraftRoutineGoal = 'onboarding_draft_routine_goal';
  static const onboardingDraftRoutineEquipment = 'onboarding_draft_routine_equipment';
  static const onboardingDraftRoutineDays = 'onboarding_draft_routine_days';
  static const onboardingDraftRoutineExperience = 'onboarding_draft_routine_experience';
  static const onboardingDraftRoutineInjuries = 'onboarding_draft_routine_injuries';

  // --- Legacy / Restore-Only Aliases (NEVER ACTIVE WRITE TARGETS) ---
  @Deprecated('Historical/restore-only key; never use as active write target')
  static const lastStreakDate = 'last_streak_date';
  @Deprecated('Historical/restore-only key; never use as active write target')
  static const prefStreakFreezeCount = 'pref_streak_freeze_count';
  @Deprecated('Historical/restore-only key; never use as active write target')
  static const weeklyActionTargetDate = 'weekly_action_target_date';
  @Deprecated('Historical/restore-only key; never use as active write target')
  static const installedFoodPacks = 'installed_food_packs';
  @Deprecated('Historical/restore-only key; never use as active write target')
  static const autoSyncHealthOnOpen = 'auto_sync_health_on_open';
  @Deprecated('Historical/restore-only key; never use as active write target')
  static const prefAchievementsJson = 'pref_achievements_json';
  @Deprecated('Historical/restore-only key; never use as active write target')
  static const legacyPrefOfflineOnly = 'pref_offline_only';
  @Deprecated('Historical/restore-only key; never use as active write target')
  static const legacyPrefRemindWorkout = 'prefRemindWorkout';
  @Deprecated('Historical/restore-only key; never use as active write target')
  static const legacyPrefRemindMeals = 'prefRemindMeals';
  @Deprecated('Historical/restore-only key; never use as active write target')
  static const legacyPrefRemindWater = 'prefRemindWater';
  @Deprecated('Historical/restore-only key; never use as active write target')
  static const legacyPrefRemindEvening = 'prefRemindEvening';
  @Deprecated('Historical/restore-only key; never use as active write target')
  static const legacyPrefRemindWeekly = 'prefRemindWeekly';
  @Deprecated('Historical/restore-only key; never use as active write target')
  static const legacyPrefQuietHoursEnabled = 'prefQuietHoursEnabled';
  @Deprecated('Historical/restore-only key; never use as active write target')
  static const legacyPrefQuietHoursStart = 'prefQuietHoursStart';
  @Deprecated('Historical/restore-only key; never use as active write target')
  static const legacyPrefQuietHoursEnd = 'prefQuietHoursEnd';
}
