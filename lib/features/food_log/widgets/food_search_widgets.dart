import 'package:flutter/material.dart';

import '../../../core/widgets/b05_accessibility_primitives.dart';

export 'food_search_bar.dart';
export 'food_search_recent_list.dart';
export 'food_search_results_list.dart';

/// Food search widgets (PV1-ENG-05D first and second pass).
///
/// Extracted verbatim from `food_search_screen.dart`; unchanged.

class FoodQuantityReviewCapture extends StatelessWidget {
  const FoodQuantityReviewCapture({
    super.key,
    required this.padding,
    required this.child,
  });

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: const ValueKey('food_quantity_review_surface'),
    child: Padding(
      padding: padding,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: child,
      ),
    ),
  );
}

class FoodSearchSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const FoodSearchSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: B05Typography.title(context)),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(sub, style: B05Typography.caption(context)),
            ),
        ],
      ),
    );
  }
}
