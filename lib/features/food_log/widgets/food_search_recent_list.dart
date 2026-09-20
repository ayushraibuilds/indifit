import 'package:flutter/material.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/consumer_task_primitives.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../data/database/app_database.dart';
import '../food_search_view_models.dart';
import 'food_search_widgets.dart';

/// Navigation card extracted verbatim from `food_search_screen.dart`.
class FoodSearchNavigationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  const FoodSearchNavigationCard({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => B05Surface(
    padding: EdgeInsets.zero,
    child: Semantics(
      container: true,
      explicitChildNodes: true,
      button: true,
      label: title,
      hint: detail,
      child: ListTile(
        minVerticalPadding: 12,
        leading: Icon(icon, color: context.b05Colors.action),
        title: Text(title, style: B05Typography.label(context)),
        subtitle: Text(detail, style: B05Typography.caption(context)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    ),
  );
}

/// Landing empty state banner extracted verbatim from `food_search_screen.dart`.
class FoodSearchLandingEmpty extends StatelessWidget {
  final String title;
  final String message;

  const FoodSearchLandingEmpty({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => B05Surface(
    subtle: true,
    showBorder: false,
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.history_rounded, color: context.b05Colors.action),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: B05Typography.label(context)),
              const SizedBox(height: 2),
              Text(message, style: B05Typography.body(context)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Recent and landing state list extracted from `food_search_screen.dart`.
///
/// Encapsulates Recent, Frequent, Saved & recipes, and More ways sections.
class FoodSearchRecentList extends StatelessWidget {
  final Widget? neutralFoodEntry;
  final bool loadingRecent;
  final String? recentFailureMessage;
  final VoidCallback onRetryRecent;
  final List<CanonicalRecentFood> canonicalRecentResults;
  final List<FoodItem> recentResults;
  final Widget Function(BuildContext context, CanonicalRecentFood recent) canonicalRecentItemBuilder;
  final Widget Function(BuildContext context, FoodItem food) recentItemBuilder;
  final VoidCallback onOpenSavedMeals;
  final VoidCallback onOpenSavedRecipes;
  final VoidCallback onOpenBarcode;
  final VoidCallback onScanNutritionLabel;
  final VoidCallback onDescribeMeal;
  final Widget? entriesPanel;

  const FoodSearchRecentList({
    super.key,
    this.neutralFoodEntry,
    required this.loadingRecent,
    this.recentFailureMessage,
    required this.onRetryRecent,
    required this.canonicalRecentResults,
    required this.recentResults,
    required this.canonicalRecentItemBuilder,
    required this.recentItemBuilder,
    required this.onOpenSavedMeals,
    required this.onOpenSavedRecipes,
    required this.onOpenBarcode,
    required this.onScanNutritionLabel,
    required this.onDescribeMeal,
    this.entriesPanel,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (neutralFoodEntry != null) ...[
          neutralFoodEntry!,
          const SizedBox(height: 16),
        ],
        const FoodSearchSectionHeader(
          title: 'Recent',
          subtitle: 'Foods you log often stay close at hand.',
        ),
        if (loadingRecent)
          const SkeletonList(count: 3)
        else if (recentFailureMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ConsumerStatusRow(
              label: 'Recent foods unavailable',
              detail: recentFailureMessage,
              error: true,
              onRetry: onRetryRecent,
            ),
          )
        else if (canonicalRecentResults.isEmpty && recentResults.isEmpty)
          const FoodSearchLandingEmpty(
            title: 'No recent foods yet',
            message: 'Foods you log will appear here.',
          )
        else
          ...canonicalRecentResults.map((item) => canonicalRecentItemBuilder(context, item)),
        if (!loadingRecent &&
            recentResults.isNotEmpty &&
            canonicalRecentResults.isNotEmpty)
          const SizedBox(height: 8),
        if (!loadingRecent)
          ...recentResults.take(6).map((food) => recentItemBuilder(context, food)),
        if (canonicalRecentResults.any((item) => item.frequencyCount > 1)) ...[
          const SizedBox(height: 16),
          const FoodSearchSectionHeader(
            title: 'Frequent',
            subtitle: 'Your repeat choices, ordered by real local history.',
          ),
          ...((canonicalRecentResults
                  .where((item) => item.frequencyCount > 1)
                  .toList()
                ..sort((left, right) {
                  final count = right.frequencyCount.compareTo(
                    left.frequencyCount,
                  );
                  if (count != 0) return count;
                  final date = right.loggedAtUtc.compareTo(left.loggedAtUtc);
                  if (date != 0) return date;
                  return left.option.id.compareTo(right.option.id);
                }))
              .map((item) => canonicalRecentItemBuilder(context, item))),
        ],
        const SizedBox(height: 16),
        const FoodSearchSectionHeader(
          title: 'Saved & recipes',
          subtitle: 'Saved meals and recipes you make often.',
        ),
        FoodSearchNavigationCard(
          icon: Icons.bookmark_outline_rounded,
          title: 'Saved meals',
          detail: 'Quickly log meal combinations you saved.',
          onTap: onOpenSavedMeals,
        ),
        FoodSearchNavigationCard(
          icon: Icons.menu_book_rounded,
          title: 'Saved recipes',
          detail: 'Find, scale or create a published recipe.',
          onTap: onOpenSavedRecipes,
        ),
        const SizedBox(height: 16),
        const FoodSearchSectionHeader(
          title: 'More ways',
          subtitle: 'Optional shortcuts when they help.',
        ),
        FoodSearchNavigationCard(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Scan barcode',
          detail: 'Find a packaged food by its barcode.',
          onTap: onOpenBarcode,
        ),
        FoodSearchNavigationCard(
          icon: Icons.document_scanner_rounded,
          title: 'Scan nutrition label',
          detail: 'Extract dual-basis facts directly from packaging.',
          onTap: onScanNutritionLabel,
        ),
        FoodSearchNavigationCard(
          icon: Icons.auto_awesome_rounded,
          title: 'Describe meal',
          detail: 'Log multi-item meals with standard Indian portions.',
          onTap: onDescribeMeal,
        ),
        if (entriesPanel != null) ...[
          const SizedBox(height: 16),
          entriesPanel!,
        ],
      ],
    );
  }
}
