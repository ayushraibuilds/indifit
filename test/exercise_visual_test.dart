import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b05_third_party_asset_manifest.dart';
import 'package:indifit/core/fixtures/exercise_identity_fixtures.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/theme/indifit_icons.dart';
import 'package:indifit/features/media/b05_exercise_visual_registry.dart';
import 'package:indifit/features/media/b05_media_bundle.dart';
import 'package:indifit/features/media/indifit_muscle_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'production registry uses exact UUIDs and excludes all five rejected families',
    () {
      final registry = B05ExerciseVisualRegistry.fromProvenance(
        B05ThirdPartyAssetManifest.fromJson(_manifestJson()),
      );

      expect(registry.bindingCount, 120);
      expect(registry.assetSetCount, 30);
      for (final name in [
        'decline hammer strength press',
        'seated leg curl',
        'standing calf raise',
        'walking lunges',
        'hanging leg raise',
      ]) {
        final uuid = ExerciseCatalogManifest.goldenCatalogUuids[name]!;
        expect(registry.lookup(uuid), isNull, reason: name);
      }
      expect(
        registry.lookup(
          ExerciseCatalogManifest
              .goldenCatalogUuids['flat barbell bench press']!,
        ),
        isNotNull,
      );
      expect(registry.lookup('Flat Barbell Bench Press'), isNull);
      expect(registry.lookup(''), isNull);

      final plank = registry.lookup(
        ExerciseCatalogManifest.goldenCatalogUuids['plank']!,
      );
      expect(plank, isNotNull);
      expect(plank!.mediaByRole.keys, {'main'});
      expect(
        plank.assetFor(ExerciseVisualPose.start),
        plank.mediaByRole['main'],
      );
    },
  );

  test(
    'B05 media adapter derives visual sets from the provenance authority',
    () async {
      final source = B05AssetBundleThirdPartyMediaManifestSource(
        bundle: _MapAssetBundle({
          'manifest.json': utf8.encode(
            File('assets/third_party/asset_manifest.json').readAsStringSync(),
          ),
        }),
        manifestAssetPath: 'manifest.json',
      );

      final manifest = await source.load();

      expect(manifest, isNotNull);
      expect(manifest!.assets, hasLength(59));
      expect(manifest.visualAssetSets, hasLength(30));
      expect(
        manifest.visualAssetSets
            .expand((set) => set.canonicalExerciseUuids)
            .toSet(),
        hasLength(120),
      );
      B05MediaManifestValidator(
        manifest.visualAssetSets
            .expand((set) => set.canonicalExerciseUuids)
            .toSet(),
      ).validate(manifest);
    },
  );

  testWidgets('approved acquired asset renders the requested static pose', (
    tester,
  ) async {
    final bytes = _syntheticPngBytes;
    final registry = _syntheticRegistry(bytes, pair: true);
    await tester.pumpWidget(
      _app(
        ExerciseVisual(
          canonicalExerciseUuid: _knownUuid,
          registry: registry,
          pose: ExerciseVisualPose.peak,
          assetBundle: _MapAssetBundle({'synthetic-peak.webp': bytes}),
          semanticsContext: 'Flat barbell bench press illustration',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(
      find.bySemanticsLabel('Flat barbell bench press illustration'),
      findsOneWidget,
    );
  });

  testWidgets('canonical UUID supplies a meaningful default image semantic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ExerciseVisual(
          canonicalExerciseUuid: _knownUuid,
          registry: _syntheticRegistry(_syntheticPngBytes, pair: false),
          assetBundle: _MapAssetBundle({
            'synthetic-main.webp': _syntheticPngBytes,
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Flat Barbell Bench Press exercise illustration'),
      findsOneWidget,
    );
  });

  testWidgets(
    'MAIN-only artwork is reused for any requested pose without looping',
    (tester) async {
      final bytes = _syntheticPngBytes;
      final registry = _syntheticRegistry(bytes, pair: false);
      await tester.pumpWidget(
        _app(
          ExerciseVisual(
            canonicalExerciseUuid: _knownUuid,
            registry: registry,
            pose: ExerciseVisualPose.peak,
            assetBundle: _MapAssetBundle({'synthetic-main.webp': bytes}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(AnimatedSwitcher), findsNothing);
    },
  );

  testWidgets('missing approved local media falls through to the muscle map', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ExerciseVisual(
          canonicalExerciseUuid: _knownUuid,
          registry: _syntheticRegistry(_syntheticPngBytes, pair: false),
          displayMuscles: const ExerciseVisualMuscleFacts(
            primaryMuscle: 'Chest',
          ),
          assetBundle: _MapAssetBundle(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(find.byType(IndiFitMuscleMap), findsOneWidget);
  });

  testWidgets(
    'muscle map falls through to semantic icon, then neutral fallback',
    (tester) async {
      await tester.pumpWidget(
        _app(
          ExerciseVisual(
            canonicalExerciseUuid: 'unknown-uuid',
            equipment: 'Barbell',
            assetBundle: _MapAssetBundle(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(IndiFitIcons.equipment), findsOneWidget);

      await tester.pumpWidget(
        _app(const ExerciseVisual(canonicalExerciseUuid: 'unknown-uuid')),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    },
  );

  testWidgets('decorative contexts suppress redundant announcements', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const ExerciseVisual(
          canonicalExerciseUuid: 'unknown-uuid',
          semanticsContext: 'Decorative exercise illustration',
          decorative: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Decorative exercise illustration'),
      findsNothing,
    );
  });
}

const _knownUuid = '089ec703-a25e-5b12-a39a-78b17ee33742';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(body: Center(child: child)),
);

B05ExerciseVisualRegistry _syntheticRegistry(
  List<int> bytes, {
  required bool pair,
}) {
  final checksum = 'sha256:${sha256.convert(bytes)}';
  final media = <String, B05ExerciseVisualAsset>{
    if (pair)
      'start': B05ExerciseVisualAsset(
        mediaRole: 'start',
        localPath: 'synthetic-start.webp',
        checksum: checksum,
      ),
    if (pair)
      'peak': B05ExerciseVisualAsset(
        mediaRole: 'peak',
        localPath: 'synthetic-peak.webp',
        checksum: checksum,
      ),
    if (!pair)
      'main': B05ExerciseVisualAsset(
        mediaRole: 'main',
        localPath: 'synthetic-main.webp',
        checksum: checksum,
      ),
  };
  return B05ExerciseVisualRegistry.fromAssetSets([
    B05ExerciseVisualAssetSet(
      assetSetId: 'synthetic-set',
      canonicalExerciseUuids: const {_knownUuid},
      mediaByRole: media,
      techniqueDisclosure: 'Synthetic test disclosure.',
    ),
  ]);
}

Map<String, dynamic> _manifestJson() =>
    jsonDecode(
          File('assets/third_party/asset_manifest.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

final _syntheticPngBytes = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  248,
  207,
  192,
  240,
  31,
  0,
  5,
  0,
  1,
  255,
  137,
  153,
  61,
  29,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];

class _MapAssetBundle extends CachingAssetBundle {
  final Map<String, List<int>> values;

  _MapAssetBundle([Map<String, List<int>>? values])
    : values = values ?? const {};

  @override
  Future<ByteData> load(String key) async {
    final bytes = values[key];
    if (bytes == null) throw FlutterError('Missing synthetic asset $key');
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}
