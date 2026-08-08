import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/fixtures/b05_foundation_registry.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/database/app_database.dart';

/// Loads the approved media manifest through a packaged asset boundary.
///
/// The production default is [B05NoApprovedMediaManifestSource] until the
/// product-owner packet supplies the exact IDs, rights record and package.
abstract interface class B05MediaManifestSource {
  Future<B05MediaManifest?> load();
}

class B05NoApprovedMediaManifestSource implements B05MediaManifestSource {
  const B05NoApprovedMediaManifestSource();

  @override
  Future<B05MediaManifest?> load() async => null;
}

/// Asset-bundle manifest boundary for the later approved package. It requires
/// the approved ID set instead of inventing a top-20 catalogue in B05 code.
class B05AssetBundleMediaManifestSource implements B05MediaManifestSource {
  final AssetBundle bundle;
  final String manifestAssetPath;
  final Set<String> approvedExerciseIds;

  B05AssetBundleMediaManifestSource({
    required this.bundle,
    required this.manifestAssetPath,
    required Iterable<String> approvedExerciseIds,
  }) : approvedExerciseIds = Set.unmodifiable(
         approvedExerciseIds
             .map((id) => id.trim())
             .where((id) => id.isNotEmpty),
       );

  @override
  Future<B05MediaManifest?> load() async {
    final raw = await bundle.loadString(manifestAssetPath);
    final decoded = jsonDecode(raw);
    final manifest = B05MediaManifest.fromJson(decoded);
    B05MediaManifestValidator(approvedExerciseIds).validate(manifest);
    return manifest;
  }
}

/// Checks both the foundation contract and the exact approved ID set supplied
/// by product. A count-only check is insufficient because an arbitrary set of
/// twenty exercises must never be mistaken for the approved pack.
class B05MediaManifestValidator {
  final Set<String> approvedExerciseIds;

  B05MediaManifestValidator(Iterable<String> approvedExerciseIds)
    : approvedExerciseIds = Set.unmodifiable(
        approvedExerciseIds.map((id) => id.trim()).where((id) => id.isNotEmpty),
      );

  void validate(B05MediaManifest manifest) {
    if (approvedExerciseIds.length !=
        B05MediaAcceptanceTemplate.requiredExerciseCount) {
      throw B05RegistryValidationException(
        'media_approval_ids',
        'The approved media packet must provide exactly 20 stable exercise IDs.',
      );
    }
    manifest.validateStructure(
      requiredAssetCount: B05MediaAcceptanceTemplate.requiredExerciseCount,
    );
    final manifestIds = manifest.assets
        .map((asset) => asset.exerciseId)
        .toSet();
    if (manifestIds.length != approvedExerciseIds.length ||
        !manifestIds.containsAll(approvedExerciseIds)) {
      throw B05RegistryValidationException(
        'media_approval_id_mismatch',
        'The media manifest does not match the approved stable exercise IDs.',
      );
    }
  }
}

typedef B05MediaAssetKeyResolver = String Function(B05MediaAssetContract asset);

/// Reads a packaged asset and verifies its declared SHA-256 checksum without
/// exposing a local path or persisting the bytes. Missing bundle keys are
/// absent; a checksum mismatch is invalid.
class B05AssetBundleMediaProbe {
  final AssetBundle bundle;
  final B05MediaAssetKeyResolver assetKey;

  const B05AssetBundleMediaProbe({
    required this.bundle,
    required this.assetKey,
  });

  Future<B05MediaAssetCheckResult> check(B05MediaAssetContract asset) async {
    final key = assetKey(asset).trim();
    if (key.isEmpty) return B05MediaAssetCheckResult.invalid;
    try {
      final data = await bundle.load(key);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final actual = 'sha256:${sha256.convert(bytes).toString()}';
      return actual.toLowerCase() == asset.checksum.toLowerCase()
          ? B05MediaAssetCheckResult.available
          : B05MediaAssetCheckResult.invalid;
    } on FlutterError {
      return B05MediaAssetCheckResult.absent;
    } catch (_) {
      return B05MediaAssetCheckResult.invalid;
    }
  }
}

/// Portable media-pack preference read model. It deliberately contains no
/// physical availability, path, bytes, verification result or cache state.
class B05StoredMediaPackPreference {
  final String id;
  final String userId;
  final String packId;
  final String manifestIdentity;
  final String? lastKnownInstalledVersion;
  final String downloadPreference;
  final String? deletionChoice;
  final String? contentAcknowledgement;
  final DateTime updatedAtUtc;

