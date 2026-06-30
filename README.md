# IndiFit 🏋️

IndiFit is an offline-first, AI-powered gym tracker and nutrition planner tailored for Indian food and training habits.

## Key Features
- **Offline-First Storage**: Powered by Drift (SQLite) to log workouts, track body stats, search food, and manage rest timers 100% offline.
- **Indian Food Database**: Auto-seeded on first install with 500+ common Indian dishes and macros (Whole wheat roti, Dal tadka, Paneer butter masala, Rajma chawal, Chole, etc.).
- **FastAPI AI Integration**: Proxied server-side calls utilizing Gemini (free/multimodal) and DeepSeek V4-Flash to build onboarding programs, estimate food via photo/text descriptions, and compile weekly report summaries.
- **Interactive Workout Player**: Responsive set counters, haptic circular countdown rest timers, and personal record confetti celebrations.

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
5. In **Bundle Identifier**, change the package suffix slightly if there's a conflict (e.g., change `com.indifit.IndiFit` to `com.indifit.IndiFitDev`).

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
> **Free Account Limits**: Apple allows personal developer accounts to sideload up to 3 apps per device. The app certificate will expire after **7 days**, after which you just need to re-plug your iPhone and click Play in Xcode again to renew it.

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
- **Routing**: GoRouter (`go_router`)
- **Local Cache & Storage**: Drift SQLite Database (`drift` + `sqlite3_flutter_libs`)
- **Backend API Sync**: Supabase Client SDK (`supabase_flutter`)
- **Networking**: Dio Client (`dio`)
- **Icons**: Lucide Icons
- **Visuals**: Lottie animations + Fl Chart
