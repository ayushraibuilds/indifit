# IndiFit 🏋️

IndiFit is an offline-first workout and nutrition tracker tailored for Indian food and training habits.

## Key Features
- **Offline Core**: Drift (SQLite) stores workouts, nutrition logs, body measurements, plans, preferences, and recovery copies on the device. Core logging and review flows work without a network connection.
- **Indian Food Catalogue**: The app bundles 573 base food entries and 25 optional regional-pack entries with nutrition facts and provenance metadata.
- **Optional Online Food Lookup**: When Offline Mode is off, users can deliberately search or scan packaged foods through Open Food Facts. Local results remain available if the provider cannot be reached.
- **Interactive Workout Player**: Responsive set counters, haptic circular countdown rest timers, and personal record confetti celebrations.
- **Progress & Health Connections**: Review recorded workout/nutrition trends and optionally connect supported Health Connect or HealthKit categories.
- **Portable Data**: Create and restore JSON backups, optionally protect manual backup files with a password, and copy a food/workout CSV summary.

## Post-V1 Capability Contract

IndiFit is local-first, not offline-only. Core logging, workout player, and local database remain 100% offline functional, while connected features (nutrition-label OCR and natural-language meal logging) act as optional, reviewable accelerators.

---

## Testing on iOS WITHOUT a Paid Apple Developer Account

Since you do not have a paid Apple Developer account ($99/year), you can use the **Free Personal Provisioning** feature in Xcode to sideload and test IndiFit directly on your physical iPhone.

### Step 1: Connect your iPhone to your Mac
1. Use a lightning/USB-C cable to connect your iPhone to your Mac.
2. If prompted on your iPhone, tap **Trust This Computer** and enter your passcode.

### Step 2: Open the Project in Xcode
1. Run this command in your terminal to prepare the iOS workspace:
   ```bash
   flutter build ios --no-codesign
   ```
2. Open the Xcode workspace:
   ```bash
   open ios/Runner.xcworkspace
   ```

### Step 3: Configure Personal Signing Team
1. In the left navigation pane of Xcode, select the **Runner** root project.
2. Go to the **Signing & Capabilities** tab.
3. Check the **Automatically manage signing** box.
4. Under **Team**, select your Apple ID (Personal Team). 
   - *If your Apple ID is not listed, click "Add an Account..." and log in with your normal iCloud email/password (no developer fee required).*
5. The public-release bundle identifier is `com.indifit.indifit` and must not change after store registration. For personal-device development only, use a clearly separate identifier such as `com.indifit.indifit.dev` if Apple's portal reports a conflict; never archive that development identity for distribution.

### Step 4: Enable Developer Mode on your iPhone
1. On your iPhone, go to **Settings** > **Privacy & Security**.
2. Scroll to the bottom and tap **Developer Mode**.
3. Toggle the switch ON, and restart your iPhone.
4. After restarting, unlock your phone and tap **Turn On** when prompted.

### Step 5: Run from Xcode
1. In Xcode's top toolbar, select your **Physical iPhone** as the active destination device.
2. Click the **Play** button (or press `Cmd + R`) to build and run the app.
3. The app will compile and install on your iPhone.
4. *Note: Before opening the app for the first time, you may need to go to iPhone **Settings** > **General** > **VPN & Device Management**, tap your Apple ID email under "Developer App", and click **Trust**.*

> [!NOTE]
> **Free Account Limits**: Apple allows personal developer accounts to sideload up to 3 active apps per device. The app certificate expires after **7 days**, after which you re-run from Xcode to renew it. Because WidgetKit extensions (like `RestTimerWidgetExtension`) use an embedded bundle identifier (`com.indifit.indifit.RestTimerWidget`), ensure both the **Runner** and **RestTimerWidgetExtension** targets are signed with your Personal Team. Each extension target consumes one App ID slot against Apple's free 10 App ID limit.

---

## Sideloading on Android (APK)

Testing on Android is completely free and does not expire:
1. Build the APK file:
   ```bash
   flutter build apk --release
   ```
2. Sideload the APK file located at `build/app/outputs/flutter-apk/app-release.apk` to your phone via USB or shared drive and install it!

---

## Technical Stack
- **State Management**: Riverpod (`flutter_riverpod`)
- **Local Cache & Storage**: Drift SQLite Database (`drift` + `sqlite3_flutter_libs`)
- **Backend Sync**: Local-only for v1 (Cloud sync planned for future versions)
- **Optional Networking**: Open Food Facts lookup and opt-in crash diagnostics, both blocked by Offline Mode
- **Visuals**: Lottie animations + Fl Chart
