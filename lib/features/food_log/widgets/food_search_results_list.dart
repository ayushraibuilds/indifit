import 'package:flutter/material.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/consumer_task_primitives.dart';
import '../../../data/services/nutrition_food_search_ranking.dart';
import 'food_search_widgets.dart';

/// No-results empty state extracted verbatim from `food_search_screen.dart`.
class FoodSearchNoResultsState extends StatelessWidget {
  final VoidCallback onCreateCustomFood;

  const FoodSearchNoResultsState({
    super.key,
    required this.onCreateCustomFood,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: context.b05Colors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text('No foods found', style: B05Typography.label(context)),
            const SizedBox(height: 4),
            Text(
              'Try another name or create a custom food.',
              style: B05Typography.body(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreateCustomFood,
              icon: const Icon(Icons.add),
              label: const Text('Create a custom food'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search results list extracted from `food_search_screen.dart`.
///
/// Encapsulates ranked search results, offline status warning, online searching spinner, and no results state.
class FoodSearchResultsList extends StatelessWidget {
  final bool isOnlineSearchOffline;
  final bool searchingOnline;
  final String? onlineFailureMessage;
  final VoidCallback onRetrySearch;
  final List<NutritionFoodSearchResult> searchResults;
  final Widget Function(BuildContext context, NutritionFoodSearchResult result) searchResultItemBuilder;
  final VoidCallback onCreateCustomFood;

  const FoodSearchResultsList({
    super.key,
    required this.isOnlineSearchOffline,
    required this.searchingOnline,
    this.onlineFailureMessage,
    required this.onRetrySearch,
    required this.searchResults,
    required this.searchResultItemBuilder,
    required this.onCreateCustomFood,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (isOnlineSearchOffline)
          ConsumerStatusRow(
            label: searchResults.isNotEmpty
                ? 'Showing matching foods'
                : 'Online search unavailable',
            detail: searchResults.isNotEmpty
                ? 'Online results are temporarily unavailable.'
                : onlineFailureMessage ?? 'Try again or choose from Recent.',
            error: searchResults.isEmpty,
            onRetry: onRetrySearch,
          ),
        if (searchResults.isNotEmpty) ...[
          const FoodSearchSectionHeader(title: 'Search results'),
          for (final result in searchResults)
            searchResultItemBuilder(context, result),
        ],
        if (searchingOnline)
          const ConsumerStatusRow(
            label: 'Searching for more matches',
            detail: 'Matching foods are ready to use.',
            loading: true,
          ),
        if (!searchingOnline &&
            !isOnlineSearchOffline &&
            searchResults.isEmpty)
          FoodSearchNoResultsState(
            onCreateCustomFood: onCreateCustomFood,
          ),
      ],
    );
  }
}
