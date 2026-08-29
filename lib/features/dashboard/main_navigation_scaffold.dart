import 'package:flutter/material.dart';

import '../../core/widgets/b05_accessibility_primitives.dart';
import '../food_log/food_search_screen.dart';
import '../progress/progress_screen.dart';
import '../training/training_screen.dart';
import 'dashboard_screen.dart';

class MainNavigationScaffold extends StatefulWidget {
  const MainNavigationScaffold({
    super.key,
    this.initialIndex = 0,
    this.foodMealType,
    this.foodSelectedDate,
    this.foodReturnToParentOnSave = false,
  });

  final int initialIndex;
  final String? foodMealType;
  final DateTime? foodSelectedDate;
  final bool foodReturnToParentOnSave;

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  static const _screenCount = 4;
  late int _currentIndex;
  late List<Widget> _screens;
  final Set<int> _visitedIndexes = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _screenCount - 1);
    _screens = List<Widget>.filled(
      _screenCount,
      const SizedBox.shrink(),
      growable: false,
    );
    _activateScreen(_currentIndex);
  }

  @override
  void didUpdateWidget(covariant MainNavigationScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.foodMealType != widget.foodMealType ||
        oldWidget.foodSelectedDate != widget.foodSelectedDate ||
        oldWidget.foodReturnToParentOnSave != widget.foodReturnToParentOnSave) {
      if (_visitedIndexes.contains(2)) _screens[2] = _screenFor(2);
    }
    if (oldWidget.initialIndex != widget.initialIndex) {
      _currentIndex = widget.initialIndex.clamp(0, _screenCount - 1);
      _activateScreen(_currentIndex);
    }
  }

  void _activateScreen(int index) {
    if (_visitedIndexes.add(index)) _screens[index] = _screenFor(index);
  }

  Widget _screenFor(int index) => switch (index) {
    0 => const DashboardScreen(),
    1 => const TrainingScreen(),
    2 => _FoodTabRoot(
      initialMealType: widget.foodMealType,
      selectedDate: widget.foodSelectedDate,
      returnToParentOnSave: widget.foodReturnToParentOnSave,
    ),
    3 => const ProgressScreen(),
    _ => const SizedBox.shrink(),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (index != 2) FocusManager.instance.primaryFocus?.unfocus();
          setState(() {
            _currentIndex = index;
            _activateScreen(index);
          });
        },
        animationDuration: B05MotionPolicy.transitionDuration(
          context,
          standard: const Duration(milliseconds: 220),
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today_rounded),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center_rounded),
            label: 'Training',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant_rounded),
            label: 'Food',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up_rounded),
            label: 'Progress',
          ),
        ],
      ),
    );
  }
}

/// Keeps Food Home mounted as the indexed destination while meal logging is
/// presented as a child task. Explicit meal routes (for example Today quick
/// add) enter the same child and may return to their external parent on exit.
class _FoodTabRoot extends StatefulWidget {
  const _FoodTabRoot({
    required this.initialMealType,
    required this.selectedDate,
    required this.returnToParentOnSave,
  });

  final String? initialMealType;
  final DateTime? selectedDate;
  final bool returnToParentOnSave;

  @override
  State<_FoodTabRoot> createState() => _FoodTabRootState();
}

class _FoodTabRootState extends State<_FoodTabRoot> {
  bool _openedInitialChild = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openInitialChild());
  }

  Future<void> _openInitialChild() async {
    final mealType = widget.initialMealType;
    if (_openedInitialChild || mealType == null || !mounted) return;
    _openedInitialChild = true;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          mealType: mealType,
          selectedDate: widget.selectedDate,
          returnToParentOnSave: true,
        ),
      ),
    );
    if (mounted && widget.returnToParentOnSave) {
      await Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) => FoodSearchScreen(
    mealType: null,
    selectedDate: widget.selectedDate,
    returnToParentOnSave: false,
  );
}
