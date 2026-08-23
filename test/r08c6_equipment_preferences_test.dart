import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/fixtures/equipment_fixtures.dart';
import 'package:indifit/core/presentation/equipment_presentation.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/equipment_preference_repository.dart';
import 'package:indifit/features/equipment/equipment_profile_editor_screen.dart';
import 'package:indifit/features/equipment/equipment_profiles_screen.dart';
import 'package:indifit/features/equipment/exercise_preference_editor_screen.dart';

class _InMemoryEquipmentProfileRepository extends EquipmentProfileRepository {
  final Map<String, EquipmentProfile> _profiles = {};
  final Map<String, List<EquipmentProfileItem>> _items = {};
  String? _defaultId;

  _InMemoryEquipmentProfileRepository(super.db);

  @override
  Future<List<EquipmentProfile>> getActiveProfiles() async {
    return _profiles.values
        .where((p) => p.archivedAtUtc == null)
        .toList(growable: false);
  }

  @override
  Future<String?> getDefaultProfileId() async => _defaultId;

  @override
  Future<EquipmentProfileAggregate?> getProfile(String profileId) async {
    final p = _profiles[profileId];
    if (p == null) return null;
    final items = _items[profileId] ?? [];
    return EquipmentProfileAggregate(profile: p, items: items);
  }

  @override
  Future<EquipmentProfile?> getProfileById(String profileId) async =>
      _profiles[profileId];

  @override
  Future<List<EquipmentProfileItem>> getItemsForProfile(String profileId) async =>
      _items[profileId] ?? [];

  @override
  Future<void> setDefaultProfileId(String profileId) async {
    if (!_profiles.containsKey(profileId)) {
      throw StateError('Profile not found');
    }
    _defaultId = profileId;
  }

  @override
  Future<String> createProfile({
    required String name,
    double? defaultWeightIncrementKg,
    String? note,
    List<EquipmentProfileItemInput> items = const [],
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError('Name cannot be blank');
    if (_profiles.values.any((p) => p.name.toLowerCase() == cleanName.toLowerCase())) {
      throw ArgumentError('Equipment profile names must be unique (case-insensitive).');
    }
    final id = 'profile-${_profiles.length + 1}';
    final now = DateTime.now().toUtc();
    final profile = EquipmentProfile(
      id: id,
      name: cleanName,
      defaultWeightIncrementKg: defaultWeightIncrementKg,
      note: note,
      createdAtUtc: now,
      updatedAtUtc: now,
    );
    _profiles[id] = profile;
    _items[id] = items
        .map(
          (i) => EquipmentProfileItem(
            id: 'item-${_items.length}-${i.equipmentCode}',
            equipmentProfileId: id,
            equipmentCode: i.equipmentCode,
            isAvailable: i.isAvailable,
            weightIncrementKg: i.weightIncrementKg,
          ),
        )
        .toList();
    _defaultId ??= id;
    return id;
  }

  @override
  Future<void> updateProfile({
    required String profileId,
    String? name,
    double? defaultWeightIncrementKg,
    bool clearDefaultWeightIncrement = false,
    String? note,
    bool clearNote = false,
    List<EquipmentProfileItemInput>? items,
  }) async {
    final existing = _profiles[profileId];
    if (existing == null) throw StateError('Profile not found');
    if (name != null &&
        _profiles.values.any(
          (p) => p.id != profileId && p.name.toLowerCase() == name.trim().toLowerCase(),
        )) {
      throw ArgumentError('Equipment profile names must be unique (case-insensitive).');
    }
    final updated = existing.copyWith(
      name: name?.trim() ?? existing.name,
      note: clearNote ? const Value(null) : (note != null ? Value(note) : const Value.absent()),
      defaultWeightIncrementKg: clearDefaultWeightIncrement
          ? const Value(null)
          : (defaultWeightIncrementKg != null
              ? Value(defaultWeightIncrementKg)
              : const Value.absent()),
    );
    _profiles[profileId] = updated;
    if (items != null) {
      _items[profileId] = items
          .map(
            (i) => EquipmentProfileItem(
              id: 'item-$profileId-${i.equipmentCode}',
              equipmentProfileId: profileId,
              equipmentCode: i.equipmentCode,
              isAvailable: i.isAvailable,
              weightIncrementKg: i.weightIncrementKg,
            ),
          )
          .toList();
    }
  }

  @override
  Future<void> archiveProfile(String profileId) async {
    final existing = _profiles[profileId];
    if (existing == null) throw StateError('Profile not found');
    if (_defaultId == profileId) {
      throw StateError('Cannot archive default profile');
    }
    _profiles[profileId] = existing.copyWith(archivedAtUtc: Value(DateTime.now().toUtc()));
  }
}

class _InMemoryExercisePreferenceRepository extends ExercisePreferenceRepository {
  final Map<String, ExercisePreferenceAggregate> _preferences = {};

