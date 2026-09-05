
import 'package:flutter/material.dart';


/// Food search widgets (PV1-ENG-05D first pass).
///
/// Extracted verbatim from `food_search_screen.dart`; unchanged.

class FoodQuantityReviewCapture extends StatelessWidget {
  const FoodQuantityReviewCapture({super.key, 
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

