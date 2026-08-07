import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_v10.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/fixtures/b05_foundation_registry.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/models/b02_muscle_volume_models.dart';
import 'package:indifit/features/education/b05_education_content.dart';
import 'package:indifit/features/exercise_library/exercise_details_sheet.dart';
import 'package:indifit/features/media/b05_media_bundle.dart';
import 'package:indifit/features/media/b05_muscle_diagram.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled registry contains exactly the five offline lesson topics', () {
    final registry = b05BundledEducationRegistry;
    registry.requireAllTopics();
    expect(registry.lessons, hasLength(5));
    expect(
      registry.lessons.map((lesson) => lesson.contentId),
      containsAll([
        'rpe',
        'progressive_overload',
        'protein',
        'energy_balance',
        'recovery',
      ]),
    );
    expect(
      registry.lessons.every((lesson) => lesson.version.isNotEmpty),
      isTrue,
    );
    expect(registry.lessons.every((lesson) => lesson.body.isNotEmpty), isTrue);
    expect(
      B05EducationContentRegistry.fromJson(registry.toJson()).lessons,
      hasLength(5),
    );
  });

  test(
    'progress uses one versioned row and explicit complete/dismiss/revisit actions',
    () async {
      final database = AppDatabase.memory();
      addTearDown(database.close);
      var now = DateTime.utc(2026, 8, 7, 10);
      final repository = B05EducationProgressRepository(
        database: database,
        nowUtc: () => now,
      );
      final lesson = b05BundledEducationRegistry.lessons.first;

      final initial = await repository.readLesson(
        userId: 'user-1',
        lesson: lesson,
      );
      expect(initial.progress.state, B05EducationProgressState.notStarted);
      expect(initial.isRevision, isFalse);
      expect(
        await database.select(database.educationContentProgress).get(),
        isEmpty,
      );

      await repository.start(userId: 'user-1', lesson: lesson);
      now = now.add(const Duration(minutes: 1));
      await repository.complete(userId: 'user-1', lesson: lesson);
      expect(
        (await repository.read(
          userId: 'user-1',
          contentId: lesson.contentId,
          contentVersion: lesson.version,
        ))!.state,
        B05EducationProgressState.completed,
      );
      expect(
        await database.select(database.educationContentProgress).get(),
        hasLength(1),
      );

      await repository.revisit(userId: 'user-1', lesson: lesson);
      expect(
        (await repository.read(
          userId: 'user-1',
          contentId: lesson.contentId,
          contentVersion: lesson.version,
        ))!.state,
        B05EducationProgressState.inProgress,
      );
      await repository.dismiss(userId: 'user-1', lesson: lesson);
      expect(
        (await repository.read(
          userId: 'user-1',
          contentId: lesson.contentId,
          contentVersion: lesson.version,
        ))!.state,
        B05EducationProgressState.dismissed,
      );
    },
  );

  test(
    'new lesson revisions preserve old progress and expose revision state',
    () async {
      final database = AppDatabase.memory();
      addTearDown(database.close);
      final repository = B05EducationProgressRepository(database: database);
      const oldLesson = B05EducationContentDescriptor(
        contentId: 'rpe',
        version: '1.0.0',
        topic: 'rpe',
        body: 'Old content',
        relevanceTags: {'rpe'},
      );
      const revisedLesson = B05EducationContentDescriptor(
        contentId: 'rpe',
        version: '2.0.0',
        topic: 'rpe',
        body: 'Revised content',
        relevanceTags: {'rpe'},
      );
      await repository.complete(userId: 'user-1', lesson: oldLesson);
      final revision = await repository.readLesson(
        userId: 'user-1',
        lesson: revisedLesson,
      );
      expect(revision.progress.state, B05EducationProgressState.notStarted);
      expect(revision.previousVersion, '1.0.0');
      expect(revision.isRevision, isTrue);

      await repository.beginRevision(userId: 'user-1', lesson: revisedLesson);
      final rows = await database
          .select(database.educationContentProgress)
          .get();
      expect(rows, hasLength(2));
      expect(
        rows.map((row) => row.contentVersion),
        containsAll(['1.0.0', '2.0.0']),
      );
    },
  );

  test(
    'versioned progress round-trips through Backup v10 without content duplication',
    () async {
      final source = AppDatabase.memory();
      final target = AppDatabase.memory();
      addTearDown(source.close);
      addTearDown(target.close);
      final repository = B05EducationProgressRepository(database: source);
      await repository.complete(
        userId: 'user-1',
        lesson: b05BundledEducationRegistry.lessons.first,
      );
      final backup = await BackupV10Data.createFromDatabase(source);
      final encoded =
          jsonDecode(jsonEncode(backup.toJson())) as Map<String, dynamic>;
      await BackupV10Data.fromJson(encoded).restoreToDatabase(target);
      final restored = await B05EducationProgressRepository(
        database: target,
      ).readAll(userId: 'user-1');
      expect(restored, hasLength(1));
      expect(restored.single.state, B05EducationProgressState.completed);
    },
  );

  test('muscle labels preserve reviewed roles and unknown mappings', () {
    final mapper = const B05MuscleLabelMapper();
    final reviewed = mapper.map(
      B02MuscleVolumeMapping(
        exerciseId: 'bench',
        status: B02MappingStatus.reviewed,
        source: 'b02-test',
        catalogVersion: 1,
        contributions: [
          B02MuscleContribution(
            muscleId: 'chest',
            role: B02MuscleRole.primary,
            contributionBasisPoints: 7000,
          ),
          B02MuscleContribution(
            muscleId: 'triceps',
            role: B02MuscleRole.secondary,
            contributionBasisPoints: 3000,
          ),
        ],
      ),
    );
    expect(reviewed.isUnknown, isFalse);
    expect(reviewed.forRole(B02MuscleRole.primary).single.displayName, 'Chest');
    expect(
      reviewed.forRole(B02MuscleRole.secondary).single.roleLabel,
      'secondary',
    );

    final unknown = mapper.map(
      B02MuscleVolumeMapping(
        exerciseId: 'custom',
        status: B02MappingStatus.unknown,
        source: null,
        catalogVersion: 1,
        contributions: const [],
      ),
    );
    expect(unknown.isUnknown, isTrue);
    expect(unknown.labels, isEmpty);
  });

  test('mixed reviewed mappings retain known labels beside unknown IDs', () {
    final mapper = const B05MuscleLabelMapper();
    final mixed = mapper.map(
      B02MuscleVolumeMapping(
        exerciseId: 'bench',
        status: B02MappingStatus.reviewed,
        source: 'b02-test',
        catalogVersion: 1,
        contributions: [
          B02MuscleContribution(
            muscleId: 'chest',
            role: B02MuscleRole.primary,
            contributionBasisPoints: 5000,
          ),
          B02MuscleContribution(
            muscleId: 'future-muscle',
            role: B02MuscleRole.secondary,
            contributionBasisPoints: 5000,
          ),
        ],
      ),
    );
    expect(mixed.isUnknown, isTrue);
    expect(mixed.forRole(B02MuscleRole.primary).single.displayName, 'Chest');
    expect(
      mixed.labels.where((label) => label.role == null).single.displayName,
      'Unknown muscle',
    );
  });

  test(
    'lesson controller exposes explicit lifecycle actions without duplicate rows',
    () async {
      final database = AppDatabase.memory();
      addTearDown(database.close);
      final lesson = b05BundledEducationRegistry.lessons.first;
      final registry = B05EducationContentRegistry([lesson]);
      final controller = B05EducationLessonsController(
        repository: B05EducationProgressRepository(database: database),
        registry: registry,
        userId: 'user-1',
      );
      await controller.load();
      expect(controller.state.status, B05EducationLessonsStatus.ready);
      expect(
        controller.state.lessons.single.progress.state,
        B05EducationProgressState.notStarted,
      );

      await controller.complete(lesson.contentId);
      expect(
        controller.state.lessons.single.progress.state,
        B05EducationProgressState.completed,
      );
      await controller.revisit(lesson.contentId);
      expect(
        controller.state.lessons.single.progress.state,
        B05EducationProgressState.inProgress,
      );
      await controller.dismiss(lesson.contentId);
      expect(
        controller.state.lessons.single.progress.state,
        B05EducationProgressState.dismissed,
      );
      expect(
        await database.select(database.educationContentProgress).get(),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'mini lessons panel exposes complete, dismiss and revisit actions',
    (tester) async {
      final database = AppDatabase.memory();
      addTearDown(database.close);
      final lesson = b05BundledEducationRegistry.lessons.first;
      final controller = B05EducationLessonsController(
        repository: B05EducationProgressRepository(database: database),
        registry: B05EducationContentRegistry([lesson]),
        userId: 'user-1',
      );
      controller.state = B05EducationLessonsState(
        status: B05EducationLessonsStatus.ready,
        lessons: [
          B05EducationLessonProgress(
            lesson: lesson,
            progress: B05EducationProgress(
              contentId: lesson.contentId,
              contentVersion: lesson.version,
              state: B05EducationProgressState.notStarted,
              updatedAtUtc: DateTime.utc(2026, 8, 7),
            ),
            previousVersion: null,
          ),
        ],
      );
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            b05EducationLessonsControllerProvider.overrideWith(
              (ref) => controller,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: SingleChildScrollView(child: B05MiniLessonsPanel()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Mini lessons'), findsOneWidget);
      expect(find.bySemanticsLabel('Mark complete'), findsOneWidget);
      expect(find.bySemanticsLabel('Dismiss'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'education panel has checklist, cue and unknown-mapping semantics at 2x text',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final model = B05ExerciseEducationModel(
        exerciseName: 'Bench press',
        stableExerciseId: 'bench',
        catalogueCues: const ['Keep your feet grounded.'],
        catalogueMistakes: const ['Do not bounce the bar.'],
        personalCues: const ['Use the medium-width grip.'],
        checklist: const [
          B05ExerciseChecklistItem(id: 'setup', label: 'Set up consistently.'),
        ],
        muscles: const B05MuscleLabelSet(labels: [], isUnknown: true),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            b05ExerciseEducationProvider.overrideWith(
              (ref, query) async => model,
            ),
          ],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 720),
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const B05ExerciseEducationPanel(
                exerciseName: 'Bench press',
                stableExerciseId: 'bench',
                catalogueCues: ['Keep your feet grounded.'],
                catalogueMistakes: ['Do not bounce the bar.'],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Exercise education'), findsOneWidget);
      expect(find.text('Form checklist'), findsOneWidget);
      expect(find.text('Catalogue guidance'), findsOneWidget);
      expect(find.text('Your personal cues'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Unavailable: Muscle contribution is unknown'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('exercise detail production surface includes education panel', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final model = B05ExerciseEducationModel(
      exerciseName: 'Bench press',
      stableExerciseId: 'bench',
      catalogueCues: const ['Keep your feet grounded.'],
      catalogueMistakes: const ['Do not bounce the bar.'],
      personalCues: const [],
      checklist: const [
        B05ExerciseChecklistItem(id: 'setup', label: 'Set up consistently.'),
      ],
      muscles: const B05MuscleLabelSet(labels: [], isUnknown: true),
    );
    const exercise = Exercise(
      id: 1,
      stableId: 'bench',
      name: 'Bench press',
      muscleGroups: 'Chest',
      equipment: 'Barbell',
      difficulty: 'Intermediate',
      formCues: 'Keep your feet grounded.',
      commonMistakes: 'Do not bounce the bar.',
      youtubeId: '',
      isCustom: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyPolicyProvider.overrideWith((ref) => PrivacyPolicyNotifier()),
          b05ExerciseEducationProvider.overrideWith(
            (ref, query) async => model,
          ),
          b05MuscleVisualRegistryProvider.overrideWithValue(
            B05MuscleVisualRegistry([
              const B05MuscleDiagramRegion(
                regionId: 'chest-region',
                muscleId: 'chest',
                label: 'Chest',
                textOrder: 0,
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: ExerciseDetailsSheet(exercise: exercise)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Exercise education'), findsOneWidget);
    expect(find.text('Interactive muscle diagram'), findsOneWidget);
    expect(find.text('INSTRUCTION VIDEO'), findsNothing);
    expect(find.byIcon(Icons.play_circle_fill_rounded), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets(
    'seeded blank youtube ids stay offline and keep education guidance',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        PrivacyPolicyNotifier.prefOfflineOnly: true,
      });
      final database = AppDatabase.memory();
      addTearDown(database.close);
      late Exercise exercise;
      await tester.runAsync(() async {
        await database.upsertSeededExercisesFromAsset();
        exercise = (await database.select(database.exercises).get()).first;
      });
      expect(exercise.youtubeId, '');

      final cues = exercise.formCues.split('\n');
      final mistakes = exercise.commonMistakes.split('\n');
      final model = B05ExerciseEducationModel(
        exerciseName: exercise.name,
        stableExerciseId: exercise.stableId ?? exercise.name,
        catalogueCues: cues,
        catalogueMistakes: mistakes,
        personalCues: const [],
        checklist: [B05ExerciseChecklistItem(id: 'setup', label: cues.first)],
        muscles: const B05MuscleLabelSet(labels: [], isUnknown: true),
      );
      final prefs = await SharedPreferences.getInstance();
      final offlinePolicy = PrivacyPolicyNotifier(prefs);
      final mediaController =
          B05MediaBundleController(
              source: const B05NoApprovedMediaManifestSource(),
              preferenceRepository: B05MediaPackPreferenceRepository(
                database: database,
              ),
              userId: 'seeded-test-user',
            )
            ..state = const B05MediaBundleState(
              status: B05MediaBundleStatus.unavailable,
              message: 'Approved media is unavailable in this test build.',
            );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            privacyPolicyProvider.overrideWith((ref) => offlinePolicy),
            b05MediaBundleControllerProvider.overrideWith(
              (ref) => mediaController,
            ),
            b05ExerciseEducationProvider.overrideWith(
              (ref, query) async => model,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(body: ExerciseDetailsSheet(exercise: exercise)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Exercise education'), findsOneWidget);
      expect(find.text('Offline exercise media'), findsOneWidget);
      expect(find.text('Exercise media is unavailable'), findsOneWidget);
      expect(find.text('INSTRUCTION VIDEO'), findsNothing);
      expect(find.byIcon(Icons.play_circle_fill_rounded), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
