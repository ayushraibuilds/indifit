import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b02_muscle_catalog.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/features/media/indifit_muscle_map.dart';
import 'package:indifit/features/media/indifit_muscle_map_geometry.g.dart';
import 'package:indifit/features/media/indifit_muscle_map_showcase.dart';
import 'package:indifit/features/media/indifit_muscle_map_taxonomy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const adapter = IndiFitMuscleMapTaxonomyAdapter();

  group('local MuscleMap geometry registry', () {
    test('contains all four pinned body views with deterministic IDs', () {
      expect(
        IndiFitMuscleMapGeometryRegistry.upstreamCommit,
        '7dc03071e03052e8bd4f6351e9176994cd28aa7d',
      );
      expect(IndiFitMuscleMapGeometryRegistry.upstreamTag, '1.6.4');
      expect(IndiFitMuscleMapGeometryRegistry.viewBoxes.keys, {
        'male_front',
        'male_back',
        'female_front',
        'female_back',
      });
      expect(IndiFitMuscleMapGeometryRegistry.regions.length, 86);

      final ids = IndiFitMuscleMapGeometryRegistry.regions
          .map((region) => region.regionId)
          .toList(growable: false);
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, contains('male_front_chest'));
      expect(ids, contains('male_back_upper-back'));
      expect(ids, contains('female_front_quadriceps'));
      expect(ids, contains('female_back_gluteal'));
    });

    test('every region has valid paths within its source view box', () {
      for (final region in IndiFitMuscleMapGeometryRegistry.regions) {
        expect(region.paths, isNotEmpty, reason: region.regionId);
        final viewBox =
            IndiFitMuscleMapGeometryRegistry
                .viewBoxes[IndiFitMuscleMapGeometryRegistry.viewBoxKey(
              region.bodyModel,
              region.side,
            )]!;
        final bounds = region.toPath().getBounds();
        expect(bounds.isFinite, isTrue, reason: region.regionId);
        const tolerance = 12.0;
        expect(
          bounds.left,
          greaterThanOrEqualTo(viewBox.originX - tolerance),
          reason: region.regionId,
        );
        expect(
          bounds.top,
          greaterThanOrEqualTo(viewBox.originY - tolerance),
          reason: region.regionId,
        );
        expect(
          bounds.right,
          lessThanOrEqualTo(viewBox.originX + viewBox.width + tolerance),
          reason: region.regionId,
        );
        expect(
          bounds.bottom,
          lessThanOrEqualTo(viewBox.originY + viewBox.height + tolerance),
          reason: region.regionId,
        );
      }
    });

    test('front and back collections are non-empty for both body models', () {
      for (final body in IndiFitMuscleMapBodyModel.values) {
        for (final side in IndiFitMuscleMapSide.values) {
          expect(
            IndiFitMuscleMapGeometryRegistry.forView(body, side),
            isNotEmpty,
            reason: '${body.name}/${side.name}',
          );
        }
      }
    });
  });

  group('one-way taxonomy adapter', () {
    test('maps broad concepts explicitly to deliberate region sets', () {
      final back = adapter.resolveExercise(primary: 'Back');
      expect(back.primarySlugs, {'upper-back', 'lower-back', 'trapezius'});

      final core = adapter.resolveExercise(primary: 'Core');
      expect(core.primarySlugs, {'abs', 'obliques'});

      final shoulders = adapter.resolveExercise(primary: 'Shoulders');
      expect(shoulders.primarySlugs, {'deltoids', 'front-deltoid'});

      final legs = adapter.resolveExercise(primary: 'Legs');
      expect(legs.primarySlugs, {'quadriceps', 'inner-quad', 'outer-quad'});

      final b02Aliases = adapter.resolveExercise(
        primary: 'glute-maximus',
        secondary: const ['Quadriceps', 'Triceps'],
      );
      expect(b02Aliases.primarySlugs, {'gluteal'});
      expect(
        b02Aliases.secondarySlugs,
        containsAll({'quadriceps', 'inner-quad', 'outer-quad', 'triceps'}),
      );
    });

    test(
      'supports exactly current display concepts and existing B02 labels',
      () {
        expect(
          IndiFitMuscleMapTaxonomyAdapter.supportedConceptToGeometry.keys,
          {
            'back',
            'biceps',
            'calves',
            'chest',
            'core',
            'glute-maximus',
            'gluteus maximus',
            'glutes',
            'hamstrings',
            'legs',
            'quadriceps',
            'shoulders',
            'triceps',
          },
        );
      },
    );

    test('every mapped output exists in the pinned geometry registry', () {
      final geometrySlugs = IndiFitMuscleMapGeometryRegistry.regions
          .map((region) => region.upstreamSlug)
          .toSet();
      for (final entry
          in IndiFitMuscleMapTaxonomyAdapter
              .supportedConceptToGeometry
              .entries) {
        expect(
          geometrySlugs,
          containsAll(entry.value),
          reason: 'Unsupported geometry target for ${entry.key}',
        );
      }
    });

    test('geometry-derived and speculative aliases remain unresolved', () {
      const removedAliases = [
        'Abs',
        'Abdominals',
        'Calf',
        'Deltoids',
        'Feet',
        'Forearm',
        'Forearms',
        'Hamstring',
        'Hip flexors',
        'hip-flexors',
        'Lower back',
        'lower-back',
        'Neck',
        'Obliques',
        'Quads',
        'Rear deltoids',
        'rear-deltoid',
        'Rhomboids',
        'Rotator cuff',
        'rotator-cuff',
        'Traps',
        'Trapezius',
        'Upper back',
        'upper-back',
      ];
      for (final alias in removedAliases) {
        final resolution = adapter.resolveExercise(primary: alias);
        expect(resolution.primarySlugs, isEmpty, reason: alias);
        expect(resolution.unresolvedMuscles, [alias], reason: alias);
      }
    });

    test('primary wins when a concept also appears as secondary', () {
      final resolution = adapter.resolveExercise(
        primary: 'Chest',
        secondary: const ['Chest', 'Triceps'],
      );
      expect(
        resolution.primarySlugs,
        containsAll({'chest', 'upper-chest', 'lower-chest'}),
      );
      expect(resolution.secondarySlugs, isNot(contains('chest')));
      expect(resolution.secondarySlugs, contains('triceps'));
    });

    test('unknown and substring-like input remain unresolved', () {
      final resolution = adapter.resolveExercise(
        primary: 'Chesticle',
        secondary: const ['backside'],
      );
      expect(resolution.primarySlugs, isEmpty);
      expect(resolution.secondarySlugs, isEmpty);
      expect(
        resolution.unresolvedMuscles,
        containsAll(['Chesticle', 'backside']),
      );
    });

    test(
      'heat values are caller-owned and missing values are not fabricated',
      () {
        final resolution = adapter.resolveHeat({
          'Chest': 0.25,
          'Back': 0.8,
          'unknown': double.nan,
        });
        expect(resolution.regionIntensities['chest'], 0.25);
        expect(resolution.regionIntensities['upper-back'], 0.8);
        expect(resolution.regionIntensities.containsKey('unknown'), isFalse);
        expect(
          resolution.unresolvedMuscles,
          contains('unknown (invalid intensity)'),
        );
        expect(resolution.regionIntensities.containsKey('triceps'), isFalse);
      },
    );

    test('adapter does not mutate B02 canonical catalog', () {
      final before = B02CanonicalMuscleCatalog.muscles
          .map((entry) => '${entry.id}:${entry.displayName}')
          .toList(growable: false);
      adapter.resolveExercise(
        primary: 'Back',
        secondary: const ['Shoulders', 'Hamstrings'],
      );
      final after = B02CanonicalMuscleCatalog.muscles
          .map((entry) => '${entry.id}:${entry.displayName}')
          .toList(growable: false);
      expect(after, before);
      expect(
        B02CanonicalMuscleCatalog.muscles.map((entry) => entry.id),
        containsAll(['chest', 'glute-maximus', 'quadriceps', 'triceps']),
      );
    });
  });

  group('widget states and accessibility', () {
    testWidgets('exercise mode exposes primary and secondary text', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _testApp(
          const IndiFitMuscleMap.exercise(
            primaryMuscle: 'Chest',
            secondaryMuscles: ['Triceps', 'Shoulders'],
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CustomPaint), findsAtLeastNWidgets(2));
      expect(find.textContaining('Primary muscle: Chest.'), findsOneWidget);
      expect(
        find.textContaining('Secondary muscles: Triceps, Shoulders.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('IndiFit muscle map'), findsOneWidget);
      final node = tester.getSemantics(
        find.bySemanticsLabel('IndiFit muscle map'),
      );
      expect(node.value, contains('Primary muscle: Chest.'));
      expect(node.value, contains('Secondary muscles: Triceps, Shoulders.'));
      expect(
        node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
        isFalse,
      );
      semantics.dispose();
    });

    testWidgets('unknown and no-data states stay neutral and truthful', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          const IndiFitMuscleMap.exercise(primaryMuscle: 'Imaginary muscle'),
        ),
      );
      await tester.pump();
      expect(
        find.textContaining('Unresolved muscle concepts: Imaginary muscle.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('No local geometry is highlighted.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_testApp(const IndiFitMuscleMap.noData()));
      await tester.pump();
      expect(find.textContaining('no reviewed muscle data'), findsOneWidget);
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(2));
    });

    testWidgets('heat mode reports supplied values without interpretation', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          const IndiFitMuscleMap.intensity(
            intensityValues: {'Chest': 0.5, 'unknown': 0.9},
            metricLabel: 'Caller metric',
            view: IndiFitMuscleMapView.front,
          ),
        ),
      );
      await tester.pump();
      expect(
        find.textContaining('Caller metric: Chest: 50%, unknown: 90%.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Unresolved muscle concepts: unknown.'),
        findsOneWidget,
      );
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });

    testWidgets('empty heat input and explicit zero remain distinct', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          const IndiFitMuscleMap.intensity(
            intensityValues: {},
            metricLabel: 'Caller metric',
            view: IndiFitMuscleMapView.front,
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('no reviewed intensity data'), findsOneWidget);

      await tester.pumpWidget(
        _testApp(
          const IndiFitMuscleMap.intensity(
            intensityValues: {'Chest': 0},
            metricLabel: 'Caller metric',
            view: IndiFitMuscleMapView.front,
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Caller metric: Chest: 0%.'), findsOneWidget);
      expect(find.textContaining('no reviewed intensity data'), findsNothing);
    });

    testWidgets('showcase is isolated and renders without production routing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: IndiFitMuscleMapShowcase()),
        ),
      );
      await tester.pump();
      expect(find.text('Local IndiFit Muscle Map'), findsOneWidget);
      expect(find.byType(IndiFitMuscleMap), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'compact and larger widths preserve layout without exceptions',
      (tester) async {
        for (final width in [240.0, 320.0, 360.0, 430.0, 720.0]) {
          tester.view.physicalSize = ui.Size(width, 1100);
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(
            _testApp(
              const IndiFitMuscleMap.exercise(
                primaryMuscle: 'Back',
                secondaryMuscles: ['Biceps'],
                view: IndiFitMuscleMapView.both,
                bodyModel: IndiFitMuscleMapBody.female,
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'width $width');
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets('bounded both-view layout keeps intrinsic height', (
      tester,
    ) async {
      tester.view.physicalSize = const ui.Size(430, 760);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: IndiFitMuscleMap.exercise(
                  primaryMuscle: 'Biceps',
                  secondaryMuscles: ['Triceps'],
                  view: IndiFitMuscleMapView.both,
                  showTextEquivalent: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(IndiFitMuscleMap)).height,
        lessThan(500),
      );
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('bounded single female view does not overflow', (tester) async {
      tester.view.physicalSize = const ui.Size(360, 760);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: IndiFitMuscleMap.exercise(
                primaryMuscle: 'Hamstrings',
                secondaryMuscles: ['Glutes'],
                view: IndiFitMuscleMapView.back,
                bodyModel: IndiFitMuscleMapBody.female,
                showTextEquivalent: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(IndiFitMuscleMap)).height,
        lessThan(728),
      );
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('both-view large text remains one concise semantic graphic', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _testApp(
          const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: IndiFitMuscleMap.exercise(
              primaryMuscle: 'Chest',
              secondaryMuscles: ['Triceps', 'Shoulders'],
              view: IndiFitMuscleMapView.both,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('IndiFit muscle map'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  group('representative goldens', () {
    testWidgets('male front light primary and secondary', (tester) async {
      _setGoldenViewport(tester);
      await tester.pumpWidget(
        _testApp(
          const IndiFitMuscleMap.exercise(
            primaryMuscle: 'Chest',
            secondaryMuscles: ['Triceps', 'Shoulders'],
            view: IndiFitMuscleMapView.front,
            bodyModel: IndiFitMuscleMapBody.male,
          ),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byKey(const ValueKey<String>('indifit_muscle_map_male_front')),
        matchesGoldenFile('goldens/indifit_muscle_map_male_front_light.png'),
      );
    });

    testWidgets('male back dark broad mapping', (tester) async {
      _setGoldenViewport(tester);
      await tester.pumpWidget(
        _testApp(
          const IndiFitMuscleMap.exercise(
            primaryMuscle: 'Back',
            view: IndiFitMuscleMapView.back,
            bodyModel: IndiFitMuscleMapBody.male,
          ),
          theme: AppTheme.darkTheme,
        ),
      );
      await tester.pump();
      await expectLater(
        find.byKey(const ValueKey<String>('indifit_muscle_map_male_back')),
        matchesGoldenFile('goldens/indifit_muscle_map_male_back_dark.png'),
      );
    });

    testWidgets('female both light no-data', (tester) async {
      _setGoldenViewport(tester);
      await tester.pumpWidget(
        _testApp(
          const IndiFitMuscleMap.noData(
            view: IndiFitMuscleMapView.both,
            bodyModel: IndiFitMuscleMapBody.female,
          ),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byKey(const ValueKey<String>('indifit_muscle_map_both')),
        matchesGoldenFile('goldens/indifit_muscle_map_female_both_no_data.png'),
      );
    });

    testWidgets('female front dark heat', (tester) async {
      _setGoldenViewport(tester);
      await tester.pumpWidget(
        _testApp(
          const IndiFitMuscleMap.intensity(
            intensityValues: {'Chest': 0.9, 'Core': 0.45, 'Calves': 0.1},
            metricLabel: 'Caller heat',
            view: IndiFitMuscleMapView.front,
            bodyModel: IndiFitMuscleMapBody.female,
          ),
          theme: AppTheme.darkTheme,
        ),
      );
      await tester.pump();
      await expectLater(
        find.byKey(const ValueKey<String>('indifit_muscle_map_female_front')),
        matchesGoldenFile('goldens/indifit_muscle_map_female_front_heat.png'),
      );
    });

    testWidgets('female back light primary and secondary', (tester) async {
      _setGoldenViewport(tester);
      await tester.pumpWidget(
        _testApp(
          const IndiFitMuscleMap.exercise(
            primaryMuscle: 'Hamstrings',
            secondaryMuscles: ['Glutes'],
            view: IndiFitMuscleMapView.back,
            bodyModel: IndiFitMuscleMapBody.female,
          ),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byKey(const ValueKey<String>('indifit_muscle_map_female_back')),
        matchesGoldenFile(
          'goldens/indifit_muscle_map_female_back_exercise.png',
        ),
      );
    });
  });
}

Widget _testApp(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AppTheme.lightTheme,
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

void _setGoldenViewport(WidgetTester tester) {
  tester.view.physicalSize = const ui.Size(420, 760);
  tester.view.devicePixelRatio = 1;
}
