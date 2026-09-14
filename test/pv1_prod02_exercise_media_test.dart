import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b05_third_party_asset_manifest.dart';
import 'package:indifit/core/fixtures/exercise_identity_fixtures.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/features/exercise_library/exercise_details_sheet.dart';
import 'package:indifit/features/exercise_library/exercise_library_screen.dart';
import 'package:indifit/features/media/b05_exercise_visual_registry.dart';
import 'package:indifit/features/media/indifit_muscle_map.dart';
import 'package:indifit/features/workout_player/workout_player_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final manifestJson = jsonDecode(
    File('assets/third_party/asset_manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final provenanceManifest = B05ThirdPartyAssetManifest.fromJson(manifestJson);
  final registry = B05ExerciseVisualRegistry.fromProvenance(provenanceManifest);

  final benchPressUuid =
      ExerciseCatalogManifest.goldenCatalogUuids['flat barbell bench press']!;
  final plankUuid =
      ExerciseCatalogManifest.goldenCatalogUuids['plank']!;
  const unapprovedUuid = '00000000-0000-0000-0000-000000000000';

  final benchPressExercise = Exercise(
    id: 1,
    stableId: benchPressUuid,
    name: 'Flat Barbell Bench Press',
    muscleGroups: 'Chest,Triceps,Shoulders',
    equipment: 'Barbell',
    difficulty: 'Intermediate',
    formCues: 'Keep feet flat on floor\nLower bar to chest',
    commonMistakes: 'Flaring elbows',
    isCustom: false,
  );

  final plankExercise = Exercise(
    id: 2,
    stableId: plankUuid,
    name: 'Plank',
    muscleGroups: 'Abs,Lower Back',
    equipment: 'Bodyweight',
    difficulty: 'Beginner',
    formCues: 'Keep body in straight line',
    commonMistakes: 'Sagging hips',
    isCustom: false,
  );

  const customExercise = Exercise(
    id: 3,
    stableId: unapprovedUuid,
    name: 'Custom Movement',
    muscleGroups: 'Legs',
    equipment: 'Dumbbells',
    difficulty: 'Intermediate',
    formCues: 'Stay balanced',
    commonMistakes: 'Rounding back',
    isCustom: true,
  );

  group('PV1-PROD-02: Provenance Manifest & Legal Distribution Contract', () {
    test('manifest has exactly 59 assets, 30 sets, 120 bindings, and pinned commit', () {
      expect(provenanceManifest.assets, hasLength(59));
      expect(provenanceManifest.visualAssetSets, hasLength(30));
      expect(registry.assetSetCount, 30);
      expect(registry.bindingCount, 120);

      expect(
        provenanceManifest.sources.first.immutableCommit,
        '045845b61e4aefd9e684fa84518b84c665ea3cd3',
      );
    });

    test('excludes all 5 rejected families and keeps plank as single MAIN role', () {
      const rejectedFamilies = [
        'decline hammer strength press',
        'seated leg curl',
        'standing calf raise',
        'walking lunges',
        'hanging leg raise',
      ];

      for (final name in rejectedFamilies) {
        final uuid = ExerciseCatalogManifest.goldenCatalogUuids[name]!;
        expect(registry.lookup(uuid), isNull, reason: 'Family $name must be rejected');
      }

      final plank = registry.lookup(plankUuid);
      expect(plank, isNotNull);
      expect(plank!.mediaByRole.keys, {'main'});
      expect(plank.techniqueDisclosure, isNotEmpty);

      final bench = registry.lookup(benchPressUuid);
      expect(bench, isNotNull);
      expect(bench!.mediaByRole.keys, {'start', 'peak'});
      expect(bench.techniqueDisclosure, isNotEmpty);
    });

    test('every approved asset has non-empty technique disclosure and exact sha256 checksums', () {
      for (final asset in provenanceManifest.assets) {
        expect(asset.checksum, startsWith('sha256:'));
        expect(asset.checksum.length, 7 + 64);
        expect(asset.localDestination, startsWith('assets/generated/repdb/'));
        expect(asset.localDestination, endsWith('.webp'));
      }

      for (final set in provenanceManifest.visualAssetSets) {
        expect(set.techniqueDisclosure.text.trim(), isNotEmpty);
        expect(set.canonicalExerciseUuids, isNotEmpty);
      }
    });

    test('public repo cleanliness: zero tracked WebPs and gitignore probe passes', () async {
      final trackedResult = await Process.run('git', ['ls-files', '--cached']);
      expect(trackedResult.exitCode, 0);
      final trackedWebPs = '${trackedResult.stdout}'
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.toLowerCase().endsWith('.webp'))
          .toList();
      expect(
        trackedWebPs,
        isEmpty,
        reason: 'No raw WebPs may ever be committed to git',
      );

      final ignoreResult = await Process.run('git', [
        'check-ignore',
        '--no-index',
        '-q',
        'assets/generated/repdb/probe.webp',
      ]);
      expect(
        ignoreResult.exitCode,
        0,
        reason: 'assets/generated/repdb/*.webp must be gitignored',
      );
    });
  });

  group('PV1-PROD-02: ExerciseDetailsSheet Interactive Pose & Disclosure', () {
    testWidgets('approved multi-pose exercise displays Start/Peak switcher and technique disclosure', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            b05ExerciseVisualRegistryProvider.overrideWith(
              (ref) async => registry,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: ExerciseDetailsSheet(exercise: benchPressExercise),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify technique disclosure text is displayed
      final set = registry.lookup(benchPressUuid)!;
      expect(find.text(set.techniqueDisclosure), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Technique disclosure',
        ),
        findsOneWidget,
      );

      // Verify SegmentedButton for Start / Peak is displayed
      expect(find.byType(SegmentedButton<ExerciseVisualPose>), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Peak'), findsOneWidget);

      // Verify initial pose is Start
      final initialVisual = tester.widget<ExerciseVisual>(
        find.byType(ExerciseVisual),
      );
      expect(initialVisual.pose, ExerciseVisualPose.start);
      expect(
        initialVisual.semanticsContext,
        'Flat Barbell Bench Press start position illustration',
      );

      // Tap 'Peak' segment
      await tester.tap(find.text('Peak'));
      await tester.pumpAndSettle();

      // Verify pose changed to Peak
      final updatedVisual = tester.widget<ExerciseVisual>(
        find.byType(ExerciseVisual),
      );
      expect(updatedVisual.pose, ExerciseVisualPose.peak);
      expect(
        updatedVisual.semanticsContext,
        'Flat Barbell Bench Press peak position illustration',
      );

      // Tap 'Start' segment
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      final revertedVisual = tester.widget<ExerciseVisual>(
        find.byType(ExerciseVisual),
      );
      expect(revertedVisual.pose, ExerciseVisualPose.start);
      expect(
        revertedVisual.semanticsContext,
        'Flat Barbell Bench Press start position illustration',
      );
    });

    testWidgets('single-pose (Plank) exercise shows disclosure but hides SegmentedButton', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            b05ExerciseVisualRegistryProvider.overrideWith(
              (ref) async => registry,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: ExerciseDetailsSheet(exercise: plankExercise),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final set = registry.lookup(plankUuid)!;
      expect(find.text(set.techniqueDisclosure), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Technique disclosure',
        ),
        findsOneWidget,
      );
      expect(find.byType(SegmentedButton<ExerciseVisualPose>), findsNothing);

      final visual = tester.widget<ExerciseVisual>(find.byType(ExerciseVisual));
      expect(visual.semanticsContext, 'Plank exercise visual');
    });

    testWidgets('unapproved or custom exercise shows neither SegmentedButton nor disclosure', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            b05ExerciseVisualRegistryProvider.overrideWith(
              (ref) async => registry,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: ExerciseDetailsSheet(exercise: customExercise),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<ExerciseVisualPose>), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Technique disclosure',
        ),
        findsNothing,
      );

      // Falls back to MuscleMap without crash
      expect(find.byType(IndiFitMuscleMap), findsOneWidget);
    });
  });

  group('PV1-PROD-02: ExerciseLibraryScreen Thumbnail CacheWidth & Semantics', () {
    testWidgets('list thumbnails enforce decorative=true and DPR-bounded cacheWidth', (
      tester,
    ) async {
      final mockRepo = _SimpleWorkoutRepo([benchPressExercise, plankExercise]);

      Future<void> pumpWithDpr(double dpr) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              workoutRepositoryProvider.overrideWithValue(mockRepo),
              b05ExerciseVisualRegistryProvider.overrideWith(
                (ref) async => registry,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: MediaQuery(
                data: MediaQueryData(devicePixelRatio: dpr),
                child: const ExerciseLibraryScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      // DPR = 1.0 -> (44 * 1.0).round().clamp(88, 264) = 88
      await pumpWithDpr(1.0);
      final visualsDpr1 = tester.widgetList<ExerciseVisual>(find.byType(ExerciseVisual));
      expect(visualsDpr1, isNotEmpty);
      for (final visual in visualsDpr1) {
        expect(visual.decorative, isTrue);
        expect(visual.cacheWidth, 88);
      }

      // DPR = 3.0 -> (44 * 3.0).round().clamp(88, 264) = 132
      await pumpWithDpr(3.0);
      final visualsDpr3 = tester.widgetList<ExerciseVisual>(find.byType(ExerciseVisual));
      expect(visualsDpr3, isNotEmpty);
      for (final visual in visualsDpr3) {
        expect(visual.decorative, isTrue);
        expect(visual.cacheWidth, 132);
      }

      // DPR = 8.0 -> (44 * 8.0).round().clamp(88, 264) = 264 (clamped)
      await pumpWithDpr(8.0);
      final visualsDpr8 = tester.widgetList<ExerciseVisual>(find.byType(ExerciseVisual));
      expect(visualsDpr8, isNotEmpty);
      for (final visual in visualsDpr8) {
        expect(visual.decorative, isTrue);
        expect(visual.cacheWidth, 264);
      }
    });

    testWidgets('details sheet banner cacheWidth scales with DPR within [220, 720]', (
      tester,
    ) async {
      Future<void> pumpDetailsWithDpr(double dpr) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              b05ExerciseVisualRegistryProvider.overrideWith(
                (ref) async => registry,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: MediaQuery(
                data: MediaQueryData(devicePixelRatio: dpr),
                child: Scaffold(
                  body: ExerciseDetailsSheet(exercise: benchPressExercise),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      // DPR = 1.0 -> (110 * 1.5 * 1.0).round().clamp(220, 720) = 220 (clamped from 165)
      await pumpDetailsWithDpr(1.0);
      final visualDpr1 = tester.widget<ExerciseVisual>(find.byType(ExerciseVisual));
      expect(visualDpr1.cacheWidth, 220);

      // DPR = 2.0 -> (110 * 1.5 * 2.0).round().clamp(220, 720) = 330
      await pumpDetailsWithDpr(2.0);
      final visualDpr2 = tester.widget<ExerciseVisual>(find.byType(ExerciseVisual));
      expect(visualDpr2.cacheWidth, 330);

      // DPR = 3.0 -> (110 * 1.5 * 3.0).round().clamp(220, 720) = 495
      await pumpDetailsWithDpr(3.0);
      final visualDpr3 = tester.widget<ExerciseVisual>(find.byType(ExerciseVisual));
      expect(visualDpr3.cacheWidth, 495);

      // DPR = 5.0 -> (110 * 1.5 * 5.0).round().clamp(220, 720) = 720 (clamped from 825)
      await pumpDetailsWithDpr(5.0);
      final visualDpr5 = tester.widget<ExerciseVisual>(find.byType(ExerciseVisual));
      expect(visualDpr5.cacheWidth, 720);
    });
  });
}

class _SimpleWorkoutRepo implements WorkoutRepository {
  final List<Exercise> _exercises;

  _SimpleWorkoutRepo(this._exercises);

  @override
  Future<List<Exercise>> searchExercises(String query) async => _exercises;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
