import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/nutrition_thali.dart';
import '../../../core/theme/b05_semantic_colors.dart';

/// Classification zone on the circular Thali plate.
enum ThaliPlateZone {
  /// The center of the plate, reserved for staples (rotis, breads, rice).
  center,

  /// The radial perimeter, reserved for bowls (katoris).
  perimeter,
}

/// Culinary category for an Indian dish within the Thali.
enum ThaliDishCategory {
  stapleBread,
  stapleRice,
  dal,
  sabzi,
  curry,
  curd,
  side,
  sweet,
}

/// Placement and styling attributes for a classified Thali dish.
class ThaliDishPlacement {
  final ThaliPlateZone zone;
  final ThaliDishCategory category;
  final Color tint;
  final IconData icon;
  final String categoryLabel;

  const ThaliDishPlacement({
    required this.zone,
    required this.category,
    required this.tint,
    required this.icon,
    required this.categoryLabel,
  });
}

/// Pure presentation classifier for Indian meals.
///
/// Operates purely on display labels, foodId, and recipeVersionId.
/// Strictly non-mutating; has a deterministic safe fallback to [ThaliDishCategory.side].
abstract final class ThaliDishClassifier {
  static ThaliDishPlacement classify({
    String? displayLabel,
    String? foodId,
    String? recipeVersionId,
    required B05SemanticColors colors,
  }) {
    final text = '${displayLabel ?? ''} ${foodId ?? ''} ${recipeVersionId ?? ''}'.toLowerCase();

    // 1. Bread and traditional regional staples (Center)
    if (_matchesAny(text, [
      'roti', 'chapati', 'phulka', 'naan', 'paratha', 'poori', 'puri',
      'bread', 'kulcha', 'thepla', 'bhakri', 'rumali', 'parotta',
      'dosa', 'idli', 'uttapam', 'appam', 'vada', 'vadai', 'pesarattu', 'pathiri',
    ])) {
      return ThaliDishPlacement(
        zone: ThaliPlateZone.center,
        category: ThaliDishCategory.stapleBread,
        tint: const Color(0xFFD97706), // Warm toasted wheat
        icon: Icons.bakery_dining_rounded,
        categoryLabel: 'Roti / Staple',
      );
    }

    // 2. Rice staples (Center or Perimeter depending on bread presence)
    if (_matchesAny(text, [
      'rice', 'chawal', 'pulao', 'biryani', 'khichdi', 'jeera rice', 'curd rice',
    ])) {
      return ThaliDishPlacement(
        zone: ThaliPlateZone.center,
        category: ThaliDishCategory.stapleRice,
        tint: const Color(0xFFF59E0B), // Golden grain
        icon: Icons.rice_bowl_rounded,
        categoryLabel: 'Rice / Grain',
      );
    }

    // 3. Dal / Lentils / Legumes (Perimeter)
    if (_matchesAny(text, [
      'dal', 'daal', 'tadka', 'dal fry', 'dal makhani', 'sambar', 'rasam', 'kadhi',
      'chole', 'chana', 'rajma', 'moong', 'toor', 'urad', 'masoor',
    ])) {
      return ThaliDishPlacement(
        zone: ThaliPlateZone.perimeter,
        category: ThaliDishCategory.dal,
        tint: colors.warning.indicator, // Warm golden yellow
        icon: Icons.soup_kitchen_rounded,
        categoryLabel: 'Dal / Sambar',
      );
    }

    // 4. Sabzi / Cooked Vegetables (Perimeter)
    if (_matchesAny(text, [
      'sabzi', 'subzi', 'bhindi', 'palak', 'gobi', 'aloo', 'poriyal',
      'thoran', 'beans', 'cabbage', 'matar', 'karela', 'baingan',
      'methi', 'kofta', 'capsicum', 'shimla', 'lauki', 'tinda',
    ])) {
      return ThaliDishPlacement(
        zone: ThaliPlateZone.perimeter,
        category: ThaliDishCategory.sabzi,
        tint: colors.action, // Fresh emerald green
        icon: Icons.eco_rounded,
        categoryLabel: 'Sabzi / Veg',
      );
    }

    // 5. Protein / Paneer / Curries (Perimeter)
    if (_matchesAny(text, [
      'paneer', 'chicken', 'egg', 'fish', 'mutton', 'tofu', 'soya',
      'tikka', 'curry', 'korma', 'butter masala', 'makhani', 'masala', 'keema',
    ])) {
      return ThaliDishPlacement(
        zone: ThaliPlateZone.perimeter,
        category: ThaliDishCategory.curry,
        tint: const Color(0xFFEA580C), // Rich terracotta/orange
        icon: Icons.restaurant_menu_rounded,
        categoryLabel: 'Curry / Protein',
      );
    }

    // 6. Curd / Dairy / Fermented (Perimeter)
    if (_matchesAny(text, [
      'dahi', 'curd', 'raita', 'chaas', 'buttermilk', 'yogurt', 'lassi',
    ])) {
      return ThaliDishPlacement(
        zone: ThaliPlateZone.perimeter,
        category: ThaliDishCategory.curd,
        tint: colors.info.indicator, // Soft ivory/cool cyan
        icon: Icons.water_drop_rounded,
        categoryLabel: 'Curd / Raita',
      );
    }

    // 7. Sweets / Desserts (Perimeter)
    if (_matchesAny(text, [
      'halwa', 'kheer', 'gulab', 'jamun', 'ladoo', 'laddu', 'sweet',
      'jalebi', 'payasam', 'rasgulla', 'shrikhand', 'mithai',
    ])) {
      return ThaliDishPlacement(
        zone: ThaliPlateZone.perimeter,
        category: ThaliDishCategory.sweet,
        tint: const Color(0xFFF43F5E), // Rose / dessert pink
        icon: Icons.cake_rounded,
        categoryLabel: 'Sweet / Dessert',
      );
    }

    // 8. Sides / Condiments (Perimeter)
    if (_matchesAny(text, [
      'chutney', 'salad', 'pickle', 'achar', 'papad', 'papadum',
      'sirka', 'onion', 'lemon', 'mirchi',
    ])) {
      return ThaliDishPlacement(
        zone: ThaliPlateZone.perimeter,
        category: ThaliDishCategory.side,
        tint: colors.dinner.indicator, // Complementary accent
        icon: Icons.dinner_dining_rounded,
        categoryLabel: 'Chutney / Salad',
      );
    }

    // Deterministic safe fallback for any custom or unrecognized food
    return ThaliDishPlacement(
      zone: ThaliPlateZone.perimeter,
      category: ThaliDishCategory.side,
      tint: colors.action,
      icon: Icons.restaurant_rounded,
      categoryLabel: 'Side Dish',
    );
  }