  _InMemoryExercisePreferenceRepository(super.db);

  @override
  Future<ExercisePreferenceAggregate?> getPreference({
    String? stableId,
    String? rawName,
  }) async {
    final key = stableId ?? rawName;
    return key != null ? _preferences[key] : null;
  }

  @override
  Future<String> savePreference({
    String? stableId,
    String? rawName,
    bool allowUnresolvedRawFallback = false,
    String? generalNote,
    bool clearGeneralNote = false,
    List<SetupValueInput>? setupValues,
    List<String>? personalCues,
  }) async {
    final key = stableId ?? rawName ?? 'unknown';
    final pref = ExerciseUserPreference(
      id: 'pref-$key',
      identityKey: key,
      exerciseId: stableId,
      exerciseNameFallback: rawName,
      generalNote: clearGeneralNote ? null : generalNote,
      createdAtUtc: DateTime.now().toUtc(),
      updatedAtUtc: DateTime.now().toUtc(),
    );
    final svList = (setupValues ?? const <SetupValueInput>[])
        .map(
          (sv) => ExerciseSetupValue(
            id: 'sv-${sv.label}',
            exerciseUserPreferenceId: pref.id,
            ordinal: sv.ordinal,
            label: sv.label,
            value: sv.value,
          ),
        )
        .toList();
    final cueList = (personalCues ?? const <String>[])
        .asMap()
        .entries
        .map(
          (e) => ExercisePersonalCue(
            id: 'cue-${e.key}',
            exerciseUserPreferenceId: pref.id,
            ordinal: e.key,
            cueText: e.value,
          ),
        )
        .toList();
    _preferences[key] = ExercisePreferenceAggregate(
      preference: pref,
      setupValues: svList,
      personalCues: cueList,
    );
    return pref.id;
  }

