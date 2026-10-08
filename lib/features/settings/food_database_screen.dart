import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_links.dart';
import '../../core/privacy/privacy_policy.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/catalog/catalog_update_service.dart';
import '../food_log/missed_food_searches.dart';
import 'food_data_credits.dart';
import 'food_database_providers.dart';
import 'widgets/settings_reminder_toggle.dart';

/// Settings → Food database (CAT-7): what is installed, when it was last
/// checked, the update controls and where the values come from.
class FoodDatabaseScreen extends ConsumerStatefulWidget {
  const FoodDatabaseScreen({super.key});

  @override
  ConsumerState<FoodDatabaseScreen> createState() => _FoodDatabaseScreenState();
}

class _FoodDatabaseScreenState extends ConsumerState<FoodDatabaseScreen> {
  bool _checking = false;

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await ref.read(catalogUpdateServiceProvider).checkNow();
    if (!mounted) return;
    setState(() => _checking = false);
    ref.invalidate(catalogStatusProvider);
    messenger?.showSnackBar(
      SnackBar(content: Text(FoodDatabaseCopy.checkMessage(result))),
    );
  }

  Future<void> _setAllowMobileData(bool value) async {
    await ref.read(catalogUpdateServiceProvider).setAllowMobileData(value);
    ref.invalidate(catalogStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(catalogStatusProvider);
    final offline = ref.watch(privacyPolicyProvider).isOfflineOnly;
    return Scaffold(
      appBar: AppBar(title: const Text('Food database')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: status.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Padding(
                padding: const EdgeInsets.all(B05Layout.space20),
                child: B05StatusMessage(
                  status: B05SemanticStatus.warning,
                  label: 'The food database details could not be read.',
                ),
              ),
              data: (status) => _content(context, status, offline),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, CatalogStatus status, bool offline) {
    final canCheck = status.updatesAvailableInBuild && !offline && !_checking;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        B05Surface(
          key: const Key('food_database_installed'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.version == null
                    ? 'No food database installed'
                    : 'Version ${status.version}',
                style: B05Typography.title(context),
              ),
              if (status.installedAt != null) ...[
                const SizedBox(height: B05Layout.space4),
                Text(
                  FoodDatabaseCopy.installedLine(
                    status.installedAt!,
                    status.source,
                  ),
                  style: B05Typography.body(context),
                ),
              ],
              const SizedBox(height: B05Layout.space4),
              Text(
                FoodDatabaseCopy.foodCountLine(status),
                key: const Key('food_database_food_count'),
                style: B05Typography.body(context),
              ),
              const SizedBox(height: B05Layout.space4),
              Text(
                FoodDatabaseCopy.lastCheckLine(status.lastCheckAt),
                key: const Key('food_database_last_check'),
                style: B05Typography.body(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: B05Layout.space16),
        if (!status.updatesAvailableInBuild)
          const B05StatusMessage(
            status: B05SemanticStatus.info,
            label:
                'Food database updates aren\'t available in this version of IndiFit yet.',
          )
        else if (offline)
          const B05StatusMessage(
            status: B05SemanticStatus.info,
            label: 'Offline Mode is on, so food database updates are paused.',
          ),
        if (!status.updatesAvailableInBuild || offline)
          const SizedBox(height: B05Layout.space12),
        B05ActionButton(
          key: const Key('food_database_check'),
          icon: Icons.refresh_rounded,
          label: _checking ? 'Checking…' : 'Check for updates',
          hint: 'Downloads a newer food database if one is published.',
          onPressed: canCheck ? _checkNow : null,
        ),
        if (status.updatesAvailableInBuild) ...[
          const SizedBox(height: B05Layout.space12),
          SettingsReminderToggle(
            key: const Key('food_database_mobile_data'),
            icon: Icons.signal_cellular_alt_rounded,
            iconColor: context.b05Colors.info.indicator,
            title: 'Also update on mobile data',
            subtitle: FoodDatabaseCopy.mobileDataSubtitle(status),
            value: status.allowMobileData,
            requestNotificationPermission: false,
            onChanged: _setAllowMobileData,
          ),
        ],
        const SizedBox(height: B05Layout.space24),
        const _MissedFoods(),
        const SizedBox(height: B05Layout.space24),
        Text('Sources and attributions', style: B05Typography.title(context)),
        const SizedBox(height: B05Layout.space12),
        const _Credit(
          title: FoodDataCredits.catalogueTitle,
          detail: FoodDataCredits.catalogue,
        ),
        const SizedBox(height: B05Layout.space12),
        const _Credit(
          title: FoodDataCredits.openFoodFactsTitle,
          detail: FoodDataCredits.openFoodFacts,
        ),
        const SizedBox(height: B05Layout.space16),
        Text(
          'Updates download the food list only. They send no information about you or your meals.',
          style: B05Typography.caption(context),
        ),
      ],
    );
  }
}

/// The words and numbers Settings → Food database shows.
abstract final class FoodDatabaseCopy {
  static final _date = DateFormat('d MMM yyyy');
  static final _dateTime = DateFormat('d MMM yyyy, HH:mm');

  static String installedLine(DateTime installedAt, String? source) {
    final date = _date.format(installedAt.toLocal());
    return switch (source) {
      'download' => 'Downloaded $date',
      _ => 'Came with the app · installed $date',
    };
  }

  static String foodCountLine(CatalogStatus status) {
    final count = NumberFormat.decimalPattern('en_IN');
    final foods = '${count.format(status.foodCount)} foods';
    if (status.variantCount == 0) return foods;
    return '$foods, including ${count.format(status.variantCount)} '
        'size and preparation variants';
  }

  static String lastCheckLine(DateTime? lastCheckAt) => lastCheckAt == null
      ? 'Not checked for updates yet'
      : 'Last checked ${_dateTime.format(lastCheckAt.toLocal())}';

  static String mobileDataSubtitle(CatalogStatus status) {
    final pending = status.pendingUpdateBytes;
    final full = status.fullPackBytes;
    final size = pending != null
        ? ' The waiting update is ${bytes(pending)}.'
        : full != null
        ? ' A full update is ${bytes(full)}.'
        : '';
    return status.allowMobileData
        ? 'On: updates also download on mobile data.$size'
        : 'Off: updates wait for Wi-Fi.$size';
  }

  static String bytes(int bytes) {
    if (bytes < 1000) return '$bytes bytes';
    if (bytes < 1000 * 1000) return '${(bytes / 1000).ceil()} KB';
    return '${(bytes / (1000 * 1000)).toStringAsFixed(1)} MB';
  }

  static String checkMessage(
    CatalogUpdateResult result,
  ) => switch (result.outcome) {
    CatalogUpdateOutcome.off =>
      'Food database updates aren\'t available in this version yet.',
    CatalogUpdateOutcome.offlineMode =>
      'Offline Mode is on, so IndiFit didn\'t check.',
    CatalogUpdateOutcome.noConnection =>
      'No internet connection. Your food database wasn\'t changed.',
    CatalogUpdateOutcome.throttled => 'Checked recently.',
    CatalogUpdateOutcome.upToDate => 'Your food database is up to date.',
    CatalogUpdateOutcome.waitingForWifi =>
      'An update is ready. It will download on Wi-Fi, or when you allow mobile data.',
    CatalogUpdateOutcome.appTooOld =>
      'The newest food database needs a newer version of IndiFit.',
    CatalogUpdateOutcome.updated =>
      'Food database updated to version ${result.installedVersion}.',
    CatalogUpdateOutcome.failed =>
      'The update didn\'t finish. Your food database wasn\'t changed.',
  };
}

class _Credit extends StatelessWidget {
  const _Credit({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return B05Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: B05Typography.title(context)),
          const SizedBox(height: B05Layout.space4),
          Text(detail, style: B05Typography.body(context)),
        ],
      ),
    );
  }
}

