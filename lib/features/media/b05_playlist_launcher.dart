import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/fixtures/b05_foundation_registry.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/privacy/privacy_policy.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/database/app_database.dart';

class B05PlaylistPreferenceRecord {
  final String id;
  final String userId;
  final String providerId;
  final String normalizedReference;
  final String? displayLabel;
  final DateTime updatedAtUtc;

  const B05PlaylistPreferenceRecord({
    required this.id,
    required this.userId,
    required this.providerId,
    required this.normalizedReference,
    required this.displayLabel,
    required this.updatedAtUtc,
  });
}

class B05PlaylistPreferenceRepository {
  final AppDatabase _database;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;

  B05PlaylistPreferenceRepository({
    required AppDatabase database,
    Uuid? uuid,
    DateTime Function()? nowUtc,
  }) : _database = database,
       _uuid = uuid ?? const Uuid(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  Future<B05PlaylistPreferenceRecord?> read({required String userId}) async {
    final owner = _owner(userId);
    final row = await (_database.select(
      _database.workoutPlaylistPreferences,
    )..where((table) => table.userId.equals(owner))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<B05PlaylistPreferenceRecord> save({
    required String userId,
    required B05PlaylistReference reference,
    String? displayLabel,
  }) async {
    final owner = _owner(userId);
    final existing = await read(userId: owner);
    final now = _nowUtc().toUtc();
    final id = existing?.id ?? _uuid.v4();
    final label = displayLabel?.trim();
    final companion = WorkoutPlaylistPreferencesCompanion(
      id: Value(id),
      userId: Value(owner),
      providerId: Value(reference.providerId),
      playlistReference: Value(reference.normalizedReference),
      displayLabel: Value(label == null || label.isEmpty ? null : label),
      updatedAtUtc: Value(now),
    );
    if (existing == null) {
      await _database
          .into(_database.workoutPlaylistPreferences)
          .insert(companion);
    } else {
      await (_database.update(
        _database.workoutPlaylistPreferences,
      )..where((table) => table.id.equals(existing.id))).write(companion);
    }
    return B05PlaylistPreferenceRecord(
      id: id,
      userId: owner,
      providerId: reference.providerId,
      normalizedReference: reference.normalizedReference,
      displayLabel: label == null || label.isEmpty ? null : label,
      updatedAtUtc: now,
    );
  }

  Future<void> clear({required String userId}) async {
    final owner = _owner(userId);
    await (_database.delete(
      _database.workoutPlaylistPreferences,
    )..where((table) => table.userId.equals(owner))).go();
  }

  B05PlaylistPreferenceRecord _fromRow(WorkoutPlaylistPreference row) =>
      B05PlaylistPreferenceRecord(
        id: row.id,
        userId: row.userId,
        providerId: row.providerId,
        normalizedReference: row.playlistReference,
        displayLabel: row.displayLabel,
        updatedAtUtc: row.updatedAtUtc.toUtc(),
      );

  static String _owner(String value) {
    final owner = value.trim();
    if (owner.isEmpty) throw ArgumentError.value(value, 'userId');
    return owner;
  }
}

enum B05PlaylistLaunchStatus { launched, invalid, appMissing, offline, failure }

class B05PlaylistLaunchResult {
  final B05PlaylistLaunchStatus status;
  final Uri? uri;
  final String message;

  const B05PlaylistLaunchResult({
    required this.status,
    required this.message,
    this.uri,
  });

  bool get isSuccess => status == B05PlaylistLaunchStatus.launched;
}

typedef B05CanLaunchUri = Future<bool> Function(Uri uri);
typedef B05LaunchUri = Future<bool> Function(Uri uri);

/// Revalidates the persisted typed reference before reconstructing and
/// launching a URI. No arbitrary URL is accepted by this boundary.
class B05PlaylistLaunchService {
  final B05PlaylistProviderRegistry registry;
  final B05CanLaunchUri _canLaunch;
  final B05LaunchUri _launch;

  B05PlaylistLaunchService({
    required this.registry,
    B05CanLaunchUri? canLaunch,
    B05LaunchUri? launch,
  }) : _canLaunch = canLaunch ?? canLaunchUrl,
       _launch =
           launch ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

  Future<B05PlaylistLaunchResult> launch({
    required B05PlaylistPreferenceRecord preference,
    required bool strictOffline,
  }) async {
    if (strictOffline) {
      return const B05PlaylistLaunchResult(
        status: B05PlaylistLaunchStatus.offline,
        message: 'Playlist launch is unavailable in strict-offline mode.',
      );
    }
    late final B05PlaylistReference reference;
    try {
      reference = registry.normalize(
        preference.providerId,
        preference.normalizedReference,
      );
    } on Object catch (error) {
      return B05PlaylistLaunchResult(
        status: B05PlaylistLaunchStatus.invalid,
        message: 'Saved playlist reference is invalid: $error',
      );
    }
    try {
      if (!await _canLaunch(reference.launchUri)) {
        return const B05PlaylistLaunchResult(
          status: B05PlaylistLaunchStatus.appMissing,
          message: 'The selected music app is not available on this device.',
        );
      }
      final launched = await _launch(reference.launchUri);
      if (!launched) {
        return const B05PlaylistLaunchResult(
          status: B05PlaylistLaunchStatus.failure,
          message: 'The selected music app could not open this playlist.',
        );
      }
      return B05PlaylistLaunchResult(
        status: B05PlaylistLaunchStatus.launched,
        message: 'Playlist opened.',
        uri: reference.launchUri,
      );
    } on Object catch (error) {
      return B05PlaylistLaunchResult(
        status: B05PlaylistLaunchStatus.failure,
        message: 'Playlist launch failed: $error',
      );
    }
  }
}

enum B05PlaylistControllerStatus { loading, ready, saving, launching, error }

class B05PlaylistControllerState {
  final B05PlaylistControllerStatus status;
  final B05PlaylistPreferenceRecord? preference;
  final String? message;

  const B05PlaylistControllerState({
    required this.status,
    this.preference,
    this.message,
  });

  const B05PlaylistControllerState.loading()
    : status = B05PlaylistControllerStatus.loading,
      preference = null,
      message = null;

  bool get isSaving => status == B05PlaylistControllerStatus.saving;
  bool get isBusy =>
      status == B05PlaylistControllerStatus.saving ||
      status == B05PlaylistControllerStatus.launching;
}

class B05PlaylistController extends StateNotifier<B05PlaylistControllerState> {
  final B05PlaylistPreferenceRepository _repository;
  final B05PlaylistProviderRegistry _registry;
  final B05PlaylistLaunchService _launcher;
  final String _userId;
  var _isLaunching = false;

  B05PlaylistController({
    required B05PlaylistPreferenceRepository repository,
    required B05PlaylistProviderRegistry registry,
    required String userId,
    B05PlaylistLaunchService? launcher,
  }) : _repository = repository,
       _registry = registry,
       _launcher = launcher ?? B05PlaylistLaunchService(registry: registry),
       _userId = userId,
       super(const B05PlaylistControllerState.loading());

  Future<void> load() async {
    final existing = state.preference;
    state = B05PlaylistControllerState(
      status: B05PlaylistControllerStatus.loading,
      preference: existing,
    );
    try {
      final preference = await _repository.read(userId: _userId);
      if (!mounted) return;
      final message =
          preference != null &&
              !_registry.providers.containsKey(preference.providerId)
          ? 'Saved playlist provider is not available in this build.'
          : null;
      state = B05PlaylistControllerState(
        status: B05PlaylistControllerStatus.ready,
        preference: preference,
        message: message,
      );
    } catch (error) {
      if (!mounted) return;
      state = B05PlaylistControllerState(
        status: B05PlaylistControllerStatus.error,
        preference: state.preference,
        message: error.toString(),
      );
    }
  }

  Future<void> save({
    required String providerId,
    required String rawReference,
    String? displayLabel,
  }) async {
    if (state.isBusy) return;
    state = B05PlaylistControllerState(
      status: B05PlaylistControllerStatus.saving,
      preference: state.preference,
    );
    try {
      final reference = _registry.normalize(providerId, rawReference);
      final preference = await _repository.save(
        userId: _userId,
        reference: reference,
        displayLabel: displayLabel,
      );
      if (!mounted) return;
      state = B05PlaylistControllerState(
        status: B05PlaylistControllerStatus.ready,
        preference: preference,
        message: 'Playlist preference saved.',
      );
    } catch (error) {
      if (!mounted) return;
      state = B05PlaylistControllerState(
        status: B05PlaylistControllerStatus.error,
        preference: state.preference,
        message: error.toString(),
      );
    }
  }

  Future<void> clear() async {
    if (state.isBusy) return;
    state = B05PlaylistControllerState(
      status: B05PlaylistControllerStatus.saving,
      preference: state.preference,
    );
    try {
      await _repository.clear(userId: _userId);
      if (!mounted) return;
      state = const B05PlaylistControllerState(
        status: B05PlaylistControllerStatus.ready,
        message: 'Playlist preference cleared.',
      );
    } catch (error) {
      if (!mounted) return;
      state = B05PlaylistControllerState(
        status: B05PlaylistControllerStatus.error,
        preference: state.preference,
        message: error.toString(),
      );
    }
  }

  Future<B05PlaylistLaunchResult?> launch({required bool strictOffline}) async {
    final preference = state.preference;
    if (preference == null || _isLaunching || state.isBusy) return null;
    _isLaunching = true;
    state = B05PlaylistControllerState(
      status: B05PlaylistControllerStatus.launching,
      preference: preference,
    );
    try {
      final result = await _launcher.launch(
        preference: preference,
        strictOffline: strictOffline,
      );
      if (mounted) {
        state = B05PlaylistControllerState(
          status: B05PlaylistControllerStatus.ready,
          preference: preference,
          message: result.message,
        );
      }
      return result;
    } catch (error) {
      if (mounted) {
        state = B05PlaylistControllerState(
          status: B05PlaylistControllerStatus.error,
          preference: preference,
          message: error.toString(),
        );
      }
      return B05PlaylistLaunchResult(
        status: B05PlaylistLaunchStatus.failure,
        message: 'Playlist launch failed: $error',
      );
    } finally {
      _isLaunching = false;
    }
  }

  Future<void> retry() => load();
}

final b05PlaylistProviderRegistryProvider =
    Provider<B05PlaylistProviderRegistry>(
      // Product approval supplies the real entries. An empty default is an
      // honest unavailable state and cannot launch arbitrary URLs.
      (_) => B05PlaylistProviderRegistry(const []),
    );

final b05PlaylistPreferenceRepositoryProvider =
    Provider<B05PlaylistPreferenceRepository>(
      (ref) => B05PlaylistPreferenceRepository(
        database: ref.watch(databaseProvider),
      ),
    );

final b05PlaylistControllerProvider =
    StateNotifierProvider.autoDispose<
      B05PlaylistController,
      B05PlaylistControllerState
    >((ref) {
      final controller = B05PlaylistController(
        repository: ref.watch(b05PlaylistPreferenceRepositoryProvider),
        registry: ref.watch(b05PlaylistProviderRegistryProvider),
        userId: kLocalNutritionUserScopeId,
      );
      unawaited(controller.load());
      return controller;
    });

class B05PlaylistLauncherButton extends ConsumerWidget {
  const B05PlaylistLauncherButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(b05PlaylistControllerProvider);
    final controller = ref.read(b05PlaylistControllerProvider.notifier);
    final preference = state.preference;
    if (state.status == B05PlaylistControllerStatus.loading ||
        state.status == B05PlaylistControllerStatus.launching) {
      return const B05IconAction(
        icon: Icons.music_note_outlined,
        label: 'Playlist launcher',
        hint: 'Checking or opening the saved workout playlist.',
        onPressed: null,
        focusOrder: 3,
      );
    }
    if (preference == null) {
      return B05IconAction(
        icon: Icons.playlist_add_outlined,
        label: 'Playlist launcher',
        hint: 'Opens settings to choose an approved playlist provider.',
        onPressed: () => context.push('/settings'),
        focusOrder: 3,
      );
    }
    return B05IconAction(
      icon: Icons.music_note_outlined,
      label: 'Playlist launcher',
      hint: state.message ?? 'Opens the saved playlist in its music app.',
      onPressed: () async {
        final result = await controller.launch(
          strictOffline: ref.read(privacyPolicyProvider).isOfflineOnly,
        );
        if (!context.mounted || result == null || result.isSuccess) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message)));
      },
      focusOrder: 3,
    );
  }
}

