import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_v8.dart';
import 'package:indifit/core/nutrition_constraints.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_constraint_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NutritionConstraintRepository repository;

  setUp(() async {
    db = AppDatabase.memory();
    repository = NutritionConstraintRepository(database: db);
    await db
        .into(db.nutritionFoods)
        .insert(
          NutritionFoodsCompanion.insert(
            id: 'owned-food-1',
            kind: 'userCreated',
            displayName: 'User food',
            locale: 'en-IN',
            sourceType: 'user',
            lifecycle: 'active',
          ),
        );
  });

  tearDown(() => db.close());

  test(
    'Backup-v8 round trip preserves constraints and evidence without registry rows',
    () async {
      final constraint = await repository.createUserConstraint(
        userId: 'user-1',
        id: 'portable-constraint-1',
        type: NutritionConstraintType.allergy,
        target: NutritionConstraintTarget(
          type: NutritionConstraintTargetType.allergen,
          id: 'peanut',
        ),
      );
      await repository.recordFoodEvidence(
        foodId: 'owned-food-1',
        evidence: NutritionConstraintEvidence(
          id: 'portable-evidence-1',
          subjectId: 'owned-food-1',
          target: NutritionConstraintTarget(
            type: NutritionConstraintTargetType.allergen,
            id: 'peanut',
          ),
          status: NutritionConstraintEvidenceStatus.possible,
          source: NutritionConstraintEvidenceSource.userEntered,
        ),
      );

      final captured = await NutritionBackupGraph.capture(db);
      final json = captured.toJson();
      final tableNames = (json['tables'] as Map).keys.cast<String>().toSet();
      expect(tableNames, contains('nutrition_user_constraints'));
      expect(tableNames, contains('nutrition_food_constraint_evidence'));
      expect(tableNames, isNot(contains('nutrition_constraint_definitions')));

      final decoded = NutritionBackupGraph.fromJson(json);
      final target = AppDatabase.memory();
      addTearDown(target.close);
      await decoded.validateAgainstTarget(target);
      await decoded.restoreInto(target);
      final restored = NutritionConstraintRepository(database: target);
      expect(
        (await restored.listAllConstraints(userId: 'user-1')).single.id,
        constraint.id,
      );
      expect(
        (await restored.listFoodEvidence('owned-food-1')).single.status,
        NutritionConstraintEvidenceStatus.possible,
      );
    },
  );

  test(
    'Backup-v8 rejects malformed value envelopes and duplicate active constraints',
    () async {
      await repository.createUserConstraint(
        userId: 'user-1',
        id: 'constraint-a',
        type: NutritionConstraintType.allergy,
        target: NutritionConstraintTarget(
          type: NutritionConstraintTargetType.allergen,
          id: 'milk',
        ),
      );
      final graph = await NutritionBackupGraph.capture(db);
      final json = graph.toJson();
      final tables = Map<String, dynamic>.from(json['tables'] as Map);
      final rows = [
        for (final row in tables['nutrition_user_constraints'] as List)
          Map<String, dynamic>.from(row as Map),
      ];
      rows.single['value'] =
          '{"contract_version":99,"target":{"type":"allergen","id":"milk"},"active":true}';
      tables['nutrition_user_constraints'] = rows;
      final malformed = Map<String, dynamic>.from(json)..['tables'] = tables;
      expect(
        () => NutritionBackupGraph.fromJson(malformed),
        throwsA(
          isA<BackupV8ValidationException>().having(
            (error) => error.code,
            'code',
            'invalid_user_constraint',
          ),
        ),
      );

      final duplicate = await NutritionBackupGraph.capture(db);
      final duplicateJson = duplicate.toJson();
      final duplicateTables = Map<String, dynamic>.from(
        duplicateJson['tables'] as Map,
      );
      final duplicateRows = [
        for (final row in duplicateTables['nutrition_user_constraints'] as List)
          Map<String, dynamic>.from(row as Map),
      ];
      duplicateRows.add(Map<String, dynamic>.from(duplicateRows.single));
      duplicateRows.last['id'] = 'constraint-b';
      duplicateTables['nutrition_user_constraints'] = duplicateRows;
      final duplicatePayload = Map<String, dynamic>.from(duplicateJson)
        ..['tables'] = duplicateTables;
      expect(
        () => NutritionBackupGraph.fromJson(duplicatePayload),
        throwsA(
          isA<BackupV8ValidationException>().having(
            (error) => error.code,
            'code',
            'duplicate_active_constraint',
          ),
        ),
      );
    },
  );

  test('Backup-v8 rejects an orphan acknowledgement correction', () async {
    final acknowledgement = NutritionConstraintAcknowledgement(
      commandId: 'ack-command-1',
      userId: 'user-1',
      evaluationFingerprint: 'missing-evaluation-fingerprint',
      constraintId: 'constraint-1',
      reason: 'Acknowledged uncertainty.',
      acknowledgedAtUtc: DateTime.utc(2026, 8, 4),
    );
    await repository.recordAcknowledgement(acknowledgement);
    final graph = await NutritionBackupGraph.capture(db);
    expect(
      () => NutritionBackupGraph.fromJson(graph.toJson()),
      throwsA(
        isA<BackupV8ValidationException>().having(
          (error) => error.code,
          'code',
          'orphan_constraint_acknowledgement',
        ),
      ),
    );
  });
}
