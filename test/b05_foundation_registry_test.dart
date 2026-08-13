import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b05_foundation_registry.dart';

void main() {
  test('dashboard registry normalizes known IDs deterministically', () {
    final registry = B05DashboardModuleRegistry([
      const B05DashboardModuleDescriptor(
        id: 'progress',
        defaultOrdinal: 0,
        label: 'Progress',
        collapsible: false,
      ),
      const B05DashboardModuleDescriptor(
        id: 'next',
        defaultOrdinal: 1,
        label: 'Next action',
      ),
      const B05DashboardModuleDescriptor(
        id: 'meal',
        defaultOrdinal: 2,
        label: 'Meal',
      ),
    ]);
    final normalized = registry.normalize([
      const B05DashboardModulePreferenceValue(
        moduleId: 'next',
        ordinal: 0,
        isVisible: true,
        isCollapsed: true,
      ),
      const B05DashboardModulePreferenceValue(
        moduleId: 'next',
        ordinal: 1,
        isVisible: false,
        isCollapsed: false,
      ),
      const B05DashboardModulePreferenceValue(
        moduleId: 'progress',
        ordinal: 0,
        isVisible: true,
        isCollapsed: true,
      ),
      const B05DashboardModulePreferenceValue(
        moduleId: 'unknown',
        ordinal: 0,
        isVisible: true,
        isCollapsed: false,
      ),
    ]);
    expect(normalized.map((value) => value.moduleId), [
      'next',
      'progress',
      'meal',
    ]);
    expect(normalized[0].isVisible, isTrue);
    expect(normalized[1].isCollapsed, isFalse);
  });

  test(
    'education, muscle and media contracts validate packaged registries',
    () async {
      final education = B05EducationContentRegistry([
        for (final topic in kB05RequiredLessonTopics)
          B05EducationContentDescriptor(
            contentId: 'lesson-$topic',
            version: '1',
            topic: topic,
            body: 'Lesson body',
            relevanceTags: {topic},
          ),
      ]);
      education.requireAllTopics();
      expect(
        B05EducationContentRegistry.fromJson(education.toJson()).lessons,
        hasLength(5),
      );

      final visual = B05MuscleVisualRegistry([
        const B05MuscleDiagramRegion(
          regionId: 'region-1',
          muscleId: 'b02-chest',
          label: 'Chest',
          textOrder: 0,
        ),
      ]);
      expect(
        B05MuscleVisualRegistry.fromJson(visual.toJson()).regions,
        hasLength(1),
      );

      const pack = B05MediaPackContract(
        packId: 'top-20',
        manifestIdentity: 'sha256:manifest',
        contentVersion: '1',
        checksumAlgorithm: 'sha256',
        sourceLicense: 'CC-BY-4.0',
        attribution: 'IndiFit',
        distributionRights: 'bundled-offline',
        offlineFallbackId: 'top-20-still',
        reducedMotionFallbackId: 'top-20-text',
      );
      final manifest = B05MediaManifest(
        pack: pack,
        assets: [
          const B05MediaAssetContract(
            exerciseId: 'exercise-1',
            assetId: 'clip-1',
            checksum:
                'sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
            sourceLicense: 'CC-BY-4.0',
            attribution: 'IndiFit',
            distributionRights: 'bundled-offline',
            stillFallbackId: 'still-1',
            reducedMotionFallbackId: 'text-1',
          ),
        ],
      );
      manifest.validateStructure();
      final reconciler = const B05MediaPackReconciler();
      expect(
        (await reconciler.reconcile(
          manifest,
          probe: (_) async => B05MediaAssetCheckResult.available,
        )).state,
        B05MediaAvailabilityState.available,
      );
      expect(
        (await reconciler.reconcile(
          manifest,
          probe: (_) async => B05MediaAssetCheckResult.absent,
        )).state,
        B05MediaAvailabilityState.absent,
      );
      expect(
        (await reconciler.reconcile(
          manifest,
          probe: (_) async => B05MediaAssetCheckResult.invalid,
        )).state,
        B05MediaAvailabilityState.invalid,
      );
    },
  );

  test('playlist providers normalize only their typed routes', () {
    final registry = B05PlaylistProviderRegistry([
      B05PlaylistProviderContract(
        id: 'spotify',
        permittedUriSchemes: {'spotify'},
        permittedHttpsHosts: {'open.spotify.com'},
        disallowedQueryParameters: {'si'},
      ),
    ]);

    final custom = registry.normalize('spotify', 'spotify://playlist/abc');
    expect(custom.normalizedReference, 'spotify://playlist/abc');
    expect(custom.launchUri.scheme, 'spotify');

    final https = registry.normalize(
      'spotify',
      'https://OPEN.SPOTIFY.COM/playlist/abc?utm_source=indi',
    );
    expect(
      https.normalizedReference,
      'https://open.spotify.com/playlist/abc?utm_source=indi',
    );
    expect(https.launchUri.host, 'open.spotify.com');

    expect(
      () => registry.normalize('spotify', 'https://example.com/playlist/abc'),
      throwsA(
        isA<B05RegistryValidationException>().having(
          (error) => error.code,
          'code',
          'playlist_provider_route',
        ),
      ),
    );
    expect(
      () => registry.normalize(
        'spotify',
        'https://open.spotify.com/playlist/abc?si=secret',
      ),
      throwsA(isA<B05RegistryValidationException>()),
    );
    expect(
      () => registry.normalize(
        'spotify',
        'https://open.spotify.com/playlist/abc?x=1&x=2',
      ),
      throwsA(isA<B05RegistryValidationException>()),
    );
  });

  test('media manifest contract is versioned and excludes physical state', () {
    final contract = B05MediaPackContract.fromJson({
      'pack_id': 'exercise-top-20',
      'manifest_identity': 'sha256:manifest-1',
      'content_version': '1.0.0',
      'checksum_algorithm': 'sha256',
      'source_license': 'CC-BY-4.0',
      'attribution': 'IndiFit exercise team',
      'distribution_rights': 'bundled-offline',
      'offline_fallback_id': 'exercise-top-20-still',
      'reduced_motion_fallback_id': 'exercise-top-20-text',
    });
    final json = contract.toJson();
    expect(json['contract_version'], kB05MediaManifestContractVersion);
    expect(B05MediaAcceptanceTemplate.maxBundledPackageBytes, greaterThan(0));
    expect(
      B05MediaAcceptanceTemplate.checksumFormat,
      'sha256:<64 hexadecimal characters>',
    );
    expect(json, isNot(contains('file_path')));
    expect(json, isNot(contains('availability')));
    expect(json, isNot(contains('bytes')));
  });
}
