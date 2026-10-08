import 'package:flutter/material.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/consumer_task_primitives.dart';
import '../../../data/services/nutrition_food_search_ranking.dart';
import 'food_search_widgets.dart';

/// No-results empty state extracted verbatim from `food_search_screen.dart`.
class FoodSearchNoResultsState extends StatelessWidget {
  final VoidCallback onCreateCustomFood;

  const FoodSearchNoResultsState({super.key, required this.onCreateCustomFood});

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
  final Widget Function(BuildContext context, NutritionFoodSearchResult result)
  searchResultItemBuilder;
  final VoidCallback onCreateCustomFood;

  /// The search to offer as "couldn't find it" (CAT-13); null hides it.
  final String? missedQuery;

  /// True once [missedQuery] was added to the list.
  final bool missedQuerySaved;
  final VoidCallback? onAddMissedQuery;

  const FoodSearchResultsList({
    super.key,
    required this.isOnlineSearchOffline,
    required this.searchingOnline,
    this.onlineFailureMessage,
    required this.onRetrySearch,
    required this.searchResults,
    required this.searchResultItemBuilder,
    required this.onCreateCustomFood,
    this.missedQuery,
    this.missedQuerySaved = false,
    this.onAddMissedQuery,
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
        if (!searchingOnline && !isOnlineSearchOffline && searchResults.isEmpty)
          FoodSearchNoResultsState(onCreateCustomFood: onCreateCustomFood),
        if (!searchingOnline && missedQuery != null)
          FoodSearchMissedQueryRow(
            query: missedQuery!,
            saved: missedQuerySaved,
            onAdd: onAddMissedQuery,
          ),
      ],
    );
  }
}

/// "Can't find "kathal sabzi"?" at the end of a search (CAT-13). Adds the
/// words to a list on this phone; nothing is sent from here.
class FoodSearchMissedQueryRow extends StatelessWidget {
  const FoodSearchMissedQueryRow({
    super.key,
    required this.query,
    required this.saved,
    this.onAdd,
  });

  final String query;
  final bool saved;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('food_search_missed_query'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Can\'t find "$query"?', style: B05Typography.label(context)),
          const SizedBox(height: 2),
          Text(
            saved
                ? 'Added to your list. Send it from Settings → Food database '
                      'when you\'re ready.'
                : 'Add it to a list on this phone. You choose later whether '
                      'to send the list to IndiFit.',
            style: B05Typography.caption(context),
          ),
          if (!saved) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('Add to my list'),
            ),
          ],
        ],
      ),
    );
  }
}