  static bool _matchesAny(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }
}

/// Abstract representation of a positioned slot on the Thali plate.
sealed class ThaliPlateSlot {
  final double angle; // Polar angle in radians (-pi to pi)
  final int index;

  const ThaliPlateSlot({required this.angle, required this.index});
}

/// A slot holding an active Thali item.
class ThaliItemSlot extends ThaliPlateSlot {
  final NutritionThaliItem item;
  final NutritionThaliItemPreview? preview;
  final ThaliDishPlacement placement;

  const ThaliItemSlot({
    required this.item,
    this.preview,
    required this.placement,
    required super.angle,
    required super.index,
  });
}

/// An empty perimeter slot inviting the user to tap and add a new dish.
class ThaliAddSlot extends ThaliPlateSlot {
  const ThaliAddSlot({
    required super.angle,
    required super.index,
  });
}

/// An overflow slot representing N additional dishes beyond the 6-slot circular cap.
class ThaliOverflowSlot extends ThaliPlateSlot {
  final int overflowCount;

  const ThaliOverflowSlot({
    required this.overflowCount,
    required super.angle,
    required super.index,
  });
}

/// Engine that computes the spatial arrangement of dishes on a circular Thali plate.
class ThaliPlateLayoutEngine {
  static const int maxPerimeterKatoris = 6;

