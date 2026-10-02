import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/core_providers.dart';
import '../../core/privacy/dpdp_consent_service.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/repositories/nutrition_food_catalog_repository.dart';
import '../nutrition/nutrition_providers.dart';
import 'ai_items_thali_handoff.dart';
import 'natural_language_meal_service.dart';
import 'nutrition_ai_controllers.dart';

class NaturalLanguageMealScreen extends ConsumerStatefulWidget {
  final String? mealType;
  final String? date;

  const NaturalLanguageMealScreen({super.key, this.mealType, this.date});

  @override
  ConsumerState<NaturalLanguageMealScreen> createState() =>
      _NaturalLanguageMealScreenState();
}

class _NaturalLanguageMealScreenState
    extends ConsumerState<NaturalLanguageMealScreen> {
  late final TextEditingController _textController;

  static const _starterChips = [
    '2 rotis and 1 bowl dal tadka',
    '100g paneer bhurji and 1 katori curd',
    '3 boiled egg whites and 2 toast',
    '1 plate chicken biryani with raita',
    '1 bowl oats upma with almonds',
  ];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  DateTime _resolveDate() {
    if (widget.date != null) {
      try {
        return DateTime.parse(widget.date!);
      } catch (_) {}
    }
    return DateTime.now();
  }

  String _resolveMealType() {
    return widget.mealType ?? 'lunch';
  }

  Future<void> _analyzeWithConsent(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    SharedPreferences? prefs;
    try {
      prefs = ref.read(sharedPreferencesProvider);
    } catch (_) {}
    prefs ??= await SharedPreferences.getInstance();
    if (!mounted) return;

    final consented = await DpdpConsentService.ensureConsent(
      context: context,
      prefs: prefs,
    );
    if (!consented || !mounted) return;

    final controller = ref.read(naturalLanguageMealControllerProvider.notifier);
    await controller.analyzeMeal(clean);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(naturalLanguageMealControllerProvider);
    final controller = ref.read(naturalLanguageMealControllerProvider.notifier);
    final colors = context.b05Colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Describe Meal')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(B05Layout.space16),
          children: [
            // Input Surface
            B05Surface(
              padding: const EdgeInsets.all(B05Layout.space16),
              showBorder: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What did you eat?',
                    style: B05Typography.title(context),
                  ),
                  const SizedBox(height: B05Layout.space8),
                  Text(
                    'Describe your meal using Indian measures (katori, bowl, roti, plates, grams).',
                    style: B05Typography.caption(context),
                  ),
                  const SizedBox(height: B05Layout.space12),
                  TextField(
                    controller: _textController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText:
                          'e.g. 2 rotis with 1 bowl dal tadka and 100g paneer',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: B05Layout.space12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _starterChips.map((chip) {
                      return ActionChip(
                        label: Text(chip, style: const TextStyle(fontSize: 12)),
                        onPressed: () {
                          _textController.text = chip;
                          _analyzeWithConsent(chip);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: B05Layout.space16),
                  B05ActionButton(
                    label: state.status == NaturalLanguageMealStatus.analyzing
                        ? 'Analyzing...'
                        : 'Analyze Meal',
                    icon: Icons.auto_awesome_rounded,
                    onPressed: state.isBusy
                        ? null
                        : () => _analyzeWithConsent(_textController.text),
                  ),
                ],
              ),
            ),

            if (state.status == NaturalLanguageMealStatus.failure) ...[
              const SizedBox(height: B05Layout.space16),
              B05StatusMessage(
                status: B05SemanticStatus.danger,
                label:
                    state.errorMessage ?? 'Could not analyze meal description.',
              ),
            ],

            if (state.result?.isFallback == true) ...[
              const SizedBox(height: B05Layout.space16),
              const B05StatusMessage(
                status: B05SemanticStatus.info,
                label: 'Local offline parsing used. Review items below.',
              ),
            ],

            // Decomposed Items
            if (state.editableItems.isNotEmpty) ...[
              const SizedBox(height: B05Layout.space20),

              // Total Summary Card
              B05Surface(
                padding: const EdgeInsets.all(B05Layout.space16),
                showBorder: true,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTotalStat(
                      context,
                      'Calories',
                      '${state.totalCalories} kcal',
                      Theme.of(context).colorScheme.primary,
                    ),
                    _buildTotalStat(
                      context,
                      'Protein',
                      '${state.totalProtein.toStringAsFixed(1)}g',
                      colors.success.indicator,
                    ),
                    _buildTotalStat(
                      context,
                      'Carbs',
                      '${state.totalCarbs.toStringAsFixed(1)}g',
                      colors.warning.indicator,
                    ),
                    _buildTotalStat(
                      context,
                      'Fat',
                      '${state.totalFat.toStringAsFixed(1)}g',
                      colors.danger.indicator,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: B05Layout.space16),

              Text(
                'Decomposed Items (${state.editableItems.length})',
                style: B05Typography.title(context),
              ),
              const SizedBox(height: B05Layout.space8),

              ...state.editableItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _buildItemCard(context, index, item, controller, colors);
              }),

              const SizedBox(height: B05Layout.space20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      label: const Text('Open in Circular Thali'),
                      icon: const Icon(Icons.pie_chart_outline_rounded),
                      onPressed: state.isBusy || state.editableItems.isEmpty
                          ? null
                          : () => _openInCircularThali(
                              _resolveMealType(),
                              _resolveDate(),
                              state.editableItems,
                            ),
                    ),
                  ),
                  const SizedBox(width: B05Layout.space12),
                  Expanded(
                    child: B05ActionButton(
                      label: state.isLogged
                          ? 'Logged to Diary'
                          : (state.status == NaturalLanguageMealStatus.logging
                                ? 'Logging Meal...'
                                : 'Log Meal to Diary'),
                      icon: Icons.check_circle_outline_rounded,
                      onPressed: state.isLogged || state.isBusy
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final router = GoRouter.of(context);
                              final ok = await controller.logAllToDiary(
                                mealType: _resolveMealType(),
                                date: _resolveDate(),
                              );
                              if (ok && mounted) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Meal logged to diary successfully!',
                                    ),
                                  ),
                                );
                                router.pop(true);
                              }
                            },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openInCircularThali(
    String mealType,
    DateTime date,
    List<DecomposedFoodItem> items,
  ) async {
    await openAiItemsInThali(
      context: context,
      ref: ref,
      mealType: mealType,
      items: items,
    );
  }

  Future<void> _openSwapModal(
    BuildContext context,
    int index,
    DecomposedFoodItem item,
    NaturalLanguageMealController controller,
  ) async {
    final catalog = await ref.read(
      nutritionFoodCatalogRepositoryProvider.future,
    );
    // Ambiguous items open on the resolver's candidates; otherwise search.
    final initialMatches = item.catalogChoices.isNotEmpty
        ? item.catalogChoices
        : await catalog.search(query: item.foodName);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        List<NutritionFoodOption> matches = initialMatches;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (ctx, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Swap Food Match',
                            style: B05Typography.title(context),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(sheetCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        autofocus: false,
                        decoration: InputDecoration(
                          hintText: 'Search food in catalog...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setSheetState(() {
                                matches = [];
                              });
                            },
                          ),
                        ),
                        onChanged: (val) async {
                          final results = await catalog.search(query: val);
                          setSheetState(() => matches = results);
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: matches.isEmpty
                            ? Center(
                                child: Text(
                                  'No matching catalog foods found.',
                                  style: B05Typography.caption(context),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: matches.length,
                                separatorBuilder: (ctx, i) => const Divider(),
                                itemBuilder: (ctx, i) {
                                  final option = matches[i];
                                  final isCurrent =
                                      item.matchedCatalogOption?.id ==
                                      option.id;
                                  final energy =
                                      option
                                          .facts['energy']
                                          ?.point
                                          ?.value
                                          .asDouble
                                          .toStringAsFixed(0) ??
                                      '—';
                                  final protein =
                                      option
                                          .facts['protein']
                                          ?.point
                                          ?.value
                                          .asDouble
                                          .toStringAsFixed(1) ??
                                      '—';
                                  return ListTile(
                                    title: Text(option.displayName),
                                    subtitle: Text(
                                      '$energy kcal • $protein g P per ${option.baseQuantity}',
                                    ),
                                    trailing: isCurrent
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.green,
                                          )
                                        : null,
                                    onTap: () {
                                      controller.updateItemFoodMatch(
                                        index,
                                        option,
                                      );
                                      Navigator.pop(sheetCtx);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTotalStat(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: B05Typography.caption(context)),
      ],
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    int index,
    DecomposedFoodItem item,
    NaturalLanguageMealController controller,
    B05SemanticColors colors,
  ) {
    final isVerified = item.isCatalogVerified;
    final needsChoice = item.needsCatalogChoice;
    final badgeColor = isVerified
        ? colors.success.indicator
        : needsChoice
        ? colors.warning.indicator
        : colors.info.indicator;
    final badgeText = isVerified
        ? 'Catalog Verified'
        : needsChoice
        ? 'Choose a match'
        : 'AI Estimate';

    final confidenceColor = switch (item.confidence.toLowerCase()) {
      'high' => colors.success.indicator,
      'low' => colors.danger.indicator,
      _ => colors.warning.indicator,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: B05Layout.space12),
      child: B05Surface(
        padding: const EdgeInsets.all(B05Layout.space16),
        showBorder: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.foodName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'from: "${item.rawSegment}"',
                        style: B05Typography.caption(context),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: confidenceColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${item.confidence[0].toUpperCase()}${item.confidence.substring(1)} Conf',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: confidenceColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: badgeColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Remove item',
                  onPressed: () => controller.removeItem(index),
                ),
              ],
            ),
            const SizedBox(height: B05Layout.space12),
            Row(
              children: [
                // Inline Stepper
                IconButton.outlined(
                  icon: const Icon(Icons.remove, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: item.quantityAmount <= 0.25
                      ? null
                      : () {
                          final step = item.quantityAmount <= 1.0 ? 0.25 : 1.0;
                          final newAmount = (item.quantityAmount - step).clamp(
                            0.25,
                            999.0,
                          );
                          controller.updateItemQuantity(
                            index,
                            newAmount,
                            item.quantityUnit,
                          );
                        },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '${item.quantityAmount.toStringAsFixed(item.quantityAmount % 1 == 0 ? 0 : 2)} ${item.quantityUnit}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton.outlined(
                  icon: const Icon(Icons.add, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    final step = item.quantityAmount < 1.0 ? 0.25 : 1.0;
                    final newAmount = item.quantityAmount + step;
                    controller.updateItemQuantity(
                      index,
                      newAmount,
                      item.quantityUnit,
                    );
                  },
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: Text(
                    isVerified ? 'Swap' : (needsChoice ? 'Choose' : 'Match'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () =>
                      _openSwapModal(context, index, item, controller),
                ),
                const Spacer(),
                Text(
                  '${item.estimatedCalories} kcal • ${item.estimatedProtein.toStringAsFixed(1)}g P',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