/// "Foods you couldn't find" (CAT-13): the words added from food search,
/// sent only when the person taps Send, from their own mail app.
class _MissedFoods extends ConsumerWidget {
  const _MissedFoods();

  Future<void> _send(
    BuildContext context,
    WidgetRef ref,
    List<String> entries,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final opened = await AppLinks.open(MissedFoodSearches.email(entries));
    if (!opened) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'No mail app opened. Email the list to ${AppLinks.supportEmail}.',
          ),
        ),
      );
    }
  }

  Future<void> _clear(WidgetRef ref) async {
    await ref.read(missedFoodSearchesProvider).clear();
    ref.invalidate(missedFoodSearchEntriesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries =
        ref.watch(missedFoodSearchEntriesProvider).value ?? const <String>[];
    return Column(
      key: const Key('food_database_missed_foods'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Foods you couldn\'t find', style: B05Typography.title(context)),
        const SizedBox(height: B05Layout.space4),
        Text(
          entries.isEmpty
              ? 'When a search misses, tap "Add to my list" at the end of '
                    'the results. The list stays on this phone.'
              : 'Kept on this phone. Send sends only these words, by email '
                    'from your own mail app, and nothing from your diary.',
          style: B05Typography.body(context),
        ),
        if (entries.isNotEmpty) ...[
          const SizedBox(height: B05Layout.space8),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• $entry', style: B05Typography.body(context)),
            ),
          const SizedBox(height: B05Layout.space12),
          B05ActionButton(
            key: const Key('food_database_send_missed'),
            icon: Icons.send_rounded,
            label: 'Send to IndiFit',
            hint: 'Opens your mail app with these food names',
            onPressed: () => _send(context, ref, entries),
          ),
          const SizedBox(height: B05Layout.space8),
          B05ActionButton(
            key: const Key('food_database_clear_missed'),
            icon: Icons.delete_outline_rounded,
            label: 'Clear list',
            hint: 'Removes these words from this phone',
            emphasis: B05ActionEmphasis.secondary,
            onPressed: () => _clear(ref),
          ),
        ],
      ],
    );
  }
}
