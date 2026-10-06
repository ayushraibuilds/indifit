# IndiFit: Market, Moat and Revenue (2026-10-05)

Companion to [FINAL_LAUNCH_AUDIT_2026-10-05.md](../audit/FINAL_LAUNCH_AUDIT_2026-10-05.md).

> **Update 2026-10-06:** nutrition is now "online-sourced, locally served". Food data arrives as versioned catalogue packs that are downloaded, checked and stored on the phone, and search stays local. The catalogue items in § 3, § 5 and § 6 now run through [NUTRITION_CATALOGUE_PACKS_PLAN.md](../implementation/NUTRITION_CATALOGUE_PACKS_PLAN.md) (CAT-1 … CAT-13). Content growth depends on data licences (CAT-10): INDB only with the authors' permission, otherwise recipes built from CC0 (USDA) and OGL (UK CoFID) ingredient data. The market facts below are unchanged.

**Rules followed**
- Every market fact links to a source opened on **2026-10-05**.
- Competitor marketing copy is labelled *claim*. User reviews are labelled *user-reported*.
- Where nothing was verified, the cell says **unknown**.
- No competitor app was installed (Ayush didn't approve installs), so competitor logging speed is **unknown**. IndiFit's is measured.

---

## 1. Method and sources

| Data | How collected | Source |
|---|---|---|
| Rating, review count, downloads, ads flag, IAP range, Data-safety summary, description | Play Store listing, India locale | `https://play.google.com/store/apps/details?id=<package>&hl=en_IN&gl=IN` (packages in § 2) |
| Recent 1–3★ reviews | The public Play web review feed (the same endpoint the store page uses): 12 newest 1★, 12 newest 2★, 12 newest 3★ per app. **504 reviews from 14 apps**, mostly Jul–Oct 2026. All were read for clustering; § 4 counts are keyword matches, so one review can fall in several clusters. | Play Store, accessed 2026-10-05 |
| INR and USD in-app prices | The App Store product page's "In-App Purchases" list, India and US storefronts | `https://apps.apple.com/in/app/id<id>` and `/us/` |
| App Store India rating | iTunes Search API, `country=in` | `https://itunes.apple.com/search?…&country=in` |
| Other facts | Linked inline | — |

Package and App Store ids:

| App | Package | App Store id |
|---|---|---|
| HealthifyMe | `com.healthifyme.basic` | 943712366 |
| cult.fit | `fit.cure.android` | 1217794588 |
| FITTR | `com.squats.fittr` | 1332568703 |
| MyFitnessPal | `com.myfitnesspal.android` | 341232718 |
| Cronometer | `com.cronometer.android.gold` | 1145935738 |
| MacroFactor | `com.sbs.diet` | 1553503471 |
| Lose It! | `com.fitnow.loseit` | 297368629 |
| Yazio | `com.yazio.android` | 946099227 |
| Hevy | `com.hevy` | 1458862350 |
| Strong | `io.strongapp.strong` | 464254577 |
| Fitbod | `com.fitbod.fitbod` | 1041517543 |
| Jefit | `je.fit` | 449810000 |
| Cal AI | `com.viraldevelopment.calai` | 6480417616 |
| SnapCalorie | `com.snapcalorie.alpha002` | 1574239307 |
| FitTrack AI *(rising Indian app)* | `in.fittrackai.app` | — |

---

## 2. Feature matrix

**Legend**
- "Acct req." = an account is required before use (*user-reported* unless noted).
- Ads = the Play "Contains ads" flag.
- Sharing = the Play Data-safety "may share" summary.

| App | Target user | Indian food coverage | Strength depth | Offline | Acct / ads / sharing | AI features | India price (App Store IN) | US price | Free tier | Play ★ (reviews · installs) | App Store IN ★ |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **IndiFit** (this audit) | Indian home-food eaters who lift | 261 dishes + 312 size/oil variants; katori, piece, glass, plate measures; Hinglish synonyms; 25 regional foods (measured) | Plans, player, one-tap sets, rest timer, PR summary (measured) | **Yes**: logging, search and the player work offline (verified, shots 122–124) | **None / none / AI text+photo to Google only after consent** | Describe meal, meal photo (Beta), label scan; catalogue computes | Free | Free | Everything | not listed | not listed |
| **HealthifyMe** | Indians wanting weight loss and coaching | "100,000 foods" (*claim*, Play description); Snap trained on "150,000 Indian food items" (*claim*, [TechCrunch 2023-09-21](https://techcrunch.com/2023/09/21/khosla-backed-healthifyme-introduces-ai-powered-image-recognition-for-indian-food/)); katori units **unknown** | Activity/workout tracking; no set logger seen; a user asks for Hevy integration | unknown | OTP sign-in (*user-reported*) / no / "Location, Personal info and 5 others" | Snap photo, voice, "Ria" AI coach (*claim*) | Healthify+ ₹499 / ₹1,899; Smart Plan ₹499–₹4,199 | $14.99/mo; $24.99–$49.99/yr; "Healthify AI" $29.99 | Snap was free in 2023 (TechCrunch); 2026 reviews say core features need a plan (*user-reported*) | 4.4 (5.69 L · 1 Cr+) | 4.55 (66,611) |
| **cult.fit** | Gym and class members | unknown | Classes and workout plans | unknown | Biometric login complaints / no / "App info and performance" | unknown | Cultpass LIVE ₹449/mo, ₹999/qtr, ₹1,999/yr | $4.99/mo, $22.49/yr | unknown | 4.6 (1.43 L · 10M+) | 4.81 (137,668) |
| **FITTR** | Coached fat loss (India) | Indian diet plans (*claim*); a user says Indian sabji is missing (*user-reported*, 2025) | Structured plans | unknown | "Add option to try app without signup" (*user-reported*) / no / "Personal info, App activity and 2 others" | unknown | Coach programs ₹7,599; groups ₹149–₹249 | $79.99 coach; $0.99–$2.99 groups | unknown | 4.4 (21.1 K · 10 L+) | 4.64 (6,435) |
| **MyFitnessPal** | Global calorie counters | "5 million foods (including restaurant dishes)" (*claim*); Indian **unknown** | Basic exercise log | unknown | Account (login complaints) / **yes** / "Location, Personal info and Device or other IDs" | Meal scan (Premium, *user-reported*) | Premium ₹619/mo, ₹3,099/yr; Premium+ ₹1,699/mo, ₹6,700/yr | $19.99/mo; $79.99/yr | Barcode and macros-per-meal behind the paywall (*user-reported*, Sept–Oct 2026) | 4.5 (29.2 L · 10 Cr+) | 4.69 (32,718) |
| **Cronometer** | Micronutrient trackers | "1 million verified foods" (*claim*); "need more Indian food options" (*user-reported*) | Basic | "Unusable without internet" (*user-reported*) | Account / **yes** / "Personal info" | AI photo and voice in Gold (*claim*) | Gold ₹999/mo, ₹5,900/yr | $10.99/mo, $59.99/yr | Logging with frequent ads | 4.4 (58.9 K · 50 L+) | 4.76 (443) |
| **MacroFactor** | Evidence-based dieters | unknown; "measured in imperial" (*user-reported*) | Separate workouts app (bundle ₹9,900/yr) | unknown | Account / no / "No data shared" | Weekly AI coach (*claim*) | ₹1,049/mo, ₹4,199/6 mo, ₹6,300/yr | $11.99/mo, $71.99/yr | **None**: trial only (Play description) | 3.9 (17.1 K · 10 L+) | 4.53 (88) |
| **Lose It!** | Weight loss (US) | unknown | Exercise sync | unknown | Account / **yes** / "Personal info and Device or other IDs" | "Snap It" photo (*claim*) | ₹299–₹6,600; lifetime ₹5,900 | $39.99/yr; lifetime $49.99–$59.99 | Basic (ads) | 4.4 (1.84 L · 1 Cr+) | 4.58 (2,755) |
| **Yazio** | Weight loss and fasting | "4 million+" items (*claim*) | — | unknown | Account / **yes** / "Location, Personal info and Device or other IDs" | AI camera (*claim*); inconsistent results (*user-reported*) | ₹419–₹3,299 | $23.90–$47.90/yr | Calorie tracking with nags | 4.4 (8.68 L · 5 Cr+) | 4.54 (2,139) |
| **Hevy** | Lifters | — | **Deep**: routines, history, watch, videos | unknown | Account (*user-reported*) / no / "No data shared" | — | Pro ₹249/mo, ₹1,999/yr, ₹6,500 lifetime | $2.99/mo, $23.99/yr, $74.99 lifetime | 4 routines, 7 custom exercises (*user-reported*) | **4.9** (2.74 L · 50 L+) | 4.90 (9,157) |
| **Strong** | Lifters | — | Deep (plate and warm-up calculators, supersets) | unknown | Account required, password resets (*user-reported*) / no / "No data shared" | — | PRO ₹389/mo, ₹1,799–₹2,449/yr, ₹7,900–₹9,900 forever | $4.99/mo, $29.99/yr, $99.99 forever | 3 templates (*user-reported*) | 4.2 (42.7 K · 10 L+) | 4.84 (1,937) |
| **Fitbod** | AI-planned gym training | — | Generated plans | unknown | Account / no / "Financial info" | AI plan generation (*claim*) | ₹360–₹399/mo, ₹1,999–₹2,000/yr | $12.99–$15.99/mo, $79.99–$95.99/yr | "No free options" (*user-reported*) | 3.9 (31.5 K · 10 L+) | 4.75 (1,009) |
| **Jefit** | Gym routines | — | "1400 exercises", 3,000+ routines (*claim*) | unknown | Account / no / "No data shared" | AI insights (*user-reported* as bloat) | Elite ₹1,149/mo, ₹6,300–₹6,900/yr | $12.99/mo, $69.99/yr | Logging (nags) | 4.4 (89.9 K · 50 L+) | 4.68 (648) |
| **Cal AI** | Photo-first calorie counting | Weak for non-US food (*user-reported*: Indonesian food) | — | unknown | Paywall at onboarding (*user-reported*) / no / "Personal info" | Photo, voice | "Unlimited" ₹119–₹3,999; streak restore ₹99 | $2.99–$29.99 | Effectively none (*user-reported*) | 4.4 (2.72 L · 10 L+) | 4.66 (13,663) |
| **SnapCalorie** | Photo and voice logging | USDA-based (*claim*) | — | unknown | Forced sign-up (*user-reported*) / no / "No data shared" | Photo portions, label scanner (*claim*) | ₹999–₹14,900 | $9.99–$149 | Exists, with popups (*user-reported*) | 4.5 (24.5 K · 5 L+) | 4.61 (317) |
| **FitTrack AI** (Indian, new) | Indians wanting AI photo logging | "200+ Indian dishes" photo AI (*claim*) | AI workout planner (*claim*) | unknown | unknown / no / "Personal info and Health and fitness" | Photo, diet planner, chat (*claim*) | Play IAP ₹360–₹5,200 | — | "Completely free" (*claim*) | 4.3 (122 · **1K+**) | — |

*Notes*
- Play "per item" price ranges are listed on the listings. For cult.fit and FITTR the Play range was ambiguous (IAP flag absent), so App Store prices are used.
- Logging speed for every competitor is **unknown**; it needs a hands-on trial.

## 3. Where IndiFit wins, loses or ties

| Dimension | Result | Why (evidence) |
|---|---|---|
| No account, no ads, no paywall | **Wins** | 10+ competitors draw account, paywall or ads complaints (§ 4); IndiFit needs none of them. |
| Offline core | **Wins** | Verified offline search, logging and player. Cronometer is "unusable without internet" (*user-reported*); others unknown. |
| Indian household measures in search and portions | **Wins narrowly** | Katori, piece and glass measures, a katori drawing, Hinglish synonyms (live). HealthifyMe has a bigger Indian DB (*claim*); katori units unknown. |
| Strength logging plus Indian nutrition in one app | **Wins** | Hevy and Strong lack nutrition; HealthifyMe lacks a set logger (a user asks for a Hevy integration). |
| Set-logging speed | **Ties** with Hevy and Strong | One tap per set after the first (live). Competitor speed unknown. |
| AI "parse then catalogue" accuracy | **Potential win, not yet** | The text eval was good (3 Oct) but uses old code; the flagship example still needs a choice (probe); photo and label are unmeasured. |
| Catalogue breadth | **Loses** badly | 261 dishes vs "100,000" (HealthifyMe *claim*), "5 million" (MFP *claim*), "1 million" (Cronometer *claim*). Open Food Facts helps for packaged food only. |
| Thali / mixed-plate logging | **Loses today** | IndiFit's thali records 0 kcal (audit C-01). HealthifyMe's Snap handles thali plates (*claim*, TechCrunch). |
| Exercise library | **Loses** | 140 exercises vs Jefit's "1400" (*claim*); Hevy has 200+ videos (*claim*). |
| Sync, wearables, web | **Loses** | No cloud, no web, no watch. Hevy and Strong have watch apps (*user-reported*). |
| Trust / ratings | **Unknown** | Not launched. Hevy 4.9 sets the bar for lifters. |

## 4. What users complain about (504 recent 1–3★ Play reviews, 14 apps)

| Cluster | Matches | Apps | Representative complaints (paraphrased, no names) | IndiFit today | Cheap to win? |
|---|---:|---:|---|---|---|
| Bugs, crashes, slowness, sync | 120 (24 %) | 12 | cult.fit back button exits the app; Hevy edit crash; MacroFactor freezes; Cal AI loses streaks | Stable in this walkthrough | Keep quality high |
| **Paywall creep / subscription surprise** | 88 (17 %) | 12 | MFP moved macros-per-meal and barcode behind Premium; HealthifyMe "everything behind paywall"; Cal AI and Fitbod "not free"; Strong 3-template limit; Hevy 7 custom exercises | **Free, no paywall** | ✅ Already solved |
| Wrong or missing nutrition data | 50 (10 %) | 11 | HealthifyMe "cooked rice 858 kcal"; can't override values; Cronometer search returns nothing | Editable label values, custom foods; but C-04 data errors | ✅ After catalogue v2 |
| **Mandatory account / broken login** | 46 (9 %) | 10 | Strong password resets; Hevy "why do I need to sign up?"; SnapCalorie forced login; FITTR "try without signup" | **No account** | ✅ Already solved |
| **Ads interrupting logging** | 34 (7 %) | 8 | Cronometer full-screen ads mid-typing; Lose It "heck ton of ads" | **No ads** | ✅ Already solved |
| Redesign broke the workflow | 24 (5 %) | 7 | MFP Oct-2026 redesign hides the diary | — | Stable UI promise |
| AI photo inaccurate | 16 (3 %) | 7 | Cal AI "wildly inaccurate"; HealthifyMe Snap "90 g protein for 4 pieces of chicken"; Yazio inconsistent | AI parses, catalogue computes, review before log | ✅ Once C-06 is fixed |
| Sales calls / coach upsell | 16 (3 %) | 5 | HealthifyMe coach no-shows and rude sales calls; FITTR support | None | ✅ Already solved |
| Long onboarding before a paywall | 15 (3 %) | 7 | Yazio "100 questions"; MacroFactor "5–10 min then £10"; Cal AI "6 minutes then pay" | 4 short steps + Skip | ✅ Already solved |
| Indian food missing | 14 (3 %) | 6 | Cronometer "need more Indian food"; FITTR "sabji not mentioned" | The core focus | ✅ With catalogue growth |

**Top 5 complaints IndiFit already solves, or could cheaply:**
1. Paywalls.
2. Mandatory accounts.
3. Ads.
4. Inaccurate AI photo estimates (via catalogue-computed AI, once C-06 is fixed).
5. Missing or wrong Indian food data (via catalogue v2).

**Gaps IndiFit must close before people switch:**
- **Thali has to work** (C-01/02/03). It is the one feature a HealthifyMe user would switch for.
- **Catalogue breadth and quality:** 261 dishes is thin. Target ~600 verified dishes with gram weights per katori/piece, plus the top 200 restaurant and street foods. Delivered as catalogue packs that update without an app release ([packs plan](../implementation/NUTRITION_CATALOGUE_PACKS_PLAN.md) CAT-6, CAT-7, CAT-11).
- **One-tap "usual meal" logging from Today** (§ 6.2 of the audit).
- **Phone-switch safety without an account:** an encrypted export to Drive or iCloud via the share sheet exists; make it a guided monthly reminder.
- **Health Connect / HealthKit write-back and wearable step sync** (users ask HealthifyMe and Hevy for it).
- **Exercise library depth and form media** for the top 100 lifts.

---

## 5. Moat analysis

| Candidate moat | Rating | Time for a funded competitor to copy | Evidence |
|---|---|---|---|
| **Catalogue: Indian foods with household measures, thali model, identity manifest, retired-duplicate handling** | **Weak → moderate** | 2–4 months | The engineering is good: identity manifest, never-deleted retired foods, regional packs. But breadth is 261 dishes and 312 are templated variants, some nonsensical (audit C-09); 6 rows have unit errors. HealthifyMe claims a far larger Indian DB and image model. |
| **"AI parses, catalogue computes"** | **Moderate (design), weak (today)** | 1–2 months for anyone with a food DB | The design yields auditable numbers and 0 % wrong auto-match in the 3 Oct text eval. But value depends on catalogue quality and conversions (probe: bowl, plate, grams fail). Pure-LLM apps draw "inaccurate" complaints (§ 4), but LLMs improve every quarter. |
| **Offline-first and privacy, no account** | **Moderate (business-model moat)** | Technically weeks; commercially unlikely | Competitors monetise through accounts, ads, upsell and coaching (§ 2). Removing those costs them revenue, so they won't. Weakness: no sync means switching phones is scary. Since 2026-10-06 the wording is "local-first logging, online-updated food data": training stays fully offline, food data updates over the network, and logs still never leave the phone. |
| **Serious set logger plus Indian nutrition in one app** | **Moderate** | 3–6 months (HealthifyMe adding a logger; Hevy adding nutrition) | Neither leader does both today (§ 3). One-tap set rows, carry-forward and a rest timer already match the Hevy and Strong basics. |
| **Data network effects** | **Weak today** | n/a | Everything is local, so nothing compounds across users. Per-user switching costs do compound: recents, frequents, usual thalis, last-set history, (future) vessel calibration. Backups are importable only into IndiFit. |

**Cheapest ways to deepen the strongest moats in the next 6 months**
1. **Make "your usual thali" the hero.** Fix C-01/02/03, then a one-tap usual thali per meal slot, learned from history (all local). It is personal and compounding, and LLM apps can't match it without your history.
2. **Vessel calibration.** One onboarding step: pick your katori, bowl and glass size from photos (or weigh once). Persist it (`household-measures` exists) and use it in the portion sheet *and* AI conversions. It's accuracy competitors don't have, and it stays private.
3. **Catalogue v2 with gram weights.** Fix the units and retire nonsense variants. Grow to ~600 dishes, with provenance shown. Rank Hinglish and regional names. *Updated 2026-10-06:* ship it as catalogue packs ([plan](../implementation/NUTRITION_CATALOGUE_PACKS_PLAN.md)), so content grows without app releases. IFCT 2017 (NIN) is not openly licensed and can't be copied in bulk. Use the INDB only if its authors grant permission (CAT-10); otherwise build dishes from recipes using CC0 (USDA) and OGL (UK CoFID) ingredient values (CAT-11).
4. **The privacy promise as product:**
   - "No account. No ads. Your data never leaves your phone unless you send it."
   - A data receipt screen that lists every network call type.
   - Guided encrypted export reminders.
5. **Lifter loop polish:** sticky rest bar, PR badges, plate maths (exists), a protein-per-kg nudge that ties nutrition to training (the unique combo). *Updated 2026-10-06:* factual "New best" sets (no estimates) and a weekly training goal ship in v1 during the closed test; the plan is [TRAINING_PROGRESS_PREMIUM_PLAN.md](../implementation/TRAINING_PROGRESS_PREMIUM_PLAN.md).

**Threats**
- HealthifyMe or cult.fit add a proper set logger.
- LLM photo apps get good at Indian plates. FitTrack AI-style apps are cheap to build: 1K+ installs today, but a template for others.
- MFP or Cronometer license an Indian DB.
- Google and Apple add native food logging.
- Firebase/Gemini price changes: current prices hold "through Dec 31, 2026" ([Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing)).
- App Check becomes mandatory 2 Nov 2026 ([Firebase](https://firebase.google.com/docs/ai-logic/app-check)).

---

## 6. Revenue model (after launch; v1 stays free)

### 6.1 Ground rules

- **No ads that use health data, and no data selling.** Apple 5.1.3(i) forbids using health and fitness data "for advertising, marketing, or other use-based data mining purposes" ([guidelines](https://developer.apple.com/app-store/review/guidelines/)). Google's Health Connect policy prohibits "using user health and fitness data for serving ads" and "selling … to data brokers" ([Play policy](https://support.google.com/googleplay/android-developer/answer/12991134)). Both would also break the offline/privacy promise, which is the moat.
- **Digital unlocks must use the store's IAP** (Apple 3.1.1).
- **India billing options:**
  - Play supports UPI Autopay for subscriptions ([Google, 2022-11-15](https://blog.google/intl/en-in/products/platforms/now-pay-for-subscriptions-via-upi-on-google-play/)).
  - Play runs a user-choice-billing program for India, with the service fee "reduced by 4%" ([Play help](https://support.google.com/googleplay/android-developer/answer/13821247)).
  - Apple India accepts UPI Autopay, cards or Apple Account balance ([Apple](https://support.apple.com/en-in/108110)).
- **Fees:**
  - Play: 15 % on auto-renewing subscriptions outside the regions on the new model ([Play](https://support.google.com/googleplay/android-developer/answer/112622)).
  - Apple Small Business Program: 15 % ([Apple](https://developer.apple.com/app-store/small-business-program/)).

### 6.2 What AI costs per user (estimate; assumptions marked)

**Inputs**
- Pricing: `gemini-3.8-flash` paid tier, **$0.75 / 1M input and $3.75 / 1M output tokens**, through Dec 31, 2026 ([pricing](https://ai.google.dev/gemini-api/docs/pricing)).
- Daily caps in code: text 30, photo 10, label 10 per device (`ai_daily_caps.dart:28`).
- Token counts: **estimated** from the prompts in `gemini_requests.dart` and image sizes (1,024 px meal, 2,048 px label). They are not measured.
- **Thinking tokens are unknown:** no `thinkingConfig` is set. So costs are shown as a range from no thinking to about 800 thinking tokens.
- Exchange rate assumption: **₹88 / US$**.

| Request | Est. input / output tokens | Cost per request |
|---|---|---|
| Describe a meal | ~450 / ~250 (+0–800 thinking) | **$0.0013–0.0043** (₹0.12–0.38) |
| Meal photo | ~1,300 / ~300 (+0–800) | $0.0021–0.0051 (₹0.18–0.45) |
| Label scan | ~1,900 / ~450 (+0–800) | $0.0031–0.0061 (₹0.27–0.54) |

**What that means**
- **Typical AI-active user:** 1.5 descriptions, 0.2 photos and 0.05 labels a day ≈ **$0.076–0.23 per month (₹6.7–20)**.
- **Abuse ceiling per device at the caps:** $0.09–0.24 per day = **$2.7–7.2 per month**.
- The current ₹950/month cap (~$10.8) covers only **~50–140 AI-active users**. Size it before launch (audit O-03).
- **Measure, don't guess:** log `usageMetadata` token counts in the eval run.

### 6.3 Options

| Option | Free vs paid | Price (anchors) | Billing | Run cost | Code and architecture | Privacy | Retention / rating risk |
|---|---|---|---|---|---|---|---|
| **A. Freemium subscription "IndiFit Plus"** | Free: all logging, catalogue, thali, player, backups, 3 AI uses/day. Plus: unlimited AI (fair-use caps), photo and label AI, advanced progress analytics, program builder; later **E2E-encrypted cloud backup/sync** | **₹99/mo · ₹699/yr** (US$2.99 / $19.99). Below Hevy Pro ₹249/mo · ₹1,999/yr and MFP ₹619/mo; Cronometer ₹999/mo; HealthifyMe Healthify+ ₹499 (§ 2) | Play Billing (UPI Autopay), App Store IAP; regional pricing | AI ≤ ₹20/user/mo (§ 6.2), net after the 15 % fee ≈ ₹84/mo, so a healthy margin | Entitlement service (StoreKit 2 + Play Billing via `in_app_purchase`); a paywall screen; receipt validation (server-side via a small Cloud Function, or on-device StoreKit 2 / Play Integrity); feature flags; restore purchases | Purchase receipts go to Apple/Google; validation needs a server call (disclose it). The no-account model holds: entitlements are tied to the store account. | Medium: a paywall can cost stars (§ 4 shows paywall creep is the #2 complaint). Mitigate by never paywalling what was free; Plus adds only new value. |
| **B. One-time "Pro" unlock** | Same as A, minus recurring AI | ₹1,499–1,999 lifetime (Hevy ₹6,500, Strong ₹7,900, Lose It ₹5,900) | Non-consumable IAP | AI runs forever on a one-off payment, so it needs AI fair-use caps or exclusion | Same entitlement work, simpler | Same | Low rating risk; revenue lumpy; AI cost tail unbounded |
| **C. AI credit packs** | Free AI allowance; buy packs (e.g. 200 scans) | ₹49 / 200 describes; ₹99 / 100 photos | Consumable IAP | Pay-as-you-go matches cost | Credit ledger on device plus server checks (otherwise trivially edited) | Needs a server-side ledger per install (App Check ID) | Users dislike metered nutrition logging; confusing |
| **D. Coach/creator programs (revenue share)** | Free player; paid programs by Indian coaches | ₹299–₹999 per program (FITTR coach SKUs ₹7,599 are coaching, not programs) | Non-consumable IAP; payouts outside the store | Low | Program import format (exists: plans and versions), creator onboarding, payout ops, content review | Programs are content only; no user data shared | Brand risk from creator quality; ops heavy for a solo dev |
| **E. B2B: gyms, dietitians, corporate wellness** | Free app; paid dashboard for the coach or org | ₹X per seat per month (no source; needs discovery) | Invoices / UPI outside the stores (no digital unlock in-app) | Server, auth, support | **Breaks no-account**: needs accounts, sharing consent, a backend (WS6 part B) | DPDP consent for sharing with the coach; a big policy change | High effort; distracts from consumer PMF |

### 6.4 Recommendation: Option A (freemium "IndiFit Plus"), staged

| Stage | When | What | Gate metrics (must be true to proceed) |
|---|---|---|---|
| **1. Launch** | Nov 2026 | Free; no paywall. Instrument using **store-provided** retention (Play Console and App Store Connect cohorts) plus an opt-in, local-first event counter (no third-party SDK). Keep the AI daily caps. | Crash-free ≥ 99.5 %; Play rating ≥ 4.4; AI cost/active user measured |
| **2. Plus** | ~Feb 2027 (3 months) | Launch Plus at ₹99/mo · ₹699/yr (US$2.99 / $19.99) with photo and label AI, unlimited describe (fair use), analytics, program builder. Free keeps 3 AI uses a day forever. | D30 retention ≥ 15 % *(target, not a market fact)*; AI cost ≤ ₹10 per AI-active user per month; ≥ 25 % of WAU use AI weekly |
| **3. Sync and programs** | ~Oct 2027 (12 months) | E2E-encrypted cloud backup and sync in Plus (zero-knowledge keys; the backend needs WS6 part B). Optionally curated coach programs (Option D) inside Plus. | Plus conversion ≥ 2–3 % of MAU *(target)*; refund rate < 5 %; rating holds ≥ 4.4 |

**Why A:**
- It matches cost (AI is the only variable cost) to revenue.
- It keeps the "no account, no ads" promise.
- It prices below every cited competitor.
- It never takes away a free feature, which avoids the #2 complaint cluster.

### 6.5 Decided (Ayush, 2026-10-06)

**Timing is Ayush's call.** The dates and gate metrics in § 6.4 are advice, not rules. Plus can launch whenever Ayush chooses; launching before retention data exists just means pricing with less evidence.

- **Stage 1 adds a supporter tip jar** (roadmap PR-T): consumable in-app purchases that unlock nothing, so there's no rating risk. It starts revenue and shows who the paying fans are.
- **Stage 2, Plus (about Feb 2027 was the suggestion), offers both** a subscription (₹99/mo · ₹699/yr) and a **lifetime option** at about 3× the annual price (about ₹1,999), for people who refuse subscriptions.
  - Lifetime still has AI fair-use caps, because AI is the only cost that runs forever.
- **The free/Plus line is fixed now,** because anything shipped free can't move later.
  - **Always free:** logging, thali, catalogue packs, bests, the weekly goal, reminders, the home widget, backups.
  - **Plus:**
    - photo and label AI;
    - unlimited describe (fair use);
    - muscles-this-week map, consistency heatmap and period comparison (training plan TP-9);
    - program builder;
    - encrypted sync (stage 3).
- **AI cost fallback** (being investigated by Ayush): a cheaper model through the existing `ai_model` Remote Config key, only after it passes the eval.

