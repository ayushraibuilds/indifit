# Implementation Plan - Launch Blockers & UI Improvements (Sprint 4.9 & Hardening)

This plan details fixes for all five highlighted launch blockers and seven UI/UX enhancements.

## Proposed Changes

### Core Security & Build Config

#### [MODIFY] [build.gradle.kts](file:///Users/dankmagician/Documents/New%20project/indifit/android/app/build.gradle.kts)
- Prevent silent fallback to debug signing key when building a release package.
- Throw a `GradleException` if `key.properties` does not exist during a release build.

#### [MODIFY] [sync_manager.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/data/repositories/sync_manager.dart)
- Include user identity (`user_id` fetched from `Supabase.instance.client.auth.currentUser?.id`) in the uploaded payloads for `food_logs` and `workout_sessions`.
- Bypass sync if no authenticated user is signed in to prevent collisions.

#### [MODIFY] [app_config.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/core/config/app_config.dart)
- Import `package:flutter/foundation.dart`.
- Change default backend URL configuration to adapt to release modes: use loopback IP `http://10.0.2.2:8000` for local dev emulator testing, and a production URL `https://api.indifit.app` for `kReleaseMode`.

### AI Backend Stability

#### [MODIFY] [main.py](file:///Users/dankmagician/Documents/New%20project/indifit/backend/main.py)
- Limit CORS origins in production using `ALLOWED_ORIGINS` loaded from environment variables (fallback to localhost / indifit.app).
- Add an explicit `is_fallback` boolean flag to routine and meal estimation JSON outputs so the UI can detect and label simulated mock data.

### Reminders Setup

#### [MODIFY] [notification_service.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/core/services/notification_service.dart)
- Default notification preferences to `false` instead of `true`. Users must explicitly opt-in to notifications, aligning with best practices.

### Dashboard & Today Screen

#### [MODIFY] [main_navigation_scaffold.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/dashboard/main_navigation_scaffold.dart)
- Rename the first tab from "Diet Tracker" to "Today".
- Change the tab icon to `Icons.today_rounded`.

#### [MODIFY] [dashboard_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/dashboard/dashboard_screen.dart)
- **Responsive Header**: Shorten the streak text to `X d` (e.g. `3d`). Group AI planner, settings, and other actions into a compact `PopupMenuButton` to prevent overflow on small screens.
- **Actual Calorie Goal**: Replace static `2000 kcal` with target from SharedPreferences.
- **Today's Workout Status**: Add a widget displaying today's scheduled workout status (split name or rest status) and a quick action button to start it.
- **Quick Action Bar**: Add a prominent row containing "Log Meal" and "Start Workout" buttons.

### Progress & Charts

#### [MODIFY] [progress_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/progress/progress_screen.dart)
- Remove simulated weight trend points when no records are logged.
- Display a clean, motivating placeholder illustration/message when measurements are empty.

### Workout Split Selector & Player

#### [MODIFY] [routine_display_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/workout_player/routine_display_screen.dart)
- Rewrite `_buildWeeklyCalendarHeader` using horizontally scrollable list views, featuring full weekday labels (`Mon`, `Tue`, etc.) instead of single letters.

#### [MODIFY] [workout_player_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/workout_player/workout_player_screen.dart)
- Enhance screen to display exercise-specific form cues and targeted rest periods from the database.
- Show target RPE (defaults to RPE 8) and display previous set history values inline for quick reference.

### Debounced Food Search

#### [MODIFY] [food_search_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/food_log/food_search_screen.dart)
- Introduce a search debounce timer (375ms) to prevent overlapping API calls on every keystroke.
- Clearly group results by local database, online searches, and alert if network is offline.

---

## Verification Plan

### Automated Tests
- Run `flutter analyze` and `flutter test` to ensure compilation and existing logic remain intact.

### Manual Verification
- Test APK compilation without `key.properties` and verify that the build fails as expected.
- Toggle notifications in settings and verify they schedule/cancel properly.
- Test debounced search in simulator, verify local and global results group nicely.
