# Project Walkthrough & Setup Guide

This document covers the details of both **DropAlert** and **IndiFit**, which have their core codebases successfully implemented, verified, and pushed to separate public GitHub repositories.

---

## 🎮 DropAlert (Web Stock Tracker)
Repository: [ayushraibuilds/dropalert](https://github.com/ayushraibuilds/dropalert)

### Completed Features:
1. **Scrapers**: Implemented 7 retailer scrapers (Amazon, Flipkart, Vijay Sales, Croma, PlayStation Direct, Reliance Digital, Games The Shop) with user-agent rotation and Playwright Chromium stealth overlays.
2. **Unified Backend Engine**: FastAPI server running an internal event-loop scheduler to scrape items every 5 minutes on a single free Render worker.
3. **Alert Services**: Email notification handlers (Resend), Telegram Chat bot command handlers (`/start`, `/status`, `/subscribe`, `/unsubscribe`), Twilio WhatsApp message senders, and **Browser Web Push Notifications** (using `pywebpush` and Service Worker registration).
4. **Next.js Frontend Dashboard**: Custom CSS dark glassmorphic dashboard (`dropalert/frontend`) with dynamic alert setup forms, service worker hooks to receive browser pushes, and an automated **Demo Fallback Mode** when the backend is offline.
5. **Live Stock Drops Timeline**: Replaced the simple drops list with a visual vertical timeline representing active drops and price drops with markers and timestamps.
6. **SEO Blog Section**: Interactive console stock tracking articles embedded directly into the homepage dashboard to enhance organic engagement and search visibility.
7. **Pylance Import Resolution Config**: Integrated `.vscode/settings.json` with workspace `extraPaths` definitions to natively clear import warnings for local modules and site packages.

---

## 🏋️ IndiFit (Offline-First Flutter App)
Repository: [ayushraibuilds/indifit](https://github.com/ayushraibuilds/indifit)

We have completed the core features for IndiFit! The app runs cleanly on mobile devices and simulator screens.

### Completed Features:

#### Phase 1: Diet & Progress Tracker
1. **Local SQLite Storage (Drift)**: Built Drift database schema mapping logs, foods, gym exercises, workout sessions/sets, and body measurement metrics into local SQL storage.
2. **Asset Database Auto-Seeding**:
   - Created [indian_foods.json](file:///Users/dankmagician/Documents/New%20project/indifit/assets/data/indian_foods.json) containing common foods (roti, dal, paneer, brown rice, etc.) mapped to calories and macro values.
   - Created [exercises.json](file:///Users/dankmagician/Documents/New%20project/indifit/assets/data/exercises.json) mapping exercises, muscle groups, equipment, difficulty, and form cues.
   - Configured `MigrationStrategy` so these files automatically seed the SQLite database upon the app's first boot.
3. **Google Fonts & Styling**: Loaded **Outfit Google Font** and established a custom emerald dark palette.
4. **Calorie & Macro Ring Home Dashboard**:
   - **Calorie Tracker Ring**: Visual circular percent ring displaying daily calorie progress.
   - **Macro Breakdown Bars**: Linear bars displaying protein, carbs, and fat limits.
   - **Water Tracker Card**: Quick add water button increments shared preferences tracker.
   - **Weight Progress Sparkline**: Live weight sparkline chart rendering trend history via `fl_chart`.
5. **Interactive Meal Logging sections**: Expandable lists mapping Breakfast, Lunch, Dinner, and Snacks. Logged meals can be deleted dynamically, which updates macro bars reactively using SQL streams.
6. **Fuzzy Search Page**: Queries local SQLite DB first (offline search) and queries Open Food Facts API in parallel if network connectivity is active.
7. **Barcode Scanner**: Integrates a camera scanner to search packaged products by barcode, falling back to a **manual text code input** for hassle-free simulator testing.

#### Phase 2: Onboarding Setup & Workout Planner
1. **5-Step Onboarding Wizard UI**: Built a visual stepper wizard prompting the user to select Goal, Equipment, Frequency, Experience, and Injuries.
2. **AI Program Generator Client**: Interfaces with the Python FastAPI backend to compile workout schedules using Gemini/DeepSeek models.
3. **Local Offline-First Split Creator**: If the user is offline or the FastAPI backend is not yet started, the client falls back to a **rule-based local routine builder**, instantly outputting structured, customized splits.
4. **Relational Routine Caching (Drift)**: Created `workout_routines`, `routine_days`, and `routine_exercises` tables to store Generated routines locally inside a database transaction, enabling complete offline review.
5. **Weekly Calendar Header**: Developed a horizontal calendar header mapping the split to days of the week, with rest day recovery pages and start workout triggers.
6. **Exercise Library & Detail Sheets**:
   - Searchable exercise list with quick muscle group filter chips.
   - Bottom sheet details pane with muscle targets, equipment parameters, YouTube demo player thumbnail link, form cues, and common mistakes list.

#### Phase 3: Workout Player & AI Meal Estimation
1. **Full-Screen Workout Player (`workout_player_screen.dart`)**:
   - Track exercise progress via a linear progress bar and dynamic set markers.
   - Easily enter weights and reps completed with tap-to-increment modifiers.
2. **Rest Period Countdown Timer**:
   - Automatically populates a circular rest countdown after completing each set.
   - Keeps the screen on via `wakelock_plus` during the rest duration.
   - Emits vibration haptic alerts upon timer completion to grab the user's attention.
3. **Personal Record (PR) Achievements**:
   - Checks logged set achievements against maximum historical weights for each exercise.
   - Instantly overlays a gold crown notification and rings haptic pattern when a new personal best is reached.
4. **Workout Summary Dashboard (`workout_summary_screen.dart`)**:
   - Computes total workout duration, active calories burned, and total metric tons/kg of volume lifted.
   - Provides a direct summary sharing card via standard mobile share dialogs.
   - Saves the final session to Drift SQLite to compile trends.
5. **Gemini Text & Photo Meal Estimators (`ai_meal_logger_screen.dart`)**:
   - Exposes text and photo logging choice drawers in the diet tracker.
   - **Text Estimator**: Type meal details ("2 rotis and paneer") to get macronutrients from Gemini.
   - **Photo Estimator**: Take or upload a picture of a plate. The app sends multipart form-data to the backend where Gemini Flash analyses the image components to estimate calories.
   - **Offline Mock Fallbacks**: Includes heuristic mockup models inside the Python backend so estimators can be run and previewed even if Gemini API keys are omitted.

#### Phase 4: Heatmap, Trends, AI Planner & Sync Manager
1. **Gym Activity Heatmap Grid (`progress_screen.dart`)**:
   - Implemented a custom 12-week grid (columns of weeks, rows of days) displaying active workout logs.
   - Completed gym sessions automatically light up as solid green (emerald `#1D9E75`) squares.
2. **Double Line Charts**:
   - **Weight Chart**: Visualizes historical bodyweight trend logs using curved grid lines.
   - **Strength Volume**: Plots total intensity metric/volume lifted per session, indicating progression.
3. **AI Meal Planner (`ai_meal_planner_screen.dart`)**:
   - Inputs for target calorie boundaries and custom diet profiles (Vegetarian, Vegan, Non-Veg).
   - Mon-Sun layout detailing Breakfast, Lunch, Dinner, and Snacks.
   - **Grocery Shopping List**: A checklist panel mapping estimated items required for the week's diet plan (e.g. Paneer: 1.2kg, Oats: 500g, Wheat flour: 3kg).
4. **Supabase Sync Manager (`sync_manager.dart`)**:
   - Listens to device connectivity state changes using `connectivity_plus`.
   - On connection, selects unsynced food logs and workout sessions (`isSynced = false`) in Drift, writes them to cloud tables, and flags them as synced locally.
   - Bypasses cloud sync gracefully if Supabase credentials are not initialized, allowing offline-only runs during development.
5. **Local Reminder Notifications (`notification_service.dart`)**:
   - Built a comprehensive reminder schedule optimized for user engagement without spam:
     - **Workout Reminder**: Daily at 7:30 AM (warm-up/train nudge)
     - **Meal Logging**: Post-lunch (1:30 PM) & post-dinner (8:30 PM) — skips breakfast to prevent morning annoyance.
     - **Water Intake**: Twice daily (11:00 AM & 4:00 PM) — keeps hydration top-of-mind without continuous buzzes.
     - **Evening Nudge**: 9:15 PM — "Did you log today?" to help maintain streaks.
     - **Weekly AI Summary**: Sundays at 10:00 AM — weekly reports compiled and notified.
6. **Configurable Settings Panel (`settings_screen.dart`)**:
   - Clean UI accessible from the Dashboard App Bar.
   - Custom toggle switches matching target category colors (Orange, Green, Blue, Purple, Teal).
   - Dynamically reschedules active alarms in the background using `shared_preferences` states when switches are changed.

#### Phase 5: Onboarding Flow, Dynamic Goals & Seed Data (Sprint 4.7)
1. **Interactive Step-by-Step Onboarding Flow (`onboarding_screen.dart`)**:
   - Introduced a gorgeous multi-page stepper to capture user metrics: Sex, Age, Height, Weight, Activity Level, Main Goal, Target Weight, and Diet Preference.
   - Incorporates the Mifflin-St Jeor BMR equation with physical TDEE activity scale multipliers to calculate customized daily caloric budgets and precise target distributions for protein, carbs, and fat.
   - Integrated as a boot-time resolver in `main.dart` that dynamically routes first-time users to the wizard.
2. **Persistent Goal Limits**:
   - Dynamic load and save parameters connected to `SharedPreferences` in both the main dashboard and the AI meal planner screens, removing the previous hardcoded calorie defaults.
3. **Seed Database Expansion**:
   - Utilized program generation algorithms to expand the static asset databases to **413 regional Indian foods** and **140 custom gym exercises**, offering comprehensive search coverage.
4. **Explicit Demo/Simulated Badges**:
   - Styled informational notice banners in the AI meal layout and workout player checking states to inform the user of offline demo configurations.

---

## Running the Apps Locally

### 1. Launch DropAlert Frontend & Backend
- **Backend**:
  ```bash
  cd dropalert
  source .venv/bin/activate
  cd backend
  uvicorn main:app --reload
  ```
- **Frontend**:
  ```bash
  cd dropalert/frontend
  npm run dev
  ```
  Visit `http://localhost:3000`.

### 2. Launch IndiFit Mobile App
- **Run project**:
  ```bash
  cd indifit
  flutter run
  ```
  *Note: To test on a physical iPhone, plug it into your Mac, open Xcode via `open ios/Runner.xcworkspace`, set up your Personal Team profile in Signing & Capabilities, and click the Play button in Xcode.*

### 3. Launch IndiFit Python AI Backend
- **Run backend**:
  ```bash
  cd indifit/backend
  python -m venv .venv
  source .venv/bin/activate
  pip install -r requirements.txt
  uvicorn main:app --reload
  ```
   Backend will run on `http://127.0.0.1:8000`. The Flutter app is pre-configured to query this endpoint.

---

## 🚀 Sprint 4.8: Core Feature Additions (Completed)

We have successfully implemented and verified all core feature additions scheduled for Sprint 4.8:

### 1. Workout History Autofill
- **Implementation**: Created `getLatestSetsForExercise` in [workout_repository.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/data/repositories/workout_repository.dart) joining completed `WorkoutSessions` with `WorkoutSets`.
- **UI Integration**: Integrated inside [workout_player_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/workout_player/workout_player_screen.dart)'s `_prefillInputs` method. Completing a set or starting an exercise pulls the exact weight and reps from the last completed session, enabling immediate progressive overload tracking.

### 2. Epley 1RM Personal Records
- **Implementation**: Wrote `getPersonalRecord` which fetches all past sets for a specific exercise target and dynamically evaluates Epley 1-Rep Max (1RM).
- **UI Integration**: The player checks the current lift against the historical PR. If the estimated 1RM is surpassed, the screen lights up with a gold crown, registers the new PR flag in the SQLite database, and plays vibration haptic patterns.

### 3. Body Measurements Screen
- **Implementation**: Configured full logging capability for Weight, Waist, Chest, and Arms into the SQLite `BodyMeasurements` table.
- **UI Integration**: Created a floating action button on [progress_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/progress/progress_screen.dart) that opens the modal form, dynamically updates local/dashboard weight settings in `SharedPreferences`, plots actual values on the curved line chart, and lists the 3 most recent entries in a history card.

### 4. Custom Food Creator
- **Implementation**: Built [custom_food_editor_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/food_log/custom_food_editor_screen.dart) letting users save their own nutritional items with name (English/Hindi), serving sizes/units, calories, and custom protein/carb/fat profiles.
- **UI Integration**: Placed quick access shortcuts in the search page app bar and no-results search states. Custom items are queryable locally and badged with a green "Custom" tag.

### 5. Weekly Adherence Score
- **Implementation**: Added a composite score calculator in [dashboard_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/dashboard/dashboard_screen.dart) tracking consistency over the past 7 days (70% nutrition consistency within ±15% calorie goals, 30% workout consistency).
- **UI Integration**: Displays via a circular progress percentage ring at the top of the dashboard.

### 6. Export/Backup Local Data
- **Implementation**: Created a secure data exporter inside [settings_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/settings/settings_screen.dart) that aggregates all relational SQLite tables (foods, logs, sessions, sets, routines, measurements) into a versioned JSON object.
- **UI Integration**: Adds a button copying the formatted backup data string to the device Clipboard.

### 7. No Backend Mode Toggle
- **Implementation**: Integrated a check inside [sync_manager.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/data/repositories/sync_manager.dart) parsing the SharedPreferences key `offline_only`.
- **UI Integration**: Added a "No Backend Mode" toggle in the Settings screen to pause synchronization calls.

### 8. Health & AI Uncertainty Disclaimers
- **Implementation**: Implemented persistent warning banners at the top of the AI Meal Planner and AI Meal Logger screens.
- **UI Integration**: Added a comprehensive medical safety scroll disclaimer inside the Settings screen.