class B05PlaylistSettingsPanel extends ConsumerStatefulWidget {
  const B05PlaylistSettingsPanel({super.key});

  @override
  ConsumerState<B05PlaylistSettingsPanel> createState() =>
      _B05PlaylistSettingsPanelState();
}

class _B05PlaylistSettingsPanelState
    extends ConsumerState<B05PlaylistSettingsPanel> {
  final _referenceController = TextEditingController();
  final _labelController = TextEditingController();
  String? _providerId;

  @override
  void dispose() {
    _referenceController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(b05PlaylistProviderRegistryProvider);
    final state = ref.watch(b05PlaylistControllerProvider);
    final controller = ref.read(b05PlaylistControllerProvider.notifier);
    ref.listen(b05PlaylistControllerProvider, (previous, next) {
      final preference = next.preference;
      if (!mounted || preference == null) return;
      _providerId ??= preference.providerId;
      if (_referenceController.text.isEmpty) {
        _referenceController.text = preference.normalizedReference;
      }
      if (_labelController.text.isEmpty && preference.displayLabel != null) {
        _labelController.text = preference.displayLabel!;
      }
    });

    if (registry.providers.isEmpty) {
      return const B05StatusMessage(
        status: B05SemanticStatus.unavailable,
        label: 'Playlist setup is unavailable',
        value:
            'An approved provider allowlist is required before a playlist can be saved or launched.',
      );
    }
    if (state.status == B05PlaylistControllerStatus.loading &&
        state.preference == null) {
      return const B05StatusMessage(
        status: B05SemanticStatus.info,
        label: 'Loading playlist preference',
      );
    }
    if (state.status == B05PlaylistControllerStatus.error &&
        state.preference == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          B05StatusMessage(
            status: B05SemanticStatus.danger,
            label: 'Playlist preference unavailable',
            value: state.message,
          ),
          const SizedBox(height: B05Layout.space8),
          B05ActionButton(
            label: 'Retry playlist settings',
            icon: Icons.refresh_rounded,
            emphasis: B05ActionEmphasis.secondary,
            onPressed: controller.retry,
          ),
        ],
      );
    }
    final provider =
        _providerId ??
        state.preference?.providerId ??
        registry.providers.keys.first;
    _providerId ??= provider;
    return B05Surface(
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Workout playlist', style: B05Typography.title(context)),
            const SizedBox(height: B05Layout.space4),
            Text(
              'Save a validated provider reference for quick launch during a workout.',
              style: B05Typography.body(context),
            ),
            const SizedBox(height: B05Layout.space12),
            DropdownButtonFormField<String>(
              initialValue: provider,
              decoration: const InputDecoration(labelText: 'Provider'),
              items: [
                for (final item in registry.providers.values)
                  DropdownMenuItem(value: item.id, child: Text(item.id)),
              ],
              onChanged: state.isBusy
                  ? null
                  : (value) => setState(() => _providerId = value),
            ),
            const SizedBox(height: B05Layout.space8),
            TextField(
              controller: _referenceController,
              enabled: !state.isBusy,
              decoration: const InputDecoration(
                labelText: 'Playlist reference',
                hintText: 'Provider-specific URI or link',
              ),
            ),
            const SizedBox(height: B05Layout.space8),
            TextField(
              controller: _labelController,
              enabled: !state.isBusy,
              decoration: const InputDecoration(labelText: 'Label (optional)'),
            ),
            const SizedBox(height: B05Layout.space8),
            B05ActionGroup(
              children: [
                B05ActionButton(
                  label: 'Save playlist',
                  icon: Icons.save_outlined,
                  onPressed: state.isBusy
                      ? null
                      : () => controller.save(
                          providerId: provider,
                          rawReference: _referenceController.text,
                          displayLabel: _labelController.text,
                        ),
                ),
                if (state.preference != null)
                  B05ActionButton(
                    label: 'Clear playlist',
                    icon: Icons.delete_outline,
                    emphasis: B05ActionEmphasis.secondary,
                    onPressed: state.isBusy ? null : controller.clear,
                  ),
              ],
            ),
            if (state.message != null) ...[
              const SizedBox(height: B05Layout.space8),
              B05StatusMessage(
                status: state.status == B05PlaylistControllerStatus.error
                    ? B05SemanticStatus.danger
                    : B05SemanticStatus.info,
                label: 'Playlist settings',
                value: state.message,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class B05PlaylistSettingsScreen extends StatelessWidget {
  const B05PlaylistSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Workout playlist')),
    body: const SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(B05Layout.space16),
        child: B05PlaylistSettingsPanel(),
      ),
    ),
  );
}
