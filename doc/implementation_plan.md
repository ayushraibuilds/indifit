# DropAlert + IndiFit — Complete Implementation Plan (v3 — Status Verified)

Two products built sequentially. **DropAlert** ships first (1 week, generates revenue) while **IndiFit** is developed (5 weeks, Flutter for Android + iOS).

> [!IMPORTANT]
> **Last verified**: This plan was cross-referenced against the actual codebase on 2026-06-30. Status markers (✅/🔲) reflect what exists in code, not just task.md checkboxes.

---

## Analysed Source

[ps5_finder_and_fitness_app_plan.html](file:///Users/dankmagician/Documents/New%20project/ps5_finder_and_fitness_app_plan.html)

---

## Decisions Locked In

| Decision | Value |
|----------|-------|
| Stock Tracker Name | **DropAlert** |
| Fitness App Name | **IndiFit** |
| PS5 Relevance | ✅ Stock shortage is back after price hike — confirmed relevant |
| Scope | Broader product tracker (PS5 + PS5 Pro + Xbox + GPUs + iPhones) |
| Mobile Platforms | Android + iOS (Flutter) — tested on personal phones |
| Supabase | Creating fresh project |
| Domain | Not purchased yet |
| Offline Support | Yes — IndiFit must work fully offline for gym usage |

---

## User Review Required

> [!IMPORTANT]
> **Apple Developer Account** — User confirmed they do NOT have one. iOS testing uses Xcode Personal Team provisioning (free, limited to 7-day cert). TestFlight requires the $99/yr program. For now, simulator + Xcode direct-install is the testing path.

> [!IMPORTANT]
> **Supabase Project Region** — For India-focused apps, choose **Mumbai (ap-south-1)** region when creating the Supabase project. This gives the lowest latency for Indian users. *User said to do Supabase later — all code has offline/demo fallbacks.*

---

# 📊 BACKEND HOSTING — Full Comparison

Every option analysed for cost, free tier, and suitability for both products.

## Hosting Platform Comparison

| Platform | Free Tier? | Monthly Cost (Starter) | Cold Starts? | Best For | India Latency | Celery/Background Jobs? | Verdict |
|----------|-----------|----------------------|-------------|----------|---------------|------------------------|---------| 
| **Render** | ✅ Yes (limited) | Free → $7/mo | Yes (30-60s after 15min idle) | Prototyping, early stage | Singapore region (ok) | ✅ Background workers free tier | 🏆 **Best for dev/pre-launch** |
| **Railway** | ❌ $5 trial credit only | ~$5-10/mo (usage-based) | No cold starts | Production, DX | No Mumbai, but decent | ✅ Native support | 🏆 **Best for production** |
| **Vercel** | ✅ Yes (Hobby) | Free → $20/mo | Serverless (short) | Next.js frontend ONLY | Edge network (global) | ❌ No long-running tasks | **Frontend only** |
| **Fly.io** | ❌ No free tier (new users) | ~$5-10/mo | No | Global, low-latency | ✅ Mumbai region available | ✅ Via Machines | Good but no free tier |
| **Deta Space** | ✅ Yes (generous) | Free | No | Simple Python backends | Limited regions | ❌ No native support | Limited for our needs |
| **Supabase Edge Functions** | ✅ 500K invocations/mo free | Free → $25/mo | Serverless (short) | Simple API endpoints | Mumbai region ✅ | ❌ Max 150s per request | **Good for simple APIs** |
| **Google Cloud Run** | ✅ 2M requests/mo free | Free → pay-per-use | Yes (configurable) | Production scale | ✅ Mumbai region | ✅ Via Cloud Tasks | **Best for scale** but complex |
| **Koyeb** | ✅ 1 nano service free | Free → $5.40/mo | Minimal | Simple deployments | Frankfurt (decent) | ✅ Background workers | Decent alternative |

### 🏆 Recommended Backend Strategy

```
DEVELOPMENT PHASE (₹0/mo):
├── Frontend (Next.js)     → Vercel Hobby (free, non-commercial)
├── Backend (FastAPI)      → Render free tier (cold starts ok for dev)
├── Database               → Supabase free tier (Mumbai region)
├── Redis/Cache            → Upstash free tier (500K commands/mo)
└── Background Jobs        → Render background worker (free tier)

LAUNCH / PRODUCTION (₹800-1,500/mo = $10-18/mo):
├── Frontend (Next.js)     → Vercel Hobby OR Render static site
├── Backend (FastAPI)      → Railway ($5-10/mo, no cold starts)
├── Database               → Supabase free tier (sufficient up to ~10K users)
├── Redis/Cache            → Upstash free → Railway Redis ($5/mo if needed)
└── Background Jobs        → Railway worker process (included in $5-10)

SCALE PHASE (when revenue > costs):
├── Everything             → Railway or Google Cloud Run
├── Database               → Supabase Pro ($25/mo) when >500MB
└── Redis                  → Upstash Pro or Railway Redis
```

> [!TIP]
> **Zero-cost until launch**: Using Render (free) + Vercel (free) + Supabase (free) + Upstash (free), you pay ₹0 during the entire development phase. The cold starts on Render's free tier don't matter during development. Switch to Railway ($5/mo) only when you go live and need reliability.

---

# 🤖 AI / LLM API — Full Comparison

For IndiFit, AI is needed for: routine generation, food estimation, meal planning, AI chat, and weekly reports. For DropAlert, AI is optional (stock prediction, pattern analysis).

## LLM API Pricing Comparison

| Provider | Model | Input (per 1M tokens) | Output (per 1M tokens) | Free Tier? | Vision (Photo → Food)? | JSON Mode? | Speed | Best For |
|----------|-------|----------------------|----------------------|-----------|----------------------|-----------|-------|----------|
| **Google Gemini** | Gemini 3.5 Flash | $1.50 (paid) | $9.00 (paid) | ✅ **Yes — completely free** (rate-limited) | ✅ Yes | ✅ Yes | Very Fast | 🏆 **Dev + early production** |
| **DeepSeek** | V4-Flash | **$0.14** | **$0.28** | ❌ Pay-as-you-go ($5 minimum top-up) | ❌ Text only | ✅ Yes | Fast | 🏆 **Cheapest production option** |
| **DeepSeek** | V4-Pro | $0.44 | $0.87 | ❌ | ❌ Text only | ✅ Yes | Medium | Complex reasoning tasks |
| **Qwen** (Alibaba) | Qwen3.6-Plus | $0.33 | $1.95 | ❌ (occasional promo credits) | ✅ Yes (multimodal) | ✅ Yes | Fast | Good all-rounder |
| **GLM** (Zhipu) | GLM-4-Flash | **Free** | **Free** | ✅ **Yes — permanently free** | ❌ Limited | ✅ Yes | Fast | 🏆 **Free fallback** |
| **GLM** (Zhipu) | GLM-5.2 | $1.40 | $4.40 | ❌ | ✅ Yes | ✅ Yes | Medium | When quality matters |
| **Kimi** (Moonshot) | K2.6 | $0.55-0.95 | $2.65-4.00 | ❌ (trial credits only) | ✅ Yes | ✅ Yes | Medium | Long context tasks |
| **NVIDIA NIM** | Various (Llama, Mistral) | Free (prototyping) | Free (prototyping) | ✅ **Yes — 40 RPM free** | Depends on model | ✅ Yes | Fast | 🏆 **Free prototyping** |
| **OpenRouter** | 20+ free models | **Free** | **Free** | ✅ **Yes — 200 req/day** | Depends on model | ✅ Yes | Varies | 🏆 **Free multi-model access** |
| **Claude** (Anthropic) | Haiku 3.5 | $0.25 | $1.25 | ❌ ($5 minimum) | ✅ Yes | ✅ Yes | Fast | Best quality for prompts |
| **Claude** (Anthropic) | Sonnet 4 | $3.00 | $15.00 | ❌ | ✅ Yes | ✅ Yes | Medium | Premium quality |

### 🏆 Recommended AI Strategy

```
DEVELOPMENT (₹0/mo):
├── Primary     → Gemini 3.5 Flash FREE TIER (rate-limited but sufficient for dev)
├── Fallback    → GLM-4-Flash (permanently free)
├── Prototyping → NVIDIA NIM (40 RPM free, OpenAI-compatible)
└── Multi-model → OpenRouter free models (200 req/day)

PRE-LAUNCH TESTING (₹400-800/mo = $5-10):
├── Primary     → DeepSeek V4-Flash ($0.14/1M input — absurdly cheap)
├── Vision      → Gemini Flash paid tier (for photo-based food logging)
└── Fallback    → GLM-4-Flash (still free)

PRODUCTION (₹800-2,500/mo = $10-30):
├── Routine Gen → DeepSeek V4-Flash (structured JSON, cheap)
├── Food Estimate → Gemini Flash (vision for photo-based, text for describe)
├── AI Chat     → DeepSeek V4-Flash or Qwen-Plus (cheap, good quality)
├── Meal Planner → DeepSeek V4-Flash (structured JSON output)
└── Weekly Report → DeepSeek V4-Flash (batch job, cheap)
```

> [!TIP]
> **Cost example**: 1,000 active users, each making ~10 AI requests/day. Average request = ~500 input + ~1,000 output tokens.
> - DeepSeek V4-Flash: 1,000 × 10 × 30 = 300K requests/mo = ~150M input + 300M output tokens = **$0.14 × 150 + $0.28 × 300 = ~$105/mo** (₹8,800/mo)
> - At ₹299/mo subscription with 15% conversion = 150 paying users = ₹44,850 revenue. **Profitable from 150 premium users.**
> - During early growth (100 users): costs are ~$10/mo.

### Why Not Just Claude?

Claude (Haiku/Sonnet) produces the *best* quality output for fitness prompts — but it costs 2-10× more than DeepSeek. The strategy:
1. **Prototype with Gemini free tier** (zero cost)
2. **Launch with DeepSeek V4-Flash** (cheapest production option)
3. **A/B test Claude vs DeepSeek** quality for routine generation
4. **Use Claude only where quality difference is noticeable** (e.g., weekly AI reports, complex chat)

### Backend AI Architecture (Provider-Agnostic)

```python
# ai_service.py — Switch providers with one config change
class AIService:
    def __init__(self, provider: str = "deepseek"):
        self.providers = {
            "gemini": GeminiProvider(api_key=GEMINI_KEY),
            "deepseek": DeepSeekProvider(api_key=DEEPSEEK_KEY),
            "glm": GLMProvider(api_key=GLM_KEY),          # Free fallback
            "openrouter": OpenRouterProvider(api_key=OR_KEY),
            "claude": ClaudeProvider(api_key=CLAUDE_KEY),
        }
        self.active = self.providers[provider]
    
    async def generate_routine(self, user_profile: dict) -> dict:
        # All providers use OpenAI-compatible API format
        return await self.active.chat_completion(
            system=ROUTINE_PROMPT,
            user=json.dumps(user_profile),
            response_format={"type": "json_object"}
        )
    
    async def estimate_food(self, description: str, photo_url: str = None):
        if photo_url:
            # Only Gemini/Claude/Qwen support vision
            return await self.providers["gemini"].vision_completion(...)
        return await self.active.chat_completion(...)
```

> [!IMPORTANT]
> **All AI calls go through YOUR FastAPI backend** — never embed API keys in the Flutter app. The backend acts as a proxy, handles rate limiting, caching, and provider switching.

---

# 🎮 PRODUCT 1: DropAlert — India's Product Stock Tracker

## All Retailers (Launch + Future)

### Phase 1 — Launch Retailers (7 retailers, new stock)

| # | Retailer | URL | Scraping Method | Difficulty | Check Interval | Status |
|---|----------|-----|----------------|-----------|----------------|--------|
| 1 | Amazon India | amazon.in | Playwright + Stealth | 🔴 Hard (anti-bot) | Every 10 min | ✅ DONE |
| 2 | Flipkart | flipkart.com | Playwright (React SPA) | 🟡 Medium | Every 5 min | ✅ DONE |
| 3 | Croma | croma.com | JSON API (direct) | 🟢 Easy | Every 5 min | ✅ DONE |
| 4 | Reliance Digital | reliancedigital.in | requests + BS4 | 🟢 Easy | Every 5 min | ✅ DONE |
| 5 | PlayStation Direct | direct.playstation.com | JSON API (official) | 🟡 Medium | Every 5 min | ✅ DONE |
| 6 | Games The Shop | gamesthe.shop | requests + BS4 | 🟢 Easy | Every 5 min | ✅ DONE |
| 7 | **Vijay Sales** | vijaysales.com | **Playwright** (JS-rendered, no public API) | 🟡 Medium | Every 5 min | ✅ DONE |

#### Vijay Sales — Scraping Notes
- No public API available. Must scrape the product page directly
- Website is JavaScript-rendered → **Playwright required** (not requests+BS4)
- Check for "Add to Cart" button vs "Out of Stock" / "Notify Me" text
- Moderate anti-bot measures — use stealth plugin + random delays
- Vijay Sales is a major retailer in West India (especially Maharashtra) — worth including

### Phase 2 — Second-Hand / Recommerce Platforms (V2, post-launch) 🔲 NOT STARTED

| # | Platform | URL | Type | Scraping Notes |
|---|----------|-----|------|---------------|
| 8 | **Dacby** | dacby.com | Recommerce (buy/sell used) | Buy-side product listings. Check for PS5/Xbox availability + price. Appeared on Shark Tank India S4. |
| 9 | **GameNation** | gamenation.in | Recommerce (buy/sell used) | India's largest pre-owned gaming platform. Check stock + pricing for used consoles. |
| 10 | **GameLoot** | gameloot.in | Recommerce (buy/sell used) | Pre-owned games + consoles. Simpler website, likely easy scraping. |
| 11 | **Happy Gaming World** | happygamingworld.com | New + refurbished | Niche retailer, sometimes has stock when big retailers don't. |

#### Second-Hand Scraper Architecture
```python
# Different data model for second-hand products
class SecondHandListing:
    retailer: str           # "dacby", "gamenation", etc.
    product_name: str       # "PS5 Disc Edition - Used"
    condition: str          # "like_new", "good", "fair"
    price: int              # In rupees
    original_price: int     # MRP for comparison
    warranty: str           # "3 months", "6 months", "none"
    url: str
    is_available: bool
    scraped_at: datetime
```

```sql
-- Additional table for second-hand listings
CREATE TABLE secondhand_listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform TEXT NOT NULL,           -- "dacby", "gamenation", etc.
  product_id UUID REFERENCES products(id),
  condition TEXT,                   -- "like_new", "good", "fair"
  price INTEGER NOT NULL,
  original_price INTEGER,
  warranty_months INTEGER DEFAULT 0,
  url TEXT NOT NULL,
  is_available BOOLEAN DEFAULT true,
  scraped_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_secondhand_product ON secondhand_listings(product_id, is_available);
```

> [!NOTE]
> **Second-hand scrapers are a V2 feature** — build the core new-stock tracker first, then add used/refurbished listings once the architecture is proven. The UI will show a "New" vs "Pre-Owned" toggle on the dashboard.

---

## DropAlert Phase 1 — Foundation & Core Scraper (Day 1-2) ✅ COMPLETE

### 1.1 Project Setup ✅ DONE

Repo: [ayushraibuilds/dropalert](https://github.com/ayushraibuilds/dropalert)

**Verified files exist:**
- [base_scraper.py](file:///Users/dankmagician/Documents/New%20project/dropalert/backend/scrapers/base_scraper.py) — Abstract base class
- [croma_scraper.py](file:///Users/dankmagician/Documents/New%20project/dropalert/backend/scrapers/croma_scraper.py) — JSON API
- [reliance_scraper.py](file:///Users/dankmagician/Documents/New%20project/dropalert/backend/scrapers/reliance_scraper.py) — requests + BS4
- [playstation_direct.py](file:///Users/dankmagician/Documents/New%20project/dropalert/backend/scrapers/playstation_direct.py) — JSON API
- [games_the_shop.py](file:///Users/dankmagician/Documents/New%20project/dropalert/backend/scrapers/games_the_shop.py) — requests + BS4
- [config.py](file:///Users/dankmagician/Documents/New%20project/dropalert/backend/config.py) — Config loader
- [main.py](file:///Users/dankmagician/Documents/New%20project/dropalert/backend/main.py) — FastAPI with scheduler

### 1.2 Database Schema ✅ WRITTEN / 🔲 NOT APPLIED TO SUPABASE

- [001_initial_schema.sql](file:///Users/dankmagician/Documents/New%20project/dropalert/supabase/migrations/001_initial_schema.sql) — Migration script exists
- Supabase project not yet created — user said to do it later

### 1.3 Core Scrapers ✅ DONE

- [x] Abstract `BaseScraper` class with `check_stock() → StockResult` method
- [x] **Croma** — JSON API call, no scraping
- [x] **Reliance Digital** — `requests` + BS4
- [x] **PlayStation Direct** — JSON API endpoint
- [x] **Games The Shop** — `requests` + BS4
- [x] Redis setup (Upstash free tier): cache logic in orchestrator
- [x] Change detection logic: compare new status vs cached → flag if changed

### 1.4 Celery + Telegram Bot ✅ CODE DONE / 🔲 NOT DEPLOYED

- [x] Event-loop scheduler in `main.py` (lifespan runner instead of Celery — simpler for free tier)
- [x] On stock change → `handle_stock_change()` → notification pipeline
- [x] Telegram bot commands: `/start`, `/status`, `/subscribe`, `/unsubscribe` — [telegram_bot.py](file:///Users/dankmagician/Documents/New%20project/dropalert/backend/bot/telegram_bot.py)
- [x] End-to-end pipeline connected
- [ ] Deploy to Render free tier for live testing

---

## DropAlert Phase 2 — Hard Scrapers + Full Notifications (Day 3-4) ✅ COMPLETE

### 2.1 Playwright Scrapers ✅ DONE

- [x] **Amazon India** — [amazon_scraper.py](file:///Users/dankmagician/Documents/New%20project/dropalert/backend/scrapers/amazon_scraper.py) — Playwright + stealth, random delays, user agent rotation
- [x] **Flipkart** — [flipkart_scraper.py](file:///Users/dankmagician/Documents/New%20project/dropalert/backend/scrapers/flipkart_scraper.py) — Playwright, React SPA handling
- [x] **Vijay Sales** — [vijaysales_scraper.py](file:///Users/dankmagician/Documents/New%20project/dropalert/backend/scrapers/vijaysales_scraper.py) — Playwright JS-rendered page
- [x] Error handling with retry logic built into base scraper

### 2.2 Notification Service ✅ DONE

- [x] **Email** — [email_service.py](file:///Users/dankmagician/Documents/New%20project/dropalert/backend/services/email_service.py) — Resend API
- [x] **Telegram** — [telegram_service.py](file:///Users/dankmagician/Documents/New%20project/dropalert/backend/services/telegram_service.py) — python-telegram-bot
- [x] **WhatsApp** — [whatsapp_service.py](file:///Users/dankmagician/Documents/New%20project/dropalert/backend/services/whatsapp_service.py) — Twilio
- [x] **Notification orchestrator** — [notification_service.py](file:///Users/dankmagician/Documents/New%20project/dropalert/backend/services/notification_service.py) — routes to channels
- [x] **Browser Push** — Web Push API via `pywebpush` — ✅ IMPLEMENTED

---

## DropAlert Phase 3 — Frontend + Launch (Day 5-7) ✅ MOSTLY COMPLETE

### 3.1 Next.js Dashboard ✅ COMPLETE

- [x] Dark glassmorphic dashboard — [page.tsx](file:///Users/dankmagician/Documents/New%20project/dropalert/frontend/src/app/page.tsx)
- [x] Demo fallback mode when backend is offline
- [x] Email subscription form with retailer preferences
- [x] Razorpay integration (premium tier setup)
- [x] Dark mode default with DropAlert branding
- [x] PWA support basics
- [ ] Supabase Realtime for live updates — 🔲 NOT IMPLEMENTED (no Supabase project yet)
- [ ] Price history chart (Recharts) — 🔲 NOT IMPLEMENTED
- [x] Stock history timeline (last 30 days) — ✅ IMPLEMENTED (live vertical timeline component)

### 3.2 SEO + Launch ⚠️ PARTIALLY COMPLETE

- [x] Page layout with basic SEO meta tags — [layout.tsx](file:///Users/dankmagician/Documents/New%20project/dropalert/frontend/src/app/layout.tsx)
- [x] Blog section: "Best Time to Buy PS5 in India", etc. — ✅ IMPLEMENTED (Insight section)
- [ ] Deploy: Frontend → Vercel, Backend → Render — 🔲 NOT DEPLOYED
- [ ] Launch posts on Reddit/Discord/Twitter — 🔲 NOT DONE

### 3.3 Domain Strategy 🔲 NOT STARTED

When ready to purchase:
- **dropalert.in** (ideal, ₹400-800/yr)
- **dropalert.co** (fallback)
- **dropalert.app** (modern feel)
- Use Cloudflare for DNS + free SSL + DDoS protection

---

# 💪 PRODUCT 2: IndiFit — AI-Powered Indian Fitness App

## Platform: Flutter (Android + iOS)

Both platforms built from a single codebase. Testing plan:
- **Android** — Build APK, sideload on your Android phone. Free, no account needed
- **iOS** — No Apple Developer Account. Use **Xcode Personal Team** provisioning (free, 7-day cert) or simulator.
- **Pre-launch**: Use both apps daily for 1-2 weeks before any public release

## Offline-First Architecture

IndiFit **must work 100% offline** in the gym. Here's how:

```
┌─────────────────────────────────────────────┐
│                 OFFLINE LAYER                │
│  ┌─────────────┐     ┌───────────────────┐  │
│  │   Drift DB   │     │  SharedPreferences │  │
│  │  (SQLite)    │     │  (Settings/Prefs)  │  │
│  │              │     │                   │  │
│  │ • Food items │     │ • Theme prefs     │  │
│  │ • Food logs  │     │ • Unit system     │  │
│  │ • Exercises  │     │ • Notification    │  │
│  │ • Workouts   │     │   preferences     │  │
│  │ • Sessions   │     └───────────────────┘  │
│  │ • Body stats │                            │
│  │ • PR history │                            │
│  └──────┬──────┘                            │
│         │                                    │
│    ┌────▼────┐                              │
│    │  Sync   │ ← Runs when connectivity     │
│    │ Engine  │   is detected                │
│    └────┬────┘                              │
│         │                                    │
└─────────┼────────────────────────────────────┘
          │
    ┌─────▼──────┐
    │  Supabase  │  ← Cloud backup + cross-device sync
    │  (Online)  │
    └────────────┘
```

### What Works Offline (No Internet Needed) — All verified in code ✅
- ✅ Food search (Indian food database is local in Drift)
- ✅ Food logging (saved locally, synced later)
- ✅ Workout player (entire routine cached locally)
- ✅ Rest timer + haptic feedback
- ✅ PR detection (local PR history in Drift)
- ✅ Set/rep/weight logging
- ✅ Workout summary + history viewing
- ✅ Exercise library browsing
- ✅ Water intake tracking

### What Requires Internet
- 🌐 AI routine generation (API call to backend) — ✅ Built with local fallback
- 🌐 "Describe your meal" AI estimation — ✅ Built
- 🌐 Photo-based food logging (Vision AI) — ✅ Built
- 🌐 AI chat — 🔲 NOT BUILT YET
- 🌐 AI weekly report — ✅ Backend endpoint exists
- 🌐 Barcode scanning (Open Food Facts API lookup) — ✅ Built
- 🌐 Cloud sync / cross-device data — ✅ SyncManager built
- 🌐 Payments (Razorpay) — 🔲 NOT BUILT YET

### Sync Strategy ✅ IMPLEMENTED
```dart
// sync_manager.dart — Implemented using connectivity_plus
// Listens to connectivity changes, pushes unsynced food_logs 
// and workout_sessions to Supabase, marks as synced locally.
// Gracefully bypasses if Supabase credentials not initialized.
```

---

## IndiFit Phase 1 — Project Scaffolding & Data Layer (Week 1) ✅ COMPLETE

### Sprint 1.1: Flutter Project Setup ✅ DONE

Repo: [ayushraibuilds/indifit](https://github.com/ayushraibuilds/indifit)

**Verified files exist:**
- [main.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/main.dart) — App entry with Supabase init (try/catch for offline)
- [app_database.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/data/database/app_database.dart) — Drift schema
- [main_navigation_scaffold.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/dashboard/main_navigation_scaffold.dart) — Bottom nav

#### Deliverables
- [x] Flutter project: `com.indifit.app` (Android) + `com.indifit.IndiFit` (iOS)
- [x] Riverpod, Drift, Supabase client, GoRouter configured
- [x] Dark theme with #1D9E75 green accent, Outfit/Inter fonts
- [x] Connectivity service for offline detection
- [x] FastAPI backend scaffolded — [backend/main.py](file:///Users/dankmagician/Documents/New%20project/indifit/backend/main.py)
- [ ] Fresh Supabase project (Mumbai region) — 🔲 USER DEFERRED

### Sprint 1.2: Indian Food Database ✅ DONE

- [x] 500+ Indian dishes compiled — [indian_foods.json](file:///Users/dankmagician/Documents/New%20project/indifit/assets/data/indian_foods.json)
- [x] Embedded as JSON asset (works offline)
- [x] Fields: name, calories, protein, carbs, fat, fiber, serving_size, category
- [x] Seed into Drift on first launch via MigrationStrategy

### Sprint 1.3: Food Logging ✅ DONE

- [x] Search bar → Drift local DB first, then Open Food Facts API — [food_search_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/food_log/food_search_screen.dart)
- [x] Meal sections: Breakfast, Lunch, Dinner, Snacks
- [x] Barcode scanner — [barcode_scanner_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/food_log/barcode_scanner_screen.dart)
- [x] All food logs stored in Drift, synced to Supabase when online

### Sprint 1.4: Dashboard ✅ DONE

- [x] Calorie ring, macro bars — [dashboard_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/dashboard/dashboard_screen.dart)
- [x] Water tracker, weight sparkline
- [x] All data from Drift (works offline)
- [ ] Supabase auth (Google + Apple Sign-In) — 🔲 DEFERRED (no Supabase project yet)

---

## IndiFit Phase 2 — AI Routine Generator & Exercise Library (Week 2) ✅ COMPLETE

### Sprint 2.1: Onboarding Wizard ✅ DONE

- [x] 5 single-question screens — [onboarding_wizard_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/onboarding/onboarding_wizard_screen.dart)
- [x] Goal, Equipment, Schedule, Experience, Considerations

### Sprint 2.2: AI Backend — Provider-Agnostic ✅ DONE

- [x] `POST /api/routine/generate` — [backend/main.py](file:///Users/dankmagician/Documents/New%20project/indifit/backend/main.py)
- [x] Provider switching: Gemini (primary) → local heuristic fallback
- [x] Local offline-first split creator (rule-based fallback)
- [x] [ai_routine_service.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/data/repositories/ai_routine_service.dart) — Client-side

### Sprint 2.3: Exercise Library ✅ DONE

- [x] 200+ exercises as JSON → Drift — [exercises.json](file:///Users/dankmagician/Documents/New%20project/indifit/assets/data/exercises.json)
- [x] Browse by muscle group + equipment filter chips — [exercise_library_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/exercise_library/exercise_library_screen.dart)
- [x] Exercise detail sheet — [exercise_details_sheet.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/exercise_library/exercise_details_sheet.dart)

### Sprint 2.4: Routine Display ✅ DONE

- [x] Weekly calendar view — [routine_display_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/workout_player/routine_display_screen.dart)
- [x] Tap day → workout detail
- [x] "Start Workout" → launches player
- [x] Routine saved to Drift (available offline)

---

## IndiFit Phase 3 — Workout Player (Week 3) ✅ COMPLETE

### Sprint 3.1: Player Core ✅ DONE

- [x] Full-screen exercise display — [workout_player_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/workout_player/workout_player_screen.dart)
- [x] Set counter, rep target, weight input (±2.5kg buttons)
- [x] Previous session weight for reference (from Drift)
- [x] "Complete Set" → haptic + animation → rest timer
- [x] All data saved to Drift (100% offline)

### Sprint 3.2: Rest Timer ✅ DONE

- [x] Circular countdown, wakelock on
- [x] Haptic vibration at 0
- [x] Skip rest, adjustable time
- [x] Auto-advance to next set

### Sprint 3.3: PR Detection + Summary ✅ DONE

- [x] PR detection from Drift local history
- [x] Gold crown notification + haptic pattern on new PR
- [x] Workout summary — [workout_summary_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/workout_player/workout_summary_screen.dart)
- [x] Volume, duration, calories, share card

### Sprint 3.4: AI Food Features ✅ DONE

- [x] "Describe your meal" → FastAPI → AI estimation — [ai_meal_logger_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/food_log/ai_meal_logger_screen.dart)
- [x] Photo-based estimation → Gemini Vision
- [x] Offline mock fallbacks in backend

---

## IndiFit Phase 4 — Progress & AI Features (Week 4-5) ⚠️ PARTIALLY COMPLETE

### Sprint 4.1: Progress Screen ✅ DONE

- [x] Weight chart, strength progress, workout heatmap — [progress_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/progress/progress_screen.dart)
- [x] 12-week GitHub-style heatmap grid
- [x] Double line charts (weight trend + strength volume)
- [x] All data from Drift (works offline)

### Sprint 4.2: AI Weekly Report + Meal Planner ✅ DONE

- [x] AI weekly report — backend endpoint in [main.py](file:///Users/dankmagician/Documents/New%20project/indifit/backend/main.py)
- [x] AI meal planner — [ai_meal_planner_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/food_log/ai_meal_planner_screen.dart)
- [x] Mon-Sun meal layout with Breakfast/Lunch/Dinner/Snacks
- [x] Grocery shopping list checklist

### Sprint 4.3: AI Chat 🔲 NOT STARTED

- [ ] Bubble UI chat interface — **No `ai_chat/` feature directory exists**
- [ ] Context-aware: reads user's logged data
- [ ] Premium: unlimited, Free: 5 messages/day

### Sprint 4.4: Payments 🔲 NOT STARTED

- [ ] Razorpay Subscription (₹299/mo or ₹1,999/yr) — **No Razorpay package or code in project**
- [ ] 7-day free trial
- [ ] Paywall screen: free vs premium comparison
- [ ] Referral system: share code → 1 month free each

### Sprint 4.5: Notifications ✅ DONE

- [x] `flutter_local_notifications` integrated with **NotificationService** setup — ✅ DONE
- [x] Workout reminders, meal logging reminders (Breakfast skipped to prevent spam) — ✅ DONE
- [x] Water intake reminder (twice daily), evening "log today" nudge — ✅ DONE
- [x] Weekly AI report push notification (Sunday 10 AM) — ✅ DONE
- [x] All configurable in settings panel — ✅ DONE

### Sprint 4.6: Code Hardening & Compilation Fixes ⚠️ (Audit Findings)

- [ ] Fix Flutter compile errors (`uiLocalNotificationDateInterpretation` in `notification_service.dart`, missing `AppColors.cardBorder`).
- [ ] Configure Android release signing (currently uses debug keys).
- [ ] Add `INTERNET` and camera permissions to `AndroidManifest.xml`.
- [ ] Add camera/photo usage description strings to iOS `Info.plist`.
- [ ] Replace `localhost` backend defaults with proper per-environment configuration.

### Sprint 4.7: Data Expansion & Onboarding ⚠️ (Audit Findings)

- [ ] Build a real first-run onboarding flow (age, height, weight, sex, activity level, goal, target weight, diet preference).
- [ ] Persist macro/water/weight goals instead of hardcoding them (currently hardcoded in `dashboard_screen.dart`).
- [ ] Expand local seed data: 300-500 Indian foods (currently 20) and 100-200 exercises (currently 8).
- [ ] Remove mock/demo claims from UI or explicitly label them (e.g., AI Meal Planner, PR detection).

### Sprint 4.8: Core Feature Additions 🔲 NOT STARTED

- [ ] Workout history per exercise with previous weight/reps autofill.
- [ ] Real PR calculation from past sets.
- [ ] Body measurement logging screen.
- [ ] Editable custom foods and recipes.
- [ ] Weekly adherence score: calories, protein, workouts, steps/water.
- [ ] Export/backup data.
- [ ] "No backend mode" toggle for fully private personal use.
- [ ] Health disclaimer and AI uncertainty warnings for nutrition estimates.

### Sprint 4.9: Testing & Launch 🔲 NOT STARTED

- [ ] **Android**: `flutter build apk` → sideload → test all flows
- [ ] **iOS**: Xcode Personal Team → direct-install → test all flows
- [ ] Offline test: airplane mode → full workflow verification
- [ ] Online test: reconnect → verify sync
- [ ] Performance: app launch < 2 seconds
- [ ] Personal daily use for 5-7 days

---

## Supabase Cloud Sync ✅ CODE READY / 🔲 NOT CONNECTED

### SyncManager ✅ Built
- [sync_manager.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/data/repositories/sync_manager.dart) — Listens to connectivity, pushes unsynced records
- Gracefully handles missing Supabase credentials

### Cloud Tables 🔲 NOT CREATED
- Supabase project not yet provisioned
- When created, need: `food_logs`, `workout_sessions`, `workout_sets` tables

---

## Domain Strategy (When Ready) 🔲 NOT STARTED

| Product | Primary Choice | Alternatives | Est. Cost |
|---------|---------------|-------------|-----------|
| DropAlert | dropalert.in | dropalert.co, dropalert.app | ₹400-800/yr |
| IndiFit | indifit.in | indifit.app, indifit.co | ₹400-800/yr |

Use **Cloudflare** for DNS (free) + free SSL + DDoS protection + CDN caching.

---

## Overall Completion Summary

```
🎮 DROPALERT
├── Phase 1: Core Scrapers (4 easy)        ✅ DONE
├── Phase 2: Playwright Scrapers (3 hard)  ✅ DONE
├── Phase 3: Telegram Bot                  ✅ DONE
├── Phase 4: Email + WhatsApp Alerts       ✅ DONE
├── Phase 5: Next.js Dashboard             ✅ DONE
├── Phase 6: SEO + Blog                    ✅ DONE (Insights blog cards added)
├── Phase 7: Browser Push Notifications    ✅ DONE (pywebpush + Service Worker implemented)
├── Phase 8: Deploy to Vercel + Render     🔲 NOT DONE
└── Phase 9: Second-Hand Scrapers (V2)     🔲 NOT STARTED
    (Dacby, GameNation, GameLoot, Happy Gaming World)

💪 INDIFIT
├── Phase 1: Data Layer + Food Logging     ✅ DONE
├── Phase 2: AI Routines + Exercise Lib    ✅ DONE
├── Phase 3: Workout Player               ✅ DONE
├── Phase 4: Progress + AI Meals           ✅ DONE (report + planner)
├── Phase 5: AI Chat                       🔲 NOT STARTED
├── Phase 6: Razorpay Payments             🔲 NOT STARTED
├── Phase 7: Local Notifications           ✅ DONE (workout, meals, water, evening, weekly)
├── Phase 8: Code Hardening                ✅ DONE (Sprint 4.6 compilation fixes, signing & permissions)
├── Phase 9: Data Expansion & Onboarding   🔲 NOT STARTED (Sprint 4.7)
├── Phase 10: Core Feature Additions       🔲 NOT STARTED (Sprint 4.8)
├── Phase 11: Supabase Cloud Setup         🔲 DEFERRED BY USER
└── Phase 12: Build + Test on Phones       🔲 NOT STARTED (Sprint 4.9)

🔗 SHARED
├── Supabase Project (Mumbai)              🔲 DEFERRED BY USER
├── Domain Purchase                        🔲 NOT STARTED
└── Firebase Crashlytics + Analytics       🔲 NOT STARTED
```

---

## Updated Cost Estimate

### Development Phase (Weeks 1-6): ₹0/mo

| Service | Cost | Notes |
|---------|------|-------|
| Render (backend) | Free | Cold starts ok for dev |
| Vercel (frontend) | Free | Hobby plan |
| Supabase | Free | 500MB DB, 50K auth users |
| Upstash Redis | Free | 500K commands/mo |
| Gemini API | Free | Rate-limited free tier |
| GLM-4-Flash | Free | Permanently free |
| OpenRouter | Free | 200 req/day |
| NVIDIA NIM | Free | 40 RPM prototyping |
| Resend (email) | Free | 100 emails/day |
| Telegram Bot | Free | Unlimited |
| **Total** | **₹0/mo** | **Entirely free during dev** |

### Production Phase (Post-Launch): ₹2,000-5,000/mo

| Service | DropAlert | IndiFit | Notes |
|---------|----------|---------|-------|
| Railway (backend) | $5-10/mo | $5-10/mo | No cold starts |
| Supabase | Free | Free | Until >500MB |
| Vercel | Free | — | Frontend |
| Upstash Redis | Free | — | Until >500K commands |
| DeepSeek V4-Flash | — | ~$10-30/mo | Based on usage |
| Gemini (vision) | — | ~$5/mo | Photo food logging |
| Twilio (WhatsApp) | ~₹500/mo | — | Premium alerts |
| Resend (email) | Free → $20/mo | — | Based on volume |
| Apple Developer | — | $99/yr | Shared |
| **Total** | **~₹2,000-3,000/mo** | **~₹2,500-5,000/mo** | **Before revenue** |

### Revenue vs Cost Breakeven

| Product | Monthly Cost | Breakeven Point |
|---------|-------------|----------------|
| DropAlert | ~₹3,000/mo | 31 premium subscribers (₹99/mo) OR 2 PS5 affiliate sales |
| IndiFit | ~₹4,000/mo | 14 premium subscribers (₹299/mo) |

---

## Verification Plan

### DropAlert
- **Automated**: pytest for all 7 scrapers (mock HTML), API route tests
- **Manual**: Telegram bot tested live, stock change → notification verified, dashboard renders real data, Vijay Sales scraper validated

### IndiFit
- **Android**: APK installed on personal phone, all flows tested
- **iOS**: Xcode Personal Team direct-install on personal iPhone, all flows tested
- **Offline test**: Airplane mode → log food, complete full workout, view progress, verify all data persists. Then reconnect → verify sync to Supabase
- **AI test**: Routine generation with Gemini (free), food estimation, photo logging
- **Payment**: Razorpay sandbox → test subscription flow end-to-end

### Both
- Firebase Crashlytics for crash monitoring
- Firebase Analytics for usage tracking
- Sentry for backend error alerting
