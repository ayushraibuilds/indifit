class ParsedMealItem {
  final String foodName;
  final double quantity;
  final String unit;

  const ParsedMealItem({
    required this.foodName,
    required this.quantity,
    required this.unit,
  });
}

class NaturalMealParser {
  /// Parses natural-language strings like "2 rotis and 100g paneer and 1 bowl dal"
  static List<ParsedMealItem> parse(String text) {
    if (text.trim().isEmpty) return [];

    final items = <ParsedMealItem>[];
    final parts = text.toLowerCase().split(RegExp(r'\band\b|\b,\b|\b\+\b'));

    for (final rawPart in parts) {
      final part = rawPart.trim();
      if (part.isEmpty) continue;

      final match = RegExp(r'^(\d+(?:\.\d+)?)\s*([a-zA-Z]+)?\s+(.+)$').firstMatch(part);
      if (match != null) {
        final qty = double.tryParse(match.group(1)!) ?? 1.0;
        final possibleUnit = match.group(2) ?? '';
        final name = match.group(3)!.trim();

        String unit = possibleUnit.isEmpty ? 'serving' : possibleUnit;
        if (unit == 'g' || unit == 'grams') unit = 'g';
        if (unit == 'ml' || unit == 'milliliters') unit = 'ml';

        items.add(ParsedMealItem(
          foodName: name,
          quantity: qty,
          unit: unit,
        ));
      } else {
        // Fallback: entire string as food name with quantity 1.0
        items.add(ParsedMealItem(
          foodName: part,
          quantity: 1.0,
          unit: 'serving',
        ));
      }
    }

    return items;
  }
}
