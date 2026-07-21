class HouseholdMeasure {
  final String key;
  final String label;
  final String labelHindi;
  final double gramEquivalent; // Approximate gram/ml weight for 1 unit

  const HouseholdMeasure({
    required this.key,
    required this.label,
    required this.labelHindi,
    required this.gramEquivalent,
  });

  static const List<HouseholdMeasure> allMeasures = [
    HouseholdMeasure(key: 'g', label: 'Gram (g)', labelHindi: 'ग्राम', gramEquivalent: 1.0),
    HouseholdMeasure(key: 'ml', label: 'Milliliter (ml)', labelHindi: 'मिली', gramEquivalent: 1.0),
    HouseholdMeasure(key: 'piece', label: 'Piece / Item', labelHindi: 'टुकड़ा / पीस', gramEquivalent: 50.0),
    HouseholdMeasure(key: 'serving', label: 'Standard Serving', labelHindi: 'सर्विंग', gramEquivalent: 100.0),
    HouseholdMeasure(key: 'katori', label: 'Standard Katori (~150g)', labelHindi: 'कटोरी (~150 ग्राम)', gramEquivalent: 150.0),
    HouseholdMeasure(key: 'katori_full', label: 'Full Katori (~200g)', labelHindi: 'बड़ी कटोरी (~200 ग्राम)', gramEquivalent: 200.0),
    HouseholdMeasure(key: 'tbsp_ghee', label: 'Tbsp Ghee / Oil (~15g)', labelHindi: 'चम्मच घी/तेल (~15 ग्राम)', gramEquivalent: 15.0),
    HouseholdMeasure(key: 'small_roti', label: 'Small Roti (~30g)', labelHindi: 'छोटी रोटी (~30 ग्राम)', gramEquivalent: 30.0),
    HouseholdMeasure(key: 'medium_roti', label: 'Medium Roti (~45g)', labelHindi: 'मध्यम रोटी (~45 ग्राम)', gramEquivalent: 45.0),
    HouseholdMeasure(key: 'large_roti', label: 'Large Roti (~60g)', labelHindi: 'बड़ी रोटी (~60 ग्राम)', gramEquivalent: 60.0),
    HouseholdMeasure(key: 'cup', label: 'Measuring Cup (~240g)', labelHindi: 'कप (~240 ग्राम)', gramEquivalent: 240.0),
    HouseholdMeasure(key: 'thali', label: 'Full Thali Plate', labelHindi: 'थाली', gramEquivalent: 400.0),
  ];

  static HouseholdMeasure findByKey(String key) {
    return allMeasures.firstWhere(
      (m) => m.key.toLowerCase() == key.toLowerCase(),
      orElse: () => const HouseholdMeasure(
        key: 'serving',
        label: 'Serving',
        labelHindi: 'सर्विंग',
        gramEquivalent: 100.0,
      ),
    );
  }

  /// Calculates scaling multiplier when switching between units
  static double getScaleMultiplier({
    required String baseUnit,
    required double baseAmount,
    required String targetUnit,
    required double targetAmount,
  }) {
    final base = findByKey(baseUnit);
    final target = findByKey(targetUnit);

    final baseTotalWeight = base.gramEquivalent * baseAmount;
    if (baseTotalWeight == 0) return 1.0;

    final targetTotalWeight = target.gramEquivalent * targetAmount;
    return targetTotalWeight / baseTotalWeight;
  }
}
