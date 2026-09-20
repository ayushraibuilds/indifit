# C0B Persisted Preference Contract

- Status: Frozen baseline
- Date: 2026-09-01
- Scope: production `SharedPreferences` keys, defaults, ownership, and backup
  classification
- Characterization: `test/c0b_preference_contract_test.dart`

## Contract rule

Existing key spellings and consumer defaults are compatibility contracts. C0B
does not rename keys, consolidate access, change defaults, or promote a
preference into canonical domain authority. Those changes require a separate
migration and product decision.

## Current durable preferences

| Owner | Keys | Type and absent-value behavior |
|---|---|---|
| App gate | `onboarding_completed`, `onboarding_skipped` | bool; absent is false |
| Privacy | `offline_only`, `pref_crash_reporting_enabled` | bool; both default false; offline-only forces telemetry false |
| Presentation | `user_theme_mode`, `display_units` | string; invalid/absent becomes `system` and `Metric` respectively |
| Profile | `user_name`, `user_age`, `user_height`, `user_weight`, `current_weight`, `user_target_weight`, `user_sex`, `user_activity_level`, `user_goal`, `user_diet_preference`, `user_equipment`, `user_injuries` | typed profile mirrors; established fallbacks are characterized below |
| Nutrition targets | `calorie_goal`, `protein_goal`, `carbs_goal`, `fat_goal` | int/double; defaults 2000/120/230/65 |
| Hydration | `water_goal`, `water_glass_size`, `water_logged`, `water_last_logged_date` | int/int/int/string; active UI defaults to 8 glasses, 250 ml, and zero for the current civil date |
| Achievements/streak | `unlocked_achievement_ids`, `user_streak_count`, `streak_freezes_count`, `last_freeze_claimed_at` | string list/int/int/int; empty/zero/one/zero fallbacks |
| Weekly action | `weekly_action_type`, `weekly_action_text`, `weekly_action_target`, `weekly_action_created_at` | string/string/int/string; absent action, target fallback 5 |
| Health | `health_integration_enabled`, `health_last_sync_time`, and the seven `health_category_*` keys | bool/string/bool; integration defaults false and categories default true |

Empty profile storage loads as no profile with: weight 74.5 kg, sex `male`, age
25, activity `moderate`, goal `maintain`, diet `veg`, equipment `full_gym`, and
no injury text. These are UI/service fallbacks, not fabricated canonical user
evidence.

## Notification preferences

The current notification keys are:

- toggles: `pref_remind_workout`, `pref_remind_meals`,
  `pref_remind_water`, `pref_remind_evening`, `pref_remind_weekly`;
- quiet hours: `pref_quiet_hours_enabled`, `pref_quiet_hours_start`,
  `pref_quiet_hours_end`;
- workout schedule: `pref_workout_reminder_days`,
  `pref_workout_reminder_hour`, `pref_workout_reminder_minute`;
- meal schedule: `pref_lunch_reminder_hour`, `pref_lunch_reminder_minute`,
  `pref_dinner_reminder_hour`, `pref_dinner_reminder_minute`;
- daily/weekly schedule: `pref_daily_logging_reminder_hour`,
  `pref_daily_logging_reminder_minute`, `pref_weekly_progress_day`,
  `pref_weekly_progress_hour`, `pref_weekly_progress_minute`.

Absent defaults are all toggles off, quiet hours enabled from 22:00 to 07:00,
workout reminders every day at 07:30, lunch at 13:30, dinner at 20:30, daily
logging at 21:15, and weekly Progress on Sunday at 10:00. Invalid stored days
or times fail closed to those defaults.

`last_scheduled_timezone_id` and `last_utc_offset_minutes` are operational
scheduling metadata, not user choices.

## Resumable and operational keys

These keys are deliberately not personal-truth authority:

| Class | Keys | Lifecycle |
|---|---|---|
| Profile onboarding draft | `onboarding_draft_page`, `_sex`, `_name`, `_age`, `_height`, `_weight`, `_activity`, `_goal`, `_target_weight`, `_diet`, `_flow_version` using the full `onboarding_draft_*` prefix | Removed after completion/skip or explicit clear |
| Routine onboarding draft | `onboarding_draft_routine_step`, `_goal`, `_equipment`, `_days`, `_experience`, `_injuries` | Removed after completion or explicit clear |
| Today handoff | `today_onboarding_handoff_pending` | One-shot; removed when cleared |
| Health permission metadata | `health_permission_requested_<category>` | Operational permission-attempt marker |
| Auto-backup deduplication | `auto_backup_last_content_fingerprint_v2` | Device-local operational fingerprint |
| Notification timezone | `last_scheduled_timezone_id`, `last_utc_offset_minutes` | Replaced when timezone/offset changes |

## Backup compatibility classes

The v7 preference collector retained by v8-v10 supports current keys plus
historical aliases. Historical backup-only aliases include:

- `pref_offline_only`;
- `pref_streak_freeze_count`, `last_streak_date`;
- `auto_sync_health_on_open`;
- `pref_achievements_json`;
- `prefRemindWorkout`, `prefRemindMeals`, `prefRemindWater`,
  `prefRemindEvening`, `prefRemindWeekly`;
- `prefQuietHoursEnabled`, `prefQuietHoursStart`, `prefQuietHoursEnd`;
- `weekly_action_target_date`;
- `installed_food_packs`.

They remain restore compatibility inputs. Their presence does not make them
current write targets.

## Baseline risks recorded, not changed in C0B

1. Twenty production files call `SharedPreferences.getInstance()` directly.
   The planned injected preference boundary remains a later composition task.
2. Backup preference coverage is not identical to the current durable set.
   Notably, the collector omits `user_theme_mode`, current Health category and
   integration choices, and `pref_remind_water`; the backup contract slice must
   decide whether each omission is intentional before any codec change.
3. The active hydration UI treats `water_goal` as glasses with a default of 8,
   while one legacy database migration fallback reads it as 2000 ml. This is a
   frozen inconsistency to investigate, not normalize during cleanup.
4. `SettingsController.toggleReminder` accepts an arbitrary string key. Typed
   ownership can replace that boundary later without renaming persisted keys.
5. Onboarding drafts, health permission markers, timezone state, handoff state,
   and the auto-backup fingerprint are intentionally device-local candidates;
   they should not be added to portable backup merely for completeness.

## Verification

- `flutter test test/c0b_preference_contract_test.dart --reporter expanded` —
  4/4 passed.
- Public key spellings, defaults, Health category mappings, exact onboarding
  draft key sets, and Today handoff lifecycle are machine checked.
