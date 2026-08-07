import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b02_muscle_catalog.dart';
import 'package:indifit/core/fixtures/b05_foundation_registry.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/widgets/b05_accessibility_primitives.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/features/education/b05_education_content.dart';
import 'package:indifit/features/media/b05_media_bundle.dart';
import 'package:indifit/features/media/b05_muscle_diagram.dart';
import 'package:indifit/features/media/b05_playlist_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('media approval validation requires the exact twenty IDs', () async {
    final approvedIds = _approvedMediaIds();
    final manifest = _manifest(approvedIds);

    final source = B05AssetBundleMediaManifestSource(
      bundle: _MapAssetBundle({
        'manifest.json': utf8.encode(jsonEncode(manifest.toJson())),
      }),
      manifestAssetPath: 'manifest.json',
      approvedExerciseIds: approvedIds,
    );

    expect(
      () => B05MediaManifestValidator(approvedIds).validate(manifest),
      returnsNormally,
    );
    expect((await source.load())!.assets, hasLength(20));

    final substitutedIds = [...approvedIds]..[0] = 'unapproved-exercise';
    expect(
      () => B05MediaManifestValidator(substitutedIds).validate(manifest),
      throwsA(
        isA<B05RegistryValidationException>().having(
          (error) => error.code,
          'code',
          'media_approval_id_mismatch',
        ),
      ),
    );
    expect(
      () => B05MediaManifestValidator(
        approvedIds,
      ).validate(_manifest([...approvedIds, 'extra-exercise'])),
      throwsA(isA<B05RegistryValidationException>()),
    );
  });

  test(
    'packaged media probe distinguishes available, absent and invalid',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3, 5, 8]);
      final checksum = 'sha256:${sha256.convert(bytes)}';
      final asset = _mediaAsset('exercise-0', checksum: checksum);
      final probe = B05AssetBundleMediaProbe(
        bundle: _MapAssetBundle({'clips/exercise-0': bytes}),
        assetKey: (candidate) => 'clips/${candidate.exerciseId}',
      );

      expect(await probe.check(asset), B05MediaAssetCheckResult.available);
      expect(
        await probe.check(
          _mediaAsset(
            'exercise-0',
            checksum:
                'sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          ),
        ),
        B05MediaAssetCheckResult.invalid,
      );
      expect(
        await B05AssetBundleMediaProbe(
          bundle: _MapAssetBundle(),
          assetKey: (candidate) => 'clips/${candidate.exerciseId}',
        ).check(asset),
        B05MediaAssetCheckResult.absent,
      );
    },
  );

  test(
    'media reconciliation restores preference metadata and rechecks assets',
    () async {
      final database = AppDatabase.memory();
      addTearDown(database.close);
      const userId = 'local-user';
      final manifest = _manifest(_approvedMediaIds());
      await database
          .into(database.mediaPackPreferences)
          .insert(
            MediaPackPreferencesCompanion.insert(
              id: 'media-preference-1',
              userId: userId,
              packId: manifest.pack.packId,
              manifestIdentity: manifest.pack.manifestIdentity,
              updatedAtUtc: drift.Value(DateTime.utc(2026, 8, 7, 12)),
            ),
          );
      final controller = B05MediaBundleController(
        source: _StaticMediaManifestSource(manifest),
        preferenceRepository: B05MediaPackPreferenceRepository(
          database: database,
        ),
        userId: userId,
        probe: (_) async => B05MediaAssetCheckResult.absent,
      );
      addTearDown(controller.dispose);

      await controller.reconcile();

      expect(controller.state.status, B05MediaBundleStatus.absent);
      expect(controller.state.preference?.packId, manifest.pack.packId);
      expect(
        controller.exercise('exercise-0').status,
        B05MediaExerciseStatus.absent,
      );
      expect(
        controller.exercise('unknown-exercise').status,
        B05MediaExerciseStatus.unavailable,
      );
    },
  );

  test(
    'media controller exposes failure and retry without remote fallback',
    () async {
      final database = AppDatabase.memory();
      addTearDown(database.close);
      final source = _MutableMediaManifestSource()
        ..error = StateError('manifest unavailable')
        ..manifest = _manifest(_approvedMediaIds());
      final controller = B05MediaBundleController(
        source: source,
        preferenceRepository: B05MediaPackPreferenceRepository(
          database: database,
        ),
        userId: 'local-user',
      );
      addTearDown(controller.dispose);

      await controller.reconcile();
      expect(controller.state.status, B05MediaBundleStatus.error);

      source.error = null;
      await controller.retry();
      expect(controller.state.status, B05MediaBundleStatus.absent);
    },
  );

  test(
    'playlist repository persists only normalized typed references and is idempotent',
    () async {
      final database = AppDatabase.memory();
      addTearDown(database.close);
      final registry = _playlistRegistry();
      var now = DateTime.utc(2026, 8, 7, 12);
      final repository = B05PlaylistPreferenceRepository(
        database: database,
        nowUtc: () => now,
      );

      final first = await repository.save(
        userId: 'local-user',
        reference: registry.normalize(
          'spotify',
          'https://OPEN.SPOTIFY.COM/playlist/abc?utm_source=indi',
        ),
        displayLabel: '  Strength mix  ',
      );
      now = now.add(const Duration(minutes: 1));
      final second = await repository.save(
        userId: 'local-user',
        reference: registry.normalize(
          'spotify',
          'https://open.spotify.com/playlist/def',
        ),
      );
      final rows = await database
          .select(database.workoutPlaylistPreferences)
          .get();

      expect(second.id, first.id);
      expect(rows, hasLength(1));
      expect(
        rows.single.playlistReference,
        'https://open.spotify.com/playlist/def',
      );
      expect(rows.single.displayLabel, isNull);
      expect(
        (await repository.read(userId: 'local-user'))?.normalizedReference,
        'https://open.spotify.com/playlist/def',
      );

      await repository.clear(userId: 'local-user');
      expect(await repository.read(userId: 'local-user'), isNull);
    },
  );

  test(
    'playlist controller validates, deduplicates repeated saves and retries',
    () async {
      final database = AppDatabase.memory();
      addTearDown(database.close);
      final registry = _playlistRegistry();
      final controller = B05PlaylistController(
        repository: B05PlaylistPreferenceRepository(database: database),
        registry: registry,
        userId: 'local-user',
      );
      addTearDown(controller.dispose);
      await controller.load();

      await Future.wait([
        controller.save(
          providerId: 'spotify',
          rawReference: 'https://open.spotify.com/playlist/abc',
        ),
        controller.save(
          providerId: 'spotify',
          rawReference: 'https://open.spotify.com/playlist/abc',
        ),
      ]);
      expect(controller.state.preference, isNotNull);
      expect(
        await database.select(database.workoutPlaylistPreferences).get(),
        hasLength(1),
      );

      await controller.save(
        providerId: 'spotify',
        rawReference: 'https://example.com/not-allowlisted',
      );
      expect(controller.state.status, B05PlaylistControllerStatus.error);
      await controller.retry();
      expect(controller.state.status, B05PlaylistControllerStatus.ready);
    },
  );

  test(
    'playlist controller exposes launch loading and suppresses duplicate launches',
    () async {
      final database = AppDatabase.memory();
      addTearDown(database.close);
      final gate = Completer<bool>();
      var launchCalls = 0;
      final registry = _playlistRegistry();
      final controller = B05PlaylistController(
        repository: B05PlaylistPreferenceRepository(database: database),
        registry: registry,
        userId: 'local-user',
        launcher: B05PlaylistLaunchService(
          registry: registry,
          canLaunch: (_) async => true,
          launch: (_) {
            launchCalls++;
            return gate.future;
          },
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();
      await controller.save(
        providerId: 'spotify',
        rawReference: 'https://open.spotify.com/playlist/abc',
      );

      final first = controller.launch(strictOffline: false);
      expect(controller.state.status, B05PlaylistControllerStatus.launching);
      final duplicate = await controller.launch(strictOffline: false);
      expect(duplicate, isNull);
      gate.complete(true);

      expect((await first)?.status, B05PlaylistLaunchStatus.launched);
      expect(launchCalls, 1);
      expect(controller.state.status, B05PlaylistControllerStatus.ready);
    },
  );

  test(
    'playlist launcher reports success, invalid, app-missing, offline and failure',
    () async {
      final registry = _playlistRegistry();
      final preference = B05PlaylistPreferenceRecord(
        id: 'playlist-1',
        userId: 'local-user',
        providerId: 'spotify',
        normalizedReference: 'https://open.spotify.com/playlist/abc',
        displayLabel: null,
        updatedAtUtc: DateTime.utc(2026, 8, 7),
      );
      Uri? launchedUri;
      final launcher = B05PlaylistLaunchService(
        registry: registry,
        canLaunch: (_) async => true,
        launch: (uri) async {
          launchedUri = uri;
          return true;
        },
      );
      final success = await launcher.launch(
        preference: preference,
        strictOffline: false,
      );
      expect(success.status, B05PlaylistLaunchStatus.launched);
      expect(launchedUri?.toString(), preference.normalizedReference);

      final offline = await launcher.launch(
        preference: preference,
        strictOffline: true,
      );
      expect(offline.status, B05PlaylistLaunchStatus.offline);

      final appMissing = await B05PlaylistLaunchService(
        registry: registry,
        canLaunch: (_) async => false,
      ).launch(preference: preference, strictOffline: false);
      expect(appMissing.status, B05PlaylistLaunchStatus.appMissing);

      final failed = await B05PlaylistLaunchService(
        registry: registry,
        canLaunch: (_) async => true,
        launch: (_) async => false,
      ).launch(preference: preference, strictOffline: false);
      expect(failed.status, B05PlaylistLaunchStatus.failure);

      final invalid = await launcher.launch(
        preference: B05PlaylistPreferenceRecord(
          id: preference.id,
          userId: preference.userId,
          providerId: 'not-allowlisted',
          normalizedReference: preference.normalizedReference,
          displayLabel: null,
          updatedAtUtc: preference.updatedAtUtc,
        ),
        strictOffline: false,
      );
      expect(invalid.status, B05PlaylistLaunchStatus.invalid);
    },
  );

  test(
    'muscle diagram validates canonical IDs and preserves a text equivalent',
    () {
      final valid = B05MuscleVisualRegistry([
        const B05MuscleDiagramRegion(
          regionId: 'chest-region',
          muscleId: 'chest',
          label: 'Chest',
          textOrder: 0,
        ),
      ]);
      B05MuscleDiagramValidator().validate(valid);
      expect(
        () => B05MuscleDiagramValidator().validate(
          B05MuscleVisualRegistry([
            const B05MuscleDiagramRegion(
              regionId: 'unknown-region',
              muscleId: 'invented-muscle',
              label: 'Unknown',
              textOrder: 0,
            ),
          ]),
        ),
        throwsA(isA<B05RegistryValidationException>()),
      );
      expect(
        B02CanonicalMuscleCatalog.muscles.map((muscle) => muscle.id),
        contains('chest'),
      );
    },
  );

  testWidgets(
    'muscle diagram remains usable at compact width, 2x text and reduced motion',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 720),
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: B05InteractiveMuscleDiagram(
                    muscles: B05MuscleLabelSet(
                      labels: [
                        B05MuscleLabel(
                          muscleId: 'chest',
                          displayName: 'Chest',
                          role: B02MuscleRole.primary,
                          contributionBasisPoints: 10000,
                        ),
                      ],
                      isUnknown: false,
                    ),
                    visualRegistry: B05MuscleVisualRegistry([
                      B05MuscleDiagramRegion(
                        regionId: 'chest-region',
                        muscleId: 'chest',
                        label: 'Chest',
                        textOrder: 0,
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Text list'), findsOneWidget);
        expect(find.byType(B05ActionButton), findsOneWidget);
        expect(find.byType(AnimatedSwitcher), findsNothing);
        expect(
          find.bySemanticsLabel('Muscle diagram text equivalent'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}

List<String> _approvedMediaIds() => [
  for (
    var index = 0;
    index < B05MediaAcceptanceTemplate.requiredExerciseCount;
    index++
  )
    'exercise-$index',
];

B05MediaManifest _manifest(Iterable<String> exerciseIds) => B05MediaManifest(
  pack: const B05MediaPackContract(
    packId: 'approved-top-20',
    manifestIdentity: 'manifest-v1',
    contentVersion: '1.0.0',
    checksumAlgorithm: 'sha256',
    sourceLicense: 'test-license',
    attribution: 'test-attribution',
    distributionRights: 'test-rights',
    offlineFallbackId: 'test-stills',
    reducedMotionFallbackId: 'test-text',
  ),
  assets: [for (final id in exerciseIds) _mediaAsset(id)],
);

B05MediaAssetContract _mediaAsset(
  String exerciseId, {
  String checksum =
      'sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
}) => B05MediaAssetContract(
  exerciseId: exerciseId,
  assetId: 'clip-$exerciseId',
  checksum: checksum,
  sourceLicense: 'test-license',
  attribution: 'test-attribution',
  distributionRights: 'test-rights',
  stillFallbackId: 'still-$exerciseId',
  reducedMotionFallbackId: 'text-$exerciseId',
);

class _StaticMediaManifestSource implements B05MediaManifestSource {
  final B05MediaManifest manifest;

  const _StaticMediaManifestSource(this.manifest);

  @override
  Future<B05MediaManifest> load() async => manifest;
}

class _MutableMediaManifestSource implements B05MediaManifestSource {
  B05MediaManifest? manifest;
  Object? error;

  @override
  Future<B05MediaManifest?> load() async {
    final failure = error;
    if (failure != null) throw failure;
    return manifest;
  }
}

class _MapAssetBundle extends CachingAssetBundle {
  final Map<String, Uint8List> assets;

  _MapAssetBundle([Map<String, List<int>> values = const {}])
    : assets = {
        for (final entry in values.entries)
          entry.key: Uint8List.fromList(entry.value),
      };

  @override
  Future<ByteData> load(String key) async {
    final bytes = assets[key];
    if (bytes == null) throw FlutterError('Missing test asset $key');
    return ByteData.sublistView(bytes);
  }
}

B05PlaylistProviderRegistry _playlistRegistry() => B05PlaylistProviderRegistry([
  B05PlaylistProviderContract(
    id: 'spotify',
    permittedUriSchemes: {'spotify'},
    permittedHttpsHosts: {'open.spotify.com'},
    acceptedPathPattern: RegExp(r'^/playlist/[A-Za-z0-9_-]+$'),
    disallowedQueryParameters: {'si'},
  ),
]);
