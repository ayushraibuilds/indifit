# IndiFit — App Store & Google Play Store Listing Copy

> **AI lines:** the "Optional AI meal tools" section, the AI mentions under Privacy and portability, the Camera, Photos and Internet rows, and the AI rows in section 5 describe the AI meal tools, which v1 store builds ship with (release builds have them on by default). Remove these lines only for a build made with `--dart-define=INDIFIT_CONNECTED_AI=false`.

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

- 243 Indian dishes built in, with size and oil variants, plus 25 more in optional regional packs.
- Local food search, custom foods, recipes and saved meals.
- Nutrition facts retain their source and completeness information.
- Group multiple dishes into a meal while keeping each logged item reviewable.
- Optional Open Food Facts search and barcode lookup when Offline Mode is off.

### Optional AI meal tools

- Describe a meal in your own words, Hinglish included ("2 roti aur ek katori dal"). IndiFit matches each food to its own catalogue and shows portions you can adjust.
- Photograph a packaged food's nutrition label to save it as a custom food from the printed values.
- Meal photo (Beta): photograph your plate and review the foods and portions it suggests.
- Nothing is logged until you review it.
- IndiFit asks for your consent before first use. Only the text you type or the photo you choose is sent, through Google Firebase, to Google's Gemini AI. You can withdraw consent in Settings → Manage your data → AI meal assistance.
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
- Offline Mode blocks app-initiated online food lookup, food database updates, the AI meal tools and crash diagnostics.
- Create and restore JSON backups; optional password protection is available for manual backup files.
- Copy a food and workout CSV summary when you choose.
- Automatic rolling recovery copies are kept in the app's local storage.

IndiFit does not generate meal plans, workouts or reports.

---

## 4. Store permission justifications

| Permission | Purpose |
|---|---|
| **Camera** | Used only when you choose to scan a packaged-food barcode, photograph a nutrition label or take a meal photo. |
| **Photos (iOS)** | Used only when you choose a nutrition-label or meal photo from your library. |
| **Notifications** | Used for optional workout, meal-logging and progress reminders you enable. |
| **Activity / Health** | Used only for the Health Connect or HealthKit categories you approve. |
| **Internet** | Used for food database updates, optional Open Food Facts lookup, the optional AI meal tools and opt-in crash diagnostics. Core logging remains available offline. |

---

## 5. App Privacy (App Store) and Data safety (Google Play)

What leaves the device, for filling in both forms. `ios/Runner/PrivacyInfo.xcprivacy` declares the same data types. None of it is linked to the user's identity or used for tracking, and none of it is sold.

| Data | Category (Apple / Google) | When | Recipient | Purpose |
|---|---|---|---|---|
| Typed meal descriptions | Other User Content / Other user-generated content | Only when the user uses Describe a meal, after consent | Google (Gemini via Firebase) | App functionality |
| Meal and nutrition-label photos | Photos or Videos / Photos | Only when the user takes a meal photo or scans a label, after consent | Google (Gemini via Firebase) | App functionality |
| Installation identifier (Firebase Installations ID, App Check token) | Device ID / Device or other IDs | From the first AI request, while the AI tools are available | Google (Firebase) | App functionality |
| App interaction with Firebase (Remote Config fetches) | Product Interaction / App interactions | From the first AI request, while the AI tools are available | Google (Firebase) | App functionality |
| Technical diagnostics from the Firebase SDKs | Other Diagnostic Data / Diagnostics | From the first AI request, while the AI tools are available | Google (Firebase) | App functionality |
| Crash logs | Crash Data / Crash logs | Only if the user turns on crash diagnostics | Sentry | App functionality |

Supporter tips (Settings → Support IndiFit) are consumable in-app purchases that unlock nothing. Apple or Google processes the payment; IndiFit receives no card details, has no server, and sends no purchase record anywhere. Under Apple's rules ("you are not responsible for disclosing data collected by Apple"; payment info entered outside the app "is not collected") and Google's (no declaration for data the billing system collects when the app never accesses it), neither form needs a Purchases or Payment info entry, so `PrivacyInfo.xcprivacy` adds none. Revisit this if tips are ever sent to a server or crash reports.

Not collected: account details, health and fitness records, food and workout logs, body measurements, location and contacts. These stay on the device. Barcode and food-search lookups send only the barcode or search text to Open Food Facts.

Data is encrypted in transit (HTTPS). Users can delete their on-device data from the app's data controls. IndiFit stores no AI requests itself; Google may keep them for a limited period to detect abuse, under the Gemini API terms.

The Firebase rows follow Firebase's own disclosure guides ([App Store](https://firebase.google.com/docs/ios/app-store-data-collection), [Play](https://firebase.google.com/docs/android/play-data-disclosure)); re-check them when filling in the forms.
