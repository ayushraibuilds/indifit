import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_v10.dart';
import 'package:indifit/core/fixtures/b05_foundation_registry.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/dashboard_personalization_repository.dart';
import 'package:indifit/features/dashboard/dashboard_module_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late DashboardModuleRegistry registry;
  late DashboardPersonalizationRepository repository;

  setUp(() {
    database = AppDatabase.memory();
    registry = _registry();
    repository = DashboardPersonalizationRepository(
      database: database,
      registry: registry,
    );
  });

  tearDown(() => database.close());

  test(
    'defaults are deterministic and passive reads do not persist them',
    () async {
      final layout = await repository.readLayout(userId: _userId);

      expect(layout.map((item) => item.moduleId), ['workout', 'meals', 'next']);
      expect(layout.map((item) => item.ordinal), [0, 1, 2]);
      expect(layout.every((item) => item.isVisible), isTrue);
      expect(layout.last.isCollapsed, isFalse);
      expect(
        await database.select(database.dashboardModulePreferences).get(),
        isEmpty,
      );

      await repository.reconcile(userId: _userId);
      expect(
        await database.select(database.dashboardModulePreferences).get(),
        hasLength(3),
      );
    },
  );

  test(
    'reorder, hide/reveal, collapse and repeated actions persist one row per module',
    () async {
      var layout = await repository.reorder(
        userId: _userId,
        moduleId: 'meals',
        targetIndex: 0,
      );
      expect(layout.map((item) => item.moduleId), ['meals', 'workout', 'next']);
      expect(layout.map((item) => item.ordinal), [0, 1, 2]);

      layout = await repository.setVisible(
        userId: _userId,
        moduleId: 'workout',
        isVisible: false,
      );
      expect(_item(layout, 'workout').isVisible, isFalse);
      layout = await repository.setVisible(
        userId: _userId,
        moduleId: 'workout',
        isVisible: true,
      );
      expect(_item(layout, 'workout').isVisible, isTrue);

      layout = await repository.setCollapsed(
        userId: _userId,
        moduleId: 'meals',
        isCollapsed: true,
      );
      expect(_item(layout, 'meals').isCollapsed, isTrue);
      layout = await repository.setCollapsed(
        userId: _userId,
        moduleId: 'next',
        isCollapsed: true,
      );
      expect(_item(layout, 'next').isCollapsed, isFalse);

      await repository.setVisible(
        userId: _userId,
        moduleId: 'workout',
        isVisible: true,
      );
      final rows = await database
          .select(database.dashboardModulePreferences)
          .get();
      expect(rows, hasLength(3));
      expect(rows.map((row) => row.moduleId).toSet(), hasLength(3));

      final restoredRepository = DashboardPersonalizationRepository(
        database: database,
        registry: registry,
      );
      final restored = await restoredRepository.readLayout(userId: _userId);
      expect(restored.map((item) => item.moduleId), [
        'meals',
        'workout',
        'next',
      ]);
      expect(_item(restored, 'meals').isCollapsed, isTrue);
    },
  );

  test(
    'reset restores registry defaults in the same preference rows',
    () async {
      await repository.reorder(
        userId: _userId,
        moduleId: 'next',
        targetIndex: 0,
      );
      await repository.setVisible(
        userId: _userId,
        moduleId: 'workout',
        isVisible: false,
      );
      await repository.setCollapsed(
        userId: _userId,
        moduleId: 'meals',
        isCollapsed: true,
      );

      final reset = await repository.resetToDefaults(userId: _userId);

      expect(reset.map((item) => item.moduleId), ['workout', 'meals', 'next']);
      expect(reset.every((item) => item.isVisible), isTrue);
      expect(reset.every((item) => !item.isCollapsed), isTrue);
      expect(
        await database.select(database.dashboardModulePreferences).get(),
        hasLength(3),
      );
    },
  );

  test(
    'normalization follows unknown, first duplicate, tie, default and non-collapsible rules',
    () {
      final layout = registry.normalize([
        const B05DashboardModulePreferenceValue(
          moduleId: 'meals',
          ordinal: 1,
          isVisible: false,
          isCollapsed: true,
        ),
        const B05DashboardModulePreferenceValue(
          moduleId: 'workout',
          ordinal: 1,
          isVisible: true,
          isCollapsed: false,
        ),
        const B05DashboardModulePreferenceValue(
          moduleId: 'meals',
          ordinal: 0,
          isVisible: true,
          isCollapsed: false,
        ),
        const B05DashboardModulePreferenceValue(
          moduleId: 'unknown',
          ordinal: 0,
          isVisible: true,
          isCollapsed: false,
        ),
        const B05DashboardModulePreferenceValue(
          moduleId: 'next',
          ordinal: 0,
          isVisible: true,
          isCollapsed: true,
        ),
      ]);

      expect(layout.map((item) => item.moduleId), ['next', 'meals', 'workout']);
      expect(_item(layout, 'meals').isVisible, isFalse);
      expect(_item(layout, 'next').isCollapsed, isFalse);
    },
  );

  test(
    'descriptor additions and removals are read safely and reconcile only when requested',
    () async {
      final initial = DashboardModuleRegistry([
        _descriptor('workout', 0),
        _descriptor('meals', 1),
      ]);
      final initialRepository = DashboardPersonalizationRepository(
        database: database,
        registry: initial,
      );
      await initialRepository.reconcile(userId: _userId);

      final withNewDescriptor = DashboardModuleRegistry([
        _descriptor('workout', 0),
        _descriptor('meals', 1),
        _descriptor('next', 2, collapsible: false),
      ]);
      final added = await DashboardPersonalizationRepository(
        database: database,
        registry: withNewDescriptor,
      ).readLayout(userId: _userId);
      expect(added.map((item) => item.moduleId), ['workout', 'meals', 'next']);
      expect(
        await database.select(database.dashboardModulePreferences).get(),
        hasLength(2),
      );
      final addedRepository = DashboardPersonalizationRepository(
        database: database,
        registry: withNewDescriptor,
      );
      await addedRepository.reconcile(userId: _userId);
      final reconciledWithAddition = await addedRepository.readLayout(
        userId: _userId,
      );
      expect(reconciledWithAddition.map((item) => item.moduleId), [
        'workout',
        'meals',
        'next',
      ]);
      expect(reconciledWithAddition.map((item) => item.ordinal), [0, 1, 2]);

      final onlyWorkout = DashboardModuleRegistry([_descriptor('workout', 0)]);
      final removedRepository = DashboardPersonalizationRepository(
        database: database,
        registry: onlyWorkout,
      );
      final removed = await removedRepository.readLayout(userId: _userId);
      expect(removed.map((item) => item.moduleId), ['workout']);
      expect(
        await database.select(database.dashboardModulePreferences).get(),
        hasLength(3),
      );

      await removedRepository.reconcile(userId: _userId);
      final rows = await database
          .select(database.dashboardModulePreferences)
          .get();
      expect(rows.map((row) => row.moduleId), ['workout']);
    },
  );

  test(
    'unknown persisted records do not render and are pruned only by reconciliation',
    () async {
      await repository.reconcile(userId: _userId);
      await database
          .into(database.dashboardModulePreferences)
          .insert(
            DashboardModulePreferencesCompanion.insert(
              id: 'unknown-row',
              userId: _userId,
              moduleId: 'removed.module',
              ordinal: 99,
              isVisible: const Value(true),
              isCollapsed: const Value(false),
            ),
          );

      final passive = await repository.readLayout(userId: _userId);
      expect(passive.map((item) => item.moduleId), [
        'workout',
        'meals',
        'next',
      ]);
      expect(
        await database.select(database.dashboardModulePreferences).get(),
        hasLength(4),
      );

      await repository.reconcile(userId: _userId);
      expect(
        await database.select(database.dashboardModulePreferences).get(),
        hasLength(3),
      );
    },
  );

  test(
    'Backup v10 restore feeds the same normalized repository boundary',
    () async {
      await repository.reorder(
        userId: _userId,
        moduleId: 'next',
        targetIndex: 0,
      );
      await repository.setVisible(
        userId: _userId,
        moduleId: 'meals',
        isVisible: false,
      );
      final backup = await BackupV10Data.createFromDatabase(database);
      final target = AppDatabase.memory();
      addTearDown(target.close);
      await backup.restoreToDatabase(target);

      final restored = await DashboardPersonalizationRepository(
        database: target,
        registry: registry,
      ).readLayout(userId: _userId);
      expect(restored.map((item) => item.moduleId), [
        'next',
        'workout',
        'meals',
      ]);
      expect(_item(restored, 'meals').isVisible, isFalse);
      expect(
        await target.select(target.dashboardModulePreferences).get(),
        hasLength(3),
      );
    },
  );

  test(
    'invalid command inputs fail without creating arbitrary configuration',
    () async {
      await expectLater(
        repository.reorder(
          userId: _userId,
          moduleId: 'unknown',
          targetIndex: 0,
        ),
        throwsA(isA<DashboardPersonalizationValidationException>()),
      );
      await expectLater(
        repository.reorder(
          userId: _userId,
          moduleId: 'workout',
          targetIndex: 99,
        ),
        throwsA(isA<DashboardPersonalizationValidationException>()),
      );
      await expectLater(
        repository.readLayout(userId: '   '),
        throwsA(isA<DashboardPersonalizationValidationException>()),
      );
      expect(
        await database.select(database.dashboardModulePreferences).get(),
        isEmpty,
      );
    },
  );

  test('controller stays a B05 presentation command boundary', () {
    final source = File(
      'lib/features/dashboard/dashboard_personalization_controller.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('WorkoutRepository')));
    expect(source, isNot(contains('FoodRepository')));
    expect(source, isNot(contains('NutritionReadModelRepository')));
    expect(source, isNot(contains('select(')));
  });
}

const _userId = 'local-user-v1';

DashboardModuleRegistry _registry() => DashboardModuleRegistry([
  _descriptor('workout', 0),
  _descriptor('meals', 1),
  _descriptor('next', 2, collapsible: false),
]);

DashboardModuleDescriptor _descriptor(
  String id,
  int defaultOrdinal, {
  bool collapsible = true,
}) => DashboardModuleDescriptor(
  id: id,
  defaultOrdinal: defaultOrdinal,
  label: id,
  customizationLabel: id,
  eligibility: DashboardModuleEligibility.workout,
  collapsible: collapsible,
);

DashboardModuleLayoutItem _item(
  List<DashboardModuleLayoutItem> layout,
  String moduleId,
) => layout.singleWhere((item) => item.moduleId == moduleId);
