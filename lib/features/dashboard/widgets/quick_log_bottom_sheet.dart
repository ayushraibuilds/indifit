import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../food_log/food_search_screen.dart';

class QuickLogBottomSheet extends StatelessWidget {
  const QuickLogBottomSheet({super.key});

  Widget _mealQuickActionButton(BuildContext context, String label, String type, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: AppColors.primary, size: 28),
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FoodSearchScreen(mealType: type)),
            );
          },
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
          const Text('Select Meal Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _mealQuickActionButton(context, 'Breakfast', 'breakfast', Icons.breakfast_dining_rounded),
              _mealQuickActionButton(context, 'Lunch', 'lunch', Icons.lunch_dining_rounded),
              _mealQuickActionButton(context, 'Dinner', 'dinner', Icons.dinner_dining_rounded),
              _mealQuickActionButton(context, 'Snacks', 'snack', Icons.cookie_rounded),
            ],
          ),
        ],
      ),
    );
  }
}
