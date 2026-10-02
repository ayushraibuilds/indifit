# Privacy Policy for IndiFit

**Effective Date:** August 29, 2026
**Last Updated:** October 2, 2026
**App Version:** 1.0.0

IndiFit ("we", "our", or "us") is an offline-first workout and nutrition application. This policy explains what the V1 application stores, which optional features can connect to other services, and the controls available to you.

---

## 1. Information stored by IndiFit

- **Local app data:** Food logs, custom foods and recipes, workout plans and history, body measurements, preferences, and related fitness records are stored in IndiFit's application storage on your device.
- **No IndiFit account or cloud sync:** V1 does not provide an IndiFit account, remote user database, or cloud-sync service.
- **Automatic recovery copies:** IndiFit creates rolling JSON recovery copies in its application Documents area. Depending on your operating-system and device-backup settings, application files may be included in a device backup.

IndiFit does not upload your workout history, body measurements, or health records to a cloud service. The optional AI meal tools send only the text or photo you choose to submit; see section 3.

---

## 2. Optional network features

Core logging and review features work offline. When Offline Mode is off, these optional features may connect to external services:

- **Open Food Facts:** If you deliberately use online food search or scan a packaged-food barcode, IndiFit sends the search text or barcode needed to request product information from Open Food Facts. IndiFit does not attach an IndiFit backend credential or your local logs to that request.
- **AI meal tools:** Describe-a-meal, meal-photo and nutrition-label scanning send the text or photo you submit to Google's Gemini AI. They are used only after you consent; see section 3.
- **Crash diagnostics:** If you affirmatively enable crash diagnostics, technical error information may be sent to our diagnostics provider. See section 5.

Turning on Offline Mode blocks app-initiated online food lookups, the AI meal tools, and crash diagnostics.

---

## 3. AI meal tools (Google Gemini)

The AI meal tools are optional. IndiFit asks for your consent before first use and again if what is sent, or to whom, changes.

- **What is sent:** Only the meal description you type, or the meal or nutrition-label photo you choose. IndiFit does not send your diary, profile, body measurements or health data with these requests.
- **Who receives it:** Google, which runs the Gemini models through Google Firebase. Google processes the request to return a result. Its handling of that data is governed by the [Gemini API Additional Terms of Service](https://ai.google.dev/gemini-api/terms) and [Firebase privacy information](https://firebase.google.com/support/privacy).
- **What IndiFit keeps:** IndiFit does not store your photos or descriptions. The app shows the AI's suggestions for you to review, and only the foods you confirm are saved, on your device.
- **Your choices:** You can withdraw consent at any time in Settings → Privacy → AI meal assistance; the app will ask again before any further AI use. Food search and manual logging work without AI.

---

## 4. Health Connect and HealthKit

Health connections are optional and require platform permission. Depending on the platform and the categories you approve, IndiFit may read steps, active energy, sleep sessions, resting heart rate, and activity sessions, and may write weight entries you choose to save.

Health-platform data is exchanged between IndiFit and the health service on your device. IndiFit V1 does not send this information to an IndiFit server.

You can revoke Health Connect or HealthKit access through the relevant system settings.

---

## 5. Diagnostics and crash telemetry

Crash diagnostics are optional and off by default. If enabled, a diagnostic report may contain technical information such as the app version, device and operating-system details, a stack trace, and an exception message. IndiFit does not intentionally attach your food logs, workout history, health records, or profile fields to diagnostic events.

Offline Mode disables crash diagnostics.

---

## 6. Backups, sharing, and export

- **Manual backup:** You can create a JSON backup and choose where to share or save it. Password protection is optional; a backup created without a password is not encrypted by IndiFit.
- **Automatic recovery copy:** Up to three local recovery copies may be retained in application storage. These are intended for in-app recovery and are not password-protected in V1.
- **CSV summary:** You can copy a summary of logged food and workouts to the system clipboard as CSV text. Other applications may be able to read clipboard content according to operating-system rules.

Files or text that you deliberately share, save elsewhere, or copy to the clipboard are controlled by the destination you choose and are no longer solely controlled by IndiFit.

---

## 7. Deletion and user control

You can erase supported IndiFit records from the app's data controls. Uninstalling IndiFit or clearing its application data removes active local application data subject to operating-system behavior. Copies you previously exported, shared, or retained in a device backup must be deleted separately from those locations.

---

## 8. Contact us

If you have questions about this policy or IndiFit's privacy behavior, contact:
`privacy@indifit.app`
