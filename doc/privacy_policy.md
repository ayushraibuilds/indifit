# Privacy Policy for IndiFit

**Effective Date:** August 29, 2026
**App Version:** 1.0.0

IndiFit ("we", "our", or "us") is an offline-first workout and nutrition application. This policy explains what the V1 application stores, which optional features can connect to other services, and the controls available to you.

---

## 1. Information stored by IndiFit

- **Local app data:** Food logs, custom foods and recipes, workout plans and history, body measurements, preferences, and related fitness records are stored in IndiFit's application storage on your device.
- **No IndiFit account or cloud sync:** V1 does not provide an IndiFit account, remote user database, or cloud-sync service.
- **Automatic recovery copies:** IndiFit creates rolling JSON recovery copies in its application Documents area. Depending on your operating-system and device-backup settings, application files may be included in a device backup.

IndiFit does not upload your workout history, body measurements, or health records to a cloud service. Connected nutrition tools (nutrition label scanning and natural-language meal parsing) process queries and label images ephemerally over encrypted connections when you choose to use them; label images are deleted immediately after OCR extraction and are never retained on remote servers.

---

## 2. Optional network features

Core logging and review features work offline. When Offline Mode is off, these optional features may connect to external services:

- **Open Food Facts:** If you deliberately use online food search or scan a packaged-food barcode, IndiFit sends the search text or barcode needed to request product information from Open Food Facts. IndiFit does not attach an IndiFit backend credential or your local logs to that request.
- **Nutrition-Label OCR & Natural-Language Meal Logging:** When you choose to scan a nutrition facts label or describe a meal in natural text, IndiFit securely sends the label image or text query to extract structured nutrition facts. Label images are processed ephemerally and deleted immediately. All suggestions require explicit user review and confirmation before logging.
- **Crash diagnostics:** If you affirmatively enable crash diagnostics, technical error information may be sent to our diagnostics provider. See section 4.

Turning on Offline Mode blocks app-initiated online food lookups and crash diagnostics.

---

## 3. Health Connect and HealthKit

Health connections are optional and require platform permission. Depending on the platform and the categories you approve, IndiFit may read steps, active energy, sleep sessions, resting heart rate, and activity sessions, and may write weight entries you choose to save.

Health-platform data is exchanged between IndiFit and the health service on your device. IndiFit V1 does not send this information to an IndiFit server.

You can revoke Health Connect or HealthKit access through the relevant system settings.

---

## 4. Diagnostics and crash telemetry

Crash diagnostics are optional and off by default. If enabled, a diagnostic report may contain technical information such as the app version, device and operating-system details, a stack trace, and an exception message. IndiFit does not intentionally attach your food logs, workout history, health records, or profile fields to diagnostic events.

Offline Mode disables crash diagnostics.

---

## 5. Backups, sharing, and export

- **Manual backup:** You can create a JSON backup and choose where to share or save it. Password protection is optional; a backup created without a password is not encrypted by IndiFit.
- **Automatic recovery copy:** Up to three local recovery copies may be retained in application storage. These are intended for in-app recovery and are not password-protected in V1.
- **CSV summary:** You can copy a summary of logged food and workouts to the system clipboard as CSV text. Other applications may be able to read clipboard content according to operating-system rules.

Files or text that you deliberately share, save elsewhere, or copy to the clipboard are controlled by the destination you choose and are no longer solely controlled by IndiFit.

---

## 6. Deletion and user control

You can erase supported IndiFit records from the app's data controls. Uninstalling IndiFit or clearing its application data removes active local application data subject to operating-system behavior. Copies you previously exported, shared, or retained in a device backup must be deleted separately from those locations.

---

## 7. Contact us

If you have questions about this policy or IndiFit's privacy behavior, contact:
`privacy@indifit.app`
