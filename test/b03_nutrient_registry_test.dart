import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';

NutrientRegistry loadRegistry() =>
    NutrientRegistry.fromAssetFileSync('assets/data/nutrient_registry.json');

void main() {
  test('checked-in registry has stable version and approved definitions', () {
    final registry = loadRegistry();

    expect(registry.version, kNutrientRegistryVersion);
    expect(registry.definitions, hasLength(18));
    expect(registry.definitionFor('protein').unit, NutrientUnit.gram);
    expect(registry.definitionFor('energy').unit, NutrientUnit.kilocalorie);
    expect(registry.definitionFor('vitamin_b12').unit, NutrientUnit.microgram);
  });

  test('registry reordering does not change stable IDs or machine IDs', () {
    final original = loadRegistry();
    final reordered = NutrientRegistry(
      version: original.version,
      definitions: original.definitions.reversed,
    );

    for (final definition in original.definitions) {
      final other = reordered.definitionFor(definition.id);
      expect(other.machineId, definition.machineId);
      expect(other.unit, definition.unit);
    }
  });

  test('duplicate IDs and machine IDs are rejected', () {
    final original = loadRegistry().definitions;
    final duplicateId = [...original, original.first];
    final duplicateMachineId = [
      ...original,
      NutrientDefinition(
        id: 'new_nutrient',
        machineId: original.first.machineId,
        displayName: 'New nutrient',
        unit: NutrientUnit.gram,
        category: NutrientCategory.other,
        calculationPrecision: 2,
        displayPrecision: 1,
        aggregation: NutrientAggregationBehavior.additive,
        supportState: NutrientSupportState.supported,
        deprecated: false,
      ),
    ];

    expect(
      () => NutrientRegistry(version: 1, definitions: duplicateId),
      throwsA(isA<NutrientValidationError>()),
    );
    expect(
      () => NutrientRegistry(version: 1, definitions: duplicateMachineId),
      throwsA(isA<NutrientValidationError>()),
    );
  });

  test('unsupported registry versions fail before a registry is exposed', () {
    final json =
        jsonDecode(
              File('assets/data/nutrient_registry.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    json['registry_version'] = kNutrientRegistryVersion + 1;

    expect(
      () => NutrientRegistry.fromJson(json),
      throwsA(isA<NutrientRegistryVersionError>()),
    );
  });

  test('display metadata changes do not change identity', () {
    final json =
        jsonDecode(
              File('assets/data/nutrient_registry.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final nutrients = (json['nutrients'] as List).cast<Map<String, dynamic>>();
    final first = nutrients.first;
    first['display_name'] = 'Protein (renamed for presentation)';
    final renamed = NutrientRegistry.fromJson(json);

    expect(renamed.definitionFor('energy').machineId, 'energy');
    expect(renamed.definitionFor('energy').id, 'energy');
    expect(
      renamed.definitions.map((item) => item.id),
      loadRegistry().definitions.map((item) => item.id),
    );
  });

  test(
    'serialization is deterministic and labels do not change unit identity',
    () {
      final registry = loadRegistry();
      final roundTripped = NutrientRegistry.fromJson(
        jsonDecode(registry.toJsonString()),
      );

      expect(roundTripped.toJsonString(), registry.toJsonString());
      expect(NutrientUnitContract.fromStableId('mass_gram'), NutrientUnit.gram);
      expect(NutrientUnit.gram.symbol, 'g');
      expect(NutrientUnit.microgram.displayLabel, 'micrograms');
      expect(
        roundTripped.definitionFor('protein').toJson()['unit'],
        'mass_gram',
      );
    },
  );
}
