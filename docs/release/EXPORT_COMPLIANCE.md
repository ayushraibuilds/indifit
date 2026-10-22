# Export compliance (N14-17)

**Status: reasoning for the owner to confirm. This is not legal advice.**

`ios/Runner/Info.plist` sets `ITSAppUsesNonExemptEncryption` to `false`, so App Store Connect doesn't ask the encryption questions on each upload.

## What the app encrypts

- **Backups** (`lib/core/utils/encryption_helper.dart`): AES-256-GCM with a key derived by PBKDF2-HMAC-SHA256 from the user's own password or a device recovery key. It protects the user's own data at rest in a file they export or keep. It doesn't secure communication with anyone else, and nobody but the user can decrypt it.
- **Network**: HTTPS/TLS through the OS and Firebase SDKs (AI, App Check, Hosting food packs). The app doesn't implement its own transport crypto.

## Why that reads as exempt

- Apple's export compliance guidance and the US EAR (Category 5 Part 2, Note 4 and the 740.17(b)(1) "mass market" cases) treat encryption limited to authentication, standard OS-provided HTTPS, and protecting the user's own data or files ("data at rest" for the user's own use) as exempt or not requiring documentation.
- IndiFit has no messaging, VPN, or other feature whose main purpose is encrypting communication between parties.

## What would change the answer

- End-to-end encrypted sharing or sync between users, a custom transport protocol, or proprietary (non-standard) algorithms.
- Cloud backup that stores encrypted user data on IndiFit servers is still the user's own data; re-check the guidance when it ships.

If any of these land, revisit the key and, if needed, file the annual self-classification report.

## Android

Google Play has no matching per-upload declaration; the same reasoning covers the Play distribution.

## Related: ACTIVITY_RECOGNITION removed (N14-17)

The `health` plugin is 11.1.1, which dropped Google Fit (CHANGELOG 11.0.0) and reads only through Health Connect. The app requests STEPS, ACTIVE_ENERGY_BURNED, SLEEP_SESSION, RESTING_HEART_RATE, WORKOUT and WEIGHT (`lib/data/repositories/health_service.dart`); Health Connect grants each through its own `android.permission.health.*` permission, already in the manifest. `ACTIVITY_RECOGNITION` was a Google Fit requirement (the plugin README still mentions it), nothing in `lib/` requests it at runtime, so it was removed from `android/app/src/main/AndroidManifest.xml`.