  /// Organizes items into center staples and radial perimeter katoris.
  static ({
    List<ThaliItemSlot> centerStaples,
    List<ThaliPlateSlot> perimeterSlots,
  }) computeLayout({
    required List<NutritionThaliItem> items,
    required List<NutritionThaliItemPreview> previews,
    required B05SemanticColors colors,
    bool showAddSlot = true,
  }) {
    final centerStaples = <ThaliItemSlot>[];
    final perimeterItems = <({NutritionThaliItem item, NutritionThaliItemPreview? preview, ThaliDishPlacement placement})>[];

    // First classify all items
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final preview = previews.where((p) => p.item.id == item.id).firstOrNull;
      final placement = ThaliDishClassifier.classify(
        displayLabel: item.displayLabel,
        foodId: item.foodId,
        recipeVersionId: item.recipeVersionId,
        colors: colors,
      );

      if (placement.zone == ThaliPlateZone.center) {
        centerStaples.add(
          ThaliItemSlot(
            item: item,
            preview: preview,
            placement: placement,
            angle: 0.0,
            index: i,
          ),
        );
      } else {
        perimeterItems.add((item: item, preview: preview, placement: placement));
      }
    }

    // If no staple was categorized into center, but perimeter has items,
    // let rice or first item occupy center if appropriate, or keep center open for visual balance.
    // (By default, centerStaples can remain empty or contain staples).

    final perimeterSlots = <ThaliPlateSlot>[];
    final totalPerimeter = perimeterItems.length;

    if (totalPerimeter <= maxPerimeterKatoris) {
      // All items fit around perimeter
      final hasAddSlot = showAddSlot && totalPerimeter < maxPerimeterKatoris;
      final totalPositions = totalPerimeter + (hasAddSlot ? 1 : 0);

      for (int i = 0; i < totalPerimeter; i++) {
        final angle = _computeAngle(i, totalPositions);
        final entry = perimeterItems[i];
        perimeterSlots.add(
          ThaliItemSlot(
            item: entry.item,
            preview: entry.preview,
            placement: entry.placement,
            angle: angle,
            index: i,
          ),
        );
      }

      if (hasAddSlot) {
        final angle = _computeAngle(totalPerimeter, totalPositions);
        perimeterSlots.add(ThaliAddSlot(angle: angle, index: totalPerimeter));
      }
    } else {
      // Overflow scenario: show 5 individual katoris + 1 overflow slot (+N more)
      const visibleCount = maxPerimeterKatoris - 1; // 5
      const totalPositions = maxPerimeterKatoris; // 6

      for (int i = 0; i < visibleCount; i++) {
        final angle = _computeAngle(i, totalPositions);
        final entry = perimeterItems[i];
        perimeterSlots.add(
          ThaliItemSlot(
            item: entry.item,
            preview: entry.preview,
            placement: entry.placement,
            angle: angle,
            index: i,
          ),
        );
      }

      final overflowCount = totalPerimeter - visibleCount;
      final overflowAngle = _computeAngle(visibleCount, totalPositions);
      perimeterSlots.add(
        ThaliOverflowSlot(
          overflowCount: overflowCount,
          angle: overflowAngle,
          index: visibleCount,
        ),
      );
    }

    return (centerStaples: centerStaples, perimeterSlots: perimeterSlots);
  }

  /// Distributes angles clockwise starting from top-center (-pi/2)
  static double _computeAngle(int index, int total) {
    if (total <= 0) return -math.pi / 2;
    final step = (2 * math.pi) / total;
    return -math.pi / 2 + (index * step);
  }
}
