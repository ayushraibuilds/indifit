import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../exercise_library/exercise_library_screen.dart';
import '../workout_player/routine_display_screen.dart';
import 'dashboard_screen.dart';

class MainNavigationScaffold extends StatefulWidget {
  const MainNavigationScaffold({super.key});

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const RoutineDisplayScreen(),
    const ExerciseLibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu_rounded),
            activeIcon: Icon(Icons.restaurant_menu_rounded, color: AppColors.primary),
            label: 'Diet Tracker',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_rounded),
            activeIcon: Icon(Icons.fitness_center_rounded, color: AppColors.primary),
            label: 'Workouts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books_rounded),
            activeIcon: Icon(Icons.library_books_rounded, color: AppColors.primary),
            label: 'Exercises',
          ),
        ],
      ),
    );
  }
}
