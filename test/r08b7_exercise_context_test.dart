import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/fixtures/b05_third_party_asset_manifest.dart';
import 'package:indifit/core/fixtures/exercise_display_muscles.dart';
import 'package:indifit/core/fixtures/exercise_identity_fixtures.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/widgets/b05_accessibility_primitives.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b07_exercise_context_repository.dart';
import 'package:indifit/data/services/b02_execution_progression.dart';
import 'package:indifit/features/media/b05_exercise_visual_registry.dart';
import 'package:indifit/features/media/indifit_muscle_map.dart';
import 'package:indifit/features/workout_player/widgets/b07_exercise_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('b07-bench'),
            name: 'Bench press',
            muscleGroups: 'Chest,Triceps',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Brace your feet\nKeep the bar path controlled',
            commonMistakes: 'Bouncing the bar',
          ),
        );
  });

  tearDown(() => db.close());

  test('context reads canonical fields by exact actual UUID only', () async {
    final repository = B07ExerciseContextRepository(db);

    final available = await repository.resolve('b07-bench');
    expect(available.status, B07ExerciseContextStatus.available);
    expect(available.context?.canonicalExerciseId, 'b07-bench');
    expect(available.context?.canonicalName, 'Bench press');
    expect(available.context?.equipment, 'Barbell');
    expect(available.context?.displayMuscles.primary, 'Chest');
    expect(available.context?.displayMuscles.secondary, ['Triceps']);
    expect(available.context?.formCues, [
      'Brace your feet',
      'Keep the bar path controlled',
    ]);
    expect(available.context?.commonMistakes, ['Bouncing the bar']);

    // A display name, alias, or a different canonical UUID cannot resolve the
    // row, even when the visible name is identical.
    expect(
      (await repository.resolve('Bench press')).status,
      B07ExerciseContextStatus.unavailable,
    );
    expect(
      (await repository.resolve('another-bench-id')).status,
      B07ExerciseContextStatus.unavailable,
    );
    expect(
      (await repository.resolve('')).status,
      B07ExerciseContextStatus.unavailable,
    );
  });

  test('query failure is distinct from a normal missing-context state', () {
    expect(
      const B07ExerciseContextResult.queryFailure().status,
      B07ExerciseContextStatus.queryFailure,
    );
    expect(
      const B07ExerciseContextResult.unavailable().status,
      B07ExerciseContextStatus.unavailable,
    );
  });

  test(
    'approved production registry stays exact and rejects frozen fallbacks',
    () {
      final manifest = B05ThirdPartyAssetManifest.fromJson(
        jsonDecode(
          File('assets/third_party/asset_manifest.json').readAsStringSync(),
        ),
      );
      final registry = B05ExerciseVisualRegistry.fromProvenance(manifest);

      expect(
        registry.lookup(
          ExerciseCatalogManifest
              .goldenCatalogUuids['flat barbell bench press']!,
        ),
        isNotNull,
      );
      for (final name in [
        'decline hammer strength press',
        'seated leg curl',
        'standing calf raise',
        'walking lunges',
        'hanging leg raise',
      ]) {
        expect(
          registry.lookup(ExerciseCatalogManifest.goldenCatalogUuids[name]!),
          isNull,
          reason: name,
        );
      }
      expect(registry.lookup('Bench press'), isNull);
    },
  );

  testWidgets('two-frame approved visual remains compact and labelled', (
    tester,
  ) async {
    final bytes = _syntheticPngBytes;
    await tester.pumpWidget(
      _app(
        B07ExerciseVisualRegion(
          canonicalExerciseId: 'b07-bench',
          exerciseNameSnapshot: 'Bench press',
          registry: _syntheticRegistry(pair: true),
          assetBundle: _MapAssetBundle({
            'synthetic-start.webp': bytes,
            'synthetic-peak.webp': bytes,
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start position'), findsOneWidget);
    expect(find.text('Peak position'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.textContaining('synthetic'), findsNothing);
    await expectLater(
      find.byType(B07ExerciseVisualRegion),
      matchesGoldenFile('goldens/r08b7_approved_pair.png'),
    );
  });

  testWidgets('MAIN-only visual renders one still and never invents a pair', (
    tester,
  ) async {
    final bytes = _syntheticPngBytes;
    await tester.pumpWidget(
      _app(
        B07ExerciseVisualRegion(
          canonicalExerciseId: 'b07-plank',
          exerciseNameSnapshot: 'Plank',
          registry: _syntheticRegistry(pair: false, canonicalId: 'b07-plank'),
          assetBundle: _MapAssetBundle({'synthetic-main.webp': bytes}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start position'), findsNothing);
    expect(find.text('Peak position'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('missing and corrupt local media fail closed to MuscleMap', (
    tester,
  ) async {
    final registry = _syntheticRegistry(pair: false);
    final contextData = _context(
      id: 'b07-bench',
      cues: const ['Keep the bar path controlled'],
    );

    await tester.pumpWidget(
      _app(
        B07ExerciseContextCard(
          canonicalExerciseId: 'b07-bench',
          exerciseNameSnapshot: 'Bench press',
          contextData: contextData,
          visualRegistry: registry,
          assetBundle: _MapAssetBundle(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.byType(IndiFitMuscleMap), findsOneWidget);
    expect(find.textContaining('assets/generated/repdb'), findsNothing);

    await tester.pumpWidget(
      _app(
        B07ExerciseVisualRegion(
          canonicalExerciseId: 'b07-bench',
          exerciseNameSnapshot: 'Bench press',
          displayMuscles: const ExerciseVisualMuscleFacts(
            primaryMuscle: 'Chest',
          ),
          registry: registry,
          assetBundle: _MapAssetBundle({
            'synthetic-main.webp': [0, 1, 2],
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.byType(IndiFitMuscleMap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'no muscle data falls through to icon and then neutral fallback',
    (tester) async {
      await tester.pumpWidget(
        _app(
          const B07ExerciseVisualRegion(
            canonicalExerciseId: 'unknown',
            exerciseNameSnapshot: 'Unknown exercise',
            registry: B05ExerciseVisualRegistry.empty(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);

      await tester.pumpWidget(
        _app(
          B07ExerciseVisualRegion(
            canonicalExerciseId: 'unknown',
            exerciseNameSnapshot: 'Unknown exercise',
            registry: const B05ExerciseVisualRegistry.empty(),
            equipment: 'Barbell',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.fitness_center_outlined), findsOneWidget);
    },
  );

  testWidgets(
    'canonical cues stay primary and RepDB disclosure is not coaching',
    (tester) async {
      final contextData = _context(
        id: 'b07-bench',
        cues: const ['Brace your feet', 'Keep the bar path controlled'],
        commonMistakes: const ['Bouncing the bar'],
      );
      final registry = B05ExerciseVisualRegistry.fromAssetSets([
        B05ExerciseVisualAssetSet(
          assetSetId: 'synthetic',
          canonicalExerciseUuids: const {'b07-bench'},
          mediaByRole: const {},
          techniqueDisclosure: 'RepDB movement-only disclosure',
        ),
      ]);
      await tester.pumpWidget(
        _app(
          B07ExerciseContextCard(
            canonicalExerciseId: 'b07-bench',
            exerciseNameSnapshot: 'Bench press',
            contextData: contextData,
            visualRegistry: registry,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Brace your feet'), findsOneWidget);
      expect(find.text('Technique'), findsOneWidget);
      final techniqueSize = tester.getSize(
        find.widgetWithText(TextButton, 'Technique'),
      );
      expect(
        techniqueSize.width,
        greaterThanOrEqualTo(B05Layout.minTouchTarget),
      );
      expect(
        techniqueSize.height,
        greaterThanOrEqualTo(B05Layout.minTouchTarget),
      );
      expect(find.text('RepDB movement-only disclosure'), findsNothing);
      await tester.tap(find.text('Technique'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Keep the bar path controlled'),
        findsOneWidget,
      );
      expect(find.textContaining('Bouncing the bar'), findsOneWidget);
      expect(find.text('RepDB movement-only disclosure'), findsNothing);
    },
  );

  testWidgets('missing canonical guidance stays hidden', (tester) async {
    await tester.pumpWidget(
      _app(
        B07ExerciseContextCard(
          canonicalExerciseId: 'b07-bench',
          exerciseNameSnapshot: 'Bench press',
          contextData: _context(id: 'b07-bench'),
          visualRegistry: const B05ExerciseVisualRegistry.empty(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Key cue'), findsNothing);
    expect(find.text('Technique'), findsNothing);
  });

  testWidgets('late A context cannot replace current B context', (
    tester,
  ) async {
    final a = Completer<B07ExerciseContextResult>();
    final b = Completer<B07ExerciseContextResult>();
    final fake = _FakeContextRepository(db, {
      'exercise-a': a.future,
      'exercise-b': b.future,
    });
    var id = 'exercise-a';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          b07ExerciseContextRepositoryProvider.overrideWithValue(fake),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  B07ExerciseContextPanel(
                    key: ValueKey<String>(id),
                    canonicalExerciseId: id,
                    exerciseNameSnapshot: id,
                    visualRegistry: const B05ExerciseVisualRegistry.empty(),
                  ),
                  TextButton(
                    onPressed: () => setState(() => id = 'exercise-b'),
                    child: const Text('Switch exercise'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Switch exercise'));
    await tester.pump();

    a.complete(
      B07ExerciseContextResult.available(
        _context(id: 'exercise-a', cues: const ['A cue']),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('A cue'), findsNothing);

    b.complete(
      B07ExerciseContextResult.available(
        _context(id: 'exercise-b', cues: const ['B cue']),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('B cue'), findsOneWidget);
    expect(fake.calls, 2);
  });

  testWidgets(
    'context lookup is cached by identity, not elapsed/rest repaint',
    (tester) async {
      final fake = _FakeContextRepository(db, {
        'b07-bench': Future.value(
          B07ExerciseContextResult.available(_context(id: 'b07-bench')),
        ),
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            b07ExerciseContextRepositoryProvider.overrideWithValue(fake),
          ],
          child: _app(
            const B07ExerciseContextPanel(
              canonicalExerciseId: 'b07-bench',
              exerciseNameSnapshot: 'Bench press',
              visualRegistry: B05ExerciseVisualRegistry.empty(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(fake.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('grouped next context uses B.5 member ordering', (tester) async {
    final current = _slot(
      id: 'group:0:0',
      exerciseId: 'a',
      name: 'Bench press',
      memberOrdinal: 0,
    );
    final next = _slot(
      id: 'group:0:1',
      exerciseId: 'b',
      name: 'Cable row',
      memberOrdinal: 1,
    );
    final group = B02ExerciseGroup(
      id: 'group',
      ordinal: 0,
      groupType: B02GroupType.superset,
      roundCount: 1,
      label: 'Push pull pair',
      members: [
        B02ExerciseGroupMember(
          id: 'member-a',
          exercisePrescriptionId: 'prescription-a',
          ordinal: 0,
        ),
        B02ExerciseGroupMember(
          id: 'member-b',
          exercisePrescriptionId: 'prescription-b',
          ordinal: 1,
        ),
      ],
    );
    final state = B02ExecutionDraftState(
      snapshotId: 'b07-group',
      snapshotVersion: 1,
      activityType: B02ActivityType.strength,
      routineName: 'Grouped workout',
      elapsedSeconds: 0,
      currentGroupOrdinal: 0,
      currentGroupId: 'group',
      currentRoundOrdinal: 0,
      currentMemberOrdinal: 0,
      currentExerciseOrdinal: 0,
      currentSetOrdinal: 0,
      groups: [group],
    );
    final resolvedNext = B02ExecutionProgression.nextSlot(
      state: state,
      slots: [current, next],
      current: current,
    );
    expect(resolvedNext?.id, next.id);

    await tester.pumpWidget(
      _app(
        B07NextExerciseContext(currentSlot: current, nextSlot: resolvedNext),
      ),
    );
    expect(find.text('Next exercise'), findsOneWidget);
    expect(find.text('Cable row'), findsOneWidget);
    expect(find.text('Superset · Round 1 · Member 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('end context uses consumer language in semantics', (
    tester,
  ) async {
    final current = _slot(
      id: 'last',
      exerciseId: 'a',
      name: 'Bench press',
      memberOrdinal: 0,
    );

    await tester.pumpWidget(_app(B07NextExerciseContext(currentSlot: current)));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'End of workout sequence',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('canonical'), findsNothing);
  });

  testWidgets('context card remains within a 390 point 1.5x player width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ListView(
              padding: EdgeInsets.zero,
              children: [
                B07ExerciseContextCard(
                  canonicalExerciseId: 'b07-bench',
                  exerciseNameSnapshot: 'Bench press',
                  contextData: _context(
                    id: 'b07-bench',
                    cues: const [
                      'Brace your feet',
                      'Keep the bar path controlled',
                    ],
                    commonMistakes: const ['Bouncing the bar'],
                  ),
                  visualRegistry: const B05ExerciseVisualRegistry.empty(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    addTearDown(tester.view.reset);
  });

  testWidgets(
    'context remains usable at narrow width and elevated text scale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: ListView(
                padding: EdgeInsets.zero,
                children: [
                  B07ExerciseContextCard(
                    canonicalExerciseId: 'b07-bench',
                    exerciseNameSnapshot: 'Bench press',
                    contextData: _context(
                      id: 'b07-bench',
                      cues: const [
                        'Brace your feet',
                        'Keep the bar path controlled',
                      ],
                      commonMistakes: const ['Bouncing the bar'],
                    ),
                    visualRegistry: const B05ExerciseVisualRegistry.empty(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp(r'^Exercise context for Bench press')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
      addTearDown(tester.view.reset);
    },
  );
}

B07ExerciseContext _context({
  required String id,
  List<String> cues = const [],
  List<String> commonMistakes = const [],
}) {
  return B07ExerciseContext(
    canonicalExerciseId: id,
    canonicalName: id,
    equipment: 'Barbell',
    displayMuscles: ExerciseDisplayMuscles.fromMuscleGroups('Chest,Triceps'),
    formCues: cues,
    commonMistakes: commonMistakes,
  );
}

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(body: Center(child: child)),
);

B05ExerciseVisualRegistry _syntheticRegistry({
  required bool pair,
  String canonicalId = 'b07-bench',
}) {
  final bytes = _syntheticPngBytes;
  final checksum = 'sha256:${sha256.convert(bytes)}';
  return B05ExerciseVisualRegistry.fromAssetSets([
    B05ExerciseVisualAssetSet(
      assetSetId: 'synthetic-$canonicalId',
      canonicalExerciseUuids: {canonicalId},
      mediaByRole: {
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
      },
      techniqueDisclosure: 'Synthetic movement-only disclosure.',
    ),
  ]);
}

B02StrengthExecutionSlot _slot({
  required String id,
  required String exerciseId,
  required String name,
  required int memberOrdinal,
}) {
  return B02StrengthExecutionSlot(
    id: id,
    groupId: 'group',
    groupType: B02GroupType.superset,
    groupLabel: 'Push pull pair',
    groupOrdinal: 0,
    roundOrdinal: 0,
    memberOrdinal: memberOrdinal,
    prescriptionId: 'prescription-${memberOrdinal == 0 ? 'a' : 'b'}',
    exerciseId: exerciseId,
    exerciseNameSnapshot: name,
    plannedSets: 1,
    targetRepsMin: 8,
    targetRepsMax: 10,
    targetRpe: null,
    targetLoadKg: 40,
    targetLoadBasis: B02LoadBasis.totalExternal,
  );
}

class _FakeContextRepository extends B07ExerciseContextRepository {
  _FakeContextRepository(super.database, this.results);

  final Map<String, Future<B07ExerciseContextResult>> results;
  var calls = 0;

  @override
  Future<B07ExerciseContextResult> resolve(String canonicalExerciseId) {
    calls++;
    return results[canonicalExerciseId] ??
        Future.value(const B07ExerciseContextResult.unavailable());
  }
}

class _MapAssetBundle extends CachingAssetBundle {
  _MapAssetBundle([this.values = const {}]);

  final Map<String, List<int>> values;

  @override
  Future<ByteData> load(String key) async {
    final bytes = values[key];
    if (bytes == null) throw FlutterError('Missing synthetic asset $key');
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

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
  4,
  0,
  0,
  0,
  181,
  28,
  12,
  2,
  0,
  0,
  0,
  11,
  73,
  68,
  65,
  84,
  120,
  218,
  99,
  100,
  248,
  15,
  0,
  1,
  5,
  1,
  1,
  39,
  24,
  227,
  102,
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
