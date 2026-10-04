# IndiFit — App Store & Google Play Store Listing Copy

> **AI lines:** the "Optional AI meal tools" section, the AI mentions under Privacy and portability, the Camera, Photos and Internet rows, and the AI rows in section 5 apply only to store builds made with `--dart-define=INDIFIT_CONNECTED_AI=true`. Remove them for a build without AI.

## 1. Store titles

- **App title:** IndiFit — Indian Fitness App
- **iOS subtitle:** Offline Workout & Food Log

---

## 2. Android short description

Track Indian foods, workouts and progress with private, offline-first logging.

---

## 3. Full description

**IndiFit is an offline-first workout and nutrition tracker built for Indian diets and training routines.**

Log home-cooked meals, follow structured training plans, record completed sets and review progress without creating an online account. Your core records stay in the app's storage on your device.

### Indian nutrition logging

- 535 Indian foods built in, plus 25 more in optional regional packs.
- Local food search, custom foods, recipes and saved meals.
- Nutrition facts retain their source and completeness information.
- Group multiple dishes into a meal while keeping each logged item reviewable.
- Optional Open Food Facts search and barcode lookup when Offline Mode is off.

### Optional AI meal tools

- Describe a meal in your own words, Hinglish included ("2 roti aur ek katori dal"). IndiFit matches each food to its own catalogue and shows portions you can adjust.
- Photograph a packaged food's nutrition label to save it as a custom food from the printed values.
- Nothing is logged until you review it.
- IndiFit asks for your consent before first use. Only the text you type or the label photo you take is sent, through Google Firebase, to Google's Gemini AI. You can withdraw consent in Settings → Privacy.
- Needs an internet connection; switched off in Offline Mode.

### Workout planning and execution

- Choose or author a training plan.
- Guided workout execution with working and warm-up sets, rest timers and RPE logging.
- Record substitutions and unscheduled workouts without losing history.
- Review workout history, training volume and comparable strength progress.

### Progress and device health

- Track body weight and measurements over time.
- Review factual workout, activity and nutrition summaries.
- Optionally connect supported Health Connect or HealthKit categories after granting permission.

### Privacy and portability

- Core logging and review work without a network connection or IndiFit account.
- Offline Mode blocks app-initiated online food lookup, the AI meal tools and crash diagnostics.
- Create and restore JSON backups; optional password protection is available for manual backup files.
- Copy a food and workout CSV summary when you choose.
- Automatic rolling recovery copies are kept in the app's local storage.

IndiFit does not generate meal plans, workouts or reports.

---

## 4. Store permission justifications

| Permission | Purpose |
|---|---|
| **Camera** | Used only when you choose to scan a packaged-food barcode or photograph a nutrition label. |
| **Photos (iOS)** | Used only when you choose a nutrition-label photo from your library. |
| **Notifications** | Used for optional workout, meal-logging and progress reminders you enable. |
| **Activity / Health** | Used only for the Health Connect or HealthKit categories you approve. |
| **Internet** | Used for optional Open Food Facts lookup, the optional AI meal tools and opt-in crash diagnostics. Core logging remains available offline. |

---

## 5. App Privacy (App Store) and Data safety (Google Play)

What leaves the device, for filling in both forms. `ios/Runner/PrivacyInfo.xcprivacy` declares the same data types. None of it is linked to the user's identity or used for tracking, and none of it is sold.

| Data | Category (Apple / Google) | When | Recipient | Purpose |
|---|---|---|---|---|
| Typed meal descriptions | Other User Content / Other user-generated content | Only when the user uses Describe a meal, after consent | Google (Gemini via Firebase) | App functionality |
| Nutrition-label photos | Photos or Videos / Photos | Only when the user scans a label, after consent | Google (Gemini via Firebase) | App functionality |
| Crash logs | Crash Data / Crash logs | Only if the user turns on crash diagnostics | Sentry | App functionality |

Not collected: account details, health and fitness records, food and workout logs, body measurements, location and contacts. These stay on the device. Barcode and food-search lookups send only the barcode or search text to Open Food Facts.

Data is encrypted in transit (HTTPS). Users can delete their on-device data from the app's data controls. IndiFit stores no AI requests itself; Google's retention is set by the Gemini API terms.