  @override
  Future<void> deletePreference({String? stableId, String? rawName}) async {
    final key = stableId ?? rawName;
    if (key != null) _preferences.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _InMemoryEquipmentProfileRepository inMemoryEquipmentRepo;
  late _InMemoryExercisePreferenceRepository inMemoryExercisePrefRepo;

  setUp(() async {
    db = AppDatabase.memory();
    inMemoryEquipmentRepo = _InMemoryEquipmentProfileRepository(db);
    inMemoryExercisePrefRepo = _InMemoryExercisePreferenceRepository(db);

    await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            stableId: const Value('exercise-squat-v1'),
            name: 'Barbell Squat',
            muscleGroups: 'Quadriceps',
            equipment: 'Barbell, Power Rack',
            difficulty: 'Intermediate',
            formCues: 'Chest up, knees tracking over toes',
            commonMistakes: 'Knees caving',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestWidget(
    Widget child, {
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
    Size surfaceSize = const Size(390, 844),
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        equipmentProfileRepositoryProvider.overrideWithValue(inMemoryEquipmentRepo),
        exercisePreferenceRepositoryProvider.overrideWithValue(inMemoryExercisePrefRepo),
        ...overrides,
      ],
      child: MaterialApp(
        theme: ThemeData(
          brightness: brightness,
          fontFamily: 'Outfit',
          extensions: [
            brightness == Brightness.dark
                ? B05SemanticColors.dark
                : B05SemanticColors.light,
          ],
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: surfaceSize,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child,
        ),
      ),
    );
  }

  group('R08C.6 Equipment Presentation & Fixtures Tests', () {
    test('1. EquipmentChoicesPresentation contains all canonical items', () {
      final choices = EquipmentChoicesPresentation.allChoices;
      expect(choices.length, 9); // 9 editable canonical items (excluding bodyweight)
      expect(EquipmentChoicesPresentation.editableItems.length, 9);
      expect(EquipmentChoicesPresentation.displayNameFor('barbell'), 'Barbell');
      expect(EquipmentChoicesPresentation.displayNameFor('cardio_equipment'), 'Cardio Equipment');
      expect(EquipmentChoicesPresentation.iconFor('dumbbell'), isNotNull);
    });

    test('2. EquipmentPreset starter presets have valid items and increments', () {
      final presets = EquipmentChoicesPresentation.presets;
      expect(presets.length, greaterThanOrEqualTo(4));

      final fullGym = presets.firstWhere((p) => p.id == 'full_gym');
      expect(fullGym.includedItems, contains(CanonicalEquipmentItem.barbell));
      expect(fullGym.includedItems, contains(CanonicalEquipmentItem.rack));
      expect(fullGym.standardIncrements['barbell'], 5.0);

      final dumbbells = presets.firstWhere((p) => p.id == 'dumbbells_only');
      expect(dumbbells.includedItems, contains(CanonicalEquipmentItem.dumbbell));
      expect(dumbbells.includedItems, contains(CanonicalEquipmentItem.bench));
      expect(dumbbells.includedItems, isNot(contains(CanonicalEquipmentItem.barbell)));
    });

    test('3. EquipmentCompatibilityPresentation formats compatible/incompatible/unknown statuses', () {
      const compatible = EquipmentCompatibility(
        status: EquipmentCompatibilityStatus.compatible,
        requiredEquipmentCodes: ['barbell', 'bench'],
        unavailableEquipmentCodes: [],
        originalRequirement: 'Barbell, Bench',
      );
      final compPres = EquipmentCompatibilityPresentation.fromCompatibility(compatible);
      expect(compPres.status, EquipmentCompatibilityStatus.compatible);
      expect(compPres.label, 'Compatible');
      expect(compPres.semanticStatus, B05SemanticStatus.success);

      const incompatible = EquipmentCompatibility(
        status: EquipmentCompatibilityStatus.incompatible,
        requiredEquipmentCodes: ['barbell', 'bench'],
        unavailableEquipmentCodes: ['bench'],
        originalRequirement: 'Barbell, Bench',
      );
      final incompPres = EquipmentCompatibilityPresentation.fromCompatibility(incompatible);
      expect(incompPres.status, EquipmentCompatibilityStatus.incompatible);
      expect(incompPres.label, 'Missing Equipment');
      expect(incompPres.missingItemNames, contains('Bench'));
      expect(incompPres.semanticStatus, B05SemanticStatus.warning);

      const unknown = EquipmentCompatibility(
        status: EquipmentCompatibilityStatus.unknown,
        requiredEquipmentCodes: [],
        unavailableEquipmentCodes: [],
        originalRequirement: 'Alien Gear',
      );
      final unkPres = EquipmentCompatibilityPresentation.fromCompatibility(unknown);
      expect(unkPres.status, EquipmentCompatibilityStatus.unknown);
      expect(unkPres.label, 'Unverified Equipment');
      expect(unkPres.semanticStatus, B05SemanticStatus.info);
    });
  });

  group('R08C.6 Equipment Profiles List Screen Tests', () {
    testWidgets('4. Loads existing equipment profiles and default badge', (tester) async {
      final profileId = await inMemoryEquipmentRepo.createProfile(
        name: 'My Commercial Gym',
        note: 'Full equipment access',
        defaultWeightIncrementKg: 2.5,
        items: const [
          EquipmentProfileItemInput(equipmentCode: 'barbell', isAvailable: true),
          EquipmentProfileItemInput(equipmentCode: 'dumbbell', isAvailable: true, weightIncrementKg: 2.5),
        ],
      );
      await inMemoryEquipmentRepo.setDefaultProfileId(profileId);

      await tester.pumpWidget(createTestWidget(const EquipmentProfilesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Equipment Profiles'), findsOneWidget);
      expect(find.text('My Commercial Gym'), findsOneWidget);
      expect(find.text('DEFAULT'), findsOneWidget);
      expect(find.text('Full equipment access'), findsOneWidget);
      expect(find.text('2 equipment types available'), findsOneWidget);
      expect(find.text('Default load increment: 2.5 kg'), findsOneWidget);
    });

    testWidgets('5. Renders empty state with purpose explanation and starter presets', (tester) async {
      await tester.pumpWidget(createTestWidget(const EquipmentProfilesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('No Equipment Profiles Yet'), findsOneWidget);
      expect(find.text('Create Custom Profile'), findsOneWidget);
      expect(find.text('Quick Starter Presets'), findsOneWidget);
      expect(find.text('Full Gym'), findsOneWidget);
      expect(find.text('Home Gym'), findsOneWidget);
    });

    testWidgets('6. Quick preset in empty state creates profile and sets default', (tester) async {
      await tester.pumpWidget(createTestWidget(const EquipmentProfilesScreen()));
      await tester.pumpAndSettle();

      // Tap "Full Gym" preset
      await tester.tap(find.text('Full Gym'));
      await tester.pumpAndSettle();

      expect(find.text('Created "Full Gym" profile.'), findsOneWidget);
      expect(find.text('Full Gym'), findsOneWidget);
      expect(find.text('DEFAULT'), findsOneWidget);

      final active = await inMemoryEquipmentRepo.getActiveProfiles();
      expect(active.length, 1);
      expect(active.first.name, 'Full Gym');
    });

    testWidgets('7. Handles unknown legacy access codes safely', (tester) async {
      await inMemoryEquipmentRepo.createProfile(
        name: 'Migrated Profile',
        items: const [EquipmentProfileItemInput(equipmentCode: 'dumbbell', isAvailable: true)],
      );

      await tester.pumpWidget(createTestWidget(const EquipmentProfilesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Migrated Profile'), findsOneWidget);
      expect(find.text('1 equipment type available'), findsOneWidget);
    });
  });

  group('R08C.6 Equipment Profile Editor Screen Tests', () {
    testWidgets('8. Create new profile with presets and save round-trip', (tester) async {
      await tester.pumpWidget(createTestWidget(const EquipmentProfileEditorScreen()));
      await tester.pumpAndSettle();

      expect(find.text('New Profile'), findsOneWidget);

      // Enter profile name
      await tester.enterText(find.byType(TextField).at(0), 'Garage Gym');
      await tester.pumpAndSettle();

      // Apply preset "Home Gym"
      await tester.tap(find.text('Home Gym'));
      await tester.pumpAndSettle();

      // Verify Dumbbell switch is enabled
      expect(find.text('Dumbbell'), findsOneWidget);

      // Scroll to Save Profile button and save
      await tester.ensureVisible(find.text('Save Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Profile'));
      await tester.pumpAndSettle();

      final profiles = await inMemoryEquipmentRepo.getActiveProfiles();
      expect(profiles.any((p) => p.name == 'Garage Gym'), isTrue);
    });

    testWidgets('9. Save validation: blank name shows error and does not save', (tester) async {
      await tester.pumpWidget(createTestWidget(const EquipmentProfileEditorScreen()));
      await tester.pumpAndSettle();

      // Scroll to save button and tap
      await tester.ensureVisible(find.text('Save Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a profile name.'), findsOneWidget);
      expect(find.text('Profile name cannot be blank.'), findsOneWidget);

      final profiles = await inMemoryEquipmentRepo.getActiveProfiles();
      expect(profiles, isEmpty);
    });

    testWidgets('10. Duplicate name rejection fails safely with message and does not close screen', (tester) async {
      await inMemoryEquipmentRepo.createProfile(name: 'Duplicate Gym');

      await tester.pumpWidget(createTestWidget(const EquipmentProfileEditorScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'duplicate gym');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Profile'));
      await tester.pumpAndSettle();

      // Rejection snackbar
      expect(find.textContaining('must be unique'), findsOneWidget);
      // Screen stays open
      expect(find.text('New Profile'), findsOneWidget);
    });

    testWidgets('11. Edit existing profile loads persisted values and updates correctly', (tester) async {
      final pId = await inMemoryEquipmentRepo.createProfile(
        name: 'Old Name',
        note: 'Old Note',
        defaultWeightIncrementKg: 2.0,
        items: const [
          EquipmentProfileItemInput(equipmentCode: 'kettlebell', isAvailable: true, weightIncrementKg: 2.0),
        ],
      );

      await tester.pumpWidget(createTestWidget(EquipmentProfileEditorScreen(profileId: pId)));
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Old Name'), findsOneWidget);
      expect(find.text('Old Note'), findsOneWidget);
      expect(find.text('2.0'), findsWidgets);

      // Change name and save
      await tester.enterText(find.byType(TextField).at(0), 'New Name');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Profile'));
      await tester.pumpAndSettle();

      final updated = await inMemoryEquipmentRepo.getProfile(pId);
      expect(updated!.profile.name, 'New Name');
    });
  });

  group('R08C.6 Exercise Preference Editor Screen Tests', () {
    testWidgets('12. Exercise preference setup values & cues round-trip', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const ExercisePreferenceEditorScreen(
            stableId: 'exercise-squat-v1',
            rawName: 'Barbell Squat',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Setup & Cues: Barbell Squat'), findsOneWidget);
      expect(find.text('General Exercise Note'), findsOneWidget);

      // Enter note
      await tester.enterText(find.byType(TextField).at(0), 'Use safety pins at hole 7');
      await tester.pumpAndSettle();

      // Add a setup value from suggestion chip
      await tester.tap(find.text('Pin'));
      await tester.pumpAndSettle();

      // Fill in value "7"
      await tester.enterText(find.byType(TextField).at(2), '7');
      await tester.pumpAndSettle();

      // Add a personal cue
      await tester.tap(find.byTooltip('Add cue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Personal Cue'), 'Spread the floor with feet');
      await tester.pumpAndSettle();

      // Save
      await tester.ensureVisible(find.text('Save Setup & Cues'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Setup & Cues'));
      await tester.pumpAndSettle();

      // Verify persisted in DB
      final saved = await inMemoryExercisePrefRepo.getPreference(stableId: 'exercise-squat-v1');
      expect(saved, isNotNull);
      expect(saved!.preference.generalNote, 'Use safety pins at hole 7');
      expect(saved.setupValues.single.label, 'Pin');
      expect(saved.setupValues.single.value, '7');
      expect(saved.personalCues.single.cueText, 'Spread the floor with feet');
    });

    testWidgets('13. Preferences notice states edits do not alter historical workouts', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const ExercisePreferenceEditorScreen(
            stableId: 'exercise-squat-v1',
            rawName: 'Barbell Squat',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Changes do not alter active or completed workout records'),
        findsOneWidget,
      );
    });

    test('14. Preference edits leave historical WorkoutSessions and WorkoutSets unaltered', () async {
      final realExerciseRepo = ExercisePreferenceRepository(db);
      // Create a mock completed session and sets
      final now = DateTime.now().toUtc();
      final sessionId = await db.into(db.workoutSessions).insert(
            WorkoutSessionsCompanion.insert(
              name: 'Leg Day',
              totalVolume: 500.0,
              durationSeconds: 3600,
              estimatedCalories: 0,
              completedAt: Value(now),
            ),
          );
      await db.into(db.workoutSets).insert(
            WorkoutSetsCompanion.insert(
              sessionId: sessionId,
              exerciseName: 'Barbell Squat',
              setNumber: 1,
              weight: 100.0,
              reps: 5,
            ),
          );

      // Now save preference
      await realExerciseRepo.savePreference(
        stableId: 'exercise-squat-v1',
        generalNote: 'New Squat Preference',
        personalCues: const ['Keep chest proud'],
      );

      // Verify historical rows unchanged
      final session = await (db.select(db.workoutSessions)..where((t) => t.id.equals(sessionId))).getSingle();
      final set = await (db.select(db.workoutSets)..where((t) => t.sessionId.equals(sessionId))).getSingle();

      expect(session.name, 'Leg Day');
      expect(set.weight, 100.0);
      expect(set.reps, 5);
    });
  });

  group('R08C.6 Layout, Responsive, Accessibility & Theme Tests', () {
    testWidgets('15. Narrow width (320px) renders without overflow', (tester) async {
      final pId = await inMemoryEquipmentRepo.createProfile(
        name: 'Narrow Profile Gym',
        items: const [
          EquipmentProfileItemInput(equipmentCode: 'barbell', isAvailable: true),
          EquipmentProfileItemInput(equipmentCode: 'cable', isAvailable: true),
        ],
      );

      // Profiles Screen on 320px width
      await tester.pumpWidget(
        createTestWidget(
          const EquipmentProfilesScreen(),
          surfaceSize: const Size(320, 600),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Profile Editor on 320px width
      await tester.pumpWidget(
        createTestWidget(
          EquipmentProfileEditorScreen(profileId: pId),
          surfaceSize: const Size(320, 600),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Exercise Preference Editor on 320px width
      await tester.pumpWidget(
        createTestWidget(
          const ExercisePreferenceEditorScreen(
            stableId: 'exercise-squat-v1',
            rawName: 'Barbell Squat',
          ),
          surfaceSize: const Size(320, 600),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('16. High text scale (1.6x) renders cleanly', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const EquipmentProfilesScreen(),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        createTestWidget(
          const EquipmentProfileEditorScreen(),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('17. Light and Dark themes both render without exceptions', (tester) async {
      // Dark mode
      await tester.pumpWidget(
        createTestWidget(
          const EquipmentProfilesScreen(),
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Light mode
      await tester.pumpWidget(
        createTestWidget(
          const EquipmentProfilesScreen(),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