  const B05StoredMediaPackPreference({
    required this.id,
    required this.userId,
    required this.packId,
    required this.manifestIdentity,
    required this.lastKnownInstalledVersion,
    required this.downloadPreference,
    required this.deletionChoice,
    required this.contentAcknowledgement,
    required this.updatedAtUtc,
  });
}

/// Repository boundary for the B05-01 media preference table. Availability is
/// intentionally not read from this table; the controller reconciles against
/// the physical asset bundle on the current device.
class B05MediaPackPreferenceRepository {
  final AppDatabase _database;

  const B05MediaPackPreferenceRepository({required AppDatabase database})
    : _database = database;

  Future<B05StoredMediaPackPreference?> read({required String userId}) async {
    final owner = _owner(userId);
    final rows =
        await (_database.select(_database.mediaPackPreferences)
              ..where((table) => table.userId.equals(owner))
              ..orderBy([
                (table) => OrderingTerm.desc(table.updatedAtUtc),
                (table) => OrderingTerm.asc(table.packId),
              ]))
            .get();
    final row = rows.firstOrNull;
    if (row == null) return null;
    return B05StoredMediaPackPreference(
      id: row.id,
      userId: row.userId,
      packId: row.packId,
      manifestIdentity: row.manifestIdentity,
      lastKnownInstalledVersion: row.lastKnownInstalledVersion,
      downloadPreference: row.downloadPreference,
      deletionChoice: row.deletionChoice,
      contentAcknowledgement: row.contentAcknowledgement,
      updatedAtUtc: row.updatedAtUtc.toUtc(),
    );
  }

  static String _owner(String value) {
    final owner = value.trim();
    if (owner.isEmpty) throw ArgumentError.value(value, 'userId');
    return owner;
  }
}

enum B05MediaBundleStatus {
  loading,
  ready,
  unavailable,
  absent,
  invalid,
  error,
}

class B05MediaBundleState {
  final B05MediaBundleStatus status;
  final B05MediaManifest? manifest;
  final B05MediaReconciliation? reconciliation;
  final B05StoredMediaPackPreference? preference;
  final String? message;

  const B05MediaBundleState({
    required this.status,
    this.manifest,
    this.reconciliation,
    this.preference,
    this.message,
  });

  const B05MediaBundleState.loading({
    B05MediaManifest? manifest,
    B05StoredMediaPackPreference? preference,
  }) : this(
         status: B05MediaBundleStatus.loading,
         manifest: manifest,
         preference: preference,
       );
}

enum B05MediaExerciseStatus {
  loading,
  available,
  unavailable,
  absent,
  invalid,
  error,
}

class B05MediaExerciseView {
  final B05MediaExerciseStatus status;
  final B05MediaAssetContract? asset;
  final String? message;

  const B05MediaExerciseView({required this.status, this.asset, this.message});
}

/// Presentation controller for packaged media. It only loads a packaged
/// manifest, reads portable preference metadata through its repository, and
/// derives availability through the device-local probe.
class B05MediaBundleController extends StateNotifier<B05MediaBundleState> {
  final B05MediaManifestSource _source;
  final B05MediaPackPreferenceRepository _preferenceRepository;
  final String _userId;
  final B05MediaAssetProbe? _probe;
  var _isReconciling = false;

  B05MediaBundleController({
    required B05MediaManifestSource source,
    required B05MediaPackPreferenceRepository preferenceRepository,
    required String userId,
    B05MediaAssetProbe? probe,
  }) : _source = source,
       _preferenceRepository = preferenceRepository,
       _userId = userId,
       _probe = probe,
       super(const B05MediaBundleState.loading());

