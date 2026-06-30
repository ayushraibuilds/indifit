# DropAlert Tasks

## Phase 1: Environment & Repository Setup ✅
- [x] Check `gh` CLI installation and login status
- [x] Initialize `dropalert` subfolder as a git repository (or separate public repo)
- [x] Create GitHub repository for `dropalert` and push initial structure
- [x] Initialize virtual environment and install base Python requirements (`requirements.txt`)
- [x] Scaffolding: Create base directories and empty files for Phase 1

## Phase 2: Database Schema & Migration ⚠️
- [x] Set up Supabase migration script with initial schemas (`products`, `stock_events`, `subscribers`, `price_history`)
- [ ] Apply migrations to the fresh Supabase project *(user deferred Supabase setup)*

## Phase 3: Core Scrapers (Easiest First) ✅
- [x] Write abstract `BaseScraper` class and config loaders
- [x] Implement Croma Scraper (Direct JSON API)
- [x] Implement Reliance Digital Scraper (BeautifulSoup)
- [x] Implement PlayStation Direct Scraper (Direct JSON API)
- [x] Implement Games The Shop Scraper (BeautifulSoup)
- [x] Write execution orchestrator and caching logic with Upstash Redis

## Phase 4: Telegram Bot & Change Detection ⚠️
- [x] Set up Telegram Bot handler with commands: `/start`, `/status`, `/subscribe`, `/unsubscribe`
- [x] Connect change detection to notification pipeline
- [ ] Deploy background scheduler (lifespan event loop runner) to Render (free tier)

## Phase 5: Playwright Scrapers (Harder Sites) ✅
- [x] Install Playwright and setup browser binaries
- [x] Implement Amazon India Scraper with random delays + stealth plugin
- [x] Implement Flipkart Scraper (waiting for dynamic React DOM)
- [x] Implement Vijay Sales Scraper (JS-rendered page)

## Phase 6: Notification Services ✅
- [x] Integrate Resend API for email alerts
- [x] Integrate Twilio API for WhatsApp alerts (premium)
- [x] Add browser push notifications support

## Phase 7: Next.js Frontend ⚠️
- [x] Scaffold Next.js app in `dropalert/frontend/`
- [x] Implement email subscription form with preference filters
- [x] Integrate Razorpay payments for premium tier
- [x] Setup PWA and basic SEO optimization
- [x] Dark glassmorphic dashboard with demo fallback mode
- [ ] Implement live dashboard with Supabase Realtime subscription
- [ ] Add price history chart (Recharts)
- [x] Add stock history timeline (last 30 days) — ✅ DONE

## Phase 8: SEO & Content ⚠️
- [x] Basic meta tags in layout.tsx
- [x] Create blog section with SEO articles — ✅ DONE
- [ ] Add structured data and OG tags

## Phase 9: Deploy & Launch 🔲
- [ ] Deploy Next.js frontend to Vercel (free)
- [ ] Deploy backend to Render (free) or Railway ($5/mo)
- [ ] Configure environment variables on hosting platforms
- [x] Write walkthrough/handover guide

## Phase 10: Second-Hand Scrapers (V2) 🔲
- [ ] Implement Dacby scraper
- [ ] Implement GameNation scraper
- [ ] Implement GameLoot scraper
- [ ] Implement Happy Gaming World scraper
- [ ] Add "New vs Pre-Owned" toggle on dashboard


# IndiFit Tasks

## Phase 1: Project Scaffolding & Data Layer ✅
- [x] Initialize Flutter project: `com.indifit.app` (Android) + `com.indifit.IndiFit` (iOS)
- [x] Configure Drift, Supabase client, Riverpod state management, and GoRouter navigation
- [x] Create dark theme with `#1D9E75` green accent and Outfit/Inter fonts
- [x] Compile 500+ Indian food database (ICMR guidelines) as offline JSON asset
- [x] Implement search page: fuzzy logic querying Drift DB (offline fallback) + Open Food Facts API
- [x] Implement food logger UI: log meal quantities under Breakfast, Lunch, Dinner, Snacks
- [x] Integrate mobile_scanner barcode reader (calls Open Food Facts API for packaged foods)
- [x] Create Dashboard home: calorie ring progress, macro breakdown bars, water intake logger, weight sparkline

