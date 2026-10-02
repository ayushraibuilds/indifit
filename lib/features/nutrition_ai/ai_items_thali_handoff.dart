import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/nutrition_thali.dart';
import '../../core/typed_quantities.dart';
import '../../core/utils/app_logger.dart';
import '../../data/repositories/nutrition_food_catalog_repository.dart';
import '../food_log/nutrition_thali_controller.dart';
import '../nutrition/nutrition_providers.dart';
import 'meal_item_resolver.dart';
import 'natural_language_meal_service.dart';

/// Hands AI-parsed items to the thali builder for review and logging.
///
/// Shared by the describe-meal and photo-meal screens, which previously each
/// had their own copy with three defects:
/// - items were added before the thali draft existed, so they were silently
///   dropped, and the autoDispose controller could be torn down before
///   navigation, so the builder opened empty;
/// - a catalogue match logged the AI's number against the food's base unit
///   ("2 rotis" became 2 g), and for serving-based foods built a quantity
///   without its serving definition, which throws;
/// - ambiguous matches were silently resolved to the first search result.
///
/// Returns false (after telling the user why) when nothing was handed off.
Future<bool> openAiItemsInThali({
  required BuildContext context,
  required WidgetRef ref,
  required String mealType,
  required List<DecomposedFoodItem> items,
}) async {
  final pendingChoice = items.where((item) => item.needsCatalogChoice);
  if (pendingChoice.isNotEmpty) {
    _tell(
      context,
      'Choose a match for "${pendingChoice.first.foodName}" before logging.',
    );
    return false;
  }

  final provider = nutritionThaliControllerProvider(mealType);
  // Hold the autoDispose controller until the builder screen takes over.
  final keepAlive = ref.listenManual(provider, (_, _) {});
  try {
    final ready = await _waitForDraft(ref, provider);
    if (!ready) {
      if (context.mounted) {
        _tell(context, 'Couldn\'t open the thali builder. Please try again.');
      }
      return false;
    }

    final catalog = await ref.read(
      nutritionFoodCatalogRepositoryProvider.future,
    );
    final controller = ref.read(provider.notifier);
    var portionsToSet = 0;
    for (final item in items) {
      final NutritionFoodOption option;
      final Quantity quantity;
      final matched = item.matchedCatalogOption;
      if (matched != null) {
        final portion = PortionMapping.map(
          amount: item.quantityAmount,
          unit: item.quantityUnit,
          option: matched,
        );
        if (portion.needsReview) portionsToSet++;
        option = matched;
        quantity = portion.quantity;
      } else {
        // No trustworthy catalogue food: keep the AI estimate as the user's
        // own food so it stays visibly distinct from verified entries.
        option = await catalog.createUserFood(
          displayName: item.foodName,
          servingSize: item.quantityAmount > 0 ? item.quantityAmount : 1.0,
          servingUnit: item.quantityUnit,
          energyKcal: item.estimatedCalories.toDouble(),
          proteinG: item.estimatedProtein,
          carbohydrateG: item.estimatedCarbs,
          fatG: item.estimatedFat,
        );
        quantity = option.baseQuantity;
      }
      controller.addFood(
        NutritionThaliFoodOption(
          id: option.id,
          displayName: option.displayName,
          kind: 'direct',
          sourceType: option.sourceType,
          region: null,
        ),
        quantity: quantity,
      );
    }

    if (!context.mounted) return false;
    if (portionsToSet > 0) {
      _tell(
        context,
        portionsToSet == 1
            ? '1 item needs its amount set on the plate.'
            : '$portionsToSet items need their amount set on the plate.',
      );
    }
    await context.push('/food/thali?meal=$mealType');
    return true;
  } on Object catch (error, stackTrace) {
    AppLogger.error('AI items thali handoff failed', error, stackTrace);
    if (context.mounted) {
      _tell(context, 'Couldn\'t add these items. Please try again.');
    }
    return false;
  } finally {
    keepAlive.close();
  }
}

/// Waits until the thali controller has created its draft; addFood is a
/// no-op before that.
Future<bool> _waitForDraft(
  WidgetRef ref,
  ProviderListenable<NutritionThaliState> provider, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  if (ref.read(provider).draft != null) return true;
  final ready = Completer<bool>();
  final sub = ref.listenManual(provider, (_, next) {
    if (next.draft != null && !ready.isCompleted) ready.complete(true);
  });
  try {
    return await ready.future.timeout(timeout, onTimeout: () => false);
  } finally {
    sub.close();
  }
}

void _tell(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