  Future<void> reconcile() async {
    if (_isReconciling) return;
    _isReconciling = true;
    final previous = state;
    state = B05MediaBundleState.loading(
      manifest: previous.manifest,
      preference: previous.preference,
    );
    try {
      final preference = await _preferenceRepository.read(userId: _userId);
      final manifest = await _source.load();
      if (!mounted) return;
      if (manifest == null) {
        state = B05MediaBundleState(
          status: B05MediaBundleStatus.unavailable,
          preference: preference,
          message:
              'Movement guides are not installed on this device. Written guidance remains available.',
        );
        return;
      }

      manifest.validateStructure(
        requiredAssetCount: B05MediaAcceptanceTemplate.requiredExerciseCount,
      );
      if (preference != null &&
          (preference.packId != manifest.pack.packId ||
              preference.manifestIdentity != manifest.pack.manifestIdentity)) {
        state = B05MediaBundleState(
          status: B05MediaBundleStatus.unavailable,
          manifest: manifest,
          preference: preference,
          message: 'The saved movement guide is not available on this device.',
        );
        return;
      }

      final reconciliation = await const B05MediaPackReconciler().reconcile(
        manifest,
        probe: _probe ?? (_) async => B05MediaAssetCheckResult.absent,
      );
      final status = switch (reconciliation.state) {
        B05MediaAvailabilityState.available => B05MediaBundleStatus.ready,
        B05MediaAvailabilityState.absent => B05MediaBundleStatus.absent,
        B05MediaAvailabilityState.invalid => B05MediaBundleStatus.invalid,
      };
      state = B05MediaBundleState(
        status: status,
        manifest: manifest,
        reconciliation: reconciliation,
        preference: preference,
        message: switch (status) {
          B05MediaBundleStatus.ready => 'Movement guides are ready to use.',
          B05MediaBundleStatus.absent =>
            'Movement guides are not installed. Text instructions remain available.',
          B05MediaBundleStatus.invalid =>
            'Movement guides are unavailable. Text instructions remain available.',
          _ => null,
        },
      );
    } on B05RegistryValidationException {
      if (!mounted) return;
      state = B05MediaBundleState(
        status: B05MediaBundleStatus.invalid,
        preference: state.preference,
        message: 'Exercise media could not be checked. Try again.',
      );
    } catch (_) {
      if (!mounted) return;
      state = B05MediaBundleState(
        status: B05MediaBundleStatus.error,
        manifest: state.manifest,
        preference: state.preference,
        message: 'Exercise media could not be checked. Try again.',
      );
    } finally {
      _isReconciling = false;
    }
  }

  Future<void> retry() => reconcile();

  B05MediaExerciseView exercise(String? exerciseId) {
    if (state.status == B05MediaBundleStatus.loading) {
      return const B05MediaExerciseView(status: B05MediaExerciseStatus.loading);
    }
    final id = exerciseId?.trim();
    if (id == null || id.isEmpty) {
      return const B05MediaExerciseView(
        status: B05MediaExerciseStatus.unavailable,
        message: 'Exercise media is not available for this exercise.',
      );
    }
    final asset = state.manifest?.assets
        .where((candidate) => candidate.exerciseId == id)
        .firstOrNull;
    if (asset == null) {
      return const B05MediaExerciseView(
        status: B05MediaExerciseStatus.unavailable,
        message: 'A movement guide is not available for this exercise.',
      );
    }
    return switch (state.status) {
      B05MediaBundleStatus.loading => const B05MediaExerciseView(
        status: B05MediaExerciseStatus.loading,
      ),
      B05MediaBundleStatus.ready => B05MediaExerciseView(
        status: B05MediaExerciseStatus.available,
        asset: asset,
        message: state.message,
      ),
      B05MediaBundleStatus.absent => B05MediaExerciseView(
        status: B05MediaExerciseStatus.absent,
        asset: asset,
        message: state.message,
      ),
      B05MediaBundleStatus.invalid => B05MediaExerciseView(
        status: B05MediaExerciseStatus.invalid,
        asset: asset,
        message: state.message,
      ),
      B05MediaBundleStatus.unavailable => B05MediaExerciseView(
        status: B05MediaExerciseStatus.unavailable,
        asset: asset,
        message: state.message,
      ),
      B05MediaBundleStatus.error => B05MediaExerciseView(
        status: B05MediaExerciseStatus.error,
        asset: asset,
        message: state.message,
      ),
    };
  }
}

final b05MediaManifestSourceProvider = Provider<B05MediaManifestSource>(
  (_) => const B05NoApprovedMediaManifestSource(),
);

final b05MediaPackPreferenceRepositoryProvider =
    Provider<B05MediaPackPreferenceRepository>(
      (ref) => B05MediaPackPreferenceRepository(
        database: ref.watch(databaseProvider),
      ),
    );

