# C0B Preference Ownership, Mirror, Restore, and Reset Map

- Status: Frozen baseline
- Date: 2026-09-01
- Direct production access: 20 files call `SharedPreferences.getInstance()`
- Key/default catalogue: [`C0B_PREFERENCE_CONTRACT.md`](C0B_PREFERENCE_CONTRACT.md)

## Ownership matrix

| Key family | Primary readers | Primary writers | Authority/mirror meaning |
|---|---|---|---|
| `onboarding_completed`, `onboarding_skipped` | `main.dart`, router provider seed, profile notifier, Data Management | onboarding screens/draft store; Data Management resets completed only; backup restore | app-entry gate and explicit skip state; mirrored into synchronous router provider |
| `offline_only`, `pref_crash_reporting_enabled` | privacy policy, crash service, settings controller | privacy policy and crash service through settings | privacy consent; offline-only forces telemetry false |
| `user_theme_mode` | theme notifier | theme notifier | presentation-only |
| `display_units` | unit notifier | unit notifier | presentation-only; canonical quantities remain metric |
| profile identity/demographics | user-profile notifier; dashboard reads current weight; retired AI Food reads diet | onboarding, user-profile notifier, dashboard weight update | Drift profile is preferred when present; preferences are bootstrap/compatibility mirrors |
| `user_weight` | no current production reader | profile/dashboard weight writers | compatibility mirror exported in backup; `current_weight` is the active preference reader |
| `user_target_weight` | no current production reader | onboarding | retained backup-compatible write-only preference |
| calorie/macro goals | profile notifier, dashboard, retired AI Food | onboarding and profile notifier | preference bootstrap/mirror; versioned nutrition goal history remains canonical where available |
| hydration keys | water provider, dashboard, legacy v14 migration, settings | water provider and settings | legacy local hydration state; `water_goal` has the recorded glass/ml inconsistency |
| `unlocked_achievement_ids` | dashboard achievement refresh | dashboard achievement refresh | presentation feedback memory, not canonical achievement evidence |
| streak keys | dashboard and Achievements | dashboard freeze-token flow; some historical keys are restore-only | mixed presentation/legacy state; canonical workout/food evidence is recomputed |
| weekly-action keys | dashboard; retired weekly report reads type | retired weekly report writer | dormant/compatibility state, not current Progress authority |
| notification toggles/schedules | settings controller and notification service | settings controller | user scheduling choices |
| notification timezone keys | notification service | notification reconciliation | device-local operational metadata |
| Health integration/category keys | Health service | Health service/settings surfaces | device/provider connection choices; imported evidence remains in Drift |
| `health_last_sync_time` | Health service | Health service | status metadata, not evidence timestamp authority |
| Health permission-attempt keys | Health service | Health service | device-local permission UX metadata |
| onboarding draft keys | B05 draft store | B05 draft store | resumable transient answers only |
| `today_onboarding_handoff_pending` | Today handoff provider | onboarding handoff helpers | one-shot presentation state |
| auto-backup fingerprint | auto-backup service | auto-backup service | device-local deduplication metadata |

## File ownership inventory

| Production file | Role |
|---|---|
| `main.dart` | reads onboarding gate once and injects privacy/theme state |
| `core/di/user_profile_provider.dart` | profile/goal preference bootstrap and Drift mirror writes |
| `core/di/providers.dart` | hydration state and civil-date rollover |
| `core/di/theme_provider.dart` | theme read/write |
| `core/privacy/privacy_policy.dart` | offline/telemetry consent read/write |
| `core/services/crash_reporting_service.dart` | effective telemetry read/write |
| `core/services/notification_service.dart` | reminder scheduling and timezone metadata |
| `core/services/auto_backup_service.dart` | backup fingerprint and preference snapshot input |
| `core/presentation/today_onboarding_handoff.dart` | one-shot handoff lifecycle |
| `data/repositories/health_service.dart` | Health connection/category/permission/status metadata |
| `data/database/app_database.dart` | one-time legacy hydration import only |
| `features/onboarding/onboarding_screen.dart` | completed profile and goal mirror writes |
| `features/onboarding/b05_adaptive_onboarding.dart` | bounded draft, skip, and cleanup lifecycle |
| `features/settings/settings_controller.dart` | settings reads/writes plus backup export/restore |
| `features/settings/unit_preference.dart` | unit read/write |
| `features/settings/widgets/data_management_section.dart` | restore gate refresh and setup reset |
| `features/dashboard/dashboard_controller.dart` | weight mirror, achievements, streak, weekly-action reads |
| `features/progress/achievements_screen.dart` | legacy streak fallback read |
| `features/reports/weekly_report_screen.dart` | dormant weekly-action read/write |
| `features/food_log/ai_meal_planner_screen.dart` | dormant goal/diet reads |

Backup codecs accept an injected preference instance and are not counted among
the 20 direct singleton access sites.

## Restore behavior

- Export collects only the allowlisted preference keys documented in the
  preference contract.
- Restore validates every incoming value before mutation.
- Restore writes only keys present in the payload; it does not clear unrelated
  or absent device-local preferences.
- A failed preference or database write restores the prior value—or removes a
  key created by the failed attempt—before returning failure.
- Successful restore invalidates profile state, reloads hydration state, and
  refreshes the synchronous onboarding gate from restored preferences.
- Drafts, permission-attempt metadata, notification timezone metadata, Today
  handoff, and auto-backup fingerprint are not portable restore targets.

## Delete and reset behavior

- Profile and routine draft clear operations remove their exact key sets.
- clearing the Today handoff removes its key rather than storing false;
  acknowledgement stores false until a later clear.
- completing onboarding removes `onboarding_skipped`; explicitly skipping sets
  both completed and skipped true and clears profile draft/handoff state.
- Settings “Start setup again” sets only `onboarding_completed` false and clears
  Today handoff. It deliberately does not delete logs, backups, profile mirrors,
  notification choices, or other settings, and it removes the prior navigation
  stack.
- There is no production-wide `SharedPreferences.clear()` data-erasure path.

## Recorded cleanup constraints

1. Preference injection may replace direct singleton access later, but provider
   lifetimes and async load behavior must remain stable.
2. Profile and target preference mirrors cannot be removed until Drift bootstrap,
   old installs, backup restore, and skip/setup behavior have dedicated migration
   evidence.
3. Writer-only compatibility keys (`user_weight`, `user_target_weight`) and
   dormant weekly-action keys require classification before deletion.
4. Restore semantics are “replace supported rows and apply present managed
   preferences,” not “clear every device preference.” User-facing copy must not
   be interpreted as authorization to broaden deletion.
