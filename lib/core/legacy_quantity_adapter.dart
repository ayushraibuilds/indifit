import 'typed_quantities.dart';

const int kLegacyQuantityAdapterContractVersion = 1;

enum LegacyQuantityStatus { resolved, nullValue, unresolved }

/// An explicitly retained value that could not be safely typed.
class LegacyQuantityValue {
  final String? rawAmount;
  final String? rawUnit;
  final String reason;

  const LegacyQuantityValue({
    required this.rawAmount,
    required this.rawUnit,
    required this.reason,
  });

  QuantityDimension get dimension => QuantityDimension.legacy;

  Map<String, dynamic> toJson() => {
    'contract_version': kLegacyQuantityAdapterContractVersion,
    'amount': rawAmount,
    'unit': rawUnit,
    'reason': reason,
  };
}

class LegacyQuantityAdaptation {
  final LegacyQuantityStatus status;
  final Quantity? quantity;
  final LegacyQuantityValue? unresolved;
  final QuantityError? error;

  const LegacyQuantityAdaptation._({
    required this.status,
    this.quantity,
    this.unresolved,
    this.error,
  });

  const LegacyQuantityAdaptation.resolved(Quantity quantity)
    : this._(status: LegacyQuantityStatus.resolved, quantity: quantity);

  const LegacyQuantityAdaptation.nullValue()
    : this._(status: LegacyQuantityStatus.nullValue);

  const LegacyQuantityAdaptation.unresolved({
    required LegacyQuantityValue value,
    QuantityError? error,
  }) : this._(
         status: LegacyQuantityStatus.unresolved,
         unresolved: value,
         error: error,
       );

  bool get isResolved => status == LegacyQuantityStatus.resolved;
}

/// Pure, bounded adapters for the current v16 food-log quantity fields.
///
/// This adapter never reads or writes the database. It recognizes only
/// explicit same-dimension units and preserves all other legacy labels as
/// unresolved values.
class LegacyQuantityAdapter {
  LegacyQuantityAdapter._();

  static LegacyQuantityAdaptation adapt({
    required num? amount,
    required String? unit,
  }) {
    if (amount == null && unit == null) {
      return const LegacyQuantityAdaptation.nullValue();
    }
    if (amount == null || unit == null || unit.trim().isEmpty) {
      return LegacyQuantityAdaptation.unresolved(
        value: LegacyQuantityValue(
          rawAmount: amount?.toString(),
          rawUnit: unit,
          reason: 'Legacy amount or unit is incomplete.',
        ),
        error: const UnsupportedLegacyQuantityError(
          'Legacy amount and unit must both be present.',
        ),
      );
    }

    QuantityAmount typedAmount;
    try {
      typedAmount = QuantityAmount.fromNum(amount);
    } on QuantityError catch (error) {
      return LegacyQuantityAdaptation.unresolved(
        value: LegacyQuantityValue(
          rawAmount: amount.toString(),
          rawUnit: unit,
          reason: error.message,
        ),
        error: error,
      );
    }

    final normalized = unit.trim().toLowerCase();
    final definition = _explicitLegacyUnit(normalized);
    if (definition == null) {
      return LegacyQuantityAdaptation.unresolved(
        value: LegacyQuantityValue(
          rawAmount: amount.toString(),
          rawUnit: unit,
          reason: 'No reviewed typed meaning exists for this legacy label.',
        ),
        error: UnsupportedLegacyQuantityError(
          'Legacy unit remains unresolved: $unit',
        ),
      );
    }

    if (definition.unit == QuantityUnit.serving) {
      final legacyDefinition = ServingDefinitionReference(
        id: 'legacy-serving:$normalized',
        revision: 'legacy-v1',
        source: 'legacy',
      );
      return LegacyQuantityAdaptation.resolved(
        Quantity(
          amount: typedAmount,
          unit: QuantityUnit.serving,
          context: QuantityContext(
            servingDefinition: legacyDefinition,
            source: 'legacy',
            legacy: true,
          ),
        ),
      );
    }

    return LegacyQuantityAdaptation.resolved(
      Quantity(
        amount: typedAmount,
        unit: definition.unit,
        context: const QuantityContext(legacy: true, source: 'legacy'),
      ),
    );
  }

  static QuantityUnitDefinition? _explicitLegacyUnit(String normalized) {
    const explicitUnits = <String>{
      'mg',
      'milligram',
      'milligrams',
      'g',
      'gram',
      'grams',
      'kg',
      'kilogram',
      'kilograms',
      'ml',
      'millilitre',
      'millilitres',
      'milliliter',
      'milliliters',
      'l',
      'litre',
      'litres',
      'liter',
      'liters',
      'piece',
      'pieces',
      'pc',
      'item',
      'items',
      'serving',
      'servings',
    };
    if (!explicitUnits.contains(normalized)) return null;
    return QuantityUnitRegistry.resolveToken(normalized);
  }
}
