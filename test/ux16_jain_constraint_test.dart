import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/core/config/app_preferences_keys.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrition_constraints.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/data/database/app_database.dart' show AppDatabase;
import 'package:indifit/data/repositories/nutrition_constraint_repository.dart';
import 'package:indifit/features/nutrition/jain_constraint_sync.dart';
import 'package:indifit/features/settings/nutrition_constraints_controller.dart';
import 'package:indifit/features/settings/nutrition_constraints_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UX-16: choosing Jain turns its dietary need on once, and never again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NutritionConstraintRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
    repository = NutritionConstraintRepository(database: db);
  });

  tearDown(() => db.close());

  JainConstraintSync sync() => JainConstraintSync(
    repository: repository,
    preferences: SharedPreferences.getInstance,
  );

  Future<List<NutritionUserConstraint>> jainNeeds() async => [
    for (final constraint in await repository.listAllConstraints(
      userId: kLocalNutritionUserScopeId,
    ))
      if (constraint.target.id == 'jain') constraint,
  ];

  test('choosing Jain turns on the Jain need', () async {
    await sync().applyFor('jain');
    final needs = await jainNeeds();
    expect(needs, hasLength(1));
    expect(needs.single.isActive, isTrue);
    expect(needs.single.type, NutritionConstraintType.religiousRestriction);
  });

  test('other patterns add nothing', () async {
    for (final diet in ['veg', 'non-veg', 'vegan', 'eggetarian', null]) {
      await sync().applyFor(diet);
    }
    expect(await jainNeeds(), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppPreferenceKeys.prefJainConstraintApplied), isNull);
  });

  test('a need the user turned off is never turned back on', () async {
    await sync().applyFor('jain');
    final need = (await jainNeeds()).single;
    await repository.archiveConstraint(
      userId: kLocalNutritionUserScopeId,
      constraintId: need.id,
    );

    await sync().applyFor('veg');
    await sync().applyFor('jain');
    await sync().migrateExistingUser();

    final needs = await jainNeeds();
    expect(needs, hasLength(1));
    expect(needs.single.isActive, isFalse);
  });

  test(
    'a need the user turned off before the flag existed stays off',
    () async {
      final need = await repository.createUserConstraint(
        userId: kLocalNutritionUserScopeId,
        type: NutritionConstraintType.religiousRestriction,
        target: NutritionConstraintTarget(
          type: NutritionConstraintTargetType.foodFamily,
          id: 'jain',
        ),
      );
      await repository.archiveConstraint(
        userId: kLocalNutritionUserScopeId,
        constraintId: need.id,
      );
      await sync().applyFor('jain');
      expect((await jainNeeds()).single.isActive, isFalse);
    },
  );

  test('switching away from Jain keeps the need', () async {
    await sync().applyFor('jain');
    await sync().applyFor('veg');
    expect((await jainNeeds()).single.isActive, isTrue);
  });

  group('one-time migration for existing Jain users', () {
    test('turns the need on once', () async {
      SharedPreferences.setMockInitialValues({
        AppPreferenceKeys.userDietPreference: 'jain',
      });
      await sync().migrateExistingUser();
      await sync().migrateExistingUser();
      expect(await jainNeeds(), hasLength(1));
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(AppPreferenceKeys.prefJainConstraintApplied),
        isTrue,
      );
    });

    test('does nothing once it has run', () async {
      SharedPreferences.setMockInitialValues({
        AppPreferenceKeys.userDietPreference: 'jain',
        AppPreferenceKeys.prefJainConstraintApplied: true,
      });
      await sync().migrateExistingUser();
      expect(await jainNeeds(), isEmpty);
    });

    test('leaves non-Jain users alone', () async {
      SharedPreferences.setMockInitialValues({
        AppPreferenceKeys.userDietPreference: 'veg',
      });
      await sync().migrateExistingUser();
      expect(await jainNeeds(), isEmpty);
    });
  });

  test('the flag round-trips through a backup', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppPreferenceKeys.prefJainConstraintApplied, true);
    final restored = BackupData.fromJson(
      (await BackupData.createFromDatabase(db, prefs)).toJson(),
    );
    SharedPreferences.setMockInitialValues({});
    final fresh = await SharedPreferences.getInstance();
    await restored.restoreToDatabase(db, fresh);
    expect(fresh.getBool(AppPreferenceKeys.prefJainConstraintApplied), isTrue);
  });

  testWidgets('choosing Jain in Settings → Dietary needs turns it on', (
    tester,
  ) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    final recording = _RecordingJainSync(repository);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          userProfileProvider.overrideWith((ref) => _VegProfileNotifier()),
          jainConstraintSyncProvider.overrideWithValue(recording),
          // The list itself is not under test; load it without the database.
          nutritionConstraintManagementControllerProvider.overrideWith((ref) {
            final controller = NutritionConstraintManagementController(
              repository: _EmptyConstraintRepository(database: db),
              userId: kLocalNutritionUserScopeId,
            );
            unawaited(controller.load());
            return controller;
          }),
        ],
        child: const MaterialApp(home: NutritionConstraintsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Jain').last);
    await tester.pumpAndSettle();

    // The sync's own rules are covered above; Settings hands it the choice.
    expect(recording.diets, ['jain']);
  });
}

class _RecordingJainSync extends JainConstraintSync {
  _RecordingJainSync(NutritionConstraintRepository repository)
    : super(repository: repository, preferences: SharedPreferences.getInstance);

  final diets = <String?>[];

  @override
  Future<void> applyFor(String? dietPreference) async =>
      diets.add(dietPreference);
}

class _EmptyConstraintRepository extends NutritionConstraintRepository {
  _EmptyConstraintRepository({required super.database});

  @override
  Future<List<NutritionConstraintDefinition>> listTaxonomy() async =>
      NutritionConstraintTaxonomy.definitions;

  @override
  Future<List<NutritionUserConstraint>> listAllConstraints({
    required String userId,
  }) async => const [];
}

class _VegProfileNotifier extends UserProfileNotifier {
  _VegProfileNotifier() : super() {
    state = const UserProfileState(
      isLoaded: true,
      hasProfile: true,
      calorieGoal: 2000,
      proteinGoal: 100,
      carbsGoal: 220,
      fatGoal: 65,
      currentWeight: 70,
      dietPreference: 'veg',
    );
  }

  @override
  Future<void> loadProfile() async {}

  @override
  Future<void> updateDietPreference(String dietPreference) async {
    state = state.copyWith(dietPreference: dietPreference);
  }
}
