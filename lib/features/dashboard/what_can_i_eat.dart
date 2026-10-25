import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/presentation/consumer_number_label.dart';
import 'protein_nudge.dart';
import 'today_consumer_presentation.dart';

/// "What can I eat?" (TF-2 A): what is left of today's targets and up to
/// five foods that fit it. No AI and no new ranking: the foods come from
/// the protein nudge's candidates and rules ([ProteinNudge.pick]), so they
/// fit the diet (Jain and vegan included), pass the protein-density floor
/// and fit the calories left.
abstract final class WhatCanIEat {
  static const maxSuggestions = 5;

  /// Over the calorie target, only foods at or under this are offered.
  static const lighterKcal = 150.0;

  /// What the sheet shows for these totals. A calorie target is needed;
  /// the protein target is optional.
  static WhatCanIEatPlan plan({
    required double? kcalTarget,
    required double? kcalEaten,
    required double? proteinTarget,
    required double? proteinEaten,
  }) {
    if (kcalTarget == null || kcalTarget <= 0) {
      return const WhatCanIEatPlan.noTargets();
    }
    final kcalLeft = kcalTarget - (kcalEaten ?? 0);
    final proteinLeft = proteinTarget == null || proteinTarget <= 0
        ? null
        : proteinTarget - (proteinEaten ?? 0);
    if (kcalLeft <= 0) {
      return WhatCanIEatPlan(
        status: WhatCanIEatStatus.over,
        kcalLeft: kcalLeft,
        proteinLeft: proteinLeft,
      );
    }
    return WhatCanIEatPlan(
      status: WhatCanIEatStatus.open,
      kcalLeft: kcalLeft,
      proteinLeft: proteinLeft,
    );
  }

  /// [plan] from the day's totals as Today and the Food diary show them.
  /// When estimates make a total a range, the top of it counts as eaten,
  /// so what is left is never overstated.
  static WhatCanIEatPlan planFor(TodayNutritionPresentation presentation) {
    final calories = presentation.calories;
    if (calories == null) return const WhatCanIEatPlan.noTargets();
    TodayNutritionMetricPresentation? protein;
    for (final metric in presentation.macros) {
      if (metric.nutrientId == 'protein') protein = metric;
    }
    double? eaten(TodayNutritionMetricPresentation? metric) =>
        metric == null || !metric.isAvailable
        ? null
        : metric.isRange
        ? metric.upperValue
        : metric.pointValue;
    return plan(
      kcalTarget: calories.targetValue,
      kcalEaten: eaten(calories),
      proteinTarget: protein?.targetValue,
      proteinEaten: eaten(protein),
    );
  }

  /// Up to five foods for [plan]: the same rules as the protein nudge,
  /// capped at the calories left, or at [lighterKcal] when over.
  static List<ProteinSuggestion> pick(
    ProteinCandidates found,
    WhatCanIEatPlan plan,
  ) {
    final cap = plan.kcalCap;
    if (cap == null) return const [];
    return ProteinNudge.pick(
      found.candidates,
      diet: found.diet,
      remainingKcal: cap,
      conflictingFoodIds: found.conflicts,
      limit: maxSuggestions,
    );
  }
}

enum WhatCanIEatStatus { noTargets, open, over }

class WhatCanIEatPlan {
  const WhatCanIEatPlan({
    required this.status,
    required this.kcalLeft,
    required this.proteinLeft,
  });

  const WhatCanIEatPlan.noTargets()
    : status = WhatCanIEatStatus.noTargets,
      kcalLeft = null,
      proteinLeft = null;

  final WhatCanIEatStatus status;
  final double? kcalLeft;
  final double? proteinLeft;

  @override
  bool operator ==(Object other) =>
      other is WhatCanIEatPlan &&
      other.status == status &&
      other.kcalLeft == kcalLeft &&
      other.proteinLeft == proteinLeft;

  @override
  int get hashCode => Object.hash(status, kcalLeft, proteinLeft);

  /// The most a suggestion may have; null when nothing is suggested.
  double? get kcalCap => switch (status) {
    WhatCanIEatStatus.noTargets => null,
    WhatCanIEatStatus.open => kcalLeft,
    WhatCanIEatStatus.over => WhatCanIEat.lighterKcal,
  };

  /// "1,100 kcal · 60 g protein left"; "1,100 kcal left" without a protein
  /// target; "You're over today; lighter options:" over the target.
  String get headline => switch (status) {
    WhatCanIEatStatus.noTargets => 'Set targets to see suggestions',
    WhatCanIEatStatus.over => "You're over today; lighter options:",
    WhatCanIEatStatus.open =>
      proteinLeft == null
          ? '${ConsumerNumberLabel.rounded(kcalLeft!)} kcal left'
          : '${ConsumerNumberLabel.rounded(kcalLeft!)} kcal · '
                '${ConsumerNumberLabel.rounded(proteinLeft! < 0 ? 0 : proteinLeft!)} g '
                'protein left',
  };
}

/// Suggestions for [WhatCanIEatPlan]; empty when none fit.
final whatCanIEatSuggestionsProvider = FutureProvider.autoDispose
    .family<List<ProteinSuggestion>, WhatCanIEatPlan>((ref, plan) async {
      if (plan.kcalCap == null) return const [];
      final found = await ref.watch(proteinCandidatesProvider.future);
      return WhatCanIEat.pick(found, plan);
    });
