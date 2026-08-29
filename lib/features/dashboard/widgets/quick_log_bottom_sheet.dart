import 'package:flutter/material.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../food_log/food_search_screen.dart';

class QuickLogBottomSheet extends StatelessWidget {
  final DateTime? selectedDate;
  const QuickLogBottomSheet({super.key, this.selectedDate});

  Widget _mealQuickActionButton(
    BuildContext context,
    String label,
    String type,
    IconData icon,
  ) {
    final colors = context.b05Colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: label,
          icon: Icon(icon, color: colors.action, size: 28),
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FoodSearchScreen(
                  mealType: type,
                  selectedDate: selectedDate,
                ),
              ),
            );
          },
        ),
        Text(
          label,
          style: B05Typography.caption(context).copyWith(fontSize: 11),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Meal Type',
            style: B05Typography.title(context).copyWith(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _mealQuickActionButton(
                context,
                'Breakfast',
                'breakfast',
                Icons.breakfast_dining_rounded,
              ),
              _mealQuickActionButton(
                context,
                'Lunch',
                'lunch',
                Icons.lunch_dining_rounded,
              ),
              _mealQuickActionButton(
                context,
                'Dinner',
                'dinner',
                Icons.dinner_dining_rounded,
              ),
              _mealQuickActionButton(
                context,
                'Snacks',
                'snack',
                Icons.cookie_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
