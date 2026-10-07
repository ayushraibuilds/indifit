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
  final VoidCallback? onTap;
  final bool enabled;

  const FoodSearchNavigationCard({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => B05Surface(
    padding: EdgeInsets.zero,
    child: Semantics(
      container: true,
      explicitChildNodes: true,
      button: enabled,
      enabled: enabled,
      label: title,
      hint: detail,
      child: ListTile(
        enabled: enabled,
        minVerticalPadding: 12,
        leading: Icon(
          icon,
          color: enabled ? context.b05Colors.action : Colors.grey,
        ),
        title: Text(
          title,
          style: B05Typography.label(
            context,
          ).copyWith(color: enabled ? null : Colors.grey),
        ),
        subtitle: Text(detail, style: B05Typography.caption(context)),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: enabled ? null : Colors.grey,
        ),
        onTap: enabled ? onTap : null,
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

  /// "Repeat yesterday's lunch", shown first when there's something to
  /// repeat and nothing logged for this meal yet.
  final Widget? repeatAction;
  final bool loadingRecent;
  final String? recentFailureMessage;
  final VoidCallback onRetryRecent;
  final List<CanonicalRecentFood> canonicalRecentResults;
  final List<FoodItem> recentResults;
  final Widget Function(BuildContext context, CanonicalRecentFood recent)
  canonicalRecentItemBuilder;
  final Widget Function(BuildContext context, FoodItem food) recentItemBuilder;
  final VoidCallback onOpenSavedMeals;
  final VoidCallback onOpenSavedRecipes;
  final VoidCallback onOpenBarcode;
  final VoidCallback? onScanNutritionLabel;
  final VoidCallback? onDescribeMeal;

  /// Meal photo estimate (Beta). Null hides it, like the other AI tools.
  final VoidCallback? onPhotoMeal;
  final VoidCallback? onOpenThali;
  final VoidCallback? onQuickAddMacros;
  final Widget? entriesPanel;
  final bool isOpenFoodFactsAllowed;

  const FoodSearchRecentList({
    super.key,
    this.neutralFoodEntry,
    this.repeatAction,
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
    this.onScanNutritionLabel,
    this.onDescribeMeal,
    this.onPhotoMeal,
    this.onOpenThali,
    this.onQuickAddMacros,
    this.entriesPanel,
    this.isOpenFoodFactsAllowed = true,
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
        if (repeatAction != null) ...[
          repeatAction!,
          const SizedBox(height: 12),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              if (onDescribeMeal != null) ...[
                _QuickActionChip(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Describe meal',
                  onTap: onDescribeMeal!,
                ),
                const SizedBox(width: 8),
              ],
              if (onPhotoMeal != null) ...[
                _QuickActionChip(
                  icon: Icons.photo_camera_outlined,
                  label: 'Meal photo',
                  onTap: onPhotoMeal!,
                ),
                const SizedBox(width: 8),
              ],
              if (onOpenThali != null) ...[
                _QuickActionChip(
                  icon: Icons.dinner_dining_rounded,
                  label: 'Indian Thali',
                  onTap: onOpenThali!,
                ),
                const SizedBox(width: 8),
              ],
              _QuickActionChip(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Scan barcode',
                enabled: isOpenFoodFactsAllowed,
                onTap: isOpenFoodFactsAllowed
                    ? onOpenBarcode
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Turn off Offline Mode to look up packaged foods.',
                            ),
                          ),
                        );
                      },
              ),
              if (onScanNutritionLabel != null) ...[
                const SizedBox(width: 8),
                _QuickActionChip(
                  icon: Icons.document_scanner_rounded,
                  label: 'Scan label',
                  onTap: onScanNutritionLabel!,
                ),
              ],
              if (onQuickAddMacros != null) ...[
                const SizedBox(width: 8),
                _QuickActionChip(
                  icon: Icons.bolt_rounded,
                  label: 'Quick add',
                  onTap: onQuickAddMacros!,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
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
          ...canonicalRecentResults.map(
            (item) => canonicalRecentItemBuilder(context, item),
          ),
        if (!loadingRecent &&
            recentResults.isNotEmpty &&
            canonicalRecentResults.isNotEmpty)
          const SizedBox(height: 8),
        if (!loadingRecent)
          ...recentResults
              .take(6)
              .map((food) => recentItemBuilder(context, food)),
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
          detail: isOpenFoodFactsAllowed
              ? 'Find a packaged food by its barcode.'
              : 'Turn off Offline Mode to look up packaged foods',
          enabled: isOpenFoodFactsAllowed,
          onTap: isOpenFoodFactsAllowed ? onOpenBarcode : null,
        ),
        if (onScanNutritionLabel != null)
          FoodSearchNavigationCard(
            icon: Icons.document_scanner_rounded,
            title: 'Scan nutrition label',
            detail: 'Save a packaged food from its printed nutrition label.',
            onTap: onScanNutritionLabel!,
          ),
        if (onDescribeMeal != null)
          FoodSearchNavigationCard(
            icon: Icons.auto_awesome_rounded,
            title: 'Describe meal',
            detail: 'Log multi-item meals with standard Indian portions.',
            onTap: onDescribeMeal!,
          ),
        if (onPhotoMeal != null)
          FoodSearchNavigationCard(
            icon: Icons.photo_camera_outlined,
            title: 'Meal photo (Beta)',
            detail:
                'Estimate a plate from a photo. Check every item before '
                'logging.',
            onTap: onPhotoMeal!,
          ),
        if (onQuickAddMacros != null)
          FoodSearchNavigationCard(
            icon: Icons.bolt_rounded,
            title: 'Quick-add calories & macros',
            detail: 'Log calories and macros in under 10 seconds.',
            onTap: onQuickAddMacros!,
          ),
        if (entriesPanel != null) ...[
          const SizedBox(height: 16),
          entriesPanel!,
        ],
      ],
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: enabled ? colors.border : colors.border.withAlpha(128),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: enabled ? colors.action : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: B05Typography.caption(context).copyWith(
                  fontWeight: FontWeight.w600,
                  color: enabled ? colors.textPrimary : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
