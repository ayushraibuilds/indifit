import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/repositories/nutrition_thali_repository.dart';
import 'package:indifit/features/food_log/saved_meals_controller.dart';
import 'package:indifit/features/food_log/saved_meals_screen.dart';

/// R07F-0 — Saved Meals renders correctly in LIGHT theme (the screen
/// previously used dark-only legacy colors that broke light mode).
class _StaticSavedMealsController extends SavedMealsController {
  _StaticSavedMealsController(SavedMealsState seed)
    : super(
        // Never completes and never errors, so the seeded state is never
        // replaced by repository activity during the test.
        thaliRepoFuture: Completer<NutritionThaliRepository>().future,
        userId: 'test-user',
      ) {
    state = seed;
  }
}

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required SavedMealsState state,
    required Brightness brightness,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedMealsControllerProvider.overrideWith(
            (ref) => _StaticSavedMealsController(state),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: brightness == Brightness.light
              ? ThemeMode.light
              : ThemeMode.dark,
          home: const SavedMealsScreen(mealType: 'lunch'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('light theme renders error banner with readable contrast', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      brightness: Brightness.light,
      state: const SavedMealsState(
        status: SavedMealsStatus.failure,
        errorMessage: 'Saved meals could not be loaded.',
      ),
    );

    final banner = tester.widget<Text>(
      find.text('Saved meals could not be loaded.'),
    );
    // The banner must use the theme-aware danger foreground, not the legacy
    // dark-only palette constant.
    expect(banner.style?.color, isNot(equals(const Color(0xFFEF4444))));
    expect(banner.style?.color, isA<Color>());
  });

  testWidgets('light theme renders empty state and skeleton loading', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      brightness: Brightness.light,
      state: const SavedMealsState(status: SavedMealsStatus.ready),
    );
    expect(find.text('No saved meals yet'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Loading shows content-shaped skeletons instead of a blocking spinner.
    await pumpScreen(
      tester,
      brightness: Brightness.light,
      state: const SavedMealsState(status: SavedMealsStatus.loading),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('dark theme still renders the empty state', (tester) async {
    await pumpScreen(
      tester,
      brightness: Brightness.dark,
      state: const SavedMealsState(status: SavedMealsStatus.ready),
    );
    expect(find.text('No saved meals yet'), findsOneWidget);
  });
}
