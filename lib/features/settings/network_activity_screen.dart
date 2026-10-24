import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/consumer_date_label.dart';
import '../../core/privacy/network_receipt.dart';
import '../../core/privacy/privacy_policy.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import 'food_database_screen.dart';

/// The preferences the receipt reads; null until they load.
final networkReceiptPrefsProvider =
    FutureProvider.autoDispose<SharedPreferences>(
      (ref) async =>
          sharedPreferencesOrNull(() => ref.read(sharedPreferencesProvider)) ??
          await SharedPreferences.getInstance(),
    );

/// One kind of call on the receipt: what it sends, in plain words, and the
/// switch that controls it.
class NetworkActivityRow {
  const NetworkActivityRow({
    required this.kind,
    required this.title,
    required this.sends,
    required this.switchLabel,
    required this.switchOnThisScreen,
  });

  final NetworkCallKind kind;
  final String title;
  final String sends;
  final String switchLabel;

  /// The switch is on Manage your data, so the link goes back there;
  /// otherwise it opens Food database.
  final bool switchOnThisScreen;

  static const all = [
    NetworkActivityRow(
      kind: NetworkCallKind.foodLookup,
      title: 'Food lookup and barcode',
      sends:
          'The food you search for, or the barcode you scan, to IndiFit and '
          'Open Food Facts. Not your diary or who you are.',
      switchLabel: 'Offline mode',
      switchOnThisScreen: true,
    ),
    NetworkActivityRow(
      kind: NetworkCallKind.foodDatabase,
      title: 'Food database updates',
      sends:
          'Asks IndiFit for the newest food list and downloads it. Sends '
          'nothing about you.',
      switchLabel: 'Food updates on Wi-Fi only',
      switchOnThisScreen: false,
    ),
    NetworkActivityRow(
      kind: NetworkCallKind.ai,
      title: 'AI (describe, photo, label)',
      sends:
          'The meal you describe, or the photo of your meal or label, to '
          'Google Gemini to estimate it. IndiFit keeps no photo.',
      switchLabel: 'AI consent',
      switchOnThisScreen: true,
    ),
    NetworkActivityRow(
      kind: NetworkCallKind.tipJar,
      title: 'Tip jar',
      sends:
          'Asks the App Store or Google Play for tip prices, and the '
          'purchase when you tip. Only when you open the tip jar.',
      switchLabel: 'Offline mode',
      switchOnThisScreen: true,
    ),
    NetworkActivityRow(
      kind: NetworkCallKind.crashReports,
      title: 'Crash reports',
      sends:
          'What went wrong and where in the app, with food, weights and '
          'names removed. Only if you turned it on.',
      switchLabel: 'Share crash diagnostics',
      switchOnThisScreen: true,
    ),
  ];
}

/// "Last ran Today · 14:05", "Never", or that Offline Mode blocks it.
String networkActivityStatus(
  DateTime? lastRan, {
  required bool offline,
  DateTime? today,
}) {
  final ran = lastRan == null
      ? 'Never'
      : 'Last ran ${ConsumerDateLabel.dateTime(lastRan, today: today)} · '
            '${DateFormat.Hm().format(lastRan.toLocal())}';
  return offline ? '$ran · Blocked by Offline mode' : ran;
}

/// Settings → Manage your data → Network activity (UF-21): one row per
/// kind of call the app makes.
class NetworkActivityScreen extends ConsumerWidget {
  const NetworkActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(networkReceiptPrefsProvider).valueOrNull;
    final offline = ref.watch(
      privacyPolicyProvider.select((policy) => policy.isOfflineOnly),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Network activity')),
      body: ListView(
        padding: const EdgeInsets.all(B05Layout.space16),
        children: [
          Text(
            'Everything IndiFit sends over the internet, and when it last '
            'did. Your diary and workouts stay on this phone.',
            style: B05Typography.body(context),
          ),
          for (final row in NetworkActivityRow.all) ...[
            const SizedBox(height: B05Layout.space12),
            B05Surface(
              key: ValueKey('network_row_${row.kind.id}'),
              padding: const EdgeInsets.all(B05Layout.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.title, style: B05Typography.label(context)),
                  const SizedBox(height: B05Layout.space4),
                  Text(row.sends, style: B05Typography.body(context)),
                  const SizedBox(height: B05Layout.space4),
                  Text(
                    networkActivityStatus(
                      prefs == null
                          ? null
                          : NetworkReceipt.lastRan(prefs, row.kind),
                      offline: offline,
                    ),
                    key: ValueKey('network_status_${row.kind.id}'),
                    style: B05Typography.caption(context),
                  ),
                  TextButton(
                    key: ValueKey('network_switch_${row.kind.id}'),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => row.switchOnThisScreen
                        ? Navigator.of(context).pop()
                        : Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const FoodDatabaseScreen(),
                            ),
                          ),
                    child: Text(row.switchLabel),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