final b05MediaAssetProbeProvider = Provider<B05MediaAssetProbe>(
  (_) =>
      (_) async => B05MediaAssetCheckResult.absent,
);

final b05MediaBundleControllerProvider =
    StateNotifierProvider.autoDispose<
      B05MediaBundleController,
      B05MediaBundleState
    >((ref) {
      final controller = B05MediaBundleController(
        source: ref.watch(b05MediaManifestSourceProvider),
        preferenceRepository: ref.watch(
          b05MediaPackPreferenceRepositoryProvider,
        ),
        userId: kLocalNutritionUserScopeId,
        probe: ref.watch(b05MediaAssetProbeProvider),
      );
      unawaited(controller.reconcile());
      return controller;
    });

/// Media presentation that never fetches a remote clip. The text/checklist
/// fallback remains visible when the approved pack is absent or invalid.
class B05ExerciseMediaPanel extends ConsumerWidget {
  final String? exerciseId;
  final List<String> textFallback;

  const B05ExerciseMediaPanel({
    required this.exerciseId,
    super.key,
    this.textFallback = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(b05MediaBundleControllerProvider);
    final view = ref
        .read(b05MediaBundleControllerProvider.notifier)
        .exercise(exerciseId);
    final body = switch (view.status) {
      B05MediaExerciseStatus.loading => const B05StatusMessage(
        status: B05SemanticStatus.info,
        label: 'Checking bundled exercise media',
      ),
      B05MediaExerciseStatus.available => _available(context, view),
      B05MediaExerciseStatus.unavailable => B05StatusMessage(
        status: B05SemanticStatus.unavailable,
        label: 'Exercise media is unavailable',
        value: view.message,
      ),
      B05MediaExerciseStatus.absent => B05StatusMessage(
        status: B05SemanticStatus.unavailable,
        label: 'Movement guide is not installed',
        value: view.message,
      ),
      B05MediaExerciseStatus.invalid => B05StatusMessage(
        status: B05SemanticStatus.danger,
        label: 'Movement guide is unavailable',
        value: view.message,
      ),
      B05MediaExerciseStatus.error => B05StatusMessage(
        status: B05SemanticStatus.danger,
        label: 'Exercise media could not be checked',
        value: view.message,
      ),
    };
    return Semantics(
      container: true,
      label: 'Exercise media',
      child: B05Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Offline exercise media', style: B05Typography.title(context)),
            const SizedBox(height: B05Layout.space8),
            body,
            const SizedBox(height: B05Layout.space8),
            _textAlternative(context, view),
            if (state.status == B05MediaBundleStatus.error) ...[
              const SizedBox(height: B05Layout.space8),
              B05ActionButton(
                label: 'Retry media check',
                icon: Icons.refresh_rounded,
                emphasis: B05ActionEmphasis.secondary,
                onPressed: ref
                    .read(b05MediaBundleControllerProvider.notifier)
                    .retry,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _available(BuildContext context, B05MediaExerciseView view) {
    return B05MotionContent(
      animatedChild: B05StatusMessage(
        status: B05SemanticStatus.success,
        label: 'A movement guide is available',
        value: 'Follow the guide at your own pace.',
      ),
      reducedMotionChild: B05StatusMessage(
        status: B05SemanticStatus.success,
        label: 'Still/text alternative is available',
        value: 'Reduced motion is enabled; media autoplay is disabled.',
      ),
    );
  }

  Widget _textAlternative(BuildContext context, B05MediaExerciseView view) {
    final cues = textFallback
        .map((cue) => cue.trim())
        .where((cue) => cue.isNotEmpty)
        .toList(growable: false);
    return Semantics(
      container: true,
      label: 'Written movement guidance',
      value: [
        if (cues.isNotEmpty) ...cues,
        if (cues.isEmpty) 'Use the exercise checklist below.',
      ].join('. '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Written guidance', style: B05Typography.label(context)),
          const SizedBox(height: B05Layout.space4),
          Text(
            'A written guide is always available if you prefer not to use media.',
            style: B05Typography.body(context),
          ),
          if (cues.isEmpty)
            Text(
              'Use the exercise checklist and form cues below.',
              style: B05Typography.body(context),
            ),
          ...cues.map(
            (cue) => Padding(
              padding: const EdgeInsets.only(top: B05Layout.space4),
              child: Text('• $cue', style: B05Typography.body(context)),
            ),
          ),
        ],
      ),
    );
  }
}
