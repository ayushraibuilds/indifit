import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../exercise_library/exercise_library_screen.dart';
import '../workout_player/routine_display_screen.dart';
import '../progress/progress_screen.dart';
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
    const ProgressScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryGlow,
        animationDuration: const Duration(milliseconds: 300),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today_rounded, color: AppColors.primary),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center_rounded, color: AppColors.primary),
            label: 'Workouts',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books_rounded, color: AppColors.primary),
            label: 'Exercises',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_graph_outlined),
            selectedIcon: Icon(Icons.auto_graph_rounded, color: AppColors.primary),
            label: 'Progress',
          ),
        ],
      ),
    );
  }
}
