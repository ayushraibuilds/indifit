# DropAlert + IndiFit — Complete Implementation Plan (v2 + Feature Additions)

Two products built sequentially. **DropAlert** ships first (1 week, generates revenue) while **IndiFit** is developed (5 weeks, Flutter for Android + iOS).

> [!NOTE]
> This is the **original detailed design document** with an appendix of all **feature additions and architectural decisions** that evolved during implementation (Phases 1-4). For the current status-tracked version, see [implementation_plan.md](file:///Users/dankmagician/.gemini/antigravity-ide/brain/052b2f10-3cdd-4c4d-9970-7ea798e93785/implementation_plan.md).

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
> **Apple Developer Account** — Do you already have one ($99/yr)? This is required for iOS testing on physical device via TestFlight, and for App Store publishing. Android testing via APK sideload is free, but Play Store publishing needs a one-time $25 Google Play Developer fee.

> [!IMPORTANT]
> **Supabase Project Region** — For India-focused apps, choose **Mumbai (ap-south-1)** region when creating the Supabase project. This gives the lowest latency for Indian users.

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

| # | Retailer | URL | Scraping Method | Difficulty | Check Interval |
|---|----------|-----|----------------|-----------|----------------|
| 1 | Amazon India | amazon.in | Playwright + Stealth | 🔴 Hard (anti-bot) | Every 10 min |
| 2 | Flipkart | flipkart.com | Playwright (React SPA) | 🟡 Medium | Every 5 min |
| 3 | Croma | croma.com | JSON API (direct) | 🟢 Easy | Every 5 min |
| 4 | Reliance Digital | reliancedigital.in | requests + BS4 | 🟢 Easy | Every 5 min |
| 5 | PlayStation Direct | direct.playstation.com | JSON API (official) | 🟡 Medium | Every 5 min |
| 6 | Games The Shop | gamesthe.shop | requests + BS4 | 🟢 Easy | Every 5 min |
| 7 | **Vijay Sales** | vijaysales.com | **Playwright** (JS-rendered, no public API) | 🟡 Medium | Every 5 min |

#### Vijay Sales — Scraping Notes
- No public API available. Must scrape the product page directly
- Website is JavaScript-rendered → **Playwright required** (not requests+BS4)
- Check for "Add to Cart" button vs "Out of Stock" / "Notify Me" text
- Moderate anti-bot measures — use stealth plugin + random delays
- Vijay Sales is a major retailer in West India (especially Maharashtra) — worth including

### Phase 2 — Second-Hand / Recommerce Platforms (V2, post-launch)

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

## Phase 1 — Foundation & Core Scraper (Day 1-2)

### 1.1 Project Setup

#### [NEW] `dropalert/` — Root directory

```
dropalert/
├── backend/
│   ├── scrapers/
│   │   ├── base_scraper.py         # Abstract base class
│   │   ├── amazon_scraper.py       # Playwright + stealth
│   │   ├── flipkart_scraper.py     # Playwright
│   │   ├── croma_scraper.py        # JSON API (httpx)
│   │   ├── reliance_scraper.py     # requests + BS4
│   │   ├── playstation_direct.py   # JSON API (httpx)
│   │   ├── games_the_shop.py       # requests + BS4
│   │   └── vijaysales_scraper.py   # Playwright
│   ├── services/
│   │   ├── notification_service.py
│   │   ├── email_service.py        # Resend
│   │   ├── telegram_service.py     # python-telegram-bot
│   │   └── whatsapp_service.py     # Twilio
│   ├── bot/
│   │   └── telegram_bot.py
│   ├── celery_app.py
│   ├── tasks.py
│   ├── config.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── docker-compose.yml          # Local dev: Redis + Celery
├── frontend/                       # Next.js 14+
│   ├── src/
│   │   ├── app/
│   │   │   ├── page.tsx            # Live dashboard
│   │   │   ├── layout.tsx
│   │   │   ├── subscribe/page.tsx
│   │   │   ├── history/page.tsx
│   │   │   ├── blog/page.tsx       # SEO content
│   │   │   └── api/
│   │   │       ├── subscribe/route.ts
│   │   │       ├── status/route.ts
│   │   │       └── webhook/razorpay/route.ts
│   │   ├── components/
│   │   │   ├── StatusCard.tsx
│   │   │   ├── PriceChart.tsx
│   │   │   ├── SubscribeForm.tsx
│   │   │   └── RetailerBadge.tsx
│   │   ├── lib/
│   │   │   ├── supabase.ts
│   │   │   └── types.ts
│   │   └── styles/
│   ├── public/
│   ├── next.config.js
│   └── package.json
├── supabase/
│   └── migrations/
│       └── 001_initial_schema.sql
└── README.md
```

### 1.2 Database Schema (Supabase — Fresh Project, Mumbai Region)

```sql
-- Products table (multi-product from day 1)
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL,       -- "ps5-disc", "ps5-digital", "xbox-series-x"
  name TEXT NOT NULL,
  category TEXT NOT NULL,          -- "console", "gpu", "phone"
  image_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Seed initial products
INSERT INTO products (slug, name, category) VALUES
  ('ps5-disc', 'PlayStation 5 (Disc Edition)', 'console'),
  ('ps5-digital', 'PlayStation 5 (Digital Edition)', 'console'),
  ('ps5-pro', 'PlayStation 5 Pro', 'console'),
  ('xbox-series-x', 'Xbox Series X', 'console'),
  ('xbox-series-s', 'Xbox Series S', 'console');

-- Stock events log
CREATE TABLE stock_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES products(id),
  retailer TEXT NOT NULL,
  event TEXT NOT NULL,             -- "in_stock", "out_of_stock", "price_change"
  price INTEGER,
  url TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_stock_events_lookup ON stock_events(product_id, retailer, created_at DESC);

-- Subscribers
CREATE TABLE subscribers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE,
  phone TEXT,
  telegram_id TEXT,
  tier TEXT DEFAULT 'free',        -- "free" / "premium"
  products TEXT[],                 -- product slugs to watch
  retailers TEXT[],                -- retailer names to watch
  max_price INTEGER,
  push_token TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Price history
CREATE TABLE price_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES products(id),
  retailer TEXT NOT NULL,
  price INTEGER NOT NULL,
  recorded_at TIMESTAMPTZ DEFAULT now()
);

-- Second-hand listings (Phase 2, table created now for forward-compatibility)
CREATE TABLE secondhand_listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform TEXT NOT NULL,
  product_id UUID REFERENCES products(id),
  condition TEXT,
  price INTEGER NOT NULL,
  original_price INTEGER,
  warranty_months INTEGER DEFAULT 0,
  url TEXT NOT NULL,
  is_available BOOLEAN DEFAULT true,
  scraped_at TIMESTAMPTZ DEFAULT now()
);
```

### 1.3 Core Scrapers — 4 Easiest Retailers First (Day 1)

- [ ] Abstract `BaseScraper` class with `check_stock() → StockResult` method
- [ ] **Croma** — JSON API call, no scraping. Fastest to build (~30 min)
- [ ] **Reliance Digital** — `requests` + BS4. Button text check (~45 min)
- [ ] **PlayStation Direct** — JSON API endpoint from network tab (~30 min)
- [ ] **Games The Shop** — `requests` + BS4 (~30 min)
- [ ] Redis setup (Upstash free tier): cache last known status per retailer per product
- [ ] Change detection logic: compare new status vs cached → flag if changed

### 1.4 Celery + Telegram Bot (Day 2)

- [ ] Celery beat: trigger all scrapers every 5 minutes
- [ ] On stock change → `handle_stock_change()` → notification pipeline
- [ ] Telegram bot commands: `/start`, `/status`, `/price`, `/alert`, `/history`
- [ ] Test end-to-end: simulate stock change → verify Telegram notification fires
- [ ] Deploy to Render free tier for initial testing

---

## Phase 2 — Hard Scrapers + Full Notifications (Day 3-4)

### 2.1 Playwright Scrapers (Day 3)

- [ ] **Amazon India** — Playwright + stealth, random delays (3-8s), user agent rotation. Check every 10 min
- [ ] **Flipkart** — Playwright, wait for React (`networkidle`), check button text. Every 5 min
- [ ] **Vijay Sales** — Playwright (JS-rendered page), check "Add to Cart" vs "Out of Stock". Every 5 min
- [ ] Error handling: 3 retries with exponential backoff per scraper
- [ ] CAPTCHA detection: if detected, skip retailer for 30 min, alert admin via Telegram
- [ ] Health check endpoint: `/health` returns per-scraper status

### 2.2 Notification Service (Day 4)

- [ ] **Email** — Resend API (free: 100 emails/day)
- [ ] **Telegram** — python-telegram-bot (free, unlimited)
- [ ] **WhatsApp** — Twilio (premium only, ₹0.50/message)
- [ ] **Browser Push** — Web Push API via `pywebpush` (free)
- [ ] Notification deduplication: same user + same product + same retailer → max 1 alert per 30 min
- [ ] Affiliate link injection in all notification URLs

---

## Phase 3 — Frontend + Launch (Day 5-7)

### 3.1 Next.js Dashboard (Day 5-6)

- [ ] Live status page: Green/Red/Yellow badges per retailer, timestamp, price
- [ ] Supabase Realtime for live updates
- [ ] Price history chart (Recharts)
- [ ] Stock history timeline (last 30 days)
- [ ] Email subscription form with retailer preferences
- [ ] Razorpay integration (₹99/mo premium)
- [ ] Dark mode default with DropAlert blue branding
- [ ] Mobile responsive (most users on phone)
- [ ] PWA support (installable on home screen)

### 3.2 SEO + Launch (Day 7)

- [ ] Page title: "PS5 Stock India — Live Availability Tracker | DropAlert"
- [ ] Meta description, OG tags, structured data
- [ ] Blog section: "Best Time to Buy PS5 in India", "PS5 Price Hike 2026 Guide"
- [ ] Deploy: Frontend → Vercel, Backend → Render (free) or Railway ($5/mo)
- [ ] Post to: r/IndianGaming, r/PS5India, gaming Discord servers, Twitter/X

### 3.3 Domain Strategy

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
- **iOS** — Build IPA, install via TestFlight. Requires Apple Developer account ($99/yr)
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

### What Works Offline (No Internet Needed)
- ✅ Food search (Indian food database is local in Drift)
- ✅ Food logging (saved locally, synced later)
- ✅ Workout player (entire routine cached locally)
- ✅ Rest timer + haptic feedback
- ✅ PR detection (local PR history in Drift)
- ✅ Set/rep/weight logging
- ✅ Workout summary + history viewing
- ✅ Body measurement logging
- ✅ Exercise library browsing
- ✅ Water intake tracking

### What Requires Internet
- 🌐 AI routine generation (API call to backend)
- 🌐 "Describe your meal" AI estimation
- 🌐 Photo-based food logging (Vision AI)
- 🌐 AI chat
- 🌐 AI weekly report
- 🌐 Barcode scanning (Open Food Facts API lookup)
- 🌐 Cloud sync / cross-device data
- 🌐 Payments (Razorpay)

### Sync Strategy
```dart
// sync_service.dart
class SyncService {
  // Runs automatically when connectivity changes
  void init() {
    Connectivity().onConnectivityChanged.listen((status) {
      if (status != ConnectivityResult.none) {
        syncPendingData(); // Push local changes to Supabase
      }
    });
  }
  
  Future<void> syncPendingData() async {
    // 1. Push any unsynced food logs
    // 2. Push any unsynced workout sessions  
    // 3. Push body measurements
    // 4. Pull any remote changes (e.g., new routine from AI)
    // Uses "last_synced_at" timestamp to resolve conflicts
  }
}
```

---

## Phase 1 — Project Scaffolding & Data Layer (Week 1, Day 8-14)

### Sprint 1.1: Flutter Project Setup (Day 8)

#### [NEW] `indifit/` — Root Flutter project

```
indifit/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── theme/
│   │   │   ├── app_theme.dart          # Dark theme, #1D9E75 accent
│   │   │   ├── colors.dart
│   │   │   └── typography.dart         # Google Fonts: Inter
│   │   ├── router/
│   │   │   └── app_router.dart
│   │   ├── di/
│   │   │   └── providers.dart          # Riverpod providers
│   │   ├── network/
│   │   │   ├── api_client.dart         # Dio HTTP client
│   │   │   └── connectivity_service.dart
│   │   └── constants/
│   ├── data/
│   │   ├── database/
│   │   │   ├── app_database.dart       # Drift (SQLite)
│   │   │   ├── tables/                 # All Drift table definitions
│   │   │   └── daos/                   # Data access objects
│   │   ├── repositories/
│   │   ├── models/
│   │   └── sync/
│   │       └── sync_service.dart       # Offline → Online sync
│   ├── features/
│   │   ├── onboarding/
│   │   ├── dashboard/
│   │   ├── food_log/
│   │   ├── workout_player/
│   │   ├── routine_generator/
│   │   ├── exercise_library/
│   │   ├── progress/
│   │   ├── meal_planner/
│   │   ├── ai_chat/
│   │   ├── settings/
│   │   └── paywall/
│   └── shared/
│       ├── widgets/
│       └── utils/
├── assets/
│   ├── data/
│   │   ├── indian_foods.json           # 500+ Indian dishes (offline)
│   │   └── exercises.json              # 200+ exercises (offline)
│   ├── lottie/
│   └── images/
├── backend/                            # FastAPI backend
│   ├── main.py
│   ├── routers/
│   │   ├── ai_router.py               # AI endpoints (provider-agnostic)
│   │   ├── sync_router.py
│   │   └── payment_router.py
│   ├── services/
│   │   ├── ai_service.py              # Provider switcher (Gemini/DeepSeek/GLM)
│   │   └── payment_service.py
│   ├── requirements.txt
│   └── Dockerfile
├── supabase/
│   └── migrations/
├── pubspec.yaml
└── README.md
```

#### Updated `pubspec.yaml` Dependencies

```yaml
dependencies:
  flutter_riverpod: ^2.5.1        # State management
  drift: ^2.16.0                  # Local DB (replaces deprecated Isar)
  sqlite3_flutter_libs: ^0.5.20   # SQLite for Drift
  supabase_flutter: ^2.3.4        # Cloud sync + auth
  go_router: ^13.2.0              # Navigation
  connectivity_plus: ^6.0.3       # Offline detection
  
  # Food logging
  mobile_scanner: ^5.1.0          # Barcode scanner
  dio: ^5.4.0                     # HTTP client (better than http package)
  
  # Charts + UI
  fl_chart: ^0.67.0               # Charts
  percent_indicator: ^4.2.3       # Rings
  flutter_animate: ^4.5.0         # Animations
  lottie: ^3.1.0                  # PR celebration
  google_fonts: ^6.1.0            # Inter, Outfit fonts
  
  # Workout player
  vibration: ^1.9.0               # Haptic feedback
  wakelock_plus: ^1.1.4           # Screen stays on
  just_audio: ^0.9.37             # Timer sounds
  
  # Notifications
  flutter_local_notifications: ^17.1.2
  
  # Other
  share_plus: ^9.0.0
  image_picker: ^1.1.2
  shared_preferences: ^2.2.2      # Simple key-value (replaces Hive)
  intl: ^0.19.0
  path_provider: ^2.1.2
```

#### Deliverables
- [ ] Flutter project: `com.indifit.app` (Android) + `com.indifit.IndiFit` (iOS)
- [ ] Riverpod, Drift, Supabase, GoRouter configured
- [ ] Dark theme with #1D9E75 green accent, Inter font
- [ ] Fresh Supabase project (Mumbai region), auth: Google + Apple Sign-In
- [ ] Connectivity service for offline detection
- [ ] FastAPI backend scaffolded (Render free tier initially)

### Sprint 1.2: Indian Food Database (Day 9-10)

- [ ] 500+ Indian dishes compiled from ICMR nutritional data
- [ ] Embedded as `indian_foods.json` in app assets (works offline)
- [ ] Fields: `name`, `name_hindi`, `calories`, `protein_g`, `carbs_g`, `fat_g`, `fiber_g`, `serving_size`, `serving_unit`, `category`
- [ ] Regional variants: "dal makhani", "dal fry", "toor dal", "moong dal"
- [ ] Seed into Drift on first launch
- [ ] Fuzzy search: "paratha" = "parantha" = "parathaa"

### Sprint 1.3: Food Logging (Day 10-12)

- [ ] Search bar → Drift local DB first (offline), then Open Food Facts API (online)
- [ ] Tap result → adjust serving → confirm → saved to Drift
- [ ] Meal sections: Breakfast, Lunch, Dinner, Snacks
- [ ] Quick-add: recently logged + favorites
- [ ] Barcode scanner → Open Food Facts lookup (online only)
- [ ] All food logs stored in Drift, synced to Supabase when online

### Sprint 1.4: Dashboard (Day 12-14)

- [ ] Calorie ring, macro bars, today's workout card
- [ ] Water tracker, weight sparkline, streak counter
- [ ] All data from Drift (works offline)
- [ ] Supabase auth (Google + Apple Sign-In)

---

## Phase 2 — AI Routine Generator & Exercise Library (Week 2, Day 15-21)

### Sprint 2.1: Onboarding Wizard (Day 15-16)

5 single-question screens:
1. **Goal** — Muscle Gain / Fat Loss / Strength / General Fitness
2. **Equipment** — Full Gym / Home Dumbbells / Bodyweight Only
3. **Schedule** — Tap days: M T W T F S S
4. **Experience** — Beginner / Intermediate / Advanced
5. **Considerations** — None / Lower back / Knee / Shoulder issues

### Sprint 2.2: AI Backend — Provider-Agnostic (Day 16-18)

- [ ] `POST /api/routine/generate` — Takes profile → AI prompt → structured JSON routine
- [ ] Provider switching: Gemini (dev/free) → DeepSeek (production/cheap) → GLM (fallback/free)
- [ ] Response caching: same profile inputs → cached response (save API cost)
- [ ] Rate limiting: 3 generations/day (free), unlimited (premium)
- [ ] Response validation: verify exercise names exist in library

### Sprint 2.3: Exercise Library (Day 18-20)

- [ ] 200+ exercises as JSON asset → Drift (works offline)
- [ ] Browse by muscle group + equipment filter chips
- [ ] Search by name
- [ ] Exercise detail: YouTube embed (online), form cues, common mistakes
- [ ] Exercise substitution mapping: "No bench? Try floor press"

### Sprint 2.4: Routine Display (Day 20-21)

- [ ] Weekly calendar view, color-coded
- [ ] Tap day → workout detail with exercise list
- [ ] "Start Workout" → launches player
- [ ] Routine saved to Drift (workout available offline)

---

## Phase 3 — Workout Player (Week 3, Day 22-28)

### Sprint 3.1: Player Core (Day 22-24)

- [ ] Full-screen exercise display (hide nav)
- [ ] Set counter, rep target, weight input (±2.5kg buttons)
- [ ] Previous session weight for reference (from Drift)
- [ ] "Complete Set" → haptic + animation → rest timer
- [ ] All data saved to Drift (100% offline)

### Sprint 3.2: Rest Timer (Day 24-25)

- [ ] Circular countdown, wakelock on
- [ ] Haptic vibration at 0, optional beep
- [ ] Skip rest, adjustable time (±15s)
- [ ] Auto-advance to next set

### Sprint 3.3: PR Detection + Summary (Day 25-26)

- [ ] PR detection from Drift local history
- [ ] Lottie confetti animation on new PR
- [ ] Workout summary: volume, duration, exercises, PRs
- [ ] Share as image card
- [ ] Workout notes field

### Sprint 3.4: AI Food Features (Day 26-28)

- [ ] "Describe your meal" → FastAPI → AI estimation → confirm → log
- [ ] Photo-based estimation → Gemini Vision (online only)
- [ ] AI uses DeepSeek (text) or Gemini (vision) based on input type

---

## Phase 4 — Progress, Payments & Launch (Week 4-5, Day 29-42)

### Sprint 4.1: Progress Screen (Day 29-31)

- [ ] Weight chart, strength progress, workout heatmap
- [ ] Body measurements, progress photos
- [ ] All data from Drift (works offline)

### Sprint 4.2: AI Weekly Report + Meal Planner (Day 31-33)

- [ ] Sunday AI report: reads week's data → personalized summary
- [ ] AI meal planner: calorie goal + veg/non-veg → 7-day Indian meal plan
- [ ] Auto-generated grocery list
- [ ] Premium features (₹299/mo)

### Sprint 4.3: AI Chat (Day 33-34)

- [ ] Bubble UI chat interface
- [ ] Context-aware: Claude/DeepSeek sees user's logged data
- [ ] Premium: unlimited, Free: 5 messages/day

### Sprint 4.4: Payments (Day 34-35)

- [ ] Razorpay Subscription (₹299/mo or ₹1,999/yr)
- [ ] 7-day free trial
- [ ] Paywall screen: free vs premium comparison
- [ ] Referral system: share code → 1 month free each

### Sprint 4.5: Notifications (Day 35-36)

- [ ] Workout reminders, meal logging reminders
- [ ] Water intake reminder, evening "log today" nudge
- [ ] Weekly AI report push notification
- [ ] All configurable in settings

### Sprint 4.6: Testing & Launch (Day 36-42)

- [ ] **Android**: `flutter build apk` → sideload on personal phone → test all flows
- [ ] **iOS**: `flutter build ipa` → TestFlight → install on personal iPhone → test all flows
- [ ] Offline test: airplane mode → log food, complete workout, verify everything works
- [ ] Online test: disable airplane mode → verify sync to Supabase
- [ ] Performance: app launch < 2 seconds
- [ ] Firebase Crashlytics + Analytics integration
- [ ] Use the app personally for 5-7 days before any public release
- [ ] Fix all bugs found during personal use

---

## Domain Strategy (When Ready)

| Product | Primary Choice | Alternatives | Est. Cost |
|---------|---------------|-------------|-----------|
| DropAlert | dropalert.in | dropalert.co, dropalert.app | ₹400-800/yr |
| IndiFit | indifit.in | indifit.app, indifit.co | ₹400-800/yr |

Use **Cloudflare** for DNS (free) + free SSL + DDoS protection + CDN caching.

---

## Combined Timeline

```
PREP (Day 0):
  Accounts: Supabase (Mumbai), Render, Vercel, Upstash, Telegram Bot
  Keys: Gemini API (free), Resend (free), Razorpay (sandbox)
  ───────────────────────────────────────────────────────
WEEK 1 (Day 1-7): 🎮 DropAlert — Full build + launch
  Day 1:   4 easy scrapers (Croma, Reliance, PS Direct, Games The Shop)
  Day 2:   Celery + Redis + Telegram bot + change detection
  Day 3:   Playwright scrapers (Amazon, Flipkart, Vijay Sales)
  Day 4:   Notification service (email, Telegram, WhatsApp, push)
  Day 5-6: Next.js dashboard + subscription flow + Razorpay
  Day 7:   SEO, deploy to Vercel + Render, launch on Reddit/Discord
  ───────────────────────────────────────────────────────
  🎮 DropAlert is LIVE. Revenue generating passively.
  ───────────────────────────────────────────────────────
WEEK 2 (Day 8-14): 💪 IndiFit — Phase 1: Data layer + food logging
  Day 8:    Flutter setup, Supabase, Drift, theme, auth
  Day 9-10: Indian food database (500+ dishes, offline JSON)
  Day 10-12: Food logging screen + barcode scanner
  Day 12-14: Dashboard (calorie ring, macros, water, streak)
  ───────────────────────────────────────────────────────
WEEK 3 (Day 15-21): 💪 IndiFit — Phase 2: AI + exercise library
  Day 15-16: Onboarding wizard (5-step)
  Day 16-18: FastAPI AI backend (Gemini free → DeepSeek production)
  Day 18-20: Exercise library (200+ exercises, offline)
  Day 20-21: Routine display + "Start Workout" flow
  ───────────────────────────────────────────────────────
WEEK 4 (Day 22-28): 💪 IndiFit — Phase 3: Workout player
  Day 22-24: Workout player core + weight input
  Day 24-25: Rest timer + haptic + wakelock
  Day 25-26: PR detection + workout summary
  Day 26-28: AI food estimation (text + photo)
  ───────────────────────────────────────────────────────
WEEK 5 (Day 29-35): 💪 IndiFit — Phase 4: Progress + polish
  Day 29-31: Progress screen (charts, heatmap, photos)
  Day 31-33: AI weekly report + meal planner
  Day 33-35: AI chat + Razorpay payments + notifications
  ───────────────────────────────────────────────────────
WEEK 6 (Day 36-42): 💪 IndiFit — Testing + personal use
  Day 36-37: Build APK (Android) + IPA (iOS), install on phones
  Day 37-38: Full testing: offline mode, sync, all features
  Day 38-42: Personal daily use, bug fixes, polish
  ───────────────────────────────────────────────────────
  💪 IndiFit tested on personal phones. Ready for friends/beta.
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

# 🆕 APPENDIX: Feature Additions During Implementation

The following features, architectural decisions, and design patterns were **added or changed during development** beyond what was originally specified in the v2 plan above.

---

## 🎮 DropAlert — Implementation Additions

### A1. Lifespan Scheduler (Replaced Celery)

The original plan called for **Celery + Redis** as the background task runner. During implementation, this was replaced with a simpler **asyncio lifespan scheduler** embedded directly in the FastAPI process.

**Rationale**: Celery requires a separate worker process and a Redis broker — two extra services on Render's free tier. The lifespan approach runs the scraper loop inside the same FastAPI process using `asyncio.create_task()`, needing zero additional infrastructure.

```python
# Actual implementation in dropalert/backend/main.py
async def scheduler_loop():
    await asyncio.sleep(5.0)  # Boot grace period
    interval = settings.SCRAPER_INTERVAL_MINUTES * 60
    while True:
        await run_scraper_cycle()
        await asyncio.sleep(interval)

@asynccontextmanager
async def lifespan(app: FastAPI):
    scheduler_task = asyncio.create_task(scheduler_loop())
    yield
    scheduler_task.cancel()
```

### A2. In-Memory Redis Fallback Cache

The original plan assumed **Upstash Redis** would always be available. The implementation adds a **graceful in-memory fallback** — if Redis is unavailable (no URL configured, connection failed), a Python `dict` is used as cache.

```python
# dropalert/backend/main.py
redis_client = None
local_cache: Dict[str, Dict] = {}  # Fallback if Redis is down

def get_cached_status(retailer, product_slug):
    if redis_client:
        return json.loads(redis_client.get(key))
    return local_cache.get(key)  # In-memory fallback
```

### A3. Demo Mode Frontend

The Next.js dashboard now includes a **Demo Mode** that activates automatically when the backend API is unreachable. This allows the UI to be fully functional with mock data for development, screenshots, and presentations.

- Banner: "Running in Demo Mode" with amber warning
- Mock subscription flow (simulates success)
- Mock stock status cards with realistic data
- Auto-detects when backend comes online and disables demo mode

### A4. Health Check API Endpoint

Added `GET /health` endpoint not in the original plan. Returns:
- Database connection status (Supabase connected/disconnected)
- Cache status (Redis connected / in-memory fallback)
- Scheduler stats (last run time, duration, success/error counts, per-retailer health)

Useful for UptimeRobot monitoring and debugging scraper issues.

### A5. Supabase Graceful Degradation

Both the backend and frontend now **start and run without Supabase credentials**. The original plan assumed Supabase would be configured from day 1. The implementation wraps all Supabase operations in try/catch with informative logging, allowing full local development.

---

## 💪 IndiFit — Implementation Additions

### B1. Offline Rule-Based Routine Builder (Client-Side)

The original plan only specified an AI backend for routine generation. The implementation adds a **complete offline fallback** in the Flutter app itself:

```dart
// ai_routine_service.dart — Tries API first, falls back to local rules
Future<GeneratedRoutineResult> generateRoutine(...) async {
  try {
    // 1. Try online FastAPI backend
    final response = await _dio.post('$backendUrl/api/ai/routine', ...);
    return parseResponse(response);
  } catch (e) {
    // 2. Offline fallback — local rule engine
    return _generateOfflineFallback(goal, equipment, daysPerWeek, experience);
  }
}
```

The local fallback generates structured Push/Pull/Legs (3-day) or Upper/Lower (4-5 day) splits based on the user's parameters. This means routine generation works **with zero internet and zero backend**.

### B2. Heuristic AI Mock Fallbacks (Backend)

The FastAPI backend includes **keyword-based heuristic estimators** that activate when the Gemini API key is not configured:

- **Routine endpoint**: Returns structured 3-day or 4-day splits with real exercise data
- **Text meal estimator**: Parses keywords like "roti", "chicken", "egg" → returns realistic Indian food macros
- **Photo meal estimator**: Returns generic meal estimate when Vision API is unavailable

This means the **entire AI pipeline is testable without any API keys**.

```python
# backend/main.py — Heuristic meal estimation
def _mock_meal_estimate(text):
    if "roti" in text.lower():
        return {"name": "Roti with Dal & Veg", "calories": 380, "protein": 12.5, ...}
    elif "chicken" in text.lower():
        return {"name": "High Protein Chicken Salad", "calories": 420, "protein": 38.0, ...}
```

### B3. SyncManager with `isSynced` Flag Pattern

The original plan described a generic `SyncService` with `last_synced_at` timestamps. The actual implementation uses a simpler and more robust **`isSynced` boolean flag** per record in the Drift schema:

```dart
// sync_manager.dart
class SyncManager {
  // Listens to connectivity_plus stream
  // On connection: SELECT WHERE isSynced = false → UPSERT to Supabase → UPDATE isSynced = true
  
  Future<void> _syncFoodLogs() async {
    final unsynced = await (_db.select(_db.foodLogs)
      ..where((tbl) => tbl.isSynced.equals(false))).get();
    await client.from('food_logs').upsert(payload);
    // Mark locally as synced
    await _db.update(_db.foodLogs)
      .write(FoodLogsCompanion(isSynced: Value(true)));
  }
}
```

This pattern syncs: **food_logs**, **workout_sessions**, and **workout_sets** (including per-set PR flags).

### B4. Supabase Safe Initialization

The `main.dart` wraps Supabase initialization in `try/catch` so the app **boots and runs fully offline** when no Supabase URL/key is configured. The SyncManager also checks `Supabase.instance.client` availability before attempting any sync.

### B5. iOS Testing Without Apple Developer Account

The original plan assumed TestFlight + $99/yr Apple Developer Program. Since the user confirmed they **don't have an Apple Developer Account**, the implementation includes:

1. **Xcode Personal Team Provisioning** (free) — 7-day certificate, direct device install
2. **Developer Mode setup guide** for physical iPhone
3. **Manual barcode text input** field in the barcode scanner — allows testing product lookup on the iOS Simulator without a camera

Documented in [README.md](file:///Users/dankmagician/Documents/New%20project/indifit/README.md) with step-by-step instructions.

### B6. AI Meal Planner with Grocery List

The original plan mentioned "AI meal planner" as a simple feature. The implementation includes a **full grocery shopping list** auto-generated from the 7-day meal plan:

- Mon-Sun layout with Breakfast/Lunch/Dinner/Snacks
- Custom diet profiles: Vegetarian, Vegan, Non-Veg
- Ingredient aggregation across all meals → checklist panel
- Items with estimated quantities (e.g., "Paneer: 1.2kg", "Oats: 500g", "Wheat flour: 3kg")

Implemented in [ai_meal_planner_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/food_log/ai_meal_planner_screen.dart)

### B7. PR Detection with Haptic Patterns

The original plan mentioned "Lottie confetti animation on new PR". The implementation uses a **gold crown notification overlay + haptic vibration pattern** instead of Lottie (simpler, no extra asset files). PR detection queries the Drift workout_sets table for max historical weight per exercise.

### B8. Relational Routine Caching (Drift)

Not in the original plan — added `workout_routines`, `routine_days`, and `routine_exercises` Drift tables to **persist generated routines locally** inside a database transaction. This means:
- Routines survive app restarts
- Routines are available fully offline after first generation
- The weekly calendar header reads directly from Drift

### B9. Dashboard Navigation Scaffold

The original plan didn't specify navigation structure. The implementation uses a **BottomNavigationBar scaffold** ([main_navigation_scaffold.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/dashboard/main_navigation_scaffold.dart)) with tabs for:
- Home (Dashboard)
- Food Log
- Workout
- Exercise Library
- Progress

---

## 📝 Decisions Resolved During Implementation

| Original Question | Resolution |
|---|---|
| Apple Developer Account needed? | **No** — using Xcode Personal Team (free, 7-day cert) |
| Celery or simpler scheduler? | **Lifespan scheduler** — zero extra infrastructure |
| Lottie for PR celebration? | **Gold crown overlay + haptics** — no extra asset dependency |
| SyncService with timestamps? | **SyncManager with `isSynced` boolean** — simpler, more robust |
| Supabase required from day 1? | **No** — all code has offline/demo fallbacks |
| AI keys required for testing? | **No** — heuristic mock fallbacks for all AI endpoints |
| TestFlight for iOS? | **No** — Xcode direct-install with Personal Team |

---

## Verification Plan

### DropAlert
- **Automated**: pytest for all 7 scrapers (mock HTML), API route tests
- **Manual**: Telegram bot tested live, stock change → notification verified, dashboard renders real data, Vijay Sales scraper validated

### IndiFit
- **Android**: APK installed on personal phone, all flows tested
- **iOS**: IPA via TestFlight on personal iPhone, all flows tested
- **Offline test**: Airplane mode → log food, complete full workout, view progress, verify all data persists. Then reconnect → verify sync to Supabase
- **AI test**: Routine generation with Gemini (free), food estimation, photo logging
- **Payment**: Razorpay sandbox → test subscription flow end-to-end

### Both
- Firebase Crashlytics for crash monitoring
- Firebase Analytics for usage tracking
- Sentry for backend error alerting