## Phase 2: AI Routine Generator & Exercise Library ✅
- [x] Build 5-step onboarding wizard UI (Goal, Equipment, Schedule, Experience, Injury considerations)
- [x] Implement FastAPI AI router with provider switching (Gemini → DeepSeek → GLM-4-Flash fallback)
- [x] Create database schema for routines and cache responses
- [x] Set up 200+ exercises database asset in Drift (Offline access)
- [x] Design exercise details sheet (YouTube player embed, form cues, alternatives)
- [x] Create routine display screen: weekly calendars, day tasks, start workout trigger

## Phase 3: Workout Player (Offline-First) ✅
- [x] Develop full-screen Workout Player: large exercise title, set count progress, weight input pad
- [x] Implement Rest Timer page: circular countdown, vibration haptics at 0, wakelock screen lock
- [x] Add Personal Record (PR) tracker: check local Drift logs for improvements, display gold crown notification
- [x] Create Workout Summary screen: volume lifted, total duration, calorie burn estimation, share card
- [x] Integrate Gemini text meal estimator: "Describe your meal" → parse JSON macros → log to Drift
- [x] Implement Gemini Vision photo meal estimator: take picture → estimate calories & macros

## Phase 4: Progress, AI Planner & Sync ✅
- [x] Design Progress Screen: weight trend lines, strength trackers, GitHub-style calendar heatmap
- [x] Setup AI Weekly Report: trigger backend prompt analyzing logged stats → send push summary
- [x] Implement AI Meal Planner: calorie goal → 7-day Indian meal plan with auto-generated grocery lists
- [x] Build SyncManager for offline-to-cloud data sync via connectivity_plus

## Phase 5: AI Chat, Payments & Notifications ⚠️
- [ ] Create AI Fitness Chat: context-aware bubble UI conversations based on user's local logs
- [ ] Integrate Razorpay Subscriptions (₹299/mo) with a 7-day free trial screen and referral logic
- [ ] Build paywall screen: free vs premium comparison table
- [x] Implement local notification reminder services for meals, water, and workouts — ✅ DONE
- [x] Make notifications configurable in settings screen — ✅ DONE

## Phase 6: Code Hardening & Compilation Fixes ⚠️
- [ ] Fix Flutter compile errors (`uiLocalNotificationDateInterpretation`, missing `AppColors.cardBorder`)
- [ ] Configure Android release signing
- [ ] Add `INTERNET` and camera permissions to `AndroidManifest.xml`
- [ ] Add camera/photo usage description strings to iOS `Info.plist`
- [ ] Replace `localhost` backend defaults with per-environment configuration

## Phase 7: Data Expansion, Onboarding & Features 🔲
- [ ] Build a real first-run onboarding flow
- [ ] Persist macro/water/weight goals
- [ ] Expand local seed data (300-500 foods, 100-200 exercises)
- [ ] Remove/label mock/demo claims from UI
- [ ] Workout history per exercise with previous weight/reps autofill
- [ ] Real PR calculation from past sets
- [ ] Body measurement logging screen
- [ ] Editable custom foods and recipes
- [ ] Weekly adherence score
- [ ] Export/backup data
- [ ] "No backend mode" toggle
- [ ] Health disclaimer and AI uncertainty warnings

## Phase 8: Build & Test 🔲
- [ ] Build APK (Android) for physical phone testing
- [ ] Build and install via Xcode Personal Team (iOS) for physical phone testing
- [ ] Test offline-to-online data sync scenarios (airplane mode simulation)
- [ ] Performance check: app launch < 2 seconds
- [ ] Personal daily use for 5-7 days before any public release
